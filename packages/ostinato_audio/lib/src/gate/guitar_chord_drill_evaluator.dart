import '../contract/guitar_chord_drill_contract.dart';
import '../harmony/chord_detector.dart';
import 'audio_confidence_gate.dart' show rmsDb;

/// `open_chord_drill`in TEK penceresinin okuması — tipli, kapalı küme.
/// `ostinato_posture`nin `SurfaceState`iyle AYNI disiplin: "yanlış akor" ile
/// "hiçbir akor duymadım" İKİ AYRI cümledir — biri "hangi hatayı yaptın"
/// söyler, öteki "net değildi" der; ikisini tek bir `null`a düşürmek
/// kullanıcıya en pahalı belirsizliği (hangisi?) miras bırakırdı.
sealed class GuitarChordDrillReading {
  const GuitarChordDrillReading();
}

/// Ses seviyesi `contract.levelAboveRoomFloorDbThreshold`ın altında —
/// PLAY fazına hiç girilmedi.
final class DrillAwaitingSound extends GuitarChordDrillReading {
  const DrillAwaitingSound();
}

/// `noteOnset()`ten `contract.onsetNoVerdictHoldMs` içinde — ruleset'in
/// `verdictGates` (onEvent: onset, effect: collectNoVerdict) kuralı: atak
/// aperiyodik, veri toplanır ama hüküm VERİLMEZ.
final class DrillInAttackWindow extends GuitarChordDrillReading {
  const DrillInAttackWindow();
}

/// Ses yeterince yüksek, atak penceresinin dışında, ama `ChordDetector`
/// hiçbir isim RAPORLAMADI (kendi güven kapısı reddetti) — "net değildi",
/// "yanlış çaldın" DEĞİL.
final class DrillUnclear extends GuitarChordDrillReading {
  const DrillUnclear();
}

/// Bir akor okundu ama BEKLENENDEN FARKLI bir isimle, VEYA skor
/// `contract.chordCorrectnessThreshold`ın altında. [detectedName] motorun
/// GERÇEKTEN duyduğu şey — "yanlış" demek yetmez, kullanıcı HANGİ hatayı
/// yaptığını bilmeli.
final class DrillIncorrect extends GuitarChordDrillReading {
  const DrillIncorrect({required this.detectedName, required this.score});
  final String detectedName;
  final double score;
}

/// Beklenen akor DOĞRU adla VE eşiğin üstünde bir skorla okundu.
final class DrillCorrect extends GuitarChordDrillReading {
  const DrillCorrect({required this.score});
  final double score;
}

/// `open_chord_drill` pencerelerini [GuitarChordDrillReading]e çeviren TEK
/// yer. `PostureEvaluator`nin AYNI mimarisi: sözleşmenin (`contract`)
/// canlı karşılığı, hiçbiri widget'ta değil.
///
/// `AudioConfidenceGate`i BİLEREK kullanmıyor — o `PitchReading`e özel
/// (periodicity/f0Hz), akorun kendi güven mekanizması FARKLI ve ZATEN
/// `ChordDetector.detect()`in İÇİNDE (minScore/minRunnerUpMargin, null
/// döndürür). Burada yeniden İCAT edilmedi, yalnız seviye-eşiği ve
/// atak-penceresi (ruleset'in KENDİ kavramları, chord'a özel bir kapı
/// DEĞİL) eklendi.
final class GuitarChordDrillEvaluator {
  GuitarChordDrillEvaluator({
    required this.contract,
    ChordDetector? detector,
  }) : detector = detector ?? const ChordDetector();

  final GuitarChordDrillContract contract;
  final ChordDetector detector;

  int? _lastOnsetTUs;

  /// Çağıran (canlı `OnsetDetector` çıktısı) her yeni atağı burada bildirir.
  /// Sonraki `evaluate()` çağrıları `contract.onsetNoVerdictHoldMs` boyunca
  /// `DrillInAttackWindow` döner.
  void noteOnset(int tUs) {
    _lastOnsetTUs = tUs;
  }

  GuitarChordDrillReading evaluate(
    List<double> samples, {
    required int sampleRate,
    required int tStartUs,
    required double roomFloorDb,
    required String expectedChordName,
  }) {
    final double level = rmsDb(samples);
    if (level < roomFloorDb + contract.levelAboveRoomFloorDbThreshold) {
      return const DrillAwaitingSound();
    }

    final int? lastOnset = _lastOnsetTUs;
    if (lastOnset != null &&
        tStartUs - lastOnset < contract.onsetNoVerdictHoldMs * 1000) {
      return const DrillInAttackWindow();
    }

    final ChordReading? reading = detector.detect(samples, sampleRate: sampleRate);
    if (reading == null) {
      return const DrillUnclear();
    }

    final bool nameMatches = reading.chord.name == expectedChordName;
    final bool scoreOk = reading.score >= contract.chordCorrectnessThreshold;
    if (nameMatches && scoreOk) {
      return DrillCorrect(score: reading.score);
    }
    return DrillIncorrect(detectedName: reading.chord.name, score: reading.score);
  }
}
