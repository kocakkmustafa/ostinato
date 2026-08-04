import 'dart:io';

import 'package:ostinato_posture/ostinato_posture.dart';
import 'package:test/test.dart';

/// Sözleşme GERÇEK varlıktan okunur — testin kendi sayısını uydurması,
/// sınadığı şeyi kendi kurgusuna göre sınaması olurdu.
PostureContract _contract(String instrument) => PostureContract.fromJson(
      File('../../assets/config/posture-contract.json').readAsStringSync(),
      instrument,
    );

PoseFrame _f(double? tilt, {int tUs = 0}) =>
    PoseFrame(tUs: tUs, trunkTiltDeg: tilt);

void main() {
  group('sözleşme varlıktan okunuyor', () {
    test('üç çalgı da yüklenir ve bant ölçülen aralığı taşır', () {
      for (final String i in ['guitar', 'voice', 'piano']) {
        final c = _contract(i);
        expect(c.teacherCount, greaterThanOrEqualTo(3));
        expect(c.bandLowDeg, lessThan(c.bandHighDeg));
        expect(c.cueThresholdDeg, greaterThan(c.scoringToleranceDeg),
            reason: 'merdiven sırası bozulmuş: tolerans <= cue eşiği olmalı');
      }
    });
  });

  group('gözlem işareti — POZİTİF İKİZ (M-F-232 şart 6)', () {
    test('bant İÇİNDE cue SUSAR (sessiz taraf)', () {
      final e = PostureEvaluator(contract: _contract('guitar'));
      for (int i = 0; i < 50; i++) {
        final s = e.evaluate(_f(3.0, tUs: i * 33333)) as Measuring;
        expect(s.cue, isNull, reason: '3° bandın içinde — işaret konuşmamalı');
        expect(s.inBand, isTrue);
      }
    });

    test('bant DIŞINDA cue GÖRÜNÜR (ikiz) — ama SÜRDÜRÜLÜNCE', () {
      final e = PostureEvaluator(contract: _contract('guitar'));
      // Tek kare yetmez: bastırma eşiği 3 ardışık kare.
      expect((e.evaluate(_f(25.0, tUs: 0)) as Measuring).cue, isNull);
      expect((e.evaluate(_f(25.0, tUs: 33333)) as Measuring).cue, isNull);
      final third = e.evaluate(_f(25.0, tUs: 66666)) as Measuring;
      expect(third.cue, isNotNull,
          reason: 'sürdürülen sapmada işaret DOĞMADI — hep-sessiz dedektör '
              'bütün testleri geçerdi');
      expect(third.inBand, isFalse);
    });

    test('cue METİN taşımaz — şablon kimliği + yuvalar (şart 2)', () {
      final e = PostureEvaluator(contract: _contract('voice'));
      // İLK işareti yakala: sonraki kareler cooldown ile BASTIRILIR ve bu
      // doğrudur — son kareye bakan bir test, cooldown'ı arıza sanardı.
      ObservationCue? cue;
      int cueCount = 0;
      for (int i = 0; i < 5; i++) {
        final s = e.evaluate(_f(30.0, tUs: i * 33333)) as Measuring;
        if (s.cue != null) {
          cue ??= s.cue;
          cueCount++;
        }
      }
      expect(cueCount, 1,
          reason: 'sürdürülen sapmada işaret HER karede doğdu — cooldown ölü; '
              'sürekli konuşan bir gözlem, gözlem değil arka plan gürültüsüdür');
      expect(cue!.templateId, 'OBS_TRUNK_OUTSIDE_RANGE');
      expect(cue.slots.keys,
          containsAll(<String>['n', 'sourceClass', 'thresholdDeg', 'measuredDeg']));
      // Motor kullanıcı metni ÜRETMEZ: yükte cümle olacak bir alan yok.
      expect(cue.slots['n'], '6');
      expect(cue.slots['sourceClass'], 'voice teachers');
    });

    test('sapma kesilince sayaç sıfırlanır — eski sapma yeni işaret üretmez', () {
      final e = PostureEvaluator(contract: _contract('piano'));
      e.evaluate(_f(25.0, tUs: 0));
      e.evaluate(_f(25.0, tUs: 33333));
      e.evaluate(_f(1.0, tUs: 66666)); // düzeldi
      final s = e.evaluate(_f(25.0, tUs: 99999)) as Measuring;
      expect(s.cue, isNull,
          reason: 'sayaç sıfırlanmadı — kesintili sapmalar birikip işaret üretiyor');
    });
  });

  group('dürüst hâller', () {
    test('kişi görünmüyorsa NoPersonVisible — "0 derece" DEĞİL', () {
      final e = PostureEvaluator(contract: _contract('guitar'));
      expect(e.evaluate(_f(null)), isA<NoPersonVisible>());
    });

    test('görünmeyen kişi aralık-dışı SAYILMAZ', () {
      final e = PostureEvaluator(contract: _contract('guitar'));
      e.evaluate(_f(25.0, tUs: 0));
      e.evaluate(_f(25.0, tUs: 33333));
      e.evaluate(_f(null, tUs: 66666)); // kadraj dışına çıktı
      final s = e.evaluate(_f(25.0, tUs: 99999)) as Measuring;
      expect(s.cue, isNull,
          reason: 'kadraj dışı kareler sapma serisini SÜRDÜRÜYOR — '
              'görünmeyen kişi hakkında hüküm kuruluyor demektir');
    });
  });

  group('K8 — sayısal skor YOK', () {
    test('bant konumu bir KONUMDUR, puan değil ve dışarıda null döner', () {
      final e = PostureEvaluator(contract: _contract('guitar'));
      expect(e.positionInTeacherBand(0.4), closeTo(0.0, 1e-6));
      expect(e.positionInTeacherBand(6.4), closeTo(1.0, 1e-6));
      expect(e.positionInTeacherBand(30.0), isNull,
          reason: 'bant dışında bir KONUM yoktur — 1.0 döndürmek onu '
              'tavana yapışmış bir PUANA çevirirdi');
    });
  });

  _fakeSourceClockTests();

  group('sahte kaynak canlı yolu besliyor', () {
    test('akış hâllere dönüşüyor: içeride sessiz → dışarıda işaret', () async {
      final c = _contract('guitar');
      final e = PostureEvaluator(contract: c);
      final src = FakePoseSource(<double?>[2.0, 2.5, null, 25.0, 25.0, 25.0]);
      final states = <SurfaceState>[];
      final sub = src.frames.listen((f) => states.add(e.evaluate(f)));
      for (int i = 0; i < 6; i++) {
        src.pushOne();
      }
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      await src.dispose();

      expect(states.length, 6);
      expect((states[0] as Measuring).cue, isNull);
      expect(states[2], isA<NoPersonVisible>());
      expect((states[5] as Measuring).cue, isNotNull,
          reason: 'sahte kaynakla canlı yol uçtan uca akmadı');
    });
  });
}

/// Sim ekran-kanıtının yakaladığı İKİNCİ kusurun regresyonu.
void _fakeSourceClockTests() {
  test('sahte kaynağın saati senaryo başa sarınca da MONOTONİK kalır', () {
    final src = FakePoseSource(<double?>[1.0, 2.0], stepUs: 1000);
    final stamps = <int>[];
    final sub = src.frames.listen((f) => stamps.add(f.tUs));
    for (int i = 0; i < 6; i++) {
      src.pushOne(); // senaryo 3 kez döner
    }
    return Future<void>.delayed(Duration.zero).then((_) async {
      await sub.cancel();
      await src.dispose();
      expect(stamps, <int>[0, 1000, 2000, 3000, 4000, 5000],
          reason: 'saat geri gitti — cooldown bir daha asla dolmaz ve '
              'gözlem işareti ilk turdan sonra sessizce ölür');
    });
  });

  test('döngü dönse de işaret YENİDEN doğar (cooldown gerçekten dolar)', () {
    final c = PostureContract.fromJson(
        File('../../assets/config/posture-contract.json').readAsStringSync(),
        'guitar');
    final e = PostureEvaluator(contract: c, cooldownUs: 1000);
    int cues = 0;
    // İki tur: her turda 3 ardışık sapma → 2 işaret beklenir.
    for (int cycle = 0; cycle < 2; cycle++) {
      for (int i = 0; i < 3; i++) {
        final s = e.evaluate(PoseFrame(
            tUs: (cycle * 10 + i) * 2000, trunkTiltDeg: 25.0)) as Measuring;
        if (s.cue != null) cues++;
      }
      e.evaluate(PoseFrame(tUs: (cycle * 10 + 5) * 2000, trunkTiltDeg: 2.0));
    }
    expect(cues, 2,
        reason: 'ikinci turda işaret doğmadı — saat ya da cooldown ölü');
  });
}
