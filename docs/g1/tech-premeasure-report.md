# Ostinato G1-C — Teknik Ön-Ölçüm Raporu (v1)

**Tarih:** 2026-07-26 · **Statü:** Ses bacağı ÖLÇÜLDÜ; kamera bacağı protokol+cihaz-bekliyor (D3 kapı çıktısının C parçası)
**Kapsam:** Kod-değil ilkesine uygun: mevcut araçlarla (Python analiz ortamı, yayınlanmış kütüphaneler, lisans-temiz kayıtlar) ön-fizibilite. Üretim kodu YOK; ölçüm scriptleri scratchpad'de (atılabilir).

---

## 1. Pitch algılama ön-ölçümü (KAPININ SES YARISI)

### 1.1 Düzenek

- **Adaylar:** YIN ve pYIN (librosa referans implementasyonları — native'de kendimiz yazacağımız algoritma sınıfı) + **SwiftF0** (pip paketi; lisans doğrulaması §3).
- **Katman 1 — sentetik (kusursuz ground-truth):** çello-benzeri harmonik seri (fundamental KASITLI baskın değil — gövde rezonansı gerçeği), 120ms yay-atağı rampası, hafif yay gürültüsü; koşullar: temiz · vibrato (±15¢, 5.5Hz) · SNR10 gürültü · **120Hz highpass** (ucuz telefon mikrofonu simülasyonu — C2 fundamentalini zayıflatır) · highpass+SNR10. 4 açık tel (C2=65.41 · G2=98.00 · D3=146.83 · A3=220.00 Hz), 44.1kHz ve 16kHz, pencere 1024-4096.
- **Katman 2 — gerçek kayıt:** University of Iowa MIS 2012 çello arco ff kromatik dizileri (lisans: kurumun "without restrictions" beyanı — G0 doğrulaması), 4 tel × 12 nota = 48 segment; clean + hp120 varyantları. Ground-truth = kromatik dizi eşlemesi (segmentasyon highpass sinyal üzerinden — düşük-frekans oda gürültüsü bölücüyü şaşırtıyor, ölçüm sırasında yakalanan gerçek ders).

### 1.2 Sonuçlar

**Sentetik (120 koşul-satırı):** TÜM algoritma×koşul kombinasyonlarında **oktav hatası %0**; medyan |cent| ≤10¢ (en kötü satır: YIN 44.1k/2048 vibrato 9.8¢ med, 16.4¢ p95). Highpass+SNR10'da bile C2 doğru. 16kHz downsample kayıpsız (SwiftF0'ın iç örnekleme hızı — sorun değil).

**Gerçek çello (Iowa, 48 segment/varyant; attack/release kırpılmış, medyan-üstü değerlendirme):**

| Algoritma | Varyant | Med \|¢\| | p95 \|¢\| | Segment-oktav | Not |
|---|---|---|---|---|---|
| YIN | clean | 14.9 | 44.5 | %0 | rtf≈0.003 (masaüstü) |
| YIN | hp120 | 19.2 | 53.6 | %0 | |
| pYIN | clean | 15.0 | 45.0 | **%2.1 (1/48: açık C2 → +1 oktav)** | HMM oktav-kilidi vakası |
| pYIN | hp120 | 15.0 | 53.5 | %0 | |
| SwiftF0 | clean | **12.7** | 51.0 | %0 | rtf≈0.0075; en isabetli |
| SwiftF0 | hp120 | 15.4 | 53.4 | %0 | |

Yorum dürüstlüğü: gerçek-kayıt "hatası" insan icrasının kendi entonasyon sapmasını + vibrato'yu da içerir — bu sayılar algoritma hatasının ÜST sınırıdır. pYIN'in açık-C2 oktav kilidi tek vakadır ama V1'in EN önemli notasında — **beklenen-nota önseli** (egzersiz belli → aday F0 kümesi dar) tasarım zorunluluğunun doğrudan kanıtı (reference §3 ile tutarlı).

### 1.3 Kapı değerlendirmesi

Eşikler: medyan |¢| ≤25 (çeyrek yarım-ton) · segment-oktav ≤%5 (önselsiz) · p95 ≤60¢. **Sonuç: her üç aday da her koşulda eşiklerin İÇİNDE → SES BACAĞI: ŞARTLI GEÇTİ** (gece protokolü; kurucu onayı sabah retrospektif).
⚠️ Dürüstlük notu (DEFTER O-007): eşikler ölçüm analiziyle AYNI oturumda yazıldı (ideali: ölçümden önce ayrı kayıt). Marj o kadar geniş ki (13-19¢ vs 25¢ eşik; %0-2 vs %5) makul hiçbir eşik seçimi sonucu değiştirmez — yine de süreç kusuru olarak kayıtlıdır, sonraki kapılarda eşik ÖNCE yazılacak.

### 1.4 Kalan ses riskleri (G3'e devreden)

- pp/hafif dinamikler, acemi cızırtılı ton, oda yankısı + uzak mikrofon GERÇEK kayıtla test edilmedi (Iowa = stüdyo + profesyonel icracı + ff). Kendi çekimlerimiz (G1-A protokolü) bu boşluğu kapatır.
- Mobil CPU/gecikme ölçülmedi (masaüstü rtf'ler yalnız sıralama bilgisi verir). Native implementasyon sonrası cihazda ölçülür.
- SwiftF0 → mobil: resmî iOS/Android/CoreML/TFLite export YOK (yalnız Python+WASM); ONNX modeli ~389KB → ONNX Runtime Mobile/CoreML dönüşümü bizim işimiz olur. Pilot değeri yüksek, bağımlılık riski (tek-yazar, 3 issue, release-tag'siz) DEFTER'de.

## 2. Pose+Hand kombine fps ön-ölçümü (KAPININ KAMERA YARISI — CİHAZ BEKLİYOR)

Gerçek cihaz gerektirir; bu oturumda dürüst ölçüm mümkün değil (simülatör temsil etmez — katalog §1 kuralı: "kendi cihaz matrisimizde ölçmeden eşiğe taahhüt yok").

**Hazırlanan protokol (kurucu ~30-45dk):**
1. iPhone: MediaPipe resmî iOS örnekleri — `mediapipe-samples` reposundan Pose Landmarker + Hand Landmarker örnek app'leri (Xcode, gerçek cihaz). Önce ayrı ayrı fps oku (ekranda gösteriyor), sonra kombine maliyet için Pose örneğine Hand task'ı eklemek KOD gerektirir → V0'da vekil ölçüm: iki örneği ardışık koş, kare-başına süreleri topla (üst-sınır tahmini; gerçek kombine maliyet paylaşılan ön-işlemeyle biraz daha iyi olur).
2. Android (orta segment): aynı örneklerin Android sürümleri (Android Studio).
3. Kayıt formatı: cihaz · model varyantı (lite/full/heavy) · tek-task fps · ardışık-toplam tahmini · termal gözlem (10dk sürekli koşumda).
**Eşik önerisi (ölçümden ÖNCE yazıldı):** kombine (pose+hand) efektif ≥15fps orta-segment cihazda → V1 canlı akışı yeterli (state-machine 15fps'te çalışır; overlay zaten ~10-15fps'e desimasyonlu — katalog §2). 10-15fps = "değerlendirme-modu-önce" tasarım; <10fps = mimari revizyon (dönüşümlü task scheduling / tek-task modları) kurucuya.

## 3. SwiftF0 lisans doğrulaması (G0 hattından — kapıya girdi)

- **LICENSE: MIT (Copyright 2025 Lars Nieradzik) — repo'daki ham dosyadan doğrulandı** (G0 canlı doğrulama raporu, `swiftf0` ajanı). Katalog §4'teki "lisans doğrulanmadan benimsenmez" şerhi KAPANDI (benimseme değil, pilot-izni).
- Aralık 46.875-2093.75 Hz → C2 kapsanıyor. İç işleyiş 16kHz/256-hop.
- arXiv 2508.18440 v1 (hakemsiz, yazar-ölçümü); benchmark reposu aynı yazara ait — bağımsız doğrulama bizim ölçümümüz (§1.2: iddiayla tutarlı — en isabetli aday çıktı).

## 4. Sonuç ve kapı durumu (D3 — üç parçanın C'si)

| Parça | Durum |
|---|---|
| G1-A veri protokolü | TASARIM HAZIR (`data-collection-protocol.md`) — kurucu onayı + pilot çekim bekliyor |
| G1-B B2B paketi | HAZIR (`teacher-channel-validation.md`) — görüşmeler kurucu-bacağı; eşik önerisi §4.2 onay bekliyor |
| G1-C ses ön-ölçümü | **ŞARTLI GEÇTİ** (bu rapor §1) |
| G1-C kamera ön-ölçümü | Protokol hazır; cihaz ölçümü kurucu-bacağı (§2) |
| **Derin yatırım kararı** | **AÇILMADI** — B2B sinyali (G1-B görüşmeleri) olmadan açılamaz (D3 hükmü). Ses hattı derin-yatırım SAYILMAZ: kameradan bağımsız, her senaryoda gerekli, riski düşük. |
