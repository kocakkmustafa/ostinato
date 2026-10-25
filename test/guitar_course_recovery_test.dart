import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/app_locale.dart';
import 'package:ostinato/app/guitar_journey.dart';
import 'package:ostinato/app/guitar_journey_progress.dart';
import 'package:ostinato/app/screens/guitar_journey_screen.dart';
import 'support/localized_widget_ready.dart';
import 'support/paid_access_scope.dart';

/// Paywall A: course walks run as a member; the lock itself is covered by
/// course_access_test.dart.
Widget _asMember(Widget app) => PaidAccessProbe().wrap(app);

class _Files extends CachingAssetBundle {
  bool unavailable = true;

  @override
  Future<ByteData> load(String key) async {
    if (unavailable && key == 'assets/content/guitar_journey.v1.json') {
      throw FlutterError('Test asset unavailable');
    }
    return ByteData.sublistView(File(key).readAsBytesSync());
  }
}

Widget _app(String locale, Widget home) => MaterialApp(
  locale: Locale(locale),
  supportedLocales: appSupportedLocales,
  localizationsDelegates: appLocalizationsDelegates,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(2)),
    child: child!,
  ),
  home: home,
);

Future<void> _waitText(WidgetTester tester, String text) async {
  for (var i = 0; i < 80; i++) {
    await tester.pump();
    if (find.text(text).evaluate().isNotEmpty) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
  }
  expect(find.text(text), findsOneWidget);
}

Future<void> _tap(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.runAsync(() => tester.tap(finder));
  await tester.pump();
}

Future<void> _tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.runAsync(() => tester.tap(finder));
  await tester.pump();
}

void _expectRecordingDisabled(WidgetTester tester) {
  for (final key in [
    'guitar-progress-viewed',
    'guitar-progress-practiced',
    'guitar-progress-completed',
  ]) {
    expect(
      tester.widget<ButtonStyleButton>(find.byKey(Key(key))).onPressed,
      isNull,
      reason: '$key must not record unknown progress',
    );
  }
}

GuitarJourneyCourse _course() => GuitarJourneyCourse.fromJson(
  jsonDecode(File('assets/content/guitar_journey.v1.json').readAsStringSync())
      as Map<String, dynamic>,
);

void main() {
  setUpAll(prepareRootTranslations);
  for (final locale in ['en', 'tr']) {
    final tr = locale == 'tr';
    final retry = tr ? 'Yeniden dene' : 'Retry';
    final zero = tr
        ? '0 / 60 öz beyanla tamamlandı'
        : '0 of 60 self-reported complete';
    final one = tr
        ? '1 / 60 öz beyanla tamamlandı'
        : '1 of 60 self-reported complete';

    testWidgets('course failure offers back and verified retry ($locale)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final files = _Files();
      await tester.pumpWidget(
        _asMember(
          _app(
            locale,
            Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => GuitarJourneyScreen(
                        bundle: files,
                        initialProgress: const {},
                      ),
                    ),
                  ),
                  child: const Text('Open test course'),
                ),
              ),
            ),
          ),
        ),
      );
      await _tap(tester, 'Open test course');
      final error = tr
          ? 'Kurs yüklenemedi.'
          : 'The course could not be loaded.';
      await _waitText(tester, error);
      await _tap(tester, tr ? 'Geri' : 'Back');
      await tester.pumpAndSettle();
      expect(find.text('Open test course'), findsOneWidget);
      await _tap(tester, 'Open test course');
      await _waitText(tester, error);
      files.unavailable = false;
      await _tap(tester, retry);
      await _waitText(tester, zero);
      expect(find.text(error), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'unreadable progress keeps lessons read-only until a valid retry ($locale)',
      (tester) async {
        final root = Directory.systemTemp.createTempSync('ostinato-recovery-');
        addTearDown(() => root.deleteSync(recursive: true));
        final file = File('${root.path}/guitar_journey_progress.v1.json');
        file.writeAsStringSync('{broken guest history');
        final store = GuitarJourneyProgressStore(
          directoryProvider: () async => root,
        );
        final course = _course();
        await tester.pumpWidget(
          _asMember(
            _app(
              locale,
              GuitarJourneyScreen(
                initialCourse: course,
                progressStoreFactory: (_) => store,
              ),
            ),
          ),
        );
        final error = tr
            ? 'Yerel ilerlemen okunamadı. Kayıt sıfırlanmadı.'
            : 'Your local progress could not be read. It has not been reset.';
        await _waitText(tester, error);
        expect(
          tester
              .widget<Text>(find.byKey(const Key('guitar-journey-progress')))
              .data,
          tr ? 'İlerleme bilinmiyor' : 'Progress unknown',
        );
        expect(find.text(zero), findsNothing);
        expect(
          find.text(tr ? '0 / 6 öz beyan' : '0 / 6 self-reported'),
          findsNothing,
        );
        expect(find.text(tr ? 'BAŞLANMADI' : 'NOT STARTED'), findsNothing);
        expect(find.byKey(const Key('guitar-journey-next')), findsNothing);
        expect(find.byType(LinearProgressIndicator), findsNothing);

        // This lesson normally gates its body behind session preparation.
        // Unknown progress must allow reading, without enabling any writer.
        final lesson = course.lessons[3];
        await _tapKey(tester, 'guitar-lesson-${lesson.id}');
        await tester.pumpAndSettle();
        expect(
          find.byKey(Key('guitar-lesson-title-${lesson.id}')),
          findsOneWidget,
        );
        expect(
          find.text(tr ? lesson.objective.tr : lesson.objective.en),
          findsOneWidget,
        );
        expect(
          find.text(
            tr ? 'Çalışma kaydı: bilinmiyor' : 'Practice entries: unknown',
          ),
          findsOneWidget,
        );
        expect(
          find.text(tr ? 'Çalışma kaydı: 0' : 'Practice entries: 0'),
          findsNothing,
        );
        expect(
          find.byKey(const Key('guitar-previous-version-completion')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('guitar-lesson-progress-unavailable')),
          findsOneWidget,
        );
        _expectRecordingDisabled(tester);
        await _tapKey(tester, 'guitar-session-acknowledge');
        _expectRecordingDisabled(tester);
        await _tapKey(tester, 'guitar-session-after-break');
        _expectRecordingDisabled(tester);
        expect(file.readAsStringSync(), '{broken guest history');
        expect(File('${file.path}.tmp').existsSync(), isFalse);
        await _tapKey(tester, 'guitar-lesson-back');
        await _waitText(tester, error);
        await _tap(tester, retry);
        Object? readFailure;
        var readDone = false;
        await tester.runAsync(() async {
          store.load().then<void>(
            (_) {
              readDone = true;
            },
            onError: (Object failure, StackTrace _) {
              readFailure = failure;
              readDone = true;
            },
          );
        });
        // Join the retry's real I/O queue while allowing fake-zone callbacks
        // from the first widget load to finish as well.
        for (var i = 0; i < 80 && !readDone; i++) {
          await tester.pump();
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 5)),
          );
        }
        expect(readDone, isTrue);
        expect(readFailure, isFormatException);
        await _waitText(tester, error);
        expect(file.readAsStringSync(), '{broken guest history');
        // Simulate a restored test backup; the app never clears corrupt history.
        file.writeAsStringSync('{"schemaVersion":1,"records":[]}');
        await _tap(tester, retry);
        await _waitText(tester, zero);
        expect(
          find.byKey(const Key('guitar-progress-unavailable')),
          findsNothing,
        );
        await _tap(tester, tr ? 'Dersi aç' : 'Open lesson');
        await tester.pumpAndSettle();
        await _tap(tester, tr ? 'Çalışmayı kaydet' : 'Record practice');
        await _waitText(
          tester,
          tr ? 'Çalışma kaydı: 1' : 'Practice entries: 1',
        );
        final saved = await tester.runAsync(store.load);
        expect(saved?.values.single.practiceCount, 1);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('guest practice survives a fresh screen and store ($locale)', (
      tester,
    ) async {
      final root = Directory.systemTemp.createTempSync(
        'ostinato-guest-reopen-',
      );
      addTearDown(() => root.deleteSync(recursive: true));
      final course = _course();
      Widget screen() => _app(
        locale,
        GuitarJourneyScreen(
          initialCourse: course,
          progressStoreFactory: (id) => GuitarJourneyProgressStore(
            accountUserId: id,
            directoryProvider: () async => root,
          ),
        ),
      );
      await tester.pumpWidget(_asMember(screen()));
      await _waitText(tester, zero);
      await _tap(tester, tr ? 'Dersi aç' : 'Open lesson');
      await tester.pumpAndSettle();
      await _tap(tester, tr ? 'Çalışmayı kaydet' : 'Record practice');
      await _waitText(tester, tr ? 'Çalışma kaydı: 1' : 'Practice entries: 1');
      await _tap(
        tester,
        tr ? 'Bu çalışmayı tamamladım' : 'I completed this practice',
      );
      final reader = GuitarJourneyProgressStore(
        directoryProvider: () async => root,
      );
      Map<String, GuitarLessonProgress>? records;
      for (var i = 0; i < 80; i++) {
        records = await tester.runAsync(reader.load);
        if (records?.values.single.selfReportedCompletedAt != null) break;
        await tester.pump();
      }
      expect(records?.values.single.practiceCount, 1);
      expect(records?.values.single.selfReportedCompletedAt, isNotNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.pumpWidget(_asMember(screen()));
      await _waitText(tester, one);
      final otherAccount = GuitarJourneyProgressStore(
        directoryProvider: () async => root,
        accountUserId: '11111111-1111-4111-8111-111111111111',
      );
      expect(await tester.runAsync(otherAccount.load), isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('pending reload never reuses known progress with the next read', (
    tester,
  ) async {
    final root = Directory.systemTemp.createTempSync(
      'ostinato-pending-progress-',
    );
    addTearDown(() => root.deleteSync(recursive: true));
    Completer<Directory>? pendingDirectory;
    final store = GuitarJourneyProgressStore(
      directoryProvider: () => pendingDirectory?.future ?? Future.value(root),
    );
    final course = _course();
    await tester.pumpWidget(
      _asMember(
        _app(
          'en',
          GuitarJourneyScreen(
            initialCourse: course,
            progressStoreFactory: (_) => store,
          ),
        ),
      ),
    );
    await _waitText(tester, '0 of 60 self-reported complete');
    await _tap(tester, 'Open lesson');
    await tester.pumpAndSettle();
    final file = File('${root.path}/guitar_journey_progress.v1.json');
    file.writeAsStringSync('{changed after the previous read');
    final pending = Completer<Directory>();
    pendingDirectory = pending;
    await _tapKey(tester, 'guitar-lesson-back');
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('guitar-journey-progress')), findsNothing);
    expect(find.byKey(const Key('guitar-journey-next')), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pending.complete(root);
    await _waitText(
      tester,
      'Your local progress could not be read. It has not been reset.',
    );
    expect(find.text('0 of 60 self-reported complete'), findsNothing);
    expect(file.readAsStringSync(), '{changed after the previous read');
    expect(tester.takeException(), isNull);
  });

  final validRecord = GuitarLessonProgress(
    lessonId: 'guitar.journey.start.parts',
    contentVersion: 'test_content_v1',
    seenAt: DateTime.utc(2026, 10, 19),
    practicedAt: DateTime.utc(2026, 10, 19),
    practiceCount: 1,
  ).toJson();
  final invalidSnapshots = <String, String>{
    'malformed JSON': '{broken history',
    'future schema': jsonEncode({
      'schemaVersion': 2,
      'records': [validRecord],
    }),
    'wrong root type': '[]',
    'wrong records type': '{"schemaVersion":1,"records":{}}',
    'wrong record type': '{"schemaVersion":1,"records":[42]}',
    'wrong field type': jsonEncode({
      'schemaVersion': 1,
      'records': [
        {...validRecord, 'practiceCount': 'one'},
      ],
    }),
    'invalid date': jsonEncode({
      'schemaVersion': 1,
      'records': [
        {...validRecord, 'seenAt': 'not-a-date'},
      ],
    }),
    'negative practice count': jsonEncode({
      'schemaVersion': 1,
      'records': [
        {...validRecord, 'practiceCount': -1},
      ],
    }),
    'duplicate record': jsonEncode({
      'schemaVersion': 1,
      'records': [validRecord, validRecord],
    }),
  };
  for (final entry in invalidSnapshots.entries) {
    test(
      'record preserves ${entry.key} for every action and queue recovers',
      () async {
        final root = Directory.systemTemp.createTempSync(
          'ostinato-invalid-progress-',
        );
        addTearDown(() => root.deleteSync(recursive: true));
        final file = File('${root.path}/guitar_journey_progress.v1.json');
        final temp = File('${file.path}.tmp');
        file.writeAsStringSync(entry.value);
        final originalBytes = file.readAsBytesSync();
        final store = GuitarJourneyProgressStore(
          directoryProvider: () async => root,
        );
        final readFailure = anyOf(isA<FormatException>(), isA<TypeError>());
        await expectLater(store.load(), throwsA(readFailure));
        for (final action in GuitarProgressAction.values) {
          await expectLater(
            store.record(
              lessonId: 'guitar.journey.start.parts',
              contentVersion: 'test_content_v1',
              action: action,
            ),
            throwsA(readFailure),
          );
          expect(file.readAsBytesSync(), orderedEquals(originalBytes));
          expect(temp.existsSync(), isFalse);
        }
        // An existing uncommitted temp is not a backup and must also be left
        // alone when the main file cannot be read.
        temp.writeAsStringSync('uncommitted test bytes');
        await expectLater(
          store.record(
            lessonId: 'guitar.journey.start.parts',
            contentVersion: 'test_content_v1',
            action: GuitarProgressAction.practiced,
          ),
          throwsA(readFailure),
        );
        expect(file.readAsBytesSync(), orderedEquals(originalBytes));
        expect(temp.readAsStringSync(), 'uncommitted test bytes');

        // Only the test fixture restores a valid snapshot. Failed reads/writes
        // must not poison the real store/account queue for a later valid save.
        file.writeAsStringSync('{"schemaVersion":1,"records":[]}');
        final next = await store.record(
          lessonId: 'guitar.journey.start.parts',
          contentVersion: 'test_content_v1',
          action: GuitarProgressAction.practiced,
          at: DateTime.utc(2026, 10, 19),
        );
        expect(next.practiceCount, 1);
        expect((await store.load()).values.single.practiceCount, 1);
        expect(temp.existsSync(), isFalse);
      },
    );
  }

  for (final action in GuitarProgressAction.values) {
    testWidgets('read-only guard rejects a stale $action callback', (
      tester,
    ) async {
      final root = Directory.systemTemp.createTempSync(
        'ostinato-readonly-callback-',
      );
      addTearDown(() => root.deleteSync(recursive: true));
      var resolutions = 0;
      final store = GuitarJourneyProgressStore(
        directoryProvider: () async {
          resolutions++;
          return root;
        },
      );
      final course = _course();
      final lesson = course.lessons.first;
      GuitarLessonProgress? initial;
      if (action == GuitarProgressAction.selfReportedCompleted) {
        initial = await tester.runAsync(
          () => store.record(
            lessonId: lesson.id,
            contentVersion: lesson.progressVersionFor(course.contentVersion),
            action: GuitarProgressAction.practiced,
          ),
        );
      }
      Widget screen(bool readOnly) => _app(
        'en',
        GuitarJourneyLessonScreen(
          key: const ValueKey('same-lesson-state'),
          course: course,
          lesson: lesson,
          store: store,
          initial: initial,
          progressReadOnly: readOnly,
        ),
      );
      await tester.pumpWidget(_asMember(screen(false)));
      await tester.pumpAndSettle();
      final key = switch (action) {
        GuitarProgressAction.viewed => 'guitar-progress-viewed',
        GuitarProgressAction.practiced => 'guitar-progress-practiced',
        GuitarProgressAction.selfReportedCompleted =>
          'guitar-progress-completed',
      };
      final staleCallback = tester
          .widget<ButtonStyleButton>(find.byKey(Key(key)))
          .onPressed;
      expect(staleCallback, isNotNull);
      final file = File('${root.path}/guitar_journey_progress.v1.json');
      file.writeAsStringSync('{unreadable history');
      await tester.pumpWidget(_asMember(screen(true)));
      await tester.pumpAndSettle();
      _expectRecordingDisabled(tester);
      final before = resolutions;
      staleCallback!();
      await tester.pumpAndSettle();
      expect(
        resolutions,
        before,
        reason: 'shared save guard must reject before store.record',
      );
      expect(file.readAsStringSync(), '{unreadable history');
      expect(File('${file.path}.tmp').existsSync(), isFalse);
      expect(find.text('Practice entries: unknown'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
