import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motion_camera/motion_camera.dart';

/// Exercises the published controller/lease and real EventChannel handler.
/// Only the synthetic native wire endpoint is mocked; no CameraCaptureLease
/// implementation or camera hardware/media/model bytes are substituted.
final class OwnedCameraNativeFixture {
  OwnedCameraNativeFixture({
    Duration timeout = const Duration(milliseconds: 200),
  }) {
    final int serial = ++_serial;
    _control = MethodChannel('ostinato/camera-test/$serial/control',
        const StandardMethodCodec(), _messenger);
    _eventName = 'ostinato/camera-test/$serial/frames';
    _eventControl = MethodChannel(_eventName, const StandardMethodCodec(), _messenger);
    controller = MotionCameraController(
      control: _control,
      frames: EventChannel(_eventName, const StandardMethodCodec(), _messenger),
      controlTimeout: timeout,
    );
    _messenger.setMockMethodCallHandler(_control, _onControl);
    _messenger.setMockMethodCallHandler(_eventControl, _onStreamControl);
  }

  static int _serial = 0;
  final TestDefaultBinaryMessenger _messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late final MethodChannel _control;
  late final MethodChannel _eventControl;
  late final String _eventName;
  late final MotionCameraController controller;
  final List<MethodCall> controlCalls = <MethodCall>[];
  final List<MethodCall> streamCalls = <MethodCall>[];
  final Map<String, int> generations = <String, int>{};
  final Map<String, int> closeSequences = <String, int>{};
  final List<void Function()> extraCleanup = <void Function()>[];
  String? activeOwner;
  String? streamOwner;
  int _generation = 0;
  Completer<void>? startGate;
  Completer<void>? ackGate;
  Completer<void>? readbackGate;
  Completer<void>? cancelGate;
  Completer<void>? listenGate;
  Completer<void>? _heldReadback;
  bool absentOwnerAckBeforeLateStart = false;
  bool rejectWhileRunning = false;
  bool ownedUnavailable = false;
  bool neverAnswerReadback = false;
  bool rejectCancelAck = false;
  bool rejectListenAck = false;
  String? receiptFault;

  List<MethodCall> calls(String method) =>
      controlCalls.where((call) => call.method == method).toList();

  List<MethodCall> get startCalls => controlCalls
      .where((call) => call.method == 'startOwned' || call.method == 'start')
      .toList();

  List<MethodCall> get stopCalls => controlCalls
      .where((call) => call.method == 'stopOwned' || call.method == 'stop')
      .toList();

  String? ownerOf(MethodCall call) =>
      (call.arguments as Map<Object?, Object?>?)?['ownerId'] as String?;

  Future<Object?> _onControl(MethodCall call) async {
    controlCalls.add(call);
    final Map<Object?, Object?> args =
        (call.arguments as Map<Object?, Object?>?) ?? <Object?, Object?>{};
    final bool owned = call.method.endsWith('Owned') || call.method == 'readback';
    if (owned && ownedUnavailable) throw MissingPluginException('owned RPC absent');
    switch (call.method) {
      case 'start':
      case 'startOwned':
        if (rejectWhileRunning && activeOwner != null) {
          throw PlatformException(code: 'already-running');
        }
        final String owner = args['ownerId'] as String? ?? 'legacy-${_generation + 1}';
        await startGate?.future;
        final int generation = ++_generation;
        generations[owner] = generation;
        activeOwner = owner;
        return <String, Object>{
          'protocol': 1,
          'ownerId': owner,
          'generation': generation,
          'w': 720,
          'h': 1280,
          'clock': 'monotonic',
          'library': 'synthetic-owned-camera',
        };
      case 'stop':
        await ackGate?.future;
        activeOwner = null;
        return null;
      case 'stopOwned':
        final String owner = args['ownerId']! as String;
        final bool absent = absentOwnerAckBeforeLateStart &&
            !generations.containsKey(owner);
        await ackGate?.future;
        if (activeOwner == owner) activeOwner = null;
        closeSequences[owner] = (closeSequences[owner] ?? 0) + 1;
        return _closed(owner, 0, generation: absent ? 0 : null);
      case 'readback':
        if (neverAnswerReadback) {
          _heldReadback ??= Completer<void>();
          await _heldReadback!.future;
        }
        await readbackGate?.future;
        return _closed(args['ownerId']! as String, args['nonce']! as int);
      default:
        throw MissingPluginException(call.method);
    }
  }

  Map<String, Object> _closed(String owner, int nonce, {int? generation}) {
    final Map<String, Object> reply = <String, Object>{
      'protocol': 1,
      'ownerId': owner,
      'generation': generation ?? generations[owner] ?? 0,
      'state': 'closed',
      'captureClosed': true,
      'modelsClosed': true,
      'closeSequence': closeSequences[owner] ?? 0,
      'nonce': nonce,
    };
    switch (receiptFault) {
      case 'owner': reply['ownerId'] = 'another-owner';
      case 'generation': reply['generation'] = 999;
      case 'capture': reply['captureClosed'] = false;
      case 'model': reply['modelsClosed'] = false;
      case 'state': reply['state'] = 'closing';
      case 'nonce': if (nonce > 0) reply['nonce'] = nonce - 1;
      case 'sequence': if (nonce > 0) reply['closeSequence'] = 0;
    }
    return reply;
  }

  Future<Object?> _onStreamControl(MethodCall call) async {
    streamCalls.add(call);
    final String? owner = ownerOf(call);
    if (call.method == 'listen') {
      streamOwner = owner ?? activeOwner;
      await listenGate?.future;
      if (rejectListenAck) {
        throw PlatformException(code: 'listen-ack-rejected',
            message: 'synthetic native stream did not acknowledge activation');
      }
    }
    if (call.method == 'cancel') {
      await cancelGate?.future;
      if (rejectCancelAck) {
        throw PlatformException(code: 'cancel-ack-rejected',
            message: 'synthetic native stream did not acknowledge cancellation');
      }
      // A legacy/global cancel deliberately exposes an unsafe successor clear.
      if (owner == null || owner == streamOwner) streamOwner = null;
    }
    return null;
  }

  Future<void> emit({
    String? owner,
    int? generation,
    int tUs = 1,
    bool visible = false,
  }) async {
    final String selected = owner ?? activeOwner ?? 'absent';
    await _messenger.handlePlatformMessage(
      _eventName,
      const StandardMethodCodec().encodeSuccessEnvelope(<String, Object?>{
        'ownerId': selected,
        'generation': generation ?? generations[selected] ?? 0,
        't': tUs,
        'w': 720,
        'h': 1280,
        'model': 'synthetic-owned-camera',
        'clock': 'monotonic',
        'infUs': 50,
        'dropped': 0,
        'up': visible ? _torso() : null,
      }),
      (_) {},
    );
  }

  Future<void> emitError() async {
    await _messenger.handlePlatformMessage(
      _eventName,
      const StandardMethodCodec().encodeErrorEnvelope(
        code: 'session-interrupted', message: 'synthetic stale event',
      ),
      (_) {},
    );
  }

  Future<void> emitEnd() async {
    await _messenger.handlePlatformMessage(_eventName, null, (_) {});
  }

  Future<void> emitMalformed() async {
    await _messenger.handlePlatformMessage(
      _eventName,
      const StandardMethodCodec().encodeSuccessEnvelope(<String, Object>{
        'ownerId': activeOwner ?? 'absent',
        'generation': generations[activeOwner] ?? 0,
        't': 1,
        'w': 720,
        'h': 1280,
        'model': 'synthetic-malformed',
        'clock': 'monotonic',
        'infUs': 0,
        'dropped': 0,
        'up': Float32List(4),
      }),
      (_) {},
    );
  }

  static Float32List _torso() {
    final Float32List points = Float32List(33 * 4);
    for (var index = 0; index < 33; index++) {
      points[index * 4] = .5;
      points[index * 4 + 1] = .5;
      points[index * 4 + 3] = 1;
    }
    for (final (index, x, y) in <(int, double, double)>[
      (11, .4, .25), (12, .6, .25), (23, .42, .7), (24, .58, .7),
    ]) {
      points[index * 4] = x;
      points[index * 4 + 1] = y;
    }
    return points;
  }

  /// Unblock teardown even when an assertion stops a negative test early.
  void releaseGates() {
    for (final void Function() release in extraCleanup) {
      release();
    }
    extraCleanup.clear();
    for (final Completer<void>? gate in <Completer<void>?>[
      startGate, ackGate, readbackGate, cancelGate, listenGate, _heldReadback,
    ]) {
      if (gate != null && !gate.isCompleted) gate.complete();
    }
    neverAnswerReadback = false;
    rejectCancelAck = false;
    rejectListenAck = false;
    receiptFault = null;
    ownedUnavailable = false;
  }

  void dispose() {
    releaseGates();
    _messenger.setMockMethodCallHandler(_control, null);
    _messenger.setMockMethodCallHandler(_eventControl, null);
  }
}

Future<void> flushCameraCallbacks() async {
  for (var turn = 0; turn < 4; turn++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// Fault tests assert the original failing close before disposing source buses.
/// Cleanup accepts only that typed quarantine failure, never an arbitrary error.
Future<void> cleanupAfterCameraFault(Future<void> cleanup) async {
  try {
    await cleanup;
  } on CameraException catch (error) {
    if (error.failure != CameraFailure.closeUncertain) rethrow;
  }
}

/// Widget body cleanup must drain Futures while its fake-async zone is alive.
/// This advances the existing 200ms native bound; it does not extend it.
Future<void> settleWidgetCameraWork(
  WidgetTester tester,
  Future<void> work, {
  required String label,
}) async {
  var settled = false;
  Object? failure;
  StackTrace? stack;
  unawaited(work.then<void>((_) { settled = true; },
      onError: (Object error, StackTrace trace) {
        failure = error;
        stack = trace;
        settled = true;
      }));
  for (var turn = 0; turn < 80 && !settled; turn++) {
    // Broadcast cancel can return Dart's shared root-zone completed Future.
    // Fake pump alone cannot run its continuation; yield the real zone too.
    await tester.runAsync(() async { await Future<void>.delayed(Duration.zero); });
    await tester.pump(const Duration(milliseconds: 5));
  }
  if (!settled) throw StateError('camera test cleanup did not settle: $label');
  if (failure != null) Error.throwWithStackTrace(failure!, stack!);
}
