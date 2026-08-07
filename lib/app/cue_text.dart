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

  /// Şablon kimliği → VARYANT listesi. Tek varyantlı bir şablon da burada
  /// tek elemanlı listedir; çağıran taraf farkı görmez.
  final Map<String, List<String>> _templates;

  /// Şablon başına round-robin sayacı — RASTGELE DEĞİL.
  ///
  /// Rastgelelik burada iki kez yanlış olurdu: (1) aynı varyant arka arkaya
  /// gelebilir, yani çözdüğü sorunu çözmez; (2) bu yüzeyin kanıtı
  /// deterministik testlere dayanıyor (`cue_cooldown_visibility_test`,
  /// 11 kanıt karesi) ve rastgele bir seçim onları ölçülemez kılardı.
  final Map<String, int> _next = <String, int>{};

  static Future<CueTextResolver> load() async {
    final String raw = await rootBundle
        .loadString('config/observation-cue-templates.golden.json');
    final Map<String, dynamic> doc = jsonDecode(raw) as Map<String, dynamic>;
    final Map<String, dynamic> tpl = doc['templates'] as Map<String, dynamic>;
    return CueTextResolver._(<String, List<String>>{
      for (final MapEntry<String, dynamic> e in tpl.entries)
        e.key: <String>[
          // `variants` varsa o, yoksa tek elemanlı `text`. Geriye-uyum:
          // varyantsız bir şablon eskisi gibi çalışır.
          ...((e.value as Map<String, dynamic>)['variants'] as List<dynamic>? ??
                  <dynamic>[(e.value as Map<String, dynamic>)['text']])
              .cast<String>(),
        ],
    });
  }

  /// Şablonu yuvalarla doldurur. Bilinmeyen şablon SESSİZCE boş dönmez —
  /// fırlatır: eksik bir şablon, kullanıcıya yarım cümle göstermekten iyidir.
  String resolve(ObservationCue cue) {
    final List<String>? variants = _templates[cue.templateId];
    if (variants == null || variants.isEmpty) {
      throw StateError(
          'golden katalogda "${cue.templateId}" şablonu YOK — yüzey, motorun '
          'ürettiği bir işareti gösteremiyor');
    }
    // O-062: ÖLÇÜLDÜ — gözlem işareti ~31,68sn periyotla ateşleniyor
    // (O-032/O-035 canlı ölçümü) ve en uzun işaretli ders 7 dk, yani ~13
    // ateşleme. Tek varyantla aynı cümle bir derste 13 kez okunuyordu.
    // NADİR GÖRÜNEN bir öğe, SIK TEKRARLANAN bir cümle olabilir.
    final int i = _next[cue.templateId] ?? 0;
    _next[cue.templateId] = (i + 1) % variants.length;
    String out = variants[i];
    cue.slots.forEach((String k, String v) {
      out = out.replaceAll('{$k}', v);
    });
    return out;
  }
}
