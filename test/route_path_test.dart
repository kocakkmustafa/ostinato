import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/content.dart';
import 'package:ostinato/app/cue_text.dart';
import 'package:ostinato/app/design/app_scope.dart';
import 'package:ostinato/app/design/ostinato_theme.dart';
import 'package:ostinato/app/screens/live_screen.dart';
import 'package:ostinato_posture/ostinato_posture.dart';

/// O-032 TEŞHİS TESTİ — navigasyon/route sarmalayıcısı (regresyon kalıcı
/// kanıtı). O-032 kapandı: route hipotezi ölçülüp YANLIŞ çıktı — gerçek
/// `Navigator.push(MaterialPageRoute(...))` arkasında ilk ateşleme sorunsuz.
/// Bu test o ölçümün donmuş hâli.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ContentRepository repo;
  late CueTextResolver cueText;
  late Discipline guitar;
  late Lesson postureLesson;
  setUpAll(() async {
    repo = await ContentRepository.load();
    cueText = await CueTextResolver.load();
    guitar = repo.disciplines.firstWhere((Discipline d) => d.id == 'guitar');
    postureLesson = guitar.lessons
        .firstWhere((Lesson l) => l.id == 'guitar.foundations.posture');
  });

  testWidgets(
      'GERÇEK Navigator.push arkasında: tam senaryo + gerçek zamanlayıcı',
      (WidgetTester t) async {
    final FakePoseSource src = FakePoseSource(<double?>[
      2.0, 2.4, 3.1, 2.8, 3.4, 2.2, 2.9, 3.3, 2.5, 3.0,
      null, null, null,
      16.0, 18.0, 19.5, 21.0, 22.0, 20.5, 19.0, 20.0, 21.5, 22.5,
      21.0, 19.5, 18.5, 20.0, 21.0,
      6.0, 4.5, 3.2, 2.6,
    ], stepUs: 180000);

    // Uygulamanın GERÇEK şekli: bir üst ekrandan Navigator.push ile açılır.
    // ContentRepositoryScope MaterialApp'i SARAR (main.dart ile AYNI kural)
    // — push edilen route Navigator'ın Overlay'inde KARDEŞ eklenir, Scope
    // Overlay'in İÇİNDE kalırsa pushed ekran onu HİÇ GÖREMEZ (bu test tam
    // bunu ölçmek için var).
    await t.pumpWidget(ContentRepositoryScope(
      repo: repo,
      cueText: cueText,
      child: MaterialApp(
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                key: const Key('open-lesson'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => LiveScreenRoute(
                      discipline: guitar,
                      lesson: postureLesson,
                      hue: InstrumentHues.guitar,
                      source: src,
                      skipCountdown: true,
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ));

    await t.tap(find.byKey(const Key('open-lesson')));
    await t.pump(); // push'u başlat
    await t.pump(const Duration(milliseconds: 300)); // geçiş animasyonu

    expect(find.byType(LiveScreenRoute), findsOneWidget,
        reason: 'push sonrası LiveScreenRoute ekranda değil');

    for (int i = 0; i < 16; i++) {
      await t.pump(const Duration(milliseconds: 180));
    }

    expect(find.byKey(const Key('observation-cue')), findsOneWidget,
        reason: 'O-032 REGRESYONU: gerçek route arkasında işaret DOĞMADI');

    await src.stop();
    await src.dispose();
  });
}
