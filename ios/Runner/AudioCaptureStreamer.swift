import AVFoundation
import Flutter
import UIKit

/// Foreground, explicit opt-in capture. Buffers are RAM-only and discarded
/// after channel delivery. No recording, background mode or network path.
final class AudioCaptureStreamer: NSObject, FlutterStreamHandler {
  private let engine = AVAudioEngine()
  private var eventSink: FlutterEventSink?
  private var running = false
  private var tapInstalled = false
  private var generation = 0
  private var observers: [NSObjectProtocol] = []
  private let pendingBuffer = DispatchSemaphore(value: 1)

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "ready": result(eventSink != nil)
    case "start":
      guard let args = call.arguments as? [String: Any], let rate = args["sampleRate"] as? Int else {
        result(FlutterError(code: "bad_args", message: nil, details: nil)); return
      }
      start(rate: rate, result: result)
    case "stop": stop(); result(nil)
    default: result(FlutterMethodNotImplemented)
    }
  }
  private func start(rate: Int, result: @escaping FlutterResult) {
    guard !running else { result(nil); return }
    guard UIApplication.shared.applicationState == .active,
          AVAudioSession.sharedInstance().recordPermission == .granted,
          eventSink != nil else {
      result(FlutterError(code: "not_foreground_or_permitted", message: nil, details: nil)); return
    }
    guard rate == 44100 || rate == 48000 else {
      result(FlutterError(code: "unsupported_sample_rate", message: nil, details: nil)); return
    }
    let session = AVAudioSession.sharedInstance()
    do {
      try session.setCategory(.record, mode: .measurement)
      try session.setPreferredSampleRate(Double(rate))
      try session.setActive(true)
      // Preferred rate is a request, not a guarantee. The PCM's actual rate
      // is transmitted; Dart independently restricts 44.1/48 kHz.
      let input = engine.inputNode
      let format = input.inputFormat(forBus: 0)
      guard format.channelCount > 0,
            format.sampleRate == 44100 || format.sampleRate == 48000 else {
        stop(); result(FlutterError(code: "unsupported_sample_rate", message: nil, details: nil)); return
      }
      generation += 1
      let token = generation
      input.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self] buffer, time in
        guard let self = self, self.pendingBuffer.wait(timeout: .now()) == .success else { return }
        guard let channelData = buffer.floatChannelData else { self.pendingBuffer.signal(); return }
        let frames = Int(buffer.frameLength), channels = Int(buffer.format.channelCount)
        guard frames > 0 && channels > 0 else { self.pendingBuffer.signal(); return }
        var mono = [Double](repeating: 0, count: frames)
        for ch in 0..<channels { for i in 0..<frames { mono[i] += Double(channelData[ch][i]) / Double(channels) } }
        let data = mono.withUnsafeBufferPointer { Data(buffer: $0) }
        for i in mono.indices { mono[i] = 0 }
        let actualRate = Int(buffer.format.sampleRate)
        let stamp = Int64(AVAudioTime.seconds(forHostTime: time.hostTime) * 1_000_000)
        // Flutter channel invocation is on the platform main thread. A stop
        // invalidates already queued chunks; no stale sample is delivered.
        DispatchQueue.main.async { [weak self] in
          defer { self?.pendingBuffer.signal() }
          guard let self = self, self.running, self.generation == token else { return }
          self.eventSink?(["type": "chunk", "samples": FlutterStandardTypedData(float64: data),
                           "sampleRate": actualRate, "t": stamp])
        }
      }
      tapInstalled = true
      let center = NotificationCenter.default
      observers.append(center.addObserver(forName: AVAudioSession.routeChangeNotification, object: session, queue: .main) { [weak self] _ in
        guard let self = self, self.running, self.generation == token else { return }
        self.eventSink?(["type": "interrupted", "reason": "input_changed"]); self.stop()
      })
      observers.append(center.addObserver(forName: AVAudioSession.interruptionNotification, object: session, queue: .main) { [weak self] note in
        guard let self = self, self.running, self.generation == token,
              let type = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              type == AVAudioSession.InterruptionType.began.rawValue else { return }
        self.eventSink?(["type": "interrupted", "reason": "session_interrupted"]); self.stop()
      })
      observers.append(center.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
        guard let self = self, self.running, self.generation == token else { return }
        self.eventSink?(["type": "interrupted", "reason": "foreground_lost"]); self.stop()
      })
      running = true
      try engine.start()
      emitRoute()
      result(nil)
    } catch {
      stop(); result(FlutterError(code: "setup_failed", message: nil, details: nil))
    }
  }
  private func emitRoute() {
    let type = AVAudioSession.sharedInstance().currentRoute.inputs.first?.portType
    // Normalize the enum, not its implementation raw string (e.g.
    // MicrophoneBuiltIn). Dart's stable route tag is explicitly BuiltInMic.
    let port = type == .builtInMic ? "BuiltInMic" : (type?.rawValue ?? "Unknown")
    eventSink?(["type": "routeChanged", "route": "ios:\(port)"])
  }
  func stop() {
    generation += 1; running = false
    if tapInstalled { engine.inputNode.removeTap(onBus: 0); tapInstalled = false }
    engine.stop(); observers.forEach { NotificationCenter.default.removeObserver($0) }; observers.removeAll()
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
  }
  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events; return nil
  }
  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    stop(); eventSink = nil; return nil
  }
  deinit { observers.forEach { NotificationCenter.default.removeObserver($0) } }
}
