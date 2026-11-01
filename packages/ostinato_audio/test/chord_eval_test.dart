// E53 harness (tool/chord_eval.dart): voicing table (PLAN §5, §9.3),
// variant generation (§6), isolated-chords voicing rule, K0 vocabulary.
import 'dart:typed_data';

import 'package:ostinato_audio/src/harmony/chord_string_checker.dart';
import 'package:test/test.dart';

import '../tool/chord_eval.dart';

void main() {
  test('voicing table: 60 voicings, every pitch playable at fret 0–12 (§9.3)',
      () {
    expect(tableProblems(), isEmpty);
    expect(table.length, 60);
    expect(tableById['Ebar:F']!.midi, [41, 48, 53, 57, 60, 65]);
    expect(tableById['Abar:Bm']!.midi, [null, 47, 54, 59, 62, 66]);
    expect(tableById['Ebar:Cm'], isNull); // minor E-barre: F, G, A only
    expect(tableById['Abar:B7']!.midi, [null, 47, 54, 57, 63, 66]);
  });

  test('K0 vocabulary is major / minor / dominant 7 by pitch-class set', () {
    expect(k0NameOf({4, 7, 11}), 'Em');
    expect(k0NameOf({2, 6, 9}), 'D');
    expect(k0NameOf({4, 8, 11, 2}), 'E7');
    expect(k0NameOf({4, 11}), isNull); // power chord
    expect(k0NameOf({2, 7, 9}), isNull); // Dsus4
    expect(k0NameOf(tableById['slash:D/F#']!.voicing.pitchClasses), 'D');
  });

  test('isolated-chords rule: open shape, else E-barre ≤ fret 4, else A-barre',
      () {
    expect(igcAllowed(7, false).map((v) => v.id), ['open:G3', 'open:G4']);
    expect(igcAllowed(6, true).single.midi,
        [42, 49, 54, 57, 61, 66]); // F#m E-shape f2
    expect(igcAllowed(1, false).single.midi,
        [null, 49, 56, 61, 65, 68]); // C# A-shape f4
    expect(igcAllowed(3, true).single.midi,
        [null, 51, 58, 63, 66, 70]); // D#m A-shape f6
    expect(parseLabel('A#m'), (root: 10, minor: true));
  });

  test('synthetic variants follow PLAN §6 and are deterministic', () {
    final v = tableById['open:Em']!;
    final a = synthVariants(v, 900, StrumRenderer(48000));
    final b = synthVariants(v, 900, StrumRenderer(48000));
    final names = [for (final x in a) x.name];
    expect(names.where((n) => n == 'TAM').length, 3);
    expect(names.where((n) => n == 'EKSIK1').length, 6);
    expect(names.where((n) => n == 'SUST1').length, 2);
    expect(names.where((n) => n == 'EKSIK2').length, 1);
    expect(names.where((n) => n == 'FARKLI').length, inInclusiveRange(1, 3));
    expect(names.where((n) => n == 'YANLIS').length, 1);
    expect(names.where((n) => n == 'FAZLA').length, 0); // Em plays all six
    for (var i = 0; i < a.length; i++) {
      expect(a[i].audio, b[i].audio);
      expect(a[i].meta, b[i].meta);
    }
    for (final x in a.where((x) => x.name == 'FARKLI')) {
      final played = tableById[x.meta['played']]!.voicing.pitchClasses;
      final pcs = v.voicing.pitchClasses;
      final d = played.difference(pcs).length + pcs.difference(played).length;
      expect(d, inInclusiveRange(1, 3));
    }
    final w = a.firstWhere((x) => x.name == 'YANLIS').meta['wrong'] as List;
    expect(v.voicing.pitchClasses.contains((w[1] as int) % 12), isFalse);
  });

  test('EKSIK1 is the TAM rep-0 strum minus exactly one string', () {
    final v = tableById['pow3:A5']!;
    final r = StrumRenderer(48000);
    final vars = synthVariants(v, 901, r);
    final tam = vars.firstWhere((x) => x.name == 'TAM' && x.rep == 0).audio;
    final e = vars.where((x) => x.name == 'EKSIK1').toList();
    expect(e.length, 3);
    // Sum over the three single-removals = 2 × TAM (each string missing once).
    final s = Float64List(tam.length);
    for (final x in e) {
      for (var i = 0; i < s.length; i++) {
        s[i] += x.audio[i];
      }
    }
    for (var i = 0; i < s.length; i += 997) {
      expect(s[i], closeTo(2 * tam[i], 1e-12));
    }
    final f = vars.firstWhere((x) => x.name == 'FAZLA');
    expect(f.meta['extraString'], 6); // bass side first
  });

  test('table voicings are StringVoicing-compatible', () {
    for (final v in table) {
      expect(v.voicing.midi.length, 6);
      expect(v.voicing.playedIndices.length, greaterThanOrEqualTo(2));
      expect(standardTuningMidi.length, 6);
    }
  });
}
