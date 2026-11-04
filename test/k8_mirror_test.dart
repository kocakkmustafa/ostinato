// K8 hand lesson mirror (founder 2026-11-04: the `camera` package, now;
// behind ostinatoCameraLessonsOpen, opens in 1.0.3). The mirror is the live
// front-camera preview and nothing else: no hint, no score, no frame read,
// nothing recorded. Two camera stacks share one device camera, so the tests
// pin the handoff: the mirror never opens while a motion_camera owner is
// live or closing, and a motion_camera start waits until the mirror has let
// the camera go.
//
// Nothing here runs a real camera: the screen tests use a scripted
// MirrorCamera and the DeviceMirrorCamera tests a scripted CameraPlatform.
// The claim is "the handoff and release run as written", never "the camera
// works on a phone"; that is the founder's TestFlight check.
import 'dart:async';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/camera_session.dart';
import 'package:ostinato/app/practice/camera/camera_lesson_copy.dart';
import 'package:ostinato/app/practice/camera/mirror_camera.dart';
import 'package:ostinato/app/practice/camera/mirror_hold_screen.dart';
import 'package:ostinato/app/practice/loop/practice_progress_store.dart';
import 'package:ostinato/app/practice/loop/v1_course_catalog.dart';
import 'package:ostinato/app/practice/loop/v1_lesson_reader_screen.dart';
import 'package:ostinato_posture/ostinato_posture.dart';
import 'package:permission_handler/permission_handler.dart';

import 'fixtures/owned_camera_native_fixture.dart';
import 'support/practice_host.dart';

final class _MemoryChecks implements V1LessonChecks {
  @override
  Future<Map<String, V1LessonCheck>> load() async => const {};

  @override
  Future<V1LessonCheck> record(
    String lessonId,
    V1CheckEvidence evidence, {
    DateTime? at,
  }) async => V1LessonCheck(
    lessonId: lessonId,
    evidence: evidence,
    at: at ?? DateTime.utc(2026, 11, 4),
  );
}

/// One scripted mirror per opening; [log] is shared across openings.
final class _ScriptMirror implements MirrorCamera {
  _ScriptMirror(this.log, this.result);

  final List<String> log;
  final SurfaceState? result;
  bool closed = false;

  @override
  Future<SurfaceState?> open() async {
    log.add('open');
    return result;
  }

  @override
  Widget preview() => const SizedBox(key: Key('script-preview'), height: 40);

  @override
  Future<void> close() async {
    if (closed) return;
    closed = true;
    log.add('close');
  }
}

/// A camera platform the test drives: it counts creates and disposes and can
/// hold initialize open.
final class _ScriptPlatform extends CameraPlatform {
  final log = <String>[];
  Completer<void>? initializeGate;
  Object? disposeError;
  final _initialized = StreamController<CameraInitializedEvent>.broadcast();

  static const front = CameraDescription(
    name: 'front',
    lensDirection: CameraLensDirection.front,
    sensorOrientation: 270,
  );
  static const back = CameraDescription(
    name: 'back',
    lensDirection: CameraLensDirection.back,
    sensorOrientation: 90,
  );

  @override
  Future<List<CameraDescription>> availableCameras() async => [back, front];

  @override
  Future<int> createCameraWithSettings(
    CameraDescription cameraDescription,
    MediaSettings mediaSettings,
  ) async {
    log.add(
      'create ${cameraDescription.name} audio=${mediaSettings.enableAudio}',
    );
    return 7;
  }

  @override
  Stream<CameraInitializedEvent> onCameraInitialized(int cameraId) =>
      _initialized.stream;

  // Never emits and never closes: `first` on an empty stream would throw.
  final _errors = StreamController<CameraErrorEvent>.broadcast();

  @override
  Stream<CameraErrorEvent> onCameraError(int cameraId) => _errors.stream;

  @override
  Stream<DeviceOrientationChangedEvent> onDeviceOrientationChanged() =>
      const Stream<DeviceOrientationChangedEvent>.empty();

  @override
  Future<void> initializeCamera(
    int cameraId, {
    ImageFormatGroup imageFormatGroup = ImageFormatGroup.unknown,
  }) async {
    log.add('initialize');
    await initializeGate?.future;
    scheduleMicrotask(
      () => _initialized.add(
        const CameraInitializedEvent(
          7,
          640,
          480,
          ExposureMode.auto,
          true,
          FocusMode.auto,
          true,
        ),
      ),
    );
  }

  @override
  Widget buildPreview(int cameraId) => const SizedBox();

  @override
  Future<void> dispose(int cameraId) async {
    log.add('dispose');
    if (disposeError case final error?) throw error;
  }
}

/// Runs [work] and reports whether it finished within a few event-loop turns.
Future<bool> _settles(Future<void> work) async {
  var done = false;
  unawaited(work.then((_) => done = true, onError: (_) => done = true));
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
  return done;
}

const _hand = 'gtr-s1-m01-03';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('mirror screen (scripted camera)', () {
    Widget host(List<String> log, {SurfaceState? result, int seconds = 30}) =>
        practiceHost(
          MirrorHoldScreen(
            title: 'Pick and fretting hand',
            holdSeconds: seconds,
            camera: () => _ScriptMirror(log, result),
          ),
        );

    testWidgets('live: the preview and the no-hint line, nothing else', (
      tester,
    ) async {
      final log = <String>[];
      await tester.pumpWidget(host(log));
      await tester.pump();
      expect(log, ['open']);
      expect(find.byKey(const Key('mirror-preview')), findsOneWidget);
      expect(find.text(CameraLessonCopy.mirrorLive.$1), findsOneWidget);
      expect(find.text('30 s left'), findsOneWidget);
      // No hint text of any kind on the mirror.
      expect(find.text(CameraLessonCopy.watching.$1), findsNothing);
      expect(find.byKey(const Key('camera-hold-hint')), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the hold ends after its seconds and releases once', (
      tester,
    ) async {
      final log = <String>[];
      await tester.pumpWidget(host(log, seconds: 30));
      await tester.pump();
      await tester.pump(const Duration(seconds: 29));
      expect(find.text('1 s left'), findsOneWidget);
      expect(log, ['open']);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text(CameraLessonCopy.timeUp.$1), findsOneWidget);
      expect(find.byKey(const Key('mirror-preview')), findsNothing);
      expect(log, ['open', 'close']);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpWidget(const SizedBox());
      expect(log, ['open', 'close'], reason: 'no second close, no reopen');
    });

    testWidgets('leaving mid-hold releases the camera', (tester) async {
      final log = <String>[];
      await tester.pumpWidget(host(log));
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpWidget(const SizedBox());
      expect(log, ['open', 'close']);
    });

    testWidgets('background releases; the foreground reopens; time pauses', (
      tester,
    ) async {
      final log = <String>[];
      await tester.pumpWidget(host(log));
      await tester.pump(const Duration(seconds: 5));
      expect(find.text('25 s left'), findsOneWidget);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(log, ['open'], reason: 'a permission dialog is only inactive');

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      // No frames are drawn in the background; the timer still fires.
      await tester.pump(const Duration(seconds: 10));
      expect(log, ['open', 'close']);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(log, ['open', 'close', 'open']);
      expect(find.byKey(const Key('mirror-preview')), findsOneWidget);
      expect(find.text('25 s left'), findsOneWidget, reason: 'time paused');
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('24 s left'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      expect(log, ['open', 'close', 'open', 'close']);
    });

    testWidgets('permission refused for good: says so, offers Settings', (
      tester,
    ) async {
      final log = <String>[];
      await tester.pumpWidget(
        host(log, result: const PermissionDeniedPermanent()),
      );
      await tester.pump();
      expect(find.text(CameraLessonCopy.denied.$1), findsOneWidget);
      expect(find.byKey(const Key('mirror-hold-settings')), findsOneWidget);
      expect(find.byKey(const Key('mirror-preview')), findsNothing);
      expect(log, ['open', 'close']);
      await tester.pump(const Duration(seconds: 40));
      expect(find.text('30 s left'), findsOneWidget, reason: 'no mirror');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a first refusal is not asked again on every return', (
      tester,
    ) async {
      final log = <String>[];
      await tester.pumpWidget(
        host(log, result: const PermissionDeniedRetriable()),
      );
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(log, ['open', 'close']);
      expect(find.text(CameraLessonCopy.denied.$1), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('busy or broken camera: says so, no preview', (tester) async {
      final log = <String>[];
      await tester.pumpWidget(
        host(log, result: const CameraUnavailable('camera-busy')),
      );
      await tester.pump();
      expect(find.text(CameraLessonCopy.unavailable.$1), findsOneWidget);
      expect(find.byKey(const Key('mirror-preview')), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the reader opens the mirror only on the tap', (tester) async {
      tester.view.physicalSize = const Size(900, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final gtr = await tester.runAsync(V1CourseCatalog.load);
      final log = <String>[];
      await tester.pumpWidget(
        practiceHost(
          V1LessonReaderScreen(
            lesson: gtr!.lesson(_hand)!,
            checks: _MemoryChecks(),
            cameraLessonsOpen: true,
            mirrorCamera: () => _ScriptMirror(log, null),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(log, isEmpty, reason: 'no camera before the tap');

      await tester.tap(find.byKey(const Key('v1-reader-mirror')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(MirrorHoldScreen), findsOneWidget);
      expect(log, ['open']);

      await tester.tap(find.byKey(const Key('mirror-hold-back')));
      await tester.pumpAndSettle();
      expect(find.byType(MirrorHoldScreen), findsNothing);
      expect(log, ['open', 'close']);
    });
  });

  group('one camera at a time (DeviceMirrorCamera)', () {
    late _ScriptPlatform platform;
    late List<String> asks;
    late PermissionStatus answer;
    late CameraPlatform previous;

    setUp(() {
      resetCameraSessionForTesting();
      previous = CameraPlatform.instance;
      platform = _ScriptPlatform();
      CameraPlatform.instance = platform;
      asks = [];
      answer = PermissionStatus.granted;
    });
    tearDown(() {
      CameraPlatform.instance = previous;
      resetCameraSessionForTesting();
    });

    DeviceMirrorCamera mirror() => DeviceMirrorCamera(
      requestPermission: () async {
        asks.add('permission');
        return answer;
      },
    );

    test('opens the front lens, no audio, and holds the barrier', () async {
      final m = mirror();
      expect(await m.open(), isNull);
      expect(platform.log, ['create front audio=false', 'initialize']);
      expect(cameraClosingPending, isTrue, reason: 'held while open');

      // A motion_camera start drains closures first: it waits for the mirror.
      final motionStart = awaitPendingClose();
      expect(await _settles(motionStart), isFalse);

      await m.close();
      expect(platform.log.last, 'dispose');
      expect(await _settles(motionStart), isTrue);
    });

    test('a live motion_camera owner keeps the mirror shut', () async {
      final fixture = OwnedCameraNativeFixture();
      final owner = registerCameraOwner(
        fixture.controller,
        lifecycle: ValueNotifier(AppLifecycleState.resumed),
      );
      addTearDown(owner.retire);
      expect(cameraOwnedElsewhere, isTrue);

      final m = mirror();
      expect(await m.open(), const CameraUnavailable('camera-busy'));
      expect(asks, isEmpty, reason: 'not even a permission prompt');
      expect(platform.log, isEmpty);
    });

    test('a pending closure is drained before the mirror opens', () async {
      final closing = Completer<void>();
      noteClosing(closing.future);
      final m = mirror();
      final opened = m.open();
      expect(await _settles(opened), isFalse);
      expect(platform.log, isEmpty, reason: 'no create over a closing camera');
      closing.complete();
      expect(await opened, isNull);
      expect(platform.log.first, 'create front audio=false');
      await m.close();
    });

    test('closing during initialize releases once and opens nothing', () async {
      platform.initializeGate = Completer<void>();
      final m = mirror();
      final opened = m.open();
      await _settles(Future<void>.value());
      expect(platform.log, ['create front audio=false', 'initialize']);
      final closed = m.close();
      platform.initializeGate!.complete();
      expect(await opened, const CameraUnavailable('camera-busy'));
      await closed;
      expect(platform.log.where((e) => e == 'dispose'), hasLength(1));
      expect(await _settles(awaitPendingClose()), isTrue, reason: 'released');
    });

    test('refused permission: no camera is created', () async {
      answer = PermissionStatus.permanentlyDenied;
      final m = mirror();
      expect(await m.open(), const PermissionDeniedPermanent());
      expect(platform.log, isEmpty);
      expect(cameraClosingPending, isFalse, reason: 'never held');
    });

    test('an app boundary releases an open mirror', () async {
      final m = mirror();
      expect(await m.open(), isNull);
      retireAllCameraOwners();
      await _settles(Future<void>.value());
      expect(platform.log.last, 'dispose');
      expect(await _settles(awaitPendingClose()), isTrue, reason: 'released');
    });

    test('a failed release quarantines the camera for both stacks', () async {
      platform.disposeError = StateError('native close failed');
      final m = mirror();
      expect(await m.open(), isNull);
      await expectLater(m.close(), throwsStateError);
      await expectLater(awaitPendingClose(), throwsA(isA<Object>()));
      expect(await mirror().open(), const SetupFailed('mirror-start-failed'));
    });
  });
}
