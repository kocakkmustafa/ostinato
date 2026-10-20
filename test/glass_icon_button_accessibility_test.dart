import 'dart:ui' show SemanticsAction, SemanticsFlag;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/app_locale.dart';
import 'package:ostinato/app/content.dart';
import 'package:ostinato/app/cue_text.dart';
import 'package:ostinato/app/design/app_scope.dart';
import 'package:ostinato/app/design/ostinato_theme.dart';
import 'package:ostinato/app/design/widgets.dart';
import 'package:ostinato/app/screens/library_screen.dart';
import 'package:ostinato/app/screens/settings_screen.dart';

int _tapActions(SemanticsNode node) {
  var count = node.getSemanticsData().hasAction(SemanticsAction.tap) ? 1 : 0;
  node.visitChildren((child) {
    count += _tapActions(child);
    return true;
  });
  return count;
}

Widget _host(String locale, Widget home) => MaterialApp(
  theme: ostinatoTheme(),
  locale: Locale(locale),
  supportedLocales: appSupportedLocales,
  localizationsDelegates: appLocalizationsDelegates,
  home: home,
);

void main() {
  for (final locale in ['en', 'tr']) {
    final label = locale == 'tr' ? 'Ayarlar' : 'Settings';
    testWidgets('48dp target keeps a 38dp visual and one action ($locale)', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        var taps = 0;
        var neighborTaps = 0;
        Widget screen(bool enabled) => _host(
          locale,
          Scaffold(
            body: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GlassIconButton(
                    key: const Key('target'),
                    icon: '⚙',
                    semanticLabel: label,
                    onTap: enabled ? () => taps++ : null,
                  ),
                  GlassIconButton(
                    key: const Key('neighbor'),
                    icon: '✕',
                    semanticLabel: locale == 'tr' ? 'Kapat' : 'Close',
                    onTap: () => neighborTaps++,
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpWidget(screen(true));
        await tester.pumpAndSettle();
        final target = find.byKey(const Key('target'));
        final neighbor = find.byKey(const Key('neighbor'));
        final rect = tester.getRect(target);
        expect(rect.size, const Size(48, 48));
        expect(tester.getRect(neighbor).left, rect.right);
        final visual = find.descendant(
          of: target,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is SizedBox &&
                widget.width == 38 &&
                widget.height == 38,
          ),
        );
        expect(visual, findsOneWidget);
        expect(tester.getSize(visual), const Size(38, 38));
        final named = find.bySemanticsLabel(label);
        expect(named, findsOneWidget);
        final node = tester.getSemantics(named);
        final data = node.getSemanticsData();
        expect(data.label, label);
        expect(data.hasFlag(SemanticsFlag.isButton), isTrue);
        expect(data.hasFlag(SemanticsFlag.hasEnabledState), isTrue);
        expect(data.hasFlag(SemanticsFlag.isEnabled), isTrue);
        expect(node.rect.width, greaterThanOrEqualTo(48));
        expect(node.rect.height, greaterThanOrEqualTo(48));
        expect(_tapActions(node), 1);
        expect(find.byTooltip(label), findsOneWidget);

        // Each point is outside the 38dp visual but inside its own 48dp target.
        for (final offset in const [
          Offset(1, 24),
          Offset(24, 1),
          Offset(47, 24),
          Offset(24, 47),
        ]) {
          final before = taps;
          await tester.tapAt(rect.topLeft + offset);
          await tester.pump();
          expect(taps, before + 1);
          expect(neighborTaps, 0);
        }
        await tester.tapAt(tester.getTopLeft(neighbor) + const Offset(1, 24));
        await tester.pump();
        expect(neighborTaps, 1);
        expect(taps, 4);

        final actionNode = tester.getSemantics(find.bySemanticsLabel(label));
        tester.binding.pipelineOwner.semanticsOwner!.performAction(
          actionNode.id,
          SemanticsAction.tap,
        );
        await tester.pump();
        expect(taps, 5);
        await tester.longPress(target);
        await tester.pump(const Duration(milliseconds: 800));
        expect(find.text(label), findsOneWidget);
        expect(taps, 5);

        await tester.pumpWidget(screen(false));
        await tester.pumpAndSettle();
        final disabled = tester.getSemantics(find.bySemanticsLabel(label));
        expect(
          disabled.getSemanticsData().hasFlag(SemanticsFlag.hasEnabledState),
          isTrue,
        );
        expect(
          disabled.getSemanticsData().hasFlag(SemanticsFlag.isEnabled),
          isFalse,
        );
        expect(_tapActions(disabled), 0);
        expect(tester.getSize(target), const Size(48, 48));
        await tester.tapAt(tester.getTopLeft(target) + const Offset(1, 24));
        await tester.pump();
        expect(taps, 5);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('keyboard focus activates the same action ($locale)', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        var taps = 0;
        await tester.pumpWidget(
          _host(
            locale,
            Scaffold(
              body: Center(
                child: GlassIconButton(
                  icon: '⚙',
                  semanticLabel: label,
                  onTap: () => taps++,
                ),
              ),
            ),
          ),
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        expect(
          tester
              .getSemantics(find.bySemanticsLabel(label))
              .getSemanticsData()
              .hasFlag(SemanticsFlag.isFocused),
          isTrue,
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(taps, 1);
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pumpAndSettle();
        expect(taps, 2);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    });
  }

  testWidgets('library settings and back remain reachable at 320px and 2x', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = await ContentRepository.load();
    final cues = await CueTextResolver.load();
    for (final locale in ['en', 'tr']) {
      await tester.pumpWidget(
        ContentRepositoryScope(
          repo: repo,
          cueText: cues,
          child: MaterialApp(
            key: ValueKey(locale),
            theme: ostinatoTheme(),
            locale: Locale(locale),
            supportedLocales: appSupportedLocales,
            localizationsDelegates: appLocalizationsDelegates,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(2),
              ),
              child: child!,
            ),
            home: LibraryScreen(repo: repo, cueText: cues),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final settings = find.byType(GlassIconButton);
      expect(tester.getSize(settings), const Size(48, 48));
      await tester.tapAt(tester.getTopLeft(settings) + const Offset(47, 24));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      final back = find.byType(GlassIconButton).last;
      await tester.tapAt(tester.getTopLeft(back) + const Offset(1, 24));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsNothing);
      expect(find.byType(LibraryScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
