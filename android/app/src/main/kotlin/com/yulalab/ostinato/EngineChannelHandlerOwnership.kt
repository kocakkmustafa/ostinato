package com.yulalab.ostinato

import java.util.IdentityHashMap

/**
 * One handler owner per engine and messenger. Flutter channel names are
 * messenger-wide, so an old Activity must never clear a newer registration.
 */
internal class EngineChannelHandlerOwnership {
  class Claim internal constructor(
    val engine: Any,
    val messenger: Any,
    val activityEpoch: Any,
  )

  class Acquisition internal constructor(
    val claim: Claim,
    private val previousRetirements: List<() -> Unit>,
  ) {
    fun retirePrevious() {
      var firstFailure: Throwable? = null
      previousRetirements.forEach { retire ->
        try {
          retire()
        } catch (error: Throwable) {
          if (firstFailure == null) firstFailure = error
        }
      }
      firstFailure?.let { throw it }
    }
  }

  private class Entry(val claim: Claim, val retire: () -> Unit)
  private val gate = Any()
  private val byEngine = IdentityHashMap<Any, Entry>()
  private val byMessenger = IdentityHashMap<Any, Entry>()

  fun claim(
    engine: Any,
    messenger: Any,
    activityEpoch: Any,
    retire: () -> Unit,
  ): Acquisition = synchronized(gate) {
    // A changed messenger for one engine, or a reused messenger for another
    // engine, invalidates both prior registrations before any new install.
    val previous = listOfNotNull(byEngine[engine], byMessenger[messenger]).distinct()
    previous.forEach { removeLocked(it) }
    val claim = Claim(engine, messenger, activityEpoch)
    val entry = Entry(claim, retire)
    byEngine[engine] = entry
    byMessenger[messenger] = entry
    Acquisition(claim, previous.map { it.retire })
  }

  fun isCurrent(claim: Claim): Boolean = synchronized(gate) {
    isCurrentLocked(claim)
  }

  /** Serializes handler publication with every competing claim and clear. */
  fun installIfCurrent(claim: Claim, install: () -> Unit): Boolean = synchronized(gate) {
    if (!isCurrentLocked(claim)) return@synchronized false
    install()
    true
  }

  /**
   * A stale claim may clear its old messenger only if nobody reclaimed that
   * messenger. This also releases handlers after an engine changes messenger.
   */
  fun clearIfMessengerUncontested(claim: Claim, clear: () -> Unit): Boolean = synchronized(gate) {
    val owner = byMessenger[claim.messenger]
    if (owner != null && owner.claim !== claim) return@synchronized false
    try {
      clear()
    } finally {
      if (owner != null) removeLocked(owner)
    }
    true
  }

  private fun isCurrentLocked(claim: Claim): Boolean {
    val entry = byEngine[claim.engine]
    return entry != null && entry === byMessenger[claim.messenger] &&
      entry.claim === claim &&
      entry.claim.engine === claim.engine &&
      entry.claim.messenger === claim.messenger &&
      entry.claim.activityEpoch === claim.activityEpoch
  }

  private fun removeLocked(entry: Entry) {
    val claim = entry.claim
    if (byEngine[claim.engine] === entry) byEngine.remove(claim.engine)
    if (byMessenger[claim.messenger] === entry) byMessenger.remove(claim.messenger)
  }

  companion object {
    val process = EngineChannelHandlerOwnership()
  }
}
