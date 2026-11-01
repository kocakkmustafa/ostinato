// E54 harness helpers (tool/voice_eval.dart). Synthetic signals only.
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ostinato_audio/ostinato_audio.dart';
import 'package:test/test.dart';

import '../tool/audio_eval.dart' show Condition, EvalContext;
import '../tool/voice_eval.dart';

const sr = 48000;
double centsOf(double a, double b) => 1200 * math.log(a / b) / math.ln2;

void main() {
  test('sha256Hex matches FIPS 180-4 vectors', () {
    String h(String s) => sha256Hex(Uint8List.fromList(utf8.encode(s)));
    expect(h(''),
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855');
    expect(h('abc'),
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
    expect(h('abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq'),
        '248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1');
    expect(sha256Hex(Uint8List.fromList(List.filled(1000000, 0x61))),
        'cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0');
  });

  test('harmonicCurve with a constant curve is SyntheticTone.harmonic', () {
    final a = SyntheticTone.harmonic(
        f0Hz: 233.08, sampleRate: sr, seconds: 0.5, seed: 901);
    final b = harmonicCurve(
        f0At: (_) => 233.08, sampleRate: sr, seconds: 0.5, seed: 901);
    expect(b, a);
  });

  test('vib style reproduces SyntheticTone vibrato bit for bit', () {
    final note = {'style': 'vib', 'midi': 57, 'shift': 15, 'seed': 902};
    final a = synthNote(note, sr, seconds: 0.4, gain: 1);
    final ref = SyntheticTone.harmonic(
        f0Hz: midiHz(57) * math.pow(2, 15 / 1200),
        sampleRate: sr,
        seconds: 0.4,
        vibratoHz: 5.5,
        vibratoCents: 50,
        seed: 902);
    final b = harmonicCurve(
        f0At: (t) => synthNoteHz('vib', 57, 15, t),
        sampleRate: sr,
        seconds: 0.4,
        seed: 902);
    // Curve generator and SyntheticTone agree, and synthNote only fades.
    expect(b, ref);
    for (var i = 0; i < a.length - (0.02 * sr).round(); i++) {
      expect(a[i], ref[i]);
    }
  });

  test('scoop starts 80 cents flat and reaches the target at 150 ms', () {
    expect(centsOf(synthNoteHz('scoopvib', 69, 0, 0), 440), closeTo(-80, 1e-9));
    final at = synthNoteHz('scoopvib', 69, 0, 0.15);
    expect(centsOf(at, 440),
        closeTo(30 * math.sin(2 * math.pi * 5.5 * 0.15), 1e-9));
  });

  test('derived Y1 equals the engine with expectedHzPrior, bit for bit', () {
    final grid = FrameGrid(sr, 92.9, 23.2);
    final plain = YinPitchSource(minHz: 55, maxHz: 1200, threshold: 0.15);
    var compared = 0;
    for (final (midi, shift) in [
      (40, 0.0),
      (52, 15.0),
      (64, -40.0),
      (76, 40.0),
      (84, 0.0)
    ]) {
      final x = synthNote(
          {'style': 'scoopvib', 'midi': midi, 'shift': shift, 'seed': 900}, sr,
          seconds: 0.35);
      final f = Float64List.fromList(x);
      for (final tc in [-1200.0, -700.0, -100.0, 0.0, 200.0, 1900.0]) {
        final prior = midiHz(midi) * math.pow(2, tc / 1200);
        final real = YinPitchSource(
            minHz: 55, maxHz: 1200, threshold: 0.15, expectedHzPrior: prior);
        for (final k in grid.frames(f.length, null)) {
          final w = f.sublist(k * grid.hop, k * grid.hop + grid.win);
          final r0 = plain.analyze(w, sampleRate: sr, tStartUs: 0);
          final r1 = real.analyze(w, sampleRate: sr, tStartUs: 0);
          if (r0.f0Hz == null) continue;
          final d = applyPriorLikeEngine(r0.f0Hz!, prior,
              minHz: 55, maxHz: 1200, priorToleranceCents: 700);
          expect(d, r1.f0Hz, reason: 'midi $midi prior $tc frame $k');
          expect(r1.periodicity, r0.periodicity);
          compared++;
        }
      }
    }
    expect(compared, greaterThan(100));
  });

  test('noise-only clip sits at PhoneChannel.noiseFloorDb', () {
    final ref = Float64List.fromList(synthNote(
        {'style': 'flat', 'midi': 60, 'shift': 0, 'seed': 999}, sr,
        seconds: 1.0));
    final ir = Float64List(4800)..[10] = 1.0;
    for (var i = 11; i < ir.length; i++) {
      ir[i] = 0.3 * math.exp(-i / 900) * math.sin(i * 1.7);
    }
    final ctx = EvalContext(sr, const [], [ir]);
    final c = Condition.fromJson({
      'name': 'Q-quiet-phone',
      'reverb': true,
      'drrDb': 6,
      'noise': 'pink',
      'snrDb': 35,
      'lowCutHz': 100,
      'lowCutOrder': 2,
      'agc': true,
    });
    const seed = 12345;
    final clip = noiseOnlyRender(ctx, ref, 2 * sr, c, seed);
    final levels = <double>[];
    for (var s = 0; s + 2048 <= clip.length; s += 2048) {
      var e = 0.0;
      for (var i = s; i < s + 2048; i++) {
        e += clip[i] * clip[i];
      }
      levels
          .add(20 * math.log(math.max(math.sqrt(e / 2048), 1e-9)) / math.ln10);
    }
    levels.sort();
    final floor = PhoneChannel.noiseFloorDb(
        ref,
        sr,
        PhoneChannelConfig(
            impulseResponse: ir,
            directToReverbDb: 6,
            noise: ChannelNoise.pink,
            snrDb: 35,
            lowCutHz: 100,
            agc: true),
        seed: seed);
    expect(levels[levels.length ~/ 2], floor);
    final clean = noiseOnlyRender(ctx, ref, sr,
        Condition.fromJson({'name': 'C0-clean', 'clean': true}), seed);
    expect(clean.every((v) => v == 0), isTrue);
  });

  test('frame grid: centres and interior membership', () {
    final g = FrameGrid(sr, 92.9, 23.2);
    expect(g.win, 4459);
    expect(g.hop, 1114);
    expect(g.centre(0), closeTo(4459 / 2 / sr, 1e-12));
    final ks = g.frames(sr * 2, [
      [0.5, 0.6]
    ]);
    expect(ks.every((k) => g.centre(k) >= 0.5 && g.centre(k) <= 0.6), isTrue);
    expect(ks.length, 4); // 100 ms / 23.2 ms hop
  });

  test('resynthesis follows the GT curve and is silent where GT is', () {
    final t = [for (var k = 0; k < 200; k++) k * 256 / 44100];
    final hz = [for (var k = 0; k < 200; k++) k >= 20 && k < 180 ? 196.0 : 0.0];
    final y = resynth(t, hz, (t.last * sr).round(), sr);
    final yin = YinPitchSource();
    final mid = (0.5 * sr).round();
    final r =
        yin.analyze(y.sublist(mid, mid + 4459), sampleRate: sr, tStartUs: 0);
    expect(centsOf(r.f0Hz!, 196).abs(), lessThan(0.5));
    expect(y.sublist(0, (t[19] * sr).floor()).every((v) => v == 0), isTrue);
  });
}
