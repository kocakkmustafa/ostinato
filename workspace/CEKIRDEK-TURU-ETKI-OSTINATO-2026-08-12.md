# 🔧 Çekirdek turu — Ostinato etki değerlendirmesi (2026-08-12)

> Kaynak gündem: `ventures/motion-core/workspace/CEKIRDEK-TURU-GUNDEMI.md`.
> Ölçüm ağacı: `ostinato/app` @ `feeb160`. **Kod yazılmadı · çekirdeğe
> dokunulmadı · pin'e dokunulmadı.**
>
> ⚠️ **Sayıyı şişirmemek için üç kalemi kendim ÇIKARDIM** (④⑦ · ② · ⑥).
> *Terfiyi zayıflatmak için değil, doğru kurmak için.*

## Özet — kalem başına tek satır

| # | kalem | beni etkiliyor mu | duruşum |
|---|---|---|---|
| 1 | C-195 kapanış garantisi | **EVET** | ✅ **DESTEK** + gündeme **düzeltme** |
| 2 | `worldLandmarks` | hayır | 🚫 **KARŞI-ÖLÇÜM** |
| 3 | pencere-koşulu | hayır (farklı tür) | 🚫 **yayılıma eklenmemeliyim** + kısıt #7'ye girdi |
| 4+7 | `SessionRecord` sayaç `int?` | **HAYIR** | 🚫 **KARŞI-ÖLÇÜM** (tip bende hiç yok) |
| 5 | kamera önizleme / texture | evet, sınıf aynı | ⚠️ **kendi açığım** — yokluğum İSİMLİ DEĞİL |
| 6 | tutuş-süresi primitifi | hayır | 🚫 **KARŞI-ÖLÇÜM** (`sustain` bende MÜZİKAL) |
| 8 | izin/gizlilik metni kapısı | **EVET** | ✅ **DESTEK** — referans uygulama bende |
| 9 | dürüst hâl ekranı bir EYLEM taşır | **EVET** | ✅ **DESTEK** — en yüksek şiddet bende |
| 10 | — | **ölçülemedi** | 🔴 gündemde **anılıyor ama TANIMLI DEĞİL** |

---

## ① C-195 — DESTEK, ve kısıt #6'da bir DÜZELTME

**Ölçüm:** `lib/app/camera_session.dart:60` → `Future<void>? _closing;`
**girintisiz = üst düzey = SÜREÇ-GENELİ.** Docstring'i de öyle diyor:
*"🔒 SÜREÇ-GENELİ KAPANIŞ KİLİDİ (O-076 · Choreia C-195 aktarımı)"*.

🔴 **Gündemin kısıt #6'sı benim kapsamımı yanlış tarif ediyor:** *"Gravita'nınki
süreç-geneli STATIC; **Ostinato'nunki 'aynı seans içindeki zorunlu ekran
zinciri'**"*. Ölçüm: *"zorunlu ekran zinciri"* benim **TETİĞİM** — yarışın
NEREDE doğduğu (Kurulum Kontrolü → `pushReplacement` → `LiveScreen.start()`) —
**kilidimin KAPSAMI değil.** Kapsam süreç-geneli.
→ **Etkisi terfinin şekline:** #6 kapsam-daralma riskini **bir** süreç-geneli
uygulamaya karşı yazmış; ölçüm **İKİ** gösteriyor (Gravita + Ostinato).
***Geniş kapsam seçimi sandığından güçlü.***

* **Neyi değiştirir:** kilit çekirdeğe taşınırsa üç dosyalık yerel çözümüm
  (session + iki çağrı yeri) çekirdek garantisine bağlanır.
* **Neyi KIRAR:** çekirdek **DAR** kapsam (seans-içi) seçerse benim korumam da
  daralır — bugün yakaladığım yarış **her dersin zorunlu yolunda**, tek bir
  seansın içinde değil.
* **Maliyet:** düşük (~25 satır + docstring, tek dosya).

## ② `worldLandmarks` — KARŞI-ÖLÇÜM, adıyla

**Ölçüm (pozitif kontrollü):** `worldLandmark*` → **0 dosya** ·
`.z` okuması → **0 satır** · **pozitif kontrol** `PoseLandmark` → **2 dosya**
(arama çalışıyor, sıfır gerçek).
Ve bu **eksiklik değil SEÇİM**: `camera_posture_adapter.dart` docstring'i
`trunk_tilt`in **düzlemsel** olduğunu yazıyor (yalnız x,y; `AngleKind.trunkTilt`
z'ye **hiç** bakmaz) — 3B dünya koordinatı gerektiren metrikler bilerek dışarıda.

> **JabLab'ın yanına ikinci karşı-ölçüm.** Kalem zaten 0/5; ben de
> **eklenmeyi reddediyorum.**

## ③ pencere-koşulu — yayılıma eklenmemeliyim, ama kısıt #7'ye GİRDİ

**Ölçüm:** `live_screen.dart:97-190` → `_hist` **240 karelik kayan pencere**,
ama yalnız **GÖSTERİM** için (`history:` grafiğe gidiyor). Koşul ayrı yerde:
`ostinato_posture/evaluator.dart:37-45` → `_consecutiveOut >=
consecutiveOutOfBandBeforeCue (3)` — **ardışık-kare bastırması.**

→ Bende **pencere üzerinde koşul değerlendirilmiyor**: pencere çizim,
koşul ardışıklık sayacı. **Yayılıma eklenmemeliyim.**
🔴 **Ama kısıt #7'yi GÜÇLENDİRİYOR:** Gravita korelasyon · JabLab oran ·
Lissom tetik · **Ostinato ardışıklık** = **dört farklı koşul türü.** Çekirdek
tek şekli dayatırsa **dörtten üçü** uyarlanamaz. Primitif *"pencere içinde BİR
KOŞUL değerlendir"* olmalı, koşulun TÜRÜ değil — gündemin kendi sonucuyla aynı,
bir örnek daha.

## ④+⑦ `SessionRecord` sayaç `int?` — KARŞI-ÖLÇÜM, adıyla

**Ölçüm (pozitif kontrollü):** `SessionRecord|workedSeconds|unitsCompleted|
unmeasuredUnits` → bende **0 dosya**. **Pozitif kontrol:** tip **pinli
çekirdekte VAR** (1 dosya) → arama çalışıyor; tip var, **ben kullanmıyorum.**
**Sebebi ölçülü, tesadüf değil:** hiçbir şey saklamıyorum (O-102 bağı: `lib/`
içinde 2 yazıcı, ikisi de ÖLÇÜM DEĞİL — karşılama biti + poz modeli asset'i).
Seans kaydı olmadığı için `workedSeconds`/`unitsCompleted` bende **ifade
edilecek bir olgu değil.**

> Koordinatörün ölçümü doğru: **bu kalem beni bağlamıyor.** Eklenmeyi
> **reddediyorum** — 2/5 ödedi, 3/5 olmuyor.

## ⑤ kamera önizleme / texture — SINIF AYNI, ama benim yokluğum SESSİZ

**Ölçüm:** `Texture(`/`textureId`/`registrar.textures` → **0 dosya** ·
`CameraPreview` → **0** · **pozitif kontrol** `motion_camera|CameraSession` →
**8 satır** (kamerayı gerçekten kullanıyorum, önizlemeyi göstermiyorum).
Kurulum ekranı önizleme yerine `_Skeleton` çiziyor (`setup_check_screen.dart:
182/192/202`, `dim:` bayrağıyla).

⚠️ **JabLab'dan AYRIŞTIĞIM yer — ve bu bir terfi kalemi değil, KENDİ AÇIĞIM:**
JabLab'ın yokluğu `PLACEHOLDER(asset)` + `unblocked by:` işaretçisi taşıyor.
**Bendeki kamera-önizleme yokluğu isimli DEĞİL** — `setup_check_screen.dart:369`
taşıdığı `unblocked by`, **oda-gürültüsü** kalemine ait. Yani sınıf aynı
(*yapılabilir, biz yapmadık*) ama **benim sessizliğim JabLab'ın adlandırdığı
yerde duruyor.** Adıyla bildiriyorum; sevk edilirse kapatırım (tek satır
işaretçi, kod değil davranış değişikliği yok).

## ⑥ tutuş-süresi primitifi — KARŞI-ÖLÇÜM, adıyla

**Ölçüm:** bende `sustain` **MÜZİKAL** — `config/instruments.v1.json:20`
`mono_pitch` motorunun verdikleri (`note · intonation · vibrato · sustain`) ·
`sustained_note_drill` config bayrağı · `onset_detector.dart` docstring'i.
Postürde geçen "sustained" ise **cue bastırması** (`_consecutiveOut >= 3`),
tutuş-süresi motoru **değil**: `HoldEngine|holdDurationUs|minHoldUs` → **0**.

> 3/5'e **dördüncü olarak eklenmemeliyim.** 📌 Ve hasat tarafındaki
> `hold_isolator` bir **ARAÇ** (offline pencere izolasyonu), ürün primitifi
> değil — o da sayıya girmemeli.

## ⑧ izin/gizlilik metni kapısı — DESTEK, referans uygulama bende

Bugün yazıldı (O-098 → O-104) ve gündemin iki bağlayıcı kısıtına **zaten
uyuyor**:
* kısıt #4 (*anahtar/kapsam TÜRETİLİR*): alan-adı beyaz listesi **yok** —
  `prose_values()` tüm string değerleri ada bakmadan yürüyor, ayıklama
  değerin **biçiminden**
* kısıt #5 (*kapsam plist ile sınırlı değil*): plist + Android manifest/strings
  + mağaza globları (`docs/store/**`, `fastlane/**`), mağaza dosyası **yokken
  bile** yol kurulu ve **uçtan uca sabotajla kanıtlı**
Ayrıca: MUT-A'da kalıcı mutasyon vakası (14/14) · iddia↔ölçüm bağı **iki
yönde** (özne başına, ölçüm ADRESİYLE) · 26 python kapısı.

* **Neyi KIRAR (tasarım şartı, karşı-ölçüm DEĞİL):** çekirdeğe taşınırken
  kapsamın **türetimli** kalması **şart**. Elle liste tutan bir sürüm
  JabLab'ın `description` yüzeyini **yeniden** kaçırır — o vaka bugün ölçüldü.
* **Maliyetim:** sıfır ek iş; kapı bende canlı.

## ⑨ "dürüst hâl ekranı bir EYLEM taşır" — DESTEK, en yüksek şiddet bende

**Ölçüm:** `live_screen.dart:5` `import … show openAppSettings` + `:566`
**gerçek çağrı**. Dört şiddetin en olgunu: ölü düğme yok · yola giden yol var ·
eylem **gerçekten** sistem ayarlarını açıyor.

## ⑩ — ölçülemedi, çünkü gündemde TANIMLI DEĞİL

Gündemin 42. satırı Lissom'un getirisini **④+⑦+⑩** diye yazıyor, ama tabloda
**`| 10 |` satırı YOK** (ölçüldü: 0 isabet; **pozitif kontrol** `| 9 |` → 1
isabet, yani tarama çalışıyor). Kalemin **numarası var, tanımı yok** →
değerlendiremedim. Koordinatöre bildiriliyor.

---

## Turun bana getirisi — dürüst toplam

**Üç kalem beni bağlamıyor** (②④⑦⑥ → karşı-ölçüm), **bir kalemde yayılıma
girmemeliyim** (③), **üçü destekliyor** (①⑧⑨), **biri kendi açığım** (⑤),
**biri tanımsız** (⑩).

> **Tur bana KAPI AÇMIYOR.** ⑧ ve ⑨ zaten canlı; ① çekirdeğe taşınırsa
> bakım yükümü azaltır ama bugün ifade edemediğim bir olgu yok.
> ***Getirim "yetenek" değil "bakım" tarafında*** — JabLab'ın durumunun
> tersi: onun darboğazı tüketicisi, benimki hiç değil.
