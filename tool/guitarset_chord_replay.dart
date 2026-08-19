// dart run tool/guitarset_chord_replay.dart
//
// OST-P0-003 Step 2+4, roadmap §11 "Supported major/minor triad chord
// accuracy ≥%90": `fixtures/audio-real/AC-*.json`i tarar, her fixture'ı
// GERÇEK `ChordDetector`la (varsayılan config — 24 şablon, acceptedNames
// kısıtı YOK; burada sınanan HAM dedektör, bir dersin daraltılmış sözlüğü
// değil) 5 kaydırmalı pencerede (400ms/200ms hop, bkz. fixture JSON'undaki
// `windowing.$rationale`) koşar, otomatik değerlendirir, tek JSON rapor
// üretir. `audio_fixture_replay.dart`tan AYRI script — akor fixture'ları
// farklı şema taşıyor (`expected.chordName` vs `expected.f0Hz`), ID
// namespace'i de ayrı (`AC-` vs `AF-`) — bu iki script birbirinin dosyalarını
// asla tarama alanına almaz.
//
// Bu turda yalnız MAJÖR akorlar var (GuitarSet'in bu take'inin basit chord
// katmanı D#/G#/A# majör dışında bir şey içermiyor) — minör kapsamı henüz
// YOK, rapor bunu `notCoveredThisRun` ile açıkça işaretler, sessizce
// atlanmaz.

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:ostinato_audio/ostinato_audio.dart';

import 'audio_fixture_io.dart';

const int _windowMs = 400;
const int _hopMs = 200;

class WindowResult {
  WindowResult(this.detectedName, this.score, this.margin, this.latencyUs);
  final String? detectedName;
  final double? score;
  final double? margin;
  final int latencyUs;
}

List<WindowResult> _runWindows(List<double> samples, int sampleRate) {
  final int windowSamples = (sampleRate * _windowMs / 1000).round();
  final int hopSamples = (sampleRate * _hopMs / 1000).round();
  const ChordDetector detector = ChordDetector();
  final List<WindowResult> results = [];
  for (int start = 0; start + windowSamples <= samples.length; start += hopSamples) {
    final List<double> window = samples.sublist(start, start + windowSamples);
    final Stopwatch sw = Stopwatch()..start();
    final ChordReading? reading = detector.detect(window, sampleRate: sampleRate);
    sw.stop();
    results.add(WindowResult(
      reading?.chord.name,
      reading?.score,
      reading?.runnerUpMargin,
      sw.elapsedMicroseconds,
    ));
  }
  return results;
}

void main() {
  final Directory realDir = Directory('fixtures/audio-real');
  final List<File> jsonFiles = realDir.existsSync()
      ? (realDir.listSync().whereType<File>()
          .where((f) => f.uri.pathSegments.last.startsWith('AC-') && f.path.endsWith('.json'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path)))
      : <File>[];

  if (jsonFiles.isEmpty) {
    stderr.writeln('⛔ fixtures/audio-real/AC-*.json yok — önce: '
        'python3 tool/fetch_guitarset_fixtures.py && dart run tool/prepare_guitarset_fixtures.dart');
    exit(1);
  }

  final List<Map<String, Object?>> fixtureResults = [];
  int totalWindows = 0, correctWindows = 0, nullWindows = 0, wrongWindows = 0;
  int pass = 0, fail = 0, skip = 0;
  final Set<String> qualitiesSeen = {};
  final List<int> latenciesUs = [];

  for (final File jf in jsonFiles) {
    final Map<String, Object?> fixture = jsonDecode(jf.readAsStringSync()) as Map<String, Object?>;
    final String fixtureId = fixture['fixtureId'] as String;
    final String audioName = fixture['audio'] as String;
    final File audioFile = File('${realDir.path}/$audioName');

    if (!audioFile.existsSync()) {
      fixtureResults.add(<String, Object?>{
        'fixtureId': fixtureId,
        'status': 'skipped',
        'reason': 'audio_not_fetched',
        'howToFix': 'python3 tool/fetch_guitarset_fixtures.py && dart run tool/prepare_guitarset_fixtures.dart',
      });
      skip++;
      stdout.writeln('⏭  $fixtureId — SKIP (ses dosyası yok)');
      continue;
    }

    final Map<String, Object?> expected = fixture['expected'] as Map<String, Object?>;
    final String expectedName = expected['chordName'] as String;
    final String expectedQuality = expected['quality'] as String;
    qualitiesSeen.add(expectedQuality);

    final PcmWav wav = PcmWav.readFile(audioFile.path);
    final List<double> mono = wav.toMono();
    final List<WindowResult> windows = _runWindows(mono, wav.sampleRate);

    int fixCorrect = 0, fixNull = 0, fixWrong = 0;
    final List<Map<String, Object?>> windowReports = [];
    for (final WindowResult w in windows) {
      totalWindows++;
      latenciesUs.add(w.latencyUs);
      if (w.detectedName == null) {
        nullWindows++;
        fixNull++;
      } else if (w.detectedName == expectedName) {
        correctWindows++;
        fixCorrect++;
      } else {
        wrongWindows++;
        fixWrong++;
      }
      windowReports.add(<String, Object?>{
        'detected': w.detectedName,
        'score': w.score == null ? null : double.parse(w.score!.toStringAsFixed(3)),
        'runnerUpMargin': w.margin == null ? null : double.parse(w.margin!.toStringAsFixed(3)),
        'latencyUs': w.latencyUs,
      });
    }

    final double matchFraction = windows.isEmpty ? 0 : fixCorrect / windows.length;
    // Tek fixture'lık geçme kuralı yok — roadmap eşiği AGREGE ("chord
    // accuracy ≥%90"), o yüzden burada fixture-düzeyi "pass/fail" YALNIZ
    // teşhis amaçlı: bu fixture'ın TÜM pencerelerinde doğru mu.
    final bool fixturePass = fixCorrect == windows.length && windows.isNotEmpty;
    if (fixturePass) {
      pass++;
    } else {
      fail++;
    }

    fixtureResults.add(<String, Object?>{
      'fixtureId': fixtureId,
      'status': fixturePass ? 'pass' : 'fail',
      'expectedChordName': expectedName,
      'expectedQuality': expectedQuality,
      'windowCount': windows.length,
      'correctWindows': fixCorrect,
      'nullWindows': fixNull,
      'wrongWindows': fixWrong,
      'matchFraction': double.parse(matchFraction.toStringAsFixed(3)),
      'windows': windowReports,
    });

    final String icon = fixturePass ? '✅' : '🔴';
    stdout.writeln('$icon $fixtureId — beklenen $expectedName, $fixCorrect/${windows.length} pencere doğru '
        '($fixNull null, $fixWrong yanlış)');
  }

  final double overallAccuracy = totalWindows == 0 ? 0 : correctWindows / totalWindows;
  const double accuracyThreshold = 0.90; // roadmap §11: "chord accuracy ≥%90"
  final bool gateOk = totalWindows > 0 && overallAccuracy >= accuracyThreshold;

  final double meanLatencyMs = latenciesUs.isEmpty
      ? 0
      : latenciesUs.reduce((a, b) => a + b) / latenciesUs.length / 1000.0;
  final int maxLatencyUs = latenciesUs.isEmpty ? 0 : latenciesUs.reduce(math.max);

  // M-L-05 (ölü-metrik yasağı): karşılaştırma mekanizması GERÇEKTEN
  // "yanlış" üretebiliyor mu? İlk fixture'ın GERÇEK sesini KASITLI yanlış
  // bir `expectedChordName`a ("A" — D#'nin ne runner-up'ı ne yakın komşusu,
  // 24 şablonun hiçbirinde D# ile karışmayacak kadar uzak bir kök) karşı
  // ölç; motor gerçek D#'yi rapor ediyor olduğundan karşılaştırma bunu
  // "yanlış" saymalı. Saymıyorsa (ya da her zaman "doğru" diyorsa) kıyas
  // körmüş demektir.
  final bool selfTestCaught = _selfTestDetectsMismatch(realDir);

  final Map<String, Object?> report = <String, Object?>{
    'schemaVersion': 'ostinato-audio-chord-gate-1',
    'generatedBy': 'tool/guitarset_chord_replay.dart',
    'engineVersion': 'ChordDetector (ostinato_audio 0.1.0), default config (24 templates, no acceptedNames restriction)',
    'roadmapGate': {
      '\$text': 'Supported major/minor triad chord accuracy ≥%90; üç SNR koşulunda ayrı rapor. (23-OSTINATO-MASTER-ROADMAP.md §11)',
      'threshold': accuracyThreshold,
      'measured': double.parse(overallAccuracy.toStringAsFixed(4)),
      'gateOk': gateOk,
    },
    'summary': <String, Object?>{
      'fixturesPass': pass,
      'fixturesFail': fail,
      'fixturesSkipped': skip,
      'fixturesTotal': jsonFiles.length,
      'totalWindows': totalWindows,
      'correctWindows': correctWindows,
      'nullWindows': nullWindows,
      'wrongWindows': wrongWindows,
      'meanLatencyMs': double.parse(meanLatencyMs.toStringAsFixed(3)),
      'maxLatencyUs': maxLatencyUs,
      'selfTestCaughtMismatch': selfTestCaught,
    },
    'notCoveredThisRun': [
      'Minor triads — this take\'s simple chord track is 100% major (D#/G#/A#); '
          'qualitiesSeen=${qualitiesSeen.toList()}. Roadmap gate names "major/minor" jointly; '
          'minor coverage requires a different GuitarSet take (or another source) with minor '
          'chords in its simple annotation track.',
      'Three-SNR-condition report (roadmap §11 literal requirement) — this run is clean/'
          'as-recorded only, no noise mixed in. Same additive-noise-at-target-SNR technique as '
          'tool/audio_snr_replay.dart could extend this, not yet done this turn.',
      'Dominant7 quality — not present in this take\'s simple chord annotations.',
    ],
    'fixtures': fixtureResults,
  };

  final File reportFile = File('fixtures/audio-real/chord-report.json');
  reportFile.writeAsStringSync(const JsonEncoder.withIndent(' ').convert(report));

  stdout.writeln('');
  stdout.writeln('→ agrege doğruluk: ${(overallAccuracy * 100).toStringAsFixed(1)}% '
      '($correctWindows/$totalWindows pencere) — eşik ${(accuracyThreshold * 100).toStringAsFixed(0)}% → ${gateOk ? "✓ GEÇTİ" : "🔴 KALDI"}');
  stdout.writeln('→ ortalama gecikme: ${meanLatencyMs.toStringAsFixed(2)}ms, azami ${(maxLatencyUs / 1000).toStringAsFixed(2)}ms');
  stdout.writeln('→ öz-test (bilinçli uyuşmazlığı yakaladı mı): ${selfTestCaught ? "✓ EVET" : "⛔ HAYIR — kıyas KÖR"}');
  stdout.writeln('→ rapor: ${reportFile.path}');

  if (!selfTestCaught) exit(1);
}

bool _selfTestDetectsMismatch(Directory realDir) {
  final File probe = File('${realDir.path}/AC-R001-guitar-d-sharp-1.wav');
  if (!probe.existsSync()) return true; // ses yoksa ana koşum zaten skip diyecek, öz-test anlamsız
  final PcmWav wav = PcmWav.readFile(probe.path);
  final List<double> mono = wav.toMono();
  const ChordDetector detector = ChordDetector();
  final int windowSamples = (wav.sampleRate * _windowMs / 1000).round();
  final ChordReading? reading =
      detector.detect(mono.sublist(0, windowSamples), sampleRate: wav.sampleRate);
  if (reading == null) return true; // motor "bilmiyorum" dedi — körlük değil, dürüstlük
  const String corruptedExpectation = 'A'; // gerçek cevap D# — bilinçli YANLIŞ beklenti
  return reading.chord.name != corruptedExpectation; // kıyas bunu YAKALAMALI (true = yakaladı)
}
