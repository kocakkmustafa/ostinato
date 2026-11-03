// Kalan drill'ler: klavyede tam/yarım ses, portede çizgi/aralık, ölçü
// çizgisi ve 4/4 simgeleri; kulak kursunun bütün drill'leri artık açık.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/curriculum/v1_lesson.dart';
import 'package:ostinato/app/drill/drill_generator.dart';
import 'package:ostinato/app/drill/drill_screen.dart';
import 'package:ostinato/app/drill/drill_staff.dart';
import 'package:ostinato/app/drill/drill_theory.dart';

import 'support/practice_host.dart';

V1Drill drillOf(String id) => V1Lesson.fromJson(
  jsonDecode(File('content/v1/ear/$id.json').readAsStringSync()),
).practice.drill!;

void main() {
  test('keyboard: whole or half step between neighbouring scale notes', () {
    final drill = drillOf('ear-s2-m05-01');
    expect(supportsDrill(drill), isTrue);
    var halves = 0;
    for (var seed = 0; seed < 40; seed++) {
      for (final q in generateDrill(drill, seed: seed)) {
        expect(q.kind, DrillPromptKind.stepSize);
        final [a, b] = q.keys;
        expect(q.expected, b - a == 1 ? 'half' : 'whole');
        final key = SpelledNote.parse(q.values['v0']! as String);
        // Half steps sit between degrees 3–4 and 7–8 only.
        final degree = ((a - 60 - key.pitchClass) % 12);
        if (b - a == 1) {
          halves++;
          expect(degree == 4 || degree == 11, isTrue, reason: '$key $a');
        }
        expect(q.optionSounds, hasLength(2));
        expect(q.sound!.notes.last.midi - q.sound!.notes.first.midi, b - a);
      }
    }
    expect(halves, greaterThan(0));
  });

  test('staff places: the note sits on the named line or space', () {
    final drill = drillOf('ear-s1-m04-01');
    expect(supportsDrill(drill), isTrue);
    for (var seed = 0; seed < 40; seed++) {
      for (final q in generateDrill(drill, seed: seed)) {
        final step = drillStaffStep(q.staff!.notes.single, 'treble');
        final n = int.parse(q.expected.split('_').last);
        expect(step, q.expected.startsWith('line') ? 2 * (n - 1) : 2 * n - 1);
        expect(q.options.toSet(), hasLength(q.options.length));
      }
    }
  });

  test('bar symbols: the highlighted sign is the answer; 4/4 has 4', () {
    final drill = drillOf('ear-s1-m03-04');
    expect(supportsDrill(drill), isTrue);
    final kinds = <DrillPromptKind>{};
    for (var seed = 0; seed < 30; seed++) {
      for (final q in generateDrill(drill, seed: seed)) {
        kinds.add(q.kind);
        expect(q.staff!.timeSignature, '4/4');
        if (q.kind == DrillPromptKind.beatsInBar) {
          expect(q.expected, '4');
          expect(q.staff!.highlight, isNull);
        } else {
          expect(q.staff!.highlight, q.expected);
        }
      }
    }
    expect(kinds, {DrillPromptKind.staffSymbol, DrillPromptKind.beatsInBar});
  });

  test('every drill of the ear course is now supported', () {
    final closed = <String>[];
    for (final f in Directory('content/v1/ear').listSync()) {
      if (f is! File || !f.path.endsWith('.json')) continue;
      final l = V1Lesson.fromJson(jsonDecode(f.readAsStringSync()));
      final d = l.practice.drill;
      if (d != null && !supportsDrill(d)) closed.add(l.id);
    }
    expect(closed, isEmpty);
  });

  testWidgets('screen draws the keyboard and localized step options', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      practiceHost(
        locale: 'tr',
        DrillScreen(drill: drillOf('ear-s2-m05-01'), title: 'Adımlar', seed: 1),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('drill-keyboard')), findsOneWidget);
    expect(find.text('Tam ses'), findsOneWidget);
    expect(find.text('Yarım ses'), findsOneWidget);
    expect(find.byKey(const Key('drill-play-question')), findsOneWidget);
  });
}
