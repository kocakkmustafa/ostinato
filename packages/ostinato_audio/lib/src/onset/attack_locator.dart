import 'dart:math' as math;

import 'onset_detector.dart';

/// Finds the pluck a measurement should start from, using the spectral-flux
/// [OnsetDetector] instead of "the loudest frame".
///
/// Why not the loudest frame (E36–E38): with phone AGC a decaying note is
/// slowly amplified, and the *next* note's attack becomes the loudest frame of
/// the buffer. A tuner or verifier anchored there runs out of samples or
/// measures the wrong note. Flux reacts to spectral change, which AGC gain
/// riding does not create.
///
/// Rule ("last usable attack"): among rising attacks (below) whose flux
/// strength is at least [minRelativeStrength] of the strongest one, take the latest that still
/// leaves `requiredSamples` after it. A later note whose attack arrives too
/// close to the end of the buffer is ignored rather than mistaken for the
/// note being measured. A buffer with no attack at all is a note that was
/// already ringing when the buffer began: its start (index 0) is used.
///
/// A flux peak counts as an attack only if the level *rises* across it by at
/// least [minRiseDb] (100 ms after vs 50 ms before). E39 found the other
/// direction on real recordings: a note-off/damping transient is spectral
/// change too, and "last usable" then chose silence after the note.
final class AttackLocator {
  const AttackLocator({
    this.detector = const OnsetDetector(),
    this.minRelativeStrength = 0.2,
    this.minRiseDb = 0.5,
  });

  final OnsetDetector detector;
  final double minRelativeStrength;

  /// Required level rise across an attack; null disables the check (E39).
  final double? minRiseDb;

  /// Sample indices of the retained attacks, in time order.
  List<int> attacks(List<double> samples, int sampleRate) {
    final rise = minRiseDb;
    int index(Onset o) => (o.tUs * sampleRate / 1000000).round();
    final onsets = [
      for (final o
          in detector.detect(samples, sampleRate: sampleRate, tStartUs: 0))
        if (rise == null || levelRiseDb(samples, sampleRate, index(o)) >= rise)
          o,
    ];
    if (onsets.isEmpty) return const [];
    final strongest = onsets.map((o) => o.strength).reduce(math.max);
    return [
      for (final o in onsets)
        if (o.strength >= minRelativeStrength * strongest) index(o),
    ];
  }

  /// RMS level 10–110 ms after [index] minus 60–10 ms before it, in dB. A
  /// window that falls outside the buffer is treated as silence (an attack at
  /// the very start rises from nothing).
  static double levelRiseDb(List<double> x, int sampleRate, int index) {
    double rmsDb(int from, int to) {
      final a = math.max(0, from), b = math.min(x.length, to);
      if (b <= a) return -160;
      var e = 0.0;
      for (var i = a; i < b; i++) {
        e += x[i] * x[i];
      }
      return 10 * math.log(math.max(e / (b - a), 1e-16)) / math.ln10;
    }

    int ms(double v) => (v * sampleRate / 1000).round();
    return rmsDb(index + ms(10), index + ms(110)) -
        rmsDb(index - ms(60), index - ms(10));
  }

  /// The attack to measure from, or null when attacks exist but none leaves
  /// [requiredSamples] (the caller reports "not enough audio").
  int? lastUsableAttack(
    List<double> samples,
    int sampleRate, {
    required int requiredSamples,
  }) {
    final found = attacks(samples, sampleRate);
    if (found.isEmpty) {
      return samples.length >= requiredSamples ? 0 : null;
    }
    for (final index in found.reversed) {
      if (samples.length - index >= requiredSamples) return index;
    }
    return null;
  }
}
