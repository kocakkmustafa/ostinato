#!/usr/bin/env python3
"""Renk-token kapısı — metin rengi TOKEN'dan gelir, sabit hex'ten değil.

Neden var (2026-08-07, O-049 · JabLab J-116'nın dersi):

  O-048'de üç nötr metin tonunu WCAG AA'ya çektim ve "kontrast kapandı"
  dedim. Sonra ölçtüm: `lesson_locked_screen.dart:38` **eski değeri**
  (`Color(0xFF6E6880)`) SABİT-KODLAMIŞTI ve düzeltmeden sessizce KAÇTI —
  4.43'te kaldı. Token'ı düzeltmek, token'ı ATLAYAN kopyaları düzeltmez.

  JabLab'ın cümlesi: ***"örüntüyü değil örneği düzeltmişim."*** Bu kapı o
  cümlenin panzehri: `test/contrast_test.dart` TOKEN'ların oranını ölçer,
  bu kapı da HER metin renginin gerçekten bir token olduğunu ölçer. İkisi
  ayrı ayrı yetersiz, birlikte kapalı:
    · kontrast testi     → "token'lar okunuyor mu?"
    · bu kapı            → "token DIŞINDA metin rengi var mı?"

Kapsam KASITLI olarak dar: yalnız METİN rengi. `Border`, `BoxShadow`,
gradyan durağı, ayraç çizgisi gibi metin-dışı renkler bu kuralın dışında —
onların eşiği farklı (WCAG 1.4.11 = 3.0) ve çoğu dekoratif, yani bir token
zorunluluğu gereksiz gürültü üretirdi. Sınırın SINIFI: kapsam-dışı, eksik
değil.
"""
import re
import sys
from pathlib import Path

LIB = Path("lib")

#: Metin rengi TAŞIYAN çağrılar. `hankenText`/`monoText` bu kod tabanındaki
#: TEK iki tipografi yardımcısı (ölçüldü: üçüncü bir `GoogleFonts.*` çağrısı
#: yok, `ostinato_theme.dart`); `TextStyle(color:` ise ham kaçış yolu.
TEXT_COLOR_CALLS = [
    re.compile(r"(?:hankenText|monoText)\s*\([^)]*?\bcolor:\s*([^,)]+)", re.S),
    re.compile(r"\bTextStyle\s*\([^)]*?\bcolor:\s*([^,)]+)", re.S),
    re.compile(r"\bkicker\s*\([^)]*?\bcolor:\s*([^,)]+)", re.S),
]

#: ── O-082 · KUSUR CÜMLENİN KONUSUNDA DEĞİL, ÖNVARSAYIMINDAYDI ─────────────
#: Yukarıdaki üç desen çağrı YERİNİ denetler ve bu doğru. Ama ölçüldü ki
#: `hankenText`/`monoText` çağrılarının ÇOĞU `color:` HİÇ GEÇMİYOR — renk
#: imzadaki VARSAYILANDAN geliyor:
#:     TextStyle hankenText({ ... Color color = OstinatoColors.ink, ... })
#: Yani kapı, rengin çağrı yerine HER ZAMAN geldiğini VARSAYIYORDU. O
#: varsayılan ham bir hex'e çevrilse uygulamanın TÜM metni ham renge düşerdi
#: ve kapı yine "temiz" derdi — üstelik taranan çağrı sayısı DOLU kalırdı,
#: yani vakum kapısı da göremezdi (O-061'in aynı gölgesi).
#: Kapsam kasten dar: yalnız `TextStyle` DÖNDÜREN bir bildirimin imzası.
TEXTSTYLE_DECL = re.compile(r"\bTextStyle\s+\w+\s*\(")
COLOR_DEFAULT = re.compile(r"\bColor\??\s+\w+\s*=\s*([^,)\n]+)")

#: Kabul edilen kaynaklar: tema token'ları, çalgı kimliği, ve Flutter'ın
#: kendi iki ucu (saf beyaz/siyah — koyu sahnelerde metin bunlarla çizilir
#: ve kontrast testi o yığınları AYRICA ölçüyor).
#:
#: ⚠️ Bu liste BİLEREK dar. İlk hâli `_` ve `\bcolor\b` gibi geniş desenler
#: taşıyordu ve neredeyse her ifadeyi affediyordu — bir muafiyet listesi
#: fazla genişse kapının kendisi olmaz (O-045'in aynı dersi, burada kendi
#: kapımda tekrarlandı).
ALLOWED = re.compile(
    r"OstinatoColors\.|"           # tema token'ı
    r"hue\.|InstrumentHues\.|"     # çalgı kimliği (kontrast testi kapsıyor)
    r"Colors\.white|Colors\.black|"
    r"Color\(0xFFFFFFFF\)"
)

#: ⚠️ KAPANIŞ PARANTEZİ ARANMAZ. İlk hâli `Color\(0x…\)` istiyordu ve HİÇBİR
#: ŞEY yakalayamıyordu: yakalama grubu `[^,)]+` zaten ilk `)`de kesiliyor,
#: yani hex'in kapanışı ifadeye hiç girmiyordu. Kapı "temiz" diyordu ve
#: ölçülmüş İKİ ihlal ortada duruyordu — kapının kendi kör noktası.
#: ⚠️ O-081 — alt sınır İCAT EDİLMİŞTİ (`{6,8}`). `Color(0xFFF)` da, `Color(0x0)`
#: da geçerli Dart'tır ve ikisi de ham renktir; eski desen ikisini de KAÇIRIYORDU.
#: Bir kapının deseni "tipik" hedefi değil, MEŞRU hedeflerin TAMAMINI tanımalı —
#: JabLab'ın 2 karakterlik `W1`'i `{3,}` yüzünden kaçırması ile aynı sınıf.
BARE_HEX = re.compile(r"Color\(0x[0-9A-Fa-f]{1,8}")


def strip_comments(src: str) -> str:
    out, i, n, q = [], 0, len(src), None
    while i < n:
        ch = src[i]
        if q:
            out.append(ch)
            if ch == "\\" and i + 1 < n:
                out.append(src[i + 1]); i += 2; continue
            if ch == q: q = None
            i += 1; continue
        if ch in ("'", '"'):
            q = ch; out.append(ch); i += 1; continue
        if ch == "/" and i + 1 < n and src[i + 1] == "/":
            while i < n and src[i] != "\n":
                out.append(" "); i += 1
            continue
        if ch == "/" and i + 1 < n and src[i + 1] == "*":
            while i < n and not (src[i] == "*" and i + 1 < n and src[i + 1] == "/"):
                out.append("\n" if src[i] == "\n" else " "); i += 1
            out.append("  "); i += 2; continue
        out.append(ch); i += 1
    return "".join(out)


#: Ham `TextStyle(...)` — tipografi yardımcısını (`hankenText`/`monoText`)
#: ATLAYAN kaçış yolu. Ölçüldü (O-052): iki yerde vardı ve ikisi de gerçek
#: uygulamada `textTheme`den font alıyordu, kanıt karesinde ise varsayılana
#: düşüyordu — yani ekranda GÖRÜNEN ile KANITLANAN ayrışıyordu. Renk için
#: kapı kurulmuştu, tipografi için yoktu; aynı sınıf, eksik yarısı.
RAW_TEXTSTYLE = re.compile(r"style:\s*(?:const\s+)?TextStyle\s*\(")


#: POZİTİF İKİZ (O-061). Bu kapının `BARE_HEX`i bu gece SAHTE SIFIR verdi —
#: kapanış parantezi arıyordu, yakalama grubu zaten `)`de kesiliyordu. Kapı
#: "temiz" dedi, iki gerçek ihlal ortada duruyordu. Vakum kapısı bunu
#: göremezdi: taranan çağrı sayısı DOLUYDU, bozuk olan DESENDİ.
def _twin(name, ok, why):
    return (name, ok, why)


SELFTEST_SAMPLES = [
    _twin("BARE_HEX olumlu",
          lambda: BARE_HEX.search("const Color(0xFF9B95A8") is not None,
          "sabit hex yakalanmalı"),
    _twin("BARE_HEX olumsuz",
          lambda: BARE_HEX.search("OstinatoColors.textMono") is None,
          "token'ı hex sanmamalı"),
    _twin("ALLOWED olumlu",
          lambda: ALLOWED.search("OstinatoColors.ink") is not None,
          "token muafiyeti çalışmalı"),
    _twin("ALLOWED olumsuz",
          lambda: ALLOWED.search("const Color(0xFF123456") is None,
          "muafiyet sabit hex'i affetmemeli"),
    _twin("RAW_TEXTSTYLE olumlu",
          lambda: RAW_TEXTSTYLE.search("style: const TextStyle(") is not None,
          "ham TextStyle yakalanmalı"),
    _twin("RAW_TEXTSTYLE olumsuz",
          lambda: RAW_TEXTSTYLE.search("style: hankenText(size: 12)") is None,
          "yardımcıyı ham TextStyle sanmamalı"),
    _twin("metin çağrısı",
          lambda: TEXT_COLOR_CALLS[0].search("hankenText(size: 12, color: Foo)")
          is not None, "hankenText çağrısı yakalanmalı"),
]

def selftest() -> int:
    dead = [f"{n}: {why}" for n, fn, why in SELFTEST_SAMPLES if not fn()]
    if dead:
        print(f"⛔ {len(dead)} ÖLÜ DESEN (pozitif ikiz başarısız):")
        for d in dead:
            print(f"   - {d}")
        return 1
    print(f"✅ pozitif ikiz TEMİZ — {len(SELFTEST_SAMPLES)} desen sınandı "
          f"(olumlu VE olumsuz örnekle)")
    return 0


def main() -> int:
    violations = []
    checked = 0
    for path in sorted(LIB.rglob("*.dart")):
        # Tema dosyasının KENDİSİ token'ları TANIMLAR — hex orada yaşar.
        if path.name == "ostinato_theme.dart":
            continue
        src = strip_comments(path.read_text(encoding="utf-8"))
        for pattern in TEXT_COLOR_CALLS:
            for m in pattern.finditer(src):
                expr = m.group(1).strip()
                checked += 1
                if not BARE_HEX.search(expr):
                    continue
                if ALLOWED.search(expr):
                    continue
                line = src.count("\n", 0, m.start(1)) + 1
                violations.append(
                    f"{path}:{line}: metin rengi SABİT HEX — token'ı atlıyor: "
                    f"{expr[:60]!r}. Bir token düzeltmesi bu satırı ıskalar "
                    f"(O-049: tam olarak bu oldu). `OstinatoColors.*` kullan."
                )

    # ── O-082: `TextStyle` DÖNDÜREN imzaların renk VARSAYILANLARI.
    # ⚠️ Bu geçiş `ostinato_theme.dart`ı DIŞLAMAZ — ve kör noktanın sebebi tam
    # olarak o dışlamaydı: dosya PALETİ tanımladığı için muaftı, ama aynı
    # dosyadaki imza varsayılanları palet DEĞİL, paletin TÜKETİCİSİDİR.
    defaults_checked = 0
    for path in sorted(LIB.rglob("*.dart")):
        src = strip_comments(path.read_text(encoding="utf-8"))
        for d in TEXTSTYLE_DECL.finditer(src):
            depth, i, n = 0, d.end() - 1, len(src)
            while i < n:  # imzanın kapanış parantezini bul
                if src[i] == "(":
                    depth += 1
                elif src[i] == ")":
                    depth -= 1
                    if depth == 0:
                        break
                i += 1
            signature = src[d.end():i]
            for c in COLOR_DEFAULT.finditer(signature):
                expr = c.group(1).strip()
                defaults_checked += 1
                if not BARE_HEX.search(expr) or ALLOWED.search(expr):
                    continue
                line = src.count("\n", 0, d.start()) + 1
                violations.append(
                    f"{path}:{line}: `TextStyle` imzasında metin rengi "
                    f"VARSAYILANI ham hex: {expr[:50]!r}. Çağrıların çoğu "
                    f"`color:` GEÇMEZ — bu varsayılan uygulamanın metin "
                    f"rengidir ve çağrı-yeri denetimi onu göremez (O-082).")

    # ── Tipografi: ham TextStyle yasak (yardımcıdan geç).
    for path in sorted(LIB.rglob("*.dart")):
        src = strip_comments(path.read_text(encoding="utf-8"))
        for m in RAW_TEXTSTYLE.finditer(src):
            line = src.count("\n", 0, m.start()) + 1
            violations.append(
                f"{path}:{line}: ham `TextStyle(` — `hankenText()`/`monoText()` "
                f"yardımcısını atlıyor. Yardımcıdan geçmeyen metin, temanın "
                f"`textTheme`ine düşer: gerçek uygulamada Hanken, temasız bir "
                f"koşumda VARSAYILAN font — yani ekranda görünen ile "
                f"kanıtlanan ayrışır (O-052)."
            )


    # ── VAKUM KAPISI (O-059 · JabLab'ın öz-düzeltmesi: *rapor edilen sıfır,
    # ölçülen sıfır SANILIYOR*). Bir yol kırılır ya da cwd kayarsa bu kapı
    # "TEMİZ" der ve kimse sayıya bakmaz. Ölçüldü: 27 `tools/` betiğinin
    # yalnız 3'ü kendi doğru-pozitifini kontrol ediyordu.
    if checked < 30:
        violations.append(
            f"VAKUM: yalnız {checked} metin-rengi çağrısı tarandı "
            f"(beklenen ≥30) — regex ya da yol kırılmış, hüküm GEÇERSİZ")

    if violations:
        print(f"⛔ {len(violations)} TOKEN/TİPOGRAFİ İHLALİ:")
        for v in violations:
            print(f"   - {v}")
        return 1
    if defaults_checked == 0:
        print("⛔ VAKUM: hiçbir `TextStyle` imzasında renk varsayılanı "
              "bulunamadı — O-082 geçişi boşa koştu, yeşili anlamsız")
        return 1
    print(f"✅ renk+tipografi token kapısı TEMİZ — {checked} metin-rengi "
          f"çağrısı + {defaults_checked} imza VARSAYILANI token'dan geliyor, "
          f"ham `TextStyle` yok")
    return 0


if __name__ == "__main__":
    sys.exit(selftest() if "--selftest" in sys.argv else main())
