#!/usr/bin/env python3
"""Anlaşmazlığın SINIFI — betimsel teşhis (M-F-140 hüküm 4).

M-O-56 ölçtü: üç çalgıda da ≥3 take var ve hiçbiri M-F-47 anlaşma kapısını
geçmiyor. "Neden" sorusunun ÜÇ rakip cevabı var ve koordinatör sırayı
kilitledi — (c) → (b) → (a), YENİ HASAT YOK, EŞİK YOK:

  (c) PENCERE TANIMI yanlış olabilir. Sınama: TAKE-İÇİ varyans vs
      TAKE-ARASI varyans. Take-İÇİ büyükse, pencere zaten tek bir duruşu
      yakalamıyor demektir — o zaman (b)'nin take-çifti matrisi ANLAMSIZ
      olur, çünkü "take'in açısı" diye kararlı bir sayı yoktur.
  (b) KAYNAK-KİMLİĞİ ayrışması olabilir (M-F-66 intent-variant). Sınama:
      take-çiftleri anlaşmazlık MATRİSİ — blok yapısı var mı? Küme-içi dar
      / kümeler-arası geniş iki alt-küme çıkarsa ve adlandırılabilir bir
      geleneğe oturuyorsa (klasik vs modern duruş) TAG'lenir; asla
      havuzlanmaz, asla atılmaz.
  (a) BAR sorusu — yalnız (c) ve (b) null çıkarsa. Ve 22 fıtratla
      ALINMAZ: gitarın 22'si VARYANS DAYANAKLI bir scoringBarDeg'di.

Bu betik EŞİK ÖNERMEZ ve KARAR VERMEZ: sayıları üretir, sınıfı koordinatör
adlandırır. Ölçüm `replay_check.POSE` sözlüğündeki AYNI trunk_tilt
fonksiyonuyla yapılır — yeni bir açı tanımı icat edilmez (M-O-18 dersi).
"""
import json
import statistics as st
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from replay_check import POSE  # noqa: E402

LIB = Path.home() / "motion-harvest" / "ostinato"
METRIC = "trunk_tilt"


def take_series(instrument):
    """Her take'in hold-penceresi İÇİNDEKİ kare-kare trunk_tilt dizisi."""
    man = json.loads((LIB / f"hold-windows-{instrument}.json").read_text())
    out = {}
    for row in man["sources"]:
        if not row.get("found"):
            continue
        vid = row["videoId"]
        doc = json.loads((LIB / "landmarks" / f"{vid}.full.json").read_text())
        t0, t1 = row["tStartS"], row["tEndS"]
        vals = []
        for fr in doc.get("frames", []):
            if not fr.get("detected") or not fr.get("world"):
                continue
            if not (t0 <= fr["t"] / 1000.0 < t1):
                continue
            try:
                v = POSE[METRIC](fr["world"])
            except Exception:
                continue
            if v == v:
                vals.append(v)
        if len(vals) >= 10:
            out[vid] = vals
    return out


def main():
    print("ANLAŞMAZLIK SINIFI — betimsel teşhis (eşik YOK, karar YOK)\n")
    report = {}
    for inst in ("guitar", "voice", "piano"):
        series = take_series(inst)
        if len(series) < 2:
            print(f"── {inst}: {len(series)} take — teşhis için yetersiz\n")
            continue
        meds = {v: st.median(s) for v, s in series.items()}
        # (c) TAKE-İÇİ yayılım: pencere gerçekten TEK bir duruşu mu tutuyor?
        #     IQR kullanılıyor (uç-kare gürültüsüne dayanıklı, std'den dürüst).
        within = {}
        for v, s in series.items():
            q = sorted(s)
            iqr = q[int(0.75 * (len(q) - 1))] - q[int(0.25 * (len(q) - 1))]
            within[v] = iqr
        # TAKE-ARASI yayılım: take medyanlarının kendi aralığı.
        between = max(meds.values()) - min(meds.values())
        med_within = st.median(list(within.values()))
        ratio = (between / med_within) if med_within else float("inf")

        print(f"── {inst} ({len(series)} take) ──")
        print(f"  (c) TAKE-İÇİ yayılım (IQR, medyan): {med_within:.1f}°")
        for v in sorted(within, key=lambda k: -within[k]):
            print(f"        {v:14} medyan={meds[v]:6.1f}°  içi-IQR={within[v]:5.1f}°  n={len(series[v])}")
        print(f"  (c) TAKE-ARASI yayılım (medyan aralığı): {between:.1f}°")
        print(f"  (c) ORAN arası/içi = {ratio:.1f}×  "
              f"→ {'take-İÇİ baskın: PENCERE TANIMI şüpheli' if ratio < 1.0 else 'take-ARASI baskın: pencereler kararlı, anlaşmazlık GERÇEK'}")

        # (b) çift-çift anlaşmazlık matrisi — blok yapısı var mı?
        vids = sorted(meds, key=lambda v: meds[v])
        print("  (b) çift-çift |Δmedyan| matrisi (medyana göre sıralı):")
        print("        " + "".join(f"{v[:8]:>10}" for v in vids))
        for a in vids:
            row = "".join(f"{abs(meds[a]-meds[b]):10.1f}" for b in vids)
            print(f"      {a[:8]:>8}{row}")
        gaps = [(meds[vids[i + 1]] - meds[vids[i]], vids[i], vids[i + 1])
                for i in range(len(vids) - 1)]
        big = max(gaps, key=lambda g: g[0]) if gaps else None
        if big:
            lo = [v for v in vids if meds[v] <= meds[big[1]]]
            hi = [v for v in vids if meds[v] >= meds[big[2]]]
            print(f"  (b) en büyük komşu boşluk: {big[0]:.1f}° "
                  f"({big[1][:8]} | {big[2][:8]}) → alt-kümeler {len(lo)}/{len(hi)}")
            if len(lo) >= 2 and len(hi) >= 2:
                wlo = max(meds[v] for v in lo) - min(meds[v] for v in lo)
                whi = max(meds[v] for v in hi) - min(meds[v] for v in hi)
                print(f"       küme-içi genişlikler: {wlo:.1f}° / {whi:.1f}° "
                      f"→ {'BLOK YAPISI ADAYI (küme-içi < boşluk)' if max(wlo, whi) < big[0] else 'blok yapısı YOK (küme-içi ≥ boşluk)'}")
            else:
                print("       → tek take'lik kenar; blok yapısı İDDİA EDİLEMEZ "
                      "(en az 2+2 gerekir)")
        report[inst] = {"takeMedians": meds, "withinIqr": within,
                        "betweenSpreadDeg": round(between, 1),
                        "medianWithinIqrDeg": round(med_within, 1),
                        "betweenOverWithin": round(ratio, 2)}
        print()

    # ── DÖRDÜNCÜ SINIF (koordinatörün üç şıkkında YOK) ────────────────
    # `joint_deviation_table.dart` (build()ın attığı hatayla BİREBİR
    # doğrulanmış) gösterdi ki M-F-47'nin take-başına sayısı EKLEM-MEDYANI:
    #   gitar  trunk_tilt 0,3-5,9°  ·  kollar 25-137°  → medyan 13,2-42,9°
    #   piyano trunk_tilt 0,9-2,3°  ·  kollar 16-133°  → medyan 16,2-46,4°
    # 9 eklemin 8'i KOL olduğu için medyanı kollar belirliyor — ve kollar
    # bu üç çalgıda ZATEN `coached_only` (M-O-47/M-F-46 k.3: ölçtük,
    # anlaşmıyorlar, o yüzden skorlanmıyorlar). Yani kapı, ÜRÜNÜN HİÇ
    # SKORLAMAYACAĞI eklemlerde anlaşma arıyor ve SKORLANAN metriği
    # mükemmel uyan take'leri reddediyor.
    print("=" * 66)
    print("DÖRDÜNCÜ SINIF — üç şıkkın da dışında (kanıt: joint_deviation_table):")
    for inst in report:
        rs = Path(f"config/rulesets/{inst}@0.2.0-draft.json")
        if not rs.exists():
            continue
        rc = json.loads(rs.read_text(encoding="utf-8")).get("referenceConsumption", {})
        scored, coached = rc.get("scored", []), rc.get("coached_only", [])
        r = report[inst]
        print(f"  {inst}: SKORLANAN {scored} → take-medyan aralığı "
              f"{r['betweenSpreadDeg']}° · KOÇLANAN {len(coached)} eklem kapı "
              f"medyanını belirliyor")
    print("  → Kapı, ürünün SKORLAMAYACAĞI eklemlerde anlaşma arıyor.")
    print("  → Bu (a) bar, (b) kaynak-kimliği, (c) pencere DEĞİL: kapının")
    print("    GİRDİ KÜMESİ ürünün tükettiği kümeyle aynı değil.")
    print("=" * 66 + "\n")

    out = LIB / "disagreement-diagnosis.json"
    out.write_text(json.dumps({
        "$why": "M-F-140 hüküm 4 — betimsel teşhis. Eşik önerilmez, sınıf koordinatör "
                "tarafından adlandırılır. Ölçüm replay_check.POSE trunk_tilt ile.",
        "instruments": report,
    }, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(f"yazıldı: {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
