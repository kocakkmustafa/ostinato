import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/app_message_ids.dart';
import 'package:ostinato/app/app_translation_catalog.dart';
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

  test('v1 home and FK2 copy are in all 14 catalogs', () {
    for (final tag in supportedLanguageTags) {
      final messages =
          (jsonDecode(File('assets/l10n/$tag.json').readAsStringSync())
                  as Map<String, dynamic>)['messages']
              as Map<String, dynamic>;
      for (final pair in [...V1HomeCopy.all, ...OwnRecordingCopy.all]) {
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
}
