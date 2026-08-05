import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart' show ByteData, rootBundle;
import 'package:motion_camera/motion_camera.dart';
import 'package:motion_core/motion_core.dart' as core;
import 'package:ostinato_posture/ostinato_posture.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

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

  /// Asset'i uygulama-özel bir dosyaya yazar — plugin bundle DEĞİL bir YOL
  /// ister (Gravita `_modelPath()` deseni). Dosya zaten varsa yeniden
  /// yazılmaz.
  Future<String> _modelPath() async {
    final Directory dir = await getApplicationSupportDirectory();
    final File f =
        File('${dir.path}/${PoseModelPin.assetPath.split('/').last}');
    if (!await f.exists()) {
      final ByteData data = await rootBundle.load(PoseModelPin.assetPath);
      await f.writeAsBytes(data.buffer.asUint8List(), flush: true);
    }
    return f.path;
  }

  /// İzni kalıcı/geçici ayrımına çevirir (zeyil-3 deseni, JabLab emsali):
  /// sunulan eylem farklı olduğu için ayrım TİP taşır — "tekrar dene"
  /// kalıcı redde işlevsiz bir düğme olurdu.
  SurfaceState _permissionState(PermissionStatus perm) {
    if (perm.isPermanentlyDenied || perm.isRestricted) {
      return const PermissionDeniedPermanent();
    }
    return const PermissionDeniedRetriable();
  }

  /// `CameraFailure`ı yüzeyin sealed hâline çevirir. Eşleme HAZIR (tur-2
  /// devir promptu): `permissionDenied` → izin hâli, geri kalan HER kod →
  /// `SetupFailed(reason)`. ÇIKMAZ-SOKAK YASAĞI: hiçbir dal yakalanmadan
  /// geçmez, ders her zaman AÇILIR.
  SurfaceState _failureState(CameraFailure failure) {
    if (failure == CameraFailure.permissionDenied) {
      return const PermissionDeniedRetriable();
    }
    return SetupFailed(failure.code);
  }

  @override
  Future<void> start() async {
    try {
      // İzin ÖNCE ve AÇIKÇA (Gravita deseni): plugin izin İSTEMEZ — sorması
      // gereken app'tir; reddedilirse adı olan bir hâl doğar, boş ekran DEĞİL.
      final PermissionStatus perm = await Permission.camera.request();
      if (!perm.isGranted) {
        _status.add(_permissionState(perm));
        return;
      }

      final CameraSessionInfo info = await _camera.start(
        modelPath: await _modelPath(),
        modelId: PoseModelPin.modelId,
        lens: CameraLens.front,
        initialPlan: PassPlan.uprightOnly,
      );
      _running = true;
      final core.FrameSize size = core.FrameSize(info.width, info.height);

      _sub = _camera.frames().listen(
        (CameraFrameEnvelope e) => _onEnvelope(e, size),
        onError: (Object err) {
          _status.add(err is CameraException
              ? _failureState(err.failure)
              : SetupFailed('unexpected: $err'));
        },
      );
    } on CameraException catch (e) {
      _status.add(_failureState(e.failure));
    } on Object catch (e) {
      // Bilinmeyen istisna da tipli bir hâle döner: ders çıkmaz-sokağa
      // düşmez, ham metin yüzeye sızmaz (İSİMLİ sebep: "unexpected: ...").
      _status.add(SetupFailed('unexpected: $e'));
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
