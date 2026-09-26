import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ostinato/app/account_connection.dart';
import 'package:ostinato/app/app_locale.dart';
import 'package:ostinato/app/audio/audio_capture_channel.dart';
import 'package:ostinato/app/guitar_journey.dart';
import 'package:ostinato/app/guitar_journey_progress.dart';
import 'package:ostinato/app/screens/guitar_journey_screen.dart';

/// Native asset/plugin/UI/persistence smoke. It never asks microphone
/// permission or calls capture.start, and does not prove physical audio DSP.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native guitar course read practice self-report reopen and audio bridge without capture',
    (tester) async {
      final course = await GuitarJourneyCourse.load();
      expect(course.modules.length, 10);
      expect(course.lessons.length, 60);
      final first = course.lessons.first;
      final nativeSupport = await getApplicationSupportDirectory();
      final root = Directory(
        '${nativeSupport.path}/guitar_course_smoke_${DateTime.now().microsecondsSinceEpoch}',
      );
      await root.create();
      const owner = '00000000-0000-4000-8000-000000000026';
      final store = GuitarJourneyProgressStore(
        accountUserId: owner,
        directoryProvider: () async => root,
      );
      final channel = MethodChannelAudioCaptureChannel();
      final captured = <RawAudioChunkEvent>[];
      final sub = channel.events.listen((event) {
        if (event is RawAudioChunkEvent) captured.add(event);
      });
      try {
        await channel.prepare(); // event registration/ready only; no capture
        await channel.stop();
        expect(captured, isEmpty);
        Widget app() => AccountScope(
          connection: null,
          currentUserId: owner,
          child: MaterialApp(
            locale: const Locale('en'),
            supportedLocales: appSupportedLocales,
            localizationsDelegates: appLocalizationsDelegates,
            home: GuitarJourneyScreen(progressStoreFactory: (_) => store),
          ),
        );
        Future<void> waitText(String text) async {
          for (
            var i = 0;
            i < 80 && find.textContaining(text).evaluate().isEmpty;
            i++
          ) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          expect(find.textContaining(text), findsOneWidget);
        }

        Future<void> tapText(String text) async {
          final finder = find.text(text);
          await tester.ensureVisible(finder);
          await tester.pumpAndSettle();
          await tester.tap(finder);
          await tester.pumpAndSettle();
        }

        Future<void> waitPracticeEnabled() async {
          final button = find.widgetWithText(OutlinedButton, 'Record practice');
          for (var i = 0; i < 80; i++) {
            if (tester.widget<OutlinedButton>(button).onPressed != null) return;
            await tester.pump(const Duration(milliseconds: 100));
          }
          expect(tester.widget<OutlinedButton>(button).onPressed, isNotNull);
        }

        await tester.pumpWidget(app());
        await waitText('0 of 60 self-reported complete');
        await tapText('Open lesson');
        expect(
          find.byKey(Key('guitar-lesson-title-${first.id}')),
          findsOneWidget,
        );
        expect(find.text(first.selfCheck.en), findsOneWidget);
        await tapText('Mark viewed');
        await waitPracticeEnabled();
        await tapText('Record practice');
        await waitText('Practice entries: 1');
        await tapText('I completed this practice');
        await waitText('Practice entries: 1');
        // I/O completion is read back independently of the painted button.
        Map<String, GuitarLessonProgress> records = {};
        for (var i = 0; i < 80; i++) {
          records = await store.load();
          if (records['${course.contentVersion}|${first.id}']
                  ?.selfReportedCompletedAt !=
              null) {
            break;
          }
          await tester.pump(const Duration(milliseconds: 100));
        }
        final saved = records['${course.contentVersion}|${first.id}'];
        expect(saved?.seenAt, isNotNull);
        expect(saved?.practiceCount, 1);
        expect(saved?.selfReportedCompletedAt, isNotNull);
        await tester.pumpWidget(const MaterialApp(home: SizedBox()));
        await tester.pumpAndSettle();
        await tester.pumpWidget(app());
        await waitText('1 of 60 self-reported complete');
        // Reopened route reads disk, not initialProgress or an in-memory record.
        expect((await store.load()).values.single.practiceCount, 1);
        expect(captured, isEmpty);
      } finally {
        await channel.stop();
        await sub.cancel();
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        // Exact directory created by this test only; no other app/user data.
        if (await root.exists()) await root.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
