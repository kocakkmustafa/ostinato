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
  ◻️ kanal dışı — koşul, motoru henüz yazılmamış bir metriğe dayanıyor.
     Kapsama boşluğu; config kusuru değil, ama SAYILIR.
  ⛔ ölü faz — girdiler mevcuttu, koşul yine de hiç sağlanmadı. GERÇEK kusur.
  ⚠️ kapısız faz — çalarken de sessizlikte de ateşleniyor. Ses koşulu yazılmış
     ama iş görmüyor; ölü fazın aynadaki hâli ve linter'ın göremediği sınıf.

Ses kanalı `fixtures/audio/` (ostinato-audiofix-1) üzerinden beslenir. Poz ve ses
kayıtları bağımsızdır: buradaki hüküm ULAŞILABİLİRLİK kanıtıdır, eşzamanlılık
kanıtı değil.
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
#: Hiçbir fixture türünde BULUNMAYAN girdi sınıfı — motoru henüz yazılmamış
#: metrikler. Bir fazın koşulu yalnız bunlara dayanıyorsa "ölü faz" DEĞİL
#: "kanal dışı" demektir; ikisini aynı işaretle raporlamak gerçek ölü fazı
#: gürültüde kaybeder.
#:
#: Ses metrikleri 2026-07-29'da bu listeden ÇIKTI: `ostinato-audiofix-1` seti
#: üretildi, artık gerçek ölçülmüş değerlerle besleniyorlar (M-F-56 kapsama
#: boşluğu kapandı). Kalanlar fixture_check'in "aspirational" sınıfı.
OUT_OF_CHANNEL = {"vibrato_rate_hz", "chord_correctness", "strum_timing_ms",
                  "note_timing_ms", "setup_complete"}

#: Ses fixture'ından türetilen metrikler. Poz kareleriyle ZAMAN-HİZALI DEĞİL:
#: iki kayıt bağımsız. Bu yüzden buradaki "ateşlendi" hükmü ULAŞILABİLİRLİK
#: kanıtıdır ("bu koşul sağlanabiliyor"), eşzamanlı gerçek kullanımda ateşlendiği
#: kanıtı değil. Liveness kapısının sorusu zaten budur.
def audio_windows(fixture_id):
    path = f"fixtures/audio/{fixture_id}.json"
    d = json.load(open(path, encoding="utf-8"))
    expected = d["expected"].get("f0Hz")
    out = []
    for w in d["measured"]["windows"]:
        vals = {"level_above_room_floor_db": w["levelAboveFloorDb"],
                "periodicity": w["periodicity"]}
        if w["f0Hz"] and expected:
            vals["pitch_deviation_cents"] = abs(1200 * math.log(w["f0Hz"] / expected, 2))
        out.append(vals)
    return out


#: Her çalgı için: çalınan bir fixture + çalınmayan bir fixture. İkincisi kapının
#: NEGATİF yönünü sınar — ses-kapılı bir faz sessizlikte de ateşleniyorsa o faz
#: "canlı" değil, sadece koşulsuz.
AUDIO_BY_INSTRUMENT = {"voice": "AF-001-clean-sustained-a4",
                       "guitar": "AF-003-scale-with-metronome",
                       "piano": "AF-003-scale-with-metronome"}
SILENT_FIXTURE = "AF-002-room-noise-only"

AUDIO_METRICS = {"level_above_room_floor_db", "periodicity", "pitch_deviation_cents"}

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

        playing = audio_windows(AUDIO_BY_INSTRUMENT.get(inst, "AF-001-clean-sustained-a4"))
        silent = audio_windows(SILENT_FIXTURE)

        for t in cfg["techniques"]:
            fired = {p["id"]: 0 for p in t["phases"]}
            fired_silent = {p["id"]: 0 for p in t["phases"]}
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
                    a_play = playing[frames % len(playing)]
                    a_mute = silent[frames % len(silent)]
                    frames += 1
                    for p in t["phases"]:
                        r = evaluate(p.get("enter", {}), {**vals, **a_play})
                        if r is None: undecidable[p["id"]] += 1
                        elif r: fired[p["id"]] += 1
                        if evaluate(p.get("enter", {}), {**vals, **a_mute}) is True:
                            fired_silent[p["id"]] += 1

            print(f"  teknik {t['id']} — {frames} kare")
            for p in t["phases"]:
                pid = p["id"]
                f_, u_ = fired[pid], undecidable[pid]
                needed = condition_metrics(p.get("enter", {}))
                if f_ == 0 and u_ > 0 and needed and needed <= OUT_OF_CHANNEL:
                    # Kusur DEĞİL: bu faz ses kanalına bağlı, fixture pose-only.
                    print(f"    ◻️ {pid:10} kanal dışı — koşulu {', '.join(sorted(needed))} "
                          f"gerektiriyor; bu metriğin MOTORU henüz yok "
                          f"(fixture_check'te 'aspirational'; kapsama boşluğu, config kusuru değil)")
                elif f_ == 0 and u_ > 0:
                    print(f"    ⛔ {pid:10} HİÇ ATEŞLENMEDİ — {u_} karede koşul DEĞERLENDİRİLEMEDİ "
                          f"(gereken metrikler: {', '.join(sorted(needed))})")
                    rc = 1
                elif f_ == 0:
                    print(f"    ⛔ {pid:10} HİÇ ATEŞLENMEDİ — koşul {frames} karede hep yanlış")
                    rc = 1
                else:
                    needs_audio = needed & AUDIO_METRICS
                    mute = fired_silent[pid]
                    if needs_audio and mute > 0:
                        # Sessizlikte de ateşleniyor: koşul sesi gerçekten
                        # kapı olarak kullanmıyor. Ölü fazın aynadaki hâli.
                        print(f"    ⚠️ {pid:10} {f_}/{frames} çalarken ateşlendi AMA "
                              f"{mute}/{frames} SESSİZLİKTE de ateşlendi — "
                              f"ses koşulu ({', '.join(sorted(needs_audio))}) kapı görevi görmüyor")
                        rc = 1
                    else:
                        tag = " · sessizlikte 0 ✓" if needs_audio else ""
                        print(f"    ✅ {pid:10} {f_}/{frames} karede giriş koşulu sağlandı "
                              f"(%{100*f_/frames:.0f}){tag}")
    return rc


if __name__ == "__main__":
    sys.exit(main())
