import AVFoundation
import Flutter
import UIKit

/// A stop request can fence callbacks while hardware startup is still blocked.
final class CaptureFence {
  private let lock = NSLock()
  private var cancelled = false
  func cancel() { lock.lock(); cancelled = true; lock.unlock() }
  var isCancelled: Bool {
    lock.lock(); defer { lock.unlock() }
    return cancelled
  }
}

enum CaptureHardwareError: Error, Equatable { case cancelled, unsupportedRate }

/// A fake can exercise the coordinator without requesting microphone access.
protocol CaptureHardware: AnyObject {
  func start(
    rate: Int,
    fence: CaptureFence,
    onChunk: @escaping (Data, Int, Int64, @escaping () -> Void) -> Void
  ) throws -> String
  func stop() throws
}

/// F2.1: capture hardware that can also play short cues inside the same
/// attempt. The extra Bool on each chunk is "app output may have been audible
/// during this window" (for a later low-confidence mark).
protocol DuplexCaptureHardware: CaptureHardware {
  func start(
    rate: Int,
    mode: PracticeAudioSessionMode,
    fence: CaptureFence,
    onChunk: @escaping (Data, Int, Int64, Bool, @escaping () -> Void) -> Void
  ) throws -> String
  /// Runs on the capture worker; must not block for the cue's duration.
  func playCue(samples: [Float], sampleRate: Int) throws
}

enum CuePlaybackError: Error, Equatable { case unavailable, unsupportedRate }

/// A cue longer than this is rejected rather than queued.
let maxCueSeconds = 2

/// Hardware-free overlap bookkeeping. A cue counts as possibly audible from
/// scheduling until its played-back callback plus [tail] (output latency and
/// room decay; a per-route calibrated value replaces this in F3.5).
final class PlaybackOverlapTracker {
  private let lock = NSLock()
  private let tailNs: UInt64
  private let now: () -> UInt64
  private var pending = 0
  private var tailUntil: UInt64 = 0

  init(tailNs: UInt64 = 300_000_000,
       now: @escaping () -> UInt64 = { DispatchTime.now().uptimeNanoseconds }) {
    self.tailNs = tailNs
    self.now = now
  }

  func scheduled() {
    lock.lock(); pending += 1; tailUntil = now() + tailNs; lock.unlock()
  }

  func playedBack() {
    lock.lock(); pending = max(0, pending - 1); tailUntil = now() + tailNs; lock.unlock()
  }

  var isActive: Bool {
    lock.lock(); defer { lock.unlock() }
    return pending > 0 || now() < tailUntil
  }

  func reset() {
    lock.lock(); pending = 0; tailUntil = 0; lock.unlock()
  }
}

/// All AVAudioEngine/AVAudioSession calls run on one serial worker.
final class AVEngineCaptureHardware: DuplexCaptureHardware {
  private var engine = AVAudioEngine()
  // Touching mainMixerNode permanently wires the engine's output node. A later
  // record-only (`.record`) attempt must not inherit that output graph.
  private var outputGraphUsed = false
  private let sessionPolicy: PracticeAudioSessionPolicy
  private let pendingBuffer = DispatchSemaphore(value: 1)
  private var tapInstalled = false
  private var player: AVAudioPlayerNode?
  private var playerFormat: AVAudioFormat?
  private let overlap = PlaybackOverlapTracker()

  init(sessionPolicy: PracticeAudioSessionPolicy = .shared) {
    self.sessionPolicy = sessionPolicy
  }

  func start(
    rate: Int,
    fence: CaptureFence,
    onChunk: @escaping (Data, Int, Int64, @escaping () -> Void) -> Void
  ) throws -> String {
    try start(rate: rate, mode: .recordOnly, fence: fence) { data, rate, stamp, _, finish in
      onChunk(data, rate, stamp, finish)
    }
  }

  func start(
    rate: Int,
    mode: PracticeAudioSessionMode,
    fence: CaptureFence,
    onChunk: @escaping (Data, Int, Int64, Bool, @escaping () -> Void) -> Void
  ) throws -> String {
    if outputGraphUsed {
      engine = AVAudioEngine()
      outputGraphUsed = false
    }
    try sessionPolicy.activateInput(rate: rate, fence: fence, mode: mode)

    // The requested sample rate is only a preference; send the actual rate.
    let input = engine.inputNode
    let format = input.inputFormat(forBus: 0)
    guard format.channelCount > 0,
          format.sampleRate == 44100 || format.sampleRate == 48000 else {
      throw CaptureHardwareError.unsupportedRate
    }
    if fence.isCancelled { throw CaptureHardwareError.cancelled }
    if mode == .playAndRecord {
      // Only the duplex attempt touches the output graph; a record-only
      // session never instantiates mainMixerNode/outputNode.
      guard let cueFormat = AVAudioFormat(standardFormatWithSampleRate: Double(rate),
                                          channels: 1) else {
        throw CaptureHardwareError.unsupportedRate
      }
      let node = AVAudioPlayerNode()
      outputGraphUsed = true
      engine.attach(node)
      engine.connect(node, to: engine.mainMixerNode, format: cueFormat)
      player = node
      playerFormat = cueFormat
    }
    let overlap = self.overlap
    let duplex = mode == .playAndRecord
    input.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self] buffer, time in
      guard let self = self, !fence.isCancelled,
            self.pendingBuffer.wait(timeout: .now()) == .success else { return }
      guard let channelData = buffer.floatChannelData else {
        self.pendingBuffer.signal(); return
      }
      let frames = Int(buffer.frameLength), channels = Int(buffer.format.channelCount)
      guard frames > 0 && channels > 0 else {
        self.pendingBuffer.signal(); return
      }
      var mono = [Double](repeating: 0, count: frames)
      for channel in 0..<channels {
        for frame in 0..<frames {
          mono[frame] += Double(channelData[channel][frame]) / Double(channels)
        }
      }
      let data = mono.withUnsafeBufferPointer { Data(buffer: $0) }
      for index in mono.indices { mono[index] = 0 }
      let stamp = Int64(AVAudioTime.seconds(forHostTime: time.hostTime) * 1_000_000)
      let playing = duplex && overlap.isActive
      onChunk(data, Int(buffer.format.sampleRate), stamp, playing) {
        self.pendingBuffer.signal()
      }
    }
    tapInstalled = true
    if fence.isCancelled { throw CaptureHardwareError.cancelled }
    try engine.start()
    if fence.isCancelled { throw CaptureHardwareError.cancelled }
    player?.play()
    let type = sessionPolicy.currentInputPort
    let port = type == .builtInMic ? "BuiltInMic" : (type?.rawValue ?? "Unknown")
    return "ios:\(port)"
  }

  func playCue(samples: [Float], sampleRate: Int) throws {
    guard let player = player, let format = playerFormat, engine.isRunning else {
      throw CuePlaybackError.unavailable
    }
    guard Int(format.sampleRate) == sampleRate else { throw CuePlaybackError.unsupportedRate }
    guard let buffer = AVAudioPCMBuffer(pcmFormat: format,
                                        frameCapacity: AVAudioFrameCount(samples.count)),
          let channel = buffer.floatChannelData?[0] else { throw CuePlaybackError.unavailable }
    buffer.frameLength = AVAudioFrameCount(samples.count)
    samples.withUnsafeBufferPointer { source in
      channel.update(from: source.baseAddress!, count: samples.count)
    }
    let overlap = self.overlap
    overlap.scheduled()
    player.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) { _ in
      overlap.playedBack()
    }
  }

  func stop() throws {
    if tapInstalled {
      engine.inputNode.removeTap(onBus: 0)
      tapInstalled = false
    }
    player?.stop()
    engine.stop()
    if let node = player { engine.detach(node) }
    player = nil
    playerFormat = nil
    overlap.reset()
    try sessionPolicy.deactivateInput()
  }
}

enum CapturePhase: String {
  case clear, starting, running, closing, unconfirmedInFlight
  case unconfirmedQuiescent, releasedAwaitingExplicitRetry
}

typealias CaptureDeadlineScheduler = (TimeInterval, @escaping () -> Void) -> Void

/// A timeout discards one FlutterResult, never the process resource.
final class CaptureMethodReply {
  private var result: FlutterResult?
  init(
    result: @escaping FlutterResult,
    deadline: TimeInterval,
    scheduler: CaptureDeadlineScheduler,
    onTimeout: @escaping () -> Void
  ) {
    self.result = result
    scheduler(deadline) { [weak self] in
      guard let self = self, self.result != nil else { return }
      self.finish(FlutterError(code: "capture_close_unconfirmed", message: nil, details: nil))
      onTimeout()
    }
  }
  var isPending: Bool { result != nil }
  func finish(_ value: Any?) {
    guard let answer = result else { return }
    result = nil
    answer(value)
  }
}

/// One process owner survives a replacement implicit Flutter engine.
/// Mutable coordinator state and every Flutter callback are main-thread only.
final class AudioCaptureCoordinator {
  static let shared = AudioCaptureCoordinator(hardware: AVEngineCaptureHardware())

  weak var processArbiter: PracticeAudioArbiter?

  private let hardware: CaptureHardware
  private let worker = DispatchQueue(label: "com.yulalab.ostinato.capture.hardware")
  private let scheduler: CaptureDeadlineScheduler
  private let deadline: TimeInterval
  private let canCapture: () -> Bool
  private var phase: CapturePhase = .clear {
    didSet { if oldValue != phase { processArbiter?.captureTransition() } }
  }
  private var attemptId: String?
  private var attemptMode: PracticeAudioSessionMode = .recordOnly
  private var attemptRate = 0
  private var fence: CaptureFence?
  private var startReply: CaptureMethodReply?
  private var stopReplies: [CaptureMethodReply] = []
  private var closeScheduled = false
  private var closeGeneration: UInt64 = 0
  private var uncertain = false
  private var tombstones = Set<String>()
  private var sink: FlutterEventSink?
  private var sinkAttemptId: String?
  private var observers: [NSObjectProtocol] = []

  init(
    hardware: CaptureHardware,
    deadline: TimeInterval = 2,
    scheduler: @escaping CaptureDeadlineScheduler = { delay, work in
      DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    },
    canCapture: @escaping () -> Bool = {
      UIApplication.shared.applicationState == .active &&
      AVAudioSession.sharedInstance().recordPermission == .granted
    }
  ) {
    self.hardware = hardware
    self.deadline = deadline
    self.scheduler = scheduler
    self.canCapture = canCapture
    let center = NotificationCenter.default
    observers.append(center.addObserver(forName: AVAudioSession.routeChangeNotification,
                                        object: nil, queue: .main) { [weak self] _ in
      // Session configuration during startup can itself change the route.
      // Only a route change after a published running state interrupts it.
      guard let self = self, self.phase == .running else { return }
      self.interrupt("input_changed")
    })
    observers.append(center.addObserver(forName: AVAudioSession.interruptionNotification,
                                        object: nil, queue: .main) { [weak self] note in
      guard let type = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
            type == AVAudioSession.InterruptionType.began.rawValue else { return }
      self?.interrupt("session_interrupted")
    })
    observers.append(center.addObserver(forName: UIApplication.willResignActiveNotification,
                                        object: nil, queue: .main) { [weak self] _ in
      self?.interrupt("foreground_lost")
    })
  }

  deinit { observers.forEach { NotificationCenter.default.removeObserver($0) } }

  private func error(_ code: String) -> FlutterError {
    FlutterError(code: code, message: nil, details: nil)
  }
  private func valid(_ id: String) -> Bool {
    id.count == 32 && id.utf8.allSatisfy { byte in
      (48...57).contains(byte) || (97...102).contains(byte)
    }
  }

  func attachSink(_ newSink: @escaping FlutterEventSink, id: String) -> FlutterError? {
    guard valid(id) else { return error("bad_args") }
    let oldId = sinkAttemptId
    sink = newSink
    sinkAttemptId = id
    if let oldId = oldId, oldId != id { requestStop(id: oldId, result: nil) }
    if let activeId = attemptId, activeId != id { requestStop(id: activeId, result: nil) }
    return nil
  }

  func detachSink(id: String) {
    if sinkAttemptId == id { sink = nil; sinkAttemptId = nil }
    requestStop(id: id, result: nil)
  }

  func ready(id: String) -> Bool { valid(id) && sink != nil && sinkAttemptId == id }

  func closeState() -> [String: Any] {
    let inFlight = phase == .starting || phase == .closing || phase == .unconfirmedInFlight
    let released = phase == .clear || phase == .releasedAwaitingExplicitRetry
    let retry = phase == .unconfirmedQuiescent || phase == .releasedAwaitingExplicitRetry
    return [
      "phase": phase.rawValue,
      "attemptId": attemptId as Any? ?? NSNull(),
      "attemptInFlight": inFlight,
      "resourcesReleased": released,
      "requiresExplicitRetry": retry
    ]
  }

  var activeAttemptId: String? { attemptId }

  func start(
    id: String, rate: Int, result: @escaping FlutterResult,
    owner: PracticeAudioOwner? = nil, permit: [String: Any]? = nil,
    mode: PracticeAudioSessionMode = .recordOnly
  ) {
    guard valid(id) else { result(error("bad_args")); return }
    let duplexHardware = hardware as? DuplexCaptureHardware
    guard mode == .recordOnly || duplexHardware != nil else {
      result(error("playback_unavailable")); return
    }
    guard rate == 44100 || rate == 48000 else {
      result(error("unsupported_sample_rate")); return
    }
    guard ready(id: id), canCapture() else {
      result(error("not_foreground_or_permitted")); return
    }
    guard phase == .clear, !tombstones.contains(id) else {
      result(error("capture_close_unconfirmed")); return
    }
    if let arbiter = processArbiter,
       let rejected = arbiter.claimInputStart(owner: owner, attemptId: id, permit: permit) {
      result(rejected); return
    }
    attemptId = id
    attemptMode = mode
    attemptRate = rate
    phase = .starting
    uncertain = false
    closeScheduled = false
    let newFence = CaptureFence()
    fence = newFence
    startReply = CaptureMethodReply(result: result, deadline: deadline,
                                    scheduler: scheduler) { [weak self] in
      guard let self = self, self.attemptId == id else { return }
      self.uncertain = true
      self.requestStop(id: id, result: nil)
      if self.closeScheduled { self.phase = .unconfirmedInFlight }
    }
    worker.async { [weak self] in
      guard let self = self else { return }
      let outcome: Result<String, Error>
      do {
        let deliver: (Data, Int, Int64, Bool?, @escaping () -> Void) -> Void = {
          [weak self] data, actualRate, stamp, playing, finish in
          DispatchQueue.main.async {
            defer { finish() }
            guard let self = self, self.attemptId == id,
                  self.phase == .running, !newFence.isCancelled,
                  self.sinkAttemptId == id else { return }
            var message: [String: Any] = ["type": "chunk", "attemptId": id,
                        "samples": FlutterStandardTypedData(float64: data),
                        "sampleRate": actualRate, "t": stamp]
            // Record-only chunks keep their exact legacy shape.
            if let playing = playing { message["playbackActive"] = playing }
            self.sink?(message)
          }
        }
        let route: String
        if mode == .playAndRecord, let duplex = duplexHardware {
          route = try duplex.start(rate: rate, mode: mode, fence: newFence) {
            data, actualRate, stamp, playing, finish in
            deliver(data, actualRate, stamp, playing, finish)
          }
        } else {
          route = try self.hardware.start(rate: rate, fence: newFence) {
            data, actualRate, stamp, finish in
            deliver(data, actualRate, stamp, nil, finish)
          }
        }
        outcome = .success(route)
      } catch { outcome = .failure(error) }
      DispatchQueue.main.async { [weak self] in self?.finishStart(id: id, outcome: outcome) }
    }
  }

  private func finishStart(id: String, outcome: Result<String, Error>) {
    guard attemptId == id else { return }
    switch outcome {
    case .success(let route):
      if phase == .starting && fence?.isCancelled == false {
        phase = .running
        startReply?.finish(nil)
        if sinkAttemptId == id {
          sink?(["type": "routeChanged", "attemptId": id, "route": route])
        }
      } else {
        startReply?.finish(error("capture_start_cancelled"))
        requestStop(id: id, result: nil)
      }
    case .failure(let failure):
      let code: String
      if let hardwareError = failure as? CaptureHardwareError {
        code = hardwareError == .unsupportedRate
          ? "unsupported_sample_rate" : "capture_start_cancelled"
      } else {
        code = "setup_failed"
      }
      startReply?.finish(error(code))
      requestStop(id: id, result: nil)
    }
    startReply = nil
  }

  func requestStop(id: String, result: FlutterResult?, explicitRetry: Bool = false) {
    guard valid(id) else { result?(error("bad_args")); return }
    guard attemptId == id else {
      if phase == .clear {
        if explicitRetry {
          // A clear readback can follow a failed Dart stream teardown. Only
          // the already fenced ID may acknowledge that local latch.
          if tombstones.contains(id) { result?(nil) }
          else { result?(error("stale_capture_attempt")) }
        } else {
          // A direct stop may arrive before a queued start. Tombstone that ID
          // even though it has not yet allocated any hardware.
          tombstones.insert(id)
          result?(nil)
        }
      } else { result?(error("stale_capture_attempt")) }
      return
    }
    if phase == .releasedAwaitingExplicitRetry {
      if explicitRetry { clear(); result?(nil) }
      else { result?(error("capture_close_unconfirmed")) }
      return
    }
    if phase == .unconfirmedQuiescent {
      guard explicitRetry else { result?(error("capture_close_unconfirmed")); return }
      uncertain = false
    } else if explicitRetry && (phase == .starting || phase == .closing || phase == .unconfirmedInFlight) {
      result?(error("capture_close_in_flight"))
      return
    }
    tombstones.insert(id)
    fence?.cancel()
    if let result = result {
      let reply = CaptureMethodReply(result: result, deadline: deadline,
                                     scheduler: scheduler) { [weak self] in
        guard let self = self, self.attemptId == id else { return }
        self.uncertain = true
        if self.closeScheduled { self.phase = .unconfirmedInFlight }
      }
      stopReplies.append(reply)
    }
    if !closeScheduled {
      closeScheduled = true
      phase = uncertain ? .unconfirmedInFlight : .closing
      closeGeneration &+= 1
      let generation = closeGeneration
      // Lifecycle, EventChannel cancel and engine replacement have no
      // FlutterResult. Their hardware close still needs a bounded readback.
      scheduler(deadline) { [weak self] in
        guard let self = self, self.attemptId == id,
              self.closeScheduled, self.closeGeneration == generation else { return }
        self.uncertain = true
        self.phase = .unconfirmedInFlight
      }
      worker.async { [weak self] in
        guard let self = self else { return }
        let closeError: Error?
        do { try self.hardware.stop(); closeError = nil }
        catch { closeError = error }
        DispatchQueue.main.async { [weak self] in
          self?.finishClose(id: id, generation: generation, closeError: closeError)
        }
      }
    } else if uncertain {
      phase = .unconfirmedInFlight
    }
  }

  private func finishClose(id: String, generation: UInt64, closeError: Error?) {
    guard attemptId == id, closeScheduled, closeGeneration == generation else { return }
    closeScheduled = false
    closeGeneration &+= 1
    let replies = stopReplies
    stopReplies.removeAll()
    if closeError != nil {
      uncertain = true
      phase = .unconfirmedQuiescent
      replies.forEach { $0.finish(error("capture_close_unconfirmed")) }
    } else if uncertain {
      phase = .releasedAwaitingExplicitRetry
      replies.forEach { $0.finish(error("capture_close_unconfirmed")) }
    } else {
      clear()
      replies.forEach { $0.finish(nil) }
    }
  }

  /// Plays one short cue inside the caller's own running duplex attempt. The
  /// output graph belongs to the capture attempt, so close/fence/background
  /// paths that stop capture also stop playback.
  func playCue(id: String, samples: [Float], sampleRate: Int,
               result: @escaping FlutterResult) {
    guard valid(id), attemptId == id, phase == .running,
          let attemptFence = fence, !attemptFence.isCancelled,
          let duplex = hardware as? DuplexCaptureHardware else {
      result(error("playback_unavailable")); return
    }
    guard attemptMode == .playAndRecord else {
      result(error("playback_not_enabled")); return
    }
    guard sampleRate == attemptRate else {
      result(error("unsupported_sample_rate")); return
    }
    guard !samples.isEmpty, samples.count <= sampleRate * maxCueSeconds,
          samples.allSatisfy({ $0.isFinite && abs($0) <= 1 }) else {
      result(error("bad_args")); return
    }
    worker.async { [weak self] in
      var code: String?
      if attemptFence.isCancelled {
        code = "playback_unavailable"
      } else {
        do { try duplex.playCue(samples: samples, sampleRate: sampleRate) }
        catch CuePlaybackError.unsupportedRate { code = "unsupported_sample_rate" }
        catch { code = "playback_failed" }
      }
      DispatchQueue.main.async {
        guard let self = self else { return }
        if let code = code { result(self.error(code)) } else { result(nil) }
      }
    }
  }

  private func clear() {
    closeGeneration &+= 1
    attemptId = nil
    attemptMode = .recordOnly
    attemptRate = 0
    fence = nil
    startReply = nil
    uncertain = false
    closeScheduled = false
    phase = .clear
  }

  private func interrupt(_ reason: String) {
    guard let id = attemptId,
          phase == .starting || phase == .running else { return }
    if sinkAttemptId == id {
      sink?(["type": "interrupted", "attemptId": id, "reason": reason])
    }
    requestStop(id: id, result: nil)
  }
}

/// A Flutter engine handler owns only its sink binding, never the hardware.
final class AudioCaptureStreamer: NSObject, FlutterStreamHandler {
  private let coordinator: AudioCaptureCoordinator
  private let arbiter: PracticeAudioArbiter?
  private let owner: PracticeAudioOwner?
  private var boundAttemptId: String?
  // EventChannel cancellation removes a sink, not this engine's authority to
  // close or explicitly retry a previously bound capture attempt.
  private var closeAuthorizedIds = Set<String>()
  private var retired = false

  init(
    coordinator: AudioCaptureCoordinator = .shared,
    arbiter: PracticeAudioArbiter? = nil,
    owner: PracticeAudioOwner? = nil
  ) {
    self.coordinator = coordinator
    self.arbiter = arbiter
    self.owner = owner
  }

  private func ownerIsCurrent() -> Bool {
    guard let arbiter = arbiter, let owner = owner else { return arbiter == nil }
    return arbiter.isCurrent(owner)
  }

  private func foreignCapture() -> Bool {
    guard let arbiter = arbiter, let owner = owner else { return false }
    return arbiter.captureIsForeign(to: owner)
  }

  /// AppDelegate calls this before publishing a replacement engine bridge.
  /// It fences the old sink and queues hardware cleanup synchronously.
  func retireForEngineReplacement() {
    assert(Thread.isMainThread)
    guard !retired else { return }
    retired = true
    let oldId = boundAttemptId
    boundAttemptId = nil
    closeAuthorizedIds.removeAll()
    if ownerIsCurrent(), let oldId = oldId { coordinator.detachSink(id: oldId) }
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if retired {
      if call.method == "ready" { result(false) }
      else { result(FlutterError(code: "capture_unavailable", message: nil, details: nil)) }
      return
    }
    guard ownerIsCurrent() else {
      result(FlutterError(code: "stale_audio_owner", message: nil, details: nil)); return
    }
    if foreignCapture() {
      result(FlutterError(code: "capture_foreign_owner", message: nil, details: nil)); return
    }
    switch call.method {
    case "closeState": result(coordinator.closeState())
    case "ready":
      let id = (call.arguments as? [String: Any])?["attemptId"] as? String
      result(id.map { coordinator.ready(id: $0) } ?? false)
    case "start":
      guard let args = call.arguments as? [String: Any],
            let id = args["attemptId"] as? String,
            let rate = args["sampleRate"] as? Int,
            let mode = PracticeAudioSessionMode(wire: args["sessionMode"]) else {
        result(FlutterError(code: "bad_args", message: nil, details: nil)); return
      }
      var permit: [String: Any]?
      if arbiter != nil {
        let ownerKeys: Set<String> = ["ownerToken", "engineGeneration", "contextGeneration"]
        let startKeys = ownerKeys.union(["attemptId", "sampleRate"])
        let leasedKeys = startKeys.union(["leaseId", "leaseGeneration"])
        // `sessionMode` is orthogonal to the claim/lease key sets.
        let keys = Set(args.keys).subtracting(["sessionMode"])
        guard keys == startKeys || keys == leasedKeys else {
          result(FlutterError(code: "bad_args", message: nil, details: nil)); return
        }
        permit = args.filter { ownerKeys.contains($0.key) ||
          (keys == leasedKeys && ($0.key == "leaseId" || $0.key == "leaseGeneration")) }
      }
      coordinator.start(id: id, rate: rate, result: result, owner: owner, permit: permit,
                        mode: mode)
    case "playCue":
      guard let args = call.arguments as? [String: Any], args.count == 3,
            let id = args["attemptId"] as? String,
            let typed = args["samples"] as? FlutterStandardTypedData,
            typed.type == .float64,
            let rate = args["sampleRate"] as? Int else {
        result(FlutterError(code: "bad_args", message: nil, details: nil)); return
      }
      guard boundAttemptId == id else {
        result(FlutterError(code: "playback_unavailable", message: nil, details: nil)); return
      }
      let samples: [Float] = typed.data.withUnsafeBytes { raw in
        raw.bindMemory(to: Double.self).map { Float($0) }
      }
      coordinator.playCue(id: id, samples: samples, sampleRate: rate, result: result)
    case "stop":
      guard let id = (call.arguments as? [String: Any])?["attemptId"] as? String else {
        result(FlutterError(code: "bad_args", message: nil, details: nil)); return
      }
      if arbiter != nil && !closeAuthorizedIds.contains(id) {
        result(FlutterError(code: "capture_foreign_owner", message: nil, details: nil)); return
      }
      coordinator.requestStop(id: id, result: result)
    case "retryStop":
      guard let id = (call.arguments as? [String: Any])?["attemptId"] as? String else {
        result(FlutterError(code: "bad_args", message: nil, details: nil)); return
      }
      if arbiter != nil && !closeAuthorizedIds.contains(id) {
        result(FlutterError(code: "capture_foreign_owner", message: nil, details: nil)); return
      }
      coordinator.requestStop(id: id, result: result, explicitRetry: true)
    default: result(FlutterMethodNotImplemented)
    }
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    guard !retired else {
      return FlutterError(code: "capture_unavailable", message: nil, details: nil)
    }
    guard ownerIsCurrent() else {
      return FlutterError(code: "stale_audio_owner", message: nil, details: nil)
    }
    guard !foreignCapture() else {
      return FlutterError(code: "capture_foreign_owner", message: nil, details: nil)
    }
    guard let id = (arguments as? [String: Any])?["attemptId"] as? String else {
      return FlutterError(code: "bad_args", message: nil, details: nil)
    }
    if let previous = boundAttemptId, previous != id {
      coordinator.detachSink(id: previous)
    }
    if let failure = coordinator.attachSink(events, id: id) { return failure }
    boundAttemptId = id
    closeAuthorizedIds.insert(id)
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    if retired { return nil }
    guard ownerIsCurrent() else { boundAttemptId = nil; return nil }
    // Flutter's implicit cancel before a replacement listen passes nil. Use
    // the handler's old sink ID, not the coordinator's current attempt ID.
    guard let id = boundAttemptId else { return nil }
    if let supplied = (arguments as? [String: Any])?["attemptId"] as? String,
       supplied != id { return nil }
    boundAttemptId = nil
    coordinator.detachSink(id: id)
    return nil
  }
}

/// The same synchronous retirement path is used by AppDelegate and fake tests.
final class AudioCaptureHandlerSlot {
  private(set) var current: AudioCaptureStreamer?

  func install(_ next: AudioCaptureStreamer) {
    assert(Thread.isMainThread)
    current?.retireForEngineReplacement()
    current = next
  }
}
