import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/guitar_journey_progress.dart';
import 'package:ostinato/app/ostinato_release_policy.dart';
import 'package:ostinato/app/sync/lesson_progress_sync.dart';
import 'package:ostinato/app/sync/progress_sync_adapter.dart';
import 'package:ostinato/app/sync/progress_sync_engine.dart';

const _account = '11111111-1111-4111-8111-111111111111';
const _otherAccount = '22222222-2222-4222-8222-222222222222';
const _phone = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const _tablet = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const _laptop = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';

DateTime _t(int minute) => DateTime.utc(2026, 11, 1, 10, minute);

LessonProgressSyncRecord _rec({
  DateTime? seen,
  DateTime? practiced,
  DateTime? completed,
  Map<String, int> counts = const {},
}) => LessonProgressSyncRecord(
  contentVersion: 'v1',
  lessonId: 'g-01',
  seenAt: seen,
  practicedAt: practiced,
  completedAt: completed,
  practiceCounts: counts,
);

void main() {
  test('sync stays closed in this release', () {
    expect(ostinatoProgressSyncAvailable, isFalse);
  });

  group('merge rule', () {
    test('first seen is earliest, last practice is latest', () {
      final a = _rec(seen: _t(5), practiced: _t(6), counts: {_phone: 1});
      final b = _rec(seen: _t(1), practiced: _t(9), counts: {_tablet: 1});
      final m = a.merge(b);
      expect(m.seenAt, _t(1));
      expect(m.practicedAt, _t(9));
    });

    test('completion is monotone: once set it never clears, earliest wins', () {
      final done = _rec(completed: _t(8), counts: {_phone: 1});
      final notDone = _rec(practiced: _t(9), counts: {_tablet: 2});
      expect(done.merge(notDone).completedAt, _t(8));
      expect(notDone.merge(done).completedAt, _t(8));
      final earlier = _rec(completed: _t(3), counts: {_tablet: 1});
      expect(done.merge(earlier).completedAt, _t(3));
    });

    test('offline practice on two devices is counted on both', () {
      final base = _rec(counts: {_phone: 2});
      final phone = _rec(counts: {_phone: 3});
      final tablet = _rec(counts: {_phone: 2, _tablet: 1});
      expect(base.merge(phone).merge(tablet).practiceCount, 4);
      // A stale copy of the same replica does not lose increments.
      expect(phone.merge(base).practiceCounts[_phone], 3);
    });

    test('different lessons or content versions never merge', () {
      final v2 = LessonProgressSyncRecord(
        contentVersion: 'v2',
        lessonId: 'g-01',
      );
      expect(() => _rec().merge(v2), throwsArgumentError);
    });

    test('merge is commutative, associative and idempotent', () {
      final random = Random(16);
      DateTime? maybe() => random.nextBool() ? _t(random.nextInt(60)) : null;
      LessonProgressSyncRecord sample() {
        final counts = <String, int>{
          for (final r in [_phone, _tablet, _laptop])
            if (random.nextBool()) r: random.nextInt(5),
        };
        final total = counts.values.fold<int>(0, (s, v) => s + v);
        return _rec(
          seen: maybe(),
          practiced: maybe(),
          completed: total > 0 ? maybe() : null,
          counts: counts,
        );
      }

      for (var i = 0; i < 300; i++) {
        final a = sample(), b = sample(), c = sample();
        expect(a.merge(b), b.merge(a));
        expect(a.merge(b).merge(c), a.merge(b.merge(c)));
        expect(a.merge(a), a);
        expect(a.merge(b).merge(b), a.merge(b));
        final m = a.merge(b);
        if (m.isCompleted) expect(m.practiceCount, greaterThan(0));
      }
    });

    test('record sets merge per key and keep one-sided keys', () {
      final a = {'v1|g-01': _rec(seen: _t(2))};
      final other = LessonProgressSyncRecord(
        contentVersion: 'v1',
        lessonId: 'g-02',
        seenAt: _t(4),
      );
      final merged = mergeProgressSets(a, {
        'v1|g-01': _rec(seen: _t(1)),
        other.key: other,
      });
      expect(merged.keys, unorderedEquals(['v1|g-01', 'v1|g-02']));
      expect(merged['v1|g-01']!.seenAt, _t(1));
    });
  });

  group('validation', () {
    test('rejects invalid identity, counters and early completion', () {
      expect(
        () => LessonProgressSyncRecord(contentVersion: 'v|1', lessonId: 'g'),
        throwsArgumentError,
      );
      expect(
        () => LessonProgressSyncRecord(contentVersion: 'v1', lessonId: ''),
        throwsArgumentError,
      );
      expect(() => _rec(counts: {_phone: -1}), throwsArgumentError);
      expect(() => _rec(counts: {'device-1': 1}), throwsArgumentError);
      expect(() => _rec(completed: _t(1)), throwsArgumentError);
    });

    test('local completion needs a practice entry, like the local store', () {
      expect(
        () => _rec().apply(
          GuitarProgressAction.selfReportedCompleted,
          replicaId: _phone,
          at: _t(1),
        ),
        throwsStateError,
      );
      final practiced = _rec().apply(
        GuitarProgressAction.practiced,
        replicaId: _phone,
        at: _t(1),
      );
      final done = practiced.apply(
        GuitarProgressAction.selfReportedCompleted,
        replicaId: _phone,
        at: _t(2),
      );
      expect(done.completedAt, _t(2));
      expect(done.seenAt, _t(1));
      expect(done.practiceCount, 1);
    });

    test('wire JSON round-trips and carries progress fields only', () {
      final record = _rec(
        seen: _t(1),
        practiced: _t(2),
        completed: _t(3),
        counts: {_phone: 2},
      );
      final json = record.toJson();
      expect(json.keys, {
        'content_version',
        'lesson_id',
        'seen_at',
        'practiced_at',
        'completed_at',
        'practice_counts',
      });
      expect(LessonProgressSyncRecord.fromJson(json), record);
    });
  });

  group('engine with the in-memory adapter', () {
    test('two devices of one account converge', () async {
      final server = InMemoryProgressSyncAdapter();
      final phone = ProgressSyncEngine(
        adapter: server,
        accountUserId: _account,
        replicaId: _phone,
      );
      final tablet = ProgressSyncEngine(
        adapter: server,
        accountUserId: _account,
        replicaId: _tablet,
      );
      var p = phone.recordLocal(
        ProgressSyncState(),
        contentVersion: 'v1',
        lessonId: 'g-01',
        action: GuitarProgressAction.practiced,
        at: _t(1),
      );
      p = phone.recordLocal(
        p,
        contentVersion: 'v1',
        lessonId: 'g-01',
        action: GuitarProgressAction.selfReportedCompleted,
        at: _t(2),
      );
      var t = tablet.recordLocal(
        ProgressSyncState(),
        contentVersion: 'v1',
        lessonId: 'g-01',
        action: GuitarProgressAction.practiced,
        at: _t(5),
      );

      p = (await phone.syncOnce(p)).state;
      t = (await tablet.syncOnce(t)).state;
      p = (await phone.syncOnce(p)).state;

      final onPhone = p.records['v1|g-01']!;
      final onTablet = t.records['v1|g-01']!;
      expect(onPhone, onTablet);
      expect(onPhone.practiceCount, 2);
      expect(onPhone.completedAt, _t(2));
      expect(onPhone.practicedAt, _t(5));
      expect(p.dirty, isEmpty);
      expect(t.dirty, isEmpty);
      expect(server.remoteFor(_account)['v1|g-01'], onPhone);
    });

    test('offline keeps local progress and dirty keys, then retries', () async {
      final server = InMemoryProgressSyncAdapter()..online = false;
      final engine = ProgressSyncEngine(
        adapter: server,
        accountUserId: _account,
        replicaId: _phone,
      );
      final local = engine.recordLocal(
        ProgressSyncState(),
        contentVersion: 'v1',
        lessonId: 'g-01',
        action: GuitarProgressAction.viewed,
        at: _t(1),
      );
      final failed = await engine.syncOnce(local);
      expect(failed.succeeded, isFalse);
      expect(failed.error, isA<ProgressSyncUnavailable>());
      expect(failed.state.records, local.records);
      expect(failed.state.dirty, {'v1|g-01'});

      server.online = true;
      final ok = await engine.syncOnce(failed.state);
      expect(ok.succeeded, isTrue);
      expect(ok.state.dirty, isEmpty);
      expect(server.remoteFor(_account)['v1|g-01']!.seenAt, _t(1));

      // A clean state pushes nothing.
      final pushes = server.pushCalls;
      await engine.syncOnce(ok.state);
      expect(server.pushCalls, pushes);
    });

    test('a repeated push after a lost acknowledgement is harmless', () async {
      final server = InMemoryProgressSyncAdapter();
      final record = _rec(practiced: _t(1), counts: {_phone: 1});
      await server.push(_account, [record]);
      await server.push(_account, [record]);
      expect(server.remoteFor(_account)['v1|g-01']!.practiceCount, 1);
    });

    test('accounts are isolated', () async {
      final server = InMemoryProgressSyncAdapter();
      final a = ProgressSyncEngine(
        adapter: server,
        accountUserId: _account,
        replicaId: _phone,
      );
      final b = ProgressSyncEngine(
        adapter: server,
        accountUserId: _otherAccount,
        replicaId: _phone,
      );
      await a.syncOnce(
        a.recordLocal(
          ProgressSyncState(),
          contentVersion: 'v1',
          lessonId: 'g-01',
          action: GuitarProgressAction.viewed,
          at: _t(1),
        ),
      );
      final other = await b.syncOnce(ProgressSyncState());
      expect(other.state.records, isEmpty);
      expect(server.remoteFor(_otherAccount), isEmpty);
    });

    test('pull returns only changes after the cursor', () async {
      final server = InMemoryProgressSyncAdapter();
      await server.push(_account, [_rec(seen: _t(1))]);
      final first = await server.pull(_account);
      expect(first.records, hasLength(1));
      final second = await server.pull(_account, since: first.cursor);
      expect(second.records, isEmpty);
    });

    test('engine rejects a non-UUID account or replica', () {
      final server = InMemoryProgressSyncAdapter();
      expect(
        () => ProgressSyncEngine(
          adapter: server,
          accountUserId: 'guest',
          replicaId: _phone,
        ),
        throwsArgumentError,
      );
      expect(
        () => ProgressSyncEngine(
          adapter: server,
          accountUserId: _account,
          replicaId: 'device-serial',
        ),
        throwsArgumentError,
      );
    });
  });
}
