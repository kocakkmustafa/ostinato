// FK1 — referans pasajı: belirlenimli sentez, süre, tavan ve kesme.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/curriculum/v1_lesson.dart';
import 'package:ostinato/app/practice/loop/practice_score.dart';
import 'package:ostinato/app/practice/loop/reference_passage.dart';
import 'package:ostinato/app/practice/loop/v1_practice_catalog.dart';

double rms(List<double> x, int from, int to) {
  var s = 0.0;
  for (var i = from; i < to; i++) {
    s += x[i] * x[i];
  }
  return math.sqrt(s / (to - from));
}

V1Lesson lesson(String id) => V1Lesson.fromJson(
  jsonDecode(File('content/v1/gtr/$id.json').readAsStringSync()),
);

void main() {
  const rate = 44100;
  final line = PracticeScore.parse('E2 G2 A2 C3 | E2:h A2:h');

  test('deterministic, bounded, and as long as count-in + line + tail', () {
    final a = renderReferencePassage(line, bpm: 60, sampleRate: rate);
    final b = renderReferencePassage(line, bpm: 60, sampleRate: rate);
    expect(a.samples, b.samples);
    expect(a.barsPlayed, 2);
    expect(a.truncated, false);
    // 4 count-in beats + 8 line beats at 1 s, then 1.2 s of tail.
    expect(a.samples.length, (13.2 * rate).ceil());
    expect(a.samples.every((v) => v.isFinite && v.abs() <= 0.8), true);
  });

  test('the first note sounds after the count-in, not before', () {
    final p = renderReferencePassage(
      line,
      bpm: 60,
      sampleRate: rate,
      click: false,
    );
    final x = p.samples;
    // Count-in: clicks only (short bursts); the note starts at 4 s.
    final before = rms(x, (3.5 * rate).round(), (3.95 * rate).round());
    final after = rms(x, (4.02 * rate).round(), (4.5 * rate).round());
    expect(after, greaterThan(10 * before));
  });

  test('click: false leaves the line without clicks after the count-in', () {
    final plain = renderReferencePassage(
      line,
      bpm: 60,
      sampleRate: rate,
      click: false,
    );
    final clicked = renderReferencePassage(line, bpm: 60, sampleRate: rate);
    // Same length; the clicked rendering differs only after the count-in.
    expect(plain.samples.length, clicked.samples.length);
    final head = (3.9 * rate).round();
    expect(plain.samples.sublist(0, head), clicked.samples.sublist(0, head));
    expect(plain.samples, isNot(clicked.samples));
  });

  test('a long line is cut at a bar line and says so', () {
    final long = PracticeScore.parse(
      List.filled(20, 'E2 G2 A2 C3').join(' | '),
    );
    final p = renderReferencePassage(long, bpm: 40, sampleRate: rate);
    expect(p.truncated, true);
    expect(p.barCount, 20);
    // 40 s budget: 1.2 s tail + 4 count-in beats at 1.5 s → 5 bars.
    expect(p.barsPlayed, 5);
    expect(
      p.duration.inMilliseconds,
      lessThanOrEqualTo(kMaxReferenceSeconds * 1000),
    );
  });

  test('a rhythm-only line is tapped', () {
    final r = PracticeScore.parse('q q ee q | h h');
    final p = renderReferencePassage(
      r,
      bpm: 80,
      sampleRate: 48000,
      click: false,
    );
    expect(p.barsPlayed, 2);
    final beat = 48000 * 60 / 80;
    final at = (4 * beat).round();
    expect(rms(p.samples, at, at + 2400), greaterThan(0.01));
  });

  test('invalid rate, tempo or an empty line is refused', () {
    expect(
      () => renderReferencePassage(line, bpm: 60, sampleRate: 22050),
      throwsArgumentError,
    );
    expect(
      () => renderReferencePassage(line, bpm: 10, sampleRate: rate),
      throwsArgumentError,
    );
    // A degree run has no fixed pitch until a key is chosen: nothing to sound.
    expect(
      () => renderReferencePassage(
        PracticeScore.parse('1-2-3-2-1'),
        bpm: 60,
        sampleRate: rate,
      ),
      throwsArgumentError,
    );
  });

  test('course lines render at their open tempo within the cap', () {
    for (final id in ['gtr-s1-m02-01', 'gtr-s1-m03-01', 'gtr-s1-test']) {
      final l = lesson(id);
      if (!V1PracticeCatalog.isPracticable(l)) continue;
      final score = V1PracticeCatalog.scoreOf(l)!;
      final p = renderReferencePassage(
        score,
        bpm: l.practice.tempo?.open ?? 60,
        sampleRate: rate,
      );
      expect(p.barsPlayed, greaterThan(0), reason: id);
      expect(
        p.duration.inSeconds,
        lessThanOrEqualTo(kMaxReferenceSeconds),
        reason: id,
      );
    }
  });
}
