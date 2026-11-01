import 'dart:math' as math;
import 'dart:typed_data';

import '../dsp/fft.dart';

/// Round-trip (speaker → room → microphone) latency from a known click train.
///
/// Step 3 of the audio roadmap. The app schedules [clickTimes] (samples, on
/// the capture clock), plays [template] at each one and records; the click
/// reaches the recording `latency` samples later. For every click the lag in
/// `[0, maxLagSamples]` with the highest normalised cross-correlation is
/// taken; the estimate is the median over clicks, so one clap or cough does
/// not move it. Clicks whose best correlation is below [minCorrelation] are
/// treated as not heard.
///
/// The template is high-band (above the onset detector's analysis band) so
/// the same clicks can keep playing during a lesson without being counted as
/// the student's notes (E49 arm M1).
final class LoopbackLatencyEstimator {
  const LoopbackLatencyEstimator(
      {this.minCorrelation = 0.3, this.firstArrivalRatio});

  final double minCorrelation;

  /// E50: when set, the lag is the **earliest** one whose raw (unnormalised)
  /// correlation reaches this share of the window's raw maximum, instead of
  /// the normalised maximum. Normalised correlation ignores amplitude, so in
  /// a reverberant room it can lock onto a reflection (E49: 97 % of the Q
  /// errors were late). The heard check still uses [minCorrelation] on the
  /// chosen lag's normalised value.
  final double? firstArrivalRatio;

  /// Median lag in samples, or null when fewer than half the clicks were
  /// heard.
  LatencyEstimate? estimate(
    List<double> recording, {
    required List<double> template,
    required List<int> clickTimes,
    required int maxLagSamples,
  }) {
    if (template.isEmpty || clickTimes.isEmpty) return null;
    var tEnergy = 0.0;
    for (final v in template) {
      tEnergy += v * v;
    }
    if (tEnergy <= 0) return null;
    final lags = <int>[];
    final reversed = template.reversed.toList();
    for (final c in clickTimes) {
      final a = math.max(0, c);
      final b = math.min(recording.length, c + maxLagSamples + template.length);
      if (b - a < template.length) continue;
      final seg = recording.sublist(a, b);
      // Cross-correlation via FFT; conv[i + n - 1] = Σ seg[i + k]·template[k].
      final conv = fftConvolve(seg, reversed);
      final prefix = Float64List(seg.length + 1);
      for (var i = 0; i < seg.length; i++) {
        prefix[i + 1] = prefix[i] + seg[i] * seg[i];
      }
      var best = -1.0;
      var bestLag = -1;
      final n = template.length;
      double norm(int i) {
        final e = prefix[i + n] - prefix[i];
        return e <= 0 ? 0 : conv[i + n - 1] / math.sqrt(e * tEnergy);
      }

      final ratio = firstArrivalRatio;
      if (ratio == null) {
        for (var i = 0; i + n <= seg.length; i++) {
          final r = norm(i);
          if (r > best) {
            best = r;
            bestLag = a + i - c;
          }
        }
      } else {
        var rawMax = 0.0;
        for (var i = 0; i + n <= seg.length; i++) {
          rawMax = math.max(rawMax, conv[i + n - 1]);
        }
        for (var i = 0; rawMax > 0 && i + n <= seg.length; i++) {
          if (conv[i + n - 1] < ratio * rawMax) continue;
          // Earliest qualifying lag; the arrival's peak lies within one
          // template length (the burst's correlation main lobe).
          var j = i;
          for (var k = i + 1; k <= i + n && k + n <= seg.length; k++) {
            if (conv[k + n - 1] > conv[j + n - 1]) j = k;
          }
          best = norm(j);
          bestLag = a + j - c;
          break;
        }
      }
      if (bestLag >= 0 && best >= minCorrelation) lags.add(bestLag);
    }
    if (lags.length * 2 < clickTimes.length) return null;
    lags.sort();
    final median = lags[lags.length ~/ 2];
    return LatencyEstimate(
      latencySamples: median,
      heardClicks: lags.length,
      totalClicks: clickTimes.length,
      spreadSamples: lags.last - lags.first,
    );
  }

  /// A short Hann-windowed tone burst; [hz] above the onset detector's
  /// analysis band (4 kHz) keeps it out of note detection.
  static Float64List click(
      {required int sampleRate, double hz = 6000, double ms = 4, double peak = 0.5}) {
    final n = (ms * sampleRate / 1000).round();
    final out = Float64List(n);
    for (var i = 0; i < n; i++) {
      final w = 0.5 - 0.5 * math.cos(2 * math.pi * i / (n - 1));
      out[i] = peak * w * math.sin(2 * math.pi * hz * i / sampleRate);
    }
    return out;
  }
}

final class LatencyEstimate {
  const LatencyEstimate({
    required this.latencySamples,
    required this.heardClicks,
    required this.totalClicks,
    required this.spreadSamples,
  });

  final int latencySamples;
  final int heardClicks, totalClicks;

  /// Max − min of the per-click lags: a large spread means echoes or a
  /// changing route, and the calibration should be repeated.
  final int spreadSamples;
}
