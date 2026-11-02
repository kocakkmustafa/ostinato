import 'dart:async';

import 'package:flutter/material.dart';
import 'package:motion_account/motion_account.dart';
import 'package:motion_entitlements/motion_entitlements.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthState, Session;
import 'package:url_launcher/url_launcher.dart';

import 'membership_copy.dart';
import 'membership_resume.dart';
import 'ostinato_release_policy.dart';
import 'ui_copy.dart';

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
///
/// Signed out (store review 2026-11-02, screen 30), the page still shows the
/// plans with store prices, terms, privacy and restore. Choosing a plan or
/// restoring first asks the user to sign in or create an account (purchases
/// belong to the account); after sign-in the page binds to that account,
/// reloads its status and continues. Server verification is unchanged.
class OstinatoMembershipPage extends StatefulWidget {
  const OstinatoMembershipPage({
    super.key,
    required this.account,
    this.accountPageBuilder,
    this.resume,
    this.purchaseAdapter,
    this.serverAdapter,
    this.teenPurchasePolicy = ostinatoTeenPurchasePolicy,
  });

  final MotionAccountClient account;

  /// The shared sign-in / create-account page, opened when a signed-out
  /// user chooses a plan or restores.
  final WidgetBuilder? accountPageBuilder;

  /// Carries the chosen plan (or restore) across sign-in, which resets the
  /// app's navigation and closes this page; the signed-in shell reopens it.
  final MembershipResume? resume;
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
  // The account this page acts for: the one signed in when it opened, or
  // the one the user signs in to from this page. Null while signed out.
  String? _openingUserId;
  Session? _openingSession;
  List<StoreProductRef> _offers = const [];
  bool _busy = true;
  bool _active = false;
  bool _authStreamFailed = false;
  bool _consentRequired = false;
  bool _storeFamilyControls = false;
  MotionAccountString? _message;

  String get _appId => widget.account.app.name;
  bool get _signedOut => _openingUserId == null;
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
        // Signed out, the page shows only store offers; a sign-in started
        // here is adopted when the account page returns.
        if (!mounted || _authStreamFailed || _sameUser || _signedOut) return;
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
    if (_signedOut && !_authStreamFailed) return _loadSignedOutOffers();
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
        _resumeAfterLoad = true;
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
      _resumeAfterLoad = true;
    } catch (_) {
      if (!mounted || !_sameUser) return;
      setState(
        () => _message = MotionAccountString.membershipDetailsUnavailable,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
      // Runs after the early return of the consent branch too.
      if (_resumeAfterLoad && mounted && _sameUser) {
        _resumeAfterLoad = false;
        unawaited(_continuePending());
      }
    }
  }

  bool _resumeAfterLoad = false;

  /// The step chosen on this page before a sign-in that did not reset
  /// navigation (the page stayed open).
  MembershipIntent? _localIntent;

  /// Continues the plan (or restore) chosen before sign-in, once the page
  /// knows this account's status. An active membership or a purchase
  /// restriction ends it without buying.
  Future<void> _continuePending() async {
    final intent = widget.resume?.take() ?? _localIntent;
    _localIntent = null;
    if (intent == null || !mounted || !_sameUser) return;
    if (intent.restore) return _restore();
    if (_active || _consentRequired) return;
    final offer = _offers.where(
      (o) => o.productId == intent.productId && o.planId == intent.planId,
    );
    if (offer.isNotEmpty) await _buy(offer.first);
  }

  /// Plans and store prices for someone not signed in. Nothing here is tied
  /// to an account; buying and restoring ask for sign-in first.
  Future<void> _loadSignedOutOffers() async {
    // Called from initState: read the theme once the State is mounted.
    await Future<void>.value();
    if (!mounted) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final offers = await _store.fetchProducts(
        ostinatoOfferedProductIds(Theme.of(context).platform),
      );
      if (!mounted || !_signedOut) return;
      setState(() {
        _offers = [
          for (final o in offers)
            if (!isMotionPlusOffer(o)) o,
        ];
      });
    } catch (_) {
      if (!mounted || !_signedOut) return;
      setState(
        () => _message = MotionAccountString.membershipDetailsUnavailable,
      );
    } finally {
      if (mounted && _signedOut) setState(() => _busy = false);
    }
  }

  /// Signed out: explains why an account is needed, opens the account page
  /// and binds the page to the account signed in there. [intent] is held
  /// across sign-in, which normally resets navigation and closes this page;
  /// if the page is still open afterwards it continues itself.
  Future<void> _signInFromPage(MembershipIntent intent) async {
    if (_busy || _authStreamFailed || !_signedOut) return;
    if (widget.account.currentUser == null) {
      final builder = widget.accountPageBuilder;
      if (builder == null) {
        setState(() => _message = MotionAccountString.signInFirst);
        return;
      }
      final go = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          key: const Key('ostinato-membership-sign-in-prompt'),
          content: Text(uiText(dialogContext, MembershipCopy.signInFirst)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(_text(MotionAccountString.cancel)),
            ),
            FilledButton(
              key: const Key('ostinato-membership-sign-in'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(_text(MotionAccountString.signIn)),
            ),
          ],
        ),
      );
      if (go != true || !mounted) return;
      widget.resume?.hold(intent);
      await Navigator.of(
        context,
      ).push<void>(MaterialPageRoute<void>(builder: builder));
      if (!mounted) return;
      if (widget.account.currentUser == null) {
        widget.resume?.clear();
        return;
      }
    }
    if (!_signedOut) return;
    // Still open after sign-in (no navigation reset): continue here.
    widget.resume?.clear();
    _localIntent = intent;
    setState(() {
      _openingUserId = widget.account.currentUser!.id;
      _openingSession = widget.account.supabase.auth.currentSession;
      _offers = const [];
      _message = null;
    });
    await _load();
  }

  Future<MotionAgeStatus?> _ageStatus() async {
    try {
      return await Future.sync(widget.account.ageStatus);
    } catch (_) {
      return null;
    }
  }

  Future<void> _buy(StoreProductRef offer) async {
    if (_signedOut) {
      return _signInFromPage(
        MembershipIntent.purchase(
          productId: offer.productId,
          planId: offer.planId,
        ),
      );
    }
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
    if (_signedOut) {
      return _signInFromPage(const MembershipIntent.restore());
    }
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
            if (!_signedOut && !_sameUser)
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
              onPressed: _busy || (!_signedOut && !_sameUser) ? null : _restore,
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
