package io.flutter.plugins.videoplayer;

import androidx.annotation.NonNull;

/** App-owned, engine-bound authority for one native platform-view player. */
public interface VideoPermitBridge {
  /** Runs the first native player side effect while the app's claim gate is held. */
  boolean withClaimedVideoCreation(@NonNull VideoPermitClaim claim, @NonNull Runnable create);

  /** Reads the exact claimed owner and lease without claiming or releasing it. */
  boolean isCurrentClaim(@NonNull VideoPermitClaim claim);

  /** Reports an exact player only after native cleanup has completed. */
  boolean releaseVideoPlayer(@NonNull VideoPermitClaim claim);

  /** The old owner may yield this engine only after exact native release and Dart ACK.
   * Existing bridge implementations deny transfer unless they opt in explicitly. */
  default boolean isQuiescentForRebind() { return false; }
}
