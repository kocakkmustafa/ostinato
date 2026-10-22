import 'dart:convert';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/ukulele_beginner.dart';
import 'package:ostinato/app/app_locale.dart';
import 'package:ostinato/app/screens/ukulele_diagrams.dart';
import 'package:ostinato/app/content.dart';
import 'package:ostinato/app/cue_text.dart';
import 'package:ostinato/app/design/app_scope.dart';
import 'package:ostinato/app/screens/library_screen.dart';
import 'package:ostinato/app/screens/ukulele_beginner_screen.dart';
import 'support/localized_widget_ready.dart';

class Files extends CachingAssetBundle {
  Files({this.corrupt = false});
  final bool corrupt;
  @override
  Future<ByteData> load(String key) async {
    final bytes = File(key).readAsBytesSync();
    if (corrupt && key == ukuleleAsset) bytes[10] ^= 1;
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
    if (key == ukuleleAsset && !failed) {
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
      home: UkuleleBeginnerScreen(bundle: bundle),
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
      await tester.pumpWidget(_app(old));
      await tester.pump();
      await tester.pumpWidget(_app(latest));
      await tester.pump();
      latest.gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('Ukulele: high-G beginner foundation'), findsOneWidget);
      old.gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('Ukulele: high-G beginner foundation'), findsOneWidget);
      final pending = DelayedFiles();
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => UkuleleBeginnerScreen(bundle: pending),
                ),
              ),
              child: const Text('Open'),
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
    await tester.pumpWidget(_app(RecoveringFiles()));
    await tester.pumpAndSettle();
    expect(find.text('Written course unavailable.'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Ukulele: high-G beginner foundation'), findsOneWidget);
  });
  for (final locale in ['en', 'tr']) {
    testWidgets(
      '$locale every lesson, hidden answers and navigation at 2x text',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final course = UkuleleCourse.fromJson(
          jsonDecode(File(ukuleleAsset).readAsStringSync()),
        );
        await tester.pumpWidget(
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
            home: UkuleleBeginnerScreen(bundle: Files()),
          ),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byKey(const Key('ukulele-01')),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await _centre(tester, find.byKey(const Key('ukulele-01')));
        await tester.tap(find.byKey(const Key('ukulele-01')));
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
          if (i == 13) {
            final answer = find.byKey(const Key('ukulele-tab-answers'));
            final answerText = find.textContaining(
              locale == 'tr'
                  ? 'vuruş 1: tel 3, perde 0 (C4 (Do4))'
                  : 'beat 1: string 3, fret 0 (C4)',
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
              (3, 0),
              (3, 2),
              (2, 0),
              (2, 1),
              (2, 3),
              (2, 0),
              (3, 2),
              (3, 0),
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
        expect(find.byType(UkuleleBeginnerScreen), findsOneWidget);
        final readAgain = find.byKey(const Key('ukulele-14'));
        await _centre(tester, readAgain);
        await tester.tap(readAgain);
        await tester.pumpAndSettle();
        expect(
          find.textContaining(
            locale == 'tr'
                ? 'vuruş 1: tel 3, perde 0 (C4 (Do4))'
                : 'beat 1: string 3, fret 0 (C4)',
          ),
          findsNothing,
        );
      },
    );
    for (final lesson in [1, 7, 9, 10, 14, 16]) {
      testWidgets(
        '$locale original vector lesson $lesson render at narrow 2x',
        (tester) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final boundary = GlobalKey();
          await tester.pumpWidget(
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
                          child: UkuleleDiagrams(
                            course: UkuleleCourse.fromJson(
                              jsonDecode(File(ukuleleAsset).readAsStringSync()),
                            ),
                            lesson: UkuleleCourse.fromJson(
                              jsonDecode(File(ukuleleAsset).readAsStringSync()),
                            ).lessons[lesson - 1],
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
              final file = File('../ukulele-qa/$locale-$lesson$suffix.png');
              file.parent.createSync(recursive: true);
              file.writeAsBytesSync(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }

          await capture('');
          if (lesson == 14) {
            final answer = find.byKey(const Key('ukulele-tab-answers'));
            await _centre(tester, answer);
            await tester.tap(
              find
                  .descendant(of: answer, matching: find.byType(ListTile))
                  .first,
            );
            await tester.pumpAndSettle();
            final expected = locale == 'tr'
                ? 'vuruş 1: tel 3, perde 0 (C4 (Do4))'
                : 'beat 1: string 3, fret 0 (C4)';
            await _centre(tester, find.textContaining(expected));
            await capture('-answers-bar1');
            await _centre(
              tester,
              find.textContaining(
                locale == 'tr'
                    ? 'vuruş 1: tel 2, perde 3 (G4 (Sol4))'
                    : 'beat 1: string 2, fret 3 (G4)',
              ),
            );
            await capture('-answers-bar2');
          }
          if (lesson == 9) {
            final position = tester
                .state<ScrollableState>(find.byType(Scrollable).first)
                .position;
            position.jumpTo(position.maxScrollExtent);
            await tester.pumpAndSettle();
            await capture('-F');
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
              await tester.drag(table, const Offset(-400, 0));
              await tester.pumpAndSettle();
              expect(
                scroller.position.pixels,
                scroller.position.maxScrollExtent,
              );
              await capture('-bar${bar + 1}-right');
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
      ContentRepositoryScope(
        repo: repo,
        cueText: cue,
        child: MaterialApp(
          home: LibraryScreen(repo: repo, cueText: cue),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('ukulele-beginner-entry')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('ukulele-beginner-entry')));
    await tester.pumpAndSettle();
    expect(find.byType(UkuleleBeginnerScreen), findsOneWidget);
    expect(find.text('Ukulele: high-G beginner foundation'), findsOneWidget);
  });
  final source =
      jsonDecode(File(ukuleleAsset).readAsStringSync()) as Map<String, dynamic>;
  test('complete translated ordered curriculum and integrity', () async {
    final course = await UkuleleCourse.load(bundle: Files());
    expect(course.lessons.length, 24);
    expect(course.lessons.last.id, 'ukulele-24');
  });
  test('strict fields, translations, sequence, schema and completeness', () {
    for (final mutate in <void Function(Map<String, dynamic>)>[
      (m) => m['schemaVersion'] = 2,
      (m) => m['schemaVersion'] = 1.0,
      (m) => m['unexpected'] = true,
      (m) => (m['title'] as Map)['tr'] = ' ',
      (m) => (m['lessons'] as List).removeLast(),
      (m) => (m['lessons'][1] as Map)['id'] = 'ukulele-01',
      (m) => (m['lessons'][0] as Map)['score'] = 100,
      (m) => m['tuning'] = 'low-G:G3-C4-E4-A4',
      (m) => (m['tab'][0] as Map)['string'] = 0,
      (m) => (m['tab'][0] as Map)['fret'] = 1.0,
      (m) => (m['chords'][0] as Map)['frets4to1'] = [0, 0, 0, 2],
      (m) => (m['chords'][0] as Map)['fingers4to1'] = [1, 0, 0, 3],
      (m) => (m['lessons'][0] as Map)['diagrams'] = ['unknown'],
      (m) => (m['study'][0] as Map)['slots'] = ['D'],
      (m) => (m['study'][0] as Map)['chord'] = 'Dm',
      (m) => (m['study'][0]['slots'] as List)[1] = 'X',
    ]) {
      final copy = jsonDecode(jsonEncode(source)) as Map<String, dynamic>;
      mutate(copy);
      expect(() => UkuleleCourse.fromJson(copy), throwsFormatException);
    }
  });
  test('chord pitch sets and independent tab solution match high-G tuning', () {
    final course = UkuleleCourse.fromJson(source);
    const expected = {
      'C': {0, 4, 7},
      'Am': {9, 0, 4},
      'F': {0, 5, 9},
      'G7': {2, 5, 7, 11},
    };
    for (final chord in course.chords.values) {
      expect({
        for (var i = 0; i < 4; i++)
          (ukuleleOpenMidi4to1[i] + chord.frets[i]) % 12,
      }, expected[chord.id]);
    }
    expect(course.tab.map((n) => n.pitch), [
      'C4',
      'D4',
      'E4',
      'F4',
      'G4',
      'E4',
      'D4',
      'C4',
    ]);
    expect(course.study.map((b) => b.chord), [
      'C',
      'Am',
      'F',
      'G7',
      'C',
      'Am',
      'F',
      'C',
    ]);
    expect(() => course.lessons.clear(), throwsUnsupportedError);
  });
  test('tampered asset fails closed', () async {
    await expectLater(
      UkuleleCourse.load(bundle: Files(corrupt: true)),
      throwsA(anything),
    );
  });
  testWidgets('replacement load does not show stale course; failure retries', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: UkuleleBeginnerScreen(bundle: Files())),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ukulele: high-G beginner foundation'), findsOneWidget);
    await tester.pumpWidget(
      MaterialApp(home: UkuleleBeginnerScreen(bundle: Files(corrupt: true))),
    );
    expect(find.byKey(const Key('ukulele-01')), findsNothing);
    await tester.pumpAndSettle();
    expect(find.text('Written course unavailable.'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ukulele-01')), findsNothing);
  });
}
