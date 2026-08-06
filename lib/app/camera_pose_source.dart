import 'dart:async';

import 'package:motion_camera/motion_camera.dart';
import 'package:motion_core/motion_core.dart' as core;
import 'package:ostinato_posture/ostinato_posture.dart';

import 'camera_session.dart';
import 'pose_model.dart';

/// Gerçek kamera → `PoseSource` adaptörü (tur-2).
///
/// Yüzey DEĞİŞMEZ (tur-1'in taahhüdü): bu sınıf yalnız `status`/`frames`
/// akışlarını doldurur, `PostureScreen` aynı sealed hâlleri çizer —
/// [FakePoseSource]'un yerini alır, ekranın hiçbir satırı değişmez.
///
/// **Kanıt sınıfı DÜRÜST:** bu dosya plumbing + izin + hâlleri sim'de
/// kanıtlar. GERÇEK GÖRÜNTÜ kanıtı YOK — iOS simülatöründe kamera donanımı
/// yok, `start()` sim'de büyük olasılıkla `noSuchCamera`/kurulum hatasına
/// düşer ve DÜRÜST hâl ekranı açılır (çıkmaz-sokak değil). Bağlandı ≠
/// canlı; gerçek postür ölçümü cihaz-günü release-gate (M-F-263).
///
/// **İsimli, revize edilebilir seçim:** ön kamera (`CameraLens.front`) —
/// kullanıcı telefonu kendine bakacak şekilde yerleştirir (ayna kurulumu),
/// Gravita'nın arka-kamera seçiminden farklı (o, yerde farklı bir kurulum).
/// Cihaz günü gerçek kullanımla sınanmadan kesin sayılmaz.
final class CameraPoseSource implements PoseSource {
  CameraPoseSource({MotionCameraController? controller})
      : _camera = controller ?? MotionCameraController();

  final MotionCameraController _camera;
  final CameraPostureAdapter _adapter = CameraPostureAdapter();

  final StreamController<PoseFrame> _frames =
      StreamController<PoseFrame>.broadcast();
  final StreamController<SurfaceState> _status =
      StreamController<SurfaceState>.broadcast();

  StreamSubscription<CameraFrameEnvelope>? _sub;
  bool _running = false;

  @override
  Stream<PoseFrame> get frames => _frames.stream;

  @override
  Stream<SurfaceState> get status => _status.stream;

  @override
  Future<void> start() async {
    final CameraStartResult result = await requestAndStartCamera(
      _camera,
      modelPath: await PoseModelPin.resolveFilePath(),
      modelId: PoseModelPin.modelId,
    );
    switch (result) {
      case CameraStartFailed(:final SurfaceState state):
        _status.add(state);
        return;
      case CameraStarted(:final CameraSessionInfo info):
        _running = true;
        final core.FrameSize size = core.FrameSize(info.width, info.height);
        _sub = _camera.frames().listen(
          (CameraFrameEnvelope e) => _onEnvelope(e, size),
          onError: (Object err) {
            _status.add(err is CameraException
                ? cameraFailureState(err.failure)
                : SetupFailed('unexpected: $err'));
          },
        );
    }
  }

  void _onEnvelope(CameraFrameEnvelope e, core.FrameSize size) {
    // uprightOnly planı bu geçişi HER zaman çalıştırır; olmaması planlama
    // hatası olurdu (CameraFrameEnvelope.pass kendi StateError'ünü fırlatır) —
    // kare-başına sessizce atlanır, ders çökmez.
    if (!e.ran(core.BodyOrientation.upright)) return;
    final core.PoseFrame? raw = e.pass(core.BodyOrientation.upright);
    if (raw == null) {
      // MediaPipe kimseyi görmedi — uydurma sayı YOK.
      _frames.add(PoseFrame(tUs: e.tUs, trunkTiltDeg: null));
      return;
    }
    final double? deg = _adapter.trunkTiltDeg(raw, size);
    _frames.add(PoseFrame(tUs: e.tUs, trunkTiltDeg: deg));
  }

  @override
  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    if (_running) {
      _running = false;
      try {
        await _camera.stop();
      } on Object {
        // Durdurmada arıza kullanıcıyı ilgilendirmez: oturum zaten bitiyor
        // (Gravita deseni, live_session_screen.dart `_stop()`).
      }
    }
    _adapter.reset();
  }

  /// Test/harness kolaylığı — `FakePoseSource.dispose()` ile aynı şekil.
  /// Üretim yolu (main.dart) bunu çağırmaz; `PostureScreen.dispose()`
  /// yalnız `stop()` çağırır (var olan aile deseni, değiştirilmedi).
  Future<void> dispose() async {
    await _frames.close();
    await _status.close();
  }
}
