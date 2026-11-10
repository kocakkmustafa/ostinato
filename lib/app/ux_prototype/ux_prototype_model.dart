import '../practice/loop/practice_marks.dart';

/// OST-UX-04 prototype state. Everything here is sample data: nothing is
/// stored, nothing listens to a microphone, and no measurement engine is
/// involved. The only real rule it mirrors is the one in
/// `04-design.md` Ek B / §9: a run counts as measured only when it ran to
/// the end, without loop or wait, with a microphone that heard it.

/// The simulated microphone situation (chosen in the prototype's Setup layer).
enum UxMic { ready, denied, unclear }

/// How the prototype classifies a finished run.
enum UxRunKind {
  /// Full run, no loop/wait, enough of it heard.
  measured,

  /// Stopped early, looped or waited on: "unmeasured", opens no gate.
  unmeasuredPartial,

  /// Listening was off: nothing to measure, only a self-check.
  unmeasuredNotListened,

  /// Heard too little to judge: the honest "could not hear" family.
  unreliable,
}

/// Notes in the prototype's sample bar line.
const int uxRunLength = 8;

/// The sample run used while the microphone is "ready": six correct, one
/// different note, one note that could not be heard (the design's example).
const List<PracticeMark> uxReadyScript = <PracticeMark>[
  PracticeMark.correct,
  PracticeMark.correct,
  PracticeMark.differentNote,
  PracticeMark.correct,
  PracticeMark.couldNotHear,
  PracticeMark.correct,
  PracticeMark.correct,
  PracticeMark.correct,
];

/// What the simulated listener "heard" for [mic] (all pending while denied).
List<PracticeMark> uxScriptFor(UxMic mic) => switch (mic) {
  UxMic.ready => uxReadyScript,
  UxMic.unclear => List<PracticeMark>.filled(
    uxRunLength,
    PracticeMark.couldNotHear,
  ),
  UxMic.denied => List<PracticeMark>.filled(uxRunLength, PracticeMark.pending),
};

/// Minimum share of notes that must be heard for a run to be judged; the
/// same 80 percent the real gate uses for "heard" (`PassCriteria.minHeard`).
const int uxMinHeardPercent = 80;

int uxCount(List<PracticeMark> marks, PracticeMark mark) =>
    marks.where((m) => m == mark).length;

/// Share of notes that were heard, in whole percent.
int uxHeardPercent(List<PracticeMark> marks) {
  final heard = marks.length - uxCount(marks, PracticeMark.couldNotHear);
  return marks.isEmpty ? 0 : (heard * 100 / marks.length).round();
}

/// Accuracy among the notes that were heard; null when none were heard.
int? uxAccuracyPercent(List<PracticeMark> marks) {
  final right = uxCount(marks, PracticeMark.correct);
  final different = uxCount(marks, PracticeMark.differentNote);
  final decided = right + different;
  return decided == 0 ? null : (right * 100 / decided).round();
}

/// The one classification rule of the prototype.
UxRunKind uxClassifyRun({
  required UxMic mic,
  required bool finished,
  required bool loopUsed,
  required bool waitUsed,
  required List<PracticeMark> marks,
}) {
  if (mic == UxMic.denied) return UxRunKind.unmeasuredNotListened;
  if (!finished || loopUsed || waitUsed) return UxRunKind.unmeasuredPartial;
  if (mic == UxMic.unclear || uxHeardPercent(marks) < uxMinHeardPercent) {
    return UxRunKind.unreliable;
  }
  return UxRunKind.measured;
}

/// One row of the prototype's history (sample or from this session).
final class UxHistoryRun {
  const UxHistoryRun({
    required this.dayIsToday,
    required this.kind,
    required this.marks,
  });

  final bool dayIsToday;
  final UxRunKind kind;
  final List<PracticeMark> marks;

  bool get measured => kind == UxRunKind.measured;
}

/// The sample "yesterday" row shown before any run in this session: 5 right,
/// 2 different, 1 could not hear (the design's wireframe).
const UxHistoryRun uxSampleYesterday = UxHistoryRun(
  dayIsToday: false,
  kind: UxRunKind.measured,
  marks: <PracticeMark>[
    PracticeMark.correct,
    PracticeMark.correct,
    PracticeMark.differentNote,
    PracticeMark.correct,
    PracticeMark.couldNotHear,
    PracticeMark.correct,
    PracticeMark.differentNote,
    PracticeMark.correct,
  ],
);
