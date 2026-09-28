import 'dart:async';

/// An app-local ownership boundary for future lesson playback and optional
/// microphone capture. This file does not open either native resource itself.
enum PracticeAudioSide { input, output }

enum PracticeAudioLeasePhase {
  idle,
  openingInput,
  inputActive,
  closingInput,
  openingOutput,
  outputActive,
  closingOutput,
  recovering,
  blockedUnconfirmed,
}

enum PracticeAudioInvalidationReason { routeChange, accountChange, background }

enum PracticeAudioAcquireStatus {
  acquired,
  busy,
  blockedUnconfirmed,
  staleContext,
  cancelled,
  openFailed,
}

enum PracticeAudioReleaseStatus {
  confirmedClosed,
  alreadyIdle,
  busy,
  blockedUnconfirmed,
  pendingNative,
  staleTicket,
}

/// A ticket can release only the particular successful acquisition that made
/// it. A previous screen cannot close a later screen's audio session.
final class PracticeAudioTicket {
  const PracticeAudioTicket._(this._owner, this.side, this.generation);

  final PracticeAudioLease _owner;
  final PracticeAudioSide side;
  final int generation;
}

/// Captured by the current route/account owner before it schedules audio work.
/// An invalidated screen must not refresh this token for a delayed callback.
final class PracticeAudioContext {
  const PracticeAudioContext._(
    this._owner,
    this._leaseEpoch,
    this._isolateEpoch,
  );

  final PracticeAudioLease _owner;
  final int _leaseEpoch;
  final int _isolateEpoch;
}

final class PracticeAudioAcquireResult {
  const PracticeAudioAcquireResult._(this.status, this.ticket);

  final PracticeAudioAcquireStatus status;
  final PracticeAudioTicket? ticket;
}

/// The eventual native adapter must use one process owner for both sides.
/// [readAllClear] may return true only after input, output, and their shared
/// audio-session resources have a confirmed close receipt. A Dart dispose or
/// a timed-out platform reply does not establish that receipt.
abstract interface class PracticeAudioLeasePort {
  Future<bool> readAllClear();
  Future<void> open(PracticeAudioSide side);
  Future<void> closeAll();
}

/// Reserves a side synchronously before its first asynchronous platform call.
/// Unknown release remains sticky until [recover] is explicitly requested.
/// The shared owner covers this Dart isolate only, not another Flutter engine,
/// isolate, or native process. This is not an audio player or lesson result.
final class PracticeAudioLease {
  PracticeAudioLease({
    required PracticeAudioLeasePort port,
    this.operationTimeout = const Duration(seconds: 3),
  }) : _port = port {
    if (operationTimeout <= Duration.zero) {
      throw ArgumentError.value(operationTimeout, 'operationTimeout');
    }
  }

  final PracticeAudioLeasePort _port;
  final Duration operationTimeout;
  static PracticeAudioLease? _isolateOwner;
  static int _isolateEpoch = 0;
  PracticeAudioLeasePhase _phase = PracticeAudioLeasePhase.idle;
  PracticeAudioSide? _side;
  PracticeAudioInvalidationReason? _lastInvalidationReason;
  Future<PracticeAudioAcquireResult>? _opening;
  Future<PracticeAudioReleaseStatus>? _closing;
  int _generation = 0;
  int _contextEpoch = 0;
  int _nativePending = 0;

  PracticeAudioLeasePhase get phase => _phase;
  PracticeAudioInvalidationReason? get lastInvalidationReason =>
      _lastInvalidationReason;

  PracticeAudioContext captureContext() =>
      PracticeAudioContext._(this, _contextEpoch, _isolateEpoch);

  Future<PracticeAudioAcquireResult> acquire(
    PracticeAudioSide side, {
    required PracticeAudioContext context,
  }) {
    if (!identical(context._owner, this) ||
        context._leaseEpoch != _contextEpoch ||
        context._isolateEpoch != _isolateEpoch) {
      return Future.value(
        const PracticeAudioAcquireResult._(
          PracticeAudioAcquireStatus.staleContext,
          null,
        ),
      );
    }
    if (_phase == PracticeAudioLeasePhase.blockedUnconfirmed) {
      return Future.value(
        const PracticeAudioAcquireResult._(
          PracticeAudioAcquireStatus.blockedUnconfirmed,
          null,
        ),
      );
    }
    if (_phase != PracticeAudioLeasePhase.idle) {
      return Future.value(
        const PracticeAudioAcquireResult._(
          PracticeAudioAcquireStatus.busy,
          null,
        ),
      );
    }
    final owner = _isolateOwner;
    if (owner != null && !identical(owner, this)) {
      return Future.value(
        PracticeAudioAcquireResult._(
          owner._phase == PracticeAudioLeasePhase.blockedUnconfirmed
              ? PracticeAudioAcquireStatus.blockedUnconfirmed
              : PracticeAudioAcquireStatus.busy,
          null,
        ),
      );
    }

    // Both process-isolate ownership and local phase are reserved before
    // readAllClear or open can yield, including calls from another instance.
    _isolateOwner = this;
    final generation = ++_generation;
    _side = side;
    _phase = switch (side) {
      PracticeAudioSide.input => PracticeAudioLeasePhase.openingInput,
      PracticeAudioSide.output => PracticeAudioLeasePhase.openingOutput,
    };
    final completion = Completer<PracticeAudioAcquireResult>();
    _opening = completion.future;
    unawaited(
      _acquireReserved(side, generation).then<void>(
        completion.complete,
        onError: (Object _, StackTrace _) {
          _block();
          completion.complete(
            const PracticeAudioAcquireResult._(
              PracticeAudioAcquireStatus.blockedUnconfirmed,
              null,
            ),
          );
        },
      ),
    );
    unawaited(
      completion.future.then<void>((_) {
        if (identical(_opening, completion.future)) _opening = null;
      }),
    );
    return completion.future;
  }

  Future<PracticeAudioAcquireResult> _acquireReserved(
    PracticeAudioSide side,
    int generation,
  ) async {
    try {
      if (!await _native(_port.readAllClear)) {
        _block();
        return const PracticeAudioAcquireResult._(
          PracticeAudioAcquireStatus.blockedUnconfirmed,
          null,
        );
      }
    } on Object {
      _block();
      return const PracticeAudioAcquireResult._(
        PracticeAudioAcquireStatus.blockedUnconfirmed,
        null,
      );
    }
    if (generation != _generation) {
      _idle();
      return const PracticeAudioAcquireResult._(
        PracticeAudioAcquireStatus.cancelled,
        null,
      );
    }

    try {
      await _native(() => _port.open(side));
    } on TimeoutException {
      // The original open may still allocate hardware after this reply. Do
      // not race it with close or reset; explicit recovery waits for settling.
      _block();
      return const PracticeAudioAcquireResult._(
        PracticeAudioAcquireStatus.blockedUnconfirmed,
        null,
      );
    } on Object {
      final closed = await _beginClose();
      final cleared = closed == PracticeAudioReleaseStatus.confirmedClosed;
      return PracticeAudioAcquireResult._(
        cleared
            ? generation == _generation
                  ? PracticeAudioAcquireStatus.openFailed
                  : PracticeAudioAcquireStatus.cancelled
            : PracticeAudioAcquireStatus.blockedUnconfirmed,
        null,
      );
    }

    if (generation != _generation) {
      final closed = await _beginClose();
      final cleared = closed == PracticeAudioReleaseStatus.confirmedClosed;
      return PracticeAudioAcquireResult._(
        cleared
            ? PracticeAudioAcquireStatus.cancelled
            : PracticeAudioAcquireStatus.blockedUnconfirmed,
        null,
      );
    }
    _phase = switch (side) {
      PracticeAudioSide.input => PracticeAudioLeasePhase.inputActive,
      PracticeAudioSide.output => PracticeAudioLeasePhase.outputActive,
    };
    return PracticeAudioAcquireResult._(
      PracticeAudioAcquireStatus.acquired,
      PracticeAudioTicket._(this, side, generation),
    );
  }

  Future<PracticeAudioReleaseStatus> release(PracticeAudioTicket ticket) {
    if (!identical(ticket._owner, this) ||
        ticket.generation != _generation ||
        ticket.side != _side) {
      return Future.value(PracticeAudioReleaseStatus.staleTicket);
    }
    if (_phase == PracticeAudioLeasePhase.blockedUnconfirmed) {
      return Future.value(PracticeAudioReleaseStatus.blockedUnconfirmed);
    }
    if (_phase != PracticeAudioLeasePhase.inputActive &&
        _phase != PracticeAudioLeasePhase.outputActive) {
      return Future.value(PracticeAudioReleaseStatus.busy);
    }
    ++_generation;
    return _beginClose();
  }

  /// Invalidates an in-flight start or closes the active side. A late open
  /// cannot turn an invalidated route/account into an active audio session.
  Future<PracticeAudioReleaseStatus> invalidate(
    PracticeAudioInvalidationReason reason,
  ) {
    _lastInvalidationReason = reason;
    ++_contextEpoch;
    ++_isolateEpoch;
    final owner = _isolateOwner;
    if (owner != null && !identical(owner, this)) {
      // An account/route event observed through any app-local instance must
      // also fence the one that currently owns hardware.
      owner._lastInvalidationReason = reason;
      ++owner._contextEpoch;
      return owner._invalidateOwned();
    }
    return _invalidateOwned();
  }

  Future<PracticeAudioReleaseStatus> _invalidateOwned() {
    if (_phase == PracticeAudioLeasePhase.idle) {
      return Future.value(PracticeAudioReleaseStatus.alreadyIdle);
    }
    if (_phase == PracticeAudioLeasePhase.blockedUnconfirmed) {
      return Future.value(PracticeAudioReleaseStatus.blockedUnconfirmed);
    }
    if (_phase == PracticeAudioLeasePhase.openingInput ||
        _phase == PracticeAudioLeasePhase.openingOutput) {
      ++_generation;
      return _opening!.then(
        (_) => _phase == PracticeAudioLeasePhase.idle
            ? PracticeAudioReleaseStatus.confirmedClosed
            : PracticeAudioReleaseStatus.blockedUnconfirmed,
      );
    }
    if (_phase == PracticeAudioLeasePhase.inputActive ||
        _phase == PracticeAudioLeasePhase.outputActive) {
      ++_generation;
      return _beginClose();
    }
    return _closing ?? Future.value(PracticeAudioReleaseStatus.busy);
  }

  Future<PracticeAudioReleaseStatus> _beginClose({bool recovery = false}) {
    final completion = Completer<PracticeAudioReleaseStatus>();
    _phase = recovery
        ? PracticeAudioLeasePhase.recovering
        : switch (_side) {
            PracticeAudioSide.input => PracticeAudioLeasePhase.closingInput,
            PracticeAudioSide.output => PracticeAudioLeasePhase.closingOutput,
            null => PracticeAudioLeasePhase.recovering,
          };
    _closing = completion.future;
    unawaited(
      _closeAndVerify().then<void>(
        (confirmed) => completion.complete(
          confirmed
              ? PracticeAudioReleaseStatus.confirmedClosed
              : PracticeAudioReleaseStatus.blockedUnconfirmed,
        ),
        onError: (Object _, StackTrace _) {
          _block();
          completion.complete(PracticeAudioReleaseStatus.blockedUnconfirmed);
        },
      ),
    );
    unawaited(
      completion.future.then<void>((_) {
        if (identical(_closing, completion.future)) _closing = null;
      }),
    );
    return completion.future;
  }

  /// User-triggered recovery never starts audio. It can release the sticky
  /// latch only after a fresh close request and an explicit all-clear receipt.
  Future<PracticeAudioReleaseStatus> recover() {
    if (_phase == PracticeAudioLeasePhase.idle) {
      final owner = _isolateOwner;
      if (owner != null && !identical(owner, this)) {
        return Future.value(
          owner._phase == PracticeAudioLeasePhase.blockedUnconfirmed
              ? PracticeAudioReleaseStatus.blockedUnconfirmed
              : PracticeAudioReleaseStatus.busy,
        );
      }
      return Future.value(PracticeAudioReleaseStatus.alreadyIdle);
    }
    if (_phase != PracticeAudioLeasePhase.blockedUnconfirmed) {
      return Future.value(PracticeAudioReleaseStatus.busy);
    }
    if (_nativePending != 0) {
      return Future.value(PracticeAudioReleaseStatus.pendingNative);
    }
    ++_contextEpoch;
    ++_isolateEpoch;
    ++_generation;
    return _beginClose(recovery: true);
  }

  Future<bool> _closeAndVerify() async {
    try {
      await _native(_port.closeAll);
      if (!await _native(_port.readAllClear)) {
        _block();
        return false;
      }
    } on Object {
      _block();
      return false;
    }
    _idle();
    return true;
  }

  Future<T> _native<T>(Future<T> Function() operation) {
    final pending = Future<T>.sync(operation);
    ++_nativePending;
    unawaited(
      pending.then<void>(
        (_) => --_nativePending,
        onError: (Object _, StackTrace _) => --_nativePending,
      ),
    );
    return pending.timeout(operationTimeout);
  }

  void _idle() {
    _phase = PracticeAudioLeasePhase.idle;
    _side = null;
    if (identical(_isolateOwner, this)) _isolateOwner = null;
  }

  void _block() => _phase = PracticeAudioLeasePhase.blockedUnconfirmed;
}
