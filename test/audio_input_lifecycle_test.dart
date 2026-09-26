import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:ostinato/app/audio/audio_capture_channel.dart';
import 'package:ostinato/app/audio/audio_input_controller.dart';
import 'package:ostinato/app/audio/audio_route_state.dart';
import 'package:ostinato_audio/ostinato_audio.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
      await stop;
      channel.sendChunk();
      await pumpEventQueue();
      expect(channel.running, isFalse);
      expect(chunks, isEmpty);
      await sub.cancel();
      await source.dispose();
    },
  );

  test(
    'old pending start cannot stop a newer owner on the same native lane',
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
      await Future.wait([startA, stopA, startB]);
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
      await Future.wait([start, stop]);
      expect(channel.startCount, 0);
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
}

class _DelayedStartChannel implements AudioCaptureChannel {
  final startCompleted = Completer<void>();
  final _events = StreamController<RawAudioEvent>.broadcast();
  bool running = false;
  @override
  Stream<RawAudioEvent> get events => _events.stream;
  @override
  Future<void> start({required int sampleRate}) async {
    await startCompleted.future;
    running = true;
  }

  @override
  Future<void> stop() async => running = false;
  void sendChunk() => _events.add(
    const RawAudioChunkEvent(
      samples: [.2, .2],
      sampleRate: 44100,
      tNativeUs: 0,
    ),
  );
}

class _SlowCancelChannel implements AudioCaptureChannel {
  final inner = FakeAudioCaptureChannel();
  bool get isRunning => inner.isRunning;
  @override
  Future<void> start({required int sampleRate}) =>
      inner.start(sampleRate: sampleRate);
  @override
  Future<void> stop() => inner.stop();
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
    implements AudioCaptureChannel, PreparedAudioCaptureChannel {
  final ready = Completer<void>();
  int startCount = 0;
  final _events = StreamController<RawAudioEvent>.broadcast();
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
}
