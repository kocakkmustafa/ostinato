package com.yulalab.ostinato

import java.util.concurrent.atomic.AtomicBoolean
import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.media.AudioDeviceInfo
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Foreground RAM-only capture. VOICE_RECOGNITION is requested; vendor signal
 * processing is not assumed absent. No file, upload or background service. */
class AudioCaptureStreamer(private val context: Context, private val foreground: () -> Boolean) :
  MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
  private var record: AudioRecord? = null
  private var worker: Thread? = null
  @Volatile private var running = false
  @Volatile private var generation = 0
  private var sink: EventChannel.EventSink? = null
  private val pendingBuffer = AtomicBoolean(false)
  private val main = Handler(Looper.getMainLooper())
  private var routing: AudioRecord.OnRoutingChangedListener? = null

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    when(call.method) {
      "ready" -> result.success(sink != null)
      "start" -> {
        val rate = call.argument<Int>("sampleRate")
        if (rate == null) result.error("bad_args", null, null) else start(rate, result)
      }
      "stop" -> { stop(); result.success(null) }
      else -> result.notImplemented()
    }
  }
  private fun start(rate: Int, result: MethodChannel.Result) {
    if (running) { result.success(null); return }
    if (!foreground() || sink == null || ContextCompat.checkSelfPermission(context,
        Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
      result.error("not_foreground_or_permitted", null, null); return
    }
    if (rate != 44100 && rate != 48000) {
      result.error("unsupported_sample_rate", null, null); return
    }
    try {
      val size = AudioRecord.getMinBufferSize(rate, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT)
      if (size <= 0) { result.error("unsupported_sample_rate", null, null); return }
      val input = AudioRecord(MediaRecorder.AudioSource.VOICE_RECOGNITION, rate,
        AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT, size * 2)
      record = input
      if (input.state != AudioRecord.STATE_INITIALIZED || input.sampleRate !in listOf(44100, 48000)) {
        stop(); result.error("unsupported_sample_rate", null, null); return
      }
      input.startRecording()
      if (input.recordingState != AudioRecord.RECORDSTATE_RECORDING) {
        stop(); result.error("setup_failed", null, null); return
      }
      generation += 1
      val token = generation
      running = true
      if (Build.VERSION.SDK_INT >= 24) {
        val listener = AudioRecord.OnRoutingChangedListener { r ->
          if (running && generation == token && record === r) sink?.success(mapOf("type" to "routeChanged", "route" to route(r)))
        }
        routing = listener; input.addOnRoutingChangedListener(listener, main)
      }
      // Initial route may appear only after the first read; send again then.
      sink?.success(mapOf("type" to "routeChanged", "route" to route(input)))
      worker = Thread {
        val pcm = ShortArray(maxOf(size / 2, 2048))
        var announcedRoute = false
        try {
          while (running && generation == token) {
            val count = input.read(pcm, 0, pcm.size)
            if (count < 0) throw IllegalStateException("read_failed")
            if (count == 0) continue
            if (!pendingBuffer.compareAndSet(false, true)) { pcm.fill(0); continue }
            val samples = DoubleArray(count) { pcm[it] / 32768.0 }
            val time = System.nanoTime() / 1000 - count.toLong() * 1000000 / input.sampleRate
            main.post {
              if (running && generation == token) {
                if (!announcedRoute) { sink?.success(mapOf("type" to "routeChanged", "route" to route(input))); announcedRoute = true }
                sink?.success(mapOf("type" to "chunk", "samples" to samples, "sampleRate" to input.sampleRate, "t" to time))
              }
              samples.fill(0.0)
              pendingBuffer.set(false)
            }
            pcm.fill(0)
          }
        } catch (_: Exception) {
          main.post { if (running && generation == token) {
            sink?.success(mapOf("type" to "interrupted", "reason" to "capture_read_failed")); stop()
          } }
        } finally { pcm.fill(0) }
      }.apply { name = "ostinato-note-observation"; start() }
      result.success(null)
    } catch (_: Exception) {
      stop(); result.error("setup_failed", null, null)
    }
  }
  private fun route(input: AudioRecord): String {
    if (Build.VERSION.SDK_INT < 24) return "android:Unknown"
    return "android:" + when(input.routedDevice?.type) {
      AudioDeviceInfo.TYPE_BUILTIN_MIC -> "TYPE_BUILTIN_MIC"
      AudioDeviceInfo.TYPE_WIRED_HEADSET -> "TYPE_WIRED_HEADSET"
      AudioDeviceInfo.TYPE_BLUETOOTH_SCO -> "TYPE_BLUETOOTH_SCO"
      AudioDeviceInfo.TYPE_USB_DEVICE -> "TYPE_USB_DEVICE"
      AudioDeviceInfo.TYPE_USB_HEADSET -> "TYPE_USB_HEADSET"
      else -> "Unknown"
    }
  }
  fun stop() {
    generation += 1; running = false
    val input = record; record = null
    if (Build.VERSION.SDK_INT >= 24) routing?.let { input?.removeOnRoutingChangedListener(it) }
    routing = null
    try { input?.stop() } catch (_: Exception) { }
    // Do not release a record while its read thread still uses it. On unusual
    // drivers a blocked read is released by the worker after it finally exits.
    val oldWorker = worker; worker = null
    oldWorker?.join(250)
    if (oldWorker?.isAlive == true) {
      Thread { oldWorker.join(); input?.release() }.start()
    } else { input?.release() }
  }
  override fun onListen(arguments: Any?, events: EventChannel.EventSink?) { sink = events }
  override fun onCancel(arguments: Any?) { stop(); sink = null }
}
