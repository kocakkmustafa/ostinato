// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package io.flutter.plugins.videoplayer;

import static androidx.media3.common.Player.REPEAT_MODE_ALL;
import static androidx.media3.common.Player.REPEAT_MODE_OFF;

import android.os.Handler;
import android.os.Looper;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.media3.common.AudioAttributes;
import androidx.media3.common.C;
import androidx.media3.common.Format;
import androidx.media3.common.MediaItem;
import androidx.media3.common.PlaybackParameters;
import androidx.media3.common.TrackGroup;
import androidx.media3.common.TrackSelectionOverride;
import androidx.media3.common.Tracks;
import androidx.media3.common.util.UnstableApi;
import androidx.media3.exoplayer.ExoPlayer;
import androidx.media3.exoplayer.trackselection.DefaultTrackSelector;
import io.flutter.view.TextureRegistry.SurfaceProducer;
import java.util.ArrayList;
import java.util.List;

/**
 * A class responsible for managing video playback using {@link ExoPlayer}.
 *
 * <p>It provides methods to control playback, adjust volume, and handle seeking.
 */
public abstract class VideoPlayer implements VideoPlayerInstanceApi {
  @NonNull protected final VideoPlayerCallbacks videoPlayerEvents;
  @Nullable protected final SurfaceProducer surfaceProducer;
  @Nullable private DisposeHandler disposeHandler;
  @Nullable private ExoPlayerEventListener exoPlayerEventListener;
  @NonNull protected ExoPlayer exoPlayer;
  // TODO: Migrate to stable API, see https://github.com/flutter/flutter/issues/147039.
  @UnstableApi @Nullable protected DefaultTrackSelector trackSelector;

  private final Handler mainHandler = new Handler(Looper.getMainLooper());
  private volatile boolean isDisposed = false;
  private boolean mainCallbacksRemoved = false;
  private boolean exoReleased = false;

  /** A constructor failure only proves rollback when every acquired resource was released. */
  public static final class CreationFailure extends RuntimeException {
    private final boolean cleanupConfirmed;

    public CreationFailure(Throwable cause, boolean cleanupConfirmed) {
      super("Native video player construction failed", cause);
      this.cleanupConfirmed = cleanupConfirmed;
    }

    public boolean isCleanupConfirmed() {
      return cleanupConfirmed;
    }
  }

  /** A closure-compatible signature since {@link java.util.function.Supplier} is API level 24. */
  public interface ExoPlayerProvider {
    /**
     * Returns a new {@link ExoPlayer}.
     *
     * @return new instance.
     */
    @NonNull
    ExoPlayer get();
  }

  /** A handler to run when dispose is called. */
  public interface DisposeHandler {
    void onDispose();
  }

  // TODO: Migrate to stable API, see https://github.com/flutter/flutter/issues/147039.
  @UnstableApi
  // Error thrown for this-escape warning on JDK 21+ due to
  // https://bugs.openjdk.org/browse/JDK-8015831.
  // Keeping behavior as-is and addressing the warning could cause a regression:
  // https://github.com/flutter/packages/pull/10193
  @SuppressWarnings("this-escape")
  public VideoPlayer(
      @NonNull VideoPlayerCallbacks events,
      @NonNull MediaItem mediaItem,
      @NonNull VideoPlayerOptions options,
      @Nullable SurfaceProducer surfaceProducer,
      @NonNull ExoPlayerProvider exoPlayerProvider) {
    this(events, mediaItem, options, surfaceProducer, exoPlayerProvider, () -> {});
  }

  @SuppressWarnings("this-escape")
  protected VideoPlayer(
      @NonNull VideoPlayerCallbacks events,
      @NonNull MediaItem mediaItem,
      @NonNull VideoPlayerOptions options,
      @Nullable SurfaceProducer surfaceProducer,
      @NonNull ExoPlayerProvider exoPlayerProvider,
      @NonNull Runnable creationGuard) {
    this.videoPlayerEvents = events;
    this.surfaceProducer = surfaceProducer;
    try {
      creationGuard.run();
    } catch (Throwable failure) {
      // No provider has run, so there is no ExoPlayer to release.
      throw new CreationFailure(failure, true);
    }
    try {
      exoPlayer = exoPlayerProvider.get();
    } catch (Throwable failure) {
      if (failure instanceof CreationFailure &&
          ((CreationFailure) failure).isCleanupConfirmed()) {
        throw (CreationFailure) failure;
      }
      // A failing provider may have allocated a native player without returning it.
      throw new CreationFailure(failure, false);
    }
    try {
      creationGuard.run();
      // Try to get the track selector from the ExoPlayer if it was built with one.
      if (exoPlayer.getTrackSelector() instanceof DefaultTrackSelector) {
        trackSelector = (DefaultTrackSelector) exoPlayer.getTrackSelector();
      }

      creationGuard.run();
      exoPlayer.setMediaItem(mediaItem);
      creationGuard.run();
      exoPlayer.prepare();
      creationGuard.run();
      exoPlayerEventListener = createExoPlayerEventListener(exoPlayer, surfaceProducer);
      exoPlayer.addListener(exoPlayerEventListener);
      creationGuard.run();
      setAudioAttributes(exoPlayer, options.mixWithOthers);
      creationGuard.run();
    } catch (Throwable failure) {
      boolean cleaned = true;
      if (exoPlayerEventListener != null) {
        try {
          exoPlayerEventListener.dispose();
        } catch (Throwable cleanupFailure) {
          addCleanupFailure(failure, cleanupFailure);
          cleaned = false;
        }
      }
      try {
        exoPlayer.release();
      } catch (Throwable cleanupFailure) {
        addCleanupFailure(failure, cleanupFailure);
        cleaned = false;
      }
      throw new CreationFailure(failure, cleaned);
    }
  }

  private static void addCleanupFailure(Throwable first, Throwable next) {
    if (first != next) {
      first.addSuppressed(next);
    }
  }

  private static RuntimeException unchecked(Throwable failure) {
    if (failure instanceof Error) {
      throw (Error) failure;
    }
    if (failure instanceof RuntimeException) {
      return (RuntimeException) failure;
    }
    return new IllegalStateException("Native video cleanup failed", failure);
  }

  public void setDisposeHandler(@Nullable DisposeHandler handler) {
    disposeHandler = handler;
  }

  /** Denies stale instance handlers before native teardown starts. */
  public void revoke() {
    isDisposed = true;
  }

  /** Whether native teardown has started, including an exact permit close. */
  public boolean isRevoked() {
    return isDisposed;
  }

  private void requireUsable() {
    if (isDisposed) {
      throw new IllegalStateException("Native video player is closing");
    }
  }

  @NonNull
  protected abstract ExoPlayerEventListener createExoPlayerEventListener(
      @NonNull ExoPlayer exoPlayer, @Nullable SurfaceProducer surfaceProducer);

  private static void setAudioAttributes(ExoPlayer exoPlayer, boolean isMixMode) {
    exoPlayer.setAudioAttributes(
        new AudioAttributes.Builder().setContentType(C.AUDIO_CONTENT_TYPE_MOVIE).build(),
        !isMixMode);
  }

  /**
   * Helper method to extract a long value from a Format field, returning null if the value is
   * Format.NO_VALUE.
   *
   * @param value The format value to check.
   * @return The value as a Long, or null if it's Format.NO_VALUE.
   */
  private static Long getFormatValue(int value) {
    return value != Format.NO_VALUE ? (long) value : null;
  }

  /**
   * Helper method to extract a double value from a Format field, returning null if the value is
   * Format.NO_VALUE.
   *
   * @param value The format value to check.
   * @return The value as a Double, or null if it's Format.NO_VALUE.
   */
  private static Double getFormatValue(double value) {
    return value != Format.NO_VALUE ? value : null;
  }

  @Override
  public void play() {
    requireUsable();
    exoPlayer.play();
  }

  @Override
  public void pause() {
    requireUsable();
    exoPlayer.pause();
  }

  @Override
  public void setLooping(boolean looping) {
    requireUsable();
    exoPlayer.setRepeatMode(looping ? REPEAT_MODE_ALL : REPEAT_MODE_OFF);
  }

  @Override
  public void setVolume(double volume) {
    requireUsable();
    float bracketedValue = (float) Math.max(0.0, Math.min(1.0, volume));
    exoPlayer.setVolume(bracketedValue);
  }

  @Override
  public void setPlaybackSpeed(double speed) {
    requireUsable();
    // We do not need to consider pitch and skipSilence for now as we do not handle them and
    // therefore never diverge from the default values.
    final PlaybackParameters playbackParameters = new PlaybackParameters((float) speed);

    exoPlayer.setPlaybackParameters(playbackParameters);
  }

  @Override
  public long getCurrentPosition() {
    requireUsable();
    return exoPlayer.getCurrentPosition();
  }

  @Override
  public long getBufferedPosition() {
    requireUsable();
    return exoPlayer.getBufferedPosition();
  }

  @Override
  public void seekTo(long position) {
    requireUsable();
    exoPlayer.seekTo(position);
  }

  @NonNull
  public ExoPlayer getExoPlayer() {
    return exoPlayer;
  }

  // TODO: Migrate to stable API, see https://github.com/flutter/flutter/issues/147039.
  @UnstableApi
  @Override
  public @NonNull NativeAudioTrackData getAudioTracks() {
    requireUsable();
    List<ExoPlayerAudioTrackData> audioTracks = new ArrayList<>();

    // Get the current tracks from ExoPlayer
    Tracks tracks = exoPlayer.getCurrentTracks();

    // Iterate through all track groups
    for (int groupIndex = 0; groupIndex < tracks.getGroups().size(); groupIndex++) {
      Tracks.Group group = tracks.getGroups().get(groupIndex);

      // Only process audio tracks
      if (group.getType() == C.TRACK_TYPE_AUDIO) {
        for (int trackIndex = 0; trackIndex < group.length; trackIndex++) {
          Format format = group.getTrackFormat(trackIndex);
          boolean isSelected = group.isTrackSelected(trackIndex);

          // Create audio track data with metadata
          ExoPlayerAudioTrackData audioTrack =
              new ExoPlayerAudioTrackData(
                  (long) groupIndex,
                  (long) trackIndex,
                  format.label,
                  format.language,
                  isSelected,
                  getFormatValue(format.bitrate),
                  getFormatValue(format.sampleRate),
                  getFormatValue(format.channelCount),
                  format.codecs != null ? format.codecs : null);

          audioTracks.add(audioTrack);
        }
      }
    }
    return new NativeAudioTrackData(audioTracks);
  }

  // TODO: Migrate to stable API, see https://github.com/flutter/flutter/issues/147039.
  @UnstableApi
  @Override
  public void selectAudioTrack(long groupIndex, long trackIndex) {
    requireUsable();
    if (trackSelector == null) {
      throw new IllegalStateException("Cannot select audio track: track selector is null");
    }

    // Get current tracks
    Tracks tracks = exoPlayer.getCurrentTracks();

    if (groupIndex < 0 || groupIndex >= tracks.getGroups().size()) {
      throw new IllegalArgumentException(
          "Cannot select audio track: groupIndex "
              + groupIndex
              + " is out of bounds (available groups: "
              + tracks.getGroups().size()
              + ")");
    }

    Tracks.Group group = tracks.getGroups().get((int) groupIndex);

    // Verify it's an audio track
    if (group.getType() != C.TRACK_TYPE_AUDIO) {
      throw new IllegalArgumentException(
          "Cannot select audio track: group at index "
              + groupIndex
              + " is not an audio track (type: "
              + group.getType()
              + ")");
    }

    // Verify the track index is valid
    if (trackIndex < 0 || (int) trackIndex >= group.length) {
      throw new IllegalArgumentException(
          "Cannot select audio track: trackIndex "
              + trackIndex
              + " is out of bounds (available tracks in group: "
              + group.length
              + ")");
    }

    // Get the track group and create a selection override
    TrackGroup trackGroup = group.getMediaTrackGroup();
    TrackSelectionOverride override = new TrackSelectionOverride(trackGroup, (int) trackIndex);

    // Apply the track selection override
    trackSelector.setParameters(
        trackSelector.buildUponParameters().setOverrideForType(override).build());
  }

  // TODO: Migrate to stable API, see https://github.com/flutter/flutter/issues/147039.
  @UnstableApi
  @Override
  public @NonNull NativeVideoTrackData getVideoTracks() {
    requireUsable();
    List<ExoPlayerVideoTrackData> videoTracks = new ArrayList<>();

    // Get the current tracks from ExoPlayer
    Tracks tracks = exoPlayer.getCurrentTracks();

    // Iterate through all track groups
    for (int groupIndex = 0; groupIndex < tracks.getGroups().size(); groupIndex++) {
      Tracks.Group group = tracks.getGroups().get(groupIndex);

      // Only process video tracks
      if (group.getType() == C.TRACK_TYPE_VIDEO) {
        for (int trackIndex = 0; trackIndex < group.length; trackIndex++) {
          Format format = group.getTrackFormat(trackIndex);
          boolean isSelected = group.isTrackSelected(trackIndex);

          // Create video track data with metadata
          ExoPlayerVideoTrackData videoTrack =
              new ExoPlayerVideoTrackData(
                  (long) groupIndex,
                  (long) trackIndex,
                  format.label,
                  isSelected,
                  getFormatValue(format.bitrate),
                  getFormatValue(format.width),
                  getFormatValue(format.height),
                  getFormatValue(format.frameRate),
                  format.codecs != null ? format.codecs : null);

          videoTracks.add(videoTrack);
        }
      }
    }
    return new NativeVideoTrackData(videoTracks);
  }

  // TODO: Migrate to stable API, see https://github.com/flutter/flutter/issues/147039.
  @UnstableApi
  @Override
  public void enableAutoVideoQuality() {
    requireUsable();
    if (trackSelector == null) {
      throw new IllegalStateException("Cannot enable auto video quality: track selector is null");
    }

    // Clear video track override to enable adaptive streaming
    trackSelector.setParameters(
        trackSelector.buildUponParameters().clearOverridesOfType(C.TRACK_TYPE_VIDEO).build());
  }

  // TODO: Migrate to stable API, see https://github.com/flutter/flutter/issues/147039.
  @UnstableApi
  @Override
  public void selectVideoTrack(long groupIndex, long trackIndex) {
    requireUsable();
    if (trackSelector == null) {
      throw new IllegalStateException("Cannot select video track: track selector is null");
    }

    // Get current tracks
    Tracks tracks = exoPlayer.getCurrentTracks();

    if (groupIndex < 0 || groupIndex >= tracks.getGroups().size()) {
      throw new IllegalArgumentException(
          "Cannot select video track: groupIndex "
              + groupIndex
              + " is out of bounds (available groups: "
              + tracks.getGroups().size()
              + ")");
    }

    Tracks.Group group = tracks.getGroups().get((int) groupIndex);

    // Verify it's a video track
    if (group.getType() != C.TRACK_TYPE_VIDEO) {
      throw new IllegalArgumentException(
          "Cannot select video track: group at index "
              + groupIndex
              + " is not a video track (type: "
              + group.getType()
              + ")");
    }

    // Verify the track index is valid
    if (trackIndex < 0 || (int) trackIndex >= group.length) {
      throw new IllegalArgumentException(
          "Cannot select video track: trackIndex "
              + trackIndex
              + " is out of bounds (available tracks in group: "
              + group.length
              + ")");
    }

    // Get the track group and create a selection override
    TrackGroup trackGroup = group.getMediaTrackGroup();
    TrackSelectionOverride override = new TrackSelectionOverride(trackGroup, (int) trackIndex);

    // Check if the new track has different dimensions than the current track
    Format currentFormat = exoPlayer.getVideoFormat();
    Format newFormat = trackGroup.getFormat((int) trackIndex);
    boolean dimensionsChanged =
        currentFormat == null
            || currentFormat.width != newFormat.width
            || currentFormat.height != newFormat.height;

    // When video dimensions change, we need to force a complete renderer reset to avoid
    // surface rendering issues. We do this by temporarily disabling the video track type,
    // which causes ExoPlayer to release the current video renderer and MediaCodec decoder.
    // After a brief delay, we re-enable video with the new track selection, which creates
    // a fresh renderer properly configured for the new dimensions.
    //
    // Why is this necessary?
    // When switching between video tracks with different resolutions (e.g., 720p to 1080p),
    // the existing video surface and MediaCodec decoder may not properly reconfigure for the
    // new dimensions. This can cause visual glitches where the video appears in the wrong
    // position (e.g., top-left corner) or the old surface remains partially visible.
    // By disabling the video track type, we force ExoPlayer to completely release the
    // current renderer and decoder, ensuring a clean slate for the new resolution.
    //
    // References:
    // - ExoPlayer TrackSelection documentation:
    //   https://developer.android.com/media/media3/exoplayer/track-selection
    // - DefaultTrackSelector.setParameters() for track type disabling:
    //
    // https://developer.android.com/reference/androidx/media3/exoplayer/trackselection/DefaultTrackSelector.Parameters.Builder#setTrackTypeDisabled(int,boolean)
    // - This approach is necessary because ExoPlayer doesn't provide a direct API to force
    //   a renderer reset when dimensions change. Disabling and re-enabling the track type
    //   is the recommended way to ensure proper resource cleanup and reinitialization.
    // TODO(nateshmbhat): Remove this workaround once Media3 provides a supported
    // renderer reset path or reliable resolution-changing track switches.
    // https://github.com/flutter/flutter/issues/183824
    if (dimensionsChanged) {
      final boolean wasPlaying = exoPlayer.isPlaying();
      final long currentPosition = exoPlayer.getCurrentPosition();

      // Disable video track type to force renderer release
      trackSelector.setParameters(
          trackSelector
              .buildUponParameters()
              .setTrackTypeDisabled(C.TRACK_TYPE_VIDEO, true)
              .build());

      // Re-enable video with the new track selection after allowing renderer to release.
      //
      // Why 150ms delay?
      // This delay is necessary to allow the MediaCodec decoder and video renderer to fully
      // release their resources before we attempt to create new ones. Without this delay,
      // the new decoder may be initialized before the old one is completely released, leading
      // to resource conflicts and rendering artifacts. The 150ms value was determined through
      // empirical testing across various Android devices and provides a reliable balance
      // between responsiveness and ensuring complete resource cleanup. Shorter delays (e.g.,
      // 50-100ms) were found to still cause glitches on some devices, while longer delays
      // would unnecessarily impact user experience.
      mainHandler.postDelayed(
          () -> {
            // Guard against player disposal during the delay. The isDisposed flag
            // is the authoritative check; the trackSelector null-check is kept for
            // safety even though it is set in the constructor.
            if (isDisposed || trackSelector == null) {
              return;
            }

            trackSelector.setParameters(
                trackSelector
                    .buildUponParameters()
                    .setTrackTypeDisabled(C.TRACK_TYPE_VIDEO, false)
                    .setOverrideForType(override)
                    .build());

            // Restore playback state
            exoPlayer.seekTo(currentPosition);
            if (wasPlaying) {
              exoPlayer.play();
            }
          },
          150);
      return;
    }

    // Apply the track selection override normally if dimensions haven't changed
    trackSelector.setParameters(
        trackSelector.buildUponParameters().setOverrideForType(override).build());
  }

  public void dispose() {
    isDisposed = true;
    Throwable failure = null;
    if (!mainCallbacksRemoved) {
      try {
        mainHandler.removeCallbacksAndMessages(null);
        mainCallbacksRemoved = true;
      } catch (Throwable cleanupFailure) {
        failure = cleanupFailure;
      }
    }
    if (exoPlayerEventListener != null) {
      try {
        exoPlayerEventListener.dispose();
        exoPlayerEventListener = null;
      } catch (Throwable cleanupFailure) {
        if (failure == null) failure = cleanupFailure;
        else addCleanupFailure(failure, cleanupFailure);
      }
    }
    // A channel handler or listener failure must never skip the Exo release attempt.
    if (!exoReleased) {
      try {
        exoPlayer.release();
        exoReleased = true;
      } catch (Throwable cleanupFailure) {
        if (failure == null) failure = cleanupFailure;
        else addCleanupFailure(failure, cleanupFailure);
      }
    }
    if (disposeHandler != null) {
      try {
        disposeHandler.onDispose();
        disposeHandler = null;
      } catch (Throwable cleanupFailure) {
        if (failure == null) failure = cleanupFailure;
        else addCleanupFailure(failure, cleanupFailure);
      }
    }
    if (failure != null) {
      throw unchecked(failure);
    }
  }
}
