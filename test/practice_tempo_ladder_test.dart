// FK6 tempo merdiveni: geçen tam tur sonraki turu +5 BPM hızlandırır,
// hedefte durur; geçmeyen/döngülü tur ve kapalı merdiven tempoyu değiştirmez;
// serbest tempoda merdiven yoktur. Kapı anlamı (§6.3) değişmez.
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
import 'package:ostinato/app/practice/loop/practice_score.dart';
import 'package:ostinato/app/practice/loop/practice_session_controller.dart';
import 'package:ostinato/app/practice/loop/practice_tempo_ladder.dart';
import 'package:ostinato/app/practice/loop/practice_transport.dart';
import 'package:permission_handler/permission_handler.dart';

import 'support/practice_host.dart';

Map<String, dynamic> _lessonJson() =>
    jsonDecode(File('content/v1/gtr/gtr-s1-m02-02.json').readAsStringSync())
        as Map<String, dynamic>;

/// gtr-s1-m02-02: open ♩=50, target ♩=60.
V1Lesson lesson() => V1Lesson.fromJson(_lessonJson());

final score = PracticeScore.parse('E2 F2 G2 F2 | E2 F2 G2 F2');
const c = PracticeMark.correct, d = PracticeMark.differentNote;

PracticeRunSummary run(
  List<PracticeMark> marks, {
  required int bpm,
  int open = 50,
  int target = 60,
  bool completed = true,
  bool loop = false,
  bool wait = false,
  PassCriteria criteria = const PassCriteria(minAccuracy: .8),
}) => PracticeRunSummary.of(
  score: score,
  outcomes: [
    for (var i = 0; i < marks.length; i++)
      NoteOutcome(
        eventIndex: i,
        bar: score.events[i].bar,
        pass: 0,
        mark: marks[i],
        expectedMidi: score.events[i].midi,
        observedMidi: marks[i] == d ? 45 : null,
      ),
  ],
  bpm: bpm,
  openBpm: open,
  targetBpm: target,
  completed: completed,
  loopUsed: loop,
  waitUsed: wait,
  criteria: criteria,
);

final allCorrect = List.filled(8, c);
final belowGate = [c, c, d, c, d, c, c, c]; // 75 %

TempoLadder ladderFor({int open = 50, int target = 60, bool free = false}) =>
    TempoLadder.forLesson(
      freeTempo: free,
      tempo: PracticeTempo(openBpm: open, targetBpm: target),
    );

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
      .withRun(s, DateTime.utc(2026, 11, 2));
}

void main() {
  group('TempoLadder stepping', () {
    test('a passed run steps the next run up by 5', () {
      final out = ladderFor().afterRun(run(allCorrect, bpm: 50));
      expect(out, isA<TempoLadderStepped>());
      expect((out! as TempoLadderStepped).nextBpm, 55);
      final next = TempoLadder.apply(
        out,
        PracticeTempo(openBpm: 50, targetBpm: 60),
      );
      expect(next.bpm, 55);
    });

    test('never above the target', () {
      final out = ladderFor().afterRun(run(allCorrect, bpm: 58));
      expect((out! as TempoLadderStepped).nextBpm, 60);
    });

    test('at or above the target the ladder is done', () {
      expect(
        ladderFor().afterRun(run(allCorrect, bpm: 60)),
        isA<TempoLadderAtTarget>(),
      );
      // Manually above the target: the ladder never pulls the tempo down.
      final above = ladderFor().afterRun(run(allCorrect, bpm: 70));
      expect(above, isA<TempoLadderAtTarget>());
      final kept = TempoLadder.apply(
        above,
        PracticeTempo(openBpm: 50, targetBpm: 60, bpm: 70),
      );
      expect(kept.bpm, 70);
    });

    test('a run below the accuracy gate stays at its tempo', () {
      final out = ladderFor().afterRun(run(belowGate, bpm: 55));
      expect(out, isA<TempoLadderHeld>());
      expect((out! as TempoLadderHeld).bpm, 55);
      final t = PracticeTempo(openBpm: 50, targetBpm: 60, bpm: 55);
      expect(TempoLadder.apply(out, t).bpm, 55);
    });

    test('loop, "Wait for me" and a stopped run never step', () {
      final l = ladderFor();
      expect(
        l.afterRun(run(allCorrect, bpm: 50, loop: true)),
        isA<TempoLadderHeld>(),
      );
      expect(
        l.afterRun(run(allCorrect, bpm: 50, wait: true)),
        isA<TempoLadderHeld>(),
      );
      expect(
        l.afterRun(run(allCorrect, bpm: 50, completed: false)),
        isA<TempoLadderHeld>(),
      );
    });

    test('a low heard rate or a missed minimum count stays', () {
      final u = PracticeMark.couldNotHear;
      expect(
        ladderFor().afterRun(run([c, c, c, c, c, c, u, u], bpm: 50)),
        isA<TempoLadderHeld>(),
      );
      expect(
        ladderFor().afterRun(
          run(
            allCorrect,
            bpm: 50,
            criteria: const PassCriteria(minAccuracy: .8, minCorrect: 9),
          ),
        ),
        isA<TempoLadderHeld>(),
      );
    });

    test('off: no decision and the tempo is left alone', () {
      final l = ladderFor()..enabled = false;
      final out = l.afterRun(run(allCorrect, bpm: 50));
      expect(out, isNull);
      final t = PracticeTempo(openBpm: 50, targetBpm: 60);
      expect(TempoLadder.apply(out, t).bpm, 50);
    });

    test('free tempo and open == target have no ladder', () {
      final free = ladderFor(free: true);
      expect(free.available, isFalse);
      expect(free.enabled, isFalse);
      expect(free.afterRun(run(allCorrect, bpm: 60)), isNull);
      final flat = ladderFor(open: 60, target: 60);
      expect(flat.available, isFalse);
      expect(flat.afterRun(run(allCorrect, bpm: 60, open: 60)), isNull);
      // Turning an absent ladder "on" keeps it absent.
      expect(TempoLadder(available: false, enabled: true).enabled, isFalse);
    });

    test('below the opening tempo a cleared run still steps (practice)', () {
      final s = run(allCorrect, bpm: 40);
      expect(s.gate.passed, isFalse);
      expect(s.nextStep, NextStep.raiseTempo);
      expect((ladderFor().afterRun(s)! as TempoLadderStepped).nextBpm, 45);
    });

    test('M! lessons (target only): ladder steps, gate is unchanged', () {
      const targetOnly = PassCriteria(
        minAccuracy: .8,
        tempoGate: TempoGate.targetOnly,
      );
      final s = run(allCorrect, bpm: 55, criteria: targetOnly);
      expect(s.gate.passed, isFalse);
      expect((ladderFor().afterRun(s)! as TempoLadderStepped).nextBpm, 60);
    });

    test('§6.3 kept: a ladder run below the target never completes', () {
      final s = run(allCorrect, bpm: 55);
      expect(s.gate.passed, isTrue); // opening tempo opens the next lesson
      expect(s.gate.completed, isFalse);
      expect(run(allCorrect, bpm: 60).gate.completed, isTrue);
    });
  });

  group('result screen copy', () {
    Future<ResultAction?> show(
      WidgetTester tester,
      PracticeRunSummary s,
      TempoLadderOutcome? ladder, {
      String locale = 'en',
      Finder? tap,
    }) async {
      tester.view.physicalSize = const Size(420, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      ResultAction? got;
      await tester.pumpWidget(
        practiceHost(
          locale: locale,
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  got = await Navigator.of(context).push<ResultAction>(
                    MaterialPageRoute(
                      builder: (_) => PracticeResultScreen(
                        lesson: lesson(),
                        score: score,
                        summary: s,
                        hasNextLesson: true,
                        ladder: ladder,
                      ),
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      if (tap != null) {
        await tester.tap(tap);
        await tester.pumpAndSettle();
      }
      return got;
    }

    testWidgets('stepped: "Next run at ♩=55" and a play button', (
      tester,
    ) async {
      final s = run(allCorrect, bpm: 50);
      final ladder = ladderFor().afterRun(s);
      final action = await show(
        tester,
        s,
        ladder,
        tap: find.byKey(const Key('result-ladder-play')),
      );
      expect(action, isA<ResultActionRetry>());
      expect(find.byType(PracticeResultScreen), findsNothing);
      await show(tester, s, ladder);
      expect(find.text('Tempo ladder'), findsOneWidget);
      expect(find.text('Next run at ♩=55'), findsOneWidget);
      expect(find.text('Play at ♩=55'), findsOneWidget);
      expect(
        find.text('Only a run at the target ♩=60 completes the lesson.'),
        findsOneWidget,
      );
      // The gate itself is unchanged: opening pass, target still to go.
      expect(find.text('Passed at the opening tempo'), findsOneWidget);
      expect(find.text('Go to the next lesson'), findsOneWidget);
    });

    testWidgets('stepped onto the target: that run counts for the gate', (
      tester,
    ) async {
      final s = run(allCorrect, bpm: 55);
      await show(tester, s, ladderFor().afterRun(s));
      expect(
        find.text('Next run at the target ♩=60 — that run counts for the gate'),
        findsOneWidget,
      );
      expect(find.text('Play at ♩=60'), findsOneWidget);
    });

    testWidgets('at the target: this run counts for the gate', (tester) async {
      final s = run(allCorrect, bpm: 60);
      await show(tester, s, ladderFor().afterRun(s));
      expect(
        find.text('Target reached — this run counts for the gate'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('result-ladder-play')), findsNothing);
      expect(find.text('Completed at the target tempo'), findsOneWidget);
    });

    testWidgets('at the target with loop on: a full run counts', (
      tester,
    ) async {
      final s = run(allCorrect, bpm: 60, loop: true);
      await show(tester, s, ladderFor().afterRun(s));
      expect(
        find.text('Target reached — a full run here counts for the gate'),
        findsOneWidget,
      );
    });

    testWidgets('held (Turkish): stays, never "wrong"', (tester) async {
      final s = run(belowGate, bpm: 55);
      await show(tester, s, ladderFor().afterRun(s), locale: 'tr');
      expect(
        find.text(
          'Sonraki tur ♩=55 temposunda kalır — merdiven, ölçütleri karşılayan tam bir turdan sonra yükselir',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('result-ladder-play')), findsNothing);
      for (final t in tester.widgetList<Text>(find.byType(Text))) {
        final text = (t.data ?? '').toLowerCase();
        expect(text, isNot(contains('yanlış')));
        expect(text, isNot(contains('wrong')));
      }
    });

    testWidgets('below the opening tempo: one step, not two', (tester) async {
      final s = run(allCorrect, bpm: 40);
      final action = await show(
        tester,
        s,
        ladderFor().afterRun(s),
        tap: find.byKey(const Key('result-next-step')),
      );
      // "Raise the tempo by 5" would add a second step on top of the ladder.
      expect(action, isA<ResultActionRetry>());
      await show(tester, s, ladderFor().afterRun(s));
      expect(find.text('Raise the tempo by 5'), findsNothing);
      expect(find.text('Play at ♩=45'), findsOneWidget);
      expect(find.byKey(const Key('result-ladder-play')), findsNothing);
    });

    testWidgets('no ladder: no ladder card, old suggestions', (tester) async {
      final s = run(allCorrect, bpm: 40);
      await show(tester, s, null);
      expect(find.byKey(const Key('result-ladder')), findsNothing);
      expect(find.text('Raise the tempo by 5'), findsOneWidget);
    });
  });

  group('practice screen', () {
    setUp(resetAudioCaptureCoordinatorForTest);

    testWidgets('ladder on by default, steps after a pass, off keeps tempo', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(420, 1800);
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
      final progress = _Memory();
      await tester.pumpWidget(
        practiceHost(
          PracticeLoopScreen(
            lesson: lesson(),
            progress: progress,
            hasNextLesson: true,
            controllerFactory: (score, tempo, criteria) =>
                controller = PracticeSessionController(
                  score: score,
                  tempo: tempo,
                  audio: audio,
                  criteria: criteria,
                  localClockUs: () => local,
                  // Every note is heard as the expected one.
                  analyzer: (r) async =>
                      const NoteJudgement(PracticeMark.correct),
                ),
          ),
        ),
      );
      expect(find.text('Tempo ladder: On'), findsOneWidget);
      expect(
        find.text(
          'After a full run that meets the checks, the next run is 5 BPM faster, up to the target ♩=60.',
        ),
        findsOneWidget,
      );
      expect(find.text('♩=50/60'), findsOneWidget);
      final rng = math.Random(1);
      var t = 0;
      Future<void> playRun() async {
        await tester.tap(find.byKey(const Key('practice-start')));
        await tester.pump();
        final c = controller!;
        for (var i = 0; i < 600; i++) {
          final x = Float64List(4800);
          for (var k = 0; k < x.length; k++) {
            x[k] = (rng.nextDouble() * 2 - 1) * .002;
          }
          channel.pushChunk(x, sampleRate: 48000, tNativeUs: t);
          t += 100000;
          local = t;
          await tester.pump();
          if (channel.metronome != null && c.timeline == null) {
            channel.pushMetronomeAnchor(t + 200000);
            await tester.pump();
          }
          c.tick();
          await tester.pump();
          if (c.phase == PracticePhase.finished) break;
        }
        await tester.pumpAndSettle();
        expect(c.phase, PracticePhase.finished);
      }

      // Run 1 at the opening tempo passes: the next run is ♩=55.
      await playRun();
      expect(find.byType(PracticeResultScreen), findsOneWidget);
      expect(find.text('Next run at ♩=55'), findsOneWidget);
      expect(progress.records['gtr-s1-m02-02']!.passed, isTrue);
      await tester.tap(find.byKey(const Key('result-ladder-play')));
      await tester.pumpAndSettle();
      expect(find.text('♩=55/60'), findsOneWidget);
      expect(controller!.tempo.bpm, 55);

      // Manual step down still works with the ladder on, and a setting
      // changed after a result never reopens that result.
      await tester.tap(find.byKey(const Key('practice-tempo-down')));
      await tester.pumpAndSettle();
      expect(find.byType(PracticeResultScreen), findsNothing);
      expect(find.text('♩=50/60'), findsOneWidget);
      await tester.tap(find.byKey(const Key('practice-tempo-up')));
      await tester.pump();

      // Ladder off: a passed run leaves the tempo where it is.
      await tester.tap(find.byKey(const Key('practice-tempo-ladder')));
      await tester.pump();
      expect(find.text('Tempo ladder: Off'), findsOneWidget);
      expect(find.byKey(const Key('practice-tempo-ladder-hint')), findsNothing);
      await playRun();
      expect(find.byKey(const Key('result-ladder')), findsNothing);
      // Back from the result: nothing changes.
      Navigator.of(tester.element(find.byType(PracticeResultScreen))).pop();
      await tester.pumpAndSettle();
      expect(controller!.tempo.bpm, 55);
      expect(find.text('♩=55/60'), findsOneWidget);

      // On again: a pass at ♩=55 sets the target for the next run.
      await tester.tap(find.byKey(const Key('practice-tempo-ladder')));
      await tester.pump();
      await playRun();
      expect(
        find.text('Next run at the target ♩=60 — that run counts for the gate'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('result-ladder-play')));
      await tester.pumpAndSettle();
      expect(controller!.tempo.bpm, 60);

      // At the target: this run is the one that can complete the lesson.
      await playRun();
      expect(
        find.text('Target reached — this run counts for the gate'),
        findsOneWidget,
      );
      expect(find.text('Completed at the target tempo'), findsOneWidget);
      expect(progress.records['gtr-s1-m02-02']!.completed, isTrue);
      Navigator.of(tester.element(find.byType(PracticeResultScreen))).pop();
      await tester.pumpAndSettle();
      expect(controller!.tempo.bpm, 60);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(audio.dispose);
    });
  });
}
