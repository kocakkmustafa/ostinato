import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motion_account/motion_account.dart';
import 'package:ostinato/app/account_ownership_epoch.dart';
import 'package:ostinato/app/motion_account_bootstrap.dart';

import 'support/account_delete_fixture.dart';

void main() {
  for (final sameEpoch in [false, true]) {
    testWidgets(
      sameEpoch
          ? 'actual bound page same-E rebuild preserves draft and pending dialog'
          : 'actual bound page rebuild cannot let an E0 dialog spend E1',
      (tester) async {
        final h = (await tester.runAsync(
          () => AccountDeleteFixture.create(delayed: true),
        ))!;
        final connection = (await tester.runAsync(() async {
          return bindMotionAccountRuntime(
            h.runtime,
            deletionCoordinator: h.coordinator,
            // This regression isolates real page/dialog admission. Other
            // tests exercise this same callback with actual account files.
            clearLocalData: (_) async {},
          );
        }))!;
        final ownership = connection.identityBoundary! as AccountOwnershipEpoch;
        Widget host() => MaterialApp(
          home: Builder(builder: connection.pageBuilder),
        );
        try {
          await tester.pumpWidget(host());
          await tester.pumpAndSettle();
          final oldState = tester.state(find.byType(MotionAccountPage));
          final before = ownership.revision;
          await tester.enterText(find.byType(TextField).first, 'Retained draft');
          await tester.tap(find.text('Delete Motion account'));
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsOneWidget);

          if (!sameEpoch) {
            await tester.runAsync(() => h.signIn(aliceUuid, 'A-session2'));
            expect(ownership.revision, greaterThan(before));
            expect(h.runtime.userId.value, aliceUuid);
            expect(h.runtime.phase.value, MotionIdentityPhase.verified);
            expect(h.runtime.passwordRecovery.value, isFalse);
          } else {
            expect(ownership.revision, before);
          }
          // Invoke the actual production connection.pageBuilder again, under
          // one retained Navigator. No Main key, copied builder or fake client.
          await tester.pumpWidget(host());
          await tester.pump();
          expect(find.byType(AlertDialog), findsOneWidget);
          if (sameEpoch) {
            expect(
              tester.state(find.byType(MotionAccountPage)),
              same(oldState),
            );
            expect(
              tester.widget<TextField>(find.byType(TextField).first).controller!.text,
              'Retained draft',
            );
          }

          await tester.tap(find.widgetWithText(FilledButton, 'Delete account'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          await tester.pump();
          for (var attempt = 0; attempt < 20; ++attempt) {
            await tester.runAsync(() async {
              await Future<void>.delayed(const Duration(milliseconds: 1));
            });
            await tester.pump(const Duration(milliseconds: 5));
            if (h.transport.deleteRequests.isNotEmpty) break;
          }
          expect(find.byType(AlertDialog), findsNothing);
          // The actual Core request is held before cleanup or final sign-out.
          // Keyless E0->E1 must fail with real HTTP1, not a fixture timeout.
          expect(h.transport.deleteRequests.length, sameEpoch ? 1 : 0);
          if (sameEpoch) {
            expect(h.transport.deleteAuthorization, 'Bearer A-session1');
            expect(oldState.mounted, isTrue);
          } else {
            expect(oldState.mounted, isFalse);
            expect(h.client.auth.currentSession?.accessToken, 'A-session2');
          }
        } finally {
          await tester.pumpWidget(const SizedBox());
          h.transport.confirm();
          for (
            var attempt = 0;
            attempt < 40 &&
                h.transport.deleteRequests.isNotEmpty &&
                h.client.auth.currentSession != null;
            ++attempt
          ) {
            await tester.runAsync(() async {
              await Future<void>.delayed(const Duration(milliseconds: 1));
            });
            await tester.pump(const Duration(milliseconds: 5));
          }
          if (h.transport.deleteRequests.isNotEmpty) {
            expect(
              h.client.auth.currentSession,
              isNull,
              reason: 'The held actual Core request must finish local sign-out',
            );
          }
          await tester.pump();
          await tester.runAsync(() async {
            await Future<void>.delayed(Duration.zero);
          });
          await tester.pump();
          await tester.runAsync(() async {
            // Core runtime.dispose is not idempotent. Dispose the binding once
            // and let the fixture release its client/files without a second call.
            h.ownership.dispose();
            connection.disposeBinding!();
            await h.close(runtimeAlreadyDisposed: true);
          });
        }
      },
    );
  }
}
