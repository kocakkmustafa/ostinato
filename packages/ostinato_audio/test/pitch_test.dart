import 'package:ostinato_audio/ostinato_audio.dart';
import 'package:test/test.dart';

/// Thresholds are written here, once, and referenced by every case below —
/// the same numbers the G1-C benchmark gate used (median ≤25 cents, no octave
/// errors). Writing them beside the assertions is what stops a failing run from
/// quietly becoming a "well, 40 cents is fine too" run.
const centsTolerance = 25.0;
const sampleRate = 44100;

/// Analyse a whole tone in windows and return the median absolute cent error,
/// skipping the attack (which the gate refuses to judge anyway).
({double medianCents, int octaveErrors, int windows}) measure(
  List<double> signal,
  double trueHz, {
  double? prior,
  int windowSize = 4096,
}) {
  final source = YinPitchSource(minHz: 50, maxHz: 1200, expectedHzPrior: prior);
  final errors = <double>[];
  var octaveErrors = 0;
  var windows = 0;

  // Skip the first 250 ms: bow/breath attack is aperiodic by nature.
  final start = (sampleRate * 0.25).round();
  for (var i = start; i + windowSize <= signal.length; i += windowSize ~/ 2) {
    final reading = source.analyze(
      signal.sublist(i, i + windowSize),
      sampleRate: sampleRate,
      tStartUs: (i * 1000000 / sampleRate).round(),
    );
    if (!reading.hasPitch) continue;
    windows++;
    final err = absCents(reading.f0Hz!, trueHz);
    if (err > 550) {
      octaveErrors++;
    } else {
      errors.add(err);
    }
  }
  errors.sort();
  final median = errors.isEmpty ? double.infinity : errors[errors.length ~/ 2];
  return (medianCents: median, octaveErrors: octaveErrors, windows: windows);
}

void main() {
  group('YIN accuracy on cello open strings', () {
    // These four notes are the entire V1 cello drill; C2 is also where pYIN
    // locked an octave high in the G1-C benchmark on real recordings, so it is
    // the case that matters most.
    for (final (name, hz) in [
      ('C2', ReferencePitches.c2),
      ('G2', ReferencePitches.g2),
      ('D3', ReferencePitches.d3),
      ('A3', ReferencePitches.a3),
    ]) {
      test('$name clean tone within $centsTolerance cents, no octave errors', () {
        final signal = SyntheticTone.harmonic(f0Hz: hz, sampleRate: sampleRate, seconds: 2.0);
        final r = measure(signal, hz);
        expect(r.windows, greaterThan(3), reason: 'estimator went silent on a clean tone');
        expect(r.octaveErrors, 0);
        expect(r.medianCents, lessThan(centsTolerance));
      });
    }

    test('C2 survives a phone microphone high-pass that weakens the fundamental', () {
      final clean = SyntheticTone.harmonic(
          f0Hz: ReferencePitches.c2, sampleRate: sampleRate, seconds: 2.0);
      final filtered = SyntheticTone.phoneHighpass(clean, sampleRate: sampleRate);
      final r = measure(filtered, ReferencePitches.c2);
      expect(r.octaveErrors, 0, reason: 'weak fundamental must not push YIN an octave up');
      expect(r.medianCents, lessThan(centsTolerance));
    });

    test('C2 survives 10 dB SNR', () {
      final noisy = SyntheticTone.addNoise(
        SyntheticTone.harmonic(f0Hz: ReferencePitches.c2, sampleRate: sampleRate, seconds: 2.0),
        snrDb: 10,
      );
      final r = measure(noisy, ReferencePitches.c2);
      expect(r.octaveErrors, 0);
      expect(r.medianCents, lessThan(centsTolerance));
    });
  });

  group('Voice range (W1 — first shipped instrument)', () {
    test('A4 with vibrato tracks the centre pitch', () {
      final signal = SyntheticTone.harmonic(
        f0Hz: ReferencePitches.a4,
        sampleRate: sampleRate,
        seconds: 2.0,
        vibratoHz: 5.5,
        vibratoCents: 30,
      );
      final r = measure(signal, ReferencePitches.a4);
      expect(r.octaveErrors, 0);
      // Vibrato is a real excursion, not an error: allow the modulation depth
      // on top of the accuracy budget instead of pretending it is noise.
      expect(r.medianCents, lessThan(centsTolerance + 30));
    });

    test('C5 clean tone', () {
      final signal =
          SyntheticTone.harmonic(f0Hz: ReferencePitches.c5, sampleRate: sampleRate, seconds: 1.5);
      final r = measure(signal, ReferencePitches.c5);
      expect(r.octaveErrors, 0);
      expect(r.medianCents, lessThan(centsTolerance));
    });
  });

  group('Expected-note prior (the G1-C octave defence)', () {
    test('a missing fundamental does not fool YIN, with or without the prior', () {
      // The classic trick: remove the fundamental entirely and see whether the
      // tracker reports 2*f0. YIN's difference function works on periodicity
      // rather than spectral peaks, so it holds up here — measured, not
      // assumed. The prior must not *break* this case either.
      final signal = SyntheticTone.harmonic(
        f0Hz: ReferencePitches.c2,
        sampleRate: sampleRate,
        seconds: 1.5,
        partials: const [0.0, 1.0, 0.8, 0.5, 0.3],
      );
      final without = measure(signal, ReferencePitches.c2);
      final with_ = measure(signal, ReferencePitches.c2, prior: ReferencePitches.c2);

      expect(without.octaveErrors, 0);
      expect(without.medianCents, lessThan(centsTolerance));
      expect(with_.octaveErrors, 0);
      expect(with_.medianCents, lessThan(centsTolerance));
    });

    test('an estimate a whole octave off IS snapped back onto the expected note', () {
      // Direct test of the snap itself: analyse a real 2*C2 tone while the
      // drill expects C2. This is the octave lock the G1-C benchmark saw pYIN
      // fall into on the open C string.
      final octaveHigh = SyntheticTone.harmonic(
          f0Hz: ReferencePitches.c2 * 2, sampleRate: sampleRate, seconds: 1.0);
      final guided = YinPitchSource(expectedHzPrior: ReferencePitches.c2);
      final reading = guided.analyze(
        octaveHigh.sublist(20000, 20000 + 4096),
        sampleRate: sampleRate,
        tStartUs: 0,
      );
      expect(reading.hasPitch, isTrue);
      expect(absCents(reading.f0Hz!, ReferencePitches.c2), lessThan(centsTolerance));
    });

    test('a note far outside the expected range is reported as no-pitch, not as a wrong note', () {
      final signal =
          SyntheticTone.harmonic(f0Hz: ReferencePitches.a4, sampleRate: sampleRate, seconds: 1.0);
      final source = YinPitchSource(expectedHzPrior: ReferencePitches.c2);
      final reading = source.analyze(
        signal.sublist(20000, 20000 + 4096),
        sampleRate: sampleRate,
        tStartUs: 0,
      );
      expect(reading.hasPitch, isFalse);
    });
  });

  group('Refusal to answer', () {
    test('room noise yields no pitch', () {
      final noise = SyntheticTone.roomNoise(sampleRate: sampleRate, seconds: 1.0);
      final source = YinPitchSource();
      var pitched = 0;
      for (var i = 0; i + 4096 <= noise.length; i += 2048) {
        final r = source.analyze(noise.sublist(i, i + 4096), sampleRate: sampleRate, tStartUs: 0);
        if (r.hasPitch) pitched++;
      }
      expect(pitched, 0, reason: 'noise must never produce a confident note');
    });

    test('a window too short for two periods of the lowest note returns no pitch', () {
      final signal =
          SyntheticTone.harmonic(f0Hz: ReferencePitches.c2, sampleRate: sampleRate, seconds: 0.5);
      final source = YinPitchSource(minHz: 50);
      // 512 samples at 44.1 kHz is 11.6 ms — less than one period of C2.
      final r = source.analyze(signal.sublist(10000, 10512), sampleRate: sampleRate, tStartUs: 0);
      expect(r.hasPitch, isFalse);
    });
  });
}
