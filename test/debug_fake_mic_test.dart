// Sahte mikrofon (yalnız debug + OSTINATO_FAKE_MIC): simülatörde gitar yokken
// kurulum ve pratik döngüsü uçtan uca görülebilsin. Gerçek zamanlı koşar:
// kalibrasyon simüle gidiş-dönüşü bulur; "mixed" kipte doğru, farklı nota ve
// duyamadım üçü de çıkar. Ürün yüzeyine sızmadığı da burada denetlenir.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/audio/audio_input_controller.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ostinato/app/practice/debug/debug_fake_mic_channel.dart';
import 'package:ostinato/app/practice/loop/practice_judge.dart';
import 'package:ostinato/app/practice/loop/practice_marks.dart';
import 'package:ostinato/app/practice/loop/practice_score.dart';
import 'package:ostinato/app/practice/loop/practice_session_controller.dart';
import 'package:ostinato/app/practice/loop/practice_transport.dart';
import 'package:ostinato/app/practice/practice_audio_input.dart';
import 'package:ostinato/app/practice/setup/audio_environment.dart';
import 'package:ostinato/app/practice/setup/latency_calibration.dart';
import 'package:ostinato/app/practice/setup/setup_audio_controller.dart';
import 'package:ostinato/app/practice/setup/setup_profile_store.dart';

/// A fake channel on a virtual clock: time advances only when the test says
/// so, so machine load cannot starve the chunk timer.
final class Clock {
  int us = 0;
}

final class _NoNative extends AudioEnvironmentProbe {
  const _NoNative();
  @override
  Future<AudioEnvironment> read() async => AudioEnvironment.unknown;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(resetAudioCaptureCoordinatorForTest);

  test('plain test runs have the fake switched off', () {
    // No --dart-define here: production capture.
    expect(kFakeMicEnabled, isFalse);
  });

  AudioInputController onFake(DebugFakeMicChannel channel) =>
      AudioInputController(
        channel: channel,
        requestMicrophonePermission: () async => PermissionStatus.granted,
        pcmDeliveryTimeout: const Duration(minutes: 5),
      );

  Future<void> advance(
    Clock clock,
    DebugFakeMicChannel channel,
    bool Function() done, {
    void Function()? each,
    int limitMs = 30000,
  }) async {
    for (var i = 0; i < limitMs ~/ 40 && !done(); i++) {
      clock.us += 40000;
      channel.pumpNow();
      await pumpEventQueue();
      each?.call();
      await pumpEventQueue();
    }
  }

  test('E50 calibration finds the simulated round trip', () async {
    final clock = Clock();
    final channel = DebugFakeMicChannel(
      mode: FakeMicMode.clean,
      clockUs: () => clock.us,
      autoPump: false,
    );
    final audio = onFake(channel);
    final store = MemorySetupProfileStore();
    final c = SetupAudioController(
      audio: audio,
      store: store,
      environment: const _NoNative(),
      estimator: (r) async => estimateRouteLatency(r),
    );
    await c.calibrateLatency();
    await advance(
      clock,
      channel,
      () =>
          c.phase == SetupAudioPhase.done || c.phase == SetupAudioPhase.failed,
    );
    expect(c.failure, isNull);
    final l = (c.latency! as LatencyMeasured).latency;
    expect(l.roundTripUs, closeTo(70000, 1000));
    expect(c.route, CalibrationRoute.speaker, reason: 'ios:BuiltInMic tag');
    expect(store.profile.lastRoute, CalibrationRoute.speaker);
    c.dispose();
    await audio.dispose();
  });

  test('mixed mode shows correct, different note and couldn\'t hear; '
      'with calibration the timing is shown', () async {
    final score = PracticeScore.parse('E2 F2 G2 F2 E2 | E2 F2 G2 F2 E2');
    final clock = Clock();
    late PracticeSessionController c;
    final channel = DebugFakeMicChannel(
      mode: FakeMicMode.mixed,
      clockUs: () => clock.us,
      autoPump: false,
      performance: () =>
          FakeMicPerformance(score: score, countInBeats: c.plan!.countInBeats),
    );
    final audio = onFake(channel);
    c = PracticeSessionController(
      score: score,
      tempo: PracticeTempo(openBpm: 60, targetBpm: 60),
      audio: audio,
      analyzer: (r) async => judgeNote(r),
      localClockUs: () => clock.us,
      setup: MemorySetupProfileStore(
        SetupProfile.empty.withLatency(
          CalibrationRoute.speaker,
          RouteLatency(
            roundTripUs: 70000,
            spreadUs: 0,
            heardClicks: 8,
            totalClicks: 8,
            measuredAt: DateTime.utc(2026, 11, 1),
          ),
        ),
      ),
      environment: const _NoNative(),
    );
    await c.start();
    await advance(
      clock,
      channel,
      () =>
          c.phase == PracticePhase.finished || c.phase == PracticePhase.failed,
      each: c.tick,
    );
    expect(c.failure, isNull);
    expect(c.phase, PracticePhase.finished);
    expect(c.timingCalibrated, isTrue);
    final marks = c.outcomes.map((o) => o.mark).toList();
    // Notes 2 (a whole tone up) and 5 (not played) by design.
    expect(marks[2], PracticeMark.differentNote, reason: '$marks');
    expect(marks[5], PracticeMark.couldNotHear, reason: '$marks');
    expect(
      marks.where((m) => m == PracticeMark.correct).length,
      8,
      reason: '$marks',
    );
    expect(c.summary!.gate.passed, isTrue, reason: '8/9 accuracy, 9/10 heard');
    expect(c.summary!.medianTimingMs, isNotNull);
    c.dispose();
    await audio.dispose();
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('free tempo (no click, "Wait for me"): the fake plays each written '
      'pitch in turn and the run finishes', () async {
    final score = PracticeScore.parse('E2 A2 D3 G3 B3 E4');
    final clock = Clock();
    late PracticeSessionController c;
    final channel = DebugFakeMicChannel(
      mode: FakeMicMode.clean,
      clockUs: () => clock.us,
      autoPump: false,
      performance: () => FakeMicPerformance(
        score: score,
        countInBeats: 4,
        heldMidi: c.heldEvent == null ? null : score.events[c.heldEvent!].midi,
      ),
    );
    final audio = onFake(channel);
    c = PracticeSessionController(
      score: score,
      tempo: PracticeTempo(openBpm: 60, targetBpm: 60),
      audio: audio,
      freeTempo: true,
      analyzer: (r) async => judgeNote(r),
      localClockUs: () => clock.us,
      setup: MemorySetupProfileStore(),
      environment: const _NoNative(),
    );
    await c.start();
    await advance(
      clock,
      channel,
      () =>
          c.phase == PracticePhase.finished || c.phase == PracticePhase.failed,
      each: c.tick,
      limitMs: 30000,
    );
    expect(c.failure, isNull);
    expect(c.phase, PracticePhase.finished);
    expect(
      c.outcomes.map((o) => o.mark),
      everyElement(PracticeMark.correct),
    );
    c.dispose();
    await audio.dispose();
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('the fake never reaches the product surface', () {
    final debugImports = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final src = f.readAsStringSync();
      if (src.contains('debug_fake_mic_channel.dart')) debugImports.add(f.path);
    }
    // Only the factory imports it …
    expect(debugImports, ['lib/app/practice/practice_audio_input.dart']);
    final factory = File(
      'lib/app/practice/practice_audio_input.dart',
    ).readAsStringSync();
    // … behind compile-time constants that are false in release …
    expect(
      factory,
      contains(
        'const bool kFakeMicEnabled =\n    kDebugMode && _fakeMicDefine != \'\'',
      ),
    );
    expect(factory, contains("String.fromEnvironment('OSTINATO_FAKE_MIC')"));
    // … and every function that touches it checks the switch first.
    final bodies = RegExp(
      r'^[A-Za-z].*\{\n([\s\S]*?)^\}',
      multiLine: true,
    ).allMatches(factory);
    for (final b in bodies) {
      final body = b.group(1)!;
      final use = RegExp(
        r'debugFakeMicInput|FakeMicPerformance\(',
      ).firstMatch(body);
      if (use == null) continue;
      final guard = body.indexOf('if (kFakeMicEnabled)');
      expect(guard, greaterThanOrEqualTo(0), reason: b.group(0));
      expect(guard, lessThan(use.start), reason: b.group(0));
    }
    // The fake has no user-visible text.
    final fake = File(
      'lib/app/practice/debug/debug_fake_mic_channel.dart',
    ).readAsStringSync();
    expect(fake, isNot(contains('localized(')));
    expect(fake, isNot(contains('uiText(')));
    expect(fake, isNot(contains('Text(')));
  });
}
