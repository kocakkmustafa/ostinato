// F2.6a — drill oturumu ve ekranı: ilk deneme puanı, karıştırılanlar
// kuyruğu, %80 geçiş, "yanlış" demeyen geri bildirim, okuyucu bağlantısı.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/curriculum/v1_lesson.dart';
import 'package:ostinato/app/drill/drill_copy.dart';
import 'package:ostinato/app/drill/drill_generator.dart';
import 'package:ostinato/app/drill/drill_screen.dart';
import 'package:ostinato/app/drill/drill_session.dart';
import 'package:ostinato/app/practice/loop/practice_progress_store.dart';
import 'package:ostinato/app/practice/loop/v1_course_catalog.dart';
import 'package:ostinato/app/practice/loop/v1_lesson_reader_screen.dart';

import 'support/practice_host.dart';

V1Lesson lesson(String id) => V1Lesson.fromJson(
  jsonDecode(File('content/v1/gtr/$id.json').readAsStringSync()),
);

final class _Checks implements V1LessonChecks {
  final Map<String, V1LessonCheck> checks = {};
  @override
  Future<Map<String, V1LessonCheck>> load() async => Map.of(checks);
  @override
  Future<V1LessonCheck> record(
    String lessonId,
    V1CheckEvidence evidence, {
    DateTime? at,
  }) async => checks[lessonId] = mergeLessonCheck(
    checks[lessonId],
    V1LessonCheck(
      lessonId: lessonId,
      evidence: evidence,
      at: at ?? DateTime.utc(2026, 11, 3),
    ),
  );
}

void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  final drill = lesson('gtr-s2-m09-02').practice.drill!;

  test('session: first tries score; a differing answer returns once', () {
    final qs = generateDrill(drill, seed: 3);
    final s = DrillSession(qs);
    expect(s.needed, 7); // 80% of 8, rounded up
    // Miss the first question, match the rest.
    s.choose((qs[0].answer + 1) % qs[0].options.length);
    expect(s.matchedCurrent, isFalse);
    s.next();
    for (var i = 1; i < qs.length; i++) {
      s.choose(qs[i].answer);
      s.next();
    }
    expect(s.finished, isFalse);
    expect(s.isReview, isTrue);
    expect(s.current, same(qs[0]));
    expect(s.onLast, isTrue);
    s.choose(qs[0].answer);
    s.next();
    expect(s.finished, isTrue);
    // The second try teaches; the score keeps the first try.
    expect(s.matched, 7);
    expect(s.passed, isTrue);
  });

  test('session: two first-try differences fail an 8-question drill', () {
    final qs = generateDrill(drill, seed: 4);
    final s = DrillSession(qs);
    for (var i = 0; i < qs.length; i++) {
      s.choose(
        i < 2 ? (qs[i].answer + 1) % qs[i].options.length : qs[i].answer,
      );
      s.next();
    }
    while (!s.finished) {
      s.choose(s.current.answer);
      s.next();
    }
    expect(s.matched, 6);
    expect(s.passed, isFalse);
  });

  testWidgets('screen: a differing answer shows both, never "wrong"', (
    tester,
  ) async {
    _tall(tester);
    final qs = generateDrill(drill, seed: 11);
    bool? popped;
    await tester.pumpWidget(
      practiceHost(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              popped = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) =>
                      DrillScreen(drill: drill, title: 'Drill', seed: 11),
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Question 1 of 8'), findsOneWidget);
    expect(find.byKey(const Key('drill-prompt')), findsOneWidget);
    // First question: choose a different option.
    final other = (qs[0].answer + 1) % qs[0].options.length;
    await tester.tap(find.byKey(Key('drill-option-$other')));
    await tester.pump();
    final feedback = tester
        .widget<Text>(find.byKey(const Key('drill-feedback')))
        .data!;
    expect(feedback, startsWith('Your answer: '));
    expect(feedback.toLowerCase(), isNot(contains('wrong')));
    // Options are locked once answered.
    await tester.tap(find.byKey(Key('drill-option-${qs[0].answer}')));
    await tester.pump();
    expect(
      tester.widget<Text>(find.byKey(const Key('drill-feedback'))).data,
      feedback,
    );
    await tester.tap(find.byKey(const Key('drill-next')));
    await tester.pumpAndSettle();
    for (var i = 1; i < qs.length; i++) {
      await tester.ensureVisible(
        find.byKey(Key('drill-option-${qs[i].answer}')),
      );
      await tester.tap(find.byKey(Key('drill-option-${qs[i].answer}')));
      await tester.pump();
      expect(find.text(DrillCopy.matches.$1), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('drill-next')));
      await tester.tap(find.byKey(const Key('drill-next')));
      await tester.pumpAndSettle();
    }
    // The mixed-up question comes back once.
    expect(find.text(DrillCopy.review.$1), findsOneWidget);
    await tester.ensureVisible(find.byKey(Key('drill-option-${qs[0].answer}')));
    await tester.tap(find.byKey(Key('drill-option-${qs[0].answer}')));
    await tester.pump();
    expect(find.text(DrillCopy.seeResult.$1), findsOneWidget);
    await tester.tap(find.byKey(const Key('drill-next')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const Key('drill-score'))).data,
      '7 of 8 matched on the first try. Passing needs 7.',
    );
    expect(find.text(DrillCopy.passed.$1), findsOneWidget);
    await tester.tap(find.byKey(const Key('drill-back')));
    await tester.pumpAndSettle();
    expect(popped, isTrue);
  });

  testWidgets('reader: a supported drill lesson offers it and records a pass', (
    tester,
  ) async {
    _tall(tester);
    final course = V1CourseCatalog([lesson('gtr-s2-m09-02')]);
    final l = course.lesson('gtr-s2-m09-02')!;
    expect(l.availability, V1LessonAvailability.drillSoon);
    final checks = _Checks();
    await tester.pumpWidget(
      practiceHost(V1LessonReaderScreen(lesson: l, checks: checks)),
    );
    await tester.pumpAndSettle();
    expect(find.text(DrillCopy.bannerReady.$1), findsOneWidget);
    final start = find.byKey(const Key('v1-reader-drill'));
    await tester.ensureVisible(start);
    await tester.tap(start);
    await tester.pumpAndSettle();
    // Answer from the screen's own session (seed is time-based here).
    final session = tester
        .state<DrillScreenState>(find.byType(DrillScreen))
        .session;
    while (!session.finished) {
      final key = Key('drill-option-${session.current.answer}');
      await tester.ensureVisible(find.byKey(key));
      await tester.tap(find.byKey(key));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('drill-next')));
      await tester.tap(find.byKey(const Key('drill-next')));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byKey(const Key('drill-back')));
    await tester.pumpAndSettle();
    expect(checks.checks[l.id]!.evidence, V1CheckEvidence.drillPass);
    expect(find.text(DrillCopy.passed.$1), findsOneWidget);
    final status = V1CourseState(course, const {}, checks.checks).status(l);
    expect(status, V1LessonStatus.drillPassed);
  });

  testWidgets('reader: an unsupported drill keeps the "coming soon" banner', (
    tester,
  ) async {
    _tall(tester);
    final course = V1CourseCatalog([lesson('gtr-s1-m01-01')]);
    final l = course.lesson('gtr-s1-m01-01')!;
    await tester.pumpWidget(
      practiceHost(V1LessonReaderScreen(lesson: l, checks: _Checks())),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('v1-reader-drill')), findsNothing);
  });

  test('a passed drill replaces a self-report; not the other way round', () {
    V1LessonCheck c(V1CheckEvidence e) =>
        V1LessonCheck(lessonId: 'x', evidence: e, at: DateTime.utc(2026));
    expect(
      mergeLessonCheck(
        c(V1CheckEvidence.selfReport),
        c(V1CheckEvidence.drillPass),
      ).evidence,
      V1CheckEvidence.drillPass,
    );
    expect(
      mergeLessonCheck(
        c(V1CheckEvidence.drillPass),
        c(V1CheckEvidence.selfReport),
      ).evidence,
      V1CheckEvidence.drillPass,
    );
    expect(V1CheckEvidence.parse('drill_pass'), V1CheckEvidence.drillPass);
  });
}
