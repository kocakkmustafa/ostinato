#!/usr/bin/env python3
"""Öksüz-anahtar kapısı — okunmayan bir anahtar, çürütülmüş iddiaların
hayatta kaldığı yerdir.

Neden var (2026-08-07, O-057 · JabLab J-129 aktarımı):

  JabLab'ın `Lesson.fromJson`u tanımadığı anahtarı SESSİZCE düşürüyordu;
  `library.json`da 10 öksüz anahtar vardı ve **ikisi YANLIŞTI** — biri
  daha önce ölçülüp ÇÜRÜTÜLEN bir iddianın üçüncü bir yerde hayatta kalmış
  hâliydi.

  **Ve neden hiçbir kapı gördü değil:** gecenin bütün dürüstlük turları
  YÜZEYLERİ taradı. Öksüz anahtar hiçbir yüzeyde değildir. Vaat dili kapısı
  dosyayı tarıyor ama KELİMEYE bakıyor, doğruluğa değil —
  ***yanlış ama nazik bir cümle her kapıdan geçer.***

  Ostinato'da ölçüldü ve ÜÇ karanlık anahtar çıktı, biri gerçekten yanlış:
    · `schemaVersion: 1` — 5 araç okuyor, **hiçbiri DOĞRULAMIYOR**; oysa şema
      aynı gece maddeten değişti (`instrumentSpecificGap` ·
      `outOfScopeDerived` · kilitli derslerde `promotionPath`). Sürüm 1'de
      kaldı ve kimse fark etmedi.
    · `productName` — HİÇ okunmuyor ve uygulamanın gerçek başlığından FARKLI
      ("Ostinato — Music Practice" vs "Ostinato"): ürün adının ikinci,
      denetlenmeyen kaynağı.
    · `wave` — HİÇ okunmuyor; doğru olabilir ama doğru olduğunu kimse
      ölçmüyor.

Bu kapı O-040'ın bir katman ALTIDIR: O-040 "iddianın KABUKTA karşılığı var
mı" diye sordu, bu kapı "iddianın PARSER'da karşılığı var mı" diye soruyor.

Tanımlı anahtarlar ELLE listelenmez — parser KAYNAĞINDAN türetilir. Elle
liste, doğruyu iki yere yazmaktır ve ikisi ayrışır.
"""
import json
import re
import sys
from pathlib import Path

LIBRARY = "assets/content/library.json"
PARSER = "lib/app/content.dart"

#: Şemanın BEYAN EDİLEN sürümü. Bu kapı `library.json`ın `schemaVersion`ını
#: gerçekten TÜKETEN tek yerdir — yani anahtar artık öksüz değil. Şema
#: değişince (yeni alan · alan kaldırma · anlam değişimi) İKİSİ birlikte
#: yükselir; biri yükselmezse kapı kırmızı yanar.
#: v2 (2026-08-07): `honesty.instrumentSpecificGap` · `honesty.outOfScopeDerived`
#: · kilitli derslerde `promotionPath.unblockedBy` eklendi.
#: v3 (2026-08-13, O-117): `starterLessonId` eklendi (+ `_why_starter`,
#: `_why_starter_kindNote` kayıt alanları).
#: ⚠️ İSİMLİ BOŞLUK (bu turda ölçüldü): bu kapı iki sayının EŞİTLİĞİNİ
#: denetler, yeni bir alanın onları YÜKSELTMEYE ZORLADIĞINI değil. Alan
#: eklenip sürüm bırakılırsa kapı SESSİZ kalır — yükümlülük yazılı kuralda,
#: kapıda değil. Kapatmanın yolu belli (bilinen-alan kümesini dondurup
#: karşılaştırmak) ama BU TURDA YAPILMADI, adıyla açık bırakıldı.
EXPECTED_SCHEMA_VERSION = 3

#: Anahtarı KABUK dışında tüketen yerler de sayılır (kapılar, üreteçler).
READER_ROOTS = ["tools", "test", "lib", "packages"]


def parser_keys():
    """`content.dart`ın GERÇEKTEN okuduğu anahtarlar — kaynaktan türetilir."""
    src = Path(PARSER).read_text(encoding="utf-8")
    return set(re.findall(r"""\w+\??\['([^']+)'\]""", src))


def external_readers():
    text = []
    for root in READER_ROOTS:
        for f in Path(root).rglob("*"):
            if f.is_file() and f.suffix in (".py", ".dart"):
                text.append(f.read_text(encoding="utf-8", errors="ignore"))
    return "\n".join(text)


def json_keys(node, out):
    if isinstance(node, dict):
        for k, v in node.items():
            out.add(k)
            json_keys(v, out)
    elif isinstance(node, list):
        for v in node:
            json_keys(v, out)
    return out


def main() -> int:
    problems = []
    lib = json.loads(Path(LIBRARY).read_text(encoding="utf-8"))
    known = parser_keys()
    corpus = external_readers()
    all_keys = json_keys(lib, set())

    # ── VAKUM KAPISI 1: parser'dan anahtar türetilemezse bu kapı HER ŞEYİ
    # öksüz sanar ya da (daha kötüsü) hiçbir şeyi. Sessizce doğru görünmesin.
    if len(known) < 10:
        problems.append(
            f"VAKUM: parser kaynağından yalnız {len(known)} anahtar türedi "
            f"({PARSER}) — regex bozulmuş olabilir, bu kapının hükmü GEÇERSİZ")
    # ── VAKUM KAPISI 2: kütüphane okunamadıysa "öksüz yok" demek anlamsız.
    if len(all_keys) < 20:
        problems.append(
            f"VAKUM: {LIBRARY} yalnız {len(all_keys)} anahtar taşıyor — "
            f"dosya beklenenden küçük, 'öksüz yok' hükmü GEÇERSİZ")

    # ── Şema sürümü GERÇEKTEN tüketiliyor (anahtar artık öksüz değil).
    declared = lib.get("schemaVersion")
    if declared != EXPECTED_SCHEMA_VERSION:
        problems.append(
            f"schemaVersion={declared!r} ama bu kapı {EXPECTED_SCHEMA_VERSION} "
            f"bekliyor — şema değiştiyse İKİSİ birlikte yükselmeli; "
            f"yükselmeyen sürüm numarası, kimsenin doğrulamadığı bir iddiadır")

    # ── ÖKSÜZ ANAHTARLAR: ne parser ne başka bir tüketici okuyor.
    orphans = []
    for k in sorted(all_keys):
        if k.startswith("_") or k.startswith("$"):
            continue          # KAYIT alanı — bilerek okunmaz, adı öyle diyor
        if k in known:
            continue
        if re.search(rf"""['"]{re.escape(k)}['"]""", corpus):
            continue          # bir kapı/üreteç okuyor
        orphans.append(k)
    for k in orphans:
        problems.append(
            f"öksüz anahtar {k!r}: ne `content.dart` ne bir kapı/üreteç "
            f"okuyor. Okunmayan bir anahtar, çürütülmüş iddiaların hayatta "
            f"kaldığı yerdir — ya bir tüketici kazandır, ya `_` ön ekiyle "
            f"KAYIT alanı yap, ya sil")

    if problems:
        print(f"⛔ {len(problems)} ÖKSÜZ-ANAHTAR / ŞEMA İHLALİ:")
        for p in problems:
            print(f"   - {p}")
        return 1
    print(f"✅ öksüz-anahtar kapısı TEMİZ — {len(all_keys)} anahtar tarandı, "
          f"{len(known)} tanesi parser kaynağından türedi, şema v{declared}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
