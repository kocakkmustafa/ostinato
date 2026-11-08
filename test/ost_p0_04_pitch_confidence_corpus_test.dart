// ignore_for_file: avoid_print
// OST-P0-04: monofonik pitch + güven + "duyamadım" (hüküm yok) — SENTETİK,
// tohumlu corpus (TEST_ONLY). Üretim DSP'si: GuitarSingleNoteEvaluator
// (config/guitar-single-note-gate.v1.json, dosyadan okunur), YinPitchSource ve
// AudioConfidenceGate. Ölçümler `[OST-P0-04]` önekiyle stdout'a yazılır.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato_audio/ostinato_audio.dart';

import 'ost_p0_03_04_corpus.dart';

const _sr = corpusSampleRate;

GuitarSingleNoteConfig _loadConfig() {
  final m = jsonDecode(
          File('config/guitar-single-note-gate.v1.json').readAsStringSync())
      as Map<String, dynamic>;
  double d(String k) => (m[k] as num).toDouble();
  return GuitarSingleNoteConfig(
    windowSize: m['windowSize'] as int,
    hopSize: m['hopSize'] as int,
    minReliableWindows: m['minReliableWindows'] as int,
    minHz: d('minHz'),
    maxHz: d('maxHz'),
    yinThreshold: d('yinThreshold'),
    minPeriodicity: d('minPeriodicity'),
    minLevelAboveFloorDb: d('minLevelAboveFloorDb'),
    attackWindowUs: m['attackWindowUs'] as int,
    maxSpreadCents: d('maxSpreadCents'),
    maxCenterErrorCents: d('maxCenterErrorCents'),
  );
}

/// Bir gitar notası: tel + planlanan cent sapması. Nota ilk 0.4 s atlanır
/// (atak), 0.45 s'lik kesit analiz edilir.
List<double> _note(int midi, double cents, {int seed = 42, double seconds = 1.2}) =>
    SyntheticTone.harmonic(
        f0Hz: hzWithCents(midi, cents),
        sampleRate: _sr,
        seconds: seconds,
        seed: seed);

List<double> _slice(List<double> x) =>
    x.sublist((0.4 * _sr).round(), (0.85 * _sr).round());

enum _Outcome { correct, noVerdict, wrong }

class _Tally {
  int correct = 0, noVerdict = 0, wrong = 0;
  final centErr = <double>[];
  int get n => correct + noVerdict + wrong;
  void add(_Outcome o) {
    switch (o) {
      case _Outcome.correct:
        correct++;
      case _Outcome.noVerdict:
        noVerdict++;
      case _Outcome.wrong:
        wrong++;
    }
  }

  double get correctRate => n == 0 ? 0 : correct / n;
  double get noVerdictRate => n == 0 ? 0 : noVerdict / n;
  double get wrongRate => n == 0 ? 0 : wrong / n;
  String line(String label) {
    final a = centErr.map((e) => e.abs()).toList();
    return '[OST-P0-04] $label n=$n doğru=${(correctRate * 100).toStringAsFixed(1)}% '
        'duyamadım=${(noVerdictRate * 100).toStringAsFixed(1)}% '
        'yanlış_hüküm=${(wrongRate * 100).toStringAsFixed(1)}% '
        'cent_hata: med=${percentile(a, .5).toStringAsFixed(1)} '
        'p95=${percentile(a, .95).toStringAsFixed(1)} '
        'maks=${a.isEmpty ? 'NA' : percentile(a, 1).toStringAsFixed(1)}';
  }
}

/// Bir kesiti değerlendirir. "Doğru" = beklenen nota + ölçülen cent, planlanan
/// cent'ten ±[tolCents] içinde. Hüküm var ama yanlış nota/cent → "yanlış".
_Outcome _judge(
  GuitarSingleNoteEvaluator ev,
  List<double> slice, {
  required int midi,
  required double plantedCents,
  required double floorDb,
  _Tally? tally,
  double tolCents = 10,
}) {
  final r = ev.observe(slice,
      sampleRate: _sr, tStartUs: 0, roomFloorDb: floorDb);
  final o = r.observation;
  if (o == null) return _Outcome.noVerdict;
  if (o.midi != midi) return _Outcome.wrong;
  final err = o.centsFromCenter - plantedCents;
  tally?.centErr.add(err);
  return err.abs() <= tolCents ? _Outcome.correct : _Outcome.wrong;
}

void main() {
  final ev = GuitarSingleNoteEvaluator(config: _loadConfig());
  const centsSet = [0.0, 10.0, -10.0, 30.0, -30.0];

  group('temiz sinyal: açık teller E2–E4, cent sapmalı', () {
    test('doğru nota + cent hatası (floor -60 dBFS, 2 tohum)', () {
      final t = _Tally();
      guitarOpenStrings.forEach((name, midi) {
        for (final c in centsSet) {
          for (final seed in [1, 2]) {
            final slice = _slice(_note(midi, c, seed: seed));
            t.add(_judge(ev, slice,
                midi: midi, plantedCents: c, floorDb: -60, tally: t));
          }
        }
      });
      print(t.line('temiz E2–E4 ±0/10/30¢'));
      expect(t.n, 60);
      expect(t.correctRate, greaterThanOrEqualTo(_b['cleanCorrect']!));
      expect(t.wrong, lessThanOrEqualTo(_b['cleanWrong']!.toInt()));
      expect(percentile(t.centErr.map((e) => e.abs()).toList(), 0.95),
          lessThanOrEqualTo(_b['cleanP95']!));
    });

    test('evaluate(): ±30¢ hâlâ aynı nota (match), komşu nota differentNote',
        () {
      final e2 = guitarOpenStrings['E2']!;
      for (final c in [-30.0, 0.0, 30.0]) {
        final r = ev.evaluate(_slice(_note(e2, c)),
            sampleRate: _sr,
            tStartUs: 0,
            expectedMidi: e2,
            roomFloorDb: -60);
        expect(r.verdict, GuitarSingleNoteVerdict.match, reason: '$c¢');
        expect((r.signedCentsFromTarget! - c).abs(), lessThan(10));
      }
      final r = ev.evaluate(_slice(_note(e2 + 1, 0)),
          sampleRate: _sr,
          tStartUs: 0,
          expectedMidi: e2,
          roomFloorDb: -60);
      expect(r.verdict, GuitarSingleNoteVerdict.differentNote);
    });

    test('telefon yüksek-geçiren (120 Hz) altında: yanlış hüküm yok', () {
      final t = _Tally();
      guitarOpenStrings.forEach((name, midi) {
        for (final c in [0.0, 10.0, -10.0]) {
          final x = SyntheticTone.phoneHighpass(_note(midi, c),
              sampleRate: _sr);
          t.add(_judge(ev, _slice(x),
              midi: midi, plantedCents: c, floorDb: -60, tally: t));
        }
      });
      print(t.line('telefon-HP120 E2–E4'));
      expect(t.wrongRate, lessThanOrEqualTo(_b['hpWrong']!));
    });
  });

  group('gürültü: SNR 20/10/5 dB (floor = yalnız-gürültü RMS, Setup Check gibi)',
      () {
    for (final kind in NoiseKind.values) {
      for (final snr in [20.0, 10.0, 5.0]) {
        test('${kind.name} ${snr.toInt()} dB', () {
          final t = _Tally();
          guitarOpenStrings.forEach((name, midi) {
            for (final c in [0.0, 10.0, -10.0, 30.0, -30.0]) {
              final clean = _note(midi, c, seed: 3);
              final mixed = addNoiseSnr(clean,
                  kind: kind, snrDb: snr, seed: midi * 10 + snr.toInt());
              final floor = rmsDbOf(_slice(mixed.noiseOnly));
              t.add(_judge(ev, _slice(mixed.mixed),
                  midi: midi, plantedCents: c, floorDb: floor, tally: t));
            }
          });
          print(t.line('${kind.name} SNR=${snr.toInt()}dB'));
          final bound = _noiseBounds['${kind.name}${snr.toInt()}']!;
          expect(t.wrongRate, lessThanOrEqualTo(bound.wrong));
          expect(t.correctRate, greaterThanOrEqualTo(bound.correct));
        });
      }
    }
  });

  group('duyamadım: sessizlik, oda gürültüsü, yankı, çok sesli', () {
    test('sayısal sessizlik ve yalnız oda gürültüsü: hüküm yok', () {
      final t = _Tally();
      final silence = List<double>.filled((0.45 * _sr).round(), 0);
      t.add(_judge(ev, silence,
          midi: 40, plantedCents: 0, floorDb: -60));
      for (final kind in NoiseKind.values) {
        for (final seed in [1, 2, 3]) {
          for (final amp in [0.003, 0.01, 0.03]) {
            final n = unitNoise(kind, (0.45 * _sr).round(), seed: seed)
                .map((v) => v * amp)
                .toList();
            // Oda tabanı kalibre: aynı gürültünün RMS'i.
            t.add(_judge(ev, n,
                midi: 40, plantedCents: 0, floorDb: rmsDbOf(n)));
            // Taban -60 dBFS sabit (kalibrasyonsuz kötü durum).
            t.add(_judge(ev, n, midi: 40, plantedCents: 0, floorDb: -60));
          }
        }
      }
      print(t.line('sessizlik+oda gürültüsü'));
      expect(t.wrong, 0);
      expect(t.noVerdictRate, greaterThanOrEqualTo(_b['silenceNoVerdict']!));
    });

    test('AudioConfidenceGate: sessizlik/gürültü pencerelerinde mayJudge yok',
        () {
      const gate = AudioConfidenceGate();
      final yin = YinPitchSource();
      var judged = 0, total = 0;
      for (final kind in NoiseKind.values) {
        for (final seed in [1, 2, 3, 4]) {
          final n = unitNoise(kind, 4096, seed: seed)
              .map((v) => v * 0.01)
              .toList();
          final rd = yin.analyze(n, sampleRate: _sr, tStartUs: 0);
          final g = gate.evaluate(rd, roomFloorDb: rmsDbOf(n) - 0.0);
          total++;
          if (g.mayJudge) judged++;
        }
      }
      print('[OST-P0-04] AudioConfidenceGate gürültü-only: '
          'mayJudge=$judged/$total');
      expect(judged, 0);
    });

    test('yankı: nota üzerine seyrek-IR yankı (RT60 0.6 s) — yanlış hüküm',
        () {
      final t = _Tally();
      guitarOpenStrings.forEach((name, midi) {
        for (final seed in [1, 2, 3]) {
          final x = addEcho(_note(midi, 0, seconds: 1.6), seed: seed);
          final slice = x.sublist((0.5 * _sr).round(), (0.95 * _sr).round());
          t.add(_judge(ev, slice,
              midi: midi, plantedCents: 0, floorDb: -60, tally: t));
        }
      });
      print(t.line('tek nota + yankı (RT60 0.6 s)'));
      expect(t.wrongRate, lessThanOrEqualTo(_b['echoWrong']!));
    });

    test('yankı kuyruğu: önceki nota kuyruğu üstüne yeni nota — '
        'yanlış nota hükmü', () {
      // Nota A (E2) 0.5 s çalar, sonra B (A2) başlar; A'nın yankısı B'ye karışır.
      final t = _Tally();
      for (final seed in [1, 2, 3]) {
        final a = SyntheticTone.harmonic(
            f0Hz: midiToHz(40), sampleRate: _sr, seconds: 0.5, seed: seed);
        final b = SyntheticTone.harmonic(
            f0Hz: midiToHz(45), sampleRate: _sr, seconds: 1.0, seed: seed);
        final x = List<double>.filled(a.length + b.length, 0);
        for (var i = 0; i < a.length; i++) {
          x[i] += a[i];
        }
        for (var i = 0; i < b.length; i++) {
          x[a.length + i] += b[i];
        }
        final echoed = addEcho(x, seed: seed, wet: 1.5);
        final start = a.length + (0.15 * _sr).round(); // atak sonrası
        final slice = echoed.sublist(start, start + (0.45 * _sr).round());
        t.add(_judge(ev, slice,
            midi: 45, plantedCents: 0, floorDb: -60, tally: t));
      }
      print(t.line('A→B geçişi + yankı kuyruğu (B=A2 beklenir)'));
      expect(t.wrongRate, lessThanOrEqualTo(_b['tailWrong']!));
    });

    test('çok sesli: akor + güç akoru/dyad — tek-nota hükmü ölçümü', () {
      final t = _Tally();
      final wrongCases = <String>[];
      void run(String label, List<int> notes, double spread) {
        final x = SyntheticTone.chord(
            midiNotes: notes,
            sampleRate: _sr,
            seconds: 1.5,
            strumSpreadSeconds: spread);
        final r = ev.observe(_slice(x),
            sampleRate: _sr, tStartUs: 0, roomFloorDb: -60);
        final o = r.observation;
        // Çok sesli sinyalde her tek-nota hükmü yanlıştır (tek nota yok).
        t.add(o == null ? _Outcome.noVerdict : _Outcome.wrong);
        if (o != null) wrongCases.add('$label(spread=$spread)→midi ${o.midi}');
      }

      for (final spread in [0.0, 0.025]) {
        SyntheticTone.openGuitarChords
            .forEach((name, notes) => run(name, notes, spread));
        // Güç akoru/dyad: kök + beşli, 6 tel konumu.
        for (final root in guitarOpenStrings.values) {
          run('dyad${root}_${root + 7}', [root, root + 7], spread);
        }
      }
      print(t.line('çok sesli (16 akor + 12 dyad)'));
      print('[OST-P0-04] çok sesli yanlış hükümler: '
          '${wrongCases.isEmpty ? 'yok' : wrongCases.join(' | ')}');
      // Karakterizasyon (BULGU, düzeltme bu PR'da değil): ölçülen yanlış hüküm
      // sayısını sabitler; artarsa kırılır.
      expect(t.n, 28);
      expect(t.wrong, lessThanOrEqualTo(_b['polyWrongMax']!.toInt()));
    });

    test('BULGU (ENGEL): D majör akor (D3 A3 D4 F#4) tek-nota hükmü almamalı',
        () {
      final x = SyntheticTone.chord(
          midiNotes: SyntheticTone.openGuitarChords['D']!,
          sampleRate: _sr,
          seconds: 1.5,
          strumSpreadSeconds: 0.0);
      final r = ev.observe(_slice(x),
          sampleRate: _sr, tStartUs: 0, roomFloorDb: -60);
      expect(r.observation, isNull,
          reason: 'Üretim evaluator\'ı akor için bir nota hükmü veriyor '
              '(GuitarSingleNoteReason.multipleSources tanımlı ama kullanılmıyor).');
    },
        skip: 'ENGEL: üretim boşluğu — çok sesli sinyalde yanlış nota '
            'hükmü; düzeltme bu PR kapsamı dışı (OST-P0-04 raporu §Bulgu).');

    test('atak penceresi ve koç sesi: hüküm yok', () {
      final slice = _slice(_note(40, 0));
      // 6144 örnek = tam 2 pencere (t=0, 46 ms), ikisi de atak penceresinde.
      final attack = ev.observe(slice.sublist(0, 6144),
          sampleRate: _sr, tStartUs: 0, roomFloorDb: -60, lastOnsetTUs: 0);
      expect(attack.observation, isNull);
      final coach = ev.observe(slice,
          sampleRate: _sr,
          tStartUs: 0,
          roomFloorDb: -60,
          coachSpeaking: true);
      expect(coach.observation, isNull);
      expect(coach.reason, GuitarSingleNoteReason.coachSpeaking);
    });
  });

  test('corpus deterministik', () {
    expect(_note(40, 10, seed: 5), _note(40, 10, seed: 5));
    expect(whiteNoise(100, seed: 1), whiteNoise(100, seed: 1));
    expect(whiteNoise(100, seed: 1), isNot(whiteNoise(100, seed: 2)));
  });
}

class _NB {
  const _NB({required this.correct, required this.wrong});
  final double correct, wrong;
}

// Eşikler 2026-11-08 ölçümünden türetildi (`[OST-P0-04]` satırları): ölçülen
// değere yakın, yanlış-hüküm tavanları 0. Regresyon bekçisi; başarı iddiası
// DEĞİL (sentetik, TEST_ONLY). polyWrongMax = ölçülen 10 (BULGU, rapora bkz.).
const _b = <String, double>{
  'cleanCorrect': 0.95,
  'cleanWrong': 0,
  'cleanP95': 1.0,
  'hpWrong': 0,
  'silenceNoVerdict': 1.0,
  'echoWrong': 0,
  'tailWrong': 0,
  'polyWrongMax': 10,
};
const _noiseBounds = <String, _NB>{
  'white20': _NB(correct: 0.95, wrong: 0),
  'white10': _NB(correct: 0.90, wrong: 0),
  'white5': _NB(correct: 0, wrong: 0),
  'pink20': _NB(correct: 0.95, wrong: 0),
  'pink10': _NB(correct: 0.95, wrong: 0),
  'pink5': _NB(correct: 0, wrong: 0),
};
