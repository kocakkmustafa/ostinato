import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:ostinato_posture/ostinato_posture.dart';

/// Gözlem işaretinin CÜMLESİ burada kurulur — ve YALNIZ burada.
///
/// M-F-232 şart 2 (şablon-tek-yol): motor VERİ üretir, app GOLDEN katalogdaki
/// şablonu doldurur. Şablon `config/observation-cue-templates.golden.json`den
/// gelir; bu dosya donmuştur ve `validate_observation_cues.py` onu yasak-dil
/// taramasından geçirir (emir kipi · sebep-sonuç · beden-sonucu).
///
/// Buraya bir `'You are slouching'` string'i yazmak, o kapının tamamını
/// devre dışı bırakmanın en kolay yoludur: metin uygulamada doğar, golden'a
/// hiç uğramaz, kimse bakmaz. Bu yüzden burada TEK iş yuva doldurmaktır.
final class CueTextResolver {
  CueTextResolver._(this._templates);

  final Map<String, String> _templates;

  static Future<CueTextResolver> load() async {
    final String raw = await rootBundle
        .loadString('config/observation-cue-templates.golden.json');
    final Map<String, dynamic> doc = jsonDecode(raw) as Map<String, dynamic>;
    final Map<String, dynamic> tpl = doc['templates'] as Map<String, dynamic>;
    return CueTextResolver._(<String, String>{
      for (final MapEntry<String, dynamic> e in tpl.entries)
        e.key: (e.value as Map<String, dynamic>)['text'] as String,
    });
  }

  /// Şablonu yuvalarla doldurur. Bilinmeyen şablon SESSİZCE boş dönmez —
  /// fırlatır: eksik bir şablon, kullanıcıya yarım cümle göstermekten iyidir.
  String resolve(ObservationCue cue) {
    final String? template = _templates[cue.templateId];
    if (template == null) {
      throw StateError(
          'golden katalogda "${cue.templateId}" şablonu YOK — yüzey, motorun '
          'ürettiği bir işareti gösteremiyor');
    }
    String out = template;
    cue.slots.forEach((String k, String v) {
      out = out.replaceAll('{$k}', v);
    });
    return out;
  }
}
