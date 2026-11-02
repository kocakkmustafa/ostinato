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
import 'package:ostinato/app/membership_copy.dart';
import 'package:ostinato/app/membership_resume.dart';
import 'package:ostinato/app/ostinato_membership_page.dart';
import 'package:ostinato/app/ostinato_paid_access.dart';
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
  var restored = 0;

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
  Future<void> restore() async => restored++;

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

Future<_Account> _account({bool active = false, bool signedIn = true}) async {
  final client = SupabaseClient(
    'https://motion.example.invalid',
    'public-test-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
  if (signedIn) await client.auth.setInitialSession(_session());
  return _Account(client: client, active: active);
}

/// Stands in for Core's account page: "Sign in" sets a session, then the
/// user goes back.
Widget _fakeAccountPage(BuildContext context, _Account account) => Scaffold(
  appBar: AppBar(),
  body: TextButton(
    key: const Key('fake-sign-in'),
    onPressed: () => account.supabase.auth.setInitialSession(_session()),
    child: const Text('fake account page'),
  ),
);

const _monthly = 'com.yulalab.ostinato.individual.monthly';
const _yearly = 'com.yulalab.ostinato.individual.yearly';

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

  // Store review 2026-11-02 (screen 30): signed out, the page showed only
  // "sign in first" with no plans, prices or way forward.
  testWidgets('signed out: plans, prices, terms, privacy and restore show', (
    tester,
  ) async {
    final account = await _account(signedIn: false);
    final store = _Store([_ios(_monthly), _ios(_yearly)]);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        home: OstinatoMembershipPage(
          account: account,
          accountPageBuilder: (c) => _fakeAccountPage(c, account),
          purchaseAdapter: store,
          serverAdapter: _Server(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(store.requested, hasLength(1));
    expect(find.widgetWithText(FilledButton, 'Choose'), findsNWidgets(2));
    expect(find.textContaining('₺149,99'), findsOneWidget);
    expect(find.textContaining('₺999,99'), findsOneWidget);
    expect(find.text('Sign in to your Motion account first.'), findsNothing);
    for (final label in [
      'Terms of Use',
      'Privacy Policy',
      'Restore purchases',
    ]) {
      expect(find.textContaining(label), findsWidgets, reason: label);
    }
    final restore = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Restore purchases'),
    );
    expect(restore.onPressed, isNotNull);
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    account.supabase.dispose();
  });

  testWidgets('signed out: Choose asks for sign-in with the reason, then '
      'continues to the purchase of that plan', (tester) async {
    final account = await _account(signedIn: false);
    final store = _Store([_ios(_monthly), _ios(_yearly)]);
    final resume = MembershipResume();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        home: OstinatoMembershipPage(
          account: account,
          accountPageBuilder: (c) => _fakeAccountPage(c, account),
          resume: resume,
          purchaseAdapter: store,
          serverAdapter: _Server(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Not now: nothing is bought, nothing is held.
    await tester.tap(find.widgetWithText(FilledButton, 'Choose').last);
    await tester.pumpAndSettle();
    expect(find.text(MembershipCopy.signInFirst.$1), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(store.purchased, isNull);
    expect(resume.pending, isNull);

    await tester.tap(find.widgetWithText(FilledButton, 'Choose').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ostinato-membership-sign-in')));
    await tester.pumpAndSettle();
    expect(find.text('fake account page'), findsOneWidget);
    // Sign-in normally resets navigation; the choice is held for the shell.
    expect(resume.pending?.productId, _yearly);
    await tester.tap(find.byKey(const Key('fake-sign-in')));
    await tester.pumpAndSettle();
    await tester.pageBack();
    // The page waits for the store's purchase update (progress bar).
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
    // The page stayed open here, so it continues itself.
    expect(store.purchased?.productId, _yearly);
    expect(resume.pending, isNull);
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    account.supabase.dispose();
  });

  testWidgets('signed out: backing out of sign-in buys nothing', (
    tester,
  ) async {
    final account = await _account(signedIn: false);
    final store = _Store([_ios(_monthly), _ios(_yearly)]);
    final resume = MembershipResume();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        home: OstinatoMembershipPage(
          account: account,
          accountPageBuilder: (c) => _fakeAccountPage(c, account),
          resume: resume,
          purchaseAdapter: store,
          serverAdapter: _Server(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Choose').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ostinato-membership-sign-in')));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(store.purchased, isNull);
    expect(resume.pending, isNull);
    expect(find.widgetWithText(FilledButton, 'Choose'), findsNWidgets(2));
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    account.supabase.dispose();
  });

  testWidgets('signed out: Restore asks for sign-in first', (tester) async {
    final account = await _account(signedIn: false);
    final store = _Store([_ios(_monthly), _ios(_yearly)]);
    await tester.pumpWidget(
      MaterialApp(
        home: OstinatoMembershipPage(
          account: account,
          accountPageBuilder: (c) => _fakeAccountPage(c, account),
          purchaseAdapter: store,
          serverAdapter: _Server(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Restore purchases'));
    await tester.pumpAndSettle();
    expect(find.text(MembershipCopy.signInFirst.$1), findsOneWidget);
    expect(store.restored, 0);
    await tester.tap(find.byKey(const Key('ostinato-membership-sign-in')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fake-sign-in')));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(store.restored, 1);
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    account.supabase.dispose();
  });

  testWidgets('after the sign-in reset the shell reopens the page, which '
      'continues the held plan', (tester) async {
    final account = await _account();
    final store = _Store([_ios(_monthly), _ios(_yearly)]);
    final resume = MembershipResume()
      ..hold(
        const MembershipIntent.purchase(productId: _monthly, planId: 'monthly'),
      );
    final userId = ValueNotifier<String?>(_userId);
    addTearDown(userId.dispose);
    final connection = AccountConnection(
      userId: userId,
      pageBuilder: (_) => const Text('account page'),
      membershipResume: resume,
      membershipPageBuilder: (_) => OstinatoMembershipPage(
        account: account,
        resume: resume,
        purchaseAdapter: store,
        serverAdapter: _Server(),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        home: MembershipResumeHost(
          connection: connection,
          userId: _userId,
          child: const Text('home'),
        ),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
    expect(find.byType(OstinatoMembershipPage), findsOneWidget);
    expect(store.purchased?.productId, _monthly);
    expect(resume.pending, isNull);
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    account.supabase.dispose();
  });

  testWidgets('the shell does not reopen the page when nothing is held or '
      'nobody is signed in', (tester) async {
    for (final (held, user) in [(false, _userId), (true, null)]) {
      final resume = MembershipResume();
      if (held) resume.hold(const MembershipIntent.restore());
      final userId = ValueNotifier<String?>(user);
      final connection = AccountConnection(
        userId: userId,
        pageBuilder: (_) => const Text('account page'),
        membershipResume: resume,
        membershipPageBuilder: (_) => const Text('membership page'),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: MembershipResumeHost(
            connection: connection,
            userId: user,
            child: const Text('home'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('membership page'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      userId.dispose();
    }
  });

  test('a held step expires', () {
    var now = DateTime.utc(2026, 11, 2, 9);
    final resume = MembershipResume(now: () => now)
      ..hold(const MembershipIntent.restore());
    now = now.add(const Duration(minutes: 14));
    expect(resume.pending, isNotNull);
    now = now.add(const Duration(minutes: 2));
    expect(resume.pending, isNull);
  });

  // Store review 2026-11-02 (screen 37): a paid lesson tapped while signed
  // out jumped to the sign-in screen without explanation.
  testWidgets('paid lesson, signed out: the membership page opens first', (
    tester,
  ) async {
    final account = await _account(signedIn: false);
    var coreGateCalls = 0;
    late BuildContext host;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            host = context;
            return const Text('lesson list');
          },
        ),
      ),
    );
    final result = requireOstinatoPaidAccess(
      host,
      account: account,
      membershipPageBuilder: (_) => const Text('membership page'),
      salesAvailable: true,
      coreGate: () async {
        coreGateCalls++;
        return true;
      },
    );
    await tester.pumpAndSettle();
    expect(find.text('membership page'), findsOneWidget);
    expect(coreGateCalls, 0);
    Navigator.of(tester.element(find.text('membership page'))).pop();
    await tester.pumpAndSettle();
    expect(await result, isFalse, reason: 'still signed out');
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    account.supabase.dispose();
  });

  testWidgets('paid lesson, signed in: Core gate runs unchanged', (
    tester,
  ) async {
    final account = await _account();
    var coreGateCalls = 0;
    late BuildContext host;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            host = context;
            return const Text('lesson list');
          },
        ),
      ),
    );
    final admitted = await requireOstinatoPaidAccess(
      host,
      account: account,
      membershipPageBuilder: (_) => const Text('membership page'),
      salesAvailable: true,
      coreGate: () async {
        coreGateCalls++;
        return true;
      },
    );
    expect(admitted, isTrue);
    expect(coreGateCalls, 1);
    expect(find.text('membership page'), findsNothing);
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
