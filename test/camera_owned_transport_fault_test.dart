import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MethodCall;
import 'package:flutter_test/flutter_test.dart';
import 'package:motion_camera/motion_camera.dart';

import 'fixtures/owned_camera_native_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late OwnedCameraNativeFixture native;
  late CameraCaptureLease lease;
  StreamSubscription<CameraFrameEnvelope>? frames;
  late List<Object> frameErrors;
  late List<FlutterErrorDetails> callbackWarnings;
  FlutterExceptionHandler? previousErrorHandler;

  void createFixture({Duration timeout = const Duration(milliseconds: 200)}) {
    native = OwnedCameraNativeFixture(timeout: timeout);
    lease = native.controller.createCaptureLease();
    frames = null;
    frameErrors = <Object>[];
  }

  setUp(() {
    createFixture();
    callbackWarnings = <FlutterErrorDetails>[];
    previousErrorHandler = FlutterError.onError;
    FlutterError.onError = callbackWarnings.add;
  });

  Future<void> cleanup() async {
    native.releaseGates();
    await lease.close().catchError((Object _) {});
    await frames?.cancel();
    await flushCameraCallbacks();
    native.dispose();
  }

  tearDown(() async {
    try {
      await cleanup();
    } finally {
      FlutterError.onError = previousErrorHandler;
    }
  });

  Future<void> open() async {
    await lease.start(modelPath: '/synthetic/transport.task', modelId: 'synthetic');
    frames = lease.frames().listen((_) {}, onError: (Object error) { frameErrors.add(error); });
    await flushCameraCallbacks();
    expect(native.streamCalls.where((call) => call.method == 'listen'), hasLength(1));
  }

  Matcher getCloseUncertain() => isA<CameraException>().having(
    (error) => error.failure, 'failure', CameraFailure.closeUncertain,
  );

  Future<void> expectSuccessorDenied() async {
    final int starts = native.calls('startOwned').length;
    final CameraCaptureLease successor = native.controller.createCaptureLease();
    await expectLater(successor.start(modelPath: '/synthetic/B.task', modelId: 'synthetic'),
        throwsA(getCloseUncertain()));
    expect(native.calls('startOwned'), hasLength(starts));
    expect(native.calls('start'), isEmpty);
    expect(native.calls('stop'), isEmpty);
  }

  test('retirement waits for admitted listen ACK before exact cancel and readback', () async {
    native.listenGate = Completer<void>();
    await open();
    var settled = false;
    final Future<void> closing = lease.close();
    unawaited(closing.then<void>((_) { settled = true; },
        onError: (Object _, StackTrace _) { settled = true; }));
    await flushCameraCallbacks();
    expect(native.streamCalls.where((call) => call.method == 'cancel'), isEmpty,
        reason: 'cancel cannot race the still-admitted native listen');
    expect(settled, isFalse);
    expect(native.calls('readback'), isEmpty);
    native.listenGate!.complete();
    await closing;
    final MethodCall cancel = native.streamCalls.singleWhere((call) => call.method == 'cancel');
    expect(native.ownerOf(cancel), lease.ownerId);
    expect((cancel.arguments as Map)['generation'], lease.sessionInfo!.generation);
    expect(native.calls('readback'), hasLength(1));
  });

  test('actual listen RPC error becomes typed transport denial and sticky quarantine', () async {
    native.rejectListenAck = true;
    await open();
    await flushCameraCallbacks();
    expect(frameErrors, hasLength(1),
        reason: 'callback warnings=${callbackWarnings.length}; a warning is not a lease failure');
    expect(frameErrors.single, getCloseUncertain());
    expect(lease.isRetired && lease.isUncertain, isTrue);
    await expectLater(lease.close(), throwsA(getCloseUncertain()));
    expect(native.streamCalls.where((call) => call.method == 'cancel'), hasLength(1));
    expect(native.calls('readback'), isEmpty);
    await expectSuccessorDenied();
  });

  test('actual listen ACK timeout retires capture and late ACK cannot restore admission', () async {
    await cleanup();
    createFixture(timeout: const Duration(milliseconds: 40));
    native.listenGate = Completer<void>();
    await open();
    await Future<void>.delayed(const Duration(milliseconds: 60));
    await flushCameraCallbacks();
    expect(frameErrors, hasLength(1));
    expect(frameErrors.single, getCloseUncertain());
    expect(lease.isRetired && lease.isUncertain, isTrue);
    await expectLater(lease.close(), throwsA(getCloseUncertain()));
    expect(native.streamCalls.where((call) => call.method == 'cancel'), hasLength(1));
    native.listenGate!.complete();
    await flushCameraCallbacks();
    await expectSuccessorDenied();
    expect(native.calls('readback'), isEmpty);
  });

  test('actual cancel ACK timeout remains uncertain after late reply and blocks B', () async {
    await cleanup();
    createFixture(timeout: const Duration(milliseconds: 40));
    await open();
    native.cancelGate = Completer<void>();
    final Future<void> closing = lease.close();
    await expectLater(closing, throwsA(getCloseUncertain()));
    expect(lease.isUncertain, isTrue);
    native.cancelGate!.complete();
    await flushCameraCallbacks();
    expect(identical(closing, lease.close()), isTrue);
    await expectLater(lease.close(), throwsA(getCloseUncertain()));
    expect(native.calls('readback'), isEmpty);
    await expectSuccessorDenied();
  });

  test('active encoded EOS, error and malformed frame each retire and quarantine exact owner', () async {
    for (final String fault in <String>['eos', 'error', 'malformed']) {
      await open();
      switch (fault) {
        case 'eos': await native.emitEnd();
        case 'error': await native.emitError();
        case 'malformed': await native.emitMalformed();
      }
      await flushCameraCallbacks();
      expect(frameErrors, hasLength(1), reason: fault);
      expect(frameErrors.single, getCloseUncertain(), reason: fault);
      expect(lease.isRetired && lease.isUncertain, isTrue, reason: fault);
      await expectLater(lease.close(), throwsA(getCloseUncertain()));
      expect(native.calls('stopOwned'), hasLength(1), reason: fault);
      expect(native.ownerOf(native.calls('stopOwned').single), lease.ownerId);
      expect(native.streamCalls.where((call) => call.method == 'cancel'), hasLength(1));
      expect(native.calls('readback'), isEmpty);
      await expectSuccessorDenied();
      await cleanup();
      createFixture();
    }
  });
}
