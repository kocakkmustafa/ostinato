// OST-UX-05g: Hayalet Ekran (dort basamak) render kanitlari + layout assertions
// (fake data, fake mic).
// Always pumps and asserts; writes PNGs ONLY when UX_RENDER=1:
//
//   UX_RENDER=1 flutter test test/ux_05g_render_evidence_test.dart
//
// Output: docs/yula-execution/design/evidence/ux-05g/NN-<name>-<size>-<acik|koyu>.png
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/app_locale.dart';
import 'package:ostinato/app/app_theme.dart';
import 'package:ostinato/app/audio/audio_input_controller.dart';
import 'package:ostinato/app/practice/loop/v1_course_catalog.dart';
import 'package:ostinato/app/stage/ghost_policy.dart';
import 'package:ostinato/app/stage/ghost_store.dart';
import 'package:ostinato/app/stage/stage_home_screen.dart';

import 'support/localized_widget_ready.dart';
import 'support/ux_05f_rig.dart';

const String _outDir = 'docs/yula-execution/design/evidence/ux-05g';
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
            'prototip / test render · sahte veri · bayrak ACIK · 05g',
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
  late final V1CourseCatalog catalog = catalog05f();
  setUpAll(_loadFonts);
  setUpAll(prepareRootTranslations);
  setUp(() {
    resetAudioCaptureCoordinatorForTest();
    addTearDown(binding.platformDispatcher.views.first.resetPhysicalSize);
    addTearDown(binding.platformDispatcher.views.first.resetDevicePixelRatio);
  });

  // The assertions below run first; the PNG step only runs when they pass,
  // so writing files can never mask a red.
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
    GhostState state,
    String name,
    Size size,
    Brightness br, {
    Key? focus,
  }) async {
    final view = binding.platformDispatcher.views.first;
    view.physicalSize = size * 3;
    view.devicePixelRatio = 3;
    final rig = Rig05f();
    await t.pumpWidget(
      _frame(
        br,
        StageHomeScreen(
          catalog: catalog,
          progressFactory: (_) => Mem05f(),
          checksFactory: (_) => Checks05f(),
          controllerFactory: rig.factory,
          seed: 1,
          ghostOpen: true,
          ghostStore: MemoryGhostStore(state),
          tunerOpener: (_) async {},
        ),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await t.pump();
    }
    await t.tap(find.byKey(const Key('stage-shelf-toggle')));
    await t.pump();
    await t.pump();
    // ASSERT FIRST: no surface -> red, no PNG.
    expect(find.byKey(const Key('stage-help-row')), findsOneWidget);
    await t.ensureVisible(find.byKey(const Key('stage-help-row')));
    await t.pump();
    await t.tap(find.byKey(const Key('stage-help-row')));
    await t.pump();
    await t.pump();
    expect(find.byKey(const Key('ghost-help-surface')), findsOneWidget);
    expect(find.byKey(Key('ghost-level-${state.level.name}')), findsOneWidget);
    if (focus != null) {
      // ASSERT first (red if the line is missing), then scroll it into view.
      expect(find.byKey(focus), findsOneWidget);
      await Scrollable.ensureVisible(
        t.element(find.byKey(focus)),
        alignment: 1,
      );
    }
    await t.pump(const Duration(milliseconds: 300));
    expect(t.takeException(), isNull);
    await save(
      t,
      '$name-${size.width.toInt()}x${size.height.toInt()}-'
      '${br == Brightness.light ? 'acik' : 'koyu'}',
    );
    await t.pumpWidget(const SizedBox());
    await t.runAsync(rig.audio.dispose);
  }

  final sizes = <Size>[const Size(390, 844), const Size(360, 640)];
  for (final GhostLevel level in GhostLevel.values) {
    for (final Size size in sizes) {
      for (final Brightness br in Brightness.values) {
        testWidgets(
          '05g-2 render ${level.name} ${size.width.toInt()}x${size.height.toInt()} ${br.name}',
          (t) => shot(
            t,
            GhostState(
              level: level,
              validRuns: 1,
              lastRun: GhostLastRun.counted,
            ),
            '0${level.index + 1}-${level.name}',
            size,
            br,
          ),
        );
      }
    }
  }
  // 05g-5 screen evidence: "not measured" after an unreliable run, and the
  // one-step-up suggestion line.
  for (final Size size in sizes) {
    for (final Brightness br in Brightness.values) {
      final tag = '${size.width.toInt()}x${size.height.toInt()} ${br.name}';
      testWidgets(
        '05g-5 render olculmedi $tag',
        (t) => shot(
          t,
          const GhostState(lastRun: GhostLastRun.notMeasured),
          '05-olculmedi',
          size,
          br,
          focus: const Key('ghost-last-run'),
        ),
      );
      testWidgets(
        '05g-4 render oneri $tag',
        (t) => shot(
          t,
          const GhostState(
            level: GhostLevel.reinforce,
            validRuns: 2,
            lastRun: GhostLastRun.counted,
          ),
          '06-oneri',
          size,
          br,
          focus: const Key('ghost-suggestion'),
        ),
      );
    }
  }
}
