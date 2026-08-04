import 'dart:async';

import 'surface_state.dart';

/// Bir karede ölçülen postür — kaynak (kamera / fixture / sahte) ne olursa
/// olsun yüzeyin gördüğü TEK tür.
final class PoseFrame {
  const PoseFrame({required this.tUs, required this.trunkTiltDeg});

  /// Monotonik saat damgası (motion_core sözleşmesi).
  final int tUs;

  /// Gövde eğimi, DERECE, `world` uzayında. `null` = kişi görünmüyor.
  /// Bunu 0 ile doldurmak, görünmeyen bir kişiyi "dimdik oturuyor" diye
  /// raporlamak olurdu (J-056 sınıfı: çöp-ölçüm-gibi).
  final double? trunkTiltDeg;
}

/// Postür karelerinin kaynağı. Kamera bunun BİR uygulamasıdır, tek değil.
///
/// Neden soyut: canlı yolu kamerasız KANITLAYABİLMEK için. Sahte kaynakla
/// yüzeyin gerçekten aktığını göstermek, kamerayı kanıtlamış gibi yapmaktan
/// farklıdır — ikisi ayrı cümle, ayrı kanıt sınıfı.
abstract interface class PoseSource {
  Stream<PoseFrame> get frames;

  /// Kaynağın KENDİ yaşam-döngüsü hâlleri: açılıyor · izin reddi (kalıcı/
  /// geçici) · kurulum patladı.
  ///
  /// Neden ölçümden AYRI akış: bunlar postür hakkında bir şey söylemez, HATTIN
  /// kendisi hakkında söyler. Değerlendiriciye taşımak, ölçüm mantığını izin
  /// diyalogları hakkında bilgi sahibi yapardı. Kamera bu akışı doldurur;
  /// sahte kaynak yalnız `Starting` yayar.
  Stream<SurfaceState> get status;

  Future<void> start();
  Future<void> stop();
}

/// Testlerin ve sim-kanıtının kaynağı: verilen diziyi sırayla akıtır.
///
/// GERÇEK kamera DEĞİLDİR ve öyle raporlanmaz. Kanıt cümlesi: "canlı yol
/// sahte kaynakla uçtan uca aktı" — "kamera çalışıyor" değil.
final class FakePoseSource implements PoseSource {
  FakePoseSource(this.script, {this.stepUs = 33333});

  /// `null` = o karede kişi görünmüyor.
  final List<double?> script;
  final int stepUs;

  final _controller = StreamController<PoseFrame>.broadcast();
  final _status = StreamController<SurfaceState>.broadcast();

  /// Senaryodaki konum — başa sarar.
  int _i = 0;

  /// Damga sayacı — **BAŞA SARMAZ**.
  ///
  /// İlk sürüm `tUs`u senaryo indeksinden türetiyordu (`_i * stepUs`) ve
  /// senaryo döngüye girince saat GERİ GİDİYORDU. Değerlendirici monotonik
  /// saat varsayar (motion_core sözleşmesi) ve haklıdır: cooldown
  /// `frame.tUs - _lastCueUs` ile ölçülür. Saat geri gidince o fark negatif
  /// kalır ve gözlem işareti İLK turdan sonra BİR DAHA ASLA doğmaz.
  ///
  /// Sim ekranında böyle yakalandı: 20,5°de "aralık dışındasın" yazıyordu
  /// ama işaret yoktu. Senkron `pushOne()` kullanan widget testleri bunu
  /// göremez — orada senaryo hiç döngüye girmiyor. **Sözleşmeyi çiğneyen
  /// taraf test-ikizinin kendisiydi.**
  int _tick = 0;
  Timer? _timer;

  @override
  Stream<PoseFrame> get frames => _controller.stream;

  @override
  Stream<SurfaceState> get status => _status.stream;

  @override
  Future<void> start() async {
    _timer = Timer.periodic(Duration(microseconds: stepUs), (_) {
      _emit();
    });
  }

  @override
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
  }

  /// Testlerde zamanlayıcı beklemeden tek kare itmek için.
  void pushOne() => _emit();

  void _emit() {
    if (_i >= script.length) _i = 0; // senaryo başa sarar
    _controller.add(PoseFrame(
      tUs: _tick * stepUs, // saat SARMAZ
      trunkTiltDeg: script[_i],
    ));
    _i++;
    _tick++;
  }

  Future<void> dispose() async {
    await _controller.close();
    await _status.close();
  }
}

/// Yalnız bir yaşam-döngüsü hâli yayan, hiç kare üretmeyen kaynak.
///
/// Kurulum/izin yollarını GERÇEK kamera olmadan yüzeyde sınamak için —
/// tur-2'de kamera adaptörü aynı hâlleri yayacak, yüzey değişmeyecek.
final class StaticStatusSource implements PoseSource {
  StaticStatusSource(this.state);

  final SurfaceState state;
  final _frames = StreamController<PoseFrame>.broadcast();
  final _status = StreamController<SurfaceState>.broadcast();

  @override
  Stream<PoseFrame> get frames => _frames.stream;

  @override
  Stream<SurfaceState> get status => _status.stream;

  @override
  Future<void> start() async => _status.add(state);

  @override
  Future<void> stop() async {}

  Future<void> dispose() async {
    await _frames.close();
    await _status.close();
  }
}
