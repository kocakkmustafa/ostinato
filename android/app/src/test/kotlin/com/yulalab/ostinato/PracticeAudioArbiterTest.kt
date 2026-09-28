package com.yulalab.ostinato

import org.junit.Assert.*
import org.junit.Test
import java.util.ArrayDeque

class PracticeAudioArbiterTest {
  private val a = "a".repeat(32)
  private val b = "b".repeat(32)
  private val c = "c".repeat(32)

  private class Work : PracticeAudioArbiter.Work, AudioCaptureCoordinator.CaptureDispatch {
    val hardwareJobs = ArrayDeque<() -> Unit>()
    val mainJobs = ArrayDeque<() -> Unit>()
    val timers = mutableListOf<Pair<Long, () -> Unit>>()
    var now = 0L
    override fun hardware(task: () -> Unit) { hardwareJobs.addLast(task) }
    override fun main(task: () -> Unit) { mainJobs.addLast(task) }
    override fun after(delayMs: Long, task: () -> Unit) { timers.add(now + delayMs to task) }
    override fun reader(task: () -> Unit): AudioCaptureCoordinator.ReadHandle =
      object : AudioCaptureCoordinator.ReadHandle {
        override fun awaitExit(timeoutMs: Long) = true
      }
    fun hardwareOne() { hardwareJobs.removeFirst().invoke() }
    fun mainAll() { while (mainJobs.isNotEmpty()) mainJobs.removeFirst().invoke() }
    fun drain() { while (hardwareJobs.isNotEmpty()) { hardwareOne(); mainAll() } }
    fun advance(ms: Long) {
      now += ms
      val ready = timers.filter { it.first <= now }
      timers.removeAll(ready.toSet())
      ready.forEach { it.second.invoke() }
      mainAll()
    }
  }

  private class Recorder : AudioCaptureCoordinator.RecorderPort {
    override val sampleRate = 44100
    var starts = 0
    var stops = 0
    var releases = 0
    var routeCallback: (() -> Unit)? = null
    override fun start() { ++starts }
    override fun read(buffer: ShortArray) = 0
    override fun stop() { ++stops }
    override fun release() { ++releases }
    override fun route() = "android:TYPE_BUILTIN_MIC"
    override fun watchRoute(changed: () -> Unit) { routeCallback = changed }
    override fun unwatchRoute() { routeCallback = null }
  }

  private class OutputPort : PracticeAudioArbiter.OutputPort {
    var starts = 0
    var stops = 0
    var releases = 0
    var startThrows = false
    var releaseThrows = false
    override fun start() {
      ++starts
      if (startThrows) throw IllegalStateException("start")
    }
    override fun stop() { ++stops }
    override fun release() {
      ++releases
      if (releaseThrows) throw IllegalStateException("release")
    }
  }

  private class CaptureReply : AudioCaptureCoordinator.Reply {
    val calls = mutableListOf<String>()
    override fun success() { calls += "ok" }
    override fun error(code: String) { calls += code }
  }
  private class OutputReply : PracticeAudioArbiter.Reply {
    val calls = mutableListOf<String>()
    override fun success(value: Map<String, Any?>) { calls += value["status"] as String }
    override fun error(code: String) { calls += code }
  }
  private class CaptureOutput : AudioCaptureCoordinator.Output {
    override fun event(message: Map<String, Any>) {}
  }

  private class Harness(withOutput: Boolean = true) {
    val work = Work()
    val recorder = Recorder()
    val output = OutputPort()
    val arbiter = PracticeAudioArbiter(work,
      if (withOutput) object : PracticeAudioArbiter.OutputFactory {
        override fun create(assetId: String) = output
      } else null,
      if (withOutput) setOf("approved_fixture") else emptySet())
    val capture = AudioCaptureCoordinator(
      object : AudioCaptureCoordinator.RecorderFactory {
        override fun create(sampleRate: Int) = recorder
      }, work, arbiter = arbiter,
    )
    init { arbiter.attachCapture(capture) }

    fun bind(owner: Any = Any(), engine: Any = Any()): PracticeAudioArbiter.Binding =
      arbiter.registerEngine(owner, engine).also { arbiter.foreground(it, true) }

    fun state(owner: PracticeAudioArbiter.Binding): Map<String, Any?> =
      arbiter.readAllAudioState(owner, owner.ownerToken, owner.engineGeneration)

    fun reserve(owner: PracticeAudioArbiter.Binding, id: String, side: String): Map<String, Any?> =
      arbiter.reserve(owner, owner.ownerToken, owner.engineGeneration,
        state(owner)["contextGeneration"] as Long, id, side)

    fun close(owner: PracticeAudioArbiter.Binding, id: String, permit: Map<String, Any?>): Map<String, Any?> =
      arbiter.closeAll(owner, owner.ownerToken, owner.engineGeneration,
        state(owner)["contextGeneration"] as Long, id,
        permit["leaseGeneration"] as Long, "userStop")

    fun startCapture(owner: PracticeAudioArbiter.Binding, id: String): CaptureReply {
      capture.bind(owner.activityOwner, id)
      return CaptureReply().also {
        capture.start(owner.activityOwner, id, 44100, CaptureOutput(), it)
      }
    }

    fun startOutput(owner: PracticeAudioArbiter.Binding, id: String,
                    permit: Map<String, Any?>): OutputReply = OutputReply().also {
      arbiter.startOutput(owner, owner.ownerToken, owner.engineGeneration,
        state(owner)["contextGeneration"] as Long, id,
        permit["leaseGeneration"] as Long, "approved_fixture", it)
    }
  }

  private inline fun expectCode(code: String, block: () -> Unit) {
    try { block(); fail("Expected $code") }
    catch (fault: PracticeAudioArbiter.AudioFault) { assertEquals(code, fault.code) }
  }

  @Test fun outputReservationAndLegacyCaptureStartAreAtomicMutualExclusions() {
    val h = Harness(); val owner = h.bind()
    val permit = h.reserve(owner, a, "output")
    assertFalse(h.state(owner)["allClear"] as Boolean)
    assertEquals(listOf("capture_close_unconfirmed"), h.startCapture(owner, b).calls)
    assertEquals(0, h.recorder.starts)
    assertEquals("closed", h.close(owner, a, permit)["status"])
    val started = h.startCapture(owner, c)
    h.work.hardwareOne(); h.work.mainAll()
    assertEquals(listOf("ok"), started.calls)
    expectCode("audio_busy") { h.reserve(owner, b, "output") }
    assertEquals(0, h.output.starts)
    h.capture.requestCloseGlobal(); h.work.drain()
    assertEquals(true, h.state(owner)["allClear"])
  }

  @Test fun outputPlayCloseAndInputTransitionWaitForRelease() {
    val h = Harness(); val owner = h.bind()
    val permit = h.reserve(owner, a, "output")
    val playing = h.startOutput(owner, a, permit)
    assertEquals("starting", h.state(owner)["outputPhase"])
    assertEquals(listOf("capture_close_unconfirmed"), h.startCapture(owner, b).calls)
    h.work.hardwareOne(); h.work.mainAll()
    assertEquals(listOf("playing"), playing.calls)
    assertEquals("playing", h.state(owner)["outputPhase"])
    assertEquals("pending", h.close(owner, a, permit)["status"])
    expectCode("audio_busy") { h.reserve(owner, b, "input") }
    h.work.hardwareOne(); h.work.mainAll()
    assertEquals(1, h.output.stops)
    assertEquals(1, h.output.releases)
    assertEquals(true, h.state(owner)["allClear"])
    assertEquals("reserved", h.reserve(owner, b, "input")["status"])
  }

  @Test fun reservedInputRequiresMatchingNativePermitAndBlocksOutput() {
    val h = Harness(); val owner = h.bind()
    val permit = h.reserve(owner, a, "input")
    assertEquals(listOf("capture_close_unconfirmed"), h.startCapture(owner, b).calls)
    expectCode("audio_busy") { h.reserve(owner, c, "output") }
    val claim = PracticeAudioArbiter.CaptureClaim(owner.ownerToken,
      owner.engineGeneration, h.state(owner)["contextGeneration"] as Long,
      a, permit["leaseGeneration"] as Long)
    h.capture.bind(owner.activityOwner, b)
    val started = CaptureReply()
    h.capture.start(owner.activityOwner, b, 44100, CaptureOutput(), started, claim)
    h.work.hardwareOne(); h.work.mainAll()
    assertEquals(listOf("ok"), started.calls)
    assertEquals("running", h.state(owner)["inputPhase"])
    assertEquals("input", h.state(owner)["activeSide"])
    assertEquals("pending", h.close(owner, a, permit)["status"])
    h.work.drain()
    assertEquals(true, h.state(owner)["allClear"])
  }

  @Test fun timedOutOutputReleaseNeedsNewVisibleRevisionBoundRetry() {
    val h = Harness(); val owner = h.bind()
    val permit = h.reserve(owner, a, "output")
    h.startOutput(owner, a, permit)
    h.work.hardwareOne(); h.work.mainAll()
    assertEquals("pending", h.close(owner, a, permit)["status"])
    h.work.advance(2_000) // The release worker has not run.
    assertEquals("unconfirmedInFlight", h.state(owner)["outputPhase"])
    h.work.hardwareOne(); h.work.mainAll()
    val sticky = h.state(owner)
    assertEquals("releasedAwaitingExplicitRetry", sticky["outputPhase"])
    assertEquals(true, sticky["requiresExplicitRetry"])
    expectCode("audio_busy") { h.reserve(owner, b, "input") }
    val stale = h.arbiter.recoverAll(owner, owner.ownerToken, owner.engineGeneration,
      (sticky["stateRevision"] as Long) - 1, "userRetry")
    assertEquals("stale", stale["status"])
    assertEquals("closed", h.arbiter.recoverAll(owner, owner.ownerToken,
      owner.engineGeneration, sticky["stateRevision"] as Long, "userRetry")["status"])
    assertEquals(1, h.output.releases)
    assertEquals("reserved", h.reserve(owner, b, "input")["status"])
  }

  @Test fun engineReplacementFencesBlockedInputAndOldPauseCannotCloseNewOwner() {
    val h = Harness(); val activityA = Any(); val activityB = Any()
    val old = h.bind(activityA)
    val aStart = h.startCapture(old, a) // factory/create worker deliberately held
    val current = h.bind(activityB) // registration revokes A before B is foreground
    expectCode("stale_audio_owner") {
      h.arbiter.readAllAudioState(old, old.ownerToken, old.engineGeneration)
    }
    assertEquals(listOf("capture_start_cancelled"), aStart.calls)
    expectCode("audio_busy") { h.reserve(current, b, "output") }
    h.work.hardwareOne(); h.work.mainAll() // late A create does not start
    h.work.hardwareOne(); h.work.mainAll() // close releases A
    assertEquals(0, h.recorder.starts)
    assertEquals(1, h.recorder.releases)
    val permit = h.reserve(current, b, "output")
    h.arbiter.foreground(old, false) // stale A.onPause arrives after B.onResume
    expectCode("stale_audio_owner") {
      h.arbiter.closeAll(old, old.ownerToken, old.engineGeneration,
        h.state(current)["contextGeneration"] as Long, b,
        permit["leaseGeneration"] as Long, "userStop")
    }
    assertEquals("reserved", h.state(current)["outputPhase"])
    assertEquals("closed", h.arbiter.fenceContext(current, current.ownerToken,
      current.engineGeneration, h.state(current)["contextGeneration"] as Long,
      "background")["status"])
    assertEquals(true, h.state(current)["allClear"])
    assertEquals(permit["leaseGeneration"], 1L)
  }

  @Test fun newEngineExplicitlyAcknowledgesRetiredInputCloseOnlyAtFreshRevision() {
    val h = Harness(); val activityA = Any(); val activityB = Any()
    val old = h.bind(activityA)
    val started = h.startCapture(old, a)
    h.work.hardwareOne(); h.work.mainAll()
    assertEquals(listOf("ok"), started.calls)
    val stopped = CaptureReply()
    h.capture.stop(activityA, a, stopped)
    h.work.advance(2_000) // Method result times out before AudioRecord release.
    h.work.hardwareOne(); h.work.mainAll()
    assertEquals("releasedAwaitingExplicitRetry", h.capture.closeState()["phase"])
    val current = h.bind(activityB)
    val sticky = h.state(current)
    assertEquals(false, sticky["allClear"])
    assertEquals(true, sticky["requiresExplicitRetry"])
    expectCode("audio_busy") { h.reserve(current, b, "output") }
    val wrongRevision = h.arbiter.recoverAll(current, current.ownerToken,
      current.engineGeneration, (sticky["stateRevision"] as Long) - 1, "userRetry")
    assertEquals("stale", wrongRevision["status"])
    assertEquals("closed", h.arbiter.recoverAll(current, current.ownerToken,
      current.engineGeneration, sticky["stateRevision"] as Long, "userRetry")["status"])
    assertEquals(1, h.recorder.releases)
    assertEquals("reserved", h.reserve(current, b, "output")["status"])
  }

  @Test fun staleRouteCallbackCannotCloseNewActivityButCurrentRouteChangeDoes() {
    val h = Harness(); val activityA = Any(); val activityB = Any()
    val old = h.bind(activityA)
    h.startCapture(old, a)
    h.work.hardwareOne(); h.work.mainAll()
    val staleCallback = h.recorder.routeCallback!!
    h.capture.requestCloseGlobal(); h.work.drain()
    val current = h.bind(activityB)
    val started = h.startCapture(current, b)
    h.work.hardwareOne(); h.work.mainAll()
    assertEquals(listOf("ok"), started.calls)
    staleCallback(); h.work.mainAll()
    assertEquals("running", h.capture.closeState()["phase"])
    h.recorder.routeCallback!!(); h.work.mainAll()
    assertEquals("closing", h.capture.closeState()["phase"])
    h.work.drain()
    assertEquals(true, h.state(current)["allClear"])
  }

  @Test fun contextFenceDuringQueuedOutputStartNeverCommitsOldAudio() {
    val h = Harness(); val owner = h.bind()
    val permit = h.reserve(owner, a, "output")
    val playing = h.startOutput(owner, a, permit)
    val priorContext = h.state(owner)["contextGeneration"] as Long
    val fenced = h.arbiter.fenceContext(owner, owner.ownerToken,
      owner.engineGeneration, priorContext, "accountChange")
    assertEquals("pending", fenced["status"])
    assertEquals(0, h.output.starts)
    h.work.hardwareOne(); h.work.mainAll()
    h.work.drain()
    assertEquals(0, h.output.starts)
    assertEquals(1, h.output.releases)
    assertEquals(listOf("audio_close_unconfirmed"), playing.calls)
    assertEquals(true, h.state(owner)["allClear"])
    expectCode("stale_audio_context") {
      h.arbiter.reserve(owner, owner.ownerToken, owner.engineGeneration,
        priorContext, b, "input")
    }
  }

  @Test fun currentActivityBackgroundClosesOutputAndForegroundDoesNotResumeIt() {
    val h = Harness(); val owner = h.bind()
    val permit = h.reserve(owner, a, "output")
    h.startOutput(owner, a, permit)
    h.work.hardwareOne(); h.work.mainAll()
    assertEquals(1, h.output.starts)
    h.arbiter.foreground(owner, false)
    assertEquals("closing", h.state(owner)["outputPhase"])
    h.work.hardwareOne(); h.work.mainAll()
    assertEquals(1, h.output.releases)
    assertEquals(true, h.state(owner)["allClear"])
    expectCode("not_foreground_or_permitted") { h.reserve(owner, b, "input") }
    h.arbiter.foreground(owner, true)
    assertEquals(1, h.output.starts)
    assertEquals("reserved", h.reserve(owner, b, "input")["status"])
  }

  @Test fun failedOutputReleaseBlocksInputUntilExplicitRetrySucceeds() {
    val h = Harness(); val owner = h.bind()
    val permit = h.reserve(owner, a, "output")
    h.startOutput(owner, a, permit)
    h.work.hardwareOne(); h.work.mainAll()
    h.output.releaseThrows = true
    assertEquals("pending", h.close(owner, a, permit)["status"])
    h.work.hardwareOne(); h.work.mainAll()
    val blocked = h.state(owner)
    assertEquals("unconfirmedQuiescent", blocked["outputPhase"])
    assertEquals(false, blocked["outputReleased"])
    expectCode("audio_busy") { h.reserve(owner, b, "input") }
    h.output.releaseThrows = false
    val retry = h.arbiter.recoverAll(owner, owner.ownerToken,
      owner.engineGeneration, blocked["stateRevision"] as Long, "userRetry")
    assertEquals("pending", retry["status"])
    h.work.hardwareOne(); h.work.mainAll()
    assertEquals(true, h.state(owner)["allClear"])
    assertEquals(2, h.output.releases)
  }

  @Test fun setupErrorIsReportedOnlyAfterVerifiedRollback() {
    val h = Harness(); val owner = h.bind()
    val permit = h.reserve(owner, a, "output")
    h.output.startThrows = true
    val reply = h.startOutput(owner, a, permit)
    h.work.hardwareOne(); h.work.mainAll()
    assertTrue(reply.calls.isEmpty()) // Port still has to stop and release.
    assertEquals("closing", h.state(owner)["outputPhase"])
    h.work.hardwareOne(); h.work.mainAll()
    assertEquals(listOf("output_setup_failed"), reply.calls)
    assertEquals(1, h.output.releases)
    assertEquals(true, h.state(owner)["allClear"])
  }

  @Test fun unapprovedOutputHasNoPortAndNoPlaybackReceipt() {
    val h = Harness(withOutput = false); val owner = h.bind()
    val permit = h.reserve(owner, a, "output")
    val reply = h.startOutput(owner, a, permit)
    assertEquals(listOf("output_asset_unavailable"), reply.calls)
    assertEquals(0, h.work.hardwareJobs.size)
    assertEquals(true, h.state(owner)["allClear"])
  }

  @Test fun cleanLateOutputCloseCanBeAcknowledgedWithoutClosingNewerLease() {
    val h = Harness(); val owner = h.bind()
    val permit = h.reserve(owner, a, "output")
    h.startOutput(owner, a, permit)
    h.work.hardwareOne(); h.work.mainAll()
    assertEquals("pending", h.close(owner, a, permit)["status"])
    h.work.drain()
    val clear = h.state(owner)
    assertEquals(true, clear["allClear"])
    val recovered = h.arbiter.recoverAll(owner, owner.ownerToken,
      owner.engineGeneration, clear["stateRevision"] as Long, "userRetry")
    assertEquals("closed", recovered["status"])
    assertTrue((recovered["snapshot"] as Map<*, *>)["stateRevision"] as Long >
      clear["stateRevision"] as Long)

    val next = h.reserve(owner, b, "input")
    val oldClose = h.close(owner, a, permit)
    assertEquals("stale", oldClose["status"])
    assertEquals(false, (oldClose["snapshot"] as Map<*, *>)["allClear"])
    assertEquals("input", h.state(owner)["activeSide"])
    assertEquals("closed", h.close(owner, b, next)["status"])
    val empty = h.state(owner)
    val lateOldClose = h.close(owner, a, permit)
    assertEquals("closed", lateOldClose["status"])
    assertTrue((lateOldClose["snapshot"] as Map<*, *>)["stateRevision"] as Long >
      empty["stateRevision"] as Long)
  }

  @Test fun cleanLateInputCloseCanBeAcknowledgedAtFreshRevision() {
    val h = Harness(); val owner = h.bind()
    val permit = h.reserve(owner, a, "input")
    val claim = PracticeAudioArbiter.CaptureClaim(owner.ownerToken,
      owner.engineGeneration, h.state(owner)["contextGeneration"] as Long,
      a, permit["leaseGeneration"] as Long)
    h.capture.bind(owner.activityOwner, a)
    val started = CaptureReply()
    h.capture.start(owner.activityOwner, a, 44100, CaptureOutput(), started, claim)
    h.work.hardwareOne(); h.work.mainAll()
    assertEquals(listOf("ok"), started.calls)
    assertEquals("pending", h.close(owner, a, permit)["status"])
    h.work.drain()
    val clear = h.state(owner)
    assertEquals(true, clear["allClear"])
    val recovered = h.arbiter.recoverAll(owner, owner.ownerToken,
      owner.engineGeneration, clear["stateRevision"] as Long, "userRetry")
    assertEquals("closed", recovered["status"])
    assertTrue((recovered["snapshot"] as Map<*, *>)["stateRevision"] as Long >
      clear["stateRevision"] as Long)
  }
}
