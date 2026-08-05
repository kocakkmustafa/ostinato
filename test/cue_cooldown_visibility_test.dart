import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/content.dart';
import 'package:ostinato/app/cue_text.dart';
import 'package:ostinato/app/posture_screen.dart';
import 'package:ostinato_posture/ostinato_posture.dart';

/// O-032 KAPANIŞ KANITI — kök neden BUG DEĞİL, ÖLÇÜM-YÖNTEMİ boşluğu.
///
/// Canlı `flutter run` teşhisi (cold-launch, iPhone 17 Pro Max) hem
/// `PostureEvaluator.evaluate()` çıktısını hem widget'ın çizdiğini AYRI AYRI
/// logladı. Sonuç: işaret HER SEFERİNDE doğru ateşleniyor — ama gerçek 30sn
/// `cooldownUs` yüzünden her ~30sn'lik pencerede yalnız ~2,34sn'lik bir dilimde
/// GÖRÜNÜR (aralık-dışı sürenin ~%8'i). Manuel screenshot-tabanlı repro
/// denemeleri (bu dosyanın kardeşi `route_path_test.dart` ve önceki turların
/// ekran-yakalamaları) rastgele bir ana denk geldiği için neredeyse HER ZAMAN
/// "cooldown aktif, işaret yok" penceresini örnekliyordu — bu, mekanizmanın
/// kırık olduğu anlamına gelmez, yalnız TEK-ANLIK gözlemin bu sınıf bir UI
/// öğesini doğrulamaya uygun olmadığı anlamına gelir (O-028 ailesi: toplam/
/// tek-örnek ölçüm, düşük-görünürlük periyodik davranışı gizler).
///
/// `evaluator_test.dart`daki "döngü dönse de işaret YENİDEN doğar" testi
/// mekanizmayı KISALTILMIŞ cooldown'la (1000µs) zaten kanıtlamıştı — ama o
/// kanıt hiç GERÇEK 30sn değeriyle ve hiç WIDGET katmanında koşulmamıştı.
/// Bu test o boşluğu kapatır: gerçek varsayılan cooldown + gerçek demo
/// senaryosu + gerçek `PostureScreen` — ikinci ateşlemenin EKRANA ulaştığını
/// kanıtlar.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ContentRepository repo;
  late CueTextResolver cueText;
  setUpAll(() async {
    repo = await ContentRepository.load();
    cueText = await CueTextResolver.load();
  });

  testWidgets(
      'gerçek 30sn cooldown ile işaret İKİNCİ KEZ ateşlenir ve EKRANA çıkar',
      (WidgetTester t) async {
    // lib/main.dart'taki _demoScript ile BİREBİR aynı; FakePoseSource kendi
    // başına döngüye alır (bkz pose_source.dart `_emit`, `_i = 0` sarması).
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
        sourceLabel: 'TEST — gerçek cooldown, gerçek zamanlayıcı',
      ),
    ));

    // Kanıtlanacak üç olgu (canlı teşhiste ÖLÇÜLDÜ, burada TEKRARLANIR):
    // 1) ilk ateşleme tick 15'te (tUs=2.700.000) ekrana çıkar,
    // 2) tick 28'de banda dönünce SİLİNİR (M-F-232 şart 6),
    // 3) cooldown gerçekten dolunca (tUs>=32.700.000 → tick 182) İKİNCİ
    //    ateşleme yeniden ekrana çıkar — canlı örnekte tick=182 idi.
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
        reason: 'O-032 AÇIK KALIR: cooldown dolduktan sonra (tick>=182) işaret '
            'bir daha hiç ekrana çıkmadı — canlı yüzeyde gerçek tekrar-ateşleme '
            'kırık (yalnız kısaltılmış-cooldown testi bunu kaçırırdı)');

    await src.stop();
    await src.dispose();
  });
}
