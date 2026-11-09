// OST-P0-06 — dinle → dene → düzelt → tekrar: sonuç ekranı ve pratik akışı.
// Bayrak AÇIK: tek düzeltme kartı + tekrar kademesi; düşük güven "ölçemedim"
// (hüküm yok); bayrak KAPALI: kart yok. Ağ yok (HttpOverrides).
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/audio/audio_capture_channel.dart';
import 'package:ostinato/app/audio/audio_input_controller.dart';
import 'package:ostinato/app/curriculum/v1_lesson.dart';
import 'package:ostinato/app/practice/loop/listen_try_fix.dart';
import 'package:ostinato/app/practice/loop/practice_judge.dart';
import 'package:ostinato/app/practice/loop/practice_loop_screen.dart';
import 'package:ostinato/app/practice/loop/practice_marks.dart';
import 'package:ostinato/app/practice/loop/practice_outcome.dart';
import 'package:ostinato/app/practice/loop/practice_progress_store.dart';
import 'package:ostinato/app/practice/loop/practice_result_screen.dart';
import 'package:ostinato/app/practice/loop/practice_score.dart';
import 'package:ostinato/app/practice/loop/practice_session_controller.dart';
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
      .withRun(s, DateTime.utc(2026, 11, 8));
}

final class _NoNet extends HttpOverrides {
  int clients = 0;
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    clients++;
    throw StateError('EGRESS: HttpClient opened');
  }
}

final banned = RegExp(
  r'wrong|incorrect|mistake|error|fail|yanlış|hata|başarısız',
  caseSensitive: false,
);

final score = PracticeScore.parse('E2 F2 G2 F2 | E2 F2 G2 F2');

PracticeRunSummary pitchSummary(List<PracticeMark> marks) =>
    PracticeRunSummary.of(
      score: score,
      outcomes: [
        for (var i = 0; i < marks.length; i++)
          NoteOutcome(
            eventIndex: i,
            bar: score.events[i].bar,
            pass: 0,
            mark: marks[i],
            reason: marks[i] == PracticeMark.couldNotHear
                ? HearingReason.unclear
                : null,
            expectedMidi: score.events[i].midi,
            observedMidi: marks[i] == PracticeMark.differentNote ? 45 : null,
          ),
      ],
      bpm: 60,
      openBpm: 50,
      targetBpm: 60,
      completed: true,
      loopUsed: false,
      waitUsed: false,
    );

const c = PracticeMark.correct, d = PracticeMark.differentNote;
const u = PracticeMark.couldNotHear;

/// Pushes the result screen and records what it pops.
Future<void> pumpResult(
  WidgetTester tester,
  PracticeRunSummary s, {
  ListenTryFixResult? fix,
  String locale = 'en',
  Size size = const Size(420, 1800),
  void Function(Object?)? onPop,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    practiceHost(
      locale: locale,
      Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            final r = await Navigator.of(context).push<ResultAction>(
              MaterialPageRoute(
                builder: (_) => PracticeResultScreen(
                  lesson: lesson(),
                  score: score,
                  summary: s,
                  fix: fix,
                ),
              ),
            );
            onPop?.call(r);
          },
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

ListenTryFixResult fixFor(PracticeRunSummary s) =>
    ListenTryFix.of(s, lesson: lesson(), freeTempo: false, pool: const []);

void main() {
  setUp(resetAudioCaptureCoordinatorForTest);

  group('sonuç ekranı', () {
    testWidgets('bayrak AÇIK: tek düzeltme kartı + adımlar + tekrar', (
      tester,
    ) async {
      final s = pitchSummary([c, d, c, c, c, d, c, c]);
      Object? popped;
      await pumpResult(tester, s, fix: fixFor(s), onPop: (r) => popped = r);
      expect(find.byKey(const Key('listen-try-fix-card')), findsOneWidget);
      expect(find.text('One thing to work on'), findsOneWidget);
      expect(
        find.textContaining('Some notes sounded different from the written'),
        findsOneWidget,
      );
      expect(find.textContaining('(bar 1)'), findsOneWidget);
      // Bir seferde tek düzeltme metni.
      expect(find.byKey(const Key('listen-try-fix-body')), findsOneWidget);
      expect(
        find.byKey(const Key('listen-try-fix-steps')),
        findsOneWidget,
        reason: 'kademeli tempo görünür',
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('listen-try-fix-steps'))).data,
        contains('♩=45 → ♩=60'),
      );
      // Anlamsal etiket: başlık + canlı bölge.
      expect(find.bySemanticsLabel('One thing to work on'), findsWidgets);
      await tester.ensureVisible(
        find.byKey(const Key('listen-try-fix-repeat')),
      );
      expect(find.text('Try again at ♩=45'), findsOneWidget);
      await tester.tap(find.byKey(const Key('listen-try-fix-repeat')));
      await tester.pumpAndSettle();
      expect(popped, isA<ResultActionRepeat>());
      final a = popped! as ResultActionRepeat;
      expect((a.bpm, a.first, a.last), (45, 0, 1));
    });

    testWidgets('düşük güven: "ölçemedim", hüküm ve düzeltme yok', (
      tester,
    ) async {
      final s = pitchSummary([c, d, u, u, u, u, c, c]);
      final fix = fixFor(s);
      expect(fix, isA<FixUnmeasured>());
      await pumpResult(tester, s, fix: fix);
      expect(
        find.text(
          "I couldn't tell this sound apart with confidence; will you try again?",
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('listen-try-fix-repeat')), findsNothing);
      expect(find.byKey(const Key('listen-try-fix-steps')), findsNothing);
      final card = find.byKey(const Key('listen-try-fix-card'));
      final texts = tester
          .widgetList<Text>(
            find.descendant(of: card, matching: find.byType(Text)),
          )
          .map((t) => t.data ?? '')
          .join(' | ');
      expect(banned.hasMatch(texts), isFalse, reason: texts);
    });

    testWidgets('TR: ölçemedim metni ve yargılayıcı kelime yok', (
      tester,
    ) async {
      final s = pitchSummary([u, u, u, u, u, u, u, u]);
      await pumpResult(tester, s, fix: fixFor(s), locale: 'tr');
      expect(
        find.text('Bu sesi güvenle ayırt edemedim; tekrar dener misin?'),
        findsOneWidget,
      );
      final card = find.byKey(const Key('listen-try-fix-card'));
      final texts = tester
          .widgetList<Text>(
            find.descendant(of: card, matching: find.byType(Text)),
          )
          .map((t) => t.data ?? '')
          .join(' | ');
      expect(banned.hasMatch(texts), isFalse, reason: texts);
    });

    testWidgets('net fark yok: olumlu, hüküm yok', (tester) async {
      final s = pitchSummary(List.filled(8, c));
      await pumpResult(tester, s, fix: fixFor(s));
      expect(find.textContaining('matched the line well'), findsOneWidget);
      expect(find.byKey(const Key('listen-try-fix-repeat')), findsNothing);
    });

    testWidgets(
      'eşik altı, baskın tür yok: net fark yok, hızlanma önerisi yok',
      (tester) async {
        // 10 nota: 6 doğru, 2 farklı, 2 duyulmadı → doğruluk %75 < %80 ve
        // farklı notalar payı %20 < %25 → baskın tür yok.
        final s10 = PracticeScore.parse('E2 F2 G2 F2 | E2 F2 G2 F2 | E2 F2');
        final marks = [c, c, c, c, c, c, d, d, u, u];
        final s = PracticeRunSummary.of(
          score: s10,
          outcomes: [
            for (var i = 0; i < 10; i++)
              NoteOutcome(
                eventIndex: i,
                bar: s10.events[i].bar,
                pass: 0,
                mark: marks[i],
                reason: marks[i] == u ? HearingReason.unclear : null,
                expectedMidi: s10.events[i].midi,
                observedMidi: marks[i] == d ? 45 : null,
              ),
          ],
          bpm: 60,
          openBpm: 50,
          targetBpm: 60,
          completed: true,
          loopUsed: false,
          waitUsed: false,
        );
        final fix = fixFor(s);
        expect(fix, isA<FixNoClearDifference>());
        await pumpResult(tester, s, fix: fix);
        expect(
          find.text(
            "I didn't measure a clear difference; will you try once more?",
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const Key('listen-try-fix-card')),
            matching: find.textContaining('faster'),
          ),
          findsNothing,
        );
        expect(find.byKey(const Key('listen-try-fix-repeat')), findsNothing);
      },
    );

    testWidgets('dar ekran (320 px) taşma yok', (tester) async {
      final s = pitchSummary([c, d, c, c, c, d, c, c]);
      await pumpResult(
        tester,
        s,
        fix: fixFor(s),
        size: const Size(320, 1800),
        locale: 'tr',
      );
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('listen-try-fix-card')), findsOneWidget);
    });

    testWidgets('bayrak KAPALI (fix: null): kart yok, ekran aynı', (
      tester,
    ) async {
      final s = pitchSummary([c, d, c, c, c, d, c, c]);
      await pumpResult(tester, s);
      expect(find.byKey(const Key('listen-try-fix-card')), findsNothing);
      expect(find.byKey(const Key('result-retry')), findsOneWidget);
      expect(find.byKey(const Key('result-accuracy')), findsOneWidget);
    });
  });

  group('pratik akışı (bayrak)', () {
    Future<void> runPractice(
      WidgetTester tester, {
      required bool flag,
      required Future<NoteJudgement> Function(NoteJudgeRequest) analyzer,
      required void Function(PracticeSessionController) onController,
      required AudioInputController audio,
      required FakeAudioCaptureChannel channel,
    }) async {
      var local = 0;
      PracticeSessionController? controller;
      await tester.pumpWidget(
        practiceHost(
          PracticeLoopScreen(
            lesson: lesson(),
            progress: _Memory(),
            seed: 1,
            listenTryFixRepeat: flag,
            controllerFactory: (score, tempo, criteria) =>
                controller = PracticeSessionController(
                  score: score,
                  tempo: tempo,
                  audio: audio,
                  criteria: criteria,
                  localClockUs: () => local,
                  analyzer: analyzer,
                ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('practice-start')));
      await tester.pump();
      final c = controller!;
      onController(c);
      final rng = math.Random(1);
      var t = 0;
      for (var i = 0; i < 300; i++) {
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
        if (c.phase == PracticePhase.finished) break;
      }
      await tester.pumpAndSettle();
      expect(c.phase, PracticePhase.finished);
    }

    AudioInputController newAudio(FakeAudioCaptureChannel channel) =>
        AudioInputController(
          channel: channel,
          requestMicrophonePermission: () async => PermissionStatus.granted,
          pcmDeliveryTimeout: const Duration(minutes: 5),
        );

    testWidgets('bayrak AÇIK + sessiz oda: "ölçemedim", ağ 0', (tester) async {
      tester.view.physicalSize = const Size(420, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final net = _NoNet();
      final channel = FakeAudioCaptureChannel();
      final audio = newAudio(channel);
      final previous = HttpOverrides.current;
      HttpOverrides.global = net;
      addTearDown(() => HttpOverrides.global = previous);
      {
        await runPractice(
          tester,
          flag: true,
          analyzer: (r) async => judgeNote(r),
          onController: (_) {},
          audio: audio,
          channel: channel,
        );
        expect(find.byType(PracticeResultScreen), findsOneWidget);
        expect(find.byKey(const Key('listen-try-fix-card')), findsOneWidget);
        expect(
          find.textContaining("couldn't tell this sound apart"),
          findsOneWidget,
        );
        expect(find.byKey(const Key('listen-try-fix-repeat')), findsNothing);
      }
      expect(net.clients, 0);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(audio.dispose);
    });

    testWidgets('bayrak KAPALI + aynı koşu: kart yok (bugünkü ekran)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(420, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final channel = FakeAudioCaptureChannel();
      final audio = newAudio(channel);
      await runPractice(
        tester,
        flag: false,
        analyzer: (r) async => judgeNote(r),
        onController: (_) {},
        audio: audio,
        channel: channel,
      );
      expect(find.byType(PracticeResultScreen), findsOneWidget);
      expect(find.byKey(const Key('listen-try-fix-card')), findsNothing);
      expect(find.byKey(const Key('result-accuracy')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(audio.dispose);
    });

    testWidgets(
      'bayrak AÇIK: dinle → dene → tek düzeltme → tekrar kademesi (45 BPM, döngü)',
      (tester) async {
        tester.view.physicalSize = const Size(420, 1800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final channel = FakeAudioCaptureChannel();
        final audio = newAudio(channel);
        PracticeSessionController? ctl;
        await runPractice(
          tester,
          flag: true,
          // Her notada bir atak var ve perde farklı duyulur.
          analyzer: (r) async => NoteJudgement(
            PracticeMark.differentNote,
            attackIndex: r.expectedIndex,
            observedMidi: 45,
          ),
          onController: (c) => ctl = c,
          audio: audio,
          channel: channel,
        );
        expect(find.byKey(const Key('listen-try-fix-card')), findsOneWidget);
        expect(
          find.textContaining('Some notes sounded different from the written'),
          findsOneWidget,
        );
        expect(find.byKey(const Key('listen-try-fix-steps')), findsOneWidget);
        final tempoBefore = ctl!.tempo.bpm;
        await tester.ensureVisible(
          find.byKey(const Key('listen-try-fix-repeat')),
        );
        await tester.tap(find.byKey(const Key('listen-try-fix-repeat')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('practice-start')), findsOneWidget);
        expect(ctl!.tempo.bpm, lessThan(tempoBefore));
        expect(ctl!.tempo.bpm, (tempoBefore * .75).round());
        expect(ctl!.loopBars, isNotNull);
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(audio.dispose);
      },
    );
  });
}
