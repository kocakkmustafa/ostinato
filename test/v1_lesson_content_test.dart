import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/curriculum/v1_lesson.dart';

/// Every v1 lesson source file parses with the strict model. Plan-row ties
/// (title, codes, fallback, references) are checked by
/// tool/curriculum_lint.py --check.
void main() {
  final files =
      Directory('content/v1')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  test('content/v1 has lesson files', () {
    expect(files, isNotEmpty);
  });

  for (final file in files) {
    test('parses ${file.path}', () {
      final lesson = V1Lesson.fromJson(jsonDecode(file.readAsStringSync()));
      final name = file.uri.pathSegments.last;
      expect(name, '${lesson.id}.json');
      expect(file.parent.uri.pathSegments.reversed.elementAt(1), lesson.course);
    });
  }

  group('rejects', () {
    late Map<String, dynamic> base;
    setUp(() {
      base =
          jsonDecode(
                File('content/v1/gtr/gtr-s1-m02-02.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
    });

    void rejects(void Function(Map<String, dynamic> m) edit) {
      final m = jsonDecode(jsonEncode(base)) as Map<String, dynamic>;
      edit(m);
      expect(() => V1Lesson.fromJson(m), throwsFormatException);
    }

    test('an unknown key', () => rejects((m) => m['note'] = 'x'));
    test('a missing translation', () {
      rejects((m) => (m['goal'] as Map).remove('tr'));
    });
    test('a fallback that does not follow the measurement', () {
      rejects((m) => m['fallback'] = 'held');
    });
    test('A0 on a microphone lesson', () {
      rejects((m) => (m['practice'] as Map)['engineSteps'] = ['A0']);
    });
    test('a D lesson without a drill', () {
      rejects((m) => (m['practice'] as Map)['measurement'] = ['D', 'M']);
    });
    test('a tempo ladder that goes down', () {
      rejects(
        (m) => (m['practice'] as Map)['tempo'] = {'open': 60, 'target': 50},
      );
    });
    test('safety without the course-wide Ç', () {
      rejects((m) => m['safety'] = ['G1']);
    });
    test('a recorded reference', () {
      rejects((m) => (m['referenceAudio'] as Map)['kinds'] = ['REC']);
    });
  });
}
