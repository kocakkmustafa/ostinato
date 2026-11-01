import 'dart:math' as math;

import '../../curriculum/v1_lesson.dart';
import 'practice_marks.dart';
import 'practice_score.dart';

/// F2.5 — what one run produced and whether it opens the next lesson
/// (pure Dart). Contract §5–§6; all thresholds `expertPending`.
final class NoteOutcome {
  const NoteOutcome({
    required this.eventIndex,
    required this.bar,
    required this.pass,
    required this.mark,
    this.reason,
    this.expectedMidi,
    this.observedMidi,
    this.centsFromExpected,
    this.timingMs,
  });

  final int eventIndex, bar, pass;
  final PracticeMark mark;
  final HearingReason? reason;
  final int? expectedMidi, observedMidi;
  final double? centsFromExpected;

  /// Only with latency calibration; negative = early.
  final double? timingMs;
}

/// Contract §6.3 (tempo rules): which tempo opens the next lesson.
enum TempoGate {
  /// "Açılış temposu sonraki dersi açar. Hedef tempo dersi 'tamamlandı'
  /// yapar." A pass at the opening tempo (or faster) opens the next lesson;
  /// a pass at the target tempo also marks this one completed.
  openingOpensNext,

  /// "`M!` dersleri (modül geçişleri, seviye testleri) hedef tempoda
  /// geçilir." Only a pass at the target tempo opens (and completes).
  targetOnly,
}

/// The measured gate. Default (contract §6.2, S1): accuracy ≥ 80 % over
/// decided notes ("could not hear" excluded), heard ≥ 80 % (contract §5 rule
/// 1: > 20 % unheard makes the set invalid), tempo per [TempoGate] (§6.3).
/// Below the opening tempo a run is "practice" and opens nothing.
final class PassCriteria {
  const PassCriteria({
    required this.minAccuracy,
    this.minHeard = .8,
    this.tempoGate = TempoGate.openingOpensNext,
    this.minCorrect,
    this.customText,
    this.expertPending = true,
  });

  final double minAccuracy;
  final double minHeard;
  final TempoGate tempoGate;
  final int? minCorrect;

  /// A lesson-specific rule (`pass.levelDefault: false`) is shown as written;
  /// its machine-checkable part is the level default plus [minCorrect].
  final GuitarTextLike? customText;
  final bool expertPending;

  static const Map<int, double> levelAccuracy = {
    1: .80,
    2: .85,
    3: .85,
    4: .90,
  };

  factory PassCriteria.forLesson(V1Lesson lesson) => PassCriteria(
    minAccuracy: levelAccuracy[lesson.level] ?? .8,
    tempoGate: lesson.practice.measurement.contains('M!')
        ? TempoGate.targetOnly
        : TempoGate.openingOpensNext,
    minCorrect: lesson.practice.pass.minCorrect,
    customText: lesson.practice.pass.levelDefault
        ? null
        : GuitarTextLike(
            lesson.practice.pass.text!.en,
            lesson.practice.pass.text!.tr,
          ),
    expertPending: lesson.expertPending,
  );
}

/// EN/TR pair without a Flutter dependency.
final class GuitarTextLike {
  const GuitarTextLike(this.en, this.tr);
  final String en, tr;
}

enum GateCheckKind { accuracy, heard, tempo, minCorrect }

final class GateCheck {
  const GateCheck(this.kind, this.ok, this.value, this.threshold);
  final GateCheckKind kind;
  final bool ok;
  final double value, threshold;
}

/// Why a run cannot open a lesson even with good numbers.
enum GateIneligible { stoppedEarly, loopUsed, waitUsed }

final class PassGate {
  const PassGate({
    required this.checks,
    required this.ineligible,
    required this.criteria,
    required this.bpm,
    required this.targetBpm,
  });

  final List<GateCheck> checks;
  final List<GateIneligible> ineligible;
  final PassCriteria criteria;
  final int bpm, targetBpm;

  bool get eligible => ineligible.isEmpty;

  /// The measured gate is passed: the next lesson opens (§6.3).
  bool get passed => eligible && checks.every((c) => c.ok);

  /// Passed at the target tempo: this lesson is "completed" (§6.3).
  bool get completed => passed && bpm >= targetBpm;
  bool get heardTooLow =>
      checks.any((c) => c.kind == GateCheckKind.heard && !c.ok);
}

enum NextStep {
  nextLesson,
  checkSetup,
  loopSlower,
  raiseTempo,
  performanceRun,
  tryAgain,
}

final class PracticeRunSummary {
  PracticeRunSummary._({
    required this.outcomes,
    required this.correct,
    required this.different,
    required this.unheard,
    required this.bpm,
    required this.openBpm,
    required this.targetBpm,
    required this.gate,
    required this.errorBars,
    required this.lastMarks,
    required this.medianTimingMs,
    required this.timingCalibrated,
    required this.nextStep,
  });

  final List<NoteOutcome> outcomes;
  final int correct, different, unheard;
  final int bpm, openBpm, targetBpm;
  final PassGate gate;

  /// Bars with a ◆ or ◯ in the last pass, for the error map and "loop these".
  final List<int> errorBars;

  /// Event index → mark of its latest pass (the error map strip).
  final Map<int, NoteOutcome> lastMarks;
  final double? medianTimingMs;
  final bool timingCalibrated;
  final NextStep nextStep;

  int get total => correct + different + unheard;

  /// correct / (correct + different); null when nothing was decided.
  double? get accuracy =>
      correct + different == 0 ? null : correct / (correct + different);

  /// (correct + different) / all.
  double get heard => total == 0 ? 0 : (correct + different) / total;

  factory PracticeRunSummary.of({
    required PracticeScore score,
    required List<NoteOutcome> outcomes,
    required int bpm,
    required int openBpm,
    required int targetBpm,
    required bool completed,
    required bool loopUsed,
    required bool waitUsed,
    PassCriteria criteria = const PassCriteria(minAccuracy: .8),
    bool timingCalibrated = false,
  }) {
    var c = 0, d = 0, u = 0;
    for (final o in outcomes) {
      switch (o.mark) {
        case PracticeMark.correct:
          c++;
        case PracticeMark.differentNote:
          d++;
        case PracticeMark.couldNotHear:
          u++;
        case PracticeMark.pending:
          break;
      }
    }
    final accuracy = c + d == 0 ? 0.0 : c / (c + d);
    final total = c + d + u;
    final gateBpm = criteria.tempoGate == TempoGate.targetOnly
        ? targetBpm
        : math.min(openBpm, targetBpm);
    final heard = total == 0 ? 0.0 : (c + d) / total;
    final checks = <GateCheck>[
      GateCheck(
        GateCheckKind.accuracy,
        c + d > 0 && accuracy >= criteria.minAccuracy - 1e-9,
        accuracy,
        criteria.minAccuracy,
      ),
      GateCheck(
        GateCheckKind.heard,
        total > 0 && heard >= criteria.minHeard - 1e-9,
        heard,
        criteria.minHeard,
      ),
      GateCheck(
        GateCheckKind.tempo,
        bpm >= gateBpm,
        bpm.toDouble(),
        gateBpm.toDouble(),
      ),
      if (criteria.minCorrect != null)
        GateCheck(
          GateCheckKind.minCorrect,
          c >= criteria.minCorrect!,
          c.toDouble(),
          criteria.minCorrect!.toDouble(),
        ),
    ];
    // A full single run must cover every note once.
    final allCovered =
        completed &&
        score.events.every((e) => outcomes.any((o) => o.eventIndex == e.index));
    final ineligible = <GateIneligible>[
      if (!allCovered) GateIneligible.stoppedEarly,
      if (loopUsed) GateIneligible.loopUsed,
      if (waitUsed) GateIneligible.waitUsed,
    ];
    final gate = PassGate(
      checks: checks,
      ineligible: ineligible,
      criteria: criteria,
      bpm: bpm,
      targetBpm: targetBpm,
    );
    final last = <int, NoteOutcome>{};
    for (final o in outcomes) {
      final prev = last[o.eventIndex];
      if (prev == null || o.pass >= prev.pass) last[o.eventIndex] = o;
    }
    final errorBars = {
      for (final o in last.values)
        if (o.mark != PracticeMark.correct) o.bar,
    }.toList()..sort();
    final timings = [
      for (final o in outcomes)
        if (o.timingMs != null) o.timingMs!.abs(),
    ]..sort();
    final median = timings.isEmpty ? null : timings[timings.length ~/ 2];
    NextStep next;
    if (gate.passed) {
      next = NextStep.nextLesson;
    } else if (total > 0 && heard < criteria.minHeard) {
      next = NextStep.checkSetup;
    } else if (c + d > 0 && accuracy < criteria.minAccuracy) {
      next = NextStep.loopSlower;
    } else if (bpm < gateBpm) {
      next = NextStep.raiseTempo;
    } else if (!gate.eligible) {
      next = NextStep.performanceRun;
    } else {
      next = NextStep.tryAgain;
    }
    return PracticeRunSummary._(
      outcomes: List.unmodifiable(outcomes),
      correct: c,
      different: d,
      unheard: u,
      bpm: bpm,
      openBpm: openBpm,
      targetBpm: targetBpm,
      gate: gate,
      errorBars: errorBars,
      lastMarks: last,
      medianTimingMs: median,
      timingCalibrated: timingCalibrated,
      nextStep: next,
    );
  }

  /// Bars to loop for "loop these at 70 %": the error bars as one range.
  ({int first, int last})? get loopSuggestion => errorBars.isEmpty
      ? null
      : (
          first: errorBars.first,
          last: math.min(errorBars.last, errorBars.first + 1),
        );
}

/// "Session finished" event for retention (weekly goal / streak, PR #12).
/// This branch only emits it; wiring to `PracticeSessionRecorder` happens
/// once both branches are merged. Counting rule there: ≥ 60 s listening and
/// ≥ 1 heard event ("could not hear" excluded) — [heardEvents] already
/// excludes it.
final class PracticeSessionFinished {
  const PracticeSessionFinished({
    required this.lessonId,
    required this.course,
    required this.activeDuration,
    required this.heardEvents,
    required this.summary,
  });

  final String lessonId;

  /// Instrument course id as the app names it (`guitar`).
  final String course;

  /// Microphone listening time of this run (capture clock).
  final Duration activeDuration;

  /// Correct + different-note events.
  final int heardEvents;
  final PracticeRunSummary summary;
}
