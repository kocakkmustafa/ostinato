// F2.3 — akan notasyon: dizi ayrıştırıcı, tab konumu, taşıyıcı (döngü,
// "Beni bekle"), tempo, tab şeridi.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/curriculum/v1_lesson.dart';
import 'package:ostinato/app/practice/loop/practice_marks.dart';
import 'package:ostinato/app/practice/loop/practice_score.dart';
import 'package:ostinato/app/practice/loop/practice_tab_strip.dart';
import 'package:ostinato/app/practice/loop/practice_transport.dart';
import 'package:ostinato/app/practice/loop/practice_visual_theme.dart';

import 'support/practice_host.dart';

void main() {
  group('PracticeScore.parse', () {
    test('guitar line: quarters, each phrase on a bar line', () {
      final s = PracticeScore.parse('E2 F2 G2 F2 E2 | E2 F2 G2 F2 E2');
      expect(s.beatsPerBar, 4);
      expect(s.events, hasLength(10));
      expect(s.events.map((e) => e.midi).take(5), [40, 41, 43, 41, 40]);
      expect(s.events[4].startBeat, 4);
      // Second phrase restarts on the downbeat of bar 3.
      expect(s.events[5].startBeat, 8);
      expect(s.events[5].bar, 2);
      expect(s.totalBeats, 16);
    });

    test('rhythm lines with meter, ties, dots and rests', () {
      final s = PracticeScore.parse('3/4: q q q | h. | ee q q | h q');
      expect(s.beatsPerBar, 3);
      expect(s.events.map((e) => e.startBeat), [
        0, 1, 2, 3, 6, 6.5, 7, 8, 9, 11, //
      ]);
      expect(s.events[3].durationBeats, 3);
      expect(s.events.every((e) => e.kind == PracticeEventKind.onset), isTrue);
      final r = PracticeScore.parse('4/4: q qr ee q | h~q qr');
      expect(r.events.map((e) => e.startBeat), [0, 2, 2.5, 3, 4]);
      expect(r.events.last.durationBeats, 3);
    });

    test('pitch rhythm suffix, accidentals, degrees and repeats', () {
      final s = PracticeScore.parse('C#4:h Bb3:e. G3');
      expect(s.events.map((e) => e.midi), [61, 58, 55]);
      expect(s.events.map((e) => e.durationBeats), [2, .75, 1]);
      final d = PracticeScore.parse('1-3-5-8 | ×4');
      expect(d.events, hasLength(16));
      expect(d.events.first.kind, PracticeEventKind.degree);
      expect(d.events[4].startBeat, 4);
    });

    test('triplet eighths: three notes fill one beat', () {
      final s = PracticeScore.parse(
        'A2:t C3:t D3:t E3:q G3:h | A3:t tr A3:t q h',
      );
      expect(s.events.map((e) => e.startBeat).take(5), [
        0, closeTo(1 / 3, 1e-9), closeTo(2 / 3, 1e-9), 1, 2, //
      ]);
      expect(s.events[5].startBeat, 4, reason: 'the bar is exactly full');
      expect(s.events[6].startBeat, closeTo(4 + 2 / 3, 1e-9));
      expect(s.totalBeats, 8);
    });

    test('degrees: accidentals and rhythm suffixes', () {
      final s = PracticeScore.parse(
        '1-2-b3-4-5 | 5:e 4:e b3:q 1:h | #4:q. b7:e',
      );
      expect(s.events.map((e) => e.degree), [1, 2, 3, 4, 5, 5, 4, 3, 1, 4, 7]);
      expect(s.events.map((e) => e.degreeShift), [
        0,
        0,
        -1,
        0,
        0,
        0,
        0,
        -1,
        0,
        1,
        -1,
      ]);
      expect(s.events[5].startBeat, 8);
      expect(s.events.sublist(5, 9).map((e) => e.durationBeats), [
        .5,
        .5,
        1,
        2,
      ]);
      expect(s.events[9].durationBeats, 1.5);
      expect(s.events[9].startBeat, 12);
      expect(s.totalBeats, 16);
      expect(() => PracticeScore.parse('1-2-x3'), throwsFormatException);
    });

    test('rejects unknown tokens and meters', () {
      expect(() => PracticeScore.parse(''), throwsFormatException);
      expect(() => PracticeScore.parse('E2 zz'), throwsFormatException);
      expect(() => PracticeScore.parse('5/16: q'), throwsFormatException);
    });

    test('a tie across the bar line is one onset', () {
      final s = PracticeScore.parse('4/4: h q q~ | q q h');
      expect(s.events.map((e) => e.durationBeats), [2, 1, 2, 1, 2]);
      expect(s.events[2].startBeat, 3);
    });

    test('a chord name before a bar is a label, not an event', () {
      final s = PracticeScore.parse('4/4: Am h hr | G q qr q qr');
      expect(
        s.events.map((e) => e.kind),
        everyElement(PracticeEventKind.onset),
      );
      expect(s.events.map((e) => e.startBeat), [0, 4, 6]);
      expect(s.hasPitches, isFalse);
    });

    test('every written single-note v1 lesson sequence parses and fits '
        'its bars', () {
      // Technique notation the single-note line cannot carry yet: double
      // stops `C3/E4`, hammer-on `h`, pull-off `p`, slide ` / `, bend
      // `b`/`pb`, release `r`, vibrato `vib` (90-ders-yazim-kilavuzu §3.3).
      // Those lessons stay out of measured practice until the engine
      // measures them.
      final technique = RegExp(
        r'(?:^|\s)(?:h|p|b|pb|r|vib|/)(?=\s|$)|[A-G][#b♯♭]?\d/[A-G]',
      );
      for (final f in Directory('content/v1').listSync(recursive: true)) {
        if (f is! File || !f.path.endsWith('.json')) continue;
        final lesson = V1Lesson.fromJson(jsonDecode(f.readAsStringSync()));
        final seq = lesson.practice.sequence;
        if (seq == null) continue;
        // Chord charts (A4) and tuning pairs (A1 only) are not note
        // sequences; the practice loop does not run them yet.
        final steps = lesson.practice.engineSteps;
        if (steps.contains('A4') || steps.every((s) => s == 'A1')) continue;
        if (technique.hasMatch(seq)) continue;
        expect(() => PracticeScore.parse(seq), returnsNormally, reason: f.path);
        // A line the lesson describes as eighths or triplets must carry
        // its durations: bare pitches are quarters, i.e. half the speed.
        final text = [
          lesson.practice.task.en,
          ...lesson.explanation.map((e) => e.en),
        ].join(' ').toLowerCase();
        final pitchOnly = !RegExp(
          r':[whqet]|(?:^|\s)(?:ee|[whqet]\.?r?)(?=\s|$)',
        ).hasMatch(seq);
        expect(
          pitchOnly && RegExp(r'\beighth|\btriplet').hasMatch(text),
          isFalse,
          reason: '${f.path}: eighths/triplets need durations (C4:e, A2:t)',
        );
      }
    });
  });

  test('first-position tab: open strings first, then lowest fret', () {
    expect(guitarTabPosition(40), const GuitarTabPosition(6, 0));
    expect(guitarTabPosition(41), const GuitarTabPosition(6, 1));
    expect(guitarTabPosition(43), const GuitarTabPosition(6, 3));
    expect(guitarTabPosition(45), const GuitarTabPosition(5, 0));
    expect(guitarTabPosition(59), const GuitarTabPosition(2, 0));
    expect(guitarTabPosition(53), const GuitarTabPosition(4, 3));
    expect(guitarTabPosition(76), const GuitarTabPosition(1, 12));
    expect(guitarTabPosition(30), isNull);
    expect(midiName(61), 'C#4');
  });

  group('PracticeTransport', () {
    final score = PracticeScore.parse('E2 F2 G2 F2 | G2 F2 E2 F2');

    test('flow: count-in, each note reported once, then finished', () {
      final t = PracticeTransport(score: score, countInBeats: 4);
      expect(t.advance(2).displayBeat, -2);
      final a = t.advance(4.0);
      expect(a.reached.map((r) => r.event.index), [0]);
      expect(a.reached.single.metronomeBeat, 4);
      final b = t.advance(6.5);
      expect(b.reached.map((r) => r.event.index), [1, 2]);
      expect(b.displayBeat, 2.5);
      final c = t.advance(12.2);
      expect(c.reached.map((r) => r.event.index), [3, 4, 5, 6, 7]);
      expect(c.finished, isTrue);
      expect(t.advance(13).reached, isEmpty);
    });

    test('loop: notes of the range come back with a new pass', () {
      final t = PracticeTransport(
        score: score,
        countInBeats: 4,
        loop: barRange(score, 1, 1),
      );
      final first = t.advance(4.5);
      expect(first.reached.map((r) => r.event.index), [4]);
      expect(first.displayBeat, 4.5);
      final wrap = t.advance(8.2);
      expect(wrap.reached.map((r) => (r.event.index, r.pass)), [
        (5, 0),
        (6, 0),
        (7, 0),
        (4, 1),
      ]);
      expect(wrap.reached.last.metronomeBeat, 8);
      expect(wrap.displayBeat, closeTo(4.2, 1e-9));
      expect(t.finished, isFalse);
    });

    test('wait for me: holds at a note, resumes on a later click', () {
      final t = PracticeTransport(
        score: score,
        countInBeats: 4,
        waitMode: true,
      );
      final a = t.advance(5.3);
      expect(a.reached.map((r) => r.event.index), [0]);
      expect(t.heldEvent, 0);
      expect(t.advance(9).displayBeat, 0);
      expect(t.advance(9).reached, isEmpty);
      t.releaseHeld(9.4);
      // Next note (beat 1) now lands on metronome beat 4 + 6 + 1 = 11.
      expect(t.metronomeBeatFor(1), 11);
      expect(t.advance(9.5).displayBeat, 0);
      final b = t.advance(11);
      expect(b.reached.single.event.index, 1);
      expect(b.reached.single.metronomeBeat, 11);
    });
  });

  test('tempo: 40–120 % of the target, opening by default, ladder', () {
    final t = PracticeTempo(openBpm: 50, targetBpm: 60);
    expect(t.bpm, 50);
    expect(t.percent, 83);
    expect(t.atTarget, isFalse);
    expect(t.withBpm(10).bpm, 24);
    expect(t.withBpm(500).bpm, 72);
    expect(t.stepped(5).stepped(5).atTarget, isTrue);
  });

  test('visual theme: shape + colour + label, no red, CB palette', () {
    const t = PracticeVisualTheme();
    const cb = PracticeVisualTheme(colorBlindSafe: true);
    expect(t.style(PracticeMark.correct).shape, MarkShape.filledCircle);
    expect(t.style(PracticeMark.differentNote).shape, MarkShape.diamond);
    expect(t.style(PracticeMark.couldNotHear).shape, MarkShape.dashedCircle);
    expect(
      cb.style(PracticeMark.correct).color,
      isNot(t.style(PracticeMark.correct).color),
    );
    for (final theme in [t, cb]) {
      for (final m in PracticeMark.values) {
        final c = theme.style(m).color;
        final isRed = c.r > .7 && c.g < .3 && c.b < .3;
        expect(isRed, isFalse, reason: '$m');
      }
    }
  });

  group('PracticeTabStrip', () {
    final score = PracticeScore.parse('E2 F2 G2 F2 E2');

    test('NOW line is fixed; left-handed mirrors the flow', () {
      TabStripPainter painter(bool left, double beat) => TabStripPainter(
        score: score,
        displayBeat: beat,
        marks: const {},
        heldEvent: null,
        loop: null,
        pixelsPerBeat: 100,
        nowFraction: .25,
        guitar: true,
        theme: PracticeVisualTheme(leftHanded: left),
        ink: Colors.black,
        paper: Colors.white,
        muted: Colors.grey,
        now: Colors.blue,
      );
      expect(painter(false, 0).xOf(0, 400), 100);
      expect(painter(false, 0).xOf(1, 400), 200);
      expect(painter(false, 1).xOf(1, 400), 100);
      expect(painter(true, 0).xOf(0, 400), 300);
      expect(painter(true, 0).xOf(1, 400), 200);
      // String 1 on top, string 6 at the bottom (written TAB order).
      final p = painter(false, 0);
      expect(
        p.yOfString(1, const Size(400, 200)),
        lessThan(p.yOfString(6, const Size(400, 200))),
      );
    });

    testWidgets('announces the next note in words', (tester) async {
      await tester.pumpWidget(
        practiceHost(
          locale: 'tr',
          Scaffold(
            body: SizedBox(
              height: 200,
              child: PracticeTabStrip(
                score: score,
                displayBeat: .5,
                marks: const {0: StripMark(PracticeMark.correct)},
              ),
            ),
          ),
        ),
      );
      expect(
        find.bySemanticsLabel(RegExp(r'^Şimdi: .*1\. perde, 6\. tel$')),
        findsOneWidget,
      );
      await tester.pumpWidget(
        practiceHost(
          PracticeVisualThemeScope(
            theme: const PracticeVisualTheme(leftHanded: true),
            child: Scaffold(
              body: SizedBox(
                height: 200,
                child: PracticeTabStrip(
                  score: score,
                  displayBeat: -1,
                  marks: const {
                    0: StripMark(PracticeMark.differentNote, observedMidi: 41),
                  },
                ),
              ),
            ),
          ),
        ),
      );
      expect(
        find.bySemanticsLabel(RegExp(r'^Now: .*fret 1, string 6$')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
