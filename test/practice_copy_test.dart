// Pratik döngüsü metinleri: kaynak EN/TR çiftleri çeviri hattına giden
// listeyle (docs/practice/copy/practice-loop.copy.json) eşit kalır; hiçbir
// metin "yanlış / wrong" demez.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _lit = r'''(?:'((?:[^'\\]|\\.)*)'|"((?:[^"\\]|\\.)*)")''';
final _call = RegExp(
  r'localized\(\s*context,\s*' + _lit + r'\s*,\s*' + _lit,
  dotAll: true,
);

String _un(String s) =>
    s.replaceAllMapped(RegExp(r'\\(.)'), (m) => m.group(1)!);

Set<(String, String)> _pairs(String source) => {
  for (final m in _call.allMatches(source))
    (_un(m.group(1) ?? m.group(2)!), _un(m.group(3) ?? m.group(4)!)),
};

void main() {
  test('practice copy list matches the source pairs', () {
    final source = <(String, String)>{};
    for (final f in Directory('lib/app/practice/loop').listSync()) {
      if (f is File && f.path.endsWith('.dart')) {
        source.addAll(_pairs(f.readAsStringSync()));
      }
    }
    source.addAll(
      _pairs(
        File('lib/app/screens/guitar_journey_screen.dart').readAsStringSync(),
      ).where(
        (p) =>
            p.$1 == 'Measured practice' ||
            p.$1 == 'Open measured practice' ||
            p.$1.startsWith('Play a lesson with the click'),
      ),
    );
    final listed = {
      for (final p
          in (jsonDecode(
                    File(
                      'docs/practice/copy/practice-loop.copy.json',
                    ).readAsStringSync(),
                  )
                  as Map<String, dynamic>)['pairs']
              as List<dynamic>)
        ((p as Map<String, dynamic>)['en'] as String, p['tr'] as String),
    };
    expect(listed, source);
    for (final (en, tr) in source) {
      expect(en.toLowerCase(), isNot(contains('wrong')));
      expect(tr.toLowerCase(), isNot(contains('yanlış')));
    }
  });
}
