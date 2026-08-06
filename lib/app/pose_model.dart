/// Uygulamanın PİNLİ poz modeli beyanı (M-F-263 · JabLab J-072 uyarlaması,
/// Gravita `pose_model.dart` ile BİREBİR aynı — aile-geneli TEK pinli model).
///
/// **Neden sabit değil de kendi dosyası:** üç değer birbirine bağlı ve üçü
/// birlikte doğru olmak zorunda — asset yolu (hangi dosya yüklenecek),
/// [modelId] (her zarfa damgalanan kimlik) ve [sha256] (dosyanın gerçekten o
/// dosya olduğunun kanıtı). Biri kayarsa diğerleri onu örter.
///
/// ⚠️ `latest` YASAK (M-L-01'de ölçüldü): `full` varyantında
/// `/float16/latest/` ile `/float16/1/` FARKLI — **aynı boyut, farklı hash**.
/// Boyut değişmediği için fark gözden kaçar; sürüm segmenti bu yüzden pinli.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

final class PoseModelPin {
  const PoseModelPin._();

  /// Flutter asset yolu. Dosya git'te **DEĞİL** (aile kuralı: `.task`
  /// ikilileri izlenmez, `.gitignore`) — `tool/fetch_pose_model.sh` indirir
  /// ya da aile hattından kopyalar ve SHA-256'yı DOĞRULAR.
  static const String assetPath =
      'assets/models/pose_landmarker_full.v1.task';

  /// Zarfa damgalanan kimlik.
  static const String modelId = 'pose_landmarker_full/float16/1';

  /// Kanonik hash (varyant `full`, sürüm `1`) — fetch betiğiyle AYNI.
  static const String sha256 =
      '5134a3aad27a58b93da0088d431f366da362b44e3ccfbe3462b3827a839011b1';

  /// Asset'i uygulama-özel bir dosyaya yazar — plugin bundle DEĞİL bir YOL
  /// ister (Gravita `_modelPath()` deseni). Dosya zaten varsa yeniden
  /// yazılmaz. TEK yer: `CameraPoseSource` + Kurulum Kontrolü kamera probu
  /// bunu paylaşır, ikisi ayrı ayrı yazmaz.
  static Future<String> resolveFilePath() async {
    final Directory dir = await getApplicationSupportDirectory();
    final File f = File('${dir.path}/${assetPath.split('/').last}');
    if (!await f.exists()) {
      final ByteData data = await rootBundle.load(assetPath);
      await f.writeAsBytes(data.buffer.asUint8List(), flush: true);
    }
    return f.path;
  }
}
