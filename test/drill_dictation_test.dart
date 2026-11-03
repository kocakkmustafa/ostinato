// F2.6d — dikte: ritim ölçüye ve vuruş ızgarasına uyar; iki sekizlik ile
// sekizlik çifti aynı sayılır; ezgi tonda kalır; ilk nota verilir.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/curriculum/v1_lesson.dart';
import 'package:ostinato/app/drill/drill_dictation.dart';
import 'package:ostinato/app/drill/drill_generator.dart';
import 'package:ostinato/app/drill/drill_screen.dart';
import 'package:ostinato/app/drill/drill_session.dart';
import 'package:ostinato/app/drill/drill_sound.dart';
import 'package:ostinato/app/drill/drill_theory.dart';

import 'support/practice_host.dart';

V1Drill drillOf(String id) => V1Lesson.fromJson(
  jsonDecode(File('content/v1/ear/$id.json').readAsStringSync()),
).practice.drill!;

void main() {
  test('rhythms fill their bars on the beat grid, every bar sounds', () {
    for (final id in ['ear-s2-m07-01', 'ear-s2-m07-02', 'ear-s2-m07-03']) {
      final drill = drillOf(id);
      expect(supportsDrill(drill), isTrue, reason: id);
      final bars = drill.params['bars']! as int;
      for (var seed = 0; seed < 40; seed++) {
        final values = (drill.params['values']! as List).cast<String>();
        final r = generateRhythm(math.Random(seed), values, bars: bars);
        expect(rhythmLength(r), bars * 4, reason: '$id $r');
        // Re-entering it value by value is always allowed.
        final entered = <String>[];
        for (final v in r) {
          expect(rhythmFits(entered, v, bars: bars), isTrue, reason: '$r');
          entered.add(v);
        }
        // No value crosses a bar line.
        var pos = 0.0;
        for (final v in r) {
          final end = pos + rhythmBeats[v]!;
          expect((pos ~/ 4) == ((end - 1e-9) ~/ 4), isTrue, reason: '$r');
          pos = end;
        }
      }
    }
  });

  test('tied rhythms: one tie at mid-bar or a bar line, between notes', () {
    final drill = drillOf('ear-s2-m07-04');
    expect(supportsDrill(drill), isTrue);
    final values = (drill.params['values']! as List).cast<String>();
    for (var seed = 0; seed < 40; seed++) {
      final r = generateRhythm(math.Random(seed), values, bars: 2, ties: true);
      expect(r.where((v) => v == kTie), hasLength(1), reason: '$r');
      final i = r.indexOf(kTie);
      expect(isRest(r[i - 1]) || isRest(r[i + 1]), isFalse, reason: '$r');
      final at = rhythmLength(r.sublist(0, i));
      expect(at % 4 == 0 || at % 4 == 2, isTrue, reason: '$r');
      expect(rhythmLength(r), 8);
      // Re-entering it with the tie button is allowed step by step.
      final entered = <String>[];
      for (final v in r) {
        expect(rhythmFits(entered, v, bars: 2), isTrue, reason: '$r $v');
        entered.add(v);
      }
    }
    // A tie never follows a rest, never precedes one, never ends the line.
    expect(rhythmFits(['quarterRest'], kTie, bars: 1), isFalse);
    expect(rhythmFits(['quarter', kTie], 'quarterRest', bars: 1), isFalse);
    expect(rhythmFits(['whole'], kTie, bars: 1), isFalse);
  });

  test('a tie merges notes: quarter~quarter is heard as a half', () {
    expect(
      rhythmKey(['quarter', kTie, 'quarter', 'half']),
      rhythmKey(['half', 'half']),
    );
    expect(
      rhythmKey(['quarter', 'quarter', 'half']),
      isNot(rhythmKey(['half', 'half'])),
    );
    final s = rhythmSound(['quarter', kTie, 'quarter', 'half'], bpm: 60);
    final taps = s.notes.where((n) => n.timbre != DrillTimbre.click).toList();
    expect(taps, hasLength(2));
    expect(taps.first.seconds, closeTo(2 * 0.9, 1e-9));
  });

  test('two eighths equal an eighth pair; the sound has the count-in', () {
    expect(
      rhythmKey(['eighthPair', 'half', 'quarter']),
      rhythmKey(['eighth', 'eighth', 'half', 'quarter']),
    );
    final s = rhythmSound(['quarter', 'quarterRest', 'half'], bpm: 60);
    final clicks = s.notes.where((n) => n.timbre == DrillTimbre.click);
    final taps = s.notes.where((n) => n.timbre != DrillTimbre.click);
    expect(clicks, hasLength(4));
    expect(taps.map((n) => n.at), [4.0, 6.0]);
  });

  test('melodies stay in the key and range; the first note is given', () {
    final drill = drillOf('ear-s2-m08-04');
    expect(supportsDrill(drill), isTrue);
    for (var seed = 0; seed < 40; seed++) {
      for (final q in generateDrill(drill, seed: seed)) {
        final e = q.entry!;
        final degrees = q.expected.split(' ');
        expect(degrees, hasLength(3));
        expect(e.given, [degrees.first]);
        final key = e.key!;
        final tail = q.sound!.notes.where((n) => n.at >= kAfterCadence - 1e-9);
        final scale = majorScale(key).map((n) => n.pitchClass).toSet();
        for (final n in tail) {
          expect(scale, contains(n.midi.round() % 12));
          expect(n.midi, inInclusiveRange(60, 74));
        }
        // Written pitches spell the key: F major writes B (flat by key).
        expect(e.pitches[3][0], majorScale(key)[3].name[0]);
        // A melody written exactly as heard matches.
        final s = DrillSession([q])..submit(degrees);
        expect(s.matchedCurrent, isTrue);
      }
    }
  });

  test('a different written answer counts once and comes back', () {
    final drill = drillOf('ear-s2-m07-01');
    final qs = generateDrill(drill, seed: 2);
    final s = DrillSession(qs);
    s.submit(
      ['whole'] == qs[0].expected.split(' ') ? ['half', 'half'] : ['whole'],
    );
    expect(s.matchedCurrent, isFalse);
    expect(s.chosen, -1);
    expect(s.written, isNotNull);
  });

  testWidgets('rhythm entry: palette respects the bar, Check when full', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final drill = drillOf('ear-s2-m07-01');
    await tester.pumpWidget(
      practiceHost(DrillScreen(drill: drill, title: 'Rhythm', seed: 1)),
    );
    await tester.pumpAndSettle();
    final check = find.byKey(const Key('drill-check'));
    expect(tester.widget<FilledButton>(check).onPressed, isNull);
    await tester.tap(find.byKey(const Key('drill-add-half')));
    await tester.tap(find.byKey(const Key('drill-add-half')));
    await tester.pump();
    // The bar is full: nothing more fits, Check is on.
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('drill-add-quarter')))
          .onPressed,
      isNull,
    );
    expect(tester.widget<FilledButton>(check).onPressed, isNotNull);
    await tester.tap(find.byKey(const Key('drill-undo')));
    await tester.pump();
    expect(tester.widget<FilledButton>(check).onPressed, isNull);
    await tester.tap(find.byKey(const Key('drill-add-quarter')));
    await tester.tap(find.byKey(const Key('drill-add-quarterRest')));
    await tester.pump();
    await tester.tap(check);
    await tester.pump();
    expect(find.byKey(const Key('drill-feedback')), findsOneWidget);
  });

  testWidgets('melody entry keeps the given note; Clear returns to it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final drill = drillOf('ear-s2-m08-04');
    await tester.pumpWidget(
      practiceHost(DrillScreen(drill: drill, title: 'Melody', seed: 4)),
    );
    await tester.pumpAndSettle();
    expect(find.text('1 of 3 notes written'), findsOneWidget);
    expect(
      tester.widget<TextButton>(find.byKey(const Key('drill-undo'))).onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const Key('drill-add-3')));
    await tester.tap(find.byKey(const Key('drill-add-2')));
    await tester.pump();
    expect(find.text('3 of 3 notes written'), findsOneWidget);
    await tester.tap(find.byKey(const Key('drill-clear')));
    await tester.pump();
    expect(find.text('1 of 3 notes written'), findsOneWidget);
  });

  testWidgets('tie button: only after a note, and the line cannot end on it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      practiceHost(
        DrillScreen(drill: drillOf('ear-s2-m07-04'), title: 'Ties', seed: 1),
      ),
    );
    await tester.pumpAndSettle();
    final tie = find.byKey(const Key('drill-add-tie'));
    expect(tester.widget<OutlinedButton>(tie).onPressed, isNull);
    await tester.tap(find.byKey(const Key('drill-add-quarter')));
    await tester.pump();
    expect(tester.widget<OutlinedButton>(tie).onPressed, isNotNull);
    await tester.tap(tie);
    await tester.pump();
    expect(find.text('tie'), findsWidgets);
    // After a tie, a rest cannot follow.
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const Key('drill-add-quarterRest')),
          )
          .onPressed,
      isNull,
    );
  });
}
