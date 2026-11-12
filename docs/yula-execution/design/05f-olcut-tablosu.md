# OST-UX-05f ölçüt tablosu (İzin reddi, kurulum ve Ayar/Cihaz; bayrak KAPALI)

Testler: `test/ux_05f_listening_off_test.dart` (L), `test/ux_05f_device_layer_test.dart` (D), `test/ux_05f_camera_zero_test.dart` (K), `test/ux_05f_overflow_test.dart` (O), `test/ux_05f_render_evidence_test.dart` (R), `test/ux_05f_review1_test.dart` (D1, Faz D), `test/ux_05f_review2_test.dart` (E, Faz E); destek `test/support/ux_05f_rig.dart`. Kırmızı koşu (Faz A, İSKELET ile): 33 test, 28 kırmızı, 5 önceden yeşil; ham satırlar scratchpad `05f-kirmizi-kanit.md`'den birebir. Faz B (6398921) sonrası: 33/33 yeşil. Faz C'de eklenenler: O (taşma) ve R (render kanıtı).

**Süreç sapması (dürüst not):** Faz C taşma testleri (O) ve render testi (R) üretim kodu yazıldıktan SONRA yazıldı; kırmızı kanıtı yoktur (koruma/kanıt testleridir). O içindeki kırmızı test (360×640 kip + raf açık) Faz D/E'de çözüldü (bkz. Bulgu ve Faz E). Güncel durum: `flutter test test/ux_05f_*.dart` TAMAMI yeşil (sayı en sonda).

| # | Ölçüt | Test (dosya) | KIRMIZI koşu (ham) | YEŞİL | Önceden karşılanıyor / dosya:satır | Ekran |
|---|---|---|---|---|---|---|
| 1 | T7 kip: reddedilince "Dinleme kapalı" | L `05f-1a` (tr), `05f-1b` (kalıcı red), `05f-1c` (en) | 1a: `Expected: exactly one matching candidate / Actual: _KeyWidgetFinder:<Found 0 widgets with key [<'stage-listening-off'>]: []>` (L:47); 1b aynı (L:54); 1c: `Found 0 widgets with text "Listening is off"` (L:60) | yeşil | — | 02-izin-reddi-* |
| 1d | İzin verilince kip YOK | L `05f-1d` | — | yeşil | **ÖNCEDEN YEŞİL**: kip henüz yoktu | 01-sahne-* |
| 1e | ✓◆◯ yok, sayaç "ölçülmüyor" | L `05f-1e` | `Expected: no matching candidates / Actual: _TextContainingWidgetFinder:<Found 1 widget with text containing ✓: [` (L:78; kaynak `practice-count-correct`) | yeşil | — | 02-izin-reddi-* |
| 1f | Şerit/metronom/referans/kulak/akort erişilir | L `05f-1f` | `Found 0 widgets with key [<'stage-listening-off'>]` (L:92) | yeşil | `mic_permission_gate_test.dart` ve `stage_home_test.dart` "a failed start" yeşil kaldı | |
| 1g | Kip etiketi Semantics ile okunur | L `05f-1g` | `Expected: at least one matching candidate / Actual: _ElementPredicateWidgetFinder:<Found 0 widgets with a semantics label matching the pattern` (L:112) | yeşil | — | |
| 2 | "Ayarlara git" sürekli, hook ile çağrılır | L `05f-2a` | `The finder "Found 0 widgets with key [<'stage-open-settings'>]: []" (used in a call to "tap()") could not find any matching widgets.` | yeşil | — | 02-izin-reddi-* |
| 2b | Gizle (eski etiket Sustur) bağlantıyı gizler, kip kalır | L `05f-2b` | `Expected: exactly one matching candidate / Actual: _TextWidgetFinder:<Found 0 widgets with text "Sustur": []>` (L:157; Faz A ham satırı, etiket Faz D'de "Gizle" oldu) | yeşil | — | |
| 2c | Yeni ağaçta (aynı store) susturma kalır | L `05f-2c` | (2c satırı ham çıktıda ayrı blok vermedi; 2b ile aynı yüzeyden kırmızıydı: iskelette bağlantı/gizle düğmesi yoktu) | yeşil | — | |
| 2d | Dosya store kalıcı, `shared_preferences` yok | L `05f-2d` | `Expected: true / Actual: <false>` | yeşil | — | |
| 2e | Bağlantı/Gizle buton, ≥48 dp | L `05f-2e` | `Expected: exactly one matching candidate / Actual: _KeyWidgetFinder:<Found 0 widgets with key [<'stage-open-settings'>]: []>` (L:210) | yeşil | — | |
| 3 | T8 kamera: bayrak KAPALI, çağrı sayısı 0 | K `05f-3a` (bayrak), `05f-3b` (sahne+red) | — | yeşil | **ÖNCEDEN YEŞİL**: `ostinato_release_policy.dart:46` (`ostinatoCameraPracticeAvailable=false`); sahne/izin yolunda `Permission.camera` yok (permission_handler kanalı sayılır) | — |
| 3c | Red + Ayar/Cihaz açık: kamera 0, katman ulaşıldı | K `05f-3c` | `Expected: exactly one matching candidate / Actual: _KeyWidgetFinder:<Found 0 widgets with key [<'stage-device-layer'>]: []>` (K:67) | yeşil | — | 03-ayar-cihaz-* |
| 4 | Ayar katmanı açılır (varsayılan config) | D `05f-4a` | `Found 0 widgets with key [<'stage-device-layer'>]` (D:48) | yeşil | — | 03-ayar-cihaz-* |
| 4b | Mikrofon durumu (verildi/reddedildi/kalıcı; en) | D `05f-4b` x3, `05f-4b-en` | `Found 0 widgets with key [<'stage-device-mic'>]` (D:61); en: `Found 0 widgets with text "Microphone: allowed"` (D:70) | yeşil | — | |
| 4c | Gecikme kalibrasyonu girişi | D `05f-4c` | `Found 0 widgets with text "Gecikme kalibrasyonu"` (D:80) | yeşil | `openSetupWizard` ekranı değişmedi (`setup_wizard_test` yeşil) | |
| 4d/4e | Ortam gürültüsü: veri yok "ölçülmedi"; profilden okuma | D `05f-4d`, `05f-4e` | `Found 0 widgets with text "Ortam gürültüsü: ölçülmedi"` (D:90); `... "Ortam gürültüsü: sessiz"` (D:108) | yeşil | — | |
| 4f | Ayarlar ve Hesap tam ekran çıkış | D `05f-4f` | `The finder "Found 0 widgets with key [<'stage-device-settings'>]: []" (used in a call to "tap()") could not find any matching widgets.` | yeşil | — | |
| 4g | Çalarken katman açılamaz (05c) | D `05f-4g` | — | yeşil | **ÖNCEDEN YEŞİL**: çalarken tutamaklar yok (`stage_home_screen.dart` `if (!_playing)`) | |
| iii | Reddedilince akort kartı gizlenmez; "Ayarlara git" + akortçu | L `05f-iii`, `05f-iii2` | iii: `Found 0 widgets with key [<'session-tuning-gate'>]` (L:122); iii2: `Found 0 widgets with key [<'stage-open-settings'>]` (L:130) | yeşil | Eski akışta `_ranOnce` kartı gizler (`practice_loop_screen.dart:466-467`), DEĞİŞTİRİLMEDİ; sahne bandı aynı kartı gösterir | 02-izin-reddi-* |
| 5 | Gerçek cihazda reddedilmiş izin "Başlat" davranışı | — | — | **NOT_TESTED** (gerçek cihaz; kurucu cihazı) | — | — |
| 6 | Ham ses çıkmaz, kalıcı kayıt yok | D `05f-6`; mevcut `ost_p0_08_recording_retention_test` | — | yeşil | **ÖNCEDEN YEŞİL**: `ostinato_release_policy.dart:77` (`ostinatoRecordingRetentionOpen=false`); `test/flutter_test_config.dart` sıfır-ağ geçersiz kılması tüm testlerde | — |
| G1 | Bayrak KAPALI = eski akış birebir | mevcut `stage_home_test` (bayrak KAPALI grubu), `library_fold_test` | — | yeşil (stage_home 87/87) | `PracticeLoopScreen.listeningOff` varsayılan false; eski şerit aynı | — |
| G2 | 390×844 ve 360×640, yazı 1.3: kip + katman taşma yok | L `05f-ovf` x2, D `05f-ovf` x2; O `05f-ovf2` (kip+raf açık, kip+Çal, katman) | L/D: `Found 0 widgets with key [<'stage-listening-off'>]` / `[<'stage-device-layer'>]`; O: bkz. Bulgu | L/D yeşil; O: Faz C'de 360×640 kip+raf AÇIK KIRMIZIYDI, Faz D/E sonrası YEŞİL | — | tüm PNG'ler |
| G3 | Semantics: kip etiketi, düğmeler ≥48 dp | L `05f-1g`, `05f-2e`; D `05f-a11y` | `05f-a11y`: `Found 0 widgets with key [<'stage-device-latency'>]` (D:167) | yeşil | — | |

## Bulgu (Faz C; Faz D'de ÇÖZÜLDÜ, R6)
`05f-ovf2: mode ON + tool shelf OPEN, 360x640, text 1.3` Faz C'de KIRMIZIYDI (şimdi YEŞİL, Faz D/E): `BoxConstraints has a negative minimum height` (practice_loop_screen `LayoutBuilder`) ve `A RenderFlex overflowed by 46 pixels on the bottom`. Kontrol testi (kip YOK, raf açık, aynı boyut) YEŞİL; yani taşmayı kip bandı + açık raf birlikte yaratıyor. 390×844 kip+raf yeşil. 360×640'ta kip bandı kısa ekranda (≤700 dp) en çok ekranın %25'i, uzun ekranda 340 dp; alt kenarı kırpılıyor ve akort kartı band içinde kaydırarak görülüyor (02-izin-reddi-360x640-*).

## Ekran kanıtı
`docs/yula-execution/design/evidence/ux-05f/` : `01-sahne`, `02-izin-reddi`, `03-ayar-cihaz` x {390x844, 360x640} x {acik, koyu} = 12 PNG (`UX_RENDER=1 flutter test test/ux_05f_render_evidence_test.dart`). Test fontunda bazı glifler kutu çıkar (05d/05e'deki gibi); yazı düzeni gerçek.

## Tasarım kararları
- Kip yalnız `controller.failure == 'permission'` okumasından türer (yüzey düzeyi); izin akışı (MicPermissionGate, AudioInputController, PracticeSessionController) değişmedi.
- "Ayar" tutamağı her konfigürasyonda `StageLayer.setup` açar (layerBuilder verilmişse özel içerik).
- Susturma kaydı: `FileListeningOffStore`, boş işaret dosyası `stage-settings-hint.muted` (`create()`; yüzey dürüstlüğü kapısı yeni yazıcıyı reddettiği için `writeAsString` kullanılmadı); yeni bağımlılık yok.
- Sayaç, mikrofon şeridinde (✓◆◯ yerine "Sayaç: ölçülmüyor"); `PracticeLoopScreen.listeningOff` yalnız sahne parametresi.
- Ortam gürültüsü yalnız kurulum profilinden okunur; veri yoksa "ölçülmedi".
- Kamera sayımı permission_handler platform kanalı üzerinden (enjekte noktası tek değil).

## Bayrak açılmadan önce notlar
- Açılışta mikrofon durumu okunmaz; kip yalnız "Çal"dan sonra `failure=='permission'` ile girer (Ayar katmanı durumu kendi okur).
- 12 yabancı dil çevirisi makine kalitesinde; yerel anlam incelemesi yok.
- Akort kartı eski akışta `_ranOnce` ile gizli kalır; sahne bandı aynı kartı gösterir.
- Gerçek cihaz (ölçüt 5) NOT_TESTED. 360×640 taşma bulgusu ÇÖZÜLDÜ (Faz D/E).

## Faz B'de değiştirilen mevcut test satırları
- `test/stage_home_test.dart` "handles show and call the injected callback": Ayar artık katman açıp "Yolum" tutamağını örttüğü için setup dokunuşundan sonra scrim ile kapatma iki satırı eklendi (`stage-layer-scrim` dokunuşu + `pumpAndSettle`); beklentiler aynı.
- `test/app_locale_preferences_test.dart`: `hasLength(8771)` -> `hasLength(8785)` (14 yeni çift).

## Faz D (reviewer tur 1; kırmızı ham satırlar: scratchpad `05f-kirmizi-kanit.md` "## Faz D")
Süreç: önce test (D1, kırmızı koşu +40 -26), sonra uygulama (D2). Sonuç: `flutter test test/ux_05f_*.dart` 78/78 yeşil (render 12 dahil); hedefli koşu (ux_05f, stage_home, mic_permission_gate, retention, app_locale_preferences, practice_footer_honesty, setup_wizard, ui_copy_catalog, ux_05e_result_layer) +305 yeşil; analyze (tam proje) temiz; `build_message_ids.py --check` rc=0; `validate_surface_honesty.py` rc=0. Mesaj kimliği sayısı 8785 -> 8786 (4 çift çıktı, 5 çift girdi).

| R | Madde | Test | KIRMIZI (ham) | Durum |
|---|---|---|---|---|
| R1 | Kip metni dürüst: akortçu mikrofon ister; kart + Ayarlara git yan yana | D-R1a/b/c (ux_05f_review1) | `Found 0 widgets with text "Mikrofon izni verilmediği için ölçüm yapılmıyor. Metronom ve referans çalışır; akortçu mikrofon ister."` | KAPANDI (R1c tek başına yeşil: koruma) |
| R2 | Nötr mikrofon satırı: izin yok / izin kapalı / kısıtlı | 05f-4b x3, D-R2 | `Found 0 widgets with text "Mikrofon: izin yok"` (ve "izin kapalı", "kısıtlı"); D-R2: `Found 1 widget with text containing reddedil` | KAPANDI |
| R3 | Mikrofon satırı Ayarlara git (susturulmuş kipte de) | D-R3a/b/c | R3a: `Found 0 widgets with text "Ayarlara git"`; R3c: `Expected: <1> Actual: <0>` | KAPANDI |
| R4 | Resume okuma-only; retry titremesiz; katman tazelenir | D-R4a/b/c/d | R4a: `Found 0 widgets with key [<'stage-listening-off'>]`; R4c: `Found 0 widgets with text "Mikrofon: verildi"`; R4d: kip kesintisiz iddiası | KAPANDI |
| R5 | Gerçek yollar | D-R5a (gerçek SettingsScreen), D-R5b (gerçek SetupWizardScreen), D-R5c | ilk koşuda test hatası (kapsam sarması, zamanlayıcı) düzeltildi; yeni ürün davranışı yok | KAPANDI; **NOT_TESTED**: bağlı hesapla Hesap/Üyelik varsayılan yolu (hesap bağlantısı test ortamında kurulamıyor; "bağlantı yok -> satır yok" ve hook çağrısı sınandı) |
| R6 | Taşma: raf açıkken kip tek satır, raf kapalıyken bounded kaydırma | `05f-ovf2` (overflow_test), D-R6a/b/c | `BoxConstraints has a negative minimum height` + `A RenderFlex overflowed by 46 pixels on the bottom` | KAPANDI; band uzun ekranda 340 dp, kısada %25 içinde kayar |
| R7 | Katman satırı tek düğüm; gürültü satırı dönüşte tazelenir | D-R7a, D-R7b | R7b: `Found 0 widgets with text "Ortam gürültüsü: sessiz"`; R7a sabotajla bile yeşil | KAPANDI (R7a koruma) |
| R8 | Kamera `ostinatoCameraLessonsOpen` da kapalı | 05f-3a | koruma, kırmızı yok | KAPANDI |
| R9 | Tautoloji kalktı; tuner dokunuşu hook'la; 1e kontrol; şerit/referans/kulak dokunma | 05f-iii2, 05f-1f, 05f-1e-control | iii2: `Expected: <1> Actual: <0>` | KAPANDI |
| R10 | "Sustur" -> "Gizle"/"Hide" (12 dil) | 05f-2b | `Found 0 widgets with text "Gizle"` | KAPANDI |
| R11 | Okuma-only: izin isteği yok | D-R11 | ilk yazım test hatası (sayaç zamanı) düzeltildi | KAPANDI |
| R12 | liveRegion | — | — | **05h'ye** bırakıldı |

Değişen mevcut test beklentileri (Faz D): `05f-4b` metinleri (R2), `05f-2b` "Sustur" -> "Gizle" (R10), `05f-ovf2` izin metni, `app_locale_preferences_test` `hasLength(8785)` -> `hasLength(8786)`. Zayıflatma yok; `05f-iii2` tautolojik `||` iddiası gerçek iddiaya çevrildi (R9).

Ekran kanıtı Faz D: 12 PNG yeniden üretildi. 360x640 izin-reddi PNG'sinde band, "Ayarlara git" ve "Gizle" kesilmiyor; akort kartı band içinde kısmen görünüyor (kaydırılır).

Bayrak açılmadan önce ek notlar (Faz D): akort kartı 360x640'ta yalnız kısmen görünür, kaydırmayla ulaşılır; raf açıkken kart gizlenir (tek satır kip); bağlı hesapla Hesap/Üyelik varsayılan yolu NOT_TESTED.

## Kapsam notu: erişilebilirlik (04-backlog-ux-05.md:82)
Backlog kapsam satırı Ayar/Cihaz için "erişilebilirlik" sayar; ölçüt 1-6'da bunun ayrı bir maddesi yok ve Ayar katmanında erişilebilirlik ayarı (yazı boyutu, hareket azaltma vb.) YAPILMADI. Yalnız genel Semantics/≥48 dp/yazı 1.3 ölçütleri karşılandı (G2, G3). Katmanda erişilebilirlik ayarı satırı ve canlı bölge (liveRegion) duyuruları **05h'ye** bırakıldı.

## Faz E (reviewer tur 2; kırmızı satırlar: scratchpad `05f-kirmizi-kanit.md` "## Faz E")
Süreç: önce test (`ux_05f_review2_test.dart`), sonra uygulama. Her test tek tek koşuldu; art arda koşuda sızıntı gözlendi (Faz D notu geçerli).

| E | Madde | Test | KIRMIZI (tek başına) | Durum |
|---|---|---|---|---|
| E1 | Retry başka sebeple düşünce kip kapanır; başarılı başlangıçta kapanır; aynı red kalır | E1a, E1b, E1c | E1a: `Expected: no matching candidates / Actual: _KeyWidgetFinder:<Found 1 widget with key [<'stage-listening-off'>]` (kip eski sebebi söylemeye devam ediyordu). E1b/E1c: koruma (E1b ilk yazımda koşunun `running` evresine varmayan TEST hatasıydı; `listen05f` ile düzeldi) | KAPANDI (`_onRun`: `failure != null && != 'permission'` kipi kapatır) |
| E2 | Yeni ders ekranı (`_epoch`) kendi başına karar verir | E2 | koruma (kırmızı yok); ürün: kip "failure durduğu sürece" yaşar, ders/ekran değişince taşınmaz; `_lastFailure` yeni denetleyicide sıfırlanır (savunma) | KAPANDI |
| E3 | Uzun yabancı etiketler, 360×640 + yazı 1.3 + raf açık + kip (de, fr, pt-BR, id, it, pl; gerçek katalog) | E3 x6 (+ E3-control x6 kipsiz) | fr/pt-BR/it: `BoxConstraints has a negative minimum height` (raf kapalı kip bandı); de/id/pl: `A RenderFlex overflowed by 54/36 pixels on the right` (tek satır kompakt ilk tasarım); kontrol (kipsiz) YEŞİL | KAPANDI: raf açıkken kip yalnız başlığı başlık satırına koyar (ek yükseklik 0), band sınırı kısa ekranda %25; bağlantı bandın başlık altına alındı |
| E4 | Raf açık + Gizle yapılmış: izin yolu Ayar katmanında | E4 | koruma (yeşil) | KAPANDI; **bilinçli**: kompakt kip yalnız başlık gösterir, alternatif Ayar katmanındaki mikrofon satırıdır (hook çağrılır) |
| E5 | `restricted` ve okuma hatası | — | — | **Tablo notu (kod değişmedi)**: `restricted` (ebeveyn/kurum kısıtı) durumunda mikrofon satırı da "Ayarlara git" gösterir; uygulama ayarı bunu çözmeyebilir, ama kullanıcıyı sistem ayarına götürmek zararsızdır. `micStatus` hata fırlatırsa satır yalın "Mikrofon" gösterir ve dokunulmaz |
| E6 | Raf sınırı rect iddiası | E6 | koruma (yeşil) | KAPANDI (raf ekranın içinde, `0.2*h + 80` altında). D-R7a "koruma" olarak kalır |
| E7 | Render kanıtı: raf açık kompakt kip; sayaç görünür | R: `04-izin-reddi-raf-acik-*`, `05-izin-reddi-sayac-*` (390×844 ve 360×640, açık/koyu = 8 PNG) | — | KAPANDI; `02-izin-reddi-*` PNG'lerinde sayaç kıvrımın altında kalır: 1e'nin ekran kanıtı `05-izin-reddi-sayac-*` (Read ile bakıldı: "Sayaç: ölçülmüyor" ve Çal görünür) |
| E8 | Tablo tutarlılığı | — | — | KAPANDI (bu belge) |
| E9 | l10n | — | — | Metin DEĞİŞMEDİ: kimlik sayısı 8786, `--check` rc=0 |

Faz E'de değişen mevcut test beklentisi: `D-R6a` (Faz D testi): raf AÇIKken "Ayarlara git" bağlantısı artık yok (kompakt kip yalnız başlık; E3'ün taşma ölçütü bunu gerektirdi); test, raf kapanınca bağlantının görünür ve çalışır olduğunu ve raf açıkken kipin başlığının görünür olduğunu iddia eder.

Güncel test sayısı: `flutter test test/ux_05f_*.dart` +104 yeşil (render 20 dahil, 0 skip). Mesaj kimliği sayısı 8786. analyze temiz; `--check` rc=0; bekçi rc=0.

## Reviewer tur 3 (delta cfb13ee → c7577d6): KOŞULLU → düzeltildi
- Düzeltildi: E6 testi sınırı kodla aynı (`0.2*h + 80`); tablo satırları (G2 YEŞİL, kip bandı %25 / uzun ekranda 340 dp) tutarlı.
- Bayrak açılmadan önce, DÜŞÜK notlar (kod değişmedi): (a) kompakt kip (raf açık) yalnız "Dinleme kapalı" başlığını gösterir; neden/eylem metni ve "Ayarlara git" ipucu yok, izin yolu Ayar tutamağı → mikrofon satırı (2 dokunuş) ya da rafı kapatınca tam band; (b) reddedilmiş denemeden sonra `starting` iken Geri/Durdur ile kip `failure==null` ile açık kalabilir, sonraki Çal ya da resume düzeltir, testsiz; (c) kompakt dalda `title`/`links` küçük ölü hesap.

- CI notu (2026-11-12): koşu `43097319687` GitHub runner kuyruğunda takıldı (cancel/rerun/force-cancel olmadı); yeniden tetikleme için boş commit atıldı, kod değişmedi. Yerel tam süit kanıtı `c7577d6` + test sınırı commit `6af3a2e`: +2407 yeşil.
