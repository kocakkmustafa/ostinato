import '../../ui_copy.dart';

/// OST-P0-08 copy. Mirrored in `content/ui/recording-retention.json`; see
/// `test/ui_copy_catalog_test.dart`. It promises no saving and no export:
/// neither exists.
abstract final class RecordingRetentionCopy {
  static const UiCopy practiceFooterSessionOnly = (
    'Stop for pain, numbness or tingling. Audio is processed on this device and not sent. Your recording stays only in this session, on this device, and is deleted when the session ends.',
    'Ağrı, uyuşma ya da karıncalanmada dur. Ses bu cihazda işlenir, gönderilmez. Kaydın yalnız bu oturumda, cihazında kalır ve oturum bitince silinir.',
  );

  static const List<UiCopy> all = [practiceFooterSessionOnly];
}
