package com.yulalab.ostinato

import org.junit.Assert.*
import org.junit.Test
import java.util.ArrayDeque

/** F2.1 — play+record practice session. Hardware-free: the duplex port is a fake. */
class PracticeDuplexCaptureTest {
  private val owner = Any()
  private val a = "a".repeat(32)

  private class Result : AudioCaptureCoordinator.Reply {
    val calls = mutableListOf<String>()
    override fun success() { calls.add("ok") }
    override fun error(code: String) { calls.add(code) }
  }

  private class Output : AudioCaptureCoordinator.Output {
    val events = mutableListOf<Map<String, Any>>()
    override fun event(message: Map<String, Any>) { events.add(message) }
  }

  private class Dispatch : AudioCaptureCoordinator.CaptureDispatch {
    val hardware = ArrayDeque<() -> Unit>()
    val mains = ArrayDeque<() -> Unit>()
    val readers = mutableListOf<() -> Unit>()
    override fun hardware(task: () -> Unit) { hardware.addLast(task) }
    override fun reader(task: () -> Unit): AudioCaptureCoordinator.ReadHandle {
      readers.add(task)
      return object : AudioCaptureCoordinator.ReadHandle {
        override fun awaitExit(timeoutMs: Long) = true
      }
    }
    override fun main(task: () -> Unit) { mains.addLast(task) }
    override fun after(delayMs: Long, task: () -> Unit) {}
    fun drain() {
      while (hardware.isNotEmpty() || mains.isNotEmpty()) {
        while (hardware.isNotEmpty()) hardware.removeFirst().invoke()
        while (mains.isNotEmpty()) mains.removeFirst().invoke()
      }
    }
  }

  private class Port(override val sampleRate: Int = 48000) : AudioCaptureCoordinator.RecorderPort {
    var reads = ArrayDeque<Int>()
    var overlap = false
    val cues = mutableListOf<ShortArray>()
    var stops = 0
    var releases = 0
    var interruption: ((String) -> Unit)? = null
    var unwatchedInterruption = 0
    override fun start() {}
    override fun read(buffer: ShortArray): Int {
      val next = if (reads.isEmpty()) -1 else reads.removeFirst()
      if (next > 0) buffer.fill(16384, 0, next)
      return next
    }
    override fun stop() { stops++ }
    override fun release() { releases++ }
    override fun route() = "android:TYPE_BUILTIN_MIC"
    override fun watchRoute(changed: () -> Unit) {}
    override fun unwatchRoute() {}
    override fun playCue(pcm: ShortArray) { cues.add(pcm.copyOf()) }
    override fun playbackActive() = overlap
    override fun watchInterruption(interrupted: (String) -> Unit) { interruption = interrupted }
    override fun unwatchInterruption() { interruption = null; unwatchedInterruption++ }
  }

  /** Records which mode each create asked for; record-only factories keep the default. */
  private class Factory(val port: Port, val duplexCapable: Boolean = true) :
    AudioCaptureCoordinator.RecorderFactory {
    val modes = mutableListOf<CaptureSessionMode>()
    override fun create(sampleRate: Int): AudioCaptureCoordinator.RecorderPort {
      modes.add(CaptureSessionMode.RECORD_ONLY)
      return port
    }
    override fun create(sampleRate: Int, mode: CaptureSessionMode): AudioCaptureCoordinator.RecorderPort {
      if (!duplexCapable) return super.create(sampleRate, mode)
      modes.add(mode)
      return port
    }
  }

  private fun machine(dispatch: Dispatch, factory: AudioCaptureCoordinator.RecorderFactory) =
    AudioCaptureCoordinator(factory, dispatch).also { it.foreground(owner, true) }

  private fun running(
    dispatch: Dispatch, machine: AudioCaptureCoordinator, mode: CaptureSessionMode,
    output: Output = Output(), rate: Int = 48000,
  ): Result {
    val result = Result()
    machine.bind(owner, a)
    machine.start(owner, a, rate, output, result, mode = mode)
    dispatch.drain()
    return result
  }

  @Test fun recordOnlyKeepsLegacyChunkShapeAndRefusesCues() {
    val dispatch = Dispatch(); val port = Port(); val factory = Factory(port)
    val coordinator = machine(dispatch, factory)
    val output = Output()
    assertEquals(listOf("ok"), running(dispatch, coordinator, CaptureSessionMode.RECORD_ONLY, output).calls)
    assertEquals(listOf(CaptureSessionMode.RECORD_ONLY), factory.modes)
    assertNull(port.interruption)
    val cue = Result()
    coordinator.playCue(owner, a, doubleArrayOf(0.5), 48000, cue)
    assertEquals(listOf("playback_not_enabled"), cue.calls)
    port.reads.addLast(4)
    dispatch.readers.single().invoke(); dispatch.drain()
    val chunk = output.events.first { it["type"] == "chunk" }
    assertEquals(setOf("type", "attemptId", "samples", "sampleRate", "t"), chunk.keys)
  }

  @Test fun duplexChunkReportsPlaybackOverlap() {
    val dispatch = Dispatch(); val port = Port(); val coordinator = machine(dispatch, Factory(port))
    val output = Output()
    assertEquals(listOf("ok"), running(dispatch, coordinator, CaptureSessionMode.PLAY_AND_RECORD, output).calls)
    port.overlap = true
    port.reads.addLast(4)
    dispatch.readers.single().invoke(); dispatch.drain()
    val chunk = output.events.first { it["type"] == "chunk" }
    assertEquals(true, chunk["playbackActive"])
    assertEquals(48000, chunk["sampleRate"])
  }

  @Test fun duplexOnRecordOnlyFactoryFailsClosed() {
    val dispatch = Dispatch(); val port = Port()
    val coordinator = machine(dispatch, Factory(port, duplexCapable = false))
    val result = running(dispatch, coordinator, CaptureSessionMode.PLAY_AND_RECORD)
    assertEquals(listOf("setup_failed"), result.calls)
    assertEquals("clear", coordinator.closeState()["phase"])
  }

  @Test fun cueIsScaledAndValidatedInsideTheRunningAttempt() {
    val dispatch = Dispatch(); val port = Port(); val coordinator = machine(dispatch, Factory(port))
    running(dispatch, coordinator, CaptureSessionMode.PLAY_AND_RECORD)
    val ok = Result()
    coordinator.playCue(owner, a, doubleArrayOf(0.0, 0.5, -1.0), 48000, ok)
    assertEquals(listOf("ok"), ok.calls)
    assertArrayEquals(shortArrayOf(0, 16384, -32767), port.cues.single())

    val wrongRate = Result()
    coordinator.playCue(owner, a, doubleArrayOf(0.1), 44100, wrongRate)
    assertEquals(listOf("unsupported_sample_rate"), wrongRate.calls)
    val clipped = Result()
    coordinator.playCue(owner, a, doubleArrayOf(1.5), 48000, clipped)
    assertEquals(listOf("bad_args"), clipped.calls)
    val nan = Result()
    coordinator.playCue(owner, a, doubleArrayOf(Double.NaN), 48000, nan)
    assertEquals(listOf("bad_args"), nan.calls)
    val tooLong = Result()
    coordinator.playCue(owner, a, DoubleArray(48000 * MAX_CUE_SECONDS + 1), 48000, tooLong)
    assertEquals(listOf("bad_args"), tooLong.calls)
    val empty = Result()
    coordinator.playCue(owner, a, DoubleArray(0), 48000, empty)
    assertEquals(listOf("bad_args"), empty.calls)
    val foreign = Result()
    coordinator.playCue(Any(), a, doubleArrayOf(0.1), 48000, foreign)
    assertEquals(listOf("playback_unavailable"), foreign.calls)
    assertEquals(1, port.cues.size)
  }

  @Test fun cueAfterStopIsRefusedAndPortIsReleasedOnce() {
    val dispatch = Dispatch(); val port = Port(); val coordinator = machine(dispatch, Factory(port))
    running(dispatch, coordinator, CaptureSessionMode.PLAY_AND_RECORD)
    val stopped = Result()
    coordinator.stop(owner, a, stopped)
    val late = Result()
    coordinator.playCue(owner, a, doubleArrayOf(0.1), 48000, late)
    assertEquals(listOf("playback_unavailable"), late.calls)
    dispatch.drain()
    assertEquals(listOf("ok"), stopped.calls)
    assertEquals(1, port.stops)
    assertEquals(1, port.releases)
    assertEquals(1, port.unwatchedInterruption)
    assertTrue(port.cues.isEmpty())
  }

  @Test fun focusLossInterruptsAndReleasesTheDuplexAttempt() {
    val dispatch = Dispatch(); val port = Port(); val coordinator = machine(dispatch, Factory(port))
    val output = Output()
    running(dispatch, coordinator, CaptureSessionMode.PLAY_AND_RECORD, output)
    val interrupt = port.interruption!!
    interrupt("audio_focus_lost")
    dispatch.drain()
    assertTrue(output.events.any { it["type"] == "interrupted" && it["reason"] == "audio_focus_lost" })
    assertEquals(1, port.releases)
    assertEquals("clear", coordinator.closeState()["phase"])
    // A late duplicate callback after close is inert.
    interrupt("audio_focus_lost")
    dispatch.drain()
    assertEquals(1, output.events.count { it["type"] == "interrupted" })
  }

  @Test fun sessionModeWireIsOptionalAndExact() {
    val base = mapOf("attemptId" to a, "sampleRate" to 48000, "ownerToken" to "b".repeat(32),
      "engineGeneration" to 1, "contextGeneration" to 0)
    assertEquals(CaptureSessionMode.RECORD_ONLY, parseCaptureSessionMode(base))
    val duplex = base + ("sessionMode" to "playAndRecord")
    assertEquals(CaptureSessionMode.PLAY_AND_RECORD, parseCaptureSessionMode(duplex))
    assertNull(parseCaptureSessionMode(base + ("sessionMode" to "recordOnly")))
    assertNull(parseCaptureSessionMode(base + ("sessionMode" to null)))
    assertNull(parseCaptureStartClaim(duplex))
    assertNotNull(parseCaptureStartClaim(withoutSessionMode(duplex)))
    assertEquals(parseCaptureStartClaim(base), parseCaptureStartClaim(withoutSessionMode(duplex)))
  }

  @Test fun overlapTrackerCoversQueuedFramesPlusTail() {
    var now = 0L
    val tracker = PlaybackOverlapTracker(tailNs = 100, nowNs = { now })
    assertFalse(tracker.isActive(0))
    tracker.queued(480)
    assertTrue(tracker.isActive(0))
    now = 50
    assertTrue(tracker.isActive(480)) // fully consumed, still inside tail
    now = 151
    assertFalse(tracker.isActive(480))
    assertTrue(tracker.isActive(null)) // unreadable head is never "silent"
    now = 300
    tracker.reset()
    assertFalse(tracker.isActive(0))
  }
}
