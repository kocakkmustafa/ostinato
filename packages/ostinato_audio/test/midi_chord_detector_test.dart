import 'package:ostinato_audio/ostinato_audio.dart';
import 'package:test/test.dart';

/// Standart açık pozisyon parmak dizilişlerinden türetilmiş GERÇEK MIDI nota
/// numaraları (EADGBE akort: E2=40 A2=45 D3=50 G3=55 B3=59 E4=64) —
/// uydurulmadı, her akorun perde-numarası müzik teorisiyle çapraz kontrol
/// edildi (bkz. spike raporu). `open_chord_drill`in kapsadığı 8 akor,
/// kromagram spike'ıyla (M-O-35) AYNI set.
const chords = <String, Set<int>>{
  'E': {40, 47, 52, 56, 59, 64}, // 022100
  'A': {45, 52, 57, 61, 64}, // x02220
  'D': {50, 57, 62, 66}, // xx0232
  'G': {43, 47, 50, 55, 59, 67}, // 320003
  'C': {48, 52, 55, 60, 64}, // x32010
  'Am': {45, 52, 57, 60, 64}, // x02210
  'Em': {40, 47, 52, 55, 59, 64}, // 022000
  'Dm': {50, 57, 62, 65}, // xx0231
};

void main() {
  const open8 = [
    ChordTemplate(4, ChordQuality.major, [0, 4, 7]), // E
    ChordTemplate(9, ChordQuality.major, [0, 4, 7]), // A
    ChordTemplate(2, ChordQuality.major, [0, 4, 7]), // D
    ChordTemplate(7, ChordQuality.major, [0, 4, 7]), // G
    ChordTemplate(0, ChordQuality.major, [0, 4, 7]), // C
    ChordTemplate(9, ChordQuality.minor, [0, 3, 7]), // Am
    ChordTemplate(4, ChordQuality.minor, [0, 3, 7]), // Em
    ChordTemplate(2, ChordQuality.minor, [0, 3, 7]), // Dm
  ];
  const detector = MidiChordDetector(templates: open8);

  test('8 açık akorun gerçek MIDI notaları 8/8 doğru tanınıyor', () {
    for (final entry in chords.entries) {
      final r = detector.classify(entry.value);
      expect(r, isNotNull, reason: '${entry.key} tanınamadı');
      expect(r!.chord.name, entry.key,
          reason: '${entry.key} çalındı, ${r.chord.name} okundu');
      expect(r.score, 1.0,
          reason: 'MIDI\'de eksiksiz eşleşme her zaman TAM skor vermeli '
              '(gürültü payı yok — DSP tahmini değil, doğrudan veri)');
    }
  });

  test('boş nota kümesi reddedilir', () {
    expect(detector.classify(<int>{}), isNull);
  });

  test('yalnız kök nota (tek ses) reddedilir — akor değil', () {
    // Yalnız E notası (herhangi oktavda): hiçbir 3-notalı şablonun
    // %75 kapsamasını karşılamaz (1/3 = %33).
    final r = detector.classify({40});
    expect(r, isNull);
  });

  test('yanlış/fazladan nota akoru reddeder, "yaklaşık doğru" saymaz', () {
    // E majör notalarına YABANCI bir nota eklendi (F, pitch class 5) —
    // yanlış tel basılmış gibi. _coverage extra varsa 0 döner: bu
    // KASITLI sertlik, "neredeyse E" diye yanlış bir akoru onaylamamak için.
    final wrong = {...chords['E']!, 41}; // 41 = F, E'nin şablonunda yok
    final r = detector.classify(wrong);
    expect(r, isNull,
        reason: 'yabancı nota içeren küme hiçbir şablonu %100 kapsamaz '
            've extra notalı şablon 0 puan alır');
  });

  test('eksik nota (minCoverage altı) reddedilir, üstü kabul edilir', () {
    // E majör: {E,G#,B} gerekli (3 pitch class). 2/3 = %67 < minCoverage(0.75).
    // Tam open8 setiyle: runner-up karşılaştırması için ≥2 şablon şart
    // (classify() tek şablonla runner-up bulamaz — kasıtlı, ChordDetector'ın
    // aynı deseni: bir tek adayın "en iyisi" anlamsızdır, karşılaştırma ister).
    // Yalnız E ve B (pitch class 4, 11) — G# (8) eksik.
    expect(detector.classify({40, 59}), isNull,
        reason: '2/3 kapsama eşiğin (0.75) altında');
    // Tüm üçü (G# farklı oktavda bile) — kapsama %100.
    final full = detector.classify({40, 56 + 12, 59});
    expect(full, isNotNull);
    expect(full!.chord.name, 'E');
  });

  test(
      'göreli majör/minör (C↔Am) ayrımı MIDI\'de de net — '
      'paylaşılan notalarla karışmaz', () {
    // Am = {A,C,E}, C = {C,E,G} — ikisi de C ve E paylaşır. Am'nin gerçek
    // notaları (kök A dahil) yalnız Am'yi %100 kapsamalı, C'yi kapsamamalı
    // (G yok).
    final r = detector.classify(chords['Am']!);
    expect(r!.chord.name, 'Am');
    expect(r.runnerUp.name, isNot('C'),
        reason: 'Am çalınırken en yakın rakip C olmamalı — G notası yok, '
            'kapsama 0');
  });
}
