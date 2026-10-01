import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../design/ostinato_theme.dart';
import '../../design/widgets.dart';

const _retireDeadline = Duration(seconds: 2);

/// A QA fixture, never an accepted media or lesson-completion receipt.
@immutable
final class LessonMediaPlaybackFixture {
  const LessonMediaPlaybackFixture({
    required this.lessonId,
    required this.videoAssetPath,
    required this.captionAssetPaths,
  });

  final String lessonId, videoAssetPath;
  final Map<String, String> captionAssetPaths;
}

@immutable
final class SilentLessonVideoFrame {
  const SilentLessonVideoFrame({
    this.initialized = false,
    this.playing = false,
    this.hasError = false,
    this.audioOutputDisabled = false,
    this.aspectRatio = 16 / 9,
    this.caption = '',
  });

  final bool initialized, playing, hasError, audioOutputDisabled;
  final double aspectRatio;
  final String caption;
}

/// QA interface. A separate debug-only native adapter exists, but shipping
/// lessons do not instantiate it. Microphone coexistence still needs device
/// evidence before native video can become an accepted product path.
abstract interface class SilentLessonVideoHandle {
  ValueListenable<SilentLessonVideoFrame> get frame;
  Future<void> initializeMuted();
  Future<void> play();
  Future<void> pause();
  Future<void> close();
  Widget buildVideo();
}

typedef SilentLessonVideoFactory =
    SilentLessonVideoHandle Function(String videoAssetPath, String captionText);

/// Share one gate between QA routes. An uncertain close blocks later handles.
final class DebugSilentVideoGate {
  Completer<void>? _owner;
  final Queue<Completer<Completer<void>?>> _waiting = Queue();
  bool _blocked = false;

  bool get blocked => _blocked;

  Future<Completer<void>?> take() {
    final request = Completer<Completer<void>?>();
    _waiting.addLast(request);
    _drain();
    return request.future;
  }

  void _drain() {
    if (_blocked) {
      while (_waiting.isNotEmpty) {
        _waiting.removeFirst().complete(null);
      }
      return;
    }
    if (_owner != null || _waiting.isEmpty) return;
    // Assign ownership before completing a waiter: synchronous continuations
    // cannot observe an unowned slot and take the same native session.
    final owner = _owner = Completer<void>();
    _waiting.removeFirst().complete(owner);
  }

  void release(Completer<void> owner, {required bool confirmed}) {
    if (!identical(_owner, owner)) return;
    if (!confirmed) _blocked = true;
    _owner = null;
    owner.complete();
    _drain();
  }
}

/// User-started silent fixture playback. This widget has no progress-store or
/// audio-lease dependency and cannot be built by the shipping lesson route.
class DebugSilentLessonPlayback extends StatefulWidget {
  const DebugSilentLessonPlayback({
    required this.fixture,
    required this.bundle,
    required this.locale,
    required this.videoFactory,
    required this.gate,
    super.key,
  });

  final LessonMediaPlaybackFixture fixture;
  final AssetBundle bundle;
  final String locale;
  final SilentLessonVideoFactory videoFactory;
  final DebugSilentVideoGate gate;

  @override
  State<DebugSilentLessonPlayback> createState() =>
      _DebugSilentLessonPlaybackState();
}

class _DebugSilentLessonPlaybackState extends State<DebugSilentLessonPlayback>
    with WidgetsBindingObserver {
  int _epoch = 0;
  SilentLessonVideoHandle? _video;
  Completer<void>? _slotOwner;
  Future<void> _closing = Future<void>.value();
  Future<void> _nativeOperation = Future<void>.value();
  bool _ready = false;
  bool _failed = false;
  bool _commandPending = false;

  @override
  void initState() {
    super.initState();
    if (!kReleaseMode) {
      WidgetsBinding.instance.addObserver(this);
      _prepare();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _retire();
  }

  void _onFrame() {
    if (!mounted) return;
    final frame = _video?.frame.value;
    if (frame == null) return;
    if (frame.hasError || !frame.audioOutputDisabled) {
      _retire();
      setState(() => _failed = true);
      return;
    }
    setState(() {});
  }

  Future<void> _invoke(Future<void> Function() operation) {
    // Publish the in-flight marker before a synchronous frame callback can
    // retire the handle; close must await this exact native operation first.
    final settled = Completer<void>();
    _nativeOperation = settled.future;
    try {
      final result = operation();
      unawaited(
        result.then<void>(
          (_) => settled.complete(),
          onError: (Object _, StackTrace _) => settled.complete(),
        ),
      );
      return result;
    } catch (_) {
      settled.complete();
      rethrow;
    }
  }

  Future<void> _close(
    SilentLessonVideoHandle video,
    Future<void> pending,
    Completer<void> owner,
  ) async {
    var confirmed = true;
    Future<void> attempt(Future<void> Function() operation) async {
      try {
        await operation().timeout(_retireDeadline);
      } catch (_) {
        confirmed = false;
      }
    }

    try {
      await attempt(() => pending);
      await attempt(video.pause);
      await attempt(video.close);
    } finally {
      // A timeout does not cancel the underlying platform Future.
      widget.gate.release(owner, confirmed: confirmed);
    }
  }

  void _retire() {
    ++_epoch;
    final video = _video;
    final owner = _slotOwner;
    _video = null;
    _slotOwner = null;
    _ready = false;
    _commandPending = false;
    if (owner == null) return;
    if (video == null) {
      widget.gate.release(owner, confirmed: true);
      return;
    }
    video.frame.removeListener(_onFrame);
    final pending = _nativeOperation;
    _closing = _closing.then((_) => _close(video, pending, owner));
    unawaited(_closing);
  }

  Future<void> _prepare() async {
    final epoch = ++_epoch;
    try {
      final captionPath = widget.fixture.captionAssetPaths[widget.locale];
      if (captionPath == null || captionPath.isEmpty) {
        throw const FormatException('Missing caption locale');
      }
      final captions = await widget.bundle.loadString(captionPath);
      final header = 'WEBVTT - Motion locale=${widget.locale}\n\n';
      if (!captions.startsWith(header) ||
          !captions.substring(header.length).contains('-->')) {
        throw const FormatException('Invalid caption track');
      }
      if (!mounted || epoch != _epoch) return;
      final owner = await widget.gate.take();
      if (owner == null) {
        throw StateError('Previous playback close is unconfirmed');
      }
      if (!mounted || epoch != _epoch) {
        widget.gate.release(owner, confirmed: true);
        return;
      }
      _slotOwner = owner;
      final video = widget.videoFactory(
        widget.fixture.videoAssetPath,
        captions,
      );
      _video = video;
      video.frame.addListener(_onFrame);
      await _invoke(video.initializeMuted);
      if (!mounted || epoch != _epoch || _video != video) return;
      final frame = video.frame.value;
      if (!frame.initialized || !frame.audioOutputDisabled || frame.hasError) {
        throw StateError('Silent video did not initialize');
      }
      setState(() => _ready = true);
    } catch (_) {
      if (!mounted || epoch != _epoch) return;
      _retire();
      setState(() => _failed = true);
    }
  }

  Future<void> _toggle() async {
    final video = _video;
    if (video == null || !_ready || _failed || _commandPending) return;
    if (!video.frame.value.audioOutputDisabled) {
      _retire();
      setState(() => _failed = true);
      return;
    }
    setState(() => _commandPending = true);
    try {
      await _invoke(video.frame.value.playing ? video.pause : video.play);
      if (!mounted || _video != video) return;
      if (!video.frame.value.audioOutputDisabled ||
          video.frame.value.hasError) {
        throw StateError('Silent video state changed');
      }
      setState(() => _commandPending = false);
    } catch (_) {
      if (!mounted || _video != video) return;
      _retire();
      setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    if (!kReleaseMode) WidgetsBinding.instance.removeObserver(this);
    _retire();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kReleaseMode) return const SizedBox.shrink();
    final tr = widget.locale == 'tr';
    if (_failed) {
      return GlassCard(
        child: Text(
          tr
              ? 'Sessiz gösterim açılamadı. Yazılı derse devam edebilirsin.'
              : 'The silent demonstration could not open. You can continue with the written lesson.',
          key: const Key('ostinato.debugMediaFailure'),
        ),
      );
    }
    final frame = _video?.frame.value;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            tr ? 'TEST GÖSTERİMİ · SESSİZ' : 'TEST DEMONSTRATION · SILENT',
            style: monoText(size: 12),
          ),
          const SizedBox(height: 10),
          if (!_ready || frame == null)
            const AspectRatio(
              aspectRatio: 16 / 9,
              child: Center(child: CircularProgressIndicator()),
            )
          else
            AspectRatio(
              aspectRatio: frame.aspectRatio.isFinite && frame.aspectRatio > 0
                  ? frame.aspectRatio
                  : 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _video!.buildVideo(),
                  if (frame.caption.isNotEmpty)
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: ColoredBox(
                        color: const Color(0xCC000000),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            frame.caption,
                            key: const Key('ostinato.debugMediaCaption'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          TextButton.icon(
            key: const Key('ostinato.debugMediaToggle'),
            onPressed: _ready && !_commandPending ? _toggle : null,
            icon: Icon(frame?.playing == true ? Icons.pause : Icons.play_arrow),
            label: Text(
              frame?.playing == true
                  ? (tr ? 'Duraklat' : 'Pause')
                  : (tr ? 'Oynat' : 'Play'),
            ),
          ),
          Text(
            tr
                ? 'Bu test gösterimi ders ilerlemesini değiştirmez.'
                : 'This test demonstration does not change lesson progress.',
            style: hankenText(size: 12),
          ),
        ],
      ),
    );
  }
}
