import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/services.dart';

import 'native_audio_state.dart';

/// The exact native process context observed at the user's capture action.
/// A later read must never replace these fields after a fence.
final class AudioCaptureContextClaim {
  const AudioCaptureContextClaim({
    required this.ownerToken,
    required this.engineGeneration,
    required this.contextGeneration,
  });

  final String ownerToken;
  final int engineGeneration;
  final int contextGeneration;

  bool get isValid =>
      isNativeAudioToken(ownerToken) &&
      engineGeneration >= 1 &&
      contextGeneration >= 0;

  Map<String, Object> get wireFields => <String, Object>{
    'ownerToken': ownerToken,
    'engineGeneration': engineGeneration,
    'contextGeneration': contextGeneration,
  };
}

/// F2.1 — bir yakalama denemesinin ses oturumu modu. Deneme boyunca SABİT.
///
/// - [recordOnly]: eski davranış (nota gözlemi, akort kapısı). Tel biçimi
///   birebir aynı kalır: `start` çağrısına `sessionMode` anahtarı EKLENMEZ.
/// - [playAndRecord]: pratik ekranı. Aynı native deneme mikrofonu dinlerken
///   kısa ipuçları (klik/test tonu; ileride metronom ve referans ses) çalabilir.
///   Çalma, girdi kirasının İÇİNDEDİR: ayrı sahibi yoktur, yakalama kapanınca
///   (durdurma, arka plan, rota değişimi, kesinti, motor değişimi) o da kapanır.
enum AudioSessionMode { recordOnly, playAndRecord }

/// Tek bir ipucunun üst sınırı; daha uzunu kuyruğa alınmaz, reddedilir.
const int kMaxCueSeconds = 2;

/// Bir ipucu PCM'inin native'e gönderilmeden önceki biçim denetimi.
bool isValidCuePcm(List<double> samples, int sampleRate) =>
    (sampleRate == 44100 || sampleRate == 48000) &&
    samples.isNotEmpty &&
    samples.length <= sampleRate * kMaxCueSeconds &&
    samples.every((v) => v.isFinite && v.abs() <= 1.0);

/// Çal + dinle yeteneği olan kanal. [AudioCaptureChannel] arayüzü bilerek
/// değiştirilmedi (yalnız-kayıt uygulamaları etkilenmesin).
abstract interface class AudioCuePlaybackChannel {
  /// [AudioSessionMode.playAndRecord] modunda yakalamayı başlatır.
  Future<void> startPlayAndRecord({
    required int sampleRate,
    AudioCaptureContextClaim? claim,
  });

  /// Çalışan çal+dinle denemesinin İÇİNDE mono PCM çalar. [sampleRate],
  /// başlatmada istenen hızla aynı olmalı. Hata kodları:
  /// `playback_not_enabled` (yalnız-kayıt denemesi), `playback_unavailable`
  /// (çalışan deneme yok / kapanıyor), `unsupported_sample_rate`, `bad_args`,
  /// `playback_failed`.
  Future<void> playCue(Float64List samples, {required int sampleRate});
}

/// F2.2: one continuous click stream inside the running play+record attempt.
/// Beat `n` is output frame `n * framesPerBeat` of the stream (reference:
/// `lib/app/practice/loop/metronome.dart`). Like cues, it has no owner of its
/// own: every path that closes capture also stops the stream.
final class MetronomeStreamRequest {
  MetronomeStreamRequest({
    required this.sampleRate,
    required this.framesPerBeat,
    required this.beatsPerBar,
    required this.accent,
    required this.beat,
    this.leadInMs = 150,
  });

  final int sampleRate;
  final int framesPerBeat;
  final int beatsPerBar;
  final Float64List accent;
  final Float64List beat;

  /// Delay before frame 0, so the stream can be anchored at a known time.
  final int leadInMs;

  bool get isValid {
    bool click(Float64List c) =>
        c.isNotEmpty &&
        c.length < framesPerBeat &&
        c.every((v) => v.isFinite && v.abs() <= 1.0);
    return (sampleRate == 44100 || sampleRate == 48000) &&
        framesPerBeat >= sampleRate * 60 ~/ 300 &&
        framesPerBeat <= sampleRate * 60 ~/ 20 &&
        beatsPerBar >= 1 &&
        beatsPerBar <= 12 &&
        leadInMs >= 0 &&
        leadInMs <= 2000 &&
        click(accent) &&
        click(beat);
  }

  Map<String, Object?> wireFields() => <String, Object?>{
    'sampleRate': sampleRate,
    'framesPerBeat': framesPerBeat,
    'beatsPerBar': beatsPerBar,
    'accent': accent,
    'beat': beat,
    'leadInMs': leadInMs,
  };
}

/// Optional metronome capability of a play+record channel. Error codes are
/// the cue codes (`playback_not_enabled`, `playback_unavailable`,
/// `unsupported_sample_rate`, `bad_args`, `playback_failed`). The anchor
/// arrives later as a [RawMetronomeAnchorEvent].
abstract interface class AudioMetronomeChannel {
  Future<void> startMetronome(MetronomeStreamRequest request);
  Future<void> stopMetronome();
}

/// Native yakalama katmanının HAM olayı — henüz [AudioRoute]e çözülmemiş
/// (bkz. `audio_route_state.dart`), henüz tampon/izin/yaşam-döngüsü mantığı
/// uygulanmamış. Bu ayrım `motion_camera.CameraFrameEnvelope` ile
/// `ostinato_posture.CameraPostureAdapter` arasındaki sınırla AYNI gerekçe:
/// platform kanalının verdiği ham şekil ile Ostinato'nun hüküm katmanı
/// karışmasın.
sealed class RawAudioEvent {
  const RawAudioEvent();
}

/// Bir yakalama parçası, NATIVE saatinde damgalı (Dart tarafı henüz
/// dokunmadı — `AudioInputController` bunu `AudioChunk`e çevirirken
/// `AudioClockDomain.monotonic` etiketini KENDİSİ ekler, çünkü bu etiketin
/// anlamı "hangi native API kullanıldığı" bilgisine bağlı, kanal formatına
/// değil).
final class RawAudioChunkEvent extends RawAudioEvent {
  const RawAudioChunkEvent({
    required this.samples,
    required this.sampleRate,
    required this.tNativeUs,
    this.playbackActive = false,
  });
  final List<double> samples;
  final int sampleRate;
  final int tNativeUs;

  /// Yalnız çal+dinle denemesinde native'in gönderdiği bayrak: bu pencerede
  /// uygulama çıkışı duyulabilirdi (bkz. `AudioChunk.playbackActive`).
  final bool playbackActive;
}

/// Route değişti — [platformRouteTag] HAM platform adı (`audio_route_state.
/// dart`taki `mapIosPortType`/`mapAndroidDeviceType`e girecek girdi),
/// buradaki katman onu YORUMLAMAZ.
final class RawRouteChangedEvent extends RawAudioEvent {
  const RawRouteChangedEvent(this.platformRouteTag);
  final String platformRouteTag;
}

/// F2.2: the click stream's frame 0 was (or will be) presented at
/// [anchorUs] on the same native clock as chunk `tNativeUs`.
/// [outputLatencyUs] is any native output-latency estimate NOT already
/// included in [anchorUs] (iOS: `AVAudioSession.outputLatency`; Android
/// timestamps are presentation times, so 0).
final class RawMetronomeAnchorEvent extends RawAudioEvent {
  const RawMetronomeAnchorEvent({
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

/// Akış native tarafından kesildi (telefon çağrısı, başka bir app mic'i
/// aldı, vb.) — [reason] İSİMLİ platform sebebi.
final class RawInterruptedEvent extends RawAudioEvent {
  const RawInterruptedEvent(this.reason);
  final String reason;
}

/// Platform kanalının İNCE sarmalayıcısı — `motion_camera.
/// MotionCameraController`ın ses karşılığı: yalnız native ile konuşur,
/// hiçbir izin/tampon/route-yorumlama HÜKMÜ taşımaz. Testte
/// [FakeAudioCaptureChannel] yerini alır — `AudioInputController`
/// donanımsız sınanabilsin diye (`ostinato_posture.PoseSource` ile aynı
/// gerekçe, bir kat aşağıda).
abstract interface class AudioCaptureChannel {
  Stream<RawAudioEvent> get events;

  /// Requests a supported preferred rate (44.1 or 48 kHz). Hardware can
  /// choose the other supported rate; every chunk carries the actual rate.
  /// Unsupported requested/actual formats fail closed, rather than interpreting
  /// PCM with a guessed sample rate. The observation recalibrates on change.
  Future<void> start({required int sampleRate});

  Future<void> stop();
}

/// Optional readiness handshake, separated from capture so an owner can
/// recheck cancellation after event subscription preparation completes.
abstract interface class PreparedAudioCaptureChannel {
  Future<void> prepare();
}

enum AudioCaptureClosePhase {
  clear,
  starting,
  running,
  closing,
  unconfirmedInFlight,
  unconfirmedQuiescent,
  releasedAwaitingExplicitRetry,
  unknown,
}

/// A native API snapshot is evidence about the coordinator, not about the OS
/// privacy indicator. Missing or malformed replies stay unknown.
final class AudioCaptureCloseState {
  const AudioCaptureCloseState({
    required this.phase,
    required this.attemptId,
    required this.attemptInFlight,
    required this.resourcesReleased,
    required this.requiresExplicitRetry,
  });

  const AudioCaptureCloseState.unknown()
    : phase = AudioCaptureClosePhase.unknown,
      attemptId = null,
      attemptInFlight = false,
      resourcesReleased = false,
      requiresExplicitRetry = false;

  const AudioCaptureCloseState.clear()
    : phase = AudioCaptureClosePhase.clear,
      attemptId = null,
      attemptInFlight = false,
      resourcesReleased = true,
      requiresExplicitRetry = false;

  final AudioCaptureClosePhase phase;
  final String? attemptId;
  final bool attemptInFlight;
  final bool resourcesReleased;
  final bool requiresExplicitRetry;

  bool get isClear =>
      phase == AudioCaptureClosePhase.clear &&
      !attemptInFlight &&
      resourcesReleased &&
      !requiresExplicitRetry;

  bool confirmsClearAfterStop(String id) =>
      isClear && (attemptId == null || attemptId == id);

  bool get canRetry =>
      !attemptInFlight &&
      (phase == AudioCaptureClosePhase.running ||
          (requiresExplicitRetry &&
              (phase == AudioCaptureClosePhase.unconfirmedQuiescent ||
                  phase ==
                      AudioCaptureClosePhase.releasedAwaitingExplicitRetry)));

  static AudioCaptureCloseState fromMessage(Object? message) {
    if (message is! Map) return const AudioCaptureCloseState.unknown();
    final phaseName = message['phase'];
    final inFlight = message['attemptInFlight'];
    final released = message['resourcesReleased'];
    final retry = message['requiresExplicitRetry'];
    final id = message['attemptId'];
    if (phaseName is! String ||
        inFlight is! bool ||
        released is! bool ||
        retry is! bool ||
        (id != null && (id is! String || id.isEmpty))) {
      return const AudioCaptureCloseState.unknown();
    }
    final phase = AudioCaptureClosePhase.values
        .where((value) => value.name == phaseName)
        .firstOrNull;
    if (phase == null || phase == AudioCaptureClosePhase.unknown) {
      return const AudioCaptureCloseState.unknown();
    }
    if (phase == AudioCaptureClosePhase.clear &&
        (inFlight || !released || retry)) {
      return const AudioCaptureCloseState.unknown();
    }
    if (phase != AudioCaptureClosePhase.clear && id == null) {
      return const AudioCaptureCloseState.unknown();
    }
    if (switch (phase) {
      AudioCaptureClosePhase.starting ||
      AudioCaptureClosePhase.closing ||
      AudioCaptureClosePhase.unconfirmedInFlight => !inFlight || released,
      AudioCaptureClosePhase.running => inFlight || released || retry,
      AudioCaptureClosePhase.unconfirmedQuiescent =>
        inFlight || released || !retry,
      AudioCaptureClosePhase.releasedAwaitingExplicitRetry =>
        inFlight || !released || !retry,
      AudioCaptureClosePhase.clear || AudioCaptureClosePhase.unknown => false,
    }) {
      return const AudioCaptureCloseState.unknown();
    }
    return AudioCaptureCloseState(
      phase: phase,
      attemptId: id as String?,
      attemptInFlight: inFlight,
      resourcesReleased: released,
      requiresExplicitRetry: retry,
    );
  }
}

abstract interface class AudioCaptureCloseControl {
  String? get attemptId;
  Future<AudioCaptureCloseState> readCloseState();

  /// Ordinary/lifecycle close. It never acknowledges a sticky late release.
  Future<void> stopAttempt(String attemptId);

  /// Only the visible user retry action may send this distinct native method.
  Future<void> retryStopAttempt(String attemptId);
}

/// Cancels only pending status reads when their owning UI is disposed.
/// It never acknowledges a native close or clears a capture attempt.
abstract interface class AudioCaptureReadbackCancellation {
  void cancelPendingCloseReadbacks();

  /// A disposed owner can still dispatch stop, but must not create another
  /// status deadline afterward. Only a later explicit close retry resumes it.
  void suspendCloseReadbacksUntilExplicitRetry();
}

/// Üretim yolu — `com.yulalab.ostinato/audio_capture` (method) +
/// `com.yulalab.ostinato/audio_capture/events` (event) kanallarını sarar.
///
/// **Kanıt sınıfı DÜRÜST** (`CameraPoseSource` dosya-başı notuyla AYNI
/// disiplin): bu sınıf yalnız kanal PLUMBING'ini kanıtlar — simülatörde/
/// widget testinde native taraf ya YOK ya da gerçek ses donanımına
/// erişmiyor. Bağlandı ≠ canlı; gerçek mikrofon ölçümü cihaz-günü
/// release-gate'idir (roadmap §15 MANUAL-OSTINATO-DEVICE-20260818).
final class MethodChannelAudioCaptureChannel
    implements
        AudioCaptureChannel,
        AudioCuePlaybackChannel,
        AudioMetronomeChannel,
        PreparedAudioCaptureChannel,
        AudioCaptureCloseControl,
        AudioCaptureReadbackCancellation {
  MethodChannelAudioCaptureChannel({
    Duration transportTimeout = const Duration(seconds: 3),
    EventChannel? eventChannel,
  }) : _transportTimeout = transportTimeout,
       _method = const MethodChannel('com.yulalab.ostinato/audio_capture'),
       _eventChannel =
           eventChannel ??
           const EventChannel('com.yulalab.ostinato/audio_capture/events');

  final MethodChannel _method;
  final EventChannel _eventChannel;
  final Duration _transportTimeout;

  StreamSubscription<dynamic>? _rawSub;
  Future<void>? _stopInFlight;
  String? _attemptId;
  bool _prepared = false;
  bool _acceptEvents = false;
  bool _eventTeardownPending = false;
  bool _closeBlocked = false;
  bool _closeReadbacksSuspended = false;
  final Set<void Function()> _cancelCloseReadbacks = {};
  final StreamController<RawAudioEvent> _events =
      StreamController<RawAudioEvent>.broadcast();

  @override
  Stream<RawAudioEvent> get events => _events.stream;

  @override
  String? get attemptId => _attemptId;

  String _newAttemptId() {
    final random = Random.secure();
    return List<int>.generate(
      16,
      (_) => random.nextInt(256),
    ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }

  PlatformException _unconfirmed() =>
      PlatformException(code: 'capture_close_unconfirmed');

  @override
  Future<AudioCaptureCloseState> readCloseState() {
    if (_closeReadbacksSuspended) {
      return Future<AudioCaptureCloseState>.value(
        const AudioCaptureCloseState.unknown(),
      );
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
    deadline = Timer(_transportTimeout, cancel);
    try {
      unawaited(
        _method
            .invokeMethod<Object?>('closeState')
            .then<void>(
              (reply) => finish(AudioCaptureCloseState.fromMessage(reply)),
              onError: (Object _, StackTrace stackTrace) => cancel(),
            ),
      );
    } on Object {
      cancel();
    }
    return result.future;
  }

  @override
  void cancelPendingCloseReadbacks() {
    for (final cancel in _cancelCloseReadbacks.toList()) {
      cancel();
    }
  }

  @override
  void suspendCloseReadbacksUntilExplicitRetry() {
    _closeReadbacksSuspended = true;
    cancelPendingCloseReadbacks();
  }

  @override
  Future<void> prepare() async {
    if (_eventTeardownPending || _closeBlocked) throw _unconfirmed();
    final id = _attemptId ??= _newAttemptId();
    _acceptEvents = true;
    _rawSub ??= _eventChannel
        .receiveBroadcastStream(<String, Object?>{'attemptId': id})
        .listen(_onMessage, onError: _onError, onDone: () => _onDone(id));
    // Event subscription and method calls are separate channels. Complete a
    // bounded native handshake before capture, rather than assume ordering.
    var ready = false;
    for (var attempt = 0; attempt < 20; attempt++) {
      if (!_acceptEvents || id != _attemptId) throw _unconfirmed();
      if (await _method
              .invokeMethod<bool>('ready', <String, Object?>{'attemptId': id})
              .timeout(_transportTimeout) ==
          true) {
        ready = true;
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    if (!_acceptEvents || id != _attemptId) throw _unconfirmed();
    _prepared = ready;
    if (!ready) throw PlatformException(code: 'capture_stream_not_ready');
  }

  @override
  Future<void> start({
    required int sampleRate,
    AudioCaptureContextClaim? claim,
  }) => _start(sampleRate, claim, AudioSessionMode.recordOnly);

  @override
  Future<void> startPlayAndRecord({
    required int sampleRate,
    AudioCaptureContextClaim? claim,
  }) => _start(sampleRate, claim, AudioSessionMode.playAndRecord);

  Future<void> _start(
    int sampleRate,
    AudioCaptureContextClaim? claim,
    AudioSessionMode mode,
  ) async {
    if (claim == null || !claim.isValid) {
      throw PlatformException(code: 'capture_context_required');
    }
    if (_closeBlocked) throw _unconfirmed();
    if (!_prepared) await prepare();
    final id = _attemptId;
    if (!_acceptEvents || id == null || _eventTeardownPending) {
      throw _unconfirmed();
    }
    await _method.invokeMethod<void>('start', <String, Object?>{
      'attemptId': id,
      'sampleRate': sampleRate,
      ...claim.wireFields,
      // Record-only keeps the exact legacy key set (native parsers are strict).
      if (mode == AudioSessionMode.playAndRecord)
        'sessionMode': AudioSessionMode.playAndRecord.name,
    });
  }

  @override
  Future<void> playCue(Float64List samples, {required int sampleRate}) async {
    final id = _attemptId;
    if (id == null || !_acceptEvents || _closeBlocked) {
      throw PlatformException(code: 'playback_unavailable');
    }
    if (!isValidCuePcm(samples, sampleRate)) {
      throw PlatformException(code: 'bad_args');
    }
    await _method
        .invokeMethod<void>('playCue', <String, Object?>{
          'attemptId': id,
          'samples': samples,
          'sampleRate': sampleRate,
        })
        .timeout(_transportTimeout);
  }

  @override
  Future<void> startMetronome(MetronomeStreamRequest request) async {
    final id = _attemptId;
    if (id == null || !_acceptEvents || _closeBlocked) {
      throw PlatformException(code: 'playback_unavailable');
    }
    if (!request.isValid) throw PlatformException(code: 'bad_args');
    await _method
        .invokeMethod<void>('startMetronome', <String, Object?>{
          'attemptId': id,
          ...request.wireFields(),
        })
        .timeout(_transportTimeout);
  }

  @override
  Future<void> stopMetronome() async {
    final id = _attemptId;
    if (id == null || !_acceptEvents || _closeBlocked) return;
    await _method
        .invokeMethod<void>('stopMetronome', <String, Object?>{
          'attemptId': id,
        })
        .timeout(_transportTimeout);
  }

  void _onMessage(dynamic message) {
    if (!_acceptEvents) return;
    try {
      final Map<Object?, Object?> map = message as Map<Object?, Object?>;
      if (map['attemptId'] != _attemptId) return;
      switch (map['type']) {
        case 'chunk':
          // `samples` telden `Float64List` olarak gelir (StandardMessageCodec
          // FlutterStandardTypedData.float64 ↔ Dart Float64List) — kanal
          // başına binlerce örneği tek tek `NSNumber`/`Object` kutulamak
          // yerine ham bayt kopyası. `Float64List` zaten `List<double>`
          // sözleşmesini karşılar, ayrı bir dönüşüm GEREKMEZ.
          // Absent on record-only attempts; when present it must be a bool.
          final playback = map['playbackActive'];
          if (playback != null && playback is! bool) {
            throw const FormatException('playbackActive');
          }
          _events.add(
            RawAudioChunkEvent(
              samples: map['samples']! as List<double>,
              sampleRate: map['sampleRate']! as int,
              tNativeUs: map['t']! as int,
              playbackActive: playback == true,
            ),
          );
        case 'routeChanged':
          _events.add(RawRouteChangedEvent(map['route']! as String));
        case 'interrupted':
          _events.add(RawInterruptedEvent(map['reason']! as String));
        case 'metronomeAnchor':
          _events.add(
            RawMetronomeAnchorEvent(
              anchorUs: map['anchorUs']! as int,
              sampleRate: map['sampleRate']! as int,
              framesPerBeat: map['framesPerBeat']! as int,
              outputLatencyUs: (map['outputLatencyUs'] as int?) ?? 0,
            ),
          );
      }
    } on Object {
      _events.add(const RawInterruptedEvent('invalid_capture_event'));
    }
  }

  void _onError(Object error) {
    if (!_acceptEvents) return;
    final String reason = error is PlatformException
        ? error.code
        : 'unexpected: $error';
    _events.add(RawInterruptedEvent(reason));
  }

  void _onDone(String id) {
    // An ended transport is not a native close receipt. Retain the attempt
    // for ordinary stop/readback and keep the reusable public stream open.
    // A retired subscription must not end a later capture attempt.
    if (!_acceptEvents || id != _attemptId) return;
    _acceptEvents = false;
    _prepared = false;
    _closeBlocked = true;
    _events.add(const RawInterruptedEvent('capture_stream_ended'));
  }

  @override
  Future<void> stop() async {
    final id = _attemptId;
    if (id == null) return;
    await _dispatchStop(id);
  }

  @override
  Future<void> stopAttempt(String attemptId) {
    final pending = _stopInFlight;
    if (pending != null) return pending;
    _closeReadbacksSuspended = false;
    return _dispatchStop(attemptId);
  }

  @override
  Future<void> retryStopAttempt(String id) async {
    // Keep this separate from _stopInFlight: an ordinary late stop must not
    // absorb the explicit retry intent or clear the native sticky latch.
    if (_attemptId != null && _attemptId != id) throw _unconfirmed();
    _closeReadbacksSuspended = false;
    _acceptEvents = false;
    _prepared = false;
    _closeBlocked = true;
    final nativeRetry = _method
        .invokeMethod<void>('retryStop', <String, Object?>{'attemptId': id})
        .timeout(_transportTimeout);
    final subscription = _rawSub;
    Future<bool>? streamTeardown;
    if (subscription != null && !_eventTeardownPending) {
      _eventTeardownPending = true;
      final teardown = Future<void>.sync(subscription.cancel)
          .timeout(_transportTimeout)
          .then<bool>(
            (_) => true,
            onError: (Object _, StackTrace stackTrace) => false,
          );
      streamTeardown = teardown;
      unawaited(
        teardown.then((ok) {
          if (ok && identical(_rawSub, subscription)) {
            _rawSub = null;
            _eventTeardownPending = false;
          }
        }),
      );
    }
    try {
      await nativeRetry;
      if (streamTeardown != null && !(await streamTeardown)) {
        throw _unconfirmed();
      }
      final state = await readCloseState();
      if (!state.confirmsClearAfterStop(id) || _eventTeardownPending) {
        throw _unconfirmed();
      }
      _attemptId = null;
      _closeBlocked = false;
    } on Object {
      throw _unconfirmed();
    }
  }

  Future<void> _dispatchStop(String attemptId) {
    final pending = _stopInFlight;
    if (pending != null) return pending;
    final close = _stopAttempt(attemptId);
    _stopInFlight = close;
    unawaited(
      close
          .whenComplete(() {
            if (identical(_stopInFlight, close)) _stopInFlight = null;
          })
          .catchError((Object _) {}),
    );
    return close;
  }

  Future<void> _stopAttempt(String id) async {
    // Fence Dart events synchronously, then SEND native stop before awaiting
    // stream cancellation. Flutter's EventChannel cancel is not a hardware
    // release receipt and can itself be delayed or report via FlutterError.
    _acceptEvents = false;
    _prepared = false;
    _closeBlocked = true;
    final nativeStop = _method
        .invokeMethod<void>('stop', <String, Object?>{'attemptId': id})
        .timeout(_transportTimeout);
    final subscription = _rawSub;
    _eventTeardownPending = subscription != null;
    // Observe a fast cancel error as soon as cancellation starts. Awaiting the
    // native stop first is necessary for the close receipt, but attaching the
    // cancel error handler only afterward would leak that error into the zone.
    final streamTeardown = subscription == null
        ? Future<bool>.value(true)
        : Future<void>.sync(subscription.cancel)
              .timeout(_transportTimeout)
              .then<bool>(
                (_) => true,
                onError: (Object _, StackTrace stackTrace) => false,
              );
    unawaited(
      streamTeardown.then((ok) {
        if (ok && identical(_rawSub, subscription)) {
          _rawSub = null;
          _eventTeardownPending = false;
        }
      }),
    );
    Object? failure;
    try {
      await nativeStop;
    } on Object catch (error) {
      failure = error;
    }
    try {
      if (await streamTeardown) {
        if (identical(_rawSub, subscription)) _rawSub = null;
        _eventTeardownPending = false;
      } else {
        failure ??= _unconfirmed();
      }
    } on Object {
      failure ??= _unconfirmed();
    }
    final state = await readCloseState();
    if (failure != null ||
        !state.confirmsClearAfterStop(id) ||
        _eventTeardownPending) {
      throw _unconfirmed();
    }
    _attemptId = null;
    _closeBlocked = false;
  }
}

/// Testlerin ve sim-kanıtının kaynağı: gerçek platform kanalı YOK, olaylar
/// elle tetiklenir. `ostinato_posture.FakePoseSource` ile aynı disiplin.
final class FakeAudioCaptureChannel
    implements
        AudioCaptureChannel,
        AudioCuePlaybackChannel,
        AudioMetronomeChannel,
        AudioCaptureCloseControl {
  FakeAudioCaptureChannel({
    this.supportedSampleRates = const <int>{44100, 48000},
  });

  final Set<int> supportedSampleRates;

  final StreamController<RawAudioEvent> _events =
      StreamController<RawAudioEvent>.broadcast();
  bool _running = false;
  String? _attemptId;
  String? _lastClosedAttemptId;
  int _nextAttempt = 0;
  int _startedRate = 0;
  AudioSessionMode? _sessionMode;

  /// Son başlatılan denemenin modu (`null`: hiç başlatılmadı).
  AudioSessionMode? get sessionMode => _sessionMode;

  /// Çalınan ipuçları (test gözlemi).
  final List<Float64List> playedCues = <Float64List>[];

  /// `true` ise bir sonraki `playCue` `playback_failed` ile düşer.
  bool failNextCue = false;

  @override
  String? get attemptId => _attemptId;

  @override
  Future<AudioCaptureCloseState> readCloseState() async => _running
      ? AudioCaptureCloseState(
          phase: AudioCaptureClosePhase.running,
          attemptId: _attemptId,
          attemptInFlight: false,
          resourcesReleased: false,
          requiresExplicitRetry: false,
        )
      : const AudioCaptureCloseState.clear();

  @override
  Stream<RawAudioEvent> get events => _events.stream;

  bool get isRunning => _running;

  @override
  Future<void> start({required int sampleRate}) =>
      _start(sampleRate, AudioSessionMode.recordOnly);

  @override
  Future<void> startPlayAndRecord({
    required int sampleRate,
    AudioCaptureContextClaim? claim,
  }) => _start(sampleRate, AudioSessionMode.playAndRecord);

  Future<void> _start(int sampleRate, AudioSessionMode mode) async {
    _attemptId = 'fake-${++_nextAttempt}';
    _sessionMode = mode;
    if (!supportedSampleRates.contains(sampleRate)) {
      throw PlatformException(
        code: 'unsupported_sample_rate',
        message: '$sampleRate',
      );
    }
    _startedRate = sampleRate;
    _running = true;
  }

  @override
  Future<void> playCue(Float64List samples, {required int sampleRate}) async {
    if (!_running) throw PlatformException(code: 'playback_unavailable');
    if (_sessionMode != AudioSessionMode.playAndRecord) {
      throw PlatformException(code: 'playback_not_enabled');
    }
    if (sampleRate != _startedRate) {
      throw PlatformException(code: 'unsupported_sample_rate');
    }
    if (!isValidCuePcm(samples, sampleRate)) {
      throw PlatformException(code: 'bad_args');
    }
    if (failNextCue) {
      failNextCue = false;
      throw PlatformException(code: 'playback_failed');
    }
    playedCues.add(Float64List.fromList(samples));
  }

  /// F2.2: the running click stream request (null = no stream).
  MetronomeStreamRequest? metronome;

  /// `true` ise bir sonraki `startMetronome` `playback_failed` ile düşer.
  bool failNextMetronome = false;

  @override
  Future<void> startMetronome(MetronomeStreamRequest request) async {
    if (!_running) throw PlatformException(code: 'playback_unavailable');
    if (_sessionMode != AudioSessionMode.playAndRecord) {
      throw PlatformException(code: 'playback_not_enabled');
    }
    if (request.sampleRate != _startedRate) {
      throw PlatformException(code: 'unsupported_sample_rate');
    }
    if (!request.isValid) throw PlatformException(code: 'bad_args');
    if (failNextMetronome) {
      failNextMetronome = false;
      throw PlatformException(code: 'playback_failed');
    }
    metronome = request;
  }

  @override
  Future<void> stopMetronome() async {
    metronome = null;
  }

  /// Simulates the native anchor report for the running stream.
  void pushMetronomeAnchor(int anchorUs, {int outputLatencyUs = 0}) {
    final m = metronome;
    if (!_running || m == null) return;
    _events.add(
      RawMetronomeAnchorEvent(
        anchorUs: anchorUs,
        sampleRate: m.sampleRate,
        framesPerBeat: m.framesPerBeat,
        outputLatencyUs: outputLatencyUs,
      ),
    );
  }

  /// Testte tek parça itmek için — `FakePoseSource.pushOne()` deseni.
  void pushChunk(
    List<double> samples, {
    required int sampleRate,
    required int tNativeUs,
    bool playbackActive = false,
  }) {
    if (!_running) return;
    _events.add(
      RawAudioChunkEvent(
        samples: samples,
        sampleRate: sampleRate,
        tNativeUs: tNativeUs,
        playbackActive: playbackActive,
      ),
    );
  }

  void pushRouteChange(String platformRouteTag) {
    if (!_running) return;
    _events.add(RawRouteChangedEvent(platformRouteTag));
  }

  void pushInterruption(String reason) {
    if (!_running) return;
    _events.add(RawInterruptedEvent(reason));
  }

  @override
  Future<void> stop() async {
    _running = false;
    metronome = null;
    _lastClosedAttemptId = _attemptId ?? _lastClosedAttemptId;
    _attemptId = null;
  }

  @override
  Future<void> stopAttempt(String id) async {
    if (_attemptId != id && _lastClosedAttemptId != id) {
      throw PlatformException(code: 'stale_capture_attempt');
    }
    await stop();
  }

  @override
  Future<void> retryStopAttempt(String id) => stopAttempt(id);

  Future<void> dispose() async {
    await _events.close();
  }
}
