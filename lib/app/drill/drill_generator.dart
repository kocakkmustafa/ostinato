import 'dart:math' as math;

import '../curriculum/v1_lesson.dart';
import 'drill_sound.dart';
import 'drill_theory.dart';

/// F2.6 — drill questions generated at run time from `practice.drill.params`
/// (lesson guide §3: the file carries no answer key). Pure Dart and seeded:
/// the same drill and seed give the same questions, so a test can replay a
/// session exactly. Slice (a) covers the silent theory sets; [supports] says
/// which drills this build can run.

/// What the question shows. The screen turns [kind] into localized copy.
enum DrillPromptKind {
  /// "Which note is this?" with one marked fret.
  noteAtFret,

  /// "Where is {note} on string {n}?"; options are fret numbers.
  fretOfNote,

  /// "Other name for {note}?" with the marked fret.
  enharmonic,

  /// "Which step of the {key} major scale is this?"
  scaleStep,

  /// "Which note of the {key} minor pentatonic is this?"
  pentatonicNote,

  /// "Which notes make {chord}?"
  chordTones,

  /// "In {key} major, which chord is {numeral}?"
  romanNumeral,

  /// "Which is line {n} of the 12-bar blues?"
  bluesLine,

  /// "Which chord is in bar {n} of the 12-bar blues?"
  bluesBar,

  /// F2.6b, heard: "Was the second part faster, slower or the same?"
  tempoCompare,

  /// "Was the second note higher or lower?"
  pitchDirection,

  /// "How did the three notes move?" (`up-down` …)
  pitchContour,

  /// "Were the two notes the same or different?"
  sameDifferent,

  /// "Which interval was it?" (`M3`, `P5` …)
  intervalName,

  /// "Which chord quality was it?" (`major`, `minor`, `dominant7`)
  chordQuality,
}

/// Prompts that are heard: the screen shows Play and "play my answer".
bool isHeard(DrillPromptKind k) => switch (k) {
  DrillPromptKind.tempoCompare ||
  DrillPromptKind.pitchDirection ||
  DrillPromptKind.pitchContour ||
  DrillPromptKind.sameDifferent ||
  DrillPromptKind.intervalName ||
  DrillPromptKind.chordQuality => true,
  _ => false,
};

/// One marked position on the fretboard diagram.
typedef FretMark = ({int string, int fret});

final class DrillQuestion {
  const DrillQuestion({
    required this.kind,
    required this.values,
    required this.options,
    required this.answer,
    this.marks = const [],
    this.fretWindow,
    this.sound,
    this.optionSounds,
  });

  final DrillPromptKind kind;

  /// Copy values (`v0`, `v1`): technical names (`C#`, `A7`, `IV`) or numbers.
  final Map<String, Object> values;

  /// Option labels in display order. Note-like labels are technical names
  /// the screen localizes (`C#` → `C# (Do#)` in Turkish).
  final List<String> options;

  /// Index of the expected option in [options].
  final int answer;

  /// Fretboard marks to draw; empty = no diagram.
  final List<FretMark> marks;

  /// Frets the diagram shows, `(first, last)`; null = no diagram.
  final (int, int)? fretWindow;

  /// What the question plays (heard kinds only).
  final DrillSound? sound;

  /// "Play my answer": per option, what that answer would have sounded like
  /// (null where it cannot be heard, e.g. "same" in tempo comparison).
  final List<DrillSound?>? optionSounds;

  String get expected => options[answer];

  DrillQuestion withSound(DrillSound sound) => DrillQuestion(
    kind: kind,
    values: values,
    options: options,
    answer: answer,
    marks: marks,
    fretWindow: fretWindow,
    sound: sound,
  );
}

/// Sets this slice can generate, per drill type.
const Map<String, Set<String>> _supportedSets = {
  'diagram_match': {
    'fretboard_natural_notes',
    'fretboard_root_names',
    'enharmonic_names',
    'major_scale_steps',
    'pentatonic_roots',
    'triad_tones',
  },
  'symbol_match': {'roman_numeral_chords', 'seventh_chord_spelling'},
};

/// Whether this build can run [drill] (guitar fretboard sets only for
/// `major_scale_steps`; keyboard diagrams come with the ear course).
bool supportsDrill(V1Drill drill) {
  final p = drill.params;
  switch (drill.type) {
    case 'tempo_compare' || 'pitch_direction' || 'same_different':
      return true;
    case 'interval_name':
      // Staff display (piano) and cadence/melody context come with (c).
      return p['display'] == null &&
          p['context'] == null &&
          p['cadence'] != true &&
          (p['intervals'] as List?)?.every(
                (i) => intervalSemitones.containsKey(i),
              ) ==
              true;
    case 'triad_quality':
      return p['inversions'] != true &&
          (p['qualities'] as List?)?.every(
                (q) => const {'major', 'minor', 'dominant7'}.contains(q),
              ) ==
              true;
  }
  if (drill.type == 'ordering') {
    return drill.params['form'] == 'twelve_bar_blues';
  }
  final set = drill.params['set'];
  if (set is! String || !(_supportedSets[drill.type]?.contains(set) ?? false)) {
    return false;
  }
  final diagram = drill.params['diagram'];
  return diagram == null || diagram == 'fretboard';
}

/// [V1Drill.count] questions for [drill]. Throws [UnsupportedError] when
/// [supportsDrill] is false and [FormatException] for unusable params.
List<DrillQuestion> generateDrill(V1Drill drill, {required int seed}) {
  if (!supportsDrill(drill)) {
    throw UnsupportedError('Drill not in this build: ${drill.type}');
  }
  final g = _Gen(drill.params, math.Random(seed));
  final make = switch (switch (drill.type) {
    'ordering' => 'twelve_bar_blues',
    'tempo_compare' ||
    'pitch_direction' ||
    'same_different' ||
    'interval_name' ||
    'triad_quality' => drill.type,
    _ => drill.params['set'] as String,
  }) {
    'tempo_compare' => g.tempoCompare,
    'pitch_direction' => g.pitchDirection,
    'same_different' => g.sameDifferent,
    'interval_name' => g.intervalName,
    'triad_quality' => g.chordQuality,
    'fretboard_natural_notes' => () => g.fretNote(naturalOnly: true),
    'fretboard_root_names' => () => g.fretNote(naturalOnly: false),
    'enharmonic_names' => g.enharmonic,
    'major_scale_steps' => g.scaleStep,
    'pentatonic_roots' => g.pentatonic,
    'triad_tones' => g.triadTones,
    'roman_numeral_chords' => g.roman,
    'seventh_chord_spelling' => g.seventh,
    'twelve_bar_blues' => g.blues,
    _ => throw StateError('unreachable'),
  };
  final out = <DrillQuestion>[];
  // Avoid asking the same thing twice in a row when the pool allows it.
  var guard = 0;
  while (out.length < drill.count) {
    final q = make();
    final same =
        out.isNotEmpty &&
        out.last.kind == q.kind &&
        out.last.expected == q.expected &&
        _sameMarks(out.last.marks, q.marks);
    if (same && guard++ < 20) continue;
    guard = 0;
    out.add(q);
  }
  return out;
}

bool _sameMarks(List<FretMark> a, List<FretMark> b) =>
    a.length == b.length &&
    [for (var i = 0; i < a.length; i++) a[i] == b[i]].every((x) => x);

final class _Gen {
  _Gen(this.p, this.rng);

  final Map<String, Object?> p;
  final math.Random rng;

  T pick<T>(List<T> xs) => xs[rng.nextInt(xs.length)];

  List<int> ints(String key, List<int> fallback) {
    final v = p[key];
    if (v == null) return fallback;
    if (v is! List || v.any((x) => x is! int)) {
      throw FormatException('$key must be a list of integers');
    }
    return v.cast<int>();
  }

  List<String> strings(String key) {
    final v = p[key];
    if (v is! List || v.isEmpty || v.any((x) => x is! String)) {
      throw FormatException('$key must be a non-empty list of strings');
    }
    return v.cast<String>();
  }

  (int, int) frets() {
    final f = ints('frets', [0, 12]);
    if (f.length != 2 || f[0] < 0 || f[1] > 15 || f[0] >= f[1]) {
      throw const FormatException('frets must be [first, last] within 0–15');
    }
    return (f[0], f[1]);
  }

  List<int> guitarStrings() {
    final s = ints('strings', [6, 5, 4, 3, 2, 1]);
    if (s.isEmpty || s.any((x) => x < 1 || x > 6)) {
      throw const FormatException('strings must be 1–6');
    }
    return s;
  }

  bool get bothDirections => p['bothDirections'] == true;

  /// [answer] plus distinct distractors from [pool], shuffled.
  DrillQuestion choice({
    required DrillPromptKind kind,
    required String answer,
    required Iterable<String> pool,
    Map<String, Object> values = const {},
    List<FretMark> marks = const [],
    (int, int)? window,
    int options = 4,
  }) {
    final others = {...pool}..remove(answer);
    final list = others.toList()..shuffle(rng);
    final shown = [answer, ...list.take(options - 1)]..shuffle(rng);
    return DrillQuestion(
      kind: kind,
      values: values,
      options: shown,
      answer: shown.indexOf(answer),
      marks: marks,
      fretWindow: window,
    );
  }

  static const _naturals = ['C', 'D', 'E', 'F', 'G', 'A', 'B'];
  static const _sharps = [
    'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B', //
  ];

  DrillQuestion fretNote({required bool naturalOnly}) {
    final window = frets();
    final strings = guitarStrings();
    final positions = [
      for (final s in strings)
        for (var f = window.$1; f <= window.$2; f++)
          if (!naturalOnly || sharpName(fretMidi(s, f) % 12).natural)
            (string: s, fret: f),
    ];
    final at = pick(positions);
    final note = sharpName(fretMidi(at.string, at.fret) % 12).name;
    final pool = naturalOnly ? _naturals : _sharps;
    if (bothDirections && rng.nextBool()) {
      // Reverse: name → fret. Distractors are other frets on that string
      // with a different note (an octave repeat would also be right).
      final pc = fretMidi(at.string, at.fret) % 12;
      final frets = [
        for (var f = window.$1; f <= window.$2; f++)
          if (fretMidi(at.string, f) % 12 != pc) '$f',
      ];
      return choice(
        kind: DrillPromptKind.fretOfNote,
        answer: '${at.fret}',
        pool: frets,
        values: {'v0': note, 'v1': at.string},
        window: window,
      );
    }
    return choice(
      kind: DrillPromptKind.noteAtFret,
      answer: note,
      pool: pool,
      values: {'v0': at.fret, 'v1': at.string},
      marks: [at],
      window: window,
    );
  }

  DrillQuestion enharmonic() {
    final window = frets();
    final positions = [
      for (final s in guitarStrings())
        for (var f = window.$1; f <= window.$2; f++)
          if (!sharpName(fretMidi(s, f) % 12).natural) (string: s, fret: f),
    ];
    if (positions.isEmpty) {
      throw const FormatException('No sharps or flats in the fret window');
    }
    final at = pick(positions);
    final sharp = sharpName(fretMidi(at.string, at.fret) % 12);
    final flat = enharmonicOf(sharp)!;
    // Ask from either spelling; distractors are the neighbours' names.
    final fromSharp = rng.nextBool();
    final shown = fromSharp ? sharp : flat;
    final answer = fromSharp ? flat : sharp;
    final pool = [
      for (final d in [-2, -1, 1, 2]) ...[
        sharpName(sharp.pitchClass + d + 12).name,
        if (enharmonicOf(sharpName(sharp.pitchClass + d + 12)) case final e?)
          e.name,
      ],
    ]..removeWhere((n) => n == shown.name);
    return choice(
      kind: DrillPromptKind.enharmonic,
      answer: answer.name,
      pool: pool,
      values: {'v0': shown.name},
      marks: [at],
      window: window,
    );
  }

  DrillQuestion scaleStep() {
    final window = frets();
    final key = SpelledNote.parse(pick(strings('keys')));
    final scale = majorScale(key);
    final positions = [
      for (final s in guitarStrings())
        for (var f = window.$1; f <= window.$2; f++)
          if (scale.any((n) => n.pitchClass == fretMidi(s, f) % 12))
            (string: s, fret: f),
    ];
    final at = pick(positions);
    final degree =
        scale.indexWhere(
          (n) => n.pitchClass == fretMidi(at.string, at.fret) % 12,
        ) +
        1;
    return choice(
      kind: DrillPromptKind.scaleStep,
      answer: '$degree',
      pool: [for (var d = 1; d <= 7; d++) '$d'],
      values: {'v0': key.name},
      marks: [at],
      window: window,
    );
  }

  DrillQuestion pentatonic() {
    final window = frets();
    final root = SpelledNote.parse(p['key'] as String? ?? 'A');
    final notes = minorPentatonic(root);
    final positions = [
      for (final s in guitarStrings())
        for (var f = window.$1; f <= window.$2; f++)
          if (notes.any((n) => n.pitchClass == fretMidi(s, f) % 12))
            (string: s, fret: f),
    ];
    final at = pick(positions);
    final note = notes.firstWhere(
      (n) => n.pitchClass == fretMidi(at.string, at.fret) % 12,
    );
    return choice(
      kind: DrillPromptKind.pentatonicNote,
      answer: note.name,
      pool: [for (final n in notes) n.name],
      values: {'v0': root.name},
      marks: [at],
      window: window,
    );
  }

  DrillQuestion triadTones() {
    final qualities = strings('qualities');
    final roots = strings('roots');
    final root = SpelledNote.parse(pick(roots));
    final quality = pick(qualities);
    String spell(SpelledNote r, String q) =>
        chordTones(r, q).map((n) => n.name).join(' ');
    final pool = <String>{
      for (final r in roots)
        for (final q in qualities) spell(SpelledNote.parse(r), q),
    };
    return choice(
      kind: DrillPromptKind.chordTones,
      answer: spell(root, quality),
      pool: pool,
      values: {'v0': chordSymbol(root, quality)},
    );
  }

  DrillQuestion roman() {
    final key = SpelledNote.parse(pick(strings('keys')));
    final degrees = strings('degrees');
    final numeral = pick(degrees);
    // Distractors: the other asked degrees in this key, then neighbours.
    final pool = {
      for (final d in degrees) romanChord(key, d),
      for (final d in const ['II', 'III', 'VI']) romanChord(key, d),
    };
    return choice(
      kind: DrillPromptKind.romanNumeral,
      answer: romanChord(key, numeral),
      pool: pool,
      values: {'v0': key.name, 'v1': numeral},
    );
  }

  DrillQuestion seventh() {
    final symbols = strings('symbols');
    final symbol = pick(symbols);
    String spell(String s) {
      final c = parseChord(s);
      return chordTones(c.root, c.quality).map((n) => n.name).join(' ');
    }

    // Same-root chords first: telling A7 from Amaj7 is the point.
    final root = parseChord(symbol).root;
    final sameRoot = [
      for (final s in symbols)
        if (parseChord(s).root == root) spell(s),
    ];
    final pool = {...sameRoot, for (final s in symbols) spell(s)};
    return choice(
      kind: DrillPromptKind.chordTones,
      answer: spell(symbol),
      pool: sameRoot.length >= 4 ? sameRoot : pool,
      values: {'v0': symbol},
    );
  }

  DrillQuestion blues() {
    final rows = strings('items');
    final bars = [for (final r in rows) ...r.split(RegExp(r'\s+'))];
    if (p['askChordInBar'] == true && rng.nextBool()) {
      final bar = rng.nextInt(bars.length);
      return choice(
        kind: DrillPromptKind.bluesBar,
        answer: bars[bar],
        pool: bars.toSet(),
        values: {'v0': bar + 1},
      );
    }
    final line = rng.nextInt(rows.length);
    return choice(
      kind: DrillPromptKind.bluesLine,
      answer: rows[line],
      pool: rows,
      values: {'v0': line + 1},
      options: rows.length,
    );
  }

  // ---- F2.6b heard drills -------------------------------------------------

  /// `["C3","C5"]` or `"C3-C5"` → MIDI bounds.
  (int, int) range([String fallback = 'C3-C5']) {
    final v = p['range'] ?? fallback;
    final parts = v is List ? v.cast<String>() : (v as String).split('-');
    if (parts.length != 2) throw const FormatException('range needs two notes');
    final lo = noteMidi(parts[0]), hi = noteMidi(parts[1]);
    if (lo >= hi) throw const FormatException('range must rise');
    return (lo, hi);
  }

  double volume() =>
      p['varyVolume'] == true ? 0.55 + rng.nextDouble() * 0.45 : 1;

  DrillNote tone(
    double at,
    double midi, {
    double seconds = 0.7,
    double? gain,
  }) => DrillNote(at: at, midi: midi, seconds: seconds, gain: gain ?? volume());

  DrillQuestion heard({
    required DrillPromptKind kind,
    required String answer,
    required List<String> options,
    required DrillSound sound,
    List<DrillSound?>? optionSounds,
    Map<String, Object> values = const {},
  }) => DrillQuestion(
    kind: kind,
    values: values,
    options: options,
    answer: options.indexOf(answer),
    sound: sound,
    optionSounds: optionSounds,
  );

  DrillQuestion tempoCompare() {
    final base = ints('baseBpm', [70, 110]);
    final delta = ints('deltaPercent', [10, 25]);
    final bpm = base[0] + rng.nextInt(base[1] - base[0] + 1);
    final pct = delta[0] + rng.nextInt(delta[1] - delta[0] + 1);
    final choices = ['faster', 'slower', if (p['allowSame'] == true) 'same'];
    final answer = pick(choices);
    final second = switch (answer) {
      'faster' => bpm * (1 + pct / 100),
      'slower' => bpm * (1 - pct / 100),
      _ => bpm.toDouble(),
    };
    List<DrillNote> phrase(double start, double tempo) => [
      for (var b = 0; b < 4; b++)
        DrillNote(
          at: start + b * 60 / tempo,
          midi: 0,
          seconds: 0.05,
          gain: b == 0 ? 1 : 0.5,
          timbre: DrillTimbre.click,
        ),
    ];
    final firstEnd = 4 * 60 / bpm;
    return heard(
      kind: DrillPromptKind.tempoCompare,
      answer: answer,
      options: choices,
      sound: DrillSound([
        ...phrase(0, bpm.toDouble()),
        ...phrase(firstEnd + 0.8, second),
      ]),
    );
  }

  DrillQuestion pitchDirection() {
    final (lo, hi) = range();
    final minStep = (p['minSemitones'] as int?) ?? 2;
    final notesParam = p['notes'];
    final count = notesParam is List
        ? pick(notesParam.cast<int>())
        : (notesParam as int?) ?? 2;
    final allowSame = p['allowSame'] == true;
    int step(int from) {
      final moves = [
        for (var d = minStep; d <= 12; d++) ...[
          if (from + d <= hi) d,
          if (from - d >= lo) -d,
        ],
        if (allowSame) 0,
      ];
      return pick(moves);
    }

    String word(int d) => d > 0
        ? 'up'
        : d < 0
        ? 'down'
        : 'same';
    final first = lo + rng.nextInt(hi - lo + 1);
    final midis = [first];
    for (var i = 1; i < count; i++) {
      midis.add(midis.last + step(midis.last));
    }
    final sound = DrillSound([
      for (var i = 0; i < midis.length; i++)
        tone(i * 0.85, midis[i].toDouble()),
    ]);
    if (count == 2) {
      final d = midis[1] - midis[0];
      final answer = d > 0
          ? 'higher'
          : d < 0
          ? 'lower'
          : 'same';
      return heard(
        kind: DrillPromptKind.pitchDirection,
        answer: answer,
        options: ['higher', 'lower', if (allowSame) 'same'],
        sound: sound,
      );
    }
    final answer = [
      for (var i = 1; i < midis.length; i++) word(midis[i] - midis[i - 1]),
    ].join('-');
    final words = ['up', 'down', if (allowSame) 'same'];
    final all = [
      for (final a in words)
        for (final b in words) '$a-$b',
    ];
    return choice(
      kind: DrillPromptKind.pitchContour,
      answer: answer,
      pool: all,
    ).withSound(sound);
  }

  DrillQuestion sameDifferent() {
    final (lo, hi) = range();
    final minC = (p['minCents'] as int?) ?? 50;
    final maxC = (p['maxCents'] as int?) ?? 200;
    final base = (lo + rng.nextInt(hi - lo + 1)).toDouble();
    final answer = rng.nextBool() ? 'same' : 'different';
    final cents = answer == 'same'
        ? 0.0
        : (minC + rng.nextInt(maxC - minC + 1)) * (rng.nextBool() ? 1 : -1);
    return heard(
      kind: DrillPromptKind.sameDifferent,
      answer: answer,
      options: const ['same', 'different'],
      sound: DrillSound([tone(0, base), tone(0.9, base + cents / 100)]),
    );
  }

  DrillQuestion intervalName() {
    final names = strings('intervals');
    final (lo, hi) = range();
    final dir = p['direction'];
    final dirs = switch (dir) {
      'both' => ['ascending', 'descending'],
      final List<Object?> l => l.cast<String>(),
      final String d => [d],
      _ => ['ascending'],
    };
    final name = pick(names);
    final direction = pick(dirs);
    final semis = intervalSemitones[name]!;
    final widest = names.map((n) => intervalSemitones[n]!).reduce(math.max);
    final root = direction == 'ascending'
        ? lo + rng.nextInt(math.max(1, hi - widest - lo + 1))
        : lo + widest + rng.nextInt(math.max(1, hi - lo - widest + 1));
    DrillSound play(int s) {
      final other = direction == 'ascending' ? root + s : root - s;
      return DrillSound([
        tone(0, root.toDouble(), seconds: 0.8, gain: 1),
        tone(0.9, other.toDouble(), seconds: 0.8, gain: 1),
      ]);
    }

    return heard(
      kind: DrillPromptKind.intervalName,
      answer: name,
      options: names,
      sound: play(semis),
      optionSounds: [for (final n in names) play(intervalSemitones[n]!)],
      values: {'v0': direction},
    );
  }

  DrillQuestion chordQuality() {
    final qualities = strings('qualities');
    final guitar = p['voicing'] == 'guitar_open';
    final roots = p['roots'] is List ? strings('roots') : null;
    final (lo, hi) = range(guitar ? 'E2-E4' : 'C3-C5');
    final rootMidi = roots != null
        ? _guitarRootMidi(pick(roots))
        : lo + rng.nextInt(math.max(1, hi - lo - 10));
    final quality = pick(qualities);
    DrillSound play(String q) {
      final steps = switch (q) {
        'major' => [0, 4, 7],
        'minor' => [0, 3, 7],
        'dominant7' => [0, 4, 7, 10],
        _ => throw StateError('unreachable'),
      };
      final timbre = guitar ? DrillTimbre.string : DrillTimbre.piano;
      final arpeggio = p['arpeggiate'] != false;
      final gap = arpeggio ? 0.42 : 0.0;
      final chordAt = arpeggio ? steps.length * gap + 0.25 : 0.0;
      return DrillSound([
        if (arpeggio)
          for (var i = 0; i < steps.length; i++)
            DrillNote(
              at: i * gap,
              midi: (rootMidi + steps[i]).toDouble(),
              seconds: 0.6,
              timbre: timbre,
            ),
        for (final s in steps)
          DrillNote(
            at: chordAt,
            midi: (rootMidi + s).toDouble(),
            seconds: 1.4,
            gain: 0.7,
            timbre: timbre,
          ),
      ]);
    }

    return heard(
      kind: DrillPromptKind.chordQuality,
      answer: quality,
      options: qualities,
      sound: play(quality),
      optionSounds: [for (final q in qualities) play(q)],
    );
  }

  /// Open-position root on guitar: A2, D3, E2 (the open strings' octave).
  int _guitarRootMidi(String root) {
    final pc = SpelledNote.parse(root).pitchClass;
    for (var m = 40; m < 52; m++) {
      if (m % 12 == pc) return m;
    }
    throw StateError('unreachable');
  }
}
