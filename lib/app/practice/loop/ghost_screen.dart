import 'listen_try_fix.dart';

/// OST-P0-07 "Ghost screen" (pure Dart, deterministic, in memory only):
/// as measured, repeated success builds up, the guides that are drawn on the
/// practice screen fade out one level at a time, down to a run without any.
/// The player can bring them back at any moment.
///
/// What it never does:
///  - It never moves on from an unreliable measurement ("I could not tell
///    this sound apart with confidence"): the level stays, no streak changes,
///    and no completion is claimed.
///  - It never claims a skill was gained. It only decides which guides are
///    drawn; the lesson pass, the progress store and the course order are
///    untouched. Nothing is stored beyond the screen's own session.
///  - It never invents a score: success is the existing `FixClear` of
///    `ListenTryFix` (heard well enough AND the lesson's own accuracy check
///    met); `FixCorrection` / `FixNoClearDifference` are "measured, not
///    clear yet".
///  - It never blocks: at [GhostStage.learn] every guide is shown, a step
///    back is one call, and `showAll` is always available.

/// A guide the practice screen draws today (read from the code, nothing else):
/// the written line / tab strip, the "Listen first" reference playback, and
/// the visual beat. The metronome CLICK is sound, not a drawn guide, and is
/// not touched; start/stop/back/exit are controls, never guides.
enum Guide { notation, referenceAudio, beatVisual }

/// Learning → consolidating → recalling → independent performance
/// (UI brief §5.2 D).
enum GhostStage { learn, reinforce, recall, independent }

/// What one finished run says for the ghost level.
enum GhostAttempt {
  /// Heard well enough and the accuracy check is met (`FixClear`).
  clear,

  /// Heard well enough, but a difference was measured (or none stood out and
  /// the accuracy check was not met).
  notClear,

  /// The measurement was not reliable: nothing is concluded.
  unmeasured,
}

/// What a guide-free run reported (only set for a run at
/// [GhostStage.independent] with no override).
enum GhostCompletion { measuredClear, measuredNotClear, unmeasured }

/// Named, documented criteria. Success itself is `FixClear`, which reuses the
/// lesson's own accuracy bar (`PassGate.criteria.minAccuracy`) and
/// `FixThresholds` — no new score exists.
abstract final class GhostThresholds {
  /// Consecutive clear runs at a level before the next guide is hidden.
  static const int clearRunsToAdvance = 2;

  /// Consecutive measured-but-not-clear runs before one level of guides
  /// comes back on its own. Unmeasured runs count for neither.
  static const int notClearRunsToStepBack = 3;
}

final class GhostState {
  const GhostState({
    this.stage = GhostStage.learn,
    this.clearStreak = 0,
    this.notClearStreak = 0,
    this.showAll = false,
    this.independentClearRuns = 0,
    this.completion,
  });

  final GhostStage stage;
  final int clearStreak;
  final int notClearStreak;

  /// The player's override: every guide is shown, whatever the level.
  final bool showAll;

  /// Guide-free runs this session that were measured and clear. Session
  /// memory only; never persisted, never a "mastered" flag.
  final int independentClearRuns;

  /// What the last guide-free run reported; null when the last run was not
  /// one.
  final GhostCompletion? completion;

  GhostState copyWith({
    GhostStage? stage,
    int? clearStreak,
    int? notClearStreak,
    bool? showAll,
    int? independentClearRuns,
    GhostCompletion? completion,
    bool clearCompletion = false,
  }) => GhostState(
    stage: stage ?? this.stage,
    clearStreak: clearStreak ?? this.clearStreak,
    notClearStreak: notClearStreak ?? this.notClearStreak,
    showAll: showAll ?? this.showAll,
    independentClearRuns: independentClearRuns ?? this.independentClearRuns,
    completion: clearCompletion ? null : (completion ?? this.completion),
  );
}

abstract final class GhostScreenPolicy {
  /// The guides drawn at a level.
  static Set<Guide> guidesFor(GhostStage stage) => switch (stage) {
    GhostStage.learn => const {
      Guide.notation,
      Guide.referenceAudio,
      Guide.beatVisual,
    },
    GhostStage.reinforce => const {Guide.notation, Guide.beatVisual},
    GhostStage.recall => const {Guide.beatVisual},
    GhostStage.independent => const {},
  };

  /// The guides shown now: the override wins.
  static Set<Guide> visible(GhostState s) =>
      s.showAll ? Set.of(Guide.values) : guidesFor(s.stage);

  /// A finished run → one of the three attempts. Anything not clearly
  /// measured is [GhostAttempt.unmeasured] or not-clear, never clear.
  static GhostAttempt classify(ListenTryFixResult fix) => switch (fix) {
    FixClear() => GhostAttempt.clear,
    FixCorrection() || FixNoClearDifference() => GhostAttempt.notClear,
    FixUnmeasured() => GhostAttempt.unmeasured,
  };

  static GhostStage? _next(GhostStage s) =>
      s == GhostStage.independent ? null : GhostStage.values[s.index + 1];
  static GhostStage? _previous(GhostStage s) =>
      s == GhostStage.learn ? null : GhostStage.values[s.index - 1];

  /// The state after one finished run.
  static GhostState afterAttempt(GhostState s, GhostAttempt attempt) {
    // With the override on, the guides WERE visible: the run says nothing
    // about doing it without them. No step forward, no penalty.
    if (s.showAll) return s.copyWith(clearCompletion: true);
    final independent = s.stage == GhostStage.independent;
    switch (attempt) {
      case GhostAttempt.unmeasured:
        // Never a step, never a streak change, never a claim.
        return s.copyWith(
          completion: independent ? GhostCompletion.unmeasured : null,
          clearCompletion: !independent,
        );
      case GhostAttempt.clear:
        if (independent) {
          return s.copyWith(
            clearStreak: s.clearStreak + 1,
            notClearStreak: 0,
            independentClearRuns: s.independentClearRuns + 1,
            completion: GhostCompletion.measuredClear,
          );
        }
        final streak = s.clearStreak + 1;
        if (streak >= GhostThresholds.clearRunsToAdvance) {
          return s.copyWith(
            stage: _next(s.stage),
            clearStreak: 0,
            notClearStreak: 0,
            clearCompletion: true,
          );
        }
        return s.copyWith(
          clearStreak: streak,
          notClearStreak: 0,
          clearCompletion: true,
        );
      case GhostAttempt.notClear:
        final streak = s.notClearStreak + 1;
        final back = _previous(s.stage);
        if (back != null && streak >= GhostThresholds.notClearRunsToStepBack) {
          return s.copyWith(
            stage: back,
            clearStreak: 0,
            notClearStreak: 0,
            clearCompletion: true,
          );
        }
        return s.copyWith(
          clearStreak: 0,
          notClearStreak: streak,
          completion: independent ? GhostCompletion.measuredNotClear : null,
          clearCompletion: !independent,
        );
    }
  }

  /// "Back to more guides": one level back, any time, no penalty.
  static GhostState stepBack(GhostState s) {
    final back = _previous(s.stage);
    if (back == null) return s;
    return s.copyWith(
      stage: back,
      clearStreak: 0,
      notClearStreak: 0,
      clearCompletion: true,
    );
  }

  /// "Show guides" / "Hide guides again": the player's override.
  static GhostState setShowAll(GhostState s, bool on) =>
      s.showAll == on ? s : s.copyWith(showAll: on, clearCompletion: true);
}
