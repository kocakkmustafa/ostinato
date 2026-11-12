import '../practice/loop/practice_outcome.dart';

// OST-UX-05g: pure policy of the stage's "Help" (Ghost) levels. Separate from
// the older P0-07 `ghost_screen.dart` (that one steps by itself; this never
// does). It only READS the run summary: the gate, the thresholds and
// `V1PracticeRecord` are untouched.

/// The four manual help levels (04-design Ek B, 5.6).
enum GhostLevel { learn, reinforce, recall, independent }

/// Things the help matrix shows or hides.
enum GhostItem { notation, tab, beat, label, preStartPreview, metronome, hint }

/// What the last finished run did to the counter.
enum GhostLastRun { none, counted, notCounted, notMeasured }

final class GhostState {
  const GhostState({
    this.level = GhostLevel.learn,
    this.validRuns = 0,
    this.lastRun = GhostLastRun.none,
  });

  final GhostLevel level;

  /// Valid runs counted at the current level (reset by a manual change).
  final int validRuns;
  final GhostLastRun lastRun;

  GhostState copyWith({
    GhostLevel? level,
    int? validRuns,
    GhostLastRun? lastRun,
  }) => GhostState(
    level: level ?? this.level,
    validRuns: validRuns ?? this.validRuns,
    lastRun: lastRun ?? this.lastRun,
  );
}

abstract final class GhostPolicy {
  /// Valid runs at the current level that make a one-step-up suggestion
  /// (1 -> 2: one, 2 -> 3: two, 3 -> 4: three; independent has none).
  static const Map<GhostLevel, int> runsToSuggest = <GhostLevel, int>{
    GhostLevel.learn: 1,
    GhostLevel.reinforce: 2,
    GhostLevel.recall: 3,
  };

  /// Share of notes that must be heard (the gate's own 80 %).
  static const double minHeard = .8;

  static final RegExp _earId = RegExp(r'^ear-s\d+-');

  static Set<GhostItem> itemsFor(GhostLevel level) => switch (level) {
    GhostLevel.learn => const <GhostItem>{
      GhostItem.notation,
      GhostItem.tab,
      GhostItem.beat,
      GhostItem.label,
    },
    GhostLevel.reinforce => const <GhostItem>{
      GhostItem.notation,
      GhostItem.tab,
      GhostItem.beat,
    },
    GhostLevel.recall => const <GhostItem>{
      GhostItem.preStartPreview,
      GhostItem.beat,
    },
    GhostLevel.independent => const <GhostItem>{
      GhostItem.metronome,
      GhostItem.hint,
    },
  };

  /// Ear and rhythm-only runs never touch the Ghost (marked decision).
  static bool _outOfScope(PracticeSessionFinished e, bool rhythmOnly) =>
      rhythmOnly || e.course == 'ear' || _earId.hasMatch(e.lessonId);

  /// Measured, complete, no loop, no wait, heard >= 80 %, gate passed.
  static bool isValidRun(
    PracticeSessionFinished e, {
    required bool rhythmOnly,
  }) {
    if (_outOfScope(e, rhythmOnly)) return false;
    final s = e.summary;
    return s.gate.eligible &&
        s.correct + s.different + s.unheard > 0 &&
        s.heard >= minHeard - 1e-9 &&
        s.gate.passed;
  }

  /// Counts the run. NEVER changes the level.
  static GhostState afterRun(
    GhostState s,
    PracticeSessionFinished e, {
    required bool rhythmOnly,
  }) {
    if (_outOfScope(e, rhythmOnly)) return s;
    if (isValidRun(e, rhythmOnly: rhythmOnly)) {
      return s.copyWith(
        validRuns: s.validRuns + 1,
        lastRun: GhostLastRun.counted,
      );
    }
    final sum = e.summary;
    final measured =
        sum.gate.eligible && sum.correct + sum.different + sum.unheard > 0;
    return s.copyWith(
      lastRun: measured ? GhostLastRun.notCounted : GhostLastRun.notMeasured,
    );
  }

  /// Manual choice only; a different level starts its own count.
  static GhostState select(GhostState s, GhostLevel level) =>
      level == s.level ? s : GhostState(level: level, lastRun: s.lastRun);

  /// The level that may be tried next, or null. Never applied by itself.
  static GhostLevel? suggestion(GhostState s) {
    final need = runsToSuggest[s.level];
    if (need == null || s.validRuns < need) return null;
    return GhostLevel.values[s.level.index + 1];
  }
}
