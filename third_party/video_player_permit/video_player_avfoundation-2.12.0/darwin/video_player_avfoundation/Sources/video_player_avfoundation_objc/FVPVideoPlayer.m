// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "./include/video_player_avfoundation_objc/FVPVideoPlayer.h"
#import "./include/video_player_avfoundation_objc/FVPVideoPlayer_Internal.h"

#import <CoreMedia/CoreMedia.h>
#import <GLKit/GLKit.h>

#import "./include/video_player_avfoundation_objc/AVAssetTrackUtils.h"

static void *timeRangeContext = &timeRangeContext;
static void *statusContext = &statusContext;
static void *playbackLikelyToKeepUpContext = &playbackLikelyToKeepUpContext;
static void *rateContext = &rateContext;

/// The key name for loading AVURLAsset variants property asynchronously.
/// Note: Apple does not provide a constant for this key.
/// AVURLAsset.variants is documented via Apple's current async-loading API docs:
/// https://developer.apple.com/documentation/avfoundation/avpartialasyncproperty/variants
static NSString *const kFVPAssetVariantsKey = @"variants";

static FlutterError *FVPDisposedCommandError(void) {
  return [FlutterError errorWithCode:@"native_video_disposed"
                           message:@"Video player was disposed"
                           details:nil];
}

// Both asynchronous Pigeon methods use one main-thread reply registry. AVFoundation's
// completion handlers carry only a key, so disposal can answer even if AV never calls back.
typedef void (^FVPAsyncVideoReply)(FVPNativeVideoTrackData *_Nullable,
                                   FlutterError *_Nullable);

@interface FVPVideoReplyBox : NSObject
@property(nonatomic, copy) FVPAsyncVideoReply reply;
@end

@implementation FVPVideoReplyBox
@end

@interface FVPVideoPlayer ()
- (NSNumber *)registerPendingReply:(FVPAsyncVideoReply)reply;
- (void)completePendingReply:(NSNumber *)key
                     tracks:(FVPNativeVideoTrackData *_Nullable)tracks
                      error:(FlutterError *_Nullable)error;
- (BOOL)pendingReplyIsLive:(NSNumber *)key;
- (BOOL)cancelPendingRepliesForDisposal;
- (BOOL)permitRegistrationDetached;
@end

/// Registers KVO observers on 'object' for each entry in 'observations', which must be a
/// dictionary mapping KVO keys to NSValue-wrapped context pointers.
///
/// This does not call any methods on 'observer', so is safe to call from 'observer's init.
static void FVPRegisterKeyValueObservers(NSObject *observer,
                                         NSDictionary<NSString *, NSValue *> *observations,
                                         NSObject *target) {
  // It is important not to use NSKeyValueObservingOptionInitial here, because that will cause
  // synchronous calls to 'observer', violating the requirement that this method does not call its
  // methods. If there are use cases for specific pieces of initial state, those should be handled
  // explicitly by the caller, rather than by adding initial-state KVO notifications here.
  for (NSString *key in observations) {
    [target addObserver:observer
             forKeyPath:key
                options:NSKeyValueObservingOptionNew
                context:observations[key].pointerValue];
  }
}

/// Registers KVO observers on 'object' for each entry in 'observations', which must be a
/// dictionary mapping KVO keys to NSValue-wrapped context pointers.
///
/// This should only be called to balance calls to FVPRegisterKeyValueObservers, as it is an
/// error to try to remove observers that are not currently set.
///
/// This does not call any methods on 'observer', so is safe to call from 'observer's dealloc.
static void FVPRemoveKeyValueObservers(NSObject *observer,
                                       NSDictionary<NSString *, NSValue *> *observations,
                                       NSObject *target) {
  for (NSString *key in observations) {
    [target removeObserver:observer forKeyPath:key];
  }
}

/// Returns a mapping of KVO keys to NSValue-wrapped observer context pointers for observations that
/// should be set for AVPlayer instances.
static NSDictionary<NSString *, NSValue *> *FVPGetPlayerObservations(void) {
  return @{
    @"rate" : [NSValue valueWithPointer:rateContext],
  };
}

/// Returns a mapping of KVO keys to NSValue-wrapped observer context pointers for observations that
/// should be set for AVPlayerItem instances.
static NSDictionary<NSString *, NSValue *> *FVPGetPlayerItemObservations(void) {
  return @{
    @"loadedTimeRanges" : [NSValue valueWithPointer:timeRangeContext],
    @"status" : [NSValue valueWithPointer:statusContext],
    @"playbackLikelyToKeepUp" : [NSValue valueWithPointer:playbackLikelyToKeepUpContext],
  };
}

@implementation FVPVideoPlayer {
  // Whether or not player and player item listeners have ever been registered.
  BOOL _listenersRegistered;
  // KVO must be removed from the item that was originally observed, even if
  // currentItem changed or the permit-backed dispose detaches it first.
  AVPlayerItem *_observedPlayerItem;
  // Only a normal return from every observer/output/channel/event teardown
  // step permits a later native-stop-only retry. A partial exception must
  // never repeat KVO or channel cleanup against uncertain state.
  BOOL _permitTeardownFinished;
  // AV and ObjC cleanup can finish while one exact Flutter channel token is
  // still pending. Keep repeated dispose results incomplete until it clears.
  BOOL _permitRegistrationCleanupPending;
  BOOL _permitStopRetryInProgress;
  BOOL _pendingReplyDeliveryFailed;
  NSMutableDictionary<NSNumber *, FVPVideoReplyBox *> *_pendingReplies;
  NSUInteger _nextPendingReplyId;
}

- (NSNumber *)registerPendingReply:(FVPAsyncVideoReply)reply {
  NSAssert([NSThread isMainThread], @"Video replies must be registered on the main thread");
  if (!_pendingReplies) _pendingReplies = [NSMutableDictionary dictionary];
  NSNumber *key;
  do {
    key = @(++_nextPendingReplyId);
  } while (_pendingReplies[key]);
  FVPVideoReplyBox *box = [FVPVideoReplyBox new];
  box.reply = reply;
  _pendingReplies[key] = box;
  return key;
}

- (void)completePendingReply:(NSNumber *)key
                     tracks:(FVPNativeVideoTrackData *_Nullable)tracks
                      error:(FlutterError *_Nullable)error {
  NSAssert([NSThread isMainThread], @"Video replies must be completed on the main thread");
  FVPVideoReplyBox *box = _pendingReplies[key];
  if (!box) return;
  // Remove before invoking Dart: a reentrant dispose or duplicate AV callback
  // must not see this reply again.
  [_pendingReplies removeObjectForKey:key];
  box.reply(tracks, error);
}

- (BOOL)pendingReplyIsLive:(NSNumber *)key {
  if (!_pendingReplies[key]) return NO;
  if (_disposed) {
    [self completePendingReply:key tracks:nil error:FVPDisposedCommandError()];
    return NO;
  }
  return YES;
}

- (BOOL)cancelPendingRepliesForDisposal {
  NSAssert([NSThread isMainThread], @"Video replies must be cancelled on the main thread");
  BOOL allRepliesDelivered = YES;
  for (NSNumber *key in [_pendingReplies.allKeys copy]) {
    @try {
      [self completePendingReply:key tracks:nil error:FVPDisposedCommandError()];
    } @catch (NSException *replyException) {
      (void)replyException;
      // Removal happened before invocation, so delivery is uncertain and
      // cannot be retried. Continue draining and, crucially, still stop AV.
      allRepliesDelivered = NO;
    }
  }
  return allRepliesDelivered;
}

- (BOOL)permitRegistrationDetached {
  return _onRegistrationDetached != nil && _onRegistrationDetached();
}

- (instancetype)initWithPlayerItem:(NSObject<FVPAVPlayerItem> *)item
                         avFactory:(id<FVPAVFactory>)avFactory
                      viewProvider:(NSObject<FVPViewProvider> *)viewProvider {
  self = [super init];
  NSAssert(self, @"super init cannot be nil");

  _viewProvider = viewProvider;

  NSObject<FVPAVAsset> *asset = item.asset;
  void (^assetCompletionHandler)(void) = ^{
    if (self->_disposed) return;
    if ([asset statusOfValueForKey:@"tracks" error:nil] == AVKeyValueStatusLoaded) {
      void (^processVideoTracks)(NSArray<AVAssetTrack *> *) = ^(NSArray<AVAssetTrack *> *tracks) {
        if (self->_disposed) return;
        if ([tracks count] > 0) {
          AVAssetTrack *videoTrack = tracks[0];
          void (^trackCompletionHandler)(void) = ^{
            if (self->_disposed) return;
            if ([videoTrack statusOfValueForKey:@"preferredTransform"
                                          error:nil] == AVKeyValueStatusLoaded) {
              // Rotate the video by using a videoComposition and the preferredTransform
              self->_preferredTransform = FVPGetStandardizedTrackTransform(
                  videoTrack.preferredTransform, videoTrack.naturalSize);
              // Do not use video composition when it is not needed.
              if (CGAffineTransformIsIdentity(self->_preferredTransform)) {
                return;
              }
              // Note:
              // https://developer.apple.com/documentation/avfoundation/avplayeritem/1388818-videocomposition
              // Video composition can only be used with file-based media and is not supported for
              // use with media served using HTTP Live Streaming.
              AVMutableVideoComposition *videoComposition =
                  [self videoCompositionWithTransform:self->_preferredTransform
                                                asset:asset
                                           videoTrack:videoTrack];
              item.videoComposition = videoComposition;
            }
          };
          [videoTrack loadValuesAsynchronouslyForKeys:@[ @"preferredTransform" ]
                                    completionHandler:trackCompletionHandler];
        }
      };

      // Use the new async API on iOS 15.0+/macOS 12.0+, fall back to deprecated API on older
      // versions
      if (@available(iOS 15.0, macOS 12.0, *)) {
        [asset loadTracksWithMediaType:AVMediaTypeVideo
                     completionHandler:^(NSArray<AVAssetTrack *> *_Nullable tracks,
                                         NSError *_Nullable error) {
                       if (self->_disposed) return;
                       if (error == nil && tracks != nil) {
                         processVideoTracks(tracks);
                       } else if (error != nil) {
                         NSLog(@"Error loading tracks: %@", error);
                       }
                     }];
      } else {
        // For older OS versions, use the deprecated API with warning suppression
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        NSArray *tracks = [asset tracksWithMediaType:AVMediaTypeVideo];
#pragma clang diagnostic pop
        processVideoTracks(tracks);
      }
    }
  };

  _player = [avFactory playerWithPlayerItem:item];
  _player.actionAtItemEnd = AVPlayerActionAtItemEndNone;

#if TARGET_OS_IOS
  // Allow the video to follow an AirPlay route to an external device.
  //
  // allowsExternalPlayback already defaults to YES, but
  // usesExternalPlaybackWhileExternalScreenIsActive defaults to NO, so the
  // player deliberately keeps the picture on the device whenever an external
  // screen is active. The result is that selecting an AirPlay route changes the
  // audio route while the video stays on the phone and the TV only receives a
  // mirrored copy of the screen.
  //
  // Verified on an Apple TV: with both set, the receiver plays the stream
  // itself and the local surface is released.
  _player.allowsExternalPlayback = YES;
  _player.usesExternalPlaybackWhileExternalScreenIsActive = YES;
#endif

  // Configure output. AVVideoColorPropertiesKey must be declared on the output settings (not on
  // pixel buffer attributes, where AVFoundation silently ignores it) so that HDR sources are
  // tone-mapped to BT.709 SDR for the Flutter texture.
  // See https://github.com/flutter/flutter/issues/91241
  NSDictionary *outputSettings = @{
    AVVideoColorPropertiesKey : @{
      AVVideoColorPrimariesKey : AVVideoColorPrimaries_ITU_R_709_2,
      AVVideoTransferFunctionKey : AVVideoTransferFunction_ITU_R_709_2,
      AVVideoYCbCrMatrixKey : AVVideoYCbCrMatrix_ITU_R_709_2,
    },
    (id)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA),
    (id)kCVPixelBufferIOSurfacePropertiesKey : @{},
  };
  _pixelBufferSource = [avFactory videoOutputWithOutputSettings:outputSettings];

  [asset loadValuesAsynchronouslyForKeys:@[ @"tracks" ] completionHandler:assetCompletionHandler];

  return self;
}

- (void)dealloc {
  if (_listenersRegistered && !_disposed) {
    // If dispose was never called for some reason, remove observers to prevent crashes.
    FVPRemoveKeyValueObservers(self, FVPGetPlayerItemObservations(), _observedPlayerItem);
    FVPRemoveKeyValueObservers(self, FVPGetPlayerObservations(), _player);
  }
}

- (void)disposeWithError:(FlutterError *_Nullable *_Nonnull)error {
  if (![NSThread isMainThread]) {
    dispatch_sync(dispatch_get_main_queue(), ^{ [self disposeWithError:error]; });
    return;
  }
  if (error) *error = nil;
  if (_disposed) {
    // A permit-backed first disposal may have returned from its observer,
    // output, channel and view teardown callbacks yet found the item still
    // attached. Retry only its native stop; replaying a teardown callback is
    // unsafe if a prior callback threw partway through. Texture and fully
    // released paths remain idempotent no-ops as before.
    if (_onFullyDisposed && _permitTeardownFinished && _player &&
        !_permitStopRetryInProgress) {
      _permitStopRetryInProgress = YES;
      AVPlayer *retryPlayer = _player;
      BOOL pauseFinished = NO;
      BOOL itemDetached = NO;
      @try {
        [retryPlayer pause];
        pauseFinished = YES;
      } @catch (NSException *pauseException) {
        (void)pauseException;
      }
      @try {
        [retryPlayer replaceCurrentItemWithPlayerItem:nil];
        itemDetached = retryPlayer.currentItem == nil;
      } @catch (NSException *detachException) {
        (void)detachException;
      }
      if (pauseFinished && itemDetached) {
        // The Swift exact-release guard separately requires detached
        // channel/view/map and this wrapper's completed ObjC cleanup.
        _player = nil;
        retryPlayer = nil;
        if (_pendingReplyDeliveryFailed) {
          // Native sound is now stopped, but an earlier Pigeon reply threw.
          // Keep the exact claim quarantined instead of inventing an ACK.
          _permitStopRetryInProgress = NO;
          if (error) {
            *error = [FlutterError errorWithCode:@"native_video_dispose_incomplete"
                                       message:@"Native video reply delivery was uncertain"
                                       details:nil];
          }
          return;
        }
        BOOL registrationDetached = [self permitRegistrationDetached];
        void (^fullyDisposed)(void) = _onFullyDisposed;
        _onFullyDisposed = nil;
        _permitStopRetryInProgress = NO;
        if (fullyDisposed) fullyDisposed();
        if (!registrationDetached) {
          _permitRegistrationCleanupPending = YES;
          if (error) {
            *error = [FlutterError errorWithCode:@"native_video_dispose_incomplete"
                                       message:@"Native video registration cleanup did not finish"
                                       details:nil];
          }
        }
        return;
      }
      _permitStopRetryInProgress = NO;
    }
    if (_permitRegistrationCleanupPending) {
      if (![self permitRegistrationDetached]) {
        if (error) {
          *error = [FlutterError errorWithCode:@"native_video_dispose_incomplete"
                                     message:@"Native video registration cleanup did not finish"
                                     details:nil];
        }
        return;
      }
      _permitRegistrationCleanupPending = NO;
    }
    if (_onFullyDisposed && error) {
      *error = [FlutterError errorWithCode:@"native_video_dispose_incomplete"
                                 message:@"Native video cleanup did not finish"
                                 details:nil];
    }
    return;
  }
  _disposed = YES;
  // The AV seek/asset callback is not guaranteed to arrive after an item is
  // detached. Answer pending Pigeon calls independently of native stop proof.
  BOOL pendingRepliesDelivered = [self cancelPendingRepliesForDisposal];
  _pendingReplyDeliveryFailed = !pendingRepliesDelivered;

  AVPlayer *closingPlayer = _player;
  AVPlayerItem *closingItem = nil;
  AVPlayerItem *observedItem = _observedPlayerItem;
  BOOL permitBacked = _onFullyDisposed != nil;
  BOOL nativeStopFinished = !permitBacked;
  BOOL registrationCleanupAttempted = NO;
  BOOL eventCleanupAttempted = NO;

  @try {
    // A native getter can throw. Keep it inside the same boundary as the
    // physical stop so the catch still gets an independent pause/item-detach
    // attempt and never acknowledges an uncertain teardown.
    closingItem = closingPlayer.currentItem;
    if (permitBacked) {
      // Stop sound and sever the active item before observer, output, channel,
      // or event teardown can fail. Keep the original item/player references
      // for exact KVO removal below; currentItem is now intentionally nil.
      [closingPlayer pause];
      [closingPlayer replaceCurrentItemWithPlayerItem:nil];
      nativeStopFinished = closingPlayer.currentItem == nil;
    }
    if (_listenersRegistered) {
      [[NSNotificationCenter defaultCenter] removeObserver:self];
      FVPRemoveKeyValueObservers(self, FVPGetPlayerItemObservations(), observedItem);
      FVPRemoveKeyValueObservers(self, FVPGetPlayerObservations(), closingPlayer);
      _listenersRegistered = NO;
      _observedPlayerItem = nil;
    }

    AVPlayerItemVideoOutput *output = self.pixelBufferSource.videoOutput;
    if (closingItem && output && [closingItem.outputs containsObject:output]) {
      [closingItem removeOutput:output];
    }
    if (observedItem != closingItem && observedItem && output &&
        [observedItem.outputs containsObject:output]) {
      [observedItem removeOutput:output];
    }
    if (!permitBacked) {
      // Preserve the upstream texture path's observer-before-stop ordering.
      [closingPlayer pause];
      [closingPlayer replaceCurrentItemWithPlayerItem:nil];
    }

    if (_onDisposed) {
      registrationCleanupAttempted = YES;
      _onDisposed();
    }
    if (self.eventListener) {
      eventCleanupAttempted = YES;
      [self.eventListener videoPlayerWasDisposed];
    }
    self.eventListener = nil;
    _onDisposed = nil;
    if (_onFullyDisposed && nativeStopFinished) {
      // Only the permit-backed platform-view path installs this callback.
      // Its layer was detached by onDisposed; release the strong AVPlayer
      // ivar and local references before exact release can be acknowledged.
      _player = nil;
      closingItem = nil;
      observedItem = nil;
      closingPlayer = nil;
    }
  } @catch (NSException *exception) {
    (void)exception;
    _permitTeardownFinished = NO;
    // A partially completed observer or AV teardown cannot be treated as a
    // successful disposal. Keep the exact claim quarantined and observable;
    // blindly repeating KVO removal could itself be unsafe. Attempt pause and
    // item detach independently: a second pause exception must not skip the
    // only remaining opportunity to detach the item.
    @try {
      [closingPlayer pause];
    } @catch (NSException *pauseException) {
      (void)pauseException;
    }
    @try {
      [closingPlayer replaceCurrentItemWithPlayerItem:nil];
    } @catch (NSException *detachException) {
      (void)detachException;
    }
    // If the exception happened before channel/view or event teardown, try
    // each once so a stale handler cannot keep accepting commands. Do not
    // repeat a callback that was already entered and may be partially done.
    if (!registrationCleanupAttempted && _onDisposed) {
      @try {
        _onDisposed();
        _onDisposed = nil;
      } @catch (NSException *registrationException) {
        (void)registrationException;
      }
    }
    if (!eventCleanupAttempted && self.eventListener) {
      @try {
        [self.eventListener videoPlayerWasDisposed];
        self.eventListener = nil;
      } @catch (NSException *eventException) {
        (void)eventException;
      }
    }
    if (error) {
      *error = [FlutterError errorWithCode:@"native_video_dispose_incomplete"
                                 message:@"Native video cleanup did not finish"
                                 details:nil];
    }
    return;
  }
  BOOL registrationDetached = !permitBacked || [self permitRegistrationDetached];
  if (permitBacked && (!nativeStopFinished || !pendingRepliesDelivered || !registrationDetached)) {
    // A returned AV call is insufficient when currentItem remains attached.
    // An exception during Pigeon reply delivery is also uncertain: the
    // physical stop still ran, but the exact claim must stay quarantined.
    if (error) {
      *error = [FlutterError errorWithCode:@"native_video_dispose_incomplete"
                                 message:@"Native video cleanup did not finish"
                                 details:nil];
    }
    // Normal teardown permits a later native-stop-only retry if the item is
    // still attached. Uncertain reply delivery independently bars exact
    // release, even after a later stop succeeds.
    _permitTeardownFinished = YES;
    if (nativeStopFinished && pendingRepliesDelivered && !registrationDetached) {
      // The AV item and ObjC observers are gone, so publish only that narrow
      // fact to Swift. Its exact-release guard still requires all 13 channels
      // and the view/map receipt; keep the Pigeon result incomplete.
      _permitRegistrationCleanupPending = YES;
      void (^fullyDisposed)(void) = _onFullyDisposed;
      _onFullyDisposed = nil;
      if (fullyDisposed) fullyDisposed();
    }
    return;
  }
  void (^fullyDisposed)(void) = _onFullyDisposed;
  _onFullyDisposed = nil;
  if (fullyDisposed) fullyDisposed();
}

- (void)setEventListener:(NSObject<FVPVideoEventListener> *)eventListener {
  // A stale channel must not re-register KVO on a disposed player whose
  // permit-backed AVPlayer has already been released.
  if (_disposed && eventListener) return;
  _eventListener = eventListener;
  // The first time an event listener is set, set up video event listeners to relay status changes
  // changes to the event listener.
  if (eventListener && !_listenersRegistered) {
    AVPlayerItem *item = self.player.currentItem;
    // If the item is already ready to play, ensure that the intialized event is sent first.
    [self reportStatusForPlayerItem:item];
    // Reporting status can synchronously call the client's event sink. It may
    // retire this engine and dispose the player before observer setup resumes.
    if (_disposed || !self.player || self.player.currentItem != item) return;
    // Set up all necessary observers to report video events.
    FVPRegisterKeyValueObservers(self, FVPGetPlayerItemObservations(), item);
    FVPRegisterKeyValueObservers(self, FVPGetPlayerObservations(), _player);
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(itemDidPlayToEndTime:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:item];
    _observedPlayerItem = item;
    _listenersRegistered = YES;
  }
}

- (void)itemDidPlayToEndTime:(NSNotification *)notification {
  if (_disposed) return;
  if (_isLooping) {
    AVPlayerItem *p = [notification object];
    [p seekToTime:kCMTimeZero completionHandler:nil];
  } else {
    [self.eventListener videoPlayerDidComplete];
  }
}

const int64_t TIME_UNSET = -9223372036854775807;

NS_INLINE int64_t FVPCMTimeToMillis(CMTime time) {
  // When CMTIME_IS_INDEFINITE return a value that matches TIME_UNSET from ExoPlayer2 on Android.
  // Fixes https://github.com/flutter/flutter/issues/48670
  if (CMTIME_IS_INDEFINITE(time)) return TIME_UNSET;
  if (time.timescale == 0) return 0;
  return time.value * 1000 / time.timescale;
}

NS_INLINE CGFloat radiansToDegrees(CGFloat radians) {
  // Input range [-pi, pi] or [-180, 180]
  CGFloat degrees = GLKMathRadiansToDegrees((float)radians);
  if (degrees < 0) {
    // Convert -90 to 270 and -180 to 180
    return degrees + 360;
  }
  // Output degrees in between [0, 360]
  return degrees;
};

- (AVMutableVideoComposition *)videoCompositionWithTransform:(CGAffineTransform)transform
                                                       asset:(NSObject<FVPAVAsset> *)asset
                                                  videoTrack:(AVAssetTrack *)videoTrack {
  AVMutableVideoCompositionInstruction *instruction =
      [AVMutableVideoCompositionInstruction videoCompositionInstruction];
  instruction.timeRange = CMTimeRangeMake(kCMTimeZero, asset.duration);
  AVMutableVideoCompositionLayerInstruction *layerInstruction =
      [AVMutableVideoCompositionLayerInstruction
          videoCompositionLayerInstructionWithAssetTrack:videoTrack];
  [layerInstruction setTransform:_preferredTransform atTime:kCMTimeZero];

  AVMutableVideoComposition *videoComposition = [AVMutableVideoComposition videoComposition];
  instruction.layerInstructions = @[ layerInstruction ];
  videoComposition.instructions = @[ instruction ];

  // If in portrait mode, switch the width and height of the video
  CGFloat width = videoTrack.naturalSize.width;
  CGFloat height = videoTrack.naturalSize.height;
  NSInteger rotationDegrees =
      (NSInteger)round(radiansToDegrees(atan2(_preferredTransform.b, _preferredTransform.a)));
  if (rotationDegrees == 90 || rotationDegrees == 270) {
    width = videoTrack.naturalSize.height;
    height = videoTrack.naturalSize.width;
  }
  videoComposition.renderSize = CGSizeMake(width, height);

  videoComposition.sourceTrackIDForFrameTiming = videoTrack.trackID;
  if (CMTIME_IS_VALID(videoTrack.minFrameDuration)) {
    videoComposition.frameDuration = videoTrack.minFrameDuration;
  } else {
    NSLog(@"Warning: videoTrack.minFrameDuration for input video is invalid, please report this to "
          @"https://github.com/flutter/flutter/issues with input video attached.");
    videoComposition.frameDuration = CMTimeMake(1, 30);
  }

  return videoComposition;
}

- (void)observeValueForKeyPath:(NSString *)path
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
  if (_disposed) return;
  if (context == timeRangeContext) {
    NSMutableArray<NSArray<NSNumber *> *> *values = [[NSMutableArray alloc] init];
    for (NSValue *rangeValue in [object loadedTimeRanges]) {
      CMTimeRange range = [rangeValue CMTimeRangeValue];
      [values addObject:@[
        @(FVPCMTimeToMillis(range.start)),
        @(FVPCMTimeToMillis(range.duration)),
      ]];
    }
    [self.eventListener videoPlayerDidUpdateBufferRegions:values];
  } else if (context == statusContext) {
    AVPlayerItem *item = (AVPlayerItem *)object;
    [self reportStatusForPlayerItem:item];
  } else if (context == playbackLikelyToKeepUpContext) {
    [self updatePlayingState];
    if ([[_player currentItem] isPlaybackLikelyToKeepUp]) {
      [self.eventListener videoPlayerDidEndBuffering];
    } else {
      [self.eventListener videoPlayerDidStartBuffering];
    }
  } else if (context == rateContext) {
    // Important: Make sure to cast the object to AVPlayer when observing the rate property,
    // as it is not available in AVPlayerItem.
    AVPlayer *player = (AVPlayer *)object;
    [self.eventListener videoPlayerDidSetPlaying:(player.rate > 0)];
  }
}

- (void)reportStatusForPlayerItem:(AVPlayerItem *)item {
  if (_disposed) return;
  NSAssert(self.eventListener,
           @"reportStatusForPlayerItem was called when the event listener was not set.");
  switch (item.status) {
    case AVPlayerItemStatusFailed:
      [self sendFailedToLoadVideoEvent];
      break;
    case AVPlayerItemStatusUnknown:
      break;
    case AVPlayerItemStatusReadyToPlay:
      if (!_isInitialized) {
        [item addOutput:self.pixelBufferSource.videoOutput];
        [self reportInitialized];
        if (_disposed) return;
        [self updatePlayingState];
      }
      break;
  }
}

- (void)updatePlayingState {
  if (_disposed || !_isInitialized) {
    return;
  }
  if (_isPlaying) {
    // Calling play is the same as setting the rate to 1.0 (or to defaultRate depending on iOS
    // version) so last set playback speed must be set here if any instead.
    // https://github.com/flutter/flutter/issues/71264
    // https://github.com/flutter/flutter/issues/73643
    if (_targetPlaybackSpeed) {
      [self updateRate];
    } else {
      [_player play];
    }
  } else {
    [_player pause];
  }
}

/// Synchronizes the player's playback rate with targetPlaybackSpeed, constrained by the playback
/// rate capabilities of the player's current item.
- (void)updateRate {
  if (_disposed) return;
  // See https://developer.apple.com/library/archive/qa/qa1772/_index.html for an explanation of
  // these checks.
  // If status is not AVPlayerItemStatusReadyToPlay then both canPlayFastForward
  // and canPlaySlowForward are always false and it is unknown whether video can
  // be played at these speeds, updatePlayingState will be called again when
  // status changes to AVPlayerItemStatusReadyToPlay.
  float speed = _targetPlaybackSpeed.floatValue;
  AVPlayer *ratePlayer = _player;
  AVPlayerItem *rateItem = ratePlayer.currentItem;
  if (_disposed || ratePlayer != _player || !rateItem) return;
  BOOL readyToPlay = rateItem.status == AVPlayerItemStatusReadyToPlay;
  if (_disposed || ratePlayer != _player) return;
  if (speed > 2.0) {
    BOOL canPlayFastForward = rateItem.canPlayFastForward;
    if (_disposed || ratePlayer != _player) return;
    if (!canPlayFastForward) {
      if (!readyToPlay) {
        return;
      }
      speed = 2.0;
    }
  }
  if (speed < 1.0) {
    BOOL canPlaySlowForward = rateItem.canPlaySlowForward;
    if (_disposed || ratePlayer != _player) return;
    if (!canPlaySlowForward) {
      if (!readyToPlay) {
        return;
      }
      speed = 1.0;
    }
  }
  // AV getters can synchronously re-enter disposal. Never write a rate to a
  // player whose original item was detached while this command was in flight.
  AVPlayerItem *currentItem = ratePlayer.currentItem;
  if (_disposed || ratePlayer != _player || currentItem != rateItem) return;
  ratePlayer.rate = speed;
}

- (void)sendFailedToLoadVideoEvent {
  // Prefer more detailed error information from tracks loading.
  NSError *error;
  if ([self.player.currentItem.asset statusOfValueForKey:@"tracks"
                                                   error:&error] != AVKeyValueStatusFailed) {
    error = self.player.currentItem.error;
  }
  __block NSMutableOrderedSet<NSString *> *details =
      [NSMutableOrderedSet orderedSetWithObject:@"Failed to load video"];
  void (^add)(NSString *) = ^(NSString *detail) {
    if (detail != nil) {
      [details addObject:detail];
    }
  };
  NSError *underlyingError = error.userInfo[NSUnderlyingErrorKey];
  add(error.localizedDescription);
  add(error.localizedFailureReason);
  add(underlyingError.localizedDescription);
  add(underlyingError.localizedFailureReason);
  NSString *message = [details.array componentsJoinedByString:@": "];
  [self.eventListener videoPlayerDidErrorWithMessage:message];
}

- (void)reportInitialized {
  AVPlayerItem *currentItem = self.player.currentItem;
  NSAssert(currentItem.status == AVPlayerItemStatusReadyToPlay,
           @"reportInitializedIfReadyToPlay was called when the item wasn't ready to play.");
  NSAssert(!_isInitialized, @"reportInitializedIfReadyToPlay should only be called once.");

  _isInitialized = YES;
  [self.eventListener videoPlayerDidInitializeWithDuration:self.duration
                                                      size:currentItem.presentationSize];
}

#pragma mark - FVPVideoPlayerInstanceApi

- (FlutterError *)disposedCommandError {
  return FVPDisposedCommandError();
}

- (void)playWithError:(FlutterError *_Nullable *_Nonnull)error {
  if (_disposed) {
    if (error) *error = [self disposedCommandError];
    return;
  }
  _isPlaying = YES;
  [self updatePlayingState];
}

- (void)pauseWithError:(FlutterError *_Nullable *_Nonnull)error {
  if (_disposed) {
    if (error) *error = [self disposedCommandError];
    return;
  }
  _isPlaying = NO;
  [self updatePlayingState];
}

- (nullable NSNumber *)position:(FlutterError *_Nullable *_Nonnull)error {
  if (_disposed) {
    if (error) *error = [self disposedCommandError];
    return nil;
  }
  return @(FVPCMTimeToMillis([_player currentTime]));
}

- (void)seekTo:(NSInteger)position completion:(void (^)(FlutterError *_Nullable))completion {
  if (![NSThread isMainThread]) {
    dispatch_async(dispatch_get_main_queue(), ^{ [self seekTo:position completion:completion]; });
    return;
  }
  if (_disposed) {
    if (completion) completion([self disposedCommandError]);
    return;
  }
  CMTime targetCMTime = CMTimeMake(position, 1000);
  CMTimeValue duration = _player.currentItem.asset.duration.value;
  // Without adding tolerance when seeking to duration,
  // seekToTime will never complete, and this call will hang.
  // see issue https://github.com/flutter/flutter/issues/124475.
  CMTime tolerance = position == duration ? CMTimeMake(1, 1000) : kCMTimeZero;
  if (!completion) return;
  NSNumber *replyKey = [self registerPendingReply:^(FVPNativeVideoTrackData *tracks,
                                                     FlutterError *error) {
    (void)tracks;
    completion(error);
  }];
  __weak FVPVideoPlayer *weakSelf = self;
  [_player seekToTime:targetCMTime
        toleranceBefore:tolerance
         toleranceAfter:tolerance
      completionHandler:^(BOOL completed) {
        dispatch_async(dispatch_get_main_queue(), ^{
          FVPVideoPlayer *owner = weakSelf;
          if (!owner) return;
          [owner completePendingReply:replyKey
                               tracks:nil
                                error:owner.disposed ? FVPDisposedCommandError() : nil];
        });
      }];
}

- (void)setLooping:(BOOL)looping error:(FlutterError *_Nullable *_Nonnull)error {
  if (_disposed) {
    if (error) *error = [self disposedCommandError];
    return;
  }
  _isLooping = looping;
}

- (void)setVolume:(double)volume error:(FlutterError *_Nullable *_Nonnull)error {
  if (_disposed) {
    if (error) *error = [self disposedCommandError];
    return;
  }
  _player.volume = (float)((volume < 0.0) ? 0.0 : ((volume > 1.0) ? 1.0 : volume));
}

- (void)setPlaybackSpeed:(double)speed error:(FlutterError *_Nullable *_Nonnull)error {
  if (_disposed) {
    if (error) *error = [self disposedCommandError];
    return;
  }
  _targetPlaybackSpeed = @(speed);
  [self updatePlayingState];
}

- (void)getVideoTracks:(void (^)(FVPNativeVideoTrackData *_Nullable,
                                 FlutterError *_Nullable))completion {
  if (![NSThread isMainThread]) {
    dispatch_async(dispatch_get_main_queue(), ^{ [self getVideoTracks:completion]; });
    return;
  }
  if (_disposed) {
    if (completion) completion(nil, [self disposedCommandError]);
    return;
  }
  NSMutableArray<FVPMediaSelectionVideoTrackData *> *mediaSelectionTracks = [NSMutableArray array];

  AVPlayerItem *currentItem = _player.currentItem;
  if (!currentItem) {
    completion(nil, nil);
    return;
  }

  AVURLAsset *urlAsset = (AVURLAsset *)currentItem.asset;
  if (![urlAsset isKindOfClass:[AVURLAsset class]]) {
    completion(nil, nil);
    return;
  }

  // Use AVAssetVariant API for iOS 15+ to get HLS variants
  if (@available(iOS 15.0, macOS 12.0, *)) {
    if (!completion) return;
    NSNumber *replyKey = [self registerPendingReply:^(FVPNativeVideoTrackData *tracks,
                                                       FlutterError *error) {
      completion(tracks, error);
    }];
    __weak FVPVideoPlayer *weakSelf = self;
    __weak AVURLAsset *weakURLAsset = urlAsset;
    __weak AVPlayerItem *weakCurrentItem = currentItem;
    [urlAsset
        loadValuesAsynchronouslyForKeys:@[ kFVPAssetVariantsKey ]
                      completionHandler:^{
                        dispatch_async(dispatch_get_main_queue(), ^{
                          FVPVideoPlayer *owner = weakSelf;
                          if (!owner || ![owner pendingReplyIsLive:replyKey]) return;
                          AVURLAsset *loadedAsset = weakURLAsset;
                          AVPlayerItem *loadedItem = weakCurrentItem;
                          if (!loadedAsset || !loadedItem) {
                            [owner completePendingReply:replyKey
                                                 tracks:nil
                                                  error:[FlutterError
                                                            errorWithCode:@"native_video_asset_unavailable"
                                                            message:@"Video asset was released before track loading finished"
                                                            details:nil]];
                            return;
                          }
                          NSError *error = nil;
                          AVKeyValueStatus status =
                              [loadedAsset statusOfValueForKey:kFVPAssetVariantsKey error:&error];
                          // A test asset may re-enter disposal while status is read.
                          if (![owner pendingReplyIsLive:replyKey]) return;

                          if (status == AVKeyValueStatusLoaded) {
                            NSArray<AVAssetVariant *> *variants = loadedAsset.variants;
                            if (![owner pendingReplyIsLive:replyKey]) return;
                            double currentBitrate = MAX(loadedItem.preferredPeakBitRate, 0);
                            if (![owner pendingReplyIsLive:replyKey]) return;

                            NSInteger variantIndex = 0;
                            for (AVAssetVariant *variant in variants) {
                              if (![owner pendingReplyIsLive:replyKey]) return;
                              double peakBitRate = variant.peakBitRate;
                              if (![owner pendingReplyIsLive:replyKey]) return;
                              CGSize videoSize = CGSizeZero;
                              double frameRate = 0;
                              NSString *codec = nil;

                              // Get video attributes if available
                              AVAssetVariantVideoAttributes *videoAttrs = variant.videoAttributes;
                              if (![owner pendingReplyIsLive:replyKey]) return;
                              if (videoAttrs) {
                                videoSize = videoAttrs.presentationSize;
                                if (![owner pendingReplyIsLive:replyKey]) return;
                                frameRate = videoAttrs.nominalFrameRate;
                                if (![owner pendingReplyIsLive:replyKey]) return;
                                // Get codec from media sub types
                                NSArray *codecTypes = videoAttrs.codecTypes;
                                if (![owner pendingReplyIsLive:replyKey]) return;
                                if (codecTypes.count > 0) {
                                  FourCharCode codecType = [codecTypes[0] unsignedIntValue];
                                  if (![owner pendingReplyIsLive:replyKey]) return;
                                  codec = [owner codecStringFromFourCharCode:codecType];
                                }
                              }

                              // Determine if this variant is currently selected by comparing
                              // bitrates. Since AVPlayer doesn't expose the exact selected variant,
                              // we use a 10% tolerance to account for minor bitrate variations in
                              // adaptive streaming.
                              BOOL isSelected =
                                  (currentBitrate > 0 &&
                                   fabs(peakBitRate - currentBitrate) < peakBitRate * 0.1);

                              // Generate a human-readable resolution label (e.g., "1080p")
                              NSString *resolutionLabel = nil;
                              if (videoSize.height > 0) {
                                resolutionLabel =
                                    [NSString stringWithFormat:@"%.0fp", videoSize.height];
                              }

                              FVPMediaSelectionVideoTrackData *trackData =
                                  [owner createVideoTrackDataWithIndex:variantIndex
                                                                 label:resolutionLabel
                                                           peakBitRate:peakBitRate
                                                             videoSize:videoSize
                                                             frameRate:frameRate
                                                                 codec:codec
                                                            isSelected:isSelected];
                              [mediaSelectionTracks addObject:trackData];
                              variantIndex++;
                            }
                          }

                          FVPNativeVideoTrackData *result =
                              [FVPNativeVideoTrackData makeWithAssetTracks:nil
                                                      mediaSelectionTracks:mediaSelectionTracks];
                          if (![owner pendingReplyIsLive:replyKey]) return;
                          [owner completePendingReply:replyKey tracks:result error:nil];
                        });
                      }];
  } else {
    // For iOS < 15, AVAssetVariant API is not available. Return nil (not an error)
    // since the absence of variant data is expected on older OS versions.
    completion(nil, nil);
  }
}

/// Creates a video track data object with the given parameters, converting values to NSNumber
/// where appropriate and returning nil for invalid/zero values.
- (FVPMediaSelectionVideoTrackData *)createVideoTrackDataWithIndex:(NSInteger)index
                                                             label:(NSString *)label
                                                       peakBitRate:(double)peakBitRate
                                                         videoSize:(CGSize)videoSize
                                                         frameRate:(double)frameRate
                                                             codec:(NSString *)codec
                                                        isSelected:(BOOL)isSelected {
  return [FVPMediaSelectionVideoTrackData
      makeWithVariantIndex:index
                     label:label
                   bitrate:peakBitRate > 0 ? @((NSInteger)peakBitRate) : nil
                     width:videoSize.width > 0 ? @((NSInteger)videoSize.width) : nil
                    height:videoSize.height > 0 ? @((NSInteger)videoSize.height) : nil
                 frameRate:frameRate > 0 ? @(frameRate) : nil
                     codec:codec
                isSelected:isSelected];
}

/// Converts a FourCharCode codec type to a human-readable string for display in the UI.
/// These codec names help users understand the video encoding format of each quality variant.
- (NSString *)codecStringFromFourCharCode:(FourCharCode)code {
  switch (code) {
    case kCMVideoCodecType_H264:
      return @"avc1";
    case kCMVideoCodecType_HEVC:
      return @"hevc";
    case kCMVideoCodecType_VP9:
      return @"vp9";
    default:
      return nil;
  }
}

- (void)selectVideoTrackWithBitrate:(NSInteger)bitrate
                              error:(FlutterError *_Nullable *_Nonnull)error {
  if (_disposed) {
    if (error) *error = [self disposedCommandError];
    return;
  }
  AVPlayerItem *currentItem = _player.currentItem;
  if (!currentItem) {
    return;
  }

  // Set preferredPeakBitRate to select the quality
  // 0 means auto quality (adaptive streaming)
  currentItem.preferredPeakBitRate = (double)bitrate;
}

- (nullable NSArray<FVPMediaSelectionAudioTrackData *> *)getAudioTracks:
    (FlutterError *_Nullable *_Nonnull)error {
  if (_disposed) {
    if (error) *error = [self disposedCommandError];
    return nil;
  }
  AVPlayerItem *currentItem = _player.currentItem;
  NSAssert(currentItem, @"currentItem should not be nil");
  AVAsset *asset = currentItem.asset;

  // Get tracks from media selection (for HLS streams)
  AVMediaSelectionGroup *audioGroup =
      [asset mediaSelectionGroupForMediaCharacteristic:AVMediaCharacteristicAudible];

  NSMutableArray<FVPMediaSelectionAudioTrackData *> *mediaSelectionTracks =
      [[NSMutableArray alloc] init];

  if (audioGroup.options.count > 0) {
    AVMediaSelection *mediaSelection = currentItem.currentMediaSelection;
    AVMediaSelectionOption *currentSelection =
        [mediaSelection selectedMediaOptionInMediaSelectionGroup:audioGroup];

    for (NSInteger i = 0; i < audioGroup.options.count; i++) {
      AVMediaSelectionOption *option = audioGroup.options[i];
      NSString *displayName = option.displayName;

      NSString *languageCode = nil;
      if (option.locale) {
        languageCode = option.locale.languageCode;
      }

      NSArray<AVMetadataItem *> *titleItems =
          [AVMetadataItem metadataItemsFromArray:option.commonMetadata
                                         withKey:AVMetadataCommonKeyTitle
                                        keySpace:AVMetadataKeySpaceCommon];
      NSString *commonMetadataTitle = titleItems.firstObject.stringValue;

      BOOL isSelected = [currentSelection isEqual:option];

      FVPMediaSelectionAudioTrackData *trackData =
          [FVPMediaSelectionAudioTrackData makeWithIndex:i
                                             displayName:displayName
                                            languageCode:languageCode
                                              isSelected:isSelected
                                     commonMetadataTitle:commonMetadataTitle];

      [mediaSelectionTracks addObject:trackData];
    }
  }

  return mediaSelectionTracks;
}

- (void)selectAudioTrackAtIndex:(NSInteger)trackIndex
                          error:(FlutterError *_Nullable __autoreleasing *_Nonnull)error {
  if (_disposed) {
    if (error) *error = [self disposedCommandError];
    return;
  }
  AVPlayerItem *currentItem = _player.currentItem;
  NSAssert(currentItem, @"currentItem should not be nil");
  AVAsset *asset = currentItem.asset;

  AVMediaSelectionGroup *audioGroup =
      [asset mediaSelectionGroupForMediaCharacteristic:AVMediaCharacteristicAudible];

  if (audioGroup && trackIndex >= 0 && trackIndex < (NSInteger)audioGroup.options.count) {
    AVMediaSelectionOption *option = audioGroup.options[trackIndex];
    [currentItem selectMediaOption:option inMediaSelectionGroup:audioGroup];
  }
}

- (void)setPreventsDisplaySleepDuringVideoPlayback:(BOOL)preventsDisplaySleepDuringVideoPlayback
                                             error:(FlutterError *_Nullable *_Nonnull)error {
  if (_disposed) {
    if (error) *error = [self disposedCommandError];
    return;
  }
  self.player.preventsDisplaySleepDuringVideoPlayback = preventsDisplaySleepDuringVideoPlayback;
}

#pragma mark - Private

- (int64_t)duration {
  // Note: https://openradar.appspot.com/radar?id=4968600712511488
  // `[AVPlayerItem duration]` can be `kCMTimeIndefinite`,
  // use `[[AVPlayerItem asset] duration]` instead.
  return FVPCMTimeToMillis([[[_player currentItem] asset] duration]);
}

@end
