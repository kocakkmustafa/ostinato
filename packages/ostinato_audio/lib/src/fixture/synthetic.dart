import 'dart:math' as math;

/// Deterministic synthetic signals for tests and fixtures.
///
/// These exist so the audio engine can be proven correct without a microphone,
/// a room or a musician — the same role motion_core's synthetic skeletons play
/// for pose. Ground truth is exact by construction, which is the only way to
/// separate "our maths is wrong" from "the recording was hard".
final class SyntheticTone {
  const SyntheticTone._();

  /// A bowed/sung-like harmonic tone.
  ///
  /// The fundamental is deliberately *not* the strongest partial: on a real
  /// cello C string the body resonance routinely puts more energy in the second
  /// or third harmonic, and a phone microphone's bass roll-off makes it worse.
  /// An estimator tested only on pure sines will pass the test and then lock an
  /// octave high on the first real note.
  static List<double> harmonic({
    required double f0Hz,
    required int sampleRate,
    required double seconds,
    List<double> partials = const [0.5, 1.0, 0.8, 0.5, 0.35, 0.25, 0.18, 0.12],
    double attackSeconds = 0.12,
    double vibratoHz = 0,
    double vibratoCents = 0,
    double noiseAmplitude = 0.02,
    int seed = 42,
  }) {
    final n = (sampleRate * seconds).round();
    final rng = math.Random(seed);
    final out = List<double>.filled(n, 0);

    var phase = 0.0;
    for (var i = 0; i < n; i++) {
      final t = i / sampleRate;
      final inst = vibratoCents == 0
          ? f0Hz
          : f0Hz * math.pow(2, (vibratoCents / 1200) * math.sin(2 * math.pi * vibratoHz * t));
      phase += 2 * math.pi * inst / sampleRate;

      var sample = 0.0;
      for (var k = 0; k < partials.length; k++) {
        sample += partials[k] * math.sin((k + 1) * phase);
      }

      final env = attackSeconds <= 0 ? 1.0 : math.min(1.0, t / attackSeconds);
      sample *= env;
      sample += noiseAmplitude * (rng.nextDouble() * 2 - 1);
      out[i] = sample;
    }
    return _normalize(out);
  }

  /// Silence with a little room noise — the negative fixture. The engine must
  /// answer "I could not hear that", never a number.
  static List<double> roomNoise({
    required int sampleRate,
    required double seconds,
    double amplitude = 0.01,
    int seed = 7,
  }) {
    final rng = math.Random(seed);
    return List<double>.generate(
      (sampleRate * seconds).round(),
      (_) => amplitude * (rng.nextDouble() * 2 - 1),
    );
  }

  /// A sequence of short notes starting at given times — for onset and timing
  /// tests. Offsets let a test simulate a student who rushes or drags.
  static List<double> notesAt({
    required List<double> onsetSeconds,
    required double f0Hz,
    required int sampleRate,
    required double totalSeconds,
    double noteSeconds = 0.35,
  }) {
    final out = List<double>.filled((sampleRate * totalSeconds).round(), 0);
    for (final start in onsetSeconds) {
      final note = harmonic(
        f0Hz: f0Hz,
        sampleRate: sampleRate,
        seconds: noteSeconds,
        attackSeconds: 0.01,
        noiseAmplitude: 0.005,
      );
      final offset = (start * sampleRate).round();
      final releaseSamples = (note.length * 0.25).round();
      for (var i = 0; i < note.length && offset + i < out.length; i++) {
        // Decay, then a smooth release to exactly zero.
        //
        // The release matters more than it looks: cutting a note off abruptly
        // produces a broadband click, and a spectral-flux detector is right to
        // call that a new event — so a fixture built that way reports twice as
        // many onsets as were played and looks like a detector bug. Real
        // instruments do not click when a note ends. (Found 2026-07-29; same
        // class as the family's M-C-06 "fixture must be cleaner than the thing
        // it tests" lesson.)
        final decay = 1.0 - (i / note.length) * 0.8;
        final remaining = note.length - i;
        final release = remaining >= releaseSamples ? 1.0 : remaining / releaseSamples;
        out[offset + i] += note[i] * decay * release;
      }
    }
    return _normalize(out);
  }

  static List<double> addNoise(List<double> x, {required double snrDb, int seed = 11}) {
    final rng = math.Random(seed);
    var power = 0.0;
    for (final v in x) {
      power += v * v;
    }
    power /= x.length;
    final noisePower = power / math.pow(10, snrDb / 10);
    final amp = math.sqrt(noisePower * 3); // uniform noise variance = a^2/3
    return List<double>.generate(x.length, (i) => x[i] + amp * (rng.nextDouble() * 2 - 1));
  }

  /// Second-order high-pass at 120 Hz — a cheap phone microphone.
  ///
  /// This is the condition that decides whether a low-string estimator survives
  /// contact with real hardware: it weakens the fundamental and leaves the
  /// harmonics, so anything that secretly depends on seeing the fundamental
  /// fails here.
  static List<double> phoneHighpass(List<double> x, {required int sampleRate, double cutoffHz = 120}) {
    final rc = 1 / (2 * math.pi * cutoffHz);
    final dt = 1 / sampleRate;
    final alpha = rc / (rc + dt);
    var stage = List<double>.filled(x.length, 0);
    var prevIn = 0.0;
    var prevOut = 0.0;
    for (var i = 0; i < x.length; i++) {
      final out = alpha * (prevOut + x[i] - prevIn);
      stage[i] = out;
      prevIn = x[i];
      prevOut = out;
    }
    // Second pass for a steeper slope.
    prevIn = 0.0;
    prevOut = 0.0;
    final result = List<double>.filled(x.length, 0);
    for (var i = 0; i < stage.length; i++) {
      final out = alpha * (prevOut + stage[i] - prevIn);
      result[i] = out;
      prevIn = stage[i];
      prevOut = out;
    }
    return result;
  }

  static List<double> _normalize(List<double> x) {
    var peak = 0.0;
    for (final v in x) {
      final a = v.abs();
      if (a > peak) peak = a;
    }
    if (peak == 0) return x;
    return x.map((v) => v / peak).toList();
  }
}

/// Open-string / reference frequencies used across tests and drills.
final class ReferencePitches {
  const ReferencePitches._();

  // Cello open strings (W3).
  static const double c2 = 65.406;
  static const double g2 = 97.999;
  static const double d3 = 146.832;
  static const double a3 = 220.0;

  // Common vocal range anchors (W1 — Ostinato's first instrument).
  static const double c3 = 130.813;
  static const double a4 = 440.0;
  static const double c5 = 523.251;
}
