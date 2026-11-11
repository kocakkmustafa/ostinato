import '../practice/loop/practice_progress_store.dart';

/// OST-UX-05c: what the last measured run mostly missed. Derived from fields
/// that already exist (V1PracticeRecord); nothing new is
/// stored. [none] = nothing to say (or nothing derivable).
enum StageMissKind { none, unheard, different, timing }

/// Records under these thresholds read as a miss (gate default is .8).
const double stageMissMinHeard = 0.8;
const double stageMissMinAccuracy = 0.8;

/// From the record of the lesson played last: not heard enough -> [unheard],
/// heard but not matching -> [different]; a passed lesson, no run or no
/// numbers -> [none]. A record carries no timing, so never [timing]. This is
/// the ONE rule: a fresh open and a run inside the session both read the
/// stored record through it (05d ek B).
StageMissKind missFromRecord(V1PracticeRecord? r) {
  if (r == null || r.runs <= 0 || r.passed) return StageMissKind.none;
  final heard = r.bestHeard;
  if (heard != null && heard < stageMissMinHeard) return StageMissKind.unheard;
  final accuracy = r.bestAccuracy;
  if (accuracy != null && accuracy < stageMissMinAccuracy) {
    return StageMissKind.different;
  }
  return StageMissKind.none;
}

/// The record of the lesson run most recently (null = no run yet).
V1PracticeRecord? lastRunRecord(Iterable<V1PracticeRecord> records) {
  V1PracticeRecord? last;
  for (final r in records) {
    if (r.runs <= 0) continue;
    if (last == null || _newer(r, last)) last = r;
  }
  return last;
}

/// A dated run beats an undated one; the later date wins; equal dates go to
/// the larger lesson id, so the result never depends on iteration order.
bool _newer(V1PracticeRecord a, V1PracticeRecord b) {
  final x = a.lastRunAt, y = b.lastRunAt;
  if (x == null || y == null) {
    if (x == null && y == null) return a.lessonId.compareTo(b.lessonId) > 0;
    return x != null;
  }
  final c = x.compareTo(y);
  return c != 0 ? c > 0 : a.lessonId.compareTo(b.lessonId) > 0;
}

enum StageSuggestionKind { pickUp, moveCloser, listenFirst, slowDown }

/// One suggestion line: the same input always gives the same value.
final class StageSuggestion {
  const StageSuggestion(this.kind, this.lessonId);
  final StageSuggestionKind kind;

  /// The lesson the stage continues with (`V1CourseState.next`).
  final String lessonId;

  @override
  bool operator ==(Object other) =>
      other is StageSuggestion &&
      other.kind == kind &&
      other.lessonId == lessonId;

  @override
  int get hashCode => Object.hash(kind, lessonId);
}

/// Pure and deterministic. No records, or no next lesson -> null (the line is
/// hidden).
StageSuggestion? stageSuggestion({
  required bool hasRecords,
  required String? nextLessonId,
  required StageMissKind miss,
}) {
  if (!hasRecords || nextLessonId == null) return null;
  return StageSuggestion(switch (miss) {
    StageMissKind.none => StageSuggestionKind.pickUp,
    StageMissKind.unheard => StageSuggestionKind.moveCloser,
    StageMissKind.different => StageSuggestionKind.listenFirst,
    StageMissKind.timing => StageSuggestionKind.slowDown,
  }, nextLessonId);
}
