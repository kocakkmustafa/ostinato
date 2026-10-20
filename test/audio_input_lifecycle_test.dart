import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:motion_account/motion_account.dart';
import 'package:ostinato/app/audio/audio_capture_channel.dart';
import 'package:ostinato/app/audio/audio_input_controller.dart';
import 'package:ostinato/app/audio/audio_route_state.dart';
import 'package:ostinato/app/audio/native_audio_arbiter_channel.dart';
import 'package:ostinato/app/audio/practice_audio_lease.dart';
import 'package:ostinato/app/audio/practice_audio_root.dart';
import 'package:ostinato_audio/ostinato_audio.dart';
import 'package:permission_handler/permission_handler.dart';

import 'support/fake_practice_audio_port.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(resetAudioCaptureCoordinatorForTest);

  // Channel plumbing needs the real event queue; the PCM/deadline tests
  // below continue to use the widget fake clock.
  test(
    'raw EventChannel EOF is terminal once and preserves the reusable wrapper',
    () async {
      const method = MethodChannel('com.yulalab.ostinato/audio_capture');
      const events = MethodChannel('com.yulalab.ostinato/audio_capture/events');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final calls = <String>[];
      messenger.setMockMethodCallHandler(events, (call) async => null);
      messenger.setMockMethodCallHandler(method, (call) async {
        calls.add(call.method);
        if (call.method == 'ready') return true;
        if (call.method == 'closeState') {
          return <String, Object?>{
            'phase': 'clear',
            'attemptId': null,
            'attemptInFlight': false,
            'resourcesReleased': true,
            'requiresExplicitRetry': false,
          };
        }
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(method, null);
        messenger.setMockMethodCallHandler(events, null);
      });
      const claim = AudioCaptureContextClaim(
        ownerToken: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        engineGeneration: 1,
        contextGeneration: 0,
      );
      final channel = MethodChannelAudioCaptureChannel();
      final received = <RawAudioEvent>[];
      final sub = channel.events.listen(received.add);
      await channel.start(sampleRate: 44100, claim: claim);
      final firstAttempt = channel.attemptId;

      // A null platform message is EOF; a success envelope containing null
      // would instead be a malformed data event.
      messenger.handlePlatformMessage(events.name, null, (_) {});
      await pumpEventQueue();
      expect(received, hasLength(1));
      expect(
        (received.single as RawInterruptedEvent).reason,
        'capture_stream_ended',
      );
      expect(channel.attemptId, firstAttempt);
      await expectLater(
        channel.start(sampleRate: 44100, claim: claim),
        throwsA(isA<PlatformException>()),
      );
      expect(calls.where((call) => call == 'start'), hasLength(1));

      await channel.stop();
      await channel.start(sampleRate: 48000, claim: claim);
      expect(channel.attemptId, isNot(firstAttempt));
      messenger.handlePlatformMessage(
        events.name,
        const StandardMethodCodec().encodeSuccessEnvelope(<String, Object?>{
          'attemptId': channel.attemptId,
          'type': 'routeChanged',
          'route': 'ios:BuiltInMic',
        }),
        (_) {},
      );
      await pumpEventQueue();
      expect(received.last, isA<RawRouteChangedEvent>());
      await channel.stop();
      // A retired raw stream must not publish another terminal event.
      messenger.handlePlatformMessage(events.name, null, (_) {});
      await pumpEventQueue();
      expect(received.whereType<RawInterruptedEvent>(), hasLength(1));
      expect(calls.where((call) => call == 'stop'), hasLength(2));
      await sub.cancel();
    },
  );

  testWidgets(
    'event-stream EOF clears PCM and starts one ordinary close immediately',
    (tester) async {
      final channel = _CloseProbeChannel();
      final source = AudioInputController(
        channel: channel,
        pcmDeliveryTimeout: const Duration(milliseconds: 100),
        requestMicrophonePermission: () async => PermissionStatus.granted,
      );
      final states = <AudioSurfaceState>[];
      final sub = source.status.listen(states.add);
      try {
        await _settleLifecycleOperation(
          tester,
          source.start(sampleRate: 44100),
          stage: 'EOF source start',
        );
        channel._events.add(
          const RawAudioChunkEvent(
            samples: [.2, .2],
            sampleRate: 44100,
            tNativeUs: 0,
          ),
        );
        await tester.pump();
        expect(source.bufferedSampleCountForTest, 2);
        await tester.pump(const Duration(milliseconds: 99));
        final ended = channel._events.close();
        await tester.pump();
        await _settleLifecycleOperation(
          tester,
          ended,
          stage: 'EOF stream close receipt',
        );
        expect(
          states.whereType<AudioSetupFailed>().map((state) => state.reason),
          ['capture_stream_ended'],
        );
        expect(source.bufferedSampleCountForTest, 0);
        expect(channel.running, isFalse);
        expect(channel.stopCalls, 1);
        expect(channel.retryCalls, 0);
        await tester.pump(const Duration(milliseconds: 200));
        expect(channel.stopCalls, 1);
        expect(channel.startCalls, 1);
      } finally {
        await _settleLifecycleOperation(
          tester,
          sub.cancel(),
          stage: 'EOF status listener cancel',
        );
        await _settleLifecycleOperation(
          tester,
          source.dispose(),
          stage: 'EOF source dispose',
        );
        await _settleLifecycleOperation(
          tester,
          channel._events.close(),
          stage: 'EOF fake channel dispose',
        );
      }
    },
  );

  testWidgets(
    'known-route notices cannot extend the first missing-PCM deadline',
    (tester) async {
      final channel = _CloseProbeChannel();
      final source = AudioInputController(
        channel: channel,
        pcmDeliveryTimeout: const Duration(milliseconds: 100),
        requestMicrophonePermission: () async => PermissionStatus.granted,
      );
      final states = <AudioSurfaceState>[];
      final sub = source.status.listen(states.add);
      try {
        await _settleLifecycleOperation(
          tester,
          source.start(sampleRate: 44100),
          stage: 'known-route notices source start',
        );
        for (var notice = 0; notice < 3; notice++) {
          await tester.pump(const Duration(milliseconds: 30));
          channel._events.add(const RawRouteChangedEvent('ios:BuiltInMic'));
          await tester.pump();
        }
        expect(channel.running, isTrue);
        await tester.pump(const Duration(milliseconds: 11));
        expect(
          states.whereType<AudioSetupFailed>().map((state) => state.reason),
          ['capture_pcm_timeout'],
        );
        expect(channel.running, isFalse);
        expect(channel.stopCalls, 1);
        expect(channel.retryCalls, 0);
        expect(source.bufferedSampleCountForTest, 0);
        await tester.pump(const Duration(milliseconds: 200));
        expect(channel.startCalls, 1);
        expect(channel.stopCalls, 1);
      } finally {
        await _cleanupLifecycleOperations(tester, {
          'known-route notices status listener cancel': sub.cancel,
          'known-route notices source dispose': source.dispose,
          'known-route notices fake channel close': channel._events.close,
        });
      }
    },
  );

  testWidgets(
    'valid silent PCM keeps delivery alive until samples actually stop',
    (tester) async {
      final channel = _CloseProbeChannel();
      final source = AudioInputController(
        channel: channel,
        pcmDeliveryTimeout: const Duration(milliseconds: 100),
        requestMicrophonePermission: () async => PermissionStatus.granted,
      );
      final states = <AudioSurfaceState>[];
      final chunks = <AudioChunk>[];
      final sub = source.status.listen(states.add);
      final chunkSub = source.chunks.listen(chunks.add);
      try {
        await _settleLifecycleOperation(
          tester,
          source.start(sampleRate: 44100),
          stage: 'silent PCM source start',
        );
        for (var chunk = 0; chunk < 4; chunk++) {
          await tester.pump(const Duration(milliseconds: 90));
          channel._events.add(
            RawAudioChunkEvent(
              samples: List<double>.filled(4410, 0),
              sampleRate: 44100,
              tNativeUs: chunk * 100000,
            ),
          );
          await tester.pump();
          expect(channel.running, isTrue);
          expect(states.whereType<AudioSetupFailed>(), isEmpty);
        }
        expect(chunks, hasLength(4));
        expect(channel.stopCalls, 0);
        await tester.pump(const Duration(milliseconds: 99));
        expect(channel.running, isTrue);
        await tester.pump(const Duration(milliseconds: 1));
        expect(channel.running, isFalse);
        expect(channel.stopCalls, 1);
        expect(
          (states.last as AudioSetupFailed).reason,
          'capture_pcm_timeout',
        );
        expect(source.bufferedSampleCountForTest, 0);
      } finally {
        await _cleanupLifecycleOperations(tester, {
          'silent PCM chunk listener cancel': chunkSub.cancel,
          'silent PCM status listener cancel': sub.cancel,
          'silent PCM source dispose': source.dispose,
          'silent PCM fake channel close': channel._events.close,
        });
      }
    },
  );

  testWidgets('PCM deadline begins only after native start settles', (
    tester,
  ) async {
    final startGate = Completer<void>();
    final channel = _CloseProbeChannel(startGate: startGate.future);
    final source = AudioInputController(
      channel: channel,
      pcmDeliveryTimeout: const Duration(milliseconds: 100),
      requestMicrophonePermission: () async => PermissionStatus.granted,
    );
    final states = <AudioSurfaceState>[];
    final sub = source.status.listen(states.add);
    final opening = source.start(sampleRate: 44100);
    try {
      await tester.pump();
      expect(channel.startCalls, 1);
      await tester.pump(const Duration(milliseconds: 200));
      expect(channel.stopCalls, 0);
      expect(states.whereType<AudioSetupFailed>(), isEmpty);
      startGate.complete();
      await tester.pump();
      await _settleLifecycleOperation(
        tester,
        opening,
        stage: 'native-start gate receipt',
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        (states.last as AudioSetupFailed).reason,
        'capture_pcm_timeout',
      );
      expect(channel.stopCalls, 1);
    } finally {
      // This releases only the test gate, after all body assertions (or failure).
      if (!startGate.isCompleted) startGate.complete();
      await _cleanupLifecycleOperations(tester, {
        'native-start gate cleanup receipt': () => opening,
        'native-start gate status listener cancel': sub.cancel,
        'native-start gate source dispose': source.dispose,
        'native-start gate fake channel close': channel._events.close,
      });
    }
  });

  for (final dispose in [false, true]) {
    testWidgets(
      '${dispose ? 'dispose' : 'manual stop'} cancels the PCM delivery timer',
      (tester) async {
        final channel = _CloseProbeChannel();
        final source = AudioInputController(
          channel: channel,
          pcmDeliveryTimeout: const Duration(milliseconds: 100),
          requestMicrophonePermission: () async => PermissionStatus.granted,
        );
        final states = <AudioSurfaceState>[];
        final sub = source.status.listen(states.add);
        try {
          await _settleLifecycleOperation(
            tester,
            source.start(sampleRate: 44100),
            stage: 'cancel timer source start',
          );
          await tester.pump(const Duration(milliseconds: 50));
          if (dispose) {
            await _settleLifecycleOperation(
              tester,
              source.dispose(),
              stage: 'cancel timer active dispose',
            );
          } else {
            await _settleLifecycleOperation(
              tester,
              source.stop(),
              stage: 'cancel timer manual stop',
            );
          }
          await tester.pump(const Duration(milliseconds: 200));
          expect(states.whereType<AudioSetupFailed>(), isEmpty);
          expect(channel.running, isFalse);
          expect(channel.stopCalls, 1);
          expect(channel.startCalls, 1);
        } finally {
          await _cleanupLifecycleOperations(tester, {
            'cancel timer status listener cancel': sub.cancel,
            'cancel timer source dispose': source.dispose,
            'cancel timer fake channel close': channel._events.close,
          });
        }
      },
    );
  }

  testWidgets('a retired PCM deadline cannot terminate the next owner', (
    tester,
  ) async {
    final firstChannel = _CloseProbeChannel();
    final nextChannel = _CloseProbeChannel();
    AudioInputController source(_CloseProbeChannel channel) =>
        AudioInputController(
          channel: channel,
          pcmDeliveryTimeout: const Duration(milliseconds: 100),
          requestMicrophonePermission: () async => PermissionStatus.granted,
        );
    final first = source(firstChannel);
    final next = source(nextChannel);
    final nextStates = <AudioSurfaceState>[];
    final sub = next.status.listen(nextStates.add);
    try {
      await _settleLifecycleOperation(
        tester,
        first.start(sampleRate: 44100),
        stage: 'retired first start',
      );
      await tester.pump(const Duration(milliseconds: 90));
      await _settleLifecycleOperation(
        tester,
        next.start(sampleRate: 44100),
        stage: 'retired next start',
      );
      expect(firstChannel.stopCalls, 1);
      await tester.pump(const Duration(milliseconds: 20));
      expect(nextChannel.running, isTrue);
      expect(nextChannel.stopCalls, 0);
      expect(nextStates.whereType<AudioSetupFailed>(), isEmpty);
      await _settleLifecycleOperation(
        tester,
        first.dispose(),
        stage: 'retired first dispose',
      );
      await _settleLifecycleOperation(
        tester,
        next.dispose(),
        stage: 'retired next dispose',
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(nextStates.whereType<AudioSetupFailed>(), isEmpty);
      expect(nextChannel.startCalls, 1);
      expect(nextChannel.stopCalls, 1);
    } finally {
      await _cleanupLifecycleOperations(tester, {
        'retired status listener cancel': sub.cancel,
        'retired first source cleanup': first.dispose,
        'retired next source cleanup': next.dispose,
        'retired first fake channel close': firstChannel._events.close,
        'retired next fake channel close': nextChannel._events.close,
      });
    }
  });

  test(
    'iOS built-in enum tag and raw port alias both identify built-in input',
    () {
      expect(mapPlatformRouteTag('ios:BuiltInMic'), AudioRoute.speaker);
      expect(mapPlatformRouteTag('ios:MicrophoneBuiltIn'), AudioRoute.speaker);
    },
  );
  test(
    'stop cancels a permission request that returns after route exit',
    () async {
      final permission = Completer<PermissionStatus>();
      final channel = FakeAudioCaptureChannel();
      final source = AudioInputController(
        channel: channel,
        requestMicrophonePermission: () => permission.future,
      );
      final pending = source.start(sampleRate: 44100);
      await pumpEventQueue();
      await source.stop();
      permission.complete(PermissionStatus.granted);
      await pending;
      expect(channel.isRunning, isFalse);
      expect(source.bufferedSampleCountForTest, 0);
      await source.dispose();
    },
  );

  test(
    'dispose stops capture and clears RAM without a separate stop call',
    () async {
      final channel = FakeAudioCaptureChannel();
      final source = AudioInputController(
        channel: channel,
        requestMicrophonePermission: () async => PermissionStatus.granted,
      );
      await source.start(sampleRate: 44100);
      channel.pushChunk(List.filled(100, .2), sampleRate: 44100, tNativeUs: 0);
      await pumpEventQueue();
      await source.dispose();
      expect(channel.isRunning, isFalse);
      expect(source.bufferedSampleCountForTest, 0);
    },
  );

  test(
    'late native start after stop is closed and cannot publish samples',
    () async {
      final channel = _DelayedStartChannel();
      final source = AudioInputController(
        channel: channel,
        requestMicrophonePermission: () async => PermissionStatus.granted,
      );
      final chunks = <AudioChunk>[];
      final sub = source.chunks.listen(chunks.add);
      final start = source.start(sampleRate: 44100);
      await pumpEventQueue();
      final stop = source.stop();
      channel.startCompleted.complete();
      await start;
      await expectLater(stop, throwsA(isA<PlatformException>()));
      channel.sendChunk();
      await pumpEventQueue();
      expect(channel.running, isFalse);
      expect(chunks, isEmpty);
      await source.retryClose();
      await sub.cancel();
      await source.dispose();
    },
  );

  test(
    'new owner waits for explicit close retry after an old pending start',
    () async {
      final channel = _DelayedStartChannel();
      final a = AudioInputController(
        channel: channel,
        requestMicrophonePermission: () async => PermissionStatus.granted,
      );
      final b = AudioInputController(
        channel: channel,
        requestMicrophonePermission: () async => PermissionStatus.granted,
      );
      final startA = a.start(sampleRate: 44100);
      await pumpEventQueue();
      final stopA = a.stop();
      final startB = b.start(sampleRate: 44100);
      await pumpEventQueue();
      channel.startCompleted.complete();
      await startA;
      await expectLater(stopA, throwsA(isA<PlatformException>()));
      await startB;
      expect(channel.running, isFalse);
      await a.retryClose();
      await b.start(sampleRate: 44100);
      expect(channel.running, isTrue);
      await a.dispose();
      expect(channel.running, isTrue);
      await b.dispose();
      expect(channel.running, isFalse);
    },
  );

  test(
    'sample rate changes clear the old ring and request recalibration',
    () async {
      final channel = FakeAudioCaptureChannel();
      final source = AudioInputController(
        channel: channel,
        requestMicrophonePermission: () async => PermissionStatus.granted,
      );
      final states = <AudioSurfaceState>[];
      final sub = source.status.listen(states.add);
      await source.start(sampleRate: 44100);
      channel.pushChunk(List.filled(100, .2), sampleRate: 44100, tNativeUs: 0);
      await pumpEventQueue();
      channel.pushChunk(
        List.filled(50, .2),
        sampleRate: 48000,
        tNativeUs: 2500,
      );
      await pumpEventQueue();
      expect(source.bufferedSampleCountForTest, 50);
      expect(states.last, isA<AudioCalibrating>());
      await sub.cancel();
      await source.dispose();
    },
  );

  test('invalid PCM refuses the stream and clears prior samples', () async {
    final channel = FakeAudioCaptureChannel();
    final source = AudioInputController(
      channel: channel,
      requestMicrophonePermission: () async => PermissionStatus.granted,
    );
    await source.start(sampleRate: 44100);
    channel.pushChunk([.2, double.nan], sampleRate: 44100, tNativeUs: 0);
    await pumpEventQueue();
    expect(channel.isRunning, isFalse);
    expect(source.bufferedSampleCountForTest, 0);
    await source.dispose();
  });
  test(
    'stop during event readiness never opens native capture afterward',
    () async {
      final channel = _DelayedReadyChannel();
      final source = AudioInputController(
        channel: channel,
        requestMicrophonePermission: () async => PermissionStatus.granted,
      );
      final start = source.start(sampleRate: 44100);
      await pumpEventQueue();
      final stop = source.stop();
      channel.ready.complete();
      await start;
      await expectLater(stop, throwsA(isA<PlatformException>()));
      expect(channel.startCount, 0);
      await source.retryClose();
      await source.dispose();
    },
  );
  test(
    'same source restart cannot be closed by a delayed old subscription',
    () async {
      final channel = _SlowCancelChannel();
      final source = AudioInputController(
        channel: channel,
        requestMicrophonePermission: () async => PermissionStatus.granted,
      );
      await source.start(sampleRate: 44100);
      final close = source.stop();
      final restart = source.start(sampleRate: 44100);
      await pumpEventQueue();
      channel.cancellation.complete();
      await Future.wait([close, restart]);
      expect(channel.isRunning, isFalse);
      await source.start(sampleRate: 44100);
      expect(channel.isRunning, isTrue);
      await source.dispose();
    },
  );
  test(
    'foreground loss closes source and resume never restarts capture',
    () async {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final channel = FakeAudioCaptureChannel();
      final source = AudioInputController(
        channel: channel,
        requestMicrophonePermission: () async => PermissionStatus.granted,
      );
      final statuses = <AudioSurfaceState>[];
      final sub = source.status.listen(statuses.add);
      await source.start(sampleRate: 44100);
      await pumpEventQueue();
      channel.pushChunk(List.filled(100, .2), sampleRate: 44100, tNativeUs: 0);
      await pumpEventQueue();
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await pumpEventQueue();
      expect(channel.isRunning, isFalse);
      expect(source.bufferedSampleCountForTest, 0);
      expect(statuses.last, isA<AudioStopped>());
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await pumpEventQueue();
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await pumpEventQueue();
      expect(channel.isRunning, isFalse);
      await sub.cancel();
      await source.dispose();
    },
  );

  test(
    'hung native start sends direct stop and blocks another owner',
    () async {
      final gate = Completer<void>();
      final channel = _CloseProbeChannel(startGate: gate.future);
      final a = AudioInputController(
        channel: channel,
        nativeCallTimeout: const Duration(milliseconds: 25),
        requestMicrophonePermission: () async => PermissionStatus.granted,
      );
      final bChannel = _CloseProbeChannel();
      final b = AudioInputController(
        channel: bChannel,
        nativeCallTimeout: const Duration(milliseconds: 25),
        requestMicrophonePermission: () async => PermissionStatus.granted,
      );
      final statuses = <AudioSurfaceState>[];
      final sub = a.status.listen(statuses.add);
      final opening = a.start(sampleRate: 44100);
      await pumpEventQueue();
      expect(channel.startCalls, 1);
      final close = a.stop();
      await expectLater(close, throwsA(isA<PlatformException>()));
      expect(channel.stopCalls, 1);
      expect(statuses.whereType<AudioStopped>(), isEmpty);
      await b.start(sampleRate: 44100);
      expect(bChannel.startCalls, 0);
      gate.complete();
      await opening;
      await pumpEventQueue();
      expect(channel.stopCalls, greaterThanOrEqualTo(2));
      expect(channel.running, isFalse);
      await a.refreshCloseState();
      expect(a.captureNeedsExplicitRetry, isTrue);
      await a.retryClose();
      await b.start(sampleRate: 44100);
      expect(bChannel.running, isTrue);
      await sub.cancel();
      await a.dispose();
      await b.dispose();
    },
  );

  test('hung prepare sends a tombstone before any start dispatch', () async {
    final gate = Completer<void>();
    final channel = _CloseProbeChannel(prepareGate: gate.future);
    final source = AudioInputController(
      channel: channel,
      nativeCallTimeout: const Duration(milliseconds: 25),
      requestMicrophonePermission: () async => PermissionStatus.granted,
    );
    final opening = source.start(sampleRate: 44100);
    await pumpEventQueue();
    final close = source.stop();
    await expectLater(close, throwsA(isA<PlatformException>()));
    expect(channel.stopCalls, 1);
    expect(channel.startCalls, 0);
    gate.complete();
    await opening;
    await pumpEventQueue();
    expect(channel.startCalls, 0);
    await source.retryClose();
    await source.dispose();
  });

  test('failed close survives disposal and needs explicit retry', () async {
    final channel = _CloseProbeChannel()..failStop = true;
    final a = AudioInputController(
      channel: channel,
      requestMicrophonePermission: () async => PermissionStatus.granted,
    );
    await a.start(sampleRate: 44100);
    final statuses = <AudioSurfaceState>[];
    final sub = a.status.listen(statuses.add);
    await expectLater(a.stop(), throwsA(isA<PlatformException>()));
    expect(statuses.whereType<AudioStopped>(), isEmpty);
    await sub.cancel();
    await a.dispose();
    final b = AudioInputController(
      channel: _CloseProbeChannel(),
      requestMicrophonePermission: () async => PermissionStatus.granted,
    );
    await b.refreshCloseState();
    expect(b.captureGateReady, isFalse);
    expect(b.captureNeedsExplicitRetry, isTrue);
    await b.start(sampleRate: 44100);
    expect(channel.stopCalls, 1);
    channel.failStop = false;
    await b.retryClose();
    expect(b.captureGateReady, isTrue);
    await b.start(sampleRate: 44100);
    await b.dispose();
  });

  test('lost stop reply remains latched after late cleanup', () async {
    final gate = Completer<void>();
    final channel = _CloseProbeChannel(stopGate: gate.future);
    final source = AudioInputController(
      channel: channel,
      nativeCallTimeout: const Duration(milliseconds: 25),
      requestMicrophonePermission: () async => PermissionStatus.granted,
    );
    final statuses = <AudioSurfaceState>[];
    final sub = source.status.listen(statuses.add);
    await source.start(sampleRate: 44100);
    await expectLater(source.stop(), throwsA(isA<PlatformException>()));
    expect(statuses.whereType<AudioStopped>(), isEmpty);
    gate.complete();
    await pumpEventQueue();
    await source.refreshCloseState();
    expect(source.captureGateReady, isFalse);
    expect(source.captureNeedsExplicitRetry, isTrue);
    await source.retryClose();
    expect(source.captureGateReady, isTrue);
    await sub.cancel();
    await source.dispose();
  });

  test('background close failure never emits AudioStopped', () async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final channel = _CloseProbeChannel();
    final source = AudioInputController(
      channel: channel,
      requestMicrophonePermission: () async => PermissionStatus.granted,
    );
    final statuses = <AudioSurfaceState>[];
    final sub = source.status.listen(statuses.add);
    await source.start(sampleRate: 44100);
    channel.failStop = true;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await pumpEventQueue();
    expect(statuses.whereType<AudioStopped>(), isEmpty);
    expect(statuses.last, isA<AudioSetupFailed>());
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(channel.startCalls, 1);
    channel.failStop = false;
    await source.retryClose();
    await sub.cancel();
    await source.dispose();
  });

  test('stalled local stream cancel cannot delay native stop', () async {
    final channel = _SlowCancelChannel();
    final source = AudioInputController(
      channel: channel,
      nativeCallTimeout: const Duration(milliseconds: 25),
      requestMicrophonePermission: () async => PermissionStatus.granted,
    );
    final statuses = <AudioSurfaceState>[];
    final sub = source.status.listen(statuses.add);
    await source.start(sampleRate: 44100);
    final close = source.stop();
    await pumpEventQueue();
    expect(channel.isRunning, isFalse);
    await expectLater(close, throwsA(isA<PlatformException>()));
    expect(statuses.whereType<AudioStopped>(), isEmpty);
    channel.cancellation.complete();
    await source.retryClose();
    await sub.cancel();
    await source.dispose();
  });

  test('late native start error cannot clear the close latch', () async {
    final gate = Completer<void>();
    final channel = _CloseProbeChannel(startGate: gate.future);
    final source = AudioInputController(
      channel: channel,
      nativeCallTimeout: const Duration(milliseconds: 25),
      requestMicrophonePermission: () async => PermissionStatus.granted,
    );
    final opening = source.start(sampleRate: 44100);
    await pumpEventQueue();
    await expectLater(source.stop(), throwsA(isA<PlatformException>()));
    gate.completeError(StateError('late native error'));
    await opening;
    await pumpEventQueue();
    expect(source.captureGateReady, isFalse);
    await source.refreshCloseState();
    expect(source.captureNeedsExplicitRetry, isTrue);
    await source.retryClose();
    await source.dispose();
  });

  test('capture channel without close readback cannot open', () async {
    final channel = _UnknownCloseChannel();
    final source = AudioInputController(
      channel: channel,
      requestMicrophonePermission: () async => PermissionStatus.granted,
    );
    await source.start(sampleRate: 44100);
    expect(channel.startCalls, 0);
    expect(source.captureGateReady, isFalse);
    await source.dispose();
  });

  test(
    'new controller closes a released attempt before a separate start',
    () async {
      final channel = _CloseProbeChannel()
        ..attemptId = 'retained-attempt'
        ..state = const AudioCaptureCloseState(
          phase: AudioCaptureClosePhase.releasedAwaitingExplicitRetry,
          attemptId: 'retained-attempt',
          attemptInFlight: false,
          resourcesReleased: true,
          requiresExplicitRetry: true,
        );
      final source = AudioInputController(
        channel: channel,
        requestMicrophonePermission: () async => PermissionStatus.granted,
      );
      await source.refreshCloseState();
      expect(source.captureGateReady, isFalse);
      expect(source.captureNeedsExplicitRetry, isTrue);
      await source.start(sampleRate: 44100);
      expect(channel.startCalls, 0);
      await source.retryClose();
      expect(channel.stopCalls, 1);
      expect(channel.retryCalls, 1);
      expect(channel.startCalls, 0);
      expect(source.captureGateReady, isTrue);
      await source.start(sampleRate: 44100);
      expect(channel.startCalls, 1);
      await source.dispose();
    },
  );

  test('in-flight attempt rejects retry without another stop', () async {
    final channel = _CloseProbeChannel()
      ..attemptId = 'busy-attempt'
      ..state = const AudioCaptureCloseState(
        phase: AudioCaptureClosePhase.unconfirmedInFlight,
        attemptId: 'busy-attempt',
        attemptInFlight: true,
        resourcesReleased: false,
        requiresExplicitRetry: false,
      );
    final source = AudioInputController(
      channel: channel,
      requestMicrophonePermission: () async => PermissionStatus.granted,
    );
    await source.refreshCloseState();
    await expectLater(
      source.retryClose(),
      throwsA(
        isA<PlatformException>().having(
          (error) => error.code,
          'code',
          'capture_close_in_flight',
        ),
      ),
    );
    expect(channel.stopCalls, 0);
    expect(source.captureGateReady, isFalse);
    await source.dispose();
  });

  test('late ordinary stop cannot acknowledge a released attempt', () async {
    final channel = _CloseProbeChannel()
      ..attemptId = 'sticky-attempt'
      ..stickyNormalStop = true
      ..state = const AudioCaptureCloseState(
        phase: AudioCaptureClosePhase.releasedAwaitingExplicitRetry,
        attemptId: 'sticky-attempt',
        attemptInFlight: false,
        resourcesReleased: true,
        requiresExplicitRetry: true,
      );
    final source = AudioInputController(
      channel: channel,
      requestMicrophonePermission: () async => PermissionStatus.granted,
    );
    await source.refreshCloseState();
    await expectLater(channel.stop(), throwsA(isA<PlatformException>()));
    expect(source.captureGateReady, isFalse);
    await source.retryClose();
    expect(channel.retryCalls, 1);
    expect(source.captureGateReady, isTrue);
    await source.dispose();
  });

  testWidgets(
    'active dispose does not leave a closeState timer when native stop replies',
    (tester) async {
      const method = MethodChannel('com.yulalab.ostinato/audio_capture');
      const events = MethodChannel('com.yulalab.ostinato/audio_capture/events');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final unanswered = Completer<Object?>();
      var statusReads = 0;
      var stopCalls = 0;
      messenger.setMockMethodCallHandler(events, (call) async => null);
      messenger.setMockMethodCallHandler(method, (call) {
        if (call.method == 'ready') return Future<Object?>.value(true);
        if (call.method == 'stop') stopCalls++;
        if (call.method == 'closeState') {
          statusReads++;
          if (statusReads > 1) return unanswered.future;
          return Future<Object?>.value({
            'phase': 'clear',
            'attemptId': null,
            'attemptInFlight': false,
            'resourcesReleased': true,
            'requiresExplicitRetry': false,
          });
        }
        return Future<Object?>.value(null);
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(method, null);
        messenger.setMockMethodCallHandler(events, null);
      });
      const arbiterMethod = MethodChannel('test/active_dispose_arbiter');
      const ownerToken = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      messenger.setMockMethodCallHandler(arbiterMethod, (call) async {
        if (call.method == 'bind') {
          return <String, Object?>{
            'schemaVersion': 1,
            'ownerToken': ownerToken,
            'engineGeneration': 1,
            'contextGeneration': 0,
            'stateRevision': 0,
          };
        }
        if (call.method == 'readAllAudioState') {
          return <String, Object?>{
            'schemaVersion': 1,
            'ownerToken': ownerToken,
            'engineGeneration': 1,
            'contextGeneration': 0,
            'stateRevision': 0,
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
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(arbiterMethod, null),
      );
      final arbiter = NativeAudioArbiterChannel(channel: arbiterMethod);
      await _settleLifecycleOperation(
        tester,
        arbiter.readAllAudioState().then<void>((_) {}),
        stage: 'active dispose arbiter read',
      );
      final user = ValueNotifier<String?>('A');
      final phase = ValueNotifier(MotionIdentityPhase.verified);
      final owner = PracticeAudioRootOwner(
        userId: user,
        phase: phase,
        lease: PracticeAudioLease(port: FakePracticeAudioPort()),
        captureArbiter: arbiter,
        initialLifecycleState: AppLifecycleState.resumed,
        allowDetachedRouteEventsForTest: true,
        nativeFenceEnabled: false,
      );
      final observer = PracticeAudioRouteObserver(owner);
      final route = MaterialPageRoute<void>(builder: (_) => const SizedBox());
      owner.attachNavigator(observer);
      observer.didPush(route, null);
      final source = AudioInputController(
        channel: MethodChannelAudioCaptureChannel(),
        requestMicrophonePermission: () async => PermissionStatus.granted,
      );
      var ownerDisposed = false;
      var notifiersDisposed = false;
      try {
        await _settleLifecycleOperation(
          tester,
          owner.lastFenceForTest?.then<void>((_) {}) ?? Future<void>.value(),
          stage: 'active dispose initial owner fence',
        );
        final action = owner.captureActionFor(route)!;
        await _settleLifecycleOperation(
          tester,
          source.start(sampleRate: 44100, captureAction: action),
          stage: 'active dispose source start',
        );
        await _settleLifecycleOperation(
          tester,
          source.dispose(),
          stage: 'active dispose source dispose',
        );
        owner.dispose();
        ownerDisposed = true;
        await _settleLifecycleOperation(
          tester,
          owner.lastFenceForTest?.then<void>((_) {}) ?? Future<void>.value(),
          stage: 'active dispose owner fence',
        );
        user.dispose();
        phase.dispose();
        notifiersDisposed = true;
        await tester.pump();
        expect(stopCalls, 1);
        expect(source.captureGateReady, isFalse);
        expect(source.captureNeedsExplicitRetry, isFalse);
        // The platform reply remains unanswered. A disposed route must not
        // retain a Dart timer or turn this into a confirmed close.
      } finally {
        try {
          await _cleanupLifecycleOperations(tester, {
            'active dispose source cleanup': source.dispose,
            'active dispose owner cleanup': () async {
              if (!ownerDisposed) {
                owner.dispose();
                ownerDisposed = true;
              }
            },
            'active dispose owner final fence': () async {
              await owner.lastFenceForTest;
            },
          });
        } finally {
          if (!notifiersDisposed) {
            user.dispose();
            phase.dispose();
          }
        }
      }
    },
  );

  test('missing attempt ID cannot be acknowledged by an empty retry', () async {
    final channel = _NullIdChannel();
    final source = AudioInputController(
      channel: channel,
      requestMicrophonePermission: () async => PermissionStatus.granted,
    );
    await source.start(sampleRate: 44100);
    await expectLater(source.stop(), throwsA(isA<PlatformException>()));
    expect(channel.stopCalls, 1);
    await expectLater(source.retryClose(), throwsA(isA<PlatformException>()));
    expect(source.captureGateReady, isFalse);
    await source.dispose();
  });

  test(
    'new B channel retries retained A ID without calling retired A',
    () async {
      final native = _SharedCloseNative();
      final aChannel = _SharedCloseChannel(native, 'a' * 32)
        ..failNormalStop = true;
      final a = AudioInputController(
        channel: aChannel,
        requestMicrophonePermission: () async => PermissionStatus.granted,
      );
      await a.start(sampleRate: 44100);
      await expectLater(a.stop(), throwsA(isA<PlatformException>()));
      await a.dispose();
      aChannel.retired = true;

      final bChannel = _SharedCloseChannel(native, 'b' * 32);
      final b = AudioInputController(
        channel: bChannel,
        requestMicrophonePermission: () async => PermissionStatus.granted,
      );
      await b.refreshCloseState();
      expect(b.captureNeedsExplicitRetry, isTrue);
      await b.start(sampleRate: 44100);
      expect(bChannel.startCalls, 0);
      await b.retryClose();
      expect(aChannel.retryIds, isEmpty);
      expect(bChannel.retryIds, ['a' * 32]);
      expect(bChannel.reads, greaterThanOrEqualTo(3));
      expect(bChannel.startCalls, 0);
      expect(b.captureGateReady, isTrue);
      await b.start(sampleRate: 44100);
      expect(bChannel.startCalls, 1);
      await b.dispose();
    },
  );

  test('B rejects wrong, unknown, and in-flight native IDs', () async {
    final native = _SharedCloseNative();
    final aChannel = _SharedCloseChannel(native, 'a' * 32)
      ..failNormalStop = true;
    final a = AudioInputController(
      channel: aChannel,
      requestMicrophonePermission: () async => PermissionStatus.granted,
    );
    await a.start(sampleRate: 44100);
    await expectLater(a.stop(), throwsA(isA<PlatformException>()));
    await a.dispose();
    aChannel.retired = true;
    final bChannel = _SharedCloseChannel(native, 'b' * 32);
    final b = AudioInputController(
      channel: bChannel,
      requestMicrophonePermission: () async => PermissionStatus.granted,
    );
    final forbidden = <AudioCaptureCloseState>[
      const AudioCaptureCloseState.unknown(),
      AudioCaptureCloseState(
        phase: AudioCaptureClosePhase.running,
        attemptId: 'b' * 32,
        attemptInFlight: false,
        resourcesReleased: false,
        requiresExplicitRetry: false,
      ),
      AudioCaptureCloseState(
        phase: AudioCaptureClosePhase.unconfirmedInFlight,
        attemptId: 'a' * 32,
        attemptInFlight: true,
        resourcesReleased: false,
        requiresExplicitRetry: false,
      ),
    ];
    for (final state in forbidden) {
      native.state = state;
      await b.refreshCloseState();
      expect(b.captureNeedsExplicitRetry, isFalse);
      await expectLater(b.retryClose(), throwsA(isA<PlatformException>()));
      expect(bChannel.retryIds, isEmpty);
      expect(b.captureGateReady, isFalse);
    }
    native.state = _SharedCloseNative.quiescentA;
    bChannel.reportedAttemptId = 'b' * 32;
    await expectLater(b.retryClose(), throwsA(isA<PlatformException>()));
    expect(bChannel.retryIds, isEmpty);
    bChannel.reportedAttemptId = null;
    await b.retryClose();
    expect(bChannel.retryIds, ['a' * 32]);
    expect(bChannel.startCalls, 0);
    await b.dispose();
  });

  test(
    'B clear tombstone still needs A-ID retry and a clear post-readback',
    () async {
      final native = _SharedCloseNative();
      final aChannel = _SharedCloseChannel(native, 'a' * 32)
        ..failNormalStop = true;
      final a = AudioInputController(
        channel: aChannel,
        requestMicrophonePermission: () async => PermissionStatus.granted,
      );
      await a.start(sampleRate: 44100);
      await expectLater(a.stop(), throwsA(isA<PlatformException>()));
      await a.dispose();
      aChannel.retired = true;
      native.state = const AudioCaptureCloseState.clear();
      final bChannel = _SharedCloseChannel(native, 'b' * 32)
        ..stateAfterRetry = const AudioCaptureCloseState.unknown();
      final b = AudioInputController(
        channel: bChannel,
        requestMicrophonePermission: () async => PermissionStatus.granted,
      );
      await b.refreshCloseState();
      expect(b.captureNeedsExplicitRetry, isTrue);
      await expectLater(b.retryClose(), throwsA(isA<PlatformException>()));
      expect(bChannel.retryIds, ['a' * 32]);
      expect(b.captureGateReady, isFalse);
      expect(bChannel.startCalls, 0);
      bChannel.stateAfterRetry = null;
      native.state = const AudioCaptureCloseState.clear();
      await b.retryClose();
      expect(bChannel.retryIds, ['a' * 32, 'a' * 32]);
      expect(b.captureGateReady, isTrue);
      expect(bChannel.startCalls, 0);
      await b.dispose();
    },
  );

  test(
    'fresh B isolate remembers sticky A through native clear until visible retry',
    () async {
      final native = _SharedCloseNative()
        ..state = _SharedCloseNative.quiescentA
        ..tombstones.add('a' * 32);
      final bChannel = _SharedCloseChannel(native, 'b' * 32);
      final b = AudioInputController(
        channel: bChannel,
        requestMicrophonePermission: () async => PermissionStatus.granted,
      );
      await b.refreshCloseState();
      expect(b.captureNeedsExplicitRetry, isTrue);
      native.state = const AudioCaptureCloseState.clear();
      await b.refreshCloseState();
      expect(b.captureGateReady, isFalse);
      expect(b.captureNeedsExplicitRetry, isTrue);
      expect(bChannel.startCalls, 0);
      await b.retryClose(); // The user tapped; no background refresh may ack.
      expect(bChannel.retryIds, ['a' * 32]);
      expect(b.captureGateReady, isTrue);
      expect(bChannel.startCalls, 0); // Starting is a separate user choice.
      await b.dispose();
    },
  );

  test(
    'B disposal cannot lose sticky A acknowledgement before fresh C retry',
    () async {
      final native = _SharedCloseNative()
        ..state = _SharedCloseNative.quiescentA
        ..tombstones.add('a' * 32);
      final bChannel = _SharedCloseChannel(native, 'b' * 32);
      final b = AudioInputController(
        channel: bChannel,
        requestMicrophonePermission: () async => PermissionStatus.granted,
      );
      await b.refreshCloseState();
      expect(b.captureNeedsExplicitRetry, isTrue);
      native.state = const AudioCaptureCloseState.clear();
      await b.refreshCloseState();
      expect(b.captureGateReady, isFalse);
      await b.dispose();
      bChannel.retired = true;

      final cChannel = _SharedCloseChannel(native, 'c' * 32);
      final c = AudioInputController(
        channel: cChannel,
        requestMicrophonePermission: () async => PermissionStatus.granted,
      );
      await c.refreshCloseState();
      expect(c.captureGateReady, isFalse);
      expect(c.captureNeedsExplicitRetry, isTrue);
      await c.start(sampleRate: 44100);
      expect(cChannel.startCalls, 0);
      await c.retryClose(); // The visible action uses C's current transport.
      expect(cChannel.retryIds, ['a' * 32]);
      expect(bChannel.retryIds, isEmpty);
      expect(c.captureGateReady, isTrue);
      await c.start(sampleRate: 44100);
      expect(cChannel.startCalls, 1);
      await c.dispose();
    },
  );

  test(
    'new Dart coordinator still reads process-native sticky A after B retires',
    () async {
      final native = _SharedCloseNative()
        ..state = _SharedCloseNative.quiescentA
        ..tombstones.add('a' * 32);
      final bChannel = _SharedCloseChannel(native, 'b' * 32);
      final b = AudioInputController(
        channel: bChannel,
        requestMicrophonePermission: () async => PermissionStatus.granted,
      );
      await b.refreshCloseState();
      expect(b.captureNeedsExplicitRetry, isTrue);
      await b.dispose();
      bChannel.retired = true;

      // A replacement Dart isolate loses its static latch. Native state must
      // remain sticky and carry A's exact ID into the replacement controller.
      resetAudioCaptureCoordinatorForTest();
      expect(native.state.attemptId, 'a' * 32);
      expect(native.state.requiresExplicitRetry, isTrue);
      final cChannel = _SharedCloseChannel(native, 'c' * 32);
      final c = AudioInputController(
        channel: cChannel,
        requestMicrophonePermission: () async => PermissionStatus.granted,
      );
      await c.refreshCloseState();
      expect(c.captureGateReady, isFalse);
      expect(c.captureNeedsExplicitRetry, isTrue);
      await c.start(sampleRate: 44100);
      expect(cChannel.startCalls, 0);
      await c.retryClose();
      expect(cChannel.retryIds, ['a' * 32]);
      expect(bChannel.retryIds, isEmpty);
      expect(c.captureGateReady, isTrue);
      expect(cChannel.startCalls, 0); // Retrying close never auto-starts.
      await c.start(sampleRate: 44100);
      expect(cChannel.startCalls, 1);
      await c.dispose();
    },
  );

  test('fresh B never offers close retry for foreign running A', () async {
    final native = _SharedCloseNative()
      ..state = AudioCaptureCloseState(
        phase: AudioCaptureClosePhase.running,
        attemptId: 'a' * 32,
        attemptInFlight: false,
        resourcesReleased: false,
        requiresExplicitRetry: false,
      );
    final bChannel = _SharedCloseChannel(native, 'b' * 32);
    final b = AudioInputController(
      channel: bChannel,
      requestMicrophonePermission: () async => PermissionStatus.granted,
    );
    await b.refreshCloseState();
    expect(b.captureGateReady, isFalse);
    expect(b.captureNeedsExplicitRetry, isFalse);
    await expectLater(b.retryClose(), throwsA(isA<PlatformException>()));
    expect(bChannel.retryIds, isEmpty);
    expect(bChannel.startCalls, 0);
    await b.dispose();
  });

  test(
    'never-settled A start permits only fresh B readback and explicit retry',
    () async {
      final native = _SharedCloseNative();
      final hungStart = Completer<void>();
      final aChannel = _SharedCloseChannel(
        native,
        'a' * 32,
        startGate: hungStart.future,
      );
      final a = AudioInputController(
        channel: aChannel,
        nativeCallTimeout: const Duration(milliseconds: 25),
        requestMicrophonePermission: () async => PermissionStatus.granted,
      );
      final opening = a.start(sampleRate: 44100);
      await pumpEventQueue();
      expect(aChannel.startCalls, 1);
      await expectLater(a.stop(), throwsA(isA<PlatformException>()));
      await opening; // Dart's deadline settles, but the raw native Future does not.
      await a.dispose();
      aChannel.retired = true;

      final bChannel = _SharedCloseChannel(native, 'b' * 32);
      final b = AudioInputController(
        channel: bChannel,
        requestMicrophonePermission: () async => PermissionStatus.granted,
      );
      expect(b.captureNeedsExplicitRetry, isFalse);
      await b.refreshCloseState();
      expect(b.captureNeedsExplicitRetry, isTrue);
      expect(b.captureClosePending, isFalse);
      await b.retryClose();
      expect(bChannel.retryIds, ['a' * 32]);
      expect(aChannel.retryIds, isEmpty);
      expect(bChannel.startCalls, 0);
      expect(b.captureGateReady, isTrue);
      hungStart.complete();
      await pumpEventQueue();
      expect(b.captureGateReady, isTrue);
      expect(bChannel.startCalls, 0);
      await b.start(sampleRate: 44100);
      expect(bChannel.startCalls, 1);
      await b.dispose();
    },
  );
}

/// Drain the widget fake-clock microtasks while observing real queue turns.
/// This never advances the PCM clock: the exact 99/200 ms steps stay in the
/// test body. An unresolved operation names its stage instead of hanging the
/// entire suite until the outer process timeout.
Future<void> _settleLifecycleOperation(
  WidgetTester tester,
  Future<void> operation, {
  required String stage,
}) async {
  debugPrint('audio-fixture begin: $stage');
  var completed = false;
  Object? failure;
  StackTrace? failureStack;
  unawaited(
    operation.then<void>(
      (_) {
        completed = true;
      },
      onError: (Object error, StackTrace stack) {
        failure = error;
        failureStack = stack;
        completed = true;
      },
    ),
  );
  for (var turn = 0; turn < 100 && !completed; turn++) {
    await tester.pump();
    if (!completed) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 1)),
      );
    }
  }
  expect(
    completed,
    isTrue,
    reason: '$stage did not settle in 100 event turns',
  );
  debugPrint('audio-fixture settled: $stage');
  if (failure != null) Error.throwWithStackTrace(failure!, failureStack!);
}

/// Try every fixture cleanup, retain the first failure, and rethrow it.
/// This does not consume FlutterError or framework exceptions.
Future<void> _cleanupLifecycleOperations(
  WidgetTester tester,
  Map<String, Future<void> Function()> operations,
) async {
  Object? firstFailure;
  StackTrace? firstStack;
  for (final operation in operations.entries) {
    try {
      await _settleLifecycleOperation(
        tester,
        Future<void>.sync(operation.value),
        stage: operation.key,
      );
    } on Object catch (error, stack) {
      firstFailure ??= error;
      firstStack ??= stack;
      debugPrint('audio-fixture cleanup failed: ${operation.key}: $error');
    }
  }
  if (firstFailure != null) {
    Error.throwWithStackTrace(firstFailure, firstStack!);
  }
}

final class _SharedCloseNative {
  static final quiescentA = AudioCaptureCloseState(
    phase: AudioCaptureClosePhase.unconfirmedQuiescent,
    attemptId: 'a' * 32,
    attemptInFlight: false,
    resourcesReleased: false,
    requiresExplicitRetry: true,
  );
  AudioCaptureCloseState state = const AudioCaptureCloseState.clear();
  final tombstones = <String>{};
}

final class _SharedCloseChannel
    implements AudioCaptureChannel, AudioCaptureCloseControl {
  _SharedCloseChannel(this.native, this.id, {this.startGate});
  final _SharedCloseNative native;
  final String id;
  final Future<void>? startGate;
  bool retired = false;
  bool failNormalStop = false;
  String? reportedAttemptId;
  AudioCaptureCloseState? stateAfterRetry;
  int reads = 0, startCalls = 0, stopCalls = 0;
  final retryIds = <String>[];
  final _events = StreamController<RawAudioEvent>.broadcast();
  @override
  String? get attemptId => reportedAttemptId ?? (startCalls > 0 ? id : null);
  @override
  Stream<RawAudioEvent> get events => _events.stream;
  @override
  Future<AudioCaptureCloseState> readCloseState() async {
    reads++;
    return native.state;
  }

  @override
  Future<void> start({required int sampleRate}) async {
    startCalls++;
    await startGate;
    if (native.tombstones.contains(id)) {
      throw PlatformException(code: 'capture_start_cancelled');
    }
    native.state = AudioCaptureCloseState(
      phase: AudioCaptureClosePhase.running,
      attemptId: id,
      attemptInFlight: false,
      resourcesReleased: false,
      requiresExplicitRetry: false,
    );
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    if (retired) throw PlatformException(code: 'capture_handler_retired');
    native.tombstones.add(id);
    if (failNormalStop) {
      native.state = _SharedCloseNative.quiescentA;
      throw PlatformException(code: 'capture_close_unconfirmed');
    }
    native.state = startGate == null
        ? const AudioCaptureCloseState.clear()
        : AudioCaptureCloseState(
            phase: AudioCaptureClosePhase.releasedAwaitingExplicitRetry,
            attemptId: id,
            attemptInFlight: false,
            resourcesReleased: true,
            requiresExplicitRetry: true,
          );
  }

  @override
  Future<void> stopAttempt(String attemptId) => stop();

  @override
  Future<void> retryStopAttempt(String attemptId) async {
    if (retired) throw PlatformException(code: 'capture_handler_retired');
    retryIds.add(attemptId);
    if (attemptId != 'a' * 32 || !native.tombstones.contains(attemptId)) {
      throw PlatformException(code: 'stale_capture_attempt');
    }
    final state = native.state;
    if (!state.isClear &&
        (state.attemptId != attemptId ||
            state.attemptInFlight ||
            !state.canRetry ||
            state.phase == AudioCaptureClosePhase.running)) {
      throw PlatformException(code: 'capture_close_unconfirmed');
    }
    native.state = stateAfterRetry ?? const AudioCaptureCloseState.clear();
  }
}

final class _UnknownCloseChannel implements AudioCaptureChannel {
  int startCalls = 0;
  @override
  Stream<RawAudioEvent> get events => const Stream.empty();
  @override
  Future<void> start({required int sampleRate}) async {
    startCalls++;
  }

  @override
  Future<void> stop() async {}
}

final class _NullIdChannel
    implements AudioCaptureChannel, AudioCaptureCloseControl {
  int stopCalls = 0;
  final _events = StreamController<RawAudioEvent>.broadcast();
  @override
  String? get attemptId => null;
  @override
  Stream<RawAudioEvent> get events => _events.stream;
  @override
  Future<AudioCaptureCloseState> readCloseState() async =>
      const AudioCaptureCloseState.clear();
  @override
  Future<void> start({required int sampleRate}) async {}
  @override
  Future<void> stop() async {
    stopCalls++;
  }

  @override
  Future<void> stopAttempt(String id) => stop();
  @override
  Future<void> retryStopAttempt(String id) => stop();
}

final class _CloseProbeChannel
    implements
        AudioCaptureChannel,
        PreparedAudioCaptureChannel,
        AudioCaptureCloseControl {
  _CloseProbeChannel({this.startGate, this.prepareGate, this.stopGate});
  final Future<void>? startGate;
  final Future<void>? prepareGate;
  final Future<void>? stopGate;
  final _events = StreamController<RawAudioEvent>.broadcast();
  int startCalls = 0, stopCalls = 0, retryCalls = 0;
  bool running = false, failStop = false, stickyNormalStop = false;
  @override
  String? attemptId;
  AudioCaptureCloseState state = const AudioCaptureCloseState.clear();
  @override
  Stream<RawAudioEvent> get events => _events.stream;
  @override
  Future<AudioCaptureCloseState> readCloseState() async => state;
  @override
  Future<void> prepare() async {
    attemptId ??= 'test-attempt';
    state = AudioCaptureCloseState(
      phase: AudioCaptureClosePhase.starting,
      attemptId: attemptId,
      attemptInFlight: true,
      resourcesReleased: false,
      requiresExplicitRetry: false,
    );
    await prepareGate;
  }

  @override
  Future<void> start({required int sampleRate}) async {
    startCalls++;
    await startGate;
    running = true;
    state = AudioCaptureCloseState(
      phase: AudioCaptureClosePhase.running,
      attemptId: attemptId,
      attemptInFlight: false,
      resourcesReleased: false,
      requiresExplicitRetry: false,
    );
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    await stopGate;
    if (stickyNormalStop &&
        state.phase == AudioCaptureClosePhase.releasedAwaitingExplicitRetry) {
      throw PlatformException(code: 'capture_close_unconfirmed');
    }
    if (failStop) {
      state = AudioCaptureCloseState(
        phase: AudioCaptureClosePhase.unconfirmedQuiescent,
        attemptId: attemptId,
        attemptInFlight: false,
        resourcesReleased: false,
        requiresExplicitRetry: true,
      );
      throw PlatformException(code: 'release_failed');
    }
    running = false;
    state = AudioCaptureCloseState(
      phase: AudioCaptureClosePhase.clear,
      attemptId: null,
      attemptInFlight: false,
      resourcesReleased: true,
      requiresExplicitRetry: false,
    );
  }

  @override
  Future<void> stopAttempt(String id) => stop();
  @override
  Future<void> retryStopAttempt(String id) async {
    retryCalls++;
    final sticky = stickyNormalStop;
    stickyNormalStop = false;
    try {
      await stop();
    } finally {
      stickyNormalStop = sticky;
    }
  }
}

class _DelayedStartChannel
    implements AudioCaptureChannel, AudioCaptureCloseControl {
  final startCompleted = Completer<void>();
  final _events = StreamController<RawAudioEvent>.broadcast();
  bool running = false;
  @override
  String? get attemptId => 'delayed-start';
  @override
  Future<AudioCaptureCloseState> readCloseState() async => running
      ? const AudioCaptureCloseState(
          phase: AudioCaptureClosePhase.running,
          attemptId: 'delayed-start',
          attemptInFlight: false,
          resourcesReleased: false,
          requiresExplicitRetry: false,
        )
      : const AudioCaptureCloseState.clear();
  @override
  Stream<RawAudioEvent> get events => _events.stream;
  @override
  Future<void> start({required int sampleRate}) async {
    await startCompleted.future;
    running = true;
  }

  @override
  Future<void> stop() async => running = false;
  @override
  Future<void> stopAttempt(String id) => stop();
  @override
  Future<void> retryStopAttempt(String id) => stop();
  void sendChunk() => _events.add(
    const RawAudioChunkEvent(
      samples: [.2, .2],
      sampleRate: 44100,
      tNativeUs: 0,
    ),
  );
}

class _SlowCancelChannel
    implements AudioCaptureChannel, AudioCaptureCloseControl {
  final inner = FakeAudioCaptureChannel();
  bool get isRunning => inner.isRunning;
  @override
  String? get attemptId => inner.attemptId;
  @override
  Future<AudioCaptureCloseState> readCloseState() => inner.readCloseState();
  @override
  Future<void> start({required int sampleRate}) =>
      inner.start(sampleRate: sampleRate);
  @override
  Future<void> stop() => inner.stop();
  @override
  Future<void> stopAttempt(String id) => inner.stopAttempt(id);
  @override
  Future<void> retryStopAttempt(String id) => inner.retryStopAttempt(id);
  final cancellation = Completer<void>();
  @override
  Stream<RawAudioEvent> get events =>
      _SlowCancelStream(inner.events, cancellation.future);
}

class _SlowCancelStream extends Stream<RawAudioEvent> {
  _SlowCancelStream(this.inner, this.closed);
  final Stream<RawAudioEvent> inner;
  final Future<void> closed;
  @override
  StreamSubscription<RawAudioEvent> listen(
    void Function(RawAudioEvent)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => _SlowCancelSubscription(
    inner.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    ),
    closed,
  );
}

class _SlowCancelSubscription implements StreamSubscription<RawAudioEvent> {
  _SlowCancelSubscription(this.inner, this.closed);
  final StreamSubscription<RawAudioEvent> inner;
  final Future<void> closed;
  @override
  Future<void> cancel() async {
    await inner.cancel();
    await closed;
  }

  @override
  void onData(void Function(RawAudioEvent)? h) => inner.onData(h);
  @override
  void onError(Function? h) => inner.onError(h);
  @override
  void onDone(void Function()? h) => inner.onDone(h);
  @override
  void pause([Future<void>? signal]) => inner.pause(signal);
  @override
  void resume() => inner.resume();
  @override
  bool get isPaused => inner.isPaused;
  @override
  Future<E> asFuture<E>([E? value]) => inner.asFuture<E>(value);
}

class _DelayedReadyChannel
    implements
        AudioCaptureChannel,
        PreparedAudioCaptureChannel,
        AudioCaptureCloseControl {
  final ready = Completer<void>();
  int startCount = 0;
  final _events = StreamController<RawAudioEvent>.broadcast();
  @override
  String? get attemptId => 'delayed-ready';
  @override
  Future<AudioCaptureCloseState> readCloseState() async =>
      const AudioCaptureCloseState.clear();
  @override
  Stream<RawAudioEvent> get events => _events.stream;
  @override
  Future<void> prepare() => ready.future;
  @override
  Future<void> start({required int sampleRate}) async {
    startCount++;
  }

  @override
  Future<void> stop() async {}
  @override
  Future<void> stopAttempt(String id) => stop();
  @override
  Future<void> retryStopAttempt(String id) => stop();
}
