import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/screens/review_screen.dart' show SessionSummary;
import 'package:ostinato/app/session_store.dart';

// K03/K07 remaining branches. Product SessionStore, AccountDataOperations and
// the LiveScreen read-then-save sequence run against a synthetic local
// directory with real File IO. Nothing here mocks persistence.
void main() {
  late Directory root;
  setUp(() {
    root = Directory.systemTemp.createTempSync('ostinato_k03_branches_');
  });
  tearDown(() {
    root.deleteSync(recursive: true);
  });

  PersistedSession session(String lessonId) => PersistedSession(
    schemaVersion: PersistedSession.currentSchemaVersion,
    disciplineId: 'guitar',
    lessonId: lessonId,
    completedAt: DateTime.utc(2026, 10, 21, 12),
    elapsedSeconds: 120,
    sampleCount: 40,
    outCount: 3,
  );
  SessionStore reopen() => SessionStore(directoryProvider: () async => root);
  File journal() => File('${root.path}/sessions.jsonl');
  List<int> line(PersistedSession s) =>
      utf8.encode('${jsonEncode(s.toJson())}\n');

  // "ü" is 0xC3 0xBC. A write torn after its first byte leaves invalid UTF-8.
  final List<int> tornMultibyteTail = <int>[
    ...utf8.encode('{"v":1,"disciplineId":"guitar","lessonId":"g'),
    0xc3,
  ];

  test('half multibyte UTF-8 tail: last readable record survives', () async {
    final damaged = <int>[
      ...line(session('committed-çalış')),
      ...tornMultibyteTail,
    ];
    await journal().writeAsBytes(damaged, flush: true);

    expect((await reopen().lastSession())?.lessonId, 'committed-çalış');
  });

  test(
    'half multibyte UTF-8 tail: next save lands and damaged bytes are kept',
    () async {
      final damaged = <int>[
        ...line(session('committed-before')),
        ...tornMultibyteTail,
      ];
      await journal().writeAsBytes(damaged, flush: true);

      await reopen().save(session('committed-after'));

      final bytes = await journal().readAsBytes();
      expect(bytes.sublist(0, damaged.length), damaged);
      expect(bytes[damaged.length], 0x0a);
      expect((await reopen().lastSession())?.lessonId, 'committed-after');
    },
  );

  test('invalid UTF-8 in a middle line does not hide later records', () async {
    final damaged = <int>[
      ...line(session('oldest')),
      0xff,
      0xfe,
      0x0a,
      ...line(session('newest')),
    ];
    await journal().writeAsBytes(damaged, flush: true);

    expect((await reopen().lastSession())?.lessonId, 'newest');
    expect(await journal().readAsBytes(), damaged);
  });

  test(
    'journal made only of invalid bytes reads as empty, then accepts a save',
    () async {
      final damaged = <int>[0xc3, 0x0a, 0xe2, 0x82];
      await journal().writeAsBytes(damaged, flush: true);

      expect(await reopen().lastSession(), isNull);
      await reopen().save(session('first-readable'));

      final bytes = await journal().readAsBytes();
      expect(bytes.sublist(0, damaged.length), damaged);
      expect((await reopen().lastSession())?.lessonId, 'first-readable');
    },
  );

  test('existing zero-byte journal: save adds no leading separator', () async {
    await journal().writeAsBytes(const <int>[], flush: true);
    expect(await journal().length(), 0);
    expect(await reopen().lastSession(), isNull);

    await reopen().save(session('first'));

    final text = await journal().readAsString();
    expect(text, '${jsonEncode(session('first').toJson())}\n');
    expect((await reopen().lastSession())?.lessonId, 'first');
  });

  group('LiveScreen read-then-save sequence', () {
    SessionSummary summary() => const SessionSummary(
      elapsedSeconds: 90,
      sampleCount: 30,
      outCount: 2,
      history: <double>[],
    );
    PersistedSession current() => PersistedSession.fromSummary(
      disciplineId: 'guitar',
      lessonId: 'current',
      summary: summary(),
      completedAt: DateTime.utc(2026, 10, 21, 13),
    );

    test(
      'returns the previous record and then appends the current one',
      () async {
        await reopen().save(session('previous'));
        final store = _RecordingStore(read: reopen(), write: reopen());

        final previous = await readPreviousThenSave(store, current());
        await store.pendingWrite;

        expect(store.calls, <String>['read', 'write']);
        expect(previous?.lessonId, 'previous');
        expect((await reopen().lastSession())?.lessonId, 'current');
      },
    );

    test(
      'torn multibyte journal still yields history and keeps saving',
      () async {
        final damaged = <int>[
          ...line(session('previous')),
          ...tornMultibyteTail,
        ];
        await journal().writeAsBytes(damaged, flush: true);
        final store = _RecordingStore(read: reopen(), write: reopen());

        final previous = await readPreviousThenSave(store, current());
        await store.pendingWrite;

        expect(previous?.lessonId, 'previous');
        expect((await reopen().lastSession())?.lessonId, 'current');
        final bytes = await journal().readAsBytes();
        expect(bytes.sublist(0, damaged.length), damaged);
      },
    );

    test('a failing previous-read does not skip the current save', () async {
      // An unreadable journal (mode 000) makes the read fail with a real
      // FileSystemException; the save goes to a separate healthy store.
      final unreadable = Directory('${root.path}/unreadable')..createSync();
      final locked = File('${unreadable.path}/sessions.jsonl')
        ..writeAsBytesSync(line(session('locked')), flush: true);
      expect(
        Process.runSync('chmod', <String>['000', locked.path]).exitCode,
        0,
      );
      addTearDown(() => Process.runSync('chmod', <String>['600', locked.path]));
      final healthy = Directory('${root.path}/healthy')..createSync();
      final store = _RecordingStore(
        read: SessionStore(directoryProvider: () async => unreadable),
        write: SessionStore(directoryProvider: () async => healthy),
      );

      await expectLater(
        readPreviousThenSave(store, current()),
        throwsA(isA<FileSystemException>()),
      );
      await store.pendingWrite;

      expect(store.calls, <String>['read', 'write']);
      expect(
        (await SessionStore(
          directoryProvider: () async => healthy,
        ).lastSession())?.lessonId,
        'current',
      );
    });
  });
}

/// Delegates both halves of the sequence to real stores and keeps the
/// unawaited write so the test can observe it after the sequence returns.
final class _RecordingStore implements SessionStore {
  _RecordingStore({required this.read, required this.write});
  final SessionStore read;
  final SessionStore write;
  final List<String> calls = <String>[];
  Future<void>? pendingWrite;

  @override
  Future<PersistedSession?> lastSession() {
    calls.add('read');
    return read.lastSession();
  }

  @override
  Future<void> save(PersistedSession session) {
    calls.add('write');
    return pendingWrite = write.save(session);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
