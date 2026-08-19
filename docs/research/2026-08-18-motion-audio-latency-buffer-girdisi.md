# Ostinato → `packages/motion_audio/` — latency/buffer gereksinim girdisi

**Tarih:** 2026-08-18 · **Yazar:** OSTINATO proje oturumu (PREP hattı) · **Hedef:** MOTION-CORE oturumu, **Motion Orchestration üzerinden** iletilir (proje↔proje direkt mesaj protokolde YASAK).
**Amaç:** `02-MOTION-AILESI-ORKESTRASYON.md` §6.2'nin tanımladığı ortak `motion_audio` paketi ("Mic/MIDI stream, latency calibration, pitch/onset/chord primitives ve transient buffer") henüz yazılmadı. Bu not, Ostinato'nun kendi roadmap'inden (`23-OSTINATO-MASTER-ROADMAP.md` §7 + §11) türeyen **sayısal ve davranışsal gereksinimleri** tek yerde toplar — paketin İLK API tasarımına girdi olsun diye. **Enstrüman müfredatı/içerik YOK** (aile kuralı: "Yasak: Enstrüman müfredatı" — bu satır bilerek dışarıda tutuldu).

---

## 1. Sayısal eşikler (Ostinato roadmap §11, ölçüm birimi motion_audio'nun kendi çıktısı olmalı)

| Eşik | Değer | Not |
|---|---|---|
| Mic permission → ilk geçerli pitch | p95 ≤ 2 sn | Kalibrasyon dahil uçtan-uca |
| Monophonic pitch hatası | medyan ≤10 cent, p90 ≤20 cent | Desteklenen aralık İÇİNDE |
| Onset zamanlama hatası | speaker/wired medyan ≤30ms; **kalibre edilmiş Bluetooth ≤60ms** | BT için kalibrasyon ÖNCESİ skor YOK (aşağıya bkz.) |
| Chord doğruluğu | ≥%90 (major/minor triad) | 3 ayrı SNR koşulunda AYRI raporlanmalı — tek ortalama YETMEZ |
| MIDI zamanlama | not %100 (test fixture), timestamp p95 ≤10ms | USB + BLE MIDI ikisi de |
| Yanlış-hüküm oranı (gürültü/desteklenmeyen girdi) | ≤%1 | Kalan durum SESSİZCE atlanmaz, isimli `unsupported` döner |
| Audio callback underrun | 20 dakikada SIFIR | — |
| Audio→görsel feedback gecikmesi | p95 ≤150ms | — |
| Audio→sesli-koç feedback gecikmesi | p95 ≤300ms | — |
| Oturum sonu dosya kalıntısı | raw PCM/video/landmark SIFIR | Ring buffer RAM-only, zeroize/clear |

## 2. Davranışsal sözleşme (Ostinato roadmap §7)

1. **Ring buffer RAM'de** — session exit / permission revoke / background geçişinde SIFIRLANIR (dosyaya yazılmaz).
2. **Sample-rate veya route (kablolu↔BT↔hoparlör) değişimi → session state otomatik `calibration`a döner.** Bu, motion_audio'nun state machine'inin dışa açık bir hâli olmalı — Ostinato kendi UI'sinde "yeniden kalibre ediliyor" göstermek için bu sinyali dinleyecek.
3. **Bluetooth latency ÖLÇÜLMEDEN timing score verilmez.** Yani API, "BT bağlı ama latency henüz kalibre edilmedi" durumunu `notCalibrated`/`unsupported` gibi isimli bir hâl olarak ayırt etmeli — sessizce yanlış skor DÖNMEMELİ.
4. **Noise floor yüksekse pitch/chord hükmü verilmez** — güven kapısı motion_audio seviyesinde olmalı (Ostinato'nun kendi `AudioConfidenceGate`i zaten var, `packages/ostinato_audio` — bunun motion_audio'ya nasıl taşınacağı/eşleneceği ayrı bir tasarım sorusu, bu not yalnız EŞİK değerlerini taşıyor).
5. **Monophonic detector, polyphonic girdide isimli `unsupported` döner** — en yakın notayı TAHMİN ETMEZ.
6. **Chord detector yalnız desteklenen chord class'ları tanır**, nota-nota transkripsiyon iddiası YOK.
7. **MIDI event'i** (timestamp, note, velocity, channel) yalnız local session'a gider; **cihaz kimliği (device ID) analitiğe gitmez** (aile telemetry sözleşmesi, 02 §8.4).

## 3. Neden bu şimdi geliyor — Ostinato tarafındaki somut baskı

Bu oturumun `library.json` envanterinde (`workspace/DEFTER.md` O-171) **6 ders bu eşiklerin YOKLUĞU yüzünden kilitli** çıktı — en somutu `guitar.strum_timing`: "altı yakın-eşzamanlı atağı tek akor olayına eşleyen adım YOK" + "öğretmen zaman-toleransı verisi YOK". `packages/ostinato_audio` bugün bu primitifleri (pitch/onset/chord/MIDI) **kendi içinde, motion_audio'dan bağımsız** olarak üretim kalitesinde uyguluyor (30/30 test yeşil, 2026-07-29'dan beri) — yani mühendislik ZATEN var, soru **hangi kısmın ortak pakete taşınacağı**. Bu not o taşıma kararını vermiyor, yalnız Ostinato'nun tüketici olarak neye ihtiyaç duyacağını sayısallaştırıyor.

## 4. Bilerek dışarıda bırakılanlar

- Ostinato'nun enstrüman-özel nota aralıkları, egzersiz içerikleri, akor kütüphanesi — bunlar `config/instruments.v1.json` + `config/rulesets/*.json`'da kalır, core'a taşınmaz (aile kuralı).
- `packages/ostinato_audio`'nun mevcut kodunun motion_audio'ya nasıl migrate edileceği — bu bir MOTION-CORE + Ostinato ortak WRITE-lane kararı, PREP notunun kapsamı dışında.
- Golden fixture kaynak/lisans sorusu ayrı notta: `docs/research/2026-08-18-w1-audio-golden-fixture-kaynaklari.md`.
