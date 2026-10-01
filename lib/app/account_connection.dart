import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Package-independent seam for the shared Motion account screen. The host
/// supplies the real auth state and account page after motion_account has a
/// pinable Git revision. No local account or premium state is fabricated.
class AccountConnection {
  const AccountConnection({
    required this.userId,
    required this.pageBuilder,
    this.requirePaidAccess,
  });

  final ValueListenable<String?> userId;
  final WidgetBuilder pageBuilder;
  final Future<bool> Function(BuildContext)? requirePaidAccess;
}

class AccountScope extends InheritedWidget {
  const AccountScope({
    required this.connection,
    required this.currentUserId,
    required super.child,
    super.key,
  });

  final AccountConnection? connection;
  final String? currentUserId;

  static AccountScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AccountScope>();

  @override
  bool updateShouldNotify(AccountScope oldWidget) =>
      connection != oldWidget.connection ||
      currentUserId != oldWidget.currentUserId;
}
