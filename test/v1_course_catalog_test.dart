// v1 full guitar course: availability per lesson in this build, units and
// gates (contract 00-ders-format-sozlesmesi §4.2, §6.4, §9), unlocks and the
// self-check / tuner completion store.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/curriculum/v1_lesson.dart';
import 'package:ostinato/app/practice/loop/practice_progress_store.dart';
import 'package:ostinato/app/practice/loop/v1_course_catalog.dart';
import 'package:ostinato/app/practice/loop/v1_practice_catalog.dart';

List<V1Lesson> bundled() => [
  for (final f in Directory('content/v1/gtr').listSync())
    if (f is File && f.path.endsWith('.json'))
      V1Lesson.fromJson(jsonDecode(f.readAsStringSync())),
];

V1PracticeRecord passed(String id, {bool completed = false}) =>
    V1PracticeRecord(
      lessonId: id,
      runs: 1,
      passedAt: DateTime.utc(2026, 11, 1),
      passedBpm: 50,
      completedAt: completed ? DateTime.utc(2026, 11, 1) : null,
      completedBpm: completed ? 60 : null,
    );

V1LessonCheck self(String id) => V1LessonCheck(
  lessonId: id,
  evidence: V1CheckEvidence.selfReport,
  at: DateTime.utc(2026, 11, 2),
);

V1LessonCheck tuned(String id) => V1LessonCheck(
  lessonId: id,
  evidence: V1CheckEvidence.tunerCheck,
  at: DateTime.utc(2026, 11, 2),
);

void main() {
  final catalog = V1CourseCatalog(bundled());

  V1LessonAvailability a(String id) => catalog.lesson(id)!.availability;
  V1PendingReason r(String id) => catalog.lesson(id)!.reason;

  group('catalog', () {
    test('every guitar lesson is in the course, in id order', () {
      expect(catalog.lessons, hasLength(240));
      final ids = catalog.orderedIds;
      expect(ids, [...ids]..sort());
      expect(catalog.levels.map((l) => l.level), [1, 2, 3, 4]);
      expect(ids.first, 'gtr-s1-m01-01');
      expect(ids.last, 'gtr-s4-test-b');
    });

    test('units: modules, tracks and level tests; the last lesson gates', () {
      final s1 = catalog.levels.first.units.map((u) => u.id);
      expect(s1, [
        'gtr-s1-m01',
        'gtr-s1-m02',
        'gtr-s1-m03',
        'gtr-s1-m04',
        'gtr-s1-test',
      ]);
      expect(catalog.unit('gtr-s1-m02')!.gate.id, 'gtr-s1-m02-10');
      expect(catalog.unit('gtr-s1-test')!.isTest, isTrue);
      expect(catalog.unit('gtr-s4-m19a')!.track, 'a');
      expect(catalog.unit('gtr-s4-test-b')!.track, 'b');
      expect(catalog.unitOf('gtr-s4-m19b-07').id, 'gtr-s4-m19b');
    });

    test('measured = A2/A3 single-note lines the loop can run', () {
      expect(a('gtr-s1-m02-02'), V1LessonAvailability.measured);
      expect(a('gtr-s1-m02-10'), V1LessonAvailability.measured);
      // D+M with a playable line: the measured part runs.
      expect(a('gtr-s2-m09-06'), V1LessonAvailability.measured);
      final measured = catalog.lessons
          .where((l) => l.availability == V1LessonAvailability.measured)
          .map((l) => l.lesson);
      expect(measured.every(V1PracticeCatalog.isPracticable), isTrue);
      // Everything the old practice list showed stays measured, except the
      // A1-only tuning checkpoint, which moves to the tuner.
      final old = V1PracticeCatalog(bundled()).orderedIds.toSet()
        ..remove('gtr-s1-m01-04');
      expect(measured.map((l) => l.id).toSet(), old);
    });

    test('A4 chord lessons → self-check (chords)', () {
      expect(a('gtr-s1-m04-01'), V1LessonAvailability.selfCheck);
      expect(r('gtr-s1-m04-01'), V1PendingReason.chords);
      expect(a('gtr-s2-m07-09'), V1LessonAvailability.selfCheck);
    });

    test('technique notation → self-check (technique)', () {
      expect(a('gtr-s4-m19a-07'), V1LessonAvailability.selfCheck);
      expect(r('gtr-s4-m19a-07'), V1PendingReason.technique);
      expect(r('gtr-s3-m12-05'), V1PendingReason.chords, reason: 'A4 first');
    });

    test('A5 bends and vibrato → self-check (pitch track)', () {
      for (final id in ['gtr-s4-m19b-05', 'gtr-s4-m19b-08']) {
        expect(a(id), V1LessonAvailability.selfCheck);
        expect(r(id), V1PendingReason.pitchTrack);
      }
    });

    test('A3 rhythm-only lines → measured on onset timing', () {
      // These were self-check / held until the loop could run a line with
      // no pitches (`h` is a half note there, not a hammer-on).
      const movedToMeasured = [
        'gtr-s1-m03-01', // first S1 checkpoint (M!)
        'gtr-s1-m03-02',
        'gtr-s1-m03-03',
        'gtr-s1-m03-04',
        'gtr-s1-m03-05',
        'gtr-s1-m03-06',
        'gtr-s1-m03-07',
        'gtr-s1-m03-09',
        'gtr-s1-m03-10', // M03 checkpoint (M!)
        'gtr-s2-m06-02',
        'gtr-s2-m06-03',
        'gtr-s2-m06-05',
        'gtr-s2-m06-06', // chord labels, A3 only
        'gtr-s2-m06-10',
        'gtr-s3-m10-04',
        'gtr-s3-m12-10',
        'gtr-s4-m16-07', // chord labels, A3 only
        'gtr-s4-m16-09', // chord labels, A3 only
      ];
      // Power-chord labels (`E5 ee ee`) were read as the pitch E5.
      const powerChordRhythm = [
        'gtr-s3-m10-05',
        'gtr-s3-m10-06',
        'gtr-s3-m10-09',
      ];
      final rhythm = [
        for (final l in catalog.lessons)
          if (l.availability == V1LessonAvailability.measured &&
              V1PracticeCatalog.scoreOf(l.lesson)!.isRhythmOnly)
            l.id,
      ];
      expect(rhythm, [...movedToMeasured, ...powerChordRhythm]..sort());
      for (final id in rhythm) {
        final steps = catalog.lesson(id)!.lesson.practice.engineSteps;
        expect(steps, contains('A3'), reason: id);
        expect(steps, isNot(contains('A4')), reason: id);
      }
      expect(a('gtr-s1-m03-01'), V1LessonAvailability.measured);
      expect(a('gtr-s1-m03-10'), V1LessonAvailability.measured);
    });

    test('rhythm that needs the chord itself (A4) stays self-check', () {
      for (final id in [
        'gtr-s2-m06-01',
        'gtr-s2-m06-04',
        'gtr-s2-m06-07',
        'gtr-s2-m06-12',
        'gtr-s3-m13-10',
        'gtr-s3-m14-11',
        'gtr-s4-m15-08',
      ]) {
        expect(a(id), V1LessonAvailability.selfCheck, reason: id);
        expect(r(id), V1PendingReason.chords, reason: id);
      }
      expect(a('gtr-s4-m16-11'), V1LessonAvailability.held);
    });

    test('no-sequence M lessons → self-check (notation)', () {
      expect(a('gtr-s1-m01-06'), V1LessonAvailability.selfCheck);
      expect(r('gtr-s1-m01-06'), V1PendingReason.notation);
      expect(a('gtr-s2-m09-09'), V1LessonAvailability.selfCheck);
    });

    test('M! that cannot be measured → held; tests too', () {
      expect(a('gtr-s1-m04-11'), V1LessonAvailability.held);
      expect(r('gtr-s1-m04-11'), V1PendingReason.chords);
      expect(a('gtr-s2-m06-13'), V1LessonAvailability.held);
      expect(a('gtr-s1-test'), V1LessonAvailability.held);
      expect(a('gtr-s4-test-b'), V1LessonAvailability.held);
      expect(a('gtr-s4-m19b-18'), V1LessonAvailability.held);
    });

    test('A1 tuning lessons → tuner', () {
      expect(a('gtr-s1-m01-04'), V1LessonAvailability.tuner);
      expect(a('gtr-s1-m01-05'), V1LessonAvailability.tuner);
      // A1 next to a playable line stays measured (octaves, drop D).
      expect(a('gtr-s2-m09-10'), V1LessonAvailability.measured);
    });

    test('D → drill soon; K → camera checklist; Ö → self-check lesson', () {
      expect(a('gtr-s1-m01-01'), V1LessonAvailability.drillSoon);
      expect(a('gtr-s2-m09-02'), V1LessonAvailability.drillSoon);
      expect(a('gtr-s1-m01-02'), V1LessonAvailability.camera);
      expect(a('gtr-s1-m01-03'), V1LessonAvailability.camera);
      expect(a('gtr-s2-m08-09'), V1LessonAvailability.selfCheckLesson);
    });

    test('every lesson gets a class; non-measured ones a self-report', () {
      for (final l in catalog.lessons) {
        expect(
          l.selfReportable,
          l.availability != V1LessonAvailability.measured &&
              l.availability != V1LessonAvailability.tuner,
          reason: l.id,
        );
      }
    });
  });

  group('gates (§6.4, §9)', () {
    List<String> gates(String unit) => catalog.unit(unit)!.requiredGateIds;

    test('previous unit gate; level test after the last module', () {
      expect(gates('gtr-s1-m01'), isEmpty);
      expect(gates('gtr-s1-m02'), ['gtr-s1-m01-08']);
      expect(gates('gtr-s1-test'), ['gtr-s1-m04-11']);
      expect(gates('gtr-s2-m05'), ['gtr-s1-test']);
      expect(gates('gtr-s4-m15'), ['gtr-s3-test']);
    });

    test('S4 tracks need M15 + M17; track tests follow their track', () {
      expect(gates('gtr-s4-m19a'), ['gtr-s4-m15-11', 'gtr-s4-m17-10']);
      expect(gates('gtr-s4-m19b'), ['gtr-s4-m15-11', 'gtr-s4-m17-10']);
      expect(gates('gtr-s4-test-a'), ['gtr-s4-m19a-18']);
      expect(gates('gtr-s4-test-b'), ['gtr-s4-m19b-18']);
    });
  });

  group('unlocks', () {
    V1CourseState state({
      Map<String, V1PracticeRecord> records = const {},
      Map<String, V1LessonCheck> checks = const {},
    }) => V1CourseState(catalog, records, checks);

    test('fresh: only module 1 is open, every lesson in it', () {
      final s = state();
      expect(s.units['gtr-s1-m01'], V1UnitOpen.open);
      expect(s.units['gtr-s1-m02'], V1UnitOpen.locked);
      for (final l in catalog.unit('gtr-s1-m01')!.lessons) {
        expect(s.isOpen(l.id), isTrue, reason: 'no lock inside a module');
      }
      expect(s.isOpen('gtr-s1-m02-01'), isFalse);
      expect(s.status(catalog.lesson('gtr-s1-m02-01')!), V1LessonStatus.locked);
      expect(s.next!.id, 'gtr-s1-m01-01');
    });

    test('a measured gate pass opens the next module as measured', () {
      final s = state(records: {'gtr-s1-m01-08': passed('gtr-s1-m01-08')});
      expect(s.units['gtr-s1-m02'], V1UnitOpen.open);
      expect(s.units['gtr-s1-m03'], V1UnitOpen.locked);
    });

    test('M03 checkpoint is measured: only a measured pass opens M04', () {
      final records = {
        for (final id in ['gtr-s1-m01-08', 'gtr-s1-m02-10']) id: passed(id),
      };
      final gate = catalog.lesson('gtr-s1-m03-10')!;
      var s = state(records: records, checks: {gate.id: self(gate.id)});
      expect(s.gateClear(gate), V1GateClear.none);
      expect(s.units['gtr-s1-m04'], V1UnitOpen.locked);
      s = state(records: {...records, gate.id: passed(gate.id)});
      expect(s.units['gtr-s1-m04'], V1UnitOpen.open);
    });

    test('a self-report never clears a measurable gate', () {
      final s = state(
        records: {'gtr-s1-m01-08': passed('gtr-s1-m01-08')},
        checks: {'gtr-s1-m02-10': self('gtr-s1-m02-10')},
      );
      expect(s.gateClear(catalog.lesson('gtr-s1-m02-10')!), V1GateClear.none);
      expect(s.units['gtr-s1-m03'], V1UnitOpen.locked);
      expect(
        s.status(catalog.lesson('gtr-s1-m02-10')!),
        V1LessonStatus.repeatWithMeasurement,
      );
    });

    test('held gate: self-check opens the next module "not measured"', () {
      final records = {
        for (final id in ['gtr-s1-m01-08', 'gtr-s1-m02-10', 'gtr-s1-m03-10'])
          id: passed(id),
      };
      var s = state(records: records);
      final held = catalog.lesson('gtr-s1-m04-11')!;
      expect(s.units['gtr-s1-m04'], V1UnitOpen.open);
      expect(s.status(held), V1LessonStatus.held);
      expect(s.units['gtr-s1-test'], V1UnitOpen.locked);
      s = state(records: records, checks: {held.id: self(held.id)});
      expect(s.gateClear(held), V1GateClear.selfReported);
      expect(s.status(held), V1LessonStatus.heldSelfReported);
      expect(s.units['gtr-s1-test'], V1UnitOpen.openNotMeasured);
      expect(s.isOpen('gtr-s1-test'), isTrue);
      // The label does not travel on: the next gate must clear on its own.
      expect(s.units['gtr-s2-m05'], V1UnitOpen.locked);
    });

    test('S4 track opens "not measured" when one of M15/M17 is held', () {
      final s = state(
        records: {'gtr-s4-m17-10': passed('gtr-s4-m17-10')},
        checks: {'gtr-s4-m15-11': self('gtr-s4-m15-11')},
      );
      expect(s.units['gtr-s4-m19a'], V1UnitOpen.openNotMeasured);
      expect(s.units['gtr-s4-m19b'], V1UnitOpen.openNotMeasured);
      expect(
        state(
          checks: {'gtr-s4-m15-11': self('gtr-s4-m15-11')},
        ).units['gtr-s4-m19a'],
        V1UnitOpen.locked,
        reason: 'M17 is measurable and not passed',
      );
    });

    test('earlier measured progress keeps its module open', () {
      final s = state(records: {'gtr-s2-m08-03': passed('gtr-s2-m08-03')});
      expect(s.units['gtr-s2-m08'], V1UnitOpen.openEarlierProgress);
      expect(s.isOpen('gtr-s2-m08-01'), isTrue);
      expect(s.units['gtr-s2-m09'], V1UnitOpen.locked);
    });

    test('tuner lessons: a tuner check is measured; old loop passes count', () {
      final l = catalog.lesson('gtr-s1-m01-04')!;
      expect(
        state(checks: {l.id: tuned(l.id)}).status(l),
        V1LessonStatus.tuned,
      );
      expect(
        state(records: {l.id: passed(l.id, completed: true)}).status(l),
        V1LessonStatus.completed,
      );
      expect(state().status(l), V1LessonStatus.open);
    });

    test('next lesson: course order, skipping done ones of any kind', () {
      final s = state(
        checks: {
          'gtr-s1-m01-01': self('gtr-s1-m01-01'),
          'gtr-s1-m01-02': self('gtr-s1-m01-02'),
        },
      );
      expect(s.next!.id, 'gtr-s1-m01-03');
      expect(s.unitProgress(catalog.unit('gtr-s1-m01')!), (2, 8));
      expect(
        s.status(catalog.lesson('gtr-s1-m01-01')!),
        V1LessonStatus.selfReported,
      );
    });
  });

  group('lesson check store', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('v1-checks'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('self-report round trip in its own file, no audio or items', () async {
      final store = V1LessonCheckStore(directoryProvider: () async => dir);
      expect(await store.load(), isEmpty);
      await store.record(
        'gtr-s1-m04-01',
        V1CheckEvidence.selfReport,
        at: DateTime.utc(2026, 11, 2, 9),
      );
      final again = V1LessonCheckStore(directoryProvider: () async => dir);
      final loaded = await again.load();
      expect(loaded.keys, ['gtr-s1-m04-01']);
      final c = loaded['gtr-s1-m04-01']!;
      expect(c.evidence, V1CheckEvidence.selfReport);
      expect(c.measured, isFalse);
      expect(c.at, DateTime.utc(2026, 11, 2, 9));
      final raw = File(
        '${dir.path}/${V1LessonCheckStore.fileName}',
      ).readAsStringSync();
      final json = jsonDecode(raw) as Map<String, dynamic>;
      expect(json['schemaVersion'], 1);
      expect((json['records'] as List).single, {
        'lessonId': 'gtr-s1-m04-01',
        'evidence': 'self_report',
        'at': '2026-11-02T09:00:00.000Z',
      });
      // The measured-practice file is untouched.
      expect(
        File('${dir.path}/v1_practice_progress.v1.json').existsSync(),
        isFalse,
      );
    });

    test('first record kept; a tuner check replaces a self-report', () async {
      final store = V1LessonCheckStore(directoryProvider: () async => dir);
      final first = await store.record(
        'a',
        V1CheckEvidence.selfReport,
        at: DateTime.utc(2026, 11, 1),
      );
      final second = await store.record(
        'a',
        V1CheckEvidence.selfReport,
        at: DateTime.utc(2026, 11, 3),
      );
      expect(second.at, first.at);
      final tunerCheck = await store.record(
        'a',
        V1CheckEvidence.tunerCheck,
        at: DateTime.utc(2026, 11, 4),
      );
      expect(tunerCheck.measured, isTrue);
      final back = await store.record('a', V1CheckEvidence.selfReport);
      expect(back.evidence, V1CheckEvidence.tunerCheck);
      expect((await store.load())['a']!.evidence, V1CheckEvidence.tunerCheck);
    });

    test('account directories are separate; bad files fail loudly', () async {
      final a = V1LessonCheckStore(
        directoryProvider: () async => dir,
        accountUserId: '00000000-0000-4000-8000-000000000001',
      );
      await a.record('x', V1CheckEvidence.selfReport);
      final guest = V1LessonCheckStore(directoryProvider: () async => dir);
      expect(await guest.load(), isEmpty);
      File('${dir.path}/${V1LessonCheckStore.fileName}').writeAsStringSync(
        jsonEncode({
          'schemaVersion': 1,
          'records': [
            {'lessonId': 'x', 'evidence': 'measured', 'at': '2026-11-01'},
          ],
        }),
      );
      expect(guest.load(), throwsFormatException);
    });
  });
}
