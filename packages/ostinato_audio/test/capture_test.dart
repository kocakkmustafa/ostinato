import 'package:ostinato_audio/ostinato_audio.dart';
import 'package:test/test.dart';

void main() {
  group('AudioRingBuffer', () {
    test('push within capacity keeps chronological order', () {
      final buf = AudioRingBuffer(capacitySamples: 4);
      buf.push([1, 2, 3]);
      expect(buf.length, 3);
      expect(buf.isFull, isFalse);
      expect(buf.snapshot(), [1, 2, 3]);
    });

    test('push beyond capacity overwrites the oldest samples, not the newest', () {
      final buf = AudioRingBuffer(capacitySamples: 4);
      buf.push([1, 2, 3, 4]);
      buf.push([5, 6]); // 1, 2 dışarı düşer
      expect(buf.length, 4);
      expect(buf.isFull, isTrue);
      expect(buf.snapshot(), [3, 4, 5, 6]);
    });

    test('a single push larger than capacity still leaves only the tail window', () {
      final buf = AudioRingBuffer(capacitySamples: 3);
      buf.push([1, 2, 3, 4, 5]);
      expect(buf.snapshot(), [3, 4, 5]);
    });

    test('clear resets length and isFull — observable emptiness', () {
      final buf = AudioRingBuffer(capacitySamples: 4)..push([1, 2, 3, 4]);
      buf.clear();
      expect(buf.length, 0);
      expect(buf.isFull, isFalse);
      expect(buf.snapshot(), isEmpty);
    });

    test(
      'clear actually zeroes the backing store, not just the length counter '
      '(roadmap §7: "sıfırlanır" — bir sonraki oturumun örnekleri, önceki '
      'oturumun baytlarının üstüne DEĞİL, sıfırların üstüne yazılmalı)',
      () {
        final buf = AudioRingBuffer(capacitySamples: 4)..push([0.1, 0.2, 0.3, 0.4]);
        expect(buf.debugRawBackingStoreForTest(), isNot(everyElement(0.0)));
        buf.clear();
        expect(buf.debugRawBackingStoreForTest(), everyElement(0.0));
      },
    );

    test('after clear, a partial refill does not leak stale samples past the boundary', () {
      final buf = AudioRingBuffer(capacitySamples: 4)..push([9, 9, 9, 9]);
      buf.clear();
      buf.push([0.5]);
      expect(buf.snapshot(), [0.5]); // eski 9'lardan biri bile sızmaz
    });

    test('capacity must be positive', () {
      expect(() => AudioRingBuffer(capacitySamples: 0), throwsA(isA<AssertionError>()));
    });
  });

  group('AudioSurfaceState — sealed, each state carries only what it can prove', () {
    test('permission states are distinct types, not one flag', () {
      const AudioSurfaceState retriable = AudioPermissionDeniedRetriable();
      const AudioSurfaceState permanent = AudioPermissionDeniedPermanent();
      expect(retriable, isA<AudioPermissionDenied>());
      expect(permanent, isA<AudioPermissionDenied>());
      expect(retriable, isNot(isA<AudioPermissionDeniedPermanent>()));
    });

    test('Calibrating carries the route it is calibrating for', () {
      const state = AudioCalibrating(AudioRoute.bluetooth);
      expect(state.route, AudioRoute.bluetooth);
    });

    test('Streaming carries route and sample rate, nothing about latency', () {
      const state = AudioStreaming(AudioRoute.wiredHeadset, 48000);
      expect(state.route, AudioRoute.wiredHeadset);
      expect(state.sampleRate, 48000);
    });

    test('Unavailable names its reason instead of a raw exception string', () {
      const state = AudioUnavailable('unsupported_sample_rate:96000');
      expect(state.reason, 'unsupported_sample_rate:96000');
    });
  });

  group('FakeAudioSource — proves the capture contract without hardware', () {
    test('granted permission + supported rate starts and calibrates', () async {
      final src = FakeAudioSource();
      final states = <AudioSurfaceState>[];
      final sub = src.status.listen(states.add);
      await src.start(sampleRate: 44100);
      await pumpEventQueue();
      expect(states, [isA<AudioStarting>(), isA<AudioCalibrating>()]);
      expect(src.isRunning, isTrue);
      await sub.cancel();
      await src.dispose();
    });

    test('retriable denial reports the retriable state and never streams chunks', () async {
      final src = FakeAudioSource()..permissionGranted = false;
      final states = <AudioSurfaceState>[];
      final chunks = <AudioChunk>[];
      final statusSub = src.status.listen(states.add);
      final chunkSub = src.chunks.listen(chunks.add);
      await src.start(sampleRate: 44100);
      src.pushChunk([0.1, 0.2]); // koşmuyor — sessizce düşmeli
      await pumpEventQueue();
      expect(states, [isA<AudioStarting>(), isA<AudioPermissionDeniedRetriable>()]);
      expect(src.isRunning, isFalse);
      expect(chunks, isEmpty);
      await statusSub.cancel();
      await chunkSub.cancel();
      await src.dispose();
    });

    test('permanent denial is a distinct state from retriable', () async {
      final src = FakeAudioSource()
        ..permissionGranted = false
        ..permissionPermanentlyDenied = true;
      final states = <AudioSurfaceState>[];
      final sub = src.status.listen(states.add);
      await src.start(sampleRate: 44100);
      await pumpEventQueue();
      expect(states.last, isA<AudioPermissionDeniedPermanent>());
      await sub.cancel();
      await src.dispose();
    });

    test('an unsupported sample rate is named, not silently rounded to a supported one', () async {
      final src = FakeAudioSource(supportedSampleRates: {44100, 48000});
      final states = <AudioSurfaceState>[];
      final sub = src.status.listen(states.add);
      await src.start(sampleRate: 96000);
      await pumpEventQueue();
      final unavailable = states.last as AudioUnavailable;
      expect(unavailable.reason, 'unsupported_sample_rate:96000');
      expect(src.isRunning, isFalse);
      await sub.cancel();
      await src.dispose();
    });

    test('chunks pushed while running carry monotonically advancing timestamps', () async {
      final src = FakeAudioSource();
      final chunks = <AudioChunk>[];
      final sub = src.chunks.listen(chunks.add);
      await src.start(sampleRate: 44100);
      src.pushChunk(List.filled(4410, 0.0), sampleRate: 44100); // 100ms
      src.pushChunk(List.filled(4410, 0.0), sampleRate: 44100);
      await pumpEventQueue();
      expect(chunks, hasLength(2));
      expect(chunks[0].tStartUs, 0);
      expect(chunks[1].tStartUs, 100000); // +100ms, mikrosaniye
      expect(chunks[0].clockDomain, AudioClockDomain.monotonic);
      await sub.cancel();
      await src.dispose();
    });

    test('a route change while streaming forces a return to Calibrating', () async {
      final src = FakeAudioSource(initialRoute: AudioRoute.speaker);
      final states = <AudioSurfaceState>[];
      final sub = src.status.listen(states.add);
      await src.start(sampleRate: 44100);
      src.simulateRouteChange(AudioRoute.bluetooth);
      await pumpEventQueue();
      final last = states.last as AudioCalibrating;
      expect(last.route, AudioRoute.bluetooth);
      await sub.cancel();
      await src.dispose();
    });

    test('a route change before start (not running) does not fabricate a status event', () async {
      final src = FakeAudioSource();
      final states = <AudioSurfaceState>[];
      final sub = src.status.listen(states.add);
      src.simulateRouteChange(AudioRoute.bluetooth); // start() hiç çağrılmadı
      await pumpEventQueue();
      expect(states, isEmpty);
      await sub.cancel();
      await src.dispose();
    });

    test('stop marks the source as not running', () async {
      final src = FakeAudioSource();
      await src.start(sampleRate: 44100);
      expect(src.isRunning, isTrue);
      await src.stop();
      expect(src.isRunning, isFalse);
      await src.dispose();
    });
  });
}
