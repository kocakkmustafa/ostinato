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


def error_metric_map(ruleset_path):
    """Hata kodu -> koşulunun bağlandığı metrik. Kural 7'nin dayanağı."""
    if not Path(ruleset_path).exists():
        return {}
    cfg = load(ruleset_path)
    return {e["code"]: e.get("condition", {}).get("metric")
            for e in cfg.get("errors", [])}


def scored_metrics(ruleset_path):
    if not Path(ruleset_path).exists():
        return set()
    return set(load(ruleset_path).get("referenceConsumption", {}).get("scored", []))


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
        err_metric = error_metric_map(rs_path)
        scored = scored_metrics(rs_path)

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
                # Kural 7 (M-O-53): AÇIK bir ders yalnız GERÇEKTEN skorlanan bir
                # metriğe bağlı hata kodunu öne çıkarabilir. Gerekçe ölçüldü:
                # gitar ruleset'indeki 5 hata kodunun 4'ü taslak olarak
                # `level_above_room_floor_db > 15`e bağlı — yani "başparmak
                # sapta" uyarısı SES YÜKSEKLİĞİNDE ateşlerdi. `expertPending`
                # bayrağı bunu engellemiyor: hiçbir kod/araç o bayrağı OKUMUYOR
                # (beşinci canlılık sorusu — bayrak var, tüketicisi yok).
                # Bu kural, o tuzağın kullanıcıya AÇIK ders olarak ulaşmasını
                # mekanik olarak keser; ruleset'in kendi düzeltmesi ayrı iş
                # (koordinatör hükmü bekliyor — eşik/eşleme TASARIM kararı).
                if l.get("status") != "locked":
                    for code in l.get("errorFocus", []):
                        if code not in err_metric:
                            violations.append(
                                f"{lid}: var olmayan hata koduna atıf: '{code}'")
                        elif err_metric[code] not in scored:
                            violations.append(
                                f"{lid}: AÇIK ders '{code}' hata kodunu öne "
                                f"çıkarıyor ama o kod skorlanmayan bir metriğe "
                                f"bağlı ({err_metric[code]!r}; skorlananlar: "
                                f"{sorted(scored)}) — kullanıcıya ölçülmeyen "
                                f"bir hüküm vaat edilirdi")

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
