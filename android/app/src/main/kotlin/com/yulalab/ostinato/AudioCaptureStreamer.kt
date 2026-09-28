package com.yulalab.ostinato

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
import java.util.concurrent.Executors

/** Process-owned capture. Neither coordinator nor workers retain an Activity. */
internal object AudioCaptureRuntime {
  private var coordinator: AudioCaptureCoordinator? = null

  fun coordinator(context: Context): AudioCaptureCoordinator = coordinator ?: AudioCaptureCoordinator(
    AndroidRecorderFactory(), AndroidCaptureDispatch(),
  ).also { coordinator = it }

  fun foreground(owner: Any, isForeground: Boolean) {
    coordinator?.foreground(owner, isForeground)
  }
}

private class AndroidCaptureDispatch : AudioCaptureCoordinator.CaptureDispatch {
  private val main = Handler(Looper.getMainLooper())
  private val hardware = Executors.newSingleThreadExecutor { task ->
    Thread(task, "ostinato-capture-hardware").apply { isDaemon = true }
  }

  override fun hardware(task: () -> Unit) { hardware.execute(task) }
  override fun reader(task: () -> Unit): AudioCaptureCoordinator.ReadHandle {
    val thread = Thread(task, "ostinato-capture-read").apply { isDaemon = true; start() }
    return object : AudioCaptureCoordinator.ReadHandle {
      override fun awaitExit(timeoutMs: Long): Boolean {
        thread.join(timeoutMs)
        return !thread.isAlive
      }
    }
  }
  override fun main(task: () -> Unit) { main.post(task) }
  override fun after(delayMs: Long, task: () -> Unit) { main.postDelayed(task, delayMs) }
}

private class AndroidRecorderFactory : AudioCaptureCoordinator.RecorderFactory {
  override fun create(sampleRate: Int): AudioCaptureCoordinator.RecorderPort {
    val min = AudioRecord.getMinBufferSize(sampleRate, AudioFormat.CHANNEL_IN_MONO,
      AudioFormat.ENCODING_PCM_16BIT)
    if (min <= 0) throw IllegalStateException("unsupported_sample_rate")
    val record = AudioRecord(MediaRecorder.AudioSource.VOICE_RECOGNITION, sampleRate,
      AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT, min * 2)
    return AndroidRecorderPort(record)
  }
}

private class AndroidRecorderPort(private val record: AudioRecord) : AudioCaptureCoordinator.RecorderPort {
  private var routing: AudioRecord.OnRoutingChangedListener? = null
  override val sampleRate: Int get() = record.sampleRate
  override fun start() {
    if (record.state != AudioRecord.STATE_INITIALIZED || record.sampleRate !in setOf(44100, 48000)) {
      throw IllegalStateException("unsupported_sample_rate")
    }
    record.startRecording()
    if (record.recordingState != AudioRecord.RECORDSTATE_RECORDING) {
      throw IllegalStateException("setup_failed")
    }
  }
  override fun read(buffer: ShortArray): Int = record.read(buffer, 0, buffer.size)
  override fun stop() { record.stop() }
  override fun release() { record.release() }
  override fun watchRoute(changed: () -> Unit) {
    if (Build.VERSION.SDK_INT < 24) return
    val listener = AudioRecord.OnRoutingChangedListener { changed() }
    routing = listener
    record.addOnRoutingChangedListener(listener, Handler(Looper.getMainLooper()))
  }
  override fun unwatchRoute() {
    val listener = routing ?: return
    routing = null
    if (Build.VERSION.SDK_INT >= 24) record.removeOnRoutingChangedListener(listener)
  }
  override fun route(): String {
    if (Build.VERSION.SDK_INT < 24) return "android:Unknown"
    return "android:" + when (record.routedDevice?.type) {
      AudioDeviceInfo.TYPE_BUILTIN_MIC -> "TYPE_BUILTIN_MIC"
      AudioDeviceInfo.TYPE_WIRED_HEADSET -> "TYPE_WIRED_HEADSET"
      AudioDeviceInfo.TYPE_BLUETOOTH_SCO -> "TYPE_BLUETOOTH_SCO"
      AudioDeviceInfo.TYPE_USB_DEVICE -> "TYPE_USB_DEVICE"
      AudioDeviceInfo.TYPE_USB_HEADSET -> "TYPE_USB_HEADSET"
      else -> "Unknown"
    }
  }
}

/** Event subscription ownership is local to this Flutter engine. Hardware ownership is not. */
internal class AudioCaptureStreamer(
  private val context: Context,
  private val owner: Any,
  private val coordinator: AudioCaptureCoordinator,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
  private val ids = AudioCaptureBoundIds()
  private var sink: EventChannel.EventSink? = null
  private var retired = false

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    if (retired && call.method != "closeState") {
      result.error("capture_handler_retired", null, null)
      return
    }
    when (call.method) {
      "ready" -> result.success(call.argument<String>("attemptId") == ids.current && sink != null)
      "closeState" -> result.success(coordinator.closeState())
      "start" -> {
        val id = call.argument<String>("attemptId")
        val rate = call.argument<Int>("sampleRate")
        if (id == null || rate == null || id != ids.current || sink == null) {
          result.error("bad_args", null, null); return
        }
        if (!coordinator.isForeground(owner) ||
          ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
          result.error("not_foreground_or_permitted", null, null); return
        }
        coordinator.start(owner, id, rate, object : AudioCaptureCoordinator.Output {
          override fun event(message: Map<String, Any>) {
            if (ids.current == id) sink?.success(message)
          }
        }, methodReply(result))
      }
      "stop" -> {
        val id = call.argument<String>("attemptId")
        if (id == null) result.error("bad_args", null, null)
        else if (ids.owns(id)) coordinator.stop(owner, id, methodReply(result))
        else coordinator.stopBeforeListen(owner, id, methodReply(result))
      }
      "retryStop" -> {
        val id = call.argument<String>("attemptId")
        if (id == null) result.error("bad_args", null, null)
        else if (!coordinator.isForeground(owner)) {
          result.error("not_foreground_or_permitted", null, null)
        } else coordinator.retryStop(owner, id, methodReply(result))
      }
      else -> result.notImplemented()
    }
  }

  private fun methodReply(result: MethodChannel.Result) = object : AudioCaptureCoordinator.Reply {
    override fun success() { result.success(null) }
    override fun error(code: String) { result.error(code, null, null) }
  }

  override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
    if (retired) { events?.error("capture_handler_retired", null, null); return }
    val id = (arguments as? Map<*, *>)?.get("attemptId") as? String
    if (id == null || id.length != 32 || id.any { it !in '0'..'9' && it !in 'a'..'f' }) {
      events?.error("bad_args", null, null); return
    }
    if (!coordinator.isForeground(owner)) {
      events?.error("not_foreground_or_permitted", null, null); return
    }
    if (!coordinator.bind(owner, id)) {
      events?.error("capture_close_unconfirmed", null, null); return
    }
    val oldId = ids.current
    if (oldId != null && oldId != id) coordinator.requestClose(owner, oldId)
    ids.bind(id)
    sink = events
  }

  override fun onCancel(arguments: Any?) {
    if (retired) return
    // Flutter's implicit onCancel(null) runs on the OLD handler before onListen
    // replaces its binding. Never inspect the process-global current ID here.
    val supplied = (arguments as? Map<*, *>)?.get("attemptId") as? String
    val id = ids.cancel(supplied) ?: return
    sink = null
    coordinator.requestClose(owner, id)
  }

  fun closeBoundAttempt() {
    val id = ids.closeBound() ?: return
    sink = null
    coordinator.requestClose(owner, id)
  }

  fun retire() {
    if (retired) return
    closeBoundAttempt()
    retired = true
    for (id in ids.retire()) coordinator.unbind(owner, id)
  }
}
