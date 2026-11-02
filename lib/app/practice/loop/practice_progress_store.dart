import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../account_data_directory.dart';
import '../../account_data_operations.dart';
import 'practice_outcome.dart';

/// F2.5 — local, per-account record of measured practice on v1 lessons.
/// Separate from the guitar journey's self-report store on purpose: this
/// file carries `evidence: measured_practice` and never claims more than the
/// counts the microphone produced. No audio, no network.
final class V1PracticeRecord {
  const V1PracticeRecord({
    required this.lessonId,
    this.runs = 0,
    this.bestAccuracy,
    this.bestHeard,
    this.bestBpm,
    this.lastRunAt,
    this.passedAt,
    this.passedBpm,
    this.completedAt,
    this.completedBpm,
  });

  final String lessonId;
  final int runs;
  final double? bestAccuracy, bestHeard;
  final int? bestBpm;
  final DateTime? lastRunAt;

  /// First measured pass of the gate (opening tempo or faster, contract
  /// §6.3); opens the next lesson.
  final DateTime? passedAt;
  final int? passedBpm;

  /// First measured pass at the target tempo: the lesson is "completed".
  final DateTime? completedAt;
  final int? completedBpm;

  bool get passed => passedAt != null;
  bool get completed => completedAt != null;

  Map<String, Object?> toJson() => {
    'lessonId': lessonId,
    'runs': runs,
    'bestAccuracy': bestAccuracy,
    'bestHeard': bestHeard,
    'bestBpm': bestBpm,
    'lastRunAt': lastRunAt?.toUtc().toIso8601String(),
    'passedAt': passedAt?.toUtc().toIso8601String(),
    'passedBpm': passedBpm,
    'completedAt': completedAt?.toUtc().toIso8601String(),
    'completedBpm': completedBpm,
    'evidence': 'measured_practice',
  };

  factory V1PracticeRecord.fromJson(Map<String, dynamic> json) {
    if (json['evidence'] != 'measured_practice') {
      throw const FormatException('Unknown practice evidence');
    }
    DateTime? date(String key) =>
        json[key] == null ? null : DateTime.parse(json[key] as String);
    double? number(String key) => (json[key] as num?)?.toDouble();
    final passedAt = date('passedAt');
    // Files written before the §6.3 fix have no completion keys; back then
    // the gate was measured at the target tempo only, so a pass was also a
    // completion.
    final legacy = !json.containsKey('completedAt');
    return V1PracticeRecord(
      lessonId: json['lessonId'] as String,
      runs: json['runs'] as int,
      bestAccuracy: number('bestAccuracy'),
      bestHeard: number('bestHeard'),
      bestBpm: json['bestBpm'] as int?,
      lastRunAt: date('lastRunAt'),
      passedAt: passedAt,
      passedBpm: json['passedBpm'] as int?,
      completedAt: legacy ? passedAt : date('completedAt'),
      completedBpm: legacy
          ? json['passedBpm'] as int?
          : json['completedBpm'] as int?,
    );
  }

  /// Folds one finished run in. A pass is kept once reached.
  V1PracticeRecord withRun(PracticeRunSummary s, DateTime at) {
    double? best(double? old, double? next) => next == null
        ? old
        : old == null || next > old
        ? next
        : old;
    final passes = s.gate.passed && passedAt == null;
    final completes = s.gate.completed && completedAt == null;
    return V1PracticeRecord(
      lessonId: lessonId,
      runs: runs + 1,
      bestAccuracy: best(bestAccuracy, s.accuracy),
      bestHeard: best(bestHeard, s.total == 0 ? null : s.heard),
      bestBpm: s.gate.passed && (bestBpm == null || s.bpm > bestBpm!)
          ? s.bpm
          : bestBpm,
      lastRunAt: at.toUtc(),
      passedAt: passes ? at.toUtc() : passedAt,
      passedBpm: passes ? s.bpm : passedBpm,
      completedAt: completes ? at.toUtc() : completedAt,
      completedBpm: completes ? s.bpm : completedBpm,
    );
  }
}

abstract interface class V1PracticeProgress {
  Future<Map<String, V1PracticeRecord>> load();
  Future<V1PracticeRecord> recordRun(
    String lessonId,
    PracticeRunSummary summary, {
    DateTime? at,
  });
}

final class V1PracticeProgressStore implements V1PracticeProgress {
  V1PracticeProgressStore({this.directoryProvider, this.accountUserId})
    : _operations = AccountDataOperations(() async {
        final root =
            await (directoryProvider ?? getApplicationSupportDirectory)();
        return accountDataDirectory(root, accountUserId);
      });

  final Future<Directory> Function()? directoryProvider;
  final String? accountUserId;
  final AccountDataOperations _operations;

  Future<T> _run<T>(
    Future<T> Function(File file) operation, {
    bool writing = false,
  }) => _operations.run(
    (directory) =>
        operation(File('${directory.path}/v1_practice_progress.v1.json')),
    writing: writing,
  );

  @override
  Future<Map<String, V1PracticeRecord>> load() => _run(_load);

  Future<Map<String, V1PracticeRecord>> _load(File file) async {
    if (!await file.exists()) return {};
    final decoded =
        jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    if (decoded['schemaVersion'] != 1) {
      throw const FormatException('Unsupported practice progress schema');
    }
    final result = <String, V1PracticeRecord>{};
    for (final item in decoded['records'] as List<dynamic>) {
      final r = V1PracticeRecord.fromJson(item as Map<String, dynamic>);
      if (result.containsKey(r.lessonId) || r.runs < 0) {
        throw const FormatException('Duplicate or invalid practice record');
      }
      result[r.lessonId] = r;
    }
    return result;
  }

  @override
  Future<V1PracticeRecord> recordRun(
    String lessonId,
    PracticeRunSummary summary, {
    DateTime? at,
  }) => _run((file) async {
    if (lessonId.isEmpty || lessonId.contains('|')) {
      throw ArgumentError('Invalid lesson id');
    }
    final records = await _load(file);
    final next = (records[lessonId] ?? V1PracticeRecord(lessonId: lessonId))
        .withRun(summary, at ?? DateTime.now());
    records[lessonId] = next;
    await _writeRecords(file, records.values.map((r) => r.toJson()));
    return next;
  }, writing: true);
}

/// Atomic write of `{schemaVersion: 1, records: [...]}` (temp + rename).
Future<void> _writeRecords(
  File file,
  Iterable<Map<String, Object?>> records,
) async {
  await file.parent.create(recursive: true);
  final temp = File('${file.path}.tmp');
  await temp.writeAsString(
    '${jsonEncode({'schemaVersion': 1, 'records': records.toList()})}\n',
    flush: true,
  );
  await temp.rename(file.path);
}

/// What a non-loop lesson completion rests on. Kept apart from
/// `measured_practice` on purpose: a self-report never reads as measured.
enum V1CheckEvidence {
  /// The learner ticked the lesson's self-check (contract §3 Ö: "kendi
  /// beyanı"). Not measured.
  selfReport('self_report'),

  /// The tuner measured every string in tune (A1 tuning lessons).
  tunerCheck('tuner_check');

  const V1CheckEvidence(this.json);
  final String json;

  static V1CheckEvidence parse(Object? value) => values.firstWhere(
    (e) => e.json == value,
    orElse: () => throw const FormatException('Unknown check evidence'),
  );
}

/// One completed v1 lesson outside the practice loop: self-check lessons,
/// held checkpoints practised as a self-check, tuner lessons. No audio, no
/// ticked items, no network — only which lesson, on what evidence, when.
final class V1LessonCheck {
  const V1LessonCheck({
    required this.lessonId,
    required this.evidence,
    required this.at,
  });

  final String lessonId;
  final V1CheckEvidence evidence;
  final DateTime at;

  bool get measured => evidence == V1CheckEvidence.tunerCheck;

  Map<String, Object?> toJson() => {
    'lessonId': lessonId,
    'evidence': evidence.json,
    'at': at.toUtc().toIso8601String(),
  };

  factory V1LessonCheck.fromJson(Map<String, dynamic> json) => V1LessonCheck(
    lessonId: json['lessonId'] as String,
    evidence: V1CheckEvidence.parse(json['evidence']),
    at: DateTime.parse(json['at'] as String),
  );
}

abstract interface class V1LessonChecks {
  Future<Map<String, V1LessonCheck>> load();

  /// Records a completion. The first record of a lesson is kept, except that
  /// a measured tuner check replaces a self-report.
  Future<V1LessonCheck> record(
    String lessonId,
    V1CheckEvidence evidence, {
    DateTime? at,
  });
}

/// Sibling of [V1PracticeProgressStore] in the same account directory:
/// `v1_lesson_checks.v1.json`.
final class V1LessonCheckStore implements V1LessonChecks {
  V1LessonCheckStore({this.directoryProvider, this.accountUserId})
    : _operations = AccountDataOperations(() async {
        final root =
            await (directoryProvider ?? getApplicationSupportDirectory)();
        return accountDataDirectory(root, accountUserId);
      });

  static const String fileName = 'v1_lesson_checks.v1.json';

  final Future<Directory> Function()? directoryProvider;
  final String? accountUserId;
  final AccountDataOperations _operations;

  Future<T> _run<T>(
    Future<T> Function(File file) operation, {
    bool writing = false,
  }) => _operations.run(
    (directory) => operation(File('${directory.path}/$fileName')),
    writing: writing,
  );

  @override
  Future<Map<String, V1LessonCheck>> load() => _run(_load);

  Future<Map<String, V1LessonCheck>> _load(File file) async {
    if (!await file.exists()) return {};
    final decoded =
        jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    if (decoded['schemaVersion'] != 1) {
      throw const FormatException('Unsupported lesson check schema');
    }
    final result = <String, V1LessonCheck>{};
    for (final item in decoded['records'] as List<dynamic>) {
      final c = V1LessonCheck.fromJson(item as Map<String, dynamic>);
      if (result.containsKey(c.lessonId)) {
        throw const FormatException('Duplicate lesson check');
      }
      result[c.lessonId] = c;
    }
    return result;
  }

  @override
  Future<V1LessonCheck> record(
    String lessonId,
    V1CheckEvidence evidence, {
    DateTime? at,
  }) => _run((file) async {
    if (lessonId.isEmpty || lessonId.contains('|')) {
      throw ArgumentError('Invalid lesson id');
    }
    final checks = await _load(file);
    final next = mergeLessonCheck(
      checks[lessonId],
      V1LessonCheck(
        lessonId: lessonId,
        evidence: evidence,
        at: (at ?? DateTime.now()).toUtc(),
      ),
    );
    if (identical(next, checks[lessonId])) return next;
    checks[lessonId] = next;
    await _writeRecords(file, checks.values.map((c) => c.toJson()));
    return next;
  }, writing: true);
}

/// The first completion is kept; a measured tuner check replaces a
/// self-report.
V1LessonCheck mergeLessonCheck(V1LessonCheck? old, V1LessonCheck next) =>
    old == null || (!old.measured && next.measured) ? next : old;

/// Unlock rule (task F2.5, contract §6.3): the first lesson in course order is
/// open; each next one opens when the one before it has a measured pass (at
/// its opening tempo, or at the target tempo for `M!` lessons).
Set<String> unlockedLessons(
  List<String> orderedIds,
  Map<String, V1PracticeRecord> records,
) {
  final open = <String>{};
  for (var i = 0; i < orderedIds.length; i++) {
    final id = orderedIds[i];
    if (i == 0 ||
        (records[orderedIds[i - 1]]?.passed ?? false) ||
        (records[id]?.passed ?? false)) {
      open.add(id);
    }
  }
  return open;
}
