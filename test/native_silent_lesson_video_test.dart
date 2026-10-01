import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/course/media/native_silent_lesson_video.dart';
import 'package:video_player/video_player.dart';

final class _FakeVideoPort implements SilentLessonVideoPort {
  _FakeVideoPort(
    this.events, {
    this.audioTracks = 0,
    this.initializeGate,
    this.disposeGate,
  });

  final List<String> events;
  final int? audioTracks;
  final Completer<void>? initializeGate, disposeGate;
  @override
  final ValueNotifier<VideoPlayerValue> value = ValueNotifier(
    const VideoPlayerValue(duration: Duration.zero),
  );

  @override
  Future<void> setVolume(double volume) async {
    events.add('volume:$volume');
    value.value = value.value.copyWith(volume: volume);
  }

  @override
  Future<void> initialize() async {
    events.add('initialize');
    await initializeGate?.future;
    value.value = value.value.copyWith(
      duration: const Duration(seconds: 2),
      size: const Size(160, 90),
      isInitialized: true,
    );
  }

  @override
  Future<int?> audioTrackCount() async {
    events.add('audioTracks');
    return audioTracks;
  }

  @override
  Future<void> play() async {
    events.add('play');
    value.value = value.value.copyWith(isPlaying: true);
  }

  @override
  Future<void> pause() async {
    events.add('pause');
    value.value = value.value.copyWith(isPlaying: false);
  }

  @override
  Future<void> dispose() async {
    events.add('dispose');
    await disposeGate?.future;
  }

  @override
  Widget buildVideo() => const ColoredBox(color: Colors.black);
}

void main() {
  test('packaged asset audio inspection is Android only', () {
    for (final platform in TargetPlatform.values) {
      expect(
        debugCanInspectPackagedAudioTracks(platform),
        platform == TargetPlatform.android,
      );
    }
  });

  test('iOS QA factory rejects before creating a native controller', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    expect(
      () => createDebugAssetSilentLessonVideo('unused.mp4', 'WEBVTT\n\n'),
      throwsStateError,
    );
  });

  test(
    'pre-mute, initialize, post-mute, and no-track check precede play',
    () async {
      final events = <String>[];
      final port = _FakeVideoPort(events);
      final handle = NativeSilentLessonVideoHandle.forTesting(
        port: port,
        sessionGate: DebugNativeVideoSessionGate(),
      );
      await handle.initializeMuted();
      expect(events, ['volume:0.0', 'initialize', 'volume:0.0', 'audioTracks']);
      expect(handle.frame.value.initialized, isTrue);
      expect(handle.frame.value.audioOutputDisabled, isTrue);
      await handle.play();
      expect(events.last, 'play');
      await handle.close();
    },
  );

  for (final count in <int?>[1, null]) {
    test('audio-track count $count fails closed before play', () async {
      final events = <String>[];
      final handle = NativeSilentLessonVideoHandle.forTesting(
        port: _FakeVideoPort(events, audioTracks: count),
        sessionGate: DebugNativeVideoSessionGate(),
      );
      await expectLater(handle.initializeMuted(), throwsStateError);
      expect(handle.frame.value.audioOutputDisabled, isFalse);
      await expectLater(handle.play(), throwsStateError);
      expect(events, isNot(contains('play')));
      await handle.close();
    });
  }

  test(
    'separate widget gates share one isolate-local native QA owner',
    () async {
      final sessionGate = DebugNativeVideoSessionGate();
      final first = NativeSilentLessonVideoHandle.forTesting(
        port: _FakeVideoPort([]),
        sessionGate: sessionGate,
      );
      final secondEvents = <String>[];
      final second = NativeSilentLessonVideoHandle.forTesting(
        port: _FakeVideoPort(secondEvents),
        sessionGate: sessionGate,
      );
      await first.initializeMuted();
      await expectLater(second.initializeMuted(), throwsStateError);
      expect(secondEvents, isEmpty);
      await second.close();
      await first.close();
      final third = NativeSilentLessonVideoHandle.forTesting(
        port: _FakeVideoPort([]),
        sessionGate: sessionGate,
      );
      await third.initializeMuted();
      await third.close();
    },
  );

  test('close is idempotent; a late frame never revives playback', () async {
    final events = <String>[];
    final port = _FakeVideoPort(events);
    final handle = NativeSilentLessonVideoHandle.forTesting(
      port: port,
      sessionGate: DebugNativeVideoSessionGate(),
    );
    await handle.initializeMuted();
    final before = handle.frame.value;
    await Future.wait([handle.close(), handle.close()]);
    expect(events.where((event) => event == 'dispose'), hasLength(1));
    port.value.value = port.value.value.copyWith(isPlaying: true);
    expect(handle.frame.value, before);
    await expectLater(handle.play(), throwsStateError);
  });

  test(
    'closing a pending initialize prevents late mute or frame publish',
    () async {
      final events = <String>[];
      final gate = Completer<void>();
      final port = _FakeVideoPort(events, initializeGate: gate);
      final handle = NativeSilentLessonVideoHandle.forTesting(
        port: port,
        sessionGate: DebugNativeVideoSessionGate(),
      );
      final initializing = handle.initializeMuted();
      await Future<void>.delayed(Duration.zero);
      expect(events, ['volume:0.0', 'initialize']);
      final closing = handle.close();
      gate.complete();
      await initializing;
      await closing;
      expect(events, ['volume:0.0', 'initialize', 'dispose']);
      expect(handle.frame.value.initialized, isFalse);
      await expectLater(handle.play(), throwsStateError);
    },
  );

  test('dispose timeout quarantines every later native QA handle', () async {
    final gate = DebugNativeVideoSessionGate();
    final pendingDispose = Completer<void>();
    final first = NativeSilentLessonVideoHandle.forTesting(
      port: _FakeVideoPort([], disposeGate: pendingDispose),
      sessionGate: gate,
      closeDeadline: const Duration(milliseconds: 20),
    );
    await first.initializeMuted();
    await expectLater(first.close(), throwsA(isA<TimeoutException>()));
    expect(gate.blocked, isTrue);
    final laterEvents = <String>[];
    final later = NativeSilentLessonVideoHandle.forTesting(
      port: _FakeVideoPort(laterEvents),
      sessionGate: gate,
    );
    await expectLater(later.initializeMuted(), throwsStateError);
    expect(laterEvents, isEmpty);
    pendingDispose.complete();
    await later.close();
    expect(gate.blocked, isTrue);
  });
}
