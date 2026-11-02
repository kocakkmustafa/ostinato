import '../../ui_copy.dart';

/// v1 paywall copy (course list notice and the paid-lesson mark). Mirrored
/// in `content/ui/v1-paywall.json`; see `test/ui_copy_catalog_test.dart`.
abstract final class V1PaywallCopy {
  static const UiCopy freeScope = (
    'Level {v0} is free · later levels need a membership',
    'Seviye {v0} ücretsiz · sonraki seviyeler üyelik gerektirir',
  );
  static const UiCopy membershipMark = ('Membership', 'Üyelik');

  static const List<UiCopy> all = [freeScope, membershipMark];
}
