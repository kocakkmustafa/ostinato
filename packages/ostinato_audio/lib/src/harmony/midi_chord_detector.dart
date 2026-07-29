import 'chord_detector.dart';

/// MIDI-girişli akor tanıma — koordinatör talimatı (M-F-103): `open_chord_drill`
/// için MIDI-girişli ALTERNATİF yol fizibilitesi.
///
/// `ChordDetector` (kromagram) sesteki BELİRSİZLİĞİ (harmonik sızıntı, oktav
/// karışıklığı, gürültü) ölçüp yönetir — bu detektörün asıl işi o değil,
/// çünkü hex-pickup'lı bir MIDI gitarda (Fishman TriplePlay, Roland GK
/// serisi) her tel AYRI bir MIDI notası üretir: hangi perdenin basıldığı
/// DOĞRUDAN veridir, DSP tahmini değil. Bu yüzden burada skor gürültü-payı
/// değil TAM EŞLEŞME oranıdır — aynı `ChordTemplate` sözlüğünü (E A D G C Am
/// Em Dm) `chord_detector.dart`dan REUSE eder, ikinci bir akor tanımı icat
/// etmez.
///
/// Donanım gerçekliği (2026-07-29 araştırması, DEFTER'e kayıtlı): MIDI
/// gitar pickup'ları (Fishman TriplePlay ~$220-400, Roland GK-3/GK-5) ayrı
/// satın alınan, köprüye monte edilen donanım — DAW/kompozisyon kullanıcısı
/// hedefliyor, `open_chord_drill`in hedef kitlesi (açık akor öğrenen
/// YENİ BAŞLAYAN) DEĞİL. Bu detektör teknik olarak çalışır (aşağıdaki
/// self-test kanıtı) ama ürün önceliği DEĞİL — bkz. spike raporu.
final class MidiChordDetector {
  const MidiChordDetector({
    this.templates,
    this.minCoverage = 0.75,
  });

  /// Bilinen akor kümesiyle sınırlar (drill'in kapsadığı 8 akor gibi).
  final List<ChordTemplate>? templates;

  /// Şablonun gerektirdiği pitch class'ların en az bu oranı ÇALINMALI.
  /// MIDI'de "eksik nota" mümkündür (tel MIDI çevirici tarafından
  /// atlanabilir, veya kullanıcı bir teli çalmayı unutabilir) — ama sıfır
  /// tolerans, gerçek donanımın kaçırdığı tek notada tüm akoru reddeder.
  final double minCoverage;

  /// `activeMidiNotes`: o an BASILI/ÇALAN MIDI nota numaraları (note-on'dan
  /// note-off'a kadar). Standart 0-127 MIDI aralığı; pitch class = note%12.
  ChordReading? classify(Set<int> activeMidiNotes) {
    if (activeMidiNotes.isEmpty) return null;
    final pitchClasses = activeMidiNotes.map((n) => n % 12).toSet();
    final candidates = templates ?? ChordTemplate.all();

    ChordTemplate? best, second;
    var bestScore = -1.0, secondScore = -1.0;

    for (final t in candidates) {
      final s = _coverage(pitchClasses, t);
      if (s > bestScore) {
        second = best;
        secondScore = bestScore;
        best = t;
        bestScore = s;
      } else if (s > secondScore) {
        second = t;
        secondScore = s;
      }
    }
    if (best == null || second == null) return null;
    if (bestScore < minCoverage) return null;

    return ChordReading(
      chord: best,
      score: bestScore,
      runnerUp: second,
      runnerUpMargin: bestScore - secondScore,
    );
  }

  /// Şablonun gerektirdiği pitch class'ların kaçı ÇALINAN notalarda var —
  /// eksiği CEZALANDIRIR (kapsama), fazlayı da (çalınan ama şablonda
  /// olmayan bir nota varsa) SIFIRLAR: yanlış tel/perde basılmışsa bu
  /// "neredeyse doğru" değil YANLIŞ akordur.
  double _coverage(Set<int> playedPitchClasses, ChordTemplate t) {
    final required = <int>{
      for (final i in t.intervals) (t.rootPitchClass + i) % 12,
    };
    final extra = playedPitchClasses.difference(required);
    if (extra.isNotEmpty) return 0;
    final matched = required.intersection(playedPitchClasses).length;
    return matched / required.length;
  }
}
