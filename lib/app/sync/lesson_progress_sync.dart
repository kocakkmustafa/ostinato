import '../guitar_journey_progress.dart' show GuitarProgressAction;

/// K16 (2026-11-01): one lesson's progress as a state-based CRDT.
///
/// Merge is commutative, associative and idempotent, so order, repetition and
/// delay of sync rounds cannot change the result. The server proposal
/// (`supabase/proposals/K16_ostinato_lesson_progress.sql`) applies the same
/// rule. Only user progress is carried: no audio, video, raw measurement or
/// session summary. Design: `docs/sync/K16-ilerleme-senkronu.md`.
final class LessonProgressSyncRecord {
  LessonProgressSyncRecord({
    required this.contentVersion,
    required this.lessonId,
    DateTime? seenAt,
    DateTime? practicedAt,
    DateTime? completedAt,
    Map<String, int> practiceCounts = const <String, int>{},
  }) : seenAt = seenAt?.toUtc(),
       practicedAt = practicedAt?.toUtc(),
       completedAt = completedAt?.toUtc(),
       practiceCounts = Map<String, int>.unmodifiable(practiceCounts) {
    if (!isValidProgressIdentityPart(contentVersion) ||
        !isValidProgressIdentityPart(lessonId)) {
      throw ArgumentError('Invalid course progress identity');
    }
    if (practiceCounts.length > maxReplicas) {
      throw ArgumentError('Too many progress replicas');
    }
    for (final entry in practiceCounts.entries) {
      if (!isCanonicalReplicaId(entry.key) ||
          entry.value < 0 ||
          entry.value > maxPracticeCount) {
        throw ArgumentError('Invalid practice counter');
      }
    }
    if (completedAt != null && practiceCount == 0) {
      throw ArgumentError(
        'A practice entry is required before self-reporting completion',
      );
    }
  }

  /// Same limits as the server proposal's CHECK constraints.
  static const int maxReplicas = 16;
  static const int maxPracticeCount = 100000;

  final String contentVersion;
  final String lessonId;

  /// First seen: earliest wins.
  final DateTime? seenAt;

  /// Last practiced: latest wins.
  final DateTime? practicedAt;

  /// Self-reported completion: earliest wins and never clears (monotone).
  final DateTime? completedAt;

  /// G-Counter: replica ID -> practices recorded on that replica.
  final Map<String, int> practiceCounts;

  /// Same key as the local store (`contentVersion|lessonId`).
  String get key => '$contentVersion|$lessonId';

  int get practiceCount =>
      practiceCounts.values.fold<int>(0, (sum, value) => sum + value);

  bool get isCompleted => completedAt != null;

  LessonProgressSyncRecord merge(LessonProgressSyncRecord other) {
    if (other.key != key) {
      throw ArgumentError('Cannot merge progress of different lessons');
    }
    final counts = <String, int>{...practiceCounts};
    other.practiceCounts.forEach((replica, value) {
      final current = counts[replica];
      if (current == null || value > current) counts[replica] = value;
    });
    return LessonProgressSyncRecord(
      contentVersion: contentVersion,
      lessonId: lessonId,
      seenAt: _earliest(seenAt, other.seenAt),
      practicedAt: _latest(practicedAt, other.practicedAt),
      completedAt: _earliest(completedAt, other.completedAt),
      practiceCounts: counts,
    );
  }

  /// One local user action on [replicaId], mirroring
  /// `GuitarJourneyProgressStore.record` (same completion precondition).
  LessonProgressSyncRecord apply(
    GuitarProgressAction action, {
    required String replicaId,
    required DateTime at,
  }) {
    if (!isCanonicalReplicaId(replicaId)) {
      throw ArgumentError.value(replicaId, 'replicaId', 'Expected UUID');
    }
    final now = at.toUtc();
    if (action == GuitarProgressAction.selfReportedCompleted &&
        practiceCount == 0) {
      throw StateError(
        'A practice entry is required before self-reporting completion',
      );
    }
    final counts = <String, int>{...practiceCounts};
    if (action == GuitarProgressAction.practiced) {
      counts[replicaId] = (counts[replicaId] ?? 0) + 1;
    }
    return LessonProgressSyncRecord(
      contentVersion: contentVersion,
      lessonId: lessonId,
      seenAt: _earliest(seenAt, now),
      practicedAt: action == GuitarProgressAction.practiced
          ? _latest(practicedAt, now)
          : practicedAt,
      completedAt: action == GuitarProgressAction.selfReportedCompleted
          ? _earliest(completedAt, now)
          : completedAt,
      practiceCounts: counts,
    );
  }

  /// Wire shape of the server proposal's RPC (`snake_case`).
  Map<String, Object?> toJson() => <String, Object?>{
    'content_version': contentVersion,
    'lesson_id': lessonId,
    'seen_at': seenAt?.toIso8601String(),
    'practiced_at': practicedAt?.toIso8601String(),
    'completed_at': completedAt?.toIso8601String(),
    'practice_counts': practiceCounts,
  };

  factory LessonProgressSyncRecord.fromJson(Map<String, dynamic> json) {
    DateTime? date(String key) =>
        json[key] == null ? null : DateTime.parse(json[key] as String);
    final counts = json['practice_counts'] as Map<String, dynamic>? ?? {};
    return LessonProgressSyncRecord(
      contentVersion: json['content_version'] as String,
      lessonId: json['lesson_id'] as String,
      seenAt: date('seen_at'),
      practicedAt: date('practiced_at'),
      completedAt: date('completed_at'),
      practiceCounts: counts.map((k, v) => MapEntry(k, v as int)),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is LessonProgressSyncRecord &&
      other.contentVersion == contentVersion &&
      other.lessonId == lessonId &&
      other.seenAt == seenAt &&
      other.practicedAt == practicedAt &&
      other.completedAt == completedAt &&
      _sameCounts(other.practiceCounts, practiceCounts);

  @override
  int get hashCode => Object.hash(
    contentVersion,
    lessonId,
    seenAt,
    practicedAt,
    completedAt,
    Object.hashAllUnordered(
      practiceCounts.entries.map((e) => Object.hash(e.key, e.value)),
    ),
  );

  @override
  String toString() => 'LessonProgressSyncRecord(${toJson()})';
}

/// Merges two keyed record sets; keys present on one side are kept as is.
Map<String, LessonProgressSyncRecord> mergeProgressSets(
  Map<String, LessonProgressSyncRecord> a,
  Map<String, LessonProgressSyncRecord> b,
) {
  final result = <String, LessonProgressSyncRecord>{...a};
  b.forEach((key, record) {
    final existing = result[key];
    result[key] = existing == null ? record : existing.merge(record);
  });
  return result;
}

bool isValidProgressIdentityPart(String value) =>
    value.isNotEmpty && value.length <= 128 && !value.contains('|');

final RegExp _canonicalUuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
);

/// Replica IDs are random per (install, account) UUIDs, lower case. They are
/// not hardware or advertising identifiers.
bool isCanonicalReplicaId(String value) => _canonicalUuid.hasMatch(value);

DateTime? _earliest(DateTime? a, DateTime? b) {
  if (a == null) return b;
  if (b == null) return a;
  return b.isBefore(a) ? b : a;
}

DateTime? _latest(DateTime? a, DateTime? b) {
  if (a == null) return b;
  if (b == null) return a;
  return b.isAfter(a) ? b : a;
}

bool _sameCounts(Map<String, int> a, Map<String, int> b) {
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (b[entry.key] != entry.value) return false;
  }
  return true;
}
