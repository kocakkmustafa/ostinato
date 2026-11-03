package com.yulalab.ostinato

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioTrack
import android.os.Build

/** FK1 production output: one staged mono float PCM buffer, played once through
 * a static [AudioTrack] with transient media focus. No file, URL or recording. */
internal class ReferenceOutputFactory : PracticeAudioArbiter.StagedOutputFactory {
  private class Staged(val id: String, val samples: FloatArray, val sampleRate: Int)

  @Volatile private var appContext: Context? = null
  private var staged: Staged? = null
  private var serial = 0L

  fun attach(context: Context) { appContext = context.applicationContext }

  @Synchronized override fun stage(samples: FloatArray, sampleRate: Int): String {
    val id = "ref-${++serial}"
    staged = Staged(id, samples, sampleRate)
    return id
  }

  @Synchronized override fun isStaged(assetId: String): Boolean = staged?.id == assetId

  override fun create(assetId: String): PracticeAudioArbiter.OutputPort {
    val buffer = synchronized(this) { staged }
    check(buffer != null && buffer.id == assetId) { "reference not staged" }
    val audio = appContext?.getSystemService(AudioManager::class.java)
      ?: error("audio service unavailable")
    return ReferenceOutputPort(audio, buffer.samples, buffer.sampleRate)
  }
}

private class ReferenceOutputPort(
  private val audio: AudioManager,
  private val samples: FloatArray,
  private val sampleRate: Int,
) : PracticeAudioArbiter.OutputPort {
  private val attributes = AudioAttributes.Builder()
    .setUsage(AudioAttributes.USAGE_MEDIA)
    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
    .build()
  private val focus: AudioFocusRequest? =
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
        .setAudioAttributes(attributes)
        .build()
    } else null
  private var track: AudioTrack? = null
  private var focused = false

  override fun start() {
    val granted = if (focus != null) audio.requestAudioFocus(focus)
      else @Suppress("DEPRECATION") audio.requestAudioFocus(null,
        AudioManager.STREAM_MUSIC, AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
    check(granted == AudioManager.AUDIOFOCUS_REQUEST_GRANTED) { "audio focus denied" }
    focused = true
    try {
      val format = AudioFormat.Builder()
        .setEncoding(AudioFormat.ENCODING_PCM_FLOAT)
        .setSampleRate(sampleRate)
        .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
        .build()
      val created = AudioTrack(attributes, format, samples.size * 4,
        AudioTrack.MODE_STATIC, AudioManager.AUDIO_SESSION_ID_GENERATE)
      track = created
      check(created.write(samples, 0, samples.size, AudioTrack.WRITE_BLOCKING) == samples.size) {
        "reference write failed"
      }
      created.play()
    } catch (failure: Throwable) {
      release()
      throw failure
    }
  }

  override fun stop() {
    track?.let { if (it.playState != AudioTrack.PLAYSTATE_STOPPED) it.stop() }
  }

  override fun release() {
    track?.release()
    track = null
    if (!focused) return
    val abandoned = if (focus != null) audio.abandonAudioFocusRequest(focus)
      else @Suppress("DEPRECATION") audio.abandonAudioFocus(null)
    check(abandoned == AudioManager.AUDIOFOCUS_REQUEST_GRANTED) { "audio focus not released" }
    focused = false
  }
}
