import 'dart:async';
import 'dart:io';

/// Repo-geneli test girişi — HER `test/*.dart` dosyası bundan geçer
/// (Flutter `flutter_test_config.dart`ı `test/` kökünde arar, tüm alt
/// dosyalara otomatik uygulanır).
///
/// D1 REGRESYON KAPISI (2026-08-16, O-149 — Gravita `G-227` emsali,
/// katman 2: "test-zamanı SAYIM, tüm süit, hepsi 0", kalıcı bırakılır).
/// `validate_runtime_fetch.py` KAYNAK metnini tarar (statik); bu dosya
/// ÇALIŞMA-ANI davranışını sınar (dinamik) — ikisi FARKLI bir riski
/// yakalar: biri *"kod `GoogleFonts.*` çağırıyor mu"*, öteki *"test koşumu
/// boyunca, hangi API'den olursa olsun, GERÇEKTEN bir ağ bağlantısı
/// denendi mi"*. Fontlar paketli, backend yok (A9) — beklenen sayı SIFIR.
class _ZeroNetworkOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    throw StateError(
        'Testler sırasında AĞ BAĞLANTISI denendi. Bu depoda hiçbir test '
        'ağa çıkmamalı (D1: fontlar paketli, backend yok — A9). Gerçekten '
        'ağ gerektiren yeni bir test yazıyorsan bu istisna SESSİZCE '
        'geçilmez: kapsamı adıyla genişlet, sabote etme.');
  }
}

Future<void> testExecutable(Future<void> Function() testMain) async {
  HttpOverrides.global = _ZeroNetworkOverrides();
  await testMain();
}
