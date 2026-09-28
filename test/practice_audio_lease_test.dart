import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/audio/practice_audio_lease.dart';

final class _Port implements PracticeAudioLeasePort {
  final opens = <PracticeAudioSide>[];
  int closeCalls = 0;
  Future<bool> Function()? clear;
  Future<void> Function(PracticeAudioSide)? start;
  Future<void> Function()? stop;

  @override
  Future<bool> readAllClear() => clear?.call() ?? Future.value(true);

  @override
  Future<void> open(PracticeAudioSide side) {
    opens.add(side);
    return start?.call(side) ?? Future.value();
  }

  @override
  Future<void> closeAll() {
    closeCalls++;
    return stop?.call() ?? Future.value();
  }
}

Future<PracticeAudioAcquireResult> _acquire(
  PracticeAudioLease lease,
  PracticeAudioSide side,
) => lease.acquire(side, context: lease.captureContext());

void main() {
  test(
    'reservation rejects concurrent input/output before first await',
    () async {
      final read = Completer<bool>();
      final port = _Port()..clear = () => read.future;
      final lease = PracticeAudioLease(port: port);

      final input = _acquire(lease, PracticeAudioSide.input);
      expect(lease.phase, PracticeAudioLeasePhase.openingInput);
      expect(
        (await _acquire(lease, PracticeAudioSide.output)).status,
        PracticeAudioAcquireStatus.busy,
      );
      expect(port.opens, isEmpty);
      read.complete(true);
      final result = await input;
      expect(result.status, PracticeAudioAcquireStatus.acquired);
      expect(result.ticket, isNotNull);
      expect(port.opens, [PracticeAudioSide.input]);
      expect(lease.phase, PracticeAudioLeasePhase.inputActive);
      expect(
        await lease.release(result.ticket!),
        PracticeAudioReleaseStatus.confirmedClosed,
      );
    },
  );

  test(
    'route invalidation before preflight returns cannot open late',
    () async {
      final read = Completer<bool>();
      final port = _Port()..clear = () => read.future;
      final lease = PracticeAudioLease(port: port);
      final starting = _acquire(lease, PracticeAudioSide.output);
      final invalidated = lease.invalidate(
        PracticeAudioInvalidationReason.routeChange,
      );
      read.complete(true);

      expect((await starting).status, PracticeAudioAcquireStatus.cancelled);
      expect(await invalidated, PracticeAudioReleaseStatus.confirmedClosed);
      expect(port.opens, isEmpty);
      expect(
        lease.lastInvalidationReason,
        PracticeAudioInvalidationReason.routeChange,
      );
      expect(lease.phase, PracticeAudioLeasePhase.idle);
    },
  );

  test(
    'account invalidation during late open waits for close receipt',
    () async {
      final opened = Completer<void>();
      final closed = Completer<void>();
      final port = _Port();
      port.start = (_) => opened.future;
      port.stop = () => closed.future;
      final lease = PracticeAudioLease(port: port);
      final starting = _acquire(lease, PracticeAudioSide.output);
      await Future<void>.delayed(Duration.zero);
      expect(port.opens, [PracticeAudioSide.output]);
      final invalidated = lease.invalidate(
        PracticeAudioInvalidationReason.accountChange,
      );
      expect(
        (await _acquire(lease, PracticeAudioSide.input)).status,
        PracticeAudioAcquireStatus.busy,
      );
      opened.complete();
      await Future<void>.delayed(Duration.zero);
      expect(port.closeCalls, 1);
      expect(lease.phase, PracticeAudioLeasePhase.closingOutput);
      closed.complete();

      expect((await starting).status, PracticeAudioAcquireStatus.cancelled);
      expect(await invalidated, PracticeAudioReleaseStatus.confirmedClosed);
      expect(lease.phase, PracticeAudioLeasePhase.idle);
      expect(
        lease.lastInvalidationReason,
        PracticeAudioInvalidationReason.accountChange,
      );
    },
  );

  test(
    'failed close is sticky and only explicit confirmed recovery clears it',
    () async {
      final port = _Port();
      final lease = PracticeAudioLease(port: port);
      final ticket = (await _acquire(lease, PracticeAudioSide.output)).ticket!;
      port.stop = () => Future.error(StateError('native close failed'));

      expect(
        await lease.release(ticket),
        PracticeAudioReleaseStatus.blockedUnconfirmed,
      );
      expect(lease.phase, PracticeAudioLeasePhase.blockedUnconfirmed);
      expect(
        (await _acquire(lease, PracticeAudioSide.input)).status,
        PracticeAudioAcquireStatus.blockedUnconfirmed,
      );
      expect(
        await lease.release(ticket),
        PracticeAudioReleaseStatus.staleTicket,
      );
      port.stop = () async {};
      port.clear = () async => false;
      expect(
        await lease.recover(),
        PracticeAudioReleaseStatus.blockedUnconfirmed,
      );
      port.clear = () async => true;
      expect(await lease.recover(), PracticeAudioReleaseStatus.confirmedClosed);
      expect(lease.phase, PracticeAudioLeasePhase.idle);
      expect(port.closeCalls, 3);
    },
  );

  test(
    'close timeout and late reply never auto-clear the sticky latch',
    () async {
      final closed = Completer<void>();
      final port = _Port()..stop = () => closed.future;
      final lease = PracticeAudioLease(
        port: port,
        operationTimeout: const Duration(milliseconds: 15),
      );
      final ticket = (await _acquire(lease, PracticeAudioSide.input)).ticket!;
      expect(
        await lease.release(ticket),
        PracticeAudioReleaseStatus.blockedUnconfirmed,
      );
      expect(await lease.recover(), PracticeAudioReleaseStatus.pendingNative);
      closed.complete();
      await Future<void>.delayed(Duration.zero);
      expect(lease.phase, PracticeAudioLeasePhase.blockedUnconfirmed);
      port.stop = () async {};
      expect(await lease.recover(), PracticeAudioReleaseStatus.confirmedClosed);
      expect(lease.phase, PracticeAudioLeasePhase.idle);
    },
  );

  test(
    'open timeout cannot recover until original native call settles',
    () async {
      final opened = Completer<void>();
      final port = _Port()..start = (_) => opened.future;
      final lease = PracticeAudioLease(
        port: port,
        operationTimeout: const Duration(milliseconds: 15),
      );
      expect(
        (await _acquire(lease, PracticeAudioSide.output)).status,
        PracticeAudioAcquireStatus.blockedUnconfirmed,
      );
      expect(await lease.recover(), PracticeAudioReleaseStatus.pendingNative);
      opened.complete();
      await Future<void>.delayed(Duration.zero);
      expect(lease.phase, PracticeAudioLeasePhase.blockedUnconfirmed);
      expect(await lease.recover(), PracticeAudioReleaseStatus.confirmedClosed);
      expect(lease.phase, PracticeAudioLeasePhase.idle);
      expect(port.closeCalls, 1);
    },
  );

  test(
    'missing clear receipt blocks acquisition and recovery needs a new one',
    () async {
      final port = _Port()..clear = () async => false;
      final lease = PracticeAudioLease(port: port);
      expect(
        (await _acquire(lease, PracticeAudioSide.input)).status,
        PracticeAudioAcquireStatus.blockedUnconfirmed,
      );
      expect(port.opens, isEmpty);
      expect(lease.phase, PracticeAudioLeasePhase.blockedUnconfirmed);
      port.clear = () async => true;
      expect(await lease.recover(), PracticeAudioReleaseStatus.confirmedClosed);
      expect(lease.phase, PracticeAudioLeasePhase.idle);
    },
  );

  test('old ticket cannot close a later session', () async {
    final port = _Port();
    final lease = PracticeAudioLease(port: port);
    final first = (await _acquire(lease, PracticeAudioSide.output)).ticket!;
    expect(
      await lease.release(first),
      PracticeAudioReleaseStatus.confirmedClosed,
    );
    final second = (await _acquire(lease, PracticeAudioSide.input)).ticket!;
    expect(await lease.release(first), PracticeAudioReleaseStatus.staleTicket);
    expect(lease.phase, PracticeAudioLeasePhase.inputActive);
    expect(
      await lease.release(second),
      PracticeAudioReleaseStatus.confirmedClosed,
    );
  });

  test(
    'separate instances reserve one isolate owner before either await',
    () async {
      final firstRead = Completer<bool>();
      final firstPort = _Port()..clear = () => firstRead.future;
      final secondPort = _Port();
      final first = PracticeAudioLease(port: firstPort);
      final second = PracticeAudioLease(port: secondPort);

      final starting = _acquire(first, PracticeAudioSide.output);
      expect(first.phase, PracticeAudioLeasePhase.openingOutput);
      expect(
        (await _acquire(second, PracticeAudioSide.input)).status,
        PracticeAudioAcquireStatus.busy,
      );
      expect(secondPort.opens, isEmpty);
      firstRead.complete(true);
      final firstTicket = (await starting).ticket!;
      expect(
        (await _acquire(second, PracticeAudioSide.input)).status,
        PracticeAudioAcquireStatus.busy,
      );
      expect(
        await first.release(firstTicket),
        PracticeAudioReleaseStatus.confirmedClosed,
      );
      final secondTicket = (await _acquire(
        second,
        PracticeAudioSide.input,
      )).ticket!;
      expect(secondPort.opens, [PracticeAudioSide.input]);
      expect(
        await second.release(secondTicket),
        PracticeAudioReleaseStatus.confirmedClosed,
      );
    },
  );

  test('blocked owner cannot be bypassed by a new instance', () async {
    final firstPort = _Port();
    final secondPort = _Port();
    final first = PracticeAudioLease(port: firstPort);
    final second = PracticeAudioLease(port: secondPort);
    final secondOldContext = second.captureContext();
    final ticket = (await _acquire(first, PracticeAudioSide.output)).ticket!;
    firstPort.stop = () => Future.error(StateError('close failed'));
    expect(
      await first.release(ticket),
      PracticeAudioReleaseStatus.blockedUnconfirmed,
    );
    expect(
      (await second.acquire(
        PracticeAudioSide.input,
        context: secondOldContext,
      )).status,
      PracticeAudioAcquireStatus.blockedUnconfirmed,
    );
    expect(
      await second.recover(),
      PracticeAudioReleaseStatus.blockedUnconfirmed,
    );
    expect(secondPort.opens, isEmpty);

    firstPort.stop = () async {};
    expect(await first.recover(), PracticeAudioReleaseStatus.confirmedClosed);
    expect(
      (await second.acquire(
        PracticeAudioSide.input,
        context: secondOldContext,
      )).status,
      PracticeAudioAcquireStatus.staleContext,
    );
    final secondTicket = (await _acquire(
      second,
      PracticeAudioSide.input,
    )).ticket!;
    expect(
      await second.release(secondTicket),
      PracticeAudioReleaseStatus.confirmedClosed,
    );
  });

  test(
    'failed initial preflight keeps the isolate owner until recovery',
    () async {
      final firstPort = _Port()..clear = () async => false;
      final secondPort = _Port();
      final first = PracticeAudioLease(port: firstPort);
      final second = PracticeAudioLease(port: secondPort);
      final secondOldContext = second.captureContext();

      expect(
        (await _acquire(first, PracticeAudioSide.input)).status,
        PracticeAudioAcquireStatus.blockedUnconfirmed,
      );
      expect(firstPort.opens, isEmpty);
      expect(
        (await second.acquire(
          PracticeAudioSide.output,
          context: secondOldContext,
        )).status,
        PracticeAudioAcquireStatus.blockedUnconfirmed,
      );
      expect(secondPort.opens, isEmpty);
      firstPort.clear = () async => true;
      expect(await first.recover(), PracticeAudioReleaseStatus.confirmedClosed);
      expect(
        (await second.acquire(
          PracticeAudioSide.output,
          context: secondOldContext,
        )).status,
        PracticeAudioAcquireStatus.staleContext,
      );
      final ticket = (await _acquire(second, PracticeAudioSide.output)).ticket!;
      expect(
        await second.release(ticket),
        PracticeAudioReleaseStatus.confirmedClosed,
      );
    },
  );

  test('idle invalidation fences a delayed old account context', () async {
    final port = _Port();
    final lease = PracticeAudioLease(port: port);
    final oldContext = lease.captureContext();
    expect(
      await lease.invalidate(PracticeAudioInvalidationReason.accountChange),
      PracticeAudioReleaseStatus.alreadyIdle,
    );
    expect(
      (await lease.acquire(
        PracticeAudioSide.input,
        context: oldContext,
      )).status,
      PracticeAudioAcquireStatus.staleContext,
    );
    expect(port.opens, isEmpty);
    final ticket = (await _acquire(lease, PracticeAudioSide.input)).ticket!;
    expect(
      await lease.release(ticket),
      PracticeAudioReleaseStatus.confirmedClosed,
    );
  });

  test('active invalidation fences a delayed old background context', () async {
    final port = _Port();
    final lease = PracticeAudioLease(port: port);
    final oldContext = lease.captureContext();
    final ticket = (await lease.acquire(
      PracticeAudioSide.input,
      context: oldContext,
    )).ticket!;
    expect(
      await lease.invalidate(PracticeAudioInvalidationReason.background),
      PracticeAudioReleaseStatus.confirmedClosed,
    );
    expect(await lease.release(ticket), PracticeAudioReleaseStatus.staleTicket);
    expect(
      (await lease.acquire(
        PracticeAudioSide.output,
        context: oldContext,
      )).status,
      PracticeAudioAcquireStatus.staleContext,
    );
    final freshTicket = (await _acquire(
      lease,
      PracticeAudioSide.output,
    )).ticket!;
    expect(
      await lease.release(freshTicket),
      PracticeAudioReleaseStatus.confirmedClosed,
    );
  });

  test('route event on another instance fences and closes the owner', () async {
    final ownerPort = _Port();
    final owner = PracticeAudioLease(port: ownerPort);
    final observer = PracticeAudioLease(port: _Port());
    final oldContext = owner.captureContext();
    final ticket = (await owner.acquire(
      PracticeAudioSide.output,
      context: oldContext,
    )).ticket!;
    expect(
      await observer.invalidate(PracticeAudioInvalidationReason.routeChange),
      PracticeAudioReleaseStatus.confirmedClosed,
    );
    expect(ownerPort.closeCalls, 1);
    expect(await owner.release(ticket), PracticeAudioReleaseStatus.staleTicket);
    expect(
      (await owner.acquire(
        PracticeAudioSide.output,
        context: oldContext,
      )).status,
      PracticeAudioAcquireStatus.staleContext,
    );
    final freshTicket = (await _acquire(
      owner,
      PracticeAudioSide.output,
    )).ticket!;
    expect(
      await owner.release(freshTicket),
      PracticeAudioReleaseStatus.confirmedClosed,
    );
  });

  test(
    'ticket from another instance cannot close a same-generation owner',
    () async {
      final first = PracticeAudioLease(port: _Port());
      final second = PracticeAudioLease(port: _Port());
      final firstTicket = (await _acquire(
        first,
        PracticeAudioSide.output,
      )).ticket!;
      expect(
        await first.release(firstTicket),
        PracticeAudioReleaseStatus.confirmedClosed,
      );
      final secondTicket = (await _acquire(
        second,
        PracticeAudioSide.output,
      )).ticket!;
      expect(
        await second.release(firstTicket),
        PracticeAudioReleaseStatus.staleTicket,
      );
      expect(second.phase, PracticeAudioLeasePhase.outputActive);
      expect(
        await second.release(secondTicket),
        PracticeAudioReleaseStatus.confirmedClosed,
      );
    },
  );
}
