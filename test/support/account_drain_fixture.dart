import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motion_account/motion_account.dart';
import 'package:ostinato/app/account_data_directory.dart';
import 'package:ostinato/app/audio/practice_audio_lease.dart';
import 'package:ostinato/app/audio/practice_audio_root.dart';
import 'package:ostinato/app/session_store.dart';

import 'account_delete_fixture.dart';
import 'fake_practice_audio_port.dart';

const drainJoinBound = Duration(seconds: 2);
const drainTestBound = Timeout(Duration(seconds: 20));

Future<T> joinDrain<T>(Future<T> operation) => operation.timeout(drainJoinBound);

/// Observe the original failure before driving transport. This derived Future
/// is a value, while the original Core/queue Future retains its error and stack.
Future<Object?> originalOutcome(Future<void> operation) =>
    operation.then<Object?>((_) => null, onError: (Object error, StackTrace _) => error);

PersistedSession drainSession(String lesson) => PersistedSession(
  schemaVersion: PersistedSession.currentSchemaVersion,
  disciplineId: 'guitar',
  lessonId: lesson,
  completedAt: DateTime.utc(2026, 10, 2),
  elapsedSeconds: 30,
  sampleCount: 3,
  outCount: 0,
);

SessionStore accountJournal(AccountDeleteFixture h, String? id) => SessionStore(
  directoryProvider: () async => h.root,
  accountUserId: id,
);

Future<void> requireAWriterDenial(
  AccountDeleteFixture h,
  SessionStore retained,
) async {
  await expectLater(
    retained.save(drainSession('retained-A-denied')).timeout(drainJoinBound),
    throwsStateError,
  );
  await expectLater(
    accountJournal(h, aliceUuid)
        .save(drainSession('fresh-A-denied')).timeout(drainJoinBound),
    throwsStateError,
  );
}

Future<void> requireDisjointFilesAndWriters(AccountDeleteFixture h) async {
  expect(
    await File('${accountDataDirectory(h.root, bobUuid).path}/sentinel.txt').readAsString(),
    bobUuid,
  );
  expect(await File('${h.root.path}/guest.txt').readAsString(), 'guest-preserved');
  await joinDrain(accountJournal(h, bobUuid).save(drainSession('B-preserved')));
  await joinDrain(accountJournal(h, null).save(drainSession('guest-preserved')));
}

/// Constructs the actual AudioRoot owner and actual grant/lease; this controls
/// only a typed fake port. No phase or native status is synthesized.
final class AccountAudioDrainFixture {
  AccountAudioDrainFixture._(this.h, this.port, this.owner, this.observer, this.route);

  final AccountDeleteFixture h;
  final FakePracticeAudioPort port;
  final PracticeAudioRootOwner owner;
  PracticeAudioRouteObserver observer;
  Route<void> route;
  PracticeAudioTicket? ticket;

  static Future<AccountAudioDrainFixture> open(
    AccountDeleteFixture h, {
    FakePracticeAudioPort? port,
  }) async {
    final actualPort = port ?? FakePracticeAudioPort();
    final owner = PracticeAudioRootOwner(
      userId: h.runtime.userId,
      phase: h.runtime.phase,
      passwordRecovery: h.runtime.passwordRecovery,
      identityBoundary: h.ownership,
      resourceAdmission: h.ownership,
      lease: PracticeAudioLease(port: actualPort),
      initialLifecycleState: AppLifecycleState.resumed,
      allowDetachedRouteEventsForTest: true,
      allowAcquisition: true,
    );
    final observer = PracticeAudioRouteObserver(owner);
    final route = MaterialPageRoute<void>(builder: (_) => const SizedBox());
    final fixture = AccountAudioDrainFixture._(h, actualPort, owner, observer, route);
    try {
      await fixture.openCurrentRoute();
      return fixture;
    } catch (error, stack) {
      final originalFence = owner.lastFenceForTest;
      try {
        // Normal retirement only: never recover/reset or create an all-clear
        // fixture result. Preserve the first setup assertion/error regardless
        // of any failed/uncertain cleanup outcome or bounded join timeout.
        owner.dispose();
        final retirement = owner.lastFenceForTest;
        if (originalFence != null) {
          await originalFence.then<void>((_) {},
            onError: (Object _, StackTrace _) {},
          ).timeout(drainJoinBound);
        }
        if (retirement != null && !identical(retirement, originalFence)) {
          await retirement.then<void>((_) {},
            onError: (Object _, StackTrace _) {},
          ).timeout(drainJoinBound);
        }
      } on Object {
        // The source runner must still reject the original fixture failure.
      }
      Error.throwWithStackTrace(error, stack);
    }
  }

  Future<void> openCurrentRoute() async {
    expect(h.runtime.phase.value, MotionIdentityPhase.verified);
    expect(h.ownership.value, isTrue);
    owner.attachNavigator(observer);
    observer.didPush(route, null);
    final fence = owner.lastFenceForTest;
    if (fence != null) await joinDrain(fence);
    final grant = owner.grantFor(route);
    expect(grant, isNotNull, reason: 'Real verified fixture must acquire before the target race');
    final acquired = await joinDrain(owner.acquire(grant!, PracticeAudioSide.input));
    expect(acquired.status, AudioRouteAcquireStatus.acquired);
    expect(acquired.ticket, isNotNull);
    ticket = acquired.ticket;
  }

  Future<void> reopenCurrentRoute() async {
    observer = PracticeAudioRouteObserver(owner);
    route = MaterialPageRoute<void>(builder: (_) => const SizedBox());
    await openCurrentRoute();
  }

  Future<PracticeAudioReleaseStatus> closeOwner() {
    owner.dispose();
    return joinDrain(owner.lastFenceForTest!);
  }
}
