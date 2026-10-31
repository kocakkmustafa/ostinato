import 'dart:math' as math;
import 'dart:typed_data';

import '../dsp/fft.dart';

/// Noise added at the microphone. All generated here from a seed: no
/// recorded noise is shipped or needed, so there is no licence chain.
enum ChannelNoise { none, white, pink, brown, hum }

/// One simulated phone capture path. This is an *evaluation* tool: it lets
/// the engine be stressed with the failure modes a phone adds, before any
/// phone has been measured. It is not a model of any particular device and
/// its outputs prove robustness only to these specific, synthetic effects.
///
/// Stages, in physical order:
/// 1. room: convolution with [impulseResponse], tail rescaled so the
///    direct-to-reverberant ratio is [directToReverbDb];
/// 2. ambient noise at [snrDb] relative to the note's active level;
/// 3. microphone/OS low cut: Butterworth high-pass, [lowCutHz], [lowCutOrder]
///    (Android CDD allows up to −20 dB at 30–100 Hz on `VOICE_RECOGNITION`);
/// 4. AGC (slow level riding) and a fast compressor, then a soft limiter;
/// 5. 16-bit quantisation.
///
/// The sample rate is whatever the caller passes; the E36 harness uses
/// 48 kHz throughout, and [impulseResponse] must already be at that rate.
final class PhoneChannelConfig {
  const PhoneChannelConfig({
    this.name = 'clean',
    this.impulseResponse,
    this.directToReverbDb = 6,
    this.noise = ChannelNoise.none,
    this.snrDb = 60,
    this.lowCutHz,
    this.lowCutOrder = 2,
    this.agc = false,
    this.agcTargetDb = -20,
    this.agcMaxGainDb = 30,
    this.agcTimeSeconds = 0.4,
    this.compressorThresholdDb = -24,
    this.compressorRatio = 4,
    this.compressorAttackMs = 5,
    this.compressorReleaseMs = 150,
    this.quantize16 = true,
  });

  final String name;
  final List<double>? impulseResponse;
  final double directToReverbDb;
  final ChannelNoise noise;
  final double snrDb;
  final double? lowCutHz;
  final int lowCutOrder;
  final bool agc;
  final double agcTargetDb, agcMaxGainDb, agcTimeSeconds;
  final double compressorThresholdDb, compressorRatio;
  final double compressorAttackMs, compressorReleaseMs;
  final bool quantize16;
}

final class PhoneChannel {
  const PhoneChannel._();

  static Float64List apply(
    List<double> input,
    int sampleRate,
    PhoneChannelConfig config, {
    int seed = 1,
  }) {
    if (sampleRate <= 0) throw ArgumentError('Invalid sample rate');
    var x = Float64List.fromList(input);
    final ir = config.impulseResponse;
    if (ir != null && ir.isNotEmpty) {
      final shaped =
          shapeImpulseResponse(ir, sampleRate, config.directToReverbDb);
      final wet = fftConvolve(x, shaped.ir);
      // Remove the direct-path delay so note timing is unchanged.
      final y = Float64List(x.length);
      for (var i = 0; i < y.length; i++) {
        final j = i + shaped.directIndex;
        y[i] = j < wet.length ? wet[j] : 0;
      }
      x = y;
    }
    if (config.noise != ChannelNoise.none) {
      final noise = generateNoise(config.noise, x.length, sampleRate, seed);
      final sig = activeRms(x, sampleRate);
      final nr = _rms(noise);
      if (sig > 0 && nr > 0) {
        final g = sig / nr / math.pow(10, config.snrDb / 20);
        for (var i = 0; i < x.length; i++) {
          x[i] += g * noise[i];
        }
      }
    }
    final fc = config.lowCutHz;
    if (fc != null) {
      x = butterworthHighPass(x, sampleRate, fc, config.lowCutOrder);
    }
    if (config.agc) {
      x = _agcAndCompress(x, sampleRate, config);
    }
    for (var i = 0; i < x.length; i++) {
      x[i] = _softLimit(x[i]);
    }
    if (config.quantize16) {
      for (var i = 0; i < x.length; i++) {
        x[i] = (x[i] * 32767).roundToDouble() / 32767;
      }
    }
    return x;
  }

  /// The room floor the app would calibrate before the note (E44): the same
  /// noise as [apply] would add to [reference] (level set by the note's active
  /// RMS and [PhoneChannelConfig.snrDb]), but with no note, through the same
  /// low cut / AGC / limiter / quantiser, for [seconds]; returned as the median
  /// of per-chunk RMS in dBFS. Mirrors `GuitarNoteObservationController`
  /// calibration (median chunk level over `calibrationMs` = 2000; iOS tap
  /// chunks are 2048 samples).
  static double noiseFloorDb(
    List<double> reference,
    int sampleRate,
    PhoneChannelConfig config, {
    int seed = 1,
    double seconds = 2,
    int chunk = 2048,
  }) {
    final n = (seconds * sampleRate).round();
    var x = Float64List(n);
    if (config.noise != ChannelNoise.none) {
      var ref = Float64List.fromList(reference);
      final ir = config.impulseResponse;
      if (ir != null && ir.isNotEmpty) {
        final shaped =
            shapeImpulseResponse(ir, sampleRate, config.directToReverbDb);
        final wet = fftConvolve(ref, shaped.ir);
        ref = Float64List.fromList(
            wet.sublist(shaped.directIndex, shaped.directIndex + ref.length));
      }
      final noise = generateNoise(config.noise, n, sampleRate, seed);
      final sig = activeRms(ref, sampleRate);
      final nr = _rms(noise);
      if (sig > 0 && nr > 0) {
        final g = sig / nr / math.pow(10, config.snrDb / 20);
        for (var i = 0; i < n; i++) {
          x[i] = g * noise[i];
        }
      }
    }
    final fc = config.lowCutHz;
    if (fc != null) {
      x = butterworthHighPass(x, sampleRate, fc, config.lowCutOrder);
    }
    if (config.agc) x = _agcAndCompress(x, sampleRate, config);
    for (var i = 0; i < n; i++) {
      x[i] = _softLimit(x[i]);
      if (config.quantize16) {
        x[i] = (x[i] * 32767).roundToDouble() / 32767;
      }
    }
    final levels = <double>[];
    for (var s = 0; s + chunk <= n; s += chunk) {
      var e = 0.0;
      for (var i = s; i < s + chunk; i++) {
        e += x[i] * x[i];
      }
      levels
          .add(20 * math.log(math.max(math.sqrt(e / chunk), 1e-9)) / math.ln10);
    }
    levels.sort();
    return levels.isEmpty ? -180 : levels[levels.length ~/ 2];
  }

  /// Splits an IR into direct path (±2.5 ms around its peak) and tail, and
  /// rescales the tail so direct/tail energy equals [drrDb].
  static ({Float64List ir, int directIndex}) shapeImpulseResponse(
    List<double> ir,
    int sampleRate,
    double drrDb,
  ) {
    var peak = 0;
    for (var i = 1; i < ir.length; i++) {
      if (ir[i].abs() > ir[peak].abs()) peak = i;
    }
    final half = (0.0025 * sampleRate).round();
    var direct = 0.0, tail = 0.0;
    for (var i = 0; i < ir.length; i++) {
      final e = ir[i] * ir[i];
      if ((i - peak).abs() <= half) {
        direct += e;
      } else if (i > peak) {
        tail += e;
      }
    }
    final out = Float64List(ir.length);
    final norm = direct > 0 ? 1 / math.sqrt(direct) : 1.0;
    final tailGain = tail > 0 && direct > 0
        ? math.sqrt(direct / tail / math.pow(10, drrDb / 10))
        : 0.0;
    for (var i = 0; i < ir.length; i++) {
      final isDirect = (i - peak).abs() <= half;
      if (isDirect) {
        out[i] = ir[i] * norm;
      } else if (i > peak) {
        out[i] = ir[i] * norm * tailGain;
      }
    }
    return (ir: out, directIndex: peak);
  }

  /// RMS over 20 ms frames within 20 dB of the loudest frame: the level of
  /// the note itself, independent of how much silence surrounds it.
  static double activeRms(List<double> x, int sampleRate) {
    final frame = math.max(1, (0.02 * sampleRate).round());
    final energies = <double>[];
    for (var s = 0; s + frame <= x.length; s += frame) {
      var e = 0.0;
      for (var i = s; i < s + frame; i++) {
        e += x[i] * x[i];
      }
      energies.add(e / frame);
    }
    if (energies.isEmpty) return _rms(x);
    final maxE = energies.reduce(math.max);
    if (maxE <= 0) return 0;
    final keep = energies.where((e) => e >= maxE / 100).toList();
    return math.sqrt(keep.reduce((a, b) => a + b) / keep.length);
  }

  static Float64List generateNoise(
    ChannelNoise kind,
    int length,
    int sampleRate,
    int seed,
  ) {
    final rng = math.Random(seed * 7919 + kind.index);
    final out = Float64List(length);
    double white() => rng.nextDouble() * 2 - 1;
    switch (kind) {
      case ChannelNoise.none:
        break;
      case ChannelNoise.white:
        for (var i = 0; i < length; i++) {
          out[i] = white();
        }
      case ChannelNoise.pink:
        _pink(out, white);
      case ChannelNoise.brown:
        var b = 0.0;
        for (var i = 0; i < length; i++) {
          b = 0.995 * b + 0.05 * white();
          out[i] = b;
        }
      case ChannelNoise.hum:
        // Mains hum with harmonics (fridge/HVAC/ballast) over pink room tone.
        final mains = rng.nextBool() ? 50.0 : 60.0;
        final phases = [for (var k = 0; k < 6; k++) rng.nextDouble() * 6.283];
        const levels = [1.0, 0.6, 0.45, 0.3, 0.2, 0.15];
        final bed = Float64List(length);
        _pink(bed, white);
        final bedRms = _rms(bed);
        for (var i = 0; i < length; i++) {
          final t = i / sampleRate;
          var h = 0.0;
          for (var k = 0; k < levels.length; k++) {
            h += levels[k] *
                math.sin(2 * math.pi * mains * (k + 1) * t + phases[k]);
          }
          out[i] = h + (bedRms > 0 ? 0.5 * bed[i] / bedRms : 0);
        }
    }
    return out;
  }

  /// Paul Kellet's economy pink filter.
  static void _pink(Float64List out, double Function() white) {
    var b0 = 0.0, b1 = 0.0, b2 = 0.0;
    for (var i = 0; i < out.length; i++) {
      final w = white();
      b0 = 0.99765 * b0 + w * 0.0990460;
      b1 = 0.96300 * b1 + w * 0.2965164;
      b2 = 0.57000 * b2 + w * 1.0526913;
      out[i] = b0 + b1 + b2 + w * 0.1848;
    }
  }

  /// Butterworth high-pass as cascaded RBJ biquads (order 2 or 4).
  static Float64List butterworthHighPass(
    List<double> x,
    int sampleRate,
    double cutoffHz,
    int order,
  ) {
    final qs = switch (order) {
      2 => const [0.7071067811865476],
      4 => const [0.5411961001461970, 1.3065629648763766],
      _ => throw ArgumentError('Order must be 2 or 4'),
    };
    var y = Float64List.fromList(x);
    for (final q in qs) {
      final w0 = 2 * math.pi * cutoffHz / sampleRate;
      final alpha = math.sin(w0) / (2 * q);
      final cw = math.cos(w0);
      final a0 = 1 + alpha;
      final b0 = (1 + cw) / 2 / a0, b1 = -(1 + cw) / a0, b2 = (1 + cw) / 2 / a0;
      final a1 = -2 * cw / a0, a2 = (1 - alpha) / a0;
      var x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0;
      final next = Float64List(y.length);
      for (var i = 0; i < y.length; i++) {
        final xi = y[i];
        final yi = b0 * xi + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2;
        x2 = x1;
        x1 = xi;
        y2 = y1;
        y1 = yi;
        next[i] = yi;
      }
      y = next;
    }
    return y;
  }

  static Float64List _agcAndCompress(
    Float64List x,
    int sampleRate,
    PhoneChannelConfig c,
  ) {
    final out = Float64List(x.length);
    final agcCoef = math.exp(-1 / (c.agcTimeSeconds * sampleRate));
    final att = math.exp(-1 / (c.compressorAttackMs / 1000 * sampleRate));
    final rel = math.exp(-1 / (c.compressorReleaseMs / 1000 * sampleRate));
    // Start the AGC at the target so the first note is not artificially loud.
    var meanSquare = math.pow(10, c.agcTargetDb / 10).toDouble();
    var env = 0.0;
    for (var i = 0; i < x.length; i++) {
      meanSquare = agcCoef * meanSquare + (1 - agcCoef) * x[i] * x[i];
      final levelDb = 10 * math.log(math.max(meanSquare, 1e-12)) / math.ln10;
      final agcGainDb = (c.agcTargetDb - levelDb).clamp(-30.0, c.agcMaxGainDb);
      var y = x[i] * math.pow(10, agcGainDb / 20);
      final a = y.abs();
      env = a > env ? att * env + (1 - att) * a : rel * env + (1 - rel) * a;
      final envDb = 20 * math.log(math.max(env, 1e-9)) / math.ln10;
      final over = envDb - c.compressorThresholdDb;
      if (over > 0) {
        y *= math.pow(10, -over * (1 - 1 / c.compressorRatio) / 20);
      }
      out[i] = y;
    }
    return out;
  }

  static double _softLimit(double v) {
    const knee = 0.8;
    final a = v.abs();
    if (a <= knee) return v;
    final limited = knee + (1 - knee) * _tanh((a - knee) / (1 - knee));
    return v < 0 ? -limited : limited;
  }

  static double _tanh(double v) {
    if (v > 20) return 1;
    final e = math.exp(2 * v);
    return (e - 1) / (e + 1);
  }

  static double _rms(List<double> x) {
    if (x.isEmpty) return 0;
    var s = 0.0;
    for (final v in x) {
      s += v * v;
    }
    return math.sqrt(s / x.length);
  }
}
