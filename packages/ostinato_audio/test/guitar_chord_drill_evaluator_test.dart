import 'package:ostinato_audio/ostinato_audio.dart';
import 'package:test/test.dart';

/// OST-P1-001 Step 2 (guitar) — `PostureEvaluator`nin AYNI deseni: ruleset
/// sözleşmesini (`GuitarChordDrillContract`) GERÇEK bir motora
/// (`ChordDetector`) bağlayıp TEK bir pencereyi tipli bir okumaya çeviren
/// saf Dart sınıf. `evaluate()` çağrılarının SIRASI önemli — atak-penceresi
/// bookkeeping'i `PostureEvaluator`nin debounce/cooldown'uyla AYNI sınıf.
void main() {
  const int sampleRate = 44100;
  final Map<String, List<int>> chords = SyntheticTone.openGuitarChords;

  const String contractJson = '''
{"guitar": {"chordCorrectnessThreshold": 0.8, "levelAboveRoomFloorDbThreshold": 6,
 "playTimeoutMs": 20000, "playMinDurationMs": 800, "onsetNoVerdictHoldMs": 100,
 "pitchWindowMs": 92.9, "pitchHopMs": 23.2, "yinThreshold": 0.15,
 "onsetFrameMs": 46, "onsetHopMs": 6, "onsetMedianWindow": 11, "onsetBandCount": 24,
 "onsetMinAnalysisHz": 40, "onsetMaxAnalysisHz": 4000,
 "_derivedFrom": {"ruleset": "x", "rulesetVersion": "x", "technique": "x"}}}
''';
  final GuitarChordDrillContract contract = GuitarChordDrillContract.fromJson(contractJson);

  /// `chord_detector_test.dart`daki AYNI desen: strum yayılımının ötesinde,
  /// sustain'in ortasında — bir drill'in GERÇEKTEN skorlayacağı pencere.
  List<double> playedWindow(List<int> midi) {
    final List<double> s = SyntheticTone.chord(midiNotes: midi, sampleRate: sampleRate, seconds: 1.5);
    return s.sublist((0.3 * sampleRate).round(), (0.7 * sampleRate).round());
  }

  List<double> silence(double seconds) => List<double>.filled((seconds * sampleRate).round(), 0.0);

  const double roomFloorDb = -60.0;
  // roomFloorDb + levelAboveRoomFloorDbThreshold(6) = -54dB'nin ÜSTÜNDE bir
  // sinyal gerekir. Gerçek akor sinyali bunu rahatça aşar (chord_detector_
  // test.dart'ta aynı sentetik üreticiyle zaten ölçülü).

  group('DrillAwaitingSound — seviye eşiğin ALTINDA', () {
    test('sessizlik AwaitingSound döner, ChordDetector\'a HİÇ sorulmaz', () {
      final GuitarChordDrillEvaluator ev = GuitarChordDrillEvaluator(contract: contract);
      final GuitarChordDrillReading r = ev.evaluate(
        silence(0.4),
        sampleRate: sampleRate,
        tStartUs: 0,
        roomFloorDb: roomFloorDb,
        expectedChordName: 'E',
      );
      expect(r, isA<DrillAwaitingSound>());
    });
  });

  group('DrillInAttackWindow — onset\'in HEMEN ardından', () {
    test('noteOnset() sonrası contract.onsetNoVerdictHoldMs içinde InAttackWindow döner', () {
      final GuitarChordDrillEvaluator ev = GuitarChordDrillEvaluator(contract: contract);
      ev.noteOnset(1000000); // 1.0s
      final GuitarChordDrillReading r = ev.evaluate(
        playedWindow(chords['E']!),
        sampleRate: sampleRate,
        tStartUs: 1000000 + 50000, // onset'ten 50ms sonra, 100ms holdMs'in İÇİNDE
        roomFloorDb: roomFloorDb,
        expectedChordName: 'E',
      );
      expect(r, isA<DrillInAttackWindow>(),
          reason: 'sinyal net E olsa bile atak penceresi İÇİNDEYSE hüküm YOK');
    });

    test('hold penceresi GEÇTİKTEN sonra normal sınıflandırmaya döner', () {
      final GuitarChordDrillEvaluator ev = GuitarChordDrillEvaluator(contract: contract);
      ev.noteOnset(1000000);
      final GuitarChordDrillReading r = ev.evaluate(
        playedWindow(chords['E']!),
        sampleRate: sampleRate,
        tStartUs: 1000000 + 150000, // onset'ten 150ms sonra, 100ms holdMs'in DIŞINDA
        roomFloorDb: roomFloorDb,
        expectedChordName: 'E',
      );
      expect(r, isNot(isA<DrillInAttackWindow>()));
    });
  });

  group('DrillCorrect / DrillIncorrect / DrillUnclear — asıl sınıflandırma', () {
    test('beklenen akor DOĞRU adla VE eşik-üstü skorla okunursa Correct', () {
      final GuitarChordDrillEvaluator ev = GuitarChordDrillEvaluator(contract: contract);
      final GuitarChordDrillReading r = ev.evaluate(
        playedWindow(chords['E']!),
        sampleRate: sampleRate,
        tStartUs: 1000000,
        roomFloorDb: roomFloorDb,
        expectedChordName: 'E',
      );
      expect(r, isA<DrillCorrect>());
      expect((r as DrillCorrect).score, greaterThanOrEqualTo(contract.chordCorrectnessThreshold));
    });

    test('BAŞKA bir akor çalınırsa (Em beklenirken E çalındı) Incorrect, DOĞRU adıyla', () {
      final GuitarChordDrillEvaluator ev = GuitarChordDrillEvaluator(contract: contract);
      final GuitarChordDrillReading r = ev.evaluate(
        playedWindow(chords['E']!), // gerçekten E çalınıyor
        sampleRate: sampleRate,
        tStartUs: 1000000,
        roomFloorDb: roomFloorDb,
        expectedChordName: 'Em', // ama Em BEKLENİYOR
      );
      expect(r, isA<DrillIncorrect>());
      expect((r as DrillIncorrect).detectedName, 'E',
          reason: 'motor GERÇEKTEN neyi duyduğunu söylemeli — "yanlış" demek yetmez, '
              'kullanıcı hangi hatayı yaptığını bilmeli');
    });

    test('tek nota / akor-olmayan bir şey Unclear (Incorrect DEĞİL — motor hiçbir isim vermedi)', () {
      final GuitarChordDrillEvaluator ev = GuitarChordDrillEvaluator(contract: contract);
      final GuitarChordDrillReading r = ev.evaluate(
        playedWindow(const <int>[40]), // tek nota, akor DEĞİL
        sampleRate: sampleRate,
        tStartUs: 1000000,
        roomFloorDb: roomFloorDb,
        expectedChordName: 'E',
      );
      expect(r, isA<DrillUnclear>(),
          reason: 'ChordDetector null döndürdüğünde "yanlış akor" DEMEK sahte bir '
              'kesinlik olurdu — "duyamadım" ile "yanlış duydum" AYRI hâller');
    });
  });

  group('Sıra bağımlılığı — evaluate() çağrıları arasında durum KORUNUR', () {
    test('İKİNCİ bir noteOnset() atak penceresini YENİDEN başlatır', () {
      final GuitarChordDrillEvaluator ev = GuitarChordDrillEvaluator(contract: contract);
      ev.noteOnset(1000000);
      // ilk onset'ten UZUN süre sonra ama...
      ev.noteOnset(1300000); // ...YENİ bir onset geldi (ör. akor değişimi)
      final GuitarChordDrillReading r = ev.evaluate(
        playedWindow(chords['E']!),
        sampleRate: sampleRate,
        tStartUs: 1300000 + 50000, // YENİ onset'ten 50ms sonra
        roomFloorDb: roomFloorDb,
        expectedChordName: 'E',
      );
      expect(r, isA<DrillInAttackWindow>(),
          reason: 'ikinci onset kendi atak penceresini açar — ilk onset\'in '
              'penceresi çoktan kapanmış olsa bile');
    });
  });
}
