# Ostinato v1 — Ders format sözleşmesi

**Tarih:** 2026-10-31 · **Durum:** taslak (kurucu ve müzik öğretmeni incelemesi bekliyor)
**Kapsam:** v1'deki 690 dersin her biri bu sözleşmeye uyar. Ders listeleri `10-gitar.md`, `20-ses.md`, `30-piyano.md`, `40-kulak-muzisyenlik.md` dosyalarında.

Bu belge ders **gövde metni** içermez. Yalnızca her dersin hangi alanları taşıyacağını, ölçümün nasıl tanımlanacağını ve varsayılan değerleri sabitler. Gövde metinleri sonraki turda bu alanlara göre yazılır.

---

## 1. Ders birimi

Bir Ostinato dersi şu sırayla akar:

1. **Anlatım** (2–5 dk): metin, çizim, şema. Kısa ve tek hedefe bağlı.
2. **Referans dinleme** (≤1 dk): uygulamanın sentezlediği örnek çalış/söyleyiş. Önce hedef tempoda, sonra yavaş.
3. **Ölçülen pratik** (5–15 dk): ekranda kayan nota/tab/porte, metronom, döngü, tempo düşürme. Mikrofon her beklenen olay için üç sonuçtan birini verir (§5).
4. **Özet ve sonraki adım** (≤1 dk): ne geçti, ne tekrar edilecek, bir sonraki ders.

Süre hedefi: S1–S2 dersleri 10–15 dk yeni içerik + 1–2 pratik seti; S3–S4 dersleri 15–20 dk + 2–3 pratik seti. Bir dersin "tamamlanması" tek oturumda olmak zorunda değildir.

---

## 2. Alanlar

Her ders aşağıdaki alanları taşır. "Liste" sütunu, alanın kurs listelerinde (tek satır) görünüp görünmediğini gösterir; görünmeyen alanlar ders kartında yazılır ya da varsayılandan gelir.

| # | Alan | Zorunlu | Liste | Açıklama | Mevcut JSON karşılığı |
|---|---|---|---|---|---|
| 1 | `id` | Evet | Evet | `<kurs>-s<seviye>-m<modül>-<sıra>`. Kurs kodları: `gtr`, `voc`, `pno`, `ear`. Seviye testi: `<kurs>-s<n>-test`. Gitar S4 kolları: `m19a` / `m19b`, testleri `test-a` / `test-b`. Kimlik bir kez yayımlanınca değişmez | `id` |
| 2 | `title` | Evet | Evet | EN + TR. 14 dile çeviri sonra katalog üzerinden | `title.en/tr` |
| 3 | `goal` (hedef) | Evet | Evet | Tek cümle, gözlemlenebilir fiil ("çalar", "söyler", "ayırt eder"). "Anlar/bilir" yazılmaz | `objective` |
| 4 | `explanationOutline` | Evet | Hayır | 3–6 maddelik anlatım taslağı. Her madde bir kavram ya da bir hareket. Toplam ≤400 kelime (TR) | `teachingSteps` |
| 5 | `referenceAudio` | Evet | Kısa kod | Sentez gereksinimi (§7) | `mediaBrief` (kısmen) |
| 6 | `measuredPractice` | Evet* | Evet | Beklenen dizi + tempo (açılış/hedef) + geçiş ölçütü (§6). *Yalnız D/Ö/K dersleri ekran içi görev taşır | `practice` + `learningLab.masteryCriteria` |
| 7 | `measurement` | Evet | Evet | Ölçüm türü kodu (§3) | `measurementMode` |
| 8 | `engineSteps` | Evet | Evet | Gereken motor adımları (§4), örn. `A2+A3` | yeni |
| 9 | `fallback` | Evet | Kodla | Motor adımı gecikirse ne olur (§4.2). `M!` → bekletilir; `M` → Ö ile gönderilebilir | yeni |
| 10 | `safety` | Evet | Kısa kod | Güvenlik / ses sağlığı notu (§8). Kurs varsayılanı her zaman geçerli; ek kod yazılır | `stopSignal`, `mediaBrief.safety` |
| 11 | `prerequisites` | Evet | Hayır | Varsayılan kural §9; istisnalar ders kartında | `prerequisiteIds` |
| 12 | `selfCheck` | Ö dersinde zorunlu | Hayır | 3–5 maddelik kontrol listesi. Kayıt dinleme **yok** | `selfCheck` |
| 13 | `commonErrors` | Evet | Hayır | 1–3 tipik hata + düzeltme önerisi; ölçüm sonucuna bağlanır ("farklı nota: çoğunlukla bir perde yukarı") | `commonError` |
| 14 | `adaptation` | Evet | Hayır | Kolaylaştırma: yavaş tempo, kısa döngü, alternatif parmak/akor/oktav | `adaptation` |
| 15 | `repertoire` | Varsa | Hayır | Kamu malı eser: besteci, yaşam yılları, kaynak baskı, lisans notu (`60-kamu-mali-repertuvar.md`) | `sourceIds` |
| 16 | `legacy` | Varsa | Evet | Mevcut dersle ilişki: `R:` yeniden kullanıldı, `V:` revize, (emekliler `80-mevcut-ders-eslemesi.md`) | yeni |
| 17 | `minutes` | Evet | Hayır | Tahmini süre (anlatım + bir pratik seti) | `minutes` |

**Not:** "Liste" sütununda "Evet" olan alanlar kurs dosyalarında tek satırda yazılır. Satırın sütunları: `id · Başlık (EN / TR) · Hedef · Ölçülen pratik · Ölçüm · Motor · Ref/Güv · Mevcut`.

---

## 3. Ölçüm türleri

| Kod | Ad | Ne demek | Geri bildirim |
|---|---|---|---|
| **M** | Mikrofon | Telefon mikrofonuyla beklenen olay doğrulaması (nota, akor, onset, cent, göreli dB). Motor adımı gecikirse ders **Ö ile gönderilebilir** | Üç sonuç (§5) |
| **M!** | Mikrofon, zorunlu | Dersin değeri ölçümün kendisi (akort, perde eşleştirme, modül geçişi, seviye testi). Motor hazır değilse ders **bekletilir** ya da kilitlemeyen "deneme" olarak gösterilir | Üç sonuç |
| **M~** | Mikrofon, deneysel | Piyanoda aynı anda birden çok yeni nota (blok akor, iki el birlikte). Sonuç gösterilir ama **ilerlemeyi kilitlemez**; MIDI varsa MIDI esas alınır | Üç sonuç + "deneysel" etiketi |
| **MIDI** | MIDI | USB/BLE MIDI klavyeden kesin nota ve zaman. Piyanoda her ders için isteğe bağlı eşdeğer yol; M~ derslerinde güvenilir yol | Üç sonuç (duyamadım yerine "nota gelmedi") |
| **K** | Kamera | Yalnız S1 duruş/el konumu. Cihazda çalışır, kare saklanmaz, **puan vermez**, yalnız uyarır. Kamera yoksa Ö kontrol listesi | Uyarı / "görüntü yetersiz" |
| **Ö** | Öz-kontrol | Kontrol listesi, referans sesle karşılaştırma, ayna, beden duyumu. **Öğrenci kaydı alınmaz, dinletilmez** | Kullanıcı işaretler; ilerleme "kendi beyanı" diye etiketlenir |
| **D** | Dokunma/ekran yanıtı | Ekranda seçmeli soru, nota adı bulma, ritim dikte (dokunarak yazma). Ses motoru gerektirmez, nesnel puanlanır | Doğru / yanlış |

**D kodu sözleşmeye eklendi.** Brifte dört tür (M/K/Ö/MIDI) var. Ancak kulak eğitimi ve teori derslerindeki seçmeli sorular ne öz-kontroldür ne mikrofondur; nesnel puanlanır ve motor gerektirmez. Bunları Ö'ye katmak, motor gecikmesinde "neyin gerçekten ölçüldüğü" sayımını bozardı.

Bir ders birden fazla tür taşıyabilir (`D+M`, `M~ / MIDI`). Listede **baskın** tür önce yazılır.

---

## 4. Motor adımları

Kodlar, ürün önerisi §3'teki yol haritası numaralarıyla aynıdır. Motor işi `feat/precise-tuner` dalında başka bir ajan tarafından yürütülüyor; bu belge yalnız **dersin hangi adıma ihtiyaç duyduğunu** sabitler.

| Kod | Adım | Derse sağladığı | Kabul çıtası (öneri, motor tarafı) |
|---|---|---|---|
| **A0** | Motor yok | Ekran, D soruları, sentez çalma, metronom klik | — |
| (A-alt) | Ölçüm altyapısı (yol haritası adım 0) | Kayıt modu, gürültü tabanı, hoparlör→mikrofon gecikmesi. **Tüm M dersleri için ön koşul**, ayrıca sayılmaz | Gecikme tekrarlanabilirliği ±1 ms |
| **A1** | Hassas akort | Gitar akort aleti (cent), akort kapısı, alternatif akort, piyano sapma ölçümü | Medyan ≤1 c, p95 ≤3 c |
| **A2** | Tek nota doğrulayıcı (beklenen nota) | Gitar tek nota, üç sonuç, legato/çift ses değil | Doğruya "yanlış" ≤%3; temizde "duyamadım" ≤%10 |
| **A3** | Ritim | Onset, metronom hizalama, gecikme kalibrasyonu, swing oranı, **göreli dinamik (dB)**, el çırpma | Sistematik sapma ≤10 ms |
| **A4** | Gitar akor | Beklenen akorun tel tel kontrolü, eksik tel, çift ses/power chord | Doğruya "yanlış" ≤%5; eksik teli bulma ≥%80 |
| **A5** | Ses perdesi | f0 izleme, nota başına cent, tutma kararlılığı, kontur, vibrato; **gitarda bend/vibrato** perde izi de buradan | Medyan ≤5 c |
| **A6** | Piyano | Akustik piyanoda beklenen tek nota (aynı anda tek yeni nota), MIDI girişi | Doğruya "yanlış" ≤%5 |
| **A6p** | Piyano çok sesli | Blok akor, iki el aynı anda. Deneysel (M~), MIDI ile kesin | — (deneysel) |
| **A7** | Kamera kurulum kontrolü | S1 duruş, el konumu. Ölçüm türü **K** | Yanlış uyarı ≤%10 |

**Göreli dinamik neden A3'te?** Mutlak dB SPL puanı verilmeyecek (teknoloji raporu §4.6). Göreli gürlük, onset ile aynı enerji zarfından hesaplanır; ayrı bir model gerektirmez.

**Gitar bend/vibrato neden A5?** İkisi de sürekli perde izi ister; nota kararı (A2) yetmez. A5'in f0 izleyicisi çalgıdan bağımsız kurulursa gitar da kullanır.

### 4.1 Bağımlılık yazımı

- Satırda gereken **tüm** adımlar yazılır: `A2+A3` = beklenen nota + zamanlama.
- Dersi açan adım, listedeki **en geç** adımdır (sıra: A1 → A2 → A3 → A4 → A5 → A6; A7 paralel).
- A0 yalnız başına yazılırsa ders motor beklemez.

### 4.2 Yedek davranış (motor gecikirse)

| Ölçüm | Motor hazır değilse |
|---|---|
| `M` | Ders **Ö** olarak gönderilir: referans sesle karşılaştır + kontrol listesi. Ekran "Bu derste mikrofon geri bildirimi yakında" der. İlerleme "kendi beyanı" olarak işaretlenir; motor gelince ders "ölçümle tekrar et" rozeti alır |
| `M!` | Ders **bekletilir**. Seviye testinde bileşen Ö ile yapılabilir ama seviye **"ölçülmedi"** etiketiyle açılır; yerleştirme testi o bileşeni atlar |
| `M~` | Zaten kilitlemez. Motor yoksa Ö + (varsa) MIDI |
| `K` | Ö kontrol listesi (oturuş, açı, ayak, el) |
| A1 | Akort dersleri bugünkü ±20/30 c "akortlu mu" kapısıyla gönderilebilir; ±5 c hedefi "yakında" diye işaretlenir |

---

## 5. Üç sonuç semantiği

Her beklenen olay (nota, akor, vuruş) için mikrofon şu üç sonuçtan birini verir:

| Sonuç | Anlam | Puanda |
|---|---|---|
| **Doğru** | Beklenen olay, beklenen pencerede duyuldu (perde + zaman) | Pay ve paydaya girer |
| **Farklı nota** | Pencerede güvenle başka bir perde/akor duyuldu. Mümkünse yön ve yaklaşık fark gösterilir ("bir yarım ses yüksek", "5. tel duyulmuyor") | Paydaya girer |
| **Duyamadım** | Karar verecek kadar net sinyal yok (sessizlik, gürültü, palm mute, aynı perdede hızlı tekrar, amfisiz elektro) | **Paya da paydaya da girmez** |

**Kurallar:**
1. Bir pratik setinde "duyamadım" oranı **>%20** ise set **geçersiz** sayılır. Geçti/kaldı verilmez; "ortamı kontrol et" ekranı açılır (mikrofon mesafesi, gürültü, kulaklık, akort kapısı).
2. Akort kapısı: telli çalgılarda oturum başında akort ±30 c dışındaysa nota kararı verilmez, önce akort istenir.
3. Zamanlama ayrı raporlanır: nota doğru ama geç/erken ise "doğru, geç" denir. Geçiş ölçütü ikisini ayrı ister (§6).
4. "Yanlış" kelimesi kullanılmaz; ekran metni "farklı nota"dır.
5. Sesli eşlik ya da referans hoparlörden çalarken ölçüm yapılan derslerde kulaklık önerilir; eşlik sızıntısı maskelenir (klik anlarında ±15 ms onset maskesi).

---

## 6. Ölçülen pratik ve geçiş ölçütü

### 6.1 Yazım

Kurs listelerinde ölçülen pratik şu kalıpla yazılır:

`<beklenen dizi/görev> · ♩=<açılış>→<hedef> · <özel ölçüt varsa>`

- Notalar bilimsel perde adıyla (C4 = orta Do). Gitar notası **sesli perdeyle** yazılır (gitar portede bir oktav yüksek yazılır; doğrulayıcı sesli perdeyi kullanır).
- Tempo tek sayıysa açılış = hedef. "serbest" = tempo yok, yalnız nota/perde.
- Özel ölçüt yazılmamışsa §6.2'deki **seviye varsayılanı** geçerlidir.
- Ses kursunda notalar **kişisel tona taşınır**: dizi derece/solfej olarak yazılır (`1-2-3-2-1`), uygulama kullanıcının rahat menziline göre başlangıç perdesini seçer.

### 6.2 Seviye varsayılanları (öneri; müzik öğretmeni onayı bekliyor)

| Ölçüt | S1 | S2 | S3 | S4 |
|---|---|---|---|---|
| Nota doğruluğu (A2/A6), karar verilen notalar içinde | ≥%80 | ≥%85 | ≥%85 | ≥%90 |
| Akor doğruluğu (A4): tüm beklenen teller duyulan akor oranı | ≥%75 | ≥%80 | ≥%85 | ≥%85 |
| Zamanlama (A3): "zamanında" penceresi | ±90 ms | ±75 ms | ±60 ms | ±50 ms |
| Zamanlama: penceredeki onset oranı | ≥%75 | ≥%80 | ≥%80 | ≥%85 |
| Ses perdesi (A5): nota medyan sapması | ≤50 c | ≤40 c | ≤35 c | ≤30 c |
| Ses perdesi: ölçütü sağlayan nota oranı | ≥%75 | ≥%80 | ≥%80 | ≥%85 |
| Tutma kararlılığı (A5): perde IQR | ≤40 c | ≤35 c | ≤30 c | ≤25 c |
| Göreli dinamik (A3): p/f farkı | ≥4 dB | ≥5 dB | ≥6 dB | ≥6 dB |
| D soruları | ≥%80 | ≥%80 | ≥%85 | ≥%85 |

**Gerekçe ve sınırlar:**
- Zamanlama pencereleri, ölçüm hata payı (≈15–25 ms, teknoloji raporu §4.4) ile pedagojik tolerans (±50–100 ms) arasında seçildi.
- Vokal ataklar yavaş olduğundan ses kursunda zamanlama penceresi **+30 ms** genişletilir.
- Cent eşikleri literatürle uyumlu: amatör şarkıcılarda medyan nota hatası ~19 c; ≤25 c "iyi", >50 c "farklı nota".
- Hepsi `expertPending`. İlk kullanıcı kohortunda geçme oranları ölçülüp ayarlanır.

### 6.3 Tempo kuralları

- **Açılış temposu** sonraki dersi açar. **Hedef tempo** dersi "tamamlandı" yapar ve beceri haritasına puan yazar.
- Tempo merdiveni: açılıştan hedefe +5 bpm adımlar; her adımda varsayılan ölçüt.
- Tempo düşürme her zaman serbesttir; açılışın altındaki tempoda geçiş "pratik" sayılır, kilit açmaz.
- `M!` dersleri (modül geçişleri, seviye testleri) **hedef tempoda** geçilir.

### 6.4 Modül geçişi

Her modülün son dersi bir **geçiş egzersizidir** (`M!`). Modülün becerilerini tek bir özgün ya da kamu malı parçada birleştirir. Bir sonraki modülün ilk dersi geçiş egzersizi geçilince açılır. Modül içindeki diğer dersler sırayla önerilir ama kilitlenmez.

---

## 7. Referans ses

**İlke:** Bütün referans sesler cihazda ya da derleme sırasında **sentezlenir**. Telifli kayıt, örneklenmiş ticari kütüphane ve öğrenci kaydı kullanılmaz.

| Kod | Ne | Kullanım |
|---|---|---|
| `S` | Sentez örnek çalış: beklenen dizinin hedef ve yavaş tempoda çalınışı (gitar: tel modeli sentezi; piyano: piyano sentezi; ses: ünlü-formantlı vokal sentez ya da yumuşak sinüs, kullanıcı seçer) | Tüm M dersleri (varsayılan) |
| `SE` | Sentez + eşlik (bas/akor/davul döngüsü). Kulaklık önerilir | Strum, doğaçlama, şarkı, armoni |
| `DR` | Dron (tonik ya da tonik+5'li) | Ses perdesi, aralık, armoni |
| `KL` | Yalnız metronom klik | Ritim okuma, el çırpma |
| `—` | Ses yok | D ve Ö dersleri |

**Kurallar:**
- Ses kursunda referans, kullanıcının rahat menzilinden üretilir. Kadın/erkek oktav farkı için **oktav katlanmış karşılaştırma** yapılır; ekranda "kendi oktavında söyle" yazar.
- Gitar referansı sesli perdeyle üretilir (porte yazımı bir oktav yüksek).
- Kapolu derslerde referans **sesli tona** göre üretilir, tab kapoya göre gösterilir.
- Her referans "yavaş" (hedefin %60–70'i) ve "hedef" sürümüyle gelir. Döngü ve tempo değiştirme sentezi yeniden üretir; zaman germe yok.
- Kurs listelerinde `Ref/Güv` sütununda yalnız varsayılandan farklı olanlar yazılır. Boş/`S` = varsayılan.

---

## 8. Güvenlik ve ses sağlığı

Her kursun **varsayılan** güvenlik notu her derste geçerlidir. Ek kodlar `Ref/Güv` sütununda yazılır. Tıbbi tanı, tedavi, doz ya da ses tipi sınıflandırması **yapılmaz**.

| Kod | Kapsam | Not (ders kartına kısaltılarak girer) |
|---|---|---|
| **Ç** | Tüm kurslar (varsayılan) | Kulaklıkta ses düzeyini düşük tut. Ağrı, uyuşma, baş dönmesi olursa dur. Uzun oturum yerine kısa ve sık çalış |
| **G1** | Gitar (varsayılan) | Parmak ucu hassasiyeti normaldir, keskin ağrı değildir. 20–30 dk'da bir mola. Sıkmadan bas |
| **G2** | Barre, esneme, hız, dayanıklılık | Başparmak ve bilekte gerilim artarsa tempoyu düşür ya da kısmi barre/alternatif şekil kullan. Tekrar sayısı sınırlı |
| **G3** | Elektro / amfi | Amfi ve kulaklık amfisi düşük seviyede. Mikrofon kalibrasyon testi geçilmeden ölçüm yok |
| **V1** | Ses (varsayılan) | Ağrı, yanma, kısıklık, baş dönmesi ya da artan zorlanma olursa dur. Hasta, kısık ya da yorgunken söyleme. Nefes tutma yok. Sorun sürerse uygun bir uzmana başvur; uygulama değerlendirme yapmaz |
| **V2** | Menzil, register geçişi, yüksek/alçak notalar | Yalnız **rahat** menzilde çalış; hedef nota rahat değilse oktav değiştir ya da atla. Menzil "genişletme" zorlama değildir |
| **V3** | Gürlük, vurgu, dinamik | Bağırma yok. "Forte" = senin rahat güçlü sesin; mutlak dB hedefi yok |
| **V4** | Uzun tutma, nefes | Nefes süresi yarış değildir; "sayım" okuma önerisidir. Baş dönmesinde dur |
| **V5** | Çeviklik, melisma, blues perdeleri | Hafif ve yavaş başla; boğazı sıkma; yorgunlukta ders bitirilir |
| **P1** | Piyano (varsayılan) | Omuz, bilek ve parmakta gevşeklik; ağrıda dur. Bank yüksekliği ve ayak desteği |
| **P2** | Gam hızı, Hanon, esneme, oktav | Elin kapasitesini aşan açıklıkta zorlama yok; tekrar sayısı ve tempo sınırlı |
| **E1** | Kulak (varsayılan) | Söyleme görevleri V1'e tabidir; söylemek istemeyen kullanıcı için D alternatifi sunulur |

---

## 9. Ön koşullar

Varsayılan kural (ders kartında istisna yazılmadıkça):

1. Modülün ilk dersi: **önceki modülün geçiş egzersizi**.
2. Modül içindeki ders: önerilen sıra; kilit yok.
3. Seviyenin ilk modülü: **önceki seviyenin testi** ya da **yerleştirme testi** sonucu.
4. Gitar S4 kolları (`m19a`, `m19b`): S4 ortak modülleri (M15–M18) değil, **M15 (barre E-şekli) + M17 (majör gam)** yeterli; M16 ve M18 kolla paralel alınabilir.
5. Kulak & Müzisyenlik S1 her kursun S1'iyle paralel açıktır. Çalgı kurslarındaki "bu konuda kulak dersi" bağlantıları önerilir, kilitlemez.
6. Ses kursunda `voc-s1-m03-02` (rahat menzil bulma) tamamlanmadan kişisel tona taşınan dersler varsayılan orta menzilde (kadın/erkek seçimine göre değil, konuşma perdesinden) başlar.

---

## 10. Kamera kuralı

- Kamera yalnız S1'de, yalnız duruş ve el konumu için kullanılır (`K`, motor `A7`).
- Cihazda çalışır, kare saklanmaz ve yüklenmez, puan vermez. Görüntü yetersizse "göremedim" der, tahmin yürütmez.
- S2 ve sonrasında kamera dersi yoktur. "Duruşumu kontrol et" kalıcı araç olarak isteğe bağlı kalır; puanlamaya girmez.

---

## 11. Gizlilik

- **Öğrenci kaydı yok.** Ses yalnız bellekte işlenir ve atılır; dosyaya yazılmaz, yüklenmez, dinletilmez.
- Saklanabilecekler yalnız **türetilmiş sayılar**dır: geçti/kaldı, nota sonuçları, ortalama cent/ms, rahat menzil sınırları (iki nota adı), tempo. Bunlar cihazda tutulur.
- Ö dersleri kayıt dinlemeye dayanmaz. Mevcut "kendi kaydını dinle" adımları referansla karşılaştırma ya da tekrar-ölç adımına çevrilir (`80-mevcut-ders-eslemesi.md`).

---

## 12. İçerik kuralları

1. Telifli şarkı yok. Yalnız özgün egzersiz ve kamu malı eser (`60-kamu-mali-repertuvar.md`). Hedef: ölçülen pratik setlerinin **≥%80'i özgün**.
2. Sınav kurumlarının (ABRSM, RSL, Trinity, RCM) müfredat metni kopyalanmaz. Yalnız seviye yapısından esinlenilir; "Grade X eşdeğeri" iddiası yapılmaz.
3. Akor ilerlemeleri, gam ve rudiment kalıpları serbesttir; belirli bir kaydın düzenlemesi, riff'i ya da sözü kullanılmaz.
4. Tıbbi iddia yok. Ses sağlığı notları genel bilgidir.
5. Dil: başlık EN + TR; gövde EN + TR yazılır, diğer 12 dil katalog çevirisiyle gelir. Nota adlarında Almanca/Lehçe B/H farkı korunur.

---

## 13. Örnek ders kartları (alan iskeleti, gövde metni değil)

```yaml
id: gtr-s1-m02-02
title: { en: "Notes on string six", tr: "Altıncı tel notaları" }
goal: "6. telde E2, F2, G2 notalarını ♩=60'ta temiz çalar."
explanationOutline:
  - 6. tel ve tab'daki yeri
  - 1. ve 3. perde, parmak 1 ve 3
  - Notayı perdenin hemen arkasında basma
  - Tel susturma: bir sonraki notadan önce
referenceAudio: S            # E2-F2-G2-F2-E2 ×2, ♩=60 ve ♩=40
measuredPractice:
  sequence: "E2 F2 G2 F2 | E2 F2 G2 G2 | ×2"
  tempo: { open: 50, target: 60 }
  pass: seviye varsayılanı (S1)
measurement: M
engineSteps: [A2, A3]
fallback: Ö (referansla karşılaştır + 3 maddelik kontrol listesi)
safety: [Ç, G1]
prerequisites: [gtr-s1-m02-01]
commonErrors:
  - "farklı nota, yarım ses yüksek → 2. perdeye kaymış parmak"
  - "duyamadım → parmak teli tam basmıyor ya da tel susturuldu"
adaptation: ♩=40, iki notalık döngü
legacy: "R: guitar.journey.notes.bass_e"
minutes: 12
```

```yaml
id: voc-s1-m02-03
title: { en: "Match one note (±50 cents)", tr: "Tek nota eşleştir (±50 cent)" }
goal: "Duyduğu tek notayı kendi oktavında 2 sn boyunca ±50 cent içinde söyler."
referenceAudio: S + DR       # kişisel menzilde 6 nota, isteğe bağlı dron
measuredPractice:
  sequence: "6 tek nota, kişisel ton, her biri 2 sn"
  tempo: serbest
  pass: "≥5/6 nota, medyan ≤50 c (oktav katlanmış)"
measurement: M!
engineSteps: [A5]
fallback: bekletilir (perde eşleştirme ölçümsüz öğretilemez); D versiyonu "aynı mı farklı mı" ile değiştirilir
safety: [Ç, V1]
```
