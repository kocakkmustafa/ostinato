# Ostinato — Kullanıcı zihinsel modeli (OST-UX-01, Aşama 2)

Tarih: 2026-11-09 · Taban: `origin/main` `1fa8b93ac43cc663b4578047481a7d89c4211212`. Eşlik eden belge: [`01-audit.md`](01-audit.md) (envanter; numaralar oradaki bölümlere atıf yapar).
Kapsam: yalnız MEVCUT durum ve boşluk tespiti. Tasarım önerisi, yeniden tasarım ve "bence" yoktur. Kullanıcı araştırması, analitik veya kullanım verisi bu depoda bulunamadı (`docs/research/` ve `docs/evidence/` içeriği bu işte taranmadı, U); aşağıdaki "kullanıcı" cümleleri ürünün kendi metinlerinden ve akışından ÇIKARIMDIR, gözlem değildir.
Durum kodları: **var / kısmi / yok** (kaynakta); **K** kaynakta okundu · **T** testte var (koşturulmadı) · **U** doğrulanamadı. Prototip / araştırma / yayınlanmış ayrımı (§5.2.E) bölüm 4'te her yüzeye uygulanmıştır: **YAYINLANMIŞ** = `release/1.0.2` mağaza kaynağında ve bayraksız; **BAYRAK ARKASINDA** = main'de kodu var, varsayılan kapalı (kullanıcıya ulaşmaz); **PROTOTİP/ARAŞTIRMA** = kod yok, yalnız belge/ölçüm/fikstür.

## 1. §5.1 Temel UX kararı ("en önemli eylem müzik yapmaktır") — bu ürüne karşılığı

Talimat: arayüz kullanıcıyı müzikten uzaklaştırmamalı. Mevcut durum:
- Müzik yapma eylemi pratik ekranındadır (`lib/app/practice/loop/practice_loop_screen.dart`): akan TAB, ŞİMDİ çizgisi, vuruş, her zaman görünür mikrofon şeridi (K). Ekranın dokunuşla başlatılması "Başlat" düğmesidir; müzik başlamadan önce giriş yolu: Kütüphane → Gitar kartı → Çalgı sayfası → `MeasuredPracticeCard` → kurs listesi → ders → pratik (`01-audit.md` §2). Kütüphane açılış ekranında doğrudan "pratik başlat" düğmesi yoktur; en kısa yol kart + kart + liste + ders (K, kaynak okuma; kaç dokunuş olduğu cihazda sayılmadı, U).
- Müzikten uzaklaşma riski taşıyan mevcut yüzeyler (olgu, hüküm değil): Kütüphane'nin üstündeki "Dersleri incele" şeridi üç canlı disiplin için üç eski duruş/referans başlangıç dersine açılır: gitar `guitar.foundations.camera_space`, ses `voice.foundations.teacher_range`, piyano `piano.foundations.posture` (`assets/content/library.json` `status`=live ve `starterLessonId`, `lib/app/screens/library_screen.dart:54-57`); çalgı sayfasında kurs listesi ve duruş dersleri ders kartı olarak görünür; kurs listesi 4 seviye × modül yapısıdır (`lib/app/practice/loop/v1_practice_list_screen.dart`).
- Müziği kesen unsurlar: pratik sırasında hata üzerine ekran durmaz; "Bekle beni" modu isteğe bağlı ve notada durur (`lib/app/practice/loop/practice_transport.dart`, K). "Farklı nota" ve "duyamadım" ceza kelimesi değildir (`practice_marks.dart`, K).

## 2. Aşama 2 — dokuz soru

**S1. Kullanıcı burada hangi sonuca ulaşmak istiyor?**
Ürünün kendi çerçevesi: gitarı çalmayı öğrenmek ve kulak/ritim becerisi (`CLAUDE.md`, ADR-001; `lib/app/screens/v1_home_copy.dart` tanıtım metni). Ürün her ders için ölçülebilir bir geçit tanımlar: geçit tempoyla açılır, hedef tempoyla "tamamlandı" (`lib/app/practice/loop/practice_outcome.dart` `TempoGate`, K). Kullanıcı hedefini (ör. şarkı çalmak) ürüne beyan edeceği bir alan yok (K, kaynakta hedef sorusu bulunamadı); onboarding çalgı seçimi sormaz (3 sayfa: karşılama, kapsam, sensör/veri; `onboarding_screen.dart`).

**S2. Uygulamayı neden açıyor?**
Çıkarım (K, ekranlardan): (a) kaldığı dersten devam (`MeasuredNextLine`, "sıradaki ders", Kütüphane gitar ve kulak kartlarında; `library_screen.dart` `_MeasuredNextLineState`); (b) haftalık hedefe uyum (`weekly_goal_card.dart`); (c) akort (ana ekranda ücretsiz araç, `tuner-entry`); (d) araya giren yeni başlayan için ilk ders. Neden açıldığını soran veya kaydeden bir mekanizma yok; analitik yok (sıfır-ağ kapısı, `test/flutter_test_config.dart`, T).

**S3. İlk 5 saniyede ne anlamalı?**
Mevcut ilk ekran (karşılama bittiyse) Kütüphane'dir: "Ostinato" başlığı, ayar düğmesi, tanıtım kartı (`V1HomeCopy.homeSubtitle`/`homeIntro`), sonra "Dersleri incele" şeridi, haftalık hedef kartı, akort, "Çalgılarınız" kartları (`library_screen.dart`). Kullanıcının ilk 5 saniyede "ne çalacağım" sorusunun cevabı tanıtım metnine bağlıdır; ilk ekranda çalınan müzik, ses veya doğrudan başlatılabilir bir pratik düğmesi yoktur (K). 375×812 katlama konumu `test/library_fold_test.dart` ile ölçülüyor (T; sonuç bu işte koşturulmadı).

**S4. En çok hangi ekrana geri dönecek?**
Kaynaktan çıkarım: Kütüphane (gezinme kökü, `01-audit.md` §2) ve pratik ekranı + kurs listesi. Her pratikten sonra sonuç ekranından "tekrar dene" veya "sonraki ders" ile pratik ekranına döner (`practice_result_screen.dart`). Kullanım verisi olmadığı için gerçek sıklık bilinmiyor (U).

**S5. Kullanıcının sürekli tekrar ettiği işler neler?**
Ürünün tekrarı özendiren mekanizmaları (K): dersi tekrar çalma ("Tekrar çal"), tempoyu 5 artırma basamağı (`practice_tempo_ladder.dart`), başarısız kontrol noktası parçasını tek başına tekrar (`test_flow_screen.dart`), akort (`tuner_screen.dart`), haftalık seri. Elle yapılan tekrarlı iş: her oturumda Kütüphane → kart → liste → ders yolunu yeniden izlemek (kaynakta "son çalınan dersi doğrudan aç" yolu yok; `MeasuredNextLine` metin satırıdır, bunu açan ayrı bir düğme `guitar-measured-practice-entry` `MeasuredPracticeCard` içindedir, `guitar_journey_screen.dart` ~1449).

**S6. Hangi bilgiler otomatik gelebilir?**
Zaten otomatik gelenler (K): sıradaki ders (`V1CourseState.next`), kurulum profili (cihazda saklanan gecikme ve ortam sonuçları, `setup_profile_store.dart`), tema/dil (sistem), ücretsiz kapsam. Hesaplanabilir ama ekranda karşılığı bulunamayanlar (olgu): kayıtlı `bestAccuracy`/`bestHeard`/`bestBpm` alanlarının UI'da okunduğu satır yok (`01-audit.md` §5); sonuç ekranı "önceki denemeyle fark" göstermiyor olabilir, doğrulanamadı (U).

**S7. Kullanıcı ne zaman konuşmalı, ne zaman dokunmalı, ne zaman ayrıntıları incelemeli?**
Mevcut girdi biçimleri (K): çalgı sesi ve el çırpma/sesle → mikrofon (`practice_loop_screen.dart`); ekranda dokunma → alıştırma, öz-kontrol, ilk üç dakika ritim dokunuşu (bayrak kapalı); ses ile söyleme ritim/ses yolu yalnız "ilk üç dakika" içinde ve ear singing alternatifinde öz-kontrol (`test/ear_singing_alternative_test.dart`, T). Yazı ile komut/arama yok; sesle komut yok (K, kaynakta bulunamadı). Ayrıntı katmanı: ders okuyucu (anlatım, görev, ölçülmeyen not) ve sonuç ekranı "Nerede oldu" hata haritası (`practice_result_screen.dart` `result-error-map`).

**S8. Hangi karmaşıklık gizlenebilir?**
Bugün zaten gizlenmiş olanlar (K): eski yazılı kurslar (`ostinatoLegacyWrittenCoursesVisible=false`), çalgı sayfasındaki mühendislik notları (`ostinatoEngineeringNotesVisible=false`), ses ve piyano ÇALGI KARTLARININ dersleri ("Yakında" sayfası; ama bu iki disiplinin duruş/referans başlangıç dersleri ana ekran şeridinden açılır), kamera özellikleri. Hâlâ görünür karmaşıklık (olgu): 4 seviye, modül, ders, chip (`Ölçülü`, `Akort aleti`, `Öz-kontrol`, `Kamera`, `Ekran alıştırması`, `Bekliyor`), kilit ve geçit durumları aynı listede (`V1CourseCopy` chip ve status metinleri); iki ayrı "ders" kavramı (v1 kursu ve `library.json` duruş dersleri) çalgı sayfasında yan yana (`01-audit.md` §1 notu).

**S9. Hangi kritik bilgiler asla gizlenmemeli?**
Ürünün kendi sözleşmesi (K): (1) ölçüm güvenilir değilse "duyamadım" — yanlış hüküm verilmez (`practice_marks.dart`, ADR ve `docs/yula-execution/MEASUREMENT-OST-P0-03-04.md`); (2) mikrofon durumu pratikte her zaman görünür ("mikrofon şeridi", `practice_loop_screen.dart`); (3) hangi derslerin ölçülmediği ders okuyucuda ve listede etiketli (`V1CourseCopy.notMeasuredNote`, `chipSelfCheck`); (4) ses cihazda kalır (`Info.plist` `NSMicrophoneUsageDescription`; kendi kaydım opt-in); (5) "tıbbi araç değil" (`onboarding_screen.dart` `onboarding-wellness-card`); (6) ücretsiz kapsam ve kilit (`v1-course-free-scope`, `course_access.dart`). Uzman onayı durumu (`expertPending=true`, 450/450 dosya) KISMEN gösterilir: sonuç ekranı, geçit `expertPending` iken "Thresholds are defaults awaiting a music teacher’s review." satırını gösterir (`lib/app/practice/loop/practice_result_screen.dart:519-525`); ders listesi, ders okuyucu ve ana ekranda bu durumu gösteren etiket bulunamadı (U).

## 3. §5.2 A–H alanları: mevcut karşılık

| Alan | Durum | Mevcut karşılık ve kanıt | Boşluk (olgu) |
|---|---|---|---|
| A. Stüdyo / Başlangıç | **kısmi** | Kaldığı yerden devam: sıradaki ders satırı (`lib/app/screens/library_screen.dart` `_MeasuredNextLine`); haftalık hedef (`lib/app/retention/weekly_goal_card.dart`); enstrüman/alan seçimi: gitar ve kulak kartları (`library_screen.dart`); akort kısayolu | Hızlı pratik başlatma düğmesi yok (satır metin); kısa çalışma önerisi (günün çalışması) yok; "son gelişim" özeti ana ekranda yok; ders kataloğu ana ekrana yığılmamış (iyi) ama "Dersleri incele" şeridi üç disiplinin (gitar, ses, piyano) eski duruş/referans başlangıç derslerine gider (`assets/content/library.json`, `library_screen.dart:54-57`) |
| B. Canlı pratik | **var** (ölçüm sınırlarıyla) | TAB/nota şeridi, ŞİMDİ çizgisi, tempo, metronom, "Bekle beni", döngü, dinleme referansı, başlat/durdur, ✓◆◯ geri bildirim, kurulum/kalibrasyon girişi, sonuç ekranı (`lib/app/practice/loop/practice_loop_screen.dart`, `practice_result_screen.dart`, `practice_tab_strip.dart`, `reference_listen_bar.dart`, `lib/app/practice/setup/setup_wizard_screen.dart`) | "Kısa düzeltme önerisi": `listen_try_fix` bayrak KAPALI (BAYRAK ARKASINDA); yayınlanmış sürümde hata haritası ve "Nerede oldu" var ama tek bir düzeltme cümlesi yok. Ölçüm doğruluğu `01-audit.md` §6 sınırlarına tabidir |
| C. Öğrenme yolculuğu / Dersler | **kısmi** | 4 seviye, modül, ders ve geçit yapısı; seviye testi; sıradaki ders işareti; ders okuyucu hedef/anlatım/görev (`lib/app/practice/loop/v1_practice_list_screen.dart`, `v1_lesson_reader_screen.dart`, `v1_course_catalog.dart`; içerik `content/v1/gtr`, `content/v1/ear`) | Kullanıcının mevcut seviyesini/becerisini belirleme (yerleştirme) yok; "bu ders neden önerildi" açıklaması bulunamadı (sıra sabit müfredat sırası); beceri bazlı görünüm yok (ders/modül/seviye bazlı) |
| D. Hayalet Ekran | **yok** (ilgili parça: kısmi) | Aşamalı yardım azaltma modu kodda bulunamadı. İlgili: tempo basamağı (`practice_tempo_ladder.dart`), "Bekle beni", referans dinleme, "Öğrenme/Pekiştirme/Hatırlama/Bağımsız performans" aşamalarını adlandıran model yok (`lib` içinde `ghost|hayalet|fading` grep: yalnız `practice_tab_strip.dart` yanlış notayı "hayalet" çizer, yardım azaltma değil; `app_message_ids.dart` metin kataloğu) | Ölçüm güvenilmezken yetkinlik iddiası yok: sözleşme mevcut (ölçülmeyen ders "öz-bildirim" etiketli) |
| E. Kişiselleştirilmiş alıştırmalar | **kısmi** (YAYINLANMIŞ: deterministik; BAYRAK ARKASINDA: dinle-dene-düzelt; PROTOTİP: yok) | YAYINLANMIŞ: deterministik, tohumlu alıştırma üretici (`lib/app/drill/drill_generator.dart`, 29 soru türü); sıradaki ders seçimi sabit kural (`V1CourseState`). BAYRAK ARKASINDA: "farkın türünden sonraki egzersiz" (`lib/app/practice/loop/listen_try_fix.dart`, `ostinatoListenTryFixRepeatOpen=false`). ARAŞTIRMA/PROTOTİP: üretilmiş mikro-etüt YOK (kod bulunamadı) | Tekrar eden hatadan beslenen kişisel seçim yayınlanmış sürümde yok; `session_store.dart` oturum kaydı var ama hata geçmişinden alıştırma seçen kod bulunamadı (U) |
| F. Kulak ve ritim eğitimi | **var** | Kulak kursu 50 dosya (48 ders + 2 test), mağazada açık; ekran alıştırmaları (D), alkış dersleri (A3 mikrofon), şarkı söyleme öz-kontrol alternatifi (`content/v1/ear`, `lib/app/drill/`, `test/ear_course_open_test.dart`, `test/ear_clap_practice_test.dart`, `test/ear_singing_alternative_test.dart`); ölçüm biçimleri ayrı: ekran alıştırması (cevap), alkış (mikrofon zamanlama), söyleme (öz-kontrol) (`lib/app/test_flow/test_flow_screen.dart` belge yorumu). Enstrümansız ritim: BAYRAK ARKASINDA `lib/app/first_minutes/` (ritim dokunma, mikrofon izni istemez) | Kulak kursunda s1 ücretsiz (25), s2 ücretli; enstrümansız yolun ana ekranda ayrı girişi yalnız kulak kartıdır |
| G. İlerleme ve performans geçmişi | **kısmi** | Ders durumları (kilit, öz-bildirim, geçti, tamamlandı), seviye ilerleme satırı, haftalık hedef ve haftalık seri (`lib/app/practice/loop/practice_progress_store.dart`, `lib/app/retention/weekly_goal.dart`, `v1_practice_list_screen.dart`); oturum kaydı (`lib/app/session_store.dart`) | Önceki-sonraki performans karşılaştırması ve geçmiş görünümü yok (kayıtlı en iyi doğruluk/BPM alanları UI'da okunmuyor, `01-audit.md` §5); "neleri artık çalabiliyorum" beceri görünümü yok; "zorlandığım konular" ders içi hata haritasıyla sınırlı; sonraki önerilen adım yalnız sıradaki ders; rozet/puan sistemi yok, seri var (hedef + haftalık seri, `retention_copy.dart`) |
| H. Enstrüman ve cihaz kurulumu | **kısmi** | Kurulum sihirbazı: yerleşim, oda ve seviye (gürültü tabanı), gecikme (8 tık), akort; atlanabilir; cihazda saklanır (`lib/app/practice/setup/setup_wizard_screen.dart`, `latency_calibration.dart`, `audio_environment.dart`, `setup_profile_store.dart`); akort (`lib/app/tuner/`); ayarlar: solak, renk körü, kendi kaydım, dil, tema (`settings_screen.dart`); kamera yalnız K8 derslerinde istenir (BAYRAK ARKASINDA, `camera_lesson.dart`) | Ayarlarda tek yerde "ses/mikrofon durumu" paneli yok (kurulum pratik içinden açılır); ölçüm yapılamıyorsa dürüst durum: "duyamadım" ve "ölçülmedi" etiketleri var (K); kamera derslerinde kullanıcı kamera kurulumuna zorlanmaz (bayrak kapalı); erişilebilirlik ayarları yalnız solak ve renk körü; metin boyutu/hareket ayarı uygulamaya özel değil (sistem) (`01-audit.md` §8) |

## 4. §5.2.E ayrımı — yüzey yüzey: yayınlanmış / bayrak arkasında / prototip-araştırma

| Yüzey | Sınıf | Kanıt |
|---|---|---|
| Gitar v1 kursu (240 dosya) ve ölçülü pratik | YAYINLANMIŞ (release/1.0.2) | `content/v1/gtr`; `lib/app/ostinato_release_policy.dart` `ostinatoOpenInstruments={'guitar'}` |
| Kulak eğitimi (50 dosya), ekran alıştırmaları, alkış dersleri | YAYINLANMIŞ | `ostinatoEarTrainingOpen=true`; `content/v1/ear` |
| Akort aleti, kurulum sihirbazı, kendi kaydım (opt-in), haftalık hedef | YAYINLANMIŞ | `lib/app/tuner/`, `setup_wizard_screen.dart`, `own_recording.dart`, `weekly_goal.dart` |
| Deterministik alıştırma üretici (29 tür) | YAYINLANMIŞ | `lib/app/drill/drill_generator.dart` |
| Piyano kursu (160 dosya) | İÇERİK main'de, uygulamada KAPALI ("Yakında") | `lib/app/screens/instrument_screen.dart`, `coming_soon_instrument_screen.dart` |
| Şan | PROTOTİP/ARAŞTIRMA: main'de yok (yalnız `content/v1-w4-voice` dalı, ayrı kurucu kararı) | `docs/yula-execution/DECISIONS.md` ADR-001/002 |
| Çello / kamera koçu | PROTOTİP/ARAŞTIRMA (P2); kamera dersi kodu var ama kapalı | ADR-001; `ostinatoCameraPracticeAvailable=false` |
| K8 kamera dersleri + ayna (`gtr-s1-m01-02`, `-03`) | BAYRAK ARKASINDA (main) | `ostinatoCameraLessonsOpen=false`; `lib/app/practice/camera/` |
| İlk üç dakika (ritim dokunma, ses, "enstrümanım var") | BAYRAK ARKASINDA (main) | `ostinatoFirstThreeMinutesOpen=false`; `lib/app/first_minutes/` |
| Dinle-dene-düzelt (tek düzeltme, tempo tekrarı, sıradaki egzersiz) | BAYRAK ARKASINDA (main) | `ostinatoListenTryFixRepeatOpen=false`; `lib/app/practice/loop/listen_try_fix.dart` |
| Hayalet Ekran (aşamalı yardım azaltma) | YOK (ne kod ne bayrak) | `grep` ve dosya listesi |
| Üretilmiş mikro-etüt | YOK | kod bulunamadı |
| İlerleme eşitleme | KOD VAR, BAĞLI DEĞİL | `ostinatoProgressSyncAvailable=false`; `lib/app/sync/` |
| Eski yazılı kurslar, eski duruş (kamera) akışı | KOD VAR; yazılı kurslar girişsiz; duruş dersleri çalgı sayfasında listeli, kamera adımı kapı arkasında | `ostinatoLegacyWrittenCoursesVisible=false`; `lib/app/screens/lesson_scored_screen.dart` |

Tüm 450 dersin uzman onayı bekliyor (`expertPending=true`): içerik "doğrulanmış" bir kurs olarak değil, onay bekleyen kurs olarak anlaşılmalıdır (`docs/yula-execution/STATUS.md`).

## 5. §5.3 İstenmeyenler — bugün var mı?

| # | İstenmeyen | Bugün var mı? | Kanıt |
|---|---|---|---|
| 1 | Her ekranı ders listesine dönüştürmek | **kısmen** | Ana ekranda liste yok (kartlar ve şerit), ancak çalgı sayfası ve kulak/gitar giriş ekranı doğrudan ders listesidir (`v1_practice_list_screen.dart`); "Dersleri incele" şeridi ders açar (`library_screen.dart`) |
| 2 | Pratiği fazla animasyon ve efektle gölgelemek | **hayır** (statik okuma) | Animasyonlu parça yalnız `metronome_beat_view.dart`, `practice_loop_screen.dart`, `onboarding_screen.dart`; konfeti/efekt yok (`grep` boş); `GlassCard` bulanıklığı pratik ekranı dışındaki kartlarda; pratik ekranında `GlassCard` kullanımı taranmadı (U) |
| 3 | Her hata için sert görsel ceza | **hayır** | "Farklı nota" hata kelimesi değil, bilgi; "duyamadım" doğruluk dışı (`lib/app/practice/loop/practice_marks.dart`); "Bu denemede geçmedi" nötr durum (`practice_result_screen.dart`). Kırmızı/uyarı rengi kullanımı ayrıca taranmadı (U) |
| 4 | Güvenilir olmayan ses analizini kesin ölçüm göstermek | **hayır (sözleşme); sınır var** | Güven kapısı ve `multipleSources` ile çok sesli reddedilir (`docs/yula-execution/MEASUREMENT-OST-P0-03-04.md`: ürün yolunda yanlış hüküm 0/28); ancak ürünün sunduğu doğruluk yüzdesi ve cent/zamanlama değerleri eşikleri `expertPending` ve gerçek gitar/cihaz ölçümü YOK (U); sonuç ekranı "Doğruluk" yüzdesi gösterir (`result-accuracy`) — bu rakamın cihazda güvenilirliği doğrulanmadı |
| 5 | Kullanıcıyı sürekli kamera kurmaya zorlamak | **hayır** | Kamera yalnız 2 K8 dersinde, bayrak kapalı; diğer dersler kamerasız (`v1_home_copy.dart`, `camera_lesson.dart`). Eski duruş akışı kamera kapısı arkasında; kapı davranışı `motion_account` paketinde (U) |
| 6 | Oyun başarılarını gerçek müzik becerisiyle karıştırmak | **kısmen** | Rozet/puan/XP yok (`grep`); AMA haftalık seri ve haftalık hedef var (`lib/app/retention/weekly_goal.dart`: seri = hedefe uyum, beceri değil) ve "öz-bildirim" ile "ölçülü" tamamlama aynı ilerleme çubuğunda sayılır mı doğrulanmadı (U); chip'ler ayrımı gösterir (`V1CourseCopy.chipSelfCheck`) |
| 7 | Çalışan kurs ve ilerleme sistemini tasarım uğruna silmek | **hayır (bu işte)** | Bu iş yalnız belge; `diff --stat` yalnız iki belge. ADR-001: gitar/kulak içeriği silinmez |

## Ekran görüntüleri

Görüntü dizini ve üç kaynak (güncel simülatör, test render, tarihsel): [evidence/ux-01/INDEX.md](evidence/ux-01/INDEX.md). Güncel simülatör giriş engelinde kaldı; ana ekranlar yalnız test render (sahte veri) olarak vardır: [evidence/ux-01/render/INDEX.md](evidence/ux-01/render/INDEX.md). Tarihsel `docs/evidence/*.png` güncel build değildir.

## Kapsam dışı / doğrulanamayan

- Gerçek kullanıcı verisi, araştırma, analitik: yok veya okunmadı; zihinsel model ürünün kendi kaynağından çıkarımdır.
- Cihaz-üstü: kaç dokunuşta pratik başlar, ilk 5 saniye görünümü, ses ve kamera akışları, ekran okuyucu.
- Canlı mağaza; `motion_account`/`motion_core`/`motion_camera` paketleri (kamera kapısı, `motionCameraCoachingAvailable`).
- Pratik ekranındaki tüm renk (kırmızı/uyarı) ve `GlassCard` kullanımı taranmadı; sonuç ekranı "önceki denemeyle fark" göstergesi doğrulanmadı.
- `docs/research/`, `docs/evidence/`, `docs/practice/` içerikleri bu işte okunmadı.
