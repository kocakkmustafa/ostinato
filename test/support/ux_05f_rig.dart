// OST-UX-05f shared test rig (stage + fake mic permission). Test only.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/audio/audio_capture_channel.dart';
import 'package:ostinato/app/audio/audio_input_controller.dart';
import 'package:ostinato/app/curriculum/v1_lesson.dart';
import 'package:ostinato/app/practice/loop/practice_judge.dart';
import 'package:ostinato/app/practice/loop/practice_outcome.dart';
import 'package:ostinato/app/practice/loop/practice_progress_store.dart';
import 'package:ostinato/app/practice/loop/practice_score.dart';
import 'package:ostinato/app/practice/loop/practice_session_controller.dart';
import 'package:ostinato/app/practice/loop/practice_transport.dart';
import 'package:ostinato/app/practice/loop/v1_course_catalog.dart';
import 'package:ostinato/app/practice/setup/setup_profile_store.dart';
import 'package:ostinato/app/stage/listening_off_store.dart';
import 'package:ostinato/app/stage/stage_home_screen.dart';
import 'package:permission_handler/permission_handler.dart';

import 'practice_host.dart';

final class Mem05f implements V1PracticeProgress {
  @override
  Future<Map<String, V1PracticeRecord>> load() async => {};
  @override
  Future<V1PracticeRecord> recordRun(
    String id,
    PracticeRunSummary s, {
    DateTime? at,
  }) async =>
      V1PracticeRecord(lessonId: id).withRun(s, DateTime.utc(2026, 11, 1));
}

final class Checks05f implements V1LessonChecks {
  @override
  Future<Map<String, V1LessonCheck>> load() async => {};
  @override
  Future<V1LessonCheck> record(
    String lessonId,
    V1CheckEvidence evidence, {
    DateTime? at,
  }) => throw UnimplementedError();
}

V1CourseCatalog catalog05f() {
  final files =
      Directory('content/v1/gtr').listSync().whereType<File>().toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  return V1CourseCatalog([
    for (final f in files)
      if (f.path.endsWith('.json'))
        V1Lesson.fromJson(jsonDecode(f.readAsStringSync())),
  ]);
}

class Rig05f {
  Rig05f({this.permission = PermissionStatus.granted}) {
    audio = AudioInputController(
      channel: channel,
      requestMicrophonePermission: () async {
        permissionCalls++;
        return permission;
      },
      pcmDeliveryTimeout: const Duration(minutes: 5),
    );
  }

  /// Changeable between runs (the learner allows the microphone later).
  PermissionStatus permission;

  /// Sample rates the fake channel accepts; clear it to make a start fail
  /// for a reason other than the permission.
  final Set<int> rates = <int>{44100, 48000};
  late final channel = FakeAudioCaptureChannel(supportedSampleRates: rates);
  late final AudioInputController audio;
  int permissionCalls = 0;
  PracticeSessionController? controller;
  int local = 0;
  PracticeSessionController factory(
    PracticeScore score,
    PracticeTempo tempo,
    PassCriteria criteria,
  ) => controller = PracticeSessionController(
    score: score,
    tempo: tempo,
    audio: audio,
    criteria: criteria,
    localClockUs: () => local,
    analyzer: (r) async => judgeNote(r),
  );
}

/// Counters the tests read.
class Hooks05f {
  int settingsOpened = 0;
  int setupOpened = 0;
  int appSettingsOpened = 0;
  int accountOpened = 0;
  int tunerOpened = 0;
  Future<void> Function()? onSetup;
}

Widget stage05f(
  Rig05f rig,
  V1CourseCatalog catalog, {
  Hooks05f? hooks,
  ListeningOffStore? store,
  Future<PermissionStatus> Function()? micStatus,
  SetupProfileStore? setupStore,
  String locale = 'tr',
  double textScale = 1.0,
  bool realOpeners = false,
  Widget Function(Widget)? wrap,
}) {
  final h = hooks ?? Hooks05f();
  return (wrap ?? (w) => w)(
    practiceHost(
      locale: locale,
      Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: StageHomeScreen(
            catalog: catalog,
            progressFactory: (_) => Mem05f(),
            checksFactory: (_) => Checks05f(),
            controllerFactory: rig.factory,
            seed: 1,
            setupStore: setupStore ?? MemorySetupProfileStore(),
            micStatus: micStatus,
            listeningOffStore: store ?? MemoryListeningOffStore(),
            appSettingsOpener: () async {
              h.appSettingsOpened++;
              return true;
            },
            setupOpener: realOpeners
                ? null
                : (_) async {
                    h.setupOpened++;
                    await h.onSetup?.call();
                  },
            settingsOpener: realOpeners
                ? null
                : (_) async => h.settingsOpened++,
            accountOpener: realOpeners ? null : (_) async => h.accountOpened++,
            tunerOpener: (_) async => h.tunerOpened++,
            earScreenBuilder: (_) => const Scaffold(body: Text('ear-screen')),
          ),
        ),
      ),
    ),
  );
}

Future<void> boot05f(
  WidgetTester t,
  Widget w, {
  Size size = const Size(390, 844),
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(w);
  for (var i = 0; i < 4; i++) {
    await t.pump();
  }
}

Future<void> play05f(WidgetTester t) async {
  await t.tap(find.byKey(const Key('practice-start')));
  await t.pump();
  await t.pump();
  await t.pump(const Duration(milliseconds: 50));
}

/// Feeds the fake channel until the run really listens (the metronome anchor
/// arrives and the phase is `running`).
Future<void> listen05f(WidgetTester t, Rig05f rig) async {
  final c = rig.controller!;
  var tn = 0;
  for (var i = 0; i < 60 && c.phase != PracticePhase.running; i++) {
    final x = Float64List(4800);
    rig.channel.pushChunk(x, sampleRate: 48000, tNativeUs: tn);
    tn += 100000;
    rig.local = tn;
    await t.pump();
    if (rig.channel.metronome != null && c.timeline == null) {
      rig.channel.pushMetronomeAnchor(tn + 200000);
      await t.pump();
    }
    c.tick();
    await t.pump();
  }
}

Future<void> dispose05f(WidgetTester t, Rig05f rig) async {
  await t.pumpWidget(const SizedBox());
  await t.runAsync(rig.audio.dispose);
}
