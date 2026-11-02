// E52 harness flags (tool/audio_eval.dart): seedSalt / seedOf and the
// confident-first display rule (arm T). Synthetic audio only.
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ostinato_audio/ostinato_audio.dart';
import 'package:test/test.dart';

import '../tool/audio_eval.dart' as ev;

const sr = 48000;
double hz(num midi) => 440 * math.pow(2, (midi - 69) / 12).toDouble();

TuningMeasurement meas(double f0, {int? attackIndex, bool late = false}) =>
    TuningMeasurement(
      f0Hz: f0,
      inharmonicityB: 1e-4,
      midi: 45,
      centsFromNearest: 0,
      spreadCents: late ? 5 : 1,
      readings: const [],
      fromLateReadings: late,
      attackIndex: attackIndex,
    );

const q = {
  'name': 'Q-quiet-phone',
  'reverb': true,
  'drrDb': 6,
  'noise': 'pink',
  'snrDb': 35,
  'lowCutHz': 100,
  'lowCutOrder': 2,
  'agc': true,
};

/// A 2 s lead-in (previous note's tail), then the note for 3 s.
String writeSegment(Directory dir) {
  final prev = SyntheticString.pluck(
      f0Hz: hz(40), sampleRate: sr, seconds: 2.0, seed: 7);
  final note = SyntheticString.pluck(
      f0Hz: hz(45), sampleRate: sr, seconds: 3.0, seed: 8);
  final x = Float32List.fromList([...prev, ...note]);
  final f = File('${dir.path}/seg.f32')
    ..writeAsBytesSync(x.buffer.asUint8List());
  return f.path;
}

String writeIr(Directory dir) {
  final ir = Float32List(2400);
  final rng = math.Random(3);
  ir[0] = 1;
  for (var i = 1; i < ir.length; i++) {
    ir[i] = (rng.nextDouble() * 2 - 1) * 0.3 * math.exp(-i / 600);
  }
  final f = File('${dir.path}/ir.f32')
    ..writeAsBytesSync(ir.buffer.asUint8List());
  return f.path;
}

List<Map<String, Object?>> run(Map<String, dynamic> spec) {
  final rows = <Map<String, Object?>>[];
  ev.runStreamTuner(spec, ev.EvalContext.fromSpec(spec), [0, 1], rows.add);
  return rows;
}

void main() {
  late Directory dir;
  late Map<String, dynamic> base;
  setUpAll(() {
    dir = Directory.systemTemp.createTempSync('e52_harness');
    final seg = writeSegment(dir);
    base = {
      'sampleRate': sr,
      'irs': [writeIr(dir), writeIr(dir)],
      'shiftsCents': [0, 20],
      'conditions': [
        q,
        {...q, 'name': 'Q-noLC', 'lowCutHz': null, 'seedOf': 'Q-quiet-phone'},
      ],
      'cleanRef': true,
      'items': [
        {
          'id': 'synthetic/a2',
          'group': 'synthetic',
          'midi': 45,
          'profile': 'guitar',
          'seg': seg,
          'refRaw': seg,
          'onsetS': 2.0,
          'endS': 5.0,
        },
      ],
    };
  });
  tearDownAll(() => dir.deleteSync(recursive: true));

  test('seed: E45 formula without salt; salt and seedOf as in E52 PLAN §3.1',
      () {
    final c = ev.Condition.fromJson(q);
    final noLc = ev.Condition.fromJson(
        {...q, 'name': 'Q-noLC', 'seedOf': 'Q-quiet-phone'});
    expect(ev.streamTunerSeed(const {}, 'x', 20.0, c),
        ev.stableHash('x/20.0/Q-quiet-phone/stream'));
    final salted = {'seedSalt': 'E52'};
    expect(ev.streamTunerSeed(salted, 'x', 20.0, c),
        ev.stableHash('x/20.0/Q-quiet-phone/stream/E52'));
    expect(ev.streamTunerSeed(salted, 'x', 20.0, noLc),
        ev.streamTunerSeed(salted, 'x', 20.0, c));
    expect(ev.streamTunerSeed(salted, 'x', 20.0, c),
        isNot(ev.streamTunerSeed(const {}, 'x', 20.0, c)));
  });

  test('display rule: a tail reading never replaces a confident one', () {
    final d = ev.ConfidentFirst(sr);
    d.offer(meas(110, attackIndex: 2000), 0, 10000); // confident
    d.offer(meas(109, attackIndex: 0), 16800, 26800); // attack not in view
    d.offer(meas(108, attackIndex: 3000, late: true), 0, 30000); // late rule
    expect(d.conf!.f0Hz, 110);
    expect(d.confidentInstants, 1);
    // 19.98 ms is not seen, 20 ms is.
    expect(ev.ConfidentFirst.isConfident(meas(1, attackIndex: 959), sr), false);
    expect(ev.ConfidentFirst.isConfident(meas(1, attackIndex: 960), sr), true);
  });

  test('without flags rows are unchanged; T equals C when nothing confident',
      () {
    final plain = run(base);
    final t = run({...base, 'displayRule': 'confident-first'});
    expect(t.length, plain.length);
    for (var i = 0; i < plain.length; i++) {
      for (final k in plain[i].keys.where((k) => k != 'ms')) {
        expect(t[i][k], plain[i][k], reason: k);
      }
      expect(t[i]['tMeasured'], t[i]['measured']);
      if (t[i]['tConfident'] == false) {
        expect(t[i]['tF0'], t[i]['f0']);
        expect(t[i]['tLastS'], t[i]['lastS']);
        expect(t[i]['tErrClean'], t[i]['errClean']);
      } else {
        expect(t[i]['tAttackIndexMs'] as double, greaterThanOrEqualTo(20));
        expect(t[i]['tFromLate'], false);
      }
    }
    // Unsalted, no display rule: no E52 fields at all.
    expect(plain.first.containsKey('seed'), false);
    expect(plain.first.containsKey('tF0'), false);
  });

  test('salted ablation shares Q\'s seed and IR draw', () {
    final rows = run({...base, 'seedSalt': 'E52dev'});
    for (final shift in [0.0, 20.0]) {
      final r = rows.where((r) => r['shift'] == shift).toList();
      expect(r.length, 2);
      expect(r[0]['seed'], r[1]['seed']);
      expect(r[0]['irIndex'], r[1]['irIndex']);
    }
  });
}
