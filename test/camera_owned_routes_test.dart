import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/account_connection.dart';
import 'package:ostinato/app/camera_pose_source.dart';
import 'package:ostinato/app/camera_session.dart';
import 'package:ostinato/app/content.dart';
import 'package:ostinato/app/cue_text.dart';
import 'package:ostinato/app/design/app_scope.dart';
import 'package:ostinato/app/design/ostinato_theme.dart';
import 'package:ostinato/app/guitar_journey.dart';
import 'package:ostinato/app/onboarding_store.dart';
import 'package:ostinato/app/screens/live_screen.dart';
import 'package:ostinato/app/screens/setup_check_screen.dart';
import 'package:ostinato/main.dart';
import 'package:permission_handler/permission_handler.dart';

import 'fixtures/owned_camera_native_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ContentRepository repo;
  late CueTextResolver cue;
  late Discipline guitar;
  late OwnedCameraNativeFixture native;
  late List<CameraPoseSource> sources;

  setUpAll(() async {
    await GuitarJourneyCourse.load();
    repo = await ContentRepository.load();
    cue = await CueTextResolver.load();
    guitar = repo.disciplines.firstWhere((discipline) => discipline.id == 'guitar');
  });

  setUp(() {
    resetCameraSessionForTesting();
    native = OwnedCameraNativeFixture();
    sources = <CameraPoseSource>[];
  });

  tearDown(() {
    // All async route cleanup runs inside the widget body's finally block.
    native.releaseGates();
    native.dispose();
    resetCameraSessionForTesting();
  });

  CameraPoseSource source({CameraModelPathResolver? model}) {
    final CameraPoseSource result = CameraPoseSource(
      controller: native.controller,
      resolveModelPath: model ?? () async => '/synthetic/live.task',
      requestPermission: () async => PermissionStatus.granted,
    );
    sources.add(result);
    return result;
  }

  Widget harness(Widget child) => ContentRepositoryScope(
    repo: repo,
    cueText: cue,
    child: MaterialApp(theme: ostinatoTheme(), home: child),
  );

  Future<void> drain(WidgetTester tester) async {
    for (var turn = 0; turn < 6; turn++) {
      await tester.runAsync(() async { await Future<void>.delayed(Duration.zero); });
      await tester.pump();
    }
  }

  Future<void> cleanup(WidgetTester tester) async {
    native.releaseGates();
    await tester.pumpWidget(const SizedBox());
    await drain(tester);
    for (final CameraPoseSource owner in sources) {
      final Future<void> closing = owner.stop();
      unawaited(closing.catchError((Object _) {}));
      await settleWidgetCameraWork(tester,
          (owner.startSettlementForTesting ?? Future<void>.value()).catchError((Object _) {}),
          label: 'pending source start');
      await settleWidgetCameraWork(tester, closing.catchError((Object _) {}),
          label: 'first source stop');
      await settleWidgetCameraWork(tester, owner.stop().catchError((Object _) {}),
          label: 'late source stop');
      owner.captureLease.retire();
      await settleWidgetCameraWork(tester, owner.captureLease.close().catchError((Object _) {}),
          label: 'exact lease cleanup');
      await settleWidgetCameraWork(tester, cleanupAfterCameraFault(owner.dispose()),
          label: 'source buses');
    }
    await settleWidgetCameraWork(tester, awaitPendingClose().catchError((Object _) {}),
        label: 'legacy close barrier cleanup');
    resetCameraSessionForTesting();
  }

  void prepareView(WidgetTester tester) {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> sendDwell(WidgetTester tester) async {
    for (var frame = 0; frame < 8; frame++) {
      await native.emit(visible: true, tUs: 100000 * frame + 1);
      await tester.pump();
    }
    await drain(tester);
  }

  testWidgets('setup dwell awaits exact ACK and fresh readback before lesson handoff', (tester) async {
    try {
      prepareView(tester);
      native.ackGate = Completer<void>();
      native.readbackGate = Completer<void>();
      final CameraPoseSource live = source();
      await tester.pumpWidget(harness(SetupCheckScreenRoute(
        discipline: guitar,
        lesson: guitar.starterLesson ?? guitar.lessons.first,
        hue: InstrumentHues.guitar,
        controller: native.controller,
        resolveModelPath: () async => '/synthetic/setup.task',
        requestPermission: () async => PermissionStatus.granted,
        liveSource: live,
      )));
      await drain(tester);
      await sendDwell(tester);
      expect(find.byKey(const Key('setup-room-gap-title')), findsNothing,
          reason: 'dwell is not proof that native capture/models closed');
      expect(find.byType(LiveScreenRoute), findsNothing);
      expect(native.startCalls, hasLength(1));
      native.ackGate!.complete();
      await drain(tester);
      expect(find.byKey(const Key('setup-room-gap-title')), findsNothing,
          reason: 'ACK alone is not a fresh closure readback');
      native.readbackGate!.complete();
      await drain(tester);
      expect(find.byKey(const Key('setup-room-gap-title')), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pump();
      await tester.tap(find.text('Start the lesson'));
      await tester.pumpAndSettle();
      expect(find.byType(LiveScreenRoute), findsOneWidget);
      expect(native.calls('startOwned'), hasLength(2));
      expect(native.activeOwner, live.captureLease.ownerId);
      expect(native.calls('stopOwned'), hasLength(1),
          reason: 'dispose repeats the same exact close Future');
      expect(native.calls('stop'), isEmpty);
      await tester.pumpWidget(const SizedBox());
      await drain(tester);
    } finally {
      await cleanup(tester);
    }
  });

  testWidgets('setup model-close denial never presents calibration or successor action', (tester) async {
    try {
      prepareView(tester);
      native.receiptFault = 'model';
      await tester.pumpWidget(harness(SetupCheckScreenRoute(
        discipline: guitar,
        lesson: guitar.starterLesson ?? guitar.lessons.first,
        hue: InstrumentHues.guitar,
        controller: native.controller,
        resolveModelPath: () async => '/synthetic/setup.task',
        requestPermission: () async => PermissionStatus.granted,
      )));
      await drain(tester);
      await sendDwell(tester);
      expect(find.byKey(const Key('setup-camera-failed')), findsOneWidget);
      expect(find.byKey(const Key('setup-room-gap-title')), findsNothing);
      expect(find.byKey(const Key('setup-stage-passed')), findsNothing);
      expect(find.text('Start the lesson'), findsNothing);
      expect(native.startCalls, hasLength(1));
      await tester.pumpWidget(const SizedBox());
      await drain(tester);
    } finally {
      await cleanup(tester);
    }
  });

  testWidgets('same-UUID recovery, UUID ABA and identity notifications retire pending camera before rebuild', (tester) async {
    try {
      prepareView(tester);
      const String id = '11111111-1111-4111-8111-111111111111';
      final ValueNotifier<String?> userId = ValueNotifier(id);
      final ValueNotifier<bool> recovery = ValueNotifier(false);
      final ValueNotifier<int> identity = ValueNotifier(0);
      addTearDown(userId.dispose);
      addTearDown(recovery.dispose);
      addTearDown(identity.dispose);
      await tester.pumpWidget(OstinatoApp(
        store: InMemoryOnboardingStore(complete: true),
        accountConnection: AccountConnection(
          userId: userId,
          passwordRecovery: recovery,
          identityBoundary: identity,
          pageBuilder: (_) => const Scaffold(body: Text('RECOVERY_FORM')),
        ),
      ));
      for (var attempt = 0; attempt < 60 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty; attempt++) {
        await tester.runAsync(() async { await Future<void>.delayed(const Duration(milliseconds: 5)); });
        await tester.pump();
      }
      await tester.pumpAndSettle();

      for (final String boundary in <String>['recovery', 'uuid-aba', 'identity']) {
        final Completer<String> model = Completer<String>();
        native.extraCleanup.add(() { if (!model.isCompleted) model.complete('/synthetic/$boundary.task'); });
        final CameraPoseSource old = source(model: () => model.future);
        final Future<void> pending = old.start();
        unawaited(pending.catchError((Object _) {}));
        switch (boundary) {
          case 'recovery': recovery.value = true; recovery.value = false;
          case 'uuid-aba': userId.value = null; userId.value = id;
          case 'identity': identity.value++;
        }
        expect(old.captureLease.isRetired, isTrue,
            reason: '$boundary must retire synchronously before any widget pump');
        model.complete('/synthetic/$boundary.task');
        await tester.pump();
        await pending;
        await drain(tester);
        expect(native.startCalls, isEmpty, reason: '$boundary late model cannot reacquire');
      }
      await tester.pumpWidget(const SizedBox());
      await drain(tester);
    } finally {
      await cleanup(tester);
    }
  });

  testWidgets('live retirement removes both retained subscriptions before late native events', (tester) async {
    try {
      prepareView(tester);
      final CameraPoseSource live = source();
      await tester.pumpWidget(harness(LiveScreenRoute(
        discipline: guitar,
        lesson: guitar.starterLesson ?? guitar.lessons.first,
        hue: InstrumentHues.guitar,
        source: live,
        skipCountdown: true,
      )));
      await drain(tester);
      expect(live.hasFrameListeners, isTrue);
      expect(live.hasStatusListeners, isTrue);
      await native.emit(visible: true, tUs: 100);
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      expect(live.captureLease.isRetired, isTrue);
      await drain(tester);
      expect(live.hasFrameListeners, isFalse);
      expect(live.hasStatusListeners, isFalse);
      await native.emit(tUs: 200);
      await native.emitError();
      await drain(tester);
      expect(tester.takeException(), isNull);
      expect(native.calls('stopOwned'), hasLength(1));
      expect(native.calls('stop'), isEmpty);
    } finally {
      await cleanup(tester);
    }
  });

  testWidgets('denied account resource admission blocks a newly pushed real camera route', (tester) async {
    try {
      prepareView(tester);
      final ValueNotifier<String?> userId = ValueNotifier<String?>(
          '11111111-1111-4111-8111-111111111111');
      final ValueNotifier<bool> resourceAdmission = ValueNotifier(true);
      addTearDown(userId.dispose);
      addTearDown(resourceAdmission.dispose);
      await tester.pumpWidget(OstinatoApp(
        store: InMemoryOnboardingStore(complete: true),
        accountConnection: AccountConnection(
          userId: userId,
          identityBoundary: resourceAdmission,
          resourceAdmission: resourceAdmission,
          pageBuilder: (_) => const Scaffold(body: Text('ACCOUNT_FORM')),
        ),
      ));
      for (var attempt = 0; attempt < 60 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty; attempt++) {
        await tester.runAsync(() async { await Future<void>.delayed(const Duration(milliseconds: 5)); });
        await tester.pump();
      }
      await tester.pumpAndSettle();
      resourceAdmission.value = false;
      await tester.pumpAndSettle();
      final CameraPoseSource fresh = source();
      final NavigatorState navigator = tester.state<NavigatorState>(find.byType(Navigator));
      unawaited(navigator.push<void>(MaterialPageRoute<void>(builder: (_) => LiveScreenRoute(
        discipline: guitar,
        lesson: guitar.starterLesson ?? guitar.lessons.first,
        hue: InstrumentHues.guitar,
        source: fresh,
        skipCountdown: true,
      ))));
      await drain(tester);
      expect(find.byType(LiveScreenRoute), findsOneWidget);
      expect(native.startCalls, isEmpty,
          reason: 'retiring existing owners cannot admit a fresh camera while cleanup denies resources');
      expect(native.streamCalls.where((call) => call.method == 'listen'), isEmpty);
      expect(fresh.captureLease.isRetired, isTrue);
    } finally {
      await cleanup(tester);
    }
  });
}
