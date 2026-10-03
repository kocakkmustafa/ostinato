// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import AVFoundation

#if os(iOS)
  import Flutter
#elseif os(macOS)
  import FlutterMacOS
#else
  #error("Unsupported platform.")
#endif

#if canImport(video_player_avfoundation_objc)
  import video_player_avfoundation_objc
#endif

// Protocol for an display link factory. Used for injecting display links in tests.
protocol DisplayLinkFactory {
  func displayLink(
    with viewProvider: FVPViewProvider,
    callback: @escaping () -> Void
  ) -> FVPDisplayLink
}

/// Non-test implementation of the display link factory.
final class DefaultDisplayLinkFactory: DisplayLinkFactory {
  func displayLink(
    with viewProvider: FVPViewProvider,
    callback: @escaping () -> Void
  ) -> FVPDisplayLink {
    #if os(iOS)
      return FVPCADisplayLink(viewProvider: viewProvider, callback: callback)
    #elseif os(macOS)
      if #available(macOS 14.0, *) {
        return FVPCADisplayLink(viewProvider: viewProvider, callback: callback)
      }
      return FVPCoreVideoDisplayLink(viewProvider: viewProvider, callback: callback)
    #endif
  }
}

/// Non-test implementation of FVPAssetProvider, wrapping a Flutter plugin
/// registrar.
final class DefaultAssetProvider: NSObject, FVPAssetProvider {
  private weak var registrar: FlutterPluginRegistrar?

  init(registrar: FlutterPluginRegistrar) {
    self.registrar = registrar
    super.init()
  }

  func lookupKey(forAsset asset: String) -> String? {
    return registrar?.lookupKey(forAsset: asset)
  }

  func lookupKey(forAsset asset: String, fromPackage package: String) -> String? {
    return registrar?.lookupKey(forAsset: asset, fromPackage: package)
  }
}

private final class ClaimedPlatformVideo {
  let bridge: VideoPermitBridge
  let permit: VideoPermitIdentity
  let playerId: Int64
  // Keep the disposed wrapper available for a later exact-release retry. Its
  // AVPlayer ivar is cleared before objcDisposalFinished becomes true.
  var player: FVPVideoPlayer?
  var claimClosureEntered = false
  var firstSideEffectStarted = false
  var configurationFinished = false
  var instanceChannels: FVPTrackedInstanceChannels?
  var channelDetached = false
  var viewsDetached = false
  var objcDisposalFinished = false
  var emptyCleanupConfirmed = false
  var releaseInProgress = false

  init(bridge: VideoPermitBridge, permit: VideoPermitIdentity, playerId: Int64) {
    self.bridge = bridge
    self.permit = permit
    self.playerId = playerId
  }
}

public final class VideoPlayerPlugin: NSObject, FlutterPlugin, AVFoundationVideoPlayerApi {
  private let binaryMessenger: FlutterBinaryMessenger
  private let textureRegistry: FlutterTextureRegistry
  private let displayLinkFactory: DisplayLinkFactory
  private let avFactory: FVPAVFactory
  private let viewProvider: FVPViewProvider
  private let assetProvider: FVPAssetProvider
  private var nextPlayerIdentifier: Int64 = 1
  private var videoPermitBridge: VideoPermitBridge?
  private var permitBridgeRevision: UInt64 = 0
  var nativeViewFactory: NativeVideoViewFactory?
  private var engineDetached = false
  // Source-level bridge work is not native acceptance. This remains false in
  // the app binary until semantic/native/device evidence is reviewed.
  private var platformViewCreationEnabled = false
  private var platformClaims: [Int64: ClaimedPlatformVideo] = [:]
  var beforeFirstAVEffectForNativeTests: (() throws -> Void)?
  var afterAVAssetForNativeTests: (() throws -> Void)?
  var pendingPlatformClaimCountForNativeTests: Int { platformClaims.count }
  func instanceChannelsForNativeTests(_ playerId: Int64) -> FVPTrackedInstanceChannels? {
    platformClaims[playerId]?.instanceChannels
  }
  var playersByIdentifier: [Int64: FVPVideoPlayer] = [:]

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = VideoPlayerPlugin(registrar: registrar)
    // Publish the instance so that it receives detachFromEngine.
    registrar.publish(instance)

    #if os(iOS)
      let messenger = registrar.messenger()
    #else
      let messenger = registrar.messenger
    #endif
    let factory = NativeVideoViewFactory(
      messenger: messenger,
      playerByIdentifierProvider: {
        [weak instance] (playerIdentifier: Int64) -> FVPVideoPlayer? in
        return instance?.playersByIdentifier[playerIdentifier]
      }
    )
    instance.nativeViewFactory = factory
    registrar.register(factory, withId: "plugins.flutter.dev/video_player_ios")

    AVFoundationVideoPlayerApiSetup.setUp(binaryMessenger: messenger, api: instance)
  }

  convenience init(registrar: FlutterPluginRegistrar) {
    #if os(iOS)
      let messenger = registrar.messenger()
      let textures = registrar.textures()
    #else
      let messenger = registrar.messenger
      let textures = registrar.textures
    #endif
    self.init(
      avFactory: FVPDefaultAVFactory(),
      displayLinkFactory: DefaultDisplayLinkFactory(),
      binaryMessenger: messenger,
      textureRegistry: textures,
      viewProvider: FVPDefaultViewProvider(registrar: registrar),
      assetProvider: DefaultAssetProvider(registrar: registrar)
    )
  }

  init(
    avFactory: FVPAVFactory,
    displayLinkFactory: DisplayLinkFactory,
    binaryMessenger: FlutterBinaryMessenger,
    textureRegistry: FlutterTextureRegistry,
    viewProvider: FVPViewProvider,
    assetProvider: FVPAssetProvider
  ) {
    self.binaryMessenger = binaryMessenger
    self.textureRegistry = textureRegistry
    self.assetProvider = assetProvider
    self.viewProvider = viewProvider
    self.displayLinkFactory = displayLinkFactory
    self.avFactory = avFactory
    super.init()
  }

  public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    if !Thread.isMainThread {
      DispatchQueue.main.sync { self.detachFromEngine(for: registrar) }
      return
    }
    retireVideoEngine()
    #if os(iOS)
      let messenger = registrar.messenger()
    #else
      let messenger = registrar.messenger
    #endif
    AVFoundationVideoPlayerApiSetup.setUp(binaryMessenger: messenger, api: nil)
  }

  /// Shared by engine detach and native fake tests. An in-flight create not
  /// yet in playersByIdentifier observes the fence and rolls back itself.
  func retireVideoEngine() {
    guard Thread.isMainThread else { return }
    // An in-flight create can re-enter detach from its AV factory before it
    // has a player in this map. It observes this fence after construction and
    // rolls back its exact claim instead of publishing a retired-engine ID.
    engineDetached = true
    videoPermitBridge = nil
    permitBridgeRevision &+= 1
    for player in Array(playersByIdentifier.values) {
      var error: FlutterError?
      player.disposeWithError(&error)
    }
  }

  /// The app may bind its native arbiter adapter to this one published plugin
  /// instance on the main thread. No global bridge or Dart-supplied permit can
  /// substitute for this engine binding.
  @discardableResult public func installVideoPermitBridge(_ bridge: VideoPermitBridge) -> Bool {
    guard Thread.isMainThread, !engineDetached, videoPermitBridge == nil,
          playersByIdentifier.isEmpty, platformClaims.isEmpty else { return false }
    videoPermitBridge = bridge
    permitBridgeRevision &+= 1
    return true
  }

  /// Replaces only this published plugin's bridge. Proof callbacks may re-enter
  /// native code, so the messenger, bridge revision, and player records are
  /// checked on both sides. Replaying the same next bridge performs no reset.
  @discardableResult public func rebindVideoPermitBridge(
    messenger: FlutterBinaryMessenger, to nextBridge: VideoPermitBridge
  ) -> Bool {
    guard Thread.isMainThread, !engineDetached,
          (binaryMessenger as AnyObject) === (messenger as AnyObject),
          let oldBridge = videoPermitBridge,
          playersByIdentifier.isEmpty, platformClaims.isEmpty else { return false }
    let revision = permitBridgeRevision
    let playerIdentifier = nextPlayerIdentifier
    let quiescent = oldBridge.isQuiescentForRebind()
    guard quiescent, !engineDetached,
          (binaryMessenger as AnyObject) === (messenger as AnyObject),
          videoPermitBridge === oldBridge, permitBridgeRevision == revision,
          nextPlayerIdentifier == playerIdentifier,
          playersByIdentifier.isEmpty, platformClaims.isEmpty else { return false }
    if oldBridge !== nextBridge {
      videoPermitBridge = nextBridge
      permitBridgeRevision &+= 1
    }
    return true
  }

  /// The app arbiter may request disposal of only the player and permit that
  /// its original bridge admitted. Dispatch success is not a release receipt;
  /// the existing full-teardown callback records that separately.
  @discardableResult public func closeExactPlayer(
    permit: VideoPermitIdentity, playerId: Int64, bridge: VideoPermitBridge
  ) -> Bool {
    guard Thread.isMainThread, let claim = platformClaims[playerId],
          claim.bridge === bridge, claim.permit == permit,
          claim.playerId == playerId, claim.configurationFinished else { return false }
    guard let player = claim.player else {
      tryReleaseExactClaim(claim)
      return platformClaims[playerId] == nil
    }
    var error: FlutterError?
    player.disposeWithError(&error)
    detachRegistration(for: player, claim: claim)
    player.eventListener?.videoPlayerWasDisposed()
    player.eventListener = nil
    tryReleaseExactClaim(claim)
    return error == nil
  }

  /// Accessible only to this package's @testable native tests. The app cannot
  /// enable the unaccepted platform-view branch by merely binding a bridge.
  func enablePlatformViewCreationForNativeTests() {
    guard Thread.isMainThread, !engineDetached else { return }
    platformViewCreationEnabled = true
  }

  func initialize() throws {
    throw PigeonError(code: "video_permit_required", message: "Global video initialization has no native permit", details: nil)
  }

  func createPlatformViewPlayer(options params: CreationOptions) throws -> Int64 {
    guard Thread.isMainThread, !engineDetached, platformViewCreationEnabled,
          let bridge = videoPermitBridge else {
      throw permitFailure("Native video permit bridge is not installed on this engine")
    }
    let url = try validatedLocalFileURL(for: params)
    guard let permit = validatedPermit(params.permit), nextPlayerIdentifier < Int64.max else {
      throw permitFailure("Invalid native video permit")
    }
    let playerId = nextPlayerIdentifier
    nextPlayerIdentifier += 1
    let claim = ClaimedPlatformVideo(bridge: bridge, permit: permit, playerId: playerId)
    platformClaims[playerId] = claim
    var createdPlayer: FVPVideoPlayer?
    let admitted: Bool
    do {
      admitted = try bridge.withClaimedVideoCreation(permit: permit, playerId: playerId) {
        claim.claimClosureEntered = true
        guard self.engineIsCurrent(for: bridge) else {
          throw self.permitFailure("Video engine detached before native creation")
        }
        try self.beforeFirstAVEffectForNativeTests?()
        // Both the bridge and the test hook may synchronously retire this
        // engine. The last fence must precede even AVAsset construction.
        guard self.engineIsCurrent(for: bridge) else {
          throw self.permitFailure("Video engine detached before first AV effect")
        }
        claim.firstSideEffectStarted = true
        // AVAsset, AVPlayerItem, AVPlayer and any related audio effects begin
        // inside the app arbiter's atomic native claim operation.
        let item = try self.playerItem(with: url, bridge: bridge)
        let player: FVPVideoPlayer? = FVPVideoPlayer(
          playerItem: item, avFactory: self.avFactory, viewProvider: self.viewProvider)
        guard let player else { throw self.permitFailure("Native player construction failed") }
        createdPlayer = player
        claim.player = player
        self.installDisposeCallbacks(on: player, claim: claim)
        guard self.engineIsCurrent(for: bridge), !player.disposed else {
          throw self.permitFailure("Video engine detached during creation")
        }
        try self.configurePlayer(player, identifier: playerId, bridge: bridge, claim: claim)
        guard self.engineIsCurrent(for: bridge), !player.disposed else {
          throw self.permitFailure("Video engine detached during registration")
        }
      }
    } catch {
      claim.configurationFinished = true
      rollbackCreatedPlayer(createdPlayer, claim: claim)
      throw permitFailure("Native video create failed or was fenced")
    }
    claim.configurationFinished = true
    guard admitted, engineIsCurrent(for: bridge),
          let player = createdPlayer, !player.disposed,
          playersByIdentifier[playerId] === player else {
      rollbackCreatedPlayer(createdPlayer, claim: claim)
      throw permitFailure("Native video create was fenced")
    }
    return playerId
  }

  func createTexturePlayer(options creationOptions: CreationOptions) throws -> TexturePlayerIds {
    throw PigeonError(code: "video_permit_required", message: "Native video permit bridge is not installed", details: nil)
  }

  func setMixWithOthers(_ mixWithOthers: Bool) throws {
    throw PigeonError(code: "video_permit_required", message: "Global video audio mixing has no native permit", details: nil)
  }

  func fileURLForAsset(name asset: String, package: String?) throws -> String? {
    let resource =
      if let package = package {
        assetProvider.lookupKey(forAsset: asset, fromPackage: package)
      } else {
        assetProvider.lookupKey(forAsset: asset)
      }

    var path = Bundle.main.path(forResource: resource, ofType: nil)
    #if os(macOS)
      // See https://github.com/flutter/flutter/issues/135302
      // TODO(stuartmorgan): Remove this if the asset APIs are adjusted to work better for macOS.
      if path == nil, let resource = resource {
        path = URL(string: resource, relativeTo: Bundle.main.bundleURL)?.path
      }
    #endif

    guard let validPath = path else {
      return nil
    }
    return URL(fileURLWithPath: validPath).absoluteString
  }

  // MARK: - Private

  private func permitFailure(_ message: String) -> PigeonError {
    PigeonError(code: "video_permit_required", message: message, details: nil)
  }

  private func engineIsCurrent(for bridge: VideoPermitBridge) -> Bool {
    Thread.isMainThread && !engineDetached && videoPermitBridge === bridge
  }

  private func validatedPermit(_ message: VideoPermitMessage) -> VideoPermitIdentity? {
    func validToken(_ value: String) -> Bool {
      let bytes = Array(value.utf8)
      return bytes.count == 32 && bytes.allSatisfy {
        (48...57).contains($0) || (97...102).contains($0)
      }
    }
    guard validToken(message.ownerToken), validToken(message.leaseId),
          message.engineGeneration > 0, message.contextGeneration >= 0,
          message.leaseGeneration > 0,
          Int(exactly: message.engineGeneration) != nil,
          Int(exactly: message.contextGeneration) != nil,
          Int(exactly: message.leaseGeneration) != nil else { return nil }
    return VideoPermitIdentity(
      ownerToken: message.ownerToken,
      engineGeneration: message.engineGeneration,
      contextGeneration: message.contextGeneration,
      leaseId: message.leaseId,
      leaseGeneration: message.leaseGeneration)
  }

  private func validatedLocalFileURL(for options: CreationOptions) throws -> URL {
    var isDirectory: ObjCBool = false
    guard options.httpHeaders.isEmpty, !options.mixWithOthers,
          let url = URL(string: options.uri), url.isFileURL,
          (url.host ?? "").isEmpty,
          FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
          !isDirectory.boolValue else {
      throw permitFailure("Only existing local video files without headers or mixing are admitted")
    }
    return url
  }

  private func installDisposeCallbacks(on player: FVPVideoPlayer, claim: ClaimedPlatformVideo) {
    player.onDisposed = { [weak self, weak player, weak claim] in
      guard let self, let claim else { return }
      self.detachRegistration(for: player, claim: claim)
    }
    player.onRegistrationDetached = { [weak self, weak player, weak claim] in
      guard let self, let claim else { return false }
      return claim.channelDetached && claim.viewsDetached &&
        self.playersByIdentifier[claim.playerId] !== player
    }
    // ObjC calls this after item, observer and event teardown. The bridge
    // receipt additionally requires channel/map and platform-view detachment.
    player.onFullyDisposed = { [weak self, weak claim] in
      guard let self, let claim else { return }
      claim.objcDisposalFinished = true
      self.tryReleaseExactClaim(claim)
    }
  }

  private func detachRegistration(for player: FVPVideoPlayer?, claim: ClaimedPlatformVideo) {
    // A claim that never entered instance registration owns no Pigeon channel.
    // Otherwise remove only the exact Flutter connections this claim created.
    claim.channelDetached = claim.instanceChannels?.detachRemaining() ?? true
    claim.viewsDetached = nativeViewFactory?.detachPlayerViews(for: claim.playerId) ?? false
    if let player, playersByIdentifier[claim.playerId] === player {
      playersByIdentifier.removeValue(forKey: claim.playerId)
    }
  }

  private func tryReleaseExactClaim(_ claim: ClaimedPlatformVideo) {
    guard Thread.isMainThread, platformClaims[claim.playerId] === claim,
          claim.configurationFinished, !claim.releaseInProgress else { return }
    if claim.emptyCleanupConfirmed {
      guard claim.claimClosureEntered, !claim.firstSideEffectStarted,
            claim.player == nil else { return }
    } else {
      guard claim.channelDetached, claim.viewsDetached,
            claim.objcDisposalFinished,
            let player = claim.player, player.disposed,
            // ObjC clears its strong AVPlayer ivar before onFullyDisposed.
            player.player == nil, player.eventListener == nil,
            playersByIdentifier[claim.playerId] !== player else { return }
    }
    claim.releaseInProgress = true
    let released = claim.bridge.releaseVideoPlayer(permit: claim.permit, playerId: claim.playerId)
    claim.releaseInProgress = false
    if released {
      platformClaims.removeValue(forKey: claim.playerId)
    }
    // False retains only this exact tuple. A later explicit retry may use its
    // original bridge even after engine retirement; no broad acknowledgement.
  }

  /// Retries an incomplete permit-backed native stop only when ObjC recorded
  /// complete teardown, then retries exact release using the original
  /// bridge/permit/player ID. Safe to invoke after an arbiter state change.
  @discardableResult public func retryPendingExactReleases() -> Int {
    guard Thread.isMainThread else { return 0 }
    var released = 0
    for claim in Array(platformClaims.values) {
      guard platformClaims[claim.playerId] === claim else { continue }
      // A pending claim can still represent an active player or a reentrant
      // create. Neither state authorizes removal of its 13 command handlers.
      // A pre-AV empty claim has no channels and may still retry its exact
      // permit release below.
      if claim.configurationFinished, let player = claim.player,
         player.disposed, !claim.releaseInProgress {
        if !claim.channelDetached, let channels = claim.instanceChannels {
          claim.channelDetached = channels.detachRemaining()
        }
        if !claim.objcDisposalFinished || claim.channelDetached {
          // ObjC retries only a proven native stop, or rereads exact channel
          // cleanup after Swift's token-only retry. Partial KVO remains held.
          var nativeError: FlutterError?
          player.disposeWithError(&nativeError)
        }
      }
      tryReleaseExactClaim(claim)
      if platformClaims[claim.playerId] !== claim { released += 1 }
    }
    return released
  }

  private func rollbackCreatedPlayer(_ player: FVPVideoPlayer?, claim: ClaimedPlatformVideo) {
    guard let player else {
      if !claim.claimClosureEntered {
        // The bridge rejected before the closure and no native claim exists.
        platformClaims.removeValue(forKey: claim.playerId)
      } else if !claim.firstSideEffectStarted {
        // A claim exists, but no AVAsset or player operation has begun. Its
        // exact native release is safe and makes the attempt recoverable.
        claim.emptyCleanupConfirmed = true
        tryReleaseExactClaim(claim)
      }
      // A begun AVAsset/item operation with no resulting player is ambiguous.
      // Keep the exact claim quarantined until a stronger cleanup proof exists.
      return
    }
    if !player.disposed {
      var error: FlutterError?
      player.disposeWithError(&error)
    }
    // A callback can detach the engine while configurePlayer is still
    // returning. Re-remove any late registration before release is attempted.
    detachRegistration(for: player, claim: claim)
    player.eventListener?.videoPlayerWasDisposed()
    player.eventListener = nil
    tryReleaseExactClaim(claim)
  }

  private func configurePlayer(
    _ player: FVPVideoPlayer,
    identifier playerId: Int64,
    bridge: VideoPermitBridge,
    claim: ClaimedPlatformVideo
  ) throws {
    playersByIdentifier[playerId] = player
    let channelSuffix = "\(playerId)"
    let channels = FVPTrackedInstanceChannels(messenger: binaryMessenger)
    claim.instanceChannels = channels
    guard channels.register(player, suffix: channelSuffix) else {
      throw permitFailure("Native video instance channels could not be registered exactly")
    }
    // Pigeon registration can synchronously re-enter engine retirement. The
    // create rollback removes any late handlers; do not start an event stream.
    guard engineIsCurrent(for: bridge), !player.disposed else { return }
    let eventBridge = FVPEventBridge(
      messenger: binaryMessenger,
      channelName: "flutter.dev/videoPlayer/videoEvents\(channelSuffix)"
    )
    // The event channel constructor itself installs a retained handler and
    // can re-enter retirement. Close that orphan before assigning a listener.
    guard engineIsCurrent(for: bridge), !player.disposed else {
      eventBridge.videoPlayerWasDisposed()
      return
    }
    player.eventListener = eventBridge
  }

  private func playerItem(with url: URL, bridge: VideoPermitBridge) throws -> FVPAVPlayerItem {
    let asset = avFactory.urlAsset(with: url, options: nil)
    try afterAVAssetForNativeTests?()
    // AVAsset and player-item factories can both synchronously re-enter an
    // engine fence. Never begin the next native effect on a retired engine.
    guard engineIsCurrent(for: bridge) else {
      throw permitFailure("Video engine detached after AVAsset creation")
    }
    let item = avFactory.playerItem(with: asset)
    guard engineIsCurrent(for: bridge) else {
      throw permitFailure("Video engine detached after player-item creation")
    }
    return item
  }
}

#if os(iOS)
  // This function, although slightly modified, is also in camera_avfoundation.
  // Both need to do the same thing and run on the same thread (for example main thread).
  // Do not overwrite PlayAndRecord with Playback which causes inability to record
  // audio, do not overwrite all options.
  // Only change category if it is considered an upgrade which means it can only enable
  // ability to play in silent mode or ability to record audio but never disables it,
  // that could affect other plugins which depend on this global state. Only change
  // category or options if there is change to prevent unnecessary lags and silence.
  private func upgradeAudioSessionCategory(
    session: FVPAVAudioSession,
    requestedCategory: AVAudioSession.Category,
    options: AVAudioSession.CategoryOptions,
    clearOptions: AVAudioSession.CategoryOptions
  ) {
    let playCategories: Set<AVAudioSession.Category> = [.playback, .playAndRecord]
    let recordCategories: Set<AVAudioSession.Category> = [.record, .playAndRecord]
    let requiredCategories: Set<AVAudioSession.Category> = [requestedCategory, session.category]

    let requiresPlay = !requiredCategories.isDisjoint(with: playCategories)
    let requiresRecord = !requiredCategories.isDisjoint(with: recordCategories)

    var finalCategory = requestedCategory
    if requiresPlay && requiresRecord {
      finalCategory = .playAndRecord
    } else if requiresPlay {
      finalCategory = .playback
    } else if requiresRecord {
      finalCategory = .record
    }

    let newOptions = session.categoryOptions.subtracting(clearOptions).union(options)

    if finalCategory == session.category && newOptions == session.categoryOptions {
      return
    }

    try? session.setCategory(finalCategory, with: newOptions)
  }
#endif
