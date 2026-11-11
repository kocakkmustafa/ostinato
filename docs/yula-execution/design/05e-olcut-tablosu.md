# OST-UX-05e ölçüt tablosu (Sonuç katmanı ve dürüst durum; bayrak KAPALI)

Test dosyası: `test/ux_05e_result_layer_test.dart` (T). Kırmızı kanıt (ham): scratchpad `05e-kirmizi-kanit.md`; kırmızı koşu iskelette alındı (`stage` parametresi + `result_layer_copy.dart` sabitleri, davranış yok): +9 -13. Sonra: T 22/22 yeşil.

| # | Ölçüt | Test (T = ux_05e_result_layer_test) | ÖNCE-KIRMIZI ÇIKTI | Sonra | Ekran | Not |
|---|---|---|---|---|---|---|
| 1 | İçerik korunur (stage'de de) | T `olcut1 ... counts, error map, gate, retry` | KORUMA testi, kırmızı beklenmez (ilk koşuda yeşil) | yeşil; practice_result_test 18/18 | 01-normal-* | stage=false ekran birebir (T `flag-closed screen`) |
| 2 | Altı HearingReason nötr metin, "yanlış/wrong" yok | T `olcut2 ... <sebep>: a neutral line` x6 (tr+en) | `Found 0 widgets with key [<'result-reason-noAttack'>]` (aynı hata tooQuiet/tooLoud/unclear/appPlayback/skipped; T:260) | yeşil | 02-sebepler-* | 5 yeni çift + unclear (`ListenTryFixCopy.couldNotMeasure`) yeniden kullanıldı; sebep başına satır + nota sayısı |
| 2b | Satır başına sayı | T `one row per reason, with how many notes` | `Found 0 widgets with key [<'result-reason-noAttack'>]` | yeşil | | |
| 2c | 14 dil, yeni kimlikler, vaat/yargı sözcüğü yok | T `the new pairs are in all 14 catalogs` | `Expected: true Actual: <false> (I didn't hear a note start here., Burada ...)` | yeşil; `build_message_ids.py --check` rc=0; app_locale_preferences 20/20 (hasLength 8771); ui_copy_catalog 54/54 | | 12 dil elle yazıldı; regex: ainda/ancora/noch/aún/まだ/아직/jeszcze/belum/अभी/还没有/بعد/pour l'instant |
| 3 | Duyulan % doğruluktan ayrı; doğruluk yalnız karar verilenlerde | T `olcut3 ... accuracy is over decided notes` (stage) | kırmızı yok: ÖNCEDEN KARŞILANIYOR (practice_result_test.dart:66-73) | yeşil | | **ÖNCEDEN KARŞILANAN** |
| 4 | Duyulan <%80 -> checkSetup | yeni test yok | ÖNCEDEN KARŞILANIYOR (practice_result_test.dart:74,84-89) | yeşil | | **ÖNCEDEN KARŞILANAN**, eşik değişmedi |
| 5 | Yarım/döngü/Bekle = "Ölçülmedi" etiketi, geçit açılmaz | T `olcut5 ... stopped early / loop used / wait used` | `Found 0 widgets with key [<'result-not-measured'>]` (x3; T:352) | yeşil | 03-olculmedi-* | Etiket yalnız stage'de ve eski "Pratik turu" başlığının YERİNE (çift mesaj yok); neden satırları aynı; geçit kısmı ÖNCEDEN (practice_result_test.dart:132-141); metin `Ölçülmedi` mevcut kimliği paylaşır |
| 6 | Gürültü/çok sesli: ◯ + sebep, yargı yok | T `olcut6 ... unclear pitch` (W) | `Expected: ... Found 0 widgets with key [<'result-reason-unclear'>]` (ilk yazımda sayaç aramasındaki hata test düzeltmesiyle giderildi) | yeşil; corpus 19/19 | 02-sebepler | `wrong==0` ürün yolu ÖNCEDEN: ost_p0_04 corpus ~384 |
| 7 | T4/T5: Tekrar dene aynı bölüm/döngüde; çubuk = döngü; rafta görünür | T `retry keeps the loop bars` + `a bar tap loops it; the stage shelf shows that range` | kırmızı yok: ZATEN KARŞILANIYOR (ilk koşuda yeşil) | yeşil; stage_home 87/87 | | **ÖNCEDEN KARŞILANAN**; çubuk dokunuşu ayrıca practice_result_test.dart:398-423. Dikkat: döngü yalnız koşu BAŞLAMADAN ayarlanır (`_edit` koşarken yok sayar) |
| 8 | Çalarken sonuç çıkmaz; yalnız Dur sonrası | T `olcut8 ... while playing no result; after Stop` | `Found 0 widgets with key [<'result-not-measured'>]` (T:418; `stage` bağlantısı iskeletteydi) | yeşil | | Koşu sürerken PracticeResultScreen/result-* yok kısmı ilk koşuda yeşil; `no Stop, no result` yeşil; Dur'a basmadan geri ÖNCEDEN: stage_home_test.dart ~739 |

## Koşular
analyze: No issues found. Testler: ux_05e_result_layer 22, practice_result 18, practice_session 6, listen_try_fix_screen 10, stage_home 87, ui_copy_catalog 54, app_locale_preferences 20, ost_p0_04 corpus 19, practice_screen 6, glass_layer 29, ux_05e_render 12: hepsi yeşil. (`practice_outcome_test.dart` diye dosya yok.)

## Render
`docs/yula-execution/design/evidence/ux-05e/` : 01-normal, 02-sebepler (altı durum bir sayfada), 03-olculmedi x {390x844, 360x640} x {acik, koyu} = 12 PNG (`UX_RENDER=1`). Test fontunda simge/mono glifleri kutu çıkar (05d'deki gibi); yazı düzeni gerçek.

## NOT_TESTED
Gerçek cihazda/mikrofonla gerçek gürültü ve sebep dağılımı; ekran okuyucu ile sebep satırları; 14 dilde görsel taşma (yalnız tr render alındı).
Not: durmuş koşuda `nextStep` yine "Tüm diziyi hedef tempoda çal" önerebiliyor (mevcut `NextStep` kuralı, değiştirilmedi).
