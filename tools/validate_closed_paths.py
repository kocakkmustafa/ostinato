#!/usr/bin/env python3
"""Engelleyen her kalem İKİ YÖNÜ de taşır: AÇAN yol ve KAPALI yollar (O-114).

**Aile kuralı (koordinatör, Choreia'nın bulgusundan):**

> ***ENGELLEYEN HER KAPI İKİ YÖNÜ DE TAŞIR: AÇAN YOL VE ÖLÇÜLÜP KAPATILMIŞ
> YOLLAR*** — ve kapalı yol **bilinmiyorsa alan boş bırakılmaz**,
> `closedPaths: none-known` yazılır.
>
> *Boş alan, **"yok"** ile **"bakılmadı"**yı ayırt ettirmez.*

**Neden bu kapı var — ölçüm (2026-08-12):** bu ağaçta **26** engelleyen kalem
vardı; **17'sinin açan yolu** yazılıydı, **KAPALI YOLU HİÇBİRİNİN** (0/26).
Ve en keskin kanıt aynı turun kendi işinden çıktı: ⑤'te *"kullanıcıya
'kadrajını göremiyorsun' cümlesi yaz"* yolu **o gün ölçülüp elendi** ve
**hiçbir yere yazılmadı.**

> ***Bugün konan kuralın ihlali, bugünün kendi işinden çıktı*** — bir alan
> **varsayılan olarak boş kalır**; bu yüzden kural bir SÜREÇ kancası taşır:
> *bir yolu ölçüp elediğinde AYNI TURDA yazarsın.* "Sonradan" hiç gelmiyor
> (0/26 kanıtı).

## KAPSAM — hangi türler ZORUNLU (koordinatör hükmü)

**ZORUNLU (13):** `PLACEHOLDER(...)` işaretçileri (5) + `blockedByTool`
kalemleri (8).
**MUAF:** `locked` (10) ve `demoOnly` (3) dersler.

⚖️ Gerekçe (aynen taşınıyor): *alanın amacı YENİDEN-İŞİ önlemek, ve
yeniden-iş yalnız **birinin bir şey DENEYECEĞİ** kalemlerde tehdit.
`locked`/`demoOnly` bir **ürün durumu**: onları açan kişi kapalı bir yola
ikinci kez girmiyor, **içerik sevk ediyor.** Hepsine zorunlu kılmak, alanı
13 gerçek yerde ciddiye alınmayacak kadar yaygınlaştırır.*
"""
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from validate_surface_honesty import strip_dart_comments  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
LIB = ROOT / "lib"
RULESETS = ROOT / "config" / "rulesets"

NONE_KNOWN = "none-known"
#: İşaretçi gövdesinde `closedPaths:` DEĞERİ.
#:
#: ⚠️ İlk yazımım sonlandırıcı olarak `(?=\n\s*//\s*\w+:)` kullanıyordu ve
#: **TİRELİ anahtarları tanımıyordu** (`user-surface:` → `\w+` tireyi almaz).
#: Sonuç: `none-known` değerleri ARDINDAKİ satırları da yutuyor, kapı da
#: onları "ölçülmüş eleme" sayıyordu → *"4 ÖLÇÜLMÜŞ"* diye rapor etti,
#: gerçek sayı **1**. Kapının kendi sayımı, ayrıştırıcısı kadar doğruydu.
#: İki hâl ayrı okunur: `[...]` liste ise KAPANANA kadar, değilse SATIR SONU.
MARKER_CLOSED = re.compile(
    r"closedPaths:\s*(\[.*?\]|[^\n]*)", re.S)
MARKER_RE = re.compile(r"//\s*PLACEHOLDER\(([a-z]+)\):")


def _marker_blocks(text):
    """Her `PLACEHOLDER(...)` işaretçisinin YORUM BLOĞU (bitişik `//` satırları)."""
    lines = text.splitlines()
    out = []
    i = 0
    while i < len(lines):
        if MARKER_RE.search(lines[i]):
            j = i
            body = []
            while j < len(lines) and lines[j].lstrip().startswith("//"):
                body.append(lines[j])
                j += 1
            out.append((i + 1, "\n".join(body)))
            i = j
        else:
            i += 1
    return out


def collect():
    """(tür, konum, closedPaths değeri veya None) üçlüleri."""
    items = []
    for f in sorted(LIB.rglob("*.dart")):
        for line, body in _marker_blocks(f.read_text(encoding="utf-8")):
            m = MARKER_CLOSED.search(body)
            items.append(("PLACEHOLDER", f"{f.relative_to(ROOT)}:{line}",
                          m.group(1).strip() if m else None))
    for f in sorted(RULESETS.glob("*.json")):
        d = json.loads(f.read_text(encoding="utf-8"))
        for e in d.get("errors", []):
            if "blockedByTool" not in e:
                continue
            items.append(("blockedByTool", f"{f.name}:{e['code']}",
                          e.get("closedPaths")))
    return items


def judge(items):
    """Üç hâl: EKSİK → kırmızı · BOŞ → kırmızı · dolu/`none-known` → yeşil."""
    bad = []
    for kind, where, value in items:
        if value is None:
            bad.append(f"[{kind}] {where} — `closedPaths` ALANI YOK. Kapalı "
                       f"yol bilinmiyorsa bile `none-known` yazılır: boş "
                       f"alan, 'yok' ile 'bakılmadı'yı ayırt ettirmez")
        elif isinstance(value, list) and not value:
            bad.append(f"[{kind}] {where} — `closedPaths` BOŞ LİSTE. Boş "
                       f"liste bir cevap değildir; `none-known` yaz")
        elif isinstance(value, str) and not value.strip().strip('"[]'):
            bad.append(f"[{kind}] {where} — `closedPaths` BOŞ")
    return bad


def selftest() -> int:
    """Choreia'nın ÜÇ sabotajı — üçü de ayrı arıza biçimi."""
    dead = []
    probe = [("X", "x:1", None)]
    if not judge(probe):
        dead.append("EKSİK alan yakalanmıyor — kapı sessiz kalır")
    if not judge([("X", "x:1", [])]):
        dead.append("BOŞ LİSTE yakalanmıyor — ⭐ Choreia'nın İKİNCİ sabotajı: "
                    "bu olmasaydı boş liste SESSİZCE geçerdi")
    if not judge([("X", "x:1", "")]):
        dead.append("BOŞ DİZGE yakalanmıyor")
    if judge([("X", "x:1", NONE_KNOWN)]):
        dead.append(f"`{NONE_KNOWN}` REDDEDİLİYOR — kural 'doldur' değil "
                    f"'doldur YA DA bilmediğini yaz'")
    items = collect()
    if len(items) < 10:
        dead.append(f"yalnız {len(items)} engelleyen kalem toplandı "
                    f"(beklenen ≥10) — toplayıcı kırık, 'temiz' GEÇERSİZ")
    kinds = {k for k, _, _ in items}
    if kinds != {"PLACEHOLDER", "blockedByTool"}:
        dead.append(f"kapsam türleri beklenenden farklı: {sorted(kinds)}")
    if dead:
        print(f"⛔ {len(dead)} ÖLÜ DESEN (öz-test başarısız):")
        for d in dead:
            print(f"   - {d}")
        return 1
    print(f"✅ kapalı-yol kapısı öz-testi GEÇTİ — üç hâl ayrı ayrı sınandı "
          f"(EKSİK · BOŞ LİSTE · BOŞ DİZGE kırmızı, `{NONE_KNOWN}` yeşil), "
          f"{len(items)} kalem toplanıyor")
    return 0


def main() -> int:
    if "--selftest" in sys.argv:
        return selftest()
    items = collect()
    bad = judge(items)
    if bad:
        print(f"⛔ {len(bad)} KAPALI-YOL İHLALİ:")
        for b in bad:
            print(f"   - {b}")
        return 1
    known = sum(1 for _, _, v in items if str(v).strip() != NONE_KNOWN)
    print(f"✅ kapalı yol TEMİZ — {len(items)} engelleyen kalem "
          f"(PLACEHOLDER + blockedByTool), hepsi iki yönü de taşıyor: "
          f"{known} ÖLÇÜLMÜŞ eleme · {len(items) - known} `{NONE_KNOWN}`")
    print(f"   ⚖️ KAPSAM: `locked`/`demoOnly` dersler MUAF — onlar bir ÜRÜN "
          f"DURUMU; yeniden-iş yalnız birinin bir şey DENEYECEĞİ kalemlerde "
          f"tehdit (koordinatör hükmü)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
