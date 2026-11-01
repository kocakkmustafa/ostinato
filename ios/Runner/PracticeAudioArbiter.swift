import AVFoundation
import Flutter
import Security
import UIKit

/// The production output backend is deliberately absent until the lesson WAVs
/// and the shared session policy have been accepted separately.
protocol PracticeOutputHardware: AnyObject {
  func start(assetId: String) throws
  func stop() throws
}

/// F2.1: a capture attempt either only records (legacy note observation and
/// tuner gate) or records while the same engine may play short app cues
/// (practice screen). Playback lives inside the input lease; it never has an
/// independent owner and is released with the capture attempt.
enum PracticeAudioSessionMode: String {
  case recordOnly
  case playAndRecord

  struct Configuration: Equatable {
    let category: AVAudioSession.Category
    let mode: AVAudioSession.Mode
    let options: AVAudioSession.CategoryOptions
  }

  /// `.measurement` asks iOS to minimise system input/output processing
  /// (AGC included). Not verified on a device (E44 finding).
  /// Duplex: `.defaultToSpeaker` (otherwise playAndRecord plays from the
  /// receiver), `.allowBluetoothA2DP` (high-quality output to wireless
  /// headphones), and deliberately NO `.allowBluetooth`: HFP would make the
  /// headset's narrow-band microphone the practice input.
  var configuration: Configuration {
    switch self {
    case .recordOnly:
      return Configuration(category: .record, mode: .measurement, options: [])
    case .playAndRecord:
      return Configuration(category: .playAndRecord, mode: .measurement,
                           options: [.defaultToSpeaker, .allowBluetoothA2DP])
    }
  }

  /// Absent key = legacy record-only start. Only `playAndRecord` may be sent.
  init?(wire: Any?) {
    guard let wire = wire else { self = .recordOnly; return }
    guard wire as? String == PracticeAudioSessionMode.playAndRecord.rawValue else { return nil }
    self = .playAndRecord
  }
}

/// The arbiter's shared session policy is the only production writer of
/// AVAudioSession activation. Capture hardware merely requests the input mode.
final class PracticeAudioSessionPolicy {
  static let shared = PracticeAudioSessionPolicy()

  private let session = AVAudioSession.sharedInstance()
  private let lock = NSLock()
  private var inputActive = false

  var isReleased: Bool {
    lock.lock(); defer { lock.unlock() }
    return !inputActive
  }

  func activateInput(rate: Int, fence: CaptureFence,
                     mode: PracticeAudioSessionMode = .recordOnly) throws {
    if fence.isCancelled { throw CaptureHardwareError.cancelled }
    let configuration = mode.configuration
    if mode == .recordOnly {
      // The legacy call is kept verbatim (default options are empty).
      try session.setCategory(.record, mode: .measurement)
    } else {
      try session.setCategory(configuration.category, mode: configuration.mode,
                              options: configuration.options)
    }
    if fence.isCancelled { throw CaptureHardwareError.cancelled }
    try session.setPreferredSampleRate(Double(rate))
    if fence.isCancelled { throw CaptureHardwareError.cancelled }
    try session.setActive(true)
    lock.lock(); inputActive = true; lock.unlock()
    if fence.isCancelled { throw CaptureHardwareError.cancelled }
  }

  func deactivateInput() throws {
    lock.lock()
    let active = inputActive
    lock.unlock()
    guard active else { return }
    // On throw the latch remains active; an explicit retry calls this again.
    try session.setActive(false, options: .notifyOthersOnDeactivation)
    lock.lock(); inputActive = false; lock.unlock()
  }

  var currentInputPort: AVAudioSession.Port? {
    session.currentRoute.inputs.first?.portType
  }

  /// F2.2: hardware output latency of the current route (read only; the session
  /// configuration is unchanged).
  var outputLatencySeconds: Double { session.outputLatency }
}

struct PracticeAudioOwner: Equatable {
  let token: String
  let engineGeneration: Int
  // Native registry identity, never supplied by Dart. A retired Dart success
  // may be carried only across a handoff of this same engine.
  let engineIdentity: AnyObject

  static func == (lhs: PracticeAudioOwner, rhs: PracticeAudioOwner) -> Bool {
    lhs.token == rhs.token && lhs.engineGeneration == rhs.engineGeneration &&
      lhs.engineIdentity === rhs.engineIdentity
  }
}

private struct PracticeVideoClaim: Equatable {
  let owner: PracticeAudioOwner
  let contextGeneration: Int
  let leaseId: String
  let leaseGeneration: Int
  let playerId: Int64
}

private struct PracticeAudioReservation {
  let owner: PracticeAudioOwner
  let contextGeneration: Int
  let leaseId: String
  let leaseGeneration: Int
  let side: String
  let legacyCapture: Bool
}

private struct PracticeQuiescentHandoff {
  let retired: PracticeAudioOwner
  let current: PracticeAudioOwner
  let retiredContextGeneration: Int
  let retiredStateRevision: Int
}

private final class PracticeAudioReply {
  private var result: FlutterResult?

  init(result: @escaping FlutterResult, timeout: TimeInterval, onTimeout: @escaping () -> Void) {
    self.result = result
    DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak self] in
      guard let self = self, self.result != nil else { return }
      self.finish(FlutterError(code: "audio_close_unconfirmed", message: nil, details: nil))
      onTimeout()
    }
  }

  func finish(_ value: Any?) {
    guard let answer = result else { return }
    result = nil
    answer(value)
  }
}

/// All state decisions and capture-coordinator transitions are made on main.
/// Slow hardware work remains on serial workers; an in-flight worker is never
/// treated as released merely because its Flutter reply has timed out.
final class PracticeAudioArbiter {
  static let shared = PracticeAudioArbiter(coordinator: .shared,
                                            sessionPolicy: .shared)

  let coordinator: AudioCaptureCoordinator
  private let canAcquire: () -> Bool
  private let outputHardware: PracticeOutputHardware?
  private let sessionPolicy: PracticeAudioSessionPolicy?
  private let allowedOutputIds: Set<String>
  private let videoReservationEnabled: Bool
  private let outputWorker = DispatchQueue(label: "com.yulalab.ostinato.practice.output")
  private var owner: PracticeAudioOwner?
  private var engineGeneration = 0
  private var contextGeneration = 0
  private var stateRevision = 0
  private var leaseGeneration = 0
  private var reservation: PracticeAudioReservation?
  // A timed-out Dart reserve can reach this main queue after its cancellation.
  // Keep the exact attempt fenced until the engine is replaced.
  private var cancelledVideoAttempts = Set<String>()
  private var reservationClosing = false
  private var outputPhase = "clear"
  private var outputOperationInFlight = false
  private var outputRetryRequired = false
  private var globalRetryRequired = false
  private var outputCloseGeneration = 0
  private var outputCloseScheduled = false
  private var videoPhase = "clear"
  private var videoCloseTimedOut = false
  private var videoRetryRequired = false
  private var videoPlayerId: Int64?
  private var videoPlayerReleased = false
  private var videoDisposeAcknowledged = false
  // The admitted vendor player owns this exact close request. A lifecycle
  // fence must be able to request native disposal without a live Dart isolate.
  private var videoClosePort: (() -> Bool)?
  private var videoCloseDispatchPending = false
  private var releasedVideoReceipt: PracticeVideoClaim?
  private var acknowledgedVideoReceipt: PracticeVideoClaim?
  private var quiescentHandoff: PracticeQuiescentHandoff?
  private var observers: [NSObjectProtocol] = []

  init(
    coordinator: AudioCaptureCoordinator,
    canAcquire: @escaping () -> Bool = { UIApplication.shared.applicationState == .active },
    outputHardware: PracticeOutputHardware? = nil,
    allowedOutputIds: Set<String> = [],
    sessionPolicy: PracticeAudioSessionPolicy? = nil,
    videoReservationEnabled: Bool = false
  ) {
    self.coordinator = coordinator
    self.canAcquire = canAcquire
    self.outputHardware = outputHardware
    self.sessionPolicy = sessionPolicy
    self.allowedOutputIds = allowedOutputIds
    self.videoReservationEnabled = videoReservationEnabled
    coordinator.processArbiter = self
    let center = NotificationCenter.default
    observers.append(center.addObserver(forName: UIApplication.didEnterBackgroundNotification,
                                        object: nil, queue: .main) { [weak self] _ in
      self?.closeAllGlobal(reason: "background")
    })
    observers.append(center.addObserver(forName: AVAudioSession.interruptionNotification,
                                        object: nil, queue: .main) { [weak self] note in
      guard let type = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
            type == AVAudioSession.InterruptionType.began.rawValue else { return }
      self?.closeAllGlobal(reason: "interruption")
    })
    observers.append(center.addObserver(forName: AVAudioSession.routeChangeNotification,
                                        object: nil, queue: .main) { [weak self] note in
      guard let raw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt else { return }
      // Setting our own record category may emit categoryChange during input
      // setup. Other route changes invalidate even a merely reserved lease.
      guard raw != AVAudioSession.RouteChangeReason.categoryChange.rawValue else { return }
      self?.closeAllGlobal(reason: "routeChange")
    })
  }

  deinit { observers.forEach { NotificationCenter.default.removeObserver($0) } }

  private func failure(_ code: String) -> FlutterError {
    FlutterError(code: code, message: nil, details: nil)
  }

  private func isHex32(_ value: String) -> Bool {
    value.count == 32 && value.utf8.allSatisfy {
      (48...57).contains($0) || (97...102).contains($0)
    }
  }

  private func videoAttemptKey(_ token: String, _ engine: Int,
                               _ context: Int, _ id: String) -> String {
    "\(token):\(engine):\(context):\(id)"
  }

  private func newToken() -> String {
    var bytes = [UInt8](repeating: 0, count: 16)
    let status = bytes.withUnsafeMutableBytes { buffer in
      SecRandomCopyBytes(kSecRandomDefault, buffer.count, buffer.baseAddress!)
    }
    precondition(status == errSecSuccess)
    return bytes.map { String(format: "%02x", Int($0)) }.joined()
  }

  /// AppDelegate registers a new implicit engine before either channel is published.
  @discardableResult
  func replaceEngine(engineIdentity: AnyObject = NSObject()) -> PracticeAudioOwner {
    assert(Thread.isMainThread)
    let retired = owner
    let oldClear: [String: Any]?
    if let retired = retired, retired.engineIdentity === engineIdentity,
        reservation == nil, hasNoUnsettledVideoHistory(), cancelledVideoAttempts.isEmpty {
      let state = snapshot(retired)
      oldClear = state["allClear"] as? Bool == true ? state : nil
    } else {
      oldClear = nil
    }
    // A later registration replaces this one-step proof. Retirement itself
    // cannot turn a held reservation into a claim-free handoff.
    quiescentHandoff = nil
    let unclaimedVideo = reservation?.side == "video" && videoPlayerId == nil
    let hadHardware = coordinator.closeState()["phase"] as? String != "clear" ||
      outputPhase == "starting" || outputPhase == "playing" || outputOperationInFlight ||
      (videoPhase != "clear" && !unclaimedVideo)
    owner = nil
    contextGeneration += 1
    stateRevision += 1
    // Main-thread claim and engine replacement are serialized. A video
    // reserve with no admitted player has no native resource to release.
    if unclaimedVideo { clearVideoReservation() }
    cancelledVideoAttempts.removeAll()
    if hadHardware { globalRetryRequired = true }
    closeAllGlobal(reason: "engineReplacement")
    engineGeneration += 1
    let next = PracticeAudioOwner(token: newToken(), engineGeneration: engineGeneration,
                                  engineIdentity: engineIdentity)
    owner = next
    stateRevision += 1
    if let retired = retired, let oldClear = oldClear, reservation == nil,
        hasNoUnsettledVideoHistory(), cancelledVideoAttempts.isEmpty,
        snapshot(next)["allClear"] as? Bool == true {
      quiescentHandoff = PracticeQuiescentHandoff(retired: retired, current: next,
        retiredContextGeneration: oldClear["contextGeneration"] as! Int,
        retiredStateRevision: oldClear["stateRevision"] as! Int)
    }
    return next
  }

  func isCurrent(_ candidate: PracticeAudioOwner) -> Bool { owner == candidate }

  private func currentVideoClaim() -> PracticeVideoClaim? {
    guard let held = reservation, held.side == "video",
          let playerId = videoPlayerId else { return nil }
    return PracticeVideoClaim(owner: held.owner,
      contextGeneration: held.contextGeneration, leaseId: held.leaseId,
      leaseGeneration: held.leaseGeneration, playerId: playerId)
  }

  private func videoClaim(_ args: [String: Any]) -> PracticeVideoClaim? {
    guard let token = args["ownerToken"] as? String, isHex32(token),
          let engine = args["engineGeneration"] as? Int, engine > 0,
          let context = args["contextGeneration"] as? Int, context >= 0,
          let id = args["leaseId"] as? String, isHex32(id),
          let generation = args["leaseGeneration"] as? Int, generation > 0 else { return nil }
    for claim in [currentVideoClaim(), acknowledgedVideoReceipt, releasedVideoReceipt].compactMap({ $0 }) {
      if claim.owner.token == token && claim.owner.engineGeneration == engine &&
          claim.contextGeneration == context && claim.leaseId == id &&
          claim.leaseGeneration == generation { return claim }
    }
    return nil
  }

  private func videoDisposeReceipt(_ args: [String: Any], current: PracticeAudioOwner) -> [String: Any] {
    let claim = videoClaim(args)
    let sameEngine = claim?.owner.engineIdentity === current.engineIdentity
    let exact = sameEngine ? claim : nil
    let ack = exact != nil && acknowledgedVideoReceipt == exact
    let released = exact != nil && releasedVideoReceipt == exact
    let state = snapshot(current)
    return [
      "schemaVersion": 1,
      "ownerToken": args["ownerToken"]!,
      "engineGeneration": args["engineGeneration"]!,
      "contextGeneration": args["contextGeneration"]!,
      "leaseId": args["leaseId"]!,
      "leaseGeneration": args["leaseGeneration"]!,
      "playerId": exact?.playerId as Any? ?? NSNull(),
      "ackStatus": exact == nil ? "UNKNOWN" : (ack ? "RECORDED" : "NOT_RECORDED"),
      "nativeReleaseRecorded": released,
      "leaseSettled": ack && released && reservation == nil &&
        (state["allClear"] as? Bool == true),
      "snapshot": state
    ]
  }

  private func hasNoUnsettledVideoHistory() -> Bool {
    if releasedVideoReceipt == nil && acknowledgedVideoReceipt == nil { return true }
    return releasedVideoReceipt != nil && releasedVideoReceipt == acknowledgedVideoReceipt
  }

  private func clearBridgeOwner(_ bridgeOwner: PracticeAudioOwner) -> PracticeAudioOwner? {
    guard Thread.isMainThread, let current = owner,
          bridgeOwner.engineIdentity === current.engineIdentity, canAcquire(),
          reservation == nil, cancelledVideoAttempts.isEmpty,
          snapshot(current)["allClear"] as? Bool == true, isCurrent(current) else { return nil }
    return current
  }

  /// A bridge that never admitted a player needs the native one-step handoff,
  /// rather than inferring the old owner's state from the new allClear flag.
  func videoBridgeIsQuiescent(owner bridgeOwner: PracticeAudioOwner) -> Bool {
    guard let current = clearBridgeOwner(bridgeOwner), hasNoUnsettledVideoHistory() else { return false }
    if current == bridgeOwner { return true }
    return quiescentHandoff?.retired == bridgeOwner && quiescentHandoff?.current == current
  }

  /// A previously admitted bridge keeps its own exact player proof. A global
  /// receipt for a different player or engine cannot release this bridge.
  func videoBridgeIsQuiescent(owner bridgeOwner: PracticeAudioOwner,
                             contextGeneration context: Int, leaseId: String,
                             leaseGeneration: Int, playerId: Int64) -> Bool {
    guard clearBridgeOwner(bridgeOwner) != nil else { return false }
    let exact = PracticeVideoClaim(owner: bridgeOwner, contextGeneration: context,
      leaseId: leaseId, leaseGeneration: leaseGeneration, playerId: playerId)
    return releasedVideoReceipt == exact && acknowledgedVideoReceipt == exact
  }

  private func quiescentOwnerHandoff(_ args: [String: Any],
                                     current: PracticeAudioOwner) -> [String: Any]? {
    guard isCurrent(current), let handoff = quiescentHandoff,
          handoff.current == current, handoff.retired.engineIdentity === current.engineIdentity,
          args["retiredOwnerToken"] as? String == handoff.retired.token,
          args["retiredEngineGeneration"] as? Int == handoff.retired.engineGeneration,
          handoff.retired.engineGeneration < current.engineGeneration,
          clearBridgeOwner(handoff.retired) != nil, hasNoUnsettledVideoHistory() else { return nil }
    return ["schemaVersion": 1,
      "retiredOwnerToken": handoff.retired.token,
      "retiredEngineGeneration": handoff.retired.engineGeneration,
      "retiredContextGeneration": handoff.retiredContextGeneration,
      "retiredStateRevision": handoff.retiredStateRevision,
      "snapshot": snapshot(current)]
  }

  private func settledVideoHandoff(_ args: [String: Any],
                                  current: PracticeAudioOwner) -> [String: Any]? {
    guard isCurrent(current), let claim = videoClaim(args), claim.owner != current,
          clearBridgeOwner(claim.owner) != nil,
          releasedVideoReceipt == claim, acknowledgedVideoReceipt == claim else { return nil }
    return videoDisposeReceipt(args, current: current)
  }

  func captureIsForeign(to candidate: PracticeAudioOwner) -> Bool {
    guard let held = reservation, held.side == "input" else { return false }
    return held.owner != candidate
  }

  /// Called synchronously from the existing coordinator's phase setter.
  func captureTransition() {
    assert(Thread.isMainThread)
    stateRevision += 1
    if coordinator.closeState()["phase"] as? String == "clear",
       let held = reservation, held.side == "input",
       (held.legacyCapture || reservationClosing) {
      reservation = nil
      reservationClosing = false
      stateRevision += 1
    }
  }

  /// The old capture channel claims this same process owner before it queues
  /// AVAudioEngine work. A legacy start must carry the context captured for
  /// its original action, even while output reservations remain disabled.
  func claimInputStart(
    owner candidate: PracticeAudioOwner?,
    attemptId: String,
    permit: [String: Any]?
  ) -> FlutterError? {
    assert(Thread.isMainThread)
    guard let candidate = candidate, isCurrent(candidate) else {
      return failure("stale_audio_owner")
    }
    if let held = reservation {
      let leasedKeys: Set<String> = ["ownerToken", "engineGeneration",
                                     "contextGeneration", "leaseId", "leaseGeneration"]
      guard let permit = permit,
            held.side == "input", held.owner == candidate,
            held.contextGeneration == contextGeneration,
            !reservationClosing,
            Set(permit.keys) == leasedKeys,
            permit["ownerToken"] as? String == candidate.token,
            permit["engineGeneration"] as? Int == candidate.engineGeneration,
            permit["contextGeneration"] as? Int == held.contextGeneration,
            permit["leaseId"] as? String == held.leaseId,
            permit["leaseGeneration"] as? Int == held.leaseGeneration else {
        return failure("audio_busy")
      }
    } else {
      let legacyKeys: Set<String> = ["ownerToken", "engineGeneration",
                                     "contextGeneration"]
      guard let permit = permit,
            outputHardware == nil, allowedOutputIds.isEmpty,
            Set(permit.keys) == legacyKeys,
            permit["ownerToken"] as? String == candidate.token,
            permit["engineGeneration"] as? Int == candidate.engineGeneration,
            permit["contextGeneration"] as? Int == contextGeneration else {
        return failure("audio_lease_required")
      }
      leaseGeneration += 1
      reservation = PracticeAudioReservation(
        owner: candidate, contextGeneration: contextGeneration,
        leaseId: attemptId, leaseGeneration: leaseGeneration,
        side: "input", legacyCapture: true
      )
      stateRevision += 1
    }
    return nil
  }

  private func inputState() -> (phase: String, released: Bool, inFlight: Bool, retry: Bool) {
    let state = coordinator.closeState()
    let rawPhase = state["phase"] as? String ?? "unconfirmedQuiescent"
    let phase = rawPhase == "clear" && reservation?.side == "input" ? "reserved" : rawPhase
    return (phase,
            state["resourcesReleased"] as? Bool ?? false,
            state["attemptInFlight"] as? Bool ?? true,
            state["requiresExplicitRetry"] as? Bool ?? true)
  }

  private func snapshot(_ caller: PracticeAudioOwner) -> [String: Any] {
    let input = inputState()
    let side = reservation?.side
    let inputReleased = input.released
    let outputReleased = outputPhase == "clear" || outputPhase == "reserved" ||
      outputPhase == "releasedAwaitingExplicitRetry"
    let videoReleased = videoPhase == "clear" && reservation?.side != "video"
    // The input hardware is currently the only production AVAudioSession
    // client. A failed input deactivation makes resourcesReleased=false.
    let sessionReleased = input.released && outputReleased && videoReleased &&
      (sessionPolicy?.isReleased ?? true)
    let inFlight = input.inFlight || outputOperationInFlight || videoPhase == "closing"
    let retry = input.retry || outputRetryRequired || videoRetryRequired || globalRetryRequired
    let allClear = side == nil && input.phase == "clear" && outputPhase == "clear" &&
      videoPhase == "clear" && inputReleased && outputReleased && videoReleased &&
      sessionReleased && !inFlight && !retry
    return [
      "schemaVersion": 1,
      "ownerToken": caller.token,
      "engineGeneration": caller.engineGeneration,
      "contextGeneration": contextGeneration,
      "stateRevision": stateRevision,
      "activeSide": side as Any? ?? NSNull(),
      "activeLeaseGeneration": reservation?.leaseGeneration as Any? ?? NSNull(),
      "inputPhase": input.phase,
      "outputPhase": outputPhase,
      "videoPhase": videoPhase,
      "inputReleased": inputReleased,
      "outputReleased": outputReleased,
      "videoReleased": videoReleased,
      "sessionReleased": sessionReleased,
      "nativeOperationInFlight": inFlight,
      "requiresExplicitRetry": retry,
      "allClear": allClear
    ]
  }

  private func ownerMatches(_ args: [String: Any], _ candidate: PracticeAudioOwner) -> Bool {
    isCurrent(candidate) && args["ownerToken"] as? String == candidate.token &&
      args["engineGeneration"] as? Int == candidate.engineGeneration
  }

  private func currentReservationMatches(_ args: [String: Any], _ candidate: PracticeAudioOwner) -> Bool {
    guard let held = reservation else { return false }
    return held.owner == candidate && ownerMatches(args, candidate) &&
      args["contextGeneration"] as? Int == held.contextGeneration &&
      args["leaseId"] as? String == held.leaseId &&
      args["leaseGeneration"] as? Int == held.leaseGeneration
  }

  /// Future AVFoundation plugin hook. It must run on main before player create,
  /// initialize, or any AVAudioSession mutation. The stock plugin does not
  /// call this hook, so shipping video admission remains disabled.
  func claimVideoPlayer(owner candidate: PracticeAudioOwner, contextGeneration context: Int,
                        leaseId: String, leaseGeneration: Int, playerId: Int64,
                        closePort: (() -> Bool)? = nil) -> Bool {
    guard Thread.isMainThread else { return false }
    guard videoReservationEnabled, isCurrent(candidate), canAcquire(),
          context == contextGeneration, playerId >= 0,
          let held = reservation, held.owner == candidate,
          held.contextGeneration == context, held.leaseId == leaseId,
          held.leaseGeneration == leaseGeneration, held.side == "video",
          videoPhase == "reserved", !reservationClosing,
          videoPlayerId == nil else { return false }
    videoPlayerId = playerId
    videoClosePort = closePort
    releasedVideoReceipt = nil
    acknowledgedVideoReceipt = nil
    stateRevision += 1
    return true
  }

  /// Future plugin bridge entry point. Claim and the first synchronous AV
  /// resource operation share the main-thread turn; a route, engine or account
  /// fence must not be allowed between them. If the operation throws or
  /// re-enters a fence, the exact claimed lease stays held until the plugin's
  /// physical player/texture release callback arrives.
  func withClaimedVideoCreation(owner candidate: PracticeAudioOwner,
                                contextGeneration context: Int, leaseId: String,
                                leaseGeneration: Int, playerId: Int64,
                                closePort: (() -> Bool)? = nil,
                                firstSideEffect: () throws -> Void) rethrows -> Bool {
    guard Thread.isMainThread,
          claimVideoPlayer(owner: candidate, contextGeneration: context,
                           leaseId: leaseId, leaseGeneration: leaseGeneration,
                           playerId: playerId, closePort: closePort) else { return false }
    try firstSideEffect()
    guard isCurrent(candidate), contextGeneration == context,
          let held = reservation, held.owner == candidate,
          held.contextGeneration == context, held.leaseId == leaseId,
          held.leaseGeneration == leaseGeneration, held.side == "video",
          videoPlayerId == playerId, !reservationClosing,
          !videoPlayerReleased else { return false }
    return true
  }

  /// Future AVFoundation plugin hook. The plugin must call this only after
  /// its matching native player and AVAudioSession resources are released.
  func releaseVideoPlayer(owner candidate: PracticeAudioOwner, contextGeneration context: Int,
                          leaseId: String, leaseGeneration: Int, playerId: Int64) -> Bool {
    guard Thread.isMainThread else { return false }
    guard let held = reservation, held.owner == candidate,
          held.contextGeneration == context, held.leaseId == leaseId,
          held.leaseGeneration == leaseGeneration, held.side == "video",
          videoPlayerId == playerId,
          !videoPlayerReleased else { return false }
    videoPlayerReleased = true
    releasedVideoReceipt = currentVideoClaim()
    stateRevision += 1
    settleAcknowledgedVideo()
    return true
  }

  private func clearVideoReservation() {
    assert(Thread.isMainThread)
    reservation = nil
    reservationClosing = false
    videoPhase = "clear"
    videoCloseTimedOut = false
    videoRetryRequired = false
    videoPlayerId = nil
    videoPlayerReleased = false
    videoDisposeAcknowledged = false
    videoClosePort = nil
    videoCloseDispatchPending = false
    stateRevision += 1
  }

  private func settleAcknowledgedVideo() {
    assert(Thread.isMainThread)
    guard let claim = currentVideoClaim(), videoDisposeAcknowledged,
          videoPlayerReleased,
          acknowledgedVideoReceipt == claim,
          releasedVideoReceipt == claim, !videoCloseTimedOut,
          !videoRetryRequired, !videoCloseDispatchPending else { return }
    clearVideoReservation()
  }

  private func requestVideoClose(retry: Bool = false) {
    assert(Thread.isMainThread)
    guard reservation?.side == "video", !videoPlayerReleased,
          !videoCloseDispatchPending,
          videoPhase == "reserved" ||
            (retry && videoPhase == "unconfirmedQuiescent") else { return }
    videoPhase = "closing"
    videoCloseTimedOut = false
    videoRetryRequired = false
    stateRevision += 1
    let expectedLease = reservation?.leaseGeneration
    let expectedPlayer = videoPlayerId
    if let closePort = videoClosePort {
      videoCloseDispatchPending = true
      // The create closure can re-enter a fence. Dispatch after its main turn
      // so a partially configured player is never disposed by this port.
      DispatchQueue.main.async { [weak self] in
        guard let self = self,
              self.reservation?.side == "video",
              self.reservation?.leaseGeneration == expectedLease,
              self.videoPlayerId == expectedPlayer,
              self.videoCloseDispatchPending else { return }
        if self.videoPlayerReleased {
          self.videoCloseDispatchPending = false
          self.settleAcknowledgedVideo()
          return
        }
        let accepted = closePort()
        guard self.reservation?.side == "video",
              self.reservation?.leaseGeneration == expectedLease,
              self.videoPlayerId == expectedPlayer else { return }
        self.videoCloseDispatchPending = false
        if !accepted {
          self.videoRetryRequired = true
          self.videoPhase = "unconfirmedQuiescent"
          self.stateRevision += 1
        } else {
          self.settleAcknowledgedVideo()
        }
      }
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
      guard let self = self, self.reservation?.side == "video",
            self.reservation?.leaseGeneration == expectedLease,
            self.videoPhase == "closing" else { return }
      self.videoCloseTimedOut = true
      self.videoRetryRequired = true
      self.videoPhase = "unconfirmedQuiescent"
      self.stateRevision += 1
    }
  }

  private func receipt(_ candidate: PracticeAudioOwner) -> [String: Any] {
    let state = snapshot(candidate)
    let status = state["allClear"] as? Bool == true ? "closed" :
      (state["nativeOperationInFlight"] as? Bool == true ? "pending" : "blocked")
    return ["status": status, "snapshot": state]
  }

  private func closeCurrentResources() {
    assert(Thread.isMainThread)
    reservationClosing = reservation != nil
    if let id = coordinator.activeAttemptId {
      coordinator.requestStop(id: id, result: nil)
    } else if reservation?.side == "input" {
      reservation = nil
      reservationClosing = false
      stateRevision += 1
    }
    if reservation?.side == "output" {
      if outputPhase == "reserved" {
        outputPhase = "clear"
        reservation = nil
        reservationClosing = false
        stateRevision += 1
      } else if ["starting", "playing", "closing", "unconfirmedQuiescent"].contains(outputPhase),
                !outputCloseScheduled {
        outputPhase = "closing"
        outputOperationInFlight = true
        outputCloseScheduled = true
        outputCloseGeneration += 1
        let closing = outputCloseGeneration
        stateRevision += 1
        outputWorker.async { [weak self] in
          guard let self = self else { return }
          let didRelease: Bool
          do { try self.outputHardware?.stop(); didRelease = true }
          catch { didRelease = false }
          DispatchQueue.main.async { [weak self] in
            guard let self = self, self.outputCloseGeneration == closing else { return }
            self.outputOperationInFlight = false
            self.outputCloseScheduled = false
            self.outputPhase = didRelease ? "clear" : "unconfirmedQuiescent"
            self.outputRetryRequired = !didRelease
            if didRelease { self.reservation = nil; self.reservationClosing = false }
            self.stateRevision += 1
          }
        }
      }
    }
    requestVideoClose()
  }

  func closeAllGlobal(reason: String) {
    assert(Thread.isMainThread)
    // Lifecycle and engine replacement may act even if the Dart engine hangs.
    contextGeneration += 1
    stateRevision += 1
    closeCurrentResources()
  }

  func handle(_ call: FlutterMethodCall, owner candidate: PracticeAudioOwner,
              rebindBridge: (() -> Bool)? = nil, result: @escaping FlutterResult) {
    assert(Thread.isMainThread)
    guard isCurrent(candidate) else { result(failure("stale_audio_owner")); return }
    let args = call.arguments as? [String: Any] ?? [:]
    if call.method == "bind" {
      guard args["schemaVersion"] as? Int == 1 else { result(failure("bad_args")); return }
      result(["schemaVersion": 1, "ownerToken": candidate.token,
              "engineGeneration": candidate.engineGeneration,
              "contextGeneration": contextGeneration, "stateRevision": stateRevision])
      return
    }
    let exactRetiredVideoMethod = call.method == "completeRetiredVideoDispose" ||
      call.method == "readVideoDisposeReceipt" ||
      call.method == "rebindVideoPermitBridge" ||
      call.method == "rebindQuiescentOwner"
    guard exactRetiredVideoMethod || ownerMatches(args, candidate) else {
      result(failure("stale_audio_owner")); return
    }
    switch call.method {
    case "completeRetiredVideoDispose":
      let requiredKeys: Set<String> = ["ownerToken", "engineGeneration",
        "contextGeneration", "leaseId", "leaseGeneration", "confirmed"]
      guard Set(args.keys) == requiredKeys,
            args["confirmed"] as? Bool == true,
            let claim = videoClaim(args),
            claim.owner.engineIdentity === candidate.engineIdentity,
            claim.owner != candidate else {
        result(failure("stale_audio_owner")); return
      }
      if currentVideoClaim() == claim && !videoDisposeAcknowledged {
        videoDisposeAcknowledged = true
        acknowledgedVideoReceipt = claim
        stateRevision += 1
        settleAcknowledgedVideo()
      } else if acknowledgedVideoReceipt != claim {
        result(failure("stale_audio_lease")); return
      }
      result(videoDisposeReceipt(args, current: candidate))
    case "readVideoDisposeReceipt":
      let requiredKeys: Set<String> = ["ownerToken", "engineGeneration",
        "contextGeneration", "leaseId", "leaseGeneration"]
      guard Set(args.keys) == requiredKeys,
            let token = args["ownerToken"] as? String, isHex32(token),
            let id = args["leaseId"] as? String, isHex32(id),
            args["engineGeneration"] as? Int != nil,
            args["contextGeneration"] as? Int != nil,
            args["leaseGeneration"] as? Int != nil else {
        result(failure("bad_args")); return
      }
      result(videoDisposeReceipt(args, current: candidate))
    case "rebindVideoPermitBridge":
      let keys: Set<String> = ["ownerToken", "engineGeneration", "contextGeneration",
        "leaseId", "leaseGeneration"]
      guard Set(args.keys) == keys else { result(failure("bad_args")); return }
      guard let before = settledVideoHandoff(args, current: candidate) else {
        result(failure("video_handoff_pending")); return
      }
      guard let rebind = rebindBridge, rebind() else {
        result(failure("video_bridge_unavailable")); return
      }
      guard isCurrent(candidate), let after = settledVideoHandoff(args, current: candidate),
            (before as NSDictionary).isEqual(after as NSDictionary) else {
        result(failure("video_handoff_changed")); return
      }
      result(["schemaVersion": 1, "bridgeReady": true, "ack": after])
    case "rebindQuiescentOwner":
      let keys: Set<String> = ["retiredOwnerToken", "retiredEngineGeneration", "reason"]
      guard Set(args.keys) == keys, args["reason"] as? String == "userRetry",
            let token = args["retiredOwnerToken"] as? String, isHex32(token),
            let generation = args["retiredEngineGeneration"] as? Int, generation > 0 else {
        result(failure("bad_args")); return
      }
      guard let before = quiescentOwnerHandoff(args, current: candidate) else {
        result(failure("quiescent_handoff_unavailable")); return
      }
      guard let rebind = rebindBridge, rebind() else {
        result(failure("video_bridge_unavailable")); return
      }
      guard isCurrent(candidate), let after = quiescentOwnerHandoff(args, current: candidate),
            (before as NSDictionary).isEqual(after as NSDictionary) else {
        result(failure("quiescent_handoff_changed")); return
      }
      result(["schemaVersion": 1, "bridgeReady": true, "handoff": after])
    case "readAllAudioState":
      result(snapshot(candidate))
    case "reserve":
      guard let id = args["leaseId"] as? String, isHex32(id),
            let side = args["side"] as? String,
            ["input", "output", "video"].contains(side),
            args["contextGeneration"] as? Int == contextGeneration else {
        result(failure("bad_args")); return
      }
      if side == "video" && cancelledVideoAttempts.contains(videoAttemptKey(
          candidate.token, candidate.engineGeneration, contextGeneration, id)) {
        result(failure("stale_audio_lease")); return
      }
      guard canAcquire(), snapshot(candidate)["allClear"] as? Bool == true else {
        result(failure("audio_busy")); return
      }
      guard side != "output" || (outputHardware != nil && !allowedOutputIds.isEmpty) else {
        result(failure("audio_output_unavailable")); return
      }
      guard side != "video" || videoReservationEnabled else {
        result(failure("video_unavailable")); return
      }
      leaseGeneration += 1
      reservation = PracticeAudioReservation(owner: candidate,
        contextGeneration: contextGeneration, leaseId: id,
        leaseGeneration: leaseGeneration, side: side, legacyCapture: false)
      reservationClosing = false
      if side == "output" { outputPhase = "reserved" }
      if side == "video" {
        videoPhase = "reserved"
        videoCloseTimedOut = false
        videoRetryRequired = false
        videoPlayerId = nil
        videoPlayerReleased = false
        videoDisposeAcknowledged = false
        videoClosePort = nil
        videoCloseDispatchPending = false
      }
      stateRevision += 1
      result(["status": "reserved", "leaseId": id,
              "leaseGeneration": leaseGeneration, "stateRevision": stateRevision])
    case "startOutput":
      guard currentReservationMatches(args, candidate),
            reservation?.side == "output", outputPhase == "reserved",
            let assetId = args["assetId"] as? String,
            allowedOutputIds.contains(assetId), outputHardware != nil,
            canAcquire() else { result(failure("audio_output_unavailable")); return }
      outputPhase = "starting"
      outputOperationInFlight = true
      stateRevision += 1
      let expectedContext = contextGeneration
      let expectedLease = reservation?.leaseGeneration
      let reply = PracticeAudioReply(result: result, timeout: 2) { [weak self] in
        guard let self = self, self.outputPhase == "starting",
              self.contextGeneration == expectedContext,
              self.reservation?.leaseGeneration == expectedLease else { return }
        self.closeCurrentResources()
      }
      outputWorker.async { [weak self] in
        guard let self = self else { return }
        let failure: Error?
        do { try self.outputHardware?.start(assetId: assetId); failure = nil }
        catch { failure = error }
        DispatchQueue.main.async { [weak self] in
          guard let self = self else { return }
          guard failure == nil, self.outputPhase == "starting",
                self.contextGeneration == expectedContext,
                self.reservation?.leaseGeneration == expectedLease else {
            if self.outputPhase == "starting" { self.outputPhase = "closing" }
            self.stateRevision += 1
            self.closeCurrentResources()
            reply.finish(self.failure("audio_close_unconfirmed"))
            return
          }
          self.outputOperationInFlight = false
          self.outputPhase = "playing"
          self.stateRevision += 1
          reply.finish(["status": "playing", "leaseId": self.reservation!.leaseId,
                        "leaseGeneration": self.reservation!.leaseGeneration,
                        "stateRevision": self.stateRevision])
        }
      }
    case "closeAll":
      guard let reason = args["reason"] as? String,
            ["userStop", "routeChange", "accountChange"].contains(reason) else {
        result(failure("bad_args")); return
      }
      guard currentReservationMatches(args, candidate) else {
        let state = snapshot(candidate)
        // A stale ticket may observe a genuinely empty process. Dart's
        // strict receipt parser only accepts `stale` when something remains
        // held; either result is read-only for this old ticket.
        result(["status": state["allClear"] as? Bool == true ? "closed" : "stale",
                "snapshot": state]); return
      }
      closeCurrentResources()
      result(receipt(candidate))
    case "completeVideoDispose":
      let requiredKeys: Set<String> = ["ownerToken", "engineGeneration",
        "contextGeneration", "leaseId", "leaseGeneration", "confirmed"]
      guard Set(args.keys) == requiredKeys,
            let held = reservation, held.side == "video", held.owner == candidate,
            args["contextGeneration"] as? Int == held.contextGeneration,
            args["leaseId"] as? String == held.leaseId,
            args["leaseGeneration"] as? Int == held.leaseGeneration,
            let confirmed = args["confirmed"] as? Bool else {
        result(["status": "stale", "snapshot": snapshot(candidate)]); return
      }
      if !confirmed {
        reservationClosing = true
        videoRetryRequired = true
        videoPhase = "unconfirmedQuiescent"
        stateRevision += 1
        result(receipt(candidate)); return
      }
      videoDisposeAcknowledged = true
      acknowledgedVideoReceipt = currentVideoClaim()
      stateRevision += 1
      settleAcknowledgedVideo()
      if reservation?.side == "video" && !videoCloseTimedOut && !videoRetryRequired &&
          videoPhase == "reserved" { closeCurrentResources() }
      result(receipt(candidate))
    case "cancelVideoReservation":
      let requiredKeys: Set<String> = ["ownerToken", "engineGeneration",
        "contextGeneration", "leaseId", "leaseGeneration"]
      guard Set(args.keys) == requiredKeys,
            currentReservationMatches(args, candidate),
            reservation?.side == "video" else {
        result(["status": "stale", "snapshot": snapshot(candidate)]); return
      }
      guard videoPlayerId == nil else {
        result(["status": "blocked", "snapshot": snapshot(candidate)]); return
      }
      clearVideoReservation()
      result(receipt(candidate))
    case "cancelUnclaimedVideoReservation":
      let requiredKeys: Set<String> = ["ownerToken", "engineGeneration",
        "attemptOwnerToken", "attemptEngineGeneration", "attemptContextGeneration",
        "leaseId", "leaseGeneration", "expectedStateRevision"]
      guard Set(args.keys) == requiredKeys,
            let attemptToken = args["attemptOwnerToken"] as? String,
            isHex32(attemptToken),
            let attemptEngine = args["attemptEngineGeneration"] as? Int,
            attemptEngine > 0,
            let attemptContext = args["attemptContextGeneration"] as? Int,
            attemptContext >= 0, attemptContext <= contextGeneration,
            let id = args["leaseId"] as? String, isHex32(id),
            let revision = args["expectedStateRevision"] as? Int,
            revision >= 0 else { result(failure("bad_args")); return }
      guard revision == stateRevision else {
        result(["status": "stale", "snapshot": snapshot(candidate)]); return
      }
      let suppliedGeneration = args["leaseGeneration"] as? Int
      if let held = reservation {
        guard held.side == "video", suppliedGeneration != nil,
              held.owner.token == attemptToken,
              held.owner.engineGeneration == attemptEngine,
              held.contextGeneration == attemptContext, held.leaseId == id,
              held.leaseGeneration == suppliedGeneration else {
          result(["status": "stale", "snapshot": snapshot(candidate)]); return
        }
        guard videoPlayerId == nil else {
          result(["status": "blocked", "snapshot": snapshot(candidate)]); return
        }
        clearVideoReservation()
      } else {
        guard args["leaseGeneration"] is NSNull else {
          result(["status": "stale", "snapshot": snapshot(candidate)]); return
        }
      }
      if attemptToken == candidate.token && attemptEngine == candidate.engineGeneration {
        cancelledVideoAttempts.insert(videoAttemptKey(attemptToken,
          attemptEngine, attemptContext, id))
      }
      stateRevision += 1
      result(receipt(candidate))
    case "fenceContext":
      guard args["contextGeneration"] as? Int == contextGeneration,
            let reason = args["reason"] as? String,
            ["routeChange", "accountChange", "background"].contains(reason) else {
        result(failure("stale_audio_context")); return
      }
      contextGeneration += 1
      stateRevision += 1
      closeCurrentResources()
      let response = receipt(candidate)
      result(["contextGeneration": contextGeneration,
              "stateRevision": stateRevision,
              "status": response["status"]!, "snapshot": response["snapshot"]!])
    case "recoverAll":
      guard args["reason"] as? String == "userRetry",
            let revision = args["expectedStateRevision"] as? Int,
            revision == stateRevision else { result(failure("stale_audio_state")); return }
      var exactRetryClaim: PracticeVideoClaim?
      if let supplied = args["exactVideoClaim"] {
        let keys: Set<String> = ["ownerToken", "engineGeneration",
          "contextGeneration", "leaseId", "leaseGeneration"]
        guard let fields = supplied as? [String: Any], Set(fields.keys) == keys,
              let claim = videoClaim(fields),
              claim.owner.engineIdentity === candidate.engineIdentity,
              (currentVideoClaim() == claim ||
                (reservation == nil &&
                  acknowledgedVideoReceipt == claim &&
                  releasedVideoReceipt == claim)) else {
          result(failure("stale_audio_lease")); return
        }
        exactRetryClaim = claim
      }
      let input = inputState()
      if reservation?.side == "video" {
        // Only the exact native player release hook can make an old-engine or
        // timed-out video lease recoverable. The current Dart bool is never
        // enough to infer a physical release.
        guard let claim = currentVideoClaim(), videoPlayerReleased,
              videoDisposeAcknowledged,
              releasedVideoReceipt == claim,
              acknowledgedVideoReceipt == claim,
              !videoCloseDispatchPending, !input.inFlight,
              !outputOperationInFlight,
              input.phase == "clear", outputPhase == "clear" else {
          if let claim = currentVideoClaim(), exactRetryClaim == claim,
              videoDisposeAcknowledged, acknowledgedVideoReceipt == claim,
              !videoPlayerReleased && videoClosePort != nil &&
              videoRetryRequired && !videoCloseDispatchPending {
            requestVideoClose(retry: true)
          }
          result(["status": "blocked", "snapshot": snapshot(candidate)]); return
        }
        clearVideoReservation()
        if sessionPolicy?.isReleased ?? true { globalRetryRequired = false }
        result(receipt(candidate)); return
      }
      guard reservation?.side != "video", videoPhase == "clear",
            !input.inFlight, !outputOperationInFlight,
            input.phase != "starting", input.phase != "running",
            outputPhase != "starting", outputPhase != "playing" else {
        result(receipt(candidate)); return
      }
      guard reservationClosing ||
              (input.phase != "reserved" && outputPhase != "reserved") else {
        result(failure("audio_busy")); return
      }
      if let id = coordinator.activeAttemptId {
        coordinator.requestStop(id: id, result: nil, explicitRetry: true)
      } else if outputPhase == "unconfirmedQuiescent" {
        closeCurrentResources()
      }
      if coordinator.closeState()["phase"] as? String == "clear" && outputPhase == "clear" {
        reservation = nil
        reservationClosing = false
        globalRetryRequired = false
        outputRetryRequired = false
        stateRevision += 1
      }
      result(receipt(candidate))
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

/// A handler's immutable owner prevents late callbacks from an old implicit
/// engine from acting on the new process owner, even if they know a lease ID.
final class PracticeAudioArbiterHandler {
  private let arbiter: PracticeAudioArbiter
  private let owner: PracticeAudioOwner
  private let rebindBridge: (() -> Bool)?

  init(arbiter: PracticeAudioArbiter, owner: PracticeAudioOwner,
       rebindBridge: (() -> Bool)? = nil) {
    self.arbiter = arbiter
    self.owner = owner
    self.rebindBridge = rebindBridge
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    arbiter.handle(call, owner: owner, rebindBridge: rebindBridge, result: result)
  }
}
