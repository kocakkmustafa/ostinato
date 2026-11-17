/// OST-P1-04 (b): presentation decisions from the learner's accessibility
/// preferences. Pure Dart, no strings, no widgets; nothing reaches the
/// screen yet (flag `ostinatoFallbackModeEnabled`, closed).
library;

/// At or above this text scale the compact layout must not be used. 1.3 is the
/// text-scale checkpoint from the acceptance criteria; there is no precedent
/// for it elsewhere in the repo.
const double a11yLargeTextScale = 1.3;

/// Range the decision accepts; values outside are clamped.
const double a11yMinTextScale = 1.0;
const double a11yMaxTextScale = 3.0;

/// Motion level for animated elements.
enum PracticeMotion { full, reduced }

/// The learner's preferences (usually read from MediaQuery).
final class PracticeA11yPrefs {
  const PracticeA11yPrefs({
    this.reduceMotion = false,
    this.reduceTransparency = false,
    this.highContrast = false,
    this.textScale = 1.0,
  });

  final bool reduceMotion;
  final bool reduceTransparency;
  final bool highContrast;
  final double textScale;
}

/// What the presentation should do. Decision only.
final class PracticeA11yPlan {
  const PracticeA11yPlan({
    required this.motion,
    required this.opaqueSurfaces,
    required this.strongBorders,
    required this.effectiveTextScale,
    required this.noCompactLayout,
  });

  /// [PracticeMotion.reduced]: no looping or travelling animation; state
  /// changes are instant or a plain fade.
  final PracticeMotion motion;

  /// Glass layers use their opaque fallback. This is the user-preference part
  /// of `glass_layer.dart`'s opaque condition (`reduceTransparency ||
  /// highContrast`); `lowHardware` / blur budget is a separate decision. The
  /// binder must feed MediaQuery values into [PracticeA11yPrefs].
  final bool opaqueSurfaces;

  /// Edges and separators drawn at full contrast.
  final bool strongBorders;

  /// Sanitised scale in [a11yMinTextScale, a11yMaxTextScale].
  final double effectiveTextScale;

  /// True at [a11yLargeTextScale] and above: no cramped/compact layout.
  final bool noCompactLayout;

  bool get reducedMotion => motion == PracticeMotion.reduced;
}

PracticeA11yPlan planFor(PracticeA11yPrefs prefs) {
  final raw = prefs.textScale;
  final scale = raw.isNaN
      ? a11yMinTextScale
      : raw.clamp(a11yMinTextScale, a11yMaxTextScale).toDouble();
  return PracticeA11yPlan(
    motion: prefs.reduceMotion ? PracticeMotion.reduced : PracticeMotion.full,
    opaqueSurfaces: prefs.reduceTransparency || prefs.highContrast,
    strongBorders: prefs.highContrast,
    effectiveTextScale: scale,
    noCompactLayout: scale >= a11yLargeTextScale,
  );
}
