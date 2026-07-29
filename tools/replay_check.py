#!/usr/bin/env python3
"""Ruleset'in FAZ MAKİNESİ gerçek fixture'da ateşleniyor mu?

`fixture_check` metriklerin hesaplanabildiğini kanıtlar; bu betik bir adım
öteye gider: config'in fazlarını gerçek kare akışında çalıştırıp hangi
geçişlerin ATEŞLENDİĞİNİ sayar.

Neden ayrı bir kapı: metrikleri hesaplanabilen, linter'dan temiz geçen,
sarkan atıfı olmayan bir config yine de ÖLÜ olabilir — giriş koşulu hiç
sağlanmıyorsa o teknik hiçbir zaman değerlendirilmez ve bunu yalnız replay
gösterir. "Hiç ateşlenmeyen faz" = kullanıcı doğru yapsa bile hüküm çıkmaz.

Üç sonuç ayrılır ve karıştırılmaz:
  ✅ ateşlendi
  ◻️ kanal dışı — koşul yalnız bu fixture türünde bulunmayan girdilere dayanıyor
     (ses). Kapsama boşluğu; config kusuru değil, ama SAYILIR.
  ⛔ ölü faz — girdiler mevcuttu, koşul yine de hiç sağlanmadı. GERÇEK kusur.
"""
import json, glob, math, os, sys
from statistics import median

L_SH, R_SH, L_HIP, R_HIP = 11, 12, 23, 24
L_EL, R_EL, L_WR, R_WR = 13, 14, 15, 16


def _mid(w, a, b):
    return [(w[a][i] + w[b][i]) / 2 for i in range(3)]


def _angle_from_vertical(top, bottom):
    return abs(math.degrees(math.atan2(abs(top[0] - bottom[0]), abs(top[1] - bottom[1]))))


def _flexion(a, b, c):
    v1 = [a[i] - b[i] for i in range(3)]; v2 = [c[i] - b[i] for i in range(3)]
    n1 = math.sqrt(sum(x * x for x in v1)); n2 = math.sqrt(sum(x * x for x in v2))
    if n1 == 0 or n2 == 0: return float("nan")
    return math.degrees(math.acos(max(-1, min(1, sum(v1[i] * v2[i] for i in range(3)) / (n1 * n2)))))


def _seg(a, b):
    return abs(math.degrees(math.atan2(abs(b[0] - a[0]), abs(b[1] - a[1]))))


POSE = {
    "trunk_tilt": lambda w: _angle_from_vertical(_mid(w, L_SH, R_SH), _mid(w, L_HIP, R_HIP)),
    "left_shoulder": lambda w: _flexion(w[L_EL], w[L_SH], w[L_HIP]),
    "right_shoulder": lambda w: _flexion(w[R_EL], w[R_SH], w[R_HIP]),
    "left_elbow": lambda w: _flexion(w[L_SH], w[L_EL], w[L_WR]),
    "right_elbow": lambda w: _flexion(w[R_SH], w[R_EL], w[R_WR]),
    "left_upper_arm": lambda w: _seg(w[L_SH], w[L_EL]),
    "right_upper_arm": lambda w: _seg(w[R_SH], w[R_EL]),
    "left_forearm": lambda w: _seg(w[L_EL], w[L_WR]),
    "right_forearm": lambda w: _seg(w[R_EL], w[R_WR]),
}
#: Bu fixture türünde (pose-only video) BULUNMAYAN girdi sınıfı. Bir fazın
#: koşulu yalnız bunlara dayanıyorsa "ölü faz" DEĞİL "kanal dışı" demektir —
#: ikisini aynı işaretle raporlamak, gerçek ölü fazı gürültüde kaybeder.
OUT_OF_CHANNEL = {"level_above_room_floor_db", "periodicity", "pitch_deviation_cents",
                  "vibrato_rate_hz", "chord_correctness", "strum_timing_ms",
                  "note_timing_ms", "setup_complete"}

OPS = {"lt": lambda a, b: a < b, "gt": lambda a, b: a > b,
       "lte": lambda a, b: a <= b, "gte": lambda a, b: a >= b, "eq": lambda a, b: a == b}


def evaluate(cond, values):
    """Koşulu değerlendir. Metrik yoksa None döner — False DEĞİL.

    Ayrım kritik: 'koşul sağlanmadı' ile 'koşulu değerlendiremedim' farklı
    şeyler. İkincisini False saymak, ölü bir fazı "sadece tetiklenmedi" gibi
    gösterir ve kusuru gizler.
    """
    kind = cond.get("kind")
    if kind == "metric":
        v = values.get(cond["metric"])
        if v is None: return None
        return OPS[cond["op"]](v, cond["value"])
    if kind == "flag":
        v = values.get(cond["metric"])
        if v is None: return None
        return bool(v) == cond.get("is", True)
    if kind == "timeInPhase":
        return True
    if kind in ("all", "any"):
        subs = [evaluate(c, values) for c in cond.get("of", [])]
        if any(s is None for s in subs): return None
        return all(subs) if kind == "all" else any(subs)
    return None


def condition_metrics(cond, acc=None):
    acc = acc if acc is not None else set()
    if not isinstance(cond, dict): return acc
    if cond.get("metric"): acc.add(cond["metric"])
    for c in cond.get("of", []): condition_metrics(c, acc)
    return acc


def main():
    imap = json.load(open("config/fixture-instrument-map.json", encoding="utf-8"))
    lib = os.path.expanduser("~/motion-harvest/ostinato/landmarks")
    rc = 0
    for path in sorted(glob.glob("config/rulesets/*.json")):
        cfg = json.load(open(path, encoding="utf-8"))
        inst = cfg.get("module")
        files = [f for f in sorted(glob.glob(f"{lib}/*.json"))
                 if imap.get(os.path.basename(f).split(".")[0]) == inst][:3]
        print(f"\n═══ {inst} ({len(files)} fixture ile replay) ═══")
        if not files:
            print("  fixture yok"); continue

        for t in cfg["techniques"]:
            fired = {p["id"]: 0 for p in t["phases"]}
            undecidable = {p["id"]: 0 for p in t["phases"]}
            frames = 0
            for f in files:
                d = json.load(open(f))
                for fr in d["frames"][:2000]:
                    if not fr.get("detected") or not fr.get("world"): continue
                    w = fr["world"]
                    if len(w) <= R_HIP: continue
                    vals = {}
                    for mid, fn in POSE.items():
                        if mid in cfg["metrics"]:
                            try:
                                v = fn(w)
                                if not math.isnan(v): vals[mid] = v
                            except Exception:
                                pass
                    frames += 1
                    for p in t["phases"]:
                        r = evaluate(p.get("enter", {}), vals)
                        if r is None: undecidable[p["id"]] += 1
                        elif r: fired[p["id"]] += 1

            print(f"  teknik {t['id']} — {frames} kare")
            for p in t["phases"]:
                pid = p["id"]
                f_, u_ = fired[pid], undecidable[pid]
                needed = condition_metrics(p.get("enter", {}))
                if f_ == 0 and u_ > 0 and needed and needed <= OUT_OF_CHANNEL:
                    # Kusur DEĞİL: bu faz ses kanalına bağlı, fixture pose-only.
                    print(f"    ◻️ {pid:10} kanal dışı — koşulu {', '.join(sorted(needed))} "
                          f"gerektiriyor; ses fixture'ı yok (kapsama boşluğu, config kusuru değil)")
                elif f_ == 0 and u_ > 0:
                    print(f"    ⛔ {pid:10} HİÇ ATEŞLENMEDİ — {u_} karede koşul DEĞERLENDİRİLEMEDİ "
                          f"(gereken metrikler: {', '.join(sorted(needed))})")
                    rc = 1
                elif f_ == 0:
                    print(f"    ⛔ {pid:10} HİÇ ATEŞLENMEDİ — koşul {frames} karede hep yanlış")
                    rc = 1
                else:
                    print(f"    ✅ {pid:10} {f_}/{frames} karede giriş koşulu sağlandı "
                          f"(%{100*f_/frames:.0f})")
    return rc


if __name__ == "__main__":
    sys.exit(main())
