// OST-P0-07 — Hayalet Ekran: rehberler ölçülü, tekrarlı başarıyla kademeli
// azalır; güvenilmez ölçümde ilerleme ve "yetkinlik" iddiası yoktur; kullanıcı
// her an geri açabilir; başla/durdur hiç gizlenmez. Bayrak KAPALI = eski ekran.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/app_message_ids.dart';
import 'package:ostinato/app/audio/audio_capture_channel.dart';
import 'package:ostinato/app/audio/audio_input_controller.dart';
import 'package:ostinato/app/curriculum/v1_lesson.dart';
import 'package:ostinato/app/ostinato_release_policy.dart';
import 'package:ostinato/app/practice/loop/ghost_screen.dart';
import 'package:ostinato/app/practice/loop/ghost_screen_copy.dart';
import 'package:ostinato/app/practice/loop/listen_try_fix.dart';
import 'package:ostinato/app/practice/loop/metronome_beat_view.dart';
import 'package:ostinato/app/practice/loop/practice_judge.dart';
import 'package:ostinato/app/practice/loop/practice_loop_screen.dart';
import 'package:ostinato/app/practice/loop/practice_marks.dart';
import 'package:ostinato/app/practice/loop/practice_outcome.dart';
import 'package:ostinato/app/practice/loop/practice_progress_store.dart';
import 'package:ostinato/app/practice/loop/practice_score.dart';
import 'package:ostinato/app/practice/loop/practice_session_controller.dart';
import 'package:ostinato/app/practice/loop/practice_result_screen.dart';
import 'package:ostinato/app/practice/loop/practice_tab_strip.dart';
import 'package:ostinato/app/practice/loop/reference_listen_bar.dart';
import 'package:permission_handler/permission_handler.dart';

import 'support/practice_host.dart';

V1Lesson lesson() => V1Lesson.fromJson(
  jsonDecode(File('content/v1/gtr/gtr-s1-m02-02.json').readAsStringSync()),
);

final banned = RegExp(
  r'wrong|incorrect|mistake|error|fail|yanlış|hata|başarısız|mastered|ustalaş',
  caseSensitive: false,
);

const A = GhostAttempt.clear,
    N = GhostAttempt.notClear,
    U = GhostAttempt.unmeasured;

GhostState run(GhostState s, List<GhostAttempt> attempts) {
  for (final a in attempts) {
    s = GhostScreenPolicy.afterAttempt(s, a);
  }
  return s;
}

void main() {
  setUp(resetAudioCaptureCoordinatorForTest);

  group('politika (saf)', () {
    test('bayrak varsayılan KAPALI', () {
      expect(ostinatoGhostScreenOpen, isFalse);
    });

    test('rehber kümeleri kademeli azalır, öğrenmede hepsi açık', () {
      expect(
        GhostScreenPolicy.guidesFor(GhostStage.learn),
        Set.of(Guide.values),
      );
      final sizes = [
        for (final s in GhostStage.values)
          GhostScreenPolicy.guidesFor(s).length,
      ];
      expect(sizes, [3, 2, 1, 0]);
      for (var i = 1; i < GhostStage.values.length; i++) {
        expect(
          GhostScreenPolicy.guidesFor(GhostStage.values[i]),
          isNot(contains(Guide.referenceAudio)),
          reason: 'referans ses ilk gizlenen',
        );
      }
    });

    test('tekrarlı ölçülü başarı aşamayı ilerletir; tek başarı yetmez', () {
      var s = run(const GhostState(), [A]);
      expect(s.stage, GhostStage.learn);
      s = run(s, [A]);
      expect(s.stage, GhostStage.reinforce);
      s = run(s, [A, A, A, A]);
      expect(s.stage, GhostStage.independent);
    });

    test('ölçülemeyen koşu ASLA ilerletmez, seri bozmaz, iddia üretmez', () {
      var s = run(const GhostState(), [A, A, A, A]); // recall
      expect(s.stage, GhostStage.recall);
      final before = s;
      s = run(s, List.filled(20, U));
      expect(s.stage, before.stage);
      expect(s.clearStreak, before.clearStreak);
      expect(s.independentClearRuns, 0);
      expect(s.completion, isNull);
    });

    test(
      'bağımsızda ölçülemeyen koşu: tamamlama "ölçülemedi", sayaç artmaz',
      () {
        var s = run(const GhostState(), [A, A, A, A, A, A]);
        expect(s.stage, GhostStage.independent);
        s = run(s, [U]);
        expect(s.completion, GhostCompletion.unmeasured);
        expect(s.independentClearRuns, 0);
        expect(s.stage, GhostStage.independent);
      },
    );

    test('rehbersiz ölçülü başarı yalnız oturum sayacına yazılır', () {
      var s = run(const GhostState(), [A, A, A, A, A, A, A]);
      expect(s.stage, GhostStage.independent);
      expect(s.completion, GhostCompletion.measuredClear);
      expect(s.independentClearRuns, 1);
    });

    test('ardışık başarısızlıkta geri adım; öğrenmede kilit yok', () {
      var s = run(const GhostState(), [A, A, A, A]); // recall
      s = run(s, [N, N]);
      expect(s.stage, GhostStage.recall);
      s = run(s, [N]);
      expect(s.stage, GhostStage.reinforce);
      var l = run(const GhostState(), List.filled(10, N));
      expect(l.stage, GhostStage.learn);
      expect(GhostScreenPolicy.visible(l), Set.of(Guide.values));
      // Ölçülemeyen koşu geri adım serisini de bozmaz/ilerletmez.
      l = run(const GhostState(stage: GhostStage.recall), [N, U, N, U, N]);
      expect(l.stage, GhostStage.reinforce);
    });

    test('kullanıcı geri adımı ve override her an; ceza yok', () {
      var s = run(const GhostState(), [A, A, A, A, A, A]);
      s = GhostScreenPolicy.stepBack(s);
      expect(s.stage, GhostStage.recall);
      s = GhostScreenPolicy.stepBack(GhostScreenPolicy.stepBack(s));
      s = GhostScreenPolicy.stepBack(s);
      expect(s.stage, GhostStage.learn);
      var r = run(const GhostState(), [A, A, A, A]);
      r = GhostScreenPolicy.setShowAll(r, true);
      expect(GhostScreenPolicy.visible(r), Set.of(Guide.values));
      final during = run(r, [A, A, A, N, N, N, N]);
      expect(during.stage, r.stage, reason: 'override: ne ilerleme ne ceza');
      expect(during.clearStreak, r.clearStreak);
      expect(during.independentClearRuns, 0);
      r = GhostScreenPolicy.setShowAll(during, false);
      expect(
        GhostScreenPolicy.visible(r),
        GhostScreenPolicy.guidesFor(r.stage),
      );
    });

    test(
      'classify: yalnız FixClear başarıdır, FixUnmeasured güvenilmezdir',
      () {
        expect(GhostScreenPolicy.classify(const FixClear()), A);
        expect(GhostScreenPolicy.classify(const FixNoClearDifference()), N);
        expect(
          GhostScreenPolicy.classify(
            const FixUnmeasured(CouldNotMeasure.weakSignal),
          ),
          U,
        );
        expect(
          GhostScreenPolicy.classify(
            const FixUnmeasured(CouldNotMeasure.tooFewNotes),
          ),
          U,
        );
      },
    );

    PracticeRunSummary summaryOf({
      bool completed = true,
      bool loopUsed = false,
      bool waitUsed = false,
      int notes = 8,
    }) {
      final sc = PracticeScore.parse('E2 F2 G2 F2 | E2 F2 G2 F2');
      return PracticeRunSummary.of(
        score: sc,
        outcomes: [
          for (var i = 0; i < notes; i++)
            NoteOutcome(
              eventIndex: i,
              bar: sc.events[i].bar,
              pass: 0,
              mark: PracticeMark.correct,
              expectedMidi: sc.events[i].midi,
            ),
        ],
        bpm: 60,
        openBpm: 50,
        targetBpm: 60,
        completed: completed,
        loopUsed: loopUsed,
        waitUsed: waitUsed,
      );
    }

    GhostAttempt attemptOf(PracticeRunSummary s) =>
        GhostScreenPolicy.classifyRun(
          s,
          ListenTryFix.of(s, lesson: lesson(), freeTempo: false),
        );

    test(
      'tam koşu başarı sayılır; durdurulmuş/döngü/bekle koşusu sayılmaz',
      () {
        expect(attemptOf(summaryOf()), A);
        // Kısmi koşu: doğruluk 1,0 ama "completed:false" → FixClear olsa da
        // ölçülmemiş koşu.
        final partial = summaryOf(completed: false, notes: 4);
        expect(partial.accuracy, 1.0);
        expect(
          ListenTryFix.of(partial, lesson: lesson(), freeTempo: false),
          isA<FixClear>(),
        );
        expect(attemptOf(partial), U);
        expect(attemptOf(summaryOf(completed: false)), U);
        expect(attemptOf(summaryOf(loopUsed: true)), U);
        expect(attemptOf(summaryOf(waitUsed: true)), U);
        // İki kısmi koşu aşamayı ilerletmez ve "tamamlandı" iddiası üretmez.
        final s = run(const GhostState(), [
          attemptOf(partial),
          attemptOf(partial),
        ]);
        expect(s.stage, GhostStage.learn);
        expect(s.clearStreak, 0);
      },
    );

    test('metinler 14 dil tablosunda; suçlayıcı/yetkinlik dili yok', () {
      for (final c in GhostScreenCopy.all) {
        expect(appMessageIds.containsKey(c), isTrue, reason: c.$1);
        expect(banned.hasMatch('${c.$1} ${c.$2}'), isFalse, reason: c.$1);
      }
    });
  });

  group('ekran', () {
    AudioInputController newAudio(FakeAudioCaptureChannel channel) =>
        AudioInputController(
          channel: channel,
          requestMicrophonePermission: () async => PermissionStatus.granted,
          pcmDeliveryTimeout: const Duration(minutes: 5),
        );

    Future<void> setView(WidgetTester tester) async {
      tester.view.physicalSize = const Size(420, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    Future<PracticeSessionController> pump(
      WidgetTester tester, {
      required bool ghost,
      required AudioInputController audio,
      required Future<NoteJudgement> Function(NoteJudgeRequest) analyzer,
    }) async {
      var local = 0;
      late PracticeSessionController controller;
      await tester.pumpWidget(
        practiceHost(
          PracticeLoopScreen(
            lesson: lesson(),
            progress: _Memory(),
            seed: 1,
            ghostScreen: ghost,
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
      _local = () => local;
      _setLocal = (v) => local = v;
      return controller;
    }

    /// Bir koşu: başlat, sinyal ver, bitir, sonuç ekranından dön.
    Future<void> oneRun(
      WidgetTester tester,
      PracticeSessionController c,
      FakeAudioCaptureChannel channel, {
      int? stopAfter,
    }) async {
      await tester.tap(find.byKey(const Key('practice-start')));
      await tester.pump();
      final rng = math.Random(1);
      var t = _local();
      for (var i = 0; i < 300; i++) {
        final x = Float64List(4800);
        for (var k = 0; k < x.length; k++) {
          x[k] = (rng.nextDouble() * 2 - 1) * .002;
        }
        channel.pushChunk(x, sampleRate: 48000, tNativeUs: t);
        t += 100000;
        _setLocal(t);
        await tester.pump();
        if (channel.metronome != null && c.timeline == null) {
          channel.pushMetronomeAnchor(t + 200000);
          await tester.pump();
        }
        c.tick();
        await tester.pump();
        if (c.phase == PracticePhase.finished) break;
        if (stopAfter != null && i + 1 >= stopAfter) {
          await c.stop();
          await tester.pump();
          break;
        }
      }
      await tester.pumpAndSettle();
      expect(c.phase, PracticePhase.finished);
      tester
          .state<NavigatorState>(find.byType(Navigator))
          .pop(const ResultActionRetry());
      await tester.pumpAndSettle();
    }

    Future<NoteJudgement> clear(NoteJudgeRequest r) async =>
        NoteJudgement(PracticeMark.correct, attackIndex: r.expectedIndex);
    Future<NoteJudgement> silent(NoteJudgeRequest r) async => judgeNote(r);

    final guideFinders = {
      'tab': find.byType(PracticeTabStrip),
      'listen': find.byType(ReferenceListenBar),
    };

    testWidgets('bayrak KAPALI: tüm rehberler, yeni widget ve metin yok', (
      tester,
    ) async {
      await setView(tester);
      final channel = FakeAudioCaptureChannel();
      final audio = newAudio(channel);
      await pump(tester, ghost: false, audio: audio, analyzer: silent);
      expect(find.byType(PracticeTabStrip), findsOneWidget);
      expect(find.byType(ReferenceListenBar), findsOneWidget);
      expect(find.byKey(const Key('ghost-toggle')), findsNothing);
      expect(find.byKey(const Key('ghost-status')), findsNothing);
      expect(find.byKey(const Key('ghost-line-hidden')), findsNothing);
      for (final c in GhostScreenCopy.all) {
        expect(find.text(c.$1), findsNothing);
      }
      expect(find.byKey(const Key('practice-start')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(audio.dispose);
    });

    testWidgets('bayrak AÇIK, anahtar kapalı: rehberlerin hepsi görünür', (
      tester,
    ) async {
      await setView(tester);
      final channel = FakeAudioCaptureChannel();
      final audio = newAudio(channel);
      await pump(tester, ghost: true, audio: audio, analyzer: silent);
      expect(find.byKey(const Key('ghost-toggle')), findsOneWidget);
      for (final f in guideFinders.values) {
        expect(f, findsOneWidget);
      }
      expect(find.byKey(const Key('ghost-status')), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(audio.dispose);
    });

    testWidgets(
      'iki ölçülü başarıdan sonra referans gizlenir; "Rehberi göster" '
      've başla her an erişilebilir',
      (tester) async {
        await setView(tester);
        final handle = tester.ensureSemantics();
        final channel = FakeAudioCaptureChannel();
        final audio = newAudio(channel);
        final c = await pump(
          tester,
          ghost: true,
          audio: audio,
          analyzer: clear,
        );
        await tester.tap(find.byKey(const Key('ghost-toggle')));
        await tester.pump();
        expect(
          find.text('Guide level: Learn: all guides shown'),
          findsOneWidget,
        );
        await oneRun(tester, c, channel);
        expect(find.byType(ReferenceListenBar), findsOneWidget);
        await oneRun(tester, c, channel);
        // Pekiştir: referans ses gizli, çizgi ve vuruş duruyor.
        expect(find.byType(ReferenceListenBar), findsNothing);
        expect(find.byType(PracticeTabStrip), findsOneWidget);
        expect(find.textContaining('Reinforce: fewer guides'), findsOneWidget);
        expect(find.byKey(const Key('practice-start')), findsOneWidget);
        // Geri aç: erişilebilir, >= 48dp, Semantics etiketli.
        final show = find.byKey(const Key('ghost-show'));
        expect(tester.getSize(show).height, greaterThanOrEqualTo(48));
        expect(tester.getSize(show).width, greaterThanOrEqualTo(48));
        expect(find.bySemanticsLabel('Show guides'), findsOneWidget);
        expect(find.bySemanticsLabel(RegExp('Guide level: ')), findsWidgets);
        await tester.tap(show);
        await tester.pump();
        expect(find.byType(ReferenceListenBar), findsOneWidget);
        expect(find.byKey(const Key('practice-start')), findsOneWidget);
        // Gizle yine ve bir düzey geri.
        await tester.tap(find.byKey(const Key('ghost-show')));
        await tester.pump();
        expect(find.byType(ReferenceListenBar), findsNothing);
        await tester.tap(find.byKey(const Key('ghost-back')));
        await tester.pump();
        expect(find.byType(ReferenceListenBar), findsOneWidget);
        expect(find.byKey(const Key('ghost-back')), findsNothing);
        handle.dispose();
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(audio.dispose);
      },
    );

    testWidgets('sessiz oda (ölçülemeyen) koşular ekranı ilerletmez', (
      tester,
    ) async {
      await setView(tester);
      final channel = FakeAudioCaptureChannel();
      final audio = newAudio(channel);
      final c = await pump(tester, ghost: true, audio: audio, analyzer: silent);
      await tester.tap(find.byKey(const Key('ghost-toggle')));
      await tester.pump();
      for (var i = 0; i < 3; i++) {
        await oneRun(tester, c, channel);
      }
      expect(find.byType(ReferenceListenBar), findsOneWidget);
      expect(find.textContaining('Learn: all guides shown'), findsOneWidget);
      expect(find.byKey(const Key('ghost-completion')), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(audio.dispose);
    });

    testWidgets(
      'rehbersiz aşama: yazılı dizi gizli, başla/durdur erişilebilir, '
      'sonuç dürüst; "Rehberi göster" geri getirir',
      (tester) async {
        await setView(tester);
        final channel = FakeAudioCaptureChannel();
        final audio = newAudio(channel);
        final c = await pump(
          tester,
          ghost: true,
          audio: audio,
          analyzer: clear,
        );
        await tester.tap(find.byKey(const Key('ghost-toggle')));
        await tester.pump();
        for (var i = 0; i < 6; i++) {
          await oneRun(tester, c, channel);
        }
        expect(find.textContaining('On your own: no guides'), findsOneWidget);
        expect(find.byType(PracticeTabStrip), findsNothing);
        expect(find.byType(ReferenceListenBar), findsNothing);
        expect(find.byType(MetronomeBeatView), findsNothing);
        expect(find.byKey(const Key('ghost-line-hidden')), findsOneWidget);
        expect(find.byKey(const Key('practice-start')), findsOneWidget);
        await oneRun(tester, c, channel);
        expect(find.byKey(const Key('ghost-completion')), findsOneWidget);
        expect(
          find.textContaining('without guides; it matched the line well'),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('ghost-show')));
        await tester.pump();
        expect(find.byType(PracticeTabStrip), findsOneWidget);
        expect(find.byKey(const Key('ghost-line-hidden')), findsNothing);
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(audio.dispose);
      },
    );

    testWidgets('durdurulmuş (kısmi) koşular aşamayı ilerletmez', (
      tester,
    ) async {
      await setView(tester);
      final channel = FakeAudioCaptureChannel();
      final audio = newAudio(channel);
      final c = await pump(tester, ghost: true, audio: audio, analyzer: clear);
      await tester.tap(find.byKey(const Key('ghost-toggle')));
      await tester.pump();
      for (var i = 0; i < 2; i++) {
        await oneRun(tester, c, channel, stopAfter: 85);
        expect(c.summary!.gate.eligible, isFalse, reason: 'durduruldu');
      }
      expect(find.byType(ReferenceListenBar), findsOneWidget);
      expect(find.textContaining('Learn: all guides shown'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(audio.dispose);
    });

    testWidgets(
      'rehbersiz aşamada durdurulmuş koşu: "örtüştü" yok, "ölçemedim" var',
      (tester) async {
        await setView(tester);
        final channel = FakeAudioCaptureChannel();
        final audio = newAudio(channel);
        final c = await pump(
          tester,
          ghost: true,
          audio: audio,
          analyzer: clear,
        );
        await tester.tap(find.byKey(const Key('ghost-toggle')));
        await tester.pump();
        for (var i = 0; i < 6; i++) {
          await oneRun(tester, c, channel);
        }
        expect(find.textContaining('On your own: no guides'), findsOneWidget);
        await oneRun(tester, c, channel, stopAfter: 85);
        expect(c.summary!.gate.eligible, isFalse);
        expect(find.textContaining('matched the line well'), findsNothing);
        expect(
          find.textContaining("couldn't tell this sound apart"),
          findsOneWidget,
        );
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(audio.dispose);
      },
    );
  });
}

late int Function() _local;
late void Function(int) _setLocal;

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
