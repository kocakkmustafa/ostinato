import 'package:ostinato_audio/ostinato_audio.dart';
import 'package:test/test.dart';

const sampleRate = 44100;

PitchReading reading({
  double? f0,
  double periodicity = 0.9,
  double rmsDb = -20,
  int tStartUs = 1000000,
}) =>
    PitchReading(
      tStartUs: tStartUs,
      tEndUs: tStartUs + 90000,
      f0Hz: f0,
      periodicity: periodicity,
      rmsDb: rmsDb,
    );

void main() {
  group('AudioConfidenceGate — three states, not two', () {
    const gate = AudioConfidenceGate();
    const floor = -50.0;

    test('a clean periodic window may be judged', () {
      final r = gate.evaluate(reading(f0: 220), roomFloorDb: floor);
      expect(r.verdict, AudioVerdict.reliable);
      expect(r.mayJudge, isTrue);
    });

    test('a window just above the room floor is refused, with a reason', () {
      final r = gate.evaluate(reading(f0: 220, rmsDb: -47), roomFloorDb: floor);
      expect(r.verdict, AudioVerdict.unreliable);
      expect(r.reason, AudioGateReason.tooQuiet);
      expect(r.mayJudge, isFalse);
    });

    test('the attack window is a transition, not a failure', () {
      // A note that started 40 ms ago: the signal may look fine but the first
      // milliseconds of a bow or a breath are aperiodic. We collect, we do not
      // judge — and crucially this is NOT reported to the user as a problem.
      final r = gate.evaluate(
        reading(f0: 220, tStartUs: 1040000),
        roomFloorDb: floor,
        lastOnsetTUs: 1000000,
      );
      expect(r.verdict, AudioVerdict.transition);
      expect(r.reason, AudioGateReason.attackWindow);
      expect(r.mayJudge, isFalse);
    });

    test('once past the attack window the same note may be judged', () {
      final r = gate.evaluate(
        reading(f0: 220, tStartUs: 1150000),
        roomFloorDb: floor,
        lastOnsetTUs: 1000000,
      );
      expect(r.verdict, AudioVerdict.reliable);
    });

    test('low periodicity is refused rather than guessed', () {
      final r = gate.evaluate(reading(f0: 220, periodicity: 0.2), roomFloorDb: floor);
      expect(r.reason, AudioGateReason.notPeriodic);
    });

    test('the coach speaking silences judgement (V1 defence is a time gate, not AEC)', () {
      final r = gate.evaluate(reading(f0: 220), roomFloorDb: floor, coachSpeaking: true);
      expect(r.reason, AudioGateReason.coachSpeaking);
    });

    test('a note far from what the drill asked for is refused, not scored as wrong', () {
      final r = gate.evaluate(reading(f0: 440), roomFloorDb: floor, expectedHz: 220);
      expect(r.reason, AudioGateReason.outOfExpectedRange);
    });

    test('the gate is relative to the measured room, not an absolute level', () {
      // Same signal level, two rooms. A quiet room lets it through; a noisy one
      // does not. A fixed dBFS threshold could not express this, and phone
      // microphones vary by more than any fixed number could survive.
      final quiet = gate.evaluate(reading(f0: 220, rmsDb: -40), roomFloorDb: -60);
      final noisy = gate.evaluate(reading(f0: 220, rmsDb: -40), roomFloorDb: -38);
      expect(quiet.mayJudge, isTrue);
      expect(noisy.mayJudge, isFalse);
    });
  });

  group('OnsetDetector', () {
    test('finds four notes at the times they were played', () {
      const played = [0.20, 0.70, 1.20, 1.70];
      final signal = SyntheticTone.notesAt(
        onsetSeconds: played,
        f0Hz: ReferencePitches.a4,
        sampleRate: sampleRate,
        totalSeconds: 2.2,
      );
      final onsets =
          OnsetDetector().detect(signal, sampleRate: sampleRate, tStartUs: 0);

      expect(onsets.length, played.length);
      for (var i = 0; i < played.length; i++) {
        final detectedMs = onsets[i].tUs / 1000.0;
        final playedMs = played[i] * 1000;
        // 30 ms is roughly a demisemiquaver at 120 bpm — tight enough to judge
        // timing with, loose enough to survive the analysis hop size.
        expect((detectedMs - playedMs).abs(), lessThan(30),
            reason: 'onset ${i + 1} drifted too far from when it was played');
      }
    });

    test('silence produces no onsets', () {
      final noise = SyntheticTone.roomNoise(sampleRate: sampleRate, seconds: 1.5);
      final onsets = OnsetDetector().detect(noise, sampleRate: sampleRate, tStartUs: 0);
      expect(onsets, isEmpty);
    });
  });

  group('MetronomeAligner', () {
    const aligner = MetronomeAligner();
    // 120 bpm = a beat every 500 ms.
    final beats = [500000, 1000000, 1500000, 2000000];

    List<Onset> onsetsAtMs(List<int> ms) =>
        [for (final t in ms) Onset(tUs: t * 1000, strength: 1)];

    test('a student on the beat reports centred with a small median', () {
      final report = aligner.align(
        onsets: onsetsAtMs([503, 998, 1504, 1999]),
        beatTimesUs: beats,
      );
      expect(report.matchedBeats, 4);
      expect(report.coverage, 1.0);
      expect(report.medianMs, lessThan(10));
      expect(report.bias, TimingBias.centred);
    });

    test('a consistently early student is called rushing, not inaccurate', () {
      // Steadily 40 ms early: the median is large but the spread is tiny. These
      // are different lessons ("you are ahead of the click" vs "you are
      // inconsistent") and the report must be able to tell them apart.
      final report = aligner.align(
        onsets: onsetsAtMs([460, 961, 1459, 1962]),
        beatTimesUs: beats,
      );
      expect(report.bias, TimingBias.rushing);
      expect(report.medianMs, greaterThan(30));
      expect(report.spreadMs, lessThan(15), reason: 'a steady bias is not a spread');
    });

    test('a scattered student shows a wide spread even when centred', () {
      final report = aligner.align(
        onsets: onsetsAtMs([440, 1055, 1460, 2050]),
        beatTimesUs: beats,
      );
      expect(report.bias, TimingBias.centred);
      expect(report.spreadMs, greaterThan(40));
    });

    test('a stray sound far from any beat is ignored, not counted as very late', () {
      // A cough between beats would otherwise be matched to the nearest beat
      // and poison the median with a 200 ms "error" the student never played.
      final report = aligner.align(
        onsets: onsetsAtMs([500, 1000, 1250, 1500, 2000]),
        beatTimesUs: beats,
      );
      expect(report.matchedBeats, 4);
      expect(report.medianMs, lessThan(10));
    });

    test('missed beats lower coverage instead of being scored as perfect', () {
      final report = aligner.align(onsets: onsetsAtMs([500, 1500]), beatTimesUs: beats);
      expect(report.matchedBeats, 2);
      expect(report.coverage, 0.5);
    });

    test('nothing played at all yields an empty report, not a zero score', () {
      final report = aligner.align(onsets: const [], beatTimesUs: beats);
      expect(report.matchedBeats, 0);
      expect(report.coverage, 0);
      expect(report.deviations, isEmpty);
    });
  });

  group('End to end: played notes judged against a metronome', () {
    test('pitch, onsets and timing agree on a four-note drill', () {
      const played = [0.50, 1.00, 1.50, 2.00];
      final signal = SyntheticTone.notesAt(
        onsetSeconds: played,
        f0Hz: ReferencePitches.d3,
        sampleRate: sampleRate,
        totalSeconds: 2.5,
      );

      final onsets = OnsetDetector().detect(signal, sampleRate: sampleRate, tStartUs: 0);
      final report = const MetronomeAligner().align(
        onsets: onsets,
        beatTimesUs: [for (final s in played) (s * 1000000).round()],
      );
      expect(report.coverage, 1.0);
      expect(report.medianMs, lessThan(30));

      // And the note itself is identified, with the gate willing to judge it.
      final source = YinPitchSource(expectedHzPrior: ReferencePitches.d3);
      final windowStart = (sampleRate * 0.65).round();
      final r = source.analyze(
        signal.sublist(windowStart, windowStart + 4096),
        sampleRate: sampleRate,
        tStartUs: (0.65 * 1000000).round(),
      );
      expect(r.hasPitch, isTrue);
      expect(absCents(r.f0Hz!, ReferencePitches.d3), lessThan(25));

      final verdict = const AudioConfidenceGate().evaluate(
        r,
        roomFloorDb: -60,
        lastOnsetTUs: onsets.first.tUs,
        expectedHz: ReferencePitches.d3,
      );
      expect(verdict.mayJudge, isTrue);
    });
  });
}
