import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/content.dart';
import 'package:ostinato/app/cue_text.dart';
import 'package:ostinato/app/posture_screen.dart';
import 'package:ostinato_posture/ostinato_posture.dart';

/// O-032 TEŞHİS TESTİ — kalan tek aday: navigasyon/route sarmalayıcısı.
///
/// `timer_path_test.dart` (tur 55) `PostureScreen`i DOĞRUDAN `MaterialApp.home`
/// yaptı ve gerçek zamanlayıcıyla (tam senaryo dahil) işaret DOĞDU —
/// zamanlayıcı/akış yolu ve demo senaryosunun kendisi temiz çıktı. Uygulamanın
/// GERÇEK giriş yolu ise `Navigator.of(context).push(MaterialPageRoute(
/// builder: ...))` (`lib/main.dart` `_LibraryScreen.onTap`); testlerin
/// UĞRAMADIĞI TEK fark bu. Bu test AYNI tam senaryoyu, AYNI gerçek
/// zamanlayıcıyla, ama GERÇEK bir route push'unun ARKASINDA çalıştırır —
/// kontrollü tek-değişken karşılaştırması.
///
/// Düzeltme değil, ÖLÇÜM: kırmızı yanarsa arıza route yolunda, yeşil geçerse
/// route hipotezi de yanlış çıkar — sıradaki adım `flutter run` canlı log.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Varlıklar setUpAll'da: rootBundle.loadString'i test GÖVDESİNDE çağırmak
  // ikinci testte asar (M-F-278 aile-notu — bu tuzağa iki kez düşüldü).
  late ContentRepository repo;
  late CueTextResolver cueText;
  setUpAll(() async {
    repo = await ContentRepository.load();
    cueText = await CueTextResolver.load();
  });

  testWidgets(
      'GERÇEK Navigator.push arkasında: tam senaryo + gerçek zamanlayıcı',
      (WidgetTester t) async {
    // lib/main.dart'taki _demoScript ile BİREBİR aynı (timer_path_test'in
    // ikinci testiyle de aynı — tek değişken route sarmalayıcısı).
    final FakePoseSource src = FakePoseSource(<double?>[
      2.0, 2.4, 3.1, 2.8, 3.4, 2.2, 2.9, 3.3, 2.5, 3.0,
      null, null, null,
      16.0, 18.0, 19.5, 21.0, 22.0, 20.5, 19.0, 20.0, 21.5, 22.5,
      21.0, 19.5, 18.5, 20.0, 21.0,
      6.0, 4.5, 3.2, 2.6,
    ], stepUs: 180000);

    final Discipline d =
        repo.disciplines.firstWhere((Discipline x) => x.id == 'guitar');

    // Uygulamanın GERÇEK şekli: bir üst ekrandan Navigator.push ile açılır.
    // `main.dart`daki _LibraryScreen.onTap'in birebir aynısı.
    await t.pumpWidget(MaterialApp(
      home: Builder(
        builder: (BuildContext context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              key: const Key('open-lesson'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => PostureScreen(
                    discipline: d,
                    contract: repo.contractFor('guitar'),
                    cueText: cueText,
                    source: src,
                    sourceLabel: 'TEST — route arkasında',
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));

    await t.tap(find.byKey(const Key('open-lesson')));
    await t.pump(); // push'u başlat
    await t.pump(const Duration(milliseconds: 300)); // geçiş animasyonu

    expect(find.byType(PostureScreen), findsOneWidget,
        reason: 'push sonrası PostureScreen ekranda değil — kurulum hatası');

    // timer_path_test.dart'ın ikinci testiyle BİREBİR aynı döngü: 16 kare.
    for (int i = 0; i < 16; i++) {
      await t.pump(const Duration(milliseconds: 180));
    }

    expect(find.byKey(const Key('observation-cue')), findsOneWidget,
        reason: 'O-032 REPRODÜKSİYONU: gerçek route arkasında işaret DOĞMADI '
            '— arıza navigasyon/route yolunda (routeless emsali yeşildi)');

    await src.stop();
    await src.dispose();
  });
}
