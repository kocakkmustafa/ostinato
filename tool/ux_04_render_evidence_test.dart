// OST-UX-04 GÖRÜNTÜ KANITI — "test render, sahte veri".
//
// YALNIZ OST-UX-04 KANITI, ÜRÜN TESTİ DEĞİL. `tool/` altındadır; CI'ın
// `flutter test` koşusuna GİRMEZ. Elle koşulur:
//
//   flutter test tool/ux_04_render_evidence_test.dart
//
// Yedi yolculuğu prototip ekranından 390x844 @3x mantığıyla çizer ve PNG yazar:
//   docs/yula-execution/design/evidence/ux-04/NN-<yolculuk>.png
// Yöntem `tool/ux_01_render_evidence_test.dart` ile aynı. Ağ, hesap, define,
// mikrofon, kamera yok; bayrakların hepsi varsayılan (KAPALI).
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/app_locale.dart';
import 'package:ostinato/app/app_theme.dart';
import 'package:ostinato/app/app_translation_catalog.dart';
import 'package:ostinato/app/curriculum/v1_lesson.dart';
import 'package:ostinato/app/design/ostinato_theme.dart'
    show ostinatoAppBuilder;
import 'package:ostinato/app/practice/loop/v1_course_catalog.dart';
import 'package:ostinato/app/ux_prototype/ux_prototype_model.dart';
import 'package:ostinato/app/ux_prototype/ux_prototype_screen.dart';

const String _outDir = 'docs/yula-execution/design/evidence/ux-04';
const Size _logical = Size(390, 844);
const double _dpr = 3.0;
const double _outScale = 1.5;
const Duration _step = Duration(milliseconds: 50);
final GlobalKey _shot = GlobalKey();

Future<void> _loadFonts() async {
  Future<void> family(String name, List<String> files) async {
    final FontLoader l = FontLoader(name);
    for (final String f in files) {
      final Uint8List b = File(f).readAsBytesSync();
      l.addFont(Future<ByteData>.value(ByteData.sublistView(b)));
    }
    await l.load();
  }

  await family('Hanken Grotesk', <String>[
    'assets/fonts/HankenGrotesk-Regular.ttf',
    'assets/fonts/HankenGrotesk-Medium.ttf',
    'assets/fonts/HankenGrotesk-SemiBold.ttf',
  ]);
  await family('IBM Plex Mono', <String>[
    'assets/fonts/IBMPlexMono-Medium.ttf',
  ]);
}

Widget _app(Widget home) => RepaintBoundary(
  key: _shot,
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: OstinatoThemes.light,
    themeMode: ThemeMode.light,
    locale: const Locale('en'),
    supportedLocales: appSupportedLocales,
    localizationsDelegates: appLocalizationsDelegates,
    builder: ostinatoAppBuilder,
    home: home,
  ),
);

Future<void> _settle(WidgetTester t) async {
  for (int i = 0; i < 12; i++) {
    await t.pump();
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 2)),
    );
  }
  await t.pump(const Duration(milliseconds: 600));
}

Future<void> _snap(WidgetTester t, String name) async {
  await _settle(t);
  await t.runAsync(() async {
    final RenderRepaintBoundary b = t.renderObject<RenderRepaintBoundary>(
      find.byKey(_shot),
    );
    final ui.Image img = await b.toImage(pixelRatio: _outScale);
    final ByteData? data = await img.toByteData(format: ui.ImageByteFormat.png);
    Directory(_outDir).createSync(recursive: true);
    File('$_outDir/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
    // ignore: avoid_print
    print('RENDER $name.png ${img.width}x${img.height}');
  });
}

Future<void> _tap(WidgetTester t, String key) async {
  final Finder f = find.byKey(Key(key));
  await t.ensureVisible(f);
  await t.tap(f);
  await _settle(t);
}

Future<void> _playToEnd(WidgetTester t) async {
  await t.tap(find.byKey(const Key('ux-play')));
  await t.pump();
  for (int i = 0; i < 12; i++) {
    await t.pump(_step);
  }
  await _settle(t);
}

void main() {
  final TestWidgetsFlutterBinding binding =
      TestWidgetsFlutterBinding.ensureInitialized();
  late V1CourseCatalog course;

  setUpAll(() async {
    await _loadFonts();
    for (final String tag in supportedLanguageTags) {
      await const AppTranslationsDelegate().load(localeForLanguageTag(tag));
    }
    course = V1CourseCatalog(<V1Lesson>[
      for (final FileSystemEntity f in Directory('content/v1/gtr').listSync())
        if (f is File && f.path.endsWith('.json'))
          V1Lesson.fromJson(
            jsonDecode(f.readAsStringSync()) as Map<String, dynamic>,
          ),
    ]);
  });

  setUp(() {
    binding.platformDispatcher.views.first.physicalSize = _logical * _dpr;
    binding.platformDispatcher.views.first.devicePixelRatio = _dpr;
    addTearDown(binding.platformDispatcher.views.first.resetPhysicalSize);
    addTearDown(binding.platformDispatcher.views.first.resetDevicePixelRatio);
  });

  Widget screen({UxMic mic = UxMic.ready}) => _app(
    UxPrototypeScreen(
      initialMic: mic,
      stepDuration: _step,
      catalog: Future<V1CourseCatalog>.value(course),
    ),
  );

  testWidgets('01 pratige basla', (WidgetTester t) async {
    await t.pumpWidget(screen());
    await _snap(t, '01-pratige-basla');
  });

  testWidgets('02 enstrumansiz calisma', (WidgetTester t) async {
    await t.pumpWidget(screen());
    await _tap(t, 'ux-handle-other');
    await _tap(t, 'ux-other-ear');
    await _tap(t, 'ux-ear-listen');
    await _tap(t, 'ux-ear-lower');
    await _snap(t, '02-enstrumansiz-calisma');
  });

  testWidgets('03 ogrenme yolculugu', (WidgetTester t) async {
    await t.pumpWidget(screen());
    await _tap(t, 'ux-handle-path');
    await _snap(t, '03-ogrenme-yolculugu');
  });

  testWidgets('04 hata anlama', (WidgetTester t) async {
    await t.pumpWidget(screen());
    await _playToEnd(t);
    await _snap(t, '04-hata-anlama');
  });

  testWidgets('05 tekrar', (WidgetTester t) async {
    await t.pumpWidget(screen());
    await _playToEnd(t);
    await _tap(t, 'ux-loop-bar');
    await _snap(t, '05-tekrar');
  });

  testWidgets('06 ilerleme gecmisi', (WidgetTester t) async {
    await t.pumpWidget(screen());
    await _playToEnd(t);
    await _tap(t, 'ux-layer-close');
    await _tap(t, 'ux-handle-path');
    await _tap(t, 'ux-tab-history');
    await _snap(t, '06-ilerleme-gecmisi');
  });

  testWidgets('07 izin reddi', (WidgetTester t) async {
    await t.pumpWidget(screen(mic: UxMic.denied));
    await _snap(t, '07-izin-reddi');
  });
}
