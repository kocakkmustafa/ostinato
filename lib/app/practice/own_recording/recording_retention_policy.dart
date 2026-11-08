import 'dart:async';

import 'package:flutter/widgets.dart';

import 'own_recording.dart';

/// OST-P0-08 — recording retention policy. Pure Dart, no I/O.
///
/// Raw audio never leaves the device and is never stored persistently:
/// the only outcomes are a short-lived buffer ([RetentionDecision.ephemeral])
/// or nothing at all ([RetentionDecision.denied]). Encrypted on-device storage
/// and export are NOT built (no cryptography dependency, no key store); they
/// are the separate ticket OST-P0-08B, so every request for persistence is
/// denied, with or without consent, for any audience.

/// Who is playing. Nothing in the app establishes an age yet, so callers pass
/// [unknown] unless a verified adult signal exists.
enum RetentionAudience { adult, child, unknown }

enum RecordingPurpose {
  /// FK2 "listen to my own recording": one run, this session only.
  ownPlayback,

  /// Keeping a recording after the session. Not available.
  persistentArchive,
}

enum RetentionDecision { ephemeral, denied }

abstract final class RecordingRetentionPolicy {
  static RetentionDecision decide({
    required RecordingPurpose purpose,
    required RetentionAudience audience,
    bool explicitStorageConsent = false,
  }) {
    switch (purpose) {
      case RecordingPurpose.persistentArchive:
        // Consent does not open it: encrypted storage does not exist yet.
        return RetentionDecision.denied;
      case RecordingPurpose.ownPlayback:
        return audience == RetentionAudience.adult
            ? RetentionDecision.ephemeral
            : RetentionDecision.denied;
    }
  }

  /// Whether the own-take recorder may run. With [retentionOpen] false the
  /// legacy FK2 behaviour is untouched (the user's setting alone decides).
  static bool mayRecordOwnTake({
    required bool retentionOpen,
    required RetentionAudience audience,
  }) {
    if (!retentionOpen) return true;
    return decide(purpose: RecordingPurpose.ownPlayback, audience: audience) ==
        RetentionDecision.ephemeral;
  }
}

/// Discards the own take (RAM buffer and temp file) when the app leaves the
/// foreground. Attach from a State's initState, detach in dispose.
final class RecorderBackgroundGuard with WidgetsBindingObserver {
  RecorderBackgroundGuard(this.recorder);
  final OwnRecorder recorder;

  void attach() => WidgetsBinding.instance.addObserver(this);
  void detach() => WidgetsBinding.instance.removeObserver(this);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // `inactive` is a permission dialog or the notification shade: the run
    // is still in the foreground, so it must not be deleted.
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        unawaited(recorder.discard());
      case AppLifecycleState.resumed:
      case AppLifecycleState.inactive:
        break;
    }
  }
}
