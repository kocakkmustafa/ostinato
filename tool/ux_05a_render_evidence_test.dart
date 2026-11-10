// OST-UX-05a GORUNTU KANITI — "prototip/test render, sahte veri".
//
// YALNIZ OST-UX-05a KANITI, URUN TESTI DEGIL. `tool/` altindadir; CI'in
// `flutter test` kosusuna GIRMEZ. Elle kosulur:
//
//   flutter test tool/ux_05a_render_evidence_test.dart
//
// Dort PNG yazar (acik/koyu x normal/azaltilmis saydamlik):
//   docs/yula-execution/design/evidence/ux-05a/NN-<tema>-<durum>.png
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/app_theme.dart';
import 'package:ostinato/app/design/glass_layer.dart';

const String _outDir = 'docs/yula-execution/design/evidence/ux-05a';
const Size _logical = Size(390, 844);
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
}

Widget _scene(Brightness br, bool reduced, GlassLayerBudget budget) {
  return RepaintBoundary(
    key: _shot,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: OstinatoThemes.forBrightness(br),
      builder: (BuildContext context, Widget? child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(highContrast: reduced),
        child: child!,
      ),
      home: Builder(
        builder: (BuildContext context) {
          final OstinatoPalette p = OstinatoPalette.of(context);
          final TextStyle t = TextStyle(
            fontFamily: 'Hanken Grotesk',
            color: p.textBody,
            fontSize: 16,
          );
          return Scaffold(
            backgroundColor: p.shell,
            body: Stack(
              children: <Widget>[
                // Worst-case busy backdrop: hard black/white stripes.
                Positioned.fill(
                  child: Column(
                    children: <Widget>[
                      for (int i = 0; i < 28; i++)
                        Expanded(
                          child: ColoredBox(
                            color: i.isEven ? Colors.black : Colors.white,
                            child: const SizedBox.expand(),
                          ),
                        ),
                    ],
                  ),
                ),
                GlassLayer(
                  budget: budget,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Test render',
                          style: t.copyWith(
                            color: p.ink,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text('Body text over the worst backdrop.', style: t),
                        const SizedBox(height: 8),
                        Text(
                          'Muted text over the worst backdrop.',
                          style: t.copyWith(color: p.textMuted),
                        ),
                        const SizedBox(height: 16),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: p.primary,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: p.controlBorder),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            child: Text(
                              'Action',
                              style: t.copyWith(color: p.onPrimary),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}

void main() {
  final TestWidgetsFlutterBinding binding =
      TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(_loadFonts);

  setUp(() {
    binding.platformDispatcher.views.first.physicalSize = _logical * 3;
    binding.platformDispatcher.views.first.devicePixelRatio = 3;
    addTearDown(binding.platformDispatcher.views.first.resetPhysicalSize);
    addTearDown(binding.platformDispatcher.views.first.resetDevicePixelRatio);
  });

  Future<void> shot(
    WidgetTester t,
    String name,
    Brightness br,
    bool reduced,
  ) async {
    final GlassLayerBudget b = GlassLayerBudget();
    addTearDown(b.dispose);
    await t.pumpWidget(_scene(br, reduced, b));
    await t.pump(const Duration(milliseconds: 400));
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

  testWidgets(
    '01 acik normal',
    (t) => shot(t, '01-acik-normal', Brightness.light, false),
  );
  testWidgets(
    '02 acik azaltilmis',
    (t) => shot(t, '02-acik-azaltilmis', Brightness.light, true),
  );
  testWidgets(
    '03 koyu normal',
    (t) => shot(t, '03-koyu-normal', Brightness.dark, false),
  );
  testWidgets(
    '04 koyu azaltilmis',
    (t) => shot(t, '04-koyu-azaltilmis', Brightness.dark, true),
  );
}
