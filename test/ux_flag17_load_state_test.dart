// FLAG-CHECKLIST #17 — sahne "yukleme hatasi" ile "olculen ders yok" ayni
// durum degildir. Hata: dürüst hata + Tekrar dene. Gercekten olculen ders
// yoksa: hata degil, yeniden deneme sunmayan ayri durum. Her ikisinde de
// ilerleme / seri iddiasi yok, Cal pasif (fail-closed).
// Beklenen metinler LITERAL.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/course_access.dart';
import 'package:ostinato/app/curriculum/v1_lesson.dart';
import 'package:ostinato/app/practice/loop/practice_outcome.dart';
import 'package:ostinato/app/practice/loop/practice_progress_store.dart';
import 'package:ostinato/app/practice/loop/v1_course_catalog.dart';
import 'package:ostinato/app/practice/setup/setup_profile_store.dart';
import 'package:ostinato/app/stage/ghost_store.dart';
import 'package:ostinato/app/stage/listening_off_store.dart';
import 'package:ostinato/app/stage/stage_home_screen.dart';
import 'package:permission_handler/permission_handler.dart';

import 'support/practice_host.dart';
import 'support/ux_05f_rig.dart';

const _loadError = 'Çalışman yüklenemedi.';
const _noLesson = 'Bu sürümde ölçülü ders yok.';
const _retry = 'Tekrar dene';

final class _Failing implements V1PracticeProgress {
  @override
  Future<Map<String, V1PracticeRecord>> load() =>
      Future<Map<String, V1PracticeRecord>>.error(StateError('read failed'));
  @override
  Future<V1PracticeRecord> recordRun(
    String id,
    PracticeRunSummary s, {
    DateTime? at,
  }) => throw UnimplementedError();
}

final class _Empty implements V1PracticeProgress {
  @override
  Future<Map<String, V1PracticeRecord>> load() async => {};
  @override
  Future<V1PracticeRecord> recordRun(
    String id,
    PracticeRunSummary s, {
    DateTime? at,
  }) => throw UnimplementedError();
}

Future<void> _boot(
  WidgetTester t,
  Rig05f rig,
  V1CourseCatalog catalog,
  V1PracticeProgress progress, {
  bool paid = false,
  Future<bool> Function()? paidCheck,
}) async {
  t.view.physicalSize = const Size(420, 900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(
    practiceHost(
      locale: 'tr',
      StageHomeScreen(
        catalog: catalog,
        progressFactory: (_) => progress,
        checksFactory: (_) => Checks05f(),
        controllerFactory: rig.factory,
        seed: 1,
        paidFeaturesAvailable: paid,
        paidAccessCheck: paidCheck,
        setupStore: MemorySetupProfileStore(),
        listeningOffStore: MemoryListeningOffStore(),
        ghostStore: MemoryGhostStore(),
        micStatus: () async => PermissionStatus.granted,
        weeklyGoalLoader: () async => null,
      ),
    ),
  );
  for (var i = 0; i < 8; i++) {
    await t.pump();
  }
}

bool _playDisabled(WidgetTester t) =>
    t
        .widget<FilledButton>(find.byKey(const Key('stage-play-pending')))
        .onPressed ==
    null;

void main() {
  late V1CourseCatalog catalog;
  setUpAll(() => catalog = catalog05f());

  testWidgets('17 okuma hatasi: hata + Tekrar dene; "olculen ders yok" degil', (
    t,
  ) async {
    final rig = Rig05f();
    await _boot(t, rig, catalog, _Failing());
    expect(find.byKey(const Key('stage-load-error')), findsOneWidget);
    expect(find.text(_loadError), findsOneWidget);
    expect(find.byKey(const Key('stage-retry')), findsOneWidget);
    expect(find.text(_retry), findsOneWidget);
    expect(find.byKey(const Key('stage-no-lesson')), findsNothing);
    expect(find.text(_noLesson), findsNothing);
    expect(_playDisabled(t), isTrue);
    await dispose05f(t, rig);
  });

  testWidgets('17 gercekten olculen ders yok: hata degil, yeniden deneme yok', (
    t,
  ) async {
    final rig = Rig05f();
    await _boot(t, rig, V1CourseCatalog(const []), _Empty());
    expect(find.byKey(const Key('stage-no-lesson')), findsOneWidget);
    expect(find.text(_noLesson), findsOneWidget);
    expect(find.byKey(const Key('stage-load-error')), findsNothing);
    expect(find.text(_loadError), findsNothing);
    expect(find.byKey(const Key('stage-retry')), findsNothing);
    // Fail-closed: no progress / streak claim, Play stays off.
    expect(find.byKey(const Key('stage-play-pending')), findsOneWidget);
    expect(_playDisabled(t), isTrue);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await dispose05f(t, rig);
  });

  // Every measured lesson of this catalog is paid (stage s2 and later).
  V1CourseCatalog paidOnly() {
    final measured = {
      for (final l in catalog.lessons)
        if (l.availability == V1LessonAvailability.measured) l.id,
    };
    return V1CourseCatalog(
      [
        for (final f
            in Directory('content/v1/gtr').listSync().whereType<File>().toList()
              ..sort((a, b) => a.path.compareTo(b.path)))
          if (f.path.endsWith('.json'))
            V1Lesson.fromJson(jsonDecode(f.readAsStringSync())),
      ].where(
        (l) =>
            measured.contains(l.id) &&
            !isFreeV1Lesson(l.id, paidFeaturesAvailable: true),
      ),
    );
  }

  testWidgets('17 hepsi ucretli + uyelik sorgusu hata: HATA yolu (bos degil)', (
    t,
  ) async {
    final rig = Rig05f();
    final c = paidOnly();
    expect(c.lessons, isNotEmpty);
    await _boot(
      t,
      rig,
      c,
      _Empty(),
      paid: true,
      paidCheck: () => Future<bool>.error(StateError('membership read failed')),
    );
    expect(find.byKey(const Key('stage-load-error')), findsOneWidget);
    expect(find.byKey(const Key('stage-retry')), findsOneWidget);
    expect(find.byKey(const Key('stage-no-lesson')), findsNothing);
    expect(find.text(_noLesson), findsNothing);
    await dispose05f(t, rig);
  });

  testWidgets('17 hepsi ucretli + uyelik sorunsuz (uye degil): ders yok', (
    t,
  ) async {
    final rig = Rig05f();
    final c = paidOnly();
    expect(c.lessons, isNotEmpty);
    await _boot(t, rig, c, _Empty(), paid: true, paidCheck: () async => false);
    expect(find.byKey(const Key('stage-no-lesson')), findsOneWidget);
    expect(find.byKey(const Key('stage-load-error')), findsNothing);
    expect(find.byKey(const Key('stage-retry')), findsNothing);
    await dispose05f(t, rig);
  });
}
