import 'package:motion_core/motion_core.dart' as core;

/// Ham MediaPipe landmark karesini gövde-eğimi dereceye çevirir (tur-2).
///
/// Ostinato kendi açı formülünü İCAT ETMEZ: motion_core'un aile-geneli
/// `StandardJoints.trunkTilt` tanımı kullanılır — Gravita/Lissom/JabLab ile
/// PAYLAŞILAN, önceden vetted bir ölçü. `packages/motion_core/lib/src/
/// geometry/joint_angles.dart` içinde `id: 'trunk_tilt'` olarak zaten var.
///
/// Zorunlu adımlar, atlanırsa SESSİZCE yanlış sayı üretir:
///  1. **İzotropik düzeltme** (`toIsotropic`) — ham normalize landmarkler
///     anizotropik (M-F-30/J-028: gerçek hasat karelerinde eklem açılarının
///     %42'si 5°'den fazla kaydı, en kötü tekil eklem 62°). Atlanırsa her
///     açı en-boy oranıyla bükülür.
///  2. **Güven kapısı** yalnız GÖVDE (omuz+kalça) landmarklarına — kol/bacak
///     DEĞİL, Ostinato onları hiç ölçmüyor. `xExtent: size.aspect` ZORUNLU
///     (G-038: izotropik karede x-sınırı [0, aspect]'tir, ham [0,1] değil —
///     atlanırsa ekranın sağındaki her kullanıcı "kadraj dışı" sayılır).
///
/// ⚠️ AÇIK SINIR (M-O-08, motion_core'un kendi ölçülü kaydı): izotropik
/// düzeltme yalnız 2B izdüşümü düzeltir. Kullanıcı kameraya AÇILI oturursa
/// (gitar/piyano diyagonal, çello sağ-ön) 3B eksen derinlikte kısalır ve
/// düzlem-içi ölçek bunu KURTARAMAZ. `trunk_tilt` düzlemsel (yalnız x,y;
/// `AngleKind.trunkTilt` z'ye hiç bakmaz) — 3B dünya koordinatı GEREKTİREN
/// bir metrik değil, ama açılı-oturuşun gerçek etkisi CİHAZDA ölçülmeden
/// kapatılmış sayılmaz; isimli sınır olarak kalır (release-gate borcu).
final class CameraPostureAdapter {
  CameraPostureAdapter({core.ConfidenceGate? gate})
      : _gate = gate ?? const core.ConfidenceGate();

  final core.ConfidenceGate _gate;
  final core.PoseNormalizer _normalizer = core.PoseNormalizer();

  static const core.JointAngleExtractor _extractor = core.JointAngleExtractor(
    specs: <core.JointSpec>[core.StandardJoints.trunkTilt],
  );

  /// [raw] motion_camera'nın upright geçişinden gelen ham kare (henüz
  /// izotropik değil). `null` döner: (a) güven kapısı geçmezse (gövde
  /// landmarkları yeterince görünmüyor), (b) kişi hiç görünmüyorsa —
  /// ikisi de `ostinato_posture.PoseFrame(trunkTiltDeg: null)` → evaluator
  /// bunu `NoPersonVisible`e çevirir. Uydurma sayı ASLA üretilmez.
  double? trunkTiltDeg(core.PoseFrame raw, core.FrameSize size) {
    final core.FrameQuality quality = frameQuality(raw, size);
    if (!quality.judgeable) return null;

    final core.NormalizedPose pose =
        _normalizer.normalize(raw.toIsotropic(size));
    return _extractor.extract(pose).degreesById('trunk_tilt');
  }

  /// Ham güven-kapısı sonucu — Kurulum Kontrolü'nün kadraj/ışık ayrımı için
  /// (`QualityIssue.outOfFrame` → "kadraj hatası", `torsoUnreliable`/
  /// `lowTrackingConfidence` → "ışık yetersiz"). `trunkTiltDeg` de AYNI
  /// kapıyı kullanır — iki farklı eşik icat edilmedi.
  core.FrameQuality frameQuality(core.PoseFrame raw, core.FrameSize size) {
    final core.PoseFrame iso = raw.toIsotropic(size);
    return _gate.evaluate(iso, required: core.LmRegion.torso, xExtent: size.aspect);
  }

  /// Oturumlar/take'ler arası çağrılır — ölçek EMA'sını sıfırlar
  /// (`PoseNormalizer.reset`, kendi sözleşmesi: gerçek beden boyu
  /// oturumlar arası değişmez, yalnız ÖLÇÜM yeniden başlar).
  void reset() => _normalizer.reset();
}
