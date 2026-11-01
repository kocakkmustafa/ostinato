import 'package:ostinato_audio/ostinato_audio.dart';

import 'tuner_guidance.dart';

/// One analysis of the rolling tuner buffer.
final class TunerAnalysis {
  const TunerAnalysis.reading(TunerPitch this.reading) : refusal = null;
  const TunerAnalysis.refused(TunerRefusal this.refusal) : reading = null;

  final TunerPitch? reading;
  final TunerRefusal? refusal;
}

/// The attack must be at least this far inside the buffer to count as seen
/// (the E46 note-gate idea, used here only as a display-confidence rule:
/// E45 found most poor readings came from the tail of a note whose attack
/// was outside the buffer).
const int kMinVisibleAttackMs = 20;

/// Buffer length per profile: attack skip, the minimum readings, and room
/// for a pluck that lands up to 0.6 s into the buffer.
int tunerBufferMs(PreciseTunerProfile p) =>
    p.skipAfterAttackMs +
    p.readingWindowMs +
    p.readingHopMs * (p.minReadings - 1) +
    600;

/// Pure analysis, run off the main isolate. Nothing is retained.
TunerAnalysis analyzeTunerBuffer(
  List<double> samples, {
  required int sampleRate,
  required PreciseTunerProfile profile,
  double? roomFloorDb,
  double a4Hz = 440,
}) {
  final p = profile;
  final required = ((p.skipAfterAttackMs +
              p.readingWindowMs +
              p.readingHopMs * (p.minReadings - 1)) *
          sampleRate /
          1000)
      .round();
  final attack = const AttackLocator().lastUsableAttack(
    samples,
    sampleRate,
    requiredSamples: required,
  );
  if (attack == null) {
    return const TunerAnalysis.refused(TunerRefusal.insufficientSamples);
  }
  final result = PreciseTuner(profile: profile, referenceA4Hz: a4Hz).measure(
    samples,
    sampleRate: sampleRate,
    attackIndex: attack,
    roomFloorDb: roomFloorDb,
  );
  final m = result.measurement;
  if (m == null) return TunerAnalysis.refused(result.refusal!);
  final attackSeen = attack >= kMinVisibleAttackMs * sampleRate / 1000;
  return TunerAnalysis.reading(
    TunerPitch(
      f0Hz: m.f0Hz,
      confident:
          attackSeen &&
          !m.fromLateReadings &&
          m.spreadCents <= p.maxSpreadCents,
    ),
  );
}
