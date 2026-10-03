import 'package:ostinato/app/audio/native_audio_state.dart';
import 'package:ostinato/app/audio/practice_audio_lease.dart';

/// A typed, in-memory fake. It never opens a platform audio resource.
final class FakePracticeAudioPort implements PracticeAudioLeasePort {
  FakePracticeAudioPort();

  static const ownerToken = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  NativeAudioBinding get _binding => NativeAudioBinding.fromWire({
    'schemaVersion': 1,
    'ownerToken': ownerToken,
    'engineGeneration': engineGeneration,
    'contextGeneration': _context,
    'stateRevision': _revision,
  });
  final _legacyBinding = NativeAudioBinding.fromWire(const {
    'schemaVersion': 1,
    'ownerToken': ownerToken,
    'engineGeneration': 1,
    'contextGeneration': 0,
    'stateRevision': 0,
  });

  Future<bool> Function()? clear;
  Future<void> Function(PracticeAudioSide)? start;
  Future<void> Function(PracticeAudioSide)? beforeReserve;
  Future<void> Function()? stop;
  Future<void> Function(NativeAudioContextReason)? onFence;
  final opens = <PracticeAudioSide>[];
  final fences = <NativeAudioContextReason>[];
  int closeCalls = 0;
  int videoDisposeCalls = 0;
  final videoDisposePermits = <NativeAudioPermit>[];
  final videoDisposeConfirmations = <bool>[];
  bool dropNextVideoDisposeRequest = false;
  bool dropNextVideoDisposeReply = false;
  int videoCancelCalls = 0;
  int unknownVideoCancelCalls = 0;
  bool waitForNativeVideoRelease = false;
  void Function()? onVideoDisposeAcknowledged;
  int engineGeneration = 1;
  int _revision = 0;
  int _context = 0;
  int _leaseGeneration = 0;
  int _leaseContext = 0;
  int _leaseEngine = 0;
  String? _leaseId;
  final _cancelledVideoAttempts = <String>{};
  bool _retryWithoutLease = false;
  bool _videoClosing = false;
  bool _videoUnconfirmed = false;
  bool _videoDisposeAcknowledged = false;
  bool _videoNativeReleased = false;
  PracticeAudioSide? _activeSide;

  void replaceEngineForTest() {
    if (_activeSide == PracticeAudioSide.video && waitForNativeVideoRelease) {
      _retryWithoutLease = true;
    }
    ++engineGeneration;
    _cancelledVideoAttempts.clear();
    advanceContextForTest();
  }

  void requireExplicitRetryWithoutLeaseForTest() {
    if (_activeSide != null) throw StateError('lease still held');
    _retryWithoutLease = true;
    ++_revision;
  }

  void advanceContextForTest() {
    ++_context;
    ++_revision;
    if (_activeSide == PracticeAudioSide.video) _videoClosing = true;
  }

  void releaseNativeVideoForTest() {
    if (_activeSide != PracticeAudioSide.video) {
      throw StateError('no video lease');
    }
    _videoNativeReleased = true;
    if (_videoDisposeAcknowledged) {
      _activeSide = null;
      _videoClosing = false;
    }
    ++_revision;
  }

  Future<NativeAllAudioState> _snapshot() async {
    final confirmed = await (clear?.call() ?? Future.value(true));
    final side = _activeSide;
    final hasLease = side != null;
    final clearNow = confirmed && !hasLease && !_retryWithoutLease;
    return NativeAllAudioState.fromWire({
      'schemaVersion': 1,
      'ownerToken': ownerToken,
      'engineGeneration': engineGeneration,
      'contextGeneration': _context,
      'stateRevision': _revision,
      'activeSide': side?.name,
      'activeLeaseGeneration': hasLease ? _leaseGeneration : null,
      'inputPhase': side == PracticeAudioSide.input
          ? 'reserved'
          : hasLease || clearNow || _retryWithoutLease
          ? 'clear'
          : 'releasedAwaitingExplicitRetry',
      'outputPhase': side == PracticeAudioSide.output
          ? 'playing'
          : hasLease || clearNow || _retryWithoutLease
          ? 'clear'
          : 'releasedAwaitingExplicitRetry',
      'videoPhase': side == PracticeAudioSide.video
          ? _videoUnconfirmed
                ? 'unconfirmedQuiescent'
                : _videoClosing
                ? 'closing'
                : 'reserved'
          : 'clear',
      'inputReleased': side != PracticeAudioSide.input,
      'outputReleased': side != PracticeAudioSide.output,
      'videoReleased': side != PracticeAudioSide.video,
      'sessionReleased': !hasLease,
      'nativeOperationInFlight': false,
      'requiresExplicitRetry':
          _videoUnconfirmed || _retryWithoutLease || (!clearNow && !hasLease),
      'allClear': clearNow,
    });
  }

  @override
  Future<NativeAllAudioState> readAllAudioState() => _snapshot();

  @override
  Future<NativeAudioPermit> reserve(
    PracticeAudioSide side,
    String leaseId,
  ) async {
    await beforeReserve?.call(side);
    final attempt = '$engineGeneration:$_context:$leaseId';
    if (side == PracticeAudioSide.video &&
        _cancelledVideoAttempts.contains(attempt)) {
      throw StateError('cancelled late video reserve');
    }
    final binding = side == PracticeAudioSide.video ? _binding : _legacyBinding;
    opens.add(side);
    _activeSide = side;
    _leaseContext = _context;
    _leaseEngine = engineGeneration;
    _leaseId = leaseId;
    _videoClosing = false;
    _videoUnconfirmed = false;
    _videoDisposeAcknowledged = false;
    _videoNativeReleased = false;
    ++_leaseGeneration;
    ++_revision;
    await (start?.call(side) ?? Future<void>.value());
    return NativeAudioPermit.reserved(
      owner: binding,
      contextGeneration: side == PracticeAudioSide.video
          ? _leaseContext
          : _context,
      leaseId: leaseId,
      side: side,
      wire: {
        'status': 'reserved',
        'leaseId': leaseId,
        'leaseGeneration': _leaseGeneration,
        'stateRevision': _revision,
      },
    );
  }

  @override
  Future<NativeAllAudioState> completeVideoDispose(
    NativeAudioPermit permit, {
    required bool confirmed,
  }) async {
    ++videoDisposeCalls;
    videoDisposePermits.add(permit);
    videoDisposeConfirmations.add(confirmed);
    if (dropNextVideoDisposeRequest) {
      dropNextVideoDisposeRequest = false;
      throw StateError('video ACK request lost before native dispatch');
    }
    if (_activeSide != PracticeAudioSide.video ||
        permit.side != PracticeAudioSide.video ||
        permit.ownerToken != ownerToken ||
        permit.engineGeneration != engineGeneration ||
        permit.contextGeneration != _leaseContext ||
        permit.leaseGeneration != _leaseGeneration ||
        permit.leaseId != _leaseId) {
      throw StateError('stale video permit');
    }
    if (confirmed && waitForNativeVideoRelease) {
      _videoDisposeAcknowledged = true;
      if (_videoNativeReleased) {
        _activeSide = null;
        _videoClosing = false;
      } else {
        _videoClosing = true;
      }
      onVideoDisposeAcknowledged?.call();
    } else if (confirmed) {
      _activeSide = null;
      _videoClosing = false;
    } else {
      _videoClosing = true;
      _videoUnconfirmed = true;
    }
    ++_revision;
    if (dropNextVideoDisposeReply) {
      dropNextVideoDisposeReply = false;
      throw StateError('video ACK reply lost after native dispatch');
    }
    return _snapshot();
  }

  @override
  Future<NativeAllAudioState> cancelVideoReservation(
    NativeAudioPermit permit,
  ) async {
    ++videoCancelCalls;
    if (_activeSide != PracticeAudioSide.video ||
        permit.side != PracticeAudioSide.video ||
        permit.ownerToken != ownerToken ||
        permit.engineGeneration != _leaseEngine ||
        permit.contextGeneration != _leaseContext ||
        permit.leaseGeneration != _leaseGeneration ||
        permit.leaseId != _leaseId) {
      throw StateError('stale video permit');
    }
    if (waitForNativeVideoRelease) return _snapshot();
    _activeSide = null;
    _videoClosing = false;
    _videoUnconfirmed = false;
    ++_revision;
    return _snapshot();
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
    ++unknownVideoCancelCalls;
    if (expectedStateRevision != _revision ||
        attemptContextGeneration > _context) {
      throw StateError('stale video state');
    }
    if (_activeSide == PracticeAudioSide.video) {
      if (attemptOwnerToken != ownerToken ||
          attemptEngineGeneration != _leaseEngine ||
          attemptContextGeneration != _leaseContext ||
          leaseId != _leaseId ||
          leaseGeneration != _leaseGeneration) {
        throw StateError('stale video attempt');
      }
      if (waitForNativeVideoRelease) return _snapshot();
      _activeSide = null;
      _videoClosing = false;
      _videoUnconfirmed = false;
    } else if (_activeSide != null || leaseGeneration != null) {
      throw StateError('foreign lease');
    }
    if (attemptEngineGeneration == engineGeneration &&
        attemptOwnerToken == ownerToken) {
      _cancelledVideoAttempts.add(
        '$attemptEngineGeneration:$attemptContextGeneration:$leaseId',
      );
    }
    ++_revision;
    return _snapshot();
  }

  @override
  Future<NativeAudioPermit> startOutput(
    NativeAudioPermit permit,
    String assetId,
  ) async {
    ++_revision;
    return permit.playing({
      'status': 'playing',
      'leaseId': permit.leaseId,
      'leaseGeneration': permit.leaseGeneration,
      'stateRevision': _revision,
    });
  }

  @override
  Future<NativeAllAudioState> closeAll(
    NativeAudioPermit permit,
    NativeAudioCloseReason reason,
  ) async {
    ++closeCalls;
    await (stop?.call() ?? Future<void>.value());
    if (permit.leaseGeneration != _leaseGeneration ||
        permit.side != _activeSide) {
      throw StateError('stale ticket');
    }
    _activeSide = null;
    ++_revision;
    return _snapshot();
  }

  @override
  Future<NativeAllAudioState> recoverAll(int expectedStateRevision) async {
    if (expectedStateRevision != _revision) {
      throw StateError('revision changed');
    }
    if (_activeSide == PracticeAudioSide.video) {
      if (!waitForNativeVideoRelease ||
          !_videoNativeReleased ||
          !_videoDisposeAcknowledged) {
        return _snapshot();
      }
      _activeSide = null;
      _videoClosing = false;
      ++_revision;
      return _snapshot();
    }
    if (_retryWithoutLease) {
      _retryWithoutLease = false;
      ++_revision;
      return _snapshot();
    }
    ++closeCalls;
    await (stop?.call() ?? Future<void>.value());
    _activeSide = null;
    ++_revision;
    return _snapshot();
  }

  @override
  Future<NativeAllAudioState> fenceContext(
    NativeAudioContextReason reason,
  ) async {
    fences.add(reason);
    await (onFence?.call(reason) ?? Future<void>.value());
    ++_context;
    ++_revision;
    if (_activeSide == PracticeAudioSide.video) {
      ++closeCalls;
      _videoClosing = true;
      ++_revision;
    } else if (_activeSide != null) {
      ++closeCalls;
      await (stop?.call() ?? Future<void>.value());
      _activeSide = null;
      ++_revision;
    }
    return _snapshot();
  }
}
