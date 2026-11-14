// OST-UX-05h2 (W) — Yukleme / cevrimdisi / hata dayanikliligi (yeni ozellik yok).
//   A) yukleme: tek erisilebilir "Yukleniyor" durumu, Cal pasif
//   B) zaman asimi: sahne acik, "Tekrar dene"; gec donen yukleme ezmez
//   C) hata: tek dugumlu canli bolge + "Tekrar dene"; kayit yazma hatasi gorunur
//   D) cevrimdisi: ag hatasi enjekte; pratik/kulak yerel calismaya devam eder
//   E) 360x640 + yazi 1.3: iskelet ve hata 14 dilde tasmaz
// Beklenen metinler LITERAL (kataloglardan turetilmez).
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/account_connection.dart';
import 'package:ostinato/app/app_locale.dart';
import 'package:ostinato/app/app_translation_catalog.dart';
import 'package:ostinato/app/audio/audio_capture_channel.dart';
import 'package:ostinato/app/audio/audio_input_controller.dart';
import 'package:ostinato/app/course_access.dart';
import 'package:ostinato/app/curriculum/v1_lesson.dart';
import 'package:ostinato/app/design/ostinato_theme.dart';
import 'package:ostinato/app/practice/loop/practice_judge.dart';
import 'package:ostinato/app/practice/loop/practice_loop_screen.dart';
import 'package:ostinato/app/practice/loop/practice_outcome.dart';
import 'package:ostinato/app/practice/loop/practice_progress_store.dart';
import 'package:ostinato/app/practice/loop/practice_session_controller.dart';
import 'package:ostinato/app/practice/loop/v1_course_catalog.dart';
import 'package:ostinato/app/practice/setup/setup_profile_store.dart';
import 'package:ostinato/app/stage/ghost_store.dart';
import 'package:ostinato/app/stage/listening_off_store.dart';
import 'package:ostinato/app/stage/stage_home_screen.dart';
import 'package:permission_handler/permission_handler.dart';

import 'support/localized_widget_ready.dart';
import 'support/practice_host.dart';
import 'support/ux_05f_rig.dart';

const _loading = 'Yükleniyor…';
const _loadError = 'Çalışman yüklenemedi.';
const _retry = 'Tekrar dene';
const _unverified = 'Üyelik şu an doğrulanamadı. Çal\'a dokunup tekrar dene.';
const _notSaved = 'Bu sonuç cihaza kaydedilemedi.';

const _tags = <String>[
  'ar',
  'de',
  'en',
  'es-419',
  'fr',
  'hi',
  'id',
  'it',
  'ja',
  'ko',
  'pl',
  'pt-BR',
  'tr',
  'zh-Hans',
];

/// load() waits for the test to finish it.
final class _Hang implements V1PracticeProgress {
  final Completer<Map<String, V1PracticeRecord>> gate = Completer();
  int loads = 0;
  @override
  Future<Map<String, V1PracticeRecord>> load() {
    loads++;
    return gate.future;
  }

  @override
  Future<V1PracticeRecord> recordRun(
    String id,
    PracticeRunSummary s, {
    DateTime? at,
  }) => throw UnimplementedError();
}

/// The first load fails or hangs (per [first]); later loads answer at once.
final class _Flaky implements V1PracticeProgress {
  _Flaky({required this.hangFirst});
  final bool hangFirst;
  final Completer<Map<String, V1PracticeRecord>> firstGate = Completer();
  int loads = 0;
  @override
  Future<Map<String, V1PracticeRecord>> load() {
    loads++;
    if (loads == 1) {
      return hangFirst
          ? firstGate.future
          : Future<Map<String, V1PracticeRecord>>.error(
              StateError('disk read failed'),
            );
    }
    return Future.value(<String, V1PracticeRecord>{});
  }

  @override
  Future<V1PracticeRecord> recordRun(
    String id,
    PracticeRunSummary s, {
    DateTime? at,
  }) => throw UnimplementedError();
}

final class _Seeded implements V1PracticeProgress {
  _Seeded(this.records);
  final Map<String, V1PracticeRecord> records;
  @override
  Future<Map<String, V1PracticeRecord>> load() async => Map.of(records);
  @override
  Future<V1PracticeRecord> recordRun(
    String id,
    PracticeRunSummary s, {
    DateTime? at,
  }) async => throw UnimplementedError();
}

final class _FailingWrite implements V1PracticeProgress {
  @override
  Future<Map<String, V1PracticeRecord>> load() async => {};
  @override
  Future<V1PracticeRecord> recordRun(
    String id,
    PracticeRunSummary s, {
    DateTime? at,
  }) async => throw const FileSystemException('disk full');
}

Map<String, V1PracticeRecord> _level1Done(V1CourseCatalog catalog) {
  final firstPaid = catalog.lessons.firstWhere(
    (l) =>
        l.availability == V1LessonAvailability.measured &&
        !isFreeV1Lesson(l.id, paidFeaturesAvailable: true),
  );
  final upTo = catalog.lessons.indexOf(firstPaid);
  return {
    for (final l in catalog.lessons.take(upTo))
      l.id: V1PracticeRecord(
        lessonId: l.id,
        runs: 1,
        passedAt: DateTime.utc(2026, 11, 1),
        passedBpm: 50,
        completedAt: DateTime.utc(2026, 11, 1),
        completedBpm: 60,
      ),
  };
}

Future<void> _boot(
  WidgetTester t,
  Rig05f rig,
  V1CourseCatalog catalog,
  V1PracticeProgress progress, {
  String tag = 'tr',
  double scale = 1.0,
  Size size = const Size(420, 900),
  bool paid = false,
  Future<bool> Function()? paidCheck,
  Future<bool> Function(BuildContext)? guard,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  final stage = StageHomeScreen(
    catalog: catalog,
    progressFactory: (_) => progress,
    checksFactory: (_) => Checks05f(),
    controllerFactory: rig.factory,
    seed: 1,
    paidFeaturesAvailable: paid,
    paidAccessCheck: paidCheck ?? () async => true,
    setupStore: MemorySetupProfileStore(),
    listeningOffStore: MemoryListeningOffStore(),
    ghostStore: MemoryGhostStore(),
    micStatus: () async => PermissionStatus.granted,
    weeklyGoalLoader: () async => null,
    appSettingsOpener: () async => true,
    setupOpener: (_) async {},
    settingsOpener: (_) async {},
    accountOpener: (_) async {},
    tunerOpener: (_) async {},
    earScreenBuilder: (_) => const Scaffold(body: Text('ear-screen')),
  );
  await t.pumpWidget(
    MaterialApp(
      theme: ostinatoTheme(),
      locale: localeForLanguageTag(tag),
      supportedLocales: appSupportedLocales,
      localizationsDelegates: appLocalizationsDelegates,
      builder: (c, child) => MediaQuery(
        data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: guard == null
          ? stage
          : AccountScope(
              currentUserId: 'u1',
              connection: AccountConnection(
                userId: ValueNotifier<String?>('u1'),
                pageBuilder: (_) => const SizedBox(),
                hasPaidAccess: () async => true,
                requirePaidAccess: guard,
              ),
              child: stage,
            ),
    ),
  );
  await waitForLocalizedFixture(
    t,
    languageTag: tag,
    anchor: find.byType(StageHomeScreen),
    reason: tag,
  );
  for (var i = 0; i < 6; i++) {
    await t.pump();
  }
}

List<SemanticsNode> _nodes(WidgetTester t) {
  final out = <SemanticsNode>[];
  void walk(SemanticsNode n) {
    out.add(n);
    n.visitChildren((c) {
      walk(c);
      return true;
    });
  }

  // ignore: deprecated_member_use
  walk(t.binding.pipelineOwner.semanticsOwner!.rootSemanticsNode!);
  return out;
}

List<SemanticsNode> _labelled(WidgetTester t, String text) => [
  for (final n in _nodes(t))
    if (!n.flagsCollection.isHidden && n.label == text) n,
];

String _shown(WidgetTester t) =>
    t.widget<PracticeLoopScreen>(find.byType(PracticeLoopScreen)).lesson.id;

bool _playPendingDisabled(WidgetTester t) =>
    t
        .widget<FilledButton>(find.byKey(const Key('stage-play-pending')))
        .onPressed ==
    null;

void main() {
  late V1CourseCatalog catalog;
  setUpAll(() => catalog = catalog05f());

  group('A) yukleme durumu', () {
    testWidgets('A1 iskelet tek erisilebilir "Yukleniyor" durumu; Cal pasif', (
      t,
    ) async {
      final sem = t.ensureSemantics();
      final rig = Rig05f();
      await _boot(t, rig, catalog, _Hang());
      expect(find.byKey(const Key('stage-play-pending')), findsOneWidget);
      expect(_playPendingDisabled(t), isTrue);
      expect(_labelled(t, _loading), hasLength(1), reason: 'tek dugum');
      expect(find.byKey(const Key('stage-retry')), findsNothing);
      sem.dispose();
      // Let the deadline pass so no timer outlives the test.
      await t.pump(const Duration(seconds: 11));
      await dispose05f(t, rig);
    });
  });

  group('B) zaman asimi', () {
    testWidgets('B1 10 sn sonra sahne acik + Tekrar dene; oncesinde yok', (
      t,
    ) async {
      final sem = t.ensureSemantics();
      final rig = Rig05f();
      final hang = _Hang();
      await _boot(t, rig, catalog, hang);
      await t.pump(const Duration(seconds: 9));
      expect(find.byKey(const Key('stage-retry')), findsNothing);
      expect(_labelled(t, _loading), hasLength(1));
      await t.pump(const Duration(seconds: 2));
      await t.pump();
      expect(find.byKey(const Key('stage-retry')), findsOneWidget);
      expect(_playPendingDisabled(t), isTrue);
      expect(_labelled(t, _loading), isEmpty, reason: 'yukleniyor kalkti');
      expect(_labelled(t, _loadError), hasLength(1));
      expect(t.takeException(), isNull);
      sem.dispose();
      await dispose05f(t, rig);
    });

    testWidgets('B2 gec donen yukleme basarisiz durumu ezmez', (t) async {
      final rig = Rig05f();
      final hang = _Hang();
      await _boot(t, rig, catalog, hang);
      await t.pump(const Duration(seconds: 11));
      await t.pump();
      expect(find.byKey(const Key('stage-retry')), findsOneWidget);
      hang.gate.complete(<String, V1PracticeRecord>{});
      for (var i = 0; i < 4; i++) {
        await t.runAsync(() => Future<void>.delayed(Duration.zero));
        await t.pump();
      }
      expect(find.byKey(const Key('stage-retry')), findsOneWidget);
      expect(find.byType(PracticeLoopScreen), findsNothing);
      expect(t.takeException(), isNull);
      await dispose05f(t, rig);
    });

    testWidgets('B3 Tekrar dene basarili -> normal sahne; eski yukleme '
        'sonradan donse de sahne degismez', (t) async {
      final rig = Rig05f();
      final flaky = _Flaky(hangFirst: true);
      await _boot(t, rig, catalog, flaky);
      await t.pump(const Duration(seconds: 11));
      await t.pump();
      await t.tap(find.byKey(const Key('stage-retry')));
      for (var i = 0; i < 6; i++) {
        await t.pump();
      }
      expect(find.byType(PracticeLoopScreen), findsOneWidget);
      expect(find.byKey(const Key('stage-retry')), findsNothing);
      final id = _shown(t);
      // The first (late) load answers with a record that would move the stage.
      flaky.firstGate.complete({
        for (final l in catalog.lessons.take(3))
          l.id: V1PracticeRecord(
            lessonId: l.id,
            runs: 1,
            passedAt: DateTime.utc(2026, 11, 1),
            passedBpm: 50,
            completedAt: DateTime.utc(2026, 11, 1),
            completedBpm: 60,
          ),
      });
      for (var i = 0; i < 4; i++) {
        await t.runAsync(() => Future<void>.delayed(Duration.zero));
        await t.pump();
      }
      expect(_shown(t), id);
      expect(find.byKey(const Key('stage-retry')), findsNothing);
      await dispose05f(t, rig);
    });
  });

  group('C) hata', () {
    testWidgets('C1 okuma hatasi: sahne acik, tek dugum canli bolge + Tekrar '
        'dene', (t) async {
      final sem = t.ensureSemantics();
      final rig = Rig05f();
      await _boot(t, rig, catalog, _Flaky(hangFirst: false));
      expect(find.byKey(const Key('stage-retry')), findsOneWidget);
      expect(find.text(_retry), findsOneWidget);
      expect(find.byKey(const Key('stage-load-error')), findsOneWidget);
      final nodes = _labelled(t, _loadError);
      expect(nodes, hasLength(1), reason: 'tek dugum');
      expect(nodes.single.flagsCollection.isLiveRegion, isTrue);
      expect(_playPendingDisabled(t), isTrue);
      expect(find.byKey(const Key('stage-handle-path')), findsOneWidget);
      sem.dispose();
      await dispose05f(t, rig);
    });

    testWidgets('C2 Tekrar dene basarili -> normal sahne, hata metni yok', (
      t,
    ) async {
      final rig = Rig05f();
      await _boot(t, rig, catalog, _Flaky(hangFirst: false));
      await t.tap(find.byKey(const Key('stage-retry')));
      for (var i = 0; i < 6; i++) {
        await t.pump();
      }
      expect(find.byType(PracticeLoopScreen), findsOneWidget);
      expect(find.byKey(const Key('stage-load-error')), findsNothing);
      expect(find.byKey(const Key('stage-retry')), findsNothing);
      await dispose05f(t, rig);
    });

    testWidgets('C3 kayit yazma hatasi sessiz kaybolmaz: sonuc "cihaza '
        'kaydedilemedi" der (mevcut davranis kanitlandi)', (t) async {
      t.view.physicalSize = const Size(420, 1600);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final audio = AudioInputController(
        channel: FakeAudioCaptureChannel(),
        requestMicrophonePermission: () async => PermissionStatus.granted,
        pcmDeliveryTimeout: const Duration(minutes: 5),
      );
      final channel = FakeAudioCaptureChannel();
      final audio2 = AudioInputController(
        channel: channel,
        requestMicrophonePermission: () async => PermissionStatus.granted,
        pcmDeliveryTimeout: const Duration(minutes: 5),
      );
      var local = 0;
      PracticeSessionController? controller;
      final lesson = V1Lesson.fromJson(
        jsonDecode(
          File('content/v1/gtr/gtr-s1-m02-02.json').readAsStringSync(),
        ),
      );
      await t.pumpWidget(
        practiceHost(
          locale: 'tr',
          PracticeLoopScreen(
            lesson: lesson,
            progress: _FailingWrite(),
            controllerFactory: (score, tempo, criteria) =>
                controller = PracticeSessionController(
                  score: score,
                  tempo: tempo,
                  audio: audio2,
                  criteria: criteria,
                  localClockUs: () => local,
                  analyzer: (r) async => judgeNote(r),
                ),
          ),
        ),
      );
      await t.tap(find.byKey(const Key('practice-start')));
      await t.pump();
      final c = controller!;
      final rng = math.Random(1);
      var ts = 0;
      for (var i = 0; i < 300 && c.phase != PracticePhase.finished; i++) {
        final x = Float64List(4800);
        for (var k = 0; k < x.length; k++) {
          x[k] = (rng.nextDouble() * 2 - 1) * .002;
        }
        channel.pushChunk(x, sampleRate: 48000, tNativeUs: ts);
        ts += 100000;
        local = ts;
        await t.pump();
        if (channel.metronome != null && c.timeline == null) {
          channel.pushMetronomeAnchor(ts + 200000);
          await t.pump();
        }
        c.tick();
        await t.pump();
      }
      await t.pumpAndSettle();
      expect(c.phase, PracticePhase.finished);
      expect(find.text(_notSaved), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      await t.runAsync(audio2.dispose);
      await t.runAsync(audio.dispose);
    });
  });

  group('D) cevrimdisi (ag hatasi enjekte)', () {
    testWidgets('D1 uyelik sorgusu SocketException: sahne acilir, ucretsiz '
        'ders, Cal calisir (yerel pratik surer)', (t) async {
      final records = _level1Done(catalog);
      final next = V1CourseState(catalog, records, const {}).next!;
      final rig = Rig05f();
      await _boot(
        t,
        rig,
        catalog,
        _Seeded(records),
        paid: true,
        paidCheck: () => throw const SocketException('Failed host lookup'),
      );
      expect(find.byKey(const Key('stage-load-error')), findsNothing);
      expect(_shown(t), isNot(next.id));
      expect(isFreeV1Lesson(_shown(t), paidFeaturesAvailable: true), isTrue);
      await t.tap(find.byKey(const Key('practice-start')));
      for (var i = 0; i < 4; i++) {
        await t.pump();
      }
      expect(rig.controller!.running, isTrue);
      await dispose05f(t, rig);
    });

    testWidgets('D2 Cal anindaki uyelik dogrulamasi SocketException: dürüst '
        'bildirim, kosu baslamaz, tekrar denenebilir', (t) async {
      final records = _level1Done(catalog);
      final rig = Rig05f();
      var asked = 0;
      await _boot(
        t,
        rig,
        catalog,
        _Seeded(records),
        paid: true,
        guard: (_) async {
          asked++;
          if (asked == 1) throw const SocketException('Network is unreachable');
          return true;
        },
      );
      await t.tap(find.byKey(const Key('practice-start')));
      for (var i = 0; i < 4; i++) {
        await t.pump();
      }
      expect(find.text(_unverified), findsOneWidget);
      expect(rig.controller?.running ?? false, isFalse);
      await t.tap(find.byKey(const Key('practice-start')));
      for (var i = 0; i < 4; i++) {
        await t.pump();
      }
      expect(asked, 2);
      expect(rig.controller!.running, isTrue);
      expect(find.text(_unverified), findsNothing);
      await dispose05f(t, rig);
    });

    testWidgets('D3 uyelik sorgusu SocketException iken Baska calis -> kulak '
        'ekrani yerelde acilir', (t) async {
      final rig = Rig05f();
      await _boot(
        t,
        rig,
        catalog,
        _Seeded(const {}),
        paidCheck: () => throw const SocketException('offline'),
      );
      await t.tap(find.byKey(const Key('stage-handle-other')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 500));
      expect(find.byKey(const Key('stage-handle-other')), findsOneWidget);
      expect(find.text('Çal'), findsWidgets);
      expect(t.takeException(), isNull);
      await dispose05f(t, rig);
    });
  });

  group('E) 360x640 + yazi 1.3, 14 dil', () {
    for (final tag in _tags) {
      testWidgets('E iskelet $tag', (t) async {
        final rig = Rig05f();
        await _boot(
          t,
          rig,
          catalog,
          _Hang(),
          tag: tag,
          scale: 1.3,
          size: const Size(360, 640),
        );
        expect(find.byKey(const Key('stage-play-pending')), findsOneWidget);
        expect(t.takeException(), isNull, reason: '$tag iskelet');
        final play = t.getRect(find.byKey(const Key('stage-play-pending')));
        expect(play.bottom, lessThanOrEqualTo(640));
        await t.pump(const Duration(seconds: 11));
        await t.pump();
        expect(t.takeException(), isNull, reason: '$tag zaman asimi');
        expect(find.byKey(const Key('stage-load-error')), findsOneWidget);
        expect(find.byKey(const Key('stage-retry')), findsOneWidget);
        await dispose05f(t, rig);
      });

      testWidgets('E hata $tag', (t) async {
        final sem = t.ensureSemantics();
        final rig = Rig05f();
        await _boot(
          t,
          rig,
          catalog,
          _Flaky(hangFirst: false),
          tag: tag,
          scale: 1.3,
          size: const Size(360, 640),
        );
        expect(t.takeException(), isNull, reason: '$tag hata');
        final err = find.byKey(const Key('stage-load-error'));
        expect(err, findsOneWidget);
        final retry = t.getRect(find.byKey(const Key('stage-retry')));
        final msg = t.getRect(err);
        for (final r in [retry, msg]) {
          expect(r.left, greaterThanOrEqualTo(0), reason: tag);
          expect(r.right, lessThanOrEqualTo(360), reason: tag);
          expect(r.top, greaterThanOrEqualTo(0), reason: tag);
          expect(r.bottom, lessThanOrEqualTo(640), reason: tag);
        }
        expect(msg.bottom, lessThanOrEqualTo(retry.top + 0.5), reason: tag);
        final label = t.getSemantics(err).label;
        expect(label, isNotEmpty);
        if (tag != 'en') {
          expect(label, isNot('Your practice could not be loaded.'));
        }
        sem.dispose();
        await dispose05f(t, rig);
      });
    }
  });
}
