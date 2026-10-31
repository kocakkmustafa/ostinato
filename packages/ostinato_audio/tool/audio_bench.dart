// Wall-clock cost of one tuner / verifier call on this machine, for the
// E40 engine and the E41 "ALL" options. Synthetic input only (no dataset).
//
//   dart compile exe tool/audio_bench.dart -o /tmp/bench && /tmp/bench [reps]
//
// Prints median and p95 milliseconds per call. Run on an otherwise idle
// machine; this is a desktop measurement, not a device measurement.
import 'dart:io';
import 'dart:math' as math;

import 'package:ostinato_audio/ostinato_audio.dart';

void main(List<String> args) {
  final reps = args.isEmpty ? 50 : int.parse(args.first);
  const sr = 48000;
  const q = PhoneChannelConfig(
      noise: ChannelNoise.pink, snrDb: 35, lowCutHz: 100, agc: true);
  double hz(num m) => 440 * math.pow(2, (m - 69) / 12).toDouble();

  // 1.6 s tuning buffer (the app's), pluck at 0.15 s; 0.6 s practice note.
  final tuningBuffer = PhoneChannel.apply(
      SyntheticString.pluck(
          f0Hz: hz(45), sampleRate: sr, seconds: 1.45, preRollSeconds: 0.15),
      sr,
      q);
  final note = PhoneChannel.apply(
      SyntheticString.pluck(
          f0Hz: hz(57), sampleRate: sr, seconds: 0.5, preRollSeconds: 0.1),
      sr,
      q);

  const a2 = AttackLocator(bufferStartCandidate: true, maxBelowLoudestDb: 12);
  final configs = <String, (PreciseTuner, GuitarNoteVerifier)>{
    'E40': (PreciseTuner(), GuitarNoteVerifier()),
    'E41-ALL': (
      PreciseTuner(
        profile: PreciseTunerProfile.guitar.copyWith(
            adaptiveWindowPeriods: 40,
            maxAnalysisHz: 7500,
            maxLateSpreadCents: 10),
        attackLocator: a2,
      ),
      GuitarNoteVerifier(
          config: const NoteVerifierConfig(fifthRival: true),
          attackLocator: a2),
    ),
  };

  (double, double) time(void Function() f) {
    for (var i = 0; i < 3; i++) {
      f(); // warm-up
    }
    final ms = <double>[];
    for (var i = 0; i < reps; i++) {
      final sw = Stopwatch()..start();
      f();
      ms.add(sw.elapsedMicroseconds / 1000);
    }
    ms.sort();
    return (ms[ms.length ~/ 2], ms[((ms.length - 1) * 0.95).round()]);
  }

  stdout.writeln('reps=$reps (median ms / p95 ms per call)');
  for (final MapEntry(key: name, value: (tuner, verifier)) in configs.entries) {
    final t = time(() => tuner.measure(tuningBuffer, sampleRate: sr));
    final v =
        time(() => verifier.verify(note, sampleRate: sr, expectedMidi: 57));
    final o = time(() => const AttackLocator()
        .lastUsableAttack(tuningBuffer, sr, requiredSamples: sr));
    stdout.writeln('$name tuner(1.6 s)=${t.$1.toStringAsFixed(1)}/'
        '${t.$2.toStringAsFixed(1)}  verifier(0.6 s)=${v.$1.toStringAsFixed(1)}/'
        '${v.$2.toStringAsFixed(1)}  attackLocator(1.6 s)=${o.$1.toStringAsFixed(1)}/'
        '${o.$2.toStringAsFixed(1)}');
  }
}
