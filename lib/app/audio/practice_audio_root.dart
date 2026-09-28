import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:motion_account/motion_account.dart';

import 'practice_audio_lease.dart';

/// No production call may infer a native close receipt from this placeholder.
/// The input, output, and shared session need one native arbiter first.
final class _NoNativeAudioArbiter implements PracticeAudioLeasePort {
  const _NoNativeAudioArbiter();

  @override
  Future<bool> readAllClear() async => false;

  @override
  Future<void> open(PracticeAudioSide side) =>
      Future.error(StateError('Native audio arbiter is not installed'));

  @override
  Future<void> closeAll() async {}
}

enum AudioRouteAcquireStatus {
  acquired,
  unavailable,
  staleGrant,
  busy,
  blockedUnconfirmed,
  cancelled,
  openFailed,
}

final class AudioRouteAcquireResult {
  const AudioRouteAcquireResult(this.status, [this.ticket]);

  final AudioRouteAcquireStatus status;
  final PracticeAudioTicket? ticket;
}

/// One explicit user action receives one context. A delayed callback can use
/// this object but cannot use it to capture a newer lease context.
final class PracticeAudioRouteGrant {
  PracticeAudioRouteGrant._(
    this._owner,
    this._route,
    this._observer,
    this._identityEpoch,
    this._routeEpoch,
    this._visibilityEpoch,
    this._leaseContext,
  );

  final PracticeAudioRootOwner _owner;
  final Route<dynamic> _route;
  final PracticeAudioRouteObserver _observer;
  final int _identityEpoch;
  final int _routeEpoch;
  final int _visibilityEpoch;
  final PracticeAudioContext _leaseContext;
  bool _consumed = false;

  /// A route action can spend its captured authority once. It cannot mint a
  /// fresh context after an account, route, or lifecycle transition.
  Future<AudioRouteAcquireResult> acquire(PracticeAudioSide side) =>
      _owner.acquire(this, side);
}

/// App-lifetime, isolate-local context boundary. It deliberately has no
/// player or microphone implementation. Production acquisition is disabled.
final class PracticeAudioRootOwner {
  PracticeAudioRootOwner({
    required ValueListenable<String?> userId,
    required ValueListenable<MotionIdentityPhase> phase,
    required PracticeAudioLease lease,
    AppLifecycleState? initialLifecycleState,
    @visibleForTesting this.allowDetachedRouteEventsForTest = false,
    this.allowAcquisition = false,
    this.onStatusChanged,
  }) : _userIdListenable = userId,
       _phaseListenable = phase,
       _lease = lease,
       _userId = userId.value,
       _phase = phase.value,
       _foreground = initialLifecycleState == AppLifecycleState.resumed {
    // The root constructs this before building MotionIdentityGate or the
    // account-keyed Navigator; these listeners fence before either rebuilds.
    _userIdListenable.addListener(_onUserChanged);
    _phaseListenable.addListener(_onPhaseChanged);
  }

  final ValueListenable<String?> _userIdListenable;
  final ValueListenable<MotionIdentityPhase> _phaseListenable;
  final PracticeAudioLease _lease;

  /// Test seam only. The production root always keeps this false.
  final bool allowAcquisition;

  /// Unit tests may drive a NavigatorObserver without mounting a Navigator.
  /// The production root never enables detached observer events.
  @visibleForTesting
  final bool allowDetachedRouteEventsForTest;
  final VoidCallback? onStatusChanged;

  String? _userId;
  MotionIdentityPhase _phase;
  PracticeAudioRouteObserver? _observer;
  Route<dynamic>? _topRoute;
  int _identityEpoch = 0;
  int _routeEpoch = 0;
  int _visibilityEpoch = 0;
  int _fenceSerial = 0;
  bool _foreground;
  bool _barrier = false;
  bool _recovering = false;
  bool _disposed = false;
  PracticeAudioReleaseStatus? _lastRecoveryStatus;

  PracticeAudioLeasePhase get leasePhase => _lease.phase;
  bool get blocked =>
      _lease.phase == PracticeAudioLeasePhase.blockedUnconfirmed;
  bool get recovering => _recovering;
  bool get nativeReplyPending =>
      _lastRecoveryStatus == PracticeAudioReleaseStatus.pendingNative;
  Route<dynamic>? get topRoute => _topRoute;

  bool get _identityReady =>
      (_phase == MotionIdentityPhase.verified && _userId != null) ||
      (_phase == MotionIdentityPhase.signedOut && _userId == null);

  void _onUserChanged() {
    final next = _userIdListenable.value;
    if (next == _userId) return;
    _userId = next;
    ++_identityEpoch;
    _fence(PracticeAudioInvalidationReason.accountChange, retireRoute: true);
  }

  void _onPhaseChanged() {
    final next = _phaseListenable.value;
    if (next == _phase) return;
    _phase = next;
    ++_identityEpoch;
    _fence(PracticeAudioInvalidationReason.accountChange, retireRoute: true);
  }

  void attachNavigator(PracticeAudioRouteObserver observer) {
    if (_disposed || identical(_observer, observer)) return;
    _observer = observer;
    _topRoute = null;
    _fence(PracticeAudioInvalidationReason.routeChange);
  }

  void detachNavigator(PracticeAudioRouteObserver observer) {
    if (!identical(_observer, observer)) return;
    _observer = null;
    _topRoute = null;
    _fence(PracticeAudioInvalidationReason.routeChange);
  }

  void routeChanged(
    PracticeAudioRouteObserver observer,
    Route<dynamic>? route,
  ) {
    if (!identical(_observer, observer) || identical(_topRoute, route)) return;
    if (!allowDetachedRouteEventsForTest &&
        (observer.navigator == null ||
            (route != null &&
                (!identical(route.navigator, observer.navigator) ||
                    !route.isCurrent)))) {
      return;
    }
    _topRoute = route;
    _fence(PracticeAudioInvalidationReason.routeChange);
  }

  /// `inactive` can be a permission sheet: stop granting new work but do not
  /// falsely claim native close. Real background states close the lease.
  void lifecycleChanged(AppLifecycleState state) {
    if (_disposed) return;
    switch (state) {
      case AppLifecycleState.resumed:
        _foreground = true;
        ++_visibilityEpoch;
      case AppLifecycleState.inactive:
        _foreground = false;
        ++_visibilityEpoch;
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _foreground = false;
        ++_visibilityEpoch;
        _fence(PracticeAudioInvalidationReason.background);
    }
  }

  PracticeAudioRouteGrant? grantFor(Route<dynamic> route) {
    final observer = _observer;
    if (_disposed ||
        !allowAcquisition ||
        !_identityReady ||
        !_foreground ||
        _barrier ||
        observer == null ||
        !identical(_topRoute, route) ||
        blocked) {
      return null;
    }
    return PracticeAudioRouteGrant._(
      this,
      route,
      observer,
      _identityEpoch,
      _routeEpoch,
      _visibilityEpoch,
      _lease.captureContext(),
    );
  }

  bool _valid(PracticeAudioRouteGrant grant) =>
      identical(grant._owner, this) &&
      !_disposed &&
      allowAcquisition &&
      _identityReady &&
      _foreground &&
      !_barrier &&
      identical(grant._observer, _observer) &&
      identical(grant._route, _topRoute) &&
      grant._identityEpoch == _identityEpoch &&
      grant._routeEpoch == _routeEpoch &&
      grant._visibilityEpoch == _visibilityEpoch;

  Future<AudioRouteAcquireResult> acquire(
    PracticeAudioRouteGrant grant,
    PracticeAudioSide side,
  ) async {
    if (grant._consumed || !_valid(grant)) {
      return const AudioRouteAcquireResult(AudioRouteAcquireStatus.staleGrant);
    }
    // This synchronous assignment precedes the first await, so concurrent
    // continuations cannot spend the same action twice.
    grant._consumed = true;
    final result = await _lease.acquire(side, context: grant._leaseContext);
    if (result.status == PracticeAudioAcquireStatus.blockedUnconfirmed) {
      _statusChanged();
    }
    if (!_valid(grant)) {
      if (result.ticket != null) {
        await _lease.release(result.ticket!);
        _statusChanged();
      }
      return const AudioRouteAcquireResult(AudioRouteAcquireStatus.staleGrant);
    }
    return AudioRouteAcquireResult(switch (result.status) {
      PracticeAudioAcquireStatus.acquired => AudioRouteAcquireStatus.acquired,
      PracticeAudioAcquireStatus.busy => AudioRouteAcquireStatus.busy,
      PracticeAudioAcquireStatus.blockedUnconfirmed =>
        AudioRouteAcquireStatus.blockedUnconfirmed,
      PracticeAudioAcquireStatus.staleContext =>
        AudioRouteAcquireStatus.staleGrant,
      PracticeAudioAcquireStatus.cancelled => AudioRouteAcquireStatus.cancelled,
      PracticeAudioAcquireStatus.openFailed =>
        AudioRouteAcquireStatus.openFailed,
    }, result.ticket);
  }

  Future<PracticeAudioReleaseStatus> release(PracticeAudioTicket ticket) async {
    final result = await _lease.release(ticket);
    _statusChanged();
    return result;
  }

  /// This explicit retry only closes and reads native state; never opens audio.
  Future<PracticeAudioReleaseStatus> recover() async {
    if (_recovering) return PracticeAudioReleaseStatus.busy;
    _recovering = true;
    _lastRecoveryStatus = null;
    _statusChanged();
    try {
      final result = await _lease.recover();
      _lastRecoveryStatus = result;
      return result;
    } finally {
      _recovering = false;
      _statusChanged();
    }
  }

  void _fence(
    PracticeAudioInvalidationReason reason, {
    bool retireRoute = false,
  }) {
    if (retireRoute) {
      _observer = null;
      _topRoute = null;
    }
    ++_routeEpoch;
    _barrier = true;
    final serial = ++_fenceSerial;
    // `invalidate` increments the lease epoch before returning its Future.
    final close = _lease.invalidate(reason);
    unawaited(
      close.then((result) {
        if (_disposed) return;
        if (serial == _fenceSerial) _barrier = false;
        if (result == PracticeAudioReleaseStatus.blockedUnconfirmed) {
          _statusChanged();
        }
      }, onError: (Object _, StackTrace _) => _statusChanged()),
    );
  }

  void _statusChanged() {
    if (!_disposed) onStatusChanged?.call();
  }

  void dispose() {
    if (_disposed) return;
    _userIdListenable.removeListener(_onUserChanged);
    _phaseListenable.removeListener(_onPhaseChanged);
    _observer = null;
    _topRoute = null;
    _fence(PracticeAudioInvalidationReason.routeChange);
    _disposed = true;
  }
}

final class PracticeAudioRouteObserver extends NavigatorObserver {
  PracticeAudioRouteObserver(this._owner);

  final PracticeAudioRootOwner _owner;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _owner.routeChanged(this, route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _owner.routeChanged(this, previousRoute);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (identical(_owner.topRoute, route)) {
      _owner.routeChanged(this, previousRoute);
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (identical(_owner.topRoute, oldRoute)) {
      _owner.routeChanged(this, newRoute);
    }
  }
}

/// App-shell-only wrapper: no raw owner or grant minting is inherited by a
/// route widget. The shell retains this host in a private field.
final class PracticeAudioNavigatorHost {
  const PracticeAudioNavigatorHost._(this._owner);

  final PracticeAudioRootOwner _owner;

  Widget wrap({
    Key? key,
    required Widget Function(NavigatorObserver observer) builder,
  }) => _OstinatoObservedNavigator(key: key, owner: _owner, builder: builder);
}

/// One observer belongs to one account-keyed Navigator lifetime.
class _OstinatoObservedNavigator extends StatefulWidget {
  const _OstinatoObservedNavigator({
    super.key,
    required PracticeAudioRootOwner owner,
    required Widget Function(NavigatorObserver observer) builder,
  }) : _owner = owner,
       _builder = builder;

  final PracticeAudioRootOwner _owner;
  final Widget Function(NavigatorObserver observer) _builder;

  @override
  State<_OstinatoObservedNavigator> createState() =>
      _OstinatoObservedNavigatorState();
}

class _OstinatoObservedNavigatorState
    extends State<_OstinatoObservedNavigator> {
  late PracticeAudioRouteObserver _observer;

  @override
  void initState() {
    super.initState();
    _observer = PracticeAudioRouteObserver(widget._owner);
    widget._owner.attachNavigator(_observer);
  }

  @override
  void didUpdateWidget(_OstinatoObservedNavigator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget._owner, widget._owner)) {
      oldWidget._owner.detachNavigator(_observer);
      _observer = PracticeAudioRouteObserver(widget._owner);
      widget._owner.attachNavigator(_observer);
    }
  }

  @override
  void dispose() {
    widget._owner.detachNavigator(_observer);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget._builder(_observer);
}

/// Persists above MotionIdentityGate while its child is removed. The optional
/// injected lease is for tests; main() uses the denied native port.
class OstinatoAudioRoot extends StatefulWidget {
  const OstinatoAudioRoot({
    super.key,
    required this.userId,
    required this.phase,
    this.child,
    this.builder,
    this.testLease,
    this.allowTestAcquisition = false,
    this.onTestOwnerCreated,
  }) : assert(child != null || builder != null);

  final ValueListenable<String?> userId;
  final ValueListenable<MotionIdentityPhase> phase;
  final Widget? child;
  final Widget Function(PracticeAudioNavigatorHost host)? builder;
  @visibleForTesting
  final PracticeAudioLease? testLease;
  @visibleForTesting
  final bool allowTestAcquisition;
  @visibleForTesting
  final ValueChanged<PracticeAudioRootOwner>? onTestOwnerCreated;

  @override
  State<OstinatoAudioRoot> createState() => _OstinatoAudioRootState();
}

class _OstinatoAudioRootState extends State<OstinatoAudioRoot>
    with WidgetsBindingObserver {
  late final PracticeAudioRootOwner _owner;
  late final PracticeAudioNavigatorHost _navigatorHost;

  @override
  void initState() {
    super.initState();
    _owner = PracticeAudioRootOwner(
      userId: widget.userId,
      phase: widget.phase,
      lease:
          widget.testLease ??
          PracticeAudioLease(port: const _NoNativeAudioArbiter()),
      initialLifecycleState: WidgetsBinding.instance.lifecycleState,
      allowAcquisition: widget.allowTestAcquisition,
      onStatusChanged: _refreshAfterFrame,
    );
    _navigatorHost = PracticeAudioNavigatorHost._(_owner);
    widget.onTestOwnerCreated?.call(_owner);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      _owner.lifecycleChanged(state);

  void _refreshAfterFrame() {
    // NavigatorObserver callbacks may run while a route is building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
    // An asynchronous native result can arrive with no frame in flight.
    WidgetsBinding.instance.scheduleFrame();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _owner.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_owner.blocked) {
      final tr =
          WidgetsBinding.instance.platformDispatcher.locale.languageCode ==
          'tr';
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        supportedLocales: const [Locale('tr'), Locale('en')],
        home: Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tr
                          ? 'Ses kaynağının kapandığı doğrulanamadı.'
                          : 'Audio shutdown could not be confirmed.',
                      textAlign: TextAlign.center,
                    ),
                    if (_owner.nativeReplyPending) ...[
                      const SizedBox(height: 12),
                      Text(
                        tr
                            ? 'Önceki cihaz yanıtı hâlâ bekleniyor.'
                            : 'A previous device reply is still pending.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 16),
                    FilledButton(
                      key: const Key('ostinato-audio-root-recover'),
                      onPressed: _owner.recovering
                          ? null
                          : () => unawaited(_owner.recover()),
                      child: Text(
                        tr ? 'Kapanmayı yeniden dene' : 'Retry shutdown',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    return widget.builder?.call(_navigatorHost) ?? widget.child!;
  }
}
