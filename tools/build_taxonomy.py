#!/usr/bin/env python3
"""Merge two independent harvest runs into one concept-coded taxonomy.

The two runs named the same concepts differently (and the second even switched
language mid-list). Codes are assigned by us and are stable; agent phrasing is
treated as evidence, never as identity. Where both runs found a concept from
different channels, the source count grows — convergence across independent
runs is the strongest signal this harvest produces.
"""
import json, sys
from collections import defaultdict

R1 = json.load(open("w1_partial.json"))
R2 = json.load(open("w1_full.json"))

# concept code -> list of error names seen in either run
CONCEPTS = {
 "voice": {
  "V-BREATH-CLAVICULAR": ["Clavicular / Shoulder Breathing"],
  "V-POST-LOCKED-KNEES": ["Locked Knees / Rigid Standing Posture"],
  "V-HEAD-CHIN-LIFT": ["Chin Lifting / Head Tilting Back on High Notes"],
  "V-JAW-TENSION": ["Jaw Tension / Clenching"],
  "V-PULLED-CHEST": ["Pulling Chest Voice / Yelling Instead of Transitioning"],
  "V-BREATHY-TONE": ["Breathy Tone (Incomplete Vocal Fold Closure)"],
  "V-NASALITY": ["Nasality (Excessive Nasal Resonance)"],
  "V-PITCH-DRIFT": ["Flat or Sharp Pitch (Intonation Drift)"],
  "V-MOUTH-CLOSED": ["Insufficient Mouth Opening / Closed Vowel Shaping"],
  "V-LARYNX-HIGH": ["High Larynx Position / Throat Tension"],
  "V-TONGUE-ROOT": ["Tongue Root Tension (Retracted/Bunched Tongue)"],
  "V-CATCH-BREATH": ["Catch-Breath / Audible Gasping Between Phrases"],
 },
 "piano": {
  "P-SETUP-BENCH-HEIGHT": ["Bench Height Mismatch (Wrong Bench/Seat Height)", "Wrong Bench/Seat Height"],
  "P-WRIST-COLLAPSE": ['Wrist Collapse / Wrist Hyperextension ("The Kink")', "Collapsed / Overly Raised Wrist"],
  "P-FINGER-FLAT": ["Flat / Collapsed Finger Joints"],
  "P-POST-SHOULDER-TENSION": ["Shoulder Tension / Hunching"],
  "P-ELBOW-ANGLE": ["Incorrect Elbow Angle"],
  "P-TEMPO-DRIFT": ["Tempo Inconsistency (Rushing & Dragging)", "Inconsistent Tempo (No Metronome Practice)"],
  "P-TOUCH-UNEVEN": ["Uneven Hand Balance (Uneven Touch Between Hands)", "Uneven Touch Between Fingers (Weak Pinky)"],
  "P-PEDAL-BLUR": ["Pedal Blur (Muddy Sustain Pedal Use)", "Early/Late Pedaling (Blurred Sound)"],
  "P-DEATH-GRIP": ["Death Grip / Finger Gripping Tension"],
  "P-EYES-ON-HANDS": ["Looking at Hands Too Much (No Tactile Independence)"],
  "P-LEGATO-GAP": ["Legato Gaps from Early Finger-Lift / Thumb-Under Fumble"],
  "P-PRACTICE-WHOLE-PIECE": ["Whole-Piece Practice Instead of Isolating Trouble Spots"],
  "P-READING-ROTE": ["Letter-Name/Rote Reliance Instead of True Note Reading",
                     "Skipping Note-Reading (Learning Purely by Ear)"],
 },
 "guitar": {
  "G-THUMB-OVER-NECK": ["Thumb Wrapped Over the Top of the Neck", "Baseball Grip (Thumb-Over-the-Neck)"],
  "G-WRIST-BENT": ["Bent / Twisted Fretting-Hand Wrist", 'Bent Wrist ("Waiter\'s Pose")'],
  "G-DEATH-GRIP": ['"Death Grip" — Squeezing the Neck Too Hard', "Death Grip"],
  "G-FINGER-PLACEMENT-BUZZ": ["Flat / Too-Far-From-Fret Fingers Causing Buzz or Muted Strings",
                              "Flat / Uncurled Fingers Muting Adjacent Strings",
                              "Fret Buzz (perdeye yeterince yakın/sağlam basmamak)"],
  "G-POST-SLOUCH": ["Poor Sitting Posture / Slouching Over the Guitar", "Kambur Oturuş / Kötü Genel Postür"],
  "G-PICK-GRIP-TENSE": ["Tense / Overly Tight Pick Grip While Strumming",
                        "Yanlış Pena Tutuşu (çok sıkı / çok fazla pena dışarıda)"],
  "G-TEMPO-DRIFT": ["Rushing or Dragging the Strumming Tempo", "Metronomsuz Çalışma / Tempo Kayması"],
  "G-CHORD-CHANGE-HESITATION": ["Hesitating During Chord Changes, Breaking the Rhythm",
                                "Yavaş/Kesik Akor Geçişleri (parmakları teker teker kaldırıp tek tek koymak)"],
  "G-NOT-TUNED": ["Neglecting to Tune Before Playing"],
  "G-PRACTICE-NO-ISOLATION": ["Practicing Through Mistakes Instead of Slow, Deliberate Practice",
                              "Kaynak/Öğretmen Değiştirip Durma, Temelleri Atlayıp İleri Şarkılara Geçme"],
 },
}

# J-028 / M-F-30 (P0 aile kuralı): ham normalize koordinatta mesafe ve açı,
# en-boy oranı kadar bozuktur (1080p dikeyde ~1,78×). Sentetik testler bunu
# YAKALAYAMAZ çünkü sentetik iskelet zaten kare bir uzayda üretilir — hata
# ancak gerçek karede görünür. Bu yüzden kamera/füzyon gören her hata kodu,
# metriğinin hangi uzayda hesaplandığını BEYAN ETMEK ZORUNDA; ham normalize
# uzay yasak, ve kod ship edilmeden önce en az bir gerçek-kare regresyonu ister.
MEASUREMENT_SPACE_ALLOWED = {"world", "pixel_scaled"}
MEASUREMENT_SPACE_BANNED = {"normalized_raw"}
#: varsayılan: iskelet geometrisi world uzayında yapılır (metrik, en-boy bağımsız)
DEFAULT_SPACE = "world"

# observable precedence: if runs disagree, the more conservative wins.
# invisible > audio/camera/fusion is NOT the rule — "we cannot see it" must win
# over "we can", because claiming observability we do not have is the failure
# mode that hurts users.
PRECEDENCE = {"invisible": 0, "audio": 1, "camera": 1, "fusion": 2}

def collect(run, key):
    return {e["errorName"]: e for e in run.get(key, {}).get("errors", [])}

out = {"schemaVersion": "ostinato-error-taxonomy-2", "version": "1.0.0", "generated": "2026-07-29",
       "method": "İki BAĞIMSIZ hasat koşumunun kavram-düzeyinde birleşimi. Kodlar bizim ve kalıcı; "
                 "ajanların adlandırması kanıttır, kimlik değil. İki koşumda da çıkan kavram = "
                 "koşumlar-arası yakınsama (bu hasadın ürettiği en güçlü sinyal).",
       "rules": {"minIndependentSourcesPerError": 2,
                 "measurementSpace": "J-028/M-F-30: kamera+fuzyon metrikleri world uzayinda (veya piksel-olcekli) hesaplanir; HAM NORMALIZE uzay YASAK (en-boy orani kadar bozar, ~1.78x@1080p dikey). Her kod ship oncesi >=1 gercek-kare regresyonu ister; sentetik fixture bu hatayi yakalayamaz.",
                 "invisibleInProductScope": False,
                 "observableConflict": "Çelişkide DAHA TEMKİNLİ sınıf kazanır (görebildiğimizi iddia etmek, görememekten daha zararlı)."},
       "instruments": {}}

problems = []
for inst, concepts in CONCEPTS.items():
    r1 = collect(R1, f"{inst}-mistakes")
    r2 = collect(R2, f"{inst}-mistakes")
    items = []
    for code, names in concepts.items():
        sources, obs, descs, runs = [], [], [], set()
        for run_id, run in (("run1", r1), ("run2", r2)):
            for n in names:
                if n in run:
                    e = run[n]
                    runs.add(run_id)
                    obs.append(e["cameraObservable"])
                    descs.append(e["description"])
                    for s in e["sources"]:
                        sources.append({"channel": s["channel"], "url": s["url"],
                                        "videoId": s.get("videoId"), "run": run_id})
        if not runs:
            problems.append(f"{inst}/{code}: hiçbir koşumda bulunamadı (kavram haritası bayat)")
            continue
        channels = {s["channel"] for s in sources}
        if len(channels) < 2:
            problems.append(f"{inst}/{code}: <2 bağımsız kanal ({len(channels)})")
        observable = min(obs, key=lambda o: PRECEDENCE[o])
        needs_space = observable in ("camera", "fusion")
        items.append({
            "code": code,
            "measurementSpace": DEFAULT_SPACE if needs_space else None,
            "realFrameRegression": "required" if needs_space else "n/a",
            "names": sorted({n for n in names if n in r1 or n in r2}),
            "description": max(descs, key=len),
            "observable": observable,
            "observableDisagreement": sorted(set(obs)) if len(set(obs)) > 1 else None,
            "inV1Scope": observable != "invisible",
            "independentChannels": len(channels),
            "confirmedInBothRuns": len(runs) == 2,
            "sources": sources,
        })
    inscope = [i for i in items if i["inV1Scope"]]
    out["instruments"][inst] = {
        "errors": items,
        "counts": {"total": len(items), "inScope": len(inscope),
                   "invisible": len(items) - len(inscope),
                   "confirmedBothRuns": sum(1 for i in items if i["confirmedInBothRuns"]),
                   "byObservable": {k: sum(1 for i in items if i["observable"] == k)
                                    for k in ("camera", "audio", "fusion", "invisible")}},
    }

# J-028 denetimi: kamera/füzyon kodları uzay beyanı taşımalı ve yasak uzayda olmamalı
for inst, d in out["instruments"].items():
    for e in d["errors"]:
        if e["observable"] in ("camera", "fusion"):
            sp = e.get("measurementSpace")
            if sp in MEASUREMENT_SPACE_BANNED or sp not in MEASUREMENT_SPACE_ALLOWED:
                problems.append(f"{inst}/{e['code']}: gecersiz olcum uzayi {sp!r} (J-028)")
            if e.get("realFrameRegression") != "required":
                problems.append(f"{inst}/{e['code']}: gercek-kare regresyonu isaretlenmemis (J-028)")
        elif e.get("measurementSpace") is not None:
            problems.append(f"{inst}/{e['code']}: ses/invisible kodda olcum uzayi olmamali")

# every name the agents produced must be mapped — otherwise we silently drop findings
for inst in CONCEPTS:
    mapped = {n for names in CONCEPTS[inst].values() for n in names}
    for run_id, run in (("run1", R1), ("run2", R2)):
        seen = set(collect(run, f"{inst}-mistakes"))
        for extra in seen - mapped:
            problems.append(f"{inst}/{run_id}: haritalanmamış hata ATLANDI -> {extra}")

json.dump(out, open("error-taxonomy.w1.json", "w"), ensure_ascii=False, indent=1)
print("SORUN:" if problems else "✅ denetim TEMİZ (kod eşlemesi tam · hata başına ≥2 bağımsız kanal · atlanan bulgu yok)")
for p in problems:
    print("  -", p)
for i, d in out["instruments"].items():
    c = d["counts"]
    print(f"  {i}: {c['total']} kod (kapsamda {c['inScope']} · invisible {c['invisible']}) "
          f"| iki koşumda da: {c['confirmedBothRuns']} | {c['byObservable']}")
sys.exit(1 if problems else 0)
