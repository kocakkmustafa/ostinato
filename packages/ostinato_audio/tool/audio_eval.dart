// Offline evaluation runner for the precise tuner and the note verifier
// (roadmap steps 0–2). Reads mono float32 little-endian audio prepared by the
// experiment scripts, applies the simulated phone channel and writes one JSON
// row per trial. No network, no model weights; deterministic for a given
// spec and shard.
//
//   dart run tool/audio_eval.dart synth-tuner <spec.json> <out.jsonl> [k/n]
//   dart run tool/audio_eval.dart real-tuner  <spec.json> <out.jsonl> [k/n]
//   dart run tool/audio_eval.dart verify      <spec.json> <out.jsonl> [k/n]
//
// Spec keys: sampleRate, conditions[], irs[] (f32le paths at sampleRate),
// plus synth `instruments[]` or real `items[]`, `shiftsCents[]`, `offsets[]`.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ostinato_audio/ostinato_audio.dart';

void main(List<String> args) {
  if (args.length < 3) {
    stderr.writeln(
        'usage: audio_eval.dart <synth-tuner|real-tuner|verify> <spec> <out> [k/n]');
    exit(64);
  }
  final spec =
      jsonDecode(File(args[1]).readAsStringSync()) as Map<String, dynamic>;
  final shard =
      args.length > 3 ? args[3].split('/').map(int.parse).toList() : [0, 1];
  final out = File(args[2]).openWrite();
  final ctx = EvalContext.fromSpec(spec);
  final sw = Stopwatch()..start();
  var rows = 0;
  void emit(Map<String, Object?> row) {
    out.writeln(jsonEncode(row));
    rows++;
  }

  switch (args[0]) {
    case 'synth-tuner':
      runSynthTuner(spec, ctx, shard, emit);
    case 'real-tuner':
      runRealTuner(spec, ctx, shard, emit);
    case 'verify':
      runVerify(spec, ctx, shard, emit);
    default:
      stderr.writeln('unknown command ${args[0]}');
      exit(64);
  }
  out.close();
  stderr.writeln(
      '${args[0]} shard ${shard[0]}/${shard[1]}: $rows rows in ${sw.elapsed.inSeconds}s');
}

final class EvalContext {
  EvalContext(this.sampleRate, this.conditions, this.irs);

  factory EvalContext.fromSpec(Map<String, dynamic> spec) {
    final sr = spec['sampleRate'] as int;
    final irs = [
      for (final p in (spec['irs'] as List? ?? const [])) readF32(p as String)
    ];
    final conds = [
      for (final c in spec['conditions'] as List)
        Condition.fromJson(c as Map<String, dynamic>)
    ];
    return EvalContext(sr, conds, irs);
  }

  final int sampleRate;
  final List<Condition> conditions;
  final List<Float64List> irs;

  /// Applies [c]; the IR (if any) is drawn deterministically from [seed].
  Float64List render(List<double> x, Condition c, int seed) {
    if (c.clean) return Float64List.fromList(x);
    final ir = c.reverb && irs.isNotEmpty ? irs[seed % irs.length] : null;
    final config = PhoneChannelConfig(
      name: c.name,
      impulseResponse: ir,
      directToReverbDb: c.drrDb,
      noise: c.noise,
      snrDb: c.snrDb,
      lowCutHz: c.lowCutHz,
      lowCutOrder: c.lowCutOrder,
      agc: c.agc,
    );
    return PhoneChannel.apply(x, sampleRate, config, seed: seed);
  }
}

final class Condition {
  Condition.fromJson(Map<String, dynamic> j)
      : name = j['name'] as String,
        clean = j['clean'] as bool? ?? false,
        reverb = j['reverb'] as bool? ?? false,
        drrDb = (j['drrDb'] as num? ?? 6).toDouble(),
        noise = ChannelNoise.values.byName(j['noise'] as String? ?? 'none'),
        snrDb = (j['snrDb'] as num? ?? 60).toDouble(),
        lowCutHz = (j['lowCutHz'] as num?)?.toDouble(),
        lowCutOrder = j['lowCutOrder'] as int? ?? 2,
        agc = j['agc'] as bool? ?? false;
  final String name;
  final bool clean, reverb, agc;
  final double drrDb, snrDb;
  final ChannelNoise noise;
  final double? lowCutHz;
  final int lowCutOrder;
}

Float64List readF32(String path) {
  final bytes = File(path).readAsBytesSync();
  final f =
      bytes.buffer.asFloat32List(bytes.offsetInBytes, bytes.lengthInBytes ~/ 4);
  return Float64List.fromList(f);
}

/// Pitch shift by resampling (cubic Hermite). All partial frequencies scale
/// by exactly 2^(cents/1200); B is unchanged; duration shrinks/grows.
Float64List shiftPitch(List<double> x, double cents) {
  if (cents == 0) return Float64List.fromList(x);
  final r = math.pow(2, cents / 1200).toDouble();
  final n = ((x.length - 3) / r).floor();
  final y = Float64List(math.max(0, n));
  double at(int i) => x[i.clamp(0, x.length - 1)];
  for (var i = 0; i < y.length; i++) {
    final t = i * r;
    final k = t.floor();
    final u = t - k;
    final p0 = at(k - 1), p1 = at(k), p2 = at(k + 1), p3 = at(k + 2);
    final a = -0.5 * p0 + 1.5 * p1 - 1.5 * p2 + 0.5 * p3;
    final b = p0 - 2.5 * p1 + 2 * p2 - 0.5 * p3;
    final c = -0.5 * p0 + 0.5 * p2;
    y[i] = ((a * u + b) * u + c) * u + p1;
  }
  return y;
}

/// Baseline for the tuner: plain YIN (the family's estimator, no
/// inharmonicity model, no correction table) over the same post-attack
/// segment, median of periodic frames.
double? baselineYinHz(List<double> x, int sampleRate, PreciseTunerProfile p) {
  final attack = PreciseTuner.envelopePeakIndex(x, sampleRate);
  final start = attack + (p.skipAfterAttackMs * sampleRate / 1000).round();
  final end =
      math.min(x.length, start + (p.maxSegmentMs * sampleRate / 1000).round());
  final size =
      math.max(4096, nextPowerOfTwo((2.2 * sampleRate / p.minHz).ceil()));
  final yin = YinPitchSource(minHz: p.minHz, maxHz: p.maxHz);
  final f = <double>[];
  for (var s = start; s + size <= end; s += size ~/ 2) {
    final r = yin.analyze(x.sublist(s, s + size),
        sampleRate: sampleRate, tStartUs: 0);
    if (r.f0Hz != null && r.periodicity >= 0.5) f.add(r.f0Hz!);
  }
  if (f.isEmpty) return null;
  f.sort();
  return f[f.length ~/ 2];
}

/// Baseline for the verifier: the shipped note observer (guitar-observation
/// config + guard) on the same post-attack span; same note → correct, other
/// note → different, refusal → could not hear.
String baselineObserverVerdict(
  GuitarPitchObserver observer,
  List<double> x,
  int sampleRate,
  int expectedMidi, {
  int? attackIndex,
}) {
  final peak = attackIndex ?? PreciseTuner.envelopePeakIndex(x, sampleRate);
  final start = peak + (0.08 * sampleRate).round();
  final end = math.min(x.length, start + (0.32 * sampleRate).round());
  if (end <= start) return NoteVerdict.couldNotHear.name;
  final r = observer.observe(x.sublist(start, end),
      sampleRate: sampleRate, tStartUs: 0, roomFloorDb: -120);
  final o = r.observation;
  if (o == null) return NoteVerdict.couldNotHear.name;
  return o.midi == expectedMidi
      ? NoteVerdict.correct.name
      : NoteVerdict.differentNote.name;
}

GuitarPitchObserver observerFromJson(Map<String, dynamic> json) {
  final p = json['pitchGate'] as Map<String, dynamic>;
  final g = json['guard'] as Map<String, dynamic>;
  double n(Map<String, dynamic> m, String k) => (m[k] as num).toDouble();
  return GuitarPitchObserver(
    config: GuitarSingleNoteConfig(
      windowSize: p['windowSize'] as int,
      hopSize: p['hopSize'] as int,
      minReliableWindows: p['minReliableWindows'] as int,
      minHz: n(p, 'minHz'),
      maxHz: n(p, 'maxHz'),
      yinThreshold: n(p, 'yinThreshold'),
      minPeriodicity: n(p, 'minPeriodicity'),
      minLevelAboveFloorDb: n(p, 'minLevelAboveFloorDb'),
      attackWindowUs: p['attackWindowUs'] as int,
      maxSpreadCents: n(p, 'maxSpreadCents'),
      maxCenterErrorCents: n(p, 'maxCenterErrorCents'),
    ),
    guard: GuitarObservationGuardConfig(
      maxResidualPowerRatio: n(g, 'maxResidualPowerRatio'),
      minFundamentalPowerRatio: n(g, 'minFundamentalPowerRatio'),
      clippingPeak: n(g, 'clippingPeak'),
      maxClippedFraction: n(g, 'maxClippedFraction'),
      harmonicToleranceCents: n(g, 'harmonicToleranceCents'),
      minAnalysisHz: n(g, 'minAnalysisHz'),
      maxAnalysisHz: n(g, 'maxAnalysisHz'),
      minFftSamples: g['minFftSamples'] as int,
      lowStringMaxMidi: g['lowStringMaxMidi'] as int?,
      lowStringMinOddHarmonicPowerRatio:
          (g['lowStringMinOddHarmonicPowerRatio'] as num?)?.toDouble(),
    ),
  );
}

/// With `useLabelOnset: true` the dataset's own onset (item `onsetSeconds`)
/// is passed to the tuner/verifier, as a lesson or an onset detector would;
/// otherwise both locate the attack themselves (loudest 10 ms frame).
int? labelOnsetIndex(
    Map<String, dynamic> spec, Map<String, dynamic> item, int sampleRate) {
  if (spec['useLabelOnset'] != true) return null;
  final s = item['onsetSeconds'] as num?;
  if (s == null) throw ArgumentError('item ${item['id']} has no onsetSeconds');
  return (s * sampleRate).round();
}

double wrapCents(double c) => c - (c / 1200).round() * 1200;
double centsOf(double a, double b) => 1200 * math.log(a / b) / math.ln2;
double midiHz(num midi) => 440 * math.pow(2, (midi - 69) / 12).toDouble();

PreciseTunerProfile profileNamed(String name) =>
    PreciseTunerProfile.all.firstWhere((p) => p.name == name);

/// Stable small hash for seeds (Dart's String.hashCode is not specified as
/// stable across runs/platforms).
int stableHash(String s) {
  var h = 2166136261;
  for (final c in s.codeUnits) {
    h = ((h ^ c) * 16777619) & 0x7fffffff;
  }
  return h;
}

Map<String, Object?> measurementRow(TunerResult r) {
  final m = r.measurement;
  return {
    'measured': r.measured,
    'refusal': r.refusal?.name,
    'f0': m?.f0Hz,
    'bFit': m?.inharmonicityB,
    'spread': m?.spreadCents,
    'nReadings': m?.readings.length,
    'partialsMedian': m == null
        ? null
        : (m.readings.map((e) => e.partials).toList()
          ..sort())[m.readings.length ~/ 2],
    'fundamentalShare': m == null
        ? null
        : m.readings.where((e) => e.fundamentalFound).length /
            m.readings.length,
  };
}

void runSynthTuner(
  Map<String, dynamic> spec,
  EvalContext ctx,
  List<int> shard,
  void Function(Map<String, Object?>) emit,
) {
  final seedBase = spec['seedBase'] as int;
  var job = 0;
  for (final inst in spec['instruments'] as List) {
    final i = inst as Map<String, dynamic>;
    final family = i['family'] as String;
    final profile = profileNamed(i['profile'] as String);
    List<double> range(String k) =>
        [for (final v in i[k] as List) (v as num).toDouble()];
    final bR = range('bRange'),
        pR = range('pluckRange'),
        dR = range('decayRange');
    final gR = range('glideRange'), tR = range('detuneRange');
    final seconds = (i['seconds'] as num? ?? 2.4).toDouble();
    for (final midi in (i['strings'] as List).cast<int>()) {
      for (var rep = 0; rep < (i['repeats'] as int); rep++) {
        if (job++ % shard[1] != shard[0]) continue;
        final seed = seedBase + stableHash('$family/$midi/$rep');
        final rng = math.Random(seed);
        double draw(List<double> r) => r[0] + (r[1] - r[0]) * rng.nextDouble();
        final detune = draw(tR);
        final f0 = midiHz(midi) * math.pow(2, detune / 1200);
        final b = draw(bR),
            pluck = draw(pR),
            decay = draw(dR),
            glide = draw(gR);
        final x = SyntheticString.pluck(
          f0Hz: f0,
          sampleRate: ctx.sampleRate,
          seconds: seconds,
          inharmonicityB: b,
          pluckPosition: pluck,
          fundamentalDecaySeconds: decay,
          glideCents: glide,
          polarizationDetuneCents: 0.3,
          polarizationLevel: 0.2,
          preRollSeconds: 0.25,
          seed: seed,
        );
        for (final c in ctx.conditions) {
          final y = ctx.render(x, c, seed + stableHash(c.name));
          final r = PreciseTuner(profile: profile)
              .measure(y, sampleRate: ctx.sampleRate);
          final m = r.measurement;
          final yinHz = baselineYinHz(y, ctx.sampleRate, profile);
          emit({
            'family': family,
            'profile': profile.name,
            'midi': midi,
            'rep': rep,
            'cond': c.name,
            'truthF0': f0,
            'detune': detune,
            'b': b,
            'pluck': pluck,
            'decay': decay,
            'glide': glide,
            ...measurementRow(r),
            'err': m == null ? null : wrapCents(centsOf(m.f0Hz, f0)),
            'midiOk': m == null ? null : m.midi == midi,
            'yinErr': yinHz == null ? null : wrapCents(centsOf(yinHz, f0)),
          });
        }
      }
    }
  }
}

void runRealTuner(
  Map<String, dynamic> spec,
  EvalContext ctx,
  List<int> shard,
  void Function(Map<String, Object?>) emit,
) {
  final shifts = [
    for (final s in spec['shiftsCents'] as List) (s as num).toDouble()
  ];
  var job = 0;
  for (final it in spec['items'] as List) {
    final item = it as Map<String, dynamic>;
    if (job++ % shard[1] != shard[0]) continue;
    final id = item['id'] as String;
    final profile = profileNamed(item['profile'] as String);
    final tuner = PreciseTuner(profile: profile);
    final x = readF32(item['raw'] as String);
    final refRaw = item['refRaw'] as String?;
    final onset = labelOnsetIndex(spec, item, ctx.sampleRate);
    final ref = tuner.measure(refRaw == null ? x : readF32(refRaw),
        sampleRate: ctx.sampleRate, attackIndex: onset);
    final refF0 = ref.measurement?.f0Hz;
    final base = {
      'id': id,
      'group': item['group'],
      'midi': item['midi'],
      'profile': profile.name,
      'refMeasured': ref.measured,
      'refRefusal': ref.refusal?.name,
      'refF0': refF0,
      'refCentsFromLabel':
          refF0 == null ? null : centsOf(refF0, midiHz(item['midi'] as int)),
    };
    for (final shift in shifts) {
      final y = shiftPitch(x, shift);
      for (final c in ctx.conditions) {
        final seed = stableHash('$id/$shift/${c.name}');
        final z = ctx.render(y, c, seed);
        // Resampling scales time by 1/r: move the known onset with it.
        final shiftedOnset =
            onset == null ? null : (onset / math.pow(2, shift / 1200)).round();
        final r = tuner.measure(z,
            sampleRate: ctx.sampleRate, attackIndex: shiftedOnset);
        final m = r.measurement;
        final yinHz = baselineYinHz(z, ctx.sampleRate, profile);
        emit({
          ...base,
          'shift': shift,
          'cond': c.name,
          ...measurementRow(r),
          'err': m == null || refF0 == null
              ? null
              : wrapCents(centsOf(m.f0Hz, refF0) - shift),
          'yinErr': yinHz == null || refF0 == null
              ? null
              : wrapCents(centsOf(yinHz, refF0) - shift),
        });
      }
    }
  }
}

void runVerify(
  Map<String, dynamic> spec,
  EvalContext ctx,
  List<int> shard,
  void Function(Map<String, Object?>) emit,
) {
  final offsets = (spec['offsets'] as List).cast<int>();
  final verifier = GuitarNoteVerifier();
  final baselineJson = spec['baselineObserverConfig'] as String?;
  final observer = baselineJson == null
      ? null
      : observerFromJson(jsonDecode(File(baselineJson).readAsStringSync())
          as Map<String, dynamic>);
  var job = 0;
  for (final it in spec['items'] as List) {
    final item = it as Map<String, dynamic>;
    if (job++ % shard[1] != shard[0]) continue;
    final id = item['id'] as String;
    final midi = item['midi'] as int;
    final x = readF32(item['raw'] as String);
    for (final c in ctx.conditions) {
      final z = ctx.render(x, c, stableHash('$id/${c.name}'));
      // One attack per rendered recording: the dataset onset (label mode) or
      // the verifier's own rule, identical to its default path.
      final cfg = verifier.config;
      final attack = labelOnsetIndex(spec, item, ctx.sampleRate) ??
          verifier.attackLocator.lastUsableAttack(z, ctx.sampleRate,
              requiredSamples:
                  (cfg.skipAfterOnsetMs * ctx.sampleRate / 1000).round() +
                      (cfg.minAnalysisMs * ctx.sampleRate / 1000).round());
      // Baseline observer: E36–E38 used the loudest frame; with
      // `baselineAttack: "verifier"` it gets the verifier's attack.
      final baselineAttack =
          spec['baselineAttack'] == 'verifier' ? attack : null;
      for (final d in offsets) {
        final expected = midi + d;
        if (expected < 0 || expected > 127) continue;
        final v = verifier.verify(z,
            sampleRate: ctx.sampleRate,
            expectedMidi: expected,
            onsetIndex: attack);
        emit({
          'id': id,
          'group': item['group'],
          'midi': midi,
          'offset': d,
          'cond': c.name,
          'verdict': v.verdict.name,
          'reason': v.reason.name,
          'observedMidi': v.observedMidi,
          'centsFromExpected': v.centsFromExpected,
          'baseline': observer == null
              ? null
              : baselineObserverVerdict(observer, z, ctx.sampleRate, expected,
                  attackIndex: baselineAttack),
          'attackS': attack == null ? null : attack / ctx.sampleRate,
        });
      }
    }
  }
}
