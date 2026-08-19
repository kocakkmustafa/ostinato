package com.yulalab.ostinato

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
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

/**
 * Mikrofon → EventChannel, RAM-only (OST-P0-002, roadmap §7) — iOS
 * `AudioCaptureStreamer.swift`in Android karşılığı, AYNI wire format
 * (`{type, samples, sampleRate, t}` / `{type, route}` / `{type, reason}`).
 *
 * Hiçbir satır diske yazmaz: `AudioRecord.read()` doğrudan RAM'deki bir
 * `DoubleArray`e kopyalar, hiçbir `FileOutputStream`/`MediaRecorder`
 * (dosya-yazan sınıf, KASITLI KULLANILMADI — yalnız isim çakışması yüzünden
 * `AudioSource` sabiti için import edilir) çağrısı yok.
 *
 * `MediaRecorder.AudioSource.VOICE_RECOGNITION` bilinçli seçim: `MIC`/
 * `CAMCORDER`nin aksine AGC/gürültü-bastırma/yankı-iptali gibi ölçüm
 * sinyalini bozan işleme katmanlarını platformdan İSTEMEZ (Android'in kendi
 * dokümantasyonu bu kaynağı "ölçüm/tanıma amaçlı, ham'a en yakın" olarak
 * tanımlar) — `ostinato_audio`nun YIN/onset dedektörleri ham sinyal
 * bekliyor, işlenmiş DEĞİL.
 *
 * **Kanıt sınıfı DÜRÜST** (`AudioCaptureStreamer.swift` ile aynı disiplin):
 * bu dosya YALNIZ derleme-zamanı (`flutter build appbundle --release`)
 * kanıtlıdır. Gerçek mikrofon örneği hiç akıtılmadı — cihaz-günü
 * release-gate bunu İLK kez gerçek donanımda ölçecek.
 */
class AudioCaptureStreamer(private val context: Context) :
  MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

  private var audioRecord: AudioRecord? = null
  private var captureThread: Thread? = null

  @Volatile private var running = false
  private var eventSink: EventChannel.EventSink? = null
  private val mainHandler = Handler(Looper.getMainLooper())
  private var routingListener: Any? = null // API 24+ AudioRecord.OnRoutingChangedListener — türü SDK guard'ının İÇİNDE çözülür

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    when (call.method) {
      "start" -> {
        val sampleRate = call.argument<Int>("sampleRate")
        if (sampleRate == null) {
          result.error("bad_args", "sampleRate required", null)
          return
        }
        start(sampleRate, result)
      }
      "stop" -> {
        stop()
        result.success(null)
      }
      else -> result.notImplemented()
    }
  }

  private fun start(sampleRate: Int, result: MethodChannel.Result) {
    if (running) {
      result.success(null) // Dart tarafının kilidi çift-start'ı zaten önler — no-op
      return
    }

    if (ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) !=
        PackageManager.PERMISSION_GRANTED
    ) {
      result.error("setup_failed", "RECORD_AUDIO permission not granted", null)
      return
    }

    val minBuf =
      AudioRecord.getMinBufferSize(
        sampleRate, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT)
    if (minBuf == AudioRecord.ERROR_BAD_VALUE || minBuf == AudioRecord.ERROR) {
      result.error("unsupported_sample_rate", "$sampleRate", null)
      return
    }

    val record =
      try {
        AudioRecord(
          MediaRecorder.AudioSource.VOICE_RECOGNITION,
          sampleRate,
          AudioFormat.CHANNEL_IN_MONO,
          AudioFormat.ENCODING_PCM_16BIT,
          minBuf * 2)
      } catch (e: IllegalArgumentException) {
        result.error("unsupported_sample_rate", "$sampleRate", null)
        return
      }

    if (record.state != AudioRecord.STATE_INITIALIZED) {
      record.release()
      result.error("unsupported_sample_rate", "$sampleRate", null)
      return
    }

    audioRecord = record
    running = true
    record.startRecording()
    registerRoutingListener(record)

    val bufFrames = minBuf / 2 // ENCODING_PCM_16BIT = örnek başına 2 bayt
    captureThread =
      Thread {
        val shortBuf = ShortArray(bufFrames)
        // `while(running)` + içeride try/catch: `stop()` sırası `read()`i
        // erken döndürmesi için tasarlandı (bkz. `stop()` notu) ama bu bir
        // GARANTİ değil, belgelenmemiş bir durum geçişinde `read()` istisna
        // fırlatabilir — yakalanmazsa Android'de HERHANGİ bir thread'deki
        // istisna TÜM app'i çökertir. Basit bir "artık okuma yok" sinyali,
        // app çökmesinden HER ZAMAN daha iyidir.
        while (running) {
          try {
            val read = record.read(shortBuf, 0, shortBuf.size)
            if (read > 0) {
              val tUs = System.nanoTime() / 1000
              val mono = DoubleArray(read)
              for (i in 0 until read) {
                mono[i] = shortBuf[i] / 32768.0
              }
              postChunk(mono, sampleRate, tUs)
            }
          } catch (e: Exception) {
            break
          }
        }
      }
    captureThread?.apply {
      name = "ostinato-audio-capture"
      start()
    }
    result.success(null)
  }

  private fun postChunk(samples: DoubleArray, sampleRate: Int, tUs: Long) {
    mainHandler.post {
      eventSink?.success(
        mapOf(
          "type" to "chunk",
          "samples" to samples,
          "sampleRate" to sampleRate,
          "t" to tUs,
        ))
    }
  }

  /**
   * API 24 altında route-değişimi bildirimi YOK — `unknown` route'ta kalır
   * (roadmap §7 madde 2: `unknown` de `AudioCalibrating`i tetikler, tahmin
   * ÜRETİLMEZ). `minSdk` bugün 24'ün altındaysa bu isimli, kabul edilebilir
   * bir kapsam daralması; capture'ın KENDİSİ etkilenmez.
   */
  private fun registerRoutingListener(record: AudioRecord) {
    if (Build.VERSION.SDK_INT < 24) return
    val listener =
      AudioRecord.OnRoutingChangedListener { r ->
        val device = r.routedDevice ?: return@OnRoutingChangedListener
        mainHandler.post {
          eventSink?.success(
            mapOf("type" to "routeChanged", "route" to "android:${deviceTypeName(device.type)}"))
        }
      }
    routingListener = listener
    record.addOnRoutingChangedListener(listener, mainHandler)
  }

  /**
   * `AudioDeviceInfo.TYPE_*` int sabitini ADINA çevirir — sabit numarayı
   * telden İSİM olarak taşımak, bir SDK sürümünde numara kayarsa (teorik
   * ama motion_camera M-F-260 emsali: sabitler zamanla anlam değiştirebilir)
   * `audio_route_state.dart mapAndroidDeviceType`in SESSİZCE yanlış
   * eşlemesini önler.
   */
  private fun deviceTypeName(type: Int): String =
    when (type) {
      android.media.AudioDeviceInfo.TYPE_BUILTIN_MIC -> "TYPE_BUILTIN_MIC"
      android.media.AudioDeviceInfo.TYPE_WIRED_HEADSET -> "TYPE_WIRED_HEADSET"
      android.media.AudioDeviceInfo.TYPE_BLUETOOTH_SCO -> "TYPE_BLUETOOTH_SCO"
      android.media.AudioDeviceInfo.TYPE_USB_DEVICE -> "TYPE_USB_DEVICE"
      android.media.AudioDeviceInfo.TYPE_USB_HEADSET -> "TYPE_USB_HEADSET"
      else -> "TYPE_UNKNOWN_$type"
    }

  private fun stop() {
    if (!running) return
    running = false

    // SIRA ÖNEMLİ: capture thread şu anda `record.read()` içinde BLOKE
    // olabilir (`while(running)` kontrolü ancak `read()` dönünce tekrar
    // çalışır). `record.release()`i önce çağırıp thread'i sonra join etmek,
    // hâlâ okuma yapan bir kayıttan release sonrası kullanım riski taşırdı.
    // Android'in kendi belgelediği çözüm: `stop()`u ÖNCE çağırmak, bloke
    // `read()`i erkenden döndürür — thread `while(running)`e THEN döner ve
    // hızla çıkar, `join(500)` bu yüzden güvenli bir üst sınır olur.
    val record = audioRecord
    if (record != null) {
      if (Build.VERSION.SDK_INT >= 24) {
        (routingListener as? AudioRecord.OnRoutingChangedListener)?.let {
          record.removeOnRoutingChangedListener(it)
        }
      }
      routingListener = null
      try {
        record.stop()
      } catch (e: IllegalStateException) {
        // `startRecording()` hiç başarılı olmadıysa `stop()` istisna
        // fırlatır — oturum zaten bitiyor, kullanıcıyı ilgilendirmez
        // (iOS `AudioCaptureStreamer.stop()` ile aynı desen).
      }
    }

    captureThread?.join(500)
    captureThread = null

    record?.release()
    audioRecord = null
  }

  // MARK: EventChannel.StreamHandler

  override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
    eventSink = events
  }

  override fun onCancel(arguments: Any?) {
    eventSink = null
  }
}
