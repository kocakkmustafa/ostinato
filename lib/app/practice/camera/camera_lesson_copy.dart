import '../../ui_copy.dart';

/// K8 camera lesson copy. Mirrored in `content/ui/camera-lesson.json`; see
/// `test/ui_copy_catalog_test.dart`.
abstract final class CameraLessonCopy {
  static const UiCopy section = ('Camera hint', 'Kamera ipucu');
  static const UiCopy intro = (
    'While you hold the position, the camera can give a hint about how far your upper body leans. It gives no score. The image is processed on this device; it is not recorded or sent.',
    'Konumu korurken kamera, gövdenin ne kadar eğildiğine dair ipucu verebilir. Puan vermez. Görüntü bu cihazda işlenir; kaydedilmez, gönderilmez.',
  );
  static const UiCopy start = ('Start with the camera', 'Kamerayla başla');
  static const UiCopy bannerHint = (
    'This lesson has a camera hint for your upper body. The camera only gives hints: tick the checklist yourself; your completion is saved as self-reported.',
    'Bu derste gövden için kamera ipucu var. Kamera yalnız ipucu verir: kontrol listesini kendin işaretle; tamamlaman kendi beyanı olarak kaydedilir.',
  );
  static const UiCopy chipHint = (
    'Checklist · camera hint',
    'Kontrol listesi · kamera ipucu',
  );
  static const UiCopy starting = ('Opening the camera…', 'Kamera açılıyor…');
  static const UiCopy notVisible = (
    'The camera can’t see you. Both shoulders and both hips need to be in view.',
    'Kamera seni göremiyor. İki omzun ve iki kalçan görüntüde olmalı.',
  );
  static const UiCopy watching = (
    'Camera on · no hint so far',
    'Kamera açık · şimdilik ipucu yok',
  );

  /// The golden observation (`OBS_TRUNK_OUTSIDE_RANGE`, first variant) with
  /// its slots as {v0} teachers, {v1} threshold and {v2} measured degrees;
  /// test/camera_lesson_test.dart keeps the English identical to the golden.
  static const UiCopy hintTrunk = (
    'None of the {v0} guitar teachers we recorded leaned more than {v1}° from upright. You are at {v2}° right now.',
    'Kaydettiğimiz {v0} gitar eğitmeninin hiçbiri dik duruştan {v1}°’den fazla eğilmedi. Şu an {v2}°’desin.',
  );
  static const UiCopy timeLeft = ('{v0} s left', '{v0} sn kaldı');
  static const UiCopy timeUp = (
    'Time is up. Go back and tick the checklist.',
    'Süre doldu. Derse dönüp kontrol listesini işaretle.',
  );
  static const UiCopy denied = (
    'Camera access is off. You can turn it on in Settings, or use the checklist without the camera.',
    'Kamera izni kapalı. Ayarlar’dan açabilir ya da kontrol listesini kamerasız kullanabilirsin.',
  );
  static const UiCopy unavailable = (
    'The camera could not start. You can use the checklist without the camera.',
    'Kamera açılamadı. Kontrol listesini kamerasız kullanabilirsin.',
  );
  static const UiCopy back = ('Back to the lesson', 'Derse dön');
  static const UiCopy drillFirst = (
    'Pass the questions first; then the lesson can be marked done.',
    'Önce soruları geç; sonra ders tamamlandı olarak işaretlenebilir.',
  );

  // The hand lesson's mirror (no hint).
  static const UiCopy mirrorSection = ('Camera mirror', 'Kamera aynası');
  static const UiCopy mirrorIntro = (
    'While you hold the position, the front camera shows your hands like a mirror. It gives no hint and no score. The image stays on this device; it is not recorded or sent.',
    'Konumu korurken ön kamera ellerini ayna gibi gösterir. İpucu da puan da vermez. Görüntü bu cihazda kalır; kaydedilmez, gönderilmez.',
  );
  static const UiCopy mirrorStart = ('Open the mirror', 'Aynayı aç');
  static const UiCopy mirrorBanner = (
    'This lesson has a camera mirror for your hands. The mirror gives no hints: tick the checklist yourself; your completion is saved as self-reported.',
    'Bu derste ellerin için kamera aynası var. Ayna ipucu vermez: kontrol listesini kendin işaretle; tamamlaman kendi beyanı olarak kaydedilir.',
  );
  static const UiCopy mirrorChip = (
    'Checklist · camera mirror',
    'Kontrol listesi · kamera aynası',
  );
  static const UiCopy mirrorLive = (
    'Mirror on · compare your hands with the checklist.',
    'Ayna açık · ellerini kontrol listesiyle karşılaştır.',
  );

  static const List<UiCopy> all = [
    section,
    intro,
    start,
    bannerHint,
    chipHint,
    starting,
    notVisible,
    watching,
    hintTrunk,
    timeLeft,
    timeUp,
    denied,
    unavailable,
    back,
    drillFirst,
    mirrorSection,
    mirrorIntro,
    mirrorStart,
    mirrorBanner,
    mirrorChip,
    mirrorLive,
  ];
}
