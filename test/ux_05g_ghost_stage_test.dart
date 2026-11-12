// OST-UX-05g (W) — sahnede Raf > Yardim: bayrak, dort basamak matrisi, elle
// secim, olcum kapili oneri yuzeyi, calarken, NextStep sahne yolu.
// Anahtarlar (tasarim notu): stage-help-row, ghost-help-surface,
// ghost-level-<learn|reinforce|recall|independent>,
// ghost-item-<notation|tab|beat|label|preStartPreview|metronome|hint>,
// ghost-suggestion, ghost-last-run.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/audio/audio_input_controller.dart';
import 'package:ostinato/app/curriculum/v1_lesson.dart';
import 'package:ostinato/app/practice/loop/practice_marks.dart';
import 'package:ostinato/app/practice/loop/practice_outcome.dart';
import 'package:ostinato/app/practice/loop/practice_result_screen.dart';
import 'package:ostinato/app/practice/loop/practice_score.dart';
import 'package:ostinato/app/stage/ghost_policy.dart';
import 'package:ostinato/app/stage/ghost_store.dart';

import 'support/practice_host.dart';
import 'support/ux_05g_rig.dart';

const _levels = <String, GhostLevel>{
  'learn': GhostLevel.learn,
  'reinforce': GhostLevel.reinforce,
  'recall': GhostLevel.recall,
  'independent': GhostLevel.independent,
};

// 04-design Ek B, 5.6: basamak -> gorunen ogeler (LITERAL).
const _matrix = <String, Set<String>>{
  'learn': {'notation', 'tab', 'beat', 'label'},
  'reinforce': {'notation', 'tab', 'beat'},
  'recall': {'preStartPreview', 'beat'},
  'independent': {'metronome', 'hint'},
};
const _allItems = [
  'notation',
  'tab',
  'beat',
  'label',
  'preStartPreview',
  'metronome',
  'hint',
];
const _trLevel = {
  'learn': 'Öğrenme',
  'reinforce': 'Pekiştirme',
  'recall': 'Hatırlama',
  'independent': 'Bağımsız',
};

final _stems = RegExp(
  r'yetkinlik|kazanıl|ustalaş|mastered|competen|yanlış|wrong',
  caseSensitive: false,
);

Future<void> _openShelf(WidgetTester t) async {
  await t.tap(find.byKey(const Key('stage-shelf-toggle')));
  await t.pump();
  await t.pump();
}

Future<void> _openHelp(WidgetTester t) async {
  await _openShelf(t);
  await t.ensureVisible(find.byKey(const Key('stage-help-row')));
  await t.pump();
  await t.tap(find.byKey(const Key('stage-help-row')));
  await t.pump();
  await t.pump();
}

String _allText(WidgetTester t) => [
  for (final w in t.widgetList<Text>(find.byType(Text))) w.data ?? '',
].join('\n');

void main() {
  late final catalog = catalog05f();
  setUp(resetAudioCaptureCoordinatorForTest);

  group('05g-1 bayrak', () {
    testWidgets('05g-1: bayrak KAPALI: Yardim satiri HIC gorunmez', (t) async {
      final rig = Rig05f();
      await boot05f(t, stage05g(rig, catalog, ghost: false));
      await _openShelf(t);
      expect(find.byKey(const Key('stage-shelf')), findsOneWidget);
      expect(find.byKey(const Key('stage-pin-metronome')), findsOneWidget);
      expect(find.byKey(const Key('stage-help-row')), findsNothing);
      expect(find.text('Yardım'), findsNothing);
      expect(find.byKey(const Key('ghost-help-surface')), findsNothing);
      // pratik aynen: Cal var, eski Hayalet paneli yok
      expect(find.byKey(const Key('practice-start')), findsOneWidget);
      expect(find.byKey(const Key('ghost-toggle')), findsNothing);
      await dispose05f(t, rig);
    });

    testWidgets('05g-1: bayrak ACIK: Yardim satiri gorunur, yuzey acilir', (
      t,
    ) async {
      final rig = Rig05f();
      await boot05f(t, stage05g(rig, catalog, ghost: true));
      await _openShelf(t);
      expect(find.byKey(const Key('stage-help-row')), findsOneWidget);
      expect(find.text('Yardım'), findsOneWidget);
      expect(find.byKey(const Key('ghost-help-surface')), findsNothing);
      await t.ensureVisible(find.byKey(const Key('stage-help-row')));
      await t.pump();
      await t.tap(find.byKey(const Key('stage-help-row')));
      await t.pump();
      await t.pump();
      expect(find.byKey(const Key('ghost-help-surface')), findsOneWidget);
      expect(find.text('Yardım düzeyi'), findsOneWidget);
      for (final k in _levels.keys) {
        expect(find.byKey(Key('ghost-level-$k')), findsOneWidget, reason: k);
        expect(find.text(_trLevel[k]!), findsOneWidget, reason: k);
      }
      // sahnede eski panel asla (stage yolu)
      expect(find.byKey(const Key('ghost-toggle')), findsNothing);
      await dispose05f(t, rig);
    });

    // ÖNCEDEN KARSILANIYOR (dosya:satir): eski paneli sahnede gostermez:
    // lib/app/practice/loop/practice_loop_screen.dart:72 (ghostScreen varsayilan
    // ostinatoGhostScreenOpen=false), sahne `ghostScreen:` vermez
    // (stage_home_screen.dart PracticeLoopScreen cagrisi).
  });

  group('05g-2 dort basamak matrisi', () {
    for (final entry in _matrix.entries) {
      testWidgets('05g-2: ${entry.key}: gorunen ogeler = ${entry.value}', (
        t,
      ) async {
        final rig = Rig05f();
        final store = MemoryGhostStore();
        await boot05f(t, stage05g(rig, catalog, ghostStore: store));
        await _openHelp(t);
        expect(find.byKey(Key('ghost-level-${entry.key}')), findsOneWidget);
        await t.ensureVisible(find.byKey(Key('ghost-level-${entry.key}')));
        await t.tap(find.byKey(Key('ghost-level-${entry.key}')));
        await t.pump();
        await t.pump();
        for (final i in _allItems) {
          expect(
            find.byKey(Key('ghost-item-$i')),
            entry.value.contains(i) ? findsOneWidget : findsNothing,
            reason: '${entry.key} / $i',
          );
        }
        expect(store.state.level, _levels[entry.key]);
        await dispose05f(t, rig);
      });
    }
  });

  group('05g-3 yalniz elle', () {
    testWidgets('05g-3: yuksek sayac + oneri varken basamak kendiliginden '
        'DEGISMEZ', (t) async {
      final rig = Rig05f();
      final store = MemoryGhostStore(
        const GhostState(
          level: GhostLevel.learn,
          validRuns: 7,
          lastRun: GhostLastRun.counted,
        ),
      );
      await boot05f(t, stage05g(rig, catalog, ghostStore: store));
      await _openHelp(t);
      await t.pump(const Duration(seconds: 2));
      expect(find.byKey(const Key('ghost-help-surface')), findsOneWidget);
      expect(store.state.level, GhostLevel.learn);
      // yalniz oneri satiri; secim hala Ogrenme (ogeler Ogrenme matrisi)
      expect(find.byKey(const Key('ghost-item-label')), findsOneWidget);
      expect(find.byKey(const Key('ghost-suggestion')), findsOneWidget);
      await dispose05f(t, rig);
    });
  });

  group('05g-4/5 oneri satiri ve durum', () {
    Future<void> openWith(WidgetTester t, GhostState s, Rig05f rig) async {
      await boot05f(t, stage05g(rig, catalog, ghostStore: MemoryGhostStore(s)));
      await _openHelp(t);
    }

    testWidgets('05g-4: yeterli gecerli kosu: ince oneri satiri', (t) async {
      final rig = Rig05f();
      await openWith(
        t,
        const GhostState(
          level: GhostLevel.reinforce,
          validRuns: 2,
          lastRun: GhostLastRun.counted,
        ),
        rig,
      );
      final s = find.byKey(const Key('ghost-suggestion'));
      expect(s, findsOneWidget);
      expect(
        (t.widget(s) as Text).data,
        'Bir basamak yukarı denenebilir: Hatırlama',
      );
      await dispose05f(t, rig);
    });

    testWidgets('05g-4: esik-1 / bagimsiz basamak: oneri YOK', (t) async {
      final rig = Rig05f();
      await openWith(
        t,
        const GhostState(level: GhostLevel.reinforce, validRuns: 1),
        rig,
      );
      // kontrol: ayni yuzeyde esik dolunca cikar (ayri test); burada yuzey var
      expect(find.byKey(const Key('ghost-help-surface')), findsOneWidget);
      expect(find.byKey(const Key('ghost-suggestion')), findsNothing);
      await dispose05f(t, rig);
      final rig2 = Rig05f();
      await openWith(
        t,
        const GhostState(level: GhostLevel.independent, validRuns: 9),
        rig2,
      );
      expect(find.byKey(const Key('ghost-help-surface')), findsOneWidget);
      expect(find.byKey(const Key('ghost-suggestion')), findsNothing);
      await dispose05f(t, rig2);
    });

    testWidgets(
      '05g-5: olculmeyen son kosu: "olculmedi", yetkinlik metni yok',
      (t) async {
        final rig = Rig05f();
        await openWith(
          t,
          const GhostState(
            level: GhostLevel.learn,
            validRuns: 0,
            lastRun: GhostLastRun.notMeasured,
          ),
          rig,
        );
        final l = find.byKey(const Key('ghost-last-run'));
        expect(l, findsOneWidget);
        expect(
          (t.widget(l) as Text).data,
          'Son koşu ölçülmedi; basamağa sayılmadı',
        );
        expect(find.byKey(const Key('ghost-suggestion')), findsNothing);
        expect(_stems.hasMatch(_allText(t)), isFalse, reason: _allText(t));
        await dispose05f(t, rig);
      },
    );

    testWidgets('05g-5: bos/kayitsiz durum: ogrenme, oneri ve son kosu yok', (
      t,
    ) async {
      final rig = Rig05f();
      await openWith(t, const GhostState(), rig);
      expect(find.byKey(const Key('ghost-help-surface')), findsOneWidget);
      expect(find.byKey(const Key('ghost-item-label')), findsOneWidget);
      expect(find.byKey(const Key('ghost-suggestion')), findsNothing);
      expect(find.byKey(const Key('ghost-last-run')), findsNothing);
      await dispose05f(t, rig);
    });
  });

  group('05g-8 calarken', () {
    testWidgets('05g-8: calarken raf/yardim yok; ayar degismez', (t) async {
      final rig = Rig05f();
      final store = MemoryGhostStore(
        const GhostState(level: GhostLevel.reinforce, validRuns: 1),
      );
      await boot05f(t, stage05g(rig, catalog, ghostStore: store));
      await _openHelp(t);
      expect(find.byKey(const Key('ghost-help-surface')), findsOneWidget);
      await play05f(t);
      expect(find.byKey(const Key('stage-help-row')), findsNothing);
      expect(find.byKey(const Key('ghost-help-surface')), findsNothing);
      for (final k in _levels.keys) {
        expect(find.byKey(Key('ghost-level-$k')), findsNothing, reason: k);
      }
      expect(store.state.level, GhostLevel.reinforce);
      expect(store.state.validRuns, 1);
      await dispose05f(t, rig);
    });
  });

  group('genel: erisilebilirlik', () {
    testWidgets(
      'Yardim satiri ve basamak secenekleri: tek dugum, buton, >=48dp',
      (t) async {
        final sem = t.ensureSemantics();
        final rig = Rig05f();
        await boot05f(t, stage05g(rig, catalog));
        await _openShelf(t);
        final row = find.byKey(const Key('stage-help-row'));
        expect(row, findsOneWidget);
        expect(t.getSize(row).height, greaterThanOrEqualTo(48));
        expect(
          t.getSemantics(row).getSemanticsData().flagsCollection.isButton,
          isTrue,
        );
        expect(t.getSemantics(row).label, 'Yardım');
        await t.ensureVisible(row);
        await t.pump();
        await t.tap(row);
        await t.pump();
        await t.pump();
        for (final k in _levels.keys) {
          final f = find.byKey(Key('ghost-level-$k'));
          expect(f, findsOneWidget, reason: k);
          await t.ensureVisible(f);
          expect(t.getSize(f).height, greaterThanOrEqualTo(48), reason: k);
          final node = t.getSemantics(f);
          expect(node.getSemanticsData().flagsCollection.isButton, isTrue);
          expect(node.label, _trLevel[k], reason: k);
        }
        sem.dispose();
        await dispose05f(t, rig);
      },
    );
  });

  group('05g-ek NextStep sahne yolu (05e takibi)', () {
    final lesson = V1Lesson.fromJson(
      jsonDecode(File('content/v1/gtr/gtr-s1-m02-02.json').readAsStringSync()),
    );
    final score = PracticeScore.parse('E2 F2 G2 F2 | E2 F2 G2 F2');
    const c = PracticeMark.correct, d = PracticeMark.differentNote;
    const u = PracticeMark.couldNotHear;

    PracticeRunSummary sum(
      List<PracticeMark> m, {
      bool completed = true,
      bool loop = false,
      bool wait = false,
      int bpm = 60,
    }) => PracticeRunSummary.of(
      score: score,
      outcomes: [
        for (var i = 0; i < m.length; i++)
          NoteOutcome(
            eventIndex: i,
            bar: score.events[i].bar,
            pass: 0,
            mark: m[i],
            reason: m[i] == u ? HearingReason.noAttack : null,
            expectedMidi: score.events[i].midi,
            observedMidi: m[i] == d ? 45 : null,
          ),
      ],
      bpm: bpm,
      openBpm: 50,
      targetBpm: 60,
      completed: completed,
      loopUsed: loop,
      waitUsed: wait,
      criteria: const PassCriteria(minAccuracy: .8),
    );

    Future<String> label(
      WidgetTester t,
      PracticeRunSummary s, {
      required bool stage,
    }) async {
      t.view.physicalSize = const Size(420, 2400);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(
        practiceHost(
          locale: 'tr',
          PracticeResultScreen(
            lesson: lesson,
            score: score,
            summary: s,
            stage: stage,
          ),
        ),
      );
      await t.pump();
      final btn = find.byKey(const Key('result-next-step'));
      expect(btn, findsOneWidget);
      return ((t.widget(btn) as FilledButton).child! as Text).data!;
    }

    const loopSlower = 'Bu ölçüleri %70 tempoda döngüle';
    const raise = 'Tempoyu 5 artır';
    const perf = 'Tüm diziyi hedef tempoda çal';

    // (ad, ozet, eski akis etiketi)
    final cases = <(String, PracticeRunSummary, String)>[
      (
        'stoppedEarly dusuk dogruluk',
        sum([c, c, d, c, d], completed: false),
        loopSlower,
      ),
      (
        'stoppedEarly dusuk tempo',
        sum([c, c, c], completed: false, bpm: 45),
        raise,
      ),
      (
        'stoppedEarly tam dogruluk hedef tempo',
        sum([c, c, c, c], completed: false),
        perf,
      ),
      (
        'loopUsed dusuk tempo',
        sum(List.filled(8, c), loop: true, bpm: 45),
        raise,
      ),
      (
        'waitUsed dusuk dogruluk',
        sum([c, c, d, c, d, c, c, c], wait: true),
        loopSlower,
      ),
      ('loopUsed hedef tempo', sum(List.filled(8, c), loop: true), perf),
    ];
    for (final (name, s, old) in cases) {
      testWidgets('05g-ek: stage=false BIREBIR: $name -> "$old"', (t) async {
        expect(await label(t, s, stage: false), old);
      });
      testWidgets('05g-ek: stage=true: $name -> oneri URETILMEZ', (t) async {
        // kontrol (eski akis ayni girdide oneriyi uretir)
        expect(s.nextStep, isNot(NextStep.nextLesson));
        final l = await label(t, s, stage: true);
        expect([loopSlower, raise, perf], isNot(contains(l)));
        expect(l, 'Tekrar dene');
        expect(find.byKey(const Key('result-not-measured')), findsOneWidget);
        expect(find.text('Ölçülmedi'), findsOneWidget);
      });
    }

    testWidgets('05g-ek: gecit gecen tam kosu stage=true da degismez', (
      t,
    ) async {
      final s = sum(List.filled(8, c));
      expect(await label(t, s, stage: false), 'Bir kez daha çal');
      expect(await label(t, s, stage: true), 'Bir kez daha çal');
    });
  });
}
