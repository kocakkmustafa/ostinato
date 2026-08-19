// dart run tool/prepare_audio_fixtures.dart
//
// Doğrulanmış ham AIFF'lerden (tool/fetch_audio_fixtures.sh) KÜÇÜK, mono,
// kırpılmış fixture WAV'ları + eşlik eden JSON kontratlarını türetir.
//
// Bu adımın SHA-256 PİNİ YOK (kasıtlı, `tool/fetch_audio_fixtures.sh` dosya-
// başı notuna bkz.): girdi zaten doğrulanmış, dönüşüm bu makinenin
// `afconvert`ine bağlı deterministik bir yerel adım — üçüncü-taraf sabit
// bir kaynak DEĞİL, pinlemek yanlış bir kesinlik iddiası olurdu.
//
// f0Hz değerleri ELLE YAZILMADI — 12-TET formülünden türetildi (aşağıda),
// `library_starters_test.dart`ın "beklenen değerler repo'dan türer" deseniyle
// aynı disiplin: nota adı yanlış yazılırsa formül de yanlış sayı üretir,
// tutarsız bir "doğru görünen" sabit asla oluşmaz.

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'audio_fixture_io.dart';

// A6/C7/A7/B7 (2026-08-19, O-184): C8'in kök-nedeni (O-177) TEŞHİS edildi ama
// tek data noktasına göre yin.dart eşiğini ayarlamak ilkesiz sayılıp ERTELENDİ
// (O-178/O-182/O-183 boyunca tekrarlanan disiplin) — bu 4 nota C6(geçti)-
// C8(kaldı) arasına ara veri noktaları katar, tek başarısızlığa göre fit
// yerine bir EĞİLİM görmeyi mümkün kılar. SONA eklendi (frekans sırasına
// göre ARAYA değil) — ilk 6 notanın fixtureId'si (AF-R001..006, DEFTER
// O-176'dan beri referanslı) DEĞİŞMEDEN kalsın diye.
const List<String> _notes = ['A1', 'C3', 'C4', 'A4', 'C6', 'C8', 'A6', 'C7', 'A7', 'B7'];

/// 12-TET, A4=440Hz. `octave+1) * 12 + semitoneInOctave` MIDI-uyumlu mutlak
/// yarım-ton sayısıdır (C4=60, A4=69) — hangi "C=60 mı C=48 mi" tartışmasına
/// girmeden A4=69'un KENDİSİ evrensel sabit, geri kalanı ona görecelidir.
/// Gerçek onset zamanını RMS zarfından ÖLÇER — Iowa MIS kayıtlarının HİÇBİRİ
/// t=0'da başlamıyor (ölçüldü: ilk 6 fixture'ın 6'sında da 167-560ms
/// SESSİZLİK/pre-roll var, `dart run tool/diag_onset.dart` tek-seferlik
/// teşhisiyle bulundu — trim adımının "onset t=0'da" varsayımı YANLIŞTI).
/// Eşik `-40dBFS` (RMS-kare `0.0001`) — bu turda ölçülen sessizlik GERÇEKTEN
/// dijital sıfırdı (stüdyo kaydı, taban gürültüsü yok), o yüzden mutlak bir
/// eşik burada göreli bir eşikten (`AudioConfidenceGate`in `roomFloorDb`
/// yaklaşımı) daha BASİT ve aynı derecede doğru — ikisi ayrı sınıf sorun.
double? measureOnsetMs(List<double> samples, {required int sampleRate}) {
  const int windowSamples = 441; // 10ms @ 44100Hz
  const double thresholdRmsSquared = 0.0001;
  for (int start = 0; start + windowSamples <= samples.length; start += windowSamples) {
    double sumSq = 0;
    for (int i = start; i < start + windowSamples; i++) {
      sumSq += samples[i] * samples[i];
    }
    if (sumSq / windowSamples > thresholdRmsSquared) {
      return start / sampleRate * 1000.0;
    }
  }
  return null; // hiç eşik-üstü pencere yok — bu fixture için onset ÖLÇÜLEMEDİ
}

double frequencyForNote(String name) {
  final RegExpMatch? m = RegExp(r'^([A-G])(#?)(-?\d+)$').firstMatch(name);
  if (m == null) throw FormatException('nota adı çözülemedi: $name');
  const Map<String, int> semitoneFromC = {
    'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11,
  };
  final int semitoneInOctave = semitoneFromC[m.group(1)]! + (m.group(2) == '#' ? 1 : 0);
  final int octave = int.parse(m.group(3)!);
  final int absoluteSemitone = (octave + 1) * 12 + semitoneInOctave;
  const int a4Semitone = 69;
  return 440.0 * math.pow(2, (absoluteSemitone - a4Semitone) / 12.0);
}

void main() {
  final Directory rawDir = Directory('fixtures/audio-real/raw');
  if (!rawDir.existsSync()) {
    stderr.writeln('⛔ ${rawDir.path} yok — önce: bash tool/fetch_audio_fixtures.sh');
    exit(1);
  }

  const int sampleRate = 44100;
  const int trimSeconds = 3;
  const int trimSamples = sampleRate * trimSeconds;

  int prepared = 0;
  for (final String note in _notes) {
    final String aiffPath = '${rawDir.path}/Piano.mf.$note.aiff';
    if (!File(aiffPath).existsSync()) {
      stderr.writeln('⛔ $aiffPath yok — atlanıyor (fetch script tam koşmadı mı?)');
      continue;
    }

    final String monoWavPath = '${rawDir.path}/Piano.mf.$note.mono.wav';
    final ProcessResult conv = Process.runSync('afconvert', [
      '-f', 'WAVE',
      '-d', 'LEI16@$sampleRate',
      '-c', '1',
      aiffPath,
      monoWavPath,
    ]);
    if (conv.exitCode != 0) {
      stderr.writeln('⛔ afconvert başarısız ($note): ${conv.stderr}');
      exit(1);
    }

    final PcmWav full = PcmWav.readFile(monoWavPath);
    if (full.sampleRate != sampleRate) {
      throw StateError('$note: beklenmeyen sample rate ${full.sampleRate} (afconvert $sampleRate istendi)');
    }
    // M-C-07 (audio-fixture-library-design.md §4.1): sonda ≥0,5sn sönüş
    // payı — piyano notası saldırı ANINDAN itibaren sürekli söner, 3sn'lik
    // pencerenin SON kısmı zaten çürüyor (ayrı bir "release" adımı gerekmez).
    final int take = math.min(trimSamples, full.samples.length);
    final List<double> trimmed = full.samples.sublist(0, take);

    final String fixtureId = 'AF-R${(_notes.indexOf(note) + 1).toString().padLeft(3, '0')}-piano-${note.toLowerCase()}';
    final String wavName = '$fixtureId.wav';
    PcmWav.writeMonoFile('fixtures/audio-real/$wavName', sampleRate: sampleRate, samples: trimmed);

    final double f0 = frequencyForNote(note);
    final double? onsetMs = measureOnsetMs(trimmed, sampleRate: sampleRate);
    final Map<String, Object?> fixture = {
      'schemaVersion': 'ostinato-audiofix-1',
      'fixtureId': fixtureId,
      'kind': 'real-clean',
      'audio': wavName,
      '\$what': 'Real Iowa MIS piano note ($note, mf dynamic), trimmed to ${trimSeconds}s from onset.',
      'recordingMeta': {
        'source': 'iowa-mis-piano',
        'device': 'Steinway (Iowa Electronic Music Studios recording rig)',
        'room': 'Iowa EMS recording room',
        'micDistanceM': null,
        'sampleRate': sampleRate,
        'license': 'Iowa-without-restriction',
        '\$licenseNote': 'University of Iowa Electronic Music Studios — "without restriction" per '
            'the institution\'s own page, verified 2026-08-18 (docs/research/'
            '2026-08-18-w1-audio-golden-fixture-kaynaklari.md). Source AIFF SHA-256 pinned in '
            'tool/fetch_audio_fixtures.sh.',
        'sourceUrl': 'https://theremin.music.uiowa.edu/MISpiano.html',
      },
      'expected': {
        'f0Hz': double.parse(f0.toStringAsFixed(4)),
        '\$f0Derivation': '12-TET, A4=440Hz, derived from note name "$note" — not hand-typed '
            '(see frequencyForNote() in tool/prepare_audio_fixtures.dart).',
        'shouldJudge': true,
        'onsetMs': onsetMs == null ? null : double.parse(onsetMs.toStringAsFixed(1)),
        '\$onsetDerivation': 'Measured, not assumed: first 10ms RMS-power window exceeding '
            '-40dBFS in this recording (measureOnsetMs() in this file). Iowa MIS recordings do '
            'NOT start at the note attack — every one of these 6 fixtures has 167-560ms of '
            'leading silence, found by direct measurement, not documented anywhere upstream.',
      },
      // Roadmap §11: "Monophonic pitch median absolute error ≤10 cent, p90 ≤20 cent" +
      // "Speaker/wired onset median absolute error ≤30 ms".
      // M-C-06 (audio-fixture-library-design.md §4.1): fixture sapması test
      // ettiği bandın ≥1,5 katı olmalı ki test anlamlı olsun — bu GERÇEK bir
      // piyano kaydı, sentetik değil; motorun GERÇEKTEN kaç cent/ms saptığı
      // BİLİNMİYOR (bu yüzden bu fixture var), o yüzden burada roadmap'in
      // KENDİ kabul eşiği kullanılıyor, sahte-sıkı bir sayı İCAT edilmiyor.
      'tolerances': {'centsMedian': 10, 'centsP95': 20, 'onsetMs': 30},
      'labels': {'annotator': 'derived-from-note-name+measured-envelope', 'confidence': 'high'},
    };
    File('fixtures/audio-real/$fixtureId.json')
        .writeAsStringSync(const JsonEncoder.withIndent(' ').convert(fixture));
    stdout.writeln('✓ $fixtureId  ($note → ${f0.toStringAsFixed(2)}Hz, ${trimmed.length} örnek)');
    prepared++;
  }

  stdout.writeln('→ $prepared/${_notes.length} gerçek fixture hazır: fixtures/audio-real/');
}
