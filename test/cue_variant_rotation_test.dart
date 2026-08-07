import 'package:flutter_test/flutter_test.dart';
import 'package:ostinato/app/cue_text.dart';
import 'package:ostinato_posture/ostinato_posture.dart';
/// Varyant rotasyonu — O-062.
///
/// **Neden ayrı bir test:** varyant EKLEMEK, rotasyonun ÇALIŞTIĞINI
/// kanıtlamaz. Katalogda altı cümle durup çözücü hep ilkini döndürebilirdi ve
/// `validate_observation_cues.py` yine yeşil kalırdı (o kapı içeriği
/// kolluyor, DAVRANIŞI değil). Ölçülen sayı burada: en uzun işaretli ders
/// 7 dk → ~13 ateşleme (O-032/O-035 canlı periyodu 31,68sn).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('round-robin: ardışık çözümler FARKLI cümle verir', () async {
    final CueTextResolver r = await CueTextResolver.load();
    const ObservationCue cue = ObservationCue(
        templateId: 'OBS_TRUNK_OUTSIDE_RANGE',
        teacherCount: 7, sourceClass: 'guitar teachers',
        thresholdDeg: 14.0, measuredDeg: 21.0);
    final List<String> seen = <String>[for (int i = 0; i < 13; i++) r.resolve(cue)];
    expect(seen.toSet().length, 6, reason: '6 varyant dönmeli');
    expect(seen[0], seen[6], reason: 'döngü 6da başa sarmalı');
    expect(seen[0] == seen[1], isFalse, reason: 'ardışık ikisi AYNI olmamalı');
    // 13 ateşleme (en kötü ders) → her cümle en çok 3 kez
    final Map<String,int> n = <String,int>{};
    for (final String s in seen) { n[s] = (n[s] ?? 0) + 1; }
    expect(n.values.reduce((a,b)=>a>b?a:b), lessThanOrEqualTo(3),
        reason: 'en kötü derste bir cümle 3ten fazla tekrarlamamalı');
  });
}
