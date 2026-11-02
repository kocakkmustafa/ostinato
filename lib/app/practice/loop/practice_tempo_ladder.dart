import 'dart:math' as math;

import 'practice_outcome.dart';
import 'practice_transport.dart';

/// What the tempo ladder decided after one run (FK6).
sealed class TempoLadderOutcome {
  const TempoLadderOutcome();
}

/// The run cleared the checks below the target: the next run is faster.
final class TempoLadderStepped extends TempoLadderOutcome {
  const TempoLadderStepped({required this.fromBpm, required this.nextBpm});
  final int fromBpm, nextBpm;
}

/// The run did not clear the checks (or was not a full measured run): the
/// next run keeps this tempo.
final class TempoLadderHeld extends TempoLadderOutcome {
  const TempoLadderHeld(this.bpm);
  final int bpm;
}

/// The run was at the target tempo (or above): the ladder is done and this
/// run is the one the gate measures for "completed" (contract §6.3).
final class TempoLadderAtTarget extends TempoLadderOutcome {
  const TempoLadderAtTarget(this.targetBpm);
  final int targetBpm;
}

/// FK6 tempo ladder (speed trainer), contract §6.3: "açılıştan hedefe +5 bpm
/// adımlar; her adımda varsayılan ölçüt". Pure Dart; one per lesson session.
///
/// A run "clears" a step when it is a full measured run (no loop, no "Wait
/// for me", not stopped early) and every check of [PassCriteria] except the
/// tempo one is met: the default criterion at that step. The tempo check is
/// left out on purpose — it decides what the run opens or completes, which
/// the ladder never changes. Below the target a run stays practice for
/// completion; only a run at the target tempo can complete the lesson.
final class TempoLadder {
  TempoLadder({required this.available, bool? enabled, this.step = 5})
    : enabled = available && (enabled ?? true);

  /// A ladder for this lesson's tempo: none for free tempo (no click) and
  /// none when the opening tempo already is the target.
  factory TempoLadder.forLesson({
    required bool freeTempo,
    required PracticeTempo tempo,
  }) => TempoLadder(available: !freeTempo && tempo.openBpm < tempo.targetBpm);

  final bool available;
  final int step;

  /// Learner switch on the practice screen (default on when [available]).
  bool enabled;

  /// The run cleared the default criterion at its own tempo.
  static bool cleared(PracticeRunSummary s) =>
      s.gate.eligible &&
      s.gate.checks
          .where((c) => c.kind != GateCheckKind.tempo)
          .every((c) => c.ok);

  /// The ladder's decision after [s]; null when the ladder is off or absent
  /// (the tempo is then left exactly as the learner set it).
  TempoLadderOutcome? afterRun(PracticeRunSummary s) {
    if (!available || !enabled) return null;
    if (s.bpm >= s.targetBpm) return TempoLadderAtTarget(s.targetBpm);
    if (!cleared(s)) return TempoLadderHeld(s.bpm);
    return TempoLadderStepped(
      fromBpm: s.bpm,
      nextBpm: math.min(s.bpm + step, s.targetBpm),
    );
  }

  /// The tempo for the next run: the stepped tempo, otherwise [current].
  static PracticeTempo apply(
    TempoLadderOutcome? outcome,
    PracticeTempo current,
  ) => switch (outcome) {
    TempoLadderStepped(:final nextBpm) => current.withBpm(nextBpm),
    _ => current,
  };
}
