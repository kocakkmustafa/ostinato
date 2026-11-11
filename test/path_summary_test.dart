// OST-UX-05d ölçüt 1, 2, 3, 5: the path summary is a pure function of the
// catalog + stored records; it matches the catalog and the existing gate.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/course_access.dart';
import 'package:ostinato/app/curriculum/v1_lesson.dart';
import 'package:ostinato/app/practice/loop/practice_progress_store.dart';
import 'package:ostinato/app/practice/loop/v1_course_catalog.dart';
import 'package:ostinato/app/stage/path_summary.dart';

V1CourseCatalog _catalog() => V1CourseCatalog([
  for (final f
      in Directory('content/v1/gtr').listSync().whereType<File>().toList()
        ..sort((a, b) => a.path.compareTo(b.path)))
    if (f.path.endsWith('.json'))
      V1Lesson.fromJson(jsonDecode(f.readAsStringSync())),
]);

V1PracticeRecord _passed(String id) => V1PracticeRecord(
  lessonId: id,
  runs: 1,
  bestAccuracy: .9,
  bestHeard: .95,
  bestBpm: 60,
  lastRunAt: DateTime.utc(2026, 11, 1),
  passedAt: DateTime.utc(2026, 11, 1),
  passedBpm: 60,
);

Iterable<PathLesson> _lessons(PathSummary s) =>
    s.levels.expand((l) => l.units).expand((u) => u.lessons);

void main() {
  late V1CourseCatalog catalog;
  setUpAll(() => catalog = _catalog());

  group('olcut1 the path equals the catalog and the gate', () {
    test('level x module x lesson counts match v1_course_catalog', () {
      final s = pathSummary(catalog, const {}, const {});
      expect(s.levels.map((l) => l.level), catalog.levels.map((l) => l.level));
      for (var i = 0; i < catalog.levels.length; i++) {
        final cl = catalog.levels[i], pl = s.levels[i];
        expect(pl.units.map((u) => u.id), cl.units.map((u) => u.id));
        for (var j = 0; j < cl.units.length; j++) {
          expect(
            pl.units[j].lessons.map((l) => l.id),
            cl.units[j].lessons.map((l) => l.id),
          );
        }
        expect(pl.total, cl.units.fold<int>(0, (a, u) => a + u.lessons.length));
      }
      expect(s.lessonCount, catalog.lessons.length);
      expect(s.unitCount, catalog.units.length);
      expect(s.levelCount, catalog.levels.length);
    });

    test('status, lock and paid marks are the existing gate logic', () {
      final recs = {
        for (final l in catalog.lessons.take(12)) l.id: _passed(l.id),
      };
      for (final paid in [true, false]) {
        final s = pathSummary(
          catalog,
          recs,
          const {},
          paidFeaturesAvailable: paid,
        );
        final state = V1CourseState(catalog, recs, const {});
        var checked = 0;
        for (final l in _lessons(s)) {
          expect(l.status, state.status(catalog.lesson(l.id)!), reason: l.id);
          expect(
            l.paid,
            !isFreeV1Lesson(l.id, paidFeaturesAvailable: paid),
            reason: l.id,
          );
          expect(l.locked, !state.isOpen(l.id), reason: l.id);
          checked++;
        }
        expect(checked, catalog.lessons.length);
        for (final u in s.levels.expand((l) => l.units)) {
          expect(u.open, state.units[u.id]);
          final (d, t) = state.unitProgress(catalog.unit(u.id)!);
          expect((u.done, u.total), (d, t));
        }
      }
      final all = _lessons(pathSummary(catalog, const {}, const {}));
      expect(all.any((l) => l.paid), isTrue);
      expect(all.any((l) => !l.paid), isTrue);
      expect(all.any((l) => l.locked), isTrue);
    });
  });

  group('olcut2 next lesson and why, from recorded facts only', () {
    test('empty: the first module of the course', () {
      final s = pathSummary(catalog, const {}, const {});
      final state = V1CourseState(catalog, const {}, const {});
      expect(s.next!.lessonId, state.next!.id);
      expect(s.next!.why, PathWhy.firstModule);
      expect(_lessons(s).where((l) => l.isNext).map((l) => l.id), [
        state.next!.id,
      ]);
    });

    test('pathWhy covers every unit-open state', () {
      expect(pathWhy(V1UnitOpen.open, const []), PathWhy.firstModule);
      expect(pathWhy(V1UnitOpen.open, const ['x']), PathWhy.gateMeasured);
      expect(
        pathWhy(V1UnitOpen.openNotMeasured, const ['x']),
        PathWhy.gateNotMeasured,
      );
      expect(
        pathWhy(V1UnitOpen.openEarlierProgress, const ['x']),
        PathWhy.earlierProgress,
      );
      expect(pathWhy(V1UnitOpen.locked, const ['x']), isNull);
    });

    V1CourseUnit gated({required bool selfOnly}) => catalog.units.firstWhere(
      (u) =>
          u.requiredGateIds.isNotEmpty &&
          u.requiredGateIds.every(
            (id) => catalog.lesson(id)!.selfReportable == selfOnly,
          ),
    );

    test('a measured gate before the next lesson: gateMeasured', () {
      final u = gated(selfOnly: false);
      final recs = {
        for (final l in catalog.lessons)
          if (l.id.compareTo(u.lessons.first.id) < 0) l.id: _passed(l.id),
      };
      final s = pathSummary(catalog, recs, const {});
      expect(s.next!.unitId, u.id);
      expect(s.next!.why, PathWhy.gateMeasured);
    });

    test('a self-reported gate: gateNotMeasured, never "passed"', () {
      final u = gated(selfOnly: true);
      final recs = <String, V1PracticeRecord>{};
      final checks = <String, V1LessonCheck>{};
      for (final l in catalog.lessons) {
        if (l.id.compareTo(u.lessons.first.id) >= 0) continue;
        if (u.requiredGateIds.contains(l.id)) {
          checks[l.id] = V1LessonCheck(
            lessonId: l.id,
            evidence: V1CheckEvidence.selfReport,
            at: DateTime.utc(2026, 11, 1),
          );
        } else {
          recs[l.id] = _passed(l.id);
        }
      }
      final s = pathSummary(catalog, recs, checks);
      expect(s.next!.unitId, u.id);
      expect(s.next!.why, PathWhy.gateNotMeasured);
      final row = s.levels
          .expand((l) => l.units)
          .firstWhere((x) => x.id == u.id);
      expect(row.open, V1UnitOpen.openNotMeasured);
    });
  });

  group('olcut5 ear results stay apart from the instrument totals', () {
    test('adding an ear record does not change guitar totals or rows', () {
      final first = catalog.lessons.first.id;
      final base = {first: _passed(first)};
      final a = pathSummary(catalog, base, const {});
      final withEar = {
        ...base,
        'ear-s1-m01-01': _passed('ear-s1-m01-01'),
        'ear-s1-m01-02': _passed('ear-s1-m01-02'),
      };
      final b = pathSummary(catalog, withEar, const {});
      expect(b.instrumentLessonsPlayed, a.instrumentLessonsPlayed);
      expect(b.instrumentRuns, a.instrumentRuns);
      expect(
        b.history.map((r) => r.lessonId),
        a.history.map((r) => r.lessonId),
      );
      expect(a.ear.lessonsPlayed, 0);
      expect(b.ear.lessonsPlayed, 2);
      expect(b.ear.runs, 2);
      expect(b.levels.map((l) => l.done), a.levels.map((l) => l.done));
      expect(a.instrumentLessonsPlayed, 1);
    });
  });

  group('olcut3 history rows are the stored bests, read only', () {
    test('values are copied as stored; no run -> no row, no number', () {
      final id = catalog.lessons.first.id;
      final other = catalog.lessons[1].id;
      final r = V1PracticeRecord(
        lessonId: id,
        runs: 3,
        bestAccuracy: .5,
        bestHeard: .8,
        bestBpm: 70,
        lastRunAt: DateTime.utc(2026, 11, 2),
      );
      final s = pathSummary(catalog, {
        id: r,
        other: V1PracticeRecord(lessonId: other),
      }, const {});
      expect(s.history, hasLength(1));
      final row = s.history.single;
      expect(
        (row.runs, row.bestAccuracy, row.bestHeard, row.bestBpm, row.lastRunAt),
        (3, .5, .8, 70, DateTime.utc(2026, 11, 2)),
      );
      expect(pathSummary(catalog, const {}, const {}).history, isEmpty);
    });
  });
}
