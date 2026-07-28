# Ostinato — PRD (G2)

**Tarih:** 2026-07-29 · **Statü:** YÜRÜRLÜKTE (oturum kararıyla; standart §4 md.6 — kurucuya soru yok)
**Kapsam otoritesi:** `OSTINATO-BLUEPRINT.md` (42 çalgı, 7 dalga) + motion-core `30-URUN-BLUEPRINT-STANDARDI.md` (IA + oturum sözleşmesi). Çelişkide blueprint kazanır.
**Çekirdek:** `motion_core-v0.2.1` (tag-pinli; yükseltmede 34/34 sözleşme testi yeşil kaldı). Ses analizi bize ait (`packages/ostinato_audio`), saat/gecikme/kalibrasyon çekirdeğe ait.

---

## 1. Ürün tanımı ve V1 sınırı

**Ostinato: Music Practice** — telefon kamerası (postür/teknik) + mikrofon (perde/ritim) ile pratik koçu. Her çalgı kendi sayfasında, kendi kurslarıyla.

**W1 kapsamı (ilk ship edilebilir kütüphane):** Şan · Piyano(+MIDI) · Gitar. Üçü de **dedektörsüz** — kamera yalnız postür/el için kullanılır, nesne algılama yatırımı W3'e (yaylılar) ertelenmiştir. Kalan 39 çalgı sayfası "yakında" durumunda görünür (kapsam baştan görünür, sahte kurs asla listelenmez).

**V1'in vaat etmediği** (her çalgı sayfasında yazılı): nota-nota polifonik transkripsiyon · embouchure · nefes basıncı · ton kalitesi yargısı · tıbbi/klinik dil.

## 2. Modlar (çalgı-bağımsız akış; içerik çalgıdan gelir)

| Mod | Ne yapar | Kapı |
|---|---|---|
| **Setup Check** | Kamera açısı + kadraj + ışık + **oda gürültü tabanı kalibrasyonu** + (varsa) MIDI cihazı algılama | **SERT KAPI ölçüm modlarında** (M-F-09): geçilmeden analiz başlamaz. Serbest pratikte uyarı bandı |
| **Technique Drill** | Tek teknik/egzersiz üzerinde kısa tekrarlar; canlı sesli koç | Setup Check geçilmiş olmalı |
| **Guided Practice** | Metronom + egzersiz dizisi; müziği bozmayan geri bildirim | — |
| **Review** | Seans özeti: neyi ölçtük, neyi ölçemedik, bir sonraki adım | — |
| **Teacher Share** | İskelet-render rapor (ham video ÇIKMAZ), öğrencinin açık onayıyla | Öğretmen-paylaşım bir ÖZELLİK (M-F-19), kanal-kapısı değil |

## 3. Veri modeli (çekirdek sözleşmeleriyle)

```
User ─┬─ StudentProfile (yaş bandı, çocuk-rejimi bayrağı)
      └─ GuardianConsent (ebeveyn izni; K1/K2/K3 katmanlı)
InstrumentProfile (config: instruments.v1.json'dan; aktif çalgı + akort referansı + aralık)
CameraSetup + AudioSetup (kalibrasyon profili: açı, oda gürültü tabanı, route gecikmesi)
PracticePlan → Course → Exercise (versiyonlu içerik paketi)
Session ─┬─ MotionFrame / AudioWindow   (hepsi MotionClock Us damgalı)
         ├─ TechniqueAttempt ── Metric[] ── DetectedIssue[] ── Feedback[]
         └─ AttemptProvenance  ← ZORUNLU (M-F-07)
SharedReport (iskelet-render + metrik özeti)
```

**`AttemptProvenance` (M-F-07) her denemeye yazılır:** pose model varyantı + model SHA-256 · kural-seti sürümü · metrik-config sürümü · kalibrasyon profili · ses motoru sürümü. **Zaman-içi karşılaştırma (ilerleme grafiği) bu alanlar olmadan YAPILMAZ** — model sürümü değiştiğinde "gelişme" ölçüm kaymasından ibaret olabilir.

## 4. Aile şartlarının maddelenmesi (O-013 kapanışı)

| # | Şart | Ostinato'daki karşılığı |
|---|---|---|
| a | **K8 / M-F-04:** kalibrasyon kapısı geçilmeden SAYISAL skor gösterilmez | Review ekranı V1'de **bant + eğri + süre**: "steady", "improving", "needs focus". Cent/ms sayıları yalnız kalibrasyon geçilmiş ölçüm modunda ve bileşenleri açıklanarak |
| b | **M-F-09:** Setup Check ölçüm modlarında sert kapı | §2 tablosu; serbest pratikte öneri bandı |
| c | **M-F-08:** ses-gecikme kalibrasyonu çekirdekten | `LatencyCalibrationStore`/`TapTestCalibrator` tüketilir; **kendi modülümüz yok**. Metronom hizası **duyulan** zamana göre ölçülür (aksi hâlde BT kullanıcısına her vuruşta "geç kaldın" denir) |
| d | **M-F-07:** provenance | §3 |
| e | **M-F-05:** aile defterine `M-O-*` önekiyle yazılır | Uygulanıyor (M-O-01..04) |
| f | **M-F-06:** sol/sağ taraf-agnostik | Kurallar taraf-agnostik yazılır; **yay eli / sol el ayrımı** kalibrasyon pozunda GEOMETRİK kurulur, `StructuralValidator` temiz değilken taraf raporlanmaz |

## 5. Ses hattı sözleşmesi (kod: `packages/ostinato_audio`, 30/30 yeşil)

- `PitchSource` soyutlaması → platform-başına farklı implementasyon serbest; `YinPitchSource` **normatif referans** (native portlar fixture-replay ile ona karşı doğrulanır).
- **Üç durumlu güven kapısı** (reliable / unreliable+neden / transition): atak penceresi ve yay değişimi "hata" değil "hüküm yok". Eşikler **oda tabanına göreli**, mutlak dBFS değil.
- **Beklenen-nota önseli** oktav kilidine karşı; ⚠️ kurtarma menzili sayısal beyanlı (≤100 cent kalan-oktav toleransı) — O-017 dersi, aile kuralı M-O-04.
- Onset = spectral flux (enerji değil); metrik onset SAYISI değil **hizalama**.
- Metronom raporu: medyan + **yayılım** + bias (sürekli erken ≠ dağınık) + coverage (kaçan vuruş "mükemmel" sayılmaz).
- **`CueGate`:** koç konuşurken analiz zaman-kapısı (AEC'ye güvenilmez — konuşma için ayarlıdır, müziği bozar).

## 5b. Ölçüm uzayı — J-028 / M-F-30 (P0 aile kuralı)

**Ham normalize landmark koordinatında mesafe ve açı, en-boy oranı kadar bozuktur** (1080p dikeyde ~1,78×). JabLab bunu gerçek karede yakaladı; **sentetik fixture bu hatayı YAKALAYAMAZ**, çünkü sentetik iskelet zaten kare bir uzayda üretilir — yani "testlerim yeşil" bu hataya karşı hiçbir şey söylemez.

Ostinato'daki durum, kanıtla: **ses hattı etkilenmiyor** (`packages/ostinato_audio` içinde landmark/koordinat matematiği yok — grep'le doğrulandı; oradaki "normalize" geçişleri YIN'in kümülatif ortalaması ve dalga genliği). Risk **gelecekteki postür/Setup Check modülünde**.

Bağlayıcı kurallar:
1. İskelet geometrisi **world uzayında** (metrik, en-boy bağımsız) veya **piksel-ölçekli** hesaplanır. **Ham normalize uzay YASAK.**
2. Kamera/füzyon gören her hata kodu, metriğinin uzayını **beyan eder** — `config/error-taxonomy.w1.json` içinde `measurementSpace` alanı (20 kod).
3. Her kamera/füzyon kodu ship öncesi **≥1 gerçek-kare regresyonu** ister (`realFrameRegression: required`).
4. Kural **makine-denetimli**: `tools/build_taxonomy.py` uzay beyanı eksik/yasak olanı reddeder — negatif testle doğrulandı (kasten `normalized_raw` verildiğinde 20 ihlali yakalayıp exit=1).

## 6. Çalgı modülü sözleşmesi (ADR-001 revizesi)

Çekirdek "çello" bilmez; **çalgı modülü** yükler: `{aile, modüller[], frekans aralığı + akort referansı, kamera açısı şablonu, postür şablonu, hata taksonomisi + tolerans profilleri, egzersiz paketi, dürüstlük kutusu}`. Yeni çalgı = konfig + içerik; motor değişmez. Doğrulaması: **"keman testi"** — keman eklerken değişen her şey modül paketinde mi? (Setup Check'in "oturuş" varsayımı bile config'ten gelir.)

## 7. W1 kabul kriterleri (ship kapısı)

1. Üç çalgı sayfası dolu (tanıtım + kurs listesi + seviye haritası + dürüstlük kutusu), 39 sayfa "yakında" — sahte kurs 0.
2. Şan: perde doğruluğu + **vibrato metriği** + sustain + duruş; Piyano: akor-sınıfı + MIDI modu + el/bilek duruşu; Gitar: akor şekli (el-landmark) + akor-sınıfı + tempo.
3. Her hata kodunun **≥2 bağımsız öğretmen kaynağı + provenance**'ı var (M-F-19); doğru teknik **≥3 eğitmen konsensüsü**.
4. Motor kodu fixture-replay testli; kapı kanıtsız faz atlanmaz.
5. Setup Check sert kapısı çalışıyor; kalibrasyonsuz sayısal skor gösterilmiyor.
6. Ölü buton 0; offline temel akış; çocuk-rejimi akışı uçtan uca.

## 8. Riskler (DEFTER'e bağlı)

O-004 çocuk-verisi (artık 42 çalgıda) · O-005 içerik maliyeti (kapsamla çarpıldı → dalga-bazlı üretim + konfig devri) · O-012 kamera-açı kıtlığı (çelloda %7 ölçüldü; W1 çalgılarında triyaj tekrarlanacak) · O-017 sınıfı sessiz-yanlış (her normalizasyon katmanı kurtarma menzilini sayısal beyan eder).
