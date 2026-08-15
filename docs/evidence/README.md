# Tur-1 kanıt dosyası — canlı postür yüzeyi (2026-08-05)

**Kanıt sınıfı, iddiadan ÖNCE:** bu ekranların hiçbiri "kamera çalışıyor"
demez. Söyledikleri şu — *postür kareleri yüzeye ulaşıyor, tipli hâllerin her
biri kendi ekranını açıyor, bant ölçülen sayılarla çiziliyor ve gözlem işareti
sözleşmesine uyuyor.* Kaynak SAHTE ve ekranın en üstünde öyle yazıyor.

Cihaz: iPhone 17 Pro Max simülatörü · debug build · `motion_core 0.11.0 @ f13bdc9`.

| dosya | ne KANITLIYOR | ne kanıtlamıyor |
|---|---|---|
| `01-library.png` | Üç disiplin canlı; tanıtım metinleri `library.json`dan — dürüstlük kapılarından geçmiş metnin ta kendisi ekranda | ders içerikleri, kilitli/demoOnly yüzeyleri |
| `02-in-band-cue-silent.png` | Bant ölçülen sayılarla çizili (0,4°–6,4°, 7 eğitmen — sözleşme varlığından). Kullanıcı 3,0°: **"Within the range"** ve **işaret YOK** → pozitif ikizin sessiz tarafı, ekranda | — |
| `03-no-person.png` | Kişi görünmeyince AYRI ekran: *"We cannot see you yet… This is not an error"*. Kadraj dışı bir kullanıcı ile bozuk bir hat aynı ekrana düşmüyor | kamera gerçekten kişi kaybettiğinde aynı yola girdiği (tur-2) |
| `04-outside-range.png` | 22,0°: **"Outside the range we measure against"**, işaretçi bandın dışında | — |

## ✅ KAPANDI (2026-08-05) — gözlem işareti hiç kırık değildi (O-032)

**Kök neden bir kod arızası değildi — ölçüm YÖNTEMİ boşluğuydu.**

İki TAHMİN sırayla ölçüldü ve ikisi de ÇÜRÜTÜLDÜ:

1. `Timer.periodic`/`setState` yolu — `test/timer_path_test.dart` ile
   YANLIŞ çıktı (gerçek zamanlayıcı + tam senaryo, işaret DOĞUYOR).
2. Navigasyon/route sarmalayıcısı — `test/route_path_test.dart` GERÇEK
   `Navigator.push(MaterialPageRoute(...))` arkasında aynı tam senaryoyu
   koşturdu, ilk ateşleme sorunsuz çıktı → bu da YANLIŞ.

Yedi adayın hepsi elendi (değerlendirici · widget çizimi · zamanlayıcı/akış
yolu · demo senaryosu · yakalama zamanlaması · bayat ikili · route
sarmalayıcısı). **Canlı `flutter run` teşhisi** (cold-launch, iPhone 17 Pro
Max, geçici print-diagnostiği) evaluator çıktısını ve widget render'ını ayrı
ayrı logladı: işaret **5/5 ölçülen pencerede doğru ateşlendi ve doğru render
edildi** — tUs = 2.700.000 / 32.760.000 / 66.060.000 / 96.120.000 /
129.420.000.

**Düzeltme (koordinatör denetimi, 2026-08-05):** ilk yazımda bu dört aralık
"~30,06 saniyede bir" diye TEK bir periyot olarak özetlenmişti — YANLIŞ,
vitrin sayısı kendi dayanağını taşımıyordu. Gerçek aralıklar
**30,06 / 33,30 / 30,06 / 33,30 sn** (ALTERNATİF, ortalama **31,68 sn**).
Neden alternatif: cooldown tam 30.000.000 µs = 166,67 kare (180 ms/kare) —
tamsayı DEĞİL. "+167 kare" sıçraması demo senaryosunun 32 karelik turunda
İKİ farklı faza düşüyor: `i=15`ten +167 → `i=22` (hâlâ aralık-dışı → ANINDA
ateşler, 30,06 sn) · `i=22`den +167 → `i=29` (banda dönülmüş → sayaç
sıfırlanır, sıradaki aralık-dışı pencerenin 3. karesine dek 18 kare daha
beklenir, 33,30 sn) · bu ikisi sonsuza dek dönüşümlü tekrarlanır — jitter
DEĞİL, deterministik.

**Gerçek açıklama:** 30 saniyelik cooldown yüzünden işaret her ~31,68sn'lik
pencerenin yalnız **~%7,4'ünde (2,34sn / 31,68sn)** görünür kalıyor —
aralık-dışı olmak (lap'ın ~%47'si) çok daha yaygınken, işaretin *görünüyor
olması* nadir. Bu hattaki (ve önceki turlardaki) TÜM manuel/screenshot-tabanlı
repro denemeleri zamanlaması kontrol edilmeden rastgele bir ana denk geldi ve
neredeyse hep "cooldown aktif" penceresini örnekleyip bunu "işaret hiç
doğmuyor" sandı. Mekanizma — evaluator, widget, route — baştan beri doğru
çalışıyordu.

**Kod DEĞİŞMEDİ.** Kalıcı kanıt iki yeni testte: `test/route_path_test.dart`
(route elendi) ve `test/cue_cooldown_visibility_test.dart` (gerçek 30sn
cooldown + gerçek demo senaryosu + gerçek `PostureScreen`: ilk ateşleme
tick 15 → banda dönünce silinir tick 28 → cooldown boyunca tick 45-181
sessiz → ikinci ateşleme TAM tick 182'de — canlı simülatör ölçümüyle
birebir). Ders defterde: **O-035** — düşük-görünürlük periyodik davranış,
tek-anlık gözlemle kolayca "kırık" sanılır.

Tur-2 (gerçek kamera) artık önünde bloke edici bir şüphe YOK.

## Bu tur ekran kanıtının YAKALADIĞI İKİ KUSUR

Testler yeşilken ekrana bakmasaydım ikisi de kaçardı:

1. **Bayat işaret metni.** Başlık "You: 18.0°" derken işaret "You are at 20°"
   diyordu — çözülmüş METİN saklanıyordu. Cümlenin gücü referansı ve ANLIK
   ölçümü yan yana koymasından geliyor; biri bayatlarsa cümle kendi iddiasını
   çürütür. Düzeltme: yük saklanır, metin her karede yeniden çözülür.
2. **Sahte kaynağın saati döngüde SIFIRLANIYORDU.** `tUs`, senaryo indeksinden
   türetiliyordu; senaryo başa sarınca damga geri gidiyor ve cooldown bir daha
   asla dolmuyordu — işaret ilk turdan sonra sessizce ölüyordu. Değerlendirici
   monotonik saat varsayar ve haklıdır; **sözleşmeyi çiğneyen taraf
   test-ikizinin kendisiydi.** Senkron `pushOne()` kullanan widget testleri
   bunu göremezdi (orada döngü hiç dönmüyor).

İkisi de regresyon testine bağlandı.

## 🎥 Tur-2 kanıtı — gerçek kamera BAĞLANDI (2026-08-05)

**Kanıt sınıfı, iddiadan ÖNCE (tur-1'in aynı disiplini):** bu ekran "kamera
çalışıyor" demez. iOS simülatöründe kamera DONANIMI yok — söylediği şu:
*plumbing gerçek, izin akışı gerçek, çıkmaz-sokak yok; postürün GERÇEKTEN
ölçüldüğü kanıtı cihaz-günü release-gate'tedir.* Bağlandı ≠ canlı.

| dosya | ne KANITLIYOR | ne kanıtlamıyor |
|---|---|---|
| `06-tur2-camera-permission-honest-state.png` | Cold-launch → Guitar dersine dokun → **gerçek** `Permission.camera.request()` → `MotionCameraController.start()` zinciri koştu; sim'de izin `permanentlyDenied` döndü ve ekran **PermissionDeniedPermanent** hâlini doğru çizdi ("Open Settings", "tekrar dene" YOK). Banner artık **"LIVE CAMERA"** diyor — SAHTE değil. Çıkmaz-sokak YOK: ekran çöküp asılı kalmadı, tipli bir hâl doğdu | gerçek görüntüden postür ölçümü, izin VERİLDİĞİNDE akan yol (sim'de izin asla verilemiyor — donanım yok) |

**Katman katman kanıt:**
- `packages/ostinato_posture/test/camera_posture_adapter_test.dart` (5 test): motion_core'un aile-geneli `StandardJoints.trunkTilt` tanımı + izotropik düzeltme (M-F-30/J-028) + gövde-yalnız güven kapısı (G-038 `xExtent` tuzağı dahil) — sentetik landmarklarla, kamerasız, deterministik.
- `flutter build ios --simulator --debug` ve `flutter build apk --debug`: iki platform da temiz derleniyor (MediaPipe pod'ları tur-1'den + `permission_handler`/`path_provider` bu turdan).
- Canlı sim koşumu (yukarıdaki ekran): gerçek `Navigator.push` → gerçek izin isteği → gerçek `CameraFailure` çevirisi → tipli ekran. Hiçbir `flutter:` istisnası loglanmadı.
- `./tools/run_gates.sh`: **16/16 yeşil**, yeni test dosyası dahil.

**İsimli, henüz cihazda sınanmamış sınırlar (release-gate borcu):**
1. **Ön kamera seçimi** (`CameraLens.front`) — Gravita'nın arka-kamera kararından farklı; kullanıcı telefonu kendine bakacak şekilde (ayna kurulumu) yerleştirir varsayımı, gerçek kullanımla sınanmadı.
2. **M-O-08 açılı-oturuş sınırı** (motion_core `normalization.dart`'ın kendi ölçülü kaydı): izotropik düzeltme yalnız 2B izdüşümü düzeltir; gitar/piyano diyagonal oturuşta 3B eksen derinlikte kısalabilir. `trunk_tilt` düzlemsel olduğu için doğrudan etkilenmeyebilir ama gerçek etkisi CİHAZDA ölçülmeden kapatılmış sayılmaz.
3. **Gerçek MediaPipe çıkarımı** hiç çalışmadı (sim'de kamera yok) — `judgedRatio`, gerçek güven dağılımı, gerçek gecikme (`infUs`) hiçbiri bilinmiyor; hepsi "cihazda doğrulanacak" etiketli.

Yüzey (sealed hâller, bant çizimi, gözlem işareti mantığı) **HİÇ DEĞİŞMEDİ** —
yalnız kaynak sahte'den gerçeğe geçti, tur-1'in taahhüt ettiği gibi.

## O-141 kanıt yeniden-üretimi (2026-08-16) — H-15 tam karşılanarak

**Neden var:** `O-141` ölçtü ki `O-124`'ün "sekiz adım, her biri ekran
görüntüsüyle" dediği tur-3 cihaz/simülatör yürüyüşünün yalnız **1/8** karesi
(`15-tur3-device-walk-setupcheck.png`) commit'lenmişti — yedisi hiç yok. Bu
bölüm o yedi kareyi **kendi adanmış simülatöründe** (`ostinato-hatti`,
`DAE5E512-F2DD-46AA-9FB0-5147EE8009BA`) yeniden üretir; H-15'in ön-plan
belirsizliği artık **yapısal olarak imkânsız** (paylaşılan simülatörde değil,
tek-uygulamalı kendi simülatöründe alındı — her karede `DEBUG` bandı + Ostinato
içeriği doğrulanabilir).

Cihaz: `ostinato-hatti` simülatörü (adanmış) · debug build (bu turun `flutter
build ios --simulator --debug`'ı, D10 doğrulamasıyla AYNI artefakt) ·
`motion_core/motion_camera 0.11.0/0.1.2 @ f13bdc9`.

| dosya | ne KANITLIYOR | ne kanıtlamıyor |
|---|---|---|
| `17-tur5-walk-1-onboarding-welcome.png` | Onboarding perde 1, taze kurulum | — |
| `18-tur5-walk-2-onboarding-scope.png` | Perde 2 — `3/28/10/3` sayıları `library.json`dan türetilmiş (elle yazılmamış, `_LibraryFacts.from`) | — |
| `19-tur5-walk-3-onboarding-sensors.png` | Perde 3 — mikrofon-yok/video-atılır beyanları ekranda, `Open the library` düğmesi | — |
| `20-tur5-walk-4-library.png` | Kütüphane, üç canlı çalgı kartı. **START HERE şeridi bu karede katlama altında** (`D16` henüz uygulanmadı — ayrı iş) | — |
| `21-tur5-walk-5-guitar-instrument.png` | Gitar sayfası — "What we actually measure" dürüstlük kutusu, 7 öğretmen/2.24° | — |
| `22-tur5-walk-6-guitar-foundations-course.png` | Foundations kursu, 4 ders listede (`Camera and space` GUIDE, üçü SCORED) | — |
| `23-tur5-walk-7-sitting-posture.png` | Sitting posture dersi, "Begin the setup check" düğmesi | — |
| `24-tur5-walk-8-setupcheck-camera-denied.png` | SetupCheck ekranı, **FRAME** aşaması — `O-126`'nın bulgusu bağımsız DOĞRULANDI: *"Camera access is off and the system will not ask again"* simülatörde tekrar üretildi | izin GERÇEKTEN reddedilmiş mi yoksa simülatörün TCC'si mi (O-126 hâlâ ⛔ ÖLÇÜLEMEDİ — bu tur onu kapatmadı, yalnız yeniden üretti) |

**🪤 Alet tuzağı (adıyla, bu turda üç kez ısırdı):** `Begin the setup check`
düğmesine yedi taptan sonra ancak sekizinci basıyor gibi göründü — gerçek
sebep koordinat değil, **MCP simülatör aracının kendi `screenshot` eylemi
BAYAT kare döndürüyordu.** `xcrun simctl io screenshot` ile DOĞRUDAN alınan
kare, MCP `screenshot`un gösterdiğinden FARKLI (güncel) durumu gösterdi —
dokunuş muhtemelen ilk denemelerde de inmişti, yalnız doğrulama aracı bunu
söylemiyordu. **Kural: bu simülatör MCP aracıyla doğrulama-kritik bir anda
tutarsız görünürse, `xcrun simctl io <udid> screenshot <path>` ile ikinci
kaynaktan doğrula** — `H-26`'nın "tek kaynaklı sayı doğrulanmamış sayıdır"
dersinin ekran-görüntüsü hâli.
