// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "include/video_player_avfoundation_objc/FVPTrackedInstanceChannels.h"

#import "include/video_player_avfoundation_objc/FVPVideoPlayer.h"
#import "include/video_player_avfoundation_objc/VideoPlayerInstanceMessages.g.h"

static const NSUInteger kFVPInstanceChannelCount = 13;
static NSString *const kFVPInstanceChannelPrefix =
    @"dev.flutter.pigeon.video_player_avfoundation.VideoPlayerInstanceApi.";

@implementation FVPTrackedInstanceChannels {
  NSObject<FlutterBinaryMessenger> *_messenger;
  NSMutableDictionary<NSString *, NSNumber *> *_pendingConnections;
  NSMutableSet<NSString *> *_registeredNames;
  NSString *_expectedSuffix;
  BOOL _registrationFinished;
  BOOL _registrationUncertain;
  NSUInteger _detachedCount;
  NSUInteger _cleanupAttemptCount;
  BOOL _detachInProgress;
}

- (instancetype)initWithMessenger:(NSObject<FlutterBinaryMessenger> *)messenger {
  self = [super init];
  if (self) {
    _messenger = messenger;
    _pendingConnections = [NSMutableDictionary dictionary];
    _registeredNames = [NSMutableSet set];
  }
  return self;
}

- (NSUInteger)registeredCount {
  return _registeredNames.count;
}

- (NSUInteger)detachedCount {
  return _detachedCount;
}

- (NSUInteger)cleanupAttemptCount {
  return _cleanupAttemptCount;
}

- (BOOL)registrationComplete {
  return _registrationFinished && !_registrationUncertain &&
         _registeredNames.count == kFVPInstanceChannelCount;
}

- (BOOL)fullyDetached {
  return self.registrationComplete && _pendingConnections.count == 0 &&
         _detachedCount == kFVPInstanceChannelCount;
}

- (BOOL)registerPlayer:(FVPVideoPlayer *)player suffix:(NSString *)suffix {
  if (![NSThread isMainThread] || _registrationFinished || _expectedSuffix || !player ||
      suffix.length == 0) {
    return NO;
  }
  _expectedSuffix = [@"." stringByAppendingString:suffix];
  @try {
    SetUpFVPVideoPlayerInstanceApiWithSuffix(self, player, suffix);
  } @catch (NSException *exception) {
    (void)exception;
    // A handler might have been installed before its connection was returned.
    // The unknown registration must never earn an exact release receipt.
    _registrationUncertain = YES;
  }
  _registrationFinished = YES;
  return self.registrationComplete;
}

- (BOOL)detachRemaining {
  if (![NSThread isMainThread] || _detachInProgress) return NO;
  // A failure on channel N cannot stop teardown of the other twelve. A failed
  // token remains for a later exact-token retry, never a suffix-wide nil set.
  // Flutter's messenger can synchronously reenter the plugin while a token is
  // being removed. Do not count or clean that same token twice before this
  // pass records its outcome.
  _detachInProgress = YES;
  @try {
    for (NSString *name in [_pendingConnections.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
      NSNumber *token = _pendingConnections[name];
      if (!token) continue;
      ++_cleanupAttemptCount;
      @try {
        if (_cleanupAttemptCount == _throwBeforeCleanupOnAttemptForNativeTests) {
          _throwBeforeCleanupOnAttemptForNativeTests = 0;
          [NSException raise:@"FVPTestCleanupBefore" format:@"Injected cleanup failure"];
        }
        [_messenger cleanUpConnection:token.longLongValue];
        if (_cleanupAttemptCount == _throwAfterCleanupOnAttemptForNativeTests) {
          _throwAfterCleanupOnAttemptForNativeTests = 0;
          [NSException raise:@"FVPTestCleanupAfter" format:@"Injected cleanup failure"];
        }
        [_pendingConnections removeObjectForKey:name];
        ++_detachedCount;
      } @catch (NSException *exception) {
        (void)exception;
        // The token may already be gone; Flutter's token cleanup is safe to
        // retry and cannot remove a replacement handler on the same channel.
      }
    }
  } @finally {
    _detachInProgress = NO;
  }
  return self.fullyDetached;
}

#pragma mark - FlutterBinaryMessenger

- (void)sendOnChannel:(NSString *)channel message:(NSData *_Nullable)message {
  [_messenger sendOnChannel:channel message:message];
}

- (void)sendOnChannel:(NSString *)channel
              message:(NSData *_Nullable)message
          binaryReply:(FlutterBinaryReply _Nullable)callback {
  [_messenger sendOnChannel:channel message:message binaryReply:callback];
}

- (FlutterBinaryMessengerConnection)setMessageHandlerOnChannel:(NSString *)channel
                                          binaryMessageHandler:(FlutterBinaryMessageHandler _Nullable)handler {
  FlutterBinaryMessengerConnection token =
      [_messenger setMessageHandlerOnChannel:channel binaryMessageHandler:handler];
  if (!handler || ![channel hasPrefix:kFVPInstanceChannelPrefix] ||
      ![channel hasSuffix:_expectedSuffix] || [_registeredNames containsObject:channel] ||
      token <= 0) {
    _registrationUncertain = YES;
  } else {
    [_registeredNames addObject:channel];
    _pendingConnections[channel] = @(token);
  }
  return token;
}

- (void)cleanUpConnection:(FlutterBinaryMessengerConnection)connection {
  [_messenger cleanUpConnection:connection];
}

@end
