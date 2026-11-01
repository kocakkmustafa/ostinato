// v1 full guitar course screen: levels → modules → lessons with status chips;
// measured lessons open the practice loop, the others the lesson reader
// (self-check, held checkpoint, tuner); "Start next lesson" in course order.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/curriculum/v1_lesson.dart';
import 'package:ostinato/app/practice/loop/practice_loop_screen.dart';
import 'package:ostinato/app/practice/loop/practice_marks.dart';
import 'package:ostinato/app/practice/loop/practice_outcome.dart';
import 'package:ostinato/app/practice/loop/practice_progress_store.dart';
import 'package:ostinato/app/practice/loop/practice_score.dart';
import 'package:ostinato/app/practice/loop/v1_course_catalog.dart';
import 'package:ostinato/app/practice/loop/v1_lesson_reader_screen.dart';
import 'package:ostinato/app/practice/loop/v1_practice_list_screen.dart';
import 'package:ostinato/app/practice/setup/setup_profile_store.dart';
import 'package:ostinato/app/tuner/tuner_check_memory.dart';

import 'support/practice_host.dart';

Map<String, dynamic> _json(String id) =>
    jsonDecode(File('content/v1/gtr/$id.json').readAsStringSync())
        as Map<String, dynamic>;

/// A measured lesson (m02-02's body) under another id.
V1Lesson measuredAs(String id) =>
    V1Lesson.fromJson(_json('gtr-s1-m02-02')..['id'] = id);

List<V1Lesson> bundled() => [
  for (final f in Directory('content/v1/gtr').listSync())
    if (f is File && f.path.endsWith('.json'))
      V1Lesson.fromJson(jsonDecode(f.readAsStringSync())),
];

final _score = PracticeScore.parse('E2 F2 G2 F2 | E2 F2 G2 F2');

PracticeRunSummary _passing() => PracticeRunSummary.of(
  score: _score,
  outcomes: [
    for (var i = 0; i < 8; i++)
      NoteOutcome(
        eventIndex: i,
        bar: _score.events[i].bar,
        pass: 0,
        mark: PracticeMark.correct,
        expectedMidi: _score.events[i].midi,
      ),
  ],
  bpm: 60,
  openBpm: 50,
  targetBpm: 60,
  completed: true,
  loopUsed: false,
  waitUsed: false,
  criteria: const PassCriteria(minAccuracy: .8),
);

final class _MemoryProgress implements V1PracticeProgress {
  final Map<String, V1PracticeRecord> records = {};
  @override
  Future<Map<String, V1PracticeRecord>> load() async => Map.of(records);
  @override
  Future<V1PracticeRecord> recordRun(
    String lessonId,
    PracticeRunSummary summary, {
    DateTime? at,
  }) async => records[lessonId] =
      (records[lessonId] ?? V1PracticeRecord(lessonId: lessonId)).withRun(
        summary,
        at ?? DateTime.utc(2026, 11, 1),
      );
}

final class _MemoryChecks implements V1LessonChecks {
  final Map<String, V1LessonCheck> checks = {};
  bool fail = false;
  @override
  Future<Map<String, V1LessonCheck>> load() async => Map.of(checks);
  @override
  Future<V1LessonCheck> record(
    String lessonId,
    V1CheckEvidence evidence, {
    DateTime? at,
  }) async {
    if (fail) throw const FileSystemException('disk full');
    return checks[lessonId] = mergeLessonCheck(
      checks[lessonId],
      V1LessonCheck(
        lessonId: lessonId,
        evidence: evidence,
        at: at ?? DateTime.utc(2026, 11, 2),
      ),
    );
  }
}

class _FakePractice extends StatefulWidget {
  const _FakePractice({required this.onOpen, required this.pass});
  final VoidCallback onOpen;
  final Future<Object?> Function() pass;
  @override
  State<_FakePractice> createState() => _FakePracticeState();
}

class _FakePracticeState extends State<_FakePractice> {
  @override
  void initState() {
    super.initState();
    widget.onOpen();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        TextButton(
          onPressed: () async {
            await widget.pass();
            if (context.mounted) {
              Navigator.of(context).pop(PracticeExit.openNextLesson);
            }
          },
          child: const Text('pass'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(PracticeExit.closed),
          child: const Text('close'),
        ),
      ],
    ),
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

void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 5000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  final course = V1CourseCatalog(bundled());

  testWidgets('measured: module lock, setup once, a gate pass opens the '
      'next module and its first lesson', (tester) async {
    _tall(tester);
    final progress = _MemoryProgress();
    final catalog = V1CourseCatalog([
      measuredAs('gtr-s1-m01-08'),
      measuredAs('gtr-s1-m02-01'),
      measuredAs('gtr-s1-m02-02'),
    ]);
    final opened = <String>[];
    final setupOpened = <int>[];
    final setup = MemorySetupProfileStore();
    await tester.pumpWidget(
      practiceHost(
        V1PracticeListScreen(
          catalog: Future.value(catalog),
          progressFactory: (_) => progress,
          checksFactory: (_) => _MemoryChecks(),
          setupStore: setup,
          openSetup: (_) async {
            setupOpened.add(1);
            final skip = SetupStepRecord(
              SetupStepState.skipped,
              DateTime.utc(2026, 11, 1),
            );
            await setup.update(
              (p) => p.copyWith(
                placement: skip,
                roomStep: skip,
                latencyStep: skip,
                tuningStep: skip,
              ),
            );
          },
          practiceScreenBuilder: (l, p, hasNext) => _FakePractice(
            onOpen: () => opened.add(l.id),
            pass: () => p.recordRun(l.id, _passing()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Guitar course'), findsOneWidget);
    expect(
      find.text('Locked · clear the checkpoint before'),
      findsOneWidget,
      reason: 'module 2 waits for the module 1 gate',
    );
    await tester.tap(find.byKey(const Key('v1-course-unit-gtr-s1-m02')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('v1-practice-gtr-s1-m02-01')));
    await tester.pumpAndSettle();
    expect(opened, isEmpty, reason: 'a locked lesson does not open');
    expect(find.text('Measured'), findsNWidgets(3));
    await tester.tap(find.byKey(const Key('v1-practice-gtr-s1-m01-08')));
    await tester.pumpAndSettle();
    expect(setupOpened, [1]);
    await tester.tap(find.text('pass'));
    await tester.pumpAndSettle();
    expect(opened, ['gtr-s1-m01-08', 'gtr-s1-m02-01']);
    await tester.tap(find.text('close'));
    await tester.pumpAndSettle();
    expect(find.text('COMPLETED · ♩=60'), findsOneWidget);
    expect(find.text('Open · 0 of 2 done'), findsOneWidget);
    // Inside an open module there is no lock.
    expect(find.text('OPEN'), findsNWidgets(2));
    await tester.tap(find.byKey(const Key('v1-practice-gtr-s1-m02-02')));
    await tester.pumpAndSettle();
    expect(opened.last, 'gtr-s1-m02-02');
    expect(setupOpened, [1], reason: 'the wizard runs first only once');
  });

  testWidgets('"Start next lesson": first open lesson not done, course order', (
    tester,
  ) async {
    final progress = _MemoryProgress();
    await progress.recordRun('gtr-s1-m01-08', _passing());
    final catalog = V1CourseCatalog([
      measuredAs('gtr-s1-m01-08'),
      measuredAs('gtr-s1-m02-01'),
    ]);
    final opened = <String>[];
    await tester.pumpWidget(
      practiceHost(
        V1PracticeListScreen(
          startNext: true,
          catalog: Future.value(catalog),
          progressFactory: (_) => progress,
          checksFactory: (_) => _MemoryChecks(),
          setupStore: _visitedSetup(),
          practiceScreenBuilder: (l, p, hasNext) => _FakePractice(
            onOpen: () => opened.add(l.id),
            pass: () => p.recordRun(l.id, _passing()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(opened, ['gtr-s1-m02-01']);
    await tester.tap(find.text('close'));
    await tester.pumpAndSettle();
    expect(find.byType(V1PracticeListScreen), findsOneWidget);
    expect(opened, ['gtr-s1-m02-01'], reason: 'opens once, not on return');
  });

  testWidgets('"Start next lesson" on a fresh course opens the reader of the '
      'first lesson', (tester) async {
    _tall(tester);
    await tester.pumpWidget(
      practiceHost(
        V1PracticeListScreen(
          startNext: true,
          catalog: Future.value(course),
          progressFactory: (_) => _MemoryProgress(),
          checksFactory: (_) => _MemoryChecks(),
          setupStore: _visitedSetup(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(V1LessonReaderScreen), findsOneWidget);
    expect(
      find.text(
        course.lesson('gtr-s1-m01-01')!.lesson.title.en,
        skipOffstage: false,
      ),
      findsWidgets,
    );
  });

  testWidgets('full course: levels, modules and honest chips', (tester) async {
    _tall(tester);
    await tester.pumpWidget(
      practiceHost(
        V1PracticeListScreen(
          catalog: Future.value(course),
          progressFactory: (_) => _MemoryProgress(),
          checksFactory: (_) => _MemoryChecks(),
          setupStore: _visitedSetup(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final level in [1, 2, 3, 4]) {
      expect(find.text('Level $level'), findsOneWidget);
    }
    expect(find.textContaining('All 240 lessons'), findsOneWidget);
    expect(find.text('Module 19A · Acoustic track'), findsOneWidget);
    expect(find.text('Level 4 test · Electric track'), findsOneWidget);
    // Module 1 (the next lesson's) is expanded.
    String chip(String id) =>
        tester.widget<Text>(find.byKey(Key('v1-course-chip-$id'))).data!;
    expect(chip('gtr-s1-m01-01'), 'Reading · on-screen exercise coming soon');
    expect(chip('gtr-s1-m01-02'), 'Checklist · camera check coming soon');
    expect(chip('gtr-s1-m01-04'), 'Tuner');
    expect(chip('gtr-s1-m01-06'), 'Self-check · mic feedback coming soon');
    expect(chip('gtr-s1-m01-07'), 'Measured');
    expect(find.text('Open · 0 of 8 done'), findsOneWidget);
    // Module 4 is locked; its chord lessons are self-checks and its gate is
    // held.
    await tester.tap(find.byKey(const Key('v1-course-unit-gtr-s1-m04')));
    await tester.pumpAndSettle();
    expect(chip('gtr-s1-m04-01'), 'Self-check · mic feedback coming soon');
    expect(chip('gtr-s1-m04-11'), 'Checkpoint held · measurement coming soon');
    expect(
      tester
          .widget<Text>(find.byKey(const Key('v1-course-status-gtr-s1-m04-11')))
          .data,
      'LOCKED · CLEAR THE CHECKPOINT BEFORE',
    );
  });

  testWidgets('reader: self-check needs every tick, saves self-reported', (
    tester,
  ) async {
    _tall(tester);
    final checks = _MemoryChecks();
    await tester.pumpWidget(
      practiceHost(
        V1PracticeListScreen(
          catalog: Future.value(course),
          progressFactory: (_) => _MemoryProgress(),
          checksFactory: (_) => checks,
          setupStore: _visitedSetup(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('v1-practice-gtr-s1-m01-06')));
    await tester.pumpAndSettle();
    expect(find.byType(V1LessonReaderScreen), findsOneWidget);
    expect(
      find.textContaining('Microphone feedback for this lesson is coming soon'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('v1-reader-reference')), findsOneWidget);
    final lesson = course.lesson('gtr-s1-m01-06')!.lesson;
    expect(find.text(lesson.goal.en), findsOneWidget);
    for (final item in lesson.selfCheck) {
      expect(find.text(item.en), findsOneWidget);
    }
    FilledButton mark() => tester.widget<FilledButton>(
      find.byKey(const Key('v1-reader-mark-done')),
    );
    expect(mark().onPressed, isNull);
    for (var i = 0; i < lesson.selfCheck.length - 1; i++) {
      await tester.tap(find.byKey(Key('v1-reader-check-$i')));
    }
    await tester.pump();
    expect(mark().onPressed, isNull, reason: 'one item left');
    await tester.tap(
      find.byKey(Key('v1-reader-check-${lesson.selfCheck.length - 1}')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('v1-reader-mark-done')));
    await tester.pumpAndSettle();
    expect(find.text('Done · self-reported, not measured'), findsOneWidget);
    expect(
      checks.checks['gtr-s1-m01-06']!.evidence,
      V1CheckEvidence.selfReport,
    );
    // Next lesson in course order opens from the reader.
    await tester.tap(find.byKey(const Key('v1-reader-next')));
    await tester.pumpAndSettle();
    expect(
      find.text(course.lesson('gtr-s1-m01-07')!.lesson.title.en),
      findsWidgets,
    );
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Text>(find.byKey(const Key('v1-course-status-gtr-s1-m01-06')))
          .data,
      'DONE · SELF-REPORTED',
    );
    expect(find.text('Open · 1 of 8 done'), findsOneWidget);
  });

  testWidgets('held checkpoint: practised as self-check, next module opens '
      '"not measured"', (tester) async {
    _tall(tester);
    final progress = _MemoryProgress();
    for (final id in ['gtr-s1-m01-08', 'gtr-s1-m02-10']) {
      await progress.recordRun(id, _passing());
    }
    final checks = _MemoryChecks();
    await tester.pumpWidget(
      practiceHost(
        V1PracticeListScreen(
          catalog: Future.value(course),
          progressFactory: (_) => progress,
          checksFactory: (_) => checks,
          setupStore: _visitedSetup(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('v1-course-unit-gtr-s1-m03')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Text>(find.byKey(const Key('v1-course-status-gtr-s1-m03-10')))
          .data,
      'HELD · CANNOT BE PASSED YET',
    );
    await tester.tap(find.byKey(const Key('v1-practice-gtr-s1-m03-10')));
    await tester.pumpAndSettle();
    expect(find.textContaining('cannot be passed now'), findsOneWidget);
    // No checklist of its own: the generic one, with the target tempo.
    final target = course
        .lesson('gtr-s1-m03-10')!
        .lesson
        .practice
        .tempo!
        .target;
    expect(find.text('I played it at the target tempo, ♩=$target.'), findsOne);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(Key('v1-reader-check-$i')));
    }
    await tester.pump();
    await tester.tap(find.byKey(const Key('v1-reader-mark-done')));
    await tester.pumpAndSettle();
    expect(find.textContaining('The checkpoint stays held'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Text>(find.byKey(const Key('v1-course-status-gtr-s1-m03-10')))
          .data,
      'PRACTISED · SELF-REPORTED · NOT MEASURED',
    );
    expect(find.text('Open · not measured · 0 of 11 done'), findsOneWidget);
  });

  testWidgets('tuner lesson: only an all-in-tune tuner check completes it', (
    tester,
  ) async {
    _tall(tester);
    final checks = _MemoryChecks();
    TunerCheck? next;
    await tester.pumpWidget(
      practiceHost(
        V1PracticeListScreen(
          catalog: Future.value(course),
          progressFactory: (_) => _MemoryProgress(),
          checksFactory: (_) => checks,
          setupStore: _visitedSetup(),
          tuner: (_) async => next,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('v1-practice-gtr-s1-m01-04')));
    await tester.pumpAndSettle();
    expect(find.textContaining('±5 cents'), findsOneWidget);
    expect(find.byKey(const Key('v1-reader-mark-done')), findsNothing);
    next = TunerCheck(
      presetId: 'guitar.standard',
      inTune: 5,
      total: 6,
      at: DateTime.utc(2026, 11, 2),
    );
    await tester.tap(find.byKey(const Key('v1-reader-tuner')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Not every string was in tune'), findsOneWidget);
    expect(checks.checks, isEmpty);
    next = TunerCheck(
      presetId: 'guitar.standard',
      inTune: 6,
      total: 6,
      at: DateTime.utc(2026, 11, 2),
    );
    await tester.tap(find.byKey(const Key('v1-reader-tuner')));
    await tester.pumpAndSettle();
    expect(
      find.text('Tuned · all strings in tune, measured by the tuner'),
      findsOneWidget,
    );
    expect(
      checks.checks['gtr-s1-m01-04']!.evidence,
      V1CheckEvidence.tunerCheck,
    );
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Text>(find.byKey(const Key('v1-course-status-gtr-s1-m01-04')))
          .data,
      'TUNED · MEASURED BY THE TUNER',
    );
  });

  testWidgets('reader: a failed save says so; Turkish copy', (tester) async {
    _tall(tester);
    final checks = _MemoryChecks()..fail = true;
    final lesson = course.lesson('gtr-s2-m08-09')!;
    expect(lesson.availability, V1LessonAvailability.selfCheckLesson);
    await tester.pumpWidget(
      practiceHost(
        locale: 'tr',
        V1LessonReaderScreen(lesson: lesson, checks: checks),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Bu ders bir öz-kontrol dersidir'), findsOne);
    for (var i = 0; i < lesson.lesson.selfCheck.length; i++) {
      await tester.tap(find.byKey(Key('v1-reader-check-$i')));
    }
    await tester.pump();
    await tester.tap(find.byKey(const Key('v1-reader-mark-done')));
    await tester.pumpAndSettle();
    expect(find.text('Kaydedilemedi. Tekrar dene.'), findsOneWidget);
    expect(checks.checks, isEmpty);
  });
}
