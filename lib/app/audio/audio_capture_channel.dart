import 'dart:async';

import 'package:flutter/services.dart';

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
  });
  final List<double> samples;
  final int sampleRate;
  final int tNativeUs;
}

/// Route değişti — [platformRouteTag] HAM platform adı (`audio_route_state.
/// dart`taki `mapIosPortType`/`mapAndroidDeviceType`e girecek girdi),
/// buradaki katman onu YORUMLAMAZ.
final class RawRouteChangedEvent extends RawAudioEvent {
  const RawRouteChangedEvent(this.platformRouteTag);
  final String platformRouteTag;
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

/// Üretim yolu — `com.yulalab.ostinato/audio_capture` (method) +
/// `com.yulalab.ostinato/audio_capture/events` (event) kanallarını sarar.
///
/// **Kanıt sınıfı DÜRÜST** (`CameraPoseSource` dosya-başı notuyla AYNI
/// disiplin): bu sınıf yalnız kanal PLUMBING'ini kanıtlar — simülatörde/
/// widget testinde native taraf ya YOK ya da gerçek ses donanımına
/// erişmiyor. Bağlandı ≠ canlı; gerçek mikrofon ölçümü cihaz-günü
/// release-gate'idir (roadmap §15 MANUAL-OSTINATO-DEVICE-20260818).
final class MethodChannelAudioCaptureChannel
    implements AudioCaptureChannel, PreparedAudioCaptureChannel {
  MethodChannelAudioCaptureChannel()
    : _method = const MethodChannel('com.yulalab.ostinato/audio_capture'),
      _eventChannel = const EventChannel(
        'com.yulalab.ostinato/audio_capture/events',
      );

  final MethodChannel _method;
  final EventChannel _eventChannel;

  StreamSubscription<dynamic>? _rawSub;
  bool _prepared = false;
  final StreamController<RawAudioEvent> _events =
      StreamController<RawAudioEvent>.broadcast();

  @override
  Stream<RawAudioEvent> get events => _events.stream;

  @override
  Future<void> prepare() async {
    _rawSub ??= _eventChannel.receiveBroadcastStream().listen(
      _onMessage,
      onError: _onError,
    );
    // Event subscription and method calls are separate channels. Complete a
    // bounded native handshake before capture, rather than assume ordering.
    var ready = false;
    for (var attempt = 0; attempt < 20; attempt++) {
      if (await _method.invokeMethod<bool>('ready') == true) {
        ready = true;
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    _prepared = ready;
    if (!ready) throw PlatformException(code: 'capture_stream_not_ready');
  }

  @override
  Future<void> start({required int sampleRate}) async {
    if (!_prepared) await prepare();
    await _method.invokeMethod<void>('start', <String, Object?>{
      'sampleRate': sampleRate,
    });
  }

  void _onMessage(dynamic message) {
    try {
      final Map<Object?, Object?> map = message as Map<Object?, Object?>;
      switch (map['type']) {
        case 'chunk':
          // `samples` telden `Float64List` olarak gelir (StandardMessageCodec
          // FlutterStandardTypedData.float64 ↔ Dart Float64List) — kanal
          // başına binlerce örneği tek tek `NSNumber`/`Object` kutulamak
          // yerine ham bayt kopyası. `Float64List` zaten `List<double>`
          // sözleşmesini karşılar, ayrı bir dönüşüm GEREKMEZ.
          _events.add(
            RawAudioChunkEvent(
              samples: map['samples']! as List<double>,
              sampleRate: map['sampleRate']! as int,
              tNativeUs: map['t']! as int,
            ),
          );
        case 'routeChanged':
          _events.add(RawRouteChangedEvent(map['route']! as String));
        case 'interrupted':
          _events.add(RawInterruptedEvent(map['reason']! as String));
      }
    } on Object {
      _events.add(const RawInterruptedEvent('invalid_capture_event'));
    }
  }

  void _onError(Object error) {
    final String reason = error is PlatformException
        ? error.code
        : 'unexpected: $error';
    _events.add(RawInterruptedEvent(reason));
  }

  @override
  Future<void> stop() async {
    await _rawSub?.cancel();
    _rawSub = null;
    _prepared = false;
    try {
      await _method.invokeMethod<void>('stop');
    } on Object {
      // Durdurmada arıza kullanıcıyı ilgilendirmez — oturum zaten bitiyor
      // (camera_pose_source.dart `stop()` ile aynı desen).
    }
  }
}

/// Testlerin ve sim-kanıtının kaynağı: gerçek platform kanalı YOK, olaylar
/// elle tetiklenir. `ostinato_posture.FakePoseSource` ile aynı disiplin.
final class FakeAudioCaptureChannel implements AudioCaptureChannel {
  FakeAudioCaptureChannel({
    this.supportedSampleRates = const <int>{44100, 48000},
  });

  final Set<int> supportedSampleRates;

  final StreamController<RawAudioEvent> _events =
      StreamController<RawAudioEvent>.broadcast();
  bool _running = false;

  @override
  Stream<RawAudioEvent> get events => _events.stream;

  bool get isRunning => _running;

  @override
  Future<void> start({required int sampleRate}) async {
    if (!supportedSampleRates.contains(sampleRate)) {
      throw PlatformException(
        code: 'unsupported_sample_rate',
        message: '$sampleRate',
      );
    }
    _running = true;
  }

  /// Testte tek parça itmek için — `FakePoseSource.pushOne()` deseni.
  void pushChunk(
    List<double> samples, {
    required int sampleRate,
    required int tNativeUs,
  }) {
    if (!_running) return;
    _events.add(
      RawAudioChunkEvent(
        samples: samples,
        sampleRate: sampleRate,
        tNativeUs: tNativeUs,
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
  }

  Future<void> dispose() async {
    await _events.close();
  }
}
