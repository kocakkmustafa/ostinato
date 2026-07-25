#!/usr/bin/env python3
"""Ostinato G1-C pitch pre-measurement — synthetic cello-like tones.

Ground truth is exact by construction. Compares YIN vs pYIN (librosa
reference implementations of the algorithms we would re-implement natively),
across window sizes, sample rates, SNR levels, and a phone-mic highpass
simulation that weakens the C2 fundamental.
"""
import json, sys, time
import numpy as np
import librosa
from scipy.signal import butter, sosfilt

SR = 44100
DUR = 3.0
OPEN_STRINGS = {"C2": 65.406, "G2": 97.999, "D3": 146.832, "A3": 220.000}
RNG = np.random.default_rng(42)


def cello_like(f0, sr=SR, dur=DUR, vibrato=False):
    """Harmonic-rich bowed-string-ish tone: strong harmonics (body resonance
    often > fundamental on low strings), slow attack, optional vibrato,
    light bow noise."""
    t = np.arange(int(sr * dur)) / sr
    if vibrato:
        # ~5.5 Hz vibrato, +-15 cents
        f_inst = f0 * (1 + 0.0087 * np.sin(2 * np.pi * 5.5 * t))
        phase = 2 * np.pi * np.cumsum(f_inst) / sr
    else:
        phase = 2 * np.pi * f0 * t
    # harmonic amplitudes: fundamental deliberately NOT dominant (h2/h3 stronger)
    amps = [0.5, 1.0, 0.8, 0.5, 0.35, 0.25, 0.18, 0.12, 0.08, 0.05]
    x = sum(a * np.sin(k * phase) for k, a in enumerate(amps, start=1))
    # slow bow attack: 120 ms ramp
    env = np.minimum(1.0, t / 0.12)
    x = x * env
    # light broadband bow noise
    x += 0.02 * RNG.standard_normal(len(t))
    return (x / np.max(np.abs(x))).astype(np.float32)


def add_noise(x, snr_db):
    n = RNG.standard_normal(len(x)).astype(np.float32)
    p_sig = np.mean(x ** 2)
    p_n = p_sig / (10 ** (snr_db / 10))
    return x + n * np.sqrt(p_n / np.mean(n ** 2))


def phone_highpass(x, sr, fc=120.0, order=2):
    """Cheap-phone-mic simulation: 2nd order highpass at 120 Hz."""
    sos = butter(order, fc, btype="highpass", fs=sr, output="sos")
    return sosfilt(sos, x).astype(np.float32)


def cents(f_est, f_true):
    return 1200 * np.log2(f_est / f_true)


def eval_track(f0_frames, voiced_mask, f_true, sr, hop, attack_s=0.25):
    """Skip the attack window (our confidence gate would too), then measure."""
    start = int(attack_s * sr / hop)
    est = f0_frames[start:]
    vm = voiced_mask[start:] if voiced_mask is not None else ~np.isnan(est)
    est = est[vm & ~np.isnan(est)]
    if len(est) == 0:
        return dict(frames=0, med_cents=None, p95_cents=None, octave_rate=None)
    c = cents(est, f_true)
    octave_err = np.abs(c) > 600
    c_ok = c[~octave_err]
    return dict(
        frames=int(len(est)),
        med_cents=float(np.median(np.abs(c_ok))) if len(c_ok) else None,
        p95_cents=float(np.percentile(np.abs(c_ok), 95)) if len(c_ok) else None,
        octave_rate=float(np.mean(octave_err)),
    )


def run_algo(algo, x, sr, frame_length):
    hop = frame_length // 4
    fmin, fmax = 50.0, 500.0
    t0 = time.perf_counter()
    if algo == "yin":
        f0 = librosa.yin(x, fmin=fmin, fmax=fmax, sr=sr,
                         frame_length=frame_length, hop_length=hop)
        voiced = None
    else:
        f0, vflag, vprob = librosa.pyin(x, fmin=fmin, fmax=fmax, sr=sr,
                                        frame_length=frame_length, hop_length=hop)
        voiced = vflag
    dt = time.perf_counter() - t0
    return f0, voiced, hop, dt


def main():
    results = []
    conditions = []
    for note, f in OPEN_STRINGS.items():
        conditions.append((note, f, "clean", dict()))
        conditions.append((note, f, "vibrato", dict(vibrato=True)))
        conditions.append((note, f, "snr10", dict(snr=10)))
    # highpass matters mostly for the low strings
    conditions.append(("C2", OPEN_STRINGS["C2"], "hp120", dict(hp=True)))
    conditions.append(("G2", OPEN_STRINGS["G2"], "hp120", dict(hp=True)))
    conditions.append(("C2", OPEN_STRINGS["C2"], "hp120+snr10", dict(hp=True, snr=10)))

    for sr_target in (44100, 16000):
        for frame in ((2048, 4096) if sr_target == 44100 else (1024, 2048)):
            for note, f_true, cond, opts in conditions:
                x = cello_like(f_true, vibrato=opts.get("vibrato", False))
                if opts.get("hp"):
                    x = phone_highpass(x, SR)
                if "snr" in opts:
                    x = add_noise(x, opts["snr"])
                if sr_target != SR:
                    x = librosa.resample(x, orig_sr=SR, target_sr=sr_target)
                for algo in ("yin", "pyin"):
                    f0, voiced, hop, dt = run_algo(algo, x, sr_target, frame)
                    m = eval_track(f0, voiced, f_true, sr_target, hop)
                    m.update(note=note, cond=cond, algo=algo, sr=sr_target,
                             frame=frame, win_ms=round(1000 * frame / sr_target, 1),
                             rtf=round(dt / DUR, 4))  # real-time factor (desktop!)
                    results.append(m)
    print(json.dumps(results, indent=1))


if __name__ == "__main__":
    main()
