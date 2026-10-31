package com.yulalab.ostinato

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioTrack
import android.os.Build
import android.os.Handler
import android.os.Looper
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.atomic.AtomicLong

/** F2.1 overlap bookkeeping, hardware-free so JVM tests can drive it with a fake clock.
 * A frame counts as "possibly audible" from the moment it is queued until the output head has
 * consumed it plus [tailNs] (output latency + room decay, not yet calibrated per route: F3.5). */
internal class PlaybackOverlapTracker(
  private val tailNs: Long = DEFAULT_TAIL_NS,
  private val nowNs: () -> Long = System::nanoTime,
) {
  private val queuedFrames = AtomicLong(0)
  private val tailUntilNs = AtomicLong(Long.MIN_VALUE)

  fun queued(frames: Int) {
    queuedFrames.addAndGet(frames.toLong())
    tailUntilNs.set(nowNs() + tailNs)
  }

  /** [headFrames] is the output's consumed-frame count, or null when it cannot be read. */
  fun isActive(headFrames: Long?): Boolean {
    val now = nowNs()
    if (headFrames == null || queuedFrames.get() > headFrames) {
      tailUntilNs.set(now + tailNs)
      return true
    }
    return now < tailUntilNs.get()
  }

  fun reset() {
    queuedFrames.set(0)
    tailUntilNs.set(Long.MIN_VALUE)
  }

  companion object { const val DEFAULT_TAIL_NS = 300_000_000L }
}

/** Duplex attributes are a deliberate, documented choice (docs/practice/F2.1-ses-oturumu.md):
 * media usage/music content, so the volume keys and focus semantics are those of music. */
internal fun practiceCueAttributes(): AudioAttributes = AudioAttributes.Builder()
  .setUsage(AudioAttributes.USAGE_MEDIA)
  .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
  .build()

/** Capture stays exactly the legacy VOICE_RECOGNITION recorder; this port only adds one
 * streaming AudioTrack and audio focus around it. Every resource is released by [release]. */
internal class AndroidDuplexPort(
  private val record: AndroidRecorderPort,
  private val track: AudioTrack,
  private val audioManager: AudioManager,
  private val tracker: PlaybackOverlapTracker = PlaybackOverlapTracker(),
) : AudioCaptureCoordinator.RecorderPort {
  private val main = Handler(Looper.getMainLooper())
  private val writer: ExecutorService = Executors.newSingleThreadExecutor { task ->
    Thread(task, "ostinato-cue-writer").apply { isDaemon = true }
  }
  private val pendingCues = AtomicInteger(0)
  @Volatile private var interruption: ((String) -> Unit)? = null
  private var trackRouting: AudioTrack.OnRoutingChangedListener? = null
  private var focusRequest: AudioFocusRequest? = null
  private var legacyFocusHeld = false
  private val focusListener = AudioManager.OnAudioFocusChangeListener { change ->
    // A ducking request is applied by the system (API 26+); only a real loss closes practice.
    if (change == AudioManager.AUDIOFOCUS_LOSS || change == AudioManager.AUDIOFOCUS_LOSS_TRANSIENT) {
      interruption?.invoke("audio_focus_lost")
    }
  }

  override val sampleRate: Int get() = record.sampleRate

  override fun start() {
    if (track.state != AudioTrack.STATE_INITIALIZED || track.sampleRate != record.sampleRate) {
      throw IllegalStateException("playback_unavailable")
    }
    requestFocus()
    record.start()
    track.play()
    if (track.playState != AudioTrack.PLAYSTATE_PLAYING) throw IllegalStateException("setup_failed")
  }

  private fun requestFocus() {
    val granted = if (Build.VERSION.SDK_INT >= 26) {
      val request = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
        .setAudioAttributes(practiceCueAttributes())
        .setOnAudioFocusChangeListener(focusListener, main)
        .build()
      focusRequest = request
      audioManager.requestAudioFocus(request)
    } else {
      @Suppress("DEPRECATION")
      audioManager.requestAudioFocus(focusListener, AudioManager.STREAM_MUSIC,
        AudioManager.AUDIOFOCUS_GAIN_TRANSIENT).also { legacyFocusHeld = true }
    }
    if (granted != AudioManager.AUDIOFOCUS_REQUEST_GRANTED) throw IllegalStateException("audio_focus_denied")
  }

  private fun abandonFocus() {
    if (Build.VERSION.SDK_INT >= 26) {
      focusRequest?.let { audioManager.abandonAudioFocusRequest(it) }
      focusRequest = null
    } else if (legacyFocusHeld) {
      @Suppress("DEPRECATION")
      audioManager.abandonAudioFocus(focusListener)
      legacyFocusHeld = false
    }
  }

  override fun read(buffer: ShortArray): Int = record.read(buffer)

  override fun playCue(pcm: ShortArray) {
    if (pendingCues.incrementAndGet() > MAX_PENDING_CUES) {
      pendingCues.decrementAndGet()
      throw IllegalStateException("playback_busy")
    }
    tracker.queued(pcm.size)
    try {
      writer.execute {
        try {
          var offset = 0
          while (offset < pcm.size) {
            val written = track.write(pcm, offset, pcm.size - offset, AudioTrack.WRITE_BLOCKING)
            if (written <= 0) break // paused/stopped by close, or a write error
            offset += written
          }
        } catch (_: Throwable) {
        } finally {
          pcm.fill(0)
          pendingCues.decrementAndGet()
        }
      }
    } catch (failure: Throwable) {
      pendingCues.decrementAndGet()
      throw failure
    }
  }

  override fun playbackActive(): Boolean {
    val head = try { track.playbackHeadPosition.toLong() and 0xffffffffL } catch (_: Throwable) { null }
    return tracker.isActive(head)
  }

  override fun stop() {
    var failure: Throwable? = null
    try { record.stop() } catch (error: Throwable) { failure = error }
    // pause() makes a blocking stream write return early, so the writer cannot hold close.
    try { track.pause(); track.flush(); track.stop() } catch (error: Throwable) { failure = failure ?: error }
    failure?.let { throw it }
  }

  override fun release() {
    var failure: Throwable? = null
    try { abandonFocus() } catch (error: Throwable) { failure = error }
    try { if (track.playState == AudioTrack.PLAYSTATE_PLAYING) track.pause() } catch (_: Throwable) {}
    writer.shutdownNow()
    try {
      if (!writer.awaitTermination(WRITER_EXIT_BUDGET_MS, TimeUnit.MILLISECONDS)) {
        failure = failure ?: IllegalStateException("cue_writer_running")
      }
    } catch (error: Throwable) { failure = failure ?: error }
    tracker.reset()
    try { track.release() } catch (error: Throwable) { failure = failure ?: error }
    try { record.release() } catch (error: Throwable) { failure = failure ?: error }
    failure?.let { throw it }
  }

  override fun route(): String = record.route()

  override fun watchRoute(changed: () -> Unit) {
    record.watchRoute(changed)
    // Headphones in/out move the OUTPUT; iOS treats every route change the same way.
    if (Build.VERSION.SDK_INT < 24) return
    val listener = AudioTrack.OnRoutingChangedListener { changed() }
    trackRouting = listener
    track.addOnRoutingChangedListener(listener, main)
  }

  override fun unwatchRoute() {
    record.unwatchRoute()
    val listener = trackRouting ?: return
    trackRouting = null
    if (Build.VERSION.SDK_INT >= 24) track.removeOnRoutingChangedListener(listener)
  }

  override fun watchInterruption(interrupted: (String) -> Unit) { interruption = interrupted }
  override fun unwatchInterruption() { interruption = null }

  companion object {
    const val MAX_PENDING_CUES = 4
    const val WRITER_EXIT_BUDGET_MS = 500L

    fun create(context: Context, record: AndroidRecorderPort, sampleRate: Int): AndroidDuplexPort {
      val manager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
      val min = AudioTrack.getMinBufferSize(sampleRate, AudioFormat.CHANNEL_OUT_MONO,
        AudioFormat.ENCODING_PCM_16BIT)
      if (min <= 0) {
        record.release()
        throw IllegalStateException("unsupported_sample_rate")
      }
      val builder = AudioTrack.Builder()
        .setAudioAttributes(practiceCueAttributes())
        .setAudioFormat(AudioFormat.Builder()
          .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
          .setSampleRate(sampleRate)
          .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
          .build())
        .setTransferMode(AudioTrack.MODE_STREAM)
        .setBufferSizeInBytes(min * 2)
      if (Build.VERSION.SDK_INT >= 26) builder.setPerformanceMode(AudioTrack.PERFORMANCE_MODE_LOW_LATENCY)
      val track = try { builder.build() } catch (error: Throwable) { record.release(); throw error }
      return AndroidDuplexPort(record, track, manager)
    }
  }
}
