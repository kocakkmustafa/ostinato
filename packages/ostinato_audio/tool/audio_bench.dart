// Wall-clock cost of one tuner / verifier call on this machine, for the
// E40 engine and the E41 "ALL" options. Synthetic input only (no dataset).
//
//   dart compile exe tool/audio_bench.dart -o /tmp/bench && /tmp/bench [reps]
//
// Prints median and p95 milliseconds per call. Run on an otherwise idle
// machine; this is a desktop measurement, not a device measurement.
//
// E51: `audio_bench.exe e51 <outdir> [reps]` times D's tuner call on the
// product's 1.6 s buffer and its verifier call on the 0.75 s window (3 warm-ups
// + reps, median), writes both inputs as f32le so the model arms are timed on
// the same audio, and writes `<outdir>/bench-D.json`.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;

import 'package:ostinato_audio/ostinato_audio.dart';

void main(List<String> args) {
  if (args.isNotEmpty && args.first == 'e51') {
    benchE51(args[1], args.length > 2 ? int.parse(args[2]) : 20);
    return;
  }
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

  // E43: the app's sliding use. 12 analyses 350 ms apart over a 5.5 s
  // stream of three plucks, one fresh tuner per sequence (cache per stream).
  final strum = <double>[];
  for (final (m, seed) in [(45, 1), (52, 2), (57, 3)]) {
    strum.addAll(SyntheticString.pluck(
        f0Hz: hz(m),
        sampleRate: sr,
        seconds: 1.8,
        preRollSeconds: 0.05,
        seed: seed));
  }
  final z = PhoneChannel.apply(strum, sr, q);
  final buffer = (1.6 * sr).round(), step = (0.35 * sr).round();
  double sliding(PreciseTuner tuner,
      {required bool global, required bool cache}) {
    final c = cache ? OnsetFrameCache() : null;
    final sw = Stopwatch()..start();
    var calls = 0;
    for (var t = buffer; t <= z.length; t += step) {
      final a = t - buffer;
      tuner.measure(z.sublist(a, t),
          sampleRate: sr,
          absoluteStartSample: global ? a : null,
          onsetCache: c);
      calls++;
    }
    return sw.elapsedMicroseconds / 1000 / calls;
  }

  final hop10 = PreciseTuner(
      attackLocator: const AttackLocator(detector: OnsetDetector(hopMs: 10)));
  final sliders = <String, double Function()>{
    'C (buffer grid)': () =>
        sliding(PreciseTuner(), global: false, cache: false),
    'S1g (global grid)': () =>
        sliding(PreciseTuner(), global: true, cache: false),
    'S1c (global grid + cache)': () =>
        sliding(PreciseTuner(), global: true, cache: true),
    'S2 (10 ms flux hop)': () => sliding(hop10, global: false, cache: false),
  };
  stdout.writeln(
      'sliding 1.6 s buffer every 350 ms (median / p95 ms per analysis, $reps sequences)');
  for (final MapEntry(key: name, value: f) in sliders.entries) {
    for (var i = 0; i < 2; i++) {
      f();
    }
    final v = [for (var i = 0; i < reps; i++) f()]..sort();
    stdout.writeln('$name ${v[v.length ~/ 2].toStringAsFixed(1)} / '
        '${v[((v.length - 1) * 0.95).round()].toStringAsFixed(1)}');
  }
}

/// E51 bench inputs: a guitar A2 pluck at 0.15 s in the 1.6 s tuning buffer,
/// an A3 pluck at 0.15 s (expected time) in the 0.75 s verifier window, both
/// through the quiet-phone channel (seed 0).
({Float64List tuner, Float64List verify}) e51BenchInputs() {
  const sr = 48000;
  const q = PhoneChannelConfig(
      noise: ChannelNoise.pink, snrDb: 35, lowCutHz: 100, agc: true);
  double hz(num m) => 440 * math.pow(2, (m - 69) / 12).toDouble();
  return (
    tuner: PhoneChannel.apply(
        SyntheticString.pluck(
            f0Hz: hz(45), sampleRate: sr, seconds: 1.45, preRollSeconds: 0.15),
        sr,
        q),
    verify: PhoneChannel.apply(
        SyntheticString.pluck(
            f0Hz: hz(57), sampleRate: sr, seconds: 0.6, preRollSeconds: 0.15),
        sr,
        q),
  );
}

void benchE51(String outDir, int reps) {
  const sr = 48000;
  final x = e51BenchInputs();
  Directory(outDir).createSync(recursive: true);
  for (final (name, v) in [
    ('tuner-1600ms', x.tuner),
    ('verify-750ms', x.verify)
  ]) {
    File('$outDir/bench-$name.f32')
        .writeAsBytesSync(Float32List.fromList(v).buffer.asUint8List());
  }
  // The arm reads the f32 file, as the models do.
  Float64List back(String name) {
    final b = File('$outDir/bench-$name.f32').readAsBytesSync();
    return Float64List.fromList(
        b.buffer.asFloat32List(b.offsetInBytes, b.lengthInBytes ~/ 4));
  }

  final tb = back('tuner-1600ms'), vb = back('verify-750ms');
  final tuner = PreciseTuner(), verifier = GuitarNoteVerifier();
  Map<String, num> time(void Function() f) {
    for (var i = 0; i < 3; i++) {
      f();
    }
    final ms = <double>[];
    for (var i = 0; i < reps; i++) {
      final sw = Stopwatch()..start();
      f();
      ms.add(sw.elapsedMicroseconds / 1000);
    }
    ms.sort();
    return {
      'medianMs': ms[ms.length ~/ 2],
      'p95Ms': ms[((ms.length - 1) * 0.95).round()],
      'reps': reps
    };
  }

  final t = time(() => tuner.measure(tb, sampleRate: sr));
  final v = time(() => verifier.verify(vb, sampleRate: sr, expectedMidi: 57));
  // The CREPE / SwiftF0 verifier arms use D's attack front end; its cost is
  // added to theirs.
  final required = (verifier.config.skipAfterOnsetMs * sr / 1000).round() +
      (verifier.config.minAnalysisMs * sr / 1000).round();
  final att = time(() => verifier.attackLocator
      .lastUsableAttack(vb, sr, requiredSamples: required));
  final res = {
    'arm': 'D',
    'tuner': {
      ...t,
      'audioS': tb.length / sr,
      'msPerAudioS': t['medianMs']! / (tb.length / sr),
      'f0': tuner.measure(tb, sampleRate: sr).measurement?.f0Hz,
    },
    'verify': {
      ...v,
      'audioS': vb.length / sr,
      'msPerAudioS': v['medianMs']! / (vb.length / sr),
      'attackMs': att['medianMs'],
      'attackIndex': verifier.attackLocator
          .lastUsableAttack(vb, sr, requiredSamples: required),
      'verdict':
          verifier.verify(vb, sampleRate: sr, expectedMidi: 57).verdict.name,
    },
  };
  File('$outDir/bench-D.json').writeAsStringSync(jsonEncode(res));
  stdout.writeln(jsonEncode(res));
}
