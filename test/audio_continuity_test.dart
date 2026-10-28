import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/audio/audio_continuity.dart';
import 'package:ostinato/app/audio/audio_capture_channel.dart';
import 'package:ostinato/app/audio/audio_input_controller.dart';
import 'package:ostinato/app/audio/guitar_note_observation_controller.dart';
import 'package:ostinato_audio/ostinato_audio.dart';
import 'package:permission_handler/permission_handler.dart';

final class TimestampSource implements AudioSource {
  final data = StreamController<AudioChunk>.broadcast();
  final states = StreamController<AudioSurfaceState>.broadcast();
  int stops = 0;
  @override
  Stream<AudioChunk> get chunks => data.stream;
  @override
  Stream<AudioSurfaceState> get status => states.stream;
  @override
  Future<void> start({required int sampleRate}) async =>
      states.add(const AudioCalibrating(AudioRoute.speaker));
  @override
  Future<void> stop() async {
    stops++;
  }

  void send(
    int time,
    int count, {
    AudioClockDomain domain = AudioClockDomain.monotonic,
  }) => data.add(
    AudioChunk(
      samples: List.filled(count, .001),
      sampleRate: 44100,
      tStartUs: time,
      clockDomain: domain,
    ),
  );
  Future<void> dispose() async {
    await data.close();
    await states.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(resetAudioCaptureCoordinatorForTest);
  test(
    'continuity handles jitter, gap, rate, duplicate, reverse and negative times',
    () {
      final clock = AudioContinuity();
      AudioContinuityResult send(int time, {int rate = 48000}) =>
          clock.observe(startUs: time, sampleRate: rate, sampleCount: 480);
      expect(send(0), AudioContinuityResult.continuous);
      expect(send(10001), AudioContinuityResult.continuous);
      expect(send(100000), AudioContinuityResult.recalibrate);
      expect(send(110000, rate: 44100), AudioContinuityResult.recalibrate);
      expect(send(110000), AudioContinuityResult.invalid);
      expect(send(1000), AudioContinuityResult.invalid);
      expect(send(-1), AudioContinuityResult.invalid);
      clock.reset();
      expect(send(0), AudioContinuityResult.continuous);
    },
  );
  test(
    'native input gap clears buffered audio before publishing new samples',
    () async {
      final channel = FakeAudioCaptureChannel();
      final input = AudioInputController(
        channel: channel,
        requestMicrophonePermission: () async => PermissionStatus.granted,
      );
      final states = <AudioSurfaceState>[];
      final subscription = input.status.listen(states.add);
      await input.start(sampleRate: 44100);
      channel.pushChunk(List.filled(441, .1), sampleRate: 44100, tNativeUs: 0);
      await pumpEventQueue();
      channel.pushChunk(
        List.filled(441, .1),
        sampleRate: 44100,
        tNativeUs: 1000000,
      );
      await pumpEventQueue();
      expect(input.bufferedSampleCountForTest, 441);
      expect(states.last, isA<AudioCalibrating>());
      channel.pushChunk(
        List.filled(441, .1),
        sampleRate: 44100,
        tNativeUs: 500000,
      );
      await pumpEventQueue();
      expect(channel.isRunning, isFalse);
      expect(input.bufferedSampleCountForTest, 0);
      expect((states.last as AudioSetupFailed).reason, 'invalid_audio_clock');
      await input.start(sampleRate: 44100);
      channel.pushChunk(List.filled(441, .1), sampleRate: 44100, tNativeUs: 0);
      await pumpEventQueue();
      expect(channel.isRunning, isTrue);
      expect(input.bufferedSampleCountForTest, 441);
      await subscription.cancel();
      await input.dispose();
      await channel.dispose();
    },
  );
  for (final mode in ['gap', 'reverse', 'unknownClock']) {
    test(
      'guitar source $mode cannot mix earlier samples or keep an old observation',
      () async {
        final source = TimestampSource();
        final config = GuitarObservationConfig.fromJson(
          jsonDecode(
                File(
                  'assets/config/guitar-observation.v2.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>,
        );
        var calls = 0;
        final controller = GuitarNoteObservationController(
          config: config,
          source: source,
          analyzer: (_, _, _, _) async {
            calls++;
            return const GuitarNoteObservationResult(
              reason: GuitarSingleNoteReason.observed,
              totalWindows: 3,
              reliableWindows: 3,
              observation: GuitarNoteObservation(
                hz: 220,
                midi: 57,
                centsFromCenter: 0,
              ),
            );
          },
        );
        await controller.start();
        await pumpEventQueue();
        source.send(0, 88200);
        await pumpEventQueue();
        source.send(2000000, 8192);
        await pumpEventQueue();
        expect(controller.observation, isNotNull);
        final before = calls;
        final publishedPhases = <NoteObservationPhase>[];
        controller.addListener(() => publishedPhases.add(controller.phase));
        source.send(
          mode == 'reverse' ? 100 : 5000000,
          100,
          domain: mode == 'unknownClock'
              ? AudioClockDomain.unknown
              : AudioClockDomain.monotonic,
        );
        await pumpEventQueue();
        expect(controller.observation, isNull);
        expect(
          publishedPhases,
          contains(
            mode == 'gap'
                ? NoteObservationPhase.calibrating
                : NoteObservationPhase.unavailable,
          ),
        );
        expect(controller.bufferedSamples, 0);
        expect(calls, before);
        expect(
          controller.phase,
          mode == 'gap'
              ? NoteObservationPhase.calibrating
              : NoteObservationPhase.unavailable,
        );
        if (mode != 'gap') expect(source.stops, 1);
        controller.dispose();
        await pumpEventQueue();
        await source.dispose();
      },
    );
  }
}
