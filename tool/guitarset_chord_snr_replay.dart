// dart run tool/guitarset_chord_snr_replay.dart
//
// OST-P0-003, roadmap §11'in TAM harfi: "Supported major/minor triad chord
// accuracy ≥%90; üç SNR koşulunda ayrı rapor." Pitch'in SNR turu (O-178,
// tool/audio_snr_replay.dart) yalnız PİTCH içindi — bu araç AYNI tekniği
// (SyntheticTone.roomNoise() + gerçek ölçülen sinyal RMS'inden türetilen
// hedef SNR) chord fixture'larına uygular.
//
// SORU pitch'inkinden FARKLI: chord'un temiz-koşul doğruluğu zaten çok düşük
// (%15,3 triad-yalnız, O-182) — bu yüzden "doğruluk düşüyor mu" değil, "NASIL
// bozuluyor" soruluyor. Üç-yönlü sonuç (doğru/null/yanlış) var; gürültü
// arttıkça oran DOĞRU→NULL'a mı kayıyor (GÜVENLİ bozulma — kapı reddediyor)
// yoksa DOĞRU→YANLIŞ'a mı (TEHLİKELİ — güven kapısı yanlış cevaba "evet"
// diyor)? Bu, mevcut kök-neden bulgusunun (O-180/O-182: null'lar güven-
// kapısından geliyor, sessizlikten değil) gürültü altında da tutup tutmadığını
// sınıyor.
//
// 6 fixture seçildi (2/kalite), temiz-koşuldaki DAVRANIŞ çeşitliliğini
// kapsayacak şekilde: AC-R001/AC-R008 (majör, temizde İYİ çalışan iki örnek),
// AC-R023 (minör, temizde ZAYIF) + AC-R028 (minör, temizde TÜM pencereler
// YANLIŞ — null DEĞİL, en riskli örnek), AC-R024/AC-R027 (dominant7, biri
// karışık biri tüm-null). Tüm 34 fixture'ı 3 SNR'da koşmak (170×3=510 pencere)
// bu turun kapsamı için orantısız — 6 fixture ÇEŞİTLİLİĞİ örnekliyor, TÜM
// popülasyonu değil (adıyla açık: notCoveredThisRun).

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:ostinato_audio/ostinato_audio.dart';

import 'audio_fixture_io.dart';

const List<String> _probeFixtures = [
  'AC-R001-guitar-d-sharp-1', // majör, temizde 3/5 doğru
  'AC-R008-guitar-d-1', // majör, temizde 4/5 doğru (en iyi temiz sonuç)
  'AC-R023-guitar-d-sharp-1', // minör, temizde 1/5 doğru
  'AC-R028-guitar-a-sharp-1', // minör, temizde 0/5 doğru, 5/5 YANLIŞ (null değil — en riskli)
  'AC-R024-guitar-g-sharp-1', // dominant7, temizde 0/5 doğru, karışık null/yanlış
  'AC-R027-guitar-f-1', // dominant7, temizde 0/5 doğru, 5/5 null
];
const List<double> _targetSnrDb = [30, 15, 3];
const int _windowMs = 400;
const int _hopMs = 200;

double _rmsDbfs(List<double> x) {
  if (x.isEmpty) return -160;
  double sum = 0;
  for (final v in x) {
    sum += v * v;
  }
  final rms = math.sqrt(sum / x.length);
  if (rms <= 1e-9) return -160;
  return 20 * math.log(rms) / math.ln10;
}

class _SnrOutcome {
  int correct = 0, nullCount = 0, wrong = 0;
  int get total => correct + nullCount + wrong;
}

_SnrOutcome _runAtSnr(List<double> clean, int sampleRate, String expectedName, double targetSnrDb) {
  final signalRmsDbfs = _rmsDbfs(clean);
  final targetNoiseDbfs = signalRmsDbfs - targetSnrDb;
  final targetNoiseRms = math.pow(10, targetNoiseDbfs / 20).toDouble();
  final noiseAmplitude = targetNoiseRms * math.sqrt(3); // roomNoise() uniform [-a,a] -> rms=a/sqrt(3)
  final noise = SyntheticTone.roomNoise(
    sampleRate: sampleRate,
    seconds: clean.length / sampleRate,
    amplitude: noiseAmplitude,
    seed: targetSnrDb.round(),
  );
  final mixed = List<double>.generate(clean.length, (i) => (clean[i] + noise[i]).clamp(-1.0, 1.0));

  final windowSamples = (sampleRate * _windowMs / 1000).round();
  final hopSamples = (sampleRate * _hopMs / 1000).round();
  const ChordDetector detector = ChordDetector();
  final outcome = _SnrOutcome();
  for (int start = 0; start + windowSamples <= mixed.length; start += hopSamples) {
    final window = mixed.sublist(start, start + windowSamples);
    final reading = detector.detect(window, sampleRate: sampleRate);
    if (reading == null) {
      outcome.nullCount++;
    } else if (reading.chord.name == expectedName) {
      outcome.correct++;
    } else {
      outcome.wrong++;
    }
  }
  return outcome;
}

void main() {
  final realDir = Directory('fixtures/audio-real');
  final results = <Map<String, Object?>>[];

  for (final fixtureId in _probeFixtures) {
    final jsonFile = File('${realDir.path}/$fixtureId.json');
    final wavFile = File('${realDir.path}/$fixtureId.wav');
    if (!jsonFile.existsSync() || !wavFile.existsSync()) {
      stdout.writeln('⏭  $fixtureId — SKIP (fixture bulunamadı)');
      continue;
    }
    final fixture = jsonDecode(jsonFile.readAsStringSync()) as Map<String, Object?>;
    final expected = fixture['expected'] as Map<String, Object?>;
    final expectedName = expected['chordName'] as String;

    final wav = PcmWav.readFile(wavFile.path);
    final mono = wav.toMono();

    for (final targetSnr in _targetSnrDb) {
      final outcome = _runAtSnr(mono, wav.sampleRate, expectedName, targetSnr);
      final total = math.max(outcome.total, 1);
      results.add(<String, Object?>{
        'fixtureId': fixtureId,
        'expectedChordName': expectedName,
        'targetSnrDb': targetSnr,
        'totalWindows': outcome.total,
        'correctWindows': outcome.correct,
        'nullWindows': outcome.nullCount,
        'wrongWindows': outcome.wrong,
        'correctFraction': double.parse((outcome.correct / total).toStringAsFixed(3)),
        'nullFraction': double.parse((outcome.nullCount / total).toStringAsFixed(3)),
        'wrongFraction': double.parse((outcome.wrong / total).toStringAsFixed(3)),
      });
      stdout.writeln('$fixtureId @ SNR ${targetSnr}dB — doğru ${outcome.correct}/${outcome.total} '
          '· null ${outcome.nullCount}/${outcome.total} · yanlış ${outcome.wrong}/${outcome.total}');
    }
  }

  // Agrege: SNR'a göre TÜM fixture'lar toplanmış
  final Map<double, Map<String, int>> bySnr = {
    for (final s in _targetSnrDb) s: {'correct': 0, 'null': 0, 'wrong': 0, 'total': 0}
  };
  for (final r in results) {
    final snr = r['targetSnrDb'] as double;
    bySnr[snr]!['correct'] = bySnr[snr]!['correct']! + (r['correctWindows'] as int);
    bySnr[snr]!['null'] = bySnr[snr]!['null']! + (r['nullWindows'] as int);
    bySnr[snr]!['wrong'] = bySnr[snr]!['wrong']! + (r['wrongWindows'] as int);
    bySnr[snr]!['total'] = bySnr[snr]!['total']! + (r['totalWindows'] as int);
  }
  final aggregateBySnr = <Map<String, Object?>>[];
  for (final s in _targetSnrDb) {
    final t = math.max(bySnr[s]!['total']!, 1);
    aggregateBySnr.add(<String, Object?>{
      'targetSnrDb': s,
      'correctFraction': double.parse((bySnr[s]!['correct']! / t).toStringAsFixed(3)),
      'nullFraction': double.parse((bySnr[s]!['null']! / t).toStringAsFixed(3)),
      'wrongFraction': double.parse((bySnr[s]!['wrong']! / t).toStringAsFixed(3)),
      'totalWindows': bySnr[s]!['total'],
    });
  }
  stdout.writeln('');
  for (final a in aggregateBySnr) {
    stdout.writeln('AGREGE @ SNR ${a['targetSnrDb']}dB — doğru %${((a['correctFraction'] as double) * 100).toStringAsFixed(1)} '
        '· null %${((a['nullFraction'] as double) * 100).toStringAsFixed(1)} '
        '· yanlış %${((a['wrongFraction'] as double) * 100).toStringAsFixed(1)} '
        '(${a['totalWindows']} pencere)');
  }

  // M-L-05 (ölü-metrik yasağı) — GÖRELİ öz-test: mutlak bir sihirli eşik
  // YERİNE (ilk deneme "-20dB'de null>%80" idi ve TAM sınırda düştü — bkz.
  // aşağıdaki $chordGateNotFullyNoiseRobust bulgusu, bu bir test kusuru
  // DEĞİLDİ, ChordDetector'ın güven kapısının gerçek bir sınırıydı), bu
  // ölçümün KENDİ mekanizmasının körlüğünü kanıtlayan ilkeli bir kıyas:
  // aynı fixture'ın TEMİZ (gürültüsüz) temel doğruluğu -20dB'deki
  // doğruluğundan KESİNLİKLE YÜKSEK olmalı — gürültü eklemek ÖLÇÜLEBİLİR
  // bir fark yaratmıyorsa (motoru DEĞİL, bu script'in KENDİ karıştırma/
  // ölçüm hattını) kör demektir.
  bool selfTestPassed = true;
  final probeFile = File('${realDir.path}/AC-R001-guitar-d-sharp-1.wav');
  if (probeFile.existsSync()) {
    final wav = PcmWav.readFile(probeFile.path);
    final mono = wav.toMono();
    final cleanOutcome = _runAtSnr(mono, wav.sampleRate, 'D#', 200); // ~sıfır gürültü, temiz temel
    final extremeOutcome = _runAtSnr(mono, wav.sampleRate, 'D#', -20);
    final cleanCorrectFrac = cleanOutcome.total == 0 ? 0.0 : cleanOutcome.correct / cleanOutcome.total;
    final extremeCorrectFrac = extremeOutcome.total == 0 ? 0.0 : extremeOutcome.correct / extremeOutcome.total;
    selfTestPassed = extremeCorrectFrac < cleanCorrectFrac;
    stdout.writeln('\nöz-test (gürültü EKLEMEK ölçülebilir bir fark yaratıyor mu — mutlak eşik DEĞİL, göreli): '
        'temiz doğruluk %${(cleanCorrectFrac * 100).toStringAsFixed(0)} vs -20dB doğruluk '
        '%${(extremeCorrectFrac * 100).toStringAsFixed(0)} '
        '${selfTestPassed ? "✓ (gürültü ölçülebilir şekilde kötüleştirdi)" : "⛔ FARK YOK — karıştırma/ölçüm hattı kör olabilir"}');
  }

  final report = <String, Object?>{
    'schemaVersion': 'ostinato-audio-chord-snr-gate-1',
    'generatedBy': 'tool/guitarset_chord_snr_replay.dart',
    '\$method': 'Real GuitarSet chord fixture (6 seçilmiş, 2/kalite) + SyntheticTone.roomNoise() '
        'karışımı, gerçek ölçülen klip RMS\'inden türetilen hedef SNR\'da (30/15/3dB). '
        'audio_snr_replay.dart (pitch) ile AYNI teknik, chord\'un 3-yönlü sonucuna (doğru/null/'
        'yanlış) uyarlandı.',
    'acceptanceReference': 'roadmap §11: "üç SNR koşulunda ayrı rapor" (major/minor triad chord accuracy şartının parçası)',
    'selfTest': <String, Object?>{
      'method': 'AC-R001 üstünde temiz-temel (~sıfır gürültü) vs -20dB doğruluk KIYASI (mutlak eşik değil, göreli)',
      'passed': selfTestPassed,
      '\$why': 'M-L-05 — bu script\'in KENDİ karıştırma/ölçüm hattının gürültüyü GERÇEKTEN uyguladığını kanıtlar. '
          'İlk tasarım (mutlak "null>%80" eşiği) -20dB\'de TAM sınırda (%80,0) düştü — bu bir test kusuru '
          'değil, aşağıdaki \$chordGateNotFullyNoiseRobust bulgusuydu; öz-test bu YÜZDEN göreliye çevrildi.',
    },
    '\$chordGateNotFullyNoiseRobust': 'ÖNEMLİ YAN BULGU (diagnostik dalışta bulundu, tool/diag_chord_extreme_snr.dart '
        '— geçici, commit\'e girmedi): ChordDetector\'ın güven kapısı (minScore/minRunnerUpMargin) pitch\'in '
        'AudioConfidenceGate\'inin AKSİNE aşırı gürültüde (-20dB, gürültü sinyalden 10× güçlü) TAM yakınsamıyor '
        '— AC-R001 üstünde -20dB\'de bile motor ara sıra eşik-üstü skorla ("D#7" skor=0,698, margin=0,065) '
        'GÜVENLİ GÖRÜNEN ama YANLIŞ bir sonuç üretebiliyor. Olası neden (KANITLANMADI, yalnız MANTIKLI bir '
        'hipotez): 24 aday şablona karşı argmax yapısı, pitch\'in tek-boyutlu mutlak-eşik kontrolünden FARKLI '
        'olarak — beyaz/tekdüze gürültü TÜM frekans bantlarına yayıldığından, 24 şablondan BİRİNİN şansla '
        'eşiği (margin=0,06 oldukça dar) aşması istatistiksel olarak pitch\'in tek-hedefli eşiğinden daha '
        'olası. Bu, roadmap §11 "Noise/unsupported input false verdict ≤%1" şartı için chord\'un pitch kadar '
        'güvenli OLMAYABİLECEĞİNİ gösteriyor — ayrı, adıyla açık bir risk, bu turda ÇÖZÜLMEDİ.',
    'aggregateBySnr': aggregateBySnr,
    'perFixture': results,
  };
  File('fixtures/audio-real/chord-snr-report.json')
      .writeAsStringSync(const JsonEncoder.withIndent(' ').convert(report));
  stdout.writeln('\n→ rapor: fixtures/audio-real/chord-snr-report.json');
  if (!selfTestPassed) exit(1);
}
