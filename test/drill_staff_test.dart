// F2.6c — porte: nota adı (anahtar, ek çizgi), donanım, porte aralığı;
// kadanstan sonra durak sorusu ve kadanslı aralık.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/curriculum/v1_lesson.dart';
import 'package:ostinato/app/drill/drill_generator.dart';
import 'package:ostinato/app/drill/drill_screen.dart';
import 'package:ostinato/app/drill/drill_sound.dart';
import 'package:ostinato/app/drill/drill_staff.dart';
import 'package:ostinato/app/drill/drill_theory.dart';

import 'support/practice_host.dart';

V1Drill drillOf(String path) => V1Lesson.fromJson(
  jsonDecode(File('content/v1/$path.json').readAsStringSync()),
).practice.drill!;

void main() {
  test('staff steps match the piano lessons (E4/G2 bottom line)', () {
    expect(drillStaffStep('E4', 'treble'), 0);
    expect(drillStaffStep('F5', 'treble'), 8);
    expect(drillStaffStep('C4', 'treble'), -2);
    expect(drillStaffStep('G2', 'bass'), 0);
    expect(drillStaffStep('A3', 'bass'), 8);
    expect(drillStaffStep('C4', 'bass'), 10);
  });

  test('note names: clef, range and ledger rules hold on many seeds', () {
    for (final path in [
      'ear/ear-s1-m04-02',
      'ear/ear-s1-m04-03',
      'ear/ear-s1-m04-04',
      'ear/ear-s1-m04-05',
      'pno/pno-s1-m03-02',
      'pno/pno-s1-m03-05',
      'pno/pno-s2-m09-06',
    ]) {
      final drill = drillOf(path);
      expect(supportsDrill(drill), isTrue, reason: path);
      final ledgerOnly = drill.params['ledgerOnly'] == true;
      final maxLedger = (drill.params['ledgerLinesMax'] as int?) ?? 3;
      for (var seed = 0; seed < 30; seed++) {
        for (final q in generateDrill(drill, seed: seed)) {
          expect(q.kind, DrillPromptKind.staffNote);
          final staff = q.staff!;
          final pitch = staff.notes.single;
          expect(q.expected, pitch[0], reason: path);
          final step = drillStaffStep(pitch, staff.clef);
          final ledger = step < -1
              ? (-step) ~/ 2
              : step > 9
              ? (step - 8) ~/ 2
              : 0;
          expect(ledger, lessThanOrEqualTo(maxLedger), reason: '$path $pitch');
          if (ledgerOnly) expect(ledger, greaterThan(0), reason: path);
          if (drill.params['clef'] == 'grand') {
            expect(staff.clef, noteMidi(pitch) >= 60 ? 'treble' : 'bass');
          }
        }
      }
    }
  });

  test('key signatures name their key', () {
    final drill = drillOf('ear/ear-s2-m08-03');
    for (var seed = 0; seed < 20; seed++) {
      for (final q in generateDrill(drill, seed: seed)) {
        expect(q.staff!.keySignature, keySignatures[q.expected]);
        expect(['treble', 'bass'], contains(q.staff!.clef));
      }
    }
  });

  test('staff intervals count letters, both directions', () {
    for (final path in ['pno/pno-s2-m05-10', 'pno/pno-s2-m09-02']) {
      final drill = drillOf(path);
      expect(supportsDrill(drill), isTrue);
      for (var seed = 0; seed < 30; seed++) {
        for (final q in generateDrill(drill, seed: seed)) {
          final [a, b] = q.staff!.notes;
          final steps =
              (drillStaffStep(b, 'treble') - drillStaffStep(a, 'treble')).abs();
          expect('${steps + 1}', q.expected, reason: '$path $a $b');
        }
      }
    }
  });

  test('tonic-or-not plays a cadence first; about two in five are tonic', () {
    final drill = drillOf('ear/ear-s2-m05-05');
    var tonic = 0, total = 0;
    for (var seed = 0; seed < 40; seed++) {
      for (final q in generateDrill(drill, seed: seed)) {
        final notes = q.sound!.notes;
        final last = notes.last;
        final key = SpelledNote.parse(q.values['v0']! as String);
        // Cadence: four chords before the question note.
        expect(notes.where((n) => n.at < last.at).length, 16);
        final isTonic = last.midi.round() % 12 == key.pitchClass;
        expect(q.expected, isTonic ? 'tonic' : 'notTonic');
        if (isTonic) tonic++;
        total++;
      }
    }
    expect(tonic / total, inInclusiveRange(0.3, 0.5));
  });

  test('cadence intervals stay in the key and match their name', () {
    final drill = drillOf('ear/ear-s2-m06-06');
    expect(supportsDrill(drill), isTrue);
    for (var seed = 0; seed < 30; seed++) {
      for (final q in generateDrill(drill, seed: seed)) {
        final notes = q.sound!.notes;
        final tail = notes.where((n) => n.at >= 3.3).toList();
        expect(tail, hasLength(2));
        final semis = (tail[1].midi - tail[0].midi).abs().round();
        expect(semis, intervalSemitones[q.expected]);
        expect(notes.length, 18); // 16 cadence notes + 2
      }
    }
  });

  testWidgets('screen shows the staff and localized options', (tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final drill = drillOf('ear/ear-s1-m04-02');
    await tester.pumpWidget(
      practiceHost(
        locale: 'tr',
        DrillScreen(drill: drill, title: 'Porte', seed: 1),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('drill-staff')), findsOneWidget);
    expect(find.text('Bu nota hangisi?'), findsOneWidget);
    expect(find.textContaining('('), findsWidgets); // C (Do) style names
    expect(find.byKey(const Key('drill-play-question')), findsNothing);
  });

  test('a cadence sound renders within bounds', () {
    final q = generateDrill(drillOf('ear/ear-s2-m05-05'), seed: 2).first;
    final pcm = renderDrillSound(q.sound!, sampleRate: 48000);
    expect(pcm.every((v) => v.isFinite && v.abs() <= 0.8 + 1e-6), isTrue);
  });
}
