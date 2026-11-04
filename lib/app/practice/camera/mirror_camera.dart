import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';
import 'package:ostinato_posture/ostinato_posture.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../camera_session.dart';

/// K8 hand lesson mirror: a live front-camera preview and nothing else. No
/// image stream, no recording, no audio, no hint: the image goes from the
/// sensor to the screen and is never read by app code.
///
/// One instance opens at most once and closes at most once; the screen makes
/// a new one to reopen (after the app comes back to the foreground).
abstract interface class MirrorCamera {
  /// Asks for permission and starts the preview. `null` = live; otherwise the
  /// state to show (permission denied, camera unavailable).
  Future<SurfaceState?> open();

  /// The live preview; only called after [open] returned `null`.
  Widget preview();

  /// Releases the camera; idempotent. Safe before, during or after [open].
  Future<void> close();
}

/// The device's front camera through the `camera` package. It shares the
/// process camera with motion_camera through [holdCameraUntil]: it opens only
/// when no motion_camera owner is live and no closure is pending, and holds a
/// closing barrier until it has released the camera.
final class DeviceMirrorCamera implements MirrorCamera {
  DeviceMirrorCamera({
    CameraPermissionRequest? requestPermission,
    Future<List<CameraDescription>> Function()? cameras,
  }) : _requestPermission = requestPermission ?? Permission.camera.request,
       _cameras = cameras ?? availableCameras;

  final CameraPermissionRequest _requestPermission;
  final Future<List<CameraDescription>> Function() _cameras;

  CameraController? _controller;
  Completer<void>? _released;
  Future<void>? _closeFuture;
  bool _closed = false;

  static const SurfaceState _busy = CameraUnavailable('camera-busy');
  static const SurfaceState _none = CameraUnavailable('no-camera');

  @override
  Future<SurfaceState?> open() async {
    try {
      if (_closed || !cameraAdmitted || cameraOwnedElsewhere) return _busy;
      final PermissionStatus permission = await _requestPermission();
      if (_closed) return _busy;
      if (!permission.isGranted) return permissionState(permission);
      // Drain any closure (motion_camera or an earlier mirror), then take the
      // camera synchronously, with the same checks as a motion_camera start.
      do {
        await awaitPendingClose();
      } while (cameraClosingPending);
      if (_closed || !cameraAdmitted || cameraOwnedElsewhere) return _busy;
      final Completer<void> released = _released = Completer<void>();
      holdCameraUntil(released.future, () => unawaited(close()));

      final List<CameraDescription> all = await _cameras();
      if (all.isEmpty) {
        await close();
        return _none;
      }
      final CameraDescription lens = all.firstWhere(
        (CameraDescription c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => all.first,
      );
      if (_closed) return _busy;
      final CameraController controller = _controller = CameraController(
        lens,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();
      if (_closed) return _busy;
      return null;
    } on CameraException catch (error) {
      await close();
      return switch (error.code) {
        'CameraAccessDenied' ||
        'CameraAccessDeniedWithoutPrompt' ||
        'CameraAccessRestricted' => const PermissionDeniedPermanent(),
        _ => const SetupFailed('mirror-start-failed'),
      };
    } on Object {
      // Includes an uncertain earlier closure (quarantine) from
      // awaitPendingClose: the mirror does not open over it.
      await close();
      return const SetupFailed('mirror-start-failed');
    }
  }

  @override
  Widget preview() => CameraPreview(_controller!);

  @override
  Future<void> close() => _closeFuture ??= _close();

  Future<void> _close() async {
    _closed = true;
    final CameraController? controller = _controller;
    final Completer<void>? released = _released;
    try {
      // dispose() also waits for an initialize() still in flight.
      await controller?.dispose();
      if (released != null && !released.isCompleted) released.complete();
    } on Object catch (error, stack) {
      if (released != null && !released.isCompleted) {
        released.completeError(error, stack);
      }
      rethrow;
    }
  }
}
