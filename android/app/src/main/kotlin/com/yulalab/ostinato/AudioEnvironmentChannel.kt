package com.yulalab.ostinato

import android.content.Context
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build
import android.annotation.TargetApi
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * F4.2 setup wizard: read-only report of the phone's audio devices. Changes
 * nothing and asks for no permission. Names follow the capture route-tag
 * vocabulary (`TYPE_BUILTIN_MIC`, …) that `audio_route_state.dart` maps.
 *
 * Android has no Mic Mode; `micMode` is always "unknown".
 */
object AudioEnvironmentChannel {
  const val NAME = "com.yulalab.ostinato/audio_environment"

  fun register(engine: FlutterEngine, context: Context) {
    val app = context.applicationContext
    MethodChannel(engine.dartExecutor.binaryMessenger, NAME).setMethodCallHandler { call, result ->
      if (call.method != "read") {
        result.notImplemented()
        return@setMethodCallHandler
      }
      if (Build.VERSION.SDK_INT < 23) {
        result.success(mapOf("platform" to "android", "inputs" to emptyList<String>(),
          "outputs" to emptyList<String>(), "micMode" to "unknown"))
        return@setMethodCallHandler
      }
      val am = app.getSystemService(Context.AUDIO_SERVICE) as AudioManager
      result.success(
        mapOf(
          "platform" to "android",
          "inputs" to inputs(am),
          "outputs" to outputs(am),
          "micMode" to "unknown",
        ),
      )
    }
  }

  /** Inputs the capture can land on. Bluetooth SCO is listed whenever a headset is
   * paired but is only used for calls, so it is left out (no false warning). */
  @TargetApi(23)
  private fun inputs(am: AudioManager): List<String> =
    am.getDevices(AudioManager.GET_DEVICES_INPUTS)
      .map { typeName(it.type) }
      .filter { it == "TYPE_BUILTIN_MIC" || it == "TYPE_WIRED_HEADSET" || it.startsWith("TYPE_USB") }
      .distinct()

  /** Media goes to the most specific connected output; the speaker is the fallback. */
  @TargetApi(23)
  private fun outputs(am: AudioManager): List<String> {
    val names = am.getDevices(AudioManager.GET_DEVICES_OUTPUTS).map { typeName(it.type) }.toSet()
    val order = listOf(
      "TYPE_BLUETOOTH_A2DP", "TYPE_BLE_HEADSET", "TYPE_BLE_SPEAKER",
      "TYPE_WIRED_HEADPHONES", "TYPE_WIRED_HEADSET",
      "TYPE_USB_HEADSET", "TYPE_USB_DEVICE", "TYPE_BUILTIN_SPEAKER",
    )
    val active = order.firstOrNull { it in names }
    return if (active == null) emptyList() else listOf(active)
  }

  private fun typeName(type: Int): String = when (type) {
    AudioDeviceInfo.TYPE_BUILTIN_MIC -> "TYPE_BUILTIN_MIC"
    AudioDeviceInfo.TYPE_BUILTIN_SPEAKER -> "TYPE_BUILTIN_SPEAKER"
    AudioDeviceInfo.TYPE_BUILTIN_EARPIECE -> "TYPE_BUILTIN_EARPIECE"
    AudioDeviceInfo.TYPE_WIRED_HEADSET -> "TYPE_WIRED_HEADSET"
    AudioDeviceInfo.TYPE_WIRED_HEADPHONES -> "TYPE_WIRED_HEADPHONES"
    AudioDeviceInfo.TYPE_BLUETOOTH_SCO -> "TYPE_BLUETOOTH_SCO"
    AudioDeviceInfo.TYPE_BLUETOOTH_A2DP -> "TYPE_BLUETOOTH_A2DP"
    AudioDeviceInfo.TYPE_BLE_HEADSET -> "TYPE_BLE_HEADSET"
    AudioDeviceInfo.TYPE_BLE_SPEAKER -> "TYPE_BLE_SPEAKER"
    AudioDeviceInfo.TYPE_USB_DEVICE -> "TYPE_USB_DEVICE"
    AudioDeviceInfo.TYPE_USB_HEADSET -> "TYPE_USB_HEADSET"
    AudioDeviceInfo.TYPE_USB_ACCESSORY -> "TYPE_USB_ACCESSORY"
    else -> "Unknown"
  }
}
