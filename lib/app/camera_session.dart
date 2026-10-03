import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:motion_camera/motion_camera.dart';
import 'package:ostinato_posture/ostinato_posture.dart';
import 'package:permission_handler/permission_handler.dart';

import 'account_connection.dart';

typedef CameraPermissionRequest = Future<PermissionStatus> Function();
typedef CameraModelPathResolver = Future<String> Function();

// This controller and its uncertainty survive route and account replacement.
final MotionCameraController processCameraController = MotionCameraController();
final Set<CameraCaptureOwner> _cameraOwners = <CameraCaptureOwner>{};
CameraCaptureOwner? _activeCameraOwner;
ValueListenable<bool>? _resourceAdmission;
int _cameraBoundaryRevision = 0;
int _cameraTestIsolation = 0;
bool _cameraUncertain = false;
Future<void>? _closing;

/// Deny-only app resource lifetime. Core remains the sole identity gate.
/// Retain this pointer when a gated subtree disappears; a disposed app epoch
/// returns false. A successor binding must explicitly supply its current epoch.
void bindCameraResourceAdmission(ValueListenable<bool>? resourceAdmission) {
  _resourceAdmission = resourceAdmission;
}

CameraCaptureOwner registerCameraOwner(
  MotionCameraController controller, {
  ValueListenable<AppLifecycleState>? lifecycle,
}) => CameraCaptureOwner._(controller, lifecycle);

/// Invalidates pending model/permission work before any route rebuild/await.
void retireAllCameraOwners() {
  ++_cameraBoundaryRevision;
  for (final CameraCaptureOwner owner in _cameraOwners.toList()) {
    owner.retire();
  }
}

/// Observe errors without replacing the original failing close Future.
void observeCameraWork(Future<void> work) {
  unawaited(work.then<void>((_) {}, onError: (Object _, StackTrace _) {}));
}

void _noteClosing(Future<void> closing) {
  final int isolation = _cameraTestIsolation;
  final Future<void>? previous = _closing;
  final Future<void> joined = previous == null
      ? closing
      : Future.wait<void>(<Future<void>>[previous, closing]).then<void>((_) {});
  _closing = joined;
  unawaited(joined.then<void>((_) {}, onError: (Object _, StackTrace _) {
    if (isolation == _cameraTestIsolation) _cameraUncertain = true;
  }));
}

@visibleForTesting
void noteClosing(Future<void> closing) => _noteClosing(closing);

/// A later barrier is never cleared by an earlier completion. Failed barriers
/// remain installed, and no successful native stop can reset uncertainty.
Future<void> awaitPendingClose() async {
  while (_closing != null) {
    final Future<void> observed = _closing!;
    await observed;
    if (identical(_closing, observed)) _closing = null;
  }
  if (_cameraUncertain) {
    throw const CameraException(CameraFailure.closeUncertain,
        'an earlier camera closure remains uncertain');
  }
}

@visibleForTesting
void resetCameraSessionForTesting() {
  // Test fixtures each own a disposable injected controller. Production never
  // calls this reset and never constructs a controller to bypass quarantine.
  for (final CameraCaptureOwner owner in _cameraOwners.toList()) {
    owner.retire();
  }
  ++_cameraTestIsolation;
  _cameraOwners.clear();
  _activeCameraOwner = null;
  _resourceAdmission = null;
  _cameraBoundaryRevision = 0;
  _cameraUncertain = false;
  _closing = null;
}

/// App ownership includes permission/model work that has no native session yet.
final class CameraCaptureOwner with WidgetsBindingObserver
    implements AccountResourceDrain {
  CameraCaptureOwner._(MotionCameraController controller, this._lifecycle)
      : lease = controller.createCaptureLease(),
        _boundaryRevision = _cameraBoundaryRevision,
        _testIsolation = _cameraTestIsolation {
    _cameraOwners.add(this);
    if (_lifecycle != null) {
      _lifecycle.addListener(_onInjectedLifecycle);
    } else {
      WidgetsBinding.instance.addObserver(this);
    }
    final ValueListenable<bool>? admission = _resourceAdmission;
    if (admission != null && admission is AccountResourceDrainRegistry) {
      // This registry captures immutable namespace metadata before any await.
      // It can synchronously deny and retire this owner during registration.
      final AccountResourceDrainRegistration registration =
          (admission as AccountResourceDrainRegistry).registerResource(resource: this);
      _resourceRegistration = registration;
      if (_retired) _observeResourceRetirement();
    }
    // Lifecycle hooks were attached before registration so immediate denial
    // could remove them. Do not attach or revive them after that retirement.
    if (!_retired) _onLifecycle(lifecycleState);
  }

  final CameraCaptureLease lease;
  final ValueListenable<AppLifecycleState>? _lifecycle;
  final int _boundaryRevision;
  final int _testIsolation;
  final Completer<void> _retiredSignal = Completer<void>();
  Completer<void>? _foregroundWake;
  Future<void>? _closeFuture;
  AccountResourceDrainRegistration? _resourceRegistration;
  Future<void>? _resourceDrainFuture;
  bool _retired = false;
  SurfaceState? _failure;
  bool _failureReported = false;
  AppLifecycleState _lastLifecycle = AppLifecycleState.resumed;

  bool get isContextCurrent => _boundaryRevision == _cameraBoundaryRevision &&
      _testIsolation == _cameraTestIsolation;
  bool get isRetired => _retired || lease.isRetired;
  AppLifecycleState get lifecycleState => _lifecycle?.value ??
      WidgetsBinding.instance.lifecycleState ?? _lastLifecycle;
  bool get isForeground => lifecycleState == AppLifecycleState.resumed;
  bool get canObserveFrames => !_retired && !lease.isRetired &&
      !lease.isUncertain && isContextCurrent && isForeground &&
      (_resourceAdmission?.value ?? true) && identical(_activeCameraOwner, this);

  void _onInjectedLifecycle() => _onLifecycle(_lifecycle!.value);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => _onLifecycle(state);

  void _onLifecycle(AppLifecycleState state) {
    _lastLifecycle = state;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      retire();
    } else if (state == AppLifecycleState.resumed) {
      final Completer<void>? wake = _foregroundWake;
      _foregroundWake = null;
      if (wake != null && !wake.isCompleted) wake.complete();
    }
    // OS permission dialogs can transiently be inactive; await resumed rather
    // than retiring the pending initial permission owner or opening in inactive.
  }

  void ensureAdmission() {
    if (isRetired || !isContextCurrent) {
      throw const CameraException(CameraFailure.sessionInterrupted,
          'the captured camera lifetime has retired');
    }
    if (_cameraUncertain) {
      throw const CameraException(CameraFailure.closeUncertain,
          'the process camera remains quarantined');
    }
    if (!(_resourceAdmission?.value ?? true)) {
      throw const CameraException(CameraFailure.sessionInterrupted,
          'app resource admission is denied');
    }
  }

  Future<void> waitForForeground() async {
    while (!isForeground) {
      ensureAdmission();
      final Completer<void> wake = _foregroundWake ??= Completer<void>();
      await Future.any<void>(<Future<void>>[wake.future, _retiredSignal.future]);
    }
    ensureAdmission();
  }

  void activate() {
    ensureAdmission();
    _activeCameraOwner = this;
  }

  void fail(SurfaceState state) {
    if (!_retired && isContextCurrent) _failure ??= state;
    retire();
  }

  /// Core v2 retires before delivering its transport error. App retirement is
  /// separate so the current owner can surface that typed denial exactly once.
  void failTransport(Object error) {
    if (_retired || !isContextCurrent || !identical(_activeCameraOwner, this)) return;
    _cameraUncertain = true;
    fail(const SetupFailed('close-uncertain'));
  }

  SurfaceState? takeFailure() {
    if (!isContextCurrent || _failureReported || _failure == null) return null;
    _failureReported = true;
    return _failure;
  }

  @override
  void retire() {
    if (_retired) return;
    _retired = true;
    lease.retire();
    if (!_retiredSignal.isCompleted) _retiredSignal.complete();
    if (_lifecycle != null) {
      _lifecycle.removeListener(_onInjectedLifecycle);
    } else {
      WidgetsBinding.instance.removeObserver(this);
    }
    if (identical(_activeCameraOwner, this)) _activeCameraOwner = null;
    final Future<void> closing = lease.close();
    _closeFuture = closing;
    _noteClosing(closing);
    unawaited(closing.then<void>((_) {
      _cameraOwners.remove(this);
    }, onError: (Object _, StackTrace _) {
      if (_testIsolation == _cameraTestIsolation) _cameraUncertain = true;
    }));
    // Cache the exact original close before forwarding any reentrant hook.
    _observeResourceRetirement();
  }

  void _observeResourceRetirement() {
    final AccountResourceDrainRegistration? registration = _resourceRegistration;
    if (registration != null) {
      observeCameraWork(Future<void>.sync(registration.retireAndDrain));
    }
  }

  @override
  Future<void> waitForClosed() {
    final Future<void>? existing = _resourceDrainFuture;
    if (existing != null) return existing;
    final Completer<void> proof = Completer<void>();
    final Future<void> work = proof.future;
    // Publish before close(): natural retirement can reenter through registry.
    _resourceDrainFuture = work;
    observeCameraWork(work);
    try {
      final Future<void> exactClose = close();
      unawaited(_verifyResourceClosure(exactClose).then<void>((_) {
        proof.complete();
      }, onError: (Object error, StackTrace stack) {
        proof.completeError(error, stack);
      }));
    } on Object catch (error, stack) {
      proof.completeError(error, stack);
    }
    return work;
  }

  Future<void> _verifyResourceClosure(Future<void> exactClose) async {
    await exactClose;
    if (lease.isUncertain || _cameraUncertain) {
      throw const CameraException(CameraFailure.closeUncertain,
          'the captured camera resource closure remains uncertain');
    }
  }

  Future<void> close() {
    retire();
    return _closeFuture!;
  }
}

sealed class CameraStartResult {
  const CameraStartResult();
}

final class CameraStarted extends CameraStartResult {
  const CameraStarted(this.info);
  final CameraSessionInfo info;
}

final class CameraStartFailed extends CameraStartResult {
  const CameraStartFailed(this.state);
  final SurfaceState state;
}

SurfaceState permissionState(PermissionStatus perm) {
  if (perm.isPermanentlyDenied || perm.isRestricted) {
    return const PermissionDeniedPermanent();
  }
  return const PermissionDeniedRetriable();
}

SurfaceState cameraFailureState(CameraFailure failure) =>
    failure == CameraFailure.permissionDenied
        ? const PermissionDeniedRetriable()
        : SetupFailed(failure.code);

Future<CameraStartResult> requestAndStartCamera(
  CameraCaptureOwner owner, {
  required CameraModelPathResolver resolveModelPath,
  required String modelId,
  CameraLens lens = CameraLens.front,
  PassPlan initialPlan = PassPlan.uprightOnly,
  CameraPermissionRequest? requestPermission,
}) async {
  try {
    owner.ensureAdmission();
    await awaitPendingClose();
    owner.ensureAdmission();
    final PermissionStatus permission =
        await (requestPermission ?? Permission.camera.request)();
    owner.ensureAdmission();
    if (!permission.isGranted) {
      final SurfaceState denied = permissionState(permission);
      owner.fail(denied);
      return CameraStartFailed(denied);
    }
    await owner.waitForForeground();
    final String modelPath = await resolveModelPath();
    owner.ensureAdmission();
    await owner.waitForForeground();
    while (true) {
      // Permission, model and foreground waits can admit a newer closure.
      // Drain it, then check synchronously before the owned native start RPC.
      await awaitPendingClose();
      owner.ensureAdmission();
      if (!owner.isForeground) {
        await owner.waitForForeground();
        continue;
      }
      if (_closing != null) continue;
      final CameraSessionInfo info = await owner.lease.start(
        modelPath: modelPath, modelId: modelId, lens: lens, initialPlan: initialPlan,
      );
      // Native ACK may arrive during a transient OS permission interruption.
      // Keep this original start pending; background retirement still denies it.
      do {
        await owner.waitForForeground();
        owner.ensureAdmission();
      } while (!owner.isForeground);
      owner.activate();
      return CameraStarted(info);
    }
  } on CameraException catch (error) {
    final SurfaceState failure = cameraFailureState(error.failure);
    owner.fail(failure);
    return CameraStartFailed(failure);
  } on Object {
    const SurfaceState failure = SetupFailed('model-load-failed');
    owner.fail(failure);
    return const CameraStartFailed(failure);
  }
}
