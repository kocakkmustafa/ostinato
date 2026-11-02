// Store review 2026-11-02: small-caps headings used toUpperCase, which is
// locale-independent: Turkish showed "HOŞ GELDIN", "DIL", "MIKROFON".
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/app_locale.dart';
import 'package:ostinato/app/design/ostinato_theme.dart';

import 'support/localized_widget_ready.dart';

void main() {
  setUpAll(prepareRootTranslations);

  test('Turkish and Azerbaijani keep the dotted and dotless i apart', () {
    for (final tag in ['tr', 'az']) {
      final locale = Locale(tag);
      expect(localeUpperCase(locale, 'Hoş geldin'), 'HOŞ GELDİN');
      expect(localeUpperCase(locale, 'Dil'), 'DİL');
      expect(localeUpperCase(locale, 'Mikrofon'), 'MİKROFON');
      expect(localeUpperCase(locale, 'Kayıtlı ılık'), 'KAYITLI ILIK');
      expect(localeUpperCase(locale, 'İLERLEMEN'), 'İLERLEMEN');
    }
  });

  test('other locales use the default mapping', () {
    expect(localeUpperCase(const Locale('en'), 'Microphone'), 'MICROPHONE');
    expect(localeUpperCase(const Locale('de'), 'Übung'), 'ÜBUNG');
    expect(localeUpperCase(const Locale('fr'), 'Réglages'), 'RÉGLAGES');
  });

  for (final (tag, expected) in [('tr', 'MİKROFON'), ('en', 'MIKROFON')]) {
    testWidgets('kicker uppercases for the app locale ($tag)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(tag),
          supportedLocales: appSupportedLocales,
          localizationsDelegates: appLocalizationsDelegates,
          home: Scaffold(body: kicker('Mikrofon')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(expected), findsOneWidget);
    });
  }
}
