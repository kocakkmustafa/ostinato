import 'package:motion_camera/motion_camera.dart';
import 'package:ostinato_posture/ostinato_posture.dart';
import 'package:permission_handler/permission_handler.dart';

/// İzin isteği + `MotionCameraController.start()` — hem [CameraPoseSource]
/// hem Kurulum Kontrolü'nün kamera probu bunu kullanır (tekrar YAZILMADI).
/// Başarı: `CameraSessionInfo`. Başarısızlık: eşlenmiş [SurfaceState]
/// (`CameraPoseSource._failureState`/`_permissionState` ile AYNI kural).
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

/// `CameraFailure` → sealed hâl. Eşleme HAZIR (tur-2 devir promptu):
/// `permissionDenied` → izin hâli, geri kalan HER kod → `SetupFailed(reason)`.
SurfaceState cameraFailureState(CameraFailure failure) {
  if (failure == CameraFailure.permissionDenied) {
    return const PermissionDeniedRetriable();
  }
  return SetupFailed(failure.code);
}

Future<CameraStartResult> requestAndStartCamera(
  MotionCameraController camera, {
  required String modelPath,
  required String modelId,
  CameraLens lens = CameraLens.front,
  PassPlan initialPlan = PassPlan.uprightOnly,
}) async {
  try {
    final PermissionStatus perm = await Permission.camera.request();
    if (!perm.isGranted) {
      return CameraStartFailed(permissionState(perm));
    }
    final CameraSessionInfo info = await camera.start(
      modelPath: modelPath,
      modelId: modelId,
      lens: lens,
      initialPlan: initialPlan,
    );
    return CameraStarted(info);
  } on CameraException catch (e) {
    return CameraStartFailed(cameraFailureState(e.failure));
  } on Object catch (e) {
    return CameraStartFailed(SetupFailed('unexpected: $e'));
  }
}
