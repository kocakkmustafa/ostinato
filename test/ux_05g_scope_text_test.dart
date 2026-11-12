// OST-UX-05g Faz E (D4 metin): the Ghost counter is account-wide (no lesson /
// section scope), so no Ghost surface text may imply "in this section / this
// lesson". tr/en literal check + root words in the 12 other languages.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/app_message_ids.dart';
import 'package:ostinato/app/stage/ghost_level_copy.dart';
import 'package:ostinato/app/stage/stage_copy.dart';

const _scope = <String, List<String>>{
  'en': ['section', 'unit', 'module', 'lesson', 'chapter', 'this part'],
  'tr': ['bölüm', 'ünite', 'modül', 'ders', 'bu kısım'],
  'de': ['abschnitt', 'einheit', 'modul', 'lektion', 'kapitel'],
  'es-419': ['sección', 'unidad', 'módulo', 'lección', 'capítulo'],
  'fr': ['section', 'unité', 'module', 'leçon', 'chapitre'],
  'it': ['sezione', 'unità', 'modulo', 'lezione', 'capitolo'],
  'pt-BR': ['seção', 'unidade', 'módulo', 'lição', 'capítulo'],
  'pl': ['sekcj', 'rozdzia', 'moduł', 'lekcj', 'jednostk'],
  'id': ['bagian', 'unit', 'modul', 'pelajaran', 'bab '],
  'ja': ['セクション', '章', 'モジュール', 'レッスン', '単元'],
  'ko': ['섹션', '단원', '모듈', '레슨', '챕터'],
  'zh-Hans': ['章节', '单元', '模块', '课'],
  'ar': ['قسم', 'وحدة', 'درس', 'فصل'],
  'hi': ['अनुभाग', 'इकाई', 'पाठ', 'मॉड्यूल', 'अध्याय'],
};

void main() {
  test('E: tarayici kontrolu: kapsam kokleri bilinen ifadeyi yakalar', () {
    expect(_scope.keys, hasLength(14));
    bool hits(String loc, String s) =>
        _scope[loc]!.any((r) => s.toLowerCase().contains(r));
    expect(hits('tr', 'Bu bölümde bir basamak yukarı'), isTrue);
    expect(hits('en', 'In this section try one step up'), isTrue);
    expect(hits('tr', 'Bir basamak yukarı denenebilir'), isFalse);
  });

  test('E: Hayalet yuzey metinleri (15 cift) 14 dilde bolum/ders kapsami '
      'ima etmez; Yardim satiri da', () {
    final pairs = <(String, String)>[...GhostLevelCopy.all, StageCopy.help];
    expect(pairs, hasLength(16));
    for (final c in pairs) {
      final id = appMessageIds[c];
      expect(id, isNotNull, reason: c.$1);
      for (final loc in _scope.keys) {
        final cat =
            (jsonDecode(File('assets/l10n/$loc.json').readAsStringSync())
                    as Map<String, dynamic>)['messages']
                as Map<String, dynamic>;
        final text = cat[id] as String?;
        expect(text, isNotNull, reason: '$loc ${c.$1}');
        final lower = text!.toLowerCase();
        for (final r in _scope[loc]!) {
          expect(lower.contains(r), isFalse, reason: '$loc "$text" kok $r');
        }
      }
    }
  });
}
