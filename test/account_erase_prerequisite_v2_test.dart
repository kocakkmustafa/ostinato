import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/account_data_directory.dart';
import 'package:ostinato/app/account_data_operations.dart';

// Prepared for the separately applied and frozen filesystem successor.
// These unit probes are not part of the sealed old-host seven-case dispatch.
void main() {
  const first = '11111111-1111-4111-8111-111111111111';
  const second = '22222222-2222-4222-8222-222222222222';
  const step = Duration(seconds: 2);
  const limit = Timeout(Duration(seconds: 20));
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('ostinato-erase-prerequisite-');
  });
  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  Future<File> seed(String? id, String value) async {
    final directory = accountDataDirectory(root, id);
    await directory.create(recursive: true);
    final file = File('${directory.path}/sentinel.txt');
    await file.writeAsString(value);
    return file;
  }

  AccountDataOperations operations(String? id) => AccountDataOperations(
    () async => accountDataDirectory(root, id),
  );

  test('double-slash root alias joins admitted writer before erase', () async {
    final file = await seed(first, 'A');
    final entered = Completer<void>();
    final release = Completer<void>();
    final write = operations(first).run((directory) async {
      entered.complete();
      await release.future;
      await File('${directory.path}/admitted.txt').writeAsString('finished');
    }, writing: true);
    await entered.future;
    final cleanup = deleteAccountData(Directory('${root.path}/'), first);
    var erased = false;
    final observed = cleanup.then((_) => erased = true);
    try {
      await Future<void>.delayed(Duration.zero);
      expect(erased, isFalse);
      expect(await file.exists(), isTrue);
      release.complete();
      await write.timeout(step);
      await observed.timeout(step);
      expect(await file.exists(), isFalse);
    } finally {
      if (!release.isCompleted) release.complete();
      await write.timeout(step);
      await observed.timeout(step);
    }
  }, timeout: limit);

  test('pending and successful erase calls return one exact Future', () async {
    final file = await seed(first, 'A');
    final media = Completer<void>();
    final cleanup = deleteAccountData(root, first, beforeErase: media.future);
    var erased = false;
    final observed = cleanup.then<void>((_) => erased = true);
    try {
      final normalized = Directory(
        '${accountDataDirectory(root, first).path}/../$first',
      );
      expect(identical(AccountDataOperations.delete(normalized), cleanup), isTrue);
      expect(identical(deleteAccountData(root, first), cleanup), isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(erased, isFalse);
      expect(await file.readAsString(), 'A');
      media.complete();
      await observed.timeout(step);
      expect(await file.exists(), isFalse);
      expect(identical(deleteAccountData(root, first), cleanup), isTrue);
    } finally {
      if (!media.isCompleted) media.complete();
      await observed.timeout(step);
    }
  }, timeout: limit);

  test('held prerequisite rejects new A writes and preserves B and guest', () async {
    final a = await seed(first, 'A');
    final b = await seed(second, 'B');
    final guest = await seed(null, 'guest');
    final retained = operations(first);
    await retained.run((directory) => File('${directory.path}/sentinel.txt').readAsString());
    final media = Completer<void>();
    final cleanup = deleteAccountData(root, first, beforeErase: media.future);
    var aWriterEntered = false;
    Future<void> write(AccountDataOperations owner, String value) => owner.run(
      (directory) async {
        if (directory.path == accountDataDirectory(root, first).path) {
          aWriterEntered = true;
        }
        await File('${directory.path}/sentinel.txt').writeAsString(value);
      },
      writing: true,
    );
    try {
      await expectLater(write(retained, 'stale').timeout(step), throwsStateError);
      await expectLater(write(operations(first), 'fresh').timeout(step), throwsStateError);
      expect(aWriterEntered, isFalse);
      expect(await a.readAsString(), 'A');
      await write(operations(second), 'B updated').timeout(step);
      await write(operations(null), 'guest updated').timeout(step);
      expect(await b.readAsString(), 'B updated');
      expect(await guest.readAsString(), 'guest updated');
    } finally {
      media.complete();
      await cleanup.timeout(step);
    }
    expect(await a.exists(), isFalse);
    expect(await b.exists(), isTrue);
    expect(await guest.exists(), isTrue);
  }, timeout: limit);

  test('erase joins admitted A IO even after the media prerequisite settles', () async {
    final file = await seed(first, 'A');
    final entered = Completer<void>();
    final writerRelease = Completer<void>();
    final media = Completer<void>();
    final writer = operations(first).run((directory) async {
      entered.complete();
      await writerRelease.future;
      await File('${directory.path}/admitted.txt').writeAsString('finished');
    }, writing: true);
    await entered.future.timeout(step);
    final cleanup = deleteAccountData(root, first, beforeErase: media.future);
    var erased = false;
    final observed = cleanup.then<void>((_) => erased = true);
    try {
      media.complete();
      await Future<void>.delayed(Duration.zero);
      expect(erased, isFalse);
      expect(await file.exists(), isTrue);
      writerRelease.complete();
      await writer.timeout(step);
      await observed.timeout(step);
      expect(await accountDataDirectory(root, first).exists(), isFalse);
    } finally {
      if (!media.isCompleted) media.complete();
      if (!writerRelease.isCompleted) writerRelease.complete();
      await writer.timeout(step);
      await observed.timeout(step);
    }
  }, timeout: limit);

  test('held writer observes failed prerequisite without losing error or queue', () async {
    final file = await seed(first, 'A');
    final entered = Completer<void>();
    final writerRelease = Completer<void>();
    final refused = StateError('injected media prerequisite refusal');
    final originalStack = StackTrace.fromString('held-media-original-stack');
    final unhandled = <Object>[];
    final done = Completer<void>();

    runZonedGuarded(() {
      unawaited(() async {
        // A Future carrying errors and its handlers share this error zone.
        final media = Completer<void>();
        final writer = operations(first).run((_) async {
          entered.complete();
          await writerRelease.future;
        }, writing: true);
        Future<void>? observed;
        try {
          await entered.future.timeout(step);
          final cleanup = deleteAccountData(root, first, beforeErase: media.future);
          Object? caught;
          StackTrace? caughtStack;
          var settled = false;
          observed = cleanup.then<void>(
            (_) => fail('A refused prerequisite cannot erase successfully'),
            onError: (Object error, StackTrace stack) {
              caught = error;
              caughtStack = stack;
              settled = true;
            },
          );
          media.completeError(refused, originalStack);
          await Future<void>.delayed(Duration.zero);
          await Future<void>.delayed(Duration.zero);
          expect(unhandled, isEmpty);
          expect(settled, isFalse);
          expect(identical(deleteAccountData(root, first), cleanup), isTrue);
          expect(await file.readAsString(), 'A');
          writerRelease.complete();
          await writer.timeout(step);
          await observed.timeout(step);
          expect(identical(caught, refused), isTrue);
          expect(caughtStack.toString(), originalStack.toString());
          expect(await file.readAsString(), 'A');
          await expectLater(
            operations(first).run((_) async {}, writing: true).timeout(step),
            throwsStateError,
          );

          // Explicit later local retry with a successful prerequisite. This
          // checks queue semantics; it does not retry or prove native closure.
          final retry = deleteAccountData(
            root,
            first,
            beforeErase: Future<void>.value(),
          );
          expect(identical(retry, cleanup), isFalse);
          await retry.timeout(step);
          expect(await file.exists(), isFalse);
          await expectLater(cleanup, throwsA(same(refused)));
          expect(unhandled, isEmpty);
        } finally {
          if (!media.isCompleted) media.complete();
          if (!writerRelease.isCompleted) writerRelease.complete();
          await writer.timeout(step);
          if (observed != null) await observed.timeout(step);
        }
      }().then<void>(
        (_) => done.complete(),
        onError: (Object error, StackTrace stack) => done.completeError(error, stack),
      ));
    }, (Object error, StackTrace _) => unhandled.add(error));

    await done.future.timeout(const Duration(seconds: 10));
    expect(unhandled, isEmpty);
  }, timeout: limit);
}
