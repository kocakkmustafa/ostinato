# ADR-001 (TASLAK) — Enstrüman-Bağımsız Çekirdek ↔ Çello Modülü Sınır Çizgisi

**Tarih:** 2026-07-26 · **Statü:** TASLAK — G2'de (B2B sinyali onaylıysa) ADR olarak mühürlenir; şimdilik tasarım-hazırlık (kapıya bağımlı olmayan iş).
**Bağlayıcı:** 00-AILE-MIMARISI §1.1 (Ostinato TÜM çalgılara açık; çello ilk motor) + §2 (nesne algılama + ses analizi OSTINATO'ya aittir, core'a sızmaz — aile bunlarsuz yaşar) · 20-URETIM-SURECI §2.6 (ileriye-dönük mimari: alan-bağımsız motorlar, içerik=paket).

> ✅ **HİZALANDI (2026-07-29, M-F-23 yanıtıyla — O-010 KAPANDI).** Çekirdek `motion_core-v0.1.0` tag'ine pinlenir. §2.1'in soyut maddeleri artık GERÇEK konumlara bağlı:
> | Bu ADR'de yazan | Çekirdekteki gerçek yeri |
> |---|---|
> | state-machine çatısı | `engine/phase_state_machine.dart` (`PhaseStateMachine` / `AttemptRun`) |
> | replay/fixture harness | `fixture/replay.dart` (fixture şeması v2) |
> | **tek-saat sözleşmesi** | **`engine/motion_clock.dart` (`MotionClock`)** — audio+motion AYNI kaynaktan damgalanır; kendi saatimizi yazmayız |
> | ses-gecikme kalibrasyonu (M-F-08) | `LatencyCalibrationStore` + `TapTestCalibrator` (route-başına) |
> | koç sesi ↔ mikrofon çakışması | **`CueGate`** — cue sırasında analiz zaman-kapısı + ring-out; `playAndRecord` bileşik oturumun core sözleşmesi (oturum yönetiminin kendisi app/platform işi) |
> | güven/yapısal denetim | `ConfidenceGate.forVariant` (M-018) · `StructuralValidator` (M-019) |
> | referans konsensüsü | `ReferenceBuilder` / `CanonicalReference.toleranceAt` |
> | provenance | `AttemptProvenance` (M-F-07) — her deneme/skor kaydına girer |
>
> **Sınır dedektörü teyit edildi:** çekirdekte nota/pitch/yay kelimesi YOK; yeni modüller enstrüman-bilmez. **`ostinato-audiofix-1` ses fixture şeması app'te KALIR** (00-AILE §2: ses analizi core'a girmez); hizalama şartları: zaman alanları core'la konuşurken monotonic **Us**'a çevrilir (`MotionClock` çapası) · provenance alan adları fixture-v2 `provenance` bloğuyla eşlenir (`sourceUrl`/`license`/`retrievedAt`/`toolVersions`) · **`shouldJudge:false` negatif sınıfı KORUNUR** · metronom-hiza alt-seti ileride RhythmEngine onset-event arayüzüne akar (M-F-21).
> Bağlayıcı: bowing referans hattı `ReferenceBuilder` TÜKETİR, kendi konsensüs/aynalama çözücüsünü YAZMAZ (L-019'un Ostinato karşılığı).

---

## 1. Karar soruları (üç test)

Bir parçanın nereye ait olduğunu ÜÇ soru belirler:
1. **"Choreia/JabLab de kullanır mı?"** → EVET ise `motion-core` (aile çekirdeği).
2. **"Keman/gitar eklerken DEĞİŞİR mi?"** → EVET ise **enstrüman modülü**; HAYIR ise **Ostinato çekirdeği**.
3. **"Kod mu içerik mi?"** → Davranış kuralları/eşikler/müfredat = versiyonlu config+paket (kod değil); motorlar yalnız yorumlar.

## 2. Üç katman — sorumluluk haritası

### 2.1 motion-core (aile çekirdeği — pinli semver tüketimi)
Kamera kalibrasyon sihirbazı çatısı · pose/hand bridge (native, Pigeon, kanal diyeti) · landmark güven kapısı · temporal smoothing · normalizasyon · state-machine ÇATISI · versiyonlu rule-set MOTORU · feedback önceliklendirici + cooldown · replay/fixture harness · yerel depolama + gizlilik katmanı · TTS/ducking ses-geri-bildirim modülü · **TEK-SAAT sözleşmesi** (audio+motion monotonic timestamp eşleme — katalog §4 kararı gereği core'a gider; Choreia da kullanacak).
⚠️ Sınır ihlali dedektörü: motion-core'a "nota", "yay", "çello", "pitch" kelimesi giren PR = ihlal.

### 2.2 Ostinato çekirdeği (enstrüman-BAĞIMSIZ; bu repo)
- **Pratik oturum çatısı:** 5 mod akışı (Setup Check / Technique Drill / Guided Practice / Review / Teacher Share) — hepsi enstrüman-parametrik.
- **Ses motoru arayüzleri:** `PitchSource` / `OnsetDetector` / `MetronomeAligner` soyutlamaları + güven kapısı + beklenen-nota önseli çerçevesi (audio-dsp ref §2/§7). Somut implementasyonlar (YIN-native, SwiftF0-ONNX) da çekirdekte — enstrümana değil sinyale bağlılar; yalnız FREKANS ARALIĞI + eşik profili enstrüman-config'inden gelir.
- **Enstrüman algılama ÇERÇEVESİ:** "InstrumentDetector" arayüzü + 2-keypoint hat-takip çatısı (model dosyası ve sınıf listesi modülden gelir).
- **Füzyon bulgu çerçevesi:** audio-olay × motion-olay ARALIK-kesişim motoru ("yay yönü değişti + ses kesildi" tipi kural şablonları; kural İÇERİĞİ modülde).
- **Öğretmen katmanı (API-önce):** SessionReport şeması + paylaşım akışı + (ileride) öğretmen paneli sözleşmesi — enstrüman-bağımsız.
- **İçerik motoru:** egzersiz paket yükleyici (versiyonlu config: nota/metronom/tolerans/değerlendirme-kural referansları).
- **Çocuk-rejimi veri akışı:** rıza durumu → saklama/paylaşım politika uygulayıcı (baştan ayrık modül — plan §13).
- i18n altyapısı (V1 yalnız `en`).

### 2.3 Çello modülü (ilk enstrüman paketi — `modules/cello/` deseni)
- Nesne sınıf listesi + eğitilmiş detector modeli (cello_body/fingerboard/bridge_region/bow/eller) + model sürüm meta.
- Bowing state-machine TANIMLARI (READY→…→COMPLETE) — çatı çekirdekte, tanım burada.
- Çello rule-set içerikleri: E-kod eşikleri (pedagoji taksonomisinden), tel-başına/faz-başına tolerans profilleri, risk-sınıfı eşlemesi.
- Egzersiz paketi: açık-tel/uzun-yay müfredatı (Rolland ritimleri, Drexler dizisi) + replikler (EN).
- Enstrüman-config: frekans aralığı (C2-A3+), akort referansı, boy varyantları (1/4-4/4) → normalizasyon parametreleri.

## 3. "Keman testi" (sınırın kanıtı)

Keman eklerken değişmesi gereken HER ŞEY §2.3'te mi? Kontrol: yeni detector modeli ✓ (modül) · duruş AYAKTA → Setup Check kuralları modül-config'de mi? ⚠️ Setup Check akışının "oturuş" varsayımı çekirdeğe SIZMAMALI — akış adımları da enstrüman-config'ten gelmeli (bu ADR'nin ana tasarım kazanımı) · omuz/çene teması yeni E-kodlar ✓ (modül taksonomisi) · frekans aralığı ✓ (config) · kamera açısı önerisi → enstrüman-config'e (çello: sağ-ön çapraz; keman farklı olabilir).
**Sonuç kural:** çekirdek "SEATED_CELLO" bilmez; "postür şablonu + kamera şablonu + hata taksonomisi + egzersiz paketi" yükler.

## 4. Reddedilenler

- ❌ Nesne algılama/ses analizini motion-core'a koymak (00-AILE §2 açık hükmü; aile bunlarsuz yaşar).
- ❌ Çello mantığını çekirdeğe gömüp "sonra refactor ederiz" (darboğaz-kısayol yasağı — §2.6 gece direktifi; Ostinato'nun D3 maliyeti zaten yüksek, ikinci enstrümanda ödemeyi katlamak kabul edilemez).
- ❌ Pitch kütüphanesini doğrudan çağırmak (PitchSource soyutlaması şart — kütüphane değişimi tek nokta; G1-C bulgusu: 3 aday da geçerli, seçim esnek kalmalı).

## 5. G2'de mühürlenecek açık uçlar

1. `modules/cello` paketleme biçimi: Dart package mı, asset-bundle + native model dosyası mı (boyut/güncellenebilirlik dengesi).
2. Füzyon kural DSL'i ne kadar genel (JSON kural şablonu yeter mi, mini-DSL mi).
3. SessionReport şemasının öğretmen-paneli-uyumlu sürümleme stratejisi.
4. Ses motoru native paylaşımı: C++ çekirdek (iki platform tek davranış) vs platform-ayrı (AudioKit iOS + Kotlin YIN) — G1-C verisi iki yolu da açık bırakıyor; karar G4 öncesi audio-dsp turu.
