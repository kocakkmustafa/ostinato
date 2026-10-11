import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/app_locale.dart';
import 'package:ostinato/app/guitar_journey.dart';
import 'package:ostinato/app/screens/piano_beginner_screen.dart';
import 'package:ostinato/app/screens/piano_visual_practice_screen.dart';
import 'package:ostinato/app/screens/visual_practice_loop.dart';

class _Files extends CachingAssetBundle {
  _Files({this.corrupt = false});
  final bool corrupt;
  @override
  Future<ByteData> load(String key) async {
    final bytes = File(key).readAsBytesSync();
    if (corrupt && key == 'assets/content/piano_beginner.v1.json') {
      bytes[10] ^= 1;
    }
    return ByteData.sublistView(Uint8List.fromList(bytes));
  }
}

Widget _app(Widget child, String locale) => MaterialApp(
  locale: Locale(locale),
  supportedLocales: appSupportedLocales,
  localizationsDelegates: appLocalizationsDelegates,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(2)),
    child: child!,
  ),
  home: child,
);

void _narrow(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetViewInsets);
}

Future<void> _show(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      250,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String key) async {
  final matches = find.byKey(Key(key));
  if (matches.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      matches,
      250,
      scrollable: find.byType(Scrollable).first,
    );
  }
  final target = matches.first;
  await _show(tester, target);
  expect(target.hitTestable(), findsOneWidget);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

String _note(WidgetTester tester) => tester
    .widget<TextField>(find.byKey(const Key('visual-observation-location')))
    .controller!
    .text;
String _active(WidgetTester tester) => tester
    .widget<Text>(find.byKey(const Key('visual-active-instruction')))
    .data!;
Future<void> _count(WidgetTester tester, String locale, int count) async {
  final heading = find.byKey(const Key('visual-active-heading'));
  await _show(tester, heading);
  expect(
    find.descendant(
      of: heading,
      matching: find.text(
        locale == 'tr' ? 'Ölçü 1 · sayım $count' : 'Bar 1 · count $count',
      ),
    ),
    findsOneWidget,
  );
  final grid = find.byKey(Key('piano-visual-count-$count'));
  await _show(tester, grid);
  expect(tester.widget<Semantics>(grid).properties.selected, isTrue);
  expect(
    tester.getSemantics(grid).label,
    contains(locale == 'tr' ? 'Sayım $count' : 'Count $count'),
  );
}

VisualPracticeLoop _loop(List<VisualPracticeStep> steps) => VisualPracticeLoop(
  taskIdentity: 'unit.same-task.v1',
  steps: steps,
  target: const GuitarText('Target', 'Hedef'),
  observationPrompt: const GuitarText('Own report', 'Kendi beyanın'),
  recovery: const GuitarText('Smaller task', 'Küçük görev'),
  diagram: (_, _) => const SizedBox(),
  retryChoices: const SizedBox(),
);

void _widgetTest(String description, Future<void> Function(WidgetTester) body) {
  testWidgets(description, (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await body(tester);
    } finally {
      // Flutter checks semantics handles before package:test tearDown runs.
      semantics.dispose();
    }
  });
}

void main() {
  test('immutable snapshot rejects mutation and empty steps', () {
    final steps = [
      const VisualPracticeStep(
        label: GuitarText('One', 'Bir'),
        instruction: GuitarText('Read', 'Oku'),
      ),
    ];
    final loop = _loop(steps);
    steps.clear();
    expect(loop.steps.length, 1);
    expect(() => loop.steps.clear(), throwsUnsupportedError);
    expect(() => loop.steps[0] = loop.steps[0], throwsUnsupportedError);
    expect(() => _loop([]), throwsArgumentError);
  });

  for (final locale in ['en', 'tr']) {
    _widgetTest(
      '$locale active instructions grid and release match original bar',
      (tester) async {
        _narrow(tester);
        await tester.pumpWidget(_app(PianoVisualPracticeScreen(), locale));
        await tester.pumpAndSettle();
        await _count(tester, locale, 1);
        expect(
          _active(tester),
          startsWith(
            locale == 'tr'
                ? 'Sayım 1’de sol Do3 ve sağ Do4’ü birlikte başlat.'
                : 'Start left C3 and right C4 together on count 1.',
          ),
        );
        for (var count = 2; count <= 4; count++) {
          await _tap(tester, 'visual-next-step');
          await _count(tester, locale, count);
          expect(
            _active(tester),
            contains(
              locale == 'tr'
                  ? 'Sol: Do3 tutmayı sürdür; yeniden basma.'
                  : 'Left: continue holding C3; do not strike again.',
            ),
          );
          final pitches = locale == 'tr'
              ? ['Re4', 'Mi4', 'Sol4']
              : ['D4', 'E4', 'G4'];
          expect(_active(tester), contains(pitches[count - 2]));
        }
        await _tap(tester, 'visual-next-step');
        final heading = find.byKey(const Key('visual-active-heading'));
        await _show(tester, heading);
        expect(
          tester.getSemantics(heading).label,
          contains(
            locale == 'tr'
                ? 'Sayım 4’ten sonra · bırak'
                : 'After count 4 · release',
          ),
        );
        expect(
          _active(tester),
          contains(
            locale == 'tr'
                ? 'ek beşinci vuruş değildir'
                : 'not an extra fifth beat',
          ),
        );
        for (var count = 1; count <= 4; count++) {
          expect(
            tester
                .widget<Semantics>(find.byKey(Key('piano-visual-count-$count')))
                .properties
                .selected,
            isFalse,
          );
        }
        expect(find.byKey(const Key('visual-next-step')), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    _widgetTest(
      '$locale same task parent/locale rebuild and same hand keep state',
      (tester) async {
        _narrow(tester);
        await tester.pumpWidget(
          _app(
            PianoVisualPracticeScreen(key: const ValueKey('stable-screen')),
            locale,
          ),
        );
        await tester.pumpAndSettle();
        await _tap(tester, 'visual-next-step');
        await _tap(tester, 'visual-observation-uncertain');
        final note = find.byKey(const Key('visual-observation-location'));
        await _show(tester, note);
        await tester.enterText(note, 'bar 1 count 2: uncertain');
        FocusManager.instance.primaryFocus?.unfocus();
        tester.testTextInput.hide();
        await tester.pumpAndSettle();
        await tester.pumpWidget(
          _app(
            PianoVisualPracticeScreen(key: const ValueKey('stable-screen')),
            locale,
          ),
        );
        await tester.pumpAndSettle();
        expect(_note(tester), 'bar 1 count 2: uncertain');
        expect(
          tester
              .widget<ChoiceChip>(
                find.byKey(const Key('visual-observation-uncertain')),
              )
              .selected,
          isTrue,
        );
        await _tap(tester, 'piano-visual-both');
        expect(_note(tester), 'bar 1 count 2: uncertain');
        await _count(tester, locale, 2);
        final other = locale == 'tr' ? 'en' : 'tr';
        await tester.pumpWidget(
          _app(
            PianoVisualPracticeScreen(key: const ValueKey('stable-screen')),
            other,
          ),
        );
        await tester.pumpAndSettle();
        expect(_note(tester), 'bar 1 count 2: uncertain');
        await _count(tester, other, 2);
        expect(tester.takeException(), isNull);
      },
    );

    _widgetTest('$locale scope changes reset note and all three hands render', (
      tester,
    ) async {
      _narrow(tester);
      await tester.pumpWidget(_app(PianoVisualPracticeScreen(), locale));
      await tester.pumpAndSettle();
      for (final mode in ['right', 'left', 'both']) {
        await _tap(tester, 'visual-next-step');
        await _tap(tester, 'visual-observation-issue');
        final note = find.byKey(const Key('visual-observation-location'));
        await _show(tester, note);
        await tester.enterText(note, 'count 2');
        FocusManager.instance.primaryFocus?.unfocus();
        tester.testTextInput.hide();
        await tester.pumpAndSettle();
        await _tap(tester, 'piano-visual-$mode');
        expect(_note(tester), isEmpty);
        expect(
          tester
              .widget<ChoiceChip>(
                find.byKey(const Key('visual-observation-issue')),
              )
              .selected,
          isFalse,
        );
        expect(find.byKey(const Key('visual-previous-step')), findsNothing);
        if (mode == 'right') {
          expect(
            _active(tester),
            contains(
              locale == 'tr' ? 'Sol: çalma; dinlen.' : 'Left: stay at rest.',
            ),
          );
        }
        if (mode == 'left') {
          expect(
            _active(tester),
            contains(
              locale == 'tr' ? 'Sağ: çalma; dinlen.' : 'Right: stay at rest.',
            ),
          );
        }
        if (mode == 'both') {
          expect(
            _active(tester),
            contains(
              locale == 'tr' ? 'birlikte başlat' : 'together on count 1',
            ),
          );
        }
      }
      await _tap(tester, 'visual-observation-noIssueObserved');
      await _tap(tester, 'visual-comparison-uncertain');
      await _tap(tester, 'visual-restart');
      expect(_note(tester), isEmpty);
      expect(
        tester
            .widget<ChoiceChip>(
              find.byKey(const Key('visual-observation-noIssueObserved')),
            )
            .selected,
        isFalse,
      );
      expect(
        find.byKey(const Key('visual-comparison-uncertain')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    _widgetTest(
      '$locale keyboard at2x and concrete same-count correction accessible',
      (tester) async {
        _narrow(tester);
        await tester.pumpWidget(_app(PianoVisualPracticeScreen(), locale));
        await tester.pumpAndSettle();
        final note = find.byKey(const Key('visual-observation-location'));
        await _show(tester, note);
        await tester.enterText(note, 'bar 1 count 2');
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pumpAndSettle();
        await _tap(tester, 'visual-observation-uncertain');
        final recovery = find.byKey(const Key('visual-recovery'));
        await _show(tester, recovery);
        expect(
          tester.widget<Text>(recovery).data,
          contains(
            locale == 'tr'
                ? 'sağın ritmini söylerken sol Do3’ü dört sayım tut'
                : 'hold left C3 through four counts while speaking the right-hand rhythm',
          ),
        );
        await _tap(tester, 'visual-comparison-same');
        expect(
          tester
              .widget<ChoiceChip>(
                find.byKey(const Key('visual-comparison-same')),
              )
              .selected,
          isTrue,
        );
        expect(_note(tester), 'bar 1 count 2');
        expect(tester.takeException(), isNull);
      },
    );

    _widgetTest(
      '$locale verified lesson15 entry Back and reopen discards note',
      (tester) async {
        _narrow(tester);
        await tester.pumpWidget(
          _app(PianoBeginnerScreen(bundle: _Files()), locale),
        );
        await tester.pumpAndSettle();
        await _tap(tester, 'piano-15');
        await _tap(tester, 'piano-visual-practice-entry');
        await _tap(tester, 'visual-next-step');
        final note = find.byKey(const Key('visual-observation-location'));
        await _show(tester, note);
        await tester.enterText(note, 'count 2');
        FocusManager.instance.primaryFocus?.unfocus();
        tester.testTextInput.hide();
        await tester.pumpAndSettle();
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('piano-visual-practice-entry')),
          findsOneWidget,
        );
        await _tap(tester, 'piano-visual-practice-entry');
        expect(_note(tester), isEmpty);
        expect(find.byKey(const Key('visual-previous-step')), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    _widgetTest('$locale corrupt content cannot expose lesson or pilot entry', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(PianoBeginnerScreen(bundle: _Files(corrupt: true)), locale),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          locale == 'tr'
              ? 'Yazılı kurs açılamadı.'
              : 'Written course unavailable.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('piano-15')), findsNothing);
      expect(
        find.byKey(const Key('piano-visual-practice-entry')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
