import 'package:flutter/material.dart';

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

/// Where the strip draws a beat (F2.7 / FK4 left-handed mode).
///
/// Right-handed (default): the NOW line sits at [nowFraction] from the left,
/// upcoming notes wait on the right and travel leftwards to it.
///
/// Left-handed: the whole strip is mirrored left↔right. The NOW line moves to
/// the right side and upcoming notes come in from the left. The NOW line stays
/// on the fretting-hand side, where the neck points for a left-handed player
/// (the same mirror image Yousician / Rocksmith left-handed views use). The
/// vertical string order does NOT change: string 1 stays on top as written
/// TAB, because a left-handed guitar is strung so the thinnest string is still
/// nearest the floor. Fret numbers and symbols are drawn upright, never
/// mirrored. Judging and timing are untouched; only drawing changes.
final class StripGeometry {
  const StripGeometry({
    required this.width,
    required this.displayBeat,
    required this.pixelsPerBeat,
    required this.nowFraction,
    required this.leftHanded,
  });

  final double width, displayBeat, pixelsPerBeat, nowFraction;
  final bool leftHanded;

  /// +1 when later beats are drawn further right, -1 when mirrored.
  double get forward => leftHanded ? -1 : 1;

  double get nowX =>
      leftHanded ? width * (1 - nowFraction) : width * nowFraction;

  double xOf(double beat) =>
      nowX + forward * (beat - displayBeat) * pixelsPerBeat;
}

/// F2.3 theme hook, wired to settings in FK4 (F2.7): left-handed mirroring
/// and a colour-blind-safe palette. No red anywhere: "different note" is an
/// informative amber/orange.
///
/// Palettes (contrast against the notation paper and card surfaces of the
/// same brightness is at least 3:1 for every mark, `test/practice_display_test`):
/// - default: teal / amber / grey;
/// - colour-blind safe: Okabe–Ito blue / orange / grey, darkened for light
///   paper and lightened for dark paper. Blue vs orange keeps its distance
///   under protanopia, deuteranopia and tritanopia.
final class PracticeVisualTheme {
  const PracticeVisualTheme({
    this.leftHanded = false,
    this.colorBlindSafe = false,
    this.dark = false,
  });

  /// Mirrors the strip horizontally ([StripGeometry]).
  final bool leftHanded;

  /// Okabe–Ito blue / orange / grey instead of teal / amber / grey.
  final bool colorBlindSafe;

  /// Dark notation paper: lighter tones keep the contrast.
  final bool dark;

  // Light paper.
  static const _pending = Color(0xFF2A2533);
  static const _correct = Color(0xFF1C7F72);
  static const _correctCb = Color(0xFF0072B2);
  static const _different = Color(0xFFB8690A);
  static const _differentCb = Color(0xFFA65A00);
  static const _unheard = Color(0xFF6E6880);

  // Dark paper.
  static const _pendingDark = Color(0xFFEAE2F3);
  static const _correctDark = Color(0xFF4FC1B0);
  static const _correctCbDark = Color(0xFF56B4E9);
  static const _differentDark = Color(0xFFF0A04B);
  static const _differentCbDark = Color(0xFFE69F00);
  static const _unheardDark = Color(0xFFA9A3B5);

  Color _pick(Color light, Color darkTone) => dark ? darkTone : light;

  MarkStyle style(PracticeMark mark) => switch (mark) {
    PracticeMark.pending => MarkStyle(
      MarkShape.outlineCircle,
      _pick(_pending, _pendingDark),
      '',
    ),
    PracticeMark.correct => MarkStyle(
      MarkShape.filledCircle,
      colorBlindSafe
          ? _pick(_correctCb, _correctCbDark)
          : _pick(_correct, _correctDark),
      '✓',
    ),
    PracticeMark.differentNote => MarkStyle(
      MarkShape.diamond,
      colorBlindSafe
          ? _pick(_differentCb, _differentCbDark)
          : _pick(_different, _differentDark),
      '◆',
    ),
    PracticeMark.couldNotHear => MarkStyle(
      MarkShape.dashedCircle,
      _pick(_unheard, _unheardDark),
      '?',
    ),
  };

  PracticeVisualTheme copyWith({
    bool? leftHanded,
    bool? colorBlindSafe,
    bool? dark,
  }) => PracticeVisualTheme(
    leftHanded: leftHanded ?? this.leftHanded,
    colorBlindSafe: colorBlindSafe ?? this.colorBlindSafe,
    dark: dark ?? this.dark,
  );

  @override
  bool operator ==(Object other) =>
      other is PracticeVisualTheme &&
      other.leftHanded == leftHanded &&
      other.colorBlindSafe == colorBlindSafe &&
      other.dark == dark;

  @override
  int get hashCode => Object.hash(leftHanded, colorBlindSafe, dark);
}

/// Where a screen reads the practice theme from. `PracticeDisplayHost`
/// (FK4) publishes the saved settings here; [of] adds the current brightness.
class PracticeVisualThemeScope extends InheritedWidget {
  const PracticeVisualThemeScope({
    super.key,
    required this.theme,
    required super.child,
  });

  final PracticeVisualTheme theme;

  static PracticeVisualTheme of(BuildContext context) {
    final theme =
        context
            .dependOnInheritedWidgetOfExactType<PracticeVisualThemeScope>()
            ?.theme ??
        const PracticeVisualTheme();
    return theme.copyWith(
      dark: Theme.of(context).brightness == Brightness.dark,
    );
  }

  @override
  bool updateShouldNotify(PracticeVisualThemeScope oldWidget) =>
      oldWidget.theme != theme;
}
