# OSTINATO — Tam Kapsam Blueprint (oturumun kapsam otoritesi)

**Tarih:** 2026-07-28 · **Statü:** KURUCU-ONAYLI (revizyonlu: "daha fazla çalgı" direktifiyle **~35 çalgıya** genişletildi). Ortak omurga: motion-core `docs/30-URUN-BLUEPRINT-STANDARDI.md` (ÖNCE onu oku). D3 hükmü (B2B sinyalsiz derin yatırım yok) çello-derinliği için geçerli kalır; modül-mimarisinin kendisi çok-çalgı hedefiyle kurulur.
**Nihai ürün:** "Music Practice" — kamera(postür/teknik)+ses(pitch/ritim) birleşik pratik koçu; **her çalgı kendi sayfasında** kurslarıyla; modül-tabanlı mimari sayesinde yeni çalgı = çoğunlukla KONFİG, yeni motor değil.

---

## 1. MODÜL MİMARİSİ (kapsamın ölçekleme sırrı — çalgılar modüllere maplenir)

| Modül | Ne yapar | Çalgılar |
|---|---|---|
| **Monofonik pitch** (var: YIN/SwiftF0) | Nota/entonasyon/vibrato/sustain | Şan, tüm yaylılar, tüm nefesliler, bas, mızıka |
| **Akor-sınıfı polifoni** (Basic Pitch, Apache) | "Doğru akor mu?" (nota-nota DEĞİL) | Piyano, gitar, ukulele, banjo, mandolin, harp, pipa |
| **MIDI girişi** (BSD paketler) | Mükemmel nota/zamanlama verisi | Piyano/klavye (opsiyonel yükseltme) |
| **Perküsif onset** (in-house, GPL'siz) | Vuruş zamanlaması/rudiment | Davul(pad), cajon, djembe, bongo/conga; tabla (pitch-bükümlü uzantı) |
| **Yaylı modül** (pose+yay-postürü) | Yay açısı/yolu + oturuş/duruş | Çello, keman, viyola, kontrbas |
| **Nefesli modül** (pitch+artikülasyon+postür; embouchure ASLA) | Ton başlangıç netliği, sustain, duruş | Flüt, sax, klarnet, trompet, trombon (slide-pozisyon durumu!), obua, fagot, blokflüt, tin whistle |
| **Çekme-zither modülü** (YENİ — Dalga B) | Glissando/bükülü-pitch + iki-el koordinasyonu | Guzheng + Koto (paylaşımlı), harp kısmen |
| **RhythmEngine** (paylaşımlı) | Beat-grid + metronom + zamanlama skoru | HEPSİ |

## 2. TAM KAPSAM — dalgalar

**W1 (çekirdek motorlar + en yüksek talep):** **Şan/Vokal** (✅ en temiz; vibrato metriği = Yousician'ın itiraf edilmiş boşluğu) · **Piyano/Klavye** ("akor-sınıfı+postür" dürüst kapsam + **MIDI modu**) · **Gitar** (akustik+elektro; akor şekli el-landmark + akor-sınıfı). Bu üçü ABD ders talebinin ~%87'si.
**W2 (neredeyse bedava eklemeler):** Ukulele · Bas gitar · **Banjo · Mandolin** (gitar fretboard-modülü konfigleri).
**W3 (yaylılar):** Keman → Çello (D3/B2B kapısı burada) → **Viyola** (keman konfigi) → **Kontrbas** (⚠️ yalnız kadraj-mesafe yönergesi).
**W4 (nefesliler):** Flüt → Sax → Klarnet → Trompet → **Trombon** (slide-pozisyon = kameraya EN görünür brass!) → **Obua · Fagot · Blokflüt (okul pazarı!) · Tin whistle** (konfig) → **Korno ⚠️** (el-çanda blind-spot — sınırlı vaatle: yalnız duruş+pitch+ritim, el-tekniği İDDİASIZ).
**W5 (perküsyon):** Davul kiti (V1 tek-pad/trampet rudiment; PAS 40) → **Cajon · Djembe · Bongo/Conga** (onset konfigleri) → **Tabla** (pitch-bükümlü bol uzantısı; Hindistan pazarı).
**W6 (yeni modül, yüksek ROI):** **Guzheng + Koto** (paylaşımlı zither modülü — Çin'de ~10M guzheng öğrencisi iddiası: pazarlama öncesi birincil-kaynak teyidi şart, mühendislik için yeterli sinyal) · **Akordeon** (çift-el+körük modülü) · **Harp** (genişlik-kadraj yönergesi) · **Pipa** (tremolo/lunzhi uzantısı) · Mızıka (bend-dedektörü).
**W7 (bölgesel/niş — SPEKÜLATİF DEĞİL, kanıtlanmış taleple açılır):** Sitar · Oud · **Bağlama/Saz** (TR+diaspora — kurucu pazarı!) · Erhu (⚠️ yeni FSM: dikey tutuş, perdesiz) · Steel pan · Melodika (Japonya okul pazarı) · Shamisen · Charango · Balalaika · **Gayda (YALNIZ practice-chanter** — tam gayda ❌ torba-basıncı ölçülemez).
**❌ Kapsam-dışı ("Neden yok?"):** **DJ/prodüksiyon** (düzeltilecek postür/akustik teknik yok — pose+audio koç tezine uymaz; ayrı ürün fikri olarak DEFTER'e) · org pedalboard'u (ayaklar kadraj-dışı; üst-klavye piyano modülüyle sınırlı olabilir) · embouchure geri bildirimi (fiziksel görünmez — tüm nefeslilerde) · nota-nota polifonik transkripsiyon iddiası.

## 3. Bilgi mimarisi (standart §2'nin Ostinato örneği)
Kütüphane → **Çalgı aileleri** (Klavyeli · Telli-mızraplı · Yaylı · Nefesli · Perküsyon · Ses/Vokal · Dünya çalgıları) → **Çalgı sayfası** (her çalgı: tanıtım + kurulum/kamera açısı rehberi + kurs listesi [Temeller · Teknik · Repertuvar-egzersizleri · Ritim] + seviye haritası [ABRSM/Trinity-esinli, orijinal] + pratik istatistikleri + ölçüm-dürüstlük kutusu ["bu çalgıda neyi duyarız/görürüz, neyi İDDİA ETMEYİZ"]) → Kurs → Pratik seansı (Setup Check → Drill → Guided Practice → Review). Öğretmen-paylaşım raporu her çalgıda.

## 4. Motor iş listesi (sıra)
1. Ses çekirdeği: monofonik pitch (G1-C şartlı-geçti) + RhythmEngine + onset motoru.
2. Akor-sınıfı hattı: Basic Pitch TFLite/CoreML dönüşümü + akor-eşleme post-processor (sürekli çalma değil, sustain-akor vuruşu UX'i).
3. MIDI modu (USB+BLE; "klavyeni bağla" opsiyonel yükseltme).
4. Postür/pose hattı: oturan/ayakta duruş varyantları + çalgı-başına kamera-açısı rehberi; StructuralValidator entegrasyonu.
5. Yaylı modül (çello D3 kapısı sonrası derinleşir; keman/viyola konfigleri hazır bekler) + yay 2-keypoint algılama (OK-8 rejimi).
6. Nefesli modül (artikülasyon-onset + sustain; trombon slide-durumu).
7. Zither/akordeon/tabla modülleri (W6 kapısında; her biri kendi mini-spike'ıyla).

## 5. İçerik hattı
Çalgı-başına ≥3 eğitmen kamu-video konsensüsü (kamera-açı triyajı ilk adım — çello pilotu deseni her çalgıya) + ABRSM/Trinity/RCM/Suzuki/PAS yapıları YALNIZ yapısal esin (müfredat metinleri telifli — orijinal yazım) + method-book gelenekleri referans. Ses referansları: kendi ürettiğimiz egzersiz sesleri (metronom+nota — telif yok). Voice-pack: müziği bozmayan az-ve-öz replikler. Çocuk-verisi rejimi tüm çalgılarda (plan §13).

## 6. Görev backlog'u
**W0:** D3/G1 kapı paketleri (öğretmen görüşmeleri kurucu-bacağı sürüyor — BLOKLAMAZ) + IA çatısı (~35 çalgı sayfası "yakında" durumlu) + platform katmanı + ses çekirdeği.
**W1→W7:** dalga içerikleri; her çalgı: kamera-açı triyajı → referans hasadı → config → kurslar → sweep → DEFTER → vault. W6 öncesi zither/akordeon fizibilite spike'ları (kamera-doğrulama — mimari yargı yetmez, gerçek MediaPipe oturumu).
**Kapanış:** kapsam-tamamlama turu + çalgı-başına dürüstlük kutusu denetimi.

## 7. Ostinato-özel platform deltaları
Öğretmen-paylaşım raporu (iskelet-render — ham video çıkmaz) · MIDI cihaz algılama · akort aleti (tuner) her çalgı sayfasında · metronom/tempo merdiveni · pratik günlüğü + streak · HealthKit YOK (müzik) ama Screen-Time-dostu pratik hatırlatıcıları.

## 8. Dürüstlük/güvenlik (Ostinato-özel)
Nota-nota polifonik transkripsiyon İDDİASI YOK ("akor doğrulama") · embouchure YOK · korno el-tekniği YOK · "3-6 ayda çello" tarzı beklenti-şişirme dili YASAK (O-011) · guzheng/erhu pazar rakamları birincil-kaynak teyidi öncesi pazarlamada kullanılmaz · çocuk-verisi rejimi tavizsiz · ton-kalitesi öznel hükmü verilmez.

## 9. Manuel-sona listesi (kurucu)
Çello öğretmeni görüşmeleri (D3 — paket hazır) · çalgı-aile uzman turları (dalga-sonu) · URMP maili · cihaz-benchmark (G8) · fiyat onayı · voice-pack bütçesi · submission.
