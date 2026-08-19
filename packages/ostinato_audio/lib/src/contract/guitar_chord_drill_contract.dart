import 'dart:convert';

import '../pitch/yin.dart';

/// `open_chord_drill`in canlı ses yüzeyinin TÜM sayıları — hepsi
/// `tools/gen_audio_contract.py`nin `config/rulesets/guitar@0.2.0-draft.json`
/// ruleset'inden ürettiği `assets/config/audio-contract.json`ten, hiçbiri
/// kodda sabit.
///
/// `packages/ostinato_posture/lib/src/contract.dart`daki `PostureContract`
/// ile AYNI desen ve AYNI gerekçe: bir sayı kabukta kendi başına yaşarsa,
/// ruleset güncellenince o kopya sessizce bayatlar ve kimse fark etmez.
final class GuitarChordDrillContract {
  const GuitarChordDrillContract({
    required this.chordCorrectnessThreshold,
    required this.levelAboveRoomFloorDbThreshold,
    required this.playTimeoutMs,
    required this.playMinDurationMs,
    required this.onsetNoVerdictHoldMs,
    required this.pitchWindowMs,
    required this.pitchHopMs,
    required this.yinThreshold,
    required this.onsetFrameMs,
    required this.onsetHopMs,
    required this.onsetMedianWindow,
    required this.onsetBandCount,
    required this.onsetMinAnalysisHz,
    required this.onsetMaxAnalysisHz,
  });

  /// PLAY fazının kalite kapısı — `ChordReading` bunun altındaysa hüküm yok.
  final double chordCorrectnessThreshold;

  /// Oda tabanının üstünde kaç dB olunca PLAY fazına girilir/çıkılır
  /// (ruleset'in KENDİ tutarlılığı `gen_audio_contract.py`de doğrulandı —
  /// PLAY.enter ve PLAY.exit ruleset'te AYNI sayı, farklı yön).
  final double levelAboveRoomFloorDbThreshold;

  final int playTimeoutMs;
  final int playMinDurationMs;

  /// `verdictGates`in onset penceresi — bu süre boyunca veri toplanır ama
  /// hüküm VERİLMEZ (atak aperiyodik).
  final int onsetNoVerdictHoldMs;

  final double pitchWindowMs;
  final double pitchHopMs;
  final double yinThreshold;
  final int onsetFrameMs;
  final int onsetHopMs;
  final int onsetMedianWindow;
  final int onsetBandCount;
  final double onsetMinAnalysisHz;
  final double onsetMaxAnalysisHz;

  static GuitarChordDrillContract fromJson(String source) {
    final Map<String, dynamic> m =
        (jsonDecode(source) as Map<String, dynamic>)['guitar']
            as Map<String, dynamic>;
    return GuitarChordDrillContract(
      chordCorrectnessThreshold: (m['chordCorrectnessThreshold'] as num).toDouble(),
      levelAboveRoomFloorDbThreshold: (m['levelAboveRoomFloorDbThreshold'] as num).toDouble(),
      playTimeoutMs: m['playTimeoutMs'] as int,
      playMinDurationMs: m['playMinDurationMs'] as int,
      onsetNoVerdictHoldMs: m['onsetNoVerdictHoldMs'] as int,
      pitchWindowMs: (m['pitchWindowMs'] as num).toDouble(),
      pitchHopMs: (m['pitchHopMs'] as num).toDouble(),
      yinThreshold: (m['yinThreshold'] as num).toDouble(),
      onsetFrameMs: m['onsetFrameMs'] as int,
      onsetHopMs: m['onsetHopMs'] as int,
      onsetMedianWindow: m['onsetMedianWindow'] as int,
      onsetBandCount: m['onsetBandCount'] as int,
      onsetMinAnalysisHz: (m['onsetMinAnalysisHz'] as num).toDouble(),
      onsetMaxAnalysisHz: (m['onsetMaxAnalysisHz'] as num).toDouble(),
    );
  }

  /// Bu sözleşmenin `yinThreshold`iyle kurulmuş bir `YinPitchSource`.
  /// minHz/maxHz burada YOK — piyano turlarında (O-184) ölçülen "enstrüman-
  /// uygun aralık sınıf-varsayılanı EZMELİ" dersiyle tutarlı, gitar-özel
  /// aralık henüz ruleset'te YOK (yalnız `onsetMinAnalysisHz`/`onsetMaxAnalysisHz`
  /// var, o ONSET'in bant aralığı — pitch'in KENDİ minHz/maxHz'i değil,
  /// ikisini KARIŞTIRMAK yanlış motor kurardı) — çağıran gerekirse üzerine
  /// yazar.
  YinPitchSource toYinPitchSource({double? expectedHzPrior}) {
    return YinPitchSource(
      threshold: yinThreshold,
      expectedHzPrior: expectedHzPrior,
    );
  }
}
