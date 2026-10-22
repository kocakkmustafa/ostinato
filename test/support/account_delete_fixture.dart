import 'dart:async';
import 'dart:convert';
import 'dart:io';

// Disposable stage fixture uses root-selected cached http1.6.0, no network.
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:motion_account/motion_account.dart';
import 'package:ostinato/app/account_connection.dart';
import 'package:ostinato/app/account_data_directory.dart';
import 'package:ostinato/app/account_ownership_epoch.dart';
import 'package:ostinato/app/motion_account_bootstrap.dart';
import 'package:ostinato/app/ownership_guarded_account_client.dart';
// Disposable stage fixture uses root-selected cached supabase_flutter2.17.2.
import 'package:supabase_flutter/supabase_flutter.dart';

const aliceUuid = '00000000-0000-4000-8000-000000000001';
const bobUuid = '00000000-0000-4000-8000-000000000002';

Map<String, Object> _user(String id) => {
  'id': id,
  'aud': 'authenticated',
  'created_at': '2026-09-24T00:00:00Z',
  'app_metadata': <String, Object>{},
};

String _session(String id, String token) => jsonEncode({
  'access_token': token,
  'refresh_token': 'local-refresh',
  'token_type': 'bearer',
  'expires_in': 3600,
  'user': _user(id),
});

http.Response _json(Object body, {int status = 200}) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

/// Controls only HTTP transport. Auth/runtime/client behavior is actual Core.
final class AccountDeleteTransport {
  AccountDeleteTransport({this.delayed = false});

  final bool delayed;
  final started = Completer<void>();
  final response = Completer<http.Response>();
  final List<http.Request> deleteRequests = [];
  int get deleteCalls => deleteRequests.length;
  String? deleteAuthorization;
  Map<String, dynamic>? deleteBody;
  Object receipt = <String, Object>{'deleted': true, 'userId': aliceUuid};
  int receiptStatus = 200;
  String signInUserId = aliceUuid;
  String signInAccessToken = 'A-session2';
  final Set<String> permanentReceiptIds = {};
  final List<String> permanentReceiptQueries = [];
  bool aliceUserMissing = false;

  Future<http.Response> handle(http.Request request) async {
    final response = await _handle(request);
    return http.Response.bytes(response.bodyBytes, response.statusCode,
        headers: response.headers, request: request);
  }

  Future<http.Response> _handle(http.Request request) async {
    if (request.url.path.endsWith('/motion-delete-account')) {
      deleteRequests.add(request);
      deleteAuthorization = request.headers['Authorization'];
      deleteBody = jsonDecode(request.body) as Map<String, dynamic>;
      if (!started.isCompleted) started.complete();
      if (delayed) return response.future;
      return _json(receipt, status: receiptStatus);
    }
    if (request.url.path.endsWith('/motion_was_account_deleted')) {
      final id = (jsonDecode(request.body) as Map<String, dynamic>)['p_user_id'] as String;
      permanentReceiptQueries.add(id);
      return _json(permanentReceiptIds.contains(id));
    }
    if (request.url.path.endsWith('/user')) {
      final token = request.headers['Authorization'] ?? '';
      if (aliceUserMissing && !token.contains('B-session')) {
        return _json(
          <String, Object>{'error_code': 'user_not_found', 'msg': 'User not found'},
          status: 403,
        );
      }
      return _json(_user(token.contains('B-session') ? bobUuid : aliceUuid));
    }
    if (request.url.path.endsWith('/token')) {
      if (request.url.queryParameters['grant_type'] == 'password') {
        return _json(jsonDecode(_session(signInUserId, signInAccessToken)));
      }
      return _json(jsonDecode(_session(aliceUuid, 'A-refreshed')));
    }
    if (request.url.path.endsWith('/motion_profiles')) return _json(<Object>[]);
    // Core 5832031 account page age read: a declared adult without consent row.
    if (request.method == 'GET' &&
        request.url.path.endsWith('/motion_age_declarations')) {
      return _json(<Object>[
        <String, Object>{
          'birth_year_month': '1990-01',
          'country': 'TR',
          'policy_version': '2026-10-21.1',
        },
      ]);
    }
    if (request.method == 'GET' &&
        request.url.path.endsWith('/motion_parental_consents')) {
      return _json(<Object>[]);
    }
    return _json(<String, Object>{});
  }

  void confirm() {
    if (!response.isCompleted) {
      response.complete(_json(receipt, status: receiptStatus));
    }
  }
}

/// Records completion of the actual shared client operation. No fake deletion
/// or ownership decision is implemented here; Core still dispatches its HTTP.
final class _TrackedDeleteClient extends MotionAccountClient {
  _TrackedDeleteClient(this._delegate, this._record)
    : super(
        supabase: _delegate.supabase,
        app: _delegate.app,
        emailRedirectTo: _delegate.emailRedirectTo,
      );

  final MotionAccountClient _delegate;
  final void Function(Future<void>) _record;

  @override
  Future<void> deleteCommonAccount({
    Future<void> Function(String userId)? afterRemoteDelete,
  }) {
    final operation = _delegate.deleteCommonAccount(
      afterRemoteDelete: afterRemoteDelete,
    );
    _record(operation);
    return operation;
  }
}

final class AccountDeleteFixture {
  AccountDeleteFixture._(
    this.client,
    this.runtime,
    this.ownership,
    this.connection,
    this.coordinator,
    this.root,
    this.transport,
    this._ownsRoot,
  );

  final SupabaseClient client;
  final MotionAccountRuntime runtime;
  final AccountOwnershipEpoch ownership;
  final AccountConnection connection;
  final AccountDeletionCoordinator coordinator;
  final Directory root;
  final AccountDeleteTransport transport;
  final bool _ownsRoot;
  int coreDeleteCalls = 0;
  int coreDeletesSettled = 0;
  final List<(String, String?, MotionIdentityPhase)> confirmedEntries = [];
  final List<Future<void>> confirmedCleanups = [];
  final List<Future<void>> filesOnlyCleanups = [];
  final confirmedStarted = Completer<void>();

  void _recordConfirmed(String id, Future<void> operation) {
    confirmedEntries.add((id, runtime.userId.value, runtime.phase.value));
    confirmedCleanups.add(operation);
    if (!confirmedStarted.isCompleted) confirmedStarted.complete();
    // Retain the original Future and error; observe its early failure only.
    operation.then<void>((_) {}, onError: (Object _, StackTrace _) {});
  }

  void _recordDelete(Future<void> operation) {
    ++coreDeleteCalls;
    // Observe both outcomes without creating an unhandled error Future. The
    // caller still receives the original Core operation and its original error.
    operation.then<void>(
      (_) {
        ++coreDeletesSettled;
      },
      onError: (Object _, StackTrace _) {
        ++coreDeletesSettled;
      },
    );
  }

  static Future<AccountDeleteFixture> create({
    bool delayed = false,
    Directory? supportRoot,
    String initialUserId = aliceUuid,
    String initialToken = 'A-session1',
    void Function(AccountDeleteFixture)? beforeAuthReplay,
    Stream<AuthState> Function(MotionAccountRuntime)? ownerAuthChanges,
  }) async {
    final transport = AccountDeleteTransport(delayed: delayed);
    final client = SupabaseClient(
      'https://motion.example.invalid',
      'public-test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient(transport.handle),
    );
    final root = supportRoot ??
        await Directory.systemTemp.createTemp('ostinato-delete-owner-');
    await client.auth.setInitialSession(_session(initialUserId, initialToken));
    // Establish the same root authority before Core starts its receipt scan.
    final coordinator = AccountDeletionCoordinator.forRoot(root);
    AccountDeleteFixture? callbackFixture;
    late final MotionAccountRuntime runtime;
    runtime = MotionAccountRuntime.forTesting(
      client: client,
      app: MotionApp.ostinato,
      onDeletedAccount: (id) {
        final operation = coordinator.eraseConfirmed(id);
        callbackFixture?._recordConfirmed(id, operation);
        return operation;
      },
      localAccountIds: () => localAccountIds(root),
      // Genuine public RPC transport; no Core phase or receipt hook mutation.
      wasAccountDeleted: (id) async {
        final result = await client.rpc(
          'motion_was_account_deleted',
          params: {'p_user_id': id},
        );
        if (result is! bool) throw StateError('Invalid fixture receipt');
        return result;
      },
    );
    await runtime.refreshIdentity();
    await runtime.reconcileDeletedLocalAccounts();
    await Future<void>.delayed(Duration.zero);
    final connection = bindMotionAccountRuntime(
      runtime,
      clearLocalData: (id) => deleteAccountData(root, id),
      deletionCoordinator: coordinator,
      ownerAuthChanges: ownerAuthChanges?.call(runtime),
    );
    final ownership = connection.identityBoundary! as AccountOwnershipEpoch;
    final fixture = AccountDeleteFixture._(
      client,
      runtime,
      ownership,
      connection,
      coordinator,
      root,
      transport,
      supportRoot == null,
    );
    callbackFixture = fixture;
    // Runs before the public stream's async seed replay. A public session
    // replacement here exercises raw Auth changing before its notification.
    beforeAuthReplay?.call(fixture);
    return fixture;
  }

  OwnershipGuardedAccountClient pageClient() => OwnershipGuardedAccountClient(
    delegate: _TrackedDeleteClient(runtime.account, _recordDelete),
    ownership: ownership,
    pageOwnership: ownership.capturePage(),
  );

  Future<void> replace(String id, String token) async {
    await client.auth.setInitialSession(_session(id, token));
    await Future<void>.delayed(Duration.zero);
    await runtime.refreshIdentity();
    await Future<void>.delayed(Duration.zero);
  }

  Future<void> signOut() async {
    await client.auth.signOut(scope: SignOutScope.local);
    await Future<void>.delayed(Duration.zero);
  }

  Future<void> signIn(String id, String token) async {
    transport.signInUserId = id;
    transport.signInAccessToken = token;
    await runtime.account.signIn(
      email: 'local-fixture@example.invalid',
      password: 'local-fixture-password',
    );
    await Future<void>.delayed(Duration.zero);
    await runtime.refreshIdentity();
    await Future<void>.delayed(Duration.zero);
  }

  Future<void> seedFiles() async {
    for (final id in [aliceUuid, bobUuid]) {
      final directory = accountDataDirectory(root, id);
      await directory.create(recursive: true);
      await File('${directory.path}/sentinel.txt').writeAsString(id);
    }
    await File('${root.path}/guest.txt').writeAsString('guest-preserved');
  }

  Future<void> clearLocal(String id) {
    final operation = deleteAccountData(root, id);
    filesOnlyCleanups.add(operation);
    return operation;
  }

  Future<void> scanReceipts() => runtime.reconcileDeletedLocalAccounts();

  void disposeBinding() => connection.disposeBinding!();

  Future<void> close({bool runtimeAlreadyDisposed = false}) async {
    if (runtimeAlreadyDisposed) {
      ownership.dispose();
    } else {
      disposeBinding();
    }
    client.dispose();
    if (_ownsRoot && await root.exists()) await root.delete(recursive: true);
  }
}
