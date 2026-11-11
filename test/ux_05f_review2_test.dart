// OST-UX-05f Phase E (reviewer round 2): the mode follows the real failure,
// long foreign labels, the hidden-link path, shelf bounds.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/app_locale.dart';
import 'package:ostinato/app/audio/audio_input_controller.dart';
import 'package:ostinato/app/design/ostinato_theme.dart';
import 'package:ostinato/app/practice/loop/practice_session_controller.dart';
import 'package:ostinato/app/practice/setup/setup_profile_store.dart';
import 'package:ostinato/app/stage/listening_off_store.dart';
import 'package:ostinato/app/stage/stage_home_screen.dart';
import 'package:permission_handler/permission_handler.dart';

import 'support/localized_widget_ready.dart';
import 'support/ux_05f_rig.dart';

void main() {
  late final catalog = catalog05f();
  setUpAll(prepareRootTranslations);
  setUp(resetAudioCaptureCoordinatorForTest);

  Future<Rig05f> denied(WidgetTester t, {Hooks05f? hooks}) async {
    final rig = Rig05f(permission: PermissionStatus.denied);
    await boot05f(t, stage05f(rig, catalog, hooks: hooks));
    await play05f(t);
    expect(find.byKey(const Key('stage-listening-off')), findsOneWidget);
    return rig;
  }

  group('E1 the mode follows the failure that stands', () {
    testWidgets(
      'E1a: allowed later, retry fails for ANOTHER reason -> mode closes',
      (t) async {
        final rig = await denied(t);
        rig.permission = PermissionStatus.granted;
        rig.rates.clear(); // the start now fails, but not for the permission
        await play05f(t);
        await t.pump(const Duration(milliseconds: 100));
        expect(rig.controller!.failure, isNotNull);
        expect(rig.controller!.failure, isNot('permission'));
        expect(find.byKey(const Key('stage-listening-off')), findsNothing);
        expect(find.byKey(const Key('practice-failure')), findsOneWidget);
        await dispose05f(t, rig);
      },
    );

    testWidgets('E1b: allowed later, retry starts -> mode closes', (t) async {
      final rig = await denied(t);
      rig.permission = PermissionStatus.granted;
      await play05f(t);
      await listen05f(t, rig);
      expect(rig.controller!.phase, PracticePhase.running);
      expect(find.byKey(const Key('stage-listening-off')), findsNothing);
      expect(find.byKey(const Key('practice-counts')), findsOneWidget);
      await t.pump(const Duration(milliseconds: 100));
      await dispose05f(t, rig);
    });

    testWidgets('E1c: same refusal on retry -> mode stays', (t) async {
      final rig = await denied(t);
      await play05f(t);
      expect(find.byKey(const Key('stage-listening-off')), findsOneWidget);
      expect(rig.controller!.failure, 'permission');
      await dispose05f(t, rig);
    });
  });

  group('E2 a new practice screen decides on its own', () {
    testWidgets('E2: allowed run, back, then a refusal enters the mode again', (
      t,
    ) async {
      final rig = await denied(t);
      rig.permission = PermissionStatus.granted;
      await play05f(t);
      await listen05f(t, rig); // running: mode closed
      expect(find.byKey(const Key('stage-listening-off')), findsNothing);
      await t.binding.handlePopRoute(); // back during the run: new screen
      await t.pump();
      await t.pump();
      expect(find.byKey(const Key('stage-listening-off')), findsNothing);
      rig.permission = PermissionStatus.denied;
      await play05f(t);
      expect(find.byKey(const Key('stage-listening-off')), findsOneWidget);
      await t.pump(const Duration(milliseconds: 100));
      await dispose05f(t, rig);
    });
  });

  group('E3 long foreign labels, 360x640, text 1.3, shelf open, mode on', () {
    for (final (tag, locale) in <(String, Locale)>[
      ('de', const Locale('de')),
      ('fr', const Locale('fr')),
      ('pt-BR', const Locale('pt', 'BR')),
      ('id', const Locale('id')),
      ('it', const Locale('it')),
      ('pl', const Locale('pl')),
    ]) {
      for (final control in [false, true]) {
        testWidgets('E3${control ? '-control (no mode)' : ''}: $tag', (
          t,
        ) async {
          var opened = 0;
          final rig = Rig05f(
            permission: control
                ? PermissionStatus.granted
                : PermissionStatus.denied,
          );
          t.view.physicalSize = const Size(360, 640);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.resetPhysicalSize);
          addTearDown(t.view.resetDevicePixelRatio);
          await t.pumpWidget(
            MaterialApp(
              theme: ostinatoTheme(),
              locale: locale,
              supportedLocales: appSupportedLocales,
              localizationsDelegates: appLocalizationsDelegates,
              home: MediaQuery(
                data: const MediaQueryData(
                  size: Size(360, 640),
                  textScaler: TextScaler.linear(1.3),
                ),
                child: StageHomeScreen(
                  catalog: catalog,
                  progressFactory: (_) => Mem05f(),
                  checksFactory: (_) => Checks05f(),
                  controllerFactory: rig.factory,
                  seed: 1,
                  setupStore: MemorySetupProfileStore(),
                  listeningOffStore: MemoryListeningOffStore(),
                  appSettingsOpener: () async {
                    opened++;
                    return true;
                  },
                  tunerOpener: (_) async {},
                ),
              ),
            ),
          );
          await waitForLocalizedFixture(
            t,
            languageTag: tag,
            anchor: find.byType(StageHomeScreen),
            reason: tag,
          );
          for (var i = 0; i < 4; i++) {
            await t.pump();
          }
          if (!control) {
            await play05f(t);
            expect(
              find.byKey(const Key('stage-listening-off')),
              findsOneWidget,
            );
          }
          expect(t.takeException(), isNull, reason: '$tag shelf closed');
          await t.tap(find.byKey(const Key('stage-shelf-toggle')));
          await t.pump();
          await t.pump();
          expect(t.takeException(), isNull, reason: '$tag shelf open');
          if (control) {
            await dispose05f(t, rig);
            return;
          }
          // Shelf open: the mode shows its title on the headline line only;
          // the way to Settings is in the band (shelf closed) and the layer.
          expect(
            find.byKey(const Key('stage-listening-off')),
            findsOneWidget,
            reason: tag,
          );
          expect(find.byKey(const Key('stage-open-settings')), findsNothing);
          await t.tap(find.byKey(const Key('stage-shelf-toggle')));
          await t.pump();
          await t.pump();
          expect(t.takeException(), isNull, reason: '$tag shelf closed again');
          final link = find.byKey(const Key('stage-open-settings'));
          expect(link, findsOneWidget, reason: tag);
          expect(
            (Offset.zero & const Size(360, 640)).contains(
              t.getRect(link).center,
            ),
            isTrue,
            reason: '$tag link on screen',
          );
          await t.tap(link);
          await t.pump();
          expect(opened, 1, reason: '$tag link works');
          await dispose05f(t, rig);
        });
      }
    }
  });

  group('E4 shelf open + Hide done: the permission path is in the layer', () {
    testWidgets('E4: layer mic row opens app settings', (t) async {
      final hooks = Hooks05f();
      final rig = Rig05f(permission: PermissionStatus.denied);
      await boot05f(
        t,
        stage05f(
          rig,
          catalog,
          hooks: hooks,
          micStatus: () async => PermissionStatus.denied,
        ),
        size: const Size(360, 640),
      );
      await play05f(t);
      await t.tap(find.byKey(const Key('stage-open-settings-mute')));
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await t.pump();
      await t.tap(find.byKey(const Key('stage-shelf-toggle')));
      await t.pump();
      await t.pump();
      expect(find.byKey(const Key('stage-open-settings')), findsNothing);
      await t.tap(find.byKey(const Key('stage-handle-setup')));
      await t.pump();
      await t.pump();
      await t.pump();
      await t.tap(find.byKey(const Key('stage-device-mic')));
      await t.pump();
      expect(hooks.appSettingsOpened, 1);
      await dispose05f(t, rig);
    });
  });

  group('E6 shelf bound in mode', () {
    testWidgets('E6: shelf stays inside the screen and under its bound', (
      t,
    ) async {
      final rig = await denied(t);
      await t.tap(find.byKey(const Key('stage-shelf-toggle')));
      await t.pump();
      await t.pump();
      final shelf = t.getRect(find.byKey(const Key('stage-shelf')));
      expect(shelf.top, greaterThanOrEqualTo(0));
      expect(shelf.bottom, lessThanOrEqualTo(844));
      // content bound 0.24 * height plus the toggle row
      expect(shelf.height, lessThanOrEqualTo(844 * 0.24 + 80));
      await dispose05f(t, rig);
    });
  });
}
