import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/app_translation_catalog.dart';

/// Waits on real asset IO without advancing the fake three-second asset
/// timeout. Each runAsync callback yields one real event turn, then pump
/// drains fake-zone continuations and paints the next frame. A one-millisecond
/// real IO turn is bounded by 200 iterations. No error-handler override,
/// translation injection or source fallback is used.
Future<void> waitForLocalizedFixture(
  WidgetTester tester, {
  required String languageTag,
  required Finder anchor,
  required String reason,
}) async {
  bool ready() {
    if (anchor.evaluate().length != 1) return false;
    final context = tester.element(anchor);
    final translations = AppTranslations.maybeOf(context);
    return translations != null &&
        translations.messages.isNotEmpty &&
        canonicalLanguageTag(Localizations.localeOf(context)) == languageTag;
  }

  for (var turn = 0; turn < 200; turn++) {
    await tester.pump();
    if (ready()) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1)),
    );
  }
  expect(ready(), isTrue,
      reason: '$reason: no prepared localized frame after 200 real IO turns');
}
