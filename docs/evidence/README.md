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

## ⚠️ ALINAMAYAN KANIT — isimle

**Gözlem işaretinin (cue) ekran görüntüsü YOK.** İki sebep, ikisi de gerçek:
1. İşaret 3 ardışık sapmadan sonra doğar ve **30 sn cooldown**'a girer — yani
   döngü başına ~1,3 sn görünür. Bu doğru ürün davranışı (sürekli konuşan bir
   gözlem, gözlem değil arka plan gürültüsüdür), ama yakalama penceresi dar.
2. Simülatör **paylaşımlı** ve tur sırasında kardeş bir oturumun uygulaması
   öne geçti. Cihaz çekişmesine girilmedi (koordinatör talimatı).

**İşaretin kendisi DETERMİNİSTİK olarak kanıtlı** — `test/widget_test.dart`:
`İKİZ: sürdürülen sapmada işaret GÖRÜNÜR ve KAYNAĞINI taşır` (cümlede
"None of the 7 guitar teachers…") · `işaretteki sayı BAŞLIKTAKİ sayıyla aynı
kalır` · `banda dönünce işaret SUSAR`. Ekran görüntüsü tasarım turuna devredildi.

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
