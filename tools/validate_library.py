#!/usr/bin/env python3
"""İçerik kütüphanesi (`assets/content/library.json`) dürüstlük denetimi —
JabLab `library_test.dart`in AYNI beş kuralını (kopyası değil, aynı
gerekçeyle) Python'da uygular (M-F-103/108, kilitli-ders paketi).

İhlal = kullanıcıya verilmiş somut bir sözün çiğnenmesi — uyarı değil hata.
"""
import json
import sys
from pathlib import Path


def load(path):
    return json.loads(Path(path).read_text(encoding="utf-8"))


def technique_ids(ruleset_path):
    if not Path(ruleset_path).exists():
        return set()
    cfg = load(ruleset_path)
    return {t["id"] for t in cfg.get("techniques", [])}


def main():
    lib_path = "assets/content/library.json"
    lib = load(lib_path)
    violations = []

    for d in lib["disciplines"]:
        did = d["id"]

        # Kural 1: coming_soon disiplinde kurs OLAMAZ.
        if d.get("status") == "coming_soon" and d.get("courses"):
            violations.append(f"{did}: coming_soon ama {len(d['courses'])} kurs listeliyor")

        # Kural 4: her disiplinde honesty.notMeasured DOLU olmalı.
        not_measured = d.get("honesty", {}).get("notMeasured")
        if not not_measured:
            violations.append(f"{did}: honesty.notMeasured boş/yok")

        if d.get("status") != "live":
            continue

        rs_path = f"config/rulesets/{d['rulesetId']}@0.2.0-draft.json"
        techs = technique_ids(rs_path)

        for c in d.get("courses", []):
            # Kural 2: her kursun en az 1 dersi olmalı.
            if not c.get("lessons"):
                violations.append(f"{did}/{c['id']}: boş kurs (0 ders)")
                continue

            for l in c["lessons"]:
                lid = l["id"]
                # Kural 3: ders, ruleset'te BULUNMAYAN teknige atif yapamaz.
                for t in l.get("techniques", []):
                    if t not in techs:
                        violations.append(
                            f"{lid}: var olmayan tekniğe atıf: '{t}' "
                            f"(ruleset {d['rulesetId']}'de yok)")
                # Kural 5: locked ders lockedReason taşımalı.
                if l.get("status") == "locked" and not l.get("lockedReason"):
                    violations.append(f"{lid}: status=locked ama lockedReason yok")
                if l.get("status") != "locked" and l.get("lockedReason"):
                    violations.append(f"{lid}: lockedReason var ama status=locked değil "
                                       f"(tutarsız beyan)")

        # Kural 6: comingSoonInThisDiscipline maddeleri gerekçesiz olamaz
        # (canlı disiplinin İÇİNDEKİ kapsam-dışı maddeler — ayrı listedeki
        # string'ler, ' — ' ile gerekçe taşımalı, boş bırakılmamalı).
        for item in d.get("comingSoonInThisDiscipline", []):
            if len(item.strip()) < 20:
                violations.append(f"{did}: comingSoonInThisDiscipline maddesi "
                                   f"gerekçesiz görünüyor: '{item}'")

    if violations:
        print(f"⛔ {len(violations)} DÜRÜSTLÜK İHLALİ:")
        for v in violations:
            print(f"   - {v}")
        return 1

    live = [d["id"] for d in lib["disciplines"] if d.get("status") == "live"]
    soon = [d["id"] for d in lib["disciplines"] if d.get("status") == "coming_soon"]
    print(f"✅ kütüphane denetimi TEMİZ — {len(lib['disciplines'])} disiplin "
          f"({len(live)} canlı: {live} · {len(soon)} yakında: {soon})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
