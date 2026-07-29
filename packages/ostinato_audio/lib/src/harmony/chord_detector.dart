import 'dart:math' as math;

import 'chroma.dart';

/// The chord qualities `open_chord_drill` actually teaches. Deliberately not
/// the full jazz vocabulary: a detector that can name a Cmaj7#11 but confuses
/// E with Em is worse for a beginner than one that knows six shapes cold.
enum ChordQuality { major, minor, dominant7 }

final class ChordTemplate {
  const ChordTemplate(this.rootPitchClass, this.quality, this.intervals);

  final int rootPitchClass;
  final ChordQuality quality;

  /// Semitone offsets from the root that belong to the chord.
  final List<int> intervals;

  String get name =>
      '${Chromagram.pitchClassNames[rootPitchClass]}'
      '${switch (quality) {
        ChordQuality.major => '',
        ChordQuality.minor => 'm',
        ChordQuality.dominant7 => '7',
      }}';

  bool contains(int pitchClass) =>
      intervals.any((int i) => (rootPitchClass + i) % 12 == pitchClass % 12);

  static const _intervalsFor = <ChordQuality, List<int>>{
    ChordQuality.major: [0, 4, 7],
    ChordQuality.minor: [0, 3, 7],
    ChordQuality.dominant7: [0, 4, 7, 10],
  };

  static List<ChordTemplate> all() => [
        for (var root = 0; root < 12; root++)
          for (final q in ChordQuality.values)
            ChordTemplate(root, q, _intervalsFor[q]!),
      ];
}

final class ChordReading {
  const ChordReading({
    required this.chord,
    required this.score,
    required this.runnerUp,
    required this.runnerUpMargin,
  });

  final ChordTemplate chord;
  final double score;
  final ChordTemplate runnerUp;

  /// Distance between the best match and the best *distinct* rival.
  ///
  /// Reported, never hidden, and never synthesised. A day of this project was
  /// spent on a confidence flag whose gap turned out to be a constant the code
  /// invented when it could not measure one; the number here is always a real
  /// comparison between two scored candidates.
  final double runnerUpMargin;

  @override
  String toString() => '${chord.name} (score ${score.toStringAsFixed(3)}, '
      'runner-up ${runnerUp.name} by ${runnerUpMargin.toStringAsFixed(3)})';
}

/// Chord recognition by chroma/template correlation — the Fujishima approach.
///
/// Chosen over a learned model for a reason that is legal before it is
/// technical: Basic Pitch's weights were trained on datasets carrying
/// non-commercial terms, so embedding them would mean leaning on someone
/// else's assertion about their own distribution rights (M-O-33). This has no
/// such chain — it is arithmetic we own outright. Whether it is *good enough*
/// for open chords is a measurement, not an assumption, and the fixture set
/// exists to settle it.
final class ChordDetector {
  const ChordDetector({
    this.analyzer = const ChromaAnalyzer(),
    this.minScore = 0.55,
    this.minRunnerUpMargin = 0.06,
    this.templates,
  });

  final ChromaAnalyzer analyzer;

  /// Floor on the winning correlation. Below it, nothing in the window looks
  /// like a chord we know.
  final double minScore;

  /// Floor on how far ahead the winner must be.
  ///
  /// This is the guard that matters most in practice: a major chord and its
  /// relative minor share two of three notes, so the runner-up is *always*
  /// close and a bare argmax would flip between them on noise. Announcing
  /// "you played Am" when the evidence cannot separate Am from C is worse
  /// than saying nothing — the student corrects a mistake they did not make.
  final double minRunnerUpMargin;

  /// Restrict recognition to a known set (e.g. the six chords a drill covers).
  /// Narrowing the field is the cheapest accuracy gain available.
  final List<ChordTemplate>? templates;

  /// Returns null when the window is unusable or the evidence is too close to
  /// call. Both refusals are deliberate.
  ChordReading? detect(List<double> samples, {required int sampleRate}) {
    final chroma = analyzer.analyze(samples, sampleRate: sampleRate);
    if (chroma == null) return null;
    return classify(chroma);
  }

  ChordReading? classify(Chromagram chroma) {
    final candidates = templates ?? ChordTemplate.all();
    ChordTemplate? best, second;
    var bestScore = -1.0, secondScore = -1.0;

    for (final t in candidates) {
      final s = _score(chroma, t);
      if (s > bestScore) {
        second = best;
        secondScore = bestScore;
        best = t;
        bestScore = s;
      } else if (s > secondScore) {
        second = t;
        secondScore = s;
      }
    }
    if (best == null || second == null) return null;

    final margin = bestScore - secondScore;
    if (bestScore < minScore || margin < minRunnerUpMargin) return null;
    return ChordReading(
      chord: best,
      score: bestScore,
      runnerUp: second,
      runnerUpMargin: margin,
    );
  }

  /// Cosine similarity between the chromagram and a binary chord mask.
  ///
  /// Cosine rather than a raw dot product because the mask sizes differ: a
  /// dominant 7th has four notes to a triad's three, and an uncorrected dot
  /// product would hand every ambiguous window to the bigger chord.
  double _score(Chromagram chroma, ChordTemplate t) {
    var dot = 0.0, chromaNorm = 0.0, maskNorm = 0.0;
    for (var pc = 0; pc < 12; pc++) {
      final mask = t.contains(pc) ? 1.0 : 0.0;
      dot += chroma[pc] * mask;
      chromaNorm += chroma[pc] * chroma[pc];
      maskNorm += mask * mask;
    }
    if (chromaNorm == 0 || maskNorm == 0) return 0;
    return dot / (math.sqrt(chromaNorm) * math.sqrt(maskNorm));
  }
}
