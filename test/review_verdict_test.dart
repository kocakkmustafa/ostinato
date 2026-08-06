import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/screens/review_screen.dart';

/// `SessionSummary.verdict` — kalıcı regresyon kanıtı (koordinatör HÜKÜM 2b,
/// 2026-08-06). Önceki üçüncü kelime "Needs focus." idi: türetilmemiş bir
/// kesme noktasının kullanıcıya hüküm cümlesi üretmesiydi ve ailenin ton
/// kuralını ("öğretmen gibi, hakem gibi değil") ihlal ediyordu. Bu dosya
/// hem yeni betimleyici kelimeyi hem de eski hakem-dilinin BİR DAHA hiç
/// dönmediğini kilitler.
void main() {
  SessionSummary summary({required int sample, required int out, required List<double> hist}) =>
      SessionSummary(
          elapsedSeconds: 30, sampleCount: sample, outCount: out, history: hist);

  test('bandın çoğunda: "Steady." — ölçülen olguyu betimler', () {
    final SessionSummary s =
        summary(sample: 100, out: 10, hist: <double>[3.0, 3.1, 2.9]);
    expect(s.insideShare, greaterThan(0.66));
    expect(s.verdict, 'Steady.');
  });

  test('bandın çoğu dışında ama son yarı ilk yarıdan belirgin düşük: "Improving."', () {
    final SessionSummary s = summary(
      sample: 100,
      out: 40,
      hist: <double>[10, 10, 10, 10, 10, 2, 2, 2, 2, 2],
    );
    expect(s.insideShare, lessThanOrEqualTo(0.66));
    expect(s.verdict, 'Improving.');
  });

  test('bandın çoğu dışında ve düzelme YOK: "Mostly outside the band." — '
      'kişiyi DEĞİL, olguyu betimler', () {
    final SessionSummary s =
        summary(sample: 100, out: 40, hist: <double>[9.0, 9.2]); // length<=8 → _improving()=false
    expect(s.insideShare, lessThanOrEqualTo(0.66));
    expect(s.verdict, 'Mostly outside the band.');
  });

  test('REGRESYON KİLİDİ: hakem dili ("Needs focus.") hiçbir girdide dönmez', () {
    for (final int out in <int>[0, 20, 40, 60, 80, 100]) {
      for (final List<double> hist in <List<double>>[
        <double>[],
        <double>[9.0, 9.2],
        <double>[10, 10, 10, 10, 10, 2, 2, 2, 2, 2],
        <double>[2, 2, 2, 2, 2, 10, 10, 10, 10, 10],
      ]) {
        final String v = summary(sample: 100, out: out, hist: hist).verdict;
        expect(v, isNot('Needs focus.'),
            reason: 'out=$out hist=$hist → "$v" — eski hakem dili geri döndü');
      }
    }
  });
}
