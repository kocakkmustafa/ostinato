import 'dart:async';

import 'package:flutter/material.dart';
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
      {super.key, required this.discipline, required this.lesson, required this.hue});
  final Discipline discipline;
  final Lesson lesson;
  final InstrumentHue hue;

  @override
  State<SetupCheckScreenRoute> createState() => _SetupCheckScreenRouteState();
}

enum _Stage { starting, framingError, lowLight, ok, room, passed }

class _SetupCheckScreenRouteState extends State<SetupCheckScreenRoute> {
  final MotionCameraController _camera = MotionCameraController();
  StreamSubscription<CameraFrameEnvelope>? _sub;
  final CameraPostureAdapter _adapter = CameraPostureAdapter();
  core.FrameSize? _size;

  _Stage _stage = _Stage.starting;
  SurfaceState? _failure;
  int _consecutiveOk = 0;

  static const int _dwellFrames = 8; // isimli UX debounce — ölçüm eşiği DEĞİL

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    final CameraStartResult result = await requestAndStartCamera(
      _camera,
      modelPath: await PoseModelPin.resolveFilePath(),
      modelId: PoseModelPin.modelId,
    );
    if (!mounted) return;
    switch (result) {
      case CameraStartFailed(:final SurfaceState state):
        setState(() => _failure = state);
      case CameraStarted(:final CameraSessionInfo info):
        _size = core.FrameSize(info.width, info.height);
        _sub = _camera.frames().listen(_onEnvelope);
    }
  }

  void _onEnvelope(CameraFrameEnvelope e) {
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
        _stopCamera();
        setState(() => _stage = _Stage.room);
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

  void _stopCamera() {
    unawaited(_sub?.cancel());
    _sub = null;
    // O-076: kapanış artık İZLENİYOR — sıradaki `start` onu bekler.
    releaseCamera(_camera);
  }

  @override
  void dispose() {
    _stopCamera();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OstinatoColors.surface,
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
                      semanticLabel: 'Cancel setup',
                      onTap: () => Navigator.of(context).pop()),
                  kicker('Setup check'),
                  const SizedBox(width: 38),
                ],
              ),
              const SizedBox(height: 18),
              _StepBar(stage: _stage, hue: widget.hue),
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
          kicker: 'FRAME',
          title: 'Find your frame.',
          // DÜZELTME-2 (O-099): "Nine points" burada bir OKUMA iddiasıydı
          // ("we do not read your head" ile aynı cümlede) ve ölçüme
          // uymuyordu — kamera DÖRT nokta okur (`LmRegion.torso`). BEŞİNCİ
          // yüzey: ilk sayım "upper-body" ifadesini aradığı için burayı
          // KAÇIRMIŞTI — deseni ifadeye bağlamanın, iddiaya bağlamamanın
          // aynı sınıf hatası (plist kapısının deliğiyle birebir aynı).
          body: 'You should be visible from your hips to your shoulders. '
              'Four points — your two shoulders and your two hips — and no '
              'face: we do not read your head, because our reference does '
              'not carry one.',
          child: _Skeleton(dim: false),
        ),
      _Stage.framingError => _CameraStage(
          key: const Key('setup-stage-framing-error'),
          kicker: 'FRAME',
          title: 'Your hips are outside the frame.',
          body: 'Both hip points are missing, so there is no trunk line to '
              'measure. Move the phone back about an arm’s length, or sit '
              'closer to it.',
          warn: true,
          child: _Skeleton(dim: true),
        ),
      _Stage.lowLight => _CameraStage(
          key: const Key('setup-stage-low-light'),
          kicker: 'LIGHT',
          title: 'Too dark to trust.',
          body: 'Landmark confidence is below what we measure against. '
              'Turn on a light or face a window — we would rather refuse '
              'than guess.',
          warn: true,
          child: _Skeleton(dim: true),
        ),
      _Stage.ok => _CameraStage(
          key: const Key('setup-stage-ok'),
          kicker: 'FRAME',
          title: 'Holding steady…',
          body: 'Frame and light look right. Hold still for a moment.',
          child: _Skeleton(dim: false),
        ),
      _Stage.room => _RoomGapNotice(
          onContinue: () => setState(() => _stage = _Stage.passed)),
      _Stage.passed => _PassedStage(
          discipline: widget.discipline, lesson: widget.lesson, hue: widget.hue),
    };
  }

  String _describeFailure(SurfaceState s) => switch (s) {
        PermissionDeniedRetriable() =>
          'Ostinato needs the camera to see how you sit. Tap the button '
              'below to allow it.',
        PermissionDeniedPermanent() =>
          'Camera access is off and the system will not ask again. Open '
              'Settings to change it.',
        SetupFailed(:final String reason) =>
          'The camera did not start ($reason). The setup check cannot run '
              'without it.',
        _ => 'The camera is not available right now.',
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
          for (final (int i, String label) in const <String>['FRAME', 'ROOM', 'READY']
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
                          ? OstinatoColors.ink
                          : (i == _step
                              ? hue.ink
                              : const Color(0x212A2533)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(label,
                      style: monoText(
                          size: 9,
                          color: i <= _step
                              ? OstinatoColors.inkSoft
                              : const Color(0xFFB5AFC0))),
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
                  ? const Color(0xFFFFECE2)
                  : Colors.white.withValues(alpha: .85),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(kicker!,
                    style: monoText(
                        color: warn ? OstinatoColors.warnInk : OstinatoColors.textMono)),
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

// PLACEHOLDER(flow): oda gürültü-tabanı yakalama adımı KAPALI — tasarım
// 3-5sn sessizlik ölçen bir kalibrasyon gösterir, bu ekran onun yerine
// dürüst bir "henüz yok" kartı gösterir (aşağıda). unblocked by: gerçek
// bir mikrofon-giriş eklentisi `ostinato_audio`nun var olan
// `AudioConfidenceGate`ine bağlanıp bu ekranın state machine'ine
// (_Stage.room) gerçek bir örnekleme/geri-sayım aşaması eklenince.
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
                  '— there is no microphone input in this build, so we are '
                  'not showing a fake progress bar for it. Camera setup is '
                  'real; this step is a named gap.',
                  key: const Key('setup-room-gap-body'),
                  style: hankenText(size: 13.5, height: 1.55, color: OstinatoColors.textBody),
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
      {required this.discipline, required this.lesson, required this.hue});
  final Discipline discipline;
  final Lesson lesson;
  final InstrumentHue hue;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: hue.gradient,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                kicker('Ready', color: hue.ink),
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
                        LiveScreenRoute(discipline: discipline, lesson: lesson, hue: hue))),
          ),
        ],
      );
}
