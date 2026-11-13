// OST-UX-05h1 (W) — Sahne erisilebilirligi (yeni ozellik yok).
//   A) bildirimler tek anlamsal dugum + liveRegion
//   B) guvenlik satiri sahnede ilk ekranda (raf acik, 360x640, yazi 1.3)
//   C) tek dugum / tek etiket; etiketsiz scrim anlamsal dugum degil
//   D) 14 dilde 360x640 + yazi 1.3 sahne ilk ekrani gorsel tasma yok
// Beklenen metinler LITERAL (kataloglardan turetilmez).
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/account_connection.dart';
import 'package:ostinato/app/app_locale.dart';
import 'package:ostinato/app/app_translation_catalog.dart';
import 'package:ostinato/app/audio/audio_input_controller.dart';
import 'package:ostinato/app/design/ostinato_theme.dart';
import 'package:ostinato/app/practice/loop/practice_progress_store.dart';
import 'package:ostinato/app/practice/loop/v1_course_catalog.dart';
import 'package:ostinato/app/course_access.dart';
import 'package:ostinato/app/curriculum/v1_lesson.dart';
import 'package:ostinato/app/practice/loop/practice_loop_screen.dart';
import 'package:ostinato/app/practice/loop/practice_outcome.dart';
import 'package:ostinato/app/practice/setup/setup_profile_store.dart';
import 'package:ostinato/app/stage/ghost_store.dart';
import 'package:ostinato/app/stage/listening_off_store.dart';
import 'package:ostinato/app/stage/stage_home_screen.dart';
import 'package:permission_handler/permission_handler.dart';

import 'support/localized_widget_ready.dart';
import 'support/practice_host.dart';
import 'support/ux_05f_rig.dart';

const _notCompleted = 'Koşu tamamlanmadı: ölçülmedi, geçit kaydı yok.';
const _unverified = 'Üyelik şu an doğrulanamadı. Çal\'a dokunup tekrar dene.';
const _listeningOff = 'Dinleme kapalı';
const _safetyStart = 'Ağrı, uyuşma ya da karıncalanmada dur.';

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

final class _Seeded implements V1PracticeProgress {
  _Seeded([Map<String, V1PracticeRecord>? r]) : records = {...?r};
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
  V1CourseCatalog catalog, {
  String tag = 'tr',
  double scale = 1.3,
  Size size = const Size(360, 640),
  V1PracticeProgress? progress,
  bool paid = false,
  PermissionStatus mic = PermissionStatus.denied,
  Future<bool> Function(BuildContext)? guard,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
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
      home: _scope(
        guard,
        StageHomeScreen(
          catalog: catalog,
          progressFactory: (_) => progress ?? Mem05f(),
          checksFactory: (_) => Checks05f(),
          controllerFactory: rig.factory,
          seed: 1,
          paidFeaturesAvailable: paid,
          paidAccessCheck: () async => true,
          setupStore: MemorySetupProfileStore(),
          listeningOffStore: MemoryListeningOffStore(),
          ghostOpen: true,
          ghostStore: MemoryGhostStore(),
          micStatus: () async => mic,
          appSettingsOpener: () async => true,
          setupOpener: (_) async {},
          settingsOpener: (_) async {},
          accountOpener: (_) async {},
          tunerOpener: (_) async {},
          earScreenBuilder: (_) => const Scaffold(body: Text('ear-screen')),
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
  for (var i = 0; i < 6; i++) {
    await t.pump();
  }
}

Widget _scope(Future<bool> Function(BuildContext)? guard, Widget child) =>
    guard == null
    ? child
    : AccountScope(
        currentUserId: 'u1',
        connection: AccountConnection(
          userId: ValueNotifier<String?>('u1'),
          pageBuilder: (_) => const SizedBox(),
          hasPaidAccess: () async => true,
          requirePaidAccess: guard,
        ),
        child: child,
      );

Future<void> _settle(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 500));
}

Future<void> _toggleShelf(WidgetTester t) async {
  await t.tap(find.byKey(const Key('stage-shelf-toggle')));
  await _settle(t);
}

Future<void> _openHelp(WidgetTester t) async {
  await t.ensureVisible(find.byKey(const Key('stage-help-row')));
  await t.pump();
  await t.tap(find.byKey(const Key('stage-help-row')));
  await _settle(t);
}

Future<void> _openSetup(WidgetTester t) async {
  await t.tap(find.byKey(const Key('stage-handle-setup')));
  await _settle(t);
}

Future<void> _play(WidgetTester t) async {
  await t.tap(find.byKey(const Key('practice-start')));
  await t.pump();
  await t.pump();
  await t.pump(const Duration(milliseconds: 50));
}

/// Every node under the semantics root (merged data).
List<SemanticsNode> _allNodes(WidgetTester t) {
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

bool _hidden(SemanticsNode n) => n.flagsCollection.isHidden;

List<SemanticsNode> _withLabel(WidgetTester t, Pattern p) => [
  for (final n in _allNodes(t))
    if (!_hidden(n) && n.label == p || (p is RegExp && n.label.contains(p))) n,
];

void main() {
  late final catalog = catalog05f();
  setUpAll(prepareRootTranslations);
  setUp(resetAudioCaptureCoordinatorForTest);

  group('A) bildirimler: tek dugum + liveRegion', () {
    testWidgets('A1 kosu tamamlanmadi', (t) async {
      final handle = t.ensureSemantics();
      final rig = Rig05f(permission: PermissionStatus.granted);
      await _boot(t, rig, catalog, mic: PermissionStatus.granted);
      await _play(t);
      await t.binding.handlePopRoute();
      await t.pump();
      await t.pump();
      // kardes: bildirim gorunur
      expect(find.text(_notCompleted), findsOneWidget);
      final key = find.byKey(const Key('stage-run-not-completed'));
      expect(key, findsOneWidget);
      final nodes = _withLabel(t, _notCompleted);
      expect(nodes, hasLength(1), reason: 'tek okunan dugum');
      expect(nodes.single.label, _notCompleted, reason: 'etiket bir kez');
      expect(nodes.single.flagsCollection.isLiveRegion, isTrue);
      handle.dispose();
      await dispose05f(t, rig);
    });

    testWidgets('A2 uyelik dogrulanamadi', (t) async {
      final handle = t.ensureSemantics();
      final rig = Rig05f(permission: PermissionStatus.granted);
      await _boot(
        t,
        rig,
        catalog,
        mic: PermissionStatus.granted,
        progress: _Seeded(_level1Done(catalog)),
        paid: true,
        guard: (_) async => throw StateError('boom'),
      );
      await _play(t);
      await t.pump();
      expect(find.text(_unverified), findsOneWidget);
      final nodes = _withLabel(t, _unverified);
      expect(nodes, hasLength(1));
      expect(nodes.single.label, _unverified);
      expect(nodes.single.flagsCollection.isLiveRegion, isTrue);
      handle.dispose();
      await dispose05f(t, rig);
    });

    testWidgets('A3 Dinleme kapali bandi', (t) async {
      final handle = t.ensureSemantics();
      final rig = Rig05f(permission: PermissionStatus.denied);
      await _boot(t, rig, catalog);
      await _play(t);
      expect(find.byKey(const Key('stage-listening-off')), findsOneWidget);
      // bant: baslik + neden + (Ayarlara git, Gizle) dugumleri; baslik
      // etiketli dugum canli bolge ve tek.
      final nodes = _withLabel(t, RegExp('^$_listeningOff'));
      expect(nodes, hasLength(1), reason: 'baslik tek dugum');
      expect(nodes.single.flagsCollection.isLiveRegion, isTrue);
      handle.dispose();
      await dispose05f(t, rig);
    });
  });

  group('B) guvenlik satiri sahnede ilk ekranda', () {
    for (final shelf in [false, true]) {
      testWidgets('B1 360x640 yazi 1.3 raf ${shelf ? 'acik' : 'kapali'}', (
        t,
      ) async {
        final rig = Rig05f(permission: PermissionStatus.granted);
        await _boot(t, rig, catalog, mic: PermissionStatus.granted);
        if (shelf) await _toggleShelf(t);
        final line = find.textContaining(_safetyStart);
        final play = find.byKey(const Key('practice-start'));
        expect(play, findsOneWidget, reason: 'kardes: Cal var');
        expect(line, findsOneWidget);
        final r = t.getRect(line);
        final p = t.getRect(play);
        expect(r.top, greaterThanOrEqualTo(0));
        expect(r.bottom, lessThanOrEqualTo(640), reason: 'ekran icinde');
        expect(
          r.bottom,
          lessThanOrEqualTo(p.top),
          reason: 'Cal ile cakismaz, Cal ustunde',
        );
        // kaydirmadan gorunur: ust Scrollable'da kaydirilacak yer yok
        final sc = find.ancestor(of: line, matching: find.byType(Scrollable));
        for (final e in sc.evaluate()) {
          final st = (e as StatefulElement).state as ScrollableState;
          expect(st.position.maxScrollExtent, 0, reason: 'kaydirma gerekmez');
        }
        await dispose05f(t, rig);
      });
    }
  });

  group('B2) stageMode:false duzeni degismez', () {
    testWidgets('satir hala kaydirilan govdede (Cal ile birlikte)', (t) async {
      final rig = Rig05f(permission: PermissionStatus.granted);
      final lesson = V1Lesson.fromJson(
        jsonDecode(
          File('content/v1/gtr/gtr-s1-m02-02.json').readAsStringSync(),
        ),
      );
      await boot05f(
        t,
        practiceHost(
          locale: 'tr',
          PracticeLoopScreen(
            lesson: lesson,
            progress: Mem05f(),
            seed: 1,
            controllerFactory: rig.factory,
          ),
        ),
        size: const Size(360, 640),
      );
      final line = find.textContaining(_safetyStart);
      final play = find.byKey(const Key('practice-start'));
      expect(play, findsOneWidget, reason: 'kardes: Cal var');
      expect(line, findsOneWidget);
      // ikisi de ayni kaydirilan govdenin icinde (sabit alan yok)
      final lineScroll = find.ancestor(
        of: line,
        matching: find.byType(SingleChildScrollView),
      );
      final playScroll = find.ancestor(
        of: play,
        matching: find.byType(SingleChildScrollView),
      );
      expect(lineScroll, findsOneWidget);
      expect(playScroll, findsOneWidget);
      expect(
        t.widget<SingleChildScrollView>(lineScroll),
        same(t.widget<SingleChildScrollView>(playScroll)),
      );
      // satir Cal'in ALTINDA (govde sirasi)
      expect(t.getTopLeft(line).dy, greaterThan(t.getTopLeft(play).dy));
      await dispose05f(t, rig);
    });
  });

  group('C) tek dugum / tek etiket', () {
    testWidgets('C1 Araclar dugmesi tek isButton', (t) async {
      final handle = t.ensureSemantics();
      final rig = Rig05f(permission: PermissionStatus.granted);
      await _boot(t, rig, catalog, mic: PermissionStatus.granted);
      final nodes = _withLabel(t, 'Araçlar');
      expect(nodes, hasLength(1));
      expect(nodes.single.flagsCollection.isButton, isTrue);
      expect(nodes.single.label, 'Araçlar', reason: 'etiket bir kez');
      handle.dispose();
      await dispose05f(t, rig);
    });

    testWidgets('C2 Yardim satiri + seviye dugmeleri tek isButton', (t) async {
      final handle = t.ensureSemantics();
      final rig = Rig05f(permission: PermissionStatus.granted);
      await _boot(t, rig, catalog, mic: PermissionStatus.granted);
      await _toggleShelf(t);
      await t.ensureVisible(find.byKey(const Key('stage-help-row')));
      await t.pump();
      final helpNodes = _withLabel(t, 'Yardım');
      expect(helpNodes.where((n) => n.flagsCollection.isButton), hasLength(1));
      await _openHelp(t);
      for (final l in ['learn', 'reinforce', 'recall', 'independent']) {
        final k = find.byKey(Key('ghost-level-$l'));
        expect(k, findsOneWidget, reason: l);
        await t.ensureVisible(k);
        await t.pump();
        final n = t.getSemantics(k);
        expect(n.flagsCollection.isButton, isTrue, reason: l);
        expect(n.label.isNotEmpty, isTrue, reason: l);
        // ayni etiketli baska dugum yok
        final same = _withLabel(t, n.label);
        expect(same, hasLength(1), reason: '$l: ${n.label}');
      }
      handle.dispose();
      await dispose05f(t, rig);
    });

    testWidgets('C3 Cihaz katmani satirlari tek dugum; ipucu ayri degil', (
      t,
    ) async {
      final handle = t.ensureSemantics();
      final rig = Rig05f(permission: PermissionStatus.denied);
      await _boot(t, rig, catalog);
      await _openSetup(t);
      expect(find.byKey(const Key('stage-device-settings')), findsOneWidget);
      for (final label in ['Gecikme kalibrasyonu', 'Ayarlar']) {
        final nodes = _withLabel(t, label);
        expect(nodes, hasLength(1), reason: label);
        expect(nodes.single.flagsCollection.isButton, isTrue, reason: label);
      }
      // izin yok satiri: etiket + ipucu tek dugum; "Ayarlara git" ayrica
      // okunmaz (yalniz bu dugumun icinde).
      final mic = _withLabel(t, 'Mikrofon: izin yok, Ayarlara git');
      expect(mic, hasLength(1));
      expect(mic.single.flagsCollection.isButton, isTrue);
      expect(
        _withLabel(t, 'Ayarlara git').where((n) => n != mic.single),
        isEmpty,
        reason: 'ipucu ayri okunmaz',
      );
      handle.dispose();
      await dispose05f(t, rig);
    });

    testWidgets('C4 scrim etiketsiz tiklanir dugum olmaz', (t) async {
      final handle = t.ensureSemantics();
      final rig = Rig05f(permission: PermissionStatus.denied);
      await _boot(t, rig, catalog);
      await _openSetup(t);
      expect(find.byKey(const Key('stage-layer-scrim')), findsOneWidget);
      // kardes: katman icinde etiketli dugmeler var
      expect(_withLabel(t, 'Ayarlar'), isNotEmpty);
      final unlabeledTaps = [
        for (final n in _allNodes(t))
          if (!n.flagsCollection.isHidden &&
              n.getSemanticsData().hasAction(SemanticsAction.tap) &&
              n.label.isEmpty &&
              n.value.isEmpty &&
              n.hint.isEmpty)
            n,
      ];
      expect(unlabeledTaps, isEmpty, reason: 'etiketsiz tap dugumu yok');
      handle.dispose();
      await dispose05f(t, rig);
    });
  });

  group('D) 14 dilde 360x640 + 1.3 sahne ilk ekrani', () {
    for (final tag in _tags) {
      testWidgets('D $tag', (t) async {
        final rig = Rig05f(permission: PermissionStatus.denied);
        await _boot(t, rig, catalog, tag: tag);
        expect(find.byKey(const Key('stage-play-pending')), findsNothing);
        expect(t.takeException(), isNull, reason: '$tag raf kapali');
        await _toggleShelf(t);
        expect(t.takeException(), isNull, reason: '$tag raf acik');
        await _openHelp(t);
        expect(find.byKey(const Key('ghost-help-surface')), findsOneWidget);
        expect(t.takeException(), isNull, reason: '$tag Yardim yuzeyi');
        await _toggleShelf(t);
        await _play(t);
        expect(find.byKey(const Key('stage-listening-off')), findsOneWidget);
        expect(t.takeException(), isNull, reason: '$tag Dinleme kapali bandi');
        await _toggleShelf(t);
        expect(t.takeException(), isNull, reason: '$tag bant + raf acik');
        await _toggleShelf(t);
        await _openSetup(t);
        expect(find.byKey(const Key('stage-device-settings')), findsOneWidget);
        expect(t.takeException(), isNull, reason: '$tag Ayar/Cihaz katmani');
        await dispose05f(t, rig);
      });
    }
  });
}
