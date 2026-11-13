# OST-UX-05e2 ölçüt tablosu (aşama 1 + 2)

Aşama 2 koşusu: 12 dosya, `+295: All tests passed` (`scratch/2026-11-12-ostinato-05e2/raw2.txt`); analyze 0; validate_surface_honesty rc 0; build_message_ids --check rc 0.
Kırmızı kanıt (aşama 1): `scratch/2026-11-12-ostinato-05e2/05e2-kirmizi-kanit.md` (27 kırmızı / 27 yeşil; kırmızılar assertion, derleme hatası yok).
Test dosyası: `test/ux_05e2_nextstep_honesty_test.dart`.

| Ölçüt | Test (dosya: ad) | Kırmızı koşu (kanıt) | Durum |
|---|---|---|---|
| Eski yol, durmuş/yarım koşu × loopSlower/raiseTempo/performanceRun adayı: etiket "Tekrar dene"/"Try again" (en+tr, 6 widget testi) | ux_05e2: `a) stoppedEarly/<aday> [en\|tr] -> tryAgain etiketi` | kanıt dosyası, `a) stoppedEarly/*` blokları (Expected: not contains ...) | YEŞİL (aşama 2: shownStep kuralı, practice_outcome.dart) |
| Aynı, Döngü kullanılmış (6 widget testi) | ux_05e2: `a) loopUsed/<aday> [en\|tr]` | `a) loopUsed/*` | YEŞİL (aşama 2: shownStep kuralı, practice_outcome.dart) |
| Aynı, Bekle kullanılmış (6 widget testi) | ux_05e2: `a) waitUsed/<aday> [en\|tr]` | `a) waitUsed/*` | YEŞİL (aşama 2: shownStep kuralı, practice_outcome.dart) |
| Birim: ölçülmemiş koşuda `shownStep == tryAgain` (9 test) | ux_05e2: `c) <neden>/<aday> shownStep == tryAgain` | `Expected: NextStep.tryAgain  Actual: loopSlower/raiseTempo/performanceRun` | YEŞİL (aşama 2: shownStep kuralı, practice_outcome.dart) |
| Ham girdi doğrulaması: ölçülmemiş ve `nextStep` aday öneri (9 test) | ux_05e2: `ham oneri kontrolu: ...` | yeşil (girdi geçerli) | yeşil, regresyon koruması |
| nextLesson (gate.passed) aynen | ux_05e2: `b) ... gate gecti -> nextLesson` (birim+en+tr) | yeşil | önceden karşılanıyor (practice_outcome.dart:312) |
| checkSetup (eligible, heard<minHeard) aynen | ux_05e2: `b) ... eligible heard<minHeard -> checkSetup` | yeşil | önceden karşılanıyor (practice_outcome.dart:314) |
| checkSetup, eligible olmayan yarım koşuda da korunur | ux_05e2: `b) ... eligible olmayan yarim kosu ... checkSetup` | yeşil | önceden karşılanıyor (practice_outcome.dart:314, eligible'a bakmaz) |
| Eligible loopSlower aynen | ux_05e2: `b) eligible loopSlower` | yeşil | önceden karşılanıyor (practice_outcome.dart:316) |
| Eligible raiseTempo aynen | ux_05e2: `b) eligible raiseTempo` | yeşil | önceden karşılanıyor (practice_outcome.dart:318) |
| Eligible tryAgain aynen (yalnız minCorrect başarısız) | ux_05e2: `b) eligible tryAgain (yalniz minCorrect basarisiz)` | yeşil | önceden karşılanıyor (practice_outcome.dart:323) |
| Eligible performanceRun | yok | ULAŞILAMAZ: yalnız `!gate.eligible` dalında üretilir (practice_outcome.dart:320) | n/a |
| Sahne yolu (stage:true) değişmez | ux_05g_ghost_stage_test.dart:322-440 (mevcut) | yeşil | önceden karşılanıyor (practice_result_screen.dart:825 (`_step` → `summary.shownStep`), practice_outcome.dart:204-212) |
| id sayısı 8801 sabit (yeni metin yok) | `tool/build_message_ids.py --check` | rc 0 | yeşil |

## Bilinçli değişiklik (mevcut testler)

| Dosya: ad | Eski → yeni beklenti | Neden |
|---|---|---|
| test/ux_05g_ghost_stage_test.dart: `05g-ek: stage=false BIREBIR: <6 durum>` → `05e2: stage=false da olculmemis kosuda oneri URETILMEZ: <durum>` | loopSlower/raiseTempo/performanceRun etiketi → "Tekrar dene" (6 test) | Kural artık `shownStep`te, sahneden bağımsız; yalnız `!gate.eligible` koşular. |

Eligible/tam/ölçülmüş koşu beklentilerinden hiçbiri kırılmadı.

## `.nextStep` tüketicileri (`grep -rn "\.nextStep" lib`)

| Dosya:satır | Sonuç akışında öneri gösteriyor mu |
|---|---|
| practice_result_screen.dart:825,830 (base 1e06d8c: :835,837) | Evet: `_step` getter'ı, ana "sonraki adım" düğmesi (`_nextStep`, :839+). (base: kural yalnız `stage` iken.) Aşama 2: `_step` artık `summary.shownStep`. |
| practice_result_screen.dart:229-231 (base ve HEAD aynı satır) | Dolaylı (`result-ladder-play`). Aşama 2: koşul `_step != raiseTempo` (gösterilen adım). Ölçülmemiş koşuda bu dal ULAŞILAMAZ: `TempoLadderStepped` yalnız `cleared()` iken üretilir, o da `gate.eligible` ister (practice_tempo_ladder.dart:58-59,69-70). Test yazılmadı; eligible koşuda `shownStep == nextStep` olduğundan davranış aynı. |
| practice_outcome.dart:183 | Hayır: yalnız alan tanımı (kurucu). |
