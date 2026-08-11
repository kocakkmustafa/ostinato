#!/usr/bin/env python3
"""Gerçek hasat kareleri üzerinde iki ölçüm:

1. **J-028 gerçek-kare regresyonu.** Aynı açı, aynı karede iki uzayda hesaplanır:
   `world` (metrik) ve `lm` (ham normalize). Aradaki fark, en-boy oranının
   sessizce açıya karıştığının KANITIDIR. Sentetik fixture bunu gösteremez
   çünkü sentetik iskelet zaten kare bir uzayda üretilir — bu yüzden kural
   gerçek kare istiyor ve borcu burada ödüyoruz.

2. **B4 açı sınıflandırması.** Omuz hattının kameraya göre yönelimi world
   uzayında hesaplanır: frontal duruşta omuz vektörü kamera eksenine dik
   (|dx| büyük, |dz| küçük), profilde eksene paralel. Elle etiketleme yerine
   ölçülebilir bir vekil — ReferenceBuilder pilotunun açı-duyarlılık kolu
   (B4) bu sınıflara göre ayrışacak.

3. **frameClass (full_body/upper_body) türetimi — koordinatör sorusu
   2026-08-11.** `manualLabels` (triage-thresholds.w1.json) bunun "elle"
   etiketlendiğini varsayıyordu. ÖLÇÜLDÜ: yanlış varsayım — `lm` dizisinin
   3 değil 5 elemanı var; [3]/[4] MediaPipe'ın visibility/presence
   skorları, `extract_landmarks.py` onları ATMAMIŞ. Bu, harvest rig'in
   KENDİ `_body_presence()` yöntemiyle (motion-core `tools/harvest_rig/
   triage.py:155-203`: üst-gövde=burun+omuzlar, tam-gövde=+kalça+ayak
   bileği, eşik visibility≥0.5) BİREBİR AYNI hesaplanabilir — eşik İCAT
   EDİLMEDİ, rig'in zaten kalibre ettiği eşik (min_upper_body_ratio=0.6,
   triage-thresholds.w1.json) yeniden kullanıldı.
   ⚠️ Sınırı: full_body eşiği profil'de hiç ayarlanmamış
   (min_full_body_ratio=0.0 varsayılan) — rig full_body_ratio'yu HİÇ
   HESAPLAMAMIŞ (94 manifestin 94'ünde de null, ölçüldü). Burada
   HESAPLANDI ama SINIR ÇİZİLMEDİ: hangi oranın "full_body" saymaya
   yeteceği kurucu/koordinatör kararı, `unmeasured` bırakıldı.
   ⛔ hand_cam/fretboard_cam/unusable AYRIMI: bu üçü GÖVDE GEOMETRİSİ
   değil, KADRAJIN KONUSU (el/klavye mi, kötü çekim mi) — pose-landmark
   görünürlüğünden TÜRETİLEMEZ, gerçek bir görsel inceleme gerektirir.
   Düşük upper_body_ratio bu üçünü BİRBİRİNDEN AYIRT ETMEZ, yalnız
   "full_body/upper_body değil" der.
"""
import json, glob, math, os, sys
from statistics import median

L_SH, R_SH, L_HIP, R_HIP = 11, 12, 23, 24
#: Harvest rig'in KENDİ tanımı (triage.py:161-164, 178, 157) — yeniden
#: türetilmedi, birebir kopyalandı.
UPPER_IDS = (0, 11, 12)          # burun + iki omuz
LOWER_IDS = (23, 24, 27, 28)     # + kalçalar + ayak bilekleri
VISIBILITY_THRESHOLD = 0.5       # rig'in kendi eşiği (triage.py:196,198)


def body_presence_ratio(frames):
    """(üst-gövde oranı, tam-gövde oranı) — rig'in _body_presence()'ı ile
    AYNI mantık, ama PROBE örneklemi değil TÜM çıkarılmış kareler üzerinde
    (extract zaten tüm kareleri gezmişti, ikinci bir video-okuma gerekmez)."""
    seen_upper = seen_full = total = 0
    for fr in frames:
        lm = fr.get("lm")
        if not lm or len(lm) <= max(LOWER_IDS):
            continue
        total += 1
        if all(lm[i][3] >= VISIBILITY_THRESHOLD for i in UPPER_IDS):
            seen_upper += 1
            if all(lm[i][3] >= VISIBILITY_THRESHOLD for i in LOWER_IDS):
                seen_full += 1
    if total == 0:
        return None, None
    return seen_upper / total, seen_full / total


def shoulder_yaw_deg(w):
    """Omuz hattının kamera eksenine göre açısı, world uzayında.

    0° = omuzlar kameraya tam dik (frontal), 90° = profil.
    """
    dx = w[R_SH][0] - w[L_SH][0]
    dz = w[R_SH][2] - w[L_SH][2]
    return abs(math.degrees(math.atan2(abs(dz), abs(dx))))


def angle_class(yaw):
    if yaw < 25:
        return "C_frontal"
    if yaw < 55:
        return "A_right_front_diagonal"
    return "B_side_profile"


def trunk_tilt_deg(pts, aspect=1.0):
    """Gövde ekseninin dikeyden sapması.

    `aspect`, normalize uzayda y'yi gerçek piksel oranına çevirmek için; ham
    normalize karşılaştırmasında 1.0 bırakılır — bozukluğu göstermek istiyoruz.
    """
    mid_sh = [(pts[L_SH][i] + pts[R_SH][i]) / 2 for i in range(2)]
    mid_hip = [(pts[L_HIP][i] + pts[R_HIP][i]) / 2 for i in range(2)]
    dx = mid_sh[0] - mid_hip[0]
    dy = (mid_sh[1] - mid_hip[1]) * aspect
    return abs(math.degrees(math.atan2(abs(dx), abs(dy))))


def analyze(path):
    d = json.load(open(path))
    meta = d.get("recordingMeta", {})
    res = meta.get("resolution") or ""
    try:
        w, h = (int(x) for x in res.lower().split("x"))
    except ValueError:
        w = h = None
    # Normalize koordinatta x, GENİŞLİĞE göre; y, YÜKSEKLİĞE göre 0-1'e
    # sıkıştırılmıştır. Gerçek piksel geometrisini geri almak için y'yi H/W ile
    # ölçeklemek gerekir — 16:9'da bu 0.5625, yani ham normalize dikey mesafeyi
    # yataya göre 1.78× ŞİŞİRİR ve dikeyden sapma açısını olduğundan KÜÇÜK
    # gösterir. Ölçtüğümüz işaretin hep negatif çıkması bunun doğrulaması.
    aspect = (h / w) if (w and h) else None

    yaws, world_tilt, norm_tilt, norm_tilt_fixed = [], [], [], []
    for fr in d["frames"]:
        if not fr.get("detected") or not fr.get("world"):
            continue
        W, N = fr["world"], fr["lm"]
        if len(W) <= R_HIP or len(N) <= R_HIP:
            continue
        yaws.append(shoulder_yaw_deg(W))
        # world: metrik uzay, en-boy bağımsız — referans doğru cevap
        world_tilt.append(trunk_tilt_deg([[p[0], p[1]] for p in W]))
        # ham normalize: x ve y birbirinden bağımsız 0-1'e sıkıştırılmış
        norm_tilt.append(trunk_tilt_deg([[p[0], p[1]] for p in N]))
        # piksel-ölçekli düzeltme: y'yi en-boy oranıyla geri aç
        if aspect:
            norm_tilt_fixed.append(trunk_tilt_deg([[p[0], p[1]] for p in N], aspect))

    if not yaws:
        return None
    my = median(yaws)
    upper_ratio, full_ratio = body_presence_ratio(d["frames"])
    # rig'in KENDİ eşiği (min_upper_body_ratio=0.6, triage-thresholds.w1.json)
    # — icat edilmedi. full_body için profilde eşik YOK (rig hiç ölçmemişti,
    # ölçüldü: 94/94 manifest null) → sınır çizilmez, unmeasured bırakılır.
    if upper_ratio is None:
        frame_class_hint = "unmeasured (lm/visibility verisi yok)"
    elif upper_ratio < 0.6:
        frame_class_hint = "unmeasured (upper_body eşiğinin ALTINDA — " \
            "hand_cam/fretboard_cam/unusable AYRIMI görsel inceleme ister)"
    else:
        frame_class_hint = "full_or_upper_body (full_body SINIRI kurucu " \
            "kararı — full_body_ratio ölçüldü, eşiklenmedi)"
    out = {
        "video": os.path.basename(path).split(".")[0],
        "frames": len(yaws),
        "resolution": f"{w}x{h}" if w else "?",
        "medianShoulderYawDeg": round(my, 1),
        "angleClass": angle_class(my),
        "upperBodyRatio": round(upper_ratio, 3) if upper_ratio is not None else None,
        "fullBodyRatio": round(full_ratio, 3) if full_ratio is not None else None,
        "frameClassHint": frame_class_hint,
        "trunkTilt_world_deg": round(median(world_tilt), 2),
        "trunkTilt_normalizedRaw_deg": round(median(norm_tilt), 2),
    }
    out["error_normalizedRaw_deg"] = round(out["trunkTilt_normalizedRaw_deg"] - out["trunkTilt_world_deg"], 2)
    # Mutlak derece yanıltıcı: gövde ekseni zaten dikeye yakın olduğu için
    # açılar küçük. Eşik kalibrasyonunu bozan şey ORANSAL hata.
    out["relError_normalizedRaw_pct"] = round(
        100 * out["error_normalizedRaw_deg"] / out["trunkTilt_world_deg"], 1) if out["trunkTilt_world_deg"] else None
    if norm_tilt_fixed:
        out["trunkTilt_pixelScaled_deg"] = round(median(norm_tilt_fixed), 2)
        out["error_pixelScaled_deg"] = round(out["trunkTilt_pixelScaled_deg"] - out["trunkTilt_world_deg"], 2)
        out["relError_pixelScaled_pct"] = round(
            100 * out["error_pixelScaled_deg"] / out["trunkTilt_world_deg"], 1) if out["trunkTilt_world_deg"] else None
    return out


def main():
    lib = os.path.expanduser("~/motion-harvest/ostinato/landmarks")
    rows = [r for r in (analyze(p) for p in sorted(glob.glob(f"{lib}/*.json"))) if r]
    if not rows:
        print("fixture yok"); return 1

    print(f"{'video':14} {'çözünürlük':11} {'yaw°':>6} {'sınıf':24} {'world°':>7} {'hamNorm°':>9} {'hata°':>7} {'pikselÖlç°':>11} {'hata°':>7} {'oransal':>8}")
    for r in rows:
        print(f"{r['video']:14} {r['resolution']:11} {r['medianShoulderYawDeg']:6} {r['angleClass']:24} "
              f"{r['trunkTilt_world_deg']:7} {r['trunkTilt_normalizedRaw_deg']:9} {r['error_normalizedRaw_deg']:7} "
              f"{r.get('trunkTilt_pixelScaled_deg','—'):>11} {r.get('error_pixelScaled_deg','—'):>7} "
              f"{str(r.get('relError_normalizedRaw_pct','—'))+'%':>8}")

    raw_err = [abs(r["error_normalizedRaw_deg"]) for r in rows]
    raw_rel = [abs(r["relError_normalizedRaw_pct"]) for r in rows if r.get("relError_normalizedRaw_pct") is not None]
    fix_err = [abs(r["error_pixelScaled_deg"]) for r in rows if "error_pixelScaled_deg" in r]
    fix_rel = [abs(r["relError_pixelScaled_pct"]) for r in rows if r.get("relError_pixelScaled_pct") is not None]
    print(f"\nJ-028 gerçek-kare regresyonu ({len(rows)} video):")
    print(f"  ham normalize   → medyan {median(raw_err):.2f}° ({median(raw_rel):.0f}% oransal) · en kötü {max(raw_err):.2f}° ({max(raw_rel):.0f}%)")
    if fix_err:
        print(f"  piksel-ölçekli  → medyan {median(fix_err):.2f}° ({median(fix_rel):.0f}% oransal) · en kötü {max(fix_err):.2f}° ({max(fix_rel):.0f}%)")
        print(f"  → düzeltme oransal hatayı {median(raw_rel):.0f}% → {median(fix_rel):.0f}% indirdi")

    from collections import Counter
    print("\nB4 açı sınıfı dağılımı:", dict(Counter(r["angleClass"] for r in rows)))
    print("frameClass ipucu dağılımı (koordinatör sorusu 2026-08-11):",
          dict(Counter(r["frameClassHint"] for r in rows)))
    json.dump(rows, open("config/frame-analysis.json", "w"), ensure_ascii=False, indent=1)
    return 0


if __name__ == "__main__":
    sys.exit(main())
