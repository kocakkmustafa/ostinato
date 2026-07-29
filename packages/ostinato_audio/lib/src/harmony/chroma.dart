import 'dart:math' as math;

/// Energy per pitch class (C, C#, D, … B), octave-folded.
///
/// The point of folding is that a chord's identity does not depend on which
/// octave each note lands in: an E major played on the bottom four strings and
/// the same chord an octave up are the same chord.
final class Chromagram {
  const Chromagram(this.values);

  /// Twelve bins starting at C. Normalised so the largest bin is 1.0; absolute
  /// level is the confidence gate's business, not harmony's.
  final List<double> values;

  static const pitchClassNames = <String>[
    'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'
  ];

  double operator [](int pitchClass) => values[pitchClass % 12];

  @override
  String toString() => [
        for (var i = 0; i < 12; i++)
          '${pitchClassNames[i]}:${values[i].toStringAsFixed(2)}'
      ].join(' ');
}

/// Builds chromagrams by evaluating the transform **at exact note frequencies**
/// rather than reading a linear FFT grid.
///
/// This sidesteps the defect that cost a night in O-019. A uniform bin grid is
/// `sampleRate / frameSize` apart — tens of Hz — while the semitones we need to
/// separate near the bottom of a guitar's range are about 5 Hz apart. On such a
/// grid a low note falls between bins, its leakage shifts frame to frame, and
/// the reading wobbles. Evaluating directly at each semitone's frequency costs
/// one correlation per note we actually care about and has no grid to fall
/// between.
///
/// The cost is a longer window: separating semitones 5 Hz apart needs roughly
/// 200 ms of signal, which is why [minWindowMs] is what it is. Chords are held,
/// so this is affordable here in a way it would not be for onset timing.
final class ChromaAnalyzer {
  const ChromaAnalyzer({
    this.lowestMidi = 40, // E2 — a guitar's lowest open string
    this.highestMidi = 84, // C6 — above this, guitar/piano partials dominate
    this.minWindowMs = 200,
  });

  final int lowestMidi;
  final int highestMidi;

  /// Below this the low semitones are not resolvable and the chromagram is a
  /// blur that still *looks* like an answer. Analysis refuses instead.
  final double minWindowMs;

  static double midiToHz(int midi) => 440.0 * math.pow(2, (midi - 69) / 12.0);

  /// Returns null when the window is too short to resolve the low register —
  /// a blurred chromagram is worse than no chromagram, because it produces a
  /// confident-looking chord from smeared energy.
  Chromagram? analyze(List<double> samples, {required int sampleRate}) {
    if (samples.length * 1000 / sampleRate < minWindowMs) return null;

    final bins = List<double>.filled(12, 0);
    final n = samples.length;

    // Hann window: without it, the sidelobes of a strong note leak into
    // neighbouring semitones and every chord grows notes it does not have.
    //
    // Computed once and reused. It was originally rebuilt inside the semitone
    // loop — the same 45 identical cosine sweeps per analysis, for no reason
    // beyond where the line happened to sit.
    final windowed = List<double>.filled(n, 0);
    for (var i = 0; i < n; i++) {
      windowed[i] = samples[i] * (0.5 - 0.5 * math.cos(2 * math.pi * i / (n - 1)));
    }

    for (var midi = lowestMidi; midi <= highestMidi; midi++) {
      // Goertzel-style recurrence: one multiply-add per sample instead of a
      // sine and a cosine. Same result as evaluating the transform at this
      // exact frequency, which is the property that keeps low semitones off a
      // bin grid they would otherwise fall between.
      final omega = 2 * math.pi * midiToHz(midi) / sampleRate;
      final coeff = 2 * math.cos(omega);
      var s1 = 0.0, s2 = 0.0;
      for (var i = 0; i < n; i++) {
        final s0 = windowed[i] + coeff * s1 - s2;
        s2 = s1;
        s1 = s0;
      }
      final re = s1 - s2 * math.cos(omega);
      final im = s2 * math.sin(omega);
      bins[midi % 12] += math.sqrt(re * re + im * im) / n;
    }

    final peak = bins.reduce(math.max);
    if (peak <= 0) return null;
    return Chromagram([for (final v in bins) v / peak]);
  }
}
