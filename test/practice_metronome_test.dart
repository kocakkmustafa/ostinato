// F2.2 — metronom: örnek doğruluklu ızgara, 6 kHz klik, zaman çizelgesi,
// native akış sözleşmesi (Dart tarafı).
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/audio/audio_capture_channel.dart';
import 'package:ostinato/app/audio/audio_input_controller.dart';
import 'package:ostinato/app/practice/loop/metronome.dart';
import 'package:ostinato/app/practice/loop/metronome_beat_view.dart';
import 'package:ostinato_audio/ostinato_audio.dart';
import 'package:permission_handler/permission_handler.dart';

import 'support/practice_host.dart';

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

/// Share of power within ±[halfBand] Hz of [hz].
double _bandShare(List<double> x, int sampleRate, double hz, double halfBand) {
  final n = nextPowerOfTwo(x.length);
  final spec = magnitudeSpectrum(
    Float64List.fromList(x),
    blackmanHarris(x.length),
    n,
  );
  final binHz = sampleRate / n;
  var band = 0.0, all = 0.0;
  for (var k = 1; k < spec.length; k++) {
    final p = spec[k] * spec[k];
    all += p;
    if ((k * binHz - hz).abs() <= halfBand) band += p;
  }
  return band / all;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MetronomePlan', () {
    test('beats sit on whole frames and never drift', () {
      final plan = MetronomePlan(bpm: 60, sampleRate: 48000);
      expect(plan.framesPerBeat, 48000);
      expect(plan.clickFrame(1000), 48000000);
      final odd = MetronomePlan(bpm: 73, sampleRate: 44100);
      expect(odd.framesPerBeat, (44100 * 60 / 73).round());
      // Tempo error from whole-frame rounding is negligible.
      final realBpm = 44100 * 60 / odd.framesPerBeat;
      expect((realBpm - 73).abs() / 73, lessThan(3e-5));
    });

    test('accent on the bar, count-in of one or two bars', () {
      final plan = MetronomePlan(
        bpm: 90,
        sampleRate: 48000,
        beatsPerBar: 3,
        countInBars: 2,
      );
      expect(plan.countInBeats, 6);
      expect(
        [for (var b = 0; b < 7; b++) plan.isAccent(b)],
        [true, false, false, true, false, false, true],
      );
    });

    test('rejects unsupported rates, tempos and count-ins', () {
      expect(
        () => MetronomePlan(bpm: 60, sampleRate: 22050),
        throwsArgumentError,
      );
      expect(
        () => MetronomePlan(bpm: 10, sampleRate: 48000),
        throwsArgumentError,
      );
      expect(
        () => MetronomePlan(bpm: 60, sampleRate: 48000, countInBars: 3),
        throwsArgumentError,
      );
    });
  });

  group('click', () {
    test('energy sits at 6 kHz, above the 4 kHz detector band', () {
      for (final rate in [44100, 48000]) {
        final clicks = MetronomeClicks.forSampleRate(rate);
        for (final c in [clicks.accent, clicks.beat]) {
          expect(c.every((v) => v.abs() <= 1), isTrue);
          expect(_bandShare(c, rate, 6000, 1500), greaterThan(0.97));
          expect(_bandShare(c, rate, 2000, 2000), lessThan(0.01));
        }
      }
    });

    test('does not trigger the onset detector', () {
      const rate = 48000;
      final plan = MetronomePlan(bpm: 120, sampleRate: rate);
      final track = ClickTrackRenderer(
        plan,
        MetronomeClicks.forSampleRate(rate),
      ).render(0, rate * 2);
      expect(
        const OnsetDetector().detect(track, sampleRate: rate, tStartUs: 0),
        isEmpty,
      );
    });
  });

  group('ClickTrackRenderer', () {
    test('every click starts exactly on its beat frame', () {
      const rate = 44100;
      final plan = MetronomePlan(bpm: 97, sampleRate: rate);
      final clicks = MetronomeClicks.forSampleRate(rate);
      final track = ClickTrackRenderer(plan, clicks).render(0, rate * 6);
      for (var beat = 0; plan.clickFrame(beat) < track.length - 2000; beat++) {
        final at = plan.clickFrame(beat);
        final click = plan.isAccent(beat) ? clicks.accent : clicks.beat;
        expect(track[at], 0, reason: 'beat $beat frame 0');
        for (var k = 1; k < 40; k++) {
          expect(track[at + k], click[k], reason: 'beat $beat +$k');
        }
        if (at > 0) {
          expect(track[at - 1], 0, reason: 'silence before beat $beat');
        }
      }
    });

    test('rendering in blocks equals rendering at once', () {
      const rate = 48000;
      final renderer = ClickTrackRenderer(
        MetronomePlan(bpm: 133, sampleRate: rate),
        MetronomeClicks.forSampleRate(rate),
      );
      final whole = renderer.render(0, rate * 3);
      final parts = <double>[];
      for (var f = 0; f < rate * 3; f += 256) {
        parts.addAll(renderer.render(f, math.min(256, rate * 3 - f)));
      }
      expect(parts, whole);
    });
  });

  group('MetronomeTimeline', () {
    test('maps beats to the capture clock and back', () {
      const t = MetronomeTimeline(
        anchorUs: 5000000,
        sampleRate: 48000,
        framesPerBeat: 24000,
        source: MetronomeAnchorSource.native,
        outputLatencyUs: 12000,
      );
      expect(t.beatUs, 500000);
      expect(t.beatTimeUs(0), 5012000);
      expect(t.beatTimeUs(4), 7012000);
      expect(t.beatTimeUs(1.5), 5762000);
      expect(t.beatAt(7012000), 4);
      expect(t.beatAt(5012000 - 250000), -0.5);
      expect(t.calibrated, isFalse);
    });

    test('beat state for the visual beat and the count-in', () {
      const t = MetronomeTimeline(
        anchorUs: 0,
        sampleRate: 48000,
        framesPerBeat: 48000,
        source: MetronomeAnchorSource.silent,
      );
      MetronomeBeatState at(int us) =>
          MetronomeBeatState.at(t, us, beatsPerBar: 4, countInBeats: 4);
      expect(at(-1).beat, -1);
      expect(at(-1).countInRemaining, 4);
      expect(at(0).countInRemaining, 4);
      expect(at(0).beatInBar, 0);
      expect(at(2500000).countInRemaining, 2);
      expect(at(2500000).phase, closeTo(.5, 1e-9));
      expect(at(4000000).inCountIn, isFalse);
      expect(at(5000000).beatInBar, 1);
    });
  });

  test('CaptureClockEstimator follows chunks and never runs backwards', () {
    final clock = CaptureClockEstimator();
    expect(clock.nowUs(0), isNull);
    clock.observeChunk(
      tStartUs: 1000000,
      sampleCount: 4800,
      sampleRate: 48000,
      localNowUs: 50,
    );
    expect(clock.nowUs(50), 1100000);
    expect(clock.nowUs(10050), 1110000);
    // A late chunk whose end lies behind the extrapolation does not rewind.
    clock.observeChunk(
      tStartUs: 1100000,
      sampleCount: 240,
      sampleRate: 48000,
      localNowUs: 10060,
    );
    expect(clock.nowUs(10060), 1110000);
    expect(clock.nowUs(20060), 1115000);
  });

  group('MetronomeStreamRequest', () {
    MetronomeStreamRequest request({int fpb = 24000, Float64List? accent}) {
      final c = MetronomeClicks.forSampleRate(48000);
      return MetronomeStreamRequest(
        sampleRate: 48000,
        framesPerBeat: fpb,
        beatsPerBar: 4,
        accent: accent ?? c.accent,
        beat: c.beat,
      );
    }

    test('validates tempo range and click shape', () {
      expect(request().isValid, isTrue);
      expect(request(fpb: 48000 * 60 ~/ 400).isValid, isFalse);
      expect(request(fpb: 48000 * 4).isValid, isFalse);
      expect(request(accent: Float64List.fromList([2])).isValid, isFalse);
      expect(request(accent: Float64List(0)).isValid, isFalse);
    });
  });

  group('metronome wire', () {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final calls = <MethodCall>[];
    setUp(() {
      calls.clear();
      messenger.setMockMethodCallHandler(events, (call) async => null);
      messenger.setMockMethodCallHandler(method, (call) async {
        calls.add(call);
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

    test('start/stop carry the attempt and the exact stream fields', () async {
      final channel = MethodChannelAudioCaptureChannel();
      final clicks = MetronomeClicks.forSampleRate(48000);
      final req = MetronomeStreamRequest(
        sampleRate: 48000,
        framesPerBeat: 48000,
        beatsPerBar: 3,
        accent: clicks.accent,
        beat: clicks.beat,
      );
      await expectLater(
        channel.startMetronome(req),
        _code('playback_unavailable'),
      );
      await channel.startPlayAndRecord(sampleRate: 48000, claim: testClaim);
      await channel.startMetronome(req);
      final start = calls.firstWhere((c) => c.method == 'startMetronome');
      final args = Map<String, Object?>.from(start.arguments as Map);
      expect(args.keys.toSet(), {
        'attemptId',
        'sampleRate',
        'framesPerBeat',
        'beatsPerBar',
        'accent',
        'beat',
        'leadInMs',
      });
      expect(args['attemptId'], channel.attemptId);
      expect(args['framesPerBeat'], 48000);
      await channel.stopMetronome();
      expect(calls.last.method, 'stopMetronome');
      await channel.stop();
    });

    test('anchor event is parsed for the current attempt only', () async {
      final channel = MethodChannelAudioCaptureChannel();
      final received = <RawAudioEvent>[];
      final sub = channel.events.listen(received.add);
      await channel.startPlayAndRecord(sampleRate: 48000, claim: testClaim);
      Future<void> send(Object value) async {
        messenger.handlePlatformMessage(
          events.name,
          const StandardMethodCodec().encodeSuccessEnvelope(value),
          (_) {},
        );
        await pumpEventQueue();
      }

      await send({
        'type': 'metronomeAnchor',
        'attemptId': 'someone-else',
        'anchorUs': 1,
        'sampleRate': 48000,
        'framesPerBeat': 48000,
      });
      await send({
        'type': 'metronomeAnchor',
        'attemptId': channel.attemptId,
        'anchorUs': 123456,
        'sampleRate': 48000,
        'framesPerBeat': 48000,
        'outputLatencyUs': 9000,
      });
      final anchor = received.single as RawMetronomeAnchorEvent;
      expect(anchor.anchorUs, 123456);
      expect(anchor.outputLatencyUs, 9000);
      await channel.stop();
      await sub.cancel();
    });
  });

  group('AudioInputController metronome', () {
    setUp(resetAudioCaptureCoordinatorForTest);

    AudioInputController controller(AudioCaptureChannel channel) =>
        AudioInputController(
          channel: channel,
          requestMicrophonePermission: () async => PermissionStatus.granted,
        );

    MetronomeStreamRequest request() {
      final c = MetronomeClicks.forSampleRate(48000);
      return MetronomeStreamRequest(
        sampleRate: 48000,
        framesPerBeat: 48000,
        beatsPerBar: 4,
        accent: c.accent,
        beat: c.beat,
      );
    }

    test('runs only inside a play+record attempt; anchors flow', () async {
      final channel = FakeAudioCaptureChannel();
      final source = controller(channel);
      await expectLater(
        source.startMetronome(request()),
        _code('playback_unavailable'),
      );
      await source.start(
        sampleRate: 48000,
        sessionMode: AudioSessionMode.playAndRecord,
      );
      final anchors = <MetronomeAnchor>[];
      final sub = source.metronomeAnchors.listen(anchors.add);
      await source.startMetronome(request());
      expect(channel.metronome, isNotNull);
      channel.pushMetronomeAnchor(777, outputLatencyUs: 5);
      await pumpEventQueue();
      expect(anchors.single.anchorUs, 777);
      expect(anchors.single.outputLatencyUs, 5);
      await source.stopMetronome();
      expect(channel.metronome, isNull);
      expect(channel.isRunning, isTrue);
      await sub.cancel();
      await source.dispose();
    });

    test('record-only refuses; a failed start never stops capture', () async {
      final channel = FakeAudioCaptureChannel();
      final source = controller(channel);
      await source.start(sampleRate: 48000);
      await expectLater(
        source.startMetronome(request()),
        _code('playback_not_enabled'),
      );
      await source.stop();
      await source.start(
        sampleRate: 48000,
        sessionMode: AudioSessionMode.playAndRecord,
      );
      channel.failNextMetronome = true;
      await expectLater(
        source.startMetronome(request()),
        _code('playback_failed'),
      );
      expect(channel.isRunning, isTrue);
      await source.dispose();
      expect(channel.metronome, isNull);
    });
  });

  testWidgets('visual beat: count-in number, then the beat dot moves', (
    tester,
  ) async {
    const t = MetronomeTimeline(
      anchorUs: 0,
      sampleRate: 48000,
      framesPerBeat: 48000,
      source: MetronomeAnchorSource.silent,
    );
    Future<void> show(int us, String locale) => tester.pumpWidget(
      practiceHost(
        locale: locale,
        Scaffold(
          body: MetronomeBeatView(
            beatsPerBar: 4,
            state: MetronomeBeatState.at(
              t,
              us,
              beatsPerBar: 4,
              countInBeats: 4,
            ),
          ),
        ),
      ),
    );
    await show(1200000, 'tr');
    await tester.pumpAndSettle();
    expect(find.text('3'), findsOneWidget);
    expect(find.bySemanticsLabel('Ön sayım: 3'), findsOneWidget);
    await show(5100000, 'en');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('metronome-count-in')), findsNothing);
    expect(find.bySemanticsLabel('Beat 2'), findsOneWidget);
    final dot = tester.widget<AnimatedContainer>(
      find.byKey(const Key('metronome-dot-1')),
    );
    expect((dot.decoration! as BoxDecoration).color, isNot(Colors.transparent));
  });
}
