// OST-UX-04 — the interactive "one stage" prototype (behind a closed flag):
// flag default and absence of any entry while closed, the seven core
// journeys, glass rules, honest states, no camera/audio/storage.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/app_locale.dart';
import 'package:ostinato/app/app_message_ids.dart';
import 'package:ostinato/app/app_theme.dart';
import 'package:ostinato/app/content.dart';
import 'package:ostinato/app/cue_text.dart';
import 'package:ostinato/app/curriculum/v1_lesson.dart';
import 'package:ostinato/app/design/app_scope.dart';
import 'package:ostinato/app/ostinato_release_policy.dart';
import 'package:ostinato/app/practice/loop/practice_marks.dart';
import 'package:ostinato/app/practice/loop/v1_course_catalog.dart';
import 'package:ostinato/app/screens/settings_screen.dart';
import 'package:ostinato/app/ui_copy.dart';
import 'package:ostinato/app/ux_prototype/ux_glass_layer.dart';
import 'package:ostinato/app/ux_prototype/ux_prototype_copy.dart';
import 'package:ostinato/app/ux_prototype/ux_prototype_model.dart';
import 'package:ostinato/app/ux_prototype/ux_prototype_screen.dart';

import 'support/localized_widget_ready.dart';

const Duration _step = Duration(milliseconds: 50);

Widget _host(
  Widget home, {
  Brightness brightness = Brightness.light,
  bool highContrast = false,
  bool disableAnimations = false,
  double textScale = 1,
}) => MaterialApp(
  locale: const Locale('en'),
  supportedLocales: appSupportedLocales,
  localizationsDelegates: appLocalizationsDelegates,
  theme: OstinatoThemes.forBrightness(brightness),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      highContrast: highContrast,
      disableAnimations: disableAnimations,
      textScaler: TextScaler.linear(textScale),
    ),
    child: child!,
  ),
  home: home,
);

String _t(UiCopy c, [Map<String, Object?> v = const {}]) {
  var s = c.$1;
  v.forEach((k, value) => s = s.replaceAll('{$k}', '$value'));
  return s;
}

Finder _text(UiCopy c, [Map<String, Object?> v = const {}]) =>
    find.text(_t(c, v));

UxPrototypeScreen _screen({
  UxMic mic = UxMic.ready,
  bool seed = true,
  Future<V1CourseCatalog>? catalog,
}) => UxPrototypeScreen(
  initialMic: mic,
  seedHistory: seed,
  stepDuration: _step,
  catalog: catalog,
);

Future<void> _pump(WidgetTester t, Widget w) async {
  t.view.physicalSize = const Size(390, 844);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(w);
  await t.pumpAndSettle();
}

/// Plays a whole sample run (eight notes plus the finishing tick).
Future<void> _playToEnd(WidgetTester t) async {
  await t.tap(find.byKey(const Key('ux-play')));
  await t.pump();
  for (var i = 0; i < 12; i++) {
    await t.pump(_step);
  }
  await t.pumpAndSettle();
}

Future<void> _tapKey(WidgetTester t, String key) async {
  final f = find.byKey(Key(key));
  await t.ensureVisible(f);
  await t.tap(f);
  await t.pumpAndSettle();
}

double _lum(Color c) {
  double ch(double s) =>
      s <= 0.03928 ? s / 12.92 : math.pow((s + 0.055) / 1.055, 2.4) as double;
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

double _contrast(Color a, Color b) {
  final la = _lum(a), lb = _lum(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

final RegExp _verdict = RegExp(
  'wrong|yanlış|incorrect|fail',
  caseSensitive: false,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ContentRepository repo;
  late CueTextResolver cue;
  setUpAll(() async {
    await prepareRootTranslations();
    repo = await ContentRepository.load();
    cue = await CueTextResolver.load();
  });

  Widget settings({bool open = false}) => ContentRepositoryScope(
    repo: repo,
    cueText: cue,
    child: _host(SettingsScreen(uxPrototypeOpen: open)),
  );

  group('flag and entry', () {
    test('the prototype flag is closed by default', () {
      expect(ostinatoUxPrototypeOpen, isFalse);
    });

    testWidgets('closed flag: Settings has no entry to the prototype', (
      t,
    ) async {
      await _pump(t, settings());
      expect(find.byKey(const Key('ux-prototype-entry')), findsNothing);
      expect(find.text(_t(UxPrototypeCopy.entryLabel)), findsNothing);
      expect(find.byType(UxPrototypeScreen), findsNothing);
    });

    testWidgets('open flag: the single entry opens the prototype', (t) async {
      await _pump(t, settings(open: true));
      expect(find.byKey(const Key('ux-prototype-entry')), findsOneWidget);
      await t.tap(find.byKey(const Key('ux-prototype-entry')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(find.byType(UxPrototypeScreen), findsOneWidget);
      expect(find.byKey(const Key('ux-prototype-badge')), findsOneWidget);
    });

    test('nothing outside the prototype folder and Settings reaches it', () {
      final hits = <String>[];
      for (final f in Directory('lib').listSync(recursive: true)) {
        if (f is! File || !f.path.endsWith('.dart')) continue;
        if (f.path.contains('lib/app/ux_prototype/')) continue;
        if (f.readAsStringSync().contains('ux_prototype/')) hits.add(f.path);
      }
      expect(hits..sort(), <String>[
        'lib/app/ostinato_release_policy.dart', // the flag's doc comment
        'lib/app/screens/settings_screen.dart',
      ]);
    });

    test('the prototype never imports camera, audio, storage or network', () {
      for (final f in Directory('lib/app/ux_prototype').listSync()) {
        if (f is! File || !f.path.endsWith('.dart')) continue;
        final imports = f
            .readAsLinesSync()
            .where((l) => l.startsWith('import '))
            .join('\n');
        for (final banned in <String>[
          'camera',
          'audio',
          'permission_handler',
          'dart:io',
          'shared_preferences',
          'http',
          'supabase',
        ]) {
          expect(
            imports.contains(banned),
            isFalse,
            reason: '${f.path}: $banned',
          );
        }
      }
    });
  });

  group('copy', () {
    test('every prototype sentence has a message id', () {
      for (final c in UxPrototypeCopy.all) {
        expect(appMessageIds.containsKey(c), isTrue, reason: c.$1);
      }
    });

    test('no sentence says wrong', () {
      for (final c in UxPrototypeCopy.all) {
        expect(_verdict.hasMatch(c.$1), isFalse, reason: c.$1);
        expect(_verdict.hasMatch(c.$2), isFalse, reason: c.$2);
      }
    });
  });

  group('run classification', () {
    test('only a full, unlooped, heard run is measured', () {
      UxRunKind k({
        UxMic mic = UxMic.ready,
        bool finished = true,
        bool loop = false,
        bool wait = false,
        List<PracticeMark>? marks,
      }) => uxClassifyRun(
        mic: mic,
        finished: finished,
        loopUsed: loop,
        waitUsed: wait,
        marks: marks ?? uxReadyScript,
      );
      expect(k(), UxRunKind.measured);
      expect(k(finished: false), UxRunKind.unmeasuredPartial);
      expect(k(loop: true), UxRunKind.unmeasuredPartial);
      expect(k(wait: true), UxRunKind.unmeasuredPartial);
      expect(k(mic: UxMic.denied), UxRunKind.unmeasuredNotListened);
      expect(
        k(mic: UxMic.unclear, marks: uxScriptFor(UxMic.unclear)),
        UxRunKind.unreliable,
      );
      expect(uxHeardPercent(uxReadyScript), 88);
      expect(uxAccuracyPercent(uxReadyScript), 86);
      expect(uxAccuracyPercent(uxScriptFor(UxMic.unclear)), isNull);
    });
  });

  group('journey 1 - start practice', () {
    testWidgets('one tap on Play; no handle, layer or glass while playing', (
      t,
    ) async {
      await _pump(t, _host(_screen()));
      expect(find.byKey(const Key('ux-play')), findsOneWidget);
      expect(find.byKey(const Key('ux-handles')), findsOneWidget);
      await t.tap(find.byKey(const Key('ux-play')));
      await t.pump();
      await t.pump(_step);
      await t.pump(_step);
      expect(find.byKey(const Key('ux-stop')), findsOneWidget);
      expect(find.byKey(const Key('ux-handles')), findsNothing);
      expect(find.byType(UxGlassLayer), findsNothing);
      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.text(_t(UxPrototypeCopy.micListening)), findsOneWidget);
      for (var i = 0; i < 12; i++) {
        await t.pump(_step);
      }
      await t.pumpAndSettle();
      expect(find.byKey(const Key('ux-glass-layer')), findsOneWidget);
    });

    testWidgets('a layer cannot be opened while playing', (t) async {
      await _pump(t, _host(_screen()));
      await t.tap(find.byKey(const Key('ux-play')));
      await t.pump(_step);
      expect(find.byKey(const Key('ux-handle-path')), findsNothing);
      expect(find.byType(UxGlassLayer), findsNothing);
      await t.pumpAndSettle(const Duration(seconds: 1));
    });
  });

  group('journey 2 - practice without an instrument', () {
    testWidgets('two taps reach the ear mode; no microphone, not counted', (
      t,
    ) async {
      await _pump(t, _host(_screen()));
      await _tapKey(t, 'ux-handle-other');
      await _tapKey(t, 'ux-other-ear');
      expect(find.byKey(const Key('ux-ear-panel')), findsOneWidget);
      expect(_text(UxPrototypeCopy.earFormat), findsOneWidget);
      expect(find.byType(UxGlassLayer), findsNothing);
      await _tapKey(t, 'ux-ear-listen');
      expect(find.byKey(const Key('ux-ear-notes')), findsOneWidget);
      await _tapKey(t, 'ux-ear-lower');
      expect(find.byKey(const Key('ux-ear-reveal')), findsOneWidget);
      expect(find.byKey(const Key('ux-ear-not-counted')), findsOneWidget);
      expect(find.textContaining(_verdict), findsNothing);
      await _tapKey(t, 'ux-ear-back');
      await _tapKey(t, 'ux-handle-path');
      await _tapKey(t, 'ux-tab-history');
      expect(find.text(_t(UxPrototypeCopy.dayToday)), findsNothing);
    });
  });

  group('journey 3 - learning path', () {
    testWidgets('level, module list and the next module with its reason', (
      t,
    ) async {
      final lessons = <V1Lesson>[
        for (final f in Directory('content/v1/gtr').listSync())
          if (f is File && f.path.endsWith('.json'))
            V1Lesson.fromJson(
              jsonDecode(f.readAsStringSync()) as Map<String, dynamic>,
            ),
      ];
      final course = V1CourseCatalog(lessons);
      await _pump(t, _host(_screen(catalog: Future.value(course))));
      await _tapKey(t, 'ux-handle-path');
      expect(find.byKey(const Key('ux-path-list')), findsOneWidget);
      expect(_text(UxPrototypeCopy.levelLabel, {'v0': 1}), findsOneWidget);
      expect(find.byKey(const Key('ux-next-module')), findsOneWidget);
      expect(find.byKey(const Key('ux-next-why')), findsOneWidget);
      // Real catalog in: the sample-data note stays in the header only.
      expect(_text(UxPrototypeCopy.protoNote), findsOneWidget);
    });

    testWidgets('without a catalog the sample path is labelled prototype', (
      t,
    ) async {
      await _pump(t, _host(_screen()));
      await _tapKey(t, 'ux-handle-path');
      expect(find.byKey(const Key('ux-next-why')), findsOneWidget);
      expect(_text(UxPrototypeCopy.protoNote), findsNWidgets(2));
    });
  });

  group('journey 4 - understanding a mistake', () {
    testWidgets('different note, where, one correction, no verdict word', (
      t,
    ) async {
      await _pump(t, _host(_screen()));
      await _playToEnd(t);
      expect(find.byKey(const Key('ux-result-where')), findsOneWidget);
      expect(find.byKey(const Key('ux-result-correction')), findsOneWidget);
      expect(find.byKey(const Key('ux-result-could-not')), findsOneWidget);
      expect(_text(UxPrototypeCopy.heardPct, {'v0': 88}), findsOneWidget);
      expect(_text(UxPrototypeCopy.accuracyLine, {'v0': 86}), findsOneWidget);
      expect(find.textContaining(_verdict), findsNothing);
      expect(_text(UxPrototypeCopy.markDifferent), findsWidgets);
    });

    testWidgets('an unreliable run says it could not hear, gives no percent', (
      t,
    ) async {
      await _pump(t, _host(_screen(mic: UxMic.unclear)));
      await _playToEnd(t);
      expect(find.byKey(const Key('ux-result-not-measured')), findsOneWidget);
      expect(_text(UxPrototypeCopy.unreliableBody), findsOneWidget);
      expect(find.byKey(const Key('ux-result-accuracy')), findsNothing);
      expect(find.byKey(const Key('ux-result-heard')), findsNothing);
      expect(find.textContaining(_verdict), findsNothing);
    });
  });

  group('journey 5 - repeat the same section', () {
    testWidgets('Try again returns to the same section, ready', (t) async {
      await _pump(t, _host(_screen()));
      await _playToEnd(t);
      await _tapKey(t, 'ux-try-again');
      expect(find.byType(UxGlassLayer), findsNothing);
      expect(_text(UxPrototypeCopy.sectionLine, {'v0': 2}), findsOneWidget);
      expect(find.byKey(const Key('ux-play')), findsOneWidget);
    });

    testWidgets('a looped run is not measured', (t) async {
      await _pump(t, _host(_screen()));
      await _playToEnd(t);
      await _tapKey(t, 'ux-loop-bar');
      expect(find.byKey(const Key('ux-loop-notice')), findsOneWidget);
      await _playToEnd(t);
      expect(find.byKey(const Key('ux-result-not-measured')), findsOneWidget);
      expect(_text(UxPrototypeCopy.unmeasuredBody), findsOneWidget);
    });

    testWidgets('stopping early is not measured', (t) async {
      await _pump(t, _host(_screen()));
      await t.tap(find.byKey(const Key('ux-play')));
      await t.pump();
      await t.pump(_step);
      await t.pump(_step);
      await t.tap(find.byKey(const Key('ux-stop')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('ux-result-not-measured')), findsOneWidget);
      expect(_text(UxPrototypeCopy.unmeasuredBody), findsOneWidget);
    });
  });

  group('journey 6 - progress history', () {
    testWidgets('runs side by side, heard percent on its own line', (t) async {
      await _pump(t, _host(_screen()));
      await _playToEnd(t);
      await _tapKey(t, 'ux-layer-close');
      await _tapKey(t, 'ux-handle-path');
      await _tapKey(t, 'ux-tab-history');
      expect(find.byKey(const Key('ux-history')), findsOneWidget);
      expect(_text(UxPrototypeCopy.dayToday), findsOneWidget);
      expect(_text(UxPrototypeCopy.dayYesterday), findsOneWidget);
      expect(_text(UxPrototypeCopy.heardPct, {'v0': 88}), findsNWidgets(2));
      expect(_text(UxPrototypeCopy.earListedApart), findsOneWidget);
    });

    testWidgets('empty history is a plain sentence, no pressure', (t) async {
      await _pump(t, _host(_screen(seed: false)));
      await _tapKey(t, 'ux-handle-path');
      await _tapKey(t, 'ux-tab-history');
      expect(find.byKey(const Key('ux-history-empty')), findsOneWidget);
    });

    testWidgets('an unmeasured run is listed as not measured', (t) async {
      await _pump(t, _host(_screen(seed: false)));
      await t.tap(find.byKey(const Key('ux-play')));
      await t.pump(_step);
      await t.tap(find.byKey(const Key('ux-stop')));
      await t.pumpAndSettle();
      await _tapKey(t, 'ux-layer-close');
      await _tapKey(t, 'ux-handle-path');
      await _tapKey(t, 'ux-tab-history');
      expect(_text(UxPrototypeCopy.notMeasured), findsOneWidget);
    });
  });

  group('journey 7 - microphone permission refused', () {
    testWidgets('listening-off mode: still playable, ear and setup reachable', (
      t,
    ) async {
      await _pump(t, _host(_screen(mic: UxMic.denied)));
      expect(find.byKey(const Key('ux-mic-off')), findsOneWidget);
      expect(_text(UxPrototypeCopy.micOff), findsOneWidget);
      expect(_text(UxPrototypeCopy.playSelf), findsOneWidget);
      await _tapKey(t, 'ux-go-setup');
      expect(find.byKey(const Key('ux-mic-ready')), findsOneWidget);
      await _tapKey(t, 'ux-layer-close');
      await _tapKey(t, 'ux-ear-first');
      expect(find.byKey(const Key('ux-ear-panel')), findsOneWidget);
    });

    testWidgets('a run with listening off is not measured and says so', (
      t,
    ) async {
      await _pump(t, _host(_screen(mic: UxMic.denied)));
      await _playToEnd(t);
      expect(find.byKey(const Key('ux-result-not-measured')), findsOneWidget);
      expect(_text(UxPrototypeCopy.selfCheckBody), findsOneWidget);
      expect(find.byKey(const Key('ux-result-accuracy')), findsNothing);
    });

    testWidgets('the setup layer switches the simulated microphone', (t) async {
      await _pump(t, _host(_screen()));
      await _tapKey(t, 'ux-handle-setup');
      await _tapKey(t, 'ux-mic-denied');
      await _tapKey(t, 'ux-layer-close');
      expect(find.byKey(const Key('ux-mic-off')), findsOneWidget);
    });
  });

  group('glass rules', () {
    test('constants stay inside the design budget', () {
      expect(UxGlassLayer.blurSigma, lessThanOrEqualTo(16));
      expect(UxGlassLayer.surfaceAlpha, greaterThanOrEqualTo(0.9));
    });

    testWidgets('at most two glass items; a second layer replaces the first', (
      t,
    ) async {
      await _pump(t, _host(_screen()));
      await _tapKey(t, 'ux-handle-other');
      expect(find.byType(UxGlassLayer), findsOneWidget);
      expect(find.byType(BackdropFilter), findsOneWidget);
      await _tapKey(t, 'ux-layer-close');
      await _tapKey(t, 'ux-handle-path');
      expect(find.byType(UxGlassLayer), findsOneWidget);
      expect(find.byType(UxGlassLayer).evaluate().length, lessThanOrEqualTo(2));
    });

    testWidgets('high contrast draws the layer opaque with no blur', (t) async {
      await _pump(t, _host(_screen(), highContrast: true));
      await _tapKey(t, 'ux-handle-path');
      expect(find.byKey(const Key('ux-glass-layer')), findsOneWidget);
      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('reduced motion shows the layer at once', (t) async {
      await _pump(t, _host(_screen(), disableAnimations: true));
      await t.tap(find.byKey(const Key('ux-handle-path')));
      await t.pump();
      final opacity = t.widget<Opacity>(
        find
            .descendant(
              of: find.byKey(const Key('ux-glass-layer')),
              matching: find.byType(Opacity),
            )
            .first,
      );
      expect(opacity.opacity, 1);
    });

    testWidgets('tapping the open strip above the layer closes it', (t) async {
      await _pump(t, _host(_screen()));
      await _tapKey(t, 'ux-handle-setup');
      await t.tapAt(const Offset(195, 40));
      await t.pumpAndSettle();
      expect(find.byType(UxGlassLayer), findsNothing);
    });

    for (final b in Brightness.values) {
      test(
        'body text on the layer keeps 4.5:1 over the worst backdrop ($b)',
        () {
          final theme = OstinatoThemes.forBrightness(b);
          final p = theme.extension<OstinatoPalette>()!;
          final layer = p.surface.withValues(alpha: UxGlassLayer.surfaceAlpha);
          for (final backdrop in <Color>[Colors.white, Colors.black]) {
            final composed = Color.alphaBlend(layer, backdrop);
            expect(_contrast(p.textBody, composed), greaterThanOrEqualTo(4.5));
            expect(_contrast(p.ink, composed), greaterThanOrEqualTo(4.5));
          }
        },
      );
    }
  });

  group('accessibility and layout', () {
    testWidgets('large text does not overflow the stage or a layer', (t) async {
      await _pump(t, _host(_screen(), textScale: 2));
      await _tapKey(t, 'ux-handle-path');
      await _tapKey(t, 'ux-tab-history');
      expect(t.takeException(), isNull);
    });

    testWidgets('marks carry a text label, not colour alone', (t) async {
      await _pump(t, _host(_screen()));
      final labelled = find.bySemanticsLabel(
        RegExp('correct.*different note.*could not hear'),
      );
      expect(labelled, findsWidgets);
    });

    testWidgets('dark theme builds the stage and a layer', (t) async {
      await _pump(t, _host(_screen(), brightness: Brightness.dark));
      await _tapKey(t, 'ux-handle-other');
      expect(find.byKey(const Key('ux-glass-layer')), findsOneWidget);
    });
  });
}
