import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motion_account/motion_account.dart';
import 'package:ostinato/app/account_data_directory.dart';
import 'package:ostinato/app/audio/practice_audio_lease.dart';
import 'package:ostinato/app/audio/practice_audio_root.dart';

import 'support/account_delete_fixture.dart';
import 'support/account_drain_fixture.dart';
import 'support/fake_practice_audio_port.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('permanent receipt joins old A close after Core becomes unavailable', () async {
    final h = await AccountDeleteFixture.create();
    final releaseClose = Completer<void>();
    Future<void>? scan;
    AccountAudioDrainFixture? audio;
    try {
      await h.seedFiles();
      final retained = accountJournal(h, aliceUuid);
      audio = await AccountAudioDrainFixture.open(h);
      final closeEntered = Completer<void>();
      audio.port.stop = () {
        if (!closeEntered.isCompleted) closeEntered.complete();
        return releaseClose.future;
      };
      h.transport.permanentReceiptIds.add(aliceUuid);
      scan = h.scanReceipts();
      final scanOutcome = originalOutcome(scan);
      await joinDrain(h.confirmedStarted.future);
      await joinDrain(closeEntered.future);
      expect(h.confirmedEntries.single, (aliceUuid, null, MotionIdentityPhase.unavailable));
      expect(h.runtime.userId.value, isNull);
      expect(h.runtime.phase.value, MotionIdentityPhase.unavailable);
      expect(audio.port.closeCalls, 1);
      expect(h.coordinator.isDenied(aliceUuid), isTrue);
      expect(h.ownership.value, isFalse);
      expect(await accountDataDirectory(h.root, aliceUuid).exists(), isTrue);
      await requireAWriterDenial(h, retained);
      await requireDisjointFilesAndWriters(h);
      var settled = false;
      scanOutcome.then((_) => settled = true);
      await Future<void>.delayed(Duration.zero);
      expect(settled, isFalse, reason: 'Permanent receipt must join the retained exact A close');
      releaseClose.complete();
      expect(await joinDrain(audio.owner.lastFenceForTest!), PracticeAudioReleaseStatus.confirmedClosed);
      expect(await joinDrain(scanOutcome), isNull);
      expect(await accountDataDirectory(h.root, aliceUuid).exists(), isFalse);
      expect(audio.port.closeCalls, 1);
      expect(h.client.auth.currentSession, isNull);
      await requireAWriterDenial(h, retained);
      await requireDisjointFilesAndWriters(h);
    } finally {
      if (!releaseClose.isCompleted) releaseClose.complete();
      if (scan != null) await joinDrain(originalOutcome(scan));
      if (audio != null) await audio.closeOwner();
      await h.close();
    }
  }, timeout: drainTestBound);

  test('admitted remote callback keeps old A authority after binding disposal', () async {
    final h = await AccountDeleteFixture.create(delayed: true);
    final releaseClose = Completer<void>();
    AccountAudioDrainFixture? audio;
    Future<void>? deletion;
    var bindingDisposed = false;
    try {
      await h.seedFiles();
      final retained = accountJournal(h, aliceUuid);
      audio = await AccountAudioDrainFixture.open(h);
      final closeEntered = Completer<void>();
      audio.port.stop = () {
        if (!closeEntered.isCompleted) closeEntered.complete();
        return releaseClose.future;
      };
      final filesEntered = Completer<void>();
      deletion = h.pageClient().deleteCommonAccount(afterRemoteDelete: (id) {
        final files = h.clearLocal(id);
        filesEntered.complete();
        return files;
      });
      final deleteOutcome = originalOutcome(deletion);
      await joinDrain(h.transport.started.future);
      audio.owner.dispose();
      final capturedClose = audio.owner.lastFenceForTest!;
      h.disposeBinding();
      bindingDisposed = true;
      await joinDrain(closeEntered.future);
      // Auth client stays alive; this is an actual public B password sign-in.
      // The disposed runtime cannot supply a positive B resource grant.
      await h.signIn(bobUuid, 'B-session2');
      final replacementSession = h.client.auth.currentSession;
      h.transport.confirm();
      await joinDrain(filesEntered.future);
      expect(h.coordinator.isDenied(aliceUuid), isTrue);
      expect(await accountDataDirectory(h.root, aliceUuid).exists(), isTrue);
      expect(audio.port.closeCalls, 1);
      expect(audio.owner.lastFenceForTest, same(capturedClose));
      await requireAWriterDenial(h, retained);
      await requireDisjointFilesAndWriters(h);
      releaseClose.complete();
      expect(await joinDrain(capturedClose), PracticeAudioReleaseStatus.confirmedClosed);
      expect(await joinDrain(deleteOutcome), isNull);
      expect(await accountDataDirectory(h.root, aliceUuid).exists(), isFalse);
      expect(h.client.auth.currentSession, same(replacementSession));
      expect(h.client.auth.currentUser?.id, bobUuid);
      expect(audio.port.closeCalls, 1);
    } finally {
      h.transport.confirm();
      if (!releaseClose.isCompleted) releaseClose.complete();
      if (deletion != null) await joinDrain(originalOutcome(deletion));
      if (audio != null) await audio.closeOwner();
      await h.close(runtimeAlreadyDisposed: bindingDisposed);
    }
  }, timeout: drainTestBound);

  test('remote and permanent callbacks join one ticket without a files-media cycle', () async {
    final h = await AccountDeleteFixture.create(delayed: true);
    final releaseClose = Completer<void>();
    AccountAudioDrainFixture? audio;
    Future<void>? deletion;
    Future<void>? scan;
    try {
      await h.seedFiles();
      audio = await AccountAudioDrainFixture.open(h);
      final closeEntered = Completer<void>();
      audio.port.stop = () {
        if (!closeEntered.isCompleted) closeEntered.complete();
        return releaseClose.future;
      };
      final filesEntered = Completer<void>();
      deletion = h.pageClient().deleteCommonAccount(afterRemoteDelete: (id) {
        final files = h.clearLocal(id);
        filesEntered.complete();
        return files;
      });
      final deleteOutcome = originalOutcome(deletion);
      await joinDrain(h.transport.started.future);
      h.transport.confirm();
      await joinDrain(filesEntered.future);
      await joinDrain(closeEntered.future);
      // Authority was already established by the strict real HTTP receipt.
      final ticket = h.coordinator.eraseConfirmed(aliceUuid);
      final ticketOutcome = originalOutcome(ticket);
      final erase = h.filesOnlyCleanups.single;
      expect(h.coordinator.eraseConfirmed(aliceUuid), same(ticket));
      expect(deleteAccountData(h.root, aliceUuid), same(erase));
      h.transport.permanentReceiptIds.add(aliceUuid);
      scan = h.scanReceipts();
      final scanOutcome = originalOutcome(scan);
      await joinDrain(h.confirmedStarted.future);
      expect(h.confirmedCleanups.single, same(ticket));
      expect(h.confirmedEntries.single, (aliceUuid, null, MotionIdentityPhase.unavailable));
      expect(audio.port.closeCalls, 1);
      expect(await accountDataDirectory(h.root, aliceUuid).exists(), isTrue);
      // Release only the real media prerequisite. No external completion of Q/F/T.
      releaseClose.complete();
      expect(await joinDrain(audio.owner.lastFenceForTest!), PracticeAudioReleaseStatus.confirmedClosed);
      expect(await joinDrain(ticketOutcome), isNull);
      expect(await joinDrain(deleteOutcome), isNull);
      expect(await joinDrain(scanOutcome), isNull);
      expect(h.coordinator.eraseConfirmed(aliceUuid), same(ticket));
      expect(deleteAccountData(h.root, aliceUuid), same(erase));
      expect(audio.port.closeCalls, 1);
      expect(await accountDataDirectory(h.root, aliceUuid).exists(), isFalse);
      await requireDisjointFilesAndWriters(h);
    } finally {
      h.transport.confirm();
      if (!releaseClose.isCompleted) releaseClose.complete();
      if (deletion != null) await joinDrain(originalOutcome(deletion));
      if (scan != null) await joinDrain(originalOutcome(scan));
      if (audio != null) await audio.closeOwner();
      await h.close();
    }
  }, timeout: drainTestBound);

  test('confirmed typed close control permits erase and keeps all A writers denied', () async {
    final h = await AccountDeleteFixture.create(delayed: true);
    final releaseClose = Completer<void>();
    AccountAudioDrainFixture? audio;
    Future<void>? deletion;
    try {
      await h.seedFiles();
      final retained = accountJournal(h, aliceUuid);
      audio = await AccountAudioDrainFixture.open(h);
      final closeEntered = Completer<void>();
      audio.port.stop = () {
        if (!closeEntered.isCompleted) closeEntered.complete();
        return releaseClose.future;
      };
      final filesEntered = Completer<void>();
      deletion = h.pageClient().deleteCommonAccount(afterRemoteDelete: (id) {
        final files = h.clearLocal(id);
        filesEntered.complete();
        return files;
      });
      final outcome = originalOutcome(deletion);
      await joinDrain(h.transport.started.future);
      h.transport.confirm();
      await joinDrain(filesEntered.future);
      await joinDrain(closeEntered.future);
      expect(await accountDataDirectory(h.root, aliceUuid).exists(), isTrue);
      await requireAWriterDenial(h, retained);
      releaseClose.complete();
      expect(await joinDrain(audio.owner.lastFenceForTest!), PracticeAudioReleaseStatus.confirmedClosed);
      expect(await joinDrain(outcome), isNull);
      expect(await accountDataDirectory(h.root, aliceUuid).exists(), isFalse);
      expect(h.coordinator.isDenied(aliceUuid), isTrue);
      await requireAWriterDenial(h, retained);
      await requireDisjointFilesAndWriters(h);
    } finally {
      h.transport.confirm();
      if (!releaseClose.isCompleted) releaseClose.complete();
      if (deletion != null) await joinDrain(originalOutcome(deletion));
      if (audio != null) await audio.closeOwner();
      await h.close();
    }
  }, timeout: drainTestBound);

  test('false permanent receipt preserves active A and has no cleanup entry', () async {
    final h = await AccountDeleteFixture.create();
    AccountAudioDrainFixture? audio;
    try {
      await h.seedFiles();
      audio = await AccountAudioDrainFixture.open(h);
      final beforeCloses = audio.port.closeCalls;
      await joinDrain(h.scanReceipts());
      expect(h.transport.permanentReceiptQueries, contains(aliceUuid));
      expect(h.confirmedEntries, isEmpty);
      expect(h.confirmedCleanups, isEmpty);
      expect(h.coordinator.isDenied(aliceUuid), isFalse);
      expect(audio.port.closeCalls, beforeCloses);
      expect(h.runtime.userId.value, aliceUuid);
      expect(h.runtime.phase.value, MotionIdentityPhase.verified);
      expect(audio.owner.grantFor(audio.route), isNotNull);
      await joinDrain(accountJournal(h, aliceUuid).save(drainSession('A-false-receipt')));
      expect(await accountDataDirectory(h.root, aliceUuid).exists(), isTrue);
    } finally {
      if (audio != null) await audio.closeOwner();
      await h.close();
    }
  }, timeout: drainTestBound);

  test('A receipt completes independently of a disjoint held B close', () async {
    final h = await AccountDeleteFixture.create();
    final releaseB = Completer<void>();
    AccountAudioDrainFixture? audio;
    Future<PracticeAudioReleaseStatus>? capturedB;
    try {
      await h.seedFiles();
      audio = await AccountAudioDrainFixture.open(h);
      await h.replace(bobUuid, 'B-session2');
      expect(await joinDrain(audio.owner.lastFenceForTest!), PracticeAudioReleaseStatus.confirmedClosed);
      await audio.reopenCurrentRoute();
      final replacementSession = h.client.auth.currentSession;
      final closeEntered = Completer<void>();
      audio.port.stop = () {
        if (!closeEntered.isCompleted) closeEntered.complete();
        return releaseB.future;
      };
      audio.owner.dispose();
      capturedB = audio.owner.lastFenceForTest!;
      await joinDrain(closeEntered.future);
      final beforeCloses = audio.port.closeCalls;
      h.transport.permanentReceiptIds.add(aliceUuid);
      await joinDrain(h.scanReceipts());
      expect(releaseB.isCompleted, isFalse);
      expect(await accountDataDirectory(h.root, aliceUuid).exists(), isFalse);
      expect(h.runtime.userId.value, bobUuid);
      expect(h.runtime.phase.value, MotionIdentityPhase.verified);
      expect(h.client.auth.currentSession, same(replacementSession));
      expect(audio.port.closeCalls, beforeCloses, reason: 'A selector must not join or reclose B');
      await requireDisjointFilesAndWriters(h);
    } finally {
      if (!releaseB.isCompleted) releaseB.complete();
      if (capturedB != null) {
        expect(await joinDrain(capturedB), PracticeAudioReleaseStatus.confirmedClosed);
      }
      if (audio != null) await audio.closeOwner();
      await h.close();
    }
  }, timeout: drainTestBound);

  test('never-owned denied A root cannot forward native retirement to B', () async {
    final h = await AccountDeleteFixture.create(delayed: true);
    final releaseFiles = Completer<void>();
    AccountDeleteFixture? b;
    AccountAudioDrainFixture? audioB;
    PracticeAudioRootOwner? deniedA;
    Future<void>? deletion;
    try {
      await h.seedFiles();
      final filesHeld = Completer<void>();
      deletion = h.pageClient().deleteCommonAccount(afterRemoteDelete: (id) =>
          h.clearLocal(id).then<void>((_) async {
            filesHeld.complete();
            await releaseFiles.future;
          }));
      final outcome = originalOutcome(deletion);
      await joinDrain(h.transport.started.future);
      h.transport.confirm();
      await joinDrain(filesHeld.future);
      expect(h.runtime.userId.value, aliceUuid);
      expect(h.runtime.phase.value, MotionIdentityPhase.verified);
      expect(h.ownership.value, isFalse);
      b = await AccountDeleteFixture.create(
        supportRoot: h.root,
        initialUserId: bobUuid,
        initialToken: 'B-session1',
      );
      expect(b.coordinator, same(h.coordinator));
      audioB = await AccountAudioDrainFixture.open(b);
      final beforeCloses = audioB.port.closeCalls;
      final beforeFences = audioB.port.fences.length;
      final unusedPort = FakePracticeAudioPort();
      deniedA = PracticeAudioRootOwner(
        userId: h.runtime.userId,
        phase: h.runtime.phase,
        passwordRecovery: h.runtime.passwordRecovery,
        identityBoundary: h.ownership,
        resourceAdmission: h.ownership,
        lease: PracticeAudioLease(port: unusedPort),
        initialLifecycleState: AppLifecycleState.resumed,
        allowDetachedRouteEventsForTest: true,
        allowAcquisition: true,
      );
      final observer = PracticeAudioRouteObserver(deniedA);
      final route = MaterialPageRoute<void>(builder: (_) => const SizedBox());
      deniedA.attachNavigator(observer);
      observer.didPush(route, null);
      await joinDrain(deniedA.lastFenceForTest!);
      expect(deniedA.grantFor(route), isNull);
      deniedA.dispose();
      await joinDrain(deniedA.lastFenceForTest!);
      expect(unusedPort.opens, isEmpty);
      expect(unusedPort.fences, isEmpty);
      expect(audioB.port.closeCalls, beforeCloses);
      expect(audioB.port.fences.length, beforeFences);
      expect(audioB.owner.grantFor(audioB.route), isNotNull);
      releaseFiles.complete();
      expect(await joinDrain(outcome), isNull);
      expect(b.client.auth.currentUser?.id, bobUuid);
      expect(audioB.port.closeCalls, beforeCloses);
    } finally {
      h.transport.confirm();
      if (!releaseFiles.isCompleted) releaseFiles.complete();
      if (deletion != null) await joinDrain(originalOutcome(deletion));
      deniedA?.dispose();
      if (audioB != null) await audioB.closeOwner();
      if (b != null) await b.close();
      await h.close();
    }
  }, timeout: drainTestBound);

  test('valid held user stop is the exact A proof joined by confirmed deletion', () async {
    final h = await AccountDeleteFixture.create(delayed: true);
    final releaseClose = Completer<void>();
    AccountAudioDrainFixture? audio;
    Future<PracticeAudioReleaseStatus>? stop;
    Future<void>? deletion;
    try {
      await h.seedFiles();
      final retained = accountJournal(h, aliceUuid);
      audio = await AccountAudioDrainFixture.open(h);
      final closeEntered = Completer<void>();
      audio.port.stop = () {
        if (!closeEntered.isCompleted) closeEntered.complete();
        return releaseClose.future;
      };
      final beforeFences = audio.port.fences.length;
      stop = audio.owner.release(audio.ticket!);
      final originalClose = audio.owner.lastFenceForTest!;
      await joinDrain(closeEntered.future);
      expect(audio.port.closeCalls, 1);
      final filesEntered = Completer<void>();
      deletion = h.pageClient().deleteCommonAccount(afterRemoteDelete: (id) {
        final files = h.clearLocal(id);
        filesEntered.complete();
        return files;
      });
      final outcome = originalOutcome(deletion);
      await joinDrain(h.transport.started.future);
      h.transport.confirm();
      await joinDrain(filesEntered.future);
      expect(h.ownership.value, isFalse);
      expect(h.coordinator.isDenied(aliceUuid), isTrue);
      expect(audio.owner.lastFenceForTest, same(originalClose));
      expect(audio.port.closeCalls, 1);
      expect(audio.port.fences.length, beforeFences,
          reason: 'Confirmed A must join the exact user-stop close, not dispatch another fence');
      expect(await accountDataDirectory(h.root, aliceUuid).exists(), isTrue);
      await requireAWriterDenial(h, retained);
      await requireDisjointFilesAndWriters(h);
      var settled = false;
      outcome.then((_) => settled = true);
      await Future<void>.delayed(Duration.zero);
      expect(settled, isFalse,
          reason: 'A namespace cannot erase while its original user-stop proof is held');
      // Detach the owner while A is denied and before the real Core signOut.
      // Later general guest fencing is outside this retained-proof assertion.
      audio.owner.dispose();
      expect(audio.owner.lastFenceForTest, same(originalClose));
      releaseClose.complete();
      expect(await joinDrain(originalClose), PracticeAudioReleaseStatus.confirmedClosed);
      expect(await joinDrain(stop), PracticeAudioReleaseStatus.confirmedClosed);
      expect(await joinDrain(outcome), isNull);
      expect(await accountDataDirectory(h.root, aliceUuid).exists(), isFalse);
      expect(audio.port.closeCalls, 1);
      expect(audio.port.fences.length, beforeFences);
      await requireAWriterDenial(h, retained);
      await requireDisjointFilesAndWriters(h);
    } finally {
      h.transport.confirm();
      if (!releaseClose.isCompleted) releaseClose.complete();
      if (stop != null) await joinDrain(stop);
      if (deletion != null) await joinDrain(originalOutcome(deletion));
      if (audio != null) await audio.closeOwner();
      await h.close();
    }
  }, timeout: drainTestBound);

  test('stale ticket cannot bind a current actor to a different pending close', () async {
    final h = await AccountDeleteFixture.create(delayed: true);
    final releaseClose = Completer<void>();
    AccountAudioDrainFixture? audio;
    Future<PracticeAudioReleaseStatus>? stop;
    Future<void>? deletion;
    try {
      await h.seedFiles();
      audio = await AccountAudioDrainFixture.open(h);
      final stale = audio.ticket!;
      expect(await joinDrain(audio.owner.release(stale)),
          PracticeAudioReleaseStatus.confirmedClosed);
      await audio.reopenCurrentRoute();
      final activeTicket = audio.ticket!;
      final activeFence = audio.owner.lastFenceForTest;
      final activeCloses = audio.port.closeCalls;
      expect(await joinDrain(audio.owner.release(stale)),
          PracticeAudioReleaseStatus.staleTicket);
      expect(audio.owner.lastFenceForTest, same(activeFence));
      expect(audio.port.closeCalls, activeCloses);

      final closeEntered = Completer<void>();
      audio.port.stop = () {
        if (!closeEntered.isCompleted) closeEntered.complete();
        return releaseClose.future;
      };
      stop = audio.owner.release(activeTicket);
      final originalClose = audio.owner.lastFenceForTest!;
      await joinDrain(closeEntered.future);
      // Public grant creation registers a fresh current period even though a
      // native close is pending. No acquisition or native operation is started.
      expect(audio.owner.grantFor(audio.route), isNotNull);
      expect(await joinDrain(audio.owner.release(stale)),
          PracticeAudioReleaseStatus.staleTicket);
      expect(audio.owner.lastFenceForTest, same(originalClose),
          reason: 'Already-closing phase must not bind a stale Future to the fresh actor');
      expect(audio.port.closeCalls, activeCloses + 1);
      releaseClose.complete();
      expect(await joinDrain(stop), PracticeAudioReleaseStatus.confirmedClosed);
      expect(await joinDrain(originalClose), PracticeAudioReleaseStatus.confirmedClosed);

      final beforeFences = audio.port.fences.length;
      final currentOwner = audio.owner;
      final currentPort = audio.port;
      deletion = h.pageClient().deleteCommonAccount(afterRemoteDelete: (id) {
        final files = h.clearLocal(id);
        expect(currentPort.closeCalls, activeCloses + 1);
        expect(currentPort.fences.length, beforeFences);
        // Detach after confirmed A denial, before the real Core guest event.
        currentOwner.dispose();
        return files;
      });
      final outcome = originalOutcome(deletion);
      await joinDrain(h.transport.started.future);
      h.transport.confirm();
      expect(await joinDrain(outcome), isNull,
          reason: 'A fresh never-dispatched actor must keep its own valid idle proof');
      expect(await accountDataDirectory(h.root, aliceUuid).exists(), isFalse);
      expect(audio.port.closeCalls, activeCloses + 1);
      expect(audio.port.fences.length, beforeFences);
      await requireDisjointFilesAndWriters(h);
    } finally {
      h.transport.confirm();
      if (!releaseClose.isCompleted) releaseClose.complete();
      if (stop != null) await joinDrain(stop);
      if (deletion != null) await joinDrain(originalOutcome(deletion));
      if (audio != null) await audio.closeOwner();
      await h.close();
    }
  }, timeout: drainTestBound);
}
