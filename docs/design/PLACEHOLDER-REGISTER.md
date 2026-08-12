# Placeholder kaydı (ÜRETİLİR — elle düzenleme)

`python3 tools/gen_placeholder_register.py` ile üretilir. Kaynak: `lib/**/*.dart`taki `PLACEHOLDER(kategori): ... — unblocked by: ...` işaretleri + `assets/content/library.json`daki `locked`/`demoOnly` dersler. Bu dosyayı ELLE DÜZENLEME — kaynağı düzenle, betiği koş.

**Toplam: 18 kalem.**

## asset — görsel/foto (1)

- **`lib/app/screens/setup_check_screen.dart:367`**
  KAMERA ÖNİZLEMESİ YOK — bu ekran kadraj rehberi olarak canlı görüntü yerine yukarıdaki STATİK iskeleti çiziyor. Sınıf: ERTELENMİŞ (yapılabilir, biz yapmadık) — `Texture(`/`textureId`/`registrar.textures` ölçüldü: sevk edilen kodda SIFIR; pozitif kontrol `motion_camera| CameraSession` 8 satır, yani kamerayı GERÇEKTEN kullanıyoruz, göstermiyoruz. unblocked by: `motion_camera`nın `registrar.textures` yolunun bu ekrana bağlanması (JabLab `skeleton_overlay.dart` ile AYNI sınıf ve AYNI pin — iki hattın farklı sınıflandırması tek kısıtı iki şeymiş gibi okuturdu). source-only: kullanıcıya "kameranı göstermiyoruz" diyen bir cümle YOK. ⚠️ Bunun bir KULLANICI SONUCU var ve adıyla kayıtlı: kişi kendi kadrajını göremiyor, yalnız "kalçandan omzuna görünmelisin" yazısını okuyor. Cümle YAZMAK bir yüzey kararıdır (koordinatöre bildirildi, sevk kapsamı dışı).

## copy — metin (0)

_Kayıtlı kalem yok._

## data — içerik/ölçüm (14)

- **`lib/app/screens/lesson_demo_screen.dart:143`**
  bu kart canlı dirsek/önkol açısı GÖSTERMEZ, yalnız statik ArmRangeHint (öğretmen aralığı) gösterir — unblocked by: motion_core'daki StandardJoints.leftElbow/rightElbow CameraPostureAdapter'a bağlanıp gerçek zamanlı bir açı üretilince (aynı sınır: widgets.dart içindeki SkeletonFigurePainter dirsek/bilek noktaları). user-surface: demo-live-gap-note
- **`library.json: guitar.foundations.arms`**
  You see the range the teachers we recorded occupy for elbows and forearms, next to a figure of your own trunk. What you do NOT see is your own elbow angle: there is no live elbow measurement in this build, which is also why the arms in that figure are drawn as dashed lines and carry no joint dots. And even with it you would not get a mark, because there is nothing honest to mark you against. unblocked by: A measurement that separates style from mistake on this joint chain — e.g. a harvest where takes are labelled by teaching intent, so agreement can be computed within intent rather than across it.
- **`library.json: guitar.foundations.foot_support`**
  Nothing below your hips is measured. Our posture reference is built from upper-body landmarks only, because guitar teaching footage is filmed waist-up — knees and ankles are usually not in frame at all. Without leg landmarks we cannot tell a footstool from a crossed leg. unblocked by: gerekçenin kendisi (yukarıdaki cümle eksik ölçümün adını taşır)
- **`library.json: guitar.foundations.open_chords`**
  Chord recognition has only been proven on synthetic audio (8/8 chords, zero false judgements) — it has never been tested on a real guitar recording. Synthetic tones have no body resonance, no string buzz and no overlapping decay, which are exactly the things that break a chord classifier. We won't grade you against a measurement we haven't confirmed on a real instrument. unblocked by: gerekçenin kendisi (yukarıdaki cümle eksik ölçümün adını taşır)
- **`library.json: guitar.foundations.strum_timing`**
  Blocked twice over, and either block alone would be enough. First: a strum is one gesture that produces six near-simultaneous note attacks, and the step that maps those attacks onto a single chord event does not exist. Second: even with that step built, we have no teacher data on how far off the beat counts as a mistake for strumming — so there would be nothing to compare you against. We will not open this on a number we invented. unblocked by: gerekçenin kendisi (yukarıdaki cümle eksik ölçümün adını taşır)
- **`library.json: guitar.foundations.chords_beyond_eight`**
  This course teaches eight open chords, and the engine now refuses anything else by name. It did not always. Until 2026-08-04 a played Bb came back as 'Dm' in 28 of 29 windows — confidently — because the engine was only allowed to consider the eight chords of the drill, so the nearest of the eight always won. It now weighs all 24 and refuses when the winner is not one this lesson teaches. Opening a lesson on the other sixteen would mean grading you against a recogniser we have not measured on them. unblocked by: gerekçenin kendisi (yukarıdaki cümle eksik ölçümün adını taşır)
- **`library.json: voice.foundations.sustained_note`**
  The pitch engine is real and we can show you exactly what it measures — but it has only been confirmed on real cello recordings (48 segments, median error under 19 cents), never on a real singing voice. A voice is not a cello: vibrato, breath and formants are exactly the things that would break it. We will not grade your singing against a measurement we have not confirmed on singing. One real vocal recording through the same pipeline opens this lesson. unblocked by: gerekçenin kendisi (yukarıdaki cümle eksik ölçümün adını taşır)
- **`library.json: voice.foundations.arms`**
  You see the range the teachers we recorded occupy for elbows and forearms, next to a figure of your own trunk. What you do NOT see is your own elbow angle: there is no live elbow measurement in this build, which is also why the arms in that figure are drawn as dashed lines and carry no joint dots. And even with it you would not get a mark, because there is nothing honest to mark you against. unblocked by: A measurement that separates style from mistake on this joint chain — e.g. a harvest where takes are labelled by teaching intent, so agreement can be computed within intent rather than across it.
- **`library.json: voice.foundations.vibrato`**
  Vibrato is measured and never judged, and the reason is not a missing tool. We have no teacher data on what rate is 'right'. Inventing a number here would be a guess dressed as a measurement — the one thing this app is built not to do. The lesson opens when a reference exists, not when the engine improves. unblocked by: gerekçenin kendisi (yukarıdaki cümle eksik ölçümün adını taşır)
- **`library.json: voice.foundations.knees_and_chin`**
  These are the two posture mistakes singing teachers actually name, and we cannot see either one. Our reference is built from teaching footage filmed waist-up: it carries no head landmark and knees are usually not in frame at all. So a lifted chin has nothing to be lifted relative to, and locked knees are outside the picture. This is blocked on a new harvest — footage that includes those landmarks — not on a new threshold. unblocked by: gerekçenin kendisi (yukarıdaki cümle eksik ölçümün adını taşır)
- **`library.json: piano.foundations.five_finger`**
  On a recording we can pick out every note and time it against the beat. In your room we cannot: there is no microphone input in this build. Even with one, we could not turn those numbers into a mark — no piano teacher data exists on how far off the beat counts as a mistake, and our own timing engine reads a perfect note as 8.3 ms early with a bias that falls harder on rushing than on dragging. unblocked by: gerekçenin kendisi (yukarıdaki cümle eksik ölçümün adını taşır)
- **`library.json: piano.foundations.arms`**
  You see the range the teachers we recorded occupy for elbows and forearms, next to a figure of your own trunk. What you do NOT see is your own elbow angle: there is no live elbow measurement in this build, which is also why the arms in that figure are drawn as dashed lines and carry no joint dots. And even with it you would not get a mark, because there is nothing honest to mark you against. unblocked by: A measurement that separates style from mistake on this joint chain — e.g. a harvest where takes are labelled by teaching intent, so agreement can be computed within intent rather than across it.
- **`library.json: piano.foundations.shoulder_tension`**
  This is the mistake piano teachers name most often — five independent channels raise it. We can see your shoulders, and that is exactly why we will not judge them: 'shoulders rising toward the ears' is a HEIGHT, and what we measure is an ANGLE. On top of that our three teachers' own shoulder angles differ by 24 degrees on one side and 5 on the other, so there is no agreed position to compare you to. Naming it would be guessing with a measurement in hand. unblocked by: gerekçenin kendisi (yukarıdaki cümle eksik ölçümün adını taşır)
- **`library.json: piano.foundations.hands_and_wrists`**
  We have no hand or finger landmarks at all — only body joints. Every hand-related mistake in our error library is blocked on that missing tool, not on a missing threshold, and the difference matters: a threshold can be measured from teachers, a missing landmark cannot. Until the model reads hands, a collapsed wrist and a good one look identical to this app. unblocked by: gerekçenin kendisi (yukarıdaki cümle eksik ölçümün adını taşır)

## flow — kapalı adım (3)

- **`lib/app/screens/onboarding_screen.dart:33`**
  yaş bandı / vasi onayı (O4) — bu akışta YOK. unblocked by: çocuk rejiminin tasarlanıp tasarlanmayacağına dair kurucu kararı; karar "evet" olursa kapı BURAYA girer (karşılamadan sonra, kütüphaneden önce), çünkü akışı durdurabilecek tek nokta burasıdır. source-only: adım AKIŞTA HİÇ YOK — var olmayan bir adımın kullanıcı cümlesi de olamaz; çocuk rejimi tasarlanırsa yüzey O ZAMAN doğar.
- **`lib/app/screens/settings_screen.dart:11`**
  çocuk rejimi (ayrı akış/izin/UI) bu ekranda YOK — unblocked by: kurucu ürün kararı (tasarlanıp tasarlanmayacağı bile henüz KARARLAŞTIRILMADI, bu yüzden burada bir toggle/iskele de YOK — var olmayan bir karara sahte bir yer tutucu inşa etmek kendisi bir taklit olurdu). source-only: ekranda çocuk rejimine dair kullanıcı cümlesi YOK ve olmamalı — olmayan bir rejimi anlatmak onu varmış gibi gösterirdi. / Canlı çalgı cümlesi — SAYI ve ADLAR `library.json`dan TÜRER. / Elle yazılmış bir "üç çalgı" cümlesi, dördüncüsü eklendiği gün sessizce / yanlış olur ve hiçbir test kırılmaz (O-068).
- **`lib/app/screens/setup_check_screen.dart:380`**
  oda gürültü-tabanı yakalama adımı KAPALI — tasarım 3-5sn sessizlik ölçen bir kalibrasyon gösterir, bu ekran onun yerine dürüst bir "henüz yok" kartı gösterir (aşağıda). unblocked by: gerçek bir mikrofon-giriş eklentisi `ostinato_audio`nun var olan `AudioConfidenceGate`ine bağlanıp bu ekranın state machine'ine (_Stage.room) gerçek bir örnekleme/geri-sayım aşaması eklenince. user-surface: setup-room-gap-body (O-107: bu beyanın KULLANICI cümlesi silinse iki kapı da yeşil kalıyordu — sabotajla ölçüldü; artık `validate_placeholder_surface.py` onu koruyor.)
