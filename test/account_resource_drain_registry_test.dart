import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:motion_account/motion_account.dart';
import 'package:ostinato/app/account_connection.dart';
import 'package:ostinato/app/account_data_directory.dart';
import 'package:ostinato/app/account_ownership_epoch.dart';

import 'support/account_delete_fixture.dart';
import 'support/account_drain_fixture.dart';

/// Logical adapter protocol only: this test never claims physical native close.
/// Real Core public state supplies namespace metadata; these Futures exercise
/// registry identity/reentry/error joining without private Auth or Core hooks.
final class _ObservedDrain implements AccountResourceDrain {
  _ObservedDrain(this.proof, {this.onRetire});
  final Future<void> proof;
  final void Function()? onRetire;
  int retireCalls = 0;
  int waitCalls = 0;

  @override
  void retire() {
    ++retireCalls;
    onRetire?.call();
  }

  @override
  Future<void> waitForClosed() {
    ++waitCalls;
    return proof;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final suffix in ['/', '/unused/..']) {
    test('coordinator root alias $suffix joins the exact held resource ticket', () async {
      final h = await AccountDeleteFixture.create();
      final proof = Completer<void>();
      try {
        final actor = _ObservedDrain(proof.future);
        h.ownership.registerResource(resource: actor);
        final alias = AccountDeletionCoordinator.forRoot(Directory('${h.root.path}$suffix'));
        expect(alias, same(h.coordinator));
        final cleanup = alias.eraseConfirmed(aliceUuid);
        var settled = false;
        final observed = cleanup.then((_) => settled = true);
        await Future<void>.delayed(Duration.zero);
        expect(settled, isFalse);
        expect(actor.retireCalls, 1);
        proof.complete();
        await joinDrain(observed);
      } finally {
        if (!proof.isCompleted) proof.complete();
        await h.close();
      }
    });
  }

  test('raw sign-in before public notification cannot register a guest resource', () async {
    final h = await AccountDeleteFixture.create();
    try {
      await h.signOut();
      expect(h.runtime.phase.value, MotionIdentityPhase.signedOut);
      final replacement = h.replace(aliceUuid, 'A-new');
      expect(h.client.auth.currentSession, isNotNull);
      final actor = _ObservedDrain(Future<void>.value());
      final registration = h.ownership.registerResource(resource: actor);
      expect(registration.hasNamespace, isFalse);
      expect(registration.isGuest, isFalse);
      expect(actor.retireCalls, 1);
      await replacement;
      await joinDrain(registration.retireAndDrain());
    } finally {
      await h.close();
    }
  });

  test('completed A actor registration cannot be retagged by real verified B', () async {
    final h = await AccountDeleteFixture.create();
    try {
      final actor = _ObservedDrain(Future<void>.value());
      final registration = h.ownership.registerResource(resource: actor);
      final originalEpoch = registration.capturedHostEpoch;
      final original = registration.retireAndDrain();
      await joinDrain(original);
      expect(registration.accountUserId, aliceUuid);
      expect(registration.isGuest, isFalse);
      expect(registration.hasNamespace, isTrue);
      await h.replace(bobUuid, 'B-session2');
      expect(h.runtime.userId.value, bobUuid);
      expect(h.runtime.phase.value, MotionIdentityPhase.verified);
      final repeated = h.ownership.registerResource(resource: actor);
      expect(repeated, same(registration));
      expect(repeated.retireAndDrain(), same(original));
      expect(repeated.accountUserId, aliceUuid);
      expect(repeated.capturedHostEpoch, originalEpoch);
      expect(actor.retireCalls, 1);
      expect(actor.waitCalls, 1);
      final freshActor = _ObservedDrain(Future<void>.value());
      final fresh = h.ownership.registerResource(resource: freshActor);
      expect(fresh, isNot(same(registration)));
      expect(fresh.accountUserId, bobUuid);
      await joinDrain(fresh.retireAndDrain());
    } finally {
      await h.close();
    }
  }, timeout: drainTestBound);

  test('failed initial drain batch still joins late registered held A proof', () async {
    final h = await AccountDeleteFixture.create(delayed: true);
    final firstProof = Completer<void>();
    final lateProof = Completer<void>();
    final lateRegistered = Completer<void>();
    final firstFailure = StateError('first exact logical close failure');
    originalOutcome(firstProof.future);
    AccountResourceDrainRegistration? lateRegistration;
    Future<void>? deletion;
    Future<void>? lateRegistrationTurn;
    try {
      await h.seedFiles();
      final lateActor = _ObservedDrain(lateProof.future);
      final firstActor = _ObservedDrain(firstProof.future, onRetire: () {
        // The next event turn runs after current microtasks, including D's
        // initial checkpoint and first scan. D is then awaiting firstProof;
        // the denied late actor belongs to a later batch, not that snapshot.
        lateRegistrationTurn = Future<void>.delayed(Duration.zero, () {
          lateRegistration = h.ownership.registerResource(resource: lateActor);
          if (!lateRegistered.isCompleted) lateRegistered.complete();
          if (!firstProof.isCompleted) firstProof.completeError(firstFailure);
        });
        originalOutcome(lateRegistrationTurn!);
      });
      h.ownership.registerResource(resource: firstActor);
      final filesEntered = Completer<void>();
      deletion = h.pageClient().deleteCommonAccount(afterRemoteDelete: (id) {
        final files = h.clearLocal(id);
        filesEntered.complete();
        return files;
      });
      final deleteOutcome = originalOutcome(deletion);
      var deleteSettled = false;
      deleteOutcome.then((_) => deleteSettled = true);
      await joinDrain(h.transport.started.future);
      h.transport.confirm();
      await joinDrain(filesEntered.future);
      // Capture the original still-pending authoritative ticket before the
      // next event turn; a broken driver must not start a retry in this test.
      final ticket = h.coordinator.eraseConfirmed(aliceUuid);
      final ticketOutcome = originalOutcome(ticket);
      var ticketSettled = false;
      ticketOutcome.then((_) => ticketSettled = true);
      await joinDrain(lateRegistered.future);
      await joinDrain(lateRegistrationTurn!);
      await Future<void>.delayed(Duration.zero);
      expect(lateRegistration!.accountUserId, aliceUuid);
      expect(lateActor.retireCalls, 1);
      expect(lateActor.waitCalls, 1);
      expect(lateProof.isCompleted, isFalse);
      expect(ticketSettled, isFalse, reason: 'D must join late held proof after earlier failure');
      expect(deleteSettled, isFalse);
      expect(await accountDataDirectory(h.root, aliceUuid).exists(), isTrue);
      lateProof.complete();
      expect(await joinDrain(ticketOutcome), same(firstFailure));
      expect(await joinDrain(deleteOutcome), isA<MotionLocalCleanupPending>());
      expect(await accountDataDirectory(h.root, aliceUuid).exists(), isTrue);
      expect(h.coordinator.isDenied(aliceUuid), isTrue);
      expect(firstActor.retireCalls, 1);
      expect(lateActor.retireCalls, 1);
    } finally {
      h.transport.confirm();
      if (!firstProof.isCompleted) firstProof.completeError(firstFailure);
      if (!lateProof.isCompleted) lateProof.complete();
      try {
        if (deletion != null) await joinDrain(originalOutcome(deletion));
      } finally {
        try {
          // Release proofs first, then join the public event-turn Future before
          // disposing its binding. Future.delayed has no cancel handle.
          final scheduled = lateRegistrationTurn;
          if (scheduled != null) await joinDrain(originalOutcome(scheduled));
        } finally {
          await h.close();
        }
      }
    }
  }, timeout: drainTestBound);

  test('synchronous files callback joins its denied proof before an empty initial drain settles', () async {
    final h = await AccountDeleteFixture.create(delayed: true);
    final heldProof = Completer<void>();
    final filesEntered = Completer<void>();
    AccountResourceDrainRegistration? registration;
    Future<void>? deletion;
    try {
      await h.seedFiles();
      final retained = accountJournal(h, aliceUuid);
      final actor = _ObservedDrain(heldProof.future);
      deletion = h.pageClient().deleteCommonAccount(afterRemoteDelete: (id) {
        // D is independently started before F. This actual synchronous F
        // registration must be visible before its initial quiescence scan.
        registration = h.ownership.registerResource(resource: actor);
        final files = h.clearLocal(id);
        filesEntered.complete();
        return files;
      });
      final outcome = originalOutcome(deletion);
      var settled = false;
      outcome.then((_) => settled = true);
      await joinDrain(h.transport.started.future);
      h.transport.confirm();
      await joinDrain(filesEntered.future);
      await Future<void>.delayed(Duration.zero);
      expect(registration!.accountUserId, aliceUuid);
      expect(actor.retireCalls, 1);
      expect(actor.waitCalls, 1);
      expect(heldProof.isCompleted, isFalse);
      expect(settled, isFalse,
          reason: 'An initially empty D must still join same-call synchronous F registration');
      expect(await accountDataDirectory(h.root, aliceUuid).exists(), isTrue);
      await requireAWriterDenial(h, retained);
      await requireDisjointFilesAndWriters(h);
      heldProof.complete();
      expect(await joinDrain(outcome), isNull);
      expect(await accountDataDirectory(h.root, aliceUuid).exists(), isFalse);
      expect(actor.retireCalls, 1);
      expect(actor.waitCalls, 1);
    } finally {
      h.transport.confirm();
      if (!heldProof.isCompleted) heldProof.complete();
      if (deletion != null) await joinDrain(originalOutcome(deletion));
      await h.close();
    }
  }, timeout: drainTestBound);
}
