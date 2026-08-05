import 'contract.dart';
import 'pose_source.dart';
import 'surface_state.dart';

/// Postür karelerini yüzey hâllerine çeviren TEK yer.
///
/// Sözleşmenin canlı karşılığı (hepsi test edilebilir, hiçbiri widget'ta):
///  · bant İÇİNDE → cue SUSAR (M-F-232 şart 6, pozitif ikiz)
///  · bant DIŞINDA → cue yükü doğar (metin DEĞİL — templateId + yuvalar)
///  · kişi yok → `NoPersonVisible`, "0 derece" DEĞİL
///  · sayısal skor ÜRETİLMEZ (K8)
///
/// Bastırma (`consecutiveOutOfBandBeforeCue`): tek bir karede eşiği aşmak
/// işaret üretmez. Gerekçe ölçümden: eğitmenlerin kendi kayıtlarında bile
/// kare-kare oynama var; anlık bir sıçramayı "gözlem" diye sunmak, işareti
/// arka plan gürültüsüne çevirir ve o an sözleşmeyi bozar.
///
/// Cooldown (`cooldownUs`, 30 sn): ardışık ateşlemeler arası bekleme.
/// **Dayanak kardeşi kadar sağlam DEĞİL — isimle kayıtlı (koordinatör
/// denetimi, 2026-08-05, O-036).** `PostureContract`ta bu alan YOK —
/// kardeşinin aksine hiçbir üretilen artefakta bağlı değil, çıplak Dart
/// sabiti. Sayıca `config/rulesets/<çalgı>@0.2.0-draft.json`daki
/// `G-POST-SLOUCH.cooldownMs` (30000) ile EŞİT, ama bu koddan o ruleset
/// alanına DOĞRUDAN bir kablo YOK — ikisi ayrı sistemdir: bu, CANLI gözlem
/// işareti (ÖLÇÜM beyanı); `G-POST-SLOUCH` ise "öğüt"-sınıfı bir hata kodu,
/// hiç ateşlemeden `expertPending`de kapalı duruyor (`assets/content/
/// library.json`). `docs/g4-prep/ruleset-v0.md:41`de özgün değer **20**
/// sn'ydi (`"cooldownSec": {"value": 20, "expertPending": true}`); 30'a NE
/// ZAMAN/NEDEN değiştiği KAYITSIZ — uydurma gerekçe yazılmadı (O-024
/// dersi). Ruleset'teki eşleniği hâlâ `expertPending: true` taşıyor; bu
/// varsayılan da AYNI ihtiyatla okunmalı: movement-science turu (ya da
/// "görünürlük oranı doğru mu" design kararı) gelmeden nihai sayılmaz.
/// Değer BURADA DEĞİŞTİRİLMEDİ — yalnız dayanağı görünür kılındı.
final class PostureEvaluator {
  PostureEvaluator({
    required this.contract,
    this.consecutiveOutOfBandBeforeCue = 3,
    this.cooldownUs = 30 * 1000 * 1000,
  });

  final PostureContract contract;
  final int consecutiveOutOfBandBeforeCue;
  final int cooldownUs;

  int _consecutiveOut = 0;
  int? _lastCueUs;

  /// Kaynağın kendi hâli (izin/kamera) yüzeye DOĞRUDAN geçer; ölçüm hâlleri
  /// burada üretilir.
  SurfaceState evaluate(PoseFrame frame) {
    final double? tilt = frame.trunkTiltDeg;
    if (tilt == null) {
      _consecutiveOut = 0; // görünmeyen kişi "aralık dışı" DEĞİLDİR
      return const NoPersonVisible();
    }

    final double deviation = tilt.abs();
    final bool inBand = deviation <= contract.scoringToleranceDeg;
    final bool beyondCueThreshold = deviation > contract.cueThresholdDeg;

    if (!beyondCueThreshold) {
      _consecutiveOut = 0;
      return Measuring(trunkTiltDeg: tilt, inBand: inBand);
    }

    _consecutiveOut++;
    final bool sustained = _consecutiveOut >= consecutiveOutOfBandBeforeCue;
    final bool cooled = _lastCueUs == null || frame.tUs - _lastCueUs! >= cooldownUs;
    if (!(sustained && cooled)) {
      return Measuring(trunkTiltDeg: tilt, inBand: inBand);
    }

    _lastCueUs = frame.tUs;
    return Measuring(
      trunkTiltDeg: tilt,
      inBand: inBand,
      cue: ObservationCue(
        templateId: contract.cueTemplateId,
        teacherCount: contract.teacherCount,
        sourceClass: contract.sourceClass,
        thresholdDeg: contract.cueThresholdDeg,
        measuredDeg: deviation,
      ),
    );
  }

  /// Kullanıcının bandın NERESİNDE olduğu — 0..1 arası KONUM, puan DEĞİL.
  ///
  /// Ayrım önemli: bu sayı "ne kadar iyisin" demez, "ölçtüğümüz eğitmenlerin
  /// aralığında neredesin" der. Ekranda da öyle çizilir (bant + işaretçi),
  /// yüzde ya da yıldız olarak değil. `null` = bandın dışında.
  double? positionInTeacherBand(double tiltDeg) {
    final double lo = contract.bandLowDeg;
    final double hi = contract.bandHighDeg;
    final double v = tiltDeg.abs();
    if (v < lo || v > hi) return null;
    if (hi - lo < 1e-9) return 0.5;
    return (v - lo) / (hi - lo);
  }
}
