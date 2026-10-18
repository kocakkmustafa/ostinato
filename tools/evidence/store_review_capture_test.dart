// Source-current store DRAFT renders, never native/device acceptance.
// Run with OSTINATO_STORE_CAPTURE_DIR pointing at a dedicated evidence folder.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/account_connection.dart';
import 'package:ostinato/app/app_locale.dart';
import 'package:ostinato/app/content.dart';
import 'package:ostinato/app/cue_text.dart';
import 'package:ostinato/app/design/app_scope.dart';
import 'package:ostinato/app/design/ostinato_theme.dart';
import 'package:ostinato/app/guitar_journey.dart';
import 'package:ostinato/app/guitar_journey_progress.dart';
import 'package:ostinato/app/screens/guitar_journey_screen.dart';
import 'package:ostinato/app/screens/library_screen.dart';
import 'package:ostinato/app/screens/piano_beginner_screen.dart';
import 'package:ostinato/app/screens/piano_hand_support_notice.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final outputPath = Platform.environment['OSTINATO_STORE_CAPTURE_DIR'];
  if (outputPath == null || outputPath.isEmpty) {
    throw StateError(
      'Set OSTINATO_STORE_CAPTURE_DIR to a dedicated draft folder.',
    );
  }
  final output = Directory(outputPath)..createSync(recursive: true);
  late ContentRepository repo;
  late CueTextResolver cues;
  late GuitarJourneyCourse course;
  setUpAll(() async {
    repo = await ContentRepository.load();
    cues = await CueTextResolver.load();
    course = await GuitarJourneyCourse.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(1206, 2622);
    view.devicePixelRatio = 3;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);
  });
  for (final locale in ['en', 'tr']) {
    for (final screen in [
      'library',
      'guitar-path',
      'guitar-lesson',
      'piano-limit',
    ]) {
      testWidgets('$locale $screen source-current store draft', (tester) async {
        final key = GlobalKey();
        final store = GuitarJourneyProgressStore(
          accountUserId: null,
          directoryProvider: () async =>
              Directory('${output.path}/isolated-guest-$locale'),
        );
        final child = switch (screen) {
          'library' => LibraryScreen(repo: repo, cueText: cues),
          'guitar-path' => GuitarJourneyScreen(
            initialCourse: course,
            initialProgress: const {},
            progressStoreFactory: (_) => store,
          ),
          'guitar-lesson' => GuitarJourneyLessonScreen(
            course: course,
            lesson: course.lessons.first,
            store: store,
          ),
          _ => const PianoBeginnerScreen(),
        };
        await tester.pumpWidget(
          ContentRepositoryScope(
            repo: repo,
            cueText: cues,
            child: AccountScope(
              connection: null,
              currentUserId: null,
              child: RepaintBoundary(
                key: key,
                child: MaterialApp(
                  debugShowCheckedModeBanner: false,
                  locale: Locale(locale),
                  theme: ostinatoTheme(),
                  supportedLocales: appSupportedLocales,
                  localizationsDelegates: appLocalizationsDelegates,
                  home: child,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (screen == 'piano-limit') {
          await tester.scrollUntilVisible(
            find.byKey(const Key('piano-05')),
            250,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.tap(find.byKey(const Key('piano-05')));
          await tester.pumpAndSettle();
          expect(find.byType(PianoHandSupportNotice), findsOneWidget);
        }
        if (screen == 'guitar-path') {
          expect(course.lessons, hasLength(60));
          expect(course.modules, hasLength(10));
          expect(find.byType(GuitarJourneyScreen), findsOneWidget);
        }
        if (screen == 'guitar-lesson') {
          expect(find.byType(GuitarJourneyLessonScreen), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
        // The boundary wraps MaterialApp, including pushed Navigator routes.
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 3);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('${output.path}/$locale-$screen.png');
          file.writeAsBytesSync(
            data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          );
          image.dispose();
        });
        final texts = tester
            .widgetList<Text>(find.byType(Text))
            .map((x) => x.data)
            .whereType<String>()
            .toList();
        File('${output.path}/$locale-$screen.text.json').writeAsStringSync(
          const JsonEncoder.withIndent('  ').convert({
            'locale': locale,
            'screen': screen,
            'text': texts,
            'evidence': 'host-widget-render-not-native-device',
            'sensorProvider': 'none',
            'progress': 'fresh-empty-guest',
          }),
        );
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      });
    }
  }
}
