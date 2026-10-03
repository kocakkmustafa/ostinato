// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package io.flutter.plugins.videoplayer.platformview;

import android.content.Context;
import android.os.Build;
import android.view.Surface;
import android.view.SurfaceHolder;
import android.view.SurfaceView;
import android.view.View;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.annotation.OptIn;
import androidx.media3.common.util.UnstableApi;
import androidx.media3.exoplayer.ExoPlayer;
import io.flutter.plugin.platform.PlatformView;
import io.flutter.plugins.videoplayer.VideoPlayer;

/**
 * A class used to create a native video view that can be embedded in a Flutter app. It wraps an
 * {@link ExoPlayer} instance and displays its video content.
 */
public final class PlatformVideoView implements PlatformView {
  @NonNull private final VideoPlayer player;
  @NonNull private final ExoPlayer exoPlayer;
  @NonNull private final SurfaceView surfaceView;
  @NonNull private final SurfaceHolder.Callback surfaceCallback;
  @Nullable private Surface boundSurface;
  @Nullable private Surface disposeSurface;
  private volatile boolean disposed;
  private boolean callbackRemoved;
  private boolean cleanupInProgress;
  private boolean surfaceClearConfirmed;
  private boolean surfaceReleased;

  /**
   * Constructs a new PlatformVideoView.
   *
   * @param context The context in which the view is running.
   * @param player The exact player whose native lifecycle controls this view.
   */
  @OptIn(markerClass = UnstableApi.class)
  public PlatformVideoView(@NonNull Context context, @NonNull VideoPlayer player) {
    if (player.isRevoked()) {
      throw new IllegalStateException("Native video player is closing");
    }
    this.player = player;
    this.exoPlayer = player.getExoPlayer();
    final VideoSurfaceView videoSurfaceView = new VideoSurfaceView(context);
    this.surfaceView = videoSurfaceView;
    videoSurfaceView.setOwner(this);
    this.surfaceCallback = createSurfaceCallback();

    try {
      surfaceView.getHolder().addCallback(surfaceCallback);
      if (Build.VERSION.SDK_INT <= Build.VERSION_CODES.N_MR1) {
        // Avoid blank space instead of a video on Android versions below 8 by adjusting video's
        // z-layer within the Android view hierarchy.
        surfaceView.setZOrderMediaOverlay(true);
      }
    } catch (Throwable setupFailure) {
      try {
        dispose();
      } catch (Throwable cleanupFailure) {
        if (cleanupFailure != setupFailure) setupFailure.addSuppressed(cleanupFailure);
      }
      throw unchecked(setupFailure);
    }
  }

  private SurfaceHolder.Callback createSurfaceCallback() {
    return new SurfaceHolder.Callback() {
      @Override
      public void surfaceCreated(@NonNull SurfaceHolder holder) {
        if (!canUsePlayer()) return;
        bindPlayerToSurface(holder.getSurface());
        // setVideoSurface may synchronously reenter exact close.
        forceFirstFrameForAndroid9();
      }

      @Override
      public void surfaceChanged(
          @NonNull SurfaceHolder holder, int format, int width, int height) {}

      @Override
      public void surfaceDestroyed(@NonNull SurfaceHolder holder) {
        if (!canUsePlayer()) return;
        final Surface surface = holder.getSurface();
        // Use the exact surface, and never call a released ExoPlayer after a reentrant close.
        if (canUsePlayer()) {
          exoPlayer.clearVideoSurface(surface);
          if (boundSurface == surface) boundSurface = null;
        }
      }
    };
  }

  private boolean canUsePlayer() {
    return !disposed && !player.isRevoked();
  }

  boolean isDisposed() {
    return disposed;
  }

  /** Binds the ExoPlayer to the provided surface. */
  private void bindPlayerToSurface(@NonNull Surface surface) {
    if (canUsePlayer() && surface.isValid() && canUsePlayer()) {
      // Record the exact surface before Exo can reenter view disposal.
      boundSurface = surface;
      exoPlayer.setVideoSurface(surface);
    }
  }

  /**
   * Workaround for a rendering bug on Android 9 (API 28) where the decoder does not flush its
   * output buffer when a new surface is attached while the player is paused.
   */
  private void forceFirstFrameForAndroid9() {
    if (Build.VERSION.SDK_INT == Build.VERSION_CODES.P
        && canUsePlayer()
        && !exoPlayer.getPlayWhenReady()
        && canUsePlayer()) {
      long position = exoPlayer.getCurrentPosition();
      if (canUsePlayer()) exoPlayer.seekTo(position == 0 ? 1 : position);
    }
  }

  /**
   * A custom SurfaceView that re-attaches the player surface when the view becomes visible again,
   * such as after returning from a full-screen route transition.
   */
  private static class VideoSurfaceView extends SurfaceView {
    @Nullable private PlatformVideoView owner;

    public VideoSurfaceView(Context context) {
      super(context);
    }

    private void setOwner(@Nullable PlatformVideoView owner) {
      this.owner = owner;
    }

    @Override
    protected void onVisibilityChanged(@NonNull View changedView, int visibility) {
      super.onVisibilityChanged(changedView, visibility);
      // When the view becomes visible again, re-attach the current surface.
      final PlatformVideoView currentOwner = owner;
      if (currentOwner != null
          && currentOwner.canUsePlayer()
          && visibility == View.VISIBLE
          && isShown()) {
        currentOwner.bindPlayerToSurface(getHolder().getSurface());
      }
    }
  }

  /**
   * Returns the view associated with this PlatformView.
   *
   * @return The SurfaceView used to display the video.
   */
  @NonNull
  @Override
  public View getView() {
    return surfaceView;
  }

  /** Disposes of the resources used by this PlatformView. */
  @Override
  public void dispose() {
    // Tombstone first: even a retained callback must not touch Exo during partial cleanup.
    disposed = true;
    if (surfaceView instanceof VideoSurfaceView) {
      ((VideoSurfaceView) surfaceView).setOwner(null);
    }
    if (cleanupInProgress) {
      throw new IllegalStateException("Platform video view cleanup is already running");
    }
    cleanupInProgress = true;
    try {
      disposeResources();
    } finally {
      cleanupInProgress = false;
    }
  }

  private void disposeResources() {
    Throwable failure = null;
    if (!callbackRemoved) {
      try {
        surfaceView.getHolder().removeCallback(surfaceCallback);
        callbackRemoved = true;
      } catch (Throwable cleanupFailure) {
        failure = appendFailure(failure, cleanupFailure);
      }
    }
    if (disposeSurface == null) {
      try {
        disposeSurface = surfaceView.getHolder().getSurface();
        if (disposeSurface == null) {
          throw new IllegalStateException("Platform video surface is unavailable");
        }
      } catch (Throwable cleanupFailure) {
        failure = appendFailure(failure, cleanupFailure);
      }
    }
    if (!surfaceClearConfirmed) {
      if (player.isRevoked()) {
        // Native teardown owns the released player; do not call Exo again.
        surfaceClearConfirmed = true;
      } else if (boundSurface == null) {
        surfaceClearConfirmed = true;
      } else {
        try {
          exoPlayer.clearVideoSurface(boundSurface);
          surfaceClearConfirmed = true;
          boundSurface = null;
        } catch (Throwable cleanupFailure) {
          failure = appendFailure(failure, cleanupFailure);
        }
      }
    }
    if (disposeSurface != null && !surfaceReleased) {
      try {
        disposeSurface.release();
        surfaceReleased = true;
      } catch (Throwable cleanupFailure) {
        failure = appendFailure(failure, cleanupFailure);
      }
    }
    if (failure != null) throw unchecked(failure);
  }

  private static Throwable appendFailure(@Nullable Throwable previous, @NonNull Throwable next) {
    if (previous == null) return next;
    if (previous != next) previous.addSuppressed(next);
    return previous;
  }

  private static RuntimeException unchecked(@NonNull Throwable failure) {
    if (failure instanceof Error) throw (Error) failure;
    if (failure instanceof RuntimeException) return (RuntimeException) failure;
    return new IllegalStateException("Platform video view cleanup failed", failure);
  }
}
