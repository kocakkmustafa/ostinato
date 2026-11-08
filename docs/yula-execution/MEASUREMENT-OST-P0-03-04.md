# OST-P0-03/04 — Onset, tempo ve monofonik pitch ölçüm raporu

Tarih: 2026-11-08 · Durum: TEST_ONLY (sentetik) + sınırlı gerçek kayıt · Üretim kodu değişmedi.
Tüm sayılar `[OST-P0-03]` / `[OST-P0-04]` / `[OST-P0-03-real]` stdout satırlarından alındı (aşağıdaki komutlar). Hedefler "pilot test hedefi"dir; başarı veya mutlak gecikme garantisi iddiası değildir.

## Yöntem
- Corpus: `test/ost_p0_03_04_corpus.dart` — tohumlu (`dart:math Random(seed)`), ağsız. Ton: `SyntheticTone.harmonic/notesAt` (harmonikli gitar benzeri). Gürültü: beyaz (Gauss) ve pembe (Kellet), SNR nota-aktif RMS'e göre. Yankı: 48 kollu seyrek IR (20–400 ms, RT60 0,6 s); gerçek oda ölçümü değildir.
- Onset: 60/90/120 BPM × 8 vuruş, 196 Hz (G3); gürültü 20/10/5 dB × beyaz/pembe × 3 tohum (her hücre 72 vuruş). Referans = bilinen çalma zamanları; eşleme bire-bir, ±100 ms. Kaçan = referansta olup tespitte olmayan; fazla = tespitte olup referansta olmayan.
- Tempo: üretimde tempo kestiricisi YOK. Testte tespit edilen vuruşların medyan IOI'sinden türetilen BPM ile nominal BPM farkıdır (yalnız ölçüm amaçlı).
- Pitch: açık teller E2 A2 D3 G3 B3 E4, planlı sapma 0/±10/±30 cent, 2 tohum. İki katman ölçüldü: (a) korumasız iç katman `GuitarSingleNoteEvaluator` + `config/guitar-single-note-gate.v1.json`; (b) ÜRÜN YOLU `GuitarPitchObserver` + `assets/config/guitar-observation.v2.json` (controller'ın kurduğu gibi; 8192 örnek pencere, tepe 0,5'e ölçeklenmiş çünkü corpus tepe=1,0 kırpma korumasını tetikler). "Doğru" = nota doğru ve ölçülen cent planlıdan ±10 içinde. Gürültüde oda tabanı = aynı gerçekleşimin yalnız-gürültü RMS'i: ideal kalibrasyon (İYİMSER; gerçek Setup Check'ten ölçülmedi).
- Ortam: Flutter 3.47.5, Dart 3.13.4, macOS 26.6.2 arm64, yerel VM; cihaz/mikrofon yolu yok.

## Onset ve tempo (sentetik, TEST_ONLY)
| Koşul | hata ms medyan / p95 | kaçan | fazla | tempo hata BPM (medyan) |
|---|---|---|---|---|
| temiz (3 BPM, 24 vuruş) | 8,3 / 11,0 | 0% | 0% | 0,15 (maks 0,30) |
| beyaz 20 dB | 7,3 / 9,8 | 0% | 0% | 0,15 |
| beyaz 10 dB | 4,8 / 7,3 | 0% | 4,2% | 0,15 |
| beyaz 5 dB | 2,3 / 6,2 | 0% | 36,1% | 0,30 |
| pembe 20 dB | 5,9 / 7,9 | 0% | 19,4% | 0,15 |
| pembe 10 dB | 2,3 / 44,3 | 0% | 187,5% | 142 (kullanılamaz) |
| pembe 5 dB | 2,7 / 44,3 | 0% | 298,6% | 243 (kullanılamaz) |
| yankı RT60 0,6 s | 7,3 / 10,8 | 0% | 0% | 0,15 |
| sayısal sessizlik; oda gürültüsü −40 dBFS (6 durum) | — | — | 0 sahte vuruş | — |

- Sistematik yanlılık: tespitler vuruştan ortalama 7–8 ms ERKEN (işaretli medyan −7,9 ms, pencere ortası zaman damgası). Aligner, kasıtlı ±30/±60 ms kaymayı bu yanlılık çıkarılınca ±0,1 ms içinde geri buldu; bias etiketleri (rushing/centred/dragging) doğru.
- Hata türleri: 2 kaçan vuruş → aligner kapsamı 6/8; 2 ızgara-dışı fazla vuruş → tespit edildi (10/10), hizalamada sayılmadı (8/8).
- Pembe gürültüde (düşük frekanslı enerji) fazla-vuruş oranı yüksek: ölçülen SINIRLILIK; testte eşik bu değere sabitlendi (regresyon bekçisi), iyileşirse sıkılaştırılmalı.

## Onset — gerçek kayıt (GuitarSet, CC BY 4.0; `tool/ost_p0_03_real_onset_replay.dart`)
Kaynak: `tool/fetch_guitarset_fixtures.py` (Zenodo kaydı 3371780, SHA-256 pinli, 6/6 doğrulandı). Mono-mic gitar eşlik (POLİFONİK, monofonik değil; cihaz mikrofonu değil). Referans = JAMS `note_midi` başlangıçları, 70 ms içindeki strum notaları tek olay.
| Kayıt | referans | hata ms medyan / p95 | kaçan | fazla |
|---|---|---|---|---|
| BN1-129-Eb | 74 | 12,7 / 19,0 | 36,5% | 2,7% |
| BN3-119-G | 85 | 14,4 / 20,3 | 29,4% | 3,5% |
| Jazz2-110-Bb | 88 | 12,1 / 21,2 | 50,0% | 2,3% |
| TOPLAM | 247 | 12,9 / 20,8 | 38,9% | 2,8% |
Yanlılık −12,4 ms (erken). Gerçek eşlikte kaçan oranı yüksek (legato/akor); tempo gerçek kayıtta ölçülmedi.

## Pitch ve "duyamadım" (sentetik, TEST_ONLY)
Aşağıdaki ilk tablo KORUMASIZ İÇ KATMAN `GuitarSingleNoteEvaluator`'dır (üründe bu katmanın üstünde `GuitarPitchObserver` koruması vardır; ürün yolu sonuçları ondan sonraki tabloda).
| Senaryo | n | doğru | duyamadım | yanlış hüküm | cent hata medyan / p95 / maks |
|---|---|---|---|---|---|
| temiz E2–E4, ±0/10/30¢ | 60 | 100% | 0% | 0% | 0,0 / 0,0 / 0,1 |
| telefon HP 120 Hz | 18 | 100% | 0% | 0% | 0,0 / 0,0 / 0,0 |
| beyaz 20 dB | 30 | 100% | 0% | 0% | 0,1 / 0,4 / 0,5 |
| beyaz 10 dB | 30 | 96,7% | 3,3% | 0% | 0,9 / 3,7 / 4,2 |
| beyaz 5 dB | 30 | 0% | 100% | 0% | — |
| pembe 20 dB | 30 | 100% | 0% | 0% | 0,1 / 0,2 / 0,3 |
| pembe 10 dB | 30 | 100% | 0% | 0% | 0,5 / 1,1 / 1,9 |
| pembe 5 dB | 30 | 0% | 100% | 0% | — |
| sayısal sessizlik + oda gürültüsü | 37 | 0% | 100% | 0% | — |
| `AudioConfidenceGate` gürültü-only, taban = pencere RMS | 8 | — | mayJudge 0/8 | 0 | — |
| `AudioConfidenceGate` gürültü-only, bağımsız taban −60 dBFS | 8 | — | mayJudge 0/8 (hepsi notPeriodic) | 0 | — |
| tek nota + yankı | 18 | 100% | 0% | 0% | 0,0 / 0,0 / 0,0 |
| A→B geçişi + yankı kuyruğu | 3 | 100% | 0% | 0% | 0,0 |
| çok sesli (16 akor + 12 dyad), KORUMASIZ katman | 28 | — | 64,3% | 35,7% (10/28) | — |
Atak penceresi (`lastOnsetTUs`) ve koç sesi: hüküm yok (test geçti).

ÜRÜN YOLU (`GuitarPitchObserver` + `guitar-observation.v2.json`):
| Senaryo | n | doğru | duyamadım | yanlış hüküm | cent hata medyan / p95 / maks |
|---|---|---|---|---|---|
| temiz E2–E4, ±0/10/30¢ | 60 | 100% | 0% | 0% | 0,0 / 0,0 / 0,1 |
| çok sesli (16 akor + 12 dyad) | 28 | — | 100% (28/28) | 0% (0/28) | — |
| sapma ±40¢ ve ±50¢ (6 tel × 4) | 24 | 0% | 100% | 0% | — |
Çok sesli ret nedenleri: `notPeriodic` 18, `multipleSources` 10 — yani korumasız katmanın yanlış hüküm verdiği 10 durumun tamamını `multipleSources` (FFT artık-enerji koruması) yakalıyor. ±40/±50¢: `maxCenterErrorCents` 35 sınırı nedeniyle hüküm yok (yanlış hüküm yok).
Eski kanıtla uyum: `docs/evidence/production-line/guitar-techs-independent-observation-2026-09-26.json` gerçek stüdyo poliyfonide 12 pencerede 0 tek-nota çıktısı (8 multipleSources, 4 notPeriodic) bildirir; bu sentetik sonuç çelişmiyor, aynı yönde.

Pilot ön hedefle karşılaştırma (temiz monofonik ≥%90 tanıma): sentetik temiz sette 60/60 = %100 → ön hedef sentetik sette karşılandı (gerçek gitar/cihaz için kanıt değil).

Gerçek monofonik kayıt (mevcut `tool/audio_fixture_replay.dart`, Iowa MIS PİYANO, SHA-256 pinli AIFF; gitar değil): A1–C6 5/5 geçti (cent medyan 5,4–8,9; p95 ≤14,0; judged %79–94); A6–B7 5/5 kaldı (bilinen yüksek-register eğilimi, O-177/O-184). Gitar menzili (≈E2–E4) piyano A1–C4 ile örtüşür.

## Bulgu (ENGEL yok)
İlk sürümdeki ENGEL iddiası geri çekildi: ölçülen, korumasız iç katmandı. D akoru (D3 A3 D4 F#4) ve kök+beşli dyad'lar (D3+A3, G3+D4, B3+F#4, E4+B4) `GuitarSingleNoteEvaluator`'da bir oktav ALT nota olarak hüküm alıyor (YIN ortak alt-harmoniği kilitliyor; 10/28). Ürün yolunda `GuitarPitchObserver` (`guitar_pitch_observer.dart`, `multipleSources`) bunların hepsini reddediyor: yanlış hüküm 0/28. Karakterizasyon testi (adı "KARAKTERİZASYON … doğru DEĞİL") korumasız katman sayısını `equals(10)` ile sabitler; katman değişirse kırılıp bilinçli güncelleme ister. Ürün-yolu testi yanlış hükmü 0'a sabitler.

## Sınırlar
- Cihaz-üstü ölçüm yok; hoparlör/mikrofon/AGC/telefon gecikme yolu yok. Gecikme (mutlak ms) garantisi verilmez.
- Sentetik tonlar gerçek gitar zarfını/inharmonisitesini temsil etmez; yankı gerçek oda değil.
- Gerçek-kayıt pitch ölçümü yalnız piyano; gerçek monofonik GİTAR ölçümü yapılmadı.

## Komutlar
`flutter test test/ost_p0_03_onset_tempo_corpus_test.dart test/ost_p0_04_pitch_confidence_corpus_test.dart` · `dart run tool/ost_p0_03_real_onset_replay.dart` (önce `python3 tool/fetch_guitarset_fixtures.py`) · `dart run tool/audio_fixture_replay.dart` (önce `bash tool/fetch_audio_fixtures.sh` + `dart run tool/prepare_audio_fixtures.dart`).

## Açık işler (kapsam boşlukları)
- Gerçek monofonik GİTAR corpus'u ve cihaz-üstü ölçüm; gerçek Setup Check'ten gelen oda tabanı.
- Gerçek kayıtta gürültü/sessizlik/yankı senaryosu yok (gürültü/yankı yalnız sentetik).
- `ambiguousCenter` sınırı yalnız ±40/±50¢ ile yoklandı (35¢ eşiğin ince taraması yok); ±30¢ üstü sapmada gerçek kayıt yok.
- Vuruş-başı jitter yalnız tek dağılım (±25 ms düzgün, 9 koşu) denendi: onset hatası medyan 8,4 / p95 11,1 ms, aligner'ın sıralı sapma − planlanan fark p95 10,7 ms (sabit ~8 ms erken yanlılık dahil).
- Pembe gürültüde fazla-vuruş azaltma; tempo kestiricisi (üretimde yok); gerçek kayıtta tempo.
- Tek örnekleme hızı (44,1 kHz); 48 kHz ölçülmedi.
