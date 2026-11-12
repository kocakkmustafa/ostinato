// OST-UX-05f criteria 1, 2 and (iii): microphone refusal -> "Listening is
// off" mode on the stage, the Go to Settings link and its local mute.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/audio/audio_input_controller.dart';
import 'package:ostinato/app/practice/loop/reference_listen_bar.dart';
import 'package:ostinato/app/stage/listening_off_store.dart';
import 'package:permission_handler/permission_handler.dart';

import 'support/ux_05f_rig.dart';

void main() {
  late final catalog = catalog05f();
  setUp(resetAudioCaptureCoordinatorForTest);

  Future<Rig05f> denied(
    WidgetTester t, {
    PermissionStatus status = PermissionStatus.denied,
    Hooks05f? hooks,
    ListeningOffStore? store,
    String locale = 'tr',
    Size size = const Size(390, 844),
    double textScale = 1.0,
  }) async {
    final rig = Rig05f(permission: status);
    await boot05f(
      t,
      stage05f(
        rig,
        catalog,
        hooks: hooks,
        store: store,
        locale: locale,
        textScale: textScale,
      ),
      size: size,
    );
    await play05f(t);
    return rig;
  }

  group('05f-1 listening-off mode', () {
    testWidgets('05f-1a: denied -> "Dinleme kapalı" (tr)', (t) async {
      final rig = await denied(t);
      expect(find.byKey(const Key('stage-listening-off')), findsOneWidget);
      expect(find.text('Dinleme kapalı'), findsOneWidget);
      await dispose05f(t, rig);
    });

    testWidgets('05f-1b: permanently denied -> same mode', (t) async {
      final rig = await denied(t, status: PermissionStatus.permanentlyDenied);
      expect(find.byKey(const Key('stage-listening-off')), findsOneWidget);
      await dispose05f(t, rig);
    });

    testWidgets('05f-1c: en copy "Listening is off"', (t) async {
      final rig = await denied(t, locale: 'en');
      expect(find.text('Listening is off'), findsOneWidget);
      await dispose05f(t, rig);
    });

    testWidgets('05f-1d: granted -> no mode', (t) async {
      final rig = Rig05f();
      await boot05f(t, stage05f(rig, catalog));
      await play05f(t);
      expect(find.byKey(const Key('stage-listening-off')), findsNothing);
      await t.pump(const Duration(milliseconds: 100));
      await dispose05f(t, rig);
    });

    testWidgets(
      '05f-1e: no check/diamond/circle marks, counter says not measured',
      (t) async {
        final rig = await denied(t);
        for (final g in ['✓', '◆', '◯']) {
          expect(find.textContaining(g), findsNothing, reason: g);
        }
        expect(find.byKey(const Key('practice-counts')), findsNothing);
        final counter = find.byKey(const Key('stage-listening-off-counter'));
        expect(counter, findsOneWidget);
        expect((t.widget(counter) as Text).data, contains('ölçülmüyor'));
        await dispose05f(t, rig);
      },
    );

    testWidgets(
      '05f-1e-control: microphone allowed -> marks and counters show',
      (t) async {
        final rig = Rig05f();
        await boot05f(t, stage05f(rig, catalog));
        await play05f(t);
        expect(find.byKey(const Key('stage-listening-off')), findsNothing);
        expect(find.byKey(const Key('practice-counts')), findsOneWidget);
        expect(find.byKey(const Key('practice-count-correct')), findsOneWidget);
        expect(find.textContaining('✓'), findsWidgets);
        expect(
          find.byKey(const Key('stage-listening-off-counter')),
          findsNothing,
        );
        await t.pump(const Duration(milliseconds: 100));
        await dispose05f(t, rig);
      },
    );

    testWidgets(
      '05f-1f: strip, metronome, reference and tuner stay reachable',
      (t) async {
        final hooks = Hooks05f();
        final rig = await denied(t, hooks: hooks);
        expect(find.byKey(const Key('stage-listening-off')), findsOneWidget);
        await t.tap(find.byKey(const Key('stage-shelf-toggle')));
        await t.pump();
        expect(find.byKey(const Key('stage-pin-metronome')), findsOneWidget);
        expect(find.byType(ReferenceListenBar), findsOneWidget);
        // Metronome pin is a working switch; the reference buttons are
        // enabled and inside the screen.
        expect(
          t
              .widget<SwitchListTile>(
                find.byKey(const Key('stage-pin-metronome')),
              )
              .value,
          isFalse,
        );
        await t.tap(find.byKey(const Key('stage-pin-metronome')));
        await t.pump();
        expect(
          t
              .widget<SwitchListTile>(
                find.byKey(const Key('stage-pin-metronome')),
              )
              .value,
          isTrue,
        );
        final ref = find.byWidgetPredicate(
          (w) =>
              w is OutlinedButton &&
              w.key.toString().contains('reference-listen-'),
        );
        expect(ref, findsWidgets);
        expect(t.widget<OutlinedButton>(ref.first).onPressed, isNotNull);
        await t.tap(find.byKey(const Key('stage-shelf-toggle')));
        await t.pump();
        await t.tap(find.byKey(const Key('stage-handle-other')));
        await t.pump();
        await t.pump();
        expect(find.byKey(const Key('stage-tuner-entry')), findsOneWidget);
        await t.tap(find.byKey(const Key('stage-tuner-entry')));
        await t.pump();
        expect(hooks.tunerOpened, 1);
        await t.tap(find.byKey(const Key('stage-instr-ear')));
        await t.pumpAndSettle();
        expect(find.text('ear-screen'), findsOneWidget);
        expect(t.takeException(), isNull);
        await dispose05f(t, rig);
      },
    );

    testWidgets('05f-1g: mode label is read by Semantics', (t) async {
      final h = t.ensureSemantics();
      final rig = await denied(t);
      expect(find.bySemanticsLabel(RegExp('Dinleme kapalı')), findsWidgets);
      h.dispose();
      await dispose05f(t, rig);
    });

    testWidgets('05f-iii: after a refusal the tuning card is NOT hidden', (
      t,
    ) async {
      final hooks = Hooks05f();
      final rig = await denied(t, hooks: hooks);
      expect(find.byKey(const Key('session-tuning-gate')), findsOneWidget);
      await dispose05f(t, rig);
    });

    testWidgets(
      '05f-iii2: refusal shows Go to Settings + a visible tuner path',
      (t) async {
        final hooks = Hooks05f();
        final rig = await denied(t, hooks: hooks);
        expect(find.byKey(const Key('stage-open-settings')), findsOneWidget);
        expect(find.text('Ayarlara git'), findsOneWidget);
        // The tuning card stays, and its tune button opens the tuner.
        final card = find.byKey(const Key('session-tuning-gate-tune'));
        expect(card, findsOneWidget);
        // The mode block scrolls inside its bounded height: bring the card in.
        await t.ensureVisible(card);
        await t.pump();
        await t.tap(card);
        await t.pump();
        expect(hooks.tunerOpened, 1);
        await dispose05f(t, rig);
      },
    );
  });

  group('05f-2 Go to Settings link and its local mute', () {
    testWidgets('05f-2a: link calls the injected hook once per tap', (t) async {
      final hooks = Hooks05f();
      final rig = await denied(t, hooks: hooks);
      await t.tap(find.byKey(const Key('stage-open-settings')));
      await t.pump();
      expect(hooks.appSettingsOpened, 1);
      await dispose05f(t, rig);
    });

    testWidgets('05f-2b: Gizle hides the link; mode stays', (t) async {
      final rig = await denied(t);
      expect(find.text('Gizle'), findsOneWidget);
      await t.tap(find.byKey(const Key('stage-open-settings-mute')));
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await t.pump();
      expect(find.byKey(const Key('stage-open-settings')), findsNothing);
      expect(find.byKey(const Key('stage-listening-off')), findsOneWidget);
      await dispose05f(t, rig);
    });

    testWidgets('05f-2c: muted survives a fresh widget tree (same store)', (
      t,
    ) async {
      final store = MemoryListeningOffStore();
      final rig = await denied(t, store: store);
      await t.tap(find.byKey(const Key('stage-open-settings-mute')));
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await t.pump();
      await dispose05f(t, rig);

      final rig2 = await denied(t, store: store);
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await t.pump();
      expect(find.byKey(const Key('stage-listening-off')), findsOneWidget);
      expect(find.byKey(const Key('stage-open-settings')), findsNothing);
      await dispose05f(t, rig2);
    });

    test(
      '05f-2d: file store persists across instances, no shared_preferences',
      () async {
        final dir = await Directory.systemTemp.createTemp('ux05f');
        addTearDown(() => dir.delete(recursive: true));
        final a = FileListeningOffStore(directoryProvider: () async => dir);
        expect(await a.settingsHintMuted(), isFalse);
        await a.muteSettingsHint();
        final b = FileListeningOffStore(directoryProvider: () async => dir);
        expect(await b.settingsHintMuted(), isTrue);
        final pubspec = File('pubspec.yaml').readAsStringSync();
        expect(pubspec.contains('shared_preferences'), isFalse);
      },
    );

    testWidgets('05f-2e: link and mute are buttons, >= 48 dp', (t) async {
      final h = t.ensureSemantics();
      final rig = await denied(t);
      for (final k in ['stage-open-settings', 'stage-open-settings-mute']) {
        final f = find.byKey(Key(k));
        expect(f, findsOneWidget, reason: k);
        final s = t.getSize(f);
        expect(s.height, greaterThanOrEqualTo(48), reason: k);
        expect(s.width, greaterThanOrEqualTo(48), reason: k);
        expect(t.getSemantics(f).flagsCollection.isButton, isTrue, reason: k);
      }
      h.dispose();
      await dispose05f(t, rig);
    });
  });

  group('05f-ovf overflow', () {
    for (final size in [const Size(390, 844), const Size(360, 640)]) {
      testWidgets(
        '05f-ovf: mode at ${size.width.toInt()}x${size.height.toInt()}, text 1.3',
        (t) async {
          final rig = await denied(t, size: size, textScale: 1.3);
          expect(find.byKey(const Key('stage-listening-off')), findsOneWidget);
          expect(t.takeException(), isNull);
          await dispose05f(t, rig);
        },
      );
    }
  });
}
