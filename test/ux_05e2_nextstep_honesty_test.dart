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

/// OST-UX-05e2: published path (stage: false) must not suggest loop / tempo /
/// performance from the partial numbers of an unmeasured run.
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
    PassCriteria criteria = const PassCriteria(minAccuracy: .8),
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
    criteria: criteria,
  );

  Future<String> label(
    WidgetTester t,
    PracticeRunSummary s, {
    required String locale,
  }) async {
    t.view.physicalSize = const Size(420, 2400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      practiceHost(
        locale: locale,
        PracticeResultScreen(
          lesson: lesson,
          score: score,
          summary: s,
          stage: false,
        ),
      ),
    );
    await t.pump();
    final btn = find.byKey(const Key('result-next-step'));
    expect(btn, findsOneWidget);
    return ((t.widget(btn) as FilledButton).child! as Text).data!;
  }

  // Real localized labels (practice_result_screen.dart _nextStep).
  const labels = {
    'en': {
      NextStep.nextLesson: 'Play it again', // hasNextLesson false
      NextStep.checkSetup: 'Check the setup',
      NextStep.loopSlower: 'Loop these bars at 70 % tempo',
      NextStep.raiseTempo: 'Raise the tempo by 5',
      NextStep.performanceRun: 'Play the full line at the target tempo',
      NextStep.tryAgain: 'Try again',
    },
    'tr': {
      NextStep.nextLesson: 'Bir kez daha çal',
      NextStep.checkSetup: 'Kurulumu kontrol et',
      NextStep.loopSlower: 'Bu ölçüleri %70 tempoda döngüle',
      NextStep.raiseTempo: 'Tempoyu 5 artır',
      NextStep.performanceRun: 'Tüm diziyi hedef tempoda çal',
      NextStep.tryAgain: 'Tekrar dene',
    },
  };
  const bad = [
    NextStep.loopSlower,
    NextStep.raiseTempo,
    NextStep.performanceRun,
  ];

  final lowAcc = [c, c, d, c, d, c, c, c];
  final allOk = List.filled(8, c);

  // (reason, candidate, summary, raw step)
  final unmeasured = <(String, String, PracticeRunSummary, NextStep)>[
    for (final (cand, marks, bpm, raw)
        in <(String, List<PracticeMark>, int, NextStep)>[
          ('loopSlower', lowAcc, 60, NextStep.loopSlower),
          ('raiseTempo', allOk, 45, NextStep.raiseTempo),
          ('performanceRun', allOk, 60, NextStep.performanceRun),
        ]) ...[
      ('stoppedEarly', cand, sum(marks, completed: false, bpm: bpm), raw),
      ('loopUsed', cand, sum(marks, loop: true, bpm: bpm), raw),
      ('waitUsed', cand, sum(marks, wait: true, bpm: bpm), raw),
    ],
  ];

  group('05e2 a) eski yol olculmemis kosu: tryAgain', () {
    for (final (reason, cand, s, raw) in unmeasured) {
      test('ham oneri kontrolu: $reason/$cand', () {
        expect(s.gate.eligible, isFalse);
        expect(s.nextStep, raw);
      });
      for (final loc in ['en', 'tr']) {
        testWidgets('a) $reason/$cand [$loc] -> tryAgain etiketi', (t) async {
          final l = await label(t, s, locale: loc);
          expect([for (final b in bad) labels[loc]![b]], isNot(contains(l)));
          expect(l, labels[loc]![NextStep.tryAgain]);
        });
      }
    }
  });

  group('05e2 c) birim: shownStep', () {
    for (final (reason, cand, s, _) in unmeasured) {
      test('c) $reason/$cand shownStep == tryAgain', () {
        expect(s.shownStep, NextStep.tryAgain);
      });
    }
  });

  group('05e2 b) regresyon: oneriler aynen', () {
    final regress = <(String, PracticeRunSummary, NextStep)>[
      ('gate gecti -> nextLesson', sum(allOk), NextStep.nextLesson),
      (
        'eligible heard<minHeard -> checkSetup',
        sum([c, u, u, u, u, u, u, u]),
        NextStep.checkSetup,
      ),
      (
        'eligible olmayan yarim kosu heard<minHeard -> checkSetup',
        sum([c, u, u, u, u, u, u, u], completed: false),
        NextStep.checkSetup,
      ),
      ('eligible loopSlower', sum(lowAcc), NextStep.loopSlower),
      ('eligible raiseTempo', sum(allOk, bpm: 45), NextStep.raiseTempo),
      (
        'eligible tryAgain (yalniz minCorrect basarisiz)',
        sum(
          allOk,
          criteria: const PassCriteria(minAccuracy: .8, minCorrect: 9),
        ),
        NextStep.tryAgain,
      ),
    ];
    for (final (name, s, step) in regress) {
      test('b) birim: $name', () {
        expect(s.nextStep, step);
        expect(s.shownStep, step);
      });
      for (final loc in ['en', 'tr']) {
        testWidgets('b) render [$loc]: $name', (t) async {
          expect(await label(t, s, locale: loc), labels[loc]![step]);
        });
      }
    }
    // performanceRun yalniz !eligible'ta uretilir (practice_outcome.dart:306)
    // ve o durumda a) kapsar: eligible performanceRun ULASILAMAZ.
  });
}
