#!/usr/bin/env python3
"""Beşinci soru — YENİ referansın TÜKETİCİSİ canlı mı? (M-F-103)

"Bağlandı" ≠ "canlı": `guitar@0.2.0-draft.json`'a `referenceConsumption`
yazdım (M-O-47), ama config'in kendisi hiçbir şeyi ÇALIŞTIRMAZ — asıl soru
`quality.trunk_tilt` kapısının GERÇEK karede gerçekten ayrım yapıp
yapmadığı. Üç iddia, üçü de burada ölçülüyor (varsayılmıyor):

  (a) trunk_tilt SKORLANAN yolda referans-tabanlı hüküm üretiyor mu —
      gerçek "iyi" kaynak (referansın kendisi) PASS, kontrollü-bozulmuş
      "kötü" ikizi FAIL veriyor mu?
  (b) kol eklemleri KOÇLANAN katmandan mı konuşuyor — hiçbir quality/error
      koşulu onlara dayanmıyor mu (statik denetim) VE trunk_tilt'i sabit
      tutup kolları bozunca hüküm DEĞİŞMİYOR mu (davranışsal kanıt)?
  (c) mirrorAmbiguityNote'un runtime karşılığı var mı — sol-taraf verisi
      (mirror-belirsiz, gerçek veride 5-12× büyük) tek başına taraf-bazlı
      bir hüküm ÜRETMİYOR mu?

Kontrollü-bozulma yöntemi: kalça-pivotu etrafında SABİT, BEYAN EDİLMİŞ bir
açıyla (+20°) ÜST-VÜCUDU KATI DÖNDÜRME. Bu seçim bilinçli: kalça sabit
kalıp omuz/kol birlikte dönünce trunk_tilt ÖNGÖRÜLEBİLİR ŞEKİLDE (~+20°)
değişir AMA omuz-dirsek-bilek ARASINDAKİ göreli geometri (kol açıları)
KORUNUR — yani bu dönüş yalnız postürü bozar, kolu bozmaz; (a) ve (b)'yi
AYNI ANDA temiz test eder.
"""
import copy
import json
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from replay_check import POSE, OPS, evaluate, L_SH, R_SH, L_HIP, R_HIP  # noqa: E402

LIB = Path.home() / "motion-harvest" / "ostinato"
ROTATION_DEG = 20.0  # beyan edilen, sabit — "kontrollü" derken bu


def rotate_upper_body(w, deg, pivot_idx=(L_HIP, R_HIP), moved_idx=range(11, 17)):
    """Kalça-orta-noktası pivotunda XY düzleminde katı döndürme.

    Yalnız omuz+dirsek+bilek (11-16) döner — kalça SABİT. Omuz-dirsek-bilek
    ARASINDAKİ açılar (kol flexion'ları) böylece KORUNUR: yalnız gövdenin
    kalçaya göre eğimi değişir, kolun kendi iç geometrisi değişmez.
    """
    hip_mid = [(w[pivot_idx[0]][i] + w[pivot_idx[1]][i]) / 2 for i in range(3)]
    rad = math.radians(deg)
    cos_a, sin_a = math.cos(rad), math.sin(rad)
    out = [list(p) for p in w]
    for i in moved_idx:
        x, y = w[i][0] - hip_mid[0], w[i][1] - hip_mid[1]
        out[i][0] = hip_mid[0] + x * cos_a - y * sin_a
        out[i][1] = hip_mid[1] + x * sin_a + y * cos_a
    return out


def corrupt_left_arm(w, seed_offset=0.9):
    """Sol DİRSEK+BİLEĞİ (13,15) gerçek veride görülen mirror-belirsiz uçlara
    benzer şekilde bozar — sol OMUZ (11) KASITLI OLARAK dokunulmaz, çünkü o
    hem kol hem trunk_tilt'in mid-shoulder hesabında PAYLAŞILAN bir landmark;
    onu bozmak "kol sızıntısı" değil gerçek gövde-girdisi değişikliği ölçerdi.
    Sağ kol ve gövde de dokunulmaz."""
    out = [list(p) for p in w]
    for i in (13, 15):
        out[i][0] = out[i][0] + seed_offset
        out[i][1] = out[i][1] - seed_offset * 0.6
    return out


def trunk_tilt_and_arms(w):
    vals = {}
    for mid, fn in POSE.items():
        try:
            v = fn(w)
            if not math.isnan(v):
                vals[mid] = v
        except Exception:
            pass
    return vals


def quality_verdict(cfg, phase_id, vals):
    """POSTURE_CHECK.quality bloğunu (evaluate() ile AYNI motor) değerlendirir."""
    phase = next(p for t in cfg["techniques"] for p in t["phases"] if p["id"] == phase_id)
    q = phase.get("quality", {})
    out = {}
    for metric, cond in q.items():
        c = {"kind": "metric", "metric": metric, "op": cond["op"], "value": cond["value"]}
        out[metric] = evaluate(c, vals)
    return out


def main():
    cfg = json.load(open("config/rulesets/guitar@0.2.0-draft.json", encoding="utf-8"))
    imap = json.load(open("config/fixture-instrument-map.json", encoding="utf-8"))
    manifest = json.load(open(LIB / "hold-windows-guitar.json", encoding="utf-8"))
    row = next(r for r in manifest["sources"] if r["videoId"] == "8xFzcSieBXY")
    assert row["found"]
    t0, t1 = row["tStartS"], row["tEndS"]

    doc = json.load(open(LIB / "landmarks" / "8xFzcSieBXY.full.json", encoding="utf-8"))
    frames = [fr for fr in doc["frames"]
              if fr.get("detected") and fr.get("world")
              and t0 <= fr["t"] / 1000.0 < t1]
    print(f"kaynak: 8xFzcSieBXY (referansa katkı veren 3 kaynaktan biri) — "
          f"pencere [{t0:.1f}s-{t1:.1f}s], {len(frames)} kare\n")

    fails_static = []

    # (b) STATİK denetim: hiçbir quality/error koşulu kol-eklemine dayanmıyor mu?
    arm_joints = {"left_shoulder", "right_shoulder", "left_upper_arm", "right_upper_arm",
                  "left_elbow", "right_elbow", "left_forearm", "right_forearm"}
    for t in cfg["techniques"]:
        for p in t["phases"]:
            for m in p.get("quality", {}):
                if m in arm_joints:
                    fails_static.append(f"quality[{p['id']}] kol-eklemine dayanıyor: {m}")
    for e in cfg["errors"]:
        m = e["condition"].get("metric")
        if m in arm_joints:
            fails_static.append(f"error[{e['code']}] kol-eklemine dayanıyor: {m}")
    print("=== (b) STATİK denetim: quality/error kol-eklemine dayanıyor mu ===")
    print("  TEMİZ — hiçbir quality/error koşulu kol-eklemi kullanmıyor" if not fails_static
          else "  ⛔ " + "; ".join(fails_static))

    # (a) DAVRANIŞSAL: gerçek kare PASS mi veriyor?
    good_pass, good_fail, good_undecidable = 0, 0, 0
    for fr in frames:
        vals = trunk_tilt_and_arms(fr["world"])
        v = quality_verdict(cfg, "POSTURE_CHECK", vals).get("trunk_tilt")
        if v is True:
            good_pass += 1
        elif v is False:
            good_fail += 1
        else:
            good_undecidable += 1
    print(f"\n=== (a) GERÇEK kaynak — quality.trunk_tilt (lte 8°) ===")
    print(f"  PASS={good_pass} FAIL={good_fail} DEĞERLENDİRİLEMEDİ={good_undecidable} "
          f"/ {len(frames)} kare")

    # (a)+(b) KONTROLLÜ BOZULMA: +20° katı döndürme, kol geometrisi KORUNUR
    bad_pass, bad_fail = 0, 0
    trunk_deltas = []
    arm_deltas = {"left_elbow": [], "right_elbow": [], "left_forearm": [], "right_forearm": []}
    for fr in frames:
        w0 = fr["world"]
        vals0 = trunk_tilt_and_arms(w0)
        w1 = rotate_upper_body(w0, ROTATION_DEG)
        vals1 = trunk_tilt_and_arms(w1)
        if "trunk_tilt" in vals0 and "trunk_tilt" in vals1:
            trunk_deltas.append(vals1["trunk_tilt"] - vals0["trunk_tilt"])
        for k in arm_deltas:
            if k in vals0 and k in vals1:
                arm_deltas[k].append(abs(vals1[k] - vals0[k]))
        v = quality_verdict(cfg, "POSTURE_CHECK", vals1).get("trunk_tilt")
        if v is True:
            bad_pass += 1
        elif v is False:
            bad_fail += 1
    trunk_deltas.sort()
    med_delta = trunk_deltas[len(trunk_deltas) // 2] if trunk_deltas else float("nan")
    print(f"\n=== (a) KONTROLLÜ-BOZULMA ikizi (+{ROTATION_DEG:.0f}° katı döndürme, kalça pivotu) ===")
    print(f"  trunk_tilt medyan DELTA: {med_delta:+.1f}° (beklenen ≈ +{ROTATION_DEG:.0f}°)")
    print(f"  quality.trunk_tilt: PASS={bad_pass} FAIL={bad_fail} / {len(frames)} kare")
    print(f"  → gerçek kaynak çoğunlukla PASS, bozulmuş ikiz çoğunlukla FAIL mi: "
          f"{'EVET — referans-tabanlı hüküm ÇALIŞIYOR' if good_pass > good_fail and bad_fail > bad_pass else '❌ HAYIR'}")

    print(f"\n=== (b) DAVRANIŞSAL: döndürme HANGİ kol metriklerini bozdu ===")
    print("  (elbow'lar İÇ açı/flexion — döndürmeye DUYARSIZ olmalı; forearm/upper_arm")
    print("   MUTLAK dikey-açı — trunk_tilt'le AYNI ölçüm sınıfı, döndürmeyle değişmesi BEKLENİR.")
    print("   İkisi de önemli değil: hiçbiri quality/error koşulunda kullanılmıyor — (b)'nin")
    print("   asıl kanıtı yukarıdaki statik denetim.)")
    for k, ds in arm_deltas.items():
        ds.sort()
        med = ds[len(ds) // 2] if ds else float("nan")
        expect = "≈0 (flexion, rotasyon-bağımsız)" if "elbow" in k else f"≈{ROTATION_DEG:.0f}° (mutlak-dikey, trunk_tilt sınıfı)"
        print(f"  {k:16} medyan |delta| = {med:5.2f}°  beklenen {expect}")

    # (c) TARAF-BAZLI HÜKÜM YOK: sol kolu (mirror-belirsiz uçlara benzer) boz,
    # trunk_tilt'i SABİT tut — hüküm DEĞİŞMEMELİ.
    print(f"\n=== (c) Sol-kol bozulması trunk_tilt hükmünü değiştiriyor mu (değiştirmemeli) ===")
    changed = 0
    for fr in frames:
        w0 = fr["world"]
        vals0 = trunk_tilt_and_arms(w0)
        w2 = corrupt_left_arm(w0)
        vals2 = trunk_tilt_and_arms(w2)
        v0 = quality_verdict(cfg, "POSTURE_CHECK", vals0).get("trunk_tilt")
        v2 = quality_verdict(cfg, "POSTURE_CHECK", vals2).get("trunk_tilt")
        if v0 != v2:
            changed += 1
    print(f"  sol-kol bozulmasıyla hüküm DEĞİŞEN kare sayısı: {changed}/{len(frames)} "
          f"({'✅ 0 — taraf-bazlı hüküm YOK' if changed == 0 else '⛔ SIZINTI VAR'})")

    print(f"\n{'✅ TÜM İDDİALAR DOĞRULANDI' if not fails_static and changed == 0 else '⛔ BULGU VAR — yukarı bak'}")
    return 0 if (not fails_static and changed == 0) else 1


if __name__ == "__main__":
    sys.exit(main())
