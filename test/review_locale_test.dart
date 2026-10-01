import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/app_locale.dart';
import 'package:ostinato/app/catalog_copy_tr.dart';
import 'package:ostinato/app/content.dart';
import 'package:ostinato/app/design/ostinato_theme.dart';
import 'package:ostinato/app/screens/review_copy_tr.dart';
import 'package:ostinato/app/screens/review_screen.dart';
import 'package:ostinato/app/session_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ContentRepository repo;
  setUpAll(() async => repo = await ContentRepository.load());

  Future<void> show(
    WidgetTester tester,
    String instrument,
    SessionSummary summary, {
    Future<PersistedSession?>? previousSession,
  }) async {
    tester.view.physicalSize = const Size(375, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final Discipline d = repo.disciplines.firstWhere(
      (Discipline item) => item.id == instrument,
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('tr'),
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationsDelegates,
        home: ReviewScreenRoute(
          discipline: d,
          lesson: d.lessons.first,
          hue: InstrumentHues.of(instrument),
          summary: summary,
          previousSession: previousSession,
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  }

  testWidgets('measured summary names readable samples, not measured seconds', (
    WidgetTester tester,
  ) async {
    await show(
      tester,
      'guitar',
      const SessionSummary(
        elapsedSeconds: 30,
        sampleCount: 100,
        outCount: 10,
        history: <double>[3.0, 3.1, 2.9],
      ),
    );
    final String body = tester
        .widget<Text>(find.byKey(const Key('review-measured-body')))
        .data!;
    expect(body, contains('okunabilir örneklerin %90 kadarında'));
    expect(body, contains('birleşik puan yoktur'));
    expect(body, isNot(contains('saniyenin %90')));
    expect(
      find.textContaining('30 SN GEÇTİ · 100 OKUNABİLİR ÖRNEK'),
      findsOneWidget,
    );
    expect(find.text('Ölçümlerin çoğu bant içinde.'), findsOneWidget);
    expect(find.text('Dört alan, tek tek.'), findsOneWidget);
    expect(
      find.textContaining('Gitarın sapındaki parmaklarınız'),
      findsOneWidget,
    );
  });

  testWidgets('zero readable samples retain absence, never a zero score', (
    WidgetTester tester,
  ) async {
    await show(
      tester,
      'voice',
      const SessionSummary(
        elapsedSeconds: 30,
        sampleCount: 0,
        outCount: 0,
        history: <double>[],
      ),
    );
    expect(find.text('Okunabilir ölçüm yok.'), findsOneWidget);
    expect(find.textContaining('30 SN GEÇTİ · ÖLÇÜM YOK'), findsOneWidget);
    expect(find.textContaining('bu sıfır puan değildir'), findsOneWidget);
    expect(
      find.textContaining('Perde ve ses uzatma değerlendirilmez'),
      findsOneWidget,
    );
  });

  testWidgets('all live instrument gaps have guarded, distinct Turkish copy', (
    WidgetTester tester,
  ) async {
    final Map<String, String> expected = <String, String>{
      'guitar': 'Gitarın sapındaki parmaklarınız',
      'voice': 'Perde ve ses uzatma değerlendirilmez',
      'piano': 'Ostinato’da canlı el biçimi ölçümü',
    };
    for (final MapEntry<String, String> item in expected.entries) {
      final Discipline d = repo.disciplines.firstWhere(
        (Discipline x) => x.id == item.key,
      );
      expect(
        hasCurrentTurkishCatalogCopy(
          '${item.key}.instrumentSpecificGap',
          d.instrumentSpecificGap,
        ),
        isTrue,
        reason: item.key,
      );
      await show(
        tester,
        item.key,
        const SessionSummary(
          elapsedSeconds: 30,
          sampleCount: 100,
          outCount: 10,
          history: <double>[3.0],
        ),
      );
      expect(find.textContaining(item.value), findsOneWidget);
      expect(find.text(d.instrumentSpecificGap), findsNothing);
    }
  });

  testWidgets('review and catalog source drift fall back to exact English', (
    WidgetTester tester,
  ) async {
    final Discipline piano = repo.disciplines.firstWhere(
      (Discipline d) => d.id == 'piano',
    );
    const String source = 'Nothing we could read.';
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('tr'),
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationsDelegates,
        home: Builder(
          builder: (BuildContext context) {
            return SingleChildScrollView(
              child: Column(
                children: <Widget>[
                  Text(ReviewCopyTr.text(context, 'verdict.none', source)),
                  Text(ReviewCopyTr.verdict(context, 'Improving.')),
                  Text(
                    ReviewCopyTr.text(
                      context,
                      'verdict.none',
                      '$source Changed.',
                    ),
                  ),
                  Text(ReviewCopyTr.text(context, 'other.id', source)),
                  Text(
                    catalogCopy(
                      context,
                      'piano.instrumentSpecificGap',
                      '${piano.instrumentSpecificGap} Changed.',
                    ),
                  ),
                  Text(
                    ReviewCopyTr.template(
                      context,
                      'last.none',
                      '{when} — revised source.',
                      const <String, String>{'when': 'Dün'},
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
    expect(find.text('Okunabilir ölçüm yok.'), findsOneWidget);
    expect(find.text('Son bölümde gövde eğimi azaldı.'), findsOneWidget);
    expect(find.text('$source Changed.'), findsOneWidget);
    expect(find.text(source), findsOneWidget);
    expect(
      find.text('${piano.instrumentSpecificGap} Changed.'),
      findsOneWidget,
    );
    expect(find.text('Dün — revised source.'), findsOneWidget);
  });

  testWidgets(
    'last-session recap distinguishes sample share from elapsed time',
    (WidgetTester tester) async {
      final PersistedSession previous = PersistedSession(
        schemaVersion: PersistedSession.currentSchemaVersion,
        disciplineId: 'piano',
        lessonId: 'piano.foundations.posture',
        completedAt: DateTime.now().subtract(const Duration(hours: 2)),
        elapsedSeconds: 40,
        sampleCount: 80,
        outCount: 20,
      );
      await show(
        tester,
        'piano',
        const SessionSummary(
          elapsedSeconds: 30,
          sampleCount: 100,
          outCount: 10,
          history: <double>[3.0],
        ),
        previousSession: Future<PersistedSession?>.value(previous),
      );
      await tester.pump();
      final String line = tester
          .widget<Text>(find.byKey(const Key('review-last-session-note')))
          .data!;
      expect(line, contains('okunabilir örneklerin %75 kadarı'));
      expect(line, contains('40 sn geçti'));
      expect(line, isNot(contains('40 saniyenin %75')));
    },
  );
}
