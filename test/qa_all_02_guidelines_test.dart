// QA-ALL-02 (Ostinato): erisilebilirlik kontrol testleri.
//   A) ana ekranlarda dort `meetsGuideline` (android/iOS hedef boyutu,
//      etiketli hedef, metin kontrasti)
//   B) metin olcegi 2x: ana 3 ekranda tasma yok, kritik dugmeler bulunur
//      ve dokunulabilir.
// Kurulumlar mevcut testlerden (ux_05h1, ux_05e, tuner, library) alindi.
// Bulgu varsa `_findings` icinde literal aciklamayla skip edilir; bekci
// gevsetilmez.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/audio/audio_input_controller.dart';
import 'package:ostinato/app/content.dart';
import 'package:ostinato/app/cue_text.dart';
import 'package:ostinato/app/curriculum/v1_lesson.dart';
import 'package:ostinato/app/design/app_scope.dart';
import 'package:ostinato/app/practice/loop/practice_loop_screen.dart';
import 'package:ostinato/app/practice/loop/practice_outcome.dart';
import 'package:ostinato/app/practice/loop/practice_marks.dart';
import 'package:ostinato/app/practice/loop/practice_result_screen.dart';
import 'package:ostinato/app/practice/loop/practice_score.dart';
import 'package:ostinato/app/screens/library_screen.dart';
import 'package:ostinato/app/screens/settings_screen.dart';
import 'package:ostinato/app/tuner/tuner_analysis.dart';
import 'package:ostinato/app/tuner/tuner_check_memory.dart';
import 'package:ostinato/app/tuner/tuner_controller.dart';
import 'package:ostinato/app/tuner/tuner_screen.dart';
import 'package:ostinato_audio/ostinato_audio.dart';
import 'package:permission_handler/permission_handler.dart';

import 'support/practice_host.dart';
import 'support/ux_05f_rig.dart';

/// Bilinen urun bulgulari: 'ekran/guideline' -> aciklama (skip nedeni).
const Map<String, String> _findings = <String, String>{};

V1Lesson _lesson() => V1Lesson.fromJson(
  jsonDecode(File('content/v1/gtr/gtr-s1-m02-02.json').readAsStringSync()),
);

final _score = PracticeScore.parse('E2 F2 G2 F2 | E2 F2 G2 F2');

PracticeRunSummary _summary() => PracticeRunSummary.of(
  score: _score,
  outcomes: [
    for (var i = 0; i < 8; i++)
      NoteOutcome(
        eventIndex: i,
        bar: _score.events[i].bar,
        pass: 0,
        mark: i < 5 ? PracticeMark.correct : PracticeMark.differentNote,
        expectedMidi: _score.events[i].midi,
        observedMidi: i < 5 ? null : 45,
      ),
  ],
  bpm: 60,
  openBpm: 50,
  targetBpm: 60,
  completed: true,
  loopUsed: false,
  waitUsed: false,
  criteria: const PassCriteria(minAccuracy: .8),
);

typedef _Open =
    Future<Future<void> Function()> Function(WidgetTester t, double scale);

Future<void> _size(WidgetTester t, Size s) async {
  t.view.physicalSize = s;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
}

Widget _scaled(double scale, Widget child) => Builder(
  builder: (c) => MediaQuery(
    data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
    child: child,
  ),
);

Future<Future<void> Function()> _stage(
  WidgetTester t,
  double scale, {
  bool play = false,
  String? handle,
}) async {
  final rig = Rig05f();
  final catalog = catalog05f();
  await _size(t, const Size(390, 844));
  await boot05f(
    t,
    stage05f(
      rig,
      catalog,
      textScale: scale,
      micStatus: () async => PermissionStatus.granted,
    ),
    size: const Size(390, 844),
  );
  if (play) await play05f(t);
  if (handle != null) {
    await t.tap(find.byKey(Key(handle)));
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));
  }
  return () => dispose05f(t, rig);
}

Future<Future<void> Function()> _loop(WidgetTester t, double scale) async {
  final rig = Rig05f();
  await boot05f(
    t,
    practiceHost(
      _scaled(
        scale,
        PracticeLoopScreen(
          lesson: _lesson(),
          progress: Mem05f(),
          seed: 1,
          controllerFactory: rig.factory,
        ),
      ),
    ),
    size: const Size(390, 844),
  );
  await _size(t, const Size(390, 844));
  return () => dispose05f(t, rig);
}

Future<Future<void> Function()> _result(WidgetTester t, double scale) async {
  await _size(t, const Size(390, 844));
  await t.pumpWidget(
    practiceHost(
      _scaled(
        scale,
        PracticeResultScreen(
          lesson: _lesson(),
          score: _score,
          summary: _summary(),
          stage: true,
        ),
      ),
    ),
  );
  await t.pump();
  return () async {};
}

Future<Future<void> Function()> _tuner(WidgetTester t, double scale) async {
  final source = FakeAudioSource();
  final controller = TunerController(
    source: source,
    analyzer: (s, r, f, p) async =>
        const TunerAnalysis.refused(TunerRefusal.insufficientSamples),
    memory: TunerCheckMemory(),
  );
  await _size(t, const Size(390, 844));
  await t.pumpWidget(
    MaterialApp(home: _scaled(scale, TunerScreen(controller: controller))),
  );
  await t.pump();
  return () async {
    await t.pumpWidget(const SizedBox());
    controller.dispose();
    await t.runAsync(source.dispose);
  };
}

Future<Future<void> Function()> _repoScreen(
  WidgetTester t,
  double scale,
  Widget Function(ContentRepository, CueTextResolver) build,
) async {
  final repo = (await t.runAsync(ContentRepository.load))!;
  final cues = (await t.runAsync(CueTextResolver.load))!;
  await _size(t, const Size(390, 844));
  await t.pumpWidget(
    ContentRepositoryScope(
      repo: repo,
      cueText: cues,
      child: MaterialApp(home: _scaled(scale, build(repo, cues))),
    ),
  );
  await t.pump();
  await t.pump();
  return () async {};
}

Future<Future<void> Function()> _library(WidgetTester t, double scale) =>
    _repoScreen(t, scale, (r, c) => LibraryScreen(repo: r, cueText: c));

Future<Future<void> Function()> _settings(WidgetTester t, double scale) =>
    _repoScreen(t, scale, (r, c) => const SettingsScreen());

final Map<String, _Open> _screens = <String, _Open>{
  'stage-durgun': (t, s) => _stage(t, s),
  'stage-calarken': (t, s) => _stage(t, s, play: true),
  'pratik-dongusu': _loop,
  'sonuc': _result,
  'kutuphane': _library,
  'akort': _tuner,
  'ayarlar-karti': (t, s) => _stage(t, s, handle: 'stage-handle-setup'),
  'ayarlar-ekrani': _settings,
  'baska-calis': (t, s) => _stage(t, s, handle: 'stage-handle-other'),
};

final Map<String, AccessibilityGuideline Function()> _guidelines =
    <String, AccessibilityGuideline Function()>{
      'android-hedef': () => androidTapTargetGuideline,
      'ios-hedef': () => iOSTapTargetGuideline,
      'etiketli-hedef': () => labeledTapTargetGuideline,
      'metin-kontrast': () => textContrastGuideline,
    };

void main() {
  setUp(resetAudioCaptureCoordinatorForTest);

  group('A) meetsGuideline', () {
    for (final s in _screens.entries) {
      for (final g in _guidelines.entries) {
        final id = '${s.key}/${g.key}';
        testWidgets('$id${_findings.containsKey(id) ? ' [BULGU]' : ''}', (
          t,
        ) async {
          final handle = t.ensureSemantics();
          final close = await s.value(t, 1.0);
          await expectLater(t, meetsGuideline(g.value()));
          handle.dispose();
          await close();
        }, skip: _findings.containsKey(id));
      }
    }
  });

  group('B) metin olcegi 2x', () {
    Future<void> clean(WidgetTester t, String why) async {
      final e = t.takeException();
      expect(e, isNull, reason: '$why: tasma/istisna yok');
    }

    Future<void> reachable(WidgetTester t, String key, String why) async {
      final f = find.byKey(Key(key));
      expect(f, findsOneWidget, reason: '$why: $key bulunur');
      await t.ensureVisible(f);
      await t.pump();
      expect(
        f.hitTestable(),
        findsOneWidget,
        reason: '$why: $key dokunulabilir',
      );
    }

    testWidgets('stage-durgun 2x', (t) async {
      final close = await _stage(t, 2.0);
      await clean(t, 'stage');
      await reachable(t, 'practice-start', 'stage');
      await reachable(t, 'stage-handle-setup', 'stage');
      await clean(t, 'stage-sonrasi');
      await close();
    });

    testWidgets('stage-calarken 2x', (t) async {
      final close = await _stage(t, 2.0, play: true);
      await clean(t, 'calarken');
      await close();
    });

    testWidgets('pratik-dongusu 2x', (t) async {
      final close = await _loop(t, 2.0);
      await clean(t, 'dongu');
      await reachable(t, 'practice-start', 'dongu');
      await clean(t, 'dongu-sonrasi');
      await close();
    });

    testWidgets('sonuc 2x', (t) async {
      final close = await _result(t, 2.0);
      await clean(t, 'sonuc');
      await reachable(t, 'result-retry', 'sonuc');
      await clean(t, 'sonuc-sonrasi');
      await close();
    });
  });

  group('C) sonuc satiri: deger sag kenarda (eski davranis)', () {
    for (final size in const [Size(390, 844), Size(360, 640)]) {
      for (final scale in const [1.0, 2.0]) {
        testWidgets('${size.width.toInt()} x$scale', (t) async {
          await t.binding.setSurfaceSize(size);
          addTearDown(() => t.binding.setSurfaceSize(null));
          await t.pumpWidget(
            practiceHost(
              _scaled(
                scale,
                PracticeResultScreen(
                  lesson: _lesson(),
                  score: _score,
                  summary: _summary(),
                  stage: true,
                ),
              ),
            ),
          );
          await t.pump();
          expect(t.takeException(), isNull, reason: 'tasma yok');
          for (final k in const ['result-accuracy', 'result-heard']) {
            final v = find.byKey(Key(k));
            expect(v, findsOneWidget, reason: k);
            final row = find.ancestor(of: v, matching: find.byType(Row)).first;
            expect(
              t.getTopRight(v).dx,
              closeTo(t.getTopRight(row).dx, 0.5),
              reason: '$k: deger sag kenari satir sag kenari',
            );
          }
        });
      }
    }
  });
}
