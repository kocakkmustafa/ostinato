// FLAG-CHECKLIST #7 — the default (non-injected) paths of StageHomeScreen:
// "Başka çalış" -> Ear opens the real V1PracticeListScreen, Tuner opens the
// real TunerScreen. No earScreenBuilder / tunerOpener is injected.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/audio/audio_capture_channel.dart';
import 'package:ostinato/app/audio/audio_input_controller.dart';
import 'package:ostinato/app/content.dart';
import 'package:ostinato/app/cue_text.dart';
import 'package:ostinato/app/curriculum/v1_lesson.dart';
import 'package:ostinato/app/design/app_scope.dart' as scope;
import 'package:ostinato/app/practice/loop/practice_judge.dart';
import 'package:ostinato/app/practice/loop/practice_outcome.dart';
import 'package:ostinato/app/practice/loop/practice_progress_store.dart';
import 'package:ostinato/app/practice/loop/practice_session_controller.dart';
import 'package:ostinato/app/practice/loop/v1_course_catalog.dart';
import 'package:ostinato/app/practice/loop/v1_practice_list_screen.dart';
import 'package:ostinato/app/stage/stage_home_screen.dart';
import 'package:ostinato/app/practice/setup/setup_profile_store.dart';
import 'package:ostinato/app/stage/listening_off_store.dart';
import 'package:ostinato/app/tuner/session_tuning_gate.dart';
import 'package:ostinato/app/tuner/tuner_screen.dart';
import 'package:permission_handler/permission_handler.dart';

import 'support/localized_widget_ready.dart';
import 'support/practice_host.dart';
import 'support/ux_05f_rig.dart';

final class _Memory implements V1PracticeProgress {
  @override
  Future<Map<String, V1PracticeRecord>> load() async => {};
  @override
  Future<V1PracticeRecord> recordRun(
    String id,
    PracticeRunSummary s, {
    DateTime? at,
  }) => throw UnimplementedError();
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

void main() {
  late V1CourseCatalog catalog;
  late ContentRepository repo;
  late CueTextResolver cueText;
  late AudioInputController audio;

  setUpAll(() async {
    catalog = _catalog();
    await prepareRootTranslations();
    repo = await ContentRepository.load();
    cueText = await CueTextResolver.load();
  });
  setUp(resetAudioCaptureCoordinatorForTest);

  Future<void> bootOther(WidgetTester t) async {
    audio = AudioInputController(
      channel: FakeAudioCaptureChannel(),
      requestMicrophonePermission: () async => throw StateError('no mic'),
      pcmDeliveryTimeout: const Duration(minutes: 5),
    );
    addTearDown(() => t.runAsync(audio.dispose));
    t.view.physicalSize = const Size(420, 1800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      practiceHost(
        locale: 'tr',
        scope.ContentRepositoryScope(
          repo: repo,
          cueText: cueText,
          child: StageHomeScreen(
            catalog: catalog,
            progressFactory: (_) => _Memory(),
            checksFactory: (_) => _Checks(),
            weeklyGoalLoader: () async => null,
            controllerFactory: (score, tempo, criteria) =>
                PracticeSessionController(
                  score: score,
                  tempo: tempo,
                  audio: audio,
                  criteria: criteria,
                  localClockUs: () => 0,
                  analyzer: (r) async => judgeNote(r),
                ),
            seed: 1,
          ),
        ),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await t.pump();
    }
    await t.tap(find.byKey(const Key('stage-handle-other')));
    await t.pumpAndSettle();
  }

  testWidgets('default ear path opens the real V1PracticeListScreen', (
    t,
  ) async {
    await bootOther(t);
    expect(find.byType(V1PracticeListScreen), findsNothing);
    await t.ensureVisible(find.byKey(const Key('stage-instr-ear')));
    await t.tap(find.byKey(const Key('stage-instr-ear')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(find.byType(V1PracticeListScreen), findsOneWidget);
    final list = t.widget<V1PracticeListScreen>(
      find.byType(V1PracticeListScreen),
    );
    expect(list.course, 'ear');
  });

  testWidgets('default tuner path opens the real TunerScreen', (t) async {
    await bootOther(t);
    expect(find.byType(TunerScreen), findsNothing);
    await t.ensureVisible(find.byKey(const Key('stage-tuner-entry')));
    await t.tap(find.byKey(const Key('stage-tuner-entry')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(find.byType(TunerScreen), findsOneWidget);
  });
  testWidgets('default path of the session tuning gate card opens the real '
      'TunerScreen (mic refused, no tunerOpener injected)', (t) async {
    final rig = Rig05f(permission: PermissionStatus.denied);
    addTearDown(() => t.runAsync(rig.audio.dispose));
    await boot05f(
      t,
      practiceHost(
        locale: 'tr',
        StageHomeScreen(
          catalog: catalog05f(),
          progressFactory: (_) => Mem05f(),
          checksFactory: (_) => Checks05f(),
          controllerFactory: rig.factory,
          seed: 1,
          setupStore: MemorySetupProfileStore(),
          listeningOffStore: MemoryListeningOffStore(),
          weeklyGoalLoader: () async => null,
        ),
      ),
    );
    await play05f(t);
    expect(find.byType(SessionTuningGateCard), findsOneWidget);
    expect(find.byType(TunerScreen), findsNothing);
    final tune = find.byKey(const Key('session-tuning-gate-tune'));
    await t.ensureVisible(tune);
    await t.pump();
    await t.tap(tune);
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(find.byType(TunerScreen), findsOneWidget);
  });
}
