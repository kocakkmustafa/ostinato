import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/app_locale.dart';
import 'package:ostinato/app/guitar_journey.dart';
import 'package:ostinato/app/guitar_journey_progress.dart';
import 'package:ostinato/app/screens/guitar_journey_screen.dart';

const _updatedLessons = <String>[
  'guitar.journey.start.parts',
  'guitar.journey.start.fret',
  'guitar.journey.start.first_pulse',
  'guitar.journey.notes.bass_e',
  'guitar.journey.reading.quarters_eighths',
  'guitar.journey.reading.rests_ties',
  'guitar.journey.reading.staff',
  'guitar.journey.reading.reading_checkpoint',
];

void main() {
  for (final lessonId in _updatedLessons) {
    testWidgets('updated teaching renders in the real Turkish lab: $lessonId', (tester) async {
      await _renderLesson(tester, lessonId, const Locale('tr'));
    });
  }
  testWidgets('the original reading card renders in the real Arabic lab', (tester) async {
    await _renderLesson(tester, _updatedLessons.last, const Locale('ar'));
  });
}

Future<void> _renderLesson(WidgetTester tester, String lessonId, Locale locale) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final directory = Directory.systemTemp.createTempSync('ostinato-education-ui-');
  addTearDown(() => directory.deleteSync(recursive: true));
  final course = GuitarJourneyCourse.fromJson(
    jsonDecode(File('assets/content/guitar_journey.v1.json').readAsStringSync()) as Map<String, dynamic>,
  );
  final lesson = course.lessons.singleWhere((l) => l.id == lessonId);
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: appSupportedLocales,
      localizationsDelegates: appLocalizationsDelegates,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
        child: child!,
      ),
      home: GuitarJourneyLessonScreen(
        course: course,
        lesson: lesson,
        store: GuitarJourneyProgressStore(directoryProvider: () async => directory),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final acknowledge = find.byKey(const Key('guitar-session-acknowledge'));
  if (acknowledge.evaluate().isNotEmpty) {
    await tester.ensureVisible(acknowledge);
    await tester.tap(acknowledge);
    await tester.pumpAndSettle();
  }
  expect(find.byKey(Key('guitar-learning-lab-$lessonId')), findsOneWidget);
  for (final drill in lesson.learningLab!.drills) {
    final text = drill.task.of(tester.element(find.byKey(Key('guitar-learning-lab-$lessonId'))));
    expect(find.text(text, skipOffstage: false), findsWidgets);
  }
  expect(tester.takeException(), isNull);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}
