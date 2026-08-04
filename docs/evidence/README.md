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

## 🔴 AÇIK ŞÜPHE — gözlem işareti ÇALIŞAN UYGULAMADA görünmedi (O-032)

**Bunu "ekran görüntüsü alınamadı" diye yazmıyorum, çünkü öyle değil.**

Ölçülen üç şey:
1. **Değerlendirici işareti ÜRETİYOR.** Demo senaryosu doğrudan
   `PostureEvaluator`dan geçirildi: index 15'te `cue=true` (3. ardışık sapma),
   sonrasında cooldown'la bastırılıyor — tasarlandığı gibi.
2. **Widget işareti ÇİZİYOR.** Üç widget testi geçiyor: işaret görünüyor,
   cümlede "None of the 7 guitar teachers…" var, sayısı başlıktakiyle
   senkron, banda dönünce siliniyor.
3. **Çalışan uygulamada GÖRÜNMEDİ.** Aralık-dışı pencerenin ortasında
   (21,0° · 3. sapmadan çok sonra) defalarca yakalandı; işaret kutusu YOK.

Yani parçalar ayrı ayrı kanıtlı, **BİRLEŞİK CANLI HÂL kanıtlanmadı** — ve bu
tam olarak bu hattın kendi dersi: *"bağlandı ≠ canlı"*. Testlerin geçmesi,
çalışan uygulamanın üçüncü bir şey olduğu gerçeğini değiştirmiyor.

**Şüphe sınıfı (kanıtlanmadı, tahmin):** ekran ile sahte kaynak arasındaki
kablolama — muhtemelen `Timer.periodic` altındaki dinleyici/`setState`
yolunda, senkron `pushOne()` kullanan testlerin uğramadığı bir fark.
Yakalama zamanlaması ELENDİ: aralık-dışı pencere 7→15 kareye uzatıldı ve
pencerenin ortasında da işaret çıkmadı.

Kalan iş tur-2'ye devredildi ve isimli: **gerçek kamera bağlanmadan ÖNCE bu
şüphe kapatılır** — kamerayı, canlı yolu kanıtlanmamış bir yüzeye bağlamak
iki belirsizliği üst üste koyar.

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
