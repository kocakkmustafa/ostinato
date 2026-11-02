// E56 harness flag (tool/audio_eval.dart): the tail rule (arm TL) on top of
// the confident-first display rule (arm T). Synthetic audio only.
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

Map<String, Object?> row(ev.ConfidentFirst d) => d.row(
      last: null,
      lastT: null,
      lastA: null,
      cleanF0: null,
      cleanAt: null,
      onset: 0,
      refF0: null,
      shift: 0,
    );

void main() {
  late Directory dir;
  late Map<String, dynamic> base;
  setUpAll(() {
    dir = Directory.systemTemp.createTempSync('e56_harness');
    final seg = writeSegment(dir);
    base = {
      'sampleRate': sr,
      'irs': [writeIr(dir), writeIr(dir)],
      'shiftsCents': [0, 20],
      'conditions': [
        q,
        {...q, 'name': 'N20-household', 'drrDb': 0, 'snrDb': 20},
      ],
      'cleanRef': true,
      'seedSalt': 'E56dev',
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

  test('tail rule: confident first, else the last early reading', () {
    final d = ev.ConfidentFirst(sr, tailRule: true);
    d.offer(meas(109, attackIndex: 0), 16800, 26800); // early, not confident
    d.offer(meas(108, attackIndex: 3000, late: true), 0, 30000); // late rule
    expect(d.conf, isNull);
    expect(d.early!.f0Hz, 109);
    expect(row(d)['lMeasured'], true);
    expect(row(d)['lF0'], 109);
    expect(row(d)['lFromLate'], false);
    d.offer(meas(110, attackIndex: 2000), 0, 40000); // confident
    d.offer(meas(107, attackIndex: 0), 16800, 50000); // later early reading
    expect(row(d)['lF0'], 110);
    expect(row(d)['lConfident'], true);
  });

  test('tail rule: only late-rule readings means play again', () {
    final d = ev.ConfidentFirst(sr, tailRule: true);
    d.offer(meas(108, attackIndex: 3000, late: true), 0, 30000);
    final r = row(d);
    expect(r['lMeasured'], false);
    expect(r['lF0'], isNull);
    // T still falls back to C's reading; TL adds no T field change.
    expect(r['tMeasured'], false); // `last` is null in this direct call
  });

  test('without the tail rule no l* fields; T rows unchanged', () {
    expect(
        row(ev.ConfidentFirst(sr)).keys.any((k) => k.startsWith('l')), false);
    final t = run({...base, 'displayRule': 'confident-first'});
    final tl = run({...base, 'displayRule': 'confident-first+tail-rule'});
    expect(tl.length, t.length);
    for (var i = 0; i < t.length; i++) {
      for (final k in t[i].keys.where((k) => k != 'ms')) {
        expect(tl[i][k], t[i][k], reason: k);
      }
      // Field order: T's fields first, TL's appended.
      expect(tl[i].keys.take(t[i].length).toList(), t[i].keys.toList());
    }
  });

  test('TL is a subset of C and agrees with T when T is confident', () {
    final rows = run({...base, 'displayRule': 'confident-first+tail-rule'});
    expect(rows, isNotEmpty);
    for (final r in rows) {
      if (r['lMeasured'] == true) {
        expect(r['measured'], true);
        expect(r['lFromLate'], false);
      }
      if (r['tConfident'] == true) {
        expect(r['lF0'], r['tF0']);
        expect(r['lLastS'], r['tLastS']);
        expect(r['lErrClean'], r['tErrClean']);
      }
      if (r['tConfident'] == false && r['fromLate'] == false) {
        // C's own reading is early: TL shows it.
        expect(r['lF0'], r['f0']);
        expect(r['lErrClean'], r['errClean']);
      }
    }
  });

  test('unknown display rules are rejected', () {
    expect(() => ev.ConfidentFirst.fromSpec(const {'displayRule': 'x'}, sr),
        throwsArgumentError);
    expect(
        ev.ConfidentFirst.fromSpec(
                const {'displayRule': 'confident-first+tail-rule'}, sr)!
            .tailRule,
        true);
  });
}
