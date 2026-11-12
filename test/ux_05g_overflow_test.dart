// OST-UX-05g genel olcut: 390x844 ve 360x640, yazi 1.3'te Yardim yuzeyi tasmaz;
// "Cal" ve rafta diger satirlar erisilebilir kalir.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/audio/audio_input_controller.dart';
import 'package:ostinato/app/practice/loop/v1_course_catalog.dart';
import 'package:ostinato/app/stage/ghost_policy.dart';
import 'package:ostinato/app/stage/ghost_store.dart';

import 'support/ux_05g_rig.dart';

void main() {
  late final V1CourseCatalog catalog = catalog05f();
  setUp(resetAudioCaptureCoordinatorForTest);

  for (final size in <Size>[const Size(390, 844), const Size(360, 640)]) {
    final tag = '${size.width.toInt()}x${size.height.toInt()}';
    for (final level in GhostLevel.values) {
      testWidgets('05g-ovf: Yardim yuzeyi ${level.name}, $tag, yazi 1.3', (
        t,
      ) async {
        final rig = Rig05f();
        final store = MemoryGhostStore(
          GhostState(
            level: level,
            validRuns: 5,
            lastRun: GhostLastRun.notMeasured,
          ),
        );
        await boot05f(
          t,
          stage05g(rig, catalog, ghostStore: store, textScale: 1.3),
          size: size,
        );
        await t.tap(find.byKey(const Key('stage-shelf-toggle')));
        await t.pump();
        await t.pump();
        await t.ensureVisible(find.byKey(const Key('stage-help-row')));
        await t.pump();
        await t.tap(find.byKey(const Key('stage-help-row')));
        await t.pump();
        await t.pump();
        expect(find.byKey(const Key('ghost-help-surface')), findsOneWidget);
        for (final l in GhostLevel.values) {
          final f = find.byKey(Key('ghost-level-${l.name}'));
          expect(f, findsOneWidget, reason: l.name);
          await t.ensureVisible(f);
          await t.pump();
          expect(
            Offset.zero & size,
            _contains(t.getRect(f)),
            reason: 'secenek ekranda: ${l.name}',
          );
        }
        // rafta diger satir erisilebilir (kaydirarak)
        final pin = find.byKey(const Key('stage-pin-metronome'));
        expect(pin, findsOneWidget);
        await t.ensureVisible(pin);
        await t.pump();
        expect(Offset.zero & size, _contains(t.getRect(pin)));
        // "Cal" ekran icinde ve dokunulabilir
        final start = find.byKey(const Key('practice-start'));
        expect(start, findsOneWidget);
        expect(Offset.zero & size, _contains(t.getRect(start)));
        expect(start.hitTestable(), findsOneWidget);
        expect(t.takeException(), isNull);
        await dispose05f(t, rig);
      });
    }
  }
}

Matcher _contains(Rect r) => predicate<Rect>(
  (outer) =>
      r.left >= outer.left - .5 &&
      r.right <= outer.right + .5 &&
      r.top >= outer.top - .5 &&
      r.bottom <= outer.bottom + .5,
  'rect $r inside',
);
