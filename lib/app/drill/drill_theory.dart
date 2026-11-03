/// F2.6 — the little music theory the drill generators need (pure Dart):
/// spelled note names, standard guitar tuning, major scales, triads and
/// seventh chords. Spelling follows letters, so G major has F♯ and F major
/// has B♭; nothing here guesses from pitch classes alone.
library;

const List<String> _letters = ['C', 'D', 'E', 'F', 'G', 'A', 'B'];
const List<int> _letterPc = [0, 2, 4, 5, 7, 9, 11];

/// A note name: letter plus accidental (−2…+2), no octave.
final class SpelledNote {
  const SpelledNote(this.letter, this.accidental);

  /// Parses `C`, `F#`, `Bb`, `C##`, `Ebb`.
  factory SpelledNote.parse(String name) {
    final m = RegExp(r'^([A-G])(#{1,2}|b{1,2})?$').firstMatch(name);
    if (m == null) throw FormatException('Not a note name: $name');
    final acc = m.group(2) ?? '';
    return SpelledNote(
      _letters.indexOf(m.group(1)!),
      acc.startsWith('#') ? acc.length : -acc.length,
    );
  }

  /// Index into C D E F G A B.
  final int letter;
  final int accidental;

  int get pitchClass => (_letterPc[letter] + accidental) % 12;
  bool get natural => accidental == 0;

  String get name =>
      _letters[letter] +
      (accidental > 0 ? '#' * accidental : 'b' * -accidental);

  /// The note [letterSteps] letters up whose pitch class is [semitones]
  /// above this one (a third is 2 letters, a fifth 4).
  SpelledNote up(int letterSteps, int semitones) {
    final l = (letter + letterSteps) % 7;
    final target = (pitchClass + semitones) % 12;
    var acc = (target - _letterPc[l]) % 12;
    if (acc > 6) acc -= 12;
    return SpelledNote(l, acc);
  }

  @override
  bool operator ==(Object other) =>
      other is SpelledNote &&
      other.letter == letter &&
      other.accidental == accidental;

  @override
  int get hashCode => Object.hash(letter, accidental);

  @override
  String toString() => name;
}

/// Sharp spelling for black keys (C# not Db), as fretboard maps print them.
SpelledNote sharpName(int pitchClass) {
  final pc = pitchClass % 12;
  final natural = _letterPc.indexOf(pc);
  if (natural >= 0) return SpelledNote(natural, 0);
  return SpelledNote(_letterPc.indexOf(pc - 1), 1);
}

/// The other common name of a black key (C# ↔ Db); null for white keys.
SpelledNote? enharmonicOf(SpelledNote note) {
  if (note.natural) return null;
  final pc = note.pitchClass;
  return note.accidental > 0
      ? SpelledNote(_letterPc.indexOf((pc + 1) % 12), -1)
      : SpelledNote(_letterPc.indexOf((pc + 11) % 12), 1);
}

/// Open strings in standard tuning, string 6 (low E2) to string 1 (E4).
const Map<int, int> standardTuningMidi = {
  6: 40,
  5: 45,
  4: 50,
  3: 55,
  2: 59,
  1: 64,
};

int fretMidi(int string, int fret) => standardTuningMidi[string]! + fret;

/// Major scale degrees 1–7, spelled from the tonic.
List<SpelledNote> majorScale(SpelledNote tonic) {
  const steps = [0, 2, 4, 5, 7, 9, 11];
  return [for (var i = 0; i < 7; i++) tonic.up(i, steps[i])];
}

/// Chord tones by quality. Symbols: `major`, `minor`, `dominant7`, `major7`,
/// `minor7`.
List<SpelledNote> chordTones(SpelledNote root, String quality) =>
    switch (quality) {
      'major' => [root, root.up(2, 4), root.up(4, 7)],
      'minor' => [root, root.up(2, 3), root.up(4, 7)],
      'dominant7' => [root, root.up(2, 4), root.up(4, 7), root.up(6, 10)],
      'major7' => [root, root.up(2, 4), root.up(4, 7), root.up(6, 11)],
      'minor7' => [root, root.up(2, 3), root.up(4, 7), root.up(6, 10)],
      _ => throw ArgumentError.value(quality, 'quality'),
    };

/// Parses a chord symbol (`A`, `Am`, `A7`, `Amaj7`, `Am7`, `F#m`).
({SpelledNote root, String quality}) parseChord(String symbol) {
  final m = RegExp(r'^([A-G](?:#|b)?)(maj7|m7|m|7)?$').firstMatch(symbol);
  if (m == null) throw FormatException('Not a chord symbol: $symbol');
  return (
    root: SpelledNote.parse(m.group(1)!),
    quality: switch (m.group(2)) {
      null => 'major',
      'm' => 'minor',
      '7' => 'dominant7',
      'maj7' => 'major7',
      'm7' => 'minor7',
      _ => throw StateError('unreachable'),
    },
  );
}

String chordSymbol(SpelledNote root, String quality) =>
    root.name +
    switch (quality) {
      'major' => '',
      'minor' => 'm',
      'dominant7' => '7',
      'major7' => 'maj7',
      'minor7' => 'm7',
      _ => throw ArgumentError.value(quality, 'quality'),
    };

const Map<String, int> _romanDegree = {
  'I': 0, 'II': 1, 'III': 2, 'IV': 3, 'V': 4, 'VI': 5, 'VII': 6, //
};

/// The chord on [numeral] (I, IV, V…) in a major key; upper case = major.
String romanChord(SpelledNote key, String numeral) {
  final degree = _romanDegree[numeral];
  if (degree == null) throw ArgumentError.value(numeral, 'numeral');
  return chordSymbol(majorScale(key)[degree], 'major');
}

/// Minor pentatonic degrees 1 ♭3 4 5 ♭7 from [root].
List<SpelledNote> minorPentatonic(SpelledNote root) => [
  root,
  root.up(2, 3),
  root.up(3, 5),
  root.up(4, 7),
  root.up(6, 10),
];

/// Interval names (quality + number) → semitones.
const Map<String, int> intervalSemitones = {
  'm2': 1, 'M2': 2, 'm3': 3, 'M3': 4, 'P4': 5, 'TT': 6, //
  'P5': 7, 'm6': 8, 'M6': 9, 'm7': 10, 'M7': 11, 'P8': 12,
};

/// `C4` → 60, `F#3` → 54, `Bb2` → 46.
int noteMidi(String pitch) {
  final m = RegExp(r'^([A-G](?:#|b)?)(-?\d)$').firstMatch(pitch.trim());
  if (m == null) throw FormatException('Not a pitch: $pitch');
  final note = SpelledNote.parse(m.group(1)!);
  return (int.parse(m.group(2)!) + 1) * 12 +
      _letterPc[note.letter] +
      note.accidental;
}
