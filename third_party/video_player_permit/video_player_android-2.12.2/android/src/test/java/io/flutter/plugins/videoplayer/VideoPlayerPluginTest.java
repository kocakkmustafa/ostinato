// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package io.flutter.plugins.videoplayer;

import static org.junit.Assert.*;
import static org.mockito.Mockito.*;

import android.content.Context;
import android.util.LongSparseArray;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.platform.PlatformViewRegistry;
import io.flutter.plugins.videoplayer.platformview.PlatformVideoViewFactory;
import io.flutter.plugins.videoplayer.platformview.PlatformViewVideoPlayer;
import io.flutter.plugins.videoplayer.texture.TextureVideoPlayer;
import io.flutter.view.TextureRegistry;
import java.lang.reflect.Field;
import java.nio.ByteBuffer;
import java.util.Arrays;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicReference;
import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.MockedStatic;
import org.mockito.MockitoAnnotations;
import org.robolectric.RobolectricTestRunner;

@RunWith(RobolectricTestRunner.class)
public class VideoPlayerPluginTest {
  @Mock private TextureRegistry mockTextureRegistry;
  @Mock private TextureRegistry.SurfaceProducer mockSurfaceProducer;
  @Mock private PlatformViewRegistry mockPlatformViewRegistry;
  @Mock private BinaryMessenger mockBinaryMessenger;
  private VideoPlayerPlugin plugin;
  private FlutterPlugin.FlutterPluginBinding binding;

  @Before
  public void setUp() {
    MockitoAnnotations.openMocks(this);
    when(mockTextureRegistry.createSurfaceProducer()).thenReturn(mockSurfaceProducer);

    binding = mock(FlutterPlugin.FlutterPluginBinding.class);
    when(binding.getApplicationContext()).thenReturn(mock(Context.class));
    when(binding.getTextureRegistry()).thenReturn(mockTextureRegistry);
    when(binding.getBinaryMessenger()).thenReturn(mockBinaryMessenger);
    when(binding.getPlatformViewRegistry()).thenReturn(mockPlatformViewRegistry);
    when(mockPlatformViewRegistry.registerViewFactory(anyString(), any())).thenReturn(true);

    plugin = new VideoPlayerPlugin();
    plugin.onAttachedToEngine(binding);
  }

  @SuppressWarnings("unchecked")
  private LongSparseArray<VideoPlayer> getVideoPlayers() throws Exception {
    final Field field = VideoPlayerPlugin.class.getDeclaredField("videoPlayers");
    field.setAccessible(true);
    return (LongSparseArray<VideoPlayer>) field.get(plugin);
  }

  @SuppressWarnings("unchecked")
  private LongSparseArray<?> getPermitRecords() throws Exception {
    final Field field = VideoPlayerPlugin.class.getDeclaredField("permitRecords");
    field.setAccessible(true);
    return (LongSparseArray<?>) field.get(plugin);
  }

  private CreationOptions localOptions() {
    return new CreationOptions(
        "/tmp/lesson.mp4",
        null,
        new HashMap<>(),
        null,
        null,
        new VideoPermitMessage("0123456789abcdef0123456789abcdef", 1, 0,
            "fedcba9876543210fedcba9876543210", 1),
        false);
  }

  // This is only a placeholder test and doesn't actually initialize the plugin.
  @Test
  public void initPluginDoesNotThrow() {
    final VideoPlayerPlugin plugin = new VideoPlayerPlugin();
  }

  @Test
  public void registersPlatformVideoViewFactory() {
    verify(mockPlatformViewRegistry)
        .registerViewFactory(
            eq("plugins.flutter.dev/video_player_android"), any(PlatformVideoViewFactory.class));
  }

  @Test
  public void rejectedFactoryRegistrationLeavesPluginDetachedAndUnbridged() {
    plugin.onDetachedFromEngine(binding);
    when(mockPlatformViewRegistry.registerViewFactory(anyString(), any())).thenAnswer(invocation -> {
      assertThrows(IllegalStateException.class,
          () -> plugin.installPermitBridge(mockBinaryMessenger, mock(VideoPermitBridge.class)));
      return false;
    });
    assertThrows(IllegalStateException.class, () -> plugin.onAttachedToEngine(binding));
    assertThrows(IllegalStateException.class,
        () -> plugin.installPermitBridge(mockBinaryMessenger, mock(VideoPermitBridge.class)));
    assertThrows(IllegalStateException.class,
        () -> plugin.createForPlatformView(localOptions()));
  }

  @Test
  public void partialGlobalUnbindBlocksReattachAndOldDisposeCannotCloseNewPlayer()
      throws Exception {
    final String disposeChannel =
        "dev.flutter.pigeon.video_player_android.AndroidVideoPlayerApi.dispose";
    ArgumentCaptor<BinaryMessenger.BinaryMessageHandler> oldDispose =
        ArgumentCaptor.forClass(BinaryMessenger.BinaryMessageHandler.class);
    verify(mockBinaryMessenger).setMessageHandler(eq(disposeChannel), oldDispose.capture());
    assertNotNull(oldDispose.getValue());

    AtomicInteger globalUnbinds = new AtomicInteger();
    doAnswer(invocation -> {
      String channel = invocation.getArgument(0);
      Object handler = invocation.getArgument(1);
      if (handler == null && channel.startsWith(
          "dev.flutter.pigeon.video_player_android.AndroidVideoPlayerApi.")) {
        int attempt = globalUnbinds.incrementAndGet();
        if (attempt == 3 || attempt == 6) {
          throw new IllegalStateException("third global unbind failed");
        }
      }
      return null;
    }).when(mockBinaryMessenger).setMessageHandler(anyString(), any());
    assertThrows(IllegalStateException.class, () -> plugin.onDetachedFromEngine(binding));
    verify(mockBinaryMessenger, never()).setMessageHandler(eq(disposeChannel), isNull());

    BinaryMessenger nextMessenger = mock(BinaryMessenger.class);
    PlatformViewRegistry nextRegistry = mock(PlatformViewRegistry.class);
    when(nextRegistry.registerViewFactory(anyString(), any())).thenReturn(true);
    FlutterPlugin.FlutterPluginBinding nextBinding =
        mock(FlutterPlugin.FlutterPluginBinding.class);
    when(nextBinding.getApplicationContext()).thenReturn(mock(Context.class));
    when(nextBinding.getTextureRegistry()).thenReturn(mockTextureRegistry);
    when(nextBinding.getBinaryMessenger()).thenReturn(nextMessenger);
    when(nextBinding.getPlatformViewRegistry()).thenReturn(nextRegistry);
    assertThrows(IllegalStateException.class, () -> plugin.onAttachedToEngine(nextBinding));
    verifyNoInteractions(nextRegistry);
    plugin.onAttachedToEngine(nextBinding);
    verify(mockBinaryMessenger).setMessageHandler(eq(disposeChannel), isNull());

    plugin.installPermitBridge(nextMessenger, new VideoPermitBridge() {
      @Override
      public boolean withClaimedVideoCreation(VideoPermitClaim claim, Runnable create) {
        create.run();
        return true;
      }

      @Override
      public boolean isCurrentClaim(VideoPermitClaim claim) { return true; }

      @Override
      public boolean releaseVideoPlayer(VideoPermitClaim claim) { return true; }
    });
    PlatformViewVideoPlayer newPlayer = mock(PlatformViewVideoPlayer.class);
    long id;
    try (MockedStatic<PlatformViewVideoPlayer> mocked =
        mockStatic(PlatformViewVideoPlayer.class)) {
      mocked.when(() -> PlatformViewVideoPlayer.create(any(), any(), any(), any(), any()))
          .thenReturn(newPlayer);
      id = plugin.createForPlatformView(localOptions());
    }
    ByteBuffer oldRequest = AndroidVideoPlayerApi.Companion.getCodec()
        .encodeMessage(Arrays.asList(id));
    if (oldRequest.position() != 0) oldRequest.flip();
    else oldRequest.rewind();
    oldDispose.getValue().onMessage(oldRequest, reply -> {});
    verify(newPlayer, never()).dispose();
    assertSame(newPlayer, getVideoPlayers().get(id));
    plugin.dispose(id);
  }

  @Test
  public void platformViewWithoutInstalledBridgeIsDeniedBeforePlayerCreation() {
    try (MockedStatic<PlatformViewVideoPlayer> mocked =
        mockStatic(PlatformViewVideoPlayer.class)) {
      assertThrows(IllegalStateException.class,
          () -> plugin.createForPlatformView(localOptions()));
      mocked.verifyNoInteractions();
    }
  }

  @Test
  public void rejectedPlatformViewClaimNeverStartsPlayerCreation() throws Exception {
    try (MockedStatic<PlatformViewVideoPlayer> mockedPlatformViewVideoPlayerStatic =
        mockStatic(PlatformViewVideoPlayer.class)) {
      AtomicBoolean called = new AtomicBoolean();
      plugin.installPermitBridge(
          mockBinaryMessenger,
          new VideoPermitBridge() {
            @Override
            public boolean withClaimedVideoCreation(VideoPermitClaim claim, Runnable create) {
              called.set(true);
              return false;
            }

            @Override
            public boolean isCurrentClaim(VideoPermitClaim claim) { return false; }

            @Override
            public boolean releaseVideoPlayer(VideoPermitClaim claim) {
              throw new AssertionError("No claim was made");
            }
          });
      assertThrows(IllegalStateException.class,
          () -> plugin.createForPlatformView(localOptions()));
      assertTrue(called.get());
      mockedPlatformViewVideoPlayerStatic.verifyNoInteractions();
      assertEquals(0, getVideoPlayers().size());
    }
  }

  @Test
  public void aBridgeForAnotherEngineCannotBeInstalled() {
    VideoPermitBridge bridge = mock(VideoPermitBridge.class);
    assertThrows(IllegalStateException.class,
        () -> plugin.installPermitBridge(mock(BinaryMessenger.class), bridge));
    assertThrows(IllegalStateException.class,
        () -> plugin.createForPlatformView(localOptions()));
    verifyNoInteractions(bridge);
  }

  @Test
  public void firstBridgeInstallRejectsAnExistingNativePlayer() throws Exception {
    VideoPermitBridge bridge = mock(VideoPermitBridge.class);
    getVideoPlayers().put(7L, mock(VideoPlayer.class));
    assertThrows(IllegalStateException.class,
        () -> plugin.installPermitBridge(mockBinaryMessenger, bridge));
    getVideoPlayers().remove(7L);
    plugin.installPermitBridge(mockBinaryMessenger, bridge);
  }

  @Test
  public void rebindRequiresExactMessengerAndOldBridgeQuiescence() {
    VideoPermitBridge oldBridge = mock(VideoPermitBridge.class);
    VideoPermitBridge nextBridge = mock(VideoPermitBridge.class);
    plugin.installPermitBridge(mockBinaryMessenger, oldBridge);

    assertThrows(IllegalStateException.class,
        () -> plugin.rebindPermitBridge(mockBinaryMessenger, null));
    assertThrows(IllegalStateException.class,
        () -> plugin.rebindPermitBridge(mock(BinaryMessenger.class), nextBridge));
    verifyNoInteractions(oldBridge, nextBridge);
    assertThrows(IllegalStateException.class,
        () -> plugin.rebindPermitBridge(mockBinaryMessenger, nextBridge));
    verify(oldBridge).isQuiescentForRebind();
    verifyNoInteractions(nextBridge);

    when(oldBridge.isQuiescentForRebind()).thenReturn(true);
    plugin.rebindPermitBridge(mockBinaryMessenger, nextBridge);
    assertThrows(IllegalStateException.class,
        () -> plugin.createForPlatformView(localOptions()));
    verify(nextBridge).withClaimedVideoCreation(any(VideoPermitClaim.class), any(Runnable.class));
    verify(oldBridge, never()).withClaimedVideoCreation(any(VideoPermitClaim.class), any(Runnable.class));
  }

  @Test
  public void rebindRejectsOutstandingExactNativeRecordDespiteOldBridgeClaim() throws Exception {
    VideoPermitBridge oldBridge = mock(VideoPermitBridge.class);
    VideoPermitBridge nextBridge = mock(VideoPermitBridge.class);
    PlatformViewVideoPlayer player = mock(PlatformViewVideoPlayer.class);
    when(oldBridge.withClaimedVideoCreation(any(VideoPermitClaim.class), any(Runnable.class)))
        .thenAnswer(invocation -> {
          ((Runnable) invocation.getArgument(1)).run();
          return true;
        });
    when(oldBridge.isCurrentClaim(any(VideoPermitClaim.class))).thenReturn(true);
    when(oldBridge.isQuiescentForRebind()).thenReturn(true);
    plugin.installPermitBridge(mockBinaryMessenger, oldBridge);
    try (MockedStatic<PlatformViewVideoPlayer> mocked = mockStatic(PlatformViewVideoPlayer.class)) {
      mocked.when(() -> PlatformViewVideoPlayer.create(any(), any(), any(), any(), any()))
          .thenReturn(player);
      plugin.createForPlatformView(localOptions());
      assertThrows(IllegalStateException.class,
          () -> plugin.rebindPermitBridge(mockBinaryMessenger, nextBridge));
      verifyNoInteractions(nextBridge);
    }
  }

  @Test
  public void reentrantDetachDuringOldBridgeProofCannotInstallNewBridge() {
    VideoPermitBridge oldBridge = mock(VideoPermitBridge.class);
    VideoPermitBridge nextBridge = mock(VideoPermitBridge.class);
    AtomicBoolean detached = new AtomicBoolean();
    plugin.installPermitBridge(mockBinaryMessenger, oldBridge);
    when(oldBridge.isQuiescentForRebind()).thenAnswer(invocation -> {
      plugin.onDetachedFromEngine(binding);
      detached.set(true);
      return true;
    });
    assertThrows(IllegalStateException.class,
        () -> plugin.rebindPermitBridge(mockBinaryMessenger, nextBridge));
    assertTrue(detached.get());
    verifyNoInteractions(nextBridge);
  }

  @Test
  public void acceptedPlayerReleasesExactClaimOnlyAfterDispose() throws Exception {
    PlatformViewVideoPlayer player = mock(PlatformViewVideoPlayer.class);
    AtomicBoolean disposed = new AtomicBoolean();
    AtomicReference<VideoPermitClaim> createdClaim = new AtomicReference<>();
    AtomicReference<VideoPermitClaim> releasedClaim = new AtomicReference<>();
    doAnswer(invocation -> { disposed.set(true); return null; }).when(player).dispose();
    plugin.installPermitBridge(mockBinaryMessenger, new VideoPermitBridge() {
      @Override
      public boolean withClaimedVideoCreation(VideoPermitClaim claim, Runnable create) {
        createdClaim.set(claim);
        create.run();
        return true;
      }

      @Override
      public boolean isCurrentClaim(VideoPermitClaim claim) { return true; }

      @Override
      public boolean releaseVideoPlayer(VideoPermitClaim claim) {
        assertTrue(disposed.get());
        releasedClaim.set(claim);
        return true;
      }
    });
    try (MockedStatic<PlatformViewVideoPlayer> mocked =
        mockStatic(PlatformViewVideoPlayer.class)) {
      mocked.when(() -> PlatformViewVideoPlayer.create(any(), any(), any(), any(), any()))
          .thenReturn(player);
      long id = plugin.createForPlatformView(localOptions());
      assertEquals(id, createdClaim.get().getPlayerId());
      assertNull(releasedClaim.get());
      plugin.dispose(id);
      assertSame(createdClaim.get(), releasedClaim.get());
      assertEquals(0, getVideoPlayers().size());
      assertEquals(VideoPlayerPlugin.ExactCloseResult.RELEASED_EXACT,
          plugin.closeExactPlayer(mockBinaryMessenger, createdClaim.get()));
    }
  }

  @Test
  public void exactNativeCloseReleasesBeforeDartDisposeAndKeepsBoundedReceipt()
      throws Exception {
    AtomicReference<VideoPermitClaim> claim = new AtomicReference<>();
    AtomicInteger releases = new AtomicInteger();
    PlatformViewVideoPlayer player = mock(PlatformViewVideoPlayer.class);
    plugin.installPermitBridge(mockBinaryMessenger, new VideoPermitBridge() {
      @Override
      public boolean withClaimedVideoCreation(VideoPermitClaim exact, Runnable create) {
        claim.set(exact);
        create.run();
        return true;
      }

      @Override
      public boolean isCurrentClaim(VideoPermitClaim exact) { return true; }

      @Override
      public boolean releaseVideoPlayer(VideoPermitClaim exact) {
        verify(player).dispose();
        assertSame(claim.get(), exact);
        releases.incrementAndGet();
        return true;
      }
    });
    long id;
    try (MockedStatic<PlatformViewVideoPlayer> mocked =
        mockStatic(PlatformViewVideoPlayer.class)) {
      mocked.when(() -> PlatformViewVideoPlayer.create(any(), any(), any(), any(), any()))
          .thenReturn(player);
      id = plugin.createForPlatformView(localOptions());
    }
    assertEquals(VideoPlayerPlugin.ExactCloseResult.UNCONFIRMED,
        plugin.closeExactPlayer(mock(BinaryMessenger.class), claim.get()));
    assertEquals(VideoPlayerPlugin.ExactCloseResult.UNCONFIRMED,
        plugin.closeExactPlayer(mockBinaryMessenger,
            new VideoPermitClaim(localOptions().getPermit(), id)));
    verify(player, never()).dispose();
    assertEquals(VideoPlayerPlugin.ExactCloseResult.RELEASED_EXACT,
        plugin.closeExactPlayer(mockBinaryMessenger, claim.get()));
    assertEquals(1, releases.get());
    assertEquals(0, getPermitRecords().size());
    assertEquals(VideoPlayerPlugin.ExactCloseResult.RELEASED_EXACT,
        plugin.closeExactPlayer(mockBinaryMessenger, claim.get()));
    plugin.dispose(id);
    assertEquals(1, releases.get());
    verify(player, times(1)).dispose();
  }

  @Test
  public void exactCloseDuringCreateFencesPromotionAndWaitsForRollback() throws Exception {
    AtomicReference<VideoPermitClaim> claim = new AtomicReference<>();
    AtomicInteger releases = new AtomicInteger();
    PlatformViewVideoPlayer player = mock(PlatformViewVideoPlayer.class);
    plugin.installPermitBridge(mockBinaryMessenger, new VideoPermitBridge() {
      @Override
      public boolean withClaimedVideoCreation(VideoPermitClaim exact, Runnable create) {
        claim.set(exact);
        create.run();
        return true;
      }

      @Override
      public boolean isCurrentClaim(VideoPermitClaim exact) { return true; }

      @Override
      public boolean releaseVideoPlayer(VideoPermitClaim exact) {
        verify(player).dispose();
        releases.incrementAndGet();
        return true;
      }
    });
    try (MockedStatic<PlatformViewVideoPlayer> mocked =
        mockStatic(PlatformViewVideoPlayer.class)) {
      mocked.when(() -> PlatformViewVideoPlayer.create(any(), any(), any(), any(), any()))
          .thenAnswer(invocation -> {
            assertEquals(VideoPlayerPlugin.ExactCloseResult.PENDING_CREATE,
                plugin.closeExactPlayer(mockBinaryMessenger, claim.get()));
            return player;
          });
      assertThrows(IllegalStateException.class,
          () -> plugin.createForPlatformView(localOptions()));
    }
    assertEquals(1, releases.get());
    assertEquals(0, getPermitRecords().size());
    assertEquals(VideoPlayerPlugin.ExactCloseResult.RELEASED_EXACT,
        plugin.closeExactPlayer(mockBinaryMessenger, claim.get()));
  }

  @Test
  public void exactCloseFailureQuarantinesAndRetriesOnlyMatchingClaim() throws Exception {
    AtomicReference<VideoPermitClaim> claim = new AtomicReference<>();
    AtomicInteger disposals = new AtomicInteger();
    AtomicInteger releases = new AtomicInteger();
    PlatformViewVideoPlayer player = mock(PlatformViewVideoPlayer.class);
    doAnswer(invocation -> {
      if (disposals.incrementAndGet() == 1) {
        throw new IllegalStateException("Exo release unconfirmed");
      }
      return null;
    }).when(player).dispose();
    plugin.installPermitBridge(mockBinaryMessenger, new VideoPermitBridge() {
      @Override
      public boolean withClaimedVideoCreation(VideoPermitClaim exact, Runnable create) {
        claim.set(exact);
        create.run();
        return true;
      }

      @Override
      public boolean isCurrentClaim(VideoPermitClaim exact) { return true; }

      @Override
      public boolean releaseVideoPlayer(VideoPermitClaim exact) {
        return releases.incrementAndGet() == 2;
      }
    });
    long id;
    try (MockedStatic<PlatformViewVideoPlayer> mocked =
        mockStatic(PlatformViewVideoPlayer.class)) {
      mocked.when(() -> PlatformViewVideoPlayer.create(any(), any(), any(), any(), any()))
          .thenReturn(player);
      id = plugin.createForPlatformView(localOptions());
    }
    assertEquals(VideoPlayerPlugin.ExactCloseResult.UNCONFIRMED,
        plugin.closeExactPlayer(mockBinaryMessenger, claim.get()));
    assertEquals(0, releases.get());
    assertEquals(1, getPermitRecords().size());
    assertEquals(VideoPlayerPlugin.ExactCloseResult.UNCONFIRMED,
        plugin.closeExactPlayer(mockBinaryMessenger,
            new VideoPermitClaim(localOptions().getPermit(), id)));
    assertEquals(1, disposals.get());
    assertEquals(VideoPlayerPlugin.ExactCloseResult.UNCONFIRMED,
        plugin.closeExactPlayer(mockBinaryMessenger, claim.get()));
    assertEquals(2, disposals.get());
    assertEquals(1, releases.get());
    assertEquals(1, getPermitRecords().size());
    assertEquals(VideoPlayerPlugin.ExactCloseResult.RELEASED_EXACT,
        plugin.closeExactPlayer(mockBinaryMessenger, claim.get()));
    assertEquals(2, disposals.get());
    assertEquals(2, releases.get());
  }

  @Test
  public void retiredEngineExactCloseCannotTouchNewEnginePlayer() throws Exception {
    AtomicReference<VideoPermitClaim> oldClaim = new AtomicReference<>();
    plugin.installPermitBridge(mockBinaryMessenger, new VideoPermitBridge() {
      @Override
      public boolean withClaimedVideoCreation(VideoPermitClaim exact, Runnable create) {
        oldClaim.set(exact);
        create.run();
        return true;
      }

      @Override
      public boolean isCurrentClaim(VideoPermitClaim exact) { return true; }

      @Override
      public boolean releaseVideoPlayer(VideoPermitClaim exact) { return true; }
    });
    PlatformViewVideoPlayer oldPlayer = mock(PlatformViewVideoPlayer.class);
    try (MockedStatic<PlatformViewVideoPlayer> mocked =
        mockStatic(PlatformViewVideoPlayer.class)) {
      mocked.when(() -> PlatformViewVideoPlayer.create(any(), any(), any(), any(), any()))
          .thenReturn(oldPlayer);
      plugin.createForPlatformView(localOptions());
    }
    assertEquals(VideoPlayerPlugin.ExactCloseResult.RELEASED_EXACT,
        plugin.closeExactPlayer(mockBinaryMessenger, oldClaim.get()));
    plugin.onDetachedFromEngine(binding);

    BinaryMessenger nextMessenger = mock(BinaryMessenger.class);
    PlatformViewRegistry nextRegistry = mock(PlatformViewRegistry.class);
    when(nextRegistry.registerViewFactory(anyString(), any())).thenReturn(true);
    FlutterPlugin.FlutterPluginBinding nextBinding =
        mock(FlutterPlugin.FlutterPluginBinding.class);
    when(nextBinding.getApplicationContext()).thenReturn(mock(Context.class));
    when(nextBinding.getTextureRegistry()).thenReturn(mockTextureRegistry);
    when(nextBinding.getBinaryMessenger()).thenReturn(nextMessenger);
    when(nextBinding.getPlatformViewRegistry()).thenReturn(nextRegistry);
    plugin.onAttachedToEngine(nextBinding);
    plugin.installPermitBridge(nextMessenger, new VideoPermitBridge() {
      @Override
      public boolean withClaimedVideoCreation(VideoPermitClaim exact, Runnable create) {
        create.run();
        return true;
      }

      @Override
      public boolean isCurrentClaim(VideoPermitClaim exact) { return true; }

      @Override
      public boolean releaseVideoPlayer(VideoPermitClaim exact) { return true; }
    });
    PlatformViewVideoPlayer newPlayer = mock(PlatformViewVideoPlayer.class);
    long newId;
    try (MockedStatic<PlatformViewVideoPlayer> mocked =
        mockStatic(PlatformViewVideoPlayer.class)) {
      mocked.when(() -> PlatformViewVideoPlayer.create(any(), any(), any(), any(), any()))
          .thenReturn(newPlayer);
      newId = plugin.createForPlatformView(localOptions());
    }
    assertEquals(VideoPlayerPlugin.ExactCloseResult.RELEASED_EXACT,
        plugin.closeExactPlayer(mockBinaryMessenger, oldClaim.get()));
    assertEquals(VideoPlayerPlugin.ExactCloseResult.UNCONFIRMED,
        plugin.closeExactPlayer(nextMessenger, oldClaim.get()));
    verify(newPlayer, never()).dispose();
    assertSame(newPlayer, getVideoPlayers().get(newId));
    plugin.dispose(newId);
  }

  @Test
  public void failedPhysicalDisposeQuarantinesClaimUntilRetry() throws Exception {
    PlatformViewVideoPlayer player = mock(PlatformViewVideoPlayer.class);
    AtomicInteger attempts = new AtomicInteger();
    AtomicInteger releases = new AtomicInteger();
    doAnswer(invocation -> {
      if (attempts.incrementAndGet() == 1) throw new IllegalStateException("release failed");
      return null;
    }).when(player).dispose();
    plugin.installPermitBridge(mockBinaryMessenger, new VideoPermitBridge() {
      @Override
      public boolean withClaimedVideoCreation(VideoPermitClaim claim, Runnable create) {
        create.run();
        return true;
      }

      @Override
      public boolean isCurrentClaim(VideoPermitClaim claim) { return true; }

      @Override
      public boolean releaseVideoPlayer(VideoPermitClaim claim) {
        releases.incrementAndGet();
        return true;
      }
    });
    try (MockedStatic<PlatformViewVideoPlayer> mocked =
        mockStatic(PlatformViewVideoPlayer.class)) {
      mocked.when(() -> PlatformViewVideoPlayer.create(any(), any(), any(), any(), any()))
          .thenReturn(player);
      long id = plugin.createForPlatformView(localOptions());
      assertThrows(IllegalStateException.class, () -> plugin.dispose(id));
      assertEquals(0, releases.get());
      assertSame(player, getVideoPlayers().get(id));
      plugin.dispose(id);
      assertEquals(1, releases.get());
      assertEquals(0, getVideoPlayers().size());
    }
  }

  @Test
  public void fenceAfterCreationRollsBackBeforeExactRelease() throws Exception {
    PlatformViewVideoPlayer player = mock(PlatformViewVideoPlayer.class);
    AtomicBoolean disposed = new AtomicBoolean();
    AtomicInteger releases = new AtomicInteger();
    doAnswer(invocation -> { disposed.set(true); return null; }).when(player).dispose();
    plugin.installPermitBridge(mockBinaryMessenger, new VideoPermitBridge() {
      @Override
      public boolean withClaimedVideoCreation(VideoPermitClaim claim, Runnable create) {
        create.run();
        return false;
      }

      @Override
      public boolean isCurrentClaim(VideoPermitClaim claim) { return true; }

      @Override
      public boolean releaseVideoPlayer(VideoPermitClaim claim) {
        assertTrue(disposed.get());
        releases.incrementAndGet();
        return true;
      }
    });
    try (MockedStatic<PlatformViewVideoPlayer> mocked =
        mockStatic(PlatformViewVideoPlayer.class)) {
      mocked.when(() -> PlatformViewVideoPlayer.create(any(), any(), any(), any(), any()))
          .thenReturn(player);
      assertThrows(IllegalStateException.class,
          () -> plugin.createForPlatformView(localOptions()));
      assertEquals(1, releases.get());
      assertEquals(0, getVideoPlayers().size());
    }
  }

  @Test
  public void textureCreationRemainsDenied() throws Exception {
    try (MockedStatic<TextureVideoPlayer> mockedTextureVideoPlayerStatic =
        mockStatic(TextureVideoPlayer.class)) {
      mockedTextureVideoPlayerStatic
          .when(() -> TextureVideoPlayer.create(any(), any(), any(), any(), any()))
          .thenReturn(mock(TextureVideoPlayer.class));

      assertThrows(IllegalStateException.class,
          () -> plugin.createForTextureView(localOptions()));
      mockedTextureVideoPlayerStatic.verifyNoInteractions();
      assertEquals(0, getVideoPlayers().size());
    }
  }

  @Test
  public void globalInitializationAndMixingRemainDenied() {
    assertThrows(IllegalStateException.class, plugin::initialize);
    assertThrows(IllegalStateException.class, () -> plugin.setMixWithOthers(true));
  }

  @Test
  public void reentrantDetachBeforePlayerReturnsCannotPublishOldEnginePlayer() throws Exception {
    PlatformViewVideoPlayer player = mock(PlatformViewVideoPlayer.class);
    AtomicInteger releases = new AtomicInteger();
    plugin.installPermitBridge(mockBinaryMessenger, new VideoPermitBridge() {
      @Override
      public boolean withClaimedVideoCreation(VideoPermitClaim claim, Runnable create) {
        create.run();
        return true;
      }

      @Override
      public boolean isCurrentClaim(VideoPermitClaim claim) { return true; }

      @Override
      public boolean releaseVideoPlayer(VideoPermitClaim claim) {
        releases.incrementAndGet();
        return true;
      }
    });
    try (MockedStatic<PlatformViewVideoPlayer> mocked =
        mockStatic(PlatformViewVideoPlayer.class)) {
      mocked.when(() -> PlatformViewVideoPlayer.create(any(), any(), any(), any(), any()))
          .thenAnswer(invocation -> {
            plugin.onDetachedFromEngine(binding);
            return player;
          });
      assertThrows(IllegalStateException.class,
          () -> plugin.createForPlatformView(localOptions()));
      verify(player).dispose();
      assertEquals(1, releases.get());
      assertEquals(0, getVideoPlayers().size());
      assertEquals(0, getPermitRecords().size());
    }
  }

  @Test
  public void detachDuringEventBindingStopsBeforeNativePlayerCreation() throws Exception {
    AtomicBoolean detached = new AtomicBoolean();
    doAnswer(invocation -> {
      String channel = invocation.getArgument(0);
      Object handler = invocation.getArgument(1);
      if (channel.startsWith("dev.flutter.pigeon.video_player_android.VideoEventChannel.") &&
          handler != null && detached.compareAndSet(false, true)) {
        plugin.onDetachedFromEngine(binding);
      }
      return null;
    }).when(mockBinaryMessenger).setMessageHandler(anyString(), any());
    AtomicInteger releases = new AtomicInteger();
    plugin.installPermitBridge(mockBinaryMessenger, new VideoPermitBridge() {
      @Override
      public boolean withClaimedVideoCreation(VideoPermitClaim claim, Runnable create) {
        create.run();
        return true;
      }

      @Override
      public boolean isCurrentClaim(VideoPermitClaim claim) { return true; }

      @Override
      public boolean releaseVideoPlayer(VideoPermitClaim claim) {
        releases.incrementAndGet();
        return true;
      }
    });
    try (MockedStatic<PlatformViewVideoPlayer> mocked =
        mockStatic(PlatformViewVideoPlayer.class)) {
      assertThrows(IllegalStateException.class,
          () -> plugin.createForPlatformView(localOptions()));
      mocked.verifyNoInteractions();
    }
    assertTrue(detached.get());
    assertEquals(1, releases.get());
    assertEquals(0, getPermitRecords().size());
  }

  @Test
  public void failedDetachCannotExposeOldPlayerToReattachedEngine() throws Exception {
    PlatformViewVideoPlayer player = mock(PlatformViewVideoPlayer.class);
    AtomicInteger disposals = new AtomicInteger();
    doAnswer(invocation -> {
      if (disposals.incrementAndGet() <= 2) {
        throw new IllegalStateException("Exo release unconfirmed");
      }
      return null;
    }).when(player).dispose();
    plugin.installPermitBridge(mockBinaryMessenger, new VideoPermitBridge() {
      @Override
      public boolean withClaimedVideoCreation(VideoPermitClaim claim, Runnable create) {
        create.run();
        return true;
      }

      @Override
      public boolean isCurrentClaim(VideoPermitClaim claim) { return true; }

      @Override
      public boolean releaseVideoPlayer(VideoPermitClaim claim) { return true; }
    });
    long id;
    try (MockedStatic<PlatformViewVideoPlayer> mocked =
        mockStatic(PlatformViewVideoPlayer.class)) {
      mocked.when(() -> PlatformViewVideoPlayer.create(any(), any(), any(), any(), any()))
          .thenReturn(player);
      id = plugin.createForPlatformView(localOptions());
    }
    assertThrows(IllegalStateException.class, () -> plugin.onDetachedFromEngine(binding));
    BinaryMessenger nextMessenger = mock(BinaryMessenger.class);
    PlatformViewRegistry nextRegistry = mock(PlatformViewRegistry.class);
    FlutterPlugin.FlutterPluginBinding nextBinding =
        mock(FlutterPlugin.FlutterPluginBinding.class);
    when(nextBinding.getApplicationContext()).thenReturn(mock(Context.class));
    when(nextBinding.getTextureRegistry()).thenReturn(mockTextureRegistry);
    when(nextBinding.getBinaryMessenger()).thenReturn(nextMessenger);
    when(nextBinding.getPlatformViewRegistry()).thenReturn(nextRegistry);
    when(nextRegistry.registerViewFactory(anyString(), any())).thenReturn(true);

    assertThrows(IllegalStateException.class, () -> plugin.onAttachedToEngine(nextBinding));
    verifyNoInteractions(nextRegistry);
    plugin.onAttachedToEngine(nextBinding);
    ArgumentCaptor<PlatformVideoViewFactory> factory =
        ArgumentCaptor.forClass(PlatformVideoViewFactory.class);
    verify(nextRegistry).registerViewFactory(
        eq("plugins.flutter.dev/video_player_android"), factory.capture());
    assertThrows(IllegalStateException.class, () -> factory.getValue().create(
        mock(Context.class), 1, new PlatformVideoViewCreationParams(id)));
    assertEquals(0, getPermitRecords().size());
  }

  @Test
  public void eventBindFailureKeepsPrePlayerClaimUntilExactReleaseRetry() throws Exception {
    AtomicBoolean failBind = new AtomicBoolean(true);
    doAnswer(invocation -> {
      String channel = invocation.getArgument(0);
      Object handler = invocation.getArgument(1);
      if (channel.startsWith("dev.flutter.pigeon.video_player_android.VideoEventChannel.") &&
          handler != null && failBind.getAndSet(false)) {
        throw new IllegalStateException("event bind failed");
      }
      return null;
    }).when(mockBinaryMessenger).setMessageHandler(anyString(), any());
    AtomicInteger releases = new AtomicInteger();
    plugin.installPermitBridge(mockBinaryMessenger, new VideoPermitBridge() {
      @Override
      public boolean withClaimedVideoCreation(VideoPermitClaim claim, Runnable create) {
        create.run();
        return true;
      }

      @Override
      public boolean isCurrentClaim(VideoPermitClaim claim) { return true; }

      @Override
      public boolean releaseVideoPlayer(VideoPermitClaim claim) {
        return releases.incrementAndGet() == 2;
      }
    });
    try (MockedStatic<PlatformViewVideoPlayer> mocked =
        mockStatic(PlatformViewVideoPlayer.class)) {
      assertThrows(IllegalStateException.class,
          () -> plugin.createForPlatformView(localOptions()));
      mocked.verifyNoInteractions();
    }
    assertEquals(1, releases.get());
    assertEquals(1, getPermitRecords().size());
    plugin.onDestroy();
    assertEquals(2, releases.get());
    assertEquals(0, getPermitRecords().size());
  }

  @Test
  public void fencedClaimIsDeniedBeforeEventBindingOrExoCreation() throws Exception {
    AtomicInteger releases = new AtomicInteger();
    plugin.installPermitBridge(mockBinaryMessenger, new VideoPermitBridge() {
      @Override
      public boolean withClaimedVideoCreation(VideoPermitClaim claim, Runnable create) {
        create.run();
        return true;
      }

      @Override
      public boolean isCurrentClaim(VideoPermitClaim claim) { return false; }

      @Override
      public boolean releaseVideoPlayer(VideoPermitClaim claim) {
        releases.incrementAndGet();
        return true;
      }
    });
    try (MockedStatic<PlatformViewVideoPlayer> mocked =
        mockStatic(PlatformViewVideoPlayer.class)) {
      assertThrows(IllegalStateException.class,
          () -> plugin.createForPlatformView(localOptions()));
      mocked.verifyNoInteractions();
    }
    assertEquals(1, releases.get());
    assertEquals(0, getPermitRecords().size());
    verify(mockBinaryMessenger, never()).setMessageHandler(
        startsWith("dev.flutter.pigeon.video_player_android.VideoEventChannel."), any());
  }

  @Test
  public void activeClaimFenceDeniesNewPlatformViewBinding() {
    AtomicBoolean current = new AtomicBoolean(true);
    plugin.installPermitBridge(mockBinaryMessenger, new VideoPermitBridge() {
      @Override
      public boolean withClaimedVideoCreation(VideoPermitClaim claim, Runnable create) {
        create.run();
        return true;
      }

      @Override
      public boolean isCurrentClaim(VideoPermitClaim claim) { return current.get(); }

      @Override
      public boolean releaseVideoPlayer(VideoPermitClaim claim) { return true; }
    });
    PlatformViewVideoPlayer player = mock(PlatformViewVideoPlayer.class);
    long id;
    try (MockedStatic<PlatformViewVideoPlayer> mocked =
        mockStatic(PlatformViewVideoPlayer.class)) {
      mocked.when(() -> PlatformViewVideoPlayer.create(any(), any(), any(), any(), any()))
          .thenReturn(player);
      id = plugin.createForPlatformView(localOptions());
    }
    ArgumentCaptor<PlatformVideoViewFactory> factory =
        ArgumentCaptor.forClass(PlatformVideoViewFactory.class);
    verify(mockPlatformViewRegistry).registerViewFactory(
        eq("plugins.flutter.dev/video_player_android"), factory.capture());
    current.set(false);
    assertThrows(IllegalStateException.class, () -> factory.getValue().create(
        mock(Context.class), 1, new PlatformVideoViewCreationParams(id)));
    plugin.dispose(id);
  }

  @Test
  public void confirmedConstructorCleanupKeepsClaimWhenReleaseAckIsFalse() throws Exception {
    AtomicInteger releases = new AtomicInteger();
    plugin.installPermitBridge(mockBinaryMessenger, new VideoPermitBridge() {
      @Override
      public boolean withClaimedVideoCreation(VideoPermitClaim claim, Runnable create) {
        create.run();
        return true;
      }

      @Override
      public boolean isCurrentClaim(VideoPermitClaim claim) { return true; }

      @Override
      public boolean releaseVideoPlayer(VideoPermitClaim claim) {
        return releases.incrementAndGet() == 2;
      }
    });
    try (MockedStatic<PlatformViewVideoPlayer> mocked =
        mockStatic(PlatformViewVideoPlayer.class)) {
      mocked.when(() -> PlatformViewVideoPlayer.create(any(), any(), any(), any(), any()))
          .thenThrow(new VideoPlayer.CreationFailure(
              new IllegalStateException("prepare failed"), true));
      assertThrows(VideoPlayer.CreationFailure.class,
          () -> plugin.createForPlatformView(localOptions()));
    }
    assertEquals(1, releases.get());
    assertEquals(1, getPermitRecords().size());
    plugin.onDestroy();
    assertEquals(2, releases.get());
    assertEquals(0, getPermitRecords().size());
  }

  @Test
  public void partialInstanceRegistrationMustRetryUnbindBeforeExactRelease() throws Exception {
    Map<String, Object> handlers = new HashMap<>();
    AtomicInteger instanceRegistrations = new AtomicInteger();
    AtomicBoolean failUnbind = new AtomicBoolean(true);
    doAnswer(invocation -> {
      String channel = invocation.getArgument(0);
      Object handler = invocation.getArgument(1);
      if (handler != null) {
        if (channel.contains("VideoPlayerInstanceApi.") &&
            instanceRegistrations.incrementAndGet() == 3) {
          throw new IllegalStateException("partial instance registration");
        }
        handlers.put(channel, handler);
      } else {
        if (channel.contains("VideoPlayerInstanceApi.") && failUnbind.getAndSet(false)) {
          throw new IllegalStateException("first instance unbind failed");
        }
        handlers.remove(channel);
      }
      return null;
    }).when(mockBinaryMessenger).setMessageHandler(anyString(), any());
    PlatformViewVideoPlayer player = mock(PlatformViewVideoPlayer.class);
    AtomicReference<VideoPlayer.DisposeHandler> disposeHandler = new AtomicReference<>();
    doAnswer(invocation -> {
      disposeHandler.set(invocation.getArgument(0));
      return null;
    }).when(player).setDisposeHandler(any());
    doAnswer(invocation -> {
      if (disposeHandler.get() != null) disposeHandler.get().onDispose();
      return null;
    }).when(player).dispose();
    AtomicInteger releases = new AtomicInteger();
    plugin.installPermitBridge(mockBinaryMessenger, new VideoPermitBridge() {
      @Override
      public boolean withClaimedVideoCreation(VideoPermitClaim claim, Runnable create) {
        create.run();
        return true;
      }

      @Override
      public boolean isCurrentClaim(VideoPermitClaim claim) { return true; }

      @Override
      public boolean releaseVideoPlayer(VideoPermitClaim claim) {
        releases.incrementAndGet();
        return true;
      }
    });
    try (MockedStatic<PlatformViewVideoPlayer> mocked =
        mockStatic(PlatformViewVideoPlayer.class)) {
      mocked.when(() -> PlatformViewVideoPlayer.create(any(), any(), any(), any(), any()))
          .thenReturn(player);
      assertThrows(IllegalStateException.class,
          () -> plugin.createForPlatformView(localOptions()));
    }
    assertEquals(0, releases.get());
    assertEquals(1, getPermitRecords().size());
    plugin.onDestroy();
    assertEquals(1, releases.get());
    assertEquals(0, getPermitRecords().size());
    assertTrue(handlers.keySet().stream().noneMatch(
        channel -> channel.contains("VideoPlayerInstanceApi.") ||
            channel.contains("VideoEventChannel.")));
  }
}
