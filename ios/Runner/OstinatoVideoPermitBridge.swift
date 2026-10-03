import Foundation
import video_player_avfoundation

/// Binds one published video plugin to the owner captured for its Flutter engine.
/// The plugin retains this bridge for exact release after an engine replacement.
final class OstinatoVideoPermitBridge: VideoPermitBridge {
  private let arbiter: PracticeAudioArbiter
  private let owner: PracticeAudioOwner
  private weak var plugin: VideoPlayerPlugin?
  // Written only after the arbiter admits this exact claim, even if the AV
  // side effect throws or synchronously fences the owner.
  private var capturedClaim: (permit: VideoPermitIdentity, playerId: Int64)?

  init(arbiter: PracticeAudioArbiter, owner: PracticeAudioOwner,
       plugin: VideoPlayerPlugin? = nil) {
    self.arbiter = arbiter
    self.owner = owner
    self.plugin = plugin
  }

  private func fields(_ permit: VideoPermitIdentity) -> (context: Int, lease: Int)? {
    guard permit.ownerToken == owner.token,
          let engine = Int(exactly: permit.engineGeneration),
          engine == owner.engineGeneration,
          let context = Int(exactly: permit.contextGeneration),
          let lease = Int(exactly: permit.leaseGeneration) else { return nil }
    return (context, lease)
  }

  func withClaimedVideoCreation(
    permit: VideoPermitIdentity,
    playerId: Int64,
    firstSideEffect: () throws -> Void
  ) throws -> Bool {
    guard Thread.isMainThread, let values = fields(permit) else { return false }
    return try arbiter.withClaimedVideoCreation(
      owner: owner,
      contextGeneration: values.context,
      leaseId: permit.leaseId,
      leaseGeneration: values.lease,
      playerId: playerId,
      closePort: { [weak self] in
        guard let self = self, let plugin = self.plugin else { return false }
        return plugin.closeExactPlayer(permit: permit, playerId: playerId,
                                       bridge: self)
      },
      firstSideEffect: {
        self.capturedClaim = (permit, playerId)
        try firstSideEffect()
      })
  }

  func releaseVideoPlayer(permit: VideoPermitIdentity, playerId: Int64) -> Bool {
    // Do not require owner to be current: an exact old-engine teardown must
    // still be able to report release without authorizing any new creation.
    guard Thread.isMainThread, let values = fields(permit) else { return false }
    return arbiter.releaseVideoPlayer(
      owner: owner,
      contextGeneration: values.context,
      leaseId: permit.leaseId,
      leaseGeneration: values.lease,
      playerId: playerId)
  }

  func isQuiescentForRebind() -> Bool {
    guard Thread.isMainThread else { return false }
    if let claim = capturedClaim {
      guard let values = fields(claim.permit) else { return false }
      return arbiter.videoBridgeIsQuiescent(owner: owner,
        contextGeneration: values.context, leaseId: claim.permit.leaseId,
        leaseGeneration: values.lease, playerId: claim.playerId)
    }
    return arbiter.videoBridgeIsQuiescent(owner: owner)
  }
}
