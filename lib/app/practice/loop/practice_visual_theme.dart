import 'package:flutter/widgets.dart';

import 'practice_marks.dart';

/// Shape first, colour second, label third (RAPOR (f), `4-rakip-arayuzleri`
/// §6.6): a state must be readable without colour.
enum MarkShape { filledCircle, diamond, dashedCircle, outlineCircle }

final class MarkStyle {
  const MarkStyle(this.shape, this.color, this.symbol);
  final MarkShape shape;
  final Color color;

  /// One-glyph label drawn with the shape (✓ ◆ ?).
  final String symbol;
}

/// F2.3 theme hook for F2.7: left-handed mirroring and a colour-blind-safe
/// palette. No red anywhere: "different note" is an informative amber/orange.
final class PracticeVisualTheme {
  const PracticeVisualTheme({
    this.leftHanded = false,
    this.colorBlindSafe = false,
  });

  /// Mirrors the strip horizontally: notes flow left → right and the NOW line
  /// sits on the right.
  final bool leftHanded;

  /// Blue / orange / grey instead of teal / amber / grey.
  final bool colorBlindSafe;

  static const _pending = Color(0xFF2A2533);
  static const _correct = Color(0xFF1C7F72);
  static const _correctCb = Color(0xFF2F64B0);
  static const _different = Color(0xFFB8690A);
  static const _differentCb = Color(0xFFD27A00);
  static const _unheard = Color(0xFF7D778A);

  MarkStyle style(PracticeMark mark) => switch (mark) {
    PracticeMark.pending => const MarkStyle(
      MarkShape.outlineCircle,
      _pending,
      '',
    ),
    PracticeMark.correct => MarkStyle(
      MarkShape.filledCircle,
      colorBlindSafe ? _correctCb : _correct,
      '✓',
    ),
    PracticeMark.differentNote => MarkStyle(
      MarkShape.diamond,
      colorBlindSafe ? _differentCb : _different,
      '◆',
    ),
    PracticeMark.couldNotHear => const MarkStyle(
      MarkShape.dashedCircle,
      _unheard,
      '?',
    ),
  };

  PracticeVisualTheme copyWith({bool? leftHanded, bool? colorBlindSafe}) =>
      PracticeVisualTheme(
        leftHanded: leftHanded ?? this.leftHanded,
        colorBlindSafe: colorBlindSafe ?? this.colorBlindSafe,
      );
}

/// Where a screen reads the practice theme from (settings wire it in F2.7).
class PracticeVisualThemeScope extends InheritedWidget {
  const PracticeVisualThemeScope({
    super.key,
    required this.theme,
    required super.child,
  });

  final PracticeVisualTheme theme;

  static PracticeVisualTheme of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<PracticeVisualThemeScope>()
          ?.theme ??
      const PracticeVisualTheme();

  @override
  bool updateShouldNotify(PracticeVisualThemeScope oldWidget) =>
      oldWidget.theme.leftHanded != theme.leftHanded ||
      oldWidget.theme.colorBlindSafe != theme.colorBlindSafe;
}
