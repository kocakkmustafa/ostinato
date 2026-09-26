import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:ostinato_audio/ostinato_audio.dart';
import 'package:permission_handler/permission_handler.dart';

import 'audio_capture_channel.dart';
import 'audio_route_state.dart';

AudioSurfaceState audioPermissionState(PermissionStatus perm) =>
    perm.isPermanentlyDenied || perm.isRestricted
    ? const AudioPermissionDeniedPermanent()
    : const AudioPermissionDeniedRetriable();

AudioSurfaceState _mapPlatformException(PlatformException e) =>
    e.code == 'unsupported_sample_rate'
    ? AudioUnavailable('unsupported_sample_rate:${e.message ?? "?"}')
    : AudioSetupFailed(e.code);

Future<void>? _closingAudio;
AudioInputController? _audioOwner;
Future<void> _nativeLane = Future.value();
Future<void> _serializeNative(Future<void> Function() operation) {
  final next = _nativeLane.then((_) => operation());
  _nativeLane = next.catchError((Object _) {});
  return next;
}

void _releaseAudioCapture(Future<void> Function() stopFn) {
  _closingAudio = stopFn().catchError((Object _) {});
}

@visibleForTesting
void noteAudioClosing(Future<void> closing) => _closingAudio = closing;

@visibleForTesting
Future<void> awaitPendingAudioClose() async {
  final closing = _closingAudio;
  if (closing != null) {
    await closing;
    if (identical(_closingAudio, closing)) _closingAudio = null;
  }
}

/// Permission dialogs can briefly make the app inactive before capture starts.
/// Once capture is open, every loss of foreground stops it. Paused/detached
/// additionally cancel pending permission/start work.
@visibleForTesting
final class AudioLifecycleObserver extends WidgetsBindingObserver {
  AudioLifecycleObserver({
    required this.onBackground,
    this.onInactive,
    this.onResumed,
  });
  final VoidCallback onBackground;
  final VoidCallback? onInactive;
  final VoidCallback? onResumed;
  bool _attached = false;
  void attach() {
    if (_attached) return;
    WidgetsBinding.instance.addObserver(this);
    _attached = true;
  }

  void detach() {
    if (!_attached) return;
    WidgetsBinding.instance.removeObserver(this);
    _attached = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused || AppLifecycleState.detached:
        onBackground();
      case AppLifecycleState.inactive || AppLifecycleState.hidden:
        onInactive?.call();
      case AppLifecycleState.resumed:
        onResumed?.call();
    }
  }
}

/// RAM-only native source. Fake-channel tests prove cancellation/cleanup;
/// physical microphone/route behavior remains a separate acceptance gate.
final class AudioInputController implements AudioSource {
  AudioInputController({
    AudioCaptureChannel? channel,
    int ringBufferCapacitySamples = 44100 * 4,
    Future<PermissionStatus> Function()? requestMicrophonePermission,
  }) : _channel = channel ?? MethodChannelAudioCaptureChannel(),
       _ring = AudioRingBuffer(capacitySamples: ringBufferCapacitySamples),
       _requestPermission =
           requestMicrophonePermission ?? Permission.microphone.request;

  final AudioCaptureChannel _channel;
  final AudioRingBuffer _ring;
  final Future<PermissionStatus> Function() _requestPermission;
  final _chunks = StreamController<AudioChunk>.broadcast();
  final _status = StreamController<AudioSurfaceState>.broadcast();
  StreamSubscription<RawAudioEvent>? _sub;
  AudioLifecycleObserver? _lifecycle;
  Completer<bool>? _foregroundReady;
  bool _running = false;
  bool _starting = false;
  bool _askingPermission = false;
  bool _channelConnected = false;
  bool _disposed = false;
  int _epoch = 0;
  int? _sampleRate;
  AudioRoute _route = AudioRoute.unknown;

  @override
  Stream<AudioChunk> get chunks => _chunks.stream;
  @override
  Stream<AudioSurfaceState> get status => _status.stream;
  @visibleForTesting
  int get bufferedSampleCountForTest => _ring.length;
  void _emit(AudioSurfaceState state) {
    if (!_disposed) _status.add(state);
  }

  bool _current(int epoch) =>
      !_disposed && epoch == _epoch && identical(_audioOwner, this);

  Future<bool> _waitForForeground() async {
    final state = WidgetsBinding.instance.lifecycleState;
    // Null is the binding's initial state (including isolated unit harnesses).
    // Native implementations also independently require foreground at start.
    if (state == null || state == AppLifecycleState.resumed) return true;
    _foregroundReady = Completer<bool>();
    return _foregroundReady!.future.timeout(
      const Duration(seconds: 3),
      onTimeout: () => false,
    );
  }

  @override
  Future<void> start({required int sampleRate}) async {
    if (_disposed || _starting || _running) return;
    final previous = _audioOwner;
    _audioOwner = this;
    final epoch = ++_epoch;
    _starting = true;
    if (previous != null && !identical(previous, this)) await previous.stop();
    if (!_current(epoch)) return;
    _route = AudioRoute.unknown;
    _sampleRate = null;
    _lifecycle = AudioLifecycleObserver(
      onBackground: () => unawaited(_stop(announce: true)),
      onInactive: () {
        if (_running || (_starting && !_askingPermission)) {
          unawaited(_stop(announce: true));
        }
      },
      onResumed: () {
        final pending = _foregroundReady;
        if (pending != null && !pending.isCompleted) pending.complete(true);
      },
    )..attach();
    _emit(const AudioStarting());
    try {
      await awaitPendingAudioClose();
      if (!_current(epoch)) return;
      _askingPermission = true;
      final perm = await _requestPermission();
      _askingPermission = false;
      if (!_current(epoch)) return;
      if (!perm.isGranted) {
        _emit(audioPermissionState(perm));
        await _stop(announce: false);
        return;
      }
      if (!await _waitForForeground() || !_current(epoch)) {
        if (_current(epoch)) _emit(const AudioSetupFailed('not_foreground'));
        await _stop(announce: false);
        return;
      }
      _channelConnected = true;
      _sub = _channel.events.listen(
        _onRawEvent,
        onError: (Object _) {
          _emit(const AudioSetupFailed('capture_stream_failed'));
          unawaited(_stop(announce: false));
        },
      );
      await _serializeNative(() async {
        if (!_current(epoch)) return;
        final channel = _channel;
        if (channel is PreparedAudioCaptureChannel) {
          await (channel as PreparedAudioCaptureChannel).prepare();
        }
        if (!_current(epoch)) return;
        await _channel.start(sampleRate: sampleRate);
        // Cleanup shares the same lane as every owner's start/stop. It
        // cannot arrive after a newer owner's start and stop that session.
        if (!_current(epoch)) await _channel.stop();
      });
      if (!_current(epoch)) return;
      _running = true;
      _starting = false;
      _emit(AudioCalibrating(_route));
    } on PlatformException catch (e) {
      if (_current(epoch)) _emit(_mapPlatformException(e));
      await _stop(announce: false);
    } on Object {
      if (_current(epoch)) {
        _emit(const AudioSetupFailed('capture_start_failed'));
      }
      await _stop(announce: false);
    }
  }

  void _onRawEvent(RawAudioEvent event) {
    if (_disposed || !(_running || _starting)) return;
    switch (event) {
      case RawAudioChunkEvent(
        :final samples,
        :final sampleRate,
        :final tNativeUs,
      ):
        if (!_running) return;
        if (sampleRate <= 0 ||
            samples.isEmpty ||
            samples.any((v) => !v.isFinite || v.abs() > 1.0)) {
          _emit(const AudioSetupFailed('invalid_pcm'));
          unawaited(_stop(announce: false));
          return;
        }
        if (_sampleRate != null && _sampleRate != sampleRate) {
          _ring.clear();
          _emit(AudioCalibrating(_route));
        }
        _sampleRate = sampleRate;
        _ring.push(samples);
        _chunks.add(
          AudioChunk(
            samples: samples,
            sampleRate: sampleRate,
            tStartUs: tNativeUs,
            clockDomain: AudioClockDomain.monotonic,
          ),
        );
      case RawRouteChangedEvent(:final platformRouteTag):
        _route = mapPlatformRouteTag(platformRouteTag);
        _ring.clear();
        _sampleRate = null;
        if (_running) _emit(AudioCalibrating(_route));
      case RawInterruptedEvent(:final reason):
        _emit(AudioSetupFailed(reason));
        unawaited(_stop(announce: false));
    }
  }

  @override
  Future<void> stop() => _stop(announce: true);

  Future<void> _stop({required bool announce}) async {
    final stoppedEpoch = ++_epoch;
    _running = false;
    _starting = false;
    _askingPermission = false;
    final pending = _foregroundReady;
    if (pending != null && !pending.isCompleted) pending.complete(false);
    _foregroundReady = null;
    _lifecycle?.detach();
    _lifecycle = null;
    final subscription = _sub;
    _sub = null;
    final hadConnection = _channelConnected;
    _channelConnected = false;
    _ring.clear();
    _sampleRate = null;
    // Publish the close barrier before cancellation can yield. A new start
    // cannot overtake an old stop while a subscription takes time to close.
    if (hadConnection) {
      _releaseAudioCapture(() => _serializeNative(_channel.stop));
    }
    await subscription?.cancel();
    if (hadConnection) await awaitPendingAudioClose();
    if (stoppedEpoch != _epoch) return;
    if (identical(_audioOwner, this)) _audioOwner = null;
    if (announce) _emit(const AudioStopped());
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _stop(announce: false);
    await _chunks.close();
    await _status.close();
  }
}
