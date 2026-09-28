package com.yulalab.ostinato

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
  private val owner = Any()
  private val captureSlot = AudioCaptureHandlerSlot()

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    val input = AudioCaptureStreamer(applicationContext, owner,
      AudioCaptureRuntime.coordinator(applicationContext))
    val binding = FlutterAudioCaptureBinding(input)
    captureSlot.replace(flutterEngine, binding) {
      registerEngine(flutterEngine, binding)
    }
  }
  private fun registerEngine(engine: FlutterEngine, binding: FlutterAudioCaptureBinding) {
    super.configureFlutterEngine(engine)
    binding.register(engine)
  }
  override fun onResume() { super.onResume(); AudioCaptureRuntime.foreground(owner, true) }
  override fun onPause() {
    // Veto this Activity's prepared ID before giving up foreground ownership.
    // The coordinator still checks the attempt owner if another Activity has
    // already become current, so a late pause cannot close its capture.
    captureSlot.closeCurrent()
    AudioCaptureRuntime.foreground(owner, false)
    super.onPause()
  }
  override fun onDestroy() {
    AudioCaptureRuntime.foreground(owner, false)
    captureSlot.retireCurrent()
    super.onDestroy()
  }
  override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
    captureSlot.retireIfEngine(flutterEngine)
    super.cleanUpFlutterEngine(flutterEngine)
  }
}

private class FlutterAudioCaptureBinding(
  private val capture: AudioCaptureStreamer,
) : AudioCaptureBinding {
  private var methods: MethodChannel? = null
  private var events: EventChannel? = null
  private var retired = false

  fun register(engine: FlutterEngine) {
    val messenger = engine.dartExecutor.binaryMessenger
    methods = MethodChannel(messenger, "com.yulalab.ostinato/audio_capture")
      .apply { setMethodCallHandler(capture) }
    events = EventChannel(messenger, "com.yulalab.ostinato/audio_capture/events")
      .apply { setStreamHandler(capture) }
  }

  override fun closeBoundAttempt() { capture.closeBoundAttempt() }

  override fun retire() {
    if (retired) return
    retired = true
    capture.retire() // This fences the old sink and queues hardware close now.
    methods?.setMethodCallHandler(null)
    events?.setStreamHandler(null)
    methods = null
    events = null
  }
}
