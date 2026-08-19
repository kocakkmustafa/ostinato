import 'dart:async';

/// OST-P1-001 — bir pratik oturumunun yaşam döngüsü: preview → calibrating
/// → countIn → playing → reviewing, oradan `retry()` (SICAK: aynı egzersiz,
/// sensörler kalibre kalır) ya da `advanceToNext()` (SOĞUK: yeni segment,
/// yeniden preview+calibrate).
///
/// "Kabuk yalnız kablolama" — `ostinato_posture`nin `PoseSource`/
/// `SurfaceState`/`PostureEvaluator` üçlüsüyle AYNI disiplin: bu dosya saf
/// Dart, Flutter `Widget`/`BuildContext`a bağımlı DEĞİL. `live_screen.dart`
/// (OST-P1-001 Step 2) bu sınıfı SARMALAYACAK, mantığı KENDİSİ İÇERMEYECEK.

/// Bir dersin hangi ölçüm modalitelerini gerektirdiği. `Calibrating`
/// TÜMÜ hazır bildirilene kadar `CountIn`e GEÇMEZ — tek bir modalitenin
/// (ör. audio noise-floor) sessizce atlanması, kalibre-edilmemiş bir
/// motorun "hazır" sayılması demek olurdu.
enum PracticeModality { posture, audio }

/// Bir denemenin (attempt) sonucu. `isWeak` Step 4'ün weak-measure loop'unun
/// GİRDİSİ — bu turda yalnız TAŞINIYOR, tempo-ayarlama mantığı (Step 4)
/// henüz İNŞA EDİLMEDİ (spekülatif alan eklenmedi, yalnız Step 1'in
/// ihtiyacı kadarı).
final class PracticeAttemptOutcome {
  const PracticeAttemptOutcome({required this.isWeak});
  final bool isWeak;
}

sealed class PracticeSessionState {
  const PracticeSessionState();
}

/// Egzersiz henüz BAŞLAMADI — notasyon/hedef akor/beklenen aralık gösterilir,
/// hiçbir sensör dinlemiyor.
final class PracticePreview extends PracticeSessionState {
  const PracticePreview();
}

/// Gerekli TÜM modaliteler (posture kamerası, audio mikrofonu) hazır
/// bildirilene kadar sürer. `modalities` bu DERSİN neye ihtiyacı olduğunu
/// taşır — hangilerinin ZATEN hazır olduğu controller'ın kendi iç durumu
/// (dışarı sızdırılmaz, yalnız TAM SET tamamlanınca geçiş tetiklenir).
final class PracticeCalibrating extends PracticeSessionState {
  const PracticeCalibrating({required this.modalities});
  final Set<PracticeModality> modalities;
}

/// Metronom geri sayımı — `beatsRemaining` sıfıra İNMEZ, son vuruşta
/// doğrudan `PracticePlaying`e geçilir (bir "0 vuruş kaldı" hâli asla
/// gösterilmez).
final class PracticeCountIn extends PracticeSessionState {
  const PracticeCountIn({required this.beatsRemaining});
  final int beatsRemaining;
}

/// Aktif ölçüm — kamera/mikrofon canlı, örnekler biriktiriliyor.
final class PracticePlaying extends PracticeSessionState {
  const PracticePlaying();
}

/// Son denemenin SONUCU gösteriliyor — kullanıcı `retry()` (aynı egzersiz,
/// sıcak) ya da `advanceToNext()` (yeni segment, soğuk) seçer.
final class PracticeReviewing extends PracticeSessionState {
  const PracticeReviewing({required this.outcome});
  final PracticeAttemptOutcome outcome;
}

/// Saf durum makinesi. Geçersiz-hâlden çağrılan her metod SESSİZCE
/// YOK SAYILIR (hata fırlatmaz, state DEĞİŞMEZ, stream'e HİÇBİR ŞEY
/// yaymaz) — `ostinato_audio`nun `ChordDetector`ı "reddet, tahmin etme"
/// disipliniyle AYNI ilke: çağıranın UI'ı zaten yalnız ilgili düğmeleri
/// doğru hâlde gösterecek, ama savunma burada da durur.
final class PracticeSessionController {
  PracticeSessionController({
    required this.modalities,
    this.countInBeats = 4,
  }) : assert(modalities.isNotEmpty, 'en az bir modalite gerekir'),
       assert(countInBeats >= 1);

  final Set<PracticeModality> modalities;
  final int countInBeats;

  PracticeSessionState _state = const PracticePreview();
  PracticeSessionState get state => _state;

  final StreamController<PracticeSessionState> _controller =
      StreamController<PracticeSessionState>.broadcast();
  Stream<PracticeSessionState> get stateStream => _controller.stream;

  final Set<PracticeModality> _readyModalities = <PracticeModality>{};

  void _emit(PracticeSessionState s) {
    _state = s;
    _controller.add(s);
  }

  void startCalibration() {
    if (_state is! PracticePreview) return;
    _emit(PracticeCalibrating(modalities: modalities));
  }

  void reportModalityReady(PracticeModality modality) {
    if (_state is! PracticeCalibrating) return;
    _readyModalities.add(modality);
    if (_readyModalities.containsAll(modalities)) {
      _emit(PracticeCountIn(beatsRemaining: countInBeats));
    }
  }

  void tickCountIn() {
    final PracticeSessionState s = _state;
    if (s is! PracticeCountIn) return;
    if (s.beatsRemaining <= 1) {
      _emit(const PracticePlaying());
    } else {
      _emit(PracticeCountIn(beatsRemaining: s.beatsRemaining - 1));
    }
  }

  void finishAttempt(PracticeAttemptOutcome outcome) {
    if (_state is! PracticePlaying) return;
    _emit(PracticeReviewing(outcome: outcome));
  }

  /// SICAK tekrar — aynı egzersiz, sensörler ZATEN kalibre. Preview/
  /// Calibrating'i TEKRARLAMAZ (kullanıcıya sürtünme eklerdi); doğrudan
  /// CountIn'e döner. `_readyModalities` KASITLI olarak temizlenmiyor —
  /// bir sonraki Calibrating turu (advanceToNext ile) sıfırdan başlar,
  /// ama retry() zaten Calibrating'e hiç GİRMİYOR.
  void retry() {
    if (_state is! PracticeReviewing) return;
    _emit(PracticeCountIn(beatsRemaining: countInBeats));
  }

  /// SOĞUK ilerleme — yeni segment/ders. Preview'e döner; bir sonraki
  /// `startCalibration()` sıfırdan başlasın diye modalite-hazırlık durumu
  /// burada TEMİZLENİR (eski turun "hazır" bilgisi yeni segmente SIZMAZ).
  void advanceToNext() {
    if (_state is! PracticeReviewing) return;
    _readyModalities.clear();
    _emit(const PracticePreview());
  }

  void dispose() {
    _controller.close();
  }
}
