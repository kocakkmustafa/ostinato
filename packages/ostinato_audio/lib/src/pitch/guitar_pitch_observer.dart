import 'dart:math' as math;

import 'guitar_single_note_evaluator.dart';

/// Additional refusal guard for observation, not a chord classifier. Energy
/// outside one approximate harmonic family suggests noise/another source.
/// Octave mixtures and aligned partials cannot always be distinguished.
///
/// Low strings (observed MIDI <= [lowStringMaxMidi]) may carry a weak
/// fundamental (pick near the bridge, microphone low cut). There a weak
/// fundamental is accepted when odd harmonics 1/3/5/7 still carry
/// [lowStringMinOddHarmonicPowerRatio]; an octave-low pitch error has almost
/// no power at its odd harmonics and stays refused. Both null = disabled.
final class GuitarObservationGuardConfig {
  const GuitarObservationGuardConfig({
    required this.maxResidualPowerRatio,
    required this.minFundamentalPowerRatio,
    required this.clippingPeak,
    required this.maxClippedFraction,
    required this.harmonicToleranceCents,
    required this.minAnalysisHz,
    required this.maxAnalysisHz,
    required this.minFftSamples,
    this.lowStringMaxMidi,
    this.lowStringMinOddHarmonicPowerRatio,
  });
  final double maxResidualPowerRatio,
      minFundamentalPowerRatio,
      clippingPeak,
      maxClippedFraction;
  final double harmonicToleranceCents, minAnalysisHz, maxAnalysisHz;
  final int minFftSamples;
  final int? lowStringMaxMidi;
  final double? lowStringMinOddHarmonicPowerRatio;
}

final class GuitarPitchObserver {
  GuitarPitchObserver({
    required GuitarSingleNoteConfig config,
    required this.guard,
  }) : _evaluator = GuitarSingleNoteEvaluator(config: config) {
    if (!guard.maxResidualPowerRatio.isFinite ||
        guard.maxResidualPowerRatio <= 0 ||
        guard.maxResidualPowerRatio >= 1 ||
        guard.minFundamentalPowerRatio <= 0 ||
        guard.minFundamentalPowerRatio >= 1 ||
        guard.clippingPeak <= 0 ||
        guard.clippingPeak > 1 ||
        guard.maxClippedFraction < 0 ||
        guard.maxClippedFraction >= 1 ||
        guard.harmonicToleranceCents <= 0 ||
        guard.minAnalysisHz <= 0 ||
        guard.maxAnalysisHz <= guard.minAnalysisHz ||
        guard.minFftSamples < 4096) {
      throw ArgumentError('Invalid residual guard');
    }
    final lowMidi = guard.lowStringMaxMidi;
    final lowOdd = guard.lowStringMinOddHarmonicPowerRatio;
    if ((lowMidi == null) != (lowOdd == null) ||
        (lowMidi != null && (lowMidi < 28 || lowMidi > 64)) ||
        (lowOdd != null && (!lowOdd.isFinite || lowOdd <= 0 || lowOdd >= 1))) {
      throw ArgumentError('Invalid low-string guard');
    }
  }
  final GuitarSingleNoteEvaluator _evaluator;
  final GuitarObservationGuardConfig guard;

  GuitarNoteObservationResult observe(
    List<double> samples, {
    required int sampleRate,
    required int tStartUs,
    required double roomFloorDb,
    int? lastOnsetTUs,
  }) {
    GuitarNoteObservationResult refuse(GuitarSingleNoteReason reason) =>
        GuitarNoteObservationResult(
          reason: reason,
          totalWindows: 0,
          reliableWindows: 0,
        );
    if (samples.any((s) => !s.isFinite || s.abs() > 1)) {
      return refuse(GuitarSingleNoteReason.invalidSamples);
    }
    if (samples.where((s) => s.abs() >= guard.clippingPeak).length >
        samples.length * guard.maxClippedFraction) {
      return refuse(GuitarSingleNoteReason.clippedSignal);
    }
    final result = _evaluator.observe(
      samples,
      sampleRate: sampleRate,
      tStartUs: tStartUs,
      roomFloorDb: roomFloorDb,
      lastOnsetTUs: lastOnsetTUs,
    );
    final value = result.observation;
    if (value == null) return result;
    final energy = _harmonicEnergy(samples, sampleRate, value.hz, guard);
    if (energy == null || !_singleHarmonicFamily(energy, value.midi)) {
      return GuitarNoteObservationResult(
        reason: GuitarSingleNoteReason.multipleSources,
        totalWindows: result.totalWindows,
        reliableWindows: result.reliableWindows,
      );
    }
    return result;
  }

  bool _singleHarmonicFamily(_HarmonicEnergy energy, int midi) {
    if (energy.residual > guard.maxResidualPowerRatio) return false;
    if (energy.fundamental >= guard.minFundamentalPowerRatio) return true;
    final lowMidi = guard.lowStringMaxMidi;
    final lowOdd = guard.lowStringMinOddHarmonicPowerRatio;
    return lowMidi != null &&
        lowOdd != null &&
        midi <= lowMidi &&
        energy.oddHarmonics >= lowOdd;
  }
}

/// Power shares of one Hann/FFT window around an observed fundamental.
final class _HarmonicEnergy {
  const _HarmonicEnergy(this.fundamental, this.residual, this.oddHarmonics);
  final double fundamental, residual, oddHarmonics;
}

/// Original radix-2 FFT over a Hann window. No external model or dependency.
/// Bins are used only as a conservative energy refusal, never note labels.
_HarmonicEnergy? _harmonicEnergy(
  List<double> samples,
  int rate,
  double fundamental,
  GuitarObservationGuardConfig guard,
) {
  var n = 1;
  while (n * 2 <= samples.length) {
    n *= 2;
  }
  if (n < guard.minFftSamples) return null;
  final re = List<double>.filled(n, 0);
  final im = List<double>.filled(n, 0);
  for (var i = 0; i < n; i++) {
    re[i] = samples[i] * (.5 - .5 * math.cos(2 * math.pi * i / (n - 1)));
  }
  for (var i = 1, j = 0; i < n; i++) {
    var bit = n >> 1;
    for (; j & bit != 0; bit >>= 1) {
      j ^= bit;
    }
    j ^= bit;
    if (i < j) {
      final t = re[i];
      re[i] = re[j];
      re[j] = t;
    }
  }
  for (var size = 2; size <= n; size *= 2) {
    final angle = -2 * math.pi / size;
    final stepRe = math.cos(angle), stepIm = math.sin(angle);
    for (var start = 0; start < n; start += size) {
      var wr = 1.0, wi = 0.0;
      for (var j = 0; j < size ~/ 2; j++) {
        final a = start + j, b = a + size ~/ 2;
        final br = re[b] * wr - im[b] * wi;
        final bi = re[b] * wi + im[b] * wr;
        re[b] = re[a] - br;
        im[b] = im[a] - bi;
        re[a] += br;
        im[a] += bi;
        final next = wr * stepRe - wi * stepIm;
        wi = wr * stepIm + wi * stepRe;
        wr = next;
      }
    }
  }
  final hzPerBin = rate / n;
  var total = 0.0, residual = 0.0, fundamentalPower = 0.0, oddPower = 0.0;
  for (
    var bin = (guard.minAnalysisHz / hzPerBin).ceil();
    bin <= (math.min(guard.maxAnalysisHz, rate / 2) / hzPerBin).floor();
    bin++
  ) {
    final power = re[bin] * re[bin] + im[bin] * im[bin];
    total += power;
    final frequency = bin * hzPerBin;
    final harmonic = (frequency / fundamental).round();
    final center = harmonic * fundamental;
    final tolerance = math.max(
      2 * hzPerBin,
      center * (math.pow(2, guard.harmonicToleranceCents / 1200) - 1),
    );
    final near = (frequency - center).abs() <= tolerance;
    if (harmonic == 1 && near) {
      fundamentalPower += power;
    }
    if (near && harmonic.isOdd && harmonic <= 7) {
      oddPower += power;
    }
    if (harmonic < 1 || !near) {
      residual += power;
    }
  }
  return total <= 0
      ? null
      : _HarmonicEnergy(
          fundamentalPower / total,
          residual / total,
          oddPower / total,
        );
}
