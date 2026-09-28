package com.yulalab.ostinato

import java.security.SecureRandom

/** The capture coordinator and this arbiter use [gate] for every admission decision. */
internal class PracticeAudioArbiter(
  private val work: Work,
  private val outputFactory: OutputFactory? = null,
  private val allowedOutputAssetIds: Set<String> = emptySet(),
  private val closeDeadlineMs: Long = 2_000,
) {
  interface Work {
    fun hardware(task: () -> Unit)
    fun main(task: () -> Unit)
    fun after(delayMs: Long, task: () -> Unit)
  }

  /** Only a future, educator-approved asset adapter may provide these ports.
   * create() must leave no focus/player behind if it throws. */
  interface OutputFactory { fun create(assetId: String): OutputPort }
  interface OutputPort {
    fun start()
    fun stop()
    /** Must also abandon the same audio-focus request; throw if either release fails. */
    fun release()
  }
  interface Reply {
    fun success(value: Map<String, Any?>)
    fun error(code: String)
  }

  class Binding internal constructor(
    val activityOwner: Any,
    val engine: Any,
    val ownerToken: String,
    val engineGeneration: Long,
  )

  data class CaptureClaim(
    val ownerToken: String,
    val engineGeneration: Long,
    val contextGeneration: Long,
    val leaseId: String,
    val leaseGeneration: Long,
  )

  private class ReplyOnce(private var target: Reply?) {
    fun success(value: Map<String, Any?>) {
      val reply = target ?: return
      target = null
      reply.success(value)
    }
    fun error(code: String) {
      val reply = target ?: return
      target = null
      reply.error(code)
    }
  }

  private class Lease(
    val owner: Binding,
    val id: String,
    val generation: Long,
    val contextGeneration: Long,
    val side: String,
  ) {
    var phase = "reserved"
    var port: OutputPort? = null
    var startInFlight = false
    var closeInFlight = false
    var closeRequested = false
    var closeTimedOut = false
    var closeFailed = false
    var startReply: ReplyOnce? = null
    var startFailureCode = "audio_close_unconfirmed"
  }

  val gate = Any()
  private val random = SecureRandom()
  private var capture: AudioCaptureCoordinator? = null
  private var binding: Binding? = null
  private var foregroundOwner: Any? = null
  private var engineGeneration = 0L
  private var contextGeneration = 0L
  private var leaseGeneration = 0L
  private var stateRevision = 0L
  private var lease: Lease? = null
  private var lastInputFingerprint: List<Any?>? = null

  fun attachCapture(coordinator: AudioCaptureCoordinator) = synchronized(gate) {
    check(capture == null || capture === coordinator)
    capture = coordinator
    observeInputLocked()
  }

  /** Registration revokes the previous engine before the new handler is published. */
  fun registerEngine(activityOwner: Any, engine: Any): Binding = synchronized(gate) {
    val old = binding
    if (old != null && old.engine === engine && old.activityOwner === activityOwner) return@synchronized old
    if (old != null) {
      foregroundOwner = null
      capture?.foreground(old.activityOwner, false)
      ++contextGeneration
      closeAllGlobalLocked()
    }
    val current = Binding(activityOwner, engine, randomToken(), ++engineGeneration)
    binding = current
    ++stateRevision
    current
  }

  fun isCurrent(owner: Binding): Boolean = synchronized(gate) { binding === owner }

  fun foreground(owner: Binding, isForeground: Boolean) = synchronized(gate) {
    if (binding !== owner) return@synchronized
    if (isForeground) {
      foregroundOwner = owner.activityOwner
      capture?.foreground(owner.activityOwner, true)
    } else if (foregroundOwner === owner.activityOwner) {
      foregroundOwner = null
      capture?.foreground(owner.activityOwner, false)
      ++contextGeneration
      closeAllGlobalLocked()
    }
    ++stateRevision
  }

  fun bind(owner: Binding): Map<String, Any?> = synchronized(gate) {
    requireCurrentLocked(owner)
    observeInputLocked()
    mapOf(
      "schemaVersion" to 1,
      "ownerToken" to owner.ownerToken,
      "engineGeneration" to owner.engineGeneration,
      "contextGeneration" to contextGeneration,
      "stateRevision" to stateRevision,
    )
  }

  fun readAllAudioState(owner: Binding, token: String, generation: Long): Map<String, Any?> = synchronized(gate) {
    requireOwnerLocked(owner, token, generation)
    snapshotLocked(owner)
  }

  /** Called under the very same monitor as AudioCaptureCoordinator.start(). */
  fun claimCaptureStartLocked(activityOwner: Any, claim: CaptureClaim?): Boolean {
    val current = binding ?: return false
    if (current.activityOwner !== activityOwner || foregroundOwner !== activityOwner) return false
    val held = lease
    if (held == null) return claim == null
    val matches = held.side == "input" && held.phase == "reserved" && claim != null &&
      held.owner === current && claim.ownerToken == current.ownerToken &&
      claim.engineGeneration == current.engineGeneration &&
      claim.contextGeneration == contextGeneration &&
      claim.leaseId == held.id && claim.leaseGeneration == held.generation
    if (matches) {
      held.phase = "starting"
      ++stateRevision
    }
    return matches
  }

  fun reserve(
    owner: Binding, token: String, generation: Long, context: Long,
    id: String, side: String,
  ): Map<String, Any?> = synchronized(gate) {
    requireOwnerLocked(owner, token, generation)
    if (!validToken(id) || side !in setOf("input", "output")) throw AudioFault("bad_args")
    if (context != contextGeneration) throw AudioFault("stale_audio_context")
    if (foregroundOwner !== owner.activityOwner) throw AudioFault("not_foreground_or_permitted")
    // Snapshot and claim are one critical section. A legacy AudioRecord start
    // and a new output reservation cannot both observe an empty process.
    if (snapshotLocked(owner)["allClear"] != true) throw AudioFault("audio_busy")
    val held = Lease(owner, id, ++leaseGeneration, contextGeneration, side)
    lease = held
    ++stateRevision
    mapOf("status" to "reserved", "leaseId" to id,
      "leaseGeneration" to held.generation, "stateRevision" to stateRevision)
  }

  /** No production output factory/allowlist exists until educator media acceptance. */
  fun startOutput(
    owner: Binding, token: String, generation: Long, context: Long,
    id: String, heldGeneration: Long, assetId: String, reply: Reply,
  ) {
    val target = ReplyOnce(reply)
    val held = synchronized(gate) {
      try {
        requireOwnerLocked(owner, token, generation)
        val active = currentLeaseLocked(owner, context, id, heldGeneration)
        if (active.side != "output" || active.phase != "reserved") throw AudioFault("stale_audio_lease")
        if (foregroundOwner !== owner.activityOwner) throw AudioFault("not_foreground_or_permitted")
        if (outputFactory == null || assetId !in allowedOutputAssetIds) {
          lease = null
          ++stateRevision
          throw AudioFault("output_asset_unavailable")
        }
        active.phase = "starting"
        active.startInFlight = true
        active.startReply = target
        ++stateRevision
        active
      } catch (fault: AudioFault) {
        target.error(fault.code)
        return
      }
    }
    work.after(closeDeadlineMs) {
      synchronized(gate) {
        if (lease !== held || !held.startInFlight) return@after
        held.closeTimedOut = true
        held.startReply?.error("audio_close_unconfirmed")
        held.closeRequested = true
        held.phase = "unconfirmedInFlight"
        ++stateRevision
      }
    }
    work.hardware {
      var started = false
      var failed = false
      try {
        val created = outputFactory!!.create(assetId)
        synchronized(gate) {
          if (lease === held) held.port = created
        }
        val mayStart = synchronized(gate) {
          lease === held && !held.closeRequested && binding === owner &&
            held.contextGeneration == contextGeneration
        }
        if (mayStart) {
          created.start()
          started = true
        }
      } catch (_: Throwable) { failed = true }
      work.main {
        synchronized(gate) {
          if (lease !== held) {
            // A replaced process owner keeps this lease until cleanup, so
            // reaching here would indicate a programmer error. Never play.
            return@synchronized
          }
          held.startInFlight = false
          val stillCurrent = binding === owner &&
            held.contextGeneration == contextGeneration && !held.closeRequested
          if (failed || !started || !stillCurrent) {
            held.startFailureCode = if (failed && stillCurrent) "output_setup_failed"
              else "audio_close_unconfirmed"
            requestOutputCloseLocked(held)
          } else {
            held.phase = "playing"
            ++stateRevision
            held.startReply?.success(mapOf("status" to "playing", "leaseId" to id,
              "leaseGeneration" to held.generation, "stateRevision" to stateRevision))
            held.startReply = null
          }
        }
      }
    }
  }

  fun closeAll(
    owner: Binding, token: String, generation: Long, context: Long,
    id: String, heldGeneration: Long, reason: String,
  ): Map<String, Any?> = synchronized(gate) {
    requireOwnerLocked(owner, token, generation)
    if (reason !in setOf("userStop", "routeChange", "accountChange")) throw AudioFault("bad_args")
    val held = lease
    if (held == null || held.owner !== owner || held.contextGeneration != context ||
      held.id != id || held.generation != heldGeneration || context != contextGeneration) {
      // An earlier close may have finished after its pending receipt. The old
      // ticket cannot close a newer lease, but a fully empty process can give
      // a fresh, read-only close acknowledgement to the Dart adapter.
      if (snapshotLocked(owner)["allClear"] == true) {
        ++stateRevision
        return@synchronized receiptLocked(owner)
      }
      return@synchronized receiptLocked(owner, "stale")
    }
    requestLeaseCloseLocked(held)
    receiptLocked(owner)
  }

  fun recoverAll(
    owner: Binding, token: String, generation: Long, expectedRevision: Long,
    reason: String,
  ): Map<String, Any?> = synchronized(gate) {
    requireOwnerLocked(owner, token, generation)
    if (reason != "userRetry" || expectedRevision < 0) throw AudioFault("bad_args")
    if (foregroundOwner !== owner.activityOwner) throw AudioFault("not_foreground_or_permitted")
    val before = snapshotLocked(owner)
    if (before["stateRevision"] != expectedRevision) return@synchronized receiptLocked(owner, "stale")
    // A pending close can settle cleanly before the user's explicit retry.
    // Dart requires a newer closed receipt to release its local blocked latch.
    if (before["allClear"] == true) {
      ++stateRevision
      return@synchronized receiptLocked(owner)
    }
    val held = lease
    if (before["nativeOperationInFlight"] == true ||
      (held != null && held.phase !in setOf("releasedAwaitingExplicitRetry", "unconfirmedQuiescent"))) {
      return@synchronized receiptLocked(owner, "blocked")
    }
    if (held != null && held.side == "output") {
      if (held.phase == "releasedAwaitingExplicitRetry") {
        lease = null
        ++stateRevision
      } else {
        held.closeTimedOut = false
        held.closeFailed = false
        requestOutputCloseLocked(held)
      }
    } else {
      val input = capture?.closeState()
      val id = input?.get("attemptId") as? String
      if (id != null && input["requiresExplicitRetry"] == true) {
        capture?.retryStop(owner.activityOwner, id, object : AudioCaptureCoordinator.Reply {
          override fun success() {}
          override fun error(code: String) {}
        })
      } else if (held != null && held.side == "input" && input?.get("phase") == "clear") {
        lease = null
        ++stateRevision
      } else {
        return@synchronized receiptLocked(owner, "blocked")
      }
    }
    receiptLocked(owner)
  }

  fun fenceContext(
    owner: Binding, token: String, generation: Long, context: Long, reason: String,
  ): Map<String, Any?> = synchronized(gate) {
    requireOwnerLocked(owner, token, generation)
    if (context != contextGeneration) throw AudioFault("stale_audio_context")
    if (reason !in setOf("routeChange", "accountChange", "background")) throw AudioFault("bad_args")
    ++contextGeneration
    ++stateRevision
    closeAllGlobalLocked()
    val receipt = receiptLocked(owner)
    mapOf("contextGeneration" to contextGeneration, "stateRevision" to stateRevision,
      "status" to receipt["status"], "snapshot" to receipt["snapshot"])
  }

  /** Native lifecycle authority only; never callable from a Dart method. */
  fun closeAllGlobal(observedOwner: Binding?) = synchronized(gate) {
    if (observedOwner != null && binding !== observedOwner) return@synchronized
    ++contextGeneration
    ++stateRevision
    closeAllGlobalLocked()
  }

  /** A route callback is allowed to fence only its still-current input owner. */
  fun closeAllGlobalForCaptureOwner(activityOwner: Any) = synchronized(gate) {
    if (binding?.activityOwner !== activityOwner) return@synchronized
    ++contextGeneration
    ++stateRevision
    closeAllGlobalLocked()
  }

  private fun closeAllGlobalLocked() {
    capture?.requestCloseGlobal()
    lease?.let(::requestLeaseCloseLocked)
    observeInputLocked()
  }

  private fun requestLeaseCloseLocked(held: Lease) {
    if (held.side == "input") {
      held.closeRequested = true
      capture?.requestCloseGlobal()
      held.phase = "closing"
      ++stateRevision
      settleInputLeaseLocked()
    } else requestOutputCloseLocked(held)
  }

  private fun requestOutputCloseLocked(held: Lease) {
    if (lease !== held || held.closeInFlight) return
    held.closeRequested = true
    held.phase = if (held.startInFlight) "unconfirmedInFlight" else "closing"
    ++stateRevision
    if (held.startInFlight) return
    val port = held.port
    if (port == null) {
      if (held.closeTimedOut || held.closeFailed) held.phase = "releasedAwaitingExplicitRetry"
      else lease = null
      ++stateRevision
      finishStartFailureLocked(held)
      return
    }
    held.closeInFlight = true
    work.after(closeDeadlineMs) {
      synchronized(gate) {
        if (lease !== held || !held.closeInFlight) return@after
        held.closeTimedOut = true
        held.phase = "unconfirmedInFlight"
        ++stateRevision
      }
    }
    work.hardware {
      var stopFailed = false
      var released = false
      try { port.stop() } catch (_: Throwable) { stopFailed = true }
      try { port.release(); released = true } catch (_: Throwable) { /* keep port for retry */ }
      work.main {
        synchronized(gate) {
          if (lease !== held) return@synchronized
          held.closeInFlight = false
          if (released) held.port = null
          held.closeFailed = held.closeFailed || stopFailed || !released
          if (!released) held.phase = "unconfirmedQuiescent"
          else if (held.closeTimedOut || held.closeFailed) held.phase = "releasedAwaitingExplicitRetry"
          else lease = null
          ++stateRevision
          finishStartFailureLocked(held)
        }
      }
    }
  }

  private fun finishStartFailureLocked(held: Lease) {
    val reply = held.startReply ?: return
    val verifiedRollback = lease !== held && !held.closeTimedOut && !held.closeFailed
    reply.error(if (verifiedRollback) held.startFailureCode else "audio_close_unconfirmed")
    held.startReply = null
  }

  private fun settleInputLeaseLocked() {
    val held = lease ?: return
    if (held.side != "input" || !held.closeRequested) return
    val input = capture?.closeState() ?: return
    if (input["phase"] == "clear") {
      lease = null
      ++stateRevision
    } else if (input["requiresExplicitRetry"] == true) {
      held.phase = input["phase"] as String
    }
  }

  private fun snapshotLocked(owner: Binding): Map<String, Any?> {
    observeInputLocked()
    settleInputLeaseLocked()
    val input = capture?.closeState() ?: mapOf(
      "phase" to "clear", "attemptId" to null,
      "attemptInFlight" to false, "resourcesReleased" to true,
      "requiresExplicitRetry" to false,
    )
    val held = lease
    val inputPhase = if (held?.side == "input" && input["phase"] == "clear") held?.phase
      else input["phase"] as String
    val outputPhase = if (held?.side == "output") held?.phase else "clear"
    val inputReleased = input["resourcesReleased"] == true
    val outputReleased = held?.side != "output" || held.port == null &&
      !held.startInFlight && !held.closeInFlight
    val sessionReleased = outputReleased // Android holds no focus without its output port.
    val inFlight = input["attemptInFlight"] == true || held?.startInFlight == true ||
      held?.closeInFlight == true
    val retry = input["requiresExplicitRetry"] == true ||
      (held?.side == "output" && held?.phase in setOf(
        "unconfirmedQuiescent", "releasedAwaitingExplicitRetry"))
    val allClear = held == null && inputPhase == "clear" && outputPhase == "clear" &&
      inputReleased && outputReleased && sessionReleased && !inFlight && !retry
    return mapOf(
      "schemaVersion" to 1,
      "ownerToken" to owner.ownerToken,
      "engineGeneration" to owner.engineGeneration,
      "contextGeneration" to contextGeneration,
      "stateRevision" to stateRevision,
      "activeSide" to held?.side,
      "activeLeaseGeneration" to held?.generation,
      "inputPhase" to inputPhase,
      "outputPhase" to outputPhase,
      "inputReleased" to inputReleased,
      "outputReleased" to outputReleased,
      "sessionReleased" to sessionReleased,
      "nativeOperationInFlight" to inFlight,
      "requiresExplicitRetry" to retry,
      "allClear" to allClear,
    )
  }

  private fun receiptLocked(owner: Binding, forcedStatus: String? = null): Map<String, Any?> {
    val snapshot = snapshotLocked(owner)
    val status = forcedStatus ?: when {
      snapshot["allClear"] == true -> "closed"
      snapshot["nativeOperationInFlight"] == true -> "pending"
      else -> "blocked"
    }
    return mapOf("status" to status, "snapshot" to snapshot)
  }

  private fun observeInputLocked() {
    val input = capture?.closeState() ?: return
    val fingerprint = listOf(input["phase"], input["attemptId"],
      input["attemptInFlight"], input["resourcesReleased"], input["requiresExplicitRetry"])
    if (fingerprint != lastInputFingerprint) {
      lastInputFingerprint = fingerprint
      ++stateRevision
    }
  }

  private fun currentLeaseLocked(owner: Binding, context: Long, id: String, generation: Long): Lease {
    val held = lease
    if (held == null || held.owner !== owner || held.contextGeneration != contextGeneration ||
      held.contextGeneration != context || held.id != id || held.generation != generation) {
      throw AudioFault("stale_audio_lease")
    }
    return held
  }

  private fun requireCurrentLocked(owner: Binding) {
    if (binding !== owner) throw AudioFault("stale_audio_owner")
  }

  private fun requireOwnerLocked(owner: Binding, token: String, generation: Long) {
    requireCurrentLocked(owner)
    if (owner.ownerToken != token || owner.engineGeneration != generation) {
      throw AudioFault("stale_audio_owner")
    }
  }

  private fun randomToken(): String {
    val bytes = ByteArray(16)
    random.nextBytes(bytes)
    return bytes.joinToString("") { "%02x".format(it.toInt() and 0xff) }
  }

  private fun validToken(value: String): Boolean = value.length == 32 &&
    value.all { it in '0'..'9' || it in 'a'..'f' }

  class AudioFault(val code: String) : RuntimeException(code)
}
