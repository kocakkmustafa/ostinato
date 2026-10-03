import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
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
  CameraPoseSource({
    MotionCameraController? controller,
    CameraModelPathResolver? resolveModelPath,
    CameraPermissionRequest? requestPermission,
    ValueListenable<AppLifecycleState>? lifecycle,
  }) : _camera = controller ?? processCameraController,
       _resolveModelPath = resolveModelPath ?? PoseModelPin.resolveFilePath,
       _requestPermission = requestPermission,
       _lifecycle = lifecycle {
    _owner = registerCameraOwner(_camera, lifecycle: _lifecycle);
  }

  final MotionCameraController _camera;
  final CameraModelPathResolver _resolveModelPath;
  final CameraPermissionRequest? _requestPermission;
  final ValueListenable<AppLifecycleState>? _lifecycle;
  late final CameraCaptureOwner _owner;

  @visibleForTesting
  CameraCaptureLease get captureLease => _owner.lease;

  bool get canObserveFrames => !_stopRequested && !_disposed && _owner.canObserveFrames;
  bool get canObserveStatus => !_stopRequested && !_disposed && _owner.isContextCurrent;

  @visibleForTesting
  bool get hasFrameListeners => _frames.hasListener;

  @visibleForTesting
  bool get hasStatusListeners => _status.hasListener;
  final CameraPostureAdapter _adapter = CameraPostureAdapter();

  final StreamController<PoseFrame> _frames =
      StreamController<PoseFrame>.broadcast();
  final StreamController<SurfaceState> _status =
      StreamController<SurfaceState>.broadcast();

  StreamSubscription<CameraFrameEnvelope>? _sub;
  bool _stopRequested = false;
  bool _disposed = false;
  Future<void>? _lastStart;
  Future<void>? _stopFuture;
  Future<void>? _disposeFuture;

  @visibleForTesting
  Future<void>? get startSettlementForTesting => _lastStart;

  @override
  Stream<PoseFrame> get frames => _frames.stream;

  @override
  Stream<SurfaceState> get status => _status.stream;

  @override
  Future<void> start() {
    return _lastStart ??= _start();
  }

  Future<void> _start() async {
    final CameraStartResult result = await requestAndStartCamera(
      _owner,
      resolveModelPath: _resolveModelPath,
      modelId: PoseModelPin.modelId,
      requestPermission: _requestPermission,
    );
    switch (result) {
      case CameraStartFailed():
        _publishFailure();
        return;
      case CameraStarted(:final CameraSessionInfo info):
        if (!canObserveFrames) return;
        final core.FrameSize size = core.FrameSize(info.width, info.height);
        _sub = _owner.lease.frames().listen(
          (CameraFrameEnvelope e) => _onEnvelope(e, size),
          onError: (Object err) {
            _owner.failTransport(err);
            _publishFailure();
          },
        );
    }
  }

  void _onEnvelope(CameraFrameEnvelope e, core.FrameSize size) {
    if (!canObserveFrames) return;
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
  Future<void> stop() {
    if (_stopFuture != null) return _stopFuture!;
    _stopRequested = true;
    _owner.retire();
    final Future<void> closing = _finishStop();
    _stopFuture = closing;
    observeCameraWork(closing);
    return closing;
  }

  Future<void> _finishStop() async {
    final StreamSubscription<CameraFrameEnvelope>? sub = _sub;
    _sub = null;
    await Future.wait<void>(<Future<void>>[
      _owner.close(),
      if (sub != null) sub.cancel(),
    ]);
    _adapter.reset();
  }

  void _publishFailure() {
    if (!canObserveStatus || _status.isClosed) return;
    final SurfaceState? failure = _owner.takeFailure();
    if (failure != null) _status.add(failure);
  }

  Future<void> dispose() {
    _disposed = true;
    return _disposeFuture ??= _dispose();
  }

  Future<void> _dispose() async {
    try {
      await stop();
    } finally {
      await Future.wait<void>(<Future<void>>[_frames.close(), _status.close()]);
    }
  }
}
