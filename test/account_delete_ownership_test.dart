import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motion_account/motion_account.dart';
import 'package:ostinato/app/account_data_directory.dart';
import 'package:ostinato/app/account_data_operations.dart';
import 'package:ostinato/app/audio/practice_audio_lease.dart';
import 'package:ostinato/app/audio/practice_audio_root.dart';
import 'package:ostinato/app/session_store.dart';

import 'support/account_delete_fixture.dart';
import 'support/fake_practice_audio_port.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('same-token initialSession before replay cannot spend the old page', (
  ) async {
    late Future<void> replacement;
    late Future<void> rejected;
    late int before;
    late bool replacementPrecededAuthNotification;
    final h = await AccountDeleteFixture.create(
      beforeAuthReplay: (fixture) {
        final page = fixture.pageClient();
        before = fixture.ownership.revision;
        // Actual GoTrue parses a new Session and installs it synchronously,
        // even though both its strings match and public events remain queued.
        replacement = fixture.replace(aliceUuid, 'A-session1');
        replacementPrecededAuthNotification =
            fixture.ownership.revision == before;
        rejected = expectLater(
          page.deleteCommonAccount(afterRemoteDelete: fixture.clearLocal),
          throwsStateError,
        );
      },
    );
    addTearDown(h.close);
    await replacement;
    await rejected;
    expect(replacementPrecededAuthNotification, isTrue);
    expect(h.ownership.revision, greaterThan(before));
    expect(h.transport.deleteRequests, isEmpty);
    expect(h.runtime.userId.value, aliceUuid);
    expect(h.runtime.phase.value, MotionIdentityPhase.verified);
    // The new page is usable after that actual event is observed. The guard
    // must not convert replay safety into permanent account deletion denial.
    await h.pageClient().deleteCommonAccount(afterRemoteDelete: h.clearLocal);
    expect(h.transport.deleteCalls, 1);
  });

  for (final transition in ['fresh-same-UUID', 'A-null-A-same-token', 'A-B']) {
    testWidgets('old deletion dialog cannot dispatch after $transition', (
      tester,
    ) async {
      final h = (await tester.runAsync(
        () => AccountDeleteFixture.create(delayed: true),
      ))!;
      try {
        final page = h.pageClient();
        await tester.pumpWidget(
          MaterialApp(
            home: MotionAccountPage(
              account: page,
              // Dialog admission is tested here; actual UUID file cleanup is
              // exercised by delayed-response and admitted-write tests below.
              clearLocalData: (_) async {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete Motion account'));
        await tester.pumpAndSettle();
        expect(
          find.widgetWithText(FilledButton, 'Delete account'),
          findsOneWidget,
        );

        await tester.runAsync(() async {
          if (transition == 'A-null-A-same-token') await h.signOut();
          await h.replace(
            transition == 'A-B' ? bobUuid : aliceUuid,
            transition == 'A-B'
                ? 'B-session2'
                : transition == 'A-null-A-same-token'
                ? 'A-session1'
                : 'A-session2',
          );
        });
        // No replacement frame is pumped before the old dialog's action.
        if (transition == 'fresh-same-UUID') {
          expect(h.runtime.userId.value, aliceUuid);
          expect(h.runtime.phase.value, MotionIdentityPhase.verified);
          expect(h.runtime.passwordRecovery.value, isFalse);
        }
        await tester.tap(find.widgetWithText(FilledButton, 'Delete account'));
        // First stamp the reverse transition's start frame, then advance past
        // it and flush the removal frame. The pending actual Core request keeps
        // its progress indicator animating, so pumpAndSettle is invalid here.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump();
        for (var attempt = 0; attempt < 20; ++attempt) {
          await tester.runAsync(() async {
            await Future<void>.delayed(const Duration(milliseconds: 1));
          });
          await tester.pump(const Duration(milliseconds: 5));
          if (h.transport.deleteRequests.isNotEmpty) break;
        }
        expect(find.byType(AlertDialog), findsNothing);
        if (h.coreDeleteCalls != 0) {
          expect(
            h.transport.deleteRequests.length,
            h.coreDeleteCalls,
            reason: 'Every admitted real Core delete must reach the HTTP recorder',
          );
        }
        // The response is still held. Legacy same-UUID/ABA must fail 1 vs 0
        // here, before cleanup/sign-out or test teardown can alter the session.
        expect(h.transport.deleteRequests.length, 0);
        expect(
          h.client.auth.currentUser?.id,
          transition == 'A-B' ? bobUuid : aliceUuid,
        );
      } finally {
        // Unmount first so the late _run completion cannot touch old UI. Then
        // release the held response and drain actual Core sign-out in both zones.
        await tester.pumpWidget(const SizedBox());
        h.transport.confirm();
        for (
          var attempt = 0;
          attempt < 40 && h.coreDeletesSettled != h.coreDeleteCalls;
          ++attempt
        ) {
          await tester.runAsync(() async {
            await Future<void>.delayed(const Duration(milliseconds: 1));
          });
          await tester.pump(const Duration(milliseconds: 5));
        }
        expect(
          h.coreDeletesSettled,
          h.coreDeleteCalls,
          reason: 'Held actual Core requests must finish before fixture disposal',
        );
        await tester.runAsync(h.close);
      }
    });
  }

  test('actual same-token sign-in retires an old page before HTTP dispatch', (
  ) async {
    final h = await AccountDeleteFixture.create();
    addTearDown(h.close);
    final oldPage = h.pageClient();
    final before = h.ownership.revision;
    await h.signIn(aliceUuid, 'A-session1');
    expect(h.ownership.revision, greaterThan(before));
    expect(h.runtime.userId.value, aliceUuid);
    expect(h.runtime.phase.value, MotionIdentityPhase.verified);
    expect(h.client.auth.currentSession?.accessToken, 'A-session1');
    await expectLater(
      oldPage.deleteCommonAccount(afterRemoteDelete: h.clearLocal),
      throwsStateError,
    );
    expect(h.transport.deleteRequests, isEmpty);
    expect(h.client.auth.currentSession?.accessToken, 'A-session1');
  });

  for (final replacement in [bobUuid, aliceUuid]) {
    test(
      replacement == aliceUuid
          ? 'verified A cleanup drains fresh A resources and preserves replacement Auth'
          : 'verified A cleanup preserves disjoint B resources and Auth',
      () async {
        final h = await AccountDeleteFixture.create(delayed: true);
        addTearDown(h.close);
        await h.seedFiles();
        final deletion = h.pageClient().deleteCommonAccount(
          afterRemoteDelete: h.clearLocal,
        );
        await h.transport.started.future;
        expect(h.transport.deleteAuthorization, 'Bearer A-session1');
        expect(h.transport.deleteBody?['expectedUserId'], aliceUuid);
        await h.replace(
          replacement,
          replacement == bobUuid ? 'B-session2' : 'A-session2',
        );

        final port = FakePracticeAudioPort();
        final owner = PracticeAudioRootOwner(
          userId: h.runtime.userId,
          phase: h.runtime.phase,
          passwordRecovery: h.runtime.passwordRecovery,
          identityBoundary: h.ownership,
          resourceAdmission: h.ownership,
          lease: PracticeAudioLease(port: port),
          initialLifecycleState: AppLifecycleState.resumed,
          allowDetachedRouteEventsForTest: true,
          allowAcquisition: true,
        );
        addTearDown(() async {
          owner.dispose();
          await owner.lastFenceForTest;
        });
        final observer = PracticeAudioRouteObserver(owner);
        final route = MaterialPageRoute<void>(builder: (_) => const SizedBox());
        owner.attachNavigator(observer);
        observer.didPush(route, null);
        await owner.lastFenceForTest;
        final acquired = await owner.acquire(
          owner.grantFor(route)!,
          PracticeAudioSide.input,
        );
        expect(acquired.status, AudioRouteAcquireStatus.acquired);
        final closesBefore = port.closeCalls;
        var lateRetirements = 0;
        h.ownership.addListener(() => ++lateRetirements);

        h.transport.confirm();
        await deletion;
        expect(await accountDataDirectory(h.root, aliceUuid).exists(), isFalse);
        expect(
          await File(
            '${accountDataDirectory(h.root, bobUuid).path}/sentinel.txt',
          ).readAsString(),
          bobUuid,
        );
        expect(
          await File('${h.root.path}/guest.txt').readAsString(),
          'guest-preserved',
        );
        expect(h.client.auth.currentUser?.id, replacement);
        expect(
          h.client.auth.currentSession?.accessToken,
          replacement == bobUuid ? 'B-session2' : 'A-session2',
        );
        expect(lateRetirements, replacement == aliceUuid ? 1 : 0);
        expect(port.closeCalls, closesBefore + (replacement == aliceUuid ? 1 : 0));
        expect(
          owner.grantFor(route),
          replacement == aliceUuid ? isNull : isNotNull,
          reason: 'Confirmed UUID A denial spans E0 and E1; B stays disjoint',
        );
      },
    );
  }

  test('current confirmation retires before admitted IO finishes exactly once', (
  ) async {
    final h = await AccountDeleteFixture.create(delayed: true);
    addTearDown(h.close);
    await h.seedFiles();
    final entered = Completer<void>();
    final releaseWriter = Completer<void>();
    final cleanupEntered = Completer<void>();
    final erased = Completer<void>();
    final releaseCleanup = Completer<void>();
    final retained = SessionStore(
      directoryProvider: () async => h.root,
      accountUserId: aliceUuid,
    );
    final owned = accountDataDirectory(h.root, aliceUuid);
    final operations = AccountDataOperations(() async => owned);
    final admitted = operations.run((directory) async {
      entered.complete();
      await releaseWriter.future;
      await File('${directory.path}/admitted.txt').writeAsString('finished');
    }, writing: true);
    await entered.future;
    var notifications = 0;
    h.ownership.addListener(() => ++notifications);
    var cleanupDone = false;
    final deletion = h.pageClient().deleteCommonAccount(
      afterRemoteDelete: (id) {
        final cleanup = h.clearLocal(id);
        cleanupEntered.complete();
        return cleanup.then<void>((_) async {
          erased.complete();
          await releaseCleanup.future;
          cleanupDone = true;
        });
      },
    );
    await h.transport.started.future;
    h.transport.confirm();
    await cleanupEntered.future;
    try {
      expect(cleanupDone, isFalse);
      expect(notifications, 1);
      final saved = PersistedSession(
        schemaVersion: PersistedSession.currentSchemaVersion,
        disciplineId: 'guitar',
        lessonId: 'retained-after-confirmation',
        completedAt: DateTime.utc(2026, 10, 2),
        elapsedSeconds: 30,
        sampleCount: 3,
        outCount: 0,
      );
      final retainedRejected = expectLater(retained.save(saved), throwsStateError);
      final freshRejected = expectLater(
        SessionStore(
          directoryProvider: () async => h.root,
          accountUserId: aliceUuid,
        ).save(saved),
        throwsStateError,
      );
      await h.replace(bobUuid, 'B-session2');
      final beforeCompletion = notifications;
      releaseWriter.complete();
      await admitted;
      await erased.future;
      await retainedRejected;
      await freshRejected;
      expect(cleanupDone, isFalse);
      releaseCleanup.complete();
      await deletion;
      expect(notifications, beforeCompletion);
      expect(h.client.auth.currentUser?.id, bobUuid);
      expect(await owned.exists(), isFalse);
      expect(
        await File(
          '${accountDataDirectory(h.root, bobUuid).path}/sentinel.txt',
        ).readAsString(),
        bobUuid,
      );
    } finally {
      if (!releaseWriter.isCompleted) releaseWriter.complete();
      if (!releaseCleanup.isCompleted) releaseCleanup.complete();
      await admitted;
      await deletion;
    }
  });

  test('current confirmed cleanup denies a fresh route before sign-out', (
  ) async {
    final h = await AccountDeleteFixture.create(delayed: true);
    addTearDown(h.close);
    await h.seedFiles();
    final port = FakePracticeAudioPort();
    final owner = PracticeAudioRootOwner(
      userId: h.runtime.userId,
      phase: h.runtime.phase,
      passwordRecovery: h.runtime.passwordRecovery,
      identityBoundary: h.ownership,
      resourceAdmission: h.ownership,
      lease: PracticeAudioLease(port: port),
      initialLifecycleState: AppLifecycleState.resumed,
      allowDetachedRouteEventsForTest: true,
      allowAcquisition: true,
    );
    final initialObserver = PracticeAudioRouteObserver(owner);
    final initialRoute = MaterialPageRoute<void>(builder: (_) => const SizedBox());
    owner.attachNavigator(initialObserver);
    initialObserver.didPush(initialRoute, null);
    await owner.lastFenceForTest;
    final cleanupHeld = Completer<void>();
    final releaseCleanup = Completer<void>();
    final deletion = h.pageClient().deleteCommonAccount(
      afterRemoteDelete: (id) {
        final erase = h.clearLocal(id);
        return erase.then<void>((_) async {
          cleanupHeld.complete();
          await releaseCleanup.future;
        });
      },
    );
    await h.transport.started.future;
    h.transport.confirm();
    await cleanupHeld.future;
    try {
      // These are actual Core runtime/session values. It signs out only after
      // the host callback completes; no fake phase or duplicate gate is used.
      expect(h.runtime.userId.value, aliceUuid);
      expect(h.runtime.phase.value, MotionIdentityPhase.verified);
      expect(h.client.auth.currentSession?.accessToken, 'A-session1');
      expect(await accountDataDirectory(h.root, aliceUuid).exists(), isFalse);
      expect(releaseCleanup.isCompleted, isFalse);

      // Mirror Main installing a fresh Navigator after retirement. Wait for its
      // actual app lease fence so a pending fence cannot hide the admission hole.
      owner.detachNavigator(initialObserver);
      final freshObserver = PracticeAudioRouteObserver(owner);
      final freshRoute = MaterialPageRoute<void>(builder: (_) => const SizedBox());
      owner.attachNavigator(freshObserver);
      freshObserver.didPush(freshRoute, null);
      await owner.lastFenceForTest;
      final freshGrant = owner.grantFor(freshRoute);
      final result = freshGrant == null
          ? const AudioRouteAcquireResult(AudioRouteAcquireStatus.unavailable)
          : await owner.acquire(freshGrant, PracticeAudioSide.input);
      // Old behavior actually opens the fake native port here. GREEN must deny
      // before opening while the exact current deletion cleanup is still held.
      expect(port.opens, isEmpty);
      expect(result.status, AudioRouteAcquireStatus.unavailable);
      expect(owner.grantFor(freshRoute), isNull);
      expect(releaseCleanup.isCompleted, isFalse);
    } finally {
      if (!releaseCleanup.isCompleted) releaseCleanup.complete();
      await deletion;
      owner.dispose();
      await owner.lastFenceForTest;
    }
  });

  test('non-200 response with a valid-looking receipt neither erases nor retires', (
  ) async {
    final h = await AccountDeleteFixture.create();
    addTearDown(h.close);
    await h.seedFiles();
    h.transport.receiptStatus = 403;
    var notifications = 0;
    h.ownership.addListener(() => ++notifications);
    await expectLater(
      h.pageClient().deleteCommonAccount(afterRemoteDelete: h.clearLocal),
      throwsA(anything),
    );
    expect(h.transport.deleteCalls, 1);
    expect(notifications, 0);
    expect(h.ownership.value, isTrue);
    expect(await accountDataDirectory(h.root, aliceUuid).exists(), isTrue);
    expect(h.client.auth.currentSession?.accessToken, 'A-session1');
  });

  test('refresh during held HTTP retires captured resources and preserves Auth', (
  ) async {
    final h = await AccountDeleteFixture.create(delayed: true);
    addTearDown(h.close);
    await h.seedFiles();
    final retained = SessionStore(
      directoryProvider: () async => h.root,
      accountUserId: aliceUuid,
    );
    final port = FakePracticeAudioPort();
    final owner = PracticeAudioRootOwner(
      userId: h.runtime.userId,
      phase: h.runtime.phase,
      passwordRecovery: h.runtime.passwordRecovery,
      identityBoundary: h.ownership,
      resourceAdmission: h.ownership,
      lease: PracticeAudioLease(port: port),
      initialLifecycleState: AppLifecycleState.resumed,
      allowDetachedRouteEventsForTest: true,
      allowAcquisition: true,
    );
    final observer = PracticeAudioRouteObserver(owner);
    final route = MaterialPageRoute<void>(builder: (_) => const SizedBox());
    owner.attachNavigator(observer);
    observer.didPush(route, null);
    await owner.lastFenceForTest;
    final acquired = await owner.acquire(
      owner.grantFor(route)!,
      PracticeAudioSide.input,
    );
    expect(acquired.status, AudioRouteAcquireStatus.acquired);
    final before = h.ownership.revision;
    final cleanupStarted = Completer<void>();
    final erased = Completer<void>();
    final releaseCleanup = Completer<void>();
    final deletion = h.pageClient().deleteCommonAccount(
      afterRemoteDelete: (id) {
        final erase = h.clearLocal(id);
        cleanupStarted.complete();
        return erase.then<void>((_) async {
          erased.complete();
          await releaseCleanup.future;
        });
      },
    );
    await h.transport.started.future;
    try {
      expect(h.transport.deleteAuthorization, 'Bearer A-session1');
      await h.client.auth.refreshSession('local-refresh');
      await Future<void>.delayed(Duration.zero);
      await h.runtime.refreshIdentity();
      expect(h.client.auth.currentSession?.accessToken, 'A-refreshed');
      expect(h.ownership.revision, before);
      expect(owner.grantFor(route), isNotNull);
      expect(port.closeCalls, 0);
      h.transport.confirm();
      await cleanupStarted.future;
      expect(h.ownership.revision, before + 1);
      expect(h.ownership.value, isFalse);
      expect(owner.grantFor(route), isNull);
      expect(releaseCleanup.isCompleted, isFalse);
      final saved = PersistedSession(
        schemaVersion: PersistedSession.currentSchemaVersion,
        disciplineId: 'guitar',
        lessonId: 'refreshed-after-confirmed-delete',
        completedAt: DateTime.utc(2026, 10, 2),
        elapsedSeconds: 30,
        sampleCount: 3,
        outCount: 0,
      );
      await expectLater(retained.save(saved), throwsStateError);
      await expectLater(
        SessionStore(
          directoryProvider: () async => h.root,
          accountUserId: aliceUuid,
        ).save(saved),
        throwsStateError,
      );
      await owner.lastFenceForTest;
      expect(port.closeCalls, 1);
      await erased.future;
      expect(await accountDataDirectory(h.root, aliceUuid).exists(), isFalse);
      final freshObserver = PracticeAudioRouteObserver(owner);
      final freshRoute = MaterialPageRoute<void>(builder: (_) => const SizedBox());
      owner.attachNavigator(freshObserver);
      freshObserver.didPush(freshRoute, null);
      await owner.lastFenceForTest;
      expect(owner.grantFor(freshRoute), isNull);
      expect(port.opens, [PracticeAudioSide.input]);
      releaseCleanup.complete();
      await deletion;
      expect(h.ownership.revision, before + 1);
      expect(h.ownership.value, isFalse);
      expect(h.client.auth.currentUser?.id, aliceUuid);
      expect(h.client.auth.currentSession?.accessToken, 'A-refreshed');
      expect(
        await File('${h.root.path}/guest.txt').readAsString(),
        'guest-preserved',
      );
      expect(
        await File('${accountDataDirectory(h.root, bobUuid).path}/sentinel.txt').readAsString(),
        bobUuid,
      );
    } finally {
      h.transport.confirm();
      if (!releaseCleanup.isCompleted) releaseCleanup.complete();
      await deletion;
      owner.dispose();
      await owner.lastFenceForTest;
    }
  });

  test('confirmed UUID denial survives refresh and actual same-A sign-in', (
  ) async {
    final h = await AccountDeleteFixture.create(delayed: true);
    addTearDown(h.close);
    await h.seedFiles();
    final cleanupHeld = Completer<void>();
    final releaseCleanup = Completer<void>();
    final deletion = h.pageClient().deleteCommonAccount(
      afterRemoteDelete: (id) => h.clearLocal(id).then<void>((_) async {
        cleanupHeld.complete();
        await releaseCleanup.future;
      }),
    );
    await h.transport.started.future;
    h.transport.confirm();
    await cleanupHeld.future;
    final port = FakePracticeAudioPort();
    final owner = PracticeAudioRootOwner(
      userId: h.runtime.userId,
      phase: h.runtime.phase,
      passwordRecovery: h.runtime.passwordRecovery,
      identityBoundary: h.ownership,
      resourceAdmission: h.ownership,
      lease: PracticeAudioLease(port: port),
      initialLifecycleState: AppLifecycleState.resumed,
      allowDetachedRouteEventsForTest: true,
      allowAcquisition: true,
    );
    try {
      final deniedObserver = PracticeAudioRouteObserver(owner);
      final deniedRoute = MaterialPageRoute<void>(builder: (_) => const SizedBox());
      owner.attachNavigator(deniedObserver);
      deniedObserver.didPush(deniedRoute, null);
      await owner.lastFenceForTest;
      expect(h.ownership.value, isFalse);
      expect(owner.grantFor(deniedRoute), isNull);
      final beforeRefresh = h.ownership.revision;
      await h.client.auth.refreshSession('local-refresh');
      await Future<void>.delayed(Duration.zero);
      await h.runtime.refreshIdentity();
      expect(h.client.auth.currentSession?.accessToken, 'A-refreshed');
      expect(h.ownership.revision, beforeRefresh);
      expect(h.ownership.value, isFalse);
      expect(owner.grantFor(deniedRoute), isNull);
      expect(port.opens, isEmpty);

      // Actual shared signIn calls actual GoTrue's password method; only its
      // HTTP transport is mocked. Replacement Auth is independent of the
      // permanent data/media denial; this grants no positive same-A proof.
      await h.signIn(aliceUuid, 'A-session2');
      expect(h.ownership.value, isFalse);
      expect(h.ownership.revision, greaterThan(beforeRefresh));
      owner.detachNavigator(deniedObserver);
      final successorObserver = PracticeAudioRouteObserver(owner);
      final successorRoute = MaterialPageRoute<void>(builder: (_) => const SizedBox());
      owner.attachNavigator(successorObserver);
      successorObserver.didPush(successorRoute, null);
      await owner.lastFenceForTest;
      expect(owner.grantFor(successorRoute), isNull);
      expect(port.opens, isEmpty);
      // Raw Session succession never clears the verified UUID's tombstone.
      await expectLater(
        SessionStore(
          directoryProvider: () async => h.root,
          accountUserId: aliceUuid,
        ).save(
          PersistedSession(
            schemaVersion: PersistedSession.currentSchemaVersion,
            disciplineId: 'guitar',
            lessonId: 'fresh-A-after-confirmed-delete',
            completedAt: DateTime.utc(2026, 10, 2),
            elapsedSeconds: 30,
            sampleCount: 3,
            outCount: 0,
          ),
        ),
        throwsStateError,
      );
      final beforeCompletion = h.ownership.revision;
      final closesBefore = port.closeCalls;
      releaseCleanup.complete();
      await deletion;
      expect(h.ownership.revision, beforeCompletion);
      expect(port.closeCalls, closesBefore);
      expect(owner.grantFor(successorRoute), isNull);
      expect(h.client.auth.currentSession?.accessToken, 'A-session2');
      expect(await accountDataDirectory(h.root, aliceUuid).exists(), isFalse);
      expect(
        await File('${h.root.path}/guest.txt').readAsString(),
        'guest-preserved',
      );
      expect(
        await File('${accountDataDirectory(h.root, bobUuid).path}/sentinel.txt').readAsString(),
        bobUuid,
      );
    } finally {
      if (!releaseCleanup.isCompleted) releaseCleanup.complete();
      await deletion;
      owner.dispose();
      await owner.lastFenceForTest;
    }
  });

  for (final badReceipt in [
    <String, Object>{'deleted': true},
    <String, Object>{'deleted': true, 'userId': bobUuid},
    <String, Object>{'deleted': false, 'userId': aliceUuid},
  ]) {
    test('unconfirmed receipt neither erases nor retires $badReceipt', () async {
      final h = await AccountDeleteFixture.create();
      addTearDown(h.close);
      await h.seedFiles();
      h.transport.receipt = badReceipt;
      var notifications = 0;
      h.ownership.addListener(() => ++notifications);
      await expectLater(
        h.pageClient().deleteCommonAccount(afterRemoteDelete: h.clearLocal),
        throwsA(anything),
      );
      expect(h.transport.deleteCalls, 1);
      expect(notifications, 0);
      expect(await accountDataDirectory(h.root, aliceUuid).exists(), isTrue);
      expect(h.client.auth.currentUser?.id, aliceUuid);
    });
  }

  test('ordinary token refresh retains page and starts with refreshed token', (
  ) async {
    final h = await AccountDeleteFixture.create(delayed: true);
    addTearDown(h.close);
    final page = h.pageClient();
    final beforeRefresh = h.ownership.revision;
    await h.client.auth.refreshSession('local-refresh');
    await Future<void>.delayed(Duration.zero);
    await h.runtime.refreshIdentity();
    expect(h.ownership.revision, beforeRefresh);
    final deletion = page.deleteCommonAccount(afterRemoteDelete: h.clearLocal);
    await h.transport.started.future;
    expect(h.transport.deleteAuthorization, 'Bearer A-refreshed');
    h.transport.confirm();
    await deletion;
  });

  test('disposed epoch still erases verified old UUID without notification', (
  ) async {
    final h = await AccountDeleteFixture.create(delayed: true);
    addTearDown(h.close);
    await h.seedFiles();
    var notifications = 0;
    h.ownership.addListener(() => ++notifications);
    final deletion = h.pageClient().deleteCommonAccount(
      afterRemoteDelete: h.clearLocal,
    );
    await h.transport.started.future;
    h.ownership.dispose();
    h.transport.confirm();
    await deletion;
    expect(notifications, 0);
    expect(await accountDataDirectory(h.root, aliceUuid).exists(), isFalse);
    expect(await accountDataDirectory(h.root, bobUuid).exists(), isTrue);
    expect(
      await File('${h.root.path}/guest.txt').readAsString(),
      'guest-preserved',
    );
  });
}
