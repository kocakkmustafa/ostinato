import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ostinato_audio/ostinato_audio.dart';
import 'package:test/test.dart';

void main() {
  const sr = 48000;
  final click = LoopbackLatencyEstimator.click(sampleRate: sr);
  final clicks = [for (var k = 0; k < 8; k++) sr ~/ 2 + k * 28800];

  Float64List recording(int latency, {double noise = 0, int seed = 1}) {
    final y = Float64List(clicks.last + sr);
    final rng = math.Random(seed);
    for (final c in clicks) {
      for (var i = 0; i < click.length; i++) {
        y[c + latency + i] += 0.3 * click[i];
      }
    }
    for (var i = 0; i < y.length; i++) {
      y[i] += noise * (rng.nextDouble() * 2 - 1);
    }
    return y;
  }

  test('recovers an injected latency to the sample', () {
    for (final ms in [40, 120, 320]) {
      final lat = ms * sr ~/ 1000;
      final e = const LoopbackLatencyEstimator().estimate(recording(lat),
          template: click, clickTimes: clicks, maxLagSamples: sr ~/ 2)!;
      expect(e.latencySamples, lat);
      expect(e.heardClicks, 8);
      expect(e.spreadSamples, 0);
    }
  });

  test('declines when the clicks are not heard', () {
    final y = recording(0, noise: 0.2)..fillRange(0, 1, 0);
    final silent = Float64List(y.length);
    expect(
        const LoopbackLatencyEstimator().estimate(silent,
            template: click, clickTimes: clicks, maxLagSamples: sr ~/ 2),
        isNull);
  });

  test('median ignores one loud clap', () {
    final lat = 90 * sr ~/ 1000;
    final y = recording(lat, noise: 0.01);
    // A clap-like burst near the third click, louder than the click.
    for (var i = 0; i < click.length; i++) {
      y[clicks[2] + 2000 + i] += 0.9 * click[i];
    }
    final e = const LoopbackLatencyEstimator().estimate(y,
        template: click, clickTimes: clicks, maxLagSamples: sr ~/ 2)!;
    expect(e.latencySamples, lat);
  });

  test('first-arrival rule prefers the direct click over a cleaner echo', () {
    final lat = 60 * sr ~/ 1000;
    final y = recording(lat, noise: 0.002);
    // A weaker but clean reflection 25 ms later.
    for (final c in clicks) {
      for (var i = 0; i < click.length; i++) {
        y[c + lat + 1200 + i] += 0.12 * click[i];
      }
    }
    final e = const LoopbackLatencyEstimator(firstArrivalRatio: 0.5).estimate(
        y, template: click, clickTimes: clicks, maxLagSamples: sr ~/ 2)!;
    expect(e.latencySamples, lat);
  });
}
