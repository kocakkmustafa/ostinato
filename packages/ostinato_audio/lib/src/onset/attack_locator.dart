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
    this.bufferStartCandidate = true,
    this.startLoudWithinDb = 6,
    this.maxBelowLoudestDb,
  });

  /// E41 arm A1, default since E42: when the buffer opens loud (first 50 ms within
  /// [startLoudWithinDb] of the loudest 50 ms), index 0 is also a candidate:
  /// a pluck that landed exactly at the buffer start has no frame before it
  /// for the flux detector to compare with.
  final bool bufferStartCandidate;
  final double startLoudWithinDb;

  /// E41 arm A2 (null = off): a candidate is kept only if its level (10–110 ms
  /// after it) is within this many dB of the loudest candidate's. Noise that
  /// AGC lifts after a note ends is spectral change with a rising level too,
  /// but far quieter than a pluck.
  final double? maxBelowLoudestDb;

  final OnsetDetector detector;
  final double minRelativeStrength;

  /// Required level rise across an attack; null disables the check (E39).
  final double? minRiseDb;

  /// Sample indices of the retained attacks, in time order.
  /// [absoluteStartSample] / [cache]: see [OnsetDetector.detect] (E43).
  List<int> attacks(List<double> samples, int sampleRate,
      {int? absoluteStartSample, OnsetFrameCache? cache}) {
    final rise = minRiseDb;
    int index(Onset o) => (o.tUs * sampleRate / 1000000).round();
    final onsets = [
      for (final o in detector.detect(samples,
          sampleRate: sampleRate,
          tStartUs: 0,
          absoluteStartSample: absoluteStartSample,
          cache: cache))
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

  static double _postLevelDb(List<double> x, int sampleRate, int index) {
    final a = index + (0.01 * sampleRate).round();
    final b = math.min(x.length, index + (0.11 * sampleRate).round());
    if (b <= a) return -160;
    var e = 0.0;
    for (var i = a; i < b; i++) {
      e += x[i] * x[i];
    }
    return 10 * math.log(math.max(e / (b - a), 1e-16)) / math.ln10;
  }

  bool _opensLoud(List<double> x, int sampleRate) {
    final frame = math.max(1, (0.05 * sampleRate).round());
    if (x.length < frame) return false;
    double db(int s) {
      var e = 0.0;
      for (var i = s; i < s + frame; i++) {
        e += x[i] * x[i];
      }
      return 10 * math.log(math.max(e / frame, 1e-16)) / math.ln10;
    }

    var loudest = -160.0;
    for (var s = 0; s + frame <= x.length; s += frame) {
      loudest = math.max(loudest, db(s));
    }
    return db(0) >= loudest - startLoudWithinDb;
  }

  /// The attack to measure from, or null when attacks exist but none leaves
  /// [requiredSamples] (the caller reports "not enough audio").
  int? lastUsableAttack(
    List<double> samples,
    int sampleRate, {
    required int requiredSamples,
    int? absoluteStartSample,
    OnsetFrameCache? cache,
  }) {
    var found = attacks(samples, sampleRate,
        absoluteStartSample: absoluteStartSample, cache: cache);
    if (bufferStartCandidate &&
        (found.isEmpty || found.first > 0) &&
        _opensLoud(samples, sampleRate)) {
      found = [0, ...found];
    }
    final below = maxBelowLoudestDb;
    if (below != null && found.length > 1) {
      final levels = [
        for (final i in found) _postLevelDb(samples, sampleRate, i)
      ];
      final loudest = levels.reduce(math.max);
      found = [
        for (var k = 0; k < found.length; k++)
          if (levels[k] >= loudest - below) found[k],
      ];
    }
    if (found.isEmpty) {
      return samples.length >= requiredSamples ? 0 : null;
    }
    for (final index in found.reversed) {
      if (samples.length - index >= requiredSamples) return index;
    }
    return null;
  }
}
