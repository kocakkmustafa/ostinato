import 'package:ostinato_audio/ostinato_audio.dart';
import 'package:test/test.dart';

/// Regression cover for O-019: the onset detector reported a sustained cello
/// C2 as ~13 note attacks per second, and every onset roughly half a window
/// early. Both defects were invisible to the unit tests that existed, because
/// those tests only ever used a treble fixture.
///
/// The register sweep is the point. A single-pitch test cannot see a defect
/// whose whole shape is "works above 147 Hz".
void main() {
  const sampleRate = 44100;
  const detector = OnsetDetector();

  /// Lowest note each starting instrument can produce, plus the register above
  /// it. Cello C2 is the binding case and the reason this sweep exists.
  const register = <String, double>{
    'cello C2': 65.4,
    'guitar low G2': 98.0,
    'guitar D3': 146.8,
    'voice A3': 220.0,
    'voice A4': 440.0,
    'voice A5': 880.0,
  };

  group('a sustained note produces no onsets', () {
    register.forEach((name, f0) {
      test(name, () {
        final tone = SyntheticTone.harmonic(f0Hz: f0, sampleRate: sampleRate, seconds: 3.0);
        expect(
          detector.detect(tone, sampleRate: sampleRate, tStartUs: 0),
          isEmpty,
          reason: 'A note that never stops has exactly one attack, at the very '
              'start, which this fixture begins before. Anything detected here '
              'is the analysis wobbling, and the confidence gate reads every '
              'one of them as an attack window it must refuse to judge.',
        );
      });

      test('$name survives a phone microphone highpass', () {
        final tone = SyntheticTone.phoneHighpass(
          SyntheticTone.harmonic(f0Hz: f0, sampleRate: sampleRate, seconds: 3.0),
          sampleRate: sampleRate,
        );
        expect(detector.detect(tone, sampleRate: sampleRate, tStartUs: 0), isEmpty);
      });
    });
  });

  group('real note starts are found across the register', () {
    const onsetsMs = [500, 1000, 1500, 2000, 2500];

    for (final f0 in [65.4, 146.8, 523.25, 880.0]) {
      test('${f0.toStringAsFixed(0)} Hz — all five, within 15 ms', () {
        final signal = SyntheticTone.notesAt(
          onsetSeconds: const [0.5, 1.0, 1.5, 2.0, 2.5],
          f0Hz: f0,
          sampleRate: sampleRate,
          totalSeconds: 3.2,
        );
        final got = detector.detect(signal, sampleRate: sampleRate, tStartUs: 0);
        expect(got, hasLength(onsetsMs.length));

        for (var i = 0; i < onsetsMs.length; i++) {
          expect(
            (got[i].tUs / 1000 - onsetsMs[i]).abs(),
            lessThan(15),
            reason: 'Onset ${i + 1} landed at ${got[i].tUs / 1000} ms. Rhythm '
                'scoring is built on these timestamps, so a bias here becomes a '
                'bias in every timing verdict the app ever gives.',
          );
        }
      });
    }
  });

  test('band edges follow frequency, not sample rate', () {
    // A detector instance reused across a 44.1 kHz fixture and a 48 kHz device
    // stream must analyse the same frequencies in both. Caching bin indices
    // from the first rate seen would silently mis-analyse the second.
    for (final rate in [44100, 48000]) {
      final signal = SyntheticTone.notesAt(
        onsetSeconds: const [0.5, 1.0, 1.5],
        f0Hz: 65.4,
        sampleRate: rate,
        totalSeconds: 2.2,
      );
      expect(
        detector.detect(signal, sampleRate: rate, tStartUs: 0),
        hasLength(3),
        reason: 'Detection changed with sample rate at $rate Hz.',
      );
    }
  });

  test('analysis bandwidth does not shrink when the frame grows', () {
    // The defect that made the naive fix look correct: with a fixed *bin count*
    // rather than a fixed frequency range, a longer frame quietly lowered the
    // analysis ceiling until a C5's harmonics fell outside it entirely.
    final treble = SyntheticTone.notesAt(
      onsetSeconds: const [0.5, 1.0, 1.5],
      f0Hz: 523.25,
      sampleRate: sampleRate,
      totalSeconds: 2.2,
    );
    for (final frameMs in [23.0, 46.0, 93.0]) {
      final wide = OnsetDetector(frameMs: frameMs);
      final ceilingHz =
          wide.bandEdges(sampleRate).last * sampleRate / wide.frameSizeFor(sampleRate);
      expect(ceilingHz, greaterThan(1000),
          reason: 'frameMs $frameMs analyses only up to $ceilingHz Hz.');
      expect(wide.detect(treble, sampleRate: sampleRate, tStartUs: 0), hasLength(3),
          reason: 'Treble onsets lost at frameMs $frameMs.');
    }
  });
}
