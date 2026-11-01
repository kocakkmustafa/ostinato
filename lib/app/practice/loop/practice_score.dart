import 'dart:math' as math;

/// F2.3 — the expected events of one lesson, parsed from `practice.sequence`
/// (pure Dart). Positions are in quarter-note beats from the lesson start.
///
/// Accepted forms (`docs/v1-curriculum/90-ders-yazim-kilavuzu.md` §3.1 and the
/// written lessons):
/// - pitch tokens, sounding pitch for guitar: `E2 F#3 Bb3`, optional rhythm
///   suffix `E2:h`, `C4:e.`; default one quarter;
/// - rhythm tokens: `w h q e ee`, dotted `h.`, rest `qr`, tie `h~q`, and a
///   tie across the bar line `q~ | q`;
/// - a chord name before a bar's rhythm (`Am h hr`) is a label only;
/// - degree runs (voice/ear): `1-2-3-2-1`, one quarter each; a degree may
///   carry an accidental (`b3`, `#4`), octave marks (`5'` above, `5,`
///   below) and a rhythm suffix (`3:e`, `b7,:h`); sixteenth `s` exists for
///   every duration (`C4:s`);
/// - `|` separators; every segment starts on the next bar line;
/// - optional meter prefix `3/4:` (default 4/4), and `×N`/`xN` = play
///   everything so far N times in total.
enum PracticeEventKind { pitch, onset, degree }

final class PracticeEvent {
  const PracticeEvent({
    required this.index,
    required this.kind,
    required this.startBeat,
    required this.durationBeats,
    required this.bar,
    this.midi,
    this.pitchName,
    this.degree,
    this.degreeShift = 0,
    this.degreeOctave = 0,
  });

  final int index;
  final PracticeEventKind kind;
  final double startBeat;
  final double durationBeats;
  final int bar;
  final int? midi;

  /// As written in the lesson (`E2`), for labels.
  final String? pitchName;
  final int? degree;

  /// Accidental on [degree] in semitones: `b3` → −1, `#4` → +1.
  final int degreeShift;

  /// Octave marks on [degree]: `5'` → +1 (above), `5,` → −1 (below).
  final int degreeOctave;

  double get endBeat => startBeat + durationBeats;
}

final class PracticeScore {
  PracticeScore._({
    required this.events,
    required this.beatsPerBar,
    required this.totalBeats,
  });

  final List<PracticeEvent> events;

  /// Quarter-note beats per bar (`3/4` → 3, `6/8` → 3).
  final int beatsPerBar;
  final double totalBeats;

  int get barCount => (totalBeats / beatsPerBar).ceil();

  bool get hasPitches => events.any((e) => e.kind == PracticeEventKind.pitch);

  /// Events whose start lies in `[fromBeat, toBeat)`.
  Iterable<PracticeEvent> startingIn(double fromBeat, double toBeat) =>
      events.where((e) => e.startBeat >= fromBeat && e.startBeat < toBeat);

  static final RegExp _meter = RegExp(r'^\s*(\d{1,2})/(\d{1,2})\s*:\s*');
  static final RegExp _pitch = RegExp(
    r'^([A-G])([#b♯♭]?)(-?\d)(?::([whqets~.r]+))?$',
  );
  static final RegExp _rhythm = RegExp(r'^(?:[whqets]\.?)(?:~[whqets]\.?)*r?$');
  static final RegExp _degree = RegExp(
    r"^([b#♭♯]?)(\d+)([',]*)(?::([whqets~.]+))?$",
  );
  static final RegExp _degrees = RegExp(
    r"^[b#♭♯]?\d+[',]*(?::[whqets~.]+)?(?:-[b#♭♯]?\d+[',]*(?::[whqets~.]+)?)*$",
  );
  static final RegExp _repeat = RegExp(r'^[×x](\d{1,2})$');

  /// A chord name before a bar's rhythm (`Am h hr`): a label, not an event.
  static final RegExp _chordLabel = RegExp(
    r'^[A-G][#b♯♭]?(?:m|maj7|m7|7|sus2|sus4|add9|dim|aug)?(?:/[A-G][#b♯♭]?)?$',
  );

  static PracticeScore parse(String sequence) {
    var text = sequence.trim();
    if (text.isEmpty) throw const FormatException('Empty sequence');
    var beatsPerBar = 4;
    final meter = _meter.firstMatch(text);
    if (meter != null) {
      final top = int.parse(meter.group(1)!);
      final bottom = int.parse(meter.group(2)!);
      if (top < 1 || top > 12 || ![2, 4, 8].contains(bottom)) {
        throw FormatException('Unsupported meter in $sequence');
      }
      final quarters = top * 4 / bottom;
      if (quarters != quarters.roundToDouble()) {
        throw FormatException('Meter must fill whole beats: $sequence');
      }
      beatsPerBar = quarters.round();
      text = text.substring(meter.end);
    }

    final raw = <_Raw>[];
    var position = 0.0;
    var repeats = 1;
    // A rhythm token ending in `~` (`q~ | q`) ties into the next one, across
    // the bar line: the tied note is one onset, not two.
    var tieIn = false;
    final segments = text.split('|');
    for (var s = 0; s < segments.length; s++) {
      final tokens = segments[s].trim().split(RegExp(r'\s+'))
        ..removeWhere((t) => t.isEmpty);
      if (tokens.isEmpty) continue;
      // Each segment starts on a bar line.
      position = (position / beatsPerBar).ceil() * beatsPerBar.toDouble();
      for (final token in tokens) {
        if (_chordLabel.hasMatch(token)) continue;
        final repeat = _repeat.firstMatch(token);
        if (repeat != null) {
          repeats = int.parse(repeat.group(1)!);
          if (repeats < 1) throw FormatException('Bad repeat in $sequence');
          continue;
        }
        final pitch = _pitch.firstMatch(token);
        if (pitch != null) {
          final dur = pitch.group(4) == null ? 1.0 : _duration(pitch.group(4)!);
          raw.add(
            _Raw(
              PracticeEventKind.pitch,
              position,
              dur,
              midi: _midi(pitch.group(1)!, pitch.group(2)!, pitch.group(3)!),
              name: token.split(':').first,
            ),
          );
          position += dur;
          tieIn = false;
          continue;
        }
        tieIn =
            tieIn && _rhythm.hasMatch(token.replaceFirst(RegExp(r'~$'), ''));
        if (_degrees.hasMatch(token)) {
          for (final d in token.split('-')) {
            final m = _degree.firstMatch(d)!;
            final dur = m.group(4) == null ? 1.0 : _duration(m.group(4)!);
            final marks = m.group(3)!;
            raw.add(
              _Raw(
                PracticeEventKind.degree,
                position,
                dur,
                degree: int.parse(m.group(2)!),
                degreeShift: switch (m.group(1)) {
                  'b' || '♭' => -1,
                  '#' || '♯' => 1,
                  _ => 0,
                },
                degreeOctave:
                    "'".allMatches(marks).length - ','.allMatches(marks).length,
              ),
            );
            position += dur;
          }
          continue;
        }
        if (token == 'ee') {
          for (var i = 0; i < 2; i++) {
            raw.add(_Raw(PracticeEventKind.onset, position, .5));
            position += .5;
          }
          continue;
        }
        final tieOut = token.length > 1 && token.endsWith('~');
        final body = tieOut ? token.substring(0, token.length - 1) : token;
        if (_rhythm.hasMatch(body)) {
          final rest = body.endsWith('r');
          final dur = _duration(
            rest ? body.substring(0, body.length - 1) : body,
          );
          if (rest) {
            // A rest ends any open tie.
          } else if (tieIn && raw.isNotEmpty) {
            final last = raw.removeLast();
            raw.add(_Raw(last.kind, last.start, last.duration + dur));
          } else {
            raw.add(_Raw(PracticeEventKind.onset, position, dur));
          }
          position += dur;
          tieIn = tieOut && !rest;
          continue;
        }
        throw FormatException('Unknown sequence token "$token" in $sequence');
      }
    }
    if (raw.isEmpty) throw FormatException('No events in $sequence');
    final passBeats = (position / beatsPerBar).ceil() * beatsPerBar.toDouble();
    final events = <PracticeEvent>[];
    for (var r = 0; r < repeats; r++) {
      for (final e in raw) {
        final start = e.start + r * passBeats;
        events.add(
          PracticeEvent(
            index: events.length,
            kind: e.kind,
            startBeat: start,
            durationBeats: e.duration,
            bar: (start / beatsPerBar).floor(),
            midi: e.midi,
            pitchName: e.name,
            degree: e.degree,
            degreeShift: e.degreeShift,
            degreeOctave: e.degreeOctave,
          ),
        );
      }
    }
    return PracticeScore._(
      events: List.unmodifiable(events),
      beatsPerBar: beatsPerBar,
      totalBeats: passBeats * repeats,
    );
  }

  static double _duration(String token) {
    var total = 0.0;
    for (final part in token.split('~')) {
      if (part.isEmpty) throw FormatException('Bad tie in $token');
      final base = switch (part[0]) {
        'w' => 4.0,
        'h' => 2.0,
        'q' => 1.0,
        'e' => .5,
        // Triplet eighth: three in one beat (`A2:t C3:t D3:t`).
        't' => 1 / 3,
        's' => .25,
        _ => throw FormatException('Bad duration $token'),
      };
      if (part.length == 1) {
        total += base;
      } else if (part == '${part[0]}.') {
        total += base * 1.5;
      } else {
        throw FormatException('Bad duration $token');
      }
    }
    return total;
  }

  static int _midi(String letter, String accidental, String octave) {
    const steps = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11};
    final shift = switch (accidental) {
      '#' || '♯' => 1,
      'b' || '♭' => -1,
      _ => 0,
    };
    final midi = (int.parse(octave) + 1) * 12 + steps[letter]! + shift;
    if (midi < 0 || midi > 127) throw FormatException('Pitch out of range');
    return midi;
  }
}

final class _Raw {
  _Raw(
    this.kind,
    this.start,
    this.duration, {
    this.midi,
    this.name,
    this.degree,
    this.degreeShift = 0,
    this.degreeOctave = 0,
  });
  final PracticeEventKind kind;
  final double start, duration;
  final int? midi;
  final String? name;
  final int? degree;
  final int degreeShift;
  final int degreeOctave;
}

/// String (1 = high E … 6 = low E) and fret for one sounding pitch.
final class GuitarTabPosition {
  const GuitarTabPosition(this.string, this.fret);
  final int string;
  final int fret;

  @override
  bool operator ==(Object other) =>
      other is GuitarTabPosition &&
      other.string == string &&
      other.fret == fret;

  @override
  int get hashCode => Object.hash(string, fret);

  @override
  String toString() => '$string/$fret';
}

/// Standard tuning, sounding pitches: string 1 = E4 … string 6 = E2.
const List<int> kStandardTuningMidi = [64, 59, 55, 50, 45, 40];

/// First-position fingering: among positions within frets 0–4 the lowest
/// fret wins (open strings first, as beginner lessons teach them); above
/// first position the lowest fret anywhere. Null when the guitar cannot play
/// the pitch.
GuitarTabPosition? guitarTabPosition(
  int midi, {
  List<int> tuning = kStandardTuningMidi,
  int maxFret = 19,
}) {
  GuitarTabPosition? best;
  for (var s = 0; s < tuning.length; s++) {
    final fret = midi - tuning[s];
    if (fret < 0 || fret > maxFret) continue;
    final candidate = GuitarTabPosition(s + 1, fret);
    if (best == null || _rank(candidate) < _rank(best)) best = candidate;
  }
  return best;
}

int _rank(GuitarTabPosition p) => p.fret <= 4 ? p.fret : 100 + p.fret;

/// Scientific pitch name for a MIDI number with sharps (`61` → `C#4`).
String midiName(int midi) {
  const names = [
    'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B', //
  ];
  return '${names[midi % 12]}${midi ~/ 12 - 1}';
}

/// Bars `[firstBar, lastBar]` (inclusive) as a beat range.
({double start, double end}) barRange(
  PracticeScore score,
  int firstBar,
  int lastBar,
) {
  final a = math.max(0, firstBar);
  final b = math.min(score.barCount - 1, lastBar);
  return (
    start: a * score.beatsPerBar.toDouble(),
    end: (b + 1) * score.beatsPerBar.toDouble(),
  );
}
