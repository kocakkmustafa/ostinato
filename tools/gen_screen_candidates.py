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
#: ⚠️ Ve sebep ekran BAŞINA ölçülür: ilk yazımda üçü için de "kamera
#: arkasında" demiştim — ÖLÇÜM `ReviewScreenRoute`ta kamera izi OLMADIĞINI
#: gösterdi. O ekran kamerayı KULLANMIYOR; yalnız kamera gerektiren
#: `LiveScreenRoute`un ARKASINDA duruyor (`live_screen.dart:182` push eder).
#: Yanlış bir sebep, sebepsizlikten daha kötüdür: denetimi doğrulanmış
#: gösterir.
CAMERA_TRACE = re.compile(
    r"requestAndStartCamera|MotionCameraController|CameraPoseSource")


def camera_dependency(name, src_by_file):
    """Ekranın KAMERA BAĞIMLILIĞI — türetilmiş OLGU, erişilebilirlik İDDİASI
    değil.

    ⚠️ İlk yazımın adı `unreachable_reason`di ve bu YANLIŞTI: betik hangi
    ekrana varılabildiğini BİLMEZ (o yürüyüşün işi). Burada üretilen şey bir
    OLGU — *bu ekran kamerayı kullanır / kamera arkasındadır* — ve testte
    yalnız VARILAMAYANLAR için sebep olarak okunur. Bir olguyu iddia diye
    adlandırmak, kapsamı sessizce genişletir.
    """
    own = "".join(strip_dart_comments(t) for f, t in src_by_file.items()
                  if re.search(rf"class _?{name}(State)?\b", t))
    if CAMERA_TRACE.search(own):
        traces = sorted(set(CAMERA_TRACE.findall(own)))
        return f"kamerayı KENDİSİ kullanıyor ({', '.join(traces)}) — widget " \
               f"testinde platform kanalı yanıt vermez"
    # kamerası yok: onu PUSH eden ekran kamera arkasındaysa, sebep DOLAYLI
    pushers = sorted({Path(f).name for f, t in src_by_file.items()
                      if re.search(rf"=>\s*{name}\(", strip_dart_comments(t))
                      and CAMERA_TRACE.search(strip_dart_comments(t))})
    if pushers:
        return f"kamerası YOK — yalnız kamera gerektiren bir ekranın " \
               f"ARKASINDA ({', '.join(pushers)} push eder)"
    return ""


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
    reasons = {}
    for c in candidates:
        r = camera_dependency(c, src_by_file)
        if r:
            reasons[c] = r
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
        "cameraDependency": reasons,
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
