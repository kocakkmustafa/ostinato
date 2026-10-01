import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/audio/native_audio_arbiter_channel.dart';
import 'package:ostinato/app/audio/native_audio_state.dart';

const _owner = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _foreign = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _leaseId = 'cccccccccccccccccccccccccccccccc';
const _method = MethodChannel('ostinato_test/practice_audio_v1');

Map<String, Object?> _binding({String owner = _owner}) => {
  'schemaVersion': 1,
  'ownerToken': owner,
  'engineGeneration': 2,
  'contextGeneration': 3,
  'stateRevision': 4,
};

Map<String, Object?> _snapshot({
  String owner = _owner,
  int engine = 2,
  int revision = 4,
  PracticeAudioSide? side,
  bool sticky = false,
}) {
  final clear = side == null && !sticky;
  return {
    'schemaVersion': 1,
    'ownerToken': owner,
    'engineGeneration': engine,
    'contextGeneration': 3,
    'stateRevision': revision,
    'activeSide': side?.name,
    'activeLeaseGeneration': side == null ? null : 1,
    'inputPhase': side == PracticeAudioSide.input
        ? 'reserved'
        : sticky
        ? 'releasedAwaitingExplicitRetry'
        : 'clear',
    'outputPhase': side == PracticeAudioSide.output
        ? 'playing'
        : sticky
        ? 'releasedAwaitingExplicitRetry'
        : 'clear',
    'videoPhase': side == PracticeAudioSide.video ? 'reserved' : 'clear',
    'inputReleased': side != PracticeAudioSide.input,
    'outputReleased': side != PracticeAudioSide.output,
    'videoReleased': side != PracticeAudioSide.video,
    'sessionReleased': side == null,
    'nativeOperationInFlight': false,
    'requiresExplicitRetry': sticky,
    'allClear': clear,
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(_method, null));

  test(
    'codec sends exact owner, context, lease and fenced close fields',
    () async {
      final calls = <String>[];
      messenger.setMockMethodCallHandler(_method, (call) async {
        calls.add(call.method);
        final args = call.arguments as Map<Object?, Object?>;
        switch (call.method) {
          case 'bind':
            expect(args, {'schemaVersion': 1});
            return _binding();
          case 'readAllAudioState':
            expect(args, {'ownerToken': _owner, 'engineGeneration': 2});
            return _snapshot(revision: calls.length == 2 ? 4 : 7);
          case 'reserve':
            expect(args['contextGeneration'], 3);
            expect(args['leaseId'], _leaseId);
            expect(args['side'], 'output');
            return {
              'status': 'reserved',
              'leaseId': _leaseId,
              'leaseGeneration': 1,
              'stateRevision': 5,
            };
          case 'startOutput':
            expect(args['assetId'], 'demo-01');
            expect(args['leaseGeneration'], 1);
            return {
              'status': 'playing',
              'leaseId': _leaseId,
              'leaseGeneration': 1,
              'stateRevision': 6,
            };
          case 'closeAll':
            expect(args['reason'], 'userStop');
            expect(args['leaseId'], _leaseId);
            return {'status': 'closed', 'snapshot': _snapshot(revision: 7)};
        }
        throw StateError('Unexpected ${call.method}');
      });
      final port = NativeAudioArbiterChannel(
        channel: _method,
        allowedAssetIds: const {'demo-01'},
      );
      expect((await port.readAllAudioState()).allClear, isTrue);
      expect(port.capturePreflightSnapshot?.contextGeneration, 3);
      final reserved = await port.reserve(PracticeAudioSide.output, _leaseId);
      expect(port.capturePreflightSnapshot, isNull);
      final playing = await port.startOutput(reserved, 'demo-01');
      expect(playing.stateRevision, 6);
      expect(
        (await port.closeAll(
          playing,
          NativeAudioCloseReason.userStop,
        )).allClear,
        isTrue,
      );
      expect((await port.readAllAudioState()).stateRevision, 7);
      expect(port.capturePreflightSnapshot?.stateRevision, 7);
      expect(calls, [
        'bind',
        'readAllAudioState',
        'reserve',
        'startOutput',
        'closeAll',
        'readAllAudioState',
      ]);
    },
  );

  test('malformed or contradictory snapshot is never an all-clear', () async {
    for (final corrupt in <Map<String, Object?>>[
      _snapshot()..remove('sessionReleased'),
      _snapshot()..['outputReleased'] = false,
      _snapshot()..['inputPhase'] = 'unknown',
      _snapshot()..['schemaVersion'] = 2,
    ]) {
      var reserves = 0;
      messenger.setMockMethodCallHandler(_method, (call) async {
        if (call.method == 'bind') return _binding();
        if (call.method == 'readAllAudioState') return corrupt;
        if (call.method == 'reserve') ++reserves;
        throw StateError('Unexpected ${call.method}');
      });
      final port = NativeAudioArbiterChannel(channel: _method);
      await expectLater(
        port.readAllAudioState(),
        throwsA(isA<NativeAudioProtocolException>()),
      );
      expect(reserves, 0);
    }
  });

  test('foreign owner and engine generation snapshots are rejected', () async {
    for (final wrong in [_snapshot(owner: _foreign), _snapshot(engine: 1)]) {
      messenger.setMockMethodCallHandler(
        _method,
        (call) async => call.method == 'bind' ? _binding() : wrong,
      );
      final port = NativeAudioArbiterChannel(channel: _method);
      await expectLater(
        port.readAllAudioState(),
        throwsA(isA<NativeAudioProtocolException>()),
      );
    }
  });

  test(
    'old revision and changed-revision retry fail before native retry',
    () async {
      var reads = 0;
      var retries = 0;
      messenger.setMockMethodCallHandler(_method, (call) async {
        if (call.method == 'bind') return _binding();
        if (call.method == 'readAllAudioState') {
          return _snapshot(revision: ++reads == 1 ? 6 : 5, sticky: true);
        }
        if (call.method == 'recoverAll') ++retries;
        throw StateError('Unexpected ${call.method}');
      });
      final port = NativeAudioArbiterChannel(channel: _method);
      expect((await port.readAllAudioState()).stateRevision, 6);
      await expectLater(
        port.recoverAll(5),
        throwsA(isA<NativeAudioProtocolException>()),
      );
      await expectLater(
        port.readAllAudioState(),
        throwsA(isA<NativeAudioProtocolException>()),
      );
      expect(retries, 0);
    },
  );

  test('output ID outside explicit allowlist never reaches native', () async {
    var starts = 0;
    messenger.setMockMethodCallHandler(_method, (call) async {
      if (call.method == 'bind') return _binding();
      if (call.method == 'readAllAudioState') return _snapshot();
      if (call.method == 'reserve') {
        return {
          'status': 'reserved',
          'leaseId': _leaseId,
          'leaseGeneration': 1,
          'stateRevision': 5,
        };
      }
      if (call.method == 'startOutput') ++starts;
      throw StateError('Unexpected ${call.method}');
    });
    final port = NativeAudioArbiterChannel(channel: _method);
    await port.readAllAudioState();
    final permit = await port.reserve(PracticeAudioSide.output, _leaseId);
    await expectLater(
      port.startOutput(permit, 'unapproved'),
      throwsA(isA<NativeAudioProtocolException>()),
    );
    expect(starts, 0);
  });

  test(
    'video reserve is held until matching dispose acknowledgement',
    () async {
      final calls = <String>[];
      messenger.setMockMethodCallHandler(_method, (call) async {
        calls.add(call.method);
        if (call.method == 'bind') return _binding();
        if (call.method == 'readAllAudioState') return _snapshot();
        if (call.method == 'reserve') {
          expect((call.arguments as Map<Object?, Object?>)['side'], 'video');
          return {
            'status': 'reserved',
            'leaseId': _leaseId,
            'leaseGeneration': 1,
            'stateRevision': 5,
          };
        }
        if (call.method == 'completeVideoDispose') {
          final args = call.arguments as Map<Object?, Object?>;
          expect(args['contextGeneration'], 3);
          expect(args['leaseGeneration'], 1);
          expect(args['confirmed'], isTrue);
          return {'status': 'closed', 'snapshot': _snapshot(revision: 6)};
        }
        throw StateError('Unexpected ${call.method}');
      });
      final port = NativeAudioArbiterChannel(channel: _method);
      await port.readAllAudioState();
      final permit = await port.reserve(PracticeAudioSide.video, _leaseId);
      expect(port.capturePreflightSnapshot, isNull);
      expect(
        (await port.completeVideoDispose(permit, confirmed: true)).allClear,
        isTrue,
      );
      expect(calls, [
        'bind',
        'readAllAudioState',
        'reserve',
        'completeVideoDispose',
      ]);
    },
  );

  test('video snapshot without disposal state is rejected', () {
    final malformed = _snapshot(side: PracticeAudioSide.video)
      ..remove('videoPhase');
    expect(
      () => NativeAllAudioState.fromWire(malformed),
      throwsA(isA<NativeAudioProtocolException>()),
    );
  });

  test(
    'pre-create video cancellation sends the exact reserved identity',
    () async {
      final calls = <String>[];
      messenger.setMockMethodCallHandler(_method, (call) async {
        calls.add(call.method);
        if (call.method == 'bind') return _binding();
        if (call.method == 'readAllAudioState') return _snapshot();
        if (call.method == 'reserve') {
          return {
            'status': 'reserved',
            'leaseId': _leaseId,
            'leaseGeneration': 1,
            'stateRevision': 5,
          };
        }
        if (call.method == 'cancelVideoReservation') {
          expect(call.arguments, {
            'ownerToken': _owner,
            'engineGeneration': 2,
            'contextGeneration': 3,
            'leaseId': _leaseId,
            'leaseGeneration': 1,
          });
          return {'status': 'closed', 'snapshot': _snapshot(revision: 6)};
        }
        throw StateError('Unexpected ${call.method}');
      });
      final port = NativeAudioArbiterChannel(channel: _method);
      await port.readAllAudioState();
      final permit = await port.reserve(PracticeAudioSide.video, _leaseId);
      expect((await port.cancelVideoReservation(permit)).allClear, isTrue);
      expect(calls, [
        'bind',
        'readAllAudioState',
        'reserve',
        'cancelVideoReservation',
      ]);
    },
  );

  test(
    'lost video reserve cancellation carries exact attempt and CAS revision',
    () async {
      var cancels = 0;
      messenger.setMockMethodCallHandler(_method, (call) async {
        if (call.method == 'bind') return _binding();
        if (call.method == 'readAllAudioState') {
          return _snapshot(side: PracticeAudioSide.video, revision: 5);
        }
        if (call.method == 'cancelUnclaimedVideoReservation') {
          ++cancels;
          expect(call.arguments, {
            'ownerToken': _owner,
            'engineGeneration': 2,
            'attemptOwnerToken': _owner,
            'attemptEngineGeneration': 2,
            'attemptContextGeneration': 3,
            'leaseId': _leaseId,
            'leaseGeneration': 1,
            'expectedStateRevision': 5,
          });
          return {'status': 'closed', 'snapshot': _snapshot(revision: 6)};
        }
        throw StateError('Unexpected ${call.method}');
      });
      final port = NativeAudioArbiterChannel(channel: _method);
      await port.readAllAudioState();
      expect(
        (await port.cancelUnclaimedVideoReservation(
          attemptOwnerToken: _owner,
          attemptEngineGeneration: 2,
          attemptContextGeneration: 3,
          leaseId: _leaseId,
          leaseGeneration: 1,
          expectedStateRevision: 5,
        )).allClear,
        isTrue,
      );
      await expectLater(
        port.cancelUnclaimedVideoReservation(
          attemptOwnerToken: _owner,
          attemptEngineGeneration: 2,
          attemptContextGeneration: 3,
          leaseId: _leaseId,
          leaseGeneration: 1,
          expectedStateRevision: 5,
        ),
        throwsA(isA<NativeAudioProtocolException>()),
      );
      expect(cancels, 1);
    },
  );

  test(
    'stale close receipt cannot be accepted as a confirmed release',
    () async {
      messenger.setMockMethodCallHandler(_method, (call) async {
        if (call.method == 'bind') return _binding();
        if (call.method == 'readAllAudioState') return _snapshot();
        if (call.method == 'reserve') {
          return {
            'status': 'reserved',
            'leaseId': _leaseId,
            'leaseGeneration': 1,
            'stateRevision': 5,
          };
        }
        if (call.method == 'closeAll') {
          return {
            'status': 'stale',
            'snapshot': _snapshot(revision: 6, side: PracticeAudioSide.input),
          };
        }
        throw StateError('Unexpected ${call.method}');
      });
      final port = NativeAudioArbiterChannel(channel: _method);
      await port.readAllAudioState();
      final permit = await port.reserve(PracticeAudioSide.input, _leaseId);
      expect(
        (await port.closeAll(permit, NativeAudioCloseReason.userStop)).allClear,
        isFalse,
      );
    },
  );

  test('same revision cannot describe a changed native state', () async {
    var reads = 0;
    messenger.setMockMethodCallHandler(_method, (call) async {
      if (call.method == 'bind') return _binding();
      if (call.method == 'readAllAudioState') {
        return _snapshot(revision: 4, sticky: ++reads == 2);
      }
      throw StateError('Unexpected ${call.method}');
    });
    final port = NativeAudioArbiterChannel(channel: _method);
    expect((await port.readAllAudioState()).allClear, isTrue);
    await expectLater(
      port.readAllAudioState(),
      throwsA(isA<NativeAudioProtocolException>()),
    );
  });

  test(
    'an old permit is not sent to native after a newer close revision',
    () async {
      var nativeCloses = 0;
      messenger.setMockMethodCallHandler(_method, (call) async {
        if (call.method == 'bind') return _binding();
        if (call.method == 'readAllAudioState') return _snapshot();
        if (call.method == 'reserve') {
          return {
            'status': 'reserved',
            'leaseId': _leaseId,
            'leaseGeneration': 1,
            'stateRevision': 5,
          };
        }
        if (call.method == 'closeAll') {
          ++nativeCloses;
          return {'status': 'closed', 'snapshot': _snapshot(revision: 6)};
        }
        throw StateError('Unexpected ${call.method}');
      });
      final port = NativeAudioArbiterChannel(channel: _method);
      await port.readAllAudioState();
      final permit = await port.reserve(PracticeAudioSide.input, _leaseId);
      expect(
        (await port.closeAll(permit, NativeAudioCloseReason.userStop)).allClear,
        isTrue,
      );
      await expectLater(
        port.closeAll(permit, NativeAudioCloseReason.userStop),
        throwsA(isA<NativeAudioProtocolException>()),
      );
      expect(nativeCloses, 1);
    },
  );

  test(
    'fence and explicit recovery use context and visible revision',
    () async {
      var currentContext = 3;
      var revision = 4;
      var recoveries = 0;
      Map<String, Object?> state({required bool sticky}) => {
        ..._snapshot(revision: revision, sticky: sticky),
        'contextGeneration': currentContext,
      };
      messenger.setMockMethodCallHandler(_method, (call) async {
        if (call.method == 'bind') return _binding();
        if (call.method == 'readAllAudioState') {
          return state(sticky: revision > 4);
        }
        if (call.method == 'fenceContext') {
          final args = call.arguments as Map<Object?, Object?>;
          expect(args['contextGeneration'], 3);
          expect(args['reason'], 'accountChange');
          ++currentContext;
          ++revision;
          return {
            'contextGeneration': currentContext,
            'stateRevision': revision,
            'status': 'blocked',
            'snapshot': state(sticky: true),
          };
        }
        if (call.method == 'recoverAll') {
          ++recoveries;
          final args = call.arguments as Map<Object?, Object?>;
          expect(args['expectedStateRevision'], 5);
          expect(args['reason'], 'userRetry');
          ++revision;
          return {'status': 'closed', 'snapshot': state(sticky: false)};
        }
        throw StateError('Unexpected ${call.method}');
      });
      final port = NativeAudioArbiterChannel(channel: _method);
      await port.readAllAudioState();
      final fenced = await port.fenceContext(
        NativeAudioContextReason.accountChange,
      );
      expect(fenced.allClear, isFalse);
      expect(fenced.contextGeneration, 4);
      expect((await port.recoverAll(5)).allClear, isTrue);
      expect(recoveries, 1);
    },
  );

  test(
    'read replies older than reserve and playback receipts are rejected',
    () async {
      final oldPreReserveRead = Completer<Object?>();
      final oldPrePlaybackRead = Completer<Object?>();
      var reads = 0;
      messenger.setMockMethodCallHandler(_method, (call) async {
        switch (call.method) {
          case 'bind':
            return _binding();
          case 'readAllAudioState':
            ++reads;
            if (reads == 1) return _snapshot(revision: 4);
            if (reads == 2) return await oldPreReserveRead.future;
            if (reads == 3) return await oldPrePlaybackRead.future;
            throw StateError('Unexpected read');
          case 'reserve':
            return {
              'status': 'reserved',
              'leaseId': _leaseId,
              'leaseGeneration': 1,
              'stateRevision': 5,
            };
          case 'startOutput':
            return {
              'status': 'playing',
              'leaseId': _leaseId,
              'leaseGeneration': 1,
              'stateRevision': 6,
            };
        }
        throw StateError('Unexpected ${call.method}');
      });
      final port = NativeAudioArbiterChannel(
        channel: _method,
        allowedAssetIds: const {'demo-01'},
      );
      await port.readAllAudioState();
      final lateBeforeReserve = port.readAllAudioState();
      await Future<void>.delayed(Duration.zero);
      final permit = await port.reserve(PracticeAudioSide.output, _leaseId);
      await expectLater(
        port.recoverAll(4),
        throwsA(isA<NativeAudioProtocolException>()),
      );
      oldPreReserveRead.complete(_snapshot(revision: 4));
      await expectLater(
        lateBeforeReserve,
        throwsA(isA<NativeAudioProtocolException>()),
      );
      final lateBeforePlayback = port.readAllAudioState();
      await Future<void>.delayed(Duration.zero);
      await port.startOutput(permit, 'demo-01');
      oldPrePlaybackRead.complete(
        _snapshot(revision: 5, side: PracticeAudioSide.output)
          ..['outputPhase'] = 'reserved',
      );
      await expectLater(
        lateBeforePlayback,
        throwsA(isA<NativeAudioProtocolException>()),
      );
    },
  );

  test(
    'reserve reply from a fenced context is rejected after its await',
    () async {
      final lateReserve = Completer<Object?>();
      var context = 3;
      var revision = 4;
      messenger.setMockMethodCallHandler(_method, (call) async {
        if (call.method == 'bind') return _binding();
        if (call.method == 'readAllAudioState') return _snapshot();
        if (call.method == 'reserve') return lateReserve.future;
        if (call.method == 'fenceContext') {
          ++context;
          ++revision;
          return {
            'contextGeneration': context,
            'stateRevision': revision,
            'status': 'blocked',
            'snapshot': {
              ..._snapshot(revision: revision, sticky: true),
              'contextGeneration': context,
            },
          };
        }
        throw StateError('Unexpected ${call.method}');
      });
      final port = NativeAudioArbiterChannel(channel: _method);
      await port.readAllAudioState();
      final pendingReserve = port.reserve(PracticeAudioSide.input, _leaseId);
      await Future<void>.delayed(Duration.zero);
      expect(
        (await port.fenceContext(
          NativeAudioContextReason.routeChange,
        )).contextGeneration,
        4,
      );
      lateReserve.complete({
        'status': 'reserved',
        'leaseId': _leaseId,
        'leaseGeneration': 1,
        'stateRevision': 5,
      });
      await expectLater(
        pendingReserve,
        throwsA(isA<NativeAudioProtocolException>()),
      );
    },
  );

  test(
    'playback reply from a fenced context is rejected after its await',
    () async {
      final latePlayback = Completer<Object?>();
      var context = 3;
      var revision = 4;
      messenger.setMockMethodCallHandler(_method, (call) async {
        if (call.method == 'bind') return _binding();
        if (call.method == 'readAllAudioState') return _snapshot();
        if (call.method == 'reserve') {
          return {
            'status': 'reserved',
            'leaseId': _leaseId,
            'leaseGeneration': 1,
            'stateRevision': 5,
          };
        }
        if (call.method == 'startOutput') return latePlayback.future;
        if (call.method == 'fenceContext') {
          ++context;
          revision = 6;
          return {
            'contextGeneration': context,
            'stateRevision': revision,
            'status': 'blocked',
            'snapshot': {
              ..._snapshot(revision: revision, sticky: true),
              'contextGeneration': context,
            },
          };
        }
        throw StateError('Unexpected ${call.method}');
      });
      final port = NativeAudioArbiterChannel(
        channel: _method,
        allowedAssetIds: const {'demo-01'},
      );
      await port.readAllAudioState();
      final permit = await port.reserve(PracticeAudioSide.output, _leaseId);
      final pendingPlayback = port.startOutput(permit, 'demo-01');
      await Future<void>.delayed(Duration.zero);
      await port.fenceContext(NativeAudioContextReason.accountChange);
      latePlayback.complete({
        'status': 'playing',
        'leaseId': _leaseId,
        'leaseGeneration': 1,
        'stateRevision': 7,
      });
      await expectLater(
        pendingPlayback,
        throwsA(isA<NativeAudioProtocolException>()),
      );
    },
  );

  test(
    'concurrent fences send both reasons with successive contexts',
    () async {
      final firstFence = Completer<Object?>();
      final requests = <Map<Object?, Object?>>[];
      messenger.setMockMethodCallHandler(_method, (call) async {
        if (call.method == 'bind') return _binding();
        if (call.method == 'readAllAudioState') return _snapshot();
        if (call.method == 'fenceContext') {
          final args = call.arguments as Map<Object?, Object?>;
          requests.add(args);
          if (requests.length == 1) return await firstFence.future;
          return {
            'status': 'blocked',
            'contextGeneration': 5,
            'stateRevision': 6,
            'snapshot': {
              ..._snapshot(revision: 6, sticky: true),
              'contextGeneration': 5,
            },
          };
        }
        throw StateError('Unexpected ${call.method}');
      });
      final port = NativeAudioArbiterChannel(channel: _method);
      await port.readAllAudioState();
      final route = port.fenceContext(NativeAudioContextReason.routeChange);
      final account = port.fenceContext(NativeAudioContextReason.accountChange);
      await Future<void>.delayed(Duration.zero);
      expect(requests.length, 1);
      expect(requests.first['contextGeneration'], 3);
      expect(requests.first['reason'], 'routeChange');
      firstFence.complete({
        'status': 'blocked',
        'contextGeneration': 4,
        'stateRevision': 5,
        'snapshot': {
          ..._snapshot(revision: 5, sticky: true),
          'contextGeneration': 4,
        },
      });
      expect((await route).contextGeneration, 4);
      expect((await account).contextGeneration, 5);
      expect(requests.length, 2);
      expect(requests.last['contextGeneration'], 4);
      expect(requests.last['reason'], 'accountChange');
    },
  );

  test('native pre-fence retries once after a newer empty read', () async {
    final sentContexts = <int>[];
    var reads = 0;
    messenger.setMockMethodCallHandler(_method, (call) async {
      if (call.method == 'bind') return _binding();
      if (call.method == 'readAllAudioState') {
        return {
          ..._snapshot(revision: ++reads == 1 ? 4 : 5),
          'contextGeneration': reads == 1 ? 3 : 4,
        };
      }
      if (call.method == 'fenceContext') {
        final context = (call.arguments as Map)['contextGeneration'] as int;
        sentContexts.add(context);
        if (sentContexts.length == 1) {
          throw PlatformException(code: 'stale_audio_context');
        }
        return {
          'status': 'closed',
          'contextGeneration': 5,
          'stateRevision': 6,
          'snapshot': {..._snapshot(revision: 6), 'contextGeneration': 5},
        };
      }
      throw StateError('Unexpected ${call.method}');
    });
    final port = NativeAudioArbiterChannel(channel: _method);
    await port.readAllAudioState();
    expect(
      (await port.fenceContext(
        NativeAudioContextReason.background,
      )).contextGeneration,
      5,
    );
    expect(sentContexts, [3, 4]);
    expect(port.capturePreflightSnapshot?.contextGeneration, 5);
  });

  test(
    'stale pre-fence with held audio never retries or grants capture',
    () async {
      var fences = 0;
      var reads = 0;
      messenger.setMockMethodCallHandler(_method, (call) async {
        if (call.method == 'bind') return _binding();
        if (call.method == 'readAllAudioState') {
          return {
            ..._snapshot(revision: ++reads == 1 ? 4 : 5, sticky: reads > 1),
            'contextGeneration': reads == 1 ? 3 : 4,
          };
        }
        if (call.method == 'fenceContext') {
          ++fences;
          throw PlatformException(code: 'stale_audio_context');
        }
        throw StateError('Unexpected ${call.method}');
      });
      final port = NativeAudioArbiterChannel(channel: _method);
      await port.readAllAudioState();
      await expectLater(
        port.fenceContext(NativeAudioContextReason.background),
        throwsA(isA<PlatformException>()),
      );
      expect(fences, 1);
      expect(port.capturePreflightSnapshot, isNull);
    },
  );

  test(
    'fresh explicit recovery after a failed fence permits a new native fence',
    () async {
      var fenceCalls = 0;
      var reserveCalls = 0;
      messenger.setMockMethodCallHandler(_method, (call) async {
        switch (call.method) {
          case 'bind':
            return _binding();
          case 'readAllAudioState':
            return {
              ..._snapshot(revision: 5, sticky: true),
              'contextGeneration': 4,
            };
          case 'fenceContext':
            final args = call.arguments as Map<Object?, Object?>;
            ++fenceCalls;
            if (fenceCalls == 1) {
              expect(args['contextGeneration'], 3);
              throw PlatformException(code: 'audio_close_unconfirmed');
            }
            expect(args['contextGeneration'], 4);
            expect(args['reason'], 'accountChange');
            return {
              'status': 'closed',
              'contextGeneration': 5,
              'stateRevision': 7,
              'snapshot': {..._snapshot(revision: 7), 'contextGeneration': 5},
            };
          case 'recoverAll':
            final args = call.arguments as Map<Object?, Object?>;
            expect(args['expectedStateRevision'], 5);
            return {
              'status': 'closed',
              'snapshot': {..._snapshot(revision: 6), 'contextGeneration': 4},
            };
          case 'reserve':
            ++reserveCalls;
            return {
              'status': 'reserved',
              'leaseId': _leaseId,
              'leaseGeneration': 1,
              'stateRevision': 8,
            };
        }
        throw StateError('Unexpected ${call.method}');
      });
      final port = NativeAudioArbiterChannel(channel: _method);
      await expectLater(
        port.fenceContext(NativeAudioContextReason.routeChange),
        throwsA(isA<PlatformException>()),
      );
      expect((await port.readAllAudioState()).stateRevision, 5);
      await expectLater(
        port.reserve(PracticeAudioSide.input, _leaseId),
        throwsA(isA<NativeAudioProtocolException>()),
      );
      expect(reserveCalls, 0);
      expect((await port.recoverAll(5)).allClear, isTrue);
      expect(
        (await port.fenceContext(
          NativeAudioContextReason.accountChange,
        )).contextGeneration,
        5,
      );
      expect(fenceCalls, 2);
      expect(
        (await port.reserve(PracticeAudioSide.input, _leaseId)).stateRevision,
        8,
      );
      expect(reserveCalls, 1);
    },
  );

  test(
    'blocked or stale recovery keeps failed fence acquisition blocked',
    () async {
      for (final status in ['blocked', 'stale']) {
        var fenceCalls = 0;
        var reserveCalls = 0;
        messenger.setMockMethodCallHandler(_method, (call) async {
          switch (call.method) {
            case 'bind':
              return _binding();
            case 'readAllAudioState':
              return {
                ..._snapshot(revision: 5, sticky: true),
                'contextGeneration': 4,
              };
            case 'fenceContext':
              ++fenceCalls;
              throw PlatformException(code: 'audio_close_unconfirmed');
            case 'recoverAll':
              return {
                'status': status,
                'snapshot': {
                  ..._snapshot(revision: 6, sticky: true),
                  'contextGeneration': 4,
                },
              };
            case 'reserve':
              ++reserveCalls;
              throw StateError('Reserve must not reach native');
          }
          throw StateError('Unexpected ${call.method}');
        });
        final port = NativeAudioArbiterChannel(channel: _method);
        await expectLater(
          port.fenceContext(NativeAudioContextReason.routeChange),
          throwsA(isA<PlatformException>()),
        );
        await port.readAllAudioState();
        expect((await port.recoverAll(5)).allClear, isFalse);
        await expectLater(
          port.reserve(PracticeAudioSide.input, _leaseId),
          throwsA(isA<NativeAudioProtocolException>()),
        );
        await expectLater(
          port.fenceContext(NativeAudioContextReason.accountChange),
          throwsA(isA<PlatformException>()),
        );
        expect(fenceCalls, 1);
        expect(reserveCalls, 0);
      }
    },
  );

  test('changed recovery context cannot clear a failed fence', () async {
    var reserveCalls = 0;
    messenger.setMockMethodCallHandler(_method, (call) async {
      switch (call.method) {
        case 'bind':
          return _binding();
        case 'readAllAudioState':
          return {
            ..._snapshot(revision: 5, sticky: true),
            'contextGeneration': 4,
          };
        case 'fenceContext':
          throw PlatformException(code: 'audio_close_unconfirmed');
        case 'recoverAll':
          return {
            'status': 'closed',
            'snapshot': {..._snapshot(revision: 6), 'contextGeneration': 5},
          };
        case 'reserve':
          ++reserveCalls;
          throw StateError('Reserve must not reach native');
      }
      throw StateError('Unexpected ${call.method}');
    });
    final port = NativeAudioArbiterChannel(channel: _method);
    await expectLater(
      port.fenceContext(NativeAudioContextReason.routeChange),
      throwsA(isA<PlatformException>()),
    );
    await port.readAllAudioState();
    await expectLater(
      port.recoverAll(5),
      throwsA(isA<NativeAudioProtocolException>()),
    );
    await expectLater(
      port.reserve(PracticeAudioSide.input, _leaseId),
      throwsA(isA<NativeAudioProtocolException>()),
    );
    expect(reserveCalls, 0);
  });

  test(
    'failed fence requires a new accepted read before explicit retry',
    () async {
      var recoveries = 0;
      messenger.setMockMethodCallHandler(_method, (call) async {
        switch (call.method) {
          case 'bind':
            return _binding();
          case 'fenceContext':
            throw PlatformException(code: 'audio_close_unconfirmed');
          case 'recoverAll':
            ++recoveries;
            throw StateError('Retry must not reach native');
        }
        throw StateError('Unexpected ${call.method}');
      });
      final port = NativeAudioArbiterChannel(channel: _method);
      await expectLater(
        port.fenceContext(NativeAudioContextReason.routeChange),
        throwsA(isA<PlatformException>()),
      );
      await expectLater(
        port.recoverAll(4),
        throwsA(isA<NativeAudioProtocolException>()),
      );
      expect(recoveries, 0);
    },
  );

  test(
    'a read begun before fence failure is not a fresh recovery read',
    () async {
      final earlyReadReply = Completer<Object?>();
      var reads = 0;
      var recoveries = 0;
      messenger.setMockMethodCallHandler(_method, (call) async {
        switch (call.method) {
          case 'bind':
            return _binding();
          case 'readAllAudioState':
            if (++reads == 1) return _snapshot();
            return await earlyReadReply.future;
          case 'fenceContext':
            throw PlatformException(code: 'audio_close_unconfirmed');
          case 'recoverAll':
            ++recoveries;
            throw StateError('Retry must not reach native');
        }
        throw StateError('Unexpected ${call.method}');
      });
      final port = NativeAudioArbiterChannel(channel: _method);
      await port.readAllAudioState();
      final earlyRead = port.readAllAudioState();
      await Future<void>.delayed(Duration.zero);
      await expectLater(
        port.fenceContext(NativeAudioContextReason.routeChange),
        throwsA(isA<PlatformException>()),
      );
      earlyReadReply.complete({
        ..._snapshot(revision: 5, sticky: true),
        'contextGeneration': 4,
      });
      expect((await earlyRead).stateRevision, 5);
      await expectLater(
        port.recoverAll(5),
        throwsA(isA<NativeAudioProtocolException>()),
      );
      expect(recoveries, 0);
    },
  );

  test('late recovery cannot clear a newer observed revision', () async {
    final lateRecovery = Completer<Object?>();
    var reads = 0;
    var reserveCalls = 0;
    messenger.setMockMethodCallHandler(_method, (call) async {
      switch (call.method) {
        case 'bind':
          return _binding();
        case 'fenceContext':
          throw PlatformException(code: 'audio_close_unconfirmed');
        case 'readAllAudioState':
          return {
            ..._snapshot(revision: ++reads == 1 ? 5 : 6, sticky: true),
            'contextGeneration': 4,
          };
        case 'recoverAll':
          return lateRecovery.future;
        case 'reserve':
          ++reserveCalls;
          throw StateError('Reserve must not reach native');
      }
      throw StateError('Unexpected ${call.method}');
    });
    final port = NativeAudioArbiterChannel(channel: _method);
    await expectLater(
      port.fenceContext(NativeAudioContextReason.routeChange),
      throwsA(isA<PlatformException>()),
    );
    expect((await port.readAllAudioState()).stateRevision, 5);
    final recovery = port.recoverAll(5);
    await Future<void>.delayed(Duration.zero);
    expect((await port.readAllAudioState()).stateRevision, 6);
    lateRecovery.complete({
      'status': 'closed',
      'snapshot': {..._snapshot(revision: 7), 'contextGeneration': 4},
    });
    await expectLater(recovery, throwsA(isA<NativeAudioProtocolException>()));
    await expectLater(
      port.reserve(PracticeAudioSide.input, _leaseId),
      throwsA(isA<NativeAudioProtocolException>()),
    );
    expect(reserveCalls, 0);
  });
}
