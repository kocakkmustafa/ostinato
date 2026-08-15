#!/usr/bin/env python3
"""Release imzası SESSİZCE debug anahtarına düşemez (O-103, yayın engeli ⑤a).

**Neden var — ölçümden doğdu, tahminden değil (2026-08-12):** yayın engeli
denetiminde (JabLab'ın J-216 yöntemi) `assembleRelease` gerçekten koşuldu ve
üretilen APK'nın imzası okundu:

    Signer #1 certificate DN: C=US, O=Android, CN=Android Debug

Yani release yapısı **şablonun TODO'suyla** debug anahtarıyla imzalanıyordu.
Mağaza böyle bir paketi reddeder, ama kusur **hiçbir hata mesajı üretmiyordu**
— tam "sessiz düşme" sınıfı.

**Neden Gradle görevi YETMİYOR:** `verifyReleaseSigning` yalnız release
paketleme yolunda çalışır; bu deponun her-commit süiti Gradle KOŞMAZ
(`run_gates.sh` python + dart). Yapılandırma geri alınırsa Gradle tarafı
sessiz kalır ve regresyon commit'e girer. Bu kapı o boşluğu kapatır: METİN
düzeyinde değişmezi her commit'te zorlar.

**Ne şart koşMUYOR:** keystore'un varlığını. O **kurucu kalemidir** (sır) ve
bu kapı onu beklemez — hat-yereli iş kurucu kaleminin altına saklanmaz.
Kapı yalnız şunu ister: (a) release imzası KOŞULLU olsun, (b) düşüş
SESSİZ olmasın (adıyla ötecek bir görev bulunsun).
"""
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
# ⚠️ Yorum-körlüğü panzehiri (H-31/O-143) — yeniden yazılmadı, içe aktarıldı.
# `build.gradle.kts` Kotlin DSL'dir: `//`/`/* */` Dart'la AYNI sözdizimi.
from validate_surface_honesty import strip_dart_comments  # noqa: E402

GRADLE = Path("android/app/build.gradle.kts")

#: Şablonun bıraktığı hâl: release KOŞULSUZ debug imzasına bağlanmış.
TEMPLATE_FORM = re.compile(
    r"release\s*\{[^}]*?signingConfig\s*=\s*signingConfigs\.getByName\(\s*"
    r"[\"']debug[\"']\s*\)", re.DOTALL)
#: Koşullu biçim: `if (hasReleaseKeystore) … else …`
CONDITIONAL = re.compile(
    r"signingConfig\s*=\s*if\s*\(", re.DOTALL)
#: Sessizliği bozan görev.
NAMED_WARNING = re.compile(r"verifyReleaseSigning")
#: Görev release yoluna GERÇEKTEN bağlı mı (kayıt yetmez, tetik lazım).
WIRED = re.compile(r"assembleRelease|bundleRelease")


def check(src: str):
    """Metin üzerinde üç değişmez. Döner: ihlal listesi."""
    bad = []
    if TEMPLATE_FORM.search(src) and not CONDITIONAL.search(src):
        bad.append("release imzası KOŞULSUZ `signingConfigs.getByName(\"debug\")` "
                   "— şablonun TODO hâli; release paketi debug anahtarıyla "
                   "imzalanır ve mağaza reddeder (ÖLÇÜLDÜ 2026-08-12: "
                   "CN=Android Debug)")
    if not CONDITIONAL.search(src):
        bad.append("release imzası KOŞULLU değil — `key.properties` varsa "
                   "gerçek imza, yoksa geri-düşme deseni yok")
    if not NAMED_WARNING.search(src):
        bad.append("`verifyReleaseSigning` YOK — geri-düşme SESSİZ kalır; "
                   "düşüşün kendisi yasak değil, SESSİZLİĞİ yasak")
    elif not WIRED.search(src):
        bad.append("`verifyReleaseSigning` tanımlı ama release yoluna BAĞLI "
                   "DEĞİL (assembleRelease/bundleRelease) — kaydın varlığı "
                   "tetiğinin varlığı değildir")
    return bad


def selftest() -> int:
    """POZİTİF İKİZ: kapı, düzelttiği hâli GERÇEKTEN yakalıyor mu?

    Örnek uydurma değil: Flutter şablonunun birebir bıraktığı blok — yani bu
    deponun 2026-08-12 öncesindeki gerçek hâli. Kapı onu kaçırırsa ölmüştür.
    OLUMSUZ İKİZ: bugünkü (düzeltilmiş) kaynak SIFIR ihlal vermeli.
    """
    dead = []
    template = """
    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
    """
    if not check(template):
        dead.append("ŞABLON HÂLİ YAKALANMIYOR — kapı ölü (düzeltmenin kendisi "
                    "geri alınsa sessiz kalırdı)")
    # Sessizlik ayrı bir arıza: koşullu ama uyarısız bir biçim de ötmeli.
    silent = 'signingConfig = if (hasReleaseKeystore) { a } else { b }'
    if not any("verifyReleaseSigning" in v for v in check(silent)):
        dead.append("SESSİZ geri-düşme yakalanmıyor — koşullu ama uyarısız "
                    "bir yapılandırma geçerdi")
    # Kayıt var ama tetik yok: üçüncü arıza biçimi.
    unwired = (silent + "\nval verifyReleaseSigning = tasks.register(\"x\") {}")
    if not any("BAĞLI" in v for v in check(unwired)):
        dead.append("BAĞLANMAMIŞ görev yakalanmıyor — kaydın varlığı tetiğinin "
                    "varlığı sanılırdı")
    if not GRADLE.exists():
        dead.append(f"{GRADLE} YOK — kapı hiçbir şey ölçmüyor (vakum)")
    elif check(strip_dart_comments(GRADLE.read_text(encoding="utf-8"))):
        dead.append("BUGÜNKÜ kaynak ihlal veriyor — olumsuz ikiz başarısız")
    if dead:
        print(f"⛔ {len(dead)} ÖLÜ DESEN (öz-test başarısız):")
        for d in dead:
            print(f"   - {d}")
        return 1
    print("✅ imza kapısı öz-testi GEÇTİ — şablon hâli · sessiz düşme · "
          "bağlanmamış görev: üçü de yakalanıyor, bugünkü kaynak temiz")
    return 0


def main() -> int:
    if "--selftest" in sys.argv:
        return selftest()
    if not GRADLE.exists():
        print(f"⛔ {GRADLE} YOK — 'temiz' hükmü GEÇERSİZ (vakum)")
        return 1
    bad = check(strip_dart_comments(GRADLE.read_text(encoding="utf-8")))
    if bad:
        print(f"⛔ {len(bad)} RELEASE İMZASI İHLALİ:")
        for b in bad:
            print(f"   - {b}")
        return 1
    print("✅ release imzası TEMİZ — koşullu yapılandırma + release yoluna "
          "BAĞLI adıyla-uyaran görev. (Keystore'un kendisi KURUCU kalemi; "
          "bu kapı onu şart koşmaz, SESSİZLİĞİ yasaklar.)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
