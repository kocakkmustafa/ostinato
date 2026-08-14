# Ostinato — İlerleme Kaydı

## 2026-08-13 — START HERE şeridi + kapıların kendi BEYANLARI (ve üç ölçüm-yöntemi kusuru)
Oturum başı `3697b86` (== `origin/main`, ÖLÇÜLDÜ). Kayıtlar **O-117 · O-118 · O-119 · OK-14**.
Kapılar **34 → 36 python kapısı**; nihai koşum **tek süreç, borusuz, dokunulmamış**: `✅ TÜM KAPILAR YEŞİL`, MUT-A **14/14**, ağaç yalnız bu turun kalemleri.

| İş | Kanıt |
|---|---|
| **START HERE şeridi İNŞA EDİLDİ** (O-117, DESIGN-AHEAD §1.2) — dün kapanmamış tek hat-yereli inşa kalemi | Şerit `library_screen.dart`ta (`_StarterRow`, anahtar `starter-<disiplin>`). **Açık bırakılan karar TÜRETİM lehine kapandı (OK-14):** üç ders kimliği ekrana YAZILMADI, `library.json`da `starterLessonId` + `_why_starter` olarak duruyor; ekran yalnız çözer. Gerekçe icat değil, deponun kendi emsali — `honesty.instrumentSpecificGap` aynı sebeple veriye taşınmıştı |
| **Yeni kapı `validate_starters.py` — 5 kural + öz-test** | ① canlı disiplin bildirir ② kimlik gerçekten var ③ **starter `locked`/`demoOnly` OLAMAZ** (*"Start here" bir çıkmaza işaret edemez*) ④ **ekran hiçbir ders kimliği taşımaz** ⑤ gerekçe boş olamaz. Öz-test **6 mutasyon + pozitif ikiz**; öz-test yetmez diye **gerçek dosyada 3 sabotaj**: ekrana kimlik gömme · starter'ı kilitliye çevirme · bildirimi silme → üçü de EXIT=1, geri alma bayt-temiz |
| **Tek-gerçek düzeltmesi** | ders→ekran switch'i `course_screen.dart`ta `lessonScreenFor()` olarak top-level'a çıkarıldı: iki kopya olsaydı yeni bir `LessonKind`de derleyici yalnız güncelleneni bilirdi |
| **Test 4/4 — ve testin kendisi 2 mutasyonla sınandı** | `library_starters_test.dart`: beklenen değerlerin HİÇBİRİ elle yazılmadı, hepsi `repo`dan türüyor (yoksa test ikinci bir gömülü liste olurdu). MUT: şerit tek çalgıya indirildi → 3 kırmızı · kalem ders yerine çalgı adını gösterdi → 1 kırmızı |
| **🔴 Test İKİ KEZ düştü, ikisi de GERÇEK bulgu** | ⑴ ilk tanığım *"şerit kayboldu mu"*ydu — `Navigator.push` önceki rotayı **silmez, örter**; kaybolma gezinmenin YANLIŞ VEKİLİ → tanık `NavigatorObserver` (O-112 deseni). ⑵ `tap` **0 rota itti**: şerit **375×812'de katlamanın ALTINDA**. ⭐ *Testin düşmesi, ürünün ölçülmemiş bir gerçeğini söyledi:* tasarım şeridi kartların "HEMEN ALTINA" koyuyor, en dar yaygın telefonda oraya scroll'suz ulaşılmıyor. **Yerleşim DÜZELTİLMEDİ** (tasarımın kararı korundu), koordinatöre kalem olarak yazıldı |
| **O-118 — bayat beyan avlayan kapının KENDİ başarı satırı bayat beyandı** | Yeni test dosyası `allowRuntimeFetching`i kapatan 9. dosya oldu → `validate_runtime_fetch` **doğru şekilde öttü** (BEYAN 8 · ÖLÇÜM 9; ② sınıfı tasarlanmış karar noktası, O-116). Tazelerken görüldü: öz-testin başarı satırı `"3 çağrı · 8 test dosyası"` **sabitlerini** taşıyordu ve **hiçbir kontrol bir `print`in içindeki sayıyı sınamıyor**. İkisi de `actual`dan türetildi. 🧪 10. dosya sabotajı: kapı `BEYAN 9 · ÖLÇÜM 10` dedi VE başarı satırı sayıyı takip etti |
| **Şema v2 → v3** + kapının ölçemediği yer isimlendi | `starterLessonId` yeni alan → yazılı kural gereği `library.json` ve `EXPECTED_SCHEMA_VERSION` birlikte yükseltildi. ⚠️ **İSİMLİ BOŞLUK:** `validate_orphan_keys` iki sayının **eşitliğini** denetliyor, yeni alanın onları **yükseltmeye zorladığını** değil — alanı ekleyip sürümü bırakan biri **sessizce** geçerdi. MUT-T yalnız *"biri değişip öteki kalırsa"*yı yakalar. Boşluk kapının üstüne + KAPI-ENVANTERI'ne yazıldı, **bu turda KAPATILMADI** |
| **Provenance zinciri DÜZELTİLDİ** | `_why_starter` alanları önce *"`Ostinato.dc.html` satır 133-145"* diye **birinci elden** alıntılıyordu; comp **depoda YOK** (claude.ai/design) ve **bu turda açılmadı** → metinler *"OKUDUĞUM KAYNAK: `DESIGN-AHEAD-OF-CODE.md` §1.2 … comp atfı DEVRALINDI"* olarak düzeltildi. *Açmadığın bir kaynağı birinci elden alıntılamak, ölçmediğin bir sayıyı yazmakla aynı sınıf* |
| **§1.3 BAYAT ÇIKTI (yan bulgu)** | Bant çubuğu 08-12'de (O-053) inşa edilmişti, DESIGN-AHEAD hâlâ *"kart bunu taşımıyor"* diyordu. Sınıf: ***artefaktın varlığı işin durumunu güncellemez*** — "tasarım>kod" listesi TERS yönde yanılttı (yapılmış işi yapılmamış gösterdi). §1.2 + §1.3 + özet tablo birlikte kapatıldı |

**🔴 ÜÇ ÖLÇÜM-YÖNTEMİ KUSURU (O-119) — hiçbiri üründe değil, üçü de benim aracımdaydı:**
1. `run_gates.sh | tail -60` → çıktı **tamponlandı** (0 bayt, asılı sanıldı) · **kırmızı kapının adı ATILDI** · kabuk çıkış kodunu `tail`'den okudu ⇒ görev **"exit code 0"** derken betiğin son satırı `⛔ EN AZ BİR KAPI KIRMIZI` idi.
2. Birinci koşumu durdurmadan ikincisini başlattım → MUT-A mutasyon hâlindeki ağaç okundu, **4 sahte kırmızı**.
3. Koşum sürerken dosya düzenledim → `schemaVersion` yükseltmem **yedekten geri yazmayla silindi**.
> ⭐ ***Ağacı benim disiplinim değil, ARACIN SERTLEŞTİRİLMİŞ OLMASI kurtardı:*** MUT-A kilidi girmeyi reddetti (O-079), nihai koşum hasarı kendisi onardı (*"yedekten geri yüklendi, özet doğrulaması: TUTTU"*).
> **Kural: bir kapı koşumu sürerken ikincisi başlatılmaz ve dosya düzenlenmez; uzun betik boruya değil DOSYAYA yönlendirilir.** Aile-geneli aday (beş hat da kendi kapı betiğini koşuyor) → koordinatöre.

**Nihai koşumun `⛔` satırları TEK TEK incelendi** (son satıra güvenilmedi): 4 tanesinin hiçbiri kırmızı değil — 3'ü gezilebilirlik sözleşmesinin bilinen "varılamayan" işaretleri (Live/Review/SetupCheck, kamera sınırı), 1'i MUT-A log öz-testinin **kasıtlı** `heal_blocked` senaryosu.

**AÇIK KALEMLER — üç kovada:**
- **ⓐ hat-yerelinde:** ⑤ önizleme hâlâ cihaz-bekliyor (O-036) · Live/SetupCheck/Review otomatik yürüyüşle varılamıyor (kamera sınırı) · KATI eşiği **tam tabanda (8/8)** · **şema-sürümü kapı boşluğu** (adıyla açık, kapatılabilir).
- **ⓑ koordinatörde:** **OK-14 türetim kararı** retrospektif teyit bekliyor · **şeridin katlamanın altında kalması** (yerleşim kararı, hat düzeltmedi) · O-119'un aile-geneli kuralı.
- **ⓒ kurucuda:** 6 yayın kalemi (keystore · ikon+açılış · mağaza metni/görselleri · `AFTER_APPROVAL` · cihaz günü · sürüm beyanı) · **font duruşu** (asimetri büyüdü: 9 test kapatıyor, üretim kapatmıyor ⇒ hiçbir test bu davranışı göremez) · ⑫ makine-geneli JDK.

## 2026-08-12 (gece vardiyası) — GEZİLEBİLİRLİK SÖZLEŞMESİ + kapıların KENDİ dürüstlüğü
main `aea3047`(oturum başı, ÖLÇÜLDÜ: HEAD~22) → **`3697b86`** — **22 commit, hepsi push'landı.** Kayıtlar **O-095 … O-116**.
Kapılar **26 → 34 python kapısı**; her birimin sonunda ✅, ve son koşumda **MUT-A 14/14 · ağaç 0 kirli**.

| İş | Kanıt |
|---|---|
| **Onboarding ÖLÇÜLDÜ, varsayılmadı** (O-095…O-099) — izin metni **saklama iddiası** taşıyordu; aile ölçümü *4/5 hatta aynı kusur* dedi ve kural **çekirdek GARANTİSİ** oldu | `RETENTION_CLAIM` özneden BAĞIMSIZ (fiil + saklanabilir-nesne); `claim_bearing_text_surfaces()` **alan-adı beyaz listesi olmadan** TÜM dizge değerlerini yürüyor. ⚠️ Kendi taramam da aynı deliği taşıyordu: **5. yüzey** ("upper-body" ifadesine bağlıydım, İDDİAYA değil) |
| **Bağımlılık BÖLMESİ + iki yönlü bağ** (O-100…O-103) — `A ⊎ B`, üçüncü hâl = kırmızı; `RETENTION_FACTS` 8 özne, her biri **ölçüm ADRESİYLE** | `NETWORK_DEPS_KNOWN_SAFE` 63 kalem · `lock_packages()` bölmesi · özne başına iki yönde bağ (iddia→ölçüm VE ölçüm→iddia) |
| **Yayın denetimi + imza** (O-104, `YAYIN-ENGELLERI-2026-08-12.md`) — **12 kalem**; release imzası şablon debug config'iyle çıkıyordu | `validate_release_signing.py` **üç şekli** yakalıyor (koşulsuz debug · koşullu-ama-SESSİZ · görev var ama `assembleRelease`e bağlı DEĞİL). Debug fallback KASITLI kaldı (LifeOS ölçümü: kaldırmak `--debug`i kırıyor) |
| **Çalışma-anı çekmesi GÖRÜNÜR** (O-104) — `google_fonts` üretimde Google'dan indiriyor, ve **çekme yalnız TESTLERDE kapatılmış** ⇒ hiçbir test bu davranışı GÖREMEZ | `validate_runtime_fetch.py`: 3 üretim çağrısı · 8 test dosyası çekmeyi kapatıyor · asimetri **beyanı ZORUNLU**. ⏳ Duruş kararı **kurucuda** |
| **Sayma kuralı + rota kimliği** (O-105…O-107, `GEZILEBILIRLIK-SAYMA-KURALI.md`) — sayaç **etiket dizgesi** topluyordu, yazılı KATI kural **ayrı ROTA** sayar | KATI **9 → 8**: *sayı 9 hiç doğru değildi, birim değişti — yön değil.* `guide` ve `scored` aynı rotaya gidiyor |
| **DEFTER yeniden kuruldu + tazelik kapısı** (O-108…O-111) — **gedik 87 → 0** (15 → 116 kayıt, hepsi commit SHA'larından) | `defter_freshness.py`: payda **DENKLEM** olarak denetleniyor (`atıflı 133 + atıfsız 51 = 184`, rev-list ile birebir) · uçuştaki-kayıt tavanı TÜRETİLİYOR · `9xx` sentinel + prob ayrımı. ⭐ Aynı seansta **üç kez** *bir numaradan söz etmek onu var etti* |
| **GEZİLEBİLİRLİK SÖZLEŞMESİ (a)(b)(c)(d)(e)** (O-112…O-115) — **metne karşı 5/5**, üçüncü hat | Aday küme **İKİ bağımsız türetimin uzlaşması** (AD ⟷ YAPI) = 11 ekran · tanık `NavigatorObserver` **varış başına** · varılamayan 3, **her biri türetilmiş sebeple** · bölme artık **tanım değil DENETİM** (iki taraf ayrı kaynak) · elle küme **ALT SINIR** + iki şerh. **KATI 8 → 8**: *değişen sayı değil, sayının NEYLE kanıtlandığı* |
| **Öz-testin ① sınıfı SIFIRLANDI** (O-116) — *bir kapı kendi ürününün ilerlemesini cezalandırıyorsa o kapı ürünün düşmanıdır* | **85 kontrol (① 3 · ② 14 · ③ 68) → 95 kontrol (① 0 · ② 15 · ③ 80)**; öz-testli kapı 9 → 10. Font ikilisi **sentetik dedektöre**, `anchored>=mentions` **sentetik korpusa**, `expect(rootMembers,2)` **kaynaktan türetilen KÜMEye** çevrildi; prob muafiyetinin **varsayımı adıyla** yazıldı |

**⚠️ SEKİZ SABOTAJ, İKİSİ İNMEDİ — ve ikisi de GERÇEK kusur buldu:**
- **koruma ÇİFT:** `^O-\d+` + `.match()` birbirinin yedeği ⇒ tek noktalı mutasyon çapayı kıramaz (çift mutasyon kırmızı verdi).
- **kapı KÖRDÜ:** `return const SettingsScreen();` deseni hiç görmüyordu ⇒ parametresiz bir kök yüzey **görünmez**di. Ve aynı turda **öz-test `run_gates`e bağlı değildi** (üçüncü inmeme yolunun canlı örneği).
> ***"Sabotaj kırmızı verdi" demek kolay; "verdi mi?" diye ÖLÇMEK kapının körlüğünü açığa çıkarır.***

**AÇIK KALEMLER — üç kovada (ADIYLA):**
- **ⓐ hat-yerelinde:** ⑤ önizleme ERTELENMİŞ (*cihaz-gerçeği YOK*; sıradaki adım gerçek cihazda kamera yürüyüşü) · `LiveScreenRoute`/`SetupCheckScreenRoute`/`ReviewScreenRoute` **hiçbir otomatik yürüyüşle varılamıyor** (kamera sınırı, O-036/O-037 ile aynı) · KATI eşiği **tam tabanda (8/8), sıfır pay**.
- **ⓑ koordinatörde:** ⑤'in kullanıcı cümlesi **yazılmayacak** hükmü uygulandı — teyit bekliyor · gezilebilirlik panosunda **Gravita metne karşı ölçülmedi** (bu hattı etkilemez, panoyu etkiler).
- **ⓒ kurucuda:** **6 yayın kalemi** · **font duruşu** (gömmek mi, çevrimdışı ilk açılışı kabul mü — ⚠️ **üçüncü sonuç ölçüldü:** kararı uygularsan kapı *beyan tazelenmeli* diye öter, ki bu tasarlanmış karar noktası, yanlış alarm DEĞİL) · *"var olan onay yeterli mi"* · ⑫ makine-geneli JDK düzeltmesi (venture-ötesi).

**Teyit edildi:** 8 `blockedByTool` kaleminin **8'i** `unblockedBy` VE **8'i** `closedPaths` taşıyor (ölçüldü, beyan değil).

## 2026-08-07 gece (tur 59) — Yayın hattı: onboarding + üç dürüstlük kusuru + içerik derinliği
main `e0579ee` → `ef39f48` → `1e06603` → `ef0b89a` → **`df05c3d`** (hepsi push'landı).
Kapılar **17/17 → 18/18** (yeni kapı eklendi); her birimin sonunda yeşil.

| İş | Kanıt |
|---|---|
| **1. Yüzey dürüstlüğü** (`ef39f48`, O-038/O-042) — Info.plist'te `NSMicrophoneUsageDescription`, manifest'te `RECORD_AUDIO`, kabukta ses yakalama: ÜÇÜ DE YOK. Ama 2 ekran mikrofonu çalışıyor gibi anlatıyordu, 3.'sü doğruyu söylüyordu. Ayrıca M-F-186 süpürmesi dosya sınırında durmuş: `library.json` 5 "yet" taşıyordu | Metinler düzeltildi (Ayarlar kartı İKİYE ayrıldı — yokluk kendi kartı). **`tools/validate_surface_honesty.py`** (kapı #4): 10 vaat deseni × TÜM yüzey + yetenek↔izin bağı. İzin beyan edilince kural kendini emekliye ayırır. **MUT 3/3** |
| **2. Onboarding** (`1e06603`, O-039) — kodda HİÇ yoktu (0 dosya), yayının önündeki en somut engel | 3 adım (karşılama · kapsam · sensörler), UI-BRIEF §2.1'den TÜRETİLDİ; kapsam sayıları `library.json`dan TÜRER. `OstinatoHome` ayrıldı → dallanma testi `runAsync` istemiyor, `google_fonts` gezici kırmızısı düzeltilmedi **İMKÂNSIZ kılındı**. **8 test · MUT 3/3** |
| **3. "Ölçüyoruz" listesi** (`ef0b89a`, O-040) — 3 disiplinin `measured[1]`i ve blurb'ü canlı ses iddiası taşıyordu; hiçbiri "microphone" KELİMESİNİ kullanmadığı için 1. birimin kapısı göremedi | Üçü de `notMeasured`a taşındı — **tek olgu kaybedilmeden**, yalnız MEKÂN düzeltilerek (*kayıtta ölçüldü ≠ odanda ölçülüyor*). Kural C: olumlu iddia alanları (`honesty.measured`, `blurb`) ses kavramı anamaz. MUT ✅ |
| **4. İçerik derinliği** (`df05c3d`, O-041) — **19 → 28 ders** (gitar 10 · şan 9 · piyano 9) | 3 yönerge dersi (ölçüm iddiası yok; içeriği Setup Check'in GERÇEK aşamalarından) + **6 kilitli ders**, her biri EKSİK ÖLÇÜMÜN ADIYLA. Dokuzunun da `_why_locked_source`/`_why_unlocked` alanı kaynağını taşıyor — **gerekçe icadı, eşik icadı kadar yasak**. Kurs süreleri toplamdan yeniden hesaplandı; karşılama sayıları kendiliğinden güncellendi |

**KOORDİNATÖRE GİDEN 2 KALEM (karar bende değil):**
1. **Onboarding'de kamera izni İSTENMİYOR, AÇIKLANIYOR** — ürün davranışı kararı.
   Gerekçe: isteyen tek yer Kurulum Kontrolü (`requestAndStartCamera`) ve istek zaten
   orada; ikinci bir istek yolu (a) zamanla ayrışan bir çatal açar (b) reddeden
   kullanıcıyı kütüphaneyi HİÇ görmeden çıkmaz sokağa oturtur. Brief'in şartı
   ("NEDEN gerektiği, izin isteğinden ÖNCE") böyle de karşılanıyor. Aksi isteniyorsa
   küçük bir değişiklik.
2. **`google_fonts` çalışma-zamanı indirmesi yayın için gözden geçirilmeli** — bugün
   yazı tipleri ilk açılışta indiriliyor. Ağsız ilk açılış = yazı tipi yok; ayrıca
   "hiçbir şey bu cihazdan çıkmaz" diyen bir uygulamanın açılışta bir font CDN'ine
   gitmesi gizlilik anlatısıyla kötü oturuyor. Fontları gömmek (OFL, izinli) bunu
   kapatır. **Ayrı birim, bu gece YAPILMADI.**


## 2026-08-06/07 (tur 58) — GİYDİRME TESLİM EDİLDİ + 3 hüküm + O-037 kapandı + M-F-186 düzeltmesi
Koordinatörün "🎨 GİYDİRME GÖREVİ" sevkiyle başladı, aynı oturumda beş ek tur takip etti. main `95a7183`→`aac7312`→`f76dc81`→`15dced7` (son).

| İş | Kanıt |
|---|---|
| **Onaylı tasarım (`Ostinato.dc.html`, 1195 satır) koda taşındı** | 10 ekran: Library/Instrument/Course/Locked/Demo/Scored/SetupCheck/Live/Review/Settings. 17 maddelik uyum turu koşuldu, `main.dart`'ta `ContentRepositoryScope` `MaterialApp.home`'u sarıyordu (Navigator.push kırılırdı) — `route_path_test.dart` YAKALADI, prod'a sızmadan |
| **RenderFlex taşma — GERÇEK bug, ölçülüp bulundu** | `flutter_test`in ~800pt varsayılan yüzeyi telefonun 2 katı genişlikte — yanlış güven kaynağıydı. 375pt'e (Lissom standardı) sabitlenince Live başlık çubuğu 112-195px TAŞTI (üç disiplinin de İKİNCİ dersinde). Düzeltildi + 375pt kalıcı regresyon kapısına eklendi (`real_content_overflow_test.dart`) |
| **Placeholder kaydı** | `tools/gen_placeholder_register.py` — kod işaretleri + `library.json`'ın locked/demoOnly dersleri (metin icat etmeden) → `docs/design/PLACEHOLDER-REGISTER.md`. `--check` kapı: unblocked-by eksikse/kayıt bayatsa exit 1 |
| **HÜKÜM 1** (Instrument üst-bant renk) | İZİNLİ — panel cevabıyla tutarlı, Library nötr kalıyor. Kod değişmedi |
| **HÜKÜM 2** (Review) | `insideShare` yüzdesi AYNEN kaldı (süre olgusu, skor değil); `verdict`in "Needs focus."ı → **"Mostly outside the band."** (hakem dili → betimleyici). `test/review_verdict_test.dart` yeni — regresyon kilidi |
| **HÜKÜM 3** (gözlem işareti) | `rare` — config'in kendi `_silentWhen_why`siyle artık YAZILI dayanaklı |
| **🔴 Skeleton figürü — asset DEĞİL, dürüstlük kalemiydi** | Gövde CANLI döner (tiltDeg), kollar hiç ölçülmez ama rijit taşınıyordu — "kısmi canlılık" yanıltıcı. Çözüm B: kollar KESİKLİ + landmark-noktasız (tür farkı, derece değil). `PLACEHOLDER-REGISTER`den `asset` kalktı |
| **`DESIGN-AHEAD-OF-CODE.md`** (aile standardı, eksikti) | `Ostinato.dc.html` baştan sona kodla karşılaştırıldı. **🔴 En büyük bulgu: sesli antrenör göstergesi (`coachOn`, Live ekranı) — ailenin çekirdek vaadiyle (motion-core §1.1) bağlantılı, kodda SIFIR karşılığı; 5 hattın hiçbirinde ses ÇIKIŞI yok** (yalnız giriş/analiz var). Ayrıca: Library "START HERE" şeridi + 0-24° bant çubuğu hiç inşa edilmedi; Review "neyi ölçemedik" tasarımda 4 kalem kodda 3; Setup Check oda-gürültüsü tasarımda 2 aktif durum kodda 1 statik kart; `demoTreatment` A/B — `cueTreatment` ile AYNI statüde ikinci bir çatal, hiç fark edilmemiş |
| **demoTreatment isimlendirildi (OK-13)** | "İsimsiz çıkış çıkış değildir" — geriye dönük hüküm: **Treatment A seçildi** (kod zaten ona sadıktı, tek sapma veri kısıtıydı). Kod değişmedi, yalnız kayıt |
| **O-037 — ekran-kanıtı (bu tur KAPANDI)** | Tetik geldiğinde dokunma-enjeksiyonu **İKİNCİ KEZ tıkandı** (kardeş sim'ler kapatıldıktan SONRA, kendi `simctl` döngümün ardından). İSİMLİ DURDUR: `tools/evidence/evidence_capture_test.dart` yazıldı — gerçek widget ağacını pump edip `RepaintBoundary.toImage()`le PNG + `dumpText()`le gerçek `Text.data` .txt üretiyor (dokunmaya bağımlı değil). 5/6 ekran GÖZLE doğrulandı (Setup Check hariç — gerçek `MotionCameraController` test ortamında asılı kalıyor, O-036'nın aynı donanım sınırı). Kesikli-kol render'ı hem statik hem canlı-döner bağlamda doğrulandı. M-F-287 ikiz kontrolü: `lesson_scored_screen.dart`a tek cümlelik netleştirme eklendi. Üretici dosya `test/` DIŞINA taşındı (glif-yükleme async istisnası `flutter test`in varsayılan süpürmesini kırmasın diye) |
| Kapılar | **17/17 yeşil** (`./tools/run_gates.sh`, yeni placeholder-kaydı kapısı dahil) · MUT-A **13/13** |
| **M-F-186 düzeltmesi** (koordinatörün O-037 kabulündeki TEK zorunlu madde) | O-037 kapanışında `lesson_scored_screen.dart`a eklenen netleştirme cümlesi "not tracked **yet**" diyordu — vaat/zaman-taahhüdü dili yasak (M-F-186) VE yanlış: kollar ÖLÇÜLÜYOR (demo ekranı gösteriyor), izlenmeyen ölçüm değil bu FİGÜR. Aynı taramada 2 kalem daha bulundu: `lesson_demo_screen.dart` ("not wired into this build **yet**") ve `review_screen.dart` ("no report to send **yet**") — üçü de "yet" çıkarılıp bugünün olgusuna döndürüldü (gelecek vaadi yok). `content.dart`'ın `comingSoon` alanı DOKUNULMADI — zaten gerekçeli. 3 ekranın kanıtı yeniden üretildi (01/02/05); 01.png ve 05.png bayt-bayt AYNI kaldı (değişen metin görünür-alan kıvrımının altında, yalnız .txt ağaç-dökümü değişti) — bu beklenen davranış, hata değil |
| **SINIR BEYANI** (koordinatör talebiyle DEFTER O-037'ye eklendi) | ✅ metin doğruluğu kanıtlı (.txt) · ✅ düzen/vektör kanıtlı (PNG) · ⛔ cihaz-düzeyi render (gerçek font/DPI/güvenli alan) KANITLANMADI, O-036 paketine · ⛔ Setup Check KANITLANMADI, O-036 paketine · 📌 `tools/evidence/evidence_capture_test.dart` `run_gates.sh`a BAĞLI DEĞİL — ekran değişirse ELLE yeniden koşulmalı, aksi hâlde bayat PNG "doğrulandı" sanılabilir |
| Kapılar (M-F-186 sonrası) | `flutter analyze` temiz (3 dosya) · `real_content_overflow_test.dart` 4/4 · 17/17 gate · MUT-A 13/13 — hepsi tekrar koşuldu, hepsi yeşil |

| **BONUS — gerçek font (JabLab'ın kök-nedeni)** | Koordinatör JabLab'ın bulgusunu aktardı: block-glif sorunu ağ erişimi değil, `TestWidgetsFlutterBinding`in `HttpOverrides.global`i HER isteği 400'e zorluyordu. `tools/evidence/flutter_test_config.dart` (JabLab uyarlaması) + `path_provider_platform_interface` açık dev_dependency eklendi. **ÖLÇÜLDÜ:** 6/6 test 4.3sn'de sıfır istisna, 6 PNG gerçek Hanken Grotesk/IBM Plex Mono ile yeniden üretildi (01/02/06 gözle spot-check). SINIR güncellendi: gerçek font artık kanıtlı, gerçek DPI/güvenli-alan hâlâ O-036'ya |
| **YAN-BULGU (fix YAZILMADI, koordinatöre bırakıldı)** | PNG'ler okunabilir olunca `grep -rn "\byet\b" lib/` tam-ağaç taraması yapıldı — orijinal dosya-bazlı taramanın kaçırdığı 3 kesin + 1 tartışmalı "yet" bulundu: `settings_screen.dart:56` (çıplak) · `setup_check_screen.dart:386,431` (biri gerekçeli-ama-yine-ihlal, biri çıplak) · `instrument_screen.dart:158`in `'Not here yet — and why'` kicker'ı (argümanlı — `comingSoon`un zaten-gerekçeli statüsüyle aynı deyim mi). Detay + tam alıntılar: DEFTER O-037 son satırı |
| Kapılar (font-fix sonrası) | `flutter analyze` (proje-geneli) 2 önceden-var info (tools/dart_pilot/, kapsam dışı) · gate'in kendi analyze'i (`lib/`+`test/`) temiz · 17/17 gate · MUT-A 13/13 |

| **4 kalan "yet" — koordinatör onayıyla düzeltildi** | `settings_screen.dart` (gerekçesiz, en çıplak) · `setup_check_screen.dart:386,431` (gerekçeli ama yine ihlal — Setup Check dokunuşu AÇIKÇA onaylandı) · `instrument_screen.dart:158` kicker'ı `'Not here yet — and why'`→**`'Not here — and why'`** (kapsam-dışı listeye "henüz" demek gelmeyecek olana vaat verirdi; kelime seçimi bana bırakıldı). `content.dart:52` eşleşen yorum da güncellendi. Tam-ağaç taraması artık SIFIR kullanıcı-yüzeyi "yet" — kalan tüm eşleşmeler yalnız düzeltmeleri belgeleyen yorumlar |
| Kapılar (son tur) | `flutter analyze` (4 dosya) temiz · `real_content_overflow_test.dart` 4/4 · 17/17 gate · MUT-A 13/13 · `06-settings` kanıtı yeniden üretildi |

**Durum: TESLİM EDİLDİ ve TAMAMEN KAPANDI.** main `15dced7`→`799af1f`→son commit (bu tur). DEFTER: OK-10..OK-13 + O-037 kapandı (SINIR BEYANI + font-fix eki + 4-kalem "yet" kapanışı dahil). **Açık, isimlendirilmiş kalan (bu turun kapsamı DEĞİL, ayrı kararlar):** sesli antrenör göstergesi (çekirdek yetenek kararı, kurucuya taşındı) · Setup Check'in kamera-bağımlı durumları + cihaz-düzeyi DPI/güvenli-alan render (O-036, cihaz günü) · DESIGN-AHEAD-OF-CODE'daki diğer tasarım>kod kalemleri (sonraki inşa turu). Sıradaki: koordinatöre kapanış raporu → **BEKLEME MODU**.

## 2026-08-05 (tur 57) — TUR-2 KAPANDI: gerçek kamera bağlandı, yüzey değişmedi
O-032 kapandıktan hemen sonra, aynı oturumda. Kurucu emrinin sırası tamamlandı: O-032 → tur-2.

| İş | Kanıt |
|---|---|
| **`motion_camera` gerçekten bağlandı** | `lib/app/camera_pose_source.dart` (yeni) — `CameraPoseSource implements PoseSource`: izin akışı + `MotionCameraController.start/stop/frames` + `CameraFailure`→sealed-hâl eşlemesi. `PostureScreen` TEK SATIR değişmedi — kaynak sahteden gerçeğe geçti, yüzey aynı (tur-1'in taahhüdü tutuldu) |
| **İzin akışı Gravita deseniyle BİREBİR** | `permission_handler` — plugin izin İSTEMEZ (native taraf yalnız `AVCaptureDevice.authorizationStatus` OKUR), app `Permission.camera.request()`i ÖNCE ve AÇIKÇA çağırır. `PermissionDeniedRetriable`/`Permanent` ayrımı `PermissionStatus`tan türetilir |
| **Landmark→açı GEOMETRİSİ İCAT EDİLMEDİ** | `packages/ostinato_posture/lib/src/camera_posture_adapter.dart` (yeni) — motion_core'un aile-geneli `StandardJoints.trunkTilt` tanımı (Gravita/Lissom/JabLab ile PAYLAŞILAN, önceden vetted ölçü) kullanıldı. Zorunlu adımlar doğru sırayla: `toIsotropic` (M-F-30/J-028, atlanırsa her açı en-boy oranıyla bükülür) → `ConfidenceGate` gövde-yalnız (`LmRegion.torso`, `xExtent: size.aspect` — G-038 tuzağı doğru uygulandı) → `PoseNormalizer`+`JointAngleExtractor`. 5 sentetik-landmark testiyle doğrulandı (dik~0°, eğik>dikten belirgin büyük, düşük-güven→null, kol/bacak-görünmezliği etkilemez, reset() EMA'yı sıfırlar) |
| **Poz modeli aile hattından** | `tool/fetch_pose_model.sh` (Gravita/JabLab ile BİREBİR aynı script) — `pose_landmarker_full.v1.task` aile-yerel önbellekten kopyalandı, SHA-256 doğrulandı (`5134a3aa...`, Gravita'nın dosyasıyla AYNI hash). `.gitignore`e `assets/models/*.task` eklendi (aile kuralı: ikili commit edilmez) |
| **Platform duvarları** | iOS `NSCameraUsageDescription` eklendi · Android `CAMERA` izni eklendi · `flutter build ios --simulator --debug` VE `flutter build apk --debug` ikisi de temiz derleniyor (permission_handler+path_provider pod/gradle entegrasyonu sorunsuz) |
| **🔬 Canlı sim koşumu — çıkmaz-sokak YOK** | Cold-launch → Guitar dersine dokun → gerçek `Navigator.push` → gerçek izin isteği → sim'de kamera donanımı olmadığı için `PermissionDeniedPermanent` döndü → ekran ÇÖKMEDİ/asılı KALMADI, tipli "Open Settings" hâli doğru çizildi, banner "DEMO SOURCE"tan "LIVE CAMERA"a geçti. Hiçbir `flutter:` istisnası loglanmadı. Kanıt: `docs/evidence/06-tur2-camera-permission-honest-state.png` |
| **Kanıt sınıfı DÜRÜST kaldı** | "plumbing + izin + hâller sim-kanıtlı; gerçek görüntü cihaz-günü release-gate" — hiçbir yerde "cihazda kanıtlı" iddiası YOK. 2 isimli açık sınır: (1) `CameraLens.front` seçimi (Gravita'nın arka-kamera kararından farklı, kullanıcı-yerleşimi varsayımı) cihazda sınanmadı (2) M-O-08 açılı-oturuş sınırı (gitar/piyano diyagonal, motion_core'un kendi ölçülü kaydı) gerçek görüntüyle hiç ölçülmedi |
| Kapılar | **16/16 yeşil** (`./tools/run_gates.sh`) — yeni `camera_posture_adapter_test.dart` (5 test) dahil |
| Dead code temizliği | `main.dart`daki artık kullanılmayan `_demoScript` sabiti + gereksiz `ostinato_posture` import'u kaldırıldı |

**Durum:** Tur-2 kapandı. DEFTER: O-036 (yeni, iki isimli sınırla açık — cihaz-günü release-gate). Sıradaki: kapanış zinciri (commit+push+merge, koordinatöre rapor) → design linkini BEKLE.

## 2026-08-05 (tur 56) — O-032 KAPANDI: kök neden BUG DEĞİL, ölçüm-yöntemi boşluğu
Koordinatör görev-sevkiyle devam edildi (M-F-280 doğrulandı: paylaşımlı `motion-core/lib` ağacı main'in 122 commit gerisinde/0 ilerisinde — sözleşmeler `~/motion-worktrees/coordinator-main/docs/`'tan okundu, o ağaç bu turda hiç kullanılmadı).

| İş | Kanıt |
|---|---|
| **Route hipotezi de ÇÜRÜTÜLDÜ** | `test/route_path_test.dart` (yeni): GERÇEK `Navigator.push(MaterialPageRoute(...))` arkasında tam demo senaryosu + gerçek zamanlayıcı → ilk ateşleme SORUNSUZ. Yedi adayın hepsi elendi (değerlendirici · widget çizimi · zamanlayıcı/akış · demo senaryosu · yakalama zamanlaması · bayat ikili · route sarmalayıcısı) |
| **Canlı `flutter run` teşhisi** | cold-launch iPhone 17 Pro Max, geçici print-diagnostiği (evaluator çıktısı + widget render ayrı ayrı loglandı, `mcp__Claude_Code_iOS_Simulator__control` ile tıklandı). İşaret **5/5 ölçülen pencerede** doğru ateşlendi ve render edildi: tUs=2.700.000/32.760.000/66.060.000/96.120.000/129.420.000 |
| **📐 DÜZELTME (koordinatör denetimi, aynı gün)** | Aralıklar TEK periyot ("~30,06sn") DEĞİL — vitrin sayısı dayanağını taşımıyordu. Gerçek: **30,06/33,30sn ALTERNATİF** (ortalama 31,68sn). Mekanizma deterministik: cooldown 166,67 kare (tamsayı değil), 32-karelik demo lap'ında "+167 kare" sıçraması iki faza düşüyor — biri hâlâ aralık-dışıyken (anında ateşler) biri banda dönmüşken (sayaç sıfırlanır, 18 kare daha beklenir) |
| **🎯 GERÇEK KÖK NEDEN BULUNDU** | `cooldownUs=30_000_000` yüzünden işaret her ~31,68sn'lik pencerenin yalnız ~%7,4'ünde (2,34sn/31,68sn) görünür — aralık-dışı olmanın kendisi çok daha yaygınken (lap'ın ~%47'si), işaretin GÖRÜNÜYOR OLMASI nadir. TÜM önceki manuel/screenshot repro denemeleri (bu hat dahil, defalarca) rastgele bir ana denk gelip "cooldown aktif" penceresini örnekledi, mekanizmayı kırık sandı |
| **Kalıcı kanıt: iki yeni test** | `route_path_test.dart` + `cue_cooldown_visibility_test.dart` (gerçek 30sn cooldown + gerçek demo senaryosu + gerçek `PostureScreen`; ilk-ateşleme→banda-dönüş-silme→cooldown-sessizliği→ikinci-ateşleme dörtlüsünü TEK testte kanıtlar, fake-async'te <1sn'de koşar — canlı simülatörde ~3,5 dakika süren ölçümü kalıcı ve hızlı bir kapıya çevirir) |
| **Yeni ders: O-035** | Düşük-görünürlük periyodik davranış, tek-anlık gözlemle "kırık" sanılır — O-028'in zaman-ekseni kardeşi. Var olan kısaltılmış-cooldown testi (`evaluator_test.dart`) mekanizmayı zaten kanıtlamıştı ama gerçek 30sn değeriyle hiç bağlanmamıştı: iki bilinen gerçek birleştirilmedi |
| Geçici teşhis print'leri | `pose_source.dart` + `posture_screen.dart`'a eklendi, kök neden bulununca KALDIRILDI — kalıcı kod DEĞİŞMEDİ (evaluator/widget/route baştan doğru çalışıyordu) |
| Kapılar | **16/16 yeşil** (`./tools/run_gates.sh`) — iki yeni test dosyası dahil |

**Durum:** O-032 kapalı, tur-2'nin önünde bloke edici şüphe yok. Sıradaki: tur-2 gerçek kamera entegrasyonu.

## 2026-08-05 (tur 55) — O-032 teşhis turu: ŞÜPHEM ÇÜRÜTÜLDÜ, dört aday elendi · İSİMLİ DURUŞ
Kurucu emri "sırayı bu oturumda koş" alındı; 1. adım (O-032) koşuldu. **Düzeltme YAZILMADI** — kural: teşhis doğrulanmadan üzerine kod yazılmaz. main `fe82679`.

| Ölçüm | Sonuç |
|---|---|
| Gerçek zamanlayıcıyla (`t.pump(Duration)`) sürdürülen sapma | işaret **DOĞUYOR** |
| Uygulamanın **TAM** demo senaryosu (null kareler dahil) + gerçek zamanlayıcı | işaret **DOĞUYOR** |
| Yakalama zamanlaması (pencere 7→15 kare) | zaten elenmişti |
| Bayat ikili (`uninstall`→`install` temiz kurulum) | elendi |

**Şüphe sınıfım YANLIŞTI.** `Timer.periodic`/`setState` yolunu suçlamıştım; ölçüm onu temize çıkardı. ELENEN adaylar: değerlendirici · widget çizimi · zamanlayıcı/akış · demo senaryosu · yakalama · bayat ikili.

**KALAN aday (daraltıldı, yine TAHMİN):** navigasyon/route sarmalayıcısı — `MaterialPageRoute` builder'ı her yeniden-çizimde YENİ `FakePoseSource` üretiyor, State ise `initState`te bağlandığı kaynağı dinliyor. Testlerde route YOK, ekran doğrudan kuruluyor: **testlerin uğramadığı TEK fark bu.**

**Yan bulgu (desen):** `rootBundle.loadString`'i test GÖVDESİNDE çağırmak ikinci testte 10 dk asıyor; `setUpAll`a alınmalı. Bu tuzağa `widget_test.dart`ta bir kez düşülüp düzeltilmişti, **yeni dosyada tekrarlandı** — düzeltmenin dosyaya değil DESENE yazılması gerektiğinin kanıtı.

### 🛑 İSİMLİ DURUŞ
Bağlam bütçesi sınırda; koordinatörün "bağlam sıkışırsa isimli durdur" izniyle **burada duruyorum**. Tur-2 (gerçek kamera) BAŞLAMADI ve başlamamalı: O-032 açıkken kamerayı bağlamak iki belirsizliği üst üste koyar.

**Taze oturuma devir:** ilk iş hâlâ O-032, ama artık **çok daha dar** — dört aday elenmiş, tek aday kalmış, ve onu sınayacak deney belli: route'suz vs route'lu aynı ekranı karşılaştıran bir test (ya da `flutter run` canlı log).

## 2026-08-05 (tur 54) — 🎥 KABUK DOĞDU + canlı postür yüzeyi (tur-1 MÜHÜRLÜ) · bir şüphe AÇIK
M-F-263/264/269. main `f76da34` · kapılar **16/16** · iOS sim + Android debug derleme yeşil.

| İş | Kanıt |
|---|---|
| **Pin 0.8.6 → `f13bdc9`** (motion_core 0.11.0 + motion_camera 0.1.2, tek ref) | Tag'ler ayrı commit'te, ref ikisini de içeriyor (merge-base doğrulandı). Regen: çekirdek **3 sürüm atladı, artefakt BİT-BİT AYNI** (frames hash ×3 değişmedi) — frameBasis deltası YOK |
| **Pin testine ÜÇÜNCÜ ÇAPA** | Eskisi "iki kilit AYNI mı" diyordu, "DOĞRU şeyde mi aynı" demiyordu. Mühürlü ref + çözülen sürüm artık DIŞ SABİT |
| **🔴 PUB DUVARI ÖLÇÜLDÜ** | `motion_camera` eklenince kırıldı: o tam 40-SHA pinliyor, benimki kısaltılmıştı ve **pub ref'leri ÇÖZMEZ, STRING karşılaştırır**. Kısaltılmış ref TEK BAŞINA çözülüyordu — arıza ancak İKİ TARAF anlaşmak zorundayken göründü (pin testinin kendi dersi) |
| **KABUK: Ostinato'nun İLK Flutter uygulaması** | `lib/` · `ios/` · `android/` yoktu. iCloud kuralı İLK derlemeden ÖNCE (build → `~/ostinato_buildout`). Mimari G-100: **kabuk yalnız kablolama**, her hüküm `packages/ostinato_posture`ta ve testte |
| **Yüzey (üç çalgı, K8)** | Eğitmen bandı ölçülen aralıkla (gitar 0,4–6,4°/7 · şan 0,4–4,4°/6 · piyano 1,9–2,8°/3) · gözlem işareti golden'dan doldurulur · **`Measuring`de `score` alanı bilerek YOK**, bant konumu dışarıda `null` döner |
| **Dürüst hâller SEALED** | Starting · PermissionDeniedRetriable/Permanent · SetupFailed · NoPersonVisible · Measuring. Yeni hâl eklenirse derleyici yüzeyi kırar |
| **Sözleşme varlığı ÜRETİLİYOR** + kapısı | `gen_posture_contract.py --check`: kabuk hiçbir sayı taşımıyor (O-029'un canlı-yüzey hâli önlendi) |
| **🔬 EKRANA BAKMAK İKİ KUSUR YAKALADI — testler yeşilken** | (1) **bayat işaret metni**: başlık "You: 18,0°" derken işaret "You are at 20°" — çözülmüş METİN saklanıyordu, ekranda çelişen iki sayı. (2) **🔴 sahte kaynağın saati döngüde SIFIRLANIYORDU**: damga geri gidince 30 sn cooldown bir daha ASLA dolmuyor, işaret sessizce ölüyordu. **Sözleşmeyi çiğneyen taraf TEST-İKİZİNİN KENDİSİYDİ** (aile-notu kabul edildi) |
| Üçüncü, küçük bulgu | Testlerde **off-by-one**: akış teslimi bir mikrotask sonra gelir, tek `pump()` bir ÖNCEKİ kareyi çizer — testler sandıkları kareden öncekini sınıyordu. `feed()` yardımcısı |
| **Zeyil-2: üç iOS duvarı** | deployment 13→14 · `use_frameworks! :linkage => :static` · `LANG=en_US.UTF-8 pod install`. motion_camera pod'u kuruldu, sim derlemesi yeşil |
| **Zeyil-3: yüzey desenleri** | Çıkmaz-sokak yasağı (`SetupFailed` — ekran açılır, analiz-yokluğu beyan edilir) · izin **kalıcı/geçici** ayrımı tiple (kalıcıda "tekrar dene" YOK: işlevsiz düğme, olmayan düğmeden kötü) · `PoseSource.status` akışı (yaşam-döngüsünü KAYNAK bildirir; tur-2'de kamera aynı hâlleri yayacak, **yüzey değişmeyecek**) |
| Testler | 11 postür · 11 widget · 81 audio. 4 ekran kanıtı (`docs/evidence/`) |
| Commit'ler | `240f7d5` pin · `b5bd37c` kabuk+yüzey · `939101d` zeyil-2/3 · merge `f76da34` |

### 🔴 AÇIK ŞÜPHE — O-032 (tur-2'den ÖNCE kapanır)
**Gözlem işareti ÇALIŞAN UYGULAMADA görünmedi.** Bu "ekran görüntüsü alınamadı" DEĞİL:
1. Değerlendirici işareti **üretiyor** (demo senaryosu doğrudan geçirildi: index 15'te `cue=true`).
2. Widget onu **çiziyor** (3 test: görünüm · sayı senkronu · banda dönünce silinme).
3. Çalışan uygulamada, aralık-dışı pencerenin **ORTASINDA da** (21,0°) yok.

Yakalama zamanlaması **elendi** (pencere 7→15 kareye uzatıldı). Parçalar ayrı ayrı kanıtlı, **birleşik canlı hâl kanıtlanmadı** — bu hattın kendi *"bağlandı ≠ canlı"* dersinin bize dönmüş hâli. Şüphe sınıfı TAHMİN olarak yazıldı (Timer.periodic altındaki dinleyici/setState yolu; senkron `pushOne()` kullanan testlerin uğramadığı fark).

⚠️ **Koordinatör kabulü `b5bd37c`'ye dayanıyor ve kanıt dosyasının ESKİ metnini alıntılıyor** ("dar pencere + sim çekişmesi"). O metin `939101d`'de DEĞİŞTİRİLDİ: artık açık şüphe olarak yazılı. Kapanış raporunda belirtildi.

**Durum:** tur-1 mühürlü. Tur-2 (gerçek kamera) taze oturuma; **ilk iş O-032**, kamera ondan sonra.

## 2026-08-04 (tur 53) — Regen doğrulaması: O-030 kapandı, iki kapı kendini kanıtladı, bir kapsam iddiam DÜZELTİLDİ
MOCORE flip tetiği (M-F-258). Commit `f7f7c88`.

| İş | Kanıt |
|---|---|
| **Snapshot → regen → diff** | "Değişmedi" iddiası ölçülmeden kurulmaz: regen ÖNCESİ 13 alan × 3 çalgı donduruldu, sonra karşılaştırıldı |
| **Değişen TEK alan** | `guitar.technique` `guitar_posture_setup` → `open_chord_drill`. **O-030 KAPANDI.** Artefakt elle düzenlenmedi — builder geçen tur düzeltilmişti, regen işledi |
| Değişmeyen her şey | takes 7/6/3 · length 181/68/145 · meanAgreement (10 hane) · clusterTolerance · mirrorConfident · unreliableJoints · evidenceThickness · floorBoundShare · perJointSource · params · **frames hash (sha256) BİREBİR**. Dispersiyon 2,24/1,35/1,09 sabit |
| **✅ Ters-yön kapısı GERÇEK regen'de ateşledi** | Beyanı kaldırmadan önce: *"çözülmüş bir beyan bayattır, kaldırılmalı"*. Yapısal olduğunu İDDİA etmiştim — ölçüldü |
| **✅ O-024 gerekçe kapısı ÜÇ ÇALGIDA yakaladı — DEĞERLER AYNIYKEN** | Regen `generatedAt` damgasını tazeledi, değerler değişmedi, kapı yine kırmızı yandı. Kurulma sebebinin tam olarak gerçekleştiği an: *"değer doğru olsa bile gerekçe bayat"* |

### 🔴 KENDİ KAPSAM İDDİAM YANLIŞTI — düzeltme (M-F-259, koordinatör)
Raporumda ve `f7f7c88`'in ebeveyn commit mesajında şunu yazdım: *"flip hasat-zamanında etkili; landmark'lar yeniden hasat edilmediği için ulaşamadı; sayı-nötrlük ancak yeniden hasat + rebuild ile kurulur."*

**Doğrusu:** flip **ÖLÇÜM-zamanında** etkilidir. Landmark çıkarımı **MOD-AGNOSTİKTİR** (ham MediaPipe çıktısı; extract bayrağı hiç okumadı — G-107/M-F-230). Anatomik varsayılanla yeniden hasat **BİREBİR AYNI** landmark'ları üretirdi: **landmark, mod taşıyamaz.** Mod, landmark'lar ÜZERİNDEKİ açı-ölçümünde (Python evaluate-tüketicileri) yaşar. Bu hattın zinciri Dart-pinli ve bugün evaluate-tüketicisi YOK.

**Sonuç:** "yeniden hasat kalemi" diye önerdiğim iş GEREKSİZDİ. Doğru cümle üçüncüsü: **bu yol hiçbir zaman o sapmayı taşımayacak — taşıyan yol doğarsa kalem onunla gelir.** İki cümleyi ayırmam ("sapma görmedim ÇÜNKÜ mümkün değildi") doğruydu; ama *neden* mümkün olmadığını yanlış mekanizmaya bağladım. **Ders: bir sınırı isimlendirmek yetmez, MEKANİZMASI da doğru olmalı — yanlış mekanizmalı doğru sonuç, gereksiz iş üretir** (M-F-248'in "yanlış-mekanizmalı gerekçe" sınıfının kendi başıma düşmüş hâli).

Commit mesajı düzeltilemez; kayıt burada duruyor.

**Durum:** bekleme aynen. Tetikler: 🎸 gitar kaydı · 🎤 vokal kaydı · zamanlama-derecelendirme gündemi · yeni paket. **MOCORE flip tetiği ÇÖZÜLDÜ** ve yerine isimli yeni tetik geçti: zincire Python-evaluate tabanlı ölçüm girerse frameBasis karşılaştırması.

## 2026-08-04 (kapanış) — 🔚 VARDİYA KAPANDI, hat BEKLEME DURUMUNDA
Koordinatör M-F-255: vardiya hedefleri kapandı, açık iş yok.

**Devir durumu (doğrulandı, iddia değil):** `app/main = c446e0c` origin ile EŞİT · çalışma ağacı TEMİZ · push farkı 0 · dört feat dalı da main'de merge'li (silinmedi, zararsız). Kapılar **12/12** · MUT-A **13/13** · 80/80 dart testi.

**Bu vardiyanın dört turu (49-52):** şan+piyano ders yolu ve LIVE geçişi · gözlem işareti şeridi (M-F-232, 7 şart) · aile-hizalama süpürmesi (MUT-A + pozitif-ikiz + fallback mekanizma A) · atıf süpürmesi + postür yolu genişletmesi.

**Kullanıcıya ulaşan üç yanlış beyan düzeltildi:** bayat eğitmen sayısı (3→7) · sözlük-dışı akorun yanlış adı (Bb→"Dm" %97) · piyanonun var olmayan "hand feedback" vaadi.

**Devir promptu TAZELENDİ** (`workspace/YENI-OTURUM-PROMPT.md`) — eski sürüm ölü bir koordinatör oturum ID'si taşıyordu ve bu vardiyanın açılışında yeni oturum ona rapor etmeye çalıştı. Yeni sürümde ID YAZILMIYOR: koordinatör `list_sessions`'tan başlığıyla bulunur. **Bir kimliği dosyaya yazmak, onu bayatlatmanın en hızlı yolu.**

**İsimli tetikler (biri gelmeden yeni iş açılmaz):** 🎸 gitar kaydı → "Open chords" · 🎤 vokal kaydı → "Sustained note" · ⚙️ MOCORE flip → regen-doğrulama (`_pendingRegen` kalkar, ters-yön kapısı zaten hazır) · ⏱️ zamanlama-derecelendirme gündemi → O-025 önce kapanır · koordinatörden yeni paket.

## 2026-08-04 (tur 52) — Atıf süpürmesi kırık bir vaat buldu; konsolidasyonun kendisi suçluydu
M-F-249 paketi + O-025 hükmü (b).

| İş | Kanıt |
|---|---|
| **İçerik-atıf süpürmesi** (`tools/validate_references.py`, yeni) | İki arıza ayrıldı: **ÇÖZÜLMEZ** (görünür) ve **KAPSAM-YANLIŞ** (sinsi — çözünürlük kapısı "buldum" der ama başka çalgının dünyasına çözülür). 8 sabotaj sınıfı, tamamı yakalandı |
| **🔴 GERÇEK KIRIK ATIF** | Gitar referans artefaktı `technique: "guitar_posture_setup"` diyor — **ruleset'te öyle bir teknik YOK**. Kardeşleri gerçek drill id'si taşıyor (`sustained_note_drill` / `five_finger_drill`) |
| **Kök neden KONSOLİDASYONUN KENDİSİYDİ** | M-F-143'te üç kopya tek kanonik yola indirildi (doğru hamle) ama **kopyalar arasındaki FARKLAR incelenmeden bir eşleme tablosuna taşındı**. Tablo tek tip görünüyordu — iki satırı drill id'si, biri eski etiket. **Konsolidasyon, bitirmesi gereken ayrışmayı KORUDU.** Yeni ders: üç kopyayı birleştirirken tablo satırlarının BİRBİRİYLE tutarlı olduğu ayrıca sınanmalı |
| Düzeltme yolu | Builder DÜZELTİLDİ; **artefakt elle düzenlenmedi** ("ölçülür, yazılmaz") → `_pendingRegen` BEYANI (6 alan zorunlu, eksik beyan susturucudur) + **ters yön** (uyuşmazlık çözülünce beyan bayat sayılır). Aile regen'i koordinatörde |
| **Postür yolu ölçülen banda genişledi** | Hold-penceresi trunk_tilt medyanları: **gitar 0,4–6,4° (7 eğitmen) · şan 0,4–4,4° (6) · piyano 1,9–2,8° (3)**. İçerik referansın KENDİ kaydından türetildi, uydurulmadı |
| `teacher_range` dersi ×3 | "Doğru duruş bir NOKTA değil BANT." Yeni metrik yok, yeni eşik yok. Piyanoda dar bandın **kısmen küçük-örneklem etkisi** olduğu isimle yazıldı — 3 take anlaşma kapısının tabanı |
| `piano.posture_under_play` | Gitar/şanda vardı, piyanoda yoktu. **Aynı kanıt üç çalgıda da geçerliyken içerik ikisinde kurulmuştu** — eksiklik ölçümde değil İÇERİKTEYDİ (e2e 80/80 kanıtlı) |
| **Kol dersleri ×3 → `demoOnly`/`structural-circular`** | Gitarınki KİLİTLİYDİ ve **kilit yanlış araçtı**: ölçüm gerçekten yapılıyor, dürüstlük kutusu zaten "gösteriyoruz, puanlamıyoruz" diyor. `permanent` DEĞİL — **kamera kolları GÖRÜYOR, eksik olan uzlaşı** (kamera-körlüğü ≠ uzlaşı-yokluğu) |
| **Kural 11 — demoOnlyClass sözleşmesi** (M-F-245) | Varsayılan YOK · kapalı sözlük · structural-circular⇒promotionPath(3 alan) · permanent⇒whyPermanent ∧ path YASAK. **TERS YÖN kapısı**: permanent'a yol yazmak eksiklik değil ÇELİŞKİ. 8 sabotaj sınıfı, tamamı yakalandı |
| **O-025 hükmü (b) uygulandı** | `docs/gates/O-025-TIMING-CALIBRATION-PROTOCOL.md` — frameMs süpürme tablosu + 12× asimetri kanıtı + kombinasyon-başına yeniden ölçüm + damga zorunluluğu. **Config alanı AÇILMADI** (okuyucusuz alan yaşamaz, L-178/K9) |
| Kapılar | **12/12 yeşil** · MUT-A 13/13 · 80/80 dart testi |
| Commit | `ee98371` |

**Ders sayısı:** gitar 7 · şan 6 · piyano 6 (önce 6/4/3).

## 2026-08-04 (tur 51) — Aile-hizalama süpürmesi: kapılarımı sınadım, motor bir yerde kullanıcıya yalan söylüyordu
M-F-236 paketi, 5 madde. En ağır bulgu 3. maddede ve **canlı disiplinde**.

| İş | Kanıt |
|---|---|
| **MUT-A** (`tools/gate_mutation_test.py`, yeni) — 13 mutasyon | Kapılar sınıflandırıldı: tek-kaynak (çelişki kapısı yakalamalı) · **iki-kaynak** (üçüncü çapa var mı) · içerik (varlık kapısı mı). İlk koşum **5 ÇAPASIZ iddia** buldu → hepsi kapatıldı → **13/13** |
| **🔴 En kötü boşluk: VİTRİN korumasızdı** | Config'teki her sayıyı üç kapıyla koruyup, kullanıcının okuduğu dürüstlük kutusunu bağsız bırakmışız. Yeni **kural 9** (vitrin sayısı ↔ artefakt) **ANINDA gerçek kusur buldu**: gitar kutusu "3 independent guitar teachers" diyordu, artefakt **7 take**. Havuz 07-30'da 3→5→7 büyümüş, vitrin metni güncellenmemişti |
| Yeni çapalar | aile-varsayılanı 14,0° (M-F-143) · artefakt iç tutarlılığı (`contributingTakes == len(takes)`) · kural 9 · **kural 10** (varlık kapısı → ÖZ kapısı: `"x"` bir gerekçe değildir) |
| **Pozitif-ikiz denetimi** (`tools/positive_twin_audit.py`, yeni) | 7 yokluk iddiası **iki yönde** koşuluyor: sessiz taraf 0, ikiz >0. Hepsi ikizli — hep-sessiz bir dedektör artık hiçbirini geçemez |
| **🔴🔴 FALLBACK ÖLÇÜMÜ MEKANİZMA A BULDU** (reçete M-F-184, 5 adım + kontrol satırı M-F-202) | **Bb → "Dm" 28/29 pencere (%97) · Bm → "D" 22/29 (%76).** Sözlük-dışı akor, en yakın komşusuna GÜVENLE etiketleniyordu |
| **Kendi ilk teşhisim yanlıştı ve toplama bakmaktan kaynaklandı** | İlk sürüm "✅ fallback canlı, 46,5× ayırma gücü" diyordu. Toplam, %100 reddedilen tek notayı %97 yanlış-etiketlenen Bb ile ORTALIYOR ve sağlıklı bir %53 üretiyordu. Reçetenin A/B ayrımı **girdi başınadır**; teşhis girdi-başına çevrildi |
| Eşik oynatmak ÇÖZMÜYOR — ölçüldü | Yanlış-etiketi yarıya indirmek gerçek akorların **%61'ini** kaybettiriyor. Eğri: 0.06→%65,5 yanlış/%0,9 kayıp · 0.20→%27,6/%61,2 · 0.40→%8,6/%100 |
| **KÖK NEDEN: aday kümesinin daraltılması** | Kazanacak hipotez (Bb) listede yoktu, motor en yakınını seçmek zorundaydı. **Tuzak kodun kendi yorumundaydı:** "narrowing the field is the cheapest accuracy gain" — bilinenleri AYIRMAK için doğru, bilinmeyeni REDDETMEK için tam ters |
| **DÜZELTME BEDELSİZ ÇIKTI** | `acceptedNames`: aday 24 şablon, kabul 8 akor. **Yanlış-etiket %65,5 → %0,0 · tanıma kaybı DEĞİŞMEDİ (%0,9).** 12 regresyon testi (4 red + 8 pozitif ikiz). AF-007 yeniden üretildi: skorlar aynı, **runnerUp "Em"→"E7"** (o da dürüstleşti — Em yalnızca E7 aday değilken ikinciydi) |
| **O-025 KÖK NEDEN ÖLÇÜLDÜ** | Sapma `frameMs` ile **ÖLÇEKLENİYOR** (23ms→0,75 · 46ms→8,29 · 92ms→26,34) → sabit gecikme DEĞİL, analiz **GEOMETRİSİ**. Ölçülen sabit uygulanınca **asimetri 18,05 → 1,47 ms (12×)**. Motora UYGULANMADI: nerede yaşayacağı mimari karar |
| UI-BRIEF eki | Gözlem işareti yüzeyi (sayı kaynağından koparılmamalı, sürekli görünen rozet sözleşmeyi bozar) + 5 açık ders tablosu + **"ölçülür-puanlanmaz" üçüncü görsel sınıf ihtiyacı** |
| Yan düzeltme | Kapı takımını **kendi yavaşlattığım** iç içe maliyet (pozitif-ikiz → MUT-A → ağır gözlem kapısı ×13) kaldırıldı; `--fast` modu |
| Kapılar | **11/11 yeşil** · **80/80** dart testi · analyze temiz |
| Commit | `c83ecb9` |

**Durum:** Paketin 5 maddesi de kapandı. Kullanıcıya ulaşan iki yanlış beyan düzeltildi (bayat eğitmen sayısı · sözlük-dışı akorun yanlış adı).

## 2026-08-04 (tur 50) — GÖZLEM İŞARETİ ŞERİDİ: 7 şart mekanik kapıda, en sert testi ben ekledim
Koordinatör hükmü M-F-232 (M-F-125 zeyli) uygulandı. **Şerit AYRI, gevşetme değil:** hiçbir `expertPending` bayrağı kalkmadı — uzman envanteri çıktısı öncesiyle **BİREBİR AYNI** (kanıt: `diff` boş).

| İş | Kanıt |
|---|---|
| **Yeni sınıf `observationCues`** — `OBS-TRUNK-RANGE`, üç çalgıda | G-/V-/P- ad-alanını TAŞIYAMAZ (şart 1, kapıda). Eşik = `gates.clusterToleranceDeg` 14,0°, artefakttan |
| **Metin config'te DEĞİL** (şart 2) | `config/observation-cue-templates.golden.json` (donmuş). "None of the {n} {sourceClass} we recorded leaned more than {thresholdDeg}° from upright. You are at {measuredDeg}° right now." — iki cümle de ÖLÇÜM BEYANI, hükmü kullanıcı kuruyor. Motor VERİ üretir, app doldurur |
| **Yasak dil kelime-sınırıyla taranıyor** | emir kipi · sebep-sonuç · beden-sonucu. Yapay ihlal ("Sit up straight — leaning causes back pain") **tek cümlede üç sınıfı da** yakalattı |
| **🔬 ŞART 6b — 6'nın en sert hâli (kendim ekledim)** | İşaret, referansı KURAN eğitmenlerin hold pencerelerinde ateşlerse cümle kendi kaynağıyla çelişir. **ÖLÇÜLDÜ: gitar 0/939 · şan 0/729 · piyano 0/407.** Eğitmenlerin EN KÖTÜ karesi 7,59° / 5,58° / 4,01° — eşiğin %54 / %40 / %29'u |
| Videonun tamamındaki oran ayrıca ölçüldü | gitar %20,2 · şan %0,5 · piyano %17,3. Beklenen ve doğru: eğitmen yürüyor, sapı göstermek için eğiliyor. **Sınav hold penceresinde, videonun tamamında değil** — ikisini karıştırmak işareti haksız yere "gürültülü" gösterirdi |
| **240.941 GERÇEK kare** üzerinde koşuldu | Sentetik "eğik gövde" üretilmedi — kendi ürettiğimiz sayıyı kendi eşiğimizle sınamak olurdu |
| **5 şart yapay ihlalle kırmızıya döndü, geri alınca yeşil** | ad-alanı · yasak dil · bayat n · **öğüt-kapısının açılması** · kendi kaynağıyla çelişme |
| **Kütüphane: 5 açık postür dersi işareti gösteriyor** | gitar 2 · şan 2 · piyano 1. `validate_library` **kural 8**: şeritler karışamaz — bir hata kodunu `observationCues` listesine yazıp expertPending'i atlamak ÜÇ kontrolle kesildi; kilitli ders hiçbir hüküm yüzeyi taşıyamaz |
| Kapılar | **10/10 yeşil** (`tools/run_gates.sh`) · 68/68 dart · analyze temiz |
| Commit | `002830c` |

**Durum:** Gözlem şeridi canlı ve yapısal olarak korunuyor. Üç çalgıda da postür artık hem SKORLANIYOR hem ölçüm-dilli işaret veriyor; adlandırılmış hata (öğüt) hâlâ kapalı ve kapısı sağlam.

**O-025 kapı-şartı kaydedildi:** hiçbir çalgıda zamanlama derecelendirilmeden önce motor-erkenliği asimetrisi (8,29 ms) kapanacak.

## 2026-08-04 (tur 49) — Şan+piyano ders yolu AÇILDI: eşik icadı yerine türetme, ve üç yanlış-eşleme
| İş | Kanıt |
|---|---|
| **Eşik merdiveni ARTEFAKTTAN türetiliyor** (`tools/derive_posture_thresholds.py`, yeni) | Ölçülen trunk_tilt dispersiyonu: gitar 2,24° · şan 1,35° · piyano 1,09°. Merdiven: anlaşma-tabanı < **skorlama-toleransı 8,0°** (quality barı) < **hata-eşiği 14,0°** (`gates.clusterToleranceDeg`). Tolerans modeli **27 eklem-çalgı çiftinde** artefaktın KENDİ `perJointSource`/`floorBoundShare` etiketleriyle doğrulandı — varsayılmadı |
| **M-O-63: eşik dispersiyondan DEĞİL, "dispersiyonun tabana çarptığı ölçümünden" geliyor** | Üç çalgıda da `floorBoundShare 1.0`: eğitmenler o kadar hemfikir ki (1,1-2,2°) çekirdek bu bandı güvenilmez bulup 8° tabana kıstırıyor. Koordinatörün "yalnız dispersiyondan" direktifinin dürüst hâli: dispersiyon DEĞERİ eşiği veremiyor, ama dispersiyonun ÖLÇÜMÜ veriyor |
| **`--check` kapısı 7 sapma buldu ve kapattı** | şan+piyano `noiseBand` 2 → 8 (gerekçeleri ölü B4 pilotuna dayanıyordu; **M-F-98 düzeltmesi yalnız gitara uygulanmış, ikisi geride kalmıştı**) · POSTURE_CHECK barları 5 → 8 (ölçüm bandının ALTINDAYDI) · şan SUSTAIN 15 → 8 (hata eşiğinin ÜSTÜNDEYDİ: 14-15° arasında **hata ateşlerken kalite geçiyordu**) · gitar+piyano hata eşiği 15 → 14,0 |
| **🔴 M-O-64 — YANLIŞ EŞLEME 1: `P-POST-SHOULDER-TENSION`** | Kod OMUZ yüksekliğini anlatıyor ("omuzlar kulaklara yaklaşır", 5 kanal), koşulu **`trunk_tilt`e** bağlıydı. Öne eğilen ama omuzları gevşek öğrencide ATEŞLER, omuzları kulağına yapışmış dik öğrencide SUSARDI. M-F-125'in öldürdüğü sınıf — tek farkı bağın ses yüksekliğine değil BAŞKA BİR POSTÜR METRİĞİNE olması, bu yüzden gözden kaçmıştı. Eşiği 15→14 diye "türetilmiş" göstermek yanlış eşlemeyi cilalamak olurdu → koşul SÖKÜLDÜ, `blockedByStatistic` isimli |
| **🔴 M-O-64 — DÜRÜST NEGATİF: şan hata koçluğu YAPILAMAZ** | 12 şan kodunun kamerayla görülebilir postür kodlarının HİÇBİRİ trunk_tilt'e karşılık gelmiyor: `V-POST-LOCKED-KNEES` diz ister (referans bel-üstü), `V-HEAD-CHIN-LIFT` baş/çene ister (9-eklemde baş yok). Eksik olan **eşik değil, eşleşecek KOD**. Ders açık ve postür skorlanıyor; hak edilmeyen isim verilmiyor |
| **M-F-140 beklentisi ÖLÇÜLDÜ ve KARŞILANMADI** | "Şan referansı doğunca V-POST-SHOULDER-RISE kendi istatistiğiyle geri girer" — referans doğdu, `right_shoulder` dispersiyonu **43,4°** ve `unreliableJoints`te. Geri girmiyor; sebep bu sefer kaynak yokluğu değil, ölçülen dağılım (P-ELBOW-ANGLE'ın M-F-147 sonucuyla aynı sınıf) |
| **`note_timing_ms` vaat olmaktan çıktı** (`AF-008-five-note-timing`, yeni) | Gerçek `OnsetDetector`→`MetronomeAligner`, **üç varyant** (tam ızgara / 40 ms erken / 40 ms geç). Tek "kusursuz" varyant, `align()` hep 0 dönse de geçerdi — üç varyant ölçümü AYIRT ETME testine çevirdi. Motor tabanı **8,29 ms** + **ASİMETRİ: aynı hata acele edende 49,33 ms, geç kalanda 31,28 ms** (motorun kendi erkenliği hükme sızıyor) |
| **🔴 M-O-65 — ÖLÜ KAPI, iki çalgıda** | piyano `note_timing_ms<=50` ve **gitar (CANLI) `strum_timing_ms<=60`**: ikisinin de metriğini hiçbir motor üretmiyor, ikisinin de barı uydurma. Gitarınki üç bağımsız okumayla doğrulandı — fixture_check "eşleme yok" diyor · uçtan-uca koşumda kapı HİÇ değerlendirilmedi · **kütüphane kullanıcıya zaten "not yet graded" diyordu, yani config ürünün kendi sözüyle çelişiyordu**. İkisi de indirildi; metrikler ölçülür, PUANLANMAZ |
| **🔴 BAYAT GEREKÇE — değer doğruyken (yeni sınıf)** | Gitarın `_noiseBand_why`ı "3 eğitmen, medyan 0,54°" diyordu; artefakt 7 take/2,24°'ye büyümüştü ama `noiseBand=8` **her iki durumda da doğru** (ikisi de tabana kısılıyor) → değer kapısı geçiriyordu. Panzehir: her skorlanan metriğe `_derivedFrom` (düzyazının makine-okunur ikizi), `--check` artefaktla karşılaştırıyor. Yapay ihlalle exit=1 sınandı |
| **Uçtan-uca ÜÇ ÇALGIDA** (betik çalgı-parametreli, M-O-39 dersi önceden) | gitar 116/116→115/115 (**öncekiyle birebir — regresyon yok**) · şan POSTURE_CHECK 101 + SUSTAIN 100, **üç gerçek quality kapısı** (trunk_tilt + pitch_deviation_cents + periodicity — üçünün en bütün zinciri) · piyano 80/80. Doğrulama take'i `evidenceThickness`e göre seçiliyor ve kalınlık RAPORLANIYOR (M-F-150) |
| **library.json: şan+piyano `coming_soon` → `live`** | Eski gerekçenin üç şartı: uçtan-uca ✅ · drill yolu ✅ (titular drill'ler gitarınkiyle AYNI standartta kilitli) · hata koçluğu **ölçülmüş negatif**. Blurb'lar düzeltildi: **piyano "hand feedback" vaat ediyordu, el landmark'ı HİÇ YOK**; şan "pitch/sustain feedback" vaat ediyordu, o ders kilitli |
| **Kapılar tek komuta indi** (`tools/run_gates.sh`, yeni) | 9/9 yeşil · 68/68 dart testi · `dart analyze` temiz. Regen sonrası eşik teyidi artık tek komut — koordinatörün istediği doğrulama yolu |
| Commit'ler | `76ea13d` (ders yolu) · `b3955bb` (gitar kusurları + provenance ikizi) |

**Durum:** Paketin 5 maddesi de kapandı. Madde 5 (gitar genişletmesi) ölçümle karşılandı: dolgu ders eklenmedi, canlı disiplinde iki gerçek kusur bulundu.

**Koordinatöre açık tek soru:** eşik artık artefakttan türüyor (14,0° = "hemfikir sayılan eğitmenlerin işgal ettiği aralığın dışı"). `expertPending` KALDI çünkü iki soru ayrıştı — (1) sayı savunulabilir mi → EVET; (2) bunu ÖĞÜT diliyle söyleyebilir miyiz → movement-science turu yok. Ölçüm-dilli bir işaret ("ölçtüğümüz eğitmenlerin hiçbiri bu kadar eğilmiyor") açık derste görünebilir mi, yoksa M-F-125 kapısı reçete/ölçüm ayrımı yapmadan mı kalsın? **Şu an KAPALI varsayıldı** — üç çalgıda da postür skorlanıyor ama adlandırılmış hata söylenmiyor.

## 2026-07-30 (gece, tur 48) — 0.8.6 pin + regen: sayılar aynı, kanıt-kalınlığı yeni şey söyledi
| İş | Kanıt |
|---|---|
| Pin `v0.8.5` → **`v0.8.6`** | `dependency_pin_test` yeşil. Python rig `origin/main`de (0.8.6 tag'i mecaz-merge'ünü içermiyor) |
| Regen: guitar 7 · voice 6 · piano 3 | Yeni alan hariç **BİREBİR AYNI** — çekirdek yükseltmesi artefaktı değiştirmiyor (2. kanıt) |
| **`evidenceThickness` ilk okuma** | voice 6/6 = 1.00 · piano 2/3 = 1.00 · **guitar 7 take'in yalnız 2'si 1.00** (0,41 / 0,57 / 0,57 / 0,61) |
| **Ders: take SAYISI ≠ referans GÜCÜ** | En çok take'li çalgı, take başına en ince kanıtlı. Kapı değil, rapor — ama "7 take" beyanı gücünden fazlasını ima etmesin |
| Lehçe kararı: **KORU** (M-F-150) | Benzersiz geçiş 3→0 ama ölçüm bu korpusa ait; kalıplarım oturma-özgü. Konsolidasyon olursa ilk aday |
| Commit+push | `48e1d43` |

**Durum:** Pin+regen (ders-yolu paketinin 1. adımı) bitti. Sıradaki: şan+piyano ders yolu (drill + hata koçluğu + uçtan-uca + library geçişleri) — büyük paket.

## 2026-07-30 (gece, tur 47) — Mecaz kapısı + en dolu havuz: guitar 7 · voice 6 · piano 3
| İş | Kanıt |
|---|---|
| Sıra çevrildi (gerekçeli) | Yama sınıflandırmayı değiştirdiği için ÖNCE yama, sonra TEK sınıflandırma — iki tur yapılmadı |
| **Mecaz kapısı** — `keep your head IN THE game` | core dalı `fix/posture-cue-metaphor` (push'lu). **LATENT kusur: korpusta 0 isabet (ölçüldü)**; yine de kapatıldı çünkü aktif yanlış-pozitif kötü kaynağı referansa sokar |
| Doğrulama | Sentetik 2 mecaz red / 3 gerçek yönerge korundu · aile süpürmesi 4 app / 114 kaynak **0 regresyon** |
| Uygunluk **27 → 38/57** | JabLab MOVEMENT_CUE ailesi (`c561204`) ile: guitar 15/22 · voice 12/19 · piano 9/14 |
| **guitar 5→7 · voice 4→6 · piano 3** | Üçü ATTESTED · `gateJoints=[trunk_tilt]` · bar 14.0 · outlier YOK |
| Config+library sayıları tazelendi | Bayat sayı bırakılmadı |
| **Yan bulgu: kendi lehçem artık gereksiz** | Süpürmede benzersiz geçiş 3 → 0; JabLab ailesi kapsıyor. Kaldırma kararı koordinatörde |
| Commit+push | `0ea5c9b` |

**Durum:** Üç referans da en dolu havuzla kurulu. Borç: motion-core `0.8.5` tag'i + `fix/posture-cue-metaphor` merge'ü (ikisi de koordinatörde).

## 2026-07-30 (gece, tur 46) — ÜÇ ÇALGININ DA REFERANSI KURULDU (şan+piyano İLK KEZ) — beyanlı kapı, 14° varsayılan bar
| İş | Kanıt |
|---|---|
| Çekirdek `101ed95` (gateJoints/gateBasis) tüketildi | İki pubspec GEÇİCİ SHA pini (tag yok); `dependency_pin_test` yeşil |
| **guitar 3 → 5 take** · ATTESTED · outlier YOK | `gateJoints=[trunk_tilt]`, bar **14.0** (varsayılan) |
| **voice 0 → 4 take — İLK ŞAN REFERANSI** | `config/references/voice-posture-setup.v1.json` |
| **piano 0 → 3 take — İLK PİYANO REFERANSI** | mirrorConfident=TRUE · `piano-posture-setup.v1.json` |
| **22° özel barı ÖLDÜ** | O bar aslında kol gürültüsüne tahammül payıydı; `scoringBarDeg` 22,0 → 14,0 |
| Şan+piyano config: PROVISIONAL → **ATTESTED** | artefakt yolu + kapı beyanı + unreliableJoints |
| `library.json`: kendi önceki gerekçemi çürüttüm | "take'ler anlaşmıyor" YANLIŞ çıktı; yeni metin gerçek engeli söylüyor (drill + hata koçluğu + uçtan-uca doğrulama). Eski gerekçe `_priorReasonSuperseded`de kayıtlı |
| Builder çalgı-parametreli yapıldı | Üç kopya yerine tek kanonik yol (M-O-39 dersi, bu sefer önceden) |
| Kapılar | validate_ruleset 23/23 · validate_library ✅ · uçtan-uca 116/116→115/115 ✅ · ostinato_audio 68/68 ✅ |
| Commit+push | `1d98da0` |

**Durum:** Üç çalgının da postür referansı ATTESTED. Kalan borç: motion-core `0.8.5` tag'i (koordinatörde) → SHA pini geri döner. Şan/piyano ders yolu açık ama içerik (drill + hata koçluğu + uçtan-uca) ayrı iş.

## 2026-07-30 (gece, tur 45) — Üç hüküm uygulandı + İKİ BÜYÜK DÜZELTME: sınıflandırmam bayatmış, ama anlaşma yine yok
| İş | Kanıt |
|---|---|
| **Şan araç-yarışı KOŞULDU** (presence merge geldi) | `178f92a`. Kazanan HOLD — ama asıl bulgu M-O-58: presence'ın sürücüsü dönmeye duyarsız, `trunk_tilt` yerçekimine göre → yapısal olarak ifade edilemiyor. Kod okuyarak değil ÖLÇEREK: gövde-vekili sürücüler p05=90,2-93,0°'de çakılı (anatomik sabit). Eşik uydurulmadı, 60-140° süpürmesi koşuldu |
| **M-O-53 uygulandı** | `2d4a722`. 4 gitar (+3 piyano) taslak koşulu SİLİNDİ, `aspirational`+`blockedByTool` ile isimli. expertPending artık İKİ okuyuculu: validate kural 7 + **üretilen** uzman envanteri (`gen_expert_inventory.py`). Envanter KENDİ dünkü işimde hata buldu (2 ders doğrulanmamış kodu anıyordu) + piyanoda aynı gizli tuzağı buldu |
| **M-O-54 uygulandı** | motion-core dalı `776da28` (push'lu, merge koordinatörde). Aile süpürmesi İLK SÜRÜMÜMÜ ÇÜRÜTTÜ: 8 geçişin 2'si yanlış yöndeydi (3. şahıs anlatım + 1. şahıs betimleme) → ikinci-şahıs şartına sıkılaştırıldı → 3 geçiş, üçü doğrulanmış |
| **🔴 DÜZELTME: uygunluk tablom bayatmış** | J-058 FIRST_PERSON_DEMO sınıfı hasadımdan SONRA çekirdeğe inmiş. Uygunluk **15 → 27/57**; hold pencereleri guitar 5/9 · voice 4/9 · piano 3/8 — üçü de minTakes ÜSTÜNDE. **Attribüsyon ölçüldü: açılışın sebebi merge'lü çekirdek, benim lehçem DEĞİL** (lehçe yalnız 1 şan kaynağı ekliyor) |
| **🔴 DÜRÜST NEGATİF: havuz büyüdü, ANLAŞMA gelmedi** | M-F-47 kapısı üçünü de reddetti: guitar 16,9/20,6/42,9/13,2/38,1 · voice 42,0/33,0/20,5/37,7 · piano 16,2/46,4/27,3. Voice+piano 22°'de bile kümelenmiyor. **"Daha çok hasat" stratejisinin ölçülmüş sınırı** |
| **M-F-129 piyano çift-kapısı: ikisi de NEGATİF** | `d3b7d54`. (i) lehçe piyanoyu etkilemiyor · (ii) presence piyanoyu kurtarmıyor (2/8 okunabilir vs hold 6/8). Piyano+şan `comingSoonReason` ÖLÇÜLEN gerekçeyle değişti: "yeterince take VAR, take'ler ANLAŞMIYOR" |
| Kendi aracımda bayat-metin avladım | `voice_tool_race.py` HÜKÜM bloğundaki sabit "3/4 şan kaynağında" metni piyano koşumunda yanlış rapor veriyordu — kaldırıldı, sayılar hesaplanıyor |

**Durum:** Koordinatörün üç bekleyeni de kapandı. Kapılar yeşil (validate_ruleset self-test 21/21 · validate_library ✅ · uçtan-uca 116/116→115/115 · replay 3 çalgı ✅ · ostinato_audio 68/68). Açık: anlaşmazlığın sınıfı (bar mı / kaynak-kimliği mi / pencere tanımı mı) — koordinatörde. Kurucu: gitar kaydı.

## 2026-07-29 (gece, tur 44) — Gece paketi: 4 kalem + İKİ YENİ BULGU (expertPending ölü bayrak · ACTIVE_MARKERS yapısal uyumsuzluğu)
| İş | Kanıt |
|---|---|
| **Şan araç-yarışı iskeleti** — presence_isolator merge'üne hazır boru hattı | `tools/voice_tool_race.py` · hold tarafı GERÇEK (core'a dokunulmadı, gevşetilmiş eşiklerle çağrı), presence tarafı isimle NOT_AVAILABLE · smoke-test 4/4 crash'siz, 1/4 pencere · `9f14e29` |
| **Gitar içerik genişletmesi** 2→6 ders | AÇILAN: "Camera and space" (ölçüm iddiası yok) · "Staying upright while you play" (yeni ölçüm değil, aynı ölçülerin farklı anı). KİLİTLİ+isimli: "Holding the guitar" (kollar coached_only) · "Foot support" (kalça altı hiç ölçülmüyor) · `f5e3dd5` |
| **🔴 M-O-53: `expertPending` bayrağının TÜKETİCİSİ YOK** | 5 gitar hata kodunun 4'ü taslak olarak `level_above_room_floor_db>15`e bağlı — "başparmak sapta" uyarısı SES YÜKSEKLİĞİNDE ateşlerdi. grep'le doğrulandı: hiçbir kod o bayrağı okumuyor. **Panzehir:** `validate_library.py` kural 7 (açık ders yalnız skorlanan metriğe bağlı kodu öne çıkarabilir), yapay ihlalle FAIL/meşruda PASS sınandı |
| **🔴 M-O-54: çalgı-postür dili `ACTIVE_MARKERS`a yapısal olarak çarpmıyor** | Ölçüldü: `Rpalo0sbpj4` "posture"×18/"sitting"×12 ama ACTIVE isabet=0; uygun ÇIKAN `v3nfqNOBAPc` yalnız GENEL "bring your" kalıbıyla geçmiş → havuz eleme değil RASTLANTI sonucu. Tek taraflı değiştirmedim (ilişkili `passive_execution_possible: true` beyanı savunulabilir) |
| **UI-BRIEF** (ortak kalem) | `docs/design/UI-BRIEF.md` — ekranlar bugün GERÇEKTEN ölçülenin üstüne kuruldu; canlı/skorlanmayan/kilitli/boş ayrı işaretli; durum listeleri (izin-reddi, "hüküm yok" bandı, "ölçemediklerimiz") asıl iş · `b2db1c8` |
| **Cooldown-hasat: 403 YOK, cooldown işe yaradı** | 7 aday · triyajı geçen 5 · **yeni uygun 1** (`2T70e4OroEY`, yine GENEL işaretlerle: "actively/bring your/lift your" → M-O-54'ü doğruluyor) · **yeni hold-penceresi 0** (piyano 2/6, minTakes=3 kapısı hâlâ kapalı). Darboğaz iki katmanlı: ROM-mod sınıflandırması + onu geçende bile pencere çıkmaması. 7 adaylık tur minTakes'i 1 hane ilerletmedi |

**Durum: HOLD — 3 isimli tetik bekleniyor** (sessiz bekleme değil, sıradaki iş kalemleri tetiğe bağlı):
1. **Koordinatör presence-merge işareti** → `tools/voice_tool_race.py`de `run_presence_trunk()` tek satırda bağlanır, şan araç-yarışı koşulur.
2. **Koordinatör M-O-53/M-O-54 hükümleri** → (53) `expertPending`in aile-geneli tüketicisi + 4 taslak hata-koşulunun metrik/eşik eşlemesi · (54) `ACTIVE_MARKERS`a çalgı-postürü lehçesi mi, `passive_execution_possible` yeniden değerlendirmesi mi.
3. **Kurucu gitar kaydı** → `make_chord_fixture.dart`ın `--real` hattı; "Open chords" dersi açılır (ara mühendislik sıfır, M-O-52).

Kapılar paket sonrası yeniden koşuldu ve hepsi yeşil: `validate_library` · `validate_ruleset` · `verify_end_to_end_session` (116/116 → 115/115) · `replay_check` (3 çalgı) · `ostinato_audio` 68/68.

## 2026-07-29 (gece, tur 43) — M-F-116 kapandı: ham-örnekli akor fixture'ı (AF-007) + uçtan-uca senaryoda gerçek kromagram koşumu
| İş | Kanıt |
|---|---|
| `make_chord_fixture.dart` (yeni): E majör akor sentezi → GERÇEK `ChordDetector` → ölçülen `score/chordName/runnerUp` kalıcı fixture'a yazıldı | 29 pencere, %100 judged, skor 0,89-0,94, runnerUp her pencerede "Em" (M-O-36 tutarlı) |
| `fixtures/audio/AF-007-open-chord-E-major.json` (yeni) + `index.json`e kayıt | dosyalar repoda |
| `verify_end_to_end_session.py` yeniden bağlandı — `chord_correctness` artık M-O-35'ten ALINTI (sabit 1.0) DEĞİL, AF-007'nin gerçek pencere-pencere `score`'undan okunuyor | POSTURE_CHECK 116/116 PASS → gerçek exit → PLAY 115/115 chord_correctness PASS |
| Kalan (beyanlı) sınır: seviye-tetiği (AF-003) ile akor-kalitesi (AF-007) hâlâ iki bağımsız kayıt — gizlenmedi | dosya başlığında yazılı |
| Doğrulama: `validate_library.py` ✅ · `replay_check.py` 3 çalgı ✅ · `dart analyze` temiz · `ostinato_audio` 68/68 test | komut çıktıları |
| Commit+push | `0f1983f` |

**Durum:** M-F-116 (kurucunun gitar kaydı geldiğinde ara mühendislik sıfır) kapandı. Koordinatöre bildirilecek.

## 2026-07-29 (gece, tur 42) — Şan presence-spec hazırlığı: M-F-95 şüphesi ölçüldü, spekülasyon kalmadı
| İş | Kanıt |
|---|---|
| 4 uygun şan kaynağında enerji/drift ölçüldü | `hold_isolator`'ın AYNI fonksiyonlarıyla, 5sn kayan pencereler |
| **Drift medyanı gitar/piyano eşiğinin 4-16 katı** | 0,27-0,97 vs 0,06-0,08. Enerji medyanı (0,12-0,19/s) daha makul |
| Yorum: hold_isolator'ın "yavaş sürüklenme" tuzağının TERSİ | Şarkıcı hızlı hareket etmiyor ama yavaşça sürükleniyor (nefes/salınım) — gerçek performans, yapısal olarak "tutuş" değil | M-O-51 (motion-core DEFTER) |
| **Öneri yazıldı (karar değil):** `docs/g4-prep/sarki-postur-presence-spec.md` | presence ≠ hold-epsilon; scope=trunkOnly + enerji tavanı var + drift KAPI değil, trunk_tilt bant-genişliği DAYANAK olarak ölçülsün |
| Commit+push | `63aaced` |

**Durum:** M-F-108 paketinin dördü de (MIDI kitle-notu, içerik kütüphanesi, uçtan-uca senaryo, presence-spec) tamamlandı. Koordinatöre bildirilecek.

## 2026-07-29 (gece, tur 41) — Gitar içerik katmanı: J-038 kilitli-ders deseni + ilk uçtan-uca senaryo
| İş | Kanıt |
|---|---|
| `assets/content/library.json` yazıldı | JabLab deseni uyarlandı: "Sitting posture" AÇIK (yalnız trunk_tilt), "Open chords" `locked` + `lockedReason` (chord_correctness gerçek kayıtta doğrulanmadı); voice/piano `coming_soon` + isimli gerekçe |
| `validate_library.py` yazıldı, doğrulandı | JabLab'ın 6 dürüstlük kuralı Python'da; yapay ihlalle FAIL, düzeltilince PASS |
| **`verify_end_to_end_session.py`: postür+akor hattı BİRLİKTE zincirlendi** | Gerçek ATTESTED postür penceresi + gerçek ses fixture'ları: POSTURE_CHECK 116/116 PASS → PLAY'e geçiş → chord_correctness 115/115 PASS. READY stub'landı (motoru yok, gizlenmedi) | M-O-50 (motion-core DEFTER) |
| **Dürüst sınır:** chord_correctness değeri M-O-35'in kanıtlanmış sonucundan alındı, yeniden hesaplanmadı | AF-003 ham örnek taşımıyor; tam entegre test (ham-örnekli akor fixture'ı) kapsam dışı, sıradaki iş kalemi |
| Yan düzeltme | guitar config'teki stale "Basic Pitch" referansı düzeltildi + MIDI kitle-notu eklendi |
| Commit+push | `4023c69` |

**Sıradaki:** Şan presence-spec hazırlığı (yazı, presence_isolator merge öncesi).

## 2026-07-29 (gece, tur 40) — MIDI-girişli akor tanıma spike'ı kapandı: teknik triviyal, ürün önceliği düşük
| İş | Kanıt |
|---|---|
| `midi_chord_detector.dart` yazıldı | Kromagram `ChordDetector`in AYNI `ChordTemplate` sözlüğünü reuse eder; MIDI'de DSP belirsizliği yok, skor tam-kapsama oranı |
| **8/8 açık akor gerçek MIDI notalarıyla doğrulandı** | Standart EADGBE akort + açık pozisyon, müzik teorisiyle çapraz kontrollü (uydurulmadı). 6/6 test yeşil, analyze temiz |
| Donanım araştırması (WebSearch) | Fishman TriplePlay/Roland GK $200-400, DAW/kompozisyon hedefli — open_chord_drill'in yeni-başlayan kitlesi DEĞİL | M-O-49 (motion-core DEFTER) |
| Karar önerisi | Kod ücretsiz tutulabilir (opsiyonel), varsayılan/pazarlanan yol OLMAMALI — erken teşhis, inşa etmeden önce |
| Rapor + commit+push | `docs/g4-prep/midi-chord-spike-sonuc.md` · `2973943` |

**Durum:** M-O-33/34/35'ten beri açık olan MIDI sorusu TAMAMEN kapandı. Koordinatörün sonraki talimatını bekliyorum.

## 2026-07-29 (gece, tur 39) — Beşinci soru kapandı: referansın tüketicisi CANLI, üç iddia gerçek karede doğrulandı
| İş | Kanıt |
|---|---|
| `verify_score_consumer_live.py` yazıldı | Gerçek kaynak (8xFzcSieBXY) + kontrollü-bozulma ikizi (+20° katı döndürme, kalça pivotu) |
| **(a) trunk_tilt referans-tabanlı hüküm üretiyor** | Gerçek kaynak 231/231 PASS, döndürülmüş ikiz 231/231 FAIL, medyan delta +20,0° (beklenenle birebir) |
| **(b) Statik denetim temiz** | Hiçbir quality/error kol-eklemine dayanmıyor. Yan-bulgu (kusur değil): forearm/upper_arm mutlak-dikey açı olduğundan döndürmeyle değişti, elbow'lar (iç açı) değişmedi — ikisi de zaten skorlamıyor |
| **(c) Taraf-bazlı sızıntı YOK — ama ilk denemede kendi test hatamı buldum** | Sol omuz+dirsek+bilek birlikte bozununca 231/231 hüküm değişti — omuz hem trunk_tilt hem kol girdisi, paylaşılan landmark'ı bozmak gerçek sızıntı DEĞİLDİ. Düzeltme: yalnız dirsek+bilek bozuldu, omuza dokunulmadı → 0/231 değişti | M-O-48 (motion-core DEFTER) |
| Commit+push | `e4b7f87` |

**Durum:** "Bağlandı ≠ canlı" farkı kapandı. Sıradaki: MIDI spike (M-O-33'ten beri bekleyen).

## 2026-07-29 (gece, tur 38) — AİLENİN İLK ÇALGI REFERANSI: gitar postürü kanonik olarak kuruldu
| İş | Kanıt |
|---|---|
| Koordinatör kararı (M-F-98): (a)-yolu, stil sınıfı | trunk_tilt=skorlanan (postür), kol-zinciri=coached_only (çalgıyı tutma stili) |
| `motion_core-v0.8.4` (J-056) çekildi, tablo TEKRAR ölçüldü | Sayılar 0.8.2'ye göre neredeyse aynı (18,1/11,6/17,8) — bu veri setinde J-056 etkisi ihmal edilebilir, 22° tolerans temeli geçerli kaldı |
| `build_guitar_reference.dart` yazıldı | `ReferenceCli(specs: upperBody, clusterToleranceDeg: 22).buildArtifact()` — 3/3 take kabul edildi, **measurementProvenance=ATTESTED**, 0 dışlama |
| Artefakt üretildi | `config/references/guitar-posture-setup.v1.json` — `unreliableJoints=[left_elbow, left_forearm]` çekirdek bağımsız doğruladı |
| **`guitar@0.2.0-draft.json` bağlandı** | `referenceConsumption` yeniden yazıldı (scoringBarDeg=22, scored=[trunk_tilt], coached_only=8 kol-eklemi, mirrorAmbiguityNote); `trunk_tilt.noiseBand` 2→8 (floor-bound); `POSTURE_CHECK.quality.trunk_tilt` 5→8 |
| **Yan-etki yakalandı:** `dependency_pin_test.dart` ikinci gerçek avını yaptı | `ostinato_audio` 0.8.2'de kalmıştı (dart_pilot 0.8.4'e geçince), test yakaladı, düzeltildi, 62/62 yeşil |
| **Kapılar:** validate_ruleset.py temiz · fixture_check.py değişmedi (9/2/2) · replay_check.py POSTURE_CHECK %100 | M-O-47 (motion-core DEFTER) |
| Commit+push | `4bea897` (referans+config) + `1a23678` (pin düzeltmesi) |

**Durum:** Gitar postür referansı KAPANDI. Şan/piyano hâlâ veri-yetersiz — M-F-95 cooldown'u ve/veya kurucunun opsiyonel kaydını bekliyor.

## 2026-07-29 (gece, tur 37) — Eklem-başına sapma tablosu: gövde sıkı, tüm kol-zinciri serbest
| İş | Kanıt |
|---|---|
| `joint_deviation_table.dart` yazıldı | `ReferenceBuilder._deviationsFromConsensus`in AYNI algoritması (public parçalarla), eklem-medyanına sıkıştırmadan tam tablo döndürüyor |
| **Doğrulama:** eklem-medyanları `build()`ın attığı hatayla BİREBİR eşleşti | 18,3°/11,4°/18,1° — replikasyon doğru |
| **Bulgu:** `trunk_tilt` neredeyse mükemmel (0,6-0,9°); 8/9 kol-eklemi yüksek sapmalı | Sol dirsek/ön-kol bazı çiftlerde 90-122°'ye çıkıyor. Koordinatörün "kol serbest, gövde sıkı" örneğine yapısal yakın ama SAYI olarak 8/9 = çoğunluk da okunabilir | M-O-46 (motion-core DEFTER) |
| Çekince: `mirrorConfident=false` | Sol-sağ asimetrisi kısmen aynalama belirsizliğinin artefaktı olabilir; kol-zincirinin TOPLAMI (sol+sağ) daha güvenilir okuma |
| Koordinatöre tam tablo + çekince bildirildi | Hüküm (stil-sınıfı mı, okul-farkı mı) koordinatörde |

**Kapılar:** yeni araç `dart analyze` temiz.

## 2026-07-29 (gece, tur 36) — Koordinatör kararı (M-F-95): hasat DURDURULDU (cooldown), (b)'ye geçiş YOK
| İş | Kanıt |
|---|---|
| **403 serisinde ısrar etmeme kararı doğrulandı** | Aile kuralı oldu: "403 serisi = tur biter, cooldown" |
| **Gitar: havuz KURU DEĞİL** | 8 adayın 2'si 403'le HİÇ denenmedi — "kuru" hükmü verilemez. Bu oturumda BAŞKA hasat YOK; sonraki oturum/gün cooldown sonrası tek hedefli geçiş (önce o 2 aday) |
| **Opsiyonel kurucu kalemi** | Mevcut kurucu-bekleyen gitar kaydına (8 akor×3, M-O-33/kromagram) 2-3 dk oturuş-postürü tutuşu eklenirse firstParty 3. kaynak olur, hasatsız kapatır — kurucu isterse |
| **Şan: DONDURULDU** | 1/4 verim + 0/4 hold → malzeme-sınıfı şüphesi (şancılar ayakta/hareketli, postür-tutuş nadir). Gitar çözülene dek tur harcanmayacak |
| **Piyano: değişmedi** | Terim-değişikliği şartı duruyor |
| **(b)'ye geçiş YOK** | Gitar 1 kaynak uzakta |
| Sıradaki kanonik koşumlar `motion_core-v0.8.4` ile | `eb28039` — J-056 görünürlük-kapısı, eklem-düzeyinde dürüst NaN. Gitar 3. kaynak gelince tablo bu pinle + `--scope upperBody` tekrarlanacak |
| Pin-testi ilk gerçek avını yakaladı | ostinato_audio sürüklenmesi — desen kendini kanıtladı, M-F-95'e kayıtlı |

**Durum:** Bu tur kapandı. Sıradaki iş = koordinatör/kurucu tetiği (cooldown sonrası hasat, VEYA kurucunun opsiyonel postür-tutuş kaydı, VEYA MIDI gerçek-donanım ölçümü).

## 2026-07-29 (gece, tur 35) — İLK M-F-47 TABLOSU: gitar 3/3 kapıdan %100 geçti ama agreement gate GERÇEK anlaşmazlıkla reddetti
| İş | Kanıt |
|---|---|
| `hold_isolator@57b3ccd` (kapsam parametreli, `scope=upperBody`) çekildi | Self-test yeşil: bel-üstü çekim fullBody'de haklı ret, upperBody'de kabul (0,028/0,030) |
| `find_hold_windows.py` `scope="upperBody"` ile güncellendi | Diz/ayak bileği artık ne görünürlük ne enerji/drift ölçümüne karışıyor |
| **Pencere bulma:** şan 1/4 · **gitar 3/6** · piyano 2/5 | Gitar TAM minTakes=3'e ulaştı |
| **Gitar kanonik kapıdan %100 geçti (231/231, 181/181, 135/135)** | M-O-41+42+43 kombinasyonu tam beklendiği gibi çalıştı |
| **AMA `ReferenceAgreementError` ile reddedildi — bu kez GERÇEK anlaşmazlık** | 8xFzcSieBXY 18,3° · NCV9IgeSYuU 11,4° · v3nfqNOBAPc 18,1° — yalnız 1/3 eşik içinde. Ölçüm hijyeni artık suçlu DEĞİL: 3 bağımsız eğitmen gerçekten 11-18° ayrışıyor | M-O-45 (motion-core DEFTER) |
| Şan (1/4) ve piyano (2/5) hâlâ minTakes altında | Agreement sorusu onlar için test edilemedi |
| Koordinatöre M-F-47 tablosu bildirildi | Gözlem (karar değil): gitarın tek eşik-içi kaynağıyla diğerleri arası fark küçük (~7°) — 1-2 kaynak daha üçlü alt-küme oluşturabilir, ama ölçülmedi, spekülasyon |

**Kapılar:** `find_hold_windows.py` değişikliği küçük (scope parametresi eklendi), analyze gerektirmiyor (Python).

## 2026-07-29 (gece, tur 34) — Hedefli hasat (M-F-82): gitar +1 uygun kaynak, şan +0, havuzlar hâlâ minTakes altında
| İş | Kanıt |
|---|---|
| `kaynak-arama protokolü v1` elle koşuldu | ytsearch-metadata (yt-dlp) → dedup(kanal, mevcut 14+14 havuzla karşılaştırıldı) → `harvest.py run` uçtan uca (pull+triyaj+extract+transcribe) → `reclassify_rom.py`. Model dosyası worktree'de eksikti, canlı ağaçtan kopyalanıp SHA-256 doğrulandı |
| **Gitar (öncelik 1):** 8 yeni-kanal aday, 6 fixture üretti | 1 triyajda reddedildi (üst-gövde oranı) · 2'si yt-dlp 403 (İNDİRİLEMEDİ, ~13 ardışık indirimden sonra hız-sınırı şüphesi — ZORLANMADI, ısrar edilmedi) |
| **1 yeni uygun kaynak: `v3nfqNOBAPc`** | Transkriptle `unknown→active`. Gitar uygunluk 5/15→**6/21**; hold_isolator pencere buldu (135 kare, drift=0,053) → havuz 1/5→**2/6**, hâlâ <3 (minTakes) |
| **Şan (öncelik 2):** 4 yeni-kanal aday, 1 fixture üretti | 3'ü triyajda reddedildi (netlik/kadraj); üretilen de `unknown` kaldı (ACTIVE_MARKERS isabet etmedi). Uygunluk 4/18→4/19, YENİ UYGUN YOK, hold-havuzu 0/4 değişmedi |
| Piyano | Dokunulmadı (talimat: arama-terimi değişmeden aynı duvara çarpar) |
| **M-F-47 tablosu bu turda da üretilemedi** | Her iki çalgı da agreement gate'e ulaşmadan minTakes kapısında durdu | M-O-44 (motion-core DEFTER) |
| Koordinatöre bildirildi | Karar: daha fazla hasat mı (403 riski var) yoksa çalgı-bazlı (b)'ye mi geçilsin |

**Kapılar:** araçlar değişmedi; yalnız `config/fixture-instrument-map.json`ya 6 kayıt eklendi.

## 2026-07-29 (gece, tur 33) — 1c kalibrasyon turu: M-O-41 düzeltmesi ÇALIŞIYOR ama bulma oranını çökertti — kök neden ölçüldü
| İş | Kanıt |
|---|---|
| `hold_isolator@c3d9251` (görünürlük/kadraj kriteri eklenmiş) çekildi | Worktree `c3d9251`'e güncellendi, self-test yeşil (+2 yeni senaryo) |
| Tüm uygun kaynaklar (14) yeniden tarandı | `find_hold_windows.py` değişmeden çalıştı (API sabit kaldı) |
| **Bulma oranı 8/14 → 1/14'e ÇÖKTÜ** | şan 0/4 (önceki 3/4) · gitar 1/5 (önceki 2/5) · piyano 0/5 (önceki 3/5) — 0,08 geri-çekilmesi de kurtarmadı |
| **Ama pozitif taraf DOĞRULANDI: bulunan TEK pencere kanonik kapıdan 231/231 (%100) geçti** | Önceki turda AYNI sınıf pencereler 0/89, 0/82, 0/173'tü — M-O-41'in "pencere ancak kapıdan sağ çıkarsa penceredir" tanısı doğru |
| **Kök neden ÖLÇÜLDÜ (varsayılmadı):** `_frame_visible`in landmark kapsamı bizim ihtiyacımızdan geniş | `_frame_visible`, `movement_isolator.BODY`ı (12 landmark, diz+ayak bileği DAHİL) kontrol ediyor; bizim `StandardJoints.upperBody` yalnız 8 üst-vücut landmark'ı ister. 3 eski-başarılı pencere örneklendi: görünürlük-geçen 0/331, 0/91, 0/89 (%0). Bir kareyi elle inceledim: omuz/dirsek/bilek/kalça 0,92-1,00 görünürlük, diz 0,09-0,23, ayak bileği 0,03-0,04 — bel-üstü çekim TİPİK, bacak yapısal olarak kadrajda yok. `min_share=0.8` (≥10/12) her zaman reddediyor çünkü yalnız 8/12 (%67) görünür | M-O-43 (motion-core DEFTER) |
| Havuzlar şimdi hepsi minTakes=3'ün altında | M-F-47 tablosu bu turda üretilemedi (agreement gate'e hiç ulaşılamadı) |
| Koordinatöre bildirildi | Öneri: `_frame_visible`in landmark kapsamı çağıranın `required` setine parametrelensin — kendim değiştirmedim (core kodu) |

**Kapılar:** araçlar değişmedi, `dart analyze` zaten temizdi.

## 2026-07-29 (gece, tur 32) — hold_isolator gerçek veriyle koşuldu: kendi birim kaçağımı buldum, piyanoda %100 torsoUnreliable
| İş | Kanıt |
|---|---|
| Kendi worktree açıldı | `~/motion-worktrees/ostinato-hold-isolator` (origin/main @ `4ad1e2c`) — motion-core paylaşımlı ağacı (`feat/lissom-v3-onayi` dalında) DAL DEĞİŞTİRİLMEDEN (M-F-22) |
| `tools/find_hold_windows.py` yazıldı | `rom_mode.ACTIVE_MARKERS`in AYNI regex'iyle transkriptten aday-zamanı çıkarır, `hold_isolator.find_hold_windows`i koşturur, bulamazsa 0.06→0.08 geri-çeker (talimatlı) |
| **Pencere bulma oranı** | şan 3/4 · gitar 2/5 · piyano 3/5 — 5 kaynak 0,08'de bile bulunamadı |
| **Drift kalibrasyon verisi koordinatöre gönderildi** | Bulunanlar sınıra ÇOK yakın kümelendi (0,046-0,06 arası, biri tam 0,06'da); yalnız 1 kaynak 0,08 geri-çekilmesiyle bulundu |
| **Kendi kusurum: birim kaçağı (bulundu, düzeltildi)** | Python ham (undetected dahil) kare-indeksi veriyordu, Dart `Fixture.frames` yalnız tespit-edilmiş kareler tutuyor — ikisi eşleşmiyordu (1 kaynakta pencere fixture sınırını aştı, yakalandı). M-O-23/27 dersiyle düzeltildi: `tStartS`/`tEndS` (süre), kare-indeksi DEĞİL |
| **Düzeltme SONRASI bile üçü de reddedildi** | Şan: 3 bulunandan 1'i (89 kare) kanonik güven-kapısında 0'a düştü → 2<3. **Piyano: ÜÇÜ DE (89/82/173 kare) 0'a düştü** |
| **Teşhis edildi, varsayılmadı: piyanoda %100 `torsoUnreliable`** | 3 kaynağın 3'ünde de `ConfidenceGate` ayrı ayrı doğrulandı — muhtemelen piyano çekim geleneği (kamera el/klavye odaklı, gövde kadraj-dışı/güvenilmez). `hold_isolator`'ın kapsama kriteri LANDMARK VARLIĞI ölçüyor, GÜVENİLİRLİK ölçmüyor — ikisi farklı | M-O-42 (motion-core DEFTER) |
| Koordinatöre bildirildi | Girdi: torso-güvenilirlik kriteri hold_isolator'a eklensin mi + piyano kamera-açısı ayrı hasat sorunu mu — kendim karar vermedim |

**Kapılar:** `find_hold_windows.py`, `hold_reference.dart` `dart analyze` temiz.

## 2026-07-29 (gece, tur 30) — Koordinatör talimatı (M-F-70) yürütüldü: 0.8.0 fark yaratmadı, ama "take = tam video" kusuru açığa çıktı
| İş | Kanıt |
|---|---|
| Ön-kontrol | Fixture'lar `.full.json` — TAM VİDEO (3.142-55.683 kare, 24-30fps'te 2-40+ dakika), rig'in hareket-izolasyon penceresi YOK. `t` alanı ms (dart_pilot'un `*1e6` çevrimi saniye varsayıyordu — kullanılmayan alan, sessiz zarar yok, kayda geçti) |
| `motion_core-v0.8.0` (`3c310fe`) çekildi | `tools/dart_pilot/bin/canonical_reference.dart` yazıldı — pilot kopyası DEĞİL, doğrudan `ReferenceCli.buildArtifact` çağırıyor (M-O-39'un yakaladığı deseni tekrarlamamak için) |
| **Periyot ÖLÇÜLDÜ:** 14/14 uygun kaynak `measured=false` | cycleSegmentation **notApplied**; `segmentCycles:true`/`false` birebir aynı hatayı verdi — M-F-70'in öngörüsü doğrulandı, varsayılmadı |
| **SONUÇ: üçü de yine reddedildi, sayılar pilot'tan DAHA KÖTÜ** | şan 10,7-23,8° · **gitar 27,1-49,6°** (pilot: 8-33°) · **piyano 36,5-62,0°** (pilot: 15-39°). Sebep: kanonik `prepareTake` pilot'un "en durağan 90 kare" sezgisiyle SINIRLAMIYOR — güven-kapısından geçen TÜM video karesi tek take'e giriyor |
| **Daha derin bulgu: bu yalnız "az kaynak" sorunu değil** | M-F-68 HIGH-1 ile aynı sınıf, take-düzeyinde: statik malzeme için ölçülmüş bir izolasyon adımı yok. "Tüm video" ortalaması posture_setup'ı dersin geri kalanıyla (konuşma, yürüme, oturma) sulandırıyor. Hedefli hasat (seçenek a) tek başına, yeni kaynaklar da tam-video gelirse aynı sınıfta kalabilir | M-O-40 (motion-core DEFTER) |
| Koordinatöre bildirildi | `mcp__ccd_session_mgmt__send_message` ile özet + M-O-40 gönderildi; karar (seçenek a/b + statik-take izolasyon tasarımı) koordinatörde |
| **Koordinatör eki: `motion_core-v0.8.1`'e (`c5f93f0`) pinlenip TEKRAR koşuldu** | Sonuç DEĞİŞMEDİ (şan 11,3-24,1° · gitar 26,4-49,4° · piyano 38,8-64,8°, üçü de yine reddedildi) — DTW zamansal-koridor + rig motion_energy düzeltmeleri bu ölçüye dokunmuyor, çünkü periyot hiç bulunamadığından CycleAligner yoluna hiç girilmiyor. Beklenen, ölçülerek doğrulandı; M-O-40'a ek not düşüldü, koordinatöre bildirildi |

**Kapılar:** dart_pilot paketinin kendi test paketi yok (manuel araç); `canonical_reference.dart`/`pilot.dart` `dart analyze` temiz (motion_core-v0.8.0 karşı).

## 2026-07-29 (gece, tur 31) — ARA ADIM 1b (M-F-75): sulanma giderilince gitar YAKINSADI, şan/piyano havuzu çöktü
| İş | Kanıt |
|---|---|
| `motion_core-v0.8.2` (`c1f8ed3`) çekildi | `tools/dart_pilot/bin/windowed_reference.dart` yazıldı — pilot.dart'ın "en durağan 90 kare" sezgisiyle her fixture'ı KESİYOR (`windowRule: heuristic-mostStatic90, PROVISIONAL`, konsolda beyanlı), sonra kanonik `ReferenceCli.buildArtifact`a veriyor |
| **Beklenmeyen bulgu: pencere kanonik güven-kapısından çoğu zaman geçemiyor** | şan 4 uygun kaynaktan **2'si**, piyano 5'ten **3'ü** "no measurable frames" ile TAMAMEN düştü — havuz 3'ün altına indi, agreement gate'e ULAŞMADAN reddedildi. Sebep: pilot'un pencere-arama sezgisi yalnız açı-uzayında en az hareketi minimize ediyor, GÖRÜNÜRLÜK/KADRAJ kriteri yok |
| **Gitar KISMEN YAKINSADI** | 5'ten 2'si düştü, kalan 3 agreement gate'e ulaştı: sapmalar tüm-video 27,1-49,6°'den pencereli **13,6° / 24,7° / 38,3°**'ye indi — en iyisi 14° eşiğinin ALTINA girdi. Yine de yalnız 1/3 eşik içinde → küme minTakes=3'ü karşılamadı, reddedildi. Ama yön DOĞRU: sulanma gerçekten sorunun parçası |
| **Cevap: gitar için KISMEN EVET, şan/piyano için CEVAPLANAMADI** | Havuz-çöküşü yüzünden şan/piyano'da "anlaşıyor mu" sorusu hiç sınanamadı — bu ayrı bir problem (pencere kalitesi), instructor-anlaşmazlığı değil | M-O-41 (motion-core DEFTER) |
| Girdi koordinatörün `hold_isolator` tasarımına | Yalnız hareket-enerjisi + poz-kararlılığı yetmez, görünürlük/kadraj kriteri de gerekir |
| Koordinatöre bildirildi | Özet + M-O-41 gönderildi; devam talimatı bekleniyor |

**Kapılar:** `windowed_reference.dart` `dart analyze` temiz (motion_core-v0.8.2 karşı).

## 2026-07-29 (gece, tur 29) — Uygunluk zinciri KOŞTU + pilotta P0 kusur bulundu: ölçüm hâlâ ineligible kaynaklardan kuruluyordu
| İş | Kanıt |
|---|---|
| main'e geçildi | `origin/main` `1a3c2a4` (M-F-67 merge'ü), fast-forward, çalışma ağacı temiz |
| **Uygunluk yeniden sınıflandırıldı** | `reclassify_rom.py` kuru+`--write`: 45/45 transkriptli → uygun **şan 4/18 · gitar 5/15 · piyano 5/10** (öncekiyle kıyas: 3/18 · 0/15 · 0/10) — üçü de ≥3 eşiğini geçti |
| **P0 — pilot kapıyı okuyordu ama TÜKETMİYORDU** | `admitted` (eligible+firstParty) yalnız `admitted.length<3` SAYIM kapısı için hesaplanıyordu; asıl ölçüm (`resolveMirroring`/`build`) filtrelenmemiş TÜM `takes`ten (ineligible dahil) kuruluyordu. Kanonik `ReferenceCli.buildArtifact()` (core) referansı `build()`a girmeden filtreliyor — pilot bu deseni kopyalamamıştı. Düzeltildi: `pilot.dart` artık `admitted`i besliyor | `tools/dart_pilot/bin/pilot.dart` diff (M-O-39) |
| **SONUÇ: honest ölçümle 3 çalgının HİÇBİRİ referans kuramıyor** | `ReferenceAgreementError` (M-F-47 küme <14° için çok küçük): şan 4 kaynağın 0'ı kümede · gitar 5'in 2'si (yine <minTakes=3) · piyano 5'in 0'ı. Lissom M-F-60(1) ile aynı sınıf ("ilk kanonik CLI koşumu = RED, RED mimariyi doğruladı"). Eşik/tolerans GEVŞETİLMEDİ | M-O-39 (motion-core DEFTER) |
| Config'ler DOKUNULMADI | `_measurementProvenance: PROVISIONAL` durumu üç config'te de aynı kalıyor — yenileme denendi, agreement gate reddetti; scoringBarDeg/noiseBand eski (n=18/15/10 karışık-havuz) değerlerinde donuk kalıyor |
| **Veri-toplama önerisi koordinatöre gönderildi** | M-O-39 içinde: ya `posture_setup` için hedefli yeni hasat turu (aktif-gösterim ağırlıklı arama), ya da üç config süresiz PROVISIONAL + taraf-bağımsız-olmayan eklemler süresiz coached_only. Seçim ürün önceliği sorusu |

**Kapılar (dokunulmayan paket):** dart_pilot'un kendi test paketi yok (manuel araç); `packages/ostinato_audio` testleri bu turda değişmedi.

**MIDI modu spike'ı (İKİNCİ İŞ) — koşuldu, kısmi sonuç:**
| İş | Kanıt |
|---|---|
| Yeni atılabilir spike | `tools/midi_spike/` — macOS-hedefli minimal Flutter app (`motion_shell` platform iskeletinin YERİNE GEÇMEZ, M-F-25 sınırı korundu); entitlements örnek pakettten (`flutter_midi_command` example) kopyalandı (bluetooth+network) |
| **Gerçek motorla koşuldu** (release build, bu makinede fiziksel MIDI donanımı yok) | Cihaz keşfi: `midi.devices` doğru 0 · `addVirtualDevice` sonrası TAM 1 cihaz (`type=ownVirtual`) kendi taramada göründü · `connectToDevice` başarıyla bağlandı — keşif+bağlantı yolu ÇALIŞIYOR |
| **Öz-loopback vermiyor — ölçülerek öğrenildi** | Gönderilen NoteOn 500ms içinde `onMidiDataReceived`e dönmedi: `addVirtualDevice` bir CoreMIDI SOURCE yaratıyor, kendi gönderdiğimizi kendimize yankılamıyor. Gerçek gecikme sayısı fiziksel cihaz veya IAC Driver (şu an bu makinede kapalı, sistem ayarı — açmadım) gerektiriyor | O-021 |
| Ortam tuzağı (yeni değil) | İlk build iCloud-senkron `~/Documents` altında codesign'a takıldı → bilinen fix (`build/` → `~/midi-spike-buildout` sembolik link) uygulandı, ikinci denemede yeşil |

**Sıradaki:** MIDI gerçek-donanım/IAC ölçümü (kurucu-bekleyen) · uygunluk zincirinin veri-toplama kararı (koordinatör-bekleyen, M-O-39).

## 2026-07-29 (kapanış) — whisper zinciri TAMAM + merge isteği
| İş | Kanıt |
|---|---|
| **Transkript geri doldurma BİTTİ** | **32/32 başarılı, 0 hata**; 45 landmark'a **45 transkript** = tam kapsama. M-O-29/30'un sebep zinciri (`--no-transcribe` ile sınıflandırıcının kanıt kaynağını kesmem) KAPANDI; kalan iş sonucu almak |
| Uygunluk yenilemesi YENİ oturuma | Koordinatör talimatı: bu oturumda yeni kapsam yok. Zincir hazır ve devir notunda komut komut yazılı |
| Merge isteği hazırlandı | Dal `feat/g0-g1-kickoff` @ `b282741`, çalışma ağacı temiz, origin ile eşit. Merge'ü koordinatör yapacak |

## 2026-07-29 (tur 28) — Kromagram akor spike'ı: lisans sorusu şimdilik GEREKSİZ
| İş | Kanıt |
|---|---|
| **8 açık akor × 5 koşul = 8/8, 0 yanlış hüküm** | E A D G C Am Em Dm; temiz · 20/10/**5 dB SNR** · telefon highpass. Yanlış hüküm sıfır en önemli sütun: öğrenci yapmadığı hatayı düzeltmez. ML yok, ağırlık yok, **lisans zinciri yok** → M-O-33'ün kurucu sorusu askıya alındı |
| Reddetmesi gerekeni reddediyor | tek nota → RED · iki notalık aralık → RED · 100 ms pencere → RED (alçak register ayrışmaz; bulanık kromagram yine de *emin görünen* kazanan üretirdi) |
| Tasarım: **tam nota frekanslarında** değerlendirme | Doğrusal FFT ızgarası onlarca Hz aralıklı, gitarın alt ucunda ayrılacak semitonlar ~5 Hz → O-019'un aynısı. Izgarayı ortadan kaldırdım; bedeli ~200 ms pencere, akorlar tutulduğu için karşılanabilir |
| **Rakip endişelendiğim yerde değilmiş** (M-O-36) | Göreli majör/minör (C↔Am) değil, her zaman **aynı kökün 7'lisi** (E→E7) — dominant-7 şablonu majör üçlünün ÜST-KÜMESİ. Drill 7'li öğretmiyor → set 8 akora daraltılınca majör marjları **1,1-2,2× arttı** (G 2,2×), minörler değişmedi. Ders: hata eksenini varsayma, ölç |
| **Bütçe 5,2× ucuzladı, mimari sonuç çıktı** (M-O-37) | 19,9 ms/akor (30 fps'in %60'ı) → pencere semiton döngüsü İÇİNDE kuruluyormuş; bir kez + Goertzel → **3,8 ms (%11)**. **Akor tanıma onset-tetiklemeli koşmalı, kare-başına değil.** ⚠️ masaüstü JIT; mobil çarpanı bilinmiyor (G8) |
| Durum değişikliği | `chord_correctness`: aspirational → **engine**. Gitar/piyano artık 9 live · 2 engine · **2** aspirational (3'tü) |
| Dürüstlük sınırı | Sentetik akorda tam intonasyon, tel gıcırtısı/ölü tel/çınlayan komşu tel YOK. **Gerçek gitarda kanıtlanmadı** — sıradaki adım birkaç gerçek kayıt (8 akor × 3 tekrar, telefon yeter) |

**Kapılar:** 61/61 paket testi (9'u akor) · linter temiz · replay 0 · profil drift yok.

## 2026-07-29 (tur 27) — 0.7.1 ile gerçek gap ölçüldü + config birim kaçağı kapandı
| İş | Kanıt |
|---|---|
| **Gerçek gap ÖLÇÜLDÜ — kurgu değer izin veren yönde çarpıtılmış** | motion_core 0.7.1: şan **0.00068** · gitar **0.00466** · piyano **0.00181** (marj 0.02). Kurgu sabit 0.04, şanın gerçeğinin **59 KATI** (gitar 9× · piyano 22×). Yani yalnız "ölçülmemiş" değil, sistematik olarak serbest bırakma yönünde. Üçü de eşiğin altında → 7 taraf-bağımlı metrik artık ÖLÇÜLMÜŞ gerekçeyle kalıcı `coached_only` |
| Savunma amaçlı tutma DOĞRU çıktı | `2d6f8eb`'de ölçüm yokken tutmuştum; ölçüm gelince aynı sonuç. Aynalanmış take de düzeldi: şan 4/18 → **0/18** (near-tie → hiçbir take çevrilmez) |
| Pilot artık TAHMİN etmiyor, SORUYOR | 0.7.1'in `gapMeasured` alanı benim "bayrak dayanağını taşımalı" önerimin uygulaması. Kendi `n>12` eşik kopyamı tutuyordum — çekirdek sınırı 18'e çıkarınca sessizce yanlış olacaktı; kaldırıldı |
| **Config birim kaçağı** (M-O-27, koordinatör denetimi yakaladı) | Motoru O-019'da süre-tabanlı yapmıştım ama üç config `sampleRate:44100 · windowSamples:4096 · onsetFrameSize:1024` mühürlemeye devam ediyordu. İkincisi **bas hayalet-onset kusurunun sebep değeriydi** — bu config'i okuyan kod kusuru geri getirirdi. ms/Hz'e çevrildi, sürüm **0.2.0-draft**, ve linter'a kalıcı kapı + 3 negatif test |
| **Kendi self-test'im yalan söylüyormuş** (M-O-28) | "16/16 ihlal yakalandı" metni ELLE yazılıydı: bir test düşse yine 16/16 derdi. 3 test ekleyince sayının değişmemesi ele verdi → `len(cases)`'ten türetildi, **19/19** |

**Kapılar:** ruleset linter temiz · self-test 19/19 · replay çıkış 0 · 52/52 ses testi.

**Sıradaki:** piyano tur-2 hasadı sürüyor (5 aday; 1 red — netlik 39<50) → sonra W1 spike'ları (lisans katalog-§0 denetimi ÖNCE).

## 2026-07-29 (tur 26) — Havuz doğrulaması + kural 7'nin kapalı kapısı (O-021)
| İş | Kanıt |
|---|---|
| Havuz durumu ÖLÇÜLDÜ | Kabul (landmark) = **şan 18 ✅ · gitar 15 ✅ · piyano 10 ❌ (2 eksik)**. Şan tur 2 zaten koşmuş (5→18); hedef ≥12 iki çalgıda tutuyor |
| **Havuz büyüdü → toleransları yeniden ölçtüm** (kendi M-O-12 kuralım) | Şan n=5→18: `trunk_tilt` 1,5°→**2,6°** (hâlâ en sıkı metrik). Kol metrikleri şanda güvenilmez kalıyor: `right_forearm` 113,7° · `left_forearm` 80,6° · dirsekler 44-48° — eğitmenler anlaşmıyor, tolerans uydurulmaz |
| ⚠️ Pilotu argümansız koşmak YANILTICI | Argümansız çağrı 43 take'i **tek havuzda** işliyor (çalgılar karışık) → `left_forearm` 58,5° gibi anlamsız sayılar. Çalgı başına koşulmalı; bu koşum şekli tuzağı kayda geçti |
| **P0 — `mirrorConfident` n>12'de UYDURULUYOR** (M-O-25) | Şan ve gitar `runnerUpGap`i **birebir 0.04000** raporluyordu — iki bağımsız veri kümesinde aynı yuvarlak sayı. Çekirdek: `n<=12` tükenmeli arama gerçek farkı ÖLÇER, üstünde fallback `mirrorMargin*2` **yazar** (`// unknown gap`) ve bu yapısı gereği marjın üstünde olduğundan **confident DAİMA true** döner. Piyano (n=10) gerçek ölçüm `0.00181` alıp doğru şekilde TUTUYOR |
| Etki geri alındı | Şan+gitarda **7 taraf-bağımlı metrik** bu kurgu değere dayanarak puanlanıyordu (gitar gerekçesi birebir "runnerUpGap 0.04 > marj 0,020") → `coached_only`ye alındı, yalnız `trunk_tilt` puanlanıyor. Kural 3 gereği quality eşikleri de kaldırıldı (kendi linter'ım yakaladı). Çekirdeğe YAZILMADI (koordinatör alanı) |
| **Kendi hedefim kapıyı kapatıyormuş** (M-O-26) | ≥12 kabul hedefi BENİM kalite kuralım; çekirdeğin tükenmeli sınırı da n≤12. Hedefi tutturan her çalgı aynı anda güvenin ölçülemez olduğu tarafa geçiyor. **Havuz büyüdükçe sistem daha emin konuşuyor, yanlış sebeple** — hedefi tutturamayan piyano tek dürüst ölçüm |
| Pilota savunma eklendi | n>12'de artık "GAP ÖLÇÜLMEDİ … kurgu değer" uyarısı basıyor ve taraf-bağımlı metrikleri TUTUYOR. Ders: yukarı akış boolean'ının değeri değil DAYANAĞI sorulur |
| Kare hızı dağılımı (M-O-23'ün poz karşılığı) | 43 dosyada **6 farklı hız** (23,976–60 fps). Landmark kareleri `t` alanı taşıyor (süre-tabanlı ✅), ama sabit-hız varsayan her mantık bu veride kayar — koordinatörün 7-repo denetimi bunu kapsıyor |

**Kapılar:** ruleset linter temiz · replay çıkış 0 · 52/52 ses testi.

**Sıradaki:** piyano tur 2 (2 kabul eksik) → sonra W1 spike'ları (lisans katalog-§0 denetimi spike'tan ÖNCE).

## 2026-07-29 (tur 25) — Ses fixture seti + iki gerçek motor kusuru (O-019)
| İş | Kanıt |
|---|---|
| **`ostinato-audiofix-1` seti ÜRETİLDİ** (M-F-56 kapsama boşluğu) | 6 fixture: temiz sürekli nota · oda gürültüsü · 5-notalık dizi · kısık çalma · **çello C2 telefon-mikrofonu** · 10 dB SNR. Değerler uydurulmadı: sinyal sentezlenir, **gerçek motordan** (YIN + OnsetDetector + gate) geçirilir, motorun ÖLÇTÜĞÜ yazılır. 2/6 negatif (`shouldJudge:false`). `fixtures/audio/` + `tools/dart_pilot/bin/make_audio_fixtures.dart` |
| **Set ilk gününde kusur buldu — çello 63 pencerenin 1'inde kullanılabiliyordu** | Sürekli çalınan C2, **39 nota atağı** olarak raporlanıyordu; kapı her birini "atak penceresi" sayıp hüküm vermeyi reddediyordu. Perde motoru KUSURSUZDU (65.41 Hz, periyodiklik 1.000) → kusur onset dedektöründeydi ve **kapıyı zehirliyordu**. Bu, linter'ın da mevcut testlerin de göremediği sınıf: iki motor arasındaki kaskad |
| Kök neden ÖLÇÜLDÜ (varsayılmadı) | Doğrusal DFT bin aralığı 23 ms pencerede 43 Hz → C2 bin 1-2 ARASINA düşüyor, sızıntı deseni her karede kayıyor. Süpürme: hayalet onset **yalnız ~147 Hz altında** (65 Hz: 44 · 98 Hz: 35 · 147 Hz ve üstü: 0). Telefon-highpass'ın etkisi YOK (44 vs 39) — ilk hipotezim yanlıştı |
| Bariz düzeltme TUZAKTI | `frame=4096` basdaki hayaletleri sıfırlıyor **ama tiz diziyi tamamen kaybediyor** (5→0): sabit *bin sayısı*, çerçeve boyunun analiz **bant genişliğini** de belirliyordu (64 bin × 10.8 Hz = 690 Hz tavan → C5'in harmonikleri analiz dışı). Çözünürlük ve bant genişliği iki AYRI düğme olmalı |
| **2. kusur, ilki susunca görünür oldu** | Her onset ~yarım pencere **erken** damgalanıyordu — STFT karesi pencerenin ORTASINI temsil eder, başını değil. İşaretli hata ölçümü: ortalama −12,8 ms (23 ms pencere) / −31,3 ms (46 ms). Sistematik sapma; üstüne kurulacak HER ritim hükmüne sessizce geçerdi |
| **3. kusur: testin kendisi yakaladı** | Süre yerine ÖRNEK cinsinden sabitlenen pencere → 44.1 kHz fixture'da tertemiz, **48 kHz'de (çoğu Android'in doğal hızı) 3 notalık ifade için 17 onset**. Çözünürlük = 1/süre. "Bende çalışıyor, cihazların yarısında bozuk" olarak sahaya çıkardı (M-O-23) |
| Düzeltme + kanıt | log-aralıklı **bantlar** + pencere **süreyle** (ms) tanımlı + merkez damga. **52/52 test yeşil** (6 kayıt bölgesi × 2 mikrofon + 4 register × zamanlama + hız-bağımsızlığı + bant-genişliği). Çello: **1/63 → 63/63 kullanılabilir pencere** |
| Çalışma zarfı ÖLÇÜLDÜ, eşikle gizlenmedi | 8 tohum × 3 SNR: 20 dB'de 0 hayalet · 10 dB'de ≤1/3sn · 5 dB'de 1-6; gerçek onset'ler üçünde de bulunuyor. Tek tohumda 0 çıkana kadar eşik oynatmak fixture'a overfit olurdu → zarf `onsetTolerance` + gerekçe alanıyla DEKLARE edildi. **Ürün sonucu: Setup Check ~10 dB SNR doğrulamalı** (M-O-24) |
| Kendi kapımı da sıkılaştırdım | İlk sürüm `judged > 0` soruyordu ve çelloyu **1/63 ile ✅ geçirdi** — tam da yakalaması gereken kusur. Artık oran-bazlı, ve yapısı tavanı düşüren fixture kendi barını GEREKÇESİYLE beyan ediyor. Oda tabanı da fixture etiketine göre seçiliyordu (döngüsel) → tek `roomFloorDb`, seviyeler ondan türetiliyor |
| **replay_check ses kanalıyla koşuyor** | Ses-kapılı fazlar ◻️ yerine gerçek hüküm alıyor: PLAY %70 çalarken / **0 sessizlikte** · SUSTAIN %100 / 0. Yeni ⚠️ sınıfı: "çalarken de sessizlikte de ateşleniyor" = ses koşulu yazılmış ama kapı görevi görmüyor (ölü fazın aynadaki hâli). Kalan ◻️ yalnız `setup_complete` (motoru yok, M-F-25 erteli) |

**Beş kapı yeşil:** 52/52 ses testi · 6/6 fixture beyanına uygun · replay çıkış 0 · fixture_check (9 live/1-4 engine/1-3 aspirational) · ruleset linter temiz.

**Sıradaki:** şan havuzu tur 2 (7 eksik) · piyano tur 2 (2 eksik) · W1 spike'ları (Basic Pitch dönüşümü, MIDI modu).

## 2026-07-29 (gece, tur 8-12) — W1 hasadı BİTTİ + mühürlü şemaya geçiş
| İş | Kanıt |
|---|---|
| **Hasat turu 1 tamamlandı** | 55 aday → 50 manifest → **30 kabul (%60)**. Gitar 15 ✅ · piyano 10 · şan 5. Hedef ≥12/çalgı: yalnız gitar tuttu. **Eşik GEVŞETİLMEDİ** (kendi acceptanceTargets kuralım) → şan+piyano 2. tura. Rapor: `app/docs/g1/w1-hasat-nihai.md` |
| **Mühürlü şema (v3.0) → doğrudan yazım** | `config/rulesets/voice@0.1.0-draft.json` mühürlü şemanın İLK config'i (M-F-37). v0.4.0 linter ilk koşumu: **çekirdek bende gerçek hata buldu** (`setup_complete` tanımsız metrik) ve benim doğrulayıcımın `flag` muafiyetinin yanlış olduğunu gösterdi → düzeltildi, 11/11 negatif test |
| **7 şema↔okuyucu ayrışması** (M-O-10) | En kritiği `verdictGates`ın okuyucuda olmayışıydı → **v0.4.1'de üçü düzeltildi** ("şema kazanır" ilk uygulaması); geri koydum, parse+validate ✅. Kalan 3 kalem M-F-44'te planlı; ayrıca "okuyucunun işi olmayan" alanları ayrı sınıfladım (M-O-11) |
| **J-028 gerçek-kare regresyonu** (M-O-08) | 9 fixture/~50k kare: ham normalize **9/9 videoda sistematik %41 oransal hata**; ⚠️ piksel-ölçekli düzeltme medyanı iyileştirip **en kötü vakayı kötüleştiriyor** (derinlik kısalması düzlem-içi ölçeklemeyle gelmez) → tüm kamera metrikleri `world`. Aile kuralına uyarı olarak girdi |
| **B4 pilotu** (M-O-09, M-O-12) | Çalgı-başına havuz: piyanoda işe yaradı, **şanda yaramadı ve bu bir ürün kararı** (şanda kolun doğru yeri yok → metrik kapsam dışı). **Havuz 11→26 olunca kendi ölçümüm çürüdü**: piyano `trunk_tilt` 2,7°→5,1° → config eşikleri düzeltildi (noiseBand 2→6, quality 8→15), metrik artık ÖRNEKLEM-DUYARLI olduğunu beyan ediyor |
| Yeni bulgu (M-O-13) | El havuzu ikinci geçişi **hiç yeni kabul üretmedi** — el-yakın çekimler hem dar kadrajlı hem düşük çözünürlüklü; "kadrajı dar ama el için değerli" varsayımım veriyle doğrulanmadı |

**Sıradaki:** şan havuzu tur 2 (7 kabul eksik; tutmazsa şan postür metrikleri V1'de kapalı) · piyano tur 2 (2 eksik) · el metrikleri için ayrı kaynak stratejisi.


## 2026-07-29 (tur 4) — J-028 makine-denetimi + triyaj hattı ÖLÇÜLDÜ
| İş | Kanıt |
|---|---|
| **J-028/M-F-30 (P0) yanıtı — kanıtla** | Ses hattımda koordinat matematiği **YOK** (grep); risk gelecekteki postür modülündeydi ve **dokümanlarımda uzay belirtilmemişti**. Şimdi: taksonomideki **20 kamera/füzyon kodu** `measurementSpace: world` + `realFrameRegression: required` taşıyor; `tools/build_taxonomy.py` reddediyor. **Negatif testle doğrulandı** (kasten `normalized_raw` → 20 ihlal + exit=1). PRD §5b + ruleset `measurementSpace` bloğu |
| Çekirdek pini **v0.2.1** | Yükseltmede **34/34 sözleşme testi yeşil kaldı** — tag pin + çalışan sözleşme testinin değeri: bozulup bozulmadığını tahmin etmedim, ölçtüm |
| **Triyaj hattı ÇALIŞTI** | Rig `--triage-profile` ile (koda dokunulmadı); profiller `config/triage/*.json` tek kaynaktan türetiliyor (loader bilinmeyen anahtarı reddediyor). **6 video koştu, 3 kabul (%50)**, 3 fixture üretildi. Rapor: `docs/g1/w1-triyaj-pilot-raporu.md` |
| **Ölçümden çıkan kararlar** | **K-T1:** piyanoda "hand-cam vs full-body" öngörüm ölçümle doğrulandı (`E8Do4oxTJ1k` üst-gövde 0.42 ile elendi — duruş için değersiz, el metrikleri için değerli) → `piano_hands`/`guitar_hands` havuz profilleri. **K-T2:** netlik eşiği gevşetilmeyecek (3 redden 2'si netlik; bulanık kaynak = sessizce gürültülü referans). **K-T3:** %50 oranla çalgı başına ~9 kabul, hedef 12 → havuz genişletilecek |
| **Kendi hatamı düzelttim** | `apXCNMckvuY` ilk koşumda Traceback verince "rig garantisinde boşluk" diye yazmıştım; **yeniden koşumda sorunsuz geçti** → çıkarımı geri aldım, rapor 3/6'ya güncellendi. Ders: tek koşumluk hatadan mimari sonuç çıkarma |

`origin/main` = `2d2ea06` (+ rapor düzeltmesi).

## 2026-07-29 (gece, limit sonrası) — ÇEKİRDEK PİN'İ ÇALIŞIR HÂLE GETİRİLDİ + W1 taksonomisi
| İş | Kanıt |
|---|---|
| **`motion_core-v0.1.0` TAG pini — dokümante değil ÇALIŞIR** | `pubspec.yaml` git+tag bağımlılığı çözüldü (`at bffbc5`); **path DEĞİL tag**: paylaşımlı ağaca path bağımlılığı o ağaç dal değiştirince sessizce anlam değiştirir (M-O-03'ü üreten kaza sınıfı) |
| **Saat sözleşmesi testi** | `test/core_contract_test.dart` — 4 test: ses pencereleri `MotionClock`'tan damgalanıyor · onset'ler aynı zaman çizgisinde · **metronom DUYULAN zamana göre yargılanınca BT dinleyicisi cezalandırılmıyor** (düzeltilmemiş grid'in gerçekten yanlış hüküm verdiği de sınanıyor) · `BeatGrid` çekirdekten tüketiliyor (yerel fork koruması). **34/34 yeşil, analyze temiz** |
| **W1 hata taksonomisi** | `config/error-taxonomy.w1.json` — **piyano 12 + gitar 10 kod**; betikli denetim: her kodun **≥2 FARKLI kanal** kaynağı var (M-F-19 kuralı makine-kontrollü). `invisible` 3 hata (pratik-yöntemi/nota-okuma) **ürün kapsamına GİRMEZ** → dürüstlük kutusu + "Neden yok?" girdisi |
| Demo havuzu | piyano 13 + gitar 13 doğru-teknik aday (triyaja hazır) |
| Merge | `origin/main` = `37eda9f` (fast-forward, dal değiştirmeden, force yok) |

**W1 hasadı TAMAMLANDI (6/6 ajan):**
- `config/error-taxonomy.w1.json` (schema v2) — **35 kavram kodu**: voice 12 (kapsamda 10) · piano 13 (11) · guitar 10 (9). **5 `invisible` kod** (larinks pozisyonu, dil kökü gerginliği, nota-okuma alışkanlığı, pratik yöntemi ×2) ürüne GİRMEZ → dürüstlük kutusu + "Neden yok?".
- `config/demo-pool.w1.json` — **55 doğru-teknik aday**; 3/3 çalgı ≥3 bağımsız eğitmen kuralını karşılıyor (12 · 13 · 19 kanal).
- `tools/build_taxonomy.py` — birleştirme + denetim betiği: kod eşlemesi tam mı · hata başına ≥2 bağımsız kanal · **haritalanmamış bulgu atlandı mı** (sessiz kayıp koruması). Hepsi ✅.
- **O-020 / M-O-05 dersi:** resume cache'ten dönmedi, ikinci koşum aynı kavramları farklı adlarla (kısmen Türkçe) üretti → **kavram kodu oturumun, ajanın değil**. Yan kazanç: iki bağımsız koşumda çıkan kavramlar yakınsama kanıtı (piyano 9/13 · guitar 9/10).
- Merge: `origin/main` = `0a3caa5`.

## 2026-07-29 (gece vardiyası) — G2 PRD + main'e MERGE + triyaj profilleri
Koordinatör paketi (M-F-22..26 + M-O-01 yanıtı M-F-23) uygulandı.

| İş | Kanıt |
|---|---|
| **O-010 KAPANDI** | M-F-23 yanıtı işlendi: ADR-001 gerçek çekirdek konumlarına hizalandı (`PhaseStateMachine` · `fixture/replay.dart` · **`MotionClock`** · `CueGate` · `LatencyCalibrationStore`); `ostinato-audiofix-1` app'te KALIR + hizalama şartları (monotonic Us · provenance alan eşlemesi · `shouldJudge:false` korunur) |
| **M-O-03 KAPANDI** | M-F-22 worktree kuralı kabul edildi: paylaşımlı ağaçta dal değiştirmeyeceğim; core'a yazmam gerekirse `~/motion-worktrees/ostinato-<dal>` |
| **G2 PRD** | `docs/PRD.md` — 5 mod + kapılar · veri modeli (`AttemptProvenance` zorunlu) · O-013'ün 6 aile-şartı maddelendi · ses hattı sözleşmesi · çalgı modülü sınırı + "keman testi" · W1 kabul kriterleri |
| **MAIN'E MERGE (M-F-24 yetkisi)** | `feat/g0-g1-kickoff` → `origin/main` **fast-forward** (dal değiştirmeden, force YOK): `cf5a9f5..35b1f9f`. Kanıt: 30/30 Dart testi + config şema doğrulamaları yeşil |
| Çekirdek pinleme | `motion_core-v0.1.0` tag'i tüketim sözleşmesi (O-019) |
| **Triyaj eşikleri** | `config/triage-thresholds.w1.json` — çalgı-başına profil; **çello %7 bulgusundan türetildi**: piyano/gitarda "hand-cam vs full-body" iki havuz ayrımı, şanda üst-gövde eşiği en sert. Rig alan adlarıyla doğrulandı; kabul hedefleri ölçüm-ÖNCESİ yazıldı (≥12 kabul/çalgı · ≥3 eğitmen · hata başına ≥2 kaynak; **altında kalırsa eşik gevşetilmez, havuz genişletilir**) |
| Platform iskeleti | **ERTELENDİ (M-F-25)** — `motion_shell` ailede bir kez, pilot JabLab |
| Hasat deposu | `~/motion-harvest/ostinato/` açıldı (M-F-26: ham hasat repoya girmez) |

W1 "common mistakes" hasadı (6-ajan fan-out: Şan/Piyano/Gitar × hata-taksonomisi + doğru-teknik adayları) koşuyor.

## 2026-07-29 — W0 BAŞLADI: IA envanteri + SES ÇEKİRDEĞİ KODU (ilk üretim kodu)
Koordinatör iş paketi (kurucu onaylı) uygulandı. **Kod kilidi fiilen açıldı — Ostinato'nun ilk üretim kodu yazıldı.**

| İş | Kanıt |
|---|---|
| CLAUDE.md M-F-19 hizası | Zaten hizalıydı (koordinatörün `ffbe1c3` commit'i); doğrulandı |
| Roadmap dalga devri | `docs/ostinato-roadmap.md §3b` — W0-W7 tablosu + W1 gerekçesi (~%87 talep, dedektörsüz) + G0-G10'a tarihsel şerh |
| **IA envanteri** | `config/instruments.v1.json` — **42 çalgı** (blueprint "~35" yaklaşıklığı; fark kayda geçti) × 7 aile × 8 modül; her çalgıda `measures`/`notMeasures` dürüstlük kutusu + `configOf` devri + uyarılar; `excluded[]` = "Neden yok?" sayfası. Şema doğrulaması betikle TEMİZ (aile/modül/rhythm_engine/dürüstlük/configOf/id) |
| **SES ÇEKİRDEĞİ (kod)** | `packages/ostinato_audio` — **30/30 test yeşil, `dart analyze` temiz.** PitchSource soyutlaması + GPL'siz YIN (native portların normatif referansı) · AudioConfidenceGate (3 durum; eşik oda-tabanına göreli) · OnsetDetector (spectral flux, enerji değil) · MetronomeAligner (medyan+yayılım+bias) · SyntheticTone (zayıf fundamental + telefon-mikrofonu highpass) |
| Çekirdek sınırı korundu | motion_core'un `BeatGrid`+`AudioLatencyProfile`'ı TÜKETİLİR; kendi saat/gecikme modülümüz YAZILMADI (00-AILE §2 + M-F-08) |

**İki gerçek bulgu — ikisi de testle yakalandı:**
- **O-017 (kod hatası, P1):** oktav-snap yalnız yuvarlanmış oktav sayısına bakıyordu → C2 beklenirken A4 "C2, 300 cent pes" diye KABUL ediliyordu (sessiz-yanlış, M-C-05 sınıfı). Kalan-oktav toleransı eklendi; regresyon testi kondu.
- **O-018 (fixture kusuru, P2):** sentetik nota sonundaki sert kesim klik üretip onset sayısını ikiye katlıyordu (4 nota → 8 onset). Dedektör değil fixture hatası (M-C-06 sınıfı); release zarfı eklendi.

Commit'ler (feat dalı, push'lu): `2a72d23` IA envanteri+roadmap · `9552529` ses çekirdeği.

## 2026-07-28/29 — M-F-19 İZDÜŞÜMÜ: B2B kapısı kaldırıldı, kuyruk W0'a geçti
- **Git çakışması yaşandı ve ONARILDI (kayıp YOK — M-O-03):** koordinatörün 3 commit'i (`e624c2a` blueprint · `ffbe1c3` D3 revizyonu · `805d6f8` W3 satırı) feat dalındaydı; ben feat'e geçip düzenleme yaparken koordinatör AYNI çalışma ağacında dalı main'e çevirip feat'i push etti → commit'im main'e düştü (`e7902b1`, her şeyi squash olarak). Onarım: 3 düzenlenen dosya feat'e taşındı → **`cded5c8` commit + push** · `main` `cf5a9f5`'e geri alındı (e7902b1 yalnız reflog'da, origin'e gitmedi). **Kök neden yapısal:** tek çalışma ağacında çok oturum (M-016/M-017 ile aynı sınıf, 3. tekrar) → aile DEFTER'ine M-O-03 + `git worktree` / tek-yazan-oturum önerisi yazıldı.
- Okundu ve işlendi: `OSTINATO-BLUEPRINT.md` (~35 çalgı, 7 dalga, modül mimarisi) · `30-URUN-BLUEPRINT-STANDARDI.md` (IA "her öğe kendi sayfası", oturum sözleşmesi, ajan düzeni) · 00-AILE-MIMARISI **D3 revize** · CLAUDE.md V0 satırı.
- **DEFTER revizyonu:** O-001 (P0→P1, kapanış yolu = W3 veri-güdümlü kapı) · O-006 (P1→P2, B2C-first; B2B lansman-sonrası fırsat) · **OK-3 → OK-3-rev** (görüşme eşikleri yürürlükten kalktı; yerine W1-W2 çekişi + yaylı-sayfa ilgi sinyali; eşik sayıları gerçek trafik bilinince ölçüm-ÖNCESİ yazılacak) · yeni **O-015** (M-F-19 izdüşümü) + **O-016** (tam kapsam: çello W3'e, W1 = Şan/Piyano/Gitar) · yeni **OK-9** (çello varlıkları imha değil DESENE çevrilir).
- **Arşiv damgası:** `KAPI-RAPORU.md` süpersede banner'ı · `teacher-channel-validation.md` + `DAVET-PAKETI.md` → 📦 ARŞİV (bloklamaz, B2B fırsatında hazır).
- **LOOP yeniden yazıldı:** "kurucu-bacağı bekleniyor" durumu kaldırıldı; kuyruk blueprint W0'dan doldu (roadmap devri → IA envanteri/config → G2 PRD → ses çekirdeği ADR'leri → W1 "common mistakes" hasadı → platform iskeleti).
- **Yatırım muhasebesi:** G1-C ses çekirdeği (monofonik pitch) W1'in **Şan** çalgısında doğrudan kullanılıyor — öne çekildi, boşa gitmedi. Çello varlıkları (pedagoji v1.1, %7 triyaj bulgusu, veri protokolü, ruleset-v0) W3 malzemesi + tüm çalgılara uygulanacak desen.

## 2026-07-26 (öğleden sonra) — M-F-13..16 UYGULANDI: kamu-video pilotu ilk adımı ÖLÇÜLDÜ
- Direktif doğrulandı (M-F-13..16 + katalog §6.3/6.4 + roadmap ⚡ `eda2ae3`) ve işlendi (DEFTER O-014). Koordinatör commit'i dalın tepesindeydi; push tamamlandı.
- **Kamera-açı triyajı:** 6-ajan toplama → 57 YouTube adayı → thumbnail kontakt-föyleriyle 57/57 elle görsel etiket → **A-aday 4 (%7) · şartlı 27 (%47) · kullanılamaz 14 · belirsiz 12**. ANA BULGU: öğretim videolarında sıkı sağ-ön-çapraz açı NADİR → ReferenceBuilder pilotunda B4 (açı-duyarlılık, metrik-başına) YAN koldan ANA kola terfi etti. Rapor+provenance: `app/docs/g1/kamera-aci-triyaji.md` + `app/docs/data/harvest/` (commit `2eea7cf`, push'lu).
- Geniş kütüphane çapaları: çello-derin 10 kanal + keman/gitar/piyano 20 kanal envanteri (provenance JSON).
- Koordinatöre **M-O-02**: hasat rig'i ön-eleme filtreleri (süre/en-boy/tek-sahne) + açı-kıtlığı bulgusunun aile-geneli etkisi sorusu.

## 2026-07-26 (sabah) — KURUCU ONAY PAKETİ + DAVET PAKETİ
- Kurucu karar paketi (koordinatör aracılığıyla; aile DEFTER M-F-01..12'de doğrulandı) işlendi: **OK-5 onaylı · G1-A onaylı · G1-B eşikleri kilitli · push yapıldı** (origin/main `cf5a9f5` + origin/feat — git'ten doğrulandı). O-010 yürütme yolu: koordinatörle DEFTER üzerinden (M-F-03).
- **Davet paketi teslim:** `app/docs/g1/DAVET-PAKETI.md` — 12 davetlik sıra (5 isimli + İSMEK/Suzuki kurumsal + 4 Superprof + 2 EN), kişiye özel mesajlar, takip mesajı, takvim (2 haftada n≥6), görüşme-günü akışı, kilitli kapı hatırlatması. Gönderim kurucuda.
- Aile kuralları (K8 skor-kalibrasyon · M-F-08 ses-gecikme modülü · M-F-09 Setup Check sert kapı · M-F-07 provenance · M-F-06 sol/sağ · M-F-05 M-O-* önek) Ostinato şartlarına çevrildi → DEFTER O-013 (G2 PRD şart listesi).
- **Loop 2. tur (aynı sabah):** çekim-günü paketi (`g1/CEKIM-GUNU-PAKETI.md`) + ReferenceBuilder pilot planı (`g3-prep/referencebuilder-pilot-plan.md`, ölçütler önce-yazıldı) + `cello@0.1.0-draft` ruleset taslağı (`g4-prep/ruleset-v0.md`) + aile DEFTER'ine **M-O-01** hizalama talebi. LOOP tekrar durdu — tüm kalanlar dış-bacak.

## 2026-07-26 — KİCKOFF: G0 tazeleme + G1/D3 kapı paketi ÜRETİLDİ (gece oturumu; üretim kodu YOK — D3 gereği)
Kurucu tetiği "Ostinato'ya başlayalım" ile açıldı. Tamamı `feat/g0-g1-kickoff` dalında yerel commit'li (gece git politikası; push sabah onaylı).

| İş | Kanıt |
|---|---|
| `audio-dsp` danışmanı yaratıldı (3 dosya) + ROSTER 67 + registry regen | bağımsız karşıt-denetim raporu: KULLANILABİLİR, 0 teknik hata; `regen-registry: agents=67` çıktısı |
| G0 canlı doğrulama (8 web-ajanı, 8/8): rakipler + lisanslar | `app/docs/research/2026-07-26-g0-canli-dogrulama.md` (+ham JSON ek). ANA SONUÇ: kamera+postür yapan mağaza-ürünü YOK (Purdue araştırma prototipi hariç → O-008); SwiftF0 MIT ✓; Yousician'da keman bile kalkmış; Tonara kapanmış |
| Çello pedagoji kütüphanesi v1 (müfredat + E-kod taksonomisi + tolerans felsefesi + boy tablosu) | `app/docs/research/pedagogy-cello-beginner.md`; movement-science-advisor ilk-geçişi KOŞUYOR (rapor bekleniyor) |
| G1-A veri toplama protokolü (çeşitlilik matrisi 60 klip + etiket şeması + rıza formları TR + çocuk rejimi) | `app/docs/g1/data-collection-protocol.md` |
| G1-B öğretmen/B2B doğrulama paketi (Mom-Test kılavuzu + tek-sayfa EN/TR + skor kartı + ölçüm-öncesi eşikler) | `app/docs/g1/teacher-channel-validation.md` |
| G1-C ses ön-ölçümü: YIN/pYIN/SwiftF0 × sentetik(120 satır)+gerçek çello(Iowa, 48 segment) — med ≤19¢, oktav ~%0, hp120 dayanıklı → **ŞARTLI GEÇTİ (OK-5)** | `app/docs/g1/tech-premeasure-report.md` + `premeasure-artifacts/` (script+JSON) |
| G1-C kamera ön-ölçümü: cihaz protokolü + ölçüm-öncesi eşikler (OK-4) | rapor §2 (ölçüm kurucu-bacağı, ~30-45dk) |
| URMP izin maili taslağı (muhatap düzeltildi: Zhiyao Duan) | `app/docs/g1/urmp-permission-email.md` |
| DEFTER: O-002..O-008 işlendi, O-003 KAPANDI, kararlar OK-1..OK-7 | `workspace/DEFTER.md` |

**Loop iterasyonları (aynı gece, devam):**
- Ses fixture kütüphanesi TASARIMI → `app/docs/g3-prep/audio-fixture-library-design.md` (şema + 4 katman/40 fixture + negatif-fixture sınıfı + CI sözleşmesi) — commit `f4a1cea`.
- ADR-001 TASLAK (çekirdek↔çello sınır çizgisi, "keman testi" dahil) + kurucu tek-sayfa `docs/g1/KAPI-RAPORU.md` — commit `b3bbb6f`.
- **M-017 tespiti işlendi (O-010):** motion-core eşzamanlı-üretim çakışması (aile P0) — Ostinato core'a dokunmadı; ADR-001'e koordinasyon şerhi kondu; kapı raporu kurucu listesine eklendi.
- TR çello pedagoji taraması TAMAMLANDI → `app/docs/research/pedagogy-tr-kaynaklar.md` (İSMEK kademeli müfredat + Suzuki TR derneği + TR terminoloji sözlüğü + G1-B için 5 somut aday [Ebru Tezcan Ketenci · Nihan Demirkapı · Suzuki Derneği · Bora Erdoğan · İSMEK eğitmeni] + fiyat gerçekliği [~620 TL/saat ders; kurs ~4.500-4.800 TL/ay] + O-011 dürüstlük riski).
- **LOOP DURDU:** kuyrukta yalnız kurucu-bacağı/kapı-sonrası iş kaldı (LOOP.md §🔚).

**Bekleyen kurucu (sabah listesi):**
1. OK-5 şartlı-geçti retrospektif onayı (G1-C ses bacağı).
2. G1-B eşik önerisi onayı (§4.2) → sonra 8-12 öğretmen daveti + görüşmeler.
3. G1-A protokol onayı → pilot çekim (~yarım gün).
4. Pose+hand cihaz benchmark'ı (protokol hazır, ~30-45dk, iPhone+Android).
5. URMP maili gönderimi (taslak hazır).
6. Git: `feat/g0-g1-kickoff` push + main'deki roadmap commit'inin (cf5a9f5) push'u.
7. (Eski) Domain kararı: getostinato.app — M-006.

## 2026-07-25 — Venture AÇILDI (ayrı repo; kod YOK)
- Kurucu kararıyla monorepo'dan ayrı repoya kuruldu (`kocakkmustafa/ostinato`); plan + kilitli CLAUDE.md + defterler hazır; bundle-id `com.yulalab.ostinato` rezerve.
