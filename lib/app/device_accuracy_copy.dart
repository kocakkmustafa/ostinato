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

  static const List<UiCopy> all = [note];
}
