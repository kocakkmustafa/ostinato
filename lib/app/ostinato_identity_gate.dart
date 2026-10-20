import 'package:flutter/material.dart';
import 'package:motion_account/motion_account.dart';

import 'app_theme.dart';
import 'app_theme_preferences.dart';

/// App presentation only; identity proof and child admission stay in Core.
final class OstinatoIdentityGate extends StatelessWidget {
  const OstinatoIdentityGate({
    super.key,
    required this.runtime,
    required this.child,
  });

  final MotionAccountRuntime runtime;
  final Widget child;

  @override
  Widget build(BuildContext context) => MotionIdentityGate(
    runtime: runtime,
    theme: OstinatoThemes.light,
    darkTheme: OstinatoThemes.dark,
    themeMode: AppThemeScope.modeOf(context),
    locale: Localizations.maybeLocaleOf(context),
    child: child,
  );
}
