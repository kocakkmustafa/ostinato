import 'package:flutter/services.dart';

import 'native_audio_state.dart';
import 'practice_audio_lease.dart';

/// Wire adapter for the shared native process owner. Production acquisition
/// remains denied at the app root until example audio and device acceptance.
final class NativeAudioArbiterChannel implements PracticeAudioLeasePort {
  NativeAudioArbiterChannel({
    MethodChannel? channel,
    Set<String> allowedAssetIds = const {},
  }) : _channel =
           channel ??
           const MethodChannel('com.yulalab.ostinato/practice_audio_v1'),
       _allowedAssetIds = Set.unmodifiable(allowedAssetIds);

  final MethodChannel _channel;
  final Set<String> _allowedAssetIds;
  Future<NativeAudioBinding>? _bindingFuture;
  NativeAllAudioState? _latest;
  // A reserve/play receipt advances native state even before a full snapshot
  // arrives. Older reads must not roll the adapter back to an all-clear state.
  int _revisionFloor = 0;
  Future<NativeAllAudioState>? _fenceTail;
  int _pendingFences = 0;
  bool _fenceFailed = false;
  int _failedFenceSerial = 0;
  int _freshReadForFailedFence = 0;

  /// A synchronous claim for the optional legacy microphone action. The
  /// caller must capture this before permission or preparation can suspend;
  /// it must never refresh the claim after a route/account/lifecycle fence.
  NativeAllAudioState? get capturePreflightSnapshot {
    final state = _latest;
    if (_pendingFences != 0 ||
        _fenceFailed ||
        state == null ||
        !state.allClear ||
        state.stateRevision < _revisionFloor) {
      return null;
    }
    return state;
  }

  Future<NativeAudioBinding> _binding() => _bindingFuture ??= _channel
      .invokeMethod<Object?>('bind', const {'schemaVersion': 1})
      .then(NativeAudioBinding.fromWire);

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
    final owner = await _binding();
    final wire = await _channel.invokeMethod<Object?>(
      'readAllAudioState',
      _ownerFields(owner),
    );
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
    if (_pendingFences != 0 ||
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
    final current = _latest;
    if (_pendingFences != 0 ||
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
    if (_pendingFences != 0 || _fenceFailed) {
      throw const NativeAudioProtocolException('Audio context is fencing');
    }
    _checkPermitCurrent(permit, owner);
    final wire = await _channel.invokeMethod<Object?>('startOutput', {
      ..._permitFields(permit),
      'assetId': assetId,
    });
    final playing = permit.playing(wire);
    final current = _latest;
    if (_pendingFences != 0 ||
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
    ++_pendingFences;
    final previous = _fenceTail;
    final future = previous == null
        ? _sendFenceContext(reason)
        : previous.then((_) => _sendFenceContext(reason));
    _fenceTail = future;
    return future.then(
      (state) {
        --_pendingFences;
        return state;
      },
      onError: (Object error, StackTrace stack) {
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
