import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:motion_account/motion_account.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthChangeEvent, AuthState, Session;

import 'account_connection.dart';
import 'account_data_directory.dart';

/// Captured when the account page is created, before Core opens its dialog.
final class AccountPageOwnership {
  AccountPageOwnership._(this.owner, this.epoch, this.userId);

  final AccountOwnershipEpoch owner;
  final int epoch;
  final String? userId;
}

/// Captured before the shared client dispatches its account deletion.
final class AccountDeletionOwnership {
  AccountDeletionOwnership._(this.owner, this.epoch, this.userId, this.accessToken);

  final AccountOwnershipEpoch owner;
  final int epoch;
  final String? userId;
  final String? accessToken;
}

/// Per-support-root local cleanup authority. A verified UUID remains denied
/// for this isolate; raw Auth changes do not establish a new resource grant.
final class AccountDeletionCoordinator {
  AccountDeletionCoordinator._(this.supportRoot);

  static final Map<String, AccountDeletionCoordinator> _roots = {};

  static AccountDeletionCoordinator forRoot(Directory supportRoot) {
    final path = supportRoot.absolute.uri.normalizePath().toFilePath()
        .replaceAll(RegExp(r'/+'), '/')
        .replaceFirst(RegExp(r'/+$'), '');
    return _roots.putIfAbsent(
      path,
      () => AccountDeletionCoordinator._(Directory(path)),
    );
  }

  final Directory supportRoot;
  final Set<String> _denied = {};
  final Map<String, _DeletionTicket> _tickets = {};
  final Set<AccountOwnershipEpoch> _bindings = {};
  final Set<_ResourceRegistration> _resources = {};
  final Expando<_ResourceRegistration> _registrations =
      Expando<_ResourceRegistration>('account resource lifetime');

  bool isDenied(String userId) => _denied.contains(userId.toLowerCase());

  void _attach(AccountOwnershipEpoch binding) => _bindings.add(binding);
  void _detach(AccountOwnershipEpoch binding) => _bindings.remove(binding);

  _ResourceRegistration _register({
    required AccountResourceDrain resource,
    required String? accountUserId,
    required bool isGuest,
    required bool hasNamespace,
    required int hostEpoch,
    required bool denied,
  }) {
    final existing = _registrations[resource];
    if (existing != null) return existing;
    final record = _ResourceRegistration(
      coordinator: this,
      resource: resource,
      accountUserId: accountUserId,
      isGuest: isGuest,
      hasNamespace: hasNamespace,
      capturedHostEpoch: hostEpoch,
    );
    // Identity and the stable promise exist before a denied hook can reenter.
    // Keep this association after success; one actor cannot be retagged as B.
    _registrations[resource] = record;
    _resources.add(record);
    if (denied) {
      final drain = record.retireAndDrain();
      final ticket = accountUserId == null ? null : _tickets[accountUserId];
      if (ticket != null && !ticket.settled) ticket.track(drain);
      _observe(drain);
    }
    return record;
  }

  /// No async wrapper: pending and successful callers receive the same Future.
  /// A settled failed attempt can be retried by a later authoritative callback.
  Future<void> eraseConfirmed(
    String confirmedUserId, {
    Future<void> Function(String userId)? filesOnlyCleanup,
  }) {
    // Use the exact existing directory validator before publishing authority.
    accountDataDirectory(supportRoot, confirmedUserId);
    final id = confirmedUserId.toLowerCase();
    final existing = _tickets[id];
    if (existing != null && !existing.failed) return existing.future;

    final ticket = _DeletionTicket();
    _tickets[id] = ticket;
    _denied.add(id);
    // Root-owned forthcoming API: tombstone and reserve Q synchronously, behind
    // admitted file IO, with P unresolved until real media proof is available.
    final erase = deleteAccountData(
      supportRoot,
      id,
      beforeErase: ticket.media.future,
    );
    final eraseOutcome = _observe(erase);
    _observe(ticket.media.future);

    for (final binding in _bindings.toList()) {
      binding._retireConfirmedNamespace(id);
    }
    for (final record in _resources.toList()) {
      if (record.accountUserId == id) ticket.track(record.retireAndDrain());
    }
    // D is started and observed before invoking F. F may join Q, but D must
    // never wait for F/Q/T, including when a callback fails or reenters.
    final mediaOutcome = _observe(ticket.drainResources());
    unawaited(mediaOutcome.then<void>((outcome) {
      if (outcome.error == null) {
        ticket.media.complete();
      } else {
        ticket.media.completeError(outcome.error!, outcome.stack!);
      }
    }));
    final files = Future<void>.sync(
      () => filesOnlyCleanup?.call(id) ?? Future<void>.value(),
    );
    final filesOutcome = _observe(files);
    unawaited(_finishTicket(ticket, mediaOutcome, eraseOutcome, filesOutcome));
    return ticket.future;
  }

  Future<void> _finishTicket(
    _DeletionTicket ticket,
    Future<_CleanupOutcome> media,
    Future<_CleanupOutcome> erase,
    Future<_CleanupOutcome> files,
  ) async {
    // Both outcomes were observed immediately. Keep T pending until Q/F settle,
    // even if D already failed while an admitted writer still holds the queue.
    final mediaResult = await media;
    final eraseResult = await erase;
    final filesResult = await files;
    final result = mediaResult.error != null
        ? mediaResult
        : eraseResult.error != null ? eraseResult : filesResult;
    ticket.settled = true;
    if (result.error != null) {
      ticket.failed = true;
      ticket.completion.completeError(result.error!, result.stack!);
    } else {
      ticket.completion.complete();
    }
  }

  static Future<_CleanupOutcome> _observe(Future<void> operation) =>
      operation.then<_CleanupOutcome>(
        (_) => const _CleanupOutcome(),
        onError: (Object error, StackTrace stack) =>
            _CleanupOutcome(error: error, stack: stack),
      );
}

final class _CleanupOutcome {
  const _CleanupOutcome({this.error, this.stack});
  final Object? error;
  final StackTrace? stack;
}

final class _DeletionTicket {
  final completion = Completer<void>();
  final media = Completer<void>();
  final Set<Future<void>> _drains = {};
  bool settled = false;
  bool failed = false;

  Future<void> get future => completion.future;

  void track(Future<void> drain) {
    _drains.add(drain);
    // Observe early errors even if a preceding exact close is still pending.
    AccountDeletionCoordinator._observe(drain);
  }

  Future<void> drainResources() async {
    // F runs synchronously after D starts. Include any same-call denied
    // registration before declaring an initially empty set quiescent.
    await Future<void>.value();
    final seen = <Future<void>>{};
    _CleanupOutcome? firstFailure;
    while (true) {
      final batch = _drains.where((drain) => !seen.contains(drain)).toList();
      if (batch.isEmpty) {
        final failure = firstFailure;
        if (failure != null) {
          Error.throwWithStackTrace(failure.error!, failure.stack!);
        }
        return;
      }
      seen.addAll(batch);
      // One failed batch must not skip a late/reentrant registered close.
      // Retain its first error/stack while every new exact proof is joined.
      await Future.wait(batch.map((drain) =>
        AccountDeletionCoordinator._observe(drain).then<void>((outcome) {
          if (firstFailure == null && outcome.error != null) {
            firstFailure = outcome;
          }
        }),
      ));
    }
  }
}

final class _ResourceRegistration implements AccountResourceDrainRegistration {
  _ResourceRegistration({
    required this.coordinator,
    required this.resource,
    required this.accountUserId,
    required this.isGuest,
    required this.hasNamespace,
    required this.capturedHostEpoch,
  });

  final AccountDeletionCoordinator coordinator;
  final AccountResourceDrain resource;
  @override
  final String? accountUserId;
  @override
  final bool isGuest;
  @override
  final bool hasNamespace;
  @override
  final int capturedHostEpoch;
  final _completion = Completer<void>();
  bool _started = false;

  @override
  Future<void> retireAndDrain() {
    if (_started) return _completion.future;
    _started = true;
    try {
      resource.retire();
    } catch (error, stack) {
      _completion.completeError(error, stack);
      return _completion.future;
    }
    // Wait only after the synchronous retirement hook has returned. Failed or
    // pending records remain remembered across binding/epoch disposal.
    unawaited(Future<void>.sync(resource.waitForClosed).then<void>(
      (_) {
        coordinator._resources.remove(this);
        _completion.complete();
      },
      onError: (Object error, StackTrace stack) =>
          _completion.completeError(error, stack),
    ));
    return _completion.future;
  }
}

/// Retirement and deny-only consumption of public Core state. Core alone
/// verifies identity; no raw Session event clears a confirmed UUID denial.
final class AccountOwnershipEpoch extends ChangeNotifier
    implements ValueListenable<bool>, AccountResourceDrainRegistry {
  AccountOwnershipEpoch({
    required MotionAccountRuntime runtime,
    required AccountDeletionCoordinator deletionCoordinator,
    Stream<AuthState>? ownerAuthChanges,
  }) : _runtime = runtime,
       _coordinator = deletionCoordinator,
       _seedSession = runtime.account.supabase.auth.currentSession,
       _observedSession = runtime.account.supabase.auth.currentSession,
       _observedUserId = runtime.account.currentUser?.id,
       _observedAccessToken =
           runtime.account.supabase.auth.currentSession?.accessToken {
    _coordinator._attach(this);
    _runtime.userId.addListener(_retireBoundary);
    _runtime.phase.addListener(_retireBoundary);
    _runtime.passwordRecovery.addListener(_retireBoundary);
    _authSubscription = (ownerAuthChanges ?? _runtime.account.authChanges).listen(
      _onAuthChanged,
      onError: (Object _, StackTrace _) => _retireBoundary(),
    );
  }

  final MotionAccountRuntime _runtime;
  final AccountDeletionCoordinator _coordinator;
  late final StreamSubscription<AuthState> _authSubscription;
  Session? _seedSession;
  Session? _observedSession;
  String? _observedUserId;
  String? _observedAccessToken;
  int _epoch = 0;
  bool _authObserved = false;
  bool _disposed = false;

  int get revision => _epoch;

  String? get _accountNamespace =>
      _runtime.isCurrentSessionVerified
          ? _runtime.userId.value?.toLowerCase()
          : null;
  bool get _guestNamespace =>
      !_runtime.isDisposed &&
      _runtime.phase.value == MotionIdentityPhase.signedOut &&
      _runtime.userId.value == null &&
      _runtime.account.supabase.auth.currentSession == null;

  @override
  bool get value {
    if (_disposed) return false;
    final id = _accountNamespace;
    return id != null ? !_coordinator.isDenied(id) : _guestNamespace;
  }

  @override
  AccountResourceDrainRegistration registerResource({
    required AccountResourceDrain resource,
  }) {
    final existing = _coordinator._registrations[resource];
    if (existing != null) return existing;
    // Public Core grants supply immutable metadata. Unavailable/null is not
    // guest; raw Auth/currentUser is never used to relabel native resources.
    final id = _disposed ? null : _accountNamespace;
    final guest = !_disposed && _guestNamespace;
    return _coordinator._register(
      resource: resource,
      accountUserId: id,
      isGuest: guest,
      hasNamespace: id != null || guest,
      hostEpoch: _epoch,
      denied: _disposed || (id == null && !guest) ||
          (id != null && _coordinator.isDenied(id)),
    );
  }

  AccountPageOwnership capturePage() => AccountPageOwnership._(
    this,
    _epoch,
    _runtime.account.currentUser?.id,
  );

  AccountDeletionOwnership beginDeletion(AccountPageOwnership page) {
    final id = _runtime.account.currentUser?.id;
    final token = _runtime.account.supabase.auth.currentSession?.accessToken;
    if (!value ||
        !_runtime.isCurrentSessionVerified ||
        !identical(page.owner, this) ||
        page.epoch != _epoch ||
        page.userId != id ||
        id == null ||
        token == null ||
        token.isEmpty ||
        id != _observedUserId ||
        token != _observedAccessToken ||
        !identical(_observedSession, _runtime.account.supabase.auth.currentSession)) {
      throw StateError('Account page ownership has changed');
    }
    return AccountDeletionOwnership._(this, _epoch, id, token);
  }

  Future<void> retireConfirmed(
    AccountDeletionOwnership action,
    String confirmedUserId, {
    Future<void> Function(String userId)? filesOnlyCleanup,
  }) {
    if (!identical(action.owner, this) ||
        action.userId?.toLowerCase() != confirmedUserId.toLowerCase()) {
      return Future<void>.error(StateError('Confirmed account does not own this request'));
    }
    // Strict Core receipt remains authoritative after E changes or disposal.
    // Every resource/data epoch of that UUID belongs to the same local erase.
    return _coordinator.eraseConfirmed(
      confirmedUserId,
      filesOnlyCleanup: filesOnlyCleanup,
    );
  }

  void _retireConfirmedNamespace(String id) {
    if (!_disposed && _accountNamespace == id) _retireBoundary();
  }

  void _onAuthChanged(AuthState state) {
    if (_disposed) return;
    final id = state.session?.user.id;
    final token = state.session?.accessToken;
    final first = !_authObserved;
    final seedReplay = first &&
        (state.event == AuthChangeEvent.initialSession ||
            state.event == AuthChangeEvent.signedIn) &&
        identical(state.session, _seedSession);
    final changedUser = id != _observedUserId;
    final changedToken = token != _observedAccessToken;
    _authObserved = true;
    _seedSession = null;
    _observedSession = state.session;
    _observedUserId = id;
    _observedAccessToken = token;
    if (seedReplay) return;
    if (state.event == AuthChangeEvent.initialSession ||
        state.event == AuthChangeEvent.signedIn ||
        state.event == AuthChangeEvent.signedOut ||
        state.event == AuthChangeEvent.passwordRecovery ||
        changedUser ||
        (changedToken && state.event != AuthChangeEvent.tokenRefreshed)) {
      _retireBoundary();
    }
  }

  void _retireBoundary() {
    if (_disposed) return;
    ++_epoch;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _coordinator._detach(this);
    _runtime.userId.removeListener(_retireBoundary);
    _runtime.phase.removeListener(_retireBoundary);
    _runtime.passwordRecovery.removeListener(_retireBoundary);
    unawaited(_authSubscription.cancel());
    super.dispose();
  }
}
