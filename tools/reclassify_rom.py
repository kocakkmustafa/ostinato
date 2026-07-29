#!/usr/bin/env python3
"""Hasat edilmiş kaynakları M-F-43 uygunluk kapısı için YENİDEN sınıflandırır.

Neden gerekti: hasadı `--no-transcribe` ile koştum. Sınıflandırıcı kararını
kaynağın ANLATISINDAN verir (rom_mode.py: "ayrım kamerada görünmez, yalnız
kaynağın kendi anlatısında vardır") — transkripti kesince elinde yalnız
başlık/açıklama kaldı ve fail-closed gereği neredeyse her şey `unknown`
çıktı. 44 fixture'ın yalnız 2'si referansa uygun; yani B4 pilotunun ürettiği
tüm dağılım/tolerans sayıları referans-dışı kaynaklardan geliyordu. Pilot da
bu bayrağı hiç okumuyordu (O-022).

Neden video yeniden indirilmiyor: sınıflandırma tamamen METİN üzerinde
çalışır. `raw/*.info.json` başlık+açıklamayı zaten taşıyor; eksik olan yalnız
transkript ve o da yerel ses dosyasından çıkarılabiliyor.

Neden rig'in `classify`ı çağrılıyor, kopyası yazılmıyor: sınıflandırma
kuralları aile malı (M-F-43/45). Buraya kopyalasam iki kural seti oluşur ve
ayrıştıklarında hangisinin doğru olduğu tartışılır.

Çıktı: `~/motion-harvest/ostinato/rom-eligibility.json` — kaynak-başına karar,
dayanağı (hangi metin görüldü, hangi işaret bulundu) ve politika ile birlikte.
Karar değil, kararın GEREKÇESİ saklanır: "neden uygun değil" sorusu sonra
sorulacak.
"""
import json
import os
import sys
from pathlib import Path

RIG = Path("/Users/mustafakaankocak/motion-worktrees/ostinato-hold-isolator/tools/harvest_rig")  # M-F-22: paylaşılan ağaç başka dalda; izole worktree
sys.path.insert(0, str(RIG))
from rom_mode import classify  # noqa: E402  (yol enjeksiyonundan sonra)

LIB = Path(os.path.expanduser("~/motion-harvest/ostinato"))
#: B4 pilotunun kullandığı pencere "en durağan 3 sn" — yani ÇALMA değil
#: KURULUM DURUŞU. Politikamızda `posture_setup` kasıtlı olarak
#: passiveExecutionPossible=True: öğretmenin öğrencinin bileğini yerleştirmesi
#: gerçek bir öğretim hamlesi ve öyle üretilen duruş ulaşılamaz hedef olabilir.
#: Yani bu kaynaklar muafiyetle DEĞİL kanıtla geçmeli.
MOVEMENT = "posture_setup"


def transcript_text(vid):
    p = LIB / "transcripts" / f"{vid}.transcript.json"
    if not p.exists():
        return None
    d = json.loads(p.read_text(encoding="utf-8"))
    if isinstance(d, dict):
        if isinstance(d.get("text"), str):
            return d["text"]
        segs = d.get("segments") or []
        return " ".join(s.get("text", "") for s in segs)
    return " ".join(s.get("text", "") for s in d) if isinstance(d, list) else None


def main():
    profile = json.loads(Path("config/triage/piano.json").read_text(encoding="utf-8"))
    policy = profile["movementRomPolicy"]
    if MOVEMENT not in policy:
        raise SystemExit(f"movementRomPolicy'de '{MOVEMENT}' yok — beyan edilmemiş hareket "
                         f"için sınıflandırma yapılmaz (sessiz varsayılan kuralın kendisini iptal eder)")
    pep = bool(policy[MOVEMENT])

    imap = json.loads(Path("config/fixture-instrument-map.json").read_text(encoding="utf-8"))
    rows, missing_transcript = [], []

    for f in sorted((LIB / "landmarks").glob("*.json")):
        vid = f.name.split(".")[0]
        info = LIB / "raw" / f"{vid}.info.json"
        meta = json.loads(info.read_text(encoding="utf-8")) if info.exists() else {}
        text = transcript_text(vid)
        if text is None:
            missing_transcript.append(vid)

        v = classify(title=meta.get("title", "") or "",
                     description=meta.get("description", "") or "",
                     transcript=text or "",
                     passive_execution_possible=pep)
        rows.append({
            "videoId": vid,
            "instrument": imap.get(vid),
            "movement": MOVEMENT,
            "passiveExecutionPossible": pep,
            "romMode": v.mode,
            "referenceEligible": v.reference_eligible,
            "activeHits": v.active_hits,
            "passiveHits": v.passive_hits,
            "sourcesSeen": v.sources_seen,
            "reason": v.reason,
            "hasTranscript": text is not None,
        })

    out = LIB / "rom-eligibility.json"
    out.write_text(json.dumps({
        "$why": "M-F-43 uygunluk kararı + DAYANAĞI. Pilot bunu okur; karar tek başına "
                "taşınırsa 'neden uygun değil' sorusu cevapsız kalır.",
        "movement": MOVEMENT,
        "policySource": "config/triage/piano.json → movementRomPolicy (tek kaynak: "
                        "config/triage-thresholds.w1.json)",
        "passiveExecutionPossible": pep,
        "sources": rows,
    }, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")

    # Sidecar tek başına YETMEZ: pilot (ve çekirdeğin `eligibilityOf`u)
    # kararı fixture'ın KENDİ provenance'ından okur. Sidecar'da bırakırsam
    # yeniden sınıflandırma hiçbir tüketiciye ulaşmaz — "kapıya soran var mı"
    # sorusunun bir başka hâli. `--write` kararı kaynağa geri yazar; rig
    # transkriptle koşsaydı zaten oraya yazacaktı, aynı sınıflandırıcı, aynı
    # politika. Yeniden yazıldığı GÖRÜNÜR kalsın diye damga da düşülür.
    if "--write" in sys.argv:
        for r in rows:
            f = next((LIB / "landmarks").glob(f"{r['videoId']}.*json"), None)
            if not f:
                continue
            doc = json.loads(f.read_text(encoding="utf-8"))
            prov = doc.setdefault("provenance", {})
            prov["referenceEligible"] = r["referenceEligible"]
            prov["romMode"] = r["romMode"]
            prov["romReclassified"] = {
                "by": "tools/reclassify_rom.py",
                "movement": MOVEMENT,
                "passiveExecutionPossible": pep,
                "evidence": r["sourcesSeen"],
                "activeHits": r["activeHits"],
                "passiveHits": r["passiveHits"],
                "why": "ilk hasat --no-transcribe koştu; sınıflandırıcı anlatıyı görmemişti",
            }
            f.write_text(json.dumps(doc, ensure_ascii=False), encoding="utf-8")
        print(f"↻ {len(rows)} fixture provenance'ı güncellendi (--write)")

    elig = [r for r in rows if r["referenceEligible"]]
    from collections import Counter
    print(f"kaynak: {len(rows)} · transkriptli: {sum(r['hasTranscript'] for r in rows)} "
          f"· transkriptsiz: {len(missing_transcript)}")
    print("romMode:", dict(Counter(r["romMode"] for r in rows)))
    print(f"referansa UYGUN: {len(elig)}/{len(rows)}")
    per = Counter(r["instrument"] for r in elig)
    tot = Counter(r["instrument"] for r in rows)
    for inst in ("voice", "guitar", "piano"):
        print(f"  {inst:8} uygun {per[inst]:3} / {tot[inst]:3}")
    if missing_transcript:
        print(f"\n⚠️ {len(missing_transcript)} kaynağın transkripti YOK — kararları "
              f"yalnız başlık/açıklamaya dayanıyor (kanıt zayıf, fail-closed sürüyor).")
    print(f"\nyazıldı: {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
