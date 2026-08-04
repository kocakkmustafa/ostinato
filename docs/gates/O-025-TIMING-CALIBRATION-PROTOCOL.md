# O-025 — zamanlama kalibrasyon protokolü (config alanı DEĞİL, protokol)

**Koordinatör hükmü 2026-08-04, seçenek (b):** kalibrasyon alanı config'e ŞİMDİ
açılmaz. Gerekçe kendi ailemizden: **okuyucusuz alan yaşamaz.** Derecelendirme
yokken config'e kalibrasyon alanı koymak süs-alan doğurur ve bayatlar
(L-178/K9 sınıfı — "bayrak var, tüketicisi yok"un ikizi). Alan, OKUYUCUSUYLA
BİRLİKTE doğar; bu belge o gün hazır olsun diye yazıldı.

**Kapı-şartı aynen duruyor:** hiçbir çalgıda zamanlama DERECELENDİRİLMEDEN
önce O-025 kapanır.

---

## 1. Ölçülen olgu

`MetronomeAligner`, tam ızgarada çalınan notayı **erken** okur. Bu bir hata
değil, analiz geometrisinin sonucudur — ve **öngörülebilir olduğu ölçüldü.**

## 2. Ayırt eden deney (neden "gecikme" değil "geometri")

Soru: sabit bir dedektör gecikmesi mi, pencere geometrisi mi? Ayırt eden
şey basit: **sabit gecikme `frameMs`'ten BAĞIMSIZ olurdu.**

| frameMs | hopMs | medyan sapma (ms) | sapma/frameMs |
|---:|---:|---:|---:|
| 23 | 3 | −3,88 | −0,169 |
| 23 | 6 | −0,75 | −0,033 |
| 32 | 3 | −5,36 | −0,168 |
| 32 | 6 | −3,28 | −0,102 |
| **46** | **6** | **−8,29** | **−0,180** |
| 64 | 6 | −15,06 | −0,235 |
| 92 | 6 | −26,34 | −0,286 |

**Sapma frameMs ile ölçekleniyor → GEOMETRİ.** `hopMs` de etkiliyor (23 ms
çerçevede hop 3 ile −3,88, hop 6 ile −0,75): uyarlamalı eşik penceresi
(`medianWindow × hop`) de denklemde. Yani sapma **üçlünün** fonksiyonu:
`(frameMs, hopMs, medianWindow)`.

*Ölçüm: 2026-08-04 · ostinato_audio 0.1.0 · motion_core-v0.8.6 ·
`SyntheticTone.notesAt` 5 nota / 120 bpm · C5.*

## 3. Düzeltmenin işe yaradığı KANITLANDI

Kusursuz ızgaradan **ölçülen** sabit (uydurulmuş değil) onset damgalarına
eklendi:

| girdi | HAM | KALİBRE |
|---|---:|---:|
| acele 40 ms | 49,33 | 41,04 |
| geç 40 ms | 31,28 | 39,57 |
| kusursuz | 8,29 | 1,25 |

**Asimetri 18,05 ms → 1,47 ms (12×).** Asıl zarar buydu: aynı büyüklükteki
hata, acele edende geç kalandan ~18 ms daha ağır raporlanıyordu — yani
derecelendirme açılsaydı acele eden öğrenci sistematik olarak cezalandırılırdı.

## 4. Protokol — alan doğduğu gün izlenecek adımlar

1. **Kalibrasyon sabiti KOMBİNASYON BAŞINA ölçülür.** `(frameMs, hopMs,
   medianWindow)` üçlüsü değişirse sabit ARTIK GEÇERLİ DEĞİLDİR. Bir
   çalgının `signalConditioning`i değişti mi, sabit yeniden ölçülür —
   config'in kendi kuralıyla aynı mantık ("filtre ve eşik AYRILMAZ").
2. **Ölçüm yolu:** kusursuz ızgaralı sentetik girdi → gerçek
   `OnsetDetector` → gerçek `MetronomeAligner` → medyan işaretli sapma.
   `AF-008-five-note-timing` düzeneği bunun hazır hâli.
3. **Sabit, ölçüldüğü kombinasyonun damgasını taşır:** `frameMs/hopMs/
   medianWindow` + tarih + motor sürümü. Damgasız sabit, bir sonraki
   sürümde sessizce yanlış olur (O-024 sınıfı: bayat gerekçe).
4. **Asimetri kapanışı KANITLANIR, varsayılmaz:** acele/geç varyantları
   kalibre hâlde ölçülür ve fark raporlanır. Tek "kusursuz" varyant bunu
   gösteremez (AF-008'in üç-varyant gerekçesi).
5. **Gerçek kayıtta yeniden ölçülür.** Buradaki sayıların hepsi SENTETİK
   girdiden. Gerçek çalgı sesinde atak zarfı farklıdır; sabit değişebilir.
   Sentetikte ölçülmüş bir sabiti gerçek kayda uygulamak, kalibrasyonu
   varsayım hâline getirir.

## 5. Alanın doğacağı gün — ne birlikte gelir

`signalConditioning` yanında ölçülmüş bir kalibrasyon alanı + **onu okuyan
kod** + `--check` benzeri bir tazelik kapısı (kombinasyon değişti mi sabit
yeniden ölçüldü mü). Üçü birden gelmezse alan yine süs olur.

**Bugün zarar YOK:** zamanlama hiçbir çalgıda derecelendirilmiyor
(piyano `note_timing_ms` ölçülür-puanlanmaz, gitar `strum_timing_ms`
kapısı indirildi — M-O-65).
