package com.yulalab.ostinato

import org.junit.Assert.*
import org.junit.Test
import java.util.ArrayDeque
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicReference

class PracticeAudioArbiterTest {
  private val a = "a".repeat(32)
  private val b = "b".repeat(32)
  private val c = "c".repeat(32)

  private class Work : PracticeAudioArbiter.Work,
    PracticeAudioArbiter.VideoCloseDispatcher,
    AudioCaptureCoordinator.CaptureDispatch {
    val hardwareJobs = ArrayDeque<() -> Unit>()
    val mainJobs = ArrayDeque<() -> Unit>()
    val timers = mutableListOf<Pair<Long, () -> Unit>>()
    var videoPostAccept = true
    var videoPostThrows = false
    var videoPostInline = false
    var videoDeadlinePostAccept = true
    var videoDeadlinePostThrows = false
    var now = 0L
    override fun hardware(task: () -> Unit) { hardwareJobs.addLast(task) }
    override fun main(task: () -> Unit) { mainJobs.addLast(task) }
    override fun postMain(task: () -> Unit): Boolean {
      if (videoPostThrows) throw IllegalStateException("post failed")
      if (!videoPostAccept) return false
      if (videoPostInline) task() else mainJobs.addLast(task)
      return true
    }
    override fun postDeadline(delayMs: Long, task: () -> Unit): Boolean {
      if (videoDeadlinePostThrows) throw IllegalStateException("deadline post failed")
      if (!videoDeadlinePostAccept) return false
      timers.add(now + delayMs to task)
      return true
    }
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

  private class Harness(withOutput: Boolean = true, withVideo: Boolean = false) {
    val work = Work()
    val recorder = Recorder()
    val output = OutputPort()
    val videoCloseCalls = mutableListOf<PracticeAudioArbiter.VideoPlayerClaim>()
    var videoCloseAccept = true
    var videoCloseThrows = false
    var onVideoClose: (() -> Unit)? = null
    val arbiter = PracticeAudioArbiter(work,
      if (withOutput) object : PracticeAudioArbiter.OutputFactory {
        override fun create(assetId: String) = output
      } else null,
      if (withOutput) setOf("approved_fixture") else emptySet(),
      videoReservationEnabled = withVideo,
      videoCloseDispatcher = if (withVideo) work else null)
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

    fun finishVideo(owner: PracticeAudioArbiter.Binding, id: String,
                    permit: Map<String, Any?>, context: Long, confirmed: Boolean = true): Map<String, Any?> =
      arbiter.completeVideoDispose(owner, owner.ownerToken, owner.engineGeneration,
        context, id, permit["leaseGeneration"] as Long, confirmed)

    fun claimVideo(owner: PracticeAudioArbiter.Binding, id: String,
                   permit: Map<String, Any?>, context: Long, playerId: Long = 7L): Boolean =
      arbiter.withClaimedVideoCreation(owner, owner.ownerToken, owner.engineGeneration,
        context, id, permit["leaseGeneration"] as Long, playerId,
        videoPort(owner, id, permit, context, playerId)) {}

    fun videoPort(owner: PracticeAudioArbiter.Binding, id: String,
                  permit: Map<String, Any?>, context: Long, playerId: Long):
      PracticeAudioArbiter.VideoClosePort {
      val claim = PracticeAudioArbiter.VideoPlayerClaim(owner, owner.ownerToken,
        owner.engineGeneration, context, id, permit["leaseGeneration"] as Long, playerId)
      return PracticeAudioArbiter.VideoClosePort(claim) {
        assertFalse("native close ran under arbiter gate", Thread.holdsLock(arbiter.gate))
        videoCloseCalls += claim
        onVideoClose?.invoke()
        if (videoCloseThrows) throw IllegalStateException("close failed")
        videoCloseAccept
      }
    }

    fun cancelVideo(owner: PracticeAudioArbiter.Binding, id: String,
                    permit: Map<String, Any?>, context: Long): Map<String, Any?> =
      arbiter.cancelVideoReservation(owner, owner.ownerToken, owner.engineGeneration,
        context, id, permit["leaseGeneration"] as Long)

    fun cancelUnknownVideo(owner: PracticeAudioArbiter.Binding,
                           attempt: PracticeAudioArbiter.Binding,
                           context: Long, id: String, heldGeneration: Long?,
                           expectedRevision: Long): Map<String, Any?> =
      arbiter.cancelUnclaimedVideoReservation(owner, owner.ownerToken,
        owner.engineGeneration, attempt.ownerToken, attempt.engineGeneration,
        context, id, heldGeneration, expectedRevision)

    fun releaseVideo(owner: PracticeAudioArbiter.Binding, id: String,
                     permit: Map<String, Any?>, context: Long, playerId: Long): Boolean =
      arbiter.releaseVideoPlayer(owner, owner.ownerToken, owner.engineGeneration,
        context, id, permit["leaseGeneration"] as Long, playerId)

    fun legacyClaim(owner: PracticeAudioArbiter.Binding) = PracticeAudioArbiter.CaptureClaim(
      owner.ownerToken, owner.engineGeneration, state(owner)["contextGeneration"] as Long)

    fun startCapture(owner: PracticeAudioArbiter.Binding, id: String,
                     claim: PracticeAudioArbiter.CaptureClaim? = legacyClaim(owner)): CaptureReply {
      capture.bind(owner.activityOwner, id)
      return CaptureReply().also {
        capture.start(owner.activityOwner, id, 44100, CaptureOutput(), it, claim)
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

  @Test fun videoIsDisabledByDefaultAndReservedVideoExcludesCaptureUntilDisposeAck() {
    val disabled = Harness(); val ordinary = disabled.bind()
    expectCode("video_unavailable") { disabled.reserve(ordinary, a, "video") }
    assertEquals(true, disabled.state(ordinary)["allClear"])

    val h = Harness(withVideo = true); val owner = h.bind()
    val context = h.state(owner)["contextGeneration"] as Long
    val permit = h.reserve(owner, a, "video")
    assertTrue(h.claimVideo(owner, a, permit, context))
    assertFalse(h.claimVideo(owner, a, permit, context))
    assertFalse(h.releaseVideo(owner, a, permit, context, 8L))
    assertEquals("video", h.state(owner)["activeSide"])
    assertEquals("reserved", h.state(owner)["videoPhase"])
    assertEquals(false, h.state(owner)["videoReleased"])
    assertEquals(listOf("capture_close_unconfirmed"), h.startCapture(owner, b).calls)
    expectCode("audio_busy") { h.reserve(owner, c, "input") }
    assertEquals("pending", h.close(owner, a, permit)["status"])
    assertEquals("closing", h.state(owner)["videoPhase"])
    assertTrue(h.releaseVideo(owner, a, permit, context, 7L))
    assertEquals("closed", h.finishVideo(owner, a, permit, context)["status"])
    assertEquals(true, h.state(owner)["allClear"])
    val input = h.reserve(owner, b, "input")
    assertEquals("stale", h.finishVideo(owner, a, permit, context)["status"])
    assertEquals("input", h.state(owner)["activeSide"])
    assertEquals("closed", h.close(owner, b, input)["status"])
  }

  @Test fun videoCreationNeedsAnExactClosePortBeforeItsFirstEffect() {
    val h = Harness(withVideo = true); val owner = h.bind()
    val context = h.state(owner)["contextGeneration"] as Long
    val permit = h.reserve(owner, a, "video")
    var effects = 0
    assertFalse(h.arbiter.claimVideoPlayer(owner, owner.ownerToken,
      owner.engineGeneration, context, a, permit["leaseGeneration"] as Long, 7L))
    assertFalse(h.arbiter.withClaimedVideoCreation(owner, owner.ownerToken,
      owner.engineGeneration, context, a, permit["leaseGeneration"] as Long, 7L) {
      effects++
    })
    assertFalse(h.arbiter.withClaimedVideoCreation(owner, owner.ownerToken,
      owner.engineGeneration, context, a, permit["leaseGeneration"] as Long, 7L,
      h.videoPort(owner, a, permit, context, 8L)) { effects++ })
    assertEquals(0, effects)
    assertTrue(h.arbiter.withClaimedVideoCreation(owner, owner.ownerToken,
      owner.engineGeneration, context, a, permit["leaseGeneration"] as Long, 7L,
      h.videoPort(owner, a, permit, context, 7L)) { effects++ })
    assertEquals(1, effects)
  }

  @Test fun currentVideoClaimRequiresCapturedPortIdentityAndExactTupleWithoutMutation() {
    val h = Harness(withVideo = true); val owner = h.bind()
    val context = h.state(owner)["contextGeneration"] as Long
    val permit = h.reserve(owner, a, "video")
    val port = h.videoPort(owner, a, permit, context, 7L)
    val claim = port.claim
    val beforeClaim = h.state(owner)["stateRevision"]
    assertFalse(h.arbiter.isCurrentVideoClaim(claim))
    assertEquals(beforeClaim, h.state(owner)["stateRevision"])
    assertTrue(h.arbiter.withClaimedVideoCreation(owner, owner.ownerToken,
      owner.engineGeneration, context, a, permit["leaseGeneration"] as Long, 7L,
      port) {
      val revision = h.state(owner)["stateRevision"]
      assertTrue(h.arbiter.isCurrentVideoClaim(claim))
      assertEquals(revision, h.state(owner)["stateRevision"])
    })
    val revision = h.state(owner)["stateRevision"]
    assertTrue(h.arbiter.isCurrentVideoClaim(claim))
    assertFalse(h.arbiter.isCurrentVideoClaim(claim.copy()))
    assertFalse(h.arbiter.isCurrentVideoClaim(
      h.videoPort(owner, a, permit, context, 7L).claim))
    val lookalike = PracticeAudioArbiter.Binding(
      owner.activityOwner, owner.engine, owner.ownerToken, owner.engineGeneration)
    assertFalse(h.arbiter.isCurrentVideoClaim(claim.copy(owner = lookalike)))
    assertFalse(h.arbiter.isCurrentVideoClaim(claim.copy(ownerToken = b)))
    assertFalse(h.arbiter.isCurrentVideoClaim(claim.copy(engineGeneration = owner.engineGeneration + 1)))
    assertFalse(h.arbiter.isCurrentVideoClaim(claim.copy(contextGeneration = context + 1)))
    assertFalse(h.arbiter.isCurrentVideoClaim(claim.copy(leaseId = b)))
    assertFalse(h.arbiter.isCurrentVideoClaim(claim.copy(leaseGeneration = claim.leaseGeneration + 1)))
    assertFalse(h.arbiter.isCurrentVideoClaim(claim.copy(playerId = 8L)))
    assertEquals(revision, h.state(owner)["stateRevision"])
  }

  @Test fun currentVideoClaimIsRevokedBeforeCloseCallbackAndAfterNativeRelease() {
    val h = Harness(withVideo = true); val owner = h.bind()
    val context = h.state(owner)["contextGeneration"] as Long
    val permit = h.reserve(owner, a, "video")
    val port = h.videoPort(owner, a, permit, context, 7L)
    assertTrue(h.arbiter.withClaimedVideoCreation(owner, owner.ownerToken,
      owner.engineGeneration, context, a, permit["leaseGeneration"] as Long, 7L,
      port) {})
    assertTrue(h.arbiter.isCurrentVideoClaim(port.claim))
    h.arbiter.fenceContext(owner, owner.ownerToken, owner.engineGeneration,
      context, "routeChange")
    val fencedRevision = h.state(owner)["stateRevision"]
    assertFalse(h.arbiter.isCurrentVideoClaim(port.claim))
    assertEquals(fencedRevision, h.state(owner)["stateRevision"])
    h.work.mainAll()
    assertTrue(h.releaseVideo(owner, a, permit, context, 7L))
    val releasedRevision = h.state(owner)["stateRevision"]
    assertFalse(h.arbiter.isCurrentVideoClaim(port.claim))
    assertEquals(releasedRevision, h.state(owner)["stateRevision"])
    assertFalse(h.state(owner)["allClear"] as Boolean) // Dart ACK remains separate.
  }

  @Test fun reusedPlayerAndLeaseIdDoNotReviveOldContextOrEngineClaim() {
    val h = Harness(withVideo = true); val owner = h.bind()
    val context = h.state(owner)["contextGeneration"] as Long
    val firstPermit = h.reserve(owner, a, "video")
    val firstPort = h.videoPort(owner, a, firstPermit, context, 7L)
    assertTrue(h.arbiter.withClaimedVideoCreation(owner, owner.ownerToken,
      owner.engineGeneration, context, a, firstPermit["leaseGeneration"] as Long,
      7L, firstPort) {})
    h.onVideoClose = { assertTrue(h.releaseVideo(owner, a, firstPermit, context, 7L)) }
    h.arbiter.fenceContext(owner, owner.ownerToken, owner.engineGeneration,
      context, "accountChange")
    h.work.mainAll()
    assertEquals("closed", h.finishVideo(owner, a, firstPermit, context)["status"])

    val newContext = h.state(owner)["contextGeneration"] as Long
    val secondPermit = h.reserve(owner, a, "video")
    val secondPort = h.videoPort(owner, a, secondPermit, newContext, 7L)
    assertTrue(h.arbiter.withClaimedVideoCreation(owner, owner.ownerToken,
      owner.engineGeneration, newContext, a, secondPermit["leaseGeneration"] as Long,
      7L, secondPort) {})
    assertFalse(h.arbiter.isCurrentVideoClaim(firstPort.claim))
    assertTrue(h.arbiter.isCurrentVideoClaim(secondPort.claim))
    assertEquals(a, firstPort.claim.leaseId)
    assertEquals(firstPort.claim.playerId, secondPort.claim.playerId)

    h.onVideoClose = { assertTrue(h.releaseVideo(owner, a, secondPermit, newContext, 7L)) }
    h.close(owner, a, secondPermit)
    h.work.mainAll()
    assertEquals("closed", h.finishVideo(owner, a, secondPermit, newContext)["status"])
    val newOwner = h.bind(owner.activityOwner, Any())
    val thirdContext = h.state(newOwner)["contextGeneration"] as Long
    val thirdPermit = h.reserve(newOwner, a, "video")
    val thirdPort = h.videoPort(newOwner, a, thirdPermit, thirdContext, 7L)
    assertTrue(h.arbiter.withClaimedVideoCreation(newOwner, newOwner.ownerToken,
      newOwner.engineGeneration, thirdContext, a,
      thirdPermit["leaseGeneration"] as Long, 7L, thirdPort) {})
    assertFalse(h.arbiter.isCurrentVideoClaim(firstPort.claim))
    assertFalse(h.arbiter.isCurrentVideoClaim(secondPort.claim))
    assertTrue(h.arbiter.isCurrentVideoClaim(thirdPort.claim))
    assertEquals(a, thirdPort.claim.leaseId)
    assertEquals(7L, thirdPort.claim.playerId)
  }

  @Test fun eachContextFencePostsOnlyTheOldExactPlayerAndWaitsForBothAcks() {
    for (reason in listOf("accountChange", "routeChange", "background")) {
      val h = Harness(withVideo = true); val owner = h.bind()
      val context = h.state(owner)["contextGeneration"] as Long
      val permit = h.reserve(owner, a, "video")
      assertTrue(h.claimVideo(owner, a, permit, context, 17L))
      h.onVideoClose = {
        assertTrue(h.releaseVideo(owner, a, permit, context, 17L))
      }
      if (reason == "background") h.arbiter.foreground(owner, false)
      else h.arbiter.fenceContext(owner, owner.ownerToken,
        owner.engineGeneration, context, reason)
      assertEquals("closing", h.state(owner)["videoPhase"])
      assertTrue(h.videoCloseCalls.isEmpty())
      assertFalse(h.state(owner)["allClear"] as Boolean)
      val staleCallback = requireNotNull(h.work.mainJobs.peekFirst())
      h.work.mainAll()
      assertEquals(listOf(17L), h.videoCloseCalls.map { it.playerId })
      assertFalse(h.state(owner)["allClear"] as Boolean)
      assertEquals("closed", h.finishVideo(owner, a, permit, context)["status"])
      assertTrue(h.state(owner)["allClear"] as Boolean)
      if (reason == "background") h.arbiter.foreground(owner, true)
      val nextContext = h.state(owner)["contextGeneration"] as Long
      val newer = h.reserve(owner, b, "video")
      assertTrue(h.claimVideo(owner, b, newer, nextContext, 17L))
      staleCallback.invoke()
      assertEquals(listOf(17L), h.videoCloseCalls.map { it.playerId })
      assertEquals("video", h.state(owner)["activeSide"])
      assertEquals(newer["leaseGeneration"], h.state(owner)["activeLeaseGeneration"])
    }
  }

  @Test fun claimedVideoCreationSerializesFirstEffectWithContextFence() {
    val h = Harness(withVideo = true); val owner = h.bind()
    val context = h.state(owner)["contextGeneration"] as Long
    val permit = h.reserve(owner, a, "video")
    val firstEffectEntered = CountDownLatch(1)
    val allowFirstEffectToReturn = CountDownLatch(1)
    val fenceEntered = CountDownLatch(1)
    val fenceReturned = CountDownLatch(1)
    val claimed = AtomicBoolean(false)
    val failure = AtomicReference<Throwable?>(null)
    val creator = Thread {
      try {
        claimed.set(h.arbiter.withClaimedVideoCreation(owner, owner.ownerToken,
          owner.engineGeneration, context, a, permit["leaseGeneration"] as Long, 77L,
          h.videoPort(owner, a, permit, context, 77L)) {
          firstEffectEntered.countDown()
          check(allowFirstEffectToReturn.await(5, TimeUnit.SECONDS))
        })
      } catch (error: Throwable) { failure.set(error) }
    }
    val fencer = Thread {
      try {
        fenceEntered.countDown()
        h.arbiter.fenceContext(owner, owner.ownerToken, owner.engineGeneration,
          context, "routeChange")
      } catch (error: Throwable) { failure.set(error) } finally { fenceReturned.countDown() }
    }
    creator.start()
    assertTrue(firstEffectEntered.await(2, TimeUnit.SECONDS))
    fencer.start()
    assertTrue(fenceEntered.await(2, TimeUnit.SECONDS))
    try {
      // BLOCKED proves the fencer reached the arbiter monitor while the
      // creator's synchronous first side effect still holds it.
      val deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(2)
      while (fencer.state != Thread.State.BLOCKED && System.nanoTime() < deadline) {
        Thread.sleep(1)
      }
      assertEquals(Thread.State.BLOCKED, fencer.state)
      assertEquals(1L, fenceReturned.count)
    } finally {
      allowFirstEffectToReturn.countDown()
      creator.join(2_000); fencer.join(2_000)
    }
    assertFalse(creator.isAlive); assertFalse(fencer.isAlive)
    assertNull(failure.get())
    assertTrue(claimed.get())
    assertFalse(h.arbiter.withClaimedVideoCreation(owner, owner.ownerToken,
      owner.engineGeneration, context, a, permit["leaseGeneration"] as Long, 78L,
      h.videoPort(owner, a, permit, context, 78L)) {
      fail("stale context must not create")
    })
    assertTrue(h.releaseVideo(owner, a, permit, context, 77L))
  }

  @Test fun failedOrStaleClaimedCreationDoesNotRunAndThrowingEffectKeepsExactLease() {
    val h = Harness(withVideo = true); val owner = h.bind()
    val context = h.state(owner)["contextGeneration"] as Long
    val permit = h.reserve(owner, a, "video")
    var effects = 0
    assertFalse(h.arbiter.withClaimedVideoCreation(owner, owner.ownerToken,
      owner.engineGeneration, context + 1, a, permit["leaseGeneration"] as Long, 79L,
      h.videoPort(owner, a, permit, context + 1, 79L)) {
      effects++
    })
    assertFalse(h.arbiter.withClaimedVideoCreation(owner, b,
      owner.engineGeneration, context, a, permit["leaseGeneration"] as Long, 79L,
      h.videoPort(owner, a, permit, context, 79L)) {
      effects++
    })
    assertEquals(0, effects)
    try {
      h.arbiter.withClaimedVideoCreation(owner, owner.ownerToken,
        owner.engineGeneration, context, a, permit["leaseGeneration"] as Long, 79L,
        h.videoPort(owner, a, permit, context, 79L)) {
        effects++
        throw IllegalStateException("partial create")
      }
      fail("Expected partial create error")
    } catch (error: IllegalStateException) {
      assertEquals("partial create", error.message)
    }
    assertEquals(1, effects)
    assertFalse(h.state(owner)["allClear"] as Boolean)
    assertFalse(h.releaseVideo(owner, a, permit, context, 80L))
    assertTrue(h.releaseVideo(owner, a, permit, context, 79L))
    assertEquals("closed", h.finishVideo(owner, a, permit, context)["status"])
  }

  @Test fun reentrantFenceDuringVideoCreationRevokesResultWithoutClearingClaim() {
    val h = Harness(withVideo = true); val owner = h.bind()
    val context = h.state(owner)["contextGeneration"] as Long
    val permit = h.reserve(owner, a, "video")
    val result = h.arbiter.withClaimedVideoCreation(owner, owner.ownerToken,
      owner.engineGeneration, context, a, permit["leaseGeneration"] as Long, 91L,
      h.videoPort(owner, a, permit, context, 91L)) {
      h.arbiter.fenceContext(owner, owner.ownerToken,
        owner.engineGeneration, context, "routeChange")
      assertTrue(h.videoCloseCalls.isEmpty())
    }
    assertFalse(result)
    assertEquals(1, h.work.mainJobs.size)
    h.work.mainAll()
    assertEquals(listOf(91L), h.videoCloseCalls.map { it.playerId })
    assertEquals("video", h.state(owner)["activeSide"])
    expectCode("audio_busy") { h.reserve(owner, b, "input") }
    assertFalse(h.releaseVideo(owner, a, permit, context, 92L))
    assertTrue(h.releaseVideo(owner, a, permit, context, 91L))
  }

  @Test fun reentrantExactReleaseDuringVideoCreationCannotReportSuccessBeforeDartAck() {
    val h = Harness(withVideo = true); val owner = h.bind()
    val context = h.state(owner)["contextGeneration"] as Long
    val permit = h.reserve(owner, a, "video")
    var released = false
    val created = h.arbiter.withClaimedVideoCreation(owner, owner.ownerToken,
      owner.engineGeneration, context, a, permit["leaseGeneration"] as Long, 93L,
      h.videoPort(owner, a, permit, context, 93L)) {
      released = h.releaseVideo(owner, a, permit, context, 93L)
    }
    assertTrue(released)
    assertFalse(created)
    assertEquals("video", h.state(owner)["activeSide"])
    assertFalse(h.state(owner)["allClear"] as Boolean)
    assertFalse(h.releaseVideo(owner, a, permit, context, 93L))
    assertEquals("closed", h.finishVideo(owner, a, permit, context)["status"])
    assertEquals(true, h.state(owner)["allClear"])
  }

  @Test fun contextFenceWaitsForVideoDisposeAndRejectsExpiredAcknowledgement() {
    val h = Harness(withVideo = true); val owner = h.bind()
    val context = h.state(owner)["contextGeneration"] as Long
    val permit = h.reserve(owner, a, "video")
    assertTrue(h.claimVideo(owner, a, permit, context))
    assertEquals("pending", h.arbiter.fenceContext(owner, owner.ownerToken,
      owner.engineGeneration, context, "accountChange")["status"])
    expectCode("audio_busy") { h.reserve(owner, b, "input") }
    assertTrue(h.releaseVideo(owner, a, permit, context, 7L))
    assertEquals("closed", h.finishVideo(owner, a, permit, context)["status"])
    assertEquals("reserved", h.reserve(owner, b, "input")["status"])

    val h2 = Harness(withVideo = true); val second = h2.bind()
    val secondContext = h2.state(second)["contextGeneration"] as Long
    val secondPermit = h2.reserve(second, a, "video")
    assertTrue(h2.claimVideo(second, a, secondPermit, secondContext))
    h2.close(second, a, secondPermit)
    h2.work.advance(2_000)
    assertEquals("unconfirmedQuiescent", h2.state(second)["videoPhase"])
    assertEquals(true, h2.state(second)["requiresExplicitRetry"])
    assertEquals("blocked", h2.finishVideo(second, a, secondPermit, secondContext)["status"])
    val blocked = h2.state(second)
    assertEquals("pending", h2.arbiter.recoverAll(second, second.ownerToken,
      second.engineGeneration, blocked["stateRevision"] as Long, "userRetry")["status"])
    h2.work.mainAll()
    expectCode("audio_busy") { h2.reserve(second, b, "input") }
  }

  @Test fun bareDartDisposeCannotReleaseVideoAndPrecreateCancelIsExact() {
    val h = Harness(withVideo = true); val owner = h.bind()
    val context = h.state(owner)["contextGeneration"] as Long
    val permit = h.reserve(owner, a, "video")
    assertFalse(h.claimVideo(owner, a, permit, context + 1))
    assertEquals("stale", h.cancelVideo(owner, b, permit, context)["status"])
    assertEquals("pending", h.arbiter.fenceContext(owner, owner.ownerToken,
      owner.engineGeneration, context, "routeChange")["status"])
    assertEquals("closed", h.cancelVideo(owner, a, permit, context)["status"])

    val nextContext = h.state(owner)["contextGeneration"] as Long
    val second = h.reserve(owner, b, "video")
    assertTrue(h.claimVideo(owner, b, second, nextContext))
    assertEquals("blocked", h.cancelVideo(owner, b, second, nextContext)["status"])
    assertEquals("pending", h.finishVideo(owner, b, second, nextContext)["status"])
    assertFalse(h.state(owner)["allClear"] as Boolean)

    val h2 = Harness(withVideo = true); val secondOwner = h2.bind()
    val secondContext = h2.state(secondOwner)["contextGeneration"] as Long
    val third = h2.reserve(secondOwner, a, "video")
    assertTrue(h2.claimVideo(secondOwner, a, third, secondContext))
    assertTrue(h2.releaseVideo(secondOwner, a, third, secondContext, 7L))
    assertEquals("closed", h2.finishVideo(secondOwner, a, third, secondContext)["status"])
    val reused = h2.reserve(secondOwner, b, "video")
    assertTrue(h2.claimVideo(secondOwner, b, reused, secondContext))
    assertFalse(h2.releaseVideo(secondOwner, a, third, secondContext, 7L))
    assertEquals("pending", h2.finishVideo(secondOwner, b, reused, secondContext)["status"])
    assertFalse(h2.state(secondOwner)["allClear"] as Boolean)
  }

  @Test fun engineReplacementCancelsOnlyAnUnclaimedVideoReserve() {
    val h = Harness(withVideo = true); val old = h.bind()
    val context = h.state(old)["contextGeneration"] as Long
    val permit = h.reserve(old, a, "video")
    val current = h.bind()
    assertEquals(true, h.state(current)["allClear"])
    expectCode("stale_audio_owner") { h.cancelVideo(old, a, permit, context) }
    assertFalse(h.releaseVideo(old, a, permit, context, 7L))
    assertEquals("reserved", h.reserve(current, b, "input")["status"])
  }

  @Test fun retiredEngineVideoNeedsExactNativeReleaseThenCurrentOwnerRecovery() {
    val h = Harness(withVideo = true); val old = h.bind()
    val context = h.state(old)["contextGeneration"] as Long
    val permit = h.reserve(old, a, "video")
    assertTrue(h.claimVideo(old, a, permit, context))
    val current = h.bind()
    assertTrue(h.videoCloseCalls.isEmpty())
    h.work.mainAll()
    assertEquals(listOf(old), h.videoCloseCalls.map { it.owner })
    assertEquals("blocked", h.arbiter.recoverAll(current, current.ownerToken,
      current.engineGeneration, h.state(current)["stateRevision"] as Long, "userRetry")["status"])
    assertFalse(h.releaseVideo(old, b, permit, context, 7L))
    assertTrue(h.releaseVideo(old, a, permit, context, 7L))
    expectCode("stale_audio_owner") { h.finishVideo(old, a, permit, context) }
    assertEquals("stale", h.finishVideo(current, a, permit, context)["status"])
    assertEquals("blocked", h.arbiter.recoverAll(current, current.ownerToken,
      current.engineGeneration, h.state(current)["stateRevision"] as Long, "userRetry")["status"])
    assertFalse(h.state(current)["allClear"] as Boolean)
    expectCode("audio_busy") { h.reserve(current, b, "video") }
    assertFalse(h.releaseVideo(old, a, permit, context, 7L))
  }

  @Test fun rejectedPostRetriesOnlyAfterExplicitUserAction() {
    val h = Harness(withVideo = true); val owner = h.bind()
    val context = h.state(owner)["contextGeneration"] as Long
    val permit = h.reserve(owner, a, "video")
    assertTrue(h.claimVideo(owner, a, permit, context))
    h.work.videoPostAccept = false
    h.arbiter.fenceContext(owner, owner.ownerToken,
      owner.engineGeneration, context, "routeChange")
    assertEquals("unconfirmedQuiescent", h.state(owner)["videoPhase"])
    assertEquals(true, h.state(owner)["requiresExplicitRetry"])
    assertTrue(h.videoCloseCalls.isEmpty())
    assertFalse(h.state(owner)["allClear"] as Boolean)
    h.work.videoPostAccept = true
    h.onVideoClose = { assertTrue(h.releaseVideo(owner, a, permit, context, 7L)) }
    assertEquals("pending", h.arbiter.recoverAll(owner, owner.ownerToken,
      owner.engineGeneration, h.state(owner)["stateRevision"] as Long,
      "userRetry")["status"])
    h.work.mainAll()
    assertEquals(1, h.videoCloseCalls.size)
    assertFalse(h.state(owner)["allClear"] as Boolean)
    assertEquals("closed", h.finishVideo(owner, a, permit, context)["status"])
    assertTrue(h.state(owner)["allClear"] as Boolean)
  }

  @Test fun throwingPortAndInlinePostQuarantineWithoutInventingRelease() {
    val h = Harness(withVideo = true); val owner = h.bind()
    val context = h.state(owner)["contextGeneration"] as Long
    val permit = h.reserve(owner, a, "video")
    assertTrue(h.claimVideo(owner, a, permit, context))
    h.videoCloseThrows = true
    h.arbiter.fenceContext(owner, owner.ownerToken,
      owner.engineGeneration, context, "accountChange")
    h.work.mainAll()
    assertEquals("unconfirmedQuiescent", h.state(owner)["videoPhase"])
    assertEquals(false, h.arbiter.wasVideoPlayerReleased(
      h.videoPort(owner, a, permit, context, 7L).claim))
    assertFalse(h.state(owner)["allClear"] as Boolean)
    h.videoCloseThrows = false
    h.onVideoClose = { assertTrue(h.releaseVideo(owner, a, permit, context, 7L)) }
    assertEquals("pending", h.arbiter.recoverAll(owner, owner.ownerToken,
      owner.engineGeneration, h.state(owner)["stateRevision"] as Long,
      "userRetry")["status"])
    h.work.mainAll()
    assertEquals(2, h.videoCloseCalls.size)
    assertFalse(h.state(owner)["allClear"] as Boolean)
    assertEquals("closed", h.finishVideo(owner, a, permit, context)["status"])

    val inline = Harness(withVideo = true); val second = inline.bind()
    val secondContext = inline.state(second)["contextGeneration"] as Long
    val secondPermit = inline.reserve(second, b, "video")
    assertTrue(inline.claimVideo(second, b, secondPermit, secondContext))
    inline.work.videoPostInline = true
    inline.arbiter.foreground(second, false)
    assertTrue(inline.videoCloseCalls.isEmpty())
    assertEquals("unconfirmedQuiescent", inline.state(second)["videoPhase"])
    assertFalse(inline.state(second)["allClear"] as Boolean)
  }

  @Test fun failedCloseReturnAfterBothExactAcksStillNeedsExplicitRetry() {
    val h = Harness(withVideo = true); val owner = h.bind()
    val context = h.state(owner)["contextGeneration"] as Long
    val permit = h.reserve(owner, a, "video")
    assertTrue(h.claimVideo(owner, a, permit, context, 43L))
    val exact = h.videoPort(owner, a, permit, context, 43L).claim
    h.videoCloseAccept = false
    h.onVideoClose = {
      assertTrue(h.releaseVideo(owner, a, permit, context, 43L))
      assertEquals("pending", h.finishVideo(owner, a, permit, context)["status"])
      assertFalse(h.state(owner)["allClear"] as Boolean)
    }
    h.arbiter.fenceContext(owner, owner.ownerToken,
      owner.engineGeneration, context, "routeChange")
    h.work.mainAll()
    assertTrue(h.arbiter.wasVideoPlayerReleased(exact))
    assertFalse(h.arbiter.wasVideoPlayerReleased(exact.copy(playerId = 44L)))
    assertEquals(true, h.state(owner)["requiresExplicitRetry"])
    assertFalse(h.state(owner)["allClear"] as Boolean)
    assertEquals("closed", h.arbiter.recoverAll(owner, owner.ownerToken,
      owner.engineGeneration, h.state(owner)["stateRevision"] as Long,
      "userRetry")["status"])
    assertTrue(h.state(owner)["allClear"] as Boolean)
  }

  @Test fun throwingMainPostNeverCallsPortOrClaimsRelease() {
    val h = Harness(withVideo = true); val owner = h.bind()
    val context = h.state(owner)["contextGeneration"] as Long
    val permit = h.reserve(owner, a, "video")
    assertTrue(h.claimVideo(owner, a, permit, context))
    h.work.videoPostThrows = true
    h.arbiter.foreground(owner, false)
    assertTrue(h.videoCloseCalls.isEmpty())
    assertEquals("unconfirmedQuiescent", h.state(owner)["videoPhase"])
    assertEquals(true, h.state(owner)["requiresExplicitRetry"])
    assertFalse(h.state(owner)["allClear"] as Boolean)
  }

  @Test fun rejectedVideoDeadlinePostQuarantinesWithoutInventingRelease() {
    for (throws in listOf(false, true)) {
      val h = Harness(withVideo = true); val owner = h.bind()
      val context = h.state(owner)["contextGeneration"] as Long
      val permit = h.reserve(owner, a, "video")
      assertTrue(h.claimVideo(owner, a, permit, context))
      h.work.videoDeadlinePostAccept = false
      h.work.videoDeadlinePostThrows = throws
      h.arbiter.fenceContext(owner, owner.ownerToken,
        owner.engineGeneration, context, "routeChange")
      assertEquals("unconfirmedQuiescent", h.state(owner)["videoPhase"])
      assertEquals(true, h.state(owner)["requiresExplicitRetry"])
      assertFalse(h.state(owner)["allClear"] as Boolean)
      h.work.mainAll()
      assertEquals(1, h.videoCloseCalls.size)
      assertFalse(h.state(owner)["allClear"] as Boolean)
      assertFalse(h.releaseVideo(owner, a, permit, context, 8L))
    }
  }

  @Test fun videoDeadlineCanMarkUncertaintyWhileMainClosePortIsBlocked() {
    val h = Harness(withVideo = true); val owner = h.bind()
    val context = h.state(owner)["contextGeneration"] as Long
    val permit = h.reserve(owner, a, "video")
    assertTrue(h.claimVideo(owner, a, permit, context))
    val closeEntered = CountDownLatch(1)
    val allowCloseReturn = CountDownLatch(1)
    val failure = AtomicReference<Throwable?>(null)
    h.onVideoClose = {
      closeEntered.countDown()
      check(allowCloseReturn.await(5, TimeUnit.SECONDS))
      assertTrue(h.releaseVideo(owner, a, permit, context, 7L))
    }
    h.arbiter.fenceContext(owner, owner.ownerToken,
      owner.engineGeneration, context, "accountChange")
    val mainThread = Thread {
      try { h.work.mainAll() } catch (error: Throwable) { failure.set(error) }
    }
    mainThread.start()
    assertTrue(closeEntered.await(2, TimeUnit.SECONDS))
    try {
      h.work.advance(2_000)
      assertEquals("unconfirmedQuiescent", h.state(owner)["videoPhase"])
      assertEquals(true, h.state(owner)["requiresExplicitRetry"])
      assertFalse(h.state(owner)["allClear"] as Boolean)
    } finally {
      allowCloseReturn.countDown()
      mainThread.join(2_000)
    }
    assertFalse(mainThread.isAlive)
    assertNull(failure.get())
    assertEquals("blocked", h.finishVideo(owner, a, permit, context)["status"])
    assertEquals("closed", h.arbiter.recoverAll(owner, owner.ownerToken,
      owner.engineGeneration, h.state(owner)["stateRevision"] as Long,
      "userRetry")["status"])
  }

  @Test fun earlyDartAckWaitsForNativeReleaseAndTimedOutAckRequiresRetry() {
    val h = Harness(withVideo = true); val owner = h.bind()
    val context = h.state(owner)["contextGeneration"] as Long
    val permit = h.reserve(owner, a, "video")
    assertTrue(h.claimVideo(owner, a, permit, context))
    assertEquals("pending", h.finishVideo(owner, a, permit, context)["status"])
    assertEquals(false, h.state(owner)["requiresExplicitRetry"])
    assertTrue(h.releaseVideo(owner, a, permit, context, 7L))
    assertEquals(true, h.state(owner)["allClear"])

    val second = h.reserve(owner, b, "video")
    assertTrue(h.claimVideo(owner, b, second, context))
    assertEquals("pending", h.finishVideo(owner, b, second, context)["status"])
    h.work.advance(2_000)
    assertEquals("unconfirmedQuiescent", h.state(owner)["videoPhase"])
    assertTrue(h.releaseVideo(owner, b, second, context, 7L))
    assertEquals(false, h.state(owner)["allClear"])
    assertEquals("closed", h.arbiter.recoverAll(owner, owner.ownerToken,
      owner.engineGeneration, h.state(owner)["stateRevision"] as Long, "userRetry")["status"])
  }

  @Test fun lostReserveCancellationTombstonesLateCallAndRejectsStaleCas() {
    val h = Harness(withVideo = true); val owner = h.bind()
    val before = h.state(owner)
    val context = before["contextGeneration"] as Long
    val revision = before["stateRevision"] as Long
    assertEquals("stale", h.cancelUnknownVideo(owner, owner, context, a,
      null, revision - 1)["status"])
    val cancelled = h.cancelUnknownVideo(owner, owner, context, a, null, revision)
    assertEquals("closed", cancelled["status"])
    expectCode("stale_audio_lease") { h.reserve(owner, a, "video") }
    assertEquals("reserved", h.reserve(owner, b, "video")["status"])
  }

  @Test fun unclaimedTimeoutAndFailedDisposeCanCancelButClaimedPlayerCannot() {
    val h = Harness(withVideo = true); val owner = h.bind()
    val context = h.state(owner)["contextGeneration"] as Long
    val first = h.reserve(owner, a, "video")
    h.arbiter.fenceContext(owner, owner.ownerToken, owner.engineGeneration,
      context, "routeChange")
    h.work.advance(2_000)
    assertEquals("unconfirmedQuiescent", h.state(owner)["videoPhase"])
    assertEquals("closed", h.cancelVideo(owner, a, first, context)["status"])

    val nextContext = h.state(owner)["contextGeneration"] as Long
    val second = h.reserve(owner, b, "video")
    assertEquals("blocked", h.finishVideo(owner, b, second, nextContext,
      confirmed = false)["status"])
    val held = h.state(owner)
    assertEquals("closed", h.cancelUnknownVideo(owner, owner, nextContext,
      b, second["leaseGeneration"] as Long,
      held["stateRevision"] as Long)["status"])

    val third = h.reserve(owner, c, "video")
    assertTrue(h.claimVideo(owner, c, third, nextContext))
    val claimed = h.state(owner)
    val denied = h.cancelUnknownVideo(owner, owner, nextContext, c,
      third["leaseGeneration"] as Long, claimed["stateRevision"] as Long)
    assertEquals("blocked", denied["status"])
    assertEquals(claimed["stateRevision"], h.state(owner)["stateRevision"])
    assertEquals("blocked", h.cancelVideo(owner, c, third, nextContext)["status"])
    assertEquals("video", h.state(owner)["activeSide"])
  }

  @Test fun unknownAttemptCannotClearNewLeaseOrRetiredOwner() {
    val h = Harness(withVideo = true); val old = h.bind()
    val context = h.state(old)["contextGeneration"] as Long
    val first = h.reserve(old, a, "video")
    val held = h.state(old)
    assertEquals("closed", h.cancelUnknownVideo(old, old, context, a,
      first["leaseGeneration"] as Long,
      held["stateRevision"] as Long)["status"])
    val second = h.reserve(old, b, "video")
    val newState = h.state(old)
    assertEquals("stale", h.cancelUnknownVideo(old, old, context, a,
      first["leaseGeneration"] as Long,
      newState["stateRevision"] as Long)["status"])
    assertEquals("video", h.state(old)["activeSide"])
    val current = h.bind()
    expectCode("stale_audio_owner") {
      h.cancelUnknownVideo(old, old, context, a,
        first["leaseGeneration"] as Long,
        newState["stateRevision"] as Long)
    }
    val after = h.state(current)
    assertEquals(true, after["allClear"])
    assertEquals("closed", h.cancelUnknownVideo(current, old, context, a,
      null, after["stateRevision"] as Long)["status"])
    assertEquals("reserved", h.reserve(current, c, "video")["status"])
    assertEquals("stale", h.cancelUnknownVideo(current, old, context, a,
      first["leaseGeneration"] as Long,
      h.state(current)["stateRevision"] as Long)["status"])
    assertEquals("video", h.state(current)["activeSide"])
    assertEquals(second["leaseGeneration"], newState["activeLeaseGeneration"])
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

  @Test fun legacyCaptureWireRequiresExactlyThreeContextFields() {
    val wire = mapOf<String, Any>("attemptId" to a, "sampleRate" to 44100,
      "ownerToken" to b, "engineGeneration" to 1L, "contextGeneration" to 2L)
    assertEquals(PracticeAudioArbiter.CaptureClaim(b, 1L, 2L), parseCaptureStartClaim(wire))
    assertNull(parseCaptureStartClaim(mapOf("attemptId" to a, "sampleRate" to 44100)))
    assertNull(parseCaptureStartClaim(wire - "contextGeneration"))
    assertNull(parseCaptureStartClaim(wire - "ownerToken"))
    assertNull(parseCaptureStartClaim(wire - "engineGeneration"))
    assertNull(parseCaptureStartClaim(wire + ("leaseId" to c)))
    assertNull(parseCaptureStartClaim(wire + ("unknown" to true)))
    assertEquals(PracticeAudioArbiter.CaptureClaim(b, 1L, 2L, c, 3L),
      parseCaptureStartClaim(wire + ("leaseId" to c) + ("leaseGeneration" to 3L)))
  }

  @Test fun legacyCaptureClaimFromBeforeFenceCannotStartAfterFence() {
    val h = Harness(withOutput = false); val owner = h.bind()
    val old = h.legacyClaim(owner)
    val fenced = h.arbiter.fenceContext(owner, owner.ownerToken,
      owner.engineGeneration, old.contextGeneration, "routeChange")
    assertEquals("closed", fenced["status"])
    assertEquals(listOf("capture_close_unconfirmed"), h.startCapture(owner, a, null).calls)
    assertEquals(listOf("capture_close_unconfirmed"), h.startCapture(owner, a, old).calls)
    val partial = h.legacyClaim(owner).copy(leaseId = b)
    assertEquals(listOf("capture_close_unconfirmed"), h.startCapture(owner, a, partial).calls)
    assertTrue(h.work.hardwareJobs.isEmpty())
    assertEquals(0, h.recorder.starts)

    val fresh = h.startCapture(owner, a)
    h.work.hardwareOne(); h.work.mainAll()
    assertEquals(listOf("ok"), fresh.calls)
    assertEquals(1, h.recorder.starts)
    h.capture.requestCloseGlobal(); h.work.drain()
    assertEquals(true, h.state(owner)["allClear"])
  }

  @Test fun legacyClaimFromReplacedEngineCannotStartInNewEngine() {
    val h = Harness(withOutput = false); val activity = Any()
    val oldOwner = h.bind(activity)
    val oldClaim = h.legacyClaim(oldOwner)
    val current = h.bind(activity, Any())
    assertEquals(listOf("capture_close_unconfirmed"),
      h.startCapture(current, a, oldClaim).calls)
    assertTrue(h.work.hardwareJobs.isEmpty())
    assertEquals(0, h.recorder.starts)
    val fresh = h.startCapture(current, a)
    h.work.hardwareOne(); h.work.mainAll()
    assertEquals(listOf("ok"), fresh.calls)
  }
}
