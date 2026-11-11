// OST-UX-05b2 GORUNTU KANITI — "prototip/test render, sahte veri".
//
// YALNIZ OST-UX-05b2 KANITI, URUN TESTI DEGIL. `tool/` altindadir; CI'in
// `flutter test` kosusuna GIRMEZ. Elle kosulur:
//
//   flutter test tool/ux_05b2_render_evidence_test.dart
//
// Bayrak ACIK sahnede Cal'in ilk ekranda gorundugunu 3 boyut x raf
// kapali/acik (acik tema) gosterir; yazar: docs/yula-execution/design/evidence/ux-05b2/NN-<ad>-<acik|koyu>.png
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/app_locale.dart';
import 'package:ostinato/app/app_theme.dart';
import 'package:ostinato/app/audio/audio_capture_channel.dart';
import 'package:ostinato/app/audio/audio_input_controller.dart';
import 'package:ostinato/app/curriculum/v1_lesson.dart';
import 'package:ostinato/app/practice/loop/practice_judge.dart';
import 'package:ostinato/app/practice/loop/practice_outcome.dart';
import 'package:ostinato/app/practice/loop/practice_progress_store.dart';
import 'package:ostinato/app/practice/loop/practice_session_controller.dart';
import 'package:ostinato/app/practice/loop/v1_course_catalog.dart';
import 'package:ostinato/app/stage/stage_home_screen.dart';
import 'package:permission_handler/permission_handler.dart';

import '../test/support/localized_widget_ready.dart';

const String _outDir = 'docs/yula-execution/design/evidence/ux-05b2';
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

final class _Memory implements V1PracticeProgress {
  _Memory([Map<String, V1PracticeRecord>? seed]) : records = {...?seed};
  final Map<String, V1PracticeRecord> records;
  @override
  Future<Map<String, V1PracticeRecord>> load() async => Map.of(records);
  @override
  Future<V1PracticeRecord> recordRun(
    String id,
    PracticeRunSummary s, {
    DateTime? at,
  }) async => records[id] = (records[id] ?? V1PracticeRecord(lessonId: id))
      .withRun(s, DateTime.utc(2026, 11, 1));
}

final class _Checks implements V1LessonChecks {
  @override
  Future<Map<String, V1LessonCheck>> load() async => {};
  @override
  Future<V1LessonCheck> record(
    String lessonId,
    V1CheckEvidence evidence, {
    DateTime? at,
  }) => throw UnimplementedError();
}

V1CourseCatalog _catalog() => V1CourseCatalog([
  for (final f
      in Directory('content/v1/gtr').listSync().whereType<File>().toList()
        ..sort((a, b) => a.path.compareTo(b.path)))
    if (f.path.endsWith('.json'))
      V1Lesson.fromJson(jsonDecode(f.readAsStringSync())),
]);

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
            'prototip / test render · sahte veri · bayrak ACIK · 05b2',
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
  setUpAll(_loadFonts);
  setUpAll(prepareRootTranslations);
  setUp(() {
    // ignore: invalid_use_of_visible_for_testing_member
    resetAudioCaptureCoordinatorForTest();
    addTearDown(binding.platformDispatcher.views.first.resetPhysicalSize);
    addTearDown(binding.platformDispatcher.views.first.resetDevicePixelRatio);
    addTearDown(binding.platformDispatcher.clearTextScaleFactorTestValue);
  });

  Future<void> save(WidgetTester t, String name) async {
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
    String name,
    Size size,
    double scale,
    bool shelf,
  ) async {
    final view = binding.platformDispatcher.views.first;
    view.physicalSize = size * 3;
    view.devicePixelRatio = 3;
    binding.platformDispatcher.textScaleFactorTestValue = scale;
    final FakeAudioCaptureChannel channel = FakeAudioCaptureChannel();
    final AudioInputController audio = AudioInputController(
      channel: channel,
      requestMicrophonePermission: () async => PermissionStatus.granted,
      pcmDeliveryTimeout: const Duration(minutes: 5),
    );
    await t.pumpWidget(
      _frame(
        Brightness.light,
        StageHomeScreen(
          catalog: _catalog(),
          progressFactory: (_) => _Memory(),
          checksFactory: (_) => _Checks(),
          paidFeaturesAvailable: false,
          seed: 1,
          controllerFactory: (score, tempo, criteria) =>
              PracticeSessionController(
                score: score,
                tempo: tempo,
                audio: audio,
                criteria: criteria,
                localClockUs: () => 0,
                analyzer: (r) async => judgeNote(r),
              ),
        ),
      ),
    );
    for (int i = 0; i < 4; i++) {
      await t.pump();
    }
    if (shelf) {
      await t.tap(find.byKey(const Key('stage-shelf-toggle')));
      await t.pump();
      await t.pump();
    }
    expect(
      find.byKey(const Key('practice-start')).hitTestable(),
      findsOneWidget,
    );
    await save(t, name);
    await t.pumpWidget(const SizedBox());
    await t.runAsync(audio.dispose);
  }

  final List<(String, Size, double)> sizes = <(String, Size, double)>[
    ('390x844', const Size(390, 844), 1.0),
    ('360x640', const Size(360, 640), 1.0),
    ('360x640-yazi13', const Size(360, 640), 1.3),
  ];
  for (final (String, Size, double) c in sizes) {
    for (final bool open in <bool>[false, true]) {
      final String state = open ? 'raf-acik' : 'raf-kapali';
      testWidgets(
        'cal ilk ekranda ${c.$1} $state',
        (t) => shot(t, 'cal-${c.$1}-$state-acik', c.$2, c.$3, open),
      );
    }
  }
}
