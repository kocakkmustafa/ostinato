import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../app_theme.dart';

/// OST-UX-05a: the glass core (04-design.md ADR-UX-001, section 6).
///
/// A reusable temporary layer with an opaque fallback. No screen uses it.
/// All numbers below are public so tests pin them.
abstract final class GlassLayerConfig {
  /// Hard design ceiling for blur sigma.
  static const double maxBlurSigma = 16;

  /// Sigma the layer actually uses (kept under [maxBlurSigma]).
  static const double blurSigma = 12;

  /// Surface opacity over the blurred backdrop (keeps text at 4.5:1).
  static const double surfaceAlpha = 0.94;

  /// Largest share of the host height a blurred layer may cover.
  static const double maxBlurAreaFraction = 0.6;

  /// Default share of the host height (equals the ceiling).
  static const double defaultAreaFraction = 0.6;

  /// Glass items alive at once (a third request is rejected).
  static const int maxGlassItems = 2;

  /// Blurred surfaces alive at once.
  static const int maxBlurSurfaces = 1;

  /// Frames ignored at the start (startup jank must not latch low hardware).
  static const int warmupFrames = 30;

  /// Show/hide transition; zero when motion is reduced.
  static const Duration transition = Duration(milliseconds: 220);

  /// Layer surface colour: fully opaque, or [surfaceAlpha] over the backdrop.
  static Color surfaceColor(OstinatoPalette palette, {required bool opaque}) =>
      opaque
      ? palette.surface
      : palette.surface.withValues(alpha: surfaceAlpha);
}

/// Measures frame cost. Injectable so tests can fake it.
abstract interface class FrameBudgetMonitor implements Listenable {
  /// True once the device has missed the frame budget for long enough.
  bool get overBudget;

  void dispose();
}

/// Default monitor: after [GlassLayerConfig.warmupFrames] ignored frames, a run
/// of [consecutiveFrames] frames whose build + raster time exceeds [budget]
/// latches the low-hardware flag for the monitor's lifetime (no reset, so the
/// layer does not flicker between blur and opaque).
class TimingsFrameBudgetMonitor extends ChangeNotifier
    implements FrameBudgetMonitor {
  TimingsFrameBudgetMonitor({
    this.budget = defaultBudget,
    this.consecutiveFrames = defaultConsecutiveFrames,
    bool attach = true,
    this.warmupFrames = GlassLayerConfig.warmupFrames,
    void Function(ui.TimingsCallback)? register,
    void Function(ui.TimingsCallback)? unregister,
  }) : _attached = attach,
       _unregister = unregister {
    if (attach) {
      (register ?? SchedulerBinding.instance.addTimingsCallback)(onTimings);
    }
  }

  static const Duration defaultBudget = Duration(milliseconds: 20);
  static const int defaultConsecutiveFrames = 8;

  final Duration budget;
  final int consecutiveFrames;
  final int warmupFrames;
  final bool _attached;
  final void Function(ui.TimingsCallback)? _unregister;
  int _seen = 0;
  int _run = 0;
  bool _over = false;

  @override
  bool get overBudget => _over;

  void onTimings(List<FrameTiming> timings) {
    for (final t in timings) {
      recordFrame(t.buildDuration + t.rasterDuration);
    }
  }

  /// Feed one frame cost (build + raster).
  void recordFrame(Duration cost) {
    if (_over) return;
    if (_seen < warmupFrames) {
      _seen++;
      return;
    }
    _run = cost > budget ? _run + 1 : 0;
    if (_run >= consecutiveFrames) {
      _over = true;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    if (_attached) {
      (_unregister ?? SchedulerBinding.instance.removeTimingsCallback)(
        onTimings,
      );
    }
    super.dispose();
  }
}

/// Counts open glass items and holds the play state. Pure Dart state, no
/// dependency on measurement or playback code: the host feeds [playing].
///  - at most [GlassLayerConfig.maxGlassItems] open; a further [tryOpen]
///    is REJECTED (returns false); the first item is never closed for it;
///  - only the oldest open item may blur (one blurred surface at most);
///  - while [playing] no item is open and none can open. A mounted
///    [GlassLayer] is a standing request: it is admitted again (in listener registration order)
///    whenever playing ends or a slot frees up.
class GlassLayerBudget extends ChangeNotifier {
  GlassLayerBudget({this.monitor});

  /// Optional frame cost monitor; over budget = low hardware = no blur.
  final FrameBudgetMonitor? monitor;

  final List<Object> _open = <Object>[];
  bool _playing = false;
  bool _disposed = false;

  bool get playing => _playing;
  int get openCount => _open.length;
  bool get lowHardware => monitor?.overBudget ?? false;

  /// Open items that are admitted to blur (0 or 1). A layer may still draw
  /// opaque (reduced transparency); this is the upper bound on BackdropFilters.
  int get blurAdmittedCount => _open.isEmpty || _playing || lowHardware ? 0 : 1;

  set playing(bool value) {
    if (_playing == value) return;
    _playing = value;
    if (value) _open.clear();
    notifyListeners();
  }

  bool isOpen(Object id) => _open.contains(id);

  bool holdsBlur(Object id) => blurAdmittedCount == 1 && _open.first == id;

  /// Asks for a glass slot. False when playing or already full.
  bool tryOpen(Object id) {
    if (_playing || _open.contains(id)) return !_playing && isOpen(id);
    if (_open.length >= GlassLayerConfig.maxGlassItems) return false;
    _open.add(id);
    return true;
  }

  void close(Object id) {
    if (!_open.remove(id)) return;
    if (_disposed) return;
    // May run while the tree is being torn down; notify after the frame.
    scheduleMicrotask(() {
      if (!_disposed) notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// The glass layer: bottom sheet-like surface, at most
/// [GlassLayerConfig.maxBlurAreaFraction] of the host height.
/// Needs a bounded-height parent (for example a `Stack` filling the stage).
class GlassLayer extends StatefulWidget {
  const GlassLayer({
    super.key,
    required this.budget,
    required this.child,
    this.areaFraction = GlassLayerConfig.defaultAreaFraction,
    this.reduceTransparency = false,
    this.semanticLabel,
  });

  final GlassLayerBudget budget;
  final Widget child;

  /// Share of host height; clamped to the blur-area ceiling.
  final double areaFraction;

  /// Injectable "reduce transparency" signal (Flutter exposes no separate iOS
  /// flag; see 04-design deviation note). OR-ed with `MediaQuery.highContrast`.
  final bool reduceTransparency;

  /// Accessibility label supplied by the caller (the layer invents no text).
  final String? semanticLabel;

  @override
  State<GlassLayer> createState() => _GlassLayerState();
}

class _GlassLayerState extends State<GlassLayer> {
  @override
  void initState() {
    super.initState();
    widget.budget.tryOpen(this);
  }

  @override
  void didUpdateWidget(GlassLayer old) {
    super.didUpdateWidget(old);
    if (old.budget != widget.budget) {
      old.budget.close(this);
      widget.budget.tryOpen(this);
    }
  }

  @override
  void dispose() {
    widget.budget.close(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final budget = widget.budget;
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable?>[budget, budget.monitor]),
      builder: (context, _) {
        // Standing request: retry admission (no-op while playing or full).
        if (budget.playing || !budget.tryOpen(this)) {
          return const SizedBox.shrink();
        }
        return _body(context, budget);
      },
    );
  }

  Widget _body(BuildContext context, GlassLayerBudget budget) {
    final palette = OstinatoPalette.of(context);
    final opaque =
        MediaQuery.highContrastOf(context) ||
        widget.reduceTransparency ||
        budget.lowHardware ||
        !budget.holdsBlur(this);
    final instant = MediaQuery.disableAnimationsOf(context);
    const radius = BorderRadius.vertical(top: Radius.circular(22));
    final surface = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        color: GlassLayerConfig.surfaceColor(palette, opaque: opaque),
        border: Border(top: BorderSide(color: palette.glassBorder)),
      ),
      child: Material(type: MaterialType.transparency, child: widget.child),
    );
    final body = ClipRRect(
      borderRadius: radius,
      child: opaque
          ? surface
          : BackdropFilter(
              filter: ui.ImageFilter.blur(
                sigmaX: GlassLayerConfig.blurSigma,
                sigmaY: GlassLayerConfig.blurSigma,
              ),
              child: surface,
            ),
    );
    final fraction = widget.areaFraction.clamp(
      0.0,
      GlassLayerConfig.maxBlurAreaFraction,
    );
    return Align(
      alignment: Alignment.bottomCenter,
      child: FractionallySizedBox(
        widthFactor: 1,
        heightFactor: fraction,
        child: Semantics(
          container: true,
          label: widget.semanticLabel,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: instant ? Duration.zero : GlassLayerConfig.transition,
            curve: Curves.easeOutCubic,
            builder: (context, t, child) => Opacity(
              opacity: t,
              child: Transform.translate(
                offset: Offset(0, (1 - t) * 24),
                child: child,
              ),
            ),
            child: body,
          ),
        ),
      ),
    );
  }
}
