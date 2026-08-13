#!/usr/bin/env python3
"""Gezilebilirlik ADAY KÜMESİ — desenden TÜRETİLİR, elle yazılmaz (O-112).

**Sözleşme (koordinatör hükmü, beş hatta bağlayıcı):**
  (a) aday küme **DESENDEN türetilir** (koddan okur; elle liste HAFIZADAN)
  (b) üyelik **YÜRÜYEREK kanıtlanır** (`NavigatorObserver` + boyanmış
      kontrole basmak)
  (c) aday olup **VARILAMAYAN** ayrı raporlanır — KATI'ya girmez, KAYBOLMAZ
  (d) `aday = varılan ⊎ varılamayan` **ASSERT** edilir

Bu betik **(a)**yı üretir. (b)(c)(d) `test/reachable_screens_test.dart`ta.

## Neden elle liste yetmiyordu — kendi kör noktam, kendi belgemde

`docs/gates/GEZILEBILIRLIK-SAYMA-KURALI.md` §② şunu yazıyordu:
*"elle yürüyüşün göremediği şey, yazarın DENEMEYİ AKLINA GETİRMEDİĞİ
kontroldür"*. Koordinatör bunu sözleşmenin çekirdeği yaptı:

> · **elle liste** → *"yazarın aklına gelen"*; kusuru **SESSİZ ve SINIRSIZ**
>   (***ne unuttuğunu bilemezsin***)
> · **desen** → *"var olan"*; kusuru **sınırlı ve GÖRÜNÜR**
> · **yürüyüş** → *"varılabilen"*
>
> ***YÜRÜYÜŞ VARLIĞI KANITLAR, YOKLUĞU KANITLAMAZ — bir YOKLUK iddiası,
> BEKLENEN bir küme olmadan kurulamaz.***

## ⚠️ DESENİN KENDİ KAPSAMI DA ÖLÇÜLÜR (koordinatör uyarısı)

> *"Bir desenin kapsamı, onu yazanın ADLANDIRMA ALIŞKANLIĞI kadardır."*
> (Gravita'nın `Screen|Page|Tab` deseni `OnboardingFlow`u hiç almıyormuş.)

Bu yüzden aday küme **İKİ BAĞIMSIZ TÜRETİMDEN** kurulur ve **uzlaşmaları
ŞART koşulur**:
  **A) AD** — `*Screen` / `*ScreenRoute` (benim adlandırma alışkanlığım)
  **B) YAPI** — gövdesinde `Scaffold(` kuran sınıf (adlandırmadan bağımsız)

`StatefulWidget`lerde `Scaffold`u `State` sınıfı kurar; B tarafı bu yüzden
`_XState → X` normalize edilir. İki türetim ayrışırsa **kapı öter**: ayrışma
ya adlandırma alışkanlığının değiştiğini ya yeni bir ekran biçimini gösterir
— ikisi de **görülmesi gereken** olaylardır.
"""
import json
import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
# ⚠️ ÜÇÜNCÜ KEZ: yorum-kanıtı. İlk yazımda bu betik ham kaynağı tarıyordu ve
# `OnboardingScreen`e kamera bağımlılığı ATFETTİ — kanıt bir YORUMDAN geldi
# (`onboarding_screen.dart:27` kamerayı ANLATIYOR, kullanmıyor). Aynı sınıf
# bugün `validate_placeholder_surface`ta da çıkmıştı. Ayıklayıcı yine
# YENİDEN YAZILMADI, içe aktarıldı.
from validate_surface_honesty import strip_dart_comments  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
LIB = ROOT / "lib"
OUT = ROOT / "test" / "generated" / "screen_candidates.json"

NAME_RE = re.compile(r"^class ([A-Za-z0-9_]*Screen(?:Route)?)\b", re.M)

#: Ekran DEĞİL, adıyla dışlanan. Her biri GEREKÇELİ — muafiyet listesi değil,
#: KARAR listesi. Boş gerekçe kapıyı kırar.
NOT_A_DESTINATION = {
    "OstinatoApp": "MaterialApp sarmalayıcısı — kullanıcı buraya GİTMEZ, "
                   "uygulama burada BAŞLAR",
    "OstinatoHome": "karşılama↔kütüphane ANAHTARI (`home:` içinde durum "
                    "değiştirir, rota DEĞİL) — kullanıcı ona 'gidemez'",
}


def _class_bodies(text):
    parts = re.split(r"\nclass ", text)
    for p in parts[1:]:
        m = re.match(r"([A-Za-z0-9_]+)", p)
        if m:
            yield m.group(1), p.split("\nclass ")[0]


#: (c) VARILAMAMA SEBEBİ — TÜRETİLİR, elle yazılmaz.
#: Choreia kuralı: *sebepsiz dışlama, denetimi yeniden TANIMA çevirir.*
#:
#: 🔴 **2026-08-13 — YÜKLEM DEĞİŞTİ, ÖLÇÜMLE (O-121).**
#: Eski yüklem *"ekran kamerayı KENDİSİ kullanıyor"* idi ve ondan
#: *"öyleyse varılamaz"* sonucu çıkarılıyordu. Bir prob bunu ÇÜRÜTTÜ:
#: `SetupCheckScreenRoute` kamerayı kendisi kurar (`setup_check_screen.dart:38`
#: koşulsuz `MotionCameraController()`) **ama widget testinde DOKUNARAK
#: VARILIYOR** — `camera_session.dart:109`daki `on Object catch` eksik
#: platform kanalını `CameraStartFailed`e çevirir; ekran asılmaz, ilk
#: perdesini çizer ("SETUP CHECK · FRAME · Find your frame.") ve tanık
#: push'u görür.
#:
#: ⇒ Yürüyüşü durduran şey kamerayı KULLANMAK değil, kamera KAPISININ
#: ARKASINDA olmaktır: `LiveScreenRoute`a ancak kurulum kontrolü GEÇİNCE
#: gidilir (`setup_check_screen.dart:490`, `_Stage.passed`) ve o geçiş
#: GERÇEK KARE ister.
#:
#: > ***BİR EKRANIN KAMERAYA DOKUNMASI İLE KAMERANIN ARKASINDA KALMASI
#: > AYNI ŞEY DEĞİLDİR — VE ARADAKİ FARK, YÜRÜYÜŞÜN GİDEBİLDİĞİ YERDİR.***
#:
#: Yeni yüklem TEK CÜMLE: *bir ekranı push eden HER yer kare tüketiyorsa,
#: o ekran kamera kapısının arkasındadır.* `SetupCheckScreenRoute`u
#: `lesson_scored_screen.dart` push eder ve o dosya kare tüketmez → VARILIR.
FRAME_CONSUMER = re.compile(
    r"requestAndStartCamera|MotionCameraController|CameraPoseSource")

#: 🔴 **2026-08-14 — YÜKLEM İKİNCİ KEZ DÜZELTİLDİ (O-131, koordinatör H-1).**
#:
#: Kusur `FRAME_CONSUMER`ın kendisinde değil, onun **ZORUNLU** sanılmasındaydı.
#: `live_screen.dart:58` şunu yazar:
#:     `late final PoseSource _source = widget.source ?? CameraPoseSource();`
#: — yani kamera orada **YEDEK**: zerk edilmiş bir `PoseSource` varsa hiç
#: kurulmaz. Ham metin eşleşmesi bu dosyayı *"kare tüketir"* saydırıyordu ve
#: `ReviewScreenRoute`un gerekçesi şu cümleyi kuruyordu:
#:     *"onu push eden her yer (live_screen.dart) kamera karesi tüketir"*
#: **Bu cümle YANLIŞTI.**
#:
#: ⚠️ Ama SONUCU değil, SEBEBİ yanlıştı — `ReviewScreenRoute` gerçekten
#: varılamaz. Sebebi **tek sıçramalık değil GEÇİŞLİ**: onu push eden ekran
#: (`LiveScreenRoute`) **kendisi** kapının arkasındadır. Yüklem tek adım
#: bakıyordu, gerçek ise zincirin tamamıydı.
#:
#: > ***BİR KAPININ SAYISI DOĞRUYKEN GEREKÇESİ YANLIŞSA, O KAPI BUGÜN GEÇER
#: > VE YARIN YANLIŞ ŞEYİ KORUR.*** Sayı (2) değişmedi; değişen, iki sebebin
#: > de artık DOĞRU olması.
#:
#: 🪤 Ve bu, deponun kendi `strip_dart_comments` panzehirinin yetmediği bir
#: vaka: yorum değil, **KODUN KENDİSİ** yanıltıyordu — bir dizge orada
#: gerçekten var, yalnız ZORUNLU değil. *Bir deseni kör eden şey her zaman
#: görünmezlik değildir; bazen görünenin KOŞULLU olmasıdır.*
_OPTIONAL_FRAME = re.compile(
    r"\?\?\s*(?:CameraPoseSource|MotionCameraController)\s*\(")


def mandatory_frame_consumer(text):
    """Dosya kareyi ZORUNLU mu tüketiyor — `?? X()` yedeği SAYILMAZ."""
    return bool(FRAME_CONSUMER.search(
        _OPTIONAL_FRAME.sub("", strip_dart_comments(text))))


def _pushers(name, src_by_file):
    """Bu ekranı push eden dosyalar → {dosya: ZORUNLU kare tüketiyor mu}."""
    out = {}
    for f, t in src_by_file.items():
        if re.search(rf"=>\s*{name}\(", strip_dart_comments(t)):
            out[Path(f).name] = mandatory_frame_consumer(t)
    return out


def behind_camera_gate(name, src_by_file, gated_files=frozenset()):
    """Ekran KAMERA KAPISININ ARKASINDA mı — türetilmiş OLGU, iddia değil.

    ⚠️ Betik hangi ekrana varılabildiğini BİLMEZ (o yürüyüşün işi). Burada
    üretilen şey bir OLGU — *bu ekrana giden her kapı ya kare tüketir ya
    kendisi kapının arkasındadır* — ve testte yalnız VARILAMAYANLAR için
    sebep olarak okunur. Bir olguyu iddia diye adlandırmak, kapsamı sessizce
    genişletir.

    `gated_files`: kapı arkasında oldukları ZATEN türetilmiş ekranları
    TANIMLAYAN dosyalar. Geçişli yolu bu taşır; sabit nokta `gate_reasons`ta.

    Push eden yer YOKSA sebep de YOK: kök yüzeyler ve yalnız testten kurulan
    ekranlar buraya düşmez.
    """
    pushers = _pushers(name, src_by_file)
    if not pushers:
        return ""
    direct = sorted(f for f, m in pushers.items() if m)
    indirect = sorted(f for f, m in pushers.items()
                      if not m and f in gated_files)
    if len(direct) + len(indirect) != len(pushers):
        return ""
    if not indirect:
        return (f"kamera KAPISININ ARKASINDA (DOĞRUDAN) — onu push eden her "
                f"yer ({', '.join(direct)}) kamera karesini ZORUNLU tüketir; "
                f"widget testinde o kapı geçilemez (kare gelmeden sonraki "
                f"düğme doğmaz)")
    return (f"kamera KAPISININ ARKASINDA (GEÇİŞLİ) — onu push eden her yer "
            f"ya kareyi zorunlu tüketir ({', '.join(direct) or '—'}) ya da "
            f"KENDİSİ kapının arkasındaki bir ekranı tanımlar "
            f"({', '.join(indirect)}); zincirin tamamı geçilmeden bu ekran "
            f"doğmaz")


def gate_reasons(candidates, src_by_file):
    """Sabit nokta: geçişli kapı-arkasılığı yakınsayana kadar türet.

    ⚠️ Tur sayısı SINIRLI (`len(candidates)`): bir döngü olsa bile betik
    asılmaz, yalnız o turda eklenebilenler eklenir. *Bir türetimin sonlanma
    garantisi, doğruluğundan ayrı bir güvencedir.*
    """
    defined_in = {}
    for f, t in src_by_file.items():
        for n in NAME_RE.findall(t):
            defined_in[n] = Path(f).name
    reasons, gated_files = {}, set()
    for _ in range(len(candidates) + 1):
        grew = False
        for c in candidates:
            if c in reasons:
                continue
            r = behind_camera_gate(c, src_by_file, gated_files)
            if r:
                reasons[c] = r
                if c in defined_in:
                    gated_files.add(defined_in[c])
                grew = True
        if not grew:
            break
    return reasons


#: (b) KÖK VARIŞ — `home:` kökünde rota push'u OLMADAN doğan yüzeyler.
#:
#: ⚠️ Neden TÜRETİLİYOR (O-116, koordinatör hükmü): testte `expect(rootMembers,
#: 2)` yazılıydı ve gerekçesi *"kök varış YAPISAL olarak ikidir"* diyordu.
#: Ölçüm bunu ÇÜRÜTTÜ: iki oluşu `main.dart`ın BUGÜNKÜ dallanmasının sonucu —
#: üçüncü bir dal eklemek meşru bir değişikliktir ve o gün kapı, DOĞRU bir
#: değişikliği kırmızı basardı.
#:
#: > ***'YAPISAL' DEMEK, 'BUGÜN BÖYLE' DEMEKTEN FARKLIDIR — VE ARADAKİ FARK
#: > ANCAK ÖLÇÜLEREK BİLİNİR.***
#:
#: Yapısal olan şey SAYI değil KURAL: *kök varış, `OstinatoHome`un rota
#: kurmadan döndürebildiği yüzeydir.* Kural burada kodlanır, sayı ondan düşer.
HOME_STATE = "_OstinatoHomeState"
#: ⚠️ `const`/`new` ATLANIR — ilk yazımım `return\s+([A-Z]...)` idi ve
#: `return const SettingsScreen();` satırını HİÇ GÖRMÜYORDU. Sabotajla
#: ölçüldü (O-116): `main.dart`a üçüncü bir kök dal eklendi, kapı SESSİZ
#: kaldı — sabotaj kötü değildi, KAPI KÖRDÜ. Dart'ta kök yüzeyin `const`
#: olması hiç de olağandışı değil (parametresiz `StatelessWidget`).
_RETURNS = re.compile(r"return\s+(?:const\s+|new\s+)?([A-Z][A-Za-z0-9_]*)\s*\(")

#: Sabotajın KALICI İKİZİ — desen bir daha bu üç biçimden birini kaybederse
#: öz-test öter. Sentetik: gerçek kaynağın bugünkü hâline bağlı DEĞİL.
_RETURN_SAMPLES = [
    ("return LibraryScreen(repo: r);", "LibraryScreen"),
    ("return const SettingsScreen();", "SettingsScreen"),
    ("return new LegacyScreen();", "LegacyScreen"),
]

#: `behind_camera_gate` YÜKLEMİNİN SENTETİK İKİZİ — dördü de gerçek kaynağın
#: bugünkü hâlinden BAĞIMSIZ. ⚠️ Bunlar bir "geçer mi" kontrolü değil, yüklemin
#: **iki yönde de** yanlış çıkabildiğinin kanıtı: ②'nin `False` olması eski
#: yüklemin çürütüldüğü vakadır (SetupCheck), ③ ise *bir* kamerasız yolun
#: yetmesi gerektiğini sabitler.
#: Biçim: `(kaynaklar, kapı-arkası-dosyalar, beklenen)`. Üçüncü alan O-131'de
#: eklendi — GEÇİŞLİ yolu ancak o taşıyabiliyor.
_GATE_SAMPLES = [
    # ① tek push eden, kare tüketiyor → kapı ARKASINDA
    ({"live.dart": "MotionCameraController _c; builder: (_) => T("},
     frozenset(), True),
    # ② tek push eden, kare TÜKETMİYOR → varılır (SetupCheck'in ölçülmüş vakası)
    ({"lesson.dart": "builder: (_) => T("}, frozenset(), False),
    # ③ iki push eden, biri kamerasız → varılır (bir yol yeter)
    ({"live.dart": "CameraPoseSource(); builder: (_) => T(",
      "lesson.dart": "builder: (_) => T("}, frozenset(), False),
    # ④ hiç push eden yok → sebep YOK (kök yüzey / yalnız testten kurulan)
    ({"other.dart": "class T {}"}, frozenset(), False),
    # ⑤ 🔴 O-131'İN VAKASI — kamera YEDEK (`?? X()`), zorunlu DEĞİL → varılır.
    #    Bu ikiz olmasaydı düzeltme sessizce geri alınabilirdi: eski yüklem
    #    burada True verirdi ve hiçbir kapı ötmezdi.
    ({"live.dart": "_s = widget.source ?? CameraPoseSource(); "
                   "builder: (_) => T("}, frozenset(), False),
    # ⑥ 🔴 GEÇİŞLİ — push eden kare tüketmiyor AMA kendisi kapı arkasında.
    #    `Review`in gerçek sebebi budur; ⑤ ile birlikte okunmalı: ⑤ eski
    #    sebebi ÇÜRÜTÜR, ⑥ doğrusunu KURAR.
    ({"live.dart": "builder: (_) => T("}, frozenset({"live.dart"}), True),
    # ⑦ Geçişlilik SINIRLI: kapı-arkası olmayan bir dosya zinciri kırar.
    ({"live.dart": "builder: (_) => T(", "lesson.dart": "builder: (_) => T("},
     frozenset({"live.dart"}), False),
]


def root_surfaces(src_by_file):
    """`OstinatoHome`un rota KURMADAN döndürebildiği yüzeyler — kaynaktan."""
    out = set()
    for _f, t in src_by_file.items():
        for name, body in _class_bodies(strip_dart_comments(t)):
            if name == HOME_STATE:
                out |= set(_RETURNS.findall(body))
    return out - set(NOT_A_DESTINATION)


def derive():
    by_name, by_structure = set(), set()
    for f in sorted(LIB.rglob("*.dart")):
        t = f.read_text(encoding="utf-8")
        by_name |= set(NAME_RE.findall(t))
        for name, body in _class_bodies(t):
            if "Scaffold(" in body:
                # `_XState` → `X` (StatefulWidget'te Scaffold'u State kurar)
                base = re.sub(r"^_(.*)State$", r"\1", name)
                by_structure.add(base)
    by_structure -= set(NOT_A_DESTINATION)
    return by_name, by_structure


def selftest() -> int:
    """Desenler, adlandırma/biçim değişkenliğine karşı SENTETİK sınanır."""
    dead = []
    for src, want in _RETURN_SAMPLES:
        got = _RETURNS.findall(src)
        if got != [want]:
            dead.append(f"KÖK DESENİ `{src}` için {got} buldu, [{want}] "
                        f"bekleniyordu — bir dönüş biçimi görünmez oldu "
                        f"(ölçülmüş vaka: `const`)")
    if _RETURNS.findall("return widget.child;"):
        dead.append("KÖK DESENİ yapıcı-olmayan dönüşü sayıyor (yanlış-pozitif)")
    for i, (src, gated, want) in enumerate(_GATE_SAMPLES, 1):
        got = bool(behind_camera_gate("T", src, gated))
        if got != want:
            dead.append(
                f"KAPI YÜKLEMİ ikiz-{i} için {got} verdi, {want} bekleniyordu "
                f"— yüklem *'onu push eden HER yer ya kareyi ZORUNLU tüketir "
                f"ya KENDİSİ kapı arkasındadır'* sorusunu artık doğru sormuyor "
                f"(kaynak: {sorted(src)}, kapı-arkası: {sorted(gated)})")
    # 🔴 O-131 ÇAPASI — yedek/zorunlu ayrımı YAŞIYOR mu. İkiz ⑤ ile aynı
    # kusuru iki farklı BİRİMDE tutar: biri yüklemi, bu doğrudan ayırıcıyı.
    # ⚠️ "KORUMA ÇİFT" tuzağına düşmesin diye ikisi AYNI deseni sınamıyor:
    # ⑤ sonucu (varılır mı), bu ise ayırıcının KENDİSİNİ ölçer.
    if mandatory_frame_consumer("_s = a ?? CameraPoseSource();"):
        dead.append("YEDEK/ZORUNLU AYIRICISI ÖLDÜ — `?? CameraPoseSource()` "
                    "yine ZORUNLU sayılıyor; `Review`in sebebi sessizce "
                    "yanlışa döner (O-131)")
    if not mandatory_frame_consumer("MotionCameraController _c;"):
        dead.append("YEDEK/ZORUNLU AYIRICISI FAZLA GENİŞ — koşulsuz kamera "
                    "kurulumunu da 'yedek' sayıyor; kapı ARKASINDAKİ ekranlar "
                    "varılabilir görünür (yanlış-negatif)")
    roots = root_surfaces({str(f): f.read_text(encoding="utf-8")
                           for f in sorted(LIB.rglob("*.dart"))})
    if not roots:
        dead.append(f"VAKUM: `{HOME_STATE}` içinde kök yüzey bulunamadı — "
                    f"sınıf adı ya da dallanma biçimi değişmiş")
    if dead:
        print(f"⛔ {len(dead)} ÖLÜ DESEN (öz-test başarısız):")
        for d in dead:
            print(f"   - {d}")
        return 1
    print(f"✅ aday-kümesi öz-testi GEÇTİ — kök deseni üç dönüş biçimini de "
          f"görüyor (düz · const · new), yapıcı-olmayan dönüşü saymıyor; "
          f"bu ağaçta {len(roots)} kök yüzey")
    return 0


def main() -> int:
    if "--selftest" in sys.argv:
        return selftest()
    by_name, by_structure = derive()
    only_name = sorted(by_name - by_structure)
    only_struct = sorted(by_structure - by_name)
    problems = []
    if only_name:
        problems.append(
            f"AD deseni {only_name} buluyor ama YAPI (Scaffold) bulmuyor — "
            f"ya ekran değil ya Scaffold'u başka bir sınıf kuruyor")
    if only_struct:
        problems.append(
            f"YAPI {only_struct} buluyor ama AD deseni bulmuyor — "
            f"ADLANDIRMA ALIŞKANLIĞI DEĞİŞMİŞ olabilir (Gravita'nın "
            f"`OnboardingFlow` vakası); ya deseni ya `NOT_A_DESTINATION`ı "
            f"tazele")
    for k, why in NOT_A_DESTINATION.items():
        if not why.strip():
            problems.append(f"`{k}` gerekçesiz dışlanmış — dışlama bir "
                            f"KARARDIR, gerekçesi olmadan yazılamaz")
    if problems:
        print(f"⛔ {len(problems)} ADAY KÜMESİ İHLALİ:")
        for p in problems:
            print(f"   - {p}")
        return 1
    candidates = sorted(by_name)
    if len(candidates) < 5:
        print(f"⛔ VAKUM: yalnız {len(candidates)} aday türedi (beklenen ≥5) — "
              f"desen ölmüş, 'tam kapsam' iddiası GEÇERSİZ")
        return 1
    src_by_file = {str(f): f.read_text(encoding="utf-8")
                   for f in sorted(LIB.rglob("*.dart"))}
    roots = sorted(root_surfaces(src_by_file))
    if not roots:
        print(f"⛔ VAKUM: `{HOME_STATE}` içinde hiç kök yüzey bulunamadı — "
              f"ya sınıf yeniden adlandırıldı ya dallanma başka bir biçime "
              f"geçti; 'kök varış' beklentisi GEÇERSİZ")
        return 1
    if set(roots) - set(candidates):
        print(f"⛔ kök yüzey aday kümesinde YOK: "
              f"{sorted(set(roots) - set(candidates))} — iki türetim ayrıştı")
        return 1
    reasons = gate_reasons(candidates, src_by_file)
    payload = {
        "$why": "TÜRETİLDİ — elle yazılmaz. İki bağımsız türetim (AD + YAPI) "
                "uzlaştı. Kaynak: tools/gen_screen_candidates.py",
        "candidates": candidates,
        "rootSurfaces": roots,
        "$rootSurfaces": (
            "TÜRETİLDİ — `%s` içinde rota KURMADAN `return X(` edilen "
            "yüzeyler. Bu bir SAYI değil KURAL: üçüncü bir dal meşruysa sayı "
            "kendiliğinden 3 olur; ama bir varışı `root` BEYAN edip burada "
            "GÖRÜNMEMEK tanık gereksiniminden kaçmaktır ve kapı öter."
            % HOME_STATE),
        "notADestination": NOT_A_DESTINATION,
        "behindCameraGate": reasons,
        "$behindCameraGate": (
            "TÜRETİLDİ — *onu push eden HER yer ya kareyi ZORUNLU tüketir ya "
            "KENDİSİ kapı arkasındaki bir ekranı tanımlar mı?* Yüklem İKİ KEZ "
            "düzeltildi. ⑴ 2026-08-13: eski adı `cameraDependency`di ve "
            "yüklemi *'ekran kamerayı kendisi kullanıyor'*du; ölçümle çürüdü — "
            "`SetupCheckScreenRoute` kamerayı kendisi kurar AMA dokunarak "
            "varılır (platform kanalı yokken `camera_session.dart:109` "
            "zarifçe düşer). ⑵ 2026-08-14 (O-131, H-1): yüklem TEK SIÇRAMALIK "
            "ve ZORUNLULUĞA KÖRDÜ. `live_screen.dart:58` kamerayı yalnız YEDEK "
            "kurar (`widget.source ?? CameraPoseSource()`), ama ham eşleşme onu "
            "'kare tüketir' sayıyordu ⇒ `ReviewScreenRoute`un gerekçesi "
            "*'onu push eden her yer kare tüketir'* diyordu ve BU CÜMLE "
            "YANLIŞTI. Sonucu değil SEBEBİ yanlıştı: Review gerçekten "
            "varılamaz, çünkü onu push eden ekran KENDİSİ kapının arkasında — "
            "sebep tek adım değil GEÇİŞLİ. Sayı (2) değişmedi; değişen, iki "
            "sebebin de artık DOĞRU olması. ⭐ BİR KAPININ SAYISI DOĞRUYKEN "
            "GEREKÇESİ YANLIŞSA, O KAPI BUGÜN GEÇER VE YARIN YANLIŞ ŞEYİ "
            "KORUR."),
        "$handWrittenIsLowerBound":
            "(e) Yürüyüşteki ELLE yazılmış rota kimlikleri SİLİNMEZ: "
            "türetimin POZİTİF KONTROLÜdür (türetim, zaten bildiğimizi "
            "kapsamalı). ⚠️ O küme bir ALT SINIRDIR — ona ekleme yapmak bir "
            "envanter güncellemesi DEĞİL, KONTROLÜN TABANINI yükseltmektir.",
    }
    text = json.dumps(payload, ensure_ascii=False, indent=2) + "\n"
    if "--check" in sys.argv:
        if not OUT.exists() or OUT.read_text(encoding="utf-8") != text:
            print(f"⛔ {OUT} kaynakla EŞLEŞMİYOR — bayat (ekran eklendi/"
                  f"silindi, aday kümesi yeniden üretilmedi). "
                  f"`python3 tools/gen_screen_candidates.py` koş.")
            return 1
        print(f"✅ aday kümesi TAZE — {len(candidates)} ekran, iki türetim "
              f"uzlaşıyor (AD ⟷ YAPI), {len(NOT_A_DESTINATION)} gerekçeli "
              f"dışlama")
        return 0
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(text, encoding="utf-8")
    print(f"✅ aday kümesi üretildi — {len(candidates)} ekran: "
          f"{', '.join(candidates)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
