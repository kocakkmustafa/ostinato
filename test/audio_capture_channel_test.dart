import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/audio/audio_capture_channel.dart';

const method = MethodChannel('com.yulalab.ostinato/audio_capture');
const events = MethodChannel('com.yulalab.ostinato/audio_capture/events');
const testClaim = AudioCaptureContextClaim(
  ownerToken: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  engineGeneration: 1,
  contextGeneration: 0,
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <String>[];
  setUp(() {
    calls.clear();
    messenger.setMockMethodCallHandler(events, (call) async {
      calls.add('event:${call.method}');
      return null;
    });
    messenger.setMockMethodCallHandler(method, (call) async {
      calls.add(call.method);
      if (call.method == 'ready') return true;
      if (call.method == 'closeState') {
        return {
          'phase': 'clear',
          'attemptId': null,
          'attemptInFlight': false,
          'resourcesReleased': true,
          'requiresExplicitRetry': false,
        };
      }
      return null;
    });
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(events, null);
    messenger.setMockMethodCallHandler(method, null);
  });
  Future<void> send(Object value) async {
    messenger.handlePlatformMessage(
      events.name,
      const StandardMethodCodec().encodeSuccessEnvelope(value),
      (_) {},
    );
    await pumpEventQueue();
  }

  test(
    'native capture start requires a complete original context claim',
    () async {
      final channel = MethodChannelAudioCaptureChannel();
      await expectLater(
        channel.start(sampleRate: 44100),
        throwsA(
          isA<PlatformException>().having(
            (error) => error.code,
            'code',
            'capture_context_required',
          ),
        ),
      );
      await expectLater(
        channel.start(
          sampleRate: 44100,
          claim: const AudioCaptureContextClaim(
            ownerToken: 'bad',
            engineGeneration: 1,
            contextGeneration: 0,
          ),
        ),
        throwsA(
          isA<PlatformException>().having(
            (error) => error.code,
            'code',
            'capture_context_required',
          ),
        ),
      );
      expect(calls, isEmpty);

      Map<String, Object?>? startArguments;
      messenger.setMockMethodCallHandler(method, (call) async {
        calls.add(call.method);
        if (call.method == 'ready') return true;
        if (call.method == 'start') {
          startArguments = Map<String, Object?>.from(call.arguments as Map);
        }
        if (call.method == 'closeState') {
          return {
            'phase': 'clear',
            'attemptId': null,
            'attemptInFlight': false,
            'resourcesReleased': true,
            'requiresExplicitRetry': false,
          };
        }
        return null;
      });
      await channel.start(sampleRate: 44100, claim: testClaim);
      expect(startArguments, containsPair('ownerToken', testClaim.ownerToken));
      expect(startArguments, containsPair('engineGeneration', 1));
      expect(startArguments, containsPair('contextGeneration', 0));
      expect(startArguments, containsPair('sampleRate', 44100));
      expect(startArguments?['attemptId'], channel.attemptId);
      await channel.stop();
    },
  );

  test(
    'subscription ready handshake precedes native start and stop cancels events',
    () async {
      final channel = MethodChannelAudioCaptureChannel();
      final received = <RawAudioEvent>[];
      final sub = channel.events.listen(received.add);
      await channel.start(sampleRate: 44100, claim: testClaim);
      final id = channel.attemptId;
      expect(id, matches(RegExp(r'^[0-9a-f]{32}$')));
      expect(calls.indexOf('ready'), lessThan(calls.indexOf('start')));
      await send({
        'type': 'routeChanged',
        'route': 'ios:BuiltInMic',
        'attemptId': id,
      });
      await send({
        'type': 'chunk',
        'attemptId': id,
        'samples': Float64List.fromList([.1, .2]),
        'sampleRate': 44100,
        't': 12,
      });
      expect(received.first, isA<RawRouteChangedEvent>());
      expect((received.last as RawAudioChunkEvent).samples, [.1, .2]);
      await channel.stop();
      expect(calls, containsAll(['event:cancel', 'stop']));
      expect(calls.indexOf('stop'), lessThan(calls.indexOf('event:cancel')));
      expect(channel.attemptId, isNull);
      await sub.cancel();
    },
  );
  test(
    'invalid native envelope becomes interruption instead of an uncaught cast',
    () async {
      final channel = MethodChannelAudioCaptureChannel();
      final received = <RawAudioEvent>[];
      final sub = channel.events.listen(received.add);
      await channel.start(sampleRate: 44100, claim: testClaim);
      await send({
        'type': 'chunk',
        'attemptId': channel.attemptId,
        'samples': 'invalid',
      });
      expect(
        (received.single as RawInterruptedEvent).reason,
        'invalid_capture_event',
      );
      await channel.stop();
      await sub.cancel();
    },
  );

  test('missing closeState refuses a native stop success', () async {
    final channel = MethodChannelAudioCaptureChannel();
    await channel.start(sampleRate: 44100, claim: testClaim);
    messenger.setMockMethodCallHandler(method, (call) async {
      if (call.method == 'closeState') return null;
      return call.method == 'ready' ? true : null;
    });
    await expectLater(
      channel.stop(),
      throwsA(
        isA<PlatformException>().having(
          (error) => error.code,
          'code',
          'capture_close_unconfirmed',
        ),
      ),
    );
    expect(channel.attemptId, isNotNull);
    expect(
      (await channel.readCloseState()).phase,
      AudioCaptureClosePhase.unknown,
    );
    await expectLater(
      channel.start(sampleRate: 44100, claim: testClaim),
      throwsA(isA<PlatformException>()),
    );
  });

  test(
    'disposed readback stays unknown until an explicit close retry',
    () async {
      final channel = MethodChannelAudioCaptureChannel();
      await channel.start(sampleRate: 44100, claim: testClaim);
      final id = channel.attemptId!;
      channel.suspendCloseReadbacksUntilExplicitRetry();
      expect(
        (await channel.readCloseState()).phase,
        AudioCaptureClosePhase.unknown,
      );
      await expectLater(channel.stop(), throwsA(isA<PlatformException>()));
      expect(channel.attemptId, id);
      expect(
        (await channel.readCloseState()).phase,
        AudioCaptureClosePhase.unknown,
      );
      await channel.retryStopAttempt(id);
      expect(channel.attemptId, isNull);
      expect((await channel.readCloseState()).isClear, isTrue);
      expect(calls.where((call) => call == 'stop').length, 1);
      expect(calls.where((call) => call == 'retryStop').length, 1);
    },
  );

  test(
    'late ordinary stop cannot consume explicit retry wire intent',
    () async {
      final channel = MethodChannelAudioCaptureChannel();
      await channel.start(sampleRate: 44100, claim: testClaim);
      final id = channel.attemptId!;
      var sticky = true;
      messenger.setMockMethodCallHandler(method, (call) async {
        calls.add(call.method);
        if (call.method == 'stop' && sticky) {
          throw PlatformException(code: 'capture_close_unconfirmed');
        }
        if (call.method == 'retryStop') sticky = false;
        if (call.method == 'closeState') {
          return sticky
              ? {
                  'phase': 'releasedAwaitingExplicitRetry',
                  'attemptId': id,
                  'attemptInFlight': false,
                  'resourcesReleased': true,
                  'requiresExplicitRetry': true,
                }
              : {
                  'phase': 'clear',
                  'attemptId': null,
                  'attemptInFlight': false,
                  'resourcesReleased': true,
                  'requiresExplicitRetry': false,
                };
        }
        return null;
      });
      await expectLater(channel.stop(), throwsA(isA<PlatformException>()));
      await expectLater(
        channel.stopAttempt(id),
        throwsA(isA<PlatformException>()),
      );
      expect(sticky, isTrue);
      expect(channel.attemptId, id);
      await channel.retryStopAttempt(id);
      expect(calls.where((call) => call == 'stop').length, 2);
      expect(calls.where((call) => call == 'retryStop').length, 1);
      expect(channel.attemptId, isNull);
    },
  );

  test(
    'explicit retry is sent while an ordinary stop reply is still pending',
    () async {
      final channel = MethodChannelAudioCaptureChannel();
      await channel.start(sampleRate: 44100, claim: testClaim);
      final id = channel.attemptId!;
      final ordinaryReply = Completer<void>();
      var sticky = true;
      messenger.setMockMethodCallHandler(method, (call) async {
        calls.add(call.method);
        if (call.method == 'stop') await ordinaryReply.future;
        if (call.method == 'retryStop') sticky = false;
        if (call.method == 'closeState') {
          return sticky
              ? {
                  'phase': 'releasedAwaitingExplicitRetry',
                  'attemptId': id,
                  'attemptInFlight': false,
                  'resourcesReleased': true,
                  'requiresExplicitRetry': true,
                }
              : {
                  'phase': 'clear',
                  'attemptId': null,
                  'attemptInFlight': false,
                  'resourcesReleased': true,
                  'requiresExplicitRetry': false,
                };
        }
        return null;
      });
      final ordinary = channel.stop();
      await pumpEventQueue();
      await channel.retryStopAttempt(id);
      expect(calls.where((call) => call == 'retryStop').length, 1);
      expect(channel.attemptId, isNull);
      ordinaryReply.completeError(
        PlatformException(code: 'capture_close_unconfirmed'),
      );
      await expectLater(ordinary, throwsA(isA<PlatformException>()));
    },
  );

  test('stop error is visible and old chunks are fenced', () async {
    final channel = MethodChannelAudioCaptureChannel();
    final received = <RawAudioEvent>[];
    final sub = channel.events.listen(received.add);
    await channel.start(sampleRate: 44100, claim: testClaim);
    final id = channel.attemptId;
    messenger.setMockMethodCallHandler(method, (call) async {
      if (call.method == 'stop') {
        throw PlatformException(code: 'release_failed');
      }
      if (call.method == 'closeState') {
        return {
          'phase': 'unconfirmedQuiescent',
          'attemptId': id,
          'attemptInFlight': false,
          'resourcesReleased': false,
          'requiresExplicitRetry': true,
        };
      }
      return null;
    });
    await expectLater(channel.stop(), throwsA(isA<PlatformException>()));
    await send({
      'type': 'chunk',
      'attemptId': id,
      'samples': Float64List.fromList([.2]),
      'sampleRate': 44100,
      't': 5,
    });
    expect(received, isEmpty);
    await sub.cancel();
  });

  test('malformed and contradictory closeState stay unknown', () async {
    expect(
      AudioCaptureCloseState.fromMessage(null).phase,
      AudioCaptureClosePhase.unknown,
    );
    expect(
      AudioCaptureCloseState.fromMessage({
        'phase': 'clear',
        'attemptId': null,
        'attemptInFlight': true,
        'resourcesReleased': true,
        'requiresExplicitRetry': false,
      }).phase,
      AudioCaptureClosePhase.unknown,
    );
  });

  test('never-returning native stop is bounded and cannot restart', () async {
    final channel = MethodChannelAudioCaptureChannel(
      transportTimeout: const Duration(milliseconds: 20),
    );
    await channel.start(sampleRate: 44100, claim: testClaim);
    final stopReply = Completer<void>();
    messenger.setMockMethodCallHandler(method, (call) async {
      if (call.method == 'stop') {
        await stopReply.future;
        return null;
      }
      if (call.method == 'closeState') {
        return {
          'phase': 'unconfirmedInFlight',
          'attemptId': channel.attemptId,
          'attemptInFlight': true,
          'resourcesReleased': false,
          'requiresExplicitRetry': false,
        };
      }
      return null;
    });
    await expectLater(
      channel.stop(),
      throwsA(
        isA<PlatformException>().having(
          (error) => error.code,
          'code',
          'capture_close_unconfirmed',
        ),
      ),
    );
    expect(await channel.readCloseState(), isA<AudioCaptureCloseState>());
    await expectLater(
      channel.start(sampleRate: 44100, claim: testClaim),
      throwsA(isA<PlatformException>()),
    );
    stopReply.complete();
  });

  test(
    'early cancel error is observed while native stop reply is delayed',
    () async {
      final nativeStopReply = Completer<void>();
      final channel = MethodChannelAudioCaptureChannel(
        transportTimeout: const Duration(milliseconds: 30),
        eventChannel: _FailingCancelEventChannel(calls),
      );
      messenger.setMockMethodCallHandler(method, (call) async {
        calls.add(call.method);
        if (call.method == 'ready') return true;
        if (call.method == 'stop') await nativeStopReply.future;
        if (call.method == 'closeState') {
          return {
            'phase': 'unconfirmedInFlight',
            'attemptId': channel.attemptId,
            'attemptInFlight': true,
            'resourcesReleased': false,
            'requiresExplicitRetry': false,
          };
        }
        return null;
      });
      await channel.start(sampleRate: 44100, claim: testClaim);
      final id = channel.attemptId;
      final uncaught = <Object>[];
      await runZonedGuarded<Future<void>>(() async {
        await expectLater(
          channel.stop(),
          throwsA(
            isA<PlatformException>().having(
              (error) => error.code,
              'code',
              'capture_close_unconfirmed',
            ),
          ),
        );
        await pumpEventQueue();
      }, (error, stackTrace) => uncaught.add(error))!;
      expect(uncaught, isEmpty);
      expect(calls.indexOf('stop'), lessThan(calls.indexOf('event:cancel')));
      expect(channel.attemptId, id);
      await expectLater(
        channel.start(sampleRate: 44100, claim: testClaim),
        throwsA(isA<PlatformException>()),
      );
      nativeStopReply.complete();
    },
  );
}

final class _FailingCancelEventChannel extends EventChannel {
  _FailingCancelEventChannel(this.calls) : super('test/audio_capture/events');
  final List<String> calls;

  @override
  Stream<dynamic> receiveBroadcastStream([dynamic arguments]) =>
      _FailingCancelStream(calls);
}

final class _FailingCancelStream extends Stream<dynamic> {
  _FailingCancelStream(this.calls);
  final List<String> calls;

  @override
  StreamSubscription<dynamic> listen(
    void Function(dynamic)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => _FailingCancelSubscription(
    const Stream<dynamic>.empty().listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    ),
    calls,
  );
}

final class _FailingCancelSubscription implements StreamSubscription<dynamic> {
  _FailingCancelSubscription(this.inner, this.calls);
  final StreamSubscription<dynamic> inner;
  final List<String> calls;

  @override
  Future<void> cancel() {
    calls.add('event:cancel');
    return Future<void>.error(StateError('early_event_cancel_error'));
  }

  @override
  void onData(void Function(dynamic)? handler) => inner.onData(handler);
  @override
  void onError(Function? handler) => inner.onError(handler);
  @override
  void onDone(void Function()? handler) => inner.onDone(handler);
  @override
  void pause([Future<void>? resumeSignal]) => inner.pause(resumeSignal);
  @override
  void resume() => inner.resume();
  @override
  bool get isPaused => inner.isPaused;
  @override
  Future<E> asFuture<E>([E? futureValue]) => inner.asFuture<E>(futureValue);
}
