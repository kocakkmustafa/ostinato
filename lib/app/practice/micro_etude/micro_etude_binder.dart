/// OST-P1-01 — practice sonucundan mikro-etüt isteği türeten bağlayıcı
/// (saf Dart; UI'ya ya da akışa bağlı değil, bayrağı `ostinatoMicroEtudeEnabled`).
library;

import 'dart:math' as math;

import '../loop/practice_marks.dart';
import '../loop/practice_outcome.dart';
import 'micro_etude_generator.dart';
import 'micro_etude_models.dart';

/// Eşleme kuralı (tümü deterministik):
/// - Ölçülmemiş koşu (`!gate.eligible`) ya da kararlaştırılmış hata yok: null.
///   Yalnız "farklı nota" işaretleri hata sayılır; "duyamadım" karar değildir.
/// - Zamanlama hatası: ritim satırında her hata; nota satırında `timingMs`
///   eşiği (`onTimeMs`, yoksa 90 ms) aşan hata. Perde hatası: beklenen ve
///   duyulan nota farklı. Zamanlama sayısı ≥ perde sayısıysa [RhythmMiss]
///   (sapma yönü: en büyük |timingMs| hatanın işareti; negatif = erken).
/// - Aksi hâlde tam olarak TEK perde hatası ve önceki notanın beklenen perdesi
///   biliniyorsa [NoteTransitionMiss]; birden çok perde hatası desteklenmez: null.
/// - `slot`: hatalı notanın ölçü içindeki sırası, ölçünün vuruş
///   başlangıçlarına (`beatSlots`) döngüsel eşlenir (özet nota süresini
///   taşımadığı için yaklaşıktır).
/// - `bpm` üreticinin kabul ettiği [MicroEtudeGenerator.minBpm]–[maxBpm]
///   aralığına kıstırılır.
MicroEtudeRequest? microEtudeRequestFromSummary(
  PracticeRunSummary s, {
  required EtudeMeter meter,
  required int seed,
}) {
  if (!s.gate.eligible) return null;
  final last = [...s.lastMarks.values]
    ..sort((a, b) => a.eventIndex.compareTo(b.eventIndex));
  final errors = [
    for (final o in last)
      if (o.mark == PracticeMark.differentNote) o,
  ];
  if (errors.isEmpty) return null;

  final window = (s.gate.criteria.onTimeMs ?? 90).toDouble();
  final rhythmLine = s.gate.criteria.rhythm;
  final timing = <NoteOutcome>[];
  final pitch = <NoteOutcome>[];
  for (final o in errors) {
    final t = o.timingMs;
    final isTiming = rhythmLine ? t != null : t != null && t.abs() > window;
    final isPitch =
        !rhythmLine &&
        o.expectedMidi != null &&
        o.observedMidi != null &&
        o.expectedMidi != o.observedMidi;
    if (isTiming) timing.add(o);
    if (isPitch && !isTiming) pitch.add(o);
  }
  final bpm = s.bpm.clamp(
    MicroEtudeGenerator.minBpm,
    MicroEtudeGenerator.maxBpm,
  );

  if (timing.isNotEmpty && timing.length >= pitch.length) {
    var worst = timing.first;
    for (final o in timing) {
      if (o.timingMs!.abs() > worst.timingMs!.abs()) worst = o;
    }
    final inBar = [
      for (final o in last)
        if (o.bar == worst.bar) o.eventIndex,
    ];
    final pos = inBar.indexOf(worst.eventIndex);
    final slots = meter.beatSlots;
    return MicroEtudeRequest(
      miss: RhythmMiss(
        slot: slots[math.max(pos, 0) % slots.length],
        deviation: worst.timingMs! < 0
            ? RhythmDeviation.early
            : RhythmDeviation.late,
        midi: worst.expectedMidi,
      ),
      bpm: bpm,
      meter: meter,
      seed: seed,
    );
  }

  if (pitch.length == 1) {
    final to = pitch.single;
    final from = s.lastMarks[to.eventIndex - 1]?.expectedMidi;
    final toMidi = to.expectedMidi;
    if (from == null || toMidi == null || from == toMidi) return null;
    return MicroEtudeRequest(
      miss: NoteTransitionMiss(fromMidi: from, toMidi: toMidi),
      bpm: bpm,
      meter: meter,
      seed: seed,
    );
  }
  return null;
}
