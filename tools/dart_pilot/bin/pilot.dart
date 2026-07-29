import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:motion_core/motion_core.dart';

/// B4 — açı-duyarlılık pilotu.
///
/// Soru (O-012): eğitmen videoları bizim standart açımızda çekilmiyor
/// (ölçtük: 0/9 sağ-ön-çapraz). O hâlde referans çıkarımı hangi metrikte
/// hangi açı sınıfından beslenebilir?
///
/// Yöntem: her videodan DURAĞAN bir pencere seç, eklem açılarını çıkar,
/// eğitmenler arası dağılımı ölç. Bu dağılım, `CanonicalReference`ın
/// toleransının kaynağıdır — "eğitmenlerin anlaşamadığı eklemde kullanıcıyı
/// cezalandırmak dürüstlük ihlali" kuralının sayısal hâli.
void main(List<String> args) {
  final dir = Directory('${Platform.environment['HOME']}/motion-harvest/ostinato/landmarks');
  var files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.json')).toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  // M-F-41: havuz ÇALGI-BAŞINA bölünür. İlk pilot karışık havuzda koştu ve
  // kol açıları 40-60° saçıldı — çünkü şan ayakta, piyano oturarak, gitar
  // kucakta çalınır. O saçılma "eğitmenler anlaşamıyor" değil "farklı şeyler
  // ölçüyoruz" demekti. Anlaşmazlık YAPISAL nedenliyse havuz bölünür,
  // tolerans uydurulmaz.
  final instFile = File('${Directory.current.path}/../../config/fixture-instrument-map.json');
  final instMap = instFile.existsSync()
      ? (jsonDecode(instFile.readAsStringSync()) as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, v as String))
      : <String, String>{};
  final want = args.isEmpty ? null : args.first;
  if (want != null) {
    files = files
        .where((f) => instMap[f.uri.pathSegments.last.split('.').first] == want)
        .toList();
    stdout.writeln('ÇALGI: $want');
  } else {
    stdout.writeln('ÇALGI: (karışık havuz — yalnız karşılaştırma için)');
  }
  if (files.length < 3) {
    stderr.writeln('en az 3 fixture gerekir, ${files.length} var');
    exit(1);
  }

  const extractor = JointAngleExtractor(specs: StandardJoints.upperBody);
  final takes = <ReferenceTake>[];
  final angleClassOf = <String, String>{};

  for (final f in files) {
    final doc = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    final id = f.uri.pathSegments.last.split('.').first;
    final frames = (doc['frames'] as List).cast<Map<String, dynamic>>();

    // Durağan pencere: hareketin en az olduğu 3 saniye. Öğretim videosunda
    // eğitmen konuşurken duruşu sabittir; asıl referans duruş oradadır.
    final vectors = <JointAngleVector>[];
    final yaws = <double>[];
    final normalizer = PoseNormalizer();

    for (final fr in frames) {
      if (fr['detected'] != true || fr['world'] == null) continue;
      final w = (fr['world'] as List).cast<List>();
      if (w.length < 33) continue;
      final lmRaw = (fr['lm'] as List).cast<List>();
      // Konum world'den (J-028: metrik uzay), görünürlük ham `lm`den — world
      // dizisi güven taşımıyor ve güven kapısı onsuz çalışmaz.
      final pts = [
        for (var i = 0; i < w.length; i++)
          PoseLandmark(
            (w[i][0] as num).toDouble(),
            (w[i][1] as num).toDouble(),
            (w[i][2] as num).toDouble(),
            i < lmRaw.length && lmRaw[i].length > 3 ? (lmRaw[i][3] as num).toDouble() : 1.0,
          )
      ];
      final tUs = ((fr['t'] as num).toDouble() * 1e6).round();
      final pose = normalizer.normalize(PoseFrame(tUs: tUs, landmarks: pts));
      vectors.add(extractor.extract(pose));

      final dx = pts[Lm.rightShoulder].x - pts[Lm.leftShoulder].x;
      final dz = pts[Lm.rightShoulder].z - pts[Lm.leftShoulder].z;
      yaws.add(math.atan2(dz.abs(), dx.abs()) * 180 / math.pi);
    }
    if (vectors.length < 90) continue;

    yaws.sort();
    final medianYaw = yaws[yaws.length ~/ 2];
    angleClassOf[id] = medianYaw < 25 ? 'C_frontal' : (medianYaw < 55 ? 'A_diagonal' : 'B_profile');

    // 90 karelik (≈3 sn) en durağan pencere.
    var bestStart = 0;
    var bestMotion = double.infinity;
    for (var s = 0; s + 90 <= vectors.length; s += 30) {
      var motion = 0.0;
      for (var i = s + 1; i < s + 90; i++) {
        for (var j = 0; j < vectors[i].values.length; j++) {
          final a = vectors[i].values[j], b = vectors[i - 1].values[j];
          if (a.isNaN || b.isNaN) continue;
          motion += (a - b).abs();
        }
      }
      if (motion < bestMotion) {
        bestMotion = motion;
        bestStart = s;
      }
    }
    takes.add(ReferenceTake(
      id: id,
      frames: vectors.sublist(bestStart, bestStart + 90),
      source: id,
    ));
  }

  stdout.writeln('take: ${takes.length}');
  for (final t in takes) {
    stdout.writeln('  ${t.id}  ${angleClassOf[t.id]}');
  }
  if (takes.length < 3) {
    stderr.writeln('minTakes=3 karşılanmadı');
    exit(1);
  }

  const builder = ReferenceBuilder();
  // Aynalama çözümünü AYRI çağırıyoruz: runnerUpGap yalnız MirrorResolution'da
  // (CanonicalReference kararı taşıyor, marjı değil). Kural 7'yi uygulamak için
  // marj lazım — kararın kendisi yetmiyor.
  final mirror = builder.resolveMirroring(takes);
  final ref = builder.build(takes);

  stdout.writeln('\n=== Eğitmenler arası dağılım (= toleransın kaynağı) ===');
  final specs = StandardJoints.upperBody;
  for (var j = 0; j < specs.length; j++) {
    final sds = <double>[];
    for (var f = 0; f < ref.frames.length; f++) {
      final sd = ref.dispersion[f][j];
      if (!sd.isNaN) sds.add(sd * 180 / math.pi);
    }
    if (sds.isEmpty) continue;
    sds.sort();
    stdout.writeln('  ${specs[j].id.padRight(20)} medyan sapma ${sds[sds.length ~/ 2].toStringAsFixed(1)}°');
  }

  // M-F-48: aynalama/yön uzlaşması global problem. Eğitmenler izleyiciye göre
  // aynalar; yanlış çözülen bir take, sol/sağ metriklerini ŞİŞİRİR. Gitarın
  // 4 katlık sol/sağ asimetrisi (left_forearm 80° vs right 18°) kısmen bunun
  // artefaktı olabilir — ölçmeden bilinmez.
  stdout.writeln('\n=== Aynalama çözümü (M-F-48 / kural 7) ===');
  stdout.writeln('  aynalanmış take : ${ref.mirroredTakeIds.length}/${takes.length}');
  stdout.writeln('  mirrorConfident : ${ref.mirrorConfident} (resolution: ${mirror.confident})');
  stdout.writeln('  runnerUpGap     : ${mirror.runnerUpGap.toStringAsFixed(5)}');
  stdout.writeln('  dışlanan (M-F-47): ${ref.excludedOutlierIds.isEmpty ? "yok" : ref.excludedOutlierIds.join(", ")}');
  stdout.writeln('  prior çelişkisi : ${ref.priorDisagreements.isEmpty ? "yok (prior verilmedi)" : ref.priorDisagreements.join(", ")}');
  // Kural 7'nin kapısı: taraf-bağımlı hüküm ancak çözüm KESİN ise verilir.
  // Simetrik bir etkinlikte (şan duruşu) çevirmenin maliyeti neredeyse sıfırdır,
  // yani "en iyi" atama gürültüyle belirlenir — bu belirsizliği ölçmeden
  // sol/sağ farkına anlam yüklemek, artefaktı bulgu sanmaktır.
  // O-021: `mirrorConfident`i olduğu gibi kabul etmek YETMİYOR — bayrağın
  // DAYANAĞINI da sormak gerekiyor. Çekirdek n>12'de tükenmeli aramayı bırakıp
  // runnerUpGap'i `mirrorMargin*2` olarak UYDURUYOR (reference_builder.dart
  // "// unknown gap"); bu yapısı gereği marjın üstünde olduğundan o yolda
  // confident DAİMA true döner. Yani "kesin" hükmü, ölçüm yapılamadığı için
  // veriliyor olabilir — dürüstlük kapısının tam tersi.
  //
  // Acı ironi: çalgı başına ≥12 kabul hedefi BİZİM kalite kuralımız ve tam da
  // bu kontrolün kapandığı tarafa itiyor. Havuz büyüdükçe sistem daha emin
  // konuşuyor, üstelik yanlış sebeple.
  const exhaustiveLimit = 12;
  final fabricatedGap = takes.length > exhaustiveLimit;
  if (fabricatedGap) {
    stdout.writeln('  ⚠️ GAP ÖLÇÜLMEDİ: n=${takes.length} > $exhaustiveLimit → çekirdek '
        'fallback yolunda; runnerUpGap=${mirror.runnerUpGap.toStringAsFixed(5)} '
        'kurgu değer (mirrorMargin×2), gerçek fark BİLİNMİYOR.');
  }
  stdout.writeln(ref.mirrorConfident && !fabricatedGap
      ? '  → taraf-bağımlı metrikler DEĞERLENDİRİLEBİLİR (çözüm kesin, gap ÖLÇÜLDÜ)'
      : fabricatedGap
          ? '  → ⚠️ taraf-bağımlı metrikler TUTULUR (kural 7: bilinmeyen fark = belirsiz çözüm)'
          : '  → ⚠️ taraf-bağımlı metrikler TUTULUR (kural 7: çözüm kesin değil)');

  final unreliable = ref.unreliableJoints();
  stdout.writeln('\nGÜVENİLMEZ eklemler (sapma >35°): '
      '${unreliable.isEmpty ? "yok" : unreliable.join(", ")}');
  stdout.writeln('→ Bu eklemlerde kullanıcıya hüküm verilmez: eğitmenler '
      'kendi aralarında anlaşamıyorsa tolerans uydurmak dürüstlük ihlalidir.');
}
