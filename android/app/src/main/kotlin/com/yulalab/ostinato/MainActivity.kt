package com.yulalab.ostinato

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
  // OST-P0-002: ayrı bir plugin paketi AÇILMADI — iOS AppDelegate.swift ile
  // aynı gerekçe (ses motion-core'un paylaşılan yapısına asla girmez).
  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    val streamer = AudioCaptureStreamer(applicationContext)
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.yulalab.ostinato/audio_capture")
      .setMethodCallHandler(streamer)
    EventChannel(
        flutterEngine.dartExecutor.binaryMessenger, "com.yulalab.ostinato/audio_capture/events")
      .setStreamHandler(streamer)
  }
}
