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
  });

  final String lessonId;
  final int runs;
  final double? bestAccuracy, bestHeard;
  final int? bestBpm;
  final DateTime? lastRunAt;

  /// First measured pass of the gate; opens the next lesson.
  final DateTime? passedAt;
  final int? passedBpm;

  bool get passed => passedAt != null;

  Map<String, Object?> toJson() => {
    'lessonId': lessonId,
    'runs': runs,
    'bestAccuracy': bestAccuracy,
    'bestHeard': bestHeard,
    'bestBpm': bestBpm,
    'lastRunAt': lastRunAt?.toUtc().toIso8601String(),
    'passedAt': passedAt?.toUtc().toIso8601String(),
    'passedBpm': passedBpm,
    'evidence': 'measured_practice',
  };

  factory V1PracticeRecord.fromJson(Map<String, dynamic> json) {
    if (json['evidence'] != 'measured_practice') {
      throw const FormatException('Unknown practice evidence');
    }
    DateTime? date(String key) =>
        json[key] == null ? null : DateTime.parse(json[key] as String);
    double? number(String key) => (json[key] as num?)?.toDouble();
    return V1PracticeRecord(
      lessonId: json['lessonId'] as String,
      runs: json['runs'] as int,
      bestAccuracy: number('bestAccuracy'),
      bestHeard: number('bestHeard'),
      bestBpm: json['bestBpm'] as int?,
      lastRunAt: date('lastRunAt'),
      passedAt: date('passedAt'),
      passedBpm: json['passedBpm'] as int?,
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
    await file.parent.create(recursive: true);
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(
      '${jsonEncode({'schemaVersion': 1, 'records': records.values.map((r) => r.toJson()).toList()})}\n',
      flush: true,
    );
    await temp.rename(file.path);
    return next;
  }, writing: true);
}

/// Unlock rule (task F2.5): the first lesson in course order is open; each
/// next one opens when the one before it has a measured pass.
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
