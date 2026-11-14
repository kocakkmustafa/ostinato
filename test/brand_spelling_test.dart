// BRAND-01c (founder, 2026-11-14): user-facing text spells the brand
// "Yula Lab". Files, repos, domains and package names stay as they are.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

List<String> _offenders(Directory dir, bool Function(String path) wanted) => [
  for (final e in dir.listSync(recursive: true, followLinks: false))
    if (e is File &&
        wanted(e.path) &&
        e.readAsStringSync().contains('YULA Lab'))
      e.path,
];

void main() {
  test('no user-facing string spells the brand "YULA Lab"', () {
    final bad = [
      ..._offenders(Directory('assets/l10n'), (p) => p.endsWith('.json')),
      ..._offenders(Directory('lib'), (p) => p.endsWith('.dart')),
    ];
    expect(bad, isEmpty, reason: 'write "Yula Lab" in user-facing text');
  });

  test('the scan sees a planted bad spelling (not vacuous)', () {
    final tmp = Directory.systemTemp.createTempSync('brand_scan');
    addTearDown(() => tmp.deleteSync(recursive: true));
    File('${tmp.path}/x.json').writeAsStringSync('{"a":"by YULA Lab"}');
    expect(_offenders(tmp, (p) => p.endsWith('.json')), hasLength(1));
    expect(Directory('assets/l10n').listSync(), isNotEmpty);
  });
}
