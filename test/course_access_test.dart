import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/app_locale.dart';
import 'package:ostinato/app/course_access.dart';
import 'package:ostinato/app/guitar_journey.dart';
import 'package:ostinato/app/guitar_journey_progress.dart';
import 'package:ostinato/app/ostinato_release_policy.dart';
import 'package:ostinato/app/screens/guitar_journey_screen.dart';
import 'package:ostinato/app/screens/ukulele_beginner_screen.dart';
import 'package:ostinato/app/ukulele_beginner.dart';

import 'support/localized_widget_ready.dart';
import 'support/paid_access_scope.dart';

class _Files extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(File(key).readAsBytesSync());
}

// Paywall A against the real ukulele course screen and packaged course bytes;
// only the membership answer behind Core's guard is synthetic.
void main() {
  setUpAll(prepareRootTranslations);

  test('free range follows paywall A and closes unknown courses', () {
    expect(ostinatoPaidFeaturesAvailable, isTrue);
    expect(isFreeLesson('guitar', 11), isTrue);
    expect(isFreeLesson('guitar', 12), isFalse);
    for (final id in ['piano', 'ukulele', 'bass', 'voice']) {
      expect(isFreeLesson(id, 7), isTrue, reason: id);
      expect(isFreeLesson(id, 8), isFalse, reason: id);
    }
    expect(isFreeLesson('cello', 0), isFalse);
    expect(
      isFreeLesson('guitar', 59, paidFeaturesAvailable: false),
      isTrue,
      reason: 'with sales closed nothing is gated',
    );
  });

  Future<UkuleleCourse> pumpCourse(
    WidgetTester tester, {
    PaidAccessProbe? paid,
    String locale = 'en',
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final app = MaterialApp(
      locale: Locale(locale),
      supportedLocales: appSupportedLocales,
      localizationsDelegates: appLocalizationsDelegates,
      home: UkuleleBeginnerScreen(bundle: _Files()),
    );
    await tester.pumpWidget(paid == null ? app : paid.wrap(app));
    await tester.pumpAndSettle();
    return UkuleleCourse.fromJson(
      jsonDecode(File(ukuleleAsset).readAsStringSync()),
    );
  }

  Future<void> tapLesson(WidgetTester tester, String id) async {
    final tile = find.byKey(Key(id));
    await tester.scrollUntilVisible(
      tile,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(tile);
    await tester.pumpAndSettle();
  }

  for (final locale in ['en', 'tr']) {
    testWidgets('course states the free range and marks paid lessons ($locale)', (
      tester,
    ) async {
      final course = await pumpCourse(tester, locale: locale);
      expect(
        find.text(
          locale == 'tr'
              ? '1–8. dersler ücretsizdir. Sonraki dersler Ostinato veya Motion+ aboneliği gerektirir; ilerleme kayıtların her zaman görünür kalır.'
              : 'Lessons 1–8 are free. Later lessons need an Ostinato or Motion+ subscription; your progress records always stay visible.',
        ),
        findsOneWidget,
      );
      final mark = find.bySemanticsLabel(
        locale == 'tr' ? 'Abonelik dersi' : 'Subscription lesson',
      );
      final free = find.byKey(Key(course.lessons[7].id));
      final paid = find.byKey(Key(course.lessons[8].id));
      await tester.scrollUntilVisible(
        paid,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: paid, matching: find.byIcon(Icons.lock_outline)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: free, matching: find.byIcon(Icons.lock_outline)),
        findsNothing,
      );
      expect(mark, findsWidgets);
      // Titles of paid lessons stay readable in the list.
      expect(
        find.text(
          '9. ${locale == 'tr' ? course.lessons[8].title.tr : course.lessons[8].title.en}',
        ),
        findsOneWidget,
      );
    });
  }

  testWidgets('a free lesson opens without asking for membership', (
    tester,
  ) async {
    final paid = PaidAccessProbe(member: false);
    addTearDown(paid.dispose);
    final course = await pumpCourse(tester, paid: paid);
    await tapLesson(tester, course.lessons[7].id);
    expect(paid.calls, 0);
    expect(find.text(course.lessons[7].title.en), findsOneWidget);
  });

  testWidgets('a non-member stays on the list for a paid lesson', (
    tester,
  ) async {
    final paid = PaidAccessProbe(member: false);
    addTearDown(paid.dispose);
    final course = await pumpCourse(tester, paid: paid);
    await tapLesson(tester, course.lessons[8].id);
    expect(paid.calls, 1);
    expect(
      find.text(course.lessons[8].title.en),
      findsNothing,
      reason: 'no lesson route',
    );
    expect(find.byType(UkuleleBeginnerScreen), findsOneWidget);
  });

  testWidgets('a member opens a paid lesson and crosses the boundary by Next', (
    tester,
  ) async {
    final paid = PaidAccessProbe();
    addTearDown(paid.dispose);
    final course = await pumpCourse(tester, paid: paid);
    await tapLesson(tester, course.lessons[7].id);
    expect(paid.calls, 0);
    final next = find.text('Next lesson');
    await tester.scrollUntilVisible(
      next,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(paid.calls, 1);
    expect(find.text(course.lessons[8].title.en), findsOneWidget);
  });

  testWidgets('a lapsed member cannot move into the next paid lesson', (
    tester,
  ) async {
    final paid = PaidAccessProbe();
    addTearDown(paid.dispose);
    final course = await pumpCourse(tester, paid: paid);
    await tapLesson(tester, course.lessons[8].id);
    expect(paid.calls, 1);
    paid.member = false;
    final next = find.text('Next lesson');
    await tester.scrollUntilVisible(
      next,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(paid.calls, 2);
    expect(find.text(course.lessons[8].title.en), findsOneWidget);
    expect(find.text(course.lessons[9].title.en), findsNothing);
  });

  testWidgets(
    'without an account service a paid lesson stays closed and says why',
    (tester) async {
      final course = await pumpCourse(tester);
      await tapLesson(tester, course.lessons[8].id);
      expect(find.byType(UkuleleBeginnerScreen), findsOneWidget);
      expect(find.text(course.lessons[8].title.en), findsNothing);
      expect(
        find.text(
          'This lesson needs a subscription, and the account service is unavailable right now.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'guitar lesson 13 needs membership while its progress stays readable',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final root = Directory.systemTemp.createTempSync('ostinato-paywall-');
      addTearDown(() => root.deleteSync(recursive: true));
      final course = GuitarJourneyCourse.fromJson(
        jsonDecode(
              File('assets/content/guitar_journey.v1.json').readAsStringSync(),
            )
            as Map<String, dynamic>,
      );
      final paid = PaidAccessProbe(member: false);
      addTearDown(paid.dispose);
      await tester.pumpWidget(
        paid.wrap(
          MaterialApp(
            home: GuitarJourneyScreen(
              initialCourse: course,
              initialProgress: const {},
              progressStoreFactory: (_) => GuitarJourneyProgressStore(
                directoryProvider: () async => root,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('free-lessons-guitar')), findsOneWidget);
      final reading = course.modules[2];
      expect(course.lessons.indexOf(reading.lessons.first), 12);
      final moduleTile = find.byKey(Key('guitar-module-${reading.id}'));
      await tester.scrollUntilVisible(
        moduleTile,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(moduleTile);
      await tester.pumpAndSettle();
      final lessonTile = find.byKey(
        Key('guitar-lesson-${reading.lessons.first.id}'),
      );
      await tester.scrollUntilVisible(
        lessonTile,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: lessonTile, matching: find.text('NOT STARTED')),
        findsOneWidget,
        reason: 'the progress record of a paid lesson stays readable',
      );
      expect(
        find.descendant(
          of: lessonTile,
          matching: find.byIcon(Icons.lock_outline),
        ),
        findsOneWidget,
      );
      await tester.tap(lessonTile);
      await tester.pumpAndSettle();
      expect(paid.calls, 1);
      expect(
        find.byKey(Key('guitar-lesson-title-${reading.lessons.first.id}')),
        findsNothing,
      );
      expect(
        isFreeLesson(
          'guitar',
          course.lessons.indexOf(course.modules[1].lessons.last),
        ),
        isTrue,
      );
    },
  );
}
