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

/// Loads every packaged catalog for the real root bundle once, with real IO,
/// before a file's widget tests run. Without it the first tests in a file
/// pumped against a cold delegate and only passed after an earlier test had
/// warmed the shared cache (order-dependent). A catalog that falls back to
/// empty source copy fails here instead of being masked.
Future<void> prepareRootTranslations() async {
  for (final tag in supportedLanguageTags) {
    final translations = await const AppTranslationsDelegate().load(
      localeForLanguageTag(tag),
    );
    if (translations.messages.isEmpty) {
      throw StateError('Packaged catalog $tag did not load');
    }
  }
}
