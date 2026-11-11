// OST-UX-05f criterion 4 + 6: the Setup / Device layer.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/audio/audio_input_controller.dart';
import 'package:ostinato/app/ostinato_release_policy.dart';
import 'package:ostinato/app/practice/setup/setup_profile_store.dart';
import 'package:permission_handler/permission_handler.dart';

import 'support/ux_05f_rig.dart';

void main() {
  late final catalog = catalog05f();
  setUp(resetAudioCaptureCoordinatorForTest);

  Future<Rig05f> open(
    WidgetTester t, {
    Hooks05f? hooks,
    PermissionStatus mic = PermissionStatus.granted,
    SetupProfileStore? setup,
    String locale = 'tr',
    Size size = const Size(390, 844),
    double textScale = 1.0,
  }) async {
    final rig = Rig05f();
    await boot05f(
      t,
      stage05f(
        rig,
        catalog,
        hooks: hooks,
        micStatus: () async => mic,
        setupStore: setup,
        locale: locale,
        textScale: textScale,
      ),
      size: size,
    );
    await t.tap(find.byKey(const Key('stage-handle-setup')));
    await t.pump();
    await t.pump();
    return rig;
  }

  testWidgets('05f-4a: Ayar opens the device layer (default config)', (
    t,
  ) async {
    final rig = await open(t);
    expect(find.byKey(const Key('stage-device-layer')), findsOneWidget);
    await dispose05f(t, rig);
  });

  group('05f-4b mic status row', () {
    for (final e in {
      PermissionStatus.granted: 'Mikrofon: verildi',
      PermissionStatus.denied: 'Mikrofon: izin yok',
      PermissionStatus.permanentlyDenied: 'Mikrofon: izin kapalı',
      PermissionStatus.restricted: 'Mikrofon: kısıtlı',
    }.entries) {
      testWidgets('05f-4b: ${e.key.name} -> ${e.value}', (t) async {
        final rig = await open(t, mic: e.key);
        await t.pump();
        expect(find.byKey(const Key('stage-device-mic')), findsOneWidget);
        expect(find.text(e.value), findsOneWidget);
        await dispose05f(t, rig);
      });
    }

    testWidgets('05f-4b-en: en copy', (t) async {
      final rig = await open(t, locale: 'en');
      await t.pump();
      expect(find.text('Microphone: allowed'), findsOneWidget);
      await dispose05f(t, rig);
    });
  });

  testWidgets('05f-4c: latency calibration row opens the setup wizard hook', (
    t,
  ) async {
    final hooks = Hooks05f();
    final rig = await open(t, hooks: hooks);
    expect(find.text('Gecikme kalibrasyonu'), findsOneWidget);
    await t.tap(find.byKey(const Key('stage-device-latency')));
    await t.pump();
    expect(hooks.setupOpened, 1);
    await dispose05f(t, rig);
  });

  testWidgets('05f-4d: room noise says "ölçülmedi" with no data', (t) async {
    final rig = await open(t);
    await t.pump();
    expect(find.text('Ortam gürültüsü: ölçülmedi'), findsOneWidget);
    await dispose05f(t, rig);
  });

  testWidgets('05f-4e: room noise read from the stored profile (quiet)', (
    t,
  ) async {
    final store = MemorySetupProfileStore(
      SetupProfile(
        room: RoomCheck(
          floorDb: -60,
          heard: true,
          at: DateTime.utc(2026, 11, 1),
        ),
      ),
    );
    final rig = await open(t, setup: store);
    await t.pump();
    expect(find.text('Ortam gürültüsü: sessiz'), findsOneWidget);
    await dispose05f(t, rig);
  });

  testWidgets('05f-4f: Settings and Account exit rows call their hooks', (
    t,
  ) async {
    final hooks = Hooks05f();
    final rig = await open(t, hooks: hooks);
    await t.tap(find.byKey(const Key('stage-device-settings')));
    await t.pump();
    expect(hooks.settingsOpened, 1);
    await t.tap(find.byKey(const Key('stage-device-account')));
    await t.pump();
    expect(hooks.accountOpened, 1);
    await dispose05f(t, rig);
  });

  testWidgets('05f-4g: the layer cannot open while playing (05c rule)', (
    t,
  ) async {
    final rig = Rig05f();
    await boot05f(
      t,
      stage05f(rig, catalog, micStatus: () async => PermissionStatus.granted),
    );
    await play05f(t);
    expect(rig.controller!.running, isTrue);
    // While a run is going the handles are gone: nothing can open a layer.
    expect(find.byKey(const Key('stage-handle-setup')), findsNothing);
    await t.pump();
    expect(find.byKey(const Key('stage-device-layer')), findsNothing);
    await t.pump(const Duration(milliseconds: 100));
    await dispose05f(t, rig);
  });

  group('05f-ovf device layer overflow + a11y', () {
    for (final size in [const Size(390, 844), const Size(360, 640)]) {
      testWidgets(
        '05f-ovf: layer at ${size.width.toInt()}x${size.height.toInt()}, text 1.3',
        (t) async {
          final rig = await open(t, size: size, textScale: 1.3);
          await t.pump();
          expect(find.byKey(const Key('stage-device-layer')), findsOneWidget);
          expect(t.takeException(), isNull);
          await dispose05f(t, rig);
        },
      );
    }

    testWidgets('05f-a11y: layer rows are >= 48 dp', (t) async {
      final rig = await open(t);
      for (final k in [
        'stage-device-latency',
        'stage-device-settings',
        'stage-device-account',
      ]) {
        final f = find.byKey(Key(k));
        expect(f, findsOneWidget, reason: k);
        expect(t.getSize(f).height, greaterThanOrEqualTo(48), reason: k);
      }
      await dispose05f(t, rig);
    });
  });

  test('05f-6: raw audio is not kept by default', () {
    expect(ostinatoRecordingRetentionOpen, isFalse);
  });
}
