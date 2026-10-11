import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/app_locale.dart';
import 'package:ostinato/app/screens/ukulele_diagrams.dart';
import 'package:ostinato/app/ukulele_beginner.dart';

void main() {
  final course = UkuleleCourse.fromJson(
    jsonDecode(File(ukuleleAsset).readAsStringSync()),
  );
  final studyLesson = course.lessons.singleWhere(
    (lesson) => lesson.id == 'ukulele-16',
  );
  // Independently authored readings of the unchanged eight original bars.
  // S = continue counted silence, H = ringing without a new attack.
  const expectedActions = [
    ['D', 'H', 'H', 'H', 'H', 'H', 'H', 'H'],
    ['D', 'H', 'H', 'H', 'D', 'H', 'H', 'H'],
    ['D', 'H', 'D', 'H', 'D', 'H', 'R', 'S'],
    ['D', 'H', 'H', 'H', 'H', 'H', 'H', 'H'],
    ['D', 'U', 'D', 'U', 'D', 'U', 'D', 'U'],
    ['D', 'H', 'D', 'H', 'D', 'U', 'R', 'S'],
    ['D', 'H', 'H', 'H', 'H', 'H', 'H', 'H'],
    ['D', 'H', 'H', 'H', 'H', 'H', 'H', 'H'],
  ];

  for (final locale in ['en', 'tr']) {
    final phrases = locale == 'en'
        ? {
            'D': 'downstroke',
            'U': 'upstroke',
            'H': 'keep ringing; no new stroke',
            'R': 'stop sound; counted silence',
            'S': 'continue counted silence; no new stroke',
          }
        : {
            'D': 'aşağı tarama',
            'U': 'yukarı tarama',
            'H': 'çınlamayı sürdür; yeni tarama yok',
            'R': 'sesi kes; sayılan sessizlik',
            'S': 'sayılan sessizliği sürdür; yeni tarama yok',
          };
    final descriptions = [
      for (final actions in expectedActions)
        [
          for (var i = 0; i < actions.length; i++)
            '${i ~/ 2 + 1}${i.isOdd ? (locale == 'en' ? ' and' : ' ve') : ''}: ${phrases[actions[i]]}',
        ].join('; '),
    ];

    testWidgets('$locale original bars distinguish ringing and silent H at 2x', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      try {
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(locale),
          supportedLocales: appSupportedLocales,
          localizationsDelegates: appLocalizationsDelegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2),
            ),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: UkuleleDiagrams(course: course, lesson: studyLesson),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (var bar = 0; bar < 8; bar++) {
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.label == descriptions[bar],
          ),
          findsWidgets,
          reason: 'Bar ${bar + 1} must explain the intended sound state',
        );
        final key = find.byKey(Key('ukulele-study-bar-${bar + 1}'));
        expect(key, findsOneWidget);
        // Visible cell annotations and one combined screen-reader label agree. The raw
        // table is excluded so H is not announced again without its state.
        final widget = tester.widget<Semantics>(key);
        expect(widget.properties.label, descriptions[bar]);
        expect(widget.excludeSemantics, isTrue);
        final tableText = tester.widgetList<Text>(find.descendant(
          of: key,
          matching: find.byType(Text),
        )).map((text) => text.data).toList();
        expect(tableText.sublist(8), [
          for (final action in expectedActions[bar])
            switch (action) {
              'H' => locale == 'en' ? 'H\nring' : 'H\nçınlama',
              'S' => locale == 'en' ? 'H\nsilence' : 'H\nsessizlik',
              _ => action,
            },
        ]);
        await tester.ensureVisible(key);
        await tester.pumpAndSettle();
        expect(
          tester.getSemantics(key).getSemanticsData().label,
          descriptions[bar],
        );
        expect(tester.takeException(), isNull);
      }
      final raw = jsonDecode(File(ukuleleAsset).readAsStringSync()) as Map;
      expect((raw['study'] as List)[2]['slots'][7], 'H');
      expect((raw['study'] as List)[5]['slots'][7], 'H');
      } finally {
        semantics.dispose();
      }
    });
  }
}
