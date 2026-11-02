// F2.3–F2.5 ekranı: ayarlar, akış, mikrofon şeridi, sonuç ve "oturum bitti"
// olayı; paketlenmiş v1 gitar dersleri.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/audio/audio_capture_channel.dart';
import 'package:ostinato/app/audio/audio_input_controller.dart';
import 'package:ostinato/app/curriculum/v1_lesson.dart';
import 'package:ostinato/app/practice/loop/practice_judge.dart';
import 'package:ostinato/app/practice/loop/practice_loop_screen.dart';
import 'package:ostinato/app/practice/loop/practice_marks.dart';
import 'package:ostinato/app/practice/loop/practice_outcome.dart';
import 'package:ostinato/app/practice/loop/practice_progress_store.dart';
import 'package:ostinato/app/practice/loop/practice_result_screen.dart';
import 'package:ostinato/app/practice/loop/practice_session_controller.dart';
import 'package:ostinato/app/practice/loop/v1_practice_catalog.dart';
import 'package:permission_handler/permission_handler.dart';

import 'support/practice_host.dart';

V1Lesson lesson() => V1Lesson.fromJson(
  jsonDecode(File('content/v1/gtr/gtr-s1-m02-02.json').readAsStringSync()),
);

final class _Memory implements V1PracticeProgress {
  final Map<String, V1PracticeRecord> records = {};
  @override
  Future<Map<String, V1PracticeRecord>> load() async => Map.of(records);
  @override
  Future<V1PracticeRecord> recordRun(
    String id,
    PracticeRunSummary s, {
    DateTime? at,
  }) async => records[id] = (records[id] ?? V1PracticeRecord(lessonId: id))
      .withRun(s, DateTime.utc(2026, 11, 1));
}

void main() {
  setUp(resetAudioCaptureCoordinatorForTest);

  testWidgets('bundled v1 guitar lessons load as the practice catalog', (
    tester,
  ) async {
    final catalog = (await tester.runAsync(V1PracticeCatalog.load))!;
    expect(catalog.orderedIds, contains('gtr-s1-m02-02'));
    expect(catalog.lessons.every(V1PracticeCatalog.isPracticable), isTrue);
  });

  testWidgets('right-to-left: each counter keeps its glyph before the '
      'number, in the same order as other locales', (tester) async {
    tester.view.physicalSize = const Size(420, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      practiceHost(
        Directionality(
          textDirection: TextDirection.rtl,
          child: PracticeLoopScreen(lesson: lesson(), progress: _Memory()),
        ),
      ),
    );
    await tester.pump();
    final keys = [
      for (final m in [
        PracticeMark.correct,
        PracticeMark.differentNote,
        PracticeMark.couldNotHear,
      ])
        Key('practice-count-${m.name}'),
    ];
    final xs = [for (final k in keys) tester.getTopLeft(find.byKey(k)).dx];
    expect(xs, orderedEquals([...xs]..sort()), reason: 'left to right');
    for (final k in keys) {
      expect(
        Directionality.of(tester.element(find.byKey(k))),
        TextDirection.ltr,
      );
      expect(tester.widget<Text>(find.byKey(k)).data, endsWith('0'));
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('settings, flow, mic strip, result and the finished event', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final channel = FakeAudioCaptureChannel();
    final audio = AudioInputController(
      channel: channel,
      requestMicrophonePermission: () async => PermissionStatus.granted,
      pcmDeliveryTimeout: const Duration(minutes: 5),
    );
    var local = 0;
    PracticeSessionController? controller;
    final finished = <PracticeSessionFinished>[];
    final progress = _Memory();
    await tester.pumpWidget(
      practiceHost(
        locale: 'tr',
        PracticeLoopScreen(
          lesson: lesson(),
          progress: progress,
          hasNextLesson: true,
          onSessionFinished: finished.add,
          controllerFactory: (score, tempo, criteria) =>
              controller = PracticeSessionController(
                score: score,
                tempo: tempo,
                audio: audio,
                criteria: criteria,
                localClockUs: () => local,
                // Silence: every note is "couldn't hear" (no attack).
                analyzer: (r) async => judgeNote(r),
              ),
        ),
      ),
    );
    expect(find.text('Tempo ♩=50 · hedef 60 temposunun %83'), findsOneWidget);
    expect(find.text('Beni bekle: Kapalı'), findsOneWidget);
    expect(find.text('Mikrofon kapalı'), findsOneWidget);
    await tester.tap(find.byKey(const Key('practice-tempo-up')));
    await tester.pump();
    expect(find.text('♩=55/60'), findsOneWidget);
    await tester.tap(find.byKey(const Key('practice-tempo-up')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('practice-loop')));
    await tester.pump();
    expect(find.text('Döngü: 1–2. ölçüler'), findsOneWidget);
    await tester.tap(find.byKey(const Key('practice-loop')));
    await tester.pump();

    await tester.tap(find.byKey(const Key('practice-start')));
    await tester.pump();
    final c = controller!;
    // Feed 100 ms chunks of quiet room noise on the capture clock.
    final rng = math.Random(1);
    var t = 0;
    Future<void> feed(int chunks) async {
      for (var i = 0; i < chunks; i++) {
        final x = Float64List(4800);
        for (var k = 0; k < x.length; k++) {
          x[k] = (rng.nextDouble() * 2 - 1) * .002;
        }
        channel.pushChunk(x, sampleRate: 48000, tNativeUs: t);
        t += 100000;
        local = t;
        await tester.pump();
        if (channel.metronome != null && c.timeline == null) {
          channel.pushMetronomeAnchor(t + 200000);
          await tester.pump();
        }
        c.tick();
        await tester.pump();
        if (c.phase == PracticePhase.finished) return;
      }
    }

    await feed(20);
    expect(c.phase, PracticePhase.running);
    expect(find.byKey(const Key('practice-stop')), findsOneWidget);
    expect(find.text('Sessiz — çalmaya başlayınca dinliyorum'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^Şimdi: ')), findsOneWidget);
    await feed(250);
    await tester.pumpAndSettle();
    expect(c.phase, PracticePhase.finished);
    expect(c.countOf(PracticeMark.couldNotHear), 10);
    // Result screen with the setup-first message, and progress recorded.
    expect(find.byType(PracticeResultScreen), findsOneWidget);
    expect(find.text('Kurulumu kontrol et'), findsOneWidget);
    expect(progress.records['gtr-s1-m02-02']!.runs, 1);
    expect(finished.single.lessonId, 'gtr-s1-m02-02');
    expect(finished.single.course, 'guitar');
    expect(finished.single.heardEvents, 0);
    expect(finished.single.activeDuration.inSeconds, greaterThan(10));
    await tester.tap(find.byKey(const Key('result-retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('practice-start')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(audio.dispose);
  });
}
