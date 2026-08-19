# Ostinato — W1 ses "golden fixture" kaynak araştırması (pitch/onset/chord/MIDI)

**Tarih:** 2026-08-18 · **Statü:** ARAŞTIRMA (PREP hattı, üretim-hattı yeni rejim) · **Yazar bağlamı:** Motion Orchestration'a bağlı OSTINATO proje oturumu, kod DOKUNULMADI.
**Tetik:** `23-OSTINATO-MASTER-ROADMAP.md` Task `OST-P0-003` ("Pitch/onset/chord/MIDI model gates" — Step 1: "Supported ranges, SNR, chords, onset ve MIDI golden fixtures yaz") + bu oturumun `library.json` envanterinde bulduğu somut kilit (bkz. `workspace/DEFTER.md` O-171): 6 ders ("guitar.open_chords", "guitar.strum_timing", "guitar.chords_beyond_eight", "voice.sustained_note", "voice.vibrato", "piano.five_finger") açıkça "gerçek kayıtta doğrulanmadı" gerekçesiyle kilitli.
**Bağlayıcı önceki plan:** `docs/g3-prep/audio-fixture-library-design.md` (2026-07-26) — 4 katman tanımlı: **L1 sentetik** (24 hedef) · **L2 real-clean** (Iowa MIS, 12 hedef) · **L3 negatif** (4+) · **L4 real-target** (kendi çekimlerimiz, pilot→+8). Bu araştırma o planı DEĞİŞTİRMİYOR, L2/L4'ün "gerçek kaynak" sorusuna kanıtlı bir cevap veriyor.

---

## 1. Mevcut durum — ölçüldü, varsayılmadı

`fixtures/audio/` altındaki **8 fixture'ın (AF-001…AF-008) 8'i de `kind: synthetic`, `recordingMeta.source: generated`** (her birinin JSON'u tek tek okundu). `AF-005-cello-c2-**phone-mic**` ismi gerçek kayıt izlenimi veriyor ama kendi `$note` alanı açık: *"Synthetic, so the ground truth is exact. Real-recording fixtures are a separate track (the G1-A protocol)."* Yani **bugün bu depoda pitch/onset/chord/MIDI motorunu gerçek bir enstrümanda doğrulayan TEK BİR fixture yok** — tasarım belgesinin L2/L4 katmanları hiç doldurulmamış. `library.json`'daki 6 kilitli dersin `lockedReason`ı bunu bağımsız olarak doğruluyor (hepsi "yalnız sentetik/başka çalgıda kanıtlı" diyor).

## 2. Aday kaynaklar — lisans TEK TEK web'den doğrulandı (varsayılmadı)

| Kaynak | Kapsam | Lisans (kaynağından doğrulandı) | Ticari kullanım | Ostinato'ya uygunluk |
|---|---|---|---|---|
| **GuitarSet** (NYU MARL + QMUL) | 360 × ~30sn akustik gitar, 6 çalgıcı, hexafonik pickup → **akor + perde + fret + beat + key** zaman-hizalı | **CC BY 4.0** | ✅ SERBEST (atıfla) | **Guitar için EN GÜÇLÜ aday** — `guitar.open_chords` + `guitar.chords_beyond_eight`'in "gerçek kayıtta hiç ölçülmedi" boşluğunu doğrudan kapatabilir. Zenodo'dan indirilebilir (8.2GB, JAMS format) |
| **University of Iowa Musical Instrument Samples (MIS)** | Piyano (Steinway) + yaylı + nefesli/pirinç + vurmalı — izole nota/gam | **"without restriction"** (kurumun kendi sayfası) | ✅ SERBEST | Tasarım belgesinin ZATEN seçtiği L2 kaynağı — doğrulandı, sapma yok. **Gitar YOK, vokal YOK** — yalnız piyano (+ ileride W3/W4/W5 yaylı/nefesli/vurmalı) için kullanılabilir |
| **URMP** (Rochester AIR Lab) | 44 klasik oda-müziği parçası (10'u çello), nota-düzeyi F0/onset ground-truth | Resmî sayfada bağlayıcı lisans YOK (yalnız atıf ricası+form); **Dryad aynası (DOI 10.5061/dryad.ng3r749) CC0-1.0 beyan ediyor** — çelişkili ama OLUMLU sinyal | ⚠️ Muhtemelen SERBEST (Dryad+CC0 politikası tutarlı) ama TEYİTSİZ | **DÜZELTME (bu araştırmanın ilk turunda "belirsiz" yazmıştım — deponun kendi 2026-07-26 taramasını `docs/research/2026-07-26-g0-canli-dogrulama.md` + `docs/g1/urmp-permission-email.md`de bulunca netleşti, bkz. DEFTER O-173):** izin maili taslağı ZATEN yazılmış (muhatap `zhiyao.duan@rochester.edu`, "yalnız dahili doğrulama/benchmark, model eğitimi YOK" diye net kapsamlı) — **gönderildiği/yanıtlandığı DEFTER'de İZİ YOK, muhtemelen hâlâ kurucu kuyruğunda** |
| **MAESTRO** (Google Magenta) | 200 saat, piyano MIDI+audio, ~3ms hizalama | **CC BY-NC-SA 4.0** | ⛔ TİCARİ DEĞİL | `piano.five_finger`'ın zamanlama-yanlılığı sorununa TEKNİK OLARAK mükemmel uyar ama lisans commercial ship'i kapatıyor — yalnız izin alınırsa |
| **MedleyDB** (NYU MARL) | Çoklu-enstrüman, melodi F0 | **CC BY-NC-SA 3.0** | ⛔ TİCARİ DEĞİL | Aynı sebep |
| **IDMT-SMT-Guitar / -Audio-Effects / -Chords** (Fraunhofer) | Gitar nota/akor/efekt, onset etiketli | **CC BY-NC-ND 4.0** | ⛔ TİCARİ DEĞİL + türetilemez | En restriktif — GuitarSet varken zaten gerek yok |
| **NUS-48E** | 48 şarkı, söylenmiş+konuşulmuş, fonem-hizalı | Açık NUS akademik/ticari-olmayan lisans (kurumun kendi PDF'i) | ⛔ TİCARİ DEĞİL | Vokal için — kapalı |
| **MIR-1K** | 1000 Çince pop klip, 10ms perde etiketli | Sayfasında AÇIK lisans metni YOK (mirlab.org) | ⚠️ BELİRSİZ, muhtemelen akademik | Vokal için — varsayılmadı, doğrulanmadı, kullanılmadan ÖNCE doğrudan sorulmalı |

**Örüntü (6 kaynaktan 4'ü aynı yöne işaret ediyor):** Akademik MIR literatüründeki en zengin gerçek-ses veri setlerinin (MAESTRO, MedleyDB, IDMT-SMT ailesi, NUS-48E) **çoğu NC (ticari-olmayan) lisanslı**. Bu, projenin kendi `OK-8` kararıyla (dedektör eğitim/doğrulama verisi kendi/rızalı çekimde kalır, kamu-video kareleriyle ship edilen dedektör eğitilmez) ZATEN aynı sonuca varmış olmasıyla TUTARLI — golden-fixture sorusu da muhtemelen aynı cevaba çıkıyor.

## 3. Öneri — iki parçalı, kurucu kararına muhtaç OLMAYAN kısım net ayrıldı

**A) Ship-engelleyen 4 dersin en ucuz gerçek yolu: KENDİ KAYDIMIZ (lisans riski SIFIR).** `guitar.open_chords`, `guitar.chords_beyond_eight`, `voice.sustained_note`, `piano.five_finger` — dördünün de `promotionPath.unblockedBy` metni zaten "bir gerçek kayıt" diyor, "lisanslı bir veri seti" DEMİYOR. Tasarım belgesinin L4 katmanı ("kendi çekimlerimiz, rıza-temiz") + `OK-8` emsali bunu zaten öngörmüş. Roadmap §9 "Kendi üretilen exercise audio ve metronom varsayılan" ifadesiyle de birebir örtüşüyor. Bu, kurucu/hukuk kapısı GEREKTİRMEZ (dış lisans yok) — yalnız bir enstrüman çalan/şarkı söyleyen bir kişi + telefon/mikrofon + bilinen nota/akor listesi ister.

**B) Geniş regresyon/çeşitlilik için (ship-blocking DEĞİL, kalite-artırıcı):**
- **Guitar → GuitarSet** (CC BY 4.0, kullan-atıfla) — 6 çalgıcı × 5 stil çeşitliliği, `guitar.strum_timing`'in "teacher data" ihtiyacına da (beat-hizalı) katkı verebilir.
- **Piano → Iowa MIS** (serbest) — izole nota/gam katmanı, `AF-008` tarzı motor-doğruluğu testleri için.
- **URMP** — kurucunun 07-26'da başlattığı izin talebinin SONUCU takip edilmeli (bu turda ölçülemedi — mail durumu bu oturumdan görünmüyor).
- **Vokal için commercial-safe gerçek-şarkı veri seti BULUNAMADI** (NUS-48E kapalı, MIR-1K belirsiz) — bu, (A)'daki kendi-kayıt yolunun vokal için tek net seçenek olduğunu GÜÇLENDİRİYOR, alternatif aranmadı diye değil.

## 4. Bu araştırmanın ÇÖZMEDİĞİ, adıyla bırakılan kısım

- **`guitar.strum_timing`** yalnız fixture ile açılmıyor — `lockedReason`ın kendi metni iki ayrı eksik sayıyor: (i) altı-yakın-eşzamanlı-atağı-tek-akor-olayına-eşleme adımı (kod, hiç yazılmamış) VE (ii) öğretmen zaman-toleransı verisi (pedagoji, ayrı iş). Golden fixture yalnız (ii)'ye kısmen yardım eder.
- **`voice.vibrato`** ve **`piano.shoulder_tension`/`arms`×3** ses-fixture sorunu DEĞİL, öğretmen-uzlaşı/referans sorunu — bu araştırmanın kapsamı dışında (§ pedagojik uzman turu, `MANUAL-OSTINATO-RIGHTS-20260818`).
- **Lisans nihai onayı KURUCU/HUKUK KAPISIDIR** (protokol §6 R3: "Hukuk/sözleşme/marka") — bu belge yalnız araştırma, hiçbir veri seti indirilmedi/kullanılmadı.
- **W2–W7** (17 enstrüman daha) bu turda taranmadı — Iowa MIS'in yaylı/nefesli/vurmalı kapsamı W3–W5 için doğrudan yeniden kullanılabilir, ayrı bir tur ister.

## Kaynaklar

- [GuitarSet | Zenodo](https://zenodo.org/records/3371780)
- [GuitarSet: A Dataset for Guitar Transcription (ISMIR 2018)](https://ismir2018.ircam.fr/doc/pdfs/188_Paper.pdf)
- [University of Iowa Electronic Music Studios](https://theremin.music.uiowa.edu/)
- [URMP dataset documentation (Rochester AIR Lab)](https://labsites.rochester.edu/air/projects/URMP/URMP_doc.pdf)
- [The MAESTRO Dataset (Magenta)](https://magenta.withgoogle.com/datasets/maestro)
- [MedleyDB (NYU MARL)](https://steinhardt.nyu.edu/marl/research/resources/medleydb)
- [IDMT-SMT-Guitar (Fraunhofer IDMT)](https://www.idmt.fraunhofer.de/en/publications/datasets/guitar.html)
- [IDMT-SMT-Audio-Effects (Fraunhofer IDMT)](https://www.idmt.fraunhofer.de/en/publications/datasets/audio_effects.html)
- [NUS Sung and Spoken Lyrics Corpus (NUS-48E)](https://smcnus.comp.nus.edu.sg/archive/pdf/2012-2013/2013_05-Pub-NUS-48E.pdf)
- [MIR-1K dataset (MIR Lab)](http://mirlab.org/dataset/public/MIR-1K.rar)
- [Bach10 Dataset (Duan & Pardo)](https://www.semanticscholar.org/paper/Bach-10-Dataset-A-Versatile-Polyphonic-Music-Duan-Pardo/838ed7354429d9f35b100750ed74353f62547d79)
