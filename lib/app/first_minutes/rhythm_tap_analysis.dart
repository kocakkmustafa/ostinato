import 'package:ostinato_audio/ostinato_audio.dart';

import '../ui_copy.dart';
import 'first_minutes_copy.dart';

/// OST-P0-05: how a few taps sat against the beat grid, in pure Dart.
///
/// Tap times come from touch events on this device and are never written to
/// disk. The grid comes from the clip the app itself played; the exact moment
/// the speaker sounded is not known (output latency), so a CONSTANT offset is
/// reported but never judged: only how steady the taps are (their spread) is
/// used for the summary, and the summary says exactly that (consistency),
/// never "close to the beat", because a steady +250 ms (Bluetooth) is not
/// close to anything the learner can hear. There is no single correct way to tap, and nothing
/// here produces a "wrong" verdict.

/// Fewer matched taps than this cannot say anything about steadiness (two
/// taps always look steady). The product asks for four.
const int kMinMatchedTaps = 3;

/// At least this share of the expected beats must have a tap near it.
const double kMinTapCoverage = 0.5;

/// A tap further than this from every expected beat is a different event.
const double kTapMatchWindowMs = 300;

/// Interquartile spread above this is too scattered to read (not measured).
const double kMaxReadableSpreadMs = 140;

/// Human tolerance: spread up to this still counts as "close to the beat".
const double kSteadySpreadMs = 60;

/// How much closer/looser the second try must be to be called different.
const double kComparisonDeltaMs = 15;

enum TapMeasureStatus { measured, notMeasured }

enum TapSteadiness { steady, loose }

final class TapMeasurement {
  const TapMeasurement({
    required this.status,
    required this.matched,
    required this.expected,
    required this.deviationsMs,
    required this.spreadMs,
    required this.offsetMs,
    this.steadiness,
  });

  final TapMeasureStatus status;
  final int matched;
  final int expected;

  /// One entry per expected beat, in order: signed ms (negative = before the
  /// beat) or null where no tap was near that beat.
  final List<double?> deviationsMs;

  /// Interquartile spread of the matched deviations (steadiness, ms).
  final double spreadMs;

  /// Signed median offset. Informational only: it includes output latency.
  final double offsetMs;

  /// Null when [status] is [TapMeasureStatus.notMeasured].
  final TapSteadiness? steadiness;

  bool get measured => status == TapMeasureStatus.measured;
}

/// Matches [tapTimesUs] to [beatTimesUs] with the shared [MetronomeAligner]
/// and reads steadiness. Both lists use one clock (microseconds).
TapMeasurement measureTaps({
  required List<int> tapTimesUs,
  required List<int> beatTimesUs,
}) {
  final onsets = [for (final t in tapTimesUs) Onset(tUs: t, strength: 1)]
    ..sort((a, b) => a.tUs.compareTo(b.tUs));
  final report = const MetronomeAligner(
    matchWindowMs: kTapMatchWindowMs,
  ).align(onsets: onsets, beatTimesUs: beatTimesUs);
  final byBeat = {for (final d in report.deviations) d.beatTUs: d.deviationMs};
  final perBeat = [for (final b in beatTimesUs) byBeat[b]];
  final signed = report.deviations.map((d) => d.deviationMs).toList()..sort();
  final offset = signed.isEmpty ? 0.0 : _median(signed);
  final readable =
      report.matchedBeats >= kMinMatchedTaps &&
      report.coverage >= kMinTapCoverage &&
      report.spreadMs <= kMaxReadableSpreadMs;
  return TapMeasurement(
    status: readable ? TapMeasureStatus.measured : TapMeasureStatus.notMeasured,
    matched: report.matchedBeats,
    expected: beatTimesUs.length,
    deviationsMs: perBeat,
    spreadMs: report.spreadMs,
    offsetMs: offset,
    steadiness: !readable
        ? null
        : report.spreadMs <= kSteadySpreadMs
        ? TapSteadiness.steady
        : TapSteadiness.loose,
  );
}

double _median(List<double> sorted) {
  final n = sorted.length;
  return n.isOdd ? sorted[n ~/ 2] : (sorted[n ~/ 2 - 1] + sorted[n ~/ 2]) / 2;
}

/// The one sentence for a single try. Never judges right or wrong.
UiCopy summaryFor(TapMeasurement m) => switch (m.steadiness) {
  null => FirstMinutesCopy.summaryNotMeasured,
  TapSteadiness.steady => FirstMinutesCopy.summarySteady,
  TapSteadiness.loose => FirstMinutesCopy.summaryLoose,
};

/// The sentence about the difference between try 1 and try 2.
UiCopy comparisonFor(TapMeasurement first, TapMeasurement second) {
  if (!first.measured || !second.measured) return FirstMinutesCopy.compareNone;
  final delta = second.spreadMs - first.spreadMs;
  if (delta <= -kComparisonDeltaMs) return FirstMinutesCopy.compareCloser;
  if (delta >= kComparisonDeltaMs) return FirstMinutesCopy.compareLooser;
  return FirstMinutesCopy.compareSimilar;
}
