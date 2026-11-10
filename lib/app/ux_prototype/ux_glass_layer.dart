import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../app_theme.dart';

/// The prototype's one glass surface (04-design.md §6): a temporary layer on
/// top of the stage. Rules it keeps, each covered by a test:
///  - blur sigma never above [blurSigma] (16 logical pixels at most);
///  - the surface stays at least [surfaceAlpha] opaque, so body text keeps
///    4.5:1 even over the worst background behind it;
///  - high contrast (the system "increase contrast" / reduce transparency
///    family) draws the layer fully opaque with no blur at all;
///  - reduced motion (`disableAnimations`) shows the layer at once, no slide.
/// The stage never builds this widget while a run is playing.
class UxGlassLayer extends StatelessWidget {
  const UxGlassLayer({super.key, required this.child});

  final Widget child;

  /// Upper bound from the design (sigma <= 16); the layer uses less.
  static const double blurSigma = 12;

  /// Minimum opacity of the layer surface over the blurred stage.
  static const double surfaceAlpha = 0.94;

  @override
  Widget build(BuildContext context) {
    final palette = OstinatoPalette.of(context);
    final opaque = MediaQuery.highContrastOf(context);
    final instant = MediaQuery.disableAnimationsOf(context);
    const radius = BorderRadius.vertical(top: Radius.circular(22));
    final surface = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        color: opaque
            ? palette.surface
            : palette.surface.withValues(alpha: surfaceAlpha),
        border: Border(top: BorderSide(color: palette.glassBorder)),
      ),
      child: Material(type: MaterialType.transparency, child: child),
    );
    final body = opaque
        ? ClipRRect(borderRadius: radius, child: surface)
        : ClipRRect(
            borderRadius: radius,
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
              child: surface,
            ),
          );
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: instant ? Duration.zero : const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 24),
          child: child,
        ),
      ),
      child: body,
    );
  }
}
