// OST-UX-05c ölçüt 3: the suggestion line is a pure, deterministic function.
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/practice/loop/practice_progress_store.dart';
import 'package:ostinato/app/stage/stage_suggestion.dart';

V1PracticeRecord _rec({
  int runs = 1,
  double? heard,
  double? acc,
  bool passed = false,
  DateTime? at,
  String id = 'gtr-s1-m01-01',
}) => V1PracticeRecord(
  lessonId: id,
  runs: runs,
  bestHeard: heard,
  bestAccuracy: acc,
  lastRunAt: at,
  passedAt: passed ? DateTime.utc(2026, 11, 1) : null,
);

void main() {
  group('missFromRecord', () {
    test('no record / no run / passed -> none', () {
      expect(missFromRecord(null), StageMissKind.none);
      expect(missFromRecord(_rec(runs: 0, heard: .1)), StageMissKind.none);
      expect(
        missFromRecord(_rec(heard: .1, acc: .1, passed: true)),
        StageMissKind.none,
      );
    });
    test('low heard -> unheard; heard but low accuracy -> different', () {
      expect(missFromRecord(_rec(heard: .5, acc: .9)), StageMissKind.unheard);
      expect(
        missFromRecord(_rec(heard: .95, acc: .5)),
        StageMissKind.different,
      );
      expect(missFromRecord(_rec(heard: .95, acc: .9)), StageMissKind.none);
      expect(missFromRecord(_rec()), StageMissKind.none);
    });
    test('the record run last is the one read', () {
      final a = _rec(id: 'a', at: DateTime.utc(2026, 11, 1), heard: .1);
      final b = _rec(id: 'b', at: DateTime.utc(2026, 11, 2), heard: .99);
      expect(lastRunRecord([a, b])!.lessonId, 'b');
      expect(lastRunRecord([b, a])!.lessonId, 'b');
      expect(lastRunRecord([_rec(runs: 0)]), isNull);
    });
  });

  group('stageSuggestion', () {
    test('hidden without records or without a next lesson', () {
      expect(
        stageSuggestion(
          hasRecords: false,
          nextLessonId: 'x',
          miss: StageMissKind.unheard,
        ),
        isNull,
      );
      expect(
        stageSuggestion(
          hasRecords: true,
          nextLessonId: null,
          miss: StageMissKind.none,
        ),
        isNull,
      );
    });
    test('each miss kind maps to its own line; same input, same output', () {
      final seen = <StageSuggestionKind>{};
      for (final miss in StageMissKind.values) {
        final a = stageSuggestion(
          hasRecords: true,
          nextLessonId: 'gtr-s1-m02-01',
          miss: miss,
        );
        final b = stageSuggestion(
          hasRecords: true,
          nextLessonId: 'gtr-s1-m02-01',
          miss: miss,
        );
        expect(a, isNotNull);
        expect(a, b);
        expect(a!.lessonId, 'gtr-s1-m02-01');
        seen.add(a.kind);
      }
      expect(seen, hasLength(StageMissKind.values.length));
      expect(
        stageSuggestion(
          hasRecords: true,
          nextLessonId: 'gtr-s1-m02-01',
          miss: StageMissKind.none,
        )!.kind,
        StageSuggestionKind.pickUp,
      );
    });
  });
}
