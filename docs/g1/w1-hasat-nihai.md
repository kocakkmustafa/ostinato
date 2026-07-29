# W1 Hasadı — Nihai Rapor (tur 1)

**Tarih:** 2026-07-29 · **Koşum:** 55 aday → 50 manifest · **Kabul 30 (%60)** · red 20
**Depo:** `~/motion-harvest/ostinato/` (M-F-26: ham hasat repoya girmez)

## 1. Çalgı-başına sonuç ve kendi hedefime göre durum

Hedef (`config/triage-thresholds.w1.json §acceptanceTargets`, **ölçümden önce yazıldı**): çalgı başına **≥12 kabul**.

| Çalgı | Aday | Kabul | Oran | Hedef ≥12 |
|---|---|---|---|---|
| Gitar | 22 | **15** | %68 | ✅ |
| Piyano | 19 | **10** | %53 | ❌ 2 eksik |
| Şan | 14 | **5** | %36 | ❌ 7 eksik |

## 2. Şan neden en zayıf — ve bu benim kendi kararımın sonucu

Şanın kabul oranı en düşük (%36) ve bu bir tesadüf değil: **şan profilinde `min_upper_body_ratio` 0.75 ile en sert eşiği ben koydum.** Gerekçesi hâlâ geçerli (şanda ölçtüğümüz her şey üst gövdede: baş-omuz hizası, çene, omuz yükselmesi — kadraj kararsızsa video referans olamaz). Ama sonuç şu: **en sert kapıyı en küçük aday havuzuna uygulamışım.**

Kendi kuralım ne diyor (aynı dosyada, ölçümden önce yazılmış): *"Havuzu genişlet — eşik GEVŞETİLMEZ. İki tur sonunda hâlâ altındaysa o çalgı için 'referans yetersiz' kaydı DEFTER'e ve o metrik V1'de kapalı kalır."*

→ **Karar: eşik gevşetilmiyor, şan havuzu 2. tura giriyor.** Gevşetmek, kabul oranını rakamla düzeltip veriyi bozmak olurdu — bulanık/kadrajsız kaynaktan çıkan landmark sessizce gürültülü referans üretir.

## 3. Red sebepleri (20 red)

| Sebep | Adet | Not |
|---|---|---|
| üst-gövde oranı düşük | 5 | 3'ü 0.17 (el/enstrüman yakın çekimi) — el havuzuna aday |
| netlik | 4 | düşük bit-hızlı/yeniden-kodlanmış yüklemeler |
| **dikey format (608x1080)** | 2 | shorts — rig `require_landscape` ile yakaladı |
| diğer/karma | 9 | — |

İkinci geçiş (`piano_hands`/`guitar_hands` profilleri) koştu ama **yeni kabul üretmedi**: üst-gövdeden elenen klipler el havuzunun netlik eşiğini (60) geçemedi. Yani el-yakın çekimler hem kadrajı dar **hem de** düşük çözünürlüklü olma eğiliminde — bu, el metriklerinin veri temelinin sanılandan zayıf olduğu anlamına geliyor (DEFTER'e).

## 4. Pilot sonuçları (tam havuzla)

| Çalgı | n | trunk_tilt | Güvenilmez eklemler |
|---|---|---|---|
| Şan | 5 | **1.5°** | right_elbow, left_forearm, right_forearm |
| Piyano | 10 | **5.1°** | **yok** |
| Gitar | 15 | **3.6°** | left_elbow, left_forearm |

`trunk_tilt` üç çalgıda da en sıkı metrik olmayı sürdürüyor (1.5-5.1°) — W1'in omurgası. Kol metrikleri çalgıya göre ayrışıyor ve sebepleri farklı (M-O-09, M-O-12).

## 5. Sıradaki iş
1. **Şan havuzu tur 2** (7 kabul eksik): yeni arama terimleri + kanal-başına ≤2 kuralı korunarak; hedef tutmazsa "referans yetersiz" kaydı ve şan postür metriklerinin V1'de kapalı kalması.
2. Piyano tur 2 (2 kabul eksik) — düşük öncelik, hedefe yakın.
3. El havuzunun netlik gerçeği (yeni bulgu) → el metrikleri için ayrı kaynak stratejisi gerekebilir.
