import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/app_locale.dart';
import 'package:ostinato/app/content.dart';
import 'package:ostinato/app/cue_text.dart';
import 'package:ostinato/app/design/app_scope.dart';
import 'package:ostinato/app/onboarding_store.dart';
import 'package:ostinato/app/screens/instrument_screen.dart';
import 'package:ostinato/app/screens/onboarding_screen.dart';

void main() {
  late ContentRepository repo;
  late CueTextResolver cues;
  setUpAll(() async {
    repo = await ContentRepository.load();
    cues = await CueTextResolver.load();
  });
  for (final language in ['en', 'tr']) {
    Widget host(Widget child) => ContentRepositoryScope(
      repo: repo,
      cueText: cues,
      child: MaterialApp(
        locale: Locale(language),
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationsDelegates,
        home: child,
      ),
    );
    testWidgets(
      'scope labels reference previews, not user measurements ($language)',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(375, 812));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          host(
            OnboardingScreen(
              repo: repo,
              store: InMemoryOnboardingStore(),
              onFinished: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('onboarding-primary')));
        await tester.pumpAndSettle();
        final demo = find.descendant(
          of: find.byKey(const Key('onboarding-fact-demo')),
          matching: find.byType(Text),
        );
        final copy = tester
            .widgetList<Text>(demo)
            .map((w) => w.data ?? '')
            .join(' ');
        expect(
          copy,
          contains(
            language == 'tr'
                ? 'kaydedilmiş eğitmen referanslarına'
                : 'recorded teacher references',
          ),
        );
        expect(
          copy,
          contains(
            language == 'tr'
                ? 'Bu sürüm duruşunuzu ölçmez veya puanlamaz'
                : 'This release does not measure or grade your posture',
          ),
        );
        expect(copy, isNot(contains('are measured but never graded')));
        expect(copy, isNot(contains('ders ölçülür ama puanlanmaz')));
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      'guitar footer keeps historical evidence and release closure ($language)',
      (tester) async {
        final guitar = repo.disciplines.singleWhere((d) => d.id == 'guitar');
        await tester.pumpWidget(
          host(InstrumentScreenRoute(discipline: guitar)),
        );
        await tester.pumpAndSettle();
        final claim = find.textContaining(
          language == 'tr'
              ? 'Bunlar kaydedilmiş eğitmen referanslarının tarihsel bulgularıdır'
              : 'These are historical findings from recorded teacher references',
        );
        expect(claim, findsOneWidget);
        await tester.ensureVisible(claim);
        await tester.pumpAndSettle();
        final copy = tester.widget<Text>(claim).data!;
        expect(
          copy,
          contains(language == 'tr' ? '39–105°' : '39 to 105 degrees'),
        );
        expect(
          copy,
          contains(language == 'tr' ? 'sağ ve sol kol' : 'side identity'),
        );
        expect(
          copy,
          contains(
            language == 'tr'
                ? 'Bu sürüm duruşunuzu ölçmez veya puanlamaz'
                : 'This release does not measure or grade your posture',
          ),
        );
        expect(copy, isNot(contains('trunk angle we do grade')));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
