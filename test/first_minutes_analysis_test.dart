// OST-P0-05 — pure logic: tap times against the beat grid, "could not
// measure" thresholds, human tolerance, judgment-free sentences.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/app_message_ids.dart';
import 'package:ostinato/app/first_minutes/first_minutes_copy.dart';
import 'package:ostinato/app/first_minutes/rhythm_tap_analysis.dart';

const _beat = 750000; // 80 bpm, microseconds
final _grid = [for (var i = 0; i < 4; i++) 1000000 + i * _beat];

List<int> _taps(List<double> offsetsMs) => [
  for (var i = 0; i < offsetsMs.length; i++)
    _grid[i] + (offsetsMs[i] * 1000).round(),
];

TapMeasurement _m(List<double> offsetsMs) =>
    measureTaps(tapTimesUs: _taps(offsetsMs), beatTimesUs: _grid);

void main() {
  test('taps exactly on the beat: measured, steady, zero spread', () {
    final m = _m([0, 0, 0, 0]);
    expect(m.measured, isTrue);
    expect(m.steadiness, TapSteadiness.steady);
    expect(m.spreadMs, 0);
    expect(m.matched, 4);
    expect(summaryFor(m), FirstMinutesCopy.summarySteady);
  });

  test('a constant late or early offset is reported, never judged', () {
    final late = _m([40, 40, 40, 40]);
    final early = _m([-50, -50, -50, -50]);
    expect(late.offsetMs, closeTo(40, 1e-9));
    expect(early.offsetMs, closeTo(-50, 1e-9));
    expect(late.steadiness, TapSteadiness.steady);
    expect(early.steadiness, TapSteadiness.steady);
    expect(summaryFor(late), FirstMinutesCopy.summarySteady);
  });

  test('human wobble is still measured and kindly worded', () {
    final m = _m([-50, 40, -30, 60]);
    expect(m.measured, isTrue);
    expect(m.spreadMs, closeTo(80, 1e-9));
    expect(m.steadiness, TapSteadiness.loose);
    expect(summaryFor(m), FirstMinutesCopy.summaryLoose);
  });

  test('wildly scattered taps are "not measured", not "bad"', () {
    final m = _m([-100, 90, -80, 110]);
    expect(m.status, TapMeasureStatus.notMeasured);
    expect(m.steadiness, isNull);
    expect(summaryFor(m), FirstMinutesCopy.summaryNotMeasured);
  });

  test('fewer than two taps, or none near a beat: not measured', () {
    expect(_m([10]).measured, isFalse);
    expect(_m([]).measured, isFalse);
    final far = measureTaps(
      tapTimesUs: [_grid[0] + 400000, _grid[1] + 400000],
      beatTimesUs: _grid,
    );
    expect(far.matched, lessThan(2));
    expect(far.measured, isFalse);
    // Two taps on four expected beats is exactly the coverage floor (2/4).
    expect(_m([0, 0]).measured, isTrue);
    // One of four is below it.
    expect(_m([0]).deviationsMs, [0.0, null, null, null]);
  });

  test('a skipped beat (the variation) leaves a null slot, not a miss', () {
    final grid = [_grid[0], _grid[1], _grid[3]];
    final m = measureTaps(
      tapTimesUs: [grid[0] + 20000, grid[1] - 10000, grid[2] + 5000],
      beatTimesUs: grid,
    );
    expect(m.measured, isTrue);
    expect(m.deviationsMs.length, 3);
    expect(m.deviationsMs.every((d) => d != null), isTrue);
  });

  test('extra taps outside the window are ignored, not counted against', () {
    final taps = [
      ..._taps([5, -5, 5, -5]),
      _grid[3] + 2000000,
    ];
    final m = measureTaps(tapTimesUs: taps, beatTimesUs: _grid);
    expect(m.matched, 4);
    expect(m.steadiness, TapSteadiness.steady);
  });

  test('comparison sentences: closer, similar, looser, not comparable', () {
    final tight = _m([0, 5, -5, 0]);
    final loose = _m([-50, 40, -30, 60]);
    final none = _m([10]);
    expect(comparisonFor(loose, tight), FirstMinutesCopy.compareCloser);
    expect(comparisonFor(tight, loose), FirstMinutesCopy.compareLooser);
    expect(comparisonFor(tight, tight), FirstMinutesCopy.compareSimilar);
    expect(comparisonFor(none, tight), FirstMinutesCopy.compareNone);
    expect(comparisonFor(tight, none), FirstMinutesCopy.compareNone);
  });

  test('no user sentence says wrong, in English or Turkish', () {
    for (final c in FirstMinutesCopy.all) {
      expect(c.$1.toLowerCase(), isNot(contains('wrong')), reason: c.$1);
      expect(c.$2.toLowerCase(), isNot(contains('yanlış')), reason: c.$2);
      expect(c.$1.toLowerCase(), isNot(contains('incorrect')));
    }
  });

  test('every sentence has an id and all 14 catalogs carry it', () {
    const tags = [
      'ar',
      'de',
      'en',
      'es-419',
      'fr',
      'hi',
      'id',
      'it',
      'ja',
      'ko',
      'pl',
      'pt-BR',
      'tr',
      'zh-Hans',
    ];
    final catalogs = {
      for (final t in tags)
        t:
            (jsonDecode(File('assets/l10n/$t.json').readAsStringSync())
                    as Map<String, dynamic>)['messages']
                as Map<String, dynamic>,
    };
    final holders = RegExp(r'\{\w+\}');
    for (final c in FirstMinutesCopy.all) {
      final id = appMessageIds[c];
      expect(id, isNotNull, reason: c.$1);
      for (final t in tags) {
        final text = catalogs[t]![id] as String?;
        expect(text, isNotNull, reason: '$t lacks ${c.$1}');
        expect(text!.trim(), isNotEmpty);
        expect(
          holders.allMatches(text).map((m) => m[0]).toList(),
          holders.allMatches(c.$1).map((m) => m[0]).toList(),
          reason: '$t placeholders for ${c.$1}',
        );
      }
    }
  });
}
