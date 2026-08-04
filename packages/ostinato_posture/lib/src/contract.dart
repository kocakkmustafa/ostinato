import 'dart:convert';

/// Bir çalgının canlı postür yüzeyinin TÜM sayıları — hepsi config'ten,
/// hiçbiri kodda sabit.
///
/// Neden ayrı bir tür: bu sayıların kaynağı referans artefaktıdır ve
/// `tools/derive_posture_thresholds.py --check` her koşumda config'in hâlâ
/// artefaktla aynı şeyi söylediğini sınar. Kabuk bir sayıyı kendi içinde
/// tutarsa o zincir kopar ve kimse fark etmez (O-024 sınıfı: doğru sayının
/// arkasındaki bayat gerekçe).
final class PostureContract {
  const PostureContract({
    required this.instrument,
    required this.scoringToleranceDeg,
    required this.cueThresholdDeg,
    required this.teacherCount,
    required this.sourceClass,
    required this.bandLowDeg,
    required this.bandHighDeg,
    required this.cueTemplateId,
    required this.dispersionMedianDeg,
  });

  final String instrument;

  /// Skorlama bandı — "referansa göre bandın içinde misin".
  final double scoringToleranceDeg;

  /// Gözlem işaretinin eşiği = anlaşma kapısının barı (`clusterToleranceDeg`).
  /// Bunun ÖTESİ, hemfikir sayılan eğitmenlerin işgal ettiği aralığın dışıdır.
  final double cueThresholdDeg;

  final int teacherCount;
  final String sourceClass;

  /// Eğitmenlerin GERÇEKTEN oturduğu aralık (hold-penceresi medyanları).
  /// "Doğru duruş bir NOKTA değil BANT" dersinin veri karşılığı.
  final double bandLowDeg;
  final double bandHighDeg;

  final String cueTemplateId;
  final double dispersionMedianDeg;

  static PostureContract fromJson(String source, String instrument) {
    final Map<String, dynamic> m =
        (jsonDecode(source) as Map<String, dynamic>)[instrument]
            as Map<String, dynamic>;
    return PostureContract(
      instrument: instrument,
      scoringToleranceDeg: (m['scoringToleranceDeg'] as num).toDouble(),
      cueThresholdDeg: (m['cueThresholdDeg'] as num).toDouble(),
      teacherCount: m['teacherCount'] as int,
      sourceClass: m['sourceClass'] as String,
      bandLowDeg: (m['bandLowDeg'] as num).toDouble(),
      bandHighDeg: (m['bandHighDeg'] as num).toDouble(),
      cueTemplateId: m['cueTemplateId'] as String,
      dispersionMedianDeg: (m['dispersionMedianDeg'] as num).toDouble(),
    );
  }
}
