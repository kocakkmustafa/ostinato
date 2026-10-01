import 'dart:math' as math;

import 'guitar_single_note_evaluator.dart';

/// Additional refusal guard for observation, not a chord classifier. Energy
/// outside one approximate harmonic family suggests noise/another source.
/// Octave mixtures and aligned partials cannot always be distinguished.
final class GuitarObservationGuardConfig {
  const GuitarObservationGuardConfig(
      {required this.maxResidualPowerRatio,
      required this.minFundamentalPowerRatio,
      required this.clippingPeak,
      required this.maxClippedFraction,
      required this.harmonicToleranceCents,
      required this.minAnalysisHz,
      required this.maxAnalysisHz,
      required this.minFftSamples});
  final double maxResidualPowerRatio,
      minFundamentalPowerRatio,
      clippingPeak,
      maxClippedFraction;
  final double harmonicToleranceCents, minAnalysisHz, maxAnalysisHz;
  final int minFftSamples;
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
            reason: reason, totalWindows: 0, reliableWindows: 0);
    if (samples.any((s) => !s.isFinite || s.abs() > 1)) {
      return refuse(GuitarSingleNoteReason.invalidSamples);
    }
    if (samples.where((s) => s.abs() >= guard.clippingPeak).length >
        samples.length * guard.maxClippedFraction) {
      return refuse(GuitarSingleNoteReason.clippedSignal);
    }
    final result = _evaluator.observe(samples,
        sampleRate: sampleRate,
        tStartUs: tStartUs,
        roomFloorDb: roomFloorDb,
        lastOnsetTUs: lastOnsetTUs);
    final value = result.observation;
    if (value == null) return result;
    final residual = _harmonicResidual(samples, sampleRate, value.hz, guard);
    if (residual == null || residual > guard.maxResidualPowerRatio) {
      return GuitarNoteObservationResult(
        reason: GuitarSingleNoteReason.multipleSources,
        totalWindows: result.totalWindows,
        reliableWindows: result.reliableWindows,
      );
    }
    return result;
  }
}

/// Original radix-2 FFT over a Hann window. No external model or dependency.
/// Bins are used only as a conservative energy refusal, never note labels.
double? _harmonicResidual(List<double> samples, int rate, double fundamental,
    GuitarObservationGuardConfig guard) {
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
  var total = 0.0, residual = 0.0, fundamentalPower = 0.0;
  for (var bin = (guard.minAnalysisHz / hzPerBin).ceil();
      bin <= (math.min(guard.maxAnalysisHz, rate / 2) / hzPerBin).floor();
      bin++) {
    final power = re[bin] * re[bin] + im[bin] * im[bin];
    total += power;
    final frequency = bin * hzPerBin;
    final harmonic = (frequency / fundamental).round();
    final center = harmonic * fundamental;
    final tolerance = math.max(2 * hzPerBin,
        center * (math.pow(2, guard.harmonicToleranceCents / 1200) - 1));
    if (harmonic == 1 && (frequency - center).abs() <= tolerance) {
      fundamentalPower += power;
    }
    if (harmonic < 1 || (frequency - center).abs() > tolerance) {
      residual += power;
    }
  }
  return total <= 0
      ? null
      : fundamentalPower / total < guard.minFundamentalPowerRatio
          ? 1
          : residual / total;
}
