import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/app_locale.dart';
import 'package:ostinato/app/guitar_journey.dart';
import 'package:ostinato/app/guitar_journey_progress.dart';
import 'package:ostinato/app/guitar_staff_diagram.dart';
import 'package:ostinato/app/screens/guitar_journey_screen.dart';
import 'support/localized_widget_ready.dart';

void main() {
  setUpAll(prepareRootTranslations);
  test('the original first-read score has four complete playable bars', () {
    final course = GuitarJourneyCourse.fromJson(
      jsonDecode(
            File('assets/content/guitar_journey.v1.json').readAsStringSync(),
          )
          as Map<String, dynamic>,
    );
    final lesson = course.lessons.singleWhere(
      (l) => l.id == 'guitar.journey.independent.next_cycle',
    );
    final score = lesson.learningLab!.drills[1].firstReadScore!;
    expect(score.bars.length, 4);
    expect(
      score.bars.map((bar) => bar.fold<int>(0, (sum, e) => sum + e.ticks)),
      everyElement(8),
    );
    final events = score.bars.expand((bar) => bar).toList();
    expect(events.length, 18);
    expect(events.where((event) => event.isRest).length, 2);
    expect(events.where((event) => !event.isRest).length, 16);
    expect(
      events.where((event) => event.ticks == 1).map((event) => event.sounding),
      ['C4', 'D4', 'D4', 'C4'],
    );
    expect(
      events.where((event) => !event.isRest).map((event) => event.written),
      [
        'E5',
        'F5',
        'G5',
        'F5',
        'B4',
        'C5',
        'D5',
        'C5',
        'G4',
        'B4',
        'D5',
        'C5',
        'B4',
        'E5',
        'G5',
        'E5',
      ],
    );
  });

  test('first-read parsing rejects isolated eighth notes inside a full bar', () {
    final raw =
        jsonDecode(
              File('assets/content/guitar_journey.v1.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    final score =
        raw['modules'][9]['lessons'][5]['learningLab']['drills'][1]['firstReadScore']
            as Map<String, dynamic>;
    (score['bars'] as List<dynamic>)[2] = [
      {'sounding': 'G3', 'ticks': 2},
      {'sounding': 'D4', 'ticks': 1},
      {'sounding': 'B3', 'ticks': 2},
      {'sounding': 'C4', 'ticks': 1},
      {'sounding': 'B3', 'ticks': 2},
    ];
    expect(
      () => GuitarJourneyFirstReadScore.fromJson(score),
      throwsA(isA<FormatException>()),
    );
  });

  test(
    'notation distinguishes written octave, staff position and fret interval',
    () {
      // Independent treble reference: E4 bottom line; each letter advances a space.
      expect(guitarOpenStaffNotes.map((n) => n.staffStep), [
        -7,
        -4,
        -1,
        2,
        4,
        7,
      ]);
      expect(guitarOpenStaffNotes.map((n) => n.ledgerSteps).toList(), [
        [-2, -4, -6],
        [-2, -4],
        <int>[],
        <int>[],
        <int>[],
        <int>[],
      ]);
      expect(guitarOpenStaffNotes.map((n) => n.string), [6, 5, 4, 3, 2, 1]);
      const semitone = {
        'C': 0,
        'D': 2,
        'E': 4,
        'F': 5,
        'G': 7,
        'A': 9,
        'B': 11,
      };
      int midi(String pitch) =>
          (int.parse(pitch.substring(1)) + 1) * 12 + semitone[pitch[0]]!;
      for (final note in [
        ...guitarOpenStaffNotes,
        ...guitarFirstStringStaffNotes,
      ]) {
        expect(midi(note.written) - midi(note.sounding), 12);
      }
      expect(guitarFirstStringStaffNotes.map((n) => n.staffStep), [7, 8, 9]);
      for (final note in guitarFirstStringStaffNotes) {
        expect(midi(note.sounding) - midi('E4'), note.fret);
      }
    },
  );

  for (final language in ['en', 'tr']) {
    testWidgets(
      'real staff lesson fits 320px at 200percent in $language without a practice record',
      (tester) async {
        tester.view.physicalSize = const Size(320, 812);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final root = Directory.systemTemp.createTempSync('guitar-staff-view-');
        addTearDown(() => root.deleteSync(recursive: true));
        final course = GuitarJourneyCourse.fromJson(
          jsonDecode(
                File(
                  'assets/content/guitar_journey.v1.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>,
        );
        final lesson = course.lessons.singleWhere(
          (l) => l.id == 'guitar.journey.reading.staff',
        );
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(language),
            supportedLocales: appSupportedLocales,
            localizationsDelegates: appLocalizationsDelegates,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
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
        final acknowledge = find.byKey(const Key('guitar-session-acknowledge'));
        await tester.ensureVisible(acknowledge);
        await tester.tap(acknowledge);
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const Key('guitar-staff-diagram')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(GuitarStaffDiagram), findsOneWidget);
        expect(
          find.textContaining(
            language == 'tr'
                ? 'yazılı E3 → seslenen E2'
                : 'written E3 → sounding E2',
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            language == 'tr'
                ? 'ses ölçümü veya başarı testi değildir'
                : 'not an audio measurement or skill test',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        expect(root.listSync(recursive: true).whereType<File>(), isEmpty);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('the last lesson keeps its first-read card hidden until reveal', (
    tester,
  ) async {
    final root = Directory.systemTemp.createTempSync(
      'guitar-first-read-hidden-',
    );
    addTearDown(() => root.deleteSync(recursive: true));
    final course = GuitarJourneyCourse.fromJson(
      jsonDecode(
            File('assets/content/guitar_journey.v1.json').readAsStringSync(),
          )
          as Map<String, dynamic>,
    );
    final lesson = course.lessons.singleWhere(
      (l) => l.id == 'guitar.journey.independent.next_cycle',
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationsDelegates,
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
    await tester.tap(find.byKey(const Key('guitar-session-acknowledge')));
    await tester.pumpAndSettle();

    expect(find.textContaining('1 | E4(1) F4(1)'), findsNothing);
    expect(find.byKey(const Key('guitar-first-read-score')), findsNothing);
    expect(find.byKey(const Key('guitar-first-read-reveal')), findsOneWidget);
    expect(root.listSync(recursive: true).whereType<File>(), isEmpty);
  });

  for (final language in ['en', 'tr']) {
    testWidgets(
      'the final score and readable equivalent fit 320px at 200percent in $language',
      (tester) async {
        tester.view.physicalSize = const Size(320, 812);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final root = Directory.systemTemp.createTempSync('guitar-first-read-');
        addTearDown(() => root.deleteSync(recursive: true));
        final course = GuitarJourneyCourse.fromJson(
          jsonDecode(
                File(
                  'assets/content/guitar_journey.v1.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>,
        );
        final lesson = course.lessons.singleWhere(
          (l) => l.id == 'guitar.journey.independent.next_cycle',
        );
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(language),
            supportedLocales: appSupportedLocales,
            localizationsDelegates: appLocalizationsDelegates,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
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
        final acknowledge = find.byKey(const Key('guitar-session-acknowledge'));
        await tester.ensureVisible(acknowledge);
        await tester.tap(acknowledge);
        await tester.pumpAndSettle();
        final reveal = find.byKey(const Key('guitar-first-read-reveal'));
        expect(reveal, findsOneWidget);
        expect(find.byType(GuitarFirstReadScore), findsNothing);
        await tester.ensureVisible(reveal);
        await tester.tap(reveal);
        await tester.pumpAndSettle();
        expect(find.byType(GuitarFirstReadScore), findsOneWidget);
        expect(
          find.textContaining(
            language == 'tr'
                ? 'Dört porteli ölçüyü veya erişilebilir nota ve süre metnini kullanarak'
                : 'Use the four staff bars or their accessible note-and-duration text',
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            language == 'tr'
                ? 'Porteyi veya aşağıdaki büyütülebilir nota ve süre metnini kullan'
                : 'Use the staff or the scalable note-and-duration text below',
          ),
          findsOneWidget,
        );
        final detailedTask = find.textContaining(
          language == 'tr'
              ? 'Sonraki bir gün, bu yeni özgün 4/4'
              : 'On a later day, open this new original 4/4',
        );
        expect(detailedTask, findsOneWidget);
        expect(
          tester.getTopLeft(find.byType(GuitarFirstReadScore)).dy,
          lessThan(tester.getTopLeft(detailedTask).dy),
        );
        expect(
          tester
              .getTopLeft(find.text(language == 'tr' ? '4. ölçü' : 'Bar 4'))
              .dy,
          lessThan(
            tester
                .getTopLeft(
                  find.textContaining(
                    language == 'tr'
                        ? '1. ölçü: yazılı E5 (Mi5) (duyulan E4 (Mi4)), dörtlük'
                        : 'Bar 1: written E5 (sounds E4), quarter note',
                  ),
                )
                .dy,
          ),
        );
        expect(
          find.textContaining(language == 'tr' ? '1 | Mi4' : '1 | E4'),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            language == 'tr'
                ? '1. ölçü: yazılı E5 (Mi5) (duyulan E4 (Mi4)), dörtlük'
                : 'Bar 1: written E5 (sounds E4), quarter note',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        expect(root.listSync(recursive: true).whereType<File>(), isEmpty);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
