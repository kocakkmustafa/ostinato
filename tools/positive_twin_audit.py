#!/usr/bin/env python3
"""Pozitif-ikiz denetimi (M-F-194): her YOKLUK iddiasının, dedektörün
konuşabildiğini gösteren bir ikizi var mı?

Kural
-----
"X olmadı" / "sayaç 0" biçimindeki her iddia, TEK BAŞINA hiçbir şey
kanıtlamaz: hep-`false` dönen bir dedektör o testi de geçer, üstelik
kusursuz görünerek. İddia ancak AYNI dedektörün AYNI koşumda >0 ürettiği
bir ikizle birlikte anlam taşır.

Ters yön de arıza (M-F-207 zeyli): sürekli konuşan bir dedektör de
"yokluk" iddiasını anlamsızlaştırır — o yüzden burada her çift İKİ YÖNLÜ
sınanır (sessiz taraf gerçekten sessiz, konuşan taraf gerçekten konuşuyor).

Bu betik bir kontrol listesi DEĞİL: her çiftin iki tarafını da GERÇEKTEN
koşar ve sayıları basar. İkizi olmayan iddia isimle raporlanır.
"""
import json
import math
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from replay_check import POSE, audio_windows  # noqa: E402

LIB = Path.home() / "motion-harvest" / "ostinato"
FIX = Path("fixtures/audio")


def _trunk(video_id, window=None):
    p = LIB / "landmarks" / f"{video_id}.full.json"
    if not p.exists():
        return []
    out = []
    for fr in json.loads(p.read_text())["frames"]:
        if not (fr.get("detected") and fr.get("world")):
            continue
        if window and not (window[0] <= fr["t"] / 1000.0 < window[1]):
            continue
        try:
            v = POSE["trunk_tilt"](fr["world"])
        except Exception:
            continue
        if v == v:
            out.append(v)
    return out


# ── Çiftler: her biri (sessiz taraf sayısı, konuşan taraf sayısı) döndürür ──

def twin_observation_cue():
    """YOKLUK: gözlem işareti, referansı kuran pencerelerde 0 ateşler.
    İKİZ: aynı işaret, aynı eşikle, videonun tamamında ateşler."""
    ref = json.loads(Path("config/references/guitar-posture-setup.v1.json").read_text())
    man = json.loads((LIB / "hold-windows-guitar.json").read_text())
    win = {r["videoId"]: r for r in man["sources"] if r.get("tStartS") is not None}
    bar = ref["gates"]["clusterToleranceDeg"]
    quiet = speak = 0
    for t in ref["takes"]:
        row = win.get(t["id"])
        if row:
            quiet += sum(1 for v in _trunk(t["id"], (row["tStartS"], row["tEndS"])) if v > bar)
        speak += sum(1 for v in _trunk(t["id"]) if v > bar)
    return quiet, speak, "hold-penceresinde ateşleme", "tüm videoda ateşleme"


def twin_audio_gate():
    """YOKLUK: negatif ses fixture'ları hiç hüküm vermez (judged 0).
    İKİZ: pozitif fixture'lar hüküm verir."""
    idx = json.loads((FIX / "index.json").read_text())
    quiet = sum(f.get("judgedFraction", 0) > 0 for f in idx["fixtures"]
                if f.get("shouldJudge") is False)
    speak = sum(f.get("judgedFraction", 0) > 0 for f in idx["fixtures"]
                if f.get("shouldJudge") is True and "judgedFraction" in f)
    return quiet, speak, "negatif fixture'da hüküm", "pozitif fixture'da hüküm"


def twin_level_gate():
    """YOKLUK: sessizlik fixture'ında seviye kapısı hiç açılmaz.
    İKİZ: çalan fixture'da açılır."""
    quiet = sum(1 for w in audio_windows("AF-002-room-noise-only")
                if w["level_above_room_floor_db"] >= 6)
    speak = sum(1 for w in audio_windows("AF-003-scale-with-metronome")
                if w["level_above_room_floor_db"] >= 6)
    return quiet, speak, "sessizlikte kapı açık", "çalarken kapı açık"


def twin_pitch_engine():
    """YOKLUK: oda gürültüsünde perde kestirilmez (O-017'nin koruduğu davranış).
    İKİZ: temiz notada kestirilir."""
    noise = json.loads((FIX / "AF-002-room-noise-only.json").read_text())
    clean = json.loads((FIX / "AF-001-clean-sustained-a4.json").read_text())
    quiet = sum(1 for w in noise["measured"]["windows"] if w["f0Hz"])
    speak = sum(1 for w in clean["measured"]["windows"] if w["f0Hz"])
    return quiet, speak, "gürültüde perde bulundu", "temiz notada perde bulundu"


def twin_timing_bias():
    """YOKLUK: kusursuz ızgarada zamanlama önyargısı 'centred' (yön yok).
    İKİZ: kaydırılmış varyantlarda yön RAPORLANIR."""
    d = json.loads((FIX / "AF-008-five-note-timing.json").read_text())
    m = d["measured"]
    quiet = sum(1 for k in ("perfect",) if m[k]["bias"] != "centred")
    speak = sum(1 for k in ("rushing", "dragging") if m[k]["bias"] != "centred")
    return quiet, speak, "kusursuzda yön iddiası", "kaydırılmışta yön iddiası"


def twin_gate_suite():
    """YOKLUK: temiz repoda hiçbir kapı kırmızı değil.
    İKİZ: mutasyon süpürmesinde kapılar kırmızı yanabiliyor (MUT-A)."""
    clean_red = 0 if subprocess.run(
        [sys.executable, "tools/validate_library.py"], capture_output=True).returncode == 0 else 1
    # İKİZ: TEK ucuz mutasyon yeter. Tüm MUT-A harness'ını buradan çağırmak
    # (13 mutasyon × ağır gözlem kapısı) ölçüm değil bekleme üretiyordu —
    # kendi kapı takımımı yavaşlatan iç içe maliyet. MUT-A ayrı bir tur.
    lib = json.loads(Path("assets/content/library.json").read_text(encoding="utf-8"))
    orig = json.dumps(lib, ensure_ascii=False, indent=1)
    lib["disciplines"][0]["honesty"]["notMeasured"] = ["-"]
    Path("assets/content/library.json").write_text(
        json.dumps(lib, ensure_ascii=False, indent=1), encoding="utf-8")
    try:
        speak = 1 if subprocess.run(
            [sys.executable, "tools/validate_library.py"],
            capture_output=True).returncode != 0 else 0
    finally:
        Path("assets/content/library.json").write_text(orig, encoding="utf-8")
    return clean_red, speak, "temiz repoda kırmızı kapı", "mutasyonda yanan kapı"


def twin_expert_flags():
    """YOKLUK: bayraksız (doğrulanmış) hata kodu sayısı 0.
    İKİZ: bayraklı kod sayısı > 0 — yani sayaç gerçekten sayıyor."""
    flagged = unflagged = 0
    for inst in ("guitar", "voice", "piano"):
        cfg = json.loads(Path(f"config/rulesets/{inst}@0.2.0-draft.json").read_text())
        for e in cfg.get("errors", []):
            if e.get("expertPending") or e.get("status") in ("aspirational", "thresholdPending"):
                flagged += 1
            else:
                unflagged += 1
    return unflagged, flagged, "bayraksız kod", "bayraklı kod"


PAIRS = [
    ("gözlem işareti kaynak-çelişmezliği", twin_observation_cue),
    ("ses güven kapısı (negatif fixture)", twin_audio_gate),
    ("seviye kapısı (sessizlik)", twin_level_gate),
    ("perde motoru (gürültü reddi)", twin_pitch_engine),
    ("zamanlama yön-önyargısı", twin_timing_bias),
    ("uzman-bayrağı sayacı", twin_expert_flags),
    ("kapı takımının kendisi (MUT-A)", twin_gate_suite),
]


def main():
    problems = []
    print("YOKLUK İDDİASI ↔ POZİTİF İKİZ (ikisi de gerçekten koşuldu)\n")
    for name, fn in PAIRS:
        quiet, speak, qlabel, slabel = fn()
        ok_quiet = quiet == 0
        ok_speak = speak > 0
        mark = "✅" if (ok_quiet and ok_speak) else "⛔"
        print(f"  {mark} {name}")
        print(f"       sessiz taraf: {qlabel} = {quiet}   (0 olmalı)")
        print(f"       İKİZ        : {slabel} = {speak}   (>0 olmalı)")
        if not ok_quiet:
            problems.append(f"{name}: yokluk iddiası TUTMUYOR ({qlabel}={quiet})")
        if not ok_speak:
            problems.append(
                f"{name}: İKİZ YOK — dedektörün konuşabildiği gösterilmedi "
                f"({slabel}={speak}). Hep-sessiz bir dedektör bu testi de geçerdi.")

    if problems:
        print(f"\n⛔ {len(problems)} SORUN:")
        for p in problems:
            print(f"   - {p}")
        return 1
    print(f"\n✅ {len(PAIRS)} yokluk iddiasının hepsi ikizli — her biri iki yönde ölçüldü")
    return 0


if __name__ == "__main__":
    sys.exit(main())
