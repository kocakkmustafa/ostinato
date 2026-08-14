# Ostinato — LOOP (iş kuyruğu)
Protokol: her iterasyon = iş al → yap → DOĞRULA (kanıt) → PROGRESS mühürle → DEFTER güncelle → kuyruk güncelle. Kapsam otoritesi: `app/docs/OSTINATO-BLUEPRINT.md` + motion-core `30-URUN-BLUEPRINT-STANDARDI.md`. **Kurucuya SORU YOK** (standart §4 md.6); boşluk = blueprint çerçevesinde kendin karar ver + DEFTER'e yaz.

## ⛔ KALDIRILDI (M-F-19, 2026-07-28)
"Kurucu-bacağı bekleniyor" durumu YOK. Öğretmen görüşmeleri/B2B doğrulaması artık hiçbir şeyi bloklamıyor (`g1/teacher-channel-validation.md` + `g1/DAVET-PAKETI.md` = arşiv değeri; B2B lansman-sonrası fırsat, DEFTER O-006). Kurucudan yalnız: onay/kapı kararları · cihaz-benchmark (G8) · fiyat · voice-pack bütçesi · submission · (opsiyonel) uzman turu.

## Kuyruk — W0 (blueprint §6: IA çatısı + platform katmanı + ses çekirdeği)
1. ~~Roadmap'i blueprint'e devret~~ ✅ 2026-07-29 (`roadmap §3b` dalga planı W0-W7 + G0-G10'a çello-merkezli kayıt şerhi)
2. ~~IA envanteri + config~~ ✅ 2026-07-29 (`config/instruments.v1.json` — 42 çalgı × 7 aile × 8 modül, dürüstlük kutuları, excluded[]; şema doğrulaması betikle temiz)
3. ~~G2 PRD~~ ✅ 2026-07-29 (`docs/PRD.md` — modlar · veri modeli + AttemptProvenance · O-013'ün 6 şartı maddelendi · ses hattı sözleşmesi · çalgı modülü sınırı + "keman testi" · W1 kabul kriterleri). ADR-001 M-F-23 ile gerçek konumlara hizalandı → **O-010 KAPANDI**.
4. ~~Ses çekirdeği~~ ✅ 2026-07-29 — **kod yazıldı, 30/30 test yeşil** (`packages/ostinato_audio`: PitchSource+YIN · AudioConfidenceGate 3-durum · OnsetDetector · MetronomeAligner · SyntheticTone). Kalan alt-iş: akor-sınıfı hattı (Basic Pitch dönüşüm spike'ı) → W1.
5. ~~W1 "common mistakes" hasadı~~ ✅ 2026-07-29 — `config/error-taxonomy.w1.json` (**35 kod**: voice 12 · piano 13 · guitar 10; kapsamda 30, invisible 5) + `config/demo-pool.w1.json` (**55 aday video**, 3/3 çalgı ≥3 bağımsız eğitmen ✅) + `tools/build_taxonomy.py` denetimi. İki bağımsız koşum kavram-düzeyinde birleştirildi (O-020/M-O-05).
5b. **SIRADAKİ — triyaj koşumu:** demo havuzunu `config/triage-thresholds.w1.json` profilleriyle rig'den geçir (`~/motion-harvest/ostinato/`); frameClass/angleClass elle etiketle; kabul ≥12/çalgı hedefi. Sonra ReferenceBuilder pilotu (B4 açı-duyarlılık ANA kol).
6. ⛔ **Platform iskeleti ERTELENDİ (M-F-25):** platform katmanı ailede BİR KEZ üretilir (`motion_shell`, pilot JabLab). Ostinato platform UI YAZMAZ; app-özel ekranlar (canlı seans, çalgı görselleştirmesi) serbest.
6b. ~~Ses fixture seti (`ostinato-audiofix-1`)~~ ✅ 2026-07-29 — 6 fixture üretildi, **motor kusuru buldu** (O-019: bas kaydında hayalet onset + yarım-pencere erken damga + örnek-cinsinden pencere→48 kHz kırığı); 52/52 test yeşil, çello 1/63→63/63. `replay_check` artık ses kanalıyla koşuyor (M-O-21..24).
7. **W1 spike'ları:** Basic Pitch TFLite/CoreML dönüşümü (akor-sınıfı) · `flutter_midi_command` MIDI modu (piyano).
8. ~~Triyaj eşik profilleri~~ ✅ 2026-07-29 (`config/triage-thresholds.w1.json` — çalgı-başına; rig alan adlarıyla doğrulandı; kabul hedefleri ölçüm-ÖNCESİ yazıldı)

## 🔔 OTURUM KAPANDI 2026-07-29 — yeni oturum promptu HAZIR
`ventures/ostinato/workspace/YENI-OTURUM-PROMPT.md` (aynen yapıştır).
İlk iş: uygunluk zinciri — ✅ whisper BİTTİ (32/32, 45/45 transkript) → yeniden sınıflandırma → uygunluk yenileme →
PROVISIONAL damgası kalkar. İkinci iş: MIDI modu spike'ı (lisans temiz).
Dal `feat/g0-g1-kickoff` @ `b282741` push'lu, **main'e merge EDİLMEDİ** (kurucu onayı).

## Beklemede (bloklamaz)
- M-O-01/02 koordinatör yanıtı (çekirdek hizalama + hasat rig'i filtreleri) — tasarım bunu beklemeden ilerler.
- W3 çello hattı: pedagoji v1.1 · triyaj · veri protokolü · ruleset-v0 · ReferenceBuilder pilotu → W3 kapısı açılınca (OK-3-rev veri-güdümlü metrik).
- Opsiyonel uzman turu · URMP maili · cihaz-benchmark (G8).
