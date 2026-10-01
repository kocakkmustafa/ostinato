# Ostinato — LOOP (iş kuyruğu)

## 2026-09-30 QA sessiz video adaptörü sonrası

Android debug ve iOS simülatör eklenti derlemeleri geçti; QA adaptörünün
Dart yaşam döngüsü 9/9 odak ve 370/370 tam Flutter testinde temiz. iOS/macOS
paketli MP4 audio-track API'si yanlış boş sonuç verebildiği için gerçek QA
factory platformda native controller kurmadan kapanıyor. Üretim medya slotu
boş ve practice audio edinimi kapalı. Sonraki kapı: doğrulanmış sessiz medya
ve altyazı varlığı, iOS için bağımsız güvenilir ses-izi profili, Android ve
iPhone'da video ile isteğe bağlı mikrofonun fiziksel oturum/kapanış denemesi;
kurucu toplu ders kabulü en sonda. Bunlar olmadan oynatmayı ürüne açma.
Makbuz `scratch/2026-09-30-ostinato-native-video-adapter/RESULT.md`.

## 2026-09-30 sentetik YIN pilotu sonrası

Hizalı iki eşzamanlı ses tek nota gibi gözlenebiliyor; 25/28 dondurulmuş
sentetik pilot FALSIFIED. Kullanıcı metni sınırı açıkça söylüyor.
Bağımsız referanslı gerçek tek tel/karma ses ve fiziksel telefon mikrofonu
olmadan eşik retune'u veya ders başarısı iddiası yapma; eski tek koşumu
yeniden çalıştırma. Gate E onaylı örnek ses ve Gate F gerçek cihaz/kurucu
kabulü sırada. Makbuz `scratch/2026-09-30-ostinato-yin-stress/REPORT.md`.

## 2026-09-29 Gate D sonrası

Gate D boş lease native çiti, aktif kapanış sırası ve eski mikrofonun bağlam iddiası yerel kaynak/testte PASS (Flutter 127/127, Android 17/17, iOS 16/16; son kuyruk yarışı red/green). Yerel WIP commit/push edilmedi. Sırada eğitmen onaylı örnek ses ve kullanıcıya görünür oynatma Gate E; gerçek iPhone/Android ses-yaşam döngüsü, ardından kurucunun toplu fiziksel kabulü Gate F. Bunlar bitmeden practice lease edinimini açma veya nota doğruluğu ilan etme. Son SHA'da Actions ve mağaza kabulü ayrıca açık. Makbuz `scratch/2026-09-29-ostinato-gate-d/RESULT.md`.

## 2026-09-28 ortak ses hakemi sonraki kapı

Gate A tipli Dart kanal/lease; Gate B iOS proses hakemi ve Gate C Android
proses hakemi kaynakta. Bağımsız incelemenin dört kapanış/rota bulgusu
düzeltildi; son kaynak iOS simülatöründe 15/15, Android JVM'de 35/35 ve
debug derlemede geçti. Üretimde edinim kapalıdır. Sıradaki tek yazarlı iş
root'un **lease boşta olsa da** route/hesap/arka planda native
`fenceContext` çağrısı ve bunun aktif lease kapanışıyla sıra sözleşmesi
(Gate D); ardından eğitmen onaylı örnek ses ve UI Gate E, native/kurucu
fiziksel cihaz kabulü Gate F. Gate D/F ve bağımsız ürün kabulü bitmeden
`allowAcquisition` açılmaz. Yararlı son-baş CI için Actions bütçe engeli
ayrıca açık.

## 2026-09-28 güncel kuyruk
1. PR #1'e taşınan 60 derslik gitar kaynağında CI bütçe engeli kalkınca son başta yararlı kontrolleri çalıştır; v8e kaynak/medya paketinin bağımsız denetimini kaydet.
2. Ses giriş/çıkış hakemi, gerçek iki Activity/MethodChannel ve fiziksel mikrofon kapanışını ayrı kabul et; taklit testini cihaz kanıtı sayma.
3. 60 derslik mevcut kurs JSON'u paket manifestiyle boyut/SHA denetiminden geçiyor; bozuk/eksik pakette açılış kütüphaneyi kapatıyor. Eğitmen onaylı medya/altyazı ve gerçek oynatma bağı hâlâ açık. Kişi-ayrık uzman nota/form etiketi olmadan model fit yok.
4. Tam ders kurucu kabulü en sonda; başarılı PR/CI kaynağı mağaza submit veya model kabulü sayılmaz.

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
