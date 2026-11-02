import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/app_message_ids.dart';
import 'package:ostinato/app/app_translation_catalog.dart';
import 'package:ostinato/app/practice/display/practice_display_copy.dart';
import 'package:ostinato/app/practice/loop/practice_rhythm_copy.dart';
import 'package:ostinato/app/practice/loop/v1_course_copy.dart';
import 'package:ostinato/app/practice/loop/v1_paywall_copy.dart';
import 'package:ostinato/app/practice/loop/tempo_ladder_copy.dart';
import 'package:ostinato/app/practice/own_recording/own_recording_copy.dart';
import 'package:ostinato/app/retention/retention_copy.dart';
import 'package:ostinato/app/screens/v1_home_copy.dart';
import 'package:ostinato/app/tuner/tuner_copy.dart';
import 'package:ostinato/app/ui_copy.dart';

/// New UI copy lives in Dart (`*_copy.dart`) and in a JSON source under
/// `content/ui/` that `tool/build_message_ids.py --pending content/ui`
/// reads. Both must list the same pairs; no copy may say "wrong".
void main() {
  final catalogs = <String, List<UiCopy>>{
    'content/ui/retention.json': RetentionCopy.all,
    'content/ui/tuner.json': TunerCopy.all,
    'content/ui/v1-home.json': V1HomeCopy.all,
    'content/ui/own-recording.json': OwnRecordingCopy.all,
    'content/ui/v1-course.json': V1CourseCopy.all,
    'content/ui/v1-paywall.json': V1PaywallCopy.all,
    'content/ui/practice-display.json': PracticeDisplayCopy.all,
    'content/ui/tempo-ladder.json': TempoLadderCopy.all,
    'content/ui/practice-rhythm.json': RhythmCopy.all,
  };

  for (final entry in catalogs.entries) {
    test('${entry.key} matches its Dart copy', () {
      final json =
          jsonDecode(File(entry.key).readAsStringSync())
              as Map<String, dynamic>;
      final pairs = [
        for (final m in json['messages'] as List<dynamic>)
          ((m as Map)['en'] as String, m['tr'] as String),
      ];
      expect(pairs.toSet(), entry.value.toSet());
      expect(pairs, hasLength(entry.value.length));
    });

    test('${entry.key} never says wrong', () {
      final banned = RegExp(r'\bwrong\b|yanlış', caseSensitive: false);
      for (final (en, tr) in entry.value) {
        expect(banned.hasMatch(en), isFalse, reason: en);
        expect(banned.hasMatch(tr), isFalse, reason: tr);
      }
    });

    test('${entry.key} keeps the same placeholders in EN and TR', () {
      final placeholder = RegExp(r'\{(v\d+)\}');
      Set<String> names(String s) =>
          placeholder.allMatches(s).map((m) => m[1]!).toSet();
      for (final (en, tr) in entry.value) {
        expect(names(tr), names(en), reason: en);
      }
    });
  }

  test('v1 home, FK2, course, FK4 and FK6 copy are in all 14 catalogs', () {
    for (final tag in supportedLanguageTags) {
      final messages =
          (jsonDecode(File('assets/l10n/$tag.json').readAsStringSync())
                  as Map<String, dynamic>)['messages']
              as Map<String, dynamic>;
      for (final pair in [
        ...V1HomeCopy.all,
        ...OwnRecordingCopy.all,
        ...V1CourseCopy.all,
        ...V1PaywallCopy.all,
        ...PracticeDisplayCopy.all,
        ...TempoLadderCopy.all,
        ...RhythmCopy.all,
      ]) {
        final id = appMessageIds[pair];
        expect(id, isNotNull, reason: pair.$1);
        expect(messages[id], isA<String>(), reason: '$tag ${pair.$1}');
        final placeholders = RegExp(r'\{v\d+\}');
        expect(
          placeholders.allMatches(messages[id] as String).length,
          placeholders.allMatches(pair.$1).length,
          reason: '$tag ${pair.$1}',
        );
      }
    }
  });

  group('translation coverage (backlog closed 2026-11-01)', () {
    Map<String, dynamic> catalog(String tag) =>
        (jsonDecode(File('assets/l10n/$tag.json').readAsStringSync())
                as Map<String, dynamic>)['messages']
            as Map<String, dynamic>;

    List<UiCopy> sourcePairs() {
      final pairs = <UiCopy>{};
      void walk(Object? v) {
        if (v is Map) {
          if (v['en'] is String && v['tr'] is String) {
            pairs.add((v['en'] as String, v['tr'] as String));
          }
          v.values.forEach(walk);
        } else if (v is List) {
          v.forEach(walk);
        }
      }

      for (final root in ['content/v1', 'content/ui', 'docs/practice/copy']) {
        for (final f in Directory(root).listSync(recursive: true)) {
          if (f is File && f.path.endsWith('.json')) {
            walk(jsonDecode(f.readAsStringSync()));
          }
        }
      }
      return pairs.toList();
    }

    test('all 14 catalogs have the same keys as the id table', () {
      final ids = appMessageIds.values.toSet();
      for (final tag in supportedLanguageTags) {
        final keys = catalog(tag).keys.toSet();
        expect(ids.difference(keys), isEmpty, reason: '$tag lacks ids');
        expect(keys.difference(ids), isEmpty, reason: '$tag has stray keys');
      }
    });

    test('every lesson and UI source pair is translated in 14 languages, '
        'with the same placeholders', () {
      final pairs = sourcePairs();
      expect(pairs.length, greaterThan(2000));
      final placeholder = RegExp(r'\{\w+\}');
      List<String> names(String s) =>
          placeholder.allMatches(s).map((m) => m[0]!).toList()..sort();
      final catalogs = {
        for (final tag in supportedLanguageTags) tag: catalog(tag),
      };
      for (final pair in pairs) {
        final id = appMessageIds[pair];
        expect(id, isNotNull, reason: 'no id: ${pair.$1}');
        for (final MapEntry(key: tag, value: messages) in catalogs.entries) {
          final text = messages[id];
          expect(text, isA<String>(), reason: '$tag $id');
          expect(
            names(text as String),
            names(pair.$1),
            reason: '$tag $id placeholders',
          );
        }
      }
    });
  });
}
