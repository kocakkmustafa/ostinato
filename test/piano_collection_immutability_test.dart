import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/piano_beginner.dart';

Map<String, dynamic> _source() =>
    jsonDecode(File(pianoAsset).readAsStringSync()) as Map<String, dynamic>;

void main() {
  final lessonMutations = <String, void Function(PianoCourse)>{
    'clear': (course) => course.lessons.clear(),
    'remove': (course) => course.lessons.removeAt(0),
    'append': (course) => course.lessons.add(course.lessons.first),
    'reorder': (course) => course.lessons[0] = course.lessons[1],
  };
  for (final entry in lessonMutations.entries) {
    test('validated piano lessons reject ${entry.key}', () {
      final course = PianoCourse.fromJson(_source());
      final ids = course.lessons.map((lesson) => lesson.id).toList();
      expect(() => entry.value(course), throwsUnsupportedError);
      expect(course.lessons.map((lesson) => lesson.id), ids);
      expect(course.lessons.length, 25);
    });
  }

  final sectionMutations = <String, void Function(PianoLesson)>{
    'clear': (lesson) => lesson.sections.clear(),
    'remove': (lesson) => lesson.sections.removeAt(0),
    'append': (lesson) => lesson.sections.add(lesson.sections.first),
    'reorder': (lesson) => lesson.sections[0] = lesson.sections[1],
  };
  for (final entry in sectionMutations.entries) {
    test('validated piano sections reject ${entry.key}', () {
      final course = PianoCourse.fromJson(_source());
      for (final lesson in course.lessons) {
        final sections = List.of(lesson.sections);
        expect(() => entry.value(lesson), throwsUnsupportedError);
        expect(lesson.sections, sections);
        expect(lesson.sections.length, 4);
      }
    });
  }

  test(
    'caller JSON list and translation mutations cannot change decoded content',
    () {
      final source = _source();
      final rawLessons = source['lessons'] as List;
      final rawFirst = rawLessons.first as Map<String, dynamic>;
      final course = PianoCourse.fromJson(source);
      final ids = course.lessons.map((lesson) => lesson.id).toList();
      final sectionCopies = [
        for (final section in course.lessons.first.sections)
          [section.en, section.tr],
      ];
      for (final key in ['teach', 'practice', 'check', 'recover']) {
        final copy = rawFirst[key] as Map<String, dynamic>;
        copy['en'] = 'Changed caller text';
        copy['tr'] = 'Degistirilmis cagiran metni';
      }
      rawLessons[0] = rawLessons[1];
      rawLessons.clear();
      expect(course.lessons.map((lesson) => lesson.id), ids);
      expect([
        for (final section in course.lessons.first.sections)
          [section.en, section.tr],
      ], sectionCopies);
    },
  );
}
