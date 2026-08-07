# Kapı Envanteri — Ostinato

**Tarih:** 2026-08-07 · **Kaynak:** JabLab'ın kapı envanteri deseni (J-126),
koordinatör aktarımı.

> ### Aracın kuralı
> **Kapı kurmak bir iş değil, İKİ iş: kapıyı kurmak ve KAPSAMINI YAZMAK.**
> İkincisi atlanınca kapı yeşil kalır ve o alanda kimse bakmaz —
> ***yeşil bir kapı, bakılmayan bir alan üretir.***

**Biçim (bulgu üreten iki kural):**
① Soru **dışarıdan**: *"bu kapı neyi **ÖLÇMÜYOR**?"* — *"ne ölçüyor"* diye
sorulursa liste özetlerle dolar ve kapsam boşluğu çıkmaz.
② **Kanıt sütunu zorunlu:** kapsamı nasıl biliyorum · negatif ikizi var mı
(mutasyonla sınandı mı).

**Kör nokta sınıfı** (J-125): `algı` → yalnız göz kapatır · `kod` →
kapanabilir · `yöntem` → ölçüm yöntemi değişmeli.

---

## 🔴 Bu envanteri YAZARKEN çıkan bulgu (O-055)

Araç kendi işini yaptı. **Kural C'nin kapsam beyanı bayatlamıştı:**

`library.json`da **14** kullanıcı-yüzeyi proza alanı var; kural **2'sini**
kolluyordu (`honesty.measured` + `blurb`). **Üçünü kural yazıldıktan SONRA
ben ekledim** (`instrumentSpecificGap` · `outOfScopeDerived` ·
`promotionPath.unblockedBy`) ve hiçbiri kapsama girmedi.

Denetlenmeyen kapsamda **üç canlı ihlal** vardı:

| yüzey | iddia | gerçek |
|---|---|---|
| `courses[].goal` gitar | *"learn to **hear** when you're playing the right open chord"* | mikrofon girişi yok (O-040'ın **7.** örneği) |
| `courses[].goal` şan | *"standing and **singing**"* | `SUSTAIN` fazı `periodicity` ile açılır = ses tetikli (O-047 kardeşi) |
| `demoOnlyReason` ×3 | *"You see your own elbow and forearm angles, **live**"* | canlı dirsek ölçümü **YOK** |

Üçüncüsü şeklen tanıdık: **ekran dürüsttü, içerik değildi.**
`lesson_demo_screen.dart` *"Your elbow angle, **when this is live**"* diyor ve
figürün kolları tam bu yüzden **kesikli** çiziliyor — ama `library.json` "canlı
görüyorsun" diyordu. İki temsil, çelişen taraf içerikte.

**Yapısal düzeltme — kapsam TERS ÇEVRİLDİ.** Artık olumlu yollar sayılmıyor;
**yokluk anlatan yollar İSİMLE muaf, geri kalan her proza alanı denetleniyor.**
Yeni bir alan eklenince kapsam kendiliğinden genişler; muafiyet istiyorsa
yazılması *gerekir* ve o yazım bir gözden geçirme anıdır.
Kapsam **6 → 13** olumlu alan. Ayrıca kural D **canlılık eksenine** genişletildi.

---

## Envanter

### 1. `validate_surface_honesty.py` — ALTI kural
**Ölçtüğü:** kullanıcının okuduğu her metin (`lib/**.dart` literalleri + kabuğa
giden 3 JSON varlığı) × vaat dili · yetenek↔izin · olumlu iddia ↔ ses ·
skor/canlılık ekseni · saklama iddiası · **dil (F)**.

| ÖLÇMEDİĞİ | kanıt (nasıl biliyorum) | sınıf |
|---|---|---|
| **Dart yorumları** — bilerek (bize yazılır) | `strip_dart_comments()` tarama öncesi söküyor | kapsam-dışı **karar** |
| **Tanımlayıcı-biçimli string'ler** (`Key`, asset yolu) | `IDENTIFIER_LIKE`; ölçüldü: `Key('onboarding-microphone-card')` kuralı tetikliyordu, hedefi yanlıştı | kapsam-dışı **karar** |
| **Cümlenin DOĞRULUĞU** — yalnız SINIFINI ölçer | kural B "microphone" der, cümlenin gerçekten doğru olduğunu bilmez | **yöntem** |
| **`packages/` içindeki metin** | `DART_ROOTS = ["lib"]`. ÖLÇÜLDÜ (2026-08-07): `packages/*/lib`de kullanıcı-cümlesi biçiminde string YOK — ama bu bugünün olgusu, kapı onu KOLLAMIYOR: yarın eklenirse sessizce kapsam dışı kalır | **kod** ⚠️ |
| ~~Türkçe sızıntı~~ | **KAPANDI (kural F, aynı tur):** beyan edilen dil `library.json`ın `language` alanından OKUNUR (sabitlenmedi — TR yerelleştirmesi gelince kural kendini uyarlar). 241 metin kontrol ediliyor. TANI metni (`assert`/`throw`) muaf: release'te sökülür ya da framework yüzeyine düşer, `Text()`e girmez | ✅ |
| Negatif ikiz | MUT-1/2/3 · J · N/O · Q — **6 mutasyon, hepsi ısırdı** | ✅ |

### 2. `validate_color_tokens.py` — renk + tipografi
**Ölçtüğü:** her metin rengi token'dan gelir · ham `TextStyle` yasak.

| ÖLÇMEDİĞİ | kanıt | sınıf |
|---|---|---|
| **`copyWith(color:)` yolu** — JabLab'ın J-126 bulgusu | ölçüldü: `grep -c "copyWith(color" lib` = **0**, bu yol Ostinato'da KULLANILMIYOR; JabLab'ın kusuru bende YOK | ✅ ölçüldü |
| **Metin-DIŞI renkler** (border/gölge/gradyan) | bilerek: eşikleri farklı (1.4.11 = 3.0), çoğu dekoratif | kapsam-dışı **karar** |
| **`ostinato_theme.dart`'ın kendisi** | token'ları TANIMLAYAN dosya; hex orada yaşar | kapsam-dışı **karar** |
| Negatif ikiz | MUT-L · MUT-P | ✅ |

### 3. `test/contrast_test.dart` — WCAG
**Ölçtüğü:** 12 ölçüm noktası, ekranda GERÇEKTEN oluşan renkten (alfa zemine
bindirilir), gradyanın **en kötü** durağından.

| ÖLÇMEDİĞİ | kanıt | sınıf |
|---|---|---|
| **AYIRT EDİLEBİLİRLİK** — luminans ölçer | dosyanın başında isimli sınır; iki ton aynı luminansta olup ayrılmayabilir | **yöntem** |
| **Metin-dışı öğeler** (ikon, çizgi, çubuk) — 1.4.11 = 3.0 | hiç ölçülmüyor; bant çubuğu/iskelet çizgileri kapsam dışı | **kod** ⚠️ |
| **Gerçek cihaz parlaklığı/kalibrasyon** | hesap sRGB varsayar | **yöntem** (O-036) |
| Negatif ikiz | MUT-K (eski ton geri kondu → kırmızı) | ✅ |

### 4. `validate_library.py` — 12 kural
**Ölçtüğü:** kilit gerekçesi · vitrin sayısı ↔ artefakt · demoOnly sözleşmesi ·
gözlem şeridi · `unblockedBy` zorunluluğu (kural 12).

| ÖLÇMEDİĞİ | kanıt | sınıf |
|---|---|---|
| **Gerekçenin DOĞRULUĞU** — uzunluk ve varlık ölçer | kural 10 "yer-tutucu görünüyor mu" diye bakar, iddiayı doğrulamaz | **yöntem** |
| **`goal` / `displayName` alanları** | kural listesinde YOK — O-055'in iki ihlali tam oradaydı | **kod** (kural C'ye devredildi) |
| Negatif ikiz | MUT-A 13/13 + MUT-I | ✅ |

### 5. `validate_references.py` — atıf + muafiyet canlılığı
**Ölçtüğü:** her atıf çözülüyor **ve** kendi çalgısının dünyasına çözülüyor;
muafiyetler kendi canlılık iddiasını ispat ediyor (O-045).

| ÖLÇMEDİĞİ | kanıt | sınıf |
|---|---|---|
| **Atıfın işaret ettiği şeyin DOĞRU olduğu** | varlık + kapsam ölçer, içerik değil | **yöntem** |
| Negatif ikiz | `--sabotage` 8 sınıf + MUT-G/H | ✅ |

### 6. `gen_out_of_scope.py --check` — türetim tazeliği
| ÖLÇMEDİĞİ | kanıt | sınıf |
|---|---|---|
| **`comingSoonInThisDiscipline`** (elle yazılan yarı) | bilerek: ayrı sınıf, betik dokunmaz | kapsam-dışı **karar** |
| Negatif ikiz | MUT-M | ✅ |

### 7. `validate_orphan_keys.py` — okunmayan anahtar (O-057)
**Ölçtüğü:** `library.json`daki her anahtarın bir tüketicisi var mı (parser
KAYNAĞINDAN türetilir, elle liste yok) + şema sürümü gerçekten doğrulanıyor mu.

| ÖLÇMEDİĞİ | kanıt | sınıf |
|---|---|---|
| **Diğer 20 JSON dosyası** (3 ruleset · taksonomi · referanslar · fixture indeksi) | yalnız `library.json` taranıyor; `fromJson` benzeri 7 parser var, biri kolllanıyor | **kod** ⚠️ |
| **Anahtarın DEĞERİNİN doğruluğu** | tüketici VARLIĞINI ölçer; `_wave` gibi kayıt alanları hiç sınanmaz | **yöntem** |
| Negatif ikiz | MUT-S (öksüz anahtar) · MUT-T (sürüm sabit kalırsa) · **MUT-U (VAKUM: parser regex'i bozulunca kapı "temiz" demiyor)** | ✅ |

### 8. `tools/evidence/` — ekran kanıtı (KAPI DEĞİL)
**⚠️ `run_gates.sh`a BAĞLI DEĞİL — elle tazelenir.** Bayat bir PNG
"doğrulandı" sanılabilir.

| ÖLÇMEDİĞİ | kanıt | sınıf |
|---|---|---|
| **İkon / emoji** | Material Icons + emoji fontu test koşumunda yok → boş kare; ürün kusuru DEĞİL ama **gerçek bir ikon kusurunu örtebilir** | **yöntem** (O-036) |
| **Cihaz DPI / güvenli alan** | 375×812 mantıksal, gerçek donanım değil | **yöntem** (O-036) |
| **Setup Check ekranı** | `MotionCameraController` platform kanalına takılıyor, test asılı kalıyor | **kod** (O-036) |
| **Tipografi — 2026-08-07'ye kadar** | tema kurulmuyordu, ham `TextStyle` blok glif çiziyordu (O-052) — **artık kapalı** | ✅ kapandı |

---

## Açık kalan kapı boşlukları (isimli)

1. ~~Dil kuralı yok~~ → **KAPANDI aynı tur (kural F).** ⚠️ Muafiyet İKİ KEZ
   yanlış çalıştı yazılırken: karakter-konumlu geri bakış önce çok-satırlı
   `throw`u kaçırdı, düzeltince tek-satırlık `assert`in kendi `;`sine takıldı.
   Satır penceresine geçildi. *Muafiyet, kuralın kendisi kadar sınanmalı —
   sessizce yarım çalışan bir muafiyet, olmayan bir kapıdır.*
2. **Diğer 20 JSON dosyası öksüz-anahtar taramasının dışında** — 7 parser var,
   biri kollanıyor.
3. **`packages/` metin taraması** — bugün kullanıcı metni YOK (ölçüldü), ama
   kapı orayı kollamıyor: yarın eklenen bir cümle sessizce kapsam dışı kalır.
4. **Metin-dışı kontrast (1.4.11)** — bant çubuğu, iskelet çizgileri, ayraçlar
   hiç ölçülmüyor.
5. **Kanıt üreteci kapı değil** — elle tazelenir.
