// OST-UX-05g3 (W) — Hayalet yardim rafi <-> pratik ekrani uyumu.
// Kural: raf neyi vaat ediyorsa pratik ekrani onu yapar; rafta olmayan sey
// ekranda yok. Beklenen matris LITERAL (politikadan turetilmez).
//   ogrenme    {notation, tab, beat, label}
//   pekistirme {notation, tab, beat}
//   hatirlama  {preStartPreview, beat}
//   bagimsiz   {} -> raf yalniz `ghost-item-none`
// Bayrak `ostinatoGhostScreenOpen` kapaliyken (ghostLevel null) ekran main ile
// ayni.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/account_connection.dart';
import 'package:ostinato/app/app_translation_catalog.dart';
import 'package:ostinato/app/audio/audio_input_controller.dart';
import 'package:ostinato/app/design/ostinato_theme.dart';
import 'package:ostinato/app/curriculum/v1_lesson.dart';
import 'package:ostinato/app/practice/loop/practice_loop_screen.dart';
import 'package:ostinato/app/practice/loop/practice_score.dart';
import 'package:ostinato/app/practice/loop/practice_session_controller.dart';
import 'package:ostinato/app/practice/loop/practice_tab_strip.dart';
import 'package:ostinato/app/practice/loop/v1_practice_catalog.dart';
import 'package:ostinato/app/stage/ghost_policy.dart';
import 'package:ostinato/app/stage/ghost_store.dart';

import 'support/practice_host.dart';
import 'support/ux_05g_rig.dart';

const _previewTr = 'Başlamadan 3 sn nota';
const _previewEn = 'Notation for 3 seconds before you start';

// LITERAL raf matrisi.
const _shelfExpected = <GhostLevel, Set<String>>{
  GhostLevel.learn: {'notation', 'tab', 'beat', 'label'},
  GhostLevel.reinforce: {'notation', 'tab', 'beat'},
  GhostLevel.recall: {'preStartPreview', 'beat'},
  GhostLevel.independent: {'none'},
};
const _allShelfKeys = <String>[
  'notation',
  'tab',
  'beat',
  'label',
  'preStartPreview',
  'none',
  'metronome',
  'hint',
];
// LITERAL: etiket yalniz Ogrenme'de.
const _labelsShown = <GhostLevel, bool>{
  GhostLevel.learn: true,
  GhostLevel.reinforce: false,
  GhostLevel.recall: false,
  GhostLevel.independent: false,
};

/// drawParagraph cagrilarini sayan sahte tuval.
final class _RecCanvas implements ui.Canvas {
  int paragraphs = 0;
  final List<Rect> boxes = <Rect>[];
  @override
  dynamic noSuchMethod(Invocation i) {
    if (i.memberName == #drawParagraph) {
      paragraphs++;
      final para = i.positionalArguments[0] as ui.Paragraph;
      final o = i.positionalArguments[1] as Offset;
      boxes.add(Rect.fromLTWH(o.dx, o.dy, para.width, para.height));
    }
    return null;
  }
}

int _paragraphsOf(TabStripPainter p) {
  final c = _RecCanvas();
  p.paint(c, const Size(420, 190));
  return c.paragraphs;
}

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

/// Katalogdan (assets/l10n) senkron yukleyen yerellestirme (test).
final class _CatalogDelegate extends LocalizationsDelegate<AppTranslations> {
  const _CatalogDelegate(this.tag);
  final String tag;
  @override
  bool isSupported(Locale locale) => true;
  @override
  Future<AppTranslations> load(Locale locale) => SynchronousFuture(
    AppTranslations.fromJson(
      locale,
      jsonDecode(File('assets/l10n/$tag.json').readAsStringSync()),
    ),
  );
  @override
  bool shouldReload(_CatalogDelegate old) => old.tag != tag;
}

final class _Started {
  int n = 0;
}

Future<Rig05f> _screen(
  WidgetTester t,
  _Started started, {
  GhostLevel? level,
  V1Lesson? lesson,
  String locale = 'tr',
  Future<bool> Function()? beforeStart,
}) async {
  final rig = Rig05f();
  await boot05f(
    t,
    practiceHost(
      locale: locale,
      PracticeLoopScreen(
        lesson: lesson ?? _pitched(),
        progress: Mem05f(),
        seed: 1,
        ghostLevel: level,
        controllerFactory: rig.factory,
        onStarted: () => started.n++,
        beforeStart: beforeStart,
      ),
    ),
    size: const Size(420, 2400),
  );
  return rig;
}

Finder get _strip => find.byType(PracticeTabStrip);
Finder get _stripPaint => find.byKey(const Key('practice-tab-strip'));
Finder get _hidden => find.byKey(const Key('ghost-step-line-hidden'));
Finder get _previewText => find.text(_previewTr);

TabStripPainter _painter(WidgetTester t) =>
    t.widget<CustomPaint>(_stripPaint).painter! as TabStripPainter;

Future<void> _tapStart(WidgetTester t) async {
  await t.tap(find.byKey(const Key('practice-start')));
  await t.pump();
  await t.pump();
}

Future<void> _openHelp(WidgetTester t) async {
  await t.tap(find.byKey(const Key('stage-shelf-toggle')));
  await t.pump();
  await t.pump();
  await t.ensureVisible(find.byKey(const Key('stage-help-row')));
  await t.pump();
  await t.tap(find.byKey(const Key('stage-help-row')));
  await t.pump();
  await t.pump();
}

Future<void> _pickLevel(WidgetTester t, GhostLevel l) async {
  final k = find.byKey(Key('ghost-level-${l.name}'));
  await t.ensureVisible(k);
  await t.tap(k);
  await t.pump();
  await t.pump();
}

Finder _shelfItem(String k) => find.byKey(Key('ghost-item-$k'));

void main() {
  late final catalog = catalog05f();
  setUp(resetAudioCaptureCoordinatorForTest);

  group('a) raf matrisi (literal)', () {
    for (final locale in ['tr', 'en']) {
      testWidgets('$locale: her basamakta ogeler + metin taramasi', (t) async {
        final rig = Rig05f();
        await boot05f(
          t,
          stage05g(
            rig,
            catalog,
            locale: locale,
            ghostStore: MemoryGhostStore(),
          ),
        );
        for (var i = 0; i < 4; i++) {
          await t.pump();
        }
        await _openHelp(t);
        for (final level in GhostLevel.values) {
          await _pickLevel(t, level);
          final want = _shelfExpected[level]!;
          // Once var olanlar (kardes), sonra olmayanlar.
          for (final k in _allShelfKeys.where(want.contains)) {
            expect(_shelfItem(k), findsOneWidget, reason: '${level.name}/$k');
          }
          for (final k in _allShelfKeys.where((k) => !want.contains(k))) {
            expect(_shelfItem(k), findsNothing, reason: '${level.name}/$k');
          }
          for (final s in [
            'Metronom',
            'İpucu',
            'Metronome (optional)',
            'Metronome',
            'Hint',
          ]) {
            expect(
              find.descendant(
                of: find.byKey(const Key('ghost-help-surface')),
                matching: find.textContaining(s),
              ),
              findsNothing,
              reason: '${level.name}: raf metni "$s"',
            );
          }
        }
        await dispose05f(t, rig);
      });
    }
  });

  group('b) etiket <-> ekran', () {
    for (final level in GhostLevel.values) {
      testWidgets('${level.name}: painter showNoteNames', (t) async {
        final rig = await _screen(t, _Started(), level: level);
        if (_labelsShown[level]!) {
          expect(_painter(t).showNoteNames, isTrue, reason: level.name);
        } else if (level == GhostLevel.reinforce) {
          expect(_painter(t).showNoteNames, isFalse);
        } else {
          // serit gizli: painter yok, ama gizli yer tutucu var
          expect(_strip, findsNothing);
          expect(_hidden, findsOneWidget);
        }
        await dispose05f(t, rig);
      });
    }

    testWidgets('ghostLevel null: showNoteNames false', (t) async {
      final rig = await _screen(t, _Started());
      expect(_strip, findsOneWidget);
      expect(_painter(t).showNoteNames, isFalse);
      await dispose05f(t, rig);
    });

    testWidgets('gercek render: etiket paragraf sayisini artirir', (t) async {
      final rig = await _screen(t, _Started(), level: GhostLevel.learn);
      final p = _painter(t);
      TabStripPainter with_(bool names) => TabStripPainter(
        score: p.score,
        displayBeat: 0, // ilk notalar penceredeki NOW cizgisinde
        marks: p.marks,
        heldEvent: p.heldEvent,
        loop: p.loop,
        pixelsPerBeat: p.pixelsPerBeat,
        nowFraction: p.nowFraction,
        guitar: p.guitar,
        showNoteNames: names,
        theme: p.theme,
        ink: p.ink,
        paper: p.paper,
        muted: p.muted,
        now: p.now,
      );
      final on = _paragraphsOf(with_(true));
      final off = _paragraphsOf(with_(false));
      expect(
        off,
        greaterThan(0),
        reason: 'serit zaten yazi cizer (tab sayilari)',
      );
      expect(on, greaterThan(off));
      await dispose05f(t, rig);
    });
  });

  group('c) on izleme <-> ekran (Hatirlama)', () {
    testWidgets('bosta gizli; Baslat -> 3 sn serit + metin; sonra kosu', (
      t,
    ) async {
      final sem = t.ensureSemantics();
      final started = _Started();
      final rig = await _screen(t, started, level: GhostLevel.recall);
      expect(_hidden, findsOneWidget);
      expect(_strip, findsNothing);
      expect(_previewText, findsNothing);

      await _tapStart(t);
      await t.pump(const Duration(milliseconds: 500));
      expect(_strip, findsOneWidget, reason: 'on izlemede serit gorunur');
      expect(_hidden, findsNothing);
      expect(_previewText, findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.liveRegion == true &&
              w.properties.label == _previewTr,
        ),
        findsOneWidget,
        reason: 'canli bolge',
      );
      expect(started.n, 0, reason: 'kosu henuz baslamadi');
      expect(rig.controller!.timeline, isNull);

      // Ikinci Baslat dokunusu yok sayilir.
      await _tapStart(t);
      await t.pump(const Duration(milliseconds: 500));
      expect(started.n, 0);

      await t.pump(const Duration(seconds: 3));
      expect(started.n, 1, reason: 'tam bir baslatma');
      expect(_previewText, findsNothing);
      expect(_hidden, findsOneWidget, reason: 'serit tekrar gizli');
      expect(_strip, findsNothing);
      await listen05f(t, rig);
      expect(
        rig.controller!.timeline,
        isNotNull,
        reason: 'kosu gercekten acik',
      );
      await dispose05f(t, rig);
      sem.dispose();
    });

    testWidgets('on izleme sirasinda dispose: Timer sizmaz, kosu baslamaz', (
      t,
    ) async {
      final started = _Started();
      final rig = await _screen(t, started, level: GhostLevel.recall);
      await _tapStart(t);
      await t.pump(const Duration(seconds: 1));
      expect(_previewText, findsOneWidget, reason: 'on izleme basladi');
      await dispose05f(t, rig);
      await t.pump(const Duration(seconds: 5));
      expect(started.n, 0);
    });

    for (final level in [
      GhostLevel.learn,
      GhostLevel.reinforce,
      GhostLevel.independent,
      null,
    ]) {
      testWidgets(
        '${level?.name ?? 'null'}: Baslat aninda baslar (gecikme yok)',
        (t) async {
          final started = _Started();
          final rig = await _screen(t, started, level: level);
          expect(find.byKey(const Key('practice-start')), findsOneWidget);
          await _tapStart(t);
          expect(started.n, 1, reason: 'aninda basladi');
          expect(_previewText, findsNothing);
          expect(find.text(_previewEn), findsNothing);
          await dispose05f(t, rig);
        },
      );
    }
  });

  group('d) rafta olmayan sey ekranda yok (Bagimsiz)', () {
    testWidgets('Bagimsiz: serit/etiket/on izleme/ipucu yok', (t) async {
      final started = _Started();
      final rig = await _screen(t, started, level: GhostLevel.independent);
      // var olan kardesler
      expect(find.byKey(const Key('practice-start')), findsOneWidget);
      expect(_hidden, findsOneWidget);
      // yokluklar
      expect(_strip, findsNothing);
      expect(_previewText, findsNothing);
      for (final s in ['İpucu', 'Hint', 'Ipucu']) {
        expect(find.textContaining(s), findsNothing, reason: s);
      }
      await _tapStart(t);
      expect(started.n, 1);
      expect(_previewText, findsNothing);
      expect(_strip, findsNothing);
      await dispose05f(t, rig);
    });

    for (final level in GhostLevel.values) {
      testWidgets('${level.name}: klik anahtari var (serbest tempo degil)', (
        t,
      ) async {
        final rig = await _screen(t, _Started(), level: level);
        expect(
          find.byKey(const Key('practice-metronome-sound')),
          findsOneWidget,
          reason: level.name,
        );
        await dispose05f(t, rig);
      });
    }
  });

  group('e) bayrak kapali esdegeri', () {
    testWidgets('ghostLevel null: serit var, vurus var, etiket/gecikme yok', (
      t,
    ) async {
      final started = _Started();
      final rig = await _screen(t, started);
      expect(_strip, findsOneWidget);
      expect(_hidden, findsNothing);
      expect(_painter(t).showNoteNames, isFalse);
      await _tapStart(t);
      expect(started.n, 1);
      expect(_previewText, findsNothing);
      await dispose05f(t, rig);
    });

    for (final level in GhostLevel.values) {
      testWidgets(
        'ritim-only + ${level.name}: serit durur, etiket/onizleme yok',
        (t) async {
          final started = _Started();
          final rig = await _screen(
            t,
            started,
            level: level,
            lesson: _rhythmOnly(),
          );
          expect(_strip, findsOneWidget, reason: level.name);
          expect(_painter(t).showNoteNames, isFalse, reason: level.name);
          await _tapStart(t);
          expect(started.n, 1, reason: 'gecikme yok');
          expect(_previewText, findsNothing);
          await dispose05f(t, rig);
        },
      );
    }
  });

  group('f) sahne zinciri', () {
    Future<Rig05f> stage(WidgetTester t, {required bool ghost}) async {
      final rig = Rig05f();
      await boot05f(
        t,
        stage05g(
          rig,
          catalog,
          locale: 'tr',
          ghost: ghost,
          ghostStore: MemoryGhostStore(
            const GhostState(level: GhostLevel.recall),
          ),
        ),
      );
      for (var i = 0; i < 4; i++) {
        await t.pump();
      }
      return rig;
    }

    testWidgets('ghostOpen:false + depoda Hatirlama: gecikme yok, serit var', (
      t,
    ) async {
      final rig = await stage(t, ghost: false);
      expect(_strip, findsOneWidget);
      await _tapStart(t);
      await t.pump(const Duration(milliseconds: 50));
      expect(_previewText, findsNothing);
      await listen05f(t, rig);
      expect(
        rig.controller!.timeline,
        isNotNull,
        reason: 'kosu aninda basladi',
      );
      await dispose05f(t, rig);
    });

    testWidgets('ghostOpen:true + depoda Hatirlama: on izleme var', (t) async {
      final rig = await stage(t, ghost: true);
      expect(_hidden, findsOneWidget);
      await _tapStart(t);
      await t.pump(const Duration(milliseconds: 500));
      expect(_previewText, findsOneWidget);
      expect(_strip, findsOneWidget);
      expect(rig.controller!.timeline, isNull);
      await t.pump(const Duration(seconds: 3));
      expect(_previewText, findsNothing);
      await listen05f(t, rig);
      expect(rig.controller!.timeline, isNotNull);
      await dispose05f(t, rig);
    });
  });

  group('r2) reviewer tur 1', () {
    Future<Rig05f> stage(
      WidgetTester t, {
      GhostLevel level = GhostLevel.recall,
      MemoryGhostStore? store,
    }) async {
      final rig = Rig05f();
      await boot05f(
        t,
        stage05g(
          rig,
          catalog,
          locale: 'tr',
          ghostStore: store ?? MemoryGhostStore(GhostState(level: level)),
        ),
      );
      for (var i = 0; i < 4; i++) {
        await t.pump();
      }
      return rig;
    }

    testWidgets('M1: on izlemede raf/Yardim kilitli, seviye degismez', (
      t,
    ) async {
      final store = MemoryGhostStore(
        const GhostState(level: GhostLevel.recall),
      );
      final rig = await stage(t, store: store);
      expect(find.byKey(const Key('stage-shelf-toggle')), findsOneWidget);
      await _tapStart(t);
      await t.pump(const Duration(milliseconds: 500));
      expect(_previewText, findsOneWidget, reason: 'on izleme basladi');
      expect(find.byKey(const Key('stage-shelf-toggle')), findsNothing);
      expect(store.state.level, GhostLevel.recall);
      await t.pump(const Duration(seconds: 3));
      await listen05f(t, rig);
      expect(rig.controller!.timeline, isNotNull);
      await dispose05f(t, rig);
    });

    testWidgets('M1: on izlemede geri -> kosu hic baslamaz (3 sn sonra da)', (
      t,
    ) async {
      final rig = await stage(t);
      await _tapStart(t);
      await t.pump(const Duration(milliseconds: 500));
      expect(_previewText, findsOneWidget);
      await t.binding.handlePopRoute();
      await t.pump();
      await t.pump();
      expect(_previewText, findsNothing);
      expect(find.byKey(const Key('practice-start')), findsOneWidget);
      expect(find.byKey(const Key('stage-shelf-toggle')), findsOneWidget);
      await t.pump(const Duration(seconds: 4));
      expect(_previewText, findsNothing);
      expect(rig.controller!.phase, isNot(PracticePhase.running));
      expect(rig.controller!.timeline, isNull);
      expect(rig.permissionCalls, 0, reason: 'mikrofon hic istenmedi');
      await dispose05f(t, rig);
    });

    testWidgets('M2: arka plana alinirsa on izleme iptal, kosu baslamaz', (
      t,
    ) async {
      final started = _Started();
      final rig = await _screen(t, started, level: GhostLevel.recall);
      await _tapStart(t);
      await t.pump(const Duration(milliseconds: 500));
      expect(_previewText, findsOneWidget);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await t.pump();
      await t.pump(const Duration(seconds: 4));
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pump();
      expect(started.n, 0, reason: 'kosu baslamadi');
      expect(_previewText, findsNothing);
      expect(_hidden, findsOneWidget, reason: 'bosta, serit gizli');
      await dispose05f(t, rig);
    });

    testWidgets('M3: reddedilen korumada on izleme yok, kosu yok', (t) async {
      final started = _Started();
      final rig = await _screen(
        t,
        started,
        level: GhostLevel.recall,
        beforeStart: () async => false,
      );
      await _tapStart(t);
      await t.pump(const Duration(seconds: 4));
      expect(_previewText, findsNothing);
      expect(_hidden, findsOneWidget);
      expect(started.n, 0);
      await dispose05f(t, rig);
    });

    testWidgets('M3: gecikmeli onayda on izleme onaydan SONRA baslar', (
      t,
    ) async {
      final gate = Completer<bool>();
      final started = _Started();
      final rig = await _screen(
        t,
        started,
        level: GhostLevel.recall,
        beforeStart: () => gate.future,
      );
      await _tapStart(t);
      await t.pump(const Duration(seconds: 2));
      expect(_previewText, findsNothing, reason: 'onaydan once yok');
      expect(_hidden, findsOneWidget);
      gate.complete(true);
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(_previewText, findsOneWidget);
      expect(started.n, 0);
      await t.pump(const Duration(seconds: 3));
      expect(started.n, 1);
      await dispose05f(t, rig);
    });

    testWidgets('D6: on izleme duzeni kaymaz; Baslat gorsel devre disi', (
      t,
    ) async {
      final rig = await _screen(t, _Started(), level: GhostLevel.recall);
      final before = t.getTopLeft(find.byKey(const Key('practice-start'))).dy;
      await _tapStart(t);
      await t.pump(const Duration(milliseconds: 500));
      expect(_previewText, findsOneWidget);
      expect(
        t.getTopLeft(find.byKey(const Key('practice-start'))).dy,
        before,
        reason: 'Baslat dikeyde kaymadi',
      );
      expect(
        t
            .widget<ButtonStyleButton>(find.byKey(const Key('practice-start')))
            .onPressed,
        isNull,
      );
      await dispose05f(t, rig);
    });

    testWidgets('D4: en ust tel notasinda etiket serit icinde kalir', (
      t,
    ) async {
      final rig = await _screen(t, _Started(), level: GhostLevel.learn);
      final p = _painter(t);
      // string 1 (en ust tel) notasi olan bir ders ara.
      PracticeScore? top;
      PracticeEvent? ev;
      final files =
          Directory('content/v1/gtr').listSync().whereType<File>().toList()
            ..sort((a, b) => a.path.compareTo(b.path));
      for (final f in files) {
        if (!f.path.endsWith('.json')) continue;
        final sc = V1PracticeCatalog.scoreOf(
          V1Lesson.fromJson(jsonDecode(f.readAsStringSync())),
          seed: 1,
        );
        if (sc == null) continue;
        for (final e in sc.events) {
          if (e.midi != null && guitarTabPosition(e.midi!)?.string == 1) {
            top = sc;
            ev = e;
            break;
          }
        }
        if (top != null) break;
      }
      expect(top, isNotNull, reason: 'string-1 notali ders bulundu');
      final painter = TabStripPainter(
        score: top!,
        displayBeat: ev!.startBeat,
        marks: const {},
        heldEvent: null,
        loop: null,
        pixelsPerBeat: p.pixelsPerBeat,
        nowFraction: p.nowFraction,
        guitar: true,
        showNoteNames: true,
        theme: p.theme,
        ink: p.ink,
        paper: p.paper,
        muted: p.muted,
        now: p.now,
      );
      final c = _RecCanvas();
      painter.paint(c, const Size(420, 190));
      expect(c.boxes, isNotEmpty);
      for (final b in c.boxes) {
        // 2 px pay: gercek yazi tipinde satir yuksekligi test yazisindan buyuk.
        expect(b.top, greaterThanOrEqualTo(2), reason: '$b ustten tasti');
        expect(b.bottom, lessThanOrEqualTo(190), reason: '$b alttan tasti');
      }
      await dispose05f(t, rig);
    });

    testWidgets('D5: etiket yerellestirilir (tr != en); shouldRepaint', (
      t,
    ) async {
      final rigTr = await _screen(t, _Started(), level: GhostLevel.learn);
      final tr = _painter(t).noteNames.values.toList();
      await dispose05f(t, rigTr);
      final rigEn = await _screen(
        t,
        _Started(),
        level: GhostLevel.learn,
        locale: 'en',
      );
      final en = _painter(t).noteNames.values.toList();
      expect(tr, isNotEmpty);
      expect(tr, isNot(en), reason: 'musicPitch tr/en farkli');
      final p = _painter(t);
      TabStripPainter mk(bool names, Map<int, String> map) => TabStripPainter(
        score: p.score,
        displayBeat: p.displayBeat,
        marks: p.marks,
        heldEvent: p.heldEvent,
        loop: p.loop,
        pixelsPerBeat: p.pixelsPerBeat,
        nowFraction: p.nowFraction,
        guitar: p.guitar,
        showNoteNames: names,
        noteNames: map,
        theme: p.theme,
        ink: p.ink,
        paper: p.paper,
        muted: p.muted,
        now: p.now,
      );
      expect(mk(true, const {}).shouldRepaint(mk(false, const {})), isTrue);
      expect(
        mk(true, const {1: 'Mi4'}).shouldRepaint(mk(true, const {1: 'E4'})),
        isTrue,
      );
      expect(
        mk(true, const {1: 'E4'}).shouldRepaint(mk(true, const {1: 'E4'})),
        isFalse,
      );
      await dispose05f(t, rigEn);
    });

    testWidgets('B1: uzun dilde + 360x640 + yazi 1.3: on izleme tasmaz, '
        'Baslat ile cakismaz', (t) async {
      for (final (tag, locale, text) in [
        ('de', const Locale('de'), 'Noten 3 Sekunden vor dem Start'),
        (
          'pt-BR',
          const Locale('pt', 'BR'),
          'Partitura por 3 segundos antes de começar',
        ),
        ('fr', const Locale('fr'), 'Notation 3 secondes avant de commencer'),
      ]) {
        final rig = Rig05f();
        await boot05f(
          t,
          MaterialApp(
            theme: ostinatoTheme(),
            locale: locale,
            supportedLocales: [locale],
            localizationsDelegates: [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              _CatalogDelegate(tag),
            ],
            builder: (c, child) => MediaQuery(
              data: MediaQuery.of(
                c,
              ).copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
            home: PracticeLoopScreen(
              lesson: _pitched(),
              progress: Mem05f(),
              seed: 1,
              ghostLevel: GhostLevel.recall,
              controllerFactory: rig.factory,
            ),
          ),
          size: const Size(360, 640),
        );
        await t.ensureVisible(find.byKey(const Key('practice-start')));
        await t.tap(find.byKey(const Key('practice-start')));
        await t.pump();
        await t.pump(const Duration(milliseconds: 500));
        expect(find.text(text), findsOneWidget, reason: tag);
        expect(t.takeException(), isNull, reason: tag);
        final box = t.getRect(find.byKey(const Key('practice-preview-note')));
        final para = t.renderObject<RenderParagraph>(find.text(text));
        expect(
          box.height,
          greaterThanOrEqualTo(para.getMaxIntrinsicHeight(box.width)),
          reason: '$tag: kutu yaziyi sigdirir',
        );
        final start = t.getRect(find.byKey(const Key('practice-start')));
        expect(
          box.overlaps(start),
          isFalse,
          reason: '$tag: Baslat ile cakisma',
        );
        await dispose05f(t, rig);
      }
    });

    testWidgets('B2: on izlemede hesap degisimiyle ekran yeniden kurulur: '
        'kilit takili kalmaz', (t) async {
      final rig = Rig05f();
      final store = MemoryGhostStore(
        const GhostState(level: GhostLevel.recall),
      );
      Widget host(String id) => AccountScope(
        connection: null,
        currentUserId: id,
        child: stage05g(rig, catalog, locale: 'tr', ghostStore: store),
      );
      await boot05f(t, host('a'));
      for (var i = 0; i < 4; i++) {
        await t.pump();
      }
      await _tapStart(t);
      await t.pump(const Duration(milliseconds: 500));
      expect(_previewText, findsOneWidget);
      expect(find.byKey(const Key('stage-shelf-toggle')), findsNothing);
      await t.pumpWidget(host('b'));
      for (var i = 0; i < 8; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(find.byKey(const Key('practice-start')), findsOneWidget);
      expect(
        find.byKey(const Key('stage-shelf-toggle')),
        findsOneWidget,
        reason: 'raf yeniden kullanilabilir',
      );
      await t.pump(const Duration(seconds: 4));
      expect(rig.controller!.timeline, isNull, reason: 'kosu baslamadi');
      await dispose05f(t, rig);
    });

    testWidgets('B3: arka plandayken koruma biterse on izleme/kosu yok', (
      t,
    ) async {
      final gate = Completer<bool>();
      final started = _Started();
      final rig = await _screen(
        t,
        started,
        level: GhostLevel.recall,
        beforeStart: () => gate.future,
      );
      await _tapStart(t);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await t.pump();
      gate.complete(true);
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(_previewText, findsNothing, reason: 'arka planda on izleme yok');
      expect(_hidden, findsOneWidget, reason: 'bosta');
      await t.pump(const Duration(seconds: 4));
      expect(_previewText, findsNothing);
      expect(started.n, 0);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pump();
      await dispose05f(t, rig);
    });

    testWidgets('B5: sahnede yasam dongusu iptali kilidi cozer', (t) async {
      final rig = await stage(t);
      expect(find.byKey(const Key('stage-shelf-toggle')), findsOneWidget);
      await _tapStart(t);
      await t.pump(const Duration(milliseconds: 500));
      expect(_previewText, findsOneWidget);
      expect(find.byKey(const Key('stage-shelf-toggle')), findsNothing);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await t.pump();
      await t.pump();
      expect(_previewText, findsNothing);
      expect(find.byKey(const Key('stage-shelf-toggle')), findsOneWidget);
      await t.pump(const Duration(seconds: 4));
      expect(rig.controller!.timeline, isNull, reason: 'kosu baslamadi');
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pump();
      await dispose05f(t, rig);
    });
  });
}
