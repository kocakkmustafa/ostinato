// F2.5 — sonuç: sayaçlar, doğruluk/duyulma, geçiş kapısı (şemadaki pass),
// hata haritası, önerilen adım, yerel ilerleme ve sıradaki dersin açılması.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/curriculum/v1_lesson.dart';
import 'package:ostinato/app/practice/loop/practice_loop_screen.dart';
import 'package:ostinato/app/practice/loop/practice_marks.dart';
import 'package:ostinato/app/practice/loop/practice_outcome.dart';
import 'package:ostinato/app/practice/loop/practice_progress_store.dart';
import 'package:ostinato/app/practice/loop/practice_result_screen.dart';
import 'package:ostinato/app/practice/loop/practice_score.dart';
import 'package:ostinato/app/practice/loop/v1_practice_catalog.dart';
import 'package:ostinato/app/practice/loop/v1_practice_list_screen.dart';
import 'package:ostinato/app/practice/setup/setup_profile_store.dart';

import 'support/practice_host.dart';

Map<String, dynamic> _lessonJson() =>
    jsonDecode(File('content/v1/gtr/gtr-s1-m02-02.json').readAsStringSync())
        as Map<String, dynamic>;

V1Lesson lesson({String id = 'gtr-s1-m02-02', Map<String, Object?>? pass}) {
  final j = _lessonJson()..['id'] = id;
  if (pass != null) (j['practice'] as Map<String, dynamic>)['pass'] = pass;
  return V1Lesson.fromJson(j);
}

final score = PracticeScore.parse('E2 F2 G2 F2 | E2 F2 G2 F2');

NoteOutcome o(int i, PracticeMark m, {int pass = 0, int? heard}) => NoteOutcome(
  eventIndex: i,
  bar: score.events[i].bar,
  pass: pass,
  mark: m,
  expectedMidi: score.events[i].midi,
  observedMidi: heard,
);

PracticeRunSummary summary(
  List<PracticeMark> marks, {
  int bpm = 60,
  bool completed = true,
  bool loop = false,
  bool wait = false,
  PassCriteria criteria = const PassCriteria(minAccuracy: .8),
}) => PracticeRunSummary.of(
  score: score,
  outcomes: [
    for (var i = 0; i < marks.length; i++)
      o(i, marks[i], heard: marks[i] == PracticeMark.differentNote ? 45 : null),
  ],
  bpm: bpm,
  openBpm: 50,
  targetBpm: 60,
  completed: completed,
  loopUsed: loop,
  waitUsed: wait,
  criteria: criteria,
);

const c = PracticeMark.correct, d = PracticeMark.differentNote;
const u = PracticeMark.couldNotHear;

void main() {
  group('PracticeRunSummary', () {
    test('accuracy excludes "could not hear"; heard is separate', () {
      final s = summary([c, c, c, c, c, c, c, u]);
      expect(s.accuracy, 1);
      expect(s.heard, 7 / 8);
      expect(s.gate.passed, isTrue);
      expect(s.nextStep, NextStep.nextLesson);
    });

    test('exactly 80 % passes, below fails with "loop slower"', () {
      expect(summary([c, c, c, c, d, c, c, c]).gate.passed, isTrue);
      final s = summary([c, c, d, c, d, c, c, c]);
      expect(s.accuracy, .75);
      expect(s.gate.passed, isFalse);
      expect(s.nextStep, NextStep.loopSlower);
      expect(s.errorBars, [0, 1]);
      expect(s.loopSuggestion, (first: 0, last: 1));
    });

    test('heard below 80 % → check setup, not a failure of the player', () {
      final s = summary([c, c, u, c, u, c, c, c]);
      expect(s.accuracy, 1);
      expect(s.gate.heardTooLow, isTrue);
      expect(s.nextStep, NextStep.checkSetup);
    });

    test('contract §6.3: opening tempo opens, target tempo completes', () {
      final all = List.filled(8, c);
      // Opening 50, target 60.
      final open = summary(all, bpm: 50);
      expect(open.gate.passed, isTrue, reason: 'opening tempo opens next');
      expect(open.gate.completed, isFalse);
      expect(open.nextStep, NextStep.nextLesson);
      final mid = summary(all, bpm: 55);
      expect((mid.gate.passed, mid.gate.completed), (true, false));
      final target = summary(all, bpm: 60);
      expect((target.gate.passed, target.gate.completed), (true, true));
      // Below the opening tempo it is practice: nothing opens.
      final slow = summary(all, bpm: 45);
      expect(slow.gate.passed, isFalse);
      expect(slow.nextStep, NextStep.raiseTempo);
      // `M!` lessons (module transitions) pass at the target tempo only.
      const gateOnly = PassCriteria(
        minAccuracy: .8,
        tempoGate: TempoGate.targetOnly,
      );
      expect(summary(all, bpm: 55, criteria: gateOnly).gate.passed, isFalse);
      expect(
        summary(all, bpm: 55, criteria: gateOnly).nextStep,
        NextStep.raiseTempo,
      );
      expect(summary(all, bpm: 60, criteria: gateOnly).gate.completed, isTrue);
      expect(
        PassCriteria.forLesson(lesson()).tempoGate,
        TempoGate.openingOpensNext,
      );
      final transition = V1Lesson.fromJson(
        jsonDecode(
              File('content/v1/gtr/gtr-s1-m02-10.json').readAsStringSync(),
            )
            as Map<String, dynamic>,
      );
      expect(transition.practice.measurement, ['M!']);
      expect(
        PassCriteria.forLesson(transition).tempoGate,
        TempoGate.targetOnly,
      );
    });

    test('loop, wait or stopped never open', () {
      final all = List.filled(8, c);
      expect(summary(all, loop: true).gate.ineligible, [
        GateIneligible.loopUsed,
      ]);
      expect(summary(all, wait: true).gate.passed, isFalse);
      expect(summary(all, wait: true).nextStep, NextStep.performanceRun);
      expect(
        summary(all.sublist(0, 5), completed: false).gate.ineligible,
        contains(GateIneligible.stoppedEarly),
      );
    });

    test('criteria come from the lesson pass field and level', () {
      final def = PassCriteria.forLesson(lesson());
      expect(def.minAccuracy, .8);
      expect(def.minHeard, .8);
      expect(def.expertPending, isTrue);
      expect(def.customText, isNull);
      final custom = PassCriteria.forLesson(
        lesson(
          pass: {
            'levelDefault': false,
            'text': {'en': 'Ten clean notes.', 'tr': 'On temiz nota.'},
            'minCorrect': 10,
          },
        ),
      );
      expect(custom.minCorrect, 10);
      expect(custom.customText!.tr, 'On temiz nota.');
      final s = summary(List.filled(8, c), criteria: custom);
      expect(s.gate.passed, isFalse, reason: '8 < minCorrect 10');
      expect(
        PassCriteria.forLesson(lesson(id: 'gtr-s4-m01-01')).minAccuracy,
        .9,
      );
    });

    test('loop passes: the error map keeps the latest pass of a note', () {
      final s = PracticeRunSummary.of(
        score: score,
        outcomes: [o(4, d), o(4, c, pass: 1)],
        bpm: 60,
        openBpm: 50,
        targetBpm: 60,
        completed: false,
        loopUsed: true,
        waitUsed: false,
      );
      expect(s.lastMarks[4]!.mark, c);
      expect(s.errorBars, isEmpty);
      expect((s.correct, s.different), (1, 1));
    });
  });

  group('progress store and unlock', () {
    late Directory dir;
    setUp(() async => dir = await Directory.systemTemp.createTemp('v1p'));
    tearDown(() async => dir.delete(recursive: true));

    test('records runs; a pass is measured evidence and sticks', () async {
      final store = V1PracticeProgressStore(directoryProvider: () async => dir);
      expect(await store.load(), isEmpty);
      await store.recordRun('gtr-s1-m02-02', summary([c, c, d, d, c, c, c, c]));
      var r = (await store.load())['gtr-s1-m02-02']!;
      expect(r.runs, 1);
      expect(r.passed, isFalse);
      expect(r.bestAccuracy, .75);
      await store.recordRun(
        'gtr-s1-m02-02',
        summary(List.filled(8, c)),
        at: DateTime.utc(2026, 11, 1),
      );
      await store.recordRun('gtr-s1-m02-02', summary([d, d, d, d, d, d, c, c]));
      r = (await store.load())['gtr-s1-m02-02']!;
      expect(r.runs, 3);
      expect(r.passedAt, DateTime.utc(2026, 11, 1));
      expect(r.passedBpm, 60);
      expect(r.completedAt, DateTime.utc(2026, 11, 1));
      expect(r.bestAccuracy, 1);
      final raw = File(
        '${dir.path}/v1_practice_progress.v1.json',
      ).readAsStringSync();
      expect(raw, contains('measured_practice'));
      // Counts only: no audio, no pitch lists.
      expect(raw, isNot(contains('samples')));
    });

    test('opening-tempo pass opens; a later target pass completes', () async {
      final store = V1PracticeProgressStore(directoryProvider: () async => dir);
      final all = List.filled(8, c);
      await store.recordRun(
        'a',
        summary(all, bpm: 50),
        at: DateTime.utc(2026, 11, 1),
      );
      var r = (await store.load())['a']!;
      expect((r.passed, r.completed, r.passedBpm), (true, false, 50));
      expect(unlockedLessons(const ['a', 'b'], {'a': r}), {'a', 'b'});
      await store.recordRun(
        'a',
        summary(all, bpm: 60),
        at: DateTime.utc(2026, 11, 2),
      );
      r = (await store.load())['a']!;
      expect(r.passedAt, DateTime.utc(2026, 11, 1), reason: 'first pass kept');
      expect((r.completedAt, r.completedBpm), (DateTime.utc(2026, 11, 2), 60));
    });

    test('files written before the fix read a pass as completed', () {
      final r = V1PracticeRecord.fromJson({
        'lessonId': 'a',
        'runs': 1,
        'passedAt': '2026-10-31T10:00:00.000Z',
        'passedBpm': 60,
        'evidence': 'measured_practice',
      });
      expect((r.passed, r.completed, r.completedBpm), (true, true, 60));
    });

    test('first lesson open; next opens after a pass', () {
      const ids = ['a', 'b', 'c'];
      expect(unlockedLessons(ids, const {}), {'a'});
      final passed = const V1PracticeRecord(
        lessonId: 'a',
      ).withRun(summary(List.filled(8, c)), DateTime.utc(2026));
      expect(unlockedLessons(ids, {'a': passed}), {'a', 'b'});
    });
  });

  test('catalog: guitar microphone lessons with pitches, in id order', () {
    final cat = V1PracticeCatalog([lesson(id: 'gtr-s1-m02-03'), lesson()]);
    expect(cat.orderedIds, ['gtr-s1-m02-02', 'gtr-s1-m02-03']);
    expect(cat.nextAfter('gtr-s1-m02-02')!.id, 'gtr-s1-m02-03');
    expect(cat.nextAfter('gtr-s1-m02-03'), isNull);
  });

  group('result screen', () {
    Future<ResultAction?> show(
      WidgetTester tester,
      PracticeRunSummary s, {
      String locale = 'en',
      bool hasNext = true,
      Finder? tap,
      V1Lesson? forLesson,
    }) async {
      tester.view.physicalSize = const Size(420, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      ResultAction? got;
      await tester.pumpWidget(
        practiceHost(
          locale: locale,
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  got = await Navigator.of(context).push<ResultAction>(
                    MaterialPageRoute(
                      builder: (_) => PracticeResultScreen(
                        lesson: forLesson ?? lesson(),
                        score: score,
                        summary: s,
                        hasNextLesson: hasNext,
                        nextLessonOpened: s.gate.passed && hasNext,
                      ),
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      if (tap != null) {
        await tester.tap(tap);
        await tester.pumpAndSettle();
      }
      return got;
    }

    testWidgets('counters, rates, gate, next lesson', (tester) async {
      final s = summary(List.filled(8, c));
      await show(tester, s);
      expect(find.text('✓ 8'), findsOneWidget);
      expect(find.text('◆ 0'), findsOneWidget);
      expect(find.text('? 0'), findsOneWidget);
      expect(find.text('%100'), findsNWidgets(2));
      expect(find.text('Timing'), findsOneWidget);
      expect(find.text('Completed at the target tempo'), findsOneWidget);
      expect(find.text('The next lesson is open.'), findsOneWidget);
      expect(find.text('Accuracy ≥ %80'), findsOneWidget);
      expect(find.text('Heard ≥ %80'), findsOneWidget);
      expect(find.text('Opening tempo ♩=50 or faster'), findsOneWidget);
      expect(
        find.text('Target tempo ♩=60 marks the lesson completed'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('result-opening-pass')), findsNothing);
      await tester.tap(find.byKey(const Key('result-next-step')));
      await tester.pumpAndSettle();
      expect(find.byType(PracticeResultScreen), findsNothing);
    });

    testWidgets('free tempo: no tempo or timing rows (there is no click)', (
      tester,
    ) async {
      final s = summary(List.filled(8, c));
      final j = _lessonJson();
      (j['practice'] as Map<String, dynamic>).remove('tempo');
      final free = V1Lesson.fromJson(j);
      expect(free.practice.tempo, isNull);
      await show(tester, s, forLesson: free);
      expect(find.text('Timing'), findsNothing);
      expect(find.text('calibrate first'), findsNothing);
    });

    testWidgets('opening-tempo pass: next lesson opens, target still to go', (
      tester,
    ) async {
      final s = summary(List.filled(8, c), bpm: 50);
      final action = await show(
        tester,
        s,
        locale: 'tr',
        tap: find.byKey(const Key('result-target-run')),
      );
      expect(action, isA<ResultActionPerformance>());
      await show(tester, s, locale: 'tr');
      expect(find.text('Açılış temposunda geçtin'), findsOneWidget);
      expect(find.text('Sıradaki ders açıldı.'), findsOneWidget);
      expect(
        find.text(
          'Açılış temposu sıradaki dersi açar. Bu dersi "tamamlandı" yapmak için hedef tempoda (♩=60) geç.',
        ),
        findsOneWidget,
      );
      expect(find.text('Sonraki derse geç'), findsOneWidget);
    });

    testWidgets('Turkish copy: different note, heard low, never "wrong"', (
      tester,
    ) async {
      final s = summary([c, d, u, u, c, c, c, c]);
      await show(tester, s, locale: 'tr');
      expect(
        find.text(
          'Puanın değil, mikrofonun takıldı. Kurulumu kontrol edip tekrar deneyelim.',
        ),
        findsOneWidget,
      );
      expect(find.text('Kurulumu kontrol et'), findsOneWidget);
      expect(find.textContaining('duydum'), findsOneWidget);
      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => (t.data ?? '').toLowerCase());
      for (final t in texts) {
        expect(t, isNot(contains('yanlış')));
        expect(t, isNot(contains('wrong')));
      }
    });

    testWidgets('error map: tapping a bar loops it', (tester) async {
      final s = summary([c, c, c, c, c, d, c, c]);
      final action = await show(
        tester,
        s,
        tap: find.byKey(const Key('result-bar-1')),
      );
      expect(action, isA<ResultActionLoop>());
      expect((action! as ResultActionLoop).first, 1);
    });
  });

  testWidgets('list: locks, and a pass opens the next lesson', (tester) async {
    final progress = _MemoryProgress();
    final catalog = V1PracticeCatalog([lesson(), lesson(id: 'gtr-s1-m02-03')]);
    final opened = <String>[];
    final setupOpened = <int>[];
    final at = DateTime.utc(2026, 11, 1);
    final setup = MemorySetupProfileStore();
    await tester.pumpWidget(
      practiceHost(
        V1PracticeListScreen(
          catalog: Future.value(catalog),
          progressFactory: (_) => progress,
          setupStore: setup,
          // The wizard: every step skipped.
          openSetup: (_) async {
            setupOpened.add(1);
            final skip = SetupStepRecord(SetupStepState.skipped, at);
            await setup.update(
              (p) => p.copyWith(
                placement: skip,
                roomStep: skip,
                latencyStep: skip,
                tuningStep: skip,
              ),
            );
          },
          practiceScreenBuilder: (l, p, hasNext) => _FakePractice(
            onOpen: () => opened.add(l.id),
            pass: () => p.recordRun(l.id, summary(List.filled(8, c))),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('OPEN'), findsOneWidget);
    expect(find.text('LOCKED · pass the lesson before'), findsOneWidget);
    await tester.tap(find.byKey(const Key('v1-practice-gtr-s1-m02-03')));
    await tester.pumpAndSettle();
    expect(opened, isEmpty, reason: 'locked lesson does not open');
    expect(
      find.text('Placement, room, latency and tuning — about two minutes.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('v1-practice-gtr-s1-m02-02')));
    await tester.pumpAndSettle();
    // Choose a lesson → setup first (once) → practice.
    expect(setupOpened, [1]);
    await tester.tap(find.text('pass'));
    await tester.pumpAndSettle();
    // The next lesson opened straight away after the pass.
    expect(opened, ['gtr-s1-m02-02', 'gtr-s1-m02-03']);
    await tester.tap(find.text('close'));
    await tester.pumpAndSettle();
    expect(find.text('COMPLETED · ♩=60'), findsOneWidget);
    expect(find.text('LOCKED · pass the lesson before'), findsNothing);
    expect(
      find.text('Latency not measured on this output: timing stays hidden.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('v1-practice-gtr-s1-m02-02')));
    await tester.pumpAndSettle();
    expect(setupOpened, [1], reason: 'the wizard runs first only once');
  });

  testWidgets('"Start next lesson" opens the first open lesson not passed', (
    tester,
  ) async {
    final progress = _MemoryProgress();
    await progress.recordRun('gtr-s1-m02-02', summary(List.filled(8, c)));
    final catalog = V1PracticeCatalog([lesson(), lesson(id: 'gtr-s1-m02-03')]);
    final opened = <String>[];
    final at = DateTime.utc(2026, 11, 1);
    final skip = SetupStepRecord(SetupStepState.skipped, at);
    final setup = MemorySetupProfileStore(
      SetupProfile.empty.copyWith(
        placement: skip,
        roomStep: skip,
        latencyStep: skip,
        tuningStep: skip,
      ),
    );
    await tester.pumpWidget(
      practiceHost(
        V1PracticeListScreen(
          startNext: true,
          catalog: Future.value(catalog),
          progressFactory: (_) => progress,
          setupStore: setup,
          practiceScreenBuilder: (l, p, hasNext) => _FakePractice(
            onOpen: () => opened.add(l.id),
            pass: () => p.recordRun(l.id, summary(List.filled(8, c))),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(opened, ['gtr-s1-m02-03']);
    await tester.tap(find.text('close'));
    await tester.pumpAndSettle();
    expect(find.byType(V1PracticeListScreen), findsOneWidget);
    expect(opened, ['gtr-s1-m02-03'], reason: 'opens once, not on return');
  });
}

final class _MemoryProgress implements V1PracticeProgress {
  final Map<String, V1PracticeRecord> records = {};
  @override
  Future<Map<String, V1PracticeRecord>> load() async => Map.of(records);
  @override
  Future<V1PracticeRecord> recordRun(
    String lessonId,
    PracticeRunSummary summary, {
    DateTime? at,
  }) async => records[lessonId] =
      (records[lessonId] ?? V1PracticeRecord(lessonId: lessonId)).withRun(
        summary,
        at ?? DateTime.utc(2026, 11, 1),
      );
}

class _FakePractice extends StatefulWidget {
  const _FakePractice({required this.onOpen, required this.pass});
  final VoidCallback onOpen;
  final Future<Object?> Function() pass;
  @override
  State<_FakePractice> createState() => _FakePracticeState();
}

class _FakePracticeState extends State<_FakePractice> {
  @override
  void initState() {
    super.initState();
    widget.onOpen();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        TextButton(
          onPressed: () async {
            await widget.pass();
            if (context.mounted) {
              Navigator.of(context).pop(PracticeExit.openNextLesson);
            }
          },
          child: const Text('pass'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(PracticeExit.closed),
          child: const Text('close'),
        ),
      ],
    ),
  );
}
