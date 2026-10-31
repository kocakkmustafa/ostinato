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
/// Rule ("last usable attack"): among attacks whose flux strength is at least
/// [minRelativeStrength] of the strongest one, take the latest that still
/// leaves `requiredSamples` after it. A later note whose attack arrives too
/// close to the end of the buffer is ignored rather than mistaken for the
/// note being measured. A buffer with no attack at all is a note that was
/// already ringing when the buffer began: its start (index 0) is used.
final class AttackLocator {
  const AttackLocator({
    this.detector = const OnsetDetector(),
    this.minRelativeStrength = 0.2,
  });

  final OnsetDetector detector;
  final double minRelativeStrength;

  /// Sample indices of the retained attacks, in time order.
  List<int> attacks(List<double> samples, int sampleRate) {
    final onsets =
        detector.detect(samples, sampleRate: sampleRate, tStartUs: 0);
    if (onsets.isEmpty) return const [];
    final strongest = onsets.map((o) => o.strength).reduce(math.max);
    return [
      for (final o in onsets)
        if (o.strength >= minRelativeStrength * strongest)
          (o.tUs * sampleRate / 1000000).round(),
    ];
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
