/// OST-P1-04 (a): which way the practice flow runs when measurement is not
/// fully available. Pure Dart; nothing reaches the screen yet (flag
/// `ostinatoFallbackModeEnabled`, closed).
///
/// Every mode lets the lesson continue: the learner is never left at a dead
/// end, and no mode ever produces a "wrong" verdict. Conceptually related to
/// the unmeasured run idea in `practice_outcome.dart`, but there is no link in
/// code (`PassGate.eligible` does not include microphone state). When this is
/// wired in, the binding must enforce: `measuresPlaying == false` implies no
/// pass and no fail verdict.
library;

/// How the practice flow runs.
enum PracticeFallbackMode {
  /// Microphone works and is calibrated: normal measured practice.
  measured,

  /// No trustworthy measurement, but guided play (metronome, reference,
  /// follow-along) continues. The run is unmeasured.
  unmeasuredGuided,

  /// No microphone (permission denied or no device): listen / reference
  /// only. The run is unmeasured.
  listenOnly,
}

extension PracticeFallbackModeX on PracticeFallbackMode {
  /// Only [PracticeFallbackMode.measured] produces measured results.
  bool get measuresPlaying => this == PracticeFallbackMode.measured;

  /// The lesson flow is never blocked, in any mode.
  bool get blocksLesson => false;

  /// No mode ever renders a "wrong" verdict.
  bool get canJudgeWrong => false;
}

/// Decides the mode from the four device facts.
///
/// - no microphone permission, or no microphone device -> [listenOnly]
/// - permission and device present, but not calibrated or measurement
///   unhealthy -> [unmeasuredGuided]
/// - everything fine -> [measured]
PracticeFallbackMode decideFallback({
  required bool micPermissionGranted,
  required bool micAvailable,
  required bool calibrated,
  required bool measurementHealthy,
}) {
  if (!micPermissionGranted || !micAvailable) {
    return PracticeFallbackMode.listenOnly;
  }
  if (!calibrated || !measurementHealthy) {
    return PracticeFallbackMode.unmeasuredGuided;
  }
  return PracticeFallbackMode.measured;
}
