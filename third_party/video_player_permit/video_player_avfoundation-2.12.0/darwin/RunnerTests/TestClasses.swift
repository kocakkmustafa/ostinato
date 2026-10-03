// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import AVFoundation
import Testing
#if canImport(video_player_avfoundation_objc)
import video_player_avfoundation_objc
#endif

@testable import video_player_avfoundation

#if os(iOS)
  import Flutter
  import UIKit
#else
  import FlutterMacOS
#endif

/// An AVPlayer subclass that records method call parameters for inspection.
// TODO(stuartmorgan): Replace with a protocol like the other classes.
@MainActor final class InspectableAVPlayer: AVPlayer {
  private(set) nonisolated(unsafe) var beforeTolerance: NSNumber?
  private(set) nonisolated(unsafe) var afterTolerance: NSNumber?
  private(set) nonisolated(unsafe) var lastSeekTime: CMTime = .invalid

  override func seek(
    to time: CMTime,
    toleranceBefore: CMTime,
    toleranceAfter: CMTime,
    completionHandler: @escaping @Sendable (Bool) -> Void
  ) {
    beforeTolerance = NSNumber(value: toleranceBefore.value)
    afterTolerance = NSNumber(value: toleranceAfter.value)
    lastSeekTime = time
    super.seek(
      to: time, toleranceBefore: toleranceBefore, toleranceAfter: toleranceAfter,
      completionHandler: completionHandler)
  }
}

final class TestAsset: NSObject, FVPAVAsset {
  let duration: CMTime
  let tracks: [AVAssetTrack]?

  var loadedTracksAsynchronously = false

  init(duration: CMTime = CMTime.zero, tracks: [AVAssetTrack]? = nil) {
    self.duration = duration
    self.tracks = tracks
    super.init()
  }

  func statusOfValue(forKey key: String, error outError: NSErrorPointer) -> AVKeyValueStatus {
    return tracks == nil ? .loading : .loaded
  }

  func loadValuesAsynchronously(forKeys keys: [String], completionHandler handler: (() -> Void)?) {
    handler?()
  }

  @available(macOS 12.0, iOS 15.0, *)
  func loadTracks(
    withMediaType mediaType: AVMediaType,
    completionHandler: @escaping ([AVAssetTrack]?, Error?) -> Void
  ) {
    loadedTracksAsynchronously = true
    completionHandler(tracks, nil)
  }

  func tracks(withMediaType mediaType: AVMediaType) -> [AVAssetTrack] {
    return tracks ?? []
  }
}

final class StubPlayerItem: NSObject, FVPAVPlayerItem {
  let asset: FVPAVAsset
  var videoComposition: AVVideoComposition?

  init(asset: FVPAVAsset = TestAsset()) {
    self.asset = asset
    super.init()
  }
}

final class StubBinaryMessenger: NSObject, FlutterBinaryMessenger {
  private(set) var activeChannels = Set<String>()
  private var handlerByChannel: [String: FlutterBinaryMessageHandler] = [:]
  private var channelByConnection: [FlutterBinaryMessengerConnection: String] = [:]
  private var currentConnectionByChannel: [String: FlutterBinaryMessengerConnection] = [:]
  private var nextConnection: FlutterBinaryMessengerConnection = 1
  var onSetMessageHandler: ((String) -> Void)?
  var onCleanUpConnection: ((FlutterBinaryMessengerConnection) -> Void)?
  func send(onChannel channel: String, message: Data?) {}
  func send(
    onChannel channel: String,
    message: Data?,
    binaryReply callback: FlutterBinaryReply? = nil
  ) {}
  func setMessageHandlerOnChannel(
    _ channel: String,
    binaryMessageHandler handler: FlutterBinaryMessageHandler? = nil
  ) -> FlutterBinaryMessengerConnection {
    guard handler != nil else {
      activeChannels.remove(channel)
      handlerByChannel.removeValue(forKey: channel)
      currentConnectionByChannel.removeValue(forKey: channel)
      channelByConnection = channelByConnection.filter { $0.value != channel }
      return 0
    }
    let connection = nextConnection
    nextConnection += 1
    channelByConnection[connection] = channel
    currentConnectionByChannel[channel] = connection
    activeChannels.insert(channel)
    handlerByChannel[channel] = handler
    onSetMessageHandler?(channel)
    return connection
  }
  func cleanUpConnection(_ connection: FlutterBinaryMessengerConnection) {
    onCleanUpConnection?(connection)
    guard let channel = channelByConnection.removeValue(forKey: connection) else { return }
    if currentConnectionByChannel[channel] == connection {
      currentConnectionByChannel.removeValue(forKey: channel)
      activeChannels.remove(channel)
      handlerByChannel.removeValue(forKey: channel)
    }
  }

  func invokeInstanceChannel(_ channel: String, arguments: [Any] = []) -> [Any]? {
    guard let handler = handlerByChannel[channel] else { return nil }
    let codec = FVPGetVideoPlayerInstanceMessagesCodec()
    var response: [Any]?
    handler(codec.encode(arguments)) { data in
      response = codec.decode(data) as? [Any]
    }
    return response
  }
}

final class TestTextureRegistry: NSObject, FlutterTextureRegistry {
  private(set) var registeredTexture = false
  private(set) var unregisteredTexture = false
  private(set) var textureFrameAvailableCount = 0

  func register(_ texture: FlutterTexture) -> Int64 {
    registeredTexture = true
    return 1
  }

  func unregisterTexture(_ textureId: Int64) {
    if textureId != 1 {
      Issue.record("Unregistering texture with wrong ID")
    }
    unregisteredTexture = true
  }

  func textureFrameAvailable(_ textureId: Int64) {
    if textureId != 1 {
      Issue.record("Texture frame available with wrong ID")
    }
    textureFrameAvailableCount += 1
  }
}

final class StubViewProvider: NSObject, FVPViewProvider {
  #if os(iOS)
    var viewController: UIViewController?
    init(viewController: UIViewController? = nil) {
      self.viewController = viewController
      super.init()
    }
  #else
    var view: NSView?
    init(view: NSView? = nil) {
      self.view = view
      super.init()
    }
  #endif
}

final class StubAssetProvider: NSObject, FVPAssetProvider {
  func lookupKey(forAsset asset: String) -> String? {
    return asset
  }

  func lookupKey(forAsset asset: String, fromPackage package: String) -> String? {
    return asset
  }
}

final class TestPixelBufferSource: NSObject, FVPPixelBufferSource {
  var pixelBuffer: CVPixelBuffer?
  let videoOutput: AVPlayerItemVideoOutput

  override init() {
    videoOutput = AVPlayerItemVideoOutput(pixelBufferAttributes: [
      kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
      kCVPixelBufferIOSurfacePropertiesKey as String: [:] as [String: String],
    ])
    super.init()
  }

  func itemTime(forHostTime hostTimeInSeconds: CFTimeInterval) -> CMTime {
    return CMTimeMakeWithSeconds(hostTimeInSeconds, preferredTimescale: 1000)
  }

  func hasNewPixelBuffer(forItemTime itemTime: CMTime) -> Bool {
    return pixelBuffer != nil
  }

  func copyPixelBuffer(
    forItemTime itemTime: CMTime,
    itemTimeForDisplay: UnsafeMutablePointer<CMTime>?
  ) -> CVPixelBuffer? {
    let buffer = pixelBuffer
    // Ownership is transferred to the caller.
    pixelBuffer = nil
    return buffer
  }
}

#if os(iOS)
  final class TestAudioSession: NSObject, FVPAVAudioSession {
    var category: AVAudioSession.Category = .ambient
    var categoryOptions: AVAudioSession.CategoryOptions = []
    private(set) var setCategoryCalled = false

    func setCategory(
      _ category: AVAudioSession.Category,
      with options: AVAudioSession.CategoryOptions
    ) throws {
      setCategoryCalled = true
      self.category = category
      self.categoryOptions = options
    }
  }
#endif

final class StubFVPAVFactory: NSObject, FVPAVFactory {
  let player: AVPlayer
  let playerItem: FVPAVPlayerItem
  let pixelBufferSource: FVPPixelBufferSource?
  private(set) var lastOutputSettings: [String: Any]?
  private(set) var urlAssetCalls = 0
  private(set) var playerItemCalls = 0
  private(set) var playerCalls = 0
  var onURLAsset: (() -> Void)?
  var onPlayerItem: (() -> Void)?
  #if os(iOS)
    var audioSession: FVPAVAudioSession
  #endif

  init(
    player: AVPlayer? = nil,
    playerItem: FVPAVPlayerItem? = nil,
    pixelBufferSource: FVPPixelBufferSource? = nil
  ) {
    let dummyURL = URL(string: "https://flutter.dev")!
    self.player =
      player
      ?? AVPlayer(playerItem: AVPlayerItem(url: dummyURL))
    self.playerItem = playerItem ?? StubPlayerItem()
    self.pixelBufferSource = pixelBufferSource
    #if os(iOS)
      self.audioSession = TestAudioSession()
    #endif
    super.init()
  }

  func urlAsset(with url: URL, options: [String: Any]?) -> FVPAVAsset {
    urlAssetCalls += 1
    onURLAsset?()
    return playerItem.asset
  }

  func playerItem(with asset: FVPAVAsset) -> FVPAVPlayerItem {
    playerItemCalls += 1
    onPlayerItem?()
    return playerItem
  }

  func player(with playerItem: FVPAVPlayerItem) -> AVPlayer {
    playerCalls += 1
    return self.player
  }

  func videoOutput(outputSettings: [String: Any]) -> FVPPixelBufferSource {
    lastOutputSettings = outputSettings
    return pixelBufferSource ?? TestPixelBufferSource()
  }

  #if os(iOS)
    func sharedAudioSession() -> FVPAVAudioSession {
      return audioSession
    }
  #endif
}

final class StubFVPDisplayLink: NSObject, FVPDisplayLink {
  var running: Bool = false
  var duration: CFTimeInterval {
    return 1.0 / 60.0
  }
}

final class StubFVPDisplayLinkFactory: DisplayLinkFactory {
  let displayLink = StubFVPDisplayLink()
  var fireDisplayLink: (() -> Void)?

  func displayLink(
    with viewProvider: FVPViewProvider,
    callback: @escaping () -> Void
  ) -> FVPDisplayLink {
    fireDisplayLink = callback
    return displayLink
  }
}

final class StubEventListener: NSObject, FVPVideoEventListener {
  var onInitialized: (() -> Void)?
  private(set) var initializationDuration: Int64 = 0
  private(set) var initializationSize: CGSize = .zero
  private(set) var playingStateEventCount = 0

  init(onInitialized: (() -> Void)? = nil) {
    self.onInitialized = onInitialized
    super.init()
  }

  func videoPlayerDidComplete() {}
  func videoPlayerDidEndBuffering() {}
  func videoPlayerDidError(withMessage errorMessage: String) {}
  func videoPlayerDidInitialize(withDuration duration: Int64, size: CGSize) {
    onInitialized?()
    initializationDuration = duration
    initializationSize = size
  }
  func videoPlayerDidSetPlaying(_ playing: Bool) { playingStateEventCount += 1 }
  func videoPlayerDidStartBuffering() {}
  func videoPlayerDidUpdateBufferRegions(_ regions: [[NSNumber]]!) {}
  func videoPlayerWasDisposed() {}
}

final class StubTexture: NSObject, FlutterTexture {
  func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
    return nil
  }
}
