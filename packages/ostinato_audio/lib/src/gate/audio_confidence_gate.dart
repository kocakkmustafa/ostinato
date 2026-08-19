import 'dart:math' as math;

import '../pitch/pitch_source.dart';

/// What the engine is allowed to do with one window of audio.
enum AudioVerdict {
  /// Signal is good enough to measure and to judge.
  reliable,

  /// We heard something but will not stand behind it. The user is told *why*,
  /// never given a number.
  unreliable,

  /// A window we deliberately refuse to judge even when the signal looks fine:
  /// note attacks and bow changes are aperiodic by nature. Measurements may be
  /// collected here, verdicts may not.
  transition,
}

/// Why a window was not judged. Shown to the user in plain language — "I
/// couldn't hear that clearly" beats a confident wrong correction, and the
/// reason is what lets them fix the room instead of blaming themselves.
enum AudioGateReason {
  ok,
  tooQuiet,
  notPeriodic,
  outOfExpectedRange,
  attackWindow,
  coachSpeaking,
}

final class AudioGateResult {
  const AudioGateResult(this.verdict, this.reason);
  final AudioVerdict verdict;
  final AudioGateReason reason;

  bool get mayJudge => verdict == AudioVerdict.reliable;
}

/// Thresholds live in versioned config, never in code (family rule; per
/// instrument values come from the ruleset package).
final class AudioGateConfig {
  const AudioGateConfig({
    this.minPeriodicity = 0.55,
    this.attackWindowUs = 100000,
    this.minLevelAboveFloorDb = 6.0,
  });

  final double minPeriodicity;

  /// How long after a detected onset we collect but do not judge.
  final int attackWindowUs;

  /// Required level above the *calibrated room floor*, not an absolute dBFS
  /// number. Phone microphones differ by more than any fixed threshold could
  /// survive, so Setup Check measures the room and everything downstream is
  /// relative to that measurement.
  final double minLevelAboveFloorDb;
}

/// The honesty valve of the audio path.
///
/// Its whole job is to convert "the estimator returned a number" into "we are
/// willing to tell a student something about this". Three states, not two:
/// collapsing `transition` into `unreliable` would throw away the frames a bow
/// change is made of, and collapsing it into `reliable` would produce a
/// correction for every single bow change.
final class AudioConfidenceGate {
  const AudioConfidenceGate({this.config = const AudioGateConfig()});

  final AudioGateConfig config;

  AudioGateResult evaluate(
    PitchReading reading, {
    required double roomFloorDb,
    int? lastOnsetTUs,
    bool coachSpeaking = false,
    double? expectedHz,
    double expectedToleranceCents = 700,
  }) {
    // The coach's own voice reaches the microphone. V1 defence is a time gate,
    // not echo cancellation: AEC is tuned for speech and mangles music.
    if (coachSpeaking) {
      return const AudioGateResult(AudioVerdict.unreliable, AudioGateReason.coachSpeaking);
    }

    if (reading.rmsDb < roomFloorDb + config.minLevelAboveFloorDb) {
      return const AudioGateResult(AudioVerdict.unreliable, AudioGateReason.tooQuiet);
    }

    if (lastOnsetTUs != null && reading.tStartUs - lastOnsetTUs < config.attackWindowUs) {
      return const AudioGateResult(AudioVerdict.transition, AudioGateReason.attackWindow);
    }

    if (!reading.hasPitch || reading.periodicity < config.minPeriodicity) {
      return const AudioGateResult(AudioVerdict.unreliable, AudioGateReason.notPeriodic);
    }

    if (expectedHz != null && absCents(reading.f0Hz!, expectedHz) > expectedToleranceCents) {
      return const AudioGateResult(AudioVerdict.unreliable, AudioGateReason.outOfExpectedRange);
    }

    return const AudioGateResult(AudioVerdict.reliable, AudioGateReason.ok);
  }
}

/// Absolute distance between two frequencies in cents.
double absCents(double a, double b) => (1200 * math.log(a / b) / math.ln2).abs();

/// Signed distance in cents: positive means [a] is sharp relative to [b].
double cents(double a, double b) => 1200 * math.log(a / b) / math.ln2;

/// RMS level in dBFS. Extracted here as a SHARED helper (2026-08-19,
/// GuitarChordDrillEvaluator) after the same ~8-line formula had been
/// copy-pasted privately in `yin.dart`, `audio_snr_replay.dart` and
/// `guitarset_chord_snr_replay.dart` — those existing, already-tested call
/// sites were deliberately left AS-IS (no retroactive refactor of shared
/// motor code without its own regression pass); this is only for new code
/// going forward.
double rmsDb(List<double> samples) {
  if (samples.isEmpty) return -160;
  double sum = 0;
  for (final double v in samples) {
    sum += v * v;
  }
  final double rms = math.sqrt(sum / samples.length);
  if (rms <= 1e-9) return -160;
  return 20 * math.log(rms) / math.ln10;
}
