package com.yulalab.ostinato

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
  private var foreground = false
  private var capture: AudioCaptureStreamer? = null
  private var methods: MethodChannel? = null
  private var events: EventChannel? = null
  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    val input = AudioCaptureStreamer(this) { foreground }
    capture = input
    methods = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.yulalab.ostinato/audio_capture").apply { setMethodCallHandler(input) }
    events = EventChannel(flutterEngine.dartExecutor.binaryMessenger, "com.yulalab.ostinato/audio_capture/events").apply { setStreamHandler(input) }
  }
  override fun onResume() { super.onResume(); foreground = true }
  override fun onPause() { foreground = false; capture?.stop(); super.onPause() }
  override fun onDestroy() { foreground = false; capture?.stop(); super.onDestroy() }
  override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
    capture?.stop(); methods?.setMethodCallHandler(null); events?.setStreamHandler(null)
    capture = null; methods = null; events = null
    super.cleanUpFlutterEngine(flutterEngine)
  }
}
