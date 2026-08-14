# 🥁 OSTİNATO — YAYIN ENGELLERİ, 2026-08-14 gece turu

> **Mühür:** `HEAD 7e01402` · **194 commit** (bu turda **5**, hepsi PUSH'LU) · ağaç temiz · **40 kapı**
> **DEFTER son kaydı:** `O-138`
> **İşlenen hükümler:** `H-1`·`H-6`·`H-7`·`H-8`·`H-9` ✅ (`O-132`) · `H-10` ✅ (`O-135`/`O-136`) · `H-11` ✅ · `H-12` ✅ (`O-137`) · `H-13` ✅ (`O-138`)
> ⚠️ Bu dosyadaki her satır bir **ölçümdür**; ölçülemeyen `⛔ ÖLÇÜLEMEDİ` yazar, `❌` değil.

---

## 🔴 BU TURUN EN AĞIR ÜRÜN SORUSU — kalıcılık (⚠️ başlık `O-138` ile düzeltildi: "ölçütün kör noktası" DEĞİL)

> ## OSTİNATO KULLANICININ YAPTIĞI HİÇBİR ŞEYİ HATIRLAMIYOR.

`lib/` ağacında kalıcı yazma **2**, ve **ikisi de kullanıcı üretimi DEĞİL**:
`onboarding_store.dart` (*"onboarding bitti"* tek biti) · `pose_model.dart`
(pakete gömülü ML modelini diske açan **önbellek**). `SharedPreferences`·`Hive`·
`sqflite`: **0**. `SessionSummary` yalnız `live_screen.dart`ta üretilip
`review_screen.dart`a **geçirilir** — hiçbir yere yazılmaz. Geçmiş/ilerleme/streak **YOK**.

⇒ Kullanıcı dersi çalışır, postür ölçülür, sonuç yüzeyi **ölçülen** kareden türer —
**ekran kapanınca hepsi yok olur. Ertesi gün uygulama onu hiç görmemiş gibidir.**

> ***BİR KONTROL LİSTESİNİN YEŞİL OLMASI, SORDUĞU SORULAR KADAR BİR ŞEY KANITLAR.***
> Ölçüt yüzeylerin DÜRÜSTLÜĞÜNÜ ve GEZİLEBİLİRLİĞİNİ ölçüyor; hiçbir kalemi
> *"ürün, kullanıcının ürettiği değeri SAKLIYOR MU"* diye sormuyor. `A1`
> *"oturum→sonuç"* der ve o akış çalışır — **sonuçtan SONRASI kör noktadır.**

### ⚠️ DÜZELTME — bu bölümün ilk hâli fazla iddialıydı (`O-138`, aynı tur)
Yukarıdaki *"ölçüt kör"* çerçevesi **kısmen yanlıştı** ve düzeltmesi turun içinden geldi:
`validate_surface_honesty.py` **Kural E2** (`O-102`) bu iki yazma yolunu **kendi yorumunda
adıyla sayıyordu** — yani olgu **depoda zaten ölçülmüştü**, ben deponun **kendi bilgisini**
aramamıştım. Yeni olan **olgu değil**, onu bir **kurucu kararı** olarak adlandırmaktı.
> ***BİR KAPIYI KURMADAN ÖNCE, DEPONUN ONU ZATEN KURUP KURMADIĞINI ÖLÇ.***
📌 Ve `validate_persistence.py`nin bağ kontrolü E2'nin **daha zayıf** (global bool) ikizidir;
kapı bunu artık kendi ihlal mesajında ilan ediyor: *"KABA ÇAPRAZ KONTROL; E2 ile çelişirse
E2 doğrudur."* Gerçek katkısı **⑵ sessiz geçicilik** (E2 cümle yoksa denetleyemez) ve
**⑶ `WRITE_CLASSES`**.

🚦 **Kapsam kurucuda, İNŞA EDİLMEDİ.** Blueprint *"pratik günlüğü + streak"* diyor ama
MIDI·tuner·metronom ile aynı **ileri-dönem** listesinde ⇒ kararlaştırılmışın eksik
uygulaması değil, **kapsam kararı**; ilerlemenin nerede görüneceği ayrıca **tasarım yönü**.
Yapılan tek şey: boşluğun bir daha **sessiz kalamaması** (`validate_persistence.py`).

---

## A TABLOSU — hat kapatır

| # | kalem | hâl | kanıt / kalan |
|---|---|---|---|
| **A1** | tam akış: açılış→seçim→oturum→sonuç | ✅ **şerhli** | Şerh **KALKMADI**. Cihaz yarısı açıldı ama **yürüyüş yapılmadı** — kaldırma yetkisi koordinatörde |
| **A2** | onboarding var ve çıkışı var | ✅ | (devralındı) |
| **A3** | sessiz boş yüzey yok | ✅ | `0/13 = %0`. 🔎 Bu turda **doğrulandı**: 13/13 ders hem gerekçe hem açılma koşulu taşıyor **ve ikisi de ÇİZİLİYOR** (`lesson_locked_screen.dart:56` · `:71-85`) — düzeltilecek bir şey yok |
| **A4** | çıkmaz sokak sayısı adıyla | ✅ | `28 = 15 ⊎ 13 ⊎ 0` · `A 0 · A′ 2 · B 0 · C 0 · D 3 · E 8` |
| **A5** | kapılar yeşil + öz-testler engelliyor | ✅ | **40/40** borusuz (bu turda **2 kapı eklendi**: kalıcılık + öz-testi) |
| **A6** | DEFTER taze, iki yönde | ✅ | (devralındı) |
| **A7** | gezilebilirlik 5/5, METNE karşı | ✅ | `aday 11 = varılan 9 ⊎ kapı-arkası 2`. 🔎 Bu turda **sebepler düzeltildi** (aşağıda) |
| **A8** | gizlilik manifesti pakette | ✅ | (devralındı) |
| **A9** | ağ beyanı ölçümle uyuşuyor | ✅ | kapı yeşil |
| ~~A10~~ | → **B8** | 🔻 | tasarım yönü, kurucuda |
| **A11** | release derlemesi geçiyor | ✅ | 🔺 **GÜÇLENDİ:** artık yalnız simülatör değil — **cihaz release derlemesi** de ölçüldü (140,7 s · 45,2 MB) |
| **A12** | **cihaz gerçeği** | ⛔ **AÇIK — ama engeli DEĞİŞTİ** | ~~İMZA~~ **DÜŞTÜ**. Aşağıda |
| **(yeni)** | **kalıcılık duruşu** | ⏳ **kurucuda** | Ölçüldü ve kapılandı; karar `$founderDecision`da açık |

---

## A12 — engel düştü, yürüyüş açık kaldı

**Kapanan:** imza/profil engeli · gerçek donanıma kurulum · gerçek donanımda **AOT koşumu**.

- Devralınan iki iddia da yanlış yerden bakıyordu: *"profil yok"* (benim B tablom) ve
  H-6'nın *"wildcard beş app'i kapsar"*ı. **Ölçüm:** wildcard vardı ama
  `ProvisionedDevices` = tek cihaz; kurucunun telefonu o listede **yoktu**. Telefon ise
  takıma **kayıtlıydı** (dört ayrı dev profilinde) ⇒ eksik olan kayıt değil **taze profil**.
- `xcodebuild -allowProvisioningUpdates` → `T5HZGYBWK8.com.yulalab.ostinato`, 4 cihaz,
  telefon **dahil**. Kurulum `EXIT=0`; cihazda `Ostinato 1.0.0 (1)`.
- **Debug paketi cihazda koşamaz** — `signal 11`; artefakt **release** olmak zorunda.

**Kalan iki şart:**
1. **Kurucunun elleri.** Fiziksel cihazda dokunuş sürebilen kanal **YOK** (ölçüldü:
   mobile-mcp yalnız simülatör listeliyor, WDA kurulu değil).
2. **Kamera bacağı.** SetupCheck→Live geçişi **gerçek kare** ister.

🔒 **Kayda geçsin:** kurucunun kişisel telefonunda, gece yarısı, **kamerayı kendi başıma
tetiklemedim.** Kurulum ve açılış ölçümü başka şeydir. Kurucu 2026-08-14'te bunu teyit
etti (*"gerçek telefonda değil de testlerini simülatörde ilerletebilirsin"*) ve hat
simülatöre döndü. Telefon temiz bırakıldı (konsol kapalı, süreç 0, uygulama kurulu).

Kanıt: `app/docs/evidence/16-gercek-cihaz-kurulumu.txt` — **kanıtlananı VE kanıtlanmayanı
ayrı ayrı** yazar (H-7'de aile standardı ilan edildi).

---

## A7 — sayı aynı, SEBEPLER düzeldi (H-1'in ikinci yarısı)

`gen_screen_candidates.py` yüklemi **zorunluluğa kördü ve tek sıçramalıktı**.
`live_screen.dart:58` kamerayı yalnız **yedek** kurar (`widget.source ?? CameraPoseSource()`),
ham eşleşme onu *"kare tüketir"* saydırıyordu ⇒ `Review`in gerekçesi **yanlış bir cümle**
kuruyordu.

⚠️ Yanlış olan **sonuç değil SEBEP**: `Review` gerçekten varılamaz, ama sebebi
**GEÇİŞLİ** — onu push eden ekran **kendisi** kapının arkasında.

> ***BİR KAPININ SAYISI DOĞRUYKEN GEREKÇESİ YANLIŞSA, O KAPI BUGÜN GEÇER VE YARIN
> YANLIŞ ŞEYİ KORUR.***

**Sayı değişmedi (2)**; değişen iki sebebin de artık **doğru** olması:
`Live` → *DOĞRUDAN* · `Review` → *GEÇİŞLİ*.

---

## B TABLOSU — kurucuda (⛔ hat DOKUNMAZ)

| # | kalem | bu turdaki ölçüm |
|---|---|---|
| **B1/B7** | imza + gönderim | 🟢 **geliştirme-imza engeli DÜŞTÜ** (yukarıda). ⛔ Dağıtım imzası + ASC gönderimi hâlâ kurucuda |
| **B2** | sürüm hizası | `pubspec.yaml` → **`1.0.0+1`** (B2 metni *"5 hattın 4'ünde 0.1.0+1"* diyor — Ostinato o dördün DIŞINDA). **ASC tarafı hâlâ ÖLÇÜLMEDİ** |
| **B5** | `google_fonts` duruşu | Asimetri **10/10** — değişmedi |
| **B8** | ikon şablon değil | 6/6 şablon varsayılanı |
| **(yeni)** | **kalıcılık** | ⏳ ⑴ oturum sonucunu yerel saklamak mı, ⑵ hiçbir şey saklamamayı **bilerek seçip kullanıcıya söylemek** mi. İlerlemenin **nerede** görüneceği ayrıca tasarım |
| — | **kapsam/öncelik** | 🔴 **13 açılmayan dersin 6'sı TEK yetenekte birleşiyor: MİKROFON GİRİŞİ YOK** (⛔ aile kararı: SES/TTS kurucuda) |

---

## SIRADAKİ TURA — dosya + satırla

### ① Kalıcılık kararı gelirse — yol hazır
`WRITE_CLASSES` zorunluluğu sayesinde yeni bir yazma yolu **sınıflandırılmadan geçemez**.
Yani kalıcılık eklendiği an *"ne sakladığını söyle"* mecburiyeti **koda gömülü** çalışır.

### ② Yorum-körlüğü — 3 sessiz-yeşil HÂLÂ AÇIK (devralındı, kapanmadı)
- `tools/validate_runner_inventory.py:208` ve `:213` — `run_gates.sh`teki satır yoruma
  alınsa dizge `#` yorumunda kalır ⇒ kapı **yeşil**, test paketi **koşmuyor**. En geniş yarıçap.
- `tools/validate_references.py:310` · `tools/validate_release_signing.py:96,114`
- 📌 Yeni kapı (`validate_persistence.py`) bu sınıfa **düşmedi** — panzehir baştan takıldı.

### ③ MUT-A + zaman aşımı tuzağı (bu turda ısırdı, `O-132`)
`git commit`i 2 dakikalık zaman aşımıyla çağırdım; pre-commit kancası **tam takımı**
koşuyor (~22 dk) ⇒ MUT-A ortasında **SIGTERM**. Ölçüm: commit inmedi, **mutasyon
kalıntısı YOK**, `IN-FLIGHT` işaretçisini bir sonraki koşum onardı.
> ***BİR KOMUTUN ZAMAN AŞIMI, ONUN TETİKLEDİĞİ İŞİN SÜRESİNE GÖRE SEÇİLİR — SANA NE
> KADAR SÜRECEĞİNİ SÖYLEYEN ŞEY KOMUT DEĞİL, KANCASIDIR.***
Koordinatöre taşınan öneri hâlâ açık: hızlı kapılar pre-commit, MUT-A pre-push.

### ④ iCloud, `.git` dışında da ısırıyor
`.mutA-log 2.jsonl` — iCloud çakışma kopyası. MUT-A log'u ikiye bölünmüş; *"log doluyor mu"*
öz-testini sessizce yanıltabilir. Diğer hatlar kendi ağacında benzer `* 2.*` artefaktı arasın.

---

## BU TURUN BEDELLE ÖĞRENDİKLERİ

- ***BİR İMZANIN GEÇMESİ, KURULABİLDİĞİ ANLAMINA GELMEZ*** — kurulum AYRICA cihaz üyeliği ister.
- ***BİR VARLIK ÖLÇÜMÜ, ALAN SEÇİMİ KADAR GEÇERLİDİR*** (H-6'nın yokluk kuralının ikizi):
  profil vardı, hata `ProvisionedDevices` alanına hiç bakmamaktı.
- ***BİR SARMALAYICININ ÇIKIŞ KODU, SARDIĞI ŞEYİN SONUCU DEĞİLDİR*** — `process launch`
  EXIT 0 dedi, uygulama `signal 11` ile ölmüştü (O-119'un aynı gün **dördüncü** vakası).
- ***BİR DESENİ KÖR EDEN ŞEY HER ZAMAN GÖRÜNMEZLİK DEĞİLDİR; BAZEN GÖRÜNENİN KOŞULLU
  OLMASIDIR*** — `strip_dart_comments` panzehirinin yetmediği ilk vaka: yanıltan yorum
  değil **kodun kendisiydi**.
- ***BİR ENVANTERİ ELLE SAYMAK, DESENİNİN GENİŞLİĞİ KADAR DOĞRUDUR*** — elle `grep`im
  `writeAsBytes`i kaçırdı, kapı ötüp düzeltti.
- 🪤 **Sayaç iki kez yanlış şeyi saydı:** `grep -c` cihaz süreçlerinde Apple'ın
  `Roadrunner`'ını saydı (desen `/Runner\.app/Runner`e çapalandı) · `grep "progress"`
  Flutter'ın `ProgressIndicator`'ını saydı. *Bir sayacın doğru sayması, doğru şeyi
  saydığı anlamına gelmez.*

---

## ⛔ BİR SONRAKİ TUR — İLK İŞ, ATLAMA

### 🔴 Cihaz derlemesinden sonra simülatöre girmeden ÖNCE (O-137, H-12)
`flutter clean` bu ağaçta **YETMEZ** — `build` bir symlink olduğu için yalnız bağlantıyı siler:
```
rm -rf "$HOME/ostinato_buildout/app/native_assets" "$HOME/ostinato_buildout/app/ios"
ln -s "$HOME/ostinato_buildout/app" build      # panzehir geri
git checkout -- .flutter-plugins-dependencies   # clean bunu da siliyor (İZLENEN dosya)
```
Doğrulama tek komut: `vtool -show-build build/native_assets/ios/objective_c.framework/objective_c`
→ **`platform IOSSIMULATOR`** olmalı; `platform IOS` görürsen zehir CANLI.
✅ Bu tur sonunda temizlendi — ama bir sonraki cihaz derlemesi onu geri getirir.

### 🚦 KURUCU/KOORDİNATÖR KAPISINDA BEKLEYENLER
| kalem | soru |
|---|---|
| **② kalıcılık** | oturum sonucu yerel saklansın mı? Onaylanırsa `WRITE_CLASSES` yeni yazmayı **sınıflandırmaya zorlar** ve bağ kapısı **üç geçicilik metnini** birlikte düzeltmeye mecbur eder (sessiz inemez) |
| **③ ilerleme yüzeyi** | ⛔ **TASARIM YÖNÜ** — hat dokunmaz |
| **A12 yürüyüşü** | kurucunun elleri; cihazda dokunuş kanalı YOK (mobile-mcp yalnız simülatör) |
| **A1 şerhi** | kaldırma yetkisi koordinatörde — bu turda KALDIRILMADI |
| **B8 ikon · B5 font · B2 ASC** | devralındı, değişmedi |

### 📌 C DURMA BİLDİRİMİ AYAKTA
Üç turdur **kullanıcının göreceği yüzeyde ölçülmüş bir değişiklik yok** (kapı/ölçüm/ortam işi
yapıldı, ürün yüzeyi değil). H-5'in birimine göre bildirildi ve hüküm bekleniyor.
