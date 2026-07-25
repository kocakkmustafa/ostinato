# Ostinato G0 — Başlangıç Çello Pedagojisi Kütüphanesi (v1.1)

**Tarih:** 2026-07-26 (v1.1: movement-science-advisor ilk-geçiş bulguları işlendi — risk-sınıfı katmanı + geri-bildirim-sıklığı ilkesi + güvenlik şartları) · **Statü:** İLK GEÇİŞ — profesyonel çello öğretmeni doğrulaması ZORUNLU (plan §16; her hata-kuralı en az bir uzman onayı almadan rule-set'e girmez)
**Kaynak tabanı:** G0 web taraması (21 URL'li bulgu; ham liste `2026-07-26-g0-canli-dogrulama.md` ekinde) — metod kitapları yayıncı/IMSLP sayfalarından, hata terminolojisi öğretmen kaynaklarından (celloprofessor.com/Jamie Fiste-CMU, CelloBello/Baverstam, stüdyo blogları), açık-tel progresyonu Texas Tech DMA tezi (Almeida 2020; Rolland/Drexler/Evenchick/Young pedagojileri) + ASTACAP hedefleri.
**Kullanım:** (1) V1 egzersiz merdiveninin iskeleti (G6 içerik), (2) hata taksonomisi = rule-set kodlarının tohumu (G4) + veri-protokolü `error_code` sözlüğü (G1-A), (3) öğretmen görüşmelerinde (G1-B soru 4) duyulan terimlerle ÇAPRAZLANIR.

---

## 1. Standart müfredat manzarası (ne öğretiliyor, hangi sırayla)

- **Suzuki Cello School Vol.1** (Alfred; 18 parça, Twinkle varyasyonlarıyla başlar): dinle-taklit-tekrar; ebeveyn katılımı çekirdek — Ostinato'nun "evde pratik görünürlüğü" vaadiyle doğal örtüşme.
- **Essential Elements for Strings (Cello) Book 1** (Hal Leonard): grup dersi/okul standardı — B2B (okul) kanalının kullandığı dil.
- **Feuillard Daily Exercises** (1919, kamu malı/IMSLP) + **Dotzauer 113 Etudes Book 1**: teknik egzersiz klasikleri; Almeida tezi Dotzauer-tarzı kitapların shifting/harmonik hazırlığını ERTELEDİĞİNİ eleştirir — "geleneksel sıra = tek doğru" değil; V1 kapsamı (açık tel + temel yay) bu tartışmanın GÜVENLİ bölgesinde.
- **Eastman Community Music School Level I** resmî listesi: Essential Elements + Suzuki 1 (parça 1-14) + Cello Time serisi + Krane — kurumsal müfredatın V1 hedef seviyemizle örtüştüğünün kanıtı.
- **ASTACAP Foundation** hedefleri: iyi postür, sol el pozisyonu, yay tutuşu, entonasyon/ritim, 1-3-4 parmak; Level 1'de détaché/staccato/legato + bow division farkındalığı → V1 "en az 5 güvenilir geri bildirim" hedefinin sektör-dili karşılığı.

### 1.1 Açık-tel/uzun-yay öğretim dizisi (Almeida 2020 sentezi — V1 egzersiz merdiveni iskeleti)

1. **Ringing tone** kavramı: açık D pizzicato → "kaç ses duyuyorsun?" (rezonans farkındalığı). *Ostinato karşılığı: sustain/decay ölçümü — mikrofonla doğal.*
2. **Orta bölgede kısa yaylar** (Evenchick): yerleşim + kısa strok; kontrol önce, uzunluk sonra. *Kamera: yay bölgesi (bridge-region referansı) + kısa strok tespiti.*
3. **Rolland "Open String Rhythms"** (6 kalıp, A-F artan karmaşıklık): ritim kalıplarıyla açık tel. *Metronom hizası + onset zamanlaması — ses motoru çekirdek senaryosu.*
4. **Uzun yaylara geçiş** (Drexler dizisi): 2→3→4 nota tek yayda slurred staccato → Phyllis Young "reaching the moon" (dinamik yay tutuşu) → tam uzun yay. *Kamera: bow range utilization + path deviation; ses: sustain sürekliliği.*
5. **Yay değişimi pürüzsüzlüğü**: détaché temeli. *Füzyon senaryosu: yön değişimi (kamera) × ses sürekliliği (mikrofon) — Ostinato'nun ayırt edici bulgusu.*

## 2. Hata taksonomisi v0 (rule-set kod tohumları)

Sınıflandırma: **[K]** kamera-gözlemlenebilir · **[S]** ses-vekilli · **[K+S]** füzyon · **[✗]** V1'de HÜKÜM VERİLMEZ (gözlem güvenilir değil — dürüstlük ilkesi). Her satır uzman onayı bekler (❓ = kaynak çelişkili/zayıf).

### 2.0 Risk-sınıfı katmanı (movement-science ilk-geçişi; uzman onayı bekliyor)

Çelloda güvenlik hatası akut değil KÜMÜLATİF gerginlik biçimindedir (uzun süre sürdürülen kötü postür). Geri bildirim ÖNCELİĞİ gözlemlenebilirlikten değil risk sınıfından gelir:
- **Sınıf-1 (sürdürülebilir-gerginlik adayı; en yüksek feedback önceliği):** E-POST-SLOUCH + E-POST-HEAD-FWD + E-POST-SHOULDER-RAISE **kombinasyonu sürdürülürse** · E-LH-WRIST-COLLAPSE sürdürülürse.
- **Sınıf-3 (büyük mekanik):** E-BOW-SKEW, E-BOW-REGION-DRIFT, E-BOW-SHORT, E-ELBOW-BAD-HEIGHT, E-POST-CELLO-POS, E-POST-FEET.
- **Sınıf-4 (ince form; en düşük öncelik, geniş tolerans):** parmak-düzeyi hatalar (pinky-collapse, parmak yerleşimi).
- **Çocuk süre tavanı:** statik postür/egzersiz süresi çocuklarda kısa tutulur (aile sözleşmesi gereği) → ruleset config'ine `session_duration_cap_child` parametresi; SAYI uzmandan (soru §5.7).

### 2.1 Postür / kurulum (Setup Check + sürekli izleme)

| Kod | Hata (kaynak terimi) | Gözlem | V1 |
|---|---|---|---|
| E-POST-SLOUCH | Kambur oturma (hunched/slouched back) | [K] gövde ekseni açısı | ✅ |
| E-POST-HEAD-FWD | Başı/boynu öne uzatma | [K] baş-omuz hizası | ✅ |
| E-POST-SHOULDER-RAISE | Omuz yükselmesi (özellikle sağ, yay sırasında) | [K] omuz-simetri + yükseklik değişimi | ✅ |
| E-POST-FEET | Ayaklar yerde değil / desteksiz | [K] ayak-zemin (standart açıda görünür) | ✅ |
| E-POST-CELLO-POS | Çello gövdeye göre yanlış konum/açı | [K] enstrüman-bbox × gövde ilişkisi | ✅ |
| E-POST-ENDPIN | Endpin-uzunluğu türevli açı hatası | [K] ❓ endpin bacaklarla kapanır + "doğru açı" vücut-oranı/çello-boyu kalibrasyonsuz anlamsız | uzmana: kalibrasyonsuz hüküm mümkün mü? |
| E-POST-CELLO-SQUEEZE | Çelloyu diz/kollarla sıkma | [✗] görsel vekil zayıf (temas basıncı görünmez) | ❓ uzmana: güvenilir görsel işaret var mı? |
| — | "Sandalye kenarında oturma" bazı kaynaklarda hata | ❓ ÇELİŞKİLİ: birçok pedagoji sandalyenin ÖN yarısında oturmayı önerir; hata muhtemelen "kenarda ÇÖKMÜŞ oturma" | uzman netleştirmesi |

### 2.2 Yay tutuşu / sağ el

| Kod | Hata | Gözlem | V1 |
|---|---|---|---|
| E-BOW-STEAK-KNIFE | "Steak knife grip" — aşırı supinasyon (Fiste'nin 1 numaralı başlangıç hatası) | [K] el landmark oryantasyonu ❓ (hand-landmark güvenilirliği V0 benchmark'ına bağlı) | aday |
| E-BOW-PINKY-COLLAPSE | Serçe parmak çökmesi | [K] parmak eğriliği ❓ ince detay — kamera mesafesinde şüpheli | aday |
| E-BOW-DEATH-GRIP | Aşırı sıkı tutuş (gerginlik) | [✗] basınç görünmez; ses vekili (sert atak) spekülatif | ✗ (uzmana: dolaylı işaretler?) |
| E-BOW-FIST | Yumruk tutuş | [K] kaba el şekli | aday |

### 2.3 Yay hareketi (V1 çekirdeği)

| Kod | Hata | Gözlem | V1 |
|---|---|---|---|
| E-BOW-SKEW | Yay köprüye paralel değil (crooked bow) | [K] yay-hattı (2-keypoint) × köprü açısı | ✅ ÇEKİRDEK |
| E-BOW-REGION-DRIFT | Temas noktası kayması (köprüye/tuşeye sürüklenme) | [K] yay-hattı × bridge_region | ✅ ÇEKİRDEK |
| E-BOW-SHORT | Yayın hep küçük bölümü kullanılıyor | [K] bow range utilization | ✅ |
| E-BOW-BUMPY-CHANGE | Yay değişiminde ses kesilmesi/pürüz | [K+S] yön değişimi × sustain sürekliliği | ✅ AYIRT EDİCİ |
| E-ELBOW-BAD-HEIGHT | Sağ dirsek faza göre çok düşük/yüksek | [K] dirsek yörüngesi | ✅ (tel-bağımlı tolerans) |
| E-BOW-TENSE-SOUND | Bastırılmış/cızırtılı ton | [S kısmi] ❓ "ton hükmü yok" ilkesiyle sınır — yalnız NÖTR dille ("ses kesintili") | uzman + dil dikkatli |

### 2.4 Sol el (V1'de temel seviye)

| Kod | Hata | Gözlem | V1 |
|---|---|---|---|
| E-LH-WRIST-COLLAPSE | Bilek kırılması (içe/dışa) | [K] bilek açısı | ✅ |
| E-LH-ELBOW-LOW | Sol dirsek düşük | [K] dirsek yüksekliği | ✅ |
| E-LH-POSITION-DRIFT | Elin klavye üzerinde genel konum kayması | [K] el × fingerboard | aday |
| E-LH-THUMB-SQUEEZE | Başparmak sıkma | [✗] başparmak çello arkasında — kamerada görünmez | ✗ |

## 3. Tolerans felsefesi (rule-set config ilkeleri)

1. **Vücut-bağımlı tolerans:** "Yay tele 90°" kuralı bile mutlak değil — kısa kollu öğrencide A telinde uca kadar dik ısrarı gereksiz gerginlik yaratır (celloprofessor.com bulgusu). → Eşikler tel-başına + faz-başına + (ileride) vücut-oranı-normalize; TEK global açı eşiği YASAK (motion-core güven-kapısı deseniyle tutarlı).
2. **Başlangıçta geniş tolerans, ilerledikçe daralan:** ASTACAP Foundation→Level 1 geçişi gibi; tolerans profilleri versiyonlu config'te (`ruleset-v*.json`), öğretmen düzenlemesine açık (plan §18 "uzman tarafından düzenlenebilir config").
3. **Pozitif çerçeve:** geri bildirim replikleri "hata yakalama" değil "bir sonraki iyi tekrar" diliyle (Suzuki tekrar felsefesi); "yanlış" kelimesinden kaçın, davranış tarifi ver ("yayın ortasını daha çok kullan").
4. **Tolerans bandı = geri bildirim BASKILAMA eşiği (guidance hypothesis):** bant-içi sapmalar SESSİZ kalır; uyarı ancak ardışık N bant-dışı tekrardan sonra tetiklenir (N uzmandan — §5.10); öğrenci ilerledikçe geri bildirim seyrekleşir (fading/summary). Aşırı sık/anlık geri bildirim bağımlılık yaratır ve kalıcı öğrenmeyi bozar — her karede konuşan koç YASAK (plan §10 kanal listesinin üstüne sıklık kuralı).
5. **GÜVENLİK ŞARTI — "yayı köprüye paralel tut" komutu:** bu replik tolerans-bandına SERT bağımlıdır; bandsız/sabit-açı fallback ASLA üretime gitmez. Kısa kollu/çocuk kullanıcıda A telinde katı paralellik ısrarı fiziksel gerginlik yaratır (§3.1 bulgusu) → replay-fixture setine "kısa-kollu/çocuk + A teli" senaryosu ZORUNLU; hangi tel/pozisyonda komutun tamamen BASTIRILACAĞI uzmandan (§5.12).
6. **Telafi-zinciri kontrolü:** her düzeltme repliği için "bu komut görünmez bir hatayı tetikler mi?" sorusu tasarım kontrol listesinde (bilinen aday: "çelloyu yaklaştır" → diz/kol SIKMA [✗ kamerada görünmez]); bilinen çiftler uzmana sorulur (§5.11).
7. **Dış-odak tercihi:** replikler mümkünse dış-referanslı ("yayı köprüye paralel", "sesi kesintisiz tut") — beden-parçası-yönelimli (içsel-odak) repliklerden ("omzunu indir") motor-öğrenme kanıtı daha güçlü; omuz/bilek replikleri için dış-referans alternatifi denenir.

## 4. Çocuk çello boyutları (veri protokolü çeşitlilik matrisi girdisi)

Kaynaklar arasında belirgin varyans var (4/4'e geçiş 11-14 yaş arası değişiyor); tüm kaynaklar yaşın KABA başlangıç olduğunu, asıl ölçünün boy/kol uzunluğu olduğunu vurgular (Johnson String vd.):

| Boy | Yaş (kaynak aralığı) | Boy (Oxford Cello) |
|---|---|---|
| 1/10 | 3-5 | <110cm |
| 1/8 | 4-6 | 110-120cm |
| 1/4 | 6-8 | 120-135cm |
| 1/2 | 8-10 | 135-145cm |
| 3/4 | 10-13 | 145-160cm |
| 4/4 | 11-14+ | 160cm+ |

→ Veri protokolündeki `celloSize` hücre hedefleri bu tabloyla uyumlu; **model, boy-oranı farkını (1/4 çello + çocuk gövdesi) görmeden çocuk segmentinde ÇALIŞMAZ varsayımıyla** çeşitlilik zorunlu (protokol §3 çocuk kliplerinin yarı-pay gerekçesi).

## 5. Uzman-doğrulama ihtiyaç listesi (G1-B görüşmelerine taşınacak)

1. §2 taksonomisinin eksikleri/yanlışları — özellikle ❓ satırları (sandalye, squeeze, steak-knife'ın kamera işareti, death-grip dolaylı işaretleri).
2. Her ✅ kural için "yeşil/sarı/kırmızı" tolerans sınırları (somut açı/süre değil; öğretmen diliyle — mühendislik çevirisi bizde).
3. V1 egzersiz merdiveni (§1.1) sıralamasının onayı + egzersiz başına "bu egzersizde EN ÇOK şu bozulur" eşlemesi.
4. Yanlış-pozitifin pedagojik maliyeti: hangi hatada yanlış alarm ÖĞRENCİYE zarar verir (ör. gereksiz "düzelt" komutu gerginlik yaratır) — güven kapısı önceliklendirmesi buradan.
5. "Ses kesildi/pürüzlü" tarzı nötr ses bulgularının öğrenci motivasyonuna etkisi (Suzuki-tarzı pozitif çerçeveyle bağdaşan replik önerileri).
6. **Risk-sınıfı onayı (§2.0):** hangi hatalar (tek/kombinasyon, sürdürüldüğünde) gerçek gerginlik/RSI riski taşır — Sınıf-1 aday eşlememiz doğru mu?
7. **Çocuk statik-postür süre tavanı:** somut dakika/tekrar sayısı (`session_duration_cap_child` için).
8. **Endpin-türevli açı:** vücut oranı/çello boyu kalibrasyonu olmadan "yanlış açı" hükmü verilebilir mi?
9. **Yay-tutuş kümesi (§2.2) V1 kapsamı:** steak-knife/pinky-collapse/fist plan §8'de yok — bilinçli V1-dışı mı olsun?
10. **Geri bildirim sıklığı:** kaç ardışık bant-dışı tekrar sonrası uyarı; fading takvimi nasıl?
11. **Telafi-zinciri:** "çelloyu yaklaştır" → sıkma gibi bilinen düzeltme→görünmez-hata çiftleri hangileri?
12. **Yay-paralel komutunun bastırma sınırı:** kısa kollu/çocukta hangi tel/pozisyonlarda komut tamamen durdurulmalı?

## 6. Bilinen boşluklar

- CelloBello içeriği yalnız arama-snippet'lerinden (403 bot-engeli) — tam ders metinleri elle taranmalı (kurucu veya tarayıcı oturumu).
- TR pedagoji kaynağı taranmadı (kaynaklar EN-ağırlıklı); TR öğretmen görüşmeleri terminoloji farkını kapatır.
- Vibrato/shifting/ton üretimi bilinçli KAPSAM DIŞI (V1-dışı; plan §8).
