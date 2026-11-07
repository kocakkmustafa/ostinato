// OST-P0-02 — örnekleme hızı (sample-rate) kanıtı.
//
// Mevcut davranış (kaynaktan okundu, uydurma değil):
//  * Yalnız 44.1 ve 48 kHz kabul edilir: `isValidCuePcm`,
//    `MetronomeStreamRequest.isValid`, `FakeAudioCaptureChannel.start`
//    (`unsupported_sample_rate`), Kotlin `record.sampleRate !in {44100,48000}`.
//  * Desteklenmeyen hız YENİDEN ÖRNEKLENMEZ ve sessizce DEĞİŞTİRİLMEZ; ad
//    verilerek reddedilir (`AudioUnavailable('unsupported_sample_rate:N')`).
//  * Akış ortasında hız değişirse (`AudioContinuity`) tampon temizlenir ve
//    `AudioCalibrating` yayılır.
//  * Dart tarafı gelen parçanın hızını 44.1/48 ile SINIRLAMAZ (yalnız >0);
//    o denetim native'dedir. Bu dosya o boşluğu kapatmaz, yalnız belgeler.
//
// NOT: 44,1/48 kHz reddi bu testte `FakeAudioCaptureChannel.
// supportedSampleRates` ve controller katmanında sınanır;
// `MethodChannelAudioCaptureChannel._start` hızı doğrulamaz, native
// (Kotlin/Swift) doğrular — native davranış TEST_ONLY kapsam dışıdır.
//
// TEST_ONLY: sentetik loopback + sahte kanal; gerçek cihazda ölçüm yapılmadı.
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/audio/audio_capture_channel.dart';
import 'package:ostinato/app/audio/audio_input_controller.dart';
import 'package:ostinato/app/practice/setup/audio_environment.dart';
import 'package:ostinato/app/practice/setup/latency_calibration.dart';
import 'package:ostinato/app/practice/setup/setup_audio_controller.dart';
import 'package:ostinato/app/practice/setup/setup_profile_store.dart';
import 'package:ostinato_audio/ostinato_audio.dart';
import 'package:permission_handler/permission_handler.dart';

Future<PermissionStatus> _granted() async => PermissionStatus.granted;

Float64List _noise(int n, {int seed = 3, double level = .002}) {
  final r = math.Random(seed);
  return Float64List.fromList([
    for (var i = 0; i < n; i++) (r.nextDouble() * 2 - 1) * level,
  ]);
}

void _addAt(Float64List out, List<double> s, int at, double gain) {
  for (var i = 0; i < s.length && at + i < out.length; i++) {
    if (at + i >= 0) out[at + i] += gain * s[i];
  }
}

/// Synthetic loopback: 8 calibration clicks, each returning [lagMs] later.
Float64List _loopback(
  int rate,
  int lagMs, {
  double echo = 0,
  List<int>? jitter,
  int anchorUs = 500000,
}) {
  final fpb = calibrationFramesPerBeat(rate);
  final click = calibrationClick(rate);
  final s = _noise(7 * rate);
  final anchor = anchorUs * rate ~/ 1000000;
  for (var k = 0; k < 8; k++) {
    final at = anchor + k * fpb + lagMs * rate ~/ 1000 + (jitter?[k] ?? 0);
    _addAt(s, click, at, .3);
    if (echo > 0) _addAt(s, click, at + (.009 * rate).round(), echo);
  }
  return s;
}

CalibrationRecording _rec(Float64List s, int rate, {int anchorUs = 500000}) =>
    CalibrationRecording(
      samples: s,
      sampleRate: rate,
      startUs: 0,
      anchorUs: anchorUs,
      framesPerBeat: calibrationFramesPerBeat(rate),
    );

AudioInputController _audio(FakeAudioCaptureChannel c) => AudioInputController(
  channel: c,
  requestMicrophonePermission: _granted,
  pcmDeliveryTimeout: const Duration(minutes: 5),
);

final class _Probe extends AudioEnvironmentProbe {
  const _Probe();
  @override
  Future<AudioEnvironment> read() async => const AudioEnvironment(
    platform: 'ios',
    inputPorts: ['BuiltInMic'],
    outputPorts: ['Speaker'],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(resetAudioCaptureCoordinatorForTest);

  group('(d) kalibrasyon 44.1 ve 48 kHz\'de tutarlı', () {
    test('click template has the same duration at both rates', () {
      final n44 = calibrationClick(44100).length;
      final n48 = calibrationClick(48000).length;
      expect((n44 * 1000 / 44100 - n48 * 1000 / 48000).abs(), lessThan(.05));
      expect(n44, lessThan(n48));
    });

    test('frames per beat scale with the rate (same 100 BPM)', () {
      expect(calibrationFramesPerBeat(44100), 26460);
      expect(calibrationFramesPerBeat(48000), 28800);
    });

    test('the same injected round trip reads the same at 44.1 and 48 kHz', () {
      for (final ms in [30, 40, 70, 83, 240, 320, 480]) {
        final us = <int, int>{};
        for (final rate in [44100, 48000]) {
          final r = estimateRouteLatency(
            _rec(_loopback(rate, ms, echo: .12), rate),
          );
          expect(r, isA<LatencyMeasured>(), reason: '$ms ms @ $rate');
          final l = (r as LatencyMeasured).latency;
          expect(l.heardClicks, 8, reason: '$ms ms @ $rate');
          // One sample at 44.1 kHz is 22.7 µs; 100 µs is the repo's bar.
          expect(l.roundTripUs, closeTo(ms * 1000, 100), reason: '@ $rate');
          us[rate] = l.roundTripUs;
        }
        expect(
          (us[44100]! - us[48000]!).abs(),
          lessThan(100),
          reason: '$ms ms: ${us[44100]} µs @44.1k vs ${us[48000]} µs @48k',
        );
      }
    });

    test(
      'silence is "not heard" and a drifting echo is "unsteady" at 44.1k',
      () {
        const rate = 44100;
        expect(
          estimateRouteLatency(_rec(_noise(7 * rate), rate)),
          isA<LatencyNotHeard>(),
        );
        // 12 ms of per-click jitter is above the 8 ms spread limit.
        final jitter = [for (var k = 0; k < 8; k++) k.isEven ? 0 : 529];
        final r = estimateRouteLatency(
          _rec(_loopback(rate, 70, jitter: jitter), rate),
        );
        expect(r, isA<LatencyUnsteady>());
        expect(
          (r as LatencyUnsteady).spreadUs,
          greaterThan(kCalibrationMaxSpreadMs * 1000),
        );
      },
    );

    test('the click-to-sample bookkeeping honours the rate', () {
      final r44 = _rec(Float64List(10), 44100);
      final r48 = _rec(Float64List(10), 48000);
      expect(r44.clickIndices.first, 22050); // 0.5 s
      expect(r48.clickIndices.first, 24000);
      expect(r44.clickIndices[1] - r44.clickIndices[0], 26460);
      expect(r48.clickIndices[1] - r48.clickIndices[0], 28800);
    });

    for (final rate in [44100, 48000]) {
      test(
        'SetupAudioController end to end at $rate Hz stores the route',
        () async {
          final channel = FakeAudioCaptureChannel();
          final audio = _audio(channel);
          final store = MemorySetupProfileStore();
          final c = SetupAudioController(
            audio: audio,
            store: store,
            environment: const _Probe(),
            sampleRate: rate,
            estimator: (r) async => estimateRouteLatency(r),
          );
          await c.calibrateLatency();
          expect(channel.isRunning, isTrue);
          channel.pushRouteChange('ios:BuiltInMic');
          await pumpEventQueue();
          final fpb = calibrationFramesPerBeat(rate);
          final data = _loopback(rate, 83);
          final chunk = rate ~/ 10;
          for (var i = 0; i * chunk < data.length; i++) {
            final end = math.min((i + 1) * chunk, data.length);
            channel.pushChunk(
              data.sublist(i * chunk, end),
              sampleRate: rate,
              tNativeUs: i * chunk * 1000000 ~/ rate,
            );
            await pumpEventQueue();
            if (i == 0) {
              expect(channel.metronome!.sampleRate, rate);
              expect(channel.metronome!.framesPerBeat, fpb);
              channel.pushMetronomeAnchor(500000, outputLatencyUs: 12000);
              await pumpEventQueue();
            }
          }
          for (var i = 0; i < 5 && c.phase != SetupAudioPhase.done; i++) {
            await pumpEventQueue();
          }
          expect(c.failure, isNull);
          expect(c.phase, SetupAudioPhase.done);
          final l = (c.latency! as LatencyMeasured).latency;
          expect(l.roundTripUs, closeTo(83000, 100));
          expect(store.profile.latencyFor(CalibrationRoute.speaker), isNotNull);
          c.dispose();
          await audio.dispose();
        },
      );
    }
  });

  group('(d) yalnız 44.1/48 kHz kabul; diğeri ad verilerek reddedilir', () {
    test('PCM cue and metronome request accept exactly 44.1 and 48 kHz', () {
      final pcm = Float64List.fromList([.1, -.1, .2]);
      for (final rate in [44100, 48000]) {
        expect(isValidCuePcm(pcm, rate), isTrue, reason: '$rate');
      }
      for (final rate in [0, 8000, 16000, 22050, 32000, 88200, 96000]) {
        expect(isValidCuePcm(pcm, rate), isFalse, reason: '$rate');
      }
      MetronomeStreamRequest req(int rate) => MetronomeStreamRequest(
        sampleRate: rate,
        framesPerBeat: calibrationFramesPerBeat(rate),
        beatsPerBar: 4,
        accent: calibrationClick(rate),
        beat: calibrationClick(rate),
      );
      expect(req(44100).isValid, isTrue);
      expect(req(48000).isValid, isTrue);
      expect(req(22050).isValid, isFalse);
      expect(req(96000).isValid, isFalse);
    });

    test(
      'each unsupported start rate is named and nothing is buffered',
      () async {
        for (final rate in [8000, 22050, 32000, 88200]) {
          final channel = FakeAudioCaptureChannel();
          final controller = _audio(channel);
          final states = <AudioSurfaceState>[];
          final sub = controller.status.listen(states.add);
          await controller.start(sampleRate: rate);
          await pumpEventQueue();
          expect(
            (states.last as AudioUnavailable).reason,
            'unsupported_sample_rate:$rate',
          );
          expect(channel.isRunning, isFalse);
          expect(controller.bufferedSampleCountForTest, 0);
          await sub.cancel();
          await controller.dispose();
        }
      },
    );

    for (final rate in [44100, 48000]) {
      test('$rate Hz starts and buffers', () async {
        final channel = FakeAudioCaptureChannel();
        final controller = _audio(channel);
        await controller.start(sampleRate: rate);
        await pumpEventQueue();
        expect(channel.isRunning, isTrue);
        channel.pushChunk(
          List<double>.filled(rate ~/ 100, .1),
          sampleRate: rate,
          tNativeUs: 0,
        );
        await pumpEventQueue();
        expect(controller.bufferedSampleCountForTest, rate ~/ 100);
        await controller.stop();
        expect(controller.bufferedSampleCountForTest, 0);
        await controller.dispose();
      });
    }

    test(
      'a rate change mid-stream clears the buffer and recalibrates',
      () async {
        final channel = FakeAudioCaptureChannel();
        final controller = _audio(channel);
        final states = <AudioSurfaceState>[];
        final sub = controller.status.listen(states.add);
        await controller.start(sampleRate: 48000);
        await pumpEventQueue();
        channel.pushChunk(
          List<double>.filled(480, .1),
          sampleRate: 48000,
          tNativeUs: 0,
        );
        await pumpEventQueue();
        expect(controller.bufferedSampleCountForTest, 480);
        states.clear();
        // The hardware renegotiated to 44.1 kHz (e.g. a route change).
        channel.pushChunk(
          List<double>.filled(441, .1),
          sampleRate: 44100,
          tNativeUs: 10000,
        );
        await pumpEventQueue();
        expect(states, contains(isA<AudioCalibrating>()));
        expect(
          controller.bufferedSampleCountForTest,
          441,
          reason:
              'old 48 kHz samples are dropped, not mixed with 44.1 kHz ones',
        );
        await sub.cancel();
        await controller.dispose();
      },
    );
  });
}
