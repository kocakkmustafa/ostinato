import 'dart:math' as math;
import 'dart:typed_data';

import '../dsp/fft.dart';
import '../gate/audio_confidence_gate.dart' show rmsDb;

/// E53 arm K1: string-by-string check of a strummed chord against the
/// voicing the lesson expects (PLAN E53 §2, §4).
///
/// EXPERIMENT CODE. Deliberately not exported from `ostinato_audio.dart` and
/// not wired to any controller (PLAN §10.7): only `tool/chord_eval.dart` and
/// its tests import it. Whether it may ever reach the app is what E53 decides.
///
/// Method, frozen by the plan:
/// 1. the caller cuts the strum window (strum + 80 ms … min(+480 ms,
///    next strum − 20 ms), ≥ 200 ms);
/// 2. Hann, zero padding to [fftSize] (2^16 → 0.73 Hz at 48 kHz), magnitude,
///    [minHz]–[maxHz];
/// 3. dictionary of [midiLow]…[midiHigh] pitch atoms: partials 1–[partials],
///    f_n = n·f0·√(1 + B·n²), amplitude 1/n, each a Gaussian in log
///    frequency (σ = [sigmaCents]); plus one flat floor atom;
/// 4. non-negative least squares (Lawson–Hanson) → a_p ≥ 0, explained energy
///    R² = 1 − ‖S − D·a‖² / ‖S‖²;
/// 5. string s (pitch p_s) is heard ⇔ a_{p_s} ≥ θ_rel · max_{s'} a_{p_{s'}};
/// 6. unexpected pitch: p not expected, pitch class outside the chord's, and
///    a_p ≥ θ_x · max_s a_{p_s};
/// 7. extra string (information only): p in the chord's pitch classes, not
///    expected, playable at fret 0–3 on a string the voicing leaves unplayed,
///    a_p ≥ θ_x · max_s a_{p_s};
/// 8. gates: window RMS ≥ room floor + [levelAboveFloorDb] and R² ≥ τ_fit;
/// 9. several allowed voicings: any `correct` wins, otherwise the verdict of
///    the voicing with the fewest strings not heard (first on ties).
enum ChordVerdict { correct, missingString, differentChord, couldNotHear }

/// Standard tuning, string 6 (low E) first.
const standardTuningMidi = <int>[40, 45, 50, 55, 59, 64];

/// One expected fingering: MIDI per string, index 0 = string 6 (low E),
/// index 5 = string 1; null = the string is not played.
final class StringVoicing {
  const StringVoicing(this.id, this.midi);
  final String id;
  final List<int?> midi;

  /// String number (6…1) of index [i].
  static int stringNumber(int i) => 6 - i;

  Set<int> get pitchClasses => {
        for (final m in midi)
          if (m != null) m % 12
      };
  Iterable<int> get playedIndices sync* {
    for (var i = 0; i < 6; i++) {
      if (midi[i] != null) yield i;
    }
  }
}

final class StringCheck {
  const StringCheck(
      this.string, this.midi, this.activation, this.heard, this.possiblyMuted);
  final int string; // 6…1
  final int midi;
  final double activation;
  final bool heard;

  /// Not heard in the window, but energy at its pitch in the first 80 ms
  /// (report only; PLAN §2).
  final bool possiblyMuted;
}

final class VoicingJudgement {
  const VoicingJudgement(
      this.verdict, this.strings, this.unexpected, this.extra);
  final ChordVerdict verdict;
  final List<StringCheck> strings;

  /// (midi, activation) of unexpected pitches.
  final List<(int, double)> unexpected;

  /// (string 6…1, midi, activation): chord tone on a string the voicing does
  /// not play (information only).
  final List<(int, int, double)> extra;

  int get notHeard => strings.where((s) => !s.heard).length;
}

final class ChordStringResult {
  const ChordStringResult({
    required this.verdict,
    required this.gate,
    required this.levelDb,
    required this.r2,
    required this.fit,
    required this.chosen,
    required this.judgements,
  });
  final ChordVerdict verdict;

  /// 'level' or 'fit' when a gate refused, else null.
  final String? gate;
  final double levelDb;
  final double r2;
  final SpectrumFit? fit;

  /// Index into the allowed voicings of the judgement that decided, or null
  /// when a gate refused.
  final int? chosen;
  final List<VoicingJudgement> judgements;
  VoicingJudgement? get decisive => chosen == null ? null : judgements[chosen!];
}

final class SpectrumFit {
  const SpectrumFit(this.activations, this.floor, this.r2);

  /// a_p for MIDI midiLow + i.
  final Float64List activations;
  final double floor;
  final double r2;
}

final class ChordStringChecker {
  ChordStringChecker({
    this.sampleRate = 48000,
    this.fftSize = 1 << 16,
    this.minHz = 60,
    this.maxHz = 5000,
    this.midiLow = 40,
    this.midiHigh = 88,
    this.partials = 8,
    this.inharmonicityB = 1e-4,
    this.sigmaCents = 15,
    this.thetaRel = 0.12,
    this.thetaX = 0.30,
    this.tauFit = 0.40,
    this.levelAboveFloorDb = 6,
  }) {
    _build();
  }

  final int sampleRate, fftSize, midiLow, midiHigh, partials;
  final double minHz, maxHz, inharmonicityB, sigmaCents;
  final double thetaRel, thetaX, tauFit, levelAboveFloorDb;

  late final int _k0, _k1; // band bins [k0, k1]
  late final List<Int32List> _atomBins; // per pitch atom
  late final List<Float64List> _atomVals;
  late final Float64List _gram; // (n+1)², last = floor atom
  int get nPitch => midiHigh - midiLow + 1;
  int get nAtoms => nPitch + 1;

  static double midiHz(num m) => 440 * math.pow(2, (m - 69) / 12).toDouble();

  void _build() {
    final df = sampleRate / fftSize;
    _k0 = (minHz / df).ceil();
    _k1 = (maxHz / df).floor();
    final bins = <Int32List>[], vals = <Float64List>[];
    final reach = 4 * sigmaCents; // cents
    for (var p = midiLow; p <= midiHigh; p++) {
      final f0 = midiHz(p);
      final acc = <int, double>{};
      for (var n = 1; n <= partials; n++) {
        final fn = n * f0 * math.sqrt(1 + inharmonicityB * n * n);
        final lo = math.max(_k0, (fn * math.pow(2, -reach / 1200) / df).ceil());
        final hi = math.min(_k1, (fn * math.pow(2, reach / 1200) / df).floor());
        for (var k = lo; k <= hi; k++) {
          final c = 1200 * math.log(k * df / fn) / math.ln2;
          final v = math.exp(-0.5 * (c / sigmaCents) * (c / sigmaCents)) / n;
          acc[k] = (acc[k] ?? 0) + v;
        }
      }
      final ks = acc.keys.toList()..sort();
      bins.add(Int32List.fromList(ks));
      vals.add(Float64List.fromList([for (final k in ks) acc[k]!]));
    }
    _atomBins = bins;
    _atomVals = vals;
    final n = nAtoms;
    final g = Float64List(n * n);
    final dense = Float64List(_k1 + 1);
    for (var i = 0; i < nPitch; i++) {
      dense.fillRange(0, dense.length, 0);
      for (var j = 0; j < _atomBins[i].length; j++) {
        dense[_atomBins[i][j]] = _atomVals[i][j];
      }
      for (var k = i; k < nPitch; k++) {
        var s = 0.0;
        for (var j = 0; j < _atomBins[k].length; j++) {
          s += dense[_atomBins[k][j]] * _atomVals[k][j];
        }
        g[i * n + k] = s;
        g[k * n + i] = s;
      }
      var s = 0.0;
      for (final v in _atomVals[i]) {
        s += v;
      }
      g[i * n + nPitch] = s;
      g[nPitch * n + i] = s;
    }
    g[nPitch * n + nPitch] = (_k1 - _k0 + 1).toDouble();
    _gram = g;
  }

  /// Band magnitude spectrum of [window] (Hann, zero-padded), bins k0…k1.
  Float64List spectrum(List<double> window) {
    final m = window.length;
    if (m > fftSize) throw ArgumentError('window longer than fftSize');
    final re = Float64List(fftSize), im = Float64List(fftSize);
    for (var i = 0; i < m; i++) {
      re[i] = window[i] * (0.5 - 0.5 * math.cos(2 * math.pi * i / (m - 1)));
    }
    fftInPlace(re, im);
    final s = Float64List(_k1 - _k0 + 1);
    for (var k = _k0; k <= _k1; k++) {
      s[k - _k0] = math.sqrt(re[k] * re[k] + im[k] * im[k]);
    }
    return s;
  }

  /// D·a for given pitch activations and floor (band bins), for tests and
  /// the identity check (PLAN §9.1).
  Float64List synthesize(List<double> activations, double floor) {
    final s = Float64List(_k1 - _k0 + 1)..fillRange(0, _k1 - _k0 + 1, floor);
    for (var i = 0; i < nPitch; i++) {
      final a = activations[i];
      if (a == 0) continue;
      for (var j = 0; j < _atomBins[i].length; j++) {
        s[_atomBins[i][j] - _k0] += a * _atomVals[i][j];
      }
    }
    return s;
  }

  /// NNLS fit of a band spectrum (length k1 − k0 + 1).
  SpectrumFit fitSpectrum(Float64List s) {
    final n = nAtoms;
    final b = Float64List(n);
    var ss = 0.0;
    for (final v in s) {
      ss += v * v;
      b[nPitch] += v;
    }
    for (var i = 0; i < nPitch; i++) {
      var acc = 0.0;
      for (var j = 0; j < _atomBins[i].length; j++) {
        acc += s[_atomBins[i][j] - _k0] * _atomVals[i][j];
      }
      b[i] = acc;
    }
    final x = nnlsGram(_gram, b, n);
    // ‖S − Dx‖² = sᵀs − 2xᵀb + xᵀGx
    var xb = 0.0, xgx = 0.0;
    for (var i = 0; i < n; i++) {
      if (x[i] == 0) continue;
      xb += x[i] * b[i];
      var gi = 0.0;
      for (var k = 0; k < n; k++) {
        gi += _gram[i * n + k] * x[k];
      }
      xgx += x[i] * gi;
    }
    final resid = math.max(0.0, ss - 2 * xb + xgx);
    final r2 = ss > 0 ? 1 - resid / ss : 0.0;
    return SpectrumFit(Float64List.sublistView(x, 0, nPitch), x[nPitch], r2);
  }

  /// Energy at each pitch's first four partials in [early] (Hann, Goertzel),
  /// for the report-only "possibly muted" flag.
  Float64List earlyEnergies(List<double> early) {
    final out = Float64List(nPitch);
    final m = early.length;
    if (m < 2) return out;
    final w = Float64List(m);
    for (var i = 0; i < m; i++) {
      w[i] = early[i] * (0.5 - 0.5 * math.cos(2 * math.pi * i / (m - 1)));
    }
    for (var p = 0; p < nPitch; p++) {
      var e = 0.0;
      for (var h = 1; h <= 4; h++) {
        final f = h * midiHz(midiLow + p);
        if (f >= sampleRate / 2) break;
        final omega = 2 * math.pi * f / sampleRate;
        final coeff = 2 * math.cos(omega);
        var s1 = 0.0, s2 = 0.0;
        for (var i = 0; i < m; i++) {
          final s0 = w[i] + coeff * s1 - s2;
          s2 = s1;
          s1 = s0;
        }
        final re = s1 - s2 * math.cos(omega), im = s2 * math.sin(omega);
        e += math.sqrt(re * re + im * im) / h;
      }
      out[p] = e;
    }
    return out;
  }

  /// Decision for one expected voicing from a fit (steps 5–7).
  VoicingJudgement judge(SpectrumFit fit, StringVoicing v,
      {Float64List? early}) {
    double act(int midi) => midi >= midiLow && midi <= midiHigh
        ? fit.activations[midi - midiLow]
        : 0.0;
    final played = v.playedIndices.toList();
    var ref = 0.0;
    for (final i in played) {
      ref = math.max(ref, act(v.midi[i]!));
    }
    final heard = <int, bool>{
      for (final i in played) i: ref > 0 && act(v.midi[i]!) >= thetaRel * ref
    };
    // Report-only muted flag: early energy ≥ half the median early energy of
    // the heard strings.
    double? medHeard;
    if (early != null) {
      final hs = [
        for (final i in played)
          if (heard[i]! && v.midi[i]! >= midiLow && v.midi[i]! <= midiHigh)
            early[v.midi[i]! - midiLow]
      ]..sort();
      if (hs.isNotEmpty) medHeard = hs[hs.length ~/ 2];
    }
    final strings = [
      for (final i in played)
        StringCheck(
            StringVoicing.stringNumber(i),
            v.midi[i]!,
            act(v.midi[i]!),
            heard[i]!,
            !heard[i]! &&
                medHeard != null &&
                medHeard > 0 &&
                v.midi[i]! >= midiLow &&
                v.midi[i]! <= midiHigh &&
                early![v.midi[i]! - midiLow] >= 0.5 * medHeard)
    ];
    final expected = {for (final i in played) v.midi[i]!};
    final pcs = v.pitchClasses;
    final unexpected = <(int, double)>[];
    final extra = <(int, int, double)>[];
    for (var p = midiLow; p <= midiHigh; p++) {
      final a = act(p);
      if (a <= 0 || a < thetaX * ref || expected.contains(p)) continue;
      if (!pcs.contains(p % 12)) {
        unexpected.add((p, a));
      } else {
        for (var i = 0; i < 6; i++) {
          final fret = p - standardTuningMidi[i];
          if (v.midi[i] == null && fret >= 0 && fret <= 3) {
            extra.add((StringVoicing.stringNumber(i), p, a));
          }
        }
      }
    }
    final nHeard = heard.values.where((h) => h).length;
    final ChordVerdict verdict;
    if (unexpected.isNotEmpty) {
      verdict = ChordVerdict.differentChord;
    } else if (nHeard == 0) {
      verdict = ChordVerdict.couldNotHear;
    } else if (nHeard < played.length) {
      verdict = ChordVerdict.missingString;
    } else {
      verdict = ChordVerdict.correct;
    }
    return VoicingJudgement(verdict, strings, unexpected, extra);
  }

  /// Full K1 decision on a strum window. [early] = the first 80 ms after the
  /// strum (report-only muted flag); [roomFloorDb] = calibrated room floor.
  ChordStringResult check(
    List<double> window, {
    required double roomFloorDb,
    required List<StringVoicing> allowed,
    List<double>? early,
  }) {
    final level = rmsDb(window);
    if (level < roomFloorDb + levelAboveFloorDb) {
      return ChordStringResult(
          verdict: ChordVerdict.couldNotHear,
          gate: 'level',
          levelDb: level,
          r2: double.nan,
          fit: null,
          chosen: null,
          judgements: const []);
    }
    final fit = fitSpectrum(spectrum(window));
    if (!(fit.r2 >= tauFit)) {
      return ChordStringResult(
          verdict: ChordVerdict.couldNotHear,
          gate: 'fit',
          levelDb: level,
          r2: fit.r2,
          fit: fit,
          chosen: null,
          judgements: const []);
    }
    final e = early == null ? null : earlyEnergies(early);
    final js = [for (final v in allowed) judge(fit, v, early: e)];
    var chosen = js.indexWhere((j) => j.verdict == ChordVerdict.correct);
    if (chosen < 0) {
      chosen = 0;
      for (var i = 1; i < js.length; i++) {
        if (js[i].notHeard < js[chosen].notHeard) chosen = i;
      }
    }
    return ChordStringResult(
        verdict: js[chosen].verdict,
        gate: null,
        levelDb: level,
        r2: fit.r2,
        fit: fit,
        chosen: chosen,
        judgements: js);
  }
}

/// Lawson–Hanson NNLS on the normal equations: min ‖S − D·x‖, x ≥ 0, given
/// G = DᵀD (n×n, row-major) and b = DᵀS.
Float64List nnlsGram(Float64List g, Float64List b, int n, {int maxOuter = 0}) {
  final x = Float64List(n);
  final passive = List<bool>.filled(n, false);
  var bmax = 0.0;
  for (final v in b) {
    bmax = math.max(bmax, v.abs());
  }
  final tol = 1e-12 * math.max(1.0, bmax);
  final w = Float64List(n);
  void grad() {
    for (var i = 0; i < n; i++) {
      var s = b[i];
      for (var k = 0; k < n; k++) {
        if (x[k] != 0) s -= g[i * n + k] * x[k];
      }
      w[i] = s;
    }
  }

  final limit = maxOuter > 0 ? maxOuter : 3 * n;
  grad();
  for (var outer = 0; outer < limit; outer++) {
    var j = -1;
    var best = tol;
    for (var i = 0; i < n; i++) {
      if (!passive[i] && w[i] > best) {
        best = w[i];
        j = i;
      }
    }
    if (j < 0) break;
    passive[j] = true;
    for (var inner = 0; inner < 3 * n; inner++) {
      final p = [
        for (var i = 0; i < n; i++)
          if (passive[i]) i
      ];
      final z = _solveSpd(g, b, n, p);
      var allPos = true;
      for (var q = 0; q < p.length; q++) {
        if (z[q] <= 0) allPos = false;
      }
      if (allPos) {
        x.fillRange(0, n, 0);
        for (var q = 0; q < p.length; q++) {
          x[p[q]] = z[q];
        }
        break;
      }
      var alpha = double.infinity;
      for (var q = 0; q < p.length; q++) {
        if (z[q] <= 0) {
          final xi = x[p[q]];
          final a = xi / (xi - z[q]);
          if (a < alpha) alpha = a;
        }
      }
      for (var q = 0; q < p.length; q++) {
        final i = p[q];
        x[i] = x[i] + alpha * (z[q] - x[i]);
        if (x[i] <= tol * 1e-3) {
          x[i] = 0;
          passive[i] = false;
        }
      }
      for (var i = 0; i < n; i++) {
        if (!passive[i]) x[i] = 0;
      }
    }
    grad();
  }
  return x;
}

/// Solves G[P,P]·z = b[P] by Cholesky.
Float64List _solveSpd(Float64List g, Float64List b, int n, List<int> p) {
  final m = p.length;
  final l = Float64List(m * m);
  for (var i = 0; i < m; i++) {
    for (var j = 0; j <= i; j++) {
      var s = g[p[i] * n + p[j]];
      for (var k = 0; k < j; k++) {
        s -= l[i * m + k] * l[j * m + k];
      }
      if (i == j) {
        l[i * m + i] = math.sqrt(math.max(s, 1e-300));
      } else {
        l[i * m + j] = s / l[j * m + j];
      }
    }
  }
  final y = Float64List(m);
  for (var i = 0; i < m; i++) {
    var s = b[p[i]];
    for (var k = 0; k < i; k++) {
      s -= l[i * m + k] * y[k];
    }
    y[i] = s / l[i * m + i];
  }
  final z = Float64List(m);
  for (var i = m - 1; i >= 0; i--) {
    var s = y[i];
    for (var k = i + 1; k < m; k++) {
      s -= l[k * m + i] * z[k];
    }
    z[i] = s / l[i * m + i];
  }
  return z;
}
