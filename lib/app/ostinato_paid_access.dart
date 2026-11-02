import 'package:flutter/material.dart';
import 'package:motion_account/motion_account.dart';

/// Paid-lesson gate (store review 2026-11-02, screen 37).
///
/// Core's gate sends a signed-out user straight to the sign-in screen with
/// no explanation. While sales are open and the app owns its membership
/// page, a signed-out user sees that page first (plans, store prices,
/// terms); it asks for sign-in when they subscribe or restore. Afterwards
/// the lesson opens only for a signed-in account whose membership the server
/// reports active. Signed-in users go through Core's gate ([coreGate])
/// unchanged.
Future<bool> requireOstinatoPaidAccess(
  BuildContext context, {
  required MotionAccountClient account,
  required WidgetBuilder? membershipPageBuilder,
  required bool salesAvailable,
  required Future<bool> Function() coreGate,
}) async {
  if (!salesAvailable ||
      membershipPageBuilder == null ||
      account.currentUser != null) {
    return coreGate();
  }
  await Navigator.of(
    context,
  ).push<void>(MaterialPageRoute<void>(builder: membershipPageBuilder));
  if (!context.mounted) return false;
  final userId = account.currentUser?.id;
  if (userId == null) return false;
  try {
    final active = await account.hasActiveMembership();
    return context.mounted && account.currentUser?.id == userId && active;
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            MotionAccountLocalizations.of(
              context,
            ).text(MotionAccountString.membershipVerificationFailed),
          ),
        ),
      );
    }
    return false;
  }
}
