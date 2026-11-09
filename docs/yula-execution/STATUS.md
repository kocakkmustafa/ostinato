# Ostinato — Durum (kaynak gerçeği)

Tarih: 2026-11-08 · Ölçüm tabanı: `origin/main` `dfd611465bc688a6a5bdafe43db09fcabd9b1e02` (#65), `origin/release/1.0.2` `4f399e7f77a0b38cb59f2b419060f91b5f83374d` (#64).
Dayanak: kurucu kararı "Dört ürün ana talimatı" (2026-11-08) ve AUDIT-01 (salt okur, test koşturulmadı; sayılar statik). Karar kaydı: [`DECISIONS.md`](DECISIONS.md).
Durum kodları: **CS** = CONFIRMED_SOURCE (kaynakta doğrulandı) · **TO** = TEST_ONLY (yalnız testte/sentetik veride) · **DO** = DOCUMENTED_ONLY (yalnız belgede) · **NI** = NOT_IMPLEMENTED · **UK** = UNKNOWN (doğrulanmadı).
Çelişkide kod doğrudur; README ve `docs/ostinato-plan.md` kodun altındadır.

## Bilet OST-P0-01
```yaml
id: OST-P0-01
product: ostinato
phase: P0
priority_reason: "Eski README/plan çello diyor, kod gitar+kulak; yanlış kaynağa bakan ajan doğrulanmış işi silebilir."
owner_role: Ostinato proje oturumu
review_role: Motion orchestration
user_outcome: "Ajanlar ve kurucu, Ostinato'nun gerçekte ne olduğunu tek yerden okur; eski plan/README yüzünden doğrulanmış gitar işi silinmez."
depends_on: [AUDIT-01]
repo: "kocakkmustafa/ostinato"
entry_files: [CLAUDE.md, AGENTS.md, pubspec.yaml, lib/app/ostinato_release_policy.dart, README.md, docs/ostinato-plan.md]
scope_in: ["docs/yula-execution/STATUS.md", "docs/yula-execution/DECISIONS.md"]
scope_out: ["kod", "README/CLAUDE.md/AGENTS.md", "pubspec", "CI", "release/1.0.2", "mağaza", "yulalab.com"]
negative_tests: ["kamera bayrakları (ostinatoCameraLessonsOpen, ostinatoCameraPracticeAvailable) açılmadı", "kullanıcıya yanlış/wrong gösterilmez kuralı değişmedi", "content/ ve kod dosyası değişmedi"]
acceptance_tests: ["git diff --stat origin/main...HEAD yalnız iki dosya", "belgedeki her yol var", "ADR'ler zorunlu 4 konuyu kapsar"]
telemetry: ["yok (yalnız belge)"]
security_impact: "Yok; yalnız belge. Ham ses/video cihazda kalır, kamera bayrakları kapalı kalır, düşük güvende hüküm verilmez."
cost_effect_usd_per_month: "0 USD; yeni ücretli servis yok"
rollback: "PR revert; yalnız docs"
evidence_required: ["PR bağlantısı", "baş commit SHA", "yol doğrulama çıktısı"]
status: IN_REVIEW
```

## Kurs / enstrüman
| Kurs | main'de (dosya sayısı) | Mağaza build'inde | Kod | Kanıt |
|---|---|---|---|---|
| Gitar | 240 (`content/v1/gtr`) | açık | CS | `ostinatoOpenInstruments` `lib/app/ostinato_release_policy.dart` |
| Kulak eğitimi | 50 (`content/v1/ear`) | açık | CS | `ostinatoEarTrainingOpen=true`; `lib/app/screens/library_screen.dart` |
| Piyano | 160 (`content/v1/pno`) | kapalı ("yakında") | CS (içerik), kapalı | `lib/app/screens/instrument_screen.dart`, `coming_soon_instrument_screen.dart` |
| Şan | 0 (`content/v1/voc` yok) | kapalı | DO / NI | yalnız `content/v1-w4-voice` dalı: 240 dosya = 236 ders + 4 test, EN+TR |
| Çello | kamera dersi/kurs yok | yok | DO | `config/instruments.v1.json` (plan), `fixtures/audio/AF-005-cello-c2-phone-mic.json` |
| Ukulele/bas/vokal/piyano yazılı | `assets/content/*_beginner.v1.json` | gizli | CS, gizli | `ostinatoLegacyWrittenCoursesVisible=false` |
- Ölçülen (dosya ≠ ders; test dosyası = adında `-test` geçen): main **450 dosya = 440 ders + 10 test** (gtr 240 = 235+5, pno 160 = 157+3, ear 50 = 48+2); mağazada açık **290 dosya = 283 ders + 7 test** (gitar+kulak). "690" bir DOSYA sayısıdır (450 + şan 240); ders olarak 676 (ADR-002).
- Ücretsiz: v1'de gitar S1 40 + kulak S1 25 (`ostinatoV1FreeStages`, `lib/app/course_access.dart`). 12/8 sayıları yalnız gizli eski kurslarda.

## Ses motoru
| Yetenek | Durum | Kanıt |
|---|---|---|
| Mikrofon izni | CS | `ios/Runner/Info.plist` (NSMicrophoneUsageDescription), Android `RECORD_AUDIO`; `lib/app/audio/mic_permission_gate.dart` |
| Cihaz içi yakalama | CS | `ios/Runner/AudioCaptureStreamer.swift`, `android/app/src/main/kotlin/com/yulalab/ostinato/AudioCaptureStreamer.kt`, `lib/app/audio/audio_capture_channel.dart` |
| Metronom / ipucu çalma | CS | `android/.../MetronomeStream.kt`, `ios/Runner/PracticeAudioArbiter.swift` |
| Pitch (YIN) + güven kapısı | CS + TO | `packages/ostinato_audio/lib/src/pitch/yin.dart`, `.../gate/audio_confidence_gate.dart`, `config/guitar-single-note-gate.v1.json`; `packages/ostinato_audio/test/pitch_test.dart` |
| Onset / tempo | CS + TO | `.../onset/onset_detector.dart`, `.../rhythm/metronome_aligner.dart`; `.../test/onset_register_test.dart` |
| Akor sınıfı (kendi chroma'sı) | CS + TO | `.../harmony/chord_detector.dart` |
| Gecikme kalibrasyonu | CS | `lib/app/practice/setup/latency_calibration.dart` |
| Akort | CS | `lib/app/tuner`, `.../pitch/precise_tuner.dart` |
| Kendi kaydımı dinle (opt-in, geçici) | CS | `lib/app/practice/own_recording/own_recording.dart` |
| Sunucuya ses çıkışı | CS (kaynak taraması; ağ testi NI) | `lib/` içinde http istemcisi yok; `lib/app/motion_account_bootstrap.dart` yalnız hesap |
| Kamera modülü | bayrak arkasında, kapalı (CS) | `ostinatoCameraLessonsOpen=false`, `ostinatoCameraPracticeAvailable=false`; `lib/app/practice/camera/camera_lesson.dart` |
- UK: `NSCameraUsageDescription` metninin mağaza incelemesinde sorun çıkarıp çıkarmayacağı; `docs/device-day/` içeriğinin cihaz matrisi olarak yeterliliği; mağaza (Apple) inceleme sonucu.
- 450 dosyanın tümünde (test dosyaları dahil) `expertPending=true` (uzman onayı yok), hepsinde dürüst `fallback` var (AUDIT-01).

## main ↔ release/1.0.2
- main'de olup release'te olmayan 19 commit: K8 kamera dersi (bayraklı, #58–#62), yüzey dürüstlüğü kapısı (#63), AGENTS.md (#65), CI zaman sınırı.
- Release'te olup main'de olmayan 4 commit: c184e24 ve 7847c54 (alt yazı düzeltmesi), c49654b `release: 1.0.2+11`, merge #64.
- Ders dosyaları ikisinde aynı: gtr 240, ear 50, pno 160, voc 0.
- Sürüm: main `1.0.1+10`; mağaza kaynağı `release/1.0.2` = `1.0.2+11` (ADR-004).

## Açık uyuşmazlıklar (AUDIT-01 §7)
| # | Konu | Durum | Sahip |
|---|---|---|---|
| U1 | README / `ostinato-plan.md` çello merkezli | ADR-003 ile kapandı (eski kabul). README'ye eskime bandı: AYRI iş, açık | Ostinato proje oturumu |
| U2 | "690 ders" | ADR-002 ile kapandı | — |
| U3 | Site `ostinato.ts` l.22 ile l.55 tutarsız (kod: 40+25) | Açık iş; bu depoda yazılmaz | yulalab.com oturumu |
| U4 | main sürümü "1.0.0+8" yazılmış | ADR-004 ile düzeltildi (gerçek `1.0.1+10`) | — |
| U5 | `instruments.v1.json` 42 çalgı vs çalışan 2 kurs | ADR-001 ile kapandı (plan, kapsam değil) | — |
| U6 | `docs/store/` taslakları (60 ders, Motion+, 12 ücretsiz) eski | Açık iş; kod/`listing-v1` doğru kabul edilir | Ostinato proje oturumu |
| U7 | `ventures/ostinato/app` ağacı eski (`d787720`) | Açık; bu PR dokunmaz | önerilen sahip: Motion orchestration |

## Bilet OST-P0-09
- [bilet:: OST-P0-09] [durum:: BLOCKED_ACCESS] Protokol belgesi (yalnız belge) — ölçüm 03…08 merge sonrası; durum BLOCKED_ACCESS · [PR:: #72] [CI:: yok/koşulmadı] [ölçüm-raporu:: yok (03…08 merge sonrası)] [cihaz-ortam:: 0/5] [BLOCKED_ACCESS:: 100/100] · [`OST-P0-09-PROTOKOL.md`](OST-P0-09-PROTOKOL.md)

## Bilet OST-P0-07
- [bilet:: OST-P0-07] [durum:: TEST_ONLY] Hayalet Ekran: kademeli rehber gizleme, override, rehbersiz tamamlama; bayrak `ostinatoGhostScreenOpen=false` (kapalı) · [CI:: PR üzerinde] [kullanıcı-üstü-doğrulama:: YOK — gerçek kullanıcıyla öğrenme kanıtı yok] [yetkinlik-iddiası:: YOK] · [ADR-005](DECISIONS.md) · bilinen sınırlar: `A,U,A` iki art arda sayılır; durdurulmuş/döngü/bekle koşusu ilerletmez; aşama duyurusu (`liveRegion`) cihazda doğrulanmadı
