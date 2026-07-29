import 'dart:convert';
import 'dart:io';

import 'package:motion_core/motion_core.dart';

/// Ailenin İLK ÇALGI REFERANSI (M-F-98 talimatı, M-O-46 yanıtı).
///
/// Karar: eklem-başına sapma tablosu `trunk_tilt`i (0,6-1,0°, üç bağımsız
/// eğitmenin neredeyse mükemmel uzlaşısı) kol-zincirinden (8/9 eklem,
/// 90-122°'ye varan sapma) ayırdı. Koordinatörün ekseni: SAYI/anatomik-sınıf
/// DEĞİL, ürün-skorlama ilgisi — postür referansının skorladığı gövde
/// duruşudur, kol çalgıyı TUTUYOR (işlevsel/stil, postür değil). Bu B4'ün
/// "çalgı-bağımsız kol referansı reddi" bulgusuyla birebir tutarlı.
///
/// clusterToleranceDeg=22: M-F-51 stance emsalinin oranı — ölçülen max
/// take-medyanı (18,1°, 0.8.4/J-056-sonrası) + ~%20, stil-ağır statik
/// sınıf gerekçesiyle. Kaba "aynı poz mu" kapısı; asıl yetki eklemde.
/// M-F-143: ÇALGI-PARAMETRELİ. Üç çalgı da AYNI beyanlı kapıdan geçer —
/// ayrı kopya yazmak, üç ayrı gerekçenin sessizce ayrışması demekti
/// (M-O-39'un kanonik-vs-kopya dersi, bu sefer önceden).
const _techniqueByInstrument = {
  'guitar': 'guitar_posture_setup',
  'voice': 'sustained_note_drill',
  'piano': 'five_finger_drill',
};

void main(List<String> args) async {
  final want = args.isEmpty ? 'guitar' : args.first;
  final technique = _techniqueByInstrument[want];
  if (technique == null) {
    stderr.writeln('kullanım: build_guitar_reference.dart <guitar|voice|piano>');
    exit(64);
  }
  final manifestFile =
      File('${Platform.environment['HOME']}/motion-harvest/ostinato/hold-windows-$want.json');
  final manifest = jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
  final sources = (manifest['sources'] as List).cast<Map<String, dynamic>>();
  final lib = Directory('${Platform.environment['HOME']}/motion-harvest/ostinato/landmarks');

  final fixturesById = <String, Fixture>{};
  for (final row in sources) {
    if (row['found'] != true) continue;
    final id = row['videoId'] as String;
    final f = File('${lib.path}/$id.full.json');
    final doc = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    final fx = Fixture.fromJson(doc);
    final tStart = (row['tStartS'] as num).toDouble();
    final tEnd = (row['tEndS'] as num).toDouble();
    final windowFrames =
        fx.frames.where((pf) => pf.tSeconds >= tStart && pf.tSeconds < tEnd).toList();
    fixturesById[id] = Fixture(
      app: fx.app, technique: fx.technique, frames: windowFrames,
      schemaVersion: fx.schemaVersion, modelVersion: fx.modelVersion,
      recordingMeta: fx.recordingMeta, labels: fx.labels, provenance: fx.provenance,
    );
  }
  stdout.writeln('windowRule: hold_isolator@57b3ccd, scope=upperBody, '
      'defaultMaxDrift=${manifest['defaultMaxDrift']}, fallbackMaxDrift=${manifest['fallbackMaxDrift']}');
  stdout.writeln('kaynaklar: ${fixturesById.keys.join(", ")}');

  // M-F-143: kapı-eklem-kümesi artık BEYAN EDİLEN parametre. 22° özel-barı
  // ÖLDÜ — o bar aslında "kol gürültüsüne ne kadar tahammül edelim"
  // sorusuna verilmiş bir cevaptı (M-O-56 dördüncü sınıf teşhisi). Kapı
  // artık ÜRÜNÜN SKORLADIĞI eklemde anlaşma arıyor ve bar VARSAYILAN 14'e
  // geri döndü: trunk_tilt sapmaları 0,3-5,9° ölçüldüğü için geçmesi
  // gereken bu. `gateBasis` ZORUNLU — daraltma gerekçesiz yapılamaz.
  const cli = ReferenceCli(
    specs: StandardJoints.upperBody,
    gateJoints: ['trunk_tilt'],
    gateBasis: 'M-O-47/M-F-98 eklem-yetkisi kararı: postür referansının '
        'SKORLADIĞI metrik trunk_tilt; kol zinciri çalgıyı TUTUYOR '
        '(işlevsel/stil) ve ÖLÇÜLEREK coached_only ilan edildi. M-O-56: '
        'tam-küme kapısı 9 eklemin 8i kol olduğu için medyanı kollarla '
        'belirliyor ve SKORLANAN metriği mükemmel uyan take leri reddediyor '
        '(Rpalo0sbpj4: trunk 0,3° / kol-medyanı 42,9°). Kapı, urunun '
        'tukettigi kumede anlasma aramali.',
  );

  final artifact = cli.buildArtifact(
    technique: technique,
    fixturesById: fixturesById,
  );

  // M-F-98: eklem-yetkisi ve dürüstlük beyanları — üretici bu artefaktı
  // KENDİSİ etiketliyor, tüketici (config) buradan devralır.
  final result = artifact['result'] as Map<String, dynamic>;
  artifact['jointAuthority'] = <String, dynamic>{
    '_why': 'M-F-98 (M-O-46 yanıtı): postür referansının skorladığı gövde '
        'duruşudur (trunk_tilt, taraf-bağımsız — mirrorConfident=false/kural-7 '
        'çekincesi bu eklemi HİÇ etkilemiyor). Kol zinciri çalgıyı TUTUYOR — '
        'işlevsel/stil, postür değil; B4 "çalgı-bağımsız kol referansı reddi" '
        'bulgusuyla tutarlı.',
    'scored': ['trunk_tilt'],
    'coachedOnly': [
      'left_shoulder', 'right_shoulder', 'left_upper_arm', 'right_upper_arm',
      'left_elbow', 'right_elbow', 'left_forearm', 'right_forearm',
    ],
    'mirrorAmbiguityNote': 'mirrorConfident=false (gapMeasured=true, kural 7 — '
        'ölçülü ama kesin değil). Sol-taraf kol sayıları (özellikle left_elbow/'
        'left_forearm) sağdan 5-12× büyük çıkıyor; bu asimetri KISMEN aynalama '
        'belirsizliğinin artefaktı olabilir. coached_only olduğu için '
        'kullanıcıya PUAN vermiyor ama gösterim/koçlamada taraf-bazlı DEĞİL, '
        'birleşik-kol (sol+sağ) okuması önerilir.',
    'clusterToleranceDegBasis': 'M-F-143: 22° ÖZEL BARI KALDIRILDI, '
        'VARSAYILAN 14° kullanılıyor. Eski 22 gerekçesi (M-F-51 oranı, '
        'ölçülen max take-medyanı 18,1° + ~%20) aslında KOL gürültüsüne '
        'tahammül payıydı — çünkü kapı tüm-eklem medyanına bakıyordu. Kapı '
        'artık gateJoints=[trunk_tilt] ile ÜRÜNÜN SKORLADIĞI eklemde '
        'anlaşma arıyor, o yüzden özel bara gerek kalmadı.',
  };

  final outDir = Directory(
      '/Users/mustafakaankocak/Documents/YULAlab-AI/ventures/ostinato/app/config/references');
  outDir.createSync(recursive: true);
  final outFile = File('${outDir.path}/$want-posture-setup.v1.json');
  outFile.writeAsStringSync(
      const JsonEncoder.withIndent(' ').convert(artifact) + '\n');

  stdout.writeln('\n✅ ARTEFAKT ÜRETİLDİ: ${outFile.path}');
  stdout.writeln('  measurementProvenance : ${artifact['measurementProvenance']}');
  stdout.writeln('  contributingTakes     : ${result['contributingTakes']}');
  stdout.writeln('  distinctSources       : ${result['distinctSources']}');
  stdout.writeln('  excludedOutlierIds    : ${result['excludedOutlierIds']}');
  stdout.writeln('  mirrorConfident       : ${result['mirrorConfident']} '
      '(gapMeasured: ${result['mirrorGapMeasured']})');
  stdout.writeln('  meanAgreement         : ${result['meanAgreement']}');
  stdout.writeln('  unreliableJoints      : ${result['unreliableJoints']}');
}
