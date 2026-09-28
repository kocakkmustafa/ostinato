import AVFoundation
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

private final class FakePracticeOutput: PracticeOutputHardware {
  var startCalls = 0
  var stopCalls = 0
  var failStart = false
  var failStop = false
  var startGate: DispatchSemaphore?
  var startEntered: XCTestExpectation?

  func start(assetId: String) throws {
    startCalls += 1
    startEntered?.fulfill()
    startGate?.wait()
    if failStart { throw FakeCaptureFailure.deactivation }
  }

  func stop() throws {
    stopCalls += 1
    if failStop { throw FakeCaptureFailure.deactivation }
  }
}

final class PracticeAudioArbiterTests: XCTestCase {
  private let attempt = String(repeating: "a", count: 32)
  private let inputLease = String(repeating: "b", count: 32)
  private let outputLease = String(repeating: "c", count: 32)

  private func onMain<T>(_ work: () -> T) -> T {
    if Thread.isMainThread { return work() }
    return DispatchQueue.main.sync(execute: work)
  }

  private func call(
    _ arbiter: PracticeAudioArbiter,
    _ owner: PracticeAudioOwner,
    _ method: String,
    _ arguments: [String: Any]
  ) -> Any? {
    onMain {
      var answer: Any?
      arbiter.handle(FlutterMethodCall(methodName: method, arguments: arguments), owner: owner) {
        answer = $0
      }
      return answer
    }
  }

  private func ownerFields(_ owner: PracticeAudioOwner) -> [String: Any] {
    ["ownerToken": owner.token, "engineGeneration": owner.engineGeneration]
  }

  private func waitForPhase(_ phase: String, _ coordinator: AudioCaptureCoordinator) {
    let reached = expectation(description: "capture phase \(phase)")
    func poll() {
      if coordinator.closeState()["phase"] as? String == phase { reached.fulfill() }
      else { DispatchQueue.main.asyncAfter(deadline: .now() + 0.01, execute: poll) }
    }
    onMain(poll)
    wait(for: [reached], timeout: 2)
  }

  private func waitForOutputPhase(
    _ phase: String, _ arbiter: PracticeAudioArbiter, _ owner: PracticeAudioOwner
  ) {
    let reached = expectation(description: "output phase \(phase)")
    func poll() {
      let state = call(arbiter, owner, "readAllAudioState", ownerFields(owner)) as? [String: Any]
      if state?["outputPhase"] as? String == phase { reached.fulfill() }
      else { DispatchQueue.main.asyncAfter(deadline: .now() + 0.01, execute: poll) }
    }
    onMain(poll)
    wait(for: [reached], timeout: 2)
  }

  func testOutputReservationBlocksLegacyMicrophoneStartAndCanCloseWithoutHardware() {
    let captureHardware = FakeCaptureHardware()
    let coordinator = AudioCaptureCoordinator(hardware: captureHardware, canCapture: { true })
    let output = FakePracticeOutput()
    let arbiter = PracticeAudioArbiter(coordinator: coordinator, canAcquire: { true },
                                       outputHardware: output, allowedOutputIds: ["fixture"])
    let owner = onMain { arbiter.replaceEngine() }
    let context = (call(arbiter, owner, "bind", ["schemaVersion": 1]) as? [String: Any])?["contextGeneration"] as? Int
    XCTAssertNotNil(context)
    let capture = AudioCaptureStreamer(coordinator: coordinator, arbiter: arbiter, owner: owner)
    onMain {
      XCTAssertNil(capture.onListen(withArguments: ["attemptId": attempt], eventSink: { _ in }))
    }

    let reserved = call(arbiter, owner, "reserve", ownerFields(owner).merging([
      "contextGeneration": context!, "leaseId": outputLease, "side": "output"
    ]) { _, rhs in rhs }) as? [String: Any]
    XCTAssertEqual(reserved?["status"] as? String, "reserved")
    let snap = call(arbiter, owner, "readAllAudioState", ownerFields(owner)) as? [String: Any]
    XCTAssertEqual(snap?["activeSide"] as? String, "output")
    XCTAssertEqual(snap?["allClear"] as? Bool, false)
    XCTAssertEqual(snap?["inputPhase"] as? String, "clear")
    var startAnswer: Any?
    onMain {
      capture.handle(FlutterMethodCall(methodName: "start",
        arguments: ["attemptId": attempt, "sampleRate": 44100])) { startAnswer = $0 }
    }
    XCTAssertEqual((startAnswer as? FlutterError)?.code, "audio_busy")
    XCTAssertEqual(captureHardware.startCalls, 0)
    XCTAssertEqual(output.startCalls, 0)

    let closed = call(arbiter, owner, "closeAll", ownerFields(owner).merging([
      "contextGeneration": context!, "leaseId": outputLease,
      "leaseGeneration": reserved!["leaseGeneration"]!, "reason": "userStop"
    ]) { _, rhs in rhs }) as? [String: Any]
    XCTAssertEqual(closed?["status"] as? String, "closed")
    XCTAssertEqual((closed?["snapshot"] as? [String: Any])?["allClear"] as? Bool, true)
  }

  func testInputReservationAndCaptureBlockOutputReservation() {
    let captureHardware = FakeCaptureHardware()
    let coordinator = AudioCaptureCoordinator(hardware: captureHardware, canCapture: { true })
    let output = FakePracticeOutput()
    let arbiter = PracticeAudioArbiter(coordinator: coordinator, canAcquire: { true },
                                       outputHardware: output, allowedOutputIds: ["fixture"])
    let owner = onMain { arbiter.replaceEngine() }
    let context = (call(arbiter, owner, "bind", ["schemaVersion": 1]) as? [String: Any])?["contextGeneration"] as? Int
    XCTAssertNotNil(context)
    let capture = AudioCaptureStreamer(coordinator: coordinator, arbiter: arbiter, owner: owner)
    onMain {
      XCTAssertNil(capture.onListen(withArguments: ["attemptId": attempt], eventSink: { _ in }))
    }
    let reserved = call(arbiter, owner, "reserve", ownerFields(owner).merging([
      "contextGeneration": context!, "leaseId": inputLease, "side": "input"
    ]) { _, rhs in rhs }) as? [String: Any]
    XCTAssertEqual(reserved?["status"] as? String, "reserved")
    let held = call(arbiter, owner, "readAllAudioState", ownerFields(owner)) as? [String: Any]
    let wrongRecovery = call(arbiter, owner, "recoverAll", ownerFields(owner).merging([
      "expectedStateRevision": held!["stateRevision"]!, "reason": "userRetry"
    ]) { _, rhs in rhs })
    XCTAssertEqual((wrongRecovery as? FlutterError)?.code, "audio_busy")
    let started = expectation(description: "input started")
    var inputArgs = ownerFields(owner)
    inputArgs.merge(["contextGeneration": context!, "leaseId": inputLease,
                     "leaseGeneration": reserved!["leaseGeneration"]!,
                     "attemptId": attempt, "sampleRate": 44100]) { _, rhs in rhs }
    onMain {
      capture.handle(FlutterMethodCall(methodName: "start", arguments: inputArgs)) { answer in
        XCTAssertNil(answer)
        started.fulfill()
      }
    }
    wait(for: [started], timeout: 2)
    waitForPhase("running", coordinator)
    let snapshot = call(arbiter, owner, "readAllAudioState", ownerFields(owner)) as? [String: Any]
    XCTAssertEqual(snapshot?["activeSide"] as? String, "input")
    XCTAssertEqual(snapshot?["inputPhase"] as? String, "running")
    XCTAssertEqual(snapshot?["sessionReleased"] as? Bool, false)
    XCTAssertEqual(snapshot?["allClear"] as? Bool, false)
    let refused = call(arbiter, owner, "reserve", ownerFields(owner).merging([
      "contextGeneration": context!, "leaseId": outputLease, "side": "output"
    ]) { _, rhs in rhs })
    XCTAssertEqual((refused as? FlutterError)?.code, "audio_busy")
    XCTAssertEqual(output.startCalls, 0)
    _ = call(arbiter, owner, "closeAll", ownerFields(owner).merging([
      "contextGeneration": context!, "leaseId": inputLease,
      "leaseGeneration": reserved!["leaseGeneration"]!, "reason": "userStop"
    ]) { _, rhs in rhs })
    waitForPhase("clear", coordinator)
    let clear = call(arbiter, owner, "readAllAudioState", ownerFields(owner)) as? [String: Any]
    XCTAssertEqual(clear?["allClear"] as? Bool, true)
  }

  func testReplacedEngineCannotReadOrStopNewCapture() {
    let coordinator = AudioCaptureCoordinator(hardware: FakeCaptureHardware(), canCapture: { true })
    let arbiter = PracticeAudioArbiter(coordinator: coordinator, canAcquire: { true })
    let oldOwner = onMain { arbiter.replaceEngine() }
    let old = AudioCaptureStreamer(coordinator: coordinator, arbiter: arbiter, owner: oldOwner)
    onMain { XCTAssertNil(old.onListen(withArguments: ["attemptId": attempt], eventSink: { _ in })) }
    let nextOwner = onMain { arbiter.replaceEngine() }
    XCTAssertNotEqual(nextOwner, oldOwner)
    let oldRead = call(arbiter, oldOwner, "readAllAudioState", ownerFields(oldOwner))
    XCTAssertEqual((oldRead as? FlutterError)?.code, "stale_audio_owner")
    var oldStop: Any?
    onMain {
      old.handle(FlutterMethodCall(methodName: "stop", arguments: ["attemptId": attempt])) {
        oldStop = $0
      }
    }
    XCTAssertEqual((oldStop as? FlutterError)?.code, "stale_audio_owner")
    let nextRead = call(arbiter, nextOwner, "readAllAudioState", ownerFields(nextOwner)) as? [String: Any]
    XCTAssertEqual(nextRead?["ownerToken"] as? String, nextOwner.token)
  }

  func testOutputSetupAndReleaseFailuresRemainStickyUntilExplicitRetry() {
    let coordinator = AudioCaptureCoordinator(hardware: FakeCaptureHardware(), canCapture: { true })
    let output = FakePracticeOutput()
    output.failStart = true
    output.failStop = true
    let arbiter = PracticeAudioArbiter(coordinator: coordinator, canAcquire: { true },
                                       outputHardware: output, allowedOutputIds: ["fixture"])
    let owner = onMain { arbiter.replaceEngine() }
    let binding = call(arbiter, owner, "bind", ["schemaVersion": 1]) as? [String: Any]
    let context = binding!["contextGeneration"] as! Int
    let reserved = call(arbiter, owner, "reserve", ownerFields(owner).merging([
      "contextGeneration": context, "leaseId": outputLease, "side": "output"
    ]) { _, rhs in rhs }) as? [String: Any]
    XCTAssertEqual(reserved?["status"] as? String, "reserved")

    let failedStart = expectation(description: "output setup rejected")
    var replyCount = 0
    onMain {
      arbiter.handle(FlutterMethodCall(methodName: "startOutput", arguments:
        ownerFields(owner).merging([
          "contextGeneration": context, "leaseId": outputLease,
          "leaseGeneration": reserved!["leaseGeneration"]!, "assetId": "fixture"
        ]) { _, rhs in rhs }), owner: owner) { answer in
          replyCount += 1
          XCTAssertEqual((answer as? FlutterError)?.code, "audio_close_unconfirmed")
          failedStart.fulfill()
        }
    }
    wait(for: [failedStart], timeout: 2)
    waitForOutputPhase("unconfirmedQuiescent", arbiter, owner)
    let blocked = call(arbiter, owner, "readAllAudioState", ownerFields(owner)) as? [String: Any]
    XCTAssertEqual(blocked?["requiresExplicitRetry"] as? Bool, true)
    XCTAssertEqual(blocked?["allClear"] as? Bool, false)
    XCTAssertEqual(output.startCalls, 1)
    XCTAssertEqual(output.stopCalls, 1)
    XCTAssertEqual(replyCount, 1)

    output.failStop = false
    let retry = call(arbiter, owner, "recoverAll", ownerFields(owner).merging([
      "expectedStateRevision": blocked!["stateRevision"]!, "reason": "userRetry"
    ]) { _, rhs in rhs }) as? [String: Any]
    XCTAssertEqual(retry?["status"] as? String, "pending")
    waitForOutputPhase("clear", arbiter, owner)
    let clear = call(arbiter, owner, "readAllAudioState", ownerFields(owner)) as? [String: Any]
    XCTAssertEqual(clear?["allClear"] as? Bool, true)
    XCTAssertEqual(output.stopCalls, 2)
    XCTAssertEqual(replyCount, 1)
  }

  func testFailedInputDeactivationCannotYieldAllClear() {
    let hardware = FakeCaptureHardware()
    hardware.failuresRemaining = 1
    let coordinator = AudioCaptureCoordinator(hardware: hardware, canCapture: { true })
    let arbiter = PracticeAudioArbiter(coordinator: coordinator, canAcquire: { true })
    let owner = onMain { arbiter.replaceEngine() }
    let capture = AudioCaptureStreamer(coordinator: coordinator, arbiter: arbiter, owner: owner)
    onMain {
      XCTAssertNil(capture.onListen(withArguments: ["attemptId": attempt], eventSink: { _ in }))
    }
    let started = expectation(description: "legacy input started")
    onMain {
      capture.handle(FlutterMethodCall(methodName: "start",
        arguments: ["attemptId": attempt, "sampleRate": 44100])) { answer in
        XCTAssertNil(answer)
        started.fulfill()
      }
    }
    wait(for: [started], timeout: 2)
    waitForPhase("running", coordinator)
    let failed = expectation(description: "session deactivation failed")
    onMain {
      capture.handle(FlutterMethodCall(methodName: "stop", arguments: ["attemptId": attempt])) {
        answer in
        XCTAssertEqual((answer as? FlutterError)?.code, "capture_close_unconfirmed")
        failed.fulfill()
      }
    }
    wait(for: [failed], timeout: 2)
    waitForPhase("unconfirmedQuiescent", coordinator)
    let held = call(arbiter, owner, "readAllAudioState", ownerFields(owner)) as? [String: Any]
    XCTAssertEqual(held?["inputReleased"] as? Bool, false)
    XCTAssertEqual(held?["sessionReleased"] as? Bool, false)
    XCTAssertEqual(held?["requiresExplicitRetry"] as? Bool, true)
    XCTAssertEqual(held?["allClear"] as? Bool, false)
    let refused = call(arbiter, owner, "reserve", ownerFields(owner).merging([
      "contextGeneration": held!["contextGeneration"]!,
      "leaseId": inputLease, "side": "input"
    ]) { _, rhs in rhs })
    XCTAssertEqual((refused as? FlutterError)?.code, "audio_busy")

    _ = call(arbiter, owner, "recoverAll", ownerFields(owner).merging([
      "expectedStateRevision": held!["stateRevision"]!, "reason": "userRetry"
    ]) { _, rhs in rhs })
    waitForPhase("clear", coordinator)
    let clear = call(arbiter, owner, "readAllAudioState", ownerFields(owner)) as? [String: Any]
    XCTAssertEqual(clear?["allClear"] as? Bool, true)
    XCTAssertEqual(hardware.stopCalls, 2)
  }

  func testCloseWhileOutputSetupIsBlockedFencesLateStartAndRepliesOnce() {
    let coordinator = AudioCaptureCoordinator(hardware: FakeCaptureHardware(), canCapture: { true })
    let output = FakePracticeOutput()
    let gate = DispatchSemaphore(value: 0)
    output.startGate = gate
    output.startEntered = expectation(description: "output setup entered")
    let arbiter = PracticeAudioArbiter(coordinator: coordinator, canAcquire: { true },
                                       outputHardware: output, allowedOutputIds: ["fixture"])
    let owner = onMain { arbiter.replaceEngine() }
    let binding = call(arbiter, owner, "bind", ["schemaVersion": 1]) as? [String: Any]
    let context = binding!["contextGeneration"] as! Int
    let reserved = call(arbiter, owner, "reserve", ownerFields(owner).merging([
      "contextGeneration": context, "leaseId": outputLease, "side": "output"
    ]) { _, rhs in rhs }) as? [String: Any]
    XCTAssertEqual(reserved?["status"] as? String, "reserved")
    let closedStart = expectation(description: "late start denied")
    var replies = 0
    let permitFields = ownerFields(owner).merging([
      "contextGeneration": context, "leaseId": outputLease,
      "leaseGeneration": reserved!["leaseGeneration"]!
    ]) { _, rhs in rhs }
    onMain {
      arbiter.handle(FlutterMethodCall(methodName: "startOutput",
                                       arguments: permitFields.merging(["assetId": "fixture"]) { _, rhs in rhs }),
                     owner: owner) { answer in
        replies += 1
        XCTAssertEqual((answer as? FlutterError)?.code, "audio_close_unconfirmed")
        closedStart.fulfill()
      }
    }
    wait(for: [output.startEntered!], timeout: 1)
    let close = call(arbiter, owner, "closeAll", permitFields.merging([
      "reason": "userStop"
    ]) { _, rhs in rhs }) as? [String: Any]
    XCTAssertEqual(close?["status"] as? String, "pending")
    XCTAssertEqual((close?["snapshot"] as? [String: Any])?["allClear"] as? Bool, false)
    gate.signal()
    wait(for: [closedStart], timeout: 2)
    waitForOutputPhase("clear", arbiter, owner)
    let state = call(arbiter, owner, "readAllAudioState", ownerFields(owner)) as? [String: Any]
    XCTAssertEqual(state?["allClear"] as? Bool, true)
    XCTAssertEqual(replies, 1)
    XCTAssertEqual(output.startCalls, 1)
    XCTAssertEqual(output.stopCalls, 1)
  }

  func testCancelledEventSinkRetainsAuthorityForExplicitInputCloseRetry() {
    let hardware = FakeCaptureHardware()
    hardware.failuresRemaining = 1
    let coordinator = AudioCaptureCoordinator(hardware: hardware, canCapture: { true })
    let arbiter = PracticeAudioArbiter(coordinator: coordinator, canAcquire: { true })
    let owner = onMain { arbiter.replaceEngine() }
    let capture = AudioCaptureStreamer(coordinator: coordinator, arbiter: arbiter, owner: owner)
    onMain {
      XCTAssertNil(capture.onListen(withArguments: ["attemptId": attempt], eventSink: { _ in }))
    }
    let started = expectation(description: "input started before stream cancellation")
    onMain {
      capture.handle(FlutterMethodCall(methodName: "start",
        arguments: ["attemptId": attempt, "sampleRate": 44100])) { answer in
        XCTAssertNil(answer)
        started.fulfill()
      }
    }
    wait(for: [started], timeout: 2)
    waitForPhase("running", coordinator)
    onMain {
      XCTAssertNil(capture.onCancel(withArguments: ["attemptId": attempt]))
    }
    waitForPhase("unconfirmedQuiescent", coordinator)
    var ordinaryStop: Any?
    onMain {
      capture.handle(FlutterMethodCall(methodName: "stop",
        arguments: ["attemptId": attempt])) { ordinaryStop = $0 }
    }
    XCTAssertEqual((ordinaryStop as? FlutterError)?.code, "capture_close_unconfirmed")
    let recovered = expectation(description: "explicit input close retry")
    onMain {
      capture.handle(FlutterMethodCall(methodName: "retryStop",
        arguments: ["attemptId": attempt])) { answer in
        XCTAssertNil(answer)
        recovered.fulfill()
      }
    }
    wait(for: [recovered], timeout: 2)
    waitForPhase("clear", coordinator)
    XCTAssertEqual(hardware.stopCalls, 2)
  }

  func testNewOutputRouteFencesReservedInputBeforeCaptureStarts() {
    let coordinator = AudioCaptureCoordinator(hardware: FakeCaptureHardware(), canCapture: { true })
    let arbiter = PracticeAudioArbiter(coordinator: coordinator, canAcquire: { true })
    let owner = onMain { arbiter.replaceEngine() }
    let binding = call(arbiter, owner, "bind", ["schemaVersion": 1]) as! [String: Any]
    let originalContext = binding["contextGeneration"] as! Int
    let reserved = call(arbiter, owner, "reserve", ownerFields(owner).merging([
      "contextGeneration": originalContext, "leaseId": inputLease, "side": "input"
    ]) { _, rhs in rhs }) as? [String: Any]
    XCTAssertEqual(reserved?["status"] as? String, "reserved")
    onMain {
      NotificationCenter.default.post(name: AVAudioSession.routeChangeNotification,
        object: nil, userInfo: [AVAudioSessionRouteChangeReasonKey:
          AVAudioSession.RouteChangeReason.newDeviceAvailable.rawValue])
    }
    let fenced = expectation(description: "new output route fenced reserved input")
    func poll() {
      let state = call(arbiter, owner, "readAllAudioState", ownerFields(owner)) as? [String: Any]
      if (state?["contextGeneration"] as? Int ?? originalContext) > originalContext {
        XCTAssertEqual(state?["allClear"] as? Bool, true)
        fenced.fulfill()
      } else {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01, execute: poll)
      }
    }
    onMain(poll)
    wait(for: [fenced], timeout: 2)
    let oldClaim: [String: Any] = ownerFields(owner).merging([
      "contextGeneration": originalContext, "leaseId": inputLease,
      "leaseGeneration": reserved!["leaseGeneration"]!
    ]) { _, rhs in rhs }
    let rejected = onMain {
      arbiter.claimInputStart(owner: owner, attemptId: attempt, permit: oldClaim)
    }
    XCTAssertNotNil(rejected)
  }
}
