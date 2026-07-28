# W1 Triyaj Pilotu — İlk Ölçüm Raporu

**Tarih:** 2026-07-29 · **Hat:** motion-core `tools/harvest_rig` (`--triage-profile` ile, koda dokunulmadı) · **Profiller:** `config/triage/{voice,piano,guitar}.json` (tek kaynak: `config/triage-thresholds.w1.json`)
**Depo:** `~/motion-harvest/ostinato/` — ham video repoya girmez (M-F-26).

## 1. Sonuçlar (5 video, gerçek ölçüm)

| Video | Çalgı | Çözünürlük | Süre | Kesme/dk | Netlik | Üst-gövde | Sonuç |
|---|---|---|---|---|---|---|---|
| `fe57D8HxuvU` | piyano | 1920×1080 | 198s | 0.3 | **293.5** | **0.92** | ✅ kabul → fixture |
| `jog-nfLldRI` | şan | 1920×1080 | 666s | 2.3 | 68.9 | **0.92** | ✅ kabul → fixture |
| `E8Do4oxTJ1k` | piyano | 1920×1080 | 130s | 8.4 | 94.5 | **0.42** | ❌ üst-gövde 0.42 < 0.50 |
| `MHUaLy57dao` | şan | 1920×1080 | 828s | 0.1 | **39.5** | — | ❌ netlik 39.5 < 40 |
| `gld10I5NhCE` | gitar | 1920×1080 | 255s | 8.8 | **36.9** | — | ❌ netlik 36.9 < 50 |
| `apXCNMckvuY` | gitar | 1920×1080 | 214s | — | 213.8 | **1.00** | ✅ kabul → fixture |

**Kabul oranı: 3/6 (%50).** Örneklem küçük — bu bir eğilim işareti, kapı kararı değil. (İlk yazımda 2/5 idi; hata veren gitar adayı yeniden koşumda geçince güncellendi.)

## 2. Ne öğrendik (eşiklerin gerçekle teması)

1. **Netlik eşiği asıl eleyici çıktı** (3 redden 2'si). Öğretim videolarının bir kısmı düşük bit-hızlı/yeniden-kodlanmış yükleniyor; Laplacian varyansı 37-40 bandına düşüyor. **Gitarda 50'ye çıkarmam** (el detayı için) o çalgıda eleyiciliği artırdı — bilinçli bir seçimdi ve etkisi ölçüldü.
2. **Piyanoda "hand-cam vs full-body" ayrımı ölçümle doğrulandı:** `E8Do4oxTJ1k` üst-gövde 0.42 ile elendi — bu tam da öngördüğüm ikinci kadraj sınıfı (üstten el çekimi). Yani eleme doğru çalışıyor ama **o video çöp değil**: el/bilek metrikleri için değerli, duruş için değersiz. Profildeki 0.50 eşiği "duruş havuzu" kapısıdır; el havuzu için ayrı bir geçiş yolu gerekiyor (aşağıda).
3. **Şanda uzun format sorun değil:** 666s ve 828s videolar süre/kesme kapılarını rahat geçti; şanda darboğaz netlik ve kadraj.

## 3. Kararlar (bu ölçümden türetildi)

- **K-T1 — İki havuz, tek profil yetmiyor:** piyano/gitar için `posture` (üst-gövde ≥0.5-0.6) ve `hands` (üst-gövde eşiği YOK, netlik ≥60) diye iki ayrı profil üretilecek. Aynı video iki havuza farklı sonuçla girebilir; hangi metriğin hangi havuzdan beslendiği provenance'a yazılır (J-028'in `measurementSpace` beyanının kardeşi).
- **K-T2 — Netlik eşiği düşürülmeyecek:** kabul oranını yükseltmek için eşik gevşetmek, `triage-thresholds.w1.json` §acceptanceTargets'ta yazdığım kuralın ("altında kalırsa eşik gevşetilmez, havuz genişletilir") ihlali olur. Bulanık kaynaktan çıkarılan landmark, sessizce gürültülü referans üretir.
- **K-T3 — Havuz genişletme muhtemelen gerekli:** 55 adayın %50'si kabul edilirse çalgı başına ~9 kabul çıkar; hedef ≥12. Kalan adaylar koşulduktan sonra açık kalırsa arama terimlerini genişletirim (kanal-başına ≤2 kuralı korunarak).

## 4. Bilinen sınırlar

- `faster-whisper` kurulu değil → transkript aşaması "skipped"; koçluk-dili madenciliği şimdilik yok (hasadın diğer aşamalarını etkilemiyor).
- **Düzeltme (aynı gün):** `apXCNMckvuY` ilk koşumda Traceback verip manifest bırakmamıştı; ilk yorumum "rig garantisinin dışına düşen durum" idi. **Yeniden koşumda sorunsuz geçti** (netlik 213.8, üst-gövde 1.00 → kabul). Yani hata GEÇİCİydi (büyük olasılıkla indirme kaynaklı), rig'de yapısal bir boşluk değil — koordinatöre bildirilecek bir şey yok. Ders: tek koşumluk hatadan mimari sonuç çıkarma; önce tekrarla.
- Örneklem 5 video: oranlar yön gösterir, karar vermez.
