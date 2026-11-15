import 'micro_etude_models.dart';

/// Kural tabanlı mikro-etüt üreticisi. Ağ, LLM, telifli kaynak yok; yalnız
/// aşağıdaki küçük kural kümesi.
///
/// Kurallar:
/// - M1 menzil: tüm notalar E2–E5 (MIDI 40–76); girdi notaları oktav katlanır.
/// - M2 sıçrama: ardışık notalar arası en çok 12 yarım ses; A→B geçişi daha
///   büyükse B oktavla A'ya yaklaştırılır (perde sınıfı korunur).
/// - T (geçiş): T1 yavaş çiftler → T2 bağlı sekizlikler → T3 komşu sesli
///   (A B C B) → T4 kadans (B uzatılır). Cümle 2/3/4 ölçüde T1+T4, T1+T2+T4,
///   T1+T2+T3+T4.
/// - R (ritim): R1 vuruş+hedef, R2 yalnız hedef, R3 erken ise bekle ("wait"),
///   geç ise ön vuruş ("leadin"), R4 kadans (tek uzun nota). Cümle: R1+R2,
///   R1+R2+R3, R1+R2+R3+R4.
/// - K kademe: hedef tempo %60 → %80 → %100 (en az 30 bpm); cümle tekrar
///   sayıları 15–30 sn içinde kalacak biçimde aranır; sığmazsa ölçü/kademe
///   azaltılır.
abstract final class MicroEtudeGenerator {
  static const minBpm = 40, maxBpm = 160;
  static const minSeconds = 15.0, maxSeconds = 30.0, aimSeconds = 22.5;
  static const lowestMidi = 40, highestMidi = 76, maxLeap = 12;

  static const _allowed = [8, 6, 4, 3, 2, 1];

  static MicroEtude generate(MicroEtudeRequest request) {
    final bpm = request.bpm.clamp(minBpm, maxBpm);
    final meter = request.meter;
    final miss = request.miss;
    final rng = _Rng(_mixSeed(request));

    // Cümleyi en uzundan (4 ölçü) başlayarak kur; süre uymazsa kısalt.
    final (plan, phraseBars) = _plan(meter, bpm);
    final bars = <EtudeBar>[];
    final rules = <String>[];
    switch (miss) {
      case NoteTransitionMiss():
        _transitionPhrase(miss, meter, phraseBars, rng, bars, rules);
      case RhythmMiss():
        _rhythmPhrase(miss, meter, phraseBars, rng, bars, rules);
    }
    final etude = MicroEtude(
      meter: meter,
      targetBpm: bpm,
      phrase: List.unmodifiable(bars),
      stages: plan,
      rules: List.unmodifiable(rules),
    );
    return etude;
  }

  // -- Kademe/süre planı -----------------------------------------------------

  static (List<EtudeStage>, int) _plan(EtudeMeter meter, int bpm) {
    const candidates = [
      (4, [60, 80, 100]),
      (3, [60, 80, 100]),
      (2, [60, 80, 100]),
      (4, [80, 100]),
      (3, [80, 100]),
      (2, [80, 100]),
      (2, [100]),
    ];
    for (final (bars, percents) in candidates) {
      final tempos = [
        for (final p in percents) (bpm * p / 100).round().clamp(30, maxBpm),
      ];
      final secs = [
        for (final t in tempos) bars * meter.quartersPerBar * 60 / t,
      ];
      final maxRep = tempos.length == 1 ? 16 : 6;
      List<int>? best;
      var bestDist = double.infinity;
      void search(int k, List<int> reps, double total) {
        if (total > maxSeconds) return;
        if (k == tempos.length) {
          if (total >= minSeconds && (total - aimSeconds).abs() < bestDist) {
            bestDist = (total - aimSeconds).abs();
            best = List.of(reps);
          }
          return;
        }
        for (var r = k == 0 ? 1 : reps[k - 1]; r <= maxRep; r++) {
          search(k + 1, [...reps, r], total + r * secs[k]);
        }
      }

      search(0, const [], 0);
      if (best != null) {
        return (
          [
            for (var i = 0; i < tempos.length; i++)
              EtudeStage(tempos[i], best![i]),
          ],
          bars,
        );
      }
    }
    throw StateError('Süre planı bulunamadı: bpm=$bpm meter=$meter');
  }

  // -- Geçiş etüdü -----------------------------------------------------------

  static void _transitionPhrase(
    NoteTransitionMiss miss,
    EtudeMeter meter,
    int phraseBars,
    _Rng rng,
    List<EtudeBar> bars,
    List<String> rules,
  ) {
    if (miss.fromMidi == miss.toMidi) {
      throw ArgumentError('Geçiş için iki farklı nota gerekir');
    }
    final a = _fold(miss.fromMidi);
    var b = _fold(miss.toMidi);
    while ((b - a).abs() > maxLeap) {
      b += b > a ? -12 : 12;
    }
    // Komşu ses C: B'nin ±2/±3 yarım ses yanı, menzil içinde.
    final options = [
      for (final d in const [2, -2, 3, -3])
        if (b + d >= lowestMidi && b + d <= highestMidi) b + d,
    ];
    final c = options[rng.next(options.length)];
    final pitch = {'A': a, 'B': b, 'C': c};

    EtudeBar bar(List<(String, int)> spec) =>
        EtudeBar([for (final (k, n) in spec) EtudeEvent(pitch[k], n)]);

    final alt = [
      for (var i = 0; i < meter.eighthsPerBar; i++) (i.isEven ? 'A' : 'B', 1),
    ];
    final (t1, t3, t4) = switch (meter) {
      EtudeMeter.fourFour => (
        [('A', 2), ('B', 2), ('A', 2), ('B', 2)],
        [('A', 2), ('B', 2), ('C', 2), ('B', 2)],
        [('A', 2), ('B', 6)],
      ),
      EtudeMeter.threeFour => (
        [('A', 2), ('B', 2), ('A', 2)],
        [('B', 2), ('C', 2), ('B', 2)],
        [('A', 2), ('B', 4)],
      ),
      EtudeMeter.sixEight => (
        [('A', 3), ('B', 3)],
        [('A', 3), ('B', 1), ('C', 1), ('B', 1)],
        [('A', 3), ('B', 3)],
      ),
    };
    void add(String rule, List<(String, int)> spec) {
      bars.add(bar(spec));
      rules.add(rule);
    }

    add('T1', t1);
    if (phraseBars >= 3) add('T2', alt);
    if (phraseBars >= 4) add('T3', t3);
    add('T4', t4);
  }

  // -- Ritim etüdü -----------------------------------------------------------

  static void _rhythmPhrase(
    RhythmMiss miss,
    EtudeMeter meter,
    int phraseBars,
    _Rng rng,
    List<EtudeBar> bars,
    List<String> rules,
  ) {
    final n = meter.eighthsPerBar;
    if (miss.slot < 0 || miss.slot >= n) {
      throw ArgumentError('slot 0..${n - 1} aralığında olmalı: ${miss.slot}');
    }
    const roots = [52, 45, 50, 55, 57];
    final p = miss.midi != null
        ? _fold(miss.midi!)
        : roots[rng.next(roots.length)];
    final q = p + 2 <= highestMidi ? p + 2 : p - 2;
    final s = miss.slot;
    final beats = meter.beatSlots;

    void add(String rule, Set<int> onsets, {int? leadIn}) {
      bars.add(
        _barFromOnsets(onsets, n, p, leadIn == null ? null : (leadIn, q)),
      );
      rules.add(rule);
    }

    add('R1', {...beats, s});
    add('R2', s == 0 ? {0, beats[1]} : {0, s});
    if (phraseBars >= 3) {
      if (miss.deviation == RhythmDeviation.late) {
        add('R3-leadin', {
          ...beats,
          if (s > 0) s - 1,
          s,
        }, leadIn: s > 0 ? s - 1 : null);
      } else {
        add('R3-wait', {
          s,
          for (final b in beats)
            if (b > s) b,
        });
      }
    }
    if (phraseBars >= 4) add('R4', {0});
  }

  /// Vuruş kümesinden ölçü kurar: her vuruş sonrakine kadar sürer; izin
  /// verilen uzunluklara sığmayan kalan kısım sus olur.
  static EtudeBar _barFromOnsets(
    Set<int> onsets,
    int barEighths,
    int pitch,
    (int slot, int pitch)? leadIn,
  ) {
    final sorted = onsets.toList()..sort();
    final events = <EtudeEvent>[];
    void rest(int length) {
      var left = length;
      while (left > 0) {
        final l = _allowed.firstWhere((a) => a <= left);
        events.add(EtudeEvent(null, l));
        left -= l;
      }
    }

    if (sorted.first > 0) rest(sorted.first);
    for (var i = 0; i < sorted.length; i++) {
      final end = i + 1 < sorted.length ? sorted[i + 1] : barEighths;
      final gap = end - sorted[i];
      final len = _allowed.firstWhere((a) => a <= gap);
      final isLead = leadIn != null && sorted[i] == leadIn.$1;
      events.add(EtudeEvent(isLead ? leadIn.$2 : pitch, len));
      rest(gap - len);
    }
    return EtudeBar(List.unmodifiable(events));
  }

  static int _fold(int midi) {
    var m = midi;
    while (m < lowestMidi) {
      m += 12;
    }
    while (m > highestMidi) {
      m -= 12;
    }
    return m;
  }

  static int _mixSeed(MicroEtudeRequest r) {
    var h = 2166136261;
    void mix(int v) => h = ((h ^ (v & 0xFFFFFFFF)) * 16777619) & 0xFFFFFFFF;
    mix(r.seed);
    mix(r.bpm);
    mix(r.meter.index);
    switch (r.miss) {
      case RhythmMiss(:final slot, :final deviation, :final midi):
        mix(1);
        mix(slot);
        mix(deviation.index);
        mix(midi ?? -1);
      case NoteTransitionMiss(:final fromMidi, :final toMidi):
        mix(2);
        mix(fromMidi);
        mix(toMidi);
    }
    return h;
  }
}

/// Taşınabilir xorshift32 (dart:math Random sürümler arası aynı akışı
/// garanti etmez).
final class _Rng {
  _Rng(int seed) : _s = seed & 0xFFFFFFFF == 0 ? 0x9E3779B9 : seed & 0xFFFFFFFF;

  int _s;

  int next(int bound) {
    _s ^= (_s << 13) & 0xFFFFFFFF;
    _s ^= _s >> 17;
    _s ^= (_s << 5) & 0xFFFFFFFF;
    return _s % bound;
  }
}
