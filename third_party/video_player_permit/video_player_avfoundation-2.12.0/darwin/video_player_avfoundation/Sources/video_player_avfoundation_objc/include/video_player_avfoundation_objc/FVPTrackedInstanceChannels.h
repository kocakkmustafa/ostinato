// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@import Foundation;

#if TARGET_OS_OSX
@import FlutterMacOS;
#else
@import Flutter;
#endif

@class FVPVideoPlayer;

NS_ASSUME_NONNULL_BEGIN

/// Records the exact Flutter connection created for each generated player API
/// channel. Cleanup by connection leaves a newer handler on the same name alone.
@interface FVPTrackedInstanceChannels : NSObject <FlutterBinaryMessenger>

@property(nonatomic, readonly) NSUInteger registeredCount;
@property(nonatomic, readonly) NSUInteger detachedCount;
@property(nonatomic, readonly) NSUInteger cleanupAttemptCount;
@property(nonatomic, readonly) BOOL registrationComplete;
@property(nonatomic, readonly) BOOL fullyDetached;

// Fault hooks are used only by the package's native fake tests. Each fires once.
@property(nonatomic) NSUInteger throwBeforeCleanupOnAttemptForNativeTests;
@property(nonatomic) NSUInteger throwAfterCleanupOnAttemptForNativeTests;

- (instancetype)initWithMessenger:(NSObject<FlutterBinaryMessenger> *)messenger;
- (BOOL)registerPlayer:(FVPVideoPlayer *)player suffix:(NSString *)suffix;
- (BOOL)detachRemaining;

@end

NS_ASSUME_NONNULL_END
