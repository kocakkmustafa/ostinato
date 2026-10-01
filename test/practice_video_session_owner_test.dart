import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motion_account/motion_account.dart';
import 'package:ostinato/app/audio/practice_audio_lease.dart';
import 'package:ostinato/app/audio/practice_audio_root.dart';
import 'package:ostinato/app/audio/practice_video_session_owner.dart';

import 'support/fake_practice_audio_port.dart';

final class _Player implements PracticeVideoPlayerPort {
  _Player({this.onInitialize, this.onDispose});

  final Future<void> Function(NativeAudioPermit)? onInitialize;
  final Future<void> Function()? onDispose;
  int initializes = 0;
  int disposals = 0;

  @override
  Future<void> initialize(NativeAudioPermit permit) async {
    ++initializes;
    await onInitialize?.call(permit);
  }

  @override
  Future<void> dispose() async {
    ++disposals;
    await onDispose?.call();
  }
}

final class _Harness {
  _Harness({
    required this.allowVideo,
    Duration videoTimeout = const Duration(milliseconds: 1500),
  }) : user = ValueNotifier<String?>('A'),
       identity = ValueNotifier(MotionIdentityPhase.verified),
       port = FakePracticeAudioPort() {
    video = PracticeVideoSessionOwner(
      port: port,
      operationTimeout: videoTimeout,
    );
    root = PracticeAudioRootOwner(
      userId: user,
      phase: identity,
      lease: PracticeAudioLease(port: port),
      videoOwner: video,
      initialLifecycleState: AppLifecycleState.resumed,
      allowDetachedRouteEventsForTest: true,
      allowVideoAcquisitionForTest: allowVideo,
    );
    observer = PracticeAudioRouteObserver(root);
    route = MaterialPageRoute<void>(
      settings: const RouteSettings(name: 'lesson'),
      builder: (_) => const SizedBox(),
    );
    root.attachNavigator(observer);
    observer.didPush(route, null);
  }

  final bool allowVideo;
  final ValueNotifier<String?> user;
  final ValueNotifier<MotionIdentityPhase> identity;
  final FakePracticeAudioPort port;
  late final PracticeVideoSessionOwner video;
  late final PracticeAudioRootOwner root;
  late final PracticeAudioRouteObserver observer;
  late final Route<dynamic> route;

  Future<void> ready() async => root.lastFenceForTest;

  Future<void> dispose() async {
    root.dispose();
    await root.lastFenceForTest;
    user.dispose();
    identity.dispose();
  }
}

void main() {
  test('production root does not issue a video action', () async {
    final h = _Harness(allowVideo: false);
    await h.ready();
    expect(h.root.videoActionFor(h.route), isNull);
    expect(h.port.opens, isEmpty);
    await h.dispose();
  });

  test(
    'native video permit precedes player initialize and close receipt',
    () async {
      final h = _Harness(allowVideo: true);
      await h.ready();
      final player = _Player(
        onInitialize: (permit) async {
          expect(h.port.opens, [PracticeAudioSide.video]);
          expect(permit.side, PracticeAudioSide.video);
          expect(permit.ownerToken, FakePracticeAudioPort.ownerToken);
          expect(permit.engineGeneration, h.port.engineGeneration);
          expect(
            permit.contextGeneration,
            (await h.port.readAllAudioState()).contextGeneration,
          );
          expect(permit.leaseId, matches(RegExp(r'^[0-9a-f]{32}$')));
          expect(permit.leaseGeneration, greaterThan(0));
          expect(
            (await h.port.readAllAudioState()).activeSide,
            PracticeAudioSide.video,
          );
        },
      );
      final action = h.root.videoActionFor(h.route)!;
      expect(await action.start(player), PracticeVideoOpenStatus.ready);
      expect(
        await action.start(_Player()),
        PracticeVideoOpenStatus.staleContext,
      );
      expect(h.root.videoActionFor(h.route), isNull);
      expect(player.initializes, 1);
      expect(await h.video.close(), isTrue);
      expect(player.disposals, 1);
      expect(h.port.videoCancelCalls, 0);
      expect(h.port.videoDisposeCalls, 1);
      expect((await h.port.readAllAudioState()).allClear, isTrue);
      await h.dispose();
    },
  );

  test(
    'account fence waits pending video dispose then fresh all-clear',
    () async {
      final h = _Harness(allowVideo: true);
      await h.ready();
      final dispose = Completer<void>();
      final player = _Player(onDispose: () => dispose.future);
      expect(
        await h.root.videoActionFor(h.route)!.start(player),
        PracticeVideoOpenStatus.ready,
      );
      final oldFenceCount = h.port.fences.length;
      h.user.value = 'B';
      expect(h.root.videoActionFor(h.route), isNull);
      expect(player.disposals, 0); // context invalidation precedes async close
      await Future<void>.delayed(Duration.zero);
      expect(h.port.fences.length, oldFenceCount + 1);
      expect((await h.port.readAllAudioState()).videoPhase, 'closing');
      expect(player.disposals, 1);
      dispose.complete();
      expect(
        await h.root.lastFenceForTest,
        PracticeAudioReleaseStatus.confirmedClosed,
      );
      expect(h.root.blocked, isFalse);
      expect(h.port.videoDisposeCalls, 1);
      expect((await h.port.readAllAudioState()).allClear, isTrue);
      await h.dispose();
    },
  );

  test(
    'route change during reserve never initializes the stale player',
    () async {
      final h = _Harness(allowVideo: true);
      await h.ready();
      final reserve = Completer<void>();
      h.port.start = (side) => reserve.future;
      final player = _Player();
      final started = h.root.videoActionFor(h.route)!.start(player);
      await Future<void>.delayed(Duration.zero);
      expect(h.port.opens, [PracticeAudioSide.video]);
      final next = MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'next'),
        builder: (_) => const SizedBox(),
      );
      h.observer.didPush(next, h.route);
      reserve.complete();
      expect(await started, PracticeVideoOpenStatus.staleContext);
      expect(player.initializes, 0);
      expect(player.disposals, 0);
      expect(h.port.videoCancelCalls, 1);
      expect(h.port.videoDisposeCalls, 0);
      expect(
        await h.root.lastFenceForTest,
        PracticeAudioReleaseStatus.confirmedClosed,
      );
      expect(h.root.blocked, isFalse);
      await h.dispose();
    },
  );

  test('early Dart dispose acknowledgement waits for native release', () async {
    final h = _Harness(allowVideo: true);
    await h.ready();
    h.port.waitForNativeVideoRelease = true;
    final acknowledged = Completer<void>();
    h.port.onVideoDisposeAcknowledged = acknowledged.complete;
    expect(
      await h.root.videoActionFor(h.route)!.start(_Player()),
      PracticeVideoOpenStatus.ready,
    );
    final closing = h.video.close();
    await acknowledged.future;
    expect((await h.port.readAllAudioState()).videoPhase, 'closing');
    h.port.releaseNativeVideoForTest();
    expect(await closing, isTrue);
    expect(h.video.blocked, isFalse);
    await h.dispose();
  });

  test('late exact native release needs explicit root recovery', () async {
    final h = _Harness(
      allowVideo: true,
      videoTimeout: const Duration(milliseconds: 30),
    );
    await h.ready();
    h.port.waitForNativeVideoRelease = true;
    expect(
      await h.root.videoActionFor(h.route)!.start(_Player()),
      PracticeVideoOpenStatus.ready,
    );
    expect(await h.video.close(), isFalse);
    expect(h.video.blocked, isTrue);
    expect(
      await h.root.recover(),
      PracticeAudioReleaseStatus.blockedUnconfirmed,
    );
    h.port.releaseNativeVideoForTest();
    expect(await h.root.recover(), PracticeAudioReleaseStatus.confirmedClosed);
    expect(h.video.blocked, isFalse);
    await h.dispose();
  });

  test('orphaned released video can be explicitly recovered', () async {
    final h = _Harness(allowVideo: true);
    await h.ready();
    h.port.waitForNativeVideoRelease = true;
    await h.port.reserve(PracticeAudioSide.video, 'd' * 32);
    h.port.releaseNativeVideoForTest();
    expect((await h.port.readAllAudioState()).allClear, isFalse);
    expect(await h.root.recover(), PracticeAudioReleaseStatus.confirmedClosed);
    expect((await h.port.readAllAudioState()).allClear, isTrue);
    await h.dispose();
  });

  test('lost reserve reply cancels the exact unclaimed native lease', () async {
    final h = _Harness(
      allowVideo: true,
      videoTimeout: const Duration(milliseconds: 30),
    );
    await h.ready();
    final delayedReply = Completer<void>();
    h.port.start = (_) => delayedReply.future;
    final player = _Player();
    expect(
      await h.root.videoActionFor(h.route)!.start(player),
      PracticeVideoOpenStatus.blockedUnconfirmed,
    );
    expect(player.initializes, 0);
    expect(h.video.blocked, isTrue);
    expect(await h.root.recover(), PracticeAudioReleaseStatus.confirmedClosed);
    expect(h.port.unknownVideoCancelCalls, 1);
    expect((await h.port.readAllAudioState()).allClear, isTrue);
    delayedReply.complete();
    await Future<void>.delayed(Duration.zero);
    expect((await h.port.readAllAudioState()).allClear, isTrue);
    await h.dispose();
  });

  test(
    'cancellation fences a reserve that arrives after its lost reply',
    () async {
      final h = _Harness(
        allowVideo: true,
        videoTimeout: const Duration(milliseconds: 30),
      );
      await h.ready();
      final queuedReserve = Completer<void>();
      h.port.beforeReserve = (_) => queuedReserve.future;
      final player = _Player();
      expect(
        await h.root.videoActionFor(h.route)!.start(player),
        PracticeVideoOpenStatus.blockedUnconfirmed,
      );
      expect(h.port.opens, isEmpty);
      expect(
        await h.root.recover(),
        PracticeAudioReleaseStatus.confirmedClosed,
      );
      queuedReserve.complete();
      await Future<void>.delayed(Duration.zero);
      expect(h.port.opens, isEmpty);
      expect(player.initializes, 0);
      expect((await h.port.readAllAudioState()).allClear, isTrue);
      await h.dispose();
    },
  );

  test(
    'new video owner can recover an old unclaimed reserve after engine change',
    () async {
      final h = _Harness(
        allowVideo: true,
        videoTimeout: const Duration(milliseconds: 30),
      );
      await h.ready();
      final delayedReply = Completer<void>();
      h.port.start = (_) => delayedReply.future;
      expect(
        await h.root.videoActionFor(h.route)!.start(_Player()),
        PracticeVideoOpenStatus.blockedUnconfirmed,
      );
      h.port.replaceEngineForTest();
      final successor = PracticeVideoSessionOwner(port: h.port);
      expect(
        await successor.recover(),
        PracticeVideoRecoveryStatus.confirmedClosed,
      );
      expect(h.video.blocked, isFalse);
      expect((await h.port.readAllAudioState()).allClear, isTrue);
      delayedReply.complete();
      await h.dispose();
    },
  );

  test(
    'failed initialize with no native claim can be explicitly cancelled',
    () async {
      final h = _Harness(allowVideo: true);
      await h.ready();
      final player = _Player(
        onInitialize: (_) async => throw StateError('init'),
      );
      expect(
        await h.root.videoActionFor(h.route)!.start(player),
        PracticeVideoOpenStatus.blockedUnconfirmed,
      );
      expect(
        (await h.port.readAllAudioState()).videoPhase,
        'unconfirmedQuiescent',
      );
      expect(
        await h.root.recover(),
        PracticeAudioReleaseStatus.confirmedClosed,
      );
      expect(h.port.videoCancelCalls, 1);
      await h.dispose();
    },
  );

  test('unknown attempt cannot clear a newer video lease', () async {
    final h = _Harness(
      allowVideo: true,
      videoTimeout: const Duration(milliseconds: 30),
    );
    await h.ready();
    final delayedReply = Completer<void>();
    h.port.start = (_) => delayedReply.future;
    expect(
      await h.root.videoActionFor(h.route)!.start(_Player()),
      PracticeVideoOpenStatus.blockedUnconfirmed,
    );
    h.port.start = null;
    final newer = await h.port.reserve(PracticeAudioSide.video, 'b' * 32);
    expect(
      await h.root.recover(),
      PracticeAudioReleaseStatus.blockedUnconfirmed,
    );
    expect(
      (await h.port.readAllAudioState()).activeLeaseGeneration,
      newer.leaseGeneration,
    );
    expect((await h.port.cancelVideoReservation(newer)).allClear, isTrue);
    expect(await h.root.recover(), PracticeAudioReleaseStatus.confirmedClosed);
    delayedReply.complete();
    await h.dispose();
  });

  test('empty video state with retry flag reaches native recoverAll', () async {
    final h = _Harness(allowVideo: true);
    await h.ready();
    h.port.requireExplicitRetryWithoutLeaseForTest();
    final before = await h.port.readAllAudioState();
    expect(before.activeSide, isNull);
    expect(before.videoPhase, 'clear');
    expect(before.requiresExplicitRetry, isTrue);
    expect(await h.root.recover(), PracticeAudioReleaseStatus.confirmedClosed);
    expect((await h.port.readAllAudioState()).allClear, isTrue);
    await h.dispose();
  });

  test('changed engine cannot accept an old player release', () async {
    final h = _Harness(allowVideo: true);
    await h.ready();
    final player = _Player();
    expect(
      await h.root.videoActionFor(h.route)!.start(player),
      PracticeVideoOpenStatus.ready,
    );
    h.video.invalidate();
    h.port.replaceEngineForTest();
    final receipt = await h.port.readAllAudioState();
    await expectLater(
      h.video.settleAfterFence(receipt),
      throwsA(isA<StateError>()),
    );
    expect(player.disposals, 1);
    expect(h.port.videoDisposeCalls, 0);
    expect(h.video.blocked, isTrue);
    expect(
      await h.root.recover(),
      PracticeAudioReleaseStatus.blockedUnconfirmed,
    );
    // This test intentionally leaves the process owner quarantined.
    h.root.dispose();
    await h.root.lastFenceForTest;
    h.user.dispose();
    h.identity.dispose();
  });
}
