// Ritim-yalnız diziler (A3 onset zamanlaması): sınıflama dışı saf mantık,
// sentetik el çırpma / tel çekme ile uçtan uca yargı (kalibrasyonlu ve
// kalibrasyonsuz), özet + geçiş kapısı, sonuç ekranı ve pratik ekranı.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/audio/audio_capture_channel.dart';
import 'package:ostinato/app/audio/audio_input_controller.dart';
import 'package:ostinato/app/curriculum/v1_lesson.dart';
import 'package:ostinato/app/practice/loop/practice_judge.dart';
import 'package:ostinato/app/practice/loop/practice_loop_screen.dart';
import 'package:ostinato/app/practice/loop/practice_marks.dart';
import 'package:ostinato/app/practice/loop/practice_outcome.dart';
import 'package:ostinato/app/practice/loop/practice_progress_store.dart';
import 'package:ostinato/app/practice/loop/practice_result_screen.dart';
import 'package:ostinato/app/practice/loop/practice_rhythm.dart';
import 'package:ostinato/app/practice/loop/practice_score.dart';
import 'package:ostinato/app/practice/loop/practice_session_controller.dart';
import 'package:ostinato/app/practice/loop/practice_transport.dart';
import 'package:ostinato/app/practice/loop/v1_practice_catalog.dart';
import 'package:ostinato/app/practice/setup/audio_environment.dart';
import 'package:ostinato/app/practice/setup/latency_calibration.dart';
import 'package:ostinato/app/practice/setup/setup_profile_store.dart';
import 'package:ostinato_audio/ostinato_audio.dart';
import 'package:permission_handler/permission_handler.dart';

import 'support/practice_host.dart';

const rate = 48000;
const chunk = 4800; // 100 ms

V1Lesson bundled(String id) => V1Lesson.fromJson(
  jsonDecode(File('content/v1/gtr/$id.json').readAsStringSync()),
);

/// A hand clap: a short noise burst, 2 ms rise, ~25 ms decay.
Float64List clap(int seed) {
  final rng = math.Random(seed);
  final out = Float64List((rate * .15).round());
  final rise = (rate * .002).round();
  for (var i = 0; i < out.length; i++) {
    final env = i < rise ? i / rise : math.exp(-(i - rise) / (rate * .025));
    out[i] = (rng.nextDouble() * 2 - 1) * .6 * env;
  }
  return out;
}

Float64List pluck(int midi, int seed) => SyntheticString.pluck(
  f0Hz: 440 * math.pow(2, (midi - 69) / 12).toDouble(),
  sampleRate: rate,
  seconds: .6,
  seed: seed,
);

/// Room noise plus [sounds] at capture times (µs).
Float64List performance(int seconds, Map<int, Float64List> sounds) {
  final out = Float64List(seconds * rate);
  final rng = math.Random(5);
  for (var i = 0; i < out.length; i++) {
    out[i] = (rng.nextDouble() * 2 - 1) * .002;
  }
  sounds.forEach((us, s) {
    final at = us * rate ~/ 1000000;
    for (var i = 0; i < s.length && at + i < out.length; i++) {
      out[at + i] += s[i];
    }
  });
  return out;
}

class _Probe extends AudioEnvironmentProbe {
  const _Probe();
  @override
  Future<AudioEnvironment> read() async => AudioEnvironment.unknown;
}

final class RhythmRig {
  RhythmRig(
    String sequence, {
    int level = 1,
    int bpm = 60,
    SetupProfileStore? setup,
  }) {
    channel = FakeAudioCaptureChannel();
    audio = AudioInputController(
      channel: channel,
      requestMicrophonePermission: () async => PermissionStatus.granted,
      pcmDeliveryTimeout: const Duration(minutes: 5),
    );
    final score = PracticeScore.parse(sequence);
    controller = PracticeSessionController(
      score: score,
      tempo: PracticeTempo(openBpm: bpm, targetBpm: bpm),
      audio: audio,
      analyzer: (r) async => judgeNote(r),
      localClockUs: () => localUs,
      criteria: PassCriteria(
        minAccuracy: RhythmTiming.onTimeRatio[level]!,
        onTimeMs: RhythmTiming.onTimeWindowMs[level],
      ),
      setup: setup,
      environment: const _Probe(),
    );
  }

  late final FakeAudioCaptureChannel channel;
  late final AudioInputController audio;
  late final PracticeSessionController controller;
  int localUs = 0;

  Future<void> play(
    Float64List data, {
    int anchorUs = 1000000,
    int outputLatencyUs = 0,
  }) async {
    await controller.start();
    channel.pushRouteChange('ios:BuiltInMic');
    await pumpEventQueue();
    for (var i = 0; i * chunk < data.length; i++) {
      final t = i * chunk * 1000000 ~/ rate;
      channel.pushChunk(
        data.sublist(i * chunk, (i + 1) * chunk),
        sampleRate: rate,
        tNativeUs: t,
      );
      localUs = t + 100000;
      await pumpEventQueue();
      if (i == 0) {
        channel.pushMetronomeAnchor(anchorUs, outputLatencyUs: outputLatencyUs);
        await pumpEventQueue();
      }
      controller.tick();
      await pumpEventQueue();
      if (controller.phase == PracticePhase.finished) break;
    }
  }

  Future<void> close() async {
    controller.dispose();
    await audio.dispose();
  }
}

/// Anchor 1 s, count-in 4 beats at 60 BPM, no latency → beat k at (5+k) s.
int beatUs(int k, [int offsetMs = 0]) => (5 + k) * 1000000 + offsetMs * 1000;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(resetAudioCaptureCoordinatorForTest);

  group('score and criteria', () {
    test(
      'rhythm-only lines; guitar power chords before a rhythm are labels',
      () {
        final r = PracticeScore.parse('4/4: q q ee q | h h');
        expect(r.isRhythmOnly, isTrue);
        expect(r.hasPitches, isFalse);
        expect(r.events.map((e) => e.startBeat), [0, 1, 2, 2.5, 3, 4, 6]);
        expect(
          PracticeScore.parse('Am h hr | G q qr q qr').isRhythmOnly,
          isTrue,
        );
        expect(PracticeScore.parse('E2 F2').isRhythmOnly, isFalse);
        // Without the guitar flag `E5` stays the pitch E5 (other courses).
        final raw = PracticeScore.parse('4/4: E5 ee ee ee ee');
        expect(raw.hasPitches, isTrue);
        final power = PracticeScore.parse(
          '4/4: E5 ee ee ee ee | E5 q q q q',
          powerChordLabels: true,
        );
        expect(power.isRhythmOnly, isTrue);
        expect(power.barCount, 2);
        expect(power.events, hasLength(12));
        // A pitch with a duration or next to another pitch stays a pitch.
        final line = PracticeScore.parse(
          'E4 G4 A4 C5 A4',
          powerChordLabels: true,
        );
        expect(line.events.map((e) => e.midi), [64, 67, 69, 72, 69]);
        expect(
          PracticeScore.parse('A5:h', powerChordLabels: true).hasPitches,
          isTrue,
        );
      },
    );

    test('a rhythm-only lesson gets the level timing gate (§6.2)', () {
      final l = bundled('gtr-s1-m03-01');
      final score = V1PracticeCatalog.scoreOf(l)!;
      expect(score.isRhythmOnly, isTrue);
      final c = PassCriteria.forLesson(l, score: score);
      expect(c.rhythm, isTrue);
      expect(c.onTimeMs, 90);
      expect(c.minAccuracy, .75);
      expect(c.tempoGate, TempoGate.targetOnly, reason: 'M! checkpoint');
      expect(c.customText!.en, contains('Median timing deviation'));
      final s2 = bundled('gtr-s2-m06-02');
      final c2 = PassCriteria.forLesson(
        s2,
        score: V1PracticeCatalog.scoreOf(s2),
      );
      expect((c2.onTimeMs, c2.minAccuracy), (75, .80));
      final s4 = bundled('gtr-s4-m16-07');
      final c4 = PassCriteria.forLesson(
        s4,
        score: V1PracticeCatalog.scoreOf(s4),
      );
      expect((c4.onTimeMs, c4.minAccuracy), (50, .85));
      // A note line keeps note accuracy.
      final notes = bundled('gtr-s1-m02-02');
      final n = PassCriteria.forLesson(
        notes,
        score: V1PracticeCatalog.scoreOf(notes),
      );
      expect((n.rhythm, n.minAccuracy), (false, .80));
    });

    test('reference: calibrated = the grid; else the run median', () {
      final cal = OnsetTimingReference(calibrated: true, windowMs: 90);
      expect(cal.add(60).mark, PracticeMark.correct);
      expect(cal.add(150).mark, PracticeMark.differentNote);
      expect(cal.add(150).timingMs, 150);
      expect(cal.referenceMs, 0);
      final free = OnsetTimingReference(calibrated: false, windowMs: 90);
      for (final ms in const [150.0, 155.0, 145.0, 150.0]) {
        expect(free.add(ms).mark, PracticeMark.correct);
      }
      expect(free.referenceMs, 150);
      expect(free.judge(260).mark, PracticeMark.differentNote);
      expect(free.judge(260).timingMs, 110);
      expect(free.judge(40).timingMs, -110);
      final outcomes = [
        const NoteOutcome(
          eventIndex: 0,
          bar: 0,
          pass: 0,
          mark: PracticeMark.correct,
          offsetMs: 400,
        ),
        const NoteOutcome(
          eventIndex: 1,
          bar: 0,
          pass: 0,
          mark: PracticeMark.couldNotHear,
          reason: HearingReason.noAttack,
        ),
      ];
      final again = free.remark(outcomes);
      expect(again[0].mark, PracticeMark.differentNote);
      expect(again[0].timingMs, 250);
      expect(again[1].mark, PracticeMark.couldNotHear);
      expect(again[1].reason, HearingReason.noAttack);
    });

    test('summary: on-time ratio is the gate; never "accuracy" wording', () {
      final score = PracticeScore.parse('4/4: q q q q');
      NoteOutcome o(int i, PracticeMark m, [double? t]) =>
          NoteOutcome(eventIndex: i, bar: 0, pass: 0, mark: m, timingMs: t);
      final s = PracticeRunSummary.of(
        score: score,
        outcomes: [
          o(0, PracticeMark.correct, 10),
          o(1, PracticeMark.correct, -20),
          o(2, PracticeMark.correct, 30),
          o(3, PracticeMark.differentNote, 140),
        ],
        bpm: 60,
        openBpm: 60,
        targetBpm: 60,
        completed: true,
        loopUsed: false,
        waitUsed: false,
        criteria: const PassCriteria(minAccuracy: .75, onTimeMs: 90),
      );
      expect(s.gate.checks.first.kind, GateCheckKind.onTime);
      expect(s.accuracy, .75);
      expect(s.gate.passed, isTrue);
    });
  });

  group('onset judging, synthetic claps and plucks', () {
    test('uncalibrated: steady lag is absorbed; early, late and missing '
        'beats are told apart', () async {
      final rig = RhythmRig('4/4: q q q q | q q q q');
      // A constant 60 ms lag (unmeasured latency): beats 0–2, 4, 6–7 on it;
      // beat 3 160 ms after it, beat 4 130 ms before it; beat 5 not played.
      final offsets = {0: 60, 1: 60, 2: 60, 3: 220, 4: -70, 6: 60, 7: 60};
      await rig.play(
        performance(15, {
          for (final e in offsets.entries) beatUs(e.key, e.value): clap(e.key),
        }),
      );
      final c = rig.controller;
      expect(c.phase, PracticePhase.finished);
      expect(c.rhythm, isTrue);
      expect(c.timingCalibrated, isFalse);
      expect(c.outcomes.map((o) => o.mark), [
        PracticeMark.correct,
        PracticeMark.correct,
        PracticeMark.correct,
        PracticeMark.differentNote, // late
        PracticeMark.differentNote, // early
        PracticeMark.couldNotHear,
        PracticeMark.correct,
        PracticeMark.correct,
      ]);
      expect(c.outcomes[3].timingMs, greaterThan(90));
      expect(c.outcomes[4].timingMs, lessThan(-90));
      expect(c.outcomes[5].reason, HearingReason.noAttack);
      for (final i in [0, 1, 2, 6, 7]) {
        expect(c.outcomes[i].timingMs!.abs(), lessThan(25), reason: '$i');
        expect(c.outcomes[i].offsetMs, closeTo(60, 25), reason: '$i');
      }
      // The strip shows the final marks.
      expect(c.marks[3]!.mark, PracticeMark.differentNote);
      final s = c.summary!;
      expect((s.correct, s.different, s.unheard), (5, 2, 1));
      expect(s.gate.checks.first.kind, GateCheckKind.onTime);
      expect(s.accuracy, closeTo(5 / 7, 1e-9));
      expect(s.gate.passed, isFalse, reason: '71 % on time < 75 %');
      expect(s.nextStep, NextStep.loopSlower);
      expect(s.timingCalibrated, isFalse);
      expect(s.medianTimingMs, isNotNull, reason: 'relative timing');
      await rig.close();
    });

    test('plucked open string on every beat passes the S1 gate', () async {
      final rig = RhythmRig('4/4: q q q q | q q q q');
      await rig.play(
        performance(15, {
          for (var k = 0; k < 8; k++)
            beatUs(k, 40 + (k.isEven ? 15 : -15)): pluck(45, k),
        }),
      );
      final s = rig.controller.summary!;
      expect(s.correct, 8);
      expect(s.gate.passed, isTrue);
      expect(s.nextStep, NextStep.nextLesson);
      await rig.close();
    });

    test('eighth notes: two onsets per beat are judged apart', () async {
      final rig = RhythmRig('4/4: ee ee ee ee');
      await rig.play(
        performance(11, {
          for (var k = 0; k < 8; k++) beatUs(0, 30 + k * 500): clap(k),
        }),
      );
      final s = rig.controller.summary!;
      expect(rig.controller.outcomes, hasLength(8));
      expect(s.correct, 8);
      expect(s.gate.passed, isTrue);
      await rig.close();
    });

    test('silence is never on time', () async {
      final rig = RhythmRig('4/4: q q q q');
      await rig.play(performance(11, {}));
      final s = rig.controller.summary!;
      expect(s.unheard, 4);
      expect(s.gate.passed, isFalse);
      expect(s.nextStep, NextStep.checkSetup);
      await rig.close();
    });

    test(
      'calibrated: the click grid is exact, so a steady lag is late',
      () async {
        // Speaker round trip 70 ms, native output latency 12 ms: beat k is
        // heard at 1 s + 70 ms + (4 + k) s.
        RhythmRig rig0() => RhythmRig(
          '4/4: q q q q',
          setup: MemorySetupProfileStore(
            SetupProfile.empty.withLatency(
              CalibrationRoute.speaker,
              RouteLatency(
                roundTripUs: 70000,
                spreadUs: 100,
                heardClicks: 8,
                totalClicks: 8,
                measuredAt: DateTime.utc(2026, 11, 1),
              ),
            ),
          ),
        );
        int heard(int k, int ms) => beatUs(k, 70 + ms);

        var rig = rig0();
        await rig.play(
          performance(11, {for (var k = 0; k < 4; k++) heard(k, 10): clap(k)}),
          outputLatencyUs: 12000,
        );
        var c = rig.controller;
        expect(c.timingCalibrated, isTrue);
        expect(
          c.outcomes.map((o) => o.mark),
          everyElement(PracticeMark.correct),
        );
        for (final o in c.outcomes) {
          expect(o.timingMs, closeTo(10, 20));
        }
        expect(c.summary!.gate.passed, isTrue);
        await rig.close();

        resetAudioCaptureCoordinatorForTest();
        rig = rig0();
        await rig.play(
          performance(11, {for (var k = 0; k < 4; k++) heard(k, 150): clap(k)}),
          outputLatencyUs: 12000,
        );
        c = rig.controller;
        expect(
          c.outcomes.map((o) => o.mark),
          everyElement(PracticeMark.differentNote),
        );
        expect(c.outcomes.every((o) => o.timingMs! > 90), isTrue);
        expect(c.summary!.gate.passed, isFalse);
        await rig.close();
      },
    );
  });

  group('screens', () {
    PracticeRunSummary rhythmSummary({required bool calibrated}) {
      final score = PracticeScore.parse('4/4: q q q q | q q q q');
      final marks = [
        (PracticeMark.correct, 5.0),
        (PracticeMark.correct, -10.0),
        (PracticeMark.differentNote, 130.0),
        (PracticeMark.correct, 0.0),
        (PracticeMark.differentNote, -120.0),
        (PracticeMark.differentNote, 150.0),
        (PracticeMark.correct, 12.0),
        (PracticeMark.couldNotHear, null),
      ];
      return PracticeRunSummary.of(
        score: score,
        outcomes: [
          for (var i = 0; i < 8; i++)
            NoteOutcome(
              eventIndex: i,
              bar: score.events[i].bar,
              pass: 0,
              mark: marks[i].$1,
              timingMs: marks[i].$2,
            ),
        ],
        bpm: 80,
        openBpm: 60,
        targetBpm: 80,
        completed: true,
        loopUsed: false,
        waitUsed: false,
        timingCalibrated: calibrated,
        criteria: PassCriteria.forLesson(
          bundled('gtr-s1-m03-01'),
          score: score,
        ),
      );
    }

    testWidgets('result: on time, early or late, the timing gate', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(420, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final s = rhythmSummary(calibrated: false);
      await tester.pumpWidget(
        practiceHost(
          PracticeResultScreen(
            lesson: bundled('gtr-s1-m03-01'),
            score: PracticeScore.parse('4/4: q q q q | q q q q'),
            summary: s,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Early or late'), findsOneWidget);
      expect(find.text('Different note'), findsNothing);
      expect(find.text('On time'), findsOneWidget);
      expect(find.text('Accuracy'), findsNothing);
      expect(
        tester.widget<Text>(find.byKey(const Key('result-accuracy'))).data,
        '%57',
      );
      expect(find.text('On time ≥ %75 (within ±90 ms)'), findsOneWidget);
      expect(find.textContaining('Median timing deviation'), findsOneWidget);
      expect(find.textContaining('beats I could hear'), findsOneWidget);
      expect(find.byKey(const Key('result-relative-timing')), findsOneWidget);
      expect(find.text('12 ms · relative'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('result-early-late'))).data,
        'Early: 1 · Late: 2',
      );
      expect(find.text('Not passed this run'), findsOneWidget);
      expect(find.textContaining('wrong'), findsNothing);
    });

    testWidgets('result (Turkish, calibrated): absolute timing, no note', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(420, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        practiceHost(
          locale: 'tr',
          PracticeResultScreen(
            lesson: bundled('gtr-s1-m03-01'),
            score: PracticeScore.parse('4/4: q q q q | q q q q'),
            summary: rhythmSummary(calibrated: true),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Erken ya da geç'), findsOneWidget);
      expect(find.text('Zamanında'), findsOneWidget);
      expect(find.text('Zamanında ≥ %75 (±90 ms içinde)'), findsOneWidget);
      expect(find.text('12 ms'), findsOneWidget);
      expect(find.byKey(const Key('result-relative-timing')), findsNothing);
      expect(find.text('Erken: 1 · Geç: 2'), findsOneWidget);
    });

    testWidgets('practice screen runs the rhythm checkpoint gtr-s1-m03-01', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(420, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final channel = FakeAudioCaptureChannel();
      final audio = AudioInputController(
        channel: channel,
        requestMicrophonePermission: () async => PermissionStatus.granted,
        pcmDeliveryTimeout: const Duration(minutes: 5),
      );
      var local = 0;
      PracticeSessionController? controller;
      PassCriteria? criteria;
      final progress = _Memory();
      await tester.pumpWidget(
        practiceHost(
          PracticeLoopScreen(
            lesson: bundled('gtr-s1-m03-01'),
            progress: progress,
            hasNextLesson: true,
            controllerFactory: (score, tempo, c) {
              criteria = c;
              return controller = PracticeSessionController(
                score: score,
                tempo: tempo,
                audio: audio,
                criteria: c,
                localClockUs: () => local,
                analyzer: (r) async => judgeNote(r),
              );
            },
          ),
        ),
      );
      expect(criteria!.rhythm, isTrue);
      expect(find.text('♩=60/80'), findsOneWidget);
      expect(find.bySemanticsLabel('Now: a beat'), findsOneWidget);
      expect(find.bySemanticsLabel('Early or late 0'), findsOneWidget);
      // The checkpoint passes at the target tempo (M!): ♩=80.
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.byKey(const Key('practice-tempo-up')));
        await tester.pump();
      }
      expect(find.text('♩=80/80'), findsOneWidget);
      await tester.tap(find.byKey(const Key('practice-start')));
      await tester.pump();
      final c = controller!;
      // Clap 40 ms after every expected beat once the grid exists.
      final rng = math.Random(3);
      var t = 0;
      final pending = <int, Float64List>{};
      var scheduled = false;
      for (var i = 0; i < 200 && c.phase != PracticePhase.finished; i++) {
        final x = Float64List(chunk);
        for (var k = 0; k < x.length; k++) {
          x[k] = (rng.nextDouble() * 2 - 1) * .002;
        }
        final tl = c.timeline;
        if (tl != null && !scheduled) {
          scheduled = true;
          for (final e in c.score.events) {
            final at =
                tl.beatTimeUs(c.plan!.countInBeats + e.startBeat) + 40000;
            pending[at] = clap(e.index);
          }
        }
        pending.forEach((at, s) {
          final from = (at - t) * rate ~/ 1000000;
          for (var k = 0; k < s.length; k++) {
            final j = from + k;
            if (j >= 0 && j < chunk) x[j] += s[k];
          }
        });
        channel.pushChunk(x, sampleRate: rate, tNativeUs: t);
        t += 100000;
        local = t;
        await tester.pump();
        if (channel.metronome != null && c.timeline == null) {
          channel.pushMetronomeAnchor(t + 200000);
          await tester.pump();
        }
        c.tick();
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(c.phase, PracticePhase.finished);
      expect(c.countOf(PracticeMark.correct), 8);
      expect(find.byType(PracticeResultScreen), findsOneWidget);
      expect(find.text('Passed at the opening tempo'), findsNothing);
      expect(find.text('Completed at the target tempo'), findsOneWidget);
      expect(find.text('On time ≥ %75 (within ±90 ms)'), findsOneWidget);
      expect(find.text('The next lesson is open.'), findsOneWidget);
      final record = (await progress.load())['gtr-s1-m03-01']!;
      expect(record.passed, isTrue);
      expect(record.completed, isTrue);
    });
  });
}

final class _Memory implements V1PracticeProgress {
  final Map<String, V1PracticeRecord> records = {};
  @override
  Future<Map<String, V1PracticeRecord>> load() async => Map.of(records);
  @override
  Future<V1PracticeRecord> recordRun(
    String id,
    PracticeRunSummary s, {
    DateTime? at,
  }) async => records[id] = (records[id] ?? V1PracticeRecord(lessonId: id))
      .withRun(s, DateTime.utc(2026, 11, 1));
}
