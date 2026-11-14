// OST-UX-05h-3 — sertlestirme.
// (a) Gizli serit yer tutucusu `ghost-step-line-hidden`. Karar: dekoratif bos
//     alandir -> ExcludeSemantics; ekran okuyucu bos alani hicbir sey olarak
//     okumaz. Kirmizi: onceki kodda ExcludeSemantics ata dugumu yoktu.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/audio/audio_input_controller.dart';
import 'package:ostinato/app/curriculum/v1_lesson.dart';
import 'package:ostinato/app/practice/loop/practice_loop_screen.dart';
import 'package:ostinato/app/stage/ghost_policy.dart';

import 'support/practice_host.dart';
import 'support/ux_05g_rig.dart';

V1Lesson _pitched() => V1Lesson.fromJson(
  jsonDecode(File('content/v1/gtr/gtr-s1-m02-02.json').readAsStringSync()),
);

Future<Rig05f> _small(WidgetTester t, GhostLevel level, double scale) async {
  final rig = Rig05f();
  await boot05f(
    t,
    practiceHost(
      locale: 'tr',
      Builder(
        builder: (c) => MediaQuery(
          data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
          child: PracticeLoopScreen(
            lesson: _pitched(),
            progress: Mem05f(),
            seed: 1,
            ghostLevel: level,
            controllerFactory: rig.factory,
          ),
        ),
      ),
    ),
    size: const Size(360, 640),
  );
  return rig;
}

void main() {
  setUp(resetAudioCaptureCoordinatorForTest);

  group('05h-3 a: gizli serit yer tutucusu', () {
    for (final level in [GhostLevel.recall, GhostLevel.independent]) {
      testWidgets('${level.name}: semantik disi + 360x640 yazi 1.3 tasmaz', (
        t,
      ) async {
        final h = t.ensureSemantics();
        final rig = await _small(t, level, 1.3);
        final hidden = find.byKey(const Key('ghost-step-line-hidden'));
        expect(hidden, findsOneWidget);
        expect(
          find.ancestor(of: hidden, matching: find.byType(ExcludeSemantics)),
          findsWidgets,
          reason: 'bos yer tutucu ekran okuyucuya kapali',
        );
        expect(t.takeException(), isNull, reason: 'tasma yok');
        expect(find.byKey(const Key('practice-start')), findsOneWidget);
        await t.ensureVisible(find.byKey(const Key('practice-start')));
        await t.pump();
        final start = t.getRect(find.byKey(const Key('practice-start')));
        expect(start.bottom, lessThanOrEqualTo(640.5));
        expect(start.top, greaterThanOrEqualTo(0));
        expect(t.getRect(hidden).width, lessThanOrEqualTo(360));
        h.dispose();
        await dispose05f(t, rig);
      });
    }
  });

  // (c) D5 sinir: `stage-shelf-scroll` yuksekligi 700/701 dp esiginde.
  group('05h-3 c: D5 raf kaydirma siniri', () {
    for (final e in <(double, double)>[(700, 0.17), (701, 0.34)]) {
      testWidgets(
        'yukseklik ${e.$1.toInt()}: raf <= %${(e.$2 * 100).round()}',
        (t) async {
          final rig = Rig05f();
          await boot05f(t, stage05g(rig, catalog05f()), size: Size(360, e.$1));
          await t.tap(find.byKey(const Key('stage-shelf-toggle')));
          await t.pump();
          await t.pump();
          final h = t
              .getSize(find.byKey(const Key('stage-shelf-scroll')))
              .height;
          expect(h, lessThanOrEqualTo(e.$1 * e.$2 + 0.01), reason: 'h=$h');
          expect(h, greaterThan(40), reason: 'raf bos degil');
          await dispose05f(t, rig);
        },
      );
    }
  });

  // (d) Kalem 2/4: büyük metin 2.0 ve hareketi azalt, sahne + katmanlar.
  group('05h-3 d: yazi 2.0 ve hareketi azalt', () {
    for (final size in <Size>[const Size(360, 640), const Size(390, 844)]) {
      for (final handle in const [
        'stage-handle-setup',
        'stage-handle-path',
        'stage-handle-other',
      ]) {
        testWidgets(
          'yazi 2.0 + hareketi azalt (360 = BULGU/skip): ${size.width.toInt()}x${size.height.toInt()} '
          '$handle tasmaz, anlik, cam yok',
          skip:
              size.width == 360, // BULGU: 360x640 yazi 2.0 sahnede 30 px tasar
          (t) async {
            final rig = Rig05f();
            await boot05f(
              t,
              MediaQuery(
                data: const MediaQueryData(
                  disableAnimations: true,
                  highContrast: true,
                ),
                child: stage05g(rig, catalog05f(), textScale: 2.0),
              ),
              size: size,
            );
            expect(t.takeException(), isNull, reason: 'sahne 2.0 tasmaz');
            // Ölçüm (05h-3): sahnede eski GlassCard 4 BackdropFilter çizer
            // (SessionTuningGateCard vb.); katman açmak EK cam eklememeli.
            final glass = find.byType(BackdropFilter).evaluate().length;
            await t.ensureVisible(find.byKey(const Key('practice-start')));
            await t.pump();
            final start = t.getRect(find.byKey(const Key('practice-start')));
            expect(start.top, greaterThanOrEqualTo(0));
            expect(start.bottom, lessThanOrEqualTo(size.height + 0.5));
            await t.ensureVisible(find.byKey(Key(handle)));
            await t.pump();
            await t.tap(find.byKey(Key(handle)));
            await t.pump(); // gecis animasyonu yok
            await t.pump();
            await t.pump();
            expect(t.takeException(), isNull, reason: 'katman 2.0 tasmaz');
            expect(
              find.byType(BackdropFilter).evaluate().length,
              lessThanOrEqualTo(glass),
              reason: 'katman ek cam eklemez',
            );
            for (var i = 0; i < 6; i++) {
              await t.runAsync(() => Future<void>.delayed(Duration.zero));
              await t.pump(const Duration(milliseconds: 100));
            }
            if (handle == 'stage-handle-path') {
              expect(
                find.byKey(const Key('stage-path-scroll')),
                findsOneWidget,
              );
            }
            await dispose05f(t, rig);
          },
        );
      }
    }
  });
}
