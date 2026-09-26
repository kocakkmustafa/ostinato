import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/app_locale.dart';
import 'package:ostinato/app/catalog_copy_tr.dart';
import 'package:ostinato/app/content.dart';
import 'package:ostinato/app/cue_text.dart';
import 'package:ostinato/app/design/app_scope.dart';
import 'package:ostinato/app/design/ostinato_theme.dart';
import 'package:ostinato/app/onboarding_store.dart';
import 'package:ostinato/app/screens/onboarding_screen.dart';
import 'package:ostinato/app/screens/course_screen.dart';
import 'package:ostinato/app/screens/instrument_screen.dart';
import 'package:ostinato/app/screens/library_screen.dart';
import 'package:ostinato/app/screens/lesson_scored_screen.dart';
import 'package:ostinato/app/screens/lesson_demo_screen.dart';
import 'package:ostinato/app/screens/lesson_locked_screen.dart';
import 'package:ostinato/app/screens/review_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ContentRepository repo;
  late CueTextResolver cueText;
  setUpAll(() async {
    repo = await ContentRepository.load();
    cueText = await CueTextResolver.load();
  });

  testWidgets('Turkish library cards show translated descriptions and labels', (
    tester,
  ) async {
    await tester.pumpWidget(
      ContentRepositoryScope(
        repo: repo,
        cueText: cueText,
        child: MaterialApp(
          locale: const Locale('tr'),
          supportedLocales: appSupportedLocales,
          localizationsDelegates: appLocalizationsDelegates,
          home: LibraryScreen(repo: repo, cueText: cueText),
        ),
      ),
    );
    expect(find.textContaining('guitar teachers'), findsNothing);
    expect(find.textContaining('gitar eğitmeni'), findsOneWidget);
    expect(
      find.textContaining('Put your phone where it can see you sitting'),
      findsNothing,
    );
    expect(
      find.textContaining('Telefonu gitarınızla oturuşunuzu'),
      findsOneWidget,
    );
    expect(find.textContaining('GİTAR · REHBER'), findsOneWidget);
  });

  testWidgets('Turkish onboarding uses translated claims and controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('tr'),
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationsDelegates,
        home: OnboardingScreen(
          repo: repo,
          store: InMemoryOnboardingStore(),
          onFinished: () {},
        ),
      ),
    );
    expect(find.text('Gitar çalışmanı geliştir.'), findsOneWidget);
    expect(find.text('Devam et'), findsOneWidget);
    await tester.tap(find.byKey(const Key('onboarding-primary')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding-primary')));
    await tester.pumpAndSettle();
    expect(find.text('Hangi izni isteyeceğiz?'), findsOneWidget);
  });

  testWidgets('every live catalog title has a Turkish display label', (
    tester,
  ) async {
    late List<String> missing;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('tr'),
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationsDelegates,
        home: Builder(
          builder: (context) {
            final ids = <String>[
              for (final discipline in repo.disciplines)
                if (discipline.status == 'live') ...<String>[
                  discipline.id,
                  for (final course in discipline.courses) ...<String>[
                    course.id,
                    for (final lesson in course.lessons) lesson.id,
                  ],
                ],
            ];
            missing = ids
                .where(
                  (id) =>
                      catalogName(context, id, 'UNTRANSLATED') ==
                      'UNTRANSLATED',
                )
                .toList();
            return const SizedBox();
          },
        ),
      ),
    );
    expect(missing, isEmpty);
  });

  testWidgets('Turkish course route shows translated lesson titles', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final discipline = repo.disciplines.firstWhere((d) => d.id == 'guitar');
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('tr'),
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationsDelegates,
        home: CourseScreenRoute(
          discipline: discipline,
          course: discipline.courses.first,
        ),
      ),
    );
    expect(find.text('GİTAR · TEMELLER'), findsOneWidget);
    expect(find.text('Kamera ve alan'), findsOneWidget);
    expect(find.textContaining('BAŞLANGIÇ'), findsOneWidget);
    expect(find.textContaining('DK'), findsWidgets);
    expect(find.textContaining('Alanını hazırla'), findsOneWidget);
    expect(find.textContaining('Set up your space'), findsNothing);
    final rowCopy = tester
        .widgetList<RichText>(find.byType(RichText))
        .map((widget) => widget.text.toPlainText())
        .join(' ');
    expect(rowCopy, contains('Kalçanızın altı ölçülmez'));
    expect(rowCopy, isNot(contains('Nothing below your hips')));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Turkish instrument detail frames its limits and course', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final discipline = repo.disciplines.firstWhere((d) => d.id == 'guitar');
    await tester.pumpWidget(
      ContentRepositoryScope(
        repo: repo,
        cueText: cueText,
        child: MaterialApp(
          locale: const Locale('tr'),
          supportedLocales: appSupportedLocales,
          localizationsDelegates: appLocalizationsDelegates,
          home: InstrumentScreenRoute(discipline: discipline),
        ),
      ),
    );
    expect(
      find.textContaining('Bu sınırların nedenleri farklıdır'),
      findsOneWidget,
    );
    expect(find.text('KURSLAR'), findsOneWidget);
    expect(find.textContaining('Alanını hazırla'), findsOneWidget);
    expect(
      find.textContaining('Bağımsız yedi gitar eğitmeninin'),
      findsOneWidget,
    );
    expect(find.textContaining('Çaldığınız ses ölçülmez'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Turkish scored lesson explains the measurement and next step', (
    tester,
  ) async {
    final discipline = repo.disciplines.firstWhere((d) => d.id == 'guitar');
    final lesson = discipline.courses.first.lessons.firstWhere(
      (l) => l.kind == LessonKind.scored,
    );
    await tester.pumpWidget(
      ContentRepositoryScope(
        repo: repo,
        cueText: cueText,
        child: MaterialApp(
          locale: const Locale('tr'),
          supportedLocales: appSupportedLocales,
          localizationsDelegates: appLocalizationsDelegates,
          home: LessonScoredScreenRoute(
            discipline: discipline,
            lesson: lesson,
            hue: InstrumentHues.of(discipline.id),
          ),
        ),
      ),
    );
    expect(find.text('ÖLÇÜMÜN DAYANDIĞI ARALIK'), findsOneWidget);
    expect(find.textContaining('gitar eğitmeni'), findsOneWidget);
    expect(find.text('BAŞLAMADAN ÖNCE'), findsOneWidget);
    expect(find.text('Kurulum denetimini başlat'), findsOneWidget);
    expect(find.text('What you’re measured against'), findsNothing);
  });

  test(
    'all live authored limits and lesson gates match their English source',
    () {
      final entries = <MapEntry<String, String>>[];
      for (final discipline in repo.disciplines.where(
        (d) => d.status == 'live',
      )) {
        for (var i = 0; i < discipline.measured.length; i++) {
          entries.add(
            MapEntry('${discipline.id}.measured.$i', discipline.measured[i]),
          );
        }
        for (var i = 0; i < discipline.notMeasured.length; i++) {
          entries.add(
            MapEntry(
              '${discipline.id}.notMeasured.$i',
              discipline.notMeasured[i],
            ),
          );
        }
        for (var i = 0; i < discipline.comingSoon.length; i++) {
          entries.add(
            MapEntry(
              '${discipline.id}.comingSoon.$i',
              discipline.comingSoon[i],
            ),
          );
        }
        for (var i = 0; i < discipline.outOfScopeDerived.length; i++) {
          entries.add(
            MapEntry(
              '${discipline.id}.outOfScopeDerived.$i',
              discipline.outOfScopeDerived[i],
            ),
          );
        }
        for (final lesson in discipline.lessons) {
          for (final field in <(String, String?)>[
            ('lockedReason', lesson.lockedReason),
            ('demoOnlyReason', lesson.demoOnlyReason),
            ('blockedBy', lesson.blockedBy),
            ('unblockedBy', lesson.unblockedBy),
            ('ifItStaysBlocked', lesson.ifBlockedStaysBlocked),
          ]) {
            if (field.$2 != null && field.$2!.isNotEmpty) {
              entries.add(MapEntry('${lesson.id}.${field.$1}', field.$2!));
            }
          }
        }
      }
      expect(entries.length, 67);
      expect(
        entries
            .where(
              (entry) => !hasCurrentTurkishCatalogCopy(entry.key, entry.value),
            )
            .map((entry) => entry.key),
        isEmpty,
      );
      expect(
        hasCurrentTurkishCatalogCopy(
          entries.first.key,
          '${entries.first.value} changed',
        ),
        isFalse,
      );
    },
  );

  testWidgets('catalog translation stays on TR locale and exact source', (
    tester,
  ) async {
    final source = repo.disciplines
        .firstWhere((discipline) => discipline.id == 'guitar')
        .notMeasured[0];
    const key = 'guitar.notMeasured.0';
    Widget page(Locale locale, String text) => MaterialApp(
      locale: locale,
      supportedLocales: appSupportedLocales,
      localizationsDelegates: appLocalizationsDelegates,
      home: Builder(
        builder: (context) => Text(catalogCopy(context, key, text)),
      ),
    );

    await tester.pumpWidget(page(const Locale('en'), source));
    expect(find.text(source), findsOneWidget);
    await tester.pumpWidget(page(const Locale('tr'), source));
    expect(find.textContaining('Çaldığınız ses ölçülmez'), findsOneWidget);
    await tester.pumpWidget(page(const Locale('tr'), '$source changed'));
    expect(find.text('$source changed'), findsOneWidget);
  });

  testWidgets(
    'piano hand limits state the actual model and app boundary in Turkish',
    (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final discipline = repo.disciplines.firstWhere((d) => d.id == 'piano');
      final lesson = discipline.lessons.firstWhere(
        (l) => l.id == 'piano.foundations.hands_and_wrists',
      );
      expect(
        hasCurrentTurkishCatalogCopy(
          'piano.instrumentSpecificGap',
          discipline.instrumentSpecificGap,
        ),
        isTrue,
      );
      Widget wrapped(Widget home) => MaterialApp(
        locale: const Locale('tr'),
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationsDelegates,
        home: home,
      );
      await tester.pumpWidget(
        wrapped(
          LessonLockedScreenRoute(
            discipline: discipline,
            lesson: lesson,
            hue: InstrumentHues.of(discipline.id),
          ),
        ),
      );
      final reason = tester
          .widget<Text>(find.byKey(const Key('locked-reason')))
          .data!;
      final unlock = tester
          .widget<Text>(find.byKey(const Key('locked-what-would-open-it')))
          .data!;
      expect(reason, contains('bilekleri ve kaba işaret'));
      expect(reason, contains('canlı bir el biçimi ölçümü'));
      expect(unlock, contains('gösterilmedi'));
      expect(reason, isNot(contains('yalnız vücut eklemleri')));

      await tester.pumpWidget(
        wrapped(
          ReviewScreenRoute(
            discipline: discipline,
            lesson: discipline.lessons.first,
            hue: InstrumentHues.of(discipline.id),
            summary: const SessionSummary(
              elapsedSeconds: 30,
              sampleCount: 100,
              outCount: 10,
              history: <double>[3.0],
            ),
          ),
        ),
      );
      expect(
        find.textContaining('Ostinato’da canlı el biçimi ölçümü'),
        findsOneWidget,
      );
      expect(
        find.textContaining('We have no hand or finger landmarks'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Turkish locked and demonstration details explain their limits', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final discipline = repo.disciplines.firstWhere((d) => d.id == 'guitar');
    final lessons = discipline.courses.first.lessons;
    Widget wrapped(Widget home) => MaterialApp(
      locale: const Locale('tr'),
      supportedLocales: appSupportedLocales,
      localizationsDelegates: appLocalizationsDelegates,
      home: home,
    );
    final locked = lessons.firstWhere((l) => l.id.endsWith('foot_support'));
    await tester.pumpWidget(
      wrapped(
        LessonLockedScreenRoute(
          discipline: discipline,
          lesson: locked,
          hue: InstrumentHues.of(discipline.id),
        ),
      ),
    );
    expect(find.textContaining('Kalçanızın altı ölçülmez'), findsOneWidget);
    expect(find.textContaining('Bacakları gerçekten kadraja'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final demo = lessons.firstWhere((l) => l.id.endsWith('.arms'));
    await tester.pumpWidget(
      wrapped(
        LessonDemoScreenRoute(
          discipline: discipline,
          lesson: demo,
          hue: InstrumentHues.of(discipline.id),
        ),
      ),
    );
    expect(
      find.textContaining('Kendi dirsek açınız gösterilmez'),
      findsOneWidget,
    );
    expect(find.textContaining('39–105° arasında'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
