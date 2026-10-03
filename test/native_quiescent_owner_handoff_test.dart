import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motion_account/motion_account.dart';
import 'package:ostinato/app/audio/native_audio_arbiter_channel.dart';
import 'package:ostinato/app/audio/native_audio_state.dart';
import 'package:ostinato/app/audio/practice_audio_lease.dart';
import 'package:ostinato/app/audio/practice_audio_root.dart';

const _a = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _b = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _foreign = 'ffffffffffffffffffffffffffffffff';
const _channel = MethodChannel('ostinato_test/quiescent_owner_v5');

Map<String, Object?> _binding(String owner, int generation, int revision) => {
  'schemaVersion': 1,
  'ownerToken': owner,
  'engineGeneration': generation,
  'contextGeneration': generation == 2 ? 3 : 4,
  'stateRevision': revision,
};

Map<String, Object?> _clear(String owner, int generation, int revision) => {
  ..._binding(owner, generation, revision),
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

Map<String, Object?> _held() => {
  ..._binding(_a, 2, 5),
  'activeSide': 'video',
  'activeLeaseGeneration': 1,
  'inputPhase': 'clear',
  'outputPhase': 'clear',
  'videoPhase': 'reserved',
  'inputReleased': true,
  'outputReleased': true,
  'videoReleased': false,
  'sessionReleased': false,
  'nativeOperationInFlight': false,
  'requiresExplicitRetry': false,
  'allClear': false,
};

Map<String, Object?> _handoff({
  String retired = _a,
  Map<String, Object?>? snapshot,
  bool bridgeReady = true,
}) => {
  'schemaVersion': 1,
  'bridgeReady': bridgeReady,
  'handoff': {
    'schemaVersion': 1,
    'retiredOwnerToken': retired,
    'retiredEngineGeneration': 2,
    'retiredContextGeneration': 3,
    'retiredStateRevision': 4,
    'snapshot': snapshot ?? _clear(_b, 3, 9),
  },
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(_channel, null));

  test('explicit A to B handoff rejects late A read after two B reads', () async {
    final pendingA = Completer<Object?>();
    final oldReadStarted = Completer<void>();
    var binds = 0;
    var reads = 0;
    var handoffs = 0;
    messenger.setMockMethodCallHandler(_channel, (call) async {
      switch (call.method) {
        case 'bind':
          return ++binds == 1 ? _binding(_a, 2, 4) : _binding(_b, 3, 9);
        case 'readAllAudioState':
          ++reads;
          if (reads == 1) return _clear(_a, 2, 4);
          if (reads == 2) {
            oldReadStarted.complete();
            return pendingA.future;
          }
          if (reads == 3) {
            throw PlatformException(code: 'stale_audio_owner');
          }
          return _clear(_b, 3, 9);
        case 'rebindQuiescentOwner':
          ++handoffs;
          expect(call.arguments, {
            'retiredOwnerToken': _a,
            'retiredEngineGeneration': 2,
            'reason': 'userRetry',
          });
          return _handoff();
      }
      throw StateError('Unexpected ${call.method}');
    });
    final port = NativeAudioArbiterChannel(channel: _channel);
    expect((await port.readAllAudioState()).ownerToken, _a);
    final lateA = expectLater(
      port.readAllAudioState(),
      throwsA(isA<NativeAudioProtocolException>()),
    );
    await oldReadStarted.future;
    await expectLater(port.readAllAudioState(), throwsA(isA<PlatformException>()));
    expect(port.needsQuiescentOwnerRefresh, isTrue);
    expect(port.capturePreflightSnapshot, isNull);
    final current = await port.refreshQuiescentOwner();
    expect(current.ownerToken, _b);
    expect(current.engineGeneration, 3);
    expect(port.capturePreflightSnapshot?.ownerToken, _b);
    pendingA.complete(_clear(_a, 2, 6));
    await lateA;
    expect(port.capturePreflightSnapshot?.ownerToken, _b);
    expect(port.needsQuiescentOwnerRefresh, isFalse);
    expect(binds, 2);
    expect(reads, 5);
    expect(handoffs, 1);
  });

  test('bind-only A can recover after its first read reaches B', () async {
    var binds = 0;
    var reads = 0;
    messenger.setMockMethodCallHandler(_channel, (call) async {
      switch (call.method) {
        case 'bind':
          return ++binds == 1 ? _binding(_a, 2, 4) : _binding(_b, 3, 9);
        case 'readAllAudioState':
          if (++reads == 1) {
            throw PlatformException(code: 'stale_audio_owner');
          }
          return _clear(_b, 3, 9);
        case 'rebindQuiescentOwner':
          expect((call.arguments as Map<Object?, Object?>)['retiredOwnerToken'], _a);
          return _handoff();
      }
      throw StateError('Unexpected ${call.method}');
    });
    final port = NativeAudioArbiterChannel(channel: _channel);
    await expectLater(port.readAllAudioState(), throwsA(isA<PlatformException>()));
    expect(port.needsQuiescentOwnerRefresh, isTrue);
    final current = await port.refreshQuiescentOwner();
    expect(current.ownerToken, _b);
    expect(binds, 2);
    expect(reads, 3);
  });

  test('foreign, held and missing bridge evidence never replace A cache', () async {
    for (final bad in <Map<String, Object?>>[
      _handoff(retired: _foreign),
      _handoff(snapshot: _held()),
      _handoff(snapshot: _clear(_b, 3, 3)),
      _handoff(snapshot: {..._clear(_b, 3, 9), 'contextGeneration': 3}),
      _handoff(bridgeReady: false),
    ]) {
      var binds = 0;
      var reads = 0;
      messenger.setMockMethodCallHandler(_channel, (call) async {
        switch (call.method) {
          case 'bind':
            ++binds;
            return _binding(_a, 2, 4);
          case 'readAllAudioState':
            return ++reads == 1
                ? _clear(_a, 2, 4)
                : throw PlatformException(code: 'stale_audio_owner');
          case 'rebindQuiescentOwner':
            return bad;
        }
        throw StateError('Unexpected ${call.method}');
      });
      final port = NativeAudioArbiterChannel(channel: _channel);
      await port.readAllAudioState();
      await expectLater(port.readAllAudioState(), throwsA(isA<PlatformException>()));
      await expectLater(
        port.refreshQuiescentOwner(),
        throwsA(isA<NativeAudioProtocolException>()),
      );
      expect(port.needsQuiescentOwnerRefresh, isTrue);
      expect(port.capturePreflightSnapshot, isNull);
      expect(binds, 1);
    }

    var handoffs = 0;
    var reads = 0;
    messenger.setMockMethodCallHandler(_channel, (call) async {
      switch (call.method) {
        case 'bind':
          return _binding(_a, 2, 4);
        case 'readAllAudioState':
          return ++reads == 1
              ? _held()
              : throw PlatformException(code: 'stale_audio_owner');
        case 'rebindQuiescentOwner':
          ++handoffs;
          return _handoff();
      }
      throw StateError('Unexpected ${call.method}');
    });
    final heldPort = NativeAudioArbiterChannel(channel: _channel);
    expect((await heldPort.readAllAudioState()).allClear, isFalse);
    await expectLater(heldPort.readAllAudioState(), throwsA(isA<PlatformException>()));
    await expectLater(
      heldPort.refreshQuiescentOwner(),
      throwsA(isA<NativeAudioProtocolException>()),
    );
    expect(handoffs, 0);
  });

  test('lost handoff reply stays closed and explicit retry uses old A', () async {
    var binds = 0;
    var reads = 0;
    var handoffs = 0;
    messenger.setMockMethodCallHandler(_channel, (call) async {
      switch (call.method) {
        case 'bind':
          return ++binds == 1 ? _binding(_a, 2, 4) : _binding(_b, 3, 9);
        case 'readAllAudioState':
          return ++reads == 1
              ? _clear(_a, 2, 4)
              : reads == 2
              ? throw PlatformException(code: 'stale_audio_owner')
              : _clear(_b, 3, 9);
        case 'rebindQuiescentOwner':
          ++handoffs;
          expect((call.arguments as Map<Object?, Object?>)['retiredOwnerToken'], _a);
          if (handoffs == 1) {
            throw PlatformException(code: 'reply_lost');
          }
          return _handoff();
      }
      throw StateError('Unexpected ${call.method}');
    });
    final port = NativeAudioArbiterChannel(channel: _channel);
    await port.readAllAudioState();
    await expectLater(port.readAllAudioState(), throwsA(isA<PlatformException>()));
    await expectLater(
      port.refreshQuiescentOwner(),
      throwsA(isA<PlatformException>()),
    );
    expect(port.capturePreflightSnapshot, isNull);
    expect(port.needsQuiescentOwnerRefresh, isTrue);
    expect((await port.refreshQuiescentOwner()).ownerToken, _b);
    expect(handoffs, 2);
    expect(binds, 2);
  });

  test('root explicit recovery uses claim-free handoff without a Dart ACK', () async {
    var binds = 0;
    var reads = 0;
    messenger.setMockMethodCallHandler(_channel, (call) async {
      switch (call.method) {
        case 'bind':
          return ++binds == 1 ? _binding(_a, 2, 4) : _binding(_b, 3, 9);
        case 'readAllAudioState':
          return ++reads == 1
              ? _clear(_a, 2, 4)
              : reads == 2
              ? throw PlatformException(code: 'stale_audio_owner')
              : _clear(_b, 3, 9);
        case 'rebindQuiescentOwner':
          return _handoff();
      }
      throw StateError('Unexpected ${call.method}');
    });
    final user = ValueNotifier<String?>('A');
    final identity = ValueNotifier(MotionIdentityPhase.verified);
    final port = NativeAudioArbiterChannel(channel: _channel);
    final root = PracticeAudioRootOwner(
      userId: user,
      phase: identity,
      lease: PracticeAudioLease(port: port),
      captureArbiter: port,
      initialLifecycleState: AppLifecycleState.resumed,
    );
    expect((await port.readAllAudioState()).ownerToken, _a);
    expect(await root.recover(), PracticeAudioReleaseStatus.confirmedClosed);
    expect(port.capturePreflightSnapshot?.ownerToken, _b);
    expect(binds, 2);
    expect(reads, 4);
    root.dispose();
    await root.lastFenceForTest;
    user.dispose();
    identity.dispose();
  });
}
