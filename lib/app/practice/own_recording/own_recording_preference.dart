import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// FK2 setting: off unless the learner turns it on. Only the switch is
/// stored (`ostinato.own_recording.v1.json`); no audio, no account data.
abstract interface class OwnRecordingPreference {
  Future<bool> read();
  Future<void> write(bool enabled);
}

final class FileOwnRecordingPreference implements OwnRecordingPreference {
  const FileOwnRecordingPreference({this.directory});
  final Directory? directory;

  Future<File> _file() async {
    final root = directory ?? await getApplicationSupportDirectory();
    return File('${root.path}/ostinato.own_recording.v1.json');
  }

  /// Missing or unreadable reads as off: the default must never flip to on.
  @override
  Future<bool> read() async {
    try {
      final file = await _file();
      if (!await file.exists()) return false;
      final json = jsonDecode(await file.readAsString());
      return json is Map<String, dynamic> &&
          json['schemaVersion'] == 1 &&
          json['enabled'] == true;
    } on Object {
      return false;
    }
  }

  @override
  Future<void> write(bool enabled) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    final pending = File('${file.path}.tmp');
    await pending.writeAsString(
      jsonEncode({'schemaVersion': 1, 'enabled': enabled}),
      flush: true,
    );
    await pending.rename(file.path);
  }
}
