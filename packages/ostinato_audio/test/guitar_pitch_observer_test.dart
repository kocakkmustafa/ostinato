import 'dart:math' as math;
import 'package:ostinato_audio/ostinato_audio.dart';
import 'package:test/test.dart';
import 'guitar_single_note_evaluator_test.dart' as fixture;

const guard = GuitarObservationGuardConfig(
    maxResidualPowerRatio: .15,
    minFundamentalPowerRatio: .08,
    clippingPeak: .995,
    maxClippedFraction: .001,
    harmonicToleranceCents: 20,
    minAnalysisHz: 50,
    maxAnalysisHz: 4000,
    minFftSamples: 4096);
GuitarNoteObservationResult observe(List<double> samples) =>
    GuitarPitchObserver(config: fixture.config, guard: guard).observe(samples,
        sampleRate: 44100, tStartUs: 200000, roomFloorDb: -60);
List<double> mixture(List<double> frequencies) => List.generate(
    8192,
    (i) => frequencies.fold<double>(
        0,
        (sum, hz) =>
            sum +
            .65 / frequencies.length * math.sin(2 * math.pi * hz * i / 44100)));
void main() {
  test(
      'six open strings and octave are approximate observations without target',
      () {
    for (final midi in [40, 45, 50, 55, 59, 64, 69]) {
      final hz = (440 * math.pow(2, (midi - 69) / 12)).toDouble();
      final result = observe(fixture.tone(hz));
      expect(result.observation?.midi, midi, reason: 'midi $midi');
      expect(result.observation!.centsFromCenter.abs(), lessThan(5));
    }
  });
  test('one periodic harmonic family is retained', () {
    final result = observe(mixture([220, 440, 660]));
    expect(result.observation?.midi, 57);
  });
  test('eight synthetic open chord voicings refuse a single-note label', () {
    const voicings = [
      [40, 47, 52, 56, 59, 64],
      [45, 52, 57, 61, 64],
      [50, 57, 62, 66],
      [43, 47, 50, 55, 59, 67],
      [48, 52, 55, 60, 64],
      [45, 52, 57, 60, 64],
      [40, 47, 52, 55, 59, 64],
      [50, 57, 62, 65]
    ];
    for (final notes in voicings) {
      final result = observe(mixture(notes
          .map((m) => (440 * math.pow(2, (m - 69) / 12)).toDouble())
          .toList()));
      expect(result.observation, isNull, reason: '$notes');
    }
  });
  test('unrelated simultaneous tones refuse', () {
    expect(observe(mixture([220, 293.6648])).observation, isNull);
  });
  test('weak/noise/clipped/nonfinite signals refuse', () {
    expect(observe(fixture.tone(220, amplitude: .00001)).observation, isNull);
    expect(
        observe(SyntheticTone.roomNoise(sampleRate: 44100, seconds: .19))
            .observation,
        isNull);
    expect(observe(List.filled(8192, 1)).reason,
        GuitarSingleNoteReason.clippedSignal);
    expect(observe([...fixture.tone(220)..[5] = double.nan]).reason,
        GuitarSingleNoteReason.invalidSamples);
  });
  test('near halfway between note centers has no label or cents', () {
    expect(
        observe(fixture.tone((220 * math.pow(2, 50 / 1200)).toDouble()))
            .observation,
        isNull);
  });
}
