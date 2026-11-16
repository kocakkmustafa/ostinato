# Kamera izni kaldırma notu (2026-11-16)

**Ne:** Android `CAMERA` (manifestte `tools:node="remove"`; eklentiler geri getirmesin) ve iOS `NSCameraUsageDescription` (Info.plist + 14 dil InfoPlist.strings) kaldırıldı. Kamera özellik bayrakları KAPALI, kamera kodu yerinde.

**Neden:** Bayraklar kapalıyken uygulama kameraya hiç erişmiyor; kullanılmayan izin mağaza incelemesi ve gizlilik beyanı yükü.

**Kapsam:** 1.0.2 (11) Apple incelemesinde bu izinlerle gitti; kaldırma yalnız sonraki sürümü etkiler.

**Bayrak açılırken yapılacak** (`ostinato_posture` / `motion_camera` / kamera ders bayrağı):
1. AndroidManifest: `CAMERA` için `tools:node="remove"` satırını kaldır, düz `<uses-permission android:name="android.permission.CAMERA" />` ekle; `test/camera_permissions_absent_test.dart` bu durumda bilerek güncellenir.
2. iOS: `NSCameraUsageDescription` Info.plist + 14 dil InfoPlist.strings'e geri (metin saklama iddiası bekçisinden geçmeli).
3. Mağaza gizlilik beyanı (App Privacy) ve Play Data safety güncellenir. Motion'a bilgi: kamera erişimi yeniden beyan edilecek.

**Bekçi:** `tools/validate_surface_honesty.py` kendi-sınamasında izin metni yüzeyi artık `NSMicrophoneUsageDescription` ile doğrulanır; `gate_mutation_test` mutasyonu (plist'e saklama iddiası) hâlâ yakalanır.
