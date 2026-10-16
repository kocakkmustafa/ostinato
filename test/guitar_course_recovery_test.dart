import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/app_locale.dart';
import 'package:ostinato/app/guitar_journey.dart';
import 'package:ostinato/app/guitar_journey_progress.dart';
import 'package:ostinato/app/screens/guitar_journey_screen.dart';

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

GuitarJourneyCourse _course() => GuitarJourneyCourse.fromJson(
  jsonDecode(File('assets/content/guitar_journey.v1.json').readAsStringSync())
      as Map<String, dynamic>,
);

void main() {
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
      'progress retry preserves corrupt bytes then recovers ($locale)',
      (tester) async {
        final root = Directory.systemTemp.createTempSync('ostinato-recovery-');
        addTearDown(() => root.deleteSync(recursive: true));
        final file = File('${root.path}/guitar_journey_progress.v1.json');
        file.writeAsStringSync('{broken guest history');
        final store = GuitarJourneyProgressStore(
          directoryProvider: () async => root,
        );
        await tester.pumpWidget(
          _app(
            locale,
            GuitarJourneyScreen(
              initialCourse: _course(),
              progressStoreFactory: (_) => store,
            ),
          ),
        );
        final error = tr
            ? 'Yerel ilerlemen okunamadı. Kayıt sıfırlanmadı.'
            : 'Your local progress could not be read. It has not been reset.';
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
      await tester.pumpWidget(screen());
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
      await tester.pumpWidget(screen());
      await _waitText(tester, one);
      final otherAccount = GuitarJourneyProgressStore(
        directoryProvider: () async => root,
        accountUserId: '11111111-1111-4111-8111-111111111111',
      );
      expect(await tester.runAsync(otherAccount.load), isEmpty);
      expect(tester.takeException(), isNull);
    });
  }
}
