// OST-UX-05f: stage render evidence + layout assertions (fake data, fake mic).
// Always pumps and asserts; writes PNGs ONLY when UX_RENDER=1:
//
//   UX_RENDER=1 flutter test test/ux_05f_render_evidence_test.dart
//
// Output: docs/yula-execution/design/evidence/ux-05f/NN-<name>-<size>-<acik|koyu>.png
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/app_locale.dart';
import 'package:ostinato/app/app_theme.dart';
import 'package:ostinato/app/audio/audio_input_controller.dart';
import 'package:ostinato/app/practice/setup/setup_profile_store.dart';
import 'package:ostinato/app/stage/listening_off_store.dart';
import 'package:ostinato/app/stage/stage_home_screen.dart';
import 'package:permission_handler/permission_handler.dart';

import 'support/localized_widget_ready.dart';
import 'support/ux_05f_rig.dart';

const String _outDir = 'docs/yula-execution/design/evidence/ux-05f';
final bool _write = Platform.environment['UX_RENDER'] == '1';
final GlobalKey _shot = GlobalKey();

Future<void> _loadFonts() async {
  final FontLoader l = FontLoader('Hanken Grotesk');
  for (final String f in <String>[
    'assets/fonts/HankenGrotesk-Regular.ttf',
    'assets/fonts/HankenGrotesk-SemiBold.ttf',
  ]) {
    final Uint8List b = File(f).readAsBytesSync();
    l.addFont(Future<ByteData>.value(ByteData.sublistView(b)));
  }
  await l.load();
  final String? flutterRoot = Platform.environment['FLUTTER_ROOT'];
  final File icons = File(
    '${flutterRoot ?? ''}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (icons.existsSync()) {
    final FontLoader m = FontLoader('MaterialIcons');
    m.addFont(
      Future<ByteData>.value(ByteData.sublistView(icons.readAsBytesSync())),
    );
    await m.load();
  }
}

Widget _frame(Brightness br, Widget home) => RepaintBoundary(
  key: _shot,
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: OstinatoThemes.forBrightness(br),
    locale: const Locale('tr'),
    supportedLocales: appSupportedLocales,
    localizationsDelegates: appLocalizationsDelegates,
    builder: (BuildContext context, Widget? child) => Column(
      children: <Widget>[
        Container(
          width: double.infinity,
          color: const Color(0xFFB00020),
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: const Text(
            'prototip / test render · sahte veri · bayrak ACIK · 05f',
            textAlign: TextAlign.center,
            textDirection: TextDirection.ltr,
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              decoration: TextDecoration.none,
            ),
          ),
        ),
        Expanded(child: child!),
      ],
    ),
    home: home,
  ),
);

void main() {
  final TestWidgetsFlutterBinding binding =
      TestWidgetsFlutterBinding.ensureInitialized();
  late final catalog = catalog05f();
  setUpAll(_loadFonts);
  setUpAll(prepareRootTranslations);
  setUp(() {
    resetAudioCaptureCoordinatorForTest();
    addTearDown(binding.platformDispatcher.views.first.resetPhysicalSize);
    addTearDown(binding.platformDispatcher.views.first.resetDevicePixelRatio);
  });

  Future<void> save(WidgetTester t, String name) async {
    if (!_write) return;
    await t.runAsync(() async {
      final RenderRepaintBoundary rb = t.renderObject<RenderRepaintBoundary>(
        find.byKey(_shot),
      );
      final ui.Image img = await rb.toImage(pixelRatio: 1.5);
      final ByteData? d = await img.toByteData(format: ui.ImageByteFormat.png);
      Directory(_outDir).createSync(recursive: true);
      File('$_outDir/$name.png').writeAsBytesSync(d!.buffer.asUint8List());
      // ignore: avoid_print
      print('RENDER $name.png ${img.width}x${img.height}');
    });
  }

  Future<void> shot(
    WidgetTester t,
    String state,
    int no,
    Size size,
    Brightness br,
  ) async {
    final view = binding.platformDispatcher.views.first;
    view.physicalSize = size * 3;
    view.devicePixelRatio = 3;
    final rig = Rig05f(
      permission: state.startsWith('izin-reddi')
          ? PermissionStatus.denied
          : PermissionStatus.granted,
    );
    await t.pumpWidget(
      _frame(
        br,
        StageHomeScreen(
          catalog: catalog,
          progressFactory: (_) => Mem05f(),
          checksFactory: (_) => Checks05f(),
          controllerFactory: rig.factory,
          seed: 1,
          setupStore: MemorySetupProfileStore(),
          micStatus: () async => PermissionStatus.denied,
          listeningOffStore: MemoryListeningOffStore(),
          appSettingsOpener: () async => true,
          tunerOpener: (_) async {},
        ),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await t.pump();
    }
    if (state.startsWith('izin-reddi')) {
      await t.tap(find.byKey(const Key('practice-start')));
      await t.pump();
      await t.pump();
      await t.pump(const Duration(milliseconds: 50));
      expect(find.byKey(const Key('stage-listening-off')), findsOneWidget);
      expect(find.text('Dinleme kapalı'), findsOneWidget);
      if (state == 'izin-reddi-raf-acik') {
        // tool shelf open: compact mode (title on the headline line)
        await t.tap(find.byKey(const Key('stage-shelf-toggle')));
        await t.pump();
        await t.pump();
      } else {
        expect(find.byKey(const Key('stage-open-settings')), findsOneWidget);
        expect(find.byKey(const Key('session-tuning-gate')), findsOneWidget);
      }
      if (state == 'izin-reddi-sayac') {
        // the counter line of the microphone strip, scrolled into view
        final counter = find.byKey(const Key('stage-listening-off-counter'));
        await t.ensureVisible(counter);
        await t.pump();
      }
      if (state != 'izin-reddi-raf-acik') {
        expect(
          (t.widget(find.byKey(const Key('stage-listening-off-counter')))
                  as Text)
              .data,
          contains('ölçülmüyor'),
        );
      }
    } else if (state == 'ayar-cihaz') {
      await t.tap(find.byKey(const Key('stage-handle-setup')));
      await t.pump();
      await t.pump();
      await t.pump();
      expect(find.byKey(const Key('stage-device-layer')), findsOneWidget);
    } else {
      expect(find.byKey(const Key('practice-start')), findsOneWidget);
    }
    await t.pump(const Duration(milliseconds: 300));
    expect(t.takeException(), isNull);
    await save(
      t,
      '0$no-$state-${size.width.toInt()}x${size.height.toInt()}-'
      '${br == Brightness.light ? 'acik' : 'koyu'}',
    );
    await t.pumpWidget(const SizedBox());
    await t.runAsync(rig.audio.dispose);
  }

  const states = <(String, int)>[
    ('sahne', 1),
    ('izin-reddi', 2),
    ('ayar-cihaz', 3),
    ('izin-reddi-raf-acik', 4),
    ('izin-reddi-sayac', 5),
  ];
  final sizes = <Size>[const Size(390, 844), const Size(360, 640)];
  for (final (String, int) s in states) {
    for (final Size size in sizes) {
      for (final Brightness br in Brightness.values) {
        testWidgets(
          '05f ${s.$1} ${size.width.toInt()}x${size.height.toInt()} ${br.name}',
          (t) => shot(t, s.$1, s.$2, size, br),
        );
      }
    }
  }
}
