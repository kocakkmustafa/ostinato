# B4 — Havuz Büyüdü, Sayılarım Çürüdü (ve düzeltildi)

**Tarih:** 2026-07-29 · **Değişen:** havuz 11 → 26 fixture (şan 5 · piyano 10 · gitar 13)
**Neden bu belge:** Bir önceki turda `trunk_tilt` toleransını ölçüme bağlayıp "artık `expertPending` değil, veri-türevli" demiştim. Havuz büyüyünce o ölçüm **kısmen çürüdü**. Kayıt burada çünkü sessizce güncellemek, ilk ölçümü fazla güvenilir göstermek olurdu.

## 1. Piyanoda örneklem etkisi (7 → 10 take)

| Eklem | n=7 | n=10 | Fark |
|---|---|---|---|
| left_shoulder | 6.2° | **17.9°** | +11.7 |
| left_upper_arm | 5.8° | **19.2°** | +13.4 |
| trunk_tilt | 2.7° | **5.1°** | +2.4 |
| right_elbow | 15.3° | 16.7° | +1.4 (stabil) |
| left_forearm | 36.7° | 33.9° | −2.8 (eşiğin altına indi) |

**Okuma:** 7 take'teki 5-6°'lik sapmalar küçük-örneklem yanılsamasıymış. Üç eğitmen tesadüfen benzer oturunca "eğitmenler hemfikir" görünüyor; onuncu eğitmen geldiğinde gerçek dağılım ortaya çıkıyor. `right_elbow`ın stabil kalması (15.3→16.7) bunun kontrolü: gerçekten kısıtlı olan eklem örneklemle oynamıyor.

Olumlu tarafı: **piyanoda artık güvenilmez eklem yok** (`left_forearm` 33.9° ile eşiğin altına indi).

## 2. `trunk_tilt` düzeltmesi — config'e işlendi

Üç çalgıda ölçülen: şan **1.5°** (n=5) · gitar **3.8°** (n=13) · piyano **5.1°** (n=10).

Config'imde `noiseBand: 2` yazıyordu ve bu yalnız **en iyi çalgının en küçük örnekleminde** doğruydu. Düzeltildi:

| Alan | Eski | Yeni | Gerekçe |
|---|---|---|---|
| `noiseBand` | 2° | **6°** | En kötü ölçülen varyansın (5.1°) üstünde olmalı; altında kalırsa eğitmenlerin kendi aralarındaki farkı kullanıcıya "hata" diye okuruz |
| quality eşiği | 8° | **15°** | 8°, 5.1° varyansın yalnız 1.6 katıydı — eğitmen farkını hata saymaya başlardı. 15° ≈ 3 katı |

Metriğe `_toleranceSource: veri-türevli, ÖRNEKLEM-DUYARLI — havuz büyüdükçe yeniden ölçülür` notu eklendi. Bu, sayının nihai olmadığını config'in kendi içinde söylüyor.

## 3. Gitar ilk kez koşuldu (13 take) — ve şanla aynı dersi farklı sebeple veriyor

| Eklem | Sapma |
|---|---|
| **left_forearm** | **80.1°** ⚠️ |
| **left_elbow** | **36.8°** ⚠️ |
| right_forearm | 18.3° |
| right_elbow | 17.6° |
| trunk_tilt | 3.8° |

**Sol/sağ asimetrisi 4 kat** (80.1° vs 18.3°). Fiziksel olarak beklenen: sağ el (mızrap/pena) tek bir bölgede kalır, sol el (baskı) akora göre klavyenin her yerine gider. Yani **sol kolun tek bir "doğru yeri" yok — akora bağlı.**

Şandaki bulguyla aynı sınıf ama sebebi farklı: şanda kol serbest çünkü teknik onu kapsamıyor; gitarda sol kol serbest **değil**, ama doğru konumu bağlama (akora) bağlı. İkisinin çözümü de aynı olamaz:
- Şan → metrik kapsam dışı (M-O-09).
- Gitar → metrik **akor-koşullu** olmalı; "sol dirsek açısı" tek başına anlamsız, "F akorunda sol dirsek açısı" anlamlı olabilir. Bu, taksonomideki `G-WRIST-BENT`/`G-THUMB-OVER-NECK` kodlarının neden **el-yakın kadrajdan** (hand pool) beslenmesi gerektiğini de açıklıyor.

→ Karar: gitarda sol-kol metrikleri V1'de **kapalı**; açılması akor-koşullu referans gerektirir (W2+ konusu, DEFTER'e).

## 4. Yöntem dersi

Ölçüme dayanmak yetmiyor; **ölçümün örneklem duyarlılığını da beyan etmek** gerekiyor. Bir sayıyı config'e "veri-türevli" diye yazmak, onu dokunulmaz yapmıyor — havuz her büyüdüğünde yeniden koşulmalı. Bu yüzden pilot aracı tek komutla tekrar koşuluyor (`dart run bin/pilot.dart <çalgı>`) ve metrik kendi kaynağını `_toleranceSource` alanında taşıyor.
