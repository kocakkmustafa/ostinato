import 'package:flutter/material.dart';

import 'design/ostinato_theme.dart' show InstrumentHue;

/// Presentation colors only. Measurement ranges, score values, note identity,
/// ownership epochs, progress revisions and content bytes do not belong here.
@immutable
final class OstinatoPalette extends ThemeExtension<OstinatoPalette> {
  const OstinatoPalette({
    required this.ink,
    required this.inkSoft,
    required this.textBody,
    required this.textMuted,
    required this.textFaint,
    required this.textMono,
    required this.shell,
    required this.surface,
    required this.warnInk,
    required this.error,
    required this.onError,
    required this.success,
    required this.primary,
    required this.onPrimary,
    required this.focus,
    required this.outline,
    required this.divider,
    required this.glassStart,
    required this.glassEnd,
    required this.glassBorder,
    required this.glassShadow,
    required this.controlSurface,
    required this.controlBorder,
    required this.disabledBackground,
    required this.disabledForeground,
    required this.selection,
    required this.notationPaper,
    required this.notationInk,
    required this.guitar,
    required this.voice,
    required this.piano,
  });

  final Color ink;
  final Color inkSoft;
  final Color textBody;
  final Color textMuted;
  final Color textFaint;
  final Color textMono;
  final Color shell;
  final Color surface;
  final Color warnInk;
  final Color error;
  final Color onError;
  final Color success;
  final Color primary;
  final Color onPrimary;
  final Color focus;
  final Color outline;
  final Color divider;
  final Color glassStart;
  final Color glassEnd;
  final Color glassBorder;
  final Color glassShadow;
  final Color controlSurface;
  final Color controlBorder;
  final Color disabledBackground;
  final Color disabledForeground;
  final Color selection;
  final Color notationPaper;
  final Color notationInk;
  final InstrumentHue guitar;
  final InstrumentHue voice;
  final InstrumentHue piano;

  static OstinatoPalette of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<OstinatoPalette>() ??
        (theme.brightness == Brightness.dark ? dark : light);
  }

  InstrumentHue instrument(String id) => switch (id) {
    'voice' => voice,
    'piano' => piano,
    _ => guitar,
  };

  @override
  OstinatoPalette copyWith({
    Color? ink,
    Color? inkSoft,
    Color? textBody,
    Color? textMuted,
    Color? textFaint,
    Color? textMono,
    Color? shell,
    Color? surface,
    Color? warnInk,
    Color? error,
    Color? onError,
    Color? success,
    Color? primary,
    Color? onPrimary,
    Color? focus,
    Color? outline,
    Color? divider,
    Color? glassStart,
    Color? glassEnd,
    Color? glassBorder,
    Color? glassShadow,
    Color? controlSurface,
    Color? controlBorder,
    Color? disabledBackground,
    Color? disabledForeground,
    Color? selection,
    Color? notationPaper,
    Color? notationInk,
    InstrumentHue? guitar,
    InstrumentHue? voice,
    InstrumentHue? piano,
  }) => OstinatoPalette(
    ink: ink ?? this.ink,
    inkSoft: inkSoft ?? this.inkSoft,
    textBody: textBody ?? this.textBody,
    textMuted: textMuted ?? this.textMuted,
    textFaint: textFaint ?? this.textFaint,
    textMono: textMono ?? this.textMono,
    shell: shell ?? this.shell,
    surface: surface ?? this.surface,
    warnInk: warnInk ?? this.warnInk,
    error: error ?? this.error,
    onError: onError ?? this.onError,
    success: success ?? this.success,
    primary: primary ?? this.primary,
    onPrimary: onPrimary ?? this.onPrimary,
    focus: focus ?? this.focus,
    outline: outline ?? this.outline,
    divider: divider ?? this.divider,
    glassStart: glassStart ?? this.glassStart,
    glassEnd: glassEnd ?? this.glassEnd,
    glassBorder: glassBorder ?? this.glassBorder,
    glassShadow: glassShadow ?? this.glassShadow,
    controlSurface: controlSurface ?? this.controlSurface,
    controlBorder: controlBorder ?? this.controlBorder,
    disabledBackground: disabledBackground ?? this.disabledBackground,
    disabledForeground: disabledForeground ?? this.disabledForeground,
    selection: selection ?? this.selection,
    notationPaper: notationPaper ?? this.notationPaper,
    notationInk: notationInk ?? this.notationInk,
    guitar: guitar ?? this.guitar,
    voice: voice ?? this.voice,
    piano: piano ?? this.piano,
  );

  @override
  OstinatoPalette lerp(covariant OstinatoPalette? other, double t) {
    if (other == null) return this;
    return OstinatoPalette(
      ink: Color.lerp(ink, other.ink, t)!,
      inkSoft: Color.lerp(inkSoft, other.inkSoft, t)!,
      textBody: Color.lerp(textBody, other.textBody, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      textFaint: Color.lerp(textFaint, other.textFaint, t)!,
      textMono: Color.lerp(textMono, other.textMono, t)!,
      shell: Color.lerp(shell, other.shell, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      warnInk: Color.lerp(warnInk, other.warnInk, t)!,
      error: Color.lerp(error, other.error, t)!,
      onError: Color.lerp(onError, other.onError, t)!,
      success: Color.lerp(success, other.success, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      focus: Color.lerp(focus, other.focus, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      glassStart: Color.lerp(glassStart, other.glassStart, t)!,
      glassEnd: Color.lerp(glassEnd, other.glassEnd, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      glassShadow: Color.lerp(glassShadow, other.glassShadow, t)!,
      controlSurface: Color.lerp(controlSurface, other.controlSurface, t)!,
      controlBorder: Color.lerp(controlBorder, other.controlBorder, t)!,
      disabledBackground: Color.lerp(disabledBackground, other.disabledBackground, t)!,
      disabledForeground: Color.lerp(disabledForeground, other.disabledForeground, t)!,
      selection: Color.lerp(selection, other.selection, t)!,
      notationPaper: Color.lerp(notationPaper, other.notationPaper, t)!,
      notationInk: Color.lerp(notationInk, other.notationInk, t)!,
      guitar: _lerpHue(guitar, other.guitar, t),
      voice: _lerpHue(voice, other.voice, t),
      piano: _lerpHue(piano, other.piano, t),
    );
  }

  static const light = OstinatoPalette(
    ink: Color(0xFF2A2533),
    inkSoft: Color(0xFF3E3849),
    textBody: Color(0xFF4E4759),
    textMuted: Color(0xFF5F586D),
    textFaint: Color(0xFF5F586D),
    textMono: Color(0xFF5F586D),
    shell: Color(0xFFEDE9F0),
    surface: Color(0xFFF4F1F6),
    warnInk: Color(0xFF7E4230),
    error: Color(0xFF9B2420),
    onError: Color(0xFFFFFFFF),
    success: Color(0xFF28664A),
    primary: Color(0xFF5F4CA0),
    onPrimary: Color(0xFFFFFFFF),
    focus: Color(0xFF5F4CA0),
    outline: Color(0xFF82748E),
    divider: Color(0xFFB8ADBF),
    glassStart: Color(0xEBFFFFFF),
    glassEnd: Color(0x8FFFFFFF),
    glassBorder: Color(0xD9FFFFFF),
    glassShadow: Color(0x2940305A),
    controlSurface: Color(0xFFEAE4F0),
    controlBorder: Color(0xFF82748E),
    disabledBackground: Color(0xFFDDD7E4),
    disabledForeground: Color(0xFF645C70),
    selection: Color(0xFFE1D5F5),
    notationPaper: Color(0xFFFFFDF8),
    notationInk: Color(0xFF2A2533),
    guitar: InstrumentHue(
      grad: <Color>[Color(0xF2FFD9BE), Color(0xCCF8C6D4)],
      gradAlt: <Color>[Color(0xE6F8C6D4), Color(0xC7FFDECD)],
      soft: <Color>[Color(0x80FFD9BE), Color(0x57F8C6D4)],
      chip: Color(0xB3FFD9BE),
      band: Color(0x389A4E3E),
      ink: Color(0xFF8F483A),
    ),
    voice: InstrumentHue(
      grad: <Color>[Color(0xF2DACDF6), Color(0xCCC3DDF8)],
      gradAlt: <Color>[Color(0xE6C3DDF8), Color(0xC7DED3F8)],
      soft: <Color>[Color(0x80DACDF6), Color(0x57C3DDF8)],
      chip: Color(0xB3DACDF6),
      band: Color(0x335F4CA0),
      ink: Color(0xFF5F4CA0),
    ),
    piano: InstrumentHue(
      grad: <Color>[Color(0xF2C4EADB), Color(0xCCC9E3F1)],
      gradAlt: <Color>[Color(0xE6C9E3F1), Color(0xC7CAEEE0)],
      soft: <Color>[Color(0x80C4EADB), Color(0x57C9E3F1)],
      chip: Color(0xBFC4EADB),
      band: Color(0x332E7566),
      ink: Color(0xFF2A6D5F),
    ),
  );

  static const dark = OstinatoPalette(
    ink: Color(0xFFF0EBF6),
    inkSoft: Color(0xFFE3DCEB),
    textBody: Color(0xFFD6CFDF),
    textMuted: Color(0xFFBEB4CE),
    textFaint: Color(0xFFBEB4CE),
    textMono: Color(0xFFBCB2CD),
    shell: Color(0xFF1A1721),
    surface: Color(0xFF24202E),
    warnInk: Color(0xFFFFC3A1),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF4C1712),
    success: Color(0xFF9BDBB5),
    primary: Color(0xFFD9C6FF),
    onPrimary: Color(0xFF342055),
    focus: Color(0xFFD9C6FF),
    outline: Color(0xFF9B8DAA),
    divider: Color(0xFF65596F),
    glassStart: Color(0xEB302B3E),
    glassEnd: Color(0xE6231F2B),
    glassBorder: Color(0xFF65596F),
    glassShadow: Color(0x66000000),
    controlSurface: Color(0xFF362E43),
    controlBorder: Color(0xFF9B8DAA),
    disabledBackground: Color(0xFF39313F),
    disabledForeground: Color(0xFFBBB1C6),
    selection: Color(0xFF4A3B62),
    notationPaper: Color(0xFF1E1B27),
    notationInk: Color(0xFFEAE2F3),
    guitar: InstrumentHue(
      grad: <Color>[Color(0xFF442F2D), Color(0xFF3B2939)],
      gradAlt: <Color>[Color(0xFF3B2939), Color(0xFF463129)],
      soft: <Color>[Color(0xFF39282A), Color(0xFF30242F)],
      chip: Color(0xFF503632),
      band: Color(0x66896052),
      ink: Color(0xFFF5C7B1),
    ),
    voice: InstrumentHue(
      grad: <Color>[Color(0xFF342B4A), Color(0xFF27394C)],
      gradAlt: <Color>[Color(0xFF27394C), Color(0xFF3C2E4D)],
      soft: <Color>[Color(0xFF30283E), Color(0xFF243140)],
      chip: Color(0xFF42344F),
      band: Color(0x66A58ECC),
      ink: Color(0xFFD8C8FF),
    ),
    piano: InstrumentHue(
      grad: <Color>[Color(0xFF253D35), Color(0xFF293D4A)],
      gradAlt: <Color>[Color(0xFF293D4A), Color(0xFF2C4238)],
      soft: <Color>[Color(0xFF21342E), Color(0xFF253540)],
      chip: Color(0xFF2E4B40),
      band: Color(0x6680C8AF),
      ink: Color(0xFFB0E3CF),
    ),
  );

}

InstrumentHue _lerpHue(InstrumentHue a, InstrumentHue b, double t) {
  List<Color> colors(List<Color> first, List<Color> second) =>
      List<Color>.unmodifiable(List<Color>.generate(
        first.length, (i) => Color.lerp(first[i], second[i], t)!,
      ));
  return InstrumentHue(
    grad: colors(a.grad, b.grad),
    gradAlt: colors(a.gradAlt, b.gradAlt),
    soft: colors(a.soft, b.soft),
    chip: Color.lerp(a.chip, b.chip, t)!,
    band: Color.lerp(a.band, b.band, t)!,
    ink: Color.lerp(a.ink, b.ink, t)!,
  );
}

abstract final class OstinatoThemes {
  static final ThemeData light = _build(Brightness.light, OstinatoPalette.light);
  static final ThemeData dark = _build(Brightness.dark, OstinatoPalette.dark);

  static ThemeData forBrightness(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  static ThemeData _build(Brightness brightness, OstinatoPalette p) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF5F4CA0),
      brightness: brightness,
    ).copyWith(
      primary: p.primary,
      onPrimary: p.onPrimary,
      secondary: p.voice.ink,
      onSecondary: p.onPrimary,
      error: p.error,
      onError: p.onError,
      surface: p.surface,
      onSurface: p.ink,
      onSurfaceVariant: p.textBody,
      surfaceContainerLowest: p.shell,
      surfaceContainerLow: p.surface,
      surfaceContainer: p.surface,
      surfaceContainerHigh: p.controlSurface,
      surfaceContainerHighest: p.controlSurface,
      surfaceDim: p.shell,
      surfaceBright: p.surface,
      surfaceTint: Colors.transparent,
      outline: p.outline,
      outlineVariant: p.divider,
    );
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.shell,
      fontFamily: 'Hanken Grotesk',
      extensions: <ThemeExtension<dynamic>>[p],
    );
    WidgetStateProperty<Color?> stateColor(Color normal, Color disabled) =>
        WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.disabled) ? disabled : normal);
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: width),
        );
    return base.copyWith(
      pageTransitionsTheme: PageTransitionsTheme(builders: {
        for (final entry in base.pageTransitionsTheme.builders.entries)
          entry.key: _ReducedMotionPageTransitionsBuilder(entry.value),
      }),
      textTheme: base.textTheme.apply(bodyColor: p.ink, displayColor: p.ink),
      iconTheme: IconThemeData(color: p.inkSoft),
      dividerColor: p.divider,
      disabledColor: p.disabledForeground,
      focusColor: p.focus.withValues(alpha: .18),
      hoverColor: p.focus.withValues(alpha: .08),
      highlightColor: p.focus.withValues(alpha: .12),
      appBarTheme: AppBarTheme(
        backgroundColor: p.shell,
        foregroundColor: p.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: p.focus,
        selectionColor: p.selection,
        selectionHandleColor: p.focus,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.controlSurface,
        labelStyle: TextStyle(color: p.textBody),
        hintStyle: TextStyle(color: p.textMuted),
        errorStyle: TextStyle(color: p.error),
        border: border(p.controlBorder),
        enabledBorder: border(p.controlBorder),
        disabledBorder: border(p.disabledForeground),
        focusedBorder: border(p.focus, 2),
        errorBorder: border(p.error),
        focusedErrorBorder: border(p.error, 2),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          foregroundColor: stateColor(p.onPrimary, p.disabledForeground),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return p.disabledBackground;
            if (states.contains(WidgetState.focused)) {
              return Color.alphaBlend(p.onPrimary.withValues(alpha: .10), p.primary);
            }
            return p.primary;
          }),
          side: WidgetStateProperty.resolveWith((states) => BorderSide(
            color: states.contains(WidgetState.focused) ? p.onPrimary : Colors.transparent,
            width: 2,
          )),
          minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: stateColor(p.ink, p.disabledForeground),
          backgroundColor: stateColor(p.controlSurface, p.disabledBackground),
          side: WidgetStateProperty.resolveWith((states) => BorderSide(
            color: states.contains(WidgetState.focused) ? p.focus : p.controlBorder,
            width: states.contains(WidgetState.focused) ? 2 : 1,
          )),
          minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          foregroundColor: stateColor(p.inkSoft, p.disabledForeground),
          overlayColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.focused) ? p.focus.withValues(alpha: .18) : null),
          side: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.focused)
              ? BorderSide(color: p.focus, width: 2)
              : BorderSide.none),
          minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.ink,
        contentTextStyle: TextStyle(fontFamily: 'Hanken Grotesk', color: p.surface),
        actionTextColor: p.surface,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: p.ink,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: TextStyle(fontFamily: 'Hanken Grotesk', color: p.surface),
      ),
    );
  }
}

/// Preserve each platform's normal route transition and duration. When the
/// operating system requests reduced motion, present the same route child
/// without a visual transform. This changes no Navigator or route identity.
final class _ReducedMotionPageTransitionsBuilder extends PageTransitionsBuilder {
  const _ReducedMotionPageTransitionsBuilder(this.fallback);
  final PageTransitionsBuilder fallback;

  @override
  Duration get transitionDuration => fallback.transitionDuration;

  @override
  Duration get reverseTransitionDuration => fallback.reverseTransitionDuration;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => MediaQuery.disableAnimationsOf(context)
      ? child
      : fallback.buildTransitions(route, context, animation, secondaryAnimation, child);

  @override
  DelegatedTransitionBuilder? get delegatedTransition {
    final transition = fallback.delegatedTransition;
    if (transition == null) return null;
    return (context, animation, secondaryAnimation, allowSnapshotting, child) =>
        MediaQuery.disableAnimationsOf(context)
          ? child
          : transition(context, animation, secondaryAnimation, allowSnapshotting, child);
  }
}
