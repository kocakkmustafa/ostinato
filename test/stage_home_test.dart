// OST-UX-05b — stage shell and root change (flag closed by default), opaque
// tool shelf, pinned metronome, back behaviour. Criteria 1..7 of
// docs/yula-execution/design/04-backlog-ux-05.md (UX-05b).
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/account_connection.dart';
import 'package:ostinato/app/app_locale.dart';
import 'package:ostinato/app/app_message_ids.dart';
import 'package:ostinato/app/audio/audio_capture_channel.dart';
import 'package:ostinato/app/audio/audio_input_controller.dart';
import 'package:ostinato/app/content.dart';
import 'package:ostinato/app/cue_text.dart';
import 'package:ostinato/app/curriculum/v1_lesson.dart';
import 'package:ostinato/app/design/app_scope.dart';
import 'package:ostinato/app/design/glass_layer.dart';
import 'package:ostinato/app/onboarding_store.dart';
import 'package:ostinato/app/ostinato_release_policy.dart';
import 'package:ostinato/app/practice/loop/practice_judge.dart';
import 'package:ostinato/app/practice/loop/practice_loop_screen.dart';
import 'package:ostinato/app/practice/loop/practice_marks.dart';
import 'package:ostinato/app/practice/loop/practice_outcome.dart';
import 'package:ostinato/app/practice/loop/practice_progress_store.dart';
import 'package:ostinato/app/practice/loop/practice_result_screen.dart';
import 'package:ostinato/app/practice/loop/practice_score.dart';
import 'package:ostinato/app/practice/loop/practice_session_controller.dart';
import 'package:ostinato/app/practice/loop/practice_transport.dart';
import 'package:ostinato/app/practice/loop/v1_course_catalog.dart';
import 'package:ostinato/app/screens/library_screen.dart';
import 'package:ostinato/app/course_access.dart';
import 'package:ostinato/app/practice/loop/reference_listen.dart';
import 'package:ostinato/app/practice/loop/reference_listen_bar.dart';
import 'package:ostinato/app/retention/weekly_goal.dart';
import 'package:ostinato/app/stage/stage_copy.dart';
import 'package:ostinato/app/ui_copy.dart';
import 'package:ostinato/app/stage/stage_layers.dart';
import 'package:ostinato/app/design/app_scope.dart' as scope;
import 'package:ostinato/app/screens/coming_soon_instrument_screen.dart';
import 'package:ostinato/app/stage/tool_shelf.dart';
import 'package:ostinato/app/tuner/session_tuning_gate.dart';
import 'package:ostinato/app/stage/stage_home_screen.dart';
import 'package:ostinato/main.dart';
import 'package:permission_handler/permission_handler.dart';

import 'support/localized_widget_ready.dart';
import 'support/practice_host.dart';

final class _Memory implements V1PracticeProgress {
  _Memory([Map<String, V1PracticeRecord>? seed]) : records = {...?seed};
  final Map<String, V1PracticeRecord> records;
  int recordCalls = 0;
  int loadCalls = 0;

  /// 1-based load() calls that throw (a read failure).
  final Set<int> failLoadCalls = {};
  @override
  Future<Map<String, V1PracticeRecord>> load() async {
    loadCalls++;
    if (failLoadCalls.contains(loadCalls)) throw StateError('read failed');
    return Map.of(records);
  }

  @override
  Future<V1PracticeRecord> recordRun(
    String id,
    PracticeRunSummary s, {
    DateTime? at,
  }) async {
    recordCalls++;
    return records[id] = (records[id] ?? V1PracticeRecord(lessonId: id))
        .withRun(s, DateTime.utc(2026, 11, 1));
  }
}

final class _ChecksWith implements V1LessonChecks {
  _ChecksWith(this.checks);
  final Map<String, V1LessonCheck> checks;
  @override
  Future<Map<String, V1LessonCheck>> load() async => checks;
  @override
  Future<V1LessonCheck> record(
    String lessonId,
    V1CheckEvidence evidence, {
    DateTime? at,
  }) => throw UnimplementedError();
}

final class _Checks implements V1LessonChecks {
  @override
  Future<Map<String, V1LessonCheck>> load() async => {};
  @override
  Future<V1LessonCheck> record(
    String lessonId,
    V1CheckEvidence evidence, {
    DateTime? at,
  }) => throw UnimplementedError();
}

V1CourseCatalog _catalog() {
  final lessons = [
    for (final f
        in Directory('content/v1/gtr').listSync().whereType<File>().toList()
          ..sort((a, b) => a.path.compareTo(b.path)))
      if (f.path.endsWith('.json'))
        V1Lesson.fromJson(jsonDecode(f.readAsStringSync())),
  ];
  return V1CourseCatalog(lessons);
}

/// Expected pick of the stage for [records] (same rule, computed here).
V1CourseLesson _expected(
  V1CourseCatalog catalog,
  Map<String, V1PracticeRecord> records,
) {
  final state = V1CourseState(catalog, records, const {});
  final next = state.next;
  if (next != null && next.availability == V1LessonAvailability.measured) {
    return next;
  }
  return catalog.lessons.firstWhere(
    (l) =>
        l.availability == V1LessonAvailability.measured &&
        state.isOpen(l.id) &&
        !state.isDone(l),
  );
}

class _Rig {
  _Rig({this.permission = PermissionStatus.granted}) {
    audio = AudioInputController(
      channel: channel,
      requestMicrophonePermission: () async {
        permissionCalls++;
        return permission;
      },
      pcmDeliveryTimeout: const Duration(minutes: 5),
    );
  }
  final PermissionStatus permission;
  final channel = FakeAudioCaptureChannel();
  late final AudioInputController audio;
  int permissionCalls = 0;
  PracticeSessionController? controller;
  var local = 0;

  PracticeSessionController factory(
    PracticeScore score,
    PracticeTempo tempo,
    PassCriteria criteria,
  ) => controller = PracticeSessionController(
    score: score,
    tempo: tempo,
    audio: audio,
    criteria: criteria,
    localClockUs: () => local,
    analyzer: (r) async => judgeNote(r),
  );
}

/// Promise / future wording and "wrong", in en, tr and the 12 other locales
/// (plain substrings, case-insensitive; the stage values are short).
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
    'encore',
    'bientôt',
    'pronto',
    'presto',
    'bald',
    'skoro',
    'segera',
    'जल्द',
    '即将',
    '곧',
    'まもなく',
  ].join('|'),
  caseSensitive: false,
);

late V1CourseCatalog catalog;

Widget _stage(
  _Rig rig, {
  _Memory? progress,
  GlassLayerBudget? budget,
  void Function(BuildContext, StageHandle)? onHandle,
  StageLayerBuilder? layerBuilder,
  String locale = 'tr',
  bool paidFeaturesAvailable = false,
  Future<bool> Function()? paidAccessCheck,
  StageLayerManager? layerManager,
  WidgetBuilder? earScreenBuilder,
  Future<void> Function(BuildContext)? tunerOpener,
  Widget Function(Widget)? wrap,
  Future<WeeklyGoalStatus?> Function()? weeklyGoalLoader,
}) => practiceHost(
  locale: locale,
  (wrap ?? (w) => w)(
    StageHomeScreen(
      layerManager: layerManager,
      earScreenBuilder: earScreenBuilder,
      tunerOpener: tunerOpener,
      weeklyGoalLoader: weeklyGoalLoader,
      catalog: catalog,
      progressFactory: (_) => progress ?? _Memory(),
      checksFactory: (_) => _Checks(),
      controllerFactory: rig.factory,
      paidFeaturesAvailable: paidFeaturesAvailable,
      paidAccessCheck: paidAccessCheck,
      budget: budget,
      onHandle: onHandle,
      layerBuilder: layerBuilder,
      seed: 1,
    ),
  ),
);

Future<void> _boot(WidgetTester t, Widget w) async {
  t.view.physicalSize = const Size(420, 1800);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(w);
  await t.pump();
  await t.pump();
  await t.pump();
}

Future<void> _play(WidgetTester t) async {
  await t.tap(find.byKey(const Key('practice-start')));
  await t.pump();
  await t.pump();
}

Future<void> _dispose(WidgetTester t, _Rig rig) async {
  await t.pumpWidget(const SizedBox());
  await t.runAsync(rig.audio.dispose);
}

void main() {
  setUpAll(() {
    catalog = _catalog();
  });
  setUp(resetAudioCaptureCoordinatorForTest);

  group('olcut1 flag closed', () {
    late ContentRepository repo;
    late CueTextResolver cueText;
    setUpAll(() async {
      await prepareRootTranslations();
      repo = await ContentRepository.load();
      cueText = await CueTextResolver.load();
    });

    Widget home({bool? open, bool onboarded = true}) => ContentRepositoryScope(
      repo: repo,
      cueText: cueText,
      child: MaterialApp(
        locale: const Locale('en'),
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationsDelegates,
        home: open == null
            ? OstinatoHome(
                repo: repo,
                cueText: cueText,
                store: InMemoryOnboardingStore(),
                alreadyOnboarded: onboarded,
              )
            : OstinatoHome(
                repo: repo,
                cueText: cueText,
                store: InMemoryOnboardingStore(),
                alreadyOnboarded: onboarded,
                stageHomeOpen: open,
                stageHomeBuilder: (_) => const Text('stage-stub'),
              ),
      ),
    );

    Future<void> ready(WidgetTester t, Finder anchor) =>
        waitForLocalizedFixture(
          t,
          languageTag: 'en',
          anchor: anchor,
          reason: 'root',
        );

    testWidgets('the flag ships closed', (t) async {
      expect(ostinatoStageHomeEnabled, isFalse);
    });

    testWidgets('default (flag closed): the root is the library', (t) async {
      await t.pumpWidget(home());
      await ready(t, find.byType(LibraryScreen));
      expect(find.byType(LibraryScreen), findsOneWidget);
      expect(find.byType(StageHomeScreen), findsNothing);
      expect(find.byKey(const Key('stage-shelf')), findsNothing);
      expect(find.byKey(const Key('stage-pinned-metronome')), findsNothing);
    });

    testWidgets('stageHomeOpen:false gives the library, no stage', (t) async {
      await t.pumpWidget(home(open: false));
      await ready(t, find.byType(LibraryScreen));
      expect(find.byType(LibraryScreen), findsOneWidget);
      expect(find.text('stage-stub'), findsNothing);
    });

    testWidgets('stageHomeOpen:true after the welcome: the stage', (t) async {
      await t.pumpWidget(home(open: true));
      await ready(t, find.text('stage-stub'));
      expect(find.text('stage-stub'), findsOneWidget);
      expect(find.byType(LibraryScreen), findsNothing);
    });

    testWidgets('stageHomeOpen:true before the welcome: still the welcome', (
      t,
    ) async {
      await t.pumpWidget(home(open: true, onboarded: false));
      await t.pump();
      expect(find.text('stage-stub'), findsNothing);
      expect(find.byType(LibraryScreen), findsNothing);
    });
  });

  group('olcut2 stage content', () {
    testWidgets('new user: next lesson, one Play, "just starting" line', (
      t,
    ) async {
      final rig = _Rig();
      await _boot(t, _stage(rig));
      final want = _expected(catalog, {});
      expect(find.byKey(const Key('stage-home')), findsOneWidget);
      expect(
        find.text(
          want.lesson.title.of(t.element(find.byType(StageHomeScreen))),
        ),
        findsWidgets,
      );
      expect(find.byKey(const Key('stage-headline')), findsOneWidget);
      expect(find.text(StageCopy.justStarting.$2), findsOneWidget);
      // One Play: a single start control, labelled "Çal".
      expect(find.byKey(const Key('practice-start')), findsOneWidget);
      expect(find.text('Çal'), findsOneWidget);
      expect(find.text('Başlat'), findsNothing);
      await _dispose(t, rig);
    });

    testWidgets('returning user: the continue line, the lesson after records', (
      t,
    ) async {
      final first = _expected(catalog, {});
      final done = V1PracticeRecord(
        lessonId: first.id,
        runs: 3,
        passedAt: DateTime.utc(2026, 11, 1),
        passedBpm: 50,
        completedAt: DateTime.utc(2026, 11, 1),
        completedBpm: 60,
      );
      final records = {first.id: done};
      final rig = _Rig();
      await _boot(t, _stage(rig, progress: _Memory(records)));
      final want = _expected(catalog, records);
      expect(want.id, isNot(first.id));
      final unit = catalog.units.firstWhere((u) => u.id == want.unitId);
      expect(
        find.text('Devam: ${unit.level}. seviye, ${unit.module}. modül'),
        findsOneWidget,
      );
      expect(find.text(StageCopy.justStarting.$2), findsNothing);
      expect(find.byKey(const Key('practice-start')), findsOneWidget);
      await _dispose(t, rig);
    });

    testWidgets('no usable next lesson: the first measured lesson', (t) async {
      // Every lesson done: `next` is null; the first measured lesson shows.
      final all = {
        for (final l in catalog.lessons)
          l.id: V1PracticeRecord(
            lessonId: l.id,
            runs: 1,
            passedAt: DateTime.utc(2026, 11, 1),
            passedBpm: 50,
            completedAt: DateTime.utc(2026, 11, 1),
            completedBpm: 60,
          ),
      };
      final state = V1CourseState(catalog, all, const {});
      final firstMeasured = catalog.lessons.firstWhere(
        (l) => l.availability == V1LessonAvailability.measured,
      );
      final rig = _Rig();
      await _boot(t, _stage(rig, progress: _Memory(all)));
      if (state.next == null) {
        final shown = t
            .widget<PracticeLoopScreen>(find.byType(PracticeLoopScreen))
            .lesson
            .id;
        expect(shown, firstMeasured.id);
      }
      expect(find.byKey(const Key('practice-start')), findsOneWidget);
      await _dispose(t, rig);
    });

    testWidgets('three text-labelled handles at 48 dp, shared copy', (t) async {
      final rig = _Rig();
      await _boot(t, _stage(rig));
      for (final (key, label) in [
        ('stage-handle-other', 'Başka çalış'),
        ('stage-handle-path', 'Yolum'),
        ('stage-handle-setup', 'Ayar'),
      ]) {
        final f = find.byKey(Key(key));
        expect(f, findsOneWidget);
        expect(
          find.descendant(of: f, matching: find.text(label)),
          findsOneWidget,
        );
        expect(t.getSize(f).height, greaterThanOrEqualTo(48));
      }
      await _dispose(t, rig);
    });
  });

  group('olcut3 one tap to play, permission at the first Play', () {
    testWidgets('no permission before Play; one request on the first tap', (
      t,
    ) async {
      final rig = _Rig();
      await _boot(t, _stage(rig));
      expect(rig.permissionCalls, 0);
      await _play(t);
      expect(rig.permissionCalls, 1);
      expect(rig.controller!.running, isTrue);
      await _dispose(t, rig);
    });
  });

  group('olcut4 while playing', () {
    testWidgets('handles hidden, no layer can open, budget refuses', (t) async {
      final rig = _Rig();
      final budget = GlassLayerBudget();
      addTearDown(budget.dispose);
      await _boot(
        t,
        _stage(
          rig,
          budget: budget,
          layerBuilder: (c, h, close) => const Text('layer-content'),
        ),
      );
      expect(find.byKey(const Key('stage-handles')), findsOneWidget);
      await _play(t);
      expect(budget.playing, isTrue);
      expect(find.byKey(const Key('stage-handles')), findsNothing);
      expect(find.byKey(const Key('stage-handle-other')), findsNothing);
      expect(budget.tryOpen(Object()), isFalse);
      expect(budget.openCount, 0);
      expect(find.text('layer-content'), findsNothing);
      await _dispose(t, rig);
    });

    testWidgets('handles show and call the injected callback (default no-op)', (
      t,
    ) async {
      final rig = _Rig();
      final seen = <StageHandle>[];
      await _boot(t, _stage(rig, onHandle: (c, h) => seen.add(h)));
      // "Other" (05c) and "path" (05d) open layers that cover the handles:
      // setup first, then path (closed by the scrim), then other.
      await t.tap(find.byKey(const Key('stage-handle-setup')));
      await t.pump();
      await t.tap(find.byKey(const Key('stage-handle-path')));
      await t.pump();
      await t.tap(find.byKey(const Key('stage-layer-scrim')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('stage-handle-other')));
      await t.pump();
      expect(seen.toSet(), StageHandle.values.toSet());
      await _dispose(t, rig);

      final rig2 = _Rig();
      await _boot(t, _stage(rig2)); // no callback, no layer builder
      await t.tap(find.byKey(const Key('stage-handle-other')));
      await t.pump();
      expect(t.takeException(), isNull);
      await _dispose(t, rig2);
    });

    testWidgets('a failed start: the screen does not stop', (t) async {
      final rig = _Rig(permission: PermissionStatus.denied);
      await _boot(t, _stage(rig));
      await _play(t);
      await t.pump(const Duration(milliseconds: 50));
      expect(rig.controller!.phase, PracticePhase.failed);
      expect(find.byKey(const Key('practice-failure')), findsOneWidget);
      expect(find.byKey(const Key('stage-home')), findsOneWidget);
      expect(find.byKey(const Key('practice-start')), findsOneWidget);
      expect(find.byKey(const Key('stage-handles')), findsOneWidget);
      expect(t.takeException(), isNull);
      await _dispose(t, rig);
    });
  });

  group('olcut6 tool shelf', () {
    testWidgets('starts closed; opens opaque with the reused parts', (t) async {
      final rig = _Rig();
      await _boot(t, _stage(rig));
      expect(find.byKey(const Key('stage-shelf')), findsOneWidget);
      expect(find.byKey(const Key('stage-help-row')), findsNothing);
      expect(find.byKey(const Key('stage-pin-metronome')), findsNothing);
      await t.tap(find.byKey(const Key('stage-shelf-toggle')));
      await t.pump();
      for (final k in ['stage-pin-metronome', 'stage-help-row']) {
        expect(find.byKey(Key(k)), findsOneWidget, reason: k);
      }
      expect(find.text('Metronom'), findsOneWidget);
      expect(find.text('Referans'), findsOneWidget);
      expect(find.text('Yardım'), findsOneWidget);
      // Fully opaque: no blur, no glass layer, not in the glass budget.
      final shelf = find.byKey(const Key('stage-shelf'));
      expect(
        find.descendant(of: shelf, matching: find.byType(BackdropFilter)),
        findsNothing,
      );
      expect(
        find.descendant(of: shelf, matching: find.byType(GlassLayer)),
        findsNothing,
      );
      final color = t.widget<Material>(shelf).color!;
      expect(color.a, 1.0);
      // The practice screen is not split: still one start control.
      expect(find.byKey(const Key('practice-start')), findsOneWidget);
      await _dispose(t, rig);
    });

    testWidgets('closed while playing; cannot be opened; closed again after', (
      t,
    ) async {
      final rig = _Rig();
      await _boot(t, _stage(rig));
      await t.tap(find.byKey(const Key('stage-shelf-toggle')));
      await t.pump();
      await _play(t);
      expect(find.byKey(const Key('stage-shelf')), findsNothing);
      expect(find.byKey(const Key('stage-shelf-toggle')), findsNothing);
      await _dispose(t, rig);
    });

    testWidgets('the loop switch drives the session controller', (t) async {
      final rig = _Rig();
      await _boot(t, _stage(rig));
      await t.tap(find.byKey(const Key('stage-shelf-toggle')));
      await t.pump();
      if (rig.controller!.score.barCount > 1) {
        expect(rig.controller!.loopBars, isNull);
        await t.tap(find.byKey(const Key('stage-loop')));
        await t.pump();
        expect(rig.controller!.loopBars, isNotNull);
      }
      await _dispose(t, rig);
    });
  });

  group('olcut6a pinned metronome', () {
    testWidgets('visible while playing, opaque, outside the glass budget', (
      t,
    ) async {
      final rig = _Rig();
      final budget = GlassLayerBudget();
      addTearDown(budget.dispose);
      await _boot(t, _stage(rig, budget: budget));
      expect(find.byKey(const Key('stage-pinned-metronome')), findsNothing);
      await t.tap(find.byKey(const Key('stage-shelf-toggle')));
      await t.pump();
      await t.tap(find.byKey(const Key('stage-pin-metronome')));
      await t.pump();
      final before = budget.openCount;
      await _play(t);
      final pinned = find.byKey(const Key('stage-pinned-metronome'));
      expect(pinned, findsOneWidget);
      expect(t.widget<Material>(pinned).color!.a, 1.0);
      expect(
        find.descendant(of: pinned, matching: find.byType(BackdropFilter)),
        findsNothing,
      );
      expect(budget.openCount, before);
      expect(budget.openCount, 0);
      await _dispose(t, rig);
    });

    testWidgets('not pinned: no metronome strip while playing', (t) async {
      final rig = _Rig();
      await _boot(t, _stage(rig));
      await _play(t);
      expect(find.byKey(const Key('stage-pinned-metronome')), findsNothing);
      await _dispose(t, rig);
    });
  });

  group('olcut7 back', () {
    testWidgets('a layer is open: back closes the layer, stage stays', (
      t,
    ) async {
      final rig = _Rig();
      final budget = GlassLayerBudget();
      addTearDown(budget.dispose);
      await _boot(
        t,
        _stage(
          rig,
          budget: budget,
          layerBuilder: (c, h, close) => const Text('layer-content'),
        ),
      );
      await t.tap(find.byKey(const Key('stage-handle-other')));
      await t.pump();
      await t.pump();
      expect(find.text('layer-content'), findsOneWidget);
      expect(budget.openCount, 1);
      await t.binding.handlePopRoute();
      await t.pump();
      await t.pump();
      expect(find.text('layer-content'), findsNothing);
      expect(budget.openCount, 0);
      expect(find.byKey(const Key('stage-home')), findsOneWidget);
      await _dispose(t, rig);
    });

    testWidgets('an exit screen: back returns to the stage', (t) async {
      final rig = _Rig();
      await _boot(
        t,
        _stage(
          rig,
          onHandle: (context, h) => Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) => const Scaffold(body: Text('exit-screen')),
            ),
          ),
        ),
      );
      await t.tap(find.byKey(const Key('stage-handle-setup')));
      await t.pumpAndSettle();
      expect(find.text('exit-screen'), findsOneWidget);
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(find.text('exit-screen'), findsNothing);
      expect(find.byKey(const Key('stage-home')), findsOneWidget);
      expect(find.byKey(const Key('practice-start')), findsOneWidget);
      await _dispose(t, rig);
    });

    testWidgets('leaving a half run: says not measured, records nothing', (
      t,
    ) async {
      final rig = _Rig();
      final progress = _Memory();
      await _boot(t, _stage(rig, progress: progress));
      final before = (await progress.load()).length;
      await _play(t);
      expect(rig.controller!.running, isTrue);
      await t.binding.handlePopRoute();
      await t.pump();
      await t.pump();
      expect(find.byKey(const Key('stage-run-not-completed')), findsOneWidget);
      expect(find.text(StageCopy.runNotCompleted.$2), findsOneWidget);
      expect(progress.recordCalls, 0);
      expect((await progress.load()).length, before);
      // The stage is idle again: handles and a fresh Play.
      expect(find.byKey(const Key('stage-handles')), findsOneWidget);
      expect(find.byKey(const Key('practice-start')), findsOneWidget);
      await t.pump(const Duration(seconds: 1));
      expect(progress.recordCalls, 0);
      expect(t.takeException(), isNull);
      await _dispose(t, rig);
    });
  });

  group('olcut7 half run with outcomes', () {
    testWidgets('outcomes exist, back leaves: not measured, nothing recorded', (
      t,
    ) async {
      final rig = _Rig();
      final progress = _Memory();
      await _boot(t, _stage(rig, progress: progress));
      final before = (await progress.load()).length;
      await _play(t);
      final c = rig.controller!;
      final rng = math.Random(1);
      var tn = 0;
      for (var i = 0; i < 400 && c.outcomes.isEmpty; i++) {
        final x = Float64List(4800);
        for (var k = 0; k < x.length; k++) {
          x[k] = (rng.nextDouble() * 2 - 1) * .002;
        }
        rig.channel.pushChunk(x, sampleRate: 48000, tNativeUs: tn);
        tn += 100000;
        rig.local = tn;
        await t.pump();
        if (rig.channel.metronome != null && c.timeline == null) {
          rig.channel.pushMetronomeAnchor(tn + 200000);
          await t.pump();
        }
        c.tick();
        await t.pump();
      }
      expect(c.outcomes, isNotEmpty, reason: 'a result was produced');
      expect(c.phase, PracticePhase.running, reason: 'run is still half-way');
      await t.binding.handlePopRoute();
      await t.pump();
      await t.pump();
      expect(find.byKey(const Key('stage-run-not-completed')), findsOneWidget);
      expect(find.text(StageCopy.runNotCompleted.$2), findsOneWidget);
      await t.pump(const Duration(seconds: 1));
      expect(progress.recordCalls, 0);
      expect((await progress.load()).length, before);
      expect(find.byType(PracticeResultScreen), findsNothing);
      expect(t.takeException(), isNull);
      await _dispose(t, rig);
    });
  });

  group('olcut5 copy and l10n', () {
    test('every stage pair has a message id', () {
      for (final p in StageCopy.all) {
        expect(appMessageIds.containsKey(p), isTrue, reason: '$p');
      }
    });

    test('the promise regex really catches the forbidden words', () {
      for (final w in [
        'Putaran belum selesai',
        'अभी शुरुआत है',
        'Ainda não',
        'Non ancora',
        'Noch nicht',
        'Aún no',
        'まだ',
        '아직',
        'Jeszcze nie',
        '还没有',
        'ليس بعد',
        "Pas pour l'instant",
        'Encore',
        'Bientôt',
        'Pronto',
        'Presto',
        'Bald',
        'Skoro',
        'Segera',
        'जल्द',
        '即将',
        '곧',
        'まもなく',
        'coming soon',
        'not yet',
        'henüz',
        'yakında',
        'wrong',
        'yanlış',
      ]) {
        expect(_promise.hasMatch(w), isTrue, reason: w);
      }
      for (final ok in ['Metronom', 'Araçlar', 'Je débute', 'Tools']) {
        expect(_promise.hasMatch(ok), isFalse, reason: ok);
      }
    });

    test('the new pairs are in all 14 catalogs and promise nothing', () {
      for (final f in Directory('assets/l10n').listSync()) {
        if (f is! File || !f.path.endsWith('.json')) continue;
        final messages =
            (jsonDecode(f.readAsStringSync()) as Map)['messages'] as Map;
        for (final p in StageCopy.newPairs) {
          final id = appMessageIds[p]!;
          final text = messages[id] as String?;
          expect(text, isNotNull, reason: '${f.path} $id');
          expect(text, isNotEmpty);
          expect(_promise.hasMatch(text!), isFalse, reason: '${f.path} $text');
          if (!f.path.endsWith('/en.json') && !f.path.endsWith('/tr.json')) {
            // A real translation: not the English source copied over
            // (short loanwords such as "Metronom" may coincide).
            if (p.$1.length > 12) expect(text, isNot(p.$1), reason: f.path);
          }
        }
      }
    });
  });

  group('05b2 open points (a)(b)(e)', () {
    // Every lesson before the first measured paid one is passed: `next` is
    // that paid lesson (level 2 or later).
    Map<String, V1PracticeRecord> level1Done() {
      final firstPaid = catalog.lessons.firstWhere(
        (l) =>
            l.availability == V1LessonAvailability.measured &&
            !isFreeV1Lesson(l.id, paidFeaturesAvailable: true),
      );
      final upTo = catalog.lessons.indexOf(firstPaid);
      return {
        for (final l in catalog.lessons.take(upTo))
          l.id: V1PracticeRecord(
            lessonId: l.id,
            runs: 1,
            passedAt: DateTime.utc(2026, 11, 1),
            passedBpm: 50,
            completedAt: DateTime.utc(2026, 11, 1),
            completedBpm: 60,
          ),
      };
    }

    String shown(WidgetTester t) =>
        t.widget<PracticeLoopScreen>(find.byType(PracticeLoopScreen)).lesson.id;

    testWidgets('(a) member: the paid next lesson (s2+) is shown', (t) async {
      final records = level1Done();
      final next = V1CourseState(catalog, records, const {}).next!;
      expect(next.id, startsWith('gtr-s2-'));
      expect(next.availability, V1LessonAvailability.measured);
      expect(isFreeV1Lesson(next.id, paidFeaturesAvailable: true), isFalse);
      final rig = _Rig();
      await _boot(
        t,
        _stage(
          rig,
          progress: _Memory(records),
          paidFeaturesAvailable: true,
          paidAccessCheck: () async => true,
        ),
      );
      expect(shown(t), next.id);
      await _dispose(t, rig);
    });

    testWidgets('(a) free user: the paid next lesson is NOT shown', (t) async {
      final records = level1Done();
      final next = V1CourseState(catalog, records, const {}).next!;
      final rig = _Rig();
      await _boot(
        t,
        _stage(
          rig,
          progress: _Memory(records),
          paidFeaturesAvailable: true,
          paidAccessCheck: () async => false,
        ),
      );
      expect(shown(t), isNot(next.id));
      expect(
        isFreeV1Lesson(shown(t), paidFeaturesAvailable: true),
        isTrue,
        reason: 'safe fallback stays a free measured lesson',
      );
      await _dispose(t, rig);
    });

    testWidgets('(a) a check that throws: not a member, free lesson', (
      t,
    ) async {
      final records = level1Done();
      final next = V1CourseState(catalog, records, const {}).next!;
      final rig = _Rig();
      await _boot(
        t,
        _stage(
          rig,
          progress: _Memory(records),
          paidFeaturesAvailable: true,
          paidAccessCheck: () => throw StateError('boom'),
        ),
      );
      expect(shown(t), isNot(next.id));
      expect(isFreeV1Lesson(shown(t), paidFeaturesAvailable: true), isTrue);
      await _dispose(t, rig);
    });

    testWidgets('(a) a check that hangs: after the timeout the free lesson '
        'shows and Play works', (t) async {
      final records = level1Done();
      final next = V1CourseState(catalog, records, const {}).next!;
      final rig = _Rig();
      final hang = Completer<bool>();
      t.view.physicalSize = const Size(420, 1800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(
        _stage(
          rig,
          progress: _Memory(records),
          paidFeaturesAvailable: true,
          paidAccessCheck: () => hang.future,
        ),
      );
      await t.pump();
      await t.pump();
      expect(find.byType(PracticeLoopScreen), findsNothing);
      expect(find.byKey(const Key('stage-play-pending')), findsOneWidget);
      await t.pump(stagePaidCheckTimeout + const Duration(seconds: 1));
      await t.pump();
      await t.pump();
      expect(shown(t), isNot(next.id));
      expect(isFreeV1Lesson(shown(t), paidFeaturesAvailable: true), isTrue);
      await _play(t);
      expect(rig.controller!.running, isTrue);
      await _dispose(t, rig);
    });

    testWidgets('(a) the account connection (AccountScope) is the default '
        'check', (t) async {
      final records = level1Done();
      final next = V1CourseState(catalog, records, const {}).next!;
      for (final member in <bool>[true, false]) {
        final rig = _Rig();
        await _boot(
          t,
          AccountScope(
            currentUserId: 'u1',
            connection: AccountConnection(
              userId: ValueNotifier<String?>('u1'),
              pageBuilder: (_) => const SizedBox(),
              hasPaidAccess: () async => member,
            ),
            child: _stage(
              rig,
              progress: _Memory(records),
              paidFeaturesAvailable: true,
            ),
          ),
        );
        expect(shown(t) == next.id, member);
        await _dispose(t, rig);
      }
    });

    testWidgets('(a) no access check wired: treated as free', (t) async {
      final records = level1Done();
      final next = V1CourseState(catalog, records, const {}).next!;
      final rig = _Rig();
      await _boot(
        t,
        _stage(rig, progress: _Memory(records), paidFeaturesAvailable: true),
      );
      expect(shown(t), isNot(next.id));
      await _dispose(t, rig);
    });

    // (b) Play on the first screen, shelf closed and open.
    for (final c in <(String, Size, double)>[
      ('390x844', const Size(390, 844), 1.0),
      ('360x640', const Size(360, 640), 1.0),
      ('360x640 text 1.3', const Size(360, 640), 1.3),
    ]) {
      for (final open in <bool>[false, true]) {
        testWidgets(
          '(b) Play visible and tappable: ${c.$1}, shelf ${open ? 'open' : 'closed'}',
          (t) async {
            final rig = _Rig();
            t.view.physicalSize = c.$2;
            t.view.devicePixelRatio = 1;
            t.platformDispatcher.textScaleFactorTestValue = c.$3;
            addTearDown(t.view.resetPhysicalSize);
            addTearDown(t.view.resetDevicePixelRatio);
            addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
            await t.pumpWidget(_stage(rig));
            await t.pump();
            await t.pump();
            await t.pump();
            if (open) {
              await t.tap(find.byKey(const Key('stage-shelf-toggle')));
              await t.pump();
              await t.pump();
              expect(find.byKey(const Key('stage-help-row')), findsOneWidget);
            }
            final start = find.byKey(const Key('practice-start'));
            expect(start, findsOneWidget);
            final r = t.getRect(start);
            final screen = Offset.zero & c.$2;
            expect(screen.contains(r.topLeft), isTrue, reason: '$r');
            expect(screen.contains(r.bottomRight), isTrue, reason: '$r');
            expect(r.height, greaterThanOrEqualTo(48));
            expect(start.hitTestable(), findsOneWidget);
            final ex = t.takeException();
            expect(
              ex,
              isNull,
              reason: ex is FlutterError ? ex.toStringDeep() : '$ex',
            );
            await _play(t);
            expect(rig.controller!.running, isTrue);
            expect(t.takeException(), isNull);
            await _dispose(t, rig);
          },
        );
      }
    }

    testWidgets('(e) half run, back: the tuning card does not return', (
      t,
    ) async {
      final rig = _Rig();
      await _boot(t, _stage(rig));
      expect(find.byType(SessionTuningGateCard), findsOneWidget);
      await _play(t);
      await t.binding.handlePopRoute();
      await t.pump();
      await t.pump();
      expect(find.byKey(const Key('stage-run-not-completed')), findsOneWidget);
      expect(find.byKey(const Key('practice-start')), findsOneWidget);
      expect(find.byType(SessionTuningGateCard), findsNothing);
      expect(t.takeException(), isNull);
      await _dispose(t, rig);
    });
  });

  group('05c ek i: Play re-verifies the membership', () {
    Map<String, V1PracticeRecord> level1Done() {
      final firstPaid = catalog.lessons.firstWhere(
        (l) =>
            l.availability == V1LessonAvailability.measured &&
            !isFreeV1Lesson(l.id, paidFeaturesAvailable: true),
      );
      final upTo = catalog.lessons.indexOf(firstPaid);
      return {
        for (final l in catalog.lessons.take(upTo))
          l.id: V1PracticeRecord(
            lessonId: l.id,
            runs: 1,
            passedAt: DateTime.utc(2026, 11, 1),
            passedBpm: 50,
            completedAt: DateTime.utc(2026, 11, 1),
            completedBpm: 60,
          ),
      };
    }

    Widget scoped(
      _Rig rig,
      Map<String, V1PracticeRecord> records,
      Future<bool> Function(BuildContext) guard, {
      Future<bool> Function()? hasPaid,
    }) => AccountScope(
      currentUserId: 'u1',
      connection: AccountConnection(
        userId: ValueNotifier<String?>('u1'),
        pageBuilder: (_) => const SizedBox(),
        hasPaidAccess: hasPaid ?? () async => true,
        requirePaidAccess: guard,
      ),
      child: _stage(
        rig,
        progress: _Memory(records),
        paidFeaturesAvailable: true,
      ),
    );

    testWidgets('membership ended mid-session: Play does not start a paid '
        'lesson', (t) async {
      final rig = _Rig();
      var asked = 0;
      await _boot(
        t,
        scoped(rig, level1Done(), (_) async {
          asked++;
          return false;
        }),
      );
      expect(
        isFreeV1Lesson(
          t
              .widget<PracticeLoopScreen>(find.byType(PracticeLoopScreen))
              .lesson
              .id,
          paidFeaturesAvailable: true,
        ),
        isFalse,
      );
      await _play(t);
      await t.pump();
      expect(asked, 1);
      expect(rig.controller?.running ?? false, isFalse);
      expect(rig.permissionCalls, 0);
      await _dispose(t, rig);
    });

    testWidgets('a member: Play starts', (t) async {
      final rig = _Rig();
      var asked = 0;
      await _boot(
        t,
        scoped(rig, level1Done(), (_) async {
          asked++;
          return true;
        }),
      );
      await _play(t);
      await t.pump();
      expect(asked, 1);
      expect(rig.controller!.running, isTrue);
      await _dispose(t, rig);
    });

    testWidgets('a guard that throws: fail closed', (t) async {
      final rig = _Rig();
      await _boot(
        t,
        scoped(rig, level1Done(), (_) async => throw StateError('boom')),
      );
      await _play(t);
      await t.pump();
      expect(rig.controller?.running ?? false, isFalse);
      expect(t.takeException(), isNull);
      await _dispose(t, rig);
    });

    testWidgets('two quick taps on Play: one guard, one start', (t) async {
      final rig = _Rig();
      var asked = 0;
      final gate = Completer<bool>();
      await _boot(
        t,
        scoped(rig, level1Done(), (_) {
          asked++;
          return gate.future;
        }),
      );
      await t.tap(find.byKey(const Key('practice-start')));
      await t.tap(find.byKey(const Key('practice-start')), warnIfMissed: false);
      await t.pump();
      gate.complete(true);
      await t.pump();
      await t.pump();
      expect(asked, 1);
      expect(rig.permissionCalls, 1);
      expect(rig.controller!.running, isTrue);
      await _dispose(t, rig);
    });

    // 05d ek A: the guard's flags and honest state.
    testWidgets('A(a) a refused guard resets _starting: the second Play asks '
        'again, no notice for a refusal', (t) async {
      final rig = _Rig();
      var asked = 0;
      await _boot(
        t,
        scoped(rig, level1Done(), (_) async {
          asked++;
          return false;
        }),
      );
      await _play(t);
      await t.pump();
      expect(asked, 1);
      await _play(t);
      await t.pump();
      expect(asked, 2);
      expect(find.byKey(const Key('stage-start-unverified')), findsNothing);
      expect(rig.controller?.running ?? false, isFalse);
      await _dispose(t, rig);
    });

    testWidgets('A(a) a guard that threw: notice shows, the next Play asks '
        'again, starts, notice gone', (t) async {
      final rig = _Rig();
      var asked = 0;
      await _boot(
        t,
        scoped(rig, level1Done(), (_) async {
          asked++;
          if (asked == 1) throw StateError('boom');
          return true;
        }),
      );
      await _play(t);
      await t.pump();
      expect(asked, 1);
      expect(find.byKey(const Key('stage-start-unverified')), findsOneWidget);
      expect(find.text(StageCopy.startNotVerified.$2), findsOneWidget);
      expect(rig.controller?.running ?? false, isFalse);
      await _play(t);
      for (var i = 0; i < 4; i++) {
        await t.pump();
      }
      expect(asked, 2);
      expect(rig.controller!.running, isTrue);
      expect(find.byKey(const Key('stage-start-unverified')), findsNothing);
      await _dispose(t, rig);
    });

    testWidgets('A(b) the membership read hangs: after 4 s Play stays '
        'closed, the notice shows, the membership page is never pushed', (
      t,
    ) async {
      final rig = _Rig();
      var asked = 0;
      final hang = Completer<bool>();
      var reads = 0; // the first read picks the paid lesson at load
      await _boot(
        t,
        scoped(rig, level1Done(), (_) async {
          asked++;
          return true;
        }, hasPaid: () => reads++ == 0 ? Future.value(true) : hang.future),
      );
      await _play(t);
      await t.pump(const Duration(seconds: 3));
      expect(find.byKey(const Key('stage-start-unverified')), findsNothing);
      await t.pump(const Duration(seconds: 2));
      expect(find.byKey(const Key('stage-start-unverified')), findsOneWidget);
      expect(asked, 0);
      expect(rig.controller?.running ?? false, isFalse);
      expect(rig.permissionCalls, 0);
      await _dispose(t, rig);
    });

    testWidgets('A(b) the membership read throws: fail closed, notice', (
      t,
    ) async {
      final rig = _Rig();
      var reads = 0;
      await _boot(
        t,
        scoped(
          rig,
          level1Done(),
          (_) async => true,
          hasPaid: () =>
              reads++ == 0 ? Future.value(true) : throw StateError('net'),
        ),
      );
      await _play(t);
      await t.pump();
      expect(find.byKey(const Key('stage-start-unverified')), findsOneWidget);
      expect(rig.controller?.running ?? false, isFalse);
      await _dispose(t, rig);
    });

    testWidgets('A(b) the membership PAGE is never timed out: a slow '
        'requirePaidAccess still admits', (t) async {
      final rig = _Rig();
      final page = Completer<bool>();
      await _boot(t, scoped(rig, level1Done(), (_) => page.future));
      await _play(t);
      await t.pump(const Duration(seconds: 30));
      expect(find.byKey(const Key('stage-start-unverified')), findsNothing);
      page.complete(true);
      await t.pump();
      await t.pump();
      expect(rig.controller!.running, isTrue);
      await _dispose(t, rig);
    });

    testWidgets('A(b) a free lesson: no guard, no notice', (t) async {
      final rig = _Rig();
      await _boot(
        t,
        scoped(
          rig,
          const {},
          (_) async => throw StateError('never'),
          hasPaid: () => throw StateError('never'),
        ),
      );
      await _play(t);
      expect(find.byKey(const Key('stage-start-unverified')), findsNothing);
      expect(rig.controller!.running, isTrue);
      await _dispose(t, rig);
    });

    testWidgets('a free lesson: no extra question, no delay', (t) async {
      final rig = _Rig();
      var asked = 0;
      await _boot(
        t,
        scoped(rig, const {}, (_) async {
          asked++;
          return false;
        }),
      );
      await _play(t);
      expect(asked, 0);
      expect(rig.controller!.running, isTrue);
      await _dispose(t, rig);
    });
  });

  group('05c ek c: reference bar and loop range on the shelf', () {
    Future<void> shelf(WidgetTester t, String sequence, _Rig rig) async {
      final c = rig.factory(
        PracticeScore.parse(sequence),
        PracticeTempo(openBpm: 60, targetBpm: 60),
        const PassCriteria(minAccuracy: .8),
      );
      final listen = ReferenceListenController();
      addTearDown(listen.dispose);
      await _boot(
        t,
        practiceHost(
          Scaffold(
            body: SingleChildScrollView(
              child: ToolShelf(
                open: true,
                onToggle: () {},
                controller: c,
                listen: listen,
                pinned: false,
                onPinned: (_) {},
              ),
            ),
          ),
          locale: 'tr',
        ),
      );
    }

    testWidgets('pitched line: the reference bar is shown', (t) async {
      final rig = _Rig();
      await shelf(t, 'E2 F2 G2 A2 | B2 C3 D3 E3', rig);
      expect(find.byType(ReferenceListenBar), findsOneWidget);
      await _dispose(t, rig);
    });

    testWidgets('rhythm-only line: the reference bar is shown', (t) async {
      final rig = _Rig();
      await shelf(t, '4/4: q q ee q | h h', rig);
      expect(find.byType(ReferenceListenBar), findsOneWidget);
      await _dispose(t, rig);
    });

    testWidgets('degree run (no pitches, not rhythm-only): no reference bar '
        'and no empty "Referans" row', (t) async {
      final rig = _Rig();
      await shelf(t, '1-2-3-2-1 | 3-2-1-2-3', rig);
      expect(find.byType(ReferenceListenBar), findsNothing);
      expect(find.text('Referans'), findsNothing);
      await _dispose(t, rig);
    });

    testWidgets('loop on: default bars 1-2, a range slider picks the bars', (
      t,
    ) async {
      final rig = _Rig();
      await shelf(t, 'E2 F2 G2 A2 | B2 C3 D3 E3 | E2 F2 G2 A2', rig);
      expect(find.byKey(const Key('stage-loop-range')), findsNothing);
      await t.tap(find.byKey(const Key('stage-loop')));
      await t.pump();
      expect(rig.controller!.loopBars, (first: 0, last: 1));
      final slider = find.byKey(const Key('stage-loop-range'));
      expect(slider, findsOneWidget);
      expect(t.widget<RangeSlider>(slider).values, const RangeValues(0, 1));
      // Spoken as bar numbers (1-based), like the loop switch's subtitle.
      final fmt = t.widget<RangeSlider>(slider).semanticFormatterCallback;
      expect(fmt, isNotNull);
      expect(fmt!(0), '1');
      expect(fmt(2), '3');
      t.widget<RangeSlider>(slider).onChanged!(const RangeValues(1, 2));
      await t.pump();
      expect(rig.controller!.loopBars, (first: 1, last: 2));
      await _dispose(t, rig);
    });
  });

  group('05c layers', () {
    late ContentRepository repo;
    late CueTextResolver cueText;
    setUpAll(() async {
      await prepareRootTranslations();
      repo = await ContentRepository.load();
      cueText = await CueTextResolver.load();
    });

    Widget withRepo(Widget w) =>
        scope.ContentRepositoryScope(repo: repo, cueText: cueText, child: w);

    Future<void> boot(WidgetTester t, Widget w, {Size? size}) async {
      t.view.physicalSize = size ?? const Size(420, 1800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(w);
      for (var i = 0; i < 4; i++) {
        await t.pump();
      }
    }

    Future<void> settle(WidgetTester t) async {
      await t.pumpAndSettle();
    }

    StageLayerBuilder fake() =>
        (c, h, close) => Text('layer-${h.name}', key: Key('layer-${h.name}'));

    testWidgets('criterion 1: a second layer closes the first; glass <= 2', (
      t,
    ) async {
      final rig = _Rig();
      final mgr = StageLayerManager();
      addTearDown(mgr.dispose);
      final budget = GlassLayerBudget();
      addTearDown(budget.dispose);
      await boot(
        t,
        _stage(rig, layerManager: mgr, budget: budget, layerBuilder: fake()),
      );
      expect(mgr.openLayer(StageLayer.other), isTrue);
      await settle(t);
      expect(find.byKey(const Key('layer-another')), findsOneWidget);
      expect(mgr.openLayer(StageLayer.path), isTrue);
      await settle(t);
      expect(mgr.open, [StageLayer.path]);
      expect(find.byKey(const Key('layer-another')), findsNothing);
      expect(find.byKey(const Key('layer-path')), findsOneWidget);
      expect(find.byType(GlassLayer).evaluate().length, lessThanOrEqualTo(2));
      expect(budget.openCount, lessThanOrEqualTo(2));
      expect(budget.openCount, 1);
      expect(mgr.openLayer(StageLayer.setup), isTrue);
      await settle(t);
      expect(mgr.open, [StageLayer.setup]);
      expect(find.byType(GlassLayer).evaluate().length, lessThanOrEqualTo(2));
      expect(find.byKey(const Key('layer-path')), findsNothing);
      await _dispose(t, rig);
    });

    for (final size in const [Size(360, 640), Size(412, 915)]) {
      testWidgets('criterion 2: layer <= 60%, strip area >= 40% at '
          '${size.width.toInt()}x${size.height.toInt()}', (t) async {
        final rig = _Rig();
        await boot(t, _stage(rig, wrap: withRepo), size: size);
        await t.tap(find.byKey(const Key('stage-handle-other')));
        await settle(t);
        expect(find.byType(GlassLayer), findsOneWidget);
        final layer = t.getRect(
          find.descendant(
            of: find.byType(GlassLayer),
            matching: find.byType(FractionallySizedBox),
          ),
        );
        expect(layer.height, lessThanOrEqualTo(size.height * 0.6 + 0.5));
        expect(layer.top, greaterThanOrEqualTo(size.height * 0.4 - 0.5));
        final scrim = t.getRect(find.byKey(const Key('stage-layer-scrim')));
        expect(scrim.height, greaterThanOrEqualTo(size.height * 0.4 - 0.5));
        expect(scrim.top, 0);
        expect(t.takeException(), isNull);
        await _dispose(t, rig);
      });
    }

    testWidgets('criterion 3: suggestion line shows only with records', (
      t,
    ) async {
      final rig = _Rig();
      await boot(t, _stage(rig, wrap: withRepo));
      await t.tap(find.byKey(const Key('stage-handle-other')));
      await settle(t);
      expect(find.byKey(const Key('stage-suggestion')), findsNothing);
      await _dispose(t, rig);

      final first = catalog.lessons.firstWhere(
        (l) => l.availability == V1LessonAvailability.measured,
      );
      final rig2 = _Rig();
      await boot(
        t,
        _stage(
          rig2,
          wrap: withRepo,
          progress: _Memory({
            first.id: V1PracticeRecord(
              lessonId: first.id,
              runs: 2,
              bestHeard: .3,
              bestAccuracy: .9,
              lastRunAt: DateTime.utc(2026, 11, 1),
            ),
          }),
        ),
      );
      await t.tap(find.byKey(const Key('stage-handle-other')));
      await settle(t);
      expect(find.byKey(const Key('stage-suggestion')), findsOneWidget);
      expect(find.text(StageCopy.suggestMoveCloser.$2), findsOneWidget);
      await _dispose(t, rig2);
    });

    testWidgets('criterion 4: ear opens in two taps; the tuner opens full '
        'screen and back returns to the stage', (t) async {
      final rig = _Rig();
      await boot(
        t,
        _stage(
          rig,
          wrap: withRepo,
          earScreenBuilder: (_) => const Scaffold(body: Text('ear-stub')),
          tunerOpener: (c) => Navigator.of(c).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('tuner-stub')),
            ),
          ),
        ),
      );
      final lessonBefore = t
          .widget<PracticeLoopScreen>(find.byType(PracticeLoopScreen))
          .lesson
          .id;
      await t.tap(find.byKey(const Key('stage-handle-other'))); // 1
      await settle(t);
      await t.tap(find.byKey(const Key('stage-instr-ear'))); // 2
      await settle(t);
      expect(find.text('ear-stub'), findsOneWidget);
      await t.binding.handlePopRoute();
      await settle(t);
      expect(find.text('ear-stub'), findsNothing);
      expect(find.byKey(const Key('stage-home')), findsOneWidget);

      await t.tap(find.byKey(const Key('stage-tuner-entry')));
      await settle(t);
      expect(find.text('tuner-stub'), findsOneWidget);
      await t.binding.handlePopRoute();
      await settle(t);
      expect(find.byKey(const Key('stage-home')), findsOneWidget);
      expect(
        t.widget<PracticeLoopScreen>(find.byType(PracticeLoopScreen)).lesson.id,
        lessonBefore,
      );
      expect(rig.controller!.running, isFalse);
      expect(find.byKey(const Key('practice-start')), findsOneWidget);
      await _dispose(t, rig);
    });

    testWidgets('criterion 5: guitar and ear are open; other instruments '
        'follow the existing "coming soon" rule', (t) async {
      final rig = _Rig();
      await boot(
        t,
        _stage(
          rig,
          wrap: withRepo,
          earScreenBuilder: (_) => const Scaffold(body: Text('ear-stub')),
        ),
      );
      await t.tap(find.byKey(const Key('stage-handle-other')));
      await settle(t);
      expect(ostinatoOpenInstruments, contains('guitar'));
      expect(ostinatoEarTrainingOpen, isTrue);
      expect(find.byKey(const Key('stage-instr-guitar')), findsOneWidget);
      expect(find.byKey(const Key('stage-instr-ear')), findsOneWidget);
      final others = repo.disciplines.where(
        (d) => d.status == 'live' && !ostinatoOpenInstruments.contains(d.id),
      );
      expect(others, isNotEmpty);
      final d = others.first;
      await t.ensureVisible(find.byKey(Key('stage-instr-${d.id}')));
      await t.tap(find.byKey(Key('stage-instr-${d.id}')));
      await settle(t);
      expect(find.byType(ComingSoonInstrumentScreen), findsOneWidget);
      await t.binding.handlePopRoute();
      await settle(t);
      // Guitar: the stage is already on it; the layer just closes.
      await t.tap(find.byKey(const Key('stage-instr-guitar')));
      await settle(t);
      expect(find.byType(GlassLayer), findsNothing);
      await _dispose(t, rig);
    });

    testWidgets('criterion 6: focus goes into the layer, back to the handle', (
      t,
    ) async {
      final rig = _Rig();
      await boot(
        t,
        _stage(
          rig,
          layerBuilder: (c, h, close) => Column(
            children: [
              TextButton(
                key: const Key('first-item'),
                onPressed: close,
                child: const Text('first'),
              ),
              TextButton(
                key: const Key('second-item'),
                onPressed: close,
                child: const Text('second'),
              ),
            ],
          ),
        ),
      );
      await t.tap(find.byKey(const Key('stage-handle-other')));
      await settle(t);
      bool focused(String k) {
        final ctx = FocusManager.instance.primaryFocus?.context;
        if (ctx == null) return false;
        var inside = false;
        void visit(Element e) {
          if (e.widget.key == Key(k)) inside = true;
        }

        visit(ctx as Element);
        ctx.visitAncestorElements((e) {
          visit(e);
          return !inside;
        });
        return inside;
      }

      expect(focused('first-item'), isTrue);
      expect(focused('second-item'), isFalse);
      await t.tap(find.byKey(const Key('first-item')));
      await settle(t);
      expect(find.byKey(const Key('first-item')), findsNothing);
      expect(focused('stage-handle-other'), isTrue);
      await _dispose(t, rig);
    });

    testWidgets('criterion 7b: play, back, then the layer opens again', (
      t,
    ) async {
      final rig = _Rig();
      final mgr = StageLayerManager();
      addTearDown(mgr.dispose);
      await boot(t, _stage(rig, layerManager: mgr, wrap: withRepo));
      await _play(t);
      expect(mgr.locked, isTrue);
      await t.binding.handlePopRoute();
      await settle(t);
      expect(find.byKey(const Key('stage-run-not-completed')), findsOneWidget);
      expect(mgr.locked, isFalse);
      await t.tap(find.byKey(const Key('stage-handle-other')));
      await settle(t);
      expect(find.byType(GlassLayer), findsOneWidget);
      expect(mgr.isOpen, isTrue);
      await _dispose(t, rig);
    });

    PracticeRunSummary runSummary({
      required int heardNotes,
      bool completed = true,
      int bpm = 60,
    }) {
      final score = PracticeScore.parse('E2 F2 G2 F2 | E2 F2 G2 F2');
      return PracticeRunSummary.of(
        score: score,
        outcomes: [
          for (var i = 0; i < score.events.length; i++)
            NoteOutcome(
              eventIndex: i,
              bar: score.events[i].bar,
              pass: 0,
              mark: i < heardNotes
                  ? PracticeMark.correct
                  : PracticeMark.couldNotHear,
            ),
        ],
        bpm: bpm,
        openBpm: bpm,
        targetBpm: bpm,
        completed: completed,
        loopUsed: false,
        waitUsed: false,
      );
    }

    /// What the practice screen does when a run ends: the store write, then
    /// the "recorded" call.
    Future<void> finishRun(
      WidgetTester t,
      _Memory mem,
      String id,
      PracticeRunSummary s,
    ) async {
      await t.runAsync(() => mem.recordRun(id, s));
      t
          .widget<PracticeLoopScreen>(find.byType(PracticeLoopScreen))
          .onRunRecorded!();
      for (var i = 0; i < 4; i++) {
        await t.runAsync(() => Future<void>.delayed(Duration.zero));
        await t.pump();
      }
    }

    String lessonId(WidgetTester t) =>
        t.widget<PracticeLoopScreen>(find.byType(PracticeLoopScreen)).lesson.id;

    const suggestions = [
      StageCopy.suggestPickUp,
      StageCopy.suggestMoveCloser,
      StageCopy.suggestListenFirst,
      StageCopy.suggestSlowDown,
    ];
    List<UiCopy> shownSuggestions() => [
      for (final c in suggestions)
        if (find.text(c.$2).evaluate().isNotEmpty) c,
    ];

    testWidgets('criterion 3b: first run of a new user fills the line', (
      t,
    ) async {
      final rig = _Rig();
      final mem = _Memory();
      await boot(t, _stage(rig, wrap: withRepo, progress: mem));
      await finishRun(t, mem, lessonId(t), runSummary(heardNotes: 2));
      await t.tap(find.byKey(const Key('stage-handle-other')));
      await settle(t);
      expect(find.text(StageCopy.suggestMoveCloser.$2), findsOneWidget);
      await _dispose(t, rig);
    });

    testWidgets('ek B: in-session suggestion == the suggestion after a '
        'reopen (same store)', (t) async {
      for (final heard in [2, 8]) {
        final rig = _Rig();
        final mem = _Memory();
        await boot(t, _stage(rig, wrap: withRepo, progress: mem));
        await finishRun(t, mem, lessonId(t), runSummary(heardNotes: heard));
        await t.tap(find.byKey(const Key('stage-handle-other')));
        await settle(t);
        final inSession = shownSuggestions();
        await _dispose(t, rig);

        final rig2 = _Rig();
        await boot(t, _stage(rig2, wrap: withRepo, progress: mem));
        await t.tap(find.byKey(const Key('stage-handle-other')));
        await settle(t);
        expect(inSession, hasLength(1));
        expect(inSession, shownSuggestions(), reason: 'heard $heard of 8');
        expect(
          inSession.single,
          heard == 2 ? StageCopy.suggestMoveCloser : StageCopy.suggestPickUp,
        );
        await _dispose(t, rig2);
      }
    });

    testWidgets('ek B: a passed lesson with one note unheard reads none '
        '(pickUp), in session and after reopen', (t) async {
      final rig = _Rig();
      final mem = _Memory();
      await boot(t, _stage(rig, wrap: withRepo, progress: mem));
      final id = lessonId(t);
      await finishRun(t, mem, id, runSummary(heardNotes: 8));
      expect(mem.records[id]!.passed, isTrue);
      await finishRun(t, mem, id, runSummary(heardNotes: 7));
      await t.tap(find.byKey(const Key('stage-handle-other')));
      await settle(t);
      expect(shownSuggestions(), [StageCopy.suggestPickUp]);
      await _dispose(t, rig);

      final rig2 = _Rig();
      await boot(t, _stage(rig2, wrap: withRepo, progress: mem));
      await t.tap(find.byKey(const Key('stage-handle-other')));
      await settle(t);
      expect(shownSuggestions(), [StageCopy.suggestPickUp]);
      await _dispose(t, rig2);
    });

    testWidgets('ek E: the headline updates after the first run', (t) async {
      final rig = _Rig();
      final mem = _Memory();
      await boot(t, _stage(rig, wrap: withRepo, progress: mem));
      expect(
        t.widget<Text>(find.byKey(const Key('stage-headline'))).data,
        StageCopy.justStarting.$2,
      );
      final id = lessonId(t);
      await finishRun(t, mem, id, runSummary(heardNotes: 2));
      final unit = catalog.unitOf(id);
      expect(
        t.widget<Text>(find.byKey(const Key('stage-headline'))).data,
        StageCopy.continueLine.$2
            .replaceAll('{v0}', '${unit.level}')
            .replaceAll('{v1}', '${unit.module}'),
      );
      expect(t.takeException(), isNull);
      await _dispose(t, rig);
    });

    testWidgets('criterion 4b: rows are buttons for assistive technology', (
      t,
    ) async {
      final sem = t.ensureSemantics();
      final rig = _Rig();
      await boot(t, _stage(rig, wrap: withRepo));
      await t.tap(find.byKey(const Key('stage-handle-other')));
      await settle(t);
      for (final k in [
        'stage-instr-guitar',
        'stage-instr-ear',
        'stage-tuner-entry',
      ]) {
        final node = t.getSemantics(find.byKey(Key(k)));
        expect(node.flagsCollection.isButton, isTrue, reason: k);
      }
      sem.dispose();
      await _dispose(t, rig);
    });

    testWidgets('criterion 7: while playing nothing opens (manager, handle, '
        'real layer)', (t) async {
      final rig = _Rig();
      final mgr = StageLayerManager();
      addTearDown(mgr.dispose);
      await boot(t, _stage(rig, layerManager: mgr, wrap: withRepo));
      await t.tap(find.byKey(const Key('stage-handle-other')));
      await settle(t);
      expect(find.byType(GlassLayer), findsOneWidget);
      await t.tap(find.byKey(const Key('stage-instr-guitar')));
      await settle(t);
      await _play(t);
      expect(rig.controller!.running, isTrue);
      expect(mgr.openLayer(StageLayer.other), isFalse);
      expect(mgr.isOpen, isFalse);
      expect(find.byKey(const Key('stage-handles')), findsNothing);
      expect(find.byType(GlassLayer), findsNothing);
      await _dispose(t, rig);
    });
  });

  group('05d my path layer', () {
    late ContentRepository repo;
    late CueTextResolver cueText;
    setUpAll(() async {
      await prepareRootTranslations();
      repo = await ContentRepository.load();
      cueText = await CueTextResolver.load();
    });
    Widget withRepo(Widget w) =>
        scope.ContentRepositoryScope(repo: repo, cueText: cueText, child: w);

    Future<void> boot(WidgetTester t, Widget w, {Size? size}) async {
      t.view.physicalSize = size ?? const Size(420, 1800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(w);
      for (var i = 0; i < 4; i++) {
        await t.pump();
      }
    }

    Future<void> settleReads(WidgetTester t) async {
      for (var i = 0; i < 6; i++) {
        await t.runAsync(() => Future<void>.delayed(Duration.zero));
        await t.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> openPath(WidgetTester t) async {
      await t.tap(find.byKey(const Key('stage-handle-path')));
      await settleReads(t);
    }

    V1PracticeRecord rec(
      String id, {
      int runs = 1,
      double? heard,
      double? acc,
      bool passed = false,
      int? bpm,
    }) => V1PracticeRecord(
      lessonId: id,
      runs: runs,
      bestHeard: heard,
      bestAccuracy: acc,
      bestBpm: bpm,
      lastRunAt: DateTime.utc(2026, 11, 1),
      passedAt: passed ? DateTime.utc(2026, 11, 1) : null,
      passedBpm: passed ? 60 : null,
    );

    String textOf(WidgetTester t, String key) =>
        t.widget<Text>(find.byKey(Key(key), skipOffstage: false)).data!;

    testWidgets('olcut1: levels and modules equal the catalog; a row per '
        'lesson of an opened module; lock and paid marks are words', (t) async {
      final rig = _Rig();
      await boot(
        t,
        _stage(
          rig,
          wrap: withRepo,
          paidFeaturesAvailable: true,
          weeklyGoalLoader: () async => null,
        ),
      );
      await openPath(t);
      expect(find.byKey(const Key('stage-path-layer')), findsOneWidget);
      for (final level in catalog.levels) {
        expect(
          find.byKey(
            Key('stage-path-level-${level.level}'),
            skipOffstage: false,
          ),
          findsOneWidget,
        );
        for (final u in level.units) {
          expect(
            find.byKey(
              Key('stage-path-unit-title-${u.id}'),
              skipOffstage: false,
            ),
            findsOneWidget,
            reason: u.id,
          );
        }
      }
      final first = catalog.units.first;
      for (final l in first.lessons) {
        expect(
          find.byKey(Key('stage-path-lesson-${l.id}'), skipOffstage: false),
          findsOneWidget,
          reason: l.id,
        );
      }
      final paidUnit = catalog.units.firstWhere(
        (u) => u.lessons.any(
          (l) => !isFreeV1Lesson(l.id, paidFeaturesAvailable: true),
        ),
      );
      final title = find.byKey(Key('stage-path-unit-title-${paidUnit.id}'));
      await t.scrollUntilVisible(
        title,
        200,
        scrollable: find.descendant(
          of: find.byKey(const Key('stage-path-scroll')),
          matching: find.byType(Scrollable),
        ),
      );
      await t.tap(title);
      await t.pumpAndSettle();
      final paidLesson = paidUnit.lessons.firstWhere(
        (l) => !isFreeV1Lesson(l.id, paidFeaturesAvailable: true),
      );
      expect(
        find.byKey(
          Key('stage-path-paid-${paidLesson.id}'),
          skipOffstage: false,
        ),
        findsOneWidget,
      );
      expect(textOf(t, 'stage-path-paid-${paidLesson.id}'), 'Üyelik');
      expect(
        textOf(t, 'stage-path-status-${paidLesson.id}'),
        contains('KİLİTLİ'),
      );
      expect(
        find.byKey(
          Key('stage-path-paid-${first.lessons.first.id}'),
          skipOffstage: false,
        ),
        findsNothing,
      );
      expect(t.takeException(), isNull);
      await _dispose(t, rig);
    });

    testWidgets('olcut2: next lesson and why are shown; a new user: first '
        'module', (t) async {
      final rig = _Rig();
      await boot(
        t,
        _stage(rig, wrap: withRepo, weeklyGoalLoader: () async => null),
      );
      await openPath(t);
      expect(find.byKey(const Key('stage-path-next')), findsOneWidget);
      expect(textOf(t, 'stage-path-next'), startsWith('Sıradaki: '));
      expect(textOf(t, 'stage-path-why'), StageCopy.whyFirstModule.$2);
      await _dispose(t, rig);
    });

    testWidgets('olcut2: a self-reported gate reads not measured, never '
        'passed', (t) async {
      final u = catalog.units.firstWhere(
        (u) =>
            u.requiredGateIds.isNotEmpty &&
            u.requiredGateIds.every((id) => catalog.lesson(id)!.selfReportable),
      );
      final recs = <String, V1PracticeRecord>{};
      final checks = <String, V1LessonCheck>{};
      for (final l in catalog.lessons) {
        if (l.id.compareTo(u.lessons.first.id) >= 0) continue;
        if (u.requiredGateIds.contains(l.id)) {
          checks[l.id] = V1LessonCheck(
            lessonId: l.id,
            evidence: V1CheckEvidence.selfReport,
            at: DateTime.utc(2026, 11, 1),
          );
        } else {
          recs[l.id] = rec(l.id, passed: true);
        }
      }
      final rig = _Rig();
      await boot(
        t,
        practiceHost(
          locale: 'tr',
          withRepo(
            StageHomeScreen(
              catalog: catalog,
              progressFactory: (_) => _Memory(recs),
              checksFactory: (_) => _ChecksWith(checks),
              controllerFactory: rig.factory,
              paidFeaturesAvailable: false,
              weeklyGoalLoader: () async => null,
              seed: 1,
            ),
          ),
        ),
      );
      await openPath(t);
      expect(textOf(t, 'stage-path-why'), StageCopy.whyGateNotMeasured.$2);
      expect(textOf(t, 'stage-path-why'), contains('ölçülmedi'));
      expect(textOf(t, 'stage-path-why'), isNot(contains('geçildi')));
      expect(
        textOf(t, 'stage-path-unit-status-${u.id}'),
        contains('ölçülmedi'),
      );
      await _dispose(t, rig);
    });

    testWidgets('olcut3: history shows the stored bests side by side, heard '
        'apart from accuracy; weekly goal is one plain line', (t) async {
      final a = catalog.lessons[0].id, b = catalog.lessons[1].id;
      final rig = _Rig();
      await boot(
        t,
        _stage(
          rig,
          wrap: withRepo,
          progress: _Memory({
            a: rec(a, runs: 3, heard: .8, acc: .5, bpm: 70, passed: true),
            b: rec(b, heard: .4, acc: .9),
          }),
          weeklyGoalLoader: () async => evaluateWeeklyGoal(
            entries: [
              PracticeEntry(
                day: LocalDay(2026, 11, 10),
                kind: PracticeEntryKind.measuredSession,
                course: PracticeCourse.guitar,
              ),
            ],
            today: LocalDay(2026, 11, 11),
          ),
        ),
      );
      await openPath(t);
      expect(textOf(t, 'stage-history-heard-$a'), '80%');
      expect(textOf(t, 'stage-history-accuracy-$a'), '50%');
      expect(textOf(t, 'stage-history-heard-$b'), '40%');
      expect(textOf(t, 'stage-history-accuracy-$b'), '90%');
      expect(find.byKey(const Key('stage-history-empty')), findsNothing);
      expect(find.byKey(const Key('stage-history-weekly')), findsOneWidget);
      final shown = [
        for (final w in t.widgetList<Text>(
          find.descendant(
            of: find.byKey(const Key('stage-path-layer')),
            matching: find.byType(Text),
            skipOffstage: false,
          ),
        ))
          w.data ?? '',
      ].join(' ').toLowerCase();
      for (final word in [
        'puan',
        'rozet',
        'seri',
        'score',
        'badge',
        'streak',
      ]) {
        expect(shown.contains(word), isFalse, reason: word);
      }
      await _dispose(t, rig);
    });

    testWidgets('olcut3: a failed weekly read: no weekly row, no error', (
      t,
    ) async {
      final rig = _Rig();
      await boot(
        t,
        _stage(
          rig,
          wrap: withRepo,
          weeklyGoalLoader: () async => throw StateError('no file'),
        ),
      );
      await openPath(t);
      expect(find.byKey(const Key('stage-history-weekly')), findsNothing);
      expect(find.byKey(const Key('stage-path-failed')), findsNothing);
      await _dispose(t, rig);
    });

    testWidgets('olcut4: empty: the honest line, no invented number', (
      t,
    ) async {
      final rig = _Rig();
      await boot(
        t,
        _stage(rig, wrap: withRepo, weeklyGoalLoader: () async => null),
      );
      await openPath(t);
      expect(textOf(t, 'stage-history-empty'), StageCopy.historyEmpty.$2);
      expect(find.byKey(const Key('stage-history-head')), findsNothing);
      expect(find.textContaining('%'), findsNothing);
      await _dispose(t, rig);
    });

    testWidgets('olcut4: a read ERROR is not the empty text: honest error '
        'and a retry', (t) async {
      final rig = _Rig();
      final mem = _Memory({
        catalog.lessons[0].id: rec(catalog.lessons[0].id, heard: .7, acc: .7),
      });
      mem.failLoadCalls.add(2); // call 1 = stage load, call 2 = the layer
      await boot(
        t,
        _stage(
          rig,
          wrap: withRepo,
          progress: mem,
          weeklyGoalLoader: () async => null,
        ),
      );
      await openPath(t);
      expect(find.byKey(const Key('stage-path-failed')), findsOneWidget);
      expect(find.byKey(const Key('stage-history-empty')), findsNothing);
      expect(find.text(StageCopy.pathReadFailed.$2), findsOneWidget);
      await t.tap(find.byKey(const Key('stage-path-retry')));
      await settleReads(t);
      expect(find.byKey(const Key('stage-path-failed')), findsNothing);
      expect(
        find.byKey(
          Key('stage-history-heard-${catalog.lessons[0].id}'),
          skipOffstage: false,
        ),
        findsOneWidget,
      );
      await _dispose(t, rig);
    });

    testWidgets('olcut5: ear results are their own section', (t) async {
      final a = catalog.lessons[0].id;
      final rig = _Rig();
      await boot(
        t,
        _stage(
          rig,
          wrap: withRepo,
          progress: _Memory({
            a: rec(a, heard: .8, acc: .8),
            'ear-s1-m01-01': rec('ear-s1-m01-01', runs: 4, heard: 1, acc: 1),
          }),
          weeklyGoalLoader: () async => null,
        ),
      );
      await openPath(t);
      expect(
        find.byKey(const Key('stage-history-ear-title'), skipOffstage: false),
        findsOneWidget,
      );
      expect(
        textOf(t, 'stage-history-ear'),
        StageCopy.earLine.$2.replaceAll('{v0}', '1').replaceAll('{v1}', '4'),
      );
      expect(
        find.byKey(
          const Key('stage-history-row-ear-s1-m01-01'),
          skipOffstage: false,
        ),
        findsNothing,
      );
      expect(
        find.byKey(Key('stage-history-row-$a'), skipOffstage: false),
        findsOneWidget,
      );
      await _dispose(t, rig);
    });

    testWidgets('olcut7: a linear list for assistive technology: level > '
        'module > lesson, no map component, no sort keys, rows not buttons', (
      t,
    ) async {
      final sem = t.ensureSemantics();
      final rig = _Rig();
      await boot(
        t,
        _stage(rig, wrap: withRepo, weeklyGoalLoader: () async => null),
      );
      await openPath(t);
      final layer = find.byKey(const Key('stage-path-layer'));
      for (final type in [InteractiveViewer, GridView, CustomScrollView]) {
        expect(
          find.descendant(
            of: layer,
            matching: find.byWidgetPredicate((w) => w.runtimeType == type),
          ),
          findsNothing,
          reason: '$type',
        );
      }
      final labels = <String>[];
      var sortKeys = 0;
      void walk(SemanticsNode n) {
        final d = n.getSemanticsData();
        if (d.label.isNotEmpty) labels.add(d.label);
        if (n.sortKey != null) sortKeys++;
        n
            .debugListChildrenInOrder(DebugSemanticsDumpOrder.traversalOrder)
            .forEach(walk);
      }

      walk(t.getSemantics(layer));
      final firstLesson = catalog.units.first.lessons.first;
      final lv = labels.indexWhere((l) => l.startsWith('Seviye 1'));
      final un = labels.indexWhere((l) => l.startsWith('Modül 1'));
      final ls = labels.indexWhere(
        (l) => l.contains(firstLesson.lesson.title.of(t.element(layer))),
        un + 1,
      );
      expect(lv, greaterThanOrEqualTo(0), reason: '$labels');
      expect(un, greaterThan(lv), reason: '$labels');
      expect(ls, greaterThan(un), reason: '$labels');
      expect(sortKeys, 0);
      final row = t.getSemantics(
        find.byKey(Key('stage-path-lesson-${firstLesson.id}')),
      );
      expect(row.flagsCollection.isButton, isFalse);
      sem.dispose();
      await _dispose(t, rig);
    });

    for (final size in const [Size(360, 640), Size(412, 915)]) {
      testWidgets('layer <= 60%, strip >= 40% at '
          '${size.width.toInt()}x${size.height.toInt()}', (t) async {
        final rig = _Rig();
        await boot(
          t,
          _stage(
            rig,
            wrap: withRepo,
            progress: _Memory({
              catalog.lessons[0].id: rec(catalog.lessons[0].id, heard: .8),
            }),
            weeklyGoalLoader: () async => null,
          ),
          size: size,
        );
        await openPath(t);
        expect(find.byType(GlassLayer), findsOneWidget);
        final layer = t.getRect(
          find.descendant(
            of: find.byType(GlassLayer),
            matching: find.byType(FractionallySizedBox),
          ),
        );
        expect(layer.height, lessThanOrEqualTo(size.height * 0.6 + 0.5));
        expect(layer.top, greaterThanOrEqualTo(size.height * 0.4 - 0.5));
        final scrim = t.getRect(find.byKey(const Key('stage-layer-scrim')));
        expect(scrim.height, greaterThanOrEqualTo(size.height * 0.4 - 0.5));
        expect(find.byKey(const Key('stage-path-scroll')), findsOneWidget);
        expect(t.takeException(), isNull);
        await _dispose(t, rig);
      });
    }

    testWidgets('one layer at a time: path then other closes path; focus '
        'goes in, and back to the handle', (t) async {
      final rig = _Rig();
      final mgr = StageLayerManager();
      addTearDown(mgr.dispose);
      await boot(
        t,
        _stage(
          rig,
          layerManager: mgr,
          wrap: withRepo,
          weeklyGoalLoader: () async => null,
        ),
      );
      await openPath(t);
      expect(find.byType(GlassLayer), findsOneWidget);
      final primary = FocusManager.instance.primaryFocus;
      expect(primary, isNotNull);
      expect(primary!.debugLabel, isNot('handle-path'));
      await t.tap(find.byKey(const Key('stage-layer-scrim')));
      await t.pumpAndSettle();
      expect(find.byType(GlassLayer), findsNothing);
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'handle-path');
      await t.tap(find.byKey(const Key('stage-handle-path')));
      await settleReads(t);
      expect(mgr.openLayer(StageLayer.other), isTrue);
      await settleReads(t);
      expect(mgr.open, [StageLayer.other]);
      expect(find.byKey(const Key('stage-path-layer')), findsNothing);
      expect(find.byKey(const Key('stage-other-scroll')), findsOneWidget);
      expect(find.byType(GlassLayer).evaluate().length, 1);
      await _dispose(t, rig);
    });

    testWidgets('tur1 #3: no records: the weekly line is hidden even when a '
        'real weekly status exists (no invented "0 of 3")', (t) async {
      final rig = _Rig();
      await boot(
        t,
        _stage(
          rig,
          wrap: withRepo,
          weeklyGoalLoader: () async => evaluateWeeklyGoal(
            entries: const <PracticeEntry>[],
            today: LocalDay(2026, 11, 11),
          ),
        ),
      );
      await openPath(t);
      expect(textOf(t, 'stage-history-empty'), StageCopy.historyEmpty.$2);
      expect(find.byKey(const Key('stage-history-weekly')), findsNothing);
      await _dispose(t, rig);
    });

    for (final completed in [false, true]) {
      testWidgets('tur1 #6: a stored pass without a tempo shows no '
          '"♩=0" (${completed ? 'completed' : 'passed'})', (t) async {
        final id = catalog.lessons[0].id;
        final rig = _Rig();
        await boot(
          t,
          _stage(
            rig,
            wrap: withRepo,
            progress: _Memory({
              id: V1PracticeRecord(
                lessonId: id,
                runs: 1,
                bestHeard: .9,
                bestAccuracy: .9,
                lastRunAt: DateTime.utc(2026, 11, 1),
                passedAt: DateTime.utc(2026, 11, 1),
                completedAt: completed ? DateTime.utc(2026, 11, 1) : null,
              ),
            }),
            weeklyGoalLoader: () async => null,
          ),
        );
        await openPath(t);
        final status = textOf(t, 'stage-path-status-$id');
        expect(status, isNot(contains('♩=0')));
        expect(status, isNot(contains('♩')));
        expect(status, isNotEmpty);
        await _dispose(t, rig);
      });
    }

    testWidgets('tur1 #4: once the content has loaded, focus is on the '
        'first item of the layer (a real item, not the scope)', (t) async {
      final rig = _Rig();
      await boot(
        t,
        _stage(rig, wrap: withRepo, weeklyGoalLoader: () async => null),
      );
      await openPath(t);
      await t.pump();
      final focus = FocusManager.instance.primaryFocus!;
      expect(focus.debugLabel, isNot('stage-layer'));
      final tile = focus.context!
          .findAncestorWidgetOfExactType<ExpansionTile>();
      expect(tile, isNotNull, reason: 'focus is on a unit header');
      expect(
        tile!.key,
        PageStorageKey<String>('stage-path-unit-${catalog.units.first.id}'),
      );
      await _dispose(t, rig);
    });

    testWidgets('tur1 #4: a failed read: focus goes to the retry button', (
      t,
    ) async {
      final rig = _Rig();
      final mem = _Memory();
      mem.failLoadCalls.add(2);
      await boot(
        t,
        _stage(
          rig,
          wrap: withRepo,
          progress: mem,
          weeklyGoalLoader: () async => null,
        ),
      );
      await openPath(t);
      await t.pump();
      final focus = FocusManager.instance.primaryFocus!;
      expect(
        focus.context!.findAncestorWidgetOfExactType<TextButton>()?.key,
        const Key('stage-path-retry'),
      );
      await _dispose(t, rig);
    });

    for (final withRecords in [false, true]) {
      testWidgets('tur1 #10: text scale 1.3 at 360x640 '
          '(${withRecords ? 'history' : 'empty'}): no overflow', (t) async {
        final rig = _Rig();
        final a = catalog.lessons[0].id;
        await boot(
          t,
          _stage(
            rig,
            wrap: (w) => withRepo(
              Builder(
                builder: (c) => MediaQuery(
                  data: MediaQuery.of(
                    c,
                  ).copyWith(textScaler: const TextScaler.linear(1.3)),
                  child: w,
                ),
              ),
            ),
            progress: _Memory({
              if (withRecords)
                a: rec(
                  a,
                  runs: 12,
                  heard: .85,
                  acc: .75,
                  bpm: 70,
                  passed: true,
                ),
              if (withRecords)
                'ear-s1-m01-01': rec('ear-s1-m01-01', runs: 3, heard: 1),
            }),
            weeklyGoalLoader: () async => evaluateWeeklyGoal(
              entries: [
                PracticeEntry(
                  day: LocalDay(2026, 11, 10),
                  kind: PracticeEntryKind.measuredSession,
                  course: PracticeCourse.guitar,
                ),
              ],
              today: LocalDay(2026, 11, 11),
            ),
          ),
          size: const Size(360, 640),
        );
        await openPath(t);
        expect(find.byKey(const Key('stage-path-layer')), findsOneWidget);
        expect(t.takeException(), isNull);
        final scroll = find.descendant(
          of: find.byKey(const Key('stage-path-scroll')),
          matching: find.byType(Scrollable),
        );
        final target = find.byKey(
          Key(withRecords ? 'stage-history-ear' : 'stage-history-empty'),
          skipOffstage: false,
        );
        await t.scrollUntilVisible(target, 300, scrollable: scroll);
        await t.pump();
        expect(t.takeException(), isNull);
        await _dispose(t, rig);
      });
    }

    testWidgets('while playing the path handle is gone and nothing opens', (
      t,
    ) async {
      final rig = _Rig();
      final mgr = StageLayerManager();
      addTearDown(mgr.dispose);
      await boot(t, _stage(rig, layerManager: mgr, wrap: withRepo));
      await _play(t);
      expect(rig.controller!.running, isTrue);
      expect(find.byKey(const Key('stage-handle-path')), findsNothing);
      expect(mgr.openLayer(StageLayer.path), isFalse);
      expect(find.byType(GlassLayer), findsNothing);
      await _dispose(t, rig);
    });
  });
}
