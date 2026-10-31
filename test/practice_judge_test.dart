// F2.4 — nota başı üç durum: gerçek doğrulayıcı + sentetik tel, pencere,
// tampon, mikrofon şeridi ve "duyamadım" kuralları.
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/practice/loop/metronome.dart';
import 'package:ostinato/app/practice/loop/practice_judge.dart';
import 'package:ostinato/app/practice/loop/practice_marks.dart';
import 'package:ostinato/app/practice/loop/practice_score.dart';
import 'package:ostinato_audio/ostinato_audio.dart';

const rate = 48000;

double hz(int midi) => 440 * math.pow(2, (midi - 69) / 12).toDouble();

/// 1.4 s of buffer: 0.3 s room noise, then a pluck at [atMs].
Float64List take({
  int? midi,
  int atMs = 400,
  double noise = .002,
  int seed = 3,
}) {
  final out = Float64List((1.4 * rate).round());
  final rng = math.Random(seed);
  for (var i = 0; i < out.length; i++) {
    out[i] = (rng.nextDouble() * 2 - 1) * noise;
  }
  if (midi != null) {
    final pluck = SyntheticString.pluck(
      f0Hz: hz(midi),
      sampleRate: rate,
      seconds: .9,
      seed: seed,
    );
    final at = atMs * rate ~/ 1000;
    for (var i = 0; i < pluck.length && at + i < out.length; i++) {
      out[at + i] += pluck[i];
    }
  }
  return out;
}

NoteJudgeRequest request(
  Float64List x, {
  int? midi = 40,
  PracticeEventKind kind = PracticeEventKind.pitch,
  bool playback = false,
}) => NoteJudgeRequest(
  samples: x,
  sampleRate: rate,
  kind: kind,
  expectedMidi: midi,
  expectedIndex: 400 * rate ~/ 1000,
  searchFrom: 240 * rate ~/ 1000,
  searchTo: 660 * rate ~/ 1000,
  analysisMs: 320,
  roomFloorDb: -54,
  playback: playback,
);

void main() {
  group('judgeNote (real verifier, synthetic string)', () {
    test('the expected note is correct', () {
      for (final midi in [40, 41, 43]) {
        final j = judgeNote(request(take(midi: midi), midi: midi));
        expect(j.mark, PracticeMark.correct, reason: '$midi');
        expect(
          (j.attackIndex! - 400 * rate ~/ 1000).abs(),
          lessThan(rate ~/ 50),
        );
      }
    });

    test('another note is a different note, with what was heard', () {
      final j = judgeNote(request(take(midi: 45), midi: 41));
      expect(j.mark, PracticeMark.differentNote);
      expect(j.observedMidi, 45);
    });

    test('silence never counts as correct', () {
      final j = judgeNote(request(take()));
      expect(j.mark, PracticeMark.couldNotHear);
      expect(j.reason, HearingReason.noAttack);
    });

    test('a pluck outside the window is not this note', () {
      final j = judgeNote(request(take(midi: 40, atMs: 900)));
      expect(j.mark, PracticeMark.couldNotHear);
      expect(j.reason, HearingReason.noAttack);
    });

    test('app playback audible → could not hear, never a verdict', () {
      final j = judgeNote(request(take(midi: 40), playback: true));
      expect(j.mark, PracticeMark.couldNotHear);
      expect(j.reason, HearingReason.appPlayback);
    });

    test('rhythm onsets need an attack; degrees have no engine here', () {
      expect(
        judgeNote(request(take(midi: 40), kind: PracticeEventKind.onset)).mark,
        PracticeMark.correct,
      );
      expect(
        judgeNote(request(take(), kind: PracticeEventKind.onset)).mark,
        PracticeMark.couldNotHear,
      );
      expect(
        judgeNote(
          request(take(midi: 40), kind: PracticeEventKind.degree, midi: null),
        ).mark,
        PracticeMark.couldNotHear,
      );
    });
  });

  group('CaptureBuffer', () {
    test('slices on the capture clock, filters the 6 kHz click', () {
      final buffer = CaptureBuffer();
      final click = ClickTrackRenderer(
        MetronomePlan(bpm: 120, sampleRate: rate),
        MetronomeClicks.forSampleRate(rate),
      ).render(0, rate);
      for (var i = 0; i < 10; i++) {
        buffer.push(
          AudioChunk(
            samples: click.sublist(i * 4800, (i + 1) * 4800),
            sampleRate: rate,
            tStartUs: 1000000 + i * 100000,
            clockDomain: AudioClockDomain.monotonic,
            playbackActive: i == 7,
          ),
        );
      }
      final s = buffer.slice(1000000, 1500000);
      expect(s.samples.length, rate ~/ 2);
      expect(s.playback, isFalse);
      // The click is attenuated by the reject filter (≥ 20 dB).
      expect(
        CaptureBuffer.rmsDb(s.samples),
        lessThan(CaptureBuffer.rmsDb(click.sublist(0, rate ~/ 2)) - 20),
      );
      expect(buffer.slice(1600000, 1900000).playback, isTrue);
      expect(s.indexOf(1250000), rate ~/ 4);
      buffer.clear();
      expect(buffer.isEmpty, isTrue);
    });
  });

  test('NoteWindow: wide when alone, never past half the gap', () {
    final alone = NoteWindow.forNote(expectedUs: 0, durationUs: 1000000);
    expect(alone.searchFromUs, -160000);
    expect(alone.searchToUs, 260000);
    expect(alone.analysisMs, 320);
    final tight = NoteWindow.forNote(
      expectedUs: 0,
      durationUs: 250000,
      prevGapUs: 250000,
      nextGapUs: 250000,
    );
    expect(tight.searchFromUs, -125000);
    expect(tight.searchToUs, 125000);
    expect(tight.analysisMs, 170);
    expect(tight.readyAtUs, 125000 + (80 + 170 + 40) * 1000);
  });

  group('HearingMonitor', () {
    const unheard = NoteJudgement(
      PracticeMark.couldNotHear,
      reason: HearingReason.noAttack,
    );
    const ok = NoteJudgement(PracticeMark.correct);

    test('three in a row bring the setup card; snoozed 5 min', () {
      final m = HearingMonitor();
      m.observe(unheard, 0);
      m.observe(unheard, 1);
      expect(m.setupCardDue, isFalse);
      m.observe(ok, 2);
      m.observe(unheard, 3);
      m.observe(unheard, 4);
      m.observe(unheard, 5);
      expect(m.setupCardDue, isTrue);
      m.dismissSetupCard(10);
      for (var i = 0; i < 3; i++) {
        m.observe(unheard, 20 + i);
      }
      expect(m.setupCardDue, isFalse);
      for (var i = 0; i < 3; i++) {
        m.observe(unheard, 10 + 5 * 60 * 1000000 + i);
      }
      expect(m.setupCardDue, isTrue);
    });

    test('more than 25 % unheard over 8+ notes also brings it', () {
      final m = HearingMonitor();
      for (var i = 0; i < 9; i++) {
        m.observe(i % 3 == 0 ? unheard : ok, i);
      }
      expect(m.setupCardDue, isTrue);
    });

    test('strip: silent / hearing / hearing but unclear', () {
      final m = HearingMonitor()..roomFloorDb = -60;
      m.observeLevel(-58);
      expect(m.state(0), MicStripState.silent);
      m.observeLevel(-30);
      expect(m.state(0), MicStripState.hearing);
      m.observe(
        const NoteJudgement(
          PracticeMark.couldNotHear,
          reason: HearingReason.unclear,
        ),
        100,
      );
      expect(m.state(200), MicStripState.unclear);
      expect(m.state(100 + 1600000), MicStripState.hearing);
      expect(m.meter, closeTo(.833, .01));
      expect(HearingMonitor.floorOf([-50, -70, -60]), -60);
    });
  });

  test('wait stages: 4 s hint, 8 s actions', () {
    expect(waitStageOf(3999999), WaitStage.listening);
    expect(waitStageOf(4000000), WaitStage.hint);
    expect(waitStageOf(8000000), WaitStage.actions);
  });
}
