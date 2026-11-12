# OST-UX-05g Hayalet Ekran (dört basamak): ölçüt tablosu

Dal `feat/OST-UX-05g-ghost-screen` (main 129483f). Bayrak KAPALI varsayılan.

## Süreç
Faz A: tüm ölçütlerin testi uygulamadan ÖNCE yazıldı ve kırmızı çıktı (85 test: 78 kırmızı, 7 yeşil regresyon tabanı; ham çıktı ve ham hata satırları ajan kırmızı-kanıt dosyasında). Faz B girişi: sahne entegrasyonu (koşu özeti → Hayalet store) için `test/ux_05g_ghost_run_test.dart` (10 test) uygulamadan önce yazıldı, 10/10 kırmızı ("Expected: not null / Actual: <null>": sahne `onSessionFinished` bağlamıyordu), sonra uygulandı.

## Bayrak adı farkı
Bilet `ostinatoGhostScreenEnabled` der; kodda `ostinatoGhostScreenOpen` (ostinato_release_policy.dart:71, KAPALI) var. Yeni bayrak AÇILMADI; mevcut bayrak kullanıldı (`StageHomeScreen.ghostOpen`, varsayılan `ostinatoGhostScreenOpen`). Testte yalnız test ortamında `ghostOpen: true`.

## Tasarım
- `lib/app/stage/ghost_policy.dart`: saf politika (basamak, Ek B matrisi, geçerli koşu, öneri). Basamak ASLA otomatik değişmez; `select` yalnız elle ve sayacı sıfırlar.
- Eşikler (mevcut basamakta TOPLAM geçerli koşu, ardışık değil): 1→2: 1, 2→3: 2, 3→4: 3; bağımsızda öneri yok. Sayılmayan koşu sayacı ne sıfırlar ne artırır.
- Geçerli koşu: ölçülmüş, tam (stoppedEarly değil), döngüsüz, Bekle'siz, duyulan ≥ %80, `gate.passed`; kulak ve ritim-only hariç.
- `lib/app/stage/ghost_store.dart`: ayrı dosya `ghost-screen.v1.json` (`schemaVersion:1`, level, validRuns, lastRun), geçici dosya + rename; bozuk/yanlış sürüm = Öğrenme, öneri yok. `V1PracticeRecord`, kapı ve eşikler yalnız okunur.
- Yüzey: Raf > Yardım satırı (yalnız bayrak AÇIK) → rafın kendi kaydırma alanında opak `ghost-help-surface` (cam/bulanıklık yok, GlassLayer'a girmez); dört basamak elle seçim; seçili basamağın öğeleri; öneri ve "ölçülmedi" satırları.
- Sahne `PracticeLoopScreen.onSessionFinished` ile koşu özetini alır (yalnız bayrak AÇIKken bağlanır); kulak/ritim ayrımı: `course == 'ear'`, `^ear-s\d+-`, `PracticeScore.isRhythmOnly` (sahne ders kimliğinden katalogdan bulur).
- NextStep bastırma YALNIZ sahne yolunda: `practice_result_screen.dart` `_step` (`stage && !gate.eligible` iken loopSlower/raiseTempo/performanceRun → "Tekrar dene"). `practice_outcome.dart` kuralı ve eski tüketici davranışı değişmedi.

## Motion orchestration'a işaretli karar
Kulak ve ritim-only koşular Hayalet sayacına/basamağına girmez; Hayalet enstrüman geçidini (V1 gate/course state) etkilemez. (Gitar kursundaki ritim-only A3 satırları da dışarıda tutuldu; Ek B alkış/ritmi ayrı sayıyor.)

## Ölçüt tablosu
| # | Ölçüt | Test | KIRMIZI (ham) | YEŞİL | Önceden karşılanan | Ekran kanıtı |
|---|---|---|---|---|---|---|
| 1 | Bayrak KAPALI: Yardım satırı yok; AÇIK: görünür | `ux_05g_ghost_stage_test` 05g-1 (2 test) | "Expected: no matching candidates / Found 1 widget with key [<'stage-help-row'>]"; "Found 0 widgets ... 'ghost-help-surface'" | geçti | pratik aynen: practice_loop_screen.dart:72,553 (kısmen) | — |
| 2 | Dört basamak matrisi | `ux_05g_ghost_policy_test` 05g-2; stage 05g-2 (4 test); `ux_05g_render_evidence_test` (16) | "Expected: Set:[notation,...] / Actual: Set:[]"; "Found 0 widgets ... 'ghost-level-<ad>'"; render "Found 0 widgets ... 'ghost-help-surface'" | geçti | — | `evidence/ux-05g/` 16 PNG |
| 3 | Basamak yalnız elle | policy 05g-3 (2), stage 05g-3 | "Expected: <10> / Actual: <0>"; "Expected: GhostLevel.recall / Actual: GhostLevel.learn" | geçti | — | — |
| 4 | Öneri yalnız geçerli koşuyla | policy 05g-4 (24+): her geçiş için eşik-1/eşik/eşik+1 ve 4 güvenilmez tür; stage 05g-4 (2) | "Expected: GhostLevel.reinforce / Actual: <null>" | geçti | — | — |
| 5 | "Yetkinlik kazanıldı" yok; sonuç ölçülmedi | policy 05g-5 (3), stage 05g-5 (2), metin taraması (katalog + stage_copy + Hayalet metinleri, 14 dil) | "Expected: a value greater than or equal to <14> / Actual: <0>"; "Found 0 widgets ... 'ghost-last-run'" | geçti | Sonuç ekranı "Ölçülmedi": practice_result_screen.dart:409-411,430 (kısmen) | — |
| 6 | Ayrı yerel anahtar; V1PracticeRecord/kapı/eşik değişmez | policy 05g-6 (2); run testi (yeniden açılış) | "Expected: true / Actual: <false>" (ghost-screen.v1.json yok) | geçti | — | — |
| 7 | Kulak/ritim ayrımı | policy 05g-7 (3); run testi (ear, ritim-only) | "Expected: <1> / Actual: <0>" | geçti | — | — |
| 8 | Çalarken yardım açılmaz/değişmez | stage 05g-8 | "Found 0 widgets ... 'ghost-help-surface'" (pozitif kontrol) | geçti | Raf çalarken kurulmaz/kapanır: stage_home_screen.dart `_onRun`, `if (!_playing)`; katman kilidi stage_layers.dart:17-22 (kısmen) | — |
| Ek | NextStep sahne yolu; stage=false birebir | stage 05g-ek (13) | "Expected: not contains 'Tempoyu 5 artır'" vb. (6 stage=true testi) | geçti; stage=false 6 test ve "geçit geçen" testi baştan yeşil (regresyon tabanı) | — | — |
| Genel | 390×844 / 360×640, yazı 1.3 taşma yok; Semantics tek düğüm, buton, ≥48dp | `ux_05g_overflow_test` (8), stage erişilebilirlik testi | "Found 0 widgets ... 'ghost-help-surface'" | geçti | — | PNG'ler |

## Entegrasyon (Faz B giriş) testleri
`ux_05g_ghost_run_test` 10 test: geçerli koşu sayar ve store'a yazar; 5 sayılmayan tür (stoppedEarly, ölçülmemiş/boş-yarım, loopUsed, waitUsed, duyulan<%80) artırmaz (her biri pozitif kontrol); kulak ve ritim-only etkilemez; bayrak KAPALI store'a yazmaz; yeniden açılışta basamak/sayaç geri gelir. Koşu olayı, sahnenin `PracticeLoopScreen`'e verdiği `onSessionFinished` callback'i çağrılarak enjekte edilir (gerçek bağlantı satırı sınanır; ses rig'i ile tam koşu değil).

## Değişen mevcut test satırları
- `test/stage_home_test.dart` ~538-543: açılan rafta `stage-help-row` ve 'Yardım' beklenirdi; artık varsayılan KAPALI bayrakta `findsNothing` (ölçüt 1'in kendisi).
- `test/stage_home_test.dart` ~999: düzen testinde `stage-help-row` `findsOneWidget` → `findsNothing` (aynı neden).
- `test/app_locale_preferences_test.dart:411`: `appMessageIds` sayısı 8786 → 8801 (+15 çift).
Diğer mevcut testler değişmedi.

## Eski akış notu
`NextStep` üreticisi (`practice_outcome.dart:296-310`) kısmi veride (durdurulmuş/döngülü/Bekle'li koşu) hâlâ loopSlower/raiseTempo/performanceRun üretir ve eski sonuç ekranı (`stage=false`) bunu BİREBİR gösterir: "Ölçülmedi" etiketiyle çelişen öneri eski akışta KALIR. Bu tutarsızlık bayrak/eski akış açılmadan önce ayrı bir bilette ele alınmalıdır (burada kasıtlı olarak değiştirilmedi).

## Haritadan düzeltmeler
- `PracticeSessionFinished.course` değeri `'guitar'`/`'ear'`; harita 'gtr' demişti.
- Rhythm-only bilgisi olayda yok; sahne dersi katalogdan bulup `PracticeScore.isRhythmOnly` ile belirler.
- Yardım satırı raf kaydırma alanında en altta; ilk açılışta ekran dışında olabilir (kaydırılır). Testler `ensureVisible` kullanır.

## Yerelleştirme ve bekçi
- 15 yeni `UiCopy` çifti (`ghost_level_copy.dart`), id'ler `app_message_ids.dart`ta, 14 katalogda 15'er giriş (210). `python3 tool/build_message_ids.py --check` rc=0. 12 yabancı dilde vaat/olumsuz sözcük elle kontrol edildi (yok).
- Bekçi (güncel): `openWrite` dolanması KALDIRILDI; `ghost_store.dart` standart `temp.writeAsString(json, flush: true)` + `rename` kullanır (atomiklik korunur). Bu hâliyle bekçi KIRMIZI verdi (rc=1, ham satır: "[iddia↔ölçüm yeniden-ölçüm] muaf olmayan YENİ yazıcı bulundu (lib/app/stage/ghost_store.dart) → 'saklanmıyor' beyanı taşıyan 6 özne (angle, landmark, measurement, video, your footage, history) YENİDEN SINIFLANDIRILMALI"). Sınıflandırmayı veren: Motion orchestration, 2026-11-12: `tools/validate_surface_honesty.py` `RETENTION_WRITERS_RECONCILED` kümesine yalnız `"ghost_store.dart"` eklendi (yorum: Hayalet basamak 1–4 + geçerli koşu sayacı; ölçümden türeyen özet, ham ses/poz/açı/kayıt yok; bestAccuracy/bestHeard/bestBpm ile aynı sınıf; yerel, ağa çıkmaz). Başka bekçi değişikliği yok; bekçi ek iddia↔ölçüm kaydı istemedi. Koşu rc=0, `--selftest` rc=0.
- Silme yolu: VAR. Hesap silme `deleteAccountData` (account_data_directory.dart:50-58) hesap klasörünü (`accounts/<uuid>/`) siler; ilerleme depoları (`V1PracticeProgressStore`, `V1LessonCheckStore`) bu klasörde yazar. `FileGhostStore` artık `accountUserId` alır, `accountDataDirectory` + `AccountDataOperations` kullanır (ilerleme depolarıyla aynı kuyruk; silinmiş hesaba yazma reddedilir); sahne depoyu hesap kimliğiyle kurar. Test: `test/ux_05g_ghost_delete_test.dart` (3 test; önce 2 kırmızı: "Expected: true / Actual: <false>" ve "Expected: (learn, 0) / Actual: (recall, 2)"). Hesapsız (null) yol eski yerinde (`<destek dizini>/ghost-screen.v1.json`); çıkış/hesap değiştirme yerel veriyi korur (mevcut kural). Ayrı bir "verilerimi sil" Ayarlar akışı bu depoda bulunmadı; var olan tek silme yolu hesap silme.

## Faz D (reviewer tur 1)
Testler `test/ux_05g_review1_test.dart` (8 test) önce yazıldı; 5'i kırmızı (D1, D3, D5 ×2, D7), uygulamadan sonra hepsi yeşil. Ham kırmızı satırlar kırmızı-kanıt dosyasında.
| # | Madde | Sonuç | Kanıt |
|---|---|---|---|
| D1 | `stage-help-row` ve `ghost-level-*` Semantics `onTap` yoktu | KAPANDI (`onTap` eklendi, `device_layer.dart:187-192` örüntüsü) | kırmızı "Expected: true / Actual: <false>" (`hasAction(tap)`); yeşil: eylem var, tetiklenince yüzey açılır, basamak seçilir |
| D2 | Sahne eski P0-07 panelini bayrak açıkken göstermemeli | KAPANDI (`ghostScreen: false` sahnede açık verildi) | KIRMIZI ÜRETİLEMEDİ: `ostinatoGhostScreenOpen` `const false`, testte açılamaz; test sahnenin verdiği `ghostScreen` değerini okur ve `ghost-toggle` yokluğunu sınar. Eski akış (stage KAPALI) `ghost_screen_test` 18 yeşil |
| D3 | "Bu basamakta görünenler" yanıltıcı | KAPANDI: "Bu basamağın yardımları" / "Help items for this level"; eski çift tablo ve 14 katalogdan çıkarıldı, yenisi eklendi | id sayısı 8801 (değişmedi), `--check` rc=0, bekçi rc=0, 12 dil elle kontrol; sınır notu: seçim pratik ekranında henüz uygulanmıyor (NOT_TESTED) |
| D4 | Ek B "bu bölümde bu basamakta" der | AÇIK karar, kod değişmedi | Ek B ile sapma: sayaç hesap geneli (ders/bölüm ayrımı yok); ölçüt 4 yalnız eşik sayısını verir; bayrak açılmadan önce Motion orchestration kararı gerekir |
| D5 | Yardım açılınca yüzey ekran dışında kalıyordu | KAPANDI (`_EnsureVisible`, açılışta bir kez `Scrollable.ensureVisible`, animasyonsuz) | kırmızı: 360×640 ve 390×844 yüzey ekran dışı; yeşil; 8 yeni PNG: `05-olculmedi-*`, `06-oneri-*` (360×640 ve 390×844, açık/koyu), 360×640 açık ikisi Read ile kontrol edildi, metin kesilmiyor |
| D6 | Yabancı katalog taraması yalnız tr/en | KAPANDI (yeşil ön-fix; test eklendi) | 15 çift × 14 dil, bekçinin `PROMISE_PATTERNS` listesi dosyadan okunur (bekçi değişmedi) + dil başına kök listesi; tarayıcı kontrol testi |
| D7 | Hesap değişince `_ghost` sıfırlanmıyor, eski okuma ezebilir | KAPANDI (`_ghostEpoch` guard, hesap değişince sıfırlama, `ghostStoreFactory`) | kırmızı "Found 0 widgets ... 'ghost-item-preStartPreview'"; yeşil: eski hesabın geç okuması yeni hesabı ezmez |
| D8 | Eskimiş yorumlar; Yardım satırı düzen testi | KAPANDI | "skeleton" yorumu düzeltildi; render testi başlık yorumu `ux_05g_...`'ye çevrildi; bayrak KAPALI/AÇIK Yardım satırı varlığı `ux_05g_ghost_stage_test` 05g-1 (iki test) ve overflow testleri ile sınanıyor; `stage_home_test` ~999 KAPALI varsayılanda `findsNothing` |

Test sayıları (hepsi yeşil): ux_05g policy 35, run 10, stage 26, delete 3, overflow 8, review1 8, render 24 (16 basamak + 8 yeni durum); stage_home_test 87, ghost_screen_test 18, app_locale_preferences_test 20, practice_footer_honesty_test 2, ux_05e_result_layer_test 27, practice_result_test 18, ux_05f_* 112. Tam proje `flutter analyze` 0 sorun. Mesaj id'si 8801.

## NOT_TESTED
Gerçek cihazda Hayalet yüzeyi; ses rig'iyle uçtan uca tam koşu → sayaç; Hayalet seçiminin pratik ekranındaki nota/tab/etiket/vuruş görünürlüğüne GERÇEKTEN uygulanması (bu bilet yüzey, seçim, öneri ve store'u kapsar; matris yüzeyde ve politikada sabit, pratik ekranı rehber gizleme uygulaması ayrı bilet). Hesap silme kapsamı artık çözüldü (yukarıdaki "Silme yolu"); gerçek hesap silme akışıyla uçtan uca doğrulama NOT_TESTED (birim testi `deleteAccountData` ile).
