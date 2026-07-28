import 'dart:math' as math;

import 'pitch_source.dart';

/// YIN pitch estimator (de Cheveigné & Kawahara, 2002), written as the family's
/// normative reference implementation.
///
/// Why we own this instead of pulling a library: every well-known open-source
/// implementation on the audio side is GPL or AGPL (aubio, TarsosDSP, Essentia)
/// and cannot ship in a closed commercial app — catalogue §0. YIN itself is a
/// published algorithm, not a licensed artefact.
///
/// The real-time loop will run natively for latency reasons; native ports are
/// validated by replaying the same fixtures against this class. When they
/// disagree, this class is right by definition — same contract motion_core uses
/// for pose.
final class YinPitchSource implements PitchSource {
  YinPitchSource({
    this.minHz = 55.0,
    this.maxHz = 1200.0,
    this.threshold = 0.15,
    this.expectedHzPrior,
    this.priorToleranceCents = 700.0,
  })  : assert(minHz > 0 && maxHz > minHz),
        assert(threshold > 0 && threshold < 1);

  final double minHz;
  final double maxHz;

  /// YIN's absolute threshold on the cumulative mean normalised difference.
  /// Lower = stricter = more windows reported as unpitched.
  final double threshold;

  /// Optional expected fundamental (Hz) for the current exercise.
  ///
  /// This is the octave-error defence the G1-C benchmark asked for: on real
  /// cello, pYIN locked an octave high on the open C2 — the single most
  /// important note in the V1 drill. When the drill already knows which note is
  /// being asked for, candidates outside [priorToleranceCents] of it are
  /// rejected before they can become a confident wrong answer.
  final double? expectedHzPrior;
  final double priorToleranceCents;

  @override
  ({double minHz, double maxHz}) get range => (minHz: minHz, maxHz: maxHz);

  @override
  PitchReading analyze(List<double> samples, {required int sampleRate, required int tStartUs}) {
    final n = samples.length;
    final tEndUs = tStartUs + (n * 1000000 / sampleRate).round();
    final rmsDb = _rmsDb(samples);

    final tauMin = math.max(2, (sampleRate / maxHz).floor());
    final tauMax = math.min(n ~/ 2, (sampleRate / minHz).ceil());
    if (tauMax <= tauMin) {
      // Window is too short to hold two periods of the lowest note we accept.
      // Reporting "no pitch" is correct here; guessing is not.
      return PitchReading(
          tStartUs: tStartUs, tEndUs: tEndUs, f0Hz: null, periodicity: 0, rmsDb: rmsDb);
    }

    final d = _differenceFunction(samples, tauMax);
    final cmnd = _cumulativeMeanNormalized(d, tauMax);

    final tau = _absoluteThreshold(cmnd, tauMin, tauMax);
    if (tau == null) {
      return PitchReading(
          tStartUs: tStartUs, tEndUs: tEndUs, f0Hz: null, periodicity: 0, rmsDb: rmsDb);
    }

    final refined = _parabolicInterpolation(cmnd, tau);
    var f0 = sampleRate / refined;
    final periodicity = (1.0 - cmnd[tau]).clamp(0.0, 1.0);

    final prior = expectedHzPrior;
    if (prior != null) {
      f0 = _snapToPriorOctave(f0, prior);
      if (_absCents(f0, prior) > priorToleranceCents) {
        // Inside the search range but nowhere near what this drill asked for:
        // most likely a harmonic lock or a neighbouring instrument. Stay quiet.
        return PitchReading(
            tStartUs: tStartUs, tEndUs: tEndUs, f0Hz: null, periodicity: periodicity, rmsDb: rmsDb);
      }
    }

    if (f0 < minHz || f0 > maxHz) {
      return PitchReading(
          tStartUs: tStartUs, tEndUs: tEndUs, f0Hz: null, periodicity: periodicity, rmsDb: rmsDb);
    }

    return PitchReading(
        tStartUs: tStartUs, tEndUs: tEndUs, f0Hz: f0, periodicity: periodicity, rmsDb: rmsDb);
  }

  /// Squared difference function, YIN step 1.
  List<double> _differenceFunction(List<double> x, int tauMax) {
    final n = x.length;
    final d = List<double>.filled(tauMax + 1, 0);
    for (var tau = 1; tau <= tauMax; tau++) {
      var sum = 0.0;
      final limit = n - tau;
      for (var i = 0; i < limit; i++) {
        final delta = x[i] - x[i + tau];
        sum += delta * delta;
      }
      d[tau] = sum;
    }
    return d;
  }

  /// Cumulative mean normalised difference, YIN step 2. This is what makes the
  /// function comparable across lags and lets a single absolute threshold work.
  List<double> _cumulativeMeanNormalized(List<double> d, int tauMax) {
    final cmnd = List<double>.filled(tauMax + 1, 1.0);
    var running = 0.0;
    for (var tau = 1; tau <= tauMax; tau++) {
      running += d[tau];
      cmnd[tau] = running == 0 ? 1.0 : d[tau] * tau / running;
    }
    return cmnd;
  }

  /// YIN step 3: first local minimum below the threshold, not the global one.
  ///
  /// Taking the global minimum is the classic way to land an octave low; the
  /// first qualifying dip is the actual period.
  int? _absoluteThreshold(List<double> cmnd, int tauMin, int tauMax) {
    for (var tau = tauMin; tau <= tauMax; tau++) {
      if (cmnd[tau] < threshold) {
        var t = tau;
        while (t + 1 <= tauMax && cmnd[t + 1] < cmnd[t]) {
          t++;
        }
        return t;
      }
    }
    return null;
  }

  /// YIN step 4: parabolic interpolation around the chosen lag.
  ///
  /// Without this the resolution is one sample of lag, which at 44.1 kHz is
  /// already ~1 cent at C2 but a coarse ~35 cents up at A5 — far too blunt for
  /// an intonation coach.
  double _parabolicInterpolation(List<double> cmnd, int tau) {
    if (tau <= 0 || tau >= cmnd.length - 1) return tau.toDouble();
    final s0 = cmnd[tau - 1];
    final s1 = cmnd[tau];
    final s2 = cmnd[tau + 1];
    final denom = 2 * (2 * s1 - s2 - s0);
    if (denom == 0) return tau.toDouble();
    return tau + (s2 - s0) / denom;
  }

  /// How far from an exact octave an estimate may sit and still be treated as
  /// an octave error rather than a different note. One semitone.
  static const double _octaveSnapToleranceCents = 100.0;

  /// Pull an estimate that is a whole number of octaves away from the expected
  /// note back onto the expected octave.
  ///
  /// The residual check is the important half. Snapping on the rounded octave
  /// count alone folds *any* frequency onto the expected note — a student
  /// singing A4 against an expected C2 is 2.75 octaves away, rounds to 3, and
  /// silently becomes "C2, 300 cents flat" instead of "that is not the note".
  /// Caught by a fixture, 2026-07-29 (DEFTER O-017).
  double _snapToPriorOctave(double f0, double prior) {
    final octavesExact = math.log(f0 / prior) / math.ln2;
    final octaves = octavesExact.round();
    if (octaves == 0) return f0;
    if ((octavesExact - octaves).abs() * 1200 > _octaveSnapToleranceCents) {
      // Not an octave relationship at all — leave it alone so the range check
      // below can reject it honestly.
      return f0;
    }
    final snapped = f0 / math.pow(2, octaves);
    return _absCents(snapped, prior) < _absCents(f0, prior) ? snapped.toDouble() : f0;
  }

  double _absCents(double a, double b) => (1200 * math.log(a / b) / math.ln2).abs();

  double _rmsDb(List<double> x) {
    if (x.isEmpty) return -160;
    var sum = 0.0;
    for (final v in x) {
      sum += v * v;
    }
    final rms = math.sqrt(sum / x.length);
    if (rms <= 1e-9) return -160;
    return 20 * math.log(rms) / math.ln10;
  }
}
