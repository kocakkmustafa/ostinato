import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motion_camera/motion_camera.dart';
import 'package:ostinato/app/camera_pose_source.dart';
import 'package:ostinato/app/camera_session.dart';
import 'package:ostinato_posture/ostinato_posture.dart';
import 'package:permission_handler/permission_handler.dart';

import 'fixtures/owned_camera_native_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late OwnedCameraNativeFixture native;
  late List<CameraPoseSource> sources;
  late List<StreamSubscription<Object?>> listeners;

  CameraPoseSource source({
    String path = '/synthetic/current.task',
    CameraModelPathResolver? model,
    CameraPermissionRequest? permission,
    ValueListenable<AppLifecycleState>? lifecycle,
  }) {
    final CameraPoseSource result = CameraPoseSource(
      controller: native.controller,
      resolveModelPath: model ?? () async => path,
      requestPermission: permission ?? () async => PermissionStatus.granted,
      lifecycle: lifecycle,
    );
    sources.add(result);
    return result;
  }

  void observeErrors(Future<void> future) {
    unawaited(future.then<void>((_) {}, onError: (Object _, StackTrace _) {}));
  }

  setUp(() {
    resetCameraSessionForTesting();
    native = OwnedCameraNativeFixture();
    sources = <CameraPoseSource>[];
    listeners = <StreamSubscription<Object?>>[];
  });

  tearDown(() async {
    native.releaseGates();
    for (final StreamSubscription<Object?> listener in listeners) {
      await listener.cancel();
    }
    for (final CameraPoseSource owner in sources) {
      final Future<void> closing = owner.stop();
      observeErrors(closing);
      await owner.startSettlementForTesting?.catchError((Object _) {});
      await closing.catchError((Object _) {});
      await owner.stop().catchError((Object _) {});
      owner.captureLease.retire();
      await owner.captureLease.close().catchError((Object _) {});
      await cleanupAfterCameraFault(owner.dispose());
    }
    native.dispose();
    resetCameraSessionForTesting();
  });

  test('current owner uses exact native capture and repeated stop shares one Future', () async {
    final CameraPoseSource current = source();
    final List<PoseFrame> poses = <PoseFrame>[];
    listeners.add(current.frames.listen(poses.add));
    await current.start();
    await flushCameraCallbacks();
    expect(native.calls('startOwned'), hasLength(1));
    expect(native.ownerOf(native.calls('startOwned').single), current.captureLease.ownerId);
    expect(current.captureLease.sessionInfo?.generation, greaterThan(0));
    await native.emit(visible: true, tUs: 100);
    await flushCameraCallbacks();
    expect(poses.single.tUs, 100);
    expect(poses.single.trunkTiltDeg, isNotNull);

    final Future<void> first = current.stop();
    final Future<void> replay = current.stop();
    expect(current.captureLease.isRetired, isTrue);
    expect(identical(first, replay), isTrue);
    await first;
    expect(native.calls('stopOwned'), hasLength(1));
    expect(native.calls('readback'), hasLength(1));
    expect(native.calls('start'), isEmpty);
    expect(native.calls('stop'), isEmpty);
  });

  test('retired A permission completion cannot open over fresh B', () async {
    final Completer<PermissionStatus> permission = Completer<PermissionStatus>();
    native.extraCleanup.add(() {
      if (!permission.isCompleted) permission.complete(PermissionStatus.granted);
    });
    final CameraPoseSource old = source(path: '/synthetic/A.task', permission: () => permission.future);
    final Future<void> oldStart = old.start();
    observeErrors(oldStart);
    await flushCameraCallbacks();
    await old.stop();
    final CameraPoseSource fresh = source(path: '/synthetic/B.task');
    await fresh.start();
    permission.complete(PermissionStatus.granted);
    await oldStart;
    await flushCameraCallbacks();
    expect(native.startCalls.map((call) => (call.arguments as Map)['modelPath']),
        <String>['/synthetic/B.task']);
    expect(native.activeOwner, fresh.captureLease.ownerId);
    expect(old.captureLease.isRetired, isTrue);
  });

  test('retired A model completion cannot start or publish stale failure/pose', () async {
    final Completer<String> model = Completer<String>();
    var requestedModel = false;
    native.extraCleanup.add(() {
      if (!model.isCompleted) model.complete('/synthetic/A.task');
    });
    final CameraPoseSource old = source(model: () {
      requestedModel = true;
      return model.future;
    });
    final List<SurfaceState> status = <SurfaceState>[];
    final List<PoseFrame> poses = <PoseFrame>[];
    listeners.add(old.status.listen(status.add));
    listeners.add(old.frames.listen(poses.add));
    final Future<void> pending = old.start();
    observeErrors(pending);
    await flushCameraCallbacks();
    expect(requestedModel, isTrue, reason: 'A is actually awaiting its captured model');
    await old.stop();
    final CameraPoseSource fresh = source(path: '/synthetic/B.task');
    await fresh.start();
    model.complete('/synthetic/A.task');
    await pending;
    await native.emit(tUs: 500);
    await flushCameraCallbacks();
    expect(native.startCalls.map((call) => (call.arguments as Map)['modelPath']),
        <String>['/synthetic/B.task']);
    expect(status, isEmpty);
    expect(poses, isEmpty);
    expect(native.activeOwner, fresh.captureLease.ownerId);
  });

  test('pending native A is retired synchronously and B waits for fresh readback', () async {
    native.startGate = Completer<void>();
    native.readbackGate = Completer<void>();
    final CameraPoseSource old = source();
    final Future<void> opening = old.start();
    observeErrors(opening);
    await flushCameraCallbacks();
    final Future<void> closing = old.stop();
    observeErrors(closing);
    expect(old.captureLease.isRetired, isTrue);
    await flushCameraCallbacks();
    expect(native.calls('stopOwned').map(native.ownerOf), <String>[old.captureLease.ownerId]);

    final CameraPoseSource fresh = source(path: '/synthetic/B.task');
    final Future<void> freshStart = fresh.start();
    observeErrors(freshStart);
    await flushCameraCallbacks();
    expect(native.startCalls, hasLength(1));
    native.startGate!.complete();
    await opening;
    await flushCameraCallbacks();
    expect(native.startCalls, hasLength(1));
    expect(native.calls('readback'), hasLength(1));
    native.readbackGate!.complete();
    await closing;
    await freshStart;
    expect(native.activeOwner, fresh.captureLease.ownerId);
  });

  test('model completion waits for a close barrier installed after model resolution began', () async {
    final CameraPoseSource old = source(path: '/synthetic/A.task');
    final Completer<String> model = Completer<String>();
    var modelEntered = false;
    Future<void>? freshOpening;
    Future<void>? oldClosing;
    try {
      await old.start();
      await flushCameraCallbacks();
      expect(native.calls('startOwned'), hasLength(1));
      final CameraPoseSource fresh = source(model: () {
        modelEntered = true;
        return model.future;
      });
      freshOpening = fresh.start();
      observeErrors(freshOpening);
      await flushCameraCallbacks();
      expect(modelEntered, isTrue);
      expect(native.startCalls, hasLength(1));

      native.readbackGate = Completer<void>();
      oldClosing = old.stop();
      observeErrors(oldClosing);
      expect(old.captureLease.isRetired, isTrue);
      await flushCameraCallbacks();
      expect(native.calls('readback'), hasLength(1));
      expect(native.ownerOf(native.calls('readback').single), old.captureLease.ownerId);
      model.complete('/synthetic/B.task');
      await flushCameraCallbacks();
      expect(native.startCalls, hasLength(1),
          reason: 'a closure admitted while B awaited its model still requires exact fresh proof');
      expect(fresh.captureLease.sessionInfo, isNull);
      native.readbackGate!.complete();
      await oldClosing;
      await freshOpening;
      await flushCameraCallbacks();
      expect(native.calls('startOwned'), hasLength(2));
      expect(native.activeOwner, fresh.captureLease.ownerId);
      expect(native.calls('start'), isEmpty);
      expect(native.calls('stop'), isEmpty);
    } finally {
      if (!model.isCompleted) model.complete('/synthetic/B.task');
      native.releaseGates();
      await oldClosing;
      await freshOpening;
    }
  });

  test('native start ACK during transient inactive waits for resumed before frame attachment', () async {
    final ValueNotifier<AppLifecycleState> lifecycle = ValueNotifier(AppLifecycleState.resumed);
    addTearDown(lifecycle.dispose);
    native.startGate = Completer<void>();
    final CameraPoseSource current = source(lifecycle: lifecycle);
    final List<PoseFrame> poses = <PoseFrame>[];
    listeners.add(current.frames.listen(poses.add));
    final Future<void> opening = current.start();
    var settled = false;
    unawaited(opening.then<void>((_) { settled = true; },
        onError: (Object _, StackTrace _) { settled = true; }));
    try {
      await flushCameraCallbacks();
      expect(native.calls('startOwned'), hasLength(1));
      expect(current.captureLease.sessionInfo, isNull,
          reason: 'the actual native start ACK is still held');
      lifecycle.value = AppLifecycleState.inactive;
      native.startGate!.complete();
      await flushCameraCallbacks();
      expect(current.captureLease.sessionInfo, isNotNull);
      expect(current.captureLease.isRetired, isFalse);
      expect(settled, isFalse,
          reason: 'an inactive native ACK must retain the original pending start');
      expect(native.streamCalls.where((call) => call.method == 'listen'), isEmpty);
      lifecycle.value = AppLifecycleState.resumed;
      await opening;
      await flushCameraCallbacks();
      expect(settled, isTrue);
      expect(native.streamCalls.where((call) => call.method == 'listen'), hasLength(1));
      expect(native.streamOwner, current.captureLease.ownerId);
      await native.emit(visible: true, tUs: 1500);
      await flushCameraCallbacks();
      expect(poses.single.tUs, 1500);
      expect(poses.single.trunkTiltDeg, isNotNull);
      expect(native.calls('startOwned'), hasLength(1),
          reason: 'resumed attaches frames to the same original native capture');
    } finally {
      lifecycle.value = AppLifecycleState.resumed;
      native.releaseGates();
      await opening;
      await current.stop();
    }
  });

  test('generation-zero ACK is followed by exact reclose after late A start', () async {
    native.startGate = Completer<void>();
    native.absentOwnerAckBeforeLateStart = true;
    final CameraPoseSource old = source();
    final Future<void> opening = old.start();
    observeErrors(opening);
    await flushCameraCallbacks();
    final Future<void> closing = old.stop();
    observeErrors(closing);
    await flushCameraCallbacks();
    native.startGate!.complete();
    await opening;
    await closing;
    expect(native.calls('stopOwned').map(native.ownerOf),
        <String>[old.captureLease.ownerId, old.captureLease.ownerId]);
    expect(native.calls('readback'), hasLength(1));
    expect(native.activeOwner, isNull);
    final CameraPoseSource fresh = source();
    await fresh.start();
    expect(native.activeOwner, fresh.captureLease.ownerId);
  });

  test('permission-denied and busy B retire only B while current A keeps frames', () async {
    final CameraPoseSource current = source();
    final List<PoseFrame> poses = <PoseFrame>[];
    listeners.add(current.frames.listen(poses.add));
    await current.start();
    await flushCameraCallbacks();
    final String? activeBefore = native.activeOwner;
    final CameraPoseSource denied = source(permission: () async => PermissionStatus.denied);
    await denied.start();
    await denied.stop();
    native.rejectWhileRunning = true;
    final CameraPoseSource busy = source();
    final List<SurfaceState> failures = <SurfaceState>[];
    listeners.add(busy.status.listen(failures.add));
    await busy.start();
    await busy.stop();
    await native.emit(tUs: 700);
    await flushCameraCallbacks();
    expect(denied.captureLease.isRetired, isTrue);
    expect(busy.captureLease.isRetired, isTrue);
    expect(failures.whereType<SetupFailed>(), isNotEmpty);
    expect(native.activeOwner, activeBefore);
    expect(poses.single.tUs, 700);
    expect(native.stopCalls.any((call) => native.ownerOf(call) == current.captureLease.ownerId), isFalse);
    expect(native.calls('stop'), isEmpty);
  });

  test('wrong closure owner/generation/model/nonce/sequence keeps successor quarantined', () async {
    for (final String fault in <String>['owner', 'generation', 'capture', 'model', 'state', 'nonce', 'sequence']) {
      final CameraPoseSource old = source();
      await old.start();
      native.receiptFault = fault;
      await expectLater(old.stop(), throwsA(isA<CameraException>().having(
        (error) => error.failure, 'failure', CameraFailure.closeUncertain,
      )));
      expect(old.captureLease.isUncertain, isTrue, reason: fault);
      native.receiptFault = null;
      final int startsBefore = native.startCalls.length;
      final CameraPoseSource fresh = source();
      final List<SurfaceState> failures = <SurfaceState>[];
      final StreamSubscription<SurfaceState> listener = fresh.status.listen(failures.add);
      listeners.add(listener);
      await fresh.start();
      await flushCameraCallbacks();
      expect(native.startCalls, hasLength(startsBefore), reason: fault);
      expect(failures.whereType<SetupFailed>().any((state) => state.reason == 'close-uncertain'), isTrue);
      // Each fault is a fresh process fixture; production has no quarantine reset.
      for (final CameraPoseSource owner in sources) {
        await owner.stop().catchError((Object _) {});
        await cleanupAfterCameraFault(owner.dispose());
      }
      sources.clear();
      for (final StreamSubscription<Object?> sub in listeners) { await sub.cancel(); }
      listeners.clear();
      native.dispose();
      resetCameraSessionForTesting();
      native = OwnedCameraNativeFixture();
    }
  });

  test('old owned protocol and readback timeout never fall back to global native calls', () async {
    native.ownedUnavailable = true;
    final CameraPoseSource unavailable = source();
    final List<SurfaceState> failures = <SurfaceState>[];
    listeners.add(unavailable.status.listen(failures.add));
    await unavailable.start();
    await flushCameraCallbacks();
    expect(failures.whereType<SetupFailed>().any((state) =>
        state.reason == 'owned-protocol-unavailable' || state.reason == 'close-uncertain'), isTrue);
    expect(native.calls('start'), isEmpty);
    native.ownedUnavailable = false;
    final int before = native.startCalls.length;
    await source().start();
    expect(native.startCalls, hasLength(before));

    // A separate process fixture covers timeout; there is no app reset fallback.
    for (final CameraPoseSource owner in sources) {
      await owner.stop().catchError((Object _) {});
      await cleanupAfterCameraFault(owner.dispose());
    }
    sources.clear();
    for (final StreamSubscription<Object?> sub in listeners) { await sub.cancel(); }
    listeners.clear();
    native.dispose();
    resetCameraSessionForTesting();
    native = OwnedCameraNativeFixture(timeout: const Duration(milliseconds: 40));
    final CameraPoseSource timedOut = source();
    await timedOut.start();
    native.neverAnswerReadback = true;
    await expectLater(timedOut.stop(), throwsA(isA<CameraException>().having(
      (error) => error.failure, 'failure', CameraFailure.closeUncertain,
    )));
    final int attempted = native.startCalls.length;
    await source().start();
    expect(native.startCalls, hasLength(attempted));
    expect(native.calls('stop'), isEmpty);
  });

  test('paused retained A listener and repeated old stop cannot cancel B raw EventChannel', () async {
    final CameraPoseSource old = source();
    await old.start();
    final StreamSubscription<CameraFrameEnvelope> retained = old.captureLease.frames().listen((_) {});
    listeners.add(retained);
    retained.pause();
    await flushCameraCallbacks();
    await old.stop();
    final CameraPoseSource fresh = source();
    final List<PoseFrame> poses = <PoseFrame>[];
    listeners.add(fresh.frames.listen(poses.add));
    await fresh.start();
    await flushCameraCallbacks();
    final int cancels = native.streamCalls.where((call) => call.method == 'cancel').length;
    await retained.cancel();
    await old.stop();
    await native.emit(tUs: 900);
    await flushCameraCallbacks();
    expect(native.streamOwner, fresh.captureLease.ownerId);
    expect(poses.single.tUs, 900);
    expect(native.streamCalls.where((call) => call.method == 'cancel'), hasLength(cancels));
    expect(native.calls('stop'), isEmpty);
  });

  test('wrong-owner/generation and events delivered after retirement never reach pose or status', () async {
    final CameraPoseSource current = source();
    final List<PoseFrame> poses = <PoseFrame>[];
    final List<SurfaceState> status = <SurfaceState>[];
    listeners.add(current.frames.listen(poses.add));
    listeners.add(current.status.listen(status.add));
    await current.start();
    await flushCameraCallbacks();
    await native.emit(owner: 'wrong-owner', generation: 1, tUs: 1);
    await native.emit(owner: current.captureLease.ownerId, generation: 999, tUs: 2);
    await flushCameraCallbacks();
    expect(poses, isEmpty);
    current.captureLease.retire();
    await native.emit(owner: current.captureLease.ownerId, generation: 1, tUs: 3);
    await native.emitError();
    await flushCameraCallbacks();
    expect(poses, isEmpty);
    expect(status, isEmpty);
  });

  test('current owned transport denial is surfaced once after Core retires its lease', () async {
    final CameraPoseSource current = source();
    final List<PoseFrame> poses = <PoseFrame>[];
    final List<SurfaceState> status = <SurfaceState>[];
    listeners.add(current.frames.listen(poses.add));
    listeners.add(current.status.listen(status.add));
    await current.start();
    await flushCameraCallbacks();
    await native.emitError();
    await flushCameraCallbacks();
    expect(current.captureLease.isRetired && current.captureLease.isUncertain, isTrue);
    expect(status, hasLength(1),
        reason: 'Core retirement must not suppress the current typed denial');
    expect(status.single, isA<SetupFailed>().having(
      (failure) => failure.reason, 'reason', 'close-uncertain',
    ));
    await native.emit(visible: true, tUs: 1200);
    await native.emitError();
    await flushCameraCallbacks();
    expect(poses, isEmpty);
    expect(status, hasLength(1));
    final Future<void> closing = current.stop();
    expect(identical(closing, current.stop()), isTrue);
    await expectLater(closing, throwsA(isA<CameraException>().having(
      (error) => error.failure, 'failure', CameraFailure.closeUncertain,
    )));
    final int attempted = native.startCalls.length;
    await source().start();
    expect(native.startCalls, hasLength(attempted));
    expect(native.calls('start'), isEmpty);
    expect(native.calls('stop'), isEmpty);
  });

  test('permission dialog inactive waits for foreground; true background permanently retires owner', () async {
    final ValueNotifier<AppLifecycleState> lifecycle = ValueNotifier(AppLifecycleState.resumed);
    addTearDown(lifecycle.dispose);
    final Completer<PermissionStatus> permission = Completer<PermissionStatus>();
    native.extraCleanup.add(() {
      if (!permission.isCompleted) permission.complete(PermissionStatus.granted);
    });
    final CameraPoseSource pending = source(permission: () => permission.future, lifecycle: lifecycle);
    final Future<void> opening = pending.start();
    observeErrors(opening);
    await flushCameraCallbacks();
    lifecycle.value = AppLifecycleState.inactive;
    permission.complete(PermissionStatus.granted);
    await flushCameraCallbacks();
    expect(pending.captureLease.isRetired, isFalse,
        reason: 'transient permission dialog inactive is not background retirement');
    expect(native.startCalls, isEmpty);
    lifecycle.value = AppLifecycleState.resumed;
    await opening;
    expect(native.startCalls, hasLength(1));
    lifecycle.value = AppLifecycleState.paused;
    expect(pending.captureLease.isRetired, isTrue);
    await pending.stop();
    lifecycle.value = AppLifecycleState.resumed;
    await pending.start();
    expect(native.startCalls, hasLength(1), reason: 'background A never resumes as a fresh owner');
  });
}
