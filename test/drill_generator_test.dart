// F2.6a — drill üreticisi: harf tabanlı yazım, belirlenimli tohum, tekil
// doğru şık; desteklenmeyen setler açılmaz.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/curriculum/v1_lesson.dart';
import 'package:ostinato/app/drill/drill_generator.dart';
import 'package:ostinato/app/drill/drill_theory.dart';

V1Lesson lesson(String id) => V1Lesson.fromJson(
  jsonDecode(File('content/v1/gtr/$id.json').readAsStringSync()),
);

String scale(String tonic) =>
    majorScale(SpelledNote.parse(tonic)).map((n) => n.name).join(' ');

String chord(String symbol) {
  final c = parseChord(symbol);
  return chordTones(c.root, c.quality).map((n) => n.name).join(' ');
}

void main() {
  test('spelling follows letters', () {
    expect(scale('G'), 'G A B C D E F#');
    expect(scale('F'), 'F G A Bb C D E');
    expect(scale('D'), 'D E F# G A B C#');
    expect(chord('A7'), 'A C# E G');
    expect(chord('Amaj7'), 'A C# E G#');
    expect(chord('Am7'), 'A C E G');
    expect(chord('Dmaj7'), 'D F# A C#');
    expect(chord('Em'), 'E G B');
    expect(romanChord(SpelledNote.parse('D'), 'V'), 'A');
    expect(romanChord(SpelledNote.parse('C'), 'IV'), 'F');
    expect(enharmonicOf(SpelledNote.parse('C#'))!.name, 'Db');
    expect(enharmonicOf(SpelledNote.parse('Bb'))!.name, 'A#');
    expect(enharmonicOf(SpelledNote.parse('E')), isNull);
    expect(sharpName(fretMidi(6, 5) % 12).name, 'A');
    expect(sharpName(fretMidi(5, 4) % 12).name, 'C#');
    expect(
      minorPentatonic(SpelledNote.parse('A')).map((n) => n.name).join(' '),
      'A C D E G',
    );
  });

  const supported = [
    'gtr-s2-m09-02',
    'gtr-s2-m09-06',
    'gtr-s3-m11-06',
    'gtr-s3-m13-01',
    'gtr-s3-m14-01',
    'gtr-s3-m14-04',
    'gtr-s3-m14-08',
    'gtr-s4-m15-05',
    'gtr-s4-m16-04',
    'gtr-s4-m17-01',
  ];

  test('every supported guitar drill gives sound questions on many seeds', () {
    for (final id in supported) {
      final drill = lesson(id).practice.drill!;
      expect(supportsDrill(drill), isTrue, reason: id);
      for (var seed = 0; seed < 40; seed++) {
        final qs = generateDrill(drill, seed: seed);
        expect(qs, hasLength(drill.count), reason: id);
        for (final q in qs) {
          expect(q.options.toSet(), hasLength(q.options.length), reason: id);
          expect(q.options.length, greaterThanOrEqualTo(3), reason: id);
          expect(q.answer, inInclusiveRange(0, q.options.length - 1));
          switch (q.kind) {
            case DrillPromptKind.noteAtFret:
              final m = q.marks.single;
              expect(
                q.expected,
                sharpName(fretMidi(m.string, m.fret) % 12).name,
              );
            case DrillPromptKind.fretOfNote:
              final s = q.values['v1']! as int;
              final note = SpelledNote.parse(q.values['v0']! as String);
              expect(fretMidi(s, int.parse(q.expected)) % 12, note.pitchClass);
              // No other offered fret sounds the same note.
              for (final o in q.options.where((o) => o != q.expected)) {
                expect(fretMidi(s, int.parse(o)) % 12, isNot(note.pitchClass));
              }
            case DrillPromptKind.enharmonic:
              final shown = SpelledNote.parse(q.values['v0']! as String);
              expect(
                SpelledNote.parse(q.expected).pitchClass,
                shown.pitchClass,
              );
              expect(q.expected, isNot(shown.name));
            case DrillPromptKind.chordTones:
              expect(q.expected, chord(q.values['v0']! as String));
            case DrillPromptKind.romanNumeral:
              expect(
                q.expected,
                romanChord(
                  SpelledNote.parse(q.values['v0']! as String),
                  q.values['v1']! as String,
                ),
              );
            case DrillPromptKind.scaleStep ||
                DrillPromptKind.pentatonicNote ||
                DrillPromptKind.bluesLine ||
                DrillPromptKind.bluesBar:
              break;
            default:
              fail('heard kind in a silent set: ${q.kind}');
          }
          if (q.marks.isNotEmpty) {
            final (first, last) = q.fretWindow!;
            for (final m in q.marks) {
              expect(m.fret, inInclusiveRange(first, last), reason: id);
            }
          }
        }
      }
    }
  });

  test('the same seed replays the same session', () {
    final drill = lesson('gtr-s2-m09-02').practice.drill!;
    String key(List<DrillQuestion> qs) => [
      for (final q in qs)
        '${q.kind}${q.values}${q.options}${q.answer}${q.marks}',
    ].join('|');
    expect(
      key(generateDrill(drill, seed: 7)),
      key(generateDrill(drill, seed: 7)),
    );
    expect(
      key(generateDrill(drill, seed: 7)),
      isNot(key(generateDrill(drill, seed: 8))),
    );
  });

  test('sets needing art, audio or a keyboard stay closed', () {
    for (final id in [
      'gtr-s1-m01-01', // guitar parts illustration
      'gtr-s1-test', // open strings by ear
      'gtr-s2-m07-08', // repeat-sign glyphs
    ]) {
      final drill = lesson(id).practice.drill!;
      expect(supportsDrill(drill), isFalse, reason: id);
      expect(() => generateDrill(drill, seed: 1), throwsUnsupportedError);
    }
    // K8 opened the hand diagram for guitar finger numbers (gtr-s1-m01-03,
    // test/k8_camera_lesson_test.dart); piano numbers (thumb = 1) stay
    // closed.
    expect(
      supportsDrill(
        const V1Drill('diagram_match', 6, {
          'set': 'piano_finger_numbers',
          'diagram': 'hand',
        }),
      ),
      isFalse,
    );
    // The keyboard opens only for scale steps (ear-s2-m05-01); other
    // keyboard sets stay closed.
    expect(
      supportsDrill(
        const V1Drill('diagram_match', 4, {
          'set': 'chord_shapes',
          'diagram': 'keyboard',
        }),
      ),
      isFalse,
    );
  });

  test('a degree pattern answer on the 12-bar blues matches its bar', () {
    final drill = lesson('gtr-s3-m13-01').practice.drill!;
    final rows = (drill.params['items']! as List).cast<String>();
    final bars = [for (final r in rows) ...r.split(' ')];
    for (var seed = 0; seed < 30; seed++) {
      for (final q in generateDrill(drill, seed: seed)) {
        if (q.kind == DrillPromptKind.bluesBar) {
          expect(q.expected, bars[(q.values['v0']! as int) - 1]);
        } else {
          expect(q.expected, rows[(q.values['v0']! as int) - 1]);
        }
      }
    }
  });
}
