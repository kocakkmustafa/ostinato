package com.yulalab.ostinato

import java.util.ArrayDeque
import org.junit.Assert.*
import org.junit.Test

class AndroidVideoPermitBridgeCoreTest {
  private val leaseId = "a".repeat(32)

  private class QueueWork : PracticeAudioArbiter.Work,
    PracticeAudioArbiter.VideoCloseDispatcher {
    val mainJobs = ArrayDeque<() -> Unit>()
    val deadlines = mutableListOf<() -> Unit>()
    override fun hardware(task: () -> Unit) { fail("unexpected hardware job") }
    override fun main(task: () -> Unit) { mainJobs.addLast(task) }
    override fun after(delayMs: Long, task: () -> Unit) { deadlines += task }
    override fun postMain(task: () -> Unit): Boolean {
      mainJobs.addLast(task)
      return true
    }
    override fun postDeadline(delayMs: Long, task: () -> Unit): Boolean {
      deadlines += task
      return true
    }
    fun drainMain() { while (mainJobs.isNotEmpty()) mainJobs.removeFirst().invoke() }
  }

  private data class FakeClaim(
    val ownerToken: String,
    val engineGeneration: Long,
    val contextGeneration: Long,
    val leaseId: String,
    val leaseGeneration: Long,
    val playerId: Long,
  ) {
    fun fields() = AndroidVideoPermitBridgeCore.Fields(
      ownerToken, engineGeneration, contextGeneration, leaseId,
      leaseGeneration, playerId,
    )
  }

  private class FakeMessenger

  private class FakePlugin {
    val calls = mutableListOf<Pair<FakeMessenger, FakeClaim>>()
    var result = AndroidVideoPermitBridgeCore.ExactCloseResult.RELEASED_EXACT
    var onClose: ((FakeMessenger, FakeClaim) -> Unit)? = null
    fun close(messenger: FakeMessenger, claim: FakeClaim):
      AndroidVideoPermitBridgeCore.ExactCloseResult {
      calls += messenger to claim
      onClose?.invoke(messenger, claim)
      return result
    }
  }

  private class Harness {
    val work = QueueWork()
    val arbiter = PracticeAudioArbiter(work,
      videoReservationEnabled = true, videoCloseDispatcher = work)
    val binding = arbiter.registerEngine(Any(), Any()).also { arbiter.foreground(it, true) }
    val messenger = FakeMessenger()
    val plugin = FakePlugin()
    val core = newCore(plugin, messenger)

    fun newCore(plugin: FakePlugin, messenger: FakeMessenger) =
      AndroidVideoPermitBridgeCore<FakeClaim, FakePlugin, FakeMessenger>(
        arbiter, binding, plugin, messenger,
        fieldsOf = { it.fields() },
        closeExact = { exactPlugin, exactMessenger, exactClaim ->
          assertFalse("plugin close ran under arbiter gate", Thread.holdsLock(arbiter.gate))
          exactPlugin.close(exactMessenger, exactClaim)
        },
      )

    fun state(owner: PracticeAudioArbiter.Binding = binding): Map<String, Any?> =
      arbiter.readAllAudioState(owner, owner.ownerToken, owner.engineGeneration)

    fun reserve(id: String = "a".repeat(32), playerId: Long = 7L): FakeClaim {
      val context = state()["contextGeneration"] as Long
      val permit = arbiter.reserve(binding, binding.ownerToken,
        binding.engineGeneration, context, id, "video")
      return FakeClaim(binding.ownerToken, binding.engineGeneration, context,
        id, permit["leaseGeneration"] as Long, playerId)
    }

    fun ack(claim: FakeClaim): Map<String, Any?> = arbiter.completeVideoDispose(
      binding, claim.ownerToken, claim.engineGeneration, claim.contextGeneration,
      claim.leaseId, claim.leaseGeneration, true,
    )
  }

  @Test fun exactClaimIsCapturedBeforeFirstEffectAndReadOnlyChecksRejectCopies() {
    val h = Harness()
    val claim = h.reserve()
    var effects = 0
    assertFalse(h.core.isCurrentClaim(claim))
    assertFalse(h.core.withClaimedVideoCreation(
      claim.copy(ownerToken = "b".repeat(32)), Runnable { effects++ }))
    assertEquals(0, effects)
    assertTrue(h.core.withClaimedVideoCreation(claim, Runnable {
      effects++
      val revision = h.state()["stateRevision"]
      assertTrue(h.core.isCurrentClaim(claim))
      assertFalse(h.core.isCurrentClaim(claim.copy()))
      assertEquals(revision, h.state()["stateRevision"])
    }))
    assertEquals(1, effects)
    assertTrue(h.core.isCurrentClaim(claim))
    assertFalse(h.core.isCurrentClaim(claim.copy(contextGeneration = claim.contextGeneration + 1)))
    assertFalse(h.core.releaseVideoPlayer(claim.copy()))

    val foreignPlugin = FakePlugin()
    val foreignCore = h.newCore(foreignPlugin, FakeMessenger())
    assertFalse(foreignCore.isCurrentClaim(claim))
    assertFalse(foreignCore.releaseVideoPlayer(claim))
    assertFalse(foreignCore.withClaimedVideoCreation(claim, Runnable { fail("duplicate create") }))
    assertTrue(foreignPlugin.calls.isEmpty())
  }

  @Test fun exactCloseUsesOriginalObjectsOutsideLockAndNeedsSeparateDartAck() {
    val h = Harness()
    val claim = h.reserve()
    assertTrue(h.core.withClaimedVideoCreation(claim, Runnable {}))
    h.plugin.onClose = { messenger, closedClaim ->
      assertSame(h.messenger, messenger)
      assertSame(claim, closedClaim)
      assertTrue(h.core.releaseVideoPlayer(closedClaim))
    }
    h.arbiter.closeAllGlobal(h.binding)
    assertFalse(h.core.isCurrentClaim(claim))
    assertTrue(h.plugin.calls.isEmpty()) // Closing must be deferred beyond the fence monitor.
    h.work.drainMain()
    assertEquals(1, h.plugin.calls.size)
    assertSame(h.messenger, h.plugin.calls.single().first)
    assertSame(claim, h.plugin.calls.single().second)
    assertEquals(false, h.state()["allClear"])
    assertEquals("closed", h.ack(claim)["status"])
    assertEquals(true, h.state()["allClear"])
  }

  @Test fun pendingCreateAndUnconfirmedNeverBecomeExactClose() {
    for (result in listOf(
      AndroidVideoPermitBridgeCore.ExactCloseResult.PENDING_CREATE,
      AndroidVideoPermitBridgeCore.ExactCloseResult.UNCONFIRMED,
    )) {
      val h = Harness()
      val claim = h.reserve()
      h.plugin.result = result
      assertTrue(h.core.withClaimedVideoCreation(claim, Runnable {}))
      h.arbiter.closeAllGlobal(h.binding)
      h.work.drainMain()
      assertEquals(1, h.plugin.calls.size)
      assertEquals("unconfirmedQuiescent", h.state()["videoPhase"])
      assertEquals(false, h.state()["allClear"])
      assertEquals("blocked", h.ack(claim)["status"])
      assertEquals(false, h.state()["allClear"])
    }
  }

  @Test fun repeatedExactNativeReleaseUsesBoundedReadOnlyReceipt() {
    val h = Harness()
    val claim = h.reserve()
    assertTrue(h.core.withClaimedVideoCreation(claim, Runnable {}))
    assertTrue(h.core.releaseVideoPlayer(claim))
    val revision = h.state()["stateRevision"]
    assertTrue(h.core.releaseVideoPlayer(claim))
    assertEquals(revision, h.state()["stateRevision"])
    assertFalse(h.core.releaseVideoPlayer(claim.copy()))
    assertFalse(h.core.isCurrentClaim(claim))
    assertEquals(false, h.state()["allClear"])
  }

  @Test fun retiredEngineKeepsOldExactCloseButCannotReviveItsClaim() {
    val h = Harness()
    val claim = h.reserve()
    assertTrue(h.core.withClaimedVideoCreation(claim, Runnable {}))
    h.plugin.onClose = { _, closedClaim -> assertTrue(h.core.releaseVideoPlayer(closedClaim)) }
    val replacement = h.arbiter.registerEngine(Any(), Any())
    h.arbiter.foreground(replacement, true)
    assertFalse(h.core.isCurrentClaim(claim))
    assertFalse(h.core.isCurrentClaim(claim.copy()))
    h.work.drainMain()
    assertEquals(1, h.plugin.calls.size)
    assertSame(claim, h.plugin.calls.single().second)
    assertEquals(false, h.state(replacement)["allClear"]) // Old Dart ACK is still absent.
  }

  @Test fun productionDefaultVideoGateStillRejectsReservation() {
    val work = QueueWork()
    val arbiter = PracticeAudioArbiter(work, videoCloseDispatcher = work)
    val binding = arbiter.registerEngine(Any(), Any())
    arbiter.foreground(binding, true)
    val context = arbiter.bind(binding)["contextGeneration"] as Long
    try {
      arbiter.reserve(binding, binding.ownerToken, binding.engineGeneration,
        context, leaseId, "video")
      fail("default video gate must reject reservation")
    } catch (fault: PracticeAudioArbiter.AudioFault) {
      assertEquals("video_unavailable", fault.code)
    }
  }
}
