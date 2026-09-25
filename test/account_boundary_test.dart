import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/account_data_directory.dart';
import 'package:ostinato/app/session_store.dart';

void main() {
  const first = '11111111-1111-4111-8111-111111111111';
  const second = '22222222-2222-4222-8222-222222222222';

  test('guest and two accounts keep distinct real session journals', () async {
    final root = await Directory.systemTemp.createTemp('ostinato_accounts');
    addTearDown(() async => root.delete(recursive: true));
    final guest = SessionStore(directoryProvider: () async => root);
    final one = SessionStore(
      directoryProvider: () async => root,
      accountUserId: first,
    );
    final two = SessionStore(
      directoryProvider: () async => root,
      accountUserId: second,
    );
    PersistedSession session(String lesson) => PersistedSession(
      schemaVersion: PersistedSession.currentSchemaVersion,
      disciplineId: 'guitar',
      lessonId: lesson,
      completedAt: DateTime.utc(2026, 9, 24),
      elapsedSeconds: 30,
      sampleCount: 3,
      outCount: 0,
    );

    await guest.save(session('guest'));
    await one.save(session('first'));
    await two.save(session('second'));

    expect((await guest.lastSession())?.lessonId, 'guest');
    expect((await one.lastSession())?.lessonId, 'first');
    expect((await two.lastSession())?.lessonId, 'second');
    expect(await File('${root.path}/sessions.jsonl').exists(), isTrue);
    expect(
      await File('${root.path}/accounts/$first/sessions.jsonl').exists(),
      isTrue,
    );
    expect(
      await File('${root.path}/accounts/$second/sessions.jsonl').exists(),
      isTrue,
    );

    await deleteAccountData(root, first);
    await deleteAccountData(root, first); // repeated deletion is harmless
    expect(
      await File('${root.path}/accounts/$first/sessions.jsonl').exists(),
      isFalse,
    );
    expect((await guest.lastSession())?.lessonId, 'guest');
    expect((await two.lastSession())?.lessonId, 'second');
  });

  test('user ID cannot escape local account directory', () async {
    expect(
      () => accountDataDirectory(Directory.systemTemp, '../another-user'),
      throwsArgumentError,
    );
  });

  test(
    'deletion receipt scan sees only canonical account directories',
    () async {
      final root = await Directory.systemTemp.createTemp('ostinato_receipts');
      addTearDown(() async => root.delete(recursive: true));
      final accounts = await Directory('${root.path}/accounts').create();
      await Directory('${accounts.path}/$second').create();
      await Directory('${accounts.path}/$first').create();
      await Directory('${accounts.path}/other').create();
      await File(
        '${accounts.path}/33333333-3333-4333-8333-333333333333',
      ).create();
      await Link(
        '${accounts.path}/44444444-4444-4444-8444-444444444444',
      ).create(root.path);

      expect(await localAccountIds(root), [first, second]);
    },
  );
}
