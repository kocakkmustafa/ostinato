// Store review 2026-11-02 (screens 63, 85): the lesson reader passed a {v0}
// value to every banner, but only the tuner banner has {v0}. The catalog's
// placeholder check then fell back to English in the 12 other languages.
// Every banner must render its own translation.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/app_locale.dart';
import 'package:ostinato/app/app_translation_catalog.dart';
import 'package:ostinato/app/app_message_ids.dart';
import 'package:ostinato/app/curriculum/v1_lesson.dart';
import 'package:ostinato/app/practice/loop/practice_progress_store.dart';
import 'package:ostinato/app/practice/loop/v1_course_catalog.dart';
import 'package:ostinato/app/practice/loop/v1_course_copy.dart';
import 'package:ostinato/app/practice/loop/v1_lesson_reader_screen.dart';
import 'package:ostinato/app/ui_copy.dart';

import 'support/localized_widget_ready.dart';

final class _NoChecks implements V1LessonChecks {
  @override
  Future<Map<String, V1LessonCheck>> load() async => const {};
  @override
  Future<V1LessonCheck> record(
    String lessonId,
    V1CheckEvidence evidence, {
    DateTime? at,
  }) async => V1LessonCheck(
    lessonId: lessonId,
    evidence: evidence,
    at: at ?? DateTime.utc(2026, 11, 2),
  );
}

List<V1Lesson> _bundled() => [
  for (final f in Directory('content/v1/gtr').listSync())
    if (f is File && f.path.endsWith('.json'))
      V1Lesson.fromJson(jsonDecode(f.readAsStringSync())),
];

Map<String, dynamic> _catalog(String tag) =>
    (jsonDecode(File('assets/l10n/$tag.json').readAsStringSync())
            as Map<String, dynamic>)['messages']
        as Map<String, dynamic>;

const _banners = <V1LessonAvailability, UiCopy>{
  V1LessonAvailability.selfCheck: V1CourseCopy.bannerSelfCheck,
  V1LessonAvailability.selfCheckLesson: V1CourseCopy.bannerSelfCheckLesson,
  V1LessonAvailability.camera: V1CourseCopy.bannerCamera,
  V1LessonAvailability.drillSoon: V1CourseCopy.bannerDrill,
  V1LessonAvailability.held: V1CourseCopy.bannerHeld,
  V1LessonAvailability.tuner: V1CourseCopy.bannerTuner,
};

void main() {
  setUpAll(prepareRootTranslations);
  final course = V1CourseCatalog(_bundled());

  for (final tag in ['de', 'ar']) {
    final messages = _catalog(tag);
    for (final MapEntry(key: availability, value: banner) in _banners.entries) {
      testWidgets('${availability.name} banner is translated ($tag)', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(800, 4000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final lesson = course.lessons.firstWhere(
          (l) => l.availability == availability,
        );
        await tester.pumpWidget(
          MaterialApp(
            locale: localeForLanguageTag(tag),
            supportedLocales: appSupportedLocales,
            localizationsDelegates: appLocalizationsDelegates,
            home: V1LessonReaderScreen(lesson: lesson, checks: _NoChecks()),
          ),
        );
        await tester.pumpAndSettle();
        final shown = tester
            .widget<Text>(
              find
                  .descendant(
                    of: find.byKey(const Key('v1-reader-banner')),
                    matching: find.byType(Text),
                  )
                  .first,
            )
            .data!;
        final expected = messages[appMessageIds[banner]] as String;
        if (banner == V1CourseCopy.bannerTuner) {
          // The tolerance is formatted for the locale; the words around it
          // come from the catalog.
          final parts = expected.split('{v0}');
          expect(parts, hasLength(2));
          expect(shown, startsWith(parts.first));
          expect(shown, endsWith(parts.last));
          expect(shown, isNot(contains('{v0}')));
        } else {
          expect(shown, expected);
        }
        expect(shown, isNot(banner.$1), reason: 'English fallback');
      });
    }
  }
}
