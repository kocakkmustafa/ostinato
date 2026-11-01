import '../../ui_copy.dart';

/// FK2 copy ("listen to my own recording"). Mirrored in
/// `content/ui/own-recording.json`; see `test/ui_copy_catalog_test.dart`.
abstract final class OwnRecordingCopy {
  static const UiCopy settingTitle = (
    'Listen to my own recording',
    'Kendi kaydımı dinle',
  );
  static const UiCopy settingBody = (
    'Off by default. When on, your playing in a measured practice run is kept on this device only, so you can listen to it on the result screen. It is deleted when you start the next run or leave the lesson. It is never uploaded and never used for analysis or training.',
    'Varsayılan olarak kapalı. Açıkken ölçülü pratik turunda çaldığın yalnız bu cihazda tutulur; sonuç ekranında dinleyebilirsin. Sonraki tura başlayınca ya da dersten çıkınca silinir. Hiçbir yere yüklenmez; analiz ya da eğitim için kullanılmaz.',
  );
  static const UiCopy settingSaveFailed = (
    'The setting could not be saved. Try again.',
    'Ayar kaydedilemedi. Tekrar dene.',
  );
  static const UiCopy takeTitle = ('Your recording', 'Kendi kaydın');
  static const UiCopy takeNote = (
    'Only on this device · deleted when you start the next run or leave the lesson',
    'Yalnız bu cihazda · sonraki tura başlayınca ya da dersten çıkınca silinir',
  );
  static const UiCopy listen = ('Listen', 'Dinle');
  static const UiCopy pause = ('Pause', 'Duraklat');
  static const UiCopy playFailed = (
    'The recording could not be played.',
    'Kayıt çalınamadı.',
  );

  static const List<UiCopy> all = [
    settingTitle,
    settingBody,
    settingSaveFailed,
    takeTitle,
    takeNote,
    listen,
    pause,
    playFailed,
  ];
}
