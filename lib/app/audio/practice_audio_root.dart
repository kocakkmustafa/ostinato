import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:motion_account/motion_account.dart';

import '../app_locale.dart';
import 'audio_capture_channel.dart';
import 'native_audio_arbiter_channel.dart';
import 'practice_audio_lease.dart';
import 'practice_video_session_owner.dart';

/// No production call may infer a native close receipt from this placeholder.
/// The input, output, and shared session need one native arbiter first.
final class _NoNativeAudioArbiter implements PracticeAudioLeasePort {
  const _NoNativeAudioArbiter();

  @override
  Future<NativeAllAudioState> readAllAudioState() =>
      Future.error(StateError('Native audio arbiter is not installed'));

  @override
  Future<NativeAudioPermit> reserve(PracticeAudioSide side, String leaseId) =>
      Future.error(StateError('Native audio arbiter is not installed'));

  @override
  Future<NativeAllAudioState> completeVideoDispose(
    NativeAudioPermit permit, {
    required bool confirmed,
  }) => Future.error(StateError('Native audio arbiter is not installed'));

  @override
  Future<NativeAllAudioState> cancelVideoReservation(
    NativeAudioPermit permit,
  ) => Future.error(StateError('Native audio arbiter is not installed'));

  @override
  Future<NativeAllAudioState> cancelUnclaimedVideoReservation({
    required String attemptOwnerToken,
    required int attemptEngineGeneration,
    required int attemptContextGeneration,
    required String leaseId,
    required int? leaseGeneration,
    required int expectedStateRevision,
  }) => Future.error(StateError('Native audio arbiter is not installed'));

  @override
  Future<NativeAudioPermit> startOutput(
    NativeAudioPermit permit,
    String assetId,
  ) => Future.error(StateError('Native audio arbiter is not installed'));

  @override
  Future<NativeAllAudioState> closeAll(
    NativeAudioPermit permit,
    NativeAudioCloseReason reason,
  ) => Future.error(StateError('Native audio arbiter is not installed'));

  @override
  Future<NativeAllAudioState> recoverAll(int expectedStateRevision) =>
      Future.error(StateError('Native audio arbiter is not installed'));

  @override
  Future<NativeAllAudioState> fenceContext(NativeAudioContextReason reason) =>
      Future.error(StateError('Native audio arbiter is not installed'));
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
  Future<AudioRouteAcquireResult> acquire(
    PracticeAudioSide side, {
    String? assetId,
  }) => _owner.acquire(this, side, assetId: assetId);
}

/// Reserved for the future verified-media route. The production root does not
/// issue these actions until the native player itself enforces video permits.
final class PracticeVideoStartAction {
  PracticeVideoStartAction._(
    this._owner,
    this._route,
    this._observer,
    this._identityEpoch,
    this._routeEpoch,
    this._visibilityEpoch,
  );

  final PracticeAudioRootOwner _owner;
  final Route<dynamic> _route;
  final PracticeAudioRouteObserver _observer;
  final int _identityEpoch;
  final int _routeEpoch;
  final int _visibilityEpoch;
  bool _consumed = false;

  Future<PracticeVideoOpenStatus> start(PracticeVideoPlayerPort player) =>
      _owner.startVideo(this, player);
}

/// A single user tap can authorize only the native context that was clear at
/// that tap. It is retired synchronously by route, identity, or visibility
/// changes, including while a permission prompt is still unanswered.
final class PracticeAudioCaptureAction {
  PracticeAudioCaptureAction._(
    this._owner,
    this._route,
    this._observer,
    this._identityEpoch,
    this._routeEpoch,
    this._visibilityEpoch,
    NativeAllAudioState nativeSnapshot,
  ) : _nativeSnapshot = nativeSnapshot,
      claim = AudioCaptureContextClaim(
        ownerToken: nativeSnapshot.ownerToken,
        engineGeneration: nativeSnapshot.engineGeneration,
        contextGeneration: nativeSnapshot.contextGeneration,
      );

  final PracticeAudioRootOwner _owner;
  final Route<dynamic> _route;
  final PracticeAudioRouteObserver _observer;
  final int _identityEpoch;
  final int _routeEpoch;
  final int _visibilityEpoch;
  final NativeAllAudioState _nativeSnapshot;
  final AudioCaptureContextClaim claim;
  VoidCallback? _cancel;
  bool _attached = false;
  bool _retired = false;

  bool get isCurrent => !_retired && _owner._validCapture(this);

  /// A capture source attaches before its first asynchronous boundary.
  bool attachCancellation(VoidCallback cancel) {
    if (_attached || !isCurrent) return false;
    _attached = true;
    _cancel = cancel;
    return true;
  }

  /// Fresh native readback is required before requesting microphone consent.
  /// It checks the original claim, never mints a newer claim for this action.
  Future<bool> confirmPreflight() async {
    if (!isCurrent) return false;
    try {
      final state = await _owner._captureArbiter!.readAllAudioState();
      return isCurrent &&
          state.allClear &&
          state.hasSameSnapshotAs(_nativeSnapshot);
    } on Object {
      return false;
    }
  }

  void retire() {
    if (_retired) return;
    _retired = true;
    _cancel = null;
    _owner._captureActions.remove(this);
  }

  void _invalidate() {
    if (_retired) return;
    _retired = true;
    final cancel = _cancel;
    _cancel = null;
    _owner._captureActions.remove(this);
    cancel?.call();
  }
}

/// App-lifetime, isolate-local context boundary. It deliberately has no
/// player or microphone implementation. Production acquisition is disabled.
final class PracticeAudioRootOwner {
  PracticeAudioRootOwner({
    required ValueListenable<String?> userId,
    required ValueListenable<MotionIdentityPhase> phase,
    required PracticeAudioLease lease,
    NativeAudioArbiterChannel? captureArbiter,
    PracticeVideoSessionOwner? videoOwner,
    AppLifecycleState? initialLifecycleState,
    @visibleForTesting this.allowDetachedRouteEventsForTest = false,
    this.allowAcquisition = false,
    @visibleForTesting this.allowVideoAcquisitionForTest = false,
    this.nativeFenceEnabled = true,
    this.onStatusChanged,
  }) : _userIdListenable = userId,
       _phaseListenable = phase,
       _lease = lease,
       _captureArbiter = captureArbiter,
       _videoOwner = videoOwner,
       _userId = userId.value,
       _phase = phase.value,
       _foreground = initialLifecycleState == AppLifecycleState.resumed {
    if (videoOwner != null) {
      if (!nativeFenceEnabled) {
        throw ArgumentError('Video owner requires native context fencing');
      }
      if (captureArbiter != null &&
          !identical(captureArbiter, videoOwner.port)) {
        throw ArgumentError('Capture and video must share one native channel');
      }
      _lease.attachVideoFenceSettler(
        videoOwner.port,
        videoOwner.settleAfterFence,
      );
    }
    // The root constructs this before building MotionIdentityGate or the
    // account-keyed Navigator; these listeners fence before either rebuilds.
    _userIdListenable.addListener(_onUserChanged);
    _phaseListenable.addListener(_onPhaseChanged);
  }

  final ValueListenable<String?> _userIdListenable;
  final ValueListenable<MotionIdentityPhase> _phaseListenable;
  final PracticeAudioLease _lease;
  final NativeAudioArbiterChannel? _captureArbiter;
  final PracticeVideoSessionOwner? _videoOwner;
  final Set<PracticeAudioCaptureAction> _captureActions = {};

  /// Test seam only. The production root always keeps this false.
  final bool allowAcquisition;

  /// Test-only admission until the native video plugin validates each permit.
  @visibleForTesting
  final bool allowVideoAcquisitionForTest;
  final bool nativeFenceEnabled;

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
  Future<PracticeAudioReleaseStatus>? _lastFence;

  PracticeAudioLeasePhase get leasePhase => _lease.phase;
  bool get blocked =>
      _lease.phase == PracticeAudioLeasePhase.blockedUnconfirmed ||
      (_videoOwner?.blocked ?? false);
  bool get recovering => _recovering;
  bool get nativeReplyPending =>
      _lastRecoveryStatus == PracticeAudioReleaseStatus.pendingNative;
  Route<dynamic>? get topRoute => _topRoute;
  @visibleForTesting
  Future<PracticeAudioReleaseStatus>? get lastFenceForTest => _lastFence;

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
        (_videoOwner?.busy ?? false) ||
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

  /// This seam proves Dart ordering with a fake player. Shipping lessons never
  /// request an action; their media slot remains empty.
  @visibleForTesting
  PracticeVideoStartAction? videoActionFor(Route<dynamic> route) {
    final observer = _observer;
    if (_disposed ||
        !allowVideoAcquisitionForTest ||
        _videoOwner == null ||
        _videoOwner.busy ||
        !_identityReady ||
        !_foreground ||
        _barrier ||
        observer == null ||
        !identical(_topRoute, route) ||
        blocked) {
      return null;
    }
    return PracticeVideoStartAction._(
      this,
      route,
      observer,
      _identityEpoch,
      _routeEpoch,
      _visibilityEpoch,
    );
  }

  bool _validVideoAction(PracticeVideoStartAction action) =>
      identical(action._owner, this) &&
      !_disposed &&
      allowVideoAcquisitionForTest &&
      _videoOwner != null &&
      _identityReady &&
      _foreground &&
      !_barrier &&
      !blocked &&
      identical(action._observer, _observer) &&
      identical(action._route, _topRoute) &&
      action._identityEpoch == _identityEpoch &&
      action._routeEpoch == _routeEpoch &&
      action._visibilityEpoch == _visibilityEpoch;

  Future<PracticeVideoOpenStatus> startVideo(
    PracticeVideoStartAction action,
    PracticeVideoPlayerPort player,
  ) async {
    if (action._consumed || !_validVideoAction(action)) {
      return PracticeVideoOpenStatus.staleContext;
    }
    action._consumed = true;
    final video = _videoOwner!;
    final status = await video.open(
      player,
      isCurrent: () => _validVideoAction(action),
    );
    if (status == PracticeVideoOpenStatus.ready && !_validVideoAction(action)) {
      return await video.close()
          ? PracticeVideoOpenStatus.staleContext
          : PracticeVideoOpenStatus.blockedUnconfirmed;
    }
    return status;
  }

  /// Legacy microphone capture remains separate from practice-lease
  /// acquisition. The latter is still disabled in production.
  PracticeAudioCaptureAction? captureActionFor(Route<dynamic> route) {
    final observer = _observer;
    final native = _captureArbiter?.capturePreflightSnapshot;
    if (_disposed ||
        !_identityReady ||
        !_foreground ||
        _barrier ||
        observer == null ||
        !identical(_topRoute, route) ||
        blocked ||
        native == null) {
      return null;
    }
    final action = PracticeAudioCaptureAction._(
      this,
      route,
      observer,
      _identityEpoch,
      _routeEpoch,
      _visibilityEpoch,
      native,
    );
    _captureActions.add(action);
    return action;
  }

  bool _validCapture(PracticeAudioCaptureAction action) {
    final native = _captureArbiter?.capturePreflightSnapshot;
    return identical(action._owner, this) &&
        !_disposed &&
        _identityReady &&
        _foreground &&
        !_barrier &&
        !blocked &&
        identical(action._observer, _observer) &&
        identical(action._route, _topRoute) &&
        action._identityEpoch == _identityEpoch &&
        action._routeEpoch == _routeEpoch &&
        action._visibilityEpoch == _visibilityEpoch &&
        native != null &&
        native.hasSameSnapshotAs(action._nativeSnapshot);
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
    PracticeAudioSide side, {
    String? assetId,
  }) async {
    if (grant._consumed || !_valid(grant)) {
      return const AudioRouteAcquireResult(AudioRouteAcquireStatus.staleGrant);
    }
    // This synchronous assignment precedes the first await, so concurrent
    // continuations cannot spend the same action twice.
    grant._consumed = true;
    final result = await _lease.acquire(
      side,
      context: grant._leaseContext,
      assetId: assetId,
    );
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
      final videoResult = await _videoOwner?.recover();
      if (videoResult == PracticeVideoRecoveryStatus.busy ||
          videoResult == PracticeVideoRecoveryStatus.blockedUnconfirmed) {
        _lastRecoveryStatus = videoResult == PracticeVideoRecoveryStatus.busy
            ? PracticeAudioReleaseStatus.busy
            : PracticeAudioReleaseStatus.blockedUnconfirmed;
        return _lastRecoveryStatus!;
      }
      final leaseResult = await _lease.recover();
      final result =
          videoResult == PracticeVideoRecoveryStatus.confirmedClosed &&
              leaseResult == PracticeAudioReleaseStatus.alreadyIdle
          ? PracticeAudioReleaseStatus.confirmedClosed
          : leaseResult;
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
    // Stop a pending or running legacy microphone synchronously before the
    // shared native fence advances the context. A late permission reply can
    // only carry its now-stale original claim.
    for (final action in _captureActions.toList()) {
      action._invalidate();
    }
    _videoOwner?.invalidate();
    if (retireRoute) {
      _observer = null;
      _topRoute = null;
    }
    ++_routeEpoch;
    _barrier = true;
    final serial = ++_fenceSerial;
    // `invalidate` increments the lease epoch before returning its Future.
    final close = nativeFenceEnabled
        ? _lease.invalidateAndFence(reason)
        : _lease.invalidate(reason);
    _lastFence = close;
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

/// Exposes only a one-shot capture action to route widgets, never the root
/// owner or an unrestricted practice-audio lease grant.
class PracticeAudioCaptureScope extends InheritedWidget {
  const PracticeAudioCaptureScope._({
    required this.owner,
    required super.child,
  });

  final PracticeAudioRootOwner owner;

  static PracticeAudioCaptureAction? actionFor(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<PracticeAudioCaptureScope>();
    final route = ModalRoute.of(context);
    if (scope == null || route == null) return null;
    return scope.owner.captureActionFor(route);
  }

  @override
  bool updateShouldNotify(PracticeAudioCaptureScope oldWidget) =>
      !identical(owner, oldWidget.owner);
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
  Widget build(BuildContext context) => PracticeAudioCaptureScope._(
    owner: widget._owner,
    child: widget._builder(_observer),
  );
}

/// Persists above MotionIdentityGate while its child is removed. The optional
/// injected lease is for tests; mobile production uses the shared native
/// arbiter for closure while acquisition remains denied.
class OstinatoAudioRoot extends StatefulWidget {
  const OstinatoAudioRoot({
    super.key,
    required this.userId,
    required this.phase,
    this.child,
    this.builder,
    this.testLease,
    this.testCaptureArbiter,
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
  final NativeAudioArbiterChannel? testCaptureArbiter;
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
    final mobileNative =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.android);
    final nativeArbiter =
        widget.testCaptureArbiter ??
        (widget.testLease == null && mobileNative
            ? NativeAudioArbiterChannel()
            : null);
    _owner = PracticeAudioRootOwner(
      userId: widget.userId,
      phase: widget.phase,
      lease:
          widget.testLease ??
          PracticeAudioLease(
            port: nativeArbiter ?? const _NoNativeAudioArbiter(),
          ),
      captureArbiter: nativeArbiter,
      initialLifecycleState: WidgetsBinding.instance.lifecycleState,
      allowAcquisition: widget.allowTestAcquisition,
      nativeFenceEnabled: widget.testLease != null || mobileNative,
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
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationsDelegates,
        home: Builder(
          builder: (statusContext) => Scaffold(
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        localized(
                          statusContext,
                          'Audio shutdown could not be confirmed.',
                          'Ses kaynağının kapandığı doğrulanamadı.',
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (_owner.nativeReplyPending) ...[
                        const SizedBox(height: 12),
                        Text(
                          localized(
                            statusContext,
                            'A previous device reply is still pending.',
                            'Önceki cihaz yanıtı hâlâ bekleniyor.',
                          ),
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
                          localized(
                            statusContext,
                            'Retry shutdown',
                            'Kapanmayı yeniden dene',
                          ),
                        ),
                      ),
                    ],
                  ),
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
