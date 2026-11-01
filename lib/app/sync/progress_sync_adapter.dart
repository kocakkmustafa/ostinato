import 'lesson_progress_sync.dart';

/// K16: server-independent seam for progress sync. The real Supabase adapter
/// is a later PR (founder approval for schema and deploy); this interface
/// carries only progress records, keyed by the signed-in Motion account.
abstract interface class ProgressSyncAdapter {
  /// Records changed since [since] (null = everything) for [accountUserId].
  Future<ProgressPull> pull(String accountUserId, {String? since});

  /// Merges [records] into the remote copy. Must be idempotent: the remote
  /// side merges with the same rule as [LessonProgressSyncRecord.merge].
  Future<void> push(
    String accountUserId,
    List<LessonProgressSyncRecord> records,
  );
}

final class ProgressPull {
  const ProgressPull({required this.records, required this.cursor});

  final List<LessonProgressSyncRecord> records;

  /// Opaque position to pass as `since` next time.
  final String? cursor;
}

/// Thrown when the remote side cannot be reached; local data is untouched.
final class ProgressSyncUnavailable implements Exception {
  const ProgressSyncUnavailable([this.message = 'Progress sync unavailable']);

  final String message;

  @override
  String toString() => 'ProgressSyncUnavailable: $message';
}

/// Fake remote for tests and local development. No network: it keeps one
/// merged record set per account in memory and merges pushes like the server
/// proposal does.
final class InMemoryProgressSyncAdapter implements ProgressSyncAdapter {
  final Map<String, Map<String, LessonProgressSyncRecord>> _accounts = {};
  final Map<String, Map<String, int>> _revisions = {};
  int _revision = 0;

  /// When false every call throws [ProgressSyncUnavailable] (offline).
  bool online = true;

  int pushCalls = 0;
  int pullCalls = 0;

  /// Remote copy for assertions.
  Map<String, LessonProgressSyncRecord> remoteFor(String accountUserId) =>
      Map.unmodifiable(_accounts[accountUserId] ?? const {});

  @override
  Future<ProgressPull> pull(String accountUserId, {String? since}) async {
    pullCalls++;
    if (!online) throw const ProgressSyncUnavailable();
    final after = since == null ? 0 : int.parse(since);
    final records = _accounts[accountUserId] ?? const {};
    final revisions = _revisions[accountUserId] ?? const {};
    return ProgressPull(
      records: [
        for (final entry in records.entries)
          if ((revisions[entry.key] ?? 0) > after) entry.value,
      ],
      cursor: '$_revision',
    );
  }

  @override
  Future<void> push(
    String accountUserId,
    List<LessonProgressSyncRecord> records,
  ) async {
    pushCalls++;
    if (!online) throw const ProgressSyncUnavailable();
    final keys = records.map((r) => r.key).toSet();
    if (keys.length != records.length) {
      throw ArgumentError('Duplicate progress key in one push');
    }
    final account = _accounts.putIfAbsent(accountUserId, () => {});
    final revisions = _revisions.putIfAbsent(accountUserId, () => {});
    for (final record in records) {
      final existing = account[record.key];
      final merged = existing == null ? record : existing.merge(record);
      if (merged != existing) {
        account[record.key] = merged;
        revisions[record.key] = ++_revision;
      }
    }
  }
}
