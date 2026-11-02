// v1 submission (founder, 2026-11-02): only the two Ostinato plans are sold;
// Motion+ is neither requested, offered nor named. A verified membership
// (including an earlier Motion+ purchase) still counts as active.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motion_account/motion_account.dart';
import 'package:motion_entitlements/motion_entitlements.dart';
import 'package:ostinato/app/account_connection.dart';
import 'package:ostinato/app/content.dart';
import 'package:ostinato/app/cue_text.dart';
import 'package:ostinato/app/design/app_scope.dart';
import 'package:ostinato/app/ostinato_membership_page.dart';
import 'package:ostinato/app/ostinato_release_policy.dart';
import 'package:ostinato/app/practice/own_recording/own_recording_preference.dart';
import 'package:ostinato/app/screens/settings_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _userId = '11111111-1111-1111-1111-111111111111';

String _session() => jsonEncode({
  'access_token': 'local-test-token',
  'token_type': 'bearer',
  'user': {
    'id': _userId,
    'aud': 'authenticated',
    'created_at': '2026-09-24T00:00:00Z',
    'app_metadata': <String, dynamic>{},
  },
});

class _Store implements PurchaseAdapter {
  _Store(this.offers);

  final List<StoreProductRef> offers;
  final requested = <List<String>>[];
  StoreProductRef? purchased;

  @override
  Stream<StorePurchaseUpdate> get updates => const Stream.empty();

  @override
  Future<List<StoreProductRef>> fetchProducts(List<String> productIds) async {
    requested.add(productIds);
    return offers;
  }

  @override
  Future<void> startPurchase(StoreProductRef offer) async => purchased = offer;

  @override
  Future<void> restore() async {}

  @override
  Future<void> complete(StorePurchaseUpdate update) async {}
}

class _Server implements ServerAdapter {
  @override
  Future<EntitlementStatus?> verify(StorePurchaseEvidence evidence) async =>
      null;
}

class _Account extends MotionAccountClient {
  _Account({required SupabaseClient client, required this.active})
    : super(
        supabase: client,
        app: MotionApp.ostinato,
        emailRedirectTo: 'com.yulalab.ostinato://auth/callback',
      );

  bool active;

  @override
  Future<bool> hasActiveMembership() async => active;

  @override
  Future<MotionMembershipStatus> membershipStatus() async =>
      MotionMembershipStatus(active: active, anyActive: active);

  @override
  Future<MotionAgeStatus> ageStatus() async => const MotionAgeStatus(
    declaration: MotionAgeDeclaration(
      birthYear: 1990,
      birthMonth: 1,
      countryCode: 'TR',
      policyVersion: MotionAgePolicy.version,
    ),
    consent: MotionParentalConsent.none,
  );
}

Future<_Account> _account({bool active = false}) async {
  final client = SupabaseClient(
    'https://motion.example.invalid',
    'public-test-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
  await client.auth.setInitialSession(_session());
  return _Account(client: client, active: active);
}

final class _Pref implements OwnRecordingPreference {
  @override
  Future<bool> read() async => false;
  @override
  Future<void> write(bool enabled) async {}
}

StoreProductRef _ios(String id) => StoreProductRef(
  productId: id,
  platform: StorePlatform.ios,
  planId: id.endsWith('.yearly') ? 'yearly' : 'monthly',
  localizedPrice: id.endsWith('.yearly') ? '₺999,99' : '₺149,99',
);

void main() {
  test('Motion+ is not offered in this release', () {
    expect(ostinatoMotionPlusOffered, isFalse);
  });

  test('the offered product ids are exactly the two Ostinato plans', () {
    expect(ostinatoOfferedProductIds(TargetPlatform.iOS), [
      'com.yulalab.ostinato.individual.monthly',
      'com.yulalab.ostinato.individual.yearly',
    ]);
    // Play: one subscription; monthly and yearly are its base plans.
    expect(ostinatoOfferedProductIds(TargetPlatform.android), [
      'ostinato_individual',
    ]);
    for (final platform in TargetPlatform.values) {
      for (final id in ostinatoOfferedProductIds(platform)) {
        expect(FlutterPurchaseAdapter.isMotionPlusProduct(id), isFalse);
        expect(id.toLowerCase(), isNot(contains('motion')));
      }
    }
  });

  testWidgets('membership page lists the two Ostinato plans and no Motion+', (
    tester,
  ) async {
    final account = await _account();
    // Even if a store returned a Motion+ product, it is not shown.
    final store = _Store([
      _ios('com.yulalab.ostinato.individual.monthly'),
      _ios('com.yulalab.ostinato.individual.yearly'),
      _ios('com.yulalab.ostinato.motionplus.monthly'),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        home: OstinatoMembershipPage(
          account: account,
          purchaseAdapter: store,
          serverAdapter: _Server(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(store.requested, [
      [
        'com.yulalab.ostinato.individual.monthly',
        'com.yulalab.ostinato.individual.yearly',
      ],
    ]);
    expect(find.widgetWithText(FilledButton, 'Choose'), findsNWidgets(2));
    expect(
      find.byKey(
        const Key(
          'ostinato-offer-com.yulalab.ostinato.individual.yearly-yearly',
        ),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Motion+'), findsNothing);
    expect(find.textContaining('₺149,99'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Choose').first);
    // The page waits for the store's purchase update (progress bar).
    await tester.pump();
    await tester.pump();
    expect(
      store.purchased?.productId,
      'com.yulalab.ostinato.individual.monthly',
    );
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    account.supabase.dispose();
  });

  testWidgets('an existing verified membership (e.g. Motion+) stays active', (
    tester,
  ) async {
    final account = await _account(active: true);
    final store = _Store(const []);
    await tester.pumpWidget(
      MaterialApp(
        home: OstinatoMembershipPage(
          account: account,
          purchaseAdapter: store,
          serverAdapter: _Server(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(store.requested, isEmpty, reason: 'no offers for an active member');
    expect(find.widgetWithText(FilledButton, 'Choose'), findsNothing);
    expect(find.textContaining('Motion+'), findsNothing);
    expect(await account.hasActiveMembership(), isTrue);
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    account.supabase.dispose();
  });

  testWidgets('Settings opens the membership page from the connection', (
    tester,
  ) async {
    final userId = ValueNotifier<String?>(null);
    addTearDown(userId.dispose);
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = (await tester.runAsync(ContentRepository.load))!;
    final cue = (await tester.runAsync(CueTextResolver.load))!;
    await tester.pumpWidget(
      ContentRepositoryScope(
        repo: repo,
        cueText: cue,
        child: AccountScope(
          connection: AccountConnection(
            userId: userId,
            pageBuilder: (_) => const Text('account page'),
            membershipPageBuilder: (_) => const Text('membership page'),
          ),
          currentUserId: null,
          child: MaterialApp(
            home: SettingsScreen(ownRecordingPreference: _Pref()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final entry = find.byKey(const Key('settings-membership'));
    expect(entry, findsOneWidget);
    expect(find.text('Membership'), findsOneWidget);
    await tester.tap(entry);
    await tester.pumpAndSettle();
    expect(find.text('membership page'), findsOneWidget);
  });

  test('no user-facing app copy names Motion+ in this release', () {
    // Sources the v1 build shows: the onboarding/home copy is switched by
    // ostinatoMotionPlusOffered; the membership page is the app's own.
    for (final path in [
      'lib/app/ostinato_membership_page.dart',
      'lib/app/screens/onboarding_screen.dart',
      'lib/app/screens/settings_screen.dart',
      'lib/app/practice/loop/v1_practice_list_screen.dart',
      'lib/app/practice/loop/v1_paywall_copy.dart',
    ]) {
      final src = File(path).readAsStringSync();
      expect(
        RegExp(r"'[^'\n]*Motion\+[^'\n]*'").hasMatch(src),
        isFalse,
        reason: path,
      );
    }
  });
}
