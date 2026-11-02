import 'dart:convert';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/piano_beginner.dart';
import 'package:ostinato/app/app_locale.dart';
import 'package:ostinato/app/screens/piano_notation.dart';
import 'package:ostinato/app/content.dart';
import 'package:ostinato/app/cue_text.dart';
import 'package:ostinato/app/design/app_scope.dart';
import 'package:ostinato/app/screens/instrument_screen.dart';
import 'package:ostinato/app/screens/piano_beginner_screen.dart';
import 'package:ostinato/app/ostinato_release_policy.dart';

import 'support/localized_widget_ready.dart';
import 'support/paid_access_scope.dart';

/// Paywall A: course walks run as a member; the lock itself is covered by
/// course_access_test.dart.
Widget _asMember(Widget app) => PaidAccessProbe().wrap(app);

class Files extends CachingAssetBundle {
  Files({this.corrupt = false});
  final bool corrupt;
  @override
  Future<ByteData> load(String key) async {
    final bytes = File(key).readAsBytesSync();
    if (corrupt && key == pianoAsset) bytes[10] ^= 1;
    return ByteData.sublistView(Uint8List.fromList(bytes));
  }
}

class DelayedFiles extends Files {
  DelayedFiles({super.corrupt});
  final gate = Completer<void>();
  @override
  Future<ByteData> load(String key) async {
    await gate.future;
    return super.load(key);
  }
}

class RecoveringFiles extends Files {
  bool failed = false;
  @override
  Future<ByteData> load(String key) async {
    if (key == pianoAsset && !failed) {
      failed = true;
      return Files(corrupt: true).load(key);
    }
    return super.load(key);
  }
}

Widget _app(AssetBundle bundle, {String locale = 'en', Key? key}) =>
    MaterialApp(
      key: key,
      locale: Locale(locale),
      theme: ThemeData(fontFamily: 'Hanken Grotesk'),
      supportedLocales: appSupportedLocales,
      localizationsDelegates: appLocalizationsDelegates,
      home: PianoBeginnerScreen(bundle: bundle),
    );
Future<void> _centre(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    250,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  final y = tester.getCenter(target).dy;
  final position = tester
      .state<ScrollableState>(find.byType(Scrollable).first)
      .position;
  position.jumpTo(
    (position.pixels + y - 350).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await prepareRootTranslations();
    final font = FontLoader('Hanken Grotesk')
      ..addFont(rootBundle.load('assets/fonts/HankenGrotesk-Regular.ttf'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  testWidgets(
    'late old bundle cannot replace newer result; back/unmount while pending',
    (tester) async {
      final old = DelayedFiles(corrupt: true), latest = DelayedFiles();
      await tester.pumpWidget(_asMember(_app(old)));
      await tester.pump();
      await tester.pumpWidget(_asMember(_app(latest)));
      await tester.pump();
      latest.gate.complete();
      await tester.pumpAndSettle();
      expect(
        find.text('Piano / keyboard: beginner foundation'),
        findsOneWidget,
      );
      old.gate.complete();
      await tester.pumpAndSettle();
      expect(
        find.text('Piano / keyboard: beginner foundation'),
        findsOneWidget,
      );
      final pending = DelayedFiles();
      await tester.pumpWidget(
        _asMember(
          MaterialApp(
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PianoBeginnerScreen(bundle: pending),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byType(BackButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      pending.gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('Open'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('successful retry uses real verified assets', (tester) async {
    await tester.pumpWidget(_asMember(_app(RecoveringFiles())));
    await tester.pumpAndSettle();
    expect(find.text('Written course unavailable.'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Piano / keyboard: beginner foundation'), findsOneWidget);
  });
  test(
    'staff task answer data has correct pitches and four-beat aligned bars',
    () {
      expect(pianoStaffPosition('E4', treble: true), 0);
      expect(pianoStaffPosition('G4', treble: true), 2);
      expect(pianoStaffPosition('C4', treble: true), -2);
      expect(pianoStaffPosition('F3', treble: false), 6);
      expect(pianoStaffPosition('C4', treble: false), 10);
      expect(pianoReadingRight[0].map((n) => n.pitch), ['E4', 'F4', 'G4']);
      expect(pianoReadingRight[1].map((n) => n.pitch), ['G4', 'E4', 'D4']);
      expect(pianoReadingLeft.map((b) => b.single.pitch), ['C3', 'G3']);
      for (final bars in [
        pianoReadingRight,
        pianoReadingLeft,
        pianoStudyRight,
        pianoStudyLeft,
      ]) {
        for (final bar in bars) {
          expect(bar.fold<double>(0, (sum, n) => sum + n.beats), 4);
        }
      }
    },
  );
  for (final locale in ['en', 'tr']) {
    testWidgets(
      '$locale every lesson, hidden answers and navigation at 2x text',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final course = PianoCourse.fromJson(
          jsonDecode(File(pianoAsset).readAsStringSync()),
        );
        await tester.pumpWidget(
          _asMember(
            MaterialApp(
              locale: Locale(locale),
              theme: ThemeData(fontFamily: 'Hanken Grotesk'),
              supportedLocales: appSupportedLocales,
              localizationsDelegates: appLocalizationsDelegates,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
              home: PianoBeginnerScreen(bundle: Files()),
            ),
          ),
        );
        await waitForLocalizedFixture(
          tester,
          languageTag: locale,
          anchor: find.descendant(
            of: find.byType(PianoBeginnerScreen),
            matching: find.byType(ListView),
          ),
          reason:
              'Piano course and packaged translations must be ready before scrolling',
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byKey(const Key('piano-01')),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await _centre(tester, find.byKey(const Key('piano-01')));
        await tester.tap(find.byKey(const Key('piano-01')));
        await tester.pumpAndSettle();
        for (var i = 0; i < course.lessons.length; i++) {
          expect(
            find.text(
              locale == 'tr'
                  ? course.lessons[i].title.tr
                  : course.lessons[i].title.en,
            ),
            findsOneWidget,
          );
          if (i == 13 || i == 14) {
            final answer = find.byKey(Key('piano-answers-${i + 1}'));
            await tester.scrollUntilVisible(
              answer,
              300,
              scrollable: find.byType(Scrollable).first,
            );
            expect(
              find.textContaining(
                locale == 'tr'
                    ? 'E4 (Mi4) dörtlük (vuruş 1)'
                    : 'E4 quarter (beat 1)',
              ),
              findsNothing,
            );
            await tester.ensureVisible(answer);
            await tester.pumpAndSettle();
            await tester.tap(
              find
                  .descendant(of: answer, matching: find.byType(ListTile))
                  .first,
            );
            await tester.pumpAndSettle();
            expect(
              find.textContaining(locale == 'tr' ? 'sağ' : 'right'),
              findsWidgets,
            );
            expect(
              find.textContaining(
                locale == 'tr'
                    ? 'E4 (Mi4) dörtlük (vuruş 1)'
                    : 'E4 quarter (beat 1)',
              ),
              findsNWidgets(i == 13 ? 1 : 2),
            );
          }
          if (i < course.lessons.length - 1) {
            final next = find.text(
              locale == 'tr' ? 'Sonraki ders' : 'Next lesson',
            );
            await tester.scrollUntilVisible(
              next,
              300,
              scrollable: find.byType(Scrollable).first,
            );
            await tester.drag(
              find.byType(ListView).first,
              const Offset(0, -150),
            );
            await tester.pumpAndSettle();
            await tester.tap(next);
            await tester.pumpAndSettle();
          }
          expect(tester.takeException(), isNull);
        }
        expect(
          find.text(locale == 'tr' ? 'Sonraki ders' : 'Next lesson'),
          findsNothing,
        );
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.byType(PianoBeginnerScreen), findsOneWidget);
      },
    );
    for (final lesson in [3, 7, 8, 14, 15]) {
      testWidgets(
        '$locale original vector lesson $lesson render at narrow 2x',
        (tester) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final boundary = GlobalKey();
          await tester.pumpWidget(
            _asMember(
              MaterialApp(
                locale: Locale(locale),
                theme: ThemeData(fontFamily: 'Hanken Grotesk'),
                supportedLocales: appSupportedLocales,
                localizationsDelegates: appLocalizationsDelegates,
                home: Scaffold(
                  body: RepaintBoundary(
                    key: boundary,
                    child: Material(
                      color: Colors.white,
                      child: MediaQuery(
                        data: const MediaQueryData(
                          textScaler: TextScaler.linear(2),
                        ),
                        child: SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: PianoNotation(lesson: lesson),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          Future<void> capture(String suffix) async {
            await tester.runAsync(() async {
              final image =
                  await (boundary.currentContext!.findRenderObject()
                          as RenderRepaintBoundary)
                      .toImage();
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final file = File('../notation-qa/$locale-$lesson$suffix.png');
              file.parent.createSync(recursive: true);
              file.writeAsBytesSync(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }

          await capture('');
          if (lesson == 15) {
            final position = tester
                .state<ScrollableState>(find.byType(Scrollable).first)
                .position;
            position.jumpTo(position.maxScrollExtent);
            await tester.pumpAndSettle();
            await capture('-bottom');
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('actual piano page links the written course only in legacy builds', (
    tester,
  ) async {
    final repo = (await tester.runAsync(ContentRepository.load))!;
    final cue = (await tester.runAsync(CueTextResolver.load))!;
    await tester.pumpWidget(
      _asMember(
        ContentRepositoryScope(
          repo: repo,
          cueText: cue,
          child: MaterialApp(
            home: InstrumentScreenRoute(
              discipline: repo.disciplines.firstWhere((d) => d.id == 'piano'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // v1 store build: the pre-v1 written course is not linked.
    if (!ostinatoLegacyWrittenCoursesVisible) {
      expect(find.byKey(const Key('piano-beginner-entry')), findsNothing);
      return;
    }
    await tester.scrollUntilVisible(
      find.byKey(const Key('piano-beginner-entry')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('piano-beginner-entry')));
    await tester.pumpAndSettle();
    expect(find.byType(PianoBeginnerScreen), findsOneWidget);
    expect(find.text('Piano / keyboard: beginner foundation'), findsOneWidget);
  });
  final source =
      jsonDecode(File(pianoAsset).readAsStringSync()) as Map<String, dynamic>;
  test('complete translated ordered curriculum and integrity', () async {
    final course = await PianoCourse.load(bundle: Files());
    expect(course.lessons.length, 25);
    expect(course.lessons.last.id, 'piano-25');
  });
  test('strict fields, translations, sequence, schema and completeness', () {
    for (final mutate in <void Function(Map<String, dynamic>)>[
      (m) => m['schemaVersion'] = 2,
      (m) => m['schemaVersion'] = 1.0,
      (m) => m['unexpected'] = true,
      (m) => (m['title'] as Map)['tr'] = ' ',
      (m) => (m['lessons'] as List).removeLast(),
      (m) => (m['lessons'][1] as Map)['id'] = 'piano-01',
      (m) => (m['lessons'][0] as Map)['score'] = 100,
    ]) {
      final copy = jsonDecode(jsonEncode(source)) as Map<String, dynamic>;
      mutate(copy);
      expect(() => PianoCourse.fromJson(copy), throwsFormatException);
    }
  });
  test('tampered asset fails closed', () async {
    await expectLater(
      PianoCourse.load(bundle: Files(corrupt: true)),
      throwsA(anything),
    );
  });
  testWidgets('read, next, back and large text stay available', (tester) async {
    await tester.pumpWidget(
      _asMember(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: PianoBeginnerScreen(bundle: Files()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(const Key('piano-01')), 250);
    await _centre(tester, find.byKey(const Key('piano-01')));
    await tester.tap(find.byKey(const Key('piano-01')));
    await tester.pumpAndSettle();
    expect(find.text('Self-check'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Next lesson'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(ListView).first, const Offset(0, -100));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next lesson'));
    await tester.pumpAndSettle();
    expect(find.text('Keyboard map'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(PianoBeginnerScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('replacement load does not show stale course; failure retries', (
    tester,
  ) async {
    await tester.pumpWidget(
      _asMember(MaterialApp(home: PianoBeginnerScreen(bundle: Files()))),
    );
    await tester.pumpAndSettle();
    expect(find.text('Piano / keyboard: beginner foundation'), findsOneWidget);
    await tester.pumpWidget(
      _asMember(
        MaterialApp(home: PianoBeginnerScreen(bundle: Files(corrupt: true))),
      ),
    );
    expect(find.byKey(const Key('piano-01')), findsNothing);
    await tester.pumpAndSettle();
    expect(find.text('Written course unavailable.'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('piano-01')), findsNothing);
  });
}
