import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'lesson_media_playback.dart';

const _defaultCloseDeadline = Duration(seconds: 2);

/// Current plugin implementations expose real packaged-file audio groups only
/// on Android. AVFoundation reports selectable HLS audio, not MP4 streams.
@visibleForTesting
bool debugCanInspectPackagedAudioTracks(TargetPlatform platform) =>
    platform == TargetPlatform.android;

/// A second QA gate shared by routes in this Flutter isolate. Widget gates can
/// be different; this still denies a second native player here until disposal
/// is confirmed. Other engines and microphone capture need native arbitration.
final class DebugNativeVideoSessionGate {
  static final DebugNativeVideoSessionGate shared =
      DebugNativeVideoSessionGate();

  Object? _owner;
  bool _blocked = false;

  bool get blocked => _blocked;

  Object? take() {
    if (_blocked || _owner != null) return null;
    return _owner = Object();
  }

  void release(Object? owner, {required bool confirmed}) {
    if (owner == null || !identical(_owner, owner)) return;
    if (!confirmed) _blocked = true;
    _owner = null;
  }
}

/// Keeps the platform player replaceable in a Dart-only QA test. The real port
/// asks Android for tracks after initialization; unknown means no play.
abstract interface class SilentLessonVideoPort {
  ValueListenable<VideoPlayerValue> get value;
  Future<void> setVolume(double volume);
  Future<void> initialize();
  Future<int?> audioTrackCount();
  Future<void> play();
  Future<void> pause();
  Future<void> dispose();
  Widget buildVideo();
}

final class _AssetSilentLessonVideoPort implements SilentLessonVideoPort {
  _AssetSilentLessonVideoPort(String assetPath, String captionText)
    : _controller = VideoPlayerController.asset(
        assetPath,
        closedCaptionFile: Future<ClosedCaptionFile>.value(
          WebVTTCaptionFile(captionText),
        ),
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: true,
          allowBackgroundPlayback: false,
        ),
      );

  final VideoPlayerController _controller;

  @override
  ValueListenable<VideoPlayerValue> get value => _controller;

  @override
  Future<void> setVolume(double volume) => _controller.setVolume(volume);

  @override
  Future<void> initialize() => _controller.initialize();

  @override
  Future<int?> audioTrackCount() async {
    // AVFoundation's getAudioTracks reports selectable HLS tracks, not the
    // actual audio stream in an MP4. Its empty result cannot certify silence.
    // Do not open native QA playback on iOS/macOS until a trustworthy media
    // receipt and physical audio-session test are available.
    if (!debugCanInspectPackagedAudioTracks(defaultTargetPlatform)) return null;
    if (!_controller.isAudioTrackSupportAvailable()) return null;
    return (await _controller.getAudioTracks()).length;
  }

  @override
  Future<void> play() => _controller.play();

  @override
  Future<void> pause() => _controller.pause();

  @override
  Future<void> dispose() => _controller.dispose();

  @override
  Widget buildVideo() => VideoPlayer(_controller);
}

/// Explicit QA factory. A normal lesson uses `LessonMediaSlot.empty` and never
/// calls this function. Plugin initialization may still affect AVAudioSession
/// or Android audio focus, so real microphone coexistence needs device proof.
@visibleForTesting
SilentLessonVideoHandle createDebugAssetSilentLessonVideo(
  String assetPath,
  String captionText,
) {
  if (kReleaseMode) {
    throw StateError('Native QA video is disabled in release builds');
  }
  if (!debugCanInspectPackagedAudioTracks(defaultTargetPlatform)) {
    throw StateError('Native QA video audio tracks cannot be inspected here');
  }
  return NativeSilentLessonVideoHandle._(
    port: _AssetSilentLessonVideoPort(assetPath, captionText),
    sessionGate: DebugNativeVideoSessionGate.shared,
    closeDeadline: _defaultCloseDeadline,
  );
}

/// User-started, debug-only native adapter. Zero audio tracks and a completed
/// native mute call are both required before its first play. This check is a
/// defensive QA boundary, not a signed media receipt or audio-session proof.
final class NativeSilentLessonVideoHandle implements SilentLessonVideoHandle {
  NativeSilentLessonVideoHandle._({
    required SilentLessonVideoPort port,
    required DebugNativeVideoSessionGate sessionGate,
    required Duration closeDeadline,
  }) : _port = port,
       _sessionGate = sessionGate,
       _closeDeadline = closeDeadline;

  @visibleForTesting
  NativeSilentLessonVideoHandle.forTesting({
    required SilentLessonVideoPort port,
    required DebugNativeVideoSessionGate sessionGate,
    Duration closeDeadline = _defaultCloseDeadline,
  }) : this._(
         port: port,
         sessionGate: sessionGate,
         closeDeadline: closeDeadline,
       );

  final SilentLessonVideoPort _port;
  final DebugNativeVideoSessionGate _sessionGate;
  final Duration _closeDeadline;
  final ValueNotifier<SilentLessonVideoFrame> _frame = ValueNotifier(
    const SilentLessonVideoFrame(),
  );
  Future<void>? _initializing, _closing;
  Object? _sessionOwner;
  bool _initializingPending = false;
  bool _listening = false;
  bool _initialized = false;
  bool _silentCertified = false;
  bool _closed = false;

  @override
  ValueListenable<SilentLessonVideoFrame> get frame => _frame;

  @override
  Future<void> initializeMuted() {
    if (_closed) throw StateError('Video handle is closed');
    return _initializing ??= _initialize();
  }

  Future<void> _initialize() async {
    final owner = _sessionGate.take();
    if (owner == null) throw StateError('Native QA video slot unavailable');
    _sessionOwner = owner;
    _initializingPending = true;
    try {
      // Before initialize this sets the Dart controller's desired volume;
      // video_player applies it to native only when initialized. We also await
      // an explicit post-initialize native mute below before allowing play.
      await _port.setVolume(0);
      if (_closed) return;
      await _port.initialize();
      if (_closed) return;
      await _port.setVolume(0);
      if (_closed) return;
      final value = _port.value.value;
      if (!value.isInitialized || value.hasError || value.volume != 0) {
        throw StateError('Silent video did not initialize');
      }
      final tracks = await _port.audioTrackCount();
      if (_closed) return;
      if (tracks != 0) {
        throw StateError('Audio track present or not inspectable');
      }
      _silentCertified = true;
      _initialized = true;
      _port.value.addListener(_sync);
      _listening = true;
      _sync();
    } finally {
      _initializingPending = false;
    }
  }

  void _sync() {
    if (_closed || !_initialized) return;
    final value = _port.value.value;
    final aspect = value.aspectRatio;
    _frame.value = SilentLessonVideoFrame(
      initialized: value.isInitialized,
      playing: value.isPlaying,
      hasError: value.hasError,
      audioOutputDisabled: _silentCertified && value.volume == 0,
      aspectRatio: aspect.isFinite && aspect > 0 ? aspect : 16 / 9,
      caption: value.caption.text,
    );
  }

  @override
  Future<void> play() async {
    if (_closed || !_initialized || !_frame.value.audioOutputDisabled) {
      throw StateError('Silent video is not ready');
    }
    await _port.play();
    _sync();
  }

  @override
  Future<void> pause() async {
    if (_closed || !_initialized) return;
    await _port.pause();
    _sync();
  }

  @override
  Future<void> close() => _closing ??= _retire();

  Future<void> _retire() async {
    _closed = true;
    if (_listening) {
      _port.value.removeListener(_sync);
      _listening = false;
    }
    final owner = _sessionOwner;
    _sessionOwner = null;
    Object? firstFailure;
    StackTrace? firstStack;
    Future<void> attempt(Future<void> Function() action) async {
      try {
        await action().timeout(_closeDeadline);
      } on Object catch (error, stack) {
        firstFailure ??= error;
        firstStack ??= stack;
      }
    }

    try {
      if (_initializingPending && _initializing != null) {
        await attempt(() => _initializing!);
      }
      if (_initialized) await attempt(_port.pause);
      await attempt(_port.dispose);
    } finally {
      _sessionGate.release(owner, confirmed: firstFailure == null);
      _frame.dispose();
    }
    if (firstFailure != null) {
      Error.throwWithStackTrace(firstFailure!, firstStack!);
    }
  }

  @override
  Widget buildVideo() => _port.buildVideo();
}
