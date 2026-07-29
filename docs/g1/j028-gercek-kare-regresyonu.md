# J-028 Gerçek-Kare Regresyonu — Ostinato Ölçümü

**Tarih:** 2026-07-29 · **Veri:** 9 hasat fixture'ı, ~50k kare, gerçek YouTube öğretim videoları (kabul edilen havuz) · **Araç:** `tools/analyze_frames.py` · **Çıktı:** `config/frame-analysis.json`
**Neden bu ölçüm:** M-F-30 kuralı kamera/füzyon metriklerinden **≥1 gerçek-kare regresyonu** istiyor; sentetik fixture bu hatayı yapısal olarak yakalayamıyor (sentetik iskelet zaten kare uzayda üretiliyor). Borç ödendi.

## 1. Yöntem

Aynı kare, aynı metrik (gövde ekseninin dikeyden sapması), **üç uzayda**:
- `world` — MediaPipe metrik 3D. Referans doğru cevap.
- `normalizedRaw` — ham 0-1 koordinat (x genişliğe, y yüksekliğe göre normalize).
- `pixelScaled` — normalize koordinatta y'yi H/W ile ölçekleyerek piksel geometrisini geri açma denemesi.

## 2. Sonuç

| Uzay | Medyan mutlak | Medyan **oransal** | En kötü oransal |
|---|---|---|---|
| ham normalize | 0.98° | **%41** | %62 |
| piksel-ölçekli | 0.53° | **%27** | **%74** |

**Mutlak dereceye bakmak yanıltıcı:** gövde ekseni zaten dikeye yakın olduğu için tüm açılar küçük (0.7°-8°). Eşik kalibrasyonunu bozan şey oransal hata — ve o %41.

### 2.1 Ham normalize sistematik olarak KÜÇÜK gösteriyor
Dokuz videonun **dokuzunda da** işaret negatif. Beklenen davranış bu: 16:9'da y, x'e göre 1.78× şişer, dolayısıyla `atan(dx/dy)` olduğundan küçük çıkar. Yani ham normalize uzayda kurulan bir "gövde eğik" eşiği **hep geç ateşlenir** — ve bu, gürültü gibi görünmediği için fark edilmez.

### 2.2 ⚠️ Piksel-ölçekli düzeltme yeterli DEĞİL
Beklentimin tersi bir sonuç: düzeltme medyanı iyileştirdi (%41→%27) ama **en kötü vakayı kötüleştirdi (%62→%74)**. Açı sınıfına göre ayırdım — her iki sınıfta da medyan iyileşiyor, ama uç değerler düzelmiyor:

| Sınıf | n | ham (medyan/en kötü) | piksel-ölçekli (medyan/en kötü) |
|---|---|---|---|
| C_frontal | 6 | %56 / %62 | %30 / **%75** |
| B_side_profile | 3 | %34 / %41 | %16 / **%52** |

**Yorum:** piksel-ölçekleme yalnız 2D izdüşümünü düzeltir; gövde ekseninin **derinlik (z) bileşenini geri getiremez**. Denek kameraya göre döndüğünde gerçek 3D eksen 2D'de kısalır ve hiçbir ölçekleme bunu telafi etmez. World uzayı gerçek 3D taşıdığı için bu sorunu yaşamaz.

## 3. Ostinato'nun kararı

**Kamera metriklerimin tamamı `measurementSpace: world`.** `pixel_scaled` aile kuralında izinli bir alternatif olarak duruyor ama **benim ölçümüm ikisinin denk olmadığını gösteriyor**: 2D'de kalan her düzeltme, açılı denekte çaresiz. Ostinato'da denek çoğu zaman açılı oturur (piyano yandan, gitar çapraz, çello sağ-ön çapraz) — yani en kötü vaka bizim normal vakamız.

→ Aile defterine **M-O-08** olarak bildirildi: kuralın "world **veya** pixel_scaled" ifadesi, açılı-denek app'leri için yanıltıcı olabilir; bir uyarı satırı önerildi.

## 4. Yan kazanç: B4 açı sınıflandırması otomatikleşti

Elle etiketleme yerine omuz hattının world-uzayı yönelimi kullanılıyor (frontal duruşta omuz vektörü kamera eksenine dik, profilde paralel). Bu havuzda: **6 frontal · 3 profil · 0 sağ-ön-çapraz.**

Bu, çello triyajındaki %7 bulgusunun W1'de de sürdüğünü gösteriyor: **öğretim videoları bizim standart açımızda çekilmiyor.** ReferenceBuilder pilotunun B4 kolu (metrik-başına açı-duyarlılık) bu yüzden ana kol olarak kalıyor — ve şimdi girdisi elle değil ölçümle üretiliyor.

## 5. Sınırlar
- 9 video, tek metrik (gövde eğimi). Omuz yükselmesi ve baş-çene açısı için ayrı regresyon gerekir — aynı araca metrik eklemek yeterli.
- Açı sınıfı eşikleri (25°/55°) şimdilik seçim; ReferenceBuilder pilotunda ayrışma ölçülünce kalibre edilecek.
