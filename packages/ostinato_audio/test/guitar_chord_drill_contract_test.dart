import 'package:ostinato_audio/ostinato_audio.dart';
import 'package:test/test.dart';

/// OST-P1-001 Step 2 (guitar dilimi) — `tools/gen_audio_contract.py`nin
/// ürettiği `assets/config/audio-contract.json`ı okuyan sözleşme sınıfı.
/// `PostureContract` ile AYNI desen (`packages/ostinato_posture/lib/src/
/// contract.dart`): tüm sayılar config'ten, hiçbiri kodda sabit.
void main() {
  const String sample = '''
{
 "guitar": {
  "chordCorrectnessThreshold": 0.8,
  "levelAboveRoomFloorDbThreshold": 6,
  "playTimeoutMs": 20000,
  "playMinDurationMs": 800,
  "onsetNoVerdictHoldMs": 100,
  "pitchWindowMs": 92.9,
  "pitchHopMs": 23.2,
  "yinThreshold": 0.15,
  "onsetFrameMs": 46,
  "onsetHopMs": 6,
  "onsetMedianWindow": 11,
  "onsetBandCount": 24,
  "onsetMinAnalysisHz": 40,
  "onsetMaxAnalysisHz": 4000,
  "_derivedFrom": {"ruleset": "config/rulesets/guitar@0.2.0-draft.json", "rulesetVersion": "0.2.0-draft", "technique": "open_chord_drill"}
 }
}
''';

  test('fromJson TÜM alanları GERÇEK JSON değerleriyle doldurur (sabit YOK)', () {
    final GuitarChordDrillContract c = GuitarChordDrillContract.fromJson(sample);
    expect(c.chordCorrectnessThreshold, 0.8);
    expect(c.levelAboveRoomFloorDbThreshold, 6.0);
    expect(c.playTimeoutMs, 20000);
    expect(c.playMinDurationMs, 800);
    expect(c.onsetNoVerdictHoldMs, 100);
    expect(c.pitchWindowMs, 92.9);
    expect(c.pitchHopMs, 23.2);
    expect(c.yinThreshold, 0.15);
    expect(c.onsetFrameMs, 46);
    expect(c.onsetHopMs, 6);
    expect(c.onsetMedianWindow, 11);
    expect(c.onsetBandCount, 24);
    expect(c.onsetMinAnalysisHz, 40.0);
    expect(c.onsetMaxAnalysisHz, 4000.0);
  });

  test('int-şekilli JSON sayıları (6, 40, 4000) DOĞRU şekilde double\'a çevrilir', () {
    // JSON'da "levelAboveRoomFloorDbThreshold": 6 (ondalık YOK) — Dart'ın
    // jsonDecode'u bunu `int` olarak parse eder, `num.toDouble()` şart.
    final GuitarChordDrillContract c = GuitarChordDrillContract.fromJson(sample);
    expect(c.levelAboveRoomFloorDbThreshold, isA<double>());
    expect(c.onsetMinAnalysisHz, isA<double>());
  });

  test('toYinPitchSource() PitchSource\'ı GERÇEK config değerleriyle kurar', () {
    final GuitarChordDrillContract c = GuitarChordDrillContract.fromJson(sample);
    final YinPitchSource source = c.toYinPitchSource(expectedHzPrior: 440.0);
    // YinPitchSource'ın kendi alanları private DEĞİL — threshold/minHz/maxHz
    // public, ama pitchWindow/hopMs kendisi taşımıyor (çağıran pencereyi
    // KENDİSİ kesip veriyor) — burada yalnız threshold'un GERÇEKTEN
    // config'ten geldiğini doğrula (varsayılan 0.15 ile aynı DEĞER olsa
    // bile, testin amacı "sabit değil, config'ten okundu" — bu örnekte
    // ikisi aynı sayı olduğu için ayrıca farklı bir eşikle de sına).
    expect(source.threshold, 0.15);
  });

  test('farklı bir yinThreshold GERÇEKTEN motoru DEĞİŞTİRİR (sabit-kopyalama değil)', () {
    const String customThreshold = '''
{"guitar": {"chordCorrectnessThreshold": 0.8, "levelAboveRoomFloorDbThreshold": 6,
 "playTimeoutMs": 20000, "playMinDurationMs": 800, "onsetNoVerdictHoldMs": 100,
 "pitchWindowMs": 92.9, "pitchHopMs": 23.2, "yinThreshold": 0.33,
 "onsetFrameMs": 46, "onsetHopMs": 6, "onsetMedianWindow": 11, "onsetBandCount": 24,
 "onsetMinAnalysisHz": 40, "onsetMaxAnalysisHz": 4000,
 "_derivedFrom": {"ruleset": "x", "rulesetVersion": "x", "technique": "x"}}}
''';
    final GuitarChordDrillContract c = GuitarChordDrillContract.fromJson(customThreshold);
    expect(c.yinThreshold, 0.33);
    expect(c.toYinPitchSource().threshold, 0.33,
        reason: 'sözleşme farklı bir eşik taşıyorsa motor da onu YANSITMALI '
            '— sabit 0.15 kodda gömülü olsaydı bu test hâlâ (yanlışlıkla) geçerdi');
  });
}
