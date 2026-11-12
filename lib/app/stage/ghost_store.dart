import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../account_data_directory.dart';
import '../account_data_operations.dart';
import 'ghost_policy.dart';

/// OST-UX-05g: the Ghost level and its counter, in their OWN local file
/// (`ghost-screen.v1.json`). Nothing is written to `V1PracticeRecord`, the
/// gate or the thresholds. A read problem means "learning level, no
/// suggestion".
abstract interface class GhostStore {
  Future<GhostState> load();
  Future<void> save(GhostState state);
}

final class FileGhostStore implements GhostStore {
  /// The file lives in the account's own data directory (same place as the
  /// practice progress), so the account data deletion removes it too.
  FileGhostStore({this.directoryProvider, this.accountUserId})
    : _operations = AccountDataOperations(() async {
        final root =
            await (directoryProvider ?? getApplicationSupportDirectory)();
        return accountDataDirectory(root, accountUserId);
      });

  static const String fileName = 'ghost-screen.v1.json';

  /// Signed-in account (null = the pre-account local path).
  final String? accountUserId;

  /// Null = the application support directory.
  final Future<Directory> Function()? directoryProvider;
  final AccountDataOperations _operations;

  @override
  Future<GhostState> load() async {
    try {
      return await _operations.run(_read);
    } on Object {
      return const GhostState();
    }
  }

  Future<GhostState> _read(Directory dir) async {
    try {
      final file = File('${dir.path}/$fileName');
      if (!await file.exists()) return const GhostState();
      final j = jsonDecode(await file.readAsString());
      if (j is! Map<String, dynamic> || j['schemaVersion'] != 1) {
        return const GhostState();
      }
      final level = GhostLevel.values.asNameMap()[j['level']];
      final last = GhostLastRun.values.asNameMap()[j['lastRun']];
      final runs = j['validRuns'];
      if (level == null || last == null || runs is! int || runs < 0) {
        return const GhostState();
      }
      return GhostState(level: level, validRuns: runs, lastRun: last);
    } on Object {
      return const GhostState();
    }
  }

  /// Atomic: temp file, flush, rename. A failed write only loses this save.
  @override
  Future<void> save(GhostState state) async {
    try {
      await _operations.run((dir) async {
        await dir.create(recursive: true);
        final file = File('${dir.path}/$fileName');
        final temp = File('${file.path}.tmp');
        final json = jsonEncode(<String, Object>{
          'schemaVersion': 1,
          'level': state.level.name,
          'validRuns': state.validRuns,
          'lastRun': state.lastRun.name,
        });
        await temp.writeAsString('$json\n', flush: true);
        await temp.rename(file.path);
      }, writing: true);
    } on Object {
      // The stage does not depend on it.
    }
  }
}

/// Tests and previews.
final class MemoryGhostStore implements GhostStore {
  MemoryGhostStore([this.state = const GhostState()]);
  GhostState state;

  @override
  Future<GhostState> load() async => state;

  @override
  Future<void> save(GhostState s) async => state = s;
}
