// OST-UX-01 GÖRÜNTÜ KANITI — "test render, sahte veri".
//
// ⚠️ YALNIZ OST-UX-01 KANITI, ÜRÜN TESTİ DEĞİL. Bu dosya `tool/` altındadır;
// CI'ın `flutter test` koşusuna (yalnız `test/`) GİRMEZ. Elle koşulur:
//
//   flutter test tool/ux_01_render_evidence_test.dart
//
// Ne yapar: ürünün ana ekranlarını, mevcut widget testlerinin kullandığı
// sahte / bellek-içi kurulumlarla (InMemoryOnboardingStore, bellek-içi
// ilerleme ve kontrol depoları, FakeAudioCaptureChannel, MemorySetupProfileStore)
// 390x844 @3x mantığıyla çizer ve PNG yazar:
//   docs/yula-execution/design/evidence/ux-01/render/NN-<ekran>.png
//
// Kapsam dışı (bilerek): Supabase, hesap, ağ, `--dart-define`, gerçek
// mikrofon/kamera, ham ses. Bayrakların HEPSİ varsayılan (KAPALI); kamera ve
// yeni özellik bayrakları AÇILMAZ. Yalnız `lib` API'si import edilir.
// ignore_for_file: invalid_use_of_visible_for_testing_member
// (Sıfırlama kancaları @visibleForTesting; bu dosya elle koşulan bir test.)
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
import 'package:ostinato/app/audio/audio_capture_channel.dart';
import 'package:ostinato/app/audio/audio_input_controller.dart';
import 'package:ostinato/app/audio/mic_permission_gate.dart';
import 'package:ostinato/app/content.dart';
import 'package:ostinato/app/cue_text.dart';
import 'package:ostinato/app/design/app_scope.dart';
import 'package:ostinato/app/design/ostinato_theme.dart' show ostinatoAppBuilder;
import 'package:ostinato/app/onboarding_store.dart';
import 'package:ostinato/app/practice/loop/practice_loop_screen.dart';
import 'package:ostinato/app/practice/loop/practice_marks.dart';
import 'package:ostinato/app/practice/loop/practice_outcome.dart';
import 'package:ostinato/app/practice/loop/practice_progress_store.dart';
import 'package:ostinato/app/practice/loop/practice_result_screen.dart';
import 'package:ostinato/app/practice/loop/practice_score.dart';
import 'package:ostinato/app/practice/loop/practice_session_controller.dart';
import 'package:ostinato/app/practice/loop/v1_course_catalog.dart';
import 'package:ostinato/app/practice/loop/v1_lesson_reader_screen.dart';
import 'package:ostinato/app/practice/loop/v1_practice_list_screen.dart';
import 'package:ostinato/app/practice/setup/setup_profile_store.dart';
import 'package:ostinato/app/curriculum/v1_lesson.dart';
import 'package:ostinato/app/screens/settings_screen.dart';
import 'package:ostinato/main.dart';
import 'package:permission_handler/permission_handler.dart';

const String _outDir = 'docs/yula-execution/design/evidence/ux-01/render';
const Size _logical = Size(390, 844);
const double _dpr = 3.0; // fiziksel 1170x2532
const double _outScale = 1.5; // PNG 585x1266 (boyut sınırı için)

final GlobalKey _shot = GlobalKey();

// ---------------------------------------------------------------- yardımcı

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
  await family('IBM Plex Mono', <String>['assets/fonts/IBMPlexMono-Medium.ttf']);
}

/// Uygulamanın MaterialApp ayarlarını (tema, yerelleştirme, builder) taklit
/// eder; yalnız sahte kök ekran verilir. `RepaintBoundary` PNG için.
Widget _app(Widget home, {ContentRepository? repo, CueTextResolver? cue}) {
  final Widget app = MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: OstinatoThemes.light,
    darkTheme: OstinatoThemes.dark,
    themeMode: ThemeMode.light,
    locale: const Locale('en'),
    supportedLocales: appSupportedLocales,
    localizationsDelegates: appLocalizationsDelegates,
    builder: ostinatoAppBuilder,
    home: home,
  );
  final Widget scoped = (repo != null && cue != null)
      ? ContentRepositoryScope(repo: repo, cueText: cue, child: app)
      : app;
  return RepaintBoundary(key: _shot, child: scoped);
}

Future<void> _settle(WidgetTester t) async {
  // Gerçek varlık G/Ç'si (çeviri katalogları, içerik) sahte zamanda ilerlemez;
  // birkaç gerçek olay turu ver, sonra kareyi çiz.
  for (int i = 0; i < 20; i++) {
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
    final RenderRepaintBoundary b =
        t.renderObject<RenderRepaintBoundary>(find.byKey(_shot));
    final ui.Image img = await b.toImage(pixelRatio: _outScale);
    final ByteData? data = await img.toByteData(format: ui.ImageByteFormat.png);
    Directory(_outDir).createSync(recursive: true);
    File('$_outDir/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
    // ignore: avoid_print
    print('RENDER $name.png ${img.width}x${img.height}');
  });
}

Future<void> _tap(WidgetTester t, Finder f) async {
  expect(f, findsWidgets, reason: 'dokunulacak öğe yok: $f');
  try {
    await t.ensureVisible(f.first);
    await t.pump();
  } on Object {/* kaydırılabilir ata yok */}
  await t.tap(f.first);
  await _settle(t);
}

// ------------------------------------------------------- bellek-içi depolar

final class _MemoryProgress implements V1PracticeProgress {
  final Map<String, V1PracticeRecord> records = <String, V1PracticeRecord>{};
  @override
  Future<Map<String, V1PracticeRecord>> load() async =>
      Map<String, V1PracticeRecord>.of(records);
  @override
  Future<V1PracticeRecord> recordRun(
    String id,
    PracticeRunSummary s, {
    DateTime? at,
  }) async => records[id] = (records[id] ?? V1PracticeRecord(lessonId: id))
      .withRun(s, at ?? DateTime.utc(2026, 11, 1));
}

final class _MemoryChecks implements V1LessonChecks {
  final Map<String, V1LessonCheck> checks = <String, V1LessonCheck>{};
  @override
  Future<Map<String, V1LessonCheck>> load() async =>
      Map<String, V1LessonCheck>.of(checks);
  @override
  Future<V1LessonCheck> record(
    String lessonId,
    V1CheckEvidence evidence, {
    DateTime? at,
  }) async => checks[lessonId] = mergeLessonCheck(
    checks[lessonId],
    V1LessonCheck(
      lessonId: lessonId,
      evidence: evidence,
      at: at ?? DateTime.utc(2026, 11, 2),
    ),
  );
}

Map<String, dynamic> jsonDecodeFile(String p) =>
    jsonDecode(File(p).readAsStringSync()) as Map<String, dynamic>;

V1Lesson _lesson(String id) =>
    V1Lesson.fromJson(jsonDecodeFile('content/v1/gtr/$id.json'));

// ------------------------------------------------------------------- testler

void main() {
  final TestWidgetsFlutterBinding binding =
      TestWidgetsFlutterBinding.ensureInitialized();
  late ContentRepository repo;
  late CueTextResolver cue;
  late V1CourseCatalog course;

  setUpAll(() async {
    await _loadFonts();
    // Paketli çeviri katalogları gerçek G/Ç ile bir kez ısıtılır.
    for (final String tag in supportedLanguageTags) {
      await const AppTranslationsDelegate().load(localeForLanguageTag(tag));
    }
    repo = await ContentRepository.load();
    cue = await CueTextResolver.load();
    final List<V1Lesson> all = <V1Lesson>[
      for (final FileSystemEntity f in Directory('content/v1/gtr').listSync())
        if (f is File && f.path.endsWith('.json'))
          V1Lesson.fromJson(jsonDecodeFile(f.path)),
    ];
    course = V1CourseCatalog(all);
  });

  setUp(() {
    binding.platformDispatcher.views.first.physicalSize = _logical * _dpr;
    binding.platformDispatcher.views.first.devicePixelRatio = _dpr;
    addTearDown(binding.platformDispatcher.views.first.resetPhysicalSize);
    addTearDown(binding.platformDispatcher.views.first.resetDevicePixelRatio);
    MicPermissionGate.resetForTest();
    resetAudioCaptureCoordinatorForTest();
  });

  Widget home({required bool onboarded}) => _app(
    OstinatoHome(
      repo: repo,
      cueText: cue,
      store: InMemoryOnboardingStore(),
      alreadyOnboarded: onboarded,
    ),
    repo: repo,
    cue: cue,
  );

  testWidgets('01-onboarding-karsilama', (WidgetTester t) async {
    await t.pumpWidget(home(onboarded: false));
    await _settle(t);
    await _snap(t, '01-onboarding-karsilama');
    await _tap(t, find.byKey(const Key('onboarding-primary')));
    await _snap(t, '02-onboarding-kapsam');
    await _tap(t, find.byKey(const Key('onboarding-primary')));
    await _snap(t, '03-onboarding-sensorler');
  });

  testWidgets('04-stüdyo-kütüphane', (WidgetTester t) async {
    await t.pumpWidget(home(onboarded: true));
    await _settle(t);
    await _snap(t, '04-studyo-kutuphane');
    await _tap(t, find.text('Guitar'));
    await _snap(t, '05-calgi-gitar');
  });

  testWidgets('06-kurs-ders-listesi', (WidgetTester t) async {
    final _MemoryProgress progress = _MemoryProgress();
    final SetupStepRecord skip = SetupStepRecord(
      SetupStepState.skipped,
      DateTime.utc(2026, 11, 1),
    );
    await t.pumpWidget(
      _app(
        V1PracticeListScreen(
          catalog: Future<V1CourseCatalog>.value(course),
          progressFactory: (_) => progress,
          checksFactory: (_) => _MemoryChecks(),
          setupStore: MemorySetupProfileStore(
            SetupProfile.empty.copyWith(
              placement: skip,
              roomStep: skip,
              latencyStep: skip,
              tuningStep: skip,
            ),
          ),
        ),
      ),
    );
    await _settle(t);
    await _snap(t, '06-kurs-ders-listesi');
  });

  testWidgets('07-ders-okuyucu', (WidgetTester t) async {
    final V1CourseLesson l = course.units
        .expand((V1CourseUnit u) => u.lessons)
        .firstWhere(
          (V1CourseLesson x) =>
              x.availability == V1LessonAvailability.selfCheck,
        );
    await t.pumpWidget(
      _app(V1LessonReaderScreen(lesson: l, checks: _MemoryChecks())),
    );
    await _settle(t);
    await _snap(t, '07-ders-okuyucu');
  });

  testWidgets('08-pratik-ekrani', (WidgetTester t) async {
    await t.pumpWidget(
      _app(PracticeLoopScreen(
        lesson: _lesson('gtr-s1-m02-02'),
        progress: _MemoryProgress(),
        hasNextLesson: true,
      )),
    );
    await _settle(t);
    await _snap(t, '08-pratik-ekrani');
  });

  testWidgets('09-pratik-mikrofon-izni-reddi', (WidgetTester t) async {
    final FakeAudioCaptureChannel channel = FakeAudioCaptureChannel();
    final AudioInputController audio = AudioInputController(
      channel: channel,
      requestMicrophonePermission: () async => PermissionStatus.denied,
      pcmDeliveryTimeout: const Duration(minutes: 5),
    );
    MicPermissionGate.knownGranted = false;
    MicPermissionGate.status = () async => PermissionStatus.denied;
    MicPermissionGate.request = () async => PermissionStatus.denied;
    await t.pumpWidget(
      _app(PracticeLoopScreen(
        lesson: _lesson('gtr-s1-m02-02'),
        progress: _MemoryProgress(),
        controllerFactory: (score, tempo, criteria) =>
            PracticeSessionController(
              score: score,
              tempo: tempo,
              audio: audio,
              criteria: criteria,
            ),
      )),
    );
    await _settle(t);
    await _tap(t, find.byKey(const Key('practice-start')));
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await _snap(t, '09-pratik-mikrofon-izni-reddi');
    await t.pumpWidget(const SizedBox());
    await t.runAsync(audio.dispose);
  });

  testWidgets('10-sonuc-ekrani', (WidgetTester t) async {
    final PracticeScore score =
        PracticeScore.parse('E2 F2 G2 F2 | E2 F2 G2 F2');
    const List<PracticeMark> marks = <PracticeMark>[
      PracticeMark.correct,
      PracticeMark.correct,
      PracticeMark.differentNote,
      PracticeMark.correct,
      PracticeMark.correct,
      PracticeMark.correct,
      PracticeMark.couldNotHear,
      PracticeMark.correct,
    ];
    final PracticeRunSummary s = PracticeRunSummary.of(
      score: score,
      outcomes: <NoteOutcome>[
        for (int i = 0; i < marks.length; i++)
          NoteOutcome(
            eventIndex: i,
            bar: score.events[i].bar,
            pass: 0,
            mark: marks[i],
            expectedMidi: score.events[i].midi,
            observedMidi: marks[i] == PracticeMark.differentNote ? 45 : null,
          ),
      ],
      bpm: 60,
      openBpm: 50,
      targetBpm: 60,
      completed: true,
      loopUsed: false,
      waitUsed: false,
      criteria: const PassCriteria(minAccuracy: .8),
    );
    await t.pumpWidget(
      _app(PracticeResultScreen(
        lesson: _lesson('gtr-s1-m02-02'),
        score: score,
        summary: s,
        hasNextLesson: true,
      )),
    );
    await _settle(t);
    await _snap(t, '10-sonuc-ekrani');
  });

  testWidgets('11-ayarlar', (WidgetTester t) async {
    await t.pumpWidget(_app(const SettingsScreen(), repo: repo, cue: cue));
    await _settle(t);
    await _snap(t, '11-ayarlar');
  });
}
