import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motion_account/motion_account.dart';
import 'package:ostinato/app/audio/audio_capture_channel.dart';
import 'package:ostinato/app/audio/audio_input_controller.dart';
import 'package:ostinato/app/audio/native_audio_arbiter_channel.dart';
import 'package:ostinato/app/audio/practice_audio_lease.dart';
import 'package:ostinato/app/audio/practice_audio_root.dart';
import 'package:permission_handler/permission_handler.dart';

const _arbiterMethod = MethodChannel('test/legacy_capture_context_arbiter');
const _ownerToken = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

final class _NativeHarness {
  _NativeHarness(this.messenger) {
    messenger.setMockMethodCallHandler(_arbiterMethod, (call) async {
      calls.add(call.method);
      switch (call.method) {
        case 'bind':
          return <String, Object?>{
            'schemaVersion': 1,
            'ownerToken': _ownerToken,
            'engineGeneration': 1,
            'contextGeneration': 0,
            'stateRevision': 0,
          };
        case 'readAllAudioState':
          return snapshot();
        case 'fenceContext':
          final args = Map<String, Object?>.from(call.arguments as Map);
          if (args['contextGeneration'] != context) {
            throw PlatformException(code: 'stale_audio_context');
          }
          ++context;
          ++revision;
          return <String, Object?>{
            'status': 'closed',
            'contextGeneration': context,
            'stateRevision': revision,
            'snapshot': snapshot(),
          };
      }
      throw PlatformException(code: 'unexpected_${call.method}');
    });
  }

  final TestDefaultBinaryMessenger messenger;
  final calls = <String>[];
  int context = 0;
  int revision = 0;

  Map<String, Object?> snapshot() => <String, Object?>{
    'schemaVersion': 1,
    'ownerToken': _ownerToken,
    'engineGeneration': 1,
    'contextGeneration': context,
    'stateRevision': revision,
    'activeSide': null,
    'activeLeaseGeneration': null,
    'inputPhase': 'clear',
    'outputPhase': 'clear',
    'inputReleased': true,
    'outputReleased': true,
    'sessionReleased': true,
    'nativeOperationInFlight': false,
    'requiresExplicitRetry': false,
    'allClear': true,
  };

  void dispose() => messenger.setMockMethodCallHandler(_arbiterMethod, null);
}

final class _RouteHarness {
  _RouteHarness(this.native)
    : user = ValueNotifier<String?>('A'),
      phase = ValueNotifier(MotionIdentityPhase.verified),
      arbiter = NativeAudioArbiterChannel(channel: _arbiterMethod) {
    owner = PracticeAudioRootOwner(
      userId: user,
      phase: phase,
      lease: PracticeAudioLease(port: arbiter),
      captureArbiter: arbiter,
      initialLifecycleState: AppLifecycleState.resumed,
      allowDetachedRouteEventsForTest: true,
      allowAcquisition: false,
    );
    observer = PracticeAudioRouteObserver(owner);
    route = MaterialPageRoute<void>(builder: (_) => const SizedBox());
  }

  final _NativeHarness native;
  final ValueNotifier<String?> user;
  final ValueNotifier<MotionIdentityPhase> phase;
  final NativeAudioArbiterChannel arbiter;
  late final PracticeAudioRootOwner owner;
  late final PracticeAudioRouteObserver observer;
  late final Route<void> route;

  Future<void> ready() async {
    owner.attachNavigator(observer);
    observer.didPush(route, null);
    await owner.lastFenceForTest;
    expect(owner.blocked, isFalse);
  }

  Future<void> dispose() async {
    owner.dispose();
    await owner.lastFenceForTest;
    user.dispose();
    phase.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late _NativeHarness native;
  setUp(() {
    resetAudioCaptureCoordinatorForTest();
    native = _NativeHarness(messenger);
  });
  tearDown(() => native.dispose());

  test(
    'production capture without a root action never asks for permission',
    () async {
      var permissions = 0;
      final source = AudioInputController(
        channel: MethodChannelAudioCaptureChannel(),
        requestMicrophonePermission: () async {
          ++permissions;
          return PermissionStatus.granted;
        },
      );
      await source.start(sampleRate: 44100);
      expect(permissions, 0);
      expect(source.captureCloseState.phase, AudioCaptureClosePhase.unknown);
      await source.dispose();
    },
  );

  test(
    'capture action is route-bound even when practice lease acquisition is off',
    () async {
      final route = _RouteHarness(native);
      await route.ready();
      final action = route.owner.captureActionFor(route.route)!;
      expect(action.claim.contextGeneration, native.context);
      expect(action.claim.ownerToken, _ownerToken);
      expect(await action.confirmPreflight(), isTrue);
      var cancelled = 0;
      expect(action.attachCancellation(() => ++cancelled), isTrue);

      route.user.value = 'B';
      expect(cancelled, 1); // before a pump or native fence response
      expect(action.isCurrent, isFalse);
      expect(await action.confirmPreflight(), isFalse);
      expect(route.owner.captureActionFor(route.route), isNull);
      await route.dispose();
    },
  );

  test(
    'late permission after account fence cannot start a fake microphone',
    () async {
      final route = _RouteHarness(native);
      await route.ready();
      final action = route.owner.captureActionFor(route.route)!;
      final permission = Completer<PermissionStatus>();
      final requested = Completer<void>();
      final capture = FakeAudioCaptureChannel();
      final source = AudioInputController(
        channel: capture,
        requestMicrophonePermission: () {
          requested.complete();
          return permission.future;
        },
      );
      final starting = source.start(sampleRate: 44100, captureAction: action);
      await requested.future;
      route.user.value = 'B';
      expect(action.isCurrent, isFalse);
      permission.complete(PermissionStatus.granted);
      await starting;
      expect(capture.isRunning, isFalse);
      await source.dispose();
      await capture.dispose();
      await route.dispose();
    },
  );

  test(
    'active legacy capture closes before native account fence dispatch',
    () async {
      final route = _RouteHarness(native);
      await route.ready();
      final action = route.owner.captureActionFor(route.route)!;
      final capture = FakeAudioCaptureChannel();
      final source = AudioInputController(
        channel: capture,
        requestMicrophonePermission: () async => PermissionStatus.granted,
      );
      await source.start(sampleRate: 44100, captureAction: action);
      expect(capture.isRunning, isTrue);
      final oldFenceCount = native.calls
          .where((call) => call == 'fenceContext')
          .length;
      route.user.value = 'B';
      expect(capture.isRunning, isFalse);
      await route.owner.lastFenceForTest;
      expect(
        native.calls.where((call) => call == 'fenceContext').length,
        oldFenceCount + 1,
      );
      await source.dispose();
      await capture.dispose();
      await route.dispose();
    },
  );

  test('native context change on fresh preflight blocks permission', () async {
    final route = _RouteHarness(native);
    await route.ready();
    final action = route.owner.captureActionFor(route.route)!;
    ++native.context;
    ++native.revision;
    var permissions = 0;
    final capture = FakeAudioCaptureChannel();
    final source = AudioInputController(
      channel: capture,
      requestMicrophonePermission: () async {
        ++permissions;
        return PermissionStatus.granted;
      },
    );
    await source.start(sampleRate: 44100, captureAction: action);
    expect(permissions, 0);
    expect(capture.isRunning, isFalse);
    await source.dispose();
    await capture.dispose();
    // The harness native change did not pass through the lease's own fence.
    // Dispose's native fence still needs the adapter's fresh context.
    await route.dispose();
  });
}
