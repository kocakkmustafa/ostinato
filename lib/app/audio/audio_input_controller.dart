import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:ostinato_audio/ostinato_audio.dart';
import 'package:permission_handler/permission_handler.dart';

import 'audio_capture_channel.dart';
import 'audio_continuity.dart';
import 'audio_route_state.dart';
import 'practice_audio_root.dart';

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
AudioInputController? _audioCandidate;
_AudioCloseLatch? _audioCloseLatch;

final class _AudioCloseLatch {
  _AudioCloseLatch(
    this.channel,
    this.attemptId, {
    required this.pendingNativeCall,
    this.foreignRecovery = false,
  }) : requiresExplicitRetry = pendingNativeCall;
  // A foreign observed close has no pending call on its retired channel.
  final AudioCaptureChannel? channel;
  final String? attemptId;
  bool pendingNativeCall;
  final bool requiresExplicitRetry;
  final bool foreignRecovery;
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

@visibleForTesting
void resetAudioCaptureCoordinatorForTest() {
  _closingAudio = null;
  _audioOwner = null;
  _audioCandidate = null;
  _audioCloseLatch = null;
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
    Duration nativeCallTimeout = const Duration(seconds: 3),
    Duration pcmDeliveryTimeout = const Duration(seconds: 3),
  }) : assert(pcmDeliveryTimeout > Duration.zero),
       _channel = channel ?? MethodChannelAudioCaptureChannel(),
       _ring = AudioRingBuffer(capacitySamples: ringBufferCapacitySamples),
       _nativeCallTimeout = nativeCallTimeout,
       _pcmDeliveryTimeout = pcmDeliveryTimeout,
       _requestPermission =
           requestMicrophonePermission ?? Permission.microphone.request;

  final AudioCaptureChannel _channel;
  final AudioRingBuffer _ring;
  final _continuity = AudioContinuity();
  final Duration _nativeCallTimeout;
  // Wall-clock transport budget after native start / the last valid PCM.
  // This is independent of room calibration, pitch detection and loudness:
  // nonempty, valid all-zero PCM is still successful sample delivery.
  final Duration _pcmDeliveryTimeout;
  final Future<PermissionStatus> Function() _requestPermission;
  final _chunks = StreamController<AudioChunk>.broadcast();
  final _status = StreamController<AudioSurfaceState>.broadcast();
  final _anchors = StreamController<MetronomeAnchor>.broadcast();
  StreamSubscription<RawAudioEvent>? _sub;
  Timer? _pcmDeliveryTimer;
  AudioLifecycleObserver? _lifecycle;
  PracticeAudioCaptureAction? _captureAction;
  Completer<bool>? _foregroundReady;
  bool _running = false;
  bool _starting = false;
  bool _askingPermission = false;
  bool _channelConnected = false;
  bool _disposed = false;
  bool _nativeCallPending = false;
  Future<void>? _stopInFlight;
  AudioCaptureCloseState _closeState = const AudioCaptureCloseState.unknown();
  bool _closeReadbackAfterLatch = false;
  final Set<void Function()> _cancelCloseReadbacks = {};
  int _epoch = 0;
  AudioRoute _route = AudioRoute.unknown;
  AudioSessionMode _sessionMode = AudioSessionMode.recordOnly;

  /// F2.1: the mode of the current (or last requested) attempt.
  AudioSessionMode get sessionMode => _sessionMode;

  @override
  Stream<AudioChunk> get chunks => _chunks.stream;
  @override
  Stream<AudioSurfaceState> get status => _status.stream;
  @visibleForTesting
  int get bufferedSampleCountForTest => _ring.length;
  AudioCaptureCloseState get captureCloseState => _closeState;
  bool get captureGateReady =>
      _closeState.isClear &&
      _audioCloseLatch == null &&
      _audioOwner == null &&
      _audioCandidate == null;
  bool get captureClosePending =>
      _stopInFlight != null ||
      _closeState.attemptInFlight ||
      ((_nativeCallPending || (_audioCloseLatch?.pendingNativeCall ?? false)) &&
          !_freshNativeRetryEvidence(_audioCloseLatch, _closeState));
  bool get captureNeedsExplicitRetry {
    if (captureClosePending) return false;
    final latch = _audioCloseLatch;
    if (latch != null) return _freshNativeRetryEvidence(latch, _closeState);
    if (_closeState.phase == AudioCaptureClosePhase.running) {
      return _ownsNativeAttempt(_closeState.attemptId);
    }
    return _closeState.canRetry;
  }

  bool _ownsNativeAttempt(String? id) {
    final channel = _channel;
    return id != null &&
        channel is AudioCaptureCloseControl &&
        (channel as AudioCaptureCloseControl).attemptId == id;
  }

  bool _stickyRecoveryState(AudioCaptureCloseState state) =>
      !state.attemptInFlight &&
      state.requiresExplicitRetry &&
      (state.phase == AudioCaptureClosePhase.unconfirmedQuiescent ||
          state.phase == AudioCaptureClosePhase.releasedAwaitingExplicitRetry);

  bool _nativeAllowsRetry(
    _AudioCloseLatch latch,
    AudioCaptureCloseState state,
  ) {
    final id = latch.attemptId;
    return id != null &&
        (state.isClear ||
            (state.attemptId == id &&
                !state.attemptInFlight &&
                state.canRetry &&
                (!latch.foreignRecovery || _stickyRecoveryState(state))));
  }

  bool _freshNativeRetryEvidence(
    _AudioCloseLatch? latch,
    AudioCaptureCloseState state,
  ) =>
      latch != null &&
      _closeReadbackAfterLatch &&
      _nativeAllowsRetry(latch, state);

  Future<AudioCaptureCloseState> _boundedCloseReadback(
    AudioCaptureCloseControl control,
  ) {
    if (_disposed) {
      // A route can be disposed while an earlier stop is still finishing.
      // Accept a status that is already settled in this microtask turn (the
      // fake has one), but never arm a fresh timer for a detached route.
      final settled = Completer<AudioCaptureCloseState>();
      void finish(AudioCaptureCloseState state) {
        if (!settled.isCompleted) settled.complete(state);
      }

      try {
        unawaited(
          control.readCloseState().then<void>(
            finish,
            onError: (Object _, StackTrace stackTrace) =>
                finish(const AudioCaptureCloseState.unknown()),
          ),
        );
      } on Object {
        finish(const AudioCaptureCloseState.unknown());
      }
      scheduleMicrotask(() => finish(const AudioCaptureCloseState.unknown()));
      return settled.future;
    }
    final result = Completer<AudioCaptureCloseState>();
    late final Timer deadline;
    late final void Function() cancel;
    void finish(AudioCaptureCloseState state) {
      if (result.isCompleted) return;
      deadline.cancel();
      _cancelCloseReadbacks.remove(cancel);
      result.complete(state);
    }

    cancel = () => finish(const AudioCaptureCloseState.unknown());
    _cancelCloseReadbacks.add(cancel);
    deadline = Timer(_nativeCallTimeout, cancel);
    try {
      unawaited(
        control.readCloseState().then<void>(
          finish,
          onError: (Object _, StackTrace stackTrace) => cancel(),
        ),
      );
    } on Object {
      cancel();
    }
    return result.future;
  }

  void _suspendPendingCloseReadbacks() {
    for (final cancel in _cancelCloseReadbacks.toList()) {
      cancel();
    }
    final channel = _channel;
    if (channel is AudioCaptureReadbackCancellation) {
      (channel as AudioCaptureReadbackCancellation)
          .suspendCloseReadbacksUntilExplicitRetry();
    }
    final retained = _audioCloseLatch?.channel;
    if (retained is AudioCaptureReadbackCancellation &&
        !identical(retained, channel)) {
      (retained as AudioCaptureReadbackCancellation)
          .suspendCloseReadbacksUntilExplicitRetry();
    }
  }

  Future<AudioCaptureCloseState> refreshCloseState() async {
    final latchAtRead = _audioCloseLatch;
    final channel = _channel;
    AudioCaptureCloseState next;
    try {
      next = channel is AudioCaptureCloseControl
          ? await _boundedCloseReadback(channel as AudioCaptureCloseControl)
          : const AudioCaptureCloseState.unknown();
    } on Object {
      next = const AudioCaptureCloseState.unknown();
    }
    _closeState = next;
    _closeReadbackAfterLatch = identical(_audioCloseLatch, latchAtRead);
    if (_audioCloseLatch == null &&
        _stickyRecoveryState(next) &&
        next.attemptId != null &&
        !_ownsNativeAttempt(next.attemptId)) {
      // Keep the exact ID across route disposal in this Dart isolate. There
      // is no pending call or retained retired transport for this foreign ID.
      _audioCloseLatch = _AudioCloseLatch(
        null,
        next.attemptId,
        pendingNativeCall: false,
        foreignRecovery: true,
      );
      _closeReadbackAfterLatch = true;
    }
    return next;
  }

  /// An explicit user retry only closes the retained attempt. It never starts
  /// capture or clears a local timeout merely because a readback says clear.
  Future<void> retryClose() async {
    if (_disposed) {
      throw PlatformException(code: 'capture_controller_disposed');
    }
    final state = await refreshCloseState();
    if (state.attemptInFlight) {
      throw PlatformException(code: 'capture_close_in_flight');
    }
    var latch = _audioCloseLatch;
    if (latch == null &&
        state.canRetry &&
        state.attemptId != null &&
        (state.phase != AudioCaptureClosePhase.running ||
            _ownsNativeAttempt(state.attemptId))) {
      latch = _AudioCloseLatch(
        _channel,
        state.attemptId,
        pendingNativeCall: false,
      );
      _audioCloseLatch = latch;
    }
    if (latch == null || !_nativeAllowsRetry(latch, state)) {
      throw PlatformException(code: 'capture_close_unconfirmed');
    }
    final id = latch.attemptId;
    final channel = _channel;
    final AudioCaptureCloseControl? control =
        channel is AudioCaptureCloseControl
        ? channel as AudioCaptureCloseControl
        : null;
    final currentAttemptId = control?.attemptId;
    if (control == null ||
        id == null ||
        (currentAttemptId != null && currentAttemptId != id) ||
        !identical(_audioCloseLatch, latch)) {
      throw PlatformException(code: 'capture_close_unconfirmed');
    }
    // The retained ID is closed through this controller's current transport.
    await control.retryStopAttempt(id).timeout(_nativeCallTimeout);
    final confirmed = await _boundedCloseReadback(control);
    if (!confirmed.confirmsClearAfterStop(id) ||
        !identical(_audioCloseLatch, latch)) {
      throw PlatformException(code: 'capture_close_unconfirmed');
    }
    _audioCloseLatch = null;
    _audioOwner = null;
    _closeState = confirmed;
    _closeReadbackAfterLatch = false;
  }

  void _emit(AudioSurfaceState state) {
    if (!_disposed) _status.add(state);
  }

  bool _current(int epoch) =>
      !_disposed &&
      epoch == _epoch &&
      (identical(_audioCandidate, this) || identical(_audioOwner, this));

  Future<void> _boundedNative(Future<void> nativeCall) async {
    _nativeCallPending = true;
    unawaited(
      nativeCall.then<void>(
        (_) => _nativeCallSettled(),
        onError: (Object _, StackTrace stackTrace) => _nativeCallSettled(),
      ),
    );
    await nativeCall.timeout(_nativeCallTimeout);
  }

  void _nativeCallSettled() {
    _nativeCallPending = false;
    final latch = _audioCloseLatch;
    if (latch != null &&
        identical(latch.channel, _channel) &&
        latch.pendingNativeCall) {
      latch.pendingNativeCall = false;
      // A legacy/fake native start can finish after the first stop request.
      // Issue another direct close, but retain the latch: only a later
      // explicit retry may unlock another capture.
      unawaited(
        _channel.stop().timeout(_nativeCallTimeout).catchError((Object _) {}),
      );
    }
  }

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
  Future<void> start({
    required int sampleRate,
    PracticeAudioCaptureAction? captureAction,
    AudioSessionMode sessionMode = AudioSessionMode.recordOnly,
  }) async {
    if (_disposed || _starting || _running) {
      captureAction?.retire();
      return;
    }
    // F2.1: a play+record request on a record-only channel fails before any
    // owner, lifecycle observer or native resource is claimed.
    if (sessionMode == AudioSessionMode.playAndRecord &&
        _channel is! AudioCuePlaybackChannel) {
      captureAction?.retire();
      _emit(const AudioSetupFailed('playback_unavailable'));
      return;
    }
    // Production's MethodChannel has no unclaimed start path. Fake sources
    // remain usable in isolated signal and controller tests.
    if (_channel is MethodChannelAudioCaptureChannel && captureAction == null) {
      _emit(const AudioSetupFailed('capture_context_required'));
      return;
    }
    if (_audioCandidate != null && !identical(_audioCandidate, this)) {
      captureAction?.retire();
      _emit(const AudioSetupFailed('capture_owner_busy'));
      return;
    }
    if (_audioCloseLatch != null) {
      captureAction?.retire();
      _emit(const AudioSetupFailed('capture_close_unconfirmed'));
      return;
    }
    final previous = _audioOwner;
    if (captureAction != null &&
        !captureAction.attachCancellation(() {
          unawaited(_stop(announce: false).catchError((Object _) {}));
        })) {
      _emit(const AudioSetupFailed('capture_context_stale'));
      return;
    }
    _captureAction = captureAction;
    _audioCandidate = this;
    _sessionMode = sessionMode;
    final epoch = ++_epoch;
    _starting = true;
    _route = AudioRoute.unknown;
    _lifecycle = AudioLifecycleObserver(
      onBackground: () => _stopAfterLifecycle(),
      onInactive: () {
        if (_running || (_starting && !_askingPermission)) {
          _stopAfterLifecycle();
        }
      },
      onResumed: () {
        final pending = _foregroundReady;
        if (pending != null && !pending.isCompleted) pending.complete(true);
      },
    )..attach();
    _emit(const AudioStarting());
    try {
      if (previous != null && !identical(previous, this)) {
        await previous.stop();
      }
      await awaitPendingAudioClose();
      if (!_current(epoch)) return;
      if (_audioCloseLatch != null) {
        throw PlatformException(code: 'capture_close_unconfirmed');
      }
      final nativeState = await refreshCloseState();
      if (!nativeState.isClear ||
          _audioCloseLatch != null ||
          !_current(epoch)) {
        throw PlatformException(code: 'capture_close_unconfirmed');
      }
      if (captureAction != null) {
        if (!captureAction.isCurrent ||
            !await captureAction.confirmPreflight() ||
            !captureAction.isCurrent) {
          throw PlatformException(code: 'capture_context_stale');
        }
      }
      _askingPermission = true;
      final perm = await _requestPermission();
      _askingPermission = false;
      if (!_current(epoch)) return;
      if (captureAction != null && !captureAction.isCurrent) {
        throw PlatformException(code: 'capture_context_stale');
      }
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
      if (captureAction != null && !captureAction.isCurrent) {
        throw PlatformException(code: 'capture_context_stale');
      }
      _channelConnected = true;
      _sub = _channel.events.listen(
        _onRawEvent,
        onError: (Object _) =>
            _failCapture('capture_stream_failed', expectedEpoch: epoch),
        onDone: () =>
            _failCapture('capture_stream_ended', expectedEpoch: epoch),
      );
      final channel = _channel;
      if (channel is PreparedAudioCaptureChannel) {
        await _boundedNative(
          (channel as PreparedAudioCaptureChannel).prepare(),
        );
      }
      if (!_current(epoch) || _audioCloseLatch != null) return;
      if (captureAction != null && !captureAction.isCurrent) {
        throw PlatformException(code: 'capture_context_stale');
      }
      // This synchronous guard is the only point where the new capture owner
      // is claimed. A prior owner's confirmed close is required above.
      if (_audioOwner != null && !identical(_audioOwner, this)) {
        throw PlatformException(code: 'capture_owner_busy');
      }
      _audioOwner = this;
      _audioCandidate = null;
      final nativeStart = sessionMode == AudioSessionMode.playAndRecord
          ? (channel as AudioCuePlaybackChannel).startPlayAndRecord(
              sampleRate: sampleRate,
              claim: captureAction?.claim,
            )
          : channel is MethodChannelAudioCaptureChannel
          ? channel.start(sampleRate: sampleRate, claim: captureAction?.claim)
          : channel.start(sampleRate: sampleRate);
      await _boundedNative(nativeStart);
      if (!_current(epoch)) return;
      if (captureAction != null && !captureAction.isCurrent) {
        throw PlatformException(code: 'capture_context_stale');
      }
      _running = true;
      _starting = false;
      _resetPcmDeliveryDeadline(epoch);
      _emit(AudioCalibrating(_route));
    } on PlatformException catch (e) {
      if (_current(epoch)) _emit(_mapPlatformException(e));
      try {
        await _stop(announce: false);
      } on Object {
        _emit(const AudioSetupFailed('capture_close_unconfirmed'));
      }
    } on Object {
      if (_current(epoch)) {
        _emit(const AudioSetupFailed('capture_start_failed'));
      }
      try {
        await _stop(announce: false);
      } on Object {
        _emit(const AudioSetupFailed('capture_close_unconfirmed'));
      }
    }
  }

  void _stopAfterLifecycle({bool announce = true}) {
    unawaited(_stop(announce: announce).catchError((Object _) {}));
  }

  void _failCapture(String reason, {int? expectedEpoch}) {
    if (_disposed ||
        !(_running || _starting) ||
        (expectedEpoch != null && !_current(expectedEpoch))) {
      return;
    }
    _emit(AudioSetupFailed(reason));
    _stopAfterLifecycle(announce: false);
  }

  void _resetPcmDeliveryDeadline(int epoch) {
    _pcmDeliveryTimer?.cancel();
    _pcmDeliveryTimer = Timer(_pcmDeliveryTimeout, () {
      _pcmDeliveryTimer = null;
      if (!_current(epoch) || !_running) return;
      _failCapture('capture_pcm_timeout', expectedEpoch: epoch);
    });
  }

  void _onRawEvent(RawAudioEvent event) {
    if (_disposed || !(_running || _starting)) return;
    switch (event) {
      case RawAudioChunkEvent(
        :final samples,
        :final sampleRate,
        :final tNativeUs,
        :final playbackActive,
      ):
        if (!_running) return;
        if (sampleRate <= 0 ||
            samples.isEmpty ||
            samples.any((v) => !v.isFinite || v.abs() > 1.0)) {
          _emit(const AudioSetupFailed('invalid_pcm'));
          _stopAfterLifecycle(announce: false);
          return;
        }
        final continuity = _continuity.observe(
          startUs: tNativeUs,
          sampleRate: sampleRate,
          sampleCount: samples.length,
        );
        if (continuity == AudioContinuityResult.invalid) {
          _emit(const AudioSetupFailed('invalid_audio_clock'));
          _stopAfterLifecycle(announce: false);
          return;
        }
        _resetPcmDeliveryDeadline(_epoch);
        if (continuity == AudioContinuityResult.recalibrate) {
          _ring.clear();
          _emit(AudioCalibrating(_route));
        }
        _ring.push(samples);
        _chunks.add(
          AudioChunk(
            samples: samples,
            sampleRate: sampleRate,
            tStartUs: tNativeUs,
            clockDomain: AudioClockDomain.monotonic,
            // A record-only attempt never plays; ignore a stray native flag.
            playbackActive:
                _sessionMode == AudioSessionMode.playAndRecord &&
                playbackActive,
          ),
        );
      case RawRouteChangedEvent(:final platformRouteTag):
        _route = mapPlatformRouteTag(platformRouteTag);
        _continuity.reset();
        _ring.clear();
        if (_running) _emit(AudioCalibrating(_route));
      case RawInterruptedEvent(:final reason):
        _failCapture(reason);
      case RawMetronomeAnchorEvent(
        :final anchorUs,
        :final sampleRate,
        :final framesPerBeat,
        :final outputLatencyUs,
      ):
        if (!_running || _sessionMode != AudioSessionMode.playAndRecord) {
          return;
        }
        _anchors.add(
          MetronomeAnchor(
            anchorUs: anchorUs,
            sampleRate: sampleRate,
            framesPerBeat: framesPerBeat,
            outputLatencyUs: outputLatencyUs,
          ),
        );
    }
  }

  /// F2.1: plays one short mono cue inside the running play+record attempt.
  /// A cue failure is reported to the caller only; it never stops capture
  /// (a missing click must not end the learner's practice measurement).
  /// Throws [PlatformException] with `playback_not_enabled` (record-only
  /// attempt), `playback_unavailable` (not running), `bad_args`, or the
  /// native code.
  Future<void> playCue(Float64List samples, {required int sampleRate}) async {
    if (_disposed || !_running) {
      throw PlatformException(code: 'playback_unavailable');
    }
    if (_sessionMode != AudioSessionMode.playAndRecord) {
      throw PlatformException(code: 'playback_not_enabled');
    }
    if (!isValidCuePcm(samples, sampleRate)) {
      throw PlatformException(code: 'bad_args');
    }
    final channel = _channel as AudioCuePlaybackChannel;
    try {
      await channel
          .playCue(samples, sampleRate: sampleRate)
          .timeout(_nativeCallTimeout);
    } on TimeoutException {
      throw PlatformException(code: 'playback_failed');
    }
  }

  /// F2.2: starts (or replaces) the click stream inside the running
  /// play+record attempt. Same guards as [playCue]; a failure never stops
  /// capture. The anchor arrives on [metronomeAnchors].
  Future<void> startMetronome(MetronomeStreamRequest request) async {
    if (_disposed || !_running) {
      throw PlatformException(code: 'playback_unavailable');
    }
    if (_sessionMode != AudioSessionMode.playAndRecord) {
      throw PlatformException(code: 'playback_not_enabled');
    }
    final channel = _channel;
    if (channel is! AudioMetronomeChannel) {
      throw PlatformException(code: 'playback_unavailable');
    }
    if (!request.isValid) throw PlatformException(code: 'bad_args');
    try {
      await (channel as AudioMetronomeChannel)
          .startMetronome(request)
          .timeout(_nativeCallTimeout);
    } on TimeoutException {
      throw PlatformException(code: 'playback_failed');
    }
  }

  /// Stops the click stream; capture keeps running. No-op when idle.
  Future<void> stopMetronome() async {
    final channel = _channel;
    if (_disposed || !_running || channel is! AudioMetronomeChannel) return;
    try {
      await (channel as AudioMetronomeChannel).stopMetronome().timeout(
        _nativeCallTimeout,
      );
    } on Object {
      // Closing capture stops the stream anyway.
    }
  }

  /// F2.2: click-stream anchors of the current attempt.
  Stream<MetronomeAnchor> get metronomeAnchors => _anchors.stream;

  @override
  Future<void> stop() => _stop(announce: true);

  Future<void> _stop({required bool announce}) {
    final pending = _stopInFlight;
    if (pending != null) return pending;
    final next = _performStop(announce: announce);
    _stopInFlight = next;
    unawaited(
      next
          .whenComplete(() {
            if (identical(_stopInFlight, next)) _stopInFlight = null;
          })
          .catchError((Object _) {}),
    );
    return next;
  }

  Future<void> _performStop({required bool announce}) async {
    final stoppedEpoch = ++_epoch;
    _pcmDeliveryTimer?.cancel();
    _pcmDeliveryTimer = null;
    _captureAction?.retire();
    _captureAction = null;
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
    _continuity.reset();
    // Keep the old owner and an explicit-retry handle before any await. Native
    // stop is invoked directly, outside the start/prepare logical wait.
    _AudioCloseLatch? latch;
    Future<void>? nativeClose;
    if (hadConnection) {
      final channel = _channel;
      latch = _AudioCloseLatch(
        channel,
        channel is AudioCaptureCloseControl
            ? (channel as AudioCaptureCloseControl).attemptId
            : null,
        pendingNativeCall: _nativeCallPending,
      );
      _audioCloseLatch = latch;
      _closeState = const AudioCaptureCloseState.unknown();
      _closeReadbackAfterLatch = false;
      nativeClose = Future<void>.sync(channel.stop).timeout(_nativeCallTimeout);
      _closingAudio = nativeClose;
    }
    Object? failure;
    try {
      await nativeClose;
    } on Object catch (error) {
      failure = error;
    }
    try {
      await subscription?.cancel().timeout(_nativeCallTimeout);
    } on Object catch (error) {
      failure ??= error;
    }
    if (identical(_closingAudio, nativeClose)) _closingAudio = null;
    if (stoppedEpoch != _epoch) return;
    if (failure == null && latch != null && !latch.pendingNativeCall) {
      final control = _channel;
      if (control is AudioCaptureCloseControl) {
        final state = await refreshCloseState();
        if (latch.attemptId == null ||
            !state.confirmsClearAfterStop(latch.attemptId!)) {
          failure = PlatformException(code: 'capture_close_unconfirmed');
        }
      }
    }
    if (latch != null &&
        (failure != null ||
            latch.pendingNativeCall ||
            latch.requiresExplicitRetry)) {
      _emit(const AudioSetupFailed('capture_close_unconfirmed'));
      throw PlatformException(code: 'capture_close_unconfirmed');
    }
    if (latch == null && _audioCloseLatch != null) {
      _emit(const AudioSetupFailed('capture_close_unconfirmed'));
      throw PlatformException(code: 'capture_close_unconfirmed');
    }
    if (identical(_audioCloseLatch, latch)) _audioCloseLatch = null;
    if (identical(_audioOwner, this) && _audioCloseLatch == null) {
      _audioOwner = null;
    }
    if (identical(_audioCandidate, this)) _audioCandidate = null;
    if (announce) _emit(const AudioStopped());
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _suspendPendingCloseReadbacks();
    try {
      await _stop(announce: false);
    } on Object {
      // The process close latch survives this controller and can be retried
      // explicitly by a later screen. Dispose must still close Dart streams.
    } finally {
      await _chunks.close();
      await _status.close();
      await _anchors.close();
    }
  }
}

/// F2.2: where the click stream's frame 0 sits on the capture clock.
final class MetronomeAnchor {
  const MetronomeAnchor({
    required this.anchorUs,
    required this.sampleRate,
    required this.framesPerBeat,
    this.outputLatencyUs = 0,
  });
  final int anchorUs;
  final int sampleRate;
  final int framesPerBeat;
  final int outputLatencyUs;
}
