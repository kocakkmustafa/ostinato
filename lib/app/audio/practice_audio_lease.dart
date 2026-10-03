import 'dart:async';
import 'dart:math';

import 'native_audio_state.dart';

export 'native_audio_state.dart'
    show
        PracticeAudioSide,
        NativeAllAudioState,
        NativeAudioPermit,
        NativeVideoDisposeReceipt,
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
  fencing,
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
  Future<NativeAllAudioState> completeVideoDispose(
    NativeAudioPermit permit, {
    required bool confirmed,
  });
  Future<NativeAllAudioState> cancelVideoReservation(NativeAudioPermit permit);
  Future<NativeAllAudioState> cancelUnclaimedVideoReservation({
    required String attemptOwnerToken,
    required int attemptEngineGeneration,
    required int attemptContextGeneration,
    required String leaseId,
    required int? leaseGeneration,
    required int expectedStateRevision,
  });
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

/// Optional cached-engine handoff protocol. An implementation may only call
/// the write method after the owner retained success of the exact Dart player
/// dispose Future. Ordinary audio ports need no knowledge of this protocol.
abstract interface class PracticeVideoExactAckPort {
  Future<NativeVideoDisposeReceipt> completeRetiredVideoDispose(
    NativeAudioPermit permit,
  );
  Future<NativeVideoDisposeReceipt> readVideoDisposeReceipt(
    NativeAudioPermit permit,
  );
  /// Pins an explicit current-handler retry to this exact old video claim.
  /// A blocked snapshot is only a retry dispatch receipt, never release proof.
  Future<NativeAllAudioState> recoverRetiredVideo(
    NativeVideoDisposeReceipt receipt,
  );
  Future<NativeAllAudioState> refreshOwnerAfterExactVideoDispose(
    NativeVideoDisposeReceipt receipt,
  );
}

typedef PracticeVideoFenceSettler =
    Future<NativeAllAudioState> Function(NativeAllAudioState fenceReceipt);

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
  PracticeAudioLeasePort get port => _port;
  final Duration operationTimeout;
  static PracticeAudioLease? _isolateOwner;
  static int _isolateEpoch = 0;
  PracticeAudioLeasePhase _phase = PracticeAudioLeasePhase.idle;
  PracticeAudioSide? _side;
  PracticeAudioInvalidationReason? _lastInvalidationReason;
  Future<PracticeAudioAcquireResult>? _opening;
  Future<PracticeAudioReleaseStatus>? _closing;
  Future<PracticeAudioReleaseStatus>? _fencing;
  final List<NativeAudioContextReason> _fenceQueue = [];
  bool _fencingActive = false;
  int _generation = 0;
  int _contextEpoch = 0;
  int _nativePending = 0;
  NativeAudioPermit? _permit;
  NativeAllAudioState? _lastNativeState;
  PracticeVideoFenceSettler? _videoFenceSettler;

  /// The video owner must share this exact native channel. The root attaches
  /// it once before any video work; production currently attaches none.
  void attachVideoFenceSettler(
    PracticeAudioLeasePort port,
    PracticeVideoFenceSettler settler,
  ) {
    if (!identical(_port, port) || _videoFenceSettler != null) {
      throw StateError('Video fence owner must share the native audio port');
    }
    _videoFenceSettler = settler;
  }

  PracticeAudioLeasePhase get phase {
    final owner = _isolateOwner;
    if (owner != null &&
        !identical(owner, this) &&
        owner._phase == PracticeAudioLeasePhase.blockedUnconfirmed) {
      return PracticeAudioLeasePhase.blockedUnconfirmed;
    }
    return _phase;
  }

  /// A native-empty owner transition may clear a local retry latch only if
  /// this isolate retained no ticket, opening, close, fence or native call.
  bool get canRefreshQuiescentOwner =>
      _permit == null &&
      _side == null &&
      _opening == null &&
      _closing == null &&
      _nativePending == 0 &&
      !_fencingActive &&
      _fenceQueue.isEmpty &&
      (_isolateOwner == null || identical(_isolateOwner, this));

  void settleQuiescentOwnerRefresh(NativeAllAudioState proof) {
    if (!canRefreshQuiescentOwner || !proof.allClear) {
      throw StateError('Audio lease still owns an uncertain claim');
    }
    ++_generation;
    ++_contextEpoch;
    ++_isolateEpoch;
    _phase = PracticeAudioLeasePhase.recovering;
    _idle();
  }

  PracticeAudioInvalidationReason? get lastInvalidationReason =>
      _lastInvalidationReason;

  PracticeAudioContext captureContext() =>
      PracticeAudioContext._(this, _contextEpoch, _isolateEpoch);

  Future<PracticeAudioAcquireResult> acquire(
    PracticeAudioSide side, {
    required PracticeAudioContext context,
    String? assetId,
  }) {
    // The generic audio lease cannot prove video_player disposal. Native
    // video admission uses a separate reserve/completeVideoDispose handshake
    // and remains unavailable to the shipping lesson route.
    if (side == PracticeAudioSide.video) {
      return Future.value(
        const PracticeAudioAcquireResult._(
          PracticeAudioAcquireStatus.openFailed,
          null,
        ),
      );
    }
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
      PracticeAudioSide.video => throw StateError('Video lease is separate'),
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
      if (_fencingActive) {
        return const PracticeAudioAcquireResult._(
          PracticeAudioAcquireStatus.cancelled,
          null,
        );
      }
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
        if (_fencingActive) {
          return const PracticeAudioAcquireResult._(
            PracticeAudioAcquireStatus.cancelled,
            null,
          );
        }
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
      if (_fencingActive) {
        return const PracticeAudioAcquireResult._(
          PracticeAudioAcquireStatus.cancelled,
          null,
        );
      }
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
      if (_fencingActive) {
        return const PracticeAudioAcquireResult._(
          PracticeAudioAcquireStatus.cancelled,
          null,
        );
      }
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
      PracticeAudioSide.video => throw StateError('Video lease is separate'),
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

  /// Root-level context transition. The native process fence is the single
  /// close authority for an active side; sending closeAll concurrently would
  /// race its newly advanced context against an old permit. Acquisition stays
  /// denied while every queued fence and late opening is reconciled.
  Future<PracticeAudioReleaseStatus> invalidateAndFence(
    PracticeAudioInvalidationReason reason,
  ) {
    _lastInvalidationReason = reason;
    ++_contextEpoch;
    ++_isolateEpoch;
    final owner = _isolateOwner;
    if (owner != null && !identical(owner, this)) {
      owner._lastInvalidationReason = reason;
      ++owner._contextEpoch;
      return owner._fenceOwned(reason);
    }
    return _fenceOwned(reason);
  }

  Future<PracticeAudioReleaseStatus> _fenceOwned(
    PracticeAudioInvalidationReason reason,
  ) {
    final wasBlocked = _phase == PracticeAudioLeasePhase.blockedUnconfirmed;
    _fenceQueue.add(switch (reason) {
      PracticeAudioInvalidationReason.routeChange =>
        NativeAudioContextReason.routeChange,
      PracticeAudioInvalidationReason.accountChange =>
        NativeAudioContextReason.accountChange,
      PracticeAudioInvalidationReason.background =>
        NativeAudioContextReason.background,
    });
    if (_fencingActive) return _fencing!;

    final opening = _opening;
    final closing = _closing;
    _fencingActive = true;
    _isolateOwner = this;
    ++_generation;
    if (!wasBlocked) _phase = PracticeAudioLeasePhase.fencing;
    final completion = Completer<PracticeAudioReleaseStatus>();
    _fencing = completion.future;
    unawaited(
      _fenceAndVerify(
        opening: opening,
        closing: closing,
        wasBlocked: wasBlocked,
      ).then<void>(
        completion.complete,
        onError: (Object _, StackTrace _) {
          _block();
          _fencingActive = false;
          completion.complete(PracticeAudioReleaseStatus.blockedUnconfirmed);
        },
      ),
    );
    unawaited(
      completion.future.then<void>((_) {
        if (identical(_fencing, completion.future)) _fencing = null;
      }),
    );
    return completion.future;
  }

  Future<PracticeAudioReleaseStatus> _fenceAndVerify({
    required Future<PracticeAudioAcquireResult>? opening,
    required Future<PracticeAudioReleaseStatus>? closing,
    required bool wasBlocked,
  }) async {
    var mustRemainBlocked = wasBlocked;
    try {
      // Native closeAll validates its exact permit and old context. A context
      // event must fence immediately, even when that close later times out;
      // the old close receipt remains read-only reconciliation afterward.
      Future<void> drainFences() async {
        while (_fenceQueue.isNotEmpty) {
          final reason = _fenceQueue.removeAt(0);
          final receipt = await _native(() => _port.fenceContext(reason));
          _lastNativeState = receipt;
          final videoSettler = _videoFenceSettler;
          final videoPending = receipt.activeSide == PracticeAudioSide.video;
          if (!receipt.allClear && !videoPending) {
            // Existing capture/output uncertainty remains sticky. Only the
            // exact video owner may turn a pending video close into a clear.
            mustRemainBlocked = true;
            continue;
          }
          if (videoPending && videoSettler == null) {
            mustRemainBlocked = true;
            continue;
          }
          if (videoSettler != null) {
            // Also wait for a video reserve that was in flight when the fence
            // arrived, even if its first native receipt looked empty.
            final settled = await _native(() => videoSettler(receipt));
            _lastNativeState = settled;
            if (!settled.allClear ||
                settled.ownerToken != receipt.ownerToken ||
                settled.engineGeneration != receipt.engineGeneration ||
                settled.contextGeneration != receipt.contextGeneration ||
                settled.stateRevision < receipt.stateRevision ||
                (videoPending &&
                    settled.stateRevision <= receipt.stateRevision)) {
              mustRemainBlocked = true;
              continue;
            }
          }
          final fresh = await _native(_port.readAllAudioState);
          _lastNativeState = fresh;
          if (!fresh.allClear ||
              fresh.ownerToken != receipt.ownerToken ||
              fresh.engineGeneration != receipt.engineGeneration ||
              fresh.contextGeneration != receipt.contextGeneration ||
              fresh.stateRevision < receipt.stateRevision ||
              (videoPending && fresh.stateRevision <= receipt.stateRevision)) {
            mustRemainBlocked = true;
          }
        }
      }

      await drainFences();
      if (closing != null &&
          await closing != PracticeAudioReleaseStatus.confirmedClosed) {
        mustRemainBlocked = true;
      }
      if (opening != null) await opening;
      // A new route/account event can enqueue a reason between an async
      // drain's completion and this continuation. Check again synchronously
      // before releasing the isolate owner or the root barrier.
      do {
        await drainFences();
      } while (_fenceQueue.isNotEmpty);
      if (mustRemainBlocked ||
          _phase == PracticeAudioLeasePhase.blockedUnconfirmed ||
          _nativePending != 0) {
        _block();
        return PracticeAudioReleaseStatus.blockedUnconfirmed;
      }
      _fencingActive = false;
      _idle();
      return PracticeAudioReleaseStatus.confirmedClosed;
    } on Object {
      _block();
      return PracticeAudioReleaseStatus.blockedUnconfirmed;
    } finally {
      _fencingActive = false;
      if (_phase == PracticeAudioLeasePhase.blockedUnconfirmed) {
        _fenceQueue.clear();
      }
    }
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
            PracticeAudioSide.video => throw StateError(
              'Video lease is separate',
            ),
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
    final owner = _isolateOwner;
    if (owner != null && !identical(owner, this)) {
      return owner._phase == PracticeAudioLeasePhase.blockedUnconfirmed
          ? owner.recover()
          : Future.value(PracticeAudioReleaseStatus.busy);
    }
    if (_fencingActive) {
      return Future.value(PracticeAudioReleaseStatus.busy);
    }
    if (_phase == PracticeAudioLeasePhase.idle) {
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
    if (_phase == PracticeAudioLeasePhase.blockedUnconfirmed) return;
    if (_fencingActive) {
      _phase = PracticeAudioLeasePhase.fencing;
      _side = null;
      _permit = null;
      return;
    }
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
