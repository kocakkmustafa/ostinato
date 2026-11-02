import 'ui_copy.dart';

/// Ostinato membership page copy. Mirrored in `content/ui/membership.json`;
/// see `test/ui_copy_catalog_test.dart`.
abstract final class MembershipCopy {
  /// Shown when a signed-out user chooses a plan or restores purchases.
  static const UiCopy signInFirst = (
    'Sign in or create an account first: your membership is tied to your account, so it works on every device where you sign in.',
    'Önce giriş yap ya da hesap oluştur: üyeliğin hesabına bağlıdır, böylece giriş yaptığın her cihazda geçerli olur.',
  );

  static const List<UiCopy> all = [signInFirst];
}
