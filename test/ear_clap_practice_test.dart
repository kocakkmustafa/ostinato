// Kulak kursu alkış dersleri: yazılı ritim satırı olan A3 dersleri ölçülü
// pratik ekranında açılır; şarkı ve üretilen satırlı dersler açılmaz;
// gitar akort kartı görünmez.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/audio/audio_capture_channel.dart';
import 'package:ostinato/app/audio/audio_input_controller.dart';
import 'package:ostinato/app/curriculum/v1_lesson.dart';
import 'package:ostinato/app/practice/loop/practice_judge.dart';
import 'package:ostinato/app/practice/loop/practice_loop_screen.dart';
import 'package:ostinato/app/practice/loop/practice_outcome.dart';
import 'package:ostinato/app/practice/loop/practice_progress_store.dart';
import 'package:ostinato/app/practice/loop/practice_session_controller.dart';
import 'package:ostinato/app/practice/loop/v1_practice_catalog.dart';
import 'package:ostinato/app/tuner/session_tuning_gate.dart';
import 'package:permission_handler/permission_handler.dart';

import 'support/practice_host.dart';

V1Lesson ear(String id) => V1Lesson.fromJson(
  jsonDecode(File('content/v1/ear/$id.json').readAsStringSync()),
);

final class _Memory implements V1PracticeProgress {
  @override
  Future<Map<String, V1PracticeRecord>> load() async => {};
  @override
  Future<V1PracticeRecord> recordRun(
    String id,
    PracticeRunSummary s, {
    DateTime? at,
  }) async => V1PracticeRecord(lessonId: id).withRun(s, DateTime.utc(2026));
}

void main() {
  test('written clapping lines in the ear course are practicable', () {
    final practicable = <String>{};
    for (final f in Directory('content/v1/ear').listSync()) {
      if (f is! File || !f.path.endsWith('.json')) continue;
      final l = V1Lesson.fromJson(jsonDecode(f.readAsStringSync()));
      if (V1PracticeCatalog.isPracticable(l)) {
        practicable.add(l.id);
        final score = V1PracticeCatalog.scoreOf(l)!;
        expect(score.isRhythmOnly, isTrue, reason: l.id);
        expect(l.practice.engineSteps, ['A3'], reason: l.id);
      }
    }
    expect(practicable, {
      'ear-s1-m01-01', // 16 pulse beats
      'ear-s1-m01-02', // 8 pulse beats, tempo ladder 60→100
      'ear-s1-m01-04',
      'ear-s1-m01-05',
      'ear-s1-m03-01',
      'ear-s1-m03-02',
      'ear-s1-m03-03',
      'ear-s1-m03-04',
      'ear-s1-m03-05', // 3/4
      // Generated per attempt from a module-derived clap block.
      'ear-s1-m01-06',
      'ear-s1-m03-06',
      'ear-s2-m07-03',
      'ear-s2-m07-04',
      'ear-s2-m07-05',
    });
    // Singing (A5) and lines generated per attempt stay out.
    for (final id in ['ear-s1-m02-04', 'ear-s2-m05-02', 'ear-s1-test']) {
      expect(V1PracticeCatalog.isPracticable(ear(id)), isFalse, reason: id);
    }
  });

  test('pulse lines count the beats the task names', () {
    expect(
      V1PracticeCatalog.scoreOf(ear('ear-s1-m01-01'))!.events,
      hasLength(16),
    );
    expect(
      V1PracticeCatalog.scoreOf(ear('ear-s1-m01-02'))!.events,
      hasLength(8),
    );
    expect(V1PracticeCatalog.scoreOf(ear('ear-s1-m03-05'))!.beatsPerBar, 3);
  });

  test('clap blocks: new lines per seed, only the block\'s values', () {
    const tokens = {
      'whole': 'w',
      'half': 'h',
      'dottedQuarter': 'q.',
      'quarter': 'q',
      'eighthPair': 'ee',
      'eighth': 'e',
      'quarterRest': 'qr',
      'halfRest': 'hr',
    };
    for (final id in [
      'ear-s1-m01-06',
      'ear-s1-m03-06',
      'ear-s2-m07-03',
      'ear-s2-m07-04',
      'ear-s2-m07-05',
    ]) {
      final l = ear(id);
      final clap = l.practice.clap!;
      expect(
        clap.derivedFrom,
        startsWith('Modülden türetildi, kaynak satırlar:'),
      );
      expect(clap.tempo.open, 60, reason: id);
      final allowed = {for (final v in clap.values) tokens[v]!};
      // A tied pair is written `e e~` so the tie sits on one eighth.
      if (clap.ties && clap.values.contains('eighthPair')) allowed.add('e');
      final seen = <String>{};
      var tied = 0;
      for (var seed = 0; seed < 25; seed++) {
        final seq = V1PracticeCatalog.clapSequence(l, seed: seed)!;
        seen.add(seq);
        expect(seq, V1PracticeCatalog.clapSequence(l, seed: seed));
        final score = V1PracticeCatalog.scoreOf(l, seed: seed)!;
        expect(score.isRhythmOnly, isTrue, reason: seq);
        expect(score.totalBeats, clap.bars * clap.lines * 4, reason: seq);
        final body = seq.substring('4/4: '.length);
        for (final t in body.split(RegExp(r'[\s|]+'))) {
          if (t.isEmpty) continue;
          if (t.endsWith('~')) tied++;
          expect(allowed, contains(t.replaceAll('~', '')), reason: '$id $t');
        }
      }
      expect(seen.length, greaterThan(15), reason: '$id draws new lines');
      if (clap.ties) {
        expect(tied, greaterThanOrEqualTo(25 * clap.lines), reason: id);
      } else {
        expect(tied, 0, reason: id);
      }
    }
  });

  testWidgets('an ear clapping lesson opens without the guitar tuning card', (
    tester,
  ) async {
    final audio = AudioInputController(
      channel: FakeAudioCaptureChannel(),
      requestMicrophonePermission: () async => PermissionStatus.granted,
    );
    PassCriteria? criteria;
    await tester.pumpWidget(
      practiceHost(
        PracticeLoopScreen(
          lesson: ear('ear-s1-m03-01'),
          progress: _Memory(),
          controllerFactory: (score, tempo, c) {
            criteria = c;
            return PracticeSessionController(
              score: score,
              tempo: tempo,
              audio: audio,
              criteria: c,
              analyzer: (r) async => judgeNote(r),
            );
          },
        ),
      ),
    );
    await tester.pump();
    expect(criteria!.rhythm, isTrue);
    expect(find.byType(SessionTuningGateCard), findsNothing);
    expect(find.byKey(const Key('practice-start')), findsOneWidget);
    await audio.dispose();
  });
}
