// OST-UX-05g2 (W) — secilen Hayalet basamagi PRATIK EKRANINDAKI nota / tab /
// vurus gorunurlugune uygulanir (04-design Ek B, 5.6; ghost_policy.dart).
// Matris (nota+tab ayni seritte cizilir; vurus = MetronomeBeatView):
//   ogrenme    : serit VAR, vurus VAR
//   pekistirme : serit VAR, vurus VAR
//   hatirlama  : serit YOK, vurus VAR
//   bagimsiz   : serit YOK, vurus YOK
// Bayrak KAPALI (ghostLevel null / sahne ghostOpen:false): ekran main ile ayni.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/audio/audio_input_controller.dart';
import 'package:ostinato/app/curriculum/v1_lesson.dart';
import 'package:ostinato/app/practice/loop/metronome_beat_view.dart';
import 'package:ostinato/app/practice/loop/practice_loop_screen.dart';
import 'package:ostinato/app/practice/loop/practice_tab_strip.dart';
import 'package:ostinato/app/practice/loop/v1_course_catalog.dart';
import 'package:ostinato/app/practice/loop/v1_practice_catalog.dart';
import 'package:ostinato/app/stage/ghost_policy.dart';
import 'package:ostinato/app/stage/ghost_store.dart';

import 'support/practice_host.dart';
import 'support/ux_05g_rig.dart';

// LITERAL beklenen matris (politikadan turetilmez).
const _stripShown = <GhostLevel, bool>{
  GhostLevel.learn: true,
  GhostLevel.reinforce: true,
  GhostLevel.recall: false,
  GhostLevel.independent: false,
};
const _beatShown = <GhostLevel, bool>{
  GhostLevel.learn: true,
  GhostLevel.reinforce: true,
  GhostLevel.recall: true,
  GhostLevel.independent: false,
};

/// Depo okumasi elle tamamlanan sahte depo (yukleme-oncesi penceresi).
final class _SlowStore implements GhostStore {
  _SlowStore(this.stored);
  final GhostState stored;
  final Completer<GhostState> gate = Completer<GhostState>();
  @override
  Future<GhostState> load() => gate.future;
  @override
  Future<void> save(GhostState state) async {}
}

PracticeLoopScreen _practice(WidgetTester t) =>
    t.widget<PracticeLoopScreen>(find.byType(PracticeLoopScreen));

V1Lesson _pitched() => V1Lesson.fromJson(
  jsonDecode(File('content/v1/gtr/gtr-s1-m02-02.json').readAsStringSync()),
);

V1Lesson _rhythmOnly() {
  final files =
      Directory('content/v1/gtr').listSync().whereType<File>().toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  for (final f in files) {
    if (!f.path.endsWith('.json')) continue;
    final l = V1Lesson.fromJson(jsonDecode(f.readAsStringSync()));
    if (V1PracticeCatalog.scoreOf(l, seed: 1)?.isRhythmOnly ?? false) return l;
  }
  throw StateError('no rhythm-only lesson in content/v1/gtr');
}

Future<Rig05f> _screen(
  WidgetTester t, {
  GhostLevel? level,
  V1Lesson? lesson,
}) async {
  final rig = Rig05f();
  await boot05f(
    t,
    practiceHost(
      PracticeLoopScreen(
        lesson: lesson ?? _pitched(),
        progress: Mem05f(),
        seed: 1,
        ghostLevel: level,
        controllerFactory: rig.factory,
      ),
    ),
    size: const Size(420, 2400),
  );
  return rig;
}

Finder get _strip => find.byType(PracticeTabStrip);
Finder get _beat => find.byType(MetronomeBeatView);

Future<void> _run(WidgetTester t, Rig05f rig, {bool preview = false}) async {
  await play05f(t);
  // 05g3: Hatirlama'da Baslat'tan sonra 3 sn on izleme, sonra kosu.
  if (preview) await t.pump(const Duration(seconds: 3));
  await listen05f(t, rig);
  expect(rig.controller!.timeline, isNotNull, reason: 'run is really on');
}

void main() {
  late final catalog = catalog05f();
  setUp(resetAudioCaptureCoordinatorForTest);

  group('05g2 pratik ekrani: basamak x gorunurluk', () {
    for (final level in GhostLevel.values) {
      testWidgets('${level.name}: bosta nota/tab seridi', (t) async {
        final rig = await _screen(t, level: level);
        expect(
          _strip,
          _stripShown[level]! ? findsOneWidget : findsNothing,
          reason: level.name,
        );
        // Gizli seritte yer tutucu var (yerlesim sicramaz), baslat erisilir.
        expect(
          find.byKey(const Key('ghost-step-line-hidden')),
          _stripShown[level]! ? findsNothing : findsOneWidget,
        );
        expect(find.byKey(const Key('practice-start')), findsOneWidget);
        await dispose05f(t, rig);
      });

      testWidgets('${level.name}: calarken vurus gostergesi', (t) async {
        final rig = await _screen(t, level: level);
        await _run(t, rig, preview: level == GhostLevel.recall);
        expect(
          _beat,
          _beatShown[level]! ? findsOneWidget : findsNothing,
          reason: level.name,
        );
        expect(
          _strip,
          _stripShown[level]! ? findsOneWidget : findsNothing,
          reason: level.name,
        );
        await dispose05f(t, rig);
      });
    }

    testWidgets('bayrak KAPALI (ghostLevel null): serit ve vurus hep var', (
      t,
    ) async {
      final rig = await _screen(t);
      expect(_strip, findsOneWidget);
      expect(find.byKey(const Key('ghost-step-line-hidden')), findsNothing);
      expect(find.byKey(const Key('ghost-line-hidden')), findsNothing);
      await _run(t, rig);
      expect(_beat, findsOneWidget);
      expect(_strip, findsOneWidget);
      await dispose05f(t, rig);
    });

    testWidgets('ritim-only ders: basamak ne olursa olsun serit durur', (
      t,
    ) async {
      final rig = await _screen(
        t,
        level: GhostLevel.independent,
        lesson: _rhythmOnly(),
      );
      expect(_strip, findsOneWidget);
      await dispose05f(t, rig);
    });
  });

  group('05g2 sahne: depodaki basamak pratik ekranina yansir', () {
    Future<Rig05f> stage(
      WidgetTester t,
      GhostLevel level, {
      required bool ghost,
    }) async {
      final rig = Rig05f();
      await boot05f(
        t,
        stage05g(
          rig,
          catalog,
          ghost: ghost,
          ghostStore: MemoryGhostStore(GhostState(level: level)),
        ),
      );
      // depo okumasi bitsin
      for (var i = 0; i < 4; i++) {
        await t.pump();
      }
      return rig;
    }

    for (final level in GhostLevel.values) {
      testWidgets('bayrak ACIK + ${level.name}: sahnede serit/vurus', (
        t,
      ) async {
        final rig = await stage(t, level, ghost: true);
        expect(
          _strip,
          _stripShown[level]! ? findsOneWidget : findsNothing,
          reason: level.name,
        );
        await _run(t, rig, preview: level == GhostLevel.recall);
        expect(
          _beat,
          _beatShown[level]! ? findsOneWidget : findsNothing,
          reason: level.name,
        );
        await dispose05f(t, rig);
      });
    }

    testWidgets('bayrak KAPALI: depoda bagimsiz olsa da ekran main ile ayni', (
      t,
    ) async {
      final rig = await stage(t, GhostLevel.independent, ghost: false);
      expect(_strip, findsOneWidget);
      expect(find.byKey(const Key('ghost-step-line-hidden')), findsNothing);
      await _run(t, rig);
      expect(_beat, findsOneWidget);
      await dispose05f(t, rig);
    });

    testWidgets(
      'elle secim: Yardim yuzeyinden Bagimsiz secilince serit gider',
      (t) async {
        final rig = Rig05f();
        await boot05f(
          t,
          stage05g(rig, catalog, ghost: true, ghostStore: MemoryGhostStore()),
        );
        for (var i = 0; i < 4; i++) {
          await t.pump();
        }
        expect(_strip, findsOneWidget);
        await t.tap(find.byKey(const Key('stage-shelf-toggle')));
        await t.pump();
        await t.pump();
        await t.ensureVisible(find.byKey(const Key('stage-help-row')));
        await t.pump();
        await t.tap(find.byKey(const Key('stage-help-row')));
        await t.pump();
        await t.pump();
        await t.ensureVisible(find.byKey(const Key('ghost-level-independent')));
        await t.tap(find.byKey(const Key('ghost-level-independent')));
        await t.pump();
        await t.pump();
        expect(_strip, findsNothing);
        await t.tap(find.byKey(const Key('ghost-level-learn')));
        await t.pump();
        await t.pump();
        expect(_strip, findsOneWidget);
        await dispose05f(t, rig);
      },
    );

    testWidgets('depo yuklenene kadar ghostLevel null; sonra Bagimsiz gizler', (
      t,
    ) async {
      final store = _SlowStore(const GhostState(level: GhostLevel.independent));
      final rig = Rig05f();
      await boot05f(t, stage05g(rig, catalog, ghost: true, ghostStore: store));
      for (var i = 0; i < 4; i++) {
        await t.pump();
      }
      // yukleme bitmedi: main davranisi (null), serit gorunur
      expect(_practice(t).ghostLevel, isNull);
      expect(_strip, findsOneWidget);
      store.gate.complete(store.stored);
      for (var i = 0; i < 4; i++) {
        await t.pump();
      }
      expect(_practice(t).ghostLevel, GhostLevel.independent);
      expect(_strip, findsNothing);
      await dispose05f(t, rig);
    });

    testWidgets('ritim-only ders sahnede: bagimsiz depoda bile serit durur', (
      t,
    ) async {
      final only = V1CourseCatalog([_rhythmOnly()]);
      final rig = Rig05f();
      await boot05f(
        t,
        stage05g(
          rig,
          only,
          ghost: true,
          ghostStore: MemoryGhostStore(
            const GhostState(level: GhostLevel.independent),
          ),
        ),
      );
      for (var i = 0; i < 4; i++) {
        await t.pump();
      }
      expect(find.byKey(const Key('practice-start')), findsOneWidget);
      expect(_strip, findsOneWidget);
      await dispose05f(t, rig);
    });
  });
}
