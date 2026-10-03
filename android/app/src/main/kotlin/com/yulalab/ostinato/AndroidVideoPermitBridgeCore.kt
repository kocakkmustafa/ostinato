package com.yulalab.ostinato

/** App-owned half of one engine-bound video permit bridge.
 *
 * [Claim], [Plugin], and [Messenger] remain the caller's exact objects. The
 * vendor adapter creates one core per registered plugin and messenger; it
 * must not rebuild a claim from its fields for a later callback.
 */
internal class AndroidVideoPermitBridgeCore<Claim : Any, Plugin : Any, Messenger : Any>(
  private val arbiter: PracticeAudioArbiter,
  private val binding: PracticeAudioArbiter.Binding,
  private val plugin: Plugin,
  private val messenger: Messenger,
  private val fieldsOf: (Claim) -> Fields,
  private val closeExact: (Plugin, Messenger, Claim) -> ExactCloseResult,
) {
  data class Fields(
    val ownerToken: String,
    val engineGeneration: Long,
    val contextGeneration: Long,
    val leaseId: String,
    val leaseGeneration: Long,
    val playerId: Long,
  )

  enum class ExactCloseResult { RELEASED_EXACT, PENDING_CREATE, UNCONFIRMED }

  private class Captured<Claim : Any>(
    val original: Claim,
    val arbiterClaim: PracticeAudioArbiter.VideoPlayerClaim,
  )

  @Volatile private var captured: Captured<Claim>? = null

  /** The first side effect runs synchronously after the arbiter stores the close port. */
  fun withClaimedVideoCreation(claim: Claim, create: Runnable): Boolean {
    val fields = fieldsOf(claim)
    val exact = PracticeAudioArbiter.VideoPlayerClaim(
      binding, fields.ownerToken, fields.engineGeneration,
      fields.contextGeneration, fields.leaseId, fields.leaseGeneration,
      fields.playerId,
    )
    val closePort = PracticeAudioArbiter.VideoClosePort(exact) {
      val current = captured
      current != null && current.original === claim && current.arbiterClaim === exact &&
        closeExact(plugin, messenger, claim) == ExactCloseResult.RELEASED_EXACT
    }
    return arbiter.withClaimedVideoCreation(
      binding, fields.ownerToken, fields.engineGeneration,
      fields.contextGeneration, fields.leaseId, fields.leaseGeneration,
      fields.playerId, closePort,
    ) {
      captured = Captured(claim, exact)
      create.run()
    }
  }

  /** Reuses the originally captured app claim; constructing an equal copy fails. */
  fun isCurrentClaim(claim: Claim): Boolean {
    val current = captured ?: return false
    return current.original === claim && arbiter.isCurrentVideoClaim(current.arbiterClaim)
  }

  /** Called only after the matching vendor player and its channels are cleaned. */
  fun releaseVideoPlayer(claim: Claim): Boolean {
    val current = captured ?: return false
    if (current.original !== claim) return false
    val exact = current.arbiterClaim
    val released = arbiter.releaseVideoPlayer(
      binding, exact.ownerToken, exact.engineGeneration,
      exact.contextGeneration, exact.leaseId, exact.leaseGeneration,
      exact.playerId,
    )
    return released || arbiter.wasVideoPlayerReleased(exact)
  }

  /** The vendor separately verifies that no native record or player remains. */
  fun isQuiescentForRebind(): Boolean =
    arbiter.isVideoBridgeRebindQuiescent(captured?.arbiterClaim)
}
