// dart run tool/ost_p0_03_real_onset_replay.dart
//
// OST-P0-03: GERÇEK kayıtta onset ölçümü (salt ölçüm, test değil).
// Girdi: tool/fetch_guitarset_fixtures.py'nin SHA-256 doğrulamalı indirdiği
// GuitarSet (CC BY 4.0) mono-mic gitar eşlik (comping) kayıtları + JAMS
// `note_midi` notaları. Referans = JAMS'taki insan-doğrulamalı nota başlangıçları
// (6 tel birleşik); aynı strum içindeki notalar [clusterMs] içinde tek olaya
// birleştirilir ve olayın İLK nota zamanı referans alınır.
// Bu kayıtlar POLİFONİK eşliktir (monofonik değil) ve cihaz mikrofonu değildir.
//
// ÖNKOŞUL: `python3 tool/fetch_guitarset_fixtures.py` (SHA-256 pinli indirme).
// Bu betik her ham dosyanın SHA-256'sını fetch betiğindeki pinlerle (tek
// kaynak: o dosyanın `"dest"` / `"sha256"` çiftleri) KENDİSİ doğrular; dosya
// yoksa veya özet uyuşmazsa çıkış kodu != 0 olur ve ölçüm yapılmaz.
import 'dart:convert';
import 'dart:io';

import 'package:ostinato_audio/ostinato_audio.dart';

import 'audio_fixture_io.dart';

const clusterMs = 70.0;
const matchWindowMs = 100.0;
const tracks = [
  '00_BN1-129-Eb_comp',
  '00_BN3-119-G_comp',
  '00_Jazz2-110-Bb_comp',
];

/// fetch_guitarset_fixtures.py'deki `dest` -> `sha256` pinleri (tek kaynak).
Map<String, String> loadPins() {
  final src = File('tool/fetch_guitarset_fixtures.py').readAsStringSync();
  final re = RegExp(r'"dest":\s*"([^"]+)",\s*"sha256":\s*"([0-9a-f]{64})"');
  return {for (final m in re.allMatches(src)) m.group(1)!: m.group(2)!};
}

/// `shasum -a 256` (macOS) ile ham dosyayı doğrular; sorun varsa false.
bool verifySha(File f, String expected) {
  final r = Process.runSync('shasum', ['-a', '256', f.path]);
  if (r.exitCode != 0) return false;
  return (r.stdout as String).split(' ').first == expected;
}

double pct(List<double> v, double p) {
  final s = List<double>.from(v)..sort();
  return s.isEmpty ? double.nan : s[((s.length - 1) * p).round()];
}

String f1(double v) => v.isNaN ? 'NA' : v.toStringAsFixed(1);

double meanOf(List<double> v) =>
    v.isEmpty ? double.nan : v.reduce((a, b) => a + b) / v.length;

void main() {
  const detector = OnsetDetector();
  final pins = loadPins();
  for (final t in tracks) {
    for (final name in ['guitarset_${t}_mic.wav', 'guitarset_$t.jams']) {
      final f = File('fixtures/audio-real/raw/$name');
      final pin = pins[name];
      if (!f.existsSync()) {
        stderr.writeln('[OST-P0-03-real] HATA: $name yok - önce '
            'python3 tool/fetch_guitarset_fixtures.py koşulmalı.');
        exitCode = 2;
        return;
      }
      if (pin == null || !verifySha(f, pin)) {
        stderr.writeln('[OST-P0-03-real] HATA: $name SHA-256 pin '
            'uyuşmazlığı veya pin yok - ölçüm yapılmadı.');
        exitCode = 3;
        return;
      }
    }
  }
  stdout.writeln('[OST-P0-03-real] ham dosyalar SHA-256 pinleriyle doğrulandı '
      '(${tracks.length * 2}/${tracks.length * 2}).');

  final allErr = <double>[];
  var truthTotal = 0, missedTotal = 0, extraTotal = 0;
  for (final t in tracks) {
    final wav = File('fixtures/audio-real/raw/guitarset_${t}_mic.wav');
    final jams = File('fixtures/audio-real/raw/guitarset_$t.jams');
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
    if (truthMs.isEmpty) {
      stderr.writeln('[OST-P0-03-real] HATA: $t için referans olay yok.');
      exitCode = 4;
      return;
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
        'hata_ms: med=${f1(pct(abs, .5))} p95=${f1(pct(abs, .95))} '
        'ort=${f1(meanOf(abs))} yanlılık(işaretli med)=${f1(pct(errs, .5))} '
        'kaçan=${(100 * missed / truthMs.length).toStringAsFixed(1)}% '
        'fazla=${(100 * extra / truthMs.length).toStringAsFixed(1)}%');
    allErr.addAll(errs);
    truthTotal += truthMs.length;
    missedTotal += missed;
    extraTotal += extra;
  }
  final abs = allErr.map((e) => e.abs()).toList();
  stdout.writeln('[OST-P0-03-real] TOPLAM referans=$truthTotal '
      'hata_ms: med=${f1(pct(abs, .5))} p95=${f1(pct(abs, .95))} '
      'yanlılık=${f1(pct(allErr, .5))} '
      'kaçan=${(100 * missedTotal / truthTotal).toStringAsFixed(1)}% '
      'fazla=${(100 * extraTotal / truthTotal).toStringAsFixed(1)}%');
}
