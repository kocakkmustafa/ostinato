import 'dart:math' as math;

import '../curriculum/v1_lesson.dart';
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
}

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

  String get expected => options[answer];
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
  final make = switch (drill.type == 'ordering'
      ? 'twelve_bar_blues'
      : drill.params['set'] as String) {
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
}
