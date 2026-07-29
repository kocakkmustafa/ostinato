#!/usr/bin/env python3
"""Ruleset'te BEYAN EDİLEN her metriğin arkasında çalışan bir motor var mı?

Bir config, hesaplayabildiğinden fazlasını beyan edebilir ve hiçbir yapısal
linter bunu görmez — `chord_correctness` yazmak onu var etmez. Bu betik
metrikleri üç sınıfa ayırır ve pose metriklerini GERÇEK fixture'lardan
hesaplayarak canlı olduklarını kanıtlar:

  live      — bu betik burada, gerçek veriden hesapladı
  engine    — kodu var ve testli, ama girdisi bu fixture'da yok (ses)
  aspirational — motoru HENÜZ YOK; config söz veriyor, ürün tutamaz

Üçüncü sınıf boş olmak zorunda değil (yol haritası meşru), ama SAYILMALI:
sayılmayan söz, ship gününde keşfedilir.
"""
import json, glob, math, os, sys
from statistics import median

L_SH, R_SH, L_HIP, R_HIP = 11, 12, 23, 24
L_EL, R_EL, L_WR, R_WR = 13, 14, 15, 16

# metrik id -> nasıl hesaplanır
POSE = {
    "trunk_tilt": lambda w: _angle_from_vertical(_mid(w, L_SH, R_SH), _mid(w, L_HIP, R_HIP)),
    "left_shoulder": lambda w: _flexion(w[L_EL], w[L_SH], w[L_HIP]),
    "right_shoulder": lambda w: _flexion(w[R_EL], w[R_SH], w[R_HIP]),
    "left_elbow": lambda w: _flexion(w[L_SH], w[L_EL], w[L_WR]),
    "right_elbow": lambda w: _flexion(w[R_SH], w[R_EL], w[R_WR]),
    "left_upper_arm": lambda w: _segment_dir(w[L_SH], w[L_EL]),
    "right_upper_arm": lambda w: _segment_dir(w[R_SH], w[R_EL]),
    "left_forearm": lambda w: _segment_dir(w[L_EL], w[L_WR]),
    "right_forearm": lambda w: _segment_dir(w[R_EL], w[R_WR]),
}
# kodu var, testli — ama girdisi ses; video fixture'ında yok
AUDIO_ENGINE = {"pitch_deviation_cents", "periodicity", "level_above_room_floor_db",
                "vibrato_rate_hz"}
# motoru henüz yok
NO_ENGINE_HINT = {"chord_correctness": "Basic Pitch TFLite/CoreML dönüşüm spike'ı bekliyor (W1)",
                  "strum_timing_ms": "onset motoru var ama akor-vuruş eşlemesi yok",
                  "note_timing_ms": "MIDI modu spike'ı bekliyor (flutter_midi_command)",
                  "setup_complete": "Setup Check akışı henüz yazılmadı (platform katmanı, M-F-25 erteli)",
                  "shoulder_rise_norm": "türetilmiş metrik; tanımı henüz yok",
                  "head_chin_angle_deg": "yüz landmark'ı gerekiyor; pose-only fixture'da yok"}


def _mid(w, a, b):
    return [(w[a][i] + w[b][i]) / 2 for i in range(3)]


def _angle_from_vertical(top, bottom):
    dx, dy = top[0] - bottom[0], top[1] - bottom[1]
    return abs(math.degrees(math.atan2(abs(dx), abs(dy))))


def _flexion(a, b, c):
    v1 = [a[i] - b[i] for i in range(3)]
    v2 = [c[i] - b[i] for i in range(3)]
    dot = sum(v1[i] * v2[i] for i in range(3))
    n1 = math.sqrt(sum(x * x for x in v1)); n2 = math.sqrt(sum(x * x for x in v2))
    if n1 == 0 or n2 == 0: return float("nan")
    return math.degrees(math.acos(max(-1, min(1, dot / (n1 * n2)))))


def _segment_dir(a, b):
    return abs(math.degrees(math.atan2(abs(b[0] - a[0]), abs(b[1] - a[1]))))


def fixtures_for(instrument):
    lib = os.path.expanduser("~/motion-harvest/ostinato/landmarks")
    imap = json.load(open("config/fixture-instrument-map.json", encoding="utf-8"))
    return [f for f in sorted(glob.glob(f"{lib}/*.json"))
            if imap.get(os.path.basename(f).split(".")[0]) == instrument]


def compute(metric, files, max_frames=3000):
    fn = POSE[metric]
    vals = []
    for f in files[:4]:
        d = json.load(open(f))
        for fr in d["frames"][:max_frames]:
            if not fr.get("detected") or not fr.get("world"):
                continue
            w = fr["world"]
            if len(w) <= R_HIP:
                continue
            try:
                v = fn(w)
            except Exception:
                continue
            if not math.isnan(v):
                vals.append(v)
    return vals


def main():
    rc = 0
    for path in sorted(glob.glob("config/rulesets/*.json")):
        d = json.load(open(path, encoding="utf-8"))
        inst = d.get("module")
        files = fixtures_for(inst)
        print(f"\n═══ {os.path.basename(path)} ({len(files)} fixture) ═══")
        live = engine = aspirational = 0
        for mid in d["metrics"]:
            if mid in POSE:
                vals = compute(mid, files)
                if vals:
                    live += 1
                    print(f"  live         {mid:20} n={len(vals):6}  medyan {median(vals):6.1f}°  "
                          f"aralık [{min(vals):.0f}, {max(vals):.0f}]")
                else:
                    aspirational += 1
                    print(f"  ⚠️ HESAPLANAMADI {mid:20} (fixture var ama değer çıkmadı)")
                    rc = 1
            elif mid in AUDIO_ENGINE:
                engine += 1
                print(f"  engine       {mid:20} (ostinato_audio testli; girdi=ses, bu fixture'da yok)")
            else:
                aspirational += 1
                hint = NO_ENGINE_HINT.get(mid, "motor bilinmiyor")
                print(f"  aspirational {mid:20} → {hint}")
        total = live + engine + aspirational
        print(f"  ── {live} live · {engine} engine · {aspirational} aspirational  (toplam {total})")
        if aspirational and total:
            print(f"     ⚠️ metriklerin %{100*aspirational/total:.0f}'i henüz motorsuz — config söz veriyor, "
                  f"ürün bugün tutamaz")
    return rc


if __name__ == "__main__":
    sys.exit(main())
