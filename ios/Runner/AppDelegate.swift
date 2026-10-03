import Flutter
import UIKit
import video_player_avfoundation

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
    let messenger = engineBridge.applicationRegistrar.messenger()
    // The process owner revokes the old bridge and fences input before either
    // new MethodChannel can receive a Dart call.
    let owner = arbiter.replaceEngine(engineIdentity: messenger as AnyObject)
    let capture = AudioCaptureStreamer(coordinator: arbiter.coordinator,
                                       arbiter: arbiter, owner: owner)
    audioCaptureSlot.install(capture)
    audioMethods?.setMethodCallHandler(nil)
    audioEvents?.setStreamHandler(nil)
    practiceAudioMethods?.setMethodCallHandler(nil)
    #if DEBUG
    qaVideoProbe?.invalidate()
    qaVideoMethods?.setMethodCallHandler(nil)
    #endif
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // Bind only the plugin published by this exact implicit engine. A missing
    // plugin or rejected install leaves native video creation denied.
    let registry = engineBridge.pluginRegistry
    var rebindBridge: (() -> Bool)?
    if let plugin = registry.valuePublished(byPlugin: "VideoPlayerPlugin") as? VideoPlayerPlugin {
      let videoBridge = OstinatoVideoPermitBridge(arbiter: arbiter, owner: owner,
                                                   plugin: plugin)
      if !plugin.installVideoPermitBridge(videoBridge) {
        NSLog("OstinatoVideoPermit: iOS bridge installation rejected")
      }
      // Reuse this exact next bridge for lost-reply retries. Neither a stale
      // handler nor a replacement published plugin can use this owner's port.
      rebindBridge = { [weak plugin] in
        guard let plugin = plugin, arbiter.isCurrent(owner),
              (registry.valuePublished(byPlugin: "VideoPlayerPlugin") as? VideoPlayerPlugin) === plugin else { return false }
        let ready = plugin.rebindVideoPermitBridge(messenger: messenger, to: videoBridge)
        return ready && arbiter.isCurrent(owner) &&
          (registry.valuePublished(byPlugin: "VideoPlayerPlugin") as? VideoPlayerPlugin) === plugin
      }
    } else {
      NSLog("OstinatoVideoPermit: iOS plugin unavailable")
    }
    let practice = PracticeAudioArbiterHandler(arbiter: arbiter, owner: owner,
                                               rebindBridge: rebindBridge)
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
