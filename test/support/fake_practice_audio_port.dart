import 'package:ostinato/app/audio/native_audio_state.dart';
import 'package:ostinato/app/audio/practice_audio_lease.dart';

/// A typed, in-memory fake. It never opens a platform audio resource.
final class FakePracticeAudioPort implements PracticeAudioLeasePort {
  FakePracticeAudioPort();

  static const ownerToken = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  final _binding = NativeAudioBinding.fromWire(const {
    'schemaVersion': 1,
    'ownerToken': ownerToken,
    'engineGeneration': 1,
    'contextGeneration': 0,
    'stateRevision': 0,
  });

  Future<bool> Function()? clear;
  Future<void> Function(PracticeAudioSide)? start;
  Future<void> Function()? stop;
  final opens = <PracticeAudioSide>[];
  int closeCalls = 0;
  int _revision = 0;
  int _context = 0;
  int _leaseGeneration = 0;
  PracticeAudioSide? _activeSide;

  Future<NativeAllAudioState> _snapshot() async {
    final confirmed = await (clear?.call() ?? Future.value(true));
    final side = _activeSide;
    final hasLease = side != null;
    final clearNow = confirmed && !hasLease;
    return NativeAllAudioState.fromWire({
      'schemaVersion': 1,
      'ownerToken': ownerToken,
      'engineGeneration': 1,
      'contextGeneration': _context,
      'stateRevision': _revision,
      'activeSide': side?.name,
      'activeLeaseGeneration': hasLease ? _leaseGeneration : null,
      'inputPhase': side == PracticeAudioSide.input
          ? 'reserved'
          : side == PracticeAudioSide.output || clearNow
          ? 'clear'
          : 'releasedAwaitingExplicitRetry',
      'outputPhase': side == PracticeAudioSide.output
          ? 'playing'
          : side == PracticeAudioSide.input || clearNow
          ? 'clear'
          : 'releasedAwaitingExplicitRetry',
      'inputReleased': side != PracticeAudioSide.input,
      'outputReleased': side != PracticeAudioSide.output,
      'sessionReleased': !hasLease,
      'nativeOperationInFlight': false,
      'requiresExplicitRetry': !clearNow && !hasLease,
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
    opens.add(side);
    _activeSide = side;
    ++_leaseGeneration;
    ++_revision;
    await (start?.call(side) ?? Future<void>.value());
    return NativeAudioPermit.reserved(
      owner: _binding,
      contextGeneration: _context,
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
    ++_context;
    ++_revision;
    if (_activeSide != null) {
      await (stop?.call() ?? Future<void>.value());
      _activeSide = null;
      ++_revision;
    }
    return _snapshot();
  }
}
