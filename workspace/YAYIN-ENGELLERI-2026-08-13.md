# 🥁 OSTİNATO — YAYIN ENGELLERİ, 2026-08-13 turu sonu

> **Mühür:** `HEAD 35abb0a`+ (bu turda 4 commit) · ağaç temiz · 44 kapı yeşil
> **DEFTER son kaydı:** `O-128`
> ⚠️ Bu dosyadaki her satır bir **ölçümdür**; ölçülemeyen `⛔ ÖLÇÜLEMEDİ` yazar, `❌` değil.

---

## A TABLOSU — hat kapatır

| # | kalem | hâl | kanıt / kalan |
|---|---|---|---|
| **A1** | tam akış: açılış→seçim→oturum→sonuç | ✅ **şerhli** | `test/full_flow_test.dart` + 3 sabotaj · cihaz yürüyüşü `docs/evidence/15-*` · ⚠️ **zerk edilen tek bacak: SetupCheck→Live** (aşağıda) |
| **A2** | onboarding var ve çıkışı var | ✅ | A1 içinde, **bayrak set edilmeden** · cihazda: `terminate`+`launch` sonrası Kütüphane'ye düşüyor ⇒ bayrak kalıcı |
| **A3** | sessiz boş yüzey yok | ✅ | `validate_block_taxonomy.py` → `0/13 = %0`; sabotajla doğrulandı. ⚠️ payda **2 varılamayan ekranı kapsamaz** (şerh kodda) |
| **A4** | çıkmaz sokak sayısı adıyla | ✅ | `28 = 15 ⊎ 13 ⊎ 0`, payda 13 · **`A 0 · A′ 2 · B 0 · C 0 · D 3 · E 8`** |
| **A5** | kapılar yeşil + öz-testler engelliyor | ✅ | 44/44, borusuz. Bu turda **2 kapı eklendi** (A4 taksonomisi + öz-testi) |
| **A6** | DEFTER taze, iki yönde | ✅ | Bu turda **kırmızı verdi ve haklıydı** → O-120 deftere yazıldı; üçüncü kova `LESSON_ONLY` eklendi (O-123) |
| **A7** | gezilebilirlik 5/5, METNE karşı | ✅ **güçlendi** | `aday 11 = varılan 9 ⊎ kapı-arkası 2` (önce 8⊎3). Devir notundaki **şerh kalktı** — yanlış sebep metni düzeltildi (O-121) |
| **A8** | gizlilik manifesti pakette | ✅ | (devralındı; bu turda dokunulmadı) |
| **A9** | ağ beyanı ölçümle uyuşuyor | ✅ | kapı yeşil |
| ~~A10~~ | → **B8** | 🔻 | tasarım yönü, kurucuda |
| **A11** | release derlemesi geçiyor | ✅ | (devralındı; iOS sim derlemesi bu turda da geçti, 376,5 s) |
| **A12** | **cihaz gerçeği** | ⛔ **AÇIK — ama engeli DEĞİŞTİ (O-129/O-130)** | ~~engel İMZA~~ **DÜŞTÜ**: profil üretildi, uygulama gerçek iPhone'a **kuruldu** (`Ostinato 1.0.0 (1)`, `EXIT=0`, bağımsız teyitli). Kalan **iki** şey: ⑴ **release (AOT) derlemesi** — debug cihazda `signal 11` ile ölür (O-130), ⑵ **kurucunun elleri**: fiziksel cihazda dokunuş sürebilen kanal **YOK** (ölçüldü: mobile-mcp yalnız simülatör listeliyor, WDA kurulu değil). ⇒ A12 artık *mühendislik engeli* değil, **~2 dakikalık insan yürüyüşü** |

### 🔴 A1'in şerhi — adıyla
Yürüyüşün **tek** bir bacağı dokunuşla değil koşumla kuruluyor: **SetupCheck → Live.**
Ürünün o düğmesi `setup_check_screen.dart:490`da `_Stage.passed`ta doğar ve o aşama
**gerçek kamera karesi** ister. Simülatörde kamera donanımı yoktur.
> ***Ostinato'da A1'in son metresi A12'nin ta kendisidir.***
Ölçüt ikisini ayrı kalem sayar; bu uygulamada *"oturum → sonuç"* bacağı **ancak kamerayla**
gözlemlenir. A1 ✅ sayıldı çünkü ölçütün A1 için istediği kanıt *"yürüyüş testi, taze
kurulumdan, `NavigatorObserver` tanığıyla"* ve o kanıt sabotajla doğrulanmış hâlde duruyor.
**Koordinatör aksini derse geri alınır.**

---

## B TABLOSU — kurucuda (⛔ hat DOKUNMAZ)

| # | kalem | bu turdaki ölçüm |
|---|---|---|
| **B1/B7** | imza + gönderim | 🟢 **DÜZELTİLDİ 2026-08-14 (O-129) — iki iddia da yanlıştı.** ⑴ *"profil yok"* → artık **VAR**: `6838d7c8…` = `T5HZGYBWK8.com.yulalab.ostinato`, **4 cihaz**, kurucunun iPhone'u (`00008120-001804D83E13C01E`) **dahil**; `xcodebuild -allowProvisioningUpdates` portaldan ürettirdi. ⑵ *"`xctrace` → Devices Offline"* → **BAYAT OKUMA**: `devicectl` telefonla **canlı tünel** kuruyor. **Kurulum yapıldı, `EXIT=0`.** ⛔ Kalan gönderim işi (dağıtım imzası + ASC) hâlâ kurucuda — ama **geliştirme-imza engeli DÜŞTÜ** |
| **B2** | sürüm hizası | `pubspec.yaml` → **`1.0.0+1`** (B2 metni *"5 hattın 4'ünde 0.1.0+1"* diyor — **Ostinato o dördün DIŞINDA**). **ASC tarafı hâlâ ÖLÇÜLMEDİ** |
| **B5** | `google_fonts` duruşu | Asimetri **10/10**: 10 test dosyası çekmeyi kapatıyor, üretim kapatmıyor ⇒ **hiçbir test bu davranışı göremez** |
| **B8** | ikon şablon değil | 6/6 şablon varsayılanı (tek commit `b5bd37c`) |
| — | **kapsam/öncelik** | 🔴 **13 açılmayan dersin 6'sı TEK bir yetenekte birleşiyor: MİKROFON GİRİŞİ YOK** |

---

## SIRADAKİ TURA — dosya + satırla

### ① Yorum-körlüğü: 36 python dosyası tarandı, **3 sessiz-yeşil doğrulandı**
- `tools/validate_runner_inventory.py:208` → `if "flutter test" not in gates:`
  `run_gates.sh`'te satır **yoruma alınsa** dizge `#` yorumunda kalır ⇒ kapı **yeşil**,
  test paketi **koşmuyor**. (Aynı desen `:213` `dart analyze` için de.) **En geniş yarıçap.**
- `tools/validate_references.py:310` → `producerPattern` **ham** dart metninde; üretici
  silinip yorumda adı kalırsa *"live ama üreticisi yok"* denetimi **susar**.
- `tools/validate_release_signing.py:96,114` → `.gradle.kts` **hiç ayıklanmadan** taranıyor.
> Panzehir bu depoda zaten var: `validate_surface_honesty.strip_dart_comments`.
> `.gradle.kts`/`.sh`/`.yaml` için **yok** — orası yeni iş.

### ② `O-126` — kamera hata sınıfı, A12'de ayrılacak
SetupCheck *"Camera access is off"* diyor **ama `simctl privacy grant camera` sonrası da**.
Ürün mü karıştırıyor, simülatör TCC'si mi vermiyor — **simülatörde ayrılamaz.**

### ③ Koordinatöre taşınan iki yapısal öneri (uygulanmadı)
- **pre-commit maliyeti:** tam kapı takımı **~22 dk**, yük altında **45+ dk**. Öneri:
  hızlı kapılar pre-commit, MUT-A + ağır süitler **pre-push**.
- **MUT-A kesilince ağacı zehirliyor:** `finally` SIGTERM'de koşmuyor. Öneri: SIGTERM tuzağı.
  ⚠️ Ve türevi: **MUT-A koşarken depoyu OKUMAK sabote edilmiş veri okumaktır** (yük altında
  bu pencere 20+ dk). Bir ölçüm ajanım tam buna düştü; verisi atıldı.

---

## BU TURUN BEDELLE ÖĞRENDİKLERİ

- ***BİR DENETİMİN İKİ TARAFI DA AYNI ŞEYİ DENEMİYORSA, UZLAŞMALARI BİR ÖLÇÜM DEĞİL
  BİR SESSİZLİKTİR.*** (Yürüyüş "Begin the setup check"e hiç basmıyordu; bölme assert'i
  üç ekran için **yanlış çıkamıyordu**.)
- ***BİR SARMALAYICININ ÇIKIŞ KODU, SARDIĞI ŞEYİN SONUCU DEĞİLDİR — İKİ YÖNDE DE.***
  Aynı gün biri *"exit 0"* dedi (commit düşmüştü), öteki *"failed"* dedi (commit inmişti).
- ***BİR SINIFLANDIRMA, ELİNDEKİ KOVALARIN HİÇBİRİ UYMAYAN BİR KALEMİ YİNE DE BİRİNE
  ATIYORSA, ÖLÇTÜĞÜ ŞEY KALEM DEĞİL KENDİ DARLIĞIDIR.*** (`LESSON_ONLY`, beşinci vaka.)
- 🪤 **`kicker()` metni `toUpperCase()` yapar** (`ostinato_theme.dart:180`) — *bir yüzeyi
  kaynak dizgesiyle aramak, ürünün ÇİZDİĞİNİ değil yazarın YAZDIĞINI aramaktır.*
- 🪤 **Alt-ajanın çıktısı da bir iddiadır**, ve kaynağı kirliyse sessizce yanlıştır.
