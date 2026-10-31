# Piyano / Klavye — S1–S3 ders listesi (v1)

**Hedef:** ~160 · **Yazılan:** 160 ders (S1 40 · S2 60 · S3 60)

**Kurs varsayılanları:** Güvenlik `Ç, P1` · Referans `S` (piyano sentezi) · Geçiş ölçütü: seviye varsayılanı (`00-ders-format-sozlesmesi.md` §6.2).

## Mikrofonla ölçülebilirlik kuralı

v1 piyanosu **mikrofonla ölçülebilen seviyelerle** sınırlıdır. Bunu sağlayan tasarım kuralı:

> **Tek yeni nota kuralı.** Bir ölçülen pratikte aynı anda yalnız **bir yeni nota** başlar. Tutulan bas ya da uzayan nota olabilir; ama iki notanın atakları çakışmaz.

- Bu kurala uyan pratikler `A6` (akustik beklenen nota) ile ölçülür ve ilerlemeyi açar (`M` / `M!`).
- Paralel oktav (iki el aynı nota adı) istisnadır: oktav katlanmış tek nota sayılır, `A6` ile ölçülür.
- Kurala uymayan pratikler (blok akor, iki el farklı notalar aynı anda) `A6p` ile **deneysel** ölçülür (`M~`). İlerlemeyi kilitlemez. MIDI bağlıysa MIDI kesin sonuç verir.
- Her piyano dersinde **MIDI** eşdeğer bir yoldur (USB/BLE). Tabloda MIDI yalnız `M~` derslerinde ayrıca yazılır.
- Akustik piyano akortsuz olabilir: `pno-s1-m01-06` piyanonun genel sapmasını ölçer ve doğrulayıcıya ofset olarak verir. Notalar arası düzensizlik büyükse ölçüm "duyamadım"a kayar, kullanıcıya akort önerilir.
- Pes notalar: S1–S3 en pes C2'ye (65,4 Hz) iner. Kurucu kararıyla (1 Kas) dersler yerinde kalır. Akort motorunun bas profili 28 Hz'e iniyor (PR #7). A6 piyano doğrulayıcısı da C2'yi kapsamalı; bu bir A6 gereksinimi, ders engeli değil (`70-motor-bagimliligi.md`).

**Mevcut:** `R:`/`V:` kimlikleri `piano-NN` (yazılı kurs, 25 ders) ve `piano.foundations.` (`f.`, kamera kursu).

---

## S1 — Klavye ve okuma (40)

### M01 Oturuş, el şekli ve klavye / Seating, hand shape and keyboard (8)

| id | Başlık (EN / TR) | Hedef | Ölçülen pratik | Ölçüm | Motor | Ref/Güv | Mevcut |
|---|---|---|---|---|---|---|---|
| pno-s1-m01-01 | Setup and limits / Kurulum ve sınırlar | Bank yüksekliğini, mesafeyi ve oturuşu kurar | Kamera: gövde hizası 60 sn, uyarı var puan yok · Ö kontrol listesi | K | A7 | — | V: piano-01 + f.camera_space, f.posture, f.light_and_frame |
| pno-s1-m01-02 | Hand shape and wrists / El şekli ve bilekler | Yuvarlak el ve düz bilekle tuşa yerleşir | Kamera: el/bilek 30 sn uyarı · Ö kontrol listesi | K | A7 | — | V: f.hands_and_wrists + f.arms |
| pno-s1-m01-03 | Keyboard map / Klavye haritası | Siyah tuş gruplarından C, D, E, F, G, A, B'yi bulur | D: 8 soru + tüm C'leri sırayla çal | D+M | A6 | — | R: piano-02 |
| pno-s1-m01-04 | Middle C and registers / Orta Do ve bölgeler | Orta Do'yu (C4) ve pes/tiz bölgeleri bulur | C3, C4, C5 + 4 rastgele nota | M | A6 | — | — |
| pno-s1-m01-05 | Finger numbers and touch / Parmak numaraları ve tuşe | Parmak numaralarıyla tek tek tuşa basar | D: 6 soru + C4–G4 parmak 1–5 | D+M | A6 | — | R: piano-03 |
| pno-s1-m01-06 | Microphone and piano check / Mikrofon ve piyano kontrolü | Telefonu yerleştirir, piyanonun akort sapmasını ölçer, MIDI seçeneğini görür | A4 + C4 + C3 çal; genel sapma kaydedilir, "duyamadım" yok | M! | A1+A6 | — | — |
| pno-s1-m01-07 | Black keys, sharps and flats / Siyah tuşlar, diyez ve bemoller | Siyah tuşları adlarıyla çalar | D: 6 soru + C♯4, E♭4, F♯4, A♭4, B♭4 | D+M | A6 | — | R: piano-16 |
| pno-s1-m01-08 | Loose fingers, no tension / Gevşek parmak, gerilimsiz çalış | Omuz ve bilek gerilimini fark edip bırakır | Ö kontrol listesi + 1 dk gevşeme | Ö | A0 | — | V: f.shoulder_tension |

### M02 C pozisyonu: sağ el / C position: right hand (10)

| id | Başlık (EN / TR) | Hedef | Ölçülen pratik | Ölçüm | Motor | Ref/Güv | Mevcut |
|---|---|---|---|---|---|---|---|
| pno-s1-m02-01 | Right-hand five notes / Sağ elde beş nota | Sağ elle C4–G4'ü çalar | C4→G4→C4 · ♩=50→60 | M | A6+A3 | — | R: piano-05 |
| pno-s1-m02-02 | Steps / Basamaklar | Komşu tuşlar arasında basamakla hareket eder | Özgün 2 ölçü · ♩=60 | M | A6+A3 | — | — |
| pno-s1-m02-03 | Skips / Atlamalar | C-E-G atlamalarını çalar | C4-E4-G4-E4-C4 ×2 · ♩=60 | M | A6+A3 | — | — |
| pno-s1-m02-04 | Repeated notes / Tekrar notalar | Aynı tuşu eşit tekrar eder | E4 ×8 · ♩=60 (tekrar notada "duyamadım" toleransı) | M | A6+A3 | KL | — |
| pno-s1-m02-05 | Steady pulse and rests / Düzenli vuruş ve sus | Sus sırasında tuştan kalkar | 4 ölçü nota + sus · ♩=60 | M | A6+A3 | KL | R: piano-04 |
| pno-s1-m02-06 | Quarter and half notes / Dörtlük ve ikilik | Süreleri sayarak çalar | 4 ölçü · ♩=60→70 | M | A6+A3 | KL | — |
| pno-s1-m02-07 | Five-finger pattern in C / Do'da beş parmak kalıbı | Kalıbı tempoda çalar | 1-2-3-4-5-4-3-2-1 · ♩=60→80 | M | A6+A3 | KL | V: f.five_finger |
| pno-s1-m02-08 | Legato: connecting keys / Legato: tuşları bağlamak | Bir tuştan diğerine boşluksuz geçer | 5 nota legato + Ö bağlılık kontrolü | M+Ö | A6 | — | — |
| pno-s1-m02-09 | An original right-hand melody / Özgün sağ el melodisi | Kısa melodiyi çalar | Özgün 4 ölçü · ♩=70 | M | A6+A3 | — | — |
| pno-s1-m02-10 | Right-hand checkpoint / Sağ el geçişi | Sağ el becerilerini birleştirir | Özgün 8 ölçü · ♩=80 · geçiş | M! | A6+A3 | — | — |

### M03 Sol el ve fa anahtarı / Left hand and bass clef (10)

| id | Başlık (EN / TR) | Hedef | Ölçülen pratik | Ölçüm | Motor | Ref/Güv | Mevcut |
|---|---|---|---|---|---|---|---|
| pno-s1-m03-01 | Left-hand five notes / Sol elde beş nota | Sol elle C3–G3'ü çalar | C3→G3→C3 (5-4-3-2-1) · ♩=50→60 | M | A6+A3 | — | R: piano-06 |
| pno-s1-m03-02 | The bass clef / Fa anahtarı | Fa anahtarında F3 ve C3'ü okur | D: 8 soru + 4 nota çal | D+M | A6 | — | — |
| pno-s1-m03-03 | Left-hand steps and skips / Sol elde basamak ve atlama | Sol elle basamak ve atlama çalar | Özgün 2 ölçü · ♩=60 | M | A6+A3 | — | — |
| pno-s1-m03-04 | Left-hand five-finger pattern / Sol el beş parmak kalıbı | Sol elle kalıbı tempoda çalar | 5-4-3-2-1-2-3-4-5 · ♩=60→80 | M | A6+A3 | KL | — |
| pno-s1-m03-05 | Reading the grand staff / Büyük porteyi okumak | İki porteden notayı bulur | D: 10 soru + 6 nota çal | D+M | A6 | — | R: piano-07 |
| pno-s1-m03-06 | Alternating hands / Elleri sırayla kullanmak | Melodiyi eller arasında paylaşır | Özgün 4 ölçü, eller ardışık · ♩=60 | M | A6+A3 | — | R: piano-09 |
| pno-s1-m03-07 | Question and answer between hands / Eller arasında soru-cevap | Sağ el sorar, sol el cevaplar | Özgün 4 ölçü · ♩=70 | M | A6+A3 | — | — |
| pno-s1-m03-08 | Low notes / Pes notalar | C2–G2 bölgesini çalar | C2→G2→C2 · ♩=60 | M | A6+A3 | — | — |
| pno-s1-m03-09 | An original left-hand melody / Özgün sol el melodisi | Sol elle melodi çalar | Özgün 4 ölçü · ♩=70 | M | A6+A3 | — | — |
| pno-s1-m03-10 | Left-hand checkpoint / Sol el geçişi | Sol el ve eller arası geçişi birleştirir | Özgün 8 ölçü · ♩=76 · geçiş | M! | A6+A3 | — | — |

### M04 Ritim okuma / Reading rhythm (11)

| id | Başlık (EN / TR) | Hedef | Ölçülen pratik | Ölçüm | Motor | Ref/Güv | Mevcut |
|---|---|---|---|---|---|---|---|
| pno-s1-m04-01 | Quarter, half and whole notes / Dörtlük, ikilik ve birlik | Süreleri alkışla ve çalarak okur | Alkış 2 ölçü + C4 ile 2 ölçü · ♩=60 | M | A3+A6 | KL | — |
| pno-s1-m04-02 | Reading rhythm with notes / Nota ile ritmi okumak | Perde ve ritmi birlikte okur | Özgün 4 ölçü · ♩=60→70 | M | A6+A3 | KL | R: piano-08 |
| pno-s1-m04-03 | Counting aloud while playing / Çalarken yüksek sesle saymak | Sayarak çalar (sayım ölçülmez) | Özgün 4 ölçü · ♩=60 | M | A6+A3 | KL | — |
| pno-s1-m04-04 | Rests in both hands / İki elde sus | Her iki eldeki susları uygular | Özgün 4 ölçü · ♩=60 | M | A6+A3 | KL | — |
| pno-s1-m04-05 | Three-four time and dotted notes / Üç dörtlük ve noktalı notalar | 3/4'te noktalı ikiliği çalar | Özgün 8 ölçü · ♩=70 | M | A6+A3 | KL | R: piano-20 |
| pno-s1-m04-06 | Paired eighth notes / Çift sekizlikler | Sekizlik çiftlerini eşit çalar | Özgün 4 ölçü · ♩=60 | M | A6+A3 | KL | — |
| pno-s1-m04-07 | Bar lines and repeats / Ölçü çizgileri ve tekrarlar | Tekrar işaretini izler | D: 4 soru + 4 ölçü tekrarla | D+M | A6+A3 | — | — |
| pno-s1-m04-08 | Phrasing and dynamics / Cümleleme ve gürlük | p ve f arasında cümle kurar | Özgün 4 ölçü, p/f fark ≥4 dB | M | A3+A6 | — | R: piano-13 |
| pno-s1-m04-09 | First independent reading / İlk bağımsız okuma | Görülmemiş satırı okur | 3 görülmemiş 4 ölçü · ♩=60 | M | A6+A3 | KL | R: piano-14 |
| pno-s1-m04-10 | Türk: a first Handstück / Türk: ilk el parçası | Kamu malı bir başlangıç parçasını çalar | Türk, Handstücke'den seçme (tek yeni nota uyumlu) · ♩=72 | M | A6+A3 | — | — |
| pno-s1-m04-11 | Rhythm-reading checkpoint / Ritim okuma geçişi | Karışık ritimli parçayı okur | Özgün 8 ölçü · ♩=80 · geçiş | M! | A6+A3 | KL | — |

### S1 seviye testi

| id | Başlık (EN / TR) | Hedef | Ölçülen pratik | Ölçüm | Motor | Ref/Güv | Mevcut |
|---|---|---|---|---|---|---|---|
| pno-s1-test | Level 1 test / Seviye 1 testi | S1 becerilerini gösterir | `50-…` §2.3 | M! | A3+A6 | — | — |

---

## S2 — Tonlar, gamlar ve iki el (60)

### M05 Pentaskallar / Pentascales (12)

| id | Başlık (EN / TR) | Hedef | Ölçülen pratik | Ölçüm | Motor | Ref/Güv | Mevcut |
|---|---|---|---|---|---|---|---|
| pno-s2-m05-01 | G position and moving the hand / Sol konumu ve eli taşımak | Eli G pozisyonuna taşır | G majör pentaskal sağ el · ♩=70 | M | A6+A3 | KL | R: piano-18 |
| pno-s2-m05-02 | G pentascale, left hand / Sol el G pentaskal | Sol elle G pentaskal çalar | ♩=70 | M | A6+A3 | KL | — |
| pno-s2-m05-03 | F pentascale / Fa pentaskal | F pozisyonunu çalar | Eller ayrı · ♩=70 | M | A6+A3 | KL | — |
| pno-s2-m05-04 | D pentascale / Re pentaskal | F♯'yi doğru yerde çalar | Eller ayrı · ♩=70 | M | A6+A3 | KL | — |
| pno-s2-m05-05 | A pentascale / La pentaskal | C♯'yi doğru yerde çalar | Eller ayrı · ♩=70 | M | A6+A3 | KL | — |
| pno-s2-m05-06 | E pentascale / Mi pentaskal | G♯'yi doğru yerde çalar | Eller ayrı · ♩=70 | M | A6+A3 | KL | — |
| pno-s2-m05-07 | Minor pentascales C, G, D / C, G, D minör pentaskal | Üçüncüyü indirip minör çalar | Eller ayrı · ♩=70 | M | A6+A3 | KL | — |
| pno-s2-m05-08 | Minor pentascales A, E, D / A, E, D minör pentaskal | Minör pentaskal üç tonda çalar | Eller ayrı · ♩=70 | M | A6+A3 | KL | — |
| pno-s2-m05-09 | Transposing a melody / Melodiyi taşımak | Kısa melodiyi yeni pentaskala taşır | Özgün 4 ölçü, 3 tonda · ♩=70 | M | A6+A3 | — | — |
| pno-s2-m05-10 | Intervals from a second to a fifth / İkiliden beşliye aralıklar | Aralıkları çalar ve adlandırır | D: 8 soru + 8 aralık çal (ardışık) | D+M | A6 | — | R: piano-17 |
| pno-s2-m05-11 | Pentascales at 100 / ♩=100'de pentaskal | Pentaskalı hızda eşit çalar | 4 ton · ♩=80→100 | M | A6+A3 | KL | — |
| pno-s2-m05-12 | Pentascale checkpoint / Pentaskal geçişi | Majör ve minör pentaskalları çalar | 4 majör + 2 minör, eller ayrı · ♩=100 · geçiş | M! | A6+A3 | KL | — |

### M06 Bir oktav gam, eller ayrı / One-octave scales, hands separate (12)

Ek güvenlik: tüm modül **P2**.

| id | Başlık (EN / TR) | Hedef | Ölçülen pratik | Ölçüm | Motor | Ref/Güv | Mevcut |
|---|---|---|---|---|---|---|---|
| pno-s2-m06-01 | C major with a thumb crossing / Başparmak geçişiyle Do majör | Sağ elle başparmak altı geçerek gam çalar | C4→C5→C4 · ♩=50→60 | M | A6+A3 | KL, P2 | R: piano-19 |
| pno-s2-m06-02 | C major, left hand / Sol elde Do majör | Sol elle gamı çalar | C3→C4→C3 · ♩=50→60 | M | A6+A3 | KL, P2 | — |
| pno-s2-m06-03 | Thumb-under drills / Başparmak geçiş alıştırmaları | Geçişi pürüzsüz yapar | 1-2-3-1, 1-2-3-4-1 kalıpları · ♩=60 | M | A6+A3 | KL, P2 | — |
| pno-s2-m06-04 | G major / Sol majör | G majörü eller ayrı çalar | ♩=60 | M | A6+A3 | KL, P2 | — |
| pno-s2-m06-05 | F major / Fa majör | F majörü (sağ el 4. parmak B♭) çalar | ♩=60 | M | A6+A3 | KL, P2 | — |
| pno-s2-m06-06 | D major / Re majör | D majörü çalar | ♩=60 | M | A6+A3 | KL, P2 | — |
| pno-s2-m06-07 | A minor, natural and harmonic / Doğal ve armonik La minör | İki minör biçimi çalar | ♩=60 | M | A6+A3 | KL, P2 | — |
| pno-s2-m06-08 | E minor and D minor / Mi minör ve Re minör | İki minör tonu çalar | Armonik · ♩=60 | M | A6+A3 | KL, P2 | — |
| pno-s2-m06-09 | Evenness / Eşitlik | Eşit zaman ve gürlükte gam çalar | C majör, IOI sapması ve dB yayılımı raporlanır · ♩=70 | M | A3+A6 | KL, P2 | — |
| pno-s2-m06-10 | Scales in eighth notes / Sekizlik gamlar | Gamı sekizlikle çalar | C, G · ♩=60 sekizlik | M | A6+A3 | KL, P2 | — |
| pno-s2-m06-11 | Scale fingering maps / Gam parmak haritaları | Parmak numaralarını tonlara göre eşleştirir | D: 8 soru | D | A0 | — | — |
| pno-s2-m06-12 | Scale checkpoint / Gam geçişi | Dört tonda gamı eller ayrı çalar | C, G, F, Am · ♩=80 · geçiş | M! | A6+A3 | KL, P2 | — |

### M07 Üçlüler ve çevrimler / Triads and inversions (11)

| id | Başlık (EN / TR) | Hedef | Ölçülen pratik | Ölçüm | Motor | Ref/Güv | Mevcut |
|---|---|---|---|---|---|---|---|
| pno-s2-m07-01 | Major triads, broken / Kırık majör üçlüler | Majör üçlüyü kırık çalar | C, F, G kök-3-5 · ♩=60 | M | A6+A3 | — | — |
| pno-s2-m07-02 | Minor triads, broken / Kırık minör üçlüler | Minör üçlüyü kırık çalar | Am, Dm, Em · ♩=60 | M | A6+A3 | — | — |
| pno-s2-m07-03 | Blocked triads / Blok üçlüler | Üç notayı birlikte çalar | C, F, G blok ×4 | M~ / MIDI | A6p | — | — |
| pno-s2-m07-04 | Broken then blocked / Önce kırık sonra blok | Aynı üçlüyü kırık ve blok çalar | 4 üçlü; kırık kısım ölçülür, blok deneysel | M | A6+A6p | — | — |
| pno-s2-m07-05 | First inversion / Birinci çevrim | 1. çevrimi kırık çalar | C6, F6, G6 · ♩=60 | M | A6+A3 | — | — |
| pno-s2-m07-06 | Second inversion / İkinci çevrim | 2. çevrimi kırık çalar | C64, F64, G64 · ♩=60 | M | A6+A3 | — | — |
| pno-s2-m07-07 | The inversion chain / Çevrim zinciri | Üç pozisyonu sırayla çalar | C → C6 → C64 → C kırık · ♩=60→80 | M | A6+A3 | KL | — |
| pno-s2-m07-08 | Left-hand C, F and G7 / Sol elde C, F ve G7 | Sol elde temel akorları blok çalar | C–F–G7–C blok | M~ / MIDI | A6p | — | R: piano-22 |
| pno-s2-m07-09 | Primary chords in C and G / Do ve Sol'de ana akorlar | I–IV–V'i kırık ve blok çalar | Kırık (ölçülür) + blok (deneysel) | M | A6+A6p | — | — |
| pno-s2-m07-10 | Triads across the hands / Eller arasında üçlü | Kökü sol, 3-5'i sağ elle ardışık çalar | 4 üçlü · ♩=70 | M | A6+A3 | — | — |
| pno-s2-m07-11 | Triads checkpoint / Üçlüler geçişi | Kırık üçlü ve çevrimleri çalar | 6 üçlü + zincir · ♩=80 · geçiş (blok kısmı isteğe bağlı) | M! | A6+A3 | KL | — |

### M08 Basit iki el / Simple two hands (13)

| id | Başlık (EN / TR) | Hedef | Ölçülen pratik | Ölçüm | Motor | Ref/Güv | Mevcut |
|---|---|---|---|---|---|---|---|
| pno-s2-m08-01 | Together: matching pulse / Birlikte: ortak vuruş | İki elle oktav paralel aynı notayı çalar | C pentaskal oktav paralel · ♩=60 | M | A6+A3 | KL | R: piano-10 |
| pno-s2-m08-02 | Melody over a held bass / Tutulan bas üstünde melodi | Sol el notayı tutarken sağ el melodi çalar | Özgün 4 ölçü (tek yeni nota) · ♩=60 | M | A6+A3 | — | R: piano-11 |
| pno-s2-m08-03 | Changing bass and two-note harmony / Değişen bas ve iki sesli armoni | İki notayı aynı anda çalar | Özgün 4 ölçü, çift ses | M~ / MIDI | A6p | — | R: piano-12 |
| pno-s2-m08-04 | Bass on one, melody after / Bas birde, melodi sonra | Basla melodiyi kaydırarak çalar | Özgün 4 ölçü (bas 1, melodi 2-3-4) · ♩=70 | M | A6+A3 | — | — |
| pno-s2-m08-05 | Parallel octaves / Paralel oktavlar | Kısa melodiyi iki elle oktav çalar | Özgün 4 ölçü · ♩=70 | M | A6+A3 | — | — |
| pno-s2-m08-06 | Contrary motion, five fingers / Zıt hareket, beş parmak | İki el zıt yönde beş parmak çalar | C4 başlangıçlı zıt hareket | M~ / MIDI | A6p | — | — |
| pno-s2-m08-07 | Left-hand fifths under a melody / Melodi altında sol el beşlileri | Beşli tutarken melodi çalar | Özgün 4 ölçü | M~ / MIDI | A6p | — | — |
| pno-s2-m08-08 | Staccato against legato / Legatoya karşı staccato | Bir el legato, diğeri staccato çalar | Özgün 4 ölçü | M~ / MIDI | A6p | — | — |
| pno-s2-m08-09 | Original two-hand study / Özgün iki el etüdü | Dört ölçülük iki el etüdünü çalar | Özgün 4 ölçü (tek yeni nota) · ♩=70 | M | A6+A3 | — | R: piano-15 |
| pno-s2-m08-10 | Map a new piece on your own / Yeni parçayı kendin haritala | Parçayı bölümlere ayırıp ilk bölümü öğrenir | D: bölümleri işaretle + 4 ölçü çal | D+M | A6+A3 | — | R: piano-23 |
| pno-s2-m08-11 | Türk: a two-hand Handstück / Türk: iki elli el parçası | Kamu malı iki elli parçayı çalar | Seçme (tek yeni nota uyumlu) · ♩=72 | M | A6+A3 | — | — |
| pno-s2-m08-12 | Beyer: a first study / Beyer: ilk etüt | Beyer Op. 101'den bir etüdü çalar | Seçme · ♩=72 (çakışan ataklar deneysel) | M | A6+A3 | — | — |
| pno-s2-m08-13 | Two-hand checkpoint / İki el geçişi | İki elli parçayı çalar | Özgün 8 ölçü (tek yeni nota) · ♩=76 · geçiş | M! | A6+A3 | — | — |

### M09 Deşifre I / Sight-reading I (11)

| id | Başlık (EN / TR) | Hedef | Ölçülen pratik | Ölçüm | Motor | Ref/Güv | Mevcut |
|---|---|---|---|---|---|---|---|
| pno-s2-m09-01 | Staccato, legato and accents / Staccato, legato ve aksanlar | Artikülasyon işaretlerini çalar | Özgün 4 ölçü, aksan ≥+3 dB · ♩=70 | M | A6+A3 | — | R: piano-21 |
| pno-s2-m09-02 | Intervals by sight / Görerek aralık | Portede aralığı görüp çalar | D: 8 soru + 8 aralık | D+M | A6 | — | — |
| pno-s2-m09-03 | Reading in C position / Do pozisyonunda okuma | Görülmemiş satırı okur | 4 görülmemiş 4 ölçü · ♩=60 | M | A6+A3 | KL | — |
| pno-s2-m09-04 | Reading in G position / Sol pozisyonunda okuma | G pozisyonunda okur | 4 görülmemiş 4 ölçü · ♩=60 | M | A6+A3 | KL | — |
| pno-s2-m09-05 | Reading with hand changes / El değiştirerek okuma | Eller arasında geçen satırı okur | 4 görülmemiş 4 ölçü · ♩=60 | M | A6+A3 | KL | — |
| pno-s2-m09-06 | Ledger lines around middle C / Orta Do çevresinde ek çizgiler | Ek çizgili notaları okur | D: 8 soru + 6 nota | D+M | A6 | — | — |
| pno-s2-m09-07 | Keep going / Durmadan devam | Hata olsa da durmadan okur | 8 ölçü, kesinti yok · ♩=60 | M | A6+A3 | KL | — |
| pno-s2-m09-08 | Reading in three / Üç zamanda okuma | 3/4 satırı okur | 4 görülmemiş 4 ölçü · ♩=70 | M | A6+A3 | KL | — |
| pno-s2-m09-09 | Reading in F position / Fa pozisyonunda okuma | B♭'li satırı okur | 4 görülmemiş 4 ölçü · ♩=60 | M | A6+A3 | KL | — |
| pno-s2-m09-10 | Your own practice cycle / Kendi çalışma döngün | Haftalık kısa döngü planlar | Ö plan kontrol listesi | Ö | A0 | — | R: piano-24 |
| pno-s2-m09-11 | Sight-reading checkpoint / Deşifre geçişi | Görülmemiş 8 ölçüyü okur | Görülmemiş 8 ölçü (tek yeni nota) · ♩=66 · geçiş | M! | A6+A3 | KL | — |

### S2 seviye testi

| id | Başlık (EN / TR) | Hedef | Ölçülen pratik | Ölçüm | Motor | Ref/Güv | Mevcut |
|---|---|---|---|---|---|---|---|
| pno-s2-test | Level 2 test / Seviye 2 testi | S2 becerilerini gösterir | `50-…` §2.3 | M! | A3+A6 | — | V: piano-25 |

---

## S3 — Gamlar, eşlik ve ilk eserler (60)

### M10 İki oktav gam / Two-octave scales (12)

Ek güvenlik: tüm modül **P2**.

| id | Başlık (EN / TR) | Hedef | Ölçülen pratik | Ölçüm | Motor | Ref/Güv | Mevcut |
|---|---|---|---|---|---|---|---|
| pno-s3-m10-01 | C major, two octaves, right hand / Sağ elde iki oktav Do majör | Gamı iki oktav çalar | C4→C6 · ♩=60 | M | A6+A3 | KL, P2 | — |
| pno-s3-m10-02 | C major, two octaves, left hand / Sol elde iki oktav Do majör | Sol elle iki oktav çalar | C2→C4 · ♩=60 | M | A6+A3 | KL, P2 | — |
| pno-s3-m10-03 | G major, two octaves / İki oktav Sol majör | G majörü eller ayrı iki oktav çalar | ♩=60 | M | A6+A3 | KL, P2 | — |
| pno-s3-m10-04 | F major, two octaves / İki oktav Fa majör | F majörü iki oktav çalar | ♩=60 | M | A6+A3 | KL, P2 | — |
| pno-s3-m10-05 | D major, two octaves / İki oktav Re majör | D majörü iki oktav çalar | ♩=60 | M | A6+A3 | KL, P2 | — |
| pno-s3-m10-06 | A harmonic minor, two octaves / İki oktav armonik La minör | Armonik minörü iki oktav çalar | ♩=60 | M | A6+A3 | KL, P2 | — |
| pno-s3-m10-07 | E and D minor, two octaves / İki oktav Mi ve Re minör | İki minör tonu çalar | ♩=60 | M | A6+A3 | KL, P2 | — |
| pno-s3-m10-08 | The chromatic scale / Kromatik gam | Kromatik gamı bir oktav çalar | C4→C5, eller ayrı · ♩=60 | M | A6+A3 | KL, P2 | — |
| pno-s3-m10-09 | Even eighths at 69 / ♩=69'da eşit sekizlikler | Gamı sekizlikle eşit çalar | C, G iki oktav · ♩=60→69 sekizlik | M | A6+A3 | KL, P2 | — |
| pno-s3-m10-10 | Hands together in octaves / Oktav aralıkla eller birlikte | Gamı iki elle oktav paralel çalar | C, G bir oktav · ♩=60 | M | A6+A3 | KL, P2 | — |
| pno-s3-m10-11 | Scale sequences / Gam sekansları | Üçlü gruplarla gamda ilerler | C majör 1-2-3, 2-3-4… · ♩=60 | M | A6+A3 | KL, P2 | — |
| pno-s3-m10-12 | Scale checkpoint / Gam geçişi | İki oktav gamları eller ayrı çalar | C, G, F, D, Am · ♩=69 sekizlik · geçiş | M! | A6+A3 | KL, P2 | — |

### M11 Sol el eşlik kalıpları / Left-hand accompaniment patterns (12)

| id | Başlık (EN / TR) | Hedef | Ölçülen pratik | Ölçüm | Motor | Ref/Güv | Mevcut |
|---|---|---|---|---|---|---|---|
| pno-s3-m11-01 | Broken-chord bass / Kırık akor bası | Kök-5-8 kalıbını çalar | C, F, G · ♩=70 | M | A6+A3 | KL | — |
| pno-s3-m11-02 | Alberti bass in C / Do'da Alberti bası | Alberti kalıbını eşit çalar | C-G-E-G · ♩=60→80 sekizlik | M | A6+A3 | KL | — |
| pno-s3-m11-03 | Alberti in G and F / Sol ve Fa'da Alberti | Kalıbı iki tona taşır | ♩=70 sekizlik | M | A6+A3 | KL | — |
| pno-s3-m11-04 | Waltz bass / Vals bası | Kök + iki blok vuruşu çalar | C–G7, 8 ölçü | M~ / MIDI | A6p | — | — |
| pno-s3-m11-05 | Alberti with a melody / Melodiyle Alberti | Alberti üstünde sağ el melodisi çalar | Özgün 4 ölçü | M~ / MIDI | A6p | — | — |
| pno-s3-m11-06 | Wider broken chords / Geniş kırık akorlar | Kök-5-10 kalıbını zorlamadan çalar | C, F · ♩=60 | M | A6+A3 | P2 | — |
| pno-s3-m11-07 | A walking bass line / Yürüyen bas çizgisi | Basamaklı bas çizgisi çalar | Özgün 4 ölçü · ♩=70 | M | A6+A3 | KL | — |
| pno-s3-m11-08 | Classical-style melody and Alberti / Klasik üslupta melodi ve Alberti | Klasik üslupta özgün parçayı çalar | Özgün 8 ölçü | M~ / MIDI | A6p | — | — |
| pno-s3-m11-09 | Accompaniment at 80 / ♩=80'de eşlik | Kalıbı hızda sürdürür | Alberti 8 ölçü · ♩=80 | M | A6+A3 | KL | — |
| pno-s3-m11-10 | Switching patterns through I–IV–V / I–IV–V'de kalıp değiştirmek | Akor değişiminde kalıbı korur | C–F–G–C Alberti · ♩=70 | M | A6+A3 | KL | — |
| pno-s3-m11-11 | Gurlitt: an accompaniment study / Gurlitt: eşlik etüdü | Gurlitt'ten seçilmiş parçayı çalar | Seçme (kamu malı) | M~ / MIDI | A6p | — | — |
| pno-s3-m11-12 | Accompaniment checkpoint / Eşlik geçişi | Sol el kalıplarını tek başına çalar (sağ el isteğe bağlı) | Sol el 16 ölçü, 3 kalıp · ♩=80 · geçiş | M! | A6+A3 | KL | — |

### M12 Pedal (7)

Mikrofon pedalı doğrudan ölçmez; pedal **Ö** ile, notalar **A6** ile değerlendirilir.

| id | Başlık (EN / TR) | Hedef | Ölçülen pratik | Ölçüm | Motor | Ref/Güv | Mevcut |
|---|---|---|---|---|---|---|---|
| pno-s3-m12-01 | What the sustain pedal does / Uzatma pedalı ne yapar | Pedalın işlevini açıklar | D: 5 soru | D | A0 | — | — |
| pno-s3-m12-02 | Pedal down, pedal up / Pedal bas, pedal kaldır | Pedalı vuruşla birlikte kullanır | Ö + C4 dörtlük 4 ölçü | M+Ö | A6+A3 | KL | — |
| pno-s3-m12-03 | Legato pedalling / Legato pedal | Notadan hemen sonra pedal değiştirir | Ö + 4 ölçü | M+Ö | A6+A3 | — | — |
| pno-s3-m12-04 | Pedal changes with chords / Akor değişiminde pedal | Akor değişiminde pedalı temizler | Ö + kırık C–F–G–C | M+Ö | A6+A3 | — | — |
| pno-s3-m12-05 | When not to pedal / Ne zaman pedalsız | Pedalsız netliği seçer | D: 4 soru + Ö | D+Ö | A0 | — | — |
| pno-s3-m12-06 | A pedalled broken-chord study / Pedallı kırık akor etüdü | Pedalla kırık akor etüdü çalar | Özgün 8 ölçü · ♩=66 | M+Ö | A6+A3 | — | — |
| pno-s3-m12-07 | Pedal checkpoint / Pedal geçişi | Pedallı parçayı çalar | Özgün 8 ölçü · ♩=70 (notalar ölçülür, pedal Ö) | M+Ö | A6+A3 | — | — |

### M13 Akor sembolleri ve lead sheet / Chord symbols and lead sheets (12)

| id | Başlık (EN / TR) | Hedef | Ölçülen pratik | Ölçüm | Motor | Ref/Güv | Mevcut |
|---|---|---|---|---|---|---|---|
| pno-s3-m13-01 | Reading chord symbols / Akor sembolü okuma | C, Am, F, G sembollerini notalara çevirir | D: 10 soru | D | A0 | — | — |
| pno-s3-m13-02 | Chords from symbols / Sembolden akor | Sembolden akoru kırık çalar | 6 akor · ♩=60 | M | A6+A3 | — | — |
| pno-s3-m13-03 | The I–V–vi–IV progression / I–V–vi–IV ilerlemesi | Yaygın ilerlemeyi kırık çalar | C–G–Am–F · ♩=70 | M | A6+A3 | SE | — |
| pno-s3-m13-04 | Melody with chord roots / Akor kökleriyle melodi | Sağ el melodi, sol el kök çalar | Özgün 8 ölçü (tek yeni nota) · ♩=70 | M | A6+A3 | — | — |
| pno-s3-m13-05 | Inversions for smooth changes / Yumuşak geçiş için çevrimler | En yakın çevrimi seçer | C–F/C–G/B–C kırık · ♩=60 | M | A6+A3 | — | — |
| pno-s3-m13-06 | Slash chords and bass notes / Bölü akorlar ve bas | Bölü akorda basın yerini bulur | 4 bölü akor kırık | M | A6 | — | — |
| pno-s3-m13-07 | C7, G7 and Dm7 / C7, G7 ve Dm7 | 7'li akorları kırık çalar | 3 akor · ♩=60 | M | A6+A3 | — | — |
| pno-s3-m13-08 | Block comping on beat one / Birinci vuruşta blok eşlik | Sol elde blok akorla eşlik eder | 8 ölçü | M~ / MIDI | A6p | SE | — |
| pno-s3-m13-09 | Amazing Grace from a lead sheet / Lead sheet'ten Amazing Grace | Geleneksel ezgiyi semboller üstünden çalar | 16 ölçü; melodi + kök (ölçülür), blok (deneysel) | M | A6+A3 | — | — |
| pno-s3-m13-10 | Transposing a lead sheet / Lead sheet'i taşımak | Kısa lead sheet'i yeni tona taşır | Özgün 8 ölçü, C→G | M | A6+A3 | — | — |
| pno-s3-m13-11 | An unseen lead sheet / Görülmemiş lead sheet | İlk görüşte melodi + kök çalar | Görülmemiş 8 ölçü · ♩=66 | M | A6+A3 | — | — |
| pno-s3-m13-12 | Lead-sheet checkpoint / Lead sheet geçişi | Lead sheet'ten melodi ve kök çalar | Görülmemiş 16 ölçü · ♩=72 · geçiş | M! | A6+A3 | — | — |

### M14 Kromatik, zıt hareket ve ilk eserler / Chromatic, contrary motion and first pieces (16)

| id | Başlık (EN / TR) | Hedef | Ölçülen pratik | Ölçüm | Motor | Ref/Güv | Mevcut |
|---|---|---|---|---|---|---|---|
| pno-s3-m14-01 | Chromatic scale, two octaves / İki oktav kromatik gam | Kromatiği iki oktav eller ayrı çalar | ♩=60 | M | A6+A3 | KL, P2 | — |
| pno-s3-m14-02 | Contrary-motion C scale / Zıt hareketli Do gamı | Gamı iki elle zıt yönde çalar | C4'ten iki yöne, bir oktav | M~ / MIDI | A6p | P2 | — |
| pno-s3-m14-03 | Hands together in parallel / Paralel eller birlikte | C ve G'yi oktav paralel iki oktav çalar | ♩=60 | M | A6+A3 | KL, P2 | — |
| pno-s3-m14-04 | Petzold: Minuet in G, right hand / Petzold: Sol Majör Menuet, sağ el | Menuet'in sağ elini çalar | BWV Anh. 114, sağ el · ♩=80 | M | A6+A3 | — | — |
| pno-s3-m14-05 | Petzold: Minuet in G, left hand / Petzold: Sol Majör Menuet, sol el | Menuet'in sol elini çalar | BWV Anh. 114, sol el · ♩=80 | M | A6+A3 | — | — |
| pno-s3-m14-06 | Petzold: Minuet in G, hands together / Petzold: Sol Majör Menuet, eller birlikte | Menuet'i iki elle çalar | BWV Anh. 114 · ♩=80 | M~ / MIDI | A6p | — | — |
| pno-s3-m14-07 | Musette in D / Re Majör Musette | Notenbüchlein'deki Musette'i çalar | BWV Anh. 126, eller ayrı ölçülür, birlikte deneysel · ♩=80 | M | A6+A3 | — | — |
| pno-s3-m14-08 | Türk: a character piece / Türk: bir karakter parçası | Türk'ten seçilmiş parçayı çalar | Seçme (tek yeni nota uyumlu) · ♩=76 | M | A6+A3 | — | — |
| pno-s3-m14-09 | Gurlitt: a melodic piece / Gurlitt: melodik parça | Gurlitt'ten melodik parçayı çalar | Seçme · ♩=76 | M | A6+A3 | — | — |
| pno-s3-m14-10 | Czerny Op. 599: a study / Czerny Op. 599: bir etüt | Czerny etüdünü çalar | Op. 599'dan seçme · ♩=80 | M | A6+A3 | P2 | — |
| pno-s3-m14-11 | Beyer Op. 101: a later study / Beyer Op. 101: ileri bir etüt | Beyer'in ileri etüdünü çalar | Seçme · ♩=80 | M | A6+A3 | — | — |
| pno-s3-m14-12 | Schumann: Melodie / Schumann: Melodie | Op. 68 No. 1'i çalar | Op. 68 No. 1 | M~ / MIDI | A6p | — | — |
| pno-s3-m14-13 | Leopold Mozart: a Minuet / Leopold Mozart: bir Menuet | Nannerl defterinden menueti çalar | Seçme · ♩=80 | M | A6+A3 | — | — |
| pno-s3-m14-14 | Hanon No. 1, carefully / Dikkatle Hanon No. 1 | Hanon No. 1'i eller ayrı, gerilimsiz çalar | İlk 4 ölçü ×2 el · ♩=60 | M | A6+A3 | KL, P2 | — |
| pno-s3-m14-15 | Preparing a performance / Performansa hazırlık | Harita, yavaş tempo, döngü ve tempo merdivenini uygular | Ö plan + seçilen parçanın 8 ölçüsü | M+Ö | A6+A3 | — | — |
| pno-s3-m14-16 | Repertoire checkpoint / Repertuvar geçişi | Bir kamu malı eseri çalar | Seçilen eser, tek yeni nota sürümü ölçülür (tam sürüm MIDI/deneysel) · geçiş | M! | A6+A3 | — | — |

### S3 seviye testi

| id | Başlık (EN / TR) | Hedef | Ölçülen pratik | Ölçüm | Motor | Ref/Güv | Mevcut |
|---|---|---|---|---|---|---|---|
| pno-s3-test | Level 3 test / Seviye 3 testi | S3 becerilerini gösterir | `50-…` §2.3 | M! | A3+A6 | — | — |

---

## Bilerek v1 dışında bırakılanlar

- Eller birlikte tam gamlar (paralel, oktav dışı) ve arpejler: S4, MIDI ile (v1.x).
- Burgmüller Op. 100, Clementi Op. 36, Notenbüchlein'in iki elli zor parçaları: S4–S5.
