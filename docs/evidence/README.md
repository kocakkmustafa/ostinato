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
129.420.000, yani ~30,06 saniyede bir, `cooldownUs=30_000_000` sabitiyle
birebir tutarlı.

**Gerçek açıklama:** 30 saniyelik cooldown yüzünden işaret her ~30sn'lik
pencerenin yalnız **~%8'inde (≈2,34sn)** görünür kalıyor — aralık-dışı olmak
(lap'ın ~%47'si) çok daha yaygınken, işaretin *görünüyor olması* nadir. Bu
hattaki (ve önceki turlardaki) TÜM manuel/screenshot-tabanlı repro denemeleri
zamanlaması kontrol edilmeden rastgele bir ana denk geldi ve neredeyse hep
"cooldown aktif" penceresini örnekleyip bunu "işaret hiç doğmuyor" sandı.
Mekanizma — evaluator, widget, route — baştan beri doğru çalışıyordu.

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
