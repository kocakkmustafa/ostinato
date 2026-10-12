import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/study_review.dart';
import 'package:ostinato/app/study_review_content.dart';

void main() {
  test('approved domains have bilingual recall and source references', () {
    expect(studyAreas.map((a) => a.id).toSet(), <String>{"piano", "vocal", "ukulele", "bass"});
    final ids = <String>{};
    for (final area in studyAreas) {
      expect(area.sourceRefs, isNotEmpty);
      expect(area.lessons, hasLength(2));
      for (final lesson in area.lessons) {
        expect(ids.add(lesson.id), isTrue);
        for (final text in [area.title, area.boundary, lesson.title,
          lesson.teaching, lesson.question, lesson.answer]) {
          expect(text.en.trim(), isNotEmpty);
          expect(text.tr.trim(), isNotEmpty);
        }
      }
    }
  });

  Future<void> smallSurface(WidgetTester t, String language) async {
    t.view.physicalSize = const Size(320, 900);
    t.view.devicePixelRatio = 1;
    t.binding.platformDispatcher.localeTestValue = Locale(language);
    t.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.binding.platformDispatcher.clearLocaleTestValue);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
  }

  Future<void> tapVisible(WidgetTester t, Finder target) async {
    if (target.evaluate().isEmpty) {
      await t.scrollUntilVisible(target, 250, scrollable: find.byType(Scrollable).first);
    }
    await t.ensureVisible(target);
    await t.pumpAndSettle();
    await t.tap(target);
    await t.pumpAndSettle();
  }

  for (final language in ['en', 'tr']) {
    testWidgets('$language entry reaches every area and reference at 320px/2x', (t) async {
      await smallSurface(t, language);
      await t.pumpWidget(MaterialApp(locale: Locale(language),
        supportedLocales: const [Locale('en'), Locale('tr')],
        localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
        home: const Scaffold(body: StudyReviewEntry())));
      await tapVisible(t, find.byKey(const Key('study-review-entry')));
      for (final area in studyAreas) {
        final lesson = area.lessons.first;
        final target = find.byKey(Key('study-lesson-${lesson.id}'));
        // ListView children are materialized lazily at the current scroll position.
        await t.scrollUntilVisible(target, 250, scrollable: find.byType(Scrollable).first);
        await tapVisible(t, target);
        expect(find.byKey(const Key('study-reference')), findsNothing);
        await tapVisible(t, find.byKey(const Key('study-reference-toggle')));
        expect(find.byKey(const Key('study-reference')), findsOneWidget);
        expect(find.text(language == 'tr' ? lesson.answer.tr : lesson.answer.en), findsOneWidget);
        expect(t.takeException(), isNull);
        await t.tap(find.byType(BackButton));
        await t.pumpAndSettle();
      }
      expect(t.takeException(), isNull);
    });
  }

  for (final status in RecallObservation.values) {
    testWidgets('${status.name} gives a distinct next step without promotion', (t) async {
      final area = studyAreas.first;
      await t.pumpWidget(MaterialApp(home: RecallLessonPage(area: area, lesson: area.lessons.first)));
      expect(find.byKey(const Key('study-feedback')), findsNothing);
      await tapVisible(t, find.byKey(Key('study-state-${status.name}')));
      expect(find.byKey(const Key('study-feedback')), findsOneWidget);
      final message = t.widget<Text>(find.byKey(const Key('study-feedback'))).data!;
      if (status == RecallObservation.uncertain) expect(message, contains('uncertainty'));
      if (status == RecallObservation.difference) expect(message, contains('written answers'));
      if (status == RecallObservation.notAttempted) expect(message, contains('unattempted'));
      if (status == RecallObservation.stopped) {
        expect(message, contains('End this activity'));
        expect(find.byKey(const Key('study-next')), findsNothing);
      } else {
        await t.scrollUntilVisible(find.byKey(const Key('study-next')), 200, scrollable: find.byType(Scrollable).first);
        expect(find.byKey(const Key('study-next')), findsOneWidget);
      }
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('notes, revealed reference and observation are discarded on leaving', (t) async {
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: StudyReviewEntry())));
    await tapVisible(t, find.byKey(const Key('study-review-entry')));
    final key = Key('study-lesson-${studyAreas.first.lessons.first.id}');
    await tapVisible(t, find.byKey(key));
    await t.enterText(find.byKey(const Key('study-answer')), 'private temporary written answer');
    // Remove keyboard before exercising the scroll path.
    t.testTextInput.hide();
    await t.pumpAndSettle();
    await tapVisible(t, find.byKey(const Key('study-reference-toggle')));
    await tapVisible(t, find.byKey(const Key('study-state-uncertain')));
    await t.tap(find.byType(BackButton));
    await t.pumpAndSettle();
    await tapVisible(t, find.byKey(key));
    final answer = t.widget<TextField>(find.byKey(const Key('study-answer')));
    expect(answer.controller!.text, isEmpty);
    expect(find.byKey(const Key('study-reference')), findsNothing);
    expect(find.byKey(const Key('study-feedback')), findsNothing);
  });
}
