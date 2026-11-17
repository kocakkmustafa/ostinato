/// OST-P1-03 — aynı ders için iki koşunun ("önce" / "sonra") yargısız
/// karşılaştırma modeli (saf Dart; UI'ya bağlı değil, bayrağı
/// `ostinatoBeforeAfterEnabled`). Kullanıcıya dönük metin içermez; yalnız
/// cihazdaki özetlerden hesaplanır, ağ ya da G/Ç yoktur.
library;

import '../loop/practice_outcome.dart';

/// Bir ölçünün yönü. Yargı taşımaz: yalnız "daha iyi bir yöne gitti",
/// "aynı kaldı" ya da "farklı" der.
enum BeforeAfterDirection {
  /// Ölçü, doğru/az hata yönünde değişti.
  improved,

  /// Değer değişmedi.
  same,

  /// Değer değişti; yönü iyi/kötü diye okunmaz (ör. tempo).
  different,
}

/// [delta] = sonra − önce. [direction] yukarıdaki kurala göre.
final class BeforeAfterMeasure<T extends num> {
  const BeforeAfterMeasure({
    required this.before,
    required this.after,
    required this.delta,
    required this.direction,
  });

  final T before, after, delta;
  final BeforeAfterDirection direction;
}

final class BeforeAfter {
  const BeforeAfter({
    required this.tempoBpm,
    required this.correct,
    required this.different,
    required this.unheard,
    required this.errorBars,
    required this.medianTimingMs,
  });

  /// Tempo (bpm). Değişim yönsüzdür: aynı ya da farklı.
  final BeforeAfterMeasure<int> tempoBpm;

  /// Doğru sayısı: artış = iyileşti.
  final BeforeAfterMeasure<int> correct;

  /// Farklı duyulan sayısı: azalış = iyileşti.
  final BeforeAfterMeasure<int> different;

  /// Duyulamayan sayısı: azalış = iyileşti.
  final BeforeAfterMeasure<int> unheard;

  /// Hata ölçüsü haritasındaki ölçü sayısı: azalış = iyileşti.
  final BeforeAfterMeasure<int> errorBars;

  /// Ortanca |zamanlama| (ms): azalış = iyileşti. İki taraf da ölçülmüş
  /// ve kalibre ise dolu, aksi hâlde null.
  final BeforeAfterMeasure<double>? medianTimingMs;
}

/// Çağıran, iki koşunun AYNI derse ait olduğunu garanti eder; model bunu
/// doğrulamaz. `medianTimingMs` özette mutlak değerdir (erken/geç yönü yok).
///
/// Kurallar (deterministik):
/// - Taraflardan biri ölçülmemiş (`!gate.eligible`) ise null: kıyas yok.
/// - Tempo dışındaki sayaçlar için azalış/artış yönü yukarıdaki belgelere
///   göre; tempo değişirse hep [BeforeAfterDirection.different].
/// - `medianTimingMs`: iki taraf da null değil ve `timingCalibrated` ise
///   hesaplanır, aksi hâlde null.
BeforeAfter? beforeAfterOf(
  PracticeRunSummary before,
  PracticeRunSummary after,
) {
  if (!before.gate.eligible || !after.gate.eligible) return null;

  BeforeAfterMeasure<int> count(
    int b,
    int a, {
    required bool higherIsBetter,
    bool directionless = false,
  }) {
    final d = a - b;
    final dir = d == 0
        ? BeforeAfterDirection.same
        : directionless
        ? BeforeAfterDirection.different
        : (d > 0) == higherIsBetter
        ? BeforeAfterDirection.improved
        : BeforeAfterDirection.different;
    return BeforeAfterMeasure<int>(
      before: b,
      after: a,
      delta: d,
      direction: dir,
    );
  }

  BeforeAfterMeasure<double>? timing;
  final tb = before.medianTimingMs, ta = after.medianTimingMs;
  if (tb != null &&
      ta != null &&
      before.timingCalibrated &&
      after.timingCalibrated) {
    final d = ta - tb;
    timing = BeforeAfterMeasure<double>(
      before: tb,
      after: ta,
      delta: d,
      direction: d == 0
          ? BeforeAfterDirection.same
          : d < 0
          ? BeforeAfterDirection.improved
          : BeforeAfterDirection.different,
    );
  }

  return BeforeAfter(
    tempoBpm: count(
      before.bpm,
      after.bpm,
      higherIsBetter: true,
      directionless: true,
    ),
    correct: count(before.correct, after.correct, higherIsBetter: true),
    different: count(before.different, after.different, higherIsBetter: false),
    unheard: count(before.unheard, after.unheard, higherIsBetter: false),
    errorBars: count(
      before.errorBars.length,
      after.errorBars.length,
      higherIsBetter: false,
    ),
    medianTimingMs: timing,
  );
}
