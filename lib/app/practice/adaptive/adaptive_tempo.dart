import 'dart:math' as math;

import '../loop/practice_outcome.dart';
import '../loop/practice_tempo_ladder.dart';

/// Why [adaptTempo] chose its tempo (OST-P1-02).
enum AdaptiveTempoReason {
  /// Two steady measured runs in a row at this tempo: one ladder step up.
  raise,

  /// Keep this tempo (not steady twice yet, at the target, or at the floor).
  keep,

  /// Two unsteady measured runs in a row at this tempo: one ladder step down.
  slowDown,

  /// The run was not a full measured run: the tempo is left as it was.
  notMeasured,
}

/// The tempo suggested for the next run and the reason for it.
final class AdaptiveTempoDecision {
  const AdaptiveTempoDecision({required this.nextBpm, required this.reason});
  final int nextBpm;
  final AdaptiveTempoReason reason;

  @override
  bool operator ==(Object other) =>
      other is AdaptiveTempoDecision &&
      other.nextBpm == nextBpm &&
      other.reason == reason;

  @override
  int get hashCode => Object.hash(nextBpm, reason);
}

/// OST-P1-02 — adaptive accompaniment, tempo only (pure Dart, no I/O).
/// Only the tempo adapts; pitch, rhythm and content never change.
///
/// WARNING (reconcile before wiring): this shares only the definition of a
/// steady run ([TempoLadder.cleared]) and the step size (5 bpm) with the
/// tempo ladder. [TempoLadder] raises after ONE steady run and never lowers;
/// [adaptTempo] needs TWO steady runs in a row to raise and does lower. The
/// two must be reconciled before both are wired to the same screen.
///
/// - Not measured (`!gate.eligible`): the tempo does not change, even when
///   it is above the target (`nextBpm == last.bpm`, no clamping).
/// - `openBpm > targetBpm` (invalid range): `keep` at `last.bpm`; no throw.
/// - Hysteresis: only measured runs count (unmeasured ones are skipped) and
///   only the most recent earlier measured run, at the same tempo as [last].
///   Two steady in a row raise one step (never above the target); two
///   unsteady in a row lower one step (never below the opening tempo);
///   anything else keeps.
///
/// [history]: earlier runs ordered OLDEST FIRST (newest last), not including
/// [last]. [step] must be > 0, otherwise an [ArgumentError] is thrown (also
/// in release builds); a step larger than the range is cut at the bounds.
AdaptiveTempoDecision adaptTempo(
  PracticeRunSummary last, {
  List<PracticeRunSummary> history = const [],
  int step = 5,
}) {
  if (step <= 0) throw ArgumentError.value(step, 'step', 'must be > 0');
  if (!last.gate.eligible) {
    return AdaptiveTempoDecision(
      nextBpm: last.bpm,
      reason: AdaptiveTempoReason.notMeasured,
    );
  }
  if (last.openBpm > last.targetBpm) {
    return AdaptiveTempoDecision(
      nextBpm: last.bpm,
      reason: AdaptiveTempoReason.keep,
    );
  }
  final open = last.openBpm, target = last.targetBpm;
  final base = last.bpm.clamp(open, target);
  AdaptiveTempoDecision keep() =>
      AdaptiveTempoDecision(nextBpm: base, reason: AdaptiveTempoReason.keep);

  final steady = TempoLadder.cleared(last);
  // Previous measured run at this very tempo (skipping unmeasured ones).
  PracticeRunSummary? previous;
  for (final s in history.reversed) {
    if (!s.gate.eligible) continue;
    if (s.bpm == last.bpm) previous = s;
    break;
  }
  if (previous == null) return keep();
  final previousSteady = TempoLadder.cleared(previous);

  if (steady && previousSteady && base < target) {
    return AdaptiveTempoDecision(
      nextBpm: math.min(base + step, target),
      reason: AdaptiveTempoReason.raise,
    );
  }
  if (!steady && !previousSteady && base > open) {
    return AdaptiveTempoDecision(
      nextBpm: math.max(base - step, open),
      reason: AdaptiveTempoReason.slowDown,
    );
  }
  return keep();
}
