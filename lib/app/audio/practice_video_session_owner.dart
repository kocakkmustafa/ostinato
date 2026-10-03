import 'dart:async';
import 'dart:math';

import 'practice_audio_lease.dart';

/// This port is deliberately smaller than video_player. Constructing an
/// implementation must be side effect free: no native player or audio session
/// may exist before initialize receives the permit. No shipping widget
/// constructs one yet; the native plugin still needs its own permit check.
abstract interface class PracticeVideoPlayerPort {
  /// The adapter must pass this exact permit to native code before create or
  /// any platform audio/session preparation. No shipping adapter exists yet.
  Future<void> initialize(NativeAudioPermit permit);
  Future<void> dispose();
}

enum PracticeVideoSessionPhase {
  idle,
  opening,
  active,
  closing,
  blockedUnconfirmed,
}

enum PracticeVideoOpenStatus {
  ready,
  busy,
  staleContext,
  blockedUnconfirmed,
  nativeBusy,
  initializeFailed,
}

enum PracticeVideoRecoveryStatus {
  alreadyClear,
  confirmedClosed,
  busy,
  blockedUnconfirmed,
}

/// One isolate-local video owner. It reserves the process-wide native video
/// side before a player may initialize and never claims a native release from
/// a failed, timed-out, or foreign player disposal.
final class PracticeVideoSessionOwner {
  PracticeVideoSessionOwner({
    required PracticeAudioLeasePort port,
    this.operationTimeout = const Duration(milliseconds: 1500),
  }) : _port = port {
    if (operationTimeout <= Duration.zero) {
      throw ArgumentError.value(operationTimeout, 'operationTimeout');
    }
  }

  final PracticeAudioLeasePort _port;
  final Duration operationTimeout;
  static PracticeVideoSessionOwner? _isolateOwner;
  PracticeVideoSessionPhase _phase = PracticeVideoSessionPhase.idle;
  PracticeVideoPlayerPort? _player;
  NativeAudioPermit? _permit;
  NativeAllAudioState? _reservePreflight;
  String? _reserveLeaseId;
  Future<PracticeVideoOpenStatus>? _opening;
  Future<NativeAllAudioState?>? _closing;
  int _epoch = 0;
  int _claimSerial = 0;
  bool _initializationUncertain = false;
  bool _initializationStarted = false;
  _ConfirmedVideoDispose? _disposeProof;

  PracticeAudioLeasePort get port => _port;
  PracticeVideoSessionPhase get phase {
    final owner = _isolateOwner;
    if (owner != null &&
        !identical(owner, this) &&
        owner._phase == PracticeVideoSessionPhase.blockedUnconfirmed) {
      return PracticeVideoSessionPhase.blockedUnconfirmed;
    }
    return _phase;
  }

  bool get blocked => phase == PracticeVideoSessionPhase.blockedUnconfirmed;
  bool get busy => phase != PracticeVideoSessionPhase.idle;

  /// Exact video ACK recovery takes precedence whenever a player, permit or
  /// even a pre-reserve attempt survives in this isolate.
  bool get canRefreshQuiescentOwner =>
      _player == null &&
      _permit == null &&
      _reservePreflight == null &&
      _reserveLeaseId == null &&
      _opening == null &&
      _closing == null &&
      _disposeProof == null &&
      !_initializationStarted &&
      !_initializationUncertain &&
      (_isolateOwner == null || identical(_isolateOwner, this));

  void settleQuiescentOwnerRefresh(NativeAllAudioState proof) {
    if (!canRefreshQuiescentOwner || !proof.allClear) {
      throw StateError('Video owner still has an exact claim');
    }
    ++_epoch;
    ++_claimSerial;
    _phase = PracticeVideoSessionPhase.closing;
    _idle();
  }

  /// A root context event calls this synchronously before its single native
  /// fence. The fence settler then waits for any in-flight opening and closes
  /// the matching player with its original permit.
  void invalidate() => ++_epoch;

  Future<PracticeVideoOpenStatus> open(
    PracticeVideoPlayerPort player, {
    required bool Function() isCurrent,
  }) {
    if (blocked) {
      return Future.value(PracticeVideoOpenStatus.blockedUnconfirmed);
    }
    if (_phase != PracticeVideoSessionPhase.idle ||
        (_isolateOwner != null && !identical(_isolateOwner, this))) {
      return Future.value(PracticeVideoOpenStatus.busy);
    }
    if (!isCurrent()) {
      return Future.value(PracticeVideoOpenStatus.staleContext);
    }
    // Claim isolate ownership before the first native read can yield.
    _isolateOwner = this;
    _phase = PracticeVideoSessionPhase.opening;
    _player = player;
    ++_claimSerial;
    _disposeProof = null;
    final epoch = ++_epoch;
    final opening = _openReserved(player, epoch, isCurrent);
    _opening = opening;
    unawaited(
      opening.then<void>((_) {
        if (identical(_opening, opening)) _opening = null;
      }),
    );
    return opening;
  }

  bool _current(int epoch, bool Function() isCurrent) =>
      epoch == _epoch && isCurrent();

  Future<PracticeVideoOpenStatus> _openReserved(
    PracticeVideoPlayerPort player,
    int epoch,
    bool Function() isCurrent,
  ) async {
    try {
      final before = await _native(_port.readAllAudioState);
      if (!before.allClear) {
        _idle();
        return PracticeVideoOpenStatus.nativeBusy;
      }
      if (!_current(epoch, isCurrent)) {
        _idle();
        return PracticeVideoOpenStatus.staleContext;
      }
      final leaseId = _newVideoLeaseId();
      _reservePreflight = before;
      _reserveLeaseId = leaseId;
      final permit = await _native(
        () => _port.reserve(PracticeAudioSide.video, leaseId),
      );
      if (permit.side != PracticeAudioSide.video ||
          permit.leaseId != leaseId ||
          permit.ownerToken != before.ownerToken ||
          permit.engineGeneration != before.engineGeneration ||
          permit.contextGeneration != before.contextGeneration ||
          permit.stateRevision <= before.stateRevision) {
        throw StateError('Video reserve receipt changed owner or context');
      }
      _permit = permit;
      if (!_current(epoch, isCurrent)) {
        return await _retireStale();
      }
      // video_player.init/create must stay behind the already-held permit. An
      // exception or timeout may leave a native create running after Dart has
      // resumed, so only successful init can make disposal confirmable.
      _initializationUncertain = true;
      _initializationStarted = true;
      await player.initialize(permit).timeout(operationTimeout);
      _initializationUncertain = false;
      // The engine can be replaced without a Dart route/account callback while
      // initialize is pending. A successful player Future is not proof that
      // the original native video lease still belongs to this player.
      NativeAllAudioState current;
      try {
        current = await _native(_port.readAllAudioState);
      } on Object {
        await _disposeWithoutAcknowledgement();
        return PracticeVideoOpenStatus.blockedUnconfirmed;
      }
      if (!_matchesReservedVideo(current, permit)) {
        await _disposeWithoutAcknowledgement();
        return PracticeVideoOpenStatus.blockedUnconfirmed;
      }
      if (!_current(epoch, isCurrent)) {
        return await _retireStale();
      }
      _phase = PracticeVideoSessionPhase.active;
      return PracticeVideoOpenStatus.ready;
    } on Object {
      if (_permit == null) {
        // A failed reserve may have allocated native state before its reply.
        _block();
        return PracticeVideoOpenStatus.blockedUnconfirmed;
      }
      final settled = await _closeOwned();
      return settled == null
          ? PracticeVideoOpenStatus.blockedUnconfirmed
          : PracticeVideoOpenStatus.initializeFailed;
    }
  }

  Future<PracticeVideoOpenStatus> _retireStale() async =>
      await _closeOwned() == null
      ? PracticeVideoOpenStatus.blockedUnconfirmed
      : PracticeVideoOpenStatus.staleContext;

  bool _matchesReservedVideo(
    NativeAllAudioState current,
    NativeAudioPermit permit,
  ) =>
      current.ownerToken == permit.ownerToken &&
      current.engineGeneration == permit.engineGeneration &&
      current.contextGeneration == permit.contextGeneration &&
      current.activeSide == PracticeAudioSide.video &&
      current.activeLeaseGeneration == permit.leaseGeneration &&
      current.stateRevision >= permit.stateRevision &&
      current.videoPhase == 'reserved' &&
      current.inputPhase == 'clear' &&
      current.outputPhase == 'clear' &&
      current.inputReleased &&
      current.outputReleased &&
      !current.videoReleased &&
      !current.sessionReleased &&
      !current.nativeOperationInFlight &&
      !current.requiresExplicitRetry &&
      !current.allClear;

  /// User stop needs no second context fence: the video permit remains held
  /// until dispose and a fresh native read both confirm its release.
  Future<bool> close() async {
    final opening = _opening;
    if (opening != null) {
      try {
        await opening.timeout(operationTimeout);
      } on Object {
        _block();
        return false;
      }
    }
    if (_phase == PracticeVideoSessionPhase.idle) return true;
    if (blocked) return false;
    return await _closeOwned() != null;
  }

  /// Called by the audio lease after its one native context fence. Only an
  /// already-held video lease may reconcile a pending video receipt.
  Future<NativeAllAudioState> settleAfterFence(
    NativeAllAudioState fenceReceipt,
  ) async {
    final opening = _opening;
    if (opening != null) {
      try {
        await opening.timeout(operationTimeout);
      } on Object {
        _block();
        throw StateError('Video opening did not settle after fence');
      }
    }
    if (blocked) throw StateError('Video owner is quarantined');
    final permit = _permit;
    if (fenceReceipt.activeSide == PracticeAudioSide.video) {
      if (permit != null &&
          (permit.ownerToken != fenceReceipt.ownerToken ||
              permit.engineGeneration != fenceReceipt.engineGeneration ||
              permit.leaseGeneration != fenceReceipt.activeLeaseGeneration)) {
        await _disposeWithoutAcknowledgement();
        throw StateError('Foreign video fence receipt');
      }
      if (permit != null) {
        final closed = await _closeOwned();
        if (closed == null) {
          throw StateError('Video disposal was not confirmed');
        }
        return closed;
      }
    } else if (permit != null) {
      await _disposeWithoutAcknowledgement();
      throw StateError('Native video lease vanished before disposal');
    }
    final fresh = await _native(_port.readAllAudioState);
    if (!fresh.allClear ||
        fresh.ownerToken != fenceReceipt.ownerToken ||
        fresh.engineGeneration != fenceReceipt.engineGeneration ||
        fresh.contextGeneration != fenceReceipt.contextGeneration ||
        fresh.stateRevision < fenceReceipt.stateRevision ||
        (fenceReceipt.activeSide == PracticeAudioSide.video &&
            fresh.stateRevision <= fenceReceipt.stateRevision)) {
      _block();
      throw StateError('Video fence has no matching close receipt');
    }
    return fresh;
  }

  Future<NativeAllAudioState?> _closeOwned() {
    final closing = _closing;
    if (closing != null) return closing;
    final permit = _permit;
    final player = _player;
    if (permit == null || player == null) {
      _block();
      return Future.value(null);
    }
    _phase = PracticeVideoSessionPhase.closing;
    final future = _disposeAndAcknowledge(permit, player);
    _closing = future;
    unawaited(
      future.then<void>((_) {
        if (identical(_closing, future)) _closing = null;
      }),
    );
    return future;
  }

  Future<NativeAllAudioState?> _disposeAndAcknowledge(
    NativeAudioPermit permit,
    PracticeVideoPlayerPort player,
  ) async {
    // An uninitialized video_player controller can wait indefinitely inside
    // dispose(). The port's side-effect-free construction contract means no
    // native player exists yet, so only the original reservation is cancelled.
    final cancelledBeforeCreate = !_initializationStarted;
    if (_initializationStarted) {
      try {
        await player.dispose().timeout(operationTimeout);
        // This is one isolate-local fact about this exact player and permit.
        // Neither a native release receipt nor a late timed-out Future may
        // manufacture it. Keep it if the first ACK transport attempt fails.
        if (!_initializationUncertain &&
            identical(_permit, permit) &&
            identical(_player, player)) {
          _disposeProof = _ConfirmedVideoDispose(
            permit,
            player,
            _claimSerial,
          );
        }
      } on Object {
        // A timed-out dispose may still complete. Never turn that late callback
        // into a release acknowledgement for this or a newer lease.
      }
    }
    try {
      // Before initialize was invoked there cannot be a native player claim.
      // Keep that cancellation separate from the player-ID release receipt.
      final confirmed = cancelledBeforeCreate ||
          _hasExactDisposeProof(permit, player);
      final deadline = Stopwatch()..start();
      final receipt = await _nativeWithin(
        () => cancelledBeforeCreate
            ? _port.cancelVideoReservation(permit)
            : _port.completeVideoDispose(permit, confirmed: confirmed),
        operationTimeout,
      );
      if (!confirmed) {
        _block();
        return null;
      }
      _rememberExactAckResponse(permit, player, receipt);
      final fresh = await _awaitVideoClosed(_port, permit, receipt, deadline);
      if (fresh == null) {
        _block();
        return null;
      }
      _idle();
      return fresh;
    } on Object {
      _block();
      return null;
    }
  }

  bool _hasExactDisposeProof(
    NativeAudioPermit permit,
    PracticeVideoPlayerPort player,
  ) {
    final proof = _disposeProof;
    return proof != null &&
        !_initializationUncertain &&
        proof.claimSerial == _claimSerial &&
        identical(proof.permit, permit) &&
        identical(proof.player, player) &&
        identical(_permit, permit) &&
        identical(_player, player);
  }

  void _rememberExactAckResponse(
    NativeAudioPermit permit,
    PracticeVideoPlayerPort player,
    NativeAllAudioState receipt,
  ) {
    if (_hasExactDisposeProof(permit, player) &&
        _sameVideoOwner(receipt, permit) &&
        (receipt.allClear || _pendingOwnVideo(receipt, permit))) {
      // A delivered response for the same held claim is distinct from the
      // native player release. It lets a later all-clear close a timed-out
      // poll, but a lost ACK reply does not get this evidence.
      _disposeProof!.ackResponseObserved = true;
    }
  }

  Future<NativeAllAudioState?> _awaitVideoClosed(
    PracticeAudioLeasePort port,
    NativeAudioPermit permit,
    NativeAllAudioState initial,
    Stopwatch deadline,
  ) async {
    var receipt = initial;
    if (!_sameVideoOwner(receipt, permit)) return null;
    while (!receipt.allClear) {
      if (!_pendingOwnVideo(receipt, permit)) return null;
      final remaining = operationTimeout - deadline.elapsed;
      if (remaining <= Duration.zero) return null;
      await Future<void>.delayed(
        remaining < const Duration(milliseconds: 20)
            ? remaining
            : const Duration(milliseconds: 20),
      );
      receipt = await _nativeWithin(
        port.readAllAudioState,
        operationTimeout - deadline.elapsed,
      );
    }
    final fresh = await _nativeWithin(
      port.readAllAudioState,
      operationTimeout - deadline.elapsed,
    );
    if (!fresh.allClear ||
        fresh.ownerToken != receipt.ownerToken ||
        fresh.engineGeneration != receipt.engineGeneration ||
        fresh.contextGeneration != receipt.contextGeneration ||
        fresh.stateRevision < receipt.stateRevision) {
      return null;
    }
    return fresh;
  }

  bool _sameVideoOwner(NativeAllAudioState state, NativeAudioPermit permit) =>
      state.ownerToken == permit.ownerToken &&
      state.engineGeneration == permit.engineGeneration &&
      state.contextGeneration >= permit.contextGeneration &&
      state.stateRevision > permit.stateRevision;

  bool _pendingOwnVideo(NativeAllAudioState state, NativeAudioPermit permit) =>
      _sameVideoOwner(state, permit) &&
      state.activeSide == PracticeAudioSide.video &&
      state.activeLeaseGeneration == permit.leaseGeneration &&
      state.videoPhase == 'closing' &&
      !state.requiresExplicitRetry;

  bool _heldExactVideo(NativeAllAudioState state, NativeAudioPermit permit) =>
      state.ownerToken == permit.ownerToken &&
      state.engineGeneration == permit.engineGeneration &&
      state.contextGeneration >= permit.contextGeneration &&
      state.stateRevision >= permit.stateRevision &&
      state.activeSide == PracticeAudioSide.video &&
      state.activeLeaseGeneration == permit.leaseGeneration &&
      (state.videoPhase == 'reserved' || state.videoPhase == 'closing') &&
      !state.allClear &&
      !state.requiresExplicitRetry;

  /// Explicit user retry can settle a late native release or an old-engine
  /// video lease. Native recoverAll requires an exact player release record;
  /// a Dart dispose bool or a merely empty callback never suffices.
  Future<PracticeVideoRecoveryStatus> recover() => _recoverWithPort(_port);

  Future<PracticeVideoRecoveryStatus> _recoverWithPort(
    PracticeAudioLeasePort recoveryPort,
  ) async {
    final other = _isolateOwner;
    if (other != null && !identical(other, this)) {
      return other._recoverWithPort(recoveryPort);
    }
    if (_phase == PracticeVideoSessionPhase.opening ||
        _phase == PracticeVideoSessionPhase.active ||
        _phase == PracticeVideoSessionPhase.closing) {
      return PracticeVideoRecoveryStatus.busy;
    }
    final permit = _permit;
    try {
      final proof = _disposeProof;
      if (proof != null && recoveryPort is PracticeVideoExactAckPort) {
        final exactPort = recoveryPort as PracticeVideoExactAckPort;
        // Do not start with readAllAudioState: the wire adapter still caches
        // Activity A's binding, while B's current handler is already live.
        if (permit == null ||
            _player == null ||
            !_hasExactDisposeProof(permit, _player!)) {
          return PracticeVideoRecoveryStatus.blockedUnconfirmed;
        }
        NativeVideoDisposeReceipt exact;
        try {
          exact = await _native(
            () => exactPort.completeRetiredVideoDispose(permit),
          );
        } on Object {
          // A lost response may still have committed the exact ACK. This is
          // read-only; UNKNOWN or native-release-only never advances recovery.
          exact = await _native(
            () => exactPort.readVideoDisposeReceipt(permit),
          );
        }
        if (!exact.ackRecorded || exact.playerId == null) {
          return PracticeVideoRecoveryStatus.blockedUnconfirmed;
        }
        if (!exact.nativeReleaseRecorded) {
          if (!_retryableExactVideo(exact, permit)) {
            return PracticeVideoRecoveryStatus.blockedUnconfirmed;
          }
          // This user retry is pinned to the current handler and exact held
          // claim. A blocked response only means dispatch was requested.
          await _native(() => exactPort.recoverRetiredVideo(exact));
          final released = await _awaitExactNativeRelease(
            exactPort,
            permit,
            exact,
          );
          if (released == null) {
            return PracticeVideoRecoveryStatus.blockedUnconfirmed;
          }
          exact = released;
        }
        if (!exact.leaseSettled) {
          // ACK and physical release are separate facts. The native global
          // retry latch may still require one revision-pinned userRetry.
          await _native(() => exactPort.recoverRetiredVideo(exact));
          final settled = await _native(
            () => exactPort.readVideoDisposeReceipt(permit),
          );
          if (!_sameExactReadback(settled, exact)) {
            return PracticeVideoRecoveryStatus.blockedUnconfirmed;
          }
          exact = settled;
        }
        if (!exact.ackRecorded ||
            !exact.nativeReleaseRecorded ||
            !exact.leaseSettled ||
            !exact.snapshot.allClear) {
          return PracticeVideoRecoveryStatus.blockedUnconfirmed;
        }
        final current = await _native(
          () => exactPort.refreshOwnerAfterExactVideoDispose(exact),
        );
        if (!current.allClear ||
            current.ownerToken != exact.snapshot.ownerToken ||
            current.engineGeneration != exact.snapshot.engineGeneration ||
            current.contextGeneration != exact.snapshot.contextGeneration ||
            current.stateRevision < exact.snapshot.stateRevision) {
          return PracticeVideoRecoveryStatus.blockedUnconfirmed;
        }
        _phase = PracticeVideoSessionPhase.closing;
        _idle();
        return PracticeVideoRecoveryStatus.confirmedClosed;
      }
      final before = await _native(recoveryPort.readAllAudioState);
      if (proof != null) {
        if (permit == null ||
            _player == null ||
            !_hasExactDisposeProof(permit, _player!)) {
          return PracticeVideoRecoveryStatus.blockedUnconfirmed;
        }
        if (before.allClear &&
            proof.ackResponseObserved &&
            _sameVideoOwner(before, permit)) {
          final fresh = await _native(recoveryPort.readAllAudioState);
          if (fresh.allClear &&
              _sameCurrentSnapshot(fresh, before) &&
              fresh.stateRevision >= before.stateRevision) {
            _phase = PracticeVideoSessionPhase.closing;
            _idle();
            return PracticeVideoRecoveryStatus.confirmedClosed;
          }
        }
        if (!_heldExactVideo(before, permit)) {
          // An already-clear lease after an ACK reply was lost still needs an
          // exact native ACK receipt. A fresh epoch or another lease cannot
          // consume this old Dart proof.
          return PracticeVideoRecoveryStatus.blockedUnconfirmed;
        }
        final deadline = Stopwatch()..start();
        final receipt = await _nativeWithin(
          () => recoveryPort.completeVideoDispose(permit, confirmed: true),
          operationTimeout,
        );
        _rememberExactAckResponse(permit, _player!, receipt);
        final closed = await _awaitVideoClosed(
          recoveryPort,
          permit,
          receipt,
          deadline,
        );
        if (closed == null) {
          return PracticeVideoRecoveryStatus.blockedUnconfirmed;
        }
        _phase = PracticeVideoSessionPhase.closing;
        _idle();
        return PracticeVideoRecoveryStatus.confirmedClosed;
      }
      if (permit != null &&
          _initializationStarted &&
          !_initializationUncertain) {
        // A real player may have been created, but its dispose Future did not
        // succeed. Native release by itself cannot stand in for Dart ACK.
        return PracticeVideoRecoveryStatus.blockedUnconfirmed;
      }
      var receipt = before;
      final attempt = _reservePreflight;
      final attemptedId = _reserveLeaseId;
      if (permit == null && attempt != null && attemptedId != null) {
        // The reserve response may be lost while its native call is still in
        // flight. A CAS cancellation also fences that late call by lease ID.
        if (before.activeSide != null &&
            before.activeSide != PracticeAudioSide.video) {
          return PracticeVideoRecoveryStatus.blockedUnconfirmed;
        }
        receipt = await _native(
          () => recoveryPort.cancelUnclaimedVideoReservation(
            attemptOwnerToken: attempt.ownerToken,
            attemptEngineGeneration: attempt.engineGeneration,
            attemptContextGeneration: attempt.contextGeneration,
            leaseId: attemptedId,
            leaseGeneration: before.activeLeaseGeneration,
            expectedStateRevision: before.stateRevision,
          ),
        );
        if (!_sameCurrentSnapshot(receipt, before) ||
            receipt.stateRevision <= before.stateRevision ||
            receipt.activeSide != null) {
          return PracticeVideoRecoveryStatus.blockedUnconfirmed;
        }
      } else if (!before.allClear &&
          before.activeSide == PracticeAudioSide.video) {
        if (permit != null &&
            before.activeLeaseGeneration != permit.leaseGeneration) {
          return PracticeVideoRecoveryStatus.blockedUnconfirmed;
        }
        // A known pre-create reserve can be cleared even after its deadline.
        // A claimed player remains held until its exact native release hook.
        if (permit != null &&
            before.ownerToken == permit.ownerToken &&
            before.engineGeneration == permit.engineGeneration) {
          receipt = await _native(
            () => recoveryPort.cancelVideoReservation(permit),
          );
          if (!_sameCurrentSnapshot(receipt, before) ||
              receipt.stateRevision < before.stateRevision) {
            return PracticeVideoRecoveryStatus.blockedUnconfirmed;
          }
        }
        if (!receipt.allClear &&
            receipt.activeSide == PracticeAudioSide.video) {
          final prior = receipt;
          receipt = await _native(
            () => recoveryPort.recoverAll(prior.stateRevision),
          );
          if (!_sameCurrentSnapshot(receipt, prior) ||
              !receipt.allClear ||
              receipt.stateRevision <= prior.stateRevision) {
            return PracticeVideoRecoveryStatus.blockedUnconfirmed;
          }
        }
      }
      if (!receipt.allClear && _quiescentRetry(receipt)) {
        final prior = receipt;
        receipt = await _native(
          () => recoveryPort.recoverAll(prior.stateRevision),
        );
        if (!_sameCurrentSnapshot(receipt, prior) ||
            !receipt.allClear ||
            receipt.stateRevision <= prior.stateRevision) {
          return PracticeVideoRecoveryStatus.blockedUnconfirmed;
        }
      }
      if (!receipt.allClear) {
        return PracticeVideoRecoveryStatus.blockedUnconfirmed;
      }
      final fresh = await _native(recoveryPort.readAllAudioState);
      if (!fresh.allClear ||
          !_sameCurrentSnapshot(fresh, receipt) ||
          fresh.stateRevision < receipt.stateRevision) {
        return PracticeVideoRecoveryStatus.blockedUnconfirmed;
      }
      if (_phase == PracticeVideoSessionPhase.blockedUnconfirmed) {
        _phase = PracticeVideoSessionPhase.closing;
        _idle();
        return PracticeVideoRecoveryStatus.confirmedClosed;
      }
      return before.allClear
          ? PracticeVideoRecoveryStatus.alreadyClear
          : PracticeVideoRecoveryStatus.confirmedClosed;
    } on Object {
      return PracticeVideoRecoveryStatus.blockedUnconfirmed;
    }
  }

  bool _sameCurrentSnapshot(
    NativeAllAudioState next,
    NativeAllAudioState prior,
  ) =>
      next.ownerToken == prior.ownerToken &&
      next.engineGeneration == prior.engineGeneration &&
      next.contextGeneration == prior.contextGeneration;

  bool _retryableExactVideo(
    NativeVideoDisposeReceipt receipt,
    NativeAudioPermit permit,
  ) {
    final state = receipt.snapshot;
    return receipt.ackRecorded &&
        !receipt.nativeReleaseRecorded &&
        !receipt.leaseSettled &&
        state.activeSide == PracticeAudioSide.video &&
        state.activeLeaseGeneration == permit.leaseGeneration &&
        state.videoPhase == 'unconfirmedQuiescent' &&
        state.requiresExplicitRetry &&
        !state.nativeOperationInFlight &&
        !state.allClear;
  }

  bool _sameExactReadback(
    NativeVideoDisposeReceipt next,
    NativeVideoDisposeReceipt prior,
  ) =>
      next.ackRecorded &&
      next.playerId == prior.playerId &&
      next.permit.ownerToken == prior.permit.ownerToken &&
      next.permit.engineGeneration == prior.permit.engineGeneration &&
      next.permit.contextGeneration == prior.permit.contextGeneration &&
      next.permit.leaseId == prior.permit.leaseId &&
      next.permit.leaseGeneration == prior.permit.leaseGeneration &&
      (!prior.nativeReleaseRecorded || next.nativeReleaseRecorded) &&
      (!prior.leaseSettled || next.leaseSettled) &&
      _sameCurrentSnapshot(next.snapshot, prior.snapshot) &&
      next.snapshot.stateRevision >= prior.snapshot.stateRevision &&
      (next.snapshot.stateRevision != prior.snapshot.stateRevision ||
          next.snapshot.hasSameSnapshotAs(prior.snapshot));

  Future<NativeVideoDisposeReceipt?> _awaitExactNativeRelease(
    PracticeVideoExactAckPort port,
    NativeAudioPermit permit,
    NativeVideoDisposeReceipt prior,
  ) async {
    final deadline = Stopwatch()..start();
    var previous = prior;
    while (true) {
      final next = await _native(() => port.readVideoDisposeReceipt(permit));
      if (!_sameExactReadback(next, previous)) return null;
      if (next.nativeReleaseRecorded) return next;
      final state = next.snapshot;
      if (state.activeSide != PracticeAudioSide.video ||
          state.activeLeaseGeneration != permit.leaseGeneration ||
          state.videoPhase != 'closing' ||
          deadline.elapsed >= operationTimeout) {
        return null;
      }
      previous = next;
      final remaining = operationTimeout - deadline.elapsed;
      await Future<void>.delayed(
        remaining < const Duration(milliseconds: 20)
            ? remaining
            : const Duration(milliseconds: 20),
      );
    }
  }

  bool _quiescentRetry(NativeAllAudioState state) =>
      state.activeSide == null &&
      state.inputPhase == 'clear' &&
      state.outputPhase == 'clear' &&
      state.videoPhase == 'clear' &&
      state.inputReleased &&
      state.outputReleased &&
      state.videoReleased &&
      !state.nativeOperationInFlight &&
      state.requiresExplicitRetry;

  Future<void> _disposeWithoutAcknowledgement() async {
    try {
      await _player?.dispose().timeout(operationTimeout);
    } on Object {
      // The old engine/player is not permitted to release a new owner.
    }
    _block();
  }

  Future<T> _native<T>(Future<T> Function() action) =>
      Future<T>.sync(action).timeout(operationTimeout);

  Future<T> _nativeWithin<T>(Future<T> Function() action, Duration remaining) {
    if (remaining <= Duration.zero) {
      return Future<T>.error(TimeoutException('Video close deadline'));
    }
    return Future<T>.sync(action).timeout(remaining);
  }

  void _idle() {
    if (_phase == PracticeVideoSessionPhase.blockedUnconfirmed) return;
    _phase = PracticeVideoSessionPhase.idle;
    _permit = null;
    _reservePreflight = null;
    _reserveLeaseId = null;
    _player = null;
    _initializationUncertain = false;
    _initializationStarted = false;
    _disposeProof = null;
    if (identical(_isolateOwner, this)) _isolateOwner = null;
  }

  void _block() => _phase = PracticeVideoSessionPhase.blockedUnconfirmed;
}

final class _ConfirmedVideoDispose {
  _ConfirmedVideoDispose(this.permit, this.player, this.claimSerial);

  final NativeAudioPermit permit;
  final PracticeVideoPlayerPort player;
  final int claimSerial;
  bool ackResponseObserved = false;
}

String _newVideoLeaseId() {
  final random = Random.secure();
  return List<int>.generate(
    16,
    (_) => random.nextInt(256),
  ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
}
