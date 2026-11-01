import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/retention/weekly_goal.dart';
import 'package:ostinato/app/retention/weekly_goal_card.dart';
import 'package:ostinato/app/retention/weekly_goal_store.dart';

/// File I/O completes on the real event loop; each completion then needs a
/// frame in the test zone. A few rounds cover the read-modify-write chain.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
}

void main() {
  late Directory root;
  late DateTime utcNow;
  const offset = Duration(hours: 3);

  WeeklyGoalStore store() => WeeklyGoalStore(
    directoryProvider: () async => root,
    clock: () => LocalInstant(utcNow, offset),
  );

  setUp(() async {
    root = await Directory.systemTemp.createTemp('weekly_goal_');
    // Monday 2026-11-02 10:00 in UTC+3.
    utcNow = DateTime.utc(2026, 11, 2, 7);
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('empty store reports the default goal and no streak', () async {
    final status = await store().load();
    expect(status.goal, 3);
    expect(status.credit, 0);
    expect(status.streakActive, isFalse);
    expect(status.freezesLeft, 2);
    expect(File('${root.path}/${WeeklyGoalStore.fileName}').existsSync(),
        isFalse);
  });

  test('records survive reload and keep only day, kind and course', () async {
    await store().recordLessonPractice(PracticeCourse.guitar);
    utcNow = utcNow.add(const Duration(days: 1));
    await store().recordOffAppPractice();
    utcNow = utcNow.add(const Duration(days: 1));
    final status = await store().recordLessonPractice(PracticeCourse.guitar);
    expect(status.currentWeekMet, isTrue);
    expect((await store().load()).streakWeeks, 1);

    final raw = jsonDecode(
      File('${root.path}/${WeeklyGoalStore.fileName}').readAsStringSync(),
    ) as Map<String, dynamic>;
    expect(raw['schemaVersion'], 1);
    for (final e in raw['entries'] as List<dynamic>) {
      expect((e as Map).keys.toSet(), {'day', 'kind', 'course'});
    }
  });

  test('the day comes from the injected local clock', () async {
    // 22:30 UTC Sunday is 01:30 Monday in UTC+3: a new week.
    utcNow = DateTime.utc(2026, 11, 8, 22, 30);
    final status = await store().recordOffAppPractice();
    expect(status.weekStart, LocalDay(2026, 11, 9));
    expect(status.practiceDays, 1);
  });

  test('a measured session below the minimum is not counted', () async {
    final short = await store().recordPracticeSession(
      const MeasuredPracticeSession(
        course: PracticeCourse.guitar,
        activeDuration: Duration(seconds: 30),
        heardEvents: 12,
      ),
    );
    expect(short.counted, isFalse);
    expect(short.status.credit, 0);
    final ok = await store().recordPracticeSession(
      const MeasuredPracticeSession(
        course: PracticeCourse.guitar,
        activeDuration: Duration(minutes: 4),
        heardEvents: 12,
      ),
    );
    expect(ok.counted, isTrue);
    expect(ok.status.credit, 1);
  });

  test('goal changes replace earlier ones in the same week', () async {
    await store().setGoal(5);
    final status = await store().setGoal(2);
    expect(status.goal, 2);
    expect((await store().loadData()).goalChanges, hasLength(1));
    expect(() => store().setGoal(0), throwsArgumentError);
    expect(() => store().setGoal(8), throwsArgumentError);
  });

  test('voice rest day is stored as a voice entry', () async {
    final status = await store().recordVoiceRestDay();
    expect(status.practiceDays, 0);
    expect(status.restDaysCredited, 1);
  });

  test('an unknown schema is refused, not reset', () async {
    File('${root.path}/${WeeklyGoalStore.fileName}')
        .writeAsStringSync('{"schemaVersion":2,"entries":[],"goalChanges":[]}');
    await expectLater(store().load(), throwsFormatException);
  });

  testWidgets('home card shows progress and records an off-app entry', (
    tester,
  ) async {
    await tester.runAsync(() => store().recordLessonPractice(
          PracticeCourse.guitar,
        ));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: WeeklyGoalCard(storeFactory: (_) => store()),
          ),
        ),
      ),
    );
    await settle(tester);
    expect(find.byKey(const Key('weekly-goal-card')), findsOneWidget);
    expect(find.text('1 of 3 sessions'), findsOneWidget);
    expect(
      find.textContaining("Meet this week's goal to start"),
      findsOneWidget,
    );

    utcNow = utcNow.add(const Duration(days: 1));
    await tester.runAsync(
      () => tester.tap(find.byKey(const Key('weekly-goal-off-app'))),
    );
    await settle(tester);
    expect(find.text('2 of 3 sessions'), findsOneWidget);
    expect(find.text('Saved for today.'), findsOneWidget);
    expect(find.textContaining('wrong', findRichText: true), findsNothing);
  });
}
