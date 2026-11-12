// OST-UX-05g Faz B giris testleri (W): sahnenin GERCEK baglanti satiri
// (stage_home_screen.dart: PracticeLoopScreen.onSessionFinished -> ghost
// store). Olay, sahnenin PracticeLoopScreen'ine verdigi callback'in kendisi
// cagrilarak enjekte edilir (rig'de gercek kosu cok agir).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/audio/audio_input_controller.dart';
import 'package:ostinato/app/practice/loop/practice_loop_screen.dart';
import 'package:ostinato/app/practice/loop/practice_marks.dart';
import 'package:ostinato/app/practice/loop/practice_outcome.dart';
import 'package:ostinato/app/practice/loop/practice_score.dart';
import 'package:ostinato/app/stage/ghost_policy.dart';
import 'package:ostinato/app/stage/ghost_store.dart';

import 'support/ux_05g_rig.dart';

final _score = PracticeScore.parse('E2 F2 G2 F2 | E2 F2 G2 F2');
const _c = PracticeMark.correct, _u = PracticeMark.couldNotHear;

PracticeRunSummary _sum(
  List<PracticeMark> marks, {
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
        reason: marks[i] == _u ? HearingReason.noAttack : null,
        expectedMidi: _score.events[i].midi,
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

PracticeSessionFinished _ev(
  PracticeRunSummary s, {
  String id = 'gtr-s1-m02-02',
  String course = 'guitar',
}) => PracticeSessionFinished(
  lessonId: id,
  course: course,
  activeDuration: const Duration(seconds: 12),
  heardEvents: s.correct + s.different,
  summary: s,
);

Future<void> _finish(
  WidgetTester t,
  PracticeSessionFinished e, {
  bool requireWired = true,
}) async {
  final cb = t
      .widget<PracticeLoopScreen>(find.byType(PracticeLoopScreen))
      .onSessionFinished;
  if (requireWired) {
    expect(cb, isNotNull, reason: 'sahne onSessionFinished baglamali');
  }
  cb?.call(e);
  for (var i = 0; i < 4; i++) {
    await t.pump();
  }
}

void main() {
  late final catalog = catalog05f();
  setUp(resetAudioCaptureCoordinatorForTest);

  final valid = _ev(_sum(List.filled(8, _c)));
  final bad = <String, PracticeSessionFinished>{
    'stoppedEarly': _ev(_sum(List.filled(4, _c), completed: false)),
    'olculmemis (bos, yarim)': _ev(_sum(const [], completed: false)),
    'loopUsed': _ev(_sum(List.filled(8, _c), loop: true)),
    'waitUsed': _ev(_sum(List.filled(8, _c), wait: true)),
    'heard<80': _ev(_sum([_c, _c, _c, _c, _c, _u, _u, _u])),
  };

  testWidgets('05g-int: gecerli kosu sayaci arttirir ve store e yazar', (
    t,
  ) async {
    final rig = Rig05f();
    final store = MemoryGhostStore();
    await boot05f(t, stage05g(rig, catalog, ghostStore: store));
    await _finish(t, valid);
    expect(store.state.validRuns, 1);
    expect(store.state.lastRun, GhostLastRun.counted);
    expect(store.state.level, GhostLevel.learn, reason: 'oto degisim yok');
    await _finish(t, valid);
    expect(store.state.validRuns, 2);
    await dispose05f(t, rig);
  });

  for (final e in bad.entries) {
    testWidgets('05g-int: ${e.key} sayaci ARTIRMAZ', (t) async {
      final rig = Rig05f();
      final store = MemoryGhostStore();
      await boot05f(t, stage05g(rig, catalog, ghostStore: store));
      // kontrol: ayni baglantidan gecerli kosu sayilir
      await _finish(t, valid);
      expect(store.state.validRuns, 1, reason: 'kontrol');
      await _finish(t, e.value);
      expect(store.state.validRuns, 1, reason: e.key);
      expect(store.state.level, GhostLevel.learn);
      expect(store.state.lastRun, isNot(GhostLastRun.counted), reason: e.key);
      await dispose05f(t, rig);
    });
  }

  testWidgets('05g-int: kulak kosusu (ear) Hayaleti etkilemez', (t) async {
    final rig = Rig05f();
    final store = MemoryGhostStore();
    await boot05f(t, stage05g(rig, catalog, ghostStore: store));
    await _finish(t, valid);
    expect(store.state.validRuns, 1, reason: 'kontrol');
    await _finish(
      t,
      _ev(_sum(List.filled(8, _c)), id: 'ear-s1-m01-01', course: 'ear'),
    );
    expect(store.state.validRuns, 1);
    expect(store.state.lastRun, GhostLastRun.counted, reason: 'dokunulmadi');
    await dispose05f(t, rig);
  });

  testWidgets('05g-int: ritim-only (isRhythmOnly) kosu Hayaleti etkilemez', (
    t,
  ) async {
    final rig = Rig05f();
    final store = MemoryGhostStore();
    await boot05f(t, stage05g(rig, catalog, ghostStore: store));
    await _finish(t, valid);
    expect(store.state.validRuns, 1, reason: 'kontrol');
    await _finish(t, _ev(_sum(List.filled(8, _c)), id: 'gtr-s1-m03-01'));
    expect(store.state.validRuns, 1);
    await dispose05f(t, rig);
  });

  testWidgets('05g-int: bayrak KAPALI: store e hic yazilmaz', (t) async {
    final rig = Rig05f();
    final store = MemoryGhostStore();
    await boot05f(t, stage05g(rig, catalog, ghost: false, ghostStore: store));
    // kontrol (acik bayrakta ayni baglanti yazar) ayri testte; burada eski akis
    await _finish(t, valid, requireWired: false);
    expect(store.state.validRuns, 0);
    expect(store.state.lastRun, GhostLastRun.none);
    await dispose05f(t, rig);
  });

  testWidgets('05g-int: yeniden aciliste basamak ve sayac geri gelir', (
    t,
  ) async {
    final rig = Rig05f();
    final store = MemoryGhostStore();
    await boot05f(t, stage05g(rig, catalog, ghostStore: store));
    await _finish(t, valid);
    expect(store.state.validRuns, 1, reason: 'kontrol');
    await t.pumpWidget(const SizedBox());
    await t.runAsync(rig.audio.dispose);
    // yeni sahne ayni store ile: 1 gecerli kosu, Ogrenme -> oneri satiri
    final rig2 = Rig05f();
    await boot05f(t, stage05g(rig2, catalog, ghostStore: store));
    await t.tap(find.byKey(const Key('stage-shelf-toggle')));
    await t.pump();
    await t.pump();
    await t.ensureVisible(find.byKey(const Key('stage-help-row')));
    await t.pump();
    await t.tap(find.byKey(const Key('stage-help-row')));
    await t.pump();
    await t.pump();
    expect(find.byKey(const Key('ghost-suggestion')), findsOneWidget);
    expect(find.byKey(const Key('ghost-item-label')), findsOneWidget);
    await dispose05f(t, rig2);
  });
}
