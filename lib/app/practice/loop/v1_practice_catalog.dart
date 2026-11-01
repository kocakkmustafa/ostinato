import 'dart:convert';

import 'package:flutter/services.dart';

import '../../curriculum/v1_lesson.dart';
import 'practice_score.dart';

/// The v1 guitar lessons the measured practice loop can run: microphone
/// lessons (`M`, `M!`) with a written pitch sequence. Course order = lesson id
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

  static bool isPracticable(V1Lesson l) {
    final seq = l.practice.sequence;
    if (l.course != 'gtr' || seq == null) return false;
    final m = l.practice.measurement;
    if (!m.contains('M') && !m.contains('M!')) return false;
    // Chord lessons need the A4 chord engine; their sequences are chord
    // charts, not single notes.
    if (l.practice.engineSteps.contains('A4')) return false;
    try {
      return PracticeScore.parse(seq).hasPitches;
    } on FormatException {
      return false;
    }
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
