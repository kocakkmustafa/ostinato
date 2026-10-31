import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/retention/weekly_goal.dart';

PracticeEntry practice(
  LocalDay day, {
  PracticeEntryKind kind = PracticeEntryKind.lessonPractice,
  PracticeCourse course = PracticeCourse.guitar,
}) => PracticeEntry(day: day, kind: kind, course: course);

PracticeEntry rest(LocalDay day) => PracticeEntry(
  day: day,
  kind: PracticeEntryKind.voiceRestDay,
  course: PracticeCourse.voice,
);

/// Monday 2026-11-02 is the first day of week 0 in these tests.
final monday = LocalDay(2026, 11, 2);

/// Days [d0, d1, …] of week [week] (offsets from that week's Monday).
List<PracticeEntry> week(int week, List<int> offsets) => [
  for (final o in offsets) practice(monday.addDays(week * 7 + o)),
];

void main() {
  group('LocalDay', () {
    test('parse is strict and round-trips', () {
      expect(LocalDay.parse('2026-11-02').toIso(), '2026-11-02');
      expect(() => LocalDay.parse('2026-02-30'), throwsFormatException);
      expect(() => LocalDay.parse('2026-1-02'), throwsFormatException);
      expect(LocalDay(2026, 12, 31).addDays(1), LocalDay(2027, 1, 1));
      expect(monday.weekday, DateTime.monday);
    });

    test('a local instant keeps the wall-clock day of its time zone', () {
      // 21:30 UTC on Sunday is already Monday 00:30 in Istanbul (UTC+3)
      // and still Sunday 16:30 in New York (UTC-5).
      final utc = DateTime.utc(2026, 11, 8, 21, 30);
      expect(LocalInstant(utc, const Duration(hours: 3)).day, monday.addDays(7));
      expect(
        LocalInstant(utc, const Duration(hours: -5)).day,
        LocalDay(2026, 11, 8),
      );
      expect(LocalInstant(utc, Duration.zero).day, LocalDay(2026, 11, 8));
      // Half-hour zones (India, UTC+5:30).
      expect(
        LocalInstant(
          DateTime.utc(2026, 11, 8, 18, 30),
          const Duration(hours: 5, minutes: 30),
        ).day,
        monday.addDays(7),
      );
    });
  });

  group('week boundary', () {
    test('Sunday 23:59 and Monday 00:00 fall in different weeks', () {
      const rules = WeeklyGoalRules();
      final sunday = LocalInstant(
        DateTime.utc(2026, 11, 8, 20, 59),
        const Duration(hours: 3),
      ).day; // 23:59 local
      final nextMonday = LocalInstant(
        DateTime.utc(2026, 11, 8, 21, 0),
        const Duration(hours: 3),
      ).day; // 00:00 local
      expect(rules.weekStartOf(sunday), monday);
      expect(rules.weekStartOf(nextMonday), monday.addDays(7));
    });

    test('a Sunday-first week moves the boundary', () {
      const rules = WeeklyGoalRules(firstDayOfWeek: DateTime.sunday);
      final sunday = LocalDay(2026, 11, 8);
      expect(rules.weekStartOf(sunday), sunday);
      expect(rules.weekStartOf(sunday.addDays(6)), sunday);
      expect(rules.weekStartOf(sunday.addDays(-1)), sunday.addDays(-7));
    });

    test('entries count in the week of their recorded local day', () {
      // Three sessions: Sat, Sun (late evening locally), and Mon.
      final status = evaluateWeeklyGoal(
        entries: [
          practice(monday.addDays(5)),
          practice(monday.addDays(6)),
          practice(monday.addDays(7)),
        ],
        today: monday.addDays(7),
      );
      expect(status.weeks.first.practiceDays, 2);
      expect(status.practiceDays, 1);
      expect(status.weeks.first.outcome, WeekOutcome.inactive);
    });

    test('travel does not move an entry already recorded', () {
      // Recorded on Sunday in New York; evaluated later from Istanbul.
      final recorded = LocalInstant(
        DateTime.utc(2026, 11, 9, 3, 0),
        const Duration(hours: -5),
      ).day;
      expect(recorded, LocalDay(2026, 11, 8));
      final status = evaluateWeeklyGoal(
        entries: [practice(recorded)],
        today: LocalInstant(
          DateTime.utc(2026, 11, 9, 9),
          const Duration(hours: 3),
        ).day,
      );
      expect(status.weekStart, monday.addDays(7));
      expect(status.practiceDays, 0);
      expect(status.weeks.first.practiceDays, 1);
    });
  });

  group('sessions', () {
    test('several entries on one day are one session', () {
      final day = monday.addDays(1);
      final status = evaluateWeeklyGoal(
        entries: [
          practice(day),
          practice(day, kind: PracticeEntryKind.offApp),
          practice(day, kind: PracticeEntryKind.measuredSession),
        ],
        today: day,
      );
      expect(status.practiceDays, 1);
      expect(status.goal, 3);
      expect(status.currentWeekMet, isFalse);
      expect(status.todayPracticed, isTrue);
      expect(status.practicedWeekdays, {1});
      expect(status.daysLeftInWeek, 6);
    });

    test('off-app entries count like any session', () {
      final status = evaluateWeeklyGoal(
        entries: [
          for (final o in [0, 2, 4])
            practice(monday.addDays(o), kind: PracticeEntryKind.offApp),
        ],
        today: monday.addDays(4),
      );
      expect(status.currentWeekMet, isTrue);
      expect(status.streakActive, isTrue);
      expect(status.streakWeeks, 1);
    });

    test('future-dated entries wait for their day', () {
      final status = evaluateWeeklyGoal(
        entries: [practice(monday.addDays(3))],
        today: monday,
      );
      expect(status.practiceDays, 0);
      expect(status.weeks, isEmpty);
    });

    test('measured practice needs a minute and one heard event', () {
      const ok = MeasuredPracticeSession(
        course: PracticeCourse.guitar,
        activeDuration: Duration(seconds: 60),
        heardEvents: 1,
      );
      expect(practiceSessionQualifies(ok), isTrue);
      expect(
        practiceSessionQualifies(
          const MeasuredPracticeSession(
            course: PracticeCourse.guitar,
            activeDuration: Duration(seconds: 59),
            heardEvents: 40,
          ),
        ),
        isFalse,
      );
      expect(
        practiceSessionQualifies(
          const MeasuredPracticeSession(
            course: PracticeCourse.guitar,
            activeDuration: Duration(minutes: 10),
            heardEvents: 0,
          ),
        ),
        isFalse,
      );
    });
  });

  group('streak and freezes', () {
    test('no streak and no freeze use before the first met week', () {
      final status = evaluateWeeklyGoal(
        entries: [...week(0, [0]), ...week(1, [0, 1])],
        today: monday.addDays(21),
      );
      expect(
        status.weeks.map((w) => w.outcome),
        [WeekOutcome.inactive, WeekOutcome.inactive, WeekOutcome.inactive,
         WeekOutcome.inProgress],
      );
      expect(status.streakActive, isFalse);
      expect(status.freezesLeft, 2);
    });

    test('the current week never counts as missed before it ends', () {
      final status = evaluateWeeklyGoal(
        entries: [...week(0, [0, 1, 2])],
        today: monday.addDays(13), // Sunday of week 1, nothing played yet
      );
      expect(status.weeks.last.outcome, WeekOutcome.inProgress);
      expect(status.streakActive, isTrue);
      expect(status.streakWeeks, 1);
      expect(status.freezesLeft, 2);
      expect(status.daysLeftInWeek, 1);
    });

    test('two missed weeks use two freezes; the third ends the streak', () {
      final status = evaluateWeeklyGoal(
        entries: [...week(0, [0, 1, 2]), ...week(2, [0])],
        today: monday.addDays(4 * 7),
      );
      expect(status.weeks.map((w) => w.outcome), [
        WeekOutcome.met,
        WeekOutcome.frozen,
        WeekOutcome.frozen,
        WeekOutcome.streakEnded,
        WeekOutcome.inProgress,
      ]);
      expect(status.streakActive, isFalse);
      expect(status.streakWeeks, 0);
    });

    test('a frozen week keeps but does not grow the streak', () {
      final status = evaluateWeeklyGoal(
        entries: [...week(0, [0, 1, 2]), ...week(2, [0, 1, 2])],
        today: monday.addDays(2 * 7 + 2),
      );
      expect(status.weeks.map((w) => w.outcome), [
        WeekOutcome.met,
        WeekOutcome.frozen,
        WeekOutcome.met,
      ]);
      expect(status.streakWeeks, 2);
      expect(status.freezesLeft, 1);
    });

    test('every fifth met week earns one freeze', () {
      final entries = [
        for (var w = 0; w < 10; w++) ...week(w, [0, 1, 2]),
      ];
      final afterFour = evaluateWeeklyGoal(
        entries: entries,
        today: monday.addDays(3 * 7 + 6),
      );
      expect(afterFour.streakWeeks, 4);
      expect(afterFour.freezesLeft, 2);
      expect(afterFour.metWeeksUntilNextFreeze, 1);
      final afterTen = evaluateWeeklyGoal(
        entries: entries,
        today: monday.addDays(9 * 7 + 6),
      );
      expect(afterTen.streakWeeks, 10);
      expect(afterTen.freezesLeft, 4);
      expect(afterTen.metWeeksUntilNextFreeze, 5);
    });

    test('a new streak after an ended one starts with a fresh allowance', () {
      final status = evaluateWeeklyGoal(
        entries: [...week(0, [0, 1, 2]), ...week(4, [0, 1, 2])],
        today: monday.addDays(4 * 7 + 3),
      );
      expect(status.weeks[3].outcome, WeekOutcome.streakEnded);
      expect(status.weeks.last.outcome, WeekOutcome.met);
      expect(status.streakWeeks, 1);
      expect(status.freezesLeft, 2);
    });
  });

  group('goal changes', () {
    test('a change applies from its own week onwards', () {
      final status = evaluateWeeklyGoal(
        entries: [...week(0, [0, 1]), ...week(1, [0, 1])],
        goalChanges: [GoalChange(fromDay: monday.addDays(10), sessionsPerWeek: 2)],
        today: monday.addDays(10),
      );
      expect(status.weeks.first.goal, 3);
      expect(status.weeks.first.outcome, WeekOutcome.inactive);
      expect(status.goal, 2);
      expect(status.currentWeekMet, isTrue);
    });

    test('the last change within a week wins', () {
      final changes = [
        GoalChange(fromDay: monday, sessionsPerWeek: 5),
        GoalChange(fromDay: monday.addDays(2), sessionsPerWeek: 1),
      ];
      expect(goalForWeek(monday, changes, const WeeklyGoalRules()), 1);
      expect(goalForWeek(monday.addDays(-7), changes, const WeeklyGoalRules()), 3);
    });
  });

  group('voice rest days', () {
    test('rest days count toward the goal but one session is required', () {
      final onlyRest = evaluateWeeklyGoal(
        entries: [for (final o in [0, 1, 2]) rest(monday.addDays(o))],
        today: monday.addDays(6),
      );
      expect(onlyRest.practiceDays, 0);
      expect(onlyRest.restDaysCredited, 2);
      expect(onlyRest.currentWeekMet, isFalse);

      final withSession = evaluateWeeklyGoal(
        entries: [
          rest(monday),
          rest(monday.addDays(1)),
          practice(monday.addDays(2), course: PracticeCourse.voice),
        ],
        today: monday.addDays(2),
      );
      expect(withSession.currentWeekMet, isTrue);
    });

    test('a rest day does not break an active streak', () {
      final status = evaluateWeeklyGoal(
        entries: [
          ...week(0, [0, 1, 2]),
          practice(monday.addDays(7), course: PracticeCourse.voice),
          rest(monday.addDays(8)),
          rest(monday.addDays(9)),
        ],
        today: monday.addDays(14),
      );
      expect(status.weeks[1].outcome, WeekOutcome.met);
      expect(status.streakWeeks, 2);
      expect(status.freezesLeft, 2);
    });

    test('a rest day on a practice day is not counted twice', () {
      final status = evaluateWeeklyGoal(
        entries: [practice(monday), rest(monday)],
        today: monday,
      );
      expect(status.practiceDays, 1);
      expect(status.restDaysCredited, 0);
    });

    test('rest days are voice-only in stored data', () {
      expect(
        () => PracticeEntry.fromJson({
          'day': '2026-11-02',
          'kind': 'voice_rest',
          'course': 'guitar',
        }),
        throwsFormatException,
      );
      final entry = rest(monday);
      expect(PracticeEntry.fromJson(entry.toJson()), entry);
    });
  });
}
