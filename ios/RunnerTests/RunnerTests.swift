import AVFoundation
import Flutter
import XCTest
import video_player_avfoundation
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

  private func call(_ handler: PracticeAudioArbiterHandler, _ method: String,
                    _ arguments: [String: Any]) -> Any? {
    onMain {
      var answer: Any?
      handler.handle(FlutterMethodCall(methodName: method, arguments: arguments)) { answer = $0 }
      return answer
    }
  }

  private func quiescentRebindArguments(_ retired: PracticeAudioOwner) -> [String: Any] {
    ["retiredOwnerToken": retired.token,
      "retiredEngineGeneration": retired.engineGeneration, "reason": "userRetry"]
  }

  private struct VideoRebindFixture {
    let arbiter: PracticeAudioArbiter
    let engine: NSObject
    let retired: PracticeAudioOwner
    let bridge: OstinatoVideoPermitBridge
    let permit: VideoPermitIdentity
    let claim: [String: Any]
    let playerId: Int64
  }

  private func makeVideoRebindFixture(playerId: Int64 = 89) -> VideoRebindFixture {
    let coordinator = AudioCaptureCoordinator(hardware: FakeCaptureHardware(), canCapture: { true })
    let arbiter = PracticeAudioArbiter(coordinator: coordinator, canAcquire: { true },
                                       videoReservationEnabled: true)
    let engine = NSObject()
    let retired = onMain { arbiter.replaceEngine(engineIdentity: engine) }
    let binding = call(arbiter, retired, "bind", ["schemaVersion": 1]) as! [String: Any]
    let context = binding["contextGeneration"] as! Int
    let reserved = call(arbiter, retired, "reserve", ownerFields(retired).merging([
      "contextGeneration": context, "leaseId": outputLease, "side": "video"
    ]) { _, rhs in rhs }) as! [String: Any]
    let generation = reserved["leaseGeneration"] as! Int
    let permit = VideoPermitIdentity(ownerToken: retired.token,
      engineGeneration: Int64(retired.engineGeneration), contextGeneration: Int64(context),
      leaseId: outputLease, leaseGeneration: Int64(generation))
    let bridge = OstinatoVideoPermitBridge(arbiter: arbiter, owner: retired)
    XCTAssertTrue(onMain { try! bridge.withClaimedVideoCreation(
      permit: permit, playerId: playerId, firstSideEffect: {}) })
    return VideoRebindFixture(arbiter: arbiter, engine: engine, retired: retired,
      bridge: bridge, permit: permit, claim: ownerFields(retired).merging([
        "contextGeneration": context, "leaseId": outputLease, "leaseGeneration": generation
      ]) { _, rhs in rhs }, playerId: playerId)
  }

  private func drainVideoRebindCloseDispatch() {
    let drained = expectation(description: "video rebind close dispatch drained")
    onMain { DispatchQueue.main.async { drained.fulfill() } }
    wait(for: [drained], timeout: 1)
  }

  private func settleVideoRebindFixture(_ fixture: VideoRebindFixture,
                                       current: PracticeAudioOwner) {
    drainVideoRebindCloseDispatch()
    XCTAssertTrue(onMain { fixture.bridge.releaseVideoPlayer(
      permit: fixture.permit, playerId: fixture.playerId) })
    _ = call(fixture.arbiter, current, "completeRetiredVideoDispose",
      fixture.claim.merging(["confirmed": true]) { _, rhs in rhs })
    let state = call(fixture.arbiter, current, "readAllAudioState", ownerFields(current)) as! [String: Any]
    let settled = call(fixture.arbiter, current, "recoverAll", ownerFields(current).merging([
      "expectedStateRevision": state["stateRevision"]!, "reason": "userRetry",
      "exactVideoClaim": fixture.claim
    ]) { _, rhs in rhs }) as! [String: Any]
    XCTAssertEqual(settled["status"] as? String, "closed")
  }

  private func legacyStartArguments(
    _ arbiter: PracticeAudioArbiter, _ owner: PracticeAudioOwner
  ) -> [String: Any] {
    let state = call(arbiter, owner, "readAllAudioState", ownerFields(owner)) as! [String: Any]
    return ownerFields(owner).merging([
      "contextGeneration": state["contextGeneration"]!,
      "attemptId": attempt, "sampleRate": 44100
    ]) { _, rhs in rhs }
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
        arguments: legacyStartArguments(arbiter, owner))) { startAnswer = $0 }
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
        arguments: legacyStartArguments(arbiter, owner))) { answer in
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
        arguments: legacyStartArguments(arbiter, owner))) { answer in
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

  func testLegacyMicrophoneRequiresCurrentThreeFieldContextClaim() {
    let hardware = FakeCaptureHardware()
    let coordinator = AudioCaptureCoordinator(hardware: hardware, canCapture: { true })
    let arbiter = PracticeAudioArbiter(coordinator: coordinator, canAcquire: { true })
    let owner = onMain { arbiter.replaceEngine() }
    let capture = AudioCaptureStreamer(coordinator: coordinator, arbiter: arbiter, owner: owner)
    onMain {
      XCTAssertNil(capture.onListen(withArguments: ["attemptId": attempt], eventSink: { _ in }))
    }
    let old = legacyStartArguments(arbiter, owner)
    let oldContext = old["contextGeneration"] as! Int
    let fenced = call(arbiter, owner, "fenceContext", ownerFields(owner).merging([
      "contextGeneration": oldContext, "reason": "routeChange"
    ]) { _, rhs in rhs }) as? [String: Any]
    XCTAssertEqual(fenced?["status"] as? String, "closed")

    let missing: [String: Any] = ["attemptId": attempt, "sampleRate": 44100]
    let partial = old.filter { $0.key != "contextGeneration" }
    for (arguments, code) in [(missing, "bad_args"), (partial, "bad_args"),
                              (old, "audio_lease_required")] {
      var answer: Any?
      onMain {
        capture.handle(FlutterMethodCall(methodName: "start", arguments: arguments)) {
          answer = $0
        }
      }
      XCTAssertEqual((answer as? FlutterError)?.code, code)
      XCTAssertEqual(hardware.startCalls, 0)
    }

    let started = expectation(description: "fresh legacy context starts")
    onMain {
      capture.handle(FlutterMethodCall(methodName: "start",
        arguments: legacyStartArguments(arbiter, owner))) { answer in
        XCTAssertNil(answer)
        started.fulfill()
      }
    }
    wait(for: [started], timeout: 2)
    waitForPhase("running", coordinator)
    XCTAssertEqual(hardware.startCalls, 1)

    let stopped = expectation(description: "fresh legacy context closes")
    onMain {
      capture.handle(FlutterMethodCall(methodName: "stop",
        arguments: ["attemptId": attempt])) { answer in
        XCTAssertNil(answer)
        stopped.fulfill()
      }
    }
    wait(for: [stopped], timeout: 2)
    waitForPhase("clear", coordinator)
  }

  func testVideoReservationIsDisabledByDefaultAndDisposeAcknowledgementExcludesCapture() {
    let coordinator = AudioCaptureCoordinator(hardware: FakeCaptureHardware(), canCapture: { true })
    let disabled = PracticeAudioArbiter(coordinator: coordinator, canAcquire: { true })
    let oldOwner = onMain { disabled.replaceEngine() }
    let disabledContext = (call(disabled, oldOwner, "bind", ["schemaVersion": 1]) as! [String: Any])["contextGeneration"]!
    let denied = call(disabled, oldOwner, "reserve", ownerFields(oldOwner).merging([
      "contextGeneration": disabledContext, "leaseId": outputLease, "side": "video"
    ]) { _, rhs in rhs })
    XCTAssertEqual((denied as? FlutterError)?.code, "video_unavailable")

    let enabledCoordinator = AudioCaptureCoordinator(hardware: FakeCaptureHardware(), canCapture: { true })
    let enabled = PracticeAudioArbiter(coordinator: enabledCoordinator, canAcquire: { true },
                                       videoReservationEnabled: true)
    let owner = onMain { enabled.replaceEngine() }
    let context = (call(enabled, owner, "bind", ["schemaVersion": 1]) as! [String: Any])["contextGeneration"]!
    let permit = call(enabled, owner, "reserve", ownerFields(owner).merging([
      "contextGeneration": context, "leaseId": outputLease, "side": "video"
    ]) { _, rhs in rhs }) as! [String: Any]
    XCTAssertTrue(onMain { enabled.claimVideoPlayer(owner: owner,
      contextGeneration: context as! Int, leaseId: outputLease,
      leaseGeneration: permit["leaseGeneration"] as! Int, playerId: 7) })
    XCTAssertFalse(onMain { enabled.claimVideoPlayer(owner: owner,
      contextGeneration: context as! Int, leaseId: outputLease,
      leaseGeneration: permit["leaseGeneration"] as! Int, playerId: 7) })
    let held = call(enabled, owner, "readAllAudioState", ownerFields(owner)) as! [String: Any]
    XCTAssertEqual(held["activeSide"] as? String, "video")
    XCTAssertEqual(held["videoPhase"] as? String, "reserved")
    XCTAssertEqual(held["videoReleased"] as? Bool, false)
    XCTAssertEqual(held["sessionReleased"] as? Bool, false)
    let capture = AudioCaptureStreamer(coordinator: enabledCoordinator, arbiter: enabled, owner: owner)
    onMain { XCTAssertNil(capture.onListen(withArguments: ["attemptId": attempt], eventSink: { _ in })) }
    var captureAnswer: Any?
    onMain {
      capture.handle(FlutterMethodCall(methodName: "start",
        arguments: legacyStartArguments(enabled, owner))) { captureAnswer = $0 }
    }
    XCTAssertEqual((captureAnswer as? FlutterError)?.code, "audio_busy")
    let fields = ownerFields(owner).merging([
      "contextGeneration": context, "leaseId": outputLease,
      "leaseGeneration": permit["leaseGeneration"]!
    ]) { _, rhs in rhs }
    let close = call(enabled, owner, "closeAll", fields.merging([
      "reason": "userStop"
    ]) { _, rhs in rhs }) as! [String: Any]
    XCTAssertEqual(close["status"] as? String, "pending")
    XCTAssertFalse(onMain { enabled.releaseVideoPlayer(owner: owner,
      contextGeneration: context as! Int, leaseId: outputLease,
      leaseGeneration: permit["leaseGeneration"] as! Int, playerId: 8) })
    XCTAssertTrue(onMain { enabled.releaseVideoPlayer(owner: owner,
      contextGeneration: context as! Int, leaseId: outputLease,
      leaseGeneration: permit["leaseGeneration"] as! Int, playerId: 7) })
    let disposed = call(enabled, owner, "completeVideoDispose", fields.merging([
      "confirmed": true
    ]) { _, rhs in rhs }) as! [String: Any]
    XCTAssertEqual(disposed["status"] as? String, "closed")
    let input = call(enabled, owner, "reserve", ownerFields(owner).merging([
      "contextGeneration": context, "leaseId": inputLease, "side": "input"
    ]) { _, rhs in rhs }) as! [String: Any]
    XCTAssertEqual(input["status"] as? String, "reserved")
    let stale = call(enabled, owner, "completeVideoDispose", fields.merging([
      "confirmed": true
    ]) { _, rhs in rhs }) as! [String: Any]
    XCTAssertEqual(stale["status"] as? String, "stale")
    XCTAssertEqual((stale["snapshot"] as? [String: Any])?["activeSide"] as? String, "input")
  }

  func testHostVideoBridgeRejectsForeignPermitAndReleasesOnlyRetiredExactClaim() {
    let coordinator = AudioCaptureCoordinator(hardware: FakeCaptureHardware(), canCapture: { true })
    let arbiter = PracticeAudioArbiter(coordinator: coordinator, canAcquire: { true },
                                       videoReservationEnabled: true)
    let old = onMain { arbiter.replaceEngine() }
    let context = (call(arbiter, old, "bind", ["schemaVersion": 1]) as! [String: Any])["contextGeneration"] as! Int
    let reservation = call(arbiter, old, "reserve", ownerFields(old).merging([
      "contextGeneration": context, "leaseId": outputLease, "side": "video"
    ]) { _, rhs in rhs }) as! [String: Any]
    let generation = reservation["leaseGeneration"] as! Int
    let exact = VideoPermitIdentity(ownerToken: old.token,
                                    engineGeneration: Int64(old.engineGeneration),
                                    contextGeneration: Int64(context), leaseId: outputLease,
                                    leaseGeneration: Int64(generation))
    let foreign = VideoPermitIdentity(ownerToken: String(repeating: "f", count: 32),
                                      engineGeneration: Int64(old.engineGeneration),
                                      contextGeneration: Int64(context), leaseId: outputLease,
                                      leaseGeneration: Int64(generation))
    let bridge = OstinatoVideoPermitBridge(arbiter: arbiter, owner: old)
    var effects = 0
    let rejected = onMain {
      try? bridge.withClaimedVideoCreation(permit: foreign, playerId: 41) { effects += 1 }
    }
    XCTAssertFalse(rejected ?? true)
    XCTAssertEqual(effects, 0)
    let admitted = onMain {
      try? bridge.withClaimedVideoCreation(permit: exact, playerId: 41) { effects += 1 }
    }
    XCTAssertTrue(admitted ?? false)
    XCTAssertEqual(effects, 1)

    let current = onMain { arbiter.replaceEngine() }
    XCTAssertFalse(onMain { bridge.releaseVideoPlayer(permit: foreign, playerId: 41) })
    XCTAssertFalse(onMain { bridge.releaseVideoPlayer(permit: exact, playerId: 42) })
    XCTAssertTrue(onMain { bridge.releaseVideoPlayer(permit: exact, playerId: 41) })
    XCTAssertFalse(onMain { bridge.releaseVideoPlayer(permit: exact, playerId: 41) })
    let held = call(arbiter, current, "readAllAudioState", ownerFields(current)) as! [String: Any]
    XCTAssertEqual(held["activeSide"] as? String, "video")
    XCTAssertEqual(held["allClear"] as? Bool, false) // Native release is not Dart ACK.
  }

  func testVideoCreationGateRejectsStalePermitAndReentrantFenceKeepsExactClaim() {
    let coordinator = AudioCaptureCoordinator(hardware: FakeCaptureHardware(), canCapture: { true })
    let arbiter = PracticeAudioArbiter(coordinator: coordinator, canAcquire: { true },
                                       videoReservationEnabled: true)
    let owner = onMain { arbiter.replaceEngine() }
    let context = (call(arbiter, owner, "bind", ["schemaVersion": 1]) as! [String: Any])["contextGeneration"] as! Int
    let permit = call(arbiter, owner, "reserve", ownerFields(owner).merging([
      "contextGeneration": context, "leaseId": outputLease, "side": "video"
    ]) { _, rhs in rhs }) as! [String: Any]
    let generation = permit["leaseGeneration"] as! Int
    var effects = 0
    XCTAssertFalse(onMain { arbiter.withClaimedVideoCreation(owner: owner,
      contextGeneration: context + 1, leaseId: outputLease,
      leaseGeneration: generation, playerId: 107) { effects += 1 } })
    XCTAssertEqual(effects, 0)
    XCTAssertFalse(onMain { arbiter.withClaimedVideoCreation(owner: owner,
      contextGeneration: context, leaseId: outputLease,
      leaseGeneration: generation, playerId: 107) {
        effects += 1
        arbiter.closeAllGlobal(reason: "routeChange")
      } })
    XCTAssertEqual(effects, 1)
    let held = call(arbiter, owner, "readAllAudioState", ownerFields(owner)) as! [String: Any]
    XCTAssertEqual(held["activeSide"] as? String, "video")
    XCTAssertFalse(onMain { arbiter.releaseVideoPlayer(owner: owner,
      contextGeneration: context, leaseId: outputLease,
      leaseGeneration: generation, playerId: 108) })
    XCTAssertTrue(onMain { arbiter.releaseVideoPlayer(owner: owner,
      contextGeneration: context, leaseId: outputLease,
      leaseGeneration: generation, playerId: 107) })
  }

  func testReentrantExactReleaseDuringVideoCreationCannotReportSuccessBeforeDartAck() {
    let coordinator = AudioCaptureCoordinator(hardware: FakeCaptureHardware(), canCapture: { true })
    let arbiter = PracticeAudioArbiter(coordinator: coordinator, canAcquire: { true },
                                       videoReservationEnabled: true)
    let owner = onMain { arbiter.replaceEngine() }
    let context = (call(arbiter, owner, "bind", ["schemaVersion": 1]) as! [String: Any])["contextGeneration"] as! Int
    let permit = call(arbiter, owner, "reserve", ownerFields(owner).merging([
      "contextGeneration": context, "leaseId": outputLease, "side": "video"
    ]) { _, rhs in rhs }) as! [String: Any]
    let generation = permit["leaseGeneration"] as! Int
    var released = false
    let created = onMain { arbiter.withClaimedVideoCreation(owner: owner,
      contextGeneration: context, leaseId: outputLease,
      leaseGeneration: generation, playerId: 111) {
        released = arbiter.releaseVideoPlayer(owner: owner,
          contextGeneration: context, leaseId: outputLease,
          leaseGeneration: generation, playerId: 111)
      } }
    XCTAssertTrue(released)
    XCTAssertFalse(created)
    let held = call(arbiter, owner, "readAllAudioState", ownerFields(owner)) as! [String: Any]
    XCTAssertEqual(held["activeSide"] as? String, "video")
    XCTAssertEqual(held["allClear"] as? Bool, false)
    XCTAssertFalse(onMain { arbiter.releaseVideoPlayer(owner: owner,
      contextGeneration: context, leaseId: outputLease,
      leaseGeneration: generation, playerId: 111) })
    let disposed = call(arbiter, owner, "completeVideoDispose", ownerFields(owner).merging([
      "contextGeneration": context, "leaseId": outputLease,
      "leaseGeneration": generation, "confirmed": true
    ]) { _, rhs in rhs }) as! [String: Any]
    XCTAssertEqual(disposed["status"] as? String, "closed")
    XCTAssertEqual((disposed["snapshot"] as? [String: Any])?["allClear"] as? Bool, true)
  }

  func testThrowingVideoCreationGateKeepsClaimUntilExactRelease() {
    enum PartialCreate: Error { case failed }
    let coordinator = AudioCaptureCoordinator(hardware: FakeCaptureHardware(), canCapture: { true })
    let arbiter = PracticeAudioArbiter(coordinator: coordinator, canAcquire: { true },
                                       videoReservationEnabled: true)
    let owner = onMain { arbiter.replaceEngine() }
    let context = (call(arbiter, owner, "bind", ["schemaVersion": 1]) as! [String: Any])["contextGeneration"] as! Int
    let permit = call(arbiter, owner, "reserve", ownerFields(owner).merging([
      "contextGeneration": context, "leaseId": outputLease, "side": "video"
    ]) { _, rhs in rhs }) as! [String: Any]
    let generation = permit["leaseGeneration"] as! Int
    var caught = false
    onMain {
      do {
        _ = try arbiter.withClaimedVideoCreation(owner: owner,
          contextGeneration: context, leaseId: outputLease,
          leaseGeneration: generation, playerId: 109) { throw PartialCreate.failed }
      } catch { caught = true }
    }
    XCTAssertTrue(caught)
    let held = call(arbiter, owner, "readAllAudioState", ownerFields(owner)) as! [String: Any]
    XCTAssertEqual(held["activeSide"] as? String, "video")
    XCTAssertFalse(onMain { arbiter.releaseVideoPlayer(owner: owner,
      contextGeneration: context, leaseId: outputLease,
      leaseGeneration: generation, playerId: 110) })
    XCTAssertTrue(onMain { arbiter.releaseVideoPlayer(owner: owner,
      contextGeneration: context, leaseId: outputLease,
      leaseGeneration: generation, playerId: 109) })
  }

  func testVideoContextFenceRequiresExactReleaseForTimeoutRecovery() {
    let coordinator = AudioCaptureCoordinator(hardware: FakeCaptureHardware(), canCapture: { true })
    let arbiter = PracticeAudioArbiter(coordinator: coordinator, canAcquire: { true },
                                       videoReservationEnabled: true)
    let owner = onMain { arbiter.replaceEngine() }
    let context = (call(arbiter, owner, "bind", ["schemaVersion": 1]) as! [String: Any])["contextGeneration"]!
    let permit = call(arbiter, owner, "reserve", ownerFields(owner).merging([
      "contextGeneration": context, "leaseId": outputLease, "side": "video"
    ]) { _, rhs in rhs }) as! [String: Any]
    XCTAssertTrue(onMain { arbiter.claimVideoPlayer(owner: owner,
      contextGeneration: context as! Int, leaseId: outputLease,
      leaseGeneration: permit["leaseGeneration"] as! Int, playerId: 7) })
    let fields = ownerFields(owner).merging([
      "contextGeneration": context, "leaseId": outputLease,
      "leaseGeneration": permit["leaseGeneration"]!
    ]) { _, rhs in rhs }
    let fence = call(arbiter, owner, "fenceContext", ownerFields(owner).merging([
      "contextGeneration": context, "reason": "accountChange"
    ]) { _, rhs in rhs }) as! [String: Any]
    XCTAssertEqual(fence["status"] as? String, "pending")
    let freshContext = (fence["snapshot"] as! [String: Any])["contextGeneration"]!
    let refused = call(arbiter, owner, "reserve", ownerFields(owner).merging([
      "contextGeneration": freshContext, "leaseId": inputLease, "side": "input"
    ]) { _, rhs in rhs })
    XCTAssertEqual((refused as? FlutterError)?.code, "audio_busy")
    let expired = expectation(description: "video dispose acknowledgement deadline")
    DispatchQueue.main.asyncAfter(deadline: .now() + 2.05) { expired.fulfill() }
    wait(for: [expired], timeout: 3)
    let sticky = call(arbiter, owner, "readAllAudioState", ownerFields(owner)) as! [String: Any]
    XCTAssertEqual(sticky["videoPhase"] as? String, "unconfirmedQuiescent")
    XCTAssertEqual(sticky["requiresExplicitRetry"] as? Bool, true)
    XCTAssertTrue(onMain { arbiter.releaseVideoPlayer(owner: owner,
      contextGeneration: context as! Int, leaseId: outputLease,
      leaseGeneration: permit["leaseGeneration"] as! Int, playerId: 7) })
    let late = call(arbiter, owner, "completeVideoDispose", fields.merging([
      "confirmed": true
    ]) { _, rhs in rhs }) as! [String: Any]
    XCTAssertEqual(late["status"] as? String, "blocked")
    let latest = call(arbiter, owner, "readAllAudioState", ownerFields(owner)) as! [String: Any]
    let recovery = call(arbiter, owner, "recoverAll", ownerFields(owner).merging([
      "expectedStateRevision": latest["stateRevision"]!, "reason": "userRetry"
    ]) { _, rhs in rhs }) as! [String: Any]
    XCTAssertEqual(recovery["status"] as? String, "closed")
  }

  func testEngineReplacementCancelsUnclaimedVideoButClaimedVideoNeedsOldRelease() {
    let coordinator = AudioCaptureCoordinator(hardware: FakeCaptureHardware(), canCapture: { true })
    let arbiter = PracticeAudioArbiter(coordinator: coordinator, canAcquire: { true },
                                       videoReservationEnabled: true)
    let old = onMain { arbiter.replaceEngine() }
    let context = (call(arbiter, old, "bind", ["schemaVersion": 1]) as! [String: Any])["contextGeneration"]!
    let first = call(arbiter, old, "reserve", ownerFields(old).merging([
      "contextGeneration": context, "leaseId": outputLease, "side": "video"
    ]) { _, rhs in rhs }) as! [String: Any]
    let oldFields = ownerFields(old).merging([
      "contextGeneration": context, "leaseId": outputLease,
      "leaseGeneration": first["leaseGeneration"]!
    ]) { _, rhs in rhs }
    let next = onMain { arbiter.replaceEngine() }
    let empty = call(arbiter, next, "readAllAudioState", ownerFields(next)) as! [String: Any]
    XCTAssertEqual(empty["allClear"] as? Bool, true)
    let retiredCancel = call(arbiter, old, "cancelVideoReservation", oldFields)
    XCTAssertEqual((retiredCancel as? FlutterError)?.code, "stale_audio_owner")
    let nextContext = empty["contextGeneration"]!
    let second = call(arbiter, next, "reserve", ownerFields(next).merging([
      "contextGeneration": nextContext, "leaseId": inputLease, "side": "video"
    ]) { _, rhs in rhs }) as! [String: Any]
    XCTAssertEqual(second["status"] as? String, "reserved")

    let coordinator2 = AudioCaptureCoordinator(hardware: FakeCaptureHardware(), canCapture: { true })
    let arbiter2 = PracticeAudioArbiter(coordinator: coordinator2, canAcquire: { true },
                                        videoReservationEnabled: true)
    let heldOwner = onMain { arbiter2.replaceEngine() }
    let heldContext = (call(arbiter2, heldOwner, "bind", ["schemaVersion": 1]) as! [String: Any])["contextGeneration"]!
    let held = call(arbiter2, heldOwner, "reserve", ownerFields(heldOwner).merging([
      "contextGeneration": heldContext, "leaseId": outputLease, "side": "video"
    ]) { _, rhs in rhs }) as! [String: Any]
    XCTAssertTrue(onMain { arbiter2.claimVideoPlayer(owner: heldOwner,
      contextGeneration: heldContext as! Int, leaseId: outputLease,
      leaseGeneration: held["leaseGeneration"] as! Int, playerId: 17) })
    let successor = onMain { arbiter2.replaceEngine() }
    let before = call(arbiter2, successor, "readAllAudioState", ownerFields(successor)) as! [String: Any]
    let denied = call(arbiter2, successor, "recoverAll", ownerFields(successor).merging([
      "expectedStateRevision": before["stateRevision"]!, "reason": "userRetry"
    ]) { _, rhs in rhs }) as! [String: Any]
    XCTAssertEqual(denied["status"] as? String, "blocked")
    XCTAssertFalse(onMain { arbiter2.releaseVideoPlayer(owner: heldOwner,
      contextGeneration: heldContext as! Int, leaseId: inputLease,
      leaseGeneration: held["leaseGeneration"] as! Int, playerId: 17) })
    XCTAssertTrue(onMain { arbiter2.releaseVideoPlayer(owner: heldOwner,
      contextGeneration: heldContext as! Int, leaseId: outputLease,
      leaseGeneration: held["leaseGeneration"] as! Int, playerId: 17) })
    let released = call(arbiter2, successor, "readAllAudioState", ownerFields(successor)) as! [String: Any]
    let recovered = call(arbiter2, successor, "recoverAll", ownerFields(successor).merging([
      "expectedStateRevision": released["stateRevision"]!, "reason": "userRetry"
    ]) { _, rhs in rhs }) as! [String: Any]
    XCTAssertEqual(recovered["status"] as? String, "blocked")
    XCTAssertEqual((recovered["snapshot"] as? [String: Any])?["activeSide"] as? String, "video")
    let successorContext = (recovered["snapshot"] as! [String: Any])["contextGeneration"]!
    let newer = call(arbiter2, successor, "reserve", ownerFields(successor).merging([
      "contextGeneration": successorContext, "leaseId": inputLease, "side": "video"
    ]) { _, rhs in rhs })
    XCTAssertEqual((newer as? FlutterError)?.code, "audio_busy")
  }

  func testEarlyDisposeAcknowledgementWaitsForNativeRelease() {
    let coordinator = AudioCaptureCoordinator(hardware: FakeCaptureHardware(), canCapture: { true })
    let arbiter = PracticeAudioArbiter(coordinator: coordinator, canAcquire: { true },
                                       videoReservationEnabled: true)
    let owner = onMain { arbiter.replaceEngine() }
    let context = (call(arbiter, owner, "bind", ["schemaVersion": 1]) as! [String: Any])["contextGeneration"]!
    let permit = call(arbiter, owner, "reserve", ownerFields(owner).merging([
      "contextGeneration": context, "leaseId": outputLease, "side": "video"
    ]) { _, rhs in rhs }) as! [String: Any]
    let fields = ownerFields(owner).merging([
      "contextGeneration": context, "leaseId": outputLease,
      "leaseGeneration": permit["leaseGeneration"]!
    ]) { _, rhs in rhs }
    XCTAssertTrue(onMain { arbiter.claimVideoPlayer(owner: owner,
      contextGeneration: context as! Int, leaseId: outputLease,
      leaseGeneration: permit["leaseGeneration"] as! Int, playerId: 7) })
    let pending = call(arbiter, owner, "completeVideoDispose", fields.merging([
      "confirmed": true
    ]) { _, rhs in rhs }) as! [String: Any]
    XCTAssertEqual(pending["status"] as? String, "pending")
    XCTAssertEqual((pending["snapshot"] as? [String: Any])?["requiresExplicitRetry"] as? Bool, false)
    XCTAssertTrue(onMain { arbiter.releaseVideoPlayer(owner: owner,
      contextGeneration: context as! Int, leaseId: outputLease,
      leaseGeneration: permit["leaseGeneration"] as! Int, playerId: 7) })
    let closed = call(arbiter, owner, "readAllAudioState", ownerFields(owner)) as! [String: Any]
    XCTAssertEqual(closed["allClear"] as? Bool, true)
  }

  func testVideoCancelAndReusedPlayerIdRequireExactLease() {
    let coordinator = AudioCaptureCoordinator(hardware: FakeCaptureHardware(), canCapture: { true })
    let arbiter = PracticeAudioArbiter(coordinator: coordinator, canAcquire: { true },
                                       videoReservationEnabled: true)
    let owner = onMain { arbiter.replaceEngine() }
    let context = (call(arbiter, owner, "bind", ["schemaVersion": 1]) as! [String: Any])["contextGeneration"]!
    let first = call(arbiter, owner, "reserve", ownerFields(owner).merging([
      "contextGeneration": context, "leaseId": outputLease, "side": "video"
    ]) { _, rhs in rhs }) as! [String: Any]
    let firstFields = ownerFields(owner).merging([
      "contextGeneration": context, "leaseId": outputLease,
      "leaseGeneration": first["leaseGeneration"]!
    ]) { _, rhs in rhs }
    let wrong = call(arbiter, owner, "cancelVideoReservation", firstFields.merging([
      "leaseId": inputLease
    ]) { _, rhs in rhs }) as! [String: Any]
    XCTAssertEqual(wrong["status"] as? String, "stale")
    let fenced = call(arbiter, owner, "fenceContext", ownerFields(owner).merging([
      "contextGeneration": context, "reason": "routeChange"
    ]) { _, rhs in rhs }) as! [String: Any]
    XCTAssertEqual(fenced["status"] as? String, "pending")
    let cancelled = call(arbiter, owner, "cancelVideoReservation", firstFields) as! [String: Any]
    XCTAssertEqual(cancelled["status"] as? String, "closed")

    let nextContext = (cancelled["snapshot"] as! [String: Any])["contextGeneration"]!
    let second = call(arbiter, owner, "reserve", ownerFields(owner).merging([
      "contextGeneration": nextContext, "leaseId": outputLease, "side": "video"
    ]) { _, rhs in rhs }) as! [String: Any]
    let secondFields = ownerFields(owner).merging([
      "contextGeneration": nextContext, "leaseId": outputLease,
      "leaseGeneration": second["leaseGeneration"]!
    ]) { _, rhs in rhs }
    XCTAssertTrue(onMain { arbiter.claimVideoPlayer(owner: owner,
      contextGeneration: nextContext as! Int, leaseId: outputLease,
      leaseGeneration: second["leaseGeneration"] as! Int, playerId: 9) })
    XCTAssertTrue(onMain { arbiter.releaseVideoPlayer(owner: owner,
      contextGeneration: nextContext as! Int, leaseId: outputLease,
      leaseGeneration: second["leaseGeneration"] as! Int, playerId: 9) })
    let disposed = call(arbiter, owner, "completeVideoDispose", secondFields.merging([
      "confirmed": true
    ]) { _, rhs in rhs }) as! [String: Any]
    XCTAssertEqual(disposed["status"] as? String, "closed")
    let third = call(arbiter, owner, "reserve", ownerFields(owner).merging([
      "contextGeneration": nextContext, "leaseId": inputLease, "side": "video"
    ]) { _, rhs in rhs }) as! [String: Any]
    let thirdFields = ownerFields(owner).merging([
      "contextGeneration": nextContext, "leaseId": inputLease,
      "leaseGeneration": third["leaseGeneration"]!
    ]) { _, rhs in rhs }
    XCTAssertTrue(onMain { arbiter.claimVideoPlayer(owner: owner,
      contextGeneration: nextContext as! Int, leaseId: inputLease,
      leaseGeneration: third["leaseGeneration"] as! Int, playerId: 9) })
    XCTAssertFalse(onMain { arbiter.releaseVideoPlayer(owner: owner,
      contextGeneration: nextContext as! Int, leaseId: outputLease,
      leaseGeneration: second["leaseGeneration"] as! Int, playerId: 9) })
    let bare = call(arbiter, owner, "completeVideoDispose", thirdFields.merging([
      "confirmed": true
    ]) { _, rhs in rhs }) as! [String: Any]
    XCTAssertEqual(bare["status"] as? String, "blocked")
    XCTAssertEqual((bare["snapshot"] as? [String: Any])?["allClear"] as? Bool, false)
  }

  func testLostVideoReserveCancellationFencesLateCallAndStaleRevision() {
    let coordinator = AudioCaptureCoordinator(hardware: FakeCaptureHardware(), canCapture: { true })
    let arbiter = PracticeAudioArbiter(coordinator: coordinator, canAcquire: { true },
                                       videoReservationEnabled: true)
    let owner = onMain { arbiter.replaceEngine() }
    let before = call(arbiter, owner, "readAllAudioState", ownerFields(owner)) as! [String: Any]
    let context = before["contextGeneration"] as! Int
    let revision = before["stateRevision"] as! Int
    let fields = ownerFields(owner).merging([
      "attemptOwnerToken": owner.token,
      "attemptEngineGeneration": owner.engineGeneration,
      "attemptContextGeneration": context,
      "leaseId": outputLease,
      "leaseGeneration": NSNull(),
      "expectedStateRevision": revision
    ]) { _, rhs in rhs }
    let stale = call(arbiter, owner, "cancelUnclaimedVideoReservation",
      fields.merging(["expectedStateRevision": revision - 1]) { _, rhs in rhs }) as! [String: Any]
    XCTAssertEqual(stale["status"] as? String, "stale")
    let closed = call(arbiter, owner, "cancelUnclaimedVideoReservation", fields) as! [String: Any]
    XCTAssertEqual(closed["status"] as? String, "closed")
    let late = call(arbiter, owner, "reserve", ownerFields(owner).merging([
      "contextGeneration": context, "leaseId": outputLease, "side": "video"
    ]) { _, rhs in rhs })
    XCTAssertEqual((late as? FlutterError)?.code, "stale_audio_lease")
    let unrelated = call(arbiter, owner, "reserve", ownerFields(owner).merging([
      "contextGeneration": context, "leaseId": inputLease, "side": "video"
    ]) { _, rhs in rhs }) as! [String: Any]
    XCTAssertEqual(unrelated["status"] as? String, "reserved")
  }

  func testUnclaimedVideoFailureCanCancelButClaimedAndNewLeaseStayHeld() {
    let coordinator = AudioCaptureCoordinator(hardware: FakeCaptureHardware(), canCapture: { true })
    let arbiter = PracticeAudioArbiter(coordinator: coordinator, canAcquire: { true },
                                       videoReservationEnabled: true)
    let owner = onMain { arbiter.replaceEngine() }
    let context = (call(arbiter, owner, "bind", ["schemaVersion": 1]) as! [String: Any])["contextGeneration"] as! Int
    let first = call(arbiter, owner, "reserve", ownerFields(owner).merging([
      "contextGeneration": context, "leaseId": outputLease, "side": "video"
    ]) { _, rhs in rhs }) as! [String: Any]
    let firstFields = ownerFields(owner).merging([
      "contextGeneration": context, "leaseId": outputLease,
      "leaseGeneration": first["leaseGeneration"]!
    ]) { _, rhs in rhs }
    let failed = call(arbiter, owner, "completeVideoDispose", firstFields.merging([
      "confirmed": false
    ]) { _, rhs in rhs }) as! [String: Any]
    XCTAssertEqual(failed["status"] as? String, "blocked")
    let cancelled = call(arbiter, owner, "cancelVideoReservation", firstFields) as! [String: Any]
    XCTAssertEqual(cancelled["status"] as? String, "closed")

    let second = call(arbiter, owner, "reserve", ownerFields(owner).merging([
      "contextGeneration": context, "leaseId": inputLease, "side": "video"
    ]) { _, rhs in rhs }) as! [String: Any]
    let secondState = call(arbiter, owner, "readAllAudioState", ownerFields(owner)) as! [String: Any]
    let oldAttempt = ownerFields(owner).merging([
      "attemptOwnerToken": owner.token,
      "attemptEngineGeneration": owner.engineGeneration,
      "attemptContextGeneration": context,
      "leaseId": outputLease,
      "leaseGeneration": first["leaseGeneration"]!,
      "expectedStateRevision": secondState["stateRevision"]!
    ]) { _, rhs in rhs }
    let stale = call(arbiter, owner, "cancelUnclaimedVideoReservation", oldAttempt) as! [String: Any]
    XCTAssertEqual(stale["status"] as? String, "stale")
    XCTAssertTrue(onMain { arbiter.claimVideoPlayer(owner: owner,
      contextGeneration: context, leaseId: inputLease,
      leaseGeneration: second["leaseGeneration"] as! Int, playerId: 9) })
    let claimed = call(arbiter, owner, "readAllAudioState", ownerFields(owner)) as! [String: Any]
    let currentAttempt = oldAttempt.merging([
      "leaseId": inputLease,
      "leaseGeneration": second["leaseGeneration"]!,
      "expectedStateRevision": claimed["stateRevision"]!
    ]) { _, rhs in rhs }
    let denied = call(arbiter, owner, "cancelUnclaimedVideoReservation", currentAttempt) as! [String: Any]
    XCTAssertEqual(denied["status"] as? String, "blocked")
    XCTAssertEqual((denied["snapshot"] as? [String: Any])?["activeSide"] as? String, "video")
    let old = onMain { arbiter.replaceEngine() }
    let retired = call(arbiter, owner, "cancelUnclaimedVideoReservation", currentAttempt)
    XCTAssertEqual((retired as? FlutterError)?.code, "stale_audio_owner")
    let stillHeld = call(arbiter, old, "readAllAudioState", ownerFields(old)) as! [String: Any]
    XCTAssertEqual(stillHeld["activeSide"] as? String, "video")
  }

  func testUnclaimedVideoTimeoutAllowsExactLostReceiptCancellation() {
    let coordinator = AudioCaptureCoordinator(hardware: FakeCaptureHardware(), canCapture: { true })
    let arbiter = PracticeAudioArbiter(coordinator: coordinator, canAcquire: { true },
                                       videoReservationEnabled: true)
    let owner = onMain { arbiter.replaceEngine() }
    let context = (call(arbiter, owner, "bind", ["schemaVersion": 1]) as! [String: Any])["contextGeneration"] as! Int
    let permit = call(arbiter, owner, "reserve", ownerFields(owner).merging([
      "contextGeneration": context, "leaseId": outputLease, "side": "video"
    ]) { _, rhs in rhs }) as! [String: Any]
    _ = call(arbiter, owner, "fenceContext", ownerFields(owner).merging([
      "contextGeneration": context, "reason": "routeChange"
    ]) { _, rhs in rhs })
    let expired = expectation(description: "unclaimed video close deadline")
    DispatchQueue.main.asyncAfter(deadline: .now() + 2.05) { expired.fulfill() }
    wait(for: [expired], timeout: 3)
    let held = call(arbiter, owner, "readAllAudioState", ownerFields(owner)) as! [String: Any]
    XCTAssertEqual(held["videoPhase"] as? String, "unconfirmedQuiescent")
    let cancelled = call(arbiter, owner, "cancelUnclaimedVideoReservation",
      ownerFields(owner).merging([
        "attemptOwnerToken": owner.token,
        "attemptEngineGeneration": owner.engineGeneration,
        "attemptContextGeneration": context,
        "leaseId": outputLease,
        "leaseGeneration": permit["leaseGeneration"]!,
        "expectedStateRevision": held["stateRevision"]!
      ]) { _, rhs in rhs }) as! [String: Any]
    XCTAssertEqual(cancelled["status"] as? String, "closed")
    XCTAssertEqual((cancelled["snapshot"] as? [String: Any])?["allClear"] as? Bool, true)
  }

  func testEarlyVideoAckEngineReplacementLateReleaseAllowsEmptyRetry() {
    let coordinator = AudioCaptureCoordinator(hardware: FakeCaptureHardware(), canCapture: { true })
    let arbiter = PracticeAudioArbiter(coordinator: coordinator, canAcquire: { true },
                                       videoReservationEnabled: true)
    let old = onMain { arbiter.replaceEngine() }
    let context = (call(arbiter, old, "bind", ["schemaVersion": 1]) as! [String: Any])["contextGeneration"] as! Int
    let permit = call(arbiter, old, "reserve", ownerFields(old).merging([
      "contextGeneration": context, "leaseId": outputLease, "side": "video"
    ]) { _, rhs in rhs }) as! [String: Any]
    let generation = permit["leaseGeneration"] as! Int
    XCTAssertTrue(onMain { arbiter.claimVideoPlayer(owner: old,
      contextGeneration: context, leaseId: outputLease,
      leaseGeneration: generation, playerId: 17) })
    let ack = call(arbiter, old, "completeVideoDispose", ownerFields(old).merging([
      "contextGeneration": context, "leaseId": outputLease,
      "leaseGeneration": generation, "confirmed": true
    ]) { _, rhs in rhs }) as! [String: Any]
    XCTAssertEqual(ack["status"] as? String, "pending")
    let current = onMain { arbiter.replaceEngine() }
    XCTAssertTrue(onMain { arbiter.releaseVideoPlayer(owner: old,
      contextGeneration: context, leaseId: outputLease,
      leaseGeneration: generation, playerId: 17) })
    let before = call(arbiter, current, "readAllAudioState", ownerFields(current)) as! [String: Any]
    XCTAssertTrue(before["activeSide"] is NSNull)
    XCTAssertEqual(before["videoPhase"] as? String, "clear")
    XCTAssertEqual(before["requiresExplicitRetry"] as? Bool, true)
    let recovered = call(arbiter, current, "recoverAll", ownerFields(current).merging([
      "expectedStateRevision": before["stateRevision"]!, "reason": "userRetry"
    ]) { _, rhs in rhs }) as! [String: Any]
    XCTAssertEqual(recovered["status"] as? String, "closed")
    XCTAssertEqual((recovered["snapshot"] as? [String: Any])?["allClear"] as? Bool, true)
  }

  func testVideoFenceDispatchesExactNativeCloseWithoutDartAck() {
    let coordinator = AudioCaptureCoordinator(hardware: FakeCaptureHardware(), canCapture: { true })
    let arbiter = PracticeAudioArbiter(coordinator: coordinator, canAcquire: { true },
                                       videoReservationEnabled: true)
    let owner = onMain { arbiter.replaceEngine() }
    let context = (call(arbiter, owner, "bind", ["schemaVersion": 1]) as! [String: Any])["contextGeneration"] as! Int
    let reserved = call(arbiter, owner, "reserve", ownerFields(owner).merging([
      "contextGeneration": context, "leaseId": outputLease, "side": "video"
    ]) { _, rhs in rhs }) as! [String: Any]
    let generation = reserved["leaseGeneration"] as! Int
    let dispatched = expectation(description: "exact native video close dispatched")
    let admitted = onMain { arbiter.withClaimedVideoCreation(
      owner: owner, contextGeneration: context, leaseId: outputLease,
      leaseGeneration: generation, playerId: 71,
      closePort: {
        XCTAssertTrue(arbiter.releaseVideoPlayer(owner: owner,
          contextGeneration: context, leaseId: self.outputLease,
          leaseGeneration: generation, playerId: 71))
        dispatched.fulfill()
        return true
      }, firstSideEffect: {}) }
    XCTAssertTrue(admitted)
    let fence = call(arbiter, owner, "fenceContext", ownerFields(owner).merging([
      "contextGeneration": context, "reason": "accountChange"
    ]) { _, rhs in rhs }) as! [String: Any]
    XCTAssertEqual(fence["status"] as? String, "pending")
    wait(for: [dispatched], timeout: 1)
    let held = call(arbiter, owner, "readAllAudioState", ownerFields(owner)) as! [String: Any]
    XCTAssertEqual(held["activeSide"] as? String, "video")
    let retry = call(arbiter, owner, "recoverAll", ownerFields(owner).merging([
      "expectedStateRevision": held["stateRevision"]!, "reason": "userRetry"
    ]) { _, rhs in rhs }) as! [String: Any]
    XCTAssertEqual(retry["status"] as? String, "blocked")
  }

  func testVideoClosePortFailureDoesNotProduceReleaseReceipt() {
    let coordinator = AudioCaptureCoordinator(hardware: FakeCaptureHardware(), canCapture: { true })
    let arbiter = PracticeAudioArbiter(coordinator: coordinator, canAcquire: { true },
                                       videoReservationEnabled: true)
    let owner = onMain { arbiter.replaceEngine() }
    let context = (call(arbiter, owner, "bind", ["schemaVersion": 1]) as! [String: Any])["contextGeneration"] as! Int
    let reserved = call(arbiter, owner, "reserve", ownerFields(owner).merging([
      "contextGeneration": context, "leaseId": outputLease, "side": "video"
    ]) { _, rhs in rhs }) as! [String: Any]
    let rejected = expectation(description: "native close port rejected")
    XCTAssertTrue(onMain { arbiter.withClaimedVideoCreation(
      owner: owner, contextGeneration: context, leaseId: outputLease,
      leaseGeneration: reserved["leaseGeneration"] as! Int, playerId: 73,
      closePort: { rejected.fulfill(); return false }, firstSideEffect: {}) })
    _ = call(arbiter, owner, "fenceContext", ownerFields(owner).merging([
      "contextGeneration": context, "reason": "routeChange"
    ]) { _, rhs in rhs })
    wait(for: [rejected], timeout: 1)
    let held = call(arbiter, owner, "readAllAudioState", ownerFields(owner)) as! [String: Any]
    XCTAssertEqual(held["activeSide"] as? String, "video")
    XCTAssertEqual(held["requiresExplicitRetry"] as? Bool, true)
    XCTAssertEqual(held["allClear"] as? Bool, false)
  }

  func testRetiredVideoAckReadbackRequiresSameEngineAndBothExactReceipts() {
    let coordinator = AudioCaptureCoordinator(hardware: FakeCaptureHardware(), canCapture: { true })
    let arbiter = PracticeAudioArbiter(coordinator: coordinator, canAcquire: { true },
                                       videoReservationEnabled: true)
    let engine = NSObject()
    let old = onMain { arbiter.replaceEngine(engineIdentity: engine) }
    let context = (call(arbiter, old, "bind", ["schemaVersion": 1]) as! [String: Any])["contextGeneration"] as! Int
    let reserved = call(arbiter, old, "reserve", ownerFields(old).merging([
      "contextGeneration": context, "leaseId": outputLease, "side": "video"
    ]) { _, rhs in rhs }) as! [String: Any]
    let generation = reserved["leaseGeneration"] as! Int
    XCTAssertTrue(onMain { arbiter.claimVideoPlayer(owner: old,
      contextGeneration: context, leaseId: outputLease,
      leaseGeneration: generation, playerId: 79) })
    let current = onMain { arbiter.replaceEngine(engineIdentity: engine) }
    let fields: [String: Any] = [
      "ownerToken": old.token, "engineGeneration": old.engineGeneration,
      "contextGeneration": context, "leaseId": outputLease,
      "leaseGeneration": generation
    ]
    let before = call(arbiter, current, "readVideoDisposeReceipt", fields) as! [String: Any]
    XCTAssertEqual(before["ackStatus"] as? String, "NOT_RECORDED")
    XCTAssertEqual(before["nativeReleaseRecorded"] as? Bool, false)
    XCTAssertTrue(onMain { arbiter.releaseVideoPlayer(owner: old,
      contextGeneration: context, leaseId: outputLease,
      leaseGeneration: generation, playerId: 79) })
    let releaseOnly = call(arbiter, current, "readVideoDisposeReceipt", fields) as! [String: Any]
    XCTAssertEqual(releaseOnly["ackStatus"] as? String, "NOT_RECORDED")
    XCTAssertEqual(releaseOnly["nativeReleaseRecorded"] as? Bool, true)
    let acknowledged = call(arbiter, current, "completeRetiredVideoDispose",
      fields.merging(["confirmed": true]) { _, rhs in rhs }) as! [String: Any]
    XCTAssertEqual(acknowledged["ackStatus"] as? String, "RECORDED")
    XCTAssertEqual(acknowledged["nativeReleaseRecorded"] as? Bool, true)
    XCTAssertEqual(acknowledged["leaseSettled"] as? Bool, false)
    let replay = call(arbiter, current, "readVideoDisposeReceipt", fields) as! [String: Any]
    XCTAssertEqual(replay["ackStatus"] as? String, "RECORDED")
    XCTAssertEqual(replay["leaseSettled"] as? Bool, false)
    let foreign = onMain { arbiter.replaceEngine(engineIdentity: NSObject()) }
    let denied = call(arbiter, foreign, "completeRetiredVideoDispose",
      fields.merging(["confirmed": true]) { _, rhs in rhs })
    XCTAssertEqual((denied as? FlutterError)?.code, "stale_audio_owner")
    let unknown = call(arbiter, foreign, "readVideoDisposeReceipt", fields) as! [String: Any]
    XCTAssertEqual(unknown["ackStatus"] as? String, "UNKNOWN")
  }

  func testQuiescentBridgeRebindUsesStableNativeHandoff() {
    let coordinator = AudioCaptureCoordinator(hardware: FakeCaptureHardware(), canCapture: { true })
    let arbiter = PracticeAudioArbiter(coordinator: coordinator, canAcquire: { true })
    let engine = NSObject()
    let retired = onMain { arbiter.replaceEngine(engineIdentity: engine) }
    let bridge = OstinatoVideoPermitBridge(arbiter: arbiter, owner: retired)
    let oldState = call(arbiter, retired, "readAllAudioState", ownerFields(retired)) as! [String: Any]
    let current = onMain { arbiter.replaceEngine(engineIdentity: engine) }
    var dispatches = 0
    let handler = PracticeAudioArbiterHandler(arbiter: arbiter, owner: current, rebindBridge: {
      dispatches += 1
      return bridge.isQuiescentForRebind()
    })
    let before = call(arbiter, current, "readAllAudioState", ownerFields(current)) as! [String: Any]
    let result = call(handler, "rebindQuiescentOwner", quiescentRebindArguments(retired)) as! [String: Any]
    let proof = result["handoff"] as! [String: Any]
    XCTAssertEqual(result["bridgeReady"] as? Bool, true)
    XCTAssertEqual(proof["retiredContextGeneration"] as? Int, oldState["contextGeneration"] as? Int)
    XCTAssertEqual(proof["retiredStateRevision"] as? Int, oldState["stateRevision"] as? Int)
    XCTAssertTrue((proof["snapshot"] as! NSDictionary).isEqual(before as NSDictionary))
    let first = call(arbiter, current, "readAllAudioState", ownerFields(current)) as! [String: Any]
    let second = call(arbiter, current, "readAllAudioState", ownerFields(current)) as! [String: Any]
    XCTAssertTrue((before as NSDictionary).isEqual(first as NSDictionary))
    XCTAssertTrue((first as NSDictionary).isEqual(second as NSDictionary))
    XCTAssertEqual(dispatches, 1)
  }

  func testQuiescentBridgeRebindRejectsForeignAndSkippedOwners() {
    for foreignEngine in [true, false] {
      let coordinator = AudioCaptureCoordinator(hardware: FakeCaptureHardware(), canCapture: { true })
      let arbiter = PracticeAudioArbiter(coordinator: coordinator, canAcquire: { true })
      let engine = NSObject()
      let retired = onMain { arbiter.replaceEngine(engineIdentity: engine) }
      let second = onMain { arbiter.replaceEngine(engineIdentity: foreignEngine ? NSObject() : engine) }
      let current = foreignEngine ? second : onMain { arbiter.replaceEngine(engineIdentity: engine) }
      var dispatches = 0
      let handler = PracticeAudioArbiterHandler(arbiter: arbiter, owner: current, rebindBridge: {
        dispatches += 1; return true
      })
      let denied = call(handler, "rebindQuiescentOwner", quiescentRebindArguments(retired))
      XCTAssertEqual((denied as? FlutterError)?.code, "quiescent_handoff_unavailable")
      XCTAssertEqual(dispatches, 0)
    }
  }

  func testQuiescentBridgeRebindRejectsHeldCancelledAndBackgroundOwners() {
    for history in ["held", "cancelled", "background"] {
      let coordinator = AudioCaptureCoordinator(hardware: FakeCaptureHardware(), canCapture: { true })
      var foreground = true
      let arbiter = PracticeAudioArbiter(coordinator: coordinator, canAcquire: { foreground },
                                         videoReservationEnabled: true)
      let engine = NSObject()
      let retired = onMain { arbiter.replaceEngine(engineIdentity: engine) }
      let state = call(arbiter, retired, "readAllAudioState", ownerFields(retired)) as! [String: Any]
      if history == "held" {
        _ = call(arbiter, retired, "reserve", ownerFields(retired).merging([
          "contextGeneration": state["contextGeneration"]!, "leaseId": outputLease, "side": "video"
        ]) { _, rhs in rhs })
      } else if history == "cancelled" {
        _ = call(arbiter, retired, "cancelUnclaimedVideoReservation", ownerFields(retired).merging([
          "attemptOwnerToken": retired.token, "attemptEngineGeneration": retired.engineGeneration,
          "attemptContextGeneration": state["contextGeneration"]!, "leaseId": outputLease,
          "leaseGeneration": NSNull(), "expectedStateRevision": state["stateRevision"]!
        ]) { _, rhs in rhs })
      }
      let current = onMain { arbiter.replaceEngine(engineIdentity: engine) }
      if history == "background" { foreground = false }
      let after = call(arbiter, current, "readAllAudioState", ownerFields(current)) as! [String: Any]
      XCTAssertEqual(after["allClear"] as? Bool, true)
      var dispatches = 0
      let handler = PracticeAudioArbiterHandler(arbiter: arbiter, owner: current, rebindBridge: {
        dispatches += 1; return true
      })
      let denied = call(handler, "rebindQuiescentOwner", quiescentRebindArguments(retired))
      XCTAssertEqual((denied as? FlutterError)?.code, "quiescent_handoff_unavailable")
      XCTAssertEqual(dispatches, 0)
    }
  }

  func testExactVideoBridgeRebindRequiresOwnSettledClaimAndReplaysItsReceipt() {
    let fixture = makeVideoRebindFixture()
    let arbiter = fixture.arbiter
    let current = onMain { arbiter.replaceEngine(engineIdentity: fixture.engine) }
    drainVideoRebindCloseDispatch()
    var dispatches = 0
    let handler = PracticeAudioArbiterHandler(arbiter: arbiter, owner: current, rebindBridge: {
      dispatches += 1
      return fixture.bridge.isQuiescentForRebind()
    })
    XCTAssertEqual((call(handler, "rebindVideoPermitBridge", fixture.claim) as? FlutterError)?.code,
                   "video_handoff_pending")
    XCTAssertTrue(onMain { fixture.bridge.releaseVideoPlayer(permit: fixture.permit, playerId: fixture.playerId) })
    XCTAssertEqual((call(handler, "rebindVideoPermitBridge", fixture.claim) as? FlutterError)?.code,
                   "video_handoff_pending")
    _ = call(arbiter, current, "completeRetiredVideoDispose",
      fixture.claim.merging(["confirmed": true]) { _, rhs in rhs })
    XCTAssertEqual((call(handler, "rebindVideoPermitBridge", fixture.claim) as? FlutterError)?.code,
                   "video_handoff_pending")
    XCTAssertEqual(dispatches, 0)
    let held = call(arbiter, current, "readAllAudioState", ownerFields(current)) as! [String: Any]
    _ = call(arbiter, current, "recoverAll", ownerFields(current).merging([
      "expectedStateRevision": held["stateRevision"]!, "reason": "userRetry",
      "exactVideoClaim": fixture.claim
    ]) { _, rhs in rhs })
    XCTAssertFalse(onMain { arbiter.videoBridgeIsQuiescent(owner: fixture.retired,
      contextGeneration: Int(fixture.permit.contextGeneration), leaseId: fixture.permit.leaseId,
      leaseGeneration: Int(fixture.permit.leaseGeneration), playerId: fixture.playerId + 1) })
    let wrong = fixture.claim.merging(["leaseId": inputLease]) { _, rhs in rhs }
    XCTAssertEqual((call(handler, "rebindVideoPermitBridge", wrong) as? FlutterError)?.code,
                   "video_handoff_pending")
    let first = call(handler, "rebindVideoPermitBridge", fixture.claim) as! [String: Any]
    let replay = call(handler, "rebindVideoPermitBridge", fixture.claim) as! [String: Any]
    XCTAssertEqual(first["bridgeReady"] as? Bool, true)
    let ack = first["ack"] as! [String: Any]
    XCTAssertEqual(ack["playerId"] as? Int64, fixture.playerId)
    XCTAssertEqual(ack["ackStatus"] as? String, "RECORDED")
    XCTAssertEqual(ack["nativeReleaseRecorded"] as? Bool, true)
    XCTAssertEqual(ack["leaseSettled"] as? Bool, true)
    XCTAssertTrue((first as NSDictionary).isEqual(replay as NSDictionary))
    XCTAssertEqual(dispatches, 2)
  }

  func testVideoBridgeRebindKeepsCapturedClaimWhenGlobalReceiptChanges() {
    let fixture = makeVideoRebindFixture(playerId: 97)
    let arbiter = fixture.arbiter
    let current = onMain { arbiter.replaceEngine(engineIdentity: fixture.engine) }
    settleVideoRebindFixture(fixture, current: current)
    XCTAssertTrue(onMain { fixture.bridge.isQuiescentForRebind() })
    let state = call(arbiter, current, "readAllAudioState", ownerFields(current)) as! [String: Any]
    let context = state["contextGeneration"] as! Int
    let nextId = String(repeating: "d", count: 32)
    let reserved = call(arbiter, current, "reserve", ownerFields(current).merging([
      "contextGeneration": context, "leaseId": nextId, "side": "video"
    ]) { _, rhs in rhs }) as! [String: Any]
    let generation = reserved["leaseGeneration"] as! Int
    let nextPermit = VideoPermitIdentity(ownerToken: current.token,
      engineGeneration: Int64(current.engineGeneration), contextGeneration: Int64(context),
      leaseId: nextId, leaseGeneration: Int64(generation))
    let nextBridge = OstinatoVideoPermitBridge(arbiter: arbiter, owner: current)
    XCTAssertTrue(onMain { try! nextBridge.withClaimedVideoCreation(
      permit: nextPermit, playerId: 101, firstSideEffect: {}) })
    XCTAssertTrue(onMain { nextBridge.releaseVideoPlayer(permit: nextPermit, playerId: 101) })
    _ = call(arbiter, current, "completeVideoDispose", ownerFields(current).merging([
      "contextGeneration": context, "leaseId": nextId, "leaseGeneration": generation,
      "confirmed": true
    ]) { _, rhs in rhs })
    let clear = call(arbiter, current, "readAllAudioState", ownerFields(current)) as! [String: Any]
    XCTAssertEqual(clear["allClear"] as? Bool, true)
    XCTAssertTrue(onMain { nextBridge.isQuiescentForRebind() })
    XCTAssertFalse(onMain { fixture.bridge.isQuiescentForRebind() })
    var dispatches = 0
    let handler = PracticeAudioArbiterHandler(arbiter: arbiter, owner: current, rebindBridge: {
      dispatches += 1; return true
    })
    XCTAssertEqual((call(handler, "rebindVideoPermitBridge", fixture.claim) as? FlutterError)?.code,
                   "video_handoff_pending")
    XCTAssertEqual(dispatches, 0)
  }

  func testBridgeRebindRejectsChangedCallbacksFailedPortsAndStaleHandlers() {
    for exactVideo in [false, true] {
      for mutation in ["owner", "context", "revision", "failedPort"] {
        let arbiter: PracticeAudioArbiter
        let engine: NSObject
        let retired: PracticeAudioOwner
        let current: PracticeAudioOwner
        let arguments: [String: Any]
        if exactVideo {
          let fixture = makeVideoRebindFixture()
          arbiter = fixture.arbiter; engine = fixture.engine; retired = fixture.retired
          current = onMain { arbiter.replaceEngine(engineIdentity: engine) }
          settleVideoRebindFixture(fixture, current: current)
          arguments = fixture.claim
        } else {
          let coordinator = AudioCaptureCoordinator(hardware: FakeCaptureHardware(), canCapture: { true })
          arbiter = PracticeAudioArbiter(coordinator: coordinator, canAcquire: { true })
          engine = NSObject()
          retired = onMain { arbiter.replaceEngine(engineIdentity: engine) }
          current = onMain { arbiter.replaceEngine(engineIdentity: engine) }
          arguments = quiescentRebindArguments(retired)
        }
        let method = exactVideo ? "rebindVideoPermitBridge" : "rebindQuiescentOwner"
        let changedCode = exactVideo ? "video_handoff_changed" : "quiescent_handoff_changed"
        var dispatches = 0
        let handler = PracticeAudioArbiterHandler(arbiter: arbiter, owner: current, rebindBridge: {
          dispatches += 1
          if mutation == "owner" { arbiter.replaceEngine(engineIdentity: engine) }
          if mutation == "context" { arbiter.closeAllGlobal(reason: "routeChange") }
          if mutation == "revision" {
            let state = self.call(arbiter, current, "readAllAudioState", self.ownerFields(current)) as! [String: Any]
            _ = self.call(arbiter, current, "recoverAll", self.ownerFields(current).merging([
              "expectedStateRevision": state["stateRevision"]!, "reason": "userRetry"
            ]) { _, rhs in rhs })
          }
          return mutation != "failedPort"
        })
        let denied = call(handler, method, arguments)
        XCTAssertEqual((denied as? FlutterError)?.code,
                       mutation == "failedPort" ? "video_bridge_unavailable" : changedCode)
        XCTAssertNil(denied as? [String: Any])
        XCTAssertEqual(dispatches, 1)
        onMain { arbiter.replaceEngine(engineIdentity: engine) }
        XCTAssertEqual((call(handler, method, arguments) as? FlutterError)?.code, "stale_audio_owner")
        XCTAssertEqual(dispatches, 1)
      }
    }
    let coordinator = AudioCaptureCoordinator(hardware: FakeCaptureHardware(), canCapture: { true })
    let arbiter = PracticeAudioArbiter(coordinator: coordinator, canAcquire: { true })
    let engine = NSObject()
    let retired = onMain { arbiter.replaceEngine(engineIdentity: engine) }
    let bridge = OstinatoVideoPermitBridge(arbiter: arbiter, owner: retired)
    let current = onMain { arbiter.replaceEngine(engineIdentity: engine) }
    let handler = PracticeAudioArbiterHandler(arbiter: arbiter, owner: current,
      rebindBridge: { bridge.isQuiescentForRebind() })
    let first = call(handler, "rebindQuiescentOwner", quiescentRebindArguments(retired)) as! [String: Any]
    let replay = call(handler, "rebindQuiescentOwner", quiescentRebindArguments(retired)) as! [String: Any]
    XCTAssertTrue((first as NSDictionary).isEqual(replay as NSDictionary))
  }

  func testExactRetiredUserRetryDispatchesCloseThenSettlesOnlyAfterReadback() {
    let coordinator = AudioCaptureCoordinator(hardware: FakeCaptureHardware(), canCapture: { true })
    let arbiter = PracticeAudioArbiter(coordinator: coordinator, canAcquire: { true },
                                       videoReservationEnabled: true)
    let engine = NSObject()
    let old = onMain { arbiter.replaceEngine(engineIdentity: engine) }
    let context = (call(arbiter, old, "bind", ["schemaVersion": 1]) as! [String: Any])["contextGeneration"] as! Int
    let reserved = call(arbiter, old, "reserve", ownerFields(old).merging([
      "contextGeneration": context, "leaseId": outputLease, "side": "video"
    ]) { _, rhs in rhs }) as! [String: Any]
    let generation = reserved["leaseGeneration"] as! Int
    let first = expectation(description: "first close port rejected")
    let second = expectation(description: "exact close port retried")
    var dispatches = 0
    XCTAssertTrue(onMain { arbiter.withClaimedVideoCreation(
      owner: old, contextGeneration: context, leaseId: outputLease,
      leaseGeneration: generation, playerId: 83,
      closePort: {
        dispatches += 1
        if dispatches == 1 { first.fulfill(); return false }
        XCTAssertTrue(arbiter.releaseVideoPlayer(owner: old,
          contextGeneration: context, leaseId: self.outputLease,
          leaseGeneration: generation, playerId: 83))
        second.fulfill()
        return true
      }, firstSideEffect: {}) })
    _ = call(arbiter, old, "fenceContext", ownerFields(old).merging([
      "contextGeneration": context, "reason": "routeChange"
    ]) { _, rhs in rhs })
    wait(for: [first], timeout: 1)
    let current = onMain { arbiter.replaceEngine(engineIdentity: engine) }
    let claim: [String: Any] = [
      "ownerToken": old.token, "engineGeneration": old.engineGeneration,
      "contextGeneration": context, "leaseId": outputLease,
      "leaseGeneration": generation
    ]
    let ack = call(arbiter, current, "completeRetiredVideoDispose",
      claim.merging(["confirmed": true]) { _, rhs in rhs }) as! [String: Any]
    XCTAssertEqual(ack["ackStatus"] as? String, "RECORDED")
    XCTAssertEqual(ack["nativeReleaseRecorded"] as? Bool, false)
    let held = call(arbiter, current, "readAllAudioState", ownerFields(current)) as! [String: Any]
    let base: [String: Any] = ownerFields(current).merging([
      "expectedStateRevision": held["stateRevision"]!, "reason": "userRetry"
    ]) { _, rhs in rhs }
    let wrong = claim.merging(["leaseId": String(repeating: "d", count: 32)]) { _, rhs in rhs }
    let denied = call(arbiter, current, "recoverAll", base.merging([
      "exactVideoClaim": wrong
    ]) { _, rhs in rhs })
    XCTAssertEqual((denied as? FlutterError)?.code, "stale_audio_lease")
    let broad = call(arbiter, current, "recoverAll", base) as! [String: Any]
    XCTAssertEqual(broad["status"] as? String, "blocked")
    XCTAssertEqual(dispatches, 1)
    let retry = call(arbiter, current, "recoverAll", base.merging([
      "exactVideoClaim": claim
    ]) { _, rhs in rhs }) as! [String: Any]
    XCTAssertEqual(retry["status"] as? String, "blocked")
    wait(for: [second], timeout: 1)
    let released = call(arbiter, current, "readVideoDisposeReceipt", claim) as! [String: Any]
    XCTAssertEqual(released["nativeReleaseRecorded"] as? Bool, true)
    XCTAssertEqual(released["leaseSettled"] as? Bool, false)
    let beforeSettle = call(arbiter, current, "readAllAudioState", ownerFields(current)) as! [String: Any]
    let settled = call(arbiter, current, "recoverAll", ownerFields(current).merging([
      "expectedStateRevision": beforeSettle["stateRevision"]!,
      "reason": "userRetry", "exactVideoClaim": claim
    ]) { _, rhs in rhs }) as! [String: Any]
    XCTAssertEqual(settled["status"] as? String, "closed")
    let final = call(arbiter, current, "readVideoDisposeReceipt", claim) as! [String: Any]
    XCTAssertEqual(final["leaseSettled"] as? Bool, true)
  }
}

// MARK: - F2.1 play + record practice session

private final class FakeDuplexHardware: DuplexCaptureHardware {
  private(set) var modes: [PracticeAudioSessionMode] = []
  private(set) var cues: [[Float]] = []
  private(set) var stopCalls = 0
  var playing = false
  private var duplexChunk: ((Data, Int, Int64, Bool, @escaping () -> Void) -> Void)?
  private var legacyChunk: ((Data, Int, Int64, @escaping () -> Void) -> Void)?

  func start(rate: Int, fence: CaptureFence,
             onChunk: @escaping (Data, Int, Int64, @escaping () -> Void) -> Void) throws -> String {
    modes.append(.recordOnly)
    legacyChunk = onChunk
    return "ios:BuiltInMic"
  }

  func start(rate: Int, mode: PracticeAudioSessionMode, fence: CaptureFence,
             onChunk: @escaping (Data, Int, Int64, Bool, @escaping () -> Void) -> Void) throws -> String {
    modes.append(mode)
    duplexChunk = onChunk
    return "ios:BuiltInMic"
  }

  func playCue(samples: [Float], sampleRate: Int) throws { cues.append(samples) }
  func stop() throws { stopCalls += 1 }

  func emitChunk() {
    let data = Data(repeating: 0, count: 8)
    if let duplex = duplexChunk { duplex(data, 48000, 1, playing) {} }
    else { legacyChunk?(data, 48000, 1) {} }
  }
}

final class PracticeDuplexSessionTests: XCTestCase {
  private let a = String(repeating: "a", count: 32)

  private func onMain(_ work: () -> Void) {
    if Thread.isMainThread { work() } else { DispatchQueue.main.sync(execute: work) }
  }

  private func call(_ handler: AudioCaptureStreamer, _ method: String,
                    _ args: [String: Any]) -> Any? {
    let replied = expectation(description: method)
    var answer: Any?
    onMain {
      handler.handle(FlutterMethodCall(methodName: method, arguments: args)) {
        answer = $0; replied.fulfill()
      }
    }
    wait(for: [replied], timeout: 2)
    return answer
  }

  private func code(_ value: Any?) -> String? { (value as? FlutterError)?.code }

  private func running(_ hardware: CaptureHardware, mode: String?,
                       events: @escaping FlutterEventSink) -> (AudioCaptureCoordinator, AudioCaptureStreamer) {
    let coordinator = AudioCaptureCoordinator(hardware: hardware, deadline: 1, canCapture: { true })
    let handler = AudioCaptureStreamer(coordinator: coordinator)
    onMain { XCTAssertNil(handler.onListen(withArguments: ["attemptId": a], eventSink: events)) }
    var args: [String: Any] = ["attemptId": a, "sampleRate": 48000]
    if let mode = mode { args["sessionMode"] = mode }
    XCTAssertNil(code(call(handler, "start", args)))
    return (coordinator, handler)
  }

  private func cue(_ samples: [Double], rate: Int = 48000) -> [String: Any] {
    let data = samples.withUnsafeBufferPointer { Data(buffer: $0) }
    return ["attemptId": a, "samples": FlutterStandardTypedData(float64: data), "sampleRate": rate]
  }

  private func drainMain() {
    let drained = expectation(description: "main drained")
    DispatchQueue.main.async { drained.fulfill() }
    wait(for: [drained], timeout: 1)
  }

  func testSessionModeConfigurationsAndWire() {
    XCTAssertEqual(PracticeAudioSessionMode.recordOnly.configuration,
      .init(category: .record, mode: .measurement, options: []))
    let duplex = PracticeAudioSessionMode.playAndRecord.configuration
    XCTAssertEqual(duplex.category, .playAndRecord)
    XCTAssertEqual(duplex.mode, .measurement)
    XCTAssertTrue(duplex.options.contains(.defaultToSpeaker))
    XCTAssertTrue(duplex.options.contains(.allowBluetoothA2DP))
    XCTAssertFalse(duplex.options.contains(.allowBluetooth))
    XCTAssertFalse(duplex.options.contains(.mixWithOthers))
    XCTAssertEqual(PracticeAudioSessionMode(wire: nil), .recordOnly)
    XCTAssertEqual(PracticeAudioSessionMode(wire: "playAndRecord"), .playAndRecord)
    XCTAssertNil(PracticeAudioSessionMode(wire: "recordOnly"))
    XCTAssertNil(PracticeAudioSessionMode(wire: 1))
  }

  func testOverlapTrackerCoversScheduledCuesPlusTail() {
    var now: UInt64 = 1_000
    let tracker = PlaybackOverlapTracker(tailNs: 100, now: { now })
    XCTAssertFalse(tracker.isActive)
    tracker.scheduled()
    now += 500
    XCTAssertTrue(tracker.isActive)
    tracker.playedBack()
    now += 50
    XCTAssertTrue(tracker.isActive)
    now += 51
    XCTAssertFalse(tracker.isActive)
    tracker.scheduled(); tracker.reset()
    XCTAssertFalse(tracker.isActive)
  }

  func testRecordOnlyStartKeepsLegacyChunkAndRefusesCue() {
    let hardware = FakeDuplexHardware()
    var chunks: [[String: Any]] = []
    let (_, handler) = running(hardware, mode: nil) { event in
      if let map = event as? [String: Any], map["type"] as? String == "chunk" { chunks.append(map) }
    }
    XCTAssertEqual(hardware.modes, [.recordOnly])
    XCTAssertEqual(code(call(handler, "playCue", cue([0.1]))), "playback_not_enabled")
    hardware.emitChunk(); drainMain()
    XCTAssertEqual(chunks.count, 1)
    XCTAssertNil(chunks.first?["playbackActive"])
    XCTAssertTrue(hardware.cues.isEmpty)
  }

  func testDuplexStartReportsOverlapAndPlaysValidatedCues() {
    let hardware = FakeDuplexHardware()
    var chunks: [[String: Any]] = []
    let (coordinator, handler) = running(hardware, mode: "playAndRecord") { event in
      if let map = event as? [String: Any], map["type"] as? String == "chunk" { chunks.append(map) }
    }
    XCTAssertEqual(hardware.modes, [.playAndRecord])
    hardware.playing = true
    hardware.emitChunk(); drainMain()
    XCTAssertEqual(chunks.first?["playbackActive"] as? Bool, true)

    XCTAssertNil(code(call(handler, "playCue", cue([0, 0.5, -1]))))
    XCTAssertEqual(hardware.cues, [[0, 0.5, -1]])
    XCTAssertEqual(code(call(handler, "playCue", cue([0.1], rate: 44100))), "unsupported_sample_rate")
    XCTAssertEqual(code(call(handler, "playCue", cue([1.5]))), "bad_args")
    XCTAssertEqual(code(call(handler, "playCue", cue([.nan]))), "bad_args")
    XCTAssertEqual(code(call(handler, "playCue", cue([]))), "bad_args")
    XCTAssertEqual(code(call(handler, "playCue",
      cue([Double](repeating: 0, count: 48000 * maxCueSeconds + 1)))), "bad_args")

    XCTAssertNil(code(call(handler, "stop", ["attemptId": a])))
    XCTAssertEqual(coordinator.closeState()["phase"] as? String, "clear")
    XCTAssertEqual(hardware.stopCalls, 1)
    XCTAssertEqual(code(call(handler, "playCue", cue([0.1]))), "playback_unavailable")
    XCTAssertEqual(hardware.cues.count, 1)
  }

  func testDuplexOnRecordOnlyHardwareFailsClosed() {
    let coordinator = AudioCaptureCoordinator(hardware: FakeCaptureHardware(), deadline: 1,
                                              canCapture: { true })
    let handler = AudioCaptureStreamer(coordinator: coordinator)
    onMain { XCTAssertNil(handler.onListen(withArguments: ["attemptId": a], eventSink: { _ in })) }
    XCTAssertEqual(code(call(handler, "start",
      ["attemptId": a, "sampleRate": 48000, "sessionMode": "playAndRecord"])), "playback_unavailable")
    XCTAssertEqual(code(call(handler, "start",
      ["attemptId": a, "sampleRate": 48000, "sessionMode": "bogus"])), "bad_args")
    XCTAssertEqual(coordinator.closeState()["phase"] as? String, "clear")
  }
}
