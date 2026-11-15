/// OST-P1-01 — kural tabanlı kişisel mikro-etüt: girdi ve çıktı modelleri
/// (saf Dart; UI'ya, akışa ya da bayrağa bağlı değil).
///
/// Zaman ızgarası sekizlik nota: MIDI'de 240 tik (çeyrek = 480), MusicXML'de
/// `divisions` = 2. `bpm` her ölçüde ÇEYREK nota başına vuruştur.
library;

enum EtudeMeter {
  threeFour(3, 4),
  fourFour(4, 4),
  sixEight(6, 8);

  const EtudeMeter(this.beats, this.beatType);

  final int beats, beatType;

  /// Ölçüdeki sekizlik sayısı (3/4 → 6, 4/4 → 8, 6/8 → 6).
  int get eighthsPerBar => beats * 8 ~/ beatType;

  /// Ölçünün çeyrek nota cinsinden uzunluğu (6/8 → 3).
  double get quartersPerBar => beats * 4 / beatType;

  /// Ölçü içindeki vuruş başlangıçları (sekizlik cinsinden): 6/8'de noktalı
  /// çeyrek (0, 3), diğerlerinde çeyrek.
  List<int> get beatSlots {
    final step = this == sixEight ? 3 : 2;
    return [for (var s = 0; s < eighthsPerBar; s += step) s];
  }
}

/// Ritim kaçağı yönü: vuruş erken mi geç mi geldi.
enum RhythmDeviation { early, late }

sealed class MicroEtudeMiss {
  const MicroEtudeMiss();
}

/// Ritim sapması: ölçü içindeki [slot] (0 tabanlı sekizlik konumu) kaçtı.
/// [midi] verilirse etüt o notayla çalınır (menzile oktav katlanır).
final class RhythmMiss extends MicroEtudeMiss {
  const RhythmMiss({required this.slot, required this.deviation, this.midi});

  final int slot;
  final RhythmDeviation deviation;
  final int? midi;
}

/// Tek nota geçişi: [fromMidi] → [toMidi] geçişi kaçtı.
final class NoteTransitionMiss extends MicroEtudeMiss {
  const NoteTransitionMiss({required this.fromMidi, required this.toMidi});

  final int fromMidi, toMidi;
}

final class MicroEtudeRequest {
  const MicroEtudeRequest({
    required this.miss,
    required this.bpm,
    required this.meter,
    this.seed = 0,
  });

  final MicroEtudeMiss miss;

  /// Hedef tempo (çeyrek/dk); üretici 40–160'a sıkıştırır.
  final int bpm;
  final EtudeMeter meter;

  /// Aynı girdi + aynı tohum = aynı etüt.
  final int seed;
}

/// Bir ölçüdeki tek olay: nota ([midi] dolu) ya da sus ([midi] null).
final class EtudeEvent {
  const EtudeEvent(this.midi, this.eighths);

  final int? midi;
  final int eighths;

  bool get isRest => midi == null;
}

final class EtudeBar {
  const EtudeBar(this.events);

  final List<EtudeEvent> events;
}

/// Tempo kademesi: [repeats] kez çalınan cümle [bpm] tempoda.
final class EtudeStage {
  const EtudeStage(this.bpm, this.repeats);

  final int bpm, repeats;
}

final class MicroEtude {
  const MicroEtude({
    required this.meter,
    required this.targetBpm,
    required this.phrase,
    required this.stages,
    required this.rules,
  });

  final EtudeMeter meter;
  final int targetBpm;

  /// Cümle: 2–4 ölçü; her kademede [EtudeStage.repeats] kez çalınır.
  final List<EtudeBar> phrase;
  final List<EtudeStage> stages;

  /// Uygulanan kural kimlikleri, ölçü sırasıyla (şeffaflık ve test için).
  final List<String> rules;

  int get totalBars => stages.fold(0, (a, s) => a + s.repeats * phrase.length);

  /// Toplam çalma süresi (sn): ölçü uzunluğu ve kademe tempolarından.
  double get durationSeconds => stages.fold(
    0.0,
    (a, s) => a + s.repeats * phrase.length * meter.quartersPerBar * 60 / s.bpm,
  );

  /// Çalma sırasıyla (tempo, ölçü) listesi.
  List<({int bpm, EtudeBar bar})> get timeline => [
    for (final s in stages)
      for (var r = 0; r < s.repeats; r++)
        for (final bar in phrase) (bpm: s.bpm, bar: bar),
  ];
}
