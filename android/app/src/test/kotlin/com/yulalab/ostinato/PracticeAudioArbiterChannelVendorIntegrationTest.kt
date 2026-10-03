package com.yulalab.ostinato

import android.content.Context
import android.util.LongSparseArray
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.PluginRegistry
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformViewFactory
import io.flutter.plugin.platform.PlatformViewRegistry
import io.flutter.plugins.videoplayer.CreationOptions
import io.flutter.plugins.videoplayer.VideoAsset
import io.flutter.plugins.videoplayer.VideoPermitBridge
import io.flutter.plugins.videoplayer.VideoPermitMessage
import io.flutter.plugins.videoplayer.VideoPlayerCallbacks
import io.flutter.plugins.videoplayer.VideoPlayerOptions
import io.flutter.plugins.videoplayer.VideoPlayerPlugin
import io.flutter.plugins.videoplayer.platformview.PlatformViewVideoPlayer
import io.flutter.view.TextureRegistry
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.Mockito
import org.robolectric.RobolectricTestRunner
import java.util.ArrayDeque

/** The FlutterEngine shell is mocked; the app channel, bridge, and vendor plugin are real. */
@RunWith(RobolectricTestRunner::class)
class PracticeAudioArbiterChannelVendorIntegrationTest {
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
  }

  private class ChannelResult : MethodChannel.Result {
    val successes = mutableListOf<Any?>()
    val errors = mutableListOf<String>()
    var notImplemented = 0

    override fun success(result: Any?) { successes += result }
    override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
      errors += errorCode
    }
    override fun notImplemented() { notImplemented++ }
  }

  private class Harness {
    val messenger = Mockito.mock(BinaryMessenger::class.java)
    val plugin = Mockito.spy(VideoPlayerPlugin())
    val engine = Mockito.mock(FlutterEngine::class.java)
    val work = QueueWork()
    val arbiter = PracticeAudioArbiter(work,
      videoReservationEnabled = true, videoCloseDispatcher = work)

    init {
      val pluginBinding = Mockito.mock(FlutterPlugin.FlutterPluginBinding::class.java)
      val registry = Mockito.mock(PluginRegistry::class.java)
      val executor = Mockito.mock(DartExecutor::class.java)
      val platformViews = Mockito.mock(PlatformViewRegistry::class.java)
      Mockito.`when`(pluginBinding.applicationContext)
        .thenReturn(Mockito.mock(Context::class.java))
      Mockito.`when`(pluginBinding.textureRegistry)
        .thenReturn(Mockito.mock(TextureRegistry::class.java))
      Mockito.`when`(pluginBinding.binaryMessenger).thenReturn(messenger)
      Mockito.`when`(pluginBinding.platformViewRegistry).thenReturn(platformViews)
      Mockito.`when`(platformViews.registerViewFactory(
        Mockito.anyString(), Mockito.any(PlatformViewFactory::class.java))).thenReturn(true)
      Mockito.`when`(engine.plugins).thenReturn(registry)
      Mockito.`when`(registry.get(VideoPlayerPlugin::class.java)).thenReturn(plugin)
      Mockito.`when`(engine.dartExecutor).thenReturn(executor)
      Mockito.`when`(executor.binaryMessenger).thenReturn(messenger)
      plugin.onAttachedToEngine(pluginBinding)
    }

    fun bind(onEngine: Any = engine): PracticeAudioArbiter.Binding =
      arbiter.registerEngine(Any(), onEngine).also { arbiter.foreground(it, true) }

    fun state(owner: PracticeAudioArbiter.Binding): Map<String, Any?> =
      arbiter.readAllAudioState(owner, owner.ownerToken, owner.engineGeneration)

    fun bridge(): VideoPermitBridge {
      val field = VideoPlayerPlugin::class.java.getDeclaredField("permitBridge")
      field.isAccessible = true
      return field.get(plugin) as VideoPermitBridge
    }

    fun nativeCount(fieldName: String): Int {
      val field = VideoPlayerPlugin::class.java.getDeclaredField(fieldName)
      field.isAccessible = true
      return (field.get(plugin) as LongSparseArray<*>).size()
    }

    fun callRebind(
      current: PracticeAudioArbiter.Binding,
      retired: PracticeAudioArbiter.Binding,
    ): ChannelResult = ChannelResult().also { reply ->
      PracticeAudioArbiterChannel(arbiter, current).onMethodCall(
        MethodCall("rebindQuiescentOwner", mapOf(
          "retiredOwnerToken" to retired.ownerToken,
          "retiredEngineGeneration" to retired.engineGeneration,
          "reason" to "userRetry",
        )), reply)
    }
  }

  private fun options(owner: PracticeAudioArbiter.Binding,
                      context: Long, leaseId: String, leaseGeneration: Long) =
    CreationOptions(
      uri = "/tmp/lesson.mp4",
      httpHeaders = emptyMap(),
      permit = VideoPermitMessage(owner.ownerToken, owner.engineGeneration,
        context, leaseId, leaseGeneration),
      mixWithOthers = false,
    )

  private fun expectIllegalState(block: () -> Unit) {
    try {
      block()
      fail("expected IllegalStateException")
    } catch (_: IllegalStateException) {
      // The vendor must reject before any native player construction.
    }
  }

  @Test fun foreignReceiptRejectsOldCapturedBridgeBeforeChannelAck() {
    val h = Harness()
    val yOwner = h.bind()
    assertEquals(VendorVideoPermitBridge.InstallResult.INSTALLED,
      VendorVideoPermitBridge.installForEngine(h.engine, yOwner, h.arbiter))
    val oldBridge = h.bridge()
    val yContext = h.state(yOwner)["contextGeneration"] as Long
    val yId = "a".repeat(32)
    val yReservation = h.arbiter.reserve(yOwner, yOwner.ownerToken,
      yOwner.engineGeneration, yContext, yId, "video")
    val yGeneration = yReservation["leaseGeneration"] as Long
    val yOptions = options(yOwner, yContext, yId, yGeneration)
    val player = Mockito.mock(PlatformViewVideoPlayer::class.java)
    val playerFactory = Mockito.mockStatic(PlatformViewVideoPlayer::class.java)
    val yPlayerId = try {
      playerFactory.`when`<PlatformViewVideoPlayer> {
        PlatformViewVideoPlayer.create(
          Mockito.any(Context::class.java),
          Mockito.any(VideoPlayerCallbacks::class.java),
          Mockito.any(VideoAsset::class.java),
          Mockito.any(VideoPlayerOptions::class.java),
          Mockito.any(Runnable::class.java),
        )
      }.thenReturn(player)
      val id = h.plugin.createForPlatformView(yOptions)
      h.plugin.dispose(id)
      id
    } finally {
      playerFactory.close()
    }
    Mockito.verify(player).dispose()
    assertEquals("closed", h.arbiter.completeVideoDispose(yOwner,
      yOwner.ownerToken, yOwner.engineGeneration, yContext,
      yId, yGeneration, true)["status"])
    assertTrue(oldBridge.isQuiescentForRebind())
    assertEquals(0, h.nativeCount("videoPlayers"))
    assertEquals(0, h.nativeCount("permitRecords"))

    // A different engine completes X. This replaces the global Y receipt,
    // while the original E2 vendor bridge still holds the exact Y claim.
    val xOwner = h.bind(Any())
    val xContext = h.state(xOwner)["contextGeneration"] as Long
    val xId = "b".repeat(32)
    val xReservation = h.arbiter.reserve(xOwner, xOwner.ownerToken,
      xOwner.engineGeneration, xContext, xId, "video")
    val xGeneration = xReservation["leaseGeneration"] as Long
    val xPlayerId = yPlayerId + 1
    val xClaim = PracticeAudioArbiter.VideoPlayerClaim(xOwner,
      xOwner.ownerToken, xOwner.engineGeneration, xContext,
      xId, xGeneration, xPlayerId)
    assertTrue(h.arbiter.withClaimedVideoCreation(xOwner,
      xOwner.ownerToken, xOwner.engineGeneration, xContext,
      xId, xGeneration, xPlayerId,
      PracticeAudioArbiter.VideoClosePort(xClaim) { true }) {})
    assertTrue(h.arbiter.releaseVideoPlayer(xOwner,
      xOwner.ownerToken, xOwner.engineGeneration, xContext,
      xId, xGeneration, xPlayerId))
    assertEquals("closed", h.arbiter.completeVideoDispose(xOwner,
      xOwner.ownerToken, xOwner.engineGeneration, xContext,
      xId, xGeneration, true)["status"])
    assertFalse(oldBridge.isQuiescentForRebind())

    val b = h.bind()
    val c = h.bind() // Same E2 engine object; only this B->C leg is eligible.
    val provisional = h.arbiter.quiescentOwnerHandoff(c,
      b.ownerToken, b.engineGeneration)
    assertEquals(true, (provisional["snapshot"] as Map<*, *>)["allClear"])
    val reply = h.callRebind(c, b)
    Mockito.verify(h.plugin).rebindPermitBridge(
      Mockito.same(h.messenger), Mockito.any(VideoPermitBridge::class.java))
    assertEquals(listOf("video_bridge_unavailable"), reply.errors)
    assertTrue(reply.successes.isEmpty()) // No bridgeReady or handoff ACK.
    assertEquals(0, reply.notImplemented)
    assertSame(oldBridge, h.bridge())

    // The failed rebind leaves the stale bridge installed, but it cannot
    // authorize a new player from Y's obsolete owner/lease fields.
    val deniedFactory = Mockito.mockStatic(PlatformViewVideoPlayer::class.java)
    try {
      expectIllegalState { h.plugin.createForPlatformView(yOptions) }
      deniedFactory.verifyNoInteractions()
    } finally {
      deniedFactory.close()
    }
    assertEquals(0, h.nativeCount("permitRecords"))
    assertEquals(0, h.nativeCount("videoPlayers"))
  }

  @Test fun virginOldBridgeCanRebindAndReturnReady() {
    val h = Harness()
    val a = h.bind()
    assertEquals(VendorVideoPermitBridge.InstallResult.INSTALLED,
      VendorVideoPermitBridge.installForEngine(h.engine, a, h.arbiter))
    val oldBridge = h.bridge()
    assertTrue(oldBridge.isQuiescentForRebind())
    val b = h.bind()
    val reply = h.callRebind(b, a)
    Mockito.verify(h.plugin).rebindPermitBridge(
      Mockito.same(h.messenger), Mockito.any(VideoPermitBridge::class.java))
    assertTrue(reply.errors.isEmpty())
    assertEquals(1, reply.successes.size)
    assertEquals(true, (reply.successes.single() as Map<*, *>)["bridgeReady"])
    assertFalse(h.bridge() === oldBridge)
    assertEquals(0, reply.notImplemented)
  }
}
