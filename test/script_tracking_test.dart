// Store review 2026-11-02 (screens 80, 83, 84): letter spacing split Hindi
// clusters apart ("कै मरा", "ट्यू नि ंग") and would break Arabic joins.
// Scripts where tracking breaks shaping get none; others keep the design.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/app_locale.dart';
import 'package:ostinato/app/design/ostinato_theme.dart';

import 'support/localized_widget_ready.dart';

void main() {
  setUpAll(prepareRootTranslations);

  test('which locales lose tracking', () {
    for (final tag in ['hi', 'ar', 'bn', 'ta', 'th', 'fa', 'ur']) {
      expect(trackingBreaksShaping(Locale(tag)), isTrue, reason: tag);
    }
    for (final tag in ['en', 'tr', 'de', 'ja', 'ko', 'zh', 'pl', 'fr']) {
      expect(trackingBreaksShaping(Locale(tag)), isFalse, reason: tag);
    }
    expect(
      trackingBreaksShaping(
        const Locale.fromSubtags(languageCode: 'sd', scriptCode: 'Deva'),
      ),
      isTrue,
    );
  });

  for (final (tag, untracked) in [
    ('hi', true),
    ('ar', true),
    ('de', false),
    ('ja', false),
  ]) {
    testWidgets('app shell tracking in $tag', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(tag),
          supportedLocales: appSupportedLocales,
          localizationsDelegates: appLocalizationsDelegates,
          builder: ostinatoAppBuilder,
          home: Builder(
            builder: (context) => Scaffold(
              body: Column(
                children: [
                  Text('mono', style: monoText()),
                  Text('wide', style: hankenText(letterSpacing: .07)),
                  Text('theme', style: Theme.of(context).textTheme.labelLarge),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      double? spacing(String text) =>
          tester.widget<Text>(find.text(text)).style!.letterSpacing;
      if (untracked) {
        expect(spacing('mono'), 0);
        expect(spacing('wide'), 0);
        expect(spacing('theme'), 0);
      } else {
        expect(spacing('mono'), 1.4);
        expect(spacing('wide'), .07);
      }
    });
  }
}
