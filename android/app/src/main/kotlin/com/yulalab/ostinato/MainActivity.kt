package com.yulalab.ostinato

import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.atomic.AtomicBoolean

class MainActivity : FlutterActivity() {
  private val owner = Any()
  private val captureSlot = AudioCaptureHandlerSlot()
  private var audioBinding: PracticeAudioArbiter.Binding? = null

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    val processOwner = AudioCaptureRuntime.registerEngine(applicationContext, owner, flutterEngine)
    audioBinding = processOwner
    val input = AudioCaptureStreamer(applicationContext, owner,
      AudioCaptureRuntime.coordinator(applicationContext), AudioCaptureRuntime.arbiter(), processOwner)
    val binding = FlutterAudioCaptureBinding(input,
      PracticeAudioArbiterChannel(AudioCaptureRuntime.arbiter(), processOwner), owner)
    captureSlot.replace(flutterEngine, binding) {
      registerEngine(flutterEngine, binding, processOwner)
    }
  }
  private fun registerEngine(
    engine: FlutterEngine,
    binding: FlutterAudioCaptureBinding,
    processOwner: PracticeAudioArbiter.Binding,
  ) {
    super.configureFlutterEngine(engine)
    binding.register(engine)
    AudioEnvironmentChannel.register(engine, applicationContext)
    // Auto-registration happened in super only for an Activity-owned engine.
    // Cached/external engines may have no plugin or an already installed bridge.
    val videoInstall = VendorVideoPermitBridge.installForEngine(
      engine, processOwner, AudioCaptureRuntime.arbiter())
    if (videoInstall != VendorVideoPermitBridge.InstallResult.INSTALLED &&
        videoInstall != VendorVideoPermitBridge.InstallResult.REBOUND) {
      Log.w("OstinatoVideoPermit", "Video bridge unavailable: $videoInstall")
    }
  }
  override fun onResume() {
    super.onResume()
    audioBinding?.let { AudioCaptureRuntime.foreground(it, true) }
  }
  override fun onPause() {
    // Veto this Activity's prepared ID before giving up foreground ownership.
    // The coordinator still checks the attempt owner if another Activity has
    // already become current, so a late pause cannot close its capture.
    captureSlot.closeCurrent()
    audioBinding?.let { AudioCaptureRuntime.foreground(it, false) }
    super.onPause()
  }
  override fun onDestroy() {
    audioBinding?.let { AudioCaptureRuntime.foreground(it, false) }
    captureSlot.retireCurrent()
    super.onDestroy()
  }
  override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
    captureSlot.retireIfEngine(flutterEngine)
    audioBinding?.takeIf { it.engine === flutterEngine }?.let {
      AudioCaptureRuntime.arbiter().closeAllGlobal(it)
    }
    super.cleanUpFlutterEngine(flutterEngine)
  }
}

private class FlutterAudioCaptureBinding(
  private val capture: AudioCaptureStreamer,
  private val arbiterChannel: PracticeAudioArbiterChannel,
  private val activityEpoch: Any,
) : AudioCaptureBinding {
  private val handlerOwners = EngineChannelHandlerOwnership.process
  @Volatile
  private var handlerClaim: EngineChannelHandlerOwnership.Claim? = null
  private var methods: MethodChannel? = null
  private var events: EventChannel? = null
  private val retired = AtomicBoolean(false)

  fun register(engine: FlutterEngine) {
    val messenger = engine.dartExecutor.binaryMessenger
    val acquisition = handlerOwners.claim(engine, messenger, activityEpoch) { retire() }
    handlerClaim = acquisition.claim
    acquisition.retirePrevious()
    if (!handlerOwners.installIfCurrent(acquisition.claim) {
        check(!retired.get()) { "Retired audio handler cannot register" }
        methods = MethodChannel(messenger, "com.yulalab.ostinato/audio_capture")
          .apply { setMethodCallHandler(capture) }
        events = EventChannel(messenger, "com.yulalab.ostinato/audio_capture/events")
          .apply { setStreamHandler(capture) }
        arbiterChannel.register(engine)
      }) {
      throw IllegalStateException("Audio handler registration was superseded")
    }
  }

  override fun closeBoundAttempt() { capture.closeBoundAttempt() }

  override fun retire() {
    if (!retired.compareAndSet(false, true)) return
    try {
      capture.retire() // Fence the old sink even after another Activity claims the engine.
    } finally {
      try {
        handlerClaim?.let { claim ->
          handlerOwners.clearIfMessengerUncontested(claim) {
            arbiterChannel.retire(clearHandler = true)
            methods?.setMethodCallHandler(null)
            events?.setStreamHandler(null)
          }
        }
      } finally {
        // A stale binding must stop serving direct callbacks but must not
        // clear the new Activity's messenger-wide handlers.
        arbiterChannel.retire(clearHandler = false)
        handlerClaim = null
        methods = null
        events = null
      }
    }
  }
}
