#!/usr/bin/env python3
"""Canlı ses yüzeyinin sözleşme varlığını ÜRET — `assets/config/audio-contract.json`.

`tools/gen_posture_contract.py`nin ses karşılığı — AYNI gerekçe: kabuğun
gösterdiği/karşılaştırdığı her sayı ruleset'e bağlı kalmalı, elle
kopyalanmış bir sayı regen sonrası sessizce bayatlar.

FARK: posture'ınki HAM per-kare eğitmen verisinden İSTATİSTİK türetiyor
(medyan dispersiyon, bant). Bu script yalnız ruleset'te ZATEN yazılı olan
skaler değerleri (chord_correctness eşiği, faz zaman aşımları, YIN/onset
sinyal-koşullandırma parametreleri) İSİMLE eşleştirerek çıkarır — hesaplama
YOK, yalnız çıkarma. Yine de ELLE kopyalanmıyor: ruleset "TASLAK" (alan
adları mühürlenmeden önce değişebilir) — Python'ın KeyError'ı, bir alan
adı kayarsa derleme-zamanında/koşum-zamanında GÜRÜLTÜLÜ durur; Dart'ta
ham JSON'u index/isimle gezinen kırılgan bir okuma, sessizce yanlış
değer okurdu.

Bu turda YALNIZ guitar (`open_chord_drill`) — en olgun/en çok kanıtlı motor
(OST-P0-003, 3 bağımsız GuitarSet take, 34 fixture). voice
(`sustained_note_drill`, pitch_deviation_cents+periodicity) ve piano
(`five_finger_drill`, PLAY fazının HENÜZ hiçbir quality bloğu yok — ruleset
kendisi expertPending/ölçülmemiş) SONRAKİ bir dilim, adıyla açık bırakıldı.

`--check` modu: varlık ruleset'le hâlâ aynı şeyi söylüyor mu?
"""
import json, sys
from pathlib import Path

OUT = Path("assets/config/audio-contract.json")


def _phase(techniques, technique_id, phase_id):
    tech = next(t for t in techniques if t["id"] == technique_id)
    return next(p for p in tech["phases"] if p["id"] == phase_id)


def build():
    cfg = json.loads(Path("config/rulesets/guitar@0.2.0-draft.json").read_text(encoding="utf-8"))
    sc = cfg["signalConditioning"]
    play = _phase(cfg["techniques"], "open_chord_drill", "PLAY")
    onset_gate = next(
        g for g in cfg["techniques"][0]["verdictGates"] if g["onEvent"] == "onset"
    )

    guitar = {
        "chordCorrectnessThreshold": play["quality"]["chord_correctness"]["value"],
        "levelAboveRoomFloorDbThreshold": play["enter"]["value"],
        "playTimeoutMs": play["timeoutMs"],
        "playMinDurationMs": play["minDurationMs"],
        "onsetNoVerdictHoldMs": onset_gate["holdMs"],
        "pitchWindowMs": sc["pitchWindowMs"],
        "pitchHopMs": sc["pitchHopMs"],
        "yinThreshold": sc["yinThreshold"],
        "onsetFrameMs": sc["onsetFrameMs"],
        "onsetHopMs": sc["onsetHopMs"],
        "onsetMedianWindow": sc["onsetMedianWindow"],
        "onsetBandCount": sc["onsetBandCount"],
        "onsetMinAnalysisHz": sc["onsetMinAnalysisHz"],
        "onsetMaxAnalysisHz": sc["onsetMaxAnalysisHz"],
        "_derivedFrom": {
            "ruleset": "config/rulesets/guitar@0.2.0-draft.json",
            "rulesetVersion": cfg["version"],
            "technique": "open_chord_drill",
        },
    }
    # PLAY.enter ve PLAY.exit AYNI eşiği (6dB) farklı yönde (gte/lt) kullanıyor
    # — ruleset'in KENDİ tutarlılığını doğrula, sessizce varsaymadan.
    exit_value = play["exit"]["value"]
    if exit_value != guitar["levelAboveRoomFloorDbThreshold"]:
        raise SystemExit(
            f"⛔ PLAY.enter ({guitar['levelAboveRoomFloorDbThreshold']}) != "
            f"PLAY.exit ({exit_value}) — ruleset'in kendi eşiği TUTARSIZ, "
            "varsayılan tek-eşik modeli GEÇERSİZ, script'i güncelle."
        )
    return {"guitar": guitar}


def main():
    built = build()
    if "--check" in sys.argv:
        if not OUT.exists():
            print(f"⛔ {OUT} YOK — `python3 tools/gen_audio_contract.py` koştur")
            return 1
        cur = json.loads(OUT.read_text(encoding="utf-8"))
        if cur != built:
            print(f"⛔ ses sözleşme varlığı BAYAT: ruleset'le uyuşmuyor. "
                  f"`python3 tools/gen_audio_contract.py` ile yeniden üret.")
            for k in built["guitar"]:
                if cur.get("guitar", {}).get(k) != built["guitar"][k]:
                    print(f"   guitar.{k}: varlık {cur.get('guitar',{}).get(k)!r} != "
                          f"ruleset {built['guitar'][k]!r}")
            return 1
        print("✅ ses sözleşme varlığı ruleset'le EŞİT "
              f"(guitar: chord≥{built['guitar']['chordCorrectnessThreshold']}, "
              f"yinThreshold={built['guitar']['yinThreshold']})")
        return 0
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(built, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"✅ {OUT} üretildi")
    g = built["guitar"]
    print(f"   guitar: chord_correctness≥{g['chordCorrectnessThreshold']} · "
          f"level≥{g['levelAboveRoomFloorDbThreshold']}dB · "
          f"playTimeout={g['playTimeoutMs']}ms · yinThreshold={g['yinThreshold']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
