#!/usr/bin/env python3
"""Yüzey dürüstlüğü kapısı — kullanıcının OKUDUĞU her metin, ÜÇ kural.

Neden var (2026-08-07, gece vardiyası ölçümü):

  **A) Vaat dili DOSYAYA değil DESENE aittir.** M-F-186 süpürmesi (`e0579ee`
  ve öncesi) `lib/**.dart` içindeki "yet"leri temizledi ve orada durdu.
  Aynı gün ölçtük: `assets/content/library.json` — çalgı sayfasında
  kullanıcının GERÇEKTEN okuduğu metin — hâlâ 5 tane taşıyordu. Kimse fark
  etmedi çünkü süpürmeyi bir KAPI değil bir TUR yapmıştı; tur biter, kapı
  kalır. Aile dersi #8: tuzak dosyaya değil desene yazılır.

  **B) Bir yetenek iddiası, o yeteneğin PLATFORM İZNİYLE tutarlı olmalı.**
  Aynı ölçüm: iki ekran ("the microphone listens to what you play",
  "the microphone reads level and pitch") bu build'de VAR OLMAYAN bir
  mikrofon girişini anlatıyordu — `Info.plist`te
  `NSMicrophoneUsageDescription`, `AndroidManifest.xml`de `RECORD_AUDIO`
  YOK. Üçüncü ekran (Kurulum Kontrolü) ise doğruyu söylüyordu. Metni
  düzeltmek yeterli değil: aile dersi #7 — hatayı düzeltmek değil, hatanın
  İMKÂNSIZ olduğu yapıyı seç. Bu kural iddiayı manifest'e BAĞLAR, yani
  mikrofon gerçekten kablolanıp izin beyan edildiği gün kendini emekliye
  ayırır; o gün kimsenin bu dosyayı hatırlaması gerekmez.

  **C) OLUMLU iddia yüzeyi yalnız BU BUILD'in yapabildiğini söyler.** Kural B
  KELİME arıyordu; asıl iddialar o kelimeyi hiç kullanmıyordu ve ürünün en
  güçlü yüzeyinde duruyordu (`honesty.measured`, `blurb`). Ayrıntı kuralın
  kendi başlığında.

Kapsam: kullanıcıya GÖRÜNEN metin. Dart YORUMLARI kapsam DIŞI (bize yazılır,
kullanıcıya değil) — bu yüzden kaynak taranmadan önce yorumlar sökülür.
JSON'da `_` ile başlayan alanlar ve `$comment` de kayıt alanıdır, kullanıcı
yüzeyi değil. Tanımlayıcı-biçimli string'ler (widget `Key`i, asset yolu)
proza değildir, atlanır.

⚠️ **Kapsamın kendisi de türetilir, elle yazılmaz.** Taranan JSON listesi
`pubspec.yaml`ın `assets:` bloğundan okunur — kapı ilk yazıldığında yalnız
`library.json`a bakıyordu ve kabuğa giden diğer iki metin varlığını (canlı
gözlem cümlesinin golden kataloğu dahil) görmüyordu. Her koşumda kapsam
EKRANA yazılır: bakılmayan bir yer "temiz" sanılamasın diye.
"""
import json
import plistlib
import re
import sys
from pathlib import Path

# ── A: vaat dili ────────────────────────────────────────────────────────────
# Her biri bir ZAMAN taahhüdü ima eder. "Neden yok" dürüstlüktür; "yakında
# gelecek" vaattir — gerekçenin varlığı vaadi affetmez (M-F-186).
PROMISE_PATTERNS = [
    (r"\byet\b", "yet"),
    (r"\bcoming soon\b", "coming soon"),
    (r"\bsoon\b", "soon"),
    (r"\bstay tuned\b", "stay tuned"),
    (r"\bupcoming\b", "upcoming"),
    (r"\bwill be (?:added|supported|available|measured|graded)\b", "will be …"),
    (r"\bin a (?:future|later) (?:build|release|version|update)\b", "in a future build"),
    (r"\bfor now\b", "for now"),
    (r"\bhenüz\b", "henüz"),
    (r"\byakında\b", "yakında"),
]

# ── B: yetenek iddiası ↔ platform izni ──────────────────────────────────────
# Bir yetenek adı geçtiğinde, cümle ya iznin VARLIĞIYLA desteklenmeli ya da
# YOKLUĞUNU söyleyen bir ifade taşımalı. Üçüncü seçenek (sessizce iddia
# etmek) tam da düzeltilen kusurdu.
CAPABILITY_RULES = [
    {
        "name": "mikrofon",
        "mention": r"\bmicrophone\b|\bmikrofon\b",
        # Yokluğu SÖYLEYEN ifadeler — bunlardan biri varsa cümle dürüsttür.
        "absence": [
            r"\bno (?:live )?microphone\b",
            r"microphone[^.]{0,40}\bis not wired\b",
            r"microphone[^.]{0,40}\bnot wired\b",
            r"\bnot wired in this build\b",
            r"\bno audio permission\b",
            r"\bthere is no microphone input\b",
        ],
        # İzin beyan edildiği gün kural kendini kaldırır.
        "ios_key": "NSMicrophoneUsageDescription",
        "android_permission": "android.permission.RECORD_AUDIO",
    },
]

# ── C: OLUMLU iddia yüzeyleri yalnız BU BUILD'in yapabildiğini söyler ───────
# Kural B "microphone" KELİMESİNİ arar. Ölçüldü (2026-08-07): asıl iddialar o
# kelimeyi hiç kullanmıyordu — «Note timing against the beat — measured and
# shown to you», «Whether the room is quiet enough and your voice is loud
# enough», «listen for the chords you play». Üçü de `honesty.measured` ve
# `blurb` içindeydi, yani ürünün EN GÜÇLÜ iddia yüzeyinde.
#
# Bu kural KELİMEYİ değil ALANI hedefler: bu iki yol OLUMLU iddiadır ("bunu
# ölçüyoruz"), ses alanına ait bir kavram anmaları ancak canlı bir ses girişi
# varsa meşrudur. `notMeasured` ve `comingSoonInThisDiscipline` KAPSAM DIŞI —
# onlar zaten yokluğu anlatır, ses kavramlarını serbestçe anmalıdırlar.
# ⚠️ KAPSAM TERS ÇEVRİLDİ (2026-08-07, O-055 — JabLab J-126 dersi).
#
# İlk hâli OLUMLU yolları SAYIYORDU (`honesty.measured` + `blurb`). Ölçüldü:
# `library.json`da 14 kullanıcı-yüzeyi proza alanı var, kural İKİSİNİ
# kolluyordu — ve ÜÇÜNÜ bu kural yazıldıktan SONRA ben ekledim
# (`instrumentSpecificGap` · `outOfScopeDerived` · `promotionPath.unblockedBy`).
# **Kapsam beyanı, altındaki yapı değişince bayatlar.** Kapı yeşil kaldı ve o
# alanlarda kimse bakmadı: *yeşil bir kapı, bakılmayan bir alan üretir.*
#
# Denetlenmeyen kapsamda ÜÇ CANLI İHLAL vardı (hepsi düzeltildi):
#   · `courses[].goal` gitar  — "learn to HEAR when you're playing the right
#     open chord" (canlı ses iddiası, mikrofon yok)
#   · `courses[].goal` şan    — "standing and SINGING" (faz ses-tetikli)
#   · `demoOnlyReason` ×3     — "You see your own elbow and forearm angles,
#     LIVE" — canlı dirsek ölçümü YOK; ekran bunu doğru söylüyordu ("when
#     this is live"), İÇERİK söylemiyordu.
#
# Şimdi VARSAYILAN OLUMLU: yokluk anlatan yollar İSİMLE muaf, geri kalan HER
# proza alanı denetlenir. Yeni bir alan eklendiğinde kapsam KENDİLİĞİNDEN
# genişler — muafiyet istiyorsa buraya yazılması GEREKİR, ve o yazım bir
# gözden geçirme anıdır.
ABSENCE_JSON_PATHS = [
    # "ölçmediklerimiz" — zaten yokluk anlatır
    re.compile(r"\.honesty\.notMeasured\[\d+\]$"),
    re.compile(r"\.honesty\.instrumentSpecificGap$"),
    re.compile(r"\.honesty\.outOfScopeDerived\[\d+\]$"),
    re.compile(r"\.comingSoonInThisDiscipline\[\d+\]$"),
    # kilit/engel gerekçeleri — hepsi "neden YOK"u anlatır
    re.compile(r"\.lockedReason$"),
    re.compile(r"\.promotionPath\.(?:blockedBy|unblockedBy|ifItStaysBlocked)$"),
    # ad/etiket alanları — cümle değil (kısa, iddia taşımaz)
    re.compile(r"\.displayName$"),
    re.compile(r"^[^.]*\.productName$"),
]

AUDIO_CONCEPTS = re.compile(
    r"\b(chord|chords|pitch|note timing|onset|beat|loudness|loud enough|"
    r"room (?:is )?quiet|noise floor|microphone|audio|listen|listens|"
    # "while you sing/play" bir ZAMAN ifadesi gibi görünür ama SES tetiğidir:
    # o fazlar `periodicity`/`level_above_room_floor_db` ile açılıyor (O-047).
    # Canlı giriş yokken o pencereler HİÇ oluşmaz, yani iddia ölçümün
    # yapıldığı ANLARIN yarısını kapsayıp o yarıyı erişilemez bırakır.
    r"while you (?:sing|play)|as you (?:sing|play)|"
    r"hear|hears|sound)\b", re.IGNORECASE)
# Yokluğu söyleyen cümle geçer (kural B ile aynı mantık).
AUDIO_ABSENCE = re.compile(
    r"no microphone input|hears nothing|never listen|"
    r"not wired in this build|no audio permission", re.IGNORECASE)


# ── D: OLUMLU iddia, "koçlanan ama SKORLANMAYAN" eklemi sahiplenemez ────────
# (JabLab J-113 aktarımı, koordinatör 2026-08-07 — SKOR ekseni.) JabLab'ın
# kusuru şuydu: `coachedOnlyJoints` bir eklemi açıkça "koçlanan ama
# SKORLANMAYAN" kovasına koyuyordu, `measured` listesi ise aynı şeyi SINIRSIZ
# iddia ediyordu. **İki temsil çelişiyordu ve çelişen taraf en görünür
# yerdeydi.** Sınıfı M-F-287'nin TERS yönü: bir sınırı değil bir YETENEĞİ
# olduğundan geniş yazmak — daha tehlikeli, çünkü kullanıcı ALEYHİNE hata
# verir.
#
# Kova ELLE yazılmıyor: her çalgının kendi ruleset'indeki `coached_only`
# listesinden okunuyor, yani kova değişirse kural da değişir.
JOINT_WORDS = {
    "shoulder": r"\bshoulders?\b",
    "upper_arm": r"\bupper arms?\b",
    "elbow": r"\belbows?\b",
    "forearm": r"\bforearms?\b",
}
# "ölçülür ama puanlanmaz" DİYEN cümle meşrudur — iddia zaten sınırlı.
#: CANLILIK iddiası — "şu anda, canlı olarak görüyorsun". `coached_only`
#: eklemlerin canlı ölçümü YOK (kaynak şerhi: `lesson_demo_screen.dart`
#: "canlı kol/önkol açısı okuması burada YOK", ve figür kolları tam bu
#: yüzden KESİKLİ çiziliyor). Ölçüldü (O-055): `demoOnlyReason` üç derste de
#: "You see your own elbow and forearm angles, LIVE" diyordu — ekran doğruyu
#: söylüyordu ("when this is live"), İÇERİK söylemiyordu.
LIVE_CLAIM = re.compile(r"\blive\b|\bright now\b|\bas you (?:sit|play|sing)\b",
                        re.IGNORECASE)
#: Canlılığın YOKLUĞUNU söyleyen ifadeler.
NOT_LIVE = re.compile(
    r"no live |not see your own|do not see|when this is live|"
    r"is not measured live|dashed", re.IGNORECASE)

NOT_GRADED = re.compile(
    r"never graded|not graded|never marked|do not grade|"
    r"never judged|not judged|show(?:n)? .{0,20}never|"
    # O-055: dürüst metin "you would not get a mark, because there is
    # nothing honest to mark you against" diyor — aynı hükmü kuran ama
    # sözlükte olmayan üç kalıp. Kural gevşemedi, sözlüğü tamamlandı.
    r"not get a mark|nothing honest to mark|no mark\b", re.IGNORECASE)


def coached_only_joints(instrument):
    p = Path(f"config/rulesets/{instrument}@0.2.0-draft.json")
    if not p.exists():
        return []
    rc = json.loads(p.read_text(encoding="utf-8")).get(
        "referenceConsumption", {})
    return rc.get("coached_only", []) or []


# ── E: SAKLAMA iddiası, saklayan bir KOD YOLU ister ────────────────────────
# (Yayın envanteri, O-054 — JabLab'ın "üretici yok ama beyan onu ANLATIYOR"
# sınıfı.) İki yüzey "what we keep is the body angles we measured" /
# "only the body angles we measure are kept" diyordu. Ölçüldü: `lib/` içinde
# TEK dosya yazımı karşılama işaretidir, hiçbir ölçüm saklanmıyor.
#
# En sinsi yanı: **sonuç DOĞRUYDU** (video cihazdan çıkmıyor), yalnız
# GEREKÇE uydurmaydı. Doğru sonucu yanlış gerekçeyle söylemek en zor
# yakalanan hatadır — kimse sonucu sorgulamadığı için gerekçe hiç
# denetlenmez. Üstelik cümle bir gizlilik İMTİYAZI kılığındaydı, yani
# kullanıcıya var olmayan bir KAYIT olduğunu düşündürüyordu.
# ⚠️ DESEN ÖZNE-BAĞIMSIZ YAZILIR (O-099, 2026-08-12 — bu deliğin ÖLÇÜLDÜĞÜ
# vaka): önceki hâli özneyi desenin İÇİNE gömüyordu (`we keep` · `are kept` ·
# `we store`). Ölçüldü: 08-07'de `settings_screen`de düzeltilen cümle
# *"only the body angles we measure **are kept**"* YAKALANIYORDU, ama AYNI
# İDDİANIN üçüncü-şahıs-aktif hâli — `Info.plist`teki *"the app only
# **keeps** the body angles it measures"* — KAÇIYORDU. Desen sağlamdı
# (öz-test örneğini yakalıyordu); delik DİLBİLGİSİNDEYDİ.
#
# → Bir iddia düzeltildiğinde DÜZELTİLEN CÜMLE değil İDDİA aranır. Desen
#   artık özneyi hiç saymıyor: SAKLAMA FİİLİ + SAKLANABİLİR NESNE arıyor.
#   Böylece "the app keeps", "we keep", "are kept", "Ostinato retains" —
#   dördü de aynı kapıdan geçer, ve yeni bir özne icat etmek deseni
#   atlatmaz. Nesne listesi sınırlı tutuluyor ki "keep your phone steady"
#   ya da "keeps you inside the band" YANLIŞ-POZİTİF üretmesin (ikisi de
#   sevk edilen yüzeyde geçiyor — ölçüldü).
_RETENTION_VERB = (r"(?:keeps?|kept|stores?|stored|retains?|retained|"
                   r"saves?|saved|records?|recorded|logs?|logged)")
# ⚠️ NESNE LİSTESİ DAR TUTULUR — ve bu sınır ÖLÇÜLEREK çizildi, tahminle
# değil. İlk yazımda liste `points?|frames?|readings?|sessions?|data` da
# içeriyordu; kapı GERÇEK korpusta koşturulunca ÜÇ yanlış-pozitif verdi:
#   · "At the distance that keeps your hips IN FRAME …"  → `frame` kadraj,
#     saklanan kare değil
#   · "…the {n} {sourceClass} we RECORDED was {deg}°; you're currently
#     READING {measured}" → `reading` fiil, saklanan ölçüm değil
# İkisi de saklama İDDİASI değil. Ders: olumsuz örnekleri DESENİ YAZAN
# seçerse, kaçırdığı biçimi de seçer — panzehir, kapıyı gerçek korpusta
# koşturmak. O üç cümle artık NEGATIVE_SAMPLES'ta kalıcı.
#
# Nesne KULLANICI VERİSİNE işaret etmeli: eğitmen korpusunu "kaydettik"
# demek bir saklama iddiası DEĞİL (o bizim referans malzememiz).
# `footage` KULLANICI-KAPSAMLI yazılır (`your footage`): sevk edilen metinde
# "footage" neredeyse daima EĞİTMEN malzemesidir ("the teaching footage our
# references come from was recorded waist-up") — kapsamsız bırakmak o cümleyi
# saklama iddiası sayardı. Kullanıcının kaydı bu üründe "video".
_RETENTION_OBJECT = (r"(?:angles?|landmarks?|measurements?|"
                     r"video|your footage|history|session data|your data)")
RETENTION_CLAIM = re.compile(
    # aktif: "keeps the body angles" (özne kim olursa olsun)
    rf"\b{_RETENTION_VERB}\b[^.!?]{{0,40}}?\b{_RETENTION_OBJECT}\b|"
    # edilgen: "the angles are kept"
    rf"\b{_RETENTION_OBJECT}\b[^.!?]{{0,40}}?\b(?:are|is|was|were)\s+"
    rf"{_RETENTION_VERB}\b|"
    rf"\bsaved on (?:your|this) (?:phone|device)\b|\byour history\b",
    re.IGNORECASE)
# Yokluğu söyleyen cümle geçer. ("nothing is recorded" O-099'da eklendi —
# aynı iddianın başka fiille söylenmiş yokluk hâli; Choreia'nın izin metni
# tam bu biçimi kullanıyor, aile ölçümü 4/5.)
RETENTION_ABSENCE = re.compile(
    r"nothing is stored|none to delete|no history|are gone when|"
    r"is gone when|not stored|nothing is kept|nothing is recorded|"
    r"nothing is saved|nothing is retained|nothing is logged", re.IGNORECASE)
#: Ölçüm SAKLAYAN bir kod yolu nasıl görünürdü. Karşılama işareti ve poz
#: modeli dosyası HARİÇ (ikisi de ölçüm değil): dosya adlarıyla muaf.
RETENTION_WRITERS = re.compile(
    r"writeAsString|writeAsBytes|SharedPreferences|Hive\.|sqflite|"
    r"\.insert\(|openDatabase")
RETENTION_EXEMPT_FILES = {"onboarding_store.dart", "pose_model.dart"}

# ── İDDİA ↔ ÖLÇÜM BAĞI (O-102, Gravita `f169ba5`ten doğan kısıt) ─────────
#
# Her ÖZNE için: saklanıyor mu (`stored`) + bunu SÖYLEYEN ÖLÇÜM (`evidence`).
# `evidence` bir gerekçe değil bir ADRES olmalı — hangi tarama/dosya/sayı bu
# hükmü verdi. Beyanın kendisi kanıt değildir; kanıtın YERİNİ gösterir.
#
# ⚠️ Bu kayıt bir MUAFİYET LİSTESİ DEĞİL, bir KARAR NOKTASI: bir özne
# hakkında iddia eden bir cümle sevk edilmişse, o öznenin burada bir kaydı
# OLMAK ZORUNDA. Kayıt yoksa kapı öter (*"ölçmedim ama iddia ettim"*).
#
# Ostinato ölçümü (2026-08-12): `lib/` içinde diske yazan **iki** yer var —
# `onboarding_store.dart` (karşılama biti, ÖLÇÜM DEĞİL) ve `pose_model.dart`
# (model asset'i, ÖLÇÜM DEĞİL). Üçüncü bir yazıcı YOK; ağ çağrısı YOK.
# Gravita'da üç yazıcı vardı ve landmark hiçbirinde değildi — *"bir şey
# yazılıyor"* ile *"BU ŞEY yazılıyor"* farklı sorular, kayıt bu yüzden
# ÖZNE BAŞINA tutulur.
RETENTION_FACTS = {
    "angle": {"stored": False, "evidence":
              "lib/ yazıcı taraması: muaf olmayan writeAsString/Bytes/"
              "SharedPreferences/Hive/sqflite SIFIR (2 muaf yazıcı: "
              "karşılama biti + poz modeli asset'i)"},
    "landmark": {"stored": False, "evidence":
                 "aynı tarama; ayrıca canlı zincir yalnız trunkTiltDeg "
                 "skalerini taşıyor (camera_posture_adapter), landmark "
                 "dizisi ekrandan öteye geçmiyor"},
    "measurement": {"stored": False, "evidence":
                    "aynı tarama; ölçüm seans içinde bellekte, kalıcı "
                    "yazıcı yok"},
    "video": {"stored": False, "evidence":
              "aynı tarama + kamera karesi hiçbir dosyaya yazılmıyor; "
              "ağ çağrısı da yok (Kural J: yükleyen yol SIFIR)"},
    "your footage": {"stored": False, "evidence": "video ile aynı ölçüm"},
    "history": {"stored": False, "evidence":
                "aynı tarama; geçmiş ekranı YOK (review_screen seans-içi)"},
    "session data": {"stored": False, "evidence":
                     "aynı tarama; seans kaydı tutan bir yol yok "
                     "(Gravita'da VARDI — bu hattın ölçümü ayrı)"},
    "your data": {"stored": False, "evidence": "yukarıdaki öznelerin toplamı"},
}

#: Cümledeki saklama ÖZNESİNİ çıkarır — hangi nesne eşleşti. `RETENTION_FACTS`
#: anahtarlarına normalize eder (çoğul → tekil), böylece kayıt tek biçimde
#: tutulur ve "angles"/"angle" ayrı kayıt gerektirmez.
#
#: ⚠️ DOLAYLI ÖZNELER (O-102, kendi ölçümümün bulduğu delik): özne çıkarıcı
#: ilk yazımda `_RETENTION_OBJECT`i olduğu gibi kullanıyordu ve sevk edilen
#: DÖRT saklama cümlesinden BİRİ özne vermiyordu —
#: *"Nothing is stored either: **what we measure** exists while the lesson
#: runs…"* (onboarding). Kod onu SESSİZCE atlıyordu (`if not subjects:
#: continue`), yani cümle saklama hükmü veriyor ama hiçbir ölçüme
#: bağlanmıyordu. Günün deseni burada da: *bir şeyi bulamayan tarama,
#: bulunacak bir şey olmadığını kanıtlamaz.*
#: Çözüm iki katmanlı: ① dolaylı biçimler özneye çevrilir ② hâlâ özne
#: çıkmazsa bu SESSİZ kalmaz, kapsam satırında SAYIYLA raporlanır.
#: Not: bu alternasyon YALNIZ özne çıkarımında kullanılır; `RETENTION_CLAIM`
#: dar kalır (dolaylı kalıpları TESPİTE sokmak yanlış-pozitif üretirdi).
_SUBJECT_PARAPHRASE = [
    (r"what (?:we|the app|it|ostinato) measures?", "measurement"),
    (r"what (?:we|the app|it|ostinato) reads?", "measurement"),
    (r"the (?:body )?positions?", "landmark"),
]
_SUBJECT_RE = re.compile(_RETENTION_OBJECT, re.IGNORECASE)
_PARAPHRASE_RES = [(re.compile(p, re.IGNORECASE), k)
                   for p, k in _SUBJECT_PARAPHRASE]


def retention_subjects(sentence: str):
    """Cümlenin saklama hükmü verdiği ÖZNELER (normalize, sırayı korur)."""
    out = []
    for m in _SUBJECT_RE.finditer(sentence):
        raw = m.group(0).lower()
        key = raw if raw in RETENTION_FACTS else raw.rstrip("s")
        if key not in out:
            out.append(key)
    for rx, key in _PARAPHRASE_RES:
        if rx.search(sentence) and key not in out:
            out.append(key)
    return out

# ── J: YÜKLEME-YOKLUĞU iddiası, YÜKLEYEN bir kod yolunun YOKLUĞUNU ister ──
# (O-080, 2026-08-07 — E'nin ağ kardeşi.)
#
# Altı sevk edilen yüzey şunu söylüyor: *"Raw video never leaves this device"*,
# *"Nothing is uploaded"*, *"Video never leaves your phone"*. Bugün ÖLÇÜLDÜ:
# hepsi DOĞRU. Ama **hiçbir kapı onları korumuyordu** — yarın biri analitik
# SDK'sı eklerse altı cümle birden yalana döner ve hiçbir şey ötmez.
#
# ⚠️ Bu kuralı yazarken kendi brifimdeki bir abartıyı da düzelttim:
# `google_fonts` açılışta Google CDN'ine gidiyor, ama bu bir **GET**tir —
# "yüklenmiyor" iddiasını YALANLAMAZ. Kural bu ayrımı KODLAR; "ağa çıkan her
# şey iddiayı bozar" demek KOLAY ama YANLIŞ olurdu ve kapıyı gürültüye
# boğardı (O-057: geniş kapsam → yanlış-pozitif → kapı susturulur).
#
# Kalıcı olan kısım: ağa çıkabilen HER bağımlılık **kayıtlı** olmak zorunda.
# Kayıtsız bir tanesi belirdiğinde kapı öter — çünkü o noktada iddianın hâlâ
# geçerli olup olmadığı bir İNSAN KARARIDIR, bir varsayım değil.
UPLOAD_CLAIM = re.compile(
    r"nothing is uploaded|never leaves (?:this|your) (?:device|phone)|"
    r"does not leave (?:this|your) (?:device|phone)|nothing (?:is )?sent",
    re.IGNORECASE)
#: Kullanıcı verisini DIŞARI taşıyan kod yolları.
UPLOADER_TRACES = re.compile(
    r"\bhttp\.post\b|\bhttp\.put\b|\bDio\(|\bHttpClient\(|\bWebSocket\b|"
    r"MultipartRequest|\.upload\(")
#: Ağa çıkabilen ama kullanıcı verisi TAŞIMAYAN, KAYITLI bağımlılıklar.
#: Yeni bir tanesi eklendiğinde kapı öter — kayıt bir MUAFİYET değil, bir
#: KARAR NOKTASIDIR.
NETWORK_DEPS_RECORDED = {
    # O-104 (JabLab J-217'nin bulgusundan, kendi ağacımda YENİDEN ölçüldü):
    # kayıt eskiden yalnız "yazı tipi indirir (GET)" diyordu — doğru ama
    # EKSİK. Ölçülen tam hâl: ÜRETİMDE ağa çıkıyor (`ostinato_theme.dart` 3
    # çağrı) · `allowRuntimeFetching` üretimde HİÇ kapatılmamış · paketlenmiş
    # font SIFIR → font yüzleri ilk açılışta Google'ın sunucularından iniyor.
    # ⭐ JabLab'ın cümlesi, aynen taşınıyor çünkü ölçüm burada da aynı:
    #   *"Kendi kodunda ağ olmaması, ürününde ağ olmaması demek değildir."*
    # ⚠️ VE BU HATTIN ÖLÇTÜĞÜ EK: çekme 8 TEST dosyasında kapatılmış,
    # üretimde değil → HİÇBİR TEST bu davranışı GÖREMEZ. Kapı eksik değil,
    # KÖR EDİLMİŞ — ve körlük iyi niyetle (ağsız test) konmuş.
    # Ayrıntı + kapı: `tools/validate_runtime_fetch.py`.
    "google_fonts": "ÜRETİMDE AĞA ÇIKIYOR — font yüzleri çalışma anında "
                    "Google'dan iniyor (ostinato_theme.dart 3 çağrı · "
                    "allowRuntimeFetching üretimde kapatılmamış · paketlenmiş "
                    "font 0). Kullanıcı verisi GÖNDERİLMİYOR (istek font "
                    "dosyası için), o yüzden 'video cihazdan çıkmıyor' ve "
                    "'hiçbir şey yüklenmiyor' iddiaları HÂLÂ DOĞRU; ama "
                    "'ürün ağa çıkmıyor' cümlesi bu paket yüzünden YANLIŞ "
                    "olurdu — ölçüldü: öyle bir cümle sevk edilmiyor (0)",
    "http": "TRANSİTİF — google_fonts'un altında geliyor (pubspec.lock: "
            "`dependency: transitive`), lib/'de DOĞRUDAN import YOK "
            "(ölçüldü, `package:http` sıfır çağrı). google_fonts'un GET-only "
            "gerekçesi bunu da kapsar; kendi başına ek yükleme yolu değil.",
}
#: Ağa çıkabilen bağımlılık ailelerinin izleri (pubspec adlarında aranır).
#: ⚠️ Lissom'un O-080 reçetesini port ederken bulduğu delik (koordinatör
#: 2026-08-11, kaynakta doğrulandı): `posthog`/`amplitude`/`mixpanel`/
#: `segment`/`appsflyer`/`adjust` `\w*` TAŞIMIYORDU — Flutter'da baskın paket
#: adı biçimi SONEKLİ (`posthog_flutter`, `amplitude_flutter`, ...), desen
#: yalnız tam-adı yakalıyordu. Öz-test bunu görmedi çünkü bu repodaki TEK ağ
#: bağımlılığı (`google_fonts`) soneksiz — kapsam yerel gerçeklik kadardı.
#: Artık HEPSİ `\w*` taşıyor: yakalama alanını yalnız BÜYÜTÜR, daraltmaz.
NETWORK_DEP_HINTS = re.compile(
    r"^\s+(http|dio|firebase\w*|sentry\w*|posthog\w*|amplitude\w*|mixpanel\w*|"
    r"segment\w*|appsflyer\w*|adjust\w*|google_fonts|supabase\w*|graphql\w*|"
    r"web_socket\w*):",
    re.MULTILINE)

# ── ⑤ DEĞİŞİM-DEDEKTÖRÜ: ret-listesi yerine TAM BÖLME ────────────────────
#
# **Kaynak: ADAPTE EDİLDİ, İCAT EDİLMEDİ.** Lissom `1abd4a0` (2026-08-12,
# M-F-455 ③) bu problemi zaten çözmüştü ve çözümü benim önerimden GÜÇLÜ:
# ben *"paket-kümesi anlık görüntüsü, küme değişince öt"* önermiştim — o
# **BÖLME** yazdı. Fark şu: anlık görüntü DEĞİŞİMİ yakalar, bölme
# TAMLIĞI ZORLAR. Yeni bir paket eklendiğinde anlık görüntü "değişti" der
# ve insan onu görmezden gelebilir; bölmede paket üçüncü hâlde kalır ve
# kapı KIRMIZI yanar. (Koordinatör sevki: *"karşılıyorsa adapte et"*.)
#
# **Delik neydi (M-F-455, koordinatörün kendi ölçümü):** `NETWORK_DEP_HINTS`
# bir RET-LİSTESİDİR — adı listede olmayan bir paket sessizce geçer.
# Ostinato'da ÖLÇÜLDÜ: `pubspec.lock` 65 paket, `NETWORK_DEPS_RECORDED` 2 →
# **63 paket hiçbir kapıdan geçmiyordu.** Ve desen tam-eşleşme aradığı için
# (`^\s+http:`) `http_parser:` gibi ÖNEK PAYLAŞAN bir ad bile görülmüyordu.
#
# **Kural:** `pubspec.lock`taki HER paket `NETWORK_DEPS_RECORDED` (ağa
# çıkabilir, gerekçeli) ⊎ `NETWORK_DEPS_KNOWN_SAFE` (çıkamaz, gerekçeli)
# bölmesine girmek ZORUNDA. Üçüncü hâl (ikisinde de YOK) ya da çelişki
# (ikisinde de VAR) → KIRMIZI. Liste kendiliğinden BÜYÜMEZ: yeni paket
# geldiğinde kapı öter, sınıflandırma bir İNSAN KARARIdır.
#
# **DÜRÜST SINIR — isimle (Lissom'un sınırı, aynen taşınıyor):** bu
# sınıflandırma her paketin KAYNAK KODUNU okuyarak DEĞİL, KATEGORİ+İTİBARLA
# yapıldı (Dart/Flutter SDK'sının kendi paketleri; tek-amaçlı, I/O yüzeyi
# olmayan ekosistem paketleri). `http_parser` kaydının kullandığı ilkenin
# aynısı — 63 paket için tek tek kaynak okuması YAPILMADI.
#
# Kapsam: yalnız BUGÜN `pubspec.lock`ta olan paketler.
NETWORK_DEPS_KNOWN_SAFE = {
    "args": "komut satırı argüman ayrıştırma, I/O yok",
    "async": "Future/Stream yardımcıları, kendi başına I/O yapmaz",
    "boolean_selector": "test etiketi ayrıştırma, I/O yok",
    "characters": "Unicode grapheme kümesi işlemleri, I/O yok",
    "clock": "saat soyutlaması (test için), I/O yok",
    "code_assets": "derleme-zamanı native varlık meta-verisi, I/O yok",
    "collection": "saf veri yapısı, I/O yok",
    "crypto": "SHA-256 hesaplama (reference_equivalence kanıt zinciri) — ",
    "cupertino_icons": "ikon font VARLIĞI (ttf), çalışma zamanı kodu yok — I/O yüzeyi yok",
    "fake_async": "test için zaman simülasyonu, I/O yok",
    "ffi": "native bellek/işlev arayüzü (C interop), ağ değil",
    "flutter": "Flutter SDK",
    "flutter_lints": "yalnız analiz kuralları (dev_dependency), sevk edilen kodda ÇALIŞMAZ",
    "flutter_test": "Flutter SDK",
    "flutter_web_plugins": "Flutter SDK",
    "hooks": "derleme-zamanı hook sözleşmesi, I/O yok",
    "http_parser": "HTTP MESAJ AYRIŞTIRMA (başlık/medya-tipi string işleme), SOKET AÇMAZ — adı `http` öneki taşıdığı için ret-listesi desenine benziyor ama ret-listesi deseni TAM eşleşme aradığı için onu HİÇ görmüyordu: bölmenin yakaladığı ilk gerçek vaka",
    "jni": "Java native interop köprüsü (poz modeli), ağ değil",
    "jni_flutter": "jni paketinin Flutter eklentisi",
    "jni_util": "jni paketinin yardımcı kütüphanesi",
    "leak_tracker": "bellek-sızıntısı test aracı, dev-only, I/O yok",
    "leak_tracker_flutter_testing": "leak_tracker'ın Flutter eklentisi, dev-only",
    "leak_tracker_testing": "leak_tracker'ın test-altyapısı parçası, dev-only",
    "lints": "statik analiz kural paketi, dev-only, ÇALIŞMA ZAMANINDA hiç yok",
    "logging": "yerel log FASADI, varsayılan sink yok (uzağa göndermez)",
    "matcher": "test-altyapısı (expect/matcher), I/O yok",
    "material_color_utilities": "Material renk algoritmaları, saf hesaplama",
    "meta": "yalnız annotation, çalışma zamanı kodu yok",
    "motion_camera": "aile paketi, pinli — motion_core ile aynı gerekçe",
    "motion_core": "aile paketi, pinli — kendi başına A3 kapsamı DIŞINDA ",
    "objective_c": "Objective-C native interop köprüsü, ağ değil",
    "ostinato_posture": "BU DEPONUN kendi paketi (path bağımlılığı), ağ kodu yok — kaynağı burada",
    "package_config": "paket çözümleme meta-verisi okuma (yerel dosya), ağ değil",
    "path": "dosya yolu string işlemleri, I/O yok",
    "path_provider": "yerel dizin yolu çözümü, dosya sistemi — ağ değil",
    "path_provider_android": "path_provider'ın Android platform eklentisi",
    "path_provider_foundation": "path_provider'ın iOS/macOS platform eklentisi",
    "path_provider_linux": "path_provider'ın Linux platform eklentisi",
    "path_provider_platform_interface": "path_provider sözleşme soyutlaması",
    "path_provider_windows": "path_provider'ın Windows platform eklentisi",
    "permission_handler": "OS izin API'si, ağa çıkmaz (pubspec.yaml'da beyanlı)",
    "permission_handler_android": "permission_handler'ın Android eklentisi",
    "permission_handler_apple": "permission_handler'ın iOS/macOS eklentisi",
    "permission_handler_html": "permission_handler'ın web eklentisi",
    "permission_handler_platform_interface": "permission_handler sözleşmesi",
    "permission_handler_windows": "permission_handler'ın Windows eklentisi",
    "platform": "işletim sistemi/platform TESPİTİ, ağ değil",
    "plugin_platform_interface": "Flutter eklenti sözleşme soyutlaması, I/O yok",
    "pub_semver": "sürüm dizesi ayrıştırma, I/O yok",
    "record_use": "derleme-zamanı kullanım kaydı (tree-shaking), I/O yok",
    "sky_engine": "Flutter SDK (Dart core kütüphaneleri SDK snapshot'ı)",
    "source_span": "kaynak-konum izleme (derleyici altyapısı), I/O yok",
    "stack_trace": "hata izi biçimlendirme, I/O yok",
    "stream_channel": "Stream soyutlaması, kendi başına I/O yapmaz",
    "string_scanner": "string ayrıştırma, I/O yok",
    "term_glyph": "terminal Unicode/ASCII glif seçimi, I/O yok",
    "test_api": "test-altyapısı sözleşmesi, I/O yok",
    "typed_data": "ikili veri görünümleri, I/O yok",
    "vector_math": "saf matematik (matris/vektör), I/O yok",
    "vm_service": "Dart VM hata-ayıklama protokolü, yerel/geliştirme aracı",
    "web": "tarayıcı JS-interop bağlamaları — ÖLÇÜLDÜ: bu depoda `web/` dizini YOK, hedef platformlar yalnız android+ios; kullanılsa bile ÇAĞIRAN kod sorumludur ve kanal ① onu yakalar",
    "xdg_directories": "Linux XDG dizin yolları, dosya sistemi — ağ değil",
    "yaml": "YAML ayrıştırma, kendi başına I/O yapmaz",
}


def lock_packages(lock_text: str):
    """`pubspec.lock`taki paket adları — bölme bunun ÜZERİNDE tanımlıdır."""
    return re.findall(r"^  ([a-z0-9_]+):$", lock_text, re.MULTILINE)



# ── F: kullanıcı yüzeyi TEK DİLDİR (bugün: İngilizce) ─────────────────────
# Bu gece İKİ kez sızdı ve ikisi de BAŞKA bir kuralın yan etkisiyle ya da
# elle yakalandı, yani şans eseri:
#   · `promotionPath.unblockedBy` — mikrofon şerhini Türkçe bırakmıştım
#     (kural B "mikrofon" kelimesini gördüğü için tesadüfen çıktı)
#   · `gen_out_of_scope.py` çıktısı — taksonominin `names[0]`ı Türkçeydi
#     (gözle görüldü, hiçbir kapı bakmıyordu)
# Kütüphane baştan sona İngilizce (`library.json` `language` alanı da öyle
# diyor). Türkçe bir cümle İngilizce konuşan kullanıcıya GİDER ve hiçbir
# testi kırmaz — sessiz, ama kullanıcı için en görünür kusur sınıfı.
#
# ⚠️ Bu kural DİL DEĞİŞTİĞİ gün güncellenmeli: TR yerelleştirmesi geldiğinde
# yüzey artık tek dilli olmayacak. O yüzden hangi dil olduğu `library.json`ın
# `language` alanından OKUNUYOR, buraya sabitlenmedi.
TURKISH_CHARS = set("ğĞşŞıİçÇ")   # ö/ü/â Fransızca-Almanca alıntılarda da geçer
#: TANI metni — `assert(...)` ve fırlatılan hata mesajları. Bunlar hiçbir
#: zaman `Text()`e girmez: assert release'te SÖKÜLÜR, `StateError` ise
#: framework hata yüzeyine düşer. Bu ekip tanı metnini TÜRKÇE yazıyor ve bu
#: DOĞRU — kural yalnız kullanıcı yüzeyini kolluyor.
#: ⚠️ Muafiyet YALNIZ kural F için: bir tanı metninin Türkçe olması meşru,
#: ama içinde vaat dili ya da yanlış yetenek iddiası olması yine de ölçülür.
#: Bir literal TANI metni midir? Literalin kendi satırı ve ondan ÖNCEKİ iki
#: satır bir tanı yapısı içeriyorsa evet. Karakter-konumlu geri bakış İKİ KEZ
#: yanlış çalıştı (önce çok-satırlı `throw`u, sonra tek-satırlık `assert`in
#: kendi `;`sini) — satır penceresi hem daha basit hem açıklanabilir.
DIAGNOSTIC_LINE = re.compile(
    r"\bassert\s*\(|\bthrow\b|\bStateError\s*\(|\bArgumentError\s*\(|"
    r"\bUnsupportedError\s*\(|\bException\s*\(")

TURKISH_WORDS = re.compile(
    r"\b(ve|ile|için|değil|yok|var|bu|şu|olan|bir|daha|çok|gibi|ama)\b",
    re.IGNORECASE)

# ── TERS YÖN: yetenek GELDİĞİ gün, yokluk iddiaları YANLIŞA döner ─────────
#
# (O-059 · JabLab J-133 ölçütü: *bir cümle sevk edildiyse, onu yanlışa
# çevirecek en MAKUL değişikliği sor. Makulse, kapı gerekir.*)
#
# Kural B/C/E "izin/kod yolu gelince kendini emekliye ayırır" DİYORDU — ve
# ölçüldü: bu bir NİYETTİ, kapı değil. Üçü de yalnız SUSUYOR. Mikrofon
# kablolandığı gün **20 cümle** (15 `library.json` + 5 `lib/`) sessizce
# yanlışa döner ve hiçbir kapı bakmaz. Kimse yalan söylemeye karar vermez;
# biri `Info.plist`e bir satır ekler.
#
# O-045'te `RUNTIME_REFS` için iki yönü de kapatmıştım, sonra AYNI tek-yönlü
# deseni üç kez daha yazdım. Şimdi simetrik: yetenek YOKKEN iddia yasak,
# yetenek VARKEN yokluk-iddiası yasak.
ABSENCE_ASSERTIONS = re.compile(
    r"no (?:live )?microphone|there is no microphone input|"
    r"not wired in this build|no audio permission|hears nothing|"
    r"never listen(?:s)? to your", re.IGNORECASE)
RETENTION_ABSENCE_ASSERTIONS = re.compile(
    r"nothing is stored|none to delete|no history here", re.IGNORECASE)

# ── G: YOKLUK BEYANI EKRANDA DURMALI (varlık ikizi) ───────────────────────
#
# (O-060 · JabLab dersi: *bir dürüstlük kapısı, koruduğu cümlenin SİLİNMESİNİ
# de geçerli sayarsa dürüstlüğü değil SESSİZLİĞİ korur.*)
#
# ÖLÇÜLDÜ (2026-08-07): karşılamadaki "The microphone is not wired" kartının
# TAMAMINI sildim — dosyada sıfır anma kaldı — ve kapı "TEMİZ" dedi.
# Kullanıcı mikrofonun kablolu olmadığını hiç öğrenmezdi ve 21 kapının hepsi
# yeşil kalırdı. Kurallar B/C/E "yanlış söyleme"yi kolluyordu; "hiç söyleme"
# serbestti — oysa bu ürünün tüm iddiası SÖYLEMEK üzerine kurulu.
#
# Kural simetrinin üçüncü ayağı:
#   yetenek YOK  + iddia var        → kural B/C  (yanlış söyleme)
#   yetenek VAR  + yokluk-iddiası   → ters yön   (eski cümle)
#   yetenek YOK  + yokluk-iddiası YOK → KURAL G  (hiç söylememe)
REQUIRED_DISCLOSURES = [
    {
        "name": "mikrofon yokluğu",
        "pattern": re.compile(r"no microphone input in this build|"
                              r"microphone is not wired", re.IGNORECASE),
        "present_when": "audio_absent",
        "why": "Ürün ses ölçümü ANLATIYOR (akor · zamanlama · perde) ama canlı "
               "giriş yok. Bunu söylemeyen bir yüzey, kullanıcıyı motorun "
               "yeteneğiyle ürünün yeteneğini karıştırmaya bırakır.",
    },
    {
        "name": "saklama yokluğu",
        "pattern": re.compile(r"nothing is stored|none to delete", re.IGNORECASE),
        "present_when": "no_writer",
        "why": "Kamera açıklaması varken saklama beyanı yoksa kullanıcı "
               "cihazında bir kayıt olduğunu VARSAYAR (O-054'ün tersi).",
    },
]

# ── H: VÜCUT-TARAF YÖNERGESİ YASAK (ellik bilinmiyor) ─────────────────────
#
# (O-063 · JabLab J-142'nin müzik karşılığı. Orada canlı koçluk repliği
# "Right hand home." diyordu ve SOUTHPAW duruşta arka el SOL eldir — solak
# kullanıcıya YANLIŞ eli söylüyordu.)
#
# Ostinato'da bu DAHA keskin: **solak gitaristler gitarı TERS tutar** — sol
# el mızrap, sağ el perde. Bir gitar dersinde "your right hand" demek, solak
# bir öğrenciye yanlış eli söylemektir.
#
# ÖLÇÜLDÜ (2026-08-07): sevk edilen yüzeyde vücut-taraf sözcüğü **SIFIR**, ve
# canlı ölçüm ayna-güvenli (`trunkTiltDeg.abs()` — işaret atılıyor). Ayrıca
# uygulama kullanıcının ELLİĞİNİ hiç bilmiyor (`handed`/`dominant hand` diye
# bir girdi YOK) ve ruleset'ler bunu zaten beyan ediyor:
# `sideDependencyResolved.mirrorConfident` gitar **false** · piyano **false**.
# Yani bugün temiz — ama TEAMÜLLE temiz, kapıyla değil. Yeni bir ders
# "sağ elini şöyle koy" diyebilir ve hiçbir şey durdurmaz.
#
# ⚠️ KAPI TARAF SÖZCÜĞÜNE DEĞİL, TARAF+VÜCUT eşleşmesine bakar. Düz bir
# `left`/`right` yasağı yanlış olurdu: "Where you left off" · "the right
# move" · "right now" hepsi doğru İngilizce ve hepsi masum. *Aynı sözcük,
# zıt sınıflar.*
BODY_SIDE = re.compile(
    r"\b(left|right)[- ](hand|hands|wrist|wrists|arm|arms|elbow|elbows|"
    r"shoulder|shoulders|foot|feet|leg|legs|side|thumb|finger|fingers)\b",
    re.IGNORECASE)
#: Anatomik ÖLÇÜM adları (metrik kimliği) yönerge değildir — muaf.
BODY_SIDE_METRIC = re.compile(r"left_|right_", re.IGNORECASE)

# ── I: TÜRETİLEBİLİR bir sayı ELLE yazılamaz ──────────────────────────────
#
# (O-068 · JabLab J-151: *bir kusuru bulduğun YÜZEYDE düzeltmek, onu ürünün
# geri kalanında düzeltmek değildir. Kapsam KATMAN bazında değil YÜZEY
# bazında dolaşılmalı.*)
#
# ÖLÇÜLDÜ: karşılama ekranında canlı çalgı sayısını `library.json`dan
# TÜRETMİŞTİM (O-039) — ve `settings_screen` aynı sayıyı ELLE yazıyordu
# ("Three instruments are live: guitar, voice, piano"). Dördüncü çalgı canlıya
# geçtiği gün ayarlar sessizce "Three" demeye devam ederdi ve hiçbir test
# kırılmazdı. Düzeltme DOĞRUYDU, kapsamı EKSİKTİ.
#
# Kural: kullanıcı yüzeyinde bir SAYI SÖZCÜĞÜ, deponun bildiği bir
# koleksiyonun adıyla yan yana geçemez — o sayı türetilmeli.
# ⚠️ Dar tutuldu: yalnız `${...}` interpolasyonu OLMAYAN metinler; ve yalnız
# depodan türetilebilen üç koleksiyon (çalgı · ders · eğitmen).
COUNT_WORD = (r"\b(two|three|four|five|six|seven|eight|nine|ten|"
              r"eleven|twelve)\b")
#: ÇOĞUL isim ZORUNLU — "one lesson" bir sayım değil, bir örnektir.
#: ⚠️ `teachers` BU KURALDAN muaf — ama SESSİZCE değil: `validate_library.py`
#: **kural 9 + 9b** onu artefaktın `contributingTakes` değerine bağlıyor,
#: yani daha GÜÇLÜ bir çapası var (sayı yalnız türetilmiş olmakla kalmıyor,
#: ÖLÇÜMLE karşılaştırılıyor). İki kapının aynı şeyi iki farklı gerekçeyle
#: kollaması gürültü üretir; muafiyetin gerekçesi burada YAZILI.
DERIVABLE_NOUN = r"\b(instruments|lessons|courses)\b"
#: Araya BELİRTEÇ giremez: "not one THIS lesson teaches" bir sayım DEĞİL.
#: (İlk hâli 10 yanlış-pozitif üretti — geniş bir kapı, güvenilmez bir
#: kapıdır ve susturulmasına yol açar; O-058'in dersi.)
HANDWRITTEN_COUNT = re.compile(
    COUNT_WORD + r"\s+(?:(?!this|that|these|those|the|a|an|of)\w+\s+)?"
    + DERIVABLE_NOUN, re.IGNORECASE)

DART_ROOTS = ["lib"]
LIBRARY_JSON = "assets/content/library.json"
PUBSPEC = "pubspec.yaml"


#: KABUĞA GİTMEYEN ama KULLANICI METNİ ETİKETİ taşıyan katman: ruleset'lerin
#: `referenceConsumption.userExplanation` alanı. `validate_ruleset.py` kural 3
#: onu ZORUNLU kılıyor ve gerekçesi açıkça kullanıcıya dair ("açıklamasız
#: puan-yokluğu kullanıcıya 'sistem bozuk' okunur") — ama ÖLÇÜLDÜ (O-058):
#: kabukta okuyucusu **0**. Yani metin kullanıcı için yazılıyor, kullanıcıya
#: hiç ulaşmıyor.
#:
#: Bu kapı onu ÇÖZMÜYOR (render kararı koordinatörde) ama artık DENETLİYOR:
#: kullanıcı metni etiketi taşıyan bir alan, kullanıcı metni standardını
#: karşılamalı — bir gün render edilirse ölçülmemiş bir cümle canlıya çıkmaz.
#:
#: ⚠️ KAPSAM DAR TUTULDU, ve bu ölçümle öğrenildi. İlk denemede ruleset'in
#: TAMAMI tarandı ve üç Türkçe MÜHENDİSLİK kaydı (`mirrorAmbiguityNote` ·
#: `blockedByStatistic` ×2) ihlal sayıldı — oysa onlar kullanıcı metni değil,
#: bu ekip mühendislik notunu Türkçe yazıyor ve bu DOĞRU.
#: **Katman kapsamı İKİ YÖNDE de yanlış olabilir:** dar tutmak kör nokta
#: üretir, geniş tutmak yanlış-pozitif üretir ve ikincisi kapıyı
#: güvenilmez kılıp susturulmasına yol açar. Bu yüzden ruleset katmanında
#: TEK alan taranıyor: kullanıcı ETİKETİ taşıyan `userExplanation`.
#: ⚠️ `[^.]+` KULLANMA: dosya adı nokta İÇERİYOR (`guitar@0.2.0-draft.json`).
#: İlk hâli hiçbir şeyle eşleşmiyordu ve kapı kapsam satırında "3 ruleset
#: taranıyor" YAZIYORDU — sıfır alan tararken. **Yalan söyleyen bir kapsam
#: satırı, hiç olmayandan kötüdür:** okuyan kişi orayı denetlenmiş sanar.
#: MUT-V bunu yakaladı (mutasyon geçti, kapı sustu).
RULESET_USER_TEXT_PATH = re.compile(
    r"\.referenceConsumption\.userExplanation$")
RULESET_TEXT_GLOB = "config/rulesets/*.json"


def shipped_json_assets():
    """Kabuğa GİDEN her JSON varlığı — liste `pubspec.yaml`dan TÜRER.

    ⚠️ Bu fonksiyon bir kapsam hatasının düzeltmesidir (2026-08-07). Kapı ilk
    yazıldığında yalnız `library.json`ı tarıyordu; ölçüldü ki `pubspec`
    kabuğa **dört** varlık gönderiyor ve ikisi daha KULLANICI METNİ taşıyor —
    `config/observation-cue-templates.golden.json` (canlı ekranda okunan
    gözlem cümlesi, ürünün en çok "konuşan" metni) ve
    `assets/config/posture-contract.json` (`sourceClass` etiketleri, cümlenin
    içine giriyor). İkisi de o gün TEMİZDİ — ama **var olmayan kapsam
    kırmızıya dönemez** (aile dersi #4'ün kapı hâli): kimse bakmıyordu, ve
    bakılmadığı için temiz oldukları bilinmiyordu, sanılıyordu.

    Liste ELLE yazılmıyor çünkü elle yazılan bir kapsam, eklenen ilk yeni
    varlıkta sessizce bayatlar — tam da bu kapının kovaladığı arıza sınıfı.

    ── O-081 (2026-08-07) · EŞİK SÜPÜRMESİ, JabLab'ın `{3,}`/`W1` sınıfı ──
    Bu ayrıştırıcı `^\\s{2}assets:` ve `^\\s{4,}-` yazıyordu; yani girintiyi
    İCAT EDİLMİŞ sabitlerle bağlıyordu. Oysa **2 boşluk girintili bir dizi
    YAML'da tamamen geçerlidir**:
        flutter:
          assets:
          - assets/foo.json      ← ÖLÇÜLDÜ: eski desen bunu KAÇIRIYORDU
    Vakum kapısı (<3) yalnız TOPLAM kırılmayı yakalar. Üç varlık 4 boşlukta
    kalıp DÖRDÜNCÜSÜ 2 boşlukta eklenseydi: kapı sessizce 3 tarar, vakum
    geçer, ve yeni varlık **hiç denetlenmeden** sevk edilirdi.

    🎓 Ders: eşiği GENİŞLETMEK (4 → 3) çizgiyi oynatmaktan ibarettir. Doğrusu
    eşiği KALDIRMAK ve sınırı verinin KENDİSİNDEN türetmektir — burada
    `assets:` anahtarının kendi girintisi.
    """
    text = Path(PUBSPEC).read_text(encoding="utf-8")
    out, key_indent = [], None
    for raw in text.splitlines():
        m = re.match(r"^(\s*)assets:\s*$", raw)
        if m:  # her gerçek `assets:` bloğu sayılır (yorumlar aşağıda elenir)
            key_indent = len(m.group(1))
            continue
        if key_indent is None:
            continue
        if not raw.strip() or raw.strip().startswith("#"):
            continue
        indent = len(raw) - len(raw.lstrip())
        item = re.match(r"^\s*-\s+(\S+)\s*$", raw)
        # YAML: dizi öğesi anahtarla AYNI girintide ya da DAHA İÇERİDE olabilir.
        if item and indent >= key_indent:
            if item.group(1).endswith(".json"):
                out.append(item.group(1))
            continue
        if indent <= key_indent:
            key_indent = None  # blok bitti; sonraki `assets:` yorum olabilir
    return out


def strip_dart_comments(src: str) -> str:
    """Yorumları BOŞLUKLA değiştirir (satır numaraları korunur)."""
    out = []
    i, n = 0, len(src)
    in_s = None  # aktif string tırnağı
    while i < n:
        ch = src[i]
        if in_s:
            out.append(ch)
            if ch == "\\" and i + 1 < n:
                out.append(src[i + 1])
                i += 2
                continue
            if ch == in_s:
                in_s = None
            i += 1
            continue
        if ch in ("'", '"'):
            in_s = ch
            out.append(ch)
            i += 1
            continue
        if ch == "/" and i + 1 < n and src[i + 1] == "/":
            while i < n and src[i] != "\n":
                out.append(" ")
                i += 1
            continue
        if ch == "/" and i + 1 < n and src[i + 1] == "*":
            while i < n and not (src[i] == "*" and i + 1 < n and src[i + 1] == "/"):
                out.append("\n" if src[i] == "\n" else " ")
                i += 1
            out.append("  ")
            i += 2
            continue
        out.append(ch)
        i += 1
    return "".join(out)


STRING_LITERAL = re.compile(r"'((?:[^'\\\n]|\\.)*)'|\"((?:[^\"\\\n]|\\.)*)\"")

# Widget `Key`leri, asset yolları, paket adları… — boşluksuz ve yalnız
# tanımlayıcı karakterlerinden oluşan bir string PROZA DEĞİLDİR, kimse onu
# okumaz. Bu bir kaçamak deliği açmaz: kullanıcıya gösterilen her cümlede
# boşluk vardır. (Ölçüldü: `Key('onboarding-microphone-card')` yetenek
# kuralını tetikliyordu — kural haklıydı, hedefi yanlıştı.)
IDENTIFIER_LIKE = re.compile(r"^[A-Za-z0-9_\-./:]+$")


def dart_surface_strings():
    """(dosya, satır, metin) — yorumlar SÖKÜLDÜKTEN sonraki string literalleri.

    ⚠️ BİTİŞİK literaller BİRLEŞTİRİLİR. Dart'ta `'a ' 'b'` tek bir string'dir
    ve bu kod tabanı uzun metinleri hep böyle sarar. Literal-başına bakan bir
    tarayıcı, cümleyi tam da olumsuzlamanın düştüğü yerden ikiye böler —
    "The microphone is not " / "wired in this build" — ve dürüst bir cümleyi
    ihlal sayar. Kural CÜMLEYİ değerlendirir, o yüzden cümlenin kaynakta
    bölünmüş olması onu değiştirmemeli.
    """
    for root in DART_ROOTS:
        for path in sorted(Path(root).rglob("*.dart")):
            src = strip_dart_comments(path.read_text(encoding="utf-8"))
            pending, start = None, None
            last_end = None
            for m in STRING_LITERAL.finditer(src):
                text = m.group(1) if m.group(1) is not None else m.group(2)
                adjacent = (last_end is not None
                            and src[last_end:m.start()].strip() == "")
                if adjacent and pending is not None:
                    pending += text
                else:
                    if pending:
                        yield str(path), src.count("\n", 0, start) + 1, pending
                    pending, start = text, m.start()
                last_end = m.end()
            if pending:
                yield str(path), src.count("\n", 0, start) + 1, pending


def json_surface_strings(files=None):
    """(yol, metin) — `_`/`$` ile başlayan KAYIT alanları hariç.

    `files` verilmezse kabuğa giden TÜM JSON varlıkları taranır (bkz.
    [shipped_json_assets]). Kural C gibi yalnız `library.json`a ait alan
    yollarıyla çalışan çağıranlar dosyayı AÇIKÇA verir.
    """
    results = []

    def walk(node, path):
        if isinstance(node, dict):
            for k, v in node.items():
                if k.startswith("_") or k.startswith("$"):
                    continue
                walk(v, f"{path}.{k}")
        elif isinstance(node, list):
            for idx, v in enumerate(node):
                walk(v, f"{path}[{idx}]")
        elif isinstance(node, str):
            results.append((path, node))

    scan = files if files is not None else (
        shipped_json_assets() + sorted(str(x) for x in Path(".").glob(RULESET_TEXT_GLOB)))
    for f in scan:
        p = Path(f)
        if not p.exists():
            continue
        walk(json.loads(p.read_text(encoding="utf-8")), f)
    # Ruleset katmanında YALNIZ kullanıcı-etiketli alan kalır (yukarıdaki şerh).
    return [(pth, t) for pth, t in results
            if "config/rulesets/" not in pth or RULESET_USER_TEXT_PATH.search(pth)]


def ios_declares(key: str) -> bool:
    p = Path("ios/Runner/Info.plist")
    return p.exists() and key in p.read_text(encoding="utf-8")


def android_declares(permission: str) -> bool:
    p = Path("android/app/src/main/AndroidManifest.xml")
    return p.exists() and permission in p.read_text(encoding="utf-8")


# ── PLATFORM/MAĞAZA METİN YÜZEYLERİ (O-099 → O-100'de KAPSAM GENİŞLETİLDİ) ──
#
# **① Neden var (O-099):** bu kapı `ios_declares()` ile yalnız ANAHTARIN
# VARLIĞINA bakıyordu, METNE hiç bakmıyordu. `NSCameraUsageDescription`
# içinde 08-07'de ölçülüp YANLIŞ bulunan saklama iddiası günlerce sevk
# edildi. Kullanıcı o cümleyi onboarding'in *"izni kurulum kontrolünde
# isteyeceğiz"* sözünün hemen ardından sistem diyaloğunda görür.
#
# **② Neden kapsam GENİŞLEDİ (O-100, koordinatör kısıtı):** JabLab aynı
# yanlış cümlenin ÜÇÜNCÜ bir yüzeyini buldu — `docs/store/listing.json`
# içindeki `description` alanı — ve onun kapısı **yalnız
# `cameraPermissionRationale`ı** okuduğu için kaçırdı.
#   ⭐ *Bir kapının yakaladığı yüzey sayısı, kapının OKUDUĞU alan sayısıdır.*
#   ⭐ *Kapsam dışındaki kopya, DÜZELTME TURUNDA BİLE hayatta kalır.*
#
# **KISIT ②: ALAN-ADI BEYAZ LİSTESİ TUTULMAZ.** Kapsam DOSYA sayımından ve
# değerin BİÇİMİNDEN türer. `endswith("UsageDescription")` bir alan-adı
# filtresiydi ve tam JabLab'ın kapısının hatasıydı — kaldırıldı. Artık her
# yuvalı yapının TÜM string değerleri yürünüyor; ayıklama PROSA BİÇİMİNE
# göre (boşluk taşıyor mu · build değişkeni mi), ada göre DEĞİL. Böylece
# yarın eklenen `NSPhotoLibraryUsageDescription` ya da bir mağaza
# `description`ı kapıya KENDİLİĞİNDEN girer — kimse liste güncellemez.
#
# **Ostinato ölçümü (2026-08-12):** mağaza taslağı YOK (pozitif kontrol:
# aynı desen JabLab'ın `docs/store/listing.json`unu buluyor). Yokluk
# ADIYLA raporlanır — sessizce "temiz" sayılmaz.

#: Build değişkeni (`$(FLUTTER_BUILD_NAME)`) ya da tek-simge değer
#: (`APPL`, `????`, `Main`, `6.0`) prosa DEĞİLDİR. Ölçüm: plist'in 24 string
#: değerinden yalnız 1'i prosa (izin gerekçesi) — geri kalanı yapılandırma.
_BUILD_VAR = re.compile(r"\$\(|\$\{")


def _is_prose(value: str) -> bool:
    """Kullanıcıya cümle olarak görünebilecek bir metin mi? ADA BAKMAZ."""
    v = value.strip()
    return bool(v) and " " in v and not _BUILD_VAR.search(v)


def prose_values(obj, path=""):
    """Yuvalı bir yapıdaki (dict/list) TÜM string değerlerini yürür ve
    PROSA olanları `(yol, metin)` olarak döndürür — **alan adına hiç
    bakmadan** (kısıt ②). plist, mağaza listesi ve strings.xml aynı
    yürüyücüyü kullanır: bir yüzey türü eklemek yeni bir kural istemez.
    """
    if isinstance(obj, dict):
        for key, value in obj.items():
            yield from prose_values(value, f"{path}.{key}" if path else str(key))
    elif isinstance(obj, list):
        for i, value in enumerate(obj):
            yield from prose_values(value, f"{path}[{i}]")
    elif isinstance(obj, str) and _is_prose(obj):
        yield path, obj


#: Mağaza/metadata taslaklarının GELENEKSEL yerleri (aile geneli). Bu bir
#: ALAN listesi değil, DOSYA listesi — alanlar `prose_values` ile türer.
STORE_TEXT_GLOBS = [
    "docs/store/**/*.json", "docs/store/**/*.md", "docs/store/**/*.txt",
    "fastlane/**/metadata/**/*.txt", "store/**/*.json",
]


#: SATICI (vendored) yolları — BİZİM metnimiz değil. Ölçüldü: `ios/**/
#: Info.plist` üç dosya buluyor ve ikisi **MediaPipe xcframework**'ünün kendi
#: plist'i. Prosa vermiyorlar (yanlış-pozitif yok), ama kapsam satırında
#: "3 dosya" demek AYNI TÜRDEN olmayan şeyleri saymaktır (M-F-499'un sayım
#: kuralı) — kendi yüzeyimiz sanılır. Bu bir ALAN-ADI filtresi değil, SAHİPLİK
#: filtresi: `Pods/` CocoaPods'un satıcı dizinidir, `build/` üretilmiş çıktı.
_VENDOR_PATH = re.compile(r"(^|/)(Pods|build|\.symlinks|\.dart_tool)(/|$)")


def _ours(p: Path) -> bool:
    return not _VENDOR_PATH.search(str(p))


def claim_bearing_text_surfaces():
    """Saklama/gizlilik iddiası taşıyabilen HER metin yüzeyi + kapsam raporu.

    Döner: `(yüzeyler, rapor)` — rapor her yüzey sınıfı için kaç DOSYA ve kaç
    PROSA değer görüldüğünü taşır. Rapor basılır: taranmayan bir sınıf
    'temiz' sanılmasın (bu kapının kendi kapsam hatası tam böyle görünmezdi).
    """
    out, report = [], {}

    ios_files = [f for f in sorted(Path("ios").rglob("Info.plist")) if _ours(f)]
    seen = 0
    for ios in ios_files:
        try:
            data = plistlib.loads(ios.read_bytes())
        except Exception as exc:  # bozuk plist SESSİZCE atlanmaz
            out.append((f"{ios} (OKUNAMADI: {exc})", "plist okunamadi"))
            continue
        for key, value in prose_values(data):
            out.append((f"{ios}:{key}", value))
            seen += 1
    report["plist"] = (len(ios_files), seen)

    seen = 0
    android_files = [f for f in sorted(Path("android").rglob("strings.xml"))
                     if _ours(f)]
    for strings in android_files:
        try:
            import xml.etree.ElementTree as ET
            for node in ET.parse(strings).getroot().iter("string"):
                if node.text and node.get("name") and _is_prose(node.text):
                    out.append((f"{strings}:{node.get('name')}", node.text))
                    seen += 1
        except Exception as exc:
            out.append((f"{strings} (OKUNAMADI: {exc})", "xml okunamadi"))
    # Manifest'in kendi metin taşıyan öznitelikleri (`android:label`,
    # `android:description`) — öznitelik ADI değil, DEĞERİN biçimi ayıklar.
    manifests = [f for f in sorted(Path("android").rglob("AndroidManifest.xml"))
                 if _ours(f)]
    for man in manifests:
        for m in re.finditer(r'android:(\w+)="([^"]*)"',
                             man.read_text(encoding="utf-8")):
            if _is_prose(m.group(2)):
                out.append((f"{man}:android:{m.group(1)}", m.group(2)))
                seen += 1
    report["android"] = (len(android_files) + len(manifests), seen)

    seen, store_files = 0, []
    for pattern in STORE_TEXT_GLOBS:
        store_files += [f for f in sorted(Path(".").glob(pattern)) if _ours(f)]
    for f in store_files:
        try:
            if f.suffix == ".json":
                for key, value in prose_values(
                        json.loads(f.read_text(encoding="utf-8"))):
                    out.append((f"{f}:{key}", value))
                    seen += 1
            else:
                text = f.read_text(encoding="utf-8").strip()
                if _is_prose(text):
                    out.append((str(f), text))
                    seen += 1
        except Exception as exc:
            out.append((f"{f} (OKUNAMADI: {exc})", "magaza dosyasi okunamadi"))
    report["mağaza"] = (len(store_files), seen)

    return out, report


def sentences(text: str):
    """Kaba cümle bölme — iddia CÜMLE düzeyinde değerlendirilir; bir paragrafın
    başka bir yerindeki olumsuzlama, buradaki iddiayı aklamaz."""
    return [s for s in re.split(r"(?<=[.!?])\s+", text) if s.strip()]


# ── POZİTİF İKİZ: her desen BİLİNEN bir örneği yakalayabiliyor mu? ─────────
#
# (O-061 · JabLab'ın `find.byType` tuzağı: bir bulucu her zaman sıfır
# döndürüyordu, test yeşildi ve HİÇBİR ŞEY ölçmüyordu. İfşa eden şey pozitif
# ikizdi.)
#
# **Vakum kapısı "hiç bulamadım"ı yakalar; pozitif ikiz "aracım bozuk"u.**
# İkisi farklı arıza: vakum kapısı kapsam sayısına bakar, ama kapsam DOLU
# olup desenin kendisi bozuksa sayı yüksek kalır ve kapı yine sahte-yeşil
# olur. Bu gece üç kez oldu (BARE_HEX kapanış parantezi · ruleset yolundaki
# `[^.]+` · tanı bağlamı geri bakışı) — üçünde de kapsam doluydu.
#
# Her örnek KASTEN ihlal: desen onu YAKALAMAZSA desen ölmüştür.
SELFTEST_SAMPLES = [
    ("vaat dili A", PROMISE_PATTERNS[0][0], "we do not grade this yet"),
    ("vaat dili A/soon", PROMISE_PATTERNS[2][0], "chord grading is coming soon"),
    ("yetenek B", CAPABILITY_RULES[0]["mention"], "the microphone reads pitch"),
    ("yetenek B muafiyeti", CAPABILITY_RULES[0]["absence"][0],
     "there is no live microphone here"),
    ("ses kavramı C", AUDIO_CONCEPTS.pattern, "we hear every chord you play"),
    ("ses yokluğu C", AUDIO_ABSENCE.pattern, "there is no microphone input"),
    ("canlılık D", LIVE_CLAIM.pattern, "your elbow angle, live"),
    ("puanlanmaz D muafiyeti", NOT_GRADED.pattern, "measured but never graded"),
    ("saklama E", RETENTION_CLAIM.pattern, "the angles are kept on device"),
    # ⭐ O-099'un canlı kanıtı: AYNI İDDİANIN üç dilbilgisi. Üçüncüsü
    # (üçüncü-şahıs aktif) eski desenden KAÇIYORDU ve `Info.plist`te sevk
    # edilmişti. Örnekler burada durdukça özne-bağımlı bir desene geri
    # dönüş SESSİZ olamaz.
    ("saklama E/edilgen", RETENTION_CLAIM.pattern,
     "only the body angles we measure are kept"),
    ("saklama E/üçüncü şahıs aktif", RETENTION_CLAIM.pattern,
     "the app only keeps the body angles it measures"),
    ("saklama E/başka özne", RETENTION_CLAIM.pattern,
     "Ostinato retains your session data"),
    ("saklama yokluğu E", RETENTION_ABSENCE.pattern, "nothing is stored"),
    ("saklama yokluğu E/kayıt", RETENTION_ABSENCE.pattern,
     "nothing is recorded or uploaded"),
    ("dil F", TURKISH_WORDS.pattern, "bu ekran ve o kart için"),
    ("tanı muafiyeti F", DIAGNOSTIC_LINE.pattern, "throw StateError('x')"),
    ("ters yön", ABSENCE_ASSERTIONS.pattern, "there is no microphone input"),
    ("zorunlu beyan G", REQUIRED_DISCLOSURES[0]["pattern"].pattern,
     "there is no microphone input in this build"),
    ("tanımlayıcı", IDENTIFIER_LIKE.pattern, "onboarding-microphone-card"),
    ("vücut-taraf H", BODY_SIDE.pattern, "rest your right hand here"),
    ("elle sayı I", HANDWRITTEN_COUNT.pattern, "Three instruments are live"),
    # Lissom portu bunu buldu (2026-08-11): yerel gerçeklikte (`google_fonts`)
    # hiç SONEK yok, o yüzden desen soneksiz kaldı ve öz-test hiç fark etmedi.
    # Bu vaka artık kalıcı: sahte bir SONEKLİ paket, gerçek repoda hiç
    # olmasa bile.
    ("ağ J soneki", NETWORK_DEP_HINTS.pattern, "  posthog_flutter: ^1.0.0"),
    # Gravita bulgusu (2026-08-11): pubspec.yaml YALNIZ doğrudan bağımlılığı
    # taşır; transitif olanlar (http gibi) SADECE pubspec.lock'ta görünür,
    # orada da `dependency: transitive` satırının ÜSTÜNDE aynı girintili
    # `ad:` biçiminde. Desen aynı ama YALNIZ yaml taranırsa bu satıra hiç
    # ulaşılmaz — kalıcı hatırlatma sahte bir transitif paket adıyla.
    ("ağ J transitif (lock-biçimi)", NETWORK_DEP_HINTS.pattern,
     "  http:\n    dependency: transitive\n"),
]

# ── OLUMSUZ İKİZ: desen YAKALAMAMASI gerekeni yakalıyor mu? ───────────────
#
# (O-099 — bir deseni GENİŞLETMENİN kendi riski.) `RETENTION_CLAIM` özne
# bağımlılığından kurtarılırken fiil listesi genişledi; genişleyen bir desen
# gürültü üretirse hat kapıyı görmezden gelmeye başlar — pozitif ikizin
# ölçmediği arıza budur. Bu örnekler GERÇEK sevk edilen cümlelerden alındı
# (icat değil): desen bunlardan HERHANGİ BİRİNİ ihlal sayarsa genişletme
# fazla geniş yazılmış demektir. *Sınırı geniş yazmak, dar yazmak kadar
# pahalıdır* — bu hattın kendi dersi.
NEGATIVE_SAMPLES = [
    ("saklama: kılavuz cümlesi", RETENTION_CLAIM,
     "Keep your phone steady."),
    ("saklama: kayıt YOKLUĞU (sürüyor kipi)", RETENTION_CLAIM,
     "This takes a moment. Nothing is being recorded."),
    ("saklama: ses ölçülmedi", RETENTION_CLAIM,
     "Room noise is not part of this check, so nothing about your sound "
     "was measured or saved."),
    ("saklama: figür sayısı", RETENTION_CLAIM,
     "Your two shoulders and your two hips are what the camera reads; "
     "this figure draws nine points."),
    # ⭐ Bu üçünü kapının KENDİSİ buldu (yukarıdaki nesne-listesi şerhi):
    # ikisi de gerçek sevk edilen metin, ikisi de saklama iddiası DEĞİL.
    # Buradan çıkarılırlarsa nesne listesini genişletme SESSİZ olamaz.
    ("saklama: kadraj 'in frame'", RETENTION_CLAIM,
     "At the distance that keeps your hips in frame, a fingertip is a few "
     "pixels wide, so there is nothing stable to measure."),
    ("saklama: korpus 'we recorded'", RETENTION_CLAIM,
     "The widest lean among the 7 teachers we recorded was 14.0°; you're "
     "currently reading 19.2°."),
    ("saklama: eğitmen malzemesi kaydı", RETENTION_CLAIM,
     "The teaching footage our references come from was recorded waist-up."),
]


def selftest() -> int:
    dead = []
    for name, pattern, sample in NEGATIVE_SAMPLES:
        if pattern.search(sample):
            dead.append(f"{name}: desen YAKALAMAMASI gerekeni yakaladı "
                        f"(yanlış-pozitif) — «{sample[:70]}»")
    for name, pattern, sample in SELFTEST_SAMPLES:
        if not re.search(pattern, sample, re.IGNORECASE):
            dead.append(f"{name}: desen bilinen örneği YAKALAMIYOR — "
                        f"«{sample}» · desen {pattern!r}")
    # Yol türetimleri de sahte-sıfır verebilir (bu gece verdi).
    if not shipped_json_assets():
        dead.append("shipped_json_assets() BOŞ — pubspec türetimi ölmüş")
    if not list(Path(".").glob(RULESET_TEXT_GLOB)):
        dead.append(f"{RULESET_TEXT_GLOB} hiçbir dosyayla eşleşmiyor")
    if not any(RULESET_USER_TEXT_PATH.search(p)
               for p, _ in json_surface_strings()):
        dead.append("ruleset `userExplanation` yolu HİÇ eşleşmiyor — "
                    "kapsam satırı 'taranıyor' derken sıfır tarar (O-058)")
    # Gravita bulgusu (2026-08-11): Kural J bir ara yalnız pubspec.yaml
    # okuyordu, transitif bağımlılıklar (yalnız pubspec.lock'ta görünenler)
    # kör noktaydı. `http` GERÇEKTEN transitif (google_fonts altında) ve
    # yaml'da HİÇ geçmiyor — canlı kanıt olarak kullanılır: kapı pubspec.lock'u
    # gerçekten okumuyorsa bu kontrol hiç görmez ve regresyon sessiz kalır.
    lock_text = Path("pubspec.lock").read_text(encoding="utf-8")
    if not NETWORK_DEP_HINTS.search(lock_text):
        dead.append("pubspec.lock hiçbir ağ-bağımlılığı ipucuyla eşleşmiyor — "
                    "kural yalnız yaml'a mı döndü? (Gravita'nın transitif "
                    "bulgusu, http/google_fonts)")
    if "http" not in NETWORK_DEPS_RECORDED:
        dead.append("NETWORK_DEPS_RECORDED'da 'http' yok — transitif kayıt "
                    "geri alınmış olabilir")
    # ⑤ bölmenin İKİ arıza biçimi (Lissom'un iki öz-testinin aynısı):
    # ① ret-listesi önekine UYMAYAN, sınıflandırılmamış paket sessizce geçmesin
    # ② çelişkili sınıflandırma (ikisinde de) fark edilsin
    fake_lock = "  ably_flutter:\n    dependency: transitive\n"
    fake_pkgs = lock_packages(fake_lock)
    if "ably_flutter" not in fake_pkgs:
        dead.append("lock_packages() `ably_flutter`ı ayrıştıramadı — bölme "
                    "hiçbir şeyin üzerinde tanımlı değil (biçim kayması)")
    elif NETWORK_DEP_HINTS.search(fake_lock):
        dead.append("öz-test örneği geçersiz: `ably_flutter` ret-listesine "
                    "TAKILIYOR, dolayısıyla bölmenin ekstra değerini "
                    "kanıtlamıyor — listede OLMAYAN bir ad seçilmeli")
    elif ("ably_flutter" in NETWORK_DEPS_RECORDED
          or "ably_flutter" in NETWORK_DEPS_KNOWN_SAFE):
        dead.append("`ably_flutter` bir kayda girmiş — öz-test örneği artık "
                    "'sınıflandırılmamış' vakasını temsil etmiyor")
    # ── O-102: iddia↔ölçüm bağının kendi yolları ─────────────────────────
    # ① Özne çıkarımı çalışıyor mu — DOĞRUDAN ve DOLAYLI biçimde.
    if "angle" not in retention_subjects(
            "the app only keeps the body angles it measures"):
        dead.append("özne çıkarıcı DOĞRUDAN özneyi bulamıyor ('angles') — "
                    "iddia↔ölçüm bağı hiçbir cümleye bağlanamaz")
    if "measurement" not in retention_subjects(
            "Nothing is stored either: what we measure exists while the "
            "lesson runs and is gone when it ends."):
        dead.append("özne çıkarıcı DOLAYLI özneyi bulamıyor ('what we "
                    "measure') — sevk edilen gerçek bir cümle bu biçimde ve "
                    "ilk yazımda SESSİZCE atlanıyordu (O-102)")
    # ② BÖLME TAMLIĞI, ⑤'in aynısı ama ÖZNELER üzerinde: tespit edicinin
    #    çıkarabildiği HER özne `RETENTION_FACTS`ta bir kayda sahip OLMALI.
    #    Yeni bir nesne `_RETENTION_OBJECT`e eklenip kayda eklenmezse, o özne
    #    hakkındaki her iddia sessizce bağsız kalırdı.
    detectable = {a.strip().lower() for a in
                  _RETENTION_OBJECT.strip("(?:)").split("|")}
    for obj in sorted(detectable):
        base = obj if obj in RETENTION_FACTS else obj.rstrip("s?")
        if base not in RETENTION_FACTS:
            dead.append(f"BÖLME (özne): tespit edici «{obj}» çıkarabiliyor "
                        f"ama `RETENTION_FACTS`ta kaydı YOK — o özne "
                        f"hakkındaki her iddia sessizce bağsız kalır")
    # ③ Her kaydın ölçüm ADRESİ olmalı; boş gerekçe bir beyandır, kanıt değil.
    for subj, fact in RETENTION_FACTS.items():
        if not fact.get("evidence", "").strip():
            dead.append(f"`RETENTION_FACTS[{subj}]` ölçüm ADRESİ taşımıyor — "
                        f"beyan kendi kanıtı olamaz")
    overlap = set(NETWORK_DEPS_RECORDED) & set(NETWORK_DEPS_KNOWN_SAFE)
    if overlap:
        dead.append(f"BÖLME ÇELİŞKİSİ zaten var: {sorted(overlap)} iki kayıtta "
                    f"birden — ⊎ bozulmuş")
    # Bölme GERÇEKTEN dolu mu (vakum): 63 paketlik bir kayıt sessizce
    # boşalırsa kapı "üçüncü hâl yok" der ve yeşil kalır.
    if len(NETWORK_DEPS_KNOWN_SAFE) < 20:
        dead.append(f"NETWORK_DEPS_KNOWN_SAFE yalnız "
                    f"{len(NETWORK_DEPS_KNOWN_SAFE)} kayıt taşıyor (beklenen "
                    f"≥20) — bölme boşalmış, tamlık kontrolü anlamsız")
    # O-099: izin metni yolu da sahte-sıfır verebilir — ve tam bu yüzey
    # yıllarca ölçülmedi. Uygulama kamerayı kullanıyor, dolayısıyla
    # `NSCameraUsageDescription` OKUNABİLİR olmak zorunda. Bu kontrol
    # "kapsamı ekledim" iddiasını "kapsam gerçekten dolu" ölçümüne çevirir.
    perm, _report = claim_bearing_text_surfaces()
    if not perm:
        dead.append("claim_bearing_text_surfaces() BOŞ — platform metni yolu "
                    "ölmüş; kapı 'temiz' derken sıfır tarar (O-099)")
    elif not any(k.endswith("NSCameraUsageDescription") and t.strip()
                 for k, t in perm):
        dead.append("NSCameraUsageDescription METNİ okunamadı — anahtar "
                    "varlığı ölçülüyordu, METİN yine ölçülmüyor demektir")
    # ⭐ O-100: MAĞAZA yüzeyi Ostinato'da HENÜZ YOK, ama kapının onu
    # yakalayacağı BUGÜN kanıtlanır — yoksa "kapsama aldım" iddiası, dosya
    # ortaya çıktığı gün sınanacak bir VARSAYIM olarak kalır.
    # Örnek JabLab'ın GERÇEK kaçan yüzeyinin biçimi: yuvalı JSON + `description`
    # alanı + üçüncü-şahıs-aktif saklama iddiası. Alan adı beyaz listeye
    # ALINMADIĞI için yürüyücünün onu bulması gerekir.
    jablab_shaped = {"listing": {"en-US": {
        "title": "JabLab",
        "description": "JabLab keeps the body positions it measures, "
                       "not video.",
        "version": "$(FLUTTER_BUILD_NAME)",
    }}}
    found = dict(prose_values(jablab_shaped))
    hit = [p for p, t in found.items() if RETENTION_CLAIM.search(t)]
    if not hit:
        dead.append("MAĞAZA YÜZEYİ: yuvalı bir listing'in `description` alanı "
                    "yürüyücüden ya da desenden KAÇIYOR — JabLab'ın üçüncü "
                    "yüzeyi bu kapıdan da geçerdi (O-100)")
    if any("version" in p for p in found):
        dead.append("build değişkeni prosa sayıldı — `$(...)` ayıklaması "
                    "kırılmış; kapsam sayısı şişer ve vakum kapısı anlamını "
                    "yitirir")
    if dead:
        print(f"⛔ {len(dead)} ÖLÜ DESEN/YOL (pozitif ikiz başarısız):")
        for d in dead:
            print(f"   - {d}")
        return 1
    print(f"✅ pozitif ikiz TEMİZ — {len(SELFTEST_SAMPLES)} desen bilinen "
          f"örneğini yakaladı, {len(NEGATIVE_SAMPLES)} olumsuz örnek "
          f"yakalanMADI, 4 yol türetimi canlı (izin metni dahil)")
    return 0


def main() -> int:
    violations = []

    dart_raw = list(dart_surface_strings())
    surfaces = [(f"{f}:{ln}", t) for f, ln, t in dart_raw]
    surfaces += [(p, t) for p, t in json_surface_strings()]
    # Platform/mağaza metin yüzeyleri (O-099 → O-100): İŞLETİM SİSTEMİNİN ve
    # MAĞAZANIN gösterdiği metinler. Diğer yüzeylerle AYNI kurallardan geçer —
    # ayrı bir muafiyet katmanı yaratmak, bugün kapatılan deliğin kendisiydi.
    permission_surfaces, surface_report = claim_bearing_text_surfaces()
    surfaces += permission_surfaces
    surfaces = [(w, t) for w, t in surfaces if not IDENTIFIER_LIKE.match(t)]

    # ── Kural A ──
    for where, text in surfaces:
        for pattern, label in PROMISE_PATTERNS:
            if re.search(pattern, text, flags=re.IGNORECASE):
                violations.append(
                    f"[vaat dili] {where}: '{label}' geçiyor — "
                    f"«{text.strip()[:110]}»"
                )

    # ── Kural B ──
    for rule in CAPABILITY_RULES:
        declared = ios_declares(rule["ios_key"]) or android_declares(
            rule["android_permission"])
        if declared:
            # ⚠️ KURAL KENDİNİ KALDIRMAZ, YÖN DEĞİŞTİRİR (O-059). Yetenek artık
            # VAR: yokluğunu söyleyen her cümle BUGÜN YANLIŞ.
            for where, text in surfaces:
                for sentence in sentences(text):
                    if ABSENCE_ASSERTIONS.search(sentence):
                        violations.append(
                            f"[ters yön] {where}: '{rule['name']}' artık BEYAN "
                            f"EDİLMİŞ ({rule['ios_key']}/"
                            f"{rule['android_permission']}) ama bu cümle hâlâ "
                            f"yokluğunu söylüyor — «{sentence.strip()[:100]}»")
            continue
        for where, text in surfaces:
            for sentence in sentences(text):
                if not re.search(rule["mention"], sentence, flags=re.IGNORECASE):
                    continue
                if any(re.search(a, sentence, flags=re.IGNORECASE)
                       for a in rule["absence"]):
                    continue
                violations.append(
                    f"[yetenek iddiası] {where}: '{rule['name']}' anılıyor ama "
                    f"ne {rule['ios_key']} ne {rule['android_permission']} "
                    f"beyan edilmiş, cümle de yokluğu söylemiyor — "
                    f"«{sentence.strip()[:110]}»"
                )

    # ── Kural J ── (yükleme-yokluğu iddiası ↔ yükleyen kod yolu + kayıtlı ağ)
    claims_no_upload = [(w, t) for w, t in surfaces if UPLOAD_CLAIM.search(t)]
    if claims_no_upload:
        shipped_src = "\n".join(
            f.read_text(encoding="utf-8", errors="ignore")
            for f in Path("lib").rglob("*.dart"))
        for m in UPLOADER_TRACES.finditer(shipped_src):
            violations.append(
                f"[yükleme iddiası] sevk edilen kod '{m.group(0)}' taşıyor ama "
                f"{len(claims_no_upload)} yüzey 'hiçbir şey yüklenmiyor/"
                f"cihazdan çıkmıyor' diyor — iddia artık YANLIŞ olabilir")
        # ⚠️ Gravita bulgusu (koordinatör 2026-08-11, kaynakta 5 hatta
        # doğrulandı): yalnız pubspec.yaml TARANIYORDU — DOĞRUDAN
        # bağımlılıkları görür, TRANSİTİF olanları göremez. `http`,
        # google_fonts'un altında geliyor (`pubspec.lock`ta
        # `dependency: transitive`), yaml'da hiç geçmiyor. pubspec.lock
        # AYNI girinti biçimini taşıyor (`^\s+ad:`), o yüzden aynı desen
        # ikisine de uygulanabilir.
        pub = Path("pubspec.yaml").read_text(encoding="utf-8")
        lock = Path("pubspec.lock").read_text(encoding="utf-8")
        seen_deps = set()
        for src in (pub, lock):
            for m in NETWORK_DEP_HINTS.finditer(src):
                seen_deps.add(m.group(1))
        for dep in sorted(seen_deps):
            if dep not in NETWORK_DEPS_RECORDED:
                violations.append(
                    f"[yükleme iddiası] '{dep}' ağa çıkabilen bir bağımlılık "
                    f"(doğrudan ya da transitif) ve KAYITLI DEĞİL. "
                    f"{len(claims_no_upload)} yüzey 'cihazdan çıkmıyor' "
                    f"diyor: bu iddianın hâlâ geçerli olup olmadığı bir "
                    f"İNSAN KARARIDIR. Kararı verip `NETWORK_DEPS_RECORDED`a "
                    f"GEREKÇESİYLE yazın")
    else:
        # VAKUM: iddia hiç bulunamadıysa kural boşa koşmuş demektir.
        violations.append(
            "[yükleme iddiası] VAKUM: hiçbir yüzeyde 'cihazdan çıkmıyor' "
            "iddiası bulunamadı — ya cümleler kaldırıldı ya tarama kırıldı; "
            "iki hâlde de bu kuralın yeşili anlamsız")

    # ── ⑤ BÖLME TAMLIĞI (Lissom `1abd4a0`ten adapte) ─────────────────────
    # Ret-listesi ANDIĞINI yakalar; bölme ANMADIĞINI da yakalar. Bu kontrol
    # ret-listesinin YERİNE geçmez, ÜSTÜNE biner: HINTS bir paketi ağ-ailesi
    # diye işaretleyip kayıtsız bulursa yukarıdaki ihlal düşer; burada ise
    # SINIFLANDIRILMAMIŞ kalan her paket düşer.
    lock_pkgs = lock_packages(Path("pubspec.lock").read_text(encoding="utf-8"))
    unclassified = [p for p in lock_pkgs
                    if p not in NETWORK_DEPS_RECORDED
                    and p not in NETWORK_DEPS_KNOWN_SAFE]
    contradictory = [p for p in lock_pkgs
                     if p in NETWORK_DEPS_RECORDED
                     and p in NETWORK_DEPS_KNOWN_SAFE]
    if unclassified:
        violations.append(
            f"[bölme] {len(unclassified)} paket ÜÇÜNCÜ HÂLDE: ne "
            f"`NETWORK_DEPS_RECORDED`da ne `NETWORK_DEPS_KNOWN_SAFE`de — "
            f"{', '.join(unclassified[:8])}"
            f"{' …' if len(unclassified) > 8 else ''}. Ret-listesi bunları "
            f"ANMADIĞI için sessizce geçiriyordu; sınıflandırma bir İNSAN "
            f"KARARIDIR, gerekçesiyle yazın (M-F-455 ③ / Lissom 1abd4a0)")
    if contradictory:
        violations.append(
            f"[bölme] ÇELİŞKİLİ sınıflandırma — {', '.join(contradictory)} "
            f"hem 'ağa çıkabilir' hem 'çıkamaz' kaydında; bölme ⊎ olmalı")
    if not lock_pkgs:
        violations.append(
            "[bölme] VAKUM: `pubspec.lock`tan hiç paket adı ayrıştırılamadı — "
            "bölmenin yeşili anlamsız (biçim değişmiş olabilir)")

    # ── Kural C ──
    audio_declared = ios_declares("NSMicrophoneUsageDescription") or \
        android_declares("android.permission.RECORD_AUDIO")
    checked_affirmative = 0
    if not audio_declared:
        for path, text in json_surface_strings([LIBRARY_JSON]):
            # VARSAYILAN OLUMLU — muaf yollar dışındaki her proza denetlenir.
            if any(a.search(path) for a in ABSENCE_JSON_PATHS):
                continue
            if " " not in text:      # tek sözcük: ad/kimlik, cümle değil
                continue
            checked_affirmative += 1
            if AUDIO_ABSENCE.search(text):
                continue
            hit = AUDIO_CONCEPTS.search(text)
            if hit:
                violations.append(
                    f"[olumlu ses iddiası] {path}: '{hit.group(0)}' — bu alan "
                    f"OLUMLU bir ölçüm iddiasıdır ama canlı ses girişi beyan "
                    f"edilmemiş ve cümle yokluğu söylemiyor — "
                    f"«{text.strip()[:110]}»"
                )


    # ── Kural D ──
    lib_json = json.loads(Path(LIBRARY_JSON).read_text(encoding="utf-8"))
    checked_d = 0
    for disc in lib_json["disciplines"]:
        joints = coached_only_joints(disc["id"])
        if not joints:
            continue
        # Kovadaki eklem ADLARINDAN hangi kelimelerin yasak olduğunu TÜRET.
        banned = {w: rx for w, rx in JOINT_WORDS.items()
                  if any(w in j for j in joints)}
        # KAPSAM GENİŞLETİLDİ (O-055): yalnız `honesty.measured` değil, kural
        # C ile AYNI olumlu yüzeylerin tamamı. Dar kapsam, `demoOnlyReason`
        # içindeki canlı-dirsek iddiasını göremiyordu.
        claims = [t for pth, t in json_surface_strings([LIBRARY_JSON])
                  if f".disciplines[{lib_json['disciplines'].index(disc)}]" in pth
                  and not any(a.search(pth) for a in ABSENCE_JSON_PATHS)
                  and " " in t]
        for claim in claims:
            checked_d += 1
            # CANLILIK ekseni: canlı okuma iddiası + koçlanan eklem.
            if LIVE_CLAIM.search(claim) and not NOT_LIVE.search(claim):
                for word, rx in banned.items():
                    if re.search(rx, claim, re.IGNORECASE):
                        violations.append(
                            f"[canlılık ekseni] {disc['id']}: '{word}' CANLI "
                            f"okunuyormuş gibi anlatılıyor ama o eklemin canlı "
                            f"ölçümü YOK (`coached_only`) — «{claim.strip()[:100]}»")
            if NOT_GRADED.search(claim):
                continue
            for word, rx in banned.items():
                if re.search(rx, claim, re.IGNORECASE):
                    violations.append(
                        f"[skor ekseni] {disc['id']}.honesty.measured: "
                        f"'{word}' anılıyor ama o eklem ruleset'in "
                        f"`coached_only` kovasında (koçlanır, SKORLANMAZ) ve "
                        f"cümle bu sınırı söylemiyor — yeteneği olduğundan "
                        f"geniş yazmak, sınırı dar yazmaktan tehlikelidir — "
                        f"«{claim.strip()[:100]}»")


    # ── Kural E ──
    writers = []
    for f in sorted(Path("lib").rglob("*.dart")):
        if f.name in RETENTION_EXEMPT_FILES:
            continue
        if RETENTION_WRITERS.search(strip_dart_comments(
                f.read_text(encoding="utf-8"))):
            writers.append(str(f))
    writer_found = bool(writers)
    if writer_found:
        # TERS YÖN (O-059): artık saklayan bir kod yolu VAR; "hiçbir şey
        # saklanmıyor" diyen her cümle bugün YANLIŞ.
        for where, text in surfaces:
            for sentence in sentences(text):
                if RETENTION_ABSENCE_ASSERTIONS.search(sentence):
                    violations.append(
                        f"[ters yön] {where}: kabukta ölçüm SAKLAYAN bir kod "
                        f"yolu var ama bu cümle hâlâ hiçbir şeyin "
                        f"saklanmadığını söylüyor — «{sentence.strip()[:100]}»")

    # ── Kural E2: İDDİA ↔ ÖLÇÜM BAĞI, ÖZNE BAŞINA, İKİ YÖNDE ────────────
    # (O-102 — Gravita'nın `f169ba5` ölçümünden doğan koordinatör kısıtı.)
    #
    # **Kapının sorusu değişti:** *"iddia VAR MI"* değil, ***"iddia ÖLÇÜMLE
    # UYUŞUYOR MU — ve HER İKİ YÖNDE"***. Çünkü aynı cümleden İKİ AYRI sınıf
    # kusur doğuyor:
    #   ① **veriyi gizler** — beyandan FAZLA saklıyor (O-059'un yakaladığı yön)
    #   ② **olmayan veriyi İCAT EDER** — saklamadığı hâlde sakladığını beyan
    #      ediyor (Gravita + JabLab'ın vakası; kusur *gizli toplama* değil,
    #      *var olmayan bir saklamayı beyan etmek*)
    #
    # **Neden ÖZNE BAŞINA:** yukarıdaki `writer_found` GLOBAL bir bool ve
    # Gravita'nın vakasını ayırt EDEMEZ — orada diske yazan üç yer var (seans
    # kaydı · onboarding biti · poz modeli) ama **landmark hiçbirinde yok.**
    # Yani "bir şey yazılıyor" ile "BU ŞEY yazılıyor" farklı sorulardır.
    # Ostinato'da ölçüldü: diske yazan 2 yer var (`onboarding_store.dart`
    # karşılama biti · `pose_model.dart` model asset'i), ikisi de ÖLÇÜM
    # DEĞİL ve ikisi de adıyla muaf.
    #
    # **Neden tam otomatik DEĞİL (koordinatörün sınırı):** gerçeği ölçmek
    # HATTIN işi; bir regex "landmark diske gidiyor mu"yu karara bağlayamaz.
    # O yüzden kapının şart koştuğu şey bir BAĞ: iddia edilen her öznenin
    # `RETENTION_FACTS`ta **beyan edilmiş, gerekçeli** bir ölçüm karşılığı
    # OLMAK ZORUNDA. Bağ yoksa kapı öter — *"ölçmedim ama iddia ettim"*
    # sessizce geçemez.
    bound, unbound, unresolved = 0, 0, 0
    for where, text in surfaces:
        for sentence in sentences(text):
            positive = bool(RETENTION_CLAIM.search(sentence))
            absence = bool(RETENTION_ABSENCE.search(sentence)
                           or RETENTION_ABSENCE_ASSERTIONS.search(sentence))
            if not (positive or absence):
                continue
            subjects = retention_subjects(sentence)
            if not subjects:
                # SESSİZ ATLAMA YOK: cümle saklama hükmü veriyor ama özne
                # çıkarılamadı. Bu bir ihlal DEĞİL (her hüküm izlediğimiz
                # bir özne hakkında olmayabilir) ama SAYILIR ve raporlanır —
                # sayı büyüyorsa çıkarıcı gerçeğin gerisine düşmüş demektir.
                unresolved += 1
                continue
            for subj in subjects:
                fact = RETENTION_FACTS.get(subj)
                if fact is None:
                    unbound += 1
                    violations.append(
                        f"[iddia↔ölçüm bağı] {where}: cümle «{subj}» hakkında "
                        f"saklama hükmü veriyor ama `RETENTION_FACTS`ta bu "
                        f"öznenin BEYAN EDİLMİŞ bir ölçümü YOK — iddia "
                        f"ölçüme bağlanmadan sevk edilemez "
                        f"(«{sentence.strip()[:90]}»)")
                    continue
                bound += 1
                # ② olmayan veriyi icat etmek
                if positive and not absence and not fact["stored"]:
                    violations.append(
                        f"[iddia↔ölçüm ②] {where}: cümle «{subj}» "
                        f"SAKLANDIĞINI söylüyor, ölçüm SAKLANMADIĞINI "
                        f"({fact['evidence']}) — var olmayan bir saklamayı "
                        f"BEYAN ETMEK «{sentence.strip()[:90]}»")
                # ① veriyi gizlemek
                if absence and fact["stored"]:
                    violations.append(
                        f"[iddia↔ölçüm ①] {where}: cümle «{subj}» "
                        f"saklanmadığını söylüyor, ölçüm SAKLANDIĞINI "
                        f"({fact['evidence']}) — veriyi GİZLEYEN yön "
                        f"«{sentence.strip()[:90]}»")
    # `stored: False` beyanlarının YENİDEN ÖLÇÜMÜ: kayıt bir kez yazıldı diye
    # sonsuza kadar doğru kalmaz. Muaf olmayan bir yazıcı ortaya çıkarsa
    # BÜTÜN "saklanmıyor" beyanları şüphelidir — ve hangisi olduğu ADIYLA.
    if writer_found:
        stale = [s for s, f in RETENTION_FACTS.items() if not f["stored"]]
        violations.append(
            f"[iddia↔ölçüm yeniden-ölçüm] muaf olmayan yazıcı bulundu "
            f"({', '.join(writers)}) → 'saklanmıyor' beyanı taşıyan "
            f"{len(stale)} özne ({', '.join(stale)}) YENİDEN "
            f"SINIFLANDIRILMALI; beyanlar bugün şüpheli")

    # ── Kural F ──
    declared_lang = json.loads(
        Path(LIBRARY_JSON).read_text(encoding="utf-8")).get("language", "en")
    checked_f = 0
    if declared_lang.startswith("en"):
        # Tanı bağlamında duran literalleri ATLA (dosya-satır ile eşlenir).
        diagnostic = set()
        for f, ln, t in dart_raw:
            src = strip_dart_comments(Path(f).read_text(encoding="utf-8"))
            # ⚠️ `src.find(t)` KULLANILAMAZ: `t` BİTİŞİK literallerin
            # birleşmiş hâli ve kaynakta o hâliyle geçmiyor (aradaki tırnak
            # ve satır sonları yüzünden). Ölçüldü: `assert` tek satırlık
            # olduğu için yakalanıyordu, çok satırlı `throw StateError(...)`
            # kaçıyordu — muafiyet SESSİZCE yarım çalışıyordu.
            # Konum SATIR NUMARASINDAN kuruluyor (zaten elimizde).
            lines = src.splitlines()
            window = "\n".join(lines[max(0, ln - 3):ln])
            if DIAGNOSTIC_LINE.search(window):
                diagnostic.add(f"{f}:{ln}")
        for where, text in surfaces:
            if " " not in text or where in diagnostic:
                continue
            checked_f += 1
            if set(text) & TURKISH_CHARS or TURKISH_WORDS.search(text):
                violations.append(
                    f"[dil] {where}: kullanıcı yüzeyi TÜRKÇE görünüyor ama "
                    f"beyan edilen dil {declared_lang!r} — İngilizce konuşan "
                    f"kullanıcıya gider ve hiçbir test bunu kırmaz — "
                    f"«{text.strip()[:100]}»")


    # ── VAKUM KAPISI (O-059 · JabLab'ın öz-düzeltmesi: *rapor edilen sıfır,
    # ölçülen sıfır SANILIYOR*). Bir yol kırılır ya da cwd kayarsa bu kapı
    # "TEMİZ" der ve kimse sayıya bakmaz. Ölçüldü: 27 `tools/` betiğinin
    # yalnız 3'ü kendi doğru-pozitifini kontrol ediyordu.
    # ── Kural G ──
    for req in REQUIRED_DISCLOSURES:
        active = (not audio_declared) if req["present_when"] == "audio_absent" \
            else (not writer_found)
        if not active:
            continue          # yetenek geldi — ters yön devraldı
        hits = [w for w, t in surfaces if req["pattern"].search(t)]
        if not hits:
            violations.append(
                f"[yokluk beyanı EKSİK] '{req['name']}' hiçbir kullanıcı "
                f"yüzeyinde söylenmiyor. {req['why']} — bir kapı, koruduğu "
                f"cümlenin SİLİNMESİNİ de geçerli sayarsa dürüstlüğü değil "
                f"SESSİZLİĞİ korur")

    # ── Kural H ──
    checked_h = 0
    for where, text in surfaces:
        for sentence in sentences(text):
            if BODY_SIDE_METRIC.search(sentence):
                continue          # `left_elbow` gibi metrik adı — ölçüm, yönerge değil
            checked_h += 1
            m = BODY_SIDE.search(sentence)
            if m:
                violations.append(
                    f"[vücut-taraf] {where}: '{m.group(0)}' — uygulama "
                    f"kullanıcının ELLİĞİNİ bilmiyor (ellik girdisi YOK) ve "
                    f"solak gitarist gitarı TERS tutar; bu yönerge ona YANLIŞ "
                    f"eli söyler — «{sentence.strip()[:90]}»")

    # ── Kural I ──
    checked_i = 0
    for where, text in surfaces:
        if "$" in text:          # interpolasyon = zaten türetilmiş
            continue
        checked_i += 1
        m = HANDWRITTEN_COUNT.search(text)
        if m:
            violations.append(
                f"[elle yazılmış sayı] {where}: «{m.group(0)}» — bu sayı "
                f"depodan TÜRETİLEBİLİR. Elle yazılan bir sayı, koleksiyon "
                f"büyüdüğü gün sessizce yanlış olur ve hiçbir test kırılmaz")

    if len(surfaces) < 150:
        violations.append(
            f"VAKUM: yalnız {len(surfaces)} kullanıcı-yüzeyi metni tarandı "
            f"(beklenen ≥150) — bir yol kırılmış olabilir, 'temiz' hükmü "
            f"GEÇERSİZ")
    if len(shipped_json_assets()) < 3:
        violations.append(
            f"VAKUM: pubspec'ten yalnız {len(shipped_json_assets())} JSON "
            f"varlığı türedi (beklenen ≥3) — kapsam türetimi kırılmış")
    # O-099 vakumu: uygulama kamerayı KULLANIYOR, dolayısıyla en az bir izin
    # gerekçesi metni OLMAK ZORUNDA. Sıfır dönerse yol kırılmış demektir ve
    # "temiz" hükmü geçersiz — tam bu yüzeyin yıllarca ölçülmemiş olması bu
    # kapının var olma sebebi.
    # O-102 vakumu — turun en çok tekrarlanan dersinin bu kurala uygulanışı:
    # bağ kuralı SIFIR çift üzerinde koşarsa yeşili hiçbir şey söylemez.
    # Ostinato'nun yüzeyleri video/açı/geçmiş hakkında iddia taşıyor, yani
    # bu sayı ölçülebilir biçimde >0 olmak zorunda.
    if bound == 0:
        violations.append(
            "VAKUM: iddia↔ölçüm bağı HİÇ çift üzerinde koşmadı (0 bağ) — "
            "ya özne çıkarıcı ya yüzey taraması kırıldı; kuralın yeşili "
            "anlamsız (vakum-yeşil sınıfı)")
    if surface_report["plist"][1] < 1:
        violations.append(
            "VAKUM: plist'te hiç prosa metin bulunamadı (beklenen ≥1) — "
            "uygulama kamera kullanıyor; plist yolu kırılmış olabilir, "
            "'temiz' hükmü GEÇERSİZ")
    # O-100 vakumu: mağaza dosyası VARSA prosa vermek zorundadır. Dosya YOKSA
    # bu bir ihlal DEĞİL (Ostinato'da taslak yok, ölçüldü) — ama kapsam
    # satırında ADIYLA yazılır, sessizce "temiz" sayılmaz (M-F-444).
    store_files, store_prose = surface_report["mağaza"]
    if store_files and not store_prose:
        violations.append(
            f"VAKUM: {store_files} mağaza metni dosyası var ama HİÇ prosa "
            f"alan çıkmadı — alan yürüyücüsü kırılmış olabilir (JabLab'ın "
            f"`description` vakası tam bu sınıftı), 'temiz' hükmü GEÇERSİZ")

    if violations:
        print(f"⛔ {len(violations)} YÜZEY DÜRÜSTLÜĞÜ İHLALİ:")
        for v in violations:
            print(f"   - {v}")
        return 1

    ruleset_files = sorted(str(x) for x in Path(".").glob(RULESET_TEXT_GLOB))
    scanned = ", ".join(shipped_json_assets())
    print(f"✅ yüzey dürüstlüğü TEMİZ — {len(surfaces)} kullanıcı-yüzeyi metni "
          f"tarandı ({len(PROMISE_PATTERNS)} vaat deseni + "
          f"{len(CAPABILITY_RULES)} yetenek kuralı + "
          f"{checked_affirmative} olumlu iddia alanı + "
          f"{checked_d} skor-ekseni + {len(claims_no_upload)} yükleme iddiası + "
          f"{checked_f} dil + "
          f"{checked_h} vücut-taraf + {checked_i} sayı)")
    # KAPSAM her koşumda YAZILIR: taranmayan bir yer 'temiz' sanılamasın diye
    # (bu kapının kendi kapsam hatası tam olarak böyle görünmezdi).
    print(f"   kapsam: {DART_ROOTS} + kabuğa giden {len(shipped_json_assets())} "
          f"JSON varlığı ({scanned}) + {len(ruleset_files)} ruleset "
          f"(userExplanation katmanı, O-058)")
    # O-100: yüzey SINIFI başına dosya/prosa sayımı — bir sınıfın SIFIR
    # olması da ADIYLA yazılır. "Mağaza: 0 dosya" cümlesi, o yüzeyin
    # taranmadığını değil VAR OLMADIĞINI söyler; ikisi karıştırılamaz.
    print(f"   iddia↔ölçüm bağı (O-102, iki yönlü): {bound} iddia-özne "
          f"çifti ÖLÇÜME BAĞLANDI · {len(RETENTION_FACTS)} özne kaydı (her "
          f"biri ölçüm ADRESİYLE) · özne çıkarılamayan hüküm {unresolved} "
          f"(sessizce atlanmıyor, SAYILIYOR)")
    print(f"   ⑤ bağımlılık bölmesi (Lissom 1abd4a0'ten adapte): "
          f"{len(lock_pkgs)} paket = {len(NETWORK_DEPS_RECORDED)} kayıtlı "
          f"(ağa çıkabilir) ⊎ {len(NETWORK_DEPS_KNOWN_SAFE)} güvenli "
          f"(çıkamaz) · üçüncü hâl 0 · çelişki 0")
    print("   platform/mağaza kapsamı (O-099/O-100 — alan-adı beyaz listesi "
          "YOK, prosa biçiminden türer):")
    for cls, (files, prose) in surface_report.items():
        note = ""
        if cls == "mağaza" and files == 0:
            note = "  ← Ostinato'da taslak YOK (ölçüldü; aynı desen " \
                   "JabLab'ın docs/store/listing.json'unu buluyor)"
        print(f"     {cls:8} {files} dosya · {prose} prosa metin{note}")
    return 0


if __name__ == "__main__":
    sys.exit(selftest() if "--selftest" in sys.argv else main())
