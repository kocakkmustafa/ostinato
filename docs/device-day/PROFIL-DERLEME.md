# Profil derlemesi (cihaz günü ön hazırlık 4)

Durum: **TARİF.** iPhone için derleme denenmedi (cihaz, hesap ve Xcode gerekir); Android profil APK ilk denemede asset eksikliğiyle düştü, ikinci denemede başarılı oldu (§3, §6.2). Hesap/imza gerektiren adımlar §5'te ENGEL olarak kimin yapacağıyla ayrıdır. Sır, profil ve anahtar içeriği okunmadı; yalnız dosya yolu ve ayar adı yazıldı. Tur: [`TUR-LISTESI.md`](TUR-LISTESI.md). Kare ölçümü profil modu ister: [`FLAG-21-OLCUM.md`](FLAG-21-OLCUM.md).

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
- `buildTypes` içinde `profile` tanımı **yok**; profil buildType'ını Flutter Gradle eklentisi ekler. Profil APK'nın gerçek imzası ölçüldü: `CN=Android Debug` (§6.2).
- `key.properties` bu çalışma ağacında **yok**; içeriği okunmadı. Ana kopyada dosyanın varlığı görüldü, içeriğine bakılmadı.

Denenen komut (2026-11-18, bu çalışma ağacı, `key.properties` yok):

```
flutter pub get          # çıkış 0
flutter build apk --profile
```

Sonuç (ilk deneme): **BAŞARISIZ, 10 dk 8 sn.** Neden imza değil: `:app:compileFlutterBuildProfile` görevinde `aot_android_asset_bundle` hedefi, `assets/models/pose_landmarker_full.v1.task` varlığı bu çalışma ağacında olmadığı için düştü (§1). İmza görevine ulaşılmadı. APK oluşmadı, commit'e girecek derleme çıktısı yok (`build/` ignore'dur). Süre 5 dk'yı aştığı için varlık sağlanıp yeniden denenmedi: ikinci deneme için §6.2.

İkinci deneme (2026-11-18, `wt-ost-defines`, asset symlink, `-PallowDebugSigning=true`, define'lı, ≈247 sn): **BAŞARILI**, imza `CN=Android Debug`. Ayrıntı ve komutlar §6.2.

Kurulum (cihazda USB hata ayıklama açık: Ayarlar → Geliştirici seçenekleri):

```
adb devices
adb install -r build/app/outputs/flutter-apk/app-profile.apk
```

APK yolu Flutter varsayılanıdır; çıktıda görülen yol kullanılır. APK commit'e girmez. Mağaza imzası (anahtar deposu) **kurucudadır** ve bu iş için kullanılmaz; yalnız debug ya da profil kimliğiyle kurulum yapılır (mağazaya gidebilir bir paket DEĞİLDİR).

## 4. Bayraklar (K1): kapalı yüzeyleri açmak

`lib/app/ostinato_release_policy.dart` bayrakları `const bool` ve kapalıdır. `ostinatoStageHomeEnabled` ve `ostinatoGhostScreenOpen` `--dart-define` ile açılır (§6); kaynağı yerelde `true` yapmak gerekmez ve yapılmaz. Kodda diğer `fromEnvironment` kullanımları Supabase adresi/anahtarı ve `OSTINATO_FAKE_MIC`'tir. Kapalı derlemede görünmeyenler: ilk üç dakika (`ostinatoFirstThreeMinutesOpen`; bu iki derlemede de kapalı kalır, define'ı yoktur), sahne (`ostinatoStageHomeEnabled`, bulanık katmanın tek kullanıcısı), dinle-dene-düzelt (`ostinatoListenTryFixRepeatOpen`; define'ı yoktur, kapalı kalır), hayalet ekran (`ostinatoGhostScreenOpen`). Hangi bayrakların açık olduğu [`CIHAZ-TABLOSU.md`](CIHAZ-TABLOSU.md) "Bayrak durumu" sütununa yazılır.

## 5. ENGEL listesi (imza / hesap gerektiren adımlar)

| No | Adım | Kim | Neden |
|---|---|---|---|
| E1 | Xcode'da Apple geliştirici hesabı oturumu | Kurucu | Hesap parolası/2FA yalnız kuruculadır |
| E2 | Gerekirse imza profilinin Xcode ile tazelenmesi (`-allowProvisioningUpdates`) | Kurucu (Xcode açık, hesap açık) | Hesap yetkisi |
| E3 | iPhone'da Geliştirici Modu ve "Güvenilir geliştirici" | Kurucu | Cihaz ayarı |
| E4 | Android'de USB hata ayıklama ve adb yetkisi | Kurucu | Cihaz ayarı |
| E5 | Mağaza anahtar deposu (`android/key.properties`) | Kurucu; bu iş için gerekmiyor | Sır; okunmaz |
| E6 | Profil APK imza davranışı | Ostinato | Çözüldü: ilk deneme asset eksikliğiyle düştü; ikinci deneme (`wt-ost-defines`, asset symlink, `-PallowDebugSigning=true`, define'lı, ≈247 sn) BAŞARILI; `apksigner verify --print-certs` çıktısı `V2 Signer: certificate DN: C=US, O=Android, CN=Android Debug` (§6.2) |
| E7 | Bayrak açık profil derlemesi (K1) | Ostinato, §6 komutlarıyla | Bayraklar `--dart-define` ile açılır; kaynağı yerelde `true` yapmak gerekmez |

## 6. Cihaz günü derlemeleri (22 Kas)

İki bayrak (`ostinatoStageHomeEnabled`, `ostinatoGhostScreenOpen`) `bool.fromEnvironment` ile tanımlıdır; varsayılan false. Yalnız cihaz günü profil derlemesi `--dart-define=...=true` verir; mağaza/release derlemesi **asla** vermez. Koruma testi: `test/devday_defines_test.dart`.

İki derleme, ikisi de **profil**:

1. **Kapalı:** define yok (bayraklar false).
2. **Açık:** `--dart-define=OSTINATO_DEVDAY_STAGE_HOME=true --dart-define=OSTINATO_DEVDAY_GHOST_SCREEN=true`

Derleme türü sütunu [`CIHAZ-TABLOSU.md`](CIHAZ-TABLOSU.md) §1'de zaten vardır: orada `profil-kapali` ya da `profil-acik` yaz; "Bayrak durumu" sütununa açık bayrak adlarını yaz.

### 6.1 Donma notu şablonu

```
22 Kas 12:00 main donar
SHA: ________________________________________ (tam 40 karakter; git rev-parse origin/main)
Derleme saati: ____   Derleyen: ____
İki derleme AYNI SHA'dan alınır (SHA zaten aynıdır, derlemeleri ayıran şey APK adı ve stage/yardım görünümüdür): kapalı ____ · açık ____
Profil derlemeleri 13:30'a dek hazır.
```

Derlemeler SHA'daki temiz ağaçtan alınır (`git status` boş; `assets/models/*.task` git dışı varlığı §1'e göre geçici symlink, derlemeden sonra silinir).

### 6.2 Android (cihaz 2)

İmza gerçeği (`android/app/build.gradle.kts` okundu): `signingConfig` yalnız `release` buildType'ında ayarlıdır; `profile` için dosyada tanım yoktur, tipi Flutter eklentisi ekler. Motion kararı (kaynak: Motion Orchestration mesajı 18 Kas): profil APK **debug anahtarıyla** imzalanır, release anahtarı kullanılmaz. 2026-11-18 denemesinde `key.properties` olmayan ağaçta, `-PallowDebugSigning=true` verilerek derlenen profil APK'nın imzası `apksigner verify --print-certs` ile `CN=Android Debug` çıktı. Kanıt (APK `build/app/outputs/flutter-apk/app-profile.apk` olarak durduğundan yeniden koşuldu): `V2 Signer: certificate DN: C=US, O=Android, CN=Android Debug`. Bayrağın profil için şart olup olmadığı **ayrıca ölçülmedi**; komuta eklenir (profil buildType'ı onu okumasa da zararsızdır, `verifyReleaseSigning` profil görevine bağlı değildir).

```
# 1) kapalı
flutter build apk --profile -PallowDebugSigning=true
mv build/app/outputs/flutter-apk/app-profile.apk build/app/outputs/flutter-apk/app-profile-kapali.apk

# 2) açık
flutter build apk --profile -PallowDebugSigning=true \
  --dart-define=OSTINATO_DEVDAY_STAGE_HOME=true \
  --dart-define=OSTINATO_DEVDAY_GHOST_SCREEN=true
mv build/app/outputs/flutter-apk/app-profile.apk build/app/outputs/flutter-apk/app-profile-acik.apk
```

Flutter her derlemede `build/app/outputs/flutter-apk/app-profile.apk` üzerine yazar; bu yüzden **her derlemeden hemen sonra yeniden adlandır** (`app-profile-kapali.apk` / `app-profile-acik.apk`). Kurulum: `adb devices` sonra `adb install -r build/app/outputs/flutter-apk/app-profile-<kapali|acik>.apk`. Aynı paket adı (`com.yulalab.ostinato`): iki profil derlemesi arasında ikinci kurulum birincinin üstüne yazar ve veri korunur. APK commit'e girmez. Süre: ≈4-10 dk; terminal zaman aşımı için arka planda koş.

### 6.3 iPhone (cihaz 1)

Önkoşul (kurucu, 22 Kas 13:00): Xcode açık, Apple hesabı girili, iPhone bağlı, Geliştirici Modu açık. Xcode'da Runner → Signing & Capabilities: otomatik imza; takım adı projede yazılıdır (`DEVELOPMENT_TEAM`), sır okunmaz.

```
flutter build ios --profile                      # 1) kapalı
flutter build ios --profile \
  --dart-define=OSTINATO_DEVDAY_STAGE_HOME=true \
  --dart-define=OSTINATO_DEVDAY_GHOST_SCREEN=true  # 2) açık
```

İki derleme `ios/build` çıktısını ve `Runner.app`'i paylaşır; aynı anda ikisi saklanmaz. Her derlemeden sonra Xcode'dan (Product → Run, profil şeması) ya da `flutter install --profile -d <kimlik>` ile kur. Bundle id aynıdır (`com.yulalab.ostinato`): ikinci kurulum birincinin üstüne yazar.

### 6.4 Kurulum sırası ve hangi cihaz hangi derlemeyi alır

| Cihaz | Derleme | Sıra | Not |
|---|---|---|---|
| 1 iPhone (kurucu) | `profil-acik` | 1. kapalıyı derle, gerekirse tur 1-2 için kur; 2. açığı derle ve üstüne kur | Ağ yakalama ve ekran okuyucu bu cihazda; açık derleme kalır |
| 2 Android | `profil-kapali` + `profil-acik` | `app-profile-kapali.apk` önce, gerekirse sonra `app-profile-acik.apk` (`-r`) | Kapalı derleme "yayın ayarlı" karşılaştırması içindir |
| 3-5 | Motion orchestration atar | Aynı kural: son kurulan derleme çalışır | Tabloya yaz |

Kural: bir cihazda aynı anda tek derleme çalışır (aynı bundle id); tur sonuçları satırında hangi derlemede ölçüldüğü `Derleme türü` sütunuyla yazılır. Hangi cihazın hangi derlemeyi alacağı gün sabahı Motion orchestration tarafından kesinleşir (bu tablo öneridir).

### 6.5 Derleme sonrası doğrulama

Bayrak const olduğundan APK/IPA içinde metin olarak aranmaz (Dart AOT; ölçülmedi). Doğrulama uygulamada görünür farktan yapılır:

- **Sahne kökte:** karşılama sayfalarından sonra kök ekran. Açık derlemede sahne (devam edilen ders, tek "Play", üç tutamaç, araç rafı); kapalı derlemede kütüphane.
- **Yardım yüzeyi (ghost):** iki bayrak açıkken sahnenin araç rafında Yardım yüzeyi görünür (`ghost-help-surface`, `ghost-level-*`; `lib/app/stage/tool_shelf.dart`) ve seçilen seviye (`ghostLevel`) pratik ekranını şekillendirir. Kapalı derlemede bunlar yoktur (`ghost` yalnız `ostinatoGhostScreenOpen` açıkken rafa verilir).
- Pratik ekranındaki eski `ghost-toggle` bu ayrımda **kullanılmaz**: sahne pratik ekranını `ghostScreen: false` ile açar, anahtar sahnede hiç çıkmaz.
- Bu derlemelerde `ostinatoFirstThreeMinutesOpen` kapalı kalır: ilk üç dakika akışı görünmez, karşılamadan sonra doğrudan kök gelir.
- Görünür fark yoksa derlemenin etiketi tutmadığını varsay, yeniden derle; sonucu tabloya yaz.

### 6.6 Mağaza derlemesinin define almadığını gösteren komut ve sınırları

```
grep -rn OSTINATO_DEVDAY .github tool tools docs/store
```

Çıktı **boş** olmalıdır (izinli yerler: `docs/device-day/`, policy dosyası, koruma testi). `test/devday_defines_test.dart` aynı marker'ı ayrıca şunlarda arar: `.github/workflows/*.yml|yaml`, `docs/store/` (metin dosyaları), `flutter build` geçen `tool/` ve `tools/` dosyaları, `ios/` ve `android/` altında `.gradle .kts .properties .xcscheme .pbxproj .xcconfig .yml .yaml .rb .sh .plist .json` ile Fastfile/Appfile/Gymfile (`build/`, `Pods/`, `.gradle/`, `Flutter/ephemeral/` hariç).

**Test taramaz:** dolaylı `--dart-define-from-file`, `.env` ya da `.json` define dosyaları (ios/ ve android/ dışında), Makefile, codemagic.yaml ve `ios/Flutter/Generated.xcconfig` içindeki `DART_DEFINES` (base64, metin taraması bulmaz). Bu yüzden kural süreçtir: cihaz günü derlemeleri **ayrı worktree'de** (`wt-*`) yapılır; mağaza derlemesi öncesi `flutter clean` + `flutter build ios --release`; Xcode'dan doğrudan Archive alınmaz (eski `Generated.xcconfig` define taşıyabilir).

### 6.7 Mağazaya yükleme uyarısı

- Profil derlemeleri aynı `com.yulalab.ostinato` ve aynı sürüm/build numarasını taşır; **TestFlight'a ve Play'e YÜKLENMEZ**.
- Android: debug imzalı profil APK, mağaza imzalı kurulu sürümün üstüne `adb install -r` ile kurulmaz (imza uyuşmazlığı). Önce kaldırmak uygulama verisini siler; kurucunun gerçek verisi olan cihazda dikkat.
- iOS: kurucunun TestFlight kopyası varsa profil derlemesi onun üstüne yazılır.
