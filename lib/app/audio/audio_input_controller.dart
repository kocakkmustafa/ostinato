import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:ostinato_audio/ostinato_audio.dart';
import 'package:permission_handler/permission_handler.dart';

import 'audio_capture_channel.dart';
import 'audio_route_state.dart';

/// İzin isteği + [AudioCaptureChannel.start] — `camera_session.dart`
/// `requestAndStartCamera`sıyla AYNI iş bölümü: izin Dart'ta, PLUMBING
/// kanalda.
AudioSurfaceState audioPermissionState(PermissionStatus perm) {
  if (perm.isPermanentlyDenied || perm.isRestricted) {
    return const AudioPermissionDeniedPermanent();
  }
  return const AudioPermissionDeniedRetriable();
}

AudioSurfaceState _mapPlatformException(PlatformException e) {
  if (e.code == 'unsupported_sample_rate') {
    return AudioUnavailable('unsupported_sample_rate:${e.message ?? "?"}');
  }
  return AudioSetupFailed(e.code);
}

/// 🔒 SÜREÇ-GENELİ KAPANIŞ KİLİDİ — `camera_session.dart`taki `_closing`
/// deseninin BİREBİR ses karşılığı (O-076 aktarımı). Cihazda TEK mikrofon
/// var; bir ekran kapanırken mikrofonu hâlâ bırakıyorken bir sonraki ekran
/// `start()` çağırırsa native taraf "already running" ile patlar. Kilit:
/// `start` önce uçuştaki kapanışı BEKLER, N=1'de maliyet SIFIR.
Future<void>? _closingAudio;

void _releaseAudioCapture(Future<void> Function() stopFn) {
  _closingAudio = stopFn().catchError((Object _) {});
}

@visibleForTesting
void noteAudioClosing(Future<void> closing) => _closingAudio = closing;

@visibleForTesting
Future<void> awaitPendingAudioClose() async {
  final Future<void>? closing = _closingAudio;
  if (closing != null) {
    await closing;
    _closingAudio = null;
  }
}

/// Uygulama arka plana düşünce/tekrar öne gelince [onBackground]i çağırır.
/// Ayrı sınıf: kilidin kendisi gibi, eklentisiz sınanabilsin diye
/// (`camera_session.dart noteClosing` deseniyle aynı "test edilebilirlik
/// önce" gerekçesi).
@visibleForTesting
final class AudioLifecycleObserver extends WidgetsBindingObserver {
  AudioLifecycleObserver({required this.onBackground});

  final VoidCallback onBackground;
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
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      onBackground();
    }
  }
}

/// Gerçek mikrofon → [AudioSource] adaptörü (OST-P0-002).
///
/// Roadmap §7 sözleşmesinin YEDİ maddesinden BEŞİ burada uygulanır (madde 4
/// "noise floor" ve madde 6 "chord class" `ostinato_audio`nun kendi
/// `AudioConfidenceGate`/`ChordDetector`ına ait, bu katmanın işi DEĞİL):
///  1. Ring buffer RAM-only + session exit/permission revoke/background'da
///     sıfırlanır → [stop] VE [AudioLifecycleObserver] ikisi de [_ring.clear]
///     çağırır.
///  2. Route/sample-rate değişince `calibration`a döner → [_onRawEvent]
///     `RawRouteChangedEvent`i HER zaman `AudioCalibrating`e çevirir, asla
///     doğrudan `AudioStreaming`e atlamaz (terfi YOK bu turda — bkz. dosya
///     sonu not).
///  3. BT latency kalibre edilmeden timing score yok → bu katman TIMING
///     SCORE hiç ÜRETMEZ (kapsam dışı, OST-P0-003); `AudioStreaming`in
///     kendisi zaten "latency kalibre" iddiası TAŞIMIYOR (bkz.
///     `audio_surface_state.dart`).
///  5. Monophonic/polyphonic ayrımı → `ostinato_audio` katmanının işi.
///  7. MIDI event cihaz kimliği taşımaz → bu dosya MIDI'ye hiç dokunmuyor
///     (ayrı görev paketi).
///
/// **Kanıt sınıfı DÜRÜST** (camera_pose_source.dart dosya-başı notuyla AYNI
/// disiplin): bu sınıf PLUMBING + izin + hâlleri [FakeAudioCaptureChannel]
/// ile kanıtlar. GERÇEK MİKROFON kanıtı YOK — cihaz-günü release-gate
/// (roadmap §15 MANUAL-OSTINATO-DEVICE-20260818). Bağlandı ≠ canlı.
final class AudioInputController implements AudioSource {
  AudioInputController({
    AudioCaptureChannel? channel,
    int ringBufferCapacitySamples = 44100 * 4,
    Future<PermissionStatus> Function()? requestMicrophonePermission,
  })  : _channel = channel ?? MethodChannelAudioCaptureChannel(),
        _ring = AudioRingBuffer(capacitySamples: ringBufferCapacitySamples),
        _requestPermission =
            requestMicrophonePermission ?? Permission.microphone.request;

  final AudioCaptureChannel _channel;
  final AudioRingBuffer _ring;

  /// Enjekte edilebilir izin isteği — `camera_session.dart`taki
  /// `Permission.camera.request()` doğrudan çağrısından FARKLI olarak
  /// buradaki tek satır bir seam: `flutter test`te gerçek platform kanalı
  /// YOK, ve roadmap'in "background/route-change/sample-rate" testleri
  /// izin adımını GEÇMEK zorunda — enjeksiyon olmadan hepsi native
  /// eklentiye takılırdı. Üretimde varsayılan gerçek `Permission.
  /// microphone.request` (davranış DEĞİŞMEDİ, yalnız test edilebilir).
  final Future<PermissionStatus> Function() _requestPermission;

  final StreamController<AudioChunk> _chunks =
      StreamController<AudioChunk>.broadcast();
  final StreamController<AudioSurfaceState> _status =
      StreamController<AudioSurfaceState>.broadcast();

  StreamSubscription<RawAudioEvent>? _sub;
  AudioLifecycleObserver? _lifecycle;
  bool _running = false;
  AudioRoute _route = AudioRoute.unknown;

  @override
  Stream<AudioChunk> get chunks => _chunks.stream;

  @override
  Stream<AudioSurfaceState> get status => _status.stream;

  /// YALNIZ test/tanı: tamponda şu an tutulan örnek sayısı. "Temizlendi mi"
  /// sorusu bu sayıyla ÖLÇÜLÜR (roadmap §7 madde 1'in doğrulama noktası),
  /// bir yorumun beyanıyla değil.
  @visibleForTesting
  int get bufferedSampleCountForTest => _ring.length;

  @override
  Future<void> start({required int sampleRate}) async {
    _status.add(const AudioStarting());
    await awaitPendingAudioClose();
    final PermissionStatus perm = await _requestPermission();
    if (!perm.isGranted) {
      _status.add(audioPermissionState(perm));
      return;
    }
    try {
      await _channel.start(sampleRate: sampleRate);
      _running = true;
      _route = AudioRoute.unknown; // ilk route bildirimi gelene kadar
      _sub = _channel.events.listen(_onRawEvent, onError: (Object e) {
        _status.add(AudioSetupFailed('unexpected: $e'));
      });
      _lifecycle = AudioLifecycleObserver(onBackground: _onBackground)..attach();
      _status.add(AudioCalibrating(_route));
    } on PlatformException catch (e) {
      _status.add(_mapPlatformException(e));
    } on Object catch (e) {
      _status.add(AudioSetupFailed('unexpected: $e'));
    }
  }

  void _onRawEvent(RawAudioEvent event) {
    switch (event) {
      case RawAudioChunkEvent(:final samples, :final sampleRate, :final tNativeUs):
        _ring.push(samples);
        _chunks.add(AudioChunk(
          samples: samples,
          sampleRate: sampleRate,
          tStartUs: tNativeUs,
          clockDomain: AudioClockDomain.monotonic,
        ));
      case RawRouteChangedEvent(:final platformRouteTag):
        _route = mapPlatformRouteTag(platformRouteTag);
        // Roadmap §7 madde 2: HER route değişimi kalibrasyona döner — akış
        // durmaz (chunks akmaya devam eder), yalnız zamanlama hükmü kesilir.
        _status.add(AudioCalibrating(_route));
      case RawInterruptedEvent(:final reason):
        _status.add(AudioSetupFailed(reason));
        unawaited(stop());
    }
  }

  /// Roadmap §7 madde 1: arka plan geçişi — tampon sıfırlanır VE akış
  /// TAMAMEN durur (yalnız tampon temizlenmez). Bu app'in `Info.plist`'inde
  /// `audio` background modu YOK ve OLMAMALI — arka planda dinlemeye devam
  /// eden bir müzik pratiği app'i kapsamın (roadmap §9: "raw mic/camera
  /// upload yok; permission just-in-time ve görünür session indicator")
  /// ruhuna aykırı olurdu.
  void _onBackground() {
    unawaited(stop());
  }

  @override
  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _lifecycle?.detach();
    _lifecycle = null;
    if (_running) {
      _running = false;
      _releaseAudioCapture(_channel.stop);
    }
    // Roadmap §7 madde 1 — "sıfırlanır" koşulsuzdur: başarılı/başarısız
    // kapanış farketmez, HER `stop()` tamponu zeroize eder.
    _ring.clear();
  }

  /// Test/harness kolaylığı — `CameraPoseSource.dispose()` ile aynı şekil.
  Future<void> dispose() async {
    await _chunks.close();
    await _status.close();
  }
}
