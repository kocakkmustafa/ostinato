import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let audioCaptureSlot = AudioCaptureHandlerSlot()
  private var audioMethods: FlutterMethodChannel?
  private var audioEvents: FlutterEventChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    let capture = AudioCaptureStreamer()
    // Retire the old sink and fence its hardware before the new bridge exists.
    audioCaptureSlot.install(capture)
    audioMethods?.setMethodCallHandler(nil)
    audioEvents?.setStreamHandler(nil)
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let messenger = engineBridge.applicationRegistrar.messenger()
    audioMethods = FlutterMethodChannel(name: "com.yulalab.ostinato/audio_capture", binaryMessenger: messenger)
    audioEvents = FlutterEventChannel(name: "com.yulalab.ostinato/audio_capture/events", binaryMessenger: messenger)
    audioMethods?.setMethodCallHandler { [weak capture] call, result in
      guard let capture = capture else { result(FlutterError(code: "capture_unavailable", message: nil, details: nil)); return }
      capture.handle(call, result: result)
    }
    audioEvents?.setStreamHandler(capture)
  }
}
