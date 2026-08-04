#!/usr/bin/env python3
"""Uçtan-uca replay senaryosu — postür kapısı ile çalgının kendi ses hattı
BİRLİKTE mi çalışıyor? ÜÇ ÇALGI İÇİN (ders-yolu paketi, madde 3).

Neden ayrı bir kapı: `replay_check.py` her fazı BAĞIMSIZ, kare-kare kontrol
eder (bu fazın koşulu bu karede sağlanıyor mu) — hiçbir ZAMAN SIRASI kurmaz.
`verify_score_consumer_live.py` yalnız POSTURE_CHECK'i tek başına sınadı. Bu
betik bir GERÇEK OTURUMU simüle eder: kullanıcı önce oturur (ses YOK, postür
kapısı çalışır) sonra çalar/söyler (ses VAR, çalgının kapısı çalışır) — ve
faz makinesinin bu ikisini SIRAYLA doğru ZİNCİRLEDİĞİNİ kanıtlar.

2026-08-04 (M-O-39 dersi, bu sefer önceden): betik ÇALGI-PARAMETRELİ. Önceki
sürüm yalnız gitarı koşuyordu ve şan/piyano için kopyalanacaktı — üç kopya,
üç ayrı bayatlama yolu. Tek kanonik yol: çalgıya özgü olan her şey `SPECS`
tablosunda, mantık ortak.

Doğrulama take'i EN KALIN KANITLI olandan seçilir (`evidenceThickness`,
M-F-150): tur 48'de ölçüldü ki take SAYISI ile referans GÜCÜ aynı şey değil —
gitarın 7 take'inin yalnız 2'si tam yoğunlukta. Uçtan-uca kanıtın hangi
kalınlıkta bir kaynağa dayandığı RAPOR EDİLİR, sessiz bırakılmaz.

Dürüstlük sınırı (değişmedi): Ostinato'nun henüz Dart RUNTIME motoru yok
(platform iskeleti M-F-25 ile ertelendi) — burada motion_core'un gerçek
`PhaseStateMachine`i DEĞİL, `replay_check.py`nin AYNI `evaluate()` mantığı
kullanılıyor (JSON ruleset semantiğinin Python yansıması). READY fazı
`setup_complete` motoruna bağlı ve o motor YOK — bu adım STUB'lanır,
gizlenmez.
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from replay_check import POSE, evaluate, audio_windows  # noqa: E402

LIB = Path.home() / "motion-harvest" / "ostinato"
RULESET = "config/rulesets/{}@0.2.0-draft.json"
REFERENCE = "config/references/{}-posture-setup.v1.json"

#: Çalgıya özgü olan HER ŞEY burada. Mantık aşağıda ortak.
SPECS = {
    "guitar": {
        "technique": "open_chord_drill",
        "silentFixture": "AF-002-room-noise-only",
        "playingFixture": "AF-003-scale-with-metronome",
        # Ses seviyesi kapıyı AÇAR; akor kalitesi AYRI bir gerçek kayıttan gelir
        # (M-F-116). İki bağımsız ölçüm, ikisi de gerçek — beyanlı sınır.
        "levelTriggerFrom": "AF-003-scale-with-metronome",
        "chordFixture": "AF-007-open-chord-E-major",
        "mustPass": ["trunk_tilt", "chord_correctness"],
    },
    "voice": {
        "technique": "sustained_note_drill",
        "silentFixture": "AF-002-room-noise-only",
        # Şan hattının AYRICALIĞI: tek fixture SUSTAIN'in İKİ quality metriğini
        # de (pitch_deviation_cents + periodicity) GERÇEK YIN motorundan
        # üretiyor. Gitarda seviye ve akor iki ayrı kayıttan geliyordu; şanda
        # tek kayıt yetiyor — bu yüzden şan zinciri üçünün en bütünü.
        "playingFixture": "AF-001-clean-sustained-a4",
        "levelTriggerFrom": None,  # fixture'ın kendi pencereleri sürdürülür
        "chordFixture": None,
        "mustPass": ["trunk_tilt", "pitch_deviation_cents", "periodicity"],
    },
    "piano": {
        "technique": "five_finger_drill",
        "silentFixture": "AF-002-room-noise-only",
        "playingFixture": "AF-003-scale-with-metronome",
        "levelTriggerFrom": "AF-003-scale-with-metronome",
        "chordFixture": None,
        # PLAY fazının derecelendirilen quality kapısı YOK (M-O-65:
        # note_timing_ms ölçülür ama puanlanmaz). Zincir kanıtı postürden ve
        # faz geçişinden gelir — olmayan bir kapıyı "geçti" diye saymayız.
        "mustPass": ["trunk_tilt"],
        "reportOnly": {"fixture": "AF-008-five-note-timing", "metric": "note_timing_ms"},
    },
}


def thickest_take(instrument):
    """ATTESTED referansa katkı veren, hold-penceresi OLAN ve kanıtı EN KALIN
    take. Seçim gerekçesi rapora yazılır."""
    ref = json.loads(Path(REFERENCE.format(instrument)).read_text(encoding="utf-8"))
    thickness = ref["evidenceThickness"]["takes"]
    manifest = json.loads((LIB / f"hold-windows-{instrument}.json").read_text())
    windows = {r["videoId"]: r for r in manifest["sources"] if r.get("tStartS") is not None}

    candidates = [(tid, t) for tid, t in thickness.items() if tid in windows]
    if not candidates:
        raise SystemExit(f"{instrument}: hold-penceresi olan ATTESTED take YOK")
    # Önce kanıt kalınlığı, eşitlikte daha uzun süre.
    tid, t = max(candidates, key=lambda kv: (kv[1]["alignedDistinctShare"], kv[1]["durationS"]))
    src = next(x for x in ref["takes"] if x["id"] == tid)
    return tid, windows[tid], t, src["source"]


def load_posture_window(video_id, row):
    doc = json.loads((LIB / "landmarks" / f"{video_id}.full.json").read_text())
    t0, t1 = row["tStartS"], row["tEndS"]
    return [fr for fr in doc["frames"]
            if fr.get("detected") and fr.get("world") and t0 <= fr["t"] / 1000.0 < t1]


def performance_phase(technique):
    """Postürden SONRAKİ, gerçekten ÖLÇÜM yapılan faz. Adı çalgıdan çalgıya
    değişiyor (PLAY / SUSTAIN) — tabloya elle yazmak yerine ruleset'ten
    okunuyor ki config değişince betik bayatlamasın."""
    for p in technique["phases"]:
        if p["id"] != "POSTURE_CHECK" and p.get("measureHere"):
            return p["id"]
    raise SystemExit("ölçüm yapan performans fazı bulunamadı")


def playing_values(spec, k):
    """k'ıncı 'çalıyor' karesinin ses değerleri."""
    if spec["levelTriggerFrom"] is None:
        wins = audio_windows(spec["playingFixture"])
        return dict(wins[k % len(wins)])
    raw = audio_windows(spec["levelTriggerFrom"])
    trigger = next(w for w in raw if w["level_above_room_floor_db"] > 20)
    vals = dict(trigger)
    if spec["chordFixture"]:
        d = json.loads(Path(f"fixtures/audio/{spec['chordFixture']}.json").read_text(encoding="utf-8"))
        cw = d["measured"]["windows"]
        vals["chord_correctness"] = cw[k % len(cw)]["score"]
    return vals


def run(instrument):
    spec = SPECS[instrument]
    cfg = json.load(open(RULESET.format(instrument), encoding="utf-8"))
    technique = next(t for t in cfg["techniques"] if t["id"] == spec["technique"])
    phases = {p["id"]: p for p in technique["phases"]}
    order = [p["id"] for p in technique["phases"]]
    perf = performance_phase(technique)

    take_id, row, thick, source = thickest_take(instrument)
    pose_frames = load_posture_window(take_id, row)
    if not pose_frames:
        raise SystemExit(f"{instrument}: {take_id} hold-penceresinde kare YOK")
    silent = audio_windows(spec["silentFixture"])

    n = len(pose_frames)
    timeline = (
        [("SESSİZLİK", pose_frames[i], silent[i % len(silent)]) for i in range(n // 2)] +
        [("SES VAR", pose_frames[i], playing_values(spec, i - n // 2)) for i in range(n // 2, n)]
    )

    current = order[0]
    log, stubbed = [], set()
    quality_hits = {}
    phase_active = {pid: 0 for pid in order}

    for label, fr, aud in timeline:
        vals = {}
        for mid, fn in POSE.items():
            if mid in cfg["metrics"]:
                try:
                    v = fn(fr["world"])
                    if v == v:  # NaN kontrolü
                        vals[mid] = v
                except Exception:
                    pass
        vals.update(aud)

        phase_active[current] += 1
        p = phases[current]

        for metric, cond in p.get("quality", {}).items():
            r = evaluate({"kind": "metric", "metric": metric,
                          "op": cond["op"], "value": cond["value"]}, vals)
            if r is not None:
                bucket = quality_hits.setdefault(metric, {"PASS": 0, "FAIL": 0})
                bucket["PASS" if r else "FAIL"] += 1

        exit_cond = p.get("exit")
        if exit_cond and evaluate(exit_cond, vals) is True:
            idx = order.index(current)
            if idx + 1 < len(order):
                nxt = order[idx + 1]
                enter_r = evaluate(phases[nxt].get("enter", {}), vals)
                # READY `setup_complete`e bağlı ve o motor YOK: değerlendirilemez
                # (None). STUB'lanır ve log'a yazılır — sessizce atlanmaz.
                if enter_r is None and "setup_complete" in str(phases[nxt].get("enter")):
                    stubbed.add(nxt)
                    idx += 1
                    nxt = order[idx + 1] if idx + 1 < len(order) else nxt
                if current != nxt:
                    log.append(f"  [{label}] {current} → {nxt}")
                current = nxt

    print(f"=== {instrument.upper()} — OTUR (ses yok) → {perf} (ses var) ===")
    print(f"postür kaynağı: {take_id} ({source}) · {n} kare · "
          f"kanıt kalınlığı {thick['alignedDistinctShare']:.2f} "
          f"({thick['durationS']:.1f} sn)")
    print(f"ses: {spec['silentFixture']} (sessiz) → {spec['playingFixture']}"
          + (f" + {spec['chordFixture']}" if spec["chordFixture"] else ""))
    if thick["alignedDistinctShare"] < 1.0:
        print(f"⚠️  bu take'in kanıtı TAM DEĞİL ({thick['alignedDistinctShare']:.2f}) — "
              f"zincir kanıtlanır ama tek kaynağın kalınlığı beyan edilir")

    for line in log:
        print(line)
    if stubbed:
        print(f"⚠️  STUB'lanan faz (motoru yok): {sorted(stubbed)}")

    print("faz-başına aktif kare: " +
          " · ".join(f"{pid}={phase_active[pid]}" for pid in order))
    if quality_hits:
        for metric, hits in quality_hits.items():
            print(f"  quality {metric:22} PASS={hits['PASS']} FAIL={hits['FAIL']}")
    else:
        print("  quality kapısı YOK (bu çalgının performans fazında "
              "derecelendirilen metrik yok — beyanlı)")

    if spec.get("reportOnly"):
        ro = spec["reportOnly"]
        d = json.loads(Path(f"fixtures/audio/{ro['fixture']}.json").read_text(encoding="utf-8"))
        vals = {k: v[ro["metric"].replace("note_timing_ms", "noteTimingMs")]
                for k, v in d["measured"].items()}
        print(f"  ÖLÇÜLÜR-PUANLANMAZ {ro['metric']}: " +
              " · ".join(f"{k}={v}ms" for k, v in vals.items()) +
              f"  (motor tabanı {d['derived']['engineFloorMs']}ms — bar YOK, M-O-65)")

    problems = []
    if phase_active["POSTURE_CHECK"] == 0:
        problems.append("POSTURE_CHECK hiç aktif olmadı")
    if phase_active.get(perf, 0) == 0:
        problems.append(f"{perf} fazına hiç geçilmedi")
    for metric in spec["mustPass"]:
        hits = quality_hits.get(metric)
        if hits is None:
            problems.append(f"{metric} quality kapısı HİÇ DEĞERLENDİRİLMEDİ "
                            f"(metrik üretilmiyor olabilir)")
        elif hits["PASS"] == 0:
            problems.append(f"{metric} hiç PASS vermedi")

    ok = not problems
    print("✅ ZİNCİR KANITLANDI" if ok else "⛔ " + " · ".join(problems))
    print()
    return ok


def main():
    targets = [a for a in sys.argv[1:] if not a.startswith("-")] or list(SPECS)
    results = {t: run(t) for t in targets}
    bad = [t for t, ok in results.items() if not ok]
    print("=" * 52)
    print(f"{len(results) - len(bad)}/{len(results)} çalgıda uçtan-uca zincir kanıtlandı"
          + (f" — BAŞARISIZ: {bad}" if bad else ""))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
