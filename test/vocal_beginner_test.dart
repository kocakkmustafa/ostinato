import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:ostinato/app/screens/vocal_diagrams.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/vocal_beginner.dart';
import 'package:ostinato/app/app_locale.dart';
import 'package:ostinato/app/content.dart';
import 'package:ostinato/app/cue_text.dart';
import 'package:ostinato/app/design/app_scope.dart';
import 'package:ostinato/app/screens/library_screen.dart';
import 'package:ostinato/app/screens/vocal_beginner_screen.dart';

import 'support/localized_widget_ready.dart';

class Files extends CachingAssetBundle {
  Files({this.corrupt = false});
  final bool corrupt;
  @override
  Future<ByteData> load(String key) async {
    final bytes = File(key).readAsBytesSync();
    if (corrupt && key == vocalAsset) bytes[10] ^= 1;
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
    if (key == vocalAsset && !failed) {
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
      home: VocalBeginnerScreen(bundle: bundle),
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
      expect(
        find.text('Voice: comfortable written beginner foundation'),
        findsOneWidget,
      );
      old.gate.complete();
      await tester.pumpAndSettle();
      expect(
        find.text('Voice: comfortable written beginner foundation'),
        findsOneWidget,
      );
      final pending = DelayedFiles();
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => VocalBeginnerScreen(bundle: pending),
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
    expect(
      find.text('Voice: comfortable written beginner foundation'),
      findsOneWidget,
    );
  });

  test(
    'strict schema, symbol roles, complete sequence and immutable practice',
    () async {
      Map<String, dynamic> raw() =>
          jsonDecode(File(vocalAsset).readAsStringSync())
              as Map<String, dynamic>;
      final course = await VocalCourse.load(bundle: Files());
      expect(course.lessons.length, 22);
      expect(course.study.length, 8);
      expect(course.contour, [
        ['M', 'H', 'M', 'R'],
        ['L', 'M', 'M', 'R'],
      ]);
      expect(course.study[5].events.first.kind, 'rest');
      expect(course.study[7].events.first.kind, 'rest');
      expect(() => course.lessons.clear(), throwsUnsupportedError);
      expect(() => course.study.first.events.clear(), throwsUnsupportedError);
      expect(() => course.contour.first.clear(), throwsUnsupportedError);
      for (final mutation in <void Function(Map<String, dynamic>)>[
        (m) => m['unexpected'] = true,
        (m) => m['schemaVersion'] = 1.0,
        (m) => m['pitchMode'] = 'fixed:C4',
        (m) => m['rhythmSymbols']['hold'] = 'H',
        (m) => m['title']['tr'] = ' ',
        (m) => m['paperAnswers']['measured'] = true,
        (m) => m['lessons'].removeLast(),
        (m) => m['lessons'][0]['id'] = 'vocal-02',
        (m) => m['lessons'][5]['diagrams'] = [],
        (m) => m['contour'][0][0] = 'C4',
        (m) => m['contour'][0].removeLast(),
        (m) => m['study'][0]['events'][0]['tone'] = 'A4',
        (m) => m['study'][0]['events'][0]['syllable']['tr'] = '',
        (m) => m['study'][0]['events'][1]['tone'] = 'M',
        (m) => m['study'][0]['events'][0] = {'kind': 'hold'},
        (m) => m['study'][0]['events'].removeLast(),
      ]) {
        final m = raw();
        mutation(m);
        expect(() => VocalCourse.fromJson(m), throwsFormatException);
      }
      await expectLater(
        VocalCourse.load(bundle: Files(corrupt: true)),
        throwsA(isA<Exception>()),
      );
    },
  );
  for (final locale in ['en', 'tr']) {
    testWidgets(
      '$locale sixteen lessons, separate answers, navigation and study pan at 2x',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final course = VocalCourse.fromJson(
          jsonDecode(File(vocalAsset).readAsStringSync()),
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
            home: VocalBeginnerScreen(bundle: Files()),
          ),
        );
        await waitForLocalizedFixture(
          tester,
          languageTag: locale,
          anchor: find.descendant(
            of: find.byType(VocalBeginnerScreen),
            matching: find.byType(ListView),
          ),
          reason:
              'Vocal course and packaged translations must be ready before scrolling',
        );
        await tester.pumpAndSettle();
        await _centre(tester, find.byKey(const Key('vocal-01')));
        await tester.tap(find.byKey(const Key('vocal-01')));
        await tester.pumpAndSettle();
        for (var i = 0; i < 16; i++) {
          expect(
            find.text(
              locale == 'tr'
                  ? course.lessons[i].title.tr
                  : course.lessons[i].title.en,
            ),
            findsOneWidget,
          );
          if (i == 5 || i == 8) {
            final kind = i == 5 ? 'rhythm' : 'contour';
            final answer = i == 5 ? course.rhythmAnswer : course.contourAnswer;
            final text = locale == 'tr' ? answer.tr : answer.en;
            expect(find.text(text), findsNothing);
            final panel = find.byKey(Key('vocal-$kind-answers'));
            await _centre(tester, panel);
            await tester.tap(
              find.descendant(of: panel, matching: find.byType(ListTile)).first,
            );
            await tester.pumpAndSettle();
            expect(find.text(text), findsOneWidget);
            await tester.tap(find.byType(BackButton));
            await tester.pumpAndSettle();
            final lesson = find.byKey(
              Key('vocal-${(i + 1).toString().padLeft(2, '0')}'),
            );
            await _centre(tester, lesson);
            await tester.tap(lesson);
            await tester.pumpAndSettle();
            expect(find.text(text), findsNothing);
          }
          if (i == 13) {
            for (var b = 1; b <= 8; b++) {
              final table = find.byKey(Key('vocal-study-$b'));
              await _centre(tester, table);
              await tester.drag(table, const Offset(-700, 0));
              await tester.pumpAndSettle();
              final scrollable = find.descendant(
                of: table,
                matching: find.byType(Scrollable),
              );
              expect(
                tester.state<ScrollableState>(scrollable).position.pixels,
                greaterThan(0),
              );
            }
          }
          expect(tester.takeException(), isNull);
          if (i < 15) {
            final next = find.text(
              locale == 'tr' ? 'Sonraki ders' : 'Next lesson',
            );
            await _centre(tester, next);
            await tester.tap(next);
            await tester.pumpAndSettle();
          }
        }
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.byType(VocalBeginnerScreen), findsOneWidget);
      },
    );
    for (final lesson in [6, 9, 14]) {
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
                          child: VocalDiagrams(
                            course: VocalCourse.fromJson(
                              jsonDecode(File(vocalAsset).readAsStringSync()),
                            ),
                            lesson: VocalCourse.fromJson(
                              jsonDecode(File(vocalAsset).readAsStringSync()),
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
              final file = File('../vocal-qa/$locale-$lesson$suffix.png');
              file.parent.createSync(recursive: true);
              file.writeAsBytesSync(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }

          await capture('');
          if (lesson == 6 || lesson == 9) {
            final kind = lesson == 6 ? 'rhythm' : 'contour';
            final answer = find.byKey(Key('vocal-$kind-answers'));
            await _centre(tester, answer);
            await tester.tap(
              find
                  .descendant(of: answer, matching: find.byType(ListTile))
                  .first,
            );
            await tester.pumpAndSettle();
            final course = VocalCourse.fromJson(
              jsonDecode(File(vocalAsset).readAsStringSync()),
            );
            final text = lesson == 6
                ? course.rhythmAnswer
                : course.contourAnswer;
            await _centre(
              tester,
              find.text(locale == 'tr' ? text.tr : text.en),
            );
            await capture('-answer');
          }
          if (lesson == 14) {
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
    testWidgets('$locale actual Library written voice entry', (tester) async {
      final repo = (await tester.runAsync(ContentRepository.load))!;
      final cueText = (await tester.runAsync(CueTextResolver.load))!;
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(locale),
          supportedLocales: appSupportedLocales,
          localizationsDelegates: appLocalizationsDelegates,
          home: ContentRepositoryScope(
            repo: repo,
            cueText: cueText,
            child: LibraryScreen(repo: repo, cueText: cueText),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final entry = find.byKey(const Key('vocal-written-course'));
      await _centre(tester, entry);
      await tester.tap(entry);
      await tester.pumpAndSettle();
      expect(find.byType(VocalBeginnerScreen), findsOneWidget);
      expect(find.byKey(const Key('vocal-01')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
