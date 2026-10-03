import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/guitar_journey.dart';
import 'package:ostinato/app/guitar_journey_progress.dart';
import 'package:ostinato/app/screens/guitar_journey_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Map<String, dynamic> source() =>
      jsonDecode(
            File('assets/content/guitar_journey.v1.json').readAsStringSync(),
          )
          as Map<String, dynamic>;

  test('only an explicitly revised lesson receives a new progress key', () {
    final raw = source();
    final first =
        ((raw['modules'] as List).first['lessons'] as List).first
            as Map<String, dynamic>;
    first['progressRevision'] = 'materials_1';
    final course = GuitarJourneyCourse.fromJson(raw);
    expect(course.lessons.length, 60);
    expect(
      course.lessons.first.progressVersionFor(course.contentVersion),
      '${course.contentVersion}~materials_1',
    );
    expect(
      course.lessons
          .skip(1)
          .every(
            (lesson) =>
                lesson.progressVersionFor(course.contentVersion) ==
                course.contentVersion,
          ),
      isTrue,
    );
    first['progressRevision'] = 'bad|key';
    expect(() => GuitarJourneyCourse.fromJson(raw), throwsFormatException);
  });

  testWidgets('revised lesson does not inherit an old completion or erase it', (
    tester,
  ) async {
    final raw = source();
    final lessons = (raw['modules'] as List).first['lessons'] as List;
    final first = lessons.first as Map<String, dynamic>;
    first['progressRevision'] = 'materials_1';
    final course = GuitarJourneyCourse.fromJson(raw);
    final firstId = course.lessons.first.id;
    final secondId = course.lessons[1].id;
    final root = Directory.systemTemp.createTempSync('guitar-revision-');
    addTearDown(() => root.deleteSync(recursive: true));
    final store = GuitarJourneyProgressStore(
      directoryProvider: () async => root,
    );
    final oldRecords = await tester.runAsync(() async {
      for (final id in [firstId, secondId]) {
        await store.record(
          lessonId: id,
          contentVersion: course.contentVersion,
          action: GuitarProgressAction.practiced,
        );
        await store.record(
          lessonId: id,
          contentVersion: course.contentVersion,
          action: GuitarProgressAction.selfReportedCompleted,
        );
      }
      return store.load();
    });
    final oldFile = File('${root.path}/guitar_journey_progress.v1.json');
    final oldText = oldFile.readAsStringSync();
    await tester.pumpWidget(
      MaterialApp(
        home: GuitarJourneyScreen(
          initialCourse: course,
          initialProgress: oldRecords!,
          progressStoreFactory: (_) => store,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('1 of 60 self-reported complete'), findsOneWidget);
    expect(oldFile.readAsStringSync(), oldText);

    final firstTile = find.byKey(Key('guitar-lesson-$firstId'));
    await tester.ensureVisible(firstTile);
    await tester.tap(firstTile);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('guitar-previous-version-completion')),
      findsOneWidget,
    );
    expect(find.textContaining('earlier version'), findsOneWidget);
    final viewed = find.text('Mark viewed');
    await tester.ensureVisible(viewed);
    await tester.runAsync(() async {
      await tester.tap(viewed);
      await store.load();
    });
    await tester.pumpAndSettle();
    Map<String, GuitarLessonProgress>? records;
    final newKey =
        '${course.lessons.first.progressVersionFor(course.contentVersion)}|$firstId';
    for (var attempt = 0; attempt < 40; attempt++) {
      records = await tester.runAsync(store.load);
      await tester.pump();
      if (records?[newKey]?.seenAt != null) break;
    }
    final oldFirst = records!['${course.contentVersion}|$firstId'];
    final newFirst = records[newKey];
    expect(oldFirst?.selfReportedCompletedAt, isNotNull);
    expect(newFirst?.seenAt, isNotNull);
    expect(newFirst?.selfReportedCompletedAt, isNull);
    expect(
      records['${course.contentVersion}|$secondId']?.selfReportedCompletedAt,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('eight newly required lessons leave 52 earlier completions', (
    tester,
  ) async {
    final raw = source();
    const targetIndices = {6, 12, 29, 39, 53, 54, 55, 56};
    var index = 0;
    for (final module in raw['modules'] as List) {
      for (final lesson in module['lessons'] as List) {
        if (targetIndices.contains(index)) {
          (lesson as Map<String, dynamic>)['progressRevision'] = 'materials_1';
        }
        index++;
      }
    }
    final course = GuitarJourneyCourse.fromJson(raw);
    final oldRecords = <String, GuitarLessonProgress>{
      for (final lesson in course.lessons)
        '${course.contentVersion}|${lesson.id}': GuitarLessonProgress(
          lessonId: lesson.id,
          contentVersion: course.contentVersion,
          practiceCount: 1,
          selfReportedCompletedAt: DateTime.utc(2026, 9, 26),
        ),
    };
    expect(oldRecords.length, 60);
    await tester.pumpWidget(
      MaterialApp(
        home: GuitarJourneyScreen(
          initialCourse: course,
          initialProgress: oldRecords,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('52 of 60 self-reported complete'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('guitar-journey-next')),
        matching: find.text(course.lessons[6].title.en),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
