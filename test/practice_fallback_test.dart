import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/ostinato_release_policy.dart';
import 'package:ostinato/app/practice/fallback/practice_fallback.dart';

void main() {
  test('bayrak varsayılan KAPALI', () {
    expect(ostinatoFallbackModeEnabled, isFalse);
  });

  test('16 kombinasyon: bağımsız literal tablo', () {
    const m = PracticeFallbackMode.measured;
    const g = PracticeFallbackMode.unmeasuredGuided;
    const l = PracticeFallbackMode.listenOnly;
    // (izin, cihaz, kalibre, sağlıklı) -> beklenen mod
    const table = <(bool, bool, bool, bool, PracticeFallbackMode)>[
      (false, false, false, false, l),
      (false, false, false, true, l),
      (false, false, true, false, l),
      (false, false, true, true, l),
      (false, true, false, false, l),
      (false, true, false, true, l),
      (false, true, true, false, l),
      (false, true, true, true, l),
      (true, false, false, false, l),
      (true, false, false, true, l),
      (true, false, true, false, l),
      (true, false, true, true, l),
      (true, true, false, false, g),
      (true, true, false, true, g),
      (true, true, true, false, g),
      (true, true, true, true, m),
    ];
    expect(table.length, 16);
    expect(table.map((r) => (r.$1, r.$2, r.$3, r.$4)).toSet().length, 16);
    final counts = <PracticeFallbackMode, int>{};
    for (final r in table) {
      final got = decideFallback(
        micPermissionGranted: r.$1,
        micAvailable: r.$2,
        calibrated: r.$3,
        measurementHealthy: r.$4,
      );
      expect(got, r.$5, reason: '${r.$1} ${r.$2} ${r.$3} ${r.$4}');
      counts[got] = (counts[got] ?? 0) + 1;
    }
    expect(counts[m], 1);
    expect(counts[g], 3);
    expect(counts[l], 12);
  });

  test('örnek durumlar', () {
    PracticeFallbackMode m(bool p, bool a, bool c, bool h) => decideFallback(
      micPermissionGranted: p,
      micAvailable: a,
      calibrated: c,
      measurementHealthy: h,
    );
    expect(m(true, true, true, true), PracticeFallbackMode.measured);
    expect(m(false, true, true, true), PracticeFallbackMode.listenOnly);
    expect(m(true, false, true, true), PracticeFallbackMode.listenOnly);
    expect(m(true, true, false, true), PracticeFallbackMode.unmeasuredGuided);
    expect(m(true, true, true, false), PracticeFallbackMode.unmeasuredGuided);
  });

  test(
    'hiçbir modda ders bloke olmaz, yanlış hükmü yok; yalnız measured ölçer',
    () {
      const expectedMeasures = {
        PracticeFallbackMode.measured: true,
        PracticeFallbackMode.unmeasuredGuided: false,
        PracticeFallbackMode.listenOnly: false,
      };
      expect(expectedMeasures.length, PracticeFallbackMode.values.length);
      for (final e in expectedMeasures.entries) {
        expect(e.key.blocksLesson, isFalse);
        expect(e.key.canJudgeWrong, isFalse);
        expect(e.key.measuresPlaying, e.value);
      }
    },
  );
}
