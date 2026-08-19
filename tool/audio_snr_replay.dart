// dart run tool/audio_snr_replay.dart
//
// OST-P0-003 Step 1 (SNR dimension) — roadmap §7 "Noise floor yüksekse
// pitch/chord hükmü yok" + §11 "Noise/unsupported input false verdict ≤%1".
//
// Yeni fixture/indirme YOK: mevcut GERÇEK piyano kayıtlarına (C4, A4 — C8
// hariç, onun pitch açığı zaten O-177'de teşhisli, SNR bulgusunu bulandırırdı)
// `SyntheticTone.roomNoise()` KONTROLLÜ seviyede karıştırılır (3 SNR: temiz/
// orta/sert), `AudioConfidenceGate`in GERÇEK sinyal + BİLİNEN gürültü
// tabanıyla doğru davranıp davranmadığı ölçülür — hem doğruluk (judged
// pencerelerde hata) hem de DAVRANIŞ (gürültü arttıkça hüküm-verme oranı
// düşüyor mu, "false verdict" oranı düşük kalıyor mu).

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:ostinato_audio/ostinato_audio.dart';

import 'audio_fixture_io.dart';

const List<String> _probeFixtures = ['AF-R003-piano-c4', 'AF-R004-piano-a4'];
const List<double> _targetSnrDb = [30, 15, 3]; // temiz · orta · sert
const double _pianoMinHz = 25.0;
const double _pianoMaxHz = 4200.0;

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

void main() {
  final realDir = Directory('fixtures/audio-real');
  final results = <Map<String, Object?>>[];

  for (final fixtureId in _probeFixtures) {
    final jsonFile = File('${realDir.path}/$fixtureId.json');
    final wavFile = File('${realDir.path}/$fixtureId.wav');
    if (!jsonFile.existsSync() || !wavFile.existsSync()) {
      stdout.writeln('⏭  $fixtureId — SKIP (fixture bulunamadı, fetch/prepare koşulmadı)');
      continue;
    }
    final fixture = jsonDecode(jsonFile.readAsStringSync()) as Map<String, Object?>;
    final expected = fixture['expected'] as Map<String, Object?>;
    final expectedHz = (expected['f0Hz'] as num).toDouble();
    final onsetMs = (expected['onsetMs'] as num?)?.toDouble();

    final wav = PcmWav.readFile(wavFile.path);
    final mono = wav.toMono();

    // Sinyalin KENDİ RMS'i — yalnız çalınan bölge (onset sonrası +50ms'den
    // itibaren), sessizlik payını dışarıda BIRAKARAK doğru SNR hesabı.
    final playStart = onsetMs == null ? 0 : ((onsetMs + 50) / 1000 * wav.sampleRate).round();
    final signalOnly = mono.sublist(math.min(playStart, mono.length - 1));
    final signalRmsDbfs = _rmsDbfs(signalOnly);

    for (final targetSnr in _targetSnrDb) {
      final targetNoiseDbfs = signalRmsDbfs - targetSnr;
      final targetNoiseRms = math.pow(10, targetNoiseDbfs / 20).toDouble();
      // roomNoise() genliği tekdüze [-a,a] rastgele üretir; RMS'i a/sqrt(3) —
      // istenen RMS'e ulaşmak için genliği TERSİNE çöz.
      final noiseAmplitude = targetNoiseRms * math.sqrt(3);
      final noise = SyntheticTone.roomNoise(
        sampleRate: wav.sampleRate,
        seconds: mono.length / wav.sampleRate,
        amplitude: noiseAmplitude,
        seed: targetSnr.round(), // her SNR farklı ama TEKRARLANABİLİR gürültü
      );
      final mixed = List<double>.generate(
        mono.length, (i) => (mono[i] + noise[i]).clamp(-1.0, 1.0));
      final measuredNoiseDbfs = _rmsDbfs(noise);

      final source =
          YinPitchSource(minHz: _pianoMinHz, maxHz: _pianoMaxHz, expectedHzPrior: expectedHz);
      const gate = AudioConfidenceGate();
      const windowSize = 4096, hop = 2048;
      int total = 0, judged = 0, wrongWhileJudged = 0;
      final judgedCentsErrors = <double>[];

      for (int start = 0; start + windowSize <= mixed.length; start += hop) {
        final window = mixed.sublist(start, start + windowSize);
        final tStartUs = (start / wav.sampleRate * 1000000).round();
        final reading = source.analyze(window, sampleRate: wav.sampleRate, tStartUs: tStartUs);
        total++;
        final verdict = gate.evaluate(reading,
            roomFloorDb: measuredNoiseDbfs, expectedHz: expectedHz);
        if (verdict.mayJudge) {
          judged++;
          final err = absCents(reading.f0Hz!, expectedHz);
          judgedCentsErrors.add(err);
          // roadmap §11 "false verdict" — kapı "yargılanabilir" dediği bir
          // pencerede motor YANLIŞ bir nota raporlarsa bu SESSİZCE yanlış bir
          // özgüven olurdu; >50 cent (yarım yarım-ton) AÇIKÇA farklı nota.
          if (err > 50) wrongWhileJudged++;
        }
      }

      judgedCentsErrors.sort();
      final medianCents = judgedCentsErrors.isEmpty
          ? null
          : judgedCentsErrors[judgedCentsErrors.length ~/ 2];
      final falseVerdictRate = judged == 0 ? 0.0 : wrongWhileJudged / judged;

      results.add(<String, Object?>{
        'fixtureId': fixtureId,
        'targetSnrDb': targetSnr,
        'measuredNoiseDbfs': double.parse(measuredNoiseDbfs.toStringAsFixed(1)),
        'signalRmsDbfs': double.parse(signalRmsDbfs.toStringAsFixed(1)),
        'totalWindows': total,
        'judgedWindows': judged,
        'judgedFraction': double.parse((total == 0 ? 0 : judged / total).toStringAsFixed(3)),
        'medianCentsWhenJudged': medianCents == null ? null : double.parse(medianCents.toStringAsFixed(2)),
        'falseVerdictRate': double.parse(falseVerdictRate.toStringAsFixed(3)),
      });

      stdout.writeln('$fixtureId @ SNR ${targetSnr}dB — judged ${(judged / math.max(total,1) * 100).toStringAsFixed(0)}% '
          '· medyan-hata-judged ${medianCents?.toStringAsFixed(1) ?? "N/A"}¢ '
          '· YANLIŞ-İKEN-YARGILANDI $wrongWhileJudged/$judged (${(falseVerdictRate * 100).toStringAsFixed(1)}%)');
    }
  }

  // M-L-05 (ölü-metrik yasağı): bu ölçümün "gürültü arttıkça judged düşer"
  // bulgusu bir tesadüf mü yoksa gate GERÇEKTEN reddedebiliyor mu? Aşırı
  // olumsuz SNR'da (-20dB, gürültü sinyalden 10× GÜÇLÜ) judged oranı neredeyse
  // sıfıra inmeli — inmiyorsa ölçümün "judged düşüyor" bulgusu güvenilmez.
  bool selfTestPassed = true;
  final probeFile = File('${realDir.path}/AF-R003-piano-c4.wav');
  if (probeFile.existsSync()) {
    final wav = PcmWav.readFile(probeFile.path);
    final mono = wav.toMono();
    final noise = SyntheticTone.roomNoise(
        sampleRate: wav.sampleRate, seconds: mono.length / wav.sampleRate, amplitude: 0.9, seed: 99);
    final mixed = List<double>.generate(mono.length, (i) => (mono[i] + noise[i]).clamp(-1.0, 1.0));
    final source = YinPitchSource(minHz: _pianoMinHz, maxHz: _pianoMaxHz);
    const gate = AudioConfidenceGate();
    final noiseFloor = _rmsDbfs(noise);
    int judgedUnderExtremeNoise = 0, totalUnderExtremeNoise = 0;
    for (int start = 0; start + 4096 <= mixed.length; start += 2048) {
      totalUnderExtremeNoise++;
      final reading = source.analyze(mixed.sublist(start, start + 4096),
          sampleRate: wav.sampleRate, tStartUs: 0);
      if (gate.evaluate(reading, roomFloorDb: noiseFloor).mayJudge) judgedUnderExtremeNoise++;
    }
    final extremeFraction = judgedUnderExtremeNoise / math.max(totalUnderExtremeNoise, 1);
    selfTestPassed = extremeFraction < 0.05;
    stdout.writeln('\nöz-test (aşırı gürültüde gate GERÇEKTEN reddediyor mu): '
        '${(extremeFraction * 100).toStringAsFixed(1)}% judged '
        '${selfTestPassed ? "✓ (beklenen <%5)" : "⛔ ÇOK YÜKSEK — gate kör olabilir"}');
  }

  final report = <String, Object?>{
    'schemaVersion': 'ostinato-audio-snr-gate-1',
    'generatedBy': 'tool/audio_snr_replay.dart',
    '\$method': 'Real piano fixture + SyntheticTone.roomNoise() mixed at a target SNR (computed '
        'from the ACTUAL measured signal RMS during the playing region, not the whole file). '
        'roomFloorDb passed to AudioConfidenceGate is the injected noise\'s own measured dBFS — '
        'not assumed, not the target value (target vs achieved can differ slightly due to '
        'roomNoise()\'s uniform-random amplitude formula).',
    'acceptanceReference': 'roadmap §11: false verdict rate ≤1% (measured here as wrongWhileJudged/judged)',
    'selfTest': <String, Object?>{
      'method': 'extreme-negative-SNR probe (noise amplitude 0.9, far louder than the real signal)',
      'passed': selfTestPassed,
      '\$why': 'M-L-05 — proves the gate CAN reject under noise, not just happened to on these 6 samples',
    },
    'results': results,
  };
  File('fixtures/audio-real/snr-report.json')
      .writeAsStringSync(const JsonEncoder.withIndent(' ').convert(report));
  stdout.writeln('\n→ rapor: fixtures/audio-real/snr-report.json');
  if (!selfTestPassed) exit(1); // öz-test düşerse rapor GÜVENİLMEZ
}
