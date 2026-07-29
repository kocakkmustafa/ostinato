import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:ostinato_audio/ostinato_audio.dart';

/// Builds the `ostinato-audiofix-1` audio fixture set.
///
/// Values are not authored: the signal is synthesised, then run through the
/// **real engine** (YIN + OnsetDetector + AudioConfidenceGate) and what the
/// engine measured is what gets written. So each fixture is both an input for
/// replay and a record of how the engine behaves on it — a change in engine
/// behaviour shows up as a diff here.
///
/// Negative fixtures (`shouldJudge:false`) are mandatory. The cases where the
/// engine must stay quiet are tested as hard as the ones where it speaks.
const sampleRate = 44100;
const windowSamples = 4096;
const hopSamples = 2048;

/// One quiet-room floor for every fixture.
///
/// Earlier this was keyed off the fixture's own label — negative fixtures were
/// handed a higher floor, which is circular: the set would have "proved" the
/// gate refuses quiet playing using a floor picked to make it refuse. Levels
/// below are derived to sit where the fixture claims to sit relative to this
/// one number.
const roomFloorDb = -60.0;

double _rmsDb(List<double> x) {
  var sum = 0.0;
  for (final v in x) {
    sum += v * v;
  }
  return 20 * math.log(math.sqrt(sum / x.length) + 1e-12) / math.ln10;
}

/// Rescale a signal so it lands [db] above the room floor.
List<double> _atLevel(List<double> x, double db) {
  final gain = math.pow(10, (roomFloorDb + db - _rmsDb(x)) / 20).toDouble();
  return [for (final v in x) v * gain];
}

void main(List<String> args) {
  final outDir = Directory(args.isEmpty ? '../../fixtures/audio' : args.first)
    ..createSync(recursive: true);

  const scaleOnsets = [0.5, 1.0, 1.5, 2.0, 2.5];

  final specs = <Map<String, dynamic>>[
    {
      'id': 'AF-001-clean-sustained-a4',
      'kind': 'synthetic',
      'what': 'Clean sustained note (A4). The engine should speak: stable pitch, ample level.',
      'signal': SyntheticTone.harmonic(f0Hz: ReferencePitches.a4, sampleRate: sampleRate, seconds: 3.0),
      'expectedF0': ReferencePitches.a4,
      'expectedOnsets': 0,
      'shouldJudge': true,
    },
    {
      'id': 'AF-002-room-noise-only',
      'kind': 'synthetic-negative',
      'what': 'Room noise at the floor, nothing played. The engine must stay silent.',
      'signal': _atLevel(SyntheticTone.roomNoise(sampleRate: sampleRate, seconds: 3.0), 1.0),
      'expectedF0': null,
      'expectedOnsets': 0,
      'shouldJudge': false,
    },
    {
      'id': 'AF-003-scale-with-metronome',
      'kind': 'synthetic',
      'what': 'Five-note scale on a 120bpm grid. Exercises onset detection and timing.',
      'signal': SyntheticTone.notesAt(
          onsetSeconds: scaleOnsets, f0Hz: ReferencePitches.c5,
          sampleRate: sampleRate, totalSeconds: 3.2),
      'expectedF0': ReferencePitches.c5,
      'expectedOnsets': scaleOnsets.length,
      'clickTimesUs': [for (final s in scaleOnsets) (s * 1000000).round()],
      'shouldJudge': true,
      // Discrete notes, so the judgeable ceiling is set by the fixture's own
      // shape: the silence between notes and the 100 ms attack window after
      // each one are legitimately unjudgeable. Holding this to the sustained
      // fixtures' bar would be demanding the engine judge silence.
      'minJudgedFraction': 0.5,
      'minJudgedWhy': 'discrete notes — gaps and attack windows are not judgeable',
    },
    {
      'id': 'AF-004-quiet-playing',
      'kind': 'synthetic-negative',
      'what': 'Playing 3 dB above the room floor. Measurable, but not enough to '
          'judge on — the gate must refuse rather than guess.',
      'signal': _atLevel(
          SyntheticTone.harmonic(f0Hz: ReferencePitches.a4, sampleRate: sampleRate, seconds: 2.0),
          3.0),
      'expectedF0': ReferencePitches.a4,
      'expectedOnsets': 0,
      'shouldJudge': false,
    },
    {
      'id': 'AF-005-cello-c2-phone-mic',
      'kind': 'synthetic',
      'what': 'Cello C2 through a simulated phone microphone (120 Hz highpass). '
          'The hardest case: the fundamental is attenuated and the engine has to '
          'find the period from the harmonics. This fixture is what exposed O-019.',
      'signal': SyntheticTone.phoneHighpass(
          SyntheticTone.harmonic(f0Hz: ReferencePitches.c2, sampleRate: sampleRate, seconds: 3.0),
          sampleRate: sampleRate),
      'expectedF0': ReferencePitches.c2,
      'expectedOnsets': 0,
      'shouldJudge': true,
    },
    {
      'id': 'AF-006-noisy-10db',
      'kind': 'synthetic',
      'what': 'Sustained note at 10 dB SNR — the stand-in for a real room.',
      'signal': SyntheticTone.addNoise(
          SyntheticTone.harmonic(f0Hz: ReferencePitches.d3, sampleRate: sampleRate, seconds: 3.0),
          snrDb: 10),
      'expectedF0': ReferencePitches.d3,
      'expectedOnsets': 0,
      'shouldJudge': true,
      // Measured envelope across 8 noise seeds: 0 phantom onsets at 20 dB SNR,
      // at most 1 per 3 s at 10 dB, and 1-6 at 5 dB. Demanding exactly 0 here
      // would mean tuning the detector until one seeded noise realisation
      // happened to come out clean — overfitting to a fixture. The tolerance
      // records the real limit instead, and Setup Check owes the user a warning
      // below roughly 10 dB rather than a stream of phantom attack windows.
      'onsetTolerance': 1,
      'onsetToleranceWhy': 'noise floor at 10 dB SNR; measured max 1 per 3 s over 8 seeds',
    },
  ];

  /// A fixture that claims to be judgeable must be judgeable for most of its
  /// length, not for one lucky window. The first version of this script asked
  /// only for `judged > 0`, and passed the cello case at 1 usable window out of
  /// 63 — the exact defect the fixture existed to catch.
  ///
  /// Fixtures whose own structure lowers the ceiling override this and say why.
  const defaultMinJudgedFraction = 0.6;

  const gate = AudioConfidenceGate();
  final index = <Map<String, dynamic>>[];

  for (final spec in specs) {
    final signal = (spec['signal'] as List).cast<double>();
    final expectedF0 = spec['expectedF0'] as double?;
    final source = YinPitchSource(expectedHzPrior: expectedF0);

    final onsets = OnsetDetector().detect(signal, sampleRate: sampleRate, tStartUs: 0);
    final windows = <Map<String, dynamic>>[];
    var judged = 0;

    for (var i = 0; i + windowSamples <= signal.length; i += hopSamples) {
      final tUs = (i * 1000000 / sampleRate).round();
      final r = source.analyze(signal.sublist(i, i + windowSamples),
          sampleRate: sampleRate, tStartUs: tUs);
      final priorOnsets = onsets.where((o) => o.tUs <= tUs);
      final verdict = gate.evaluate(r,
          roomFloorDb: roomFloorDb,
          lastOnsetTUs: priorOnsets.isEmpty ? null : priorOnsets.last.tUs);
      if (verdict.mayJudge) judged++;
      windows.add({
        'tStartUs': r.tStartUs,
        'tEndUs': r.tEndUs,
        'f0Hz': r.f0Hz,
        'periodicity': double.parse(r.periodicity.toStringAsFixed(4)),
        'rmsDb': double.parse(r.rmsDb.toStringAsFixed(2)),
        'levelAboveFloorDb': double.parse((r.rmsDb - roomFloorDb).toStringAsFixed(2)),
        'verdict': verdict.verdict.name,
        'reason': verdict.reason.name,
      });
    }

    final expectedOnsets = spec['expectedOnsets'] as int;
    final onsetTolerance = (spec['onsetTolerance'] as int?) ?? 0;
    final minJudged = (spec['minJudgedFraction'] as double?) ?? defaultMinJudgedFraction;
    final judgedFraction = windows.isEmpty ? 0.0 : judged / windows.length;
    final shouldJudge = spec['shouldJudge'] as bool;
    final onsetDrift = (onsets.length - expectedOnsets).abs();
    final failures = <String>[
      if (shouldJudge && judgedFraction < minJudged)
        'only ${(judgedFraction * 100).round()}% of windows judged '
            '(needs ${(minJudged * 100).round()}%)',
      if (!shouldJudge && judged > 0) '\$judged windows judged; expected none',
      if (onsetDrift > onsetTolerance)
        '${onsets.length} onsets detected; expected \$expectedOnsets'
            '${onsetTolerance > 0 ? " ±\$onsetTolerance" : ""}',
    ];

    File('${outDir.path}/${spec['id']}.json').writeAsStringSync(
        const JsonEncoder.withIndent(' ').convert({
      'schemaVersion': 'ostinato-audiofix-1',
      'fixtureId': spec['id'],
      'kind': spec['kind'],
      r'$what': spec['what'],
      'recordingMeta': {
        'source': 'generated',
        'sampleRate': sampleRate,
        'windowSamples': windowSamples,
        'hopSamples': hopSamples,
        'roomFloorDb': roomFloorDb,
        'license': 'generated',
        r'$note': 'Synthetic, so the ground truth is exact. Real-recording '
            'fixtures are a separate track (the G1-A protocol). This set pins '
            'engine BEHAVIOUR, not real-world accuracy.',
      },
      'engineVersions': {
        'pitch': 'YinPitchSource (ostinato_audio 0.1.0)',
        'onset': 'OnsetDetector (spectral flux over log-spaced bands)',
        'gate': 'AudioConfidenceGate',
      },
      'expected': {
        'f0Hz': expectedF0,
        'onsets': expectedOnsets,
        if (onsetTolerance > 0) 'onsetTolerance': onsetTolerance,
        if (spec['onsetToleranceWhy'] != null) r'$onsetToleranceWhy': spec['onsetToleranceWhy'],
        'shouldJudge': shouldJudge,
        'minJudgedFraction': shouldJudge ? minJudged : null,
        if (spec['minJudgedWhy'] != null) r'$minJudgedWhy': spec['minJudgedWhy'],
        if (spec['clickTimesUs'] != null) 'clickTimesUs': spec['clickTimesUs'],
      },
      'measured': {
        'onsetsUs': [for (final o in onsets) o.tUs],
        'windows': windows,
        'judgedWindows': judged,
        'judgedFraction': double.parse(judgedFraction.toStringAsFixed(3)),
      },
    }));

    stdout.writeln('${failures.isEmpty ? "✅" : "❌"} ${spec['id']}: '
        '${windows.length} windows · judged ${(judgedFraction * 100).round()}% '
        '· ${onsets.length} onsets (expected $expectedOnsets)'
        '${failures.isEmpty ? "" : "\n     ${failures.join("\n     ")}"}');
    index.add({
      'fixtureId': spec['id'],
      'kind': spec['kind'],
      'shouldJudge': shouldJudge,
      'judgedFraction': double.parse(judgedFraction.toStringAsFixed(3)),
      'onsets': onsets.length,
      'ok': failures.isEmpty,
      if (failures.isNotEmpty) 'failures': failures,
    });
  }

  File('${outDir.path}/index.json')
      .writeAsStringSync(const JsonEncoder.withIndent(' ').convert({
    'schemaVersion': 'ostinato-audiofix-index-1',
    r'$why': 'A minimal audio set so audio-gated phases can be exercised by '
        'replay (the coverage gap M-F-56 named). Negative fixtures are '
        'mandatory: the engine staying quiet is tested as hard as it speaking.',
    'roomFloorDb': roomFloorDb,
    'fixtures': index,
  }));

  final failed = index.where((e) => e['ok'] != true).length;
  stdout.writeln(failed == 0
      ? '\n✅ ${index.length}/${index.length} fixtures behaved as declared'
      : '\n❌ $failed fixture(s) deviated from what they declare');
  exit(failed == 0 ? 0 : 1);
}
