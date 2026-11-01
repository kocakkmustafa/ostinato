// F2.2–F2.5 uçtan uca (donanımsız): sahte kanal + gerçek AudioInputController
// + metronom çapası + gerçek doğrulayıcı + sentetik tel → nota başı üç durum
// → özet ve geçiş kapısı.
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/audio/audio_capture_channel.dart';
import 'package:ostinato/app/audio/audio_input_controller.dart';
import 'package:ostinato/app/practice/loop/metronome.dart';
import 'package:ostinato/app/practice/loop/practice_judge.dart';
import 'package:ostinato/app/practice/loop/practice_marks.dart';
import 'package:ostinato/app/practice/loop/practice_outcome.dart';
import 'package:ostinato/app/practice/loop/practice_score.dart';
import 'package:ostinato/app/practice/loop/practice_session_controller.dart';
import 'package:ostinato/app/practice/loop/practice_transport.dart';
import 'package:ostinato_audio/ostinato_audio.dart';
import 'package:permission_handler/permission_handler.dart';

const rate = 48000;
const chunk = 4800; // 100 ms

double hz(int midi) => 440 * math.pow(2, (midi - 69) / 12).toDouble();

/// Room noise plus plucks at given capture times (µs → midi).
Float64List performance(int seconds, Map<int, int> plucks) {
  final out = Float64List(seconds * rate);
  final rng = math.Random(5);
  for (var i = 0; i < out.length; i++) {
    out[i] = (rng.nextDouble() * 2 - 1) * .002;
  }
  plucks.forEach((us, midi) {
    final p = SyntheticString.pluck(
      f0Hz: hz(midi),
      sampleRate: rate,
      seconds: .95,
      seed: us ~/ 1000,
    );
    final at = us * rate ~/ 1000000;
    for (var i = 0; i < p.length && at + i < out.length; i++) {
      out[at + i] += p[i];
    }
  });
  return out;
}

final class Rig {
  Rig(
    String sequence, {
    int bpm = 60,
    int target = 60,
    bool sound = true,
    NoteAnalyzer? analyzer,
  }) {
    channel = FakeAudioCaptureChannel();
    audio = AudioInputController(
      channel: channel,
      requestMicrophonePermission: () async => PermissionStatus.granted,
      // Analysis runs on the test isolate; wall-clock PCM budget is not
      // what these tests measure.
      pcmDeliveryTimeout: const Duration(minutes: 5),
    );
    controller = PracticeSessionController(
      score: PracticeScore.parse(sequence),
      tempo: PracticeTempo(openBpm: bpm, targetBpm: target),
      audio: audio,
      analyzer: analyzer ?? (r) async => judgeNote(r),
      localClockUs: () => localUs,
    )..metronomeSound = sound;
  }

  late final FakeAudioCaptureChannel channel;
  late final AudioInputController audio;
  late final PracticeSessionController controller;
  int localUs = 0;

  Future<void> play(Float64List audioData, {int anchorUs = 1000000}) async {
    await controller.start();
    for (var i = 0; i * chunk < audioData.length; i++) {
      final t = i * chunk * 1000000 ~/ rate;
      channel.pushChunk(
        audioData.sublist(i * chunk, (i + 1) * chunk),
        sampleRate: rate,
        tNativeUs: t,
      );
      localUs = t + 100000;
      await pumpEventQueue();
      if (i == 0 && controller.metronomeSound) {
        channel.pushMetronomeAnchor(anchorUs);
        await pumpEventQueue();
      }
      controller.tick();
      await pumpEventQueue();
      if (controller.phase == PracticePhase.finished) break;
    }
  }

  Future<void> close() async {
    controller.dispose();
    await audio.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(resetAudioCaptureCoordinatorForTest);

  test('three marks per note, summary and the gate (heard too low)', () async {
    final rig = Rig('E2 F2 G2 F2');
    // Anchor 1 s, count-in 4 beats at 60 BPM → lesson beat k at (5 + k) s.
    await rig.play(
      performance(11, {
        5000000: 40, // E2 ✓
        6000000: 45, // A2 instead of F2 → ◆
        // G2 not played → ◯
        8000000: 41, // F2 ✓
      }),
    );
    final c = rig.controller;
    expect(rig.channel.metronome, isNull, reason: 'stream stopped at the end');
    expect(c.phase, PracticePhase.finished);
    expect(c.timeline!.source, MetronomeAnchorSource.native);
    expect(c.outcomes.map((o) => o.mark), [
      PracticeMark.correct,
      PracticeMark.differentNote,
      PracticeMark.couldNotHear,
      PracticeMark.correct,
    ]);
    expect(c.outcomes[1].observedMidi, 45);
    expect(c.outcomes[2].reason, HearingReason.noAttack);
    final s = c.summary!;
    expect((s.correct, s.different, s.unheard), (2, 1, 1));
    expect(s.accuracy, closeTo(2 / 3, 1e-9));
    expect(s.heard, .75);
    expect(s.gate.eligible, isTrue);
    expect(s.gate.passed, isFalse);
    expect(s.nextStep, NextStep.checkSetup);
    expect(s.errorBars, [0]);
    expect(rig.channel.isRunning, isFalse);
    await rig.close();
  });

  test('a clean run at the target tempo passes the gate', () async {
    final rig = Rig('E2 F2 G2 F2');
    await rig.play(
      performance(11, {5000000: 40, 6000000: 41, 7000000: 43, 8000000: 41}),
    );
    final s = rig.controller.summary!;
    expect(s.correct, 4);
    expect(s.gate.passed, isTrue);
    expect(s.nextStep, NextStep.nextLesson);
    // Timing is never reported without latency calibration.
    expect(s.medianTimingMs, isNull);
    // Listening time for the retention event: first chunk → finish.
    expect(rig.controller.activeDuration.inMilliseconds, greaterThan(8500));
    await rig.close();
  });

  test('below the target tempo the run cannot open the next lesson', () async {
    final rig = Rig('E2 E2', bpm: 50, target: 60, sound: false);
    // Silent grid: anchor = first capture time estimate + 0.4 s.
    await rig.play(performance(14, {}));
    final c = rig.controller;
    expect(c.timeline!.source, MetronomeAnchorSource.silent);
    final s = c.summary!;
    expect(s.gate.passed, isFalse);
    expect(
      s.gate.checks.firstWhere((k) => k.kind == GateCheckKind.tempo).ok,
      isFalse,
    );
    await rig.close();
  });

  test('wait for me: holds, hint at 4 s, actions at 8 s, skip', () async {
    // Silence only: the DSP path is covered above; here only the timers.
    final rig = Rig(
      'E2 F2',
      sound: false,
      analyzer: (r) async => const NoteJudgement(
        PracticeMark.couldNotHear,
        reason: HearingReason.noAttack,
      ),
    )..controller.waitMode = true;
    final c = rig.controller;
    await c.start();
    final silence = Float64List(chunk);
    var t = 0;
    Future<void> step() async {
      rig.channel.pushChunk(silence, sampleRate: rate, tNativeUs: t);
      t += 100000;
      rig.localUs = t;
      await pumpEventQueue();
      c.tick();
      await pumpEventQueue();
    }

    // Grid: anchor ≈ 0.5 s; first note held at 0.5 + 4 s.
    while (c.heldEvent == null && t < 8000000) {
      await step();
    }
    expect(c.heldEvent, 0);
    expect(c.waitStage, WaitStage.listening);
    final heldAt = t;
    while (t < heldAt + 4100000) {
      await step();
    }
    expect(c.phase, PracticePhase.running, reason: '${c.failure}');
    expect(c.waitStage, WaitStage.hint);
    while (t < heldAt + 8100000) {
      await step();
    }
    expect(c.waitStage, WaitStage.actions);
    expect(c.heldEvent, 0, reason: 'never locks, never advances by itself');
    c.skipHeld();
    expect(c.outcomes.single.reason, HearingReason.skipped);
    expect(c.heldEvent, isNull);
    await step();
    await c.stop();
    expect(c.summary!.gate.ineligible, contains(GateIneligible.waitUsed));
    await rig.close();
  });

  test('settings are locked while running; loop bars are clamped', () async {
    final rig = Rig('E2 F2 G2 F2 | E2 F2 G2 F2');
    final c = rig.controller;
    c.loopBars = (first: 1, last: 9);
    expect(c.loopBars, (first: 1, last: 1));
    expect(c.loopRange, (start: 4.0, end: 8.0));
    await c.start();
    c.waitMode = true;
    expect(c.waitMode, isFalse);
    await c.stop();
    expect(c.phase, PracticePhase.idle);
    await rig.close();
  });

  test('referenceNote is a short bounded synthesized cue', () {
    final pcm = referenceNote(40, sampleRate: rate);
    expect(isValidCuePcm(pcm, rate), isTrue);
    expect(pcm.last.abs(), lessThan(1e-3));
  });
}
