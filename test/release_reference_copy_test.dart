import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/app_locale.dart';
import 'package:ostinato/app/catalog_copy_tr.dart';
import 'package:ostinato/app/content.dart';
import 'package:ostinato/app/cue_text.dart';
import 'package:ostinato/app/design/app_scope.dart';
import 'package:ostinato/app/design/ostinato_theme.dart';
import 'package:ostinato/app/design/widgets.dart';
import 'package:ostinato/app/onboarding_store.dart';
import 'package:ostinato/app/screens/course_screen.dart';
import 'package:ostinato/app/screens/instrument_screen.dart';
import 'package:ostinato/app/screens/lesson_demo_screen.dart';
import 'package:ostinato/app/screens/onboarding_screen.dart';
import 'package:ostinato/app/ostinato_release_policy.dart';

import 'support/localized_widget_ready.dart';

// Keep the framework's own error handler. Extra diagnostics make a failed
// phase identify its RenderFlex creator instead of hiding it behind takeException.
List<String> _watchFrameworkErrors() {
  final diagnostics = <String>[];
  final previous = FlutterError.onError!;
  FlutterError.onError = (details) {
    final text = StringBuffer()..writeln(details.exceptionAsString());
    if (details.context != null) text.writeln(details.context!.toDescription());
    final collector = details.informationCollector;
    if (collector != null) {
      for (final node in collector()) {
        text.writeln(node.toStringDeep());
      }
    }
    diagnostics.add(text.toString());
    previous(details);
  };
  addTearDown(() => FlutterError.onError = previous);
  return diagnostics;
}

void _expectNoFrameworkError(
  WidgetTester tester,
  List<String> diagnostics,
  String phase,
) {
  expect(tester.takeException(), isNull,
      reason: '$phase\n${diagnostics.join("\n")}');
  diagnostics.clear();
}

void main() {
  late ContentRepository repo;
  late CueTextResolver cues;
  setUpAll(() async {
    repo = await ContentRepository.load();
    cues = await CueTextResolver.load();
  });
  for (final language in ['en', 'tr']) {
    Widget host(Widget child, {double textScale = 1}) => ContentRepositoryScope(
      repo: repo,
      cueText: cues,
      child: MaterialApp(
        theme: ostinatoTheme(),
        locale: Locale(language),
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationsDelegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
          ),
          child: child!,
        ),
        home: child,
      ),
    );
    testWidgets(
      'scope labels reference previews, not user measurements ($language)',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(375, 812));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          host(
            OnboardingScreen(
              repo: repo,
              store: InMemoryOnboardingStore(),
              onFinished: () {},
            ),
          ),
        );
        await waitForLocalizedFixture(tester,
          languageTag: language,
          anchor: find.byType(OnboardingScreen),
          reason: 'Onboarding must publish its actual packaged translations',
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('onboarding-primary')));
        await tester.pumpAndSettle();
        // v1 (2026-11-01): the scope step lists what the app has today;
        // the legacy posture-preview counts are gone.
        final written = find.descendant(
          of: find.byKey(const Key('onboarding-fact-written')),
          matching: find.byType(Text),
        );
        final copy = tester
            .widgetList<Text>(written)
            .map((w) => w.data ?? '')
            .join(' ');
        // v1 store build: the pre-v1 written lessons are not linked, so
        // the scope step does not list them.
        expect(
          copy,
          ostinatoLegacyWrittenCoursesVisible
              ? contains(language == 'tr' ? '60 derslik' : '60-lesson')
              : isEmpty,
        );
        expect(find.byKey(const Key('onboarding-fact-demo')), findsNothing);
        expect(copy, isNot(contains('are measured but never graded')));
        expect(copy, isNot(contains('ders ölçülür ama puanlanmaz')));
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      'normal demo routes show static references with no user marker ($language)',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 812));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final diagnostics = _watchFrameworkErrors();
        final tr = language == 'tr';
        final firstSentence = tr
            ? 'Yalnız kayıtlı eğitmen referansları; bu sürümde kamera değerlendirmesi kapalıdır.'
            : 'Recorded teacher references only; camera assessment is disabled in this release.';
        var opened = 0;
        for (final discipline in repo.disciplines) {
          final demos = discipline.lessons.where(
            (lesson) => lesson.kind == LessonKind.demoOnly,
          );
          for (final lesson in demos) {
            final course = discipline.courses.singleWhere(
              (course) => course.lessons.any((entry) => entry.id == lesson.id),
            );
            for (final textScale in [1.0, 2.0]) {
              await tester.pumpWidget(
                host(
                  CourseScreenRoute(discipline: discipline, course: course),
                  textScale: textScale,
                ),
              );
              await waitForLocalizedFixture(tester,
                languageTag: language,
                anchor: find.byKey(Key('lesson-${lesson.id}')),
                reason: 'Course ${lesson.id} must render before reading its copy',
              );
              await tester.pumpAndSettle();
              final row = find.byKey(Key('lesson-${lesson.id}'));
              final rowCopy = tester
                  .widgetList<RichText>(
                    find.descendant(of: row, matching: find.byType(RichText)),
                  )
                  .map((widget) => widget.text.toPlainText())
                  .join(' ');
              expect(rowCopy, contains(firstSentence));
              expect(rowCopy, isNot(contains('your own trunk')));
              expect(rowCopy, isNot(contains('gövdenizin çizimiyle')));
              _expectNoFrameworkError(tester, diagnostics,
                  'Course ${lesson.id} ($language) at 320px/${textScale}x');
            }
            final row = find.byKey(Key('lesson-${lesson.id}'));
            await tester.ensureVisible(row);
            await tester.tap(row);
            await tester.pumpAndSettle();
            expect(find.byType(LessonDemoScreenRoute), findsOneWidget);
            _expectNoFrameworkError(tester, diagnostics,
                'Demo ${lesson.id} ($language) immediately after route push');
            final reason = find.byKey(const Key('demo-reason'));
            expect(tester.widget<Text>(reason).data, contains(firstSentence));

            // Call the production reader in the rendered route's locale. Old
            // release copy must never conceal a changed or unknown source.
            final context = tester.element(reason);
            final fields = <String, String>{
              'demoOnlyReason': lesson.demoOnlyReason!,
              'ifItStaysBlocked': lesson.ifBlockedStaysBlocked!,
            };
            for (final field in fields.entries) {
              final key = '${lesson.id}.${field.key}';
              final copy = catalogCopy(context, key, field.value);
              expect(copy, isNot(field.value));
              expect(copy, contains(tr ? 'referans' : 'reference'));
              expect(find.text(copy), findsOneWidget);
              expect(
                catalogCopy(context, key, '${field.value} changed'),
                '${field.value} changed',
              );
              expect(
                catalogCopy(context, 'unreviewed.$key', field.value),
                field.value,
              );
            }
            final courseBack = find.byType(GlassIconButton).last;
            await tester.ensureVisible(courseBack);
            await tester.pumpAndSettle();
            await tester.tapAt(
              tester.getTopLeft(courseBack) + const Offset(1, 24),
            );
            await tester.pumpAndSettle();
            expect(find.byType(CourseScreenRoute), findsOneWidget);
            expect(find.byType(LessonDemoScreenRoute), findsNothing);
            _expectNoFrameworkError(tester, diagnostics,
                'Demo ${lesson.id} ($language) return to course');

            await tester.pumpWidget(
              host(
                Builder(
                  key: ValueKey(lesson.id),
                  builder: (context) => Scaffold(
                    body: TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => lessonScreenFor(
                            discipline: discipline,
                            lesson: lesson,
                            hue: InstrumentHues.of(discipline.id),
                          ),
                        ),
                      ),
                      child: const Text('Open test reference'),
                    ),
                  ),
                ),
                textScale: 2,
              ),
            );
            await waitForLocalizedFixture(tester,
              languageTag: language,
              anchor: find.text('Open test reference'),
              reason: 'The direct demo fixture must render before a real tap',
            );
            await tester.tap(find.text('Open test reference'));
            await tester.pumpAndSettle();
            expect(find.byType(LessonDemoScreenRoute), findsOneWidget);
            _expectNoFrameworkError(tester, diagnostics,
                'Demo ${lesson.id} ($language) immediately after route push');
            opened++;
            expect(
              tester
                  .widget<Text>(find.byKey(const Key('state-lesson-demo')))
                  .data,
              tr ? 'REFERANS · PUAN YOK' : 'REFERENCE · NO SCORING',
            );
            final note = tester.widget<Text>(
              find.byKey(const Key('demo-live-gap-note')),
            ).data!;
            expect(
              note,
              contains(
                tr
                    ? 'Bu sürümde kamera değerlendirmesi kapalıdır'
                    : 'Camera assessment is disabled in this release',
              ),
            );
            final text = tester
                .widgetList<Text>(
                  find.descendant(
                    of: find.byType(LessonDemoScreenRoute),
                    matching: find.byType(Text),
                  ),
                )
                .map((widget) => widget.data ?? '')
                .join(' ');
            for (final staleClaim in [
              'MEASURED · NOT MARKED',
              'ÖLÇÜM · PUAN YOK',
              'only trunk posture measures live today',
              'yalnız gövde duruşu ölçülür',
              'your own trunk',
              'gövdenizin çizimiyle',
              'measurement shown, no mark',
              'ölçüm gösterilir, puan verilmez',
              'when this is live',
              'Canlı ölçüm olduğunda',
            ]) {
              expect(text, isNot(contains(staleClaim)));
            }
            final range = tester.widget<HorizontalBandTrack>(
              find.byType(HorizontalBandTrack),
            );
            expect(range.youDeg, isNull);
            expect(find.byKey(const Key('you-marker')), findsNothing);
            for (final key in ['demo-scale-min', 'demo-range-value', 'demo-scale-max']) {
              final label = find.byKey(Key(key));
              expect(label, findsOneWidget);
              final bounds = tester.getRect(label);
              expect(bounds.left, greaterThanOrEqualTo(0));
              expect(bounds.right, lessThanOrEqualTo(320));
              expect(tester.widget<Text>(label).maxLines, isNull);
              expect(Directionality.of(tester.element(label)), TextDirection.ltr);
            }
            _expectNoFrameworkError(tester, diagnostics,
                'Demo ${lesson.id} ($language) reference legend at 320px/2x');
            final back = find.byType(GlassIconButton);
            await tester.ensureVisible(back);
            await tester.pumpAndSettle();
            await tester.tapAt(tester.getTopLeft(back) + const Offset(1, 24));
            await tester.pumpAndSettle();
            expect(find.text('Open test reference'), findsOneWidget);
            expect(find.byType(LessonDemoScreenRoute), findsNothing);
          }
        }
        expect(opened, greaterThan(0));
      },
    );
    testWidgets(
      'guitar footer keeps historical evidence and release closure ($language)',
      (tester) async {
        final guitar = repo.disciplines.singleWhere((d) => d.id == 'guitar');
        await tester.pumpWidget(
          host(InstrumentScreenRoute(discipline: guitar)),
        );
        await waitForLocalizedFixture(tester,
          languageTag: language,
          anchor: find.byType(InstrumentScreenRoute),
          reason: 'Instrument footer must render its packaged translations',
        );
        await tester.pumpAndSettle();
        final claim = find.textContaining(
          language == 'tr'
              ? 'Bunlar kaydedilmiş eğitmen referanslarının tarihsel bulgularıdır'
              : 'These are historical findings from recorded teacher references',
        );
        expect(claim, findsOneWidget);
        await tester.ensureVisible(claim);
        await tester.pumpAndSettle();
        final copy = tester.widget<Text>(claim).data!;
        expect(
          copy,
          contains(language == 'tr' ? '39–105°' : '39 to 105 degrees'),
        );
        expect(
          copy,
          contains(language == 'tr' ? 'sağ ve sol kol' : 'side identity'),
        );
        expect(
          copy,
          contains(
            language == 'tr'
                ? 'Bu sürüm duruşunuzu ölçmez veya puanlamaz'
                : 'This release does not measure or grade your posture',
          ),
        );
        expect(copy, isNot(contains('trunk angle we do grade')));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
