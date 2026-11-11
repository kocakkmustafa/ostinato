import '../course_access.dart';
import '../ostinato_release_policy.dart';
import '../practice/loop/practice_progress_store.dart';
import '../practice/loop/v1_course_catalog.dart';

/// OST-UX-05d: the "My path" drawer as plain data. Pure: the same catalog and
/// the same stored records always give the same value; nothing is stored,
/// nothing is computed that the records do not say.

/// Why the next lesson is the next one. Only recorded facts (the unit's
/// open state, which comes from the gate clearances).
enum PathWhy { firstModule, gateMeasured, gateNotMeasured, earlierProgress }

/// [open] is the unit's [V1UnitOpen]; [requiredGateIds] its gates. A locked
/// unit never holds the next lesson, so it has no reason (null).
PathWhy? pathWhy(V1UnitOpen open, List<String> requiredGateIds) =>
    switch (open) {
      V1UnitOpen.open =>
        requiredGateIds.isEmpty ? PathWhy.firstModule : PathWhy.gateMeasured,
      V1UnitOpen.openNotMeasured => PathWhy.gateNotMeasured,
      V1UnitOpen.openEarlierProgress => PathWhy.earlierProgress,
      V1UnitOpen.locked => null,
    };

final class PathLesson {
  const PathLesson({
    required this.id,
    required this.status,
    required this.paid,
    required this.locked,
    required this.isNext,
    this.runs = 0,
    this.bpm,
  });
  final String id;
  final V1LessonStatus status;

  /// Needs a membership (the v1 gate: `isFreeV1Lesson`).
  final bool paid;

  /// The module gate has not opened it (`V1CourseState.isOpen`).
  final bool locked;
  final bool isNext;

  /// Stored runs, and the tempo of the stored pass / completion (null when
  /// the record has none): read from the record, never computed.
  final int runs;
  final int? bpm;
}

final class PathUnit {
  const PathUnit({
    required this.id,
    required this.level,
    required this.module,
    required this.track,
    required this.open,
    required this.done,
    required this.total,
    required this.lessons,
  });
  final String id;
  final int level;
  final int? module;
  final String? track;
  final V1UnitOpen open;
  final int done, total;
  final List<PathLesson> lessons;
}

final class PathLevel {
  const PathLevel(this.level, this.units, this.done, this.total);
  final int level;
  final List<PathUnit> units;
  final int done, total;
}

final class PathNext {
  const PathNext(this.lessonId, this.unitId, this.why);
  final String lessonId, unitId;
  final PathWhy? why;
}

/// One lesson's stored bests, copied as they are (read only).
final class PathHistoryRow {
  const PathHistoryRow({
    required this.lessonId,
    required this.runs,
    required this.bestAccuracy,
    required this.bestHeard,
    required this.bestBpm,
    required this.lastRunAt,
  });
  final String lessonId;
  final int runs;
  final double? bestAccuracy, bestHeard;
  final int? bestBpm;
  final DateTime? lastRunAt;
}

/// Ear-training results: their own section, never added to the instrument.
final class PathEar {
  const PathEar(this.lessonsPlayed, this.runs);
  final int lessonsPlayed, runs;
}

final class PathSummary {
  const PathSummary({
    required this.levels,
    required this.next,
    required this.history,
    required this.ear,
    required this.instrumentLessonsPlayed,
    required this.instrumentRuns,
  });
  final List<PathLevel> levels;
  final PathNext? next;

  /// Instrument (catalog course) lessons that have a run, in course order.
  final List<PathHistoryRow> history;
  final PathEar ear;
  final int instrumentLessonsPlayed, instrumentRuns;

  int get levelCount => levels.length;
  int get unitCount => levels.fold(0, (a, l) => a + l.units.length);
  int get lessonCount => levels.fold(0, (a, l) => a + l.total);
}

/// Ear lessons are the v1 course group `ear` (same id shape as the gate's).
final RegExp _earId = RegExp(r'^ear-s\d+-');

PathSummary pathSummary(
  V1CourseCatalog catalog,
  Map<String, V1PracticeRecord> records,
  Map<String, V1LessonCheck> checks, {
  bool paidFeaturesAvailable = ostinatoPaidFeaturesAvailable,
}) {
  final state = V1CourseState(catalog, records, checks);
  final next = state.next;
  final levels = <PathLevel>[];
  for (final level in catalog.levels) {
    var done = 0, total = 0;
    final units = <PathUnit>[];
    for (final u in level.units) {
      final (d, t) = state.unitProgress(u);
      done += d;
      total += t;
      units.add(
        PathUnit(
          id: u.id,
          level: u.level,
          module: u.module,
          track: u.track,
          open: state.units[u.id] ?? V1UnitOpen.locked,
          done: d,
          total: t,
          lessons: [
            for (final l in u.lessons)
              PathLesson(
                id: l.id,
                status: state.status(l),
                paid: !isFreeV1Lesson(
                  l.id,
                  paidFeaturesAvailable: paidFeaturesAvailable,
                ),
                locked: !state.isOpen(l.id),
                isNext: l.id == next?.id,
                runs: records[l.id]?.runs ?? 0,
                bpm: switch (state.status(l)) {
                  V1LessonStatus.completed => records[l.id]?.completedBpm,
                  V1LessonStatus.passed => records[l.id]?.passedBpm,
                  _ => null,
                },
              ),
          ],
        ),
      );
    }
    levels.add(PathLevel(level.level, units, done, total));
  }
  final history = <PathHistoryRow>[];
  var runs = 0;
  for (final l in catalog.lessons) {
    final r = records[l.id];
    if (r == null || r.runs <= 0) continue;
    runs += r.runs;
    history.add(
      PathHistoryRow(
        lessonId: l.id,
        runs: r.runs,
        bestAccuracy: r.bestAccuracy,
        bestHeard: r.bestHeard,
        bestBpm: r.bestBpm,
        lastRunAt: r.lastRunAt,
      ),
    );
  }
  var earLessons = 0, earRuns = 0;
  for (final r in records.values) {
    if (r.runs > 0 && _earId.hasMatch(r.lessonId)) {
      earLessons++;
      earRuns += r.runs;
    }
  }
  return PathSummary(
    levels: levels,
    next: next == null
        ? null
        : PathNext(
            next.id,
            next.unitId,
            pathWhy(
              state.units[next.unitId] ?? V1UnitOpen.locked,
              catalog.unitOf(next.id).requiredGateIds,
            ),
          ),
    history: history,
    ear: PathEar(earLessons, earRuns),
    instrumentLessonsPlayed: history.length,
    instrumentRuns: runs,
  );
}
