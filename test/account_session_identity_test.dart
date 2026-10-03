import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motion_account/motion_account.dart';
import 'package:ostinato/app/account_data_directory.dart';

import 'support/account_delete_fixture.dart';

/// Counts public calls while preserving the real app guard and Core transport.
final class _CountedAccountClient extends MotionAccountClient {
  _CountedAccountClient(this.delegate)
    : super(
        supabase: delegate.supabase,
        app: delegate.app,
        emailRedirectTo: delegate.emailRedirectTo,
      );

  final MotionAccountClient delegate;
  int deleteCalls = 0;

  @override
  Future<void> deleteCommonAccount({
    Future<void> Function(String userId)? afterRemoteDelete,
  }) {
    ++deleteCalls;
    return delegate.deleteCommonAccount(afterRemoteDelete: afterRemoteDelete);
  }
}

Future<void> _expectOtherOwnersPreserved(AccountDeleteFixture h) async {
  expect(await accountDataDirectory(h.root, aliceUuid).exists(), isFalse);
  expect(
    await File(
      '${accountDataDirectory(h.root, bobUuid).path}/sentinel.txt',
    ).readAsString(),
    bobUuid,
  );
  expect(await File('${h.root.path}/guest.txt').readAsString(), 'guest-preserved');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'same SDK Session and a new wrapper dispatch the captured client and cleanup',
    (tester) async {
      final h = (await tester.runAsync(
        () => AccountDeleteFixture.create(delayed: true),
      ))!;
      await tester.runAsync(h.seedFiles);
      final session = h.client.auth.currentSession;
      final epoch = h.ownership.revision;
      final oldClient = _CountedAccountClient(h.pageClient());
      final newClient = _CountedAccountClient(h.pageClient());
      var oldCleanups = 0;
      var newCleanups = 0;
      Future<void> oldCleanup(String id) {
        ++oldCleanups;
        return h.clearLocal(id);
      }

      Future<void> newCleanup(String id) {
        ++newCleanups;
        return h.clearLocal(id);
      }

      Widget host(
        MotionAccountClient account,
        Future<void> Function(String) cleanup,
      ) => MaterialApp(
        home: MotionAccountPage(
          key: const ValueKey('same-epoch-page'),
          account: account,
          clearLocalData: cleanup,
        ),
      );
      try {
        await tester.pumpWidget(host(oldClient, oldCleanup));
        await tester.pumpAndSettle();
        final pageState = tester.state(find.byType(MotionAccountPage));
        await tester.tap(find.text('Delete Motion account'));
        await tester.pumpAndSettle();
        await tester.pumpWidget(host(newClient, newCleanup));
        await tester.pump();
        expect(tester.state(find.byType(MotionAccountPage)), same(pageState));
        expect(
          tester.widget<MotionAccountPage>(find.byType(MotionAccountPage)).account,
          same(newClient),
        );
        expect(h.client.auth.currentSession, same(session));
        expect(h.ownership.revision, epoch);
        expect(find.byType(AlertDialog), findsOneWidget);

        await tester.tap(find.widgetWithText(FilledButton, 'Delete account'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        for (var attempt = 0; attempt < 20; ++attempt) {
          await tester.runAsync(() async {
            await Future<void>.delayed(const Duration(milliseconds: 1));
          });
          await tester.pump(const Duration(milliseconds: 5));
          if (h.transport.deleteCalls == 1) break;
        }
        expect(oldClient.deleteCalls, 1);
        expect(newClient.deleteCalls, 0);
        expect(h.transport.deleteCalls, 1);
        expect(h.transport.deleteAuthorization, 'Bearer A-session1');
        expect(oldCleanups, 0);
        expect(newCleanups, 0);

        h.transport.confirm();
        for (var attempt = 0; attempt < 40; ++attempt) {
          await tester.runAsync(() async {
            await Future<void>.delayed(const Duration(milliseconds: 1));
          });
          await tester.pump(const Duration(milliseconds: 5));
          if (h.coreDeletesSettled == 1) break;
        }
        expect(h.coreDeletesSettled, 1);
        expect(oldCleanups, 1);
        expect(newCleanups, 0);
        expect(h.client.auth.currentSession, isNull);
        await tester.runAsync(() => _expectOtherOwnersPreserved(h));
      } finally {
        await tester.pumpWidget(const SizedBox());
        h.transport.confirm();
        for (var attempt = 0;
            attempt < 40 && h.coreDeletesSettled != h.coreDeleteCalls;
            ++attempt) {
          await tester.runAsync(() async {
            await Future<void>.delayed(const Duration(milliseconds: 1));
          });
          await tester.pump(const Duration(milliseconds: 5));
        }
        expect(h.coreDeletesSettled, h.coreDeleteCalls);
        await tester.runAsync(h.close);
      }
    },
  );

  for (final replacement in [
    'same-token initialSession',
    'same-token signedIn',
    'normal tokenRefreshed',
  ]) {
    test('held confirmed deletion preserves the actual $replacement Session',
        () async {
      final h = await AccountDeleteFixture.create(delayed: true);
      addTearDown(h.close);
      await h.seedFiles();
      final initiatingSession = h.client.auth.currentSession;
      var cleanupCalls = 0;
      final operation = h.pageClient().deleteCommonAccount(
        afterRemoteDelete: (id) {
          ++cleanupCalls;
          expect(id, aliceUuid);
          return h.clearLocal(id);
        },
      );
      await h.transport.started.future;
      try {
        expect(h.transport.deleteAuthorization, 'Bearer A-session1');
        expect(h.transport.deleteBody?['expectedUserId'], aliceUuid);
        if (replacement == 'same-token initialSession') {
          await h.replace(aliceUuid, 'A-session1');
        } else if (replacement == 'same-token signedIn') {
          await h.signIn(aliceUuid, 'A-session1');
        } else {
          await h.client.auth.refreshSession('local-refresh');
          await Future<void>.delayed(Duration.zero);
          await h.runtime.refreshIdentity();
          await Future<void>.delayed(Duration.zero);
        }
        final replacementSession = h.client.auth.currentSession;
        expect(replacementSession, isNotNull);
        expect(identical(replacementSession, initiatingSession), isFalse);
        expect(replacementSession!.user.id, initiatingSession!.user.id);
        expect(
          replacementSession.accessToken,
          replacement == 'normal tokenRefreshed' ? 'A-refreshed' : 'A-session1',
        );
        h.transport.confirm();
        await operation;
        expect(cleanupCalls, 1);
        expect(h.transport.deleteCalls, 1);
        expect(h.client.auth.currentSession, same(replacementSession));
        expect(h.runtime.userId.value, aliceUuid);
        expect(h.runtime.phase.value, MotionIdentityPhase.verified);
        await _expectOtherOwnersPreserved(h);
      } finally {
        h.transport.confirm();
        await operation;
      }
    });
  }
}
