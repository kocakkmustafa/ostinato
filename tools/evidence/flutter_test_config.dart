import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show FontLoader;

/// `tools/evidence/` içindeki test(ler) için giriş — Flutter
/// `flutter_test_config.dart`ı test DOSYASIYLA AYNI dizinde arar.
///
/// D1 NOTU (2026-08-16, O-149): bu dosya `google_fonts`un çalışma-anı
/// indirmesini test ortamında güvenli hâle getiren dört adımlık bir
/// `HttpOverrides`/`path_provider` ön-ısınma mekanizması taşıyordu (bkz. git
/// geçmişi). Fontlar artık `pubspec.yaml`ın `fonts:` bölümünde PAKETLİ —
/// ağ/path_provider işi bitti. AMA `flutter_test` ÖLÇÜLDÜ (2026-08-16):
/// `pubspec.yaml`daki `fonts:` bildirimini test ortamında OTOMATİK
/// YÜKLEMİYOR — sınama karesi BLOK GLİF çiziyordu (`loadAppFonts()` bu
/// Flutter sürümünde (3.41.1) YOK). Panzehir: dosyaları elle `FontLoader`a
/// ver — bu, üretimin OKUDUĞU AYNI dört dosya, ayrı bir kopya DEĞİL.
Future<void> testExecutable(Future<void> Function() testMain) async {
  Future<void> loadFamily(String family, List<String> paths) async {
    final FontLoader loader = FontLoader(family);
    for (final String path in paths) {
      final Uint8List bytes = File(path).readAsBytesSync();
      loader.addFont(Future<ByteData>.value(bytes.buffer.asByteData()));
    }
    await loader.load();
  }

  await loadFamily('Hanken Grotesk', <String>[
    'assets/fonts/HankenGrotesk-Regular.ttf',
    'assets/fonts/HankenGrotesk-Medium.ttf',
    'assets/fonts/HankenGrotesk-SemiBold.ttf',
  ]);
  await loadFamily(
      'IBM Plex Mono', <String>['assets/fonts/IBMPlexMono-Medium.ttf']);

  await testMain();
}
