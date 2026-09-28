import 'dart:async';
import 'dart:math';

import 'native_audio_state.dart';

export 'native_audio_state.dart'
    show
        PracticeAudioSide,
        NativeAllAudioState,
        NativeAudioPermit,
        NativeAudioCloseReason,
        NativeAudioContextReason;

/// An app-local ownership boundary for future lesson playback and optional
/// microphone capture. This file does not open either native resource itself.
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
  const PracticeAudioTicket._(
    this._owner,
    this.side,
    this.generation,
    this.permit,
  );

  final PracticeAudioLease _owner;
  final PracticeAudioSide side;
  final int generation;
  final NativeAudioPermit permit;
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
/// The native implementation must cover existing capture, future output, and
/// their shared session. All replies are checked against a single owner.
abstract interface class PracticeAudioLeasePort {
  Future<NativeAllAudioState> readAllAudioState();
  Future<NativeAudioPermit> reserve(PracticeAudioSide side, String leaseId);
  Future<NativeAudioPermit> startOutput(
    NativeAudioPermit permit,
    String assetId,
  );
  Future<NativeAllAudioState> closeAll(
    NativeAudioPermit permit,
    NativeAudioCloseReason reason,
  );
  Future<NativeAllAudioState> recoverAll(int expectedStateRevision);
  Future<NativeAllAudioState> fenceContext(NativeAudioContextReason reason);
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
  NativeAudioPermit? _permit;
  NativeAllAudioState? _lastNativeState;

  PracticeAudioLeasePhase get phase => _phase;
  PracticeAudioInvalidationReason? get lastInvalidationReason =>
      _lastInvalidationReason;

  PracticeAudioContext captureContext() =>
      PracticeAudioContext._(this, _contextEpoch, _isolateEpoch);

  Future<PracticeAudioAcquireResult> acquire(
    PracticeAudioSide side, {
    required PracticeAudioContext context,
    String? assetId,
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
    if (side == PracticeAudioSide.output &&
        (assetId == null || assetId.isEmpty)) {
      return Future.value(
        const PracticeAudioAcquireResult._(
          PracticeAudioAcquireStatus.openFailed,
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
    // readAllAudioState or reserve can yield, including another instance.
    _isolateOwner = this;
    final generation = ++_generation;
    _side = side;
    _permit = null;
    _phase = switch (side) {
      PracticeAudioSide.input => PracticeAudioLeasePhase.openingInput,
      PracticeAudioSide.output => PracticeAudioLeasePhase.openingOutput,
    };
    final completion = Completer<PracticeAudioAcquireResult>();
    _opening = completion.future;
    unawaited(
      _acquireReserved(side, generation, assetId).then<void>(
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
    String? assetId,
  ) async {
    late NativeAllAudioState preflight;
    try {
      preflight = await _native(_port.readAllAudioState);
      _lastNativeState = preflight;
      if (!preflight.allClear) {
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
      final leaseId = _newLeaseId();
      final permit = await _native(() => _port.reserve(side, leaseId));
      if (permit.leaseId != leaseId ||
          permit.side != side ||
          permit.ownerToken != preflight.ownerToken ||
          permit.engineGeneration != preflight.engineGeneration ||
          permit.contextGeneration != preflight.contextGeneration ||
          permit.stateRevision <= preflight.stateRevision) {
        _block();
        return const PracticeAudioAcquireResult._(
          PracticeAudioAcquireStatus.blockedUnconfirmed,
          null,
        );
      }
      _permit = permit;
      if (generation != _generation) {
        final closed = await _beginClose();
        return PracticeAudioAcquireResult._(
          closed == PracticeAudioReleaseStatus.confirmedClosed
              ? PracticeAudioAcquireStatus.cancelled
              : PracticeAudioAcquireStatus.blockedUnconfirmed,
          null,
        );
      }
      if (side == PracticeAudioSide.output) {
        final playing = await _native(
          () => _port.startOutput(permit, assetId!),
        );
        if (playing.leaseId != permit.leaseId ||
            playing.leaseGeneration != permit.leaseGeneration ||
            playing.ownerToken != permit.ownerToken ||
            playing.engineGeneration != permit.engineGeneration ||
            playing.contextGeneration != permit.contextGeneration ||
            playing.side != PracticeAudioSide.output ||
            playing.stateRevision <= permit.stateRevision) {
          _block();
          return const PracticeAudioAcquireResult._(
            PracticeAudioAcquireStatus.blockedUnconfirmed,
            null,
          );
        }
        _permit = playing;
      }
    } on TimeoutException {
      // The native operation may still allocate hardware after this reply. Do
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
      PracticeAudioTicket._(this, side, generation, _permit!),
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
    return _beginClose(reason: NativeAudioCloseReason.userStop);
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
      return owner._invalidateOwned(reason);
    }
    return _invalidateOwned(reason);
  }

  Future<PracticeAudioReleaseStatus> _invalidateOwned(
    PracticeAudioInvalidationReason reason,
  ) {
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
      return _beginClose(
        reason: switch (reason) {
          PracticeAudioInvalidationReason.routeChange =>
            NativeAudioCloseReason.routeChange,
          PracticeAudioInvalidationReason.accountChange =>
            NativeAudioCloseReason.accountChange,
          PracticeAudioInvalidationReason.background =>
            NativeAudioCloseReason.routeChange,
        },
      );
    }
    return _closing ?? Future.value(PracticeAudioReleaseStatus.busy);
  }

  Future<PracticeAudioReleaseStatus> _beginClose({
    bool recovery = false,
    NativeAudioCloseReason reason = NativeAudioCloseReason.userStop,
  }) {
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
      _closeAndVerify(recovery: recovery, reason: reason).then<void>(
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

  Future<bool> _closeAndVerify({
    required bool recovery,
    required NativeAudioCloseReason reason,
  }) async {
    try {
      if (recovery) {
        // Read a new revision after any late native operation has settled.
        // recoverAll never starts audio or closes a newer lease.
        final before = await _native(_port.readAllAudioState);
        final previous = _lastNativeState;
        if (previous != null &&
            (before.ownerToken != previous.ownerToken ||
                before.engineGeneration != previous.engineGeneration ||
                before.contextGeneration < previous.contextGeneration ||
                before.stateRevision < previous.stateRevision)) {
          _block();
          return false;
        }
        _lastNativeState = before;
        final receipt = await _native(
          () => _port.recoverAll(before.stateRevision),
        );
        _lastNativeState = receipt;
        if (!receipt.allClear) {
          _block();
          return false;
        }
      } else {
        final permit = _permit;
        if (permit == null) {
          _block();
          return false;
        }
        final receipt = await _native(() => _port.closeAll(permit, reason));
        _lastNativeState = receipt;
        if (!receipt.allClear ||
            receipt.ownerToken != permit.ownerToken ||
            receipt.engineGeneration != permit.engineGeneration ||
            receipt.stateRevision <= permit.stateRevision) {
          _block();
          return false;
        }
      }
      final finalState = await _native(_port.readAllAudioState);
      _lastNativeState = finalState;
      if (!finalState.allClear) {
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
    _permit = null;
    _lastNativeState = null;
    if (identical(_isolateOwner, this)) _isolateOwner = null;
  }

  void _block() => _phase = PracticeAudioLeasePhase.blockedUnconfirmed;
}

String _newLeaseId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
}
