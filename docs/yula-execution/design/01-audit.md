# Ostinato — Mevcut arayüz ve deneyim envanteri (OST-UX-01, Aşama 1)

Tarih: 2026-11-09 · Taban: `origin/main` `1fa8b93ac43cc663b4578047481a7d89c4211212` (pubspec `1.0.1+10`) · Mağaza kaynağı: `origin/release/1.0.2` `4f399e7f77a0b38cb59f2b419060f91b5f83374d` (`1.0.2+11`).
Dayanak: kurucu emri 2026-11-09, "Dört Ürün Arayüz ve Deneyim Talimatı" §7 Aşama 1. YALNIZ BELGE: kod, tema, renk, kurs, ölçüm ve ilerleme sistemi bu işte değişmedi. Yöntem: statik kaynak okuma (okuma + grep); test koşturulmadı, uygulama bu belge için çalıştırılmadı. Ürün gerçeği: gitar + kulak eğitimi (`docs/yula-execution/DECISIONS.md` ADR-001); eski `README.md` ve `docs/ostinato-plan.md` kodun altındadır (ADR-003).
Doğrulama kodları: **K** = kaynakta okundu · **T** = testte var (koşturulmadı) · **U** = doğrulanamadı.

## 1. Mevcut ekranlar ve amaçları

Giriş: `lib/main.dart` (`OstinatoHome`, satır ~370–428) kabuğun tek dallanma noktasıdır: karşılama bitmediyse `OnboardingScreen`, bittiyse `LibraryScreen` (bayrak açıksa önce `FirstThreeMinutesScreen`). Satır sayıları `wc -l` ile alındı.

| Ekran | Dosya | Amaç (kaynaktaki belge yorumundan) |
|---|---|---|
| Karşılama (3 sayfa: karşılama, kapsam, sensör/veri) | `lib/app/screens/onboarding_screen.dart` (464) | İlk açılış; izin BURADA istenmez, açıklanır (dosya yorumu). Mikrofon, kamera, "tıbbi araç değil", ilerleme kartları |
| İlk üç dakika | `lib/app/first_minutes/first_three_minutes_screen.dart` (618) | Ritim dokunma / ses / "enstrümanım var" üç başlangıç. BAYRAK KAPALI (bölüm 8) |
| Kütüphane (ana ekran) | `lib/app/screens/library_screen.dart` (606) | Giriş ekranı: tanıtım kartı, "Dersleri incele" şeridi, haftalık hedef kartı, akort aleti, çalgı kartları (gitar; ses ve piyano "Yakında"), kulak eğitimi kartı |
| Ayarlar | `lib/app/screens/settings_screen.dart` (577) | Görünüm (açık/koyu), dil, hesap, üyelik, kamera/mikrofon beyanı, kendi kaydım (opt-in), pratik ekranı (solak, renk körü), paylaşım |
| Çalgı sayfası | `lib/app/screens/instrument_screen.dart` (566) | Açık çalgı için sayfa: `MeasuredPracticeCard`, `NoteObservationCard`, `library.json` kurs listesi |
| "Yakında" çalgı sayfası | `lib/app/screens/coming_soon_instrument_screen.dart` (101) | Açık olmayan çalgı (ses, piyano); ders açmaz |
| v1 kurs listesi (gitar, kulak) | `lib/app/practice/loop/v1_practice_list_screen.dart` (827) | Seviye, modül, ders; ölçülü ders pratiği açar, diğerleri okuyucuyu |
| Ders okuyucu | `lib/app/practice/loop/v1_lesson_reader_screen.dart` (610) | Hedef, anlatım, görev, "ölçülmeyen" notu, öz-kontrol; akort/alıştırma/test akışına çıkış |
| Pratik ekranı | `lib/app/practice/loop/practice_loop_screen.dart` (1003) | Akan TAB, sabit ŞİMDİ çizgisi, görsel vuruş, her zaman görünür mikrofon şeridi, ✓/◆/◯ sayaçları, başla/durdur |
| Pratik sonucu | `lib/app/practice/loop/practice_result_screen.dart` (809) | Doğruluk, duyulan, zamanlama, tempo basamağı, hata haritası, geçit; "tekrar dene", "sonraki ders" |
| Kurulum sihirbazı | `lib/app/practice/setup/setup_wizard_screen.dart` (730) | Yerleşim, oda ve seviye, gecikme (8 tık), akort; her adım atlanabilir; sonuçlar cihazda |
| Ekran alıştırması | `lib/app/drill/drill_screen.dart` (867) | Soru-cevap alıştırması, ikinci deneme, ilk denemede %80 kuralı |
| Kontrol noktası / test akışı | `lib/app/test_flow/test_flow_screen.dart` (282) | Parça parça kontrol noktası; başarısız parça tek başına tekrarlanır |
| Akort aleti | `lib/app/tuner/tuner_screen.dart` (606) | Ücretsiz araç; ana ekrandan erişilir |
| Not gözlemi | `lib/app/screens/guitar_note_observation_screen.dart` (558) | İsteğe bağlı çalgı aracı; hedef istemi, değerlendirme veya ilerleme yazımı yok (dosya yorumu) |
| Haftalık hedef kartı | `lib/app/retention/weekly_goal_card.dart` (266) | Haftalık hedef ve haftalık seri; yerel |
| Eski duruş akışı: ders (rehber/skorlu/kilitli/demo) | `lib/app/screens/{course_screen,lesson_scored_screen,lesson_locked_screen,lesson_demo_screen}.dart` | `library.json` kurs dersleri (`guitar.foundations` 10 ders) |
| Eski duruş akışı: kurulum denetimi, canlı, gözden geçirme | `lib/app/screens/{setup_check_screen,live_screen,review_screen}.dart` | Kamera tabanlı duruş ölçümü; kamera kapısına bağlı (bölüm 6) |
| Eski yazılı kurslar (ukulele, bas, ses, piyano, gitar yolculuğu) | `lib/app/screens/{ukulele,bass,vocal,piano}_beginner_screen.dart`, `lib/app/screens/guitar_journey_screen.dart` | `ostinatoLegacyWrittenCoursesVisible=false`: giriş noktaları kaldırılmış, kod ve saklanan ilerleme duruyor (`lib/app/ostinato_release_policy.dart`) |
| Hesap ve üyelik | `lib/app/ostinato_membership_page.dart`, `lib/app/ostinato_paid_access.dart`, `lib/app/account_connection.dart` | Aylık ve yıllık plan; Motion+ sunulmaz (`ostinatoMotionPlusOffered=false`) |
| Yazılı tekrar | `lib/app/study_review.dart` | Yalnız eski yazılı kurs bayrağı açıkken girişi var |

Not (K): Kütüphane'deki "Dersleri incele" şeridinin başlangıç dersi `library.json` içindeki `guitar.foundations.camera_space` olarak çözülür (`assets/content/library.json`, `starterLessonId`); v1 ölçülü gitar kursuna ise çalgı kartı → çalgı sayfası → `MeasuredPracticeCard` üzerinden gidilir (`lib/app/screens/instrument_screen.dart` satır ~142, `lib/app/screens/guitar_journey_screen.dart` `MeasuredPracticeCard`, satır ~1413). Bu iki yolun cihazda nasıl göründüğü doğrulanmadı (U).

## 2. Navigasyon haritası (metin diyagramı)

Uygulamada sekme çubuğu, alt gezinme, `routes:` tablosu veya adlandırılmış route YOKTUR (`grep` `BottomNavigationBar|NavigationBar|TabBar|routes:` `lib/main.dart` boş). Gezinme tamamen `Navigator.push(MaterialPageRoute)` ile yığındır; `MaterialApp.home` tektir (`lib/main.dart`).

```
main.dart OstinatoApp -> OstinatoHome
 |- (ilk açılış) OnboardingScreen --bitti--> [setState, push değil]
 |- [bayrak ostinatoFirstThreeMinutesOpen=false -> atlanır] FirstThreeMinutesScreen
 `- LibraryScreen  (kök; geri yok)
     |- Ayarlar (SettingsScreen) -> Hesap / Üyelik sayfaları
     |- "Dersleri incele" şeridi -> lessonScreenFor(guitar.foundations.camera_space)
     |      -> LessonScored|Locked|Demo -> (kamera kapısı) SetupCheck -> Live -> Review
     |- Haftalık hedef kartı (alt sayfa: showModalBottomSheet)
     |- Akort aleti (openTuner)
     |- Gitar kartı -> InstrumentScreenRoute
     |      |- MeasuredPracticeCard -> V1PracticeListScreen(course gtr)
     |      |- NoteObservationCard -> GuitarNoteObservationScreen
     |      `- library.json kurs listesi -> CourseScreenRoute -> eski duruş akışı
     |- Ses / Piyano kartı -> ComingSoonInstrumentScreen
     `- Kulak eğitimi kartı -> V1PracticeListScreen(course ear)

V1PracticeListScreen
 |- ölçülü ders -> PracticeLoopScreen -> PracticeResultScreen -> (tekrar | sonraki ders)
 |      |- Kurulum -> SetupWizardScreen ; akort -> TunerScreen ; ekran alıştırması -> DrillScreen
 |- diğer dersler -> V1LessonReaderScreen -> (TunerScreen | DrillScreen | TestFlowScreen)
 `- ücretli ders -> ödeme/üyelik koruması (course_access.dart)
```

Kanıt: `Navigator.of(...).push` çağrıları `lib/app/screens/library_screen.dart`, `instrument_screen.dart`, `course_screen.dart`, `lib/app/practice/loop/v1_practice_list_screen.dart` (satır ~219, ~255), `v1_lesson_reader_screen.dart` (~131, ~151), `test_flow_screen.dart` (~86–102). `test/reachable_screens_test.dart` "açılıştan dokunarak ulaşılan her ayrı ekranı" saymak için yazılmıştır (T). Sayfa geçişi: işletim sistemi "hareketi azalt" isteğinde dönüşümsüz (`lib/app/app_theme.dart` `_ReducedMotionPageTransitionsBuilder`, K; `test/app_theme_motion_test.dart`, T).
Geri dönüş: ekran başına elle yazılmış geri düğmesi (`GlassIconButton` ‹) ve `Navigator.pop` kullanılır (ör. `lib/app/screens/course_screen.dart:69`).

## 3. Tema ve tasarım tokenları

Renkler KAYDEDİLİR; bu işte DEĞİŞTİRİLMEDİ ve değiştirilmeyecektir ("değişmez"). Tek canlı kaynak: `lib/app/app_theme.dart` `OstinatoPalette.light/dark` + `OstinatoThemes` (Material 3, tohum `#5F4CA0`). Eski sabit sınıfı `lib/app/design/ostinato_theme.dart` `OstinatoColors` hâlâ var; değerleri `OstinatoPalette.light`tan bazı alanlarda FARKLIDIR (ör. `textMuted` `#6D677E` ↔ `#5F586D`, `warnInk` `#9A5A46` ↔ `#7E4230`); hangisinin nerede okunduğu çağıranlara bağlıdır (grep ile tam harita çıkarılmadı, U).

| Token | Açık | Koyu |
|---|---|---|
| ink | `#2A2533` | `#F0EBF6` |
| inkSoft | `#3E3849` | `#E3DCEB` |
| textBody | `#4E4759` | `#D6CFDF` |
| textMuted / Faint / Mono | `#5F586D` | `#BEB4CE` / `#BEB4CE` / `#BCB2CD` |
| shell (zemin) | `#EDE9F0` | `#1A1721` |
| surface | `#F4F1F6` | `#24202E` |
| warnInk | `#7E4230` | `#FFC3A1` |
| error / onError | `#9B2420` / `#FFFFFF` | `#FFB4AB` / `#4C1712` |
| success | `#28664A` | `#9BDBB5` |
| primary / onPrimary | `#5F4CA0` / `#FFFFFF` | `#D9C6FF` / `#342055` |
| focus | `#5F4CA0` | `#D9C6FF` |
| outline / divider | `#82748E` / `#B8ADBF` | `#9B8DAA` / `#65596F` |
| glassStart / glassEnd | `#EBFFFFFF` / `#8FFFFFFF` | `#EB302B3E` / `#E6231F2B` |
| glassBorder | `#D9FFFFFF` | `#65596F` |
| glassShadow | `#2940305A` | `#66000000` |
| controlSurface / controlBorder | `#EAE4F0` / `#82748E` | `#362E43` / `#9B8DAA` |
| disabledBackground / Foreground | `#DDD7E4` / `#645C70` | `#39313F` / `#BBB1C6` |
| selection | `#E1D5F5` | `#4A3B62` |
| notationPaper / notationInk | `#FFFDF8` / `#2A2533` | `#1E1B27` / `#EAE2F3` |

Çalgı tonları (`InstrumentHue`, `lib/app/app_theme.dart` ve `lib/app/design/ostinato_theme.dart`): gitar `ink #8F483A` (açık), `#F5C7B1` (koyu); ses `#5F4CA0` / `#D8C8FF`; piyano `#2A6D5F` (palet) / `#2B6F60` (eski sınıf) / `#B0E3CF` (koyu). Gradyanlar `grad`, `gradAlt`, `soft`, `chip`, `band` alanlarındadır (değerler dosyada; burada yinelenmedi).
Tipografi: Hanken Grotesk 400/500/600 ve IBM Plex Mono 500, pakette (`pubspec.yaml` `fonts:`, `assets/fonts/`); `hankenText`, `monoText`, `kicker` (`lib/app/design/ostinato_theme.dart`). Birkaç dilde harf aralığı kapatılır (`ostinatoAppBuilder`).
Cam: `GlassCard` (`lib/app/design/widgets.dart`) = `BackdropFilter` bulanıklık sigma 18 + gradyan + kenarlık + gölge. Dosya yorumu "gerçek cihazda blur ucuz değil" der. `BackdropFilter` yalnız bu dosyada geçer (`grep`); düşük donanım ya da "saydamlığı azalt" için koşullu yol bulunamadı (K, `grep` highContrast/reduceTransparency boş). Bölüm 8'de yeniden ele alınır.
Düğmeler: asgari 48×48 (`FilledButton`, `OutlinedButton`, `IconButton` temaları, `lib/app/app_theme.dart`); odak halkası 2 px.

## 4. Bileşen envanteri

Paylaşılan (`lib/app/design/widgets.dart`, 462 satır): `GlassCard`, `GlassIconButton` (48 px, `semanticLabel`, RTL'de ‹ › çevrilir; `test/glass_icon_button_accessibility_test.dart`), `PrimaryButton`, `HorizontalBandTrack`, `SkeletonFigurePainter` (eski duruş ekranları için gövde iskeleti). Diğer ortak parçalar: `kicker` (bölüm etiketi), `InstrumentHue` kartları, `_SensorCard`, `_StarterRow`, `_InstrumentCard`, `_EarTrainingCard` (hepsi `library_screen.dart` / `onboarding_screen.dart` içinde özel sınıf).
Pratik yüzeyi: akan TAB şeridi `lib/app/practice/loop/practice_tab_strip.dart` (400), vuruş görünümü `metronome_beat_view.dart`, nota işareti `practice_marks.dart` (✓ ◆ ?, "şekil önce, renk ikinci"; `practice_visual_theme.dart`), taşıma `practice_transport.dart`, tempo basamağı `practice_tempo_ladder.dart`, referans dinleme `reference_listen_bar.dart`, "dinle-dene-düzelt" kartı `listen_try_fix_card.dart` (bayrak kapalı). Alıştırma: `lib/app/drill/` (klavye, bilek, porte, 29 soru türü, `drill_generator.dart` `DrillPromptKind`). Ölçüm: `lib/app/tuner/`, `lib/app/practice/setup/`.
Tekrar kullanım notu: birçok ekran kart ve satırı yerinde `InkWell` + `Ink` + gradyan ile yeniden yazar (`library_screen.dart`, `instrument_screen.dart`); ortak "kart" bileşeni `GlassCard` ile `Ink` kartı arasında bölünmüştür (K).

## 5. Kurs ve ders veri modeli

Dosya = ders DEĞİLDİR (test dosyası = adında `-test` geçen). main: `content/v1/gtr` 240 dosya = 235 ders + 5 test; `content/v1/ear` 50 = 48 + 2; `content/v1/pno` 160 = 157 + 3. Toplam **450 dosya = 440 ders + 10 test**. Mağazada açık: gitar + kulak = **290 dosya = 283 ders + 7 test** (ADR-002; bu işte `ls` ile yeniden sayıldı: 240/50/160, test 5/2/3). `content/v1/voc` yok; şan dalı main'de değildir.
Yapı: gtr Seviye 1–4 (s1 40, s2 60, s3 60, s4 80; 22 modül kimliği), ear s1 25 + s2 25 (9 modül), pno s1 40, s2 60, s3 60 (15 modül); kimlik `gtr-s1-m01-01` biçimli (K, dosya adlarından).
Ders alanları (`content/v1/gtr/gtr-s1-m01-01.json`): `id`, `title` {en,tr}, `goal`, `explanation[]`, `referenceAudio`, `practice` {`measurement[]`, `engineSteps[]`, `task`}, `fallback`, `safety`, `prerequisites`, `selfCheck`, `commonErrors`, `adaptation`, `legacy`, `minutes`, `expertPending`. Çalışma zamanı modeli: `lib/app/curriculum/v1_lesson.dart` (`V1Lesson`), `lib/app/practice/loop/v1_course_catalog.dart` (`V1LessonAvailability`: measured, tuner, selfCheck, selfCheckLesson, camera, drillSoon, held).
İçerik beyanı (dosyalardan sayıldı; "ders çalışma zamanında bu yolla çalışır" DEĞİL): gitar `measurement` `M` 191, `M!` 27, `D+M` 12, `M+Ö` 6, `D` 1, `K+D` 1, `K` 1, `Ö` 1; `fallback` selfCheck 209, held 27, noEngine 2, camera 2. Kulak: `M` 20, `D` 19, `M!` 7, `D+M` 2, `M+D` 2; `fallback` selfCheck 24, noEngine 19, held 7. Kaç dersin bu sürümde gerçekten ölçülü pratikle çalıştığı çalışma zamanı sınıflamasına bağlıdır ve bu belge için hesaplanmadı (U).
Uzman onayı: 450 dosyanın tümünde `expertPending=true` (240+50+160; K, `python` ile sayıldı; `docs/yula-execution/STATUS.md` ile uyumlu). Eşikler "uzman onayı bekliyor"dur.
Ücretsiz kapsam: gitar s1 (40) + kulak s1 (25) (`ostinatoV1FreeStages`, `lib/app/course_access.dart`). Modül kapısı: önceki modülün kontrol noktası geçilince açılır; modül içinde tüm dersler açıktır (`v1_practice_list_screen.dart` belge yorumu).
Eski içerik: `assets/content/*.v1.json` (ukulele, bas, ses, piyano yazılı, gitar yolculuğu), `assets/content/library.json` (3 çalgı × `foundations` kursu; gitar 10 ders, duruş odaklı). Giriş noktaları kapalı.
İlerleme ve saklama: `V1PracticeRecord` (`lib/app/practice/loop/practice_progress_store.dart`, 365): `runs`, `bestAccuracy`, `bestHeard`, `bestBpm`, `lastRunAt`, `passedAt/Bpm`, `completedAt/Bpm`, `evidence: measured_practice`; yerel, hesap başına, ham ses ve ağ yok. Ayrı depolar: öz-bildirim (`V1LessonCheckStore`), oturum (`lib/app/session_store.dart`, `sessions.jsonl`), haftalık hedef (`lib/app/retention/weekly_goal_store.dart`), kontrol noktası parçaları (`lib/app/test_flow/test_flow_store.dart`), kurulum profili (`lib/app/practice/setup/setup_profile_store.dart`). Eşitleme KAPALI (`ostinatoProgressSyncAvailable=false`; `lib/app/sync/` bağlı değil). Bulgu (K): `bestAccuracy`, `bestHeard`, `bestBpm` alanlarını `practice_progress_store.dart` dışında okuyan satır `lib/app` içinde bulunamadı (`grep` boş); önceki-sonraki performans karşılaştırması bu alanlardan geliyor olamaz, başka bir yoldan gelip gelmediği ayrıca doğrulanmadı (U).

## 6. Ölçüm altyapısının güvenilirlik sınırları

Kaynak: `docs/yula-execution/MEASUREMENT-OST-P0-03-04.md` (durum TEST_ONLY sentetik + sınırlı gerçek kayıt) ve `docs/yula-execution/OST-P0-09-PROTOKOL.md` (cihaz ölçümü yapılmadı; STATUS'ta BLOCKED_ACCESS, cihaz-ortam 0/5). Aşağıdaki sayılar o rapordan alınmıştır, bu işte yeniden ölçülmedi.
- Onset: sentetik temiz sette hata medyan 8,3 ms, p95 11,0 ms, kaçan %0, fazla %0. Gürültüde fazla vuruş artar: beyaz 5 dB %36,1; pembe 10 dB %187,5 ve pembe 5 dB %298,6 (rapor "tempo kullanılamaz" der). Tespitler vuruştan ortalama 7–8 ms ERKEN (sistematik yanlılık). Gerçek kayıt (GuitarSet, mono mikrofon, polifonik eşlik, cihaz mikrofonu DEĞİL): 247 referansta kaçan %38,9, fazla %2,8, hata medyan 12,9 ms.
- Tempo: üretimde tempo kestiricisi YOK; testteki tempo, tespit edilen vuruşların IOI'sinden ölçüm amaçlı türetilir. Gerçek kayıtta tempo ölçülmedi.
- Pitch: ürün yolu (`GuitarPitchObserver`) temiz tek nota sentetik 60/60; çok sesli 28/28 "duyamadım", yanlış hüküm 0/28; ±40/±50 cent sapmada hüküm yok. Korumasız iç katman çok seslide 10/28 yanlış (bir oktav alt) hüküm verir; üründe koruma bunu reddeder. Gerçek monofonik GİTAR ölçümü YAPILMADI (gerçek monofonik kayıt yalnız piyano).
- `duyamadım` davranışı (K): her nota ✓ doğru, ◆ farklı nota veya ◯ duyamadım alır; "farklı nota hata kelimesi değil, bilgidir; duyamadım doğruluk oranının dışındadır" (`lib/app/practice/loop/practice_marks.dart`). Nedenleri: saldırı yok, çok kısık, çok yüksek (kırpma), perde çözülemedi, uygulama sesi duyuldu, atlandı (`HearingReason`). Notaların beşte birinden fazlasında duyulamazsa bileşen puanlanmaz (`lib/app/app_message_ids.dart` metin kataloğunda).
- Sınırlar (raporun kendi cümleleri): cihaz-üstü ölçüm yok; sentetik tonlar gerçek gitar zarfını temsil etmez; yankı gerçek oda değildir; tek örnekleme hızı (44,1 kHz); mutlak gecikme garantisi verilmez; "pilot test hedefi" başarı iddiası değildir. Cihaz gecikmesi için kurulum sihirbazında 8 tıklı kalibrasyon vardır (`lib/app/practice/setup/latency_calibration.dart`); gerçek cihazlarda doğruluğu ölçülmedi (U).
- Paketler: `packages/ostinato_audio/lib/src/` (capture, contract, dsp, fixture, gate, harmony, onset, pitch, rhythm; 26 kaynak, 24 test dosyası), `packages/ostinato_posture/` (6 kaynak, 2 test). Akor sınıfı yalnız sentetik/sınırlı kanıtla; ilgili raporda akor doğruluğu ölçülmedi.
- Sonuç: bu yüzeylerde "ölçüm" kelimesi, cihaz-üstü doğrulanmış kesin doğruluk anlamına GELMEZ; ölçümün güvenilir olmadığı durumda ürün "duyamadım" der (K), ve yanlış hüküm vermemek tasarım sözleşmesidir.

## 7. Kamera ve mikrofon izin akışları

Mikrofon (K): `ios/Runner/Info.plist` `NSMicrophoneUsageDescription` (notaları ve ritmi duymak; ses cihazda işlenir, yüklenmez; kendi kaydım opt-in, cihazda, oturum bitince silinir), Android `RECORD_AUDIO`. İstek `lib/app/audio/mic_permission_gate.dart` (`MicPermissionGate`): önce istem, sonra izin verilirse yalnız uygulama ön planda ve yaşam döngüsü sakinse yakalama başlar; reddedilirse denetleyici bildirir. Kullanım yerleri: pratik girişi (`lib/app/practice/practice_audio_input.dart`), akort (`tuner_screen.dart`), not gözlemi, ilk üç dakika sesli yol (`first_minutes_controller.dart` `requestVoice`: ret normal cevap; kalıcı ret ve kısıtlı ayrı sonuç). Karşılama sayfası izni İSTEMEZ, açıklar. Reddedilince tam davranış (pratik ekranında "Mikrofon kapalı" durumu ve alternatif akış) kod ve testlerde var (`test/mic_permission_gate_test.dart`, T); cihazda denenmedi (U).
Kamera: `NSCameraUsageDescription` ve Android `CAMERA` manifestte BİLDİRİLİDİR (`ios/Runner/Info.plist`, `android/app/src/main/AndroidManifest.xml`); istek yalnız kamera akışlarında yapılır (`lib/app/camera_session.dart` `Permission.camera`, `lib/app/practice/camera/mirror_camera.dart`). Eski duruş akışında "Kurulum denetimini başlat" önce hesap bağlantısının `requireCameraAccess` kapısından geçer (`lib/app/screens/lesson_scored_screen.dart` ~220–232); Core kamera koçluk bayrağı `ostinatoCameraPracticeAvailable` ile bağlanır (`lib/app/motion_account_bootstrap.dart:167`). Bu kapının davranışı `motion_account` paketindedir; paket bu çalışma ağacında bulunmadığı için doğrulanamadı (U). `library_screen.dart` `motionCameraCoachingAvailable` değerini okuyup tanıtım metnini seçer; değerin çalışma zamanı sonucu doğrulanmadı (U).
K8 kamera dersleri (`lib/app/practice/camera/camera_lesson.dart`): yalnız `gtr-s1-m01-02` (gövde ipucu, 60 sn) ve `gtr-s1-m01-03` (ayna, 30 sn); bayrak `ostinatoCameraLessonsOpen=false`.

| Bayrak (`lib/app/ostinato_release_policy.dart`) | main | release/1.0.2 (mağaza) |
|---|---|---|
| `ostinatoPaidFeaturesAvailable` | true | true |
| `ostinatoMotionPlusOffered` | false | false |
| `ostinatoLegacyWrittenCoursesVisible` | false | false |
| `ostinatoOpenInstruments` | {guitar} | {guitar} |
| `ostinatoEarTrainingOpen` | true | true |
| `ostinatoEngineeringNotesVisible` | false | false |
| `ostinatoCameraPracticeAvailable` | false | false |
| `ostinatoCameraLessonsOpen` | false | yok (kod yok) |
| `ostinatoListenTryFixRepeatOpen` | false | yok (kod yok) |
| `ostinatoFirstThreeMinutesOpen` | false | yok (kod yok) |
| `ostinatoProgressSyncAvailable` | false | false |
| `ostinatoTeenPurchasePolicy` | storeFamilyControls | storeFamilyControls |

## 8. Erişilebilirlik bulguları (statik; cihazda ekran okuyucu ile denenmedi)

- Kontrast: açık ve koyu palet WCAG AA için ölçülerek ayarlanmıştır (`lib/app/design/ostinato_theme.dart` yorumu: en kötü oran 4,5 civarı; `test/contrast_test.dart`, `test/app_theme_palette_test.dart`, T).
- Dokunma hedefi: düğme temalarında 48×48 asgari; `GlassIconButton` 48 px (`test/glass_icon_button_accessibility_test.dart`, T). Pratik ekranındaki tüm özel kontrollerin 48 px olduğu bu belge için taranmadı (U).
- Anlamsal etiket: `Semantics(` 48 kullanım, `semanticLabel`/`liveRegion` vb. 33 dosyada (`grep`). Pratik ekranı yoğunluğu düşük: `practice_loop_screen.dart` 2, `practice_tab_strip.dart` 3 (ŞİMDİ etiketi ve `liveRegion`), `practice_result_screen.dart` 3 `Semantics(`. TAB şeridinin tamamının ekran okuyucuda ne söylediği doğrulanmadı (U).
- Renk tek başına taşıyıcı değil: ✓ ◆ ? şekli önce (`practice_visual_theme.dart`); renk körü paleti ve solak şerit ayarları var, ikisi de varsayılan KAPALI (`lib/app/practice/display/practice_display_preferences.dart`, `settings_screen.dart` `PracticeDisplaySettingCard`).
- Metin ölçekleme: `lib/` içinde `TextScaler`/`textScaleFactor` sınırlaması YOK (varsayılan sistem ölçeği geçerli). Metin ölçeğiyle düzen testi yalnız şu dosyalarda: `first_three_minutes_screen_test`, `guitar_journey_test`, `visual_practice_pilot_test`, `piano_beginner_test`, `ukulele_beginner_test`, `written_repeat_navigation_test`, `feedback_availability_test`, `release_reference_copy_test`, `study_course_links_test`, `guitar_staff_diagram_test`. Pratik ekranı, sonuç ekranı, kütüphane ve kurs listesi için büyük metin testi bulunamadı (`grep` ile). `test/real_content_overflow_test.dart` gerçek içerikle taşma ölçer (T).
- Hareketi azalt: yalnız sayfa geçişleri `MediaQuery.disableAnimationsOf` okur (`lib/app/app_theme.dart`, `test/app_theme_motion_test.dart`). Animasyonlu parçalar `lib/app/practice/loop/metronome_beat_view.dart`, `lib/app/practice/loop/practice_loop_screen.dart`, `lib/app/screens/onboarding_screen.dart` içinde bu ayarı okumaz (`grep` `disableAnimations` yalnız `app_theme.dart`).
- Saydamlık ve bulanıklık: `GlassCard` her zaman sigma 18 bulanıklık çizer; "saydamlığı azalt", yüksek kontrast veya `boldText` okuyan kod yok (`grep` boş).
- Dil: 14 yerel dil dosyası (`assets/l10n/`: ar, de, en, es-419, fr, hi, id, it, ja, ko, pl, pt-BR, tr, zh-Hans), RTL için ok çevirme var (`GlassIconButton`). Tüm dillerde tüm metinlerin tamlığı bu işte doğrulanmadı (U).
- Tema: açık/koyu ve sistem seçimi var (`lib/app/app_appearance_picker.dart`, `app_theme_preferences.dart`).

## 9. Test kapsamı (statik sayım; koşturulmadı)

- `test/`: 168 `*_test.dart` dosyası; satır başında `test(`/`testWidgets(` 1274 çağrı (371'i `testWidgets`, 92 dosyada). Döngüyle üretilen testler bu sayıya dahil değildir; sayı alt sınırdır. `integration_test/`: 2 dosya (`guitar_course_smoke_test.dart`, `production_main_boot_test.dart`). Paketler: `packages/ostinato_audio` 24, `packages/ostinato_posture` 2 test dosyası. CI: `.github/workflows/checks.yml`.
- Test edilen alanlar (dosya adlarından): hesap ve silme yaşam döngüsü (`account_*`), ses yakalama ve native hakem (`audio_*`, `native_*`, `practice_audio_*`, `practice_video_*`), pratik yargıç, ritim, metronom, sonuç (`practice_judge`, `practice_rhythm`, `practice_metronome`, `practice_result`, `practice_tempo_ladder`), kurulum (`setup_wizard`, `setup_calibration`), kurs bütünlüğü ve erişim (`guitar_course_integrity`, `v1_course_catalog`, `v1_lesson_content`, `course_access`, `v1_store_scope`, `ear_course_open`, `ear_clap_practice`), alıştırmalar (`drill_*`), akort, kamera K8 (`k8_*`, `camera_*`), ilk üç dakika, dinle-dene-düzelt, ölçüm külliyatı (`ost_p0_03_onset_tempo_corpus`, `ost_p0_04_pitch_confidence_corpus`), erişilebilirlik kapıları (`contrast`, `glass_icon_button_accessibility`, `app_theme_*`), ulaşılabilir ekran sayımı (`reachable_screens`), sıfır-ağ kapısı (`flutter_test_config.dart`, `ost_p0_02_egress`), dil (`locale_*`, `app_locale_*`).
- Test edilmemiş veya zayıf (dosya adı bulunamadı): kütüphane ve çalgı sayfasının görsel hiyerarşisi (yalnız `library_fold_test`, `library_starters_test`), cihaz üstü mikrofon doğruluğu, ekran okuyucu ile uçtan uca akış, büyük metinde pratik ekranı.
- Bu belge için `flutter test` koşturulmadı; geçiyor/geçmiyor iddiası yoktur.

## 10. Gerçek yayın durumu (mağaza 1.0.2 (11) ile main farkı)

Yöntem: `git log`, `git diff` (`origin/release/1.0.2` ↔ `origin/main`). Canlı mağaza durumu bu işte okunmadı (U); "mağazada" = `release/1.0.2` kaynağı (ADR-004, STATUS).
- Mağazada (release/1.0.2): gitar kursu ve kulak eğitimi açık; ses ve piyano "Yakında"; ücretsiz gitar s1 + kulak s1; abonelik aylık ve yıllık; kamera kapalı; eşitleme kapalı. Sürüm `1.0.2+11`.
- Yalnız main'de, bayrak ARKASINDA (varsayılan kapalı): K8 kamera dersleri ve ayna (`ostinatoCameraLessonsOpen`), ilk üç dakika akışı (`ostinatoFirstThreeMinutesOpen`), dinle-dene-düzelt döngüsü (`ostinatoListenTryFixRepeatOpen`). Bu üçünün main varsayılanıyla kullanıcıya ulaşan davranışı release ile aynıdır (bayrak false); açılırsa yeni ekran görünür.
- Yalnız main'de, bayraksız: `camera` paketi bağımlılığı (`pubspec.yaml`); ders metni düzeltmeleri (`content/v1/gtr/gtr-s1-m01-03.json`, `lib/app/screens/v1_home_copy.dart` kamera metni "duruşa ve el konumuna" diye değişti); ölçüm külliyatı testleri; belge işleri (STATUS, DECISIONS, ölçüm raporu, protokol). Yalnız main'in içerik/metin farkı release'e ulaşmaz.
- Yalnız release'te: 4 commit (`c184e24`, `7847c54` alt yazı dürüstlüğü düzeltmesi; `c49654b` sürüm; merge #64). main ondan 40 commit ileride, 4 commit geridedir (`git rev-list --count`). Düzeltmeler önce main'e, sonra release'e alınır (ADR-004).
- Bu belgenin tüm değerlendirmesi mağaza değil main kaynağı üzerinedir; mağaza ikilisini bu iş için çalıştırmadım (U).

## Ekran görüntüleri

(OST-UX-01 ekran görüntüleri scratch'te; liste PR gövdesinde)

## Kapsam dışı / doğrulanamayan

- Cihaz-üstü her şey: gerçek telefonda mikrofon, kamera, gecikme, ekran okuyucu (VoiceOver/TalkBack), büyük yazı tipi, düşük donanımda cam bulanıklığı performansı.
- Canlı mağaza (App Store Connect / Play) durumu, inceleme sonucu, mağaza ikilisi; yalnız kaynak dalları okundu.
- `packages/motion_account`, `motion_core`, `motion_camera` bu çalışma ağacında yok; kamera kapısı (`requireCameraAccess`) ve `motionCameraCoachingAvailable` değerinin gerçek davranışı okunamadı.
- Çalışma zamanı ders sınıflaması (kaç ders ölçülü, kaç ders öz-kontrol) hesaplanmadı; yalnız içerik beyanı sayıldı.
- Testler koşturulmadı; sayılar statik `grep`/`find` sayımıdır.
- `OstinatoColors` ↔ `OstinatoPalette` çağıran haritası çıkarılmadı.
- Şan W4 dalı (`content/v1-w4-voice`) ve eski yazılı kurslar derinlemesine incelenmedi.
