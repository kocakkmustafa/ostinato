#!/usr/bin/env python3
"""Kaynak ruleset'ten v0.4.0 OKUYUCUSUNUN kabul ettiği alt-kümeyi üretir.

Kaynak dosya (`config/rulesets/*.json`) mühürlü ŞEMA'ya göre yazılmıştır ve
tek doğruluk kaynağıdır. Okuyucu şu an şemanın bazı yapılarını tanımıyor;
bu betik farkı GÖRÜNÜR kılar — sessizce kırpmaz, düşürdüğü her alanı raporlar.
"""
import json, sys, pathlib

READER_TECHNIQUE = {"id","sideResolution","phases","limb","cyclic","repCompletedOn",
                    "resetBetweenReps","fallback","requiredLandmarks","requiredSignals",
                    # v0.4.1: şema kazandı — okuyucu bu üçünü artık tanıyor
                    "requires","verdictGates",
                    "errors","$doc"}
READER_PHASE = {"id","enter","quality","exit","abort","abortCode","timeoutMs","minDurationMs",
                "measureHere","terminal","checkpoint","skippableIn","requiredLandmarks","requiredSignals","$doc"}
READER_METRIC = {"unit","range","noiseBand","baseline","interval","cutoffHz",
                 "measurementSpace",  # v0.4.1 (M-O-08 kararı beyan edilebilir)
                 "$doc"}
READER_ERROR = {"code","evaluateAt","condition","priority","perturbation","cooldownMs",
                "maxPerRound","suppressesJudgement","drillId","$doc"}

def strip(obj, allowed, path, dropped):
    out = {}
    for k, v in obj.items():
        if k.startswith("_"):
            continue                     # bizim yorum sözleşmemiz
        if k in allowed:
            out[k] = v
        else:
            dropped.append(f"{path}.{k}")
    return out

def main(src, dst):
    d = json.loads(pathlib.Path(src).read_text(encoding="utf-8"))
    dropped, notes = [], []
    out = {"schemaVersion": "3.0", "metrics": {}, "techniques": []}

    for k in d:
        if k in ("metrics", "techniques") or k.startswith("_"):
            continue
        dropped.append(f"config.{k}")

    for mid, m in d["metrics"].items():
        if m.get("inV1Scope") is False:
            notes.append(f"metric {mid}: kapsam-dışı, okuyucu config'ine alınmadı")
            continue
        mm = strip(m, READER_METRIC | {"id"}, f"metrics.{mid}", dropped)
        mm.pop("id", None)
        if mm.get("baseline") is None:
            mm["baseline"] = 0
        out["metrics"][mid] = mm

    for t in d["techniques"]:
        tt = strip(t, READER_TECHNIQUE | {"verdictGates","requires"}, f"technique.{t['id']}", dropped)
        # şema `requires:{signals}` diyor; okuyucu düz `requiredSignals` istiyor
        # v0.4.1'den beri requires/verdictGates olduğu gibi geçiyor (düzleştirme
        # ve düşürme kaldırıldı); yorum anahtarları yine temizleniyor.
        if isinstance(tt.get("verdictGates"), list):
            tt["verdictGates"] = [{k: v for k, v in g.items() if not k.startswith("_")}
                                  for g in tt["verdictGates"]]
        tt["phases"] = [strip(p, READER_PHASE, f"technique.{t['id']}.phase.{p['id']}", dropped)
                        for p in t["phases"]]
        for p in tt["phases"]:
            # Okuyucunun `quality`si Map<String,double> — çıplak sayı. Şemadaki
            # {op, value} biçimi YÖN taşıyor ("≤25 cent" vs "≥0,7 periyodiklik");
            # düzleştirince o bilgi kayboluyor. Değeri geçiriyoruz ama kaybı
            # rapora yazıyoruz (M-O-10).
            q = p.get("quality")
            if q:
                p["quality"] = {}
                for mid, spec in q.items():
                    if isinstance(spec, dict):
                        p["quality"][mid] = spec.get("value")
                        if "op" in spec:
                            notes.append(f"quality {mid}: op='{spec['op']}' KAYBOLDU "
                                         f"(okuyucu çıplak sayı alıyor; yön bilgisi taşınamıyor)")
                    else:
                        p["quality"][mid] = spec
        errs = []
        for e in d.get("errors", []):
            ee = strip(e, READER_ERROR, f"error.{e['code']}", dropped)
            ee.setdefault("priority", "quality")   # okuyucu ZORUNLU tutuyor, şema listelemiyor
            # Şema §3 `evaluateAt: ANY | <faz-id> | COMBINATION_END | <işaret>`
            # diyor (düz değer). Okuyucu M-J-05.1 işaret taksonomisini
            # uyguluyor: {kind: phase|combinationEnd|periodic|appEvent, ...}.
            ea = ee.get("evaluateAt")
            if isinstance(ea, str):
                ee["evaluateAt"] = ({"kind": "appEvent", "event": "any"} if ea == "ANY"
                                    else {"kind": "phase", "phaseId": ea})
                notes.append(f"error {ee['code']}: evaluateAt '{ea}' -> işaret nesnesine çevrildi "
                             f"(şema düz değer gösteriyor, okuyucu taksonomi nesnesi istiyor)")
            errs.append(ee)
        if errs:
            tt["errors"] = errs
        out["techniques"].append(tt)

    pathlib.Path(dst).write_text(json.dumps(out, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"yazıldı: {dst}")
    if dropped:
        print(f"\nDÜŞÜRÜLEN ALANLAR ({len(dropped)}):")
        for x in sorted(set(dropped)): print("  -", x)
    if notes:
        print("\nDÖNÜŞÜM NOTLARI:")
        for n in notes: print("  *", n)

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
