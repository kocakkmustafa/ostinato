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
BARE_HEX = re.compile(r"Color\(0x[0-9A-Fa-f]{6,8}")


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

    if violations:
        print(f"⛔ {len(violations)} TOKEN-ATLAYAN METİN RENGİ:")
        for v in violations:
            print(f"   - {v}")
        return 1
    print(f"✅ renk token kapısı TEMİZ — {checked} metin-rengi çağrısı tarandı, "
          f"hepsi token'dan ya da çalgı kimliğinden geliyor")
    return 0


if __name__ == "__main__":
    sys.exit(main())
