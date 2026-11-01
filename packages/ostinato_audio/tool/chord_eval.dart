// E53 — audio roadmap step A4 (guitar chord verdict + missing/muted strings)
// offline harness.
//
//   dart run tool/chord_eval.dart table    <out.json>
//   dart run tool/chord_eval.dart selftest <spec.json> <out.json>
//   dart run tool/chord_eval.dart run      <spec.json> <outDir> [k/n] [--only <jobId>]
//
// Arms (PLAN §3): K0 = the shipped `GuitarChordDrillEvaluator` +
// `ChordDetector` defaults with the contract numbers from
// `assets/config/audio-contract.json`; K1 = `ChordStringChecker`
// (lib/src/harmony/chord_string_checker.dart, not exported, not wired).
//
// Jobs (written by E53/tools/prep_e53.py):
//  - synth: one voicing × one generation seed. Builds the PLAN §6 variants
//    (TAM ×3, EKSİK-1, SUST-1 ×2, EKSİK-2, FARKLI ≤3, YANLIŞ-PERDE, FAZLA)
//    from `SyntheticString` renders (one render per string, summed), applies
//    each condition (E36 rule, IR = irs[renderSeed % irs.length]) and scores
//    K0 and K1 on the strum window.
//  - noise: 60 noise-only clips per condition × seed, level set by the TAM
//    strum of voicing (k mod 60) (E54 rule).
//  - real: prepared 48 kHz f32 segments (GuitarSet hex/mic, isolated chords)
//    with the strum time and window end given by the prep.
//
// Output (outDir): rows-<k>.jsonl (one row per strum × condition × target ×
// arm; deterministic — no clock enters a row) and timing-<k>.jsonl (per job
// wall times, Stopwatch).
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ostinato_audio/ostinato_audio.dart';
import 'package:ostinato_audio/src/harmony/chord_string_checker.dart';

import 'audio_eval.dart' show Condition, EvalContext, readF32, stableHash;

void main(List<String> args) {
  if (args.length < 2) {
    stderr.writeln('usage: chord_eval.dart <table|selftest|run> ...');
    exit(64);
  }
  switch (args[0]) {
    case 'table':
      File(args[1]).writeAsStringSync(jsonEncode(tableJson()));
    case 'selftest':
      final spec =
          jsonDecode(File(args[1]).readAsStringSync()) as Map<String, dynamic>;
      final r = selfTest(spec);
      File(args[2])
          .writeAsStringSync(const JsonEncoder.withIndent(' ').convert(r));
      stderr.writeln('selftest pass=${r['pass']}');
      if (r['pass'] != true) exit(2);
    case 'run':
      final spec =
          jsonDecode(File(args[1]).readAsStringSync()) as Map<String, dynamic>;
      var shard = [0, 1];
      String? only;
      for (var i = 3; i < args.length; i++) {
        if (args[i] == '--only') {
          only = args[++i];
        } else {
          shard = args[i].split('/').map(int.parse).toList();
        }
      }
      runJobs(spec, args[2], shard, only);
    default:
      stderr.writeln('unknown command ${args[0]}');
      exit(64);
  }
}

// ---------------------------------------------------------------------------
// Voicing table (PLAN §5). Strings 6 → 1, MIDI; null = not played.

final class TableVoicing {
  const TableVoicing(this.id, this.family, this.name, this.midi);
  final String id, family, name;
  final List<int?> midi;
  StringVoicing get voicing => StringVoicing(id, midi);
}

const _pcNames = Chromagram.pitchClassNames;

List<int?> _frets(List<int?> frets) => [
      for (var i = 0; i < 6; i++)
        frets[i] == null ? null : standardTuningMidi[i] + frets[i]!
    ];

List<TableVoicing> buildTable() {
  const open = <String, List<int?>>{
    'Em': [40, 47, 52, 55, 59, 64],
    'Am': [null, 45, 52, 57, 60, 64],
    'E': [40, 47, 52, 56, 59, 64],
    'A': [null, 45, 52, 57, 61, 64],
    'D': [null, null, 50, 57, 62, 66],
    'G3': [43, 47, 50, 55, 59, 67],
    'G4': [43, 47, 50, 55, 62, 67],
    'C': [null, 48, 52, 55, 60, 64],
    'Dm': [null, null, 50, 57, 62, 65],
    'F4': [null, null, 53, 57, 60, 65],
    'Gtop4': [null, null, 55, 59, 62, 67],
    'Atop4': [null, null, 57, 61, 64, 69],
  };
  const openNames = {
    'G3': 'G', 'G4': 'G', 'F4': 'F', 'Gtop4': 'G', 'Atop4': 'A', //
  };
  const ext = <String, List<int?>>{
    'E7': [40, 47, 50, 56, 59, 64],
    'A7': [null, 45, 52, 55, 61, 64],
    'D7': [null, null, 50, 57, 60, 66],
    'B7': [null, 47, 51, 57, 59, 66],
    'Dsus2': [null, null, 50, 57, 62, 64],
    'Dsus4': [null, null, 50, 57, 62, 67],
    'Asus2': [null, 45, 52, 57, 59, 64],
    'Asus4': [null, 45, 52, 57, 62, 64],
    'Fmaj7': [null, null, 53, 57, 60, 64],
    'Cadd9': [null, 48, 52, 55, 62, 64],
    'Am7': [null, 45, 52, 55, 60, 64],
    'Em7': [40, 47, 50, 55, 59, 64],
    'Dm7': [null, null, 50, 57, 60, 65],
    'Cmaj7': [null, 48, 52, 55, 59, 64],
    'Amaj7': [null, 45, 52, 56, 61, 64],
    'Dmaj7': [null, null, 50, 57, 61, 66],
  };
  const slash = <String, List<int?>>{
    'G/B': [null, 47, 50, 55, 59, 67],
    'D/F#': [42, null, 50, 57, 62, 66],
  };
  const power = <String, List<int?>>{
    'E5': [40, 47, null, null, null, null],
    'G5': [43, 50, null, null, null, null],
    'A5': [null, 45, 52, null, null, null],
    'C5': [null, 48, 55, null, null, null],
    'D5': [null, 50, 57, null, null, null],
  };
  const power3 = <String, List<int?>>{
    'E5': [40, 47, 52, null, null, null],
    'A5': [null, 45, 52, 57, null, null],
    'D5': [null, 50, 57, 62, null, null],
  };
  final t = <TableVoicing>[
    for (final e in open.entries)
      TableVoicing('open:${e.key}', 'open', openNames[e.key] ?? e.key, e.value),
    for (final e in ext.entries)
      TableVoicing('ext:${e.key}', 'ext', e.key, e.value),
    for (final e in slash.entries)
      TableVoicing('slash:${e.key}', 'slash', e.key, e.value),
    for (final e in power.entries)
      TableVoicing('pow:${e.key}', 'power', e.key, e.value),
    for (final e in power3.entries)
      TableVoicing('pow3:${e.key}', 'power', e.key, e.value),
  ];
  // E-shape barre, root on string 6 at fret f.
  const eShape = <String, List<int> Function(int)>{
    '': _eMaj, 'm': _eMin, '7': _e7, 'm7': _eM7, //
  };
  const eRoots = <String, List<int>>{
    '': [1, 3, 5, 8], 'm': [1, 3, 5], '7': [1, 3, 5], 'm7': [1, 3, 5], //
  };
  for (final q in eShape.keys) {
    for (final f in eRoots[q]!) {
      final name = '${_pcNames[(4 + f) % 12]}$q';
      t.add(TableVoicing('Ebar:$name', 'Ebarre', name, _frets(eShape[q]!(f))));
    }
  }
  const aRoots = <String, List<int>>{
    '': [1, 2, 3, 5, 7], 'm': [2, 3], '7': [2], 'm7': [2], //
  };
  for (final q in aRoots.keys) {
    for (final f in aRoots[q]!) {
      final name = '${_pcNames[(9 + f) % 12]}$q';
      t.add(TableVoicing('Abar:$name', 'Abarre', name, _frets(aShape(q, f))));
    }
  }
  return t;
}

List<int> _eMaj(int f) => [f, f + 2, f + 2, f + 1, f, f];
List<int> _eMin(int f) => [f, f + 2, f + 2, f, f, f];
List<int> _e7(int f) => [f, f + 2, f, f + 1, f, f];
List<int> _eM7(int f) => [f, f + 2, f, f, f, f];
List<int?> aShape(String q, int f) => switch (q) {
      '' => [null, f, f + 2, f + 2, f + 2, f],
      'm' => [null, f, f + 2, f + 2, f + 1, f],
      '7' => [null, f, f + 2, f, f + 2, f],
      'm7' => [null, f, f + 2, f, f + 1, f],
      _ => throw ArgumentError(q),
    };
List<int?> eShapeFrets(String q, int f) => switch (q) {
      '' => _eMaj(f),
      'm' => _eMin(f),
      '7' => _e7(f),
      'm7' => _eM7(f),
      _ => throw ArgumentError(q),
    };

final table = buildTable();
final tableById = {for (final v in table) v.id: v};

/// PLAN §4.9: lessons that accept several shapes. Only G (3 or 4 fingers).
const allowedGroups = [
  ['open:G3', 'open:G4'],
];

List<TableVoicing> allowedFor(String id) {
  for (final g in allowedGroups) {
    if (g.contains(id)) return [for (final x in g) tableById[x]!];
  }
  return [tableById[id]!];
}

/// K0 name of a pitch-class set: the unique major / minor / dominant-7
/// template with exactly these pitch classes, else null (outside K0's
/// vocabulary).
String? k0NameOf(Set<int> pcs) {
  final hits = [
    for (final t in ChordTemplate.all())
      if ({for (final i in t.intervals) (t.rootPitchClass + i) % 12}
              .containsAll(pcs) &&
          pcs.length == t.intervals.length)
        t.name
  ];
  return hits.length == 1 ? hits.first : null;
}

/// isolated-guitar-chords expected voicing (PLAN §6): the table's open shape
/// when there is one (G: 3 or 4 fingers), else an E-shape barre when the
/// root sits at fret ≤ 4 on string 6, else an A-shape barre.
List<StringVoicing> igcAllowed(int rootPc, bool minor) {
  final name = '${_pcNames[rootPc]}${minor ? 'm' : ''}';
  const openFor = {
    'E': ['open:E'], 'A': ['open:A'], 'D': ['open:D'], 'C': ['open:C'], //
    'G': ['open:G3', 'open:G4'], 'F': ['open:F4'],
    'Em': ['open:Em'], 'Am': ['open:Am'], 'Dm': ['open:Dm'],
  };
  final o = openFor[name];
  if (o != null) return [for (final id in o) tableById[id]!.voicing];
  final q = minor ? 'm' : '';
  final f6 = (rootPc - 4) % 12;
  if (f6 <= 4) {
    return [StringVoicing('igcE:$name', _frets(eShapeFrets(q, f6)))];
  }
  return [StringVoicing('igcA:$name', _frets(aShape(q, (rootPc - 9) % 12)))];
}

({int root, bool minor}) parseLabel(String label) {
  final minor = label.endsWith('m');
  final rootName = minor ? label.substring(0, label.length - 1) : label;
  final root = _pcNames.indexOf(rootName);
  if (root < 0) throw ArgumentError('label $label');
  return (root: root, minor: minor);
}

Map<String, Object?> tableJson() => {
      'voicings': [
        for (final v in table)
          {
            'id': v.id,
            'family': v.family,
            'name': v.name,
            'midi': v.midi,
            'pcs': (v.voicing.pitchClasses.toList()..sort()),
            'k0Name': k0NameOf(v.voicing.pitchClasses),
            'allowed': [for (final a in allowedFor(v.id)) a.id],
          }
      ],
      'igc': {
        for (var r = 0; r < 12; r++)
          for (final m in [false, true])
            '${_pcNames[r]}${m ? 'm' : ''}': [
              for (final v in igcAllowed(r, m)) {'id': v.id, 'midi': v.midi}
            ]
      },
    };

/// Every pitch must be playable on its own string at fret 0–12 (PLAN §9.3).
List<String> tableProblems() {
  final out = <String>[];
  final ids = <String>{};
  for (final v in table) {
    if (!ids.add(v.id)) out.add('duplicate id ${v.id}');
    if (v.voicing.playedIndices.length < 2) out.add('${v.id}: < 2 strings');
    for (var i = 0; i < 6; i++) {
      final m = v.midi[i];
      if (m == null) continue;
      final fret = m - standardTuningMidi[i];
      if (fret < 0 || fret > 12) out.add('${v.id}: string ${6 - i} fret $fret');
    }
  }
  if (table.length != 60) {
    out.add('table has ${table.length} voicings, plan ≈ 60');
  }
  return out;
}

// ---------------------------------------------------------------------------
// Synthetic strums (PLAN §6).

const strumLeadS = 0.1;
const clipS = 1.2;

final class StringParams {
  StringParams(this.b, this.pluck, this.decay, this.levelDb, this.glide,
      this.pol, this.seed);
  final double b, pluck, decay, levelDb, glide, pol;
  final int seed;
}

final class StrumParams {
  StrumParams(this.strings, this.up, this.spreadMs, this.tuneCents);
  final List<StringParams> strings; // index 0 = string 6
  final bool up;
  final double spreadMs, tuneCents;
}

double _u(math.Random r, double a, double b) => a + (b - a) * r.nextDouble();

/// Draws parameters for all six strings (fixed RNG consumption).
StrumParams drawStrum(math.Random r) {
  final ss = <StringParams>[
    for (var i = 0; i < 6; i++)
      StringParams(
        i < 3 ? _u(r, 1.7e-4, 3e-4) : _u(r, 4e-5, 3e-4), // bass: upper half
        _u(r, 0.08, 0.25),
        _u(r, 0.8, 3.0),
        _u(r, -6, 6),
        _u(r, 0, 2),
        _u(r, 0, 0.3),
        r.nextInt(1 << 30),
      )
  ];
  final up = r.nextDouble() < 0.25;
  final spread = _u(r, 8, 15);
  final tune = const [0.0, 15.0, -15.0][r.nextInt(3)];
  return StrumParams(ss, up, spread, tune);
}

/// One strum: [notes] (string index → MIDI) rendered with [p], strings in
/// [muted] decaying in 30 ms. The sweep starts at the first string of
/// [sweep] in the strum direction; string i starts |i − start| · spread later.
final class StrumRenderer {
  StrumRenderer(this.sampleRate);
  final int sampleRate;
  final _cache = <String, Float64List>{};

  Float64List string(StrumParams p, int i, int midi, bool muted, int onset) {
    final key = '${identityHashCode(p)}/$i/$midi/$muted/$onset';
    return _cache.putIfAbsent(key, () {
      final s = p.strings[i];
      final f0 = ChordStringChecker.midiHz(midi) *
          math.pow(2, p.tuneCents / 1200).toDouble();
      return SyntheticString.pluck(
        f0Hz: f0,
        sampleRate: sampleRate,
        seconds: clipS - onset / sampleRate,
        inharmonicityB: s.b,
        pluckPosition: s.pluck,
        fundamentalDecaySeconds: muted ? 0.03 : s.decay,
        glideCents: s.glide,
        polarizationDetuneCents: 1.0,
        polarizationLevel: s.pol,
        pickNoiseLevel: 0.05,
        maxPartialHz: 5000,
        peak: 0.12 * math.pow(10, s.levelDb / 20).toDouble(),
        seed: s.seed,
      );
    });
  }

  Float64List render(
      StrumParams p, Map<int, int> notes, Set<int> muted, Iterable<int> sweep) {
    final sw = sweep.toList()..sort();
    final start = p.up ? sw.last : sw.first;
    final out = Float64List((clipS * sampleRate).round());
    for (final e in notes.entries) {
      final onset = ((strumLeadS + (e.key - start).abs() * p.spreadMs / 1000) *
              sampleRate)
          .round();
      final x = string(p, e.key, e.value, muted.contains(e.key), onset);
      for (var j = 0; j < x.length && onset + j < out.length; j++) {
        out[onset + j] += x[j];
      }
    }
    return out;
  }

  void clear() => _cache.clear();
}

final class Variant {
  Variant(this.name, this.rep, this.audio, this.meta);
  final String name;
  final int rep;
  final Float64List audio;
  final Map<String, Object?> meta;
}

Map<int, int> notesOf(List<int?> midi) => {
      for (var i = 0; i < 6; i++)
        if (midi[i] != null) i: midi[i]!
    };

/// PLAN §6 variants of [v] for generation seed [gseed]. Expected (target) is
/// always [v]; FARKLI plays a neighbour.
List<Variant> synthVariants(TableVoicing v, int gseed, StrumRenderer r) {
  final rng = math.Random(stableHash('$gseed/${v.id}'));
  final p0 = drawStrum(rng);
  final p1 = drawStrum(rng);
  final p2 = drawStrum(rng);
  final notes = notesOf(v.midi);
  final played = notes.keys.toList()..sort();
  final out = <Variant>[];
  Map<String, Object?> sm(StrumParams p) =>
      {'tuneCents': p.tuneCents, 'up': p.up};
  for (final (rep, p) in [(0, p0), (1, p1), (2, p2)]) {
    out.add(Variant('TAM', rep, r.render(p, notes, const {}, played), sm(p)));
  }
  for (final s in played) {
    out.add(Variant(
        'EKSIK1', 0, r.render(p0, Map.of(notes)..remove(s), const {}, played), {
      'removed': [6 - s],
      ...sm(p0),
    }));
  }
  final order = List.of(played)..shuffle(rng);
  for (var k = 0; k < math.min(2, order.length); k++) {
    out.add(Variant('SUST1', k, r.render(p0, notes, {order[k]}, played), {
      'muted': [6 - order[k]],
      ...sm(p0),
    }));
  }
  if (played.length >= 4) {
    final pr = List.of(played)..shuffle(rng);
    final pair = [pr[0], pr[1]]..sort();
    out.add(Variant(
        'EKSIK2',
        0,
        r.render(p0, Map.of(notes)..removeWhere((k, _) => pair.contains(k)),
            const {}, played),
        {
          'removed': [for (final s in pair) 6 - s],
          ...sm(p0),
        }));
  }
  // FARKLI: neighbours by pitch-class symmetric difference 1–2 (else 3).
  final pcs = v.voicing.pitchClasses;
  final group = {for (final a in allowedFor(v.id)) a.id};
  int diff(TableVoicing w) {
    final q = w.voicing.pitchClasses;
    return pcs.difference(q).length + q.difference(pcs).length;
  }

  var nb = [
    for (final w in table)
      if (!group.contains(w.id) && diff(w) >= 1 && diff(w) <= 2) w
  ];
  if (nb.isEmpty) {
    nb = [
      for (final w in table)
        if (!group.contains(w.id) && diff(w) == 3) w
    ];
  }
  nb.shuffle(rng);
  for (var k = 0; k < math.min(3, nb.length); k++) {
    final w = nb[k];
    final pw = drawStrum(rng);
    final nw = notesOf(w.midi);
    out.add(Variant('FARKLI', k, r.render(pw, nw, const {}, nw.keys), {
      'played': w.id,
      'playedPcs': (w.voicing.pitchClasses.toList()..sort()),
      ...sm(pw),
    }));
  }
  // YANLIŞ-PERDE: one string ±1 semitone, landing outside the chord's
  // pitch classes, still playable (fret ≥ 0).
  final ws = List.of(played)..shuffle(rng);
  for (final s in ws) {
    final m = notes[s]!;
    final opts = [
      for (final d in const [1, -1])
        if (!pcs.contains((m + d) % 12) && m + d >= standardTuningMidi[s]) d
    ];
    if (opts.isEmpty) continue;
    final d = opts[opts.length == 1 ? 0 : rng.nextInt(opts.length)];
    out.add(Variant('YANLIS', 0,
        r.render(p0, Map.of(notes)..[s] = m + d, const {}, played), {
      'wrong': [6 - s, m + d],
      ...sm(p0),
    }));
    break;
  }
  // FAZLA: the unplayed open string next to the played block, bass side first.
  final lo = played.first, hi = played.last;
  final extra = lo > 0 ? lo - 1 : (hi < 5 ? hi + 1 : null);
  if (extra != null) {
    final n = Map.of(notes)..[extra] = standardTuningMidi[extra];
    out.add(Variant('FAZLA', 0, r.render(p0, n, const {}, n.keys), {
      'extraString': 6 - extra,
      'extraMidi': standardTuningMidi[extra],
      'extraInChord': pcs.contains(standardTuningMidi[extra] % 12),
      ...sm(p0),
    }));
  }
  return out;
}

/// The TAM rep-0 strum of [v] at [gseed] (noise-clip level reference).
Float64List referenceStrum(TableVoicing v, int gseed, StrumRenderer r) {
  final rng = math.Random(stableHash('$gseed/${v.id}'));
  final p0 = drawStrum(rng);
  final notes = notesOf(v.midi);
  return r.render(p0, notes, const {}, notes.keys);
}

// ---------------------------------------------------------------------------
// Channel.

/// Noise-only clip (E54 rule, `voice_eval.dart`): the channel's noise at the
/// level the strum [ref] would set, then low cut / AGC / limiter / quantiser.
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
// Scoring.

String verdictCode(ChordVerdict v) => switch (v) {
      ChordVerdict.correct => 'DOGRU',
      ChordVerdict.missingString => 'EKSIK_TEL',
      ChordVerdict.differentChord => 'FARKLI_AKOR',
      ChordVerdict.couldNotHear => 'DUYAMADIM',
    };

final class Window {
  const Window(this.strumS, this.endS);
  final double strumS, endS;
}

final class Scorer {
  Scorer(this.spec)
      : sampleRate = spec['sampleRate'] as int,
        k1 = _k1(spec),
        contract = GuitarChordDrillContract.fromJson(
            File(spec['contractPath'] as String).readAsStringSync()) {
    final w = spec['window'] as Map<String, dynamic>;
    startS = (w['startMs'] as num) / 1000;
    endS = (w['endMs'] as num) / 1000;
    gapS = (w['gapMs'] as num) / 1000;
    minS = (w['minMs'] as num) / 1000;
    earlyS = (w['earlyMs'] as num) / 1000;
    c0FloorDb = (spec['c0FloorDb'] as num).toDouble();
  }

  static ChordStringChecker _k1(Map<String, dynamic> spec) {
    final k = spec['k1'] as Map<String, dynamic>;
    double d(String n) => (k[n] as num).toDouble();
    return ChordStringChecker(
      sampleRate: spec['sampleRate'] as int,
      fftSize: k['fftSize'] as int,
      minHz: d('minHz'),
      maxHz: d('maxHz'),
      midiLow: k['midiLow'] as int,
      midiHigh: k['midiHigh'] as int,
      partials: k['partials'] as int,
      inharmonicityB: d('B'),
      sigmaCents: d('sigmaCents'),
      thetaRel: d('thetaRel'),
      thetaX: d('thetaX'),
      tauFit: d('tauFit'),
      levelAboveFloorDb: d('levelAboveFloorDb'),
      tuningSearchCents: d('tuningSearchCents'),
      tuningStepCents: d('tuningStepCents'),
      evidenceBandCents: d('evidenceBandCents'),
      evidencePartials: k['evidencePartials'] as int,
      sharedToleranceCents: d('sharedToleranceCents'),
      sharedMaxPartial: k['sharedMaxPartial'] as int,
    );
  }

  final Map<String, dynamic> spec;
  final int sampleRate;
  final ChordStringChecker k1;
  final GuitarChordDrillContract contract;
  late final double startS, endS, gapS, minS, earlyS, c0FloorDb;
  final swK1 = Stopwatch(), swK0 = Stopwatch();
  var nK1 = 0, nK0 = 0;

  /// PLAN §4.1 window in samples, or null (< minMs → strum excluded).
  /// [winEndS]: the prep's end limit (next strum − gap), absolute seconds.
  (int, int)? window(double strumS, double? winEndS, int n) {
    final a = ((strumS + startS) * sampleRate).round();
    var endT = strumS + endS;
    if (winEndS != null) endT = math.min(endT, winEndS);
    final b = math.min(n, (endT * sampleRate).round());
    if ((b - a) / sampleRate < minS - 1e-9) return null;
    return (a, b);
  }

  /// K1 + K0 rows for one rendered strum.
  List<Map<String, Object?>> score(
    Float64List z,
    double floorDb,
    double strumS,
    double? endLimitS,
    List<StringVoicing> allowed,
    Map<String, Object?> base, {
    String? k0Name,
  }) {
    final w = window(strumS, endLimitS, z.length);
    if (w == null) {
      return [
        {...base, 'arm': 'K1', 'excluded': true},
      ];
    }
    final win = z.sublist(w.$1, w.$2);
    final e0 = (strumS * sampleRate).round();
    final early =
        z.sublist(e0, math.min(z.length, e0 + (earlyS * sampleRate).round()));
    swK1.start();
    final r =
        k1.check(win, roomFloorDb: floorDb, allowed: allowed, early: early);
    final ee = r.fit == null ? null : k1.earlyEnergies(early);
    swK1.stop();
    nK1++;
    final j = r.decisive;
    final rows = <Map<String, Object?>>[
      {
        ...base,
        'arm': 'K1',
        'verdict': verdictCode(r.verdict),
        'gate': r.gate,
        'level': r.levelDb,
        'floor': floorDb,
        'r2': r.r2.isNaN ? null : r.r2,
        'winS': (w.$2 - w.$1) / sampleRate,
        'chosen': r.chosen,
        'allowed': [for (final v in allowed) v.midi],
        if (j != null) ...{
          'strings': [
            for (final s in j.strings)
              [
                s.string,
                s.midi,
                s.activation,
                s.heard,
                s.possiblyMuted,
                s.shared,
                s.evidence
              ]
          ],
          'unexpected': [
            for (final u in j.unexpected) [u.$1, u.$2]
          ],
          'extra': [
            for (final x in j.extra) [x.$1, x.$2, x.$3]
          ],
        },
        if (r.verdict == ChordVerdict.differentChord) ...nearest(r.fit!),
        if (r.fit != null) 'act': r.fit!.activations,
        if (r.fit != null) 'fl': r.fit!.floor,
        if (r.fit != null) 'offset': r.fit!.offsetCents,
        if (r.fit != null) 'ev': r.fit!.evidence,
        if (ee != null) 'early': ee,
      }
    ];
    if (k0Name != null) {
      swK0.start();
      final ev = GuitarChordDrillEvaluator(contract: contract);
      final g = ev.evaluate(win,
          sampleRate: sampleRate,
          tStartUs: 0,
          roomFloorDb: floorDb,
          expectedChordName: k0Name);
      swK0.stop();
      nK0++;
      rows.add({
        ...base,
        'arm': 'K0',
        'k0Expected': k0Name,
        'verdict': switch (g) {
          DrillCorrect() => 'DOGRU',
          DrillIncorrect() => 'FARKLI_AKOR',
          _ => 'DUYAMADIM',
        },
        'k0': switch (g) {
          DrillCorrect(:final score) => ['Correct', k0Name, score],
          DrillIncorrect(:final detectedName, :final score) => [
              'Incorrect',
              detectedName,
              score
            ],
          DrillUnclear() => ['Unclear', null, null],
          DrillAwaitingSound() => ['AwaitingSound', null, null],
          DrillInAttackWindow() => ['InAttackWindow', null, null],
        },
      });
    }
    return rows;
  }

  /// Nearest chord name (PLAN §2, FARKLI_AKOR only): heard pitches =
  /// a_p ≥ θ_rel · max_p a_p; the table chord whose pitch-class set has the
  /// highest Jaccard overlap (first in table order on ties).
  Map<String, Object?> nearest(SpectrumFit fit) {
    var amax = 0.0;
    for (final a in fit.activations) {
      amax = math.max(amax, a);
    }
    final h = <int>{
      for (var i = 0; i < fit.activations.length; i++)
        if (amax > 0 && fit.activations[i] >= k1.thetaRel * amax)
          (k1.midiLow + i) % 12
    };
    TableVoicing? best;
    var bestJ = -1.0;
    for (final v in table) {
      final q = v.voicing.pitchClasses;
      final inter = q.intersection(h).length;
      final uni = q.union(h).length;
      final jac = uni == 0 ? 0.0 : inter / uni;
      if (jac > bestJ) {
        bestJ = jac;
        best = v;
      }
    }
    return {
      'nearest': best?.name,
      'nearestPcs':
          best == null ? null : (best.voicing.pitchClasses.toList()..sort()),
    };
  }
}

// ---------------------------------------------------------------------------
// Runner.

void runJobs(
    Map<String, dynamic> spec, String outDir, List<int> shard, String? only) {
  Directory(outDir).createSync(recursive: true);
  final ctx = EvalContext.fromSpec(spec);
  final sr = ctx.sampleRate;
  final conds = {for (final c in ctx.conditions) c.name: c};
  final sc = Scorer(spec);
  final tag = only == null ? '${shard[0]}' : 'only';
  final rowsOut = File('$outDir/rows-$tag.jsonl').openWrite();
  final timing = File('$outDir/timing-$tag.jsonl').openWrite();
  final sw = Stopwatch()..start();
  var idx = 0, done = 0;

  double floorOf(List<double> x, Condition c, int seed) =>
      c.clean ? sc.c0FloorDb : ctx.floorDb(x, c, seed);

  for (final j in (spec['jobs'] as List).cast<Map<String, dynamic>>()) {
    final id = j['id'] as String;
    if (only != null) {
      if (id != only) continue;
    } else if (idx++ % shard[1] != shard[0]) {
      continue;
    }
    final swJob = Stopwatch()..start();
    final k1Before = sc.swK1.elapsedMicroseconds,
        k0Before = sc.swK0.elapsedMicroseconds;
    final n1 = sc.nK1, n0 = sc.nK0;
    var swGen = 0, swCh = 0;
    final jc = [
      for (final c in j['conds'] as List)
        (conds[(c as List)[0] as String]!, c[1] as int)
    ];
    void emit(Map<String, Object?> row) => rowsOut.writeln(jsonEncode(row));

    switch (j['kind'] as String) {
      case 'synth':
        final gseed = j['gseed'] as int;
        final v = tableById[j['voicing'] as String]!;
        final allowed = [for (final a in allowedFor(v.id)) a.voicing];
        final k0 = k0NameOf(v.voicing.pitchClasses);
        final t0 = Stopwatch()..start();
        final r = StrumRenderer(sr);
        final vars = synthVariants(v, gseed, r);
        r.clear();
        swGen += t0.elapsedMicroseconds;
        for (final va in vars) {
          for (final (c, seed) in jc) {
            final key = 'syn/$gseed/${v.id}/${va.name}/${va.rep}';
            final rs = stableHash('$key/${c.name}/$seed');
            final tc = Stopwatch()..start();
            final z = ctx.render(va.audio, c, rs);
            final fl = floorOf(va.audio, c, rs);
            swCh += tc.elapsedMicroseconds;
            for (final row in sc.score(
                z,
                fl,
                strumLeadS,
                null,
                allowed,
                {
                  'job': id,
                  'set': 'syn',
                  'gseed': gseed,
                  'voicing': v.id,
                  'family': v.family,
                  'variant': va.name,
                  'rep': va.rep,
                  'cond': c.name,
                  'seed': seed,
                  'renderSeed': rs,
                  'target': 'exp',
                  ...va.meta,
                },
                k0Name: k0)) {
              emit(row);
            }
          }
        }
      case 'noise':
        final gseed = j['gseed'] as int;
        final nClips = j['n'] as int;
        final n = (clipS * sr).round();
        for (var k = 0; k < nClips; k++) {
          final v = table[k % table.length];
          final t0 = Stopwatch()..start();
          final ref = referenceStrum(v, gseed, StrumRenderer(sr));
          swGen += t0.elapsedMicroseconds;
          for (final (c, seed) in jc) {
            final rs = stableHash('noise/$gseed/$k/${c.name}/$seed');
            final tc = Stopwatch()..start();
            final z = noiseOnlyRender(ctx, ref, n, c, rs);
            final fl = floorOf(ref, c, rs);
            swCh += tc.elapsedMicroseconds;
            for (final row in sc.score(
                z,
                fl,
                strumLeadS,
                null,
                [for (final a in allowedFor(v.id)) a.voicing],
                {
                  'job': id,
                  'set': 'noise',
                  'gseed': gseed,
                  'clip': k,
                  'voicing': v.id,
                  'cond': c.name,
                  'seed': seed,
                  'renderSeed': rs,
                  'target': 'exp',
                },
                k0Name: k0NameOf(v.voicing.pitchClasses))) {
              emit(row);
            }
          }
        }
      case 'real':
        final strumS = (j['strumS'] as num).toDouble();
        final endS = (j['winEndS'] as num?)?.toDouble();
        final targets = <(String, List<StringVoicing>)>[];
        if (j['igcLabel'] != null) {
          final l = parseLabel(j['igcLabel'] as String);
          targets.add(('exp', igcAllowed(l.root, l.minor)));
          targets.add(('par', igcAllowed(l.root, !l.minor)));
        } else {
          targets.add((
            'exp',
            [
              for (final (i, m) in (j['allowed'] as List).indexed)
                StringVoicing('real$i', [for (final x in m as List) x as int?])
            ]
          ));
        }
        for (final seg
            in (j['segments'] as List).cast<Map<String, dynamic>>()) {
          final x = readF32(seg['path'] as String);
          for (final (c, seed) in jc) {
            final key = '$id/${seg['variant']}';
            final rs = stableHash('$key/${c.name}/$seed');
            final tc = Stopwatch()..start();
            final z = ctx.render(x, c, rs);
            final fl = floorOf(x, c, rs);
            swCh += tc.elapsedMicroseconds;
            for (final (tname, allowed) in targets) {
              for (final row in sc.score(
                  z,
                  fl,
                  strumS,
                  endS,
                  allowed,
                  {
                    'job': id,
                    'set': j['set'],
                    'track': j['track'],
                    'variant': seg['variant'],
                    'cond': c.name,
                    'seed': seed,
                    'renderSeed': rs,
                    'target': tname,
                    if (j['igcLabel'] != null) 'label': j['igcLabel'],
                    ...((seg['meta'] as Map<String, dynamic>?) ?? const {}),
                  },
                  k0Name: k0NameOf(allowed.first.pitchClasses))) {
                emit(row);
              }
            }
          }
        }
      default:
        throw ArgumentError('job $id: kind ${j['kind']}');
    }
    timing.writeln(jsonEncode({
      'job': id,
      'ms': swJob.elapsedMicroseconds / 1000,
      'genMs': swGen / 1000,
      'channelMs': swCh / 1000,
      'k1Ms': (sc.swK1.elapsedMicroseconds - k1Before) / 1000,
      'k1N': sc.nK1 - n1,
      'k0Ms': (sc.swK0.elapsedMicroseconds - k0Before) / 1000,
      'k0N': sc.nK0 - n0,
    }));
    done++;
  }
  rowsOut.close();
  timing.close();
  stderr
      .writeln('chord-eval shard $tag: $done jobs in ${sw.elapsed.inSeconds}s');
}

// ---------------------------------------------------------------------------
// Pre-run checks run by the harness (PLAN §9.1–9.3).

Map<String, Object?> selfTest(Map<String, dynamic> spec) {
  final k1 = Scorer._k1(spec);
  // §9.1 dictionary identity: S = D·a for known a → NNLS returns a (1e-6,
  // relative to max a); removing one string's atom → that string not heard.
  final rng = math.Random(53);
  var maxErr = 0.0, dropOk = 0, dropN = 0, sharedN = 0;
  final cases = <Map<String, Object?>>[];
  for (final v in table) {
    final a = Float64List(k1.nPitch);
    for (final m in v.midi) {
      if (m != null) a[m - k1.midiLow] = 0.5 + rng.nextDouble();
    }
    final floor = 0.01 * rng.nextDouble();
    final fit = k1.fitSpectrum(k1.synthesize(a, floor));
    var amax = 0.0;
    for (final x in a) {
      amax = math.max(amax, x);
    }
    var err = (fit.floor - floor).abs() / amax;
    for (var i = 0; i < a.length; i++) {
      err = math.max(err, (fit.activations[i] - a[i]).abs() / amax);
    }
    maxErr = math.max(maxErr, err);
    final full = k1.judge(fit, v.voicing);
    for (final i in v.voicing.playedIndices) {
      final b = Float64List.fromList(a)..[v.midi[i]! - k1.midiLow] = 0;
      final f2 = k1.fitSpectrum(k1.synthesize(b, floor));
      final jd = k1.judge(f2, v.voicing);
      final st = jd.strings.firstWhere((s) => s.string == 6 - i);
      dropN++;
      // Shared strings have no evidence of their own and stay heard by design
      // (PLAN §13); every other dropped string must be not heard.
      final ok = (st.shared ? st.heard : !st.heard) &&
          f2.offsetCents == 0 &&
          jd.strings.where((s) => s.string != 6 - i).every((s) => s.heard);
      if (st.shared) sharedN++;
      if (ok) dropOk++;
    }
    cases.add({
      'voicing': v.id,
      'err': err,
      'offset': fit.offsetCents,
      'full': verdictCode(full.verdict)
    });
  }
  final c1 = {
    'maxRelErr': maxErr,
    'dropStringNotHeard': dropOk,
    'dropN': dropN,
    'dropShared': sharedN,
    'offsetZeroOnExact': cases.every((c) => c['offset'] == 0.0),
    'fullCorrect': cases.where((c) => c['full'] == 'DOGRU').length,
    'pass': maxErr <= 1e-6 &&
        dropOk == dropN &&
        cases.every((c) => c['offset'] == 0.0) &&
        cases.every((c) => c['full'] == 'DOGRU'),
  };
  // §9.2 harness K0 path == ChordDetector on the shipped test fixtures.
  final sc = Scorer(spec);
  final fx = <Map<String, Object?>>[];
  var k0ok = true;
  for (final e in SyntheticTone.openGuitarChords.entries) {
    final x = SyntheticTone.chord(
        midiNotes: e.value, sampleRate: sc.sampleRate, seconds: 1.5);
    final z = Float64List.fromList(x);
    final rows = sc.score(
        z,
        -120,
        0.0,
        null,
        [
          StringVoicing('fx', [for (var i = 0; i < 6; i++) null])
        ],
        {},
        k0Name: e.key);
    final k0row = rows.firstWhere((r) => r['arm'] == 'K0');
    final w = sc.window(0.0, null, z.length)!;
    final direct = const ChordDetector()
        .detect(z.sublist(w.$1, w.$2), sampleRate: sc.sampleRate);
    final harnessName = (k0row['k0'] as List)[1];
    final same = direct?.chord.name == harnessName ||
        (direct == null && harnessName == null);
    k0ok &= same;
    fx.add(
        {'chord': e.key, 'harness': k0row['k0'], 'direct': direct?.chord.name});
  }
  // §9.3 voicing table.
  final problems = tableProblems();
  return {
    'c1_identity': c1,
    'c2_k0_fixtures': {'fixtures': fx, 'pass': k0ok},
    'c3_table': {
      'voicings': table.length,
      'problems': problems,
      'pass': problems.isEmpty
    },
    'k1': spec['k1'],
    'pass': c1['pass'] == true && k0ok && problems.isEmpty,
  };
}
