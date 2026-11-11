// OST-UX-05f general criterion: no overflow at 390x844 and 360x640 with text
// 1.3 in the refusal mode (tool shelf open) and with the Setup / Device layer.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/audio/audio_input_controller.dart';
import 'package:permission_handler/permission_handler.dart';

import 'support/ux_05f_rig.dart';

void main() {
  late final catalog = catalog05f();
  setUp(resetAudioCaptureCoordinatorForTest);

  final sizes = <Size>[const Size(390, 844), const Size(360, 640)];
  for (final size in sizes) {
    final tag = '${size.width.toInt()}x${size.height.toInt()}';

    testWidgets('05f-ovf2: mode ON + tool shelf OPEN, $tag, text 1.3', (
      t,
    ) async {
      final rig = Rig05f(permission: PermissionStatus.denied);
      await boot05f(t, stage05f(rig, catalog, textScale: 1.3), size: size);
      await play05f(t);
      await t.tap(find.byKey(const Key('stage-shelf-toggle')));
      await t.pump();
      await t.pump();
      expect(t.takeException(), isNull);
      expect(find.byKey(const Key('stage-listening-off')), findsOneWidget);
      expect(find.byKey(const Key('stage-shelf')), findsOneWidget);
      // The play control and the failure line are still there and on screen.
      expect(find.byKey(const Key('practice-failure')), findsOneWidget);
      final start = find.byKey(const Key('practice-start'));
      expect(start, findsOneWidget);
      expect(
        Offset.zero & size,
        _contains(t.getRect(start)),
        reason: 'Play stays inside the screen',
      );
      await dispose05f(t, rig);
    });

    testWidgets('05f-ovf2: mode ON, shelf closed, Play works, $tag, 1.3', (
      t,
    ) async {
      final rig = Rig05f(permission: PermissionStatus.denied);
      await boot05f(t, stage05f(rig, catalog, textScale: 1.3), size: size);
      await play05f(t);
      await play05f(t); // Play again after the refusal: no exception
      expect(t.takeException(), isNull);
      expect(find.byKey(const Key('stage-listening-off')), findsOneWidget);
      await dispose05f(t, rig);
    });

    testWidgets('05f-ovf2-control: NO mode, shelf open, $tag, text 1.3', (
      t,
    ) async {
      final rig = Rig05f();
      await boot05f(t, stage05f(rig, catalog, textScale: 1.3), size: size);
      await t.tap(find.byKey(const Key('stage-shelf-toggle')));
      await t.pump();
      await t.pump();
      expect(t.takeException(), isNull);
      await dispose05f(t, rig);
    });

    testWidgets('05f-ovf2: Setup / Device layer open, $tag, text 1.3', (
      t,
    ) async {
      final rig = Rig05f();
      await boot05f(
        t,
        stage05f(
          rig,
          catalog,
          textScale: 1.3,
          micStatus: () async => PermissionStatus.permanentlyDenied,
        ),
        size: size,
      );
      await t.tap(find.byKey(const Key('stage-handle-setup')));
      await t.pump();
      await t.pump();
      await t.pump();
      expect(t.takeException(), isNull);
      expect(find.byKey(const Key('stage-device-layer')), findsOneWidget);
      expect(find.text('Mikrofon: izin kapalı'), findsOneWidget);
      expect(find.byKey(const Key('practice-start')), findsOneWidget);
      await dispose05f(t, rig);
    });
  }
}

Matcher _contains(Rect inner) => predicate<Rect>(
  (outer) =>
      outer.left <= inner.left &&
      outer.top <= inner.top &&
      outer.right >= inner.right &&
      outer.bottom >= inner.bottom,
  'contains $inner',
);
