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

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'inference_manifest.dart';

final class PoseModelPin {
  const PoseModelPin._();

  /// Flutter asset yolu. Dosya git'te **DEĞİL** (aile kuralı: `.task`
  /// ikilileri izlenmez, `.gitignore`) — `tool/fetch_pose_model.sh` indirir
  /// ya da aile hattından kopyalar ve SHA-256'yı DOĞRULAR.
  static const String assetPath = InferenceManifest.poseModelPath;

  /// Zarfa damgalanan kimlik.
  static const String modelId = InferenceManifest.poseModelId;

  /// Kanonik hash (varyant `full`, sürüm `1`) — fetch betiğiyle AYNI.
  static const String sha256 = InferenceManifest.poseModelSha256;

  /// Asset'i uygulama-özel bir dosyaya yazar — plugin bundle DEĞİL bir YOL
  /// ister (Gravita `_modelPath()` deseni). Dosya içerik hashine göre ayrılır ve her açılışta
  /// doğrulanır. TEK yer: `CameraPoseSource` + Kurulum Kontrolü kamera probu
  /// bunu paylaşır, ikisi ayrı ayrı yazmaz.
  static Future<String> resolveFilePath() async {
    final manifest = await InferenceManifest.load();
    await manifest.postureReference.readVerified(rootBundle);
    return resolveVerifiedModelFile(
      artifact: manifest.poseModel,
      directory: await getApplicationSupportDirectory(),
      bundle: rootBundle,
    );
  }
}

/// Content-addressed model cache: every returned file is verified. A corrupt
/// file is retained for diagnosis and refused; it is never silently activated.
/// Different release hashes occupy different paths, so rollback uses its own
/// bundled bytes instead of a previous release's mutable filename.
Future<String> resolveVerifiedModelFile({
  required RuntimeArtifact artifact,
  required Directory directory,
  required AssetBundle bundle,
}) async {
  final file = File('${directory.path}/pose-${artifact.sha256}.task');
  if (await file.exists()) {
    if (!artifact.matches(await file.readAsBytes())) {
      throw const FormatException('Cached pose model hash mismatch');
    }
    return file.path;
  }
  final bytes = await artifact.readVerified(bundle);
  await directory.create(recursive: true);
  // A separate temporary file prevents partial writes from becoming active.
  final temporary = await directory.createTemp('.ostinato-model-');
  final candidate = File('${temporary.path}/verified.task');
  try {
    await candidate.writeAsBytes(bytes, flush: true);
    if (!artifact.matches(await candidate.readAsBytes())) {
      throw const FormatException('Written pose model hash mismatch');
    }
    await candidate.rename(file.path);
  } finally {
    // Only this function's new temporary directory is removed.
    await temporary.delete(recursive: true);
  }
  return file.path;
}
