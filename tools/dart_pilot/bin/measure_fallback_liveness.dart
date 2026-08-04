import 'dart:convert';
import 'dart:io';

import 'package:ostinato_audio/ostinato_audio.dart';

/// Fallback canlılık ölçümü — reçete `FALLBACK-CANLILIK-RECETESI.md` (M-F-184).
///
/// > "Bir fallback sınıfının VAR olması, tanımadığı girdinin ORAYA DÜŞTÜĞÜ
/// > anlamına gelmez. Fallback'in tetiklendiği ölçülmedikçe dekoratiftir."
///
/// ADIM 1 — sözlük ve fallback İSİMLE:
///   Modellenmiş sınıflar: `open_chord_drill`in kapsadığı 8 açık akor
///   (E A D G C Am Em Dm — `SyntheticTone.openGuitarChords`, ruleset'in
///   canlı dersiyle aynı küme).
///   Fallback: `ChordDetector.detect()` -> `null`. İki ayrı kapı üretir:
///     · bestScore < minScore (0.55)            -> "bildiğim hiçbir şeye benzemiyor"
///     · runnerUpMargin < minMargin (0.06)      -> "ayıramıyorum"
///   Kod yolu: chord_detector.dart:132.
///
/// ADIM 2 — sözlük-dışı girdi. DÜRÜST SINIR, reçete §3.2 gereği İSİMLE:
///   elimizde GERÇEK gitar kaydı YOK (kurucu-bekleyen), bu yüzden ölçüm
///   SENTETİK girdiyle yapıldı. Reçetenin hükmü: sonuç "fallback tetiklendi"
///   diye DEĞİL, "SENTETİKTE tetiklendi" diye yazılır. Gerçek kayıt gelince
///   aynı iskelet o kaydı da geçirir — kod değişmez, girdi değişir.
///
/// ADIM 3 — ÜÇ sayaç birlikte + KONTROL SATIRI (M-F-202: "bir orana 'düşük'
///   demek kontrol koşulunu ölçmeden mümkün değil"). Her sözlük-dışı ölçümün
///   yanında, AYNI hattan geçmiş bir sözlük-İÇİ akor duruyor.
void main(List<String> args) {
  const sampleRate = 44100;
  const windowSamples = 8820; // 200 ms — make_chord_fixture ile aynı
  const hopSamples = 4410;
  const seconds = 3.0;

  // Modellenmiş sözlük = dersin kapsadığı 8 akor (ruleset'le birebir).
  const specs = <String, (int, ChordQuality)>{
    'E': (4, ChordQuality.major), 'A': (9, ChordQuality.major),
    'D': (2, ChordQuality.major), 'G': (7, ChordQuality.major),
    'C': (0, ChordQuality.major), 'Am': (9, ChordQuality.minor),
    'Em': (4, ChordQuality.minor), 'Dm': (2, ChordQuality.minor),
  };
  final templates = [
    for (final e in specs.entries)
      ChordTemplate(e.value.$1, e.value.$2,
          e.value.$2 == ChordQuality.major ? const [0, 4, 7] : const [0, 3, 7]),
  ];
  final detector = ChordDetector(templates: templates);

  // Sözlük-DIŞI girdiler. F majör kasten ilk sırada: yeni başlayanın ilk
  // barre akoru ve notaları (F A C) sözlükteki Dm (D F A) ve Am (A C E) ile
  // ikişer nota paylaşıyor — yanlış-sınıflama (mekanizma A) için en olası aday.
  const oov = <String, List<int>>{
    'F (barre, sözlük dışı)': [41, 45, 48, 53, 57, 65],
    'Bm (barre, sözlük dışı)': [47, 54, 59, 62, 66],
    'Bb (sözlük dışı)': [46, 53, 58, 62, 65],
    'F#m (sözlük dışı)': [42, 49, 54, 57, 61],
    'tek nota A4 (akor DEĞİL)': [69],
  };
  // KONTROL: sözlük İÇİ akorlar, AYNI hattan.
  const control = <String, List<int>>{
    'E (sözlükte)': [40, 47, 52, 56, 59, 64],
    'Am (sözlükte)': [45, 52, 57, 60, 64],
    'G (sözlükte)': [43, 47, 50, 55, 59, 67],
  };

  Map<String, dynamic> measure(String label, List<int> midi, {bool noise = false}) {
    final signal = noise
        ? SyntheticTone.roomNoise(sampleRate: sampleRate, seconds: seconds, amplitude: 0.05)
        : SyntheticTone.chord(
            midiNotes: midi, sampleRate: sampleRate, seconds: seconds,
            strumSpreadSeconds: 0.025);

    var windows = 0, refused = 0, lowScore = 0, lowMargin = 0, unusable = 0;
    final modelled = <String, int>{};
    for (var i = 0; i + windowSamples <= signal.length; i += hopSamples) {
      windows++;
      final slice = signal.sublist(i, i + windowSamples);
      final r = detector.detect(slice, sampleRate: sampleRate);
      if (r != null) {
        modelled[r.chord.name] = (modelled[r.chord.name] ?? 0) + 1;
        continue;
      }
      refused++;
      // Reddin SEBEBİNİ ayır: aynı sayı, üç farklı teşhis demektir.
      final chroma = const ChromaAnalyzer().analyze(slice, sampleRate: sampleRate);
      if (chroma == null) {
        unusable++;
      } else {
        final open = ChordDetector(templates: templates, minScore: 0, minRunnerUpMargin: 0)
            .classify(chroma);
        if (open == null) {
          unusable++;
        } else if (open.score < 0.55) {
          lowScore++;
        } else {
          lowMargin++;
        }
      }
    }
    final durationS = signal.length / sampleRate;
    return {
      'label': label,
      'windows': windows,
      'durationS': double.parse(durationS.toStringAsFixed(2)),
      'windowsPerSecond': double.parse((windows / durationS).toStringAsFixed(2)),
      'fallback': refused,
      'fallbackShare': double.parse((windows == 0 ? 0 : refused / windows).toStringAsFixed(3)),
      'refusalReason': {'lowScore': lowScore, 'lowMargin': lowMargin, 'unusable': unusable},
      'modelled': modelled,
      'modelledTotal': modelled.values.fold<int>(0, (a, b) => a + b),
    };
  }

  final oovRows = [for (final e in oov.entries) measure(e.key, e.value)];
  oovRows.add(measure('oda gürültüsü (ses DEĞİL)', const [], noise: true));
  final controlRows = [for (final e in control.entries) measure(e.key, e.value)];

  void show(String title, List<Map<String, dynamic>> rows) {
    stdout.writeln('\n$title');
    for (final r in rows) {
      final m = (r['modelled'] as Map).entries
          .map((e) => '${e.key}×${e.value}').join(' ');
      stdout.writeln('  ${(r['label'] as String).padRight(26)} '
          'pencere ${r['windows']} (${r['windowsPerSecond']}/sn) · '
          'FALLBACK ${r['fallback']} (%${((r['fallbackShare'] as double) * 100).round()}) · '
          'modellenmiş ${r['modelledTotal']}${m.isEmpty ? '' : '  [$m]'}');
      final rr = r['refusalReason'] as Map;
      if ((r['fallback'] as int) > 0) {
        stdout.writeln('  ${' '.padRight(26)} red sebebi: '
            'düşük-skor ${rr['lowScore']} · ayıramama ${rr['lowMargin']} · '
            'kullanılamaz ${rr['unusable']}');
      }
    }
  }

  show('── SÖZLÜK-DIŞI (sentetik) ──', oovRows);
  show('── KONTROL: sözlük-içi, AYNI hat (M-F-202) ──', controlRows);

  // TEŞHİS (reçete §3 tablosu). Kontrol satırı olmadan hiçbir orana
  // "yüksek/düşük" denemez — bu yüzden teşhis ikisini birlikte okur.
  final oovFallback = oovRows.fold<int>(0, (a, r) => a + (r['fallback'] as int));
  final oovModelled = oovRows.fold<int>(0, (a, r) => a + (r['modelledTotal'] as int));
  final ctlFallback = controlRows.fold<int>(0, (a, r) => a + (r['fallback'] as int));
  final ctlModelled = controlRows.fold<int>(0, (a, r) => a + (r['modelledTotal'] as int));
  final oovWindows = oovRows.fold<int>(0, (a, r) => a + (r['windows'] as int));
  final ctlWindows = controlRows.fold<int>(0, (a, r) => a + (r['windows'] as int));

  final oovShare = oovFallback / oovWindows;
  final ctlShare = ctlFallback / ctlWindows;

  // TEŞHİS GİRDİ BAŞINA — toplamda DEĞİL.
  //
  // İlk sürümüm toplam oranı okuyordu ve "✅ fallback canlı, 46,5× ayırma
  // gücü" diyordu. O cümle DOĞRUYDU ve YANILTICIYDI: toplam, %100 reddedilen
  // tek notayı %97 yanlış-sınıflanan Bb ile ORTALIYOR ve ikisinden sağlıklı
  // görünen bir %53 üretiyor. Reçetenin A/B ayrımı girdi başınadır; toplama
  // uygulanan bir teşhis, en kötü vakayı en iyisiyle örter.
  final mechanismA = <String>[];
  for (final r in oovRows) {
    final w = r['windows'] as int;
    final f = r['fallback'] as int;
    final m = r['modelledTotal'] as int;
    if (w > 0 && m > f) {
      final top = (r['modelled'] as Map<String, int>).entries
          .reduce((a, b) => a.value >= b.value ? a : b);
      mechanismA.add('${r['label']} → ${top.key} olarak ${top.value}/$w pencere '
          '(%${(100 * top.value / w).round()}), fallback yalnız $f');
    }
  }

  String verdict;
  if (mechanismA.isNotEmpty) {
    verdict = '🔴 MEKANİZMA A — GİRDİ BAŞINA: ${mechanismA.length}/${oovRows.length} '
        'sözlük-dışı girdi, fallback\'e düşmek yerine en yakın MODELLENMİŞ '
        'akora tamamlanıyor. Toplam oran (%${(oovShare * 100).round()} vs '
        'kontrol %${(ctlShare * 100).round()}) bunu GİZLİYOR.';
  } else if (oovFallback == 0 && oovModelled == 0) {
    verdict = '🔴 MEKANİZMA B (görünmezlik): girdi hüküm yoluna hiç girmedi.';
  } else if (oovShare <= ctlShare) {
    verdict = '🟠 AYIRMA YOK: sözlük-dışı red oranı (%${(oovShare * 100).round()}) '
        'kontrolden (%${(ctlShare * 100).round()}) yüksek DEĞİL.';
  } else {
    verdict = '✅ FALLBACK CANLI ve girdi başına AYIRT EDİYOR: sözlük-dışı '
        '%${(oovShare * 100).round()}, kontrol %${(ctlShare * 100).round()}.';
  }
  stdout.writeln('\nTEŞHİS: $verdict');
  for (final a in mechanismA) {
    stdout.writeln('   · $a');
  }
  stdout.writeln('SINIR: ölçüm SENTETİK girdiyle yapıldı — gerçek gitar kaydı '
      'yok (kurucu-bekleyen). Reçete §3.2: sonuç "sentetikte tetiklendi" diye okunur.');

  final outPath = args.isEmpty ? '../../docs/g1/fallback-liveness-guitar.json' : args.first;
  File(outPath).writeAsStringSync(
      const JsonEncoder.withIndent(' ').convert({
    'measuredAt': 'motion_core-v0.8.6 / ostinato_audio 0.1.0',
    'recipe': 'FALLBACK-CANLILIK-RECETESI.md (M-F-184)',
    'inputKind': 'synthetic',
    r'$limit': 'Gerçek gitar kaydı yok — "sentetikte tetiklendi" olarak okunur (reçete §3.2).',
    'vocabulary': specs.keys.toList(),
    'fallbackClass': 'ChordDetector.detect() -> null (minScore 0.55 / minRunnerUpMargin 0.06)',
    'outOfVocabulary': oovRows,
    'control': controlRows,
    'mechanismA': mechanismA,
    'summary': {
      'oovFallbackShare': double.parse(oovShare.toStringAsFixed(3)),
      'controlFallbackShare': double.parse(ctlShare.toStringAsFixed(3)),
      'oovModelledTotal': oovModelled,
      'controlModelledTotal': ctlModelled,
      'verdict': verdict,
    },
  }));
  stdout.writeln('\n→ $outPath yazıldı');
}
