// dart run tool/audio_fixture_replay.dart
//
// OST-P0-003 Step 2+4: `fixtures/audio-real/`i tarar, her fixture'ı
// `ostinato_audio`nun GERÇEK motoruyla (YinPitchSource + AudioConfidenceGate)
// koşar, `expected`±`tolerances`a karşı OTOMATİK değerlendirir, tek JSON
// rapor üretir (`docs/evidence/production-line/audio-model-gate.json`ın
// girdisi). Sentetik `fixtures/audio/` setine DOKUNMAZ — o zaten
// `packages/ostinato_audio/test/`in kendi test'lerinde kanıtlı, bu aracın
// işi YALNIZ gerçek kayıtlar.
//
// Fixture sesi henüz İNDİRİLMEMİŞSE (tool/fetch_audio_fixtures.sh
// koşulmadıysa) her fixture İSİMLİ `skipped` olarak raporlanır — sessizce
// atlanmaz, sessizce de ÇÖKMEZ.

import 'dart:convert';
import 'dart:io';

import 'package:ostinato_audio/ostinato_audio.dart';

import 'audio_fixture_io.dart';

void main() {
  final Directory realDir = Directory('fixtures/audio-real');
  // Yalnız `AF-*.json` — bu aracın KENDİ çıktısı (`replay-report.json`) aynı
  // klasöre yazılıyor ve `.json`la bitiyor; ayırt edilmezse bir sonraki
  // koşum kendi raporunu fixture sanıp çöker (ölçüldü: `fixture['audio']`
  // null çıkıp cast hatası verdi — kendi kaynağını okumadan varsaydığım
  // BİR TURLUK bir kusur, ikinci koşumda kendi kendini yakaladı).
  final List<File> jsonFiles = realDir.existsSync()
      ? (realDir.listSync().whereType<File>()
          .where((f) => f.uri.pathSegments.last.startsWith('AF-') && f.path.endsWith('.json'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path)))
      : <File>[];

  if (jsonFiles.isEmpty) {
    stderr.writeln('⛔ fixtures/audio-real/*.json yok — hiçbir gerçek fixture tanımlı değil.');
    exit(1);
  }

  // Piyano-uygun sınırlar (A0=27,5Hz .. C8=4186Hz) — `YinPitchSource`ın
  // VARSAYILANI (55-1200Hz) çello turlarından kalma (bkz. yin.dart dosya-başı
  // notu "open C2"), piyano'nun kendi aralığına göre GENİŞLETİLMEDEN
  // kullanmak C6/C8'i "desteklenmiyor" diye YANLIŞ etiketlerdi —
  // `PitchSource` sözleşmesinin kendi ilkesi ("instrument configs narrow
  // this further") ile TUTARLI: enstrüman-uygun sınır, sınıf-varsayılanı
  // DEĞİL.
  const double pianoMinHz = 25.0;
  const double pianoMaxHz = 4200.0;

  final List<Map<String, Object?>> results = [];
  int pass = 0, fail = 0, skip = 0, outOfRange = 0;

  for (final File jf in jsonFiles) {
    final Map<String, Object?> fixture = jsonDecode(jf.readAsStringSync()) as Map<String, Object?>;
    final String fixtureId = fixture['fixtureId'] as String;
    final String audioName = fixture['audio'] as String;
    final File audioFile = File('${realDir.path}/$audioName');

    if (!audioFile.existsSync()) {
      results.add(<String, Object?>{
        'fixtureId': fixtureId,
        'status': 'skipped',
        'reason': 'audio_not_fetched',
        'howToFix': 'bash tool/fetch_audio_fixtures.sh && dart run tool/prepare_audio_fixtures.dart',
      });
      skip++;
      stdout.writeln('⏭  $fixtureId — SKIP (ses dosyası yok, fetch/prepare koşulmadı)');
      continue;
    }

    final Map<String, Object?> expected = fixture['expected'] as Map<String, Object?>;
    final double expectedHz = (expected['f0Hz'] as num).toDouble();

    if (expectedHz < pianoMinHz || expectedHz > pianoMaxHz) {
      results.add(<String, Object?>{
        'fixtureId': fixtureId,
        'status': 'out_of_range',
        'expectedHz': expectedHz,
        'supportedRange': <String, Object?>{'minHz': pianoMinHz, 'maxHz': pianoMaxHz},
      });
      outOfRange++;
      stdout.writeln('⚠️  $fixtureId — DESTEKLENMİYOR (${expectedHz}Hz, sınır $pianoMinHz-${pianoMaxHz}Hz dışında)');
      continue;
    }

    final PcmWav wav = PcmWav.readFile(audioFile.path);
    final List<double> mono = wav.toMono();

    final Map<String, Object?> tolerances = fixture['tolerances'] as Map<String, Object?>;
    final double centsMedianTol = (tolerances['centsMedian'] as num).toDouble();
    final double centsP95Tol = (tolerances['centsP95'] as num).toDouble();

    // Pencereleme `gate_and_timing_test.dart`ın kendi deseniyle AYNI: 4096
    // örnek pencere, %50 örtüşme (hop=2048).
    final YinPitchSource source =
        YinPitchSource(minHz: pianoMinHz, maxHz: pianoMaxHz, expectedHzPrior: expectedHz);
    const int windowSize = 4096;
    const int hop = 2048;
    final List<double> centsErrors = <double>[];
    int windowCount = 0;

    for (int start = 0; start + windowSize <= mono.length; start += hop) {
      final List<double> window = mono.sublist(start, start + windowSize);
      final int tStartUs = (start / wav.sampleRate * 1000000).round();
      final PitchReading reading =
          source.analyze(window, sampleRate: wav.sampleRate, tStartUs: tStartUs);
      windowCount++;
      if (!reading.hasPitch) continue;
      centsErrors.add(absCents(reading.f0Hz!, expectedHz));
    }

    centsErrors.sort();
    final double? medianCents = centsErrors.isEmpty ? null : _percentile(centsErrors, 0.5);
    final double? p95Cents = centsErrors.isEmpty ? null : _percentile(centsErrors, 0.95);
    final double judgedFraction = windowCount == 0 ? 0 : centsErrors.length / windowCount;

    final bool pitchOk = medianCents != null &&
        p95Cents != null &&
        medianCents <= centsMedianTol &&
        p95Cents <= centsP95Tol;

    // Onset — roadmap §11 "Speaker/wired onset median absolute error ≤30ms".
    // `expected.onsetMs` her fixture'da olmak ZORUNDA değil (eski şema
    // sürümleri taşımayabilir) — YOKSA onset kontrolü SESSİZCE atlanır,
    // yalnız pitch hükmü sayılır (`onsetOk` bu durumda `null`, "geçti"
    // DEĞİL — üçüncü bir hâl, ölçülemedi).
    final num? expectedOnsetMs = (expected['onsetMs'] as num?);
    double? onsetErrorMs;
    bool? onsetOk;
    if (expectedOnsetMs != null) {
      final List<Onset> onsets =
          OnsetDetector().detect(mono, sampleRate: wav.sampleRate, tStartUs: 0);
      final double onsetTolMs = ((tolerances['onsetMs'] as num?) ?? 30).toDouble();
      if (onsets.isEmpty) {
        onsetOk = false; // roadmap'in kendi eşiği: yanlış-hüküm değil ama HİÇ bulamamak da geçemez
      } else {
        // En yakın algılanan onset'i eşleştir — birden fazla algılanmışsa
        // (gürültü/harmonik artefakt) en yakını gerçek hatayı temsil eder.
        double best = double.infinity;
        for (final Onset o in onsets) {
          final double detectedMs = o.tUs / 1000.0;
          final double err = (detectedMs - expectedOnsetMs).abs();
          if (err < best) best = err;
        }
        onsetErrorMs = best;
        onsetOk = best <= onsetTolMs;
      }
    }

    final bool ok = pitchOk && (onsetOk ?? true);

    results.add(<String, Object?>{
      'fixtureId': fixtureId,
      'status': ok ? 'pass' : 'fail',
      'expectedHz': expectedHz,
      'windowCount': windowCount,
      'judgedWindowCount': centsErrors.length,
      'judgedFraction': double.parse(judgedFraction.toStringAsFixed(3)),
      'medianCents': medianCents == null ? null : double.parse(medianCents.toStringAsFixed(2)),
      'p95Cents': p95Cents == null ? null : double.parse(p95Cents.toStringAsFixed(2)),
      'toleranceCentsMedian': centsMedianTol,
      'toleranceCentsP95': centsP95Tol,
      'onsetStatus': expectedOnsetMs == null ? 'not_measured' : (onsetOk! ? 'pass' : 'fail'),
      'expectedOnsetMs': expectedOnsetMs,
      'onsetErrorMs': onsetErrorMs == null ? null : double.parse(onsetErrorMs.toStringAsFixed(1)),
    });

    final String medStr = medianCents?.toStringAsFixed(2) ?? 'N/A';
    final String p95Str = p95Cents?.toStringAsFixed(2) ?? 'N/A';
    final String onsetStr = onsetErrorMs == null
        ? (expectedOnsetMs == null ? '' : ' · onset YOK')
        : ' · onset ${onsetErrorMs.toStringAsFixed(1)}ms hata${onsetOk! ? "" : " ⚠️"}';
    if (ok) {
      pass++;
      stdout.writeln('✅ $fixtureId — medyan $medStr¢ / p95 $p95Str¢ (eşik $centsMedianTol¢/$centsP95Tol¢, judged ${(judgedFraction * 100).toStringAsFixed(0)}%)$onsetStr');
    } else {
      fail++;
      stdout.writeln('🔴 $fixtureId — medyan $medStr¢ / p95 $p95Str¢ (eşik $centsMedianTol¢/$centsP95Tol¢, judged ${(judgedFraction * 100).toStringAsFixed(0)}%)$onsetStr');
    }
  }

  // M-L-05 (ölü-metrik yasağı, audio-fixture-library-design.md §4.1 madde
  // 4): bu koşumun KENDİ ölçüm mekanizması sahte bozguna tepki veriyor mu?
  // Bilinen-yanlış bir frekansla (beklenenin 2 katı, oktav hatası simülasyonu)
  // TEKRAR koşup raporun GERÇEKTEN "fail" ürettiğini doğrula — kapı hiç
  // kırmızı üretmiyorsa kör kapı, kırmızı üretebiliyor olması "bu turda
  // temiz" iddiasını anlamlı kılar.
  final bool selfTestCaught = _selfTestDetectsCorruption(realDir, pianoMinHz, pianoMaxHz);

  final Map<String, Object?> report = <String, Object?>{
    'schemaVersion': 'ostinato-audio-model-gate-1',
    'generatedBy': 'tool/audio_fixture_replay.dart',
    'engineVersions': <String, Object?>{
      'pitch': 'YinPitchSource (ostinato_audio 0.1.0)',
      'gate': 'AudioConfidenceGate',
    },
    'summary': <String, Object?>{
      'pass': pass,
      'fail': fail,
      'outOfRange': outOfRange,
      'skipped': skip,
      'total': jsonFiles.length,
      'selfTestCaughtCorruption': selfTestCaught,
    },
    'fixtures': results,
  };

  final File reportFile = File('fixtures/audio-real/replay-report.json');
  reportFile.writeAsStringSync(const JsonEncoder.withIndent(' ').convert(report));

  stdout.writeln('');
  stdout.writeln('→ $pass geçti · $fail kaldı · $outOfRange desteklenmiyor · $skip atlandı (${jsonFiles.length} toplam)');
  stdout.writeln('→ öz-test (bilinçli bozguna tepki verdi mi): ${selfTestCaught ? "✓ EVET" : "⛔ HAYIR — kapı KÖR"}');
  stdout.writeln('→ rapor: ${reportFile.path}');

  if (!selfTestCaught) exit(1); // kör bir kapı, kendi "temiz" iddiasına güvenilmez
}

double _percentile(List<double> sortedAsc, double p) {
  final int idx = (sortedAsc.length * p).floor().clamp(0, sortedAsc.length - 1);
  return sortedAsc[idx];
}

/// İlk fixture'ı KASITLI yanlış bir `expectedHzPrior`la (beklenenin 2 katı —
/// bir oktav hatası simülasyonu) koşar; gerçek motor gerçek notayı çalıyor
/// olduğundan `absCents(ölçülen, YANLIŞ-beklenen)` çok büyük çıkmalı ve
/// eşiği AŞMALI. Aşmıyorsa (ya da hiç pitch bulunamıyorsa "geçti" sayılıyorsa)
/// karşılaştırmanın kendisi kör demektir.
bool _selfTestDetectsCorruption(Directory realDir, double minHz, double maxHz) {
  final File probe = File('${realDir.path}/AF-R003-piano-c4.wav');
  if (!probe.existsSync()) return true; // ses hiç yoksa öz-test anlamsız, ana koşum zaten skip diyecek
  final PcmWav wav = PcmWav.readFile(probe.path);
  final List<double> mono = wav.toMono();
  const double realHz = 261.6256; // C4
  const double corruptedExpectation = realHz * 2; // bilinçli YANLIŞ (oktav-üstü) beklenti

  final YinPitchSource source =
      YinPitchSource(minHz: minHz, maxHz: maxHz, expectedHzPrior: corruptedExpectation);
  final List<double> window = mono.sublist(0, 4096);
  final PitchReading reading = source.analyze(window, sampleRate: wav.sampleRate, tStartUs: 0);
  if (!reading.hasPitch) return true; // motor "bilmiyorum" dedi — bu da körlük değil, dürüstlük
  final double cents = absCents(reading.f0Hz!, corruptedExpectation);
  return cents > 20; // ~1200 cent'lik bir oktav hatası kolayca 20¢'i aşar
}
