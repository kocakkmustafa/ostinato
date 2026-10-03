// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package io.flutter.plugins.videoplayer;

import static org.junit.Assert.assertTrue;
import static org.mockito.Mockito.*;

import android.content.Context;
import androidx.media3.exoplayer.ExoPlayer;
import androidx.test.core.app.ApplicationProvider;
import io.flutter.plugin.platform.PlatformView;
import io.flutter.plugins.videoplayer.platformview.PlatformVideoView;
import io.flutter.plugins.videoplayer.platformview.PlatformVideoViewFactory;
import java.util.concurrent.atomic.AtomicBoolean;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;

@RunWith(RobolectricTestRunner.class)
public class PlatformVideoViewFactoryTest {
  @Test
  public void createsPlatformVideoViewBasedOnSuppliedArguments() {
    final PlatformVideoViewFactory.VideoPlayerProvider videoPlayerProvider =
        mock(PlatformVideoViewFactory.VideoPlayerProvider.class);
    final VideoPlayer videoPlayer = mock(VideoPlayer.class);
    final Context context = ApplicationProvider.getApplicationContext();
    final ExoPlayer exoPlayer = new ExoPlayer.Builder(context).build();
    final long playerId = 1L;

    when(videoPlayerProvider.getVideoPlayer(playerId)).thenReturn(videoPlayer);
    when(videoPlayer.getExoPlayer()).thenReturn(exoPlayer);

    final PlatformVideoViewFactory factory = new PlatformVideoViewFactory(videoPlayerProvider);
    final PlatformVideoViewCreationParams args = new PlatformVideoViewCreationParams(playerId);

    final PlatformView view = factory.create(context, 0, args);

    assertTrue(view instanceof PlatformVideoView);
    verify(videoPlayerProvider).getVideoPlayer(playerId);
    verify(videoPlayer).getExoPlayer();

    exoPlayer.release();
  }

  @Test
  public void closingDuringViewCreationDoesNotReturnAViewOrTouchExo() {
    final PlatformVideoViewFactory.VideoPlayerProvider provider =
        mock(PlatformVideoViewFactory.VideoPlayerProvider.class);
    final VideoPlayer player = mock(VideoPlayer.class);
    final ExoPlayer exoPlayer = mock(ExoPlayer.class);
    final AtomicBoolean revoked = new AtomicBoolean(false);
    final long playerId = 2L;
    when(provider.getVideoPlayer(playerId)).thenReturn(player);
    when(player.isRevoked()).thenAnswer(invocation -> revoked.get());
    when(player.getExoPlayer())
        .thenAnswer(
            invocation -> {
              revoked.set(true);
              return exoPlayer;
            });

    final PlatformVideoViewFactory factory = new PlatformVideoViewFactory(provider);
    try {
      factory.create(
          ApplicationProvider.getApplicationContext(),
          0,
          new PlatformVideoViewCreationParams(playerId));
      throw new AssertionError("Expected closing player to deny view creation");
    } catch (IllegalStateException expected) {
      // The newly constructed view is tombstoned before the factory refuses it.
    }

    verifyNoInteractions(exoPlayer);
  }
}
