import 'dart:convert';
import 'dart:io';
import 'package:ostinato/app/study_review.dart';
import 'package:ostinato/app/screens/piano_beginner_screen.dart';
import 'package:ostinato/app/screens/vocal_beginner_screen.dart';
import 'package:ostinato/app/screens/ukulele_beginner_screen.dart';
import 'package:ostinato/app/screens/bass_beginner_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> tapVisible(WidgetTester t, String key) async {
  final target = find.byKey(Key(key));
  if (target.hitTestable().evaluate().isEmpty) {
    await t.scrollUntilVisible(
      target,
      300,
      maxScrolls: 100,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await t.ensureVisible(target);
  await t.pumpAndSettle();
  expect(target.hitTestable(), findsOneWidget);
  await t.tap(target.hitTestable());
  await t.pumpAndSettle();
  expect(t.takeException(), isNull);
}

Future<void> mount(WidgetTester t, Widget home, String language) async {
  t.view.physicalSize = const Size(320, 900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      locale: Locale(language),
      supportedLocales: const [Locale('en'), Locale('tr')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(2)),
        child: child!,
      ),
      home: home,
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  for (final language in ['en', 'tr']) {
    testWidgets(
      '$language recall opens four real written courses and returns at 320px/2x',
      (t) async {
        await mount(t, const Scaffold(body: StudyReviewEntry()), language);
        await tapVisible(t, 'study-review-entry');
        for (final entry in <String, Type>{
          'piano': PianoBeginnerScreen,
          'vocal': VocalBeginnerScreen,
          'ukulele': UkuleleBeginnerScreen,
          'bass': BassBeginnerScreen,
        }.entries) {
          await tapVisible(t, 'study-course-${entry.key}');
          expect(find.byType(entry.value), findsOneWidget);
          expect(find.byType(CircularProgressIndicator), findsNothing);
          final data =
              jsonDecode(
                    File(
                      'assets/content/${entry.key}_beginner.v1.json',
                    ).readAsStringSync(),
                  )
                  as Map;
          final lesson = (data['lessons'] as List).first as Map;
          await tapVisible(t, lesson['id'] as String);
          expect(
            find.widgetWithText(
              AppBar,
              (lesson['title'] as Map)[language] as String,
            ),
            findsOneWidget,
          );
          await t.tap(find.byType(BackButton));
          await t.pumpAndSettle();
          await t.tap(find.byType(BackButton));
          await t.pumpAndSettle();
          expect(find.byType(StudyReviewPage), findsOneWidget);
        }
        expect(t.takeException(), isNull);
      },
    );
  }
}
