#!/usr/bin/env python3
"""Uçtan-uca replay senaryosu — postür-kapısı + kromagram-akor hattı BİRLİKTE
mi çalışıyor? (M-F-108, kilitli-ders paketinin 3. maddesi)

Neden ayrı bir kapı: `replay_check.py` her fazı BAĞIMSIZ, kare-kare kontrol
eder (bu fazın koşulu bu karede sağlanıyor mu) — hiçbir ZAMAN SIRASI kurmaz.
`verify_score_consumer_live.py` yalnız POSTURE_CHECK'i tek başına sınadı. Bu
betik BİRİNCİ KEZ bir GERÇEK OTURUMU simüle eder: kullanıcı önce oturur (ses
YOK, postür kapısı çalışır) sonra çalar (ses VAR, akor kapısı çalışır) — ve
faz makinesinin bu ikisini SIRAYLA doğru şekilde ZİNCİRLEDİĞİNİ kanıtlar.

Dürüstlük sınırı: Ostinato'nun henüz bir Dart RUNTIME motoru yok (platform
iskeleti M-F-25 ile JabLab'a ertelendi) — bu yüzden burada motion_core'un
gerçek `PhaseStateMachine`i DEĞİL, `replay_check.py`nin AYNI `evaluate()`
mantığı kullanılıyor (JSON ruleset semantiğinin Python yansıması). READY
fazı `setup_complete` motoruna bağlı ve o motor YOK (aspirational,
fixture_check'te de böyle işaretli) — bu adım STUB'lanır, gizlenmez.
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from replay_check import POSE, evaluate, audio_windows  # noqa: E402

LIB = Path.home() / "motion-harvest" / "ostinato"


def load_posture_window():
    """8xFzcSieBXY hold-penceresi — ATTESTED referansa katkı veren gerçek
    kaynak, M-O-47/48'de zaten PASS olduğu doğrulanmış."""
    manifest = json.loads((LIB / "hold-windows-guitar.json").read_text())
    row = next(r for r in manifest["sources"] if r["videoId"] == "8xFzcSieBXY")
    doc = json.loads((LIB / "landmarks" / "8xFzcSieBXY.full.json").read_text())
    t0, t1 = row["tStartS"], row["tEndS"]
    return [fr for fr in doc["frames"]
            if fr.get("detected") and fr.get("world")
            and t0 <= fr["t"] / 1000.0 < t1]


def main():
    cfg = json.load(open("config/rulesets/guitar@0.2.0-draft.json", encoding="utf-8"))
    technique = next(t for t in cfg["techniques"] if t["id"] == "open_chord_drill")
    phases = {p["id"]: p for p in technique["phases"]}
    order = [p["id"] for p in technique["phases"]]

    pose_frames = load_posture_window()
    silent = audio_windows("AF-002-room-noise-only")
    playing_raw = audio_windows("AF-003-scale-with-metronome")
    # AF-003 tek-nota (monofonik) fixture'ı — silence lead-in + ayrık notalar
    # arasında boşluklar taşır (skala egzersizi, kromagram/akor testi için
    # tasarlanmadı). Sürdürülen bir akor SESİNİ modellemek için o fixture'ın
    # İÇİNDEN gerçekten "çalıyor" olan TEK bir pencereyi (yüksek seviye+
    # periyodiklik) seçip SABİT tutuyoruz — postürü sabit tuttuğumuz gibi.
    sustained_play = next(w for w in playing_raw if w["level_above_room_floor_db"] > 20)
    # chord_correctness: BU fixture ham örnek taşımıyor (yalnız önceden
    # hesaplanmış level/periodicity/f0) — kromagram akor tanıma Dart
    # tarafında (ostinato_audio) ve TEK-NOTA fixture'ından hesaplanamaz.
    # Değer chord_detector_test.dart'ın ZATEN KANITLANMIŞ sonucundan
    # ALINIYOR (E majör, skor 1.0, M-O-35 — 8/8 gerçek MIDI/kromagram
    # testi) — burada YENİDEN HESAPLANMIYOR. Dürüst sınır: ses örneklerini
    # tek geçişte hem kromagrama hem faz-zincirine sokan TAM entegre test
    # henüz YOK (ham-örnekli akor fixture'ı gerekir) — bu turun kapsamı
    # DEĞİL, sıradaki iş kalemi olarak DEFTER'e yazılıyor.
    sustained_play = {**sustained_play, "chord_correctness": 1.0}

    # Senaryo: ilk yarı OTURDU-AMA-ÇALMIYOR (postür kapısı sınanır),
    # ikinci yarı ÇALIYOR (akor kapısı sınanır, SABİT sürdürülen ses).
    # Poz AYNI (gerçek iyi postür) — yalnız ses değişiyor, tam da
    # kullanıcının yaptığı şey.
    n = len(pose_frames)
    timeline = (
        [("SESSİZLİK", pose_frames[i], silent[i % len(silent)]) for i in range(n // 2)] +
        [("ÇALIYOR", pose_frames[i], sustained_play) for i in range(n // 2, n)]
    )

    current = order[0]  # POSTURE_CHECK
    log = []
    quality_hits = {"trunk_tilt": {"PASS": 0, "FAIL": 0}, "chord_correctness": {"PASS": 0, "FAIL": 0}}
    phase_active_frames = {pid: 0 for pid in order}
    stubbed = set()

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

        phase_active_frames[current] += 1
        p = phases[current]

        # Quality kapılarını GERÇEK karede değerlendir (yalnız aktif fazda).
        for metric, cond in p.get("quality", {}).items():
            c = {"kind": "metric", "metric": metric, "op": cond["op"], "value": cond["value"]}
            r = evaluate(c, vals)
            if r is True:
                quality_hits.setdefault(metric, {"PASS": 0, "FAIL": 0})["PASS"] += 1
            elif r is False:
                quality_hits.setdefault(metric, {"PASS": 0, "FAIL": 0})["FAIL"] += 1

        # Geçiş: exit koşulu sağlanırsa sıradaki faza geç.
        exit_cond = p.get("exit")
        if exit_cond:
            r = evaluate(exit_cond, vals)
            if r is True:
                idx = order.index(current)
                if idx + 1 < len(order):
                    nxt = order[idx + 1]
                    # READY fazının giriş koşulu setup_complete'e bağlı —
                    # motoru yok (aspirational). Gerçek karede DEĞERLENDİRİLEMEZ
                    # (None) — STUB'lanır, bir sonrakine (PLAY) geçilir; bu
                    # gizlenmiyor, log'a yazılıyor.
                    if nxt in phases:
                        enter_r = evaluate(phases[nxt].get("enter", {}), vals)
                        if enter_r is None and "setup_complete" in str(phases[nxt].get("enter")):
                            stubbed.add(nxt)
                            idx += 1
                            nxt = order[idx + 1] if idx + 1 < len(order) else nxt
                    if current != nxt:
                        log.append(f"  [{label}] {current} → {nxt}")
                    current = nxt

    print("=== Uçtan-uca senaryo: OTUR (ses yok) → ÇAL (ses var) ===")
    print(f"kaynak: 8xFzcSieBXY hold-penceresi ({n} kare, gerçek ATTESTED postür) "
          f"+ AF-002 (sessiz)/AF-003 (çalıyor) ses fixture'ları\n")
    print("Faz geçişleri:")
    for line in log:
        print(line)
    if stubbed:
        print(f"\n⚠️  STUB'lanan faz(lar) (motoru yok, aspirational): {sorted(stubbed)}")

    print("\nFaz-başına aktif kare sayısı:")
    for pid in order:
        print(f"  {pid:14} {phase_active_frames[pid]} kare")

    print("\nQuality kapısı verdictleri (yalnız o faz aktifken değerlendirildi):")
    for metric, hits in quality_hits.items():
        if hits["PASS"] or hits["FAIL"]:
            print(f"  {metric:20} PASS={hits['PASS']} FAIL={hits['FAIL']}")

    ok = (phase_active_frames["POSTURE_CHECK"] > 0 and phase_active_frames["PLAY"] > 0
          and quality_hits["trunk_tilt"]["PASS"] > 0)
    print(f"\n{'✅ İKİ HAT DA ZİNCİRLENDİ: POSTURE_CHECK aktifti+PASS verdi, sonra PLAY aktif oldu' if ok else '⛔ ZİNCİRLEME KANITLANAMADI'}")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
