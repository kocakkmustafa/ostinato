import 'dart:math' as math;

import '../curriculum/v1_lesson.dart';
import 'drill_dictation.dart';
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

  /// F2.6c, read: "Which note is this?" on a staff.
  staffNote,

  /// "Which major key has this key signature?"
  keySignature,

  /// "Which interval number is this?" (2nd…8th) on a staff.
  staffInterval,

  /// Heard after a cadence: "Was the last note the tonic?"
  tonicOrNot,

  /// F2.6d, written: "Write the rhythm you heard."
  rhythmDictation,

  /// "Write the melody you heard" (scale degrees; the first is given).
  melodicDictation,

  /// Remaining drills: two marked keys in a scale — whole or half step?
  stepSize,

  /// "On which line or in which space is the note?"
  staffPlace,

  /// "What is the highlighted sign?" (bar line, double bar, 4/4)
  staffSymbol,

  /// "How many beats are in each bar of 4/4?"
  beatsInBar,

  /// Singing alternatives: where is the half step in four scale notes?
  halfStepPlace,

  /// Which degree is the note over the drone?
  degreeOverDrone,

  /// Which of two staves (A/B) matches the line heard?
  staffMatch,
}

enum DrillEntryKind { rhythm, melody }

/// What the learner writes instead of choosing an option.
final class DrillEntry {
  const DrillEntry.rhythm({
    required this.palette,
    required this.bars,
    required this.bpm,
    required this.answer,
    this.ties = false,
  }) : kind = DrillEntryKind.rhythm,
       length = 0,
       given = const [],
       key = null,
       midis = const [],
       pitches = const [],
       keySignature = 0,
       cadence = false;

  const DrillEntry.melody({
    required this.palette,
    required this.length,
    required this.given,
    required SpelledNote this.key,
    required this.midis,
    required this.pitches,
    required this.keySignature,
    required this.answer,
    this.cadence = true,
  }) : kind = DrillEntryKind.melody,
       bars = 0,
       bpm = 0,
       ties = false;

  final DrillEntryKind kind;

  /// Rhythm values, or degrees (`1`…`7`) for a melody.
  final List<String> palette;
  final int bars, bpm;

  /// Melody: notes to write in all, of which [given] are prefilled.
  final int length;
  final List<String> given;
  final SpelledNote? key;

  /// Melody: sounding MIDI and written pitch per degree 1–7.
  final List<int> midis;
  final List<String> pitches;
  final int keySignature;
  final bool cadence;

  /// Rhythm: the palette offers a tie (`~`) between two notes.
  final bool ties;

  /// The expected answer as written (labels, "play the expected").
  final List<String> answer;

  /// The canonical answer key of [entered] (see [DrillQuestion.expected]).
  String keyOf(List<String> entered) =>
      kind == DrillEntryKind.rhythm ? rhythmKey(entered) : entered.join(' ');

  bool complete(List<String> entered) => kind == DrillEntryKind.rhythm
      ? (rhythmLength(entered) - bars * 4).abs() < 1e-9 &&
            (entered.isEmpty || entered.last != kTie)
      : entered.length == length;
}

/// A staff to draw: clef, notes (natural pitches, left to right) and the
/// key signature (+n sharps, −n flats).
final class DrillStaff {
  const DrillStaff({
    required this.clef,
    required this.notes,
    this.keySignature = 0,
    this.timeSignature,
    this.bars = 0,
    this.doubleBarEnd = false,
    this.highlight,
  });

  /// `4/4` drawn after the clef, or null.
  final String? timeSignature;

  /// Bars drawn with bar lines (each note one bar); 0 = notes only.
  final int bars;
  final bool doubleBarEnd;

  /// `bar_line`, `double_bar_line` or `time_signature_4_4` to highlight.
  final String? highlight;

  /// `treble` or `bass`.
  final String clef;
  final List<String> notes;
  final int keySignature;
}

/// Prompts that are heard: the screen shows Play and "play my answer".
bool isHeard(DrillPromptKind k) => switch (k) {
  DrillPromptKind.tempoCompare ||
  DrillPromptKind.pitchDirection ||
  DrillPromptKind.pitchContour ||
  DrillPromptKind.sameDifferent ||
  DrillPromptKind.intervalName ||
  DrillPromptKind.chordQuality ||
  DrillPromptKind.tonicOrNot ||
  DrillPromptKind.stepSize ||
  DrillPromptKind.halfStepPlace ||
  DrillPromptKind.degreeOverDrone ||
  DrillPromptKind.staffMatch => true,
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
    this.staff,
    this.entry,
    this.keys = const [],
    this.staves = const [],
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

  /// A staff to draw (read kinds), or null.
  final DrillStaff? staff;

  /// Written answers (dictation); [options] then holds only the expected
  /// canonical key.
  final DrillEntry? entry;

  /// Keyboard diagram: marked keys (MIDI); empty = no keyboard.
  final List<int> keys;

  /// Staff match: the staves the options name (A, B), in order.
  final List<DrillStaff> staves;

  String get expected => options[answer];

  DrillQuestion withStaff(DrillStaff staff) => DrillQuestion(
    kind: kind,
    values: values,
    options: options,
    answer: answer,
    staff: staff,
  );

  DrillQuestion withKeys(
    List<int> keys,
    DrillSound sound,
    List<DrillSound?> optionSounds,
  ) => DrillQuestion(
    kind: kind,
    values: values,
    options: options,
    answer: answer,
    keys: keys,
    sound: sound,
    optionSounds: optionSounds,
  );

  DrillQuestion withSound(DrillSound sound) => DrillQuestion(
    kind: kind,
    values: values,
    options: options,
    answer: answer,
    marks: marks,
    fretWindow: fretWindow,
    sound: sound,
    staff: staff,
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
      final names = (p['intervals'] as List?)?.cast<Object?>() ?? const [];
      if (p['display'] == 'staff') {
        // Numbers only (2…8): read on the staff, no quality.
        return names.isNotEmpty &&
            names.every((i) => i is String && _staffNumbers.contains(i));
      }
      return names.isNotEmpty &&
          names.every((i) => intervalSemitones.containsKey(i)) &&
          (p['context'] == null || p['context'] == 'melody');
    case 'note_name' || 'half_step_place' || 'degree_over_drone':
      return true;
    case 'staff_match':
      return true;
    case 'key_signature':
      return (p['keys'] as List?)?.every(keySignatures.containsKey) == true;
    case 'scale_degree':
      return p['question'] == 'tonic_or_not';
    case 'rhythm_dictation':
      // Ties across beats need a tie entry; they come later.
      return (p['meter'] ?? '4/4') == '4/4' &&
          (p['values'] as List?)?.every(rhythmBeats.containsKey) == true;
    case 'melodic_dictation':
      return (p['degrees'] as List?)?.every(
                (d) => d is int && d >= 1 && d <= 7,
              ) ==
              true &&
          ((p['key'] as List?) ?? const ['C']).every(
            (k) => k is String && keySignatures.containsKey(k),
          );
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
  if (drill.type == 'symbol_match' && set is List) {
    return set.isNotEmpty &&
        (set.every(staffPlaceNames.contains) ||
            set.every(barSymbolNames.contains));
  }
  if (set is! String || !(_supportedSets[drill.type]?.contains(set) ?? false)) {
    return false;
  }
  final diagram = drill.params['diagram'];
  if (diagram == 'keyboard') return set == 'major_scale_steps';
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
    'triad_quality' ||
    'note_name' ||
    'key_signature' ||
    'scale_degree' ||
    'rhythm_dictation' ||
    'melodic_dictation' ||
    'half_step_place' ||
    'degree_over_drone' ||
    'staff_match' => drill.type,
    _ when drill.params['set'] is List =>
      (drill.params['set'] as List).every(staffPlaceNames.contains)
          ? 'staff_places'
          : 'bar_symbols',
    _ when drill.params['diagram'] == 'keyboard' => 'keyboard_steps',
    _ => drill.params['set'] as String,
  }) {
    'staff_places' => g.staffPlace,
    'bar_symbols' => g.barSymbol,
    'keyboard_steps' => g.stepSize,
    'tempo_compare' => g.tempoCompare,
    'pitch_direction' => g.pitchDirection,
    'same_different' => g.sameDifferent,
    'interval_name' => switch (drill.params['display']) {
      'staff' => g.staffInterval,
      _ =>
        drill.params['cadence'] == true || drill.params['context'] != null
            ? g.cadenceInterval
            : g.intervalName,
    },
    'note_name' => g.staffNote,
    'key_signature' => g.keySignature,
    'scale_degree' => g.tonicOrNot,
    'rhythm_dictation' => g.rhythmDictation,
    'melodic_dictation' => g.melodicDictation,
    'half_step_place' => g.halfStepPlace,
    'degree_over_drone' => g.degreeOverDrone,
    'staff_match' => g.staffMatch,
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

/// I–IV–V–I in [key], root-position block chords around C4.
List<DrillNote> cadenceNotes(SpelledNote key) {
  final t = 48 + key.pitchClass;
  const chords = [
    [0, 4, 7, 12],
    [5, 9, 12, 17],
    [7, 11, 14, 19],
    [0, 4, 7, 12],
  ];
  return [
    for (var c = 0; c < chords.length; c++)
      for (final s in chords[c])
        DrillNote(
          at: c * 0.7,
          midi: (t + s).toDouble(),
          seconds: c == chords.length - 1 ? 1.0 : 0.65,
          gain: 0.55,
        ),
  ];
}

/// Where the question starts after a cadence (seconds).
const double kAfterCadence = 3.4;

/// "Play my answer" for a written melody: the cadence, then the degrees.
DrillSound melodyAnswerSound(DrillEntry e, List<String> degrees) => DrillSound([
  if (e.cadence) ...cadenceNotes(e.key!),
  for (var i = 0; i < degrees.length; i++)
    DrillNote(
      at: (e.cadence ? kAfterCadence : 0) + i * 0.75,
      midi: e.midis[int.parse(degrees[i]) - 1].toDouble(),
      seconds: 0.7,
    ),
]);

/// Staff places counted from the bottom (symbol_match sets).
const Set<String> staffPlaceNames = {
  'line_1', 'line_2', 'line_3', 'line_4', 'line_5', //
  'space_1', 'space_2', 'space_3', 'space_4',
};

/// Bar-line and 4/4 symbols (symbol_match sets).
const Set<String> barSymbolNames = {
  'bar_line', 'double_bar_line', 'time_signature_4_4', 'beats_in_bar_4_4', //
};

const Set<String> _staffNumbers = {'2', '3', '4', '5', '6', '7', '8'};

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

  // ---- F2.6c read on the staff, heard after a cadence ----------------------

  /// Natural pitches (no accidentals) from [lo] to [hi] MIDI, as `E4`.
  List<String> naturals(int lo, int hi) => [
    for (var m = lo; m <= hi; m++)
      if (sharpName(m % 12).natural) '${sharpName(m % 12).name}${m ~/ 12 - 1}',
  ];

  /// Staff step from the bottom line (treble E4 = 0, bass G2 = 0).
  static int staffStep(String pitch, String clef) =>
      'CDEFGAB'.indexOf(pitch[0]) +
      int.parse(pitch.substring(1)) * 7 -
      (clef == 'treble' ? 30 : 18);

  /// Clef for one question: a single clef, a choice, or `grand` (treble
  /// from C4 up, bass below).
  String clefFor(String pitch) {
    final c = p['clef'];
    if (c == 'grand') return noteMidi(pitch) >= 60 ? 'treble' : 'bass';
    return c is String ? c : 'treble';
  }

  List<String> clefChoices() {
    final c = p['clef'];
    if (c is List) return c.cast<String>();
    if (c == 'grand') return const ['grand'];
    return [c is String ? c : 'treble'];
  }

  (int, int) clefRange(String clef) {
    final r = p['range'];
    if (r is Map) {
      final pair = (r[clef] as List).cast<String>();
      return (noteMidi(pair[0]), noteMidi(pair[1]));
    }
    return range(clef == 'bass' ? 'C2-E4' : 'A3-C6');
  }

  DrillQuestion staffNote() {
    final clefChoice = pick(clefChoices());
    final (lo, hi) = clefRange(clefChoice == 'grand' ? 'treble' : clefChoice);
    final maxLedger = (p['ledgerLinesMax'] as int?) ?? 3;
    final ledgerOnly = p['ledgerOnly'] == true;
    final candidates = [
      for (final n in naturals(lo, hi))
        if (() {
          final clef = clefChoice == 'grand' ? clefFor(n) : clefChoice;
          final step = staffStep(n, clef);
          final ledger = step < -1
              ? (-step) ~/ 2
              : step > 9
              ? (step - 8) ~/ 2
              : 0;
          return ledger <= maxLedger && (!ledgerOnly || ledger > 0);
        }())
          n,
    ];
    if (candidates.isEmpty) {
      throw const FormatException('No notes fit the clef, range and ledgers');
    }
    final pitch = pick(candidates);
    final clef = clefChoice == 'grand' ? clefFor(pitch) : clefChoice;
    return choice(
      kind: DrillPromptKind.staffNote,
      answer: pitch[0],
      pool: _naturals,
    ).withStaff(DrillStaff(clef: clef, notes: [pitch]));
  }

  DrillQuestion keySignature() {
    final keys = strings('keys');
    final clefs = p['clefs'] is List ? strings('clefs') : const ['treble'];
    final key = pick(keys);
    final pool = {...keys, ...keySignatures.keys};
    return choice(
      kind: DrillPromptKind.keySignature,
      answer: key,
      pool: pool,
    ).withStaff(
      DrillStaff(
        clef: pick(clefs),
        notes: const [],
        keySignature: keySignatures[key]!,
      ),
    );
  }

  DrillQuestion staffInterval() {
    final numbers = strings('intervals');
    final clefChoice = pick(clefChoices());
    final (lo, hi) = range(clefChoice == 'bass' ? 'C3-C4' : 'C4-G5');
    final notes = naturals(lo, hi);
    final dirs = switch (p['direction']) {
      'both' => ['ascending', 'descending'],
      final List<Object?> l => l.cast<String>(),
      final String d => [d],
      _ => ['ascending'],
    };
    final number = int.parse(pick(numbers));
    final direction = pick(dirs);
    final starts = [
      for (var i = 0; i < notes.length; i++)
        if (direction == 'ascending'
            ? i + number - 1 < notes.length
            : i - number + 1 >= 0)
          i,
    ];
    final i = pick(starts);
    final j = direction == 'ascending' ? i + number - 1 : i - number + 1;
    final first = notes[i], second = notes[j];
    final clef = clefChoice == 'grand'
        ? clefFor(noteMidi(first) <= noteMidi(second) ? first : second)
        : clefChoice;
    return choice(
      kind: DrillPromptKind.staffInterval,
      answer: '$number',
      pool: numbers,
      options: numbers.length,
    ).withStaff(DrillStaff(clef: clef, notes: [first, second]));
  }

  DrillQuestion tonicOrNot() {
    final key = SpelledNote.parse(pick(strings('key')));
    final degrees = ints('degrees', [1, 2, 3, 4, 5, 6, 7]);
    final others = degrees.where((d) => d != 1).toList();
    // About two in five questions are the tonic, so "no" is not a safe guess.
    final degree = rng.nextInt(5) < 2 || others.isEmpty ? 1 : pick(others);
    const steps = [0, 2, 4, 5, 7, 9, 11];
    final midi = 60 + key.pitchClass + steps[degree - 1];
    return heard(
      kind: DrillPromptKind.tonicOrNot,
      answer: degree == 1 ? 'tonic' : 'notTonic',
      options: const ['tonic', 'notTonic'],
      sound: DrillSound([
        ...cadenceNotes(key),
        DrillNote(at: kAfterCadence, midi: midi.toDouble(), seconds: 1.0),
      ]),
      values: {'v0': key.name},
    );
  }

  DrillQuestion cadenceInterval() {
    final names = strings('intervals');
    final key = SpelledNote.parse(
      p['keys'] is List ? pick(strings('keys')) : 'C',
    );
    final dirs = switch (p['direction']) {
      'both' => ['ascending', 'descending'],
      final List<Object?> l => l.cast<String>(),
      final String d => [d],
      _ => ['ascending'],
    };
    final name = pick(names);
    final direction = pick(dirs);
    final semis = intervalSemitones[name]!;
    // Melody context: both notes belong to the key.
    final scalePcs = majorScale(key).map((n) => n.pitchClass).toSet();
    final tonic = 60 + key.pitchClass;
    final starts = [
      for (var m = tonic - 5; m <= tonic + 7; m++)
        if (scalePcs.contains(m % 12) &&
            scalePcs.contains(
              (direction == 'ascending' ? m + semis : m - semis) % 12,
            ))
          m,
    ];
    final start = pick(starts);
    DrillSound play(int s) {
      final other = direction == 'ascending' ? start + s : start - s;
      return DrillSound([
        ...cadenceNotes(key),
        DrillNote(at: kAfterCadence, midi: start.toDouble(), seconds: 0.8),
        DrillNote(
          at: kAfterCadence + 0.9,
          midi: other.toDouble(),
          seconds: 0.8,
        ),
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

  // ---- F2.6d dictation ------------------------------------------------------

  DrillQuestion rhythmDictation() {
    final values = strings('values');
    final bars = (p['bars'] as int?) ?? 1;
    final bpm = (p['bpm'] as int?) ?? 70;
    final ties = p['ties'] == true;
    final rhythm = generateRhythm(rng, values, bars: bars, ties: ties);
    final key = rhythmKey(rhythm);
    return DrillQuestion(
      kind: DrillPromptKind.rhythmDictation,
      values: {'v0': bars},
      options: [key],
      answer: 0,
      sound: rhythmSound(rhythm, bpm: bpm),
      entry: DrillEntry.rhythm(
        palette: values,
        bars: bars,
        bpm: bpm,
        ties: ties,
        answer: rhythm,
      ),
    );
  }

  DrillQuestion melodicDictation() {
    final degrees = ints('degrees', [1, 2, 3, 4, 5]);
    final count = (p['notes'] as int?) ?? 3;
    final key = SpelledNote.parse(
      p['key'] is List ? pick(strings('key')) : 'C',
    );
    final (lo, hi) = range('C4-D5');
    final midis = degreeMidis(key, lo, hi);
    final pitches = [
      for (var d = 1; d <= 7; d++) degreePitch(key, d, midis[d - 1]),
    ];
    // Stepwise-leaning melody: neighbours more likely than leaps.
    final melody = <int>[pick(degrees)];
    while (melody.length < count) {
      final near = degrees
          .where((d) => (d - melody.last).abs() <= 2 && d != melody.last)
          .toList();
      melody.add(
        near.isNotEmpty && rng.nextInt(3) > 0 ? pick(near) : pick(degrees),
      );
    }
    final firstGiven = p['firstNoteGiven'] != false;
    final cadence = p['cadenceEachQuestion'] != false;
    final notes = <DrillNote>[
      if (cadence) ...cadenceNotes(key),
      for (var i = 0; i < melody.length; i++)
        DrillNote(
          at: (cadence ? kAfterCadence : 0) + i * 0.75,
          midi: midis[melody[i] - 1].toDouble(),
          seconds: 0.7,
        ),
    ];
    return DrillQuestion(
      kind: DrillPromptKind.melodicDictation,
      values: {'v0': count, 'v1': key.name},
      options: [melody.join(' ')],
      answer: 0,
      sound: DrillSound(notes),
      entry: DrillEntry.melody(
        palette: [for (final d in degrees) '$d'],
        length: count,
        given: firstGiven ? ['${melody.first}'] : const [],
        key: key,
        midis: midis,
        pitches: pitches,
        keySignature: keySignatures[key.name]!,
        cadence: cadence,
        answer: [for (final d in melody) '$d'],
      ),
    );
  }

  // ---- Remaining drills: keyboard steps, staff places, bar symbols --------

  DrillQuestion stepSize() {
    final key = SpelledNote.parse(pick(strings('keys')));
    const steps = [0, 2, 4, 5, 7, 9, 11, 12];
    final tonic = 60 + key.pitchClass;
    final degree = rng.nextInt(7); // 0-based: degrees d and d+1
    final a = tonic + steps[degree], b = tonic + steps[degree + 1];
    final answer = b - a == 1 ? 'half' : 'whole';
    DrillSound pair(int up) => DrillSound([
      tone(0, a.toDouble(), seconds: 0.8, gain: 1),
      tone(0.9, (a + up).toDouble(), seconds: 0.8, gain: 1),
    ]);
    return DrillQuestion(
      kind: DrillPromptKind.stepSize,
      values: {'v0': key.name},
      options: const ['whole', 'half'],
      answer: answer == 'whole' ? 0 : 1,
    ).withKeys([a, b], pair(b - a), [pair(2), pair(1)]);
  }

  /// Treble staff steps 0…8 (E4 bottom line … F5 top line) as pitches.
  static const _trebleSteps = [
    'E4', 'F4', 'G4', 'A4', 'B4', 'C5', 'D5', 'E5', 'F5', //
  ];

  DrillQuestion staffPlace() {
    final set = strings('set');
    final place = pick(set);
    final n = int.parse(place.split('_').last);
    final step = place.startsWith('line') ? 2 * (n - 1) : 2 * n - 1;
    // Distractors: neighbouring places first, so lines and spaces mix.
    final near = set.toList()
      ..sort((x, y) {
        int st(String p) {
          final k = int.parse(p.split('_').last);
          return p.startsWith('line') ? 2 * (k - 1) : 2 * k - 1;
        }

        return (st(x) - step).abs().compareTo((st(y) - step).abs());
      });
    return choice(
      kind: DrillPromptKind.staffPlace,
      answer: place,
      pool: near.take(5),
    ).withStaff(DrillStaff(clef: 'treble', notes: [_trebleSteps[step]]));
  }

  DrillQuestion barSymbol() {
    final set = strings('set');
    final symbol = pick(set);
    if (symbol == 'beats_in_bar_4_4') {
      return choice(
        kind: DrillPromptKind.beatsInBar,
        answer: '4',
        pool: const ['2', '3', '4', '6'],
      ).withStaff(
        const DrillStaff(
          clef: 'treble',
          notes: ['A4', 'C5'],
          timeSignature: '4/4',
          bars: 2,
          doubleBarEnd: true,
        ),
      );
    }
    final names = set.where((s) => s != 'beats_in_bar_4_4').toList();
    return choice(
      kind: DrillPromptKind.staffSymbol,
      answer: symbol,
      pool: names,
      options: names.length,
    ).withStaff(
      DrillStaff(
        clef: 'treble',
        notes: const ['A4', 'C5'],
        timeSignature: '4/4',
        bars: 2,
        doubleBarEnd: true,
        highlight: symbol,
      ),
    );
  }

  // ---- Singing alternatives: half steps, drone degrees, staff match --------

  SpelledNote keyParam() {
    final k = p['key'];
    return SpelledNote.parse(
      k is List ? pick(k.cast<String>()) : (k as String? ?? 'C'),
    );
  }

  DrillQuestion halfStepPlace() {
    final key = keyParam();
    final count = (p['notes'] as int?) ?? 4;
    const steps = [0, 2, 4, 5, 7, 9, 11, 12, 14, 16, 17];
    final start = rng.nextInt(8 - count + 1); // 0-based first degree
    final tonic = 60 + key.pitchClass;
    final midis = [for (var i = 0; i < count; i++) tonic + steps[start + i]];
    final places = [
      for (var i = 1; i < count; i++)
        if (midis[i] - midis[i - 1] == 1) '$i-${i + 1}',
    ];
    final answer = places.isEmpty ? 'none' : places.first;
    final options = [for (var i = 1; i < count; i++) '$i-${i + 1}', 'none'];
    return heard(
      kind: DrillPromptKind.halfStepPlace,
      answer: answer,
      options: options,
      sound: DrillSound([
        for (var i = 0; i < count; i++)
          tone(i * 0.75, midis[i].toDouble(), seconds: 0.7, gain: 1),
      ]),
      values: {'v0': key.name},
    );
  }

  /// A low tonic + fifth held under the clip (no cadence).
  List<DrillNote> drone(SpelledNote key, double seconds) {
    final t = 48 + key.pitchClass;
    return [
      DrillNote(at: 0, midi: t.toDouble(), seconds: seconds, gain: 0.35),
      DrillNote(at: 0, midi: (t + 7).toDouble(), seconds: seconds, gain: 0.3),
    ];
  }

  DrillQuestion degreeOverDrone() {
    final key = keyParam();
    final degrees = ints('degrees', [1, 2, 3, 4, 5, 6]);
    final degree = pick(degrees);
    const steps = [0, 2, 4, 5, 7, 9, 11];
    final tonic = 60 + key.pitchClass;
    DrillSound play(int d) => DrillSound([
      ...drone(key, 3.2),
      DrillNote(at: 1.0, midi: (tonic + steps[d - 1]).toDouble(), seconds: 1.8),
    ]);
    final options = [for (final d in degrees) '$d'];
    return heard(
      kind: DrillPromptKind.degreeOverDrone,
      answer: '$degree',
      options: options,
      sound: play(degree),
      optionSounds: [for (final d in degrees) play(d)],
      values: {'v0': key.name},
    );
  }

  DrillQuestion staffMatch() {
    final key = keyParam();
    final count = (p['notes'] as int?) ?? 8;
    final degrees = ints('degrees', [1, 2, 3, 4, 5, 6, 7, 8]);
    final (lo, hi) = range('C4-G5');
    final midis = degreeMidis(key, lo, hi);
    int midiOf(int d) => d == 8 ? midis[0] + 12 : midis[d - 1];
    String pitchOf(int d) => d == 8
        ? degreePitch(key, 1, midis[0] + 12)
        : degreePitch(key, d, midis[d - 1]);
    // Stepwise line; the other staff differs in one or two notes.
    final line = <int>[pick(degrees)];
    while (line.length < count) {
      final near = degrees
          .where((d) => (d - line.last).abs() <= 2 && d != line.last)
          .toList();
      line.add(near.isEmpty ? pick(degrees) : pick(near));
    }
    final other = List.of(line);
    final changes = 1 + rng.nextInt(2);
    final spots = [for (var i = 1; i < count; i++) i]..shuffle(rng);
    for (final i in spots.take(changes)) {
      final alt = degrees
          .where((d) => d != line[i] && (d - line[i]).abs() <= 2)
          .toList();
      other[i] = alt.isEmpty
          ? degrees.firstWhere((d) => d != line[i])
          : pick(alt);
    }
    final heardFirst = rng.nextBool();
    final staves = [
      for (final l in heardFirst ? [line, other] : [other, line])
        DrillStaff(
          clef: 'treble',
          notes: [for (final d in l) pitchOf(d)],
          keySignature: keySignatures[key.name]!,
          // Four quarters a bar, so a long line stays readable.
          bars: count % 4 == 0 ? count ~/ 4 : 0,
        ),
    ];
    DrillSound play(List<int> l) => DrillSound([
      for (var i = 0; i < l.length; i++)
        DrillNote(at: i * 0.6, midi: midiOf(l[i]).toDouble(), seconds: 0.55),
    ]);
    return DrillQuestion(
      kind: DrillPromptKind.staffMatch,
      values: {'v0': key.name},
      options: const ['A', 'B'],
      answer: heardFirst ? 0 : 1,
      sound: play(line),
      optionSounds: [
        play(heardFirst ? line : other),
        play(heardFirst ? other : line),
      ],
      staves: staves,
    );
  }
}
