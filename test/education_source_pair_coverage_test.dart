// Disk-source contract only: message membership does not prove translation meaning.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/app_message_ids.dart';
import 'package:ostinato/app/app_translation_catalog.dart';

const _courseAssets = <String>[
  'assets/content/guitar_journey.v1.json',
  'assets/content/piano_beginner.v1.json',
  'assets/content/vocal_beginner.v1.json',
  'assets/content/ukulele_beginner.v1.json',
  'assets/content/bass_beginner.v1.json',
];

final class _SourcePair {
  const _SourcePair(this.source, this.lessonId, this.pointer, this.en, this.tr);
  final String source;
  final String? lessonId;
  final String pointer;
  final String en;
  final String tr;

  String get location => '$source ${lessonId ?? "course"} $pointer';
}

Iterable<_SourcePair> _pairs(
  Object? value, {
  required String source,
  String pointer = '',
  String? lessonId,
}) sync* {
  if (value is Map<String, dynamic>) {
    final currentLesson =
        value.containsKey('teach') || value.containsKey('teachingSteps')
        ? value['id'] as String?
        : lessonId;
    if (value.containsKey('en') || value.containsKey('tr')) {
      final en = value['en'];
      final tr = value['tr'];
      if (en is! String || tr is! String || en.trim().isEmpty || tr.trim().isEmpty) {
        throw FormatException('Incomplete EN/TR pair: $source $currentLesson $pointer');
      }
      yield _SourcePair(source, currentLesson, pointer, en, tr);
    }
    for (final entry in value.entries) {
      final key = entry.key.replaceAll('~', '~0').replaceAll('/', '~1');
      yield* _pairs(
        entry.value,
        source: source,
        pointer: '$pointer/$key',
        lessonId: currentLesson,
      );
    }
  } else if (value is List) {
    for (var i = 0; i < value.length; i++) {
      yield* _pairs(
        value[i],
        source: source,
        pointer: '$pointer/$i',
        lessonId: lessonId,
      );
    }
  }
}

void main() {
  test('every authored five-course pair has an ID and all presentation catalogs', () {
    final catalogs = <String, AppTranslations>{
      for (final tag in supportedLanguageTags)
        tag: AppTranslations.fromJson(
          localeForLanguageTag(tag),
          jsonDecode(File('assets/l10n/$tag.json').readAsStringSync()),
        ),
    };
    final failures = <String>[];
    for (final path in _courseAssets) {
      final source = jsonDecode(File(path).readAsStringSync());
      final pairs = _pairs(source, source: path).toList();
      expect(pairs, isNotEmpty, reason: path);
      for (final pair in pairs) {
        final id = appMessageIds[(pair.en, pair.tr)];
        if (id == null) {
          failures.add('${pair.location}: no exact source-pair message ID');
          continue;
        }
        for (final entry in catalogs.entries) {
          if (!entry.value.messages.containsKey(id)) {
            failures.add('${pair.location}: $id missing in ${entry.key}');
          }
        }
      }
    }
    expect(failures, isEmpty, reason: failures.join('\n'));
  });

  test('a newly authored unmapped lesson pair is discovered with its lesson ID', () {
    final path = _courseAssets[1];
    final source = jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
    final first = (source['lessons'] as List).first as Map<String, dynamic>;
    first['teach'] = <String, String>{
      'en': 'EDUCATION COVERAGE NEGATIVE CONTROL: new unmapped instruction.',
      'tr': 'EĞİTİM KAPSAMI NEGATİF KONTROL: yeni haritalanmamış yönerge.',
    };
    final missing = _pairs(source, source: path)
        .where((pair) => !appMessageIds.containsKey((pair.en, pair.tr)))
        .toList();
    expect(missing, hasLength(1));
    expect(missing.single.lessonId, first['id']);
    expect(missing.single.pointer, '/lessons/0/teach');
    // The modified object remains in memory; no canonical source is written.
  });

  test('the vocal contour legend keeps quarter-note beats in every catalog', () {
    const en = 'Original contour in quarter-note beats. M = your comfortable centre; L/H = nearby lower/higher, not quieter/louder. Each letter starts a new sound. R = counted silence. No fixed note or interval.';
    const tr = 'Özgün dörtlük vuruş çizgisi. M = rahat merkezin; L/H = yakın pes/tiz; daha hafif/gür demek değildir. Her harf yeni ses başlatır. R = sayılan sessizlik. Sabit nota veya aralık yok.';
    final id = appMessageIds[(en, tr)];
    expect(id, isNotNull);
    for (final tag in supportedLanguageTags) {
      final catalog = AppTranslations.fromJson(
        localeForLanguageTag(tag),
        jsonDecode(File('assets/l10n/$tag.json').readAsStringSync()),
      );
      expect(catalog.messages.containsKey(id), isTrue, reason: tag);
      expect(catalog.text(en, tr).trim(), isNotEmpty, reason: tag);
    }
  });
}
