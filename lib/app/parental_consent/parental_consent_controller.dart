import 'package:flutter/foundation.dart';
import 'package:motion_account/motion_account.dart';

import 'consent_token_store.dart';

/// The three Core calls the flow needs. A narrow seam so tests use a fake
/// client and the flow never reaches a server by itself.
abstract interface class ParentalConsentGateway {
  Future<MotionDeviceConsentStatus> request({
    required String deviceToken,
    required String parentEmail,
    required String locale,
  });
  Future<MotionDeviceConsentStatus> status(String deviceToken);
  Future<void> signUpUnderThirteen({
    required String email,
    required String password,
    required MotionAgeDeclaration age,
    required String deviceToken,
  });
}

final class MotionAccountConsentGateway implements ParentalConsentGateway {
  const MotionAccountConsentGateway(this._client);
  final MotionAccountClient _client;

  @override
  Future<MotionDeviceConsentStatus> request({
    required String deviceToken,
    required String parentEmail,
    required String locale,
  }) => _client.requestDeviceConsent(
    deviceToken: deviceToken,
    parentEmail: parentEmail,
    locale: locale,
  );

  @override
  Future<MotionDeviceConsentStatus> status(String deviceToken) =>
      _client.deviceConsentStatus(deviceToken);

  @override
  Future<void> signUpUnderThirteen({
    required String email,
    required String password,
    required MotionAgeDeclaration age,
    required String deviceToken,
  }) async {
    await _client.signUpUnderThirteen(
      email: email,
      password: password,
      age: age,
      deviceConsentToken: deviceToken,
    );
  }
}

enum ConsentPhase {
  loading,
  needParentEmail,
  pending,
  approved,

  /// Parent refused: the permanent marker was written first.
  denied,

  /// Link or window expired: nothing is blocked, the child may ask again.
  expired,

  /// Could not read the state: no permission, no account, try again.
  unavailable,
  accountCreated,
}

enum ConsentNotice { none, tooSoon, dailyLimit, invalidEmail, unavailable }

/// Under-13 parental consent flow (ADR-008 §3, §6; Core requirement §10).
/// Fail-closed: every error or unclear answer leaves "no permission".
final class ParentalConsentController extends ChangeNotifier {
  ParentalConsentController({
    required this.gateway,
    required this.tokenStore,
    required this.markBlocked,
    required this.locale,
  });

  final ParentalConsentGateway gateway;
  final ConsentTokenStorage tokenStore;

  /// Persists the permanent block marker (`AgeGateStore.markBlocked`).
  final Future<void> Function() markBlocked;
  final String locale;

  ConsentPhase _phase = ConsentPhase.loading;
  ConsentNotice _notice = ConsentNotice.none;
  bool _busy = false;
  bool _disposed = false;

  /// Set once a refusal was read. The server reads it out only once, so from
  /// here the session stays closed whatever happens to the marker write.
  bool _blockedInSession = false;
  bool _markerPending = false;
  ConsentPhase get phase => _phase;
  ConsentNotice get notice => _notice;
  bool get busy => _busy;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _set(ConsentPhase phase, [ConsentNotice notice = ConsentNotice.none]) {
    _phase = phase;
    _notice = notice;
    notifyListeners();
  }

  /// Opens the flow: makes sure a device token exists, then reads the state.
  Future<void> load() => refresh();

  Future<void> refresh() async {
    if (_busy) return;
    _busy = true;
    notifyListeners();
    try {
      if (!_blockedInSession) {
        try {
          if (await tokenStore.deniedSeen()) {
            _blockedInSession = true;
            _markerPending = true;
          }
        } on Object {
          // Unreadable note: fall through to the normal fail-closed read.
        }
      }
      if (_blockedInSession) {
        await _settleDenied();
        return;
      }
      final String token;
      try {
        token = await tokenStore.readOrCreate();
      } on Object {
        _set(ConsentPhase.unavailable);
        return;
      }
      await _apply(await _status(token));
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<MotionDeviceConsentStatus> _status(String token) async {
    try {
      return await gateway.status(token);
    } on Object {
      return const MotionDeviceConsentStatus.unavailable();
    }
  }

  Future<void> _apply(MotionDeviceConsentStatus status) async {
    if (!status.verified) return _set(ConsentPhase.unavailable);
    switch (status.state) {
      case MotionParentalConsent.none:
        return _set(ConsentPhase.needParentEmail);
      case MotionParentalConsent.pending:
        return _set(ConsentPhase.pending);
      case MotionParentalConsent.approved:
        return _set(ConsentPhase.approved);
      case MotionParentalConsent.denied:
        // The server reads a refusal out once and then forgets it, so the
        // permanent marker is written BEFORE anything else happens. If the
        // write fails the token and the denied result are kept and the write
        // is retried; the session stays closed in memory meanwhile.
        _blockedInSession = true;
        _markerPending = true;
        try {
          await tokenStore.markDenied();
        } on Object {
          // Still closed in memory; the marker write below is attempted too.
        }
        await _settleDenied();

      case MotionParentalConsent.expired:
        // No marker: the child may start again.
        return _set(ConsentPhase.expired);
      case MotionParentalConsent.withdrawn:
        return _set(ConsentPhase.unavailable);
    }
  }

  Future<void> _settleDenied() async {
    if (_markerPending) {
      try {
        await markBlocked();
        _markerPending = false;
      } on Object {
        // Keep the token and retry on the next refresh.
      }
    }
    if (!_markerPending) {
      try {
        await tokenStore.clear();
      } on Object {
        // The token is only a wait handle; the marker is what matters.
      }
    }
    _set(ConsentPhase.denied);
  }

  Future<void> sendParentEmail(String parentEmail) async {
    if (_busy ||
        !(_phase == ConsentPhase.needParentEmail ||
            _phase == ConsentPhase.expired ||
            _phase == ConsentPhase.pending)) {
      return;
    }
    _busy = true;
    notifyListeners();
    final before = _phase;
    try {
      var token = await tokenStore.readOrCreate();
      try {
        final status = await gateway.request(
          deviceToken: token,
          parentEmail: parentEmail.trim(),
          locale: locale,
        );
        if (status.verified && status.state == MotionParentalConsent.pending) {
          return _set(ConsentPhase.pending);
        }
        return _set(before, ConsentNotice.unavailable);
      } on MotionConsentRequestRefused catch (refused) {
        switch (refused.reason) {
          case MotionConsentRequestError.tooSoon:
            return _set(before, ConsentNotice.tooSoon);
          case MotionConsentRequestError.dailyLimit:
            return _set(before, ConsentNotice.dailyLimit);
          case MotionConsentRequestError.invalidParentEmail:
          case MotionConsentRequestError.parentEmailIsTeen:
            return _set(before, ConsentNotice.invalidEmail);
          case MotionConsentRequestError.alreadyApproved:
          case MotionConsentRequestError.alreadyDecided:
            // A decision exists: read it instead of guessing.
            await _apply(await _status(token));
            return;
          case MotionConsentRequestError.invalidDeviceToken:
            token = await tokenStore.renew();
            return _set(before, ConsentNotice.unavailable);
          case MotionConsentRequestError.mailUnavailable:
          case MotionConsentRequestError.notRequired:
            return _set(before, ConsentNotice.unavailable);
        }
      }
    } on Object {
      _set(before, ConsentNotice.unavailable);
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Creates the child's account, only after a fresh verified approval.
  /// Returns true when Core accepted the sign-up.
  Future<bool> createAccount({
    required String email,
    required String password,
    required MotionAgeDeclaration age,
  }) async {
    if (_busy || _phase != ConsentPhase.approved) return false;
    _busy = true;
    notifyListeners();
    try {
      final token = await tokenStore.read();
      if (token == null) {
        _set(ConsentPhase.unavailable);
        return false;
      }
      final status = await _status(token);
      if (!status.allowsAccount) {
        await _apply(status);
        return false;
      }
      await gateway.signUpUnderThirteen(
        email: email.trim(),
        password: password,
        age: age,
        deviceToken: token,
      );
      try {
        await tokenStore.clear();
      } on Object {
        // Server consumed the token; a leftover file is harmless.
      }
      _set(ConsentPhase.accountCreated);
      return true;
    } on Object {
      _set(ConsentPhase.approved, ConsentNotice.unavailable);
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}
