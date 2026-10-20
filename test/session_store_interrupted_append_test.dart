import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/session_store.dart';

// Product SessionStore and AccountDataOperations run against a synthetic local
// directory. No mock implements persistence. Run only under coordinator lease.
void main() {
  late Directory root;
  setUp(() { root = Directory.systemTemp.createTempSync('ostinato_torn_journal_'); });
  tearDown(() { root.deleteSync(recursive: true); });

  PersistedSession session(String lessonId) => PersistedSession(
    schemaVersion: PersistedSession.currentSchemaVersion,
    disciplineId: 'guitar',
    lessonId: lessonId,
    completedAt: DateTime.utc(2026, 10, 20, 12),
    elapsedSeconds: 120,
    sampleCount: 40,
    outCount: 3,
  );
  SessionStore reopen() => SessionStore(directoryProvider: () async => root);

  test('successful save after interrupted ASCII append survives reopen', () async {
    final journal = File('${root.path}/sessions.jsonl');
    final committed = jsonEncode(session('committed-before-interruption').toJson());
    final damaged = '$committed\n{"v":1,"lessonId":"interrupted';
    await journal.writeAsString(damaged, flush: true);
    expect((await reopen().lastSession())?.lessonId, 'committed-before-interruption');

    await reopen().save(session('committed-after-interruption'));

    // The damaged bytes remain as evidence; recovery must not truncate them.
    expect(await journal.readAsString(), startsWith(damaged));
    expect((await reopen().lastSession())?.lessonId, 'committed-after-interruption');
  });

  test('successful save after newline-less restored valid record survives reopen', () async {
    final journal = File('${root.path}/sessions.jsonl');
    final restored = jsonEncode(session('restored-without-final-newline').toJson());
    await journal.writeAsString(restored, flush: true);
    expect((await reopen().lastSession())?.lessonId, 'restored-without-final-newline');

    await reopen().save(session('committed-after-restore'));

    expect(await journal.readAsString(), startsWith(restored));
    expect((await reopen().lastSession())?.lessonId, 'committed-after-restore');
  });

  test('ordinary empty and newline-terminated journals still round-trip', () async {
    await reopen().save(session('first'));
    expect((await reopen().lastSession())?.lessonId, 'first');
    await reopen().save(session('second'));
    expect((await reopen().lastSession())?.lessonId, 'second');
    final lines = await File('${root.path}/sessions.jsonl').readAsLines();
    expect(lines.length, 2);
    expect(lines.where((line) => line.trim().isNotEmpty).length, 2);
  });
}
