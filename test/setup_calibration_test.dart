// F4.2 — kurulum: E50 gecikme kalibrasyonu (8 klik, ilk varış), rota başına
// yerel kayıt, oda + seviye adımı, iOS uyarıları ve pratik döngüsüne
// bağlantı (gecikme nota penceresine uygulanır; rota değişince rozet).
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/audio/audio_capture_channel.dart';
import 'package:ostinato/app/audio/audio_input_controller.dart';
import 'package:ostinato/app/practice/loop/practice_judge.dart';
import 'package:ostinato/app/practice/loop/practice_marks.dart';
import 'package:ostinato/app/practice/loop/practice_score.dart';
import 'package:ostinato/app/practice/loop/practice_session_controller.dart';
import 'package:ostinato/app/practice/loop/practice_transport.dart';
import 'package:ostinato/app/practice/setup/audio_environment.dart';
import 'package:ostinato/app/practice/setup/latency_calibration.dart';
import 'package:ostinato/app/practice/setup/setup_audio_controller.dart';
import 'package:ostinato/app/practice/setup/setup_profile_store.dart';
import 'package:ostinato_audio/ostinato_audio.dart';
import 'package:permission_handler/permission_handler.dart';

const rate = 48000;
const chunk = 4800; // 100 ms

/// Probe answering a fixed environment (no native side in tests).
final class FixedProbe extends AudioEnvironmentProbe {
  const FixedProbe(this.env);
  final AudioEnvironment env;
  @override
  Future<AudioEnvironment> read() async => env;
}

const speakerEnv = AudioEnvironment(
  platform: 'ios',
  inputPorts: ['BuiltInMic'],
  outputPorts: ['Speaker'],
);

Float64List noise(int samples, {int seed = 3, double level = .002}) {
  final r = math.Random(seed);
  return Float64List.fromList([
    for (var i = 0; i < samples; i++) (r.nextDouble() * 2 - 1) * level,
  ]);
}

void addAt(Float64List out, List<double> sound, int at, double gain) {
  for (var i = 0; i < sound.length && at + i < out.length; i++) {
    if (at + i >= 0) out[at + i] += gain * sound[i];
  }
}

/// The player damps the string as the next note starts: a 100 ms fade, not
/// a hard cut (a cut would itself read as an attack).
Float64List damped(Float64List p) {
  final fade = rate ~/ 10;
  for (var i = 0; i < fade; i++) {
    p[p.length - 1 - i] *= i / fade;
  }
  return p;
}

RouteLatency latencyOf(int ms) => RouteLatency(
  roundTripUs: ms * 1000,
  spreadUs: 100,
  heardClicks: 8,
  totalClicks: 8,
  measuredAt: DateTime.utc(2026, 11, 1),
);

AudioInputController audioOn(FakeAudioCaptureChannel channel) =>
    AudioInputController(
      channel: channel,
      requestMicrophonePermission: () async => PermissionStatus.granted,
      pcmDeliveryTimeout: const Duration(minutes: 5),
    );

Future<void> pushAll(
  FakeAudioCaptureChannel channel,
  Float64List data, {
  int startUs = 0,
  void Function(int index)? after,
}) async {
  for (var i = 0; i * chunk < data.length; i++) {
    final end = math.min((i + 1) * chunk, data.length);
    channel.pushChunk(
      data.sublist(i * chunk, end),
      sampleRate: rate,
      tNativeUs: startUs + i * chunk * 1000000 ~/ rate,
    );
    await pumpEventQueue();
    after?.call(i);
    await pumpEventQueue();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(resetAudioCaptureCoordinatorForTest);

  group('estimateRouteLatency (E50 first arrival)', () {
    final fpb = calibrationFramesPerBeat(rate);
    final click = calibrationClick(rate);

    CalibrationRecording rec(Float64List s, {int anchorUs = 500000}) =>
        CalibrationRecording(
          samples: s,
          sampleRate: rate,
          startUs: 0,
          anchorUs: anchorUs,
          framesPerBeat: fpb,
        );

    Float64List clicks(int lagMs, {double echo = 0, List<int>? jitter}) {
      final s = noise(6 * rate);
      for (var k = 0; k < 8; k++) {
        final at =
            rate ~/ 2 + k * fpb + lagMs * rate ~/ 1000 + (jitter?[k] ?? 0);
        addAt(s, click, at, .3);
        if (echo > 0) addAt(s, click, at + (.009 * rate).round(), echo);
      }
      return s;
    }

    test('measures the injected round trip despite a reflection', () {
      for (final ms in [40, 70, 240]) {
        final r = estimateRouteLatency(rec(clicks(ms, echo: .12)));
        expect(r, isA<LatencyMeasured>());
        final l = (r as LatencyMeasured).latency;
        expect(l.roundTripUs, closeTo(ms * 1000, 100));
        expect(l.heardClicks, 8);
        expect(
          l.latencyCorrectionUs(outputLatencyUs: 12000),
          l.roundTripUs - 12000,
        );
      }
    });

    test('silence is "not heard", never a number', () {
      expect(
        estimateRouteLatency(rec(noise(6 * rate))),
        isA<LatencyNotHeard>(),
      );
    });

    test('clicks at different delays are "unsteady"', () {
      final r = estimateRouteLatency(
        rec(clicks(70, jitter: [0, 960, 0, 960, 0, 960, 0, 960])),
      );
      expect(r, isA<LatencyUnsteady>());
    });
  });

  group('routes and warnings', () {
    test('output decides the calibration route', () {
      expect(
        calibrationRouteOf(AudioRoute.speaker, speakerEnv),
        CalibrationRoute.speaker,
      );
      const a2dp = AudioEnvironment(
        platform: 'ios',
        inputPorts: ['BuiltInMic'],
        outputPorts: ['BluetoothA2DP'],
      );
      expect(
        calibrationRouteOf(AudioRoute.speaker, a2dp),
        CalibrationRoute.bluetooth,
        reason: 'phone microphone, Bluetooth output: Bluetooth latency',
      );
      const wired = AudioEnvironment(
        platform: 'android',
        inputPorts: ['TYPE_BUILTIN_MIC'],
        outputPorts: ['TYPE_WIRED_HEADPHONES'],
      );
      expect(
        calibrationRouteOf(AudioRoute.speaker, wired),
        CalibrationRoute.wiredHeadset,
      );
      // No native report: the capture's input route.
      expect(
        calibrationRouteOf(AudioRoute.speaker, AudioEnvironment.unknown),
        CalibrationRoute.speaker,
      );
      expect(
        calibrationRouteOf(AudioRoute.unknown, AudioEnvironment.unknown),
        isNull,
      );
      const airplay = AudioEnvironment(
        platform: 'ios',
        outputPorts: ['AirPlay'],
      );
      expect(calibrationRouteOf(AudioRoute.speaker, airplay), isNull);
    });

    test('one-line warnings only for what was detected', () {
      expect(setupWarnings(speakerEnv), isEmpty);
      expect(setupWarnings(AudioEnvironment.unknown), isEmpty);
      final env = AudioEnvironment.fromWire({
        'platform': 'ios',
        'inputs': ['HeadsetMic'],
        'outputs': ['Headphones'],
        'micMode': 'voiceIsolation',
      });
      expect(setupWarnings(env), [
        SetupWarning.voiceIsolation,
        SetupWarning.headsetMic,
      ]);
      expect(
        setupWarnings(
          AudioEnvironment.fromWire({
            'platform': 'ios',
            'inputs': ['MicrophoneWired'],
            'micMode': 'wideSpectrum',
          }),
        ),
        [SetupWarning.wideSpectrum, SetupWarning.headsetMic],
      );
      expect(AudioEnvironment.fromWire('junk').isKnown, isFalse);
    });

    test('missing native method → unknown environment', () async {
      const probe = AudioEnvironmentProbe(
        channel: MethodChannel('test/no_such_channel'),
      );
      expect((await probe.read()).isKnown, isFalse);
    });
  });

  group('setup profile store', () {
    late Directory dir;
    setUp(() async => dir = await Directory.systemTemp.createTemp('setup'));
    tearDown(() async => dir.delete(recursive: true));

    test(
      'per-route latency and steps round trip; no audio in the file',
      () async {
        final store = FileSetupProfileStore(directoryProvider: () async => dir);
        expect((await store.load()).visited, isFalse);
        final at = DateTime.utc(2026, 11, 1);
        await store.update(
          (p) => p
              .withLatency(CalibrationRoute.speaker, latencyOf(64))
              .copyWith(
                placement: SetupStepRecord(SetupStepState.done, at),
                roomStep: SetupStepRecord(SetupStepState.skipped, at),
                latencyStep: SetupStepRecord(SetupStepState.done, at),
                tuningStep: SetupStepRecord(SetupStepState.skipped, at),
              ),
        );
        final p = await store.load();
        expect(p.visited, isTrue);
        expect(p.lastRoute, CalibrationRoute.speaker);
        expect(p.latencyFor(CalibrationRoute.speaker)!.roundTripUs, 64000);
        expect(p.latencyFor(CalibrationRoute.bluetooth), isNull);
        final raw = File(
          '${dir.path}/setup_profile.v1.json',
        ).readAsStringSync();
        expect(jsonDecode(raw)['schemaVersion'], 1);
        expect(raw, isNot(contains('samples')));
      },
    );

    test('a damaged file reads as uncalibrated', () async {
      File('${dir.path}/setup_profile.v1.json').writeAsStringSync('{"x":');
      final store = FileSetupProfileStore(directoryProvider: () async => dir);
      expect((await store.load()).latency, isEmpty);
    });
  });

  group('SetupAudioController', () {
    test('room: 2 s quiet → floor; a played string is heard', () async {
      final channel = FakeAudioCaptureChannel();
      final audio = audioOn(channel);
      final store = MemorySetupProfileStore();
      final c = SetupAudioController(audio: audio, store: store);
      await c.measureRoom();
      final data = noise(5 * rate);
      addAt(
        data,
        SyntheticString.pluck(f0Hz: 110, sampleRate: rate, seconds: 1),
        3 * rate,
        1,
      );
      await pushAll(channel, data);
      await pumpEventQueue();
      expect(c.phase, SetupAudioPhase.done);
      expect(c.room!.heard, isTrue);
      expect(c.room!.floorDb, closeTo(-59, 3));
      expect(store.profile.room!.heard, isTrue);
      expect(store.profile.roomStep!.state, SetupStepState.done);
      expect(channel.isRunning, isFalse, reason: 'capture closed after step');
      c.dispose();
      await audio.dispose();
    });

    test('room floor is told in three learner words, never a number', () {
      expect(roomNoiseFor(-70), RoomNoise.quiet);
      expect(roomNoiseFor(-59), RoomNoise.quiet);
      expect(roomNoiseFor(-50), RoomNoise.some);
      expect(roomNoiseFor(-45), RoomNoise.some);
      expect(roomNoiseFor(-40), RoomNoise.loud);
      final wizard = File(
        'lib/app/practice/setup/setup_wizard_screen.dart',
      ).readAsStringSync();
      expect(wizard, isNot(contains('dBFS')));
      expect(wizard, isNot(contains('floorDb.round')));
    });

    test('room: nothing played in 10 s → not heard (no score)', () async {
      final channel = FakeAudioCaptureChannel();
      final audio = audioOn(channel);
      final c = SetupAudioController(
        audio: audio,
        store: MemorySetupProfileStore(),
      );
      await c.measureRoom();
      await pushAll(channel, noise(13 * rate));
      await pumpEventQueue();
      expect(c.room!.heard, isFalse);
      c.dispose();
      await audio.dispose();
    });

    test('latency: 8 clicks on the stream → stored for the route', () async {
      final channel = FakeAudioCaptureChannel();
      final audio = audioOn(channel);
      final store = MemorySetupProfileStore();
      final c = SetupAudioController(
        audio: audio,
        store: store,
        environment: const FixedProbe(speakerEnv),
        estimator: (r) async => estimateRouteLatency(r),
      );
      await c.calibrateLatency();
      expect(channel.sessionMode, AudioSessionMode.playAndRecord);
      channel.pushRouteChange('ios:BuiltInMic');
      await pumpEventQueue();
      // Anchor at 0.5 s; the room returns each click 83 ms later.
      const anchorUs = 500000;
      final fpb = calibrationFramesPerBeat(rate);
      final data = noise(7 * rate);
      for (var k = 0; k < 8; k++) {
        addAt(
          data,
          calibrationClick(rate),
          rate ~/ 2 + k * fpb + 83 * rate ~/ 1000,
          .3,
        );
      }
      await pushAll(
        channel,
        data,
        after: (i) {
          if (i == 0) {
            expect(channel.metronome!.framesPerBeat, fpb);
            channel.pushMetronomeAnchor(anchorUs, outputLatencyUs: 12000);
          }
        },
      );
      for (var i = 0; i < 5 && c.phase != SetupAudioPhase.done; i++) {
        await pumpEventQueue();
      }
      expect(c.failure, isNull);
      expect(c.phase, SetupAudioPhase.done);
      final measured = (c.latency! as LatencyMeasured).latency;
      expect(measured.roundTripUs, closeTo(83000, 100));
      expect(c.route, CalibrationRoute.speaker);
      expect(
        store.profile.latencyFor(CalibrationRoute.speaker)!.roundTripUs,
        measured.roundTripUs,
      );
      expect(store.profile.latencyStep!.state, SetupStepState.done);
      expect(channel.metronome, isNull);
      expect(channel.isRunning, isFalse);
      c.dispose();
      await audio.dispose();
    });

    test('latency: no anchor → "no clicks", nothing stored', () async {
      final channel = FakeAudioCaptureChannel();
      final audio = audioOn(channel);
      final store = MemorySetupProfileStore();
      final c = SetupAudioController(
        audio: audio,
        store: store,
        anchorTimeout: const Duration(milliseconds: 10),
      );
      await c.calibrateLatency();
      await pushAll(channel, noise(rate ~/ 2));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await pumpEventQueue();
      expect(c.phase, SetupAudioPhase.failed);
      expect(c.failure, 'no_clicks');
      expect(store.profile.latency, isEmpty);
      c.dispose();
      await audio.dispose();
    });
  });

  group('practice loop uses the route calibration', () {
    Future<PracticeSessionController> run({
      required SetupProfileStore store,
      String route = 'ios:BuiltInMic',
      AudioEnvironment env = AudioEnvironment.unknown,
    }) async {
      final channel = FakeAudioCaptureChannel();
      final audio = audioOn(channel);
      var local = 0;
      final c = PracticeSessionController(
        score: PracticeScore.parse('E2 F2 G2 F2'),
        tempo: PracticeTempo(openBpm: 60, targetBpm: 60),
        audio: audio,
        analyzer: (r) async => judgeNote(r),
        localClockUs: () => local,
        setup: store,
        environment: FixedProbe(env),
      );
      await c.start();
      channel.pushRouteChange(route);
      await pumpEventQueue();
      // Anchor 1 s, native output latency 12 ms, real round trip 70 ms; the
      // learner plays on the heard click, 5 ms late.
      final data = noise(11 * rate);
      for (var k = 0; k < 4; k++) {
        final us = 1000000 + (4 + k) * 1000000 + 70000 + 5000;
        addAt(
          data,
          damped(
            SyntheticString.pluck(
              f0Hz:
                  440 * math.pow(2, ([40, 41, 43, 41][k] - 69) / 12).toDouble(),
              sampleRate: rate,
              seconds: 1.05,
              seed: k,
            ),
          ),
          us * rate ~/ 1000000,
          1,
        );
      }
      for (var i = 0; i * chunk < data.length; i++) {
        final t = i * chunk * 1000000 ~/ rate;
        channel.pushChunk(
          data.sublist(i * chunk, (i + 1) * chunk),
          sampleRate: rate,
          tNativeUs: t,
        );
        local = t + 100000;
        await pumpEventQueue();
        if (i == 0) {
          channel.pushMetronomeAnchor(1000000, outputLatencyUs: 12000);
          await pumpEventQueue();
        }
        c.tick();
        await pumpEventQueue();
        if (c.phase == PracticePhase.finished) break;
      }
      addTearDown(() async {
        c.dispose();
        await audio.dispose();
      });
      return c;
    }

    test(
      'stored speaker latency → timing judged, correction applied',
      () async {
        final store = MemorySetupProfileStore(
          SetupProfile.empty.withLatency(
            CalibrationRoute.speaker,
            latencyOf(70),
          ),
        );
        final c = await run(store: store);
        expect(c.phase, PracticePhase.finished);
        expect(c.calibrationRoute, CalibrationRoute.speaker);
        expect(c.timingCalibrated, isTrue);
        expect(c.timeline!.latencyCorrectionUs, 70000 - 12000);
        expect(
          c.outcomes.map((o) => o.mark),
          everyElement(PracticeMark.correct),
        );
        for (final o in c.outcomes) {
          expect(o.timingMs, isNotNull);
          expect(
            o.timingMs!.abs(),
            lessThan(20),
            reason: '${[for (final x in c.outcomes) x.timingMs]}',
          );
        }
        expect(c.summary!.timingCalibrated, isTrue);
        expect(c.summary!.medianTimingMs, isNotNull);
      },
    );

    test('no calibration for this route → badge stays, no timing', () async {
      final store = MemorySetupProfileStore(
        SetupProfile.empty.withLatency(
          CalibrationRoute.bluetooth,
          latencyOf(220),
        ),
      );
      final c = await run(store: store);
      expect(c.calibrationRoute, CalibrationRoute.speaker);
      expect(c.timingCalibrated, isFalse);
      expect(c.timeline!.latencyCorrectionUs, 0);
      expect(c.outcomes.every((o) => o.timingMs == null), isTrue);
      expect(store.profile.lastRoute, CalibrationRoute.speaker);
    });

    test(
      'Bluetooth output uses the Bluetooth value, not the speaker one',
      () async {
        final store = MemorySetupProfileStore(
          SetupProfile.empty
              .withLatency(CalibrationRoute.speaker, latencyOf(70))
              .withLatency(CalibrationRoute.bluetooth, latencyOf(220)),
        );
        final c = await run(
          store: store,
          env: const AudioEnvironment(
            platform: 'ios',
            inputPorts: ['BuiltInMic'],
            outputPorts: ['BluetoothA2DP'],
          ),
        );
        expect(c.calibrationRoute, CalibrationRoute.bluetooth);
        expect(c.timeline!.latencyCorrectionUs, 220000 - 12000);
      },
    );
  });
}
