/// A single pitch estimate over a window of audio.
///
/// Carries an interval, never a point in time: every estimator needs at least
/// two periods of signal to say anything, and on the low strings that window is
/// tens of milliseconds long. Fusing an audio finding with a camera finding is
/// an interval intersection; pretending the estimate happened at one instant is
/// how false "the bow changed while the sound stopped" findings get made.
final class PitchReading {
  const PitchReading({
    required this.tStartUs,
    required this.tEndUs,
    required this.f0Hz,
    required this.periodicity,
    required this.rmsDb,
  });

  /// Window start on the shared monotonic clock (motion-core contract).
  final int tStartUs;
  final int tEndUs;

  /// Estimated fundamental in Hz; `null` when the estimator found no periodic
  /// component it was willing to stand behind.
  final double? f0Hz;

  /// 0..1, higher is more periodic. For YIN-family estimators this is
  /// `1 - aperiodicity`, which is the estimator's own doubt, not a score we
  /// invented afterwards.
  final double periodicity;

  /// Level of the window relative to full scale, in dBFS.
  final double rmsDb;

  bool get hasPitch => f0Hz != null;

  Duration get windowLength => Duration(microseconds: tEndUs - tStartUs);
}

/// The seam between "which library estimates pitch" and the rest of Ostinato.
///
/// Deliberately narrow. The G1-C benchmark found three viable estimators (YIN,
/// pYIN, SwiftF0) all inside our accuracy thresholds on real cello, which means
/// the choice is genuinely open and will likely differ per platform — iOS may
/// end up on AudioKit, Android on a native port of [YinPitchSource]. Everything
/// downstream (gate, scoring, feedback) is written against this interface so
/// that swapping the estimator is a one-line change, not surgery.
abstract interface class PitchSource {
  /// Analyse one window of mono float samples in `[-1, 1]`.
  ///
  /// [tStartUs] is the capture timestamp of `samples[0]` on the shared
  /// monotonic clock.
  PitchReading analyze(List<double> samples, {required int sampleRate, required int tStartUs});

  /// Lowest and highest fundamental this source will report, in Hz.
  ///
  /// Instrument configs narrow this further — a voice lesson has no business
  /// reporting 60 Hz, and an open-string cello drill has no business reporting
  /// 900 Hz. Narrowing the search range is also the cheapest defence against
  /// octave errors.
  ({double minHz, double maxHz}) get range;
}
