import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

  // ⚠️ Bu liste ELLE yazılı ve öyle KALMAK ZORUNDA: `testWidgets` KAYIT
  // anında çağrılır, `repo` ise `setUpAll`da yani ÇALIŞTIRMA anında dolar —
  // disiplin döngüsü burada kurulamaz (`real_content_overflow_test.dart`
  // aynı sınırı aynı gerekçeyle taşıyor).
  // Dördüncü çalgı eklenirse bu döngü onu KAPSAMAZ ve test KIRMIZI DA
  // DÖNMEZ — sessizce eksik kalır. O yüzden aşağıdaki "HER canlı çalgıda
  // FARKLI" testi TEST GÖVDESİNDE (repo hazırken) canlı listeyi kendi
  // türetiyor: kapsamın tamamını o kolluyor, bu döngü yalnız başlık-sayı
  // iddiasını üç bilinen çalgıda derinlemesine sınıyor.
  for (final String id in const <String>['guitar', 'voice', 'piano']) {
    testWidgets('$id — başlıktaki sayı GERÇEK kalem sayısıyla aynı',
        (WidgetTester t) async {
      final List<String> texts = await pumpReview(t, id);
      final Discipline d =
          repo.disciplines.firstWhere((Discipline x) => x.id == id);

      // 3 sabit kalem + çalgıya-özel kalem (varsa) — ekranın kendi kuralı.
      final int expected = 3 + (d.instrumentSpecificGap.isEmpty ? 0 : 1);
      // Ekranın kendi yazıyla-sayı eşlemesinin AYNADAKİ hâli — ekran ondan
      // uzun bir listede rakama düşüyor, test de öyle düşer (yoksa liste
      // büyüdüğünde test, ürün doğru davranırken null'a çarpar).
      const Map<int, String> words = <int, String>{
        1: 'One', 2: 'Two', 3: 'Three', 4: 'Four', 5: 'Five', 6: 'Six',
      };
      expect(headline(t), '${words[expected] ?? expected} things, by name.',
          reason: 'başlık listeden TÜREMİYOR — sayı elle yazılmış olabilir');

      // Sayının SAYDIĞI şey gerçekten ekranda mı? Başlık türerken liste boş
      // kalsaydı ikisi de "tutarlı" görünürdü.
      expect(texts, contains(d.instrumentSpecificGap));
    });
  }

  testWidgets('çalgıya-özel kalem HER canlı çalgıda FARKLI', (WidgetTester t) async {
    // ⚠️ SAYI DEĞİL KURAL ölçülüyor (JabLab dersi, koordinatör 2026-08-07:
    // "fazla geniş bir test, ürün doğru genişlerken kırmızıya döner").
    // Önceki hâli `expect(seen.length, 3)` idi ve çalgı listesi de elle
    // yazılıydı — DÖRDÜNCÜ çalgı eklendiği gün bu test, ürün DOĞRU
    // genişlerken kırmızıya dönecekti. Kural şu: kaç canlı çalgı varsa o
    // kadar FARKLI cümle olmalı; sayı listeden türer.
    final List<Discipline> live =
        repo.disciplines.where((Discipline d) => d.status == 'live').toList();
    final Set<String> seen = <String>{};
    for (final Discipline d in live) {
      await pumpReview(t, d.id);
      seen.add(d.instrumentSpecificGap);
    }
    expect(seen.length, live.length,
        reason: 'çalgıya-özel kalem çalgıya göre DEĞİŞMİYOR — türetim kopmuş '
            've ekran genel bir metne düşmüş olabilir');
    expect(seen.any((String s) => s.isEmpty), isFalse);
    expect(live.length, greaterThan(1),
        reason: 'tek çalgıyla "her çalgıda farklı" iddiası vakum-doğru olur');
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
