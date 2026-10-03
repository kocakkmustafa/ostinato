import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:motion_account/motion_account.dart';
import 'package:ostinato/app/account_data_directory.dart';
import 'package:ostinato/app/account_data_operations.dart';
import 'package:ostinato/app/audio/practice_audio_lease.dart';

import 'account_delete_fixture.dart';
import 'account_drain_fixture.dart';

/// Each caller belongs to a separate Dart test isolate. The real lease's sticky
/// uncertainty is never reset, recovered or cleared by this fixture/teardown.
Future<void> requireBlockedAccountClose({required bool throwStop}) async {
  final h = await AccountDeleteFixture.create(delayed: true);
  final releaseWriter = Completer<void>();
  AccountAudioDrainFixture? audio;
  Future<void>? admitted;
  Future<void>? deletion;
  try {
    await h.seedFiles();
    final retained = accountJournal(h, aliceUuid);
    audio = await AccountAudioDrainFixture.open(h);
    final entered = Completer<void>();
    admitted = AccountDataOperations(
      () async => accountDataDirectory(h.root, aliceUuid),
    ).run((directory) async {
      entered.complete();
      await releaseWriter.future;
      await File('${directory.path}/admitted.txt').writeAsString('finished');
    }, writing: true);
    await joinDrain(entered.future);
    if (throwStop) {
      audio.port.stop = () async => throw StateError('distinctive typed stop failure');
    } else {
      // Only after real normal input acquisition: the actual typed native
      // snapshot fails all-clear. No synthetic ReleaseStatus is returned.
      audio.port.clear = () async => false;
    }
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
    final ticket = h.coordinator.eraseConfirmed(aliceUuid);
    final ticketOutcome = originalOutcome(ticket);
    var ticketSettled = false;
    ticketOutcome.then((_) => ticketSettled = true);
    final failedExactClose = audio.owner.lastFenceForTest!;
    expect(
      await joinDrain(failedExactClose),
      PracticeAudioReleaseStatus.blockedUnconfirmed,
    );
    expect(await accountDataDirectory(h.root, aliceUuid).exists(), isTrue);
    expect(h.coordinator.isDenied(aliceUuid), isTrue);
    await requireAWriterDenial(h, retained);
    await requireDisjointFilesAndWriters(h);
    expect(ticketSettled, isFalse, reason: 'Failed D must still join Q behind admitted IO');
    expect(deleteSettled, isFalse, reason: 'Core cleanup cannot settle before its queued files callback');
    expect(audio.port.closeCalls, 1);
    // Isolate the retained proof from later normal Core signedOut/guest
    // notifications. Dispose while A is still denied and W still holds Q.
    // No SDK/phase suppression, uncertainty reset or native recovery occurs.
    audio.owner.dispose();
    expect(audio.owner.lastFenceForTest, same(failedExactClose));
    expect(await joinDrain(failedExactClose), PracticeAudioReleaseStatus.blockedUnconfirmed);
    final closesBefore = audio.port.closeCalls;
    final fencesBefore = audio.port.fences.length;
    releaseWriter.complete();
    await joinDrain(admitted);
    final originalFailure = await joinDrain(ticketOutcome);
    expect(originalFailure, isA<StateError>());
    expect(await joinDrain(deleteOutcome), isA<MotionLocalCleanupPending>());
    expect(await accountDataDirectory(h.root, aliceUuid).exists(), isTrue);
    expect(h.coordinator.isDenied(aliceUuid), isTrue);
    expect(audio.port.closeCalls, closesBefore);
    expect(audio.port.fences.length, fencesBefore);
    await requireAWriterDenial(h, retained);
    await requireDisjointFilesAndWriters(h);

    if (!throwStop) {
      // Join the actual sign-out-triggered false scan before arming a new
      // permanent receipt. A later authoritative retry reuses failed proof;
      // it cannot retry/reset the native process or authorize erase.
      await joinDrain(h.scanReceipts());
      h.transport.permanentReceiptIds.add(aliceUuid);
      final retryOutcome = originalOutcome(h.scanReceipts());
      expect(await joinDrain(retryOutcome), same(originalFailure));
      expect(h.confirmedCleanups.single, isNot(same(ticket)));
      expect(await accountDataDirectory(h.root, aliceUuid).exists(), isTrue);
      expect(audio.port.closeCalls, closesBefore);
      expect(audio.port.fences.length, fencesBefore);
      expect(h.coordinator.isDenied(aliceUuid), isTrue);
    }
  } finally {
    h.transport.confirm();
    if (!releaseWriter.isCompleted) releaseWriter.complete();
    if (admitted != null) await joinDrain(originalOutcome(admitted));
    if (deletion != null) await joinDrain(originalOutcome(deletion));
    // Observe uncertainty only. This does not recover or manufacture all-clear.
    if (audio != null) {
      expect(await audio.closeOwner(), PracticeAudioReleaseStatus.blockedUnconfirmed);
    }
    await h.close();
  }
}
