#!/usr/bin/env python3
"""Canlı yüzeyin sözleşme varlığını ÜRET — `assets/config/posture-contract.json`.

Neden üretilir, elle yazılmaz: kabuğun gösterdiği her sayı referans
artefaktına bağlı kalmalı. Elle yazılan bir varlık, regen sonrası sessizce
bayatlar ve ekranda "7 eğitmen" yazarken artefakt başka bir şey söyler —
tam olarak O-029'un (vitrin korumasızdı) canlı-yüzey hâli.

`--check` modu: varlık artefaktlarla hâlâ aynı şeyi söylüyor mu?
"""
import json, math, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))
from replay_check import POSE

INSTRUMENTS = ["guitar", "voice", "piano"]
OUT = Path("assets/config/posture-contract.json")
LIB = Path.home() / "motion-harvest" / "ostinato"
SOURCE_CLASS = {"guitar": "guitar teachers", "voice": "voice teachers",
                "piano": "piano teachers"}


def med(xs):
    s = sorted(xs); n = len(s)
    return s[n // 2] if n % 2 else (s[n // 2 - 1] + s[n // 2]) / 2


def build():
    out = {}
    for inst in INSTRUMENTS:
        ref = json.loads(Path(f"config/references/{inst}-posture-setup.v1.json")
                         .read_text(encoding="utf-8"))
        cfg = json.loads(Path(f"config/rulesets/{inst}@0.2.0-draft.json")
                         .read_text(encoding="utf-8"))
        cue = cfg["observationCues"][0]
        k = ref["joints"].index("trunk_tilt")
        disp = round(math.degrees(med([f[k] for f in ref["frames"]["dispersionRad"]])), 2)

        # Eğitmen bandı: hold-penceresi take-medyanları (teacher_range dersinin
        # veri kaynağı). Uydurulmaz — kaynağın kendi kaydından ölçülür.
        man = json.loads((LIB / f"hold-windows-{inst}.json").read_text())
        win = {r["videoId"]: r for r in man["sources"] if r.get("tStartS") is not None}
        meds = []
        for t in ref["takes"]:
            row = win.get(t["id"])
            if not row:
                continue
            doc = json.loads((LIB / "landmarks" / f"{t['id']}.full.json").read_text())
            vals = [POSE["trunk_tilt"](fr["world"]) for fr in doc["frames"]
                    if fr.get("detected") and fr.get("world")
                    and row["tStartS"] <= fr["t"] / 1000.0 < row["tEndS"]]
            vals = [v for v in vals if v == v]
            if vals:
                meds.append(med(vals))
        out[inst] = {
            "scoringToleranceDeg": cfg["metrics"]["trunk_tilt"]["noiseBand"],
            "cueThresholdDeg": cue["condition"]["value"],
            "teacherCount": ref["result"]["contributingTakes"],
            "sourceClass": SOURCE_CLASS[inst],
            "bandLowDeg": round(min(meds), 1),
            "bandHighDeg": round(max(meds), 1),
            "cueTemplateId": cue["template"],
            "dispersionMedianDeg": disp,
            "_derivedFrom": {
                "artifact": f"config/references/{inst}-posture-setup.v1.json",
                "generatedAt": ref["generatedAt"],
            },
        }
    return out


def main():
    built = build()
    if "--check" in sys.argv:
        if not OUT.exists():
            print(f"⛔ {OUT} YOK — `python3 tools/gen_posture_contract.py` koştur")
            return 1
        cur = json.loads(OUT.read_text(encoding="utf-8"))
        bad = [i for i in INSTRUMENTS if cur.get(i) != built[i]]
        if bad:
            print(f"⛔ sözleşme varlığı BAYAT: {bad} — artefaktla uyuşmuyor. "
                  f"`python3 tools/gen_posture_contract.py` ile yeniden üret.")
            for i in bad:
                for kk in built[i]:
                    if cur.get(i, {}).get(kk) != built[i][kk]:
                        print(f"   {i}.{kk}: varlık {cur.get(i,{}).get(kk)!r} != "
                              f"artefakt {built[i][kk]!r}")
            return 1
        print("✅ canlı yüzey sözleşmesi artefaktlarla EŞİT "
              + " · ".join(f"{i}: bant {built[i]['bandLowDeg']}-{built[i]['bandHighDeg']}° "
                           f"({built[i]['teacherCount']} eğitmen)" for i in INSTRUMENTS))
        return 0
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(built, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"✅ {OUT} üretildi")
    for i in INSTRUMENTS:
        b = built[i]
        print(f"   {i}: bant {b['bandLowDeg']}–{b['bandHighDeg']}° · "
              f"tolerans {b['scoringToleranceDeg']}° · cue {b['cueThresholdDeg']}° · "
              f"{b['teacherCount']} {b['sourceClass']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
