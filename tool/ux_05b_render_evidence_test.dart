// OST-UX-05b GORUNTU KANITI — "prototip/test render, sahte veri".
//
// YALNIZ OST-UX-05b KANITI, URUN TESTI DEGIL. `tool/` altindadir; CI'in
// `flutter test` kosusuna GIRMEZ. Elle kosulur:
//
//   flutter test tool/ux_05b_render_evidence_test.dart
//
// Bayrak ACIK (sahne) ekranlarini ve bayrak KAPALI eski koku, acik/koyu
// yazar: docs/yula-execution/design/evidence/ux-05b/NN-<ad>-<acik|koyu>.png
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/app_locale.dart';
import 'package:ostinato/app/app_theme.dart';
import 'package:ostinato/app/audio/audio_capture_channel.dart';
import 'package:ostinato/app/audio/audio_input_controller.dart';
import 'package:ostinato/app/content.dart';
import 'package:ostinato/app/cue_text.dart';
import 'package:ostinato/app/curriculum/v1_lesson.dart';
import 'package:ostinato/app/design/app_scope.dart';
import 'package:ostinato/app/onboarding_store.dart';
import 'package:ostinato/app/practice/loop/practice_judge.dart';
import 'package:ostinato/app/practice/loop/practice_outcome.dart';
import 'package:ostinato/app/practice/loop/practice_progress_store.dart';
import 'package:ostinato/app/practice/loop/practice_session_controller.dart';
import 'package:ostinato/app/practice/loop/v1_course_catalog.dart';
import 'package:ostinato/app/stage/stage_home_screen.dart';
import 'package:ostinato/main.dart';
import 'package:permission_handler/permission_handler.dart';

import '../test/support/localized_widget_ready.dart';

const String _outDir = 'docs/yula-execution/design/evidence/ux-05b';
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
            'prototip / test render · sahte veri · bayrak ACIK',
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
    binding.platformDispatcher.views.first.physicalSize = _logical * 3;
    binding.platformDispatcher.views.first.devicePixelRatio = 3;
    addTearDown(binding.platformDispatcher.views.first.resetPhysicalSize);
    addTearDown(binding.platformDispatcher.views.first.resetDevicePixelRatio);
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

  final Map<String, Brightness> themes = <String, Brightness>{
    'acik': Brightness.light,
    'koyu': Brightness.dark,
  };

  Future<void> stageShot(
    WidgetTester t,
    String name,
    Brightness br, {
    bool returning = false,
    bool shelf = false,
    bool pin = false,
    bool play = false,
  }) async {
    final FakeAudioCaptureChannel channel = FakeAudioCaptureChannel();
    final AudioInputController audio = AudioInputController(
      channel: channel,
      requestMicrophonePermission: () async => PermissionStatus.granted,
      pcmDeliveryTimeout: const Duration(minutes: 5),
    );
    PracticeSessionController? controller;
    int local = 0;
    final V1CourseCatalog catalog = _catalog();
    final String firstId = catalog.lessons
        .firstWhere((l) => l.availability == V1LessonAvailability.measured)
        .id;
    final Map<String, V1PracticeRecord> seed = returning
        ? <String, V1PracticeRecord>{
            firstId: V1PracticeRecord(
              lessonId: firstId,
              runs: 4,
              passedAt: DateTime.utc(2026, 11, 1),
              passedBpm: 50,
              completedAt: DateTime.utc(2026, 11, 1),
              completedBpm: 60,
            ),
          }
        : <String, V1PracticeRecord>{};
    await t.pumpWidget(
      _frame(
        br,
        StageHomeScreen(
          catalog: catalog,
          progressFactory: (_) => _Memory(seed),
          checksFactory: (_) => _Checks(),
          paidFeaturesAvailable: false,
          seed: 1,
          controllerFactory: (score, tempo, criteria) =>
              controller = PracticeSessionController(
                score: score,
                tempo: tempo,
                audio: audio,
                criteria: criteria,
                localClockUs: () => local,
                analyzer: (r) async => judgeNote(r),
              ),
        ),
      ),
    );
    for (int i = 0; i < 4; i++) {
      await t.pump();
    }
    if (shelf || pin) {
      await t.tap(find.byKey(const Key('stage-shelf-toggle')));
      await t.pump();
    }
    if (pin) {
      await t.tap(find.byKey(const Key('stage-pin-metronome')));
      await t.pump();
      if (!shelf) {
        await t.tap(find.byKey(const Key('stage-shelf-toggle')));
        await t.pump();
      }
    }
    if (play) {
      await t.ensureVisible(find.byKey(const Key('practice-start')));
      await t.pump();
      await t.tap(find.byKey(const Key('practice-start')));
      await t.pump();
      final math.Random rng = math.Random(1);
      int tn = 0;
      for (int i = 0; i < 8; i++) {
        final Float64List x = Float64List(4800);
        for (int k = 0; k < x.length; k++) {
          x[k] = (rng.nextDouble() * 2 - 1) * .002;
        }
        channel.pushChunk(x, sampleRate: 48000, tNativeUs: tn);
        tn += 100000;
        local = tn;
        await t.pump();
        if (channel.metronome != null && controller!.timeline == null) {
          channel.pushMetronomeAnchor(tn + 200000);
          await t.pump();
        }
        controller!.tick();
        await t.pump();
      }
    }
    await save(t, name);
    await t.pumpWidget(const SizedBox());
    await t.runAsync(audio.dispose);
  }

  for (final MapEntry<String, Brightness> th in themes.entries) {
    final String s = th.key;
    final Brightness b = th.value;
    testWidgets(
      '01 sahne yeni kullanici $s',
      (t) => stageShot(t, '01-sahne-yeni-kullanici-$s', b),
    );
    testWidgets(
      '02 sahne devam var $s',
      (t) => stageShot(t, '02-sahne-devam-var-$s', b, returning: true),
    );
    testWidgets(
      '03 calarken $s',
      (t) => stageShot(t, '03-calarken-$s', b, returning: true, play: true),
    );
    testWidgets(
      '04 raf kapali $s',
      (t) => stageShot(t, '04-raf-kapali-$s', b, returning: true),
    );
    testWidgets(
      '05 raf acik $s',
      (t) => stageShot(t, '05-raf-acik-$s', b, returning: true, shelf: true),
    );
    testWidgets(
      '06 calarken metronom $s',
      (t) => stageShot(
        t,
        '06-calarken-metronom-$s',
        b,
        returning: true,
        pin: true,
        play: true,
      ),
    );
    testWidgets('07 eski kok bayrak kapali $s', (t) async {
      final ContentRepository repo = (await t.runAsync(
        ContentRepository.load,
      ))!;
      final CueTextResolver cue = (await t.runAsync(CueTextResolver.load))!;
      await t.pumpWidget(
        ContentRepositoryScope(
          repo: repo,
          cueText: cue,
          child: RepaintBoundary(
            key: _shot,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: OstinatoThemes.forBrightness(b),
              locale: const Locale('tr'),
              supportedLocales: appSupportedLocales,
              localizationsDelegates: appLocalizationsDelegates,
              builder: (BuildContext context, Widget? child) => Column(
                children: <Widget>[
                  Container(
                    width: double.infinity,
                    color: const Color(0xFF3F3F46),
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: const Text(
                      'prototip / test render · eski kok degismedi · bayrak KAPALI',
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
              home: OstinatoHome(
                repo: repo,
                cueText: cue,
                store: InMemoryOnboardingStore(),
                alreadyOnboarded: true,
                stageHomeOpen: false,
              ),
            ),
          ),
        ),
      );
      for (int i = 0; i < 20; i++) {
        await t.pump(const Duration(milliseconds: 50));
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)),
        );
      }
      await save(t, '07-eski-kok-$s');
    });
  }
}
