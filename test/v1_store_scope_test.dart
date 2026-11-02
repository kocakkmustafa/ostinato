// v1 store scope (founder, 2026-11-02): the v1 guitar course is open; voice
// and piano say "Coming soon"; the pre-v1 written courses (60-lesson guitar
// journey, ukulele, bass, voice, piano) and the written recall page that
// links to them are not reachable from home, library or the guitar page.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/content.dart';
import 'package:ostinato/app/cue_text.dart';
import 'package:ostinato/app/design/app_scope.dart';
import 'package:ostinato/app/ostinato_release_policy.dart';
import 'package:ostinato/app/practice/loop/v1_practice_list_screen.dart';
import 'package:ostinato/app/screens/instrument_screen.dart';
import 'package:ostinato/app/screens/library_screen.dart';

void main() {
  test('the release policy hides the pre-v1 written courses', () {
    expect(ostinatoLegacyWrittenCoursesVisible, isFalse);
  });

  test('legacy course screens are opened only behind the release flag', () {
    // Every file in lib/ that constructs a pre-v1 course screen (or the
    // recall page that links to them) must be one of these, and each one
    // guards the link with ostinatoLegacyWrittenCoursesVisible. study_review
    // itself is reachable only through StudyReviewEntry on the library.
    final screens = RegExp(
      r'\b(UkuleleBeginnerScreen|BassBeginnerScreen|VocalBeginnerScreen|'
      r'PianoBeginnerScreen|GuitarJourneyScreen|StudyReviewEntry|'
      r'StudyReviewPage)\(',
    );
    final users = <String>{};
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final src = f.readAsStringSync();
      for (final m in screens.allMatches(src)) {
        // Skip the class's own constructor/super calls.
        final line = src.substring(
          src.lastIndexOf('\n', m.start) + 1,
          src.indexOf('\n', m.start),
        );
        if (line.contains('const ${m[1]}({') ||
            line.contains('State<${m[1]}>') ||
            line.trimLeft().startsWith('class ')) {
          continue;
        }
        users.add(f.path);
      }
    }
    expect(
      users,
      unorderedEquals([
        'lib/app/screens/library_screen.dart',
        'lib/app/screens/instrument_screen.dart',
        'lib/app/study_review.dart',
      ]),
    );
    for (final path in [
      'lib/app/screens/library_screen.dart',
      'lib/app/screens/instrument_screen.dart',
    ]) {
      expect(
        File(path).readAsStringSync(),
        contains('ostinatoLegacyWrittenCoursesVisible'),
        reason: path,
      );
    }
  });

  test('ear training is not shipped: not bundled, no screen loads it', () {
    // Build 9: ear training is "coming soon" like voice and piano. Its
    // paywall constant exists, but its lessons are not packaged.
    expect(
      File('pubspec.yaml').readAsStringSync(),
      isNot(contains('content/v1/ear')),
    );
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      expect(
        f.readAsStringSync(),
        isNot(contains('content/v1/ear')),
        reason: f.path,
      );
    }
  });

  group('real screens', () {
    late ContentRepository repo;
    late CueTextResolver cue;

    Future<void> load(WidgetTester tester) async {
      repo = (await tester.runAsync(ContentRepository.load))!;
      cue = (await tester.runAsync(CueTextResolver.load))!;
    }

    Widget host(Widget home) => ContentRepositoryScope(
      repo: repo,
      cueText: cue,
      child: MaterialApp(home: home),
    );

    testWidgets('library: no ukulele, bass, written voice or recall entry', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await load(tester);
      await tester.pumpWidget(host(LibraryScreen(repo: repo, cueText: cue)));
      await tester.pumpAndSettle();
      for (final key in [
        'ukulele-beginner-entry',
        'bass-beginner-entry',
        'vocal-written-course',
        'study-review-entry',
      ]) {
        expect(find.byKey(Key(key)), findsNothing, reason: key);
      }
      expect(find.textContaining('Ukulele'), findsNothing);
      expect(find.textContaining('Bass'), findsNothing);
      // Voice and piano keep the v1 "Coming soon" line.
      expect(find.byKey(const Key('coming-soon-voice')), findsOneWidget);
      expect(find.byKey(const Key('coming-soon-piano')), findsOneWidget);
      expect(find.byKey(const Key('guitar-card-measured')), findsOneWidget);
    });

    testWidgets('guitar page opens the v1 course, not the 60-lesson journey', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await load(tester);
      await tester.pumpWidget(
        host(
          InstrumentScreenRoute(
            discipline: repo.disciplines.firstWhere((d) => d.id == 'guitar'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('guitar-journey-entry')), findsNothing);
      expect(
        find.byKey(const Key('guitar-measured-practice-entry')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('guitar-note-observation-entry')),
        findsOneWidget,
      );
      final course = find.byKey(const Key('guitar-course-entry'));
      await tester.ensureVisible(course);
      await tester.tap(course);
      // The course loads from the bundle (a spinner meanwhile): pump the
      // route transition only.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(V1PracticeListScreen), findsOneWidget);
    });

    testWidgets('piano page has no written-course link', (tester) async {
      tester.view.physicalSize = const Size(390, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await load(tester);
      await tester.pumpWidget(
        host(
          InstrumentScreenRoute(
            discipline: repo.disciplines.firstWhere((d) => d.id == 'piano'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('piano-beginner-entry')), findsNothing);
    });
  });
}
