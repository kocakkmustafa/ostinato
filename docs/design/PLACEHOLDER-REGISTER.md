# Placeholder kaydı (ÜRETİLİR — elle düzenleme)

`python3 tools/gen_placeholder_register.py` ile üretilir. Kaynak: `lib/**/*.dart`taki `PLACEHOLDER(kategori): ... — unblocked by: ...` işaretleri + `assets/content/library.json`daki `locked`/`demoOnly` dersler. Bu dosyayı ELLE DÜZENLEME — kaynağı düzenle, betiği koş.

**Toplam: 10 kalem.**

## asset — görsel/foto (0)

_Kayıtlı kalem yok._

## copy — metin (0)

_Kayıtlı kalem yok._

## data — içerik/ölçüm (8)

- **`lib/app/screens/lesson_demo_screen.dart:143`**
  bu kart canlı dirsek/önkol açısı GÖSTERMEZ, yalnız statik ArmRangeHint (öğretmen aralığı) gösterir — unblocked by: motion_core'daki StandardJoints.leftElbow/rightElbow CameraPostureAdapter'a bağlanıp gerçek zamanlı bir açı üretilince (aynı sınır: widgets.dart içindeki SkeletonFigurePainter dirsek/bilek noktaları).
- **`library.json: guitar.foundations.arms`**
  You see your own elbow and forearm angles, live, next to the range the teachers we recorded occupy. What you do not get is a mark, because there is nothing honest to mark you against. unblocked by: A measurement that separates style from mistake on this joint chain — e.g. a harvest where takes are labelled by teaching intent, so agreement can be computed within intent rather than across it.
- **`library.json: guitar.foundations.foot_support`**
  Nothing below your hips is measured. Our posture reference is built from upper-body landmarks only, because guitar teaching footage is filmed waist-up — knees and ankles are usually not in frame at all. Without leg landmarks we cannot tell a footstool from a crossed leg. unblocked by: gerekçenin kendisi (yukarıdaki cümle eksik ölçümün adını taşır)
- **`library.json: guitar.foundations.open_chords`**
  Chord recognition has only been proven on synthetic audio (8/8 chords, zero false judgements) — it hasn't been tested on a real guitar recording yet. We won't grade you against a measurement we haven't confirmed on a real instrument. unblocked by: gerekçenin kendisi (yukarıdaki cümle eksik ölçümün adını taşır)
- **`library.json: voice.foundations.sustained_note`**
  The pitch engine is real and we can show you exactly what it measures — but it has only been confirmed on real cello recordings (48 segments, median error under 19 cents), never on a real singing voice. A voice is not a cello: vibrato, breath and formants are exactly the things that would break it. We will not grade your singing against a measurement we have not confirmed on singing. One real vocal recording through the same pipeline opens this lesson. unblocked by: gerekçenin kendisi (yukarıdaki cümle eksik ölçümün adını taşır)
- **`library.json: voice.foundations.arms`**
  You see your own elbow and forearm angles, live, next to the range the teachers we recorded occupy. What you do not get is a mark, because there is nothing honest to mark you against. unblocked by: A measurement that separates style from mistake on this joint chain — e.g. a harvest where takes are labelled by teaching intent, so agreement can be computed within intent rather than across it.
- **`library.json: piano.foundations.five_finger`**
  We can hear every note you play and time it against the beat — you will see those numbers. What we cannot do is turn them into a mark. No piano teacher data exists on how far off the beat counts as a mistake, and our own timing engine reads a perfect note as 8.3 ms early with a bias that falls harder on rushing than on dragging. A grade built on that would be arithmetic, not teaching. unblocked by: gerekçenin kendisi (yukarıdaki cümle eksik ölçümün adını taşır)
- **`library.json: piano.foundations.arms`**
  You see your own elbow and forearm angles, live, next to the range the teachers we recorded occupy. What you do not get is a mark, because there is nothing honest to mark you against. unblocked by: A measurement that separates style from mistake on this joint chain — e.g. a harvest where takes are labelled by teaching intent, so agreement can be computed within intent rather than across it.

## flow — kapalı adım (2)

- **`lib/app/screens/settings_screen.dart:9`**
  çocuk rejimi (ayrı akış/izin/UI) bu ekranda YOK — unblocked by: kurucu ürün kararı (tasarlanıp tasarlanmayacağı bile henüz KARARLAŞTIRILMADI, bu yüzden burada bir toggle/iskele de YOK — var olmayan bir karara sahte bir yer tutucu inşa etmek kendisi bir taklit olurdu).
- **`lib/app/screens/setup_check_screen.dart:359`**
  oda gürültü-tabanı yakalama adımı KAPALI — tasarım 3-5sn sessizlik ölçen bir kalibrasyon gösterir, bu ekran onun yerine dürüst bir "henüz yok" kartı gösterir (aşağıda). unblocked by: gerçek bir mikrofon-giriş eklentisi `ostinato_audio`nun var olan `AudioConfidenceGate`ine bağlanıp bu ekranın state machine'ine (_Stage.room) gerçek bir örnekleme/geri-sayım aşaması eklenince.
