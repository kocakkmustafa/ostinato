import 'dart:convert';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/bass_beginner.dart';
import 'package:ostinato/app/app_locale.dart';
import 'package:ostinato/app/screens/bass_diagrams.dart';
import 'package:ostinato/app/content.dart';
import 'package:ostinato/app/cue_text.dart';
import 'package:ostinato/app/design/app_scope.dart';
import 'package:ostinato/app/screens/library_screen.dart';
import 'package:ostinato/app/screens/bass_beginner_screen.dart';

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
    if (corrupt && key == bassAsset) bytes[10] ^= 1;
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
    if (key == bassAsset && !failed) {
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
      home: BassBeginnerScreen(bundle: bundle),
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
        find.text('Bass: four-string beginner foundation'),
        findsOneWidget,
      );
      old.gate.complete();
      await tester.pumpAndSettle();
      expect(
        find.text('Bass: four-string beginner foundation'),
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
                    builder: (_) => BassBeginnerScreen(bundle: pending),
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
    expect(find.text('Bass: four-string beginner foundation'), findsOneWidget);
  });
  for (final locale in ['en', 'tr']) {
    testWidgets(
      '$locale every lesson, hidden answers and navigation at 2x text',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final course = BassCourse.fromJson(
          jsonDecode(File(bassAsset).readAsStringSync()),
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
              home: BassBeginnerScreen(bundle: Files()),
            ),
          ),
        );
        await waitForLocalizedFixture(
          tester,
          languageTag: locale,
          anchor: find.descendant(
            of: find.byType(BassBeginnerScreen),
            matching: find.byType(ListView),
          ),
          reason:
              'Bass course and packaged translations must be ready before scrolling',
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byKey(const Key('bass-01')),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await _centre(tester, find.byKey(const Key('bass-01')));
        await tester.tap(find.byKey(const Key('bass-01')));
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
          if (i == 11) {
            final answer = find.byKey(const Key('bass-tab-answers'));
            final answerText = find.textContaining(
              locale == 'tr'
                  ? 'vuruş 1: tel 4, perde 0 (E1 (Mi1))'
                  : 'beat 1: string 4, fret 0 (E1)',
            );
            expect(answerText, findsNothing);
            await _centre(tester, answer);
            await tester.tap(
              find
                  .descendant(of: answer, matching: find.byType(ListTile))
                  .first,
            );
            await tester.pumpAndSettle();
            expect(answerText, findsOneWidget);
            const expectedPairs = [
              (4, 0),
              (4, 3),
              (3, 0),
              (3, 2),
              (2, 0),
              (2, 2),
              (1, 0),
              (4, 0),
            ];
            for (var j = 0; j < expectedPairs.length; j++) {
              final pair = expectedPairs[j];
              expect(
                find.textContaining(
                  locale == 'tr'
                      ? 'vuruş ${j % 4 + 1}: tel ${pair.$1}, perde ${pair.$2}'
                      : 'beat ${j % 4 + 1}: string ${pair.$1}, fret ${pair.$2}',
                ),
                findsOneWidget,
              );
            }
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
        expect(find.byType(BassBeginnerScreen), findsOneWidget);
        final readAgain = find.byKey(const Key('bass-12'));
        await _centre(tester, readAgain);
        await tester.tap(readAgain);
        await tester.pumpAndSettle();
        expect(
          find.textContaining(
            locale == 'tr'
                ? 'vuruş 1: tel 4, perde 0 (E1 (Mi1))'
                : 'beat 1: string 4, fret 0 (E1)',
          ),
          findsNothing,
        );
      },
    );
    for (final lesson in [1, 4, 11, 12, 13, 16]) {
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
                            child: BassDiagrams(
                              course: BassCourse.fromJson(
                                jsonDecode(File(bassAsset).readAsStringSync()),
                              ),
                              lesson: BassCourse.fromJson(
                                jsonDecode(File(bassAsset).readAsStringSync()),
                              ).lessons[lesson - 1],
                            ),
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
              final file = File('../bass-qa/$locale-$lesson$suffix.png');
              file.parent.createSync(recursive: true);
              file.writeAsBytesSync(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }

          await capture('');
          if (lesson == 4) {
            await _centre(tester, find.byKey(const Key('bass-vector-frets')));
            await capture('-frets');
          }
          if (lesson == 12) {
            final answer = find.byKey(const Key('bass-tab-answers'));
            await _centre(tester, answer);
            await tester.tap(
              find
                  .descendant(of: answer, matching: find.byType(ListTile))
                  .first,
            );
            await tester.pumpAndSettle();
            final expected = locale == 'tr'
                ? 'vuruş 1: tel 4, perde 0 (E1 (Mi1))'
                : 'beat 1: string 4, fret 0 (E1)';
            await _centre(tester, find.textContaining(expected));
            await capture('-answers-bar1');
            await _centre(
              tester,
              find.textContaining(
                locale == 'tr'
                    ? 'vuruş 1: tel 2, perde 0 (D2 (Re2))'
                    : 'beat 1: string 2, fret 0 (D2)',
              ),
            );
            await capture('-answers-bar2');
          }
          if (lesson == 16) {
            final horizontal = find
                .byWidgetPredicate(
                  (w) =>
                      w is SingleChildScrollView &&
                      w.scrollDirection == Axis.horizontal,
                )
                .first;
            await tester.drag(horizontal, const Offset(-300, 0));
            await tester.pumpAndSettle();
            final state = tester.state<ScrollableState>(
              find
                  .descendant(of: horizontal, matching: find.byType(Scrollable))
                  .first,
            );
            expect(state.position.pixels, greaterThan(0));
            await capture('-panned');
            for (var bar = 0; bar < 8; bar++) {
              final table = find
                  .byWidgetPredicate(
                    (w) =>
                        w is SingleChildScrollView &&
                        w.scrollDirection == Axis.horizontal,
                  )
                  .at(bar);
              await _centre(tester, table);
              final scroller = tester.state<ScrollableState>(
                find
                    .descendant(of: table, matching: find.byType(Scrollable))
                    .first,
              );
              scroller.position.jumpTo(0);
              await tester.pumpAndSettle();
              await capture('-bar${bar + 1}-left');
              await tester.drag(table, const Offset(-700, 0));
              await tester.pumpAndSettle();
              expect(
                scroller.position.pixels,
                scroller.position.maxScrollExtent,
              );
              await capture('-bar${bar + 1}-right');
              scroller.position.jumpTo(scroller.position.maxScrollExtent / 2);
              await tester.pumpAndSettle();
              await capture('-bar${bar + 1}-middle');
            }
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

  testWidgets('actual library entry opens packaged written course', (
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
            home: LibraryScreen(repo: repo, cueText: cue),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('bass-beginner-entry')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('bass-beginner-entry')));
    await tester.pumpAndSettle();
    expect(find.byType(BassBeginnerScreen), findsOneWidget);
    expect(find.text('Bass: four-string beginner foundation'), findsOneWidget);
  });
  final source =
      jsonDecode(File(bassAsset).readAsStringSync()) as Map<String, dynamic>;
  test('complete translated ordered curriculum and integrity', () async {
    final course = await BassCourse.load(bundle: Files());
    expect(course.lessons.length, 24);
    expect(course.lessons.last.id, 'bass-24');
  });
  test('strict fields, translations, sequence, schema and completeness', () {
    for (final mutate in <void Function(Map<String, dynamic>)>[
      (m) => m['schemaVersion'] = 2,
      (m) => m['schemaVersion'] = 1.0,
      (m) => m['unexpected'] = true,
      (m) => (m['title'] as Map)['tr'] = ' ',
      (m) => (m['lessons'] as List).removeLast(),
      (m) => (m['lessons'][1] as Map)['id'] = 'bass-01',
      (m) => (m['lessons'][0] as Map)['score'] = 100,
      (m) => m['tuning'] = 'piccolo:E2-A2-D3-G3',
      (m) => m['pitchConvention'] = 'written-only',
      (m) => (m['tab'][0] as Map)['string'] = 0,
      (m) => (m['tab'][0] as Map)['fret'] = 1.0,
      (m) => (m['lessons'][0] as Map)['diagrams'] = ['unknown'],
      (m) => (m['study'][0] as Map)['events'] = [],
      (m) => (m['study'][0]['events'][0] as Map)['kind'] = 'AI-detected',
      (m) => (m['study'][0]['events'][1] as Map)['string'] = 4,
      (m) => (m['study'][0]['events'][0] as Map)['fret'] = 4,
      (m) => (m['study'][0]['events'][0] as Map).remove('string'),
    ]) {
      final copy = jsonDecode(jsonEncode(source)) as Map<String, dynamic>;
      mutate(copy);
      expect(() => BassCourse.fromJson(copy), throwsFormatException);
    }
  });
  test('sounding pitches, root/fifth/octave and written staff positions', () {
    final course = BassCourse.fromJson(source);
    expect(bassOpenMidi4to1, [28, 33, 38, 43]);
    expect(course.tab.map((n) => n.pitch), [
      'E1',
      'G1',
      'A1',
      'B1',
      'D2',
      'E2',
      'G2',
      'E1',
    ]);
    expect(bassOpenMidi4to1[1] + 2 - bassOpenMidi4to1[0], 7);
    expect(bassOpenMidi4to1[2] + 2 - bassOpenMidi4to1[0], 12);
    expect(['E2', 'A2', 'D3', 'G3'].map(bassWrittenStaffPosition), [
      -2,
      1,
      4,
      7,
    ]);
    expect(course.study[2].events.map((e) => e.pitch), [
      'E1',
      null,
      'B1',
      null,
      'E1',
      null,
      null,
      null,
    ]);
    expect(course.study[7].events[4].kind, 'rest');
    expect(() => course.lessons.clear(), throwsUnsupportedError);
    expect(() => course.study.first.events.clear(), throwsUnsupportedError);
  });
  test('tampered asset fails closed', () async {
    await expectLater(
      BassCourse.load(bundle: Files(corrupt: true)),
      throwsA(anything),
    );
  });
  testWidgets('replacement load does not show stale course; failure retries', (
    tester,
  ) async {
    await tester.pumpWidget(
      _asMember(MaterialApp(home: BassBeginnerScreen(bundle: Files()))),
    );
    await tester.pumpAndSettle();
    expect(find.text('Bass: four-string beginner foundation'), findsOneWidget);
    await tester.pumpWidget(
      _asMember(
        MaterialApp(home: BassBeginnerScreen(bundle: Files(corrupt: true))),
      ),
    );
    expect(find.byKey(const Key('bass-01')), findsNothing);
    await tester.pumpAndSettle();
    expect(find.text('Written course unavailable.'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bass-01')), findsNothing);
  });
}
