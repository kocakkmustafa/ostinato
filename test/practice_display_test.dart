// FK4 (plan F2.7): left-handed TAB strip, colour-blind-safe palette and
// spoken mark states. The setting file, the mirroring geometry, the strip and
// result screen reacting to the setting, contrast in both themes and the
// screen-reader labels.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/app_theme.dart';
import 'package:ostinato/app/practice/display/practice_display_copy.dart';
import 'package:ostinato/app/practice/display/practice_display_preferences.dart';
import 'package:ostinato/app/practice/loop/practice_marks.dart';
import 'package:ostinato/app/practice/loop/practice_score.dart';
import 'package:ostinato/app/practice/loop/practice_tab_strip.dart';
import 'package:ostinato/app/practice/loop/practice_visual_theme.dart';
import 'package:ostinato/app/screens/settings_screen.dart';

import 'support/practice_host.dart';

final class _MemoryPreference implements PracticeDisplayPreference {
  _MemoryPreference([this.stored = const PracticeDisplaySettings()]);
  PracticeDisplaySettings stored;
  bool failWrites = false;
  final writes = <PracticeDisplaySettings>[];

  @override
  Future<PracticeDisplaySettings> read() async => stored;

  @override
  Future<void> write(PracticeDisplaySettings settings) async {
    if (failWrites) throw const FileSystemException('disk full');
    writes.add(settings);
    stored = settings;
  }
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + .05) / (lo + .05);
}

TabStripPainter _painter(WidgetTester tester) =>
    tester
            .widget<CustomPaint>(find.byKey(const Key('practice-tab-strip')))
            .painter!
        as TabStripPainter;

void main() {
  group('setting file (ostinato.practice_display.v1.json)', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('fk4-display-'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('missing file reads as both off', () async {
      final store = FilePracticeDisplayPreference(directory: dir);
      expect(await store.read(), const PracticeDisplaySettings());
      expect((await store.read()).leftHanded, isFalse);
      expect((await store.read()).colorBlindSafe, isFalse);
    });

    test(
      'round trip keeps both flags, schemaVersion 1, nothing else',
      () async {
        final store = FilePracticeDisplayPreference(directory: dir);
        for (final s in const [
          PracticeDisplaySettings(leftHanded: true),
          PracticeDisplaySettings(colorBlindSafe: true),
          PracticeDisplaySettings(leftHanded: true, colorBlindSafe: true),
          PracticeDisplaySettings(),
        ]) {
          await store.write(s);
          expect(await store.read(), s);
        }
        final file = File(
          '${dir.path}/${FilePracticeDisplayPreference.fileName}',
        );
        expect(jsonDecode(file.readAsStringSync()), {
          'schemaVersion': 1,
          'leftHanded': false,
          'colorBlindSafe': false,
        });
        expect(File('${file.path}.tmp').existsSync(), isFalse);
      },
    );

    test('corrupt, other schema or non-bool flags read as off', () async {
      final store = FilePracticeDisplayPreference(directory: dir);
      final file = File(
        '${dir.path}/${FilePracticeDisplayPreference.fileName}',
      );
      for (final raw in [
        '{not json',
        '[]',
        jsonEncode({
          'schemaVersion': 2,
          'leftHanded': true,
          'colorBlindSafe': true,
        }),
        jsonEncode({
          'schemaVersion': 1,
          'leftHanded': 'yes',
          'colorBlindSafe': 1,
        }),
      ]) {
        file.writeAsStringSync(raw);
        expect(
          await store.read(),
          const PracticeDisplaySettings(),
          reason: raw,
        );
      }
    });
  });

  group('PracticeDisplayController', () {
    test('defaults off, loads the stored value, writes each change', () async {
      final pref = _MemoryPreference(
        const PracticeDisplaySettings(colorBlindSafe: true),
      );
      final c = PracticeDisplayController(preference: pref);
      expect(c.settings, const PracticeDisplaySettings());
      await c.load();
      expect(c.loaded, isTrue);
      expect(c.settings.colorBlindSafe, isTrue);
      await c.setLeftHanded(true);
      expect(
        pref.stored,
        const PracticeDisplaySettings(leftHanded: true, colorBlindSafe: true),
      );
      await c.setColorBlindSafe(false);
      expect(pref.stored, const PracticeDisplaySettings(leftHanded: true));
      expect(c.settings.theme.leftHanded, isTrue);
      expect(c.settings.theme.colorBlindSafe, isFalse);
      c.dispose();
    });

    test('a failed write rolls back and says so', () async {
      final pref = _MemoryPreference()..failWrites = true;
      final c = PracticeDisplayController(preference: pref);
      await c.load();
      final f = c.setLeftHanded(true);
      expect(c.settings.leftHanded, isTrue, reason: 'shows at once');
      await f;
      expect(c.settings.leftHanded, isFalse);
      expect(c.saveFailed, isTrue);
      pref.failWrites = false;
      await c.setLeftHanded(true);
      expect(c.saveFailed, isFalse);
      expect(pref.stored.leftHanded, isTrue);
      c.dispose();
    });

    test('a change made before the read lands is not overwritten', () async {
      final pref = _MemoryPreference(
        const PracticeDisplaySettings(leftHanded: true),
      );
      final c = PracticeDisplayController(preference: pref);
      final changed = c.setColorBlindSafe(true);
      await c.load();
      await changed;
      expect(c.settings, const PracticeDisplaySettings(colorBlindSafe: true));
      c.dispose();
    });
  });

  group('StripGeometry (left-handed mirroring)', () {
    StripGeometry g(bool left, {double beat = 0}) => StripGeometry(
      width: 400,
      displayBeat: beat,
      pixelsPerBeat: 100,
      nowFraction: .25,
      leftHanded: left,
    );

    test('right-handed: NOW on the left, later notes to the right', () {
      expect(g(false).nowX, 100);
      expect(g(false).xOf(0), 100);
      expect(g(false).xOf(2), 300);
      expect(g(false).forward, 1);
    });

    test('left-handed is the exact mirror image', () {
      expect(g(true).nowX, 300);
      expect(g(true).xOf(2), 100);
      expect(g(true).forward, -1);
      for (final beat in [-1.0, 0.0, .5, 1.0, 3.25]) {
        for (final now in [0.0, 1.5]) {
          expect(
            g(true, beat: now).xOf(beat),
            closeTo(400 - g(false, beat: now).xOf(beat), 1e-9),
          );
        }
      }
    });

    test('time still runs towards the NOW line in both modes', () {
      for (final left in [false, true]) {
        final before = (g(left, beat: 0).xOf(2) - g(left, beat: 0).nowX).abs();
        final after = (g(left, beat: 1).xOf(2) - g(left, beat: 1).nowX).abs();
        expect(after, lessThan(before), reason: 'left=$left');
      }
    });
  });

  group('palette', () {
    test('every state keeps a distinct shape and symbol in every palette', () {
      for (final cb in [false, true]) {
        for (final dark in [false, true]) {
          final t = PracticeVisualTheme(colorBlindSafe: cb, dark: dark);
          final judged = [
            PracticeMark.correct,
            PracticeMark.differentNote,
            PracticeMark.couldNotHear,
          ].map(t.style).toList();
          expect(judged.map((s) => s.shape).toSet(), hasLength(3));
          expect(judged.map((s) => s.symbol).toSet(), {'✓', '◆', '?'});
          expect(judged.map((s) => s.color).toSet(), hasLength(3));
        }
      }
    });

    test('colour-blind palette is Okabe–Ito blue / orange', () {
      const light = PracticeVisualTheme(colorBlindSafe: true);
      const dark = PracticeVisualTheme(colorBlindSafe: true, dark: true);
      expect(dark.style(PracticeMark.correct).color, const Color(0xFF56B4E9));
      expect(
        dark.style(PracticeMark.differentNote).color,
        const Color(0xFFE69F00),
      );
      // Light paper: the same hues, darkened for contrast.
      final blue = HSVColor.fromColor(light.style(PracticeMark.correct).color);
      final orange = HSVColor.fromColor(
        light.style(PracticeMark.differentNote).color,
      );
      expect(blue.hue, inInclusiveRange(195, 215));
      expect(orange.hue, inInclusiveRange(25, 45));
    });

    test('marks keep ≥ 3:1 against paper and cards in light and dark', () {
      for (final (palette, dark) in [
        (OstinatoPalette.light, false),
        (OstinatoPalette.dark, true),
      ]) {
        for (final cb in [false, true]) {
          final t = PracticeVisualTheme(colorBlindSafe: cb, dark: dark);
          for (final m in PracticeMark.values) {
            for (final bg in [
              palette.notationPaper,
              palette.surface,
              palette.controlSurface,
            ]) {
              expect(
                _contrast(t.style(m).color, bg),
                greaterThanOrEqualTo(3),
                reason: 'dark=$dark cb=$cb $m on $bg',
              );
            }
          }
          // Fret numbers are written in paper colour inside filled marks.
          for (final m in [PracticeMark.correct, PracticeMark.differentNote]) {
            expect(
              _contrast(t.style(m).color, palette.notationPaper),
              greaterThanOrEqualTo(4),
              reason: 'label inside $m, dark=$dark cb=$cb',
            );
          }
        }
      }
    });
  });

  group('practice strip follows the setting', () {
    final score = PracticeScore.parse('E2 F2 G2 F2 E2');

    Widget strip(
      PracticeDisplayController c, {
      Map<int, StripMark> marks = const {},
      String locale = 'en',
    }) => practiceHost(
      locale: locale,
      PracticeDisplayHost(
        controller: c,
        child: Scaffold(
          body: SizedBox(
            height: 200,
            width: 400,
            child: PracticeTabStrip(score: score, displayBeat: 0, marks: marks),
          ),
        ),
      ),
    );

    testWidgets('left-handed toggle mirrors the strip at once', (tester) async {
      final c = PracticeDisplayController(preference: _MemoryPreference());
      await c.load();
      await tester.pumpWidget(strip(c));
      final width = tester
          .getSize(find.byKey(const Key('practice-tab-strip')))
          .width;
      var p = _painter(tester);
      expect(p.theme.leftHanded, isFalse);
      expect(p.geometry(width).nowX, lessThan(width / 2));
      expect(p.xOf(1, width), greaterThan(p.xOf(0, width)));

      await c.setLeftHanded(true);
      await tester.pump();
      p = _painter(tester);
      expect(p.theme.leftHanded, isTrue);
      expect(p.geometry(width).nowX, greaterThan(width / 2));
      expect(p.xOf(1, width), lessThan(p.xOf(0, width)));
      // String order is NOT flipped: string 1 stays on top.
      expect(
        p.yOfString(1, const Size(400, 200)),
        lessThan(p.yOfString(6, const Size(400, 200))),
      );
      expect(tester.takeException(), isNull);
      c.dispose();
    });

    testWidgets('colour-blind toggle switches the palette', (tester) async {
      final c = PracticeDisplayController(preference: _MemoryPreference());
      await c.load();
      await tester.pumpWidget(
        strip(c, marks: const {0: StripMark(PracticeMark.correct)}),
      );
      final before = _painter(tester).theme.style(PracticeMark.correct).color;
      await c.setColorBlindSafe(true);
      await tester.pump();
      final theme = _painter(tester).theme;
      expect(theme.colorBlindSafe, isTrue);
      expect(theme.style(PracticeMark.correct).color, isNot(before));
      expect(
        theme.style(PracticeMark.correct).color,
        const PracticeVisualTheme(
          colorBlindSafe: true,
        ).style(PracticeMark.correct).color,
      );
      c.dispose();
    });

    testWidgets('dark theme picks the dark tones', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: OstinatoThemes.dark,
          home: Scaffold(
            body: SizedBox(
              height: 200,
              child: PracticeTabStrip(score: score, displayBeat: 0),
            ),
          ),
        ),
      );
      expect(_painter(tester).theme.dark, isTrue);
    });

    testWidgets('the newest mark is announced as a state, never "wrong"', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final c = PracticeDisplayController(preference: _MemoryPreference());
      await c.load();
      await tester.pumpWidget(strip(c));
      expect(find.bySemanticsLabel(RegExp('^Last note')), findsNothing);

      for (final (mark, words) in [
        (PracticeMark.correct, 'Last note: Correct'),
        (PracticeMark.differentNote, 'Last note: Different note'),
        (PracticeMark.couldNotHear, "Last note: Couldn't hear"),
      ]) {
        await tester.pumpWidget(
          strip(
            c,
            marks: {
              0: const StripMark(PracticeMark.correct),
              1: StripMark(mark, observedMidi: 45),
            },
          ),
        );
        final node = tester.getSemantics(
          find.byKey(const Key('practice-tab-strip-last-mark')),
        );
        expect(node.label, words);
        expect(node.flagsCollection.isLiveRegion, isTrue);
        expect(node.label.toLowerCase(), isNot(contains('wrong')));
      }
      // The NOW label is still its own node.
      expect(find.bySemanticsLabel(RegExp(r'^Now: ')), findsOneWidget);

      await tester.pumpWidget(
        strip(
          c,
          locale: 'tr',
          marks: const {0: StripMark(PracticeMark.differentNote)},
        ),
      );
      expect(
        tester
            .getSemantics(find.byKey(const Key('practice-tab-strip-last-mark')))
            .label,
        'Son nota: Farklı nota',
      );
      handle.dispose();
      c.dispose();
    });

    test('lastMarkedEvent picks the newest judged note', () {
      expect(lastMarkedEvent(const {}), isNull);
      expect(
        lastMarkedEvent(const {
          0: StripMark(PracticeMark.correct),
          3: StripMark(PracticeMark.couldNotHear),
          2: StripMark(PracticeMark.differentNote),
        }),
        3,
      );
      expect(
        lastMarkedEvent(const {0: StripMark(PracticeMark.pending)}),
        isNull,
      );
    });
  });

  test('mark labels never say "wrong"', () {
    for (final (en, tr) in PracticeDisplayCopy.all) {
      expect(en.toLowerCase(), isNot(contains('wrong')));
      expect(tr.toLowerCase(), isNot(contains('yanlış')));
    }
    for (final m in PracticeMark.values) {
      expect(PracticeDisplayCopy.mark(m), isNotNull);
    }
  });

  group('settings card', () {
    testWidgets('both switches start off and persist when turned on', (
      tester,
    ) async {
      final pref = _MemoryPreference();
      final c = PracticeDisplayController(preference: pref);
      await c.load();
      await tester.pumpWidget(
        practiceHost(
          Scaffold(
            body: SingleChildScrollView(
              child: PracticeDisplaySettingCard(controller: c),
            ),
          ),
        ),
      );
      Switch sw(String key) => tester.widget<Switch>(find.byKey(Key(key)));
      expect(sw('settings-left-handed-switch').value, isFalse);
      expect(sw('settings-color-blind-switch').value, isFalse);
      expect(find.text(PracticeDisplayCopy.leftHandedTitle.$1.toUpperCase()), findsOneWidget);

      await tester.tap(find.byKey(const Key('settings-left-handed-switch')));
      await tester.pumpAndSettle();
      expect(sw('settings-left-handed-switch').value, isTrue);
      expect(pref.stored.leftHanded, isTrue);

      await tester.tap(find.byKey(const Key('settings-color-blind-switch')));
      await tester.pumpAndSettle();
      expect(
        pref.stored,
        const PracticeDisplaySettings(leftHanded: true, colorBlindSafe: true),
      );
      expect(
        find.byKey(const Key('settings-practice-display-save-failed')),
        findsNothing,
      );
      c.dispose();
    });

    testWidgets('a failed save flips back and shows the note', (tester) async {
      final pref = _MemoryPreference()..failWrites = true;
      final c = PracticeDisplayController(preference: pref);
      await c.load();
      await tester.pumpWidget(
        practiceHost(
          locale: 'tr',
          Scaffold(body: PracticeDisplaySettingCard(controller: c)),
        ),
      );
      expect(find.text('SOLAK'), findsOneWidget);
      await tester.tap(find.byKey(const Key('settings-color-blind-switch')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Switch>(
              find.byKey(const Key('settings-color-blind-switch')),
            )
            .value,
        isFalse,
      );
      expect(
        find.byKey(const Key('settings-practice-display-save-failed')),
        findsOneWidget,
      );
      c.dispose();
    });
  });
}
