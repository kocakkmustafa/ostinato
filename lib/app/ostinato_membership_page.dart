import 'dart:async';

import 'package:flutter/material.dart';
import 'package:motion_account/motion_account.dart';
import 'package:motion_entitlements/motion_entitlements.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthState, Session;
import 'package:url_launcher/url_launcher.dart';

import 'ostinato_release_policy.dart';

/// The Ostinato plans this build sells: one subscription, monthly and yearly.
/// App Store: two products. Play: one subscription whose base plans are
/// `monthly` and `yearly`. Motion+ products are never requested here.
List<String> ostinatoOfferedProductIds(TargetPlatform platform) =>
    platform == TargetPlatform.android
    ? const ['ostinato_individual']
    : const [
        'com.yulalab.ostinato.individual.monthly',
        'com.yulalab.ostinato.individual.yearly',
      ];

/// Whether a store product is a Motion+ product (same rule as Core's
/// `FlutterPurchaseAdapter.isMotionPlusProduct`).
bool isMotionPlusOffer(StoreProductRef offer) =>
    FlutterPurchaseAdapter.isMotionPlusProduct(offer.productId);

/// Ostinato's membership page for the v1 store build: Core's
/// `MotionMembershipPage` flow (status, offers, purchase, server
/// verification, restore, manage, legal links) with only the two Ostinato
/// plans. Core's page always draws a Motion+ section, and Core is not edited
/// from this app, so the app layer owns this page while
/// [ostinatoMotionPlusOffered] is false.
///
/// Entitlement is unchanged: a Motion+ right the server already verified
/// still counts as active membership (Core `membershipStatus`).
class OstinatoMembershipPage extends StatefulWidget {
  const OstinatoMembershipPage({
    super.key,
    required this.account,
    this.purchaseAdapter,
    this.serverAdapter,
    this.teenPurchasePolicy = ostinatoTeenPurchasePolicy,
  });

  final MotionAccountClient account;
  final PurchaseAdapter? purchaseAdapter;
  final ServerAdapter? serverAdapter;
  final MotionTeenPurchasePolicy teenPurchasePolicy;

  @override
  State<OstinatoMembershipPage> createState() => _OstinatoMembershipPageState();
}

class _OstinatoMembershipPageState extends State<OstinatoMembershipPage> {
  late final PurchaseAdapter _store;
  late final PurchaseCoordinator _coordinator;
  StreamSubscription<StorePurchaseUpdate>? _subscription;
  StreamSubscription<AuthState>? _authSubscription;
  late final String? _openingUserId;
  late final Session? _openingSession;
  List<StoreProductRef> _offers = const [];
  bool _busy = true;
  bool _active = false;
  bool _authStreamFailed = false;
  bool _consentRequired = false;
  bool _storeFamilyControls = false;
  MotionAccountString? _message;

  String get _appId => widget.account.app.name;
  bool get _sameUser =>
      !_authStreamFailed &&
      _openingUserId != null &&
      identical(widget.account.supabase.auth.currentSession, _openingSession) &&
      widget.account.currentUser?.id == _openingUserId;

  @override
  void initState() {
    super.initState();
    _openingUserId = widget.account.currentUser?.id;
    _openingSession = widget.account.supabase.auth.currentSession;
    // No Motion+ trial gate: no Motion+ product is requested on this page.
    _store =
        widget.purchaseAdapter ??
        FlutterPurchaseAdapter(
          appId: _appId,
          currentUserId: () => widget.account.currentUser?.id,
        );
    _coordinator = PurchaseCoordinator(
      appId: _appId,
      currentUserId: () => _sameUser ? _openingUserId! : '',
      store: _store,
      server:
          widget.serverAdapter ??
          SupabasePurchaseServerAdapter(widget.account.supabase),
      cache: InMemoryEntitlementCache(),
      now: DateTime.now,
    );
    _subscription = _store.updates.listen(
      (update) => unawaited(_handleUpdate(update)),
      onError: (Object _) {
        if (!mounted) return;
        setState(() {
          _busy = false;
          _message = MotionAccountString.storeConnectionFailed;
        });
      },
    );
    _authSubscription = widget.account.authChanges.listen(
      (_) {
        if (!mounted || _authStreamFailed || _sameUser) return;
        setState(() {
          _offers = const [];
          _active = false;
          _busy = false;
          _message = null;
        });
      },
      onError: (Object _, StackTrace _) {
        if (!mounted) return;
        setState(() {
          _authStreamFailed = true;
          _offers = const [];
          _active = false;
          _busy = false;
          _message = MotionAccountString.membershipReopen;
        });
      },
    );
    unawaited(_load());
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    unawaited(_authSubscription?.cancel());
    super.dispose();
  }

  String _text(MotionAccountString key) =>
      MotionAccountLocalizations.of(context).text(key);

  Future<void> _load() async {
    if (!_sameUser) {
      if (mounted) setState(() => _busy = false);
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final age = await _ageStatus();
      if (!mounted || !_sameUser) return;
      final today = DateTime.now();
      final policy = widget.teenPurchasePolicy;
      _storeFamilyControls =
          age?.storeDecidesPurchaseOn(today, policy) ?? false;
      if (age?.purchaseRestrictedOn(today, policy) ?? false) {
        setState(() {
          _consentRequired = true;
          _offers = const [];
        });
        return;
      }
      final status = await widget.account.membershipStatus();
      if (!mounted || !_sameUser) return;
      final offers = status.active
          ? const <StoreProductRef>[]
          : await _store.fetchProducts(
              ostinatoOfferedProductIds(Theme.of(context).platform),
            );
      if (!mounted || !_sameUser) return;
      setState(() {
        _active = status.active;
        _offers = [
          for (final o in offers)
            if (!isMotionPlusOffer(o)) o,
        ];
      });
    } catch (_) {
      if (!mounted || !_sameUser) return;
      setState(
        () => _message = MotionAccountString.membershipDetailsUnavailable,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<MotionAgeStatus?> _ageStatus() async {
    try {
      return await Future.sync(widget.account.ageStatus);
    } catch (_) {
      return null;
    }
  }

  Future<void> _buy(StoreProductRef offer) async {
    if (_busy || _active || _consentRequired || !_sameUser) return;
    setState(() {
      _busy = true;
      _message = MotionAccountString.openingStore;
    });
    try {
      // A purchase in another app may have landed since the page loaded.
      final status = await widget.account.membershipStatus();
      if (!mounted || !_sameUser) return;
      if (status.active) {
        setState(() {
          _active = true;
          _busy = false;
          _message = MotionAccountString.membershipChanged;
        });
        return;
      }
      await _store.startPurchase(offer);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = MotionAccountString.purchaseStartFailed;
      });
    }
  }

  Future<void> _restore() async {
    if (_busy || !_sameUser) return;
    setState(() {
      _busy = true;
      _message = MotionAccountString.lookingForPurchases;
    });
    try {
      await _store.restore();
      if (!mounted || !_sameUser) return;
      setState(() {
        _busy = false;
        _message = MotionAccountString.foundPurchases;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = MotionAccountString.restoreFailed;
      });
    }
  }

  Future<void> _handleUpdate(StorePurchaseUpdate update) async {
    if (!mounted || !_sameUser) return;
    if (update.kind == StorePurchaseKind.pending) {
      setState(() => _message = MotionAccountString.waitingStore);
      return;
    }
    if (update.kind == StorePurchaseKind.canceled ||
        update.kind == StorePurchaseKind.failed) {
      setState(() {
        _busy = false;
        _message = update.kind == StorePurchaseKind.canceled
            ? MotionAccountString.purchaseCanceled
            : MotionAccountString.storePurchaseFailed;
      });
      return;
    }
    try {
      final result = await _coordinator.verifyAndComplete(update);
      if (!mounted || !_sameUser) return;
      setState(() {
        _busy = false;
        if (result != null) {
          _active = true;
          _offers = const [];
          _message = MotionAccountString.membershipActive;
        } else {
          _message = MotionAccountString.purchaseNotVerified;
        }
      });
    } catch (_) {
      if (!mounted || !_sameUser) return;
      setState(() {
        _busy = false;
        _message = MotionAccountString.verificationUnavailable;
      });
    }
  }

  Future<void> _open(Uri uri, MotionAccountString failure) async {
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {
      // The store app or a browser may be unavailable on this device.
    }
    if (!mounted) return;
    setState(() => _message = failure);
  }

  Widget _offer(StoreProductRef offer) {
    final yearly = offer.planId == 'yearly';
    final trialDays = offer.freeTrialDays;
    return ListTile(
      key: Key('ostinato-offer-${offer.productId}-${offer.planId}'),
      title: Text(
        _text(
          yearly ? MotionAccountString.yearly : MotionAccountString.monthly,
        ),
      ),
      subtitle: Text(
        trialDays == null
            ? offer.localizedPrice
            : MotionAccountLocalizations.of(context).trialThenPrice(
                yearly: yearly,
                days: trialDays,
                price: offer.localizedPrice,
              ),
      ),
      trailing: FilledButton(
        onPressed: _busy ? null : () => _buy(offer),
        child: Text(_text(MotionAccountString.choose)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appName = _appId[0].toUpperCase() + _appId.substring(1);
    final android = Theme.of(context).platform == TargetPlatform.android;
    return Scaffold(
      appBar: AppBar(title: Text(_text(MotionAccountString.membershipTitle))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (_busy) const LinearProgressIndicator(),
            if (_message != null) ...[
              const SizedBox(height: 12),
              Semantics(liveRegion: true, child: Text(_text(_message!))),
            ],
            if (!_sameUser)
              Text(_text(MotionAccountString.signInFirst))
            else if (_consentRequired)
              Text(_text(MotionAccountString.parentalConsentNeeded))
            else if (_active)
              Text(_text(MotionAccountString.yourMembershipActive))
            else if (!_busy && _offers.isEmpty)
              Text(_text(MotionAccountString.storeMembershipsUnavailable))
            else ...[
              Text(
                MotionAccountLocalizations.of(
                  context,
                ).membershipForApp(appName),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(_text(MotionAccountString.guidedBenefit)),
              for (final offer in _offers) _offer(offer),
              const SizedBox(height: 12),
              Text(_text(MotionAccountString.autoRenewTerms)),
              if (_storeFamilyControls)
                Text(_text(MotionAccountString.storeFamilyControlsNote)),
              if (_offers.any((offer) => offer.freeTrialDays != null))
                Text(_text(MotionAccountString.trialRenewTerms)),
            ],
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _busy || !_sameUser ? null : _restore,
              child: Text(_text(MotionAccountString.restorePurchases)),
            ),
            TextButton(
              onPressed: _busy ? null : _load,
              child: Text(_text(MotionAccountString.refreshStatus)),
            ),
            TextButton(
              onPressed: () => _open(
                Uri.parse(
                  android
                      ? 'https://play.google.com/store/account/subscriptions'
                      : 'https://apps.apple.com/account/subscriptions',
                ),
                MotionAccountString.storeSubscriptionOpenFailed,
              ),
              child: Text(_text(MotionAccountString.manageInStore)),
            ),
            TextButton(
              onPressed: () => _open(
                Uri.parse('https://yulalab.com/terms'),
                MotionAccountString.linkOpenFailed,
              ),
              child: Text(_text(MotionAccountString.termsOfUse)),
            ),
            TextButton(
              onPressed: () => _open(
                Uri.parse('https://yulalab.com/privacy/motion'),
                MotionAccountString.linkOpenFailed,
              ),
              child: Text(_text(MotionAccountString.privacyPolicyTitle)),
            ),
            Text(_text(MotionAccountString.subscriptionDisclosure)),
          ],
        ),
      ),
    );
  }
}
