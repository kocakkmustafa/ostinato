// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@import AVFoundation;

#import "./VideoPlayerInstanceMessages.g.h"
#import "FVPAVFactory.h"
#import "FVPVideoEventListener.h"
#import "FVPViewProvider.h"

#if TARGET_OS_OSX
@import FlutterMacOS;
#else
@import Flutter;
#endif

NS_ASSUME_NONNULL_BEGIN

/// FVPVideoPlayer manages video playback using AVPlayer.
/// It provides methods for controlling playback, adjusting volume, and handling seeking.
/// This class contains all functionalities needed to manage video playback in platform views and is
/// typically used alongside NativeVideoViewFactory. If you need to display a video using a
/// texture, use FVPTextureBasedVideoPlayer instead.
@interface FVPVideoPlayer : NSObject <FVPVideoPlayerInstanceApi>
/// The AVPlayer instance used for video playback. A disposed platform-view
/// player clears its last owned reference before its exact-release callback.
@property(nonatomic, readonly, nullable) AVPlayer *player;
/// Indicates whether the video player has been disposed.
@property(nonatomic, readonly) BOOL disposed;
/// Indicates whether the video player is set to loop.
@property(nonatomic) BOOL isLooping;
/// The current playback position of the video, in milliseconds.
@property(nonatomic, readonly) int64_t position;
/// The event listener to report video events to.
@property(nonatomic, nullable) NSObject<FVPVideoEventListener> *eventListener;
/// A block that will be called when dispose is called.
@property(nonatomic, nullable, copy) void (^onDisposed)(void);
/// Reads the permit claim's exact channel/view/map cleanup after onDisposed.
/// A false result must surface as incomplete disposal even if AV is stopped.
@property(nonatomic, nullable, copy) BOOL (^onRegistrationDetached)(void);
/// Called once after the base player has removed observers, detached its
/// current item, closed its event listener, and released its AVPlayer ivar.
/// Platform-view claims still need separate channel/layer-detachment proof.
@property(nonatomic, nullable, copy) void (^onFullyDisposed)(void);

/// Initializes a new instance of FVPVideoPlayer with the given AVPlayerItem, AV factory, and view
/// provider.
- (instancetype)initWithPlayerItem:(NSObject<FVPAVPlayerItem> *)item
                         avFactory:(id<FVPAVFactory>)avFactory
                      viewProvider:(NSObject<FVPViewProvider> *)viewProvider;

@end

NS_ASSUME_NONNULL_END
