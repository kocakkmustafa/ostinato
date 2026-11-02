// Offline evaluation runner for the precise tuner and the note verifier
// (roadmap steps 0–2). Reads mono float32 little-endian audio prepared by the
// experiment scripts, applies the simulated phone channel and writes one JSON
// row per trial. No network, no model weights; deterministic for a given
// spec and shard.
//
//   dart run tool/audio_eval.dart synth-tuner <spec.json> <out.jsonl> [k/n]
//   dart run tool/audio_eval.dart real-tuner  <spec.json> <out.jsonl> [k/n]
//   dart run tool/audio_eval.dart verify      <spec.json> <out.jsonl> [k/n]
//   dart run tool/audio_eval.dart stream-tuner|stream-verify <spec> <out> [k/n]
//
// E52 stream-tuner flags (absent = E45 behaviour, rows unchanged):
// `seedSalt` (string) salts the channel seed, condition `seedOf` reuses
// another condition's channel draw, `displayRule: "confident-first"` adds
// arm T (t* fields) computed in the same pass as arm C.
//
// E51 (harness only; the engine is unchanged):
//   stream-tuner / stream-verify accept `seedSalt` (int, 0 = the E43–E45
//   hashes), `lastOnly` (stream-tuner) and `gShift` (stream-tuner, C0 rows).
//   dart run tool/audio_eval.dart stream-render <spec.json> <outdir> [k/n] [from:to]
//   dart run tool/audio_eval.dart synth-render  <spec.json> <outdir> [k/n]
//   The render commands write the channel output (f32le) and a
//   `manifest.jsonl` into <outdir> for the model arms; `from:to` selects the
//   shard-local item range (chunks).
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
  final render = args[0] == 'stream-render' || args[0] == 'synth-render';
  if (render) Directory(args[2]).createSync(recursive: true);
  final out = File(render ? '${args[2]}/manifest.jsonl' : args[2]).openWrite();
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
    case 'stream-tuner':
      runStreamTuner(spec, ctx, shard, emit);
    case 'stream-verify':
      runStreamVerify(spec, ctx, shard, emit);
    case 'stream-render':
      final range = args.length > 4
          ? args[4].split(':').map(int.parse).toList()
          : [0, 1 << 30];
      runStreamRender(spec, ctx, shard, range, args[2], emit);
    case 'synth-render':
      runSynthRender(spec, ctx, shard, args[2], emit);
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

  /// Calibrated room floor for [c] (see PhoneChannel.noiseFloorDb), same IR
  /// and noise seed as [render].
  double floorDb(List<double> x, Condition c, int seed) {
    if (c.clean) return -180;
    final ir = c.reverb && irs.isNotEmpty ? irs[seed % irs.length] : null;
    return PhoneChannel.noiseFloorDb(
      x,
      sampleRate,
      PhoneChannelConfig(
        impulseResponse: ir,
        directToReverbDb: c.drrDb,
        noise: c.noise,
        snrDb: c.snrDb,
        lowCutHz: c.lowCutHz,
        lowCutOrder: c.lowCutOrder,
        agc: c.agc,
      ),
      seed: seed + 1,
    );
  }

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
        agc = j['agc'] as bool? ?? false,
        seedOf = j['seedOf'] as String?;
  final String name;

  /// E52: an ablation condition reuses another condition's channel draw (IR
  /// index and noise sequence) by naming it here; null = its own name.
  final String? seedOf;
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

/// Arm options from the spec. Since E42 an absent key means the *product
/// default*; an explicit key overrides it (`false` / `null` switches an option
/// off, which reproduces the E40 engine). E41 specs were run at commit
/// 0f22744, where absent keys meant "off".
AttackLocator locatorFromSpec(Map<String, dynamic> spec) {
  final o = spec['locator'] as Map<String, dynamic>? ?? const {};
  const d = AttackLocator();
  final hop = (o['hopMs'] as num?)?.toDouble();
  return AttackLocator(
    detector: hop == null ? d.detector : OnsetDetector(hopMs: hop),
    minRelativeStrength: d.minRelativeStrength,
    minRiseDb: d.minRiseDb,
    bufferStartCandidate:
        o['bufferStartCandidate'] as bool? ?? d.bufferStartCandidate,
    maxBelowLoudestDb: o.containsKey('maxBelowLoudestDb')
        ? (o['maxBelowLoudestDb'] as num?)?.toDouble()
        : d.maxBelowLoudestDb,
  );
}

PreciseTuner tunerFromSpec(
    Map<String, dynamic> spec, PreciseTunerProfile profile) {
  final o = spec['tunerOptions'] as Map<String, dynamic>? ?? const {};
  return PreciseTuner(
    profile: profile.copyWith(
      maxAnalysisHz: (o['maxAnalysisHz'] as num?)?.toDouble(),
      adaptiveWindowPeriods: (o['adaptiveWindowPeriods'] as num?)?.toDouble(),
      maxLateSpreadCents: (o['maxLateSpreadCents'] as num?)?.toDouble(),
      disableAdaptiveWindow: o.containsKey('adaptiveWindowPeriods') &&
          o['adaptiveWindowPeriods'] == null,
      disableLateReadings: o.containsKey('maxLateSpreadCents') &&
          o['maxLateSpreadCents'] == null,
      adaptiveWindowMinMidi: (o['adaptiveWindowMinMidi'] as num?)?.toDouble(),
      lateFractionOpen: (o['lateFractionOpen'] as num?)?.toDouble(),
    ),
    attackLocator: locatorFromSpec(spec),
  );
}

GuitarNoteVerifier verifierFromSpec(Map<String, dynamic> spec) {
  final o = spec['verifierOptions'] as Map<String, dynamic>? ?? const {};
  return GuitarNoteVerifier(
    config: NoteVerifierConfig(
        fifthRival:
            o['fifthRival'] as bool? ?? const NoteVerifierConfig().fifthRival),
    attackLocator: locatorFromSpec(spec),
  );
}

/// Optional dataset-cut correction (E41 arm P): `padGroups: {group: s}`
/// prepends s seconds of digital silence (the channel then adds its noise).
Float64List readItem(
    Map<String, dynamic> spec, Map<String, dynamic> item, String key, int sr) {
  final x = readF32(item[key] as String);
  final pad = (spec['padGroups'] as Map<String, dynamic>?)?[item['group']];
  if (pad == null) return x;
  final n = ((pad as num) * sr).round();
  return Float64List(n + x.length)..setRange(n, n + x.length, x);
}

/// `groups: [...]` restricts a run to those item groups (null = all).
bool inGroups(Map<String, dynamic> spec, Map<String, dynamic> item) {
  final g = spec['groups'] as List?;
  return g == null || g.contains(item['group']);
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
    'fromLate': m?.fromLateReadings,
  };
}

/// One E36 synthetic string note (draw order fixed: detune, B, pluck, decay,
/// glide). Shared by `synth-tuner` and the E51 `synth-render`.
({
  int seed,
  double f0,
  double detune,
  double b,
  double pluck,
  double decay,
  double glide,
  Float64List x
}) synthNote(
    Map<String, dynamic> i, int seedBase, int midi, int rep, int sampleRate) {
  final family = i['family'] as String;
  List<double> range(String k) =>
      [for (final v in i[k] as List) (v as num).toDouble()];
  final seconds = (i['seconds'] as num? ?? 2.4).toDouble();
  final seed = seedBase + stableHash('$family/$midi/$rep');
  final rng = math.Random(seed);
  double draw(List<double> r) => r[0] + (r[1] - r[0]) * rng.nextDouble();
  final detune = draw(range('detuneRange'));
  final f0 = midiHz(midi) * math.pow(2, detune / 1200);
  final b = draw(range('bRange')),
      pluck = draw(range('pluckRange')),
      decay = draw(range('decayRange')),
      glide = draw(range('glideRange'));
  final x = SyntheticString.pluck(
    f0Hz: f0,
    sampleRate: sampleRate,
    seconds: seconds,
    inharmonicityB: b,
    pluckPosition: pluck,
    fundamentalDecaySeconds: decay,
    glideCents: glide,
    polarizationDetuneCents: 0.3,
    polarizationLevel: 0.2,
    preRollSeconds: synthPreRollS,
    seed: seed,
  );
  return (
    seed: seed,
    f0: f0,
    detune: detune,
    b: b,
    pluck: pluck,
    decay: decay,
    glide: glide,
    x: x
  );
}

/// Onset of every E36 synthetic note (pre-roll before the pluck).
const synthPreRollS = 0.25;

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
    for (final midi in (i['strings'] as List).cast<int>()) {
      for (var rep = 0; rep < (i['repeats'] as int); rep++) {
        if (job++ % shard[1] != shard[0]) continue;
        final n = synthNote(i, seedBase, midi, rep, ctx.sampleRate);
        final (:seed, :f0, :detune, :b, :pluck, :decay, :glide, :x) = n;
        for (final c in ctx.conditions) {
          final y = ctx.render(x, c, seed + stableHash(c.name));
          final r = tunerFromSpec(spec, profile)
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
    if (!inGroups(spec, item)) continue;
    if (job++ % shard[1] != shard[0]) continue;
    final id = item['id'] as String;
    final profile = profileNamed(item['profile'] as String);
    final tuner = tunerFromSpec(spec, profile);
    final x = readItem(spec, item, 'raw', ctx.sampleRate);
    final refRaw = item['refRaw'] as String?;
    final onset = labelOnsetIndex(spec, item, ctx.sampleRate);
    final ref = tuner.measure(
        refRaw == null ? x : readItem(spec, item, 'refRaw', ctx.sampleRate),
        sampleRate: ctx.sampleRate,
        attackIndex: onset);
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
  final verifier = verifierFromSpec(spec);
  final baselineJson = spec['baselineObserverConfig'] as String?;
  final observer = baselineJson == null
      ? null
      : observerFromJson(jsonDecode(File(baselineJson).readAsStringSync())
          as Map<String, dynamic>);
  var job = 0;
  for (final it in spec['items'] as List) {
    final item = it as Map<String, dynamic>;
    if (!inGroups(spec, item)) continue;
    if (job++ % shard[1] != shard[0]) continue;
    final id = item['id'] as String;
    final midi = item['midi'] as int;
    final x = readItem(spec, item, 'raw', ctx.sampleRate);
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

// ---------------------------------------------------------------------------
// E43 product-like cut. Each item is a stream segment: 2 s of the audio that
// really preceded the note in the source stream, the note, and its life up
// to the next note (max 4 s). The phone channel runs over the whole segment
// (AGC and reverb are warm when the note starts).
//
// Tuner: the app keeps the last 1.6 s (GuitarObservationConfig.tuningWindowMs)
// and analyses every 350 ms (guitar-observation.v2.json analysisIntervalMs);
// each analysis measures the whole tuning buffer; a refusal keeps the last
// reading. Here: analysis instants onset + phase + k * 350 ms (phase per note,
// 0–349 ms, from a stable hash) up to the note's end; the note's reading is
// the last successful measurement (what the gate shows), success = any.
//
// Verifier: the lesson knows the expected time; window = expected - 150 ms
// (MetronomeAligner.matchWindowMs) .. expected + 600 ms, where the player is
// early/late by a stable per-note jitter of up to ±100 ms.
//
// spec['grid']: 'buffer' (default, frames from each buffer's start),
// 'global' (frames on the stream's hop grid) or 'global+cache' (same, with an
// OnsetFrameCache reused across a note's analyses; rows must equal 'global').

int jitterMs(String id, int range, [String salt = '']) =>
    stableHash('$id/phase$salt') % range;

/// E51 seeds: `seedSalt` s > 0 appends `/s{s}` to every stableHash key of the
/// cut (render seed, player jitter, tuner phase); 0 or absent keeps the E43–E45
/// keys bit for bit.
String seedSalt(Map<String, dynamic> spec) {
  // A string salt is E52's (streamTunerSeed); E51 keys stay unsalted for it.
  final v = spec['seedSalt'];
  if (v is String) return '';
  final s = v as int? ?? 0;
  if (s < 0) throw ArgumentError('seedSalt must be >= 0');
  return s > 0 ? '/s$s' : '';
}

/// IR index the channel uses for [seed] (null: no reverb).
int? irIndexOf(EvalContext ctx, Condition c, int seed) =>
    c.clean || !c.reverb || ctx.irs.isEmpty ? null : seed % ctx.irs.length;

/// Tuner analysis instants of one note: onset + phase + k × interval, ≤ end.
List<int> analysisInstants(int onset, int phase, int end, int interval) =>
    [for (var t = onset + phase; t <= end; t += interval) t];

/// The note's shown reading = the last successful measurement over
/// [instants] (E43). Forward: every instant is measured (`n`, `measured`,
/// `firstK` are diagnostics). With [lastOnly] the instants are visited
/// backwards and the walk stops at the first success: the same reading and
/// instant, because a measurement depends only on its own buffer. Not exact
/// with a stateful [accept] (note gate), so that combination is rejected.
({TuningMeasurement? m, int? k, int n, int? measured, int? firstK})
    shownReading(
        List<int> instants, TuningMeasurement? Function(int t) measureAt,
        {bool lastOnly = false,
        bool Function(TuningMeasurement m, int t)? accept}) {
  if (lastOnly) {
    if (accept != null) {
      throw ArgumentError('lastOnly is exact only without a note gate');
    }
    var n = 0;
    for (var k = instants.length - 1; k >= 0; k--) {
      n++;
      final m = measureAt(instants[k]);
      if (m != null) return (m: m, k: k, n: n, measured: null, firstK: null);
    }
    return (m: null, k: null, n: n, measured: null, firstK: null);
  }
  TuningMeasurement? last;
  int? lastK, firstK;
  var measured = 0;
  for (var k = 0; k < instants.length; k++) {
    final m = measureAt(instants[k]);
    if (m != null && (accept == null || accept(m, instants[k]))) {
      measured++;
      last = m;
      lastK = k;
      firstK ??= k;
    }
  }
  return (
    m: last,
    k: lastK,
    n: instants.length,
    measured: measured,
    firstK: firstK
  );
}

/// Writes x[from:to] as float32 little-endian.
void writeF32(String path, List<double> x, [int from = 0, int? to]) {
  final end = to ?? x.length;
  final f = Float32List(end - from);
  for (var i = from; i < end; i++) {
    f[i - from] = x[i];
  }
  File(path).writeAsBytesSync(f.buffer.asUint8List());
}

({OnsetFrameCache? cache, bool global}) gridMode(Map<String, dynamic> spec) {
  final g = spec['grid'] as String? ?? 'buffer';
  return (
    cache: g == 'global+cache' ? OnsetFrameCache() : null,
    global: g != 'buffer'
  );
}

void runStreamTuner(
  Map<String, dynamic> spec,
  EvalContext ctx,
  List<int> shard,
  void Function(Map<String, Object?>) emit,
) {
  final shifts = [
    for (final s in spec['shiftsCents'] as List) (s as num).toDouble()
  ];
  final sr = ctx.sampleRate;
  final interval = (0.35 * sr).round();
  final bufferLen = (1.6 * sr).round();
  final salt = seedSalt(spec);
  final e51 = spec['seedSalt'] is int;
  final lastOnly = spec['lastOnly'] == true;
  if (lastOnly && spec['noteGate'] != null) {
    throw ArgumentError('lastOnly is exact only without noteGate');
  }
  var job = 0;
  for (final it in spec['items'] as List) {
    final item = it as Map<String, dynamic>;
    if (!inGroups(spec, item)) continue;
    if (job++ % shard[1] != shard[0]) continue;
    final id = item['id'] as String;
    final profile = profileNamed(item['profile'] as String);
    final tuner = tunerFromSpec(spec, profile);
    final seg = readF32(item['seg'] as String);
    final ref =
        tuner.measure(readF32(item['refRaw'] as String), sampleRate: sr);
    final refF0 = ref.measurement?.f0Hz;
    final phase = (jitterMs(id, 350, salt) * sr / 1000).round();
    final onset0 = ((item['onsetS'] as num) * sr).round();
    for (final shift in shifts) {
      final r = math.pow(2, shift / 1200).toDouble();
      final y = shiftPitch(seg, shift);
      final onset = ((item['onsetS'] as num) * sr / r).round();
      final end = math.min(y.length, ((item['endS'] as num) * sr / r).round());
      final instants = analysisInstants(onset, phase, end, interval);
      for (final c in ctx.conditions) {
        // E51 (int salt) and E52 (string salt, seedOf) keep their own keys.
        final seed = spec['seedSalt'] is int
            ? stableHash('$id/$shift/${c.name}/stream$salt')
            : streamTunerSeed(spec, id, shift, c);
        final z = ctx.render(y, c, seed);
        final mode = gridMode(spec);
        // E44: the app passes its calibrated room floor to every measurement.
        final floor =
            spec['roomFloor'] == 'calibrated' ? ctx.floorDb(y, c, seed) : null;
        final gate = NoteGate.fromSpec(spec, sr);
        // E52 arm T: same measurements, only the shown one differs.
        final display = ConfidentFirst.fromSpec(spec, sr);
        final sw = Stopwatch()..start();
        final shown = shownReading(
            instants,
            (t) => tuner
                .measure(z.sublist(math.max(0, t - bufferLen), t),
                    sampleRate: sr,
                    roomFloorDb: floor,
                    absoluteStartSample:
                        mode.global ? math.max(0, t - bufferLen) : null,
                    onsetCache: mode.cache)
                .measurement,
            lastOnly: lastOnly,
            accept: gate == null && display == null
                ? null
                : (m, t) {
                    final a = math.max(0, t - bufferLen);
                    if (gate != null && !gate.accept(m, a, t)) return false;
                    display?.offer(m, a, t);
                    return true;
                  });
        sw.stop();
        final last = shown.m;
        final lastT = shown.k == null ? null : instants[shown.k!];
        final lastA = lastT == null
            ? null
            : math.max(0, lastT - bufferLen) + (last!.attackIndex ?? 0);
        final firstS = shown.firstK == null
            ? null
            : (instants[shown.firstK!] - onset) / sr;
        // E51 G-shift: in C0 the shifted note's reading against the unshifted
        // clean buffer at the same analysis instant (same k).
        double? gShiftF0;
        if (spec['gShift'] == true &&
            c.clean &&
            shift != 0 &&
            shown.k != null) {
          final t0 = onset0 + phase + shown.k! * interval;
          if (t0 <= seg.length) {
            gShiftF0 = cleanTuner(spec, profile)
                .measure(seg.sublist(math.max(0, t0 - bufferLen), t0),
                    sampleRate: sr)
                .measurement
                ?.f0Hz;
          }
        }
        // E45: the clean (unrendered, same shift) buffer at the instant the
        // shown reading was taken; separates the tuner's error from the
        // string's own drift. Not timed.
        double? cleanAt(int t) => cleanTuner(spec, profile)
            .measure(y.sublist(math.max(0, t - bufferLen), t), sampleRate: sr)
            .measurement
            ?.f0Hz;
        double? cleanF0;
        if (spec['cleanRef'] == true && lastT != null) {
          cleanF0 = cleanAt(lastT);
        }
        emit({
          'id': id,
          'group': item['group'],
          'midi': item['midi'],
          'shift': shift,
          'cond': c.name,
          'refMeasured': ref.measured,
          'refF0': refF0,
          'instants': lastOnly ? null : shown.n,
          'measuredInstants': shown.measured,
          'measured': last != null,
          'f0': last?.f0Hz,
          'fromLate': last?.fromLateReadings,
          'firstSuccessS': firstS,
          'err': last == null || refF0 == null
              ? null
              : wrapCents(centsOf(last.f0Hz, refF0) - shift),
          'ms': sw.elapsedMicroseconds / 1000,
          'lastS': lastT == null ? null : (lastT - onset) / sr,
          'lastAttackS': lastA == null ? null : (lastA - onset) / sr,
          if (spec['cleanRef'] == true) ...{
            'cleanF0': cleanF0,
            'errClean': last == null || cleanF0 == null
                ? null
                : centsOf(last.f0Hz, cleanF0),
          },
          'cacheHits': mode.cache?.hits,
          'cacheMisses': mode.cache?.misses,
          'roomFloorDb': floor,
          if (e51) ...{
            'seedSalt': spec['seedSalt'],
            'renderSeed': seed,
            'irIndex': irIndexOf(ctx, c, seed),
            'k': shown.k,
            'calls': shown.n,
          },
          if (spec['gShift'] == true && c.clean && shift != 0) ...{
            'gShiftF0': gShiftF0,
            'gShift': last == null || gShiftF0 == null
                ? null
                : centsOf(last.f0Hz, gShiftF0) - shift,
          },
          // E52 fields only when an E52 flag is set (rows of older specs are
          // byte-for-byte unchanged).
          if (spec['seedSalt'] is String || display != null) ...{
            'seed': seed,
            'irIndex': ctx.irs.isEmpty ? null : seed % ctx.irs.length,
            'irUsed': !c.clean && c.reverb && ctx.irs.isNotEmpty,
            'attackIndexMs': last?.attackIndex == null
                ? null
                : last!.attackIndex! * 1000 / sr,
            'confident':
                last == null ? null : ConfidentFirst.isConfident(last, sr),
          },
          if (display != null)
            ...display.row(
              last: last,
              lastT: lastT,
              lastA: lastA,
              cleanF0: cleanF0,
              cleanAt: spec['cleanRef'] == true ? cleanAt : null,
              onset: onset,
              refF0: refF0,
              shift: shift,
            ),
        });
      }
    }
  }
}

/// Channel seed of a stream-tuner row. Without `seedSalt` this is the E43–E45
/// formula (a condition's own name); E52 (`seedSalt: "E52"`) appends the salt
/// so the IR draw and noise differ from every earlier run, and `seedOf` lets
/// an ablation reuse another condition's draw.
int streamTunerSeed(
    Map<String, dynamic> spec, String id, double shift, Condition c) {
  final salt = spec['seedSalt'] as String?;
  final key = '$id/$shift/${c.seedOf ?? c.name}/stream';
  return stableHash(salt == null ? key : '$key/$salt');
}

/// E52 arm T (`displayRule: "confident-first"`): the note shows its last
/// *confident* measurement — the tuner screen's `confident` rule
/// (lib/app/tuner/tuner_analysis.dart: attack at least kMinVisibleAttackMs =
/// 20 ms inside the buffer, not from the late-readings rule; the spread limit
/// follows from the latter) — and falls back to the last successful
/// measurement (arm C) when the note has none. A tail reading never replaces
/// an earlier confident reading of the same note. Null when the spec has no
/// display rule.
final class ConfidentFirst {
  ConfidentFirst(this.sampleRate);

  static const minVisibleAttackMs = 20;

  static ConfidentFirst? fromSpec(Map<String, dynamic> spec, int sampleRate) {
    final r = spec['displayRule'] as String?;
    if (r == null) return null;
    if (r != 'confident-first') {
      throw ArgumentError('unknown displayRule $r');
    }
    return ConfidentFirst(sampleRate);
  }

  static bool isConfident(TuningMeasurement m, int sampleRate) {
    final idx = m.attackIndex;
    return idx != null &&
        idx >= minVisibleAttackMs * sampleRate / 1000 &&
        !m.fromLateReadings;
  }

  final int sampleRate;
  TuningMeasurement? conf;
  int? confT, confA;
  var confidentInstants = 0;

  /// Called with every measurement arm C counts, in time order.
  void offer(TuningMeasurement m, int bufferStart, int t) {
    if (!isConfident(m, sampleRate)) return;
    confidentInstants++;
    conf = m;
    confT = t;
    confA = bufferStart + m.attackIndex!;
  }

  Map<String, Object?> row({
    required TuningMeasurement? last,
    required int? lastT,
    required int? lastA,
    required double? cleanF0,
    required double? Function(int t)? cleanAt,
    required int onset,
    required double? refF0,
    required double shift,
  }) {
    final sr = sampleRate;
    final m = conf ?? last;
    final t = conf != null ? confT : lastT;
    final a = conf != null ? confA : lastA;
    // Clean reference: reused when T shows C's instant, else one extra
    // measurement of the clean buffer at T's instant.
    final extra = cleanAt != null && t != null && t != lastT;
    final tClean = cleanAt == null || t == null
        ? null
        : (t == lastT ? cleanF0 : cleanAt(t));
    return {
      'tMeasured': m != null,
      'tConfident': conf != null,
      'tConfidentInstants': confidentInstants,
      'tF0': m?.f0Hz,
      'tFromLate': m?.fromLateReadings,
      'tAttackIndexMs':
          m?.attackIndex == null ? null : m!.attackIndex! * 1000 / sr,
      'tLastS': t == null ? null : (t - onset) / sr,
      'tLastAttackS': a == null ? null : (a - onset) / sr,
      'tErr': m == null || refF0 == null
          ? null
          : wrapCents(centsOf(m.f0Hz, refF0) - shift),
      if (cleanAt != null) ...{
        'tCleanF0': tClean,
        'tCleanExtra': extra,
        'tErrClean':
            m == null || tClean == null ? null : centsOf(m.f0Hz, tClean),
      },
    };
  }
}

void runStreamVerify(
  Map<String, dynamic> spec,
  EvalContext ctx,
  List<int> shard,
  void Function(Map<String, Object?>) emit,
) {
  final offsets = (spec['offsets'] as List).cast<int>();
  final verifier = verifierFromSpec(spec);
  final sr = ctx.sampleRate;
  final salt = seedSalt(spec);
  final e51 = spec['seedSalt'] is int;
  var job = 0;
  for (final it in spec['items'] as List) {
    final item = it as Map<String, dynamic>;
    if (!inGroups(spec, item)) continue;
    if (job++ % shard[1] != shard[0]) continue;
    final id = item['id'] as String;
    final midi = item['midi'] as int;
    final seg = readF32(item['seg'] as String);
    final (:a, :b, :early) = verifyWindow(item, seg.length, sr, salt);
    for (final c in ctx.conditions) {
      final seed = stableHash('$id/${c.name}/stream$salt');
      final z = ctx.render(seg, c, seed);
      final window = z.sublist(a, b);
      final floor =
          spec['roomFloor'] == 'calibrated' ? ctx.floorDb(seg, c, seed) : null;
      final mode = gridMode(spec);
      for (final d in offsets) {
        final v = verifier.verify(window,
            sampleRate: sr,
            expectedMidi: midi + d,
            roomFloorDb: floor,
            absoluteStartSample: mode.global ? a : null,
            onsetCache: mode.cache);
        emit({
          'id': id,
          'group': item['group'],
          'midi': midi,
          'offset': d,
          'cond': c.name,
          'verdict': v.verdict.name,
          'reason': v.reason.name,
          'observedMidi': v.observedMidi,
          'earlyMs': early * 1000 / sr,
          if (e51) ...{
            'seedSalt': spec['seedSalt'],
            'renderSeed': seed,
            'irIndex': irIndexOf(ctx, c, seed),
          },
        });
      }
    }
  }
}

/// E43 verifier window of one stream item: the player is early (+) or late
/// (−) by up to 100 ms relative to the expected time; window = expected −
/// 150 ms .. expected + 600 ms.
({int a, int b, int early}) verifyWindow(
    Map<String, dynamic> item, int length, int sr, String salt) {
  final onset = ((item['onsetS'] as num) * sr).round();
  final early =
      ((jitterMs(item['id'] as String, 201, salt) - 100) * sr / 1000).round();
  final expected = onset + early;
  return (
    a: math.max(0, expected - (0.15 * sr).round()),
    b: math.min(length, expected + (0.60 * sr).round()),
    early: early
  );
}

// ---------------------------------------------------------------------------
// E51: inputs for the model arms. Same items, shifts, seeds, channel and
// windows as stream-tuner / stream-verify; the models run in Python on the
// written f32 files (48 kHz). No measurement happens here except D's synthetic
// reading in synth-render.

/// Tuner spec (has `shiftsCents`): per (item, shift) the clean shifted
/// segment from the first buffer's start to its end (`_clean.f32`), per
/// condition the channel output from the same start to the note's end;
/// manifest offsets are relative to the shifted segment. Verifier spec (has
/// `offsets`): per (item, condition) the 0.75 s window and the verifier's own
/// attack (`AttackLocator.lastUsableAttack`, required 80 + 200 ms).
void runStreamRender(
  Map<String, dynamic> spec,
  EvalContext ctx,
  List<int> shard,
  List<int> range,
  String outDir,
  void Function(Map<String, Object?>) emit,
) {
  final sr = ctx.sampleRate;
  final salt = seedSalt(spec);
  final interval = (0.35 * sr).round();
  final bufferLen = (1.6 * sr).round();
  final tunerSpec = spec.containsKey('shiftsCents');
  final verifier = verifierFromSpec(spec);
  final vc = verifier.config;
  final required = (vc.skipAfterOnsetMs * sr / 1000).round() +
      (vc.minAnalysisMs * sr / 1000).round();
  var job = 0, index = -1;
  for (final it in spec['items'] as List) {
    index++;
    final item = it as Map<String, dynamic>;
    if (!inGroups(spec, item)) continue;
    if (job++ % shard[1] != shard[0]) continue;
    final local = (job - 1) ~/ shard[1];
    if (local < range[0] || local >= range[1]) continue;
    final id = item['id'] as String;
    final seg = readF32(item['seg'] as String);
    final base = {
      'id': id,
      'group': item['group'],
      'midi': item['midi'],
      'profile': item['profile'],
      'seedSalt': spec['seedSalt'] ?? 0,
      'item': index,
    };
    if (tunerSpec) {
      final phase = (jitterMs(id, 350, salt) * sr / 1000).round();
      final onset0 = ((item['onsetS'] as num) * sr).round();
      for (final s in spec['shiftsCents'] as List) {
        final shift = (s as num).toDouble();
        final r = math.pow(2, shift / 1200).toDouble();
        final y = shiftPitch(seg, shift);
        final onset = ((item['onsetS'] as num) * sr / r).round();
        final end =
            math.min(y.length, ((item['endS'] as num) * sr / r).round());
        final first = math.max(0, math.min(onset + phase, end) - bufferLen);
        final tag = '$index${shift < 0 ? 'm' : 'p'}${shift.abs().round()}';
        final cleanFile = '$outDir/${tag}_clean.f32';
        writeF32(cleanFile, y, first);
        for (final (ci, c) in ctx.conditions.indexed) {
          final seed = stableHash('$id/$shift/${c.name}/stream$salt');
          final z = ctx.render(y, c, seed);
          final file = '$outDir/${tag}_c$ci.f32';
          writeF32(file, z, first, end);
          emit({
            ...base,
            'kind': 'tuner',
            'shift': shift,
            'cond': c.name,
            'renderSeed': seed,
            'irIndex': irIndexOf(ctx, c, seed),
            'offset': first,
            'onset': onset,
            'onset0': onset0,
            'phase': phase,
            'end': end,
            'interval': interval,
            'bufferLen': bufferLen,
            'instants': analysisInstants(onset, phase, end, interval),
            'file': file,
            'n': end - first,
            'cleanFile': cleanFile,
            'cleanN': y.length - first,
          });
        }
      }
    } else {
      final (:a, :b, :early) = verifyWindow(item, seg.length, sr, salt);
      for (final (ci, c) in ctx.conditions.indexed) {
        final seed = stableHash('$id/${c.name}/stream$salt');
        final z = ctx.render(seg, c, seed);
        final window = z.sublist(a, b);
        final attack = verifier.attackLocator
            .lastUsableAttack(window, sr, requiredSamples: required);
        final file = '$outDir/${index}v_c$ci.f32';
        writeF32(file, window);
        emit({
          ...base,
          'kind': 'verify',
          'cond': c.name,
          'renderSeed': seed,
          'irIndex': irIndexOf(ctx, c, seed),
          'a': a,
          'b': b,
          'earlyMs': early * 1000 / sr,
          'attack': attack,
          'file': file,
          'n': b - a,
        });
      }
    }
  }
}

/// E51 G-abs: E36 synthetic families (spec `instruments`, `seedBase`), the
/// buffer [onset − `bufferPreS`, onset + `bufferPostS`] after the channel,
/// written for the model arms, with D's reading of the same buffer (default
/// tuner of the family's profile) and the true f0.
void runSynthRender(
  Map<String, dynamic> spec,
  EvalContext ctx,
  List<int> shard,
  String outDir,
  void Function(Map<String, Object?>) emit,
) {
  final sr = ctx.sampleRate;
  final seedBase = spec['seedBase'] as int;
  final pre = (spec['bufferPreS'] as num? ?? 0.1).toDouble();
  final post = (spec['bufferPostS'] as num? ?? 1.5).toDouble();
  final a = ((synthPreRollS - pre) * sr).round();
  final b = ((synthPreRollS + post) * sr).round();
  var job = 0;
  for (final inst in spec['instruments'] as List) {
    final i = inst as Map<String, dynamic>;
    final family = i['family'] as String;
    final profile = profileNamed(i['profile'] as String);
    for (final midi in (i['strings'] as List).cast<int>()) {
      for (var rep = 0; rep < (i['repeats'] as int); rep++) {
        if (job++ % shard[1] != shard[0]) continue;
        final n = synthNote(i, seedBase, midi, rep, sr);
        for (final (ci, c) in ctx.conditions.indexed) {
          final renderSeed = n.seed + stableHash(c.name);
          final y = ctx.render(n.x, c, renderSeed);
          final buf = y.sublist(a, math.min(b, y.length));
          final file = '$outDir/${family}_${midi}_${rep}_c$ci.f32';
          writeF32(file, buf);
          final m = tunerFromSpec(spec, profile)
              .measure(buf, sampleRate: sr)
              .measurement;
          emit({
            'kind': 'synth',
            'family': family,
            'profile': profile.name,
            'midi': midi,
            'rep': rep,
            'cond': c.name,
            'seedBase': seedBase,
            'seed': n.seed,
            'renderSeed': renderSeed,
            'irIndex': irIndexOf(ctx, c, renderSeed),
            'truthF0': n.f0,
            'detune': n.detune,
            'b': n.b,
            'file': file,
            'n': buf.length,
            'dMeasured': m != null,
            'dF0': m?.f0Hz,
            'dErr': m == null ? null : centsOf(m.f0Hz, n.f0),
          });
        }
      }
    }
  }
}

/// E45 clean reference: the default tuner (E42) on the clean buffer, so the
/// reference does not move with an arm's tuner options.
PreciseTuner cleanTuner(Map<String, dynamic> spec, PreciseTunerProfile p) =>
    PreciseTuner(profile: p);

/// E46 note gate (controller policy, simulated). A measurement counts only if
/// its attack is inside the buffer, at least [minAttackMs] after the buffer
/// start (E45: 95 % of shown readings came from buffers with no attack in
/// view, attack index 0), at most [maxAgeMs] old at the analysis instant, and
/// within [lockCents] of the first counted reading after that attack; a
/// different attack (more than [sameAttackMs] away) starts a new note.
/// Null when the spec has no gate.
final class NoteGate {
  NoteGate(this.sampleRate, this.maxAgeMs, this.lockCents, this.sameAttackMs,
      this.minAttackMs);

  static NoteGate? fromSpec(Map<String, dynamic> spec, int sampleRate) {
    final g = spec['noteGate'] as Map<String, dynamic>?;
    if (g == null) return null;
    return NoteGate(
        sampleRate,
        g['maxAgeMs'] as int,
        (g['lockCents'] as num).toDouble(),
        g['sameAttackMs'] as int? ?? 50,
        g['minAttackMs'] as int? ?? 0);
  }

  final int sampleRate, maxAgeMs, sameAttackMs, minAttackMs;
  final double lockCents;
  int? _attack;
  double? _f0;

  bool accept(TuningMeasurement m, int bufferStart, int t) {
    final idx = m.attackIndex;
    if (idx == null || idx < minAttackMs * sampleRate / 1000) return false;
    final att = bufferStart + idx;
    if ((t - att) > maxAgeMs * sampleRate / 1000) return false;
    final same = _attack != null &&
        (att - _attack!).abs() <= sameAttackMs * sampleRate / 1000;
    if (!same) {
      // A new attack anchors a new note at its first counted reading.
      _attack = att;
      _f0 = m.f0Hz;
      return true;
    }
    return centsOf(m.f0Hz, _f0!).abs() <= lockCents;
  }
}
