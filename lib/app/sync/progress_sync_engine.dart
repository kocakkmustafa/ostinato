import '../guitar_journey_progress.dart' show GuitarProgressAction;
import 'lesson_progress_sync.dart';
import 'progress_sync_adapter.dart';

/// K16: per-account sync state. The offline queue is a set of dirty keys, not
/// an operation log: records are state-based CRDTs, so pushing the merged
/// state again after a failure is always safe.
final class ProgressSyncState {
  ProgressSyncState({
    Map<String, LessonProgressSyncRecord> records = const {},
    Set<String> dirty = const {},
    this.cursor,
  }) : records = Map.unmodifiable(records),
       dirty = Set.unmodifiable(dirty);

  final Map<String, LessonProgressSyncRecord> records;
  final Set<String> dirty;
  final String? cursor;
}

final class ProgressSyncOutcome {
  const ProgressSyncOutcome(this.state, {this.error});

  final ProgressSyncState state;

  /// Set when pull or push failed; [state] still holds everything merged so
  /// far and keeps unsent keys dirty.
  final Object? error;

  bool get succeeded => error == null;
}

/// Server-independent sync loop for one account and one replica. Not wired
/// into the app: `ostinatoProgressSyncAvailable` is false and the local store
/// stays the only source the screens read.
final class ProgressSyncEngine {
  ProgressSyncEngine({
    required this.adapter,
    required this.accountUserId,
    required this.replicaId,
  }) {
    if (!isCanonicalReplicaId(accountUserId.toLowerCase())) {
      throw ArgumentError.value(
        accountUserId,
        'accountUserId',
        'Expected UUID',
      );
    }
    if (!isCanonicalReplicaId(replicaId)) {
      throw ArgumentError.value(replicaId, 'replicaId', 'Expected UUID');
    }
  }

  final ProgressSyncAdapter adapter;
  final String accountUserId;
  final String replicaId;

  /// Applies a local action and marks its key dirty. Pure: no I/O.
  ProgressSyncState recordLocal(
    ProgressSyncState state, {
    required String contentVersion,
    required String lessonId,
    required GuitarProgressAction action,
    required DateTime at,
  }) {
    final base = LessonProgressSyncRecord(
      contentVersion: contentVersion,
      lessonId: lessonId,
    );
    final current = state.records[base.key] ?? base;
    final next = current.apply(action, replicaId: replicaId, at: at);
    return ProgressSyncState(
      records: {...state.records, base.key: next},
      dirty: {...state.dirty, base.key},
      cursor: state.cursor,
    );
  }

  /// One round: pull since cursor, merge, push merged dirty records. Never
  /// throws for remote failures; local records are never lost.
  Future<ProgressSyncOutcome> syncOnce(ProgressSyncState state) async {
    final ProgressPull pulled;
    try {
      pulled = await adapter.pull(accountUserId, since: state.cursor);
    } on Object catch (error) {
      return ProgressSyncOutcome(state, error: error);
    }
    final merged = mergeProgressSets(state.records, {
      for (final record in pulled.records) record.key: record,
    });
    final afterPull = ProgressSyncState(
      records: merged,
      dirty: state.dirty,
      cursor: pulled.cursor ?? state.cursor,
    );
    if (afterPull.dirty.isEmpty) return ProgressSyncOutcome(afterPull);
    final keys = afterPull.dirty.toList()..sort();
    try {
      await adapter.push(accountUserId, [
        for (final key in keys) afterPull.records[key]!,
      ]);
    } on Object catch (error) {
      return ProgressSyncOutcome(afterPull, error: error);
    }
    return ProgressSyncOutcome(
      ProgressSyncState(records: merged, cursor: afterPull.cursor),
    );
  }
}
