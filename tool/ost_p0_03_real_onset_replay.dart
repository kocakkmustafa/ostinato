// dart run tool/ost_p0_03_real_onset_replay.dart
//
// OST-P0-03: GERÇEK kayıtta onset ölçümü (salt ölçüm, test değil).
// Girdi: tool/fetch_guitarset_fixtures.py'nin SHA-256 doğrulamalı indirdiği
// GuitarSet (CC BY 4.0) mono-mic gitar eşlik (comping) kayıtları + JAMS
// `note_midi` notaları. Referans = JAMS'taki insan-doğrulamalı nota başlangıçları
// (6 tel birleşik); aynı strum içindeki notalar [clusterMs] içinde tek olaya
// birleştirilir ve olayın İLK nota zamanı referans alınır.
// Bu kayıtlar POLİFONİK eşliktir (monofonik değil) ve cihaz mikrofonu değildir.
// Ham ses yoksa (fetch koşulmadıysa) isimli olarak çıkar.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:ostinato_audio/ostinato_audio.dart';

import 'audio_fixture_io.dart';

const clusterMs = 70.0;
const matchWindowMs = 100.0;
const tracks = [
  '00_BN1-129-Eb_comp',
  '00_BN3-119-G_comp',
  '00_Jazz2-110-Bb_comp',
];

double pct(List<double> v, double p) {
  final s = List<double>.from(v)..sort();
  return s.isEmpty ? double.nan : s[((s.length - 1) * p).round()];
}

void main() {
  const detector = OnsetDetector();
  final allErr = <double>[];
  var truthTotal = 0, missedTotal = 0, extraTotal = 0;
  for (final t in tracks) {
    final wav = File('fixtures/audio-real/raw/guitarset_${t}_mic.wav');
    final jams = File('fixtures/audio-real/raw/guitarset_$t.jams');
    if (!wav.existsSync() || !jams.existsSync()) {
      stdout.writeln('[OST-P0-03-real] $t atlandı: ham dosya yok '
          '(python3 tool/fetch_guitarset_fixtures.py koşulmadı)');
      continue;
    }
    final pcm = PcmWav.readFile(wav.path);
    final samples = pcm.toMono();
    final ann = jsonDecode(jams.readAsStringSync()) as Map<String, dynamic>;
    final times = <double>[];
    for (final a in (ann['annotations'] as List)) {
      if (a['namespace'] != 'note_midi') continue;
      for (final n in (a['data'] as List)) {
        times.add((n['time'] as num).toDouble());
      }
    }
    times.sort();
    final truthMs = <double>[];
    for (final s in times) {
      if (truthMs.isEmpty || s * 1000 - truthMs.last > clusterMs) {
        truthMs.add(s * 1000);
      }
    }
    final det = detector
        .detect(samples, sampleRate: pcm.sampleRate, tStartUs: 0)
        .map((o) => o.tUs / 1000.0)
        .toList();
    final used = <int>{};
    final errs = <double>[];
    var missed = 0;
    for (final r in truthMs) {
      int? best;
      var bestAbs = double.infinity;
      for (var i = 0; i < det.length; i++) {
        if (used.contains(i)) continue;
        final a = (det[i] - r).abs();
        if (a < bestAbs) {
          bestAbs = a;
          best = i;
        }
      }
      if (best == null || bestAbs > matchWindowMs) {
        missed++;
      } else {
        used.add(best);
        errs.add(det[best] - r);
      }
    }
    final extra = det.length - used.length;
    final abs = errs.map((e) => e.abs()).toList();
    stdout.writeln('[OST-P0-03-real] $t süre=${(samples.length / pcm.sampleRate).toStringAsFixed(1)}s '
        'referans=${truthMs.length} tespit=${det.length} '
        'hata_ms: med=${pct(abs, .5).toStringAsFixed(1)} '
        'p95=${pct(abs, .95).toStringAsFixed(1)} '
        'ort=${(abs.reduce((a, b) => a + b) / math.max(1, abs.length)).toStringAsFixed(1)} '
        'yanlılık(işaretli med)=${pct(errs, .5).toStringAsFixed(1)} '
        'kaçan=${(100 * missed / truthMs.length).toStringAsFixed(1)}% '
        'fazla=${(100 * extra / truthMs.length).toStringAsFixed(1)}%');
    allErr.addAll(errs);
    truthTotal += truthMs.length;
    missedTotal += missed;
    extraTotal += extra;
  }
  if (truthTotal > 0) {
    final abs = allErr.map((e) => e.abs()).toList();
    stdout.writeln('[OST-P0-03-real] TOPLAM referans=$truthTotal '
        'hata_ms: med=${pct(abs, .5).toStringAsFixed(1)} '
        'p95=${pct(abs, .95).toStringAsFixed(1)} '
        'yanlılık=${pct(allErr, .5).toStringAsFixed(1)} '
        'kaçan=${(100 * missedTotal / truthTotal).toStringAsFixed(1)}% '
        'fazla=${(100 * extraTotal / truthTotal).toStringAsFixed(1)}%');
  }
}
