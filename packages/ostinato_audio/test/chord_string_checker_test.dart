// E53 arm K1 (lib/src/harmony/chord_string_checker.dart). Experiment code,
// not exported, not wired: these tests pin the method, not product accuracy.
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ostinato_audio/ostinato_audio.dart';
import 'package:ostinato_audio/src/harmony/chord_string_checker.dart';
import 'package:test/test.dart';

const em = StringVoicing('Em', [40, 47, 52, 55, 59, 64]);
const c = StringVoicing('C', [null, 48, 52, 55, 60, 64]);
const g3 = StringVoicing('G3', [43, 47, 50, 55, 59, 67]);
const g4 = StringVoicing('G4', [43, 47, 50, 55, 62, 67]);

Float64List actFor(ChordStringChecker k, Map<int, double> m) {
  final a = Float64List(k.nPitch);
  m.forEach((p, v) => a[p - k.midiLow] = v);
  return a;
}

void main() {
  final k = ChordStringChecker();

  test('dictionary: 49 pitch atoms + floor, band 60–5000 Hz', () {
    expect(k.nPitch, 49);
    expect(k.nAtoms, 50);
  });

  test('NNLS recovers a known non-negative combination (PLAN §9.1)', () {
    final rng = math.Random(7);
    for (var t = 0; t < 20; t++) {
      final m = <int, double>{};
      for (var j = 0; j < 6; j++) {
        m[40 + rng.nextInt(49)] = 0.1 + rng.nextDouble();
      }
      final a = actFor(k, m);
      final fit = k.fitSpectrum(k.synthesize(a, 0.003));
      for (var i = 0; i < a.length; i++) {
        expect(fit.activations[i], closeTo(a[i], 1e-6));
      }
      expect(fit.floor, closeTo(0.003, 1e-6));
      expect(fit.r2, closeTo(1, 1e-9));
    }
  });

  test('NNLS keeps x ≥ 0 and satisfies KKT on an arbitrary spectrum', () {
    final rng = math.Random(11);
    final s = Float64List.fromList(List.generate(
        k.synthesize(Float64List(k.nPitch), 0).length,
        (_) => rng.nextDouble()));
    final fit = k.fitSpectrum(s);
    for (final v in fit.activations) {
      expect(v, greaterThanOrEqualTo(0));
    }
    // KKT: gradient Dᵀ(S − Dx) ≤ 0 on zero coordinates, ≈ 0 on positive.
    final resid = Float64List.fromList([
      for (var i = 0; i < s.length; i++)
        s[i] - k.synthesize(fit.activations, fit.floor)[i]
    ]);
    for (var p = 0; p < k.nPitch; p++) {
      final unit = actFor(k, {k.midiLow + p: 1.0});
      final atom = k.synthesize(unit, 0);
      var g = 0.0, norm = 0.0;
      for (var i = 0; i < s.length; i++) {
        g += atom[i] * resid[i];
        norm += atom[i] * atom[i];
      }
      final scale = math.sqrt(norm);
      if (fit.activations[p] > 0) {
        expect(g.abs() / scale, lessThan(1e-6));
      } else {
        expect(g / scale, lessThan(1e-6));
      }
    }
  });

  test('verdicts from exact spectra: correct, missing, different', () {
    final full = {for (final m in em.midi) m!: 1.0};
    expect(k.judge(k.fitSpectrum(k.synthesize(actFor(k, full), 0)), em).verdict,
        ChordVerdict.correct);
    final drop = Map.of(full)..remove(55);
    final j = k.judge(k.fitSpectrum(k.synthesize(actFor(k, drop), 0)), em);
    expect(j.verdict, ChordVerdict.missingString);
    expect([
      for (final s in j.strings)
        if (!s.heard) s.string
    ], [
      3
    ]);
    final sharp = Map.of(drop)..[56] = 1.0; // G♯ instead of G
    final d = k.judge(k.fitSpectrum(k.synthesize(actFor(k, sharp), 0)), em);
    expect(d.verdict, ChordVerdict.differentChord);
    expect(d.unexpected.map((u) => u.$1), contains(56));
  });

  test('extra string is reported, does not change the verdict', () {
    final m = {
      for (final x in c.midi)
        if (x != null) x: 1.0,
      40: 1.0
    }; // low E
    final j = k.judge(k.fitSpectrum(k.synthesize(actFor(k, m), 0)), c);
    expect(j.verdict, ChordVerdict.correct);
    expect(j.extra.map((e) => e.$1), contains(6));
  });

  test('gates: silence → level; noise-like → couldNotHear', () {
    final silent = Float64List(19200);
    final r = k.check(silent, roomFloorDb: -120, allowed: const [em]);
    expect(r.verdict, ChordVerdict.couldNotHear);
    expect(r.gate, 'level');
    final strict = ChordStringChecker(tauFit: 0.999);
    final x = Float64List.fromList(SyntheticTone.chord(
        midiNotes: [40, 47, 52, 55, 59, 64], sampleRate: 48000, seconds: 0.4));
    final r2 = strict.check(x, roomFloorDb: -120, allowed: const [em]);
    expect(r2.gate, 'fit');
    expect(r2.verdict, ChordVerdict.couldNotHear);
  });

  test('allowed voicings: any correct wins (G 3 or 4 fingers)', () {
    final m = {for (final x in g4.midi) x!: 1.0};
    final f = k.fitSpectrum(k.synthesize(actFor(k, m), 0));
    expect(k.judge(f, g3).verdict, isNot(ChordVerdict.correct));
    expect(k.judge(f, g4).verdict, ChordVerdict.correct);
  });

  test(
      'check() on a real-time-domain synthetic strum runs and is deterministic',
      () {
    final x = Float64List(57600);
    for (final (i, m) in em.midi.indexed) {
      final s = SyntheticString.pluck(
          f0Hz: ChordStringChecker.midiHz(m!),
          sampleRate: 48000,
          seconds: 1.2 - 0.01 * i,
          seed: 3 + i,
          peak: 0.1);
      final o = (0.01 * i * 48000).round();
      for (var j = 0; j < s.length; j++) {
        x[o + j] += s[j];
      }
    }
    final w = x.sublist(3840, 23040);
    final a = k.check(w, roomFloorDb: -120, allowed: const [em, c]);
    final b = k.check(w, roomFloorDb: -120, allowed: const [em, c]);
    expect(a.verdict, b.verdict);
    expect(a.r2, b.r2);
    expect(a.fit!.activations, b.fit!.activations);
  });
}
