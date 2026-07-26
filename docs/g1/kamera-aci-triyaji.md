# Ostinato — Kamera-Açı Triyajı Raporu (v1)

**Tarih:** 2026-07-26 · **Direktif:** M-F-13 (kurucusuz veri fabrikası) — kamu-video pilotunun İLK ADIMI. **Yöntem:** 6-ajan web toplama (tonebase-free · CelloBello · YouTube EN×2 · TR · kanal envanterleri) → 57 YouTube adayı → mqdefault thumbnail kontakt-föyleri → **elle görsel etiketleme (57/57)**. Provenance: `../data/harvest/cello-triage.v1.json`.
**Dürüstlük şerhi:** Triyaj THUMBNAIL üzerindendir; thumbnail ≠ video karesi (özellikle başlık-kartı olanlar). Nihai kullanılabilirlik ReferenceBuilder çıkarımı anında kare-düzeyinde teyit edilir — bu rapor ilk eleme + oran tahminidir.

## 1. Sonuç sayıları

| Hüküm | Adet | Oran | Tanım |
|---|---|---|---|
| **A-aday** | **4** | **%7** | Sağ-ön çapraz görünümlü + tam üst-gövde+yay (bizim standart açı) |
| Şartlı | 27 | %47 | Kadraj TAM ama açı ön/sol-ön (B/C) — açı-duyarlılık kolu (pilot B4) + postür referansı adayı |
| Kullanılamaz | 14 | %25 | Dar kadraj / baş kırpık / el yakın-çekimi / dikey-shorts |
| Belirsiz | 12 | %21 | Thumbnail başlık-kartı; video-içi kadraj bilinmiyor (TR birincil aday Bora Erdoğan serisi BURADA — kare kontrolü şart) |

**Kullanılabilir-oran okuması:** Sıkı-A oranı düşük (%7) — öğretim videoları ezici çoğunlukla ÖN/SOL-ÖN çekiliyor (izleyiciye yüz dönük anlatım doğası). A+şartlı birleşik %54: malzeme BOL ama bizim açıda DEĞİL.

## 2. A-aday listesi (ReferenceBuilder pilotunun çekirdek girdisi)

| # | Video | Eğitmen/Kanal | Not |
|---|---|---|---|
| 20 | `WyV8b6Dw1Cw` Bow Grip & Arm Weight | **Alisa Weilerstein** (CelloBello röportaj serisi) | Dünya-sınıfı icracı; röportaj formatı — çalma kesitleri seçilmeli |
| 40 | `omDtTuWTNAA` bow demonstration & troubleshooting | AdultCello ("Cello in 30 Days" masterclass kesiti) | Gösterim-ağırlıklı |
| 48 | `37WtvwyTZXY` How to Hold and Sit | Olga Celli (olası) | Geniş plan, tam vücut |
| 56 | `NOjAhoEluQw` Yeni Başlayanlar İçin Çello Dersi | Rapsodi Sanat (TR; eğitmen adı doğrulanamadı) | TR bacağı A-adayı |

4 bağımsız kaynak = pilot B1 ölçütü (≥3 eğitmen) İLK BAKIŞTA karşılanabilir — kare-düzeyi teyit şartıyla. Belirsiz sınıfından (özellikle Bora Erdoğan 1-2) kare kontrolüyle A'ya terfi olasılığı var.

## 3. O-012'ye etki (açı fizibilite riski — ÖN-VERİ)

1. **Sıkı-A kıtlığı doğrulandı:** referans hattı yalnız-A ile beslenemez; pilot tasarımındaki B4 (açı-duyarlılık ölçümü) artık YAN kol değil ANA kol — B/C-açılı 27 şartlı videodan açı-normalizasyon toleransı ölçülmeden kamu-video stratejisinin çello için verimi bilinemez.
2. Alternatif güçlendirici (pilot planına eklendi): şartlı sınıfın bir kısmı POSTÜR referansı için açı-toleranslı olabilir (gövde/omuz metrikleri sagittal hassasiyeti düşük — Lissom A5 bulgusuyla tutarlı beklenti); yay-paralellik referansı ise açıya en duyarlı olan — pilotta metrik-başına açı-duyarlılık ayrıştırılacak.
3. Shorts/yakın-çekim formatı (%25) hasat rig'inde otomatik elenmeli (süre + en-boy oranı + tek-sahne filtreleri) — koordinatörün rig kuyruğuna girdi (M-O-02 notu olarak iletilecek).

## 4. Kanal envanteri (hasat çapaları — M-F-13 geniş kütüphane)

`../data/harvest/harvest_channels.json`: **çello-derin 10 kanal** (tonebase Cello 390 video · CelloBello · Cello Professor/Fiste · AdultCello · Ailbhe McDonagh · TR: Rapsodi Sanat, Bora Erdoğan vb.) + **geniş çapalar 20 kanal** (keman/gitar/piyano ders-gösterimi zengin kanallar — motor sonra, envanter hazır). YouTube-dışı 2 tonebase site-dersi (e-posta-kilitli) ayrı dosyada.

## 5. Sonraki adımlar

1. Kare-düzeyi teyit (çıkarım öncesi): A-aday 4 + belirsiz-terfi adayları → gerçek video karelerinde açı/kadraj doğrulaması (hasat rig'i veya elle; koordinatör rig'i beklenirse elle 6-8 video yeterli).
2. ReferenceBuilder pilotu (plan: `../g3-prep/referencebuilder-pilot-plan.md`) girdi listesi bu rapora bağlandı; B4 açı-duyarlılık kolu ANA kol yapıldı.
3. Provenance zinciri: her seçilen video için `{URL, eğitmen, açı-sınıfı, kesit-timestamp, lisans-bağlamı}` çıkarım anında JSON'a işlenir (M-F-07).
