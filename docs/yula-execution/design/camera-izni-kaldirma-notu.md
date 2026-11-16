# Android kamera izni kaldırma notu (2026-11-16)

**Karar (Motion):** Yalnız ANDROID kamera izni kalkar. iOS `NSCameraUsageDescription` (Info.plist + 14 dil InfoPlist.strings) DURUR; metin dürüst ve kamera bayrakları kapalıyken istenmez.

**Ne:** Android `CAMERA` ve `camera.any` zorunluluğu birleşik manifestten çıkar. Kaynak manifestte `CAMERA` için `tools:node="remove"` durur (eklentiler izni geri getirmesin; gradle eklenti manifestlerinde görülen: `build/camera_android_camerax/intermediates/aapt_friendly_merged_manifests/debug/processDebugManifest/aapt/AndroidManifest.xml` CAMERA + `camera.any`, `build/motion_camera/...` aynı yolda CAMERA; ostinato_posture manifesti kontrol EDİLMEDİ); `camera.any` `required="false"`. Kamera kodu silinmedi, bayraklar KAPALI.

**Neden iOS'ta kalıyor:** iOS tarafında kamera eklentileri hâlâ bağlı (`pubspec.lock`: `camera`, `camera_avfoundation`; `Podfile.lock`: `camera_avfoundation`, `motion_camera`; `Podfile`: `PERMISSION_CAMERA=1`). Apple kamera API'si kullanımını görüp `NSCameraUsageDescription` bulamazsa ITMS-90683 verebilir. iOS eklentilerini çıkarmak ayrı bilet: **OST-CAM-IOS-01**.

**Kanıt (kod yolu okundu):** Kamera erişimi derleme-zamanı sabitleriyle kapalı: `ostinatoCameraPracticeAvailable = false` (`lib/app/ostinato_release_policy.dart:46`; `motion_account_bootstrap.dart` bunu `requireCameraAccess` kapısına verir), `ostinatoCameraLessonsOpen = false` (satır 52), Core `motionCameraCoachingAvailable = false` (`motion_release_policy.dart:6`; pub-cache revizyonu `5b1530…`'da okundu, pin `69a3c81` üzerinde DOĞRULANMADI). Üçü de `const`, uzaktan açılmaz; açmak kod değişikliği ve yeni derleme ister. `Permission.camera.request` yalnız `camera_session.dart:354` ve `mirror_camera.dart:36` içinde, bu kapıların arkasında.

**Birleşik manifest kanıtı:** `(cd android && ./gradlew :app:processReleaseMainManifest)` sonra `python3 tools/verify_merged_manifest_no_camera.py` (varsayılan yol release): CAMERA yok, zorunlu kamera özelliği yok, RECORD_AUDIO var. Bekçi: `test/camera_permissions_absent_test.dart`.

**Kapsam:** 1.0.2 (11) Apple incelemesine iOS izin metniyle gitti; iOS tarafı değişmedi. Android kaldırma yalnız sonraki Android sürümünü etkiler.

**Bayrak açılırken yapılacak** (`ostinato_posture` / `motion_camera` / kamera ders bayrağı):
1. AndroidManifest: `CAMERA` için `tools:node="remove"` satırını kaldır, düz `<uses-permission android:name="android.permission.CAMERA" />` ekle; `test/camera_permissions_absent_test.dart` bu durumda bilerek güncellenir.
2. iOS metni zaten yerinde; saklama iddiası bekçisinden geçmeye devam etmeli.
3. Mağaza gizlilik beyanı (App Privacy) ve Play Data safety güncellenir. Motion'a bilgi: Android kamera erişimi yeniden beyan edilecek.

**UYARI:** iOS'ta izin metni olmadan `Permission.camera` isteği uygulamayı çökertir; bu yüzden iOS metni kaldırılmadı. Android'de bayrak açılmadan önce izin geri eklenmeli.

**Bekçi:** `tools/validate_surface_honesty.py` kendi-sınamasında izin metni yüzeyi hem `NSCameraUsageDescription` hem `NSMicrophoneUsageDescription` için okunabilir olmalı; `gate_mutation_test` mutasyonları (plist'e saklama iddiası dahil) yakalanır.

**Takip (KAPATILDI, OST-CI-MANIFEST-01, 2026-11-16):** `checks.yml` `android-release-build` işinde `flutter build appbundle --release` adımından sonra `python3 tools/verify_merged_manifest_no_camera.py` koşar; CAMERA/zorunlu kamera varsa ya da manifest yoksa o mevcut iş kırılır (yeni iş/kontrol adı yok, 3/3 düzeni aynı). Dart testindeki birleşik grup `gates` işinde (derleme yok) atlanmaya devam eder; zorunluluk betik adımındadır, test değişmedi.
