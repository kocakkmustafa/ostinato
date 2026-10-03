// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import AVFoundation
import Foundation
import Testing
@testable import video_player_avfoundation
#if canImport(video_player_avfoundation_objc)
import video_player_avfoundation_objc
#endif

#if os(iOS)
  import Flutter
#else
  import FlutterMacOS
#endif

private final class FakeVideoPermitBridge: VideoPermitBridge {
  var admit = true
  var acceptAfterEffect = true
  var releaseConfirmed = true
  var onClaim: (() -> Void)?
  var onRelease: (() -> Void)?
  var quiescent = false
  var onQuiescence: (() -> Void)?
  private(set) var quiescenceChecks = 0
  private(set) var claims: [(VideoPermitIdentity, Int64)] = []
  private(set) var releases: [(VideoPermitIdentity, Int64)] = []

  func withClaimedVideoCreation(permit: VideoPermitIdentity, playerId: Int64,
                                firstSideEffect: () throws -> Void) throws -> Bool {
    claims.append((permit, playerId))
    onClaim?()
    guard admit else { return false }
    try firstSideEffect()
    return acceptAfterEffect
  }

  func releaseVideoPlayer(permit: VideoPermitIdentity, playerId: Int64) -> Bool {
    releases.append((permit, playerId))
    onRelease?()
    return releaseConfirmed
  }

  func isQuiescentForRebind() -> Bool {
    quiescenceChecks += 1
    onQuiescence?()
    return quiescent
  }
}

private final class IgnoringDetachAVPlayer: AVPlayer {
  var remainingIgnoredDetachCalls = Int.max
  var onDetach: (() -> Void)?
  private(set) var detachCalls = 0
  private(set) var rejectedDetachCalls = 0

  override func replaceCurrentItem(with item: AVPlayerItem?) {
    if item == nil {
      detachCalls += 1
      onDetach?()
      if remainingIgnoredDetachCalls > 0 {
        remainingIgnoredDetachCalls -= 1
        rejectedDetachCalls += 1
        return
      }
    }
    super.replaceCurrentItem(with: item)
  }
}

private final class LocalVideoErrorEvents: @unchecked Sendable {
  private let lock = NSLock()
  private var errorCodes: [String] = []
  private var errorMessages: [String] = []
  private var initializedCount = 0

  func record(_ event: Any?) {
    let error = event as? FlutterError
    let eventName = (event as? [String: Any])?["event"] as? String
    lock.lock()
    defer { lock.unlock() }
    if let error {
      errorCodes.append(error.code)
      errorMessages.append(error.message ?? "")
    }
    if eventName == "initialized" { initializedCount += 1 }
  }

  func snapshot() -> (codes: [String], messages: [String], initialized: Int) {
    lock.lock()
    defer { lock.unlock() }
    return (errorCodes, errorMessages, initializedCount)
  }
}

@MainActor private final class DeferredSeekAVPlayer: AVPlayer, @unchecked Sendable {
  private(set) nonisolated(unsafe) var pendingSeek: (@Sendable (Bool) -> Void)?
  nonisolated(unsafe) var ignoreNilItemDetach = false

  override func replaceCurrentItem(with item: AVPlayerItem?) {
    if item == nil && ignoreNilItemDetach { return }
    super.replaceCurrentItem(with: item)
  }

  override func seek(
    to time: CMTime,
    toleranceBefore: CMTime,
    toleranceAfter: CMTime,
    completionHandler: @escaping @Sendable (Bool) -> Void
  ) {
    pendingSeek = completionHandler
  }

  func finishSeek() {
    let callback = pendingSeek
    pendingSeek = nil
    callback?(true)
  }
}

private final class DeferredVariantsAsset: AVURLAsset, @unchecked Sendable {
  private(set) var pendingVariantLoad: (@Sendable () -> Void)?
  private(set) var variantStatusReads = 0
  var onVariantStatusRead: (() -> Void)?

  override func loadValuesAsynchronously(
    forKeys keys: [String], completionHandler handler: (@Sendable () -> Void)?
  ) {
    if keys == ["variants"] {
      pendingVariantLoad = handler
    } else {
      super.loadValuesAsynchronously(forKeys: keys, completionHandler: handler)
    }
  }

  override func statusOfValue(forKey key: String, error outError: NSErrorPointer) -> AVKeyValueStatus {
    if key == "variants" {
      variantStatusReads += 1
      onVariantStatusRead?()
    }
    return super.statusOfValue(forKey: key, error: outError)
  }

  func finishVariantLoad() {
    let callback = pendingVariantLoad
    pendingVariantLoad = nil
    callback?()
  }
}

@MainActor struct VideoPermitBridgeTests {
  @Test func staleMessengerCleanupKeepsTheCurrentChannelHandler() {
    let messenger = StubBinaryMessenger()
    let oldConnection = messenger.setMessageHandlerOnChannel(
      "videoEvents1", binaryMessageHandler: { _, _ in })
    let currentConnection = messenger.setMessageHandlerOnChannel(
      "videoEvents1", binaryMessageHandler: { _, _ in })
    messenger.cleanUpConnection(oldConnection)
    #expect(messenger.activeChannels.contains("videoEvents1"))
    messenger.cleanUpConnection(currentConnection)
    #expect(!messenger.activeChannels.contains("videoEvents1"))
    let olderConnection = messenger.setMessageHandlerOnChannel(
      "videoEvents1", binaryMessageHandler: { _, _ in })
    let newerConnection = messenger.setMessageHandlerOnChannel(
      "videoEvents1", binaryMessageHandler: { _, _ in })
    messenger.cleanUpConnection(newerConnection)
    #expect(!messenger.activeChannels.contains("videoEvents1"))
    messenger.cleanUpConnection(olderConnection)
    #expect(!messenger.activeChannels.contains("videoEvents1"))
  }

  private var permit: VideoPermitMessage {
    VideoPermitMessage(ownerToken: String(repeating: "a", count: 32),
                       engineGeneration: 1, contextGeneration: 0,
                       leaseId: String(repeating: "b", count: 32), leaseGeneration: 1)
  }

  private var permitIdentity: VideoPermitIdentity {
    VideoPermitIdentity(ownerToken: permit.ownerToken, engineGeneration: permit.engineGeneration,
      contextGeneration: permit.contextGeneration, leaseId: permit.leaseId,
      leaseGeneration: permit.leaseGeneration)
  }

  private func localURL() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try Data([0]).write(to: url)
    return url
  }

  private func options(_ uri: String) -> CreationOptions {
    CreationOptions(uri: uri, httpHeaders: [:], permit: permit, mixWithOthers: false)
  }

  private func makePlugin(_ avFactory: StubFVPAVFactory,
                          messenger: StubBinaryMessenger = StubBinaryMessenger(),
                          textureRegistry: TestTextureRegistry = TestTextureRegistry()) -> VideoPlayerPlugin {
    let plugin = VideoPlayerPlugin(
      avFactory: avFactory,
      displayLinkFactory: StubFVPDisplayLinkFactory(),
      binaryMessenger: messenger,
      textureRegistry: textureRegistry,
      viewProvider: StubViewProvider(),
      assetProvider: StubAssetProvider())
    plugin.nativeViewFactory = NativeVideoViewFactory(
      messenger: messenger,
      playerByIdentifierProvider: { [weak plugin] id in plugin?.playersByIdentifier[id] })
    return plugin
  }

  private func flushMainQueue() async {
    await withCheckedContinuation { continuation in
      DispatchQueue.main.async { continuation.resume() }
    }
  }

  @Test func unboundOrInvalidPermitNeverStartsAVCreation() throws {
    let file = try localURL()
    defer { try? FileManager.default.removeItem(at: file) }
    let av = StubFVPAVFactory()
    let plugin = makePlugin(av)
    do {
      _ = try plugin.createPlatformViewPlayer(options: options(file.absoluteString))
      Issue.record("Unbound engine created a player")
    } catch {}
    #expect(av.urlAssetCalls == 0)
    let bridge = FakeVideoPermitBridge()
    #expect(plugin.installVideoPermitBridge(bridge))
    #expect(!plugin.installVideoPermitBridge(FakeVideoPermitBridge()))
    do {
      _ = try plugin.createPlatformViewPlayer(options: options(file.absoluteString))
      Issue.record("Unaccepted production platform-view branch created a player")
    } catch {}
    #expect(av.urlAssetCalls == 0)
    plugin.enablePlatformViewCreationForNativeTests()

    for bad in [
      options("https://example.invalid/movie.mp4"),
      CreationOptions(uri: file.absoluteString, httpHeaders: ["X-Test": "1"],
                      permit: permit, mixWithOthers: false),
      CreationOptions(uri: file.absoluteString, httpHeaders: [:],
                      permit: permit, mixWithOthers: true),
      CreationOptions(uri: file.absoluteString, httpHeaders: [:],
                      permit: VideoPermitMessage(ownerToken: "bad", engineGeneration: 1,
                        contextGeneration: 0, leaseId: permit.leaseId,
                        leaseGeneration: 1), mixWithOthers: false),
    ] {
      do {
        _ = try plugin.createPlatformViewPlayer(options: bad)
        Issue.record("Invalid video input created a player")
      } catch {}
    }
    bridge.admit = false
    do {
      _ = try plugin.createPlatformViewPlayer(options: options(file.absoluteString))
      Issue.record("Rejected native claim created a player")
    } catch {}
    #expect(av.urlAssetCalls == 0)
    #expect(bridge.releases.isEmpty)
    do { try plugin.initialize(); Issue.record("Global initialize was admitted") } catch {}
    do { try plugin.setMixWithOthers(true); Issue.record("Global mix was admitted") } catch {}
    do {
      _ = try plugin.createTexturePlayer(options: options(file.absoluteString))
      Issue.record("Texture create was admitted")
    } catch {}
    #expect(av.urlAssetCalls == 0)
  }

  @Test func platformViewClaimPrecedesAVAndReleaseFollowsPlayerChannelAndLayerCleanup() throws {
    let file = try localURL()
    defer { try? FileManager.default.removeItem(at: file) }
    let av = StubFVPAVFactory()
    let messenger = StubBinaryMessenger()
    let plugin = makePlugin(av, messenger: messenger)
    let bridge = FakeVideoPermitBridge()
    var order: [String] = []
    bridge.onClaim = { order.append("claim") }
    av.onURLAsset = { order.append("asset") }
    #expect(plugin.installVideoPermitBridge(bridge))
    plugin.enablePlatformViewCreationForNativeTests()
    let id = try plugin.createPlatformViewPlayer(options: options(file.absoluteString))
    #expect(id == 1)
    #expect(order == ["claim", "asset"])
    let player = try #require(plugin.playersByIdentifier[id])
    let channels = try #require(plugin.instanceChannelsForNativeTests(id))
    #expect(channels.registrationComplete)
    #expect(channels.registeredCount == 13)
    #expect(messenger.activeChannels.contains(where: { $0.contains("VideoPlayerInstanceApi.dispose") }))
    #if os(iOS)
      let view = try #require(plugin.nativeViewFactory?.create(
        withFrame: .zero, viewIdentifier: 1,
        arguments: PlatformVideoViewCreationParams(playerId: id)) as? FVPNativeVideoView)
      let layer = try #require(view.view().layer as? AVPlayerLayer)
      #expect(layer.player != nil)
    #endif
    bridge.onRelease = {
      #expect(player.disposed)
      #expect(player.player == nil)
      #expect(player.eventListener == nil)
      #expect(plugin.playersByIdentifier[id] == nil)
      #expect(!messenger.activeChannels.contains(where: {
        $0.contains("VideoPlayerInstanceApi.") || $0.contains("videoEvents\(id)")
      }))
      #if os(iOS)
        #expect(layer.player == nil)
      #endif
    }
    var error: FlutterError?
    player.disposeWithError(&error)
    #expect(error == nil)
    #expect(bridge.releases.count == 1)
    #expect(channels.fullyDetached)
    #expect(channels.detachedCount == 13)
    #expect(bridge.releases[0].1 == id)
    #expect(bridge.releases[0].0.leaseId == permit.leaseId)
    #expect(plugin.pendingPlatformClaimCountForNativeTests == 0)
    player.disposeWithError(&error)
    #expect(bridge.releases.count == 1)
  }

  @Test func exactNativeClosePortCannotDisposeAnotherPlayerOrBridge() throws {
    let file = try localURL()
    defer { try? FileManager.default.removeItem(at: file) }
    let plugin = makePlugin(StubFVPAVFactory())
    let bridge = FakeVideoPermitBridge()
    #expect(plugin.installVideoPermitBridge(bridge))
    plugin.enablePlatformViewCreationForNativeTests()
    let id = try plugin.createPlatformViewPlayer(options: options(file.absoluteString))
    let exact = VideoPermitIdentity(ownerToken: permit.ownerToken,
      engineGeneration: permit.engineGeneration,
      contextGeneration: permit.contextGeneration,
      leaseId: permit.leaseId,
      leaseGeneration: permit.leaseGeneration)
    let wrong = VideoPermitIdentity(ownerToken: exact.ownerToken,
      engineGeneration: exact.engineGeneration,
      contextGeneration: exact.contextGeneration,
      leaseId: String(repeating: "c", count: 32),
      leaseGeneration: exact.leaseGeneration)
    #expect(!plugin.closeExactPlayer(permit: exact, playerId: id + 1, bridge: bridge))
    #expect(!plugin.closeExactPlayer(permit: wrong, playerId: id, bridge: bridge))
    #expect(!plugin.closeExactPlayer(permit: exact, playerId: id,
                                      bridge: FakeVideoPermitBridge()))
    #expect(plugin.playersByIdentifier[id] != nil)
    #expect(bridge.releases.isEmpty)
    #expect(plugin.closeExactPlayer(permit: exact, playerId: id, bridge: bridge))
    #expect(bridge.releases.count == 1)
    #expect(plugin.pendingPlatformClaimCountForNativeTests == 0)
  }

  @Test func quiescentRebindChangesOnlyTheBridgeOnTheSameMessenger() throws {
    let file = try localURL()
    defer { try? FileManager.default.removeItem(at: file) }
    let messenger = StubBinaryMessenger()
    let textures = TestTextureRegistry()
    let plugin = makePlugin(StubFVPAVFactory(), messenger: messenger, textureRegistry: textures)
    AVFoundationVideoPlayerApiSetup.setUp(binaryMessenger: messenger, api: plugin)
    let channels = messenger.activeChannels
    let old = FakeVideoPermitBridge()
    old.quiescent = true
    let next = FakeVideoPermitBridge()
    #expect(plugin.installVideoPermitBridge(old))
    #expect(plugin.rebindVideoPermitBridge(messenger: messenger, to: next))
    #expect(old.quiescenceChecks == 1)
    #expect(messenger.activeChannels == channels)
    #expect(!textures.registeredTexture)
    #expect(plugin.pendingPlatformClaimCountForNativeTests == 0)
    plugin.enablePlatformViewCreationForNativeTests()
    let id = try plugin.createPlatformViewPlayer(options: options(file.absoluteString))
    #expect(old.claims.isEmpty)
    #expect(next.claims.count == 1)
    #expect(plugin.closeExactPlayer(permit: permitIdentity, playerId: id, bridge: next))
    #expect(next.releases.count == 1)
    #expect(messenger.activeChannels == channels)
  }

  @Test func rebindRejectsForeignMessengerAndHeldPlayerBeforeProof() throws {
    let file = try localURL()
    defer { try? FileManager.default.removeItem(at: file) }
    let messenger = StubBinaryMessenger()
    let plugin = makePlugin(StubFVPAVFactory(), messenger: messenger)
    let old = FakeVideoPermitBridge()
    old.quiescent = true
    let next = FakeVideoPermitBridge()
    #expect(plugin.installVideoPermitBridge(old))
    #expect(!plugin.rebindVideoPermitBridge(messenger: StubBinaryMessenger(), to: next))
    let unbound = makePlugin(StubFVPAVFactory(), messenger: messenger)
    #expect(!unbound.rebindVideoPermitBridge(messenger: messenger, to: next))
    #expect(old.quiescenceChecks == 0)
    plugin.enablePlatformViewCreationForNativeTests()
    let id = try plugin.createPlatformViewPlayer(options: options(file.absoluteString))
    let channels = messenger.activeChannels
    #expect(!plugin.rebindVideoPermitBridge(messenger: messenger, to: next))
    #expect(old.quiescenceChecks == 0)
    #expect(plugin.playersByIdentifier[id] != nil)
    #expect(plugin.pendingPlatformClaimCountForNativeTests == 1)
    #expect(messenger.activeChannels == channels)
    #expect(old.releases.isEmpty)
    #expect(plugin.closeExactPlayer(permit: permitIdentity, playerId: id, bridge: old))
  }

  @Test func rebindRechecksDetachCreationAndBridgeRevisionAfterProof() throws {
    let file = try localURL()
    defer { try? FileManager.default.removeItem(at: file) }
    for mutation in ["detach", "heldCreate", "transientCreate", "bridgeChange"] {
      let messenger = StubBinaryMessenger()
      let plugin = makePlugin(StubFVPAVFactory(), messenger: messenger)
      let old = FakeVideoPermitBridge()
      old.quiescent = true
      let next = FakeVideoPermitBridge()
      let intermediate = FakeVideoPermitBridge()
      intermediate.quiescent = true
      #expect(plugin.installVideoPermitBridge(old))
      plugin.enablePlatformViewCreationForNativeTests()
      old.onQuiescence = {
        old.onQuiescence = nil
        if mutation == "detach" { plugin.retireVideoEngine() }
        if mutation == "heldCreate" || mutation == "transientCreate" {
          do {
            let id = try plugin.createPlatformViewPlayer(options: self.options(file.absoluteString))
            if mutation == "transientCreate" {
              #expect(plugin.closeExactPlayer(permit: self.permitIdentity, playerId: id, bridge: old))
              #expect(plugin.playersByIdentifier.isEmpty)
              #expect(plugin.pendingPlatformClaimCountForNativeTests == 0)
            }
          } catch { Issue.record("Reentrant creation unexpectedly failed: \(error)") }
        }
        if mutation == "bridgeChange" {
          #expect(plugin.rebindVideoPermitBridge(messenger: messenger, to: intermediate))
          // Even changing away and back must invalidate the outer proof.
          #expect(plugin.rebindVideoPermitBridge(messenger: messenger, to: old))
        }
      }
      #expect(!plugin.rebindVideoPermitBridge(messenger: messenger, to: next))
      #expect(next.claims.isEmpty)
      if mutation == "heldCreate" {
        let id = try #require(old.claims.first?.1)
        #expect(plugin.pendingPlatformClaimCountForNativeTests == 1)
        #expect(plugin.closeExactPlayer(permit: permitIdentity, playerId: id, bridge: old))
      } else if mutation != "detach" {
        let id = try plugin.createPlatformViewPlayer(options: options(file.absoluteString))
        #expect(old.claims.last?.1 == id)
        #expect(next.claims.isEmpty)
        #expect(plugin.closeExactPlayer(permit: permitIdentity, playerId: id, bridge: old))
      }
    }
  }

  @Test func emptyPluginCannotSubstituteAnotherBridgeForOldExactReleaseProof() throws {
    let file = try localURL()
    defer { try? FileManager.default.removeItem(at: file) }
    let messenger = StubBinaryMessenger()
    let plugin = makePlugin(StubFVPAVFactory(), messenger: messenger)
    let old = FakeVideoPermitBridge()
    let next = FakeVideoPermitBridge()
    next.quiescent = true
    #expect(plugin.installVideoPermitBridge(old))
    plugin.enablePlatformViewCreationForNativeTests()
    let id = try plugin.createPlatformViewPlayer(options: options(file.absoluteString))
    #expect(plugin.closeExactPlayer(permit: permitIdentity, playerId: id, bridge: old))
    #expect(old.releases.count == 1)
    #expect(old.releases[0].0 == permitIdentity)
    #expect(old.releases[0].1 == id)
    #expect(plugin.playersByIdentifier.isEmpty)
    #expect(plugin.pendingPlatformClaimCountForNativeTests == 0)
    // Empty maps and a different bridge's clear flag cannot prove this old
    // bridge's retained ACK. The app's exact proof remains independently false.
    #expect(!plugin.rebindVideoPermitBridge(messenger: messenger, to: next))
    #expect(next.quiescenceChecks == 0)
    old.quiescent = true
    #expect(plugin.rebindVideoPermitBridge(messenger: messenger, to: next))
  }

  @Test func sameNextBridgeReplayPreservesChannelsRegistryAndExactClose() throws {
    let file = try localURL()
    defer { try? FileManager.default.removeItem(at: file) }
    let messenger = StubBinaryMessenger()
    let textures = TestTextureRegistry()
    let plugin = makePlugin(StubFVPAVFactory(), messenger: messenger, textureRegistry: textures)
    AVFoundationVideoPlayerApiSetup.setUp(binaryMessenger: messenger, api: plugin)
    let channels = messenger.activeChannels
    let old = FakeVideoPermitBridge()
    old.quiescent = true
    let next = FakeVideoPermitBridge()
    next.quiescent = true
    #expect(plugin.installVideoPermitBridge(old))
    #expect(plugin.rebindVideoPermitBridge(messenger: messenger, to: next))
    #expect(plugin.rebindVideoPermitBridge(messenger: messenger, to: next))
    #expect(next.quiescenceChecks == 1)
    #expect(messenger.activeChannels == channels)
    #expect(!textures.registeredTexture)
    plugin.enablePlatformViewCreationForNativeTests()
    let id = try plugin.createPlatformViewPlayer(options: options(file.absoluteString))
    let instanceChannels = try #require(plugin.instanceChannelsForNativeTests(id))
    let liveChannels = messenger.activeChannels
    #expect(!plugin.rebindVideoPermitBridge(messenger: messenger, to: next))
    #expect(messenger.activeChannels == liveChannels)
    #expect(!plugin.closeExactPlayer(permit: permitIdentity, playerId: id, bridge: old))
    #expect(plugin.closeExactPlayer(permit: permitIdentity, playerId: id, bridge: next))
    #expect(instanceChannels.fullyDetached)
    #expect(instanceChannels.detachedCount == 13)
    #expect(next.releases.count == 1)
    #expect(messenger.activeChannels == channels)
    next.quiescent = false
    #expect(!plugin.rebindVideoPermitBridge(messenger: messenger, to: next))
    next.quiescent = true
    #expect(plugin.rebindVideoPermitBridge(messenger: messenger, to: next))
    #expect(messenger.activeChannels == channels)
    #expect(!textures.registeredTexture)
    #expect(plugin.pendingPlatformClaimCountForNativeTests == 0)
  }

  @Test func permittedPlatformViewPlayerDoesNotRegisterTexture() throws {
    let file = try localURL()
    defer { try? FileManager.default.removeItem(at: file) }
    let textures = TestTextureRegistry()
    let av = StubFVPAVFactory()
    let plugin = makePlugin(av, textureRegistry: textures)
    let bridge = FakeVideoPermitBridge()
    #expect(plugin.installVideoPermitBridge(bridge))
    plugin.enablePlatformViewCreationForNativeTests()

    let id = try plugin.createPlatformViewPlayer(options: options(file.absoluteString))
    #expect(bridge.claims.count == 1)
    #expect(av.urlAssetCalls == 1)
    #expect(!textures.registeredTexture)
    #expect(textures.textureFrameAvailableCount == 0)

    let player = try #require(plugin.playersByIdentifier[id])
    var error: FlutterError?
    player.disposeWithError(&error)
    #expect(error == nil)
    #expect(!textures.registeredTexture)
    #expect(!textures.unregisteredTexture)
  }

  @Test func permittedInvalidLocalFileEmitsVideoErrorAndReleasesExactClaim() async throws {
    let file = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension("mp4")
    try Data("not an MP4".utf8).write(to: file)
    defer { try? FileManager.default.removeItem(at: file) }
    var isDirectory: ObjCBool = false
    let fileExists = FileManager.default.fileExists(atPath: file.path, isDirectory: &isDirectory)
    #expect(file.isFileURL)
    #expect(fileExists)
    #expect(!isDirectory.boolValue)

    let messenger = StubBinaryMessenger()
    let plugin = VideoPlayerPlugin(
      avFactory: FVPDefaultAVFactory(),
      displayLinkFactory: StubFVPDisplayLinkFactory(),
      binaryMessenger: messenger,
      textureRegistry: TestTextureRegistry(),
      viewProvider: StubViewProvider(),
      assetProvider: StubAssetProvider())
    plugin.nativeViewFactory = NativeVideoViewFactory(
      messenger: messenger,
      playerByIdentifierProvider: { [weak plugin] id in plugin?.playersByIdentifier[id] })
    let bridge = FakeVideoPermitBridge()
    #expect(plugin.installVideoPermitBridge(bridge))
    plugin.enablePlatformViewCreationForNativeTests()

    let id = try plugin.createPlatformViewPlayer(options: options(file.absoluteString))
    let player = try #require(plugin.playersByIdentifier[id])
    let nativeItem = try #require(player.player?.currentItem)
    let localAsset = try #require(nativeItem.asset as? AVURLAsset)
    #expect(localAsset.url.standardizedFileURL == file.standardizedFileURL)
    let channels = try #require(plugin.instanceChannelsForNativeTests(id))
    #expect(channels.registrationComplete)
    #expect(channels.registeredCount == 13)

    let events = LocalVideoErrorEvents()
    let listener = try #require(player.eventListener as? FlutterStreamHandler)
    let sink: FlutterEventSink = { event in events.record(event) }
    #expect(listener.onListen(withArguments: nil, eventSink: sink) == nil)

    let deadline = ProcessInfo.processInfo.systemUptime + 10
    while ProcessInfo.processInfo.systemUptime < deadline {
      if nativeItem.status == .failed && events.snapshot().codes.contains("VideoError") {
        break
      }
      try await Task.sleep(nanoseconds: 25_000_000)
    }
    let itemFailed = nativeItem.status == .failed
    let beforeDispose = events.snapshot()
    if itemFailed {
      #expect(beforeDispose.codes == ["VideoError"])
      #expect(beforeDispose.messages.count == 1)
      #expect(beforeDispose.messages.first?.hasPrefix("Failed to load video") == true)
      #expect(beforeDispose.initialized == 0)
    } else {
      Issue.record("FIXTURE_INCONCLUSIVE: local malformed MP4 did not reach AVPlayerItem.failed")
    }

    var disposeError: FlutterError?
    player.disposeWithError(&disposeError)
    #expect(disposeError == nil)
    #expect(player.player == nil)
    #expect(player.eventListener == nil)
    #expect(plugin.playersByIdentifier[id] == nil)
    #expect(channels.fullyDetached)
    #expect(channels.detachedCount == 13)
    #expect(!messenger.activeChannels.contains(where: {
      $0.contains("VideoPlayerInstanceApi.") || $0.contains("videoEvents\(id)")
    }))
    #expect(plugin.pendingPlatformClaimCountForNativeTests == 0)
    #expect(bridge.claims.count == 1)
    #expect(bridge.releases.count == 1)
    let claim = try #require(bridge.claims.first)
    let release = try #require(bridge.releases.first)
    #expect(claim.1 == id)
    #expect(release.0 == claim.0)
    #expect(release.1 == claim.1)
    try await Task.sleep(nanoseconds: 100_000_000)
    let afterDispose = events.snapshot()
    #expect(afterDispose.codes == beforeDispose.codes)
    #expect(afterDispose.initialized == beforeDispose.initialized)
  }

  @Test func retryWithLivePlayerDoesNotDetachItsCommandChannels() throws {
    let file = try localURL()
    defer { try? FileManager.default.removeItem(at: file) }
    let messenger = StubBinaryMessenger()
    let plugin = makePlugin(StubFVPAVFactory(), messenger: messenger)
    let bridge = FakeVideoPermitBridge()
    #expect(plugin.installVideoPermitBridge(bridge))
    plugin.enablePlatformViewCreationForNativeTests()
    let id = try plugin.createPlatformViewPlayer(options: options(file.absoluteString))
    let player = try #require(plugin.playersByIdentifier[id])
    let channels = try #require(plugin.instanceChannelsForNativeTests(id))
    let before = messenger.activeChannels
    #expect(channels.registeredCount == 13)
    #expect(channels.cleanupAttemptCount == 0)
    #expect(player.player?.currentItem != nil)

    #expect(plugin.retryPendingExactReleases() == 0)
    #expect(!player.disposed)
    #expect(player.player?.currentItem != nil)
    #expect(messenger.activeChannels == before)
    #expect(channels.cleanupAttemptCount == 0)
    #expect(channels.detachedCount == 0)
    #expect(bridge.releases.isEmpty)
    #expect(plugin.pendingPlatformClaimCountForNativeTests == 1)

    var error: FlutterError?
    player.disposeWithError(&error)
    #expect(error == nil)
    #expect(channels.fullyDetached)
    #expect(channels.detachedCount == 13)
    #expect(bridge.releases.count == 1)
  }

  @Test func reentrantRetryDuringCreateLeavesPartialRegistrationUntouched() throws {
    let file = try localURL()
    defer { try? FileManager.default.removeItem(at: file) }
    let messenger = StubBinaryMessenger()
    let plugin = makePlugin(StubFVPAVFactory(), messenger: messenger)
    let bridge = FakeVideoPermitBridge()
    #expect(plugin.installVideoPermitBridge(bridge))
    plugin.enablePlatformViewCreationForNativeTests()
    var checked = false
    messenger.onSetMessageHandler = { channel in
      guard !checked, channel.contains("VideoPlayerInstanceApi."),
            messenger.activeChannels.filter({ $0.contains("VideoPlayerInstanceApi.") }).count == 7
      else { return }
      checked = true
      let channels = plugin.instanceChannelsForNativeTests(1)
      #expect(channels?.registeredCount == 6)
      let before = messenger.activeChannels
      #expect(plugin.retryPendingExactReleases() == 0)
      #expect(messenger.activeChannels == before)
      #expect(channels?.cleanupAttemptCount == 0)
      #expect(bridge.releases.isEmpty)
    }

    let id = try plugin.createPlatformViewPlayer(options: options(file.absoluteString))
    let player = try #require(plugin.playersByIdentifier[id])
    let channels = try #require(plugin.instanceChannelsForNativeTests(id))
    #expect(checked)
    #expect(!player.disposed)
    #expect(channels.registrationComplete)
    #expect(channels.cleanupAttemptCount == 0)
    #expect(channels.detachedCount == 0)
    #expect(messenger.activeChannels.filter { $0.contains("VideoPlayerInstanceApi.") }.count == 13)

    var error: FlutterError?
    player.disposeWithError(&error)
    #expect(error == nil)
    #expect(bridge.releases.count == 1)
  }

  @Test func reentrantRetryDuringExactTokenCleanupCountsEachChannelOnce() throws {
    let file = try localURL()
    defer { try? FileManager.default.removeItem(at: file) }
    let messenger = StubBinaryMessenger()
    let plugin = makePlugin(StubFVPAVFactory(), messenger: messenger)
    let bridge = FakeVideoPermitBridge()
    #expect(plugin.installVideoPermitBridge(bridge))
    plugin.enablePlatformViewCreationForNativeTests()
    let id = try plugin.createPlatformViewPlayer(options: options(file.absoluteString))
    let player = try #require(plugin.playersByIdentifier[id])
    let channels = try #require(plugin.instanceChannelsForNativeTests(id))
    var nestedRetries = 0
    messenger.onCleanUpConnection = { _ in
      guard nestedRetries == 0 else { return }
      nestedRetries += 1
      #expect(plugin.retryPendingExactReleases() == 0)
      #expect(bridge.releases.isEmpty)
    }

    var error: FlutterError?
    player.disposeWithError(&error)
    #expect(error == nil)
    #expect(nestedRetries == 1)
    #expect(channels.cleanupAttemptCount == 13)
    #expect(channels.detachedCount == 13)
    #expect(channels.fullyDetached)
    #expect(bridge.releases.count == 1)
    #expect(plugin.pendingPlatformClaimCountForNativeTests == 0)
  }

  @Test func partialChannelCleanupKeepsStalePlayInertAndRetriesExactToken() throws {
    let file = try localURL()
    defer { try? FileManager.default.removeItem(at: file) }
    let nativePlayer = IgnoringDetachAVPlayer(playerItem: AVPlayerItem(url: file))
    let messenger = StubBinaryMessenger()
    let plugin = makePlugin(StubFVPAVFactory(player: nativePlayer), messenger: messenger)
    let bridge = FakeVideoPermitBridge()
    #expect(plugin.installVideoPermitBridge(bridge))
    plugin.enablePlatformViewCreationForNativeTests()
    let id = try plugin.createPlatformViewPlayer(options: options(file.absoluteString))
    let player = try #require(plugin.playersByIdentifier[id])
    let channels = try #require(plugin.instanceChannelsForNativeTests(id))
    let play = "dev.flutter.pigeon.video_player_avfoundation.VideoPlayerInstanceApi.play.\(id)"
    let registrations = messenger.activeChannels.filter { $0.contains("VideoPlayerInstanceApi.") }.sorted()
    let playIndex = try #require(registrations.firstIndex(of: play))
    channels.throwBeforeCleanupOnAttemptForNativeTests = UInt(playIndex + 1)

    var error: FlutterError?
    player.disposeWithError(&error)
    #expect(error?.code == "native_video_dispose_incomplete")
    #expect(channels.registeredCount == 13)
    #expect(channels.detachedCount == 12)
    #expect(bridge.releases.isEmpty)
    #expect(plugin.pendingPlatformClaimCountForNativeTests == 1)
    #expect(player.player === nativePlayer)
    #expect(messenger.activeChannels.contains(play))
    let oldRate = nativePlayer.rate
    let response = messenger.invokeInstanceChannel(play)
    #expect(response?.first as? String == "native_video_disposed")
    #expect(nativePlayer.rate == oldRate)
    #expect(bridge.releases.isEmpty)
    player.disposeWithError(&error)
    #expect(error?.code == "native_video_dispose_incomplete")

    nativePlayer.remainingIgnoredDetachCalls = 0
    #expect(plugin.retryPendingExactReleases() == 1)
    #expect(channels.fullyDetached)
    #expect(!messenger.activeChannels.contains(play))
    #expect(bridge.releases.count == 1)
    #expect(plugin.pendingPlatformClaimCountForNativeTests == 0)
    player.disposeWithError(&error)
    #expect(error == nil)
  }

  @Test func partialChannelCleanupKeepsStaleSpeedInertAndRetriesExactToken() throws {
    let file = try localURL()
    defer { try? FileManager.default.removeItem(at: file) }
    let nativePlayer = IgnoringDetachAVPlayer(playerItem: AVPlayerItem(url: file))
    let messenger = StubBinaryMessenger()
    let plugin = makePlugin(StubFVPAVFactory(player: nativePlayer), messenger: messenger)
    let bridge = FakeVideoPermitBridge()
    #expect(plugin.installVideoPermitBridge(bridge))
    plugin.enablePlatformViewCreationForNativeTests()
    let id = try plugin.createPlatformViewPlayer(options: options(file.absoluteString))
    let player = try #require(plugin.playersByIdentifier[id])
    let channels = try #require(plugin.instanceChannelsForNativeTests(id))
    let speed = "dev.flutter.pigeon.video_player_avfoundation.VideoPlayerInstanceApi.setPlaybackSpeed.\(id)"
    let registrations = messenger.activeChannels.filter { $0.contains("VideoPlayerInstanceApi.") }.sorted()
    let speedIndex = try #require(registrations.firstIndex(of: speed))
    channels.throwBeforeCleanupOnAttemptForNativeTests = UInt(speedIndex + 1)

    var error: FlutterError?
    player.disposeWithError(&error)
    #expect(error?.code == "native_video_dispose_incomplete")
    #expect(channels.detachedCount == 12)
    #expect(bridge.releases.isEmpty)
    #expect(player.player === nativePlayer)
    #expect(messenger.activeChannels.contains(speed))
    let oldRate = nativePlayer.rate
    let response = messenger.invokeInstanceChannel(speed, arguments: [2.0])
    #expect(response?.first as? String == "native_video_disposed")
    #expect(nativePlayer.rate == oldRate)
    #expect(bridge.releases.isEmpty)
    player.disposeWithError(&error)
    #expect(error?.code == "native_video_dispose_incomplete")

    nativePlayer.remainingIgnoredDetachCalls = 0
    #expect(plugin.retryPendingExactReleases() == 1)
    #expect(channels.fullyDetached)
    #expect(!messenger.activeChannels.contains(speed))
    #expect(bridge.releases.count == 1)
    player.disposeWithError(&error)
    #expect(error == nil)
  }

  @Test func disposedPartialChannelRetryCannotAcknowledgeBeforeNativeStop() throws {
    let file = try localURL()
    defer { try? FileManager.default.removeItem(at: file) }
    let nativePlayer = IgnoringDetachAVPlayer(playerItem: AVPlayerItem(url: file))
    let messenger = StubBinaryMessenger()
    let plugin = makePlugin(StubFVPAVFactory(player: nativePlayer), messenger: messenger)
    let bridge = FakeVideoPermitBridge()
    #expect(plugin.installVideoPermitBridge(bridge))
    plugin.enablePlatformViewCreationForNativeTests()
    let id = try plugin.createPlatformViewPlayer(options: options(file.absoluteString))
    let player = try #require(plugin.playersByIdentifier[id])
    let channels = try #require(plugin.instanceChannelsForNativeTests(id))
    channels.throwBeforeCleanupOnAttemptForNativeTests = 1

    var error: FlutterError?
    player.disposeWithError(&error)
    #expect(error?.code == "native_video_dispose_incomplete")
    #expect(player.disposed)
    #expect(channels.detachedCount == 12)
    #expect(bridge.releases.isEmpty)

    #expect(plugin.retryPendingExactReleases() == 0)
    #expect(channels.fullyDetached)
    #expect(channels.detachedCount == 13)
    #expect(channels.cleanupAttemptCount == 14)
    #expect(nativePlayer.currentItem != nil)
    #expect(bridge.releases.isEmpty)
    #expect(plugin.pendingPlatformClaimCountForNativeTests == 1)

    nativePlayer.remainingIgnoredDetachCalls = 0
    #expect(plugin.retryPendingExactReleases() == 1)
    #expect(nativePlayer.currentItem == nil)
    #expect(bridge.releases.count == 1)
    #expect(plugin.pendingPlatformClaimCountForNativeTests == 0)
  }

  @Test func oldCleanupTokenCannotRemoveNewHandlerOnReusedSuffix() throws {
    let file = try localURL()
    defer { try? FileManager.default.removeItem(at: file) }
    let messenger = StubBinaryMessenger()
    let plugin = makePlugin(StubFVPAVFactory(), messenger: messenger)
    let bridge = FakeVideoPermitBridge()
    #expect(plugin.installVideoPermitBridge(bridge))
    plugin.enablePlatformViewCreationForNativeTests()
    let id = try plugin.createPlatformViewPlayer(options: options(file.absoluteString))
    let player = try #require(plugin.playersByIdentifier[id])
    let channels = try #require(plugin.instanceChannelsForNativeTests(id))
    let play = "dev.flutter.pigeon.video_player_avfoundation.VideoPlayerInstanceApi.play.\(id)"
    let registrations = messenger.activeChannels.filter { $0.contains("VideoPlayerInstanceApi.") }.sorted()
    let playIndex = try #require(registrations.firstIndex(of: play))
    channels.throwAfterCleanupOnAttemptForNativeTests = UInt(playIndex + 1)

    var error: FlutterError?
    player.disposeWithError(&error)
    #expect(error?.code == "native_video_dispose_incomplete")
    #expect(channels.detachedCount == 12)
    #expect(bridge.releases.isEmpty)
    player.disposeWithError(&error)
    #expect(error?.code == "native_video_dispose_incomplete")
    #expect(!messenger.activeChannels.contains(play))
    let newToken = messenger.setMessageHandlerOnChannel(play, binaryMessageHandler: { _, reply in
      reply(nil)
    })
    #expect(messenger.activeChannels.contains(play))

    #expect(plugin.retryPendingExactReleases() == 1)
    #expect(channels.fullyDetached)
    #expect(bridge.releases.count == 1)
    #expect(messenger.activeChannels.contains(play))
    player.disposeWithError(&error)
    #expect(error == nil)
    messenger.cleanUpConnection(newToken)
    #expect(!messenger.activeChannels.contains(play))
  }

  @Test func registrationCallbackAloneCannotReleaseBeforeObjCDisposal() throws {
    let file = try localURL()
    defer { try? FileManager.default.removeItem(at: file) }
    let plugin = makePlugin(StubFVPAVFactory())
    let bridge = FakeVideoPermitBridge()
    #expect(plugin.installVideoPermitBridge(bridge))
    plugin.enablePlatformViewCreationForNativeTests()
    let id = try plugin.createPlatformViewPlayer(options: options(file.absoluteString))
    let player = try #require(plugin.playersByIdentifier[id])
    player.onDisposed?()
    #expect(!player.disposed)
    #expect(bridge.releases.isEmpty)
    #expect(plugin.pendingPlatformClaimCountForNativeTests == 1)
    var error: FlutterError?
    player.disposeWithError(&error)
    #expect(error == nil)
    #expect(bridge.releases.count == 1)
  }

  @Test func disposalRemovesKVOFromOriginallyObservedItemAfterCurrentItemChanges() throws {
    let file = try localURL()
    defer { try? FileManager.default.removeItem(at: file) }
    let av = StubFVPAVFactory(player: AVPlayer(playerItem: AVPlayerItem(url: file)))
    let plugin = makePlugin(av)
    let bridge = FakeVideoPermitBridge()
    #expect(plugin.installVideoPermitBridge(bridge))
    plugin.enablePlatformViewCreationForNativeTests()
    let id = try plugin.createPlatformViewPlayer(options: options(file.absoluteString))
    let player = try #require(plugin.playersByIdentifier[id])
    let originallyObserved = try #require(av.player.currentItem)
    let replacement = AVPlayerItem(url: file)
    av.player.replaceCurrentItem(with: replacement)
    #expect(av.player.currentItem === replacement)
    var error: FlutterError?
    player.disposeWithError(&error)
    #expect(error == nil)
    #expect(av.player.currentItem == nil)
    #expect(player.player == nil)
    #expect(bridge.releases.count == 1)
    #expect(plugin.pendingPlatformClaimCountForNativeTests == 0)
    // Keep the original alive through this assertion; disposal must have
    // detached its KVO without attempting to remove it from replacement.
    _ = originallyObserved
  }

  @Test func disposedPlatformViewStopsObservingRetainedAVPlayerRate() throws {
    let file = try localURL()
    defer { try? FileManager.default.removeItem(at: file) }
    let retainedAVPlayer = AVPlayer(playerItem: AVPlayerItem(url: file))
    let av = StubFVPAVFactory(player: retainedAVPlayer)
    let messenger = StubBinaryMessenger()
    let bridge = FakeVideoPermitBridge()
    weak var disposedPlayer: FVPVideoPlayer?

    try autoreleasepool {
      let plugin = makePlugin(av, messenger: messenger)
      #expect(plugin.installVideoPermitBridge(bridge))
      plugin.enablePlatformViewCreationForNativeTests()
      let id = try plugin.createPlatformViewPlayer(options: options(file.absoluteString))
      let player = try #require(plugin.playersByIdentifier[id])
      disposedPlayer = player
      let channels = try #require(plugin.instanceChannelsForNativeTests(id))
      #expect(channels.registrationComplete)
      #expect(channels.registeredCount == 13)

      // Prove that rate KVO was attached before testing its removal. Keep the
      // original event bridge so dispose can close its Flutter event channel.
      let eventBridge = try #require(player.eventListener)
      let rateProbe = StubEventListener()
      player.eventListener = rateProbe
      let eventsBeforeNotification = rateProbe.playingStateEventCount
      retainedAVPlayer.willChangeValue(forKey: "rate")
      retainedAVPlayer.didChangeValue(forKey: "rate")
      #expect(rateProbe.playingStateEventCount > eventsBeforeNotification)
      player.eventListener = eventBridge

      var error: FlutterError?
      player.disposeWithError(&error)
      #expect(error == nil)
      #expect(retainedAVPlayer.currentItem == nil)
      #expect(player.player == nil)
      #expect(player.eventListener == nil)
      #expect(plugin.playersByIdentifier[id] == nil)
      #expect(channels.fullyDetached)
      #expect(channels.detachedCount == 13)
      #expect(!messenger.activeChannels.contains(where: {
        $0.contains("VideoPlayerInstanceApi.") || $0.contains("videoEvents\(id)")
      }))
      #expect(plugin.pendingPlatformClaimCountForNativeTests == 0)
      #expect(bridge.claims.count == 1)
      #expect(bridge.releases.count == 1)
      let claim = try #require(bridge.claims.first)
      let release = try #require(bridge.releases.first)
      #expect(claim.1 == id)
      #expect(release.0 == claim.0)
      #expect(release.1 == claim.1)
    }

    // A still-retained wrapper would make this crash regression vacuous.
    #expect(disposedPlayer == nil)
    retainedAVPlayer.willChangeValue(forKey: "rate")
    retainedAVPlayer.didChangeValue(forKey: "rate")
    #expect(bridge.releases.count == 1)
  }

  @Test func attachedItemAfterStopCallCannotAcknowledgeExactRelease() throws {
    let file = try localURL()
    defer { try? FileManager.default.removeItem(at: file) }
    let nativePlayer = IgnoringDetachAVPlayer(playerItem: AVPlayerItem(url: file))
    let plugin = makePlugin(StubFVPAVFactory(player: nativePlayer))
    let bridge = FakeVideoPermitBridge()
    #expect(plugin.installVideoPermitBridge(bridge))
    plugin.enablePlatformViewCreationForNativeTests()
    let id = try plugin.createPlatformViewPlayer(options: options(file.absoluteString))
    let player = try #require(plugin.playersByIdentifier[id])
    var error: FlutterError?
    player.disposeWithError(&error)
    #expect(error?.code == "native_video_dispose_incomplete")
    #expect(nativePlayer.rejectedDetachCalls == 1)
    #expect(nativePlayer.currentItem != nil)
    #expect(bridge.releases.isEmpty)
    #expect(plugin.pendingPlatformClaimCountForNativeTests == 1)
    #expect(plugin.playersByIdentifier[id] == nil)
    #expect(plugin.retryPendingExactReleases() == 0)
    #expect(nativePlayer.detachCalls == 2)
    #expect(nativePlayer.currentItem != nil)
    #expect(bridge.releases.isEmpty)
    #expect(plugin.pendingPlatformClaimCountForNativeTests == 1)
  }

  @Test func temporarySilentDetachFailureRetriesOnlyNativeStopAfterCleanup() throws {
    let file = try localURL()
    defer { try? FileManager.default.removeItem(at: file) }
    let nativePlayer = IgnoringDetachAVPlayer(playerItem: AVPlayerItem(url: file))
    nativePlayer.remainingIgnoredDetachCalls = 1
    let av = StubFVPAVFactory(player: nativePlayer)
    let messenger = StubBinaryMessenger()
    let plugin = makePlugin(av, messenger: messenger)
    let bridge = FakeVideoPermitBridge()
    #expect(plugin.installVideoPermitBridge(bridge))
    plugin.enablePlatformViewCreationForNativeTests()
    let id = try plugin.createPlatformViewPlayer(options: options(file.absoluteString))
    let player = try #require(plugin.playersByIdentifier[id])
    #if os(iOS)
      let view = try #require(plugin.nativeViewFactory?.create(
        withFrame: .zero, viewIdentifier: 1,
        arguments: PlatformVideoViewCreationParams(playerId: id)) as? FVPNativeVideoView)
      let layer = try #require(view.view().layer as? AVPlayerLayer)
      #expect(layer.player != nil)
    #endif
    var error: FlutterError?
    player.disposeWithError(&error)
    #expect(error?.code == "native_video_dispose_incomplete")
    #expect(nativePlayer.detachCalls == 1)
    #expect(nativePlayer.currentItem != nil)
    #expect(player.player === nativePlayer)
    #expect(plugin.playersByIdentifier[id] == nil)
    #expect(!messenger.activeChannels.contains(where: {
      $0.contains("VideoPlayerInstanceApi.") || $0.contains("videoEvents\(id)")
    }))
    #if os(iOS)
      #expect(layer.player == nil)
    #endif
    #expect(bridge.releases.isEmpty)
    #expect(plugin.pendingPlatformClaimCountForNativeTests == 1)

    bridge.onRelease = {
      #expect(nativePlayer.currentItem == nil)
      #expect(player.player == nil)
      #expect(player.eventListener == nil)
      #expect(plugin.playersByIdentifier[id] == nil)
      #expect(!messenger.activeChannels.contains(where: {
        $0.contains("VideoPlayerInstanceApi.") || $0.contains("videoEvents\(id)")
      }))
      #if os(iOS)
        #expect(layer.player == nil)
      #endif
    }
    nativePlayer.onDetach = {
      // A synchronous native callback cannot start a second overlapping
      // stop retry or acknowledge the exact claim ahead of the outer call.
      #expect(plugin.retryPendingExactReleases() == 0)
      #expect(bridge.releases.isEmpty)
    }
    #expect(plugin.retryPendingExactReleases() == 1)
    nativePlayer.onDetach = nil
    #expect(nativePlayer.detachCalls == 2)
    #expect(nativePlayer.rejectedDetachCalls == 1)
    #expect(nativePlayer.currentItem == nil)
    #expect(player.player == nil)
    #expect(bridge.releases.count == 1)
    #expect(plugin.pendingPlatformClaimCountForNativeTests == 0)
    #expect(plugin.retryPendingExactReleases() == 0)
    #expect(bridge.releases.count == 1)
  }

  @Test func disposedStaleCommandsCannotChangeQuarantinedNativePlayer() throws {
    let file = try localURL()
    defer { try? FileManager.default.removeItem(at: file) }
    let nativePlayer = IgnoringDetachAVPlayer(playerItem: AVPlayerItem(url: file))
    let plugin = makePlugin(StubFVPAVFactory(player: nativePlayer))
    let bridge = FakeVideoPermitBridge()
    #expect(plugin.installVideoPermitBridge(bridge))
    plugin.enablePlatformViewCreationForNativeTests()
    let id = try plugin.createPlatformViewPlayer(options: options(file.absoluteString))
    let player = try #require(plugin.playersByIdentifier[id])

    var error: FlutterError?
    player.disposeWithError(&error)
    #expect(error?.code == "native_video_dispose_incomplete")
    #expect(nativePlayer.currentItem != nil)
    #expect(bridge.releases.isEmpty)

    error = nil
    player.playWithError(&error)
    #expect(error?.code == "native_video_disposed")
    error = nil
    player.setPlaybackSpeed(2, error: &error)
    #expect(error?.code == "native_video_disposed")
    let volumeBefore = nativePlayer.volume
    error = nil
    player.setVolume(0.25, error: &error)
    #expect(error?.code == "native_video_disposed")
    #expect(nativePlayer.volume == volumeBefore)
    let item = try #require(nativePlayer.currentItem)
    let bitrateBefore = item.preferredPeakBitRate
    error = nil
    player.selectVideoTrack(withBitrate: 5_000_000, error: &error)
    #expect(error?.code == "native_video_disposed")
    #expect(item.preferredPeakBitRate == bitrateBefore)
    error = nil
    let audioTracks = player.getAudioTracks(&error)
    #expect(audioTracks == nil)
    #expect(error?.code == "native_video_disposed")
    let sleepBefore = nativePlayer.preventsDisplaySleepDuringVideoPlayback
    error = nil
    player.setPreventsDisplaySleepDuringVideoPlayback(!sleepBefore, error: &error)
    #expect(error?.code == "native_video_disposed")
    #expect(nativePlayer.preventsDisplaySleepDuringVideoPlayback == sleepBefore)
    error = nil
    player.pauseWithError(&error)
    #expect(error?.code == "native_video_disposed")
    #expect(nativePlayer.currentItem != nil)
    #expect(bridge.releases.isEmpty)

    // A rejected stale command must not consume the one safe stop-only retry.
    nativePlayer.remainingIgnoredDetachCalls = 0
    error = nil
    player.disposeWithError(&error)
    #expect(error == nil)
    #expect(nativePlayer.currentItem == nil)
    #expect(bridge.releases.count == 1)
  }

  @Test func disposedAsyncCommandsReplyOnceWithoutReadingNativeMedia() throws {
    let file = try localURL()
    defer { try? FileManager.default.removeItem(at: file) }
    let nativePlayer = IgnoringDetachAVPlayer(playerItem: AVPlayerItem(url: file))
    let plugin = makePlugin(StubFVPAVFactory(player: nativePlayer))
    let bridge = FakeVideoPermitBridge()
    #expect(plugin.installVideoPermitBridge(bridge))
    plugin.enablePlatformViewCreationForNativeTests()
    let id = try plugin.createPlatformViewPlayer(options: options(file.absoluteString))
    let player = try #require(plugin.playersByIdentifier[id])
    var error: FlutterError?
    player.disposeWithError(&error)
    #expect(error?.code == "native_video_dispose_incomplete")

    var seekReplies = 0
    player.seek(to: 1000) { reply in
      seekReplies += 1
      #expect(reply?.code == "native_video_disposed")
    }
    var trackReplies = 0
    player.getVideoTracks { _, reply in
      trackReplies += 1
      #expect(reply?.code == "native_video_disposed")
    }
    #expect(seekReplies == 1)
    #expect(trackReplies == 1)
    #expect(nativePlayer.currentItem != nil)
    #expect(bridge.releases.isEmpty)
  }

  @Test func seekStartedBeforeDisposeCannotCompleteSuccessfullyAfterDispose() async throws {
    let file = try localURL()
    defer { try? FileManager.default.removeItem(at: file) }
    let nativePlayer = DeferredSeekAVPlayer(playerItem: AVPlayerItem(url: file))
    let plugin = makePlugin(StubFVPAVFactory(player: nativePlayer))
    let bridge = FakeVideoPermitBridge()
    #expect(plugin.installVideoPermitBridge(bridge))
    plugin.enablePlatformViewCreationForNativeTests()
    let id = try plugin.createPlatformViewPlayer(options: options(file.absoluteString))
    let player = try #require(plugin.playersByIdentifier[id])
    var replies = 0

    let replyCode: String? = await withCheckedContinuation { continuation in
      player.seek(to: 1000) { error in
        replies += 1
        continuation.resume(returning: error?.code)
      }
      guard nativePlayer.pendingSeek != nil else {
        Issue.record("Native seek did not enter the deferred fake")
        continuation.resume(returning: nil)
        return
      }
      #expect(replies == 0)
      var disposeError: FlutterError?
      player.disposeWithError(&disposeError)
      #expect(disposeError == nil)
      #expect(player.disposed)
      #expect(bridge.releases.count == 1)
      nativePlayer.finishSeek()
    }
    #expect(replyCode == "native_video_disposed")
    #expect(replies == 1)
    #expect(bridge.releases.count == 1)
  }

  @Test func variantLoadStartedBeforeDisposeCannotReadOrReturnStaleMedia() async throws {
    let file = try localURL()
    defer { try? FileManager.default.removeItem(at: file) }
    let asset = DeferredVariantsAsset(url: file)
    let nativePlayer = AVPlayer(playerItem: AVPlayerItem(asset: asset))
    let plugin = makePlugin(StubFVPAVFactory(player: nativePlayer))
    let bridge = FakeVideoPermitBridge()
    #expect(plugin.installVideoPermitBridge(bridge))
    plugin.enablePlatformViewCreationForNativeTests()
    let id = try plugin.createPlatformViewPlayer(options: options(file.absoluteString))
    let player = try #require(plugin.playersByIdentifier[id])
    var replies = 0
    var variantReadsBeforeCompletion = 0

    let reply: (String?, Bool) = await withCheckedContinuation { continuation in
      player.getVideoTracks { tracks, error in
        replies += 1
        continuation.resume(returning: (error?.code, tracks == nil))
      }
      guard asset.pendingVariantLoad != nil else {
        Issue.record("Variant load did not enter the deferred fake")
        continuation.resume(returning: (nil, false))
        return
      }
      #expect(replies == 0)
      var disposeError: FlutterError?
      player.disposeWithError(&disposeError)
      #expect(disposeError == nil)
      #expect(player.disposed)
      #expect(bridge.releases.count == 1)
      variantReadsBeforeCompletion = asset.variantStatusReads
      asset.finishVariantLoad()
    }
    #expect(reply.0 == "native_video_disposed")
    #expect(reply.1)
    #expect(replies == 1)
    #expect(asset.variantStatusReads == variantReadsBeforeCompletion)
    #expect(bridge.releases.count == 1)
  }

  @Test func inFlightCommandsKeepNormalRepliesWhilePlayerRemainsLive() async throws {
    let file = try localURL()
    defer { try? FileManager.default.removeItem(at: file) }
    let asset = DeferredVariantsAsset(url: file)
    let nativePlayer = DeferredSeekAVPlayer(playerItem: AVPlayerItem(asset: asset))
    let plugin = makePlugin(StubFVPAVFactory(player: nativePlayer))
    let bridge = FakeVideoPermitBridge()
    #expect(plugin.installVideoPermitBridge(bridge))
    plugin.enablePlatformViewCreationForNativeTests()
    let id = try plugin.createPlatformViewPlayer(options: options(file.absoluteString))
    let player = try #require(plugin.playersByIdentifier[id])

    let seekCode: String? = await withCheckedContinuation { continuation in
      player.seek(to: 1000) { error in continuation.resume(returning: error?.code) }
      guard nativePlayer.pendingSeek != nil else {
        Issue.record("Live seek did not enter the deferred fake")
        continuation.resume(returning: "missing_seek")
        return
      }
      nativePlayer.finishSeek()
    }
    #expect(seekCode == nil)

    let trackReply: (String?, Bool) = await withCheckedContinuation { continuation in
      player.getVideoTracks { tracks, error in
        continuation.resume(returning: (error?.code, tracks != nil))
      }
      guard asset.pendingVariantLoad != nil else {
        Issue.record("Live variant load did not enter the deferred fake")
        continuation.resume(returning: ("missing_load", false))
        return
      }
      asset.finishVariantLoad()
    }
    #expect(trackReply.0 == nil)
    #expect(trackReply.1)
    var disposeError: FlutterError?
    player.disposeWithError(&disposeError)
    #expect(disposeError == nil)
    #expect(bridge.releases.count == 1)
  }

  @Test func pendingAsyncRepliesDrainOnDisposeWithoutAnyNativeCallback() throws {
    let file = try localURL()
    defer { try? FileManager.default.removeItem(at: file) }
    let asset = DeferredVariantsAsset(url: file)
    let nativePlayer = DeferredSeekAVPlayer(playerItem: AVPlayerItem(asset: asset))
    let plugin = makePlugin(StubFVPAVFactory(player: nativePlayer))
    let bridge = FakeVideoPermitBridge()
    #expect(plugin.installVideoPermitBridge(bridge))
    plugin.enablePlatformViewCreationForNativeTests()
    let id = try plugin.createPlatformViewPlayer(options: options(file.absoluteString))
    let player = try #require(plugin.playersByIdentifier[id])

    var seekCodes: [String?] = []
    var trackCodes: [String?] = []
    var trackResultsWereNil: [Bool] = []
    player.seek(to: 1000) { seekCodes.append($0?.code) }
    player.getVideoTracks { tracks, error in
      trackCodes.append(error?.code)
      trackResultsWereNil.append(tracks == nil)
    }
    #expect(nativePlayer.pendingSeek != nil)
    #expect(asset.pendingVariantLoad != nil)
    #expect(seekCodes.isEmpty)
    #expect(trackCodes.isEmpty)

    var disposeError: FlutterError?
    player.disposeWithError(&disposeError)
    #expect(disposeError == nil)
    #expect(seekCodes == ["native_video_disposed"])
    #expect(trackCodes == ["native_video_disposed"])
    #expect(trackResultsWereNil == [true])
    #expect(bridge.releases.count == 1)
    player.disposeWithError(&disposeError)
    #expect(seekCodes.count == 1)
    #expect(trackCodes.count == 1)
    #expect(bridge.releases.count == 1)
    // Neither deferred AV callback is invoked; disposal itself provided both replies.
  }

  @Test func callbacksArrivingAfterDisposeDoNotReplyOrReadTracksAgain() async throws {
    let file = try localURL()
    defer { try? FileManager.default.removeItem(at: file) }
    let asset = DeferredVariantsAsset(url: file)
    let nativePlayer = DeferredSeekAVPlayer(playerItem: AVPlayerItem(asset: asset))
    let plugin = makePlugin(StubFVPAVFactory(player: nativePlayer))
    let bridge = FakeVideoPermitBridge()
    #expect(plugin.installVideoPermitBridge(bridge))
    plugin.enablePlatformViewCreationForNativeTests()
    let id = try plugin.createPlatformViewPlayer(options: options(file.absoluteString))
    let player = try #require(plugin.playersByIdentifier[id])

    var seekCodes: [String?] = []
    var trackCodes: [String?] = []
    player.seek(to: 1000) { seekCodes.append($0?.code) }
    player.getVideoTracks { _, error in trackCodes.append(error?.code) }
    #expect(nativePlayer.pendingSeek != nil)
    #expect(asset.pendingVariantLoad != nil)
    var disposeError: FlutterError?
    player.disposeWithError(&disposeError)
    #expect(disposeError == nil)
    #expect(seekCodes == ["native_video_disposed"])
    #expect(trackCodes == ["native_video_disposed"])
    let variantReadsAfterDispose = asset.variantStatusReads

    nativePlayer.finishSeek()
    asset.finishVariantLoad()
    await flushMainQueue()
    #expect(seekCodes == ["native_video_disposed"])
    #expect(trackCodes == ["native_video_disposed"])
    #expect(asset.variantStatusReads == variantReadsAfterDispose)
    #expect(bridge.releases.count == 1)
  }

  @Test func incompleteNativeStopDrainsRepliesButKeepsExactClaim() async throws {
    let file = try localURL()
    defer { try? FileManager.default.removeItem(at: file) }
    let asset = DeferredVariantsAsset(url: file)
    let nativePlayer = DeferredSeekAVPlayer(playerItem: AVPlayerItem(asset: asset))
    nativePlayer.ignoreNilItemDetach = true
    let plugin = makePlugin(StubFVPAVFactory(player: nativePlayer))
    let bridge = FakeVideoPermitBridge()
    #expect(plugin.installVideoPermitBridge(bridge))
    plugin.enablePlatformViewCreationForNativeTests()
    let id = try plugin.createPlatformViewPlayer(options: options(file.absoluteString))
    let player = try #require(plugin.playersByIdentifier[id])

    var seekCodes: [String?] = []
    var trackCodes: [String?] = []
    player.seek(to: 1000) { seekCodes.append($0?.code) }
    player.getVideoTracks { _, error in trackCodes.append(error?.code) }
    #expect(nativePlayer.pendingSeek != nil)
    #expect(asset.pendingVariantLoad != nil)
    var disposeError: FlutterError?
    player.disposeWithError(&disposeError)
    #expect(disposeError?.code == "native_video_dispose_incomplete")
    #expect(seekCodes == ["native_video_disposed"])
    #expect(trackCodes == ["native_video_disposed"])
    #expect(nativePlayer.currentItem != nil)
    #expect(bridge.releases.isEmpty)
    #expect(plugin.pendingPlatformClaimCountForNativeTests == 1)
    player.disposeWithError(&disposeError)
    #expect(seekCodes.count == 1)
    #expect(trackCodes.count == 1)
    #expect(bridge.releases.isEmpty)

    nativePlayer.finishSeek()
    asset.finishVariantLoad()
    await flushMainQueue()
    #expect(seekCodes == ["native_video_disposed"])
    #expect(trackCodes == ["native_video_disposed"])
    #expect(bridge.releases.isEmpty)
  }

  @Test func reentrantDisposeDuringVariantStatusCannotReturnOldTracks() async throws {
    let file = try localURL()
    defer { try? FileManager.default.removeItem(at: file) }
    let asset = DeferredVariantsAsset(url: file)
    let nativePlayer = AVPlayer(playerItem: AVPlayerItem(asset: asset))
    let plugin = makePlugin(StubFVPAVFactory(player: nativePlayer))
    let bridge = FakeVideoPermitBridge()
    #expect(plugin.installVideoPermitBridge(bridge))
    plugin.enablePlatformViewCreationForNativeTests()
    let id = try plugin.createPlatformViewPlayer(options: options(file.absoluteString))
    let player = try #require(plugin.playersByIdentifier[id])
    var replies: [(String?, Bool)] = []
    player.getVideoTracks { tracks, error in
      replies.append((error?.code, tracks == nil))
    }
    #expect(asset.pendingVariantLoad != nil)
    asset.onVariantStatusRead = {
      asset.onVariantStatusRead = nil
      var disposeError: FlutterError?
      player.disposeWithError(&disposeError)
      #expect(disposeError == nil)
    }
    asset.finishVariantLoad()
    await flushMainQueue()
    #expect(replies.count == 1)
    #expect(replies.first?.0 == "native_video_disposed")
    #expect(replies.first?.1 == true)
    #expect(asset.variantStatusReads == 1)
    #expect(bridge.releases.count == 1)
  }

  @Test func reentrantEngineDetachDuringAVAssetQuarantinesWithoutConstructingPlayer() throws {
    let file = try localURL()
    defer { try? FileManager.default.removeItem(at: file) }
    let av = StubFVPAVFactory()
    let plugin = makePlugin(av)
    let bridge = FakeVideoPermitBridge()
    #expect(plugin.installVideoPermitBridge(bridge))
    plugin.enablePlatformViewCreationForNativeTests()
    av.onURLAsset = { plugin.retireVideoEngine() }
    do {
      _ = try plugin.createPlatformViewPlayer(options: options(file.absoluteString))
      Issue.record("Detached engine returned a player ID")
    } catch {}
    #expect(av.urlAssetCalls == 1)
    #expect(av.playerItemCalls == 0)
    #expect(av.playerCalls == 0)
    #expect(plugin.playersByIdentifier.isEmpty)
    #expect(bridge.releases.isEmpty)
    #expect(plugin.pendingPlatformClaimCountForNativeTests == 1)
    #expect(!plugin.installVideoPermitBridge(FakeVideoPermitBridge()))
  }

  @Test func reentrantEngineDetachDuringPlayerItemQuarantinesWithoutAVPlayer() throws {
    let file = try localURL()
    defer { try? FileManager.default.removeItem(at: file) }
    let av = StubFVPAVFactory()
    let plugin = makePlugin(av)
    let bridge = FakeVideoPermitBridge()
    #expect(plugin.installVideoPermitBridge(bridge))
    plugin.enablePlatformViewCreationForNativeTests()
    av.onPlayerItem = { plugin.retireVideoEngine() }
    do {
      _ = try plugin.createPlatformViewPlayer(options: options(file.absoluteString))
      Issue.record("Detached engine constructed AVPlayer")
    } catch {}
    #expect(av.urlAssetCalls == 1)
    #expect(av.playerItemCalls == 1)
    #expect(av.playerCalls == 0)
    #expect(bridge.releases.isEmpty)
    #expect(plugin.pendingPlatformClaimCountForNativeTests == 1)
  }

  @Test func reentrantDetachDuringEventChannelRegistrationClosesOrphanHandler() throws {
    let file = try localURL()
    defer { try? FileManager.default.removeItem(at: file) }
    let messenger = StubBinaryMessenger()
    let plugin = makePlugin(StubFVPAVFactory(), messenger: messenger)
    let bridge = FakeVideoPermitBridge()
    #expect(plugin.installVideoPermitBridge(bridge))
    plugin.enablePlatformViewCreationForNativeTests()
    messenger.onSetMessageHandler = { channel in
      if channel.contains("videoEvents1") { plugin.retireVideoEngine() }
    }
    do {
      _ = try plugin.createPlatformViewPlayer(options: options(file.absoluteString))
      Issue.record("Detached engine returned a player")
    } catch {}
    #expect(plugin.playersByIdentifier.isEmpty)
    #expect(!messenger.activeChannels.contains(where: { $0.contains("videoEvents1") }))
    #expect(bridge.releases.count == 1)
    #expect(plugin.pendingPlatformClaimCountForNativeTests == 0)
  }

  @Test func reentrantEngineDetachInClaimCallbackNeverStartsAV() throws {
    let file = try localURL()
    defer { try? FileManager.default.removeItem(at: file) }
    let av = StubFVPAVFactory()
    let plugin = makePlugin(av)
    let bridge = FakeVideoPermitBridge()
    #expect(plugin.installVideoPermitBridge(bridge))
    plugin.enablePlatformViewCreationForNativeTests()
    bridge.onClaim = { plugin.retireVideoEngine() }
    do {
      _ = try plugin.createPlatformViewPlayer(options: options(file.absoluteString))
      Issue.record("Retired engine started native creation")
    } catch {}
    #expect(av.urlAssetCalls == 0)
    #expect(av.playerCalls == 0)
    #expect(plugin.playersByIdentifier.isEmpty)
    #expect(bridge.releases.count == 1)
    #expect(plugin.pendingPlatformClaimCountForNativeTests == 0)
  }

  @Test func reentrantEngineDetachInPreAVHookNeverStartsAV() throws {
    let file = try localURL()
    defer { try? FileManager.default.removeItem(at: file) }
    let av = StubFVPAVFactory()
    let plugin = makePlugin(av)
    let bridge = FakeVideoPermitBridge()
    #expect(plugin.installVideoPermitBridge(bridge))
    plugin.enablePlatformViewCreationForNativeTests()
    plugin.beforeFirstAVEffectForNativeTests = { plugin.retireVideoEngine() }
    do {
      _ = try plugin.createPlatformViewPlayer(options: options(file.absoluteString))
      Issue.record("Retired engine started AVAsset creation")
    } catch {}
    #expect(av.urlAssetCalls == 0)
    #expect(av.playerCalls == 0)
    #expect(bridge.releases.count == 1)
    #expect(plugin.pendingPlatformClaimCountForNativeTests == 0)
  }

  @Test func failureAfterClaimButBeforeFirstAVEffectReleasesExactEmptyClaim() throws {
    enum PreAVFailure: Error { case injected }
    let file = try localURL()
    defer { try? FileManager.default.removeItem(at: file) }
    let av = StubFVPAVFactory()
    let plugin = makePlugin(av)
    let bridge = FakeVideoPermitBridge()
    #expect(plugin.installVideoPermitBridge(bridge))
    plugin.enablePlatformViewCreationForNativeTests()
    plugin.beforeFirstAVEffectForNativeTests = { throw PreAVFailure.injected }
    do {
      _ = try plugin.createPlatformViewPlayer(options: options(file.absoluteString))
      Issue.record("Pre-AV failure returned a player ID")
    } catch {}
    #expect(av.urlAssetCalls == 0)
    #expect(av.playerCalls == 0)
    #expect(plugin.playersByIdentifier.isEmpty)
    #expect(bridge.claims.count == 1)
    #expect(bridge.releases.count == 1)
    #expect(bridge.releases[0].1 == bridge.claims[0].1)
    #expect(bridge.releases[0].0 == bridge.claims[0].0)
    #expect(plugin.pendingPlatformClaimCountForNativeTests == 0)
  }

  @Test func failureAfterAVAssetWithoutPlayerQuarantinesTheExactClaim() throws {
    enum AssetFailure: Error { case injected }
    let file = try localURL()
    defer { try? FileManager.default.removeItem(at: file) }
    let av = StubFVPAVFactory()
    let plugin = makePlugin(av)
    let bridge = FakeVideoPermitBridge()
    #expect(plugin.installVideoPermitBridge(bridge))
    plugin.enablePlatformViewCreationForNativeTests()
    plugin.afterAVAssetForNativeTests = { throw AssetFailure.injected }
    do {
      _ = try plugin.createPlatformViewPlayer(options: options(file.absoluteString))
      Issue.record("Ambiguous asset failure returned a player ID")
    } catch {}
    #expect(av.urlAssetCalls == 1)
    #expect(av.playerCalls == 0)
    #expect(plugin.playersByIdentifier.isEmpty)
    #expect(bridge.claims.count == 1)
    #expect(bridge.releases.isEmpty)
    #expect(plugin.pendingPlatformClaimCountForNativeTests == 1)
  }

  @Test func reentrantClaimRevocationRollsBackWithoutReturningPlayer() throws {
    let file = try localURL()
    defer { try? FileManager.default.removeItem(at: file) }
    let av = StubFVPAVFactory()
    let plugin = makePlugin(av)
    let bridge = FakeVideoPermitBridge()
    bridge.acceptAfterEffect = false
    #expect(plugin.installVideoPermitBridge(bridge))
    plugin.enablePlatformViewCreationForNativeTests()
    do {
      _ = try plugin.createPlatformViewPlayer(options: options(file.absoluteString))
      Issue.record("Revoked claim returned a player ID")
    } catch {}
    #expect(av.urlAssetCalls == 1)
    #expect(plugin.playersByIdentifier.isEmpty)
    #expect(bridge.releases.count == 1)
    #expect(bridge.releases[0].1 == 1)
  }

  @Test func failedExactReleaseStaysQuarantinedAcrossEngineRetirement() throws {
    let file = try localURL()
    defer { try? FileManager.default.removeItem(at: file) }
    let plugin = makePlugin(StubFVPAVFactory())
    let bridge = FakeVideoPermitBridge()
    bridge.releaseConfirmed = false
    #expect(plugin.installVideoPermitBridge(bridge))
    plugin.enablePlatformViewCreationForNativeTests()
    let id = try plugin.createPlatformViewPlayer(options: options(file.absoluteString))
    let player = try #require(plugin.playersByIdentifier[id])
    var error: FlutterError?
    player.disposeWithError(&error)
    #expect(error == nil)
    #expect(bridge.releases.count == 1)
    #expect(plugin.pendingPlatformClaimCountForNativeTests == 1)
    plugin.retireVideoEngine()
    player.disposeWithError(&error)
    #expect(bridge.releases.count == 1)
    #expect(plugin.pendingPlatformClaimCountForNativeTests == 1)
    #expect(!plugin.installVideoPermitBridge(FakeVideoPermitBridge()))
  }

  @Test func failedExactReleaseRetriesOnlyItsStoredTuple() throws {
    let file = try localURL()
    defer { try? FileManager.default.removeItem(at: file) }
    let plugin = makePlugin(StubFVPAVFactory())
    let bridge = FakeVideoPermitBridge()
    bridge.releaseConfirmed = false
    #expect(plugin.installVideoPermitBridge(bridge))
    plugin.enablePlatformViewCreationForNativeTests()
    let id = try plugin.createPlatformViewPlayer(options: options(file.absoluteString))
    let player = try #require(plugin.playersByIdentifier[id])
    var error: FlutterError?
    player.disposeWithError(&error)
    #expect(error == nil)
    #expect(player.player == nil)
    #expect(bridge.releases.count == 1)
    plugin.retireVideoEngine()
    bridge.releaseConfirmed = true
    #expect(plugin.retryPendingExactReleases() == 1)
    #expect(bridge.releases.count == 2)
    #expect(bridge.releases[0].0 == bridge.releases[1].0)
    #expect(bridge.releases[0].1 == bridge.releases[1].1)
    #expect(plugin.pendingPlatformClaimCountForNativeTests == 0)
  }

  @Test func preAVFailedReleaseCanRetryWithoutCreatingPlayer() throws {
    enum PreAVFailure: Error { case injected }
    let file = try localURL()
    defer { try? FileManager.default.removeItem(at: file) }
    let av = StubFVPAVFactory()
    let plugin = makePlugin(av)
    let bridge = FakeVideoPermitBridge()
    bridge.releaseConfirmed = false
    #expect(plugin.installVideoPermitBridge(bridge))
    plugin.enablePlatformViewCreationForNativeTests()
    plugin.beforeFirstAVEffectForNativeTests = { throw PreAVFailure.injected }
    do {
      _ = try plugin.createPlatformViewPlayer(options: options(file.absoluteString))
      Issue.record("Pre-AV failure returned a player")
    } catch {}
    #expect(av.urlAssetCalls == 0)
    #expect(bridge.releases.count == 1)
    #expect(plugin.pendingPlatformClaimCountForNativeTests == 1)
    bridge.releaseConfirmed = true
    #expect(plugin.retryPendingExactReleases() == 1)
    #expect(bridge.releases.count == 2)
    #expect(bridge.releases[0].0 == bridge.releases[1].0)
    #expect(bridge.releases[0].1 == bridge.releases[1].1)
  }

  @Test func retryDuringReleaseCannotSendDuplicateReceipt() throws {
    let file = try localURL()
    defer { try? FileManager.default.removeItem(at: file) }
    let plugin = makePlugin(StubFVPAVFactory())
    let bridge = FakeVideoPermitBridge()
    #expect(plugin.installVideoPermitBridge(bridge))
    plugin.enablePlatformViewCreationForNativeTests()
    let id = try plugin.createPlatformViewPlayer(options: options(file.absoluteString))
    bridge.onRelease = { #expect(plugin.retryPendingExactReleases() == 0) }
    let player = try #require(plugin.playersByIdentifier[id])
    var error: FlutterError?
    player.disposeWithError(&error)
    #expect(error == nil)
    #expect(bridge.releases.count == 1)
  }

  @Test func oldFailedReleaseCannotConsumeNewEngineClaim() throws {
    let file = try localURL()
    defer { try? FileManager.default.removeItem(at: file) }
    let oldPlugin = makePlugin(StubFVPAVFactory())
    let oldBridge = FakeVideoPermitBridge()
    oldBridge.releaseConfirmed = false
    #expect(oldPlugin.installVideoPermitBridge(oldBridge))
    oldPlugin.enablePlatformViewCreationForNativeTests()
    let oldId = try oldPlugin.createPlatformViewPlayer(options: options(file.absoluteString))
    let oldPlayer = try #require(oldPlugin.playersByIdentifier[oldId])
    var error: FlutterError?
    oldPlayer.disposeWithError(&error)
    #expect(error == nil)
    oldPlugin.retireVideoEngine()
    #expect(oldBridge.releases.count == 1)
    #expect(oldPlugin.pendingPlatformClaimCountForNativeTests == 1)

    let newPlugin = makePlugin(StubFVPAVFactory())
    let newBridge = FakeVideoPermitBridge()
    let newPermit = VideoPermitMessage(
      ownerToken: String(repeating: "c", count: 32), engineGeneration: 2,
      contextGeneration: 0, leaseId: String(repeating: "d", count: 32),
      leaseGeneration: 2)
    #expect(newPlugin.installVideoPermitBridge(newBridge))
    newPlugin.enablePlatformViewCreationForNativeTests()
    let newId = try newPlugin.createPlatformViewPlayer(options: CreationOptions(
      uri: file.absoluteString, httpHeaders: [:], permit: newPermit,
      mixWithOthers: false))
    let newPlayer = try #require(newPlugin.playersByIdentifier[newId])
    newPlayer.disposeWithError(&error)
    #expect(error == nil)
    #expect(newBridge.releases.count == 1)
    #expect(newBridge.releases[0].0.engineGeneration == 2)
    #expect(newBridge.releases[0].0.leaseId == newPermit.leaseId)
    #expect(oldBridge.releases.count == 1)
    #expect(oldPlugin.pendingPlatformClaimCountForNativeTests == 1)
    #expect(newPlugin.pendingPlatformClaimCountForNativeTests == 0)
  }

  @Test func missingViewDetachmentProofCannotSendReleaseReceipt() throws {
    let file = try localURL()
    defer { try? FileManager.default.removeItem(at: file) }
    let plugin = makePlugin(StubFVPAVFactory())
    plugin.nativeViewFactory = nil
    let bridge = FakeVideoPermitBridge()
    #expect(plugin.installVideoPermitBridge(bridge))
    plugin.enablePlatformViewCreationForNativeTests()
    let id = try plugin.createPlatformViewPlayer(options: options(file.absoluteString))
    let player = try #require(plugin.playersByIdentifier[id])
    var error: FlutterError?
    player.disposeWithError(&error)
    #expect(error?.code == "native_video_dispose_incomplete")
    #expect(bridge.releases.isEmpty)
    #expect(plugin.pendingPlatformClaimCountForNativeTests == 1)
  }
}
