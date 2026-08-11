import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/cue_text.dart';
import 'package:ostinato_posture/ostinato_posture.dart';
/// Varyant rotasyonu — O-062, tavan O-088'de 6→14 tamamlandı.
///
/// **Neden ayrı bir test:** varyant EKLEMEK, rotasyonun ÇALIŞTIĞINI
/// kanıtlamaz. Katalogda cümleler durup çözücü hep ilkini döndürebilirdi ve
/// `validate_observation_cues.py` yine yeşil kalırdı (o kapı içeriği
/// kolluyor, DAVRANIŞI değil). Katalog boyutu burada ELLE YAZILMAZ, golden
/// dosyadan TÜRETİLİR — sabit "6" (ya da "14") yazmak, O-088'in kapattığı
/// aynı hastalığı bu dosyada yeniden açardı.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('round-robin: ardışık çözümler FARKLI cümle verir', () async {
    final CueTextResolver r = await CueTextResolver.load();
    const ObservationCue cue = ObservationCue(
        templateId: 'OBS_TRUNK_OUTSIDE_RANGE',
        teacherCount: 7, sourceClass: 'guitar teachers',
        thresholdDeg: 14.0, measuredDeg: 21.0);

    final Map<String, dynamic> golden = json.decode(File(
            'config/observation-cue-templates.golden.json')
        .readAsStringSync()) as Map<String, dynamic>;
    final int variantCount = ((golden['templates']
            as Map<String, dynamic>)['OBS_TRUNK_OUTSIDE_RANGE']
        as Map<String, dynamic>)['variants'].length as int;

    // Ölçülen sayı: en uzun işaretli ders 7 dk → ~13 ateşleme
    // (O-032/O-035 canlı periyodu 31,68sn) — bu SABİT kalır, katalog
    // boyutundan bağımsız bir GERÇEKLİK ölçümüdür.
    const int firings = 13;
    final List<String> seen = <String>[for (int i = 0; i < firings; i++) r.resolve(cue)];

    final int expectedDistinct = firings <= variantCount ? firings : variantCount;
    expect(seen.toSet().length, expectedDistinct,
        reason: '$firings ateşlemede (katalog=$variantCount) '
            '$expectedDistinct farklı cümle görülmeli');
    expect(seen[0] == seen[1], isFalse, reason: 'ardışık ikisi AYNI olmamalı');

    // Wrap-around'ı bağımsız doğrula: TAM `variantCount` çözüm sonra aynı
    // cümleye dönmeli — başlangıç noktasından bağımsız (döngü kapalı).
    final List<String> wrap =
        <String>[for (int i = 0; i < variantCount + 1; i++) r.resolve(cue)];
    expect(wrap[0], wrap[variantCount],
        reason: 'döngü $variantCount da başa sarmalı');

    final int maxRepeat =
        firings <= variantCount ? 1 : (firings / variantCount).ceil();
    final Map<String, int> n = <String, int>{};
    for (final String s in seen) { n[s] = (n[s] ?? 0) + 1; }
    expect(n.values.reduce((a, b) => a > b ? a : b), lessThanOrEqualTo(maxRepeat),
        reason: 'en kötü derste bir cümle en çok $maxRepeat kez tekrarlamalı '
            '($firings ateşleme / $variantCount varyant)');
  });
}
