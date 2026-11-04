import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ostinato_posture/ostinato_posture.dart';
import 'package:permission_handler/permission_handler.dart'
    show openAppSettings;

import '../../app_locale.dart';
import '../../app_theme.dart';
import '../../camera_session.dart';
import '../../design/ostinato_theme.dart';
import '../../design/widgets.dart';
import '../../tuner/tuner_copy.dart';
import '../../ui_copy.dart';
import 'camera_hold_screen.dart' show cameraHoldStatusCopy;
import 'camera_lesson_copy.dart';
import 'mirror_camera.dart';

/// K8 hand lesson: hold the hand position for [holdSeconds] in front of a
/// mirror (the front camera's live preview). The mirror gives no hint and no
/// score and reads no frame; the lesson's checklist decides completion.
///
/// The camera is released when the hold ends, when the screen closes and
/// when the app leaves the foreground; it reopens on return while time is
/// left. The countdown runs only while the mirror is live.
class MirrorHoldScreen extends StatefulWidget {
  const MirrorHoldScreen({
    super.key,
    required this.title,
    required this.holdSeconds,
    this.camera,
  });

  final String title;
  final int holdSeconds;

  /// Makes one camera per opening; defaults to [DeviceMirrorCamera].
  final MirrorCamera Function()? camera;

  @override
  State<MirrorHoldScreen> createState() => _MirrorHoldScreenState();
}

class _MirrorHoldScreenState extends State<MirrorHoldScreen>
    with WidgetsBindingObserver {
  MirrorCamera? _camera;
  SurfaceState _state = const Starting();
  bool _live = false;
  late int _left = widget.holdSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _open();
  }

  void _open() {
    final camera = _camera = (widget.camera ?? DeviceMirrorCamera.new)();
    _state = const Starting();
    unawaited(
      camera.open().then((failure) {
        if (!mounted || !identical(_camera, camera)) {
          observeCameraWork(camera.close());
          return;
        }
        setState(() {
          if (failure == null) {
            _live = true;
            _timer ??= Timer.periodic(const Duration(seconds: 1), _tick);
          } else {
            _state = failure;
            _release();
          }
        });
      }),
    );
  }

  void _release() {
    final camera = _camera;
    _camera = null;
    _live = false;
    if (camera != null) observeCameraWork(camera.close());
  }

  void _tick(Timer t) {
    if (!mounted || !_live) return;
    setState(() => _left = (_left - 1).clamp(0, widget.holdSeconds));
    if (_left == 0) {
      t.cancel();
      setState(_release);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      // Not `inactive`: the permission dialog makes the app inactive.
      case AppLifecycleState.paused ||
          AppLifecycleState.hidden ||
          AppLifecycleState.detached:
        if (_camera != null) setState(_release);
      case AppLifecycleState.resumed:
        // Back from Settings, a denied or busy camera is tried again; a
        // first refusal is not asked again on every return.
        if (_camera == null &&
            _left > 0 &&
            _state is! PermissionDeniedRetriable) {
          setState(_open);
        }
      case AppLifecycleState.inactive:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = OstinatoPalette.of(context);
    final body = hankenText(size: 14, height: 1.45);
    final camera = _camera;
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
              key: const Key('mirror-hold-time'),
              style: hankenText(size: 28, weight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            if (_live && camera != null) ...[
              ClipRRect(
                key: const Key('mirror-preview'),
                borderRadius: BorderRadius.circular(16),
                child: camera.preview(),
              ),
              const SizedBox(height: 12),
              Text(uiText(context, CameraLessonCopy.mirrorLive), style: body),
            ] else if (_left > 0)
              GlassCard(
                key: const Key('mirror-hold-status'),
                padding: const EdgeInsets.all(14),
                child: Text(
                  uiText(context, cameraHoldStatusCopy(_state)),
                  style: body,
                ),
              ),
            if (_state is PermissionDeniedPermanent) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                key: const Key('mirror-hold-settings'),
                onPressed: () => unawaited(openAppSettings()),
                child: Text(uiText(context, TunerCopy.openSettings)),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('mirror-hold-back'),
              onPressed: () => Navigator.of(context).pop(),
              child: Text(uiText(context, CameraLessonCopy.back)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Opens [MirrorHoldScreen]; the hand lesson's entry point.
Future<void> openMirrorHold(
  BuildContext context, {
  required String title,
  required int holdSeconds,
  MirrorCamera Function()? camera,
}) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    builder: (_) => MirrorHoldScreen(
      title: title,
      holdSeconds: holdSeconds,
      camera: camera,
    ),
  ),
);
