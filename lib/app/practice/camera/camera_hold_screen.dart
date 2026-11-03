import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:ostinato_posture/ostinato_posture.dart';
import 'package:permission_handler/permission_handler.dart'
    show openAppSettings;

import '../../app_locale.dart';
import '../../app_theme.dart';
import '../../camera_pose_source.dart';
import '../../camera_session.dart';
import '../../design/ostinato_theme.dart';
import '../../design/widgets.dart';
import '../../tuner/tuner_copy.dart';
import '../../ui_copy.dart';
import 'camera_lesson_copy.dart';

/// The guitar posture contract (trunk tilt band and cue threshold).
Future<PostureContract> loadGuitarPostureContract() async =>
    PostureContract.fromJson(
      await rootBundle.loadString('assets/config/posture-contract.json'),
      'guitar',
    );

/// K8: hold a position for [holdSeconds] while the camera watches the
/// trunk tilt. The chain is the live screen's (PoseSource →
/// PostureEvaluator → SurfaceState): inside the teachers' range it stays
/// quiet; a sustained lean past the cue threshold gives one observation,
/// then the evaluator's cooldown. No score, nothing saved, no frame kept:
/// the lesson's checklist decides completion.
class CameraHoldScreen extends StatefulWidget {
  const CameraHoldScreen({
    super.key,
    required this.title,
    required this.holdSeconds,
    this.source,
    this.contract,
  });

  final String title;
  final int holdSeconds;

  /// Defaults to the device camera; permission is asked when it starts.
  final PoseSource? source;

  /// Defaults to [loadGuitarPostureContract].
  final Future<PostureContract>? contract;

  @override
  State<CameraHoldScreen> createState() => _CameraHoldScreenState();
}

class _CameraHoldScreenState extends State<CameraHoldScreen> {
  late final PoseSource _source = widget.source ?? CameraPoseSource();
  PostureEvaluator? _evaluator;
  StreamSubscription<SurfaceState>? _statusSub;
  StreamSubscription<PoseFrame>? _frameSub;
  Future<void>? _closeFuture;
  bool _retired = false;

  SurfaceState _state = const Starting();
  ObservationCue? _cue;
  late int _left = widget.holdSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    unawaited(_open());
  }

  Future<void> _open() async {
    final PostureContract contract;
    try {
      contract = await (widget.contract ?? loadGuitarPostureContract());
    } on Object {
      if (mounted) setState(() => _state = const SetupFailed('no-contract'));
      return;
    }
    if (!mounted || _retired) return;
    _evaluator = PostureEvaluator(contract: contract);
    _statusSub = _source.status.listen((s) {
      if (!mounted || _retired) return;
      final source = _source;
      if (source is CameraPoseSource && !source.canObserveStatus) return;
      setState(() {
        _state = s;
        _cue = null;
      });
    });
    _frameSub = _source.frames.listen((f) {
      if (!mounted || _retired || _left == 0) return;
      final source = _source;
      if (source is CameraPoseSource && !source.canObserveFrames) return;
      final s = _evaluator!.evaluate(f);
      setState(() {
        _state = s;
        _timer ??= Timer.periodic(const Duration(seconds: 1), _tick);
        if (s is Measuring && s.cue != null) {
          _cue = s.cue;
        } else if (s is! Measuring || s.inBand) {
          // Inside the range (or not visible) the hint goes quiet.
          _cue = null;
        }
      });
    });
    observeCameraWork(_source.start());
  }

  void _tick(Timer t) {
    if (!mounted) return;
    setState(() {
      _left = (_left - 1).clamp(0, widget.holdSeconds);
      if (_left == 0) _cue = null;
    });
    if (_left == 0) {
      t.cancel();
      observeCameraWork(_retire());
    }
  }

  Future<void> _retire() {
    if (_closeFuture != null) return _closeFuture!;
    _retired = true;
    // Stop first (it retires the camera lease), then drop the listeners.
    final stop = _source.stop();
    final status = _statusSub;
    final frames = _frameSub;
    _statusSub = null;
    _frameSub = null;
    return _closeFuture = Future.wait<void>([
      stop,
      if (status != null) status.cancel(),
      if (frames != null) frames.cancel(),
    ]).then<void>((_) {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    observeCameraWork(_retire());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = OstinatoPalette.of(context);
    final body = hankenText(size: 14, height: 1.45);
    return Scaffold(
      backgroundColor: palette.surface,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
          children: [
            Row(
              children: [
                GlassIconButton(
                  icon: '‹',
                  semanticLabel: localized(context, 'Back', 'Geri'),
                  onTap: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.title,
                    style: hankenText(size: 20, weight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              _left == 0
                  ? uiText(context, CameraLessonCopy.timeUp)
                  : uiText(
                      context,
                      CameraLessonCopy.timeLeft,
                      values: {'v0': _left},
                    ),
              key: const Key('camera-hold-time'),
              style: hankenText(size: 28, weight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            // A hint replaces the status line ("no hint so far").
            if (_left > 0 && _cue == null)
              GlassCard(
                key: const Key('camera-hold-status'),
                padding: const EdgeInsets.all(14),
                child: Text(_statusText(context), style: body),
              ),
            if (_cue case final cue? when _left > 0) ...[
              const SizedBox(height: 12),
              GlassCard(
                key: const Key('camera-hold-hint'),
                padding: const EdgeInsets.all(14),
                child: Text(
                  uiText(
                    context,
                    CameraLessonCopy.hintTrunk,
                    values: {
                      'v0': cue.teacherCount,
                      'v1': cue.thresholdDeg.toStringAsFixed(0),
                      'v2': cue.measuredDeg.toStringAsFixed(0),
                    },
                  ),
                  style: body,
                ),
              ),
            ],
            if (_state is PermissionDeniedPermanent) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                key: const Key('camera-hold-settings'),
                onPressed: () => unawaited(openAppSettings()),
                child: Text(uiText(context, TunerCopy.openSettings)),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('camera-hold-back'),
              onPressed: () => Navigator.of(context).pop(),
              child: Text(uiText(context, CameraLessonCopy.back)),
            ),
          ],
        ),
      ),
    );
  }

  String _statusText(BuildContext context) =>
      uiText(context, cameraHoldStatusCopy(_state));
}

/// Opens [CameraHoldScreen]; the lesson screen's entry point.
Future<void> openCameraHold(
  BuildContext context, {
  required String title,
  required int holdSeconds,
  PoseSource Function()? source,
}) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    builder: (_) => CameraHoldScreen(
      title: title,
      holdSeconds: holdSeconds,
      source: source?.call(),
    ),
  ),
);

/// The status line for a camera state.
UiCopy cameraHoldStatusCopy(SurfaceState state) => switch (state) {
  Starting() => CameraLessonCopy.starting,
  PermissionDenied() => CameraLessonCopy.denied,
  CameraUnavailable() || SetupFailed() => CameraLessonCopy.unavailable,
  NoPersonVisible() => CameraLessonCopy.notVisible,
  Measuring() => CameraLessonCopy.watching,
};
