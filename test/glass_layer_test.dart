// OST-UX-05a: GlassLayer core. Each group maps to one acceptance item
// (docs/yula-execution/design/05a-olcut-tablosu.md).
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show FrameTiming, TimingsCallback;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/app_theme.dart';
import 'package:ostinato/app/design/glass_layer.dart';

class _FakeMonitor extends ChangeNotifier implements FrameBudgetMonitor {
  bool _over = false;
  @override
  bool get overBudget => _over;
  void trip() {
    _over = true;
    notifyListeners();
  }
}

Widget _host(
  Widget child, {
  Brightness brightness = Brightness.light,
  bool highContrast = false,
  bool disableAnimations = false,
}) => MaterialApp(
  theme: ThemeData(brightness: brightness),
  builder: (context, c) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      highContrast: highContrast,
      disableAnimations: disableAnimations,
    ),
    child: c!,
  ),
  home: Scaffold(body: SizedBox(width: 400, height: 800, child: child)),
);

Widget _layer(GlassLayerBudget b, {String label = 'x', bool reduce = false}) =>
    GlassLayer(
      key: ValueKey<String>(label),
      budget: b,
      reduceTransparency: reduce,
      child: Text(label),
    );

/// True when the layer keyed [label] is the one drawing the BackdropFilter.
bool _blurs(String label) => find
    .descendant(
      of: find.byKey(ValueKey<String>(label)),
      matching: find.byType(BackdropFilter),
    )
    .evaluate()
    .isNotEmpty;

Widget _stack(List<Widget> layers) =>
    Stack(children: <Widget>[const SizedBox.expand(), ...layers]);

double _lum(Color c) {
  double ch(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

double _ratio(Color a, Color b) {
  final x = _lum(a), y = _lum(b);
  return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
}

Color _over(Color top, Color bg) => Color.alphaBlend(top, bg);

void main() {
  group('olcut1 one blurred surface; none while playing', () {
    testWidgets('two open layers draw one BackdropFilter', (t) async {
      final b = GlassLayerBudget();
      addTearDown(b.dispose);
      await t.pumpWidget(_host(_stack([_layer(b, label: 'a'), _layer(b)])));
      await t.pump(const Duration(milliseconds: 300));
      expect(b.openCount, 2);
      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(_blurs('a'), isTrue, reason: 'oldest layer holds the blur');
      expect(_blurs('x'), isFalse);
      expect(b.blurAdmittedCount, 1);
    });

    testWidgets('playing: zero blur and zero glass items', (t) async {
      final b = GlassLayerBudget();
      addTearDown(b.dispose);
      await t.pumpWidget(_host(_stack([_layer(b, label: 'a')])));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.byType(BackdropFilter), findsOneWidget);
      b.playing = true;
      await t.pump();
      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.text('a'), findsNothing);
      expect(b.openCount, 0);
      expect(b.blurAdmittedCount, 0);
      expect(b.tryOpen(Object()), isFalse);
    });

    testWidgets('a layer mounted while playing stays empty', (t) async {
      final b = GlassLayerBudget()..playing = true;
      addTearDown(b.dispose);
      await t.pumpWidget(_host(_stack([_layer(b, label: 'a')])));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('a'), findsNothing);
      expect(find.byType(BackdropFilter), findsNothing);
    });
  });

  group('olcut2 at most two glass items; third is rejected', () {
    test('budget: third tryOpen returns false, first stays', () {
      final b = GlassLayerBudget();
      final a = Object(), c = Object(), d = Object();
      expect(b.tryOpen(a), isTrue);
      expect(b.tryOpen(c), isTrue);
      expect(b.tryOpen(d), isFalse);
      expect(b.isOpen(a), isTrue);
      expect(b.isOpen(d), isFalse);
      expect(b.openCount, 2);
      b.close(a);
      expect(b.tryOpen(d), isTrue);
    });

    testWidgets('widgets: third layer renders nothing', (t) async {
      final b = GlassLayerBudget();
      addTearDown(b.dispose);
      await t.pumpWidget(
        _host(
          _stack([
            _layer(b, label: 'one'),
            _layer(b, label: 'two'),
            _layer(b, label: 'three'),
          ]),
        ),
      );
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('one'), findsOneWidget);
      expect(find.text('two'), findsOneWidget);
      expect(find.text('three'), findsNothing);
      expect(_blurs('one'), isTrue);
      expect(_blurs('two'), isFalse);
      expect(b.openCount, 2);
    });
  });

  group('olcut3 reduce transparency and reduce motion', () {
    testWidgets('normal: blur', (t) async {
      final b = GlassLayerBudget();
      addTearDown(b.dispose);
      await t.pumpWidget(_host(_stack([_layer(b)])));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    testWidgets('highContrast: opaque, no blur', (t) async {
      final b = GlassLayerBudget();
      addTearDown(b.dispose);
      await t.pumpWidget(_host(_stack([_layer(b)]), highContrast: true));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.byType(BackdropFilter), findsNothing);
      final deco = t.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(GlassLayer),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect((deco.decoration as BoxDecoration).color!.a, 1);
    });

    testWidgets('injected reduceTransparency: opaque, no blur', (t) async {
      final b = GlassLayerBudget();
      addTearDown(b.dispose);
      await t.pumpWidget(_host(_stack([_layer(b, reduce: true)])));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('disableAnimations: shown at once', (t) async {
      final b = GlassLayerBudget();
      addTearDown(b.dispose);
      await t.pumpWidget(_host(_stack([_layer(b)]), disableAnimations: true));
      await t.pump();
      final o = t.widget<Opacity>(
        find
            .descendant(
              of: find.byType(GlassLayer),
              matching: find.byType(Opacity),
            )
            .first,
      );
      expect(o.opacity, 1);
    });

    testWidgets('motion on: starts transparent, 220 ms transition', (t) async {
      final b = GlassLayerBudget();
      addTearDown(b.dispose);
      await t.pumpWidget(_host(_stack([_layer(b)])));
      await t.pump();
      await t.pump(const Duration(milliseconds: 20));
      final o = t.widget<Opacity>(
        find
            .descendant(
              of: find.byType(GlassLayer),
              matching: find.byType(Opacity),
            )
            .first,
      );
      expect(o.opacity, lessThan(1));
      expect(GlassLayerConfig.transition, const Duration(milliseconds: 220));
      await t.pump(const Duration(milliseconds: 300));
    });
  });

  group('olcut4 contrast on the worst backdrop', () {
    for (final entry in <String, OstinatoPalette>{
      'light': OstinatoPalette.light,
      'dark': OstinatoPalette.dark,
    }.entries) {
      final p = entry.value;
      for (final opaque in <bool>[true, false]) {
        test('${entry.key} ${opaque ? "opaque" : "translucent"}', () {
          // Worst backdrops are the extremes (luminance is linear in the blend).
          for (final bg in <Color>[Colors.black, Colors.white]) {
            final layer = _over(
              GlassLayerConfig.surfaceColor(p, opaque: opaque),
              bg,
            );
            for (final text in <Color>[
              p.ink,
              p.inkSoft,
              p.textBody,
              p.textMuted,
              p.textFaint,
            ]) {
              expect(
                _ratio(text, layer),
                greaterThanOrEqualTo(4.5),
                reason: 'text $text over $layer',
              );
            }
            expect(_ratio(p.onPrimary, p.primary), greaterThanOrEqualTo(4.5));
            for (final comp in <Color>[
              p.primary,
              p.controlBorder,
              p.outline,
              p.focus,
            ]) {
              expect(
                _ratio(comp, layer),
                greaterThanOrEqualTo(3),
                reason: 'component $comp over $layer',
              );
            }
          }
        });
      }
    }
  });

  group('olcut5 blur budget constants', () {
    test('sigma <= 16 and area <= 60%', () {
      expect(GlassLayerConfig.maxBlurSigma, 16);
      expect(GlassLayerConfig.blurSigma, lessThanOrEqualTo(16));
      expect(GlassLayerConfig.maxBlurAreaFraction, lessThanOrEqualTo(0.6));
      expect(
        GlassLayerConfig.defaultAreaFraction,
        lessThanOrEqualTo(GlassLayerConfig.maxBlurAreaFraction),
      );
      expect(GlassLayerConfig.surfaceAlpha, greaterThanOrEqualTo(0.9));
      expect(GlassLayerConfig.maxGlassItems, 2);
      expect(GlassLayerConfig.maxBlurSurfaces, 1);
    });

    testWidgets('area fraction is clamped to the ceiling', (t) async {
      final b = GlassLayerBudget();
      addTearDown(b.dispose);
      await t.pumpWidget(
        _host(
          _stack([
            GlassLayer(budget: b, areaFraction: 1, child: const Text('x')),
          ]),
        ),
      );
      await t.pump(const Duration(milliseconds: 300));
      final h = t.getSize(find.byType(ClipRRect).first).height;
      expect(h, lessThanOrEqualTo(800 * 0.6 + 0.01));
    });
  });

  group('olcut6 low hardware falls back to opaque', () {
    test('monitor latches after N consecutive slow frames', () {
      final m = TimingsFrameBudgetMonitor(attach: false, warmupFrames: 0);
      for (var i = 0; i < 7; i++) {
        m.recordFrame(const Duration(milliseconds: 30));
      }
      expect(m.overBudget, isFalse);
      m.recordFrame(const Duration(milliseconds: 5)); // resets the run
      for (var i = 0; i < 7; i++) {
        m.recordFrame(const Duration(milliseconds: 30));
      }
      expect(m.overBudget, isFalse);
      m.recordFrame(const Duration(milliseconds: 30));
      expect(m.overBudget, isTrue);
      m.dispose();
    });

    test('monitor reads FrameTiming build + raster', () {
      final m = TimingsFrameBudgetMonitor(attach: false, warmupFrames: 0);
      FrameTiming slow() => FrameTiming(
        vsyncStart: 0,
        buildStart: 0,
        buildFinish: 12000,
        rasterStart: 12000,
        rasterFinish: 26000,
        rasterFinishWallTime: 26000,
      );
      m.onTimings(List<FrameTiming>.generate(8, (_) => slow()));
      expect(m.overBudget, isTrue);
      m.dispose();
    });

    testWidgets('over budget: blur closes, layer stays, opaque', (t) async {
      final mon = _FakeMonitor();
      final b = GlassLayerBudget(monitor: mon);
      addTearDown(b.dispose);
      await t.pumpWidget(_host(_stack([_layer(b, label: 'a')])));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.byType(BackdropFilter), findsOneWidget);
      mon.trip();
      await t.pump();
      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.text('a'), findsOneWidget);
      expect(b.blurAdmittedCount, 0);
      expect(b.openCount, 1);
    });
  });

  group('review fixes', () {
    testWidgets('playing true -> false: mounted layer comes back', (t) async {
      final b = GlassLayerBudget();
      addTearDown(b.dispose);
      await t.pumpWidget(_host(_stack([_layer(b, label: 'a')])));
      await t.pump(const Duration(milliseconds: 300));
      b.playing = true;
      await t.pump();
      expect(find.text('a'), findsNothing);
      b.playing = false;
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('a'), findsOneWidget);
      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(_blurs('a'), isTrue);
      expect(b.openCount, 1);
    });

    testWidgets('rejected third layer is admitted when a slot frees', (
      t,
    ) async {
      final b = GlassLayerBudget();
      addTearDown(b.dispose);
      Widget tree(bool second) => _host(
        _stack([
          _layer(b, label: 'one'),
          if (second) _layer(b, label: 'two'),
          _layer(b, label: 'three'),
        ]),
      );
      await t.pumpWidget(tree(true));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('three'), findsNothing);
      await t.pumpWidget(tree(false));
      await t.pump(); // microtask notify
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('one'), findsOneWidget);
      expect(find.text('two'), findsNothing);
      expect(find.text('three'), findsOneWidget);
      expect(_blurs('one'), isTrue);
      expect(_blurs('three'), isFalse);
      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(b.openCount, 2);
    });

    testWidgets('unmount returns the slot', (t) async {
      final b = GlassLayerBudget();
      addTearDown(b.dispose);
      await t.pumpWidget(_host(_stack([_layer(b)])));
      expect(b.openCount, 1);
      await t.pumpWidget(_host(_stack(const <Widget>[])));
      expect(b.openCount, 0);
    });

    testWidgets('budget swap closes the slot on the old budget', (t) async {
      final a = GlassLayerBudget(), c = GlassLayerBudget();
      addTearDown(a.dispose);
      addTearDown(c.dispose);
      await t.pumpWidget(_host(_stack([_layer(a)])));
      expect(a.openCount, 1);
      await t.pumpWidget(_host(_stack([_layer(c)])));
      await t.pump(const Duration(milliseconds: 300));
      expect(a.openCount, 0);
      expect(c.openCount, 1);
    });

    testWidgets('semantics: container with caller label; none when closed', (
      t,
    ) async {
      final h = t.ensureSemantics();
      final b = GlassLayerBudget();
      addTearDown(b.dispose);
      Widget tree({bool reduce = false}) => _host(
        _stack([
          GlassLayer(
            budget: b,
            reduceTransparency: reduce,
            semanticLabel: 'Panel',
            child: const SizedBox(width: 10, height: 10),
          ),
        ]),
      );
      await t.pumpWidget(tree());
      await t.pump(const Duration(milliseconds: 300));
      expect(find.bySemanticsLabel('Panel'), findsOneWidget);
      final node = t.getSemantics(find.bySemanticsLabel('Panel'));
      expect(node.label, 'Panel');
      expect(node.rect.height, lessThanOrEqualTo(800 * 0.6 + 0.01));
      expect(node.rect.height, greaterThan(0));
      expect(node.rect.width, 400);
      await t.pumpWidget(tree(reduce: true));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.bySemanticsLabel('Panel'), findsOneWidget);
      b.playing = true;
      await t.pump();
      expect(find.bySemanticsLabel('Panel'), findsNothing);
      h.dispose();
    });

    testWidgets('over budget: layer is fully opaque, no blur', (t) async {
      final mon = _FakeMonitor();
      final b = GlassLayerBudget(monitor: mon);
      addTearDown(b.dispose);
      await t.pumpWidget(_host(_stack([_layer(b)])));
      await t.pump(const Duration(milliseconds: 300));
      mon.trip();
      await t.pump();
      final deco = t.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(GlassLayer),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect((deco.decoration as BoxDecoration).color!.a, 1);
      expect(find.byType(BackdropFilter), findsNothing);
    });

    test('monitor ignores the warm-up frames', () {
      final m = TimingsFrameBudgetMonitor(attach: false);
      for (var i = 0; i < GlassLayerConfig.warmupFrames + 7; i++) {
        m.recordFrame(const Duration(milliseconds: 40));
      }
      expect(GlassLayerConfig.warmupFrames, 30);
      expect(m.overBudget, isFalse);
      m.recordFrame(const Duration(milliseconds: 40));
      expect(m.overBudget, isTrue);
      m.recordFrame(const Duration(milliseconds: 1));
      expect(m.overBudget, isTrue, reason: 'latched for the lifetime');
      m.dispose();
    });

    test('monitor registers and unregisters the timings callback', () {
      final added = <TimingsCallback>[], removed = <TimingsCallback>[];
      final m = TimingsFrameBudgetMonitor(
        register: added.add,
        unregister: removed.add,
      );
      expect(added, hasLength(1));
      expect(removed, isEmpty);
      m.dispose();
      expect(removed, <TimingsCallback>[added.single]);
    });

    testWidgets('default monitor attaches to the real binding', (t) async {
      final m = TimingsFrameBudgetMonitor();
      expect(m.overBudget, isFalse);
      m.dispose();
    });
  });

  group('olcut8 no existing screen uses GlassLayer', () {
    test('only its own file references glass_layer', () {
      final hits = <String>[];
      for (final f in Directory('lib').listSync(recursive: true)) {
        if (f is! File || !f.path.endsWith('.dart')) continue;
        if (f.path.endsWith('lib/app/design/glass_layer.dart')) continue;
        final s = f.readAsStringSync();
        if (s.contains('design/glass_layer.dart') ||
            s.contains("'glass_layer.dart'") ||
            RegExp(r'\bGlassLayer\b').hasMatch(s)) {
          hits.add(f.path);
        }
      }
      expect(hits, isEmpty);
    });
  });
}
