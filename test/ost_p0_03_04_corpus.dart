// OST-P0-03 / OST-P0-04 ortak SENTETİK test corpus'u.
//
// Her şey tohumlu (seeded) ve deterministiktir; ağ/indirme/dosya gerekmez.
// Bu bir GERÇEK KAYIT DEĞİLDİR: tüm sinyaller `SyntheticTone` (harmonik ton) +
// bu dosyadaki gürültü/yankı üreteçleridir. Ölçüm sonuçları TEST_ONLY'dir.
import 'dart:math' as math;

const int corpusSampleRate = 44100;

/// Tek bir SNR ölçüm tanımı: gürültü, sinyalin NOTA-AKTİF örneklerinin RMS'ine
/// göre ölçeklenir (|x| > 1e-4); aralardaki sessizlik hesaba katılmaz.
double activeRms(List<double> x) {
  var sum = 0.0;
  var n = 0;
  for (final v in x) {
    if (v.abs() > 1e-4) {
      sum += v * v;
      n++;
    }
  }
  return n == 0 ? 0 : math.sqrt(sum / n);
}

double rmsDbOf(List<double> x) {
  if (x.isEmpty) return -160;
  var s = 0.0;
  for (final v in x) {
    s += v * v;
  }
  final r = math.sqrt(s / x.length);
  return r <= 1e-9 ? -160 : 20 * math.log(r) / math.ln10;
}

/// Birim-RMS beyaz gürültü (Gauss, Box-Muller).
List<double> whiteNoise(int n, {required int seed}) {
  final rng = math.Random(seed);
  final out = List<double>.filled(n, 0);
  for (var i = 0; i < n; i += 2) {
    final u1 = math.max(rng.nextDouble(), 1e-12);
    final u2 = rng.nextDouble();
    final r = math.sqrt(-2 * math.log(u1));
    out[i] = r * math.cos(2 * math.pi * u2);
    if (i + 1 < n) out[i + 1] = r * math.sin(2 * math.pi * u2);
  }
  return out;
}

/// Pembe gürültü (Paul Kellet'in 3 kutuplu yaklaşımı), birim-RMS'e normalize.
List<double> pinkNoise(int n, {required int seed}) {
  final w = whiteNoise(n, seed: seed);
  var b0 = 0.0, b1 = 0.0, b2 = 0.0;
  final out = List<double>.filled(n, 0);
  for (var i = 0; i < n; i++) {
    b0 = 0.99765 * b0 + w[i] * 0.0990460;
    b1 = 0.96300 * b1 + w[i] * 0.2965164;
    b2 = 0.57000 * b2 + w[i] * 1.0526913;
    out[i] = b0 + b1 + b2 + w[i] * 0.1848;
  }
  var s = 0.0;
  for (final v in out) {
    s += v * v;
  }
  final r = math.sqrt(s / n);
  return out.map((v) => v / r).toList();
}

enum NoiseKind { white, pink }

List<double> unitNoise(NoiseKind kind, int n, {required int seed}) =>
    kind == NoiseKind.white
        ? whiteNoise(n, seed: seed)
        : pinkNoise(n, seed: seed);

/// [signal] + gürültü, nota-aktif RMS'e göre [snrDb]. Döner: karışım ve
/// yalnız-gürültü kesiti (oda tabanını kalibre etmek için, Setup Check gibi).
({List<double> mixed, List<double> noiseOnly}) addNoiseSnr(
  List<double> signal, {
  required NoiseKind kind,
  required double snrDb,
  required int seed,
}) {
  final noise = unitNoise(kind, signal.length, seed: seed);
  final gain = activeRms(signal) / math.pow(10, snrDb / 20);
  final scaled = noise.map((v) => v * gain).toList();
  return (
    mixed: List<double>.generate(signal.length, (i) => signal[i] + scaled[i]),
    noiseOnly: scaled,
  );
}

/// Seyrek tohumlu yankı IR'ı ile evrişim: doğrudan ses + [taps] gecikmeli kopya
/// (20 ms..[maxDelayMs], üstel sönüm, [rt60Seconds]). Oda yankısının kaba,
/// tekrarlanabilir bir modeli; gerçek bir odanın ölçümü DEĞİLDİR.
List<double> addEcho(
  List<double> x, {
  required int seed,
  int taps = 48,
  double maxDelayMs = 400,
  double rt60Seconds = 0.6,
  double wet = 1.0,
}) {
  final rng = math.Random(seed);
  final delays = <int>[];
  final gains = <double>[];
  for (var k = 0; k < taps; k++) {
    final dMs = 20 + rng.nextDouble() * (maxDelayMs - 20);
    final g = math.pow(10, -3 * (dMs / 1000) / rt60Seconds).toDouble() *
        (rng.nextBool() ? 1 : -1) *
        (0.3 + 0.7 * rng.nextDouble()) /
        math.sqrt(taps / 8);
    delays.add((dMs * corpusSampleRate / 1000).round());
    gains.add(g * wet);
  }
  final out = List<double>.from(x);
  for (var t = 0; t < taps; t++) {
    final d = delays[t];
    final g = gains[t];
    for (var i = d; i < x.length; i++) {
      out[i] += g * x[i - d];
    }
  }
  return out;
}

double percentile(List<double> values, double p) {
  if (values.isEmpty) return double.nan;
  final s = List<double>.from(values)..sort();
  return s[((s.length - 1) * p).round()];
}

double mean(List<double> v) =>
    v.isEmpty ? double.nan : v.reduce((a, b) => a + b) / v.length;

/// Bire-bir, en yakın eşleme (greedy, her tespit en çok bir referansa).
/// Döner: eşleşen çiftlerin işaretli hatası (ms, tespit − referans), kaçan
/// (referansta olup tespitte olmayan) ve fazla (tespitte olup referansta
/// olmayan) sayıları.
({List<double> errorsMs, int missed, int extra}) matchOnsets(
  List<int> truthUs,
  List<int> detectedUs, {
  double windowMs = 100,
}) {
  final used = <int>{};
  final errs = <double>[];
  var missed = 0;
  for (final t in truthUs) {
    int? best;
    var bestAbs = double.infinity;
    for (var i = 0; i < detectedUs.length; i++) {
      if (used.contains(i)) continue;
      final a = (detectedUs[i] - t).abs() / 1000.0;
      if (a < bestAbs) {
        bestAbs = a;
        best = i;
      }
    }
    if (best == null || bestAbs > windowMs) {
      missed++;
    } else {
      used.add(best);
      errs.add((detectedUs[best] - t) / 1000.0);
    }
  }
  return (
    errorsMs: errs,
    missed: missed,
    extra: detectedUs.length - used.length
  );
}

/// Bilinen vuruş zamanlı metronom ritmi. Referans (truth) zamanları BİLİNEN
/// vuruş zamanlarıdır: ızgara + kasıtlı kayma; çalınmayan vuruşlar [skipBeats]
/// ile çıkarılır; ızgarada olmayan fazla vuruşlar [extraOffsetsSeconds] ile
/// eklenir (ızgaraya göre ofsetli saniye).
final class RhythmCase {
  RhythmCase({
    required this.bpm,
    required this.samples,
    required this.gridUs,
    required this.playedUs,
  });
  final int bpm;
  final List<double> samples;

  /// Metronom ızgarası (ideal vuruş zamanları, µs).
  final List<int> gridUs;

  /// Gerçekte çalınan vuruşların (kaymalı + fazlalıklı) tam zamanları, µs.
  final List<int> playedUs;
}

RhythmCase buildRhythm({
  required int bpm,
  required List<double> Function(
          {required List<double> onsetSeconds, required double totalSeconds})
      render,
  int beats = 8,
  double leadSeconds = 0.5,
  Map<int, double> shiftMsByBeat = const {},
  double uniformShiftMs = 0,
  Set<int> skipBeats = const {},
  List<double> extraOffsetsSeconds = const [],
}) {
  final period = 60.0 / bpm;
  final grid = <int>[];
  final played = <double>[];
  for (var b = 0; b < beats; b++) {
    final tGrid = leadSeconds + b * period;
    grid.add((tGrid * 1e6).round());
    if (skipBeats.contains(b)) continue;
    played.add(tGrid + (uniformShiftMs + (shiftMsByBeat[b] ?? 0)) / 1000);
  }
  for (final e in extraOffsetsSeconds) {
    played.add(leadSeconds + e);
  }
  played.sort();
  final total = leadSeconds + beats * period + 0.6;
  return RhythmCase(
    bpm: bpm,
    samples: render(onsetSeconds: played, totalSeconds: total),
    gridUs: grid,
    playedUs: played.map((s) => (s * 1e6).round()).toList(),
  );
}

/// Açık gitar telleri (E2..E4), 12-TET, A4 = 440 Hz.
const Map<String, int> guitarOpenStrings = {
  'E2': 40,
  'A2': 45,
  'D3': 50,
  'G3': 55,
  'B3': 59,
  'E4': 64,
};

double midiToHz(int midi) => 440.0 * math.pow(2, (midi - 69) / 12).toDouble();

double hzWithCents(int midi, double cents) =>
    midiToHz(midi) * math.pow(2, cents / 1200).toDouble();

double centsBetween(double a, double b) => 1200 * math.log(a / b) / math.ln2;
