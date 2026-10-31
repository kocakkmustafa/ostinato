import 'dart:math' as math;

import 'package:ostinato_audio/ostinato_audio.dart';
import 'package:test/test.dart';

const sr = 48000;
double hz(int midi) => 440 * math.pow(2, (midi - 69) / 12).toDouble();

/// Previous note ringing, the measured pluck at 0.1 s, and a louder next
/// pluck 30 ms before the buffer ends — the E38 failure, through simulated AGC.
List<double> sequence({required double seconds, required int seed}) {
  final total = (seconds * sr).round();
  final x = List<double>.filled(total, 0);
  final prev = SyntheticString.pluck(
      f0Hz: hz(45),
      sampleRate: sr,
      seconds: seconds + 0.5,
      seed: seed,
      peak: 0.3);
  final cur = SyntheticString.pluck(
      f0Hz: hz(52),
      sampleRate: sr,
      seconds: seconds,
      seed: seed + 1,
      peak: 0.3,
      fundamentalDecaySeconds: 0.8);
  final next = SyntheticString.pluck(
      f0Hz: hz(57), sampleRate: sr, seconds: 0.2, seed: seed + 2, peak: 0.5);
  final on = (0.1 * sr).round(), nx = total - (0.03 * sr).round();
  for (var k = 0; k < total; k++) {
    x[k] += 0.6 * prev[k + sr ~/ 2];
    if (k >= on) x[k] += cur[k - on];
    if (k >= nx) x[k] += next[k - nx];
  }
  return PhoneChannel.apply(
      x,
      sr,
      const PhoneChannelConfig(
          noise: ChannelNoise.pink, snrDb: 35, lowCutHz: 100, agc: true),
      seed: seed);
}

void main() {
  test('DftPlan matches the direct DFT for non-power-of-two lengths', () {
    for (final n in [7, 2117, 2208]) {
      final rng = math.Random(n);
      final x = [for (var i = 0; i < n; i++) rng.nextDouble() * 2 - 1];
      final got = DftPlan(n).transformReal(x, bins: 40);
      for (var k = 0; k < math.min(40, n); k++) {
        var re = 0.0, im = 0.0;
        for (var j = 0; j < n; j++) {
          re += x[j] * math.cos(2 * math.pi * k * j / n);
          im -= x[j] * math.sin(2 * math.pi * k * j / n);
        }
        expect(got.re[k], closeTo(re, 1e-8));
        expect(got.im[k], closeTo(im, 1e-8));
      }
    }
  });

  test('last usable attack ignores a later, AGC-boosted pluck', () {
    for (final seed in [1, 2, 3]) {
      final y = sequence(seconds: 1.6, seed: seed);
      final loudest = PreciseTuner.envelopePeakIndex(y, sr);
      final attack = const AttackLocator()
          .lastUsableAttack(y, sr, requiredSamples: (1.0 * sr).round());
      expect(attack, isNotNull);
      expect((attack! - 0.1 * sr).abs(), lessThan(0.05 * sr),
          reason: 'seed $seed');
      // The old rule lands on the next note at the end of the buffer.
      expect(loudest, greaterThan(1.4 * sr), reason: 'seed $seed');
    }
  });

  test('tuner and verifier measure the right note in that buffer', () {
    final y = sequence(seconds: 1.6, seed: 1);
    final m = PreciseTuner().measure(y, sampleRate: sr).measurement!;
    expect(m.midi, 52);
    expect(
        GuitarNoteVerifier()
            .verify(y, sampleRate: sr, expectedMidi: 52)
            .verdict,
        NoteVerdict.correct);
  });

  test('a note ringing from before the buffer starts at index 0', () {
    final x = SyntheticString.pluck(
        f0Hz: hz(40), sampleRate: sr, seconds: 3, seed: 9);
    final ringing = x.sublist(sr, sr + (1.4 * sr).round());
    expect(
        const AttackLocator()
            .lastUsableAttack(ringing, sr, requiredSamples: sr),
        0);
    expect(
        const AttackLocator().lastUsableAttack(ringing.sublist(0, sr ~/ 2), sr,
            requiredSamples: sr),
        isNull);
  });

  test('a note-off is not an attack: the note from index 0 is measured', () {
    // E39: a damping transient at 3 s is spectral change, and "last usable"
    // used to choose the silence after it.
    final z = SyntheticString.pluck(
        f0Hz: hz(64), sampleRate: sr, seconds: 4, seed: 7, peak: 0.4);
    final rng = math.Random(7);
    for (var k = 3 * sr; k < z.length; k++) {
      z[k] *= math.exp(-(k - 3 * sr) / (0.03 * sr));
      if (k < 3 * sr + 480) z[k] += 0.02 * (rng.nextDouble() * 2 - 1);
    }
    final q = PhoneChannel.apply(
        z,
        sr,
        const PhoneChannelConfig(
            noise: ChannelNoise.pink, snrDb: 35, lowCutHz: 100, agc: true),
        seed: 7);
    for (final signal in [z, q]) {
      final attack = const AttackLocator()
          .lastUsableAttack(signal, sr, requiredSamples: (0.28 * sr).round());
      expect(attack, lessThan(0.05 * sr));
    }
    expect(AttackLocator.levelRiseDb(z, sr, 3 * sr), lessThan(-10));
    expect(
        GuitarNoteVerifier()
            .verify(z, sampleRate: sr, expectedMidi: 64)
            .verdict,
        NoteVerdict.correct);
  });
}
