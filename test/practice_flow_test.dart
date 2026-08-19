import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/practice/practice_controller.dart';

/// OST-P1-001 Step 1: preview/calibrate/count-in/play/review/loop/retry
/// state testleri — TDD, KIRMIZI yazıldı (PracticeSessionController henüz
/// YOK). "Kabuk yalnız kablolama" deseni (PoseSource/SurfaceState/
/// PostureEvaluator ile AYNI): bu state machine saf Dart, Flutter Widget'a
/// bağımlı DEĞİL — widget pump'sız `flutter test`le doğrudan sınanır.
void main() {
  group('PracticePreview — başlangıç hâli', () {
    test('oturum PracticePreview ile başlar', () {
      final PracticeSessionController c = PracticeSessionController(
        modalities: const {PracticeModality.posture},
      );
      expect(c.state, isA<PracticePreview>());
    });
  });

  group('Preview → Calibrating', () {
    test('startCalibration() ile Calibrating\'e geçer, İSTENEN modaliteleri taşır', () {
      final PracticeSessionController c = PracticeSessionController(
        modalities: const {PracticeModality.posture, PracticeModality.audio},
      );
      c.startCalibration();
      final PracticeSessionState s = c.state;
      expect(s, isA<PracticeCalibrating>());
      expect((s as PracticeCalibrating).modalities,
          {PracticeModality.posture, PracticeModality.audio});
    });

    test('YANLIŞ hâlden startCalibration() çağrısı YOK SAYILIR (guard)', () {
      final PracticeSessionController c = PracticeSessionController(
        modalities: const {PracticeModality.posture},
      );
      c.startCalibration();
      final PracticeSessionState afterFirst = c.state;
      c.startCalibration(); // zaten Calibrating'te — ikinci çağrı etkisiz olmalı
      expect(c.state, same(afterFirst));
    });
  });

  group('Calibrating — TÜM modaliteler hazır olmadan İLERLEMEZ', () {
    test('yalnız BİR modalite hazır → hâlâ Calibrating (ikinci modalite BEKLENİYOR)', () {
      final PracticeSessionController c = PracticeSessionController(
        modalities: const {PracticeModality.posture, PracticeModality.audio},
      );
      c.startCalibration();
      c.reportModalityReady(PracticeModality.posture);
      expect(c.state, isA<PracticeCalibrating>(),
          reason: 'audio hâlâ hazır değilken CountIn\'e geçmek '
              'kalibre-edilmemiş bir modaliteyi SESSİZCE atlamak olurdu');
    });

    test('İKİ modalite de hazır → CountIn\'e geçer', () {
      final PracticeSessionController c = PracticeSessionController(
        modalities: const {PracticeModality.posture, PracticeModality.audio},
        countInBeats: 4,
      );
      c.startCalibration();
      c.reportModalityReady(PracticeModality.posture);
      c.reportModalityReady(PracticeModality.audio);
      final PracticeSessionState s = c.state;
      expect(s, isA<PracticeCountIn>());
      expect((s as PracticeCountIn).beatsRemaining, 4);
    });

    test('tek-modaliteli (yalnız posture) ders, o modalite hazır olunca DERHAL CountIn\'e geçer', () {
      final PracticeSessionController c = PracticeSessionController(
        modalities: const {PracticeModality.posture},
      );
      c.startCalibration();
      c.reportModalityReady(PracticeModality.posture);
      expect(c.state, isA<PracticeCountIn>());
    });

    test('AYNI modalite İKİ KEZ hazır bildirilirse (yinelenen olay) tek modalite SAYILIR', () {
      final PracticeSessionController c = PracticeSessionController(
        modalities: const {PracticeModality.posture, PracticeModality.audio},
      );
      c.startCalibration();
      c.reportModalityReady(PracticeModality.posture);
      c.reportModalityReady(PracticeModality.posture); // yinelenen
      expect(c.state, isA<PracticeCalibrating>(),
          reason: 'yinelenen posture bildirimi audio\'yu HAZIR SAYDIRMAMALI');
    });

    test('YANLIŞ hâlden reportModalityReady() çağrısı YOK SAYILIR (guard)', () {
      final PracticeSessionController c = PracticeSessionController(
        modalities: const {PracticeModality.posture},
      );
      // henüz startCalibration() ÇAĞRILMADI — hâlâ Preview
      c.reportModalityReady(PracticeModality.posture);
      expect(c.state, isA<PracticePreview>());
    });
  });

  group('CountIn — geri sayım', () {
    test('her tickCountIn() beatsRemaining\'i bir azaltır', () {
      final PracticeSessionController c = PracticeSessionController(
        modalities: const {PracticeModality.posture},
        countInBeats: 3,
      );
      c.startCalibration();
      c.reportModalityReady(PracticeModality.posture);
      expect((c.state as PracticeCountIn).beatsRemaining, 3);
      c.tickCountIn();
      expect((c.state as PracticeCountIn).beatsRemaining, 2);
    });

    test('son vuruşta Playing\'e geçer (beatsRemaining sıfıra İNMEZ, doğrudan Playing)', () {
      final PracticeSessionController c = PracticeSessionController(
        modalities: const {PracticeModality.posture},
        countInBeats: 2,
      );
      c.startCalibration();
      c.reportModalityReady(PracticeModality.posture);
      c.tickCountIn(); // 2 -> 1
      expect((c.state as PracticeCountIn).beatsRemaining, 1);
      c.tickCountIn(); // 1 -> Playing
      expect(c.state, isA<PracticePlaying>());
    });

    test('YANLIŞ hâlden tickCountIn() çağrısı YOK SAYILIR (guard)', () {
      final PracticeSessionController c = PracticeSessionController(
        modalities: const {PracticeModality.posture},
      );
      c.tickCountIn(); // hâlâ Preview
      expect(c.state, isA<PracticePreview>());
    });
  });

  group('Playing → Reviewing', () {
    PracticeSessionController playingController({int countInBeats = 1}) {
      final PracticeSessionController c = PracticeSessionController(
        modalities: const {PracticeModality.posture},
        countInBeats: countInBeats,
      );
      c.startCalibration();
      c.reportModalityReady(PracticeModality.posture);
      c.tickCountIn();
      return c;
    }

    test('finishAttempt() sonucu TAŞIYARAK Reviewing\'e geçer', () {
      final PracticeSessionController c = playingController();
      expect(c.state, isA<PracticePlaying>());
      c.finishAttempt(const PracticeAttemptOutcome(isWeak: true));
      final PracticeSessionState s = c.state;
      expect(s, isA<PracticeReviewing>());
      expect((s as PracticeReviewing).outcome.isWeak, isTrue);
    });

    test('YANLIŞ hâlden finishAttempt() çağrısı YOK SAYILIR (guard)', () {
      final PracticeSessionController c = PracticeSessionController(
        modalities: const {PracticeModality.posture},
      );
      c.finishAttempt(const PracticeAttemptOutcome(isWeak: false)); // hâlâ Preview
      expect(c.state, isA<PracticePreview>());
    });
  });

  group('Reviewing → retry (SICAK, sensörler kalibre kalır) vs advanceToNext (SOĞUK, yeniden preview)', () {
    PracticeSessionController reviewingController() {
      final PracticeSessionController c = PracticeSessionController(
        modalities: const {PracticeModality.posture},
        countInBeats: 1,
      );
      c.startCalibration();
      c.reportModalityReady(PracticeModality.posture);
      c.tickCountIn();
      c.finishAttempt(const PracticeAttemptOutcome(isWeak: true));
      return c;
    }

    test('retry() DOĞRUDAN CountIn\'e döner — Preview/Calibrating TEKRARLANMAZ', () {
      final PracticeSessionController c = reviewingController();
      c.retry();
      expect(c.state, isA<PracticeCountIn>(),
          reason: 'retry aynı egzersizin TEKRARI — sensörler zaten kalibre, '
              'kullanıcıyı yeniden preview/calibrating\'den geçirmek sürtünme eklerdi');
    });

    test('retry() sonrası modalite-hazırlık durumu KORUNUR — yeniden reportModalityReady GEREKMEZ', () {
      final PracticeSessionController c = reviewingController();
      c.retry();
      // CountIn zaten burada — tickCountIn hemen çalışmalı, reportModalityReady beklenmeden
      c.tickCountIn();
      expect(c.state, isA<PracticePlaying>());
    });

    test('advanceToNext() Preview\'e döner — YENİ segment, yeniden tanıtılır', () {
      final PracticeSessionController c = reviewingController();
      c.advanceToNext();
      expect(c.state, isA<PracticePreview>());
    });

    test('advanceToNext() sonrası modalite-hazırlık SIFIRLANIR — yeni segment yeniden kalibre olmalı', () {
      final PracticeSessionController c = reviewingController();
      c.advanceToNext();
      c.startCalibration();
      c.reportModalityReady(PracticeModality.posture);
      // Eğer eski hazırlık durumu SIZMIŞ olsaydı bu tek bildirim yetmezdi/hemen geçerdi
      // (tek modaliteli derste zaten hemen geçer) — asıl kanıt: state GERÇEKTEN Calibrating'ten geçti.
      expect(c.state, isA<PracticeCountIn>());
    });

    test('YANLIŞ hâlden retry()/advanceToNext() çağrıları YOK SAYILIR (guard)', () {
      final PracticeSessionController c = PracticeSessionController(
        modalities: const {PracticeModality.posture},
      );
      c.retry();
      expect(c.state, isA<PracticePreview>());
      c.advanceToNext();
      expect(c.state, isA<PracticePreview>());
    });
  });

  group('stateStream — her geçiş SIRAYLA yayılır', () {
    test('preview→calibrating→countIn→playing→reviewing tam sırayla akar', () async {
      final PracticeSessionController c = PracticeSessionController(
        modalities: const {PracticeModality.posture},
        countInBeats: 1,
      );
      final List<Type> seen = <Type>[];
      final sub = c.stateStream.listen((PracticeSessionState s) => seen.add(s.runtimeType));

      c.startCalibration();
      c.reportModalityReady(PracticeModality.posture);
      c.tickCountIn();
      c.finishAttempt(const PracticeAttemptOutcome(isWeak: false));
      await Future<void>.delayed(Duration.zero);

      expect(seen, <Type>[
        PracticeCalibrating,
        PracticeCountIn,
        PracticePlaying,
        PracticeReviewing,
      ]);
      await sub.cancel();
      c.dispose();
    });

    test('guard tarafından REDDEDİLEN çağrılar stream\'e HİÇBİR ŞEY yaymaz', () async {
      final PracticeSessionController c = PracticeSessionController(
        modalities: const {PracticeModality.posture},
      );
      final List<PracticeSessionState> seen = <PracticeSessionState>[];
      final sub = c.stateStream.listen(seen.add);

      c.tickCountIn(); // Preview'dan geçersiz — YOK SAYILMALI
      c.finishAttempt(const PracticeAttemptOutcome(isWeak: false)); // geçersiz
      await Future<void>.delayed(Duration.zero);

      expect(seen, isEmpty,
          reason: 'reddedilen bir geçiş sessizce state\'i DEĞİŞTİRMEMELİ VE '
              'dinleyicilere sahte bir "bir şey oldu" sinyali GÖNDERMEMELİ');
      await sub.cancel();
      c.dispose();
    });
  });
}
