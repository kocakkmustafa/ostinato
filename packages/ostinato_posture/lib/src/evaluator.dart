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
