#!/usr/bin/env python3
"""Ostinato G1-C — real cello recordings (Iowa MIS 2012, arco ff).

Each file holds an ascending chromatic sequence starting at the open string.
We segment on silence, assign ground-truth notes chromatically, and compare
YIN / pYIN / SwiftF0 per segment. Also repeats with a 120 Hz highpass
(phone-mic simulation) for the low strings.
"""
import json, time
import numpy as np
import librosa
from scipy.signal import butter, sosfilt
from swift_f0 import SwiftF0

FILES = [
    ("iowa/Cello.arco.ff.sulC.C2B2.stereo.aif", "C2", 65.406, 12),   # C2..B2
    ("iowa/Cello.arco.ff.sulG.G2Gb3.stereo.aif", "G2", 97.999, 12),  # G2..F#3
    ("iowa/Cello.arco.ff.sulD.D3Db4.stereo.aif", "D3", 146.832, 12), # D3..C#4
    ("iowa/Cello.arco.ff.sulA.A3Ab4.stereo.aif", "A3", 220.0, 12),   # A3..G#4
]
SR = 44100


def cents(a, b):
    return 1200 * np.log2(a / b)


def segments(y, sr, top_db=35, min_len_s=0.6):
    iv = librosa.effects.split(y, top_db=top_db)
    return [(s, e) for s, e in iv if (e - s) / sr >= min_len_s]


def median_f0_yin(seg, sr, frame=4096):
    f0 = librosa.yin(seg, fmin=50, fmax=600, sr=sr, frame_length=frame,
                     hop_length=frame // 4)
    return f0


def median_f0_pyin(seg, sr, frame=4096):
    f0, v, p = librosa.pyin(seg, fmin=50, fmax=600, sr=sr, frame_length=frame,
                            hop_length=frame // 4)
    return f0[~np.isnan(f0)]


_sf0 = SwiftF0(confidence_threshold=0.5)

def median_f0_swift(seg, sr):
    r = _sf0.detect_from_array(seg.astype(np.float32), sr)
    f = np.asarray(r.pitch_hz)[np.asarray(r.confidence) >= 0.5]
    return f


def hp120(y, sr):
    sos = butter(2, 120.0, btype="highpass", fs=sr, output="sos")
    return sosfilt(sos, y).astype(np.float32)


def eval_segment(f0_frames, f_true, trim_frac=0.15):
    f0 = np.asarray(f0_frames, dtype=float)
    f0 = f0[~np.isnan(f0)]
    if len(f0) < 8:
        return None
    k = int(len(f0) * trim_frac)          # drop attack/release frames
    f0 = f0[k: len(f0) - k or None]
    c = cents(f0, f_true)
    med = float(np.median(c))
    octave = abs(med) > 550
    # per-frame octave-ish outliers
    frame_oct = float(np.mean(np.abs(c) > 550))
    return dict(med_cents=med, frame_octave_rate=frame_oct, octave=bool(octave),
                n=len(f0))


def main():
    rows = []
    for path, start_note, f_start, n_notes in FILES:
        y, sr = librosa.load(path, sr=SR, mono=True)
        # Segment ALWAYS on the highpassed signal (low-frequency room rumble
        # confuses the silence splitter and breaks chromatic assignment);
        # analyze the requested variant inside those boundaries.
        seg_ref = segments(hp120(y, sr), sr)
        if len(seg_ref) != n_notes:
            print(f"UYARI: {path} segment sayısı {len(seg_ref)} != {n_notes}")
        for variant in (["clean", "hp120"] if f_start < 120 else ["clean"]):
            yy = hp120(y, sr) if variant == "hp120" else y
            segs = seg_ref
            # assign chromatic ground truth to the first n_notes segments
            for i, (s, e) in enumerate(segs[:n_notes]):
                f_true = f_start * (2 ** (i / 12))
                seg = yy[s:e]
                for algo, fn in (("yin", median_f0_yin), ("pyin", median_f0_pyin),
                                 ("swiftf0", median_f0_swift)):
                    try:
                        t0 = time.perf_counter()
                        f0f = fn(seg, sr) if algo != "swiftf0" else fn(seg, sr)
                        dt = time.perf_counter() - t0
                        m = eval_segment(f0f, f_true)
                        if m is None:
                            m = dict(med_cents=None, frame_octave_rate=None,
                                     octave=None, n=0)
                        m.update(file=start_note, variant=variant, idx=i,
                                 note_hz=round(f_true, 2), algo=algo,
                                 rtf=round(dt / (len(seg) / sr), 4))
                        rows.append(m)
                    except Exception as ex:
                        rows.append(dict(file=start_note, variant=variant, idx=i,
                                         algo=algo, error=str(ex)[:120]))
    json.dump(rows, open("results_real.json", "w"), indent=1)
    # summary
    import collections
    g = collections.defaultdict(list)
    for r in rows:
        if r.get("med_cents") is None and "error" not in r:
            g[(r["algo"], r["variant"])].append(("skip", r))
        elif "error" in r:
            g[(r["algo"], r["variant"])].append(("err", r))
        else:
            g[(r["algo"], r["variant"])].append(("ok", r))
    print(f"{'algo':8} {'variant':7} {'segs':4} {'med|c| med':10} {'|c| p95':8} {'seg-oct%':8} {'skip/err':8} {'rtf med':7}")
    for (algo, var), items in sorted(g.items()):
        ok = [r for tag, r in items if tag == "ok"]
        sk = sum(1 for tag, _ in items if tag != "ok")
        if ok:
            absmed = [abs(r["med_cents"]) for r in ok if not r["octave"]]
            octr = 100 * np.mean([r["octave"] for r in ok])
            rtf = np.median([r["rtf"] for r in ok])
            print(f"{algo:8} {var:7} {len(ok):4} {np.median(absmed):10.1f} {np.percentile(absmed,95):8.1f} {octr:7.1f}% {sk:8} {rtf:7}")
    # worst offenders
    bad = [r for r in rows if r.get("octave")]
    print(f"\nOktav hatalı segmentler ({len(bad)}):")
    for r in bad[:12]:
        print(f"  {r['algo']:8} {r['file']}[{r['idx']}] {r['variant']} true={r['note_hz']}Hz med={r['med_cents']:.0f}c n={r['n']}")


if __name__ == "__main__":
    main()
