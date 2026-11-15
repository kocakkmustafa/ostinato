import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/curriculum/v1_lesson.dart';
import 'package:ostinato/app/practice/loop/practice_marks.dart';
import 'package:ostinato/app/practice/loop/practice_outcome.dart';
import 'package:ostinato/app/practice/loop/practice_result_screen.dart';
import 'package:ostinato/app/practice/loop/practice_score.dart';
import 'support/practice_host.dart';

/// OST-UX-16: a partial run (stopped early / loop used / wait used) must
/// never PRODUCE a loop / tempo / performance step (FLAG-CHECKLIST #16).
void main() {
  final lesson = V1Lesson.fromJson(
    jsonDecode(File('content/v1/gtr/gtr-s1-m02-02.json').readAsStringSync()),
  );
  final score = PracticeScore.parse('E2 F2 G2 F2 | E2 F2 G2 F2');
  const c = PracticeMark.correct, d = PracticeMark.differentNote;
  const u = PracticeMark.couldNotHear;

  PracticeRunSummary sum(
    List<PracticeMark> m, {
    bool completed = true,
    bool loop = false,
    bool wait = false,
    int bpm = 60,
  }) => PracticeRunSummary.of(
    score: score,
    outcomes: [
      for (var i = 0; i < m.length; i++)
        NoteOutcome(
          eventIndex: i,
          bar: score.events[i].bar,
          pass: 0,
          mark: m[i],
          reason: m[i] == u ? HearingReason.noAttack : null,
          expectedMidi: score.events[i].midi,
          observedMidi: m[i] == d ? 45 : null,
        ),
    ],
    bpm: bpm,
    openBpm: 50,
    targetBpm: 60,
    completed: completed,
    loopUsed: loop,
    waitUsed: wait,
    criteria: const PassCriteria(minAccuracy: .8),
  );

  final lowAcc = [c, c, d, c, d, c, c, c];
  final allOk = List.filled(8, c);
  const banned = {
    NextStep.loopSlower,
    NextStep.raiseTempo,
    NextStep.performanceRun,
  };

  final partial = <String, PracticeRunSummary>{
    for (final (cand, marks, bpm) in <(String, List<PracticeMark>, int)>[
      ('lowAccuracy', lowAcc, 60),
      ('lowTempo', allOk, 45),
      ('fullTempoOk', allOk, 60),
    ]) ...{
      'stoppedEarly/$cand': sum(marks, completed: false, bpm: bpm),
      'loopUsed/$cand': sum(marks, loop: true, bpm: bpm),
      'waitUsed/$cand': sum(marks, wait: true, bpm: bpm),
    },
  };

  group('16 uretici: kismi kosu loop/tempo/performans URETMEZ', () {
    partial.forEach((name, s) {
      test(name, () {
        expect(s.gate.eligible, isFalse);
        expect(s.nextStep, isNot(isIn(banned)));
        expect(s.nextStep, isIn({NextStep.checkSetup, NextStep.tryAgain}));
      });
    });
    test('kismi + duyulan nota yetersiz -> checkSetup', () {
      final s = sum([c, u, u, u, u, u, u, u], completed: false);
      expect(s.nextStep, NextStep.checkSetup);
    });
  });

  group('16 tam kosu: davranis ayni', () {
    test('gecti -> nextLesson', () {
      expect(sum(allOk).nextStep, NextStep.nextLesson);
    });
    test('dusuk dogruluk -> loopSlower', () {
      expect(sum(lowAcc).nextStep, NextStep.loopSlower);
    });
    test('dusuk tempo -> raiseTempo', () {
      expect(sum(allOk, bpm: 45).nextStep, NextStep.raiseTempo);
    });
  });

  group('16 sonuc ekrani: kismi kosuda loop/tempo onerisi gorunmez', () {
    for (final loc in ['en', 'tr']) {
      partial.forEach((name, s) {
        testWidgets('$name [$loc]', (t) async {
          t.view.physicalSize = const Size(420, 2400);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.resetPhysicalSize);
          addTearDown(t.view.resetDevicePixelRatio);
          await t.pumpWidget(
            practiceHost(
              locale: loc,
              PracticeResultScreen(
                lesson: lesson,
                score: score,
                summary: s,
                stage: false,
              ),
            ),
          );
          await t.pump();
          for (final bad in [
            'Loop these bars',
            'Raise the tempo',
            'Play the full line',
            'Bu ölçüleri %70',
            'Tempoyu 5 artır',
            'Tüm diziyi hedef',
          ]) {
            expect(find.textContaining(bad), findsNothing, reason: bad);
          }
        });
      });
    }
  });
}
