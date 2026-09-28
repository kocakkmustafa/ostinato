import Flutter
import XCTest
@testable import Runner

private enum FakeCaptureFailure: Error { case deactivation }

private final class ManualCaptureDeadlines {
  private var pending: [() -> Void] = []
  func schedule(_ work: @escaping () -> Void) { pending.append(work) }
  func fireAll() {
    let due = pending
    pending.removeAll()
    due.forEach { $0() }
  }
}

private final class FakeCaptureHardware: CaptureHardware {
  private let lock = NSLock()
  private var gatedStart: DispatchSemaphore?
  private var gatedStop: DispatchSemaphore?
  var startGate: DispatchSemaphore? {
    get { lock.lock(); defer { lock.unlock() }; return gatedStart }
    set { lock.lock(); gatedStart = newValue; lock.unlock() }
  }
  var stopGate: DispatchSemaphore? {
    get { lock.lock(); defer { lock.unlock() }; return gatedStop }
    set { lock.lock(); gatedStop = newValue; lock.unlock() }
  }
  var startEntered: XCTestExpectation?
  var stopEntered: XCTestExpectation?
  var failuresRemaining = 0
  private(set) var startCalls = 0
  private(set) var stopCalls = 0
  private var chunk: ((Data, Int, Int64, @escaping () -> Void) -> Void)?
  private var startFence: CaptureFence?
  var latestFence: CaptureFence? {
    lock.lock(); defer { lock.unlock() }
    return startFence
  }

  func start(
    rate: Int,
    fence: CaptureFence,
    onChunk: @escaping (Data, Int, Int64, @escaping () -> Void) -> Void
  ) throws -> String {
    lock.lock()
    startCalls += 1
    chunk = onChunk
    startFence = fence
    let gate = gatedStart
    lock.unlock()
    startEntered?.fulfill()
    gate?.wait()
    if fence.isCancelled { throw CaptureHardwareError.cancelled }
    return "ios:BuiltInMic"
  }

  func stop() throws {
    lock.lock()
    stopCalls += 1
    let gate = gatedStop
    let shouldFail = failuresRemaining > 0
    if shouldFail { failuresRemaining -= 1 }
    lock.unlock()
    stopEntered?.fulfill()
    gate?.wait()
    if shouldFail { throw FakeCaptureFailure.deactivation }
  }

  func emitChunk() {
    lock.lock()
    let callback = chunk
    lock.unlock()
    callback?(Data(repeating: 0, count: 8), 44100, 1) {}
  }
}

final class RunnerTests: XCTestCase {
  private let a = String(repeating: "a", count: 32)
  private let b = String(repeating: "b", count: 32)

  private func onMain(_ work: () -> Void) {
    if Thread.isMainThread { work() }
    else { DispatchQueue.main.sync(execute: work) }
  }

  private func awaitPhase(
    _ name: String,
    of coordinator: AudioCaptureCoordinator,
    timeout: TimeInterval = 2
  ) {
    let reached = expectation(description: "phase \(name)")
    func poll() {
      if coordinator.closeState()["phase"] as? String == name {
        reached.fulfill()
      } else {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01, execute: poll)
      }
    }
    onMain(poll)
    wait(for: [reached], timeout: timeout)
  }

  private func listen(
    _ handler: AudioCaptureStreamer,
    id: String,
    events: @escaping FlutterEventSink = { _ in }
  ) {
    onMain {
      XCTAssertNil(handler.onListen(withArguments: ["attemptId": id], eventSink: events))
    }
  }

  private func start(
    _ handler: AudioCaptureStreamer,
    id: String,
    reply: @escaping FlutterResult
  ) {
    onMain {
      handler.handle(
        FlutterMethodCall(methodName: "start",
                          arguments: ["attemptId": id, "sampleRate": 44100]),
        result: reply
      )
    }
  }

  private func stop(
    _ handler: AudioCaptureStreamer,
    id: String,
    reply: @escaping FlutterResult
  ) {
    onMain {
      handler.handle(
        FlutterMethodCall(methodName: "stop", arguments: ["attemptId": id]),
        result: reply
      )
    }
  }

  private func retryStop(
    _ handler: AudioCaptureStreamer,
    id: String,
    reply: @escaping FlutterResult
  ) {
    onMain {
      handler.handle(
        FlutterMethodCall(methodName: "retryStop", arguments: ["attemptId": id]),
        result: reply
      )
    }
  }

  func testHungStartFencesStopAndLateCompletionRequiresExplicitRetry() {
    let hardware = FakeCaptureHardware()
    let startGate = DispatchSemaphore(value: 0)
    hardware.startGate = startGate
    hardware.startEntered = expectation(description: "hardware start entered")
    hardware.stopEntered = expectation(description: "hardware stop after late start")
    let coordinator = AudioCaptureCoordinator(
      hardware: hardware, deadline: 0.1, canCapture: { true }
    )
    let handler = AudioCaptureStreamer(coordinator: coordinator)
    var events: [Any?] = []
    listen(handler, id: a) { events.append($0) }

    let startTimedOut = expectation(description: "start timeout")
    let stopTimedOut = expectation(description: "stop timeout")
    var startReplies: [Any?] = []
    var stopReplies: [Any?] = []
    start(handler, id: a) {
      startReplies.append($0)
      startTimedOut.fulfill()
    }
    wait(for: [hardware.startEntered!], timeout: 1)
    stop(handler, id: a) {
      stopReplies.append($0)
      stopTimedOut.fulfill()
    }
    XCTAssertEqual(coordinator.closeState()["phase"] as? String, "closing")
    wait(for: [startTimedOut, stopTimedOut], timeout: 1)
    XCTAssertEqual((startReplies.first as? FlutterError)?.code, "capture_close_unconfirmed")
    XCTAssertEqual((stopReplies.first as? FlutterError)?.code, "capture_close_unconfirmed")
    XCTAssertEqual(coordinator.closeState()["phase"] as? String, "unconfirmedInFlight")

    // The hardware call was not cancelled by either timeout; its late return
    // must close serially, not publish a start success or a chunk.
    hardware.startGate = nil
    startGate.signal()
    wait(for: [hardware.stopEntered!], timeout: 1)
    awaitPhase("releasedAwaitingExplicitRetry", of: coordinator)
    hardware.emitChunk()
    XCTAssertTrue(events.isEmpty)
    XCTAssertEqual(startReplies.count, 1)
    XCTAssertEqual(stopReplies.count, 1)
    XCTAssertEqual(hardware.stopCalls, 1)

    let replacement = AudioCaptureStreamer(coordinator: coordinator)
    listen(replacement, id: b)
    var blocked: Any?
    start(replacement, id: b) { blocked = $0 }
    XCTAssertEqual((blocked as? FlutterError)?.code, "capture_close_unconfirmed")
    var retry: Any? = "not called"
    retryStop(replacement, id: a) { retry = $0 }
    XCTAssertNil(retry)
    XCTAssertEqual(coordinator.closeState()["phase"] as? String, "clear")
  }

  func testDeactivationFailureKeepsProcessLatchUntilExplicitSecondStop() {
    let hardware = FakeCaptureHardware()
    hardware.failuresRemaining = 1
    let coordinator = AudioCaptureCoordinator(hardware: hardware, canCapture: { true })
    let slot = AudioCaptureHandlerSlot()
    let first = AudioCaptureStreamer(coordinator: coordinator)
    onMain { slot.install(first) }
    listen(first, id: a)
    let started = expectation(description: "start A")
    start(first, id: a) { response in
      XCTAssertNil(response)
      started.fulfill()
    }
    wait(for: [started], timeout: 1)
    awaitPhase("running", of: coordinator)

    let failed = expectation(description: "deactivation throws")
    stop(first, id: a) { response in
      XCTAssertEqual((response as? FlutterError)?.code, "capture_close_unconfirmed")
      failed.fulfill()
    }
    wait(for: [failed], timeout: 1)
    awaitPhase("unconfirmedQuiescent", of: coordinator)
    XCTAssertEqual(coordinator.closeState()["requiresExplicitRetry"] as? Bool, true)

    let replacement = AudioCaptureStreamer(coordinator: coordinator)
    onMain { slot.install(replacement) }
    listen(replacement, id: b)
    var blocked: Any?
    start(replacement, id: b) { blocked = $0 }
    XCTAssertEqual((blocked as? FlutterError)?.code, "capture_close_unconfirmed")
    let retried = expectation(description: "second stop completes")
    var ordinary: Any?
    stop(replacement, id: a) { ordinary = $0 }
    XCTAssertEqual((ordinary as? FlutterError)?.code, "capture_close_unconfirmed")
    XCTAssertEqual(hardware.stopCalls, 1)
    retryStop(replacement, id: a) { response in
      XCTAssertNil(response)
      retried.fulfill()
    }
    wait(for: [retried], timeout: 1)
    awaitPhase("clear", of: coordinator)
    XCTAssertEqual(hardware.stopCalls, 2)

    let restarted = expectation(description: "independent B start")
    start(replacement, id: b) { response in
      XCTAssertNil(response)
      restarted.fulfill()
    }
    wait(for: [restarted], timeout: 1)
    awaitPhase("running", of: coordinator)
    onMain {
      XCTAssertNil(first.onCancel(withArguments: ["attemptId": a]))
      XCTAssertEqual(coordinator.closeState()["attemptId"] as? String, b)
    }
    let finished = expectation(description: "B closes")
    stop(replacement, id: b) { response in
      XCTAssertNil(response)
      finished.fulfill()
    }
    wait(for: [finished], timeout: 1)
  }

  func testImplicitNilCancelTombstonesPreviousSinkBeforeLateStart() {
    let hardware = FakeCaptureHardware()
    let coordinator = AudioCaptureCoordinator(hardware: hardware, canCapture: { true })
    let handler = AudioCaptureStreamer(coordinator: coordinator)
    listen(handler, id: a)
    onMain { XCTAssertNil(handler.onCancel(withArguments: nil)) }
    listen(handler, id: b)
    var oldStart: Any?
    start(handler, id: a) { oldStart = $0 }
    XCTAssertNotNil(oldStart as? FlutterError)
    XCTAssertEqual(hardware.startCalls, 0)

    let started = expectation(description: "B starts")
    start(handler, id: b) { response in
      XCTAssertNil(response)
      started.fulfill()
    }
    wait(for: [started], timeout: 1)
    awaitPhase("running", of: coordinator)
    onMain {
      XCTAssertNil(handler.onCancel(withArguments: ["attemptId": a]))
      XCTAssertEqual(coordinator.closeState()["attemptId"] as? String, b)
    }
    let stopped = expectation(description: "B stops")
    stop(handler, id: b) { response in
      XCTAssertNil(response)
      stopped.fulfill()
    }
    wait(for: [stopped], timeout: 1)
  }

  func testHungStopRepliesOnceAndLateReleaseStaysLatchedAcrossHandler() {
    let hardware = FakeCaptureHardware()
    let coordinator = AudioCaptureCoordinator(
      hardware: hardware, deadline: 0.1, canCapture: { true }
    )
    let first = AudioCaptureStreamer(coordinator: coordinator)
    listen(first, id: a)
    let started = expectation(description: "A starts")
    start(first, id: a) { response in
      XCTAssertNil(response)
      started.fulfill()
    }
    wait(for: [started], timeout: 1)
    awaitPhase("running", of: coordinator)

    let stopGate = DispatchSemaphore(value: 0)
    hardware.stopGate = stopGate
    hardware.stopEntered = expectation(description: "stop entered")
    let timedOut = expectation(description: "stop deadline")
    var replies: [Any?] = []
    stop(first, id: a) {
      replies.append($0)
      timedOut.fulfill()
    }
    wait(for: [hardware.stopEntered!, timedOut], timeout: 1)
    XCTAssertEqual((replies.first as? FlutterError)?.code, "capture_close_unconfirmed")
    XCTAssertEqual(coordinator.closeState()["phase"] as? String, "unconfirmedInFlight")

    hardware.stopGate = nil
    stopGate.signal()
    awaitPhase("releasedAwaitingExplicitRetry", of: coordinator)
    XCTAssertEqual(replies.count, 1)
    let replacement = AudioCaptureStreamer(coordinator: coordinator)
    XCTAssertEqual(replacementCoordinatorPhase(replacement), "releasedAwaitingExplicitRetry")
    var retry: Any? = "not called"
    retryStop(replacement, id: a) { retry = $0 }
    XCTAssertNil(retry)
    XCTAssertEqual(coordinator.closeState()["phase"] as? String, "clear")
  }

  func testEngineReplacementFencesRunningAttemptAndOnlyNewExplicitRetryClearsLatch() {
    let hardware = FakeCaptureHardware()
    let deadlines = ManualCaptureDeadlines()
    let coordinator = AudioCaptureCoordinator(
      hardware: hardware, deadline: 2,
      scheduler: { _, work in deadlines.schedule(work) },
      canCapture: { true }
    )
    let slot = AudioCaptureHandlerSlot()
    let old = AudioCaptureStreamer(coordinator: coordinator)
    let replacement = AudioCaptureStreamer(coordinator: coordinator)
    onMain { slot.install(old) }
    var chunks = 0
    let firstChunk = expectation(description: "old chunk delivered before replacement")
    listen(old, id: a) { event in
      if (event as? [String: Any])?["type"] as? String == "chunk" {
        chunks += 1
        firstChunk.fulfill()
      }
    }
    let started = expectation(description: "A running")
    start(old, id: a) { response in
      XCTAssertTrue(Thread.isMainThread)
      XCTAssertNil(response)
      started.fulfill()
    }
    wait(for: [started], timeout: 1)
    awaitPhase("running", of: coordinator)
    hardware.emitChunk()
    wait(for: [firstChunk], timeout: 1)
    XCTAssertEqual(chunks, 1)

    let stopGate = DispatchSemaphore(value: 0)
    hardware.stopGate = stopGate
    hardware.stopEntered = expectation(description: "replacement stop entered")
    onMain {
      slot.install(replacement) // No old onCancel or lifecycle callback.
      XCTAssertTrue(hardware.latestFence?.isCancelled == true)
      XCTAssertEqual(coordinator.closeState()["phase"] as? String, "closing")
      XCTAssertTrue(slot.current === replacement)
    }
    wait(for: [hardware.stopEntered!], timeout: 1)
    hardware.emitChunk()
    let drained = expectation(description: "old chunk callback drained")
    DispatchQueue.main.async { drained.fulfill() }
    wait(for: [drained], timeout: 1)
    XCTAssertEqual(chunks, 1)
    XCTAssertEqual(hardware.stopCalls, 1)

    listen(replacement, id: b)
    var blocked: Any?
    start(replacement, id: b) { blocked = $0 }
    XCTAssertEqual((blocked as? FlutterError)?.code, "capture_close_unconfirmed")
    XCTAssertEqual(hardware.startCalls, 1)
    onMain { deadlines.fireAll() }
    XCTAssertEqual(coordinator.closeState()["phase"] as? String, "unconfirmedInFlight")
    XCTAssertEqual(coordinator.closeState()["attemptInFlight"] as? Bool, true)
    XCTAssertEqual(coordinator.closeState()["resourcesReleased"] as? Bool, false)

    hardware.stopGate = nil
    stopGate.signal()
    awaitPhase("releasedAwaitingExplicitRetry", of: coordinator)
    hardware.stopEntered = nil
    var oldStop: Any?
    stop(old, id: a) { oldStop = $0 }
    XCTAssertEqual((oldStop as? FlutterError)?.code, "capture_unavailable")
    var ordinary: Any?
    stop(replacement, id: a) { ordinary = $0 }
    XCTAssertEqual((ordinary as? FlutterError)?.code, "capture_close_unconfirmed")
    var wrongId: Any?
    retryStop(replacement, id: b) { wrongId = $0 }
    XCTAssertEqual((wrongId as? FlutterError)?.code, "stale_capture_attempt")
    XCTAssertEqual(replacementCoordinatorPhase(replacement), "releasedAwaitingExplicitRetry")
    XCTAssertEqual(hardware.stopCalls, 1)

    var explicit: Any? = "not called"
    var explicitReplies = 0
    retryStop(replacement, id: a) { response in
      XCTAssertTrue(Thread.isMainThread)
      explicitReplies += 1
      explicit = response
    }
    XCTAssertNil(explicit)
    XCTAssertEqual(explicitReplies, 1)
    XCTAssertEqual(replacementCoordinatorPhase(replacement), "clear")
    let bStarted = expectation(description: "separate B start")
    start(replacement, id: b) { response in
      XCTAssertTrue(Thread.isMainThread)
      XCTAssertNil(response)
      bStarted.fulfill()
    }
    wait(for: [bStarted], timeout: 1)
    awaitPhase("running", of: coordinator)
    onMain {
      XCTAssertNil(old.onCancel(withArguments: nil))
      XCTAssertNil(old.onCancel(withArguments: ["attemptId": a]))
      XCTAssertEqual(coordinator.closeState()["attemptId"] as? String, b)
      XCTAssertEqual(old.onListen(withArguments: ["attemptId": String(repeating: "c", count: 32)],
                                  eventSink: { _ in })?.code,
                     "capture_unavailable")
    }
    var oldRetry: Any?
    retryStop(old, id: a) { oldRetry = $0 }
    XCTAssertEqual((oldRetry as? FlutterError)?.code, "capture_unavailable")
    var oldStart: Any?
    start(old, id: String(repeating: "c", count: 32)) { oldStart = $0 }
    XCTAssertEqual((oldStart as? FlutterError)?.code, "capture_unavailable")
    let bStopped = expectation(description: "B stop")
    stop(replacement, id: b) { response in
      XCTAssertNil(response)
      bStopped.fulfill()
    }
    wait(for: [bStopped], timeout: 1)
  }

  func testEngineReplacementWhileStartBlockedKeepsLateStartFenced() {
    let hardware = FakeCaptureHardware()
    let startGate = DispatchSemaphore(value: 0)
    hardware.startGate = startGate
    hardware.startEntered = expectation(description: "blocked start entered")
    hardware.stopEntered = expectation(description: "late start cleaned")
    let deadlines = ManualCaptureDeadlines()
    let coordinator = AudioCaptureCoordinator(
      hardware: hardware, deadline: 2,
      scheduler: { _, work in deadlines.schedule(work) },
      canCapture: { true }
    )
    let slot = AudioCaptureHandlerSlot()
    let old = AudioCaptureStreamer(coordinator: coordinator)
    let replacement = AudioCaptureStreamer(coordinator: coordinator)
    onMain { slot.install(old) }
    var chunks = 0
    listen(old, id: a) { event in
      if (event as? [String: Any])?["type"] as? String == "chunk" { chunks += 1 }
    }
    var startReplies = 0
    start(old, id: a) { response in
      XCTAssertTrue(Thread.isMainThread)
      XCTAssertEqual((response as? FlutterError)?.code, "capture_close_unconfirmed")
      startReplies += 1
    }
    wait(for: [hardware.startEntered!], timeout: 1)
    onMain {
      slot.install(replacement)
      XCTAssertTrue(hardware.latestFence?.isCancelled == true)
      XCTAssertEqual(coordinator.closeState()["phase"] as? String, "closing")
    }
    listen(replacement, id: b)
    var blocked: Any?
    start(replacement, id: b) { blocked = $0 }
    XCTAssertEqual((blocked as? FlutterError)?.code, "capture_close_unconfirmed")
    onMain { deadlines.fireAll() }
    XCTAssertEqual(startReplies, 1)
    XCTAssertEqual(coordinator.closeState()["phase"] as? String, "unconfirmedInFlight")
    startGate.signal()
    wait(for: [hardware.stopEntered!], timeout: 1)
    awaitPhase("releasedAwaitingExplicitRetry", of: coordinator)
    hardware.emitChunk()
    let drained = expectation(description: "late chunk callback drained")
    DispatchQueue.main.async { drained.fulfill() }
    wait(for: [drained], timeout: 1)
    XCTAssertEqual(chunks, 0)
    XCTAssertEqual(startReplies, 1)
    XCTAssertEqual(hardware.startCalls, 1)
    XCTAssertEqual(hardware.stopCalls, 1)
    var retry: Any? = "not called"
    retryStop(replacement, id: a) { retry = $0 }
    XCTAssertNil(retry)
    XCTAssertEqual(replacementCoordinatorPhase(replacement), "clear")
  }

  func testExplicitRetryOnClearOnlyAcknowledgesPreviouslyTombstonedId() {
    let hardware = FakeCaptureHardware()
    let coordinator = AudioCaptureCoordinator(hardware: hardware, canCapture: { true })
    let handler = AudioCaptureStreamer(coordinator: coordinator)
    listen(handler, id: a)
    onMain { XCTAssertNil(handler.onCancel(withArguments: nil)) }
    XCTAssertEqual(replacementCoordinatorPhase(handler), "clear")
    var unknown: Any?
    retryStop(handler, id: b) { unknown = $0 }
    XCTAssertEqual((unknown as? FlutterError)?.code, "stale_capture_attempt")
    var known: Any? = "not called"
    retryStop(handler, id: a) { known = $0 }
    XCTAssertNil(known)
    XCTAssertEqual(hardware.stopCalls, 0)
  }

  private func replacementCoordinatorPhase(_ handler: AudioCaptureStreamer) -> String? {
    var phase: String?
    onMain {
      handler.handle(FlutterMethodCall(methodName: "closeState", arguments: nil)) {
        phase = ($0 as? [String: Any])?["phase"] as? String
      }
    }
    return phase
  }
}
