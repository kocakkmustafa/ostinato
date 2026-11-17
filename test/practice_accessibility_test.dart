import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/practice/fallback/practice_accessibility.dart';

void main() {
  test('varsayılan tercihler: sade değişiklik yok', () {
    final p = planFor(const PracticeA11yPrefs());
    expect(p.motion, PracticeMotion.full);
    expect(p.reducedMotion, isFalse);
    expect(p.opaqueSurfaces, isFalse);
    expect(p.strongBorders, isFalse);
    expect(p.effectiveTextScale, 1.0);
    expect(p.noCompactLayout, isFalse);
  });

  test('tüm bool kombinasyonları x yazı ölçekleri', () {
    for (var i = 0; i < 8; i++) {
      final rm = i & 4 != 0, rt = i & 2 != 0, hc = i & 1 != 0;
      for (final s in [1.0, 1.29, 1.3, 2.0]) {
        final p = planFor(
          PracticeA11yPrefs(
            reduceMotion: rm,
            reduceTransparency: rt,
            highContrast: hc,
            textScale: s,
          ),
        );
        expect(p.reducedMotion, rm);
        expect(p.opaqueSurfaces, rt || hc);
        expect(p.strongBorders, hc);
        expect(p.noCompactLayout, s >= a11yLargeTextScale);
        expect(p.effectiveTextScale, s);
      }
    }
  });

  test('textScale sınırları', () {
    PracticeA11yPlan at(double s) => planFor(PracticeA11yPrefs(textScale: s));
    expect(at(1.2999).noCompactLayout, isFalse);
    expect(at(a11yLargeTextScale).noCompactLayout, isTrue);
    expect(at(0.5).effectiveTextScale, a11yMinTextScale);
    expect(at(-2).effectiveTextScale, a11yMinTextScale);
    expect(at(double.nan).effectiveTextScale, a11yMinTextScale);
    expect(at(99).effectiveTextScale, a11yMaxTextScale);
    expect(at(double.infinity).effectiveTextScale, a11yMaxTextScale);
    expect(at(99).noCompactLayout, isTrue);
  });
}
