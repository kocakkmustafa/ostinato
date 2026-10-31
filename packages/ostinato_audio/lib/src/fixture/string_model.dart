import 'dart:math' as math;
import 'dart:typed_data';

/// Deterministic plucked stiff-string tone with exact ground truth.
///
/// Unlike [SyntheticTone.harmonic], partials here are *inharmonic*:
/// f_n = n·f0·sqrt(1 + B·n²) (Fletcher). That is the physics that makes a
/// period-based estimator such as YIN read stiff strings sharp (E34: +2.9…+4.1
/// cents on open strings), so a precise tuner can only be tested against it.
///
/// Also modelled, because each one is a known tuner error source:
/// - a pluck-position comb (|sin(nπβ)|), which can almost remove a partial;
/// - per-partial exponential decay, faster for higher partials;
/// - a tension-modulation pitch glide that starts [glideCents] sharp and
///   decays with the square of the amplitude (twice the decay rate);
/// - a second, slightly detuned polarisation (slow beating);
/// - a short broadband pick noise at the attack.
///
/// Ground truth is [f0Hz]: the at-rest, inharmonicity-free fundamental. The
/// glide and the second polarisation are deliberate deviations from it; tests
/// that need an exact answer set them to zero.
final class SyntheticString {
  const SyntheticString._();

  static Float64List pluck({
    required double f0Hz,
    required int sampleRate,
    required double seconds,
    double inharmonicityB = 1e-4,
    double pluckPosition = 0.2,
    double fundamentalDecaySeconds = 2.0,
    double decayGrowthPerPartial = 0.15,
    double spectralTilt = 1.0,
    double glideCents = 0,
    double polarizationDetuneCents = 0,
    double polarizationLevel = 0,
    double pickNoiseLevel = 0.05,
    double preRollSeconds = 0,
    double maxPartialHz = 8000,
    double peak = 0.5,
    int seed = 1,
  }) {
    if (f0Hz <= 0 || sampleRate <= 0 || seconds <= 0) {
      throw ArgumentError('Invalid string parameters');
    }
    final rng = math.Random(seed);
    final pre = (preRollSeconds * sampleRate).round();
    final n = (seconds * sampleRate).round();
    final out = Float64List(pre + n);
    final nyquistGuard = math.min(maxPartialHz, sampleRate * 0.45);

    final amps = <double>[];
    final freqs = <double>[];
    final decays = <double>[];
    final phases = <double>[];
    for (var k = 1; k <= 80; k++) {
      final fk = k * f0Hz * math.sqrt(1 + inharmonicityB * k * k);
      if (fk > nyquistGuard) break;
      final comb = math.sin(k * math.pi * pluckPosition).abs();
      // Small random level jitter so no two partials are artificially equal.
      final jitter = 0.85 + 0.3 * rng.nextDouble();
      amps.add(comb * jitter / math.pow(k, spectralTilt));
      freqs.add(fk);
      decays
          .add(fundamentalDecaySeconds / (1 + decayGrowthPerPartial * (k - 1)));
      phases.add(rng.nextDouble() * 2 * math.pi);
    }
    final polRatio = math.pow(2, polarizationDetuneCents / 1200).toDouble();
    final glideRatio = math.pow(2, glideCents / 1200).toDouble() - 1;
    final dt = 1 / sampleRate;
    final phaseA = List<double>.of(phases);
    final phaseB = [for (final p in phases) p + 1.3];

    for (var i = 0; i < n; i++) {
      final t = i * dt;
      // Tension modulation follows amplitude squared of the fundamental.
      final glide = 1 + glideRatio * math.exp(-2 * t / fundamentalDecaySeconds);
      var s = 0.0;
      for (var k = 0; k < amps.length; k++) {
        final env = math.exp(-t / decays[k]);
        final w = 2 * math.pi * freqs[k] * glide * dt;
        phaseA[k] += w;
        s += amps[k] * env * math.sin(phaseA[k]);
        if (polarizationLevel > 0) {
          phaseB[k] += w * polRatio;
          s += polarizationLevel * amps[k] * env * math.sin(phaseB[k]);
        }
      }
      if (pickNoiseLevel > 0 && t < 0.01) {
        s += pickNoiseLevel * (rng.nextDouble() * 2 - 1) * (1 - t / 0.01);
      }
      out[pre + i] = s;
    }
    var maxAbs = 0.0;
    for (final v in out) {
      maxAbs = math.max(maxAbs, v.abs());
    }
    if (maxAbs > 0) {
      final g = peak / maxAbs;
      for (var i = 0; i < out.length; i++) {
        out[i] *= g;
      }
    }
    return out;
  }
}
