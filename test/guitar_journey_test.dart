import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/account_connection.dart';
import 'package:ostinato/app/account_data_directory.dart';
import 'package:ostinato/app/app_locale.dart';
import 'package:ostinato/app/design/widgets.dart';
import 'package:ostinato/app/guitar_journey.dart';
import 'package:ostinato/app/guitar_journey_progress.dart';
import 'package:ostinato/app/guitar_session_preparation.dart';
import 'package:ostinato/app/screens/guitar_journey_screen.dart';

const firstId = 'guitar.journey.start.parts';
const accountA = '11111111-1111-4111-8111-111111111111';
const accountB = '22222222-2222-4222-8222-222222222222';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'shipped path parses 10 modules and 60 ordered original lessons',
    () async {
      final course = await GuitarJourneyCourse.load();
      expect(course.modules.length, 10);
      expect(course.lessons.length, 60);
      expect(course.contentVersion, '2026.09.26.1');
      expect(course.curriculumRevision, '2026.09.27.comprehensive.1');
      expect(course.sources.length, 13);
      expect(
        course.lessons.every((l) => l.learningLab?.drills.length == 3),
        isTrue,
      );
      expect(course.lessons.first.learningLab!.reviewDays, [1, 3, 7]);
      expect(course.lessons.first.id, firstId);
      expect(course.lessons.first.prerequisiteIds, isEmpty);
      expect(course.lessons.last.prerequisiteIds, [course.lessons[58].id]);
      expect(course.lessons.where((l) => l.capstone).length, 2);
      expect(course.tuning.map((s) => s.note).toList(), [
        'E2',
        'A2',
        'D3',
        'G3',
        'B3',
        'E4',
      ]);
      expect(course.chordShapes['Em']!.frets6to1, [0, 2, 2, 0, 0, 0]);
      expect(course.chordShapes['D']!.frets6to1, [null, null, 0, 2, 3, 2]);
      expect(
        course.lessons.singleWhere((l) => l.id.endsWith('.power_chords')).shapeIds,
        ['E5', 'A5'],
      );
      expect(
        course.lessons.singleWhere((l) => l.id.endsWith('.movable_shape')).shapeIds,
        ['G_barre', 'Gm_barre', 'B_barre', 'Bm_barre'],
      );
      expect(course.chordShapes['G_barre']!.frets6to1, [3, 5, 5, 4, 3, 3]);
      expect(course.chordShapes['Bm_barre']!.frets6to1, [null, 2, 4, 4, 3, 2]);
      expect(
        course.lessons.where((l) => l.shapeIds.isNotEmpty).length,
        greaterThan(15),
      );
      expect(
        course.lessons.every(
          (l) => l.sourceIds.every(course.sources.containsKey),
        ),
        isTrue,
      );
      expect(
        course.lessons.every(
          (l) => l.mediaStatus.contains('teacher_review_required'),
        ),
        isTrue,
      );
    },
  );

  test('older content without a practice lab still parses', () {
    final json =
        jsonDecode(
              File('assets/content/guitar_journey.v1.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    json.remove('curriculumRevision');
    json.remove('progressSemantics');
    final modules = json['modules'] as List<dynamic>;
    final first = (modules.first as Map<String, dynamic>)['lessons'] as List;
    (first.first as Map<String, dynamic>).remove('learningLab');
    final course = GuitarJourneyCourse.fromJson(json);
    expect(course.lessons.first.learningLab, isNull);
    expect(course.curriculumRevision, isNull);
    expect(course.lessons.length, 60);
  });

  test(
    'enrichment keeps an existing historical completion under its stable key',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'ostinato-guitar-history-',
      );
      addTearDown(() => root.delete(recursive: true));
      final store = GuitarJourneyProgressStore(
        directoryProvider: () async => root,
      );
      await store.record(
        lessonId: firstId,
        contentVersion: '2026.09.26.1',
        action: GuitarProgressAction.practiced,
        at: DateTime.utc(2026, 9, 26),
      );
      await store.record(
        lessonId: firstId,
        contentVersion: '2026.09.26.1',
        action: GuitarProgressAction.selfReportedCompleted,
        at: DateTime.utc(2026, 9, 26, 1),
      );
      final before = File(
        '${root.path}/guitar_journey_progress.v1.json',
      ).readAsStringSync();
      final course = await GuitarJourneyCourse.load();
      final reopened = (await store
          .load())['${course.contentVersion}|$firstId'];
      expect(reopened!.practiceCount, 1);
      expect(reopened.selfReportedCompletedAt, DateTime.utc(2026, 9, 26, 1));
      expect(
        File('${root.path}/guitar_journey_progress.v1.json').readAsStringSync(),
        before,
      );
      expect(course.lessons.first.learningLab, isNotNull);
    },
  );

  for (final index in [0, 50, 59]) {
    testWidgets(
      'Turkish practice lab at narrow width and 200percent text ($index)',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final root = Directory.systemTemp.createTempSync(
          'ostinato-guitar-lab-ui-',
        );
        addTearDown(() => root.deleteSync(recursive: true));
        final course = GuitarJourneyCourse.fromJson(
          jsonDecode(
                File(
                  'assets/content/guitar_journey.v1.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>,
        );
        final lesson = course.lessons[index];
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('tr'),
            supportedLocales: appSupportedLocales,
            localizationsDelegates: appLocalizationsDelegates,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(2)),
              child: child!,
            ),
            home: GuitarJourneyLessonScreen(
              course: course,
              lesson: lesson,
              store: GuitarJourneyProgressStore(
                directoryProvider: () async => root,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (index > 2) {
          final acknowledge = find.byKey(
            const Key('guitar-session-acknowledge'),
          );
          await tester.ensureVisible(acknowledge);
          await tester.tap(acknowledge);
          await tester.pumpAndSettle();
        }
        expect(
          find.byKey(Key('guitar-learning-lab-${lesson.id}')),
          findsOneWidget,
        );
        for (final drill in lesson.learningLab!.drills) {
          expect(find.byKey(Key('guitar-drill-${drill.id}')), findsOneWidget);
          if (drill.firstReadScore != null) {
            expect(find.text(drill.task.tr), findsNothing);
            final reveal = find.byKey(const Key('guitar-first-read-reveal'));
            await tester.ensureVisible(reveal);
            await tester.tap(reveal);
            await tester.pumpAndSettle();
          }
          expect(find.text(drill.task.tr), findsOneWidget);
        }
        expect(find.textContaining('original_flexible_product'), findsNothing);
        expect(find.textContaining('schemaVersion'), findsNothing);
        expect(find.textContaining('native_status'), findsNothing);
        expect(find.text('Bu çalışmayı tamamladım'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  test(
    'progress distinguishes seen, practice and self-report; versions and accounts stay separate',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'ostinato-guitar-progress-',
      );
      addTearDown(() => root.delete(recursive: true));
      final a = GuitarJourneyProgressStore(
        directoryProvider: () async => root,
        accountUserId: accountA,
      );
      final b = GuitarJourneyProgressStore(
        directoryProvider: () async => root,
        accountUserId: accountB,
      );
      final seen = await a.record(
        lessonId: firstId,
        contentVersion: 'v1',
        action: GuitarProgressAction.viewed,
        at: DateTime.utc(2026, 9, 26),
      );
      expect(seen.practiceCount, 0);
      expect(seen.selfReportedCompletedAt, isNull);
      await expectLater(
        a.record(
          lessonId: firstId,
          contentVersion: 'v1',
          action: GuitarProgressAction.selfReportedCompleted,
        ),
        throwsStateError,
      );
      final practiced = await a.record(
        lessonId: firstId,
        contentVersion: 'v1',
        action: GuitarProgressAction.practiced,
        at: DateTime.utc(2026, 9, 27),
      );
      expect(practiced.practiceCount, 1);
      expect(practiced.selfReportedCompletedAt, isNull);
      final done = await a.record(
        lessonId: firstId,
        contentVersion: 'v1',
        action: GuitarProgressAction.selfReportedCompleted,
        at: DateTime.utc(2026, 9, 28),
      );
      expect(done.selfReportedCompletedAt, DateTime.utc(2026, 9, 28));
      expect((await a.load())['v1|$firstId']!.practiceCount, 1);
      expect((await a.load())['v2|$firstId'], isNull);
      expect(await b.load(), isEmpty);
      await b.record(
        lessonId: firstId,
        contentVersion: 'v1',
        action: GuitarProgressAction.viewed,
      );
      await deleteAccountData(root, accountA);
      expect(await a.load(), isEmpty);
      expect((await b.load()).length, 1);
    },
  );

  test(
    'corrupt local progress is not silently reset and overwritten',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'ostinato-guitar-corrupt-',
      );
      addTearDown(() => root.delete(recursive: true));
      final file = File('${root.path}/guitar_journey_progress.v1.json');
      await file.writeAsString('{broken');
      final store = GuitarJourneyProgressStore(
        directoryProvider: () async => root,
      );
      await expectLater(
        store.record(
          lessonId: firstId,
          contentVersion: 'v1',
          action: GuitarProgressAction.viewed,
        ),
        throwsFormatException,
      );
      expect(await file.readAsString(), '{broken');
    },
  );

  testWidgets('learner opens full lesson with honest progress mode', (
    tester,
  ) async {
    final root = Directory.systemTemp.createTempSync('ostinato-guitar-ui-');
    addTearDown(() => root.deleteSync(recursive: true));
    final course = GuitarJourneyCourse.fromJson(
      jsonDecode(
            File('assets/content/guitar_journey.v1.json').readAsStringSync(),
          )
          as Map<String, dynamic>,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: GuitarJourneyScreen(
          initialCourse: course,
          initialProgress: const {},
          progressStoreFactory: (_) =>
              GuitarJourneyProgressStore(directoryProvider: () async => root),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('guitar-journey-progress')), findsOneWidget);
    expect(
      find.textContaining('0 of 60 self-reported complete'),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('Open lesson'));
    await tester.tap(find.text('Open lesson'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('guitar-lesson-title-$firstId')),
      findsOneWidget,
    );
    expect(
      find.textContaining('no note, chord or hand position is graded here'),
      findsOneWidget,
    );
    expect(find.text('Record practice', skipOffstage: false), findsOneWidget);
    expect(
      find.text('I completed this practice', skipOffstage: false),
      findsOneWidget,
    );
  });

  for (final locale in ['en', 'tr']) {
    testWidgets(
      'lesson back reloads saved progress without an exception ($locale)',
      (tester) async {
        final root = Directory.systemTemp.createTempSync(
          'ostinato-guitar-back-',
        );
        addTearDown(() => root.deleteSync(recursive: true));
        final course = GuitarJourneyCourse.fromJson(
          jsonDecode(
                File(
                  'assets/content/guitar_journey.v1.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>,
        );
        final store = GuitarJourneyProgressStore(
          directoryProvider: () async => root,
        );
        final isTr = locale == 'tr';
        final open = isTr ? 'Dersi aç' : 'Open lesson';
        final practice = isTr ? 'Çalışmayı kaydet' : 'Record practice';
        final complete = isTr
            ? 'Bu çalışmayı tamamladım'
            : 'I completed this practice';
        final back = isTr ? 'Kursa dön' : 'Back to course';
        final recordKey = '${course.contentVersion}|$firstId';

        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(locale),
            supportedLocales: appSupportedLocales,
            localizationsDelegates: appLocalizationsDelegates,
            home: GuitarJourneyScreen(
              initialCourse: course,
              initialProgress: const {},
              progressStoreFactory: (_) => store,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text(open));
        await tester.tap(find.text(open));
        await tester.pumpAndSettle();

        Future<GuitarLessonProgress?> savedRecord() async {
          final records = await tester.runAsync(store.load);
          await tester.pump();
          return records?[recordKey];
        }

        Future<void> saveAndWait(
          String text,
          bool Function(GuitarLessonProgress?) saved,
        ) async {
          await tester.ensureVisible(find.text(text));
          await tester.tap(find.text(text));
          for (var attempt = 0; attempt < 40; attempt++) {
            // Yield to actual file I/O; completion must be read from disk.
            if (saved(await savedRecord())) return;
          }
          fail('The lesson action was not persisted: $text');
        }

        await saveAndWait(practice, (record) => record?.practiceCount == 1);
        await saveAndWait(
          complete,
          (record) => record?.selfReportedCompletedAt != null,
        );
        final backButton = find.byWidgetPredicate(
          (widget) => widget is GlassIconButton && widget.semanticLabel == back,
        );
        expect(backButton, findsOneWidget);
        await tester.ensureVisible(backButton);
        await tester.pumpAndSettle();
        await tester.tap(backButton);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // The course route stayed mounted; its reload must read the saved record.
        final courseProgress = find.text(
          isTr
              ? '1 / 60 öz beyanla tamamlandı'
              : '1 of 60 self-reported complete',
        );
        for (var attempt = 0; attempt < 40; attempt++) {
          await savedRecord();
          await tester.pumpAndSettle();
          if (courseProgress.evaluate().isNotEmpty) break;
        }
        expect(courseProgress, findsOneWidget);
        final firstLesson = find.byKey(const Key('guitar-lesson-$firstId'));
        await tester.ensureVisible(firstLesson);
        await tester.tap(firstLesson);
        await tester.pumpAndSettle();
        expect(
          find.text(isTr ? 'Çalışma kaydı: 1' : 'Practice entries: 1'),
          findsOneWidget,
        );
        final completionButton = find.widgetWithText(FilledButton, complete);
        expect(tester.widget<FilledButton>(completionButton).onPressed, isNull);
        expect((await savedRecord())?.practiceCount, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('open-chord lesson exposes actual string and fret examples', (
    tester,
  ) async {
    final course = GuitarJourneyCourse.fromJson(
      jsonDecode(
            File('assets/content/guitar_journey.v1.json').readAsStringSync(),
          )
          as Map<String, dynamic>,
    );
    final lesson = course.lessons.firstWhere(
      (l) => l.id.endsWith('.diagrams_em_am'),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: GuitarJourneyLessonScreen(
          course: course,
          lesson: lesson,
          store: const GuitarJourneyProgressStore(),
        ),
      ),
    );
    final acknowledge = find.byKey(const Key('guitar-session-acknowledge'));
    await tester.ensureVisible(acknowledge);
    await tester.tap(acknowledge);
    await tester.pumpAndSettle();
    expect(find.text('E minor', skipOffstage: false), findsOneWidget);
    expect(find.text('A minor', skipOffstage: false), findsOneWidget);
    expect(
      find.textContaining('Finger numbers are examples', skipOffstage: false),
      findsOneWidget,
    );
    expect(find.text('Before this lesson', skipOffstage: false), findsNothing);
    expect(
      find.text('BEFORE THIS LESSON', skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets('Turkish lesson stays readable at narrow width and large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final course = GuitarJourneyCourse.fromJson(
      jsonDecode(
            File('assets/content/guitar_journey.v1.json').readAsStringSync(),
          )
          as Map<String, dynamic>,
    );
    final lesson = course.lessons.firstWhere((l) => l.id.endsWith('.f_chord'));
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('tr'),
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationsDelegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.6)),
          child: child!,
        ),
        home: GuitarJourneyLessonScreen(
          course: course,
          lesson: lesson,
          store: const GuitarJourneyProgressStore(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final acknowledge = find.byKey(const Key('guitar-session-acknowledge'));
    await tester.ensureVisible(acknowledge);
    await tester.tap(acknowledge);
    await tester.pumpAndSettle();
    expect(
      find.text('Fa majör seçenekleri', skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.text('Fa majör kısmi bare', skipOffstage: false),
      findsOneWidget,
    );
    expect(find.text('BU DERSTEN ÖNCE', skipOffstage: false), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test(
    'session preparation resets after a date change, background and break',
    () {
      var now = DateTime(2026, 9, 28, 9);
      final preparation = GuitarSessionPreparation(now: () => now);
      addTearDown(preparation.dispose);

      expect(preparation.isAcknowledged, isFalse);
      preparation.acknowledge();
      expect(preparation.isAcknowledged, isTrue);
      now = DateTime(2026, 9, 29, 9);
      expect(preparation.isAcknowledged, isFalse);
      preparation.didChangeAppLifecycleState(AppLifecycleState.resumed);
      preparation.acknowledge();
      preparation.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(preparation.isAcknowledged, isFalse);
      preparation.acknowledge();
      preparation.afterBreak();
      expect(preparation.isAcknowledged, isFalse);
    },
  );

  testWidgets(
    'yesterday prerequisites do not prepare a new accompaniment session',
    (tester) async {
      final course = GuitarJourneyCourse.fromJson(
        jsonDecode(
              File('assets/content/guitar_journey.v1.json').readAsStringSync(),
            )
            as Map<String, dynamic>,
      );
      final root = Directory.systemTemp.createTempSync('ostinato-guitar-prep-');
      addTearDown(() => root.deleteSync(recursive: true));
      final store = GuitarJourneyProgressStore(
        directoryProvider: () async => root,
      );
      final yesterday = DateTime.utc(2026, 9, 27, 10);
      final initialProgress = await tester.runAsync(() async {
        for (final id in [
          'guitar.journey.start.setup',
          'guitar.journey.start.tuning',
          'guitar.journey.strum.mute',
        ]) {
          await store.record(
            lessonId: id,
            contentVersion: course.contentVersion,
            action: GuitarProgressAction.practiced,
            at: yesterday,
          );
          await store.record(
            lessonId: id,
            contentVersion: course.contentVersion,
            action: GuitarProgressAction.selfReportedCompleted,
            at: yesterday.add(const Duration(minutes: 10)),
          );
        }
        return store.load();
      });
      expect(initialProgress, isNotNull);
      final now = DateTime(2026, 9, 28, 10);
      final preparation = GuitarSessionPreparation(now: () => now);
      addTearDown(preparation.dispose);
      const lessonId = 'guitar.journey.strum.accompaniment';

      await tester.pumpWidget(
        MaterialApp(
          home: GuitarJourneyScreen(
            initialCourse: course,
            initialProgress: initialProgress!,
            progressStoreFactory: (_) => store,
            preparation: preparation,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final lessonTile = find.byKey(const Key('guitar-lesson-$lessonId'));
      await tester.ensureVisible(lessonTile);
      await tester.tap(lessonTile);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('guitar-session-preparation')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('guitar-learning-lab-$lessonId')),
        findsNothing,
      );
      expect(find.text('Record practice', skipOffstage: false), findsNothing);

      final observe = find.byKey(const Key('guitar-session-observe'));
      await tester.ensureVisible(observe);
      await tester.tap(observe);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('guitar-learning-lab-$lessonId')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Record practice'),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'I completed this practice'),
            )
            .onPressed,
        isNull,
      );
      final viewed = find.text('Mark viewed');
      await tester.ensureVisible(viewed);
      await tester.tap(viewed);
      GuitarLessonProgress? observedRecord;
      for (var attempt = 0; attempt < 40; attempt++) {
        observedRecord = (await tester.runAsync(
          store.load,
        ))?['${course.contentVersion}|$lessonId'];
        await tester.pump();
        if (observedRecord?.seenAt != null) break;
      }
      expect(observedRecord?.seenAt, isNotNull);
      expect(observedRecord?.practiceCount, 0);
      expect(observedRecord?.selfReportedCompletedAt, isNull);

      final acknowledge = find.byKey(const Key('guitar-session-acknowledge'));
      await tester.ensureVisible(acknowledge);
      await tester.tap(acknowledge);
      await tester.pumpAndSettle();
      expect(preparation.isAcknowledged, isTrue);
      expect(find.byKey(const Key('guitar-session-prepared')), findsOneWidget);
      final afterBreak = find.byKey(const Key('guitar-session-after-break'));
      await tester.ensureVisible(afterBreak);
      await tester.tap(afterBreak);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('guitar-session-preparation')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('guitar-learning-lab-$lessonId')),
        findsNothing,
      );
      final afterBreakRecord = (await tester.runAsync(
        store.load,
      ))?['${course.contentVersion}|$lessonId'];
      expect(afterBreakRecord?.practiceCount, 0);
      expect(afterBreakRecord?.selfReportedCompletedAt, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'setup and tuning lessons teach without a duplicate session gate',
    (tester) async {
      final course = GuitarJourneyCourse.fromJson(
        jsonDecode(
              File('assets/content/guitar_journey.v1.json').readAsStringSync(),
            )
            as Map<String, dynamic>,
      );
      for (final id in [
        'guitar.journey.start.setup',
        'guitar.journey.start.tuning',
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            home: GuitarJourneyLessonScreen(
              course: course,
              lesson: course.lessons.firstWhere((lesson) => lesson.id == id),
              store: const GuitarJourneyProgressStore(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('guitar-session-preparation')),
          findsNothing,
        );
        expect(find.byKey(Key('guitar-learning-lab-$id')), findsOneWidget);
      }
    },
  );

  testWidgets('a different account cannot inherit guitar session preparation', (
    tester,
  ) async {
    final course = GuitarJourneyCourse.fromJson(
      jsonDecode(
            File('assets/content/guitar_journey.v1.json').readAsStringSync(),
          )
          as Map<String, dynamic>,
    );
    final preparation = GuitarSessionPreparation()..acknowledge();
    addTearDown(preparation.dispose);
    Widget app(String accountId) => MaterialApp(
      home: AccountScope(
        connection: null,
        currentUserId: accountId,
        child: GuitarJourneyScreen(
          initialCourse: course,
          initialProgress: const {},
          preparation: preparation,
          progressStoreFactory: (id) =>
              GuitarJourneyProgressStore(accountUserId: id),
        ),
      ),
    );
    await tester.pumpWidget(app(accountA));
    await tester.pumpAndSettle();
    expect(preparation.isAcknowledged, isTrue);
    await tester.pumpWidget(app(accountB));
    await tester.pumpAndSettle();
    expect(preparation.isAcknowledged, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('course note entry shares its fresh-session acknowledgment', (
    tester,
  ) async {
    final course = GuitarJourneyCourse.fromJson(
      jsonDecode(
            File('assets/content/guitar_journey.v1.json').readAsStringSync(),
          )
          as Map<String, dynamic>,
    );
    final preparation = GuitarSessionPreparation();
    await tester.pumpWidget(
      MaterialApp(
        home: GuitarJourneyScreen(
          initialCourse: course,
          initialProgress: const {},
          preparation: preparation,
          progressStoreFactory: (id) =>
              GuitarJourneyProgressStore(accountUserId: id),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final entry = find.byKey(const Key('guitar-note-observation-entry'));
    await tester.ensureVisible(entry);
    await tester.tap(entry);
    await tester.pumpAndSettle();
    expect(preparation.isAcknowledged, isFalse);
    expect(find.byKey(const Key('note-session-acknowledge')), findsOneWidget);
    final acknowledge = find.byKey(const Key('note-session-acknowledge'));
    await tester.ensureVisible(acknowledge);
    await tester.tap(acknowledge);
    await tester.pump();
    expect(preparation.isAcknowledged, isTrue);
    expect(find.byKey(const Key('note-session-after-break')), findsOneWidget);
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    preparation.dispose();
    expect(tester.takeException(), isNull);
  });
}
