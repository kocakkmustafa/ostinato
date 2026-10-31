// E49 — audio roadmap step 3 (rhythm / latency) in a simulated loop.
//
//   dart run tool/latency_sim.dart <spec.json> <out.jsonl> [k/n]
//
// No device: a known round-trip latency L is injected, the speaker clicks and
// the student's plucks go through the simulated phone channel, and the
// estimates are compared with the truth. This measures the algorithms only;
// the ±1 ms repeatability and ≤10 ms bias bars on a real phone cannot be
// checked here (no physical device, no first-party recording).
//
// Per trial (arm, condition, L, student bias β, seed):
//  1. Calibration: 8 clicks, recorded L later → LoopbackLatencyEstimator.
//  2. Lesson: 16 beats; the student plucks at the heard beat + β + jitter,
//     so the pluck reaches the recording at click + L + β + j; the click
//     itself also bleeds into the recording.
//  3. OnsetDetector on the lesson recording; arm M0 masks onsets within
//     ±15 ms of the predicted click arrival (the lesson contract's rule), arm
//     M1 uses a 6 kHz click above the detector's 4 kHz band and no mask.
//  4. Onsets are shifted by the detector offset δ (measured once on clean
//     plucks, spec `detectorOffsetUs`) and aligned with MetronomeAligner
//     against click + L̂. Error = median signed deviation − median(β + j).
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ostinato_audio/ostinato_audio.dart';

void main(List<String> args) {
  final spec =
      jsonDecode(File(args[0]).readAsStringSync()) as Map<String, dynamic>;
  final shard =
      args.length > 2 ? args[2].split('/').map(int.parse).toList() : [0, 1];
  final out = File(args[1]).openWrite();
  final sr = spec['sampleRate'] as int;
  final irs = [
    for (final p in (spec['irs'] as List? ?? const [])) readF32(p as String)
  ];
  final conds = (spec['conditions'] as List).cast<Map<String, dynamic>>();
  final arms = (spec['arms'] as List).cast<String>();
  final lats = (spec['latenciesMs'] as List).cast<int>();
  final biases = (spec['studentBiasMs'] as List).cast<int>();
  final seeds = spec['seeds'] as int;
  final seedBase = spec['seedBase'] as int;
  final jitterMs = (spec['jitterMs'] as num).toDouble();
  final bpm = (spec['bpm'] as num).toDouble();
  final beats = spec['beats'] as int;
  final bleedDb = (spec['clickBleedDb'] as num).toDouble();
  final deltaUs = spec['detectorOffsetUs'] as int? ?? 0;
  final sw = Stopwatch()..start();
  var job = 0, rows = 0;
  for (final arm in arms) {
    final hz = arm == 'M1' ? 6000.0 : 1500.0;
    final click = LoopbackLatencyEstimator.click(sampleRate: sr, hz: hz);
    for (final c in conds) {
      for (final lat in lats) {
        for (final beta in biases) {
          for (var s = 0; s < seeds; s++) {
            if (job++ % shard[1] != shard[0]) continue;
            final seed = seedBase + s;
            final row = trial(
                sr: sr,
                irs: irs,
                cond: c,
                arm: arm,
                click: click,
                latMs: lat,
                betaMs: beta,
                jitterMs: jitterMs,
                bpm: bpm,
                beats: beats,
                bleedDb: bleedDb,
                deltaUs: deltaUs,
                seed: seed);
            out.writeln(jsonEncode(row));
            rows++;
          }
        }
      }
    }
  }
  out.close();
  stderr.writeln('latency-sim shard ${shard[0]}/${shard[1]}: $rows rows '
      'in ${sw.elapsed.inSeconds}s');
}

Map<String, Object?> trial({
  required int sr,
  required List<Float64List> irs,
  required Map<String, dynamic> cond,
  required String arm,
  required Float64List click,
  required int latMs,
  required int betaMs,
  required double jitterMs,
  required double bpm,
  required int beats,
  required double bleedDb,
  required int deltaUs,
  required int seed,
}) {
  final rng = math.Random(seed * 7919 + latMs * 31 + betaMs);
  final lat = latMs * sr ~/ 1000;
  final period = (60 / bpm * sr).round();
  final lead = sr ~/ 2;

  // 1. Calibration clicks (no student).
  final calTimes = [for (var k = 0; k < 8; k++) lead + k * period];
  final cal = Float64List(calTimes.last + lat + sr);
  for (final t in calTimes) {
    _add(cal, click, t + lat, 0.25);
  }
  final calRec = _channel(cal, sr, cond, irs, seed);
  final est = const LoopbackLatencyEstimator().estimate(calRec,
      template: click, clickTimes: calTimes, maxLagSamples: sr ~/ 2);
  final latHat = est?.latencySamples;

  // 2. Lesson: plucks + click bleed.
  final beatTimes = [for (var k = 0; k < beats; k++) lead + k * period];
  final offsets = <double>[];
  final lesson = Float64List(beatTimes.last + lat + 2 * sr);
  final bleed = 0.5 * math.pow(10, bleedDb / 20).toDouble();
  for (var k = 0; k < beats; k++) {
    final j = _gauss(rng) * jitterMs;
    final offMs = betaMs + j;
    offsets.add(offMs);
    final at = beatTimes[k] + lat + (offMs * sr / 1000).round();
    final midi = 40 + rng.nextInt(25);
    final pluck = SyntheticString.pluck(
        f0Hz: 440 * math.pow(2, (midi - 69) / 12).toDouble(),
        sampleRate: sr,
        seconds: period / sr,
        seed: seed * 100 + k);
    _add(lesson, pluck, at, 1);
    _add(lesson, click, beatTimes[k] + lat, bleed / 0.5);
  }
  final rec = _channel(lesson, sr, cond, irs, seed + 1);

  // 3–4. Detect, mask (M0), align.
  if (latHat == null) {
    return {'arm': arm, 'cond': cond['name'], 'latMs': latMs, 'betaMs': betaMs,
        'seed': seed, 'calHeard': false};
  }
  var onsets = const OnsetDetector().detect(rec, sampleRate: sr, tStartUs: 0);
  final predicted = [for (final t in beatTimes) (t + latHat) * 1e6 / sr];
  if (arm == 'M0') {
    onsets = [
      for (final o in onsets)
        if (predicted.every((p) => (o.tUs - p).abs() > 15000)) o
    ];
  }
  final shifted = [
    for (final o in onsets) Onset(tUs: o.tUs - deltaUs, strength: o.strength)
  ];
  final report = const MetronomeAligner().align(
      onsets: shifted, beatTimesUs: [for (final p in predicted) p.round()]);
  final signed = [for (final d in report.deviations) d.deviationMs]..sort();
  final measured = signed.isEmpty ? null : signed[signed.length ~/ 2];
  final truth = List.of(offsets)..sort();
  final truthMedian = truth[truth.length ~/ 2];
  return {
    'arm': arm,
    'cond': cond['name'],
    'latMs': latMs,
    'betaMs': betaMs,
    'seed': seed,
    'calHeard': true,
    'latHatMs': latHat * 1000 / sr,
    'calErrMs': (latHat - lat) * 1000 / sr,
    'calHeardClicks': est!.heardClicks,
    'calSpreadMs': est.spreadSamples * 1000 / sr,
    'coverage': report.coverage,
    'measuredBiasMs': measured,
    'truthBiasMs': truthMedian,
    'biasErrMs': measured == null ? null : measured - truthMedian,
    'medianAbsMs': report.medianMs,
  };
}

void _add(Float64List y, List<double> x, int at, double gain) {
  for (var i = 0; i < x.length; i++) {
    final j = at + i;
    if (j >= 0 && j < y.length) y[j] += gain * x[i];
  }
}

double _gauss(math.Random r) {
  final u = math.max(1e-12, r.nextDouble());
  return math.sqrt(-2 * math.log(u)) * math.cos(2 * math.pi * r.nextDouble());
}

Float64List _channel(Float64List x, int sr, Map<String, dynamic> c,
    List<Float64List> irs, int seed) {
  if (c['clean'] == true) return x;
  final ir = (c['reverb'] as bool? ?? false) && irs.isNotEmpty
      ? irs[seed % irs.length]
      : null;
  return PhoneChannel.apply(
      x,
      sr,
      PhoneChannelConfig(
        name: c['name'] as String,
        impulseResponse: ir,
        directToReverbDb: (c['drrDb'] as num? ?? 6).toDouble(),
        noise: ChannelNoise.values.byName(c['noise'] as String? ?? 'none'),
        snrDb: (c['snrDb'] as num? ?? 60).toDouble(),
        lowCutHz: (c['lowCutHz'] as num?)?.toDouble(),
        lowCutOrder: c['lowCutOrder'] as int? ?? 2,
        agc: c['agc'] as bool? ?? false,
      ),
      seed: seed);
}

Float64List readF32(String path) {
  final b = File(path).readAsBytesSync();
  final f = b.buffer.asFloat32List(b.offsetInBytes, b.lengthInBytes ~/ 4);
  return Float64List.fromList(f);
}
