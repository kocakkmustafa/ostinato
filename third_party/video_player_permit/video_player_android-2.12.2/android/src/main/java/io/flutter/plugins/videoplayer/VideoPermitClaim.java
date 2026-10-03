package io.flutter.plugins.videoplayer;

import androidx.annotation.NonNull;

/** Immutable copy of the Pigeon permit and the plugin-assigned player id. */
public final class VideoPermitClaim {
  @NonNull private final String ownerToken;
  private final long engineGeneration;
  private final long contextGeneration;
  @NonNull private final String leaseId;
  private final long leaseGeneration;
  private final long playerId;

  VideoPermitClaim(@NonNull VideoPermitMessage permit, long playerId) {
    ownerToken = permit.getOwnerToken();
    engineGeneration = permit.getEngineGeneration();
    contextGeneration = permit.getContextGeneration();
    leaseId = permit.getLeaseId();
    leaseGeneration = permit.getLeaseGeneration();
    this.playerId = playerId;
    if (!validToken(ownerToken) || !validToken(leaseId) || engineGeneration < 1 ||
        contextGeneration < 0 || leaseGeneration < 1 || playerId < 1) {
      throw new IllegalArgumentException("Invalid native video permit");
    }
  }

  private static boolean validToken(String value) {
    return value != null && value.matches("[0-9a-f]{32}");
  }

  @NonNull public String getOwnerToken() { return ownerToken; }
  public long getEngineGeneration() { return engineGeneration; }
  public long getContextGeneration() { return contextGeneration; }
  @NonNull public String getLeaseId() { return leaseId; }
  public long getLeaseGeneration() { return leaseGeneration; }
  public long getPlayerId() { return playerId; }
}
