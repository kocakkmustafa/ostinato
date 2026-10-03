import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motion_camera/motion_camera.dart';

import 'fixtures/owned_camera_native_fixture.dart';

/// This bypasses the app's still-legacy RED wrapper, while preserving the
/// actual published lease and actual EventChannel subscription/cancel RPC.
/// A Flutter callback warning is recorded separately from a native close ACK.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late OwnedCameraNativeFixture native;
  late CameraCaptureLease lease;
  StreamSubscription<CameraFrameEnvelope>? appFrames;
  late List<FlutterErrorDetails> callbackWarnings;
  FlutterExceptionHandler? previousErrorHandler;

  setUp(() {
    native = OwnedCameraNativeFixture();
    lease = native.controller.createCaptureLease();
    appFrames = null;
    callbackWarnings = <FlutterErrorDetails>[];
    previousErrorHandler = FlutterError.onError;
    FlutterError.onError = callbackWarnings.add;
  });

  tearDown(() async {
    native.releaseGates();
    await lease.close().catchError((Object _) {});
    await appFrames?.cancel();
    native.dispose();
    FlutterError.onError = previousErrorHandler;
  });

  Future<void> open() async {
    await lease.start(modelPath: '/synthetic/cancel-ack.task', modelId: 'synthetic');
    appFrames = lease.frames().listen((_) {});
    await flushCameraCallbacks();
    expect(native.streamCalls.where((call) => call.method == 'listen'), hasLength(1));
  }

  test('actual Core lease close remains pending until native EventChannel cancel ACK', () async {
    await open();
    native.cancelGate = Completer<void>();
    var closeSettled = false;
    Object? closeError;
    final Future<void> closing = lease.close();
    unawaited(closing.then<void>((_) { closeSettled = true; },
        onError: (Object error, StackTrace _) { closeError = error; closeSettled = true; }));
    expect(lease.isRetired, isTrue);
    await flushCameraCallbacks();
    expect(native.streamCalls.where((call) => call.method == 'cancel'), hasLength(1));
    expect(native.calls('stopOwned'), hasLength(1));
    expect(closeSettled, isFalse,
        reason: 'raw StreamSubscription.cancel completion does not prove native cancel RPC ACK');
    native.cancelGate!.complete();
    await closing;
    expect(closeError, isNull);
    expect(native.calls('readback'), hasLength(1));
  });

  test('actual native cancel RPC rejection yields closeUncertain instead of warning-only success', () async {
    await open();
    native.rejectCancelAck = true;
    Object? closeError;
    var closeSettled = false;
    final Future<void> closing = lease.close();
    unawaited(closing.then<void>((_) { closeSettled = true; },
        onError: (Object error, StackTrace _) { closeError = error; closeSettled = true; }));
    await flushCameraCallbacks();
    expect(native.streamCalls.where((call) => call.method == 'cancel'), hasLength(1));
    expect(closeSettled, isTrue);
    expect(closeError, isA<CameraException>().having(
      (error) => error.failure, 'failure', CameraFailure.closeUncertain,
    ), reason: 'callback warnings=${callbackWarnings.length}; a warning cannot substitute for an ACK');
    expect(lease.isUncertain, isTrue);
    final CameraCaptureLease successor = native.controller.createCaptureLease();
    await expectLater(successor.start(modelPath: '/synthetic/B.task', modelId: 'synthetic'),
        throwsA(isA<CameraException>().having(
          (error) => error.failure, 'failure', CameraFailure.closeUncertain,
        )));
    expect(native.calls('startOwned'), hasLength(1));
  });
}
