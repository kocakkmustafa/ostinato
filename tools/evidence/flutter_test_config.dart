import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_fonts/src/google_fonts_base.dart' show pendingFontFutures;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

/// `tools/evidence/` içindeki test(ler) için giriş — Flutter
/// `flutter_test_config.dart`ı test DOSYASIYLA AYNI dizinde arar (isim
/// `test/`e bağlı değil; ÖLÇÜLDÜ: bu dosya buraya konunca
/// `evidence_capture_test.dart` çalışırken devreye giriyor).
///
/// JabLab'ın AYNI kök-nedeni bulduğu AYNI çözümün BİREBİR uyarlaması
/// (kaynak: `ventures/jablab/app/test/flutter_test_config.dart`,
/// koordinatör aktarımı 2026-08-07). Ostinato'nun kendi üç deneme-yanılma
/// turu (bkz. `evidence_capture_test.dart` başındaki eski not) kök nedeni
/// EKSİK teşhis etmişti: sorun "test ortamı ağa ulaşamıyor" DEĞİL,
/// `TestWidgetsFlutterBinding`in kurduğu `HttpOverrides.global`in HER
/// isteği kasıtlı 400'e zorlamasıydı — `allowRuntimeFetching=true` denemesi
/// bu yüzden network-hatası biçimini DEĞİŞTİRDİ ama gidermedi.
///
/// Çözüm dört adımın SIRAYLA giderilmesi:
/// 1. `google_fonts` önce yerel asset'e bakar, bu `ServicesBinding.instance`
///    ister → binding önce kurulmalı.
/// 2. Binding kurulunca `HttpOverrides.global` HER isteği 400'e zorlar →
///    ön-ısınma sırasında geçici `null`a alınır.
/// 3. İndirme başarılı olunca diske yazma `path_provider`in platform
///    kanalını çağırır → `flutter test`in saf Dart-VM'inde kanal YOK,
///    `MissingPluginException`. Bu turun kendi geçici klasörüne yazan sahte
///    bir `PathProviderPlatform`la değiştirilir.
/// 4. İki geçici değişiklik de yalnız ön-ısınma penceresinde açık kalır,
///    asıl testler başlamadan ESKİ hâline dönerler — testin kendisi hâlâ
///    standart sandbox'ta koşar, kalıcı bir ağ bağımlılığı EKLENMEZ (ağırlık
///    zaten `google_fonts`un bellek-içi önbelleğinde).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();

  final HttpOverrides? previousHttpOverrides = HttpOverrides.current;
  final PathProviderPlatform previousPathProvider =
      PathProviderPlatform.instance;
  final Directory fontCacheDir =
      Directory.systemTemp.createTempSync('ostinato_test_fonts_');

  HttpOverrides.global = null;
  PathProviderPlatform.instance = _TempPathProvider(fontCacheDir.path);
  try {
    // Ostinato'nun TÜM google_fonts yüzeyi iki yardımcıdan geçer
    // (`hankenText`/`monoText`, `ostinato_theme.dart`) — üçüncü bir
    // GoogleFonts.* çağrısı yok. Kullanılan ağırlıklar ÖLÇÜLDÜ (grep,
    // 2026-08-07): hankenGrotesk {w400 varsayılan, w500, w600} ·
    // ibmPlexMono {w500 varsayılan, başka override yok}.
    GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w400);
    GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w500);
    GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w600);
    GoogleFonts.ibmPlexMono(fontWeight: FontWeight.w500);
    // `TextStyle` SENKRON döner, yükleme arka planda başlar — sabit bir
    // bekleme yerine paketin KENDİ takip ettiği `pendingFontFutures`i
    // bekliyoruz.
    await Future.wait(pendingFontFutures.toList());
  } finally {
    HttpOverrides.global = previousHttpOverrides;
    PathProviderPlatform.instance = previousPathProvider;
  }
  await testMain();
  try {
    fontCacheDir.deleteSync(recursive: true);
  } on Object {
    // Temizlik başarısız olsa bile TESTLERİN sonucu etkilenmez — geçici
    // klasör zaten sistemin kendi temp dizininde, işletim sistemi süpürür.
  }
}

/// `google_fonts`un indirdiği font baytlarını diske yazabilmesi için — GERÇEK
/// bir platform kanalı yerine bu koşunun kendi geçici klasörünü döndürüyor.
class _TempPathProvider extends PathProviderPlatform {
  _TempPathProvider(this._path) : super();

  final String _path;

  @override
  Future<String?> getApplicationSupportPath() async => _path;

  @override
  Future<String?> getTemporaryPath() async => _path;

  @override
  Future<String?> getApplicationDocumentsPath() async => _path;
}
