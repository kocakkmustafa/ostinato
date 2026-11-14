import 'dart:math' as math;

import '../../curriculum/v1_lesson.dart';
import 'practice_marks.dart';
import 'practice_outcome.dart';
import 'practice_transport.dart';
import 'v1_practice_catalog.dart';

/// OST-P0-06 — "listen → try → fix → repeat" on top of one measured run
/// (pure Dart, deterministic, nothing stored). It reads what the run already
/// measured (`NoteOutcome`: attack timing, pitch verdict, why a note could
/// not be heard) and returns ONE main correction, or "I could not measure
/// this", or "no clear difference". It never calls a run wrong: a low signal
/// is never turned into a verdict.
///
/// Not measured today, so never reported: an extra attack (the judge keeps no
/// unmatched onsets) and the direction of a pitch drift.
enum FixKind {
  /// Attacks clearly before the beat (rhythm line, timing below zero).
  early,

  /// Attacks clearly after the beat (rhythm line, timing above zero).
  late,

  /// No attack heard where a beat was expected (the signal was fine).
  missed,

  /// A pitch line note whose pitch was heard as a different one.
  pitchOff,
}

/// Why the run could not be turned into a correction.
enum CouldNotMeasure {
  /// Too few notes were heard to say anything (see [FixThresholds.minHeard]).
  weakSignal,

  /// Fewer than [FixThresholds.minDecided] notes were decided.
  tooFewNotes,
}

/// All thresholds in one place; `expertPending` like the gate's.
abstract final class FixThresholds {
  /// Heard share (decided / all notes) below which no verdict is given.
  static const double minHeard = .7;

  /// Decided notes (correct + different) needed to say anything.
  static const int minDecided = 3;

  /// Notes of one kind needed to name it.
  static const int minEvidence = 2;

  /// Share of all notes the kind must reach.
  static const double minShare = .25;
}

/// The repeat plan: the same part, slower first, then back up to the target.
final class FixRepeatPlan {
  const FixRepeatPlan({
    required this.steps,
    required this.nextBpm,
    required this.loop,
    this.nextExercise,
  });

  /// Ascending tempo steps (BPM); empty for a free-tempo lesson (no click).
  final List<int> steps;

  /// The tempo to play next: a fresh correction starts at the slower step; a
  /// persisting one repeats the last tempo; null for a free-tempo lesson.
  final int? nextBpm;

  /// Bars to repeat for steps below the anchor tempo; null = the full line.
  final ({int first, int last})? loop;

  /// An earlier lesson of the same course that practices this kind.
  final V1Lesson? nextExercise;
}

sealed class ListenTryFixResult {
  const ListenTryFixResult();
}

/// "I could not tell this sound apart with confidence; try again?"
final class FixUnmeasured extends ListenTryFixResult {
  const FixUnmeasured(this.reason);
  final CouldNotMeasure reason;
}

/// Heard well enough, the accuracy check of the lesson is met (measured) and
/// no kind of difference stands out. [nextBpm] is set while a correction is
/// active and the run was below its anchor tempo: the next step up.
final class FixClear extends ListenTryFixResult {
  const FixClear({this.nextBpm});
  final int? nextBpm;
}

/// Heard well enough, but the accuracy check is not met and no single kind
/// dominates: nothing is claimed, nothing faster is suggested.
final class FixNoClearDifference extends ListenTryFixResult {
  const FixNoClearDifference();
}

final class FixCorrection extends ListenTryFixResult {
  const FixCorrection({
    required this.kind,
    required this.bar,
    required this.count,
    required this.plan,
  });
  final FixKind kind;

  /// First bar (0-based, as in `NoteOutcome.bar`) where the kind was measured;
  /// the card shows `bar + 1`.
  final int bar;
  final int count;
  final FixRepeatPlan plan;
}

abstract final class ListenTryFix {
  /// Priority when two kinds are equally frequent.
  static const List<FixKind> priority = [
    FixKind.pitchOff,
    FixKind.early,
    FixKind.late,
    FixKind.missed,
  ];

  /// The one correction for [summary]. Every count (heard, decided, kinds,
  /// accuracy) is taken from the LATEST pass of each note (`lastMarks`), so
  /// loop passes never mix. [anchorBpm] is the tempo at which the correction
  /// started: while a correction persists the same step is offered again
  /// (never a higher one); once the run is clear it climbs to the next step.
  /// Null = fresh correction. [pool] = lessons a next exercise may come from.
  static ListenTryFixResult of(
    PracticeRunSummary summary, {
    required V1Lesson lesson,
    required bool freeTempo,
    int? anchorBpm,
    List<V1Lesson> pool = const [],
  }) {
    var correct = 0, different = 0, unheard = 0;
    for (final o in summary.lastMarks.values) {
      switch (o.mark) {
        case PracticeMark.correct:
          correct++;
        case PracticeMark.differentNote:
          different++;
        case PracticeMark.couldNotHear:
          unheard++;
        case PracticeMark.pending:
          break;
      }
    }
    final decided = correct + different;
    final total = decided + unheard;
    final heard = total == 0 ? 0.0 : decided / total;
    if (total == 0 || heard < FixThresholds.minHeard) {
      return const FixUnmeasured(CouldNotMeasure.weakSignal);
    }
    if (decided < FixThresholds.minDecided) {
      return const FixUnmeasured(CouldNotMeasure.tooFewNotes);
    }
    final rhythm = summary.gate.criteria.rhythm;
    final bars = <FixKind, List<int>>{};
    for (final o in summary.lastMarks.values) {
      final kind = kindOf(o, rhythm: rhythm);
      if (kind != null) (bars[kind] ??= []).add(o.bar);
    }
    FixKind? best;
    for (final k in priority) {
      final n = bars[k]?.length ?? 0;
      if (n < FixThresholds.minEvidence || n < FixThresholds.minShare * total) {
        continue;
      }
      if (best == null || n > bars[best]!.length) best = k;
    }
    if (best == null) {
      final accuracy = correct / decided;
      if (accuracy < summary.gate.criteria.minAccuracy - 1e-9) {
        return const FixNoClearDifference();
      }
      int? climb;
      if (anchorBpm != null && !freeTempo && summary.bpm < anchorBpm) {
        for (final st in tempoSteps(
          anchorBpm: anchorBpm,
          targetBpm: summary.targetBpm,
        )) {
          if (st > summary.bpm) {
            climb = st;
            break;
          }
        }
      }
      return FixClear(nextBpm: climb);
    }
    final list = bars[best]!..sort();
    return FixCorrection(
      kind: best,
      bar: list.first,
      count: list.length,
      plan: repeatPlan(
        best,
        runBpm: summary.bpm,
        targetBpm: summary.targetBpm,
        anchorBpm: anchorBpm,
        freeTempo: freeTempo,
        bars: list,
        lesson: lesson,
        pool: pool,
      ),
    );
  }

  /// What one note's latest outcome says; null when it says nothing.
  static FixKind? kindOf(NoteOutcome o, {required bool rhythm}) {
    switch (o.mark) {
      case PracticeMark.differentNote:
        if (!rhythm) return FixKind.pitchOff;
        final t = o.timingMs;
        if (t == null || t == 0) return null;
        return t < 0 ? FixKind.early : FixKind.late;
      case PracticeMark.couldNotHear:
        // Only a quiet attack window is a finding; a weak or loud signal,
        // app sound or a skipped note is the setup's story, not the player's.
        // And only on a rhythm line: on a pitch line "no beat heard" would
        // misname a note that was simply not picked up.
        return rhythm && o.reason == HearingReason.noAttack
            ? FixKind.missed
            : null;
      case PracticeMark.correct || PracticeMark.pending:
        return null;
    }
  }

  /// Slower first, then the run's tempo, then the target; ascending, no
  /// duplicates, inside the tempo range.
  static List<int> tempoSteps({
    required int anchorBpm,
    required int targetBpm,
  }) {
    final min = PracticeTempo.minBpm(targetBpm);
    final max = PracticeTempo.maxBpm(targetBpm);
    int clamp(int v) => v.clamp(min, max);
    final out = <int>[];
    for (final v in [
      clamp((anchorBpm * .75).round()),
      clamp(anchorBpm),
      clamp(targetBpm),
    ]) {
      if (out.isEmpty || v > out.last) out.add(v);
    }
    return out;
  }

  static FixRepeatPlan repeatPlan(
    FixKind kind, {
    required int runBpm,
    required int targetBpm,
    int? anchorBpm,
    required bool freeTempo,
    required List<int> bars,
    required V1Lesson lesson,
    List<V1Lesson> pool = const [],
  }) {
    final anchor = anchorBpm ?? runBpm;
    final steps = freeTempo
        ? const <int>[]
        : tempoSteps(anchorBpm: anchor, targetBpm: targetBpm);
    // A fresh correction starts at the slower step (below this run). While it
    // persists (anchor set) the same tempo is offered again: no step up until
    // a run is clear.
    int? next;
    if (steps.isNotEmpty) {
      if (anchorBpm == null) {
        for (final s in steps) {
          if (s < runBpm) {
            next = s;
            break;
          }
        }
      }
      next ??= runBpm;
    }
    // Only steps below the anchor repeat the short part; the steps from the
    // anchor up are full runs (a full run at the target is what the gate
    // measures).
    final sorted = List<int>.of(bars)..sort();
    final loop = next != null && next < anchor && sorted.isNotEmpty
        ? (first: sorted.first, last: math.min(sorted.last, sorted.first + 1))
        : null;
    return FixRepeatPlan(
      steps: steps,
      nextBpm: next,
      loop: loop,
      nextExercise: nextExercise(kind, lesson: lesson, pool: pool),
    );
  }

  /// The nearest EARLIER lesson of the same course whose line trains this
  /// kind (timing kinds: a rhythm-only line; pitch: a pitch line). Earlier
  /// lessons are already open when this one is; null when none exists.
  static V1Lesson? nextExercise(
    FixKind kind, {
    required V1Lesson lesson,
    required List<V1Lesson> pool,
  }) {
    final wantRhythm = kind != FixKind.pitchOff;
    V1Lesson? pick;
    for (final l in pool) {
      if (l.course != lesson.course || l.id.compareTo(lesson.id) >= 0) continue;
      final score = V1PracticeCatalog.scoreOf(l);
      if (score == null) continue;
      if (wantRhythm ? !score.isRhythmOnly : !score.hasPitches) continue;
      if (pick == null || l.id.compareTo(pick.id) > 0) pick = l;
    }
    return pick;
  }
}
