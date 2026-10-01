import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let audioCaptureSlot = AudioCaptureHandlerSlot()
  private var audioMethods: FlutterMethodChannel?
  private var audioEvents: FlutterEventChannel?
  private var practiceAudioMethods: FlutterMethodChannel?
  #if DEBUG
  private var qaVideoMethods: FlutterMethodChannel?
  private var qaVideoProbe: QASilentVideoProbeHandler?
  #endif

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    let arbiter = PracticeAudioArbiter.shared
    // The process owner revokes the old bridge and fences input before either
    // new MethodChannel can receive a Dart call.
    let owner = arbiter.replaceEngine()
    let capture = AudioCaptureStreamer(coordinator: arbiter.coordinator,
                                       arbiter: arbiter, owner: owner)
    let practice = PracticeAudioArbiterHandler(arbiter: arbiter, owner: owner)
    audioCaptureSlot.install(capture)
    audioMethods?.setMethodCallHandler(nil)
    audioEvents?.setStreamHandler(nil)
    practiceAudioMethods?.setMethodCallHandler(nil)
    #if DEBUG
    qaVideoProbe?.invalidate()
    qaVideoMethods?.setMethodCallHandler(nil)
    #endif
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let messenger = engineBridge.applicationRegistrar.messenger()
    audioMethods = FlutterMethodChannel(name: "com.yulalab.ostinato/audio_capture", binaryMessenger: messenger)
    audioEvents = FlutterEventChannel(name: "com.yulalab.ostinato/audio_capture/events", binaryMessenger: messenger)
    practiceAudioMethods = FlutterMethodChannel(name: "com.yulalab.ostinato/practice_audio_v1",
                                                binaryMessenger: messenger)
    audioMethods?.setMethodCallHandler { [weak capture] call, result in
      guard let capture = capture else { result(FlutterError(code: "capture_unavailable", message: nil, details: nil)); return }
      capture.handle(call, result: result)
    }
    audioEvents?.setStreamHandler(capture)
    practiceAudioMethods?.setMethodCallHandler { call, result in
      practice.handle(call, result: result)
    }
    #if DEBUG
    let probe = QASilentVideoProbeHandler()
    qaVideoProbe = probe
    qaVideoMethods = FlutterMethodChannel(name: QASilentVideoProbeHandler.channelName,
                                          binaryMessenger: messenger)
    qaVideoMethods?.setMethodCallHandler { [weak probe] call, result in
      guard let probe = probe else { result(false); return }
      probe.handle(call, result: result)
    }
    #endif
  }
}
