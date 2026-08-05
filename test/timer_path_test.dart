import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/content.dart';
import 'package:ostinato/app/cue_text.dart';
import 'package:ostinato/app/posture_screen.dart';
import 'package:ostinato_posture/ostinato_posture.dart';

/// O-032 TEŞHİS TESTİ — uygulamanın GERÇEK yolu.
///
/// Mevcut widget testleri `pushOne()` ile SENKRON kare itiyor. Çalışan
/// uygulama ise `Timer.periodic` kullanıyor ve kareler akıştan ASENKRON
/// geliyor. İşaret testlerde görünüp uygulamada görünmüyorsa, fark tam da
/// bu yolda olmalı — burada `t.pump(Duration(...))` ile zamanlayıcıyı
/// GERÇEKTEN ilerletiyoruz.
///
/// Bu test bir DÜZELTME değil, bir ÖLÇÜMDÜR: kırmızı yanarsa arıza
/// zamanlayıcı yolunda; yeşil geçerse arıza başka yerde (ve o zaman
/// şüphe sınıfım yanlıştı).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Varlıklar setUpAll'da yüklenir. Test GÖVDESİNDE `rootBundle.loadString`
  // çağırmak ikinci testte asıyor — bu tuzağa widget_test.dart'ta bir kez
  // düşülüp düzeltilmişti, yeni dosyada tekrarlandı. Kayda geçsin.
  late ContentRepository repo;
  late CueTextResolver cueText;
  setUpAll(() async {
    repo = await ContentRepository.load();
    cueText = await CueTextResolver.load();
  });

  testWidgets('GERÇEK zamanlayıcıyla: sürdürülen sapmada işaret GÖRÜNÜR mü?',
      (WidgetTester t) async {
    // Uygulamadaki demo senaryosunun aralık-dışı kısmıyla aynı şekil.
    final FakePoseSource src = FakePoseSource(
      <double?>[2.0, 2.5, 16.0, 18.0, 19.5, 21.0, 22.0, 20.5],
      stepUs: 180000,
    );

    await t.pumpWidget(MaterialApp(
      home: PostureScreen(
        discipline: repo.disciplines.firstWhere((Discipline d) => d.id == 'guitar'),
        contract: repo.contractFor('guitar'),
        cueText: cueText,
        source: src,
        sourceLabel: 'TEST — gerçek zamanlayıcı',
      ),
    ));

    // Zamanlayıcıyı 8 kare ilerlet (180 ms × 8 = 1,44 sn).
    for (int i = 0; i < 8; i++) {
      await t.pump(const Duration(milliseconds: 180));
    }

    expect(find.byKey(const Key('state-measuring')), findsOneWidget,
        reason: 'zamanlayıcı yolunda ölçüm ekranına hiç gelinmedi');
    expect(find.byKey(const Key('observation-cue')), findsOneWidget,
        reason: 'O-032 REPRODÜKSİYONU: gerçek zamanlayıcıyla işaret DOĞMADI '
            '— arıza zamanlayıcı/akış yolunda');

    await src.stop();
    await src.dispose();
  });

  testWidgets('UYGULAMANIN TAM senaryosu (null kareler dahil), gerçek zamanlayıcı',
      (WidgetTester t) async {
    // lib/main.dart'taki _demoScript ile BİREBİR aynı.
    final FakePoseSource src = FakePoseSource(<double?>[
      2.0, 2.4, 3.1, 2.8, 3.4, 2.2, 2.9, 3.3, 2.5, 3.0,
      null, null, null,
      16.0, 18.0, 19.5, 21.0, 22.0, 20.5, 19.0, 20.0, 21.5, 22.5,
      21.0, 19.5, 18.5, 20.0, 21.0,
      6.0, 4.5, 3.2, 2.6,
    ], stepUs: 180000);

    await t.pumpWidget(MaterialApp(
      home: PostureScreen(
        discipline: repo.disciplines.firstWhere((Discipline d) => d.id == 'guitar'),
        contract: repo.contractFor('guitar'),
        cueText: cueText,
        source: src,
        sourceLabel: 'TEST — tam senaryo',
      ),
    ));

    // 16 kare: 13 in-band/null + aralık-dışının ilk 3'ü → işaret DOĞMALI.
    for (int i = 0; i < 16; i++) {
      await t.pump(const Duration(milliseconds: 180));
    }
    expect(find.byKey(const Key('observation-cue')), findsOneWidget,
        reason: 'TAM senaryoda işaret doğmadı — fark null kareler tarafında');

    await src.stop();
    await src.dispose();
  });
}
