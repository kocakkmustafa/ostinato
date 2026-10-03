import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/audio/native_audio_state.dart'
    show NativeAudioBinding;
import 'package:ostinato/app/audio/practice_audio_lease.dart';
import 'package:ostinato/app/audio/practice_video_session_owner.dart';

const _a = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _b = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

final class _Player implements PracticeVideoPlayerPort {
  int disposals = 0;

  @override
  Future<void> initialize(NativeAudioPermit permit) async {}

  @override
  Future<void> dispose() async {
    ++disposals;
  }
}

final class _Port implements PracticeAudioLeasePort, PracticeVideoExactAckPort {
  _Port({
    this.firstAckCommitted = false,
    this.retiredReplyLost = false,
    this.nativeReleaseOnActivity = true,
    this.closeRetrySucceedsAfter = 1,
    this.delayedReleaseOnRetry = false,
    this.foreignRecoveryHandler = false,
  });

  final bool firstAckCommitted;
  final bool retiredReplyLost;
  final bool nativeReleaseOnActivity;
  final int closeRetrySucceedsAfter;
  final bool delayedReleaseOnRetry;
  bool foreignRecoveryHandler;
  int exactWrites = 0;
  int exactReads = 0;
  int recoveries = 0;
  int closeRetries = 0;
  int refreshes = 0;
  int ordinaryAcks = 0;
  bool _held = false;
  bool _nativeReleased = false;
  bool _ack = false;
  bool _replyLostOnce = false;
  bool _activityB = false;
  bool _retryLatch = false;
  bool _closePending = false;
  int _revision = 10;
  NativeAudioPermit? _permit;

  Map<String, Object?> _stateWire({required bool clear}) => {
    'schemaVersion': 1,
    'ownerToken': _activityB ? _b : _a,
    'engineGeneration': _activityB ? 2 : 1,
    'contextGeneration': _activityB ? 2 : 1,
    'stateRevision': _activityB
        ? _revision
        : clear
        ? 1
        : 2,
    'activeSide': clear ? null : 'video',
    'activeLeaseGeneration': clear ? null : 1,
    'inputPhase': 'clear',
    'outputPhase': 'clear',
    'videoPhase': clear
        ? 'clear'
        : _closePending
        ? 'closing'
        : _activityB
        ? 'unconfirmedQuiescent'
        : 'reserved',
    'inputReleased': true,
    'outputReleased': true,
    'videoReleased': clear,
    'sessionReleased': clear,
    'nativeOperationInFlight': _closePending,
    'requiresExplicitRetry': _retryLatch,
    'allClear': clear && !_retryLatch,
  };

  NativeAllAudioState _state({required bool clear}) =>
      NativeAllAudioState.fromWire(_stateWire(clear: clear));

  void releaseAndRebindActivity() {
    _nativeReleased = nativeReleaseOnActivity;
    if (_ack && _nativeReleased) _held = false;
    _activityB = true;
    _retryLatch = true;
  }

  NativeVideoDisposeReceipt _receipt(NativeAudioPermit permit) =>
      NativeVideoDisposeReceipt.fromWire({
        'schemaVersion': 1,
        'ownerToken': permit.ownerToken,
        'engineGeneration': permit.engineGeneration,
        'contextGeneration': permit.contextGeneration,
        'leaseId': permit.leaseId,
        'leaseGeneration': permit.leaseGeneration,
        'playerId': 7,
        'ackStatus': _ack ? 'RECORDED' : 'NOT_RECORDED',
        'nativeReleaseRecorded': _nativeReleased,
        'leaseSettled': !_held && _ack && _nativeReleased && !_retryLatch,
        'snapshot': _stateWire(clear: !_held),
      }, permit);

  @override
  Future<NativeAllAudioState> readAllAudioState() async =>
      _state(clear: !_held);

  @override
  Future<NativeAudioPermit> reserve(PracticeAudioSide side, String id) async {
    expect(side, PracticeAudioSide.video);
    _held = true;
    final binding = NativeAudioBinding.fromWire({
      'schemaVersion': 1,
      'ownerToken': _a,
      'engineGeneration': 1,
      'contextGeneration': 1,
      'stateRevision': 1,
    });
    return _permit = NativeAudioPermit.reserved(
      owner: binding,
      contextGeneration: 1,
      leaseId: id,
      side: side,
      wire: {
        'status': 'reserved',
        'leaseId': id,
        'leaseGeneration': 1,
        'stateRevision': 2,
      },
    );
  }

  @override
  Future<NativeAllAudioState> completeVideoDispose(
    NativeAudioPermit permit, {
    required bool confirmed,
  }) async {
    ++ordinaryAcks;
    expect(permit, same(_permit));
    expect(confirmed, isTrue);
    if (firstAckCommitted) _ack = true;
    throw StateError('first ACK transport response lost');
  }

  @override
  Future<NativeVideoDisposeReceipt> completeRetiredVideoDispose(
    NativeAudioPermit permit,
  ) async {
    ++exactWrites;
    expect(permit, same(_permit));
    _ack = true;
    if (_nativeReleased) _held = false;
    if (retiredReplyLost && !_replyLostOnce) {
      _replyLostOnce = true;
      throw StateError('retired ACK response lost');
    }
    return _receipt(permit);
  }

  @override
  Future<NativeVideoDisposeReceipt> readVideoDisposeReceipt(
    NativeAudioPermit permit,
  ) async {
    ++exactReads;
    return _receipt(permit);
  }

  @override
  Future<NativeAllAudioState> recoverRetiredVideo(
    NativeVideoDisposeReceipt receipt,
  ) async {
    expect(receipt.permit, same(_permit));
    expect(receipt.ackRecorded, isTrue);
    expect(receipt.leaseSettled, isFalse);
    if (!_activityB || foreignRecoveryHandler) {
      throw StateError('foreign current handler');
    }
    ++recoveries;
    if (!_nativeReleased) {
      expect(receipt.snapshot.activeLeaseGeneration, _permit!.leaseGeneration);
      expect(receipt.snapshot.requiresExplicitRetry, isTrue);
      ++closeRetries;
      if (closeRetries >= closeRetrySucceedsAfter) {
        if (delayedReleaseOnRetry) {
          _closePending = true;
          ++_revision;
          Future<void>.delayed(const Duration(milliseconds: 30), () {
            _nativeReleased = true;
            if (_ack) _held = false;
            _closePending = false;
            ++_revision;
          });
        } else {
          _nativeReleased = true;
          if (_ack) _held = false;
          ++_revision;
        }
      }
    } else {
      expect(_ack, isTrue);
      expect(_held, isFalse);
      _retryLatch = false;
      ++_revision;
    }
    return _state(clear: !_held);
  }

  @override
  Future<NativeAllAudioState> refreshOwnerAfterExactVideoDispose(
    NativeVideoDisposeReceipt receipt,
  ) async {
    ++refreshes;
    expect(receipt.ackRecorded, isTrue);
    expect(receipt.nativeReleaseRecorded, isTrue);
    expect(receipt.leaseSettled, isTrue);
    return _state(clear: true);
  }

  @override
  Future<NativeAllAudioState> cancelVideoReservation(NativeAudioPermit _) =>
      throw UnimplementedError();
  @override
  Future<NativeAllAudioState> cancelUnclaimedVideoReservation({
    required String attemptOwnerToken,
    required int attemptEngineGeneration,
    required int attemptContextGeneration,
    required String leaseId,
    required int? leaseGeneration,
    required int expectedStateRevision,
  }) => throw UnimplementedError();
  @override
  Future<NativeAudioPermit> startOutput(NativeAudioPermit _, String _) =>
      throw UnimplementedError();
  @override
  Future<NativeAllAudioState> closeAll(
    NativeAudioPermit _,
    NativeAudioCloseReason _,
  ) => throw UnimplementedError();
  @override
  Future<NativeAllAudioState> recoverAll(int _) => throw UnimplementedError();
  @override
  Future<NativeAllAudioState> fenceContext(NativeAudioContextReason _) =>
      throw UnimplementedError();
}

void main() {
  for (final replyLost in [false, true]) {
    test(
      'retired ACK replays exact Dart success; replyLost=$replyLost',
      () async {
        final port = _Port(
          firstAckCommitted: replyLost,
          retiredReplyLost: replyLost,
        );
        final owner = PracticeVideoSessionOwner(port: port);
        final player = _Player();
        expect(
          await owner.open(player, isCurrent: () => true),
          PracticeVideoOpenStatus.ready,
        );
        expect(await owner.close(), isFalse);
        expect(owner.blocked, isTrue);
        expect(owner.canRefreshQuiescentOwner, isFalse);
        expect(player.disposals, 1);
        port.releaseAndRebindActivity();
        expect(
          await owner.recover(),
          PracticeVideoRecoveryStatus.confirmedClosed,
        );
        expect(owner.blocked, isFalse);
        expect(owner.canRefreshQuiescentOwner, isTrue);
        expect(port.ordinaryAcks, 1);
        expect(port.exactWrites, 1);
        expect(port.exactReads, replyLost ? 2 : 1);
        expect(port.recoveries, 1);
        expect(port.closeRetries, 0);
        expect(port.refreshes, 1);
      },
    );
  }

  test('exact dispose proof retries native close, then settles exact ACK', () async {
    final port = _Port(
      nativeReleaseOnActivity: false,
      closeRetrySucceedsAfter: 2,
    );
    final owner = PracticeVideoSessionOwner(port: port);
    final player = _Player();
    expect(
      await owner.open(player, isCurrent: () => true),
      PracticeVideoOpenStatus.ready,
    );
    expect(await owner.close(), isFalse);
    port.releaseAndRebindActivity();
    expect(
      await owner.recover(),
      PracticeVideoRecoveryStatus.blockedUnconfirmed,
    );
    expect(port.closeRetries, 1);
    expect(port.recoveries, 1);
    expect(port.refreshes, 0);
    expect(owner.blocked, isTrue);
    expect(
      await owner.recover(),
      PracticeVideoRecoveryStatus.confirmedClosed,
    );
    expect(port.closeRetries, 2);
    expect(port.recoveries, 3); // close retry twice, then latch settlement
    expect(port.refreshes, 1);
    expect(player.disposals, 1);
  });

  test('foreign handler cannot use exact Dart proof for retry', () async {
    final port = _Port(
      nativeReleaseOnActivity: false,
      foreignRecoveryHandler: true,
    );
    final owner = PracticeVideoSessionOwner(port: port);
    addTearDown(() async {
      // Keep the production isolate-owner fence intact. Restore this fake
      // handler, then settle the exact held claim before the next test.
      port.foreignRecoveryHandler = false;
      expect(
        await owner.recover(),
        PracticeVideoRecoveryStatus.confirmedClosed,
      );
      expect(owner.canRefreshQuiescentOwner, isTrue);
    });
    final player = _Player();
    expect(
      await owner.open(player, isCurrent: () => true),
      PracticeVideoOpenStatus.ready,
    );
    expect(await owner.close(), isFalse);
    port.releaseAndRebindActivity();
    expect(
      await owner.recover(),
      PracticeVideoRecoveryStatus.blockedUnconfirmed,
    );
    expect(port.closeRetries, 0);
    expect(port.refreshes, 0);
    expect(owner.blocked, isTrue);
  });

  test('pending close readback can retain global retry latch', () async {
    final port = _Port(
      nativeReleaseOnActivity: false,
      delayedReleaseOnRetry: true,
    );
    final owner = PracticeVideoSessionOwner(port: port);
    final player = _Player();
    expect(
      await owner.open(player, isCurrent: () => true),
      PracticeVideoOpenStatus.ready,
    );
    expect(await owner.close(), isFalse);
    port.releaseAndRebindActivity();
    expect(
      await owner.recover(),
      PracticeVideoRecoveryStatus.confirmedClosed,
    );
    expect(port.closeRetries, 1);
    expect(port.recoveries, 2);
    expect(port.refreshes, 1);
    expect(player.disposals, 1);
  });
}
