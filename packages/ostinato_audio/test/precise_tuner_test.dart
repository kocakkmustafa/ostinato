import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ostinato_audio/ostinato_audio.dart';
import 'package:test/test.dart';

const sr = 48000;

double hz(num midi) => 440 * math.pow(2, (midi - 69) / 12).toDouble();
double centsOf(double a, double b) => 1200 * math.log(a / b) / math.ln2;

Float64List pluck(double f0,
        {double b = 1e-4,
        double seconds = 2.2,
        int seed = 3,
        double pluckPos = 0.18}) =>
    SyntheticString.pluck(
      f0Hz: f0,
      sampleRate: sr,
      seconds: seconds,
      inharmonicityB: b,
      pluckPosition: pluckPos,
      preRollSeconds: 0.2,
      seed: seed,
    );

void main() {
  group('dsp', () {
    test('fft finds a sinusoid at its bin', () {
      const n = 1024;
      final re = Float64List(n), im = Float64List(n);
      for (var i = 0; i < n; i++) {
        re[i] = math.sin(2 * math.pi * 37 * i / n);
      }
      fftInPlace(re, im);
      var best = 0;
      for (var k = 1; k < n ~/ 2; k++) {
        if (re[k] * re[k] + im[k] * im[k] >
            re[best] * re[best] + im[best] * im[best]) {
          best = k;
        }
      }
      expect(best, 37);
    });

    test('fftConvolve equals direct convolution', () {
      final a = [1.0, -2.0, 0.5, 3.0, 0.25];
      final b = [0.5, 0.0, -1.0];
      final got = fftConvolve(a, b);
      for (var i = 0; i < a.length + b.length - 1; i++) {
        var want = 0.0;
        for (var j = 0; j < b.length; j++) {
          if (i - j >= 0 && i - j < a.length) want += a[i - j] * b[j];
        }
        expect(got[i], closeTo(want, 1e-9));
      }
    });
  });

  group('phone channel', () {
    double rms(List<double> x, [int from = 0]) {
      var s = 0.0;
      for (var i = from; i < x.length; i++) {
        s += x[i] * x[i];
      }
      return math.sqrt(s / (x.length - from));
    }

    List<double> sine(double f, double seconds) => [
          for (var i = 0; i < (seconds * sr).round(); i++)
            0.3 * math.sin(2 * math.pi * f * i / sr)
        ];

    test('low cut removes the bass and keeps the mids', () {
      const cfg =
          PhoneChannelConfig(lowCutHz: 120, lowCutOrder: 4, quantize16: false);
      final low = PhoneChannel.apply(sine(41.2, 1), sr, cfg);
      final mid = PhoneChannel.apply(sine(1000, 1), sr, cfg);
      final lowDb =
          20 * math.log(rms(low, sr ~/ 2) / rms(sine(41.2, 1))) / math.ln10;
      final midDb =
          20 * math.log(rms(mid, sr ~/ 2) / rms(sine(1000, 1))) / math.ln10;
      expect(lowDb, lessThan(-30));
      expect(midDb, closeTo(0, 0.2));
    });

    test('noise lands at the requested SNR and is seed-deterministic', () {
      final x = sine(220, 1);
      const cfg = PhoneChannelConfig(
          noise: ChannelNoise.pink, snrDb: 20, quantize16: false);
      final y = PhoneChannel.apply(x, sr, cfg, seed: 9);
      final noise = [for (var i = 0; i < x.length; i++) y[i] - x[i]];
      final snr = 20 * math.log(rms(x) / rms(noise)) / math.ln10;
      expect(snr, closeTo(20, 0.3));
      expect(PhoneChannel.apply(x, sr, cfg, seed: 9), y);
      expect(PhoneChannel.apply(x, sr, cfg, seed: 10), isNot(y));
    });

    test('IR shaping hits the requested direct-to-reverberant ratio', () {
      final rng = math.Random(1);
      final ir = [
        for (var i = 0; i < 4800; i++)
          i == 100
              ? 1.0
              : (i > 100
                  ? (rng.nextDouble() * 2 - 1) *
                      0.3 *
                      math.exp(-(i - 100) / 1500)
                  : 0.0)
      ];
      final shaped = PhoneChannel.shapeImpulseResponse(ir, sr, 3);
      final half = (0.0025 * sr).round();
      var direct = 0.0, tail = 0.0;
      for (var i = 0; i < shaped.ir.length; i++) {
        final e = shaped.ir[i] * shaped.ir[i];
        if ((i - shaped.directIndex).abs() <= half) {
          direct += e;
        } else if (i > shaped.directIndex) {
          tail += e;
        }
      }
      expect(shaped.directIndex, 100);
      expect(10 * math.log(direct / tail) / math.ln10, closeTo(3, 1e-6));
    });

    test('AGC and limiter keep a loud, noisy note in range', () {
      final x = [for (final v in sine(110, 1)) v * 3];
      final y = PhoneChannel.apply(
          x,
          sr,
          const PhoneChannelConfig(
              agc: true, noise: ChannelNoise.hum, snrDb: 10, lowCutHz: 100));
      expect(y.every((v) => v.isFinite && v.abs() <= 1), isTrue);
    });
  });

  group('precise tuner', () {
    test('measures a stiff guitar string to well under a cent', () {
      for (final (midi, detune, b) in [
        (40, 7.3, 2e-4),
        (45, -12.0, 1e-4),
        (64, 3.1, 5e-5),
        (59, -0.6, 3e-4)
      ]) {
        final f0 = hz(midi) * math.pow(2, detune / 1200);
        final r = PreciseTuner().measure(pluck(f0, b: b), sampleRate: sr);
        expect(r.measured, isTrue, reason: 'midi $midi ${r.refusal}');
        final m = r.measurement!;
        expect(centsOf(m.f0Hz, f0).abs(), lessThan(0.5), reason: 'midi $midi');
        expect(m.midi, midi);
        expect(m.centsFromNearest, closeTo(detune, 0.5));
        expect(m.inharmonicityB, closeTo(b, b * 0.5));
      }
    });

    test('YIN alone reads a stiff string sharp; the fit does not', () {
      final f0 = hz(40);
      final x = pluck(f0, b: 3e-4);
      final yin = YinPitchSource(minHz: 60, maxHz: 1400).analyze(
          x.sublist(sr ~/ 2, sr ~/ 2 + 4096),
          sampleRate: sr,
          tStartUs: 0);
      final tuned = PreciseTuner().measure(x, sampleRate: sr).measurement!;
      expect(centsOf(yin.f0Hz!, f0), greaterThan(1.5));
      expect(centsOf(tuned.f0Hz, f0).abs(), lessThan(0.5));
    });

    test('a missing fundamental is carried by partials n >= 2', () {
      final f0 = hz(40) * math.pow(2, 4 / 1200);
      const b = 1.2e-4;
      final x = [
        for (var i = 0; i < (2.2 * sr).round(); i++)
          [
                for (var n = 2; n <= 8; n++)
                  math.exp(-i / sr / 1.5) *
                      math.sin(2 *
                              math.pi *
                              n *
                              f0 *
                              math.sqrt(1 + b * n * n) *
                              i /
                              sr +
                          n) /
                      n
              ].reduce((a, c) => a + c) *
              0.4
      ];
      final m = PreciseTuner()
          .measure(x, sampleRate: sr, attackIndex: 0)
          .measurement!;
      expect(m.readings.any((r) => r.fundamentalFound), isFalse);
      expect(centsOf(m.f0Hz, f0).abs(), lessThan(0.5));
      expect(m.midi, 40);
    });

    test('bass E1 and B0 are measured with the 28 Hz floor', () {
      for (final midi in [23, 28]) {
        final f0 = hz(midi) * math.pow(2, -5 / 1200);
        final x = pluck(f0, b: 3e-4, seconds: 2.6);
        final r = PreciseTuner(profile: PreciseTunerProfile.bass)
            .measure(x, sampleRate: sr);
        expect(r.measured, isTrue, reason: '${r.refusal}');
        expect(centsOf(r.measurement!.f0Hz, f0).abs(), lessThan(1));
        expect(r.measurement!.midi, midi);
      }
      expect(PreciseTunerProfile.bass.minHz, inInclusiveRange(25, 30));
    });

    test('ukulele profile measures a nylon C4', () {
      final f0 = hz(60) * math.pow(2, 9 / 1200);
      final x = SyntheticString.pluck(
          f0Hz: f0,
          sampleRate: sr,
          seconds: 1.6,
          inharmonicityB: 3e-5,
          fundamentalDecaySeconds: 0.6,
          preRollSeconds: 0.1);
      final m = PreciseTuner(profile: PreciseTunerProfile.ukulele)
          .measure(x, sampleRate: sr)
          .measurement!;
      expect(centsOf(m.f0Hz, f0).abs(), lessThan(1));
    });

    test('target-string mode reports cents from the target', () {
      final f0 = hz(45) * math.pow(2, 23 / 1200);
      final m = PreciseTuner()
          .measure(pluck(f0), sampleRate: sr, targetHz: hz(45))
          .measurement!;
      expect(m.centsFromTarget, closeTo(23, 0.5));
    });

    test('refuses silence, short buffers, quiet rooms and drifting pitch', () {
      final tuner = PreciseTuner();
      expect(tuner.measure(Float64List(sr * 2), sampleRate: sr).refusal,
          isIn([TunerRefusal.noPitch, TunerRefusal.tooFewPartials]));
      expect(tuner.measure(pluck(hz(45), seconds: 0.5), sampleRate: sr).refusal,
          TunerRefusal.insufficientSamples);
      expect(
          tuner.measure(pluck(hz(45)), sampleRate: sr, roomFloorDb: 0).refusal,
          TunerRefusal.tooQuiet);
      // A strong pitch glide (hard pluck) keeps moving across readings: more
      // than the 10-cent late-readings limit, so still "could not measure".
      final drifting = SyntheticString.pluck(
          f0Hz: hz(45),
          sampleRate: sr,
          seconds: 2.2,
          glideCents: 60,
          fundamentalDecaySeconds: 1.2,
          preRollSeconds: 0.2);
      expect(tuner.measure(drifting, sampleRate: sr).refusal,
          TunerRefusal.unstable);
      expect(tuner.measure([2.0, 0.0], sampleRate: sr).refusal,
          TunerRefusal.invalidSamples);
    });

    test('measures through the quiet simulated phone channel', () {
      final f0 = hz(50) * math.pow(2, -8 / 1200);
      final y = PhoneChannel.apply(
        pluck(f0, b: 1.5e-4),
        sr,
        const PhoneChannelConfig(
            noise: ChannelNoise.pink, snrDb: 30, lowCutHz: 100, agc: true),
        seed: 4,
      );
      final m = PreciseTuner().measure(y, sampleRate: sr).measurement!;
      expect(centsOf(m.f0Hz, f0).abs(), lessThan(1));
    });
  });

  group('note verifier', () {
    Float64List note(int midi,
            {double b = 1e-4, double pluckPos = 0.2, int seed = 1}) =>
        SyntheticString.pluck(
            f0Hz: hz(midi),
            sampleRate: sr,
            seconds: 0.8,
            inharmonicityB: b,
            pluckPosition: pluckPos,
            preRollSeconds: 0.1,
            seed: seed);

    test('three outcomes on clean notes', () {
      final v = GuitarNoteVerifier();
      final x = note(52);
      expect(v.verify(x, sampleRate: sr, expectedMidi: 52).verdict,
          NoteVerdict.correct);
      for (final d in [1, -1, 2, 5, 7, 12, -12]) {
        final r = v.verify(x, sampleRate: sr, expectedMidi: 52 + d);
        expect(r.verdict, NoteVerdict.differentNote, reason: 'offset $d');
        expect(r.observedMidi, 52);
      }
      expect(
          v.verify(Float64List(sr), sampleRate: sr, expectedMidi: 52).verdict,
          NoteVerdict.couldNotHear);
    });

    test('octave relations are settled by the odd partials of the lower note',
        () {
      final e2 = hz(40);
      List<double> tone(List<(int, double)> partials) => [
            for (var i = 0; i < (0.7 * sr).round(); i++)
              0.5 *
                  partials
                      .map((p) =>
                          p.$2 * math.sin(2 * math.pi * p.$1 * e2 * i / sr))
                      .reduce((a, b) => a + b)
          ];
      final v = GuitarNoteVerifier();
      // Low E with a weak fundamental and strong even partials: still E2.
      final lowE = tone([
        (1, 0.03),
        (2, 0.5),
        (3, 0.25),
        (4, 0.4),
        (5, 0.15),
        (6, 0.2),
        (7, 0.08)
      ]);
      expect(
          v
              .verify(lowE, sampleRate: sr, expectedMidi: 40, onsetIndex: 0)
              .verdict,
          NoteVerdict.correct);
      expect(
          v
              .verify(lowE, sampleRate: sr, expectedMidi: 52, onsetIndex: 0)
              .verdict,
          NoteVerdict.differentNote);
      // A real E3 (no energy between its partials) asked as E2 is wrong.
      final e3 = tone([(2, 0.5), (4, 0.4), (6, 0.2), (8, 0.1)]);
      expect(
          v.verify(e3, sampleRate: sr, expectedMidi: 40, onsetIndex: 0).verdict,
          NoteVerdict.differentNote);
      expect(
          v.verify(e3, sampleRate: sr, expectedMidi: 52, onsetIndex: 0).verdict,
          NoteVerdict.correct);
    });

    test('tuning offset moves the match window with the guitar', () {
      final x = SyntheticString.pluck(
          f0Hz: hz(57) * math.pow(2, 45 / 1200),
          sampleRate: sr,
          seconds: 0.8,
          preRollSeconds: 0.1);
      final v = GuitarNoteVerifier();
      expect(
          v
              .verify(x,
                  sampleRate: sr, expectedMidi: 57, tuningOffsetCents: 40)
              .verdict,
          NoteVerdict.correct);
    });

    test('broadband noise is "could not hear", never a wrong note', () {
      final rng = math.Random(5);
      final x = [for (var i = 0; i < sr; i++) (rng.nextDouble() * 2 - 1) * 0.3];
      final r =
          GuitarNoteVerifier().verify(x, sampleRate: sr, expectedMidi: 52);
      expect(r.verdict, NoteVerdict.couldNotHear);
    });
  });
}
