#!/usr/bin/env python3
"""Şan araç-yarışı iskeleti (M-F-118, koordinatör direktifi — gece paketi
2026-07-29) — `presence_isolator` core'a MERGE OLDUĞUNDA 4 uygun şan
kaynağını iki araçla yarıştıracak betik. ŞİMDİ YAZILIYOR, KOŞULMUYOR:
presence tarafı henüz core'da yok (Lissom dalında bitiriliyor, merge
koordinatörde) — bu iskelet o merge geldiğinde `run_presence_trunk()`
TEK yerde değişecek şekilde tasarlandı (akor-fixture'daki "hazır boru
hattı" deseninin şan karşılığı — `make_chord_fixture.dart`nın `--real`
uzantısı neyse, burada presence_isolator'ın import'u o).

İki araç, aynı 4 kaynak, aynı soru — "burada kararlı bir duruş var mı?":

  - HOLD (upperBody, GEVŞETİLMİŞ) — GERÇEK, bugün koşulabilir.
    `hold_isolator` şan malzemesi için kalibre DEĞİL (M-O-51: drift
    medyanı gitar/piyano eşiğinin 4-16 katı — `sarki-postur-presence-
    spec.md`). Gerçek `scope="trunkOnly"` hold_isolator'da YOK (yalnız
    fullBody/upperBody/lowerBody) — en yakın GERÇEK scope `upperBody`
    (TORSO 4 landmark her koşulda zorunlu kontrol ediliyor; kollar
    zaten B4/M-O-09'da coached_only, hesaba karışmaları zararsız).
    Drift KAPI OLARAK KULLANILMIYOR (spec §2b-3 önerisi: `math.inf` ile
    fiilen devre dışı, yalnız RAPORLANIYOR) — enerji tavanı spec'in
    önerdiği ~0,5/s'e çekildi. İkisi de var olan `find_hold_windows`
    parametreleri — CORE'A DOKUNULMADI, yalnız çağrı şekli değişti.
  - PRESENCE (trunk-odaklı) — HENÜZ YOK. `presence_isolator.
    find_presence_windows` (aday imza, spec §2c) import edilmeye
    ÇALIŞILIR; bulunamazsa NOT_AVAILABLE döner — sessizce atlanmaz,
    isimle işaretlenir (family disiplini: kapsama boşluğu SAYILIR).

Karşılaştırma metrikleri (ikisi de mevcut olduğunda anlamlı):
  - pencere sayısı, toplam kapsanan saniye
  - HOLD: enerji/s + drift (raporlanır, KAPI değil)
  - PRESENCE: trunk_tilt bant-genişliği (spec'in "kapı değil dayanak" önerisi)
  - zaman-örtüşmesi (saniye) — iki araç AYNI anları mı seçiyor?

Kaynak listesi İCAT EDİLMEDİ: `fixture-instrument-map.json`da
instrument=voice VE provenance.referenceEligible=true olan kayıtlar
(`find_hold_windows.py`nin AYNI filtresi) — bugün tam 4 kaynak
(GiHZrYCAIas/CGhlnPVquHw/II2b3gs31SU/xm1NdA4cmEs), `sarki-postur-
presence-spec.md`nin ölçtüğü kümeyle BİREBİR.
"""
import importlib
import json
import math
import sys
from pathlib import Path

RIG = Path("/Users/mustafakaankocak/motion-worktrees/ostinato-hold-isolator/tools/harvest_rig")
sys.path.insert(0, str(RIG))
from hold_isolator import find_hold_windows  # noqa: E402

LIB = Path.home() / "motion-harvest" / "ostinato"

#: spec §2b: enerji tavanı YÜKSEK ama var — hold'un ORİJİNAL (henüz
#: gitar/piyano için daraltılmamış) tavanı, gerçek veriyle KALİBRE EDİLMEDİ
#: (spec'in kendi açık uyarısı — presence_isolator'ın ilk koşumu kalibre eder).
HOLD_RELAXED_ENERGY = 0.5
#: spec §2b-3: drift KAPI DEĞİL — math.inf ile fiilen devre dışı (yalnız
#: raporda görünür, pencere onun yüzünden reddedilmez).
HOLD_RELAXED_DRIFT = math.inf
WINDOW_S = 5.0  # spec §2c önerisi — hold'un 3.0s varsayılanından geniş


def eligible_voice_sources():
    """`find_hold_windows.py`nin AYNI filtresi — kaynak listesi icat edilmiyor."""
    imap = json.loads(Path("config/fixture-instrument-map.json").read_text())
    out = []
    for f in sorted((LIB / "landmarks").glob("*.json")):
        vid = f.name.split(".")[0]
        if imap.get(vid) != "voice":
            continue
        doc = json.loads(f.read_text(encoding="utf-8"))
        if doc.get("provenance", {}).get("referenceEligible") is not True:
            continue
        out.append((vid, doc))
    return out


def run_hold_relaxed(doc, fps):
    """GERÇEK, bugün koşulabilir — var olan `hold_isolator`ı spec'in
    gevşetilmiş eşikleriyle çağırır (core kodu DEĞİŞMEDİ)."""
    frames = [fr.get("lm") if fr.get("detected") is not False else None
              for fr in doc.get("frames", [])]
    windows = find_hold_windows(
        frames, fps=float(fps), window_s=WINDOW_S, scope="upperBody",
        max_energy_per_s=HOLD_RELAXED_ENERGY, max_drift=HOLD_RELAXED_DRIFT,
        min_coverage=0.8,
    )
    return {
        "tool": "hold_upperBody_relaxed",
        "available": True,
        "windowCount": len(windows),
        "totalSeconds": round(sum(w.seconds for w in windows), 1),
        "windows": [{"tStartS": w.start_frame / fps, "tEndS": w.end_frame / fps,
                     "energyPerS": w.energy_per_s, "drift": w.drift,
                     "coverage": w.coverage} for w in windows],
    }


def run_presence_trunk(doc, fps):
    """HENÜZ YOK — `presence_isolator` core'a merge olunca burası TEK YERDE
    (bu fonksiyon) değişir, geri kalan iskelet AYNI kalır. Aday imza:
    `sarki-postur-presence-spec.md` §2c (`find_presence_windows`)."""
    try:
        presence_isolator = importlib.import_module("presence_isolator")
    except ImportError:
        return {"tool": "presence_trunkFocused", "available": False,
                "reason": "presence_isolator core'a henüz merge olmadı (M-F-118 bekliyor)"}
    frames = [fr.get("lm") if fr.get("detected") is not False else None
              for fr in doc.get("frames", [])]
    windows = presence_isolator.find_presence_windows(
        frames, fps=float(fps), window_s=WINDOW_S, scope="trunkOnly",
        max_energy_per_s=HOLD_RELAXED_ENERGY, min_coverage=0.8,
        report_trunk_tilt_band=True,
    )
    return {"tool": "presence_trunkFocused", "available": True, "windows": windows}


def overlap_seconds(hold_windows, presence_windows):
    """İki aracın SEÇTİĞİ pencereler ZAMANDA ne kadar örtüşüyor (saniye) —
    'aynı anları mı buluyorlar' sorusunun ilk kaba ölçüsü. Örtüşme YÜKSEK
    olsun/olmasın hüküm DEĞİL — presence_isolator'ın ilk gerçek-veri koşumu
    yorumlar (bu iskelet ölçer, karar vermez)."""
    total = 0.0
    for a in hold_windows:
        for b in presence_windows:
            lo = max(a["tStartS"], b["tStartS"])
            hi = min(a["tEndS"], b["tEndS"])
            if hi > lo:
                total += hi - lo
    return round(total, 1)


def main():
    sources = eligible_voice_sources()
    print(f"=== Şan araç-yarışı iskeleti — {len(sources)} uygun kaynak ===\n")
    report = []
    for vid, doc in sources:
        fps = doc.get("recordingMeta", {}).get("fps")
        hold = run_hold_relaxed(doc, fps)
        presence = run_presence_trunk(doc, fps)
        row = {"videoId": vid, "fps": fps, "hold": hold, "presence": presence}
        if presence.get("available"):
            row["overlapSeconds"] = overlap_seconds(hold["windows"], presence["windows"])
        report.append(row)
        presence_txt = (f"⏳ {presence['reason']}" if not presence["available"]
                         else f"{len(presence['windows'])} pencere")
        print(f"{vid}: hold {hold['windowCount']} pencere/{hold['totalSeconds']}s"
              f" | presence: {presence_txt}")

    out = LIB / "voice-tool-race.json"
    out.write_text(json.dumps({
        "$why": "M-F-118 iskeleti — presence_isolator merge olunca run_presence_trunk() "
                "TEK yerde değişir, geri kalan koşum AYNI kalır. Bugün yalnız hold "
                "tarafı GERÇEK; presence tarafı isimle NOT_AVAILABLE.",
        "sources": report,
    }, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(f"\nyazıldı: {out}")

    if not any(r["presence"]["available"] for r in report):
        print("\n⏳ presence_isolator core'a merge olmadı — yarış HENÜZ koşulamıyor "
              "(beklenen; hata DEĞİL). Merge sinyali geldiğinde tekrar çalıştır.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
