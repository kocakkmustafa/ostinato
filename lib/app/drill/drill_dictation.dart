import 'dart:math' as math;

import 'drill_sound.dart';
import 'drill_theory.dart';

/// F2.6d — dictation (pure Dart): rhythms in 4/4 built from note values,
/// short melodies as scale degrees. The answer is what the learner writes,
/// not an option; its key is a canonical string so equal writing matches.

/// Beats per rhythm value (quarter = 1).
const Map<String, double> rhythmBeats = {
  'whole': 4,
  'half': 2,
  'dottedQuarter': 1.5,
  'quarter': 1,
  'eighthPair': 1,
  'eighth': 0.5,
  'quarterRest': 1,
  'halfRest': 2,
};

bool isRest(String value) => value.endsWith('Rest');

/// The tie token: the next note continues the previous one (no new attack).
const String kTie = '~';

/// Sounding events `(start, length, rest)` in beats: an eighth pair is two
/// eighths and a tied note lengthens the note before it.
List<({double start, double length, bool rest})> rhythmEvents(
  List<String> values,
) {
  final out = <({double start, double length, bool rest})>[];
  var at = 0.0;
  var tied = false;
  for (final v in values) {
    if (v == kTie) {
      tied = true;
      continue;
    }
    final parts = v == 'eighthPair' ? ['eighth', 'eighth'] : [v];
    for (final part in parts) {
      final len = rhythmBeats[part]!;
      if (tied && out.isNotEmpty && !out.last.rest && !isRest(part)) {
        final last = out.removeLast();
        out.add((start: last.start, length: last.length + len, rest: false));
      } else {
        out.add((start: at, length: len, rest: isRest(part)));
      }
      tied = false;
      at += len;
    }
  }
  return out;
}

/// Canonical answer key: what is heard. Two eighths equal a pair, and a
/// quarter tied to a quarter equals a half.
String rhythmKey(List<String> values) => [
  for (final e in rhythmEvents(values))
    '${e.start}:${e.length}${e.rest ? 'r' : ''}',
].join(' ');

double rhythmLength(List<String> values) =>
    values.fold(0, (sum, v) => v == kTie ? sum : sum + rhythmBeats[v]!);

/// Whether [next] may be written after [values] (it fits the bar and keeps
/// quarter-beat positions on the grid: a lone eighth only completes a
/// dotted quarter's half beat).
bool rhythmFits(List<String> values, String next, {required int bars}) {
  final at = rhythmLength(values);
  final last = values.isEmpty ? null : values.last;
  if (next == kTie) {
    // A tie joins two sounding notes, so something must still follow.
    return last != null &&
        last != kTie &&
        !isRest(last) &&
        at < bars * 4 - 1e-9;
  }
  if (last == kTie && isRest(next)) return false;
  final beats = rhythmBeats[next]!;
  final barEnd = (at ~/ 4 + 1) * 4.0;
  if (at + beats > math.min(barEnd, bars * 4.0) + 1e-9) return false;
  final offBeat = at % 1 != 0;
  if (offBeat) return next == 'eighth';
  return true;
}

/// A random rhythm of [bars] bars from [values], every bar with at least
/// one sounding note and no unfinished half beat.
List<String> generateRhythm(
  math.Random rng,
  List<String> values, {
  required int bars,
  bool ties = false,
}) {
  for (var attempt = 0; attempt < 200; attempt++) {
    final out = <String>[];
    var ok = true;
    while (rhythmLength(out) < bars * 4 - 1e-9) {
      final fit = [
        for (final v in values)
          if (rhythmFits(out, v, bars: bars) &&
              // A dotted quarter needs an eighth to finish its beat.
              (v != 'dottedQuarter' || values.contains('eighth')))
            v,
      ];
      if (fit.isEmpty) {
        ok = false;
        break;
      }
      // Prefer a lone eighth only where it completes a dotted quarter.
      final onBeat = rhythmLength(out) % 1 == 0;
      final pool = onBeat ? fit.where((v) => v != 'eighth').toList() : fit;
      final choices = pool.isEmpty ? fit : pool;
      out.add(choices[rng.nextInt(choices.length)]);
    }
    if (!ok) continue;
    // Every bar sounds at least once.
    var pos = 0.0;
    final sounding = List.filled(bars, false);
    for (final v in out) {
      if (!isRest(v)) sounding[(pos ~/ 4).clamp(0, bars - 1)] = true;
      pos += rhythmBeats[v]!;
    }
    if (!sounding.every((s) => s)) continue;
    if (!ties) return out;
    // One tie, mid-bar (beat 3) or across a bar line, between two notes.
    final spots = <int>[];
    var at = 0.0;
    for (var i = 0; i < out.length - 1; i++) {
      at += rhythmBeats[out[i]]!;
      final boundary = at % 4 == 0 || at % 4 == 2;
      if (boundary && !isRest(out[i]) && !isRest(out[i + 1])) spots.add(i);
    }
    if (spots.isEmpty) continue;
    final i = spots[rng.nextInt(spots.length)];
    return [...out.sublist(0, i + 1), kTie, ...out.sublist(i + 1)];
  }
  throw StateError('No rhythm fits these values');
}

/// One count-in bar of clicks, then the rhythm tapped on one pitch.
DrillSound rhythmSound(List<String> values, {required int bpm}) {
  final beat = 60 / bpm;
  final notes = <DrillNote>[
    for (var b = 0; b < 4; b++)
      DrillNote(
        at: b * beat,
        midi: 0,
        seconds: 0.05,
        gain: b == 0 ? 1 : 0.5,
        timbre: DrillTimbre.click,
      ),
  ];
  for (final e in rhythmEvents(values)) {
    if (e.rest) continue;
    notes.add(
      DrillNote(
        at: (4 + e.start) * beat,
        midi: 57,
        seconds: e.length * beat * 0.9,
      ),
    );
  }
  return DrillSound(notes);
}

/// Degrees 1–7 of [key] as MIDI, the tonic placed so 1…5 fit [lo]…[hi].
List<int> degreeMidis(SpelledNote key, int lo, int hi) {
  const steps = [0, 2, 4, 5, 7, 9, 11];
  var tonic = 60 + key.pitchClass;
  while (tonic + 7 > hi && tonic - 12 >= lo) {
    tonic -= 12;
  }
  while (tonic < lo) {
    tonic += 12;
  }
  return [for (final s in steps) tonic + s];
}

/// Written pitch (`B4`) of degree [degree] in [key] at [midi]; the letter
/// comes from the key's spelling, the key signature carries the accidental.
String degreePitch(SpelledNote key, int degree, int midi) {
  final note = majorScale(key)[degree - 1];
  // The octave of the written letter, not of the sounding pitch class: B♭4
  // and C5 differ by one letter even across the octave line.
  final octave = (midi - note.accidental) ~/ 12 - 1;
  return '${note.name[0]}$octave';
}
