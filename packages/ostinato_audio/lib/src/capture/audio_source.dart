import 'dart:async';

import 'audio_route.dart';
import 'audio_surface_state.dart';

/// Native saatin BEYAN ETTİĞİ alan — `motion_camera.ClockDomain` ile AYNI
/// kavram, bilerek AYRI tip (bu paket `motion_camera`ya bağımlı değil, dev
/// dependency bile değil — yalnız desen ödünç alınır, tip değil).
///
/// `monotonic`: iOS `AVAudioTime.hostTime` / Android `System.nanoTime()` —
/// ikisi de cihazın kendi tekdüze saatine bağlı, NTP sıçramasından/uykudan
/// etkilenmez. `unknown`: native taraf bunu garanti edemiyorsa (bugün
/// yazılan native koddaki HER iki platform da `monotonic` üretir, ama tip
/// yine de var — "her zaman monotonic" bir VARSAYIM değil, native kodun
/// KENDİSİNİN beyan ettiği bir alan olmalı).
///
/// ⚠️ `tStartUs` bu tamponun/native akışın KENDİ sıfır noktasınadır —
/// `motion_core.MotionClock.nowUs()` (Dart `Stopwatch`, ayrı bir sıfır
/// noktası) ile DOĞRUDAN karşılaştırılamaz. İki saati birleştirmek (offset
/// ölçmek) latency KALİBRASYONUDUR — bu paketin bugünkü kapsamı DIŞINDA
/// (OST-P0-003, `motion_audio` latency-girdisi notu §2 madde 3: "Bluetooth
/// latency ÖLÇÜLMEDEN timing score verilmez").
enum AudioClockDomain { monotonic, unknown }

/// Bir yakalama parçası: ham mono float örnekler + kaynağın kendi zaman
/// damgası.
final class AudioChunk {
  const AudioChunk({
    required this.samples,
    required this.sampleRate,
    required this.tStartUs,
    required this.clockDomain,
    this.playbackActive = false,
  });

  /// Mono float örnekler, `[-1, 1]` aralığında — `PitchSource.analyze`
  /// sözleşmesiyle BİREBİR (bkz. `pitch_source.dart`), böylece bu paketin
  /// analiz tarafı yakalama tarafından hiçbir dönüşüm istemeden tüketir.
  final List<double> samples;

  final int sampleRate;

  /// `samples[0]`in yakalama zamanı, KAYNAĞIN KENDİ saatinde (bkz.
  /// [clockDomain] uyarısı — `motion_core` saatiyle karıştırılamaz).
  final int tStartUs;

  final AudioClockDomain clockDomain;

  /// F2.1: bu pencere boyunca uygulamanın KENDİ çıkışı (metronom kliği,
  /// referans ses) duyulabilir durumdaydı — hoparlör→mikrofon sızıntısı
  /// olabilir. Native taraf muhafazakâr işaretler (çalma kuyruğu + kuyruk
  /// süresi). Bu bir HÜKÜM değil, ölçüm güveni girdisidir: tüketici
  /// "düşük güven" işaretlemek için kullanır. Yalnız-kayıt oturumunda her
  /// zaman `false`.
  final bool playbackActive;
}

/// Ses örneklerinin kaynağı. Gerçek mikrofon bunun BİR uygulamasıdır, tek
/// değil — `ostinato_posture.PoseSource` ile AYNI gerekçe: canlı yolu
/// donanımsız KANITLAYABİLMEK için (`FakeAudioSource`), ve öyle
/// raporlanabilmek için ("sahte kaynakla uçtan uca aktı" ≠ "mikrofon
/// çalışıyor").
abstract interface class AudioSource {
  Stream<AudioChunk> get chunks;

  /// Kaynağın KENDİ yaşam-döngüsü hâlleri — izin, kurulum, kalibrasyon,
  /// akış. Ölçümden AYRI akış (posture'un `status`/`frames` ayrımıyla aynı
  /// gerekçe): bunlar sesin NE söylediğini değil, HATTIN kendisini anlatır.
  Stream<AudioSurfaceState> get status;

  /// [sampleRate] desteklenmiyorsa `status`a `AudioUnavailable` düşer,
  /// `chunks` hiç akmaz — sessizce en yakın desteklenen hıza YUVARLAMAZ
  /// (roadmap OST-P0-002 Step 1: "unsupported sample rate" isimli bir hâl
  /// olmalı, tahmin edilmiş bir hâl değil).
  Future<void> start({required int sampleRate});

  Future<void> stop();
}

/// Testlerin ve sim-kanıtının kaynağı: script'lenmiş parçaları/hâlleri elle
/// tetikleyerek akıtır. GERÇEK mikrofon DEĞİLDİR — `ostinato_posture.
/// FakePoseSource` ile aynı disiplin, aynı sınır.
final class FakeAudioSource implements AudioSource {
  FakeAudioSource({
    this.supportedSampleRates = const <int>{44100, 48000},
    AudioRoute initialRoute = AudioRoute.speaker,
  }) : route = initialRoute;

  /// Testin `start()` çağrısının hangi hızları "destekler" bulacağını
  /// belirler — gerçek native tarafın "desteklenmeyen sample rate" hâlini
  /// donanımsız sınamak için.
  final Set<int> supportedSampleRates;

  AudioRoute route;
  bool permissionGranted = true;
  bool permissionPermanentlyDenied = false;

  final StreamController<AudioChunk> _chunks =
      StreamController<AudioChunk>.broadcast();
  final StreamController<AudioSurfaceState> _status =
      StreamController<AudioSurfaceState>.broadcast();

  bool _running = false;
  int _tickUs = 0;

  @override
  Stream<AudioChunk> get chunks => _chunks.stream;

  @override
  Stream<AudioSurfaceState> get status => _status.stream;

  bool get isRunning => _running;

  @override
  Future<void> start({required int sampleRate}) async {
    _status.add(const AudioStarting());
    if (!permissionGranted) {
      _status.add(permissionPermanentlyDenied
          ? const AudioPermissionDeniedPermanent()
          : const AudioPermissionDeniedRetriable());
      return;
    }
    if (!supportedSampleRates.contains(sampleRate)) {
      _status.add(AudioUnavailable('unsupported_sample_rate:$sampleRate'));
      return;
    }
    _running = true;
    _tickUs = 0;
    _status.add(AudioCalibrating(route));
  }

  /// Testlerde zamanlayıcı beklemeden tek parça itmek için (posture'un
  /// `pushOne()` deseni). `start()` başarısızsa (izin/hız reddi) sessizce
  /// atlar — koşan olmayan bir kaynaktan parça sızmaz.
  void pushChunk(List<double> samples, {int sampleRate = 44100}) {
    if (!_running) return;
    _chunks.add(AudioChunk(
      samples: samples,
      sampleRate: sampleRate,
      tStartUs: _tickUs,
      clockDomain: AudioClockDomain.monotonic,
    ));
    _tickUs += ((samples.length / sampleRate) * 1000000).round();
  }

  /// Route değişimini simüle eder — gerçek kaynağın native route-change
  /// bildirimiyle uyacağı sözleşme: roadmap §7 madde 2, HER değişim
  /// `AudioCalibrating`e döner (akış durmuyor, yalnız timing hükmü kesiliyor
  /// gibi düşünülmeli — ama bu sınıf timing hükmü ÜRETMEZ, yalnız hâli
  /// yayar).
  void simulateRouteChange(AudioRoute newRoute) {
    route = newRoute;
    if (_running) _status.add(AudioCalibrating(newRoute));
  }

  @override
  Future<void> stop() async {
    _running = false;
  }

  Future<void> dispose() async {
    await _chunks.close();
    await _status.close();
  }
}
