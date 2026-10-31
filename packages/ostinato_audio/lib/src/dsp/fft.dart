import 'dart:math' as math;
import 'dart:typed_data';

/// In-place iterative radix-2 complex FFT. Original code, no dependency.
///
/// Kept separate from the private FFT inside `GuitarPitchObserver` on
/// purpose: that copy is frozen by the E33 equivalence fixture and must not
/// change underneath it.
void fftInPlace(Float64List re, Float64List im) {
  final n = re.length;
  if (n != im.length || n == 0 || (n & (n - 1)) != 0) {
    throw ArgumentError('FFT length must be a power of two');
  }
  for (var i = 1, j = 0; i < n; i++) {
    var bit = n >> 1;
    for (; j & bit != 0; bit >>= 1) {
      j ^= bit;
    }
    j ^= bit;
    if (i < j) {
      final tr = re[i];
      re[i] = re[j];
      re[j] = tr;
      final ti = im[i];
      im[i] = im[j];
      im[j] = ti;
    }
  }
  for (var size = 2; size <= n; size <<= 1) {
    final half = size >> 1;
    final angle = -2 * math.pi / size;
    final stepRe = math.cos(angle), stepIm = math.sin(angle);
    for (var start = 0; start < n; start += size) {
      var wr = 1.0, wi = 0.0;
      for (var k = 0; k < half; k++) {
        final a = start + k, b = a + half;
        final br = re[b] * wr - im[b] * wi;
        final bi = re[b] * wi + im[b] * wr;
        re[b] = re[a] - br;
        im[b] = im[a] - bi;
        re[a] += br;
        im[a] += bi;
        final next = wr * stepRe - wi * stepIm;
        wi = wr * stepIm + wi * stepRe;
        wr = next;
      }
    }
  }
}

/// Smallest power of two that is >= [n].
int nextPowerOfTwo(int n) {
  var p = 1;
  while (p < n) {
    p <<= 1;
  }
  return p;
}

/// 4-term Blackman-Harris window (-92 dB side lobes). Side-lobe leakage from
/// a strong neighbouring partial is what biases a weak partial's peak, so the
/// precise tuner prefers this over Hann.
Float64List blackmanHarris(int n) {
  final w = Float64List(n);
  if (n == 1) {
    w[0] = 1;
    return w;
  }
  for (var i = 0; i < n; i++) {
    final x = 2 * math.pi * i / (n - 1);
    w[i] = 0.35875 -
        0.48829 * math.cos(x) +
        0.14128 * math.cos(2 * x) -
        0.01168 * math.cos(3 * x);
  }
  return w;
}

/// Magnitude spectrum (bins 0..n/2) of [samples] after [window], zero-padded
/// to [fftSize].
Float64List magnitudeSpectrum(
  List<double> samples,
  Float64List window,
  int fftSize,
) {
  if (samples.length != window.length || fftSize < samples.length) {
    throw ArgumentError('Window/sample length mismatch');
  }
  final re = Float64List(fftSize);
  final im = Float64List(fftSize);
  for (var i = 0; i < samples.length; i++) {
    re[i] = samples[i] * window[i];
  }
  fftInPlace(re, im);
  final mag = Float64List(fftSize ~/ 2 + 1);
  for (var k = 0; k < mag.length; k++) {
    mag[k] = math.sqrt(re[k] * re[k] + im[k] * im[k]);
  }
  return mag;
}

/// Linear convolution via FFT (overlap-free; both inputs fit one transform).
Float64List fftConvolve(List<double> a, List<double> b) {
  if (a.isEmpty || b.isEmpty) return Float64List(0);
  final outLen = a.length + b.length - 1;
  final n = nextPowerOfTwo(outLen);
  final ar = Float64List(n), ai = Float64List(n);
  final br = Float64List(n), bi = Float64List(n);
  for (var i = 0; i < a.length; i++) {
    ar[i] = a[i];
  }
  for (var i = 0; i < b.length; i++) {
    br[i] = b[i];
  }
  fftInPlace(ar, ai);
  fftInPlace(br, bi);
  // Multiply, then inverse via conjugation.
  for (var k = 0; k < n; k++) {
    final r = ar[k] * br[k] - ai[k] * bi[k];
    final i = ar[k] * bi[k] + ai[k] * br[k];
    ar[k] = r;
    ai[k] = -i;
  }
  fftInPlace(ar, ai);
  final out = Float64List(outLen);
  for (var i = 0; i < outLen; i++) {
    out[i] = ar[i] / n;
  }
  return out;
}

/// Exact DFT of any length N (Bluestein / chirp-z through power-of-two FFTs).
///
/// Gives the same bins as the textbook O(N²) sum `Σ x[n]·e^(−2πikn/N)` up to
/// floating-point rounding, in O(M log M) with M ≥ 2N − 1. Exists so a
/// detector whose frame length is set in *milliseconds* (and therefore is
/// rarely a power of two) can keep its exact bin frequencies while running
/// fast enough for a phone.
final class DftPlan {
  DftPlan(this.n) : _m = nextPowerOfTwo(2 * n - 1) {
    if (n <= 0) throw ArgumentError('DFT length must be positive');
    _chirpRe = Float64List(n);
    _chirpIm = Float64List(n);
    for (var k = 0; k < n; k++) {
      // k² mod 2N keeps the angle small, so large k lose no precision.
      final angle = math.pi * ((k * k) % (2 * n)) / n;
      _chirpRe[k] = math.cos(angle);
      _chirpIm[k] = math.sin(angle);
    }
    _kernelRe = Float64List(_m);
    _kernelIm = Float64List(_m);
    for (var k = 0; k < n; k++) {
      _kernelRe[k] = _chirpRe[k];
      _kernelIm[k] = _chirpIm[k];
      if (k > 0) {
        _kernelRe[_m - k] = _chirpRe[k];
        _kernelIm[_m - k] = _chirpIm[k];
      }
    }
    fftInPlace(_kernelRe, _kernelIm);
  }

  final int n;
  final int _m;
  late final Float64List _chirpRe, _chirpIm, _kernelRe, _kernelIm;

  /// DFT of the real sequence [x] (length [n]); returns bins 0..[bins]-1.
  ({Float64List re, Float64List im}) transformReal(List<double> x,
      {int? bins}) {
    if (x.length != n) throw ArgumentError('Expected $n samples');
    final count = math.min(bins ?? n, n);
    final ar = Float64List(_m), ai = Float64List(_m);
    for (var k = 0; k < n; k++) {
      // a_k = x_k · conj(chirp_k)
      ar[k] = x[k] * _chirpRe[k];
      ai[k] = -x[k] * _chirpIm[k];
    }
    fftInPlace(ar, ai);
    for (var k = 0; k < _m; k++) {
      final r = ar[k] * _kernelRe[k] - ai[k] * _kernelIm[k];
      final i = ar[k] * _kernelIm[k] + ai[k] * _kernelRe[k];
      // Conjugate so the forward FFT below acts as an inverse.
      ar[k] = r;
      ai[k] = -i;
    }
    fftInPlace(ar, ai);
    final re = Float64List(count), im = Float64List(count);
    for (var k = 0; k < count; k++) {
      final cr = ar[k] / _m, ci = -ai[k] / _m;
      // X_k = conj(chirp_k) · conv_k
      re[k] = cr * _chirpRe[k] + ci * _chirpIm[k];
      im[k] = ci * _chirpRe[k] - cr * _chirpIm[k];
    }
    return (re: re, im: im);
  }
}
