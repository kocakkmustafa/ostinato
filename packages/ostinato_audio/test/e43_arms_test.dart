import 'dart:math' as math;

import 'package:ostinato_audio/ostinato_audio.dart';
import 'package:test/test.dart';

const sr = 48000;
double hz(num midi) => 440 * math.pow(2, (midi - 69) / 12).toDouble();
double centsOf(double a, double b) => 1200 * math.log(a / b) / math.ln2;

/// Three plucks in a row through the quiet phone channel.
List<double> stream() {
  final x = <double>[];
  for (final (m, seed) in [(45, 1), (52, 2), (57, 3)]) {
    x.addAll(SyntheticString.pluck(
        f0Hz: hz(m),
        sampleRate: sr,
        seconds: 1.8,
        preRollSeconds: 0.1,
        seed: seed));
  }
  return PhoneChannel.apply(
      x,
      sr,
      const PhoneChannelConfig(
          noise: ChannelNoise.pink, snrDb: 35, lowCutHz: 100, agc: true),
      seed: 4);
}

void main() {
  test(
      'S1: cached global-grid onsets equal uncached ones across a sliding buffer',
      () {
    final z = stream();
    final cache = OnsetFrameCache();
    const detector = OnsetDetector();
    final buffer = (1.6 * sr).round(), step = (0.35 * sr).round();
    var calls = 0;
    for (var t = buffer; t <= z.length; t += step) {
      final a = t - buffer;
      final plain = detector.detect(z.sublist(a, t),
          sampleRate: sr, tStartUs: 0, absoluteStartSample: a);
      final cached = detector.detect(z.sublist(a, t),
          sampleRate: sr, tStartUs: 0, absoluteStartSample: a, cache: cache);
      expect([for (final o in cached) (o.tUs, o.strength)],
          [for (final o in plain) (o.tUs, o.strength)]);
      calls++;
    }
    expect(calls, greaterThan(5));
    expect(cache.hits, greaterThan(cache.misses));
  });

  test('S1: tuner with cache measures exactly as without', () {
    final z = stream();
    final cache = OnsetFrameCache();
    final buffer = (1.6 * sr).round(), step = (0.35 * sr).round();
    for (var t = buffer; t <= z.length; t += step) {
      final a = t - buffer;
      final p = PreciseTuner()
          .measure(z.sublist(a, t), sampleRate: sr, absoluteStartSample: a);
      final c = PreciseTuner().measure(z.sublist(a, t),
          sampleRate: sr, absoluteStartSample: a, onsetCache: cache);
      expect(c.refusal, p.refusal);
      expect(c.measurement?.f0Hz, p.measurement?.f0Hz);
    }
  });

  test('W65 and L options leave the defaults untouched and still measure', () {
    final f0 = hz(45) * math.pow(2, 4 / 1200);
    final x = SyntheticString.pluck(
        f0Hz: f0,
        sampleRate: sr,
        seconds: 2.2,
        glideCents: 20,
        fundamentalDecaySeconds: 1.0,
        preRollSeconds: 0.2,
        seed: 5);
    final d = PreciseTunerProfile.guitar;
    expect(d.adaptiveWindowMinMidi, isNull);
    expect(d.lateFractionOpen, isNull);
    for (final profile in [
      d.copyWith(adaptiveWindowMinMidi: 65),
      d.copyWith(lateFractionOpen: 2 / 3),
      d.copyWith(maxLateSpreadCents: 6),
    ]) {
      final r = PreciseTuner(profile: profile).measure(x, sampleRate: sr);
      if (r.measured) {
        expect(centsOf(r.measurement!.f0Hz, f0).abs(), lessThan(3));
      } else {
        expect(r.refusal, TunerRefusal.unstable);
      }
    }
    // W65: an open A2 keeps the 400 ms window (fewer readings than adaptive).
    final open = PreciseTuner(profile: d.copyWith(adaptiveWindowMinMidi: 65))
        .measure(x, sampleRate: sr, attackIndex: (0.2 * sr).round());
    final adaptive = PreciseTuner()
        .measure(x, sampleRate: sr, attackIndex: (0.2 * sr).round());
    if (open.measured && adaptive.measured) {
      expect(open.measurement!.readings.length,
          lessThanOrEqualTo(adaptive.measurement!.readings.length));
    }
  });

  test('E44: calibrated noise floor sits at the noise, not the note', () {
    final note = SyntheticString.pluck(
        f0Hz: hz(45), sampleRate: sr, seconds: 2, seed: 1);
    const quiet =
        PhoneChannelConfig(noise: ChannelNoise.pink, snrDb: 35, lowCutHz: 100);
    final floor = PhoneChannel.noiseFloorDb(note, sr, quiet, seed: 2);
    final y = PhoneChannel.apply(note, sr, quiet, seed: 2);
    final noteDb = 20 * math.log(PhoneChannel.activeRms(y, sr)) / math.ln10;
    expect(noteDb - floor, closeTo(35, 3));
    expect(PhoneChannel.noiseFloorDb(note, sr, const PhoneChannelConfig()),
        lessThan(-150));
    // The tuner refuses a buffer whose segment is below floor + 6 dB.
    expect(
        PreciseTuner().measure(y, sampleRate: sr, roomFloorDb: noteDb).refusal,
        TunerRefusal.tooQuiet);
  });
}
