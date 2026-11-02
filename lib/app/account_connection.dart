import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// A captured app resource, retired synchronously before its close is awaited.
/// waitForClosed must reject uncertain or unsuccessful close readback.
abstract interface class AccountResourceDrain {
  void retire();
  Future<void> waitForClosed();
}

/// Immutable data ownership; this does not establish Auth verification.
abstract interface class AccountResourceDrainRegistration {
  String? get accountUserId;
  bool get isGuest;
  bool get hasNamespace;
  int get capturedHostEpoch;
  Future<void> retireAndDrain();
}

/// The same actor always returns its original registration/namespace, even
/// after successful closure. A new resource period must use a new actor.
abstract interface class AccountResourceDrainRegistry {
  AccountResourceDrainRegistration registerResource({
    required AccountResourceDrain resource,
  });
}

/// Package-independent seam for the shared Motion account screen. The host
/// supplies the real auth state and account page after motion_account has a
/// pinable Git revision. No local account or premium state is fabricated.
class AccountConnection {
  const AccountConnection({
    required this.userId,
    required this.pageBuilder,
    this.passwordRecovery,
    this.identityBoundary,
    this.resourceAdmission,
    this.disposeBinding,
    this.requirePaidAccess,
    this.requireCameraAccess,
    this.membershipPageBuilder,
  });

  final ValueListenable<String?> userId;
  final WidgetBuilder pageBuilder;

  /// A recovery callback can keep the same user ID. The shared runtime owns
  /// this signal; the shell uses it only to retire navigation and resources.
  final ValueListenable<bool>? passwordRecovery;

  /// Retires routes on public auth/identity boundaries, including a fresh
  /// same-UUID session. Core still decides which phase can enter.
  final Listenable? identityBoundary;

  /// App resource denial only; Core alone decides identity admission.
  final ValueListenable<bool>? resourceAdmission;

  /// Owned by the app host; route rebuilds never dispose the shared binding.
  final VoidCallback? disposeBinding;

  /// Paid lessons and independent practice (Core `requireMotionPaidAccess`).
  final Future<bool> Function(BuildContext)? requirePaidAccess;

  /// Camera setup, measurement and scoring (Core `requireMotionCameraAccess`);
  /// closed in this release whatever the membership.
  final Future<bool> Function(BuildContext)? requireCameraAccess;

  /// The membership page (status, plans, restore) shown from Settings; null
  /// when the account page itself links to it or nothing is sold.
  final WidgetBuilder? membershipPageBuilder;
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
