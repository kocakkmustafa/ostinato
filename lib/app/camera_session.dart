import 'package:flutter/foundation.dart';
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

/// 🔒 SÜREÇ-GENELİ KAPANIŞ KİLİDİ (O-076 · Choreia C-195 aktarımı).
///
/// **Cihazda TEK kamera var** ama her ekran kendi `MotionCameraController`ını
/// kurar. `State.dispose()` SENKRONDUR — `stop()` bir platform-kanalı
/// gidiş-dönüşüdür ve BEKLENEMEZ. Sonuç: bir ekran kapanırken kamerayı hâlâ
/// bırakıyorken bir sonraki ekran `start()` çağırır → `already-running`.
///
/// **Ostinato'da bu Choreia'dakinden GENİŞ:** onların yarışı kullanıcının
/// hızlıca İKİNCİ bir ders açmasını gerektiriyor; bizde **her dersin ZORUNLU
/// yolunda** — Kurulum Kontrolü (kamera açık) → "Start the lesson" →
/// `pushReplacement` → `SetupCheck.dispose()` stop'u başlatır ama beklemez →
/// `LiveScreen` hemen `start()` çağırır.
///
/// Bugün onu maskeleyen tek şey **iki kullanıcı dokunuşunun gecikmesi** —
/// yani insan tepki süresi. Bu bir garanti değil, ŞANS. Ve N=1'de yapısal
/// olarak görünmez: 152 testin hepsi "ekran çalışıyor mu" diye soruyor ve
/// cevap ilk seferinde evet.
///
/// Kilit: `start` önce uçuştaki kapanışı BEKLER. **N=1'de bekleme sıfırdır**
/// (uçuşta kapanış yoksa `await null` maliyeti yok).
Future<void>? _closing;

/// Kamerayı bırakır ve bırakışı KAYDEDER, böylece bir sonraki `start` bekler.
///
/// `dispose()` bunu `await` EDEMEZ (senkron) — etmesine gerek de yok:
/// önemli olan kapanışın İZLENMESİ, bitmesinin beklenmesi değil. Bekleme
/// işini bir sonraki `start` yapar, ve tam da beklemesi gereken yer orası.
void releaseCamera(MotionCameraController camera) {
  noteClosing(camera.stop().catchError((Object _) {}));
}

/// Kapanışı kaydeder — test edilebilir olsun diye ayrı (kamera eklentisi
/// widget testinde yok; kilidin KENDİSİ eklentiden bağımsız sınanmalı).
@visibleForTesting
void noteClosing(Future<void> closing) => _closing = closing;

/// Uçuştaki kapanışı bekler. N=1'de maliyet SIFIR.
@visibleForTesting
Future<void> awaitPendingClose() async {
  final Future<void>? closing = _closing;
  if (closing != null) {
    await closing;
    _closing = null;
  }
}

Future<CameraStartResult> requestAndStartCamera(
  MotionCameraController camera, {
  required String modelPath,
  required String modelId,
  CameraLens lens = CameraLens.front,
  PassPlan initialPlan = PassPlan.uprightOnly,
}) async {
  try {
    // Uçuşta bir kapanış varsa BİTMESİNİ bekle — cihazda tek kamera var.
    await awaitPendingClose();
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
