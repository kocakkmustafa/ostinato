// Store screenshots 2026-11-02: the result screen showed "%100" and
// "Accuracy ≥ %80" in English; the sign was hard-coded in Turkish order.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/app_locale.dart';

import 'support/localized_widget_ready.dart';

void main() {
  setUpAll(prepareRootTranslations);

  for (final (tag, expected) in [
    ('en', '80%'),
    ('tr', '%80'),
    ('de', '80\u00a0%'),
    ('fr', '80\u00a0%'),
  ]) {
    testWidgets('appPercent follows the app locale ($tag)', (tester) async {
      late String text;
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(tag),
          supportedLocales: appSupportedLocales,
          localizationsDelegates: appLocalizationsDelegates,
          home: Builder(
            builder: (context) {
              text = appPercent(context, 0.8);
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(text, expected);
    });
  }

  testWidgets('every catalog keeps the percent out of the copy', (
    tester,
  ) async {
    for (final locale in appSupportedLocales) {
      late String text;
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          supportedLocales: appSupportedLocales,
          localizationsDelegates: appLocalizationsDelegates,
          home: Builder(
            builder: (context) {
              text = localized(
                context,
                'Accuracy ≥ {v0}',
                'Doğruluk ≥ {v0}',
                values: {'v0': appPercent(context, 0.8)},
              );
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final signs = RegExp('[%٪]').allMatches(text).length;
      expect(signs, 1, reason: '$locale: "$text"');
    }
  });
}
