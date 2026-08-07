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
RETENTION_CLAIM = re.compile(
    r"\bwe keep\b|\bare kept\b|\bis kept\b|\bwe store\b|\bis stored\b|"
    r"\bsaved on (?:your|this) (?:phone|device)\b|\byour history\b",
    re.IGNORECASE)
# Yokluğu söyleyen cümle geçer.
RETENTION_ABSENCE = re.compile(
    r"nothing is stored|none to delete|no history|are gone when|"
    r"is gone when|not stored|nothing is kept", re.IGNORECASE)
#: Ölçüm SAKLAYAN bir kod yolu nasıl görünürdü. Karşılama işareti ve poz
#: modeli dosyası HARİÇ (ikisi de ölçüm değil): dosya adlarıyla muaf.
RETENTION_WRITERS = re.compile(
    r"writeAsString|writeAsBytes|SharedPreferences|Hive\.|sqflite|"
    r"\.insert\(|openDatabase")
RETENTION_EXEMPT_FILES = {"onboarding_store.dart", "pose_model.dart"}

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
    "google_fonts": "yazı tipi indirir (GET); kullanıcı verisi TAŞIMAZ — "
                    "'yüklenmiyor' iddiasını yalanlamaz",
}
#: Ağa çıkabilen bağımlılık ailelerinin izleri (pubspec adlarında aranır).
NETWORK_DEP_HINTS = re.compile(
    r"^\s+(http|dio|firebase\w*|sentry\w*|posthog|amplitude|mixpanel|segment|"
    r"appsflyer|adjust|google_fonts|supabase\w*|graphql\w*|web_socket\w*):",
    re.MULTILINE)


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
    """
    text = Path(PUBSPEC).read_text(encoding="utf-8")
    out, in_assets = [], False
    for raw in text.splitlines():
        if re.match(r"^\s{2}assets:\s*$", raw):
            in_assets = True
            continue
        if in_assets:
            m = re.match(r"^\s{4,}-\s+(\S+)\s*$", raw)
            if m:
                if m.group(1).endswith(".json"):
                    out.append(m.group(1))
                continue
            if raw.strip() and not raw.strip().startswith("#"):
                in_assets = False
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
    ("saklama yokluğu E", RETENTION_ABSENCE.pattern, "nothing is stored"),
    ("dil F", TURKISH_WORDS.pattern, "bu ekran ve o kart için"),
    ("tanı muafiyeti F", DIAGNOSTIC_LINE.pattern, "throw StateError('x')"),
    ("ters yön", ABSENCE_ASSERTIONS.pattern, "there is no microphone input"),
    ("zorunlu beyan G", REQUIRED_DISCLOSURES[0]["pattern"].pattern,
     "there is no microphone input in this build"),
    ("tanımlayıcı", IDENTIFIER_LIKE.pattern, "onboarding-microphone-card"),
    ("vücut-taraf H", BODY_SIDE.pattern, "rest your right hand here"),
    ("elle sayı I", HANDWRITTEN_COUNT.pattern, "Three instruments are live"),
]


def selftest() -> int:
    dead = []
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
    if dead:
        print(f"⛔ {len(dead)} ÖLÜ DESEN/YOL (pozitif ikiz başarısız):")
        for d in dead:
            print(f"   - {d}")
        return 1
    print(f"✅ pozitif ikiz TEMİZ — {len(SELFTEST_SAMPLES)} desen bilinen "
          f"örneğini yakaladı, 3 yol türetimi canlı")
    return 0


def main() -> int:
    violations = []

    dart_raw = list(dart_surface_strings())
    surfaces = [(f"{f}:{ln}", t) for f, ln, t in dart_raw]
    surfaces += [(p, t) for p, t in json_surface_strings()]
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
        pub = Path("pubspec.yaml").read_text(encoding="utf-8")
        for m in NETWORK_DEP_HINTS.finditer(pub):
            dep = m.group(1)
            if dep not in NETWORK_DEPS_RECORDED:
                violations.append(
                    f"[yükleme iddiası] '{dep}' ağa çıkabilen bir bağımlılık "
                    f"ve KAYITLI DEĞİL. {len(claims_no_upload)} yüzey "
                    f"'cihazdan çıkmıyor' diyor: bu iddianın hâlâ geçerli "
                    f"olup olmadığı bir İNSAN KARARIDIR. Kararı verip "
                    f"`NETWORK_DEPS_RECORDED`a GEREKÇESİYLE yazın")
    else:
        # VAKUM: iddia hiç bulunamadıysa kural boşa koşmuş demektir.
        violations.append(
            "[yükleme iddiası] VAKUM: hiçbir yüzeyde 'cihazdan çıkmıyor' "
            "iddiası bulunamadı — ya cümleler kaldırıldı ya tarama kırıldı; "
            "iki hâlde de bu kuralın yeşili anlamsız")

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
    writer_found = False
    for f in Path("lib").rglob("*.dart"):
        if f.name in RETENTION_EXEMPT_FILES:
            continue
        if RETENTION_WRITERS.search(strip_dart_comments(
                f.read_text(encoding="utf-8"))):
            writer_found = True
            break
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
    if not writer_found:
        for where, text in surfaces:
            for sentence in sentences(text):
                if not RETENTION_CLAIM.search(sentence):
                    continue
                if RETENTION_ABSENCE.search(sentence):
                    continue
                violations.append(
                    f"[saklama iddiası] {where}: cümle bir şeyin SAKLANDIĞINI "
                    f"söylüyor ama kabukta ölçüm saklayan bir kod yolu YOK — "
                    f"«{sentence.strip()[:110]}»")

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
    return 0


if __name__ == "__main__":
    sys.exit(selftest() if "--selftest" in sys.argv else main())
