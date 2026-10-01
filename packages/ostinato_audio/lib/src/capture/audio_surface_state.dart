import 'audio_route.dart';

/// Ses girişinin gösterebileceği HER durum — tipli, kapalı küme.
///
/// `ostinato_posture`'ın `SurfaceState`'iyle AYNI desen, bilerek AYRI tip:
/// bu paket `ostinato_posture`'a (veya Flutter'a) bağımlı DEĞİL — "kabuk
/// yalnız kablolama" sınırı (Gravita G-100) sesin kendi motoru için de
/// geçerli. Kamerada olmayıp seste olan hâl: [AudioCalibrating] — roadmap §7
/// madde 2'nin "route/sample-rate değişince kalibrasyona dön" sözleşmesinin
/// tipe dökülmüş hâli; kamerada karşılığı yok çünkü kamera latency-kalibreli
/// bir zamanlama iddiası taşımıyor, ses taşıyor.
sealed class AudioSurfaceState {
  const AudioSurfaceState();
}

/// Capture is closed. Resuming the app never implicitly restarts it.
final class AudioStopped extends AudioSurfaceState {
  const AudioStopped();
}

/// Oturum henüz açılıyor — izin isteği/native akış kurulumu sürüyor.
final class AudioStarting extends AudioSurfaceState {
  const AudioStarting();
}

/// İzin verilmedi. KALICI mı GEÇİCİ mi ayrı hâller (posture'un
/// `PermissionDenied` ailesiyle birebir gerekçe: "tekrar dene" kalıcı rette
/// hiçbir şey yapmaz, düğmenin kendisi çıkmaz sokak olur).
sealed class AudioPermissionDenied extends AudioSurfaceState {
  const AudioPermissionDenied();
}

final class AudioPermissionDeniedRetriable extends AudioPermissionDenied {
  const AudioPermissionDeniedRetriable();
}

final class AudioPermissionDeniedPermanent extends AudioPermissionDenied {
  const AudioPermissionDeniedPermanent();
}

/// Mikrofon açılamadı — donanım yok, native akış reddetti ya da istenen
/// sample rate desteklenmiyor. [reason] İSİMLİ bir sebeptir (ör.
/// `"unsupported_sample_rate:96000"`), ham platform istisna metni DEĞİL.
final class AudioUnavailable extends AudioSurfaceState {
  const AudioUnavailable(this.reason);
  final String reason;
}

/// Kurulum patladı ama ders yine de açılmalı (posture'un `SetupFailed`
/// deseni, ÇIKMAZ-SOKAK YASAĞI aynı gerekçeyle geçerli).
final class AudioSetupFailed extends AudioSurfaceState {
  const AudioSetupFailed(this.reason);
  final String reason;
}

/// Akış açık ama TIMING SKORU YOK — roadmap §7 madde 2+3: oturum başlarken,
/// [route] her değiştiğinde VE Bluetooth latency'si henüz ölçülmemişken
/// buraya (yeniden) düşer. Bu hâlin kendisi bir hata değil; "kalibrasyonsuz
/// timing score FAIL" kuralının POZİTİF karşılığıdır — pitch/onset hâlâ
/// üretilebilir, yalnız ZAMANLAMA hükmü ertelenir.
final class AudioCalibrating extends AudioSurfaceState {
  const AudioCalibrating(this.route);
  final AudioRoute route;
}

/// Akış kararlı, [sampleRate]da [route] üzerinden örnek akıyor.
///
/// ⚠️ Bu hâl latency'nin KALİBRE EDİLDİĞİNİ iddia ETMEZ — yalnız akışın
/// kendisinin kararlı olduğunu söyler. Kalibrasyon ayrı bir sözleşme
/// (OST-P0-003, `motion_audio` latency-girdisi notu §2 madde 3); bu paket
/// bugün onu ÖLÇMÜYOR, isimsiz "her şey yolunda" durumuna düşürmüyor.
final class AudioStreaming extends AudioSurfaceState {
  const AudioStreaming(this.route, this.sampleRate);
  final AudioRoute route;
  final int sampleRate;
}
