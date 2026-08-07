#!/usr/bin/env python3
"""GÖZLEM İŞARETİ (`observationCue`) şeridinin 7 yapısal şartı — MEKANİK kapı.

Koordinatör hükmü M-F-232 (M-F-125 zeyli, 2026-08-04): ölçüm-dilli bir işaret
AÇIK derste görünebilir; öğüt-dilli olan expertPending'de KALIR. Hüküm bir
gevşetme değil, AYRI ŞERİT — ve "koruma YAPISAL olsun" (M-F-201) şartıyla
verildi. Bu betik o yapıdır: yedi şartın her biri burada bir kontroldür,
hiçbiri iyi niyete bırakılmamıştır.

  1. Ayrı ad-alanı        — cue G-/V-/P- hata kodu olamaz, o adları taşıyamaz
  2. Şablon-tek-yol       — metin golden katalogdan; emir kipi / sebep-sonuç /
                            beden-sonucu YASAK, kelime-sınırıyla taranır
  3. Kaynak cümlede       — N + kaynak sınıfı şablon yuvalarında ve doldurulmuş
  4. Uygunluk             — ATTESTED referans + `_derivedFrom` damgası +
                            eşik türetme kapısı YEŞİL
  5. expertPending korunur— cue hiçbir hata kodunun bayrağını tüketmez/kapatmaz;
                            uzman envanteri sayısı DEĞİŞMEZ
  6. Pozitif ikiz         — aralık içinde SUSAR, dışında görünür (İKİ test)
  7. Şeffaflık            — eşiğin taban-kısıtlı türetimi (M-O-63) makine-okunur

Şart 6 GERÇEK KARELERLE sınanır, sentetikle değil: hasat havuzunda hem aralık
içi hem aralık dışı gerçek eğitmen kareleri var (fixture_check: trunk_tilt
aralığı [0, 35]). Sentetik bir "eğik gövde" üretmek, kendi ürettiğimiz sayıyı
kendi eşiğimizle sınamak olurdu.
"""
import json
import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from replay_check import POSE, evaluate  # noqa: E402

INSTRUMENTS = ["guitar", "voice", "piano"]
RULESET = "config/rulesets/{}@0.2.0-draft.json"
REFERENCE = "config/references/{}-posture-setup.v1.json"
GOLDEN = "config/observation-cue-templates.golden.json"
LIB = Path.home() / "motion-harvest" / "ostinato"
ERROR_NAMESPACES = ("G-", "V-", "P-")


def load(p):
    return json.loads(Path(p).read_text(encoding="utf-8"))


def check_wording(text, forbidden):
    """Şart 2'nin dişleri. Kelime SINIRIYLA eşleştirilir: 'so' yasak diye
    'source' düşmemeli — alt-dize eşleşmesi yasak listesini kullanılamaz
    hâle getirir ve kapıyı gürültüden kapatırız."""
    hits = []
    for cls, words in forbidden.items():
        if cls.startswith("$"):
            continue
        for w in words:
            if re.search(rf"\b{re.escape(w)}\b", text, flags=re.IGNORECASE):
                hits.append(f"{cls}:{w}")
    return hits


def _trunk_values(video_id, window=None):
    path = LIB / "landmarks" / f"{video_id}.full.json"
    if not path.exists():
        return []
    out = []
    for fr in json.loads(path.read_text())["frames"]:
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


def real_frames(instrument):
    """Bu çalgının ATTESTED take'lerinden GERÇEK kareler (videonun TAMAMI)."""
    ref = load(REFERENCE.format(instrument))
    out = []
    for t in ref["takes"]:
        out += _trunk_values(t["id"])
    return out


def reference_window_frames(instrument):
    """Referansı KURAN hold-pencerelerinin kareleri — şart 6'nın en sert hâli.

    Bir gözlem işareti, referansı TANIMLAYAN eğitmenlerin tam o anlarında
    ateşliyorsa, yapı gereği yanlıştır: "hiçbiri bu kadar eğilmiyor" diyen
    cümle, tam da onların eğildiğini iddia ediyor olurdu. Videonun tamamında
    ateşlemesi normaldir (eğitmen yürür, sapı göstermek için eğilir); asıl
    sınav DOĞRU DURUŞUN kendi tanımında susmasıdır."""
    ref = load(REFERENCE.format(instrument))
    manifest = json.loads((LIB / f"hold-windows-{instrument}.json").read_text())
    win = {r["videoId"]: r for r in manifest["sources"] if r.get("tStartS") is not None}
    out = []
    for t in ref["takes"]:
        row = win.get(t["id"])
        if row:
            out += _trunk_values(t["id"], (row["tStartS"], row["tEndS"]))
    return out


def main():
    # --fast: tüm-video taraması (240k kare) atlanır; hold-penceresi kontrolü
    # (şart 6b, asıl yanlış-pozitif sınavı) KALIR. Mutasyon süpürmesi bu kapıyı
    # 13 kez koşuyor — ağır taramayı orada tekrarlamak ölçüm değil, bekleme
    # üretir. Tam tarama run_gates'te bir kez koşar.
    fast = "--fast" in sys.argv
    golden = load(GOLDEN)
    problems = []

    # Şart 4'ün ön koşulu: eşik türetme kapısı yeşil olmadan cue MEŞRU DEĞİL.
    derive_ok = subprocess.run(
        [sys.executable, "tools/derive_posture_thresholds.py", "--check"],
        capture_output=True).returncode == 0
    if not derive_ok:
        problems.append("ŞART 4: derive_posture_thresholds --check KIRMIZI — "
                        "eşikler artefaktla eşit değilken gözlem işareti meşru değil")

    # Şart 2: golden şablonların KENDİSİ yasak dil taşıyamaz.
    for tid, tpl in golden["templates"].items():
        # O-062: `variants` eklendi ve bu kapı YALNIZ `text`e bakıyordu —
        # yeni alan, kapının dışında kalan yeni yüzey demekti (gecenin altıncı
        # tekrarı). Artık HER varyant aynı yasak-kelime kapısından geçiyor:
        # bir varyant emir kipine kayarsa tek başına ihlaldir.
        for _i, _v in enumerate(tpl.get("variants", [tpl["text"]])):
            _h = check_wording(_v, golden["forbidden"])
            if _h:
                problems.append(
                    f"{tid} varyant[{_i}]: yasak kelime {_h} — "
                    f"varyant eklemek, kelime kuralını gevşetmenin yolu olamaz")
            # Her varyant AYNI olguları taşımalı: eksik yuva = eksik iddia.
            _missing = [sl for sl in tpl["slots"] if "{" + sl + "}" not in _v]
            if _missing:
                problems.append(
                    f"{tid} varyant[{_i}]: yuva EKSİK {_missing} — varyantlar "
                    f"aynı ölçümü söylemeli, biri sayıyı düşürürse cümle "
                    f"kaynağını kaybeder")
        if tpl.get("variants") and tpl["variants"][0] != tpl["text"]:
            problems.append(
                f"{tid}: variants[0] `text` ile AYNI olmalı — kanıt kareleri "
                f"ve widget testleri ilk ateşlemenin üzerine kurulu")
        hits = check_wording(tpl["text"], golden["forbidden"])
        if hits:
            problems.append(f"ŞART 2: golden şablon {tid} yasak dil taşıyor: {hits}")
        if tpl.get("_claimClass") != "observation":
            problems.append(f"ŞART 2: golden şablon {tid} _claimClass='observation' değil")

    total_cues = 0
    for inst in INSTRUMENTS:
        cfg = load(RULESET.format(inst))
        ref = load(REFERENCE.format(inst))
        cues = cfg.get("observationCues", [])
        error_codes = {e["code"] for e in cfg.get("errors", [])}
        phases = {p["id"] for t in cfg["techniques"] for p in t["phases"]}

        for cue in cues:
            total_cues += 1
            tag = f"{inst}/{cue.get('id')}"

            # ŞART 1 — ayrı ad-alanı.
            if cue["id"].startswith(ERROR_NAMESPACES):
                problems.append(f"ŞART 1: {tag} hata-kodu ad-alanını taşıyor")
            if cue["id"] in error_codes:
                problems.append(f"ŞART 1: {tag} bir hata koduyla AYNI id")
            if cue.get("_class") != "observation":
                problems.append(f"ŞART 1: {tag} _class='observation' değil")

            # ŞART 2 — metin yalnız golden'dan; config kendi metnini TAŞIYAMAZ.
            tid = cue.get("template")
            if tid not in golden["templates"]:
                problems.append(f"ŞART 2: {tag} golden'da olmayan şablona atıf: {tid!r}")
                continue
            tpl = golden["templates"][tid]
            for k, v in cue.items():
                if isinstance(v, str) and not k.startswith("_") and k != "template" \
                        and re.search(r"\{[a-zA-Z]+\}", v):
                    problems.append(f"ŞART 2: {tag}.{k} config içinde SERBEST METİN "
                                    f"taşıyor — metin yalnız golden katalogda yaşar")

            # ŞART 3 — N + kaynak sınıfı, cümlenin içinde ve DOLU.
            data = cue.get("templateData", {})
            for slot in tpl["slots"]:
                if slot == "measuredDeg":
                    continue  # çalışma zamanında motor doldurur
                if slot not in data:
                    problems.append(f"ŞART 3: {tag} '{slot}' yuvasını doldurmuyor")
            if data.get("n") != ref["result"]["contributingTakes"]:
                problems.append(f"ŞART 3: {tag} n={data.get('n')} != artefakt "
                                f"{ref['result']['contributingTakes']} — kaynak sayısı BAYAT")
            if not str(data.get("sourceClass", "")).strip():
                problems.append(f"ŞART 3: {tag} sourceClass boş")

            # ŞART 4 — uygunluk: ATTESTED + skorlanan metrik + _derivedFrom damgası.
            metric = cue.get("metric")
            if ref.get("measurementProvenance") != "ATTESTED":
                problems.append(f"ŞART 4: {tag} referansı ATTESTED değil")
            if metric not in ref["jointAuthority"]["scored"]:
                problems.append(f"ŞART 4: {tag} SKORLANMAYAN metriğe bağlı ({metric})")
            prov = cfg["metrics"].get(metric, {}).get("_derivedFrom")
            if prov is None:
                problems.append(f"ŞART 4: {tag} metriği `_derivedFrom` damgası taşımıyor")
            if not cue.get("_derivedFrom"):
                problems.append(f"ŞART 4: {tag} kendi `_derivedFrom` kaydını taşımıyor")
            for ph in cue.get("evaluateAt", []):
                if ph not in phases:
                    problems.append(f"ŞART 4: {tag} var olmayan faza bağlı: {ph}")

            # ŞART 7 — taban-kısıtlı türetim beyanı makine-okunur mu?
            if not cue.get("_thresholdIsFloorBound"):
                problems.append(f"ŞART 7: {tag} taban-kısıtlı türetim (M-O-63) beyanı yok")
            if cue["condition"]["value"] != ref["gates"]["clusterToleranceDeg"]:
                problems.append(f"ŞART 7: {tag} eşiği {cue['condition']['value']} != "
                                f"artefakt clusterToleranceDeg "
                                f"{ref['gates']['clusterToleranceDeg']}")

            # ŞART 5 — cue hiçbir hata kodunun bayrağını tüketmiyor/kapatmıyor.
            for e in cfg.get("errors", []):
                if e.get("condition", {}).get("metric") == metric and not e.get("expertPending"):
                    problems.append(f"ŞART 5: {tag} ile AYNI metriğe bağlı {e['code']} "
                                    f"artık expertPending DEĞİL — gözlem şeridi öğüt "
                                    f"şeridinin kapısını açmış olabilir")

            # ŞART 6 — pozitif ikiz, GERÇEK karelerle: içeride sussun, dışarıda görünsün.
            vals = [] if fast else real_frames(inst)
            if fast:
                # Hızlı modda "dışarıda görünür" ikizini hold-penceresi
                # DIŞINDAKİ tek bir take'ten al — ucuz ama gerçek.
                vals = _trunk_values(ref["takes"][0]["id"])
            if not vals:
                problems.append(f"ŞART 6: {tag} için gerçek kare bulunamadı")
                continue
            fired = [v for v in vals if evaluate(cue["condition"], {metric: v}) is True]
            silent = [v for v in vals if evaluate(cue["silentWhen"], {metric: v}) is True]
            if not fired:
                problems.append(f"ŞART 6: {tag} {len(vals)} gerçek karenin HİÇBİRİNDE "
                                f"ateşlemedi — görünmeyen bir işaret sınanmamıştır")
            if not silent:
                problems.append(f"ŞART 6: {tag} hiçbir karede SUSMADI — sürekli konuşan "
                                f"gözlem, gözlem değil arka plan gürültüsüdür")
            if len(fired) + len(silent) != len(vals):
                problems.append(f"ŞART 6: {tag} ateşleme ve susma koşulları örtüşüyor "
                                f"veya boşluk bırakıyor ({len(fired)}+{len(silent)} != {len(vals)})")
            # ŞART 6b — EN SERT HÂLİ: referansı KURAN pencerelerde SIFIR ateşleme.
            ref_vals = reference_window_frames(inst)
            if not ref_vals:
                problems.append(f"ŞART 6b: {tag} referans hold-pencereleri okunamadı")
                ref_fired, ref_worst = [], float("nan")
            else:
                ref_fired = [v for v in ref_vals
                             if evaluate(cue["condition"], {metric: v}) is True]
                ref_worst = max(ref_vals)
                if ref_fired:
                    problems.append(
                        f"ŞART 6b: {tag} referansı KURAN pencerelerde "
                        f"{len(ref_fired)}/{len(ref_vals)} karede ateşledi — cümle "
                        f"('kaydettiğimiz {data.get('n')} eğitmenin hiçbiri...') kendi "
                        f"kaynağıyla ÇELİŞİYOR")

            print(f"  {tag}: {len(vals)} gerçek kare → "
                  f"ateşleyen {len(fired)} (%{100*len(fired)/len(vals):.1f}) · "
                  f"susan {len(silent)} · eşik {cue['condition']['value']}° · "
                  f"n={data.get('n')} {data.get('sourceClass')}")
            print(f"    ↳ referansı kuran pencerelerde: {len(ref_vals)} kare · "
                  f"ateşleyen {len(ref_fired)} · eğitmenlerin en kötü karesi "
                  f"{ref_worst:.2f}° (eşiğin %{100*ref_worst/cue['condition']['value']:.0f}'i)")

    if problems:
        print(f"\n⛔ {len(problems)} ŞART İHLALİ:")
        for p in problems:
            print(f"   - {p}")
        return 1
    print(f"\n✅ gözlem işareti sözleşmesi TEMİZ — {total_cues} cue, 7/7 şart "
          f"(ayrı ad-alanı · şablon-tek-yol · kaynak-cümlede · uygunluk · "
          f"expertPending korundu · pozitif ikiz · taban-şeffaflığı)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
