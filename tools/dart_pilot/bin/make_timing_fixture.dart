import 'dart:convert';
import 'dart:io';

import 'package:ostinato_audio/ostinato_audio.dart';

/// Zamanlama fixture'ı — `note_timing_ms` metriğini VAAT olmaktan çıkarıp
/// ÖLÇÜM yapar (ders-yolu paketi, madde 1).
///
/// Neden gerekliydi: piyano ruleset'i PLAY fazında `note_timing_ms <= 50`
/// diye bir quality kapısı taşıyordu, ama o metriği ÜRETEN hiçbir kalıcı
/// kayıt yoktu — `replay_check.audio_windows()` yalnız level/periodicity/
/// pitch_deviation döndürür. Yani kapı, motoru olmayan bir metriğe
/// bakıyordu (fazın sessizce ölü olması sınıfı). `MetronomeAligner` KODU
/// vardı ve birim testleri geçiyordu, ama hiçbir fixture'a bağlanmamıştı:
/// "kod var, tüketicisi yok" — M-O-53'ün ölçüm tarafındaki kardeşi.
///
/// `make_chord_fixture.dart` ile AYNI desen (M-F-116): sinyal SENTEZLENİR,
/// GERÇEK motordan (`OnsetDetector` → `MetronomeAligner`) geçirilir, motorun
/// ÖLÇTÜĞÜ yazılır. Değer uydurulmaz.
///
/// AYRIM — bu fixture üç varyant taşır, biri değil:
///   perfect  : notalar tam ızgarada
///   rushing  : her nota 40 ms ERKEN
///   dragging : her nota 40 ms GEÇ
/// Tek "kusursuz" varyantlı bir fixture, `align()` her zaman 0 döndürse de
/// AYNI ŞEKİLDE geçerdi — yani motorun çalıştığını değil, sustuğunu
/// kanıtlardı. Üç varyant, ölçümü bir AYIRT ETME testine çevirir; negatif
/// fixture zorunluluğunun (fixtures/audio/index.json §why) zamanlama
/// karşılığı.
void main(List<String> args) {
  final outDir = Directory(args.isEmpty ? '../../fixtures/audio' : args.first)
    ..createSync(recursive: true);

  const sampleRate = 44100;
  // AF-003 ile AYNI ızgara (120 bpm, beş nota) — o fixture'ın `clickTimesUs`u
  // zaten bu; aynı malzemeyi kullanmak iki kaydın karşılaştırılabilir
  // kalmasını sağlıyor.
  const gridSeconds = [0.5, 1.0, 1.5, 2.0, 2.5];
  const beatTimesUs = [500000, 1000000, 1500000, 2000000, 2500000];
  const totalSeconds = 3.2;

  // Ruleset'in kendi sinyal-koşullama sözleşmesi (piano@0.2.0-draft
  // signalConditioning). Fixture, config'in söylediğinden BAŞKA bir
  // dedektörle ölçülürse ölçüm ürünle ilgisiz olur.
  const detector = OnsetDetector(
    frameMs: 46,
    hopMs: 6,
    medianWindow: 11,
    bandCount: 24,
    minAnalysisHz: 40,
    maxAnalysisHz: 4000,
  );
  const aligner = MetronomeAligner();

  const variants = <String, double>{
    'perfect': 0.0,
    'rushing': -0.040,
    'dragging': 0.040,
  };

  final measured = <String, dynamic>{};
  final problems = <String>[];

  for (final v in variants.entries) {
    final onsetSeconds = [for (final s in gridSeconds) s + v.value];
    final signal = SyntheticTone.notesAt(
      onsetSeconds: onsetSeconds,
      f0Hz: ReferencePitches.c5,
      sampleRate: sampleRate,
      totalSeconds: totalSeconds,
    );

    final onsets = detector.detect(signal, sampleRate: sampleRate, tStartUs: 0);
    final report = aligner.align(onsets: onsets, beatTimesUs: beatTimesUs);

    measured[v.key] = {
      'offsetAppliedMs': (v.value * 1000).round(),
      'onsetsDetected': onsets.length,
      'matchedBeats': report.matchedBeats,
      'totalBeats': report.totalBeats,
      'coverage': double.parse(report.coverage.toStringAsFixed(3)),
      'noteTimingMs': double.parse(report.medianMs.toStringAsFixed(2)),
      'spreadMs': double.parse(report.spreadMs.toStringAsFixed(2)),
      'bias': report.bias.name,
      'deviationsMs': [
        for (final d in report.deviations) double.parse(d.deviationMs.toStringAsFixed(2)),
      ],
    };

    // Kapı 1: her varyantta beş vuruşun beşi de eşleşmeli. Eşleşmeyen vuruş,
    // ölçülmemiş vuruştur — medyanı iyi göstererek kapsamı gizler.
    if (report.matchedBeats != beatTimesUs.length) {
      problems.add('${v.key}: ${report.matchedBeats}/${beatTimesUs.length} vuruş eşleşti');
    }
    // Kapı 2: AYIRT ETME. Yön doğru raporlanmalı, yoksa fixture motorun
    // sustuğunu kanıtlar.
    final expectedBias = v.value < 0
        ? TimingBias.rushing
        : v.value > 0
            ? TimingBias.dragging
            : TimingBias.centred;
    if (report.bias != expectedBias) {
      problems.add('${v.key}: bias ${report.bias.name}, beklenen ${expectedBias.name}');
    }
  }

  // Motorun kendi TABANI: kusursuz çalışta bile sıfır ölçülmez. Bu artık
  // bilinen ve KAYITLI bir sistematik (STFT karesi pencerenin ortasını
  // temsil eder; O-019'un ikinci kusuru merkez-damgayla düzeltildi, kalan
  // artık pencere çözünürlüğünün kendisi). Pedagojik hiçbir eşik bu tabanın
  // ALTINA yazılamaz — yazılırsa kusursuz çalan öğrenciye hata söyler.
  final floorMs = measured['perfect']['noteTimingMs'] as double;

  final ok = problems.isEmpty;
  const fixtureId = 'AF-008-five-note-timing';
  File('${outDir.path}/$fixtureId.json').writeAsStringSync(
      const JsonEncoder.withIndent(' ').convert({
    'schemaVersion': 'ostinato-audiofix-timing-1',
    'fixtureId': fixtureId,
    'kind': 'synthetic',
    r'$what': 'Five notes on a 120 bpm grid, played three ways: on the grid, '
        '40 ms early, 40 ms late. Real engine (OnsetDetector -> MetronomeAligner) '
        'measured, not authored. This is the first persisted record of '
        '`note_timing_ms` — before it, the piano ruleset gated on a metric no '
        'engine produced.',
    'recordingMeta': {
      'source': 'generated',
      'sampleRate': sampleRate,
      'license': 'generated',
      r'$note': 'Synthetic — the grid is exact by construction, so the '
          'deviation measured on the `perfect` variant is the ENGINE floor, '
          'not a performance. NOT proof on a real piano (pedal blur, key '
          'noise, uneven touch are absent).',
    },
    'engineVersions': {
      'onset': 'OnsetDetector (spectral flux, log-spaced bands) @ piano '
          'signalConditioning (frame 46 ms / hop 6 ms / 24 bands / 40-4000 Hz)',
      'timing': 'MetronomeAligner (median + IQR spread + signed bias)',
    },
    'expected': {
      'beatTimesUs': beatTimesUs,
      'variants': {for (final v in variants.entries) v.key: (v.value * 1000).round()},
      'allBeatsMustMatch': true,
      'biasMustDiscriminate': true,
    },
    'measured': measured,
    'derived': {
      'engineFloorMs': floorMs,
      r'$why': 'Kusursuz ızgarada ölçülen sapma. `note_timing_ms` için hiçbir '
          'kapı bu değerin altına yazılamaz — yazılırsa tam zamanında çalan '
          'öğrenciye "geç kaldın" der. Bu bir PEDAGOJİK eşik DEĞİL, ölçüm '
          'tabanıdır: hangi zamanlama farkının öğretmence "hata" sayıldığı '
          'referans hasadından gelmek zorunda ve o hasat YOK.',
    },
    'ok': ok,
  }));

  stdout.writeln('$fixtureId:');
  for (final e in measured.entries) {
    final m = e.value as Map<String, dynamic>;
    stdout.writeln('  ${e.key.padRight(9)} note_timing_ms=${m['noteTimingMs']}'
        '  spread=${m['spreadMs']}  bias=${m['bias']}'
        '  eşleşen=${m['matchedBeats']}/${m['totalBeats']}');
  }
  stdout.writeln('  motor tabanı (kusursuz çalış): \$floorMs ms');
  if (!ok) {
    for (final p in problems) {
      stdout.writeln('  ⛔ $p');
    }
  }
  stdout.writeln(ok ? '✅ üç varyant da ayırt edildi' : '❌ ayırt etme BAŞARISIZ');
  exit(ok ? 0 : 1);
}
