// ignore_for_file: avoid_print
// OST-P0-03: onset/tempo ölçümü — SENTETİK, tohumlu corpus (TEST_ONLY).
// Üretim DSP'si: OnsetDetector + MetronomeAligner. Hiçbir şey ağdan gelmez.
// Ölçülen sayılar `[OST-P0-03]` önekiyle stdout'a yazılır; rapor bunlardan.
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato_audio/ostinato_audio.dart';

import 'ost_p0_03_04_corpus.dart';

const _sr = corpusSampleRate;
const _detector = OnsetDetector();
const _f0 = 196.0; // G3, açık tel

List<double> _render(
        {required List<double> onsetSeconds, required double totalSeconds}) =>
    SyntheticTone.notesAt(
        onsetSeconds: onsetSeconds,
        f0Hz: _f0,
        sampleRate: _sr,
        totalSeconds: totalSeconds);

List<int> _detect(List<double> x) => _detector
    .detect(x, sampleRate: _sr, tStartUs: 0)
    .map((o) => o.tUs)
    .toList();

class _Agg {
  final errs = <double>[];
  int missed = 0, extra = 0, truth = 0, runs = 0;
  final tempoErr = <double>[];
  void add(RhythmCase c, List<int> det) {
    final m = matchOnsets(c.playedUs, det);
    errs.addAll(m.errorsMs);
    missed += m.missed;
    extra += m.extra;
    truth += c.playedUs.length;
    runs++;
    // Tempo: üretimde tempo kestirici YOK; testte tespit edilen vuruşların
    // medyan IOI'sinden türetilir (yalnız ölçüm amaçlı).
    if (det.length >= 3) {
      final iois = <double>[];
      for (var i = 1; i < det.length; i++) {
        iois.add((det[i] - det[i - 1]) / 1e6);
      }
      tempoErr.add((60 / percentile(iois, 0.5) - c.bpm).abs());
    }
  }

  double get missRate => truth == 0 ? 0 : missed / truth;
  double get extraRate => truth == 0 ? 0 : extra / truth;
  String line(String label) =>
      '[OST-P0-03] $label n=$runs vuruş=$truth hata_ms: '
      'ort=${mean(errs.map((e) => e.abs()).toList()).toStringAsFixed(1)} '
      'med=${percentile(errs.map((e) => e.abs()).toList(), 0.5).toStringAsFixed(1)} '
      'p95=${percentile(errs.map((e) => e.abs()).toList(), 0.95).toStringAsFixed(1)} '
      'yanlılık(işaretli med)=${percentile(errs, 0.5).toStringAsFixed(1)} '
      'tempo_hata_BPM_med=${percentile(tempoErr, 0.5).toStringAsFixed(2)} '
      'kaçan=${(missRate * 100).toStringAsFixed(1)}% '
      'fazla=${(extraRate * 100).toStringAsFixed(1)}%';
}

void main() {
  const bpms = [60, 90, 120];

  group('onset: temiz metronom (60/90/120 BPM)', () {
    final all = _Agg();
    for (final bpm in bpms) {
      test('$bpm BPM temiz', () {
        final c = buildRhythm(bpm: bpm, render: _render);
        final det = _detect(c.samples);
        final a = _Agg()..add(c, det);
        all.add(c, det);
        print(a.line('temiz $bpm BPM'));
        expect(a.missed, 0);
        expect(a.extra, 0);
        expect(percentile(a.errs.map((e) => e.abs()).toList(), 0.95),
            lessThan(45));
        expect(a.tempoErr.single, lessThan(1.0));
      });
    }
    tearDownAll(() => print(all.line('temiz TOPLAM')));
  });

  group('onset: gürültü SNR 20/10/5 dB (beyaz+pembe, 3 tohum)', () {
    for (final kind in NoiseKind.values) {
      for (final snr in [20.0, 10.0, 5.0]) {
        test('${kind.name} $snr dB', () {
          final a = _Agg();
          for (final bpm in bpms) {
            for (final seed in [1, 2, 3]) {
              final c = buildRhythm(bpm: bpm, render: _render);
              final noisy = addNoiseSnr(c.samples,
                  kind: kind, snrDb: snr, seed: seed * 100 + bpm);
              a.add(c, _detect(noisy.mixed));
            }
          }
          print(a.line('${kind.name} SNR=${snr.toInt()}dB'));
          // Dürüst eşikler: ölçüm sonrası, ölçülen değerin üstünde pay ile.
          final bound = _bounds['${kind.name}$snr']!;
          expect(a.missRate, lessThanOrEqualTo(bound.miss));
          expect(a.extraRate, lessThanOrEqualTo(bound.extra));
          expect(percentile(a.errs.map((e) => e.abs()).toList(), 0.95),
              lessThanOrEqualTo(bound.p95));
        });
      }
    }
  });

  group('onset: yankı', () {
    test('seyrek-IR yankı (RT60 0.6 s) altında kaçan/fazla', () {
      final a = _Agg();
      for (final bpm in bpms) {
        for (final seed in [1, 2, 3]) {
          final c = buildRhythm(bpm: bpm, render: _render);
          a.add(c, _detect(addEcho(c.samples, seed: seed)));
        }
      }
      print(a.line('yankı RT60=0.6s'));
      expect(a.missRate, lessThanOrEqualTo(_bounds['echo']!.miss));
      expect(a.extraRate, lessThanOrEqualTo(_bounds['echo']!.extra));
    });
  });

  group('onset: sessizlik', () {
    test('sayısal sessizlik: sıfır vuruş', () {
      expect(_detect(List<double>.filled(_sr * 4, 0)), isEmpty);
    });
    test('yalnız oda gürültüsü (-40 dBFS beyaz/pembe): fazla vuruş sayısı', () {
      var total = 0;
      for (final kind in NoiseKind.values) {
        for (final seed in [1, 2, 3]) {
          final n = unitNoise(kind, _sr * 4, seed: seed)
              .map((v) => v * 0.01)
              .toList();
          final c = _detect(n).length;
          total += c;
          print('[OST-P0-03] sessiz/oda ${kind.name} seed=$seed '
              '4 s içinde sahte vuruş=$c');
        }
      }
      expect(total, lessThanOrEqualTo(_bounds['silenceNoise']!.maxCount));
    });
  });

  group('hata türleri: kasıtlı kayma, kaçan ve fazla vuruş', () {
    test('±ms kayma: onset hatası kaymayı değil algıyı ölçer; '
        'MetronomeAligner kaymayı işaretler', () {
      for (final shift in [-60.0, -30.0, 0.0, 30.0, 60.0]) {
        final c = buildRhythm(
            bpm: 90, render: _render, uniformShiftMs: shift);
        final det = _detect(c.samples);
        final m = matchOnsets(c.playedUs, det);
        expect(m.missed, 0);
        final report = const MetronomeAligner().align(
            onsets: _detector.detect(c.samples, sampleRate: _sr, tStartUs: 0),
            beatTimesUs: c.gridUs);
        // Referans vuruş = ızgara + shift; detektörün sabit gecikmesi
        // (yanlılık) ölçülüp çıkarılır, kalan kayma ±15 ms içinde bulunmalı.
        final bias = percentile(m.errorsMs, 0.5);
        final signed =
            report.deviations.map((d) => d.deviationMs).toList();
        final recovered = percentile(signed, 0.5) - bias;
        print('[OST-P0-03] kayma=${shift.toInt()}ms → aligner med işaretli='
            '${percentile(signed, 0.5).toStringAsFixed(1)} '
            'detektör_yanlılığı=${bias.toStringAsFixed(1)} '
            'geri_çıkarılan=${recovered.toStringAsFixed(1)} '
            'bias=${report.bias.name} kapsam=${report.matchedBeats}/'
            '${report.totalBeats}');
        expect((recovered - shift).abs(), lessThan(15));
        expect(report.matchedBeats, report.totalBeats);
        if (shift <= -60) expect(report.bias, TimingBias.rushing);
        if (shift >= 60) expect(report.bias, TimingBias.dragging);
        if (shift == 0) expect(report.bias, TimingBias.centred);
      }
    });

    test('kaçan vuruşlar: ızgarada var, çalınmamış → kapsam düşer', () {
      final c = buildRhythm(
          bpm: 90, render: _render, skipBeats: const {2, 5});
      final det = _detector.detect(c.samples, sampleRate: _sr, tStartUs: 0);
      final report = const MetronomeAligner()
          .align(onsets: det, beatTimesUs: c.gridUs);
      print('[OST-P0-03] kaçan vuruş 2 → aligner kapsam='
          '${report.matchedBeats}/${report.totalBeats} '
          'tespit=${det.length}');
      expect(det.length, 6);
      expect(report.matchedBeats, 6);
      expect(report.totalBeats, 8);
      expect(report.coverage, closeTo(0.75, 1e-9));
    });

    test('fazla vuruşlar: ızgara dışı nota tespit edilir ama hizalamada '
        'sayılmaz', () {
      // 90 BPM: periyot 0.667 s; ofsetler iki vuruşun tam ortası (333 ms > 150 ms).
      final c = buildRhythm(
          bpm: 90,
          render: _render,
          extraOffsetsSeconds: const [0.3333 + 0.6667 * 2, 0.3333 + 0.6667 * 4]);
      final det = _detector.detect(c.samples, sampleRate: _sr, tStartUs: 0);
      final m = matchOnsets(c.playedUs, det.map((o) => o.tUs).toList());
      final report = const MetronomeAligner()
          .align(onsets: det, beatTimesUs: c.gridUs);
      print('[OST-P0-03] fazla vuruş 2 → tespit=${det.length} '
          'kaçan=${m.missed} fazla=${m.extra} '
          'aligner kapsam=${report.matchedBeats}/${report.totalBeats} '
          'medAbs=${report.medianMs.toStringAsFixed(1)}');
      expect(det.length, c.playedUs.length);
      expect(m.missed, 0);
      expect(report.matchedBeats, report.totalBeats);
      expect(report.medianMs, lessThan(40));
    });
  });

  group('vuruş başına rastgele jitter (seed\'li, ±25 ms düzgün dağılım)', () {
    test('onset hatası jitter\'dan bağımsız; aligner yayılımı geri bulur', () {
      final a = _Agg();
      final spreads = <double>[];
      for (final bpm in bpms) {
        for (final seed in [1, 2, 3]) {
          final rng = math.Random(seed * 1000 + bpm);
          final jitter = <int, double>{
            for (var b = 0; b < 8; b++) b: (rng.nextDouble() * 2 - 1) * 25,
          };
          final c = buildRhythm(
              bpm: bpm, render: _render, shiftMsByBeat: jitter);
          final det =
              _detector.detect(c.samples, sampleRate: _sr, tStartUs: 0);
          a.add(c, det.map((o) => o.tUs).toList());
          final rep = const MetronomeAligner()
              .align(onsets: det, beatTimesUs: c.gridUs);
          expect(rep.matchedBeats, rep.totalBeats);
          // Planlanan işaretli jitter ile aligner'ın işaretli sapması
          // (yanlılık çıkarılmış) arasındaki fark.
          final planned = jitter.values.toList()..sort();
          final got = rep.deviations.map((d) => d.deviationMs).toList()
            ..sort();
          for (var i = 0; i < 8; i++) {
            spreads.add((got[i] - planned[i]).abs());
          }
        }
      }
      print(a.line('jitter ±25ms (9 koşu)'));
      final resid = percentile(spreads, 0.95);
      print('[OST-P0-03] jitter: sıralı sapma − planlanan |fark| p95='
          '${resid.toStringAsFixed(1)} ms (sabit ~7-8 ms erken yanlılık dahil)');
      expect(a.missed, 0);
      expect(a.extra, 0);
      expect(percentile(a.errs.map((e) => e.abs()).toList(), 0.95),
          lessThanOrEqualTo(13));
      expect(resid, lessThanOrEqualTo(13));
    });
  });

  test('corpus deterministik: aynı tohum, aynı örnekler', () {
    final a = addNoiseSnr(buildRhythm(bpm: 60, render: _render).samples,
        kind: NoiseKind.pink, snrDb: 10, seed: 5);
    final b = addNoiseSnr(buildRhythm(bpm: 60, render: _render).samples,
        kind: NoiseKind.pink, snrDb: 10, seed: 5);
    expect(a.mixed, b.mixed);
    final c = addNoiseSnr(buildRhythm(bpm: 60, render: _render).samples,
        kind: NoiseKind.pink, snrDb: 10, seed: 6);
    expect(a.mixed, isNot(c.mixed));
  });
}

class _Bound {
  const _Bound({this.miss = 1, this.extra = 100, this.p95 = 1000, this.maxCount = 1000});
  final double miss, extra, p95;
  final int maxCount;
}

// Eşikler 2026-11-08 ölçümünden türetildi (stdout `[OST-P0-03]` satırları),
// ölçülen değerin ~%20-25 üstünde pay ile: regresyon bekçisi, başarı iddiası
// DEĞİL. Pembe gürültüde fazla-vuruş oranı ölçülen bir SINIRLILIKtır (rapora
// bkz.); eşik bu sınırlılığı sabitler, iyileşirse sıkılaştırılmalıdır.
const _bounds = <String, _Bound>{
  'white20.0': _Bound(miss: 0, extra: 0, p95: 13),
  'white10.0': _Bound(miss: 0, extra: 0.06, p95: 10),
  'white5.0': _Bound(miss: 0, extra: 0.45, p95: 8),
  'pink20.0': _Bound(miss: 0, extra: 0.25, p95: 10),
  'pink10.0': _Bound(miss: 0, extra: 2.3, p95: 55),
  'pink5.0': _Bound(miss: 0, extra: 3.6, p95: 55),
  'echo': _Bound(miss: 0, extra: 0, p95: 13),
  'silenceNoise': _Bound(maxCount: 0),
};
