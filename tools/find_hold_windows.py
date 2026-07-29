#!/usr/bin/env python3
"""Her uygun kaynak için `hold_isolator.find_hold_windows`i koşturur (M-F-75
ARA ADIM 1b-v2, koordinatör talimatı).

Neden transkript aday-zamanı: `hold_isolator`in `candidate_times_s` kancası
aday pencereleri ÖNCELİKLENDİRİR (kabul ETMEZ — enerji/drift/kapsama
kapılarından yine geçmeli). Adayları rom_mode.py'nin AYNI ACTIVE_MARKERS
regex'iyle transkriptten çıkarıyoruz — yeni bir anahtar kelime seti icat
etmiyoruz (M-O-18 dersi: kopya kural seti ayrışır).

Neden eşik-geri-çekilmesi (max_drift 0.06→0.08): koordinatör talimatı —
"pencere bulamadığın fixture'larda 0.08 ile dene ve HANGİ değerle bulduğunu
raporla; kalibrasyonu senin sayıların mühürleyecek." Sessizce gevşetilmiyor —
her fixture'ın hangi eşikte bulunduğu manifestte AYRI alanla kayıtlı.

Çıktı: `~/motion-harvest/ostinato/hold-windows.json` — kaynak başına seçilen
pencere (frame aralığı, hangi max_drift'te bulunduğu, aday-isabet durumu) +
DAYANAK (drift/enerji/kapsama sayıları). Pencere BULUNAMAYAN kaynak da
isimle ve nedeniyle kayda geçer (sessiz atlama yok).
"""
import json
import re
import sys
from pathlib import Path

RIG = Path("/Users/mustafakaankocak/motion-worktrees/ostinato-hold-isolator/tools/harvest_rig")
sys.path.insert(0, str(RIG))
from hold_isolator import find_hold_windows  # noqa: E402
from rom_mode import ACTIVE_MARKERS  # noqa: E402

LIB = Path.home() / "motion-harvest" / "ostinato"
DEFAULT_MAX_DRIFT = 0.06
FALLBACK_MAX_DRIFT = 0.08


def candidate_times(video_id: str) -> list[float]:
    p = LIB / "transcripts" / f"{video_id}.transcript.json"
    if not p.exists():
        return []
    segs = json.loads(p.read_text(encoding="utf-8"))
    if not isinstance(segs, list):
        return []
    out = []
    for seg in segs:
        text = seg.get("text", "")
        if any(re.search(pat, text, flags=re.IGNORECASE) for pat in ACTIVE_MARKERS):
            out.append(float(seg.get("start", 0.0)))
    return out


def main() -> int:
    want = sys.argv[1] if len(sys.argv) > 1 else None
    if not want:
        print("kullanım: find_hold_windows.py <voice|guitar|piano>", file=sys.stderr)
        return 64

    imap = json.loads(Path("config/fixture-instrument-map.json").read_text())
    rows = []
    for f in sorted((LIB / "landmarks").glob("*.json")):
        vid = f.name.split(".")[0]
        if imap.get(vid) != want:
            continue
        doc = json.loads(f.read_text(encoding="utf-8"))
        prov = doc.get("provenance", {})
        if prov.get("referenceEligible") is not True:
            continue  # ineligible/unattested — hold_isolator'a hiç sokulmaz

        fps = doc.get("recordingMeta", {}).get("fps")
        frames = [fr.get("lm") if fr.get("detected") is not False else None
                  for fr in doc.get("frames", [])]
        cands = candidate_times(vid)

        used_drift = DEFAULT_MAX_DRIFT
        windows = find_hold_windows(frames, fps=float(fps), candidate_times_s=cands,
                                     max_drift=DEFAULT_MAX_DRIFT)
        if not windows:
            used_drift = FALLBACK_MAX_DRIFT
            windows = find_hold_windows(frames, fps=float(fps), candidate_times_s=cands,
                                         max_drift=FALLBACK_MAX_DRIFT)

        row = {"videoId": vid, "candidateTimesS": cands, "fps": fps}
        if windows:
            w = windows[0]
            # Ham kare indeksi Dart'ın Fixture.frames'iyle (yalnız TESPİT
            # EDİLMİŞ kareler, gap'siz) birebir eşleşmez — dizinin kendisi
            # ÇIKARIM YAPMAZ, SÜRE eşlemesi kullanılır (M-O-23/27 dersi:
            # kare-indeksi yerine zaman). fps zaten bu satırda taşınıyor.
            row.update({
                "found": True,
                "maxDriftUsed": used_drift,
                "startFrame": w.start_frame,
                "endFrame": w.end_frame,
                "tStartS": w.start_frame / float(fps),
                "tEndS": w.end_frame / float(fps),
                "seconds": w.seconds,
                "energyPerS": w.energy_per_s,
                "drift": w.drift,
                "coverage": w.coverage,
                "candidateHit": w.candidate_hit,
            })
            print(f"  {vid}: BULUNDU [{w.start_frame}-{w.end_frame}] "
                  f"({w.seconds:.1f}s) drift={w.drift:.3f} (max_drift={used_drift}) "
                  f"enerji/s={w.energy_per_s:.3f} aday-isabet={w.candidate_hit}")
        else:
            row.update({"found": False, "maxDriftUsed": used_drift})
            print(f"  {vid}: BULUNAMADI (max_drift={used_drift}'te bile)")
        rows.append(row)

    out = LIB / f"hold-windows-{want}.json"
    out.write_text(json.dumps({
        "$why": "hold_isolator@4ad1e2c çıktısı — her kaynağın seçilmiş penceresi + "
                "DAYANAĞI (enerji/drift/kapsama). Bulunamayan kaynak da isimle kayıtlı.",
        "instrument": want,
        "defaultMaxDrift": DEFAULT_MAX_DRIFT,
        "fallbackMaxDrift": FALLBACK_MAX_DRIFT,
        "sources": rows,
    }, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    found = sum(1 for r in rows if r["found"])
    fallback_needed = sum(1 for r in rows if r["found"] and r["maxDriftUsed"] == FALLBACK_MAX_DRIFT)
    print(f"\n{found}/{len(rows)} pencere bulundu ({fallback_needed} yalnız 0.08 geri-çekilmesiyle)")
    print(f"yazıldı: {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
