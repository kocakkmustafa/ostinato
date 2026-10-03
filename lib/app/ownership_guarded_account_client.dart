import 'package:motion_account/motion_account.dart';

import 'account_ownership_epoch.dart';

/// The page owns this wrapper before its dialog opens. All remote account
/// behavior remains in the shared client, including the strict UUID receipt.
final class OwnershipGuardedAccountClient extends MotionAccountClient {
  OwnershipGuardedAccountClient({
    required MotionAccountClient delegate,
    required AccountOwnershipEpoch ownership,
    required AccountPageOwnership pageOwnership,
  }) : _delegate = delegate,
       _ownership = ownership,
       _pageOwnership = pageOwnership,
       super(
         supabase: delegate.supabase,
         app: delegate.app,
         emailRedirectTo: delegate.emailRedirectTo,
       );

  final MotionAccountClient _delegate;
  final AccountOwnershipEpoch _ownership;
  final AccountPageOwnership _pageOwnership;

  @override
  Future<void> deleteCommonAccount({
    Future<void> Function(String userId)? afterRemoteDelete,
  }) async {
    // Capture page lifetime and request token before the shared client yields.
    final action = _ownership.beginDeletion(_pageOwnership);
    await _delegate.deleteCommonAccount(
      afterRemoteDelete: (confirmedId) => _ownership.retireConfirmed(
        action,
        confirmedId,
        filesOnlyCleanup: afterRemoteDelete,
      ),
    );
  }
}
