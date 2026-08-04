#!/usr/bin/env python3
"""Postür eşiklerini REFERANS ARTEFAKTINDAN türet — ve config'in hâlâ o
artefaktla aynı şeyi söylediğini MEKANİK olarak sına.

Neden bu araç var
-----------------
Koordinatör direktifi (2026-08-04): "eşikler YALNIZ referans dispersiyonundan;
icat yasak." Bir sayıyı bir kez elle türetip config'e yazmak bu direktifi
YALNIZ YAZILDIĞI GÜN karşılar: referans yeniden üretildiğinde (MOCORE regen)
config sessizce bayatlar ve "ölçülmüş eşik" iddiası ölçümle bağını kaybeder —
bu, kendi defterimizde adı konmuş sınıf (bayat sayı, M-O-45 / "kendi
sınıflandırman bayatlayabilir").

Bu yüzden eşik burada TÜRETİLİR, config yalnız ALINTILAR, ve `--check`
her koşumda ikisinin eşit olduğunu sınar. Regen sonrası tek yapılacak:
bu betiği koşmak. Sessiz geçerse eşikler hâlâ ölçüme dayanıyor; kırmızı
yanarsa hangi sayının hangi yönde kaydığını adıyla söyler.

Türetilen merdiven (üç basamağın da kaynağı artefakt)
----------------------------------------------------
L1  agreementFloorDeg  = eğitmenler-arası dispersiyon medyanı (frames.dispersionRad)
    "Bu farkın altı sinyal değil: eğitmenlerin KENDİ aralarındaki fark."
L2  scoringToleranceDeg = clamp(dispersion, freeFloorDeg, freeCeilingDeg)
    Çekirdeğin skorlarken kullandığı bant. trunk_tilt'te dispersiyon tabanın
    ÇOK altında kaldığı için taban bağlar (`perJointSource: floor`) — yani
    eşik dispersiyon DEĞERİNDEN değil, "dispersiyonun tabana çarptığı
    ÖLÇÜMÜNDEN" gelir. Bu ayrım rapor edilir, gizlenmez (M-O-63).
L3  errorThresholdDeg  = gates.clusterToleranceDeg
    Anlaşma kapısının barı: iki take'in "aynı duruş" sayılması için izin
    verilen fark. Bunun ÖTESİ, hemfikir sayılan eğitmenlerin işgal ettiği
    aralığın dışıdır — hata koçluğunun savunulabilir en erken noktası.

Tolerans modeli DOĞRULANIR, varsayılmaz
---------------------------------------
Çekirdeğin tolerans kuralını burada yeniden kuruyoruz ve artefaktın KENDİ
`perJointSource`/`floorBoundShare` etiketleriyle karşılaştırıyoruz — dokuz
eklemin hepsinde. Model tutmuyorsa eşik türetimi de güvenilmez; o yüzden
uyuşmazlık HATA (sessiz devam değil).
"""
import json
import math
import sys
from pathlib import Path

REFS = {
    "guitar": "config/references/guitar-posture-setup.v1.json",
    "voice": "config/references/voice-posture-setup.v1.json",
    "piano": "config/references/piano-posture-setup.v1.json",
}
RULESET = "config/rulesets/{}@0.2.0-draft.json"

#: Artefaktın etiketiyle karşılaştırırken izin verilen pay. floorBoundShare bir
#: ORAN; kare-kare eşik civarında salınan eklemlerde birebir eşitlik beklemek
#: kayan-nokta hassasiyetini test etmek olurdu, tolerans modelini değil.
SHARE_TOLERANCE = 0.02


def median(xs):
    s = sorted(xs)
    n = len(s)
    return s[n // 2] if n % 2 else (s[n // 2 - 1] + s[n // 2]) / 2


def load_reference(path):
    d = json.loads(Path(path).read_text(encoding="utf-8"))
    joints = d["joints"]
    disp_deg = [[math.degrees(v) for v in frame] for frame in d["frames"]["dispersionRad"]]
    return d, joints, disp_deg


def tolerance_of(dispersion_deg, params):
    """Çekirdeğin kare-başına tolerans kuralı: dispersiyonu serbest bant
    içine kıstır. Taban, eğitmenlerin fazla hemfikir olduğu yerde bağlar —
    'çok dar bir bandı gerçek sanma' koruması."""
    return min(max(dispersion_deg, params["freeFloorDeg"]), params["freeCeilingDeg"])


#: Aile varsayılanı (M-F-143: 22° ÖZEL BARI KALDIRILDI, varsayılan 14.0 kullanılır).
#: ÜÇÜNCÜ ÇAPA — MUT-A bulgusu: artefaktın barını ve ona bağlı tüm config
#: değerlerini BİRLİKTE gevşetmek (14→30) hiçbir çelişki kapısına takılmıyordu,
#: çünkü her kaynak diğeriyle tutarlı kalıyor. Karşılaştırılacak bir DIŞ sabit
#: olmadan "eşik artefakttan geliyor" cümlesi, artefaktı düzenleyen herkese açık.
FAMILY_CLUSTER_TOLERANCE_DEG = 14.0


def verify_artifact_internals(ref):
    """Artefaktın KENDİ İÇİNDE tutarlı olduğunu sına — ÜÇÜNCÜ ÇAPA.

    MUT-A bulgusu: `result.contributingTakes` ile config'in `_derivedFrom`u
    BİRLİKTE şişirilince (6→40) çelişki kapısı susuyordu. Ama artefakt bu
    sayının ham malzemesini de taşıyor: `takes` dizisi ve `sources` listesi.
    Özet sayı, saydığı şeyle uyuşmak zorunda."""
    problems = []
    n_takes = len(ref.get("takes", []))
    if ref["result"]["contributingTakes"] != n_takes:
        problems.append(
            f"artefakt İÇ ÇELİŞKİ: result.contributingTakes="
            f"{ref['result']['contributingTakes']} ama takes dizisi {n_takes} öğe")
    n_sources = len(set(ref["result"].get("sources", [])))
    if ref["result"].get("distinctSources") != n_sources:
        problems.append(
            f"artefakt İÇ ÇELİŞKİ: result.distinctSources="
            f"{ref['result'].get('distinctSources')} ama sources listesinde "
            f"{n_sources} benzersiz ad")
    bar = ref["gates"]["clusterToleranceDeg"]
    if abs(bar - FAMILY_CLUSTER_TOLERANCE_DEG) > 1e-6 and not ref["gates"].get("clusterToleranceOverride"):
        problems.append(
            f"gates.clusterToleranceDeg={bar} aile varsayılanı "
            f"{FAMILY_CLUSTER_TOLERANCE_DEG}'dan farklı ve gerekçeli override "
            f"(`clusterToleranceOverride`) taşımıyor — M-F-143: özel bar "
            f"gerekçesiz kullanılamaz")
    thick = ref.get("evidenceThickness", {}).get("takes", {})
    missing = {t["id"] for t in ref.get("takes", [])} - set(thick)
    if missing:
        problems.append(f"evidenceThickness eksik take taşıyor: {sorted(missing)}")
    return problems


def verify_tolerance_model(ref, joints, disp_deg):
    """Modelimiz artefaktın kendi etiketlerini üretiyor mu? Dokuz eklemde sına."""
    params = ref["tolerance"]["params"]
    floor = params["freeFloorDeg"]
    problems = []
    for j, name in enumerate(joints):
        vals = [f[j] for f in disp_deg]
        computed_share = sum(1 for v in vals if v < floor) / len(vals)
        declared_share = ref["tolerance"]["floorBoundShare"][name]
        if abs(computed_share - declared_share) > SHARE_TOLERANCE:
            problems.append(
                f"{name}: floorBoundShare hesaplanan {computed_share:.3f} != "
                f"artefaktta beyan edilen {declared_share:.3f}")
        # perJointSource etiketi: çoğunluk hangi taraftaysa o.
        computed_source = "floor" if computed_share > 0.5 else "variance"
        declared_source = ref["tolerance"]["perJointSource"][name]
        if computed_source != declared_source:
            problems.append(
                f"{name}: perJointSource hesaplanan {computed_source!r} != "
                f"beyan edilen {declared_source!r}")
    return problems


def derive(instrument):
    ref, joints, disp_deg = load_reference(REFS[instrument])
    params = ref["tolerance"]["params"]
    scored = ref["jointAuthority"]["scored"]

    model_problems = verify_tolerance_model(ref, joints, disp_deg)
    model_problems += verify_artifact_internals(ref)

    per_joint = {}
    for j, name in enumerate(joints):
        vals = [f[j] for f in disp_deg]
        med = median(vals)
        per_joint[name] = {
            "dispersionMedianDeg": round(med, 2),
            "dispersionMaxDeg": round(max(vals), 2),
            "scoringToleranceDeg": round(tolerance_of(med, params), 1),
            "floorBound": med < params["freeFloorDeg"],
            "scored": name in scored,
            "unreliable": name in ref["result"].get("unreliableJoints", []),
        }

    ladder = {}
    for name in scored:
        pj = per_joint[name]
        ladder[name] = {
            "agreementFloorDeg": pj["dispersionMedianDeg"],
            "scoringToleranceDeg": pj["scoringToleranceDeg"],
            "errorThresholdDeg": ref["gates"]["clusterToleranceDeg"],
            "derivedFromFloor": pj["floorBound"],
        }

    return {
        "instrument": instrument,
        "artifact": REFS[instrument],
        "generatedAt": ref["generatedAt"],
        "contributingTakes": ref["result"]["contributingTakes"],
        "distinctSources": ref["result"]["distinctSources"],
        "params": params,
        "clusterToleranceDeg": ref["gates"]["clusterToleranceDeg"],
        "perJoint": per_joint,
        "ladder": ladder,
        "modelProblems": model_problems,
    }


def check_ruleset(d):
    """Config artefaktla aynı şeyi mi söylüyor? (regen sonrası bayatlık nöbeti)"""
    cfg = json.loads(Path(RULESET.format(d["instrument"])).read_text(encoding="utf-8"))
    problems = []
    for metric, lad in d["ladder"].items():
        m = cfg["metrics"].get(metric)
        if m is None:
            problems.append(f"metrics.{metric} YOK")
            continue
        # noiseBand = skorlama toleransı: bunun ALTINDA çizilen her çizgi,
        # çekirdeğin kendi bandının içinden hüküm çıkarmaya çalışır.
        if abs(m.get("noiseBand", -1) - lad["scoringToleranceDeg"]) > 1e-6:
            problems.append(
                f"metrics.{metric}.noiseBand={m.get('noiseBand')} != türetilen "
                f"scoringToleranceDeg={lad['scoringToleranceDeg']}")
        # DAYANAK da bayatlayabilir — üstelik değer doğruyken. Gitarın
        # gerekçesi '3 eğitmen, 0.54°' derken artefakt 7 take/2.24°'ye
        # büyümüştü ve noiseBand=8 her iki durumda da doğru olduğu için
        # değer kapısı bunu GEÇİRİYORDU. `_derivedFrom` o düzyazının
        # makine-okunur ikizi; burada artefaktla karşılaştırılır.
        prov = m.get("_derivedFrom")
        if prov is None:
            problems.append(f"metrics.{metric}._derivedFrom YOK — gerekçe "
                            f"makine-okunur ikiz taşımıyor, bayatlığı sınanamaz")
        else:
            pj = d["perJoint"][metric]
            for key, want in (("contributingTakes", d["contributingTakes"]),
                              ("generatedAt", d["generatedAt"]),
                              ("dispersionMedianDeg", pj["dispersionMedianDeg"]),
                              ("floorBoundShare", None)):
                if key == "floorBoundShare":
                    continue
                if prov.get(key) != want:
                    problems.append(
                        f"metrics.{metric}._derivedFrom.{key}={prov.get(key)!r} != "
                        f"artefakt {want!r} — GEREKÇE BAYAT (değer doğru olsa bile)")
        # Faz quality barları toleransın altına inemez.
        for tech in cfg.get("techniques", []):
            for ph in tech.get("phases", []):
                q = ph.get("quality", {}).get(metric)
                if not q or q.get("op") != "lte":
                    continue
                if q["value"] < lad["scoringToleranceDeg"]:
                    problems.append(
                        f"{tech['id']}/{ph['id']}.quality.{metric} <= {q['value']} "
                        f"ölçüm bandının ({lad['scoringToleranceDeg']}°) ALTINDA — "
                        f"gürültüden ince çizgi çekiyor")
                # Tutarlılık: quality barı hata eşiğini AŞARSA, arada hatanın
                # ateşlediği ama kalitenin GEÇTİĞİ bir bant doğar — kullanıcı
                # aynı karede hem "iyi" hem "hatalı" olur. Merdivenin sırası
                # bozulamaz: tolerans <= quality <= hata-eşiği.
                elif q["value"] > lad["errorThresholdDeg"]:
                    problems.append(
                        f"{tech['id']}/{ph['id']}.quality.{metric} <= {q['value']} "
                        f"hata eşiğinin ({lad['errorThresholdDeg']}°) ÜSTÜNDE — "
                        f"hata ateşlerken kalite geçiyor (çelişkili hüküm bandı)")
        # Bu metriğe bağlı hata kodları anlaşma barından türemeli.
        for e in cfg.get("errors", []):
            cond = e.get("condition") or {}
            if cond.get("metric") != metric or cond.get("op") != "gt":
                continue
            if abs(cond["value"] - lad["errorThresholdDeg"]) > 1e-6:
                problems.append(
                    f"errors.{e['code']} eşiği {cond['value']} != türetilen "
                    f"errorThresholdDeg={lad['errorThresholdDeg']} "
                    f"(gates.clusterToleranceDeg)")
    return problems


def main():
    check = "--check" in sys.argv
    emit = "--json" in sys.argv
    all_problems = []
    out = {}

    for inst in REFS:
        d = derive(inst)
        out[inst] = d
        if emit:
            continue
        print(f"=== {inst} === ({d['contributingTakes']} take · "
              f"{d['distinctSources']} kaynak · {d['generatedAt'][:10]})")
        if d["modelProblems"]:
            print("  ⛔ TOLERANS MODELİ ARTEFAKTLA UYUŞMUYOR:")
            for p in d["modelProblems"]:
                print(f"     - {p}")
        for name, pj in d["perJoint"].items():
            tag = "SKORLANAN" if pj["scored"] else ("güvenilmez" if pj["unreliable"] else "coached")
            print(f"  {name:17s} disp={pj['dispersionMedianDeg']:6.2f}°  "
                  f"tolerans={pj['scoringToleranceDeg']:5.1f}°  "
                  f"{'[taban]' if pj['floorBound'] else '[varyans]'}  {tag}")
        for metric, lad in d["ladder"].items():
            print(f"  → {metric} MERDİVENİ: anlaşma-tabanı {lad['agreementFloorDeg']}° · "
                  f"skorlama-toleransı {lad['scoringToleranceDeg']}° · "
                  f"hata-eşiği {lad['errorThresholdDeg']}°"
                  f"{'  (tolerans DİSPERSİYONDAN DEĞİL TABANDAN geliyor — M-O-63)' if lad['derivedFromFloor'] else ''}")
        print()
        all_problems += [f"{inst}: {p}" for p in d["modelProblems"]]

        if check:
            for p in check_ruleset(d):
                all_problems.append(f"{inst}: {p}")

    if emit:
        print(json.dumps(out, ensure_ascii=False, indent=1))
        return 0

    if all_problems:
        print(f"⛔ {len(all_problems)} UYUŞMAZLIK:")
        for p in all_problems:
            print(f"   - {p}")
        return 1
    print("✅ tolerans modeli artefakta uyuyor" + (" · config türetilen eşiklerle EŞİT" if check else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main())
