// F2.6b — duyulan drill'ler: soru sesi cevapla tutarlı, "cevabımı çal" sesi
// şıkla aynı kökten, sentez belirlenimli; ekranda Çal / Cevabımı çal.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/audio/practice_audio_lease.dart';
import 'package:ostinato/app/curriculum/v1_lesson.dart';
import 'package:ostinato/app/drill/drill_generator.dart';
import 'package:ostinato/app/drill/drill_screen.dart';
import 'package:ostinato/app/drill/drill_sound.dart';
import 'package:ostinato/app/drill/drill_theory.dart';
import 'package:ostinato/app/practice/loop/reference_listen.dart';

import 'support/fake_practice_audio_port.dart';
import 'support/practice_host.dart';

V1Drill drillOf(String path) => V1Lesson.fromJson(
  jsonDecode(File('content/v1/$path.json').readAsStringSync()),
).practice.drill!;

List<double> pitches(DrillSound s) => [
  for (final n in s.notes)
    if (n.timbre != DrillTimbre.click) n.midi,
];

final class _Port implements ReferencePlaybackPort {
  _Port(this.lease);
  final PracticeAudioLease lease;
  final staged = <int>[];
  @override
  Future<String?> stage(Float32List samples, int sampleRate) async {
    staged.add(samples.length);
    return 'ref-${staged.length}';
  }

  @override
  Future<PracticeAudioTicket?> open(String assetId) async =>
      (await lease.acquire(
        PracticeAudioSide.output,
        context: lease.captureContext(),
        assetId: assetId,
      )).ticket;

  @override
  Future<void> release(PracticeAudioTicket ticket) async {
    await lease.release(ticket);
  }
}

void main() {
  test('every heard ear and guitar drill is supported and consistent', () {
    for (final path in [
      'ear/ear-s1-m01-03',
      'ear/ear-s1-m02-01',
      'ear/ear-s1-m02-02',
      'ear/ear-s1-m02-03',
      'ear/ear-s1-m02-07',
      'ear/ear-s2-m06-01',
      'ear/ear-s2-m06-02',
      'ear/ear-s2-m06-05',
      'ear/ear-s2-m06-07',
      'ear/ear-s2-m08-01',
      'gtr/gtr-s3-m14-09',
    ]) {
      final drill = drillOf(path);
      expect(supportsDrill(drill), isTrue, reason: path);
      for (var seed = 0; seed < 30; seed++) {
        for (final q in generateDrill(drill, seed: seed)) {
          expect(isHeard(q.kind), isTrue);
          expect(q.sound, isNotNull);
          expect(q.options.toSet(), hasLength(q.options.length));
          final p = pitches(q.sound!);
          switch (q.kind) {
            case DrillPromptKind.pitchDirection:
              final d = p[1] - p[0];
              expect(
                q.expected,
                d > 0
                    ? 'higher'
                    : d < 0
                    ? 'lower'
                    : 'same',
              );
              if (q.expected != 'same') {
                expect(d.abs(), greaterThanOrEqualTo(2));
              }
            case DrillPromptKind.pitchContour:
              String w(double d) => d > 0
                  ? 'up'
                  : d < 0
                  ? 'down'
                  : 'same';
              expect(q.expected, '${w(p[1] - p[0])}-${w(p[2] - p[1])}');
            case DrillPromptKind.sameDifferent:
              final cents = ((p[1] - p[0]) * 100).abs().round();
              if (q.expected == 'same') {
                expect(cents, 0);
              } else {
                expect(cents, inInclusiveRange(50, 200));
              }
            case DrillPromptKind.tempoCompare:
              final clicks = [for (final n in q.sound!.notes) n.at];
              final first = clicks[1] - clicks[0];
              final second = clicks[5] - clicks[4];
              final ratio = first / second;
              expect(
                q.expected,
                ratio > 1.02
                    ? 'faster'
                    : ratio < 0.98
                    ? 'slower'
                    : 'same',
              );
            case DrillPromptKind.intervalName:
              final semis = (p[1] - p[0]).abs().round();
              expect(semis, intervalSemitones[q.expected]);
              expect(p[1] > p[0] ? 'ascending' : 'descending', q.values['v0']);
              expect(q.optionSounds, hasLength(q.options.length));
              expect(
                pitches(q.optionSounds![q.answer]!),
                p,
                reason: 'play-the-expected replays the question',
              );
            case DrillPromptKind.chordQuality:
              final root = p.first;
              final steps = {for (final m in p) (m - root).round()};
              expect(steps, switch (q.expected) {
                'major' => {0, 4, 7},
                'minor' => {0, 3, 7},
                _ => {0, 4, 7, 10},
              });
              for (var i = 0; i < q.options.length; i++) {
                expect(pitches(q.optionSounds![i]!).first, root);
              }
            default:
              fail('unexpected kind ${q.kind}');
          }
        }
      }
    }
  });

  test('cadence, melody context and staff display wait for slice (c)', () {
    for (final path in [
      'ear/ear-s2-m06-06',
      'pno/pno-s2-m05-10',
      'pno/pno-s2-m09-02',
    ]) {
      expect(supportsDrill(drillOf(path)), isFalse, reason: path);
    }
  });

  test('rendering is deterministic, bounded and as long as the sound', () {
    final q = generateDrill(drillOf('ear/ear-s2-m08-01'), seed: 5).first;
    final a = renderDrillSound(q.sound!, sampleRate: 44100);
    final b = renderDrillSound(q.sound!, sampleRate: 44100);
    expect(a, b);
    expect(a.length, (q.sound!.seconds * 44100).ceil());
    // Float32 rounding of 0.8 may land a hair above it.
    expect(a.every((v) => v.isFinite && v.abs() <= 0.8 + 1e-6), isTrue);
    expect(a.any((v) => v.abs() > 0.05), isTrue);
    expect(
      () => renderDrillSound(q.sound!, sampleRate: 8000),
      throwsArgumentError,
    );
  });

  testWidgets('screen: Play, then "play my answer" after a different one', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final drill = drillOf('gtr/gtr-s3-m14-09');
    final qs = generateDrill(drill, seed: 3);
    final lease = PracticeAudioLease(port: FakePracticeAudioPort());
    final port = _Port(lease);
    await tester.pumpWidget(
      practiceHost(
        DrillScreen(drill: drill, title: 'Chords', seed: 3, port: (_) => port),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('drill-play-question')), findsOneWidget);
    expect(find.byKey(const Key('drill-play-mine')), findsNothing);
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('drill-play-question')));
      for (var i = 0; i < 100 && port.staged.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    expect(port.staged, hasLength(1));
    final other = (qs[0].answer + 1) % qs[0].options.length;
    await tester.tap(find.byKey(Key('drill-option-$other')));
    await tester.pump();
    expect(find.byKey(const Key('drill-play-mine')), findsOneWidget);
    expect(find.byKey(const Key('drill-play-expected')), findsOneWidget);
    expect(find.text('Play again'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('drill-play-mine')));
      for (var i = 0; i < 100 && port.staged.length < 2; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    expect(port.staged, hasLength(2));
    // Leaving the question stops the sound and releases the output.
    await tester.tap(find.byKey(const Key('drill-next')));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    expect(lease.phase, PracticeAudioLeasePhase.idle);
  });
}
