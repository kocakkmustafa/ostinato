/// Versioned, deliberately strict value objects for the process-wide audio
/// arbiter. These are wire receipts, not evidence of physical device release.
enum PracticeAudioSide { input, output, video }

enum NativeAudioCloseReason { userStop, routeChange, accountChange }

enum NativeAudioContextReason { routeChange, accountChange, background }

final class NativeAudioProtocolException implements Exception {
  const NativeAudioProtocolException(this.message);

  final String message;

  @override
  String toString() => 'NativeAudioProtocolException: $message';
}

final class NativeAudioBinding {
  const NativeAudioBinding._({
    required this.ownerToken,
    required this.engineGeneration,
    required this.contextGeneration,
    required this.stateRevision,
  });

  final String ownerToken;
  final int engineGeneration;
  final int contextGeneration;
  final int stateRevision;

  factory NativeAudioBinding.fromWire(Object? wire) {
    final map = _wireMap(wire);
    _version(map);
    return NativeAudioBinding._(
      ownerToken: _token(map, 'ownerToken'),
      engineGeneration: _integer(map, 'engineGeneration', minimum: 1),
      contextGeneration: _integer(map, 'contextGeneration'),
      stateRevision: _integer(map, 'stateRevision'),
    );
  }
}

final class NativeAudioPermit {
  const NativeAudioPermit._({
    required this.ownerToken,
    required this.engineGeneration,
    required this.contextGeneration,
    required this.leaseId,
    required this.leaseGeneration,
    required this.side,
    required this.stateRevision,
  });

  final String ownerToken;
  final int engineGeneration;
  final int contextGeneration;
  final String leaseId;
  final int leaseGeneration;
  final PracticeAudioSide side;
  final int stateRevision;

  factory NativeAudioPermit.reserved({
    required NativeAudioBinding owner,
    required int contextGeneration,
    required String leaseId,
    required PracticeAudioSide side,
    required Object? wire,
  }) {
    final map = _wireMap(wire);
    if (map['status'] != 'reserved' ||
        map['leaseId'] != leaseId ||
        !isNativeAudioToken(leaseId) ||
        contextGeneration < owner.contextGeneration) {
      throw const NativeAudioProtocolException('Invalid reserve receipt');
    }
    return NativeAudioPermit._(
      ownerToken: owner.ownerToken,
      engineGeneration: owner.engineGeneration,
      contextGeneration: contextGeneration,
      leaseId: leaseId,
      leaseGeneration: _integer(map, 'leaseGeneration', minimum: 1),
      side: side,
      stateRevision: _integer(map, 'stateRevision'),
    );
  }

  NativeAudioPermit playing(Object? wire) {
    final map = _wireMap(wire);
    if (map['status'] != 'playing' ||
        map['leaseId'] != leaseId ||
        _integer(map, 'leaseGeneration', minimum: 1) != leaseGeneration) {
      throw const NativeAudioProtocolException('Invalid playback receipt');
    }
    return NativeAudioPermit._(
      ownerToken: ownerToken,
      engineGeneration: engineGeneration,
      contextGeneration: contextGeneration,
      leaseId: leaseId,
      leaseGeneration: leaseGeneration,
      side: side,
      stateRevision: _integer(map, 'stateRevision'),
    );
  }
}

/// An exact, bounded acknowledgement readback. The native player release and
/// the successful Dart dispose acknowledgement are separate facts.
final class NativeVideoDisposeReceipt {
  const NativeVideoDisposeReceipt._({
    required this.permit,
    required this.playerId,
    required this.ackStatus,
    required this.nativeReleaseRecorded,
    required this.leaseSettled,
    required this.snapshot,
  });

  final NativeAudioPermit permit;
  final int? playerId;
  final String ackStatus;
  final bool nativeReleaseRecorded;
  final bool leaseSettled;
  final NativeAllAudioState snapshot;

  bool get ackRecorded => ackStatus == 'RECORDED';

  factory NativeVideoDisposeReceipt.fromWire(
    Object? wire,
    NativeAudioPermit permit,
  ) {
    final map = _wireMap(wire);
    _version(map);
    if (permit.side != PracticeAudioSide.video ||
        _token(map, 'ownerToken') != permit.ownerToken ||
        _integer(map, 'engineGeneration', minimum: 1) !=
            permit.engineGeneration ||
        _integer(map, 'contextGeneration') != permit.contextGeneration ||
        _token(map, 'leaseId') != permit.leaseId ||
        _integer(map, 'leaseGeneration', minimum: 1) !=
            permit.leaseGeneration) {
      throw const NativeAudioProtocolException('Foreign video ACK receipt');
    }
    final status = map['ackStatus'];
    if (status != 'RECORDED' &&
        status != 'NOT_RECORDED' &&
        status != 'UNKNOWN') {
      throw const NativeAudioProtocolException('Invalid video ACK status');
    }
    final playerId = map['playerId'] == null
        ? null
        : _integer(map, 'playerId');
    final release = _boolean(map, 'nativeReleaseRecorded');
    final settled = _boolean(map, 'leaseSettled');
    final snapshot = NativeAllAudioState.fromWire(map['snapshot']);
    if ((status != 'UNKNOWN' && playerId == null) ||
        snapshot.engineGeneration < permit.engineGeneration ||
        (settled &&
            (status != 'RECORDED' || !release || !snapshot.allClear))) {
      throw const NativeAudioProtocolException('Contradictory video ACK receipt');
    }
    return NativeVideoDisposeReceipt._(
      permit: permit,
      playerId: playerId,
      ackStatus: status as String,
      nativeReleaseRecorded: release,
      leaseSettled: settled,
      snapshot: snapshot,
    );
  }
}

/// Native attestation for an explicit, claim-free Activity handoff on one
/// FlutterEngine. This carries no video dispose acknowledgement.
final class NativeQuiescentOwnerHandoff {
  const NativeQuiescentOwnerHandoff._({
    required this.retiredOwnerToken,
    required this.retiredEngineGeneration,
    required this.retiredContextGeneration,
    required this.retiredStateRevision,
    required this.snapshot,
  });

  final String retiredOwnerToken;
  final int retiredEngineGeneration;
  final int retiredContextGeneration;
  final int retiredStateRevision;
  final NativeAllAudioState snapshot;

  factory NativeQuiescentOwnerHandoff.fromWire(
    Object? wire,
    NativeAudioBinding retired,
    NativeAllAudioState? cached,
  ) {
    final outer = _wireMap(wire);
    _version(outer);
    if (outer['bridgeReady'] != true) {
      throw const NativeAudioProtocolException('Quiescent bridge unavailable');
    }
    final map = _wireMap(outer['handoff']);
    _version(map);
    final oldToken = _token(map, 'retiredOwnerToken');
    final oldGeneration = _integer(
      map,
      'retiredEngineGeneration',
      minimum: 1,
    );
    final oldContext = _integer(map, 'retiredContextGeneration');
    final oldRevision = _integer(map, 'retiredStateRevision');
    final snapshot = NativeAllAudioState.fromWire(map['snapshot']);
    if (oldToken != retired.ownerToken ||
        oldGeneration != retired.engineGeneration ||
        oldContext < retired.contextGeneration ||
        oldRevision < retired.stateRevision ||
        (cached != null &&
            (cached.ownerToken != oldToken ||
                cached.engineGeneration != oldGeneration ||
                !cached.allClear ||
                cached.nativeOperationInFlight ||
                cached.requiresExplicitRetry ||
                oldContext < cached.contextGeneration ||
                oldRevision < cached.stateRevision)) ||
        snapshot.ownerToken == oldToken ||
        snapshot.engineGeneration <= oldGeneration ||
        snapshot.contextGeneration <= oldContext ||
        snapshot.stateRevision <= oldRevision ||
        !snapshot.allClear ||
        snapshot.nativeOperationInFlight ||
        snapshot.requiresExplicitRetry) {
      throw const NativeAudioProtocolException('Invalid quiescent handoff');
    }
    return NativeQuiescentOwnerHandoff._(
      retiredOwnerToken: oldToken,
      retiredEngineGeneration: oldGeneration,
      retiredContextGeneration: oldContext,
      retiredStateRevision: oldRevision,
      snapshot: snapshot,
    );
  }
}

final class NativeAllAudioState {
  const NativeAllAudioState._({
    required this.ownerToken,
    required this.engineGeneration,
    required this.contextGeneration,
    required this.stateRevision,
    required this.activeSide,
    required this.activeLeaseGeneration,
    required this.inputPhase,
    required this.outputPhase,
    required this.videoPhase,
    required this.inputReleased,
    required this.outputReleased,
    required this.videoReleased,
    required this.sessionReleased,
    required this.nativeOperationInFlight,
    required this.requiresExplicitRetry,
    required this.allClear,
  });

  final String ownerToken;
  final int engineGeneration;
  final int contextGeneration;
  final int stateRevision;
  final PracticeAudioSide? activeSide;
  final int? activeLeaseGeneration;
  final String inputPhase;
  final String outputPhase;
  final String videoPhase;
  final bool inputReleased;
  final bool outputReleased;
  final bool videoReleased;
  final bool sessionReleased;
  final bool nativeOperationInFlight;
  final bool requiresExplicitRetry;
  final bool allClear;

  bool hasSameSnapshotAs(NativeAllAudioState other) =>
      ownerToken == other.ownerToken &&
      engineGeneration == other.engineGeneration &&
      contextGeneration == other.contextGeneration &&
      stateRevision == other.stateRevision &&
      activeSide == other.activeSide &&
      activeLeaseGeneration == other.activeLeaseGeneration &&
      inputPhase == other.inputPhase &&
      outputPhase == other.outputPhase &&
      videoPhase == other.videoPhase &&
      inputReleased == other.inputReleased &&
      outputReleased == other.outputReleased &&
      videoReleased == other.videoReleased &&
      sessionReleased == other.sessionReleased &&
      nativeOperationInFlight == other.nativeOperationInFlight &&
      requiresExplicitRetry == other.requiresExplicitRetry &&
      allClear == other.allClear;

  static const _inputPhases = {
    'clear',
    'reserved',
    'starting',
    'running',
    'closing',
    'unconfirmedInFlight',
    'unconfirmedQuiescent',
    'releasedAwaitingExplicitRetry',
  };
  static const _outputPhases = {
    'clear',
    'reserved',
    'starting',
    'playing',
    'closing',
    'unconfirmedInFlight',
    'unconfirmedQuiescent',
    'releasedAwaitingExplicitRetry',
  };
  static const _videoPhases = {
    'clear',
    'reserved',
    'closing',
    'unconfirmedQuiescent',
  };

  factory NativeAllAudioState.fromWire(Object? wire) {
    final map = _wireMap(wire);
    _version(map);
    final side = switch (map['activeSide']) {
      null => null,
      'input' => PracticeAudioSide.input,
      'output' => PracticeAudioSide.output,
      'video' => PracticeAudioSide.video,
      _ => throw const NativeAudioProtocolException('Invalid activeSide'),
    };
    final leaseGeneration = map['activeLeaseGeneration'] == null
        ? null
        : _integer(map, 'activeLeaseGeneration', minimum: 1);
    if ((side == null) != (leaseGeneration == null)) {
      throw const NativeAudioProtocolException('Incomplete active lease');
    }
    final inputPhase = _phase(map, 'inputPhase', _inputPhases);
    final outputPhase = _phase(map, 'outputPhase', _outputPhases);
    // Schema 1 predates native video arbitration. Old native builds can only
    // report an empty video side; a new video lease must carry both fields.
    final hasVideoPhase = map.containsKey('videoPhase');
    final hasVideoReleased = map.containsKey('videoReleased');
    if (hasVideoPhase != hasVideoReleased ||
        (side == PracticeAudioSide.video && !hasVideoPhase)) {
      throw const NativeAudioProtocolException('Incomplete video state');
    }
    final videoPhase = hasVideoPhase
        ? _phase(map, 'videoPhase', _videoPhases)
        : 'clear';
    final videoReleased = hasVideoReleased
        ? _boolean(map, 'videoReleased')
        : true;
    final inputReleased = _boolean(map, 'inputReleased');
    final outputReleased = _boolean(map, 'outputReleased');
    final sessionReleased = _boolean(map, 'sessionReleased');
    final inFlight = _boolean(map, 'nativeOperationInFlight');
    final retry = _boolean(map, 'requiresExplicitRetry');
    final allClear = _boolean(map, 'allClear');
    final computedClear =
        side == null &&
        inputPhase == 'clear' &&
        outputPhase == 'clear' &&
        videoPhase == 'clear' &&
        inputReleased &&
        outputReleased &&
        videoReleased &&
        sessionReleased &&
        !inFlight &&
        !retry;
    if (allClear != computedClear) {
      throw const NativeAudioProtocolException('Contradictory allClear');
    }
    if ((side == PracticeAudioSide.input && inputPhase == 'clear') ||
        (side == PracticeAudioSide.output && outputPhase == 'clear') ||
        (side == PracticeAudioSide.video && videoPhase == 'clear')) {
      throw const NativeAudioProtocolException('Active side has clear phase');
    }
    if ((side != PracticeAudioSide.video &&
            (videoPhase != 'clear' || !videoReleased)) ||
        (side == PracticeAudioSide.video && videoReleased)) {
      throw const NativeAudioProtocolException('Contradictory video state');
    }
    return NativeAllAudioState._(
      ownerToken: _token(map, 'ownerToken'),
      engineGeneration: _integer(map, 'engineGeneration', minimum: 1),
      contextGeneration: _integer(map, 'contextGeneration'),
      stateRevision: _integer(map, 'stateRevision'),
      activeSide: side,
      activeLeaseGeneration: leaseGeneration,
      inputPhase: inputPhase,
      outputPhase: outputPhase,
      videoPhase: videoPhase,
      inputReleased: inputReleased,
      outputReleased: outputReleased,
      videoReleased: videoReleased,
      sessionReleased: sessionReleased,
      nativeOperationInFlight: inFlight,
      requiresExplicitRetry: retry,
      allClear: allClear,
    );
  }
}

Map<String, Object?> _wireMap(Object? wire) {
  if (wire is! Map || wire.keys.any((key) => key is! String)) {
    throw const NativeAudioProtocolException('Expected string-keyed map');
  }
  return Map<String, Object?>.from(wire);
}

void _version(Map<String, Object?> map) {
  if (map['schemaVersion'] != 1 || map['schemaVersion'] is! int) {
    throw const NativeAudioProtocolException('Unsupported schema version');
  }
}

final _hex32 = RegExp(r'^[0-9a-f]{32}$');

bool isNativeAudioToken(String value) => _hex32.hasMatch(value);

String _token(Map<String, Object?> map, String name) {
  final value = map[name];
  if (value is! String || !isNativeAudioToken(value)) {
    throw NativeAudioProtocolException('Invalid $name');
  }
  return value;
}

int _integer(Map<String, Object?> map, String name, {int minimum = 0}) {
  final value = map[name];
  if (value is! int || value < minimum) {
    throw NativeAudioProtocolException('Invalid $name');
  }
  return value;
}

bool _boolean(Map<String, Object?> map, String name) {
  final value = map[name];
  if (value is! bool) {
    throw NativeAudioProtocolException('Invalid $name');
  }
  return value;
}

String _phase(Map<String, Object?> map, String name, Set<String> allowed) {
  final value = map[name];
  if (value is! String || !allowed.contains(value)) {
    throw NativeAudioProtocolException('Invalid $name');
  }
  return value;
}
