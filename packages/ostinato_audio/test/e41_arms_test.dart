import 'dart:math' as math;

import 'package:ostinato_audio/ostinato_audio.dart';
import 'package:test/test.dart';

const sr = 48000;
double hz(num midi) => 440 * math.pow(2, (midi - 69) / 12).toDouble();
double centsOf(double a, double b) => 1200 * math.log(a / b) / math.ln2;
const q = PhoneChannelConfig(
    noise: ChannelNoise.pink, snrDb: 35, lowCutHz: 100, agc: true);

void main() {
  test('all E41 options off reproduces the default engine', () {
    final x = SyntheticString.pluck(
        f0Hz: hz(50) * math.pow(2, 7 / 1200),
        sampleRate: sr,
        seconds: 2,
        preRollSeconds: 0.2,
        seed: 3);
    final a = PreciseTuner().measure(x, sampleRate: sr).measurement!;
    final b = PreciseTuner(profile: PreciseTunerProfile.guitar.copyWith())
        .measure(x, sampleRate: sr)
        .measurement!;
    expect(b.f0Hz, a.f0Hz);
    expect(b.fromLateReadings, isFalse);
  });

  test('A1/A2: a pluck at the very first sample is found', () {
    final z = SyntheticString.pluck(
        f0Hz: hz(60),
        sampleRate: sr,
        seconds: 4,
        seed: 11,
        peak: 0.4,
        fundamentalDecaySeconds: 0.8);
    for (var k = 3 * sr; k < z.length; k++) {
      z[k] *= math.exp(-(k - 3 * sr) / (0.03 * sr));
    }
    final y = PhoneChannel.apply(z, sr, q, seed: 11);
    const locator =
        AttackLocator(bufferStartCandidate: true, maxBelowLoudestDb: 12);
    expect(locator.lastUsableAttack(y, sr, requiredSamples: sr ~/ 4), 0);
  });

  test('U: a settling string is reported from its later readings', () {
    final f0 = hz(45);
    final x = SyntheticString.pluck(
        f0Hz: f0,
        sampleRate: sr,
        seconds: 2.2,
        glideCents: 20,
        fundamentalDecaySeconds: 1.0,
        preRollSeconds: 0.2,
        seed: 5);
    final strict = PreciseTuner().measure(x, sampleRate: sr);
    expect(strict.refusal, TunerRefusal.unstable);
    final lenient = PreciseTuner(
            profile:
                PreciseTunerProfile.guitar.copyWith(maxLateSpreadCents: 10))
        .measure(x, sampleRate: sr);
    expect(lenient.measured, isTrue);
    expect(lenient.measurement!.fromLateReadings, isTrue);
    // Later readings sit closer to the resting pitch than the attack does.
    expect(centsOf(lenient.measurement!.f0Hz, f0), lessThan(3));
    // A wildly drifting note is still refused.
    final wild = SyntheticString.pluck(
        f0Hz: f0,
        sampleRate: sr,
        seconds: 2.2,
        glideCents: 60,
        fundamentalDecaySeconds: 1.0,
        preRollSeconds: 0.2,
        seed: 5);
    expect(
        PreciseTuner(
                profile:
                    PreciseTunerProfile.guitar.copyWith(maxLateSpreadCents: 10))
            .measure(wild, sampleRate: sr)
            .refusal,
        TunerRefusal.unstable);
  });

  test('W1: adaptive windows keep high-note accuracy', () {
    final f0 = hz(81) * math.pow(2, -6 / 1200);
    final x = PhoneChannel.apply(
        SyntheticString.pluck(
            f0Hz: f0,
            sampleRate: sr,
            seconds: 1.6,
            inharmonicityB: 5e-5,
            fundamentalDecaySeconds: 0.4,
            preRollSeconds: 0.2,
            seed: 8),
        sr,
        q,
        seed: 8);
    final m = PreciseTuner(
            profile: PreciseTunerProfile.guitar
                .copyWith(adaptiveWindowPeriods: 40, maxAnalysisHz: 7500))
        .measure(x, sampleRate: sr)
        .measurement!;
    expect(centsOf(m.f0Hz, f0).abs(), lessThan(1));
    expect(m.readings.length, greaterThan(5));
  });

  test('F: the fifth rival resolves ±7 and leaves the right note alone', () {
    final v =
        GuitarNoteVerifier(config: const NoteVerifierConfig(fifthRival: true));
    final x = PhoneChannel.apply(
        SyntheticString.pluck(
            f0Hz: hz(52),
            sampleRate: sr,
            seconds: 0.8,
            preRollSeconds: 0.1,
            seed: 2),
        sr,
        q,
        seed: 2);
    expect(v.verify(x, sampleRate: sr, expectedMidi: 52).verdict,
        NoteVerdict.correct);
    for (final d in [7, -7]) {
      final r = v.verify(x, sampleRate: sr, expectedMidi: 52 + d);
      expect(r.verdict, NoteVerdict.differentNote, reason: 'd $d');
      expect(r.reason, NoteVerdictReason.fifthResolved, reason: 'd $d');
    }
  });
}
