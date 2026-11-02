// v1 paywall: stage S1 of each v1 course is free (`ostinatoV1FreeStages`),
// later stages open only through the paid-access guard. The module gate is
// separate and unchanged; lists, titles and progress stay readable.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/course_access.dart';
import 'package:ostinato/app/curriculum/v1_lesson.dart';
import 'package:ostinato/app/practice/loop/practice_progress_store.dart';
import 'package:ostinato/app/practice/loop/practice_outcome.dart';
import 'package:ostinato/app/practice/loop/v1_course_catalog.dart';
import 'package:ostinato/app/practice/loop/v1_lesson_reader_screen.dart';
import 'package:ostinato/app/practice/loop/v1_practice_list_screen.dart';
import 'package:ostinato/app/practice/setup/setup_profile_store.dart';

import 'support/paid_access_scope.dart';
import 'support/practice_host.dart';

List<String> _ids(String course) => [
  for (final f in Directory('content/v1/$course').listSync())
    if (f is File && f.path.endsWith('.json'))
      f.uri.pathSegments.last.replaceAll('.json', ''),
]..sort();

List<V1Lesson> _bundledGuitar() => [
  for (final f in Directory('content/v1/gtr').listSync())
    if (f is File && f.path.endsWith('.json'))
      V1Lesson.fromJson(jsonDecode(f.readAsStringSync())),
];

final class _NoProgress implements V1PracticeProgress {
  @override
  Future<Map<String, V1PracticeRecord>> load() async => {};
  @override
  Future<V1PracticeRecord> recordRun(
    String lessonId,
    PracticeRunSummary summary, {
    DateTime? at,
  }) async => V1PracticeRecord(lessonId: lessonId);
}

final class _Checks implements V1LessonChecks {
  _Checks(this.checks);
  final Map<String, V1LessonCheck> checks;
  @override
  Future<Map<String, V1LessonCheck>> load() async => Map.of(checks);
  @override
  Future<V1LessonCheck> record(
    String lessonId,
    V1CheckEvidence evidence, {
    DateTime? at,
  }) async => checks[lessonId] = V1LessonCheck(
    lessonId: lessonId,
    evidence: evidence,
    at: at ?? DateTime.utc(2026, 11, 2),
  );
}

SetupProfileStore _visitedSetup() {
  final skip = SetupStepRecord(
    SetupStepState.skipped,
    DateTime.utc(2026, 11, 1),
  );
  return MemorySetupProfileStore(
    SetupProfile.empty.copyWith(
      placement: skip,
      roomStep: skip,
      latencyStep: skip,
      tuningStep: skip,
    ),
  );
}

void main() {
  test('free scope is one constant: S1 of guitar and ear', () {
    expect(ostinatoV1FreeStages, {
      'gtr': {'s1'},
      'ear': {'s1'},
    });
  });

  test('boundary lessons: S1 free, S2+ paid, unknown ids closed', () {
    expect(isFreeV1Lesson('gtr-s1-m01-01'), isTrue);
    expect(isFreeV1Lesson('gtr-s1-m04-11'), isTrue);
    expect(isFreeV1Lesson('gtr-s1-test'), isTrue);
    expect(isFreeV1Lesson('gtr-s2-m05-01'), isFalse);
    expect(isFreeV1Lesson('gtr-s4-test-a'), isFalse);
    expect(isFreeV1Lesson('ear-s1-m01-01'), isTrue);
    expect(isFreeV1Lesson('ear-s1-test'), isTrue);
    expect(isFreeV1Lesson('ear-s2-m05-01'), isFalse);
    expect(isFreeV1Lesson('pno-s1-m01-01'), isFalse, reason: 'not listed');
    expect(isFreeV1Lesson('guitar.lesson.1'), isFalse, reason: 'not v1');
  });

  test('bundled courses: 40 free guitar lessons, 25 free ear lessons', () {
    final gtr = _ids('gtr');
    final ear = _ids('ear');
    expect(gtr, hasLength(240));
    expect(ear, hasLength(50));
    expect(gtr.where(isFreeV1Lesson), hasLength(40));
    expect(ear.where(isFreeV1Lesson), hasLength(25));
    for (final id in gtr.followedBy(ear)) {
      expect(isFreeV1Lesson(id), id.contains('-s1-'), reason: id);
    }
    expect(v1FreeLevel('gtr'), 1);
    expect(v1FreeLevel('ear'), 1);
  });

  test('with paid features off nothing is gated', () {
    for (final id in _ids('gtr').followedBy(_ids('ear'))) {
      expect(isFreeV1Lesson(id, paidFeaturesAvailable: false), isTrue);
    }
  });

  group('course list', () {
    final course = V1CourseCatalog(_bundledGuitar());

    Future<void> pump(
      WidgetTester tester, {
      PaidAccessProbe? paid,
      bool paidFeaturesAvailable = true,
      Map<String, V1LessonCheck>? checks,
    }) async {
      tester.view.physicalSize = const Size(800, 5000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final list = practiceHost(
        V1PracticeListScreen(
          catalog: Future.value(course),
          progressFactory: (_) => _NoProgress(),
          // The S1 test cleared by self-check opens module 5 "not measured".
          checksFactory: (_) => _Checks(
            checks ??
                {
                  'gtr-s1-test': V1LessonCheck(
                    lessonId: 'gtr-s1-test',
                    evidence: V1CheckEvidence.selfReport,
                    at: DateTime.utc(2026, 11, 2),
                  ),
                },
          ),
          setupStore: _visitedSetup(),
          practiceScreenBuilder: (l, _, _) =>
              Scaffold(body: Text('practice ${l.id}')),
          paidFeaturesAvailable: paidFeaturesAvailable,
        ),
      );
      await tester.pumpWidget(paid == null ? list : paid.wrap(list));
      await tester.pumpAndSettle();
    }

    Future<void> tapLesson(WidgetTester tester, String id) async {
      final unit = V1CourseCatalog.unitIdOf(id);
      final tile = find.byKey(Key('v1-practice-$id'));
      if (tile.evaluate().isEmpty) {
        await tester.tap(find.byKey(Key('v1-course-unit-$unit')));
        await tester.pumpAndSettle();
      }
      await tester.tap(tile);
      await tester.pumpAndSettle();
    }

    testWidgets('states the free scope and marks only paid lessons', (
      tester,
    ) async {
      await pump(tester);
      expect(
        find.text('Level 1 is free · later levels need a membership'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('v1-course-unit-gtr-s1-test')));
      await tester.tap(find.byKey(const Key('v1-course-unit-gtr-s2-m05')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('v1-course-paid-gtr-s1-test')), findsNothing);
      expect(
        find.byKey(const Key('v1-course-paid-gtr-s2-m05-01')),
        findsOneWidget,
      );
      expect(find.text('Membership'), findsWidgets);
      // Paid titles and progress lines stay readable.
      expect(
        find.text(course.lesson('gtr-s2-m05-01')!.lesson.title.en),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('v1-course-status-gtr-s2-m05-01')),
        findsOneWidget,
      );
    });

    testWidgets('a free lesson opens without the guard', (tester) async {
      final paid = PaidAccessProbe(member: false);
      addTearDown(paid.dispose);
      await pump(tester, paid: paid);
      await tapLesson(tester, 'gtr-s1-test');
      expect(paid.calls, 0);
      expect(find.byType(V1PracticeListScreen), findsNothing);
    });

    testWidgets('the first paid lesson asks the guard; a non-member stays '
        'on the list', (tester) async {
      final paid = PaidAccessProbe(member: false);
      addTearDown(paid.dispose);
      await pump(tester, paid: paid);
      final state = V1CourseState(course, const {}, {
        'gtr-s1-test': V1LessonCheck(
          lessonId: 'gtr-s1-test',
          evidence: V1CheckEvidence.selfReport,
          at: DateTime.utc(2026, 11, 2),
        ),
      });
      expect(state.isOpen('gtr-s2-m05-01'), isTrue, reason: 'module gate');
      await tapLesson(tester, 'gtr-s2-m05-01');
      expect(paid.calls, 1);
      expect(find.byType(V1LessonReaderScreen), findsNothing);
      expect(find.text('practice gtr-s2-m05-01'), findsNothing);
      expect(find.byType(V1PracticeListScreen), findsOneWidget);
    });

    testWidgets('a member opens the paid lesson', (tester) async {
      final paid = PaidAccessProbe();
      addTearDown(paid.dispose);
      await pump(tester, paid: paid);
      await tapLesson(tester, 'gtr-s2-m05-01');
      expect(paid.calls, 1);
      expect(
        find.byType(V1LessonReaderScreen).evaluate().isNotEmpty ||
            find.text('practice gtr-s2-m05-01').evaluate().isNotEmpty,
        isTrue,
      );
      expect(find.byType(V1PracticeListScreen, skipOffstage: false), findsOne);
      expect(
        find.byType(V1PracticeListScreen),
        findsNothing,
        reason: 'the lesson route is on top',
      );
    });

    testWidgets('the module gate still applies before the paywall', (
      tester,
    ) async {
      final paid = PaidAccessProbe();
      addTearDown(paid.dispose);
      await pump(tester, paid: paid, checks: const {});
      await tapLesson(tester, 'gtr-s2-m05-01');
      expect(paid.calls, 0, reason: 'a locked module never reaches the guard');
      expect(find.byType(V1PracticeListScreen), findsOneWidget);
    });

    testWidgets('with paid features off nothing is gated or marked', (
      tester,
    ) async {
      final paid = PaidAccessProbe(member: false);
      addTearDown(paid.dispose);
      await pump(tester, paid: paid, paidFeaturesAvailable: false);
      expect(find.byKey(const Key('v1-course-free-scope')), findsNothing);
      await tester.tap(find.byKey(const Key('v1-course-unit-gtr-s2-m05')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('v1-course-paid-gtr-s2-m05-01')),
        findsNothing,
      );
      await tapLesson(tester, 'gtr-s2-m05-01');
      expect(paid.calls, 0);
      expect(find.byType(V1PracticeListScreen), findsNothing);
    });
  });
}
