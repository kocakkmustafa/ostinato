// Kulak kursu şarkı dersleri (Yönetim, seçenek a): görev metnindeki ekran
// sürümü ölçülen yoldur; şarkı öz-kontrol kalır ve metin bunu söyler.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/curriculum/v1_lesson.dart';
import 'package:ostinato/app/drill/drill_copy.dart';
import 'package:ostinato/app/drill/drill_generator.dart';
import 'package:ostinato/app/drill/drill_screen.dart';
import 'package:ostinato/app/practice/loop/practice_progress_store.dart';
import 'package:ostinato/app/practice/loop/v1_course_catalog.dart';
import 'package:ostinato/app/practice/loop/v1_lesson_reader_screen.dart';

import 'support/practice_host.dart';

V1Lesson ear(String id) => V1Lesson.fromJson(
  jsonDecode(File('content/v1/ear/$id.json').readAsStringSync()),
);

V1CourseLesson course(V1Lesson l) {
  final (availability, reason) = V1CourseCatalog.classify(l);
  return V1CourseLesson(
    lesson: l,
    availability: availability,
    reason: reason,
    unitId: 'ear-s1-m02',
  );
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
  const withAlternative = {
    'ear-s1-m02-04',
    'ear-s1-m02-05',
    'ear-s1-m02-06',
    'ear-s2-m05-02',
    'ear-s2-m06-03',
    'ear-s2-m06-04',
    'ear-s2-m08-02',
  };

  test('singing lessons carry the on-screen version their task names', () {
    final found = <String>{};
    for (final f in Directory('content/v1/ear').listSync()) {
      if (f is! File || !f.path.endsWith('.json')) continue;
      final l = V1Lesson.fromJson(jsonDecode(f.readAsStringSync()));
      final alt = l.practice.alternative;
      if (alt == null) continue;
      found.add(l.id);
      expect(l.practice.engineSteps, contains('A5'), reason: l.id);
      expect(supportsDrill(alt.drill), isTrue, reason: l.id);
      expect(generateDrill(alt.drill, seed: 1), hasLength(alt.drill.count));
      expect(alt.source, startsWith('Görev metni:'), reason: l.id);
      // The task really offers that on-screen version.
      expect(l.practice.task.en, contains("rather not sing"), reason: l.id);
    }
    expect(found, withAlternative);
  });

  test('an alternative needs a singing step', () {
    final body =
        jsonDecode(File('content/v1/ear/ear-s1-m02-04.json').readAsStringSync())
            as Map<String, dynamic>;
    (body['practice'] as Map<String, dynamic>)['engineSteps'] = ['A3'];
    expect(() => V1Lesson.fromJson(body), throwsFormatException);
  });

  testWidgets('reader: honest banner; passing the on-screen version counts', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final l = course(ear('ear-s2-m06-03'));
    expect(l.availability, V1LessonAvailability.selfCheck);
    final checks = _Checks();
    await tester.pumpWidget(
      practiceHost(V1LessonReaderScreen(lesson: l, checks: checks)),
    );
    await tester.pumpAndSettle();
    expect(find.text(DrillCopy.bannerSingingAlternative.$1), findsOneWidget);
    final start = find.byKey(const Key('v1-reader-drill'));
    await tester.ensureVisible(start);
    await tester.tap(start);
    await tester.pumpAndSettle();
    final session = tester
        .state<DrillScreenState>(find.byType(DrillScreen))
        .session;
    while (!session.finished) {
      final key = Key('drill-option-${session.current.answer}');
      await tester.ensureVisible(find.byKey(key));
      await tester.tap(find.byKey(key));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('drill-next')));
      await tester.tap(find.byKey(const Key('drill-next')));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byKey(const Key('drill-back')));
    await tester.pumpAndSettle();
    expect(checks.checks[l.id]!.evidence, V1CheckEvidence.drillPass);
  });

  test('a passed drill shows as such on a held checkpoint too', () {
    final l = course(ear('ear-s1-m02-07'));
    expect(l.availability, V1LessonAvailability.held);
    final catalog = V1CourseCatalog(const []);
    final state = V1CourseState(catalog, const {}, {
      l.id: V1LessonCheck(
        lessonId: l.id,
        evidence: V1CheckEvidence.drillPass,
        at: DateTime.utc(2026),
      ),
    });
    expect(state.status(l), V1LessonStatus.drillPassed);
  });
}
