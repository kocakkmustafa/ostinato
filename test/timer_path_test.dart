import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/content.dart';
import 'package:ostinato/app/cue_text.dart';
import 'package:ostinato/app/design/app_scope.dart';
import 'package:ostinato/app/design/ostinato_theme.dart';
import 'package:ostinato/app/screens/live_screen.dart';
import 'package:ostinato_posture/ostinato_posture.dart';

/// O-032 TEŞHİS TESTİ — uygulamanın GERÇEK yolu (regresyon kalıcı kanıtı).
///
/// O-032 kapandı (2026-08-05): bu test artık aktif teşhis değil, kalıcı
/// regresyon kapısı. `Timer.periodic`/`setState` yolu bir kez şüpheliydi,
/// ölçülüp YANLIŞ çıktı — bu test o ölçümün donmuş hâli.
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

  Widget harness(FakePoseSource src) => ContentRepositoryScope(
        repo: repo,
        cueText: cueText,
        child: MaterialApp(
          home: LiveScreenRoute(
            discipline: guitar,
            lesson: postureLesson,
            hue: InstrumentHues.guitar,
            source: src,
            skipCountdown: true,
          ),
        ),
      );

  testWidgets('GERÇEK zamanlayıcıyla: sürdürülen sapmada işaret GÖRÜNÜR mü?',
      (WidgetTester t) async {
    final FakePoseSource src = FakePoseSource(
      <double?>[2.0, 2.5, 16.0, 18.0, 19.5, 21.0, 22.0, 20.5],
      stepUs: 180000,
    );
    await t.pumpWidget(harness(src));

    for (int i = 0; i < 8; i++) {
      await t.pump(const Duration(milliseconds: 180));
    }

    expect(find.byKey(const Key('live-measuring')), findsOneWidget,
        reason: 'zamanlayıcı yolunda ölçüm ekranına hiç gelinmedi');
    expect(find.byKey(const Key('observation-cue')), findsOneWidget,
        reason: 'O-032 REGRESYONU: gerçek zamanlayıcıyla işaret DOĞMADI');

    await src.stop();
    await src.dispose();
  });

  testWidgets('UYGULAMANIN TAM senaryosu (null kareler dahil), gerçek zamanlayıcı',
      (WidgetTester t) async {
    final FakePoseSource src = FakePoseSource(<double?>[
      2.0, 2.4, 3.1, 2.8, 3.4, 2.2, 2.9, 3.3, 2.5, 3.0,
      null, null, null,
      16.0, 18.0, 19.5, 21.0, 22.0, 20.5, 19.0, 20.0, 21.5, 22.5,
      21.0, 19.5, 18.5, 20.0, 21.0,
      6.0, 4.5, 3.2, 2.6,
    ], stepUs: 180000);

    await t.pumpWidget(harness(src));

    for (int i = 0; i < 16; i++) {
      await t.pump(const Duration(milliseconds: 180));
    }
    expect(find.byKey(const Key('observation-cue')), findsOneWidget,
        reason: 'TAM senaryoda işaret doğmadı — fark null kareler tarafında');

    await src.stop();
    await src.dispose();
  });
}
