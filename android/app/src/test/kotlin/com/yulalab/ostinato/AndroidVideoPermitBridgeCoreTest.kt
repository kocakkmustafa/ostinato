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

    fun newCore(plugin: FakePlugin, messenger: FakeMessenger,
                owner: PracticeAudioArbiter.Binding = binding) =
      AndroidVideoPermitBridgeCore<FakeClaim, FakePlugin, FakeMessenger>(
        arbiter, owner, plugin, messenger,
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

  @Test fun bridgeRebindNeedsBothExactNativeReleaseAndDartAck() {
    val h = Harness()
    assertTrue(h.core.isQuiescentForRebind())
    val claim = h.reserve()
    assertFalse(h.core.isQuiescentForRebind())
    assertTrue(h.core.withClaimedVideoCreation(claim, Runnable {}))
    assertFalse(h.core.isQuiescentForRebind())

    assertTrue(h.core.releaseVideoPlayer(claim))
    assertFalse(h.core.isQuiescentForRebind()) // Native-only is not a Dart ACK.
    assertEquals("closed", h.ack(claim)["status"])
    assertTrue(h.core.isQuiescentForRebind())
  }

  @Test fun cachedEngineNewActivityCanRebindVirginOldBridge() {
    val h = Harness()
    val replacement = h.arbiter.registerEngine(Any(), h.binding.engine)
    assertFalse(h.arbiter.isCurrent(h.binding))
    assertTrue(h.arbiter.isCurrent(replacement))
    assertTrue(h.core.isQuiescentForRebind())
  }

  @Test fun cachedEngineNewActivityCanRebindOnlyAfterOldExactCloseAndAck() {
    val h = Harness()
    val claim = h.reserve()
    assertTrue(h.core.withClaimedVideoCreation(claim, Runnable {}))
    assertTrue(h.core.releaseVideoPlayer(claim))
    assertEquals("closed", h.ack(claim)["status"])
    val replacement = h.arbiter.registerEngine(Any(), h.binding.engine)
    assertFalse(h.arbiter.isCurrent(h.binding))
    assertTrue(h.arbiter.isCurrent(replacement))
    assertTrue(h.core.isQuiescentForRebind())
  }

  @Test fun cancelledUnclaimedSuccessorDoesNotEraseOldCapturedReleaseProof() {
    val h = Harness()
    val first = h.reserve()
    assertTrue(h.core.withClaimedVideoCreation(first, Runnable {}))
    assertTrue(h.core.releaseVideoPlayer(first))
    assertEquals("closed", h.ack(first)["status"])
    assertTrue(h.core.isQuiescentForRebind())

    val unclaimed = h.reserve("b".repeat(32), 8L)
    assertFalse(h.core.isCurrentClaim(unclaimed))
    assertFalse(h.core.isQuiescentForRebind()) // Y is held, never captured.
    assertEquals("closed", h.arbiter.cancelVideoReservation(h.binding,
      unclaimed.ownerToken, unclaimed.engineGeneration,
      unclaimed.contextGeneration, unclaimed.leaseId,
      unclaimed.leaseGeneration)["status"])
    assertTrue(h.core.isQuiescentForRebind()) // The bridge still captures X.

    val replacement = h.arbiter.registerEngine(Any(), h.binding.engine)
    h.arbiter.foreground(replacement, true)
    assertEquals(true, h.arbiter.quiescentOwnerHandoff(replacement,
      h.binding.ownerToken, h.binding.engineGeneration)
      .let { (it["snapshot"] as Map<*, *>)["allClear"] })
    assertTrue(h.core.isQuiescentForRebind())
  }

  @Test fun claimedSuccessorReplacesCapturedProofBeforeFirstEffect() {
    val h = Harness()
    val first = h.reserve()
    assertTrue(h.core.withClaimedVideoCreation(first, Runnable {}))
    assertTrue(h.core.releaseVideoPlayer(first))
    assertEquals("closed", h.ack(first)["status"])
    val oldClaim = PracticeAudioArbiter.VideoPlayerClaim(h.binding,
      first.ownerToken, first.engineGeneration, first.contextGeneration,
      first.leaseId, first.leaseGeneration, first.playerId)

    val second = h.reserve("b".repeat(32), 8L)
    assertTrue(h.arbiter.wasVideoPlayerReleased(oldClaim))
    assertTrue(h.core.withClaimedVideoCreation(second, Runnable {
      assertFalse(h.arbiter.wasVideoPlayerReleased(oldClaim))
      assertTrue(h.core.isCurrentClaim(second))
    }))
    assertFalse(h.core.isQuiescentForRebind())
    assertTrue(h.core.releaseVideoPlayer(second))
    assertFalse(h.core.isQuiescentForRebind()) // Release alone is not Y ACK.
    assertEquals("closed", h.ack(second)["status"])
    assertTrue(h.core.isQuiescentForRebind())
  }

  @Test fun foreignHistoryKeepsOldBridgeProofWhileNewEngineCancelsUnclaimedVideo() {
    val h = Harness()
    val first = h.reserve()
    assertTrue(h.core.withClaimedVideoCreation(first, Runnable {}))
    assertTrue(h.core.releaseVideoPlayer(first))
    assertEquals("closed", h.ack(first)["status"])
    val secondEngine = Any()
    val second = h.arbiter.registerEngine(Any(), secondEngine)
    h.arbiter.foreground(second, true)
    val secondCore = h.newCore(FakePlugin(), FakeMessenger(), second)
    assertTrue(h.core.isQuiescentForRebind()) // E1 may still reuse captured X.
    assertTrue(secondCore.isQuiescentForRebind()) // E2 captured no player.

    val context = h.state(second)["contextGeneration"] as Long
    val id = "b".repeat(32)
    val permit = h.arbiter.reserve(second, second.ownerToken,
      second.engineGeneration, context, id, "video")
    assertFalse(h.core.isQuiescentForRebind()) // Y lease blocks both engines.
    assertFalse(secondCore.isQuiescentForRebind())
    assertEquals("closed", h.arbiter.cancelVideoReservation(second,
      second.ownerToken, second.engineGeneration, context, id,
      permit["leaseGeneration"] as Long)["status"])
    assertTrue(h.core.isQuiescentForRebind())
    assertTrue(secondCore.isQuiescentForRebind())

    val third = h.arbiter.registerEngine(Any(), secondEngine)
    h.arbiter.foreground(third, true)
    assertEquals(true, h.arbiter.quiescentOwnerHandoff(third,
      second.ownerToken, second.engineGeneration)
      .let { (it["snapshot"] as Map<*, *>)["allClear"] })
  }

  @Test fun provisionalForeignHandoffCannotReuseAnE2BridgeWithStaleCapturedY() {
    val h = Harness()
    val secondEngine = h.binding.engine
    val y = h.reserve()
    assertTrue(h.core.withClaimedVideoCreation(y, Runnable {}))
    assertTrue(h.core.releaseVideoPlayer(y))
    assertEquals("closed", h.ack(y)["status"])
    assertTrue(h.core.isQuiescentForRebind())

    val first = h.arbiter.registerEngine(Any(), Any())
    h.arbiter.foreground(first, true)
    val firstCore = h.newCore(FakePlugin(), FakeMessenger(), first)
    val context = h.state(first)["contextGeneration"] as Long
    val id = "b".repeat(32)
    val permit = h.arbiter.reserve(first, first.ownerToken,
      first.engineGeneration, context, id, "video")
    val x = FakeClaim(first.ownerToken, first.engineGeneration, context,
      id, permit["leaseGeneration"] as Long, 8L)
    assertTrue(firstCore.withClaimedVideoCreation(x, Runnable {}))
    assertTrue(firstCore.releaseVideoPlayer(x))
    assertEquals("closed", h.arbiter.completeVideoDispose(first,
      first.ownerToken, first.engineGeneration, context, id,
      permit["leaseGeneration"] as Long, true)["status"])
    assertTrue(firstCore.isQuiescentForRebind())
    assertFalse(h.core.isQuiescentForRebind()) // E2 captured Y, receipt is X.

    val second = h.arbiter.registerEngine(Any(), secondEngine)
    h.arbiter.foreground(second, true)
    val third = h.arbiter.registerEngine(Any(), secondEngine)
    h.arbiter.foreground(third, true)
    assertEquals(true, h.arbiter.quiescentOwnerHandoff(third,
      second.ownerToken, second.engineGeneration)
      .let { (it["snapshot"] as Map<*, *>)["allClear"] })
    // The channel must consult the old E2 vendor bridge before returning this
    // provisional arbiter result to Dart. Its captured-Y proof is invalid.
    assertFalse(h.core.isQuiescentForRebind())
  }

  @Test fun earlyAckAndRetiredOwnerCannotRebindAnUnreleasedClaim() {
    val h = Harness()
    val claim = h.reserve()
    assertTrue(h.core.withClaimedVideoCreation(claim, Runnable {}))
    h.ack(claim)
    assertFalse(h.core.isQuiescentForRebind()) // ACK-only is not native release.
    assertTrue(h.core.releaseVideoPlayer(claim))
    assertTrue(h.core.isQuiescentForRebind())

    val second = h.reserve("b".repeat(32), 8L)
    assertTrue(h.core.withClaimedVideoCreation(second, Runnable {}))
    h.arbiter.registerEngine(Any(), h.binding.engine)
    assertFalse(h.core.isQuiescentForRebind())
    assertTrue(h.core.releaseVideoPlayer(second))
    assertFalse(h.core.isQuiescentForRebind()) // Retired Dart owner cannot ACK.
  }

  @Test fun foreignOwnerCannotInventAckForRetiredOriginalLease() {
    val h = Harness()
    val original = h.reserve()
    assertTrue(h.core.withClaimedVideoCreation(original, Runnable {}))
    val next = h.arbiter.registerEngine(Any(), h.binding.engine)
    h.arbiter.foreground(next, true)
    assertTrue(h.core.releaseVideoPlayer(original))

    try {
      h.ack(original)
      fail("retired binding must not ACK")
    } catch (fault: PracticeAudioArbiter.AudioFault) {
      assertEquals("stale_audio_owner", fault.code)
    }
    assertEquals("stale", h.arbiter.completeVideoDispose(next,
      next.ownerToken, next.engineGeneration, original.contextGeneration,
      original.leaseId, original.leaseGeneration, true)["status"])
    assertFalse(h.core.isQuiescentForRebind())
    assertEquals(false, h.state(next)["allClear"])
  }

  @Test fun replayForOldLeaseCannotAcknowledgeNewOwnerLease() {
    val h = Harness()
    val original = h.reserve()
    assertTrue(h.core.withClaimedVideoCreation(original, Runnable {}))
    assertTrue(h.core.releaseVideoPlayer(original))
    assertEquals("closed", h.ack(original)["status"])

    val next = h.arbiter.registerEngine(Any(), h.binding.engine)
    h.arbiter.foreground(next, true)
    val context = h.state(next)["contextGeneration"] as Long
    val newerId = "b".repeat(32)
    val newer = h.arbiter.reserve(next, next.ownerToken,
      next.engineGeneration, context, newerId, "video")
    val newerGeneration = newer["leaseGeneration"]

    assertEquals("stale", h.arbiter.completeVideoDispose(next,
      next.ownerToken, next.engineGeneration, original.contextGeneration,
      original.leaseId, original.leaseGeneration, true)["status"])
    val state = h.state(next)
    assertEquals(newerGeneration, state["activeLeaseGeneration"])
    assertEquals("video", state["activeSide"])
    assertEquals(false, state["allClear"])
  }

  @Test fun unconfirmedNativeCleanupCannotRebindBridge() {
    val h = Harness()
    val claim = h.reserve()
    assertTrue(h.core.withClaimedVideoCreation(claim, Runnable {}))
    h.plugin.result = AndroidVideoPermitBridgeCore.ExactCloseResult.UNCONFIRMED
    h.arbiter.closeAllGlobal(h.binding)
    h.work.drainMain()
    assertFalse(h.core.isQuiescentForRebind())
  }

  @Test fun productionDefaultVideoGateRejectsReservationAndNativeFirstEffect() {
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

    val messenger = FakeMessenger()
    val plugin = FakePlugin()
    val core = AndroidVideoPermitBridgeCore<FakeClaim, FakePlugin, FakeMessenger>(
      arbiter, binding, plugin, messenger,
      fieldsOf = { it.fields() },
      closeExact = { exactPlugin, exactMessenger, exactClaim ->
        exactPlugin.close(exactMessenger, exactClaim)
      },
    )
    val claim = FakeClaim(binding.ownerToken, binding.engineGeneration,
      context, leaseId, 1L, 7L)
    var firstEffects = 0
    assertFalse(core.withClaimedVideoCreation(claim, Runnable { firstEffects++ }))
    assertEquals(0, firstEffects)
    assertFalse(core.isCurrentClaim(claim))
    assertFalse(core.releaseVideoPlayer(claim))
    assertTrue(plugin.calls.isEmpty())
  }

  @Test fun sameEngineRetiredAckAfterNativeReleaseHasExactLostReplyReadback() {
    val h = Harness()
    val claim = h.reserve()
    assertTrue(h.core.withClaimedVideoCreation(claim, Runnable {}))
    val next = h.arbiter.registerEngine(Any(), h.binding.engine)
    h.arbiter.foreground(next, true)
    assertTrue(h.core.releaseVideoPlayer(claim))
    assertFalse(h.core.isQuiescentForRebind())
    val receipt = h.arbiter.completeRetiredVideoDispose(next,
      claim.ownerToken, claim.engineGeneration, claim.contextGeneration,
      claim.leaseId, claim.leaseGeneration, true)
    assertEquals("RECORDED", receipt["ackStatus"])
    assertEquals(true, receipt["nativeReleaseRecorded"])
    assertEquals(true, receipt["leaseSettled"])
    assertEquals(claim.playerId, receipt["playerId"])
    assertEquals(next.ownerToken, (receipt["snapshot"] as Map<*, *>)["ownerToken"])
    val revision = h.state(next)["stateRevision"]
    val replay = h.arbiter.completeRetiredVideoDispose(next,
      claim.ownerToken, claim.engineGeneration, claim.contextGeneration,
      claim.leaseId, claim.leaseGeneration, true)
    assertEquals("RECORDED", replay["ackStatus"])
    assertEquals(revision, h.state(next)["stateRevision"])
    val read = h.arbiter.readVideoDisposeReceipt(next,
      claim.ownerToken, claim.engineGeneration, claim.contextGeneration,
      claim.leaseId, claim.leaseGeneration)
    assertEquals("RECORDED", read["ackStatus"])
    assertTrue(h.core.isQuiescentForRebind())
  }

  @Test fun sameEngineAckBeforeReleaseDoesNotInventNativeCompletion() {
    val h = Harness()
    val claim = h.reserve()
    assertTrue(h.core.withClaimedVideoCreation(claim, Runnable {}))
    val next = h.arbiter.registerEngine(Any(), h.binding.engine)
    h.arbiter.foreground(next, true)
    val before = h.arbiter.readVideoDisposeReceipt(next,
      claim.ownerToken, claim.engineGeneration, claim.contextGeneration,
      claim.leaseId, claim.leaseGeneration)
    assertEquals("NOT_RECORDED", before["ackStatus"])
    assertEquals(false, before["nativeReleaseRecorded"])
    val ack = h.arbiter.completeRetiredVideoDispose(next,
      claim.ownerToken, claim.engineGeneration, claim.contextGeneration,
      claim.leaseId, claim.leaseGeneration, true)
    assertEquals("RECORDED", ack["ackStatus"])
    assertEquals(false, ack["nativeReleaseRecorded"])
    assertEquals(false, ack["leaseSettled"])
    assertFalse(h.core.isQuiescentForRebind())
    assertTrue(h.core.releaseVideoPlayer(claim))
    val closed = h.arbiter.readVideoDisposeReceipt(next,
      claim.ownerToken, claim.engineGeneration, claim.contextGeneration,
      claim.leaseId, claim.leaseGeneration)
    assertEquals(true, closed["leaseSettled"])
  }

  @Test fun foreignEngineAndFalseAckCannotConsumeRetiredClaim() {
    val h = Harness()
    val claim = h.reserve()
    assertTrue(h.core.withClaimedVideoCreation(claim, Runnable {}))
    val foreign = h.arbiter.registerEngine(Any(), Any())
    h.arbiter.foreground(foreign, true)
    assertTrue(h.core.releaseVideoPlayer(claim))
    for (confirmed in listOf(false, true)) {
      try {
        h.arbiter.completeRetiredVideoDispose(foreign,
          claim.ownerToken, claim.engineGeneration, claim.contextGeneration,
          claim.leaseId, claim.leaseGeneration, confirmed)
        fail("foreign engine or false ACK must fail")
      } catch (_: PracticeAudioArbiter.AudioFault) { }
    }
    assertEquals(false, h.state(foreign)["allClear"])
    assertEquals(false, h.arbiter.wasVideoPlayerReleased(
      PracticeAudioArbiter.VideoPlayerClaim(foreign,
        claim.ownerToken, claim.engineGeneration, claim.contextGeneration,
        claim.leaseId, claim.leaseGeneration, claim.playerId)))
  }

  @Test fun oldAckCannotMutateSecondLeaseOnSameEngine() {
    val h = Harness()
    val old = h.reserve()
    assertTrue(h.core.withClaimedVideoCreation(old, Runnable {}))
    assertTrue(h.core.releaseVideoPlayer(old))
    val next = h.arbiter.registerEngine(Any(), h.binding.engine)
    h.arbiter.foreground(next, true)
    h.arbiter.completeRetiredVideoDispose(next,
      old.ownerToken, old.engineGeneration, old.contextGeneration,
      old.leaseId, old.leaseGeneration, true)
    val context = h.state(next)["contextGeneration"] as Long
    val newer = h.arbiter.reserve(next, next.ownerToken,
      next.engineGeneration, context, "b".repeat(32), "video")
    val revision = h.state(next)["stateRevision"]
    try {
      h.arbiter.completeRetiredVideoDispose(next,
        old.ownerToken, old.engineGeneration, old.contextGeneration,
        old.leaseId, old.leaseGeneration, true)
      fail("old ACK must not apply after a new reservation")
    } catch (fault: PracticeAudioArbiter.AudioFault) {
      assertEquals("stale_audio_lease", fault.code)
    }
    assertEquals(revision, h.state(next)["stateRevision"])
    assertEquals(newer["leaseGeneration"], h.state(next)["activeLeaseGeneration"])
  }
}
