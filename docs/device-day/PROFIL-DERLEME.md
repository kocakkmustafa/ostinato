# Profil derlemesi (cihaz günü ön hazırlık 4)

Durum: **TARİF.** iPhone için derleme denenmedi (cihaz, hesap ve Xcode gerekir); Android profil APK denendi ve **tamamlanmadı** (§3). Hesap/imza gerektiren adımlar §5'te ENGEL olarak kimin yapacağıyla ayrıdır. Sır, profil ve anahtar içeriği okunmadı; yalnız dosya yolu ve ayar adı yazıldı. Tur: [`TUR-LISTESI.md`](TUR-LISTESI.md). Kare ölçümü profil modu ister: [`FLAG-21-OLCUM.md`](FLAG-21-OLCUM.md).

Profil modu (`--profile`), AOT derlemesi + DevTools ölçümü içindir; hata ayıklama derlemesi iOS'ta cihazda JIT yüzünden çalışmaz, kare süresi için de geçerli değildir.

## 1. Ortak önkoşul: git dışı varlıklar

Ayrı bir çalışma ağacında (ör. `wt-*`) derlerken `.gitignore`'lu varlıklar yoktur. Android profil denemesi tam olarak buna takıldı: `Error detected in pubspec.yaml: No file or variants found for asset: assets/models/pose_landmarker_full.v1.task.` Çözüm: `tool/fetch_pose_model.sh` ile indir/kopyala (SHA-256 doğrulamalı) ya da ana kopyadan `assets/models/` altına **geçici** symlink kur, derlemeden sonra sil. Symlink commit'e girmez (`assets/models/*.task` ignore'dur).

## 2. iPhone (kurucu cihazı, cihaz 1)

Koddan olgular: `ios/Runner.xcodeproj/project.pbxproj` içinde `DEVELOPMENT_TEAM` yazılıdır (Runner hedefi için), `CODE_SIGN_STYLE = Automatic`, `PRODUCT_BUNDLE_IDENTIFIER = com.yulalab.ostinato`, `IPHONEOS_DEPLOYMENT_TARGET = 15.0` (**iOS 15 en düşük**). Mikrofon izin metni `ios/Runner/Info.plist` içindedir.

Adımlar:

1. Cihazda **Geliştirici Modu**'nu aç: Ayarlar → Gizlilik ve Güvenlik → Geliştirici Modu → Aç, cihaz yeniden başlar, onayla. (Menü, Xcode ile cihaz bağlanana dek görünmeyebilir.)
2. Cihazı USB ile bağla, "Bu bilgisayara güven" onayını ver.
3. Mac'te **Xcode'da kurucunun Apple geliştirici hesabı oturum açık** olmalı (Xcode → Ayarlar → Accounts). Bu kurucu adımıdır (§5, E1).
4. Ön-uçuş (isteğe bağlı): `python3 tools/device_day_preflight.py` (kod imza kimliği ve profil kontrolü; eski belge bu betiği kullanır; betik kurulum yapmaz).
5. Derle ve çalıştır:
   ```
   flutter devices
   flutter run --profile -d <iPhone-kimliği>
   ```
   Yalnız derlemek için: `flutter build ios --profile`; ardından Xcode ya da `flutter install --profile -d <kimlik>` ile kur. Otomatik imza gerekirse Xcode'da Runner → Signing & Capabilities sayfasında ekibin seçili olduğunu gör (`-allowProvisioningUpdates` gerektiren profil tazelemesi **kurucu/Xcode** adımıdır, E2).
6. İlk açılışta "Güvenilir geliştirici": Ayarlar → Genel → VPN ve Aygıt Yönetimi → geliştirici uygulaması altında hesabı **Güven** (kurucu, E3).
7. Doğrulama: uygulama açılır, Dart VM Service adresi `flutter run` çıktısında görünür (DevTools için).

Çalışmazsa: süreç hemen kapanıyorsa hata ayıklama derlemesi kurulmuştur; profil ya da release kullan. Kayıtlı cihaz (UDID) hesapta yoksa Xcode kendisi kaydeder (hesap kurucu).

## 3. Android APK (cihaz 2)

İmza mantığı (`android/app/build.gradle.kts`, okundu):

- `key.properties` varsa (`rootProject.file("key.properties")`) release imzası onunla yapılır; yoksa ve `-PallowDebugSigning=true` verilmişse release debug anahtarıyla imzalanır; ikisi de yoksa `signingConfig = null` (satır 105-110 civarı, yalnız `release` buildType'ında).
- `verifyReleaseSigning` görevi yalnız `assembleRelease` ve `bundleRelease`'e bağlıdır (satır 156-163 civarı); **profil derlemesi bu kapıdan geçmez**.
- `buildTypes` içinde `profile` tanımı **yok**. Profil buildType'ını Flutter Gradle eklentisi ekler; profil için hangi imzanın kullanıldığı bu dosyadan okunamaz. **Profil APK'nın hangi anahtarla imzalandığı DOĞRULANMADI** (aşağıdaki deneme tamamlanmadı).
- `key.properties` bu çalışma ağacında **yok**; içeriği okunmadı. Ana kopyada dosyanın varlığı görüldü, içeriğine bakılmadı.

Denenen komut (2026-11-18, bu çalışma ağacı, `key.properties` yok):

```
flutter pub get          # çıkış 0
flutter build apk --profile
```

Sonuç: **BAŞARISIZ, 10 dk 8 sn.** Neden imza değil: `:app:compileFlutterBuildProfile` görevinde `aot_android_asset_bundle` hedefi, `assets/models/pose_landmarker_full.v1.task` varlığı bu çalışma ağacında olmadığı için düştü (§1). İmza görevine ulaşılmadı. APK oluşmadı, commit'e girecek derleme çıktısı yok (`build/` ignore'dur). Süre 5 dk'yı aştığı için varlık sağlanıp yeniden denenmedi: **profil APK imza davranışı doğrulanmadı.**

Gün sabahı yapılacak (Ostinato):

```
# varlık hazır olduktan sonra, key.properties YOKSA:
flutter build apk --profile
# imza hatası alınırsa (kodda profil için anahtar yoksa):
flutter build apk --profile -PallowDebugSigning=true
```

`-PallowDebugSigning` bayrağı koda göre yalnız `release` için okunur; profil buildType'ına etkisi **doğrulanmadı**. Hata alınırsa nedeni ve çıktının kısa hâlini tabloya yaz, ENGEL olarak bildir.

Kurulum (cihazda USB hata ayıklama açık: Ayarlar → Geliştirici seçenekleri):

```
adb devices
adb install -r build/app/outputs/flutter-apk/app-profile.apk
```

APK yolu Flutter varsayılanıdır; çıktıda görülen yol kullanılır. APK commit'e girmez. Mağaza imzası (anahtar deposu) **kurucudadır** ve bu iş için kullanılmaz; yalnız debug ya da profil kimliğiyle kurulum yapılır (mağazaya gidebilir bir paket DEĞİLDİR).

## 4. Bayraklar (K1): kapalı yüzeyleri açmadan tur eksik kalır

`lib/app/ostinato_release_policy.dart` bayrakları `const bool` ve kapalıdır; `--dart-define` ile açılmaz (kodda `fromEnvironment` yalnız Supabase adresi/anahtarı ve `OSTINATO_FAKE_MIC` için var). Kapalı derlemede görünmeyenler: ilk üç dakika (`ostinatoFirstThreeMinutesOpen`), sahne (`ostinatoStageHomeEnabled`, bulanık katmanın tek kullanıcısı), dinle-dene-düzelt (`ostinatoListenTryFixRepeatOpen`), hayalet ekran (`ostinatoGhostScreenOpen`).

Önerilen yöntem (**kurucu/Motion onayı bekler**, K1): ayrı, geçici bir çalışma ağacında bu sabitleri yerelde `true` yap, derle, cihaza kur; değişiklik **commit'lenmez, itilmez**, gün sonunda ağaç atılır. Hangi bayrakların açık olduğu [`CIHAZ-TABLOSU.md`](CIHAZ-TABLOSU.md) "Bayrak durumu" sütununa yazılır. Onay gelmezse yalnız kapalı (yayın ayarlı) derleme ile tur yapılır ve eksik yüzeyler `YAPILMADI, bayrak kapalı` olarak kaydedilir. Bu belge bayrağı açmaz.

## 5. ENGEL listesi (imza / hesap gerektiren adımlar)

| No | Adım | Kim | Neden |
|---|---|---|---|
| E1 | Xcode'da Apple geliştirici hesabı oturumu | Kurucu | Hesap parolası/2FA yalnız kuruculadır |
| E2 | Gerekirse imza profilinin Xcode ile tazelenmesi (`-allowProvisioningUpdates`) | Kurucu (Xcode açık, hesap açık) | Hesap yetkisi |
| E3 | iPhone'da Geliştirici Modu ve "Güvenilir geliştirici" | Kurucu | Cihaz ayarı |
| E4 | Android'de USB hata ayıklama ve adb yetkisi | Kurucu | Cihaz ayarı |
| E5 | Mağaza anahtar deposu (`android/key.properties`) | Kurucu; bu iş için gerekmiyor | Sır; okunmaz |
| E6 | Profil APK imza davranışı | Ostinato (gün sabahı), §3 komutlarıyla | Bu turda doğrulanamadı |
| E7 | Bayrak açık yerel derleme (K1) | Kurucu/Motion onayı sonra Ostinato | Karar |
