import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/app_locale.dart';
import 'package:ostinato/app/screens/piano_beginner_screen.dart';
import 'package:ostinato/app/screens/ukulele_beginner_screen.dart';
import 'package:ostinato/app/screens/bass_beginner_screen.dart';
import 'package:ostinato/app/screens/vocal_beginner_screen.dart';
import 'support/localized_widget_ready.dart';
import 'support/paid_access_scope.dart';

/// Paywall A: course walks run as a member; the lock itself is covered by
/// course_access_test.dart.
Widget _asMember(Widget app) => PaidAccessProbe().wrap(app);

class _Files extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(Uint8List.fromList(File(key).readAsBytesSync()));
}

List<dynamic> _lessons(String kind) =>
    (jsonDecode(
              File(
                'assets/content/${kind}_beginner.v1.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>)['lessons']
        as List<dynamic>;

Future<void> _mount(WidgetTester tester, String kind, String locale) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final bundle = _Files();
  final home = switch (kind) {
    'piano' => PianoBeginnerScreen(bundle: bundle),
    'ukulele' => UkuleleBeginnerScreen(bundle: bundle),
    'bass' => BassBeginnerScreen(bundle: bundle),
    _ => VocalBeginnerScreen(bundle: bundle),
  };
  await tester.pumpWidget(
    _asMember(
      MaterialApp(
        locale: Locale(locale),
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationsDelegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(2)),
          child: child!,
        ),
        home: home,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    250,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  expect(target.hitTestable(), findsOneWidget);
  await tester.tap(target);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

Finder _previous(String kind) => find.byKey(Key('$kind-previous-lesson'));
Finder _next(String locale) =>
    find.text(locale == 'tr' ? 'Sonraki ders' : 'Next lesson');
void _title(List<dynamic> lessons, int index, String locale) => expect(
  find.widgetWithText(
    AppBar,
    ((lessons[index] as Map)['title'] as Map)[locale] as String,
  ),
  findsOneWidget,
);

void main() {
  setUpAll(prepareRootTranslations);
  for (final kind in ['piano', 'ukulele', 'bass', 'vocal']) {
    for (final locale in ['en', 'tr']) {
      testWidgets('$kind $locale repeated Previous/Next then one Back at2x', (
        tester,
      ) async {
        final lessons = _lessons(kind);
        await _mount(tester, kind, locale);
        final second = find.byKey(Key((lessons[1] as Map)['id'] as String));
        await _tap(tester, second);
        for (var repeat = 0; repeat < 3; repeat++) {
          await _tap(tester, _previous(kind));
          _title(lessons, 0, locale);
          expect(_previous(kind), findsNothing);
          await _tap(tester, _next(locale));
          _title(lessons, 1, locale);
        }
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(second, findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('$kind $locale last lesson has Previous and no Next at2x', (
        tester,
      ) async {
        final lessons = _lessons(kind);
        await _mount(tester, kind, locale);
        final last = find.byKey(Key((lessons.last as Map)['id'] as String));
        await _tap(tester, last);
        _title(lessons, lessons.length - 1, locale);
        expect(_next(locale), findsNothing);
        await tester.scrollUntilVisible(
          _previous(kind),
          250,
          scrollable: find.byType(Scrollable).first,
        );
        final position = tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position;
        position.jumpTo(position.maxScrollExtent);
        await tester.pumpAndSettle();
        expect(_next(locale), findsNothing);
        await _tap(tester, _previous(kind));
        _title(lessons, lessons.length - 2, locale);
        await _tap(tester, _next(locale));
        _title(lessons, lessons.length - 1, locale);
        expect(_next(locale), findsNothing);
        await tester.scrollUntilVisible(
          _previous(kind),
          250,
          scrollable: find.byType(Scrollable).first,
        );
        final returnedPosition = tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position;
        returnedPosition.jumpTo(returnedPosition.maxScrollExtent);
        await tester.pumpAndSettle();
        expect(_next(locale), findsNothing);
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(last, findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets(
        '$kind $locale revealed answers reset on both revisit paths',
        (tester) async {
          final lessons = _lessons(kind);
          final (number, answerKey) = switch (kind) {
            'piano' => (14, 'piano-answers-14'),
            'ukulele' => (14, 'ukulele-tab-answers'),
            'bass' => (12, 'bass-tab-answers'),
            _ => (9, 'vocal-contour-answers'),
          };
          await _mount(tester, kind, locale);
          await _tap(
            tester,
            find.byKey(Key((lessons[number - 1] as Map)['id'] as String)),
          );
          final answer = find.byKey(Key(answerKey));
          for (final goBackFirst in [true, false]) {
            await tester.scrollUntilVisible(
              answer,
              250,
              scrollable: find.byType(Scrollable).first,
            );
            final child = tester.widget<ExpansionTile>(answer).children.first;
            expect(find.byWidget(child), findsNothing);
            await _tap(tester, answer);
            expect(find.byWidget(child), findsOneWidget);
            await _tap(tester, goBackFirst ? _previous(kind) : _next(locale));
            await _tap(tester, goBackFirst ? _next(locale) : _previous(kind));
            _title(lessons, number - 1, locale);
            await tester.scrollUntilVisible(
              answer,
              250,
              scrollable: find.byType(Scrollable).first,
            );
            final resetChild = tester
                .widget<ExpansionTile>(answer)
                .children
                .first;
            expect(find.byWidget(resetChild), findsNothing);
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
