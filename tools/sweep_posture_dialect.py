#!/usr/bin/env python3
"""AYNI-KOD izole on/off süpürmesi — duruş-lehçesi işaretlerinin TÜM AİLE
korpusunda ne değiştirdiğini ölçer (M-F-125 / M-O-54 hükmünün şartı).

Neden "aynı kod": lehçenin etkisini ölçmenin tek dürüst yolu, AYNI
`classify()` fonksiyonunu iki kez koşturup YALNIZ marker demetini
değiştirmektir. Ayrı bir "eski davranış" kopyası yazsaydım, ölçtüğüm şey
lehçe değil kopyamın sadakati olurdu (M-O-39'un kanonik-vs-kopya dersi).

Neden TÜM aile korpusu, yalnız Ostinato değil: bir sözlük değişikliği
kardeş app'lerin havuzlarını da yeniden sınıflandırır. Ostinato'da kazanç,
JabLab/Lissom/Choreia'da sessiz bir kayıp olabilir — o kayıp burada
görünmezse hiçbir yerde görünmez.

Çıktı: her GEÇİŞ (sınıf değiştiren kaynak) isimle listelenir; hüküm elle
doğrulanmak ÜZERE üretilir, otomatik kabul edilmez.
"""
import json
import sys
from pathlib import Path

RIG = Path("/Users/mustafakaankocak/motion-worktrees/ostinato-hold-isolator/tools/harvest_rig")
sys.path.insert(0, str(RIG))
import rom_mode  # noqa: E402

HARVEST = Path.home() / "motion-harvest"


def transcript_text(p: Path) -> str:
    try:
        segs = json.loads(p.read_text(encoding="utf-8"))
    except Exception:
        return ""
    if not isinstance(segs, list):
        return ""
    return " ".join(s.get("text", "") for s in segs)


def classify_with(markers, title, desc, text, pep):
    """AYNI classify(), YALNIZ ACTIVE demeti değişik."""
    orig = rom_mode.ACTIVE_MARKERS
    try:
        rom_mode.ACTIVE_MARKERS = markers
        return rom_mode.classify(title=title, description=desc, transcript=text,
                                 passive_execution_possible=pep)
    finally:
        rom_mode.ACTIVE_MARKERS = orig


def main() -> int:
    base = tuple(m for m in rom_mode.ACTIVE_MARKERS
                 if m not in rom_mode.POSTURE_CUE_MARKERS)
    with_dialect = rom_mode.ACTIVE_MARKERS
    print(f"süpürme: {len(base)} temel işaret  vs  {len(with_dialect)} "
          f"(+{len(rom_mode.POSTURE_CUE_MARKERS)} duruş-lehçesi)\n")

    transitions, totals = [], {}
    for app_dir in sorted(HARVEST.iterdir()):
        if not app_dir.is_dir():
            continue
        tdir = app_dir / "transcripts"
        if not tdir.exists():
            continue
        app = app_dir.name
        counts = {"kaynak": 0, "değişen": 0}
        for tp in sorted(tdir.glob("*.json")):
            vid = tp.name.split(".")[0]
            man = app_dir / "manifests" / f"{vid}.json"
            title = desc = ""
            pep = True
            if man.exists():
                m = json.loads(man.read_text(encoding="utf-8"))
                title, desc = m.get("title") or "", m.get("description") or ""
                for s in m.get("stages", []):
                    if s.get("stage") == "romMode":
                        pep = s.get("detail", {}).get("passiveExecutionPossible", True)
            text = transcript_text(tp)
            if not text:
                continue
            counts["kaynak"] += 1
            a = classify_with(base, title, desc, text, pep)
            b = classify_with(with_dialect, title, desc, text, pep)
            if (a.mode, a.reference_eligible) != (b.mode, b.reference_eligible):
                counts["değişen"] += 1
                transitions.append({
                    "app": app, "videoId": vid,
                    "before": {"mode": a.mode, "eligible": a.reference_eligible},
                    "after": {"mode": b.mode, "eligible": b.reference_eligible},
                    "newHits": sorted(set(b.active_hits) - set(a.active_hits)),
                    "passiveExecutionPossible": pep,
                })
        totals[app] = counts

    print("app-başına: (kaynak / sınıfı DEĞİŞEN)")
    for app, c in totals.items():
        print(f"  {app:10} {c['kaynak']:3} / {c['değişen']}")

    print(f"\nGEÇİŞLER ({len(transitions)}) — her biri ELLE doğrulanacak:")
    for t in transitions:
        print(f"  [{t['app']}] {t['videoId']}: {t['before']['mode']}"
              f"(uygun={t['before']['eligible']}) → {t['after']['mode']}"
              f"(uygun={t['after']['eligible']})")
        print(f"      yeni isabet: {t['newHits']}")

    out = HARVEST / "posture-dialect-sweep.json"
    out.write_text(json.dumps({
        "$why": "AYNI-kod izole on/off süpürmesi (M-O-54). Geçişler ELLE doğrulanmak "
                "üzere listelenir; otomatik kabul YOK.",
        "baseMarkerCount": len(base), "dialectMarkerCount": len(rom_mode.POSTURE_CUE_MARKERS),
        "perApp": totals, "transitions": transitions,
    }, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(f"\nyazıldı: {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
