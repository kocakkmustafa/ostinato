import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motion_entitlements/motion_entitlements.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ostinato/app/ostinato_membership_page.dart';
import 'package:ostinato/app/account_connection.dart';
import 'package:motion_account/motion_account.dart';
import 'package:ostinato/app/age_gate_store.dart';
import 'package:ostinato/app/motion_account_bootstrap.dart';
import 'package:ostinato/app/ostinato_release_policy.dart';
import 'package:ostinato/app/parental_consent/consent_token_store.dart';
import 'package:ostinato/app/parental_consent/parental_consent_controller.dart';
import 'package:ostinato/app/parental_consent/parental_consent_copy.dart';
import 'package:ostinato/app/parental_consent/parental_consent_page.dart';
import 'package:ostinato/app/parental_consent/purchase_rule.dart';

import 'support/account_delete_fixture.dart';

// ADR-008: flag closed = today's permanent block; flag forced open = the
// parent-approval flow, always fail-closed. A fake gateway stands in for Core
// (the server side is not deployed): no test here reaches any server.

class _Gateway implements ParentalConsentGateway {
  MotionDeviceConsentStatus Function() onStatus = () =>
      const MotionDeviceConsentStatus(state: MotionParentalConsent.none);
  Object? requestError;
  Object? statusError;
  Object? signUpError;
  final calls = <String>[];
  String? lastToken;
  String? lastParent;
  String? signUpToken;

  @override
  Future<MotionDeviceConsentStatus> request({
    required String deviceToken,
    required String parentEmail,
    required String locale,
  }) async {
    calls.add('request');
    lastToken = deviceToken;
    lastParent = parentEmail;
    final e = requestError;
    if (e != null) throw e;
    return const MotionDeviceConsentStatus(
      state: MotionParentalConsent.pending,
    );
  }

  @override
  Future<MotionDeviceConsentStatus> status(String deviceToken) async {
    calls.add('status');
    lastToken = deviceToken;
    final e = statusError;
    if (e != null) throw e;
    return onStatus();
  }

  @override
  Future<void> signUpUnderThirteen({
    required String email,
    required String password,
    required MotionAgeDeclaration age,
    required String deviceToken,
  }) async {
    calls.add('signUp');
    signUpToken = deviceToken;
    final e = signUpError;
    if (e != null) throw e;
  }
}

MotionDeviceConsentStatus _st(MotionParentalConsent s) =>
    MotionDeviceConsentStatus(state: s);

MotionAgeDeclaration _age() => const MotionAgeDeclaration(
  birthYear: 2018,
  birthMonth: 5,
  countryCode: 'TR',
  policyVersion: MotionAgePolicy.version,
);

void main() {
  late Directory dir;
  late _Gateway gw;
  late ConsentTokenStore store;
  late List<String> events;
  late ParentalConsentController c;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('ost-consent-');
    gw = _Gateway();
    store = ConsentTokenStore(directory: dir);
    events = [];
    c = ParentalConsentController(
      gateway: gw,
      tokenStore: store,
      markBlocked: () async {
        events.add('marker');
        await AgeGateStore(directory: dir).markBlocked();
      },
      locale: 'tr',
    );
  });
  tearDown(() {
    c.dispose();
    dir.deleteSync(recursive: true);
  });

  group('flag closed (default)', () {
    test(
      'flag is false',
      () => expect(ostinatoParentalConsentEnabled, isFalse),
    );

    testWidgets(
      'account page keeps Core defaults: no parent surface, no call',
      (tester) async {
        final h = (await tester.runAsync(() => AccountDeleteFixture.create()))!;
        final connection = (await tester.runAsync(
          () async => bindMotionAccountRuntime(
            h.runtime,
            deletionCoordinator: h.coordinator,
            clearLocalData: (_) async {},
          ),
        ))!;
        try {
          await tester.pumpWidget(
            MaterialApp(home: Builder(builder: connection.pageBuilder)),
          );
          await tester.pumpAndSettle();
          final page = tester.widget<MotionAccountPage>(
            find.byType(MotionAccountPage),
          );
          expect(page.underThirteenConsentEnabled, isFalse);
          expect(page.onUnderThirteen, isNull);
          expect(find.byType(ParentalConsentPage), findsNothing);
          expect(h.transport.consentRequests, isEmpty);
          expect(h.transport.signUpBodies, isEmpty);
        } finally {
          await tester.pumpWidget(const SizedBox());
          await tester.runAsync(() async {
            connection.disposeBinding!();
            await h.close(runtimeAlreadyDisposed: true);
          });
        }
      },
    );

    test('purchase rule: under 13 never buys, approved or not', () {
      for (final s in MotionParentalConsent.values) {
        final d = ostinatoPurchaseDecision(
          MotionAgeStatus(declaration: _decl(2018, 5), consent: s),
          DateTime(2026, 11, 16),
          ostinatoTeenPurchasePolicy,
          parentalConsentOpen: false,
        );
        expect(d.restricted, isTrue, reason: s.name);
        expect(d.storeDecides, isFalse, reason: s.name);
      }
    });
  });

  group('flag forced open: bound account page', () {
    final mem = _MemStore();
    Finder inPage(Finder f) =>
        find.descendant(of: find.byType(ParentalConsentPage), matching: f);

    Future<void> act(
      WidgetTester tester,
      FutureOr<void> Function() action,
    ) async {
      await action();
      for (var i = 0; i < 8; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 60)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    Future<AccountConnection> bind(
      WidgetTester tester,
      AccountDeleteFixture h,
      Future<void> Function() onBlocked,
    ) async => (await tester.runAsync(
      () async => bindMotionAccountRuntime(
        h.runtime,
        deletionCoordinator: h.coordinator,
        clearLocalData: (_) async {},
        parentalConsentEnabled: true,
        consentTokenStore: mem,
        onAgeBlocked: onBlocked,
      ),
    ))!;

    Future<void> close(
      WidgetTester tester,
      AccountConnection connection,
      AccountDeleteFixture h,
    ) async {
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async {
        connection.disposeBinding!();
        await h.close(runtimeAlreadyDisposed: true);
      });
    }

    testWidgets('hand-off opens the page: token, request, locale, ret marker', (
      tester,
    ) async {
      final h = (await tester.runAsync(() => AccountDeleteFixture.create()))!;
      var persisted = 0;
      final connection = await bind(tester, h, () async => persisted++);
      try {
        await tester.pumpWidget(
          MaterialApp(home: Builder(builder: connection.pageBuilder)),
        );
        await tester.pumpAndSettle();
        final page = tester.widget<MotionAccountPage>(
          find.byType(MotionAccountPage),
        );
        expect(page.underThirteenConsentEnabled, isTrue);
        expect(h.transport.consentRequests, isEmpty);
        await act(tester, () {
          page.onUnderThirteen!();
        });
        expect(find.byType(ParentalConsentPage), findsOneWidget);
        final token = (await mem.read())!;
        expect(h.transport.consentRequests.first, {
          'action': 'status',
          'deviceToken': token,
        });
        h.transport.consentAnswer = {'status': 'pending'};
        await tester.enterText(
          inPage(find.byType(TextField)).first,
          'veli@example.com',
        );
        await act(
          tester,
          () => tester.tap(
            inPage(find.widgetWithText(FilledButton, 'Send approval request')),
          ),
        );
        expect(h.transport.consentRequests.last, {
          'action': 'request_device',
          'deviceToken': token,
          'parentEmail': 'veli@example.com',
          'locale': 'en',
        });
        h.transport.consentAnswer = {'status': 'denied'};
        await act(
          tester,
          () => tester.tap(
            inPage(find.text(ParentalConsentCopy.checkApproval.$1)),
          ),
        );
        expect(persisted, 1);
        expect(find.text(ParentalConsentCopy.denied.$1), findsOneWidget);
        expect(h.transport.signUpBodies, isEmpty);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(
          MaterialApp(home: Builder(builder: connection.pageBuilder)),
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<MotionAccountPage>(find.byType(MotionAccountPage))
              .ageBlocked,
          isTrue,
        );
      } finally {
        await close(tester, connection, h);
      }
    });

    testWidgets(
      'approved: the form re-reads the approval with the token before sign-up',
      (tester) async {
        final h = (await tester.runAsync(() => AccountDeleteFixture.create()))!;
        h.transport.consentAnswer = {'status': 'approved'};
        final connection = await bind(tester, h, () async {});
        try {
          await tester.pumpWidget(
            MaterialApp(home: Builder(builder: connection.pageBuilder)),
          );
          await tester.pumpAndSettle();
          await act(tester, () {
            tester
                .widget<MotionAccountPage>(find.byType(MotionAccountPage))
                .onUnderThirteen!();
          });
          expect(find.text(ParentalConsentCopy.approved.$1), findsOneWidget);
          final token = (await mem.read())!;
          await tester.enterText(
            inPage(find.byType(TextField)).at(0),
            'cocuk@example.com',
          );
          await tester.enterText(
            inPage(find.byType(TextField)).at(1),
            'pw-pw-pw-12',
          );
          await tester.tap(inPage(find.text('Birth month')));
          await tester.pumpAndSettle();
          await tester.tap(find.text('5').last);
          await tester.pumpAndSettle();
          await tester.tap(inPage(find.text('Birth year')));
          await tester.pumpAndSettle();
          final year = DateTime.now().year;
          await tester.tap(find.text('$year').last);
          await tester.pumpAndSettle();
          await act(
            tester,
            () => tester.tap(
              inPage(find.widgetWithText(FilledButton, 'Create account')),
            ),
          );
          // Core re-reads the approval for this token right before sign-up. The
          // fixture's auth client has no PKCE storage, so the sign-up call itself
          // is covered by the fake-gateway page test above.
          expect(h.transport.consentRequests, [
            {'action': 'status', 'deviceToken': token},
            {'action': 'status', 'deviceToken': token},
          ]);
          expect(find.byType(ParentalConsentPage), findsOneWidget);
          expect(
            await mem.read(),
            token,
            reason: 'token kept: no account made',
          );
        } finally {
          await close(tester, connection, h);
        }
      },
    );
  });

  group('flag open: flow', () {
    test(
      'token is created once, persisted, and is the only stored data',
      () async {
        await c.load();
        final first = gw.lastToken!;
        expect(MotionDeviceConsentToken.isWellFormed(first), isTrue);
        final json =
            jsonDecode(
                  File(
                    '${dir.path}/ostinato.parental_consent_token.v1.json',
                  ).readAsStringSync(),
                )
                as Map<String, dynamic>;
        expect(json.keys.toSet(), {'schemaVersion', 'token'});
        expect(await ConsentTokenStore(directory: dir).readOrCreate(), first);
        expect(c.phase, ConsentPhase.needParentEmail);
        expect(await AgeGateStore(directory: dir).read(), isFalse);
      },
    );

    test(
      'request sends the stored token and parent e-mail, then pending',
      () async {
        await c.load();
        gw.onStatus = () => _st(MotionParentalConsent.pending);
        await c.sendParentEmail(' veli@example.com ');
        expect(gw.lastParent, 'veli@example.com');
        expect(gw.lastToken, await store.read());
        expect(c.phase, ConsentPhase.pending);
        expect(gw.calls.where((e) => e == 'signUp'), isEmpty);
      },
    );

    test(
      'approved: sign-up uses the token, then the token is cleared',
      () async {
        gw.onStatus = () => _st(MotionParentalConsent.approved);
        await c.load();
        expect(c.phase, ConsentPhase.approved);
        final token = (await store.read())!;
        final ok = await c.createAccount(
          email: 'cocuk@example.com',
          password: 'pw-pw-pw-1',
          age: _age(),
        );
        expect(ok, isTrue);
        expect(gw.signUpToken, token);
        expect(c.phase, ConsentPhase.accountCreated);
        expect(await store.read(), isNull);
      },
    );

    test('denied: marker is written before the result, no account', () async {
      gw.onStatus = () => _st(MotionParentalConsent.denied);
      c.addListener(() {
        if (c.phase == ConsentPhase.denied && !events.contains('phase')) {
          events.add('phase');
        }
      });
      await c.load();
      expect(events, ['marker', 'phase']);
      expect(await AgeGateStore(directory: dir).read(), isTrue);
      final marker = jsonDecode(
        File('${dir.path}/ostinato.age_gate.v1.json').readAsStringSync(),
      );
      expect(marker, {'schemaVersion': 1, 'blocked': true});
      expect(
        await c.createAccount(email: 'a@b.c', password: 'x', age: _age()),
        isFalse,
      );
      expect(gw.calls.contains('signUp'), isFalse);
    });

    test('expired: no marker, the child can ask again', () async {
      gw.onStatus = () => _st(MotionParentalConsent.expired);
      await c.load();
      expect(c.phase, ConsentPhase.expired);
      expect(events, isEmpty);
      expect(await AgeGateStore(directory: dir).read(), isFalse);
      await c.sendParentEmail('veli@example.com');
      expect(c.phase, ConsentPhase.pending);
    });

    test(
      'fail-closed: network error or unknown answer gives no permission',
      () async {
        gw.statusError = Exception('offline');
        await c.load();
        expect(c.phase, ConsentPhase.unavailable);
        gw.statusError = null;
        gw.onStatus = () => const MotionDeviceConsentStatus.unavailable();
        await c.refresh();
        expect(c.phase, ConsentPhase.unavailable);
        expect(
          await c.createAccount(email: 'a@b.c', password: 'x', age: _age()),
          isFalse,
        );
        expect(gw.calls.contains('signUp'), isFalse);
        expect(await AgeGateStore(directory: dir).read(), isFalse);
      },
    );

    test('unverified approved answer is not an approval', () async {
      gw.onStatus = () => const MotionDeviceConsentStatus(
        state: MotionParentalConsent.approved,
        verified: false,
      );
      await c.load();
      expect(c.phase, ConsentPhase.unavailable);
    });

    test(
      'sign-up re-reads the state; a changed answer blocks the account',
      () async {
        gw.onStatus = () => _st(MotionParentalConsent.approved);
        await c.load();
        gw.onStatus = () => _st(MotionParentalConsent.denied);
        expect(
          await c.createAccount(email: 'a@b.c', password: 'x', age: _age()),
          isFalse,
        );
        expect(gw.calls.contains('signUp'), isFalse);
        expect(c.phase, ConsentPhase.denied);
        expect(await AgeGateStore(directory: dir).read(), isTrue);
      },
    );

    test(
      'sign-up refused by the server leaves approval state, no success',
      () async {
        gw.onStatus = () => _st(MotionParentalConsent.approved);
        await c.load();
        gw.signUpError = Exception('P0013');
        expect(
          await c.createAccount(email: 'a@b.c', password: 'x', age: _age()),
          isFalse,
        );
        expect(c.phase, ConsentPhase.approved);
        expect(c.notice, ConsentNotice.unavailable);
      },
    );

    test('refusal reasons map to neutral notices', () async {
      await c.load();
      final cases = {
        MotionConsentRequestError.tooSoon: ConsentNotice.tooSoon,
        MotionConsentRequestError.dailyLimit: ConsentNotice.dailyLimit,
        MotionConsentRequestError.invalidParentEmail:
            ConsentNotice.invalidEmail,
        MotionConsentRequestError.parentEmailIsTeen: ConsentNotice.invalidEmail,
        MotionConsentRequestError.mailUnavailable: ConsentNotice.unavailable,
        MotionConsentRequestError.notRequired: ConsentNotice.unavailable,
      };
      for (final e in cases.entries) {
        gw.requestError = MotionConsentRequestRefused(e.key);
        await c.sendParentEmail('veli@example.com');
        expect(c.notice, e.value, reason: e.key.name);
        expect(c.phase, ConsentPhase.needParentEmail, reason: e.key.name);
      }
      gw.requestError = Exception('lost reply');
      await c.sendParentEmail('veli@example.com');
      expect(c.notice, ConsentNotice.unavailable);
    });

    test('alreadyApproved / alreadyDecided re-read the real state', () async {
      await c.load();
      gw.requestError = const MotionConsentRequestRefused(
        MotionConsentRequestError.alreadyApproved,
      );
      gw.onStatus = () => _st(MotionParentalConsent.approved);
      await c.sendParentEmail('veli@example.com');
      expect(c.phase, ConsentPhase.approved);
      expect(gw.calls.contains('signUp'), isFalse);
    });

    test('invalidDeviceToken renews the token', () async {
      await c.load();
      final old = (await store.read())!;
      gw.requestError = const MotionConsentRequestRefused(
        MotionConsentRequestError.invalidDeviceToken,
      );
      await c.sendParentEmail('veli@example.com');
      expect((await store.read())!, isNot(old));
      expect(c.notice, ConsentNotice.unavailable);
    });

    test('damaged token file is not trusted', () async {
      File(
        '${dir.path}/ostinato.parental_consent_token.v1.json',
      ).writeAsStringSync('{"schemaVersion":1,"token":"short","extra":1}');
      expect(await store.read(), isNull);
    });

    testWidgets('page: denied shows the result and no form', (tester) async {
      gw.onStatus = () => _st(MotionParentalConsent.denied);
      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: ParentalConsentPage(
              controller: c,
              clock: () => DateTime(2026, 11, 16),
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();
      expect(find.text(ParentalConsentCopy.denied.$1), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('page: approved shows the form; create calls sign-up', (
      tester,
    ) async {
      gw.onStatus = () => _st(MotionParentalConsent.approved);
      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: ParentalConsentPage(
              controller: c,
              clock: () => DateTime(2026, 11, 16),
              countryCode: 'tr',
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();
      expect(find.text(ParentalConsentCopy.approved.$1), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(2));
      await tester.enterText(find.byType(TextField).at(0), 'c@example.com');
      await tester.enterText(find.byType(TextField).at(1), 'pw-pw-pw-12');
      await tester.tap(find.text('Birth month'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('5').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Birth year'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2018').last);
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();
      expect(gw.calls, contains('signUp'));
      expect(gw.signUpToken, isNotNull);
      expect(c.phase, ConsentPhase.accountCreated);
    });

    test(
      'marker write failure: token and denied result kept, retried',
      () async {
        var fail = true;
        var attempts = 0;
        final c2 = ParentalConsentController(
          gateway: gw,
          tokenStore: store,
          markBlocked: () async {
            attempts++;
            if (fail) throw const FileSystemException('disk');
            await AgeGateStore(directory: dir).markBlocked();
          },
          locale: 'en',
        );
        addTearDown(c2.dispose);
        gw.onStatus = () => _st(MotionParentalConsent.denied);
        await c2.load();
        expect(c2.phase, ConsentPhase.denied);
        expect(await store.read(), isNotNull, reason: 'token kept');
        gw.onStatus = () => _st(MotionParentalConsent.none);
        await c2.refresh();
        expect(c2.phase, ConsentPhase.denied);
        expect(
          await c2.createAccount(email: 'a@b.c', password: 'x', age: _age()),
          isFalse,
        );
        fail = false;
        await c2.refresh();
        expect(attempts, 3);
        expect(await AgeGateStore(directory: dir).read(), isTrue);
        expect(
          await store.read(),
          isNull,
          reason: 'token cleared after marker',
        );
        expect(c2.phase, ConsentPhase.denied);
      },
    );

    test('lost reply: neutral notice, never "nothing changed"', () async {
      await c.load();
      gw.requestError = const MotionOperationUnknown(
        MotionAccountOperation.deviceConsent,
      );
      await c.sendParentEmail('veli@example.com');
      expect(c.notice, ConsentNotice.unavailable);
      expect(c.phase, ConsentPhase.needParentEmail);
      final banned = RegExp(
        r'nothing was changed|hiçbir şey değişmedi',
        caseSensitive: false,
      );
      expect(banned.hasMatch(ParentalConsentCopy.unavailable.$1), isFalse);
      expect(banned.hasMatch(ParentalConsentCopy.unavailable.$2), isFalse);
    });

    test('dispose during an in-flight call does not notify', () async {
      final c3 = ParentalConsentController(
        gateway: gw,
        tokenStore: store,
        markBlocked: () async {},
        locale: 'en',
      );
      gw.onStatus = () => _st(MotionParentalConsent.pending);
      final inFlight = c3.load();
      c3.dispose();
      await inFlight;
      expect(c3.phase, ConsentPhase.pending);
    });
  });

  group('membership page, flag open', () {
    Future<void> pump(
      WidgetTester tester, {
      required MotionParentalConsent consent,
      required bool open,
    }) async {
      final client = SupabaseClient(
        'https://motion.example.invalid',
        'public-test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      await client.auth.setInitialSession(
        jsonEncode({
          'access_token': 'local-test-token',
          'token_type': 'bearer',
          'user': {
            'id': '11111111-1111-1111-1111-111111111111',
            'aud': 'authenticated',
            'created_at': '2026-09-24T00:00:00Z',
            'app_metadata': <String, dynamic>{},
          },
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.iOS),
          home: OstinatoMembershipPage(
            account: _KidAccount(client, consent, DateTime.now().year - 8),
            purchaseAdapter: _OneOffer(),
            serverAdapter: _NoServer(),
            parentalConsentOpen: open,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('approved under 13 sees the plan, store decides the payment', (
      tester,
    ) async {
      await pump(tester, consent: MotionParentalConsent.approved, open: true);
      expect(find.widgetWithText(FilledButton, 'Choose'), findsWidgets);
      expect(
        find.text(
          MotionAccountLocalizations(
            const Locale('en'),
          ).text(MotionAccountString.storeFamilyControlsNote),
        ),
        findsOneWidget,
      );
    });

    for (final s in [
      MotionParentalConsent.none,
      MotionParentalConsent.pending,
      MotionParentalConsent.denied,
      MotionParentalConsent.expired,
      MotionParentalConsent.withdrawn,
    ]) {
      testWidgets('under 13 with consent ${s.name} sees no purchase', (
        tester,
      ) async {
        await pump(tester, consent: s, open: true);
        expect(find.widgetWithText(FilledButton, 'Choose'), findsNothing);
      });
    }

    testWidgets('flag closed: approved under 13 still cannot buy', (
      tester,
    ) async {
      await pump(tester, consent: MotionParentalConsent.approved, open: false);
      expect(find.widgetWithText(FilledButton, 'Choose'), findsNothing);
    });
  });

  group('purchase rule, flag open', () {
    final today = DateTime(2026, 11, 16);
    ({bool restricted, bool storeDecides}) rule(
      MotionParentalConsent s, {
      int year = 2018,
    }) => ostinatoPurchaseDecision(
      MotionAgeStatus(declaration: _decl(year, 5), consent: s),
      today,
      ostinatoTeenPurchasePolicy,
      parentalConsentOpen: true,
    );

    test('under 13 buys only when approved, through the store', () {
      for (final s in MotionParentalConsent.values) {
        final d = rule(s);
        if (s == MotionParentalConsent.approved) {
          expect(d.restricted, isFalse);
          expect(d.storeDecides, isTrue);
        } else {
          expect(d.restricted, isTrue, reason: s.name);
        }
      }
    });

    test('teen rule is unchanged by the flag', () {
      final off = ostinatoPurchaseDecision(
        MotionAgeStatus(
          declaration: _decl(2011, 5),
          consent: MotionParentalConsent.none,
        ),
        today,
        ostinatoTeenPurchasePolicy,
        parentalConsentOpen: false,
      );
      final on = rule(MotionParentalConsent.none, year: 2011);
      expect(on, off);
    });

    test('unknown age status stays as before (not restricted here)', () {
      expect(
        ostinatoPurchaseDecision(
          null,
          today,
          ostinatoTeenPurchasePolicy,
          parentalConsentOpen: true,
        ),
        (restricted: false, storeDecides: false),
      );
    });
  });

  test('copy: neutral wording, no placeholders', () {
    final banned = RegExp(
      r'\bwrong\b|\bsoon\b|yanlış|yakında',
      caseSensitive: false,
    );
    for (final (en, tr) in ParentalConsentCopy.all) {
      expect(banned.hasMatch(en), isFalse, reason: en);
      expect(en.contains('YULA'), isFalse);
      expect(banned.hasMatch(tr), isFalse, reason: tr);
      expect(en.contains('{'), isFalse);
    }
  });
}

MotionAgeDeclaration _decl(int y, int m) => MotionAgeDeclaration(
  birthYear: y,
  birthMonth: m,
  countryCode: 'TR',
  policyVersion: MotionAgePolicy.version,
);

class _KidAccount extends MotionAccountClient {
  _KidAccount(SupabaseClient client, this._consent, this._birthYear)
    : super(
        supabase: client,
        app: MotionApp.ostinato,
        emailRedirectTo: 'com.yulalab.ostinato://auth/callback',
      );
  final MotionParentalConsent _consent;
  final int _birthYear;

  @override
  Future<MotionMembershipStatus> membershipStatus() async =>
      const MotionMembershipStatus(active: false, anyActive: false);

  @override
  Future<MotionAgeStatus> ageStatus() async =>
      MotionAgeStatus(declaration: _decl(_birthYear, 1), consent: _consent);
}

class _OneOffer implements PurchaseAdapter {
  @override
  Stream<StorePurchaseUpdate> get updates => const Stream.empty();
  @override
  Future<List<StoreProductRef>> fetchProducts(List<String> ids) async => [
    StoreProductRef(
      productId: 'com.yulalab.ostinato.individual.monthly',
      platform: StorePlatform.ios,
      planId: 'monthly',
      localizedPrice: '1',
    ),
  ];
  @override
  Future<void> startPurchase(StoreProductRef offer) async {}
  @override
  Future<void> restore() async {}
  @override
  Future<void> complete(StorePurchaseUpdate update) async {}
}

class _NoServer implements ServerAdapter {
  @override
  Future<EntitlementStatus?> verify(StorePurchaseEvidence evidence) async =>
      null;
}

final class _MemStore implements ConsentTokenStorage {
  String? _token;
  @override
  Future<String?> read() async => _token;
  @override
  Future<String> readOrCreate() async =>
      _token ??= MotionDeviceConsentToken.generate();
  @override
  Future<String> renew() async => _token = MotionDeviceConsentToken.generate();
  @override
  Future<void> clear() async => _token = null;
}
