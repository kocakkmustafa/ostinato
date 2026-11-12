import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// OST-UX-05f: local memory of "the learner muted the Go to Settings link"
/// on the stage's "Listening is off" mode. One bit on this device; the
/// existence of a marker file is the answer (same pattern as
/// `FileOnboardingStore`: no new package, no schema that could go stale).
abstract interface class ListeningOffStore {
  Future<bool> settingsHintMuted();
  Future<void> muteSettingsHint();
}

final class FileListeningOffStore implements ListeningOffStore {
  FileListeningOffStore({this.directoryProvider});

  static const String fileName = 'stage-settings-hint.muted';

  /// Null = the application support directory.
  final Future<Directory> Function()? directoryProvider;

  Future<File> _marker() async {
    final dir = await (directoryProvider ?? getApplicationSupportDirectory)();
    return File('${dir.path}/$fileName');
  }

  /// A read failure counts as "not muted": the link stays reachable.
  @override
  Future<bool> settingsHintMuted() async {
    try {
      return await (await _marker()).exists();
    } on Object {
      return false;
    }
  }

  /// A write failure does not stop the stage; the link shows again next time.
  @override
  Future<void> muteSettingsHint() async {
    try {
      // An empty marker: its existence is the answer (nothing is written).
      await (await _marker()).create(recursive: true);
    } on Object {
      // Nothing else depends on it.
    }
  }
}

/// Tests and previews.
final class MemoryListeningOffStore implements ListeningOffStore {
  bool _muted = false;

  @override
  Future<bool> settingsHintMuted() async => _muted;

  @override
  Future<void> muteSettingsHint() async => _muted = true;
}
