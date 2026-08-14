# 🚢 Ostinato — yayın engeli denetimi (2026-08-12)

> **Yöntem icat EDİLMEDİ:** JabLab `docs/gates/YAYIN-ENGELI-DENETIM-YONTEMI.md`
> (J-216) uygulandı — 12 kalem, her biri *soru · nasıl ölçülür · pozitif
> kontrol · sınıf*. Bu belge o yöntemin **Ostinato koşumudur**.
>
> **Ölçüm:** `main` = `8b3cb41` · ağaç temiz · kapılar 49 yeşil / 0 kırmızı.
> 08-07 denetimi (`YAYIN-ENGELLERI-2026-08-07.md`) SÜPERSEDE — o turda
> *"ölçülmemiş"* bırakılan iki kalem (ASC kaydı · mağaza metni) bu turda
> ÖLÇÜLDÜ.

## ⛔ HAYIR — 4 engel, 2 açık karar, 1 ortam kusuru.

| # | katman | sonuç | sınıf |
|---|---|---|---|
| 1 | ağ | ✅ **engel değil** — üretim Dart'ında 0 ağ çağrısı | hat-yereli |
| 2 | kalıcılık | ✅ **engel değil** — 2 yazıcı, ikisi de ÖLÇÜM DEĞİL | hat-yereli |
| 3 | izin metni | ✅ **bugün kapatıldı** (O-098) + kapıya bağlandı | hat-yereli |
| 4 | platform eşiği | ✅ **engel değil** — `targetSdk 36` | hat-yereli |
| **5** | **imza** | 🔴 **ENGEL** — release APK'yı **`CN=Android Debug`** imzaladı | **İKİYE BÖLÜNÜR** ↓ |
| 6 | gizlilik manifesti | ✅ **engel değil** — var, beyan ölçümle uyuşuyor | hat-yereli |
| **7** | **ikon + açılış** | 🔴 **ENGEL** — Flutter varsayılan logosu · açılış 68 bayt | kurucu (tasarım) |
| **8** | **mağaza iddiaları** | 🔴 **ENGEL** — depoda taslak yok, ASC alanları **null**, ekran görüntüsü **0** | kurucu (içerik+onay) |
| 9 | otomatik yayın | 🟠 **AÇIK KARAR** — `releaseType: AFTER_APPROVAL` | kurucu (ayar) |
| **10** | **cihaz kanıtı** | 🔴 **ENGEL** — cihazda hiç koşmadı | kurucu (cihaz günü) |
| 11 | sürüm | 🟠 **AÇIK KARAR** — `1.0.0+1` bir BEYAN | kurucu |
| 12 | araç zinciri | 🟠 **ORTAM** — varsayılan JDK ile Gradle hiç koşmuyor | hat-yereli (teşhis ✅) · venture-ötesi (kalıcı) |

## Dağılım

* **hat-yereli: 6** — ①②③④⑥ (hepsi ✅ kapalı) + **⑤a** (imza yapılandırması +
  sessiz-düşme kapısı) + ⑫ teşhisi (yapıldı)
* **çekirdek: 0** — ve bu bir varsayım değil ölçüm sonucu: 12 kalemin
  hiçbiri `motion_core` değişikliği gerektirmiyor
* **kurucu: 6** — **⑤b** keystore · ⑦ ikon+açılış tasarımı · ⑧ mağaza
  metni+ekran görüntüleri · ⑨ `AFTER_APPROVAL` ayarı · ⑩ cihaz günü ·
  ⑪ sürüm beyanı *(+⑫'nin makine geneli düzeltmesi, venture-ötesi)*

---

## Ölçümler ve pozitif kontrolleri

### ① ağ — engel değil
Tarama: `HttpClient(|http.(get|post|put)|Socket|WebSocket|Dio(` → **0**.
**SABOTAJ KONTROLÜ:** `HttpClient()` enjekte → tarama **1** buldu VE yüzey
kapısı öttü (*"sevk edilen kod 'HttpClient(' taşıyor ama 6 yüzey hiçbir şey
yüklenmiyor diyor"*) → geri al → **0** → uydurma dizge (`ZZQQNetworkCall`)
→ **0**. Üç katman: araç ✓ dizge ✓ kapsam ✓.

### ② kalıcılık — engel değil
`lib/` içinde diske yazan **iki** yer: `onboarding_store.dart` (karşılama
biti) · `pose_model.dart` (model asset'i). **İkisi de ÖLÇÜM DEĞİL** ve ikisi
de adıyla muaf. Üçüncü yazıcı YOK. İddia metniyle bağ O-102'de kuruldu
(5 iddia-özne çifti ölçüme bağlı, bağsız 0).
*Gravita'da üç yazıcı vardı ve landmark hiçbirinde değildi — bu hattın
ölçümü AYRI yapıldı, devralınmadı.*

### ③ izin metni — bugün kapatıldı
`NSCameraUsageDescription` 08-07'de yanlış bulunan saklama iddiasını hâlâ
taşıyordu (O-098). Düzeltildi; kapı artık plist METNİNİ tarıyor (O-099/O-100)
ve MUT-A'da kalıcı mutasyon vakası var (14/14).

### ④ platform eşiği — engel değil
`build.gradle.kts` `flutter.targetSdkVersion` diyor; **gerçek değere
çözüldü**: Flutter 3.41.1 SDK'sında `FlutterExtension.kt` →
**`targetSdk = 36` · `minSdk = 24` · `compileSdk = 36`**.
Play'in 31 Ağustos 2026 eşiği (targetSdk 36) **KARŞILANIYOR**.
**Pozitif kontrol:** SDK ağacı okunabildi — `flutter_tools/gradle` altında
**291 dosya**.

### ⑤ imza — 🔴 ENGEL, ve İKİYE BÖLÜNÜR
`android/app/build.gradle.kts` release bloğu şablonun TODO'sunu taşıyor:
```kotlin
release {
    // TODO: Add your own signing config for the release build.
    signingConfig = signingConfigs.getByName("debug")
}
```
`key.properties` YOK, keystore YOK.
**KESİN ÖLÇÜM (çıkarım değil, ARTEFAKTTAN):** `assembleRelease` koşuldu
(JDK 17 ile, `BUILD SUCCESSFUL` 3m9s) ve üretilen APK'nın imzası okundu:
```
Signer #1 certificate DN: C=US, O=Android, CN=Android Debug
```
→ Release yapısı **sessizce debug anahtarıyla** imzalanıyor.
**Pozitif kontrol:** aynı desen imzası BİLİNEN bir projede isabet ediyor —
LifeOS `android/app/build.gradle.kts`: `key.properties` okuma +
`signingConfigs` + eksikse geri-düşme yorumu.
**BÖLÜNME (yöntemin şartı):**
* **⑤a hat-yereli** — `signingConfigs` yapılandırması + **sessiz düşmeyi
  engelleyen kapı** (release, debug anahtarına düşerse ADIYLA ötmeli)
* **⑤b kurucu** — keystore'un kendisi (sır)
⚠️ ⑤a'yı ⑤b'nin altına saklamak, hat-yereli işi *"erişim bekliyor"* diye
bekletirdi. Ayrı satır.

### ⑥ gizlilik manifesti — engel değil
`ios/Runner/PrivacyInfo.xcprivacy` VAR; anahtarlar: `NSPrivacyTracking`
(false) · `NSPrivacyTrackingDomains` · `NSPrivacyCollectedDataTypes` ([]) ·
`NSPrivacyAccessedAPITypes` ([]). Kendi kapısı (`validate_privacy_manifest.py`)
beyanı kodla **iki yönde** denetliyor ve yeşil (29 sevk edilen kaynak,
5 required-reason kategorisi).

### ⑦ ikon + açılış görseli — 🔴 ENGEL
İkon **doğrudan görüntülendi**: Flutter'ın varsayılan mavi logosu.
Açılış görselleri: `LaunchImage{,@2x,@3x}.png` → **üçü de 68 bayt** (boş
yer tutucu). İkon/açılış yollarına dokunan tek commit kabuğun doğuşu
(`b5bd37c`).
⚠️ **Pozitif kontrolüm ilk denemede TABAN KURAMADI:** şablonla bayt
karşılaştırması yapmak istedim, ama Flutter şablonundaki dosya bir
`.img.tmpl` yer tutucu ve **boş** (md5 = boş dizgenin md5'i). O
karşılaştırmadan hüküm çıkmaz — kalem **görsel doğrulamayla** kapatıldı.
*Kontrolün başarısız olduğunu söylemek, sonucu ondan türetmiş gibi
yapmaktan iyidir.*

### ⑧ mağaza iddiaları — 🔴 ENGEL (08-07'nin "göremiyorum"u ÖLÇÜLDÜ)
* Depoda mağaza taslağı dosyası **YOK** — pozitif kontrol: aynı desen
  JabLab'ın `docs/store/listing.json`unu buluyor (yani arama çalışıyor).
* **ASC tarafı ölçüldü** (salt-okuma): sürüm `1.0` yerelleştirmesi →
  `description: null` · `keywords: null` · `promotionalText: null` ·
  `supportUrl: null` · `whatsNew: null`; **ekran görüntüsü seti: 0**.
08-07 raporu *"App Store Connect'e bakamıyorum"* demişti; bu tur baktı.

### ⑨ otomatik yayın — 🟠 AÇIK KARAR (Lissom'un kalemi, bizde UYGULANABİLİR)
ASC kaydı **VAR**: app `6794717868` — *Ostinato: Music Practice*
(`com.yulalab.ostinato`, sku `yula-ostinato-2026`).
Sürüm `1.0` · `appStoreState: PREPARE_FOR_SUBMISSION` ·
**`releaseType: AFTER_APPROVAL`** → gönderilip onaylandığı an
**kendiliğinden yayımlanır.** Bugün engel DEĞİL (gönderim yok) ama
**sessiz bir karar** ve gönderim günü varsayılan olarak devrede olacak.
*JabLab'da bu kalem uygulanamazdı (ASC kaydı yok); bizde uygulanabilir ve
AÇIK.*

### ⑩ cihaz kanıtı — 🔴 ENGEL
Cihaz koşumu artefaktı YOK (`docs/evidence` 35 dosya okunabiliyor — yani
dizin taraması çalışıyor, kanıt yokluğu araç kusuru değil). Uygulama bunu
kendi Ayarlar ekranında kullanıcıya söylüyor:
*"Nothing here has been verified on real hardware."*
Ürünün tek işi kameradan postür ölçmek; simülatörde kamera yok.

### ⑪ sürüm — 🟠 AÇIK KARAR
`pubspec.yaml` → `version: 1.0.0+1`. Bu bir ölçüm değil **beyan**: cihazda
hiç koşmamış bir ürün *"1.0"* diyor. `0.x` *"ön sürüm"* derdi.

### ⑫ araç zinciri — 🟠 ORTAM (teşhis hat-yereli, düzeltme venture-ötesi)
`./gradlew :app:assembleDebug --dry-run` → **BUILD FAILED**, mesaj çıplak
bir sürüm dizgesi: `25.0.2`.
**Katman kendi ağacımda ölçüldü, JabLab'ın teşhisi DEVRALINMADI:**
* depoda `25.0.2` dizgesi **hiç geçmiyor** → NDK atfı **dayanaksız**
* aktif JDK: **Temurin 25.0.2** ← hata dizgesiyle birebir
* NDK pini yok (`flutter.ndkVersion`)
* `JAVA_HOME=…/temurin-17.jdk/… ./gradlew … --dry-run` → **BUILD SUCCESSFUL**
→ Kusur **makinede**, depoda değil. Kalıcı çözüm (makine geneli JDK) LifeOS
ve Burun Farkı'nı da etkiler → **venture-ötesi**, hat yalnız teşhis eder.
Depoya makineye özel bir yol **YAZILMADI**.

---

## Yetenek gediği ≠ yayın engeli (listeyi uzatmadım)

Bunlar **engel değil** ve listede engel olarak sayılmadı:
* canlı ölçüm yalnız `trunk_tilt` (1 açı, 4 landmark) — ürün bunu **dürüstçe
  söylüyor**, dolayısıyla sevk edilebilir bir yetenek sınırı
* içerik ince (3 çalgı · 28 ders · 10 kilitli) — her kilit gerekçeli
* mikrofon yok — kapatılmış bir sınır, hiçbir yüzey vaat etmiyor
* el-landmark modeli / omuz-yüksekliği metriği — kuyrukta, engel değil

## Bir sonraki adım

**Hat-yerelinde açık tek iş ⑤a.** Kalan beş engel/karar kurucuda; ⑫'nin
kalıcı düzeltmesi venture-ötesi.
