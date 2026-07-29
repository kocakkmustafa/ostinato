# Faz-Config Şeması (M-F-35 taslak v1) — Ostinato Diff'i

**Tarih:** 2026-07-29 · **Kaynak:** motion-core `docs/40-FAZ-CONFIG-SEMASI-TASLAK.md` · **Karşılaştırılan:** `docs/g4-prep/ruleset-v0.md` + çalışan kod `packages/ostinato_audio` (34/34 yeşil).
**Statü:** İtiraz penceresine yanıt. Taslağın dediği gibi *sessizlik = onay* olduğu için susmuyorum: **3 ifade edilemezlik + 3 benimseme** var.

> Bağlam farkı, diff'in kaynağı: taslak üç POSE motorundan (Lissom/JabLab/Gravita) türetildi. Ostinato'nun pratik-oturum akışı faz-makinesi kullanıyor ama girdisi **ses**; ses ölçümleri pose karesinden yapısal olarak farklı (nokta değil aralık, landmark değil sinyal-kalitesi).

## A. Şemanın şu an İFADE EDEMEDİĞİ üç şey

### A1. Ölçümler NOKTA değil ARALIK (P1)
Pose karesi bir ana aittir; bir pitch okuması **pencereye** aittir — ve düşük notada bu pencere kısa değildir: C2'nin periyodu ~15,3 ms, iki periyot şartıyla pencere 46-93 ms (`PitchReading.tStartUs/tEndUs`, kodda mevcut). Şemanın koşul cebiri (`metric`, `delta`, `localMax`) örtük olarak **anlık** değerlendirme varsayıyor.

Bu neden önemli: Ostinato'nun ayırt edici bulgusu füzyon — *"yay yönü değişti **ve** ses kesildi"*. Bu, iki akışın **aralık kesişimi**dir. Aralığı tek noktaya indirgemek (ör. pencere ortası) 46-93 ms'lik bir belirsizliği sıfır sanmak olur ve yanlış-pozitif füzyon bulgusu üretir.

**Öneri:** koşul değerlendirmesi zaman-aralıklı ölçümü kabul etsin; `metric` koşuluna opsiyonel `window: {overlapsPhase|containedInPhase}` semantiği. Alternatif: aralık→nokta indirgemesi ŞEMADA açıkça beyan edilsin (hangi uç: start/mid/end), sessiz varsayım kalmasın.

### A2. `requiredLandmarks` var, `requiredSignals` yok (P1)
Şema tekniğin ön-koşulunu landmark varlığıyla ifade ediyor. Ostinato'nun W1 çalgılarında (Şan/Piyano/Gitar) bir tekniğin ön-koşulu çoğu zaman **sinyal kalitesi**: kalibre edilmiş oda tabanının ≥6 dB üstü seviye, periyodiklik ≥0,55, ve MIDI modunda "cihaz bağlı mı". Bunların hiçbiri landmark değil.

**Öneri:** `requiredSignals?: [...]` kardeş alanı (ör. `audioSnrAboveFloorDb`, `periodicity`, `midiConnected`) — veya `requiredInputs` diye genelleştirilmiş tek alan; landmark bunun bir türü olur. Aksi hâlde ses-öncelikli her app (Ostinato şimdi, Choreia'nın müzik tarafı yarın) ön-koşulunu şema DIŞINDA tutmak zorunda kalır ve doğrulayıcı onu göremez.

### A3. Üç-durumlu kapı ikiye sıkışıyor: **olay-tetikli "hüküm yok" penceresi** (P1)
Şemada `confidence` skaler bir koşul, `measureHere?: bool` ise **faz-yapısal** bir bayrak. Ostinato'nun kapısı üç durumlu (`reliable` / `unreliable` / **`transition`**) ve üçüncüsü faz-yapısal DEĞİL, **olay-tetikli**: nota atağından sonraki ~100 ms aperiyodiktir; orada ölçüm toplanır ama **hüküm verilmez**. Tetikleyici onset olayıdır, fazın kimliği değil — aynı faz içinde defalarca açılıp kapanır.

`transition`ı `unreliable`a katlamak yay değişiminin karelerini çöpe atar; `reliable`a katlamak her yay değişiminde bir düzeltme üretir. İkisi de yanlış.

**Öneri:** faza `noJudgeWindows?: [{ trigger: onset|custom, durationMs }]` — ölçüm akmaya devam eder, hüküm bastırılır. (Bu, JabLab'ın `abort` semantiğinden farklıdır: abort denemeyi bitirir, bu bastırır.)

## B. Şemadan BENİMSEDİKLERİM (ruleset-v0'a giriyor)

| # | Kural | Ostinato karşılığı |
|---|---|---|
| B1 | **Delta saniye-başına, kare-başına YASAK** (L-069/L-070) | ✅ **Zaten uyumluyum ve kanıtladım**: kodda kare-başına delta yok (grep temiz); ses hattı pencere+`Us` tabanlı. Kuralı ruleset'e yazıyorum ki gelecekteki postür metrikleri de bağlansın |
| B2 | **Filtre + eşik BİRLİKTE pinlenir** (M-C-07/J-027) | ⚠️ **Bende eksikti.** `YinPitchSource.threshold` (0,15) ile pencere uzunluğu ayrı ayrı duruyordu; oysa YIN eşiğinin anlamı pencere boyuna bağlı. `signalConditioning` bloğu ekliyorum: `{windowSamples, hopSamples, yinThreshold, sampleRate}` — biri değişirse sürüm artar |
| B3 | **`baseline` beyanı** (G-024/M-F-34) | ✅ Kavramsal olarak zaten var ama adı yoktu: ses tarafında taban **beklenen nota** (`expectedHzPrior`), sıfır değil. Toleransın taban-göreli olduğunu (cent = oransal) açıkça beyan ediyorum |
| B4 | **Terminal olmayan fazda timeout ZORUNLU** (Lissom #1 / J-009) | ✅ Benimsiyorum: "nota bekleniyor" fazı timeout'suz kalırsa öğrenci hiç çalmadan seans askıda kalır |
| B5 | **Bilinmeyen alan = SERT hata** (M-J-03) | ✅ Zaten bu disiplindeyim: triyaj profili loader'ı bilinmeyen anahtarı reddediyor, taksonomi doğrulayıcım haritalanmamış bulguyu yakalıyor (negatif testli) |

## C. Göç pozisyonum
Taslağın göç yolu benim için sorunsuz: `ruleset-v0` zaten **taslak** (hiçbir eşik nihai değil, tümü `expertPending`), yani göç edecek kalibre edilmiş bir motorum yok — çekirdek şema mühürlenince **doğrudan ona yazarım**, çevirici katmanına ihtiyacım olmaz. Tek şart A1-A3'ün çözülmesi; çözülmezse ses ön-koşullarını ve no-judge pencerelerini şema dışında tutmak zorunda kalırım ki bu tam da şemanın önlemek istediği sessiz-boşluk sınıfıdır.
