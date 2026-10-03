import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/audio/native_audio_arbiter_channel.dart';
import 'package:ostinato/app/audio/native_audio_state.dart';

const _oldOwner = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _newOwner = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _leaseId = 'cccccccccccccccccccccccccccccccc';
const _channel = MethodChannel('ostinato_test/video_exact_ack_v4');

Map<String, Object?> _binding(String token, int generation, int revision) => {
  'schemaVersion': 1,
  'ownerToken': token,
  'engineGeneration': generation,
  'contextGeneration': generation == 2 ? 3 : 4,
  'stateRevision': revision,
};

Map<String, Object?> _clear(String token, int generation, int revision) => {
  ..._binding(token, generation, revision),
  'activeSide': null,
  'activeLeaseGeneration': null,
  'inputPhase': 'clear',
  'outputPhase': 'clear',
  'videoPhase': 'clear',
  'inputReleased': true,
  'outputReleased': true,
  'videoReleased': true,
  'sessionReleased': true,
  'nativeOperationInFlight': false,
  'requiresExplicitRetry': false,
  'allClear': true,
};

Map<String, Object?> _recorded() => {
  'schemaVersion': 1,
  'ownerToken': _oldOwner,
  'engineGeneration': 2,
  'contextGeneration': 3,
  'leaseId': _leaseId,
  'leaseGeneration': 1,
  'playerId': 7,
  'ackStatus': 'RECORDED',
  'nativeReleaseRecorded': true,
  'leaseSettled': true,
  'snapshot': _clear(_newOwner, 3, 9),
};

Map<String, Object?> _retryClear(int revision) => {
  ..._clear(_newOwner, 3, revision),
  'requiresExplicitRetry': true,
  'allClear': false,
};

Map<String, Object?> _retryHeld(int revision) => {
  ..._retryClear(revision),
  'activeSide': 'video',
  'activeLeaseGeneration': 1,
  'videoPhase': 'unconfirmedQuiescent',
  'videoReleased': false,
  'sessionReleased': false,
};

Map<String, Object?> _unsettledReceipt({required bool released}) => {
  ..._recorded(),
  'nativeReleaseRecorded': released,
  'leaseSettled': false,
  'snapshot': released ? _retryClear(9) : _retryHeld(9),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(_channel, null));

  test('exact old ACK refreshes B and rejects a late A snapshot', () async {
    final pendingA = Completer<Object?>();
    final oldReadStarted = Completer<void>();
    var binds = 0;
    var reads = 0;
    messenger.setMockMethodCallHandler(_channel, (call) async {
      switch (call.method) {
        case 'bind':
          ++binds;
          return binds == 1
              ? _binding(_oldOwner, 2, 4)
              : _binding(_newOwner, 3, 8);
        case 'readAllAudioState':
          ++reads;
          if (reads == 1) return _clear(_oldOwner, 2, 4);
          if (reads == 2) {
            oldReadStarted.complete();
            return pendingA.future;
          }
          return _clear(_newOwner, 3, 9);
        case 'reserve':
          expect(call.arguments, {
            'ownerToken': _oldOwner,
            'engineGeneration': 2,
            'contextGeneration': 3,
            'leaseId': _leaseId,
            'side': 'video',
          });
          return {
            'status': 'reserved',
            'leaseId': _leaseId,
            'leaseGeneration': 1,
            'stateRevision': 5,
          };
        case 'completeRetiredVideoDispose':
          final args = call.arguments as Map<Object?, Object?>;
          expect(args['ownerToken'], _oldOwner);
          expect(args['engineGeneration'], 2);
          expect(args['confirmed'], true);
          return _recorded();
        case 'rebindVideoPermitBridge':
          expect((call.arguments as Map<Object?, Object?>)['leaseId'], _leaseId);
          return {
            'schemaVersion': 1,
            'bridgeReady': true,
            'ack': _recorded(),
          };
      }
      throw StateError('Unexpected ${call.method}');
    });
    final port = NativeAudioArbiterChannel(channel: _channel);
    expect((await port.readAllAudioState()).allClear, isTrue);
    final permit = await port.reserve(PracticeAudioSide.video, _leaseId);
    final oldRead = expectLater(
      port.readAllAudioState(),
      throwsA(isA<NativeAudioProtocolException>()),
    );
    await oldReadStarted.future;
    final receipt = await port.completeRetiredVideoDispose(permit);
    expect(receipt.ackRecorded, isTrue);
    expect(receipt.nativeReleaseRecorded, isTrue);
    final current = await port.refreshOwnerAfterExactVideoDispose(receipt);
    expect(current.ownerToken, _newOwner);
    expect(current.engineGeneration, 3);
    pendingA.complete(_clear(_oldOwner, 2, 6));
    await oldRead;
    expect(port.capturePreflightSnapshot?.ownerToken, _newOwner);
    expect(binds, 2);
    expect(reads, 4);
  });

  test('native release without an ACK cannot refresh the cached owner', () async {
    var reads = 0;
    messenger.setMockMethodCallHandler(_channel, (call) async {
      switch (call.method) {
        case 'bind':
          return _binding(_oldOwner, 2, 4);
        case 'readAllAudioState':
          ++reads;
          return _clear(_oldOwner, 2, 4);
        case 'reserve':
          return {
            'status': 'reserved',
            'leaseId': _leaseId,
            'leaseGeneration': 1,
            'stateRevision': 5,
          };
        case 'readVideoDisposeReceipt':
          return {
            'schemaVersion': 1,
            'ownerToken': _oldOwner,
            'engineGeneration': 2,
            'contextGeneration': 3,
            'leaseId': _leaseId,
            'leaseGeneration': 1,
            'playerId': 7,
            'ackStatus': 'NOT_RECORDED',
            'nativeReleaseRecorded': true,
            'leaseSettled': false,
            'snapshot': _clear(_newOwner, 3, 9),
          };
      }
      throw StateError('Unexpected ${call.method}');
    });
    final port = NativeAudioArbiterChannel(channel: _channel);
    await port.readAllAudioState();
    final permit = await port.reserve(PracticeAudioSide.video, _leaseId);
    final receipt = await port.readVideoDisposeReceipt(permit);
    expect(receipt.ackRecorded, isFalse);
    await expectLater(
      port.refreshOwnerAfterExactVideoDispose(receipt),
      throwsA(isA<NativeAudioProtocolException>()),
    );
    expect(reads, 1);
  });

  test('exact ACK plus release uses current handler revision before readback', () async {
    var binds = 0;
    var recovered = false;
    messenger.setMockMethodCallHandler(_channel, (call) async {
      switch (call.method) {
        case 'bind':
          ++binds;
          return binds == 1
              ? _binding(_oldOwner, 2, 4)
              : _binding(_newOwner, 3, 9);
        case 'readAllAudioState':
          return binds == 1
              ? _clear(_oldOwner, 2, 4)
              : _retryClear(9);
        case 'reserve':
          return {
            'status': 'reserved',
            'leaseId': _leaseId,
            'leaseGeneration': 1,
            'stateRevision': 5,
          };
        case 'readVideoDisposeReceipt':
          return recovered
              ? {..._recorded(), 'snapshot': _clear(_newOwner, 3, 10)}
              : _unsettledReceipt(released: true);
        case 'recoverAll':
          final args = call.arguments as Map<Object?, Object?>;
          expect(args['ownerToken'], _newOwner);
          expect(args['engineGeneration'], 3);
          expect(args['expectedStateRevision'], 9);
          expect(args['reason'], 'userRetry');
          final claim = args['exactVideoClaim'] as Map<Object?, Object?>;
          expect(claim['ownerToken'], _oldOwner);
          expect(claim['engineGeneration'], 2);
          expect(claim['leaseId'], _leaseId);
          recovered = true;
          return {'status': 'closed', 'snapshot': _clear(_newOwner, 3, 10)};
      }
      throw StateError('Unexpected ${call.method}');
    });
    final port = NativeAudioArbiterChannel(
      channel: _channel,
      platform: TargetPlatform.iOS,
    );
    await port.readAllAudioState();
    final permit = await port.reserve(PracticeAudioSide.video, _leaseId);
    final first = await port.readVideoDisposeReceipt(permit);
    expect(first.ackRecorded, isTrue);
    expect(first.nativeReleaseRecorded, isTrue);
    expect(first.leaseSettled, isFalse);
    final current = await port.recoverRetiredVideo(first);
    expect(current.allClear, isTrue);
    final second = await port.readVideoDisposeReceipt(permit);
    expect(second.leaseSettled, isTrue);
    expect(second.snapshot.allClear, isTrue);
    expect(binds, 2);
  });

  test('blocked exact close dispatch is not native release proof', () async {
    var binds = 0;
    var dispatches = 0;
    messenger.setMockMethodCallHandler(_channel, (call) async {
      switch (call.method) {
        case 'bind':
          ++binds;
          return binds == 1
              ? _binding(_oldOwner, 2, 4)
              : _binding(_newOwner, 3, 9);
        case 'readAllAudioState':
          return binds == 1
              ? _clear(_oldOwner, 2, 4)
              : _retryHeld(9);
        case 'reserve':
          return {
            'status': 'reserved',
            'leaseId': _leaseId,
            'leaseGeneration': 1,
            'stateRevision': 5,
          };
        case 'readVideoDisposeReceipt':
          return _unsettledReceipt(released: false);
        case 'recoverAll':
          final args = call.arguments as Map<Object?, Object?>;
          expect(args['expectedStateRevision'], 9);
          expect(args['ownerToken'], _newOwner);
          expect((args['exactVideoClaim'] as Map<Object?, Object?>)['leaseId'],
              _leaseId);
          ++dispatches;
          return {
            'status': 'blocked',
            'snapshot': {
              ..._retryHeld(10),
              'videoPhase': 'closing',
              'nativeOperationInFlight': true,
            },
          };
      }
      throw StateError('Unexpected ${call.method}');
    });
    final port = NativeAudioArbiterChannel(
      channel: _channel,
      platform: TargetPlatform.iOS,
    );
    await port.readAllAudioState();
    final permit = await port.reserve(PracticeAudioSide.video, _leaseId);
    final first = await port.readVideoDisposeReceipt(permit);
    final requested = await port.recoverRetiredVideo(first);
    expect(requested.allClear, isFalse);
    expect(dispatches, 1);
    final stillHeld = await port.readVideoDisposeReceipt(permit);
    expect(stillHeld.nativeReleaseRecorded, isFalse);
    expect(stillHeld.leaseSettled, isFalse);
  });

  test('changed current handler denies exact recovery before CAS', () async {
    var binds = 0;
    var recoverCalls = 0;
    messenger.setMockMethodCallHandler(_channel, (call) async {
      switch (call.method) {
        case 'bind':
          ++binds;
          return binds == 1
              ? _binding(_oldOwner, 2, 4)
              : _binding('dddddddddddddddddddddddddddddddd', 3, 9);
        case 'readAllAudioState':
          return _clear(_oldOwner, 2, 4);
        case 'reserve':
          return {
            'status': 'reserved',
            'leaseId': _leaseId,
            'leaseGeneration': 1,
            'stateRevision': 5,
          };
        case 'readVideoDisposeReceipt':
          return _unsettledReceipt(released: true);
        case 'recoverAll':
          ++recoverCalls;
          throw StateError('foreign recoverAll must not run');
      }
      throw StateError('Unexpected ${call.method}');
    });
    final port = NativeAudioArbiterChannel(
      channel: _channel,
      platform: TargetPlatform.iOS,
    );
    await port.readAllAudioState();
    final permit = await port.reserve(PracticeAudioSide.video, _leaseId);
    final exact = await port.readVideoDisposeReceipt(permit);
    await expectLater(
      port.recoverRetiredVideo(exact),
      throwsA(isA<NativeAudioProtocolException>()),
    );
    expect(recoverCalls, 0);
  });

  test('Android V8 pending retry keeps strict recoverAll wire shape', () async {
    var binds = 0;
    messenger.setMockMethodCallHandler(_channel, (call) async {
      switch (call.method) {
        case 'bind':
          ++binds;
          return binds == 1
              ? _binding(_oldOwner, 2, 4)
              : _binding(_newOwner, 3, 9);
        case 'readAllAudioState':
          return binds == 1
              ? _clear(_oldOwner, 2, 4)
              : _retryHeld(9);
        case 'reserve':
          return {
            'status': 'reserved',
            'leaseId': _leaseId,
            'leaseGeneration': 1,
            'stateRevision': 5,
          };
        case 'readVideoDisposeReceipt':
          return _unsettledReceipt(released: false);
        case 'recoverAll':
          final args = call.arguments as Map<Object?, Object?>;
          expect(args.keys, containsAll(['ownerToken', 'engineGeneration',
            'expectedStateRevision', 'reason']));
          expect(args.containsKey('exactVideoClaim'), isFalse);
          expect(args['expectedStateRevision'], 9);
          return {
            'status': 'pending',
            'snapshot': {
              ..._retryHeld(10),
              'videoPhase': 'closing',
              'nativeOperationInFlight': true,
              'requiresExplicitRetry': false,
            },
          };
      }
      throw StateError('Unexpected ${call.method}');
    });
    final port = NativeAudioArbiterChannel(
      channel: _channel,
      platform: TargetPlatform.android,
    );
    await port.readAllAudioState();
    final permit = await port.reserve(PracticeAudioSide.video, _leaseId);
    final exact = await port.readVideoDisposeReceipt(permit);
    final pending = await port.recoverRetiredVideo(exact);
    expect(pending.allClear, isFalse);
    final stillHeld = await port.readVideoDisposeReceipt(permit);
    expect(stillHeld.nativeReleaseRecorded, isFalse);
  });

  test('recorded release may settle a held exact video retry latch', () async {
    var binds = 0;
    var recoverCalls = 0;
    messenger.setMockMethodCallHandler(_channel, (call) async {
      switch (call.method) {
        case 'bind':
          ++binds;
          return binds == 1
              ? _binding(_oldOwner, 2, 4)
              : _binding(_newOwner, 3, 9);
        case 'readAllAudioState':
          return binds == 1
              ? _clear(_oldOwner, 2, 4)
              : _retryHeld(9);
        case 'reserve':
          return {
            'status': 'reserved',
            'leaseId': _leaseId,
            'leaseGeneration': 1,
            'stateRevision': 5,
          };
        case 'readVideoDisposeReceipt':
          return {
            ..._unsettledReceipt(released: true),
            'snapshot': _retryHeld(9),
          };
        case 'recoverAll':
          ++recoverCalls;
          expect((call.arguments as Map<Object?, Object?>)['expectedStateRevision'], 9);
          return {'status': 'closed', 'snapshot': _clear(_newOwner, 3, 10)};
      }
      throw StateError('Unexpected ${call.method}');
    });
    final port = NativeAudioArbiterChannel(
      channel: _channel,
      platform: TargetPlatform.iOS,
    );
    await port.readAllAudioState();
    final permit = await port.reserve(PracticeAudioSide.video, _leaseId);
    final exact = await port.readVideoDisposeReceipt(permit);
    expect(exact.nativeReleaseRecorded, isTrue);
    expect(exact.leaseSettled, isFalse);
    final settled = await port.recoverRetiredVideo(exact);
    expect(settled.allClear, isTrue);
    expect(recoverCalls, 1);
  });
}
