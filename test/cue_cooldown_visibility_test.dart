import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/content.dart';
import 'package:ostinato/app/cue_text.dart';
import 'package:ostinato/app/design/app_scope.dart';
import 'package:ostinato/app/design/ostinato_theme.dart';
import 'package:ostinato/app/screens/live_screen.dart';
import 'package:ostinato_posture/ostinato_posture.dart';

/// O-032 KAPANIŞ KANITI (kalıcı) — kök neden BUG DEĞİL, gerçek 30sn cooldown.
/// Gerçek demo senaryosu + gerçek `PostureEvaluator` cooldown'ı + gerçek
/// `LiveScreenRoute`: ilk ateşleme → banda-dönüş-silme → cooldown-sessizliği
/// → ikinci ateşleme, tek testte, fake-async'te <1sn'de.
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
      'gerçek 30sn cooldown ile işaret İKİNCİ KEZ ateşlenir ve EKRANA çıkar',
      (WidgetTester t) async {
    final FakePoseSource src = FakePoseSource(<double?>[
      2.0, 2.4, 3.1, 2.8, 3.4, 2.2, 2.9, 3.3, 2.5, 3.0,
      null, null, null,
      16.0, 18.0, 19.5, 21.0, 22.0, 20.5, 19.0, 20.0, 21.5, 22.5,
      21.0, 19.5, 18.5, 20.0, 21.0,
      6.0, 4.5, 3.2, 2.6,
    ], stepUs: 180000);

    await t.pumpWidget(ContentRepositoryScope(
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
    ));

    bool sawFirstFiring = false;
    bool clearedAfterReturnToBand = false;
    bool sawSecondFiring = false;

    for (int tick = 0; tick <= 190; tick++) {
      await t.pump(const Duration(milliseconds: 180));
      final bool cueVisible =
          find.byKey(const Key('observation-cue')).evaluate().isNotEmpty;

      if (tick >= 15 && tick <= 27 && cueVisible) sawFirstFiring = true;
      if (tick == 28 && !cueVisible) clearedAfterReturnToBand = true;
      if (tick >= 45 && tick < 182 && cueVisible) {
        fail('tick=$tick: cooldown DOLMADAN işaret yeniden göründü — '
            'suppresyon kırık (30sn = 166,67 kare, 182. karede dolar)');
      }
      if (tick >= 182 && cueVisible) sawSecondFiring = true;
    }

    expect(sawFirstFiring, isTrue, reason: 'ilk ateşleme (tick 15) ekrana çıkmadı');
    expect(clearedAfterReturnToBand, isTrue,
        reason: 'tick 28: banda dönüldü ama işaret ekranda kaldı');
    expect(sawSecondFiring, isTrue,
        reason: 'O-032 AÇIK KALIR: cooldown dolduktan sonra işaret bir daha '
            'hiç ekrana çıkmadı');

    await src.stop();
    await src.dispose();
  });
}
