// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// An immutable copy of the Pigeon permit. The app must compare every field
/// with its native arbiter binding; these Dart-supplied values grant nothing
/// by themselves.
public struct VideoPermitIdentity: Equatable {
  public let ownerToken: String
  public let engineGeneration: Int64
  public let contextGeneration: Int64
  public let leaseId: String
  public let leaseGeneration: Int64

  public init(ownerToken: String, engineGeneration: Int64, contextGeneration: Int64,
              leaseId: String, leaseGeneration: Int64) {
    self.ownerToken = ownerToken
    self.engineGeneration = engineGeneration
    self.contextGeneration = contextGeneration
    self.leaseId = leaseId
    self.leaseGeneration = leaseGeneration
  }
}

/// Installed on one plugin instance for one engine, on the main thread.
/// The implementation must atomically claim in the app arbiter before running
/// firstSideEffect, and must only acknowledge an exact player after native
/// teardown. An unbound plugin never creates a player.
public protocol VideoPermitBridge: AnyObject {
  func withClaimedVideoCreation(
    permit: VideoPermitIdentity,
    playerId: Int64,
    firstSideEffect: () throws -> Void
  ) throws -> Bool

  func releaseVideoPlayer(permit: VideoPermitIdentity, playerId: Int64) -> Bool

  /// True only for this bridge's exact native release and Dart ACK, or an
  /// attested same-engine handoff when the bridge never admitted a player.
  func isQuiescentForRebind() -> Bool
}
