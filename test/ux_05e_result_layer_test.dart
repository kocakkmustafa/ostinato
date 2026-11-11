// OST-UX-05e — result layer and honest status (stage mode, flag closed by
// default). Criteria 1..8 of docs/yula-execution/design/04-backlog-ux-05.md.
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
import 'package:ostinato/app/practice/loop/practice_judge.dart';
import 'package:ostinato/app/practice/loop/practice_loop_screen.dart';
import 'package:ostinato/app/practice/loop/practice_marks.dart';
import 'package:ostinato/app/practice/loop/practice_outcome.dart';
import 'package:ostinato/app/practice/loop/practice_progress_store.dart';
import 'package:ostinato/app/practice/loop/practice_result_screen.dart';
import 'package:ostinato/app/practice/loop/practice_score.dart';
import 'package:ostinato/app/practice/loop/practice_session_controller.dart';
import 'package:ostinato/app/practice/loop/result_layer_copy.dart';
import 'package:ostinato/app/practice/loop/reference_listen.dart';
import 'package:ostinato/app/stage/tool_shelf.dart';
import 'package:permission_handler/permission_handler.dart';

import 'support/practice_host.dart';

V1Lesson _lesson() => V1Lesson.fromJson(
  jsonDecode(File('content/v1/gtr/gtr-s1-m02-02.json').readAsStringSync()),
);

final _score = PracticeScore.parse('E2 F2 G2 F2 | E2 F2 G2 F2');
const _c = PracticeMark.correct,
    _d = PracticeMark.differentNote,
    _u = PracticeMark.couldNotHear;

/// [marks] in order; [reasons] gives the reason of each ◯ by event index.
PracticeRunSummary _summary(
  List<PracticeMark> marks, {
  Map<int, HearingReason> reasons = const {},
  bool completed = true,
  bool loop = false,
  bool wait = false,
}) => PracticeRunSummary.of(
  score: _score,
  outcomes: [
    for (var i = 0; i < marks.length; i++)
      NoteOutcome(
        eventIndex: i,
        bar: _score.events[i].bar,
        pass: 0,
        mark: marks[i],
        reason: marks[i] == _u ? (reasons[i] ?? HearingReason.noAttack) : null,
        expectedMidi: _score.events[i].midi,
        observedMidi: marks[i] == _d ? 45 : null,
      ),
  ],
  bpm: 60,
  openBpm: 50,
  targetBpm: 60,
  completed: completed,
  loopUsed: loop,
  waitUsed: wait,
  criteria: const PassCriteria(minAccuracy: .8),
);

Future<void> _showResult(
  WidgetTester t,
  PracticeRunSummary s, {
  bool stage = true,
  String locale = 'tr',
}) async {
  t.view.physicalSize = const Size(420, 2400);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(
    practiceHost(
      locale: locale,
      PracticeResultScreen(
        lesson: _lesson(),
        score: _score,
        summary: s,
        stage: stage,
      ),
    ),
  );
  await t.pump();
}

List<String> _texts(WidgetTester t) => [
  for (final w in t.widgetList<Text>(find.byType(Text)))
    (w.data ?? '').toLowerCase(),
];

/// The number in a counter cell (glyph, space, n).
int _count(WidgetTester t, String name) => int.parse(
  t.widget<Text>(find.byKey(Key('result-count-$name'))).data!.split(' ').last,
);

void _noVerdictWords(WidgetTester t) {
  for (final x in _texts(t)) {
    expect(x, isNot(contains('yanlış')), reason: x);
    expect(x, isNot(contains('wrong')), reason: x);
  }
}

final RegExp _promise = RegExp(
  [
    r'\b(yet|soon|coming|wrong)\b',
    'henüz',
    'yakında',
    'yanlış',
    'ainda',
    'ancora',
    'noch',
    'aún',
    'まだ',
    '아직',
    'jeszcze',
    'belum',
    'अभी',
    '还没有',
    'بعد',
    "pour l'instant",
  ].join('|'),
  caseSensitive: false,
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

/// A stage-mode practice screen on a fake microphone (quiet room noise).
class _Rig {
  _Rig() {
    audio = AudioInputController(
      channel: channel,
      requestMicrophonePermission: () async => PermissionStatus.granted,
      pcmDeliveryTimeout: const Duration(minutes: 5),
    );
  }
  final channel = FakeAudioCaptureChannel();
  late final AudioInputController audio;
  PracticeSessionController? controller;
  var local = 0, t = 0;
  final rng = math.Random(1);
  final progress = _Memory();

  Widget screen() => practiceHost(
    locale: 'tr',
    PracticeLoopScreen(
      lesson: _lesson(),
      progress: progress,
      stageMode: true,
      controllerFactory: (score, tempo, criteria) =>
          controller = PracticeSessionController(
            score: score,
            tempo: tempo,
            audio: audio,
            criteria: criteria,
            localClockUs: () => local,
            analyzer: (r) async => judgeNote(r),
          ),
    ),
  );

  Future<void> feed(WidgetTester tester, int chunks) async {
    final c = controller!;
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

  Future<void> boot(WidgetTester tester) async {
    tester.view.physicalSize = const Size(420, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(screen());
    await tester.pump();
  }

  /// Play, feed until some notes were judged, then Stop.
  Future<void> playAndStop(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('practice-start')));
    await tester.pump();
    await feed(tester, 60);
    expect(controller!.running, isTrue);
    expect(controller!.outcomes, isNotEmpty);
    await tester.tap(find.byKey(const Key('practice-stop')));
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(audio.dispose);
  }
}

void main() {
  setUp(resetAudioCaptureCoordinatorForTest);

  group('olcut1 content kept in stage mode', () {
    testWidgets('counts, error map, gate, retry are all there', (t) async {
      await _showResult(t, _summary([_c, _c, _c, _d, _u, _c, _c, _c]));
      expect(_count(t, 'correct'), 6);
      expect(_count(t, 'differentNote'), 1);
      expect(_count(t, 'couldNotHear'), 1);
      expect(find.byKey(const Key('result-count-correct')), findsOneWidget);
      expect(find.byKey(const Key('result-error-map')), findsOneWidget);
      expect(find.byKey(const Key('result-gate')), findsOneWidget);
      expect(find.byKey(const Key('result-retry')), findsOneWidget);
      expect(find.byKey(const Key('result-bar-0')), findsOneWidget);
    });
  });

  group('olcut2 neutral reason for every unheard note', () {
    for (final r in HearingReason.values) {
      testWidgets('${r.name}: a neutral line, no verdict word (tr + en)', (
        t,
      ) async {
        for (final loc in ['tr', 'en']) {
          await _showResult(
            t,
            _summary([_c, _c, _c, _c, _c, _c, _c, _u], reasons: {7: r}),
            locale: loc,
          );
          final pair = ResultLayerCopy.forReason(r);
          expect(find.byKey(Key('result-reason-${r.name}')), findsOneWidget);
          expect(find.text(loc == 'tr' ? pair.$2 : pair.$1), findsOneWidget);
          _noVerdictWords(t);
        }
      });
    }

    testWidgets('one row per reason, with how many notes', (t) async {
      await _showResult(
        t,
        _summary(
          [_c, _c, _u, _u, _u, _c, _c, _c],
          reasons: {
            2: HearingReason.noAttack,
            3: HearingReason.noAttack,
            4: HearingReason.tooQuiet,
          },
        ),
      );
      expect(find.byKey(const Key('result-reason-noAttack')), findsOneWidget);
      expect(find.byKey(const Key('result-reason-tooQuiet')), findsOneWidget);
      expect(find.byKey(const Key('result-reason-tooLoud')), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const Key('result-reason-noAttack')),
          matching: find.textContaining('2'),
        ),
        findsWidgets,
      );
    });

    testWidgets('nothing unheard: no reason section', (t) async {
      await _showResult(t, _summary([_c, _c, _c, _c, _c, _c, _c, _c]));
      expect(find.byKey(const Key('result-reasons')), findsNothing);
    });

    testWidgets('flag-closed screen (stage false): exactly as before', (
      t,
    ) async {
      await _showResult(
        t,
        _summary([_c, _c, _c, _c, _c, _c, _c, _u]),
        stage: false,
      );
      expect(find.byKey(const Key('result-reasons')), findsNothing);
      expect(find.byKey(const Key('result-not-measured')), findsNothing);
    });

    test('the new pairs are in all 14 catalogs, no verdict, no promise', () {
      for (final p in ResultLayerCopy.newPairs) {
        expect(appMessageIds.containsKey(p), isTrue, reason: '$p');
      }
      var files = 0;
      for (final f in Directory('assets/l10n').listSync()) {
        if (f is! File || !f.path.endsWith('.json')) continue;
        files++;
        final messages =
            (jsonDecode(f.readAsStringSync()) as Map)['messages'] as Map;
        for (final p in ResultLayerCopy.newPairs) {
          final text = messages[appMessageIds[p]] as String?;
          expect(text, isNotNull, reason: '${f.path} $p');
          expect(text, isNotEmpty);
          expect(_promise.hasMatch(text!), isFalse, reason: '${f.path} $text');
          if (!f.path.endsWith('/en.json') && !f.path.endsWith('/tr.json')) {
            expect(text, isNot(p.$1), reason: f.path);
          }
        }
      }
      expect(files, 14);
    });
  });

  group('olcut3 heard apart from accuracy (stage mode too)', () {
    testWidgets('accuracy is over decided notes; heard is its own line', (
      t,
    ) async {
      await _showResult(t, _summary([_c, _c, _c, _c, _c, _c, _u, _u]));
      expect(
        t.widget<Text>(find.byKey(const Key('result-accuracy'))).data,
        contains('100'),
      );
      expect(
        t.widget<Text>(find.byKey(const Key('result-heard'))).data,
        contains('75'),
      );
    });
  });

  group('olcut5 "not measured" label', () {
    final cases = <String, PracticeRunSummary>{
      'stopped early': _summary([_c, _c, _c, _c], completed: false),
      'loop used': _summary([_c, _c, _c, _c, _c, _c, _c, _c], loop: true),
      'wait used': _summary([_c, _c, _c, _c, _c, _c, _c, _c], wait: true),
    };
    cases.forEach((name, s) {
      testWidgets('$name: label, no gate, one message only', (t) async {
        expect(s.gate.eligible, isFalse);
        expect(s.gate.passed, isFalse);
        await _showResult(t, s);
        expect(find.byKey(const Key('result-not-measured')), findsOneWidget);
        expect(find.text(ResultLayerCopy.notMeasured.$2), findsOneWidget);
        // The old "practice round" title is not shown next to it.
        expect(find.textContaining('Pratik turu'), findsNothing);
        _noVerdictWords(t);
      });
    });

    testWidgets('a full measured run: no label', (t) async {
      await _showResult(t, _summary([_c, _c, _c, _c, _c, _c, _c, _c]));
      expect(find.byKey(const Key('result-not-measured')), findsNothing);
    });

    testWidgets('stage false: the old title, no new label', (t) async {
      await _showResult(
        t,
        _summary([_c, _c, _c, _c, _c, _c, _c, _c], loop: true),
        stage: false,
      );
      expect(find.byKey(const Key('result-not-measured')), findsNothing);
      expect(find.textContaining('Pratik turu'), findsOneWidget);
    });
  });

  group('olcut6 noisy / several notes: unheard + reason, no verdict', () {
    testWidgets('unclear pitch: ◯ and its reason, nothing marked wrong', (
      t,
    ) async {
      final s = _summary(
        [_u, _u, _u, _u, _u, _u, _u, _u],
        reasons: {for (var i = 0; i < 8; i++) i: HearingReason.unclear},
      );
      expect(s.different, 0);
      await _showResult(t, s);
      expect(_count(t, 'couldNotHear'), 8);
      expect(_count(t, 'differentNote'), 0);
      expect(find.byKey(const Key('result-reason-unclear')), findsOneWidget);
      _noVerdictWords(t);
    });
  });

  group('olcut8 the layer comes only after Stop', () {
    testWidgets('while playing no result; after Stop the stage result', (
      t,
    ) async {
      final rig = _Rig();
      await rig.boot(t);
      await t.tap(find.byKey(const Key('practice-start')));
      await t.pump();
      await rig.feed(t, 60);
      expect(rig.controller!.running, isTrue);
      expect(find.byType(PracticeResultScreen), findsNothing);
      expect(find.byKey(const Key('result-gate')), findsNothing);
      expect(find.byKey(const Key('result-retry')), findsNothing);
      await t.tap(find.byKey(const Key('practice-stop')));
      for (var i = 0; i < 6; i++) {
        await t.runAsync(() => Future<void>.delayed(Duration.zero));
        await t.pump();
      }
      await t.pumpAndSettle();
      expect(find.byType(PracticeResultScreen), findsOneWidget);
      expect(
        t.widget<PracticeResultScreen>(find.byType(PracticeResultScreen)).stage,
        isTrue,
        reason: 'the stage passes its mode to the result',
      );
      expect(find.byKey(const Key('result-not-measured')), findsOneWidget);
      await rig.dispose(t);
    });

    testWidgets('no Stop, no result: the run ends silently on dispose', (
      t,
    ) async {
      final rig = _Rig();
      await rig.boot(t);
      await t.tap(find.byKey(const Key('practice-start')));
      await t.pump();
      await rig.feed(t, 30);
      expect(find.byType(PracticeResultScreen), findsNothing);
      await rig.dispose(t);
      expect(rig.progress.records, isEmpty);
    });
  });

  group('olcut7 where it happened: retry stays on the same bars', () {
    testWidgets('retry keeps the loop bars; a bar tap sets the loop', (
      t,
    ) async {
      final rig = _Rig();
      await rig.boot(t);
      // The section is chosen on the stage (what the shelf does), then Play.
      rig.controller!.loopBars = (first: 1, last: 1);
      await t.tap(find.byKey(const Key('practice-start')));
      await t.pump();
      await rig.feed(t, 60);
      await t.tap(find.byKey(const Key('practice-stop')));
      for (var i = 0; i < 6; i++) {
        await t.runAsync(() => Future<void>.delayed(Duration.zero));
        await t.pump();
      }
      await t.pumpAndSettle();
      expect(find.byType(PracticeResultScreen), findsOneWidget);
      await t.tap(find.byKey(const Key('result-retry')));
      await t.pumpAndSettle();
      // Ready to play again on the same section.
      expect(find.byKey(const Key('practice-start')), findsOneWidget);
      expect(rig.controller!.loopBars, (first: 1, last: 1));
      expect(rig.controller!.running, isFalse);
      await rig.dispose(t);
    });

    testWidgets('a bar tap loops it; the stage shelf shows that range', (
      t,
    ) async {
      final rig = _Rig();
      final listen = ReferenceListenController();
      addTearDown(listen.dispose);
      await t.pumpWidget(
        practiceHost(
          locale: 'tr',
          Column(
            children: [
              Expanded(child: (rig.screen() as MaterialApp).home!),
              Builder(
                key: const Key('shelf-host'),
                builder: (_) => rig.controller == null
                    ? const SizedBox()
                    : SizedBox(
                        height: 300,
                        child: SingleChildScrollView(
                          child: ToolShelf(
                            open: true,
                            onToggle: () {},
                            controller: rig.controller!,
                            listen: listen,
                            pinned: false,
                            onPinned: (_) {},
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      );
      t.view.physicalSize = const Size(420, 2400);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pump();
      t.element(find.byKey(const Key('shelf-host'))).markNeedsBuild();
      await t.pump();
      expect(rig.controller!.loopBars, isNull);
      await rig.playAndStop(t);
      expect(find.byType(PracticeResultScreen), findsOneWidget);
      await t.tap(find.byKey(const Key('result-bar-1')));
      await t.pumpAndSettle();
      expect(rig.controller!.loopBars, (first: 1, last: 1));
      expect(find.byKey(const Key('practice-start')), findsOneWidget);
      final range = t.widget<RangeSlider>(
        find.byKey(const Key('stage-loop-range')),
      );
      expect(range.values, const RangeValues(1, 1));
      await rig.dispose(t);
    });
  });
}
