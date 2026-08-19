// dart run tool/prepare_guitarset_fixtures.dart
//
// Doğrulanmış ham GuitarSet WAV+JAMS'tan (tool/fetch_guitarset_fixtures.py)
// KÜÇÜK akor-fixture WAV'ları + eşlik eden JSON kontratlarını türetir.
//
// JAMS'ın İKİ 'chord' namespace'i taşıdığı DOĞRUDAN gözlemlendi (2026-08-19,
// bu dosyanın hazırlığı sırasında): biri yalın üçlü ('D#:maj'), diğeri
// voicing/inversion'lı ('D#:sus2(7)/1' — her olayda '/' içeriyor). Ostinato'nun
// ChordDetector'ı yalnız {major, minor, dominant7} biliyor (bkz.
// packages/ostinato_audio/lib/src/harmony/chord_detector.dart) — uzatma/
// inversion YOK. Detaylı katmana karşı sınamak dedektörün HİÇ cevaplamaya
// çalışmadığı bir soruyu sormak olurdu (kategori hatası); bu yüzden seçim
// index'e göre DEĞİL, yapısal işarete göre: '/' içeren HİÇBİR değeri olmayan
// namespace = basit katman.
//
// Kırpma penceresi: her akor segmentinin başından +300ms (saldırı/önceki-akor
// sızıntısını atlamak için) başlayıp 1200ms süren tek bir pencere.
// ChromaAnalyzer.minWindowMs=200 (chroma.dart) — 1200ms bunun 6 katı, üstelik
// en kısa segment (1860ms, bkz. aşağıdaki ölçüm) içinde +300ms payla dahi
// rahatça sığıyor. Sabit bir kural TÜM olaylara uygulanıyor — elle segment
// başı ayarlanmadı.

import 'dart:convert';
import 'dart:io';

import 'audio_fixture_io.dart';

const String _sourceWav = 'fixtures/audio-real/raw/guitarset_00_BN1-129-Eb_comp_mic.wav';
const String _sourceJams = 'fixtures/audio-real/raw/guitarset_00_BN1-129-Eb_comp.jams';
const double _clipOffsetS = 0.3;
const double _clipDurationS = 1.2;

/// JAMS bazı dosyalarda bemol (Eb, Bb, Ab...) yazabilir — bu dosyada
/// GÖRÜLMEDİ (D#/G#/A#, hepsi zaten diyez) ama fonksiyon başka GuitarSet
/// dosyaları için de doğru çalışsın diye enharmonik normalize ediyor.
/// Chromagram.pitchClassNames (chroma.dart) yalnız diyez kullanıyor.
const Map<String, String> _flatToSharp = {
  'Db': 'C#', 'Eb': 'D#', 'Gb': 'F#', 'Ab': 'G#', 'Bb': 'A#',
};

String _normalizeRoot(String root) => _flatToSharp[root] ?? root;

String _rootSlug(String root) => root.replaceAll('#', '-sharp').toLowerCase();

class ChordEvent {
  ChordEvent(this.timeS, this.durationS, this.root, this.quality);
  final double timeS;
  final double durationS;
  final String root;
  final String quality; // 'major' | 'minor' | 'dominant7'
}

/// GuitarSet'in iki 'chord' namespace'inden BASİT olanını seçer — yapısal
/// işaretle (hiçbir değeri '/' içermiyor), sabit index'e GÜVENMEDEN.
List<Map<String, Object?>> _pickSimpleChordNamespace(Map<String, Object?> jams) {
  final List<Object?> annotations = jams['annotations'] as List<Object?>;
  final List<List<Map<String, Object?>>> chordNamespaces = [];
  for (final Object? a in annotations) {
    final Map<String, Object?> ann = a as Map<String, Object?>;
    if (ann['namespace'] != 'chord') continue;
    final List<Object?> data = ann['data'] as List<Object?>;
    chordNamespaces.add(data.cast<Map<String, Object?>>());
  }
  for (final List<Map<String, Object?>> ns in chordNamespaces) {
    final bool anySlash = ns.any((e) => (e['value'] as String).contains('/'));
    if (!anySlash) return ns;
  }
  throw StateError(
      'JAMS içinde "/" taşımayan (basit) bir chord namespace bulunamadı — '
      '${chordNamespaces.length} chord namespace tarandı, hepsi voicing/inversion içeriyor.');
}

/// "D#:maj" → ChordEvent(root: "D#", quality: "major"). Yalnız Ostinato'nun
/// bildiği 3 kalite kabul edilir (major/minor/dominant7); başka biri
/// gelirse (bu dosyada YOK) sessizce atlamak yerine null döner — çağıran
/// bunu açıkça loglar.
ChordEvent? _parseChordEvent(Map<String, Object?> raw) {
  final double time = (raw['time'] as num).toDouble();
  final double duration = (raw['duration'] as num).toDouble();
  final String value = raw['value'] as String;
  if (value == 'N' || value == 'X') return null; // JAMS "no chord"/"unknown" işaretleri
  final List<String> parts = value.split(':');
  if (parts.length != 2) return null;
  final String root = _normalizeRoot(parts[0]);
  const Map<String, String> qualityMap = {'maj': 'major', 'min': 'minor', '7': 'dominant7'};
  final String? quality = qualityMap[parts[1]];
  if (quality == null) return null;
  return ChordEvent(time, duration, root, quality);
}

void main() {
  final File wavFile = File(_sourceWav);
  final File jamsFile = File(_sourceJams);
  if (!wavFile.existsSync() || !jamsFile.existsSync()) {
    stderr.writeln('⛔ ham GuitarSet dosyaları yok — önce: python3 tool/fetch_guitarset_fixtures.py');
    exit(1);
  }

  final PcmWav wav = PcmWav.readFile(wavFile.path);
  final Map<String, Object?> jams = jsonDecode(jamsFile.readAsStringSync()) as Map<String, Object?>;
  final List<Map<String, Object?>> simpleChordData = _pickSimpleChordNamespace(jams);

  final List<ChordEvent> events = [];
  for (final Map<String, Object?> raw in simpleChordData) {
    final ChordEvent? ev = _parseChordEvent(raw);
    if (ev == null) {
      stdout.writeln('⏭  JAMS olayı atlandı (desteklenmeyen/boş değer): ${raw['value']}');
      continue;
    }
    events.add(ev);
  }

  final Map<String, int> instanceCounter = {};
  int prepared = 0;
  for (final ChordEvent ev in events) {
    if (ev.durationS < _clipOffsetS + _clipDurationS) {
      stdout.writeln(
          '⏭  ${ev.root}:${ev.quality} @ ${ev.timeS.toStringAsFixed(3)}s atlandı — segment '
          '${ev.durationS.toStringAsFixed(3)}s, gereken ${(_clipOffsetS + _clipDurationS).toStringAsFixed(1)}s\'den kısa.');
      continue;
    }
    final int startSample = ((ev.timeS + _clipOffsetS) * wav.sampleRate).round();
    final int clipSamples = (_clipDurationS * wav.sampleRate).round();
    final int endSample = startSample + clipSamples;
    if (endSample > wav.samples.length) {
      stdout.writeln('⏭  ${ev.root}:${ev.quality} @ ${ev.timeS.toStringAsFixed(3)}s atlandı — kaynak WAV sona yetişmiyor.');
      continue;
    }
    final List<double> clip = wav.samples.sublist(startSample, endSample);

    final String rootSlug = _rootSlug(ev.root);
    final String key = '$rootSlug-${ev.quality}';
    final int instance = (instanceCounter[key] ?? 0) + 1;
    instanceCounter[key] = instance;

    final String seq = (prepared + 1).toString().padLeft(3, '0');
    final String fixtureId = 'AC-R$seq-guitar-$rootSlug-$instance';
    final String wavName = '$fixtureId.wav';
    PcmWav.writeMonoFile('fixtures/audio-real/$wavName', sampleRate: wav.sampleRate, samples: clip);

    final Map<String, Object?> fixture = {
      'schemaVersion': 'ostinato-audiofix-chord-1',
      'fixtureId': fixtureId,
      'kind': 'real-clean',
      'audio': wavName,
      '\$what': 'Real GuitarSet recording (Bossa Nova comping), ${ev.root}:${ev.quality} chord, '
          '${_clipDurationS}s window starting ${_clipOffsetS}s after JAMS segment onset '
          '(instance $instance of this root+quality in the source take).',
      'recordingMeta': {
        'source': 'guitarset',
        'device': 'guitar, mono neck-pickup mic (GuitarSet "mono-mic" release)',
        'room': null,
        'micDistanceM': null,
        'sampleRate': wav.sampleRate,
        'license': 'CC-BY-4.0',
        '\$licenseNote': 'GuitarSet (Xu, Q., Salamon, J., Bittner, R., Wang, X., Bello, J.P. '
            '"GuitarSet: A Dataset for Guitar Transcription", ISMIR 2018), Zenodo record 3371780, '
            'CC BY 4.0 — verified 2026-08-18 (docs/research/'
            '2026-08-18-w1-audio-golden-fixture-kaynaklari.md). Source ZIP entries SHA-256-pinned '
            'in tool/fetch_guitarset_fixtures.py.',
        'sourceUrl': 'https://zenodo.org/records/3371780',
        'sourceFile': '00_BN1-129-Eb_comp_mic.wav',
        'sourceJams': '00_BN1-129-Eb_comp.jams',
        'originalSegment': {
          'startS': double.parse(ev.timeS.toStringAsFixed(3)),
          'durationS': double.parse(ev.durationS.toStringAsFixed(3)),
          'clipOffsetS': _clipOffsetS,
          'clipDurationS': _clipDurationS,
        },
      },
      'expected': {
        'chordName': ev.root,
        'quality': ev.quality,
        '\$chordDerivation': 'JAMS "chord" namespace, structurally-selected simple/coarse track '
            '(no "/" in any event value — the detailed voicing track, e.g. "D#:sus2(7)/1", was '
            'deliberately excluded: ChordDetector only models {major,minor,dominant7}, so grading '
            'against extensions/inversions would test a question it never claims to answer). Root '
            'mapped via JAMS "<root>:<quality>" split; ChordTemplate.name for major has NO suffix '
            '(chroma.dart pitchClassNames are all-sharp, matching JAMS Harte notation directly for '
            'this take — no enharmonic conversion was needed here, though prepare_guitarset_fixtures.dart '
            'carries a flat→sharp table for future files that might use flat spellings).',
        'shouldJudge': true,
      },
      'windowing': {
        'windowMs': 400,
        'hopMs': 200,
        '\$rationale': 'ChromaAnalyzer.minWindowMs=200 (chroma.dart) is the analysis floor; a '
            '400ms window / 200ms hop yields 5 flush non-overlapping-start windows across this '
            '1200ms clip, testing whether the chord reading is STABLE across the held sustain '
            '(a real reliability question) rather than accepting a single lucky sample.',
      },
      'labels': {
        'annotator': 'guitarset-semi-automatic-with-manual-verification',
        '\$annotatorSource': 'JAMS annotation_metadata.data_source on the simple chord namespace.',
        'confidence': 'high',
      },
    };
    File('fixtures/audio-real/$fixtureId.json')
        .writeAsStringSync(const JsonEncoder.withIndent(' ').convert(fixture));
    stdout.writeln('✓ $fixtureId  (${ev.root}:${ev.quality} @ ${ev.timeS.toStringAsFixed(3)}s, ${clip.length} örnek)');
    prepared++;
  }

  stdout.writeln('→ $prepared/${events.length} gitar akor fixture\'ı hazır: fixtures/audio-real/');
}
