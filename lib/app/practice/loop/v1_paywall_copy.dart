import '../../ui_copy.dart';

/// v1 paywall copy (course list notice, the paid-lesson mark and the
/// onboarding note used while Motion+ is not offered). Mirrored
/// in `content/ui/v1-paywall.json`; see `test/ui_copy_catalog_test.dart`.
abstract final class V1PaywallCopy {
  static const UiCopy freeScope = (
    'Level {v0} is free · later levels need a membership',
    'Seviye {v0} ücretsiz · sonraki seviyeler üyelik gerektirir',
  );
  static const UiCopy membershipMark = ('Membership', 'Üyelik');

  /// `V1HomeCopy.welcomeNote` without Motion+ (founder, 2026-11-02: the v1
  /// submission sells only the Ostinato plans).
  static const UiCopy welcomeNoteOstinatoOnly = (
    'To pass a lesson, at least 80% of its notes need to be correct; then the next lesson opens. The first lessons of each course are free; later lessons need an Ostinato membership.',
    'Bir dersi geçmek için notaların en az %80’i doğru olmalı; o zaman sıradaki ders açılır. Her kursun ilk dersleri ücretsizdir; sonraki dersler Ostinato üyeliği gerektirir.',
  );

  static const List<UiCopy> all = [
    freeScope,
    membershipMark,
    welcomeNoteOstinatoOnly,
  ];
}
