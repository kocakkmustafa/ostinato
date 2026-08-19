import AVFoundation
import Flutter

/// Mikrofon → EventChannel, RAM-only (OST-P0-002, roadmap §7).
///
/// Bu sınıf `ostinato_audio`nun "normative reference" DSP'sini besleyecek
/// HAM örnekleri üretir — pitch/onset/chord/route HÜKMÜ burada YOK, o
/// Dart tarafının işi (`AudioInputController` + `audio_route_state.dart`).
/// Hiçbir satır diske yazmaz: `AVAudioEngine`in tap callback'i örnekleri
/// doğrudan RAM'deki bir `[Double]`e kopyalar ve event sink'e verir, hiçbir
/// `FileHandle`/`Data(contentsOf:)` yazma çağrısı YOK — kanıt kodun
/// KENDİSİ (`grep -c "FileManager\|write(to"` bu dosyada sıfır döner).
///
/// **Kanıt sınıfı DÜRÜST:** bu dosya YALNIZ derleme-zamanı kanıtlıdır
/// (`flutter build ios --release --no-codesign`, cihazsız Mac'te). GERÇEK
/// mikrofon örneği hiç akıtılmadı — simülatörde/derleme makinesinde ses
/// donanımı testi YOK. Cihaz-günü release-gate (roadmap §15
/// MANUAL-OSTINATO-DEVICE-20260818) bu sınıfın davranışını İLK kez gerçek
/// donanımda ölçecek.
final class AudioCaptureStreamer: NSObject, FlutterStreamHandler {
  private let engine = AVAudioEngine()
  private var eventSink: FlutterEventSink?
  private var isRunning = false

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "start":
      guard let args = call.arguments as? [String: Any],
        let sampleRate = args["sampleRate"] as? Int
      else {
        result(FlutterError(code: "bad_args", message: "sampleRate required", details: nil))
        return
      }
      start(requestedSampleRate: Double(sampleRate), result: result)
    case "stop":
      stop()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func start(requestedSampleRate: Double, result: @escaping FlutterResult) {
    guard !isRunning else {
      result(nil)  // zaten koşuyor — kablolama katmanının kilidi (Dart tarafı) çift-start'ı zaten önler, burada sessizce no-op
      return
    }

    let session = AVAudioSession.sharedInstance()
    do {
      // `.record`: OST-P0-002 kapsamı yalnız DİNLEME — eş-zamanlı çalma
      // (metronom/referans ton) OST-P1-002'nin işi, o gelince `.playAndRecord`e
      // yükseltilecek (isimli, bilinçli sınır).
      try session.setCategory(.record, mode: .measurement, options: [.allowBluetooth])
      try session.setPreferredSampleRate(requestedSampleRate)
      try session.setActive(true)
    } catch {
      result(FlutterError(code: "setup_failed", message: "\(error)", details: nil))
      return
    }

    // iOS oturum hızı İSTENENİ HER ZAMAN vermez (donanım kararı, dokümantasyon
    // uyarısı) — sessizce kabul ETMEK yerine gerçekten neyi verdiğini
    // DOĞRULA. `AudioInputController` bu reddi `AudioUnavailable`e çevirir.
    let achieved = session.sampleRate
    if abs(achieved - requestedSampleRate) > 1.0 {
      try? session.setActive(false)
      result(
        FlutterError(
          code: "unsupported_sample_rate", message: "\(Int(achieved))", details: nil))
      return
    }

    let input = engine.inputNode
    let format = input.inputFormat(forBus: 0)

    NotificationCenter.default.addObserver(
      self, selector: #selector(onRouteChange),
      name: AVAudioSession.routeChangeNotification, object: session)
    NotificationCenter.default.addObserver(
      self, selector: #selector(onInterruption),
      name: AVAudioSession.interruptionNotification, object: session)

    input.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self] buffer, when in
      self?.onBuffer(buffer, when: when)
    }

    do {
      try engine.start()
    } catch {
      // `isRunning` hâlâ false — bir sonraki `stop()` çağrısı `guard
      // isRunning` yüzünden no-op geçer ve oturumu AKTİF BIRAKIRDI. Bu dal
      // kendi temizliğini KENDİSİ yapmak ZORUNDA, `stop()`a güvenemez.
      input.removeTap(onBus: 0)
      NotificationCenter.default.removeObserver(self)
      try? session.setActive(false)
      result(FlutterError(code: "setup_failed", message: "\(error)", details: nil))
      return
    }

    isRunning = true
    result(nil)
  }

  private func onBuffer(_ buffer: AVAudioPCMBuffer, when: AVAudioTime) {
    guard let sink = eventSink, let channelData = buffer.floatChannelData else { return }
    let frameCount = Int(buffer.frameLength)
    guard frameCount > 0 else { return }
    let channelCount = Int(buffer.format.channelCount)

    // Mono'ya indirge — kanal ortalaması (roadmap "mono float örnekler"
    // sözleşmesi, `ostinato_audio.PitchSource.analyze` ile bire bir).
    var mono = [Double](repeating: 0, count: frameCount)
    for ch in 0..<channelCount {
      let chData = channelData[ch]
      for i in 0..<frameCount {
        mono[i] += Double(chData[i])
      }
    }
    if channelCount > 1 {
      let inv = 1.0 / Double(channelCount)
      for i in 0..<frameCount { mono[i] *= inv }
    }

    // `when.hostTime`: cihazın kendi tekdüze saati (mach host time) —
    // NTP/uykudan etkilenmez. `AudioClockDomain.monotonic` etiketinin
    // Dart tarafındaki karşılığı budur (bkz. `audio_capture_channel.dart`
    // `RawAudioChunkEvent` dosya-başı notu).
    let hostSeconds = AVAudioTime.seconds(forHostTime: when.hostTime)
    let tUs = Int64(hostSeconds * 1_000_000)

    let bytes = mono.withUnsafeBufferPointer { Data(buffer: $0) }
    sink([
      "type": "chunk",
      "samples": FlutterStandardTypedData(float64: bytes),
      "sampleRate": Int(buffer.format.sampleRate),
      "t": tUs,
    ])
  }

  @objc private func onRouteChange(_ note: Notification) {
    guard let sink = eventSink else { return }
    let session = AVAudioSession.sharedInstance()
    // GİRİŞ portu (`inputs`, ÇIKIŞ değil) — mikrofonun KENDİSİ neyse o.
    // Ham `Port` değeri zaten `audio_route_state.dart mapIosPortType`
    // tablosunun beklediği adı taşır (ör. "Speaker", "BluetoothHFP").
    let portType = session.currentRoute.inputs.first?.portType.rawValue ?? "Unknown"
    sink(["type": "routeChanged", "route": "ios:\(portType)"])
  }

  @objc private func onInterruption(_ note: Notification) {
    guard let sink = eventSink,
      let info = note.userInfo,
      let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
      let type = AVAudioSession.InterruptionType(rawValue: typeValue)
    else { return }
    if type == .began {
      // Telefon çağrısı, başka bir app mic'i aldı, vb. — `AudioInputController`
      // bunu isimli `AudioSetupFailed` yapıp akışı KAPATIR (roadmap §9:
      // "Audio buffer lifecycle, background interruption ... negatif testli").
      sink(["type": "interrupted", "reason": "session_interrupted"])
    }
  }

  private func stop() {
    guard isRunning else { return }
    isRunning = false
    engine.inputNode.removeTap(onBus: 0)
    engine.stop()
    NotificationCenter.default.removeObserver(self)
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
  }

  // MARK: FlutterStreamHandler

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    eventSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }
}
