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
  lowStringTests();
}

const lowStringGuard = GuitarObservationGuardConfig(
  maxResidualPowerRatio: .15,
  minFundamentalPowerRatio: .08,
  clippingPeak: .995,
  maxClippedFraction: .001,
  harmonicToleranceCents: 20,
  minAnalysisHz: 50,
  maxAnalysisHz: 4000,
  minFftSamples: 4096,
  lowStringMaxMidi: 52,
  lowStringMinOddHarmonicPowerRatio: .10,
);

/// Harmonic tone whose k-th partial has amplitude [weights][k-1].
List<double> partials(double hz, List<double> weights) {
  final total = weights.fold<double>(0, (a, w) => a + w);
  return List.generate(
    8192,
    (i) => List.generate(weights.length, (k) => k).fold<double>(
      0,
      (sum, k) =>
          sum +
          .65 *
              weights[k] /
              total *
              math.sin(2 * math.pi * (k + 1) * hz * i / 44100),
    ),
  );
}

/// Pick near the bridge plus a phone-like low cut: partial 1 nearly gone.
const weakFundamental = <double>[.12, 1, .9, .8, .7, .6, .5, .4, .3, .2];

void lowStringTests() {
  GuitarNoteObservationResult observeWith(
    GuitarObservationGuardConfig g,
    List<double> samples,
  ) => GuitarPitchObserver(
    config: fixture.config,
    guard: g,
  ).observe(samples, sampleRate: 44100, tStartUs: 200000, roomFloorDb: -60);
  double hzOf(int midi) => (440 * math.pow(2, (midi - 69) / 12)).toDouble();

  test(
    'weak-fundamental low strings are refused without the low-string rule',
    () {
      for (final midi in [40, 45, 50]) {
        final result = observeWith(
          guard,
          partials(hzOf(midi), weakFundamental),
        );
        expect(
          result.reason,
          GuitarSingleNoteReason.multipleSources,
          reason: 'midi $midi',
        );
      }
    },
  );
  test(
    'weak-fundamental low strings are observed with consistent odd harmonics',
    () {
      for (final midi in [40, 45, 50, 52]) {
        final result = observeWith(
          lowStringGuard,
          partials(hzOf(midi), weakFundamental),
        );
        expect(result.observation?.midi, midi, reason: 'midi $midi');
      }
    },
  );
  test('the low-string rule does not reach notes above its limit', () {
    final result = observeWith(
      lowStringGuard,
      partials(hzOf(57), weakFundamental),
    );
    expect(result.observation, isNull);
    expect(result.reason, GuitarSingleNoteReason.multipleSources);
  });
  test('an even-harmonic tone is never labelled an octave low', () {
    // Energy only at even multiples of E2 is an E3 tone; a sub-octave label
    // would have almost no power at its odd harmonics and must stay refused.
    final samples = partials(hzOf(40), <double>[.01, 1, 0, .8, 0, .6, 0, .4, 0, .2]);
    final result = observeWith(lowStringGuard, samples);
    expect(result.observation?.midi, isNot(40));
  });
  test('the low-string rule needs both fields in range', () {
    GuitarObservationGuardConfig variant({int? midi, double? odd}) =>
        GuitarObservationGuardConfig(
          maxResidualPowerRatio: .15,
          minFundamentalPowerRatio: .08,
          clippingPeak: .995,
          maxClippedFraction: .001,
          harmonicToleranceCents: 20,
          minAnalysisHz: 50,
          maxAnalysisHz: 4000,
          minFftSamples: 4096,
          lowStringMaxMidi: midi,
          lowStringMinOddHarmonicPowerRatio: odd,
        );
    for (final g in [
      variant(midi: 52),
      variant(odd: .1),
      variant(midi: 70, odd: .1),
      variant(midi: 52, odd: 0),
      variant(midi: 52, odd: 1),
    ]) {
      expect(
        () => GuitarPitchObserver(config: fixture.config, guard: g),
        throwsArgumentError,
      );
    }
  });
}
