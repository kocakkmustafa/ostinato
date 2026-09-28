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

/// All AVAudioEngine/AVAudioSession calls run on one serial worker.
final class AVEngineCaptureHardware: CaptureHardware {
  private let engine = AVAudioEngine()
  private let session = AVAudioSession.sharedInstance()
  private let pendingBuffer = DispatchSemaphore(value: 1)
  private var tapInstalled = false
  private var sessionActivated = false

  func start(
    rate: Int,
    fence: CaptureFence,
    onChunk: @escaping (Data, Int, Int64, @escaping () -> Void) -> Void
  ) throws -> String {
    if fence.isCancelled { throw CaptureHardwareError.cancelled }
    try session.setCategory(.record, mode: .measurement)
    if fence.isCancelled { throw CaptureHardwareError.cancelled }
    try session.setPreferredSampleRate(Double(rate))
    if fence.isCancelled { throw CaptureHardwareError.cancelled }
    try session.setActive(true)
    sessionActivated = true
    if fence.isCancelled { throw CaptureHardwareError.cancelled }

    // The requested sample rate is only a preference; send the actual rate.
    let input = engine.inputNode
    let format = input.inputFormat(forBus: 0)
    guard format.channelCount > 0,
          format.sampleRate == 44100 || format.sampleRate == 48000 else {
      throw CaptureHardwareError.unsupportedRate
    }
    if fence.isCancelled { throw CaptureHardwareError.cancelled }
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
      onChunk(data, Int(buffer.format.sampleRate), stamp) {
        self.pendingBuffer.signal()
      }
    }
    tapInstalled = true
    if fence.isCancelled { throw CaptureHardwareError.cancelled }
    try engine.start()
    if fence.isCancelled { throw CaptureHardwareError.cancelled }
    let type = session.currentRoute.inputs.first?.portType
    let port = type == .builtInMic ? "BuiltInMic" : (type?.rawValue ?? "Unknown")
    return "ios:\(port)"
  }

  func stop() throws {
    if tapInstalled {
      engine.inputNode.removeTap(onBus: 0)
      tapInstalled = false
    }
    engine.stop()
    // A thrown deactivation leaves the flag set for an explicit close retry.
    if sessionActivated {
      try session.setActive(false, options: .notifyOthersOnDeactivation)
      sessionActivated = false
    }
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

  private let hardware: CaptureHardware
  private let worker = DispatchQueue(label: "com.yulalab.ostinato.capture.hardware")
  private let scheduler: CaptureDeadlineScheduler
  private let deadline: TimeInterval
  private let canCapture: () -> Bool
  private var phase: CapturePhase = .clear
  private var attemptId: String?
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

  func start(id: String, rate: Int, result: @escaping FlutterResult) {
    guard valid(id) else { result(error("bad_args")); return }
    guard rate == 44100 || rate == 48000 else {
      result(error("unsupported_sample_rate")); return
    }
    guard ready(id: id), canCapture() else {
      result(error("not_foreground_or_permitted")); return
    }
    guard phase == .clear, !tombstones.contains(id) else {
      result(error("capture_close_unconfirmed")); return
    }
    attemptId = id
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
        let route = try self.hardware.start(rate: rate, fence: newFence) {
          [weak self] data, actualRate, stamp, finish in
          DispatchQueue.main.async {
            defer { finish() }
            guard let self = self, self.attemptId == id,
                  self.phase == .running, !newFence.isCancelled,
                  self.sinkAttemptId == id else { return }
            self.sink?(["type": "chunk", "attemptId": id,
                        "samples": FlutterStandardTypedData(float64: data),
                        "sampleRate": actualRate, "t": stamp])
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

  private func clear() {
    closeGeneration &+= 1
    phase = .clear
    attemptId = nil
    fence = nil
    startReply = nil
    uncertain = false
    closeScheduled = false
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
  private var boundAttemptId: String?
  private var retired = false

  init(coordinator: AudioCaptureCoordinator = .shared) { self.coordinator = coordinator }

  /// AppDelegate calls this before publishing a replacement engine bridge.
  /// It fences the old sink and queues hardware cleanup synchronously.
  func retireForEngineReplacement() {
    assert(Thread.isMainThread)
    guard !retired else { return }
    retired = true
    let oldId = boundAttemptId
    boundAttemptId = nil
    if let oldId = oldId { coordinator.detachSink(id: oldId) }
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if retired {
      if call.method == "closeState" { result(coordinator.closeState()) }
      else if call.method == "ready" { result(false) }
      else { result(FlutterError(code: "capture_unavailable", message: nil, details: nil)) }
      return
    }
    switch call.method {
    case "closeState": result(coordinator.closeState())
    case "ready":
      let id = (call.arguments as? [String: Any])?["attemptId"] as? String
      result(id.map { coordinator.ready(id: $0) } ?? false)
    case "start":
      guard let args = call.arguments as? [String: Any],
            let id = args["attemptId"] as? String,
            let rate = args["sampleRate"] as? Int else {
        result(FlutterError(code: "bad_args", message: nil, details: nil)); return
      }
      coordinator.start(id: id, rate: rate, result: result)
    case "stop":
      guard let id = (call.arguments as? [String: Any])?["attemptId"] as? String else {
        result(FlutterError(code: "bad_args", message: nil, details: nil)); return
      }
      coordinator.requestStop(id: id, result: result)
    case "retryStop":
      guard let id = (call.arguments as? [String: Any])?["attemptId"] as? String else {
        result(FlutterError(code: "bad_args", message: nil, details: nil)); return
      }
      coordinator.requestStop(id: id, result: result, explicitRetry: true)
    default: result(FlutterMethodNotImplemented)
    }
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    guard !retired else {
      return FlutterError(code: "capture_unavailable", message: nil, details: nil)
    }
    guard let id = (arguments as? [String: Any])?["attemptId"] as? String else {
      return FlutterError(code: "bad_args", message: nil, details: nil)
    }
    if let previous = boundAttemptId, previous != id {
      coordinator.detachSink(id: previous)
    }
    if let failure = coordinator.attachSink(events, id: id) { return failure }
    boundAttemptId = id
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    if retired { return nil }
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
