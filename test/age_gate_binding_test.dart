import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motion_account/motion_account.dart';
import 'package:ostinato/app/motion_account_bootstrap.dart';

import 'support/account_delete_fixture.dart';

// The production page builder passes Core's 13+ result through: a stored
// block reaches MotionAccountPage, and Core's callback persists exactly once.
void main() {
  for (final stored in [false, true]) {
    testWidgets('bound account page receives ageBlocked=$stored', (
      tester,
    ) async {
      final h = (await tester.runAsync(() => AccountDeleteFixture.create()))!;
      var persisted = 0;
      final connection = (await tester.runAsync(() async {
        return bindMotionAccountRuntime(
          h.runtime,
          deletionCoordinator: h.coordinator,
          clearLocalData: (_) async {},
          ageBlocked: stored,
          onAgeBlocked: () async => persisted++,
        );
      }))!;
      try {
        await tester.pumpWidget(
          MaterialApp(home: Builder(builder: connection.pageBuilder)),
        );
        await tester.pumpAndSettle();
        var page = tester.widget<MotionAccountPage>(
          find.byType(MotionAccountPage),
        );
        expect(page.ageBlocked, stored);
        page.onAgeBlocked!.call();
        page.onAgeBlocked!.call();
        expect(persisted, stored ? 0 : 1);
        // A later page from the same binding keeps the block.
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(
          MaterialApp(home: Builder(builder: connection.pageBuilder)),
        );
        await tester.pumpAndSettle();
        page = tester.widget<MotionAccountPage>(find.byType(MotionAccountPage));
        expect(page.ageBlocked, isTrue);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(() async {
          connection.disposeBinding!();
          await h.close(runtimeAlreadyDisposed: true);
        });
      }
    });
  }
}
