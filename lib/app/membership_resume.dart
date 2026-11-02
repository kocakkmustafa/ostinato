import 'package:flutter/material.dart';

import 'account_connection.dart';

/// What a signed-out user asked the membership page for before signing in.
@immutable
final class MembershipIntent {
  const MembershipIntent.purchase({
    required String this.productId,
    required this.planId,
  }) : restore = false;
  const MembershipIntent.restore()
    : productId = null,
      planId = null,
      restore = true;

  final String? productId;
  final String? planId;
  final bool restore;
}

/// Carries a membership step across sign-in.
///
/// Signing in is an identity boundary: the app shell replaces its navigator,
/// which closes the membership page that asked for sign-in. The page holds
/// its intent here before opening the account page; the new signed-in shell
/// ([MembershipResumeHost]) reopens the membership page, which takes the
/// intent and continues. In memory only, cleared when taken or abandoned,
/// and ignored after [lifetime].
final class MembershipResume {
  MembershipResume({DateTime Function()? now, this.lifetime = _lifetime})
    : _now = now ?? DateTime.now;

  static const _lifetime = Duration(minutes: 15);

  final DateTime Function() _now;
  final Duration lifetime;
  MembershipIntent? _intent;
  DateTime? _heldAt;

  void hold(MembershipIntent intent) {
    _intent = intent;
    _heldAt = _now();
  }

  void clear() {
    _intent = null;
    _heldAt = null;
  }

  /// The held intent, if it is still fresh.
  MembershipIntent? get pending {
    final at = _heldAt;
    if (_intent == null || at == null) return null;
    if (_now().difference(at) > lifetime) {
      clear();
      return null;
    }
    return _intent;
  }

  /// Returns [pending] and clears it.
  MembershipIntent? take() {
    final intent = pending;
    clear();
    return intent;
  }
}

/// Placed around the signed-in shell's first page: when a membership step
/// started before sign-in is pending, reopens the membership page once.
class MembershipResumeHost extends StatefulWidget {
  const MembershipResumeHost({
    super.key,
    required this.connection,
    required this.userId,
    required this.child,
  });

  final AccountConnection? connection;
  final String? userId;
  final Widget child;

  @override
  State<MembershipResumeHost> createState() => _MembershipResumeHostState();
}

class _MembershipResumeHostState extends State<MembershipResumeHost> {
  @override
  void initState() {
    super.initState();
    final connection = widget.connection;
    final page = connection?.membershipPageBuilder;
    if (widget.userId == null ||
        page == null ||
        connection?.membershipResume?.pending == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || connection?.membershipResume?.pending == null) return;
      Navigator.of(context).push<void>(MaterialPageRoute<void>(builder: page));
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
