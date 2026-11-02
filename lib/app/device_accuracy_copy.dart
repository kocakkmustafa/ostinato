import 'ui_copy.dart';

/// The one sentence about measurement accuracy on real devices, shown in
/// Settings → About, Settings → Microphone and the tuner. Founder decision
/// 2026-11-02: it replaced three "not verified on real hardware / real
/// phones" notes; to change the wording, change it here (and in
/// `content/ui/device-accuracy.json` plus the 14 catalogs).
abstract final class DeviceAccuracyCopy {
  static const UiCopy note = (
    'Accuracy depends on your phone\'s microphone and the room; measured results may vary.',
    'Doğruluk telefonunun mikrofonuna ve odaya bağlıdır; ölçülen sonuçlar değişebilir.',
  );

  /// Note-observation screen (guitar page): the same sentence inside the
  /// screen's own guidance line.
  static const UiCopy observationNote = (
    'Optional · one guitar string · a quiet room. Overlapping sounds can show a plausible but misleading note. Accuracy depends on your phone\'s microphone and the room; measured results may vary. This does not decide tuning or playing success.',
    'İsteğe bağlı · tek gitar teli · sessiz oda. Üst üste binen sesler inandırıcı ama yanıltıcı bir nota gösterebilir. Doğruluk telefonunun mikrofonuna ve odaya bağlıdır; ölçülen sonuçlar değişebilir. Akort veya çalma başarısına karar vermez.',
  );

  static const List<UiCopy> all = [note, observationNote];
}
