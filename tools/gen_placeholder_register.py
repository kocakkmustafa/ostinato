#!/usr/bin/env python3
"""Placeholder kaydı — kodda bekleyen yer tutucuların ÜRETİLEN envanteri.

Kurucu talimatı (giydirme EKİ, 2026-08-05): placeholder'lar ELLE liste
tutularak izlenmez (bu ailenin en pahalı hata sınıfı — bayat liste, unutulup
ürüne sızan taklit). Bunun yerine kodun TAM YERİNDE standart bir işaret
bırakılır:

    // PLACEHOLDER(<kategori>): <ne eksik> — unblocked by: <neyi bekliyor>

kategoriler: asset (görsel/foto) · copy (metin) · data (içerik/ölçüm) ·
flow (kapalı adım). Bu betik `lib/`i tarar, işaretlerden
`docs/design/PLACEHOLDER-REGISTER.md`yi ÜRETİR — ayrıca `library.json`daki
`status: locked` / `status: demoOnly` derslerini AYNI kayda katar (yeni metin
İCAT ETMEZ, var olan `lockedReason`/`promotionPath.unblockedBy`yi AYNEN
taşır — "aynı cümleyi kullan" talimatı).

KAPI (Choreia emsali, aile standardı 2026-08-05): `unblocked by` yoksa ya da
kategori tanınmıyorsa exit 1. "kodda bekleyen placeholder" MEŞRUDUR ve
izlenir; "kullanıcıya gerçekmiş gibi gösterilen sahte veri" burada
YAKALANAMAZ — o bir kod-inceleme/tasarım-denetimi meselesidir, bu betiğin
işi yalnız İSİMLENDİRİLMİŞ olanı KAYIT ALTINA almaktır.

Kullanım:
    python3 tools/gen_placeholder_register.py            # üretir, yazar
    python3 tools/gen_placeholder_register.py --check    # üretir, DOSYAYLA
                                                           # KARŞILAŞTIRIR,
                                                           # yazmaz (CI/kapı)
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LIB_DIR = ROOT / "lib"
LIBRARY_JSON = ROOT / "assets" / "content" / "library.json"
OUT_PATH = ROOT / "docs" / "design" / "PLACEHOLDER-REGISTER.md"

CATEGORIES = {"asset", "copy", "data", "flow"}
CATEGORY_LABELS = {
    "asset": "asset — görsel/foto",
    "copy": "copy — metin",
    "data": "data — içerik/ölçüm",
    "flow": "flow — kapalı adım",
}

MARKER_RE = re.compile(r"^\s*//\s*PLACEHOLDER\(([a-zA-Z]+)\):\s*(.*)$")
CONTINUATION_RE = re.compile(r"^\s*//\s*(.*)$")
UNBLOCKED_RE = re.compile(r"unblocked by:\s*(.*)$", re.IGNORECASE | re.DOTALL)


class Finding:
    def __init__(self, source, category, text, ok, problem=None):
        self.source = source          # "lib/app/foo.dart:42" ya da "library.json: voice.foundations.sustained_note"
        self.category = category
        self.text = text              # "unblocked by" DAHİL tam açıklama
        self.ok = ok
        self.problem = problem        # ok=False ise neden


def scan_dart_markers():
    findings = []
    for path in sorted(LIB_DIR.rglob("*.dart")):
        lines = path.read_text(encoding="utf-8").splitlines()
        rel = path.relative_to(ROOT)
        i = 0
        while i < len(lines):
            m = MARKER_RE.match(lines[i])
            if not m:
                i += 1
                continue
            category, first = m.group(1), m.group(2).strip()
            start_line = i + 1
            parts = [first]
            j = i + 1
            while j < len(lines):
                if MARKER_RE.match(lines[j]):
                    break
                cm = CONTINUATION_RE.match(lines[j])
                if not cm:
                    break
                parts.append(cm.group(1).strip())
                j += 1
            full = " ".join(p for p in parts if p).strip()
            source = f"{rel}:{start_line}"
            if category not in CATEGORIES:
                findings.append(Finding(source, category, full, False,
                    f"bilinmeyen kategori '{category}' (beklenen: {sorted(CATEGORIES)})"))
            elif not UNBLOCKED_RE.search(full):
                findings.append(Finding(source, category, full, False,
                    "'unblocked by:' eksik"))
            else:
                findings.append(Finding(source, category, full, True))
            i = j if j > i else i + 1
    return findings


def scan_library_json():
    """`status: locked`/`demoOnly` dersleri AYNI kayda katar — metin İCAT
    ETMEZ, `lockedReason`/`promotionPath.unblockedBy`yi AYNEN taşır."""
    findings = []
    if not LIBRARY_JSON.exists():
        return findings
    data = json.loads(LIBRARY_JSON.read_text(encoding="utf-8"))
    for disc in data.get("disciplines", []):
        for course in disc.get("courses", []):
            for lesson in course.get("lessons", []):
                status = lesson.get("status")
                lid = lesson.get("id", "?")
                source = f"library.json: {lid}"
                if status == "locked":
                    reason = (lesson.get("lockedReason") or "").strip()
                    # validate_library.py kural 5 zaten lockedReason'ı
                    # zorunlu kılıyor — burada TEKRAR doğrulamıyoruz, yalnız
                    # taşıyoruz. Boşsa (beklenmez) yine de KAYDET, gizleme.
                    text = (f"{reason} unblocked by: gerekçenin kendisi "
                            f"(yukarıdaki cümle eksik ölçümün adını taşır)")
                    findings.append(Finding(source, "data", text, True))
                elif status == "demoOnly":
                    reason = (lesson.get("demoOnlyReason") or "").strip()
                    promo = lesson.get("promotionPath") or {}
                    unblocked = (promo.get("unblockedBy") or "").strip()
                    text = f"{reason} unblocked by: {unblocked}" if unblocked else reason
                    ok = bool(unblocked)
                    findings.append(Finding(source, "data", text, ok,
                        None if ok else "promotionPath.unblockedBy eksik"))
    return findings


def render(findings):
    lines = [
        "# Placeholder kaydı (ÜRETİLİR — elle düzenleme)",
        "",
        f"`python3 tools/gen_placeholder_register.py` ile üretilir. Kaynak: "
        f"`lib/**/*.dart`taki `PLACEHOLDER(kategori): ... — unblocked by: ...` "
        f"işaretleri + `assets/content/library.json`daki `locked`/`demoOnly` "
        f"dersler. Bu dosyayı ELLE DÜZENLEME — kaynağı düzenle, betiği koş.",
        "",
        f"**Toplam: {len(findings)} kalem.**",
        "",
    ]
    by_cat = {}
    for f in findings:
        by_cat.setdefault(f.category, []).append(f)
    for cat in ("asset", "copy", "data", "flow"):
        items = by_cat.get(cat, [])
        lines.append(f"## {CATEGORY_LABELS[cat]} ({len(items)})")
        lines.append("")
        if not items:
            lines.append("_Kayıtlı kalem yok._")
            lines.append("")
            continue
        for f in items:
            flag = "" if f.ok else " ⛔ BOZUK"
            lines.append(f"- **`{f.source}`**{flag}")
            lines.append(f"  {f.text}")
            if not f.ok:
                lines.append(f"  _Sorun: {f.problem}_")
        lines.append("")
    return "\n".join(lines).rstrip() + "\n"


def main():
    check_only = "--check" in sys.argv[1:]
    findings = scan_dart_markers() + scan_library_json()
    broken = [f for f in findings if not f.ok]
    rendered = render(findings)

    by_cat_count = {}
    for f in findings:
        by_cat_count[f.category] = by_cat_count.get(f.category, 0) + 1
    summary = " · ".join(f"{k}={v}" for k, v in sorted(by_cat_count.items()))

    if check_only:
        if not OUT_PATH.exists():
            print(f"❌ {OUT_PATH.relative_to(ROOT)} yok — önce `python3 "
                  f"tools/gen_placeholder_register.py` koş")
            return 1
        on_disk = OUT_PATH.read_text(encoding="utf-8")
        if on_disk != rendered:
            print(f"❌ {OUT_PATH.relative_to(ROOT)} kaynakla EŞLEŞMİYOR — "
                  f"bayat (kod değişti, kayıt yeniden üretilmedi). "
                  f"`python3 tools/gen_placeholder_register.py` koş.")
            return 1
    else:
        OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
        OUT_PATH.write_text(rendered, encoding="utf-8")
        print(f"✅ {OUT_PATH.relative_to(ROOT)} üretildi — {len(findings)} "
              f"kalem ({summary})")

    if broken:
        print(f"❌ {len(broken)} placeholder BOZUK:")
        for f in broken:
            print(f"   - {f.source}: {f.problem}")
        return 1

    if check_only:
        print(f"✅ placeholder kaydı TEMİZ ve GÜNCEL — {len(findings)} "
              f"kalem ({summary})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
