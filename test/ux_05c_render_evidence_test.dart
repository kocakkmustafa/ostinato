// OST-UX-05c: layer render evidence + layout assertions (fake data).
// Always pumps and asserts; writes PNGs ONLY when UX_RENDER=1:
//
//   UX_RENDER=1 flutter test test/ux_05c_render_evidence_test.dart
//
// Output: docs/yula-execution/design/evidence/ux-05c/NN-<name>-<size>-<acik|koyu>.png
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
import 'package:ostinato/app/practice/loop/v1_practice_list_screen.dart';
import 'package:ostinato/app/design/app_scope.dart';
import 'package:ostinato/app/content.dart';
import 'package:ostinato/app/cue_text.dart';
import 'package:ostinato/app/design/glass_layer.dart';
import 'package:ostinato/app/practice/setup/setup_profile_store.dart';
import 'package:ostinato/app/stage/stage_home_screen.dart';
import 'package:permission_handler/permission_handler.dart';

import 'support/localized_widget_ready.dart';

const String _outDir = 'docs/yula-execution/design/evidence/ux-05c';
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
            'prototip / test render · sahte veri · bayrak ACIK · 05c',
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
  late ContentRepository repo;
  late CueTextResolver cueText;
  setUpAll(_loadFonts);
  setUpAll(() async {
    await prepareRootTranslations();
    repo = await ContentRepository.load();
    cueText = await CueTextResolver.load();
  });
  setUp(() {
    // ignore: invalid_use_of_visible_for_testing_member
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
    Brightness br, {
    required bool png,
  }) async {
    final view = binding.platformDispatcher.views.first;
    view.physicalSize = size * 3;
    view.devicePixelRatio = 3;
    final FakeAudioCaptureChannel channel = FakeAudioCaptureChannel();
    final AudioInputController audio = AudioInputController(
      channel: channel,
      requestMicrophonePermission: () async => PermissionStatus.granted,
      pcmDeliveryTimeout: const Duration(minutes: 5),
    );
    final catalog = _catalog();
    final first = catalog.lessons.firstWhere(
      (l) => l.availability == V1LessonAvailability.measured,
    );
    await t.pumpWidget(
      _frame(
        br,
        ContentRepositoryScope(
          repo: repo,
          cueText: cueText,
          child: StageHomeScreen(
            catalog: catalog,
            progressFactory: (_) => _Memory({
              first.id: V1PracticeRecord(
                lessonId: first.id,
                runs: 2,
                bestHeard: .4,
                bestAccuracy: .9,
                lastRunAt: DateTime.utc(2026, 11, 1),
              ),
            }),
            checksFactory: (_) => _Checks(),
            paidFeaturesAvailable: false,
            seed: 1,
            earScreenBuilder: (_) => V1PracticeListScreen(
              course: 'ear',
              setupStore: MemorySetupProfileStore(),
              catalog: Future<V1CourseCatalog>.value(
                V1CourseCatalog([
                  for (final f
                      in Directory(
                          'content/v1/ear',
                        ).listSync().whereType<File>().toList()
                        ..sort((a, b) => a.path.compareTo(b.path)))
                    if (f.path.endsWith('.json'))
                      V1Lesson.fromJson(jsonDecode(f.readAsStringSync())),
                ]),
              ),
              progressFactory: (_) => _Memory(),
              checksFactory: (_) => _Checks(),
              paidFeaturesAvailable: false,
            ),
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
      ),
    );
    for (int i = 0; i < 4; i++) {
      await t.pump();
    }
    await t.tap(find.byKey(const Key('stage-handle-other')));
    await t.pumpAndSettle();
    if (state == 'katman') {
      // Layer <= 60 % and the strip area (top) >= 40 % of the screen.
      final layer = t.getRect(
        find.descendant(
          of: find.byType(GlassLayer),
          matching: find.byType(FractionallySizedBox),
        ),
      );
      expect(layer.height, lessThanOrEqualTo(size.height * 0.6 + 0.5));
      expect(layer.top, greaterThanOrEqualTo(size.height * 0.4 - 0.5));
      expect(find.byKey(const Key('stage-suggestion')), findsOneWidget);
    } else if (state == 'kulak') {
      await t.tap(find.byKey(const Key('stage-instr-ear')));
      await t.pump(const Duration(milliseconds: 600));
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await t.pump(const Duration(milliseconds: 600));
    } else {
      await t.tap(find.byKey(const Key('stage-tuner-entry')));
      await t.pump(const Duration(milliseconds: 600));
    }
    expect(t.takeException(), isNull);
    if (png) {
      await save(
        t,
        '0$no-$state-${size.width.toInt()}x${size.height.toInt()}-'
        '${br == Brightness.light ? 'acik' : 'koyu'}',
      );
    }
    await t.pumpWidget(const SizedBox());
    await t.runAsync(audio.dispose);
  }

  const states = <(String, int)>[('katman', 1), ('kulak', 2), ('akort', 3)];
  final sizes = <Size>[const Size(390, 844), const Size(360, 640)];
  for (final (String, int) s in states) {
    for (final Size size in sizes) {
      for (final Brightness br in Brightness.values) {
        testWidgets(
          '05c ${s.$1} ${size.width.toInt()}x${size.height.toInt()} ${br.name}',
          (t) => shot(t, s.$1, s.$2, size, br, png: true),
        );
      }
    }
  }
  // Layout only (no PNG): the third reference size.
  testWidgets('05c katman 412x915 layout', (t) async {
    await shot(
      t,
      'katman',
      1,
      const Size(412, 915),
      Brightness.light,
      png: false,
    );
  });
}
