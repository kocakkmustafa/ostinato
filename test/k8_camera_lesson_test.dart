// K8 camera posture lessons (founder 2026-11-01; scope approved 2026-11-04:
// opens in 1.0.3, the sitting lesson gets a trunk-tilt hint, no score,
// nothing recorded). The camera itself is not exercised here: every widget
// test runs the live chain with a scripted pose source, so the claim is
// "the hint path ran with a fake source", never "the camera works".
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motion_account/motion_account.dart'
    show motionCameraCoachingAvailable;
import 'package:ostinato/app/cue_text.dart';
import 'package:ostinato/app/curriculum/v1_lesson.dart';
import 'package:ostinato/app/drill/drill_generator.dart';
import 'package:ostinato/app/drill/drill_hand.dart';
import 'package:ostinato/app/drill/drill_screen.dart';
import 'package:ostinato/app/ostinato_release_policy.dart';
import 'package:ostinato/app/practice/camera/camera_hold_screen.dart';
import 'package:ostinato/app/practice/camera/camera_lesson.dart';
import 'package:ostinato/app/practice/camera/camera_lesson_copy.dart';
import 'package:ostinato/app/practice/loop/practice_progress_store.dart';
import 'package:ostinato/app/practice/loop/v1_course_catalog.dart';
import 'package:ostinato/app/practice/loop/v1_course_copy.dart';
import 'package:ostinato/app/practice/loop/v1_lesson_reader_screen.dart';
import 'package:ostinato/app/practice/loop/v1_practice_list_screen.dart';
import 'package:ostinato/app/practice/loop/practice_outcome.dart';
import 'package:ostinato/app/practice/setup/setup_profile_store.dart';
import 'package:ostinato/app/tuner/tuner_copy.dart';
import 'package:ostinato_posture/ostinato_posture.dart';
import 'package:permission_handler/permission_handler.dart';

import 'support/practice_host.dart';

final class _MemoryChecks implements V1LessonChecks {
  final saved = <V1LessonCheck>[];

  @override
  Future<Map<String, V1LessonCheck>> load() async => {
    for (final c in saved) c.lessonId: c,
  };

  @override
  Future<V1LessonCheck> record(
    String lessonId,
    V1CheckEvidence evidence, {
    DateTime? at,
  }) async {
    final c = V1LessonCheck(
      lessonId: lessonId,
      evidence: evidence,
      at: at ?? DateTime.utc(2026, 11, 4),
    );
    saved.add(c);
    return c;
  }
}

final class _NoProgress implements V1PracticeProgress {
  @override
  Future<Map<String, V1PracticeRecord>> load() async => const {};
  @override
  Future<V1PracticeRecord> recordRun(
    String lessonId,
    PracticeRunSummary summary, {
    DateTime? at,
  }) => throw UnimplementedError();
}

/// A pose source the test drives frame by frame (no timer, synchronous
/// delivery so each pump shows the frame just pushed), counting starts and
/// stops.
final class _ScriptSource implements PoseSource {
  final _frames = StreamController<PoseFrame>.broadcast(sync: true);
  final _status = StreamController<SurfaceState>.broadcast(sync: true);
  int starts = 0;
  int stops = 0;
  int _tUs = 0;

  @override
  Stream<PoseFrame> get frames => _frames.stream;
  @override
  Stream<SurfaceState> get status => _status.stream;
  @override
  Future<void> start() async => starts++;
  @override
  Future<void> stop() async => stops++;

  /// One frame 100 ms after the previous; `null` = nobody visible.
  void push(double? tiltDeg) {
    _tUs += 100000;
    _frames.add(PoseFrame(tUs: _tUs, trunkTiltDeg: tiltDeg));
  }

  void emit(SurfaceState s) => _status.add(s);
}

void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Every call on the camera and permission channels; a closed flag means
/// none at all, not "none that succeeded".
List<String> _watchCameraChannels() {
  final calls = <String>[];
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  for (final name in const [
    'motion_camera/control',
    'flutter.baseflow.com/permissions/methods',
    // The `camera` package's default platform (the hand lesson's mirror).
    'plugins.flutter.io/camera',
  ]) {
    messenger.setMockMethodCallHandler(MethodChannel(name), (call) async {
      calls.add('$name ${call.method}');
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(MethodChannel(name), null),
    );
  }
  return calls;
}

String _fill(String text, Map<String, Object> values) => values.entries.fold(
  text,
  (s, e) => s.replaceAll('{${e.key}}', '${e.value}'),
);

/// Camera lessons in the guitar course: the sitting lesson has the hint;
/// the hand lesson has no teacher data, so it gets the mirror (no hint;
/// test/k8_mirror_test.dart).
const _sitting = 'gtr-s1-m01-02';
const _hand = 'gtr-s1-m01-03';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late V1CourseCatalog gtr;
  late PostureContract guitar;
  setUpAll(() async {
    gtr = await V1CourseCatalog.load();
    guitar = PostureContract.fromJson(
      File('assets/config/posture-contract.json').readAsStringSync(),
      'guitar',
    );
  });

  Widget hold(PoseSource source, {int seconds = 60}) => practiceHost(
    CameraHoldScreen(
      title: 'A comfortable sitting position',
      holdSeconds: seconds,
      source: source,
      contract: Future.value(guitar),
    ),
  );

  group('flag closed: today\'s camera lessons are unchanged', () {
    test('release gates are closed', () {
      expect(motionCameraCoachingAvailable, isFalse, reason: 'Core pin');
      expect(ostinatoCameraPracticeAvailable, isFalse);
      expect(ostinatoCameraLessonsOpen, isFalse, reason: 'opens in 1.0.3');
    });

    test('exactly two camera lessons, both with a checklist', () {
      final camera = [
        for (final l in gtr.lessons)
          if (l.availability == V1LessonAvailability.camera) l.id,
      ];
      expect(camera, [_sitting, _hand]);
      for (final id in camera) {
        final l = gtr.lesson(id)!;
        expect(l.reason, V1PendingReason.camera, reason: id);
        expect(l.lesson.practice.engineSteps, ['A7'], reason: id);
        expect(l.lesson.selfCheck, isNotEmpty, reason: id);
      }
    });

    testWidgets('the channel watch sees a permission request', (tester) async {
      // Proves the guard below can fail: an empty list is not a blind spot.
      final calls = _watchCameraChannels();
      try {
        await Permission.camera.request();
      } on TypeError {
        // The watch answers null; the plugin wants a map. The call landed.
      }
      expect(calls, isNotEmpty);
    });

    for (final id in const [_sitting, _hand]) {
      testWidgets('reader $id: banner and checklist, no camera, no channel', (
        tester,
      ) async {
        _tall(tester);
        final calls = _watchCameraChannels();
        final checks = _MemoryChecks();
        final l = gtr.lesson(id)!;
        await tester.pumpWidget(
          practiceHost(V1LessonReaderScreen(lesson: l, checks: checks)),
        );
        await tester.pumpAndSettle();

        expect(find.text(V1CourseCopy.bannerCamera.$1), findsOneWidget);
        expect(find.byKey(const Key('v1-reader-camera')), findsNothing);
        expect(find.byKey(const Key('v1-reader-mirror')), findsNothing);
        expect(find.byKey(const Key('v1-reader-drill')), findsNothing);
        for (final item in l.lesson.selfCheck) {
          expect(find.text(item.en), findsOneWidget);
        }

        for (var i = 0; i < l.lesson.selfCheck.length; i++) {
          await tester.tap(find.byKey(Key('v1-reader-check-$i')));
        }
        await tester.pump();
        await tester.tap(find.byKey(const Key('v1-reader-mark-done')));
        await tester.pumpAndSettle();

        expect(checks.saved.single.lessonId, id);
        expect(checks.saved.single.evidence, V1CheckEvidence.selfReport);
        expect(calls, isEmpty, reason: 'no camera or permission call');
      });
    }
  });

  group('flag open (1.0.3)', () {
    test('the camera table: sitting hint 60 s, hand mirror 30 s', () {
      expect(v1CameraLessons.keys, [_sitting, _hand]);
      expect(v1CameraLessons[_sitting]!.part, CameraPart.trunkHint);
      expect(v1CameraLessons[_sitting]!.holdSeconds, 60);
      expect(
        gtr.lesson(_sitting)!.lesson.practice.task.en,
        contains('60 seconds'),
      );
      expect(v1CameraLessons[_hand]!.part, CameraPart.mirror);
      expect(v1CameraLessons[_hand]!.holdSeconds, 30);
      expect(
        gtr.lesson(_hand)!.lesson.practice.task.en,
        contains('30 seconds'),
      );
    });

    test('the hint\'s English is the golden observation, slot for slot', () {
      final cue = ObservationCue(
        templateId: guitar.cueTemplateId,
        teacherCount: guitar.teacherCount,
        sourceClass: guitar.sourceClass,
        thresholdDeg: guitar.cueThresholdDeg,
        measuredDeg: 21.4,
      );
      return CueTextResolver.load().then((golden) {
        expect(
          _fill(CameraLessonCopy.hintTrunk.$1, {
            'v0': cue.teacherCount,
            'v1': cue.thresholdDeg.toStringAsFixed(0),
            'v2': cue.measuredDeg.toStringAsFixed(0),
          }),
          golden.resolve(cue), // the first variant
        );
      });
    });

    testWidgets('course list: chips say camera hint and camera mirror', (
      tester,
    ) async {
      _tall(tester);
      await tester.pumpWidget(
        practiceHost(
          V1PracticeListScreen(
            catalog: Future.value(gtr),
            progressFactory: (_) => _NoProgress(),
            checksFactory: (_) => _MemoryChecks(),
            setupStore: MemorySetupProfileStore(),
            paidFeaturesAvailable: false,
            cameraLessonsOpen: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      String chip(String id) =>
          tester.widget<Text>(find.byKey(Key('v1-course-chip-$id'))).data!;
      expect(chip(_sitting), CameraLessonCopy.chipHint.$1);
      expect(chip(_hand), CameraLessonCopy.mirrorChip.$1);
    });

    testWidgets('reader: entry on the sitting lesson; no permission yet', (
      tester,
    ) async {
      _tall(tester);
      final calls = _watchCameraChannels();
      final source = _ScriptSource();
      await tester.pumpWidget(
        practiceHost(
          V1LessonReaderScreen(
            lesson: gtr.lesson(_sitting)!,
            checks: _MemoryChecks(),
            cameraLessonsOpen: true,
            cameraSource: () => source,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(CameraLessonCopy.bannerHint.$1), findsOneWidget);
      expect(find.text(CameraLessonCopy.intro.$1), findsOneWidget);
      expect(find.byKey(const Key('v1-reader-camera')), findsOneWidget);
      expect(source.starts, 0);
      expect(calls, isEmpty, reason: 'permission waits for the tap');

      await tester.tap(find.byKey(const Key('v1-reader-camera')));
      await tester.pumpAndSettle();
      expect(find.byType(CameraHoldScreen), findsOneWidget);
      expect(source.starts, 1);
    });

    testWidgets('reader: the hand lesson has the mirror, not the hint', (
      tester,
    ) async {
      _tall(tester);
      await tester.pumpWidget(
        practiceHost(
          V1LessonReaderScreen(
            lesson: gtr.lesson(_hand)!,
            checks: _MemoryChecks(),
            cameraLessonsOpen: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('v1-reader-camera')), findsNothing);
      expect(find.byKey(const Key('v1-reader-mirror')), findsOneWidget);
      expect(find.text(CameraLessonCopy.mirrorBanner.$1), findsOneWidget);
      expect(find.text(CameraLessonCopy.mirrorIntro.$1), findsOneWidget);
    });

    testWidgets('in the teachers\' range: quiet, no hint', (tester) async {
      final source = _ScriptSource();
      await tester.pumpWidget(hold(source));
      await tester.pumpAndSettle();
      expect(find.text(CameraLessonCopy.starting.$1), findsOneWidget);
      for (final deg in [2.0, 3.5, 5.0, 9.0, 12.0]) {
        source.push(deg);
        await tester.pump();
      }
      expect(find.text(CameraLessonCopy.watching.$1), findsOneWidget);
      expect(find.byKey(const Key('camera-hold-hint')), findsNothing);
    });

    testWidgets('a sustained lean gives one hint, then the cooldown holds', (
      tester,
    ) async {
      final source = _ScriptSource();
      await tester.pumpWidget(hold(source));
      await tester.pumpAndSettle();
      // Two frames past the threshold are not a hint yet (3 in a row).
      source
        ..push(20)
        ..push(20);
      await tester.pump();
      expect(find.byKey(const Key('camera-hold-hint')), findsNothing);
      source.push(20);
      await tester.pump();
      final hint = _fill(CameraLessonCopy.hintTrunk.$1, {
        'v0': 7,
        'v1': 14,
        'v2': 20,
      });
      expect(find.text(hint), findsOneWidget);
      expect(find.text(CameraLessonCopy.watching.$1), findsNothing);
      expect(find.textContaining('%'), findsNothing, reason: 'no score');

      // Back in range: the hint goes quiet.
      source.push(3);
      await tester.pump();
      expect(find.byKey(const Key('camera-hold-hint')), findsNothing);
      // Another sustained lean within 30 s: still quiet (cooldown).
      for (var i = 0; i < 5; i++) {
        source.push(22);
      }
      await tester.pump();
      expect(find.byKey(const Key('camera-hold-hint')), findsNothing);
    });

    testWidgets('nobody visible: says so, no hint, no verdict', (tester) async {
      final source = _ScriptSource();
      await tester.pumpWidget(hold(source));
      await tester.pumpAndSettle();
      for (var i = 0; i < 5; i++) {
        source.push(null);
      }
      await tester.pump();
      expect(find.text(CameraLessonCopy.notVisible.$1), findsOneWidget);
      expect(find.byKey(const Key('camera-hold-hint')), findsNothing);
      expect(find.text(CameraLessonCopy.watching.$1), findsNothing);
    });

    testWidgets('permission denied: says so and offers Settings', (
      tester,
    ) async {
      final source = _ScriptSource();
      await tester.pumpWidget(hold(source));
      await tester.pumpAndSettle();
      source.emit(const PermissionDeniedPermanent());
      await tester.pump();
      expect(find.text(CameraLessonCopy.denied.$1), findsOneWidget);
      expect(find.text(TunerCopy.openSettings.$1), findsOneWidget);
      expect(find.byKey(const Key('camera-hold-hint')), findsNothing);
    });

    testWidgets('the hold ends after its seconds, stops the camera once', (
      tester,
    ) async {
      final source = _ScriptSource();
      await tester.pumpWidget(hold(source, seconds: 3));
      await tester.pumpAndSettle();
      source.push(4);
      await tester.pump();
      expect(find.text('3 s left'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('2 s left'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      expect(find.text(CameraLessonCopy.timeUp.$1), findsOneWidget);
      expect(source.stops, 1);
      // Frames after the end change nothing.
      for (var i = 0; i < 4; i++) {
        source.push(25);
      }
      await tester.pump();
      expect(find.byKey(const Key('camera-hold-hint')), findsNothing);
      await tester.tap(find.byKey(const Key('camera-hold-back')));
      await tester.pumpAndSettle();
      expect(source.stops, 1);
    });

    testWidgets('leaving mid-hold stops the camera', (tester) async {
      final source = _ScriptSource();
      await tester.pumpWidget(
        practiceHost(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => CameraHoldScreen(
                    title: 'Sitting',
                    holdSeconds: 60,
                    source: source,
                    contract: Future.value(guitar),
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      source.push(3);
      await tester.pump();
      await tester.tap(find.byKey(const Key('camera-hold-back')));
      await tester.pumpAndSettle();
      expect(find.byType(CameraHoldScreen), findsNothing);
      expect(source.stops, 1);
    });
  });

  group('hand lesson: finger-number questions', () {
    V1Drill handDrill() => gtr.lesson(_hand)!.lesson.practice.anyDrill!;

    test('the set runs with the hand diagram only', () {
      final d = handDrill();
      expect(d.params['set'], 'fretting_finger_numbers');
      expect(supportsDrill(d), isTrue);
      // The camera lesson's availability keeps it out of drillReady.
      expect(gtr.lesson(_hand)!.drillReady, isFalse);
      V1Drill drillWith(Map<String, Object?> params) => V1Drill.fromJson({
        'type': 'diagram_match',
        'count': 6,
        'params': params,
      });
      expect(
        supportsDrill(drillWith({'set': 'fretting_finger_numbers'})),
        isFalse,
        reason: 'needs the hand diagram',
      );
      expect(
        supportsDrill(
          drillWith({'set': 'piano_finger_numbers', 'diagram': 'hand'}),
        ),
        isFalse,
        reason: 'piano numbers (thumb = 1) are another set',
      );
    });

    test('six questions, the marked finger is the answer, no repeats', () {
      for (final seed in [1, 2, 3, 4, 5]) {
        final qs = generateDrill(handDrill(), seed: seed);
        expect(qs, hasLength(6));
        for (var i = 0; i < qs.length; i++) {
          final q = qs[i];
          expect(q.kind, DrillPromptKind.fingerNumber);
          expect(q.options, ['1', '2', '3', '4']);
          expect(q.expected, '${q.finger}');
          if (i > 0) expect(q.expected, isNot(qs[i - 1].expected));
        }
      }
    });

    testWidgets('flag open: questions, then the checklist completes it', (
      tester,
    ) async {
      _tall(tester);
      final checks = _MemoryChecks();
      final l = gtr.lesson(_hand)!;
      await tester.pumpWidget(
        practiceHost(
          V1LessonReaderScreen(
            lesson: l,
            checks: checks,
            cameraLessonsOpen: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('v1-reader-camera')), findsNothing);
      for (var i = 0; i < l.lesson.selfCheck.length; i++) {
        await tester.tap(find.byKey(Key('v1-reader-check-$i')));
      }
      await tester.pump();
      FilledButton mark() => tester.widget<FilledButton>(
        find.byKey(const Key('v1-reader-mark-done')),
      );
      expect(mark().onPressed, isNull, reason: 'questions not passed yet');
      expect(find.text(CameraLessonCopy.drillFirst.$1), findsOneWidget);

      await tester.tap(find.byKey(const Key('v1-reader-drill')));
      await tester.pumpAndSettle();
      final session = tester
          .state<DrillScreenState>(find.byType(DrillScreen))
          .session;
      while (!session.finished) {
        final painter =
            tester
                    .widget<CustomPaint>(find.byKey(const Key('drill-hand')))
                    .painter!
                as DrillHandPainter;
        expect('${painter.marked}', session.current.expected);
        final key = Key('drill-option-${session.current.answer}');
        await tester.ensureVisible(find.byKey(key));
        await tester.tap(find.byKey(key));
        await tester.pump();
        await tester.ensureVisible(find.byKey(const Key('drill-next')));
        await tester.tap(find.byKey(const Key('drill-next')));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byKey(const Key('drill-back')));
      await tester.pumpAndSettle();

      // Passing the questions alone saves nothing.
      expect(checks.saved, isEmpty);
      expect(find.text(CameraLessonCopy.drillFirst.$1), findsNothing);
      await tester.tap(find.byKey(const Key('v1-reader-mark-done')));
      await tester.pumpAndSettle();
      expect(checks.saved.single.evidence, V1CheckEvidence.selfReport);
    });
  });
}
