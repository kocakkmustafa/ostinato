import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ostinato/app/content.dart';
import 'package:ostinato/app/cue_text.dart';
import 'package:ostinato/app/design/app_scope.dart';
import 'package:ostinato/app/design/ostinato_theme.dart';
import 'package:ostinato/app/screens/review_screen.dart';

/// Review'ın "neyi ölçemedik" bölümü — O-044.
///
/// İki iddiayı kilitler:
///  1. Başlıktaki SAYI listeden TÜRER. Elle yazılıydı ("Three things") ve tam
///     altındaki liste de elle yazılıydı — dördüncü kalem eklenince başlık
///     sessizce bayatlardı. O-029'un ("vitrin korumasızdı") canlı-yüzey hâli.
///  2. Dördüncü kalem ÇALGIYA ÖZEL ve VERİDEN gelir. Üç çalgı üç FARKLI cümle
///     görmeli — aynı cümleyi görüyorlarsa türetim kopmuş, ekran genel bir
///     metne düşmüş demektir.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late ContentRepository repo;
  late CueTextResolver cueText;
  setUpAll(() async {
    repo = await ContentRepository.load();
    cueText = await CueTextResolver.load();
  });

  setUp(() {
    final TestWidgetsFlutterBinding b =
        TestWidgetsFlutterBinding.ensureInitialized();
    b.platformDispatcher.views.first.physicalSize = const Size(375, 812);
    b.platformDispatcher.views.first.devicePixelRatio = 1.0;
    addTearDown(b.platformDispatcher.views.first.resetPhysicalSize);
    addTearDown(b.platformDispatcher.views.first.resetDevicePixelRatio);
  });

  Future<List<String>> pumpReview(WidgetTester t, String id) async {
    final Discipline d =
        repo.disciplines.firstWhere((Discipline x) => x.id == id);
    await t.pumpWidget(ContentRepositoryScope(
      repo: repo,
      cueText: cueText,
      child: MaterialApp(
        home: ReviewScreenRoute(
          discipline: d,
          lesson: d.lessons.first,
          hue: InstrumentHues.of(id),
          summary: const SessionSummary(
              elapsedSeconds: 30,
              sampleCount: 100,
              outCount: 10,
              history: <double>[3.0, 3.1, 2.9]),
        ),
      ),
    ));
    await t.pump();
    await t.pump();
    expect(t.takeException(), isNull, reason: '$id Review taştı');
    return t
        .widgetList<Text>(find.byType(Text))
        .map((Text w) => w.data ?? '')
        .toList();
  }

  String headline(WidgetTester t) =>
      t.widget<Text>(find.byKey(const Key('review-gap-headline'))).data!;

  for (final String id in <String>['guitar', 'voice', 'piano']) {
    testWidgets('$id — başlıktaki sayı GERÇEK kalem sayısıyla aynı',
        (WidgetTester t) async {
      final List<String> texts = await pumpReview(t, id);
      final Discipline d =
          repo.disciplines.firstWhere((Discipline x) => x.id == id);

      // 3 sabit kalem + çalgıya-özel kalem (varsa) — ekranın kendi kuralı.
      final int expected = 3 + (d.instrumentSpecificGap.isEmpty ? 0 : 1);
      const Map<int, String> words = <int, String>{3: 'Three', 4: 'Four'};
      expect(headline(t), '${words[expected]} things, by name.',
          reason: 'başlık listeden TÜREMİYOR — sayı elle yazılmış olabilir');

      // Sayının SAYDIĞI şey gerçekten ekranda mı? Başlık türerken liste boş
      // kalsaydı ikisi de "tutarlı" görünürdü.
      expect(texts, contains(d.instrumentSpecificGap));
    });
  }

  testWidgets('dördüncü kalem üç çalgıda ÜÇ FARKLI cümle', (WidgetTester t) async {
    final Set<String> seen = <String>{};
    for (final String id in <String>['guitar', 'voice', 'piano']) {
      await pumpReview(t, id);
      seen.add(repo.disciplines
          .firstWhere((Discipline x) => x.id == id)
          .instrumentSpecificGap);
    }
    expect(seen.length, 3,
        reason: 'çalgıya-özel kalem çalgıya göre DEĞİŞMİYOR — türetim kopmuş '
            've ekran genel bir metne düşmüş olabilir');
    expect(seen.any((String s) => s.isEmpty), isFalse);
  });

  test('her canlı disiplin çalgıya-özel boşluğunu ve KAYNAĞINI taşır', () {
    for (final Discipline d
        in repo.disciplines.where((Discipline x) => x.status == 'live')) {
      expect(d.instrumentSpecificGap, isNotEmpty,
          reason: '${d.id}: Review 4. kalemi boş — ekran sessizce 3 kaleme '
              'düşer ve başlık da onunla birlikte küçülür, yani kayıp '
              'GÖRÜNMEZ olur');
      expect(d.instrumentSpecificGap.length, greaterThan(60),
          reason: '${d.id}: yer-tutucu görünüyor (kural 10 ile aynı ruh)');
    }
  });
}
