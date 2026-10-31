// F2.1 — pratik için çal + dinle ses oturumu (Dart tarafı).
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/audio/audio_capture_channel.dart';
import 'package:ostinato/app/audio/audio_input_controller.dart';
import 'package:ostinato/app/audio/practice_cue.dart';
import 'package:ostinato_audio/ostinato_audio.dart';
import 'package:permission_handler/permission_handler.dart';

const method = MethodChannel('com.yulalab.ostinato/audio_capture');
const events = MethodChannel('com.yulalab.ostinato/audio_capture/events');
const testClaim = AudioCaptureContextClaim(
  ownerToken: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  engineGeneration: 1,
  contextGeneration: 0,
);

Matcher _code(String code) => throwsA(
  isA<PlatformException>().having((error) => error.code, 'code', code),
);

/// A legacy channel without the play+record capability.
final class _RecordOnlyChannel
    implements AudioCaptureChannel, AudioCaptureCloseControl {
  int starts = 0;
  bool running = false;
  @override
  String? get attemptId => running ? 'legacy' : null;
  @override
  Stream<RawAudioEvent> get events => const Stream<RawAudioEvent>.empty();
  @override
  Future<AudioCaptureCloseState> readCloseState() async =>
      const AudioCaptureCloseState.clear();
  @override
  Future<void> start({required int sampleRate}) async {
    starts++;
    running = true;
  }

  @override
  Future<void> stop() async => running = false;
  @override
  Future<void> stopAttempt(String attemptId) => stop();
  @override
  Future<void> retryStopAttempt(String attemptId) => stop();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MethodChannelAudioCaptureChannel wire', () {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final starts = <Map<String, Object?>>[];
    final cues = <Map<String, Object?>>[];
    setUp(() {
      starts.clear();
      cues.clear();
      messenger.setMockMethodCallHandler(events, (call) async => null);
      messenger.setMockMethodCallHandler(method, (call) async {
        switch (call.method) {
          case 'ready':
            return true;
          case 'start':
            starts.add(Map<String, Object?>.from(call.arguments as Map));
          case 'playCue':
            cues.add(Map<String, Object?>.from(call.arguments as Map));
          case 'closeState':
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

    test('record-only start keeps the exact legacy key set', () async {
      final channel = MethodChannelAudioCaptureChannel();
      await channel.start(sampleRate: 48000, claim: testClaim);
      expect(starts.single.keys.toSet(), {
        'attemptId',
        'sampleRate',
        'ownerToken',
        'engineGeneration',
        'contextGeneration',
      });
      await channel.stop();
    });

    test('play+record start adds only sessionMode', () async {
      final channel = MethodChannelAudioCaptureChannel();
      await expectLater(
        channel.startPlayAndRecord(sampleRate: 48000),
        _code('capture_context_required'),
      );
      await channel.startPlayAndRecord(sampleRate: 48000, claim: testClaim);
      expect(starts.single['sessionMode'], 'playAndRecord');
      expect(starts.single.length, 6);
      await channel.stop();
    });

    test('playCue sends the running attempt and validates first', () async {
      final channel = MethodChannelAudioCaptureChannel();
      await expectLater(
        channel.playCue(Float64List.fromList([.1]), sampleRate: 48000),
        _code('playback_unavailable'),
      );
      await channel.startPlayAndRecord(sampleRate: 48000, claim: testClaim);
      await channel.playCue(Float64List.fromList([.1, -.1]), sampleRate: 48000);
      expect(cues.single['attemptId'], channel.attemptId);
      expect(cues.single['samples'], [.1, -.1]);
      expect(cues.single['sampleRate'], 48000);
      await expectLater(
        channel.playCue(Float64List.fromList([1.5]), sampleRate: 48000),
        _code('bad_args'),
      );
      await expectLater(
        channel.playCue(Float64List(0), sampleRate: 48000),
        _code('bad_args'),
      );
      await expectLater(
        channel.playCue(Float64List.fromList([.1]), sampleRate: 22050),
        _code('bad_args'),
      );
      expect(cues, hasLength(1));
      await channel.stop();
      await expectLater(
        channel.playCue(Float64List.fromList([.1]), sampleRate: 48000),
        _code('playback_unavailable'),
      );
    });

    test('chunk playbackActive is optional and strictly typed', () async {
      final channel = MethodChannelAudioCaptureChannel();
      final received = <RawAudioEvent>[];
      final sub = channel.events.listen(received.add);
      await channel.startPlayAndRecord(sampleRate: 48000, claim: testClaim);
      final id = channel.attemptId;
      Map<String, Object?> chunk([Object? flag]) => {
        'type': 'chunk',
        'attemptId': id,
        'samples': Float64List.fromList([.1]),
        'sampleRate': 48000,
        't': 1,
        'playbackActive': ?flag,
      };
      await send(chunk());
      await send(chunk(true));
      await send(chunk('yes'));
      expect((received[0] as RawAudioChunkEvent).playbackActive, isFalse);
      expect((received[1] as RawAudioChunkEvent).playbackActive, isTrue);
      expect(
        (received[2] as RawInterruptedEvent).reason,
        'invalid_capture_event',
      );
      await channel.stop();
      await sub.cancel();
    });
  });

  group('AudioInputController play+record', () {
    setUp(resetAudioCaptureCoordinatorForTest);

    AudioInputController controller(AudioCaptureChannel channel) =>
        AudioInputController(
          channel: channel,
          requestMicrophonePermission: () async => PermissionStatus.granted,
        );

    test('starts the duplex mode and carries the overlap flag', () async {
      final channel = FakeAudioCaptureChannel();
      final source = controller(channel);
      final chunks = <AudioChunk>[];
      final sub = source.chunks.listen(chunks.add);
      await source.start(
        sampleRate: 48000,
        sessionMode: AudioSessionMode.playAndRecord,
      );
      expect(channel.sessionMode, AudioSessionMode.playAndRecord);
      expect(source.sessionMode, AudioSessionMode.playAndRecord);
      channel.pushChunk(
        List.filled(64, .1),
        sampleRate: 48000,
        tNativeUs: 0,
        playbackActive: true,
      );
      channel.pushChunk(
        List.filled(64, .1),
        sampleRate: 48000,
        tNativeUs: 1333,
      );
      await pumpEventQueue();
      expect(chunks.map((c) => c.playbackActive), [true, false]);

      final click = practiceTestClick(sampleRate: 48000);
      await source.playCue(click, sampleRate: 48000);
      expect(channel.playedCues.single, click);
      await sub.cancel();
      await source.dispose();
      expect(channel.isRunning, isFalse);
    });

    test('a failed cue is reported but never stops capture', () async {
      final channel = FakeAudioCaptureChannel();
      final source = controller(channel);
      await source.start(
        sampleRate: 48000,
        sessionMode: AudioSessionMode.playAndRecord,
      );
      channel.failNextCue = true;
      await expectLater(
        source.playCue(Float64List.fromList([.1]), sampleRate: 48000),
        _code('playback_failed'),
      );
      expect(channel.isRunning, isTrue);
      await expectLater(
        source.playCue(Float64List.fromList([.1]), sampleRate: 44100),
        _code('unsupported_sample_rate'),
      );
      await expectLater(
        source.playCue(Float64List.fromList([double.nan]), sampleRate: 48000),
        _code('bad_args'),
      );
      expect(channel.isRunning, isTrue);
      await source.dispose();
    });

    test('record-only stays the default and refuses cues', () async {
      final channel = FakeAudioCaptureChannel();
      final source = controller(channel);
      final chunks = <AudioChunk>[];
      final sub = source.chunks.listen(chunks.add);
      await source.start(sampleRate: 44100);
      expect(channel.sessionMode, AudioSessionMode.recordOnly);
      expect(source.sessionMode, AudioSessionMode.recordOnly);
      // A stray native flag on a record-only attempt is ignored.
      channel.pushChunk(
        List.filled(64, .1),
        sampleRate: 44100,
        tNativeUs: 0,
        playbackActive: true,
      );
      await pumpEventQueue();
      expect(chunks.single.playbackActive, isFalse);
      await expectLater(
        source.playCue(Float64List.fromList([.1]), sampleRate: 44100),
        _code('playback_not_enabled'),
      );
      expect(channel.playedCues, isEmpty);
      await sub.cancel();
      await source.dispose();
    });

    test('cue after stop is unavailable', () async {
      final channel = FakeAudioCaptureChannel();
      final source = controller(channel);
      await source.start(
        sampleRate: 48000,
        sessionMode: AudioSessionMode.playAndRecord,
      );
      await source.stop();
      await expectLater(
        source.playCue(Float64List.fromList([.1]), sampleRate: 48000),
        _code('playback_unavailable'),
      );
      expect(channel.playedCues, isEmpty);
      await source.dispose();
    });

    test(
      'play+record on a record-only channel fails before any start',
      () async {
        final channel = _RecordOnlyChannel();
        final source = controller(channel);
        final states = <AudioSurfaceState>[];
        final sub = source.status.listen(states.add);
        await source.start(
          sampleRate: 48000,
          sessionMode: AudioSessionMode.playAndRecord,
        );
        await pumpEventQueue();
        expect(channel.starts, 0);
        expect(
          states.whereType<AudioSetupFailed>().single.reason,
          'playback_unavailable',
        );
        // No owner was claimed: the legacy record-only start still works.
        await source.start(sampleRate: 48000);
        expect(channel.starts, 1);
        await sub.cancel();
        await source.dispose();
      },
    );
  });

  group('practiceTestClick', () {
    test('is a short, bounded, valid cue for both rates', () {
      for (final rate in [44100, 48000]) {
        final click = practiceTestClick(sampleRate: rate);
        expect(click.length, (rate * 0.03).round());
        expect(isValidCuePcm(click, rate), isTrue);
        expect(click.first, 0);
        expect(
          click.reduce((a, b) => a.abs() > b.abs() ? a : b).abs(),
          lessThanOrEqualTo(0.5),
        );
        expect(click.last.abs(), lessThan(0.001));
      }
      expect(() => practiceTestClick(sampleRate: 22050), throwsArgumentError);
      expect(
        () => practiceTestClick(
          sampleRate: 48000,
          duration: const Duration(seconds: 3),
        ),
        throwsArgumentError,
      );
    });
  });
}
