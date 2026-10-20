import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/app_theme.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      testWidgets(
        'reduced motion retains a stationary route for $platform $brightness',
        (tester) async {
          tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
              const FakeAccessibilityFeatures(disableAnimations: true);
          addTearDown(
            tester
                .binding
                .platformDispatcher
                .clearAccessibilityFeaturesTestValue,
          );
          final key = GlobalKey<NavigatorState>();
          await tester.pumpWidget(
            MaterialApp(
              navigatorKey: key,
              theme: OstinatoThemes.forBrightness(
                brightness,
              ).copyWith(platform: platform),
              themeAnimationDuration: Duration.zero,
              home: const Scaffold(body: Text('root')),
            ),
          );
          final navigator = key.currentState!;
          final route = MaterialPageRoute<void>(
            builder: (_) =>
                const Scaffold(key: Key('motion-target'), body: Text('target')),
          );
          unawaited(navigator.push(route));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 1));
          final target = find.byKey(const Key('motion-target'));
          expect(target, findsOneWidget);
          final originalElement = tester.element(target);
          final originalBounds = tester.getRect(target);
          expect(originalBounds.topLeft, Offset.zero);
          expect(
            originalBounds.size,
            tester.view.physicalSize / tester.view.devicePixelRatio,
          );
          expect(MediaQuery.disableAnimationsOf(originalElement), isTrue);
          await tester.pump(const Duration(milliseconds: 150));
          expect(tester.getRect(target), originalBounds);
          expect(tester.element(target), same(originalElement));
          expect(ModalRoute.of(originalElement), same(route));
          expect(key.currentState, same(navigator));
          await tester.pumpWidget(const SizedBox.shrink());
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
