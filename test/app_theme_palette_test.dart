import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/app_theme.dart';

double _contrast(Color a, Color b) {
  final x = a.computeLuminance();
  final y = b.computeLuminance();
  return ((x > y ? x : y) + .05) / ((x > y ? y : x) + .05);
}

void main() {
  for (final entry in [(Brightness.light, OstinatoThemes.light), (Brightness.dark, OstinatoThemes.dark)]) {
    final (brightness, theme) = entry;
    test('${brightness.name}: text, error, focus, control and disabled roles retain contrast', () {
      final p = theme.extension<OstinatoPalette>()!;
      expect(theme.brightness, brightness);
      expect(theme.colorScheme.brightness, brightness);
      final backgrounds = <Color>[
        p.shell, p.surface, p.controlSurface,
        Color.alphaBlend(p.glassStart, p.shell),
        Color.alphaBlend(p.glassEnd, p.shell),
        for (final hue in [p.guitar, p.voice, p.piano])
          for (final color in [...hue.grad, ...hue.gradAlt, ...hue.soft])
            Color.alphaBlend(color, p.shell),
      ];
      for (final foreground in [p.ink, p.inkSoft, p.textBody, p.textMuted, p.textFaint, p.textMono, p.warnInk, p.error, p.success]) {
        for (final background in backgrounds) {
          expect(_contrast(foreground, background), greaterThanOrEqualTo(4.5));
        }
      }
      for (final hue in [p.guitar, p.voice, p.piano]) {
        for (final color in [...hue.grad, ...hue.gradAlt, ...hue.soft]) {
          expect(_contrast(hue.ink, Color.alphaBlend(color, p.shell)), greaterThanOrEqualTo(4.5));
        }
      }
      expect(_contrast(p.onPrimary, p.primary), greaterThanOrEqualTo(4.5));
      expect(_contrast(p.onError, p.error), greaterThanOrEqualTo(4.5));
      expect(_contrast(p.disabledForeground, p.disabledBackground), greaterThanOrEqualTo(4.5));
      expect(_contrast(p.controlBorder, p.controlSurface), greaterThanOrEqualTo(3));
      expect(_contrast(p.focus, p.controlSurface), greaterThanOrEqualTo(3));
      expect(_contrast(p.notationInk, p.notationPaper), greaterThanOrEqualTo(4.5));
      final focusedFill = theme.filledButtonTheme.style!.backgroundColor!.resolve({WidgetState.focused})!;
      final focusedInk = theme.filledButtonTheme.style!.foregroundColor!.resolve({WidgetState.focused})!;
      expect(_contrast(focusedInk, focusedFill), greaterThanOrEqualTo(4.5));
      expect(theme.filledButtonTheme.style!.backgroundColor!.resolve({WidgetState.disabled}), p.disabledBackground);
      expect(theme.filledButtonTheme.style!.foregroundColor!.resolve({WidgetState.disabled}), p.disabledForeground);
      expect(theme.inputDecorationTheme.focusedBorder!.borderSide.width, greaterThanOrEqualTo(2));
    });
  }
}
