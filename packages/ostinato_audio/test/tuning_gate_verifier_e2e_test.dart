import 'dart:math' as math;

import 'package:ostinato_audio/ostinato_audio.dart';
import 'package:test/test.dart';

const sr = 48000;
double hz(num midi) => 440 * math.pow(2, (midi - 69) / 12).toDouble();

/// One plucked note through the quiet simulated phone channel.
List<double> played(double f0, {required double seconds, int seed = 1}) =>
    PhoneChannel.apply(
      SyntheticString.pluck(
          f0Hz: f0,
          sampleRate: sr,
          seconds: seconds,
          inharmonicityB: 1.5e-4,
          preRollSeconds: 0.15,
          seed: seed),
      sr,
      const PhoneChannelConfig(
          noise: ChannelNoise.pink, snrDb: 35, lowCutHz: 100, agc: true),
      seed: seed,
    );

void main() {
  test('tuning gate measures the guitar, the verifier uses that offset', () {
    // The whole guitar sits 42 cents sharp: near the half-semitone edge where
    // E25 saw neighbouring-note confusion.
    const detune = 42.0;
    final open = played(hz(45) * math.pow(2, detune / 1200), seconds: 1.8);
    final tuning = PreciseTuner().measure(open, sampleRate: sr).measurement!;
    expect(tuning.midi, 45);
    expect(tuning.centsFromNearest, closeTo(detune, 1));

    final verifier = GuitarNoteVerifier();
    for (final (midi, seed) in [(52, 2), (57, 3), (64, 4)]) {
      final note = played(hz(midi) * math.pow(2, detune / 1200),
          seconds: 0.7, seed: seed);
      final withGate = verifier.verify(note,
          sampleRate: sr,
          expectedMidi: midi,
          tuningOffsetCents: tuning.centsFromNearest);
      expect(withGate.verdict, NoteVerdict.correct, reason: 'midi $midi');
      // A wrong fret is still caught after the offset is applied.
      final wrong = verifier.verify(note,
          sampleRate: sr,
          expectedMidi: midi + 1,
          tuningOffsetCents: tuning.centsFromNearest);
      expect(wrong.verdict, NoteVerdict.differentNote,
          reason: 'midi $midi + 1');
    }
  });

  test('a guitar far out of tune is reported by the gate, not blamed per note',
      () {
    // 48 cents flat: the nearest-note reading flips sign near ±50, so the
    // gate's |cents| > 30 "tune first" band is what protects the learner.
    final open = played(hz(40) * math.pow(2, -48 / 1200), seconds: 1.8);
    final m = PreciseTuner().measure(open, sampleRate: sr).measurement!;
    expect(m.centsFromNearest.abs(), greaterThan(30));
  });
}
