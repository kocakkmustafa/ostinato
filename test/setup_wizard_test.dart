// F4.2 kurulum sihirbazı ekranı ve pratik ekranına bağlantısı: adımlar
// atlanabilir, sonuçlar yerel; uyarılar yalnız algılanınca; kalibrasyon
// varsa rozet kalkar; oturum başında akort kapısı kartı görünür.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/audio/audio_capture_channel.dart';
import 'package:ostinato/app/audio/audio_input_controller.dart';
import 'package:ostinato/app/curriculum/v1_lesson.dart';
import 'package:ostinato/app/practice/loop/practice_loop_screen.dart';
import 'package:ostinato/app/practice/loop/practice_outcome.dart';
import 'package:ostinato/app/practice/loop/practice_progress_store.dart';
import 'package:ostinato/app/practice/loop/practice_session_controller.dart';
import 'package:ostinato/app/practice/setup/audio_environment.dart';
import 'package:ostinato/app/practice/setup/latency_calibration.dart';
import 'package:ostinato/app/practice/setup/setup_profile_store.dart';
import 'package:ostinato/app/practice/setup/setup_wizard_screen.dart';
import 'package:ostinato/app/tuner/tuner_check_memory.dart';
import 'package:permission_handler/permission_handler.dart';

import 'support/practice_host.dart';

final class _Probe extends AudioEnvironmentProbe {
  const _Probe(this.env);
  final AudioEnvironment env;
  @override
  Future<AudioEnvironment> read() async => env;
}

final class _Progress implements V1PracticeProgress {
  @override
  Future<Map<String, V1PracticeRecord>> load() async => {};
  @override
  Future<V1PracticeRecord> recordRun(
    String id,
    PracticeRunSummary s, {
    DateTime? at,
  }) async => V1PracticeRecord(lessonId: id).withRun(s, DateTime.utc(2026));
}

AudioInputController _audio() => AudioInputController(
  channel: FakeAudioCaptureChannel(),
  requestMicrophonePermission: () async => PermissionStatus.granted,
);

void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(420, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  setUp(resetAudioCaptureCoordinatorForTest);

  testWidgets('every step can be skipped; the profile remembers it', (
    tester,
  ) async {
    _tall(tester);
    final store = MemorySetupProfileStore();
    await tester.pumpWidget(
      practiceHost(
        SetupWizardScreen(
          store: store,
          audioFactory: _audio,
          environment: const _Probe(AudioEnvironment.unknown),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Step 1 of 4 · Placement'), findsOneWidget);
    expect(
      find.textContaining('Headphones are recommended, not required'),
      findsOneWidget,
    );
    for (final name in ['Room and level', 'Latency', 'Tuning']) {
      await tester.tap(find.byKey(const Key('setup-skip')));
      await tester.pumpAndSettle();
      expect(find.textContaining(name), findsWidgets);
    }
    await tester.tap(find.byKey(const Key('setup-skip')));
    await tester.pumpAndSettle();
    expect(find.text('Done'), findsWidgets);
    final p = store.profile;
    expect(p.visited, isTrue);
    expect(p.placement!.state, SetupStepState.skipped);
    expect(p.tuningStep!.state, SetupStepState.skipped);
    expect(p.latency, isEmpty);
  });

  testWidgets('iOS warnings: one line each, only when detected (Turkish)', (
    tester,
  ) async {
    _tall(tester);
    await tester.pumpWidget(
      practiceHost(
        locale: 'tr',
        SetupWizardScreen(
          store: MemorySetupProfileStore(),
          audioFactory: _audio,
          environment: const _Probe(
            AudioEnvironment(
              platform: 'ios',
              inputPorts: ['HeadsetMic'],
              outputPorts: ['Headphones'],
              micMode: MicMode.voiceIsolation,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('setup-warning-voiceIsolation')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('setup-warning-headsetMic')), findsOneWidget);
    expect(find.byKey(const Key('setup-warning-wideSpectrum')), findsNothing);
    // Sound Recognition has no public API: a conditional tip on iOS.
    expect(find.byKey(const Key('setup-sound-recognition')), findsOneWidget);
    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => (t.data ?? '').toLowerCase());
    for (final t in texts) {
      expect(t, isNot(contains('yanlış')));
    }
  });

  testWidgets('tuning step opens the tuner and shows today\'s result', (
    tester,
  ) async {
    _tall(tester);
    final store = MemorySetupProfileStore();
    await tester.pumpWidget(
      practiceHost(
        SetupWizardScreen(
          start: SetupStep.tuning,
          store: store,
          audioFactory: _audio,
          environment: const _Probe(AudioEnvironment.unknown),
          tune: (_) async => TunerCheck(
            presetId: 'guitar.standard',
            inTune: 5,
            total: 6,
            at: DateTime(2026, 11, 1),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('setup-primary')));
    await tester.pumpAndSettle();
    expect(find.text('In tune: 5 of 6 strings'), findsOneWidget);
    await tester.tap(find.byKey(const Key('setup-primary')));
    await tester.pumpAndSettle();
    expect(store.profile.tuningStep!.state, SetupStepState.done);
  });

  group('practice screen', () {
    V1Lesson lesson([String id = 'gtr-s1-m02-02']) => V1Lesson.fromJson(
      jsonDecode(File('content/v1/gtr/$id.json').readAsStringSync()),
    );

    Future<List<SetupStep>> pump(
      WidgetTester tester,
      SetupProfileStore store, {
      String lessonId = 'gtr-s1-m02-02',
    }) async {
      _tall(tester);
      final opened = <SetupStep>[];
      final audio = _audio();
      await tester.pumpWidget(
        practiceHost(
          PracticeLoopScreen(
            lesson: lesson(lessonId),
            progress: _Progress(),
            setupStore: store,
            openSetup: (_, step) async => opened.add(step),
            controllerFactory: (score, tempo, criteria) =>
                PracticeSessionController(
                  score: score,
                  tempo: tempo,
                  audio: audio,
                  criteria: criteria,
                ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return opened;
    }

    testWidgets('no calibration: badge shown and opens the latency step', (
      tester,
    ) async {
      final opened = await pump(tester, MemorySetupProfileStore());
      expect(
        find.byKey(const Key('practice-calibration-badge')),
        findsOneWidget,
      );
      // Contract §5 rule 2: the session-start tuning gate card (F4.1).
      expect(find.byKey(const Key('session-tuning-gate')), findsOneWidget);
      await tester.tap(find.byKey(const Key('practice-calibration-badge')));
      await tester.pumpAndSettle();
      expect(opened, [SetupStep.latency]);
    });

    testWidgets('calibrated last route: the badge is gone', (tester) async {
      await pump(
        tester,
        MemorySetupProfileStore(
          SetupProfile.empty.withLatency(
            CalibrationRoute.speaker,
            RouteLatency(
              roundTripUs: 64000,
              spreadUs: 100,
              heardClicks: 8,
              totalClicks: 8,
              measuredAt: DateTime.utc(2026, 11, 1),
            ),
          ),
        ),
      );
      expect(find.byKey(const Key('practice-calibration-badge')), findsNothing);
    });

    testWidgets('free tempo (no click, timing not judged): no badge', (
      tester,
    ) async {
      expect(lesson('gtr-s1-m01-04').practice.tempo, isNull);
      await pump(
        tester,
        MemorySetupProfileStore(),
        lessonId: 'gtr-s1-m01-04',
      );
      expect(find.byKey(const Key('practice-calibration-badge')), findsNothing);
    });

    testWidgets('another route calibrated only: the badge stays', (
      tester,
    ) async {
      await pump(
        tester,
        MemorySetupProfileStore(
          SetupProfile.empty
              .withLatency(
                CalibrationRoute.bluetooth,
                RouteLatency(
                  roundTripUs: 210000,
                  spreadUs: 100,
                  heardClicks: 8,
                  totalClicks: 8,
                  measuredAt: DateTime.utc(2026, 11, 1),
                ),
              )
              .copyWith(lastRoute: CalibrationRoute.speaker),
        ),
      );
      expect(
        find.byKey(const Key('practice-calibration-badge')),
        findsOneWidget,
      );
    });
  });
}
