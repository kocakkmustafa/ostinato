# B4 — Çalgı-Başına Havuz: İkinci Ölçüm

**Tarih:** 2026-07-29 · **Karar:** M-F-41 (havuz çalgı-başına bölünür) · **Araç:** `tools/dart_pilot` (`dart run bin/pilot.dart <çalgı>`)
**Veri:** şan 5 · piyano 7 · gitar 1 fixture (gitar `minTakes=3`'ün altında — koşulamadı, dürüstçe boş).

## 1. Sonuç

Eğitmenler arası medyan sapma (= toleransın kaynağı), derece:

| Eklem | Karışık havuz | Şan | Piyano |
|---|---|---|---|
| trunk_tilt | 3.0 | **1.5** | **2.7** |
| left_upper_arm | 12.5 | 15.3 | **5.8** |
| left_shoulder | 13.3 | 15.8 | **6.2** |
| right_shoulder | 15.4 | 16.0 | **8.9** |
| right_upper_arm | 25.0 | 15.6 | **13.8** |
| left_elbow | 29.6 | 35.0 | 23.4 |
| **right_elbow** | 39.2 ⚠️ | 41.1 ⚠️ | **15.3 ✅** |
| right_forearm | 31.7 | 38.9 ⚠️ | 26.1 |
| left_forearm | 58.8 ⚠️ | 51.0 ⚠️ | 36.7 ⚠️ |

## 2. İki çalgı, iki farklı sebep — ve bu ayrım kararı belirliyor

**Piyanoda bölme İŞE YARADI.** `right_elbow` 39.2° → **15.3°**: güvenilmez sınıfından çıkıp kullanılabilir hâle geldi. Omuz ve üst kol yarı yarıya sıkıldı. Sebep açık: piyanoda enstrüman kolun nereye gideceğini kısıtlar — eller tuşlarda, dirsekler klavye yüksekliğine bağlı. Eğitmenler gerçekten aynı şeyi yapıyor, karışık havuz bunu gizliyordu.

**Şanda bölme İŞE YARAMADI** — hatta bazı eklemler kötüleşti (`left_elbow` 29.6→35.0). İlk refleks "havuz küçük, daha çok video lazım" demek olurdu. Ama veriye bakınca daha basit bir açıklama var ve pedagojiyle birebir uyuşuyor: **şanda kolun doğru yeri diye bir şey yok.** Şarkıcı jest yapar, nota tutar, elini nereye isterse koyar. Yani buradaki saçılma ölçüm gürültüsü değil, **gerçeğin kendisi**.

Bunun doğrulaması taksonomimizde duruyor: şanın 12 hata kodunun hiçbiri dirsek/önkol hakkında değil — hepsi omuz, baş-çene, gövde, nefes ve ses üzerine (`config/error-taxonomy.w1.json`). Veri ile pedagoji aynı şeyi söylüyor.

**→ Karar: şanda kol/önkol metriği ÖLÇÜLMEZ.** Havuzu büyütmek bunu düzeltmez çünkü ortada düzeltilecek bir şey yok. Bu, "referans yetersiz" değil "referans YOK, çünkü teknik böyle bir şey içermiyor" vakası — ve dürüstlük kutusuna öyle yazılır.

## 3. trunk_tilt — W1'in omurgası

Her üç kesitte de en sıkı uzlaşma: karışık 3.0°, şan **1.5°**, piyano **2.7°**. Üç farklı çalgının eğitmenleri gövde dikliğinde hemfikir. Bu, `voice@0.1.0`'daki postür kurallarının **ölçülmüş** veri temeli:

- Ölçülen eğitmen-varyansı ≈ **1.5°** (şan)
- `noiseBand` bundan küçük olamaz; tolerans varyanstan türetilir, uydurulmaz
- Bu sayı ruleset'e `trunk_tilt_deg` metriği olarak işlendi (`baseline: 0`, `noiseBand: 2`, tolerans `expertPending` yerine artık **veri-türevli**)

## 4. Sınırlar
- Gitar 1 fixture: `minTakes=3` sağlanmadı, **koşulmadı** (boş rapor > uydurma sayı). Hasat sürüyor.
- Örneklem küçük (5 ve 7 take). Sayılar yön gösterir; havuz büyüdükçe araç tekrar koşulur.
- Açı sınıfı ayrımı (B4'ün asıl sorusu) hâlâ test edilemiyor: havuzda **0 sağ-ön-çapraz**. Frontal/profil karşılaştırması çalgı içinde yeterli take olunca anlamlı olacak.
