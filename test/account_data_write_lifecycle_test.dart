import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/account_data_directory.dart';
import 'package:ostinato/app/account_data_operations.dart';
import 'package:ostinato/app/guitar_journey_progress.dart';
import 'package:ostinato/app/session_store.dart';

void main() {
  const first = '11111111-1111-4111-8111-111111111111';
  const second = '22222222-2222-4222-8222-222222222222';
  const version = 'release-week-regression';
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('ostinato-data-lifecycle-');
  });
  tearDown(() async => root.delete(recursive: true));

  GuitarJourneyProgressStore progress(String? id) => GuitarJourneyProgressStore(
    directoryProvider: () async => root,
    accountUserId: id,
  );

  Future<GuitarLessonProgress> practice(
    GuitarJourneyProgressStore store,
    String lesson,
  ) => store.record(
    lessonId: lesson,
    contentVersion: version,
    action: GuitarProgressAction.practiced,
  );

  PersistedSession session(String lesson) => PersistedSession(
    schemaVersion: PersistedSession.currentSchemaVersion,
    disciplineId: 'guitar',
    lessonId: lesson,
    completedAt: DateTime.utc(2026, 10, 1),
    elapsedSeconds: 30,
    sampleCount: 3,
    outCount: 0,
  );

  test('overlapping stores preserve every lesson and practice entry', () async {
    final one = progress(first);
    final two = progress(first);
    await practice(one, 'completed');
    await one.record(
      lessonId: 'completed',
      contentVersion: version,
      action: GuitarProgressAction.selfReportedCompleted,
    );
    final completion =
        (await one.load())['$version|completed']!.selfReportedCompletedAt;

    await Future.wait([
      for (var i = 0; i < 8; i++) practice(i.isEven ? one : two, 'lesson-$i'),
      practice(one, 'repeated'),
      practice(two, 'repeated'),
    ]);

    final reopened = await progress(first).load();
    expect(reopened.length, 10);
    for (var i = 0; i < 8; i++) {
      expect(reopened['$version|lesson-$i']?.practiceCount, 1);
    }
    expect(reopened['$version|repeated']?.practiceCount, 2);
    expect(reopened['$version|completed']?.selfReportedCompletedAt, completion);
  });

  test('course reload waits for its already-started progress save', () async {
    final directory = Completer<Directory>();
    var calls = 0;
    final store = GuitarJourneyProgressStore(
      accountUserId: first,
      directoryProvider: () =>
          ++calls == 1 ? directory.future : Future.value(root),
    );
    final saved = practice(store, 'pending');
    final reloaded = store.load();
    directory.complete(root);
    await saved;
    expect((await reloaded)['$version|pending']?.practiceCount, 1);
  });

  test('late progress path cannot recreate a deleted account', () async {
    await practice(progress(first), 'old');
    final directory = Completer<Directory>();
    final store = GuitarJourneyProgressStore(
      directoryProvider: () => directory.future,
      accountUserId: first,
    );
    final pending = practice(store, 'late');
    final rejected = expectLater(pending, throwsStateError);
    await deleteAccountData(root, first);
    directory.complete(root);
    await rejected;
    expect(await accountDataDirectory(root, first).exists(), isFalse);
  });

  test('late session path cannot recreate a deleted account', () async {
    final directory = Completer<Directory>();
    final store = SessionStore(
      directoryProvider: () => directory.future,
      accountUserId: first,
    );
    final pending = store.save(session('late'));
    final rejected = expectLater(pending, throwsStateError);
    await deleteAccountData(root, first);
    directory.complete(root);
    await rejected;
    expect(await accountDataDirectory(root, first).exists(), isFalse);
  });

  test(
    'deletion fences new writers and preserves guest and other account',
    () async {
      await practice(progress(null), 'guest');
      await practice(progress(second), 'other');
      await deleteAccountData(root, first);
      await deleteAccountData(root, first);

      await expectLater(practice(progress(first), 'stale'), throwsStateError);
      await expectLater(
        SessionStore(
          directoryProvider: () async => root,
          accountUserId: first,
        ).save(session('stale')),
        throwsStateError,
      );
      expect((await progress(null).load())['$version|guest']?.practiceCount, 1);
      expect(
        (await progress(second).load())['$version|other']?.practiceCount,
        1,
      );
      expect(await accountDataDirectory(root, first).exists(), isFalse);
    },
  );

  test('one rejected record does not poison later writes', () async {
    final store = progress(first);
    await expectLater(
      store.record(
        lessonId: 'not-practiced',
        contentVersion: version,
        action: GuitarProgressAction.selfReportedCompleted,
      ),
      throwsStateError,
    );
    await practice(store, 'valid');
    expect((await store.load())['$version|valid']?.practiceCount, 1);
  });

  test('deletion joins a write already inside the account directory', () async {
    final entered = Completer<void>();
    final release = Completer<void>();
    final owned = accountDataDirectory(root, first);
    final operations = AccountDataOperations(() async => owned);
    final pending = operations.run((directory) async {
      await directory.create(recursive: true);
      entered.complete();
      await release.future;
      await File('${directory.path}/admitted.txt').writeAsString('finished');
    }, writing: true);
    await entered.future;
    var deleted = false;
    final cleanup = deleteAccountData(root, first).then((_) => deleted = true);
    await Future<void>.delayed(Duration.zero);
    expect(deleted, isFalse);
    release.complete();
    await pending;
    await cleanup;
    expect(await owned.exists(), isFalse);
    await expectLater(practice(progress(first), 'late'), throwsStateError);
  });

  test(
    'a filesystem failure leaves later operations and deletion usable',
    () async {
      final owned = accountDataDirectory(root, first);
      final operations = AccountDataOperations(() async => owned);
      await expectLater(
        operations.run(
          (directory) => File('${directory.path}/missing').readAsString(),
        ),
        throwsA(isA<FileSystemException>()),
      );
      await operations.run((directory) async {
        await directory.create(recursive: true);
        await File('${directory.path}/recovered').writeAsString('saved');
      }, writing: true);
      expect(await File('${owned.path}/recovered').readAsString(), 'saved');
      await deleteAccountData(root, first);
      expect(await owned.exists(), isFalse);
    },
  );
}
