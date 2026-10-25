import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Device-level result of Core's under-13 sign-up check
/// ([MotionAccountPage.onAgeBlocked]). Only the fact that sign-up was blocked
/// is kept: no birth month, year, country, email or account ID. Core receives
/// it back as `ageBlocked`, so entering another age on this device does not
/// reopen sign-up.
final class AgeGateStore {
  const AgeGateStore({this.directory});

  final Directory? directory;

  Future<File> _file() async {
    final root = directory ?? await getApplicationSupportDirectory();
    return File('${root.path}/ostinato.age_gate.v1.json');
  }

  /// A missing file is "not blocked". A present but unreadable or changed
  /// file stays blocked: an under-13 decision is never silently undone.
  Future<bool> read() async {
    final file = await _file();
    if (!await file.exists()) return false;
    try {
      final value = jsonDecode(await file.readAsString());
      return !(value is Map<String, dynamic> &&
          value['schemaVersion'] == 1 &&
          value['blocked'] == false);
    } on Object {
      return true;
    }
  }

  Future<void> markBlocked() async {
    final file = await _file();
    await file.parent.create(recursive: true);
    final pending = File('${file.path}.tmp');
    await pending.writeAsString(
      jsonEncode({'schemaVersion': 1, 'blocked': true}),
      flush: true,
    );
    await pending.rename(file.path);
  }
}
