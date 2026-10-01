package com.yulalab.ostinato

import org.junit.Assert.*
import org.junit.Test
import java.util.ArrayDeque
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

private val defaultTestOwner = Any()

class AudioCaptureCloseTest {
  private val a = "a".repeat(32)
  private val b = "b".repeat(32)

  private class Result : AudioCaptureCoordinator.Reply {
    val calls = mutableListOf<String>()
    override fun success() { calls.add("ok") }
    override fun error(code: String) { calls.add(code) }
  }
  private class Output : AudioCaptureCoordinator.Output {
    val events = mutableListOf<Map<String, Any>>()
    override fun event(message: Map<String, Any>) { events.add(message) }
  }
  private class SlotBinding(
    private val machine: AudioCaptureCoordinator,
    private val id: String,
    private val owner: Any = defaultTestOwner,
  ) : AudioCaptureBinding {
    var retired = false
    var bound = true
    override fun retire() {
      if (retired) return
      retired = true
      closeBoundAttempt()
      machine.unbind(owner, id)
    }
    override fun closeBoundAttempt() {
      if (!bound) return
      bound = false
      machine.requestClose(owner, id)
    }
    fun retry(targetId: String = id): Result {
      val result = Result()
      if (retired) result.error("capture_handler_retired")
      else machine.retryStop(owner, targetId, result)
      return result
    }
  }
  private class Port : AudioCaptureCoordinator.RecorderPort {
    override val sampleRate = 44100
    var startCount = 0
    var startThrows = false
    var startEntered: CountDownLatch? = null
    var unblockStart: CountDownLatch? = null
    var stopCount = 0
    var releaseCount = 0
    var stopThrows = false
    var releaseThrows = false
    var releaseEntered: CountDownLatch? = null
    var unblockRelease: CountDownLatch? = null
    var routeCallback: (() -> Unit)? = null
    override fun start() {
      startCount++
      startEntered?.countDown()
      unblockStart?.await(3, TimeUnit.SECONDS)
      if (startThrows) throw IllegalStateException("start")
    }
    override fun read(buffer: ShortArray): Int = 0
    override fun stop() { stopCount++; if (stopThrows) throw IllegalStateException("stop") }
    override fun release() {
      releaseCount++
      releaseEntered?.countDown()
      unblockRelease?.await(3, TimeUnit.SECONDS)
      if (releaseThrows) throw IllegalStateException("release")
    }
    override fun route() = "android:TYPE_BUILTIN_MIC"
    override fun watchRoute(changed: () -> Unit) { routeCallback = changed }
    override fun unwatchRoute() { routeCallback = null }
  }
  private class Dispatch : AudioCaptureCoordinator.CaptureDispatch {
    val hardware = ArrayDeque<() -> Unit>()
    val mains = ArrayDeque<() -> Unit>()
    val timers = mutableListOf<Pair<Long, () -> Unit>>()
    val readers = mutableListOf<ReadJob>()
    var now = 0L
    override fun hardware(task: () -> Unit) { hardware.addLast(task) }
    override fun reader(task: () -> Unit): AudioCaptureCoordinator.ReadHandle {
      return ReadJob(task, this).also { readers.add(it) }
    }
    override fun main(task: () -> Unit) { mains.addLast(task) }
    override fun after(delayMs: Long, task: () -> Unit) { timers.add(now + delayMs to task) }
    fun hardwareOne() { hardware.removeFirst().invoke() }
    fun mainAll() { while (mains.isNotEmpty()) mains.removeFirst().invoke() }
    fun advance(ms: Long) {
      now += ms
      val due = timers.filter { it.first <= now }
      timers.removeAll(due.toSet())
      due.forEach { it.second.invoke() }
      mainAll()
    }
    class ReadJob(private val task: () -> Unit, private val dispatch: Dispatch) : AudioCaptureCoordinator.ReadHandle {
      var exited = true
      var onAwaitExit: (() -> Unit)? = null
      override fun awaitExit(timeoutMs: Long): Boolean {
        val observed = exited
        onAwaitExit?.invoke()
        return observed
      }
      fun queueExitBeforeTimeoutCallback() { exited = true; task() }
      fun finish() { exited = true; task(); dispatch.mainAll() }
    }
  }
  private fun coordinator(dispatch: Dispatch, port: Port) = AudioCaptureCoordinator(
    object : AudioCaptureCoordinator.RecorderFactory { override fun create(sampleRate: Int) = port }, dispatch,
  ).also { it.foreground(defaultTestOwner, true) }

  private fun AudioCaptureCoordinator.start(id: String, rate: Int, output: Output, reply: Result) {
    bind(defaultTestOwner, id)
    start(defaultTestOwner, id, rate, output, reply)
  }

  private fun AudioCaptureCoordinator.stop(id: String, reply: Result? = null) {
    if (isBound(defaultTestOwner, id)) stop(defaultTestOwner, id, reply)
    else stopBeforeListen(defaultTestOwner, id, reply)
  }

  private fun AudioCaptureCoordinator.retryStop(id: String, reply: Result) =
    retryStop(defaultTestOwner, id, reply)
  private fun running(dispatch: Dispatch, coordinator: AudioCaptureCoordinator,
                      id: String, output: Output = Output()): Result {
    val result = Result()
    coordinator.start(id, 44100, output, result)
    dispatch.hardwareOne(); dispatch.mainAll()
    assertEquals(listOf("ok"), result.calls)
    return result
  }

  @Test fun normalStopRequiresReleaseAndRepliesOnce() {
    val dispatch = Dispatch(); val port = Port(); val machine = coordinator(dispatch, port)
    running(dispatch, machine, a)
    val result = Result(); machine.stop(a, result)
    assertTrue(result.calls.isEmpty())
    assertEquals("closing", machine.closeState()["phase"])
    dispatch.hardwareOne(); dispatch.mainAll()
    assertEquals(1, port.stopCount)
    assertEquals(1, port.releaseCount)
    assertEquals(listOf("ok"), result.calls)
    assertEquals("clear", machine.closeState()["phase"])
    dispatch.advance(2_000)
    assertEquals(listOf("ok"), result.calls)
  }

  @Test fun stopBeforeDelayedCreateTombstonesIdAndNeverStartsRecorder() {
    val dispatch = Dispatch(); val port = Port(); val machine = coordinator(dispatch, port)
    val started = Result(); val stopped = Result()
    machine.start(a, 44100, Output(), started)
    machine.stop(a, stopped)
    assertEquals(listOf("capture_start_cancelled"), started.calls)
    assertTrue(stopped.calls.isEmpty())
    dispatch.hardwareOne(); dispatch.mainAll()
    dispatch.hardwareOne(); dispatch.mainAll()
    assertEquals(0, port.startCount)
    assertEquals(1, port.releaseCount)
    assertEquals(listOf("ok"), stopped.calls)
    val tombstoned = Result()
    machine.start(a, 44100, Output(), tombstoned)
    assertEquals(listOf("capture_close_unconfirmed"), tombstoned.calls)
  }

  @Test fun stopBeforeAnyStartVetoesLateStartForSameId() {
    val dispatch = Dispatch(); val port = Port(); val machine = coordinator(dispatch, port)
    val stopped = Result(); machine.stop(a, stopped)
    assertEquals(listOf("ok"), stopped.calls)
    val late = Result(); machine.start(a, 44100, Output(), late)
    assertEquals(listOf("capture_close_unconfirmed"), late.calls)
    assertEquals(0, dispatch.hardware.size)
    assertEquals(0, port.startCount)
  }

  @Test fun blockedStartDeadlineRetainsStickyLateReleaseUntilExplicitRetry() {
    val dispatch = Dispatch(); val port = Port(); val machine = coordinator(dispatch, port)
    val started = Result(); val stopped = Result()
    machine.start(a, 44100, Output(), started) // hardware queue held
    machine.stop(a, stopped)
    dispatch.advance(2_000)
    assertEquals(listOf("capture_start_cancelled"), started.calls)
    assertEquals(listOf("capture_close_unconfirmed"), stopped.calls)
    assertEquals("unconfirmedInFlight", machine.closeState()["phase"])
    dispatch.hardwareOne(); dispatch.mainAll()
    dispatch.hardwareOne(); dispatch.mainAll()
    assertEquals("releasedAwaitingExplicitRetry", machine.closeState()["phase"])
    assertEquals(0, port.startCount)
    val lateOrdinaryStop = Result(); machine.stop(a, lateOrdinaryStop)
    assertEquals(listOf("capture_close_unconfirmed"), lateOrdinaryStop.calls)
    assertEquals("releasedAwaitingExplicitRetry", machine.closeState()["phase"])
    val retry = Result(); machine.retryStop(a, retry)
    assertEquals(listOf("ok"), retry.calls)
    assertEquals("clear", machine.closeState()["phase"])
    running(dispatch, machine, b)
  }

  @Test fun stopReachesCoordinatorWhileRecorderStartIsBlocked() {
    val dispatch = Dispatch(); val port = Port()
    port.startEntered = CountDownLatch(1)
    port.unblockStart = CountDownLatch(1)
    val machine = coordinator(dispatch, port)
    val started = Result(); val stopped = Result()
    machine.start(a, 44100, Output(), started)
    val worker = Thread { dispatch.hardwareOne() }.apply { start() }
    assertTrue(port.startEntered!!.await(2, TimeUnit.SECONDS))
    machine.stop(a, stopped)
    assertEquals(listOf("capture_start_cancelled"), started.calls)
    assertEquals("closing", machine.closeState()["phase"])
    dispatch.advance(2_000)
    assertEquals(listOf("capture_close_unconfirmed"), stopped.calls)
    port.unblockStart!!.countDown(); worker.join(2_000); assertFalse(worker.isAlive)
    dispatch.mainAll()
    dispatch.hardwareOne(); dispatch.mainAll()
    assertEquals(1, port.startCount)
    assertEquals(1, port.releaseCount)
    assertEquals("releasedAwaitingExplicitRetry", machine.closeState()["phase"])
    assertEquals(1, started.calls.size)
  }

  @Test fun startFailureStillRetainsPortUntilRelease() {
    val dispatch = Dispatch(); val port = Port().apply { startThrows = true }
    val machine = coordinator(dispatch, port)
    val started = Result()
    machine.start(a, 44100, Output(), started)
    dispatch.hardwareOne(); dispatch.mainAll()
    assertEquals(listOf("setup_failed"), started.calls)
    assertEquals(0, port.releaseCount)
    dispatch.hardwareOne(); dispatch.mainAll()
    assertEquals(1, port.releaseCount)
    assertEquals("releasedAwaitingExplicitRetry", machine.closeState()["phase"])
  }

  @Test fun blockedReadAndStopThrowNeverClaimClose() {
    val dispatch = Dispatch(); val port = Port().apply { stopThrows = true }
    val machine = coordinator(dispatch, port)
    running(dispatch, machine, a)
    dispatch.readers.single().exited = false
    val result = Result(); machine.stop(a, result)
    dispatch.hardwareOne(); dispatch.mainAll()
    assertEquals(0, port.releaseCount)
    assertEquals("unconfirmedInFlight", machine.closeState()["phase"])
    dispatch.advance(2_000)
    assertEquals(listOf("capture_close_unconfirmed"), result.calls)
    val joined = Result(); machine.stop(a, joined)
    assertEquals(0, dispatch.hardware.size)
    dispatch.advance(2_000)
    assertEquals(listOf("capture_close_unconfirmed"), joined.calls)
    dispatch.readers.single().finish()
    dispatch.hardwareOne(); dispatch.mainAll()
    assertEquals(1, port.releaseCount)
    assertEquals("releasedAwaitingExplicitRetry", machine.closeState()["phase"])
  }

  @Test fun readExitQueuedBeforeCloseTimeoutStillSchedulesRelease() {
    val dispatch = Dispatch(); val port = Port(); val machine = coordinator(dispatch, port)
    running(dispatch, machine, a)
    val reader = dispatch.readers.single()
    reader.exited = false
    reader.onAwaitExit = { reader.queueExitBeforeTimeoutCallback() }
    val stopped = Result(); machine.stop(a, stopped)
    dispatch.hardwareOne()
    dispatch.mainAll() // exit notification precedes close timeout notification
    assertEquals(1, dispatch.hardware.size)
    dispatch.hardwareOne(); dispatch.mainAll()
    assertEquals(1, port.releaseCount)
    assertEquals(listOf("ok"), stopped.calls)
  }

  @Test fun failedReleaseRemainsQuiescentAndExplicitRetryCanClose() {
    val dispatch = Dispatch(); val port = Port().apply { releaseThrows = true }
    val machine = coordinator(dispatch, port)
    running(dispatch, machine, a)
    val failed = Result(); machine.stop(a, failed)
    dispatch.hardwareOne(); dispatch.mainAll()
    assertEquals(listOf("capture_close_unconfirmed"), failed.calls)
    assertEquals("unconfirmedQuiescent", machine.closeState()["phase"])
    port.releaseThrows = false
    val lateOrdinaryStop = Result(); machine.stop(a, lateOrdinaryStop)
    assertEquals(listOf("capture_close_unconfirmed"), lateOrdinaryStop.calls)
    assertEquals(1, port.releaseCount)
    val retry = Result(); machine.retryStop(a, retry)
    dispatch.hardwareOne(); dispatch.mainAll()
    assertEquals(listOf("ok"), retry.calls)
    assertEquals(2, port.releaseCount)
    assertEquals("clear", machine.closeState()["phase"])
  }

  @Test fun twoStopsJoinOneBlockedReleaseAndEachReplyExactlyOnce() {
    val dispatch = Dispatch(); val port = Port()
    port.releaseEntered = CountDownLatch(1)
    port.unblockRelease = CountDownLatch(1)
    val machine = coordinator(dispatch, port)
    running(dispatch, machine, a)
    val first = Result(); val second = Result()
    machine.stop(a, first); machine.stop(a, second)
    assertEquals(1, dispatch.hardware.size)
    val worker = Thread { dispatch.hardwareOne() }.apply { start() }
    assertTrue(port.releaseEntered!!.await(2, TimeUnit.SECONDS))
    dispatch.advance(2_000)
    assertEquals(listOf("capture_close_unconfirmed"), first.calls)
    assertEquals(listOf("capture_close_unconfirmed"), second.calls)
    assertEquals("unconfirmedInFlight", machine.closeState()["phase"])
    val prematureRetry = Result(); machine.retryStop(a, prematureRetry)
    assertEquals(listOf("capture_close_in_flight"), prematureRetry.calls)
    port.unblockRelease!!.countDown(); worker.join(2_000); assertFalse(worker.isAlive)
    dispatch.mainAll()
    assertEquals(1, port.releaseCount)
    assertEquals("releasedAwaitingExplicitRetry", machine.closeState()["phase"])
    assertEquals(1, first.calls.size); assertEquals(1, second.calls.size)
  }

  @Test fun oldIdCloseCannotStopNewAttemptAndOldRouteCannotEmit() {
    val dispatch = Dispatch(); val port = Port(); val machine = coordinator(dispatch, port)
    val oldOutput = Output(); running(dispatch, machine, a, oldOutput)
    val oldEventCount = oldOutput.events.size
    val oldRoute = port.routeCallback
    machine.stop(a, Result()); dispatch.hardwareOne(); dispatch.mainAll()
    val freshMachine = machine // same process coordinator; factory below uses same fake port
    running(dispatch, freshMachine, b)
    val stopCount = port.stopCount
    oldRoute?.invoke(); dispatch.mainAll()
    machine.stop(a, Result())
    assertEquals(stopCount, port.stopCount)
    assertEquals("running", machine.closeState()["phase"])
    assertEquals(b, machine.closeState()["attemptId"])
    assertEquals(oldEventCount, oldOutput.events.size)
  }

  @Test fun sameActivitySlotFencesOldAttemptBeforeNewRegistrationAndIgnoresLateCleanup() {
    val dispatch = Dispatch(); val port = Port(); val machine = coordinator(dispatch, port)
    val slot = AudioCaptureHandlerSlot()
    val oldEngine = Any(); val newEngine = Any()
    val old = SlotBinding(machine, a)
    slot.replace(oldEngine, old) { assertEquals("clear", machine.closeState()["phase"]) }
    val oldOutput = Output(); running(dispatch, machine, a, oldOutput)
    val oldEvents = oldOutput.events.size
    val oldRoute = port.routeCallback

    val fresh = SlotBinding(machine, b)
    slot.replace(newEngine, fresh) {
      assertTrue(old.retired)
      assertEquals("closing", machine.closeState()["phase"])
      assertEquals(1, dispatch.hardware.size)
      assertEquals(listOf("capture_handler_retired"), old.retry().calls)
    }
    slot.retireIfEngine(oldEngine)
    assertFalse(fresh.retired)
    val blocked = Result(); machine.start(b, 44100, Output(), blocked)
    assertEquals(listOf("capture_close_unconfirmed"), blocked.calls)
    assertEquals(1, dispatch.hardware.size)
    oldRoute?.invoke(); dispatch.mainAll()
    assertEquals(oldEvents, oldOutput.events.size)

    dispatch.hardwareOne(); dispatch.mainAll()
    assertEquals(1, port.stopCount)
    assertEquals(1, port.releaseCount)
    assertEquals("clear", machine.closeState()["phase"])
    assertEquals(1, port.startCount) // No B auto-start during replacement.
    running(dispatch, machine, b)
    assertEquals(2, port.startCount)
    slot.retireIfEngine(newEngine)
    assertTrue(fresh.retired)
  }

  @Test fun cancelIdIsBoundToItsOwnHandlerAndImplicitCancelUsesOldBinding() {
    assertNull(boundCancelId(a, b))
    assertEquals(a, boundCancelId(a, null))
    assertEquals(a, boundCancelId(a, a))
    assertNull(boundCancelId(null, b))
    val ids = AudioCaptureBoundIds()
    ids.bind(a)
    assertEquals(a, ids.cancel(null))
    assertNull(ids.current)
    assertTrue(ids.owns(a)) // An explicit retry remains possible after cancel.
    assertFalse(ids.owns(b))
    assertEquals(setOf(a), ids.retire())
    assertFalse(ids.owns(a))
  }

  @Test fun staleActivityMessengerCannotStopNewActivityAttempt() {
    val dispatch = Dispatch(); val port = Port(); val machine = coordinator(dispatch, port)
    val ownerA = Any(); val ownerB = Any()
    val activityA = AudioCaptureHandlerSlot(); val activityB = AudioCaptureHandlerSlot()
    val idsA = AudioCaptureBoundIds(); val idsB = AudioCaptureBoundIds()
    val engineA = Any(); val engineB = Any()
    activityA.replace(engineA, SlotBinding(machine, a, ownerA)) {}
    machine.foreground(ownerA, true)
    assertTrue(machine.bind(ownerA, a))
    idsA.bind(a)
    val aStarted = Result()
    machine.start(ownerA, a, 44100, Output(), aStarted)
    dispatch.hardwareOne(); dispatch.mainAll()
    assertEquals(listOf("ok"), aStarted.calls)
    assertEquals(a, idsA.closeBound())
    activityA.closeCurrent(); dispatch.hardwareOne(); dispatch.mainAll()
    machine.foreground(ownerA, false)
    activityB.replace(engineB, SlotBinding(machine, b, ownerB)) {}
    machine.foreground(ownerB, true)
    assertTrue(machine.bind(ownerB, b))
    idsB.bind(b)
    val bStarted = Result()
    machine.start(ownerB, b, 44100, Output(), bStarted)
    dispatch.hardwareOne(); dispatch.mainAll()
    assertEquals(listOf("ok"), bStarted.calls)
    val stopCount = port.stopCount

    // The old MethodChannel can still read this process-wide snapshot. It
    // cannot turn the visible ID into a binding or a close capability.
    val bIdVisibleToA = machine.closeState()["attemptId"] as String
    assertFalse(machine.bind(ownerA, bIdVisibleToA)) // stale onListen(B)
    assertFalse(idsA.owns(bIdVisibleToA))
    assertTrue(idsB.owns(bIdVisibleToA))
    val unboundStop = Result()
    if (idsA.owns(bIdVisibleToA)) machine.stop(ownerA, bIdVisibleToA, unboundStop)
    else machine.stopBeforeListen(ownerA, bIdVisibleToA, unboundStop)
    assertEquals(listOf("not_foreground_or_permitted"), unboundStop.calls)
    val foreignStop = Result(); machine.stop(ownerA, bIdVisibleToA, foreignStop)
    assertEquals(listOf("capture_close_unconfirmed"), foreignStop.calls)
    val foreignRetry = Result(); machine.retryStop(ownerA, bIdVisibleToA, foreignRetry)
    assertEquals(listOf("not_foreground_or_permitted"), foreignRetry.calls)
    assertEquals(b, machine.closeState()["attemptId"])
    assertEquals("running", machine.closeState()["phase"])
    assertEquals(stopCount, port.stopCount)
    assertTrue(dispatch.hardware.isEmpty())
  }

  @Test fun stopBeforeListenOnlyCurrentForegroundOwnerCanTombstone() {
    val dispatch = Dispatch(); val port = Port(); val machine = coordinator(dispatch, port)
    val ownerA = Any(); val ownerB = Any()
    machine.foreground(ownerA, true)
    machine.foreground(ownerA, false)
    machine.foreground(ownerB, true)
    val stale = Result(); machine.stopBeforeListen(ownerA, a, stale)
    assertEquals(listOf("not_foreground_or_permitted"), stale.calls)
    assertFalse(machine.bind(ownerA, a))
    val current = Result(); machine.stopBeforeListen(ownerB, b, current)
    assertEquals(listOf("ok"), current.calls)
    assertFalse(machine.bind(ownerB, b))
    val late = Result(); machine.start(ownerB, b, 44100, Output(), late)
    assertEquals(listOf("capture_close_unconfirmed"), late.calls)
    assertTrue(dispatch.hardware.isEmpty())
  }

  @Test fun currentActivityRecoversRetiredActivityReleasedStickyOnlyByExplicitRetry() {
    val dispatch = Dispatch(); val port = Port(); val machine = coordinator(dispatch, port)
    val ownerA = Any(); val ownerB = Any()
    machine.foreground(ownerA, true)
    assertTrue(machine.bind(ownerA, a))
    val aStart = Result(); machine.start(ownerA, a, 44100, Output(), aStart)
    dispatch.hardwareOne(); dispatch.mainAll()
    assertEquals(listOf("ok"), aStart.calls)
    val aStop = Result(); machine.stop(ownerA, a, aStop)
    dispatch.advance(2_000) // Reply times out; the hardware close is still queued.
    assertEquals(listOf("capture_close_unconfirmed"), aStop.calls)
    dispatch.hardwareOne(); dispatch.mainAll()
    assertEquals("releasedAwaitingExplicitRetry", machine.closeState()["phase"])
    val releaseCount = port.releaseCount
    machine.unbind(ownerA, a) // Old engine/Activity handler retired.
    machine.foreground(ownerA, false)
    machine.foreground(ownerB, true)

    val bRetry = Result(); machine.retryStop(ownerB, a, bRetry)
    assertEquals(listOf("ok"), bRetry.calls)
    assertEquals("clear", machine.closeState()["phase"])
    assertEquals(releaseCount, port.releaseCount) // Ack, never a second release.
    assertTrue(dispatch.hardware.isEmpty())
    assertTrue(machine.bind(ownerB, b))
    val bStart = Result(); machine.start(ownerB, b, 44100, Output(), bStart)
    dispatch.hardwareOne(); dispatch.mainAll()
    assertEquals(listOf("ok"), bStart.calls)
  }

  @Test fun replacementEngineWithSameActivityOwnerCanAcknowledgeRetiredStickyClose() {
    val dispatch = Dispatch(); val port = Port(); val machine = coordinator(dispatch, port)
    val owner = Any(); val slot = AudioCaptureHandlerSlot()
    machine.foreground(owner, true)
    val old = SlotBinding(machine, a, owner)
    slot.replace(Any(), old) {}
    assertTrue(machine.bind(owner, a))
    val started = Result(); machine.start(owner, a, 44100, Output(), started)
    dispatch.hardwareOne(); dispatch.mainAll()
    val stopped = Result(); machine.stop(owner, a, stopped)
    dispatch.advance(2_000)
    dispatch.hardwareOne(); dispatch.mainAll()
    assertEquals("releasedAwaitingExplicitRetry", machine.closeState()["phase"])
    slot.replace(Any(), SlotBinding(machine, b, owner)) {}
    assertTrue(old.retired)
    assertFalse(machine.isBound(owner, a)) // Real engine retirement unbinds A.
    assertEquals(listOf("capture_handler_retired"), old.retry().calls)

    val newHandlerRetry = Result(); machine.retryStop(owner, a, newHandlerRetry)
    assertEquals(listOf("ok"), newHandlerRetry.calls)
    assertEquals("clear", machine.closeState()["phase"])
    assertEquals(1, port.releaseCount)
  }

  @Test fun stickyIdSurvivesTwoEngineReplacementsUntilCurrentHandlerRetries() {
    val dispatch = Dispatch(); val port = Port(); val machine = coordinator(dispatch, port)
    val owner = Any(); val slot = AudioCaptureHandlerSlot(); val c = "c".repeat(32)
    val first = SlotBinding(machine, a, owner)
    val middle = SlotBinding(machine, b, owner)
    val current = SlotBinding(machine, c, owner)
    machine.foreground(owner, true)
    slot.replace(Any(), first) {}
    assertTrue(machine.bind(owner, a))
    val started = Result(); machine.start(owner, a, 44100, Output(), started)
    dispatch.hardwareOne(); dispatch.mainAll()
    assertEquals(listOf("ok"), started.calls)

    val stopped = Result(); machine.stop(owner, a, stopped)
    dispatch.advance(2_000)
    dispatch.hardwareOne(); dispatch.mainAll()
    assertEquals(listOf("capture_close_unconfirmed"), stopped.calls)
    assertEquals("releasedAwaitingExplicitRetry", machine.closeState()["phase"])
    val releases = port.releaseCount

    slot.replace(Any(), middle) {}
    assertTrue(first.retired)
    assertFalse(machine.isBound(owner, a))
    assertEquals(a, machine.closeState()["attemptId"])
    assertTrue(machine.bind(owner, b))
    val middleStart = Result(); machine.start(owner, b, 44100, Output(), middleStart)
    assertEquals(listOf("capture_close_unconfirmed"), middleStart.calls)
    slot.replace(Any(), current) {}
    assertTrue(middle.retired)
    assertFalse(machine.isBound(owner, b))
    assertEquals(listOf("capture_handler_retired"), first.retry(a).calls)
    assertEquals(listOf("capture_handler_retired"), middle.retry(a).calls)
    assertEquals("releasedAwaitingExplicitRetry", machine.closeState()["phase"])
    assertEquals(a, machine.closeState()["attemptId"])
    assertEquals(releases, port.releaseCount)

    assertTrue(machine.bind(owner, c))
    val premature = Result(); machine.start(owner, c, 44100, Output(), premature)
    assertEquals(listOf("capture_close_unconfirmed"), premature.calls)
    assertEquals(1, port.startCount)
    assertEquals(listOf("ok"), current.retry(a).calls)
    assertEquals("clear", machine.closeState()["phase"])
    assertEquals(releases, port.releaseCount) // Released A needs acknowledgement only.
    val cStart = Result(); machine.start(owner, c, 44100, Output(), cStart)
    dispatch.hardwareOne(); dispatch.mainAll()
    assertEquals(listOf("ok"), cStart.calls)
    assertEquals(2, port.startCount) // C starts only after its separate call.
    val late = current.retry(a)
    assertEquals(listOf("capture_close_unconfirmed"), late.calls)
    assertEquals("running", machine.closeState()["phase"])
    assertEquals(c, machine.closeState()["attemptId"])
  }

  @Test fun newForegroundOwnerRetriesQuiescentFailedReleaseOnce() {
    val dispatch = Dispatch(); val port = Port().apply { releaseThrows = true }
    val machine = coordinator(dispatch, port)
    val ownerA = Any(); val ownerB = Any()
    machine.foreground(ownerA, true)
    assertTrue(machine.bind(ownerA, a))
    val started = Result(); machine.start(ownerA, a, 44100, Output(), started)
    dispatch.hardwareOne(); dispatch.mainAll()
    val stopped = Result(); machine.stop(ownerA, a, stopped)
    dispatch.hardwareOne(); dispatch.mainAll()
    assertEquals("unconfirmedQuiescent", machine.closeState()["phase"])
    assertEquals(1, port.releaseCount)
    machine.unbind(ownerA, a)
    machine.foreground(ownerA, false)
    machine.foreground(ownerB, true)
    port.releaseThrows = false

    val retry = Result(); machine.retryStop(ownerB, a, retry)
    assertTrue(retry.calls.isEmpty())
    assertEquals(1, dispatch.hardware.size)
    val duplicate = Result(); machine.retryStop(ownerB, a, duplicate)
    assertEquals(listOf("capture_close_unconfirmed"), duplicate.calls)
    assertEquals(1, dispatch.hardware.size)
    dispatch.hardwareOne(); dispatch.mainAll()
    assertEquals(listOf("ok"), retry.calls)
    assertEquals(2, port.releaseCount)
    assertEquals("clear", machine.closeState()["phase"])
  }

  @Test fun unboundRecoveryNeverStopsRunningOrInFlightForeignAttempt() {
    val dispatch = Dispatch(); val port = Port(); val machine = coordinator(dispatch, port)
    val ownerA = Any(); val ownerB = Any()
    machine.foreground(ownerA, true)
    assertTrue(machine.bind(ownerA, a))
    val started = Result(); machine.start(ownerA, a, 44100, Output(), started)
    dispatch.hardwareOne(); dispatch.mainAll()
    machine.foreground(ownerB, true)
    val runningRetry = Result(); machine.retryStop(ownerB, a, runningRetry)
    assertEquals(listOf("capture_close_unconfirmed"), runningRetry.calls)
    assertEquals("running", machine.closeState()["phase"])
    assertEquals(0, port.stopCount)
    assertTrue(dispatch.hardware.isEmpty())

    machine.stop(ownerA, a) // Lifecycle close remains allowed for A's own attempt.
    dispatch.advance(2_000)
    assertEquals("unconfirmedInFlight", machine.closeState()["phase"])
    val queued = dispatch.hardware.size
    val inFlightRetry = Result(); machine.retryStop(ownerB, a, inFlightRetry)
    assertEquals(listOf("capture_close_unconfirmed"), inFlightRetry.calls)
    assertEquals(queued, dispatch.hardware.size)
    val oldOwnerRetry = Result(); machine.retryStop(ownerA, a, oldOwnerRetry)
    assertEquals(listOf("not_foreground_or_permitted"), oldOwnerRetry.calls)
    dispatch.hardwareOne(); dispatch.mainAll()
    assertEquals("releasedAwaitingExplicitRetry", machine.closeState()["phase"])
    machine.foreground(ownerB, false)
    val backgroundRetry = Result(); machine.retryStop(ownerB, a, backgroundRetry)
    assertEquals(listOf("not_foreground_or_permitted"), backgroundRetry.calls)
  }

  @Test fun knownClearTombstoneAcknowledgesOnlyWithoutAnotherLiveAttempt() {
    val dispatch = Dispatch(); val port = Port(); val machine = coordinator(dispatch, port)
    val ownerA = Any(); val ownerB = Any(); val c = "c".repeat(32)
    machine.foreground(ownerA, true)
    val veto = Result(); machine.stopBeforeListen(ownerA, a, veto)
    assertEquals(listOf("ok"), veto.calls)
    machine.foreground(ownerA, false)
    machine.foreground(ownerB, true)
    val unknown = Result(); machine.retryStop(ownerB, c, unknown)
    assertEquals(listOf("capture_close_unconfirmed"), unknown.calls)
    val known = Result(); machine.retryStop(ownerB, a, known)
    assertEquals(listOf("ok"), known.calls)
    assertTrue(dispatch.hardware.isEmpty())
    assertTrue(machine.bind(ownerB, b))
    val started = Result(); machine.start(ownerB, b, 44100, Output(), started)
    dispatch.hardwareOne(); dispatch.mainAll()
    val stopCount = port.stopCount
    val late = Result(); machine.retryStop(ownerB, a, late)
    assertEquals(listOf("capture_close_unconfirmed"), late.calls)
    assertEquals("running", machine.closeState()["phase"])
    assertEquals(stopCount, port.stopCount)
  }
}
