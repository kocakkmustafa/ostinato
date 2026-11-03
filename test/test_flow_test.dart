// Test akışı (Yönetim onayı): bölüm bölüm; yalnız geçilemeyen bölüm
// tekrarlanır; ilerleme yerelde kalır ve kaldığı yerden devam eder; şarkı
// bölümü "öz-kontrol" etiketiyle görünür ve sonucu belirlemez.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/curriculum/v1_lesson.dart';
import 'package:ostinato/app/drill/drill_generator.dart';
import 'package:ostinato/app/practice/loop/practice_progress_store.dart';
import 'package:ostinato/app/practice/loop/v1_course_catalog.dart';
import 'package:ostinato/app/practice/loop/v1_practice_catalog.dart';
import 'package:ostinato/app/test_flow/test_flow_copy.dart';
import 'package:ostinato/app/test_flow/test_flow_screen.dart';
import 'package:ostinato/app/test_flow/test_flow_store.dart';

import 'support/practice_host.dart';

Map<String, dynamic> raw(String id) =>
    jsonDecode(File('content/v1/ear/$id.json').readAsStringSync())
        as Map<String, dynamic>;
V1Lesson ear(String id) => V1Lesson.fromJson(raw(id));

final class _MemoryFlow implements TestFlowProgress {
  final Map<String, Map<int, TestSectionResult>> data = {};
  @override
  Future<Map<int, TestSectionResult>> load(String lessonId) async =>
      Map.of(data[lessonId] ?? {});
  @override
  Future<TestSectionResult> record(
    String lessonId,
    int index, {
    required bool passed,
    DateTime? at,
  }) async {
    final m = data[lessonId] ??= {};
    return m[index] = mergeSectionResult(
      m[index],
      TestSectionResult(index: index, passed: passed, at: DateTime.utc(2026)),
    );
  }
}

final class _Checks implements V1LessonChecks {
  final Map<String, V1LessonCheck> checks = {};
  @override
  Future<Map<String, V1LessonCheck>> load() async => Map.of(checks);
  @override
  Future<V1LessonCheck> record(
    String lessonId,
    V1CheckEvidence evidence, {
    DateTime? at,
  }) async => checks[lessonId] = mergeLessonCheck(
    checks[lessonId],
    V1LessonCheck(
      lessonId: lessonId,
      evidence: evidence,
      at: DateTime.utc(2026),
    ),
  );
}

void main() {
  test('the three ear tests carry sections; parts run on existing paths', () {
    for (final id in ['ear-s1-test', 'ear-s2-test', 'ear-s2-m08-06']) {
      final l = ear(id);
      final parts = l.practice.sections;
      expect(parts, isNotEmpty, reason: id);
      expect(l.practice.measurement, contains('M!'));
      for (final p in parts) {
        expect(p.source, startsWith('Görev metni'), reason: id);
        switch (p.kind) {
          case V1SectionKind.drill:
            expect(
              supportsDrill(p.drill!),
              isTrue,
              reason: '$id ${p.title.en}',
            );
          case V1SectionKind.clap:
            final lesson = l.forSection(p);
            expect(V1PracticeCatalog.isPracticable(lesson), isTrue);
            expect(V1PracticeCatalog.scoreOf(lesson)!.isRhythmOnly, isTrue);
          case V1SectionKind.selfCheck:
            // Singing never decides a test.
            expect(p.required, isFalse, reason: id);
        }
      }
      expect(parts.where((p) => p.kind == V1SectionKind.selfCheck), isNotEmpty);
    }
  });

  test('sections: only on checkpoints; a self-check cannot be required', () {
    final body = raw('ear-s1-test');
    final practice = body['practice'] as Map<String, dynamic>;
    final sections = practice['sections'] as List<dynamic>;
    final selfCheck =
        sections.firstWhere((s) => s['kind'] == 'selfCheck')
            as Map<String, dynamic>;
    selfCheck['required'] = true;
    expect(() => V1Lesson.fromJson(body), throwsFormatException);
    selfCheck['required'] = false;
    practice['measurement'] = ['M'];
    expect(() => V1Lesson.fromJson(body), throwsFormatException);
  });

  test('store: a pass sticks; results survive a restart', () async {
    final dir = Directory.systemTemp.createTempSync('test_flow');
    addTearDown(() => dir.deleteSync(recursive: true));
    TestFlowStore store() => TestFlowStore(directoryProvider: () async => dir);
    await store().record('ear-s1-test', 0, passed: false);
    await store().record('ear-s1-test', 0, passed: true);
    await store().record('ear-s1-test', 0, passed: false);
    await store().record('ear-s1-test', 2, passed: false);
    final r = await store().load('ear-s1-test');
    expect(r[0]!.passed, isTrue);
    expect(r[2]!.passed, isFalse);
    expect(await store().load('ear-s2-test'), isEmpty);
  });

  testWidgets('flow: continue, repeat only the failed part, pass, resume', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final lesson = ear('ear-s2-m08-06');
    final parts = lesson.practice.sections;
    final flow = _MemoryFlow();
    final checks = _Checks();
    final ran = <int>[];
    var failNext = true;
    Widget screen() => practiceHost(
      TestFlowScreen(
        lesson: lesson,
        store: flow,
        checks: checks,
        runPart: (context, part) async {
          ran.add(parts.indexOf(part));
          if (part.kind == V1SectionKind.selfCheck) return true;
          final pass = !failNext;
          failNext = false;
          return pass;
        },
      ),
    );
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();
    // The singing part is labelled and is not "to do".
    final singing = parts.indexWhere((p) => p.kind == V1SectionKind.selfCheck);
    expect(
      tester.widget<Text>(find.byKey(Key('test-flow-status-$singing'))).data,
      TestFlowCopy.partSelfCheck.$1,
    );
    // First required part fails, then only it is repeated.
    await tester.tap(find.byKey(const Key('test-flow-continue')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const Key('test-flow-status-0'))).data,
      TestFlowCopy.partNotYet.$1,
    );
    await tester.tap(find.byKey(const Key('test-flow-continue')));
    await tester.pumpAndSettle();
    expect(ran, [0, 0]);
    // Leave and come back: the flow resumes at part 1.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const Key('test-flow-status-0'))).data,
      TestFlowCopy.partPassed.$1,
    );
    final required = [
      for (var i = 0; i < parts.length; i++)
        if (parts[i].required) i,
    ];
    while (find.byKey(const Key('test-flow-continue')).evaluate().isNotEmpty) {
      await tester.tap(find.byKey(const Key('test-flow-continue')));
      await tester.pumpAndSettle();
    }
    expect(ran, [0, 0, ...required.skip(1)]);
    expect(ran, isNot(contains(singing)));
    expect(find.text(TestFlowCopy.resultPassed.$1), findsOneWidget);
    expect(checks.checks[lesson.id]!.evidence, V1CheckEvidence.testPass);
  });

  test('a passed test is measured for the gate and listed as passed', () {
    final l = ear('ear-s1-test');
    final (availability, reason) = V1CourseCatalog.classify(l);
    final course = V1CourseLesson(
      lesson: l,
      availability: availability,
      reason: reason,
      unitId: 'ear-s1-test',
    );
    final state = V1CourseState(V1CourseCatalog(const []), const {}, {
      l.id: V1LessonCheck(
        lessonId: l.id,
        evidence: V1CheckEvidence.testPass,
        at: DateTime.utc(2026),
      ),
    });
    expect(state.status(course), V1LessonStatus.testPassed);
    expect(state.gateClear(course), V1GateClear.measured);
    expect(
      mergeLessonCheck(
        V1LessonCheck(
          lessonId: l.id,
          evidence: V1CheckEvidence.selfReport,
          at: DateTime.utc(2026),
        ),
        V1LessonCheck(
          lessonId: l.id,
          evidence: V1CheckEvidence.testPass,
          at: DateTime.utc(2026),
        ),
      ).evidence,
      V1CheckEvidence.testPass,
    );
  });
}
