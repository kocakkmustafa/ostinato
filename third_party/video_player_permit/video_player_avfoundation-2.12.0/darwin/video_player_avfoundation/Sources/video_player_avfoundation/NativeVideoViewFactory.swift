// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Foundation

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

/// A factory class responsible for creating native video views that can be embedded in a
/// Flutter app.
final class NativeVideoViewFactory: NSObject, FlutterPlatformViewFactory {
  private final class WeakView {
    weak var value: FVPNativeVideoView?
    init(_ value: FVPNativeVideoView) { self.value = value }
  }

  private let messenger: FlutterBinaryMessenger
  private let playerByIdentifierProvider: (Int64) -> FVPVideoPlayer?
  private var viewsByPlayerIdentifier: [Int64: [WeakView]] = [:]

  /// Initializes a new instance of NativeVideoViewFactory with the given messenger and
  /// a block that provides video players associated with their identifiers.
  init(
    messenger: FlutterBinaryMessenger,
    playerByIdentifierProvider: @escaping (Int64) -> FVPVideoPlayer?
  ) {
    self.messenger = messenger
    self.playerByIdentifierProvider = playerByIdentifierProvider
    super.init()
  }

  #if os(macOS)
    func create(
      withViewIdentifier viewIdentifier: Int64,
      arguments: Any?
    ) -> NSView {
      return createNativeVideoView(arguments: arguments as? PlatformVideoViewCreationParams)
    }
  #elseif os(iOS)
    func create(
      withFrame frame: CGRect,
      viewIdentifier: Int64,
      arguments: Any?
    ) -> FlutterPlatformView {
      return createNativeVideoView(arguments: arguments as? PlatformVideoViewCreationParams)
    }
  #endif

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    return VideoPlayerPluginMessagesPigeonCodec.shared
  }

  /// Creates a native video view for the given arguments.
  private func createNativeVideoView(
    arguments args: PlatformVideoViewCreationParams?
  ) -> FVPNativeVideoView {
    guard let args, let player = playerByIdentifierProvider(args.playerId), !player.disposed else {
      // FlutterPlatformViewFactory has no error return. An unknown/stale ID
      // gets a blank view, never a forced unwrap or another player's layer.
      return FVPNativeVideoView(player: nil)
    }
    let view = FVPNativeVideoView(player: player.player)
    viewsByPlayerIdentifier[args.playerId, default: []].append(WeakView(view))
    return view
  }

  /// Called from the player's synchronous dispose path on the main thread.
  /// A live Flutter view may outlive its Dart controller, so its AVPlayerLayer
  /// must no longer retain the disposed player before exact release is sent.
  func detachPlayerViews(for playerId: Int64) -> Bool {
    guard Thread.isMainThread else { return false }
    let views = viewsByPlayerIdentifier[playerId] ?? []
    var allDetached = true
    for reference in views {
      if let view = reference.value, !view.detachPlayer() {
        allDetached = false
      }
    }
    if allDetached { viewsByPlayerIdentifier.removeValue(forKey: playerId) }
    return allDetached
  }
}
