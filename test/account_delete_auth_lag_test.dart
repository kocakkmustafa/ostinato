import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motion_account/motion_account.dart';
import 'package:ostinato/app/account_data_directory.dart';
import 'package:ostinato/app/audio/practice_audio_lease.dart';
import 'package:ostinato/app/audio/practice_audio_root.dart';
import 'package:ostinato/app/session_store.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthChangeEvent, AuthState;

import 'support/account_delete_fixture.dart';
import 'support/fake_practice_audio_port.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final pendingSignIn in [false, true]) {
    test(
      pendingSignIn
          ? 'pending pre-confirmation sign-in cannot reopen confirmed UUID A'
          : 'pending actual token refresh cannot hide confirmed E0 retirement',
      () async {
        final lagEntered = Completer<void>();
        final releaseOwnerDelivery = Completer<void>();
        final lagEvent = pendingSignIn
            ? AuthChangeEvent.signedIn
            : AuthChangeEvent.tokenRefreshed;
        final h = await AccountDeleteFixture.create(
          delayed: true,
          ownerAuthChanges: (runtime) => runtime.account.authChanges
              .asyncMap<AuthState>((state) {
                if (state.event != lagEvent) return state;
                if (!lagEntered.isCompleted) lagEntered.complete();
                // Hold only this app owner's observation of the exact genuine
                // public AuthState. Core's independent subscription is live.
                return releaseOwnerDelivery.future.then((_) => state);
              }),
        );
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
        expect(
          (await owner.acquire(
            owner.grantFor(route)!,
            PracticeAudioSide.input,
          )).status,
          AudioRouteAcquireStatus.acquired,
        );
        final capturedEpoch = h.ownership.revision;
        final cleanupStarted = Completer<void>();
        final erased = Completer<void>();
        final releaseCleanup = Completer<void>();
        final deletion = h.pageClient().deleteCommonAccount(
          afterRemoteDelete: (id) {
            final cleanup = h.clearLocal(id);
            cleanupStarted.complete();
            return cleanup.then<void>((_) async {
              erased.complete();
              await releaseCleanup.future;
            });
          },
        );
        try {
          await h.transport.started.future.timeout(const Duration(seconds: 2));
          expect(h.transport.deleteAuthorization, 'Bearer A-session1');
          expect(h.transport.deleteBody?['expectedUserId'], aliceUuid);
          if (pendingSignIn) {
            await h.signIn(aliceUuid, 'A-session2');
          } else {
            await h.client.auth.refreshSession('local-refresh');
            await Future<void>.delayed(Duration.zero);
            await h.runtime.refreshIdentity();
          }
          await lagEntered.future.timeout(const Duration(seconds: 2));
          final nextToken = pendingSignIn ? 'A-session2' : 'A-refreshed';
          expect(h.client.auth.currentSession?.accessToken, nextToken);
          expect(h.runtime.userId.value, aliceUuid);
          expect(h.runtime.phase.value, MotionIdentityPhase.verified);
          expect(h.runtime.passwordRecovery.value, isFalse);
          expect(h.ownership.revision, capturedEpoch);
          expect(releaseOwnerDelivery.isCompleted, isFalse);
          expect(port.closeCalls, 0);

          h.transport.confirm();
          await cleanupStarted.future.timeout(const Duration(seconds: 2));
          final saved = PersistedSession(
            schemaVersion: PersistedSession.currentSchemaVersion,
            disciplineId: 'guitar',
            lessonId: 'public-auth-observation-lag',
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
          // Genuine receipt denies all A epochs even when app observation
          // of an earlier public replacement Session is still queued.
          expect(port.closeCalls, 1);
          expect(h.ownership.value, isFalse);
          expect(h.ownership.revision, capturedEpoch + 1);
          expect(owner.grantFor(route), isNull);
          expect(releaseCleanup.isCompleted, isFalse);
          expect(releaseOwnerDelivery.isCompleted, isFalse);
          await erased.future.timeout(const Duration(seconds: 2));
          expect(await accountDataDirectory(h.root, aliceUuid).exists(), isFalse);

          releaseOwnerDelivery.complete();
          await Future<void>.delayed(Duration.zero);
          if (pendingSignIn) {
            expect(h.ownership.value, isFalse);
            expect(h.ownership.revision, capturedEpoch + 2);
          } else {
            expect(h.ownership.value, isFalse);
            expect(h.ownership.revision, capturedEpoch + 1);
          }
          final nextObserver = PracticeAudioRouteObserver(owner);
          final nextRoute = MaterialPageRoute<void>(builder: (_) => const SizedBox());
          owner.attachNavigator(nextObserver);
          nextObserver.didPush(nextRoute, null);
          await owner.lastFenceForTest;
          expect(owner.grantFor(nextRoute), isNull);
          expect(port.opens, [PracticeAudioSide.input]);
          final beforeCompletion = h.ownership.revision;
          final closesBeforeCompletion = port.closeCalls;
          releaseCleanup.complete();
          await deletion;
          expect(h.ownership.revision, beforeCompletion);
          expect(port.closeCalls, closesBeforeCompletion);
          expect(h.client.auth.currentSession?.accessToken, nextToken);
          expect(
            await File('${accountDataDirectory(h.root, bobUuid).path}/sentinel.txt').readAsString(),
            bobUuid,
          );
          expect(
            await File('${h.root.path}/guest.txt').readAsString(),
            'guest-preserved',
          );
          await expectLater(retained.save(saved), throwsStateError);
          expect(owner.grantFor(nextRoute), isNull);
        } finally {
          if (!releaseOwnerDelivery.isCompleted) releaseOwnerDelivery.complete();
          h.transport.confirm();
          if (!releaseCleanup.isCompleted) releaseCleanup.complete();
          await deletion;
          await Future<void>.delayed(Duration.zero);
          owner.dispose();
          await owner.lastFenceForTest;
        }
      },
    );
  }
}
