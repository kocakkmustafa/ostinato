import '../ui_copy.dart';

/// Settings copy. Mirrored in `content/ui/settings.json`; see
/// `test/ui_copy_catalog_test.dart`.
abstract final class SettingsCopy {
  /// Settings → Microphone (store review 2026-11-02): measured practice
  /// uses the share of notes heard as correct, and permission is asked at
  /// the first measurement (setup, tuner or lesson).
  static const UiCopy micBody = (
    'In measured practice the microphone listens to the notes you play. A lesson is passed when a high enough share of its notes is heard as correct; the share needed rises with the level. Permission is asked the first time something is measured. Audio is processed on this device and is not uploaded; what you play is not recorded unless you turn on listening back to your own recording. Stopping, leaving the screen, changing account or moving the app to the background closes the microphone.',
    'Ölçülü pratikte mikrofon çaldığın notaları dinler. Notalarının yeterli bir kısmı doğru duyulduğunda ders geçilir; gereken oran seviyeyle artar. İzin, ilk ölçümde istenir. Ses bu cihazda işlenir ve yüklenmez; kendi kaydını dinleme seçeneğini açmadıkça çaldığın kaydedilmez. Durdurmak, ekrandan çıkmak, hesap değiştirmek veya uygulamayı arka plana almak mikrofonu kapatır.',
  );

  /// Settings → About this build, after the live-instrument sentence
  /// ({v0}); followed by [DeviceAccuracyCopy.note].
  static const UiCopy aboutPosture = (
    '{v0} Every posture reference is built from teaching footage filmed waist-up, which is why nothing below your hips is read.',
    '{v0} Tüm duruş referansları belden yukarı çekilmiş eğitim görüntülerine dayanır; bu yüzden kalçanızın altı okunmaz.',
  );

  static const List<UiCopy> all = [micBody, aboutPosture];
}
