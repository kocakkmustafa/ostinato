package com.yulalab.ostinato

import java.util.IdentityHashMap
import java.util.concurrent.atomic.AtomicBoolean

/** Hardware-independent capture state machine. All public calls arrive on the platform thread;
 * hardware and reads use separate workers. A timed-out method reply never proves release. */
internal class AudioCaptureCoordinator(
  private val factory: RecorderFactory,
  private val dispatch: CaptureDispatch,
  private val closeDeadlineMs: Long = 2_000,
  private val readExitBudgetMs: Long = 500,
) {
  internal interface RecorderFactory { fun create(sampleRate: Int): RecorderPort }
  internal interface RecorderPort {
    val sampleRate: Int
    fun start()
    fun read(buffer: ShortArray): Int
    fun stop()
    fun release()
    fun route(): String
    fun watchRoute(changed: () -> Unit)
    fun unwatchRoute()
  }
  internal interface ReadHandle { fun awaitExit(timeoutMs: Long): Boolean }
  internal interface CaptureDispatch {
    fun hardware(task: () -> Unit)
    fun reader(task: () -> Unit): ReadHandle
    fun main(task: () -> Unit)
    fun after(delayMs: Long, task: () -> Unit)
  }
  internal interface Reply {
    fun success()
    fun error(code: String)
  }
  internal interface Output { fun event(message: Map<String, Any>) }

  private class ReplyGate(private var target: Reply?) {
    fun success() { val reply = target ?: return; target = null; reply.success() }
    fun error(code: String) { val reply = target ?: return; target = null; reply.error(code) }
    val pending: Boolean get() = target != null
  }

  private class Attempt(
    val owner: Any,
    val id: String,
    val rate: Int,
    val generation: Long,
    var output: Output?,
    val startReply: ReplyGate,
  ) {
    var port: RecorderPort? = null
    var reader: ReadHandle? = null
    var readerExited = false
    var recordingStarted = false
    var stopRequested = false
    var stopAttempted = false
    var releaseStarted = false
    var closeQueued = false
    var waitingReader = false
    var closeDeadlineSet = false
    var closeTimedOut = false
    var closeFailure = false
    var phase = "starting"
    val pendingBuffer = AtomicBoolean(false)
    val stopReplies = mutableListOf<ReplyGate>()
  }

  private val gate = Any()
  private val tombstones = mutableSetOf<String>()
  private val bindings = IdentityHashMap<Any, MutableSet<String>>()
  private var current: Attempt? = null
  private var generation = 0L
  private var foregroundOwner: Any? = null

  /** Foreground changes and attempt operations share one lock: an old Activity
   * cannot pass a foreground check and mutate a newer owner's attempt later. */
  fun foreground(owner: Any, isForeground: Boolean) = synchronized(gate) {
    if (isForeground) foregroundOwner = owner
    else if (foregroundOwner === owner) foregroundOwner = null
  }

  fun isForeground(owner: Any): Boolean = synchronized(gate) { foregroundOwner === owner }

  /** EventChannel listen is the only way a handler claims an ID. It cannot
   * claim a newer Activity's ID after losing process foreground ownership. */
  fun bind(owner: Any, id: String): Boolean = synchronized(gate) {
    if (foregroundOwner !== owner || !validId(id) || id in tombstones) return@synchronized false
    bindings.getOrPut(owner) { mutableSetOf() }.add(id)
    true
  }

  fun unbind(owner: Any, id: String) = synchronized(gate) {
    bindings[owner]?.let { ids ->
      ids.remove(id)
      if (ids.isEmpty()) bindings.remove(owner)
    }
  }

  fun isBound(owner: Any, id: String): Boolean = synchronized(gate) {
    bindings[owner]?.contains(id) == true
  }

  fun closeState(): Map<String, Any?> = synchronized(gate) {
    val attempt = current
    val phase = attempt?.phase ?: "clear"
    mapOf(
      "phase" to phase,
      "attemptId" to attempt?.id,
      "attemptInFlight" to (phase == "starting" || phase == "closing" || phase == "unconfirmedInFlight"),
      "resourcesReleased" to (phase == "clear" || phase == "releasedAwaitingExplicitRetry"),
      "requiresExplicitRetry" to (phase == "unconfirmedQuiescent" || phase == "releasedAwaitingExplicitRetry"),
    )
  }

  fun start(owner: Any, id: String, rate: Int, output: Output, reply: Reply) {
    val response = ReplyGate(reply)
    val attempt = synchronized(gate) {
      if (!validId(id) || rate !in setOf(44100, 48000)) {
        response.error("bad_args"); return
      }
      if (foregroundOwner !== owner) {
        response.error("not_foreground_or_permitted"); return
      }
      if (bindings[owner]?.contains(id) != true) {
        response.error("capture_close_unconfirmed"); return
      }
      if (current != null || id in tombstones) {
        response.error("capture_close_unconfirmed"); return
      }
      Attempt(owner, id, rate, ++generation, output, response).also { current = it }
    }
    dispatch.after(closeDeadlineMs) {
      synchronized(gate) {
        if (current !== attempt || !response.pending) return@after
        response.error("capture_close_unconfirmed")
        attempt.closeTimedOut = true
        requestCloseLocked(attempt)
      }
    }
    dispatch.hardware {
      try {
        val port = factory.create(rate)
        synchronized(gate) {
          attempt.port = port
          if (attempt.stopRequested || current !== attempt) return@synchronized
        }
        if (!isLive(attempt)) return@hardware
        port.start()
        synchronized(gate) { attempt.recordingStarted = true }
        dispatch.main { finishStart(attempt) }
      } catch (_: Throwable) {
        dispatch.main {
          synchronized(gate) {
            if (current !== attempt) return@synchronized
            attempt.startReply.error("setup_failed")
            if (attempt.port == null && !attempt.stopRequested) {
              tombstones.add(attempt.id); current = null
            } else {
              attempt.closeFailure = true
              requestCloseLocked(attempt)
            }
          }
        }
      } finally {
        // stop may have arrived while create/start blocked. Its close worker is
        // already queued behind this task on the serial hardware executor.
      }
    }
  }

  private fun finishStart(attempt: Attempt) {
    synchronized(gate) {
      if (current !== attempt || attempt.stopRequested) return
      val port = attempt.port ?: return
      attempt.phase = "running"
      try { port.watchRoute { dispatch.main { emitRoute(attempt) } } }
      catch (_: Throwable) { /* event is optional */ }
      emitRoute(attempt)
      attempt.reader = dispatch.reader { readLoop(attempt, port) }
      attempt.startReply.success()
    }
  }

  private fun readLoop(attempt: Attempt, port: RecorderPort) {
    val pcm = ShortArray(4096)
    try {
      while (isLive(attempt)) {
        val count = port.read(pcm)
        if (count < 0) throw IllegalStateException("capture_read_failed")
        if (count == 0) continue
        if (!attempt.pendingBuffer.compareAndSet(false, true)) { pcm.fill(0); continue }
        val samples = DoubleArray(count) { pcm[it] / 32768.0 }
        val time = System.nanoTime() / 1000 - count.toLong() * 1_000_000 / port.sampleRate
        dispatch.main {
          emit(attempt, mapOf("type" to "chunk", "attemptId" to attempt.id,
            "samples" to samples, "sampleRate" to port.sampleRate, "t" to time))
          samples.fill(0.0)
          attempt.pendingBuffer.set(false)
        }
        pcm.fill(0)
      }
    } catch (_: Throwable) {
      dispatch.main {
        emit(attempt, mapOf("type" to "interrupted", "attemptId" to attempt.id,
          "reason" to "capture_read_failed"))
        requestClose(attempt)
      }
    } finally {
      pcm.fill(0)
      dispatch.main { onReaderExited(attempt) }
    }
  }

  private fun emitRoute(attempt: Attempt) {
    val route = try { attempt.port?.route() ?: "android:Unknown" } catch (_: Throwable) { "android:Unknown" }
    emit(attempt, mapOf("type" to "routeChanged", "attemptId" to attempt.id, "route" to route))
  }

  private fun emit(attempt: Attempt, message: Map<String, Any>) {
    synchronized(gate) {
      if (!isLiveLocked(attempt)) return
      attempt.output?.event(message)
    }
  }

  fun stop(owner: Any, id: String, reply: Reply? = null) {
    val response = reply?.let(::ReplyGate)
    synchronized(gate) {
      if (!validId(id)) { response?.error("bad_args"); return }
      if (bindings[owner]?.contains(id) != true) {
        response?.error("capture_close_unconfirmed"); return
      }
      val attempt = current
      if (attempt == null) {
        tombstones.add(id) // A previously bound ID remains vetoed after close.
        response?.success()
        return
      }
      if (attempt.owner !== owner) {
        response?.error("capture_close_unconfirmed"); return
      }
      if (attempt.id != id) {
        if (id in tombstones) response?.success() else response?.error("capture_close_unconfirmed")
        return
      }
      if (attempt.phase == "releasedAwaitingExplicitRetry") {
        response?.error("capture_close_unconfirmed"); return
      }
      if (attempt.phase == "unconfirmedQuiescent") {
        response?.error("capture_close_unconfirmed"); return
      }
      if (response != null) {
        attempt.stopReplies.add(response)
        dispatch.after(closeDeadlineMs) {
          synchronized(gate) {
            if (!response.pending) return@after
            response.error("capture_close_unconfirmed")
            attempt.closeTimedOut = true
            if (current === attempt && attempt.phase != "releasedAwaitingExplicitRetry") {
              attempt.phase = if (attempt.releaseStarted || !attempt.readerExited && attempt.reader != null || attempt.closeQueued)
                "unconfirmedInFlight" else "unconfirmedQuiescent"
            }
          }
        }
      }
      requestCloseLocked(attempt)
    }
  }

  /** Dart may send stop before EventChannel listen arrives. This unbound veto
   * is legal only for the current foreground owner and with no active attempt. */
  fun stopBeforeListen(owner: Any, id: String, reply: Reply? = null) {
    val response = reply?.let(::ReplyGate)
    synchronized(gate) {
      if (!validId(id)) { response?.error("bad_args"); return }
      if (foregroundOwner !== owner) {
        response?.error("not_foreground_or_permitted"); return
      }
      if (current != null) {
        response?.error("capture_close_unconfirmed"); return
      }
      tombstones.add(id)
      response?.success()
    }
  }

  /** Only the user-visible retry action may acknowledge or reattempt a sticky close. */
  fun retryStop(owner: Any, id: String, reply: Reply) {
    val response = ReplyGate(reply)
    synchronized(gate) {
      if (!validId(id)) { response.error("bad_args"); return }
      if (foregroundOwner !== owner) {
        response.error("not_foreground_or_permitted"); return
      }
      val attempt = current
      if (attempt == null) {
        // A previous owner's close may have finished before the visible tap.
        // This is only an idempotent acknowledgement, never a hardware action.
        if (id in tombstones) response.success() else response.error("capture_close_unconfirmed")
        return
      }
      if (attempt.id != id) { response.error("capture_close_unconfirmed"); return }
      val boundCurrentOwner = attempt.owner === owner && bindings[owner]?.contains(id) == true
      if (!boundCurrentOwner &&
        (!attempt.stopRequested || id !in tombstones ||
          attempt.phase !in setOf("releasedAwaitingExplicitRetry", "unconfirmedQuiescent"))) {
        // A new Activity or engine may finish only a sticky *old* close.
        // An unbound caller cannot stop a running or in-flight recorder.
        response.error("capture_close_unconfirmed"); return
      }
      when (attempt.phase) {
        "releasedAwaitingExplicitRetry" -> {
          current = null
          response.success()
        }
        "unconfirmedQuiescent" -> {
          attempt.closeFailure = false
          attempt.closeTimedOut = false
          attempt.phase = "closing"
          addStopReplyDeadlineLocked(attempt, response)
          requestCloseLocked(attempt)
        }
        "running" -> {
          addStopReplyDeadlineLocked(attempt, response)
          requestCloseLocked(attempt)
        }
        else -> response.error("capture_close_in_flight")
      }
    }
  }

  private fun addStopReplyDeadlineLocked(attempt: Attempt, response: ReplyGate) {
    attempt.stopReplies.add(response)
    dispatch.after(closeDeadlineMs) {
      synchronized(gate) {
        if (!response.pending) return@after
        response.error("capture_close_unconfirmed")
        attempt.closeTimedOut = true
        if (current === attempt && attempt.phase != "releasedAwaitingExplicitRetry") {
          attempt.phase = "unconfirmedInFlight"
        }
      }
    }
  }

  fun requestClose(owner: Any, id: String) = stop(owner, id, null)

  private fun requestClose(attempt: Attempt) = synchronized(gate) {
    requestCloseLocked(attempt)
  }

  private fun requestCloseLocked(attempt: Attempt) {
    if (current !== attempt) return
    if (!attempt.stopRequested) {
      attempt.stopRequested = true
      tombstones.add(attempt.id)
      ++generation
      attempt.output = null // fence queued chunks and detach old EventSink immediately.
      try { attempt.port?.unwatchRoute() } catch (_: Throwable) { attempt.closeFailure = true }
      attempt.startReply.error("capture_start_cancelled")
    }
    if (!attempt.closeDeadlineSet) {
      attempt.closeDeadlineSet = true
      dispatch.after(closeDeadlineMs) {
        synchronized(gate) {
          if (current !== attempt || attempt.phase == "releasedAwaitingExplicitRetry") return@after
          attempt.closeTimedOut = true
          attempt.phase = "unconfirmedInFlight"
        }
      }
    }
    if (!attempt.closeTimedOut) attempt.phase = "closing"
    else if (attempt.closeQueued || attempt.releaseStarted) attempt.phase = "unconfirmedInFlight"
    if (!attempt.closeQueued && !attempt.releaseStarted && !attempt.waitingReader) queueCloseLocked(attempt)
  }

  private fun queueCloseLocked(attempt: Attempt) {
    attempt.closeQueued = true
    dispatch.hardware { closeHardware(attempt) }
  }

  private fun closeHardware(attempt: Attempt) {
    val port = synchronized(gate) { attempt.port }
    if (port == null) {
      dispatch.main { finishRelease(attempt, released = true, failed = false) }
      return
    }
    var failed = false
    val shouldStop = synchronized(gate) {
      if (attempt.recordingStarted && !attempt.stopAttempted) {
        attempt.stopAttempted = true; true
      } else false
    }
    if (shouldStop) try { port.stop() } catch (_: Throwable) { failed = true }
    val reader = synchronized(gate) { attempt.reader }
    val exited = try { reader == null || reader.awaitExit(readExitBudgetMs) }
    catch (_: Throwable) { failed = true; false }
    if (!exited) {
      dispatch.main {
        synchronized(gate) {
          if (current !== attempt) return@synchronized
          attempt.closeFailure = attempt.closeFailure || failed
          attempt.closeQueued = false
          if (attempt.readerExited) {
            // The exit callback may have reached main before this timeout
            // callback. Queue the one release continuation instead of losing it.
            attempt.waitingReader = false
            queueCloseLocked(attempt)
          } else {
            attempt.waitingReader = true
            attempt.phase = "unconfirmedInFlight"
          }
        }
      }
      return
    }
    synchronized(gate) { attempt.releaseStarted = true }
    var releaseSucceeded = false
    try { port.release(); releaseSucceeded = true } catch (_: Throwable) { failed = true }
    dispatch.main { finishRelease(attempt, released = releaseSucceeded, failed = failed) }
  }

  private fun finishRelease(attempt: Attempt, released: Boolean, failed: Boolean) {
    synchronized(gate) {
      if (current !== attempt) return
      attempt.closeFailure = attempt.closeFailure || failed
      attempt.closeQueued = false
      attempt.releaseStarted = false
      if (!released) {
        attempt.phase = "unconfirmedQuiescent"
        drainStopReplies(attempt, false)
        return
      }
      attempt.port = null
      attempt.reader = null
      if (attempt.closeTimedOut || attempt.closeFailure) {
        attempt.phase = "releasedAwaitingExplicitRetry"
        drainStopReplies(attempt, false)
      } else {
        current = null
        drainStopReplies(attempt, true)
      }
    }
  }

  private fun drainStopReplies(attempt: Attempt, success: Boolean) {
    for (reply in attempt.stopReplies) {
      if (success) reply.success() else reply.error("capture_close_unconfirmed")
    }
    attempt.stopReplies.clear()
  }

  private fun onReaderExited(attempt: Attempt) {
    synchronized(gate) {
      attempt.readerExited = true
      attempt.waitingReader = false
      if (current === attempt && attempt.stopRequested && !attempt.closeQueued && !attempt.releaseStarted) {
        queueCloseLocked(attempt)
      }
    }
  }

  private fun isLive(attempt: Attempt): Boolean = synchronized(gate) { isLiveLocked(attempt) }
  private fun isLiveLocked(attempt: Attempt): Boolean =
    current === attempt && !attempt.stopRequested && generation == attempt.generation

  private fun validId(id: String): Boolean = id.length == 32 && id.all { it in '0'..'9' || it in 'a'..'f' }
}
