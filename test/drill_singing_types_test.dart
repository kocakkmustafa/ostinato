// Şarkı derslerinin yeni ekran sürümleri: yarım ses yeri, drone üstünde
// derece, iki porteden eşleşeni seçme.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/curriculum/v1_lesson.dart';
import 'package:ostinato/app/drill/drill_generator.dart';
import 'package:ostinato/app/drill/drill_screen.dart';
import 'package:ostinato/app/drill/drill_theory.dart';

import 'support/practice_host.dart';

V1Drill altOf(String id) => V1Lesson.fromJson(
  jsonDecode(File('content/v1/ear/$id.json').readAsStringSync()),
).practice.alternative!.drill;

void main() {
  test('half-step place matches the semitones played', () {
    final drill = altOf('ear-s2-m05-03');
    final seen = <String>{};
    for (var seed = 0; seed < 40; seed++) {
      for (final q in generateDrill(drill, seed: seed)) {
        final m = [for (final n in q.sound!.notes) n.midi.round()];
        final halves = [
          for (var i = 1; i < m.length; i++)
            if (m[i] - m[i - 1] == 1) '$i-${i + 1}',
        ];
        expect(q.expected, halves.isEmpty ? 'none' : halves.first);
        expect(halves.length, lessThanOrEqualTo(1));
        seen.add(q.expected);
      }
    }
    expect(seen, containsAll(['none', '3-4']));
  });

  test('degree over drone: the note is that degree; the drone holds', () {
    for (final id in ['ear-s2-m05-04', 'ear-s2-m05-06']) {
      final drill = altOf(id);
      final degrees = (drill.params['degrees']! as List).cast<int>();
      for (var seed = 0; seed < 30; seed++) {
        for (final q in generateDrill(drill, seed: seed)) {
          final key = SpelledNote.parse(q.values['v0']! as String);
          final note = q.sound!.notes.last;
          const steps = [0, 2, 4, 5, 7, 9, 11];
          final d = int.parse(q.expected);
          expect(degrees, contains(d));
          expect(note.midi.round(), 60 + key.pitchClass + steps[d - 1]);
          final drone = q.sound!.notes.where((n) => n.at == 0).toList();
          expect(drone, hasLength(2));
          expect(drone.first.end, greaterThan(note.end - 0.01));
          expect(q.optionSounds, hasLength(degrees.length));
        }
      }
    }
  });

  test(
    'staff match: the expected staff is the line heard, the other differs',
    () {
      final drill = altOf('ear-s2-m08-05');
      for (var seed = 0; seed < 30; seed++) {
        for (final q in generateDrill(drill, seed: seed)) {
          expect(q.staves, hasLength(2));
          final heard = q.staves[q.answer].notes;
          final other = q.staves[1 - q.answer].notes;
          expect(heard, hasLength(16));
          var diff = 0;
          for (var i = 0; i < heard.length; i++) {
            if (heard[i] != other[i]) diff++;
          }
          expect(diff, inInclusiveRange(1, 2));
          // The sound follows the expected staff note by note.
          expect(q.sound!.notes, hasLength(16));
          expect(
            q.optionSounds![q.answer]!.notes.map((n) => n.midi),
            q.sound!.notes.map((n) => n.midi),
          );
        }
      }
    },
  );

  testWidgets('staff match screen shows staves A and B', (tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      practiceHost(
        DrillScreen(drill: altOf('ear-s2-m08-05'), title: 'Lines', seed: 1),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('drill-staff-A')), findsOneWidget);
    expect(find.byKey(const Key('drill-staff-B')), findsOneWidget);
    expect(find.text('Staff A'), findsWidgets);
  });
}
