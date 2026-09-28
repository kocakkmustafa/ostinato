import 'package:flutter/services.dart';

import 'native_audio_state.dart';
import 'practice_audio_lease.dart';

/// Wire adapter only. It is deliberately not installed in the production
/// root until both platform arbiters include the existing capture path.
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
    final previous = _latest?.contextGeneration ?? owner.contextGeneration;
    final wire = await _channel.invokeMethod<Object?>('fenceContext', {
      ..._ownerFields(owner),
      'contextGeneration': previous,
      'reason': reason.name,
    });
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
