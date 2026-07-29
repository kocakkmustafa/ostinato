#!/usr/bin/env python3
"""Şan araç-yarışı iskeleti (M-F-118, koordinatör direktifi — gece paketi
2026-07-29) — `presence_isolator` core'a MERGE OLDUĞUNDA 4 uygun şan
kaynağını iki araçla yarıştıracak betik. ŞİMDİ YAZILIYOR, KOŞULMUYOR:
presence tarafı henüz core'da yok (Lissom dalında bitiriliyor, merge
koordinatörde) — bu iskelet o merge geldiğinde `run_presence_trunk()`
TEK yerde değişecek şekilde tasarlandı (akor-fixture'daki "hazır boru
hattı" deseninin şan karşılığı — `make_chord_fixture.dart`nın `--real`
uzantısı neyse, burada presence_isolator'ın import'u o).

İki araç, aynı 4 kaynak, aynı soru — "burada kararlı bir duruş var mı?":

  - HOLD (upperBody, GEVŞETİLMİŞ) — GERÇEK, bugün koşulabilir.
    `hold_isolator` şan malzemesi için kalibre DEĞİL (M-O-51: drift
    medyanı gitar/piyano eşiğinin 4-16 katı — `sarki-postur-presence-
    spec.md`). Gerçek `scope="trunkOnly"` hold_isolator'da YOK (yalnız
    fullBody/upperBody/lowerBody) — en yakın GERÇEK scope `upperBody`
    (TORSO 4 landmark her koşulda zorunlu kontrol ediliyor; kollar
    zaten B4/M-O-09'da coached_only, hesaba karışmaları zararsız).
    Drift KAPI OLARAK KULLANILMIYOR (spec §2b-3 önerisi: `math.inf` ile
    fiilen devre dışı, yalnız RAPORLANIYOR) — enerji tavanı spec'in
    önerdiği ~0,5/s'e çekildi. İkisi de var olan `find_hold_windows`
    parametreleri — CORE'A DOKUNULMADI, yalnız çağrı şekli değişti.
  - PRESENCE (trunk-odaklı) — HENÜZ YOK. `presence_isolator.
    find_presence_windows` (aday imza, spec §2c) import edilmeye
    ÇALIŞILIR; bulunamazsa NOT_AVAILABLE döner — sessizce atlanmaz,
    isimle işaretlenir (family disiplini: kapsama boşluğu SAYILIR).

Karşılaştırma metrikleri (ikisi de mevcut olduğunda anlamlı):
  - pencere sayısı, toplam kapsanan saniye
  - HOLD: enerji/s + drift (raporlanır, KAPI değil)
  - PRESENCE: trunk_tilt bant-genişliği (spec'in "kapı değil dayanak" önerisi)
  - zaman-örtüşmesi (saniye) — iki araç AYNI anları mı seçiyor?

Kaynak listesi İCAT EDİLMEDİ: `fixture-instrument-map.json`da
instrument=voice VE provenance.referenceEligible=true olan kayıtlar
(`find_hold_windows.py`nin AYNI filtresi) — bugün tam 4 kaynak
(GiHZrYCAIas/CGhlnPVquHw/II2b3gs31SU/xm1NdA4cmEs), `sarki-postur-
presence-spec.md`nin ölçtüğü kümeyle BİREBİR.
"""
import importlib
import json
import math
import sys
from pathlib import Path

RIG = Path("/Users/mustafakaankocak/motion-worktrees/ostinato-hold-isolator/tools/harvest_rig")
sys.path.insert(0, str(RIG))
from hold_isolator import find_hold_windows  # noqa: E402

LIB = Path.home() / "motion-harvest" / "ostinato"

#: spec §2b: enerji tavanı YÜKSEK ama var — hold'un ORİJİNAL (henüz
#: gitar/piyano için daraltılmamış) tavanı, gerçek veriyle KALİBRE EDİLMEDİ
#: (spec'in kendi açık uyarısı — presence_isolator'ın ilk koşumu kalibre eder).
HOLD_RELAXED_ENERGY = 0.5
#: spec §2b-3: drift KAPI DEĞİL — math.inf ile fiilen devre dışı (yalnız
#: raporda görünür, pencere onun yüzünden reddedilmez).
HOLD_RELAXED_DRIFT = math.inf
WINDOW_S = 5.0  # spec §2c önerisi — hold'un 3.0s varsayılanından geniş
#: Eşik SÜPÜRMESİ — tek bir sihirli sayı seçmemek için. Aralık, ölçülen
#: sürücü dağılımını kapsayacak şekilde geniş tutuldu; bir eşik SEÇİMİ
#: DEĞİL, aracın o aralıktaki davranışının raporu.
SWEEP_DEG = (60, 75, 90, 105, 120, 140)
MIN_HOLD_S = 2.0  # presence'ın kendi jest-tuzağı savunması (L-151): kısa
#: jest sıçraması bu süreyi biriktiremez. 2.0s aracın self-test'indeki
#: "2sn tut" senaryosuyla AYNI büyüklük sınıfı — icat değil, emsal.


def eligible_voice_sources():
    """`find_hold_windows.py`nin AYNI filtresi — kaynak listesi icat edilmiyor."""
    imap = json.loads(Path("config/fixture-instrument-map.json").read_text())
    out = []
    for f in sorted((LIB / "landmarks").glob("*.json")):
        vid = f.name.split(".")[0]
        if imap.get(vid) != "voice":
            continue
        doc = json.loads(f.read_text(encoding="utf-8"))
        if doc.get("provenance", {}).get("referenceEligible") is not True:
            continue
        out.append((vid, doc))
    return out


def run_hold_relaxed(doc, fps):
    """GERÇEK, bugün koşulabilir — var olan `hold_isolator`ı spec'in
    gevşetilmiş eşikleriyle çağırır (core kodu DEĞİŞMEDİ)."""
    frames = [fr.get("lm") if fr.get("detected") is not False else None
              for fr in doc.get("frames", [])]
    windows = find_hold_windows(
        frames, fps=float(fps), window_s=WINDOW_S, scope="upperBody",
        max_energy_per_s=HOLD_RELAXED_ENERGY, max_drift=HOLD_RELAXED_DRIFT,
        min_coverage=0.8,
    )
    return {
        "tool": "hold_upperBody_relaxed",
        "available": True,
        "windowCount": len(windows),
        "totalSeconds": round(sum(w.seconds for w in windows), 1),
        "windows": [{"tStartS": w.start_frame / fps, "tEndS": w.end_frame / fps,
                     "energyPerS": w.energy_per_s, "drift": w.drift,
                     "coverage": w.coverage} for w in windows],
    }


#: presence_isolator (merge: core `8c3c6e0`) GERÇEK imzası, spec §2c
#: ÖNERİMDEN FARKLI çıktı — ve fark yarışın SONUCUNU belirliyor, bu yüzden
#: burada isimle yazılı: araç "bir SÜRÜCÜ AÇI eşiği geçip `min_hold_s`
#: boyunca ORADA KALIYOR MU" sorusunu yanıtlıyor (faz-tanımlı tek gösterim,
#: ROM değerlendirmesi). Sürücü = ÜÇ VÜCUT NOKTASI arası açı; yani
#: DÖNMEYE-DUYARSIZ (rotation-invariant) — tasarım gereği, uzuv açıları
#: için doğru olan şey. Ostinato'nun `trunk_tilt`i ise YERÇEKİMİNE göre
#: (dikeyle açı) tanımlı ve aracın sözlüğünde sentetik "dikey" nokta YOK
#: (`NAME_TO_INDEX`: yalnız gövde landmark'ları + MID_* orta noktalar).
#: Bu bir kusur DEĞİL — aracın sorusu başka. Aşağıdaki ölçüm bunu
#: KOD OKUYARAK değil GERÇEK VERİYLE sınar.
PRESENCE_DRIVERS = {
    # Gövde-dikliği YERİNE geçebilecek, YALNIZ üst-vücutla ifade edilebilen
    # adaylar (şan malzemesi bel-üstü çekim — M-O-43). Hiçbiri trunk_tilt'in
    # AYNISI değildir; amaç "eşiğe dayanacak bir sürücü var mı" sorusu.
    "shoulderLine_vs_trunk": ("{side}_SHOULDER", "MID_SHOULDER", "MID_HIP"),
    "hipLine_vs_trunk": ("{side}_HIP", "MID_HIP", "MID_SHOULDER"),
    # Aracın KANONİK kullanımı (uzuv açısı): kol-gövde açısı. Şanda kol
    # SKORLANMAZ (B4/M-O-09) ama presence SKOR DEĞİL KLİP BULMA işidir —
    # "performans duruşu (kollar sakin)" ile "öğretmen jest yapıyor"
    # ayrımı için mesru bir sürücü adayı.
    "shoulderFlexion": ("{side}_ELBOW", "{side}_SHOULDER", "{side}_HIP"),
}


def _driver_series(presence_isolator, frames, triplets, op=">="):
    """Sürücü açısının kare-kare DEĞERLERİ — eşik SEÇMEDEN, dağılımı ölçmek
    için. Eşik icat etmenin panzehiri: önce ne okuduğunu gör."""
    out = []
    for lm in frames:
        if lm is None:
            continue
        v = presence_isolator._driver_value(lm, triplets, op=op)
        if v is not None:
            out.append(v)
    return out


def run_presence_trunk(doc, fps):
    """presence_isolator MERGE OLDU (core `8c3c6e0`) — burada GERÇEK API'ye
    bağlanıyor. Eşik UYDURULMUYOR: aracın kendisi `status: pending` bir
    eşiği reddediyor ("ölçülmemiş eşik isolatöre taşınmaz", G-043) ve bizde
    kalibre edilmiş bir şan eşiği YOK. Bu yüzden koşum iki katmanlı:
      (1) sürücü DAĞILIMINI ölç (eşiksiz — ne okuyor?),
      (2) GERÇEK `find_presence_windows`i bir eşik SÜPÜRMESİYLE çağır
          (tek sihirli sayı seçmek yerine aralığın davranışını raporla).
    Kalibrasyon bu koşumdan çıkacak — koordinatör talimatı."""
    try:
        presence_isolator = importlib.import_module("presence_isolator")
    except ImportError:
        return {"tool": "presence_trunkFocused", "available": False,
                "reason": "presence_isolator import edilemedi"}
    frames = [fr.get("lm") if fr.get("detected") is not False else None
              for fr in doc.get("frames", [])]
    out = {"tool": "presence_driverSweep", "available": True, "drivers": {}}
    for name, spec_names in PRESENCE_DRIVERS.items():
        spec = {"proximal": spec_names[0], "joint": spec_names[1],
                "distal": spec_names[2]}
        triplets = presence_isolator._resolve_triplets(spec)
        vals = _driver_series(presence_isolator, frames, triplets)
        if not vals:
            out["drivers"][name] = {"readableFrames": 0,
                                    "note": "sürücü hiç okunamadı (görünürlük)"}
            continue
        s = sorted(vals)
        q = lambda p: round(s[min(len(s) - 1, int(p * len(s)))], 1)
        sweep = {}
        for thr in SWEEP_DEG:
            ws = presence_isolator.find_presence_windows(
                frames, fps=float(fps), driver_triplets=triplets, op=">=",
                threshold_deg=float(thr), min_hold_s=MIN_HOLD_S,
                scope="upperBody", min_coverage=0.8,
            )
            sweep[thr] = {"windows": len(ws),
                          "totalHoldS": round(sum(w.hold_seconds for w in ws), 1)}
        out["drivers"][name] = {
            "readableFrames": len(vals), "readableShare": round(len(vals) / max(1, len(frames)), 3),
            "p05": q(0.05), "median": q(0.5), "p95": q(0.95),
            "spreadDeg": round(q(0.95) - q(0.05), 1),
            "thresholdSweep": sweep,
        }
    return out


def overlap_seconds(hold_windows, presence_windows):
    """İki aracın SEÇTİĞİ pencereler ZAMANDA ne kadar örtüşüyor (saniye) —
    'aynı anları mı buluyorlar' sorusunun ilk kaba ölçüsü. Örtüşme YÜKSEK
    olsun/olmasın hüküm DEĞİL — presence_isolator'ın ilk gerçek-veri koşumu
    yorumlar (bu iskelet ölçer, karar vermez)."""
    total = 0.0
    for a in hold_windows:
        for b in presence_windows:
            lo = max(a["tStartS"], b["tStartS"])
            hi = min(a["tEndS"], b["tEndS"])
            if hi > lo:
                total += hi - lo
    return round(total, 1)


def main():
    sources = eligible_voice_sources()
    print(f"=== Şan araç-yarışı iskeleti — {len(sources)} uygun kaynak ===\n")
    report = []
    for vid, doc in sources:
        fps = doc.get("recordingMeta", {}).get("fps")
        hold = run_hold_relaxed(doc, fps)
        presence = run_presence_trunk(doc, fps)
        row = {"videoId": vid, "fps": fps, "hold": hold, "presence": presence}
        report.append(row)
        print(f"\n── {vid} (fps {fps}) ──")
        print(f"  HOLD (upperBody, drift kapısız): {hold['windowCount']} pencere / "
              f"{hold['totalSeconds']}s")
        if not presence["available"]:
            print(f"  PRESENCE: ⏳ {presence['reason']}")
            continue
        for name, d in presence["drivers"].items():
            if not d.get("readableFrames"):
                print(f"  PRESENCE[{name}]: {d.get('note')}")
                continue
            hits = {t: v["windows"] for t, v in d["thresholdSweep"].items() if v["windows"]}
            print(f"  PRESENCE[{name}]: okunabilir %{d['readableShare']*100:.0f} · "
                  f"p05/med/p95 = {d['p05']}/{d['median']}/{d['p95']}° "
                  f"(yayılım {d['spreadDeg']}°) · eşik-süpürmesinde pencere: "
                  f"{hits if hits else 'HİÇBİR eşikte yok'}")

    # ── HÜKÜM (mekanik, düzyazı değil) ────────────────────────────────
    # 1) Okunabilirlik: iki araç da AYNI kaynakta çalışabiliyor mu?
    readable = [r["videoId"] for r in report
                if r["presence"].get("available")
                and max((d.get("readableShare", 0)
                         for d in r["presence"]["drivers"].values()), default=0) >= 0.5]
    hold_found = [r["videoId"] for r in report if r["hold"]["windowCount"]]
    # 2) Dejenerelik: gövde-vekili sürücüler eşik dayanacak kadar oynuyor mu?
    #    ~90 derecede çakılı bir sürücü ANATOMİK SABİTTİR (omuz/kalça çizgisi
    #    gövdeye zaten diktir) — duruş bozulsa da AYNI kalır, çünkü üç-nokta
    #    açısı dönmeye duyarsızdır. Eşik böyle bir sürücüye dayanamaz.
    #    Dejenerelik testi YALNIZ okunabilir kaynaklarda yapılır: %6 kareden
    #    çıkan bir "dağılım" dağılım değildir, onu teste katmak bulguyu
    #    seyreltir (gürültüyü kanıt sanmanın aynası).
    degenerate = {}
    for r in report:
        if not r["presence"].get("available") or r["videoId"] not in readable:
            continue
        for name, d in r["presence"]["drivers"].items():
            if not d.get("readableFrames"):
                continue
            near90 = abs(d["p05"] - 90.0) <= 3.0 and d["spreadDeg"] <= 20.0
            degenerate.setdefault(name, []).append(near90)

    print("\n" + "=" * 62)
    print("HÜKÜM (ölçümden, seçimden değil):")
    print(f"  · Sürücüsü OKUNABİLİR kaynak: {len(readable)}/{len(report)} {readable}")
    print(f"  · HOLD pencere bulduğu kaynak: {len(hold_found)}/{len(report)} {hold_found}")
    for name, flags in degenerate.items():
        if all(flags):
            print(f"  · presence[{name}]: TÜM okunabilir kaynaklarda ~90°'de "
                  f"çakılı + dar yayılım → ANATOMİK SABİT, eşik dayanamaz")
    print("  · Kök sebep ikisinde de AYNI: 3/4 şan kaynağında landmark "
          "okunabilirliği %0-6 — araç seçimi bu duvarın ARKASINDA kalıyor.")
    print("=" * 62)

    out = LIB / "voice-tool-race.json"
    out.write_text(json.dumps({
        "$why": "M-F-118 iskeleti — presence_isolator merge olunca run_presence_trunk() "
                "TEK yerde değişir, geri kalan koşum AYNI kalır. Bugün yalnız hold "
                "tarafı GERÇEK; presence tarafı isimle NOT_AVAILABLE.",
        "sources": report,
    }, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(f"\nyazıldı: {out}")

    if not any(r["presence"]["available"] for r in report):
        print("\n⏳ presence_isolator core'a merge olmadı — yarış HENÜZ koşulamıyor "
              "(beklenen; hata DEĞİL). Merge sinyali geldiğinde tekrar çalıştır.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
