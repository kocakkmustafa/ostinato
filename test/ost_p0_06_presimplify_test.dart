// OST-P0-06 (#70) bayrak öncesi sadeleştirme: tek eylem, tek tempo önerisi,
// çift "Tekrar dene" yok, perde satırında "vuruş duymadım" yok, serbest
// tempoda eylemsiz kart yok. Yeni metin yok.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/practice/loop/ghost_screen.dart';
import 'package:ostinato/app/practice/loop/listen_try_fix.dart';
import 'package:ostinato/app/practice/loop/practice_marks.dart';
import 'package:ostinato/app/practice/loop/practice_outcome.dart';
import 'package:ostinato/app/practice/loop/practice_result_screen.dart';
import 'package:ostinato/app/practice/loop/practice_tempo_ladder.dart';

import 'listen_try_fix_screen_test.dart'
    show c, d, u, fixFor, lesson, pitchSummary, score;
import 'support/practice_host.dart';

PracticeRunSummary loopUsedSummary(List<PracticeMark> marks) =>
    PracticeRunSummary.of(
      score: score,
      outcomes: [
        for (var i = 0; i < marks.length; i++)
          NoteOutcome(
            eventIndex: i,
            bar: score.events[i].bar,
            pass: 0,
            mark: marks[i],
            expectedMidi: score.events[i].midi,
            observedMidi: marks[i] == d ? 45 : null,
          ),
      ],
      bpm: 60,
      openBpm: 50,
      targetBpm: 60,
      completed: true,
      loopUsed: true,
      waitUsed: false,
    );

Future<void> pump(
  WidgetTester tester,
  PracticeRunSummary s, {
  ListenTryFixResult? fix,
  TempoLadderOutcome? ladder,
  bool hasNextLesson = false,
  String locale = 'en',
  void Function(Object?)? onPop,
}) async {
  tester.view.physicalSize = const Size(420, 2200);
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
                  ladder: ladder,
                  hasNextLesson: hasNextLesson,
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

const stepped = TempoLadderStepped(fromBpm: 50, nextBpm: 55);

void main() {
  final lowPitch = [c, d, c, c, c, d, c, c];

  group('1) kart bilgi kartı kalır; tek eylem düğmesi', () {
    testWidgets('kart gövdesine dokunmak pop/ResultAction üretmez', (
      tester,
    ) async {
      final s = pitchSummary(lowPitch);
      var pops = 0;
      Object? popped;
      await pump(
        tester,
        s,
        fix: fixFor(s),
        onPop: (r) {
          pops++;
          popped = r;
        },
      );
      await tester.tap(find.byKey(const Key('listen-try-fix-body')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('listen-try-fix-card')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      expect(find.byType(PracticeResultScreen), findsOneWidget);
      expect(pops, 0);
      expect(popped, isNull);
      expect(find.byKey(const Key('listen-try-fix-repeat')), findsOneWidget);
    });
  });

  group('2) kart düğmesi varken result-ladder-play gizli', () {
    testWidgets('kart tekrar düğmesi + stepped ladder: yalnız kart düğmesi', (
      tester,
    ) async {
      final s = pitchSummary(lowPitch);
      await pump(tester, s, fix: fixFor(s), ladder: stepped);
      expect(find.byKey(const Key('listen-try-fix-repeat')), findsOneWidget);
      expect(find.byKey(const Key('result-ladder-play')), findsNothing);
    });

    testWidgets('kart düğmesi yok (ölçülemedi): ladder-play eskisi gibi', (
      tester,
    ) async {
      final s = pitchSummary([c, d, u, u, u, u, c, c]);
      final fix = fixFor(s);
      expect(fix, isA<FixUnmeasured>());
      await pump(tester, s, fix: fix, ladder: stepped);
      expect(find.byKey(const Key('listen-try-fix-repeat')), findsNothing);
      expect(find.byKey(const Key('result-ladder-play')), findsOneWidget);
    });

    testWidgets('kart yok (fix: null): ladder-play eskisi gibi', (
      tester,
    ) async {
      final s = pitchSummary(lowPitch);
      await pump(tester, s, ladder: stepped);
      expect(find.byKey(const Key('result-ladder-play')), findsOneWidget);
    });
  });

  group('3) çift "Tekrar dene" yok', () {
    testWidgets('ana düğme tryAgain: result-retry yok, etiket tek', (
      tester,
    ) async {
      final s = loopUsedSummary(lowPitch);
      expect(s.shownStep, NextStep.tryAgain);
      await pump(tester, s, locale: 'tr');
      expect(find.byKey(const Key('result-next-step')), findsOneWidget);
      expect(find.text('Tekrar dene'), findsOneWidget);
      expect(find.byKey(const Key('result-retry')), findsNothing);
    });

    testWidgets('ana düğme tryAgain: ana düğme Retry döndürür', (tester) async {
      final s = loopUsedSummary(lowPitch);
      Object? popped;
      await pump(tester, s, onPop: (r) => popped = r);
      await tester.tap(find.byKey(const Key('result-next-step')));
      await tester.pumpAndSettle();
      expect(popped, isA<ResultActionRetry>());
    });

    testWidgets(
      'erişilebilir: loopSlower + döngü önerisi yok (eski geçişte hata, '
      'son geçişte hepsi doğru): result-retry yok, etiket tek',
      (tester) async {
        final marks0 = [d, d, d, d, d, d, c, c];
        final s = PracticeRunSummary.of(
          score: score,
          outcomes: [
            for (var pass = 0; pass < 2; pass++)
              for (var i = 0; i < 8; i++)
                NoteOutcome(
                  eventIndex: i,
                  bar: score.events[i].bar,
                  pass: pass,
                  mark: pass == 0 ? marks0[i] : c,
                  expectedMidi: score.events[i].midi,
                  observedMidi: pass == 0 && marks0[i] == d ? 45 : null,
                ),
          ],
          bpm: 60,
          openBpm: 50,
          targetBpm: 60,
          completed: true,
          loopUsed: false,
          waitUsed: false,
        );
        expect(s.nextStep, NextStep.loopSlower);
        expect(s.loopSuggestion, isNull);
        expect(s.gate.eligible, isTrue);
        await pump(tester, s, locale: 'tr');
        expect(find.text('Tekrar dene'), findsOneWidget);
        expect(find.byKey(const Key('result-retry')), findsNothing);
      },
    );

    testWidgets('regresyon: loopSlower(döngülü) iken result-retry aynen', (
      tester,
    ) async {
      final s = pitchSummary(lowPitch);
      expect(s.shownStep, NextStep.loopSlower);
      await pump(tester, s, locale: 'tr');
      expect(find.byKey(const Key('result-retry')), findsOneWidget);
      expect(find.text('Tekrar dene'), findsOneWidget);
    });

    testWidgets('regresyon: nextLesson (sonraki ders yok) result-retry aynen', (
      tester,
    ) async {
      final s = pitchSummary(List.filled(8, c));
      expect(s.shownStep, NextStep.nextLesson);
      await pump(tester, s, locale: 'tr');
      expect(find.text('Bir kez daha çal'), findsOneWidget);
      expect(find.byKey(const Key('result-retry')), findsOneWidget);
    });
  });

  group('4) missed yalnız ritim satırında', () {
    NoteOutcome noAttack() => const NoteOutcome(
      eventIndex: 0,
      bar: 0,
      pass: 0,
      mark: PracticeMark.couldNotHear,
      reason: HearingReason.noAttack,
    );

    test('kindOf: ritim satırında missed', () {
      expect(ListenTryFix.kindOf(noAttack(), rhythm: true), FixKind.missed);
    });

    test('kindOf: perde satırında noAttack kart üretmez', () {
      expect(ListenTryFix.kindOf(noAttack(), rhythm: false), isNull);
    });

    test('perde satırı, vuruş penceresi sessiz: missed düzeltmesi yok', () {
      final marks = [c, c, c, u, c, c, u, c];
      final s = PracticeRunSummary.of(
        score: score,
        outcomes: [
          for (var i = 0; i < marks.length; i++)
            NoteOutcome(
              eventIndex: i,
              bar: score.events[i].bar,
              pass: 0,
              mark: marks[i],
              reason: marks[i] == u ? HearingReason.noAttack : null,
              expectedMidi: score.events[i].midi,
            ),
        ],
        bpm: 60,
        openBpm: 50,
        targetBpm: 60,
        completed: true,
        loopUsed: false,
        waitUsed: false,
      );
      final r = fixFor(s);
      // Kanıt var (sessiz atak eşiği aşıldı): asla "temiz" değil, kart da
      // missed demez; Hayalet Ekran bunu temiz saymaz.
      expect(r, isA<FixNoClearDifference>(), reason: '$r');
      expect(GhostScreenPolicy.classify(r), GhostAttempt.notClear);
      expect(GhostScreenPolicy.classifyRun(s, r), GhostAttempt.notClear);
    });

    test('perde satırı, tek sessiz nota (eşik altı): hâlâ temiz olabilir', () {
      final marks = [c, c, c, u, c, c, c, c];
      final s = PracticeRunSummary.of(
        score: score,
        outcomes: [
          for (var i = 0; i < marks.length; i++)
            NoteOutcome(
              eventIndex: i,
              bar: score.events[i].bar,
              pass: 0,
              mark: marks[i],
              reason: marks[i] == u ? HearingReason.noAttack : null,
              expectedMidi: score.events[i].midi,
            ),
        ],
        bpm: 60,
        openBpm: 50,
        targetBpm: 60,
        completed: true,
        loopUsed: false,
        waitUsed: false,
      );
      expect(fixFor(s), isA<FixClear>());
    });
  });

  group('5) serbest tempoda eylemsiz kart gizli', () {
    testWidgets('serbest tempo düzeltmesi: kart yok', (tester) async {
      final s = pitchSummary(lowPitch);
      final fix = ListenTryFix.of(
        s,
        lesson: lesson(),
        freeTempo: true,
        pool: const [],
      );
      expect(fix, isA<FixCorrection>());
      expect((fix as FixCorrection).plan.nextBpm, isNull);
      await pump(tester, s, fix: fix);
      expect(find.byKey(const Key('listen-try-fix-card')), findsNothing);
      expect(find.byKey(const Key('listen-try-fix-repeat')), findsNothing);
    });

    testWidgets('regresyon: eylemsiz ama bilgi kartları (ölçülemedi) kalır', (
      tester,
    ) async {
      final s = pitchSummary([c, d, u, u, u, u, c, c]);
      await pump(tester, s, fix: fixFor(s));
      expect(find.byKey(const Key('listen-try-fix-card')), findsOneWidget);
    });
  });
}
