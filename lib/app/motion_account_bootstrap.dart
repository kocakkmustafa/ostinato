import 'app_theme.dart';
import 'design/ostinato_theme.dart' show ostinatoAppBuilder;
import 'app_theme_preferences.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:motion_account/motion_account.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthState;

import 'account_connection.dart';
import 'account_data_directory.dart';
import 'account_ownership_epoch.dart';
import 'age_gate_store.dart';
import 'app_locale.dart';
import 'app_locale_preferences.dart';
import 'membership_resume.dart';
import 'ostinato_membership_page.dart';
import 'ostinato_paid_access.dart';
import 'ostinato_release_policy.dart';
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
  final ageGate = AgeGateStore(directory: supportRoot);
  final ageBlocked = await ageGate.read();
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
      ageBlocked: ageBlocked,
      onAgeBlocked: ageGate.markBlocked,
    ),
  );
}

/// The production page builder and its app lifetime binding. The app host
/// removes resource listeners before releasing the runtime with disposeBinding.
AccountConnection bindMotionAccountRuntime(
  MotionAccountRuntime runtime, {
  required Future<void> Function(String userId) clearLocalData,
  required AccountDeletionCoordinator deletionCoordinator,
  bool ageBlocked = false,
  Future<void> Function()? onAgeBlocked,
  @visibleForTesting Stream<AuthState>? ownerAuthChanges,
}) {
  final ownership = AccountOwnershipEpoch(
    runtime: runtime,
    deletionCoordinator: deletionCoordinator,
    ownerAuthChanges: ownerAuthChanges,
  );
  var disposed = false;
  // Core's 13+ check: an under-13 result is persisted once and passed back on
  // every later page so another age on this device cannot reopen sign-up.
  var underAgeBlocked = ageBlocked;
  void blockUnderAge() {
    if (underAgeBlocked) return;
    underAgeBlocked = true;
    onAgeBlocked?.call().ignore();
  }

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
      ageBlocked: underAgeBlocked,
      onAgeBlocked: blockUnderAge,
      // Core's account page links only to Core's membership page (with
      // Motion+); while Motion+ is not offered, Settings links to the
      // Ostinato page instead.
      membershipAvailable:
          ostinatoPaidFeaturesAvailable && ostinatoMotionPlusOffered,
      teenPurchasePolicy: ostinatoTeenPurchasePolicy,
    );
  }

  // v1: Core's membership page always shows Motion+, so while Motion+ is not
  // offered the app opens its own page with the Ostinato plans only. A plan
  // chosen while signed out is carried across sign-in by [resume].
  final resume = MembershipResume();
  final WidgetBuilder? membershipPage = ostinatoMotionPlusOffered
      ? null
      : (_) => OstinatoMembershipPage(
          account: runtime.account,
          accountPageBuilder: accountPage,
          resume: resume,
          teenPurchasePolicy: ostinatoTeenPurchasePolicy,
        );

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
    membershipPageBuilder: ostinatoPaidFeaturesAvailable
        ? membershipPage
        : null,
    membershipResume: membershipPage == null ? null : resume,
    // Signed out, the app's membership page comes first (plans and prices,
    // then sign-in on purchase); signed in, Core's gate runs unchanged.
    requirePaidAccess: (context) => requireOstinatoPaidAccess(
      context,
      account: runtime.account,
      membershipPageBuilder: membershipPage,
      salesAvailable: ostinatoPaidFeaturesAvailable,
      coreGate: () => requireMotionPaidAccess(
        context,
        account: runtime.account,
        accountPageBuilder: accountPage,
        membershipPageBuilder: membershipPage,
        salesAvailable: ostinatoPaidFeaturesAvailable,
        teenPurchasePolicy: ostinatoTeenPurchasePolicy,
      ),
    ),
    requireCameraAccess: (context) => requireMotionCameraAccess(
      context,
      account: runtime.account,
      accountPageBuilder: accountPage,
      membershipPageBuilder: membershipPage,
      cameraCoachingAvailable: ostinatoCameraPracticeAvailable,
      teenPurchasePolicy: ostinatoTeenPurchasePolicy,
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
    builder: ostinatoAppBuilder,
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
