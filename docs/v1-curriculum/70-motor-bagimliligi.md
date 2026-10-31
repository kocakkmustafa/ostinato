# Motor bağımlılık özeti (v1, 690 ders)

**Kaynak:** Bu belgedeki sayılar `10-gitar.md`, `20-ses.md`, `30-piyano.md` ve `40-kulak-muzisyenlik.md` tablolarından betikle sayıldı (2026-10-31). Ders listesi değişirse sayılar yeniden üretilmelidir.
**Motor kodları:** `00-ders-format-sozlesmesi.md` §4. Motor işi `feat/precise-tuner` dalında yürüyor; sıra: akort (A1) → tek nota (A2) → ritim (A3) → akor (A4) → ses perdesi (A5) → piyano (A6). Kamera (A7) paralel.

---

## 1. Hangi adıma kaç ders bağlı?

"Bağlı" = dersin satırında o adım geçiyor (bir ders birden çok adıma bağlı olabilir; satır toplamı 690'ı aşar).

| Adım | Gitar | Ses | Piyano | Kulak | **Toplam** | Bunlardan `M!` (bekletilir) |
|---|---|---|---|---|---|---|
| A0 — motor yok (yalnız D/Ö) | 2 | 15 | 6 | 19 | **42** | 0 |
| A1 — hassas akort | 7 | — | 1 | — | **8** | 3 |
| A2 — tek nota (gitar) | 126 | — | — | — | **126** | 17 |
| A3 — ritim / onset / göreli dB | 182 | 130 | 124 | 19 | **455** | 64 |
| A4 — gitar akor | 99 | — | — | — | **99** | 14 |
| A5 — ses perdesi / f0 izi | 8 | 213 | — | 17 | **238** | 31 |
| A6 — piyano tek yeni nota | — | — | 138 | — | **138** | 16 |
| A6p — piyano çok sesli (deneysel) | — | — | 16 | — | **16** | 0 (14'ü `M~`, kilitlemez) |
| A7 — kamera (S1 duruş) | 2 | 1 | 2 | — | **5** | 0 |

**Dersi açan adım** (satırdaki en geç adım; her ders bir kez sayılır):

| Açan adım | Gitar | Ses | Piyano | Kulak | Toplam |
|---|---|---|---|---|---|
| A0 | 2 | 15 | 6 | 19 | 42 |
| A1 | 2 | — | — | — | 2 |
| A2 | 18 | — | — | — | 18 |
| A3 | 110 | 11 | — | 14 | 135 |
| A4 | 98 | — | — | — | 98 |
| A5 | 8 | 213 | — | 17 | 238 |
| A6 | — | — | 136 | — | 136 |
| A6p | — | — | 16 | — | 16 |
| A7 | 2 | 1 | 2 | — | 5 |
| **Toplam** | **240** | **240** | **160** | **50** | **690** |

(A6p'nin 16 dersinden 2'si (`pno-s2-m07-04`, `pno-s2-m07-09`) A6 kısmıyla ilerlemeyi açar; çok sesli kısmı deneyseldir.)

## 2. Motor adımları geldikçe tam ölçülü ders sayısı

Kamera (A7) hazır varsayıldı; hazır değilse 5 ders Ö kontrol listesine düşer, hiçbiri bekletilmez.

| Hazır olan adımlar | Gitar | Ses | Piyano | Kulak | **Toplam** |
|---|---|---|---|---|---|
| Yalnız A0 | 4 | 16 | 8 | 19 | **47** |
| + A1 | 6 | 16 | 8 | 19 | **49** |
| + A2 | 24 | 16 | 8 | 19 | **67** |
| + A3 | 134 | 27 | 8 | 33 | **202** |
| + A4 | 232 | 27 | 8 | 33 | **300** |
| + A5 | 240 | 240 | 8 | 50 | **538** |
| + A6 | 240 | 240 | 144 | 50 | **674** |
| + A6p | 240 | 240 | 160 | 50 | **690** |

**Okuma:** Gitar A1–A4 ile %97 ölçülür. Ses ve kulak kursları neredeyse tamamen **A5**'e bağlı. Piyano A6'ya bağlı; A6 olmadan yalnız 8 ders (kurulum, D ve Ö dersleri) ölçülür.

## 3. Bir adım gecikirse

Kural (`00-…` §4.2): `M` dersi Ö (referansla karşılaştırma + kontrol listesi) olarak gönderilebilir; `M!` dersi bekletilir; `M~` zaten kilitlemez.

| Gecikirse | Etkilenen | Ö ile gönderilebilir (`M`) | Bekletilir (`M!`) | Bekletilenler |
|---|---|---|---|---|
| A1 | 8 | 5 | 3 | `gtr-s1-m01-04` (akort), `gtr-s1-test`, `pno-s1-m01-06`. **Bugünkü ±20/30 c akort kapısıyla gönderilebilir** (A1 yedeği); ±5 c hedefi "yakında" |
| A2 | 126 | 109 | 17 | Gitar modül geçişleri (S1 M02/M03; S2 M08/M09; S3 M11/M12/M13; S4 M17/M18/M19A/M19B), `gtr-s4-m19b-01` (elektro mikrofon testi) ve gitar S1–S4 testleri |
| A3 | 455 | 391 | 64 | Dört kursun **neredeyse tüm** modül geçişleri ve seviye testleri + `gtr-s1-m03-01` (gecikme kalibrasyonu) |
| A4 | 99 | 85 | 14 | Gitar akor modüllerinin geçişleri (S1 M04; S2 M05/M06/M07; S3 M10/M13/M14; S4 M15/M16) ve S1–S4 testleri |
| A5 | 238 | 207 | 31 | Ses kursunun tüm geçişleri ve testleri, `voc-s1-m01-08` (mikrofon), `voc-s1-m02-03` (ilk perde eşleştirme), kulak perde geçişleri ve testleri, `gtr-s4-m19b-18`, `gtr-s4-test-b` |
| A6 | 138 | 122 | 16 | Piyano modül geçişleri, S1–S3 testleri, `pno-s1-m01-06` |
| A6p | 16 | 2 (A6 kısmıyla) | 0 | — (14 ders `M~`: Ö + MIDI ile gönderilir) |
| A7 | 5 | 5 (Ö kontrol listesi) | 0 | — |

**Yalnız öz-kontrolle gönderilebilecek ders sayısı:** 690 dersin **616'sı** herhangi bir motor adımı kaysa bile gönderilebilir: 555 `M` dersi Ö'ye düşer, 42 D/Ö dersi motor beklemez, 5 K dersi kontrol listesine, 14 `M~` dersi Ö + MIDI'ye düşer. Bekletilebilecek 74 `M!` dersi (gitar 27, ses 24, piyano 16, kulak 7) modül geçişleri, seviye testleri ve kurulum/kalibrasyon dersleridir. Ancak ürün önerisinin ayrıştırıcısı "üç sonuçlu dürüst geri bildirim"dir; Ö ağırlıklı bir kurs Apple 4.3 ve kullanıcı açısından zayıf kalır (aşağıda §5).

## 4. Motor ekibine ders tarafından gelen gereksinimler

Kabul çıtaları motor tarafının; aşağıdakiler derslerin **varsaydığı** davranışlardır. Eksik olan varsa ilgili dersler yedek davranışa düşer.

| Adım | Ders tarafının varsayımı |
|---|---|
| A-alt (adım 0) | Gecikme kalibrasyonu `gtr-s1-m03-01` ve yerleştirme testinde çalışır; kulaklık/Bluetooth rota değişiminde yenilenir. Bluetooth çıkışında ritim dersleri kapalı ya da alkış testli |
| A1 | Drop D (D2 = 73,4 Hz) dahil. Kapo algılama gerekmez (kullanıcı kapoyu seçer) ama sesli ton doğrulaması kapoya göre ofsetlenir. Piyano için genel sapma ölçümü (`pno-s1-m01-06`) doğrulayıcıya ofset olarak geçer |
| A2 | **Sesli perde** ile doğrulama (gitar portede bir oktav yüksek yazılır). Doğal flajoletler (12./7./5. perde frekansları). Aynı perdede hızlı tekrar → "duyamadım". Parmak stili arpejlerde **çalan teller üst üste biner**: beklenen nota yeni atakta aranmalı, önceki notanın kuyruğu "farklı nota" sayılmamalı. Palm mute'ta perde kararı istenmez (yalnız A3). Elektro gitar için "duyamadım" oranı raporu (`gtr-s4-m19b-01`) |
| A3 | El çırpma, vuruş (strum) ve ses atağı onset'i. **Swing oranı** (%60–70). **Göreli dB** (oturum içi p/f referansı) ve **susturma algısı** (sus anında ≥20 dB düşüş, 100 ms içinde). 60 sn'de akor değişim sayısı (onset + A4). Ses kursunda pencere +30 ms. Notalar arası IOI eşitliği (piyano gam eşitliği) |
| A4 | Tel tel kontrol ve eksik tel; **iki-üç sesli** şekiller (power chord, çift ses, çimdik); bölü akorlar (G/B); barre; kapolu sesli ton; 7'li ve sus akorları. Tam akor listesi: Em Am E A D G C Dm E7 A7 D7 B7 Dsus2 Dsus4 Asus2 Asus4 Fmaj7 F(4 tel) Cadd9 G/B D/F♯ Am7 Em7 Dm7 Cmaj7 Amaj7 Dmaj7 E5 G5 A5 C5 D5 + E-/A-şekli barre majör, minör, 7, m7 |
| A5 | **Oktav katlanmış** karşılaştırma; nota başına medyan cent (atak 80–120 ms atlanır); tutma IQR; **kontur sürekliliği** (siren, register geçişi: >1 yarım ses atlama algısı); scoop yerleşme süresi; koşu (melisma) nota segmentasyonu ♩=90 sekizliğe kadar; vibrato oranı/genişliği (yalnız bilgi). Aynı f0 izleyici **gitar bend/vibrato** için de kullanılır (8 gitar dersi) |
| A6 | Akustik piyanoda **tek yeni nota** doğrulaması (tutulan notalar sürerken); paralel oktav = tek nota sınıfı; **alt sınır ≤60 Hz** (C2 = 65,4 Hz; bugünkü 70 Hz alt sınır yetmez); tekrar nota toleransı; MIDI (USB/BLE) eşdeğer yol |
| A6p | Blok üçlü ve iki el farklı nota; sonuç "deneysel" etiketiyle, kilitlemez |
| A7 | Mevcut gövde hizası referansı (gitar, ses, piyano) yeterli; yeni kamera modeli gerekmez. El/bilek uyarısı (`pno-s1-m01-02`, `gtr-s1-m01-03`) bugün yok — Ö'ye düşer |

## 5. Sıralama için öneriler (karar motor ekibi ve kurucuda)

1. **A5'i A4'ten önceye ya da paralele almak değerlendirilmeli.** A5 238 dersi (ses kursunun %89'u, kulak kursunun perde dersleri) açarken A4 99 gitar dersini açıyor. Mevcut uygulamada ses için sürekli nota motoru "yalnız bir gerçek ses kaydı bekliyor" durumunda (library.json `voice` notu). Kurucunun "birinci taraf kayıt yok" kararıyla bu doğrulama izinli veriyle (VocalSet, vocadito) yapılmalı.
2. **A3 en çok yük taşıyan adım** (455 ders, 64 bekletilen). Ses, piyano ve kulak kurslarında A3 gecikirse `M!` dersleri için **"perde ölçülür, zamanlama bilgi olarak gösterilir"** ara yedeği önerilir; böylece 64 bekletilen dersin 39'u (ses + piyano + kulak) yalnız perdeyle geçilebilir.
3. **Piyano için en hızlı yol MIDI.** A6 (akustik) gecikirse MIDI'li kullanıcı için 152 piyano dersinin hepsi tam ölçülür; akustik kullanıcı Ö'ye düşer. Mağaza metninde "akustik piyano: tek ses çizgisi; MIDI: tam" ayrımı yazılmalı.
4. **A1 yedeği hazır.** Bugünkü akort kapısı (±20/30 c) A1 derslerini bekletmeden gönderilebilir kılar.
5. **Kamera kritik değil.** 5 dersin hepsi Ö kontrol listesiyle gönderilebilir.

## 6. Daraltılmış yayın senaryoları (bilgi için)

| Senaryo | Hazır adımlar | Tam ölçülü ders | Not |
|---|---|---|---|
| Yalnız gitar + kulak (ritim) | A1–A4 | 232 gitar + 33 kulak = 265 | Ses ve piyano Ö ile gönderilmez; ürün önerisindeki "dar alternatif"ten de dar |
| Brif sırası, A5'e kadar | A1–A5 | 538 | Piyano (152 ölçülü ders) v1.x'e kayarsa "v1 dar alternatif" (~450) ile aynı yapı |
| Tam v1 | A1–A6 (+A6p deneysel) | 674 (+16 deneysel) | — |
