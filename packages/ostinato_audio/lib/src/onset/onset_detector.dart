import 'dart:math' as math;
import 'dart:typed_data';

import '../dsp/fft.dart';

/// A detected note start on the shared monotonic clock.
final class Onset {
  const Onset({required this.tUs, required this.strength});
  final int tUs;

  /// Flux value relative to the adaptive threshold at that moment. Not a
  /// musical dynamic — do not show it to users as "how hard you played".
  final double strength;
}

/// Spectral-flux onset detector over log-spaced bands, with an adaptive median
/// threshold.
///
/// Energy-based detection is the obvious choice and the wrong one for the
/// instruments we start with: a legato bow change or a slurred vocal note can
/// produce no energy jump at all, while a room's air conditioner produces
/// plenty. Flux over a log-magnitude spectrum reacts to *spectral change*,
/// which is what a new note actually is.
///
/// Known and accepted limit: on bowed strings recall stays imperfect. That is
/// why the family metric is onset *alignment* to a known grid rather than onset
/// count, and why the camera (which sees the bow reverse unambiguously) is the
/// senior partner in fusion findings.
final class OnsetDetector {
  const OnsetDetector({
    this.frameMs = 46,
    this.hopMs = 6,
    this.medianWindow = 11,
    this.deltaAboveMedian = 0.08,
    this.minIntervalUs = 50000,
    this.bandCount = 24,
    this.minAnalysisHz = 40,
    this.maxAnalysisHz = 4000,
  });

  /// Analysis window length **in milliseconds**, not samples.
  ///
  /// Frequency resolution is `1 / duration`, so a window fixed at N samples
  /// resolves differently on a 44.1 kHz fixture than on the 48 kHz stream most
  /// Android devices actually deliver. Held at 2048 samples, this detector was
  /// clean on the test fixtures and reported 17 attacks for a 3-note cello
  /// phrase at 48 kHz — a defect that would have looked like "works on my
  /// machine, broken on half the devices".
  ///
  /// 46 ms is the shortest window measured to hold a cello C2 steady. Shorter
  /// windows tick faster but wobble in the bass; longer ones smear the attack
  /// and blunt the very timing this detector exists to report.
  final double frameMs;

  /// Step between windows. This, not [frameMs], sets timing granularity.
  final double hopMs;

  /// Frames used for the running median. Wider = calmer threshold = fewer
  /// spurious onsets in a noisy room, at the cost of reacting later to a real
  /// change in playing density.
  final int medianWindow;
  final double deltaAboveMedian;

  /// Refractory period. Two "onsets" 10 ms apart are one onset and a wobble.
  final int minIntervalUs;

  /// Log-spaced analysis bands. See [_bandMagnitudes] for why bands rather than
  /// raw DFT bins, and why this count is independent of the window length.
  final int bandCount;

  /// Analysed range. The low edge sits below the lowest fundamental we claim to
  /// support (cello C2 ≈ 65 Hz); the high edge keeps enough harmonic detail to
  /// see a bright attack without paying for bins nobody listens to.
  final double minAnalysisHz;
  final double maxAnalysisHz;

  /// Window length in samples at a given rate. Same duration everywhere, so the
  /// same music is analysed identically on a 44.1 kHz fixture and a 48 kHz phone.
  int frameSizeFor(int sampleRate) => (frameMs * sampleRate / 1000).round();

  int hopSizeFor(int sampleRate) => (hopMs * sampleRate / 1000).round();

  /// [absoluteStartSample] (E43): position of `samples[0]` in the continuous
  /// stream. When given, frames sit on a grid fixed to the stream (multiples
  /// of the hop) instead of to the buffer start, so two overlapping buffers
  /// analyse the same frames — which is what lets [cache] reuse them. With
  /// the same [absoluteStartSample], cached and uncached results are
  /// identical; only frames inside the buffer are ever used.
  List<Onset> detect(List<double> samples,
      {required int sampleRate,
      required int tStartUs,
      int? absoluteStartSample,
      OnsetFrameCache? cache}) {
    final frameSize = frameSizeFor(sampleRate);
    final hopSize = hopSizeFor(sampleRate);
    final offset = absoluteStartSample == null
        ? 0
        : ((-absoluteStartSample) % hopSize + hopSize) % hopSize;
    final flux = _spectralFlux(samples, sampleRate, offset,
        absoluteStartSample == null ? null : cache, absoluteStartSample ?? 0);
    if (flux.isEmpty) return const [];

    final onsets = <Onset>[];
    var lastTUs = -1 << 40;

    for (var i = 0; i < flux.length; i++) {
      final median = _localMedian(flux, i);
      final threshold = median + deltaAboveMedian;
      final isPeak = flux[i] > threshold &&
          (i == 0 || flux[i] >= flux[i - 1]) &&
          (i == flux.length - 1 || flux[i] >= flux[i + 1]);
      if (!isPeak) continue;

      // A frame stands for the middle of the window it analysed, not its first
      // sample. Timestamping at the start reported every onset early by roughly
      // half a window — 13 ms at the old frame length, 31 ms at this one — a
      // systematic bias that would have been silently absorbed into every
      // rhythm measurement built on top of it.
      final centreSample = offset + i * hopSize + frameSize / 2;
      final tUs = tStartUs + (centreSample * 1000000 / sampleRate).round();
      if (tUs - lastTUs < minIntervalUs) continue;

      onsets.add(Onset(tUs: tUs, strength: flux[i] - threshold));
      lastTUs = tUs;
    }
    return onsets;
  }

  /// Half-wave rectified difference of band magnitudes between frames.
  List<double> _spectralFlux(List<double> x, int sampleRate, int offset,
      OnsetFrameCache? cache, int absoluteStart) {
    final edges = bandEdges(sampleRate);
    final frameSize = frameSizeFor(sampleRate);
    final hopSize = hopSizeFor(sampleRate);
    final frames = <List<double>>[];
    cache?._check(sampleRate, frameSize, hopSize, bandCount);
    _FrameDft? dft;
    for (var start = offset; start + frameSize <= x.length; start += hopSize) {
      final key = (absoluteStart + start) ~/ hopSize;
      final cached = cache?._frames[key];
      if (cached != null) {
        cache!.hits++;
        frames.add(cached);
        continue;
      }
      dft ??= _FrameDft(frameSize);
      final m = _bandMagnitudes(x, start, edges, frameSize, dft);
      cache?._put(key, m);
      frames.add(m);
    }
    if (frames.length < 2) return const [];

    final flux = List<double>.filled(frames.length, 0);
    for (var f = 1; f < frames.length; f++) {
      var sum = 0.0;
      for (var k = 0; k < frames[f].length; k++) {
        final diff = frames[f][k] - frames[f - 1][k];
        if (diff > 0) sum += diff;
      }
      flux[f] = sum / frames[f].length;
    }
    return flux;
  }

  /// Log-compressed magnitude per band for one Hann-windowed frame.
  ///
  /// Bands, not raw bins, and the reason is a defect the audio fixture set
  /// caught (O-019). Linear DFT bins are `sampleRate / frameSize` apart — 43 Hz
  /// at a 23 ms window. A cello C2 (65 Hz) therefore falls *between* bins 1
  /// and 2, and its leakage pattern shifts every frame as the tone's phase
  /// advances against the window. The magnitude vector wobbles, flux reads that
  /// wobble as change, and a perfectly sustained note is reported as ~13 note
  /// attacks per second. Measured: phantom onsets below ~147 Hz, none above.
  ///
  /// Lengthening the frame fixes the bass and breaks the treble, because a
  /// fixed *bin count* silently makes frame length set the analysed bandwidth
  /// too (64 bins × 10.8 Hz = a 690 Hz ceiling at frameSize 4096, which puts a
  /// C5's harmonics outside the analysis entirely). Resolution and bandwidth
  /// were one knob; they need to be two.
  ///
  /// Summing energy across a band wider than the leakage makes the magnitude
  /// phase-stable wherever the partial happens to sit, and log spacing puts the
  /// narrow bands where pitch actually lives. Temporal precision — the thing
  /// onset detection genuinely needs — is set by the hop, not by this.
  List<double> _bandMagnitudes(List<double> x, int start, List<int> edges,
      int frameSize, _FrameDft dft) {
    final out = List<double>.filled(edges.length - 1, 0);
    final spectrum = dft.transform(x, start, edges.last);
    for (var b = 0; b < out.length; b++) {
      var energy = 0.0;
      for (var k = edges[b]; k < edges[b + 1]; k++) {
        energy += (spectrum.re[k] * spectrum.re[k] +
                spectrum.im[k] * spectrum.im[k]) /
            (frameSize * frameSize);
      }
      out[b] = math.log(1 + 1000 * math.sqrt(energy));
    }
    return out;
  }

  /// Linear-bin indices delimiting each log-spaced band.
  ///
  /// Derived from the sample rate given at analysis time rather than cached on
  /// the instance: a detector reused across a 44.1 kHz fixture and a 48 kHz
  /// device stream would otherwise analyse the second one at silently wrong
  /// frequencies. Bands that would collapse into the same linear bin are
  /// merged — an empty band contributes no energy and only dilutes the flux
  /// average.
  List<int> bandEdges(int sampleRate) {
    final frameSize = frameSizeFor(sampleRate);
    final binHz = sampleRate / frameSize;
    final nyquistBin = frameSize ~/ 2;
    final edges = <int>[];
    for (var b = 0; b <= bandCount; b++) {
      final hz = minAnalysisHz *
          math.pow(maxAnalysisHz / minAnalysisHz, b / bandCount);
      final bin = math.min(nyquistBin, math.max(1, (hz / binHz).round()));
      if (edges.isEmpty || bin > edges.last) edges.add(bin);
    }
    return edges;
  }

  double _localMedian(List<double> v, int i) {
    final half = medianWindow ~/ 2;
    final lo = math.max(0, i - half);
    final hi = math.min(v.length - 1, i + half);
    final window = v.sublist(lo, hi + 1)..sort();
    return window[window.length ~/ 2];
  }
}

/// Hann-windowed DFT of one frame at the frame's own bin spacing
/// (sampleRate / frameSize). Same bins as the per-bin sum this replaced
/// (rounding-level differences only), via [DftPlan]: the per-bin sum cost
/// ~0.1 s of CPU per second of 48 kHz audio, too slow for a 1.6 s tuning
/// buffer analysed every 350 ms on a phone.
final class _FrameDft {
  _FrameDft(int frameSize)
      : _plan = DftPlan(frameSize),
        _window = Float64List(frameSize),
        _frame = Float64List(frameSize) {
    for (var n = 0; n < frameSize; n++) {
      _window[n] = 0.5 - 0.5 * math.cos(2 * math.pi * n / (frameSize - 1));
    }
  }
  final DftPlan _plan;
  final Float64List _window, _frame;

  ({Float64List re, Float64List im}) transform(
      List<double> x, int start, int bins) {
    for (var n = 0; n < _frame.length; n++) {
      _frame[n] = x[start + n] * _window[n];
    }
    return _plan.transformReal(_frame, bins: math.min(bins + 1, _frame.length));
  }
}

/// Band magnitudes of already analysed frames, keyed by their position on
/// the stream's hop grid (E43). One cache belongs to one continuous stream
/// (one capture session); reset it when the stream restarts. Bounded: only
/// the most recent [maxFrames] frames are kept.
final class OnsetFrameCache {
  OnsetFrameCache({this.maxFrames = 1024});
  final int maxFrames;
  final Map<int, List<double>> _frames = {};
  int? _sampleRate, _frameSize, _hopSize, _bands;
  int hits = 0, misses = 0;

  void clear() {
    _frames.clear();
    hits = 0;
    misses = 0;
  }

  void _check(int sampleRate, int frameSize, int hopSize, int bands) {
    if (_sampleRate != sampleRate ||
        _frameSize != frameSize ||
        _hopSize != hopSize ||
        _bands != bands) {
      _frames.clear();
      _sampleRate = sampleRate;
      _frameSize = frameSize;
      _hopSize = hopSize;
      _bands = bands;
    }
  }

  void _put(int key, List<double> magnitudes) {
    misses++;
    _frames[key] = magnitudes;
    if (_frames.length > maxFrames) {
      final cut = key - maxFrames;
      _frames.removeWhere((k, _) => k <= cut);
    }
  }
}
