import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:ostinato_audio/ostinato_audio.dart';

import 'audio_fixture_io.dart';

final appRoot = File.fromUri(Platform.script).parent.parent;
final scratch = Directory(
  '${appRoot.parent.parent.parent.path}/scratch/2026-09-26-motion-courses/ostinato',
);

double _median(List<double> values) {
  values.sort();
  return values[values.length ~/ 2];
}

double _percentile(List<double> values, double fraction) {
  values.sort();
  return values[(fraction * (values.length - 1)).round()];
}

double _floor(List<double> samples, int sampleRate) {
  final chunk = (sampleRate * 0.05).round();
  final levels = <double>[];
  for (var i = 0; i + chunk <= samples.length; i += chunk) {
    levels.add(rmsDb(samples.sublist(i, i + chunk)));
  }
  return _percentile(levels, 0.10);
}

GuitarSingleNoteConfig _config(Map<String, dynamic> m) =>
    GuitarSingleNoteConfig(
      windowSize: m['windowSize'] as int,
      hopSize: m['hopSize'] as int,
      minReliableWindows: m['minReliableWindows'] as int,
      minHz: (m['minHz'] as num).toDouble(),
      maxHz: (m['maxHz'] as num).toDouble(),
      yinThreshold: (m['yinThreshold'] as num).toDouble(),
      minPeriodicity: (m['minPeriodicity'] as num).toDouble(),
      minLevelAboveFloorDb: (m['minLevelAboveFloorDb'] as num).toDouble(),
      attackWindowUs: m['attackWindowUs'] as int,
      maxSpreadCents: (m['maxSpreadCents'] as num).toDouble(),
      maxCenterErrorCents: (m['maxCenterErrorCents'] as num).toDouble(),
    );

void main(List<String> args) {
  final observationMode = args.length == 2 && args.last == 'observation';
  if ((args.length != 1 && !observationMode) ||
      !const ['development', 'holdout'].contains(args.first)) {
    stderr.writeln(
      'usage: dart run tool/guitar_single_note_replay.dart development|holdout',
    );
    exitCode = 64;
    return;
  }
  final split = args.first;
  final manifest =
      jsonDecode(
            File(
              '${scratch.path}/${observationMode ? 'observation' : 'single-note'}-manifest.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  final config = _config(
    jsonDecode(
          File(
            '${appRoot.path}/config/guitar-single-note-gate.v1.json',
          ).readAsStringSync(),
        )
        as Map<String, dynamic>,
  );
  final evaluator = GuitarSingleNoteEvaluator(config: config);
  GuitarPitchObserver? observer;
  if (observationMode) {
    final json =
        jsonDecode(
              File(
                '${appRoot.path}/assets/config/guitar-observation.v1.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final g = json['guard'] as Map<String, dynamic>;
    double n(String key) => (g[key] as num).toDouble();
    observer = GuitarPitchObserver(
      config: _config(json['pitchGate'] as Map<String, dynamic>),
      guard: GuitarObservationGuardConfig(
        maxResidualPowerRatio: n('maxResidualPowerRatio'),
        minFundamentalPowerRatio: n('minFundamentalPowerRatio'),
        clippingPeak: n('clippingPeak'),
        maxClippedFraction: n('maxClippedFraction'),
        harmonicToleranceCents: n('harmonicToleranceCents'),
        minAnalysisHz: n('minAnalysisHz'),
        maxAnalysisHz: n('maxAnalysisHz'),
        minFftSamples: g['minFftSamples'] as int,
      ),
    );
  }
  final perPlayer = <String, Map<String, dynamic>>{};
  final details = <Map<String, dynamic>>[];
  final allErrors = <double>[];
  for (final source
      in (manifest['sources'] as List<dynamic>).cast<Map<String, dynamic>>()) {
    if (source['split'] != split) continue;
    final player = source['player'] as String;
    final wav = PcmWav.readFile(source['audioPath'] as String);
    if (wav.channels != 1 || wav.sampleRate != source['sampleRate']) {
      throw StateError(
        'WAV and manifest format mismatch: ${source['recording']}',
      );
    }
    final floor = _floor(wav.samples, wav.sampleRate);
    final count = perPlayer.putIfAbsent(
      player,
      () => {
        'player': player,
        'candidateCount': 0,
        'match': 0,
        'differentNote': 0,
        'noVerdict': 0,
        'accepted': 0,
        'reasons': <String, int>{},
        'recordings': <String>[],
      },
    );
    (count['recordings'] as List<String>).add(source['recording'] as String);
    for (final candidate
        in (source['candidates'] as List<dynamic>)
            .cast<Map<String, dynamic>>()) {
      final start = candidate['startFrame'] as int;
      final windowSamples = manifest['selection']['windowSamples'] as int;
      final segment = wav.samples.sublist(start, start + windowSamples);
      var result = evaluator.evaluate(
        segment,
        sampleRate: wav.sampleRate,
        tStartUs: (start * 1000000 / wav.sampleRate).round(),
        expectedMidi: candidate['targetMidi'] as int,
        roomFloorDb: floor,
        lastOnsetTUs: ((candidate['onsetS'] as num) * 1000000).round(),
      );
      if (observer != null) {
        final observed = observer.observe(
          segment,
          sampleRate: wav.sampleRate,
          tStartUs: (start * 1000000 / wav.sampleRate).round(),
          roomFloorDb: floor,
          lastOnsetTUs: ((candidate['onsetS'] as num) * 1000000).round(),
        );
        final value = observed.observation;
        final midi = candidate['targetMidi'] as int;
        result = GuitarSingleNoteResult(
          verdict: value == null
              ? GuitarSingleNoteVerdict.noVerdict
              : value.midi == midi
              ? GuitarSingleNoteVerdict.match
              : GuitarSingleNoteVerdict.differentNote,
          reason: observed.reason,
          totalWindows: observed.totalWindows,
          reliableWindows: observed.reliableWindows,
          observedHz: value?.hz,
          observedMidi: value?.midi,
          signedCentsFromTarget: value == null
              ? null
              : cents(
                  value.hz,
                  (440 * math.pow(2, (midi - 69) / 12)).toDouble(),
                ),
        );
      }
      count['candidateCount'] = (count['candidateCount'] as int) + 1;
      final verdictName = result.verdict.name;
      count[verdictName] = (count[verdictName] as int) + 1;
      final reasons = count['reasons'] as Map<String, int>;
      reasons[result.reason.name] = (reasons[result.reason.name] ?? 0) + 1;
      double? errorCents;
      if (result.verdict != GuitarSingleNoteVerdict.noVerdict) {
        count['accepted'] = (count['accepted'] as int) + 1;
        final annotationHz =
            440 * math.pow(2, ((candidate['annotatedMidi'] as num) - 69) / 12);
        errorCents = absCents(result.observedHz!, annotationHz.toDouble());
        allErrors.add(errorCents);
      }
      details.add({
        'player': player,
        'recording': source['recording'],
        'eventIndex': candidate['eventIndex'],
        'targetMidi': candidate['targetMidi'],
        'annotatedMidi': candidate['annotatedMidi'],
        'verdict': verdictName,
        'reason': result.reason.name,
        'observedMidi': result.observedMidi,
        'observedHz': result.observedHz,
        'errorCents': errorCents,
        'reliableWindows': result.reliableWindows,
        'totalWindows': result.totalWindows,
        'roomFloorDbfs': floor,
      });
    }
  }
  final candidates = perPlayer.values.fold<int>(
    0,
    (sum, p) => sum + p['candidateCount'] as int,
  );
  final accepted = perPlayer.values.fold<int>(
    0,
    (sum, p) => sum + p['accepted'] as int,
  );
  final incorrect = perPlayer.values.fold<int>(
    0,
    (sum, p) => sum + p['differentNote'] as int,
  );
  final summary = {
    'split': split,
    'candidateCount': candidates,
    'accepted': accepted,
    'coverage': accepted / candidates,
    'differentNote': incorrect,
    'differentNoteAmongAccepted': accepted == 0 ? null : incorrect / accepted,
    'medianAbsCentsAccepted': allErrors.isEmpty
        ? null
        : _median([...allErrors]),
    'p90AbsCentsAccepted': allErrors.isEmpty
        ? null
        : _percentile([...allErrors], 0.90),
    'players': perPlayer.values.toList(),
    'details': details,
  };
  final output = File(
    '${scratch.path}/${observationMode ? 'observation-' : ''}$split-replay.json',
  );
  output.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(summary)}\n',
  );
  stdout.writeln(
    const JsonEncoder.withIndent('  ').convert({
      ...summary,
      'details': '${details.length} rows in ${output.path}',
    }),
  );
}
