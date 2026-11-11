// OST-UX-05e: stage result layer render evidence + layout assertions (fake data).
// Always pumps and asserts; writes PNGs ONLY when UX_RENDER=1:
//
//   UX_RENDER=1 flutter test test/ux_05e_render_evidence_test.dart
//
// Output: docs/yula-execution/design/evidence/ux-05e/NN-<name>-<size>-<acik|koyu>.png
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/app_locale.dart';
import 'package:ostinato/app/app_theme.dart';
import 'package:ostinato/app/curriculum/v1_lesson.dart';
import 'package:ostinato/app/practice/loop/practice_marks.dart';
import 'package:ostinato/app/practice/loop/practice_outcome.dart';
import 'package:ostinato/app/practice/loop/practice_result_screen.dart';
import 'package:ostinato/app/practice/loop/practice_score.dart';

import 'support/localized_widget_ready.dart';

const String _outDir = 'docs/yula-execution/design/evidence/ux-05e';
final bool _write = Platform.environment['UX_RENDER'] == '1';
final GlobalKey _shot = GlobalKey();

Future<void> _loadFonts() async {
  final FontLoader l = FontLoader('Hanken Grotesk');
  for (final String f in <String>[
    'assets/fonts/HankenGrotesk-Regular.ttf',
    'assets/fonts/HankenGrotesk-SemiBold.ttf',
  ]) {
    final Uint8List b = File(f).readAsBytesSync();
    l.addFont(Future<ByteData>.value(ByteData.sublistView(b)));
  }
  await l.load();
  final String? flutterRoot = Platform.environment['FLUTTER_ROOT'];
  final File icons = File(
    '${flutterRoot ?? ''}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (icons.existsSync()) {
    final FontLoader m = FontLoader('MaterialIcons');
    m.addFont(
      Future<ByteData>.value(ByteData.sublistView(icons.readAsBytesSync())),
    );
    await m.load();
  }
}

Widget _frame(Brightness br, Widget home) => RepaintBoundary(
  key: _shot,
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: OstinatoThemes.forBrightness(br),
    locale: const Locale('tr'),
    supportedLocales: appSupportedLocales,
    localizationsDelegates: appLocalizationsDelegates,
    builder: (BuildContext context, Widget? child) => Column(
      children: <Widget>[
        Container(
          width: double.infinity,
          color: const Color(0xFFB00020),
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: const Text(
            'prototip / test render · sahte veri · bayrak ACIK · 05e',
            textAlign: TextAlign.center,
            textDirection: TextDirection.ltr,
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              decoration: TextDecoration.none,
            ),
          ),
        ),
        Expanded(child: child!),
      ],
    ),
    home: home,
  ),
);

final _score = PracticeScore.parse('E2 F2 G2 F2 | E2 F2 G2 F2');
const _c = PracticeMark.correct, _d = PracticeMark.differentNote;
const _u = PracticeMark.couldNotHear;

PracticeRunSummary _summary(
  List<PracticeMark> marks, {
  Map<int, HearingReason> reasons = const {},
  bool completed = true,
  bool loop = false,
}) => PracticeRunSummary.of(
  score: _score,
  outcomes: [
    for (var i = 0; i < marks.length; i++)
      NoteOutcome(
        eventIndex: i,
        bar: _score.events[i].bar,
        pass: 0,
        mark: marks[i],
        reason: marks[i] == _u ? (reasons[i] ?? HearingReason.noAttack) : null,
        expectedMidi: _score.events[i].midi,
        observedMidi: marks[i] == _d ? 45 : null,
      ),
  ],
  bpm: 60,
  openBpm: 50,
  targetBpm: 60,
  completed: completed,
  loopUsed: loop,
  waitUsed: false,
  criteria: const PassCriteria(minAccuracy: .8),
);

V1Lesson _lesson() => V1Lesson.fromJson(
  jsonDecode(File('content/v1/gtr/gtr-s1-m02-02.json').readAsStringSync()),
);

void main() {
  final TestWidgetsFlutterBinding binding =
      TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadFonts);
  setUpAll(prepareRootTranslations);
  setUp(() {
    addTearDown(binding.platformDispatcher.views.first.resetPhysicalSize);
    addTearDown(binding.platformDispatcher.views.first.resetDevicePixelRatio);
  });

  Future<void> save(WidgetTester t, String name) async {
    if (!_write) return;
    await t.runAsync(() async {
      final RenderRepaintBoundary rb = t.renderObject<RenderRepaintBoundary>(
        find.byKey(_shot),
      );
      final ui.Image img = await rb.toImage(pixelRatio: 1.5);
      final ByteData? d = await img.toByteData(format: ui.ImageByteFormat.png);
      Directory(_outDir).createSync(recursive: true);
      File('$_outDir/$name.png').writeAsBytesSync(d!.buffer.asUint8List());
      // ignore: avoid_print
      print('RENDER $name.png ${img.width}x${img.height}');
    });
  }

  PracticeRunSummary stateSummary(String state) => switch (state) {
    'normal' => _summary([_c, _c, _c, _c, _c, _c, _d, _c]),
    'sebepler' => _summary(
      [_u, _u, _u, _u, _u, _u, _c, _c],
      reasons: {
        0: HearingReason.noAttack,
        1: HearingReason.tooQuiet,
        2: HearingReason.tooLoud,
        3: HearingReason.unclear,
        4: HearingReason.appPlayback,
        5: HearingReason.skipped,
      },
    ),
    _ => _summary([_c, _c, _c, _c, _c, _c], completed: false),
  };

  Future<void> shot(
    WidgetTester t,
    String state,
    int no,
    Size size,
    Brightness br,
  ) async {
    final view = binding.platformDispatcher.views.first;
    view.physicalSize = size * 3;
    view.devicePixelRatio = 3;
    await t.pumpWidget(
      _frame(
        br,
        PracticeResultScreen(
          lesson: _lesson(),
          score: _score,
          summary: stateSummary(state),
          stage: true,
        ),
      ),
    );
    await t.pump();
    final Key focus = switch (state) {
      'sebepler' => const Key('result-reasons'),
      'olculmedi' => const Key('result-not-measured'),
      _ => const Key('result-count-correct'),
    };
    await t.ensureVisible(find.byKey(focus));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.byKey(focus), findsOneWidget);
    if (state == 'sebepler') {
      for (final r in HearingReason.values) {
        expect(find.byKey(Key('result-reason-${r.name}')), findsOneWidget);
      }
    }
    expect(t.takeException(), isNull);
    await save(
      t,
      '0$no-$state-${size.width.toInt()}x${size.height.toInt()}-'
      '${br == Brightness.light ? 'acik' : 'koyu'}',
    );
    await t.pumpWidget(const SizedBox());
  }

  const states = <(String, int)>[
    ('normal', 1),
    ('sebepler', 2),
    ('olculmedi', 3),
  ];
  final sizes = <Size>[const Size(390, 844), const Size(360, 640)];
  for (final (String, int) s in states) {
    for (final Size size in sizes) {
      for (final Brightness br in Brightness.values) {
        testWidgets(
          '05e ${s.$1} ${size.width.toInt()}x${size.height.toInt()} ${br.name}',
          (t) => shot(t, s.$1, s.$2, size, br),
        );
      }
    }
  }
}
