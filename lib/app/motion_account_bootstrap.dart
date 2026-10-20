import 'app_theme.dart';
import 'app_theme_preferences.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:motion_account/motion_account.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthState;

import 'account_connection.dart';
import 'account_data_directory.dart';
import 'account_ownership_epoch.dart';
import 'app_locale.dart';
import 'app_locale_preferences.dart';
import 'ownership_guarded_account_client.dart';

const _url = String.fromEnvironment('MOTION_SUPABASE_URL');
const _publishableKey = String.fromEnvironment(
  'MOTION_SUPABASE_PUBLISHABLE_KEY',
);
const _redirect = 'com.yulalab.ostinato://auth/callback';

/// The only production account wiring. The common identity comes from Core;
/// Ostinato removes only its own local history after account deletion.
Future<(MotionAccountRuntime, AccountConnection)>
initializeMotionAccount() async {
  final supportRoot = await getApplicationSupportDirectory();
  // Permanent receipts can arrive during Core initialization. The same root
  // authority already remembers old pending resource closures before that await.
  final coordinator = AccountDeletionCoordinator.forRoot(supportRoot);
  Future<void> clearLocalAccountData(String userId) =>
      deleteAccountData(supportRoot, userId);

  final runtime = await MotionAccountRuntime.initialize(
    url: _url,
    publishableKey: _publishableKey,
    app: MotionApp.ostinato,
    emailRedirectTo: _redirect,
    onDeletedAccount: coordinator.eraseConfirmed,
    localAccountIds: () async => localAccountIds(supportRoot),
  );
  return (
    runtime,
    bindMotionAccountRuntime(
      runtime,
      deletionCoordinator: coordinator,
      clearLocalData: clearLocalAccountData,
    ),
  );
}

/// The production page builder and its app lifetime binding. The app host
/// removes resource listeners before releasing the runtime with disposeBinding.
AccountConnection bindMotionAccountRuntime(
  MotionAccountRuntime runtime, {
  required Future<void> Function(String userId) clearLocalData,
  required AccountDeletionCoordinator deletionCoordinator,
  @visibleForTesting Stream<AuthState>? ownerAuthChanges,
}) {
  final ownership = AccountOwnershipEpoch(
    runtime: runtime,
    deletionCoordinator: deletionCoordinator,
    ownerAuthChanges: ownerAuthChanges,
  );
  var disposed = false;
  Widget accountPage(BuildContext _) {
    final pageOwnership = ownership.capturePage();
    return MotionAccountPage(
      // Core consults widget.account again after its dialog awaits. An epoch
      // change must dispose that State before a rebuild supplies a new client;
      // ordinary same-epoch rebuilds retain form state and the open dialog.
      key: ValueKey<(AccountOwnershipEpoch, int)>((
        pageOwnership.owner,
        pageOwnership.epoch,
      )),
      account: OwnershipGuardedAccountClient(
        delegate: runtime.account,
        ownership: ownership,
        pageOwnership: pageOwnership,
      ),
      initialPasswordRecovery: runtime.isPasswordRecovery,
      clearLocalData: clearLocalData,
      onRetryIdentity: runtime.refreshIdentity,
    );
  }
  return AccountConnection(
    userId: runtime.userId,
    passwordRecovery: runtime.passwordRecovery,
    identityBoundary: ownership,
    resourceAdmission: ownership,
    disposeBinding: () {
      if (disposed) return;
      disposed = true;
      ownership.dispose();
      runtime.dispose();
    },
    pageBuilder: accountPage,
    requirePaidAccess: (context) => requireMotionPaidAccess(
      context,
      account: runtime.account,
      accountPageBuilder: accountPage,
    ),
  );
}

/// Missing or invalid build configuration must never open a guest shell as a
/// substitute for the required shared account.
class AccountStartupFailure extends StatelessWidget {
  const AccountStartupFailure({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: OstinatoThemes.light,
    darkTheme: OstinatoThemes.dark,
    themeMode: AppThemeScope.modeOf(context),
    themeAnimationDuration: Duration.zero,
    locale: AppLocaleScope.maybeOf(context) == null
        ? null
        : Localizations.localeOf(context),
    localeListResolutionCallback: resolveAppLocales,
    supportedLocales: appSupportedLocales,
    localizationsDelegates: appLocalizationsDelegates,
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              localized(
                context,
                'Sign-in is unavailable in this build. Please try an updated version.',
                'Bu sürümde giriş kullanılamıyor. Lütfen güncel bir sürüm deneyin.',
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    ),
  );
}
