# Ostinato — Ürün Yol Haritası (G0→G10)

**Tarih:** 2026-07-26 · **Statü:** Kurucu-onaylı çerçeve; oturumlar bu haritayı işler, sapmalar DEFTER'e.
**Hiyerarşi:** `00-AILE-MIMARISI.md` (D3: 3-5× efor sınıfı; B2B sinyalsiz derin yatırım YOK) > `20-URETIM-SURECI.md` > `10-ARAC-KATALOGU.md` > bu dosya > `ostinato-plan.md`.
**Ürün dili: İNGİLİZCE.** Aile sırası **4** — V0'ı KOD DEĞİL: veri protokolü + öğretmen kanalı doğrulaması.

> ⚡ **REVİZYON 2026-07-26 (kurucu direktifi — KURUCUSUZ VERİ FABRİKASI + GENİŞ KÜTÜPHANE, M-F-13..16):** Bu haritadaki "kurucu çekimi / fixture çekim listesi kurucuya" varsayımları KALDIRILDI — kurucu çekim YAPMAZ. Birincil veri = kamu-video hasadı + sentetik + gerekirse ücretli klip (katalog §6.2); doğrulama = §6.3 merdiveni; öğretim görselleri = §6.4 katmanlı AI-eğitmen hattı (T1 = iskelet-sürümlü uygulama-içi avatar, $0 ve form-garantili). Kurucudan yalnız cihaz-benchmark'ı + onay/kapı kararları beklenir. **Geniş kütüphane:** Çello derin + keman/gitar/piyano ön-hasadı; İLK ADIM kamera-açı triyajı (CelloBello+tonebase-free'den 30-50 aday video elle etiketle); pilot çekim yerine kamu-video pilotu (ReferenceBuilder); nesne-algılama EĞİTİM verisi OK-8 rejiminde kalır (öğretmen-pilot gönüllüleri; kurucu çekimi değil); cihaz-benchmark kurucuda. Sorularını bu çerçevede kendin karara bağla — kurucuya soru YOK.

## 1. Kimlik ve Kuzey Yıldızı

**Ostinato: Music Practice** — öğretmenin yanında olmadığı pratik saatlerinde kamera+mikrofon seni izlesin: postür, yay tekniği, zamanlama; kısa düzeltme versin; ilerlemeni öğretmenle paylaşılabilir yapsın. **Marka TÜM çalgılara açık (§1.1); V1 motoru çello** — mimari enstrüman-bağımsız (pose+hand+audio+öğretmen akışı ortak; çello modülü tak-çıkar).
**Kuzey Yıldızı:** haftalık aktif pratik oturumu / öğrenci (pratik alışkanlık kanıtı). İkincil: öğretmen-paylaşım kullanım oranı (B2B kanalı sinyali), geçerli-analiz oranı.
**Fark:** kamera+ses BİRLEŞİK koçluk — pazarda YOK (Trala keman/yalnız-ses; Yousician strings'te sığ; SmartMusic ses-tek kurum ürünü; postür yapan rakip bulunamadı).

## 2. Konumlandırma ve rakip boşluğu (kanıtlı)

| Rakip | Ne yapıyor | Boşluk |
|---|---|---|
| Trala ($9.99/ay) | Keman, gerçek-zamanlı pitch dinleme | Çello yok; kamera yok — kendi yorumcuları "bowing/postür veremiyor" diyor |
| Yousician ($14.99-19.99/ay) | Çok-çalgı gamified; keman sığ | Çello çekirdek değil; kamera yok; family-plan emsali (1.5×) |
| Simply ailesi ($17.90/ay) | Piyano/gitar; strings yalnız tuner | Bundle emsali (1.24×); strings koçluğu yok |
| SmartMusic | Kurumsal nota-doğruluk skorlama | Okul pazarı; postür yok — "yeterli-iyi ses değerlendirmesi" çıtası |
| Tonara / Modacity | Pratik takip/yansıtma | Otomatik teknik değerlendirme yok |
**Konumlandırma (EN):** *"The practice companion your teacher wishes you had — posture, bowing and timing feedback between lessons, on your phone, shareable with your teacher."* B2B açısı: öğretmen/müzik okulu kanalı = savunulabilir taraf (plan §11).

## 3. Teknik mimari kararları

- Katmanlar (plan §5): pose + hand (MediaPipe Pose+Hand — kombine kare maliyeti V0'da benchmark ZORUNLU, katalog §1) + enstrüman/yay algılama (MediaPipe Object Detector + Model Maker; yay = 2-keypoint uç+topuk hattı; erhu araştırması metodoloji şablonu — katalog §3) + ses analizi + senkron + kural motoru.
- **Ses hattı (katalog §4, lisans-kritik):** iOS AudioKit (MIT); Android kendi YIN/pYIN (Kotlin/C++) VEYA SwiftF0 pilotu (lisans doğrula + çello C2≈65Hz aralık testi). ❌ aubio/TarsosDSP/Essentia (GPL/AGPL). Tempo/metronom: SoundTouch (LGPL-dinamik) veya kendi hizalayıcı. V1'de tam transkripsiyon YOK — onset/tempo/sustain/perde-sınıfı yeter (plan §7).
- **Tek saat:** audio+motion aynı monotonic clock — senkron çıkarımların temeli ("yay yönü değişti + ses kesildi + dirsek düştü" birleşik bulgusu).
- Geri bildirim: müzik akışını bozmayan kanallar — egzersiz-sonrası özet öncelik; nota-arası kısa ses/görsel/haptic seçenekleri (plan §10).
- Kamera açısı: V1 TEK standart açı (hafif sağ-ön çapraz, plan §6.4); Setup Check modu bu açıyı kurduran sihirbaz.
- **Çocuk verisi rejimi (bağlayıcı, plan §13):** ebeveyn izni, saklamama varsayılanı, model-eğitimi ayrı rıza, yüz-tanıma yok, silme+saklama-süresi görünür. Tasarım her fazda privacy-first.
- Öğretmen katmanı V1: **shareable session report** (panel sonraki faz).

## 4. Faz planı

### G0 — Derin araştırma & bilgi kütüphanesi
1. `audio-dsp` danışmanını YARAT (önce-katalog; pitch/onset/tempo + mobil DSP) → ROSTER/AGENTS güncelle.
2. Rakipleri elle doğrula: Trala/Yousician/Simply güncel çalgı listeleri + fiyatlar store'dan; "kamera yapan var mı" canlı taraması (iddiayı yayınlamadan önce zorunlu — araştırma notu).
3. Çello pedagojisi kütüphanesi: başlangıç tekniği müfredatı (setup→açık tel→uzun yay→yay değişimi→sol el temeli), öğretmenlerin gerçek hata-taksonomisi, tolerans mantıkları — çello öğretmeni doğrulama ihtiyacıyla. `movement-science-advisor` postür kuralları ilk-geçişi.
4. Lisans yazışmaları: URMP ticari izin (bochen.li@rochester.edu) + SwiftF0 LICENSE + SoundTouch bağlama planı.

### G1 — V0 kapısı (D3 — KOD DEĞİL; iki paralel iş)
**A. Veri toplama protokolü tasarımı:** çekim planı (çello boyları, yaylar, kıyafet, sandalye, ışık, çocuk/yetişkin, doğru+hatalı teknik, cihazlar, arka plan çizgileri — plan §12 çeşitlilik matrisi), etiket şeması (bbox/keypoint/faz/hata/uzman-güveni), rıza formu taslakları (yetişkin + ebeveyn), saklama/silme politikası.
**B. Öğretmen/B2B kanal doğrulama paketi:** 5-10 çello öğretmeni görüşmesi için kılavuz (sorular: yalnız-pratik hataları, mevcut araçlar, paylaşım-rapor değeri, ödeme istekliliği), tek-sayfa değer önerisi (EN+TR), sinyal ölçütleri (kaç öğretmen "kullanırım/öderim" derse derin yatırım açılır — eşik önerisi kurucuya).
**C. Teknik ön-ölçüm (kod değil, mevcut araçlarla):** pose+hand kombine fps benchmark'ı (örnek MediaPipe demo app'leriyle) + pitch kütüphanesi kısa değerlendirmesi (AudioKit tuner örneğiyle çello kaydında).
**Kapı çıktısı (kurucuya):** protokol + görüşme paketi + ön-ölçüm raporu. **Derin yatırım kararı B2B sinyaline bağlı** — sinyal zayıfsa Ostinato bekletilir, aile kaynağı diğer app'lere döner (D3 hükmü).

### G2 — PRD + teknik tasarım (B2B sinyali onaylıysa)
Modlar (Setup Check / Technique Drill / Guided Practice / Review / Teacher Share — plan §4), veri modeli (plan §15), enstrüman-bağımsız çekirdek ↔ çello modülü sınır çizgisi (00-AILE-MIMARISI: nesne algılama+ses OSTINATO'ya aittir, core'a sızmaz), senkron mimarisi ADR'i, çocuk-rejimi veri akış şeması.

### G3 — Veri & fixture kütüphanesi (en ağır faz — D3'ün özü)
1. **Ses fixture'ları ÖNCE** (kameradan bağımsız yeşile çekilir): açık-tel kayıtları (doğru/kesik/tempo-kaçık), metronom-hizalama senaryoları, pitch doğruluk referansları.
2. Görüntü veri seti: protokole göre çekimler (kurucu + gönüllü öğrenciler; okul işbirliği manuel listeye) → etiketleme → çello/yay/el algılama eğitim seti; Model Maker transfer-learning turları + dürüst eval (`data-ml-engineer`: time-split, out-of-sample — BF dersi).
3. Teknik fixture'ları: doğru uzun yay + eğik yay + kısa-yay + omuz yükselmesi + bilek kırılması + yay kaybı + ses kesilmesi (plan §16).

### G4 — Motor inşası
Ses motoru (pitch/onset/tempo/metronom-uyum) → nesne algılama entegrasyonu (yay 2-keypoint takip + güven kapısı: enstrüman algılanmadan teknik hüküm YOK) → bowing state-machine (READY→BOW_CONTACT→DOWN_BOW→DIRECTION_CHANGE→UP_BOW→COMPLETE; bow path deviation, paralellik açısı, yay bölgesi kullanımı, değişim pürüzsüzlüğü) → postür kuralları (oturuş, omuz simetrisi, sol bilek) → audio-motion füzyon bulguları → geri bildirim + Review özeti.
**Kapı:** ses motoru + görüntü motoru AYRI AYRI fixture-yeşil, sonra füzyon testleri; "en az 5 güvenilir teknik geri bildirim" kanıtlı.

### G5 — İskelet uygulama (alpha, İngilizce)
Modların cilasız akışları; Guided Practice ekranı (metronom + canlı durum); Review raporu; Teacher Share (rapor dışa aktarımı). Platform stratejisi: plan §19 gereği tek platform önce kabul — **iPad/iOS önce** (AudioKit avantajı + müzik eğitimi pazarında iPad yaygınlığı), Android ardıl.

### G6 — İçerik üretimi
Egzersiz kütüphanesi (açık tel → basit gam; her egzersiz: video/nota/metronom/tolerans/değerlendirme kuralı — plan §14 içerik riski bilinçli yönetilir: V1 DAR ama derin) · sesli koç replikleri (EN; müziği bozmama ilkesiyle az-ve-öz; ~200-300 satır) · öğretmen rapor şablonu. Çello öğretmeni doğrulaması ZORUNLU (her hata en az bir profesyonelce onaylı — plan §16).

### G7 — UI giydirme (Claude Design)
"Müzik stüdyosu" estetiği: sahne sakinliği, nota/timeline görselleştirmesi, Review raporu = vitrin. Token + polish turu.

### G8 — Sertleştirme
Pose+hand+audio eşzamanlı yükün termal/pil profili (ailenin en ağır runtime'ı) · mikrofon kalite değişkenliği testi · a11y · analytics (geçerli-analiz oranı, paylaşım oranı) · offline temel akış.

### G9 — Monetizasyon + uyum
Model önerisi: bireysel abonelik (katalog §8 koridoru; Trala/Yousician emsalleri) + öğretmen kanalı için erken B2B teklifi (okul lisansı) taslağı → kurucu. IAP sandbox + Opus. Uyum: **çocuk verisi denetimi en ağır tur** — `privacy-data-guardian` ERKEN (G2'den itibaren), submit öncesi tam tur + `store-policy-officer` (Apple çocuk/veli kuralları, ses kaydı beyanları).

### G10 — Pazarlama & lansman
ASO: "cello practice, music practice coach, learn cello" + öğretmen-yönlü içerik pazarlaması (B2B kanal: öğretmen anlatısı, stüdyo pilotları). Ekran görüntüsü anlatısı: kur→çal→postür+ses bulgusu→Review→öğretmenle paylaş. Lansman: önce öğretmen-pilotlu soft launch (5-10 stüdyo), sonra genel. Submission kurucu.

## 5. Riskler / DEFTER tohumları
O-001 (mevcut): D3 efor sınıfı. Yeni: O-002 yay-takibi fizibilitesi (ince/hızlı nesne — erhu emsali cihaz-üstü kanıt DEĞİL) · O-003 pitch kütüphanesi lisans/aralık doğrulaması · O-004 çocuk-verisi uyum yükü · O-005 içerik-üretim maliyeti (egzersiz başına 5 bileşen) · O-006 niş pazar / B2B bağımlılığı.

## 6. Manuel / kurucu görevleri
Öğretmen görüşmeleri (paket G1'de hazır) · çello çekimleri için öğrenci/okul erişimi · URMP izin maili · çello öğretmeni doğrulama anlaşması · voice-pack + olası SwiftF0/SoundTouch hukuk kontrolü · fiyat/B2B teklif onayı · submission · domain (getostinato.app $9.99 — M-006).

## 7. Oturum örgütlenmesi
Fable/high; `audio-dsp` (yaratılacak) + `motion-cv-engineer` + `data-ml-engineer`; fan-out sonnet; çocuk-verisi/IAP Opus doğrulamalı; /loop. Başlangıç promptu: vault `🚀 Başlangıç Promptu — Ostinato`.
