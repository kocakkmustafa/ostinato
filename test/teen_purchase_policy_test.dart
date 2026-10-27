import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motion_account/motion_account.dart';
import 'package:ostinato/app/motion_account_bootstrap.dart';
import 'package:ostinato/app/ostinato_release_policy.dart';

import 'support/account_delete_fixture.dart';

// OST-K1 (founder decision 2026-10-25) on Core R4: Ostinato leaves 13–17
// purchases to the store's family controls. Core keeps parentalConsentRequired
// as its default, so every Core entry point Ostinato opens must carry the
// app's choice; a missing argument silently falls back to the Core default.
void main() {
  test('Ostinato selects store family controls, not the Core default', () {
    expect(
      ostinatoTeenPurchasePolicy,
      MotionTeenPurchasePolicy.storeFamilyControls,
    );
    expect(
      const MotionAccountPage(account: _NeverAccount()).teenPurchasePolicy,
      MotionTeenPurchasePolicy.parentalConsentRequired,
      reason: 'Core default unchanged; Ostinato must pass its policy',
    );
  });

  testWidgets('production account page carries the Ostinato policy', (
    tester,
  ) async {
    final h = (await tester.runAsync(() => AccountDeleteFixture.create()))!;
    final connection = (await tester.runAsync(() async {
      return bindMotionAccountRuntime(
        h.runtime,
        deletionCoordinator: h.coordinator,
        clearLocalData: (_) async {},
      );
    }))!;
    try {
      await tester.pumpWidget(
        MaterialApp(home: Builder(builder: connection.pageBuilder)),
      );
      await tester.pumpAndSettle();
      final page = tester.widget<MotionAccountPage>(
        find.byType(MotionAccountPage),
      );
      expect(page.teenPurchasePolicy, ostinatoTeenPurchasePolicy);
      expect(page.membershipAvailable, isTrue);
    } finally {
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async {
        connection.disposeBinding!();
        await h.close(runtimeAlreadyDisposed: true);
      });
    }
  });

  // The paid and camera gates open Core's default MotionMembershipPage, which
  // takes the policy from these calls (Core R4 tests that forwarding). Guard
  // the app side: each Core entry point in the bootstrap passes the policy.
  test('every Core purchase entry point in the bootstrap passes the policy', () {
    final source = File(
      'lib/app/motion_account_bootstrap.dart',
    ).readAsStringSync();
    for (final entry in [
      'MotionAccountPage(',
      'requireMotionPaidAccess(',
      'requireMotionCameraAccess(',
    ]) {
      final start = source.indexOf(entry);
      expect(start, isNonNegative, reason: entry);
      final call = source.substring(start, _closingParen(source, start));
      expect(
        call,
        contains('teenPurchasePolicy: ostinatoTeenPurchasePolicy'),
        reason: entry,
      );
    }
    expect(source, isNot(contains('MotionMembershipPage(')));
  });
}

int _closingParen(String source, int from) {
  var depth = 0;
  for (var i = source.indexOf('(', from); i < source.length; i++) {
    if (source[i] == '(') depth++;
    if (source[i] == ')' && --depth == 0) return i;
  }
  throw StateError('unbalanced call at $from');
}

final class _NeverAccount implements MotionAccountClient {
  const _NeverAccount();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('not used');
}
