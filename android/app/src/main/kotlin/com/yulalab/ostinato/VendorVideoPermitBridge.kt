package com.yulalab.ostinato

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugins.videoplayer.VideoPermitBridge
import io.flutter.plugins.videoplayer.VideoPermitClaim
import io.flutter.plugins.videoplayer.VideoPlayerPlugin

/** One app authority for the vendor plugin already attached to this exact engine. */
internal class VendorVideoPermitBridge private constructor(
  arbiter: PracticeAudioArbiter,
  binding: PracticeAudioArbiter.Binding,
  plugin: VideoPlayerPlugin,
  messenger: BinaryMessenger,
) : VideoPermitBridge {
  private val core = AndroidVideoPermitBridgeCore(
    arbiter = arbiter,
    binding = binding,
    plugin = plugin,
    messenger = messenger,
    fieldsOf = { claim: VideoPermitClaim ->
      AndroidVideoPermitBridgeCore.Fields(
        claim.ownerToken, claim.engineGeneration, claim.contextGeneration,
        claim.leaseId, claim.leaseGeneration, claim.playerId,
      )
    },
    closeExact = { exactPlugin: VideoPlayerPlugin,
                   exactMessenger: BinaryMessenger,
                   exactClaim: VideoPermitClaim ->
      when (exactPlugin.closeExactPlayer(exactMessenger, exactClaim)) {
        VideoPlayerPlugin.ExactCloseResult.RELEASED_EXACT ->
          AndroidVideoPermitBridgeCore.ExactCloseResult.RELEASED_EXACT
        VideoPlayerPlugin.ExactCloseResult.PENDING_CREATE ->
          AndroidVideoPermitBridgeCore.ExactCloseResult.PENDING_CREATE
        VideoPlayerPlugin.ExactCloseResult.UNCONFIRMED ->
          AndroidVideoPermitBridgeCore.ExactCloseResult.UNCONFIRMED
        else -> AndroidVideoPermitBridgeCore.ExactCloseResult.UNCONFIRMED
      }
    },
  )

  override fun withClaimedVideoCreation(claim: VideoPermitClaim, create: Runnable): Boolean =
    core.withClaimedVideoCreation(claim, create)

  override fun isCurrentClaim(claim: VideoPermitClaim): Boolean = core.isCurrentClaim(claim)

  override fun releaseVideoPlayer(claim: VideoPermitClaim): Boolean =
    core.releaseVideoPlayer(claim)

  override fun isQuiescentForRebind(): Boolean = core.isQuiescentForRebind()

  internal enum class InstallResult {
    INSTALLED,
    REBOUND,
    STALE_OWNER,
    MISSING_PLUGIN,
    PLUGIN_REJECTED,
  }

  companion object {
    /** External/cached engines may lack the plugin or keep an old bridge. Both stay closed. */
    fun installForEngine(
      engine: FlutterEngine,
      binding: PracticeAudioArbiter.Binding,
      arbiter: PracticeAudioArbiter,
    ): InstallResult {
      if (binding.engine !== engine || !arbiter.isCurrent(binding)) {
        return InstallResult.STALE_OWNER
      }
      val plugin = engine.plugins.get(VideoPlayerPlugin::class.java) as? VideoPlayerPlugin
        ?: return InstallResult.MISSING_PLUGIN
      val messenger = engine.dartExecutor.binaryMessenger
      val bridge = VendorVideoPermitBridge(arbiter, binding, plugin, messenger)
      return try {
        plugin.installPermitBridge(messenger, bridge)
        InstallResult.INSTALLED
      } catch (_: IllegalStateException) {
        // A cached engine can keep the old Activity's bridge. The vendor owns
        // the exact old-player and old-ACK proof before it may replace that bridge.
        try {
          plugin.rebindPermitBridge(messenger, bridge)
          InstallResult.REBOUND
        } catch (_: IllegalStateException) {
          InstallResult.PLUGIN_REJECTED
        }
      }
    }
  }
}
