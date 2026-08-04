/// Yüzeyin gösterebileceği HER durum — tipli, kapalı küme.
///
/// Neden sealed: "kamera açılmadı" ile "kişi görünmüyor" ile "izin yok" ÜÇ
/// AYRI cümledir ve kullanıcı için üç ayrı eylem gerektirir. Tek bir
/// `error?` alanına düşürmek, üçünü de "bir şeyler ters gitti"ye çevirir —
/// ve o cümle hiçbirini çözmez. Derleyici, yeni bir hâl eklendiğinde
/// yüzeyin onu ele almasını ZORLAR.
///
/// Ham detay SIZMAZ: her hâl kendi adını taşır, altındaki platform
/// istisnasını değil. Kullanıcıya yığın izi gösterilmez; log ayrı iştir.
sealed class SurfaceState {
  const SurfaceState();
}

/// Kamera oturumu henüz açılıyor — "bağlandı ≠ canlı" ayrımının ilk hâli.
final class Starting extends SurfaceState {
  const Starting();
}

/// İzin verilmedi (ya da geri alındı). Tek eylem: ayarlara yönlendir.
final class PermissionDenied extends SurfaceState {
  const PermissionDenied();
}

/// Kamera açılamadı — cihazda yok, model yüklenemedi, ya da oturum reddedildi.
/// [reason] İSİMLİ bir sebeptir (motion_camera'nın CameraFailure adı),
/// platform istisnası metni DEĞİL.
final class CameraUnavailable extends SurfaceState {
  const CameraUnavailable(this.reason);
  final String reason;
}

/// Kamera çalışıyor ama kimse görünmüyor. **Bu bir HATA DEĞİL** — kadraja
/// girmemiş bir kullanıcı ile bozuk bir hat aynı şey değildir, ve ikisini
/// aynı ekrana koymak kullanıcıya yanlış işi yaptırır.
final class NoPersonVisible extends SurfaceState {
  const NoPersonVisible();
}

/// Ölçüm var. [trunkTiltDeg] gövde eğimi; [inBand] skorlama bandının içinde
/// mi; [cue] yalnız aralığın DIŞINDAYKEN doludur (M-F-232 şart 6: içeride
/// SUSAR).
///
/// SAYISAL SKOR YOK — bilerek. Bu sınıfa bir `score` alanı eklemek K8'i
/// çiğnemenin en kolay yoludur.
final class Measuring extends SurfaceState {
  const Measuring({
    required this.trunkTiltDeg,
    required this.inBand,
    this.cue,
  });

  final double trunkTiltDeg;
  final bool inBand;
  final ObservationCue? cue;
}

/// Gözlem işaretinin YÜKÜ — cümle DEĞİL.
///
/// M-F-232 şart 2 (şablon-tek-yol): motor VERİ üretir, app golden
/// katalogdaki şablonu doldurur. Burada bir `String text` alanı olsaydı,
/// yasak-dil taraması ve golden kapısı devre dışı kalırdı: metin motorda
/// doğar, kimse bakmaz.
final class ObservationCue {
  const ObservationCue({
    required this.templateId,
    required this.teacherCount,
    required this.sourceClass,
    required this.thresholdDeg,
    required this.measuredDeg,
  });

  final String templateId;
  final int teacherCount;
  final String sourceClass;
  final double thresholdDeg;
  final double measuredDeg;

  /// Şablon yuvalarının adı → değeri. App bu haritayı golden metne uygular.
  Map<String, String> get slots => <String, String>{
        'n': '$teacherCount',
        'sourceClass': sourceClass,
        'thresholdDeg': thresholdDeg.toStringAsFixed(0),
        'measuredDeg': measuredDeg.toStringAsFixed(0),
      };
}
