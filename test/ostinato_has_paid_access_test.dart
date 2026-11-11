// OST-UX-05b2: the side-effect free paid-access read the stage uses.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:motion_account/motion_account.dart';
import 'package:ostinato/app/ostinato_paid_access.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _a = '11111111-1111-1111-1111-111111111111';
const _b = '22222222-2222-2222-2222-222222222222';

String _session(String id) => jsonEncode({
  'access_token': 'local-test-token',
  'token_type': 'bearer',
  'user': {
    'id': id,
    'aud': 'authenticated',
    'created_at': '2026-09-24T00:00:00Z',
    'app_metadata': <String, dynamic>{},
  },
});

class _Account extends MotionAccountClient {
  _Account(SupabaseClient client, this.onAsk)
    : super(
        supabase: client,
        app: MotionApp.ostinato,
        emailRedirectTo: 'com.yulalab.ostinato://auth/callback',
      );

  final Future<bool> Function(_Account) onAsk;
  int asked = 0;

  @override
  Future<bool> hasActiveMembership() {
    asked++;
    return onAsk(this);
  }
}

Future<_Account> _account(
  Future<bool> Function(_Account) onAsk, {
  bool signedIn = true,
}) async {
  final client = SupabaseClient(
    'https://motion.example.invalid',
    'public-test-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
  if (signedIn) await client.auth.setInitialSession(_session(_a));
  return _Account(client, onAsk);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('no session: false, and the server is not asked', () async {
    final acc = await _account((_) async => true, signedIn: false);
    expect(await ostinatoHasPaidAccess(acc, salesAvailable: true), isFalse);
    expect(acc.asked, 0);
  });

  test('the server throws: false', () async {
    final acc = await _account((_) async => throw StateError('down'));
    expect(await ostinatoHasPaidAccess(acc, salesAvailable: true), isFalse);
  });

  test('the user changes while asking: false', () async {
    final acc = await _account((a) async {
      await a.supabase.auth.setInitialSession(_session(_b));
      return true;
    });
    expect(await ostinatoHasPaidAccess(acc, salesAvailable: true), isFalse);
  });

  test('the server says active: true', () async {
    final acc = await _account((_) async => true);
    expect(await ostinatoHasPaidAccess(acc, salesAvailable: true), isTrue);
    expect(acc.asked, 1);
  });

  test('the server says not active: false', () async {
    final acc = await _account((_) async => false);
    expect(await ostinatoHasPaidAccess(acc, salesAvailable: true), isFalse);
  });

  test('sales closed: nothing is gated, no sign-in needed', () async {
    final acc = await _account((_) async => false, signedIn: false);
    expect(await ostinatoHasPaidAccess(acc, salesAvailable: false), isTrue);
  });
}
