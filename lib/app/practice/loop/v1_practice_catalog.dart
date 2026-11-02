import 'dart:convert';

import 'package:flutter/services.dart';

import '../../curriculum/v1_lesson.dart';
import 'practice_score.dart';

/// The v1 guitar lessons the measured practice loop can run: microphone
/// lessons (`M`, `M!`) with a written pitch sequence, or a rhythm-only line
/// in an A3 lesson (onset timing). Course order = lesson id
/// order (`gtr-s1-m02-02` < `gtr-s1-m02-03` < … < `gtr-s1-test`).
final class V1PracticeCatalog {
  V1PracticeCatalog(Iterable<V1Lesson> lessons)
    : lessons = List.unmodifiable(
        lessons.where(isPracticable).toList()
          ..sort((a, b) => a.id.compareTo(b.id)),
      );

  static const String assetPrefix = 'content/v1/gtr/';

  final List<V1Lesson> lessons;

  List<String> get orderedIds => [for (final l in lessons) l.id];

  V1Lesson? nextAfter(String id) {
    final i = lessons.indexWhere((l) => l.id == id);
    return i < 0 || i + 1 >= lessons.length ? null : lessons[i + 1];
  }

  /// Technique tokens the single-note judge cannot carry (guide §3.3):
  /// double stops `C3/E4`, hammer-on `h`, pull-off `p`, slide ` / `, bend
  /// `b`/`pb`, release `r`, vibrato `vib`.
  static final RegExp technique = RegExp(
    r'(?:^|\s)(?:h|p|b|pb|r|vib|/)(?=\s|$)|[A-G][#b♯♭]?\d/[A-G]',
  );

  /// The lesson's line as the practice screen runs it (guitar power chords
  /// before a rhythm are labels); null without a sequence or when the line
  /// does not parse.
  static PracticeScore? scoreOf(V1Lesson l) {
    final seq = l.practice.sequence;
    if (seq == null) return null;
    try {
      return PracticeScore.parse(seq, powerChordLabels: l.course == 'gtr');
    } on FormatException {
      return null;
    }
  }

  /// Engine steps a rhythm-only line can carry: A3 judges the onsets; A1
  /// (tuning) and A2 (which open string) are not in a line without pitches.
  static const Set<String> _rhythmSteps = {'A1', 'A2', 'A3'};

  static bool isPracticable(V1Lesson l) {
    final seq = l.practice.sequence;
    if (l.course != 'gtr' || seq == null) return false;
    final m = l.practice.measurement;
    if (!m.contains('M') && !m.contains('M!')) return false;
    final steps = l.practice.engineSteps;
    // Chord lessons need the A4 chord engine; their sequences are chord
    // charts, not single notes, and a chord-labelled rhythm still needs the
    // chord itself checked.
    if (steps.contains('A4')) return false;
    final score = scoreOf(l);
    if (score == null) return false;
    if (score.hasPitches) {
      // Technique notation (`h` would otherwise parse as a half-note onset).
      return !technique.hasMatch(seq);
    }
    // Rhythm-only line (`4/4: q q ee q | h h`): A3 onset timing. Here `h` is
    // a half note, never a hammer-on.
    return score.isRhythmOnly &&
        steps.contains('A3') &&
        steps.every(_rhythmSteps.contains);
  }

  static Future<V1PracticeCatalog> load({AssetBundle? bundle}) async {
    final b = bundle ?? rootBundle;
    final manifest = await AssetManifest.loadFromAssetBundle(b);
    final paths =
        manifest
            .listAssets()
            .where((p) => p.startsWith(assetPrefix) && p.endsWith('.json'))
            .toList()
          ..sort();
    final lessons = <V1Lesson>[];
    for (final path in paths) {
      lessons.add(V1Lesson.fromJson(jsonDecode(await b.loadString(path))));
    }
    return V1PracticeCatalog(lessons);
  }
}
