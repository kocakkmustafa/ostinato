import 'dart:math' as math;

import '../onset/onset_detector.dart';

/// How one played note landed against the beat it belongs to.
final class TimingDeviation {
  const TimingDeviation({required this.onsetTUs, required this.beatTUs, required this.deviationMs});
  final int onsetTUs;
  final int beatTUs;

  /// Negative = early (rushing), positive = late (dragging).
  final double deviationMs;
}

/// Summary of a drill's timing, in the only terms we can defend.
final class TimingReport {
  const TimingReport({
    required this.deviations,
    required this.matchedBeats,
    required this.totalBeats,
    required this.medianMs,
    required this.spreadMs,
    required this.bias,
  });

  final List<TimingDeviation> deviations;
  final int matchedBeats;
  final int totalBeats;

  /// Median absolute deviation — the headline number, robust to one bad note.
  final double medianMs;

  /// Interquartile spread: consistency. A student steadily 30 ms late is a
  /// different lesson from one scattered ±60 ms, and averaging hides that.
  final double spreadMs;

  /// Signed median: rushing, dragging, or centred.
  final TimingBias bias;

  double get coverage => totalBeats == 0 ? 0 : matchedBeats / totalBeats;
}

enum TimingBias { rushing, dragging, centred }

/// Matches detected onsets to expected beat times.
///
/// The grid comes from motion_core's `BeatGrid` (metronome, known-BPM track, or
/// offline-analysed audio) and the beat times handed in here are expected to be
/// **heard** times — already corrected for output latency via the core's
/// `AudioLatencyProfile`. Judging against scheduled time instead would tell a
/// Bluetooth listener they are late on every single beat.
final class MetronomeAligner {
  const MetronomeAligner({this.matchWindowMs = 150, this.biasThresholdMs = 15});

  /// An onset further than this from every beat is not a late note, it is a
  /// different event (a cough, a page turn, an extra note). Counting it would
  /// corrupt the median.
  final double matchWindowMs;
  final double biasThresholdMs;

  TimingReport align({required List<Onset> onsets, required List<int> beatTimesUs}) {
    final deviations = <TimingDeviation>[];
    final usedOnsets = <int>{};

    for (final beatUs in beatTimesUs) {
      int? bestIdx;
      var bestAbsMs = double.infinity;

      for (var i = 0; i < onsets.length; i++) {
        if (usedOnsets.contains(i)) continue;
        final devMs = (onsets[i].tUs - beatUs) / 1000.0;
        final absMs = devMs.abs();
        if (absMs < bestAbsMs) {
          bestAbsMs = absMs;
          bestIdx = i;
        }
      }

      if (bestIdx == null || bestAbsMs > matchWindowMs) continue;
      usedOnsets.add(bestIdx);
      deviations.add(TimingDeviation(
        onsetTUs: onsets[bestIdx].tUs,
        beatTUs: beatUs,
        deviationMs: (onsets[bestIdx].tUs - beatUs) / 1000.0,
      ));
    }

    if (deviations.isEmpty) {
      return TimingReport(
        deviations: const [],
        matchedBeats: 0,
        totalBeats: beatTimesUs.length,
        medianMs: 0,
        spreadMs: 0,
        bias: TimingBias.centred,
      );
    }

    final abs = deviations.map((d) => d.deviationMs.abs()).toList()..sort();
    final signed = deviations.map((d) => d.deviationMs).toList()..sort();
    final medianSigned = _percentile(signed, 0.5);

    return TimingReport(
      deviations: deviations,
      matchedBeats: deviations.length,
      totalBeats: beatTimesUs.length,
      medianMs: _percentile(abs, 0.5),
      spreadMs: _percentile(signed, 0.75) - _percentile(signed, 0.25),
      bias: medianSigned < -biasThresholdMs
          ? TimingBias.rushing
          : medianSigned > biasThresholdMs
              ? TimingBias.dragging
              : TimingBias.centred,
    );
  }

  double _percentile(List<double> sorted, double p) {
    if (sorted.isEmpty) return 0;
    final idx = ((sorted.length - 1) * p);
    final lo = idx.floor();
    final hi = math.min(lo + 1, sorted.length - 1);
    return sorted[lo] + (sorted[hi] - sorted[lo]) * (idx - lo);
  }
}
