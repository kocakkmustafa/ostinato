import 'dart:math' as math;
import 'dart:typed_data';

import '../dsp/fft.dart';
import '../onset/attack_locator.dart';
import 'yin.dart';

/// Per-instrument settings of [PreciseTuner]. Values are engineering choices
/// written before evaluation (E36 PLAN), not fitted to any dataset.
final class PreciseTunerProfile {
  const PreciseTunerProfile({
    required this.name,
    required this.minHz,
    required this.maxHz,
    required this.readingWindowMs,
    required this.defaultB,
    required this.maxB,
    this.skipAfterAttackMs = 200,
    this.maxSegmentMs = 1400,
    this.readingHopMs = 200,
    this.minReadings = 3,
    this.maxPartials = 8,
    this.maxAnalysisHz = 5000,
    this.partialSearchCents = 60,
    this.minPartialSnrDb = 15,
    this.minPartials = 2,
    this.minPartialsForB = 4,
    this.maxSpreadCents = 3,
    this.maxPartialResidualCents = 4,
    this.minLevelAboveFloorDb = 6,
    this.zeroPadFactor = 4,
    this.yinThreshold = 0.15,
    this.minPeriodicity = 0.5,
    this.octaveOddPowerRatio = 0.1,
    this.adaptiveWindowPeriods,
    this.minReadingWindowMs = 150,
    this.maxLateSpreadCents,
  });

  final String name;

  /// Lowest/highest fundamental reported. Bass goes down to 28 Hz (B0 is
  /// 30.9 Hz), well below the 70 Hz floor of the note observer.
  final double minHz, maxHz;

  /// Attack skip after the envelope peak (150–300 ms band, §3.4): the first
  /// moments of a pluck are sharp from tension modulation.
  final int skipAfterAttackMs;
  final int maxSegmentMs, readingWindowMs, readingHopMs, minReadings;

  /// Partials 1..[maxPartials] are tracked.
  final int maxPartials;
  final double maxAnalysisHz, partialSearchCents, minPartialSnrDb;
  final int minPartials, minPartialsForB;

  /// Inharmonicity prior and bound. B is fitted only when at least
  /// [minPartialsForB] partials spanning a 2:1 range were found.
  final double defaultB, maxB;

  /// Readings disagreeing by more than this are reported as "could not
  /// measure" (string still settling, or noise), never as a number.
  final double maxSpreadCents;
  final double maxPartialResidualCents;
  final double minLevelAboveFloorDb;
  final int zeroPadFactor;
  final double yinThreshold, minPeriodicity;

  /// Power share the odd partials of f/2 need before an octave-high coarse
  /// estimate is moved down an octave.
  final double octaveOddPowerRatio;

  /// E41 arm W1 (null = off): reading window of this many periods of the
  /// coarse f0, between [minReadingWindowMs] and [readingWindowMs]; the hop
  /// shrinks in proportion. High notes decay fast and get more readings.
  final double? adaptiveWindowPeriods;
  final int minReadingWindowMs;

  /// E41 arm U (null = off): when readings spread more than [maxSpreadCents]
  /// but no more than this, report the trimmed mean of the *later* half of
  /// the readings (the string has settled) instead of refusing. Wider spread
  /// is still "could not measure".
  final double? maxLateSpreadCents;

  PreciseTunerProfile copyWith({
    double? maxAnalysisHz,
    double? adaptiveWindowPeriods,
    double? maxLateSpreadCents,
  }) =>
      PreciseTunerProfile(
        name: name,
        minHz: minHz,
        maxHz: maxHz,
        readingWindowMs: readingWindowMs,
        defaultB: defaultB,
        maxB: maxB,
        skipAfterAttackMs: skipAfterAttackMs,
        maxSegmentMs: maxSegmentMs,
        readingHopMs: readingHopMs,
        minReadings: minReadings,
        maxPartials: maxPartials,
        maxAnalysisHz: maxAnalysisHz ?? this.maxAnalysisHz,
        partialSearchCents: partialSearchCents,
        minPartialSnrDb: minPartialSnrDb,
        minPartials: minPartials,
        minPartialsForB: minPartialsForB,
        maxSpreadCents: maxSpreadCents,
        maxPartialResidualCents: maxPartialResidualCents,
        minLevelAboveFloorDb: minLevelAboveFloorDb,
        zeroPadFactor: zeroPadFactor,
        yinThreshold: yinThreshold,
        minPeriodicity: minPeriodicity,
        octaveOddPowerRatio: octaveOddPowerRatio,
        adaptiveWindowPeriods:
            adaptiveWindowPeriods ?? this.adaptiveWindowPeriods,
        minReadingWindowMs: minReadingWindowMs,
        maxLateSpreadCents: maxLateSpreadCents ?? this.maxLateSpreadCents,
      );

  /// Six-string guitar, drop tunings included (D2 73 Hz → 60 Hz floor).
  static const guitar = PreciseTunerProfile(
    name: 'guitar',
    minHz: 60,
    maxHz: 1400,
    readingWindowMs: 400,
    defaultB: 1e-4,
    maxB: 1e-3,
  );

  /// Nylon-strung ukulele, GCEA (low-G included: G3 196 Hz).
  static const ukulele = PreciseTunerProfile(
    name: 'ukulele',
    minHz: 150,
    maxHz: 1400,
    readingWindowMs: 300,
    defaultB: 3e-5,
    maxB: 5e-4,
  );

  /// Four/five-string bass, B0 (30.9 Hz) and E1 (41.2 Hz) included.
  static const bass = PreciseTunerProfile(
    name: 'bass',
    minHz: 28,
    maxHz: 500,
    readingWindowMs: 600,
    defaultB: 2e-4,
    maxB: 2e-3,
    maxSegmentMs: 1800,
  );

  static const all = [guitar, ukulele, bass];
}

enum TunerRefusal {
  invalidSamples,
  insufficientSamples,
  tooQuiet,
  noPitch,
  tooFewPartials,
  unstable,
}

/// One analysis window's fit.
final class TunerReading {
  const TunerReading({
    required this.f0Hz,
    required this.inharmonicityB,
    required this.partials,
    required this.fundamentalFound,
  });
  final double f0Hz, inharmonicityB;
  final int partials;
  final bool fundamentalFound;
}

final class TuningMeasurement {
  const TuningMeasurement({
    required this.f0Hz,
    required this.inharmonicityB,
    required this.midi,
    required this.centsFromNearest,
    required this.spreadCents,
    required this.readings,
    this.centsFromTarget,
    this.fromLateReadings = false,
  });

  /// True when the value is the later readings' mean because the full set
  /// spread more than the strict limit (E41 arm U).
  final bool fromLateReadings;

  /// Inharmonicity-free fundamental (f_n = n·f0·sqrt(1 + B·n²)).
  final double f0Hz;
  final double inharmonicityB;
  final int midi;

  /// Signed cents from the nearest equal-tempered note.
  final double centsFromNearest;
  final double? centsFromTarget;
  final double spreadCents;
  final List<TunerReading> readings;
}

final class TunerResult {
  const TunerResult.measured(TuningMeasurement this.measurement)
      : refusal = null;
  const TunerResult.refused(TunerRefusal this.refusal) : measurement = null;
  final TuningMeasurement? measurement;
  final TunerRefusal? refusal;
  bool get measured => measurement != null;
}

final class _Partial {
  const _Partial(this.n, this.hz, this.weight);
  final int n;
  final double hz, weight;
}

/// Precise, inharmonicity-aware tuner (roadmap step 1, research §3.4).
///
/// 1. Find the pluck (envelope peak) and skip [PreciseTunerProfile.skipAfterAttackMs].
/// 2. Coarse f0 by prior-free YIN, then an odd-partial octave check (or the
///    caller's target string), then a harmonic-sum refinement.
/// 3. In several overlapping windows, locate partials 1..8 on a zero-padded
///    Blackman-Harris spectrum (log-parabolic peak interpolation) and fit
///    f_n² / n² = f0² + f0²·B·n² by weighted least squares: f0 and B jointly.
///    A missing or weak fundamental is simply absent from the fit; partials
///    n ≥ 2 carry the estimate.
/// 4. Readings are combined by median (trimmed mean from five readings up);
///    a spread above [PreciseTunerProfile.maxSpreadCents] is a refusal.
///
/// Pure DSP: no trained weights, nothing leaves the device.
final class PreciseTuner {
  PreciseTuner({
    this.profile = PreciseTunerProfile.guitar,
    this.referenceA4Hz = 440,
    this.attackLocator = const AttackLocator(),
  });

  final PreciseTunerProfile profile;
  final double referenceA4Hz;

  /// Used when the caller does not pass `attackIndex`: the last pluck that
  /// still leaves a full measurement (E39; was the loudest frame until E38).
  final AttackLocator attackLocator;

  TunerResult measure(
    List<double> samples, {
    required int sampleRate,
    int? attackIndex,
    double? roomFloorDb,
    double? targetHz,
  }) {
    if (sampleRate <= 0) throw ArgumentError('Invalid sample rate');
    for (final s in samples) {
      if (!s.isFinite || s.abs() > 1) {
        return const TunerResult.refused(TunerRefusal.invalidSamples);
      }
    }
    final p = profile;
    final skip = (p.skipAfterAttackMs * sampleRate / 1000).round();
    var win = (p.readingWindowMs * sampleRate / 1000).round();
    var hop = (p.readingHopMs * sampleRate / 1000).round();
    final attack = attackIndex ??
        attackLocator.lastUsableAttack(samples, sampleRate,
            requiredSamples: skip + win + hop * (p.minReadings - 1));
    if (attack == null) {
      return const TunerResult.refused(TunerRefusal.insufficientSamples);
    }
    final start = attack + skip;
    final end = math.min(
        samples.length, start + (p.maxSegmentMs * sampleRate / 1000).round());
    double? earlyCoarse;
    final periods = p.adaptiveWindowPeriods;
    if (periods != null && start >= 0 && start < end) {
      earlyCoarse = targetHz ?? _yinCoarse(samples, sampleRate, start, end);
      if (earlyCoarse != null) {
        final ms = (periods * 1000 / earlyCoarse).clamp(
            p.minReadingWindowMs.toDouble(), p.readingWindowMs.toDouble());
        win = (ms * sampleRate / 1000).round();
        hop = math.max(
            1,
            (p.readingHopMs * ms / p.readingWindowMs * sampleRate / 1000)
                .round());
      }
    }
    if (start < 0 || end - start < win + hop * (p.minReadings - 1)) {
      return const TunerResult.refused(TunerRefusal.insufficientSamples);
    }
    if (roomFloorDb != null &&
        _rmsDb(samples, start, end) < roomFloorDb + p.minLevelAboveFloorDb) {
      return const TunerResult.refused(TunerRefusal.tooQuiet);
    }

    final window = blackmanHarris(win);
    final fftSize = nextPowerOfTwo(win * p.zeroPadFactor);
    final binHz = sampleRate / fftSize;
    final spectra = <Float64List>[];
    for (var s = start; s + win <= end; s += hop) {
      spectra
          .add(magnitudeSpectrum(samples.sublist(s, s + win), window, fftSize));
    }

    double? coarse;
    if (targetHz != null) {
      coarse = _harmonicSearch(spectra.first, binHz, targetHz, 150);
    } else {
      final yin = earlyCoarse ?? _yinCoarse(samples, sampleRate, start, end);
      if (yin == null) return const TunerResult.refused(TunerRefusal.noPitch);
      coarse = _resolveOctave(spectra.first, binHz, yin);
      coarse = _harmonicSearch(spectra.first, binHz, coarse, 50);
    }
    if (coarse < p.minHz * 0.97 || coarse > p.maxHz * 1.03) {
      return const TunerResult.refused(TunerRefusal.noPitch);
    }

    final readings = <TunerReading>[];
    var b = p.defaultB;
    var f = coarse;
    for (final spec in spectra) {
      final reading = _fitReading(spec, binHz, sampleRate, f, b);
      if (reading == null) continue;
      readings.add(reading);
      f = reading.f0Hz;
      b = reading.inharmonicityB;
    }
    if (readings.length < p.minReadings) {
      return const TunerResult.refused(TunerRefusal.tooFewPartials);
    }

    final ref = _median([for (final r in readings) r.f0Hz]);
    final cs = [for (final r in readings) _cents(r.f0Hz, ref)]..sort();
    final kept = cs.length >= 5 ? cs.sublist(1, cs.length - 1) : cs;
    final spread = kept.last - kept.first;
    var combinedCents = cs.length >= 5
        ? kept.reduce((a, b) => a + b) / kept.length
        : _median(cs);
    var fromLate = false;
    if (spread > p.maxSpreadCents) {
      final lateLimit = p.maxLateSpreadCents;
      if (lateLimit == null || spread > lateLimit) {
        return const TunerResult.refused(TunerRefusal.unstable);
      }
      // Time order, later half (at least two readings), trimmed from five up.
      final late = [
        for (final r in readings.sublist(readings.length ~/ 2))
          _cents(r.f0Hz, ref)
      ]..sort();
      final lateKept =
          late.length >= 5 ? late.sublist(1, late.length - 1) : late;
      combinedCents = lateKept.reduce((a, b) => a + b) / lateKept.length;
      fromLate = true;
    }
    final f0 = ref * math.pow(2, combinedCents / 1200);
    final midiExact = 69 + 12 * math.log(f0 / referenceA4Hz) / math.ln2;
    final midi = midiExact.round();
    return TunerResult.measured(TuningMeasurement(
      f0Hz: f0.toDouble(),
      inharmonicityB: _median([for (final r in readings) r.inharmonicityB]),
      midi: midi,
      centsFromNearest: (midiExact - midi) * 100,
      centsFromTarget:
          targetHz == null ? null : _cents(f0.toDouble(), targetHz),
      spreadCents: spread,
      readings: List.unmodifiable(readings),
      fromLateReadings: fromLate,
    ));
  }

  /// Start of the loudest 10 ms frame. The E36–E38 attack rule, kept for
  /// baselines: under AGC it can pick a later note's attack (E38).
  static int envelopePeakIndex(List<double> x, int sampleRate) {
    final frame = math.max(1, (0.01 * sampleRate).round());
    var best = 0, bestE = -1.0;
    for (var s = 0; s + frame <= x.length; s += frame) {
      var e = 0.0;
      for (var i = s; i < s + frame; i++) {
        e += x[i] * x[i];
      }
      if (e > bestE) {
        bestE = e;
        best = s;
      }
    }
    return best;
  }

  double? _yinCoarse(List<double> x, int sampleRate, int start, int end) {
    final p = profile;
    var size = nextPowerOfTwo((2.2 * sampleRate / p.minHz).ceil());
    size = math.max(size, 2048);
    final source = YinPitchSource(
        minHz: p.minHz, maxHz: p.maxHz, threshold: p.yinThreshold);
    final values = <double>[];
    for (var s = start; s + size <= end && values.length < 5; s += size ~/ 2) {
      final r = source.analyze(x.sublist(s, s + size),
          sampleRate: sampleRate, tStartUs: 0);
      if (r.f0Hz != null && r.periodicity >= p.minPeriodicity) {
        values.add(r.f0Hz!);
      }
    }
    return values.isEmpty ? null : _median(values);
  }

  /// YIN can lock an octave high when even partials dominate (bridge pick,
  /// phone low cut). The odd partials of f/2 lie *between* the partials of f;
  /// real power there means the true fundamental is f/2.
  double _resolveOctave(Float64List spec, double binHz, double f) {
    final half = f / 2;
    if (half < profile.minHz) return f;
    var odd = 0.0, all = 0.0;
    for (var n = 1; n <= 2 * profile.maxPartials; n++) {
      final hz = n * half * math.sqrt(1 + profile.defaultB * n * n);
      if (hz > profile.maxAnalysisHz || hz / binHz >= spec.length - 2) break;
      final pw = math.pow(_bandPeak(spec, binHz, hz, 25), 2).toDouble();
      all += pw;
      if (n.isOdd) odd += pw;
    }
    return all > 0 && odd / all >= profile.octaveOddPowerRatio ? half : f;
  }

  /// Maximises summed partial magnitude over ±[rangeCents] in 2-cent steps.
  double _harmonicSearch(
      Float64List spec, double binHz, double centre, double rangeCents) {
    var best = centre, bestS = -1.0;
    for (var c = -rangeCents; c <= rangeCents; c += 2) {
      final f = centre * math.pow(2, c / 1200);
      var s = 0.0;
      for (var n = 1; n <= profile.maxPartials; n++) {
        final hz = n * f * math.sqrt(1 + profile.defaultB * n * n);
        if (hz > profile.maxAnalysisHz || hz / binHz >= spec.length - 2) break;
        s += _bandPeak(spec, binHz, hz, 6);
      }
      if (s > bestS) {
        bestS = s;
        best = f.toDouble();
      }
    }
    return best;
  }

  double _bandPeak(Float64List spec, double binHz, double hz, double cents) {
    final r = math.pow(2, cents / 1200).toDouble();
    final lo = math.max(1, (hz / r / binHz).floor());
    final hi = math.min(spec.length - 1, (hz * r / binHz).ceil());
    var m = 0.0;
    for (var k = lo; k <= hi; k++) {
      if (spec[k] > m) m = spec[k];
    }
    return m;
  }

  TunerReading? _fitReading(
    Float64List spec,
    double binHz,
    int sampleRate,
    double f0,
    double b,
  ) {
    final p = profile;
    final partials = <_Partial>[];
    final searchRatio = math.pow(2, p.partialSearchCents / 1200).toDouble();
    for (var n = 1; n <= p.maxPartials; n++) {
      final predicted = n * f0 * math.sqrt(1 + b * n * n);
      if (predicted > p.maxAnalysisHz || predicted > 0.45 * sampleRate) break;
      final halfBand = math.min(predicted * (searchRatio - 1), 0.4 * f0);
      final lo = math.max(2, ((predicted - halfBand) / binHz).ceil());
      final hi =
          math.min(spec.length - 3, ((predicted + halfBand) / binHz).floor());
      if (hi <= lo) continue;
      var k = lo;
      for (var j = lo + 1; j <= hi; j++) {
        if (spec[j] > spec[k]) k = j;
      }
      if (k == lo || k == hi || spec[k] <= 0) continue;
      final a = _db(spec[k - 1]), c = _db(spec[k]), d = _db(spec[k + 1]);
      final denom = a - 2 * c + d;
      final delta = denom == 0 ? 0.0 : 0.5 * (a - d) / denom;
      final hz = (k + delta) * binHz;
      final peakDb = c - 0.25 * (a - d) * delta;
      final noiseDb = _noiseDb(spec, binHz, predicted, f0);
      final snrDb = peakDb - noiseDb;
      if (snrDb < p.minPartialSnrDb) continue;
      final snrPow = math.pow(10, math.min(snrDb, 40) / 10).toDouble();
      partials.add(_Partial(n, hz, n * n * snrPow));
    }
    while (partials.length >= p.minPartials) {
      final fit = _fit(partials);
      final residuals = [
        for (final q in partials)
          _cents(q.hz, q.n * fit.f0 * math.sqrt(1 + fit.b * q.n * q.n)).abs()
      ];
      var worst = 0;
      for (var i = 1; i < residuals.length; i++) {
        if (residuals[i] > residuals[worst]) worst = i;
      }
      if (residuals[worst] <= p.maxPartialResidualCents) {
        return TunerReading(
          f0Hz: fit.f0,
          inharmonicityB: fit.b,
          partials: partials.length,
          fundamentalFound: partials.any((q) => q.n == 1),
        );
      }
      if (partials.length == p.minPartials) return null;
      partials.removeAt(worst);
    }
    return null;
  }

  ({double f0, double b}) _fit(List<_Partial> ps) {
    final p = profile;
    final ns = [for (final q in ps) q.n];
    final spansOctave = ns.reduce(math.max) >= 2 * ns.reduce(math.min);
    if (ps.length >= p.minPartialsForB && spansOctave) {
      // y = a + c·x with y = (f/n)², x = n², a = f0², c = f0²·B.
      var sw = 0.0, sx = 0.0, sy = 0.0, sxx = 0.0, sxy = 0.0;
      for (final q in ps) {
        final x = (q.n * q.n).toDouble();
        final y = (q.hz / q.n) * (q.hz / q.n);
        sw += q.weight;
        sx += q.weight * x;
        sy += q.weight * y;
        sxx += q.weight * x * x;
        sxy += q.weight * x * y;
      }
      final det = sw * sxx - sx * sx;
      if (det > 0) {
        final c = (sw * sxy - sx * sy) / det;
        final a = (sy - c * sx) / sw;
        if (a > 0) {
          final bFit = c / a;
          if (bFit >= 0 && bFit <= p.maxB) {
            return (f0: math.sqrt(a), b: bFit);
          }
          return (
            f0: _fixedB(ps, bFit.clamp(0.0, p.maxB)),
            b: bFit.clamp(0.0, p.maxB)
          );
        }
      }
    }
    return (f0: _fixedB(ps, p.defaultB), b: p.defaultB);
  }

  double _fixedB(List<_Partial> ps, double b) {
    var num = 0.0, den = 0.0;
    for (final q in ps) {
      final g = 1 + b * q.n * q.n;
      final y = (q.hz / q.n) * (q.hz / q.n);
      num += q.weight * y * g;
      den += q.weight * g * g;
    }
    return math.sqrt(num / den);
  }

  /// Median magnitude (dB) over ±f0/2 around a partial: the local floor.
  double _noiseDb(Float64List spec, double binHz, double centre, double f0) {
    final lo = math.max(1, ((centre - f0 / 2) / binHz).floor());
    final hi = math.min(spec.length - 1, ((centre + f0 / 2) / binHz).ceil());
    final values = [for (var k = lo; k <= hi; k++) spec[k]]..sort();
    return _db(values[values.length ~/ 2]);
  }

  static double _db(double m) => 20 * math.log(math.max(m, 1e-12)) / math.ln10;

  static double _cents(double a, double b) => 1200 * math.log(a / b) / math.ln2;

  static double _median(List<double> v) {
    final s = List<double>.of(v)..sort();
    final m = s.length ~/ 2;
    return s.length.isOdd ? s[m] : (s[m - 1] + s[m]) / 2;
  }

  static double _rmsDb(List<double> x, int start, int end) {
    var e = 0.0;
    for (var i = start; i < end; i++) {
      e += x[i] * x[i];
    }
    final rms = math.sqrt(e / math.max(1, end - start));
    return 20 * math.log(math.max(rms, 1e-9)) / math.ln10;
  }
}
