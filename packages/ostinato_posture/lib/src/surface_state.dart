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

/// İzin verilmedi. **KALICI mı GEÇİCİ mi, ayrı hâller** (zeyil-3, JabLab
/// deseni): sunulan EYLEM farklı olduğu için ayrımı TİP taşır.
///
/// Tek bir "izin yok" hâli kullanıcıya yanlış düğmeyi gösterir: kalıcı redde
/// "tekrar dene" hiçbir şey yapmaz (sistem artık sormaz) — dokun, hiçbir şey
/// olmaz. Çıkmaz sokağın en sinsi hâli: düğme VAR, işlevi YOK.
sealed class PermissionDenied extends SurfaceState {
  const PermissionDenied();
}

/// Sistem henüz sorabilir — "tekrar dene" GERÇEKTEN bir şey yapar.
final class PermissionDeniedRetriable extends PermissionDenied {
  const PermissionDeniedRetriable();
}

/// Kalıcı ret: sistem BİR DAHA sormaz. Tek anlamlı eylem ayarlara
/// yönlendirmek; "tekrar dene" GÖSTERİLMEZ.
final class PermissionDeniedPermanent extends PermissionDenied {
  const PermissionDeniedPermanent();
}

/// Kamera açılamadı — cihazda yok, model yüklenemedi, ya da oturum reddedildi.
/// [reason] İSİMLİ bir sebeptir (motion_camera'nın CameraFailure adı),
/// platform istisnası metni DEĞİL.
final class CameraUnavailable extends SurfaceState {
  const CameraUnavailable(this.reason);
  final String reason;
}

/// Kurulum HİÇ BAŞLAMADI ya da patladı — ama ekran yine de AÇILIR.
///
/// ÇIKMAZ-SOKAK YASAĞI (zeyil-3): kamera kurulumu patlarsa ders açılmamazlık
/// EDEMEZ. "Dokun → hiçbir şey olmaz" sessiz ölümdür; kullanıcı uygulamanın mı
/// bozuk olduğunu yoksa kendi mi yanlış yaptığını bilemez. Kurulum hatası
/// seansın DIŞINDA bir boşluk değil, İÇİNDE tipli bir hâldir: ekran açılır,
/// analiz-yokluğu BEYAN EDİLİR.
final class SetupFailed extends SurfaceState {
  const SetupFailed(this.reason);

  /// İSİMLİ sebep (`CameraFailure` adı gibi) — ham istisna metni DEĞİL.
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
