// Offline second-corpus replay. No native/microphone/network calls.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ostinato_audio/ostinato_audio.dart';

final app = File.fromUri(Platform.script).parent.parent;
final scratch = Directory(
  '${app.parent.parent.parent.path}/scratch/2026-09-26-motion-device-release/note-corpus',
);

String hash(File file) {
  final result = Process.runSync('shasum', ['-a', '256', file.path]);
  if (result.exitCode != 0) throw StateError('shasum failed: ${file.path}');
  return (result.stdout as String).split(' ').first;
}

({int rate, int channels, int bits, List<double> mono}) decodeWav(
  Uint8List bytes,
) {
  String ascii(int start, int size) =>
      String.fromCharCodes(bytes.sublist(start, start + size));
  final b = ByteData.sublistView(bytes);
  if (bytes.length < 44 || ascii(0, 4) != 'RIFF' || ascii(8, 4) != 'WAVE') {
    throw const FormatException('Not RIFF WAV');
  }
  int? tag, channels, rate, bits, block, begin, size;
  for (var p = 12; p + 8 <= bytes.length;) {
    final length = b.getUint32(p + 4, Endian.little);
    final body = p + 8;
    if (body + length > bytes.length) {
      throw const FormatException('Truncated WAV chunk');
    }
    if (ascii(p, 4) == 'fmt ') {
      if (length < 16) throw const FormatException('Truncated fmt');
      tag = b.getUint16(body, Endian.little);
      channels = b.getUint16(body + 2, Endian.little);
      rate = b.getUint32(body + 4, Endian.little);
      block = b.getUint16(body + 12, Endian.little);
      bits = b.getUint16(body + 14, Endian.little);
      if (tag == 65534) {
        if (length < 40) throw const FormatException('Invalid extensible WAV');
        tag = b.getUint16(body + 24, Endian.little);
      }
    } else if (ascii(p, 4) == 'data') {
      begin = body;
      size = length;
    }
    p = body + length + (length.isOdd ? 1 : 0);
  }
  if (tag == null ||
      channels == null ||
      rate == null ||
      bits == null ||
      block == null ||
      begin == null ||
      size == null ||
      ![1, 3].contains(tag) ||
      ![1, 2].contains(channels) ||
      ![16, 24, 32, 64].contains(bits) ||
      block != channels * bits ~/ 8 ||
      size % block != 0 ||
      (tag == 3 && ![32, 64].contains(bits))) {
    throw const FormatException('Unsupported PCM/float WAV');
  }
  double sample(int p) {
    if (tag == 3) {
      return bits == 32
          ? b.getFloat32(p, Endian.little)
          : b.getFloat64(p, Endian.little);
    }
    return switch (bits) {
      16 => b.getInt16(p, Endian.little) / 32768,
      24 =>
        ((b.getUint8(p) | b.getUint8(p + 1) << 8 | b.getUint8(p + 2) << 16) <<
                40 >>
                40) /
            8388608,
      32 => b.getInt32(p, Endian.little) / 2147483648,
      64 => b.getInt64(p, Endian.little) / 9.223372036854776e18,
      _ => throw const FormatException('Invalid bit width'),
    };
  }

  final mono = List<double>.generate(size ~/ block, (frame) {
    var sum = 0.0;
    for (var c = 0; c < channels!; c++) {
      sum += sample(begin! + frame * block! + c * bits! ~/ 8);
    }
    return sum / channels;
  });
  return (rate: rate, channels: channels, bits: bits, mono: mono);
}

GuitarPitchObserver observer(Map<String, dynamic> json) {
  final p = json['pitchGate'] as Map<String, dynamic>;
  final g = json['guard'] as Map<String, dynamic>;
  double n(Map<String, dynamic> m, String k) => (m[k] as num).toDouble();
  return GuitarPitchObserver(
    config: GuitarSingleNoteConfig(
      windowSize: p['windowSize'],
      hopSize: p['hopSize'],
      minReliableWindows: p['minReliableWindows'],
      minHz: n(p, 'minHz'),
      maxHz: n(p, 'maxHz'),
      yinThreshold: n(p, 'yinThreshold'),
      minPeriodicity: n(p, 'minPeriodicity'),
      minLevelAboveFloorDb: n(p, 'minLevelAboveFloorDb'),
      attackWindowUs: p['attackWindowUs'],
      maxSpreadCents: n(p, 'maxSpreadCents'),
      maxCenterErrorCents: n(p, 'maxCenterErrorCents'),
    ),
    guard: GuitarObservationGuardConfig(
      maxResidualPowerRatio: n(g, 'maxResidualPowerRatio'),
      minFundamentalPowerRatio: n(g, 'minFundamentalPowerRatio'),
      clippingPeak: n(g, 'clippingPeak'),
      maxClippedFraction: n(g, 'maxClippedFraction'),
      harmonicToleranceCents: n(g, 'harmonicToleranceCents'),
      minAnalysisHz: n(g, 'minAnalysisHz'),
      maxAnalysisHz: n(g, 'maxAnalysisHz'),
      minFftSamples: g['minFftSamples'],
    ),
  );
}

void selfTest() {
  Uint8List fixture(int tag, int bits, int channels, List<num> values) {
    final dataSize = values.length * bits ~/ 8;
    final bytes = Uint8List(44 + dataSize);
    final b = ByteData.sublistView(bytes);
    for (final entry in {
      0: 'RIFF',
      8: 'WAVE',
      12: 'fmt ',
      36: 'data',
    }.entries) {
      bytes.setRange(entry.key, entry.key + 4, entry.value.codeUnits);
    }
    b.setUint32(4, bytes.length - 8, Endian.little);
    b.setUint32(16, 16, Endian.little);
    b.setUint16(20, tag, Endian.little);
    b.setUint16(22, channels, Endian.little);
    b.setUint32(24, 48000, Endian.little);
    b.setUint16(32, channels * bits ~/ 8, Endian.little);
    b.setUint16(34, bits, Endian.little);
    b.setUint32(40, dataSize, Endian.little);
    for (var i = 0; i < values.length; i++) {
      final p = 44 + i * bits ~/ 8;
      if (tag == 3) {
        b.setFloat32(p, values[i].toDouble(), Endian.little);
      } else if (bits == 16) {
        b.setInt16(p, values[i].toInt(), Endian.little);
      } else if (bits == 24) {
        for (var k = 0; k < 3; k++) {
          b.setUint8(p + k, values[i].toInt() >> (8 * k) & 255);
        }
      } else {
        b.setInt32(p, values[i].toInt(), Endian.little);
      }
    }
    return bytes;
  }

  void near(double a, double b) {
    if ((a - b).abs() > 1e-7) throw StateError('Decoder mismatch $a/$b');
  }

  near(decodeWav(fixture(1, 16, 1, [-16384])).mono.single, -.5);
  near(decodeWav(fixture(1, 24, 1, [-4194304])).mono.single, -.5);
  near(decodeWav(fixture(1, 32, 1, [1073741824])).mono.single, .5);
  near(decodeWav(fixture(3, 32, 2, [.25, .75])).mono.single, .5);
  var refused = false;
  try {
    decodeWav(fixture(1, 16, 1, [0]).sublist(0, 43));
  } on FormatException {
    refused = true;
  }
  if (!refused) throw StateError('Truncated WAV accepted');
  stdout.writeln(
    '5 decoder checks passed (PCM16/24/32, float32 stereo, truncated)',
  );
}

void main(List<String> args) {
  if (args.length == 1 && args.single == '--self-test') {
    selfTest();
    return;
  }
  if (args.isNotEmpty) throw ArgumentError('Use no arguments or --self-test');
  final freeze = jsonDecode(
    File('${scratch.path}/freeze.json').readAsStringSync(),
  );
  final configFile = File(
    '${app.path}/assets/config/guitar-observation.v1.json',
  );
  if (hash(configFile) != freeze['configSha256']) {
    throw StateError('Frozen config changed');
  }
  for (final entry in (freeze['reviewedFiles'] as Map).entries) {
    if (hash(File('${app.path}/${entry.key}')) != entry.value) {
      throw StateError('Reviewed source changed: ${entry.key}');
    }
  }
  final detector = observer(jsonDecode(configFile.readAsStringSync()));
  final manifest = jsonDecode(
    File('${scratch.path}/manifest.json').readAsStringSync(),
  );
  final results = <Map<String, Object?>>[];
  for (final recording in manifest['recordings']) {
    for (final window in recording['windows']) {
      final file = File(window['path']);
      if (file.lengthSync() != window['bytes'] ||
          hash(file) != window['sha256']) {
        throw StateError('Window receipt mismatch ${file.path}');
      }
      final wav = decodeWav(file.readAsBytesSync());
      if (wav.rate != window['sampleRate'] || wav.mono.length != 8192) {
        throw StateError('Manifest WAV format mismatch');
      }
      final stopwatch = Stopwatch()..start();
      final result = detector.observe(
        wav.mono,
        sampleRate: wav.rate,
        tStartUs: ((window['startFrame'] as int) * 1000000 / wav.rate).round(),
        roomFloorDb: (recording['roomFloorDbfs'] as num).toDouble(),
        lastOnsetTUs: ((window['onsetS'] as num) * 1000000).round(),
      );
      stopwatch.stop();
      final value = result.observation;
      final reference = (window['referenceMidi'] as List).cast<int>();
      final positive = recording['kind'] == 'positive';
      results.add({
        'player': recording['player'],
        'recording': recording['recording'],
        'kind': recording['kind'],
        'windowPath': file.path,
        'startFrame': window['startFrame'],
        'referenceMidi': reference,
        'observedMidi': value?.midi,
        'observedHz': value?.hz,
        'centsFromNearestCenter': value?.centsFromCenter,
        'nominalMidiReferenceCentsDifference': value == null || !positive
            ? null
            : 1200 *
                  math.log(
                    value.hz /
                        (440 * math.pow(2, (reference.single - 69) / 12)),
                  ) /
                  math.ln2,
        'continuousF0ErrorAvailable': false,
        'label': value == null
            ? 'refused'
            : positive
            ? value.midi == reference.single
                  ? 'nominalNoteMatched'
                  : 'differentNominalNote'
            : 'singleNoteOutputOnAnnotatedPolyphony',
        'reason': result.reason.name,
        'analysisUsDesktop': stopwatch.elapsedMicroseconds,
        'sampleRate': wav.rate,
        'channels': wav.channels,
        'bitsPerSample': wav.bits,
      });
      wav.mono.fillRange(0, wav.mono.length, 0);
    }
  }
  Map<String, Object?> summarize(String kind) {
    final rows = results.where((r) => r['kind'] == kind).toList();
    final counts = <String, int>{}, reasons = <String, int>{};
    for (final row in rows) {
      counts.update(row['label'] as String, (v) => v + 1, ifAbsent: () => 1);
      reasons.update(row['reason'] as String, (v) => v + 1, ifAbsent: () => 1);
    }
    return {
      'players': rows.map((r) => r['player']).toSet().toList(),
      'recordings': rows.map((r) => r['recording']).toSet().toList(),
      'windowCount': rows.length,
      'labels': counts,
      'reasons': reasons,
    };
  }

  final report = {
    'source': manifest['source'],
    'configSha256': freeze['configSha256'],
    'positive': summarize('positive'),
    'polyphonicNegative': summarize('polyphonicNegative'),
    'continuousF0ErrorAvailable': false,
    'trainingOrTuning': false,
    'physicalPhoneAccuracyEvidence': false,
    'correlationUnit':
        'players/clips; windows within long clips are correlated',
    'floorMethod':
        'source10th-percentile50ms mono RMS; offline, not phone quiet-room calibration',
    'results': results,
  };
  File('${scratch.path}/replay.json').writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(report)}\n',
  );
  stdout.writeln(
    const JsonEncoder.withIndent(
      '  ',
    ).convert({...report, 'results': '${results.length}rows in replay.json'}),
  );
}
