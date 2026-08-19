import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  // OST-P0-002: ayrı bir plugin paketi AÇILMADI (aile kuralı — ses
  // motion-core'a asla girmez, ve bu app-özel yakalama motion-core'un
  // paylaşılan yapısına da girmemeli). Kanal doğrudan Runner'da kayıtlı.
  private let audioCaptureStreamer = AudioCaptureStreamer()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "AudioCaptureStreamer") {
      let messenger = registrar.messenger()
      let methodChannel = FlutterMethodChannel(
        name: "com.yulalab.ostinato/audio_capture", binaryMessenger: messenger)
      methodChannel.setMethodCallHandler(audioCaptureStreamer.handle)
      let eventChannel = FlutterEventChannel(
        name: "com.yulalab.ostinato/audio_capture/events", binaryMessenger: messenger)
      eventChannel.setStreamHandler(audioCaptureStreamer)
    }
  }
}
