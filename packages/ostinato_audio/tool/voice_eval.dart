// E54 — audio roadmap step A5 (voice pitch) offline harness.
//
//   dart run tool/voice_eval.dart render <spec.json> <outDir> [k/n] [--only <jobId>]
//   dart run tool/voice_eval.dart gt     <spec.json> <outDir>
//
// No engine change: the shipped `YinPitchSource` and `PhoneChannel` are used
// as they are. Per job (item × condition × seed) the harness
//  1. builds the clean input (a prepared f32 file, a resynthesis of a ground
//     truth f0 curve, the synthetic voice set, or a noise-only clip),
//  2. applies the simulated phone channel with the E36 rule
//     (`EvalContext.render`, IR = irs[renderSeed % irs.length]),
//  3. dumps the render as f32 LE with its sha256 (the model arms read exactly
//     these bytes; PLAN §3, §7.4),
//  4. runs arm Y0 (`YinPitchSource(55, 1200, 0.15)`, no prior) on the 92.9 ms
//     / 23.2 ms frame grid — frames whose centre lies in a note interior, or
//     the whole track when the job asks for it — and arm Y1 (same + the
//     note's target as `expectedHzPrior`) on the A2 note interiors, once per
//     target.
//
// Y1 cost: the prior only post-processes YIN's estimate, so Y1 is derived
// from the Y0 frame with the engine's own rule (`applyPriorLikeEngine`);
// frames Y0 rejected only by its range check are recomputed with the real
// prior-carrying `YinPitchSource`, and every `y1CheckEvery`-th derived frame
// is recomputed the same way and compared bit for bit (mismatch count goes to
// the output; metrics_e54.py requires 0). test/voice_eval_test.dart proves the
// equivalence on synthetic windows.
//
// Output (outDir): frames-<k>.jsonl (one Y0 row and one Y1 row per job),
// manifest-<k>.jsonl (render path, sha256, floor, seeds, timing).
// Deterministic for a given spec: no clock or platform hash enters a value.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ostinato_audio/ostinato_audio.dart';

import 'audio_eval.dart' show Condition, EvalContext, readF32, stableHash;

void main(List<String> args) {
  if (args.length < 3) {
    stderr.writeln('usage: voice_eval.dart <render|gt> <spec> <outDir> '
        '[k/n] [--only <jobId>]');
    exit(64);
  }
  final spec =
      jsonDecode(File(args[1]).readAsStringSync()) as Map<String, dynamic>;
  final outDir = Directory(args[2])..createSync(recursive: true);
  switch (args[0]) {
    case 'render':
      var shard = [0, 1];
      String? only;
      for (var i = 3; i < args.length; i++) {
        if (args[i] == '--only') {
          only = args[++i];
        } else {
          shard = args[i].split('/').map(int.parse).toList();
        }
      }
      runRender(spec, outDir.path, shard, only);
    case 'gt':
      runGt(spec, outDir.path);
    default:
      stderr.writeln('unknown command ${args[0]}');
      exit(64);
  }
}

// ---------------------------------------------------------------------------
// Frame recipe (PLAN §2, §3): voice@0.2.0-draft window 92.9 ms, hop 23.2 ms.

final class FrameGrid {
  FrameGrid(this.sampleRate, double winMs, double hopMs)
      : win = (winMs / 1000 * sampleRate).round(),
        hop = (hopMs / 1000 * sampleRate).round();
  final int sampleRate, win, hop;

  /// Centre (s) of frame k: samples [k·hop, k·hop + win).
  double centre(int k) => (k * hop + win / 2) / sampleRate;

  /// Frames fully inside n samples whose centre is in one of [intervals]
  /// (closed), or all of them when [intervals] is null.
  List<int> frames(int n, List<List<double>>? intervals) {
    final out = <int>[];
    for (var k = 0; k * hop + win <= n; k++) {
      if (intervals == null || inAny(centre(k), intervals)) out.add(k);
    }
    return out;
  }
}

bool inAny(double t, List<List<double>> intervals) {
  for (final iv in intervals) {
    if (t >= iv[0] && t <= iv[1]) return true;
  }
  return false;
}

/// The engine's `expectedHzPrior` post-processing (yin.dart: octave snap with
/// a 100-cent residual check, tolerance reject, then the range check),
/// applied to the estimate the same YIN produced without a prior. Valid only
/// for frames where the prior-free source returned a non-null f0 (raw f0
/// inside the range); see the header for the other cases.
double? applyPriorLikeEngine(double f0, double prior,
    {required double minHz,
    required double maxHz,
    required double priorToleranceCents}) {
  double absCents(double a, double b) =>
      (1200 * math.log(a / b) / math.ln2).abs();
  var f = f0;
  final octavesExact = math.log(f / prior) / math.ln2;
  final octaves = octavesExact.round();
  if (octaves != 0 && (octavesExact - octaves).abs() * 1200 <= 100.0) {
    final snapped = f / math.pow(2, octaves);
    if (absCents(snapped, prior) < absCents(f, prior)) f = snapped.toDouble();
  }
  if (absCents(f, prior) > priorToleranceCents) return null;
  if (f < minHz || f > maxHz) return null;
  return f;
}

// ---------------------------------------------------------------------------
// Signals.

const defaultPartials = [0.5, 1.0, 0.8, 0.5, 0.35, 0.25, 0.18, 0.12];

/// `SyntheticTone.harmonic` with a time-varying fundamental [f0At] (Hz at
/// time t seconds from the note start). Same partial template, attack ramp,
/// uniform noise and peak normalisation, same RNG call order — with a
/// constant curve it is bit-identical to `SyntheticTone.harmonic` (test).
List<double> harmonicCurve({
  required double Function(double t) f0At,
  required int sampleRate,
  required double seconds,
  List<double> partials = defaultPartials,
  double attackSeconds = 0.12,
  double noiseAmplitude = 0.02,
  int seed = 42,
}) {
  final n = (sampleRate * seconds).round();
  final rng = math.Random(seed);
  final out = List<double>.filled(n, 0);
  var phase = 0.0;
  for (var i = 0; i < n; i++) {
    final t = i / sampleRate;
    phase += 2 * math.pi * f0At(t) / sampleRate;
    var sample = 0.0;
    for (var k = 0; k < partials.length; k++) {
      sample += partials[k] * math.sin((k + 1) * phase);
    }
    final env = attackSeconds <= 0 ? 1.0 : math.min(1.0, t / attackSeconds);
    sample *= env;
    sample += noiseAmplitude * (rng.nextDouble() * 2 - 1);
    out[i] = sample;
  }
  var peak = 0.0;
  for (final v in out) {
    peak = math.max(peak, v.abs());
  }
  return peak == 0 ? out : [for (final v in out) v / peak];
}

double midiHz(num midi) => 440 * math.pow(2, (midi - 69) / 12).toDouble();

/// Synthetic voice note f0 (PLAN §4): style flat / vib (5.5 Hz ±50 c) /
/// scoopvib (−80 c → 0 linearly over 150 ms, plus 5.5 Hz ±30 c vibrato).
/// [t] is seconds from the note start.
double synthNoteHz(String style, int midi, double shiftCents, double t) {
  final base = midiHz(midi) * math.pow(2, shiftCents / 1200);
  switch (style) {
    case 'flat':
      return base;
    case 'vib':
      // Exactly SyntheticTone.harmonic's vibrato expression.
      return base * math.pow(2, (50 / 1200) * math.sin(2 * math.pi * 5.5 * t));
    case 'scoopvib':
      final scoop = t < 0.15 ? -80 * (1 - t / 0.15) : 0.0;
      final vib = 30 * math.sin(2 * math.pi * 5.5 * t);
      return base * math.pow(2, (scoop + vib) / 1200);
  }
  throw ArgumentError('unknown style $style');
}

/// One synthetic note's samples: flat / vib through `SyntheticTone.harmonic`,
/// scoopvib through [harmonicCurve]; then a 20 ms linear fade-out (no
/// offset click) and gain [gain].
List<double> synthNote(Map<String, dynamic> note, int sr,
    {double seconds = 2.0, double gain = 0.5}) {
  final style = note['style'] as String;
  final midi = note['midi'] as int;
  final shift = (note['shift'] as num).toDouble();
  final seed = note['seed'] as int;
  final base = midiHz(midi) * math.pow(2, shift / 1200);
  final x = switch (style) {
    'flat' => SyntheticTone.harmonic(
        f0Hz: base, sampleRate: sr, seconds: seconds, seed: seed),
    'vib' => SyntheticTone.harmonic(
        f0Hz: base,
        sampleRate: sr,
        seconds: seconds,
        vibratoHz: 5.5,
        vibratoCents: 50,
        seed: seed),
    _ => harmonicCurve(
        f0At: (t) => synthNoteHz(style, midi, shift, t),
        sampleRate: sr,
        seconds: seconds,
        seed: seed),
  };
  final fade = (0.02 * sr).round();
  return [
    for (var i = 0; i < x.length; i++)
      x[i] * gain * math.min(1.0, (x.length - i) / fade)
  ];
}

/// Synthetic track: notes placed at their `start` (s) in silence.
Float64List synthTrack(Map<String, dynamic> item, int sr) {
  final y = Float64List((((item['seconds'] as num).toDouble()) * sr).round());
  for (final n in (item['notes'] as List).cast<Map<String, dynamic>>()) {
    final s0 = ((n['start'] as num).toDouble() * sr).round();
    final x = synthNote(n, sr, seconds: (n['seconds'] as num).toDouble());
    for (var i = 0; i < x.length && s0 + i < y.length; i++) {
      y[s0 + i] += x[i];
    }
  }
  return y;
}

/// Synthetic track ground truth on a fixed grid [hopS]: the generating curve
/// itself (0 Hz outside notes).
({List<double> t, List<double> hz}) synthTrackGt(
    Map<String, dynamic> item, int sr, double hopS) {
  final total = (item['seconds'] as num).toDouble();
  final notes = (item['notes'] as List).cast<Map<String, dynamic>>();
  final t = <double>[], hz = <double>[];
  for (var k = 0; k * hopS < total; k++) {
    final tk = k * hopS;
    var f = 0.0;
    for (final n in notes) {
      final s0 = ((n['start'] as num).toDouble() * sr).round() / sr;
      final dur = (n['seconds'] as num).toDouble();
      if (tk >= s0 && tk < s0 + dur) {
        f = synthNoteHz(n['style'] as String, n['midi'] as int,
            (n['shift'] as num).toDouble(), tk - s0);
      }
    }
    t.add(tk);
    hz.add(f);
  }
  return (t: t, hz: hz);
}

/// Resynthesis of a ground-truth f0 curve (PLAN §4 "vocadito-resentez"):
/// fixed partial template, f0 linear in cents between consecutive voiced GT
/// frames (held across unvoiced ones), amplitude = linear interpolation of the
/// GT voicing gate (silent where GT is unvoiced). At every GT frame time the
/// instantaneous f0 equals the GT value exactly.
Float64List resynth(List<double> gtT, List<double> gtHz, int n, int sr,
    {List<double> partials = defaultPartials, double peak = 0.5}) {
  final y = Float64List(n);
  if (gtT.isEmpty) return y;
  final norm = peak / partials.reduce((a, b) => a + b);
  var phase = 0.0;
  var k = 0;
  double? lastHz;
  for (var i = 0; i < n; i++) {
    final t = i / sr;
    while (k + 1 < gtT.length && gtT[k + 1] <= t) {
      k++;
    }
    final h0 = gtHz[k];
    final hasNext = k + 1 < gtT.length;
    final h1 = hasNext ? gtHz[k + 1] : 0.0;
    final u = hasNext && t >= gtT[k]
        ? ((t - gtT[k]) / (gtT[k + 1] - gtT[k])).clamp(0.0, 1.0)
        : 0.0;
    final g0 = h0 > 0 && t >= gtT[k] ? 1.0 : 0.0;
    final g1 = h1 > 0 ? 1.0 : 0.0;
    final amp = hasNext ? g0 + (g1 - g0) * u : g0;
    double? f;
    if (h0 > 0 && h1 > 0) {
      f = h0 * math.pow(h1 / h0, u);
    } else if (h0 > 0) {
      f = h0;
    } else if (h1 > 0) {
      f = h1;
    }
    f ??= lastHz;
    if (f == null) continue;
    lastHz = f;
    phase += 2 * math.pi * f / sr;
    if (amp == 0) continue;
    var s = 0.0;
    for (var p = 0; p < partials.length; p++) {
      if ((p + 1) * f >= sr / 2) break;
      s += partials[p] * math.sin((p + 1) * phase);
    }
    y[i] = amp * norm * s;
  }
  return y;
}

/// Noise-only clip (PLAN §4): no voice; the channel's noise at the level the
/// note [ref] would set (`PhoneChannel.noiseFloorDb`'s rule: IR applied to the
/// reference, active RMS, snrDb), then the same low cut / AGC / limiter /
/// quantiser via `PhoneChannel.apply` with noise and IR off.
Float64List noiseOnlyRender(
    EvalContext ctx, List<double> ref, int n, Condition c, int seed) {
  if (c.clean || c.noise == ChannelNoise.none) return Float64List(n);
  final sr = ctx.sampleRate;
  final ir =
      c.reverb && ctx.irs.isNotEmpty ? ctx.irs[seed % ctx.irs.length] : null;
  var r = Float64List.fromList(ref);
  if (ir != null) {
    final shaped = PhoneChannel.shapeImpulseResponse(ir, sr, c.drrDb);
    final wet = fftConvolve(r, shaped.ir);
    r = Float64List.fromList(
        wet.sublist(shaped.directIndex, shaped.directIndex + r.length));
  }
  final noise = PhoneChannel.generateNoise(c.noise, n, sr, seed);
  final sig = PhoneChannel.activeRms(r, sr);
  var e = 0.0;
  for (final v in noise) {
    e += v * v;
  }
  final nr = math.sqrt(e / n);
  final x = Float64List(n);
  if (sig > 0 && nr > 0) {
    final g = sig / nr / math.pow(10, c.snrDb / 20);
    for (var i = 0; i < n; i++) {
      x[i] = g * noise[i];
    }
  }
  return PhoneChannel.apply(
      x,
      sr,
      PhoneChannelConfig(
          name: c.name,
          lowCutHz: c.lowCutHz,
          lowCutOrder: c.lowCutOrder,
          agc: c.agc),
      seed: seed);
}

// ---------------------------------------------------------------------------
// SHA-256 (FIPS 180-4). The package has no runtime dependencies and the
// harness must hash its renders itself (PLAN §7.4).

const _k256 = [
  0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, //
  0x923f82a4, 0xab1c5ed5, 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
  0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174, 0xe49b69c1, 0xefbe4786,
  0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
  0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147,
  0x06ca6351, 0x14292967, 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
  0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, 0xa2bfe8a1, 0xa81a664b,
  0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
  0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a,
  0x5b9cca4f, 0x682e6ff3, 0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
  0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
];

String sha256Hex(Uint8List data) {
  final h = Uint32List.fromList([
    0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, //
    0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
  ]);
  final bitLen = data.length * 8;
  final padLen = ((data.length + 9 + 63) ~/ 64) * 64;
  final m = Uint8List(padLen)..setRange(0, data.length, data);
  m[data.length] = 0x80;
  final bd = ByteData.sublistView(m);
  bd.setUint32(padLen - 8, (bitLen ~/ 0x100000000) & 0xffffffff);
  bd.setUint32(padLen - 4, bitLen & 0xffffffff);
  final w = Uint32List(64);
  int rotr(int x, int n) => ((x >> n) | (x << (32 - n))) & 0xffffffff;
  for (var off = 0; off < padLen; off += 64) {
    for (var i = 0; i < 16; i++) {
      w[i] = bd.getUint32(off + i * 4);
    }
    for (var i = 16; i < 64; i++) {
      final s0 = rotr(w[i - 15], 7) ^ rotr(w[i - 15], 18) ^ (w[i - 15] >> 3);
      final s1 = rotr(w[i - 2], 17) ^ rotr(w[i - 2], 19) ^ (w[i - 2] >> 10);
      w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & 0xffffffff;
    }
    var a = h[0], b = h[1], c = h[2], d = h[3];
    var e = h[4], f = h[5], g = h[6], hh = h[7];
    for (var i = 0; i < 64; i++) {
      final s1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25);
      final ch = (e & f) ^ ((~e & 0xffffffff) & g);
      final t1 = (hh + s1 + ch + _k256[i] + w[i]) & 0xffffffff;
      final s0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22);
      final maj = (a & b) ^ (a & c) ^ (b & c);
      final t2 = (s0 + maj) & 0xffffffff;
      hh = g;
      g = f;
      f = e;
      e = (d + t1) & 0xffffffff;
      d = c;
      c = b;
      b = a;
      a = (t1 + t2) & 0xffffffff;
    }
    h[0] = (h[0] + a) & 0xffffffff;
    h[1] = (h[1] + b) & 0xffffffff;
    h[2] = (h[2] + c) & 0xffffffff;
    h[3] = (h[3] + d) & 0xffffffff;
    h[4] = (h[4] + e) & 0xffffffff;
    h[5] = (h[5] + f) & 0xffffffff;
    h[6] = (h[6] + g) & 0xffffffff;
    h[7] = (h[7] + hh) & 0xffffffff;
  }
  return h.map((v) => v.toRadixString(16).padLeft(8, '0')).join();
}

// ---------------------------------------------------------------------------
// Runner.

final class ItemSource {
  ItemSource(this.spec, this.sampleRate);
  final Map<String, dynamic> spec;
  final int sampleRate;
  String? _cachedId;
  Float64List? _cached;

  Map<String, dynamic> item(String id) =>
      (spec['items'] as Map<String, dynamic>)[id] as Map<String, dynamic>;

  /// Clean input of [id] at the spec sample rate.
  Float64List audio(String id) {
    if (_cachedId == id) return _cached!;
    final it = item(id);
    final x = switch (it['kind'] as String) {
      'file' => readF32(it['path'] as String),
      'resynth' => _resynth(it),
      'synth' => synthTrack(it, sampleRate),
      final k => throw ArgumentError('item $id: kind $k has no audio'),
    };
    _cachedId = id;
    _cached = x;
    return x;
  }

  Float64List _resynth(Map<String, dynamic> it) {
    final gt = jsonDecode(File(it['gt'] as String).readAsStringSync())
        as Map<String, dynamic>;
    return resynth(
        [for (final v in gt['t'] as List) (v as num).toDouble()],
        [for (final v in gt['hz'] as List) (v as num).toDouble()],
        it['samples'] as int,
        sampleRate);
  }
}

void runRender(
    Map<String, dynamic> spec, String outDir, List<int> shard, String? only) {
  final ctx = EvalContext.fromSpec(spec);
  final sr = ctx.sampleRate;
  final grid = FrameGrid(
      sr, (spec['winMs'] as num).toDouble(), (spec['hopMs'] as num).toDouble());
  final y = spec['yin'] as Map<String, dynamic>;
  final minHz = (y['minHz'] as num).toDouble();
  final maxHz = (y['maxHz'] as num).toDouble();
  final thr = (y['threshold'] as num).toDouble();
  final tol = (y['priorToleranceCents'] as num).toDouble();
  final checkEvery = spec['y1CheckEvery'] as int? ?? 50;
  final y0 = YinPitchSource(minHz: minHz, maxHz: maxHz, threshold: thr);
  final conds = {for (final c in ctx.conditions) c.name: c};
  final renderDir = Directory(spec['renderDir'] as String)
    ..createSync(recursive: true);
  final src = ItemSource(spec, sr);
  final tag = only == null ? '${shard[0]}' : 'only';
  final frames = File('$outDir/frames-$tag.jsonl').openWrite();
  final manifest = File('$outDir/manifest-$tag.jsonl').openWrite();
  final sw = Stopwatch()..start();
  var job = 0, done = 0;
  for (final j in (spec['jobs'] as List).cast<Map<String, dynamic>>()) {
    final id = j['id'] as String;
    if (only != null) {
      if (id != only) continue;
    } else if (job++ % shard[1] != shard[0]) {
      continue;
    }
    final c = conds[j['cond'] as String]!;
    final itemId = j['item'] as String;
    final it = src.item(itemId);
    final seed = j['seed'] as int;
    final renderSeed = stableHash('$itemId/${c.name}/$seed');
    final swCh = Stopwatch()..start();
    final Float64List z;
    double floorDb;
    if (it['kind'] == 'noise') {
      final ref = src.audio(it['ref'] as String);
      final n = ((it['seconds'] as num).toDouble() * sr).round();
      z = noiseOnlyRender(ctx, ref, n, c, renderSeed);
      floorDb = ctx.floorDb(ref, c, renderSeed);
    } else {
      final x = src.audio(itemId);
      z = ctx.render(x, c, renderSeed);
      floorDb = ctx.floorDb(x, c, renderSeed);
    }
    // Every arm reads the same f32 bytes.
    final f32 = Float32List.fromList(z);
    final bytes = f32.buffer.asUint8List();
    final path = '${renderDir.path}/${id.replaceAll('/', '__')}.f32';
    File(path).writeAsBytesSync(bytes);
    final sha = sha256Hex(bytes);
    final r = Float64List.fromList(f32);
    swCh.stop();

    final interiors = j['whole'] == true
        ? null
        : [
            for (final iv in j['interiors'] as List)
              [for (final v in iv as List) (v as num).toDouble()]
          ];
    final ks = grid.frames(r.length, interiors);
    final swY = Stopwatch()..start();
    final readings = <int, PitchReading>{};
    for (final k in ks) {
      final s = k * grid.hop;
      readings[k] =
          y0.analyze(r.sublist(s, s + grid.win), sampleRate: sr, tStartUs: 0);
    }
    swY.stop();
    frames.writeln(jsonEncode({
      'job': id,
      'arm': 'Y0',
      't': [for (final k in ks) grid.centre(k)],
      'f0': [for (final k in ks) readings[k]!.f0Hz],
      'per': [for (final k in ks) readings[k]!.periodicity],
      'rms': [for (final k in ks) readings[k]!.rmsDb],
    }));

    // Y1: per A2 note interior, once per target.
    var checked = 0, mismatch = 0, exact = 0, derived = 0;
    final y1Notes = <Map<String, Object?>>[];
    for (final note
        in (j['y1'] as List? ?? const []).cast<Map<String, dynamic>>()) {
      final a = (note['a'] as num).toDouble(),
          b = (note['b'] as num).toDouble();
      final nk = [
        for (final k in ks)
          if (grid.centre(k) >= a && grid.centre(k) <= b) k
      ];
      final targets = [
        for (final v in note['targets'] as List) (v as num).toDouble()
      ];
      final f0s = <List<double?>>[], pers = <List<double>>[];
      for (final tc in targets) {
        final prior = 440 * math.pow(2, tc / 1200).toDouble();
        YinPitchSource? real;
        PitchReading realAt(int k) {
          real ??= YinPitchSource(
              minHz: minHz,
              maxHz: maxHz,
              threshold: thr,
              expectedHzPrior: prior,
              priorToleranceCents: tol);
          final s = k * grid.hop;
          return real!
              .analyze(r.sublist(s, s + grid.win), sampleRate: sr, tStartUs: 0);
        }

        final fs = <double?>[], ps = <double>[];
        for (final k in nk) {
          final r0 = readings[k]!;
          double? f;
          double p;
          if (r0.f0Hz != null) {
            f = applyPriorLikeEngine(r0.f0Hz!, prior,
                minHz: minHz, maxHz: maxHz, priorToleranceCents: tol);
            p = r0.periodicity;
            derived++;
            if (derived % checkEvery == 0) {
              final rr = realAt(k);
              checked++;
              if (rr.f0Hz != f || rr.periodicity != p) mismatch++;
            }
          } else if (r0.periodicity > 0) {
            // Rejected by the prior-free range check only: the prior may snap
            // it back into range — use the real engine call.
            final rr = realAt(k);
            f = rr.f0Hz;
            p = rr.periodicity;
            exact++;
          } else {
            f = null;
            p = r0.periodicity;
          }
          fs.add(f);
          ps.add(p);
        }
        f0s.add(fs);
        pers.add(ps);
      }
      y1Notes.add({
        'note': note['note'],
        'targets': targets,
        't': [for (final k in nk) grid.centre(k)],
        'f0': f0s,
        'per': pers,
      });
    }
    frames.writeln(jsonEncode({
      'job': id,
      'arm': 'Y1',
      'notes': y1Notes,
      'derived': derived,
      'checked': checked,
      'mismatch': mismatch,
      'exactFallback': exact,
    }));
    manifest.writeln(jsonEncode({
      'job': id,
      'item': itemId,
      'cond': c.name,
      'seed': seed,
      'renderSeed': renderSeed,
      'ir': c.reverb && ctx.irs.isNotEmpty ? renderSeed % ctx.irs.length : null,
      'render': path,
      'sha256': sha,
      'samples': r.length,
      'sampleRate': sr,
      'floorDb': floorDb,
      'y0Frames': ks.length,
      'y0Ms': swY.elapsedMicroseconds / 1000,
      'channelMs': swCh.elapsedMicroseconds / 1000,
    }));
    done++;
  }
  frames.close();
  manifest.close();
  stderr.writeln('voice-eval render shard $tag: $done jobs '
      'in ${sw.elapsed.inSeconds}s');
}

/// Ground truth of the synthetic items (the generating curve), written as
/// `<gtDir>/<item>.json` = {t: [...], hz: [...]} like the prepared GT files.
void runGt(Map<String, dynamic> spec, String outDir) {
  final sr = spec['sampleRate'] as int;
  final hopS = (spec['synthGtHopS'] as num).toDouble();
  var n = 0;
  for (final e in (spec['items'] as Map<String, dynamic>).entries) {
    final it = e.value as Map<String, dynamic>;
    if (it['kind'] != 'synth') continue;
    final gt = synthTrackGt(it, sr, hopS);
    File('$outDir/${e.key.replaceAll('/', '__')}.json')
        .writeAsStringSync(jsonEncode({'t': gt.t, 'hz': gt.hz}));
    n++;
  }
  stderr.writeln('voice-eval gt: $n synthetic items');
}
