import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/services.dart';

import 'native_audio_state.dart';
import 'practice_audio_lease.dart';

/// Wire adapter for the shared native process owner. Production acquisition
/// remains denied at the app root until example audio and device acceptance.
final class NativeAudioArbiterChannel
    implements PracticeAudioLeasePort, PracticeVideoExactAckPort {
  NativeAudioArbiterChannel({
    MethodChannel? channel,
    Set<String> allowedAssetIds = const {},
    TargetPlatform? platform,
  }) : _channel =
           channel ??
           const MethodChannel('com.yulalab.ostinato/practice_audio_v1'),
       _allowedAssetIds = Set.unmodifiable(allowedAssetIds),
       _platform = platform ?? defaultTargetPlatform;

  final MethodChannel _channel;
  final Set<String> _allowedAssetIds;
  final TargetPlatform _platform;
  Future<NativeAudioBinding>? _bindingFuture;
  NativeAudioBinding? _boundOwner;
  int _bindingEpoch = 0;
  bool _refreshInProgress = false;
  bool _staleBoundOwner = false;
  NativeAudioBinding? _quiescentRetryOwner;
  NativeAllAudioState? _quiescentRetrySnapshot;
  NativeAllAudioState? _latest;
  // A reserve/play receipt advances native state even before a full snapshot
  // arrives. Older reads must not roll the adapter back to an all-clear state.
  int _revisionFloor = 0;
  Future<NativeAllAudioState>? _fenceTail;
  int _pendingFences = 0;
  bool _fenceFailed = false;
  int _failedFenceSerial = 0;
  int _freshReadForFailedFence = 0;

  /// Only an explicit recovery action may use a native-attested, empty
  /// same-engine Activity transition. A stale owner never auto-binds B.
  bool get needsQuiescentOwnerRefresh => _staleBoundOwner;

  /// A synchronous claim for the optional legacy microphone action. The
  /// caller must capture this before permission or preparation can suspend;
  /// it must never refresh the claim after a route/account/lifecycle fence.
  NativeAllAudioState? get capturePreflightSnapshot {
    final state = _latest;
    if (_refreshInProgress ||
        _pendingFences != 0 ||
        _fenceFailed ||
        state == null ||
        !state.allClear ||
        state.stateRevision < _revisionFloor) {
      return null;
    }
    return state;
  }

  Future<NativeAudioBinding> _binding() {
    final cached = _bindingFuture;
    if (cached != null) return cached;
    final epoch = _bindingEpoch;
    final future = _channel
        .invokeMethod<Object?>('bind', const {'schemaVersion': 1})
        .then((wire) {
          final owner = NativeAudioBinding.fromWire(wire);
          if (epoch != _bindingEpoch) {
            throw const NativeAudioProtocolException('Superseded audio bind');
          }
          _boundOwner = owner;
          return owner;
        });
    _bindingFuture = future;
    return future;
  }

  void _checkBoundOwner(NativeAudioBinding owner) {
    if (!identical(owner, _boundOwner)) {
      throw const NativeAudioProtocolException('Superseded audio owner');
    }
  }

  Map<String, Object> _ownerFields(NativeAudioBinding owner) => {
    'ownerToken': owner.ownerToken,
    'engineGeneration': owner.engineGeneration,
  };

  Map<String, Object> _permitFields(NativeAudioPermit permit) => {
    'ownerToken': permit.ownerToken,
    'engineGeneration': permit.engineGeneration,
    'contextGeneration': permit.contextGeneration,
    'leaseId': permit.leaseId,
    'leaseGeneration': permit.leaseGeneration,
  };

  NativeAllAudioState _acceptState(Object? wire, NativeAudioBinding owner) {
    return _acceptParsedState(NativeAllAudioState.fromWire(wire), owner);
  }

  NativeAllAudioState _acceptParsedState(
    NativeAllAudioState state,
    NativeAudioBinding owner,
  ) {
    _checkBoundOwner(owner);
    final latest = _latest;
    if (state.ownerToken != owner.ownerToken ||
        state.engineGeneration != owner.engineGeneration ||
        state.contextGeneration <
            (latest?.contextGeneration ?? owner.contextGeneration) ||
        state.stateRevision < (latest?.stateRevision ?? owner.stateRevision) ||
        state.stateRevision < _revisionFloor ||
        (latest != null &&
            state.stateRevision == latest.stateRevision &&
            !state.hasSameSnapshotAs(latest))) {
      throw const NativeAudioProtocolException('Stale audio snapshot');
    }
    _latest = state;
    if (state.stateRevision > _revisionFloor) {
      _revisionFloor = state.stateRevision;
    }
    return state;
  }

  @override
  Future<NativeAllAudioState> readAllAudioState() async {
    final failedFenceAtReadStart = _failedFenceSerial;
    final epoch = _bindingEpoch;
    final owner = await _binding();
    Object? wire;
    try {
      wire = await _channel.invokeMethod<Object?>(
        'readAllAudioState',
        _ownerFields(owner),
      );
    } on PlatformException catch (error) {
      if (error.code == 'stale_audio_owner' &&
          epoch == _bindingEpoch &&
          identical(owner, _boundOwner)) {
        _staleBoundOwner = true;
        _fenceFailed = true;
      }
      rethrow;
    }
    final state = _acceptState(wire, owner);
    if (_fenceFailed && failedFenceAtReadStart == _failedFenceSerial) {
      _freshReadForFailedFence = failedFenceAtReadStart;
    }
    return state;
  }

  @override
  Future<NativeAudioPermit> reserve(
    PracticeAudioSide side,
    String leaseId,
  ) async {
    if (!isNativeAudioToken(leaseId)) {
      throw const NativeAudioProtocolException('Invalid leaseId');
    }
    final owner = await _binding();
    final latest = _latest;
    if (_refreshInProgress ||
        _pendingFences != 0 ||
        _fenceFailed ||
        latest == null ||
        !latest.allClear ||
        latest.stateRevision < _revisionFloor) {
      throw const NativeAudioProtocolException('No all-clear preflight');
    }
    final wire = await _channel.invokeMethod<Object?>('reserve', {
      ..._ownerFields(owner),
      'contextGeneration': latest.contextGeneration,
      'leaseId': leaseId,
      'side': side.name,
    });
    final permit = NativeAudioPermit.reserved(
      owner: owner,
      contextGeneration: latest.contextGeneration,
      leaseId: leaseId,
      side: side,
      wire: wire,
    );
    _checkBoundOwner(owner);
    final current = _latest;
    if (_refreshInProgress ||
        _pendingFences != 0 ||
        _fenceFailed ||
        current == null ||
        current.contextGeneration != latest.contextGeneration ||
        permit.contextGeneration != current.contextGeneration ||
        permit.stateRevision <= latest.stateRevision ||
        permit.stateRevision < current.stateRevision ||
        permit.stateRevision < _revisionFloor) {
      throw const NativeAudioProtocolException('Stale reserve receipt');
    }
    _revisionFloor = permit.stateRevision;
    return permit;
  }

  @override
  Future<NativeAudioPermit> startOutput(
    NativeAudioPermit permit,
    String assetId,
  ) async {
    if (permit.side != PracticeAudioSide.output ||
        !_allowedAssetIds.contains(assetId)) {
      throw const NativeAudioProtocolException('Output asset unavailable');
    }
    final owner = await _binding();
    if (_refreshInProgress || _pendingFences != 0 || _fenceFailed) {
      throw const NativeAudioProtocolException('Audio context is fencing');
    }
    _checkPermitCurrent(permit, owner);
    final wire = await _channel.invokeMethod<Object?>('startOutput', {
      ..._permitFields(permit),
      'assetId': assetId,
    });
    final playing = permit.playing(wire);
    _checkBoundOwner(owner);
    final current = _latest;
    if (_refreshInProgress ||
        _pendingFences != 0 ||
        _fenceFailed ||
        current == null ||
        playing.contextGeneration != current.contextGeneration ||
        playing.stateRevision <= permit.stateRevision ||
        playing.stateRevision < current.stateRevision ||
        playing.stateRevision < _revisionFloor) {
      throw const NativeAudioProtocolException('Stale playback receipt');
    }
    _revisionFloor = playing.stateRevision;
    return playing;
  }

  @override
  Future<NativeAllAudioState> closeAll(
    NativeAudioPermit permit,
    NativeAudioCloseReason reason,
  ) async {
    final owner = await _binding();
    _checkPermitCurrent(permit, owner);
    final wire = await _channel.invokeMethod<Object?>('closeAll', {
      ..._permitFields(permit),
      'reason': reason.name,
    });
    return _acceptClose(wire, owner);
  }

  /// A future video adapter may acknowledge this only after its native player
  /// release hook has recorded the matching player ID. The native arbiter
  /// independently rejects a bare Dart `confirmed: true`. A context fence
  /// may advance while disposal is in flight; the original lease identity
  /// still determines whether this acknowledgement can release it.
  /// The current shipping lesson route never calls this method.
  @override
  Future<NativeAllAudioState> completeVideoDispose(
    NativeAudioPermit permit, {
    required bool confirmed,
  }) async {
    if (permit.side != PracticeAudioSide.video) {
      throw const NativeAudioProtocolException('Not a video permit');
    }
    final owner = await _binding();
    final latest = _latest;
    if (permit.ownerToken != owner.ownerToken ||
        permit.engineGeneration != owner.engineGeneration ||
        (latest != null &&
            latest.stateRevision >= permit.stateRevision &&
            (latest.activeSide != PracticeAudioSide.video ||
                latest.activeLeaseGeneration != permit.leaseGeneration))) {
      throw const NativeAudioProtocolException('Stale video permit');
    }
    final wire = await _channel.invokeMethod<Object?>('completeVideoDispose', {
      ..._permitFields(permit),
      'confirmed': confirmed,
    });
    return _acceptClose(wire, owner);
  }

  @override
  Future<NativeVideoDisposeReceipt> completeRetiredVideoDispose(
    NativeAudioPermit permit,
  ) async {
    if (permit.side != PracticeAudioSide.video) {
      throw const NativeAudioProtocolException('Not a video permit');
    }
    final epoch = _bindingEpoch;
    final wire = await _channel.invokeMethod<Object?>(
      'completeRetiredVideoDispose',
      {..._permitFields(permit), 'confirmed': true},
    );
    if (epoch != _bindingEpoch) {
      throw const NativeAudioProtocolException('Superseded video ACK');
    }
    return NativeVideoDisposeReceipt.fromWire(wire, permit);
  }

  @override
  Future<NativeVideoDisposeReceipt> readVideoDisposeReceipt(
    NativeAudioPermit permit,
  ) async {
    if (permit.side != PracticeAudioSide.video) {
      throw const NativeAudioProtocolException('Not a video permit');
    }
    final epoch = _bindingEpoch;
    final wire = await _channel.invokeMethod<Object?>(
      'readVideoDisposeReceipt',
      _permitFields(permit),
    );
    if (epoch != _bindingEpoch) {
      throw const NativeAudioProtocolException('Superseded video readback');
    }
    return NativeVideoDisposeReceipt.fromWire(wire, permit);
  }

  @override
  Future<NativeAllAudioState> recoverRetiredVideo(
    NativeVideoDisposeReceipt receipt,
  ) async {
    final permit = receipt.permit;
    if (permit.side != PracticeAudioSide.video ||
        !receipt.ackRecorded ||
        receipt.playerId == null ||
        receipt.leaseSettled ||
        _refreshInProgress ||
        _pendingFences != 0) {
      throw const NativeAudioProtocolException('No exact video recovery');
    }
    final epoch = _bindingEpoch;
    // The old cached binding may belong to Activity A. These calls go to the
    // current handler without changing that binding or granting a new permit.
    final exact = await readVideoDisposeReceipt(permit);
    if (epoch != _bindingEpoch ||
        !exact.ackRecorded ||
        exact.playerId != receipt.playerId ||
        (receipt.nativeReleaseRecorded && !exact.nativeReleaseRecorded) ||
        exact.snapshot.ownerToken != receipt.snapshot.ownerToken ||
        exact.snapshot.engineGeneration != receipt.snapshot.engineGeneration ||
        exact.snapshot.contextGeneration != receipt.snapshot.contextGeneration ||
        exact.snapshot.stateRevision < receipt.snapshot.stateRevision) {
      throw const NativeAudioProtocolException('Changed exact video receipt');
    }
    final owner = NativeAudioBinding.fromWire(
      await _channel.invokeMethod<Object?>('bind', const {'schemaVersion': 1}),
    );
    if (epoch != _bindingEpoch ||
        owner.ownerToken != exact.snapshot.ownerToken ||
        owner.engineGeneration != exact.snapshot.engineGeneration ||
        owner.contextGeneration != exact.snapshot.contextGeneration ||
        owner.stateRevision < exact.snapshot.stateRevision) {
      throw const NativeAudioProtocolException('Changed video handler');
    }
    final before = NativeAllAudioState.fromWire(
      await _channel.invokeMethod<Object?>(
        'readAllAudioState',
        _ownerFields(owner),
      ),
    );
    if (epoch != _bindingEpoch ||
        before.ownerToken != owner.ownerToken ||
        before.engineGeneration != owner.engineGeneration ||
        before.contextGeneration != owner.contextGeneration ||
        before.stateRevision < owner.stateRevision ||
        before.stateRevision < exact.snapshot.stateRevision ||
        (before.stateRevision == exact.snapshot.stateRevision &&
            !before.hasSameSnapshotAs(exact.snapshot))) {
      throw const NativeAudioProtocolException('Changed video recovery state');
    }
    final settledVideoHeld =
        before.activeSide == PracticeAudioSide.video &&
        before.activeLeaseGeneration == permit.leaseGeneration &&
        before.videoPhase == 'unconfirmedQuiescent';
    final noVideoHeld = before.activeSide == null &&
        before.videoPhase == 'clear' &&
        before.videoReleased &&
        before.sessionReleased;
    final settle = exact.nativeReleaseRecorded &&
        (settledVideoHeld || noVideoHeld) &&
        before.inputPhase == 'clear' &&
        before.outputPhase == 'clear' &&
        before.inputReleased &&
        before.outputReleased &&
        !before.nativeOperationInFlight &&
        before.requiresExplicitRetry &&
        !before.allClear;
    final retryClose = !exact.nativeReleaseRecorded &&
        before.activeSide == PracticeAudioSide.video &&
        before.activeLeaseGeneration == permit.leaseGeneration &&
        before.videoPhase == 'unconfirmedQuiescent' &&
        before.requiresExplicitRetry &&
        !before.nativeOperationInFlight &&
        !before.allClear;
    if (!settle && !retryClose) {
      throw const NativeAudioProtocolException('Exact video is not retryable');
    }
    final wire = await _channel.invokeMethod<Object?>('recoverAll', {
      ..._ownerFields(owner),
      'expectedStateRevision': before.stateRevision,
      'reason': 'userRetry',
      // Android V8's exact-key channel accepts the original recoverAll shape;
      // iOS V2 checks the old claim tuple again in its current handler.
      if (_platform == TargetPlatform.iOS)
        'exactVideoClaim': _permitFields(permit),
    });
    final map = _map(wire);
    final status = map['status'];
    final after = NativeAllAudioState.fromWire(map['snapshot']);
    if (epoch != _bindingEpoch ||
        (status != 'blocked' && status != 'pending' && status != 'closed') ||
        (status == 'closed') != after.allClear ||
        after.ownerToken != before.ownerToken ||
        after.engineGeneration != before.engineGeneration ||
        after.contextGeneration != before.contextGeneration ||
        after.stateRevision < before.stateRevision ||
        (status == 'closed' && after.stateRevision == before.stateRevision)) {
      throw const NativeAudioProtocolException('Invalid exact recovery receipt');
    }
    // Blocked or pending is dispatch state, never a native release receipt.
    return after;
  }

  @override
  Future<NativeAllAudioState> refreshOwnerAfterExactVideoDispose(
    NativeVideoDisposeReceipt receipt,
  ) async {
    final original = receipt.permit;
    if (!receipt.ackRecorded ||
        !receipt.nativeReleaseRecorded ||
        !receipt.leaseSettled ||
        !receipt.snapshot.allClear ||
        _pendingFences != 0 ||
        _refreshInProgress) {
      throw const NativeAudioProtocolException('Video handoff is not settled');
    }
    // The vendor plugin independently checks records=0, players=0 and the
    // exact old bridge quiescence. No Dart epoch is refreshed on a failed
    // native rebind; the video owner remains quarantined.
    _refreshInProgress = true;
    final priorEpoch = _bindingEpoch;
    late final NativeVideoDisposeReceipt rebound;
    try {
      final reboundWire = await _channel.invokeMethod<Object?>(
        'rebindVideoPermitBridge',
        _permitFields(original),
      );
      if (priorEpoch != _bindingEpoch) {
        throw const NativeAudioProtocolException('Superseded video rebind');
      }
      final reboundMap = _map(reboundWire);
      if (reboundMap['schemaVersion'] != 1 ||
          reboundMap['bridgeReady'] != true) {
        throw const NativeAudioProtocolException('Video bridge did not rebind');
      }
      rebound = NativeVideoDisposeReceipt.fromWire(
        reboundMap['ack'],
        original,
      );
      if (!rebound.ackRecorded ||
          !rebound.nativeReleaseRecorded ||
          !rebound.leaseSettled ||
          !rebound.snapshot.allClear ||
          rebound.snapshot.ownerToken != receipt.snapshot.ownerToken ||
          rebound.snapshot.engineGeneration != receipt.snapshot.engineGeneration ||
          rebound.snapshot.contextGeneration != receipt.snapshot.contextGeneration ||
          rebound.snapshot.stateRevision < receipt.snapshot.stateRevision) {
        throw const NativeAudioProtocolException('Changed video bridge receipt');
      }
    } on Object {
      _refreshInProgress = false;
      rethrow;
    }
    ++_bindingEpoch;
    _bindingFuture = null;
    _boundOwner = null;
    _latest = null;
    _revisionFloor = 0;
    _fenceTail = null;
    _fenceFailed = false;
    _failedFenceSerial = 0;
    _freshReadForFailedFence = 0;
    try {
      final owner = await _binding();
      if (owner.ownerToken != rebound.snapshot.ownerToken ||
          owner.engineGeneration != rebound.snapshot.engineGeneration ||
          owner.engineGeneration < original.engineGeneration ||
          (owner.engineGeneration == original.engineGeneration &&
              owner.ownerToken != original.ownerToken)) {
        throw const NativeAudioProtocolException('Changed handoff owner');
      }
      final first = await readAllAudioState();
      final second = await readAllAudioState();
      if (!first.allClear ||
          !second.allClear ||
          first.ownerToken != owner.ownerToken ||
          second.ownerToken != owner.ownerToken ||
          first.engineGeneration != owner.engineGeneration ||
          second.engineGeneration != owner.engineGeneration ||
          first.contextGeneration != rebound.snapshot.contextGeneration ||
          second.contextGeneration != first.contextGeneration ||
          first.stateRevision < rebound.snapshot.stateRevision ||
          second.stateRevision < first.stateRevision) {
        throw const NativeAudioProtocolException('Unstable video handoff');
      }
      _staleBoundOwner = false;
      _quiescentRetryOwner = null;
      _quiescentRetrySnapshot = null;
      return second;
    } on Object {
      _fenceFailed = true;
      rethrow;
    } finally {
      _refreshInProgress = false;
    }
  }

  /// Explicit retry for A→B with no claim at registration or recovery.
  /// The old binding is retained across a lost B read so a second retry can
  /// ask the same exact native transition; it never grants an old permit.
  Future<NativeAllAudioState> refreshQuiescentOwner() async {
    if (!_staleBoundOwner || _refreshInProgress || _pendingFences != 0) {
      throw const NativeAudioProtocolException('No quiescent owner retry');
    }
    final retired = _quiescentRetryOwner ?? await _binding();
    final cached = _quiescentRetrySnapshot ?? _latest;
    if ((cached != null &&
            (cached.ownerToken != retired.ownerToken ||
                cached.engineGeneration != retired.engineGeneration ||
                !cached.allClear ||
                cached.nativeOperationInFlight ||
                cached.requiresExplicitRetry ||
                (cached.stateRevision < _revisionFloor &&
                    _quiescentRetryOwner == null))) ||
        (cached == null && _quiescentRetryOwner == null &&
            _revisionFloor > retired.stateRevision)) {
      throw const NativeAudioProtocolException('Old owner is not quiescent');
    }
    _refreshInProgress = true;
    final priorEpoch = _bindingEpoch;
    late final NativeQuiescentOwnerHandoff handoff;
    try {
      final wire = await _channel.invokeMethod<Object?>(
        'rebindQuiescentOwner',
        {
          'retiredOwnerToken': retired.ownerToken,
          'retiredEngineGeneration': retired.engineGeneration,
          'reason': 'userRetry',
        },
      );
      if (priorEpoch != _bindingEpoch) {
        throw const NativeAudioProtocolException('Superseded owner retry');
      }
      handoff = NativeQuiescentOwnerHandoff.fromWire(wire, retired, cached);
    } on Object {
      _fenceFailed = true;
      _refreshInProgress = false;
      rethrow;
    }
    _quiescentRetryOwner = retired;
    _quiescentRetrySnapshot = cached;
    ++_bindingEpoch;
    _bindingFuture = null;
    _boundOwner = null;
    _latest = null;
    _revisionFloor = 0;
    _fenceTail = null;
    _failedFenceSerial = 0;
    _freshReadForFailedFence = 0;
    try {
      final owner = await _binding();
      final target = handoff.snapshot;
      if (owner.ownerToken != target.ownerToken ||
          owner.engineGeneration != target.engineGeneration ||
          owner.contextGeneration != target.contextGeneration ||
          owner.stateRevision != target.stateRevision) {
        throw const NativeAudioProtocolException('Changed quiescent owner');
      }
      final first = await readAllAudioState();
      final second = await readAllAudioState();
      if (!first.allClear ||
          !second.allClear ||
          first.ownerToken != target.ownerToken ||
          second.ownerToken != target.ownerToken ||
          first.engineGeneration != target.engineGeneration ||
          second.engineGeneration != target.engineGeneration ||
          first.contextGeneration != target.contextGeneration ||
          second.contextGeneration != target.contextGeneration ||
          first.stateRevision != target.stateRevision ||
          second.stateRevision != target.stateRevision) {
        throw const NativeAudioProtocolException('Unstable quiescent handoff');
      }
      _staleBoundOwner = false;
      _quiescentRetryOwner = null;
      _quiescentRetrySnapshot = null;
      _fenceFailed = false;
      return second;
    } on Object {
      _fenceFailed = true;
      _staleBoundOwner = true;
      rethrow;
    } finally {
      _refreshInProgress = false;
    }
  }

  @override
  Future<NativeAllAudioState> cancelVideoReservation(
    NativeAudioPermit permit,
  ) async {
    if (permit.side != PracticeAudioSide.video) {
      throw const NativeAudioProtocolException('Not a video permit');
    }
    final owner = await _binding();
    if (permit.ownerToken != owner.ownerToken ||
        permit.engineGeneration != owner.engineGeneration) {
      throw const NativeAudioProtocolException('Stale video permit');
    }
    final wire = await _channel.invokeMethod<Object?>(
      'cancelVideoReservation',
      _permitFields(permit),
    );
    return _acceptClose(wire, owner);
  }

  @override
  Future<NativeAllAudioState> cancelUnclaimedVideoReservation({
    required String attemptOwnerToken,
    required int attemptEngineGeneration,
    required int attemptContextGeneration,
    required String leaseId,
    required int? leaseGeneration,
    required int expectedStateRevision,
  }) async {
    if (!isNativeAudioToken(attemptOwnerToken) ||
        !isNativeAudioToken(leaseId) ||
        attemptEngineGeneration < 1 ||
        attemptContextGeneration < 0 ||
        (leaseGeneration != null && leaseGeneration < 1)) {
      throw const NativeAudioProtocolException('Invalid video attempt');
    }
    final owner = await _binding();
    final latest = _latest;
    if (latest == null ||
        latest.ownerToken != owner.ownerToken ||
        latest.engineGeneration != owner.engineGeneration ||
        latest.contextGeneration < attemptContextGeneration ||
        latest.stateRevision != expectedStateRevision ||
        (latest.activeSide != null &&
            (latest.activeSide != PracticeAudioSide.video ||
                latest.activeLeaseGeneration != leaseGeneration)) ||
        (latest.activeSide == null && leaseGeneration != null)) {
      throw const NativeAudioProtocolException('Stale video attempt');
    }
    final wire = await _channel
        .invokeMethod<Object?>('cancelUnclaimedVideoReservation', {
          ..._ownerFields(owner),
          'attemptOwnerToken': attemptOwnerToken,
          'attemptEngineGeneration': attemptEngineGeneration,
          'attemptContextGeneration': attemptContextGeneration,
          'leaseId': leaseId,
          'leaseGeneration': leaseGeneration,
          'expectedStateRevision': expectedStateRevision,
        });
    return _acceptClose(wire, owner);
  }

  @override
  Future<NativeAllAudioState> recoverAll(int expectedStateRevision) async {
    final failedFenceAtRecoveryStart = _failedFenceSerial;
    final owner = await _binding();
    final before = _latest;
    if (_pendingFences != 0 ||
        _failedFenceSerial != failedFenceAtRecoveryStart ||
        expectedStateRevision < _revisionFloor ||
        before?.stateRevision != expectedStateRevision ||
        (_fenceFailed &&
            _freshReadForFailedFence != failedFenceAtRecoveryStart)) {
      throw const NativeAudioProtocolException('Changed recovery revision');
    }
    final wire = await _channel.invokeMethod<Object?>('recoverAll', {
      ..._ownerFields(owner),
      'expectedStateRevision': expectedStateRevision,
      'reason': 'userRetry',
    });
    final current = _latest;
    if (_pendingFences != 0 ||
        _failedFenceSerial != failedFenceAtRecoveryStart ||
        current == null ||
        !current.hasSameSnapshotAs(before!) ||
        current.stateRevision < _revisionFloor) {
      throw const NativeAudioProtocolException('Changed recovery revision');
    }
    final map = _map(wire);
    if (map['status'] == 'closed') {
      final closed = NativeAllAudioState.fromWire(map['snapshot']);
      if (closed.contextGeneration != before.contextGeneration ||
          closed.stateRevision <= before.stateRevision) {
        throw const NativeAudioProtocolException('Stale recovery receipt');
      }
    }
    final state = _acceptClose(wire, owner);
    if (map['status'] == 'closed' && state.allClear) {
      // A successful explicit retry is the only way to unpoison a failed
      // fence. Reset its failed Future as well as the acquisition latch.
      _fenceFailed = false;
      _fenceTail = null;
    }
    return state;
  }

  @override
  Future<NativeAllAudioState> fenceContext(NativeAudioContextReason reason) {
    if (_refreshInProgress) {
      return Future<NativeAllAudioState>.error(
        const NativeAudioProtocolException('Audio owner is refreshing'),
      );
    }
    final epoch = _bindingEpoch;
    ++_pendingFences;
    final previous = _fenceTail;
    final future = previous == null
        ? _sendFenceContext(reason)
        : previous.then((_) => _sendFenceContext(reason));
    _fenceTail = future;
    return future.then(
      (state) {
        if (epoch != _bindingEpoch) {
          throw const NativeAudioProtocolException('Superseded audio fence');
        }
        --_pendingFences;
        return state;
      },
      onError: (Object error, StackTrace stack) {
        if (epoch != _bindingEpoch) {
          throw const NativeAudioProtocolException('Superseded audio fence');
        }
        --_pendingFences;
        _fenceFailed = true;
        ++_failedFenceSerial;
        Error.throwWithStackTrace(error, stack);
      },
    );
  }

  Future<NativeAllAudioState> _sendFenceContext(
    NativeAudioContextReason reason,
  ) async {
    final epoch = _bindingEpoch;
    final owner = await _binding();
    var previous = _latest?.contextGeneration ?? owner.contextGeneration;
    Future<Object?> send() => _channel.invokeMethod<Object?>('fenceContext', {
      ..._ownerFields(owner),
      'contextGeneration': previous,
      'reason': reason.name,
    });
    Object? wire;
    try {
      wire = await send();
    } on PlatformException catch (error) {
      if (error.code == 'stale_audio_owner' &&
          epoch == _bindingEpoch &&
          identical(owner, _boundOwner)) {
        _staleBoundOwner = true;
        _fenceFailed = true;
      }
      if (error.code != 'stale_audio_context') rethrow;
      // A native route/lifecycle observer can close first. Retry exactly
      // once only if a new read proves the process empty and context newer.
      // Any held or ambiguous resource stays behind the failed-fence latch.
      final fresh = await readAllAudioState();
      if (!fresh.allClear || fresh.contextGeneration <= previous) rethrow;
      previous = fresh.contextGeneration;
      wire = await send();
    }
    final map = _map(wire);
    final status = map['status'];
    if (status != 'closed' && status != 'pending' && status != 'blocked') {
      throw const NativeAudioProtocolException('Invalid fence status');
    }
    final state = NativeAllAudioState.fromWire(map['snapshot']);
    if (map['contextGeneration'] != state.contextGeneration ||
        map['stateRevision'] != state.stateRevision ||
        state.contextGeneration <= previous ||
        (status == 'closed') != state.allClear) {
      throw const NativeAudioProtocolException('Invalid fence receipt');
    }
    return _acceptParsedState(state, owner);
  }

  NativeAllAudioState _acceptClose(Object? wire, NativeAudioBinding owner) {
    final map = _map(wire);
    final status = map['status'];
    if (status != 'closed' &&
        status != 'pending' &&
        status != 'blocked' &&
        status != 'stale') {
      throw const NativeAudioProtocolException('Invalid close status');
    }
    final state = NativeAllAudioState.fromWire(map['snapshot']);
    if ((status == 'closed') != state.allClear) {
      throw const NativeAudioProtocolException('Invalid close receipt');
    }
    return _acceptParsedState(state, owner);
  }

  void _checkPermitCurrent(NativeAudioPermit permit, NativeAudioBinding owner) {
    final latest = _latest;
    if (permit.ownerToken != owner.ownerToken ||
        permit.engineGeneration != owner.engineGeneration ||
        latest == null ||
        permit.contextGeneration != latest.contextGeneration ||
        (latest.activeLeaseGeneration != null &&
            (latest.activeLeaseGeneration != permit.leaseGeneration ||
                latest.activeSide != permit.side)) ||
        (latest.allClear && latest.stateRevision > permit.stateRevision)) {
      throw const NativeAudioProtocolException('Stale permit owner');
    }
  }
}

Map<String, Object?> _map(Object? wire) {
  if (wire is! Map || wire.keys.any((key) => key is! String)) {
    throw const NativeAudioProtocolException('Invalid receipt map');
  }
  return Map<String, Object?>.from(wire);
}
