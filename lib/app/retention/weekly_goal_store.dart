import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../account_data_directory.dart';
import '../account_data_operations.dart';
import 'weekly_goal.dart';

/// The seam the measured practice loop (F2.2–F2.5) calls when a session
/// ends. The loop owns measurement; the receiver only decides whether the
/// session counts toward the weekly goal ([practiceSessionQualifies]).
abstract interface class PracticeSessionRecorder {
  Future<PracticeRecordResult> recordPracticeSession(
    MeasuredPracticeSession session,
  );
}

final class PracticeRecordResult {
  const PracticeRecordResult({required this.counted, required this.status});

  /// False when the session was below the measured minimum.
  final bool counted;
  final WeeklyGoalStatus status;
}

final class WeeklyGoalData {
  const WeeklyGoalData({
    this.entries = const <PracticeEntry>{},
    this.goalChanges = const <GoalChange>[],
  });

  final Set<PracticeEntry> entries;
  final List<GoalChange> goalChanges;

  static const int schemaVersion = 1;

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'goalChanges': [for (final c in goalChanges) c.toJson()],
    'entries': [for (final e in entries) e.toJson()],
  };

  factory WeeklyGoalData.fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] != schemaVersion) {
      throw const FormatException('Unsupported weekly goal schema');
    }
    return WeeklyGoalData(
      entries: {
        for (final e in json['entries'] as List<dynamic>)
          PracticeEntry.fromJson(e as Map<String, dynamic>),
      },
      goalChanges: [
        for (final c in json['goalChanges'] as List<dynamic>)
          GoalChange.fromJson(c as Map<String, dynamic>),
      ],
    );
  }
}

/// Local weekly goal file (`weekly_goal.v1.json`) under the account
/// directory. Stores only day, entry kind and course: no lesson text, no
/// audio, no measurement values. Never sent to Motion Core or the network;
/// deleted with the local account directory.
final class WeeklyGoalStore implements PracticeSessionRecorder {
  WeeklyGoalStore({
    this.accountUserId,
    this.directoryProvider,
    LocalClock? clock,
    this.rules = const WeeklyGoalRules(),
  }) : _clock = clock ?? systemLocalNow,
       _operations = AccountDataOperations(() async {
         final root =
             await (directoryProvider ?? getApplicationSupportDirectory)();
         return accountDataDirectory(root, accountUserId);
       });

  final String? accountUserId;
  final Future<Directory> Function()? directoryProvider;
  final WeeklyGoalRules rules;
  final LocalClock _clock;
  final AccountDataOperations _operations;

  /// Bumped after every successful write so on-screen cards can reload.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static const String fileName = 'weekly_goal.v1.json';

  Future<T> _run<T>(Future<T> Function(File file) op, {bool writing = false}) =>
      _operations.run(
        (directory) => op(File('${directory.path}/$fileName')),
        writing: writing,
      );

  WeeklyGoalStatus evaluate(WeeklyGoalData data) => evaluateWeeklyGoal(
    entries: data.entries,
    goalChanges: data.goalChanges,
    today: _clock().day,
    rules: rules,
  );

  Future<WeeklyGoalData> loadData() => _run(_read);

  Future<WeeklyGoalStatus> load() async => evaluate(await loadData());

  Future<WeeklyGoalData> _read(File file) async {
    if (!await file.exists()) return const WeeklyGoalData();
    return WeeklyGoalData.fromJson(
      jsonDecode(await file.readAsString()) as Map<String, dynamic>,
    );
  }

  Future<WeeklyGoalStatus> _update(
    WeeklyGoalData Function(WeeklyGoalData old, LocalDay today) change,
  ) async {
    final status = await _run((file) async {
      final next = change(await _read(file), _clock().day);
      await file.parent.create(recursive: true);
      final temp = File('${file.path}.tmp');
      await temp.writeAsString('${jsonEncode(next.toJson())}\n', flush: true);
      await temp.rename(file.path);
      return evaluate(next);
    }, writing: true);
    revision.value++;
    return status;
  }

  Future<WeeklyGoalStatus> _add(PracticeEntryKind kind, PracticeCourse course) =>
      _update(
        (old, today) => WeeklyGoalData(
          entries: {
            ...old.entries,
            PracticeEntry(day: today, kind: kind, course: course),
          },
          goalChanges: old.goalChanges,
        ),
      );

  @override
  Future<PracticeRecordResult> recordPracticeSession(
    MeasuredPracticeSession session,
  ) async {
    if (!practiceSessionQualifies(session)) {
      return PracticeRecordResult(counted: false, status: await load());
    }
    return PracticeRecordResult(
      counted: true,
      status: await _add(PracticeEntryKind.measuredSession, session.course),
    );
  }

  /// Existing lesson events: guitar "I practised", a finished camera session.
  Future<WeeklyGoalStatus> recordLessonPractice(PracticeCourse course) =>
      _add(PracticeEntryKind.lessonPractice, course);

  Future<WeeklyGoalStatus> recordOffAppPractice({
    PracticeCourse course = PracticeCourse.other,
  }) => _add(PracticeEntryKind.offApp, course);

  Future<WeeklyGoalStatus> recordVoiceRestDay() =>
      _add(PracticeEntryKind.voiceRestDay, PracticeCourse.voice);

  Future<WeeklyGoalStatus> setGoal(int sessionsPerWeek) {
    if (!rules.isValidGoal(sessionsPerWeek)) {
      throw ArgumentError.value(sessionsPerWeek, 'sessionsPerWeek');
    }
    return _update(
      (old, today) => WeeklyGoalData(
        entries: old.entries,
        goalChanges: [
          // One record per week: the latest choice replaces earlier ones.
          for (final c in old.goalChanges)
            if (rules.weekStartOf(c.fromDay) != rules.weekStartOf(today)) c,
          GoalChange(fromDay: today, sessionsPerWeek: sessionsPerWeek),
        ],
      ),
    );
  }
}

/// Fire-and-forget hook for existing lesson events. A failed write must not
/// interrupt the lesson; the weekly card simply shows the older state.
void recordLessonPracticeInBackground(
  WeeklyGoalStore store,
  PracticeCourse course,
) {
  store.recordLessonPractice(course).then<void>((_) {}, onError: (_) {});
}
