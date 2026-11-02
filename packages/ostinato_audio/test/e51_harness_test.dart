// E51 harness (tool/audio_eval.dart, harness only): seedSalt keeps the E45
// keys at 0, lastOnly is exact, the render commands write what the D arm
// measures.
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ostinato_audio/ostinato_audio.dart';
import 'package:test/test.dart';

import '../tool/audio_eval.dart';

const sr = 48000;
double hz(num m) => 440 * math.pow(2, (m - 69) / 12).toDouble();

/// 2 s of quiet, three plucks, then 2.5 s of silence (the last instants fail).
Float64List segment() {
  final x = <double>[...List.filled(2 * sr, 0.0)];
  for (final (m, seed) in [(45, 1), (52, 2), (57, 3)]) {
    x.addAll(SyntheticString.pluck(
        f0Hz: hz(m), sampleRate: sr, seconds: 1.2, seed: seed));
  }
  x.addAll(List.filled((2.5 * sr).round(), 0.0));
  return Float64List.fromList(x);
}

Map<String, dynamic> specFor(String segPath, {int salt = 0}) => {
      'sampleRate': sr,
      'irs': <String>[],
      'shiftsCents': [-20, 0, 20],
      'offsets': [0, 1, -1, 7],
      'conditions': [
        {'name': 'C0-clean', 'clean': true},
        {
          'name': 'Q-dry',
          'noise': 'pink',
          'snrDb': 35,
          'lowCutHz': 100,
          'agc': true
        },
      ],
      'cleanRef': true,
      'seedSalt': salt,
      'items': [
        {
          'id': 'test/a',
          'group': 'nsynth-guitar',
          'midi': 45,
          'profile': 'guitar',
          'seg': segPath,
          'refRaw': segPath,
          'onsetS': 2.0,
          'endS': 8.1,
        }
      ],
    };

void main() {
  late Directory tmp;
  late String segPath;
  setUpAll(() {
    tmp = Directory.systemTemp.createTempSync('e51_');
    segPath = '${tmp.path}/seg.f32';
    writeF32(segPath, segment());
  });
  tearDownAll(() => tmp.deleteSync(recursive: true));

  test('seedSalt 0 / absent keeps the E43–E45 keys; s > 0 changes them', () {
    expect(seedSalt({}), '');
    expect(seedSalt({'seedSalt': 0}), '');
    expect(seedSalt({'seedSalt': 2}), '/s2');
    expect(() => seedSalt({'seedSalt': -1}), throwsArgumentError);
    expect(jitterMs('nsynth-guitar/x', 350),
        stableHash('nsynth-guitar/x/phase') % 350);
    var differ = 0;
    for (var i = 0; i < 200; i++) {
      final k = 'item$i/0.0/Q-quiet-phone/stream';
      if (stableHash('$k/s1') % 32 != stableHash(k) % 32) differ++;
    }
    expect(differ, greaterThan(180)); // denetim 8 needs ≥ 95 % in the real cut
  });

  test('analysisInstants = the E43 loop', () {
    final got = analysisInstants(96000, 1234, 300000, 16800);
    final want = <int>[];
    for (var t = 96000 + 1234; t <= 300000; t += 16800) {
      want.add(t);
    }
    expect(got, want);
    expect(analysisInstants(10, 5, 12, 3), isEmpty);
  });

  test('shownReading: lastOnly gives the forward reading and instant', () {
    final z = PhoneChannel.apply(
        segment(),
        sr,
        const PhoneChannelConfig(
            noise: ChannelNoise.pink, snrDb: 35, lowCutHz: 100, agc: true),
        seed: 7);
    final tuner = PreciseTuner();
    final buf = (1.6 * sr).round(), step = (0.35 * sr).round();
    for (final phase in [0, 5000, 16000]) {
      final inst = analysisInstants(2 * sr, phase, z.length, step);
      TuningMeasurement? at(int t) => tuner
          .measure(z.sublist(math.max(0, t - buf), t), sampleRate: sr)
          .measurement;
      final f = shownReading(inst, at);
      final b = shownReading(inst, at, lastOnly: true);
      expect(f.m, isNotNull);
      expect(b.k, f.k);
      expect(b.m!.f0Hz, f.m!.f0Hz);
      expect(b.n, lessThan(f.n)); // the silent tail is skipped from the end
      expect(f.k, lessThan(inst.length - 1)); // the tail really fails
    }
    expect(
        () => shownReading([1], (_) => null,
            lastOnly: true, accept: (_, __) => true),
        throwsArgumentError);
  });

  test(
      'stream-tuner: lastOnly rows equal forward rows (measured, f0, errClean)',
      () {
    final spec = specFor(segPath);
    final ctx = EvalContext.fromSpec(spec);
    final fwd = <Map<String, Object?>>[], back = <Map<String, Object?>>[];
    runStreamTuner(spec, ctx, [0, 1], fwd.add);
    runStreamTuner(
        {...spec, 'lastOnly': true, 'gShift': true}, ctx, [0, 1], back.add);
    expect(back.length, fwd.length);
    for (var i = 0; i < fwd.length; i++) {
      for (final k in ['measured', 'f0', 'errClean', 'cleanF0', 'lastS']) {
        expect(back[i][k], fwd[i][k], reason: '$k row $i');
      }
      expect(back[i]['instants'], isNull);
      if (fwd[i]['cond'] == 'C0-clean') expect(fwd[i]['errClean'], 0);
    }
    final g = back.where((r) => r.containsKey('gShift')).toList();
    expect(g.length, 2); // C0 × shift ±20
    for (final r in g) {
      expect((r['gShift'] as double).abs(), lessThan(3));
    }
    expect(
        () => runStreamTuner(
            {...spec, 'lastOnly': true, 'noteGate': {}}, ctx, [0, 1], (_) {}),
        throwsArgumentError);
  });

  test('stream-render writes what D measures (tuner and verifier inputs)', () {
    final spec = specFor(segPath, salt: 1);
    final ctx = EvalContext.fromSpec(spec);
    final dir = '${tmp.path}/render';
    Directory(dir).createSync();
    final rows = <Map<String, Object?>>[];
    runStreamRender(spec, ctx, [0, 1], [0, 1 << 30], dir, rows.add);
    final d = <Map<String, Object?>>[];
    runStreamTuner({...spec, 'lastOnly': true}, ctx, [0, 1], d.add);
    expect(rows.length, 6);
    for (final (i, r) in rows.indexed) {
      expect(r['renderSeed'], d[i]['renderSeed']);
      final z = readF32(r['file'] as String);
      final y = readF32(r['cleanFile'] as String);
      expect(z.length, r['n']);
      final inst = (r['instants'] as List).cast<int>();
      final off = r['offset'] as int;
      // D's reading at its shown instant, from the written channel output.
      final k = d[i]['k'] as int?;
      if (k != null) {
        final t = inst[k] - off;
        final m = PreciseTuner()
            .measure(z.sublist(math.max(0, t - (1.6 * sr).round()), t),
                sampleRate: sr)
            .measurement;
        // f32 storage: equal within float rounding, not bitwise.
        expect(
            (1200 * math.log(m!.f0Hz / (d[i]['f0'] as double)) / math.ln2)
                .abs(),
            lessThan(0.05));
      }
      if (r['cond'] == 'C0-clean') {
        expect(z, y.sublist(0, z.length));
      }
    }
    final vspec = {...spec}..remove('shiftsCents');
    final vrows = <Map<String, Object?>>[];
    runStreamRender(vspec, ctx, [0, 1], [0, 1], dir, vrows.add);
    expect(vrows.length, 2);
    final dv = <Map<String, Object?>>[];
    runStreamVerify(vspec, ctx, [0, 1], dv.add);
    for (final r in vrows) {
      final w = readF32(r['file'] as String);
      expect(w.length, 36000);
      expect(r['attack'], isNotNull);
      final v = GuitarNoteVerifier().verify(w,
          sampleRate: sr, expectedMidi: 45, onsetIndex: r['attack'] as int);
      final mine =
          dv.firstWhere((x) => x['cond'] == r['cond'] && x['offset'] == 0);
      expect(v.verdict.name, mine['verdict']);
    }
    // Chunk range outside the shard's items: nothing written.
    final none = <Map<String, Object?>>[];
    runStreamRender(spec, ctx, [0, 1], [1, 2], dir, none.add);
    expect(none, isEmpty);
  });

  test(
      'synth-render: E36 draws, buffer [onset − 0.1 s, onset + 1.5 s], D reading',
      () {
    final spec = {
      'sampleRate': sr,
      'seedBase': 51000,
      'irs': <String>[],
      'conditions': [
        {'name': 'C0-clean', 'clean': true}
      ],
      'instruments': [
        {
          'family': 'guitar-mf',
          'profile': 'guitar',
          'strings': [45],
          'bRange': [4e-05, 0.0003],
          'pluckRange': [0.06, 0.3],
          'decayRange': [0.8, 3.0],
          'glideRange': [0, 2],
          'detuneRange': [-40, 40],
          'repeats': 2,
          'seconds': 2.4
        }
      ],
    };
    final ctx = EvalContext.fromSpec(spec);
    final dir = '${tmp.path}/synth';
    Directory(dir).createSync();
    final rows = <Map<String, Object?>>[];
    runSynthRender(spec, ctx, [0, 1], dir, rows.add);
    final st = <Map<String, Object?>>[];
    runSynthTuner(spec, ctx, [0, 1], st.add);
    expect(rows.length, 2);
    for (final (i, r) in rows.indexed) {
      expect(r['truthF0'], st[i]['truthF0']); // same note as synth-tuner
      expect(r['seed'], 51000 + stableHash('guitar-mf/45/$i'));
      expect(readF32(r['file'] as String).length, (1.6 * sr).round());
      expect((r['dErr'] as double).abs(), lessThan(3));
    }
  });
}
