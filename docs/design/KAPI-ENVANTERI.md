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

## 🧭 KATMAN TABLOSU — "hangi kelimeler" değil, "hangi KATMANLAR"

> **Kapı yazarken ilk soru:** *"hangi kelimeler"* değil, ***"hangi katmanlar"***.
> (JabLab: beş kapı kusurunun beşi de KATMAN kapsamıydı, kelime kapsamı değil.)

| katman | proza alanı | yüzey dürüstlüğü (A–F) | öksüz anahtar | not |
|---|---|---|---|---|
| `lib/**.dart` | — | ✅ (yorumlar sökülür) | — | |
| `assets/content/library.json` | 92 | ✅ | ✅ | ana içerik |
| `config/observation-cue-templates.golden.json` | 1 | ✅ | ⛔ | canlı cümle |
| `assets/config/posture-contract.json` | 0 | ✅ | ⛔ | üretilen |
| `config/rulesets/*.json` ×3 | 3 | 🟡 **yalnız `userExplanation`** | ⛔ | O-058 |
| `config/error-taxonomy.w1.json` | **91** | ⛔ **HİÇ** | ⛔ | ⚠️ en büyük taranmayan katman |
| `config/references/*.json` ×3 | 11 | ⛔ | ⛔ | artefakt |
| `packages/*/lib` ×2 | 0 (ölçüldü) | ⛔ | — | bugün metin yok |

**Ruleset katmanı iki kez yanlış ayarlandı, ikisi de ölçümle çıktı (O-058):**
① tamamı tarandı → üç Türkçe **mühendislik** kaydı ihlal sayıldı (yanlış-pozitif);
② dar tutulunca regex `[^.]+` dosya adındaki noktayı (`guitar@0.2.0-draft.json`)
geçemedi ve **hiçbir şey eşleşmedi — ama kapsam satırı "3 ruleset taranıyor"
YAZIYORDU.** *Yalan söyleyen bir kapsam satırı, hiç olmayandan kötüdür:
okuyan kişi orayı denetlenmiş sanar.* MUT-V yakaladı.

**Katman kapsamı İKİ YÖNDE de yanlış olabilir:** dar → kör nokta ·
geniş → yanlış-pozitif, ve ikincisi kapıyı güvenilmez kılıp susturulmasına yol
açar.

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
| 🆕 **ŞEMA SÜRÜMÜNÜN YÜKSELMESİ GEREKTİĞİ** — iki sayının **eşitliğini** denetler, yeni bir alanın onları **yükseltmeye zorladığını** DEĞİL | ölçüldü 2026-08-13 (O-117): `starterLessonId` eklendi, ikisi de 2'de kalsaydı kapı **SESSİZ** geçerdi; yükümlülük yazılı kuralda, kapıda değil. MUT-T yalnız *"biri değişip öteki kalırsa"*yı yakalar — *"ikisi de değişmezse"* onun kör noktası | **kod** (kapatılabilir: bilinen-alan kümesini dondurup karşılaştır) ⚠️ **bu turda KAPATILMADI** |
| Negatif ikiz | MUT-S (öksüz anahtar) · MUT-T (sürüm sabit kalırsa) · **MUT-U (VAKUM: parser regex'i bozulunca kapı "temiz" demiyor)** | ✅ |

### 7b. `validate_starters.py` — START HERE şeridi türetilmiş mi (O-117)
**Ölçtüğü:** canlı disiplin `starterLessonId` bildiriyor mu · kimlik gerçekten
var mı · starter `locked`/`demoOnly` DEĞİL mi · `_why_starter` dolu mu ·
**ekran kodu hiçbir ders kimliği taşımıyor mu** (türetim gerçekten türetim mi).

| ÖLÇMEDİĞİ | kanıt | sınıf |
|---|---|---|
| **Seçimin DOĞRU ders olduğu** — bildirilen kimliğin geçerliliğini ölçer, o dersin giriş kapısı olmayı HAK ETTİĞİNİ değil | kaynak `_why_starter`da (onaylı `Ostinato.dc.html`), kapı o kaynağın VARLIĞINA bakar, doğruluğuna değil | **yöntem** |
| **`library_screen.dart` DIŞINDAKİ ekranlar** — kimlik gömme taraması tek dosya | desen tüm ağaca koşulabilir ama şerit tek ekranda; başka ekran ders kimliği gömerse görünmez | **kod** |
| **Şeridin GÖRÜNÜRLÜĞÜ** — kalem var mı diye bakar, kullanıcı onu görüyor mu diye değil | ölçüldü: 375×812'de şerit katlamanın ALTINDA (`ensureVisible` gerekti) | **kapsam-dışı karar** (yerleşim koordinatörde) |
| Negatif ikiz | `--selftest` 6 mutasyon + pozitif ikiz · gerçek dosyada 3 sabotaj indi | ✅ |

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

## 🔁 TERS YÖN — "kendini emekliye ayırır" bir NİYETTİ (O-059)

> **Ölçüt (JabLab J-133):** *bir cümle sevk edildiyse, onu yanlışa çevirecek
> en MAKUL değişikliği sor. Makulse, kapı gerekir.*

Kural B/C/E "izin/kod yolu gelince kendini emekliye ayırır" diyordu. **Ölçüldü:
üçü de yalnız SUSUYORDU.** Mikrofon kablolandığı gün **20 cümle** (15
`library.json` + 5 `lib/`) sessizce yanlışa dönecekti ve hiçbir kapı bakmayacaktı.
*Kimse yalan söylemeye karar vermez; biri `Info.plist`e bir satır ekler.*

Artık simetrik: **yetenek YOKKEN iddia yasak, yetenek VARKEN yokluk-iddiası
yasak.** MUT-W: izin eklendi → **22 ters-yön ihlali**. MUT-X: saklayan kod
yolu eklendi → 2 ihlal.

⚠️ Bu deseni O-045'te `RUNTIME_REFS` için kurmuştum, sonra **aynı tek-yönlü
hâli üç kez daha yazdım.** Bir dersi bir yerde uygulamak, onu her yerde
uyguladığın anlamına gelmiyor.

## 🕳️ VAKUM KORUMASI — 27 betikten 3'ü

> *Rapor edilen sıfır, ölçülen sıfır sanılıyor.*

`run_gates`teki 16 kapının **13'ünde vakum koruması yoktu** — en büyüğüm dahil.
Bu gece kurduğum üçüne eklendi (`validate_surface_honesty` ≥150 metin +
≥3 varlık · `validate_color_tokens` ≥30 çağrı · `gen_out_of_scope` >0 kalem).
MUT-Y: `DART_ROOTS` bozuldu → kapı "temiz" DEMEDİ, VAKUM dedi.
**Kalan 10 kapı hâlâ korumasız — isimli boşluk.**

## 🧬 POZİTİF İKİZ — 31 desen, 0 ikiz (O-061)

> **Vakum kapısı "hiç bulamadım"ı yakalar; pozitif ikiz "aracım BOZUK"u.**
> İkisi ayrı arıza: vakum sayıya bakar, ama kapsam DOLU olup desenin kendisi
> bozuksa sayı yüksek kalır ve kapı yine sahte-yeşil olur.

Bu gece **üç kez** oldu ve **üçünde de kapsam doluydu**: `BARE_HEX` kapanış
parantezi · ruleset yolundaki `[^.]+` · tanı bağlamı geri bakışı.

`--selftest` eklendi (run_gates'te ayrı kapı): **22 desen** bilinen bir
örneğe karşı sınanıyor, renk kapısında hepsi **olumlu VE olumsuz** örnekle.
Üç yol türetimi de canlılık kontrolünden geçiyor (`pubspec` · ruleset glob ·
`userExplanation` yolu).

**MUT-AA/AB — bu gecenin GERÇEK üç hatası geri kondu, üçünü de ikiz gördü.**
En keskin kanıt: bozuk `BARE_HEX` ile kapı *"TEMİZ — 56 çağrı tarandı"*
diyor, ikiz *"ÖLÜ DESEN"* diyor. Aynı anda.

⚠️ `find.byType` 14 kullanımım var; `findsNothing` iddialarının çoğu
pozitif ikizli (ör. `'Try again'` hem `findsOneWidget` hem `findsNothing`
ile sınanıyor — bulucunun çalıştığı ispatlı). **Test tarafı bugün temiz;
kapı tarafı bu turda kapandı.**

## 🖐️ VÜCUT-TARAF — bugün temizdi, ama TEAMÜLLE (O-063)

JabLab J-142'nin (southpaw'a *"Right hand home."*) müzik karşılığı:
**solak gitaristler gitarı TERS tutar** — sol el mızrap, sağ el perde.

**ÖLÇÜM — sevk edilen yüzey bugün TEMİZ, ve üç bağımsız sebeple:**
| kanıt | değer |
|---|---|
| `lib/` + `library.json` + golden katalogda vücut-taraf sözcüğü | **0** |
| canlı ölçüm ayna-güvenli | `trunkTiltDeg.abs()` — işaret atılıyor |
| ruleset'lerin kendi beyanı | `mirrorConfident` gitar **false** · piyano **false** · *"taraf-bağımlı hiçbir metrik zaten skorlanmıyor"* |
| kullanıcının elliği biliniyor mu | **HAYIR** — `handed`/`dominant hand` diye girdi YOK |

Koordinatörün işaret ettiği iki eşleşme **kullanıcı yüzeyi değildi**:
`RIGHT HAND IN BELL` → `config/instruments.v1.json`, **pubspec'te YOK** (sevk
edilmiyor) ve bir **korno tekniği adı** · `left_hand` → hasat bbox etiketi ·
`left_elbow`/`left_forearm` → **anatomik metrik**, meşru sınıf.

**Kural H** teamülü kapıya çevirdi. ⚠️ Taraf sözcüğüne DEĞİL, **taraf+vücut**
eşleşmesine bakıyor — pozitif ikizle iki yönde de kanıtlı:
`"where you left off"` · `"the right move"` · `"right now"` **geçiyor**,
`"right hand"` **yakalanıyor**.

**Bir sınır BEYAN EDİLMEDİ, bilerek:** *"bu dersler sağlak tutuşa göre
yazıldı"* demek YANLIŞ olurdu — dersler ellik VARSAYMIYOR (ölçüm taraf-agnostik).
Olmayan bir sınırı beyan etmek dürüstlük değil gürültüdür.

## 🔢 KAÇ SÜİT? — "testler yeşil" EKSİK bir cümledir (O-064)

> JabLab J-145: kırk kez *"kapılar N/N yeşil"* yazmış, o **app süitiydi**;
> motor süiti J-104'ten beri **kırmızıydı**.
> ***Bir kapının yeşili, o kapının KAPSADIĞI kadar geçerlidir.***

**Ostinato ailede en parçalı: 4 ayrı koşum.** Taze ölçüm (2026-08-07 09:40):

| süit | test | durum |
|---|---|---|
| kabuk (`flutter test`) | **52** | ✅ |
| `packages/ostinato_posture` | **19** | ✅ |
| `packages/ostinato_audio` | **81** | ✅ |
| **TOPLAM** | **152** | ✅ |
| MUT-A mutasyon süiti | 13/13 | ✅ |
| python kapıları | 18 | ✅ |

**KIRMIZI YOK — JabLab'ın P0'ı bende yok.** Sebebi tesadüf değil:
`run_gates.sh` üç Dart süitini de koşuyor (satır 44-46), yani gece boyunca
verdiğim **"22/22 kapı yeşil"** iddiası üç süiti de kapsıyordu.

**⚠️ AMA RAPORLAMAM EKSİKTİ:** gece boyunca *"51 test"* / *"52 test"* dedim —
o **yalnız kabuk süiti**. Ağaçta **152** test var. Kapı iddiası tamdı, SAYI
eksikti. Bu tam olarak *"eksik cümle"* sınıfı, bu kez benim raporumda.

**İKİ DÜZELTME:**
① `gate_mutation_test.py` (MUT-A 13/13 — kapılarımın ısırdığını KANITLAYAN
   süit) **`run_gates.sh`ta YOKTU**, yalnız hatırlayan koşuyordu. Bağlandı.
② `run_gates.sh` artık **KAPSAMINI ÇIKTIDA YAZIYOR**: hangi süitler, kaç
   python kapısı, ve **kapsam DIŞI ne var**. Bir daha "yeşil" demek, neyin
   yeşil olduğunu söylemeden mümkün olmasın.

**`packages/` kapsam sorusu (koordinatörün ince sorusu) — ölçüldü:** kural
C/F `DART_ROOTS = ["lib"]`. `packages/*/lib`de kullanıcı-cümlesi biçimli
string, **kapının KENDİ yöntemiyle (yorumlar sökülü) 0**. ⚠️ Ham grep 2 tane
buluyordu — ikisi de Türkçe doc-yorum parçasıydı; *ölçüm aracı kapıdan daha
kaba olduğunda sahte bulgu üretir.*

## 🎯 `landmarks` ↔ `worldLandmarks` — Ostinato'yu ETKİLEMİYOR (O-067)

Lissom L-187: `motion_camera`'nın iki native eklentisi de `result.landmarks`
kullanıyor, `worldLandmarks` değil — yani Dart'a ulaşan **z metrik dünya
koordinatı DEĞİL**.

**Ostinato'da ölçüldü, çekirdek KAYNAĞINDAN (şerhe güvenilmedi):**

| katman | bulgu |
|---|---|
| `lib/` + `ostinato_posture` | `.z` kullanımı **0** (bulucu pozitif ikizle sınandı) |
| `normalization.dart:182` | `torsoAxisAngle = atan2(torsoAxis.y, torsoAxis.x)` — **yalnız x,y** |
| `joint_angles.dart:231` | `trunkTilt = wrapPi(rawTorsoAxisAngle + π/2)` — o 2B açıdan |

**Sonuç: tek skorlanan metrik (`trunk_tilt`) DÜZLEMSEL. z'nin ne olduğu
sayıyı değiştirmiyor.**

Ve boru hattı zaten `landmarks` varsayımı üzerine kurulu: `landmarks` en-boy
oranına göre **anizotropik** normalize ve bu **açıyı bozar** — bu yüzden
`CameraPostureAdapter` **izotropik düzeltme** uyguluyor (`xExtent: size.aspect`,
M-F-30/J-028/G-038). Lissom'un bulduğu şey bende **adlandırılmış ve telafi
edilmiş**.

⚠️ **Etkilenmeyen ama AÇIK kalan sınır (M-O-08):** izotropik düzeltme yalnız
2B izdüşümü düzeltir; kullanıcı kameraya AÇILI oturursa (gitar/piyano
diyagonal) 3B eksen derinlikte kısalır ve düzlem-içi ölçek bunu kurtaramaz.
`trunk_tilt` z gerektirmiyor, ama açılı-oturuşun gerçek etkisi **cihazda
ölçülmeden** kapatılmış sayılmaz — O-036 borcu.

📌 Not: adaptörün şerhi bunu zaten yazıyordu. **İddiaya güvenmek yerine
çekirdek kaynağından doğruladım** — bu gecenin *"yanlış bir kayıt, bir
sonraki turun eline verilmiş silme talimatıdır"* dersinin tersi yönü: kayıt
DOĞRUYDU, ve doğruluğu artık ölçülü.

## 🕶️ KÖR NOKTA — sınır SINIFI (O-069, kapı YOK, bilerek)

> **Teknik kısıt örtük bir VAAT taşır; kasıtlı karar taşımaz.**
> *"Kamera bunu göremiyor"* → *"daha iyi teknoloji çözer"* demektir. Oysa
> **kusursuz bir kamerayla da vermeyeceğin hükümler var** — veri sorunu
> değil, **YETKİ** kararı.

**ÖLÇÜM (2026-08-07): 27 sınır, en az DÖRT sınıf.**

| sınıf | kaç | örnek |
|---|---|---|
| alet/kamera yok (teknoloji çözer) | 5 | *"no hand or finger landmarks at all"* |
| **kabuk eksik** (teknoloji var, biz yapmadık) | 5 | *"there is no microphone input in this build"* |
| **referans yok** (veri toplanmadı) | 5 | *"no teacher data exists on what rate is right"* |
| **karar/yetki** (bize ait değil) | 2 | *"not ours to close: it needs a movement-science review"* |
| (kaba sınıflandırıcının kaçırdığı) | 10 | — |

Başlık `Not measured` idi ve **tek sebep** ilan ediyordu. **Hiçbir cümle yalan
söylemiyordu**; kusur **cümle düzeyinde görünmüyordu**, çünkü ***çerçeve
KÜMENİN KENDİSİ hakkında bir iddiadır ve hiçbir öğesinde yazılı değildir.***

**Yapılan:** çerçeve iki yüzeyde de düzeltildi (çalgı sayfası + Review) —
başlık `What we do not judge — and why`, ve sınıfların FARKLI olduğu açıkça
söyleniyor.

**⛔ KAPI KURULMADI, bilerek.** Bir satırın hangi sınıfa girdiği **semantik**
bir yargı; mekanik ölçütüm (regex) 27 kalemin **10'unu sınıflandıramadı.
Sınıflandıramayan bir kapı, sınıfı olmayanı "temiz" sayar** — sahte yeşilin
en sinsi türü. **Kör nokta olarak kaydedildi.**

**⚠️ Açık kalan asıl kalem — SES:** kabukta mikrofon yok (kabuk eksikliği,
çözülebilir) ama **TTS/sesli koç bir ÜRÜN KARARI** (çekirdek yetenek +
harcama, kurucuda). İkisi bugün aynı "ses yok" çatısı altında okunuyor ve
**ikincisi teknoloji beklemiyor, karar bekliyor.** Ayrıştırılması koordinatör
kararı — metin yazılabilir ama hangi sınıfa ait olduğu bana ait değil.

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
5. **10 kapıda vakum koruması yok** — sahte-sıfır riski.
6. **Kanıt üreteci kapı değil** — elle tazelenir.
