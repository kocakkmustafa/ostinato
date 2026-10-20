import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import '../app_locale.dart';
import '../app_theme.dart';
import 'package:motion_camera/motion_camera.dart';
import 'package:motion_core/motion_core.dart' as core;
import 'package:ostinato_posture/ostinato_posture.dart';

import '../camera_session.dart';
import '../content.dart';
import '../design/ostinato_theme.dart';
import '../design/widgets.dart';
import '../pose_model.dart';
import 'live_screen.dart';

/// Kurulum Kontrolü — SERT KAPI (§3). Geçilmeden ölçüm modu başlamaz.
///
/// ⚠️ İSİMLİ SINIR (giydirme turu, 2026-08-05): tasarım hem kamera HEM
/// mikrofon kalibrasyonu gösterir ("oda gürültü tabanı, 3-5sn sessizlik").
/// Bu ekran yalnız KAMERA yarısını GERÇEKTEN ölçer (`ConfidenceGate` —
/// tur-2'nin aynı kapısı, iki eşik icat edilmedi). Mikrofon/oda gürültüsü
/// için canlı bir yakalama YOK — `ostinato_audio`nun `AudioConfidenceGate`i
/// var ama hiçbir mikrofon-giriş eklentisine bağlı değil. Sahte bir ilerleme
/// çubuğu GÖSTERMEK yerine bu adım kendi ismiyle "henüz yok" der.
class SetupCheckScreenRoute extends StatefulWidget {
  const SetupCheckScreenRoute(
      {super.key, required this.discipline, required this.lesson, required this.hue,
      this.controller, this.resolveModelPath, this.requestPermission,
      this.lifecycle, this.liveSource});
  final Discipline discipline;
  final Lesson lesson;
  final InstrumentHue hue;
  final MotionCameraController? controller;
  final CameraModelPathResolver? resolveModelPath;
  final CameraPermissionRequest? requestPermission;
  final ValueListenable<AppLifecycleState>? lifecycle;
  final PoseSource? liveSource;

  @override
  State<SetupCheckScreenRoute> createState() => _SetupCheckScreenRouteState();
}

enum _Stage { starting, framingError, lowLight, ok, room, passed }

class _SetupCheckScreenRouteState extends State<SetupCheckScreenRoute> {
  late final MotionCameraController _camera;
  late final CameraCaptureOwner _owner;
  StreamSubscription<CameraFrameEnvelope>? _sub;
  Future<void>? _closeFuture;
  bool _calibratingClose = false;
  final CameraPostureAdapter _adapter = CameraPostureAdapter();
  core.FrameSize? _size;

  _Stage _stage = _Stage.starting;
  SurfaceState? _failure;
  int _consecutiveOk = 0;

  static const int _dwellFrames = 8; // isimli UX debounce — ölçüm eşiği DEĞİL

  @override
  void initState() {
    super.initState();
    _camera = widget.controller ?? processCameraController;
    _owner = registerCameraOwner(_camera, lifecycle: widget.lifecycle);
    observeCameraWork(_start());
  }

  Future<void> _start() async {
    final CameraStartResult result = await requestAndStartCamera(
      _owner,
      resolveModelPath: widget.resolveModelPath ?? PoseModelPin.resolveFilePath,
      modelId: PoseModelPin.modelId,
      requestPermission: widget.requestPermission,
    );
    if (!mounted) return;
    switch (result) {
      case CameraStartFailed():
        _publishFailure();
      case CameraStarted(:final CameraSessionInfo info):
        if (!_owner.canObserveFrames) return;
        _size = core.FrameSize(info.width, info.height);
        _sub = _owner.lease.frames().listen(_onEnvelope, onError: (Object error) {
          _owner.failTransport(error);
          _publishFailure();
        });
    }
  }

  void _onEnvelope(CameraFrameEnvelope e) {
    if (!mounted || _calibratingClose || !_owner.canObserveFrames) return;
    if (_stage != _Stage.starting &&
        _stage != _Stage.framingError &&
        _stage != _Stage.lowLight &&
        _stage != _Stage.ok) {
      return;
    }
    if (!e.ran(core.BodyOrientation.upright)) return;
    final core.PoseFrame? raw = e.pass(core.BodyOrientation.upright);
    if (raw == null || _size == null) {
      _advance(_Stage.framingError);
      return;
    }
    final core.FrameQuality q = _adapter.frameQuality(raw, _size!);
    if (q.issue == core.QualityIssue.outOfFrame) {
      _advance(_Stage.framingError);
    } else if (q.issue == core.QualityIssue.torsoUnreliable ||
        q.issue == core.QualityIssue.lowTrackingConfidence) {
      _advance(_Stage.lowLight);
    } else {
      _consecutiveOk++;
      if (_consecutiveOk >= _dwellFrames) {
        _calibratingClose = true;
        observeCameraWork(_completeCalibration());
      } else {
        _advance(_Stage.ok);
      }
    }
  }

  void _advance(_Stage s) {
    if (!mounted) return;
    if (s != _Stage.ok) _consecutiveOk = 0;
    if (_stage == s) return;
    setState(() => _stage = s);
  }

  void _publishFailure() {
    if (!mounted || !_owner.isContextCurrent) return;
    final SurfaceState? failure = _owner.takeFailure();
    if (failure != null) setState(() => _failure = failure);
  }

  Future<void> _completeCalibration() async {
    try {
      await _stopCamera();
      if (!mounted || !_owner.isContextCurrent) return;
      if (!_owner.isForeground) {
        setState(() => _failure = const SetupFailed('lifecycle-unavailable'));
        return;
      }
      setState(() => _stage = _Stage.room);
    } on CameraException catch (error) {
      if (mounted && _owner.isContextCurrent) {
        setState(() => _failure = cameraFailureState(error.failure));
      }
    } on Object {
      if (mounted && _owner.isContextCurrent) {
        setState(() => _failure = const SetupFailed('close-uncertain'));
      }
    }
  }

  Future<void> _stopCamera() {
    if (_closeFuture != null) return _closeFuture!;
    _owner.retire();
    final StreamSubscription<CameraFrameEnvelope>? sub = _sub;
    _sub = null;
    final Future<void> closing = Future.wait<void>(<Future<void>>[
      _owner.close(),
      if (sub != null) sub.cancel(),
    ]).then<void>((_) {});
    _closeFuture = closing;
    observeCameraWork(closing);
    return closing;
  }

  @override
  void dispose() {
    observeCameraWork(_stopCamera());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OstinatoPalette.of(context).surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  GlassIconButton(
                      icon: '✕',
                      semanticLabel: localized(context, 'Cancel setup', 'Kurulumdan çık'),
                      onTap: () => Navigator.of(context).pop()),
                  kicker(localized(context, 'Setup check', 'Kurulum denetimi')),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 18),
              _StepBar(stage: _stage, hue: OstinatoPalette.of(context).instrument(widget.discipline.id)),
              const SizedBox(height: 18),
              Expanded(child: _stageBody(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stageBody(BuildContext context) {
    if (_failure != null) {
      return _CameraStage(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Text(_describeFailure(_failure!),
                key: const Key('setup-camera-failed'),
                textAlign: TextAlign.center,
                style: hankenText(size: 15, color: Colors.white, height: 1.5)),
          ),
        ),
      );
    }
    return switch (_stage) {
      _Stage.starting => _CameraStage(
          key: const Key('setup-stage-framing'),
          kicker: localized(context, 'FRAME', 'KADRAJ'),
          title: localized(context, 'Find your frame.', 'Kadrajını ayarla.'),
          // DÜZELTME-2 (O-099): "Nine points" burada bir OKUMA iddiasıydı
          // ("we do not read your head" ile aynı cümlede) ve ölçüme
          // uymuyordu — kamera DÖRT nokta okur (`LmRegion.torso`). BEŞİNCİ
          // yüzey: ilk sayım "upper-body" ifadesini aradığı için burayı
          // KAÇIRMIŞTI — deseni ifadeye bağlamanın, iddiaya bağlamamanın
          // aynı sınıf hatası (plist kapısının deliğiyle birebir aynı).
          body: localized(context,
              'You should be visible from your hips to your shoulders. Four points — your two shoulders and your two hips — and no face: we do not read your head, because our reference does not carry one.',
              'Omuzların ve kalçaların kadrajda olmalı. İki omuz ve iki kalça olmak üzere dört nokta okunur. Yüzün okunmaz; referans görüntümüzde baş bulunmaz.'),
          child: _Skeleton(dim: false),
        ),
      _Stage.framingError => _CameraStage(
          key: const Key('setup-stage-framing-error'),
          kicker: localized(context, 'FRAME', 'KADRAJ'),
          title: localized(context, 'Your hips are outside the frame.', 'Kalçaların kadraj dışında.'),
          body: localized(context,
              'Both hip points are missing, so there is no trunk line to measure. Move the phone back about an arm’s length, or sit closer to it.',
              'İki kalça noktası da görünmüyor; gövde çizgisi ölçülemiyor. Telefonu yaklaşık bir kol boyu uzaklaştır veya ona biraz yaklaş.'),
          warn: true,
          child: _Skeleton(dim: true),
        ),
      _Stage.lowLight => _CameraStage(
          key: const Key('setup-stage-low-light'),
          kicker: localized(context, 'LIGHT', 'IŞIK'),
          title: localized(context, 'Too dark to trust.', 'Görüntü yeterince aydınlık değil.'),
          body: localized(context,
              'Landmark confidence is below what we measure against. Turn on a light or face a window — we would rather refuse than guess.',
              'Vücut noktaları güvenilir biçimde okunmuyor. Bir ışık aç veya pencereye dön; tahmin ederek ölçüm yapmayız.'),
          warn: true,
          child: _Skeleton(dim: true),
        ),
      _Stage.ok => _CameraStage(
          key: const Key('setup-stage-ok'),
          kicker: localized(context, 'FRAME', 'KADRAJ'),
          title: localized(context, 'Holding steady…', 'Sabit dur…'),
          body: localized(context,
              'Frame and light look right. Hold still for a moment.',
              'Kadraj ve ışık uygun görünüyor. Kısa bir süre sabit dur.'),
          child: _Skeleton(dim: false),
        ),
      _Stage.room => _RoomGapNotice(
          onContinue: () => setState(() => _stage = _Stage.passed)),
      _Stage.passed => _PassedStage(
          discipline: widget.discipline, lesson: widget.lesson, hue: OstinatoPalette.of(context).instrument(widget.discipline.id),
          source: widget.liveSource),
    };
  }

  String _describeFailure(SurfaceState s) => switch (s) {
        PermissionDeniedRetriable() => localized(context,
          'Ostinato needs the camera to see how you sit. Tap the button below to allow it.',
          'Oturma duruşunu görebilmek için kamera erişimi gerekli. İzin vermek için aşağıdaki düğmeye dokun.'),
        PermissionDeniedPermanent() => localized(context,
          'Camera access is off and the system will not ask again. Open Settings to change it.',
          'Kamera erişimi kapalı ve sistem tekrar izin istemeyecek. Erişimi Ayarlar’dan açabilirsin.'),
        SetupFailed() => localized(context,
          'The camera did not start. The setup check cannot run without it. Return to the lesson to try again.',
          'Kamera açılamadı. Kurulum denetimi kamera olmadan çalışamaz. Yeniden denemek için derse dön.'),
        _ => localized(context, 'The camera is not available right now.',
          'Kamera şu anda kullanılamıyor.'),
      };
}

class _StepBar extends StatelessWidget {
  const _StepBar({required this.stage, required this.hue});
  final _Stage stage;
  final InstrumentHue hue;

  int get _step => switch (stage) {
        _Stage.starting || _Stage.framingError || _Stage.lowLight || _Stage.ok => 0,
        _Stage.room => 1,
        _Stage.passed => 2,
      };

  @override
  Widget build(BuildContext context) => Row(
        children: <Widget>[
          for (final (int i, String label) in <String>[
            localized(context, 'FRAME', 'KADRAJ'),
            localized(context, 'ROOM', 'ORTAM'),
            localized(context, 'READY', 'HAZIR'),
          ]
              .indexed) ...<Widget>[
            if (i > 0) const SizedBox(width: 7),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    height: 3,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      color: i < _step
                          ? OstinatoPalette.of(context).ink
                          : (i == _step
                              ? hue.ink
                              : OstinatoPalette.of(context).outline),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(label,
                      style: monoText(
                          size: 9,
                          color: i <= _step
                              ? OstinatoPalette.of(context).inkSoft
                              : OstinatoPalette.of(context).textMuted)),
                ],
              ),
            ),
          ],
        ],
      );
}

class _CameraStage extends StatelessWidget {
  const _CameraStage(
      {super.key, required this.child, this.kicker, this.title, this.body, this.warn = false});
  final Widget child;
  final String? kicker;
  final String? title;
  final String? body;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[Color(0xFF3A3348), Color(0xFF241F2E)],
                ),
              ),
              child: Stack(alignment: Alignment.center, children: <Widget>[
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(26),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(90),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: .22),
                            width: 1.4,
                            style: BorderStyle.solid),
                      ),
                    ),
                  ),
                ),
                Center(child: child),
              ]),
            ),
          ),
        ),
        if (kicker != null) ...<Widget>[
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: warn
                  ? OstinatoPalette.of(context).controlSurface
                  : OstinatoPalette.of(context).surface,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(kicker!,
                    style: monoText(
                        color: warn ? OstinatoPalette.of(context).warnInk : OstinatoPalette.of(context).textMono)),
                const SizedBox(height: 6),
                Text(title ?? '',
                    style: hankenText(size: 19, weight: FontWeight.w500)),
                const SizedBox(height: 6),
                Text(body ?? '', style: hankenText(size: 13.5, height: 1.5)),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton({required this.dim});
  final bool dim;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 170,
        height: 200,
        child: CustomPaint(
          painter: SkeletonFigurePainter(color: Colors.white, dim: dim),
        ),
      );
}

// PLACEHOLDER(asset): KAMERA ÖNİZLEMESİ YOK — bu ekran kadraj rehberi olarak
// canlı görüntü yerine yukarıdaki STATİK iskeleti çiziyor. Sınıf: ERTELENMİŞ
// (yapılabilir, biz yapmadık) — `Texture(`/`textureId`/`registrar.textures`
// ölçüldü: sevk edilen kodda SIFIR; pozitif kontrol `motion_camera|
// CameraSession` 8 satır, yani kamerayı GERÇEKTEN kullanıyoruz, göstermiyoruz.
// unblocked by: `motion_camera`nın `registrar.textures` yolunun bu ekrana
// bağlanması (JabLab `skeleton_overlay.dart` ile AYNI sınıf ve AYNI pin —
// iki hattın farklı sınıflandırması tek kısıtı iki şeymiş gibi okuturdu).
// source-only: kullanıcıya "kameranı göstermiyoruz" diyen bir cümle YOK.
//
// ⚠️ DÜZELTME (O-109, ölçümle): önceki not "kişi kendi kadrajını göremiyor,
// yalnız 'kalçandan omzuna görünmelisin' okuyor" diyordu. O cümle YALNIZ
// `_Stage.starting`i okuyup GENELLEMİŞTİ. Ölçüldü: poz akışı bu ekranda
// CANLI (`_camera.frames().listen(_onEnvelope)`) ve kalite sinyali zaten
// durum makinesini SÜRÜYOR — kullanıcı onayı ve adlı teşhisi ZATEN alıyor:
//   · `_Stage.ok`           → "Frame and light look right. Hold still…"
//   · `_Stage.framingError` → "Your hips are outside the frame." (HANGİ
//                              landmark eksik, adıyla)
//   · `_Stage.lowLight`     → "Landmark confidence is below what we measure"
// Yani eksik olan GÖRÜNTÜ; ONAY değil. Kullanıcının ihtiyacı olan "seni
// görüyorum" bugünkü kodla SÖYLENİYOR.
// ⛔ Sınır: bu üç hâl gerçek cihazda HİÇ doğrulanmadı (yayın engeli ⑩) —
// kod-gerçeği var, cihaz-gerçeği yok.
// closedPaths: ["kullanıcıya 'kadrajını göremiyorsun' cümlesi yazmak —
//   ÖLÇÜLDÜ ve ELENDİ (O-109): poz akışı bu ekranda CANLI ve kullanıcı
//   ZATEN adlı teşhis alıyor (`_Stage.framingError` HANGİ landmark eksik
//   diyor · `_Stage.lowLight` güven eşiğini söylüyor · `_Stage.ok` onaylıyor).
//   Eksik olan GÖRÜNTÜ, ONAY değil; cümle GÜRÜLTÜ olurdu. Bir eksiği
//   bildirmek, ardındaki ihtiyaç zaten karşılanıyorsa dürüstlük değildir."]

// PLACEHOLDER(flow): oda gürültü-tabanı yakalama adımı KAPALI — tasarım
// 3-5sn sessizlik ölçen bir kalibrasyon gösterir, bu ekran onun yerine
// dürüst bir "henüz yok" kartı gösterir (aşağıda). unblocked by: gerçek
// bir mikrofon-giriş eklentisi `ostinato_audio`nun var olan
// `AudioConfidenceGate`ine bağlanıp bu ekranın state machine'ine
// (_Stage.room) gerçek bir örnekleme/geri-sayım aşaması eklenince.
// closedPaths: none-known
// user-surface: setup-room-gap-body
// (O-107: bu beyanın KULLANICI cümlesi silinse iki kapı da yeşil kalıyordu —
//  sabotajla ölçüldü; artık `validate_placeholder_surface.py` onu koruyor.)
class _RoomGapNotice extends StatelessWidget {
  const _RoomGapNotice({required this.onContinue});
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                kicker('Room noise floor'),
                const SizedBox(height: 10),
                Text('Not measured in this build.',
                    key: const Key('setup-room-gap-title'),
                    style: hankenText(size: 19, weight: FontWeight.w500)),
                const SizedBox(height: 8),
                // DÜZELTME (koordinatör, 2026-08-07, M-F-186): "yet"
                // çıkarıldı. Gerekçenin varlığı "yet"i affetmiyor —
                // `lesson_demo_screen.dart`ın düzeltilen hâliyle aynı sınıf.
                Text(
                  'The design calls for four seconds of quiet to measure '
                  'the room before you play. That capture is not wired '
                  'in these posture lessons, so we are '
                  'not showing a fake progress bar for it. Camera setup is '
                  'real; this step is a named gap.',
                  key: const Key('setup-room-gap-body'),
                  style: hankenText(size: 13.5, height: 1.55, color: OstinatoPalette.of(context).textBody),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          PrimaryButton(label: 'Continue', onPressed: onContinue),
        ],
      );
}

class _PassedStage extends StatelessWidget {
  const _PassedStage(
      {required this.discipline, required this.lesson, required this.hue,
      this.source});
  final Discipline discipline;
  final Lesson lesson;
  final InstrumentHue hue;
  final PoseSource? source;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: OstinatoPalette.of(context).instrument(discipline.id).gradient,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                kicker('Ready', color: OstinatoPalette.of(context).instrument(discipline.id).ink),
                const SizedBox(height: 8),
                Text('Camera calibrated.',
                    key: const Key('setup-stage-passed'),
                    style: hankenText(size: 19.5, weight: FontWeight.w500)),
                const SizedBox(height: 8),
                // DÜZELTME (koordinatör, 2026-08-07, M-F-186): "yet"
                // çıkarıldı — gerekçe zaten `_RoomGapNotice`de var, burası
                // yalnız kısa bir sonuç notu.
                Text(
                  'Your frame and the light. Room noise is not part of '
                  'this check, so nothing about your sound was '
                  'measured or saved.',
                  // O-052: ham `TextStyle` yerine tipografi yardımcısı.
                  style: hankenText(size: 13.5, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          PrimaryButton(
            label: 'Start the lesson',
            onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute<void>(
                    builder: (_) =>
                        LiveScreenRoute(discipline: discipline, lesson: lesson, hue: OstinatoPalette.of(context).instrument(discipline.id),
                            source: source))),
          ),
        ],
      );
}
