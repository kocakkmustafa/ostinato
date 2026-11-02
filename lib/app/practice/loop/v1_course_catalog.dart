import 'dart:convert';

import 'package:flutter/services.dart';

import '../../curriculum/v1_lesson.dart';
import 'practice_progress_store.dart';
import 'v1_practice_catalog.dart';

/// How a v1 lesson runs in this build (contract
/// docs/v1-curriculum/00-ders-format-sozlesmesi.md §3, §4.2).
enum V1LessonAvailability {
  /// The measured practice loop runs it (A2 single notes + A3 timing).
  measured,

  /// A1 tuning lesson: the precise tuner (±5 c) is the practice.
  tuner,

  /// `M` / `M~` lesson whose engine step is not in this build: shipped as Ö
  /// (§4.2) — checklist, completion recorded as self-reported.
  selfCheck,

  /// A self-check lesson by design (`Ö` only).
  selfCheckLesson,

  /// `K` camera lesson: the camera check is not in this build; checklist.
  camera,

  /// `D` on-screen drill: the drill generator is not built yet; the lesson
  /// text and a self-check.
  drillSoon,

  /// `M!` checkpoint or level test that cannot be measured in this build:
  /// it cannot be passed. A self-check opens the next unit labelled
  /// "not measured" (§4.2's level-test rule, applied to module gates).
  held,
}

/// Why a lesson is not measured in this build (shown on the reader).
enum V1PendingReason {
  none,

  /// A4 chord engine.
  chords,

  /// A5 pitch track (bends, vibrato).
  pitchTrack,

  /// A6/A6p piano engine.
  piano,

  /// A7 camera check.
  camera,

  /// Technique notation (double stops, hammer-on/pull-off, slides, bends,
  /// vibrato; 90-ders-yazim-kilavuzu §3.3) the single-note judge cannot read.
  technique,

  /// No written single-note line the practice screen can follow (no
  /// sequence, a rhythm-only line, or a chart).
  notation,

  /// D drill generator (F2.6).
  drill,
}

final class V1CourseLesson {
  const V1CourseLesson({
    required this.lesson,
    required this.availability,
    required this.reason,
    required this.unitId,
  });

  final V1Lesson lesson;
  final V1LessonAvailability availability;
  final V1PendingReason reason;
  final String unitId;

  String get id => lesson.id;

  /// Self-reported completion is offered (never on measured/tuner lessons).
  bool get selfReportable =>
      availability != V1LessonAvailability.measured &&
      availability != V1LessonAvailability.tuner;
}

/// A module (`gtr-s1-m02`), a track module (`gtr-s4-m19a`) or a level test
/// (`gtr-s1-test`, `gtr-s4-test-a`). Its last lesson is its gate (§6.4).
final class V1CourseUnit {
  const V1CourseUnit({
    required this.id,
    required this.level,
    required this.module,
    required this.track,
    required this.lessons,
    required this.requiredGateIds,
  });

  final String id;
  final int level;

  /// Null for a level test.
  final int? module;

  /// `a` / `b` for the S4 tracks and their tests, else null.
  final String? track;
  final List<V1CourseLesson> lessons;

  /// Lesson ids whose clearance opens this unit; empty = open from the start.
  final List<String> requiredGateIds;

  bool get isTest => module == null;
  V1CourseLesson get gate => lessons.last;
}

final class V1CourseLevel {
  const V1CourseLevel(this.level, this.units);
  final int level;
  final List<V1CourseUnit> units;
}

/// The full v1 guitar course: every `gtr` lesson, grouped into levels and
/// units, in id order, each with its [V1LessonAvailability] in this build.
final class V1CourseCatalog {
  V1CourseCatalog(Iterable<V1Lesson> lessons) {
    final sorted = lessons.where((l) => l.course == 'gtr').toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    final byUnit = <String, List<V1Lesson>>{};
    for (final l in sorted) {
      byUnit.putIfAbsent(unitIdOf(l.id), () => []).add(l);
    }
    final units = <V1CourseUnit>[];
    final ids = byUnit.keys.toList();
    for (var i = 0; i < ids.length; i++) {
      final id = ids[i];
      final m = _unitPattern.firstMatch(id)!;
      final level = int.parse(m.group(1)!);
      final mod = m.group(2) == null ? null : int.parse(m.group(2)!);
      final track = m.group(3) ?? m.group(4);
      final members = byUnit[id]!;
      units.add(
        V1CourseUnit(
          id: id,
          level: level,
          module: mod,
          track: track,
          lessons: List.unmodifiable([
            for (final l in members)
              () {
                final (a, r) = classify(l);
                return V1CourseLesson(
                  lesson: l,
                  availability: a,
                  reason: r,
                  unitId: id,
                );
              }(),
          ]),
          requiredGateIds: List.unmodifiable(
            _requiredGates(
              id,
              level,
              mod,
              track,
              members.first,
              byUnit,
              i == 0 ? null : ids[i - 1],
            ),
          ),
        ),
      );
    }
    this.units = List.unmodifiable(units);
    this.lessons = List.unmodifiable([for (final u in units) ...u.lessons]);
    _byId = {for (final l in this.lessons) l.id: l};
    _unitById = {for (final u in units) u.id: u};
  }

  static const String assetPrefix = V1PracticeCatalog.assetPrefix;

  late final List<V1CourseUnit> units;

  /// Course order (= id order).
  late final List<V1CourseLesson> lessons;
  late final Map<String, V1CourseLesson> _byId;
  late final Map<String, V1CourseUnit> _unitById;

  List<String> get orderedIds => [for (final l in lessons) l.id];

  List<V1CourseLevel> get levels {
    final out = <int, List<V1CourseUnit>>{};
    for (final u in units) {
      out.putIfAbsent(u.level, () => []).add(u);
    }
    return [for (final e in out.entries) V1CourseLevel(e.key, e.value)];
  }

  V1CourseLesson? lesson(String id) => _byId[id];
  V1CourseUnit? unit(String id) => _unitById[id];
  V1CourseUnit unitOf(String lessonId) => _unitById[unitIdOf(lessonId)]!;

  V1CourseLesson? nextAfter(String id) {
    final i = lessons.indexWhere((l) => l.id == id);
    return i < 0 || i + 1 >= lessons.length ? null : lessons[i + 1];
  }

  static final RegExp _unitPattern = RegExp(
    r'^gtr-s(\d)-(?:m(\d{2})([ab])?|test(?:-([ab]))?)$',
  );

  /// `gtr-s1-m02-03` → `gtr-s1-m02`; `gtr-s1-test` → itself.
  static String unitIdOf(String lessonId) {
    final m = RegExp(r'^(.*-m\d{2}[ab]?)-\d{2}$').firstMatch(lessonId);
    return m == null ? lessonId : m.group(1)!;
  }

  /// Contract §9: a unit opens when the previous unit's gate clears; the S4
  /// tracks need M15 + M17 (§9.4, or the first lesson's listed
  /// prerequisites); a track test follows its own track.
  static List<String> _requiredGates(
    String id,
    int level,
    int? module,
    String? track,
    V1Lesson first,
    Map<String, List<V1Lesson>> byUnit,
    String? previousUnit,
  ) {
    String? gateOf(String unitId) => byUnit[unitId]?.last.id;
    if (module != null && track != null) {
      if (first.prerequisites.isNotEmpty) return first.prerequisites;
      return [
        for (final m in const [15, 17])
          ?gateOf('gtr-s$level-m${m.toString().padLeft(2, '0')}'),
      ];
    }
    if (module == null && track != null) {
      final g = byUnit.keys
          .where((k) => RegExp('^gtr-s$level-m\\d{2}$track\$').hasMatch(k))
          .map(gateOf)
          .nonNulls
          .toList();
      return g;
    }
    if (first.prerequisites.isNotEmpty) return first.prerequisites;
    final prev = previousUnit == null ? null : gateOf(previousUnit);
    return prev == null ? const [] : [prev];
  }

  static RegExp get technique => V1PracticeCatalog.technique;

  static (V1LessonAvailability, V1PendingReason) classify(V1Lesson l) {
    final m = l.practice.measurement;
    final steps = l.practice.engineSteps;
    final mic = m.contains('M') || m.contains('M!');
    if (mic && steps.every((s) => s == 'A1')) {
      return (V1LessonAvailability.tuner, V1PendingReason.none);
    }
    if (V1PracticeCatalog.isPracticable(l)) {
      return (V1LessonAvailability.measured, V1PendingReason.none);
    }
    final seq = l.practice.sequence;
    final dominant = m.first;
    final reason = steps.contains('A7')
        ? V1PendingReason.camera
        : dominant == 'D'
        ? V1PendingReason.drill
        : steps.contains('A5')
        ? V1PendingReason.pitchTrack
        : steps.contains('A4')
        ? V1PendingReason.chords
        : steps.contains('A6') || steps.contains('A6p')
        ? V1PendingReason.piano
        : seq != null && technique.hasMatch(seq)
        ? V1PendingReason.technique
        : V1PendingReason.notation;
    if (dominant == 'D') return (V1LessonAvailability.drillSoon, reason);
    if (m.contains('M!')) return (V1LessonAvailability.held, reason);
    if (dominant == 'K') return (V1LessonAvailability.camera, reason);
    if (m.contains('M') || m.contains('M~')) {
      return (V1LessonAvailability.selfCheck, reason);
    }
    if (m.every((c) => c == 'Ö')) {
      return (V1LessonAvailability.selfCheckLesson, V1PendingReason.none);
    }
    return (V1LessonAvailability.drillSoon, reason);
  }

  static Future<V1CourseCatalog> load({AssetBundle? bundle}) async {
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
    return V1CourseCatalog(lessons);
  }
}

/// How a gate (a unit's last lesson) is cleared.
enum V1GateClear {
  none,

  /// Measured pass (practice loop or tuner).
  measured,

  /// Self-check on a lesson this build cannot measure.
  selfReported,
}

/// Whether a unit is open, and on what evidence.
enum V1UnitOpen {
  locked,

  /// First unit, or every required gate passed by measurement.
  open,

  /// At least one required gate cleared only by self-check: open, labelled
  /// "not measured".
  openNotMeasured,

  /// Required gates not cleared, but the learner already has progress in the
  /// unit (earlier builds unlocked lessons one by one): kept open.
  openEarlierProgress,
}

/// Per-lesson state for the course screen.
enum V1LessonStatus {
  locked,
  open,

  /// Measured lesson: played at least once, not passed.
  played,

  /// Measured pass at the opening tempo (opens nothing on its own unless it
  /// is the gate; contract §6.3).
  passed,

  /// Measured pass at the target tempo.
  completed,

  /// Tuner lesson: every string in tune, measured by the tuner.
  tuned,

  /// Self-check done (self-reported, not measured).
  selfReported,

  /// Measured lesson that only has a self-report from a build that could not
  /// measure it: "repeat with measurement".
  repeatWithMeasurement,

  /// Held checkpoint, not practised yet.
  held,

  /// Held checkpoint practised as a self-check (not passed).
  heldSelfReported,
}

/// Unlock state over the full course (contract §6.4, §9). Inside an open
/// unit every lesson is open (suggested order, no lock).
final class V1CourseState {
  V1CourseState(this.catalog, this.records, this.checks) {
    for (final u in catalog.units) {
      units[u.id] = _open(u);
    }
  }

  final V1CourseCatalog catalog;
  final Map<String, V1PracticeRecord> records;
  final Map<String, V1LessonCheck> checks;
  final Map<String, V1UnitOpen> units = {};

  V1GateClear gateClear(V1CourseLesson l) {
    if (records[l.id]?.passed ?? false) return V1GateClear.measured;
    final check = checks[l.id];
    if (check == null) return V1GateClear.none;
    if (check.evidence == V1CheckEvidence.tunerCheck) {
      return V1GateClear.measured;
    }
    return l.selfReportable ? V1GateClear.selfReported : V1GateClear.none;
  }

  V1UnitOpen _open(V1CourseUnit u) {
    if (u.requiredGateIds.isEmpty) return V1UnitOpen.open;
    final clears = [
      for (final id in u.requiredGateIds)
        catalog.lesson(id) == null
            ? V1GateClear.none
            : gateClear(catalog.lesson(id)!),
    ];
    if (clears.every((c) => c == V1GateClear.measured)) return V1UnitOpen.open;
    if (clears.every((c) => c != V1GateClear.none)) {
      return V1UnitOpen.openNotMeasured;
    }
    final progress = u.lessons.any(
      (l) => (records[l.id]?.passed ?? false) || checks.containsKey(l.id),
    );
    return progress ? V1UnitOpen.openEarlierProgress : V1UnitOpen.locked;
  }

  bool isOpen(String lessonId) =>
      (units[V1CourseCatalog.unitIdOf(lessonId)] ?? V1UnitOpen.locked) !=
      V1UnitOpen.locked;

  V1LessonStatus status(V1CourseLesson l) {
    final r = records[l.id];
    final c = checks[l.id];
    switch (l.availability) {
      case V1LessonAvailability.measured:
        if (r?.completed ?? false) return V1LessonStatus.completed;
        if (r?.passed ?? false) return V1LessonStatus.passed;
        if (c?.evidence == V1CheckEvidence.selfReport) {
          return V1LessonStatus.repeatWithMeasurement;
        }
        if (!isOpen(l.id)) return V1LessonStatus.locked;
        return (r?.runs ?? 0) > 0 ? V1LessonStatus.played : V1LessonStatus.open;
      case V1LessonAvailability.tuner:
        if (c?.evidence == V1CheckEvidence.tunerCheck) {
          return V1LessonStatus.tuned;
        }
        if (r?.completed ?? false) return V1LessonStatus.completed;
        if (r?.passed ?? false) return V1LessonStatus.passed;
        return isOpen(l.id) ? V1LessonStatus.open : V1LessonStatus.locked;
      case V1LessonAvailability.held:
        if (r?.passed ?? false) {
          return (r!.completed)
              ? V1LessonStatus.completed
              : V1LessonStatus.passed;
        }
        if (c != null) return V1LessonStatus.heldSelfReported;
        return isOpen(l.id) ? V1LessonStatus.held : V1LessonStatus.locked;
      case V1LessonAvailability.selfCheck:
      case V1LessonAvailability.selfCheckLesson:
      case V1LessonAvailability.camera:
      case V1LessonAvailability.drillSoon:
        if (r?.passed ?? false) {
          return (r!.completed)
              ? V1LessonStatus.completed
              : V1LessonStatus.passed;
        }
        if (c != null) return V1LessonStatus.selfReported;
        return isOpen(l.id) ? V1LessonStatus.open : V1LessonStatus.locked;
    }
  }

  /// Finished for "Start next lesson": measured lessons need a measured
  /// pass; others a check of the kind they offer.
  bool isDone(V1CourseLesson l) => switch (status(l)) {
    V1LessonStatus.passed ||
    V1LessonStatus.completed ||
    V1LessonStatus.tuned ||
    V1LessonStatus.selfReported ||
    V1LessonStatus.heldSelfReported => true,
    _ => false,
  };

  /// The first open lesson in course order that is not done.
  V1CourseLesson? get next {
    for (final l in catalog.lessons) {
      if (isOpen(l.id) && !isDone(l)) return l;
    }
    return null;
  }

  /// Done / total lessons in a unit.
  (int, int) unitProgress(V1CourseUnit u) =>
      (u.lessons.where(isDone).length, u.lessons.length);
}
