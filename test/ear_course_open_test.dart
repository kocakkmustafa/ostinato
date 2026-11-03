// Opening the ear training course (founder 2026-11-03: "first microphone
// measurement, then open"): the bundled lessons, the level-1 free scope,
// the course list and reader say nothing "coming soon" and nothing about a
// guitar.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/course_access.dart';
import 'package:ostinato/app/drill/drill_copy.dart';
import 'package:ostinato/app/practice/loop/practice_outcome.dart';
import 'package:ostinato/app/practice/loop/practice_progress_store.dart';
import 'package:ostinato/app/practice/loop/v1_course_catalog.dart';
import 'package:ostinato/app/practice/loop/v1_course_copy.dart';
import 'package:ostinato/app/practice/loop/v1_lesson_reader_screen.dart';
import 'package:ostinato/app/practice/loop/v1_practice_list_screen.dart';
import 'package:ostinato/app/practice/setup/setup_profile_store.dart';

import 'support/practice_host.dart';

final class _NoProgress implements V1PracticeProgress {
  @override
  Future<Map<String, V1PracticeRecord>> load() async => const {};
  @override
  Future<V1PracticeRecord> recordRun(
    String lessonId,
    PracticeRunSummary summary, {
    DateTime? at,
  }) => throw UnimplementedError();
}

final class _NoChecks implements V1LessonChecks {
  @override
  Future<Map<String, V1LessonCheck>> load() async => const {};
  @override
  Future<V1LessonCheck> record(
    String lessonId,
    V1CheckEvidence evidence, {
    DateTime? at,
  }) async => V1LessonCheck(
    lessonId: lessonId,
    evidence: evidence,
    at: at ?? DateTime.utc(2026, 11, 3),
  );
}

void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late V1CourseCatalog ear;
  setUpAll(() async {
    ear = await V1CourseCatalog.load(course: 'ear');
  });

  test('bundled: 50 ear lessons in two levels; level 1 is free', () async {
    expect(ear.course, 'ear');
    expect(ear.lessons, hasLength(50));
    expect([for (final l in ear.levels) l.level], [1, 2]);
    expect(ear.units.first.requiredGateIds, isEmpty);
    // Level 2 opens after the level-1 test.
    expect(ear.unit('ear-s2-m05')!.requiredGateIds, ['ear-s1-test']);
    final free = [
      for (final l in ear.lessons)
        if (isFreeV1Lesson(l.id, paidFeaturesAvailable: true)) l.id,
    ];
    expect(free, hasLength(25));
    expect(free.every((id) => id.startsWith('ear-s1-')), isTrue);
    // The guitar catalog is unchanged by the course parameter.
    final gtr = await V1CourseCatalog.load();
    expect(gtr.lessons, hasLength(240));
    expect(gtr.lessons.every((l) => l.lesson.course == 'gtr'), isTrue);
  });

  test('every ear lesson runs: no drill or checkpoint is "coming soon"', () {
    for (final l in ear.lessons) {
      switch (l.availability) {
        case V1LessonAvailability.drillSoon:
          expect(l.drillReady, isTrue, reason: l.id);
        case V1LessonAvailability.held:
          expect(
            l.lesson.practice.sections.isNotEmpty || l.drillReady,
            isTrue,
            reason: l.id,
          );
        case V1LessonAvailability.camera || V1LessonAvailability.tuner:
          fail('${l.id}: ${l.availability}');
        default:
      }
    }
  });

  testWidgets('course list: ear title, level-1 free line, ready drill chips', (
    tester,
  ) async {
    _tall(tester);
    await tester.pumpWidget(
      practiceHost(
        V1PracticeListScreen(
          course: 'ear',
          catalog: Future.value(ear),
          progressFactory: (_) => _NoProgress(),
          checksFactory: (_) => _NoChecks(),
          setupStore: MemorySetupProfileStore(),
          paidFeaturesAvailable: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(V1CourseCopy.earTitle.$1), findsOneWidget);
    expect(find.text(V1CourseCopy.title.$1), findsNothing);
    expect(
      find.text('Level 1 is free · later levels need a membership'),
      findsOneWidget,
    );
    expect(find.textContaining('All 50 lessons of the ear'), findsOneWidget);
    expect(find.text(V1CourseCopy.chipDrillReady.$1), findsWidgets);
    expect(find.text(V1CourseCopy.chipDrill.$1), findsNothing);
  });

  testWidgets('reader: a drill-only ear lesson says nothing about a guitar', (
    tester,
  ) async {
    _tall(tester);
    final l = ear.lesson('ear-s1-m01-03')!;
    expect(l.lesson.practice.measurement, ['D']);
    await tester.pumpWidget(
      practiceHost(V1LessonReaderScreen(lesson: l, checks: _NoChecks())),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(
        'This lesson is an on-screen drill. Passing it saves the lesson as done.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('playing part'), findsNothing);

    // A drill plus an unmeasured singing part says so.
    final sung = ear.lesson('ear-s2-m06-06')!;
    await tester.pumpWidget(
      practiceHost(
        V1LessonReaderScreen(
          key: const ValueKey('sung'),
          lesson: sung,
          checks: _NoChecks(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(DrillCopy.bannerReadySinging.$1), findsOneWidget);
  });

  testWidgets('reader: no ear lesson shows the guitar self-checks', (
    tester,
  ) async {
    _tall(tester);
    // The app's own guitar lines; lesson text may still name guitarists.
    final guitarLines = [
      V1CourseCopy.genericTaskDone,
      V1CourseCopy.genericExplain,
      V1CourseCopy.genericPlayedThrough,
      V1CourseCopy.genericClear,
      DrillCopy.bannerReady,
    ];
    for (final l in ear.lessons) {
      await tester.pumpWidget(
        practiceHost(
          V1LessonReaderScreen(
            key: ValueKey(l.id),
            lesson: l,
            checks: _NoChecks(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final copy in guitarLines) {
        expect(find.text(copy.$1), findsNothing, reason: '${l.id}: ${copy.$1}');
      }
    }
  });
}
