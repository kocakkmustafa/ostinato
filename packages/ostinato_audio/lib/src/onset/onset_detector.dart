import 'dart:math' as math;

/// A detected note start on the shared monotonic clock.
final class Onset {
  const Onset({required this.tUs, required this.strength});
  final int tUs;

  /// Flux value relative to the adaptive threshold at that moment. Not a
  /// musical dynamic — do not show it to users as "how hard you played".
  final double strength;
}

/// Spectral-flux onset detector with an adaptive median threshold.
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
  OnsetDetector({
    this.frameSize = 1024,
    this.hopSize = 256,
    this.medianWindow = 11,
    this.deltaAboveMedian = 0.08,
    this.minIntervalUs = 50000,
  });

  final int frameSize;
  final int hopSize;

  /// Frames used for the running median. Wider = calmer threshold = fewer
  /// spurious onsets in a noisy room, at the cost of reacting later to a real
  /// change in playing density.
  final int medianWindow;
  final double deltaAboveMedian;

  /// Refractory period. Two "onsets" 10 ms apart are one onset and a wobble.
  final int minIntervalUs;

  List<Onset> detect(List<double> samples, {required int sampleRate, required int tStartUs}) {
    final flux = _spectralFlux(samples);
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

      final tUs = tStartUs + (i * hopSize * 1000000 / sampleRate).round();
      if (tUs - lastTUs < minIntervalUs) continue;

      onsets.add(Onset(tUs: tUs, strength: flux[i] - threshold));
      lastTUs = tUs;
    }
    return onsets;
  }

  /// Half-wave rectified difference of log magnitude spectra between frames.
  List<double> _spectralFlux(List<double> x) {
    final frames = <List<double>>[];
    for (var start = 0; start + frameSize <= x.length; start += hopSize) {
      frames.add(_logMagnitude(x, start));
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

  /// Magnitude spectrum of one Hann-windowed frame, in log domain.
  ///
  /// A direct DFT at a coarse bin count: onset timing needs temporal precision,
  /// not frequency precision, and this keeps the reference implementation
  /// readable. Native ports are free to use an FFT — they are validated against
  /// this by fixture replay, not by sharing code.
  List<double> _logMagnitude(List<double> x, int start) {
    const bins = 64;
    final out = List<double>.filled(bins, 0);
    for (var k = 1; k <= bins; k++) {
      var re = 0.0;
      var im = 0.0;
      final omega = 2 * math.pi * k / frameSize;
      for (var n = 0; n < frameSize; n++) {
        // Hann window suppresses the spectral splatter that would otherwise
        // look like flux at every frame boundary.
        final w = 0.5 - 0.5 * math.cos(2 * math.pi * n / (frameSize - 1));
        final s = x[start + n] * w;
        re += s * math.cos(omega * n);
        im -= s * math.sin(omega * n);
      }
      final mag = math.sqrt(re * re + im * im) / frameSize;
      out[k - 1] = math.log(1 + 1000 * mag);
    }
    return out;
  }

  double _localMedian(List<double> v, int i) {
    final half = medianWindow ~/ 2;
    final lo = math.max(0, i - half);
    final hi = math.min(v.length - 1, i + half);
    final window = v.sublist(lo, hi + 1)..sort();
    return window[window.length ~/ 2];
  }
}
