// OST-UX-05f Phase D (reviewer round 1): honest copy, tappable permission
// path, lifecycle, real exits, layout, semantics and "read only" proofs.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/content.dart';
import 'package:ostinato/app/cue_text.dart';
import 'package:ostinato/app/design/app_scope.dart';
import 'package:ostinato/app/audio/audio_input_controller.dart';
import 'package:ostinato/app/audio/mic_permission_gate.dart';
import 'package:ostinato/app/practice/setup/setup_profile_store.dart';
import 'package:ostinato/app/practice/setup/setup_wizard_screen.dart';
import 'package:ostinato/app/screens/settings_screen.dart';
import 'package:permission_handler/permission_handler.dart';

import 'support/ux_05f_rig.dart';

const _sizes = <Size>[Size(390, 844), Size(360, 640)];

void main() {
  late final catalog = catalog05f();
  late ContentRepository repo;
  late CueTextResolver cueText;
  setUpAll(() async {
    repo = await ContentRepository.load();
    cueText = await CueTextResolver.load();
  });
  setUp(resetAudioCaptureCoordinatorForTest);

  Future<Rig05f> deniedStage(
    WidgetTester t, {
    Hooks05f? hooks,
    Future<PermissionStatus> Function()? micStatus,
    Size size = const Size(390, 844),
    double scale = 1.0,
    String locale = 'tr',
    SetupProfileStore? setup,
    bool realOpeners = false,
  }) async {
    final rig = Rig05f(permission: PermissionStatus.denied);
    await boot05f(
      t,
      stage05f(
        rig,
        catalog,
        hooks: hooks,
        micStatus: micStatus,
        textScale: scale,
        locale: locale,
        setupStore: setup,
        realOpeners: realOpeners,
      ),
      size: size,
    );
    await play05f(t);
    return rig;
  }

  Future<void> settle(WidgetTester t) async {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await t.pump();
    await t.pump();
  }

  Future<void> resume(WidgetTester t) async {
    final b = t.binding;
    b.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    b.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    b.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle(t);
  }

  Future<void> openLayer(WidgetTester t) async {
    await t.tap(find.byKey(const Key('stage-handle-setup')));
    await t.pump();
    await t.pump();
    await t.pump();
  }

  group('D-R1 honest listening-off text', () {
    testWidgets('D-R1a: tr text says the tuner needs the microphone', (
      t,
    ) async {
      final rig = await deniedStage(t);
      expect(
        find.text(
          'Mikrofon izni verilmediği için ölçüm yapılmıyor. '
          'Metronom ve referans çalışır; akortçu mikrofon ister.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('akortçu çalışır'), findsNothing);
      await dispose05f(t, rig);
    });

    testWidgets('D-R1b: en text says the tuner needs the microphone', (
      t,
    ) async {
      final rig = await deniedStage(t, locale: 'en');
      expect(
        find.text(
          'The microphone is not allowed, so nothing is measured. '
          'The metronome and the reference work; the tuner needs the microphone.',
        ),
        findsOneWidget,
      );
      await dispose05f(t, rig);
    });

    testWidgets('D-R1c: tuning card and Go to Settings are both in view', (
      t,
    ) async {
      final rig = await deniedStage(t);
      const screen = Rect.fromLTWH(0, 0, 390, 844);
      for (final k in ['session-tuning-gate', 'stage-open-settings']) {
        final f = find.byKey(Key(k));
        expect(f, findsOneWidget, reason: k);
        final r = t.getRect(f);
        expect(screen.contains(r.center), isTrue, reason: '$k on screen');
      }
      await dispose05f(t, rig);
    });
  });

  group('D-R2 neutral mic row wording', () {
    testWidgets('D-R2: no blaming "reddedil" word in the layer', (t) async {
      for (final s in [
        PermissionStatus.denied,
        PermissionStatus.permanentlyDenied,
        PermissionStatus.restricted,
      ]) {
        final rig = Rig05f();
        await boot05f(t, stage05f(rig, catalog, micStatus: () async => s));
        await openLayer(t);
        expect(find.textContaining('reddedil'), findsNothing, reason: '$s');
        await dispose05f(t, rig);
      }
    });
  });

  group('D-R3 microphone row is a way to Settings', () {
    testWidgets('D-R3a: not allowed -> the mic row opens app settings', (
      t,
    ) async {
      final hooks = Hooks05f();
      final rig = Rig05f();
      await boot05f(
        t,
        stage05f(
          rig,
          catalog,
          hooks: hooks,
          micStatus: () async => PermissionStatus.denied,
        ),
      );
      await openLayer(t);
      expect(find.text('Ayarlara git'), findsWidgets);
      await t.tap(find.byKey(const Key('stage-device-mic')));
      await t.pump();
      expect(hooks.appSettingsOpened, 1);
      await dispose05f(t, rig);
    });

    testWidgets('D-R3b: allowed -> the mic row is not a button', (t) async {
      final hooks = Hooks05f();
      final rig = Rig05f();
      await boot05f(
        t,
        stage05f(
          rig,
          catalog,
          hooks: hooks,
          micStatus: () async => PermissionStatus.granted,
        ),
      );
      await openLayer(t);
      await t.tap(find.byKey(const Key('stage-device-mic')));
      await t.pump();
      expect(hooks.appSettingsOpened, 0);
      expect(find.text('Ayarlara git'), findsNothing);
      await dispose05f(t, rig);
    });

    testWidgets('D-R3c: after Gizle the layer still reaches app settings', (
      t,
    ) async {
      final hooks = Hooks05f();
      final rig = await deniedStage(
        t,
        hooks: hooks,
        micStatus: () async => PermissionStatus.denied,
      );
      await t.tap(find.byKey(const Key('stage-open-settings-mute')));
      await settle(t);
      expect(find.byKey(const Key('stage-open-settings')), findsNothing);
      await openLayer(t);
      await t.tap(find.byKey(const Key('stage-device-mic')));
      await t.pump();
      expect(hooks.appSettingsOpened, 1);
      await dispose05f(t, rig);
    });
  });

  group('D-R4 lifecycle', () {
    testWidgets('D-R4a: resume with the microphone allowed closes the mode', (
      t,
    ) async {
      var status = PermissionStatus.denied;
      final rig = await deniedStage(t, micStatus: () async => status);
      expect(find.byKey(const Key('stage-listening-off')), findsOneWidget);
      status = PermissionStatus.granted;
      await resume(t);
      expect(find.byKey(const Key('stage-listening-off')), findsNothing);
      expect(find.byKey(const Key('practice-counts')), findsOneWidget);
      await dispose05f(t, rig);
    });

    testWidgets('D-R4b: resume still not allowed keeps the mode', (t) async {
      final rig = await deniedStage(
        t,
        micStatus: () async => PermissionStatus.denied,
      );
      await resume(t);
      expect(find.byKey(const Key('stage-listening-off')), findsOneWidget);
      await dispose05f(t, rig);
    });

    testWidgets('D-R4c: an open layer follows the new state on resume', (
      t,
    ) async {
      var status = PermissionStatus.denied;
      final rig = await deniedStage(t, micStatus: () async => status);
      await openLayer(t);
      expect(find.text('Mikrofon: izin yok'), findsOneWidget);
      status = PermissionStatus.granted;
      await resume(t);
      expect(find.text('Mikrofon: verildi'), findsOneWidget);
      expect(find.text('Mikrofon: izin yok'), findsNothing);
      expect(find.byKey(const Key('stage-listening-off')), findsNothing);
      await dispose05f(t, rig);
    });

    testWidgets('D-R4d: retry keeps the mode without a flicker', (t) async {
      final rig = await deniedStage(t);
      await t.tap(find.byKey(const Key('practice-start')));
      for (var i = 0; i < 8; i++) {
        await t.pump();
        expect(
          find.byKey(const Key('stage-listening-off')),
          findsOneWidget,
          reason: 'pump $i',
        );
        expect(
          find.byKey(const Key('practice-count-correct')),
          findsNothing,
          reason: 'counters must not show at pump $i',
        );
      }
      await t.pump(const Duration(milliseconds: 100));
      await dispose05f(t, rig);
    });
  });

  group('D-R5 real exits (no fake openers)', () {
    testWidgets('D-R5a: the Settings row opens the real SettingsScreen', (
      t,
    ) async {
      final rig = Rig05f();
      await boot05f(
        t,
        stage05f(
          rig,
          catalog,
          realOpeners: true,
          wrap: (w) =>
              ContentRepositoryScope(repo: repo, cueText: cueText, child: w),
          micStatus: () async => PermissionStatus.granted,
        ),
      );
      await openLayer(t);
      await t.tap(find.byKey(const Key('stage-device-settings')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(find.byType(SettingsScreen), findsOneWidget);
      await dispose05f(t, rig);
    });

    testWidgets('D-R5b: the latency row opens the real setup wizard', (
      t,
    ) async {
      final rig = Rig05f();
      await boot05f(
        t,
        stage05f(
          rig,
          catalog,
          realOpeners: true,
          micStatus: () async => PermissionStatus.granted,
        ),
      );
      await openLayer(t);
      await t.tap(find.byKey(const Key('stage-device-latency')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(find.byType(SetupWizardScreen), findsOneWidget);
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      await dispose05f(t, rig);
    });

    testWidgets('D-R5c: no account connection -> no Account row', (t) async {
      final rig = Rig05f();
      await boot05f(
        t,
        stage05f(
          rig,
          catalog,
          realOpeners: true,
          micStatus: () async => PermissionStatus.granted,
        ),
      );
      await openLayer(t);
      expect(find.byKey(const Key('stage-device-account')), findsNothing);
      await dispose05f(t, rig);
    });
  });

  group('D-R6 layout and reach', () {
    for (final size in _sizes) {
      final tag = '${size.width.toInt()}x${size.height.toInt()}';
      testWidgets('D-R6a: $tag @1.3 shelf open: link visible and works', (
        t,
      ) async {
        final hooks = Hooks05f();
        final rig = await deniedStage(t, hooks: hooks, size: size, scale: 1.3);
        await t.tap(find.byKey(const Key('stage-shelf-toggle')));
        await t.pump();
        await t.pump();
        expect(t.takeException(), isNull);
        final link = find.byKey(const Key('stage-open-settings'));
        expect(link, findsOneWidget);
        expect((Offset.zero & size).contains(t.getRect(link).center), isTrue);
        await t.tap(link);
        await t.pump();
        expect(hooks.appSettingsOpened, 1);
        final start = find.byKey(const Key('practice-start'));
        expect((Offset.zero & size).contains(t.getRect(start).center), isTrue);
        await dispose05f(t, rig);
      });

      testWidgets('D-R6b: $tag @1.3 mode + shelf open + Setup layer', (
        t,
      ) async {
        final rig = await deniedStage(
          t,
          size: size,
          scale: 1.3,
          micStatus: () async => PermissionStatus.denied,
        );
        await t.tap(find.byKey(const Key('stage-shelf-toggle')));
        await t.pump();
        await t.pump();
        await t.tap(find.byKey(const Key('stage-handle-setup')));
        await t.pump();
        await t.pump();
        await t.pump();
        expect(t.takeException(), isNull);
        expect(find.byKey(const Key('stage-device-layer')), findsOneWidget);
        await dispose05f(t, rig);
      });

      testWidgets('D-R6c: $tag @1.3 mode closed shelf: Play works again', (
        t,
      ) async {
        final rig = await deniedStage(t, size: size, scale: 1.3);
        final before = rig.permissionCalls;
        await play05f(t);
        expect(t.takeException(), isNull);
        expect(rig.permissionCalls, greaterThan(before));
        expect(find.byKey(const Key('stage-listening-off')), findsOneWidget);
        await dispose05f(t, rig);
      });
    }
  });

  group('D-R7 layer semantics and refresh', () {
    testWidgets('D-R7a: a layer row is ONE button node with its label', (
      t,
    ) async {
      final h = t.ensureSemantics();
      final rig = Rig05f();
      await boot05f(
        t,
        stage05f(rig, catalog, micStatus: () async => PermissionStatus.granted),
      );
      await openLayer(t);
      // The layer fades in (Opacity 0 drops semantics): let it finish.
      await t.pump(const Duration(milliseconds: 500));
      for (final label in ['Gecikme kalibrasyonu', 'Ayarlar', 'Hesap']) {
        final byLabel = find.bySemanticsLabel(label);
        expect(byLabel, findsOneWidget, reason: label);
        final node = t.getSemantics(byLabel);
        expect(node.label, label, reason: label);
        expect(node.flagsCollection.isButton, isTrue, reason: label);
      }
      h.dispose();
      await dispose05f(t, rig);
    });

    testWidgets('D-R7b: room noise refreshes after the wizard returns', (
      t,
    ) async {
      final store = MemorySetupProfileStore();
      final hooks = Hooks05f()
        ..onSetup = () async {
          store.profile = SetupProfile(
            room: RoomCheck(
              floorDb: -60,
              heard: true,
              at: DateTime.utc(2026, 11, 1),
            ),
          );
        };
      final rig = Rig05f();
      await boot05f(
        t,
        stage05f(
          rig,
          catalog,
          hooks: hooks,
          setupStore: store,
          micStatus: () async => PermissionStatus.granted,
        ),
      );
      await openLayer(t);
      expect(find.text('Ortam gürültüsü: ölçülmedi'), findsOneWidget);
      await t.tap(find.byKey(const Key('stage-device-latency')));
      await settle(t);
      expect(find.text('Ortam gürültüsü: sessiz'), findsOneWidget);
      await dispose05f(t, rig);
    });
  });

  group('D-R11 read only', () {
    testWidgets('D-R11: layer, resume and mode never ask for the microphone', (
      t,
    ) async {
      var requests = 0;
      final originalRequest = MicPermissionGate.request;
      addTearDown(() => MicPermissionGate.request = originalRequest);
      MicPermissionGate.request = () async {
        requests++;
        return PermissionStatus.denied;
      };
      final rig = await deniedStage(
        t,
        micStatus: () async => PermissionStatus.denied,
      );
      final asked = rig.permissionCalls;
      final askedGate = requests; // Play's own request is not counted
      await openLayer(t);
      await resume(t);
      expect(requests, askedGate);
      expect(rig.permissionCalls, asked);
      await dispose05f(t, rig);
    });
  });
}
