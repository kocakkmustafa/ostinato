import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ostinato_audio/ostinato_audio.dart';

/// F4.2 step 3 — speaker → room → microphone latency (E50 arm M1), pure Dart.
///
/// Method (`9-ses-motoru-e45-a3.md` §5, adopted): eight 4 ms, 6 kHz clicks at
/// 100 BPM on the metronome stream, recorded on the capture clock;
/// [LoopbackLatencyEstimator] with the **first-arrival rule**
/// (`firstArrivalRatio: 0.5`) picks the direct sound, not a room reflection,
/// and takes the median over clicks. The learner does nothing (no clapping).
///
/// The result is a **round trip**: from the click's frame on the output
/// stream (`anchorUs + frame / rate`) to the moment it shows up in the
/// recording. A learner who plays on the click they hear lands in the
/// recording exactly that much later, so the lesson's expected note time is
/// `anchorUs + frame / rate + roundTrip`. The timeline already adds the
/// native `outputLatencyUs`; the correction it needs is the rest
/// ([latencyCorrectionUs]). Simulation bars (E50 Q: calibration p95 0.52 ms)
/// are not verified on a real phone.
const int kCalibrationClicks = 8;
const int kCalibrationBpm = 100;
const double kCalibrationFirstArrivalRatio = .5;

/// Longest round trip searched (E49/E50 simulated 40–320 ms; Bluetooth
/// output can exceed 300 ms, so the window is half a second).
const int kCalibrationMaxLagMs = 500;

/// Acceptance (not device-verified; E50 simulation spread was ≤ 0.19 ms):
/// at least 6 of 8 clicks heard and per-click lags within 8 ms of each other.
const int kCalibrationMinHeard = 6;
const int kCalibrationMaxSpreadMs = 8;

/// Where latency is measured and stored. Latency belongs to the route, not
/// the phone (Core `LatencyCalibrationStore` semantics, read only): a value
/// measured on the speaker is not used with headphones.
enum CalibrationRoute { speaker, wiredHeadset, bluetooth }

/// The click used for calibration: the estimator's own template.
Float64List calibrationClick(int sampleRate) =>
    LoopbackLatencyEstimator.click(sampleRate: sampleRate);

/// One stored calibration of one route.
final class RouteLatency {
  const RouteLatency({
    required this.roundTripUs,
    required this.spreadUs,
    required this.heardClicks,
    required this.totalClicks,
    required this.measuredAt,
  });

  final int roundTripUs;
  final int spreadUs;
  final int heardClicks, totalClicks;
  final DateTime measuredAt;

  /// Correction the metronome timeline needs on top of the native output
  /// latency it already adds.
  int latencyCorrectionUs({required int outputLatencyUs}) =>
      roundTripUs - outputLatencyUs;

  Map<String, Object?> toJson() => {
    'roundTripUs': roundTripUs,
    'spreadUs': spreadUs,
    'heardClicks': heardClicks,
    'totalClicks': totalClicks,
    'measuredAt': measuredAt.toUtc().toIso8601String(),
  };

  factory RouteLatency.fromJson(Map<String, dynamic> json) {
    final r = RouteLatency(
      roundTripUs: json['roundTripUs'] as int,
      spreadUs: json['spreadUs'] as int,
      heardClicks: json['heardClicks'] as int,
      totalClicks: json['totalClicks'] as int,
      measuredAt: DateTime.parse(json['measuredAt'] as String),
    );
    if (r.roundTripUs < 0 ||
        r.roundTripUs > kCalibrationMaxLagMs * 1000 ||
        r.heardClicks > r.totalClicks) {
      throw const FormatException('Invalid route latency');
    }
    return r;
  }
}

sealed class LatencyCalibrationResult {
  const LatencyCalibrationResult();
}

final class LatencyMeasured extends LatencyCalibrationResult {
  const LatencyMeasured(this.latency);
  final RouteLatency latency;
}

/// Fewer than [kCalibrationMinHeard] clicks reached the microphone.
final class LatencyNotHeard extends LatencyCalibrationResult {
  const LatencyNotHeard(this.heardClicks);
  final int heardClicks;
}

/// The clicks were heard but arrived at different delays (echo, a moving
/// phone, a route change). The number would not be a latency.
final class LatencyUnsteady extends LatencyCalibrationResult {
  const LatencyUnsteady(this.spreadUs);
  final int spreadUs;
}

/// What the calibration run needs to know to read its own recording.
final class CalibrationRecording {
  CalibrationRecording({
    required this.samples,
    required this.sampleRate,
    required this.startUs,
    required this.anchorUs,
    required this.framesPerBeat,
    this.clicks = kCalibrationClicks,
  });

  /// Mono capture, contiguous, first sample at [startUs] (capture clock).
  final Float64List samples;
  final int sampleRate;
  final int startUs;

  /// Capture-clock time of the click stream's frame 0 (native anchor; the
  /// native output latency is deliberately not added).
  final int anchorUs;
  final int framesPerBeat;
  final int clicks;

  /// Sample index in [samples] where click `k` left the output stream.
  List<int> get clickIndices => [
    for (var k = 0; k < clicks; k++)
      ((anchorUs - startUs) * sampleRate / 1e6).round() + k * framesPerBeat,
  ];

  /// Capture-clock time by which the last click's echo has arrived.
  int get endUs =>
      anchorUs +
      ((clicks - 1) * framesPerBeat * 1e6 / sampleRate).round() +
      kCalibrationMaxLagMs * 1000 +
      50000;
}

/// Runs the estimator on one recording (pure; production calls it in an
/// isolate).
LatencyCalibrationResult estimateRouteLatency(
  CalibrationRecording r, {
  DateTime? at,
}) {
  final rate = r.sampleRate;
  final template = calibrationClick(rate);
  final indices = r.clickIndices;
  if (indices.isEmpty || indices.first < 0) return const LatencyNotHeard(0);
  final estimate =
      const LoopbackLatencyEstimator(
        firstArrivalRatio: kCalibrationFirstArrivalRatio,
      ).estimate(
        r.samples,
        template: template,
        clickTimes: indices,
        maxLagSamples: kCalibrationMaxLagMs * rate ~/ 1000,
      );
  if (estimate == null || estimate.heardClicks < kCalibrationMinHeard) {
    return LatencyNotHeard(estimate?.heardClicks ?? 0);
  }
  int us(int samples) => (samples * 1e6 / rate).round();
  final spreadUs = us(estimate.spreadSamples);
  if (spreadUs > kCalibrationMaxSpreadMs * 1000) {
    return LatencyUnsteady(spreadUs);
  }
  return LatencyMeasured(
    RouteLatency(
      roundTripUs: us(estimate.latencySamples),
      spreadUs: spreadUs,
      heardClicks: estimate.heardClicks,
      totalClicks: estimate.totalClicks,
      measuredAt: (at ?? DateTime.now()).toUtc(),
    ),
  );
}

/// Frames per beat of the calibration click stream.
int calibrationFramesPerBeat(int sampleRate) =>
    (sampleRate * 60 / kCalibrationBpm).round();

/// Median level of the chunks in dBFS (the guitar observer's room-floor rule:
/// median chunk RMS over its `calibrationMs` window).
double medianLevelDb(List<double> levels) {
  if (levels.isEmpty) return -120;
  final s = List<double>.of(levels)..sort();
  return s[s.length ~/ 2];
}

/// RMS level of one chunk in dBFS.
double chunkLevelDb(List<double> samples) {
  if (samples.isEmpty) return -120;
  var e = 0.0;
  for (final v in samples) {
    e += v * v;
  }
  return 20 *
      math.log(math.max(math.sqrt(e / samples.length), 1e-6)) /
      math.ln10;
}
