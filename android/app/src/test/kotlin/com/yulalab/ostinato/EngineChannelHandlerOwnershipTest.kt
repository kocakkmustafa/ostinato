package com.yulalab.ostinato

import org.junit.Assert.*
import org.junit.Test

class EngineChannelHandlerOwnershipTest {
  private class FakeMessenger {
    var captureMethod: Any? = null
    var captureEvent: Any? = null
    var arbiterMethod: Any? = null
    var clears = 0

    fun has(owner: Any): Boolean =
      captureMethod === owner && captureEvent === owner && arbiterMethod === owner
  }

  private class FakeBinding(
    private val owners: EngineChannelHandlerOwnership,
    private val engine: Any,
    private val messenger: FakeMessenger,
    private val activityEpoch: Any,
  ) : AudioCaptureBinding {
    var retired = false
      private set
    var closedAttempts = 0
      private set
    private var claim: EngineChannelHandlerOwnership.Claim? = null

    fun register(): Boolean {
      val acquisition = owners.claim(engine, messenger, activityEpoch) { retire() }
      claim = acquisition.claim
      acquisition.retirePrevious()
      return owners.installIfCurrent(acquisition.claim) {
        check(!retired)
        messenger.captureMethod = this
        messenger.captureEvent = this
        messenger.arbiterMethod = this
      }
    }

    override fun closeBoundAttempt() { closedAttempts++ }

    override fun retire() {
      if (retired) return
      retired = true
      claim?.let {
        owners.clearIfMessengerUncontested(it) {
          messenger.captureMethod = null
          messenger.captureEvent = null
          messenger.arbiterMethod = null
          messenger.clears++
        }
      }
    }
  }

  @Test fun cachedEngineAtoBAndLateAOnDestroyCannotRemoveBHandlers() {
    val owners = EngineChannelHandlerOwnership()
    val engine = Any()
    val messenger = FakeMessenger()
    val activityA = AudioCaptureHandlerSlot()
    val activityB = AudioCaptureHandlerSlot()
    val a = FakeBinding(owners, engine, messenger, Any())
    val b = FakeBinding(owners, engine, messenger, Any())

    activityA.replace(engine, a) { assertTrue(a.register()) }
    assertTrue(messenger.has(a))
    activityB.replace(engine, b) {
      assertTrue(b.register())
      assertTrue(a.retired)
    }
    assertTrue(messenger.has(b))
    assertEquals(0, messenger.clears)

    activityA.retireCurrent() // A.onDestroy
    activityA.retireIfEngine(engine) // A.cleanUpFlutterEngine, either order
    assertTrue(messenger.has(b))
    assertEquals(0, messenger.clears)

    activityB.retireIfEngine(engine)
    assertNull(messenger.captureMethod)
    assertNull(messenger.captureEvent)
    assertNull(messenger.arbiterMethod)
    assertEquals(1, messenger.clears)
  }

  @Test fun lateACleanupBeforeOnDestroyAlsoPreservesBHandlers() {
    val owners = EngineChannelHandlerOwnership()
    val engine = Any()
    val messenger = FakeMessenger()
    val activityA = AudioCaptureHandlerSlot()
    val activityB = AudioCaptureHandlerSlot()
    val a = FakeBinding(owners, engine, messenger, Any())
    val b = FakeBinding(owners, engine, messenger, Any())
    activityA.replace(engine, a) { assertTrue(a.register()) }
    activityB.replace(engine, b) { assertTrue(b.register()) }

    activityA.retireIfEngine(engine) // A.cleanUpFlutterEngine
    activityA.retireCurrent() // A.onDestroy
    assertTrue(messenger.has(b))
    assertEquals(0, messenger.clears)
  }

  @Test fun changedMessengerRetiresAndClearsAbandonedOldMessenger() {
    val owners = EngineChannelHandlerOwnership()
    val engine = Any()
    val firstMessenger = FakeMessenger()
    val nextMessenger = FakeMessenger()
    val a = FakeBinding(owners, engine, firstMessenger, Any())
    val b = FakeBinding(owners, engine, nextMessenger, Any())
    assertTrue(a.register())
    assertTrue(b.register())
    assertTrue(a.retired)
    assertNull(firstMessenger.captureMethod)
    assertNull(firstMessenger.captureEvent)
    assertNull(firstMessenger.arbiterMethod)
    assertEquals(1, firstMessenger.clears)
    assertTrue(nextMessenger.has(b))
  }

  @Test fun foreignEngineOnSameMessengerCannotBeClearedByOldClaim() {
    val owners = EngineChannelHandlerOwnership()
    val messenger = FakeMessenger()
    val a = FakeBinding(owners, Any(), messenger, Any())
    val b = FakeBinding(owners, Any(), messenger, Any())
    assertTrue(a.register())
    assertTrue(b.register())
    a.retire()
    assertTrue(messenger.has(b))
    assertEquals(0, messenger.clears)
  }

  @Test fun supersededClaimCannotPublishOrClearForeignActivityHandlers() {
    val owners = EngineChannelHandlerOwnership()
    val engine = Any()
    val messenger = FakeMessenger()
    val a = owners.claim(engine, messenger, Any()) {}
    val b = owners.claim(engine, messenger, Any()) {}
    assertFalse(owners.isCurrent(a.claim))
    assertTrue(owners.isCurrent(b.claim))
    assertFalse(owners.installIfCurrent(a.claim) { fail("A published after B") })
    assertTrue(owners.installIfCurrent(b.claim) {
      messenger.captureMethod = b.claim
      messenger.captureEvent = b.claim
      messenger.arbiterMethod = b.claim
    })
    assertFalse(owners.clearIfMessengerUncontested(a.claim) {
      fail("A cleared B's messenger")
    })
    assertTrue(messenger.has(b.claim))
    assertTrue(owners.clearIfMessengerUncontested(b.claim) {
      messenger.captureMethod = null
      messenger.captureEvent = null
      messenger.arbiterMethod = null
    })
  }

  @Test fun failedPartialInstallClearsOnlyItsOwnHandlersBeforeReplacement() {
    val owners = EngineChannelHandlerOwnership()
    val engine = Any()
    val messenger = FakeMessenger()
    val a = owners.claim(engine, messenger, Any()) {}
    try {
      owners.installIfCurrent(a.claim) {
        messenger.captureMethod = a.claim
        throw IllegalStateException("fake event registration failure")
      }
      fail("partial registration should throw")
    } catch (expected: IllegalStateException) {
      assertEquals("fake event registration failure", expected.message)
    }
    assertTrue(owners.clearIfMessengerUncontested(a.claim) {
      messenger.captureMethod = null
      messenger.captureEvent = null
      messenger.arbiterMethod = null
    })

    val b = owners.claim(engine, messenger, Any()) {}
    assertTrue(owners.installIfCurrent(b.claim) {
      messenger.captureMethod = b.claim
      messenger.captureEvent = b.claim
      messenger.arbiterMethod = b.claim
    })
    assertFalse(owners.clearIfMessengerUncontested(a.claim) {
      fail("failed A registration cleared B")
    })
    assertTrue(messenger.has(b.claim))
  }
}
