import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:permission_handler/permission_handler.dart';

import 'practice_audio_root.dart';

/// Asks for the microphone before a tap's capture action is minted.
///
/// A [PracticeAudioCaptureAction] is valid for one visibility epoch, and the
/// system permission prompt always ends that epoch (the app resigns active
/// while or after the prompt is dismissed). Minting before the prompt made the
/// first start after "Allow" fail, so the learner had to tap again.
///
/// Here the prompt comes first and mints nothing. After a grant, the action is
/// minted only once the app is foreground and its lifecycle has been quiet for
/// [quiet]; minting still goes through the owner's own checks (same top route,
/// identity and foreground). If the app reached the background while the
/// prompt was up, or the widget is gone, nothing starts: the learner taps
/// again. Denials take the old path so the controller reports them.
abstract final class MicPermissionGate {
  static Future<PermissionStatus> Function() status = _status;
  static Future<PermissionStatus> Function() request = _request;
  static Duration quiet = const Duration(milliseconds: 800);
  static Duration timeout = const Duration(seconds: 4);

  /// Set once a grant is seen. iOS and Android end the process when the
  /// microphone permission is revoked, so it cannot go stale; while set, a
  /// tap mints and starts synchronously, exactly as before this gate.
  static bool knownGranted = false;

  static bool _pending = false;

  static Future<PermissionStatus> _status() => Permission.microphone.status;
  static Future<PermissionStatus> _request() => Permission.microphone.request();

  @visibleForTesting
  static void resetForTest() {
    status = _status;
    request = _request;
    quiet = const Duration(milliseconds: 800);
    timeout = const Duration(seconds: 4);
    knownGranted = false;
    _pending = false;
  }

  /// Runs [start] with a capture action for [context]; see the class comment.
  /// [mint] defaults to [PracticeAudioCaptureScope.actionFor]. With [skip]
  /// (the debug fake microphone) no permission is asked.
  static Future<void> startAfterPermission(
    BuildContext context,
    Future<void> Function(PracticeAudioCaptureAction? action) start, {
    PracticeAudioCaptureAction? Function(BuildContext context)? mint,
    bool skip = false,
  }) {
    final mintFor = mint ?? PracticeAudioCaptureScope.actionFor;
    return run(
      mounted: () => context.mounted,
      mint: () => mintFor(context),
      start: start,
      skip: skip,
    );
  }

  /// [startAfterPermission] without a [BuildContext].
  @visibleForTesting
  static Future<void> run({
    required bool Function() mounted,
    required PracticeAudioCaptureAction? Function() mint,
    required Future<void> Function(PracticeAudioCaptureAction? action) start,
    bool skip = false,
  }) async {
    if (_pending) return;
    if (knownGranted || skip) {
      await start(mint());
      return;
    }
    PermissionStatus before;
    try {
      before = await status();
    } on Object {
      // No plugin (unsupported platform): the old ordering.
      before = PermissionStatus.granted;
    }
    if (before.isGranted) knownGranted = true;
    if (!mounted()) return;
    if (before.isGranted || before.isPermanentlyDenied || before.isRestricted) {
      await start(mint());
      return;
    }
    _pending = true;
    final watch = _LifecycleWatch()..attach();
    try {
      final after = await request();
      if (!mounted()) return;
      if (!after.isGranted) {
        // The controller asks again (no prompt now) and shows the denial.
        await start(mint());
        return;
      }
      knownGranted = true;
      if (!await watch.settled(quiet: quiet, timeout: timeout)) return;
      if (!mounted()) return;
      await start(mint());
    } finally {
      watch.detach();
      _pending = false;
    }
  }
}

enum _Wake { changed, quiet, timeout }

final class _LifecycleWatch with WidgetsBindingObserver {
  bool _attached = false;
  bool _leftForeground = false;
  Completer<_Wake>? _wake;

  void attach() {
    if (_attached) return;
    WidgetsBinding.instance.addObserver(this);
    _attached = true;
  }

  void detach() {
    if (!_attached) return;
    WidgetsBinding.instance.removeObserver(this);
    _attached = false;
  }

  void _fire(_Wake why) {
    final wake = _wake;
    if (wake != null && !wake.isCompleted) wake.complete(why);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _leftForeground = true;
    }
    _fire(_Wake.changed);
  }

  /// True once the app is resumed and no lifecycle change has arrived for
  /// [quiet]; false if it reached the background since [attach] or [timeout]
  /// passed first.
  Future<bool> settled({
    required Duration quiet,
    required Duration timeout,
  }) async {
    var timedOut = false;
    final deadline = Timer(timeout, () {
      timedOut = true;
      _fire(_Wake.timeout);
    });
    try {
      while (!_leftForeground && !timedOut) {
        final state = WidgetsBinding.instance.lifecycleState;
        final resumed = state == null || state == AppLifecycleState.resumed;
        final wake = _wake = Completer<_Wake>();
        final quietTimer = resumed
            ? Timer(quiet, () => _fire(_Wake.quiet))
            : null;
        final why = await wake.future;
        quietTimer?.cancel();
        if (why == _Wake.quiet) return !_leftForeground;
      }
      return false;
    } finally {
      deadline.cancel();
      _wake = null;
    }
  }
}
