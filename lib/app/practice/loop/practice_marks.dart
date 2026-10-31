/// The state of one expected note on screen and in the result (contract §5).
/// "Different note" is information, never a failure word; "could not hear"
/// is outside the accuracy ratio.
enum PracticeMark { pending, correct, differentNote, couldNotHear }

/// Why a note landed in "could not hear" — drives the hint, never a verdict.
enum HearingReason {
  /// No attack in the note's window (also protects against "silence = right").
  noAttack,

  /// Signal not above the room floor + 6 dB.
  tooQuiet,

  /// Clipping: too close or too loud.
  tooLoud,

  /// Pitch could not be resolved (noise, several notes, unstable).
  unclear,

  /// App output (cue/reference) was audible: low confidence, no verdict.
  appPlayback,

  /// Skipped in "Wait for me".
  skipped,
}
