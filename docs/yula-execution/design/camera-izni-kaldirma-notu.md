# Kamera izni kaldırma notu (2026-11-16)

**Ne:** Android `CAMERA` (manifestte `tools:node="remove"`; eklentiler geri getirmesin) ve iOS `NSCameraUsageDescription` (Info.plist + 14 dil InfoPlist.strings) kaldırıldı. Kamera özellik bayrakları KAPALI, kamera kodu yerinde.

**Neden:** Kullanılmayan izin mağaza incelemesi ve gizlilik beyanı yükü.

**Kanıt (kod yolu okundu):** Kamera erişimi iki derleme-zamanı sabitiyle kapalı: `ostinatoCameraPracticeAvailable = false` (`lib/app/ostinato_release_policy.dart:46`; `motion_account_bootstrap.dart` bunu `requireCameraAccess` kapısına verir) ve `ostinatoCameraLessonsOpen = false` (satır 52). Core'daki `motionCameraCoachingAvailable` de `const bool = false` (`motion_release_policy.dart:6`). Üçü de uzaktan değil `const`; açmak kod değişikliği ve yeni derleme ister. `Permission.camera.request` yalnız `camera_session.dart:354` ve `mirror_camera.dart:36` içinde, bu kapıların arkasında.

**UYARI:** Bayrak açılırsa (uzaktan değil, yeni derlemeyle) iOS'ta izin metni olmadan `Permission.camera` isteği uygulamayı çökertir. Bayrak açılmadan önce izin + metin geri eklenmeli.

**Kapsam:** 1.0.2 (11) Apple incelemesinde bu izinlerle gitti; kaldırma yalnız sonraki sürümü etkiler.

**Bayrak açılırken yapılacak** (`ostinato_posture` / `motion_camera` / kamera ders bayrağı):
1. AndroidManifest: `CAMERA` için `tools:node="remove"` satırını kaldır, düz `<uses-permission android:name="android.permission.CAMERA" />` ekle; `test/camera_permissions_absent_test.dart` bu durumda bilerek güncellenir.
2. iOS: `NSCameraUsageDescription` Info.plist + 14 dil InfoPlist.strings'e geri (metin saklama iddiası bekçisinden geçmeli).
3. Mağaza gizlilik beyanı (App Privacy) ve Play Data safety güncellenir. Motion'a bilgi: kamera erişimi yeniden beyan edilecek.

**Bekçi:** `tools/validate_surface_honesty.py` kendi-sınamasında izin metni yüzeyi artık `NSMicrophoneUsageDescription` ile doğrulanır; `gate_mutation_test` mutasyonu (plist'e saklama iddiası) hâlâ yakalanır.

**iOS ITMS-90683 riski:** iOS tarafında kamera eklentileri hâlâ bağlı: `pubspec.lock`ta `camera`/`camera_avfoundation`, `Podfile.lock`ta `camera_avfoundation` ve `motion_camera`, `Podfile`da `PERMISSION_CAMERA=1`. Apple derlemede kamera API'si kullanımını görüp `NSCameraUsageDescription` bulamazsa ITMS-90683 ile yükleme uyarısı/ret verebilir; sonraki yüklemede çıkarsa ya eklentiler/`PERMISSION_CAMERA` çıkarılmalı ya da anahtar geri konmalı (Motion'a bilgi).
