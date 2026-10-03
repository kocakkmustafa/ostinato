// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package io.flutter.plugins.videoplayer;

import android.content.Context;
import android.os.Looper;
import android.util.LongSparseArray;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.annotation.OptIn;
import androidx.media3.common.util.UnstableApi;
import io.flutter.FlutterInjector;
import io.flutter.Log;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugins.videoplayer.platformview.PlatformVideoViewFactory;
import io.flutter.plugins.videoplayer.platformview.PlatformViewVideoPlayer;
import io.flutter.plugins.videoplayer.texture.TextureVideoPlayer;
import io.flutter.view.TextureRegistry;
import java.util.ArrayList;

/** Android platform implementation of the VideoPlayerPlugin. */
public class VideoPlayerPlugin implements FlutterPlugin, AndroidVideoPlayerApi {
  private static final String TAG = "VideoPlayerPlugin";

  /** Result of an app-owned, exact native close request. */
  public enum ExactCloseResult {
    RELEASED_EXACT,
    PENDING_CREATE,
    UNCONFIRMED
  }

  private final LongSparseArray<VideoPlayer> videoPlayers = new LongSparseArray<>();
  private final LongSparseArray<PermitRecord> permitRecords = new LongSparseArray<>();
  private final ArrayList<GlobalApiRegistration> globalApiRegistrations = new ArrayList<>();
  @Nullable private ReleasedExactPlayer releasedExactPlayer;
  private FlutterState flutterState;
  @Nullable private VideoPermitBridge permitBridge;
  private final VideoPlayerOptions sharedOptions = new VideoPlayerOptions();
  private long nextPlayerIdentifier = 1;
  private long engineEpoch = 0;

  /** Register this with the v2 embedding for the plugin to respond to lifecycle callbacks. */
  public VideoPlayerPlugin() {}

  /** Installs an app-owned bridge on this plugin instance for its exact engine messenger. */
  public void installPermitBridge(
      @NonNull BinaryMessenger engineMessenger, @NonNull VideoPermitBridge bridge) {
    requireMainThread();
    if (flutterState == null || flutterState.binaryMessenger != engineMessenger ||
        permitBridge != null || permitRecords.size() != 0 || videoPlayers.size() != 0 ||
        !findGlobalApiRegistration(flutterState).active) {
      throw new IllegalStateException("Native video permit bridge has no matching engine");
    }
    permitBridge = bridge;
  }

  /** Rebinds a reused engine only after the old bridge and all native records are quiescent. */
  public void rebindPermitBridge(
      @NonNull BinaryMessenger engineMessenger, @NonNull VideoPermitBridge nextBridge) {
    requireMainThread();
    final FlutterState state = flutterState;
    final VideoPermitBridge oldBridge = permitBridge;
    if (state == null || state.binaryMessenger != engineMessenger || oldBridge == null ||
        nextBridge == null ||
        oldBridge == nextBridge || !findGlobalApiRegistration(state).active ||
        permitRecords.size() != 0 || videoPlayers.size() != 0) {
      throw new IllegalStateException("Native video bridge is not ready for rebind");
    }
    final long epoch = engineEpoch;
    final boolean oldQuiescent;
    try {
      oldQuiescent = oldBridge.isQuiescentForRebind();
    } catch (RuntimeException failure) {
      throw new IllegalStateException("Old native video bridge proof failed", failure);
    }
    // The proof callback is app-owned. A synchronous detach or new create must not
    // make the earlier state check usable for another plugin epoch or player.
    if (!oldQuiescent || flutterState != state || engineEpoch != epoch ||
        permitBridge != oldBridge || !findGlobalApiRegistration(state).active ||
        permitRecords.size() != 0 || videoPlayers.size() != 0) {
      throw new IllegalStateException("Native video bridge rebind was not quiescent");
    }
    releasedExactPlayer = null;
    permitBridge = nextBridge;
  }

  private static void requireMainThread() {
    if (Looper.myLooper() != Looper.getMainLooper()) {
      throw new IllegalStateException("Native video permits require the main thread");
    }
  }

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
    requireMainThread();
    if (flutterState != null) {
      throw new IllegalStateException("Video plugin is already attached");
    }
    drainGlobalApiRegistrations();
    disposeAllRecords();
    if (permitRecords.size() != 0) {
      throw new IllegalStateException("Retired native video claims are not released");
    }
    advanceEngineEpoch();
    permitBridge = null;
    final FlutterInjector injector = FlutterInjector.instance();
    final FlutterState state =
        new FlutterState(
            binding.getApplicationContext(),
            binding.getBinaryMessenger(),
            injector.flutterLoader()::getLookupKeyForAsset,
            injector.flutterLoader()::getLookupKeyForAsset,
            binding.getTextureRegistry());
    final long attachedEpoch = engineEpoch;
    final GlobalApiRegistration registration =
        new GlobalApiRegistration(state, attachedEpoch);
    globalApiRegistrations.add(registration);
    flutterState = state;
    try {
      state.startListening(new EngineBoundApi(this, registration), state.binaryMessenger);
      if (flutterState != state || engineEpoch != attachedEpoch) {
        throw new IllegalStateException("Native video engine detached during registration");
      }
      if (!binding
          .getPlatformViewRegistry()
          .registerViewFactory(
              "plugins.flutter.dev/video_player_android",
              new PlatformVideoViewFactory(
                  playerId -> playerForPlatformView(state, attachedEpoch, playerId)))) {
        throw new IllegalStateException("Native video platform view factory registration failed");
      }
      if (flutterState != state || engineEpoch != attachedEpoch) {
        throw new IllegalStateException("Native video engine detached during factory registration");
      }
      registration.registrationInFlight = false;
      registration.active = true;
    } catch (Throwable failure) {
      registration.registrationInFlight = false;
      registration.active = false;
      if (flutterState == state) {
        flutterState = null;
        permitBridge = null;
        advanceEngineEpoch();
      }
      try {
        retireGlobalApiRegistration(registration);
      } catch (Throwable cleanupFailure) {
        if (failure != cleanupFailure) failure.addSuppressed(cleanupFailure);
      }
      throw unchecked(failure);
    }
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    requireMainThread();
    if (flutterState == null) {
      Log.wtf(TAG, "Detached from the engine before registering to it.");
      return;
    }
    final FlutterState state = flutterState;
    if (state.binaryMessenger != binding.getBinaryMessenger()) {
      throw new IllegalStateException("Native video detach has a stale engine messenger");
    }
    final GlobalApiRegistration registration = findGlobalApiRegistration(state);
    advanceEngineEpoch();
    flutterState = null;
    permitBridge = null;
    registration.active = false;
    for (int i = 0; i < permitRecords.size(); i++) {
      PermitRecord record = permitRecords.valueAt(i);
      if (record.state == state) {
        record.phase = PermitPhase.CLOSING;
        if (record.player != null) record.player.revoke();
      }
    }
    Throwable failure = null;
    try {
      retireGlobalApiRegistration(registration);
    } catch (Throwable cleanupFailure) {
      failure = cleanupFailure;
    }
    try {
      onDestroy();
    } catch (Throwable cleanupFailure) {
      if (failure == null) failure = cleanupFailure;
      else if (failure != cleanupFailure) failure.addSuppressed(cleanupFailure);
    }
    if (failure != null) {
      throw unchecked(failure);
    }
  }

  private void advanceEngineEpoch() {
    if (engineEpoch == Long.MAX_VALUE) {
      throw new IllegalStateException("Native video engine epochs exhausted");
    }
    engineEpoch++;
  }

  private GlobalApiRegistration findGlobalApiRegistration(FlutterState state) {
    for (GlobalApiRegistration registration : globalApiRegistrations) {
      if (registration.state == state) return registration;
    }
    throw new IllegalStateException("Native video engine has no global handler receipt");
  }

  private void retireGlobalApiRegistration(GlobalApiRegistration registration) {
    if (registration.registrationInFlight) return;
    if (registration.cleanupInProgress) {
      throw new IllegalStateException("Native video global handler cleanup is already running");
    }
    registration.cleanupInProgress = true;
    try {
      if (!registration.handlersCleared) {
        registration.state.stopListening(registration.state.binaryMessenger);
        registration.handlersCleared = true;
      }
      globalApiRegistrations.remove(registration);
    } finally {
      registration.cleanupInProgress = false;
    }
  }

  private void drainGlobalApiRegistrations() {
    Throwable failure = null;
    for (int i = globalApiRegistrations.size() - 1; i >= 0; i--) {
      GlobalApiRegistration registration = globalApiRegistrations.get(i);
      if (registration.registrationInFlight || registration.active ||
          registration.cleanupInProgress) {
        throw new IllegalStateException("Retired native video global handlers are still live");
      }
      try {
        retireGlobalApiRegistration(registration);
      } catch (Throwable cleanupFailure) {
        if (failure == null) failure = cleanupFailure;
        else if (failure != cleanupFailure) failure.addSuppressed(cleanupFailure);
      }
    }
    if (failure != null) throw unchecked(failure);
    if (!globalApiRegistrations.isEmpty()) {
      throw new IllegalStateException("Retired native video global handlers are not cleared");
    }
  }

  private VideoPlayer playerForPlatformView(FlutterState state, long epoch, Long playerId) {
    requireMainThread();
    if (playerId == null) {
      throw new IllegalStateException("Platform view has no native video player id");
    }
    PermitRecord record = permitRecords.get(playerId);
    if (flutterState != state || engineEpoch != epoch || permitBridge == null ||
        record == null || record.state != state || record.epoch != epoch ||
        record.phase != PermitPhase.ACTIVE || record.player == null) {
      throw new IllegalStateException("Platform view has no current native video permit");
    }
    if (!record.bridge.isCurrentClaim(record.claim) ||
        flutterState != state || engineEpoch != epoch || permitBridge != record.bridge ||
        record.phase != PermitPhase.ACTIVE) {
      throw new IllegalStateException("Platform view native video claim is no longer current");
    }
    return record.player;
  }

  private void disposeAllRecords() {
    Throwable failure = null;
    for (int i = permitRecords.size() - 1; i >= 0; i--) {
      PermitRecord record = permitRecords.valueAt(i);
      record.phase = PermitPhase.CLOSING;
      if (record.player != null) record.player.revoke();
      if (record.creationInFlight) continue;
      try {
        cleanupRecord(record);
      } catch (Throwable cleanupFailure) {
        if (failure == null) failure = cleanupFailure;
        else if (failure != cleanupFailure) failure.addSuppressed(cleanupFailure);
      }
    }
    if (failure != null) {
      throw unchecked(failure);
    }
  }

  public void onDestroy() {
    // The whole FlutterView is being destroyed. Here we release resources acquired for all
    // instances
    // of VideoPlayer. Once https://github.com/flutter/flutter/issues/19358 is resolved this may
    // be replaced with just asserting that videoPlayers.isEmpty().
    // https://github.com/flutter/flutter/issues/20989 tracks this.
    requireMainThread();
    disposeAllRecords();
  }

  @Override
  public void initialize() {
    throw new IllegalStateException("Global video initialization has no native permit");
  }

  @OptIn(markerClass = UnstableApi.class)
  @Override
  public long createForPlatformView(@NonNull CreationOptions options) {
    requireMainThread();
    final FlutterState state = flutterState;
    if (state == null) {
      throw new IllegalStateException("Video plugin is detached");
    }
    final VideoPermitBridge bridge = permitBridge;
    if (bridge == null) {
      // The hosted app has not installed an engine-bound adapter. Stay fail-closed.
      throw new IllegalStateException("Native video permit bridge is not installed");
    }
    ensureNoOutstandingClaims();
    final String uri = options.getUri();
    if (!uri.startsWith("/") || uri.startsWith("//") || uri.indexOf('\0') >= 0 ||
        options.getFormatHint() != null || !options.getHttpHeaders().isEmpty() ||
        options.getUserAgent() != null) {
      throw new IllegalArgumentException("Permitted native video requires a local file path");
    }
    if (nextPlayerIdentifier < 1 || nextPlayerIdentifier == Long.MAX_VALUE) {
      throw new IllegalStateException("Native video player ids exhausted");
    }
    final long id = nextPlayerIdentifier++;
    final VideoPermitClaim claim = new VideoPermitClaim(options.getPermit(), id);
    final PermitRecord record = new PermitRecord(claim, bridge, state, engineEpoch, id);
    final boolean[] entered = new boolean[1];
    final boolean[] callbackOpen = new boolean[] {true};
    final String suffix = Long.toString(id);
    try {
      boolean accepted;
      try {
        accepted = bridge.withClaimedVideoCreation(claim, () -> {
          requireMainThread();
          if (!callbackOpen[0]) {
            throw new IllegalStateException("Native video creation callback is no longer live");
          }
          callbackOpen[0] = false;
          entered[0] = true;
          permitRecords.put(id, record);
          assertCurrentClaim(record);
          VideoPlayerOptions playerOptions = new VideoPlayerOptions();
          playerOptions.mixWithOthers = options.getMixWithOthers();
          playerOptions.backBufferDurationMs = options.getBackBufferDurationMs();
          VideoPlayerEventCallbacks callbacks =
              VideoPlayerEventCallbacks.bindTo(state.binaryMessenger, suffix);
          assertCurrentClaim(record);
          record.nativeAllocationStarted = true;
          record.player = PlatformViewVideoPlayer.create(
              state.applicationContext,
              callbacks,
              new LocalVideoAsset(uri),
              playerOptions,
              () -> assertCurrentClaim(record));
          assertCurrentClaim(record);
          videoPlayers.put(id, record.player);
          registerPlayerInstance(record.player, id, state.binaryMessenger);
          assertCurrentClaim(record);
          record.registrationComplete = true;
        });
      } finally {
        callbackOpen[0] = false;
      }
      if (!entered[0] || !accepted || !record.registrationComplete) {
        throw new IllegalStateException("Native video permit was rejected or fenced");
      }
      assertCurrentClaim(record);
      record.creationInFlight = false;
      record.phase = PermitPhase.ACTIVE;
      return id;
    } catch (Throwable failure) {
      if (entered[0]) {
        record.creationInFlight = false;
        record.phase = PermitPhase.CLOSING;
        if (failure instanceof VideoPlayer.CreationFailure &&
            ((VideoPlayer.CreationFailure) failure).isCleanupConfirmed()) {
          record.nativeCleanupConfirmed = true;
        }
        try {
          cleanupRecord(record);
        } catch (Throwable cleanupFailure) {
          if (failure != cleanupFailure) failure.addSuppressed(cleanupFailure);
        }
      }
      throw unchecked(failure);
    }
  }

  private void assertCurrentClaim(PermitRecord record) {
    requireMainThread();
    if (flutterState != record.state || engineEpoch != record.epoch ||
        permitBridge != record.bridge || record.phase != PermitPhase.CREATING) {
      throw new IllegalStateException("Native video engine was fenced during creation");
    }
    if (!record.bridge.isCurrentClaim(record.claim)) {
      throw new IllegalStateException("Native video claim is no longer current");
    }
    if (flutterState != record.state || engineEpoch != record.epoch ||
        permitBridge != record.bridge || record.phase != PermitPhase.CREATING) {
      throw new IllegalStateException("Native video engine was fenced during claim readback");
    }
  }

  private void ensureNoOutstandingClaims() {
    for (int i = permitRecords.size() - 1; i >= 0; i--) {
      PermitRecord record = permitRecords.valueAt(i);
      if (record.phase != PermitPhase.ACTIVE) {
        cleanupRecord(record);
      }
    }
    if (permitRecords.size() != 0) {
      throw new IllegalStateException("Another native video claim is still held");
    }
  }

  private void cleanupRecord(PermitRecord record) {
    requireMainThread();
    record.phase = PermitPhase.CLOSING;
    if (record.player != null) record.player.revoke();
    if (record.creationInFlight) return;
    if (record.cleanupInProgress) {
      throw new IllegalStateException("Native video cleanup is already running");
    }
    record.cleanupInProgress = true;
    try {
      Throwable failure = null;
      if (record.player != null && !record.nativeCleanupConfirmed) {
        try {
          record.player.dispose();
          record.nativeCleanupConfirmed = true;
        } catch (Throwable cleanupFailure) {
          failure = cleanupFailure;
        }
      } else if (record.player == null && !record.nativeAllocationStarted) {
        record.nativeCleanupConfirmed = true;
      }
      if (!record.channelsCleared) {
        try {
          unregisterPlayerChannels(record.state.binaryMessenger, Long.toString(record.id));
          record.channelsCleared = true;
        } catch (Throwable cleanupFailure) {
          if (failure == null) failure = cleanupFailure;
          else if (failure != cleanupFailure) failure.addSuppressed(cleanupFailure);
        }
      }
      if (failure != null) throw unchecked(failure);
      if (!record.nativeCleanupConfirmed || !record.channelsCleared) {
        throw new IllegalStateException("Native video cleanup is unconfirmed");
      }
      if (!record.bridge.releaseVideoPlayer(record.claim)) {
        throw new IllegalStateException("Exact native video release was not acknowledged");
      }
      videoPlayers.remove(record.id);
      permitRecords.remove(record.id);
      // One plugin-local receipt is enough for the just-closed player. Eviction denies an older
      // acknowledgement rather than allowing it to apply to a later engine or player.
      releasedExactPlayer = new ReleasedExactPlayer(record);
    } catch (Throwable failure) {
      record.phase = PermitPhase.QUARANTINED;
      throw unchecked(failure);
    } finally {
      record.cleanupInProgress = false;
    }
  }

  private static RuntimeException unchecked(Throwable failure) {
    if (failure instanceof Error) throw (Error) failure;
    if (failure instanceof RuntimeException) return (RuntimeException) failure;
    return new IllegalStateException("Native video operation failed", failure);
  }

  private static void unregisterPlayerChannels(BinaryMessenger messenger, String suffix) {
    Throwable failure = null;
    try {
      VideoPlayerInstanceApi.Companion.setUp(messenger, null, suffix);
    } catch (Throwable cleanupFailure) {
      failure = cleanupFailure;
    }
    try {
      VideoPlayerEventCallbacks.unbindFrom(messenger, suffix);
    } catch (Throwable cleanupFailure) {
      if (failure == null) failure = cleanupFailure;
      else if (failure != cleanupFailure) failure.addSuppressed(cleanupFailure);
    }
    if (failure != null) throw unchecked(failure);
  }

  @OptIn(markerClass = UnstableApi.class)
  @Override
  public @NonNull TexturePlayerIds createForTextureView(@NonNull CreationOptions options) {
    if (flutterState == null) {
      throw new IllegalStateException("Video plugin is detached");
    }
    // Deny before SurfaceProducer, texture, player, focus, or prepare.
    throw new IllegalStateException("Native video permit bridge is not installed");
  }

  private @NonNull VideoAsset videoAssetWithOptions(@NonNull CreationOptions options) {
    final @NonNull String uri = options.getUri();
    if (uri.startsWith("asset:")) {
      return VideoAsset.fromAssetUrl(uri);
    } else if (uri.startsWith("rtsp:")) {
      return VideoAsset.fromRtspUrl(uri);
    } else {
      VideoAsset.StreamingFormat streamingFormat = VideoAsset.StreamingFormat.UNKNOWN;
      PlatformVideoFormat formatHint = options.getFormatHint();
      if (formatHint != null) {
        switch (formatHint) {
          case SS:
            streamingFormat = VideoAsset.StreamingFormat.SMOOTH;
            break;
          case DASH:
            streamingFormat = VideoAsset.StreamingFormat.DYNAMIC_ADAPTIVE;
            break;
          case HLS:
            streamingFormat = VideoAsset.StreamingFormat.HTTP_LIVE;
            break;
        }
      }
      return VideoAsset.fromRemoteUrl(
          uri, streamingFormat, options.getHttpHeaders(), options.getUserAgent());
    }
  }

  private void registerPlayerInstance(VideoPlayer player, long id, BinaryMessenger messenger) {
    // Set up the instance-specific API handler, and make sure it is removed when the player is
    // disposed.
    final String channelSuffix = Long.toString(id);
    player.setDisposeHandler(() -> unregisterPlayerChannels(messenger, channelSuffix));
    VideoPlayerInstanceApi.Companion.setUp(messenger, player, channelSuffix);
  }

  @NonNull
  private VideoPlayer getPlayer(long playerId) {
    VideoPlayer player = videoPlayers.get(playerId);

    // Avoid a very ugly un-debuggable NPE that results in returning a null player.
    if (player == null) {
      String message = "No player found with playerId <" + playerId + ">";
      if (videoPlayers.size() == 0) {
        message += " and no active players created by the plugin.";
      }
      throw new IllegalStateException(message);
    }

    return player;
  }

  @Override
  public void dispose(long playerId) {
    requireMainThread();
    FlutterState state = flutterState;
    if (state == null) {
      throw new IllegalStateException("Native video player has no current engine");
    }
    disposeForEngine(state, engineEpoch, playerId);
  }

  private void disposeForEngine(FlutterState state, long epoch, long playerId) {
    PermitRecord record = permitRecords.get(playerId);
    if (record == null) {
      if (releasedExactPlayer != null &&
          releasedExactPlayer.matches(state, epoch, playerId)) return;
      throw new IllegalStateException("Native video player has no exact permit claim");
    }
    if (record.state != state || record.epoch != epoch || record.player == null) {
      throw new IllegalStateException("Native video player has no exact permit claim");
    }
    cleanupRecord(record);
    if (permitRecords.get(playerId) == record) {
      throw new IllegalStateException("Native video player cleanup remains pending");
    }
  }

  /** Closes only the captured plugin instance, original messenger and immutable exact claim. */
  public @NonNull ExactCloseResult closeExactPlayer(
      @NonNull BinaryMessenger engineMessenger, @NonNull VideoPermitClaim claim) {
    requireMainThread();
    PermitRecord record = permitRecords.get(claim.getPlayerId());
    if (record == null) {
      return releasedExactPlayer != null && releasedExactPlayer.matches(engineMessenger, claim)
          ? ExactCloseResult.RELEASED_EXACT : ExactCloseResult.UNCONFIRMED;
    }
    if (record.claim != claim || record.state.binaryMessenger != engineMessenger) {
      return ExactCloseResult.UNCONFIRMED;
    }
    record.phase = PermitPhase.CLOSING;
    if (record.player != null) record.player.revoke();
    if (record.creationInFlight) return ExactCloseResult.PENDING_CREATE;
    try {
      cleanupRecord(record);
    } catch (RuntimeException failure) {
      return ExactCloseResult.UNCONFIRMED;
    }
    return releasedExactPlayer != null && releasedExactPlayer.matches(engineMessenger, claim)
        ? ExactCloseResult.RELEASED_EXACT : ExactCloseResult.UNCONFIRMED;
  }

  @Override
  public void setMixWithOthers(boolean mixWithOthers) {
    throw new IllegalStateException("Global video audio mixing has no native permit");
  }

  @Override
  public @NonNull String getLookupKeyForAsset(@NonNull String asset, @Nullable String packageName) {
    return packageName == null
        ? flutterState.keyForAsset.get(asset)
        : flutterState.keyForAssetAndPackageName.get(asset, packageName);
  }

  private interface KeyForAssetFn {
    String get(String asset);
  }

  /** Receipt for one engine's generated global handlers, including partial registration. */
  private static final class GlobalApiRegistration {
    final FlutterState state;
    final long epoch;
    boolean registrationInFlight = true;
    boolean cleanupInProgress;
    boolean active;
    boolean handlersCleared;

    GlobalApiRegistration(FlutterState state, long epoch) {
      this.state = state;
      this.epoch = epoch;
    }
  }

  /** Generated Pigeon handlers capture this engine owner rather than the reusable plugin. */
  private static final class EngineBoundApi implements AndroidVideoPlayerApi {
    final VideoPlayerPlugin plugin;
    final GlobalApiRegistration registration;

    EngineBoundApi(VideoPlayerPlugin plugin, GlobalApiRegistration registration) {
      this.plugin = plugin;
      this.registration = registration;
    }

    private void requireCurrentEngine() {
      requireMainThread();
      if (!registration.active || registration.registrationInFlight ||
          registration.handlersCleared || plugin.flutterState != registration.state ||
          plugin.engineEpoch != registration.epoch) {
        throw new IllegalStateException("Native video global handler belongs to a retired engine");
      }
    }

    @Override
    public void initialize() {
      requireCurrentEngine();
      plugin.initialize();
    }

    @Override
    public long createForPlatformView(@NonNull CreationOptions options) {
      requireCurrentEngine();
      return plugin.createForPlatformView(options);
    }

    @Override
    public @NonNull TexturePlayerIds createForTextureView(@NonNull CreationOptions options) {
      requireCurrentEngine();
      return plugin.createForTextureView(options);
    }

    @Override
    public void dispose(long playerId) {
      requireCurrentEngine();
      plugin.disposeForEngine(registration.state, registration.epoch, playerId);
    }

    @Override
    public void setMixWithOthers(boolean mixWithOthers) {
      requireCurrentEngine();
      plugin.setMixWithOthers(mixWithOthers);
    }

    @Override
    public @NonNull String getLookupKeyForAsset(
        @NonNull String asset, @Nullable String packageName) {
      requireCurrentEngine();
      return plugin.getLookupKeyForAsset(asset, packageName);
    }
  }

  private enum PermitPhase {
    CREATING,
    ACTIVE,
    CLOSING,
    QUARANTINED
  }

  /** Bounded receipt for a fully cleaned and bridge-acknowledged exact player. */
  private static final class ReleasedExactPlayer {
    final VideoPermitClaim claim;
    final BinaryMessenger messenger;
    final long epoch;
    final long id;

    ReleasedExactPlayer(PermitRecord record) {
      claim = record.claim;
      messenger = record.state.binaryMessenger;
      epoch = record.epoch;
      id = record.id;
    }

    boolean matches(BinaryMessenger candidateMessenger, VideoPermitClaim candidate) {
      return messenger == candidateMessenger && claim == candidate;
    }

    boolean matches(FlutterState candidateState, long candidateEpoch, long candidateId) {
      return messenger == candidateState.binaryMessenger && epoch == candidateEpoch &&
          id == candidateId;
    }
  }

  private static final class PermitRecord {
    final VideoPermitClaim claim;
    final VideoPermitBridge bridge;
    final FlutterState state;
    final long epoch;
    final long id;
    PermitPhase phase = PermitPhase.CREATING;
    @Nullable VideoPlayer player;
    boolean creationInFlight = true;
    boolean nativeAllocationStarted;
    boolean nativeCleanupConfirmed;
    boolean channelsCleared;
    boolean registrationComplete;
    boolean cleanupInProgress;

    PermitRecord(VideoPermitClaim claim, VideoPermitBridge bridge, FlutterState state,
        long epoch, long id) {
      this.claim = claim;
      this.bridge = bridge;
      this.state = state;
      this.epoch = epoch;
      this.id = id;
    }
  }

  private interface KeyForAssetAndPackageName {
    String get(String asset, String packageName);
  }

  private static final class FlutterState {
    final Context applicationContext;
    final BinaryMessenger binaryMessenger;
    final KeyForAssetFn keyForAsset;
    final KeyForAssetAndPackageName keyForAssetAndPackageName;
    final TextureRegistry textureRegistry;

    FlutterState(
        Context applicationContext,
        BinaryMessenger messenger,
        KeyForAssetFn keyForAsset,
        KeyForAssetAndPackageName keyForAssetAndPackageName,
        TextureRegistry textureRegistry) {
      this.applicationContext = applicationContext;
      this.binaryMessenger = messenger;
      this.keyForAsset = keyForAsset;
      this.keyForAssetAndPackageName = keyForAssetAndPackageName;
      this.textureRegistry = textureRegistry;
    }

    void startListening(AndroidVideoPlayerApi api, BinaryMessenger messenger) {
      AndroidVideoPlayerApi.Companion.setUp(messenger, api);
    }

    void stopListening(BinaryMessenger messenger) {
      AndroidVideoPlayerApi.Companion.setUp(messenger, null);
    }
  }
}
