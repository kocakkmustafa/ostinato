/// F5.2 — weekly goal and weekly streak (local, never written to Motion Core).
///
/// Pure rules only: no I/O, no `DateTime.now()`. The caller passes the
/// learner's local calendar day; the store derives it from an injected clock.
///
/// Rules (PLAN-ONERISI §2 F5.2, RAPOR (f)):
/// - A *session* is a local calendar day with at least one qualifying entry:
///   a measured practice session, a lesson practice event, or an "I played
///   outside the app" entry. Several entries on one day count once, so the
///   goal rewards spread-out practice and an entry cannot be repeated for
///   credit.
/// - Default goal: 3 sessions per week. Weeks start on [WeeklyGoalRules
///   .firstDayOfWeek] (Monday by default).
/// - The streak counts consecutive weeks that met their goal. It becomes
///   active at the first week that meets the goal; until then a short week
///   costs nothing.
/// - An active streak starts with 2 freezes. A finished week below its goal
///   uses one freeze automatically: the streak survives but does not grow.
///   With no freeze left the streak ends; the next met week starts a new
///   streak with a fresh allowance. Every 5th met week of a streak adds a
///   freeze.
/// - Voice course: a logged rest day never breaks the streak. Each rest day
///   that is not also a practice day counts toward the week's goal, up to
///   `goal - 1`, so one real session per week is still needed.
/// - The current week is in progress: it can be met early but is never
///   counted as missed before it ends.
library;

/// A calendar day as the learner's device showed it. Carries no time zone:
/// an entry keeps the day it was recorded on even after travel.
final class LocalDay implements Comparable<LocalDay> {
  LocalDay(int year, int month, int day)
    : this._(DateTime.utc(year, month, day));

  LocalDay._(DateTime utcMidnight)
    : year = utcMidnight.year,
      month = utcMidnight.month,
      day = utcMidnight.day;

  factory LocalDay.fromEpochDay(int epochDay) => LocalDay._(
    DateTime.fromMillisecondsSinceEpoch(epochDay * _dayMs, isUtc: true),
  );

  /// Strict `YYYY-MM-DD`.
  factory LocalDay.parse(String value) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
    if (match == null) throw FormatException('Invalid day', value);
    final parsed = LocalDay(
      int.parse(match[1]!),
      int.parse(match[2]!),
      int.parse(match[3]!),
    );
    if (parsed.toIso() != value) throw FormatException('Invalid day', value);
    return parsed;
  }

  static const int _dayMs = 86400000;

  final int year, month, day;

  int get epochDay =>
      DateTime.utc(year, month, day).millisecondsSinceEpoch ~/ _dayMs;

  /// ISO weekday, Monday = 1 … Sunday = 7 (same as [DateTime.weekday]).
  int get weekday => DateTime.utc(year, month, day).weekday;

  LocalDay addDays(int days) => LocalDay.fromEpochDay(epochDay + days);

  String toIso() =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';

  @override
  int compareTo(LocalDay other) => epochDay.compareTo(other.epochDay);

  @override
  bool operator ==(Object other) =>
      other is LocalDay && other.epochDay == epochDay;

  @override
  int get hashCode => epochDay;

  @override
  String toString() => toIso();
}

/// One wall-clock reading: the UTC instant and the device's UTC offset at
/// that instant. Kept apart so tests can model any time zone.
final class LocalInstant {
  LocalInstant(DateTime utc, this.offset) : utc = utc.toUtc();

  final DateTime utc;
  final Duration offset;

  LocalDay get day {
    final wall = utc.add(offset);
    return LocalDay(wall.year, wall.month, wall.day);
  }
}

typedef LocalClock = LocalInstant Function();

LocalInstant systemLocalNow() {
  final now = DateTime.now();
  return LocalInstant(now.toUtc(), now.timeZoneOffset);
}

/// Course that produced an entry. Only [voice] changes a rule (rest days).
enum PracticeCourse {
  guitar('guitar'),
  bass('bass'),
  ukulele('ukulele'),
  piano('piano'),
  voice('voice'),
  ear('ear'),
  other('other');

  const PracticeCourse(this.id);
  final String id;

  static PracticeCourse fromId(String id) => values.firstWhere(
    (c) => c.id == id,
    orElse: () => throw FormatException('Unknown practice course', id),
  );

  /// Discipline IDs used by the content repository (`voice`, `guitar`, …).
  static PracticeCourse forDiscipline(String disciplineId) =>
      values.where((c) => c.id == disciplineId).firstOrNull ?? other;
}

enum PracticeEntryKind {
  /// From the measured practice loop (F2.2–F2.5), see
  /// [practiceSessionQualifies].
  measuredSession('measured'),

  /// An existing lesson event: a guitar "I practised" entry or a finished
  /// camera practice session.
  lessonPractice('lesson'),

  /// "I played outside the app" (self report).
  offApp('off_app'),

  /// Voice course rest day; never a practice day.
  voiceRestDay('voice_rest');

  const PracticeEntryKind(this.id);
  final String id;

  static PracticeEntryKind fromId(String id) => values.firstWhere(
    (k) => k.id == id,
    orElse: () => throw FormatException('Unknown practice entry kind', id),
  );
}

final class PracticeEntry {
  const PracticeEntry({
    required this.day,
    required this.kind,
    required this.course,
  });

  final LocalDay day;
  final PracticeEntryKind kind;
  final PracticeCourse course;

  bool get isPractice => kind != PracticeEntryKind.voiceRestDay;

  Map<String, Object?> toJson() => {
    'day': day.toIso(),
    'kind': kind.id,
    'course': course.id,
  };

  factory PracticeEntry.fromJson(Map<String, dynamic> json) {
    final kind = PracticeEntryKind.fromId(json['kind'] as String);
    final course = PracticeCourse.fromId(json['course'] as String);
    if (kind == PracticeEntryKind.voiceRestDay &&
        course != PracticeCourse.voice) {
      throw const FormatException('Rest days belong to the voice course');
    }
    return PracticeEntry(
      day: LocalDay.parse(json['day'] as String),
      kind: kind,
      course: course,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PracticeEntry &&
      other.day == day &&
      other.kind == kind &&
      other.course == course;

  @override
  int get hashCode => Object.hash(day, kind, course);
}

/// A goal applies from the week that contains [fromDay] onwards.
final class GoalChange {
  const GoalChange({required this.fromDay, required this.sessionsPerWeek});

  final LocalDay fromDay;
  final int sessionsPerWeek;

  Map<String, Object?> toJson() => {
    'from': fromDay.toIso(),
    'sessionsPerWeek': sessionsPerWeek,
  };

  factory GoalChange.fromJson(Map<String, dynamic> json) => GoalChange(
    fromDay: LocalDay.parse(json['from'] as String),
    sessionsPerWeek: json['sessionsPerWeek'] as int,
  );
}

final class WeeklyGoalRules {
  const WeeklyGoalRules({
    this.defaultSessionsPerWeek = 3,
    this.minSessionsPerWeek = 1,
    this.maxSessionsPerWeek = 7,
    this.initialFreezes = 2,
    this.metWeeksPerEarnedFreeze = 5,
    this.firstDayOfWeek = DateTime.monday,
  }) : assert(firstDayOfWeek >= DateTime.monday),
       assert(firstDayOfWeek <= DateTime.sunday);

  final int defaultSessionsPerWeek;
  final int minSessionsPerWeek, maxSessionsPerWeek;
  final int initialFreezes;
  final int metWeeksPerEarnedFreeze;
  final int firstDayOfWeek;

  bool isValidGoal(int sessions) =>
      sessions >= minSessionsPerWeek && sessions <= maxSessionsPerWeek;

  LocalDay weekStartOf(LocalDay day) =>
      day.addDays(-((day.weekday - firstDayOfWeek) % 7));
}

/// Minimum measured evidence for a practice-loop session to count.
/// Engineering choice, not fitted: one minute of listening with at least one
/// note the engine actually heard. "Could not hear" outcomes do not count.
const Duration kMinMeasuredPracticeDuration = Duration(seconds: 60);
const int kMinHeardPracticeEvents = 1;

/// What the measured practice loop reports when a session ends. The loop
/// owns the measurement; this layer only decides whether it counts.
final class MeasuredPracticeSession {
  const MeasuredPracticeSession({
    required this.course,
    required this.activeDuration,
    required this.heardEvents,
    this.lessonId,
  });

  final PracticeCourse course;

  /// Time the microphone was listening inside the practice screen.
  final Duration activeDuration;

  /// Notes/beats/chords with a measured result (any of the three states
  /// except "could not hear").
  final int heardEvents;
  final String? lessonId;
}

bool practiceSessionQualifies(MeasuredPracticeSession session) =>
    session.activeDuration >= kMinMeasuredPracticeDuration &&
    session.heardEvents >= kMinHeardPracticeEvents;

enum WeekOutcome {
  /// Before the first met week, or after a streak ended.
  inactive,
  met,

  /// Below goal; a freeze kept the streak.
  frozen,

  /// Below goal with no freeze left; the streak ended here.
  streakEnded,

  /// Current week, not met yet.
  inProgress,
}

final class WeekSummary {
  const WeekSummary({
    required this.start,
    required this.goal,
    required this.practiceDays,
    required this.restDaysCredited,
    required this.outcome,
  });

  final LocalDay start;
  final int goal;
  final int practiceDays;
  final int restDaysCredited;
  final WeekOutcome outcome;

  int get credit => practiceDays + restDaysCredited;
  bool get met => credit >= goal;
}

final class WeeklyGoalStatus {
  const WeeklyGoalStatus({
    required this.today,
    required this.weekStart,
    required this.goal,
    required this.practiceDays,
    required this.restDaysCredited,
    required this.practicedWeekdays,
    required this.streakActive,
    required this.streakWeeks,
    required this.freezesLeft,
    required this.metWeeksUntilNextFreeze,
    required this.weeks,
  });

  final LocalDay today;
  final LocalDay weekStart;

  /// Goal of the current week.
  final int goal;
  final int practiceDays;
  final int restDaysCredited;

  /// Offsets 0–6 from [weekStart] that have a practice entry.
  final Set<int> practicedWeekdays;
  final bool streakActive;

  /// Met weeks in the current streak, including the current week once met.
  final int streakWeeks;
  final int freezesLeft;
  final int metWeeksUntilNextFreeze;

  /// From the first week with an entry to the current week (oldest first).
  final List<WeekSummary> weeks;

  int get credit => practiceDays + restDaysCredited;
  bool get currentWeekMet => credit >= goal;
  int get daysLeftInWeek => 7 - (today.epochDay - weekStart.epochDay);
  bool get todayPracticed =>
      practicedWeekdays.contains(today.epochDay - weekStart.epochDay);
}

int goalForWeek(
  LocalDay weekStart,
  List<GoalChange> changes,
  WeeklyGoalRules rules,
) {
  var goal = rules.defaultSessionsPerWeek;
  var at = -1 << 40;
  for (final change in changes) {
    final from = rules.weekStartOf(change.fromDay).epochDay;
    // Later records win on ties: the last change in a week is the one kept.
    if (from <= weekStart.epochDay && from >= at) {
      at = from;
      goal = change.sessionsPerWeek;
    }
  }
  return goal;
}

WeeklyGoalStatus evaluateWeeklyGoal({
  required Iterable<PracticeEntry> entries,
  required LocalDay today,
  List<GoalChange> goalChanges = const [],
  WeeklyGoalRules rules = const WeeklyGoalRules(),
}) {
  final currentWeek = rules.weekStartOf(today);
  final practice = <int, Set<int>>{};
  final rest = <int, Set<int>>{};
  int? firstWeek;
  for (final entry in entries) {
    // Entries dated after today (clock changes) wait for their day.
    if (entry.day.epochDay > today.epochDay) continue;
    final week = rules.weekStartOf(entry.day).epochDay;
    (entry.isPractice ? practice : rest)
        .putIfAbsent(week, () => <int>{})
        .add(entry.day.epochDay);
    if (firstWeek == null || week < firstWeek) firstWeek = week;
  }

  WeekSummary summarize(int week, WeekOutcome Function(bool met) outcome) {
    final start = LocalDay.fromEpochDay(week);
    final goal = goalForWeek(start, goalChanges, rules);
    final days = practice[week] ?? const <int>{};
    final restOnly = (rest[week] ?? const <int>{}).difference(days).length;
    final credited = restOnly.clamp(0, goal > 0 ? goal - 1 : 0);
    final met = days.length + credited >= goal;
    return WeekSummary(
      start: start,
      goal: goal,
      practiceDays: days.length,
      restDaysCredited: credited,
      outcome: outcome(met),
    );
  }

  var active = false;
  var streak = 0;
  var freezes = rules.initialFreezes;
  final weeks = <WeekSummary>[];

  void countMet() {
    if (!active) {
      active = true;
      streak = 0;
      freezes = rules.initialFreezes;
    }
    streak++;
    if (rules.metWeeksPerEarnedFreeze > 0 &&
        streak % rules.metWeeksPerEarnedFreeze == 0) {
      freezes++;
    }
  }

  if (firstWeek != null) {
    for (var week = firstWeek; week <= currentWeek.epochDay; week += 7) {
      final isCurrent = week == currentWeek.epochDay;
      weeks.add(
        summarize(week, (met) {
          if (met) {
            countMet();
            return WeekOutcome.met;
          }
          if (isCurrent) return WeekOutcome.inProgress;
          if (!active) return WeekOutcome.inactive;
          if (freezes > 0) {
            freezes--;
            return WeekOutcome.frozen;
          }
          active = false;
          streak = 0;
          return WeekOutcome.streakEnded;
        }),
      );
    }
  }

  final current = weeks.isNotEmpty && weeks.last.start == currentWeek
      ? weeks.last
      : summarize(currentWeek.epochDay, (_) => WeekOutcome.inProgress);
  final practicedWeekdays = {
    for (final day in practice[currentWeek.epochDay] ?? const <int>{})
      day - currentWeek.epochDay,
  };
  final every = rules.metWeeksPerEarnedFreeze;
  return WeeklyGoalStatus(
    today: today,
    weekStart: currentWeek,
    goal: current.goal,
    practiceDays: current.practiceDays,
    restDaysCredited: current.restDaysCredited,
    practicedWeekdays: practicedWeekdays,
    streakActive: active,
    streakWeeks: active ? streak : 0,
    freezesLeft: active ? freezes : rules.initialFreezes,
    metWeeksUntilNextFreeze: every <= 0
        ? 0
        : every - ((active ? streak : 0) % every),
    weeks: List.unmodifiable(weeks),
  );
}
