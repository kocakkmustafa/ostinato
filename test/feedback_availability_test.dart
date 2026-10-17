import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/app_locale.dart';
import 'package:ostinato/app/screens/feedback_availability.dart';

void main() {
  for (final language in ['en', 'tr']) {
    for (final instrument in ['guitar', 'piano', 'ukulele', 'bass', 'voice']) {
      testWidgets(
        '$instrument capability is explicit at 320px / 200% ($language)',
        (t) async {
          await t.binding.setSurfaceSize(const Size(320, 640));
          addTearDown(() => t.binding.setSurfaceSize(null));
          await t.pumpWidget(
            MaterialApp(
              locale: Locale(language),
              supportedLocales: appSupportedLocales,
              localizationsDelegates: appLocalizationsDelegates,
              home: Scaffold(
                body: MediaQuery(
                  data: const MediaQueryData(
                    size: Size(320, 640),
                    textScaler: TextScaler.linear(2),
                  ),
                  child: SingleChildScrollView(
                    child: FeedbackAvailability(instrumentId: instrument),
                  ),
                ),
              ),
            ),
          );
          await t.pumpAndSettle();
          final text = t
              .widget<Text>(
                find.byKey(Key('feedback-availability-$instrument')),
              )
              .data!;
          expect(
            text,
            contains(
              instrument == 'guitar'
                  ? (language == 'tr'
                        ? 'yaklaşık tek nota'
                        : 'approximate single-note')
                  : (language == 'tr' ? 'desteklenmiyor' : 'not supported'),
            ),
          );
          expect(t.takeException(), isNull);
        },
      );
    }
    testWidgets('failed manifest keeps feedback closed ($language)', (t) async {
      await t.pumpWidget(
        MaterialApp(
          locale: Locale(language),
          supportedLocales: appSupportedLocales,
          localizationsDelegates: appLocalizationsDelegates,
          home: Scaffold(
            body: FeedbackAvailability(
              instrumentId: 'guitar',
              manifest: () async => throw const FormatException('bad manifest'),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(
        find.textContaining(
          language == 'tr'
              ? 'geri bildirim kullanılamıyor'
              : 'feedback is unavailable',
        ),
        findsOneWidget,
      );
      expect(t.takeException(), isNull);
    });
  }
}
