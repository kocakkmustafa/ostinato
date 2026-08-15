#!/usr/bin/env python3
"""İçerik-atıf süpürmesi — "bir atıf bir VAATTİR" (M-F-248, Choreia emsali).

Kural
-----
Bir config alanı başka bir varlığa İSİMLE işaret ediyorsa, o isim bir söz
verir: "bu şey vardır". Choreia'nın 13 kırık `relatedDrill` atıfı bu sözün
sessizce çiğnenebildiğini gösterdi — hata taksonomisi yedi alıştırmaya
yönlendiriyordu, hiçbiri yoktu, hiçbir kapı bakmıyordu.

İki ayrı arıza var ve İKİNCİSİ daha sinsi:

  ÇÖZÜLMEZ    — işaret edilen şey YOK. Görünür arıza.
  KAPSAM-YANLIŞ — işaret edilen şey VAR ama BAŞKA BİR ÇALGININ. Çözünürlük
                  kapısı "buldum" der ve geçirir; ürün gitar dersinde piyano
                  referansını tüketir. **Çözülmek yetmez, DOĞRU YERE
                  çözülmek gerekir.**

Bu yüzden burada her atıf iki soruya birden cevap verir: çözülüyor mu, ve
BU çalgının dünyasına mı çözülüyor.

Sabotaj: `--sabotage` her atıf sınıfını kasten kırar ve kapının kırmızı
yandığını sınar. Kapı, kırabildiğini göstermeden "kapı" değildir.
"""
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
# ⚠️ Yorum-körlüğü panzehiri (H-31/O-143) — yeniden yazılmadı, içe aktarıldı.
from validate_surface_honesty import strip_dart_comments  # noqa: E402

INSTRUMENTS = ["guitar", "voice", "piano"]
RULESET = "config/rulesets/{}@0.2.0-draft.json"
REFERENCE = "config/references/{}-posture-setup.v1.json"
LIBRARY = "assets/content/library.json"
GOLDEN = "config/observation-cue-templates.golden.json"
TAXONOMY = "config/error-taxonomy.w1.json"
FIXTURE_INDEX = "fixtures/audio/index.json"

#: Çalışma-zamanı referansları: statik olarak çözülemez ve çözülmeye
#: ÇALIŞILMAMALI. İSİMLE muaf tutuluyorlar — sessiz atlama, kapsamı gizler.
#:
#: ⚠️ **AMA İSİMLİ OLMAK YETMİYOR** (JabLab aktarımı, koordinatör 2026-08-07;
#: orada `engineDriven` muafiyet listesi 6→3 indi ve ÜÇ ÖLÜ REPLİK tam
#: muafiyetin arkasında saklanıyordu). Mekanizma: liste "bunu çalışma zamanı
#: üretir" der → üreten kod yolu YOKTUR → kapı yeşil kaldıkça kimse bakmaz.
#: **Muafiyet, kapının kendi kör noktasını üretir.**
#:
#: Ostinato'da ölçüldü (2026-08-07) ve İKİSİ DE boştu:
#:   · `setup.roomFloorDb`   — kabukta ÜRETİCİ 0 (mikrofon girişi yok, O-040).
#:                             Tüketici var (`AudioConfidenceGate`), besleyen yok.
#:   · `exercise.expectedNoteHz` — TÜM ağaçta 1 eşleşme: kendi beyanı.
#:                             Ne üretici ne tüketici ne test. Tamamen ölü.
#:
#: Bu yüzden muafiyet artık çıplak bir isim değil, KENDİ CANLILIK İDDİASINI
#: taşıyan bir kayıt — ve kapı o iddiayı DOĞRULUYOR (aşağıda). `live` iddia
#: eden bir kalem üreticisini gösteremezse KIRMIZI; `blocked` diyen bir kalem
#: üreticisi ORTAYA ÇIKARSA da KIRMIZI (kayıt bayatladı, muafiyet kendini
#: emekliye ayırmalı). İki yön de kapalı olmadan bu sadece daha uzun bir
#: muafiyet listesi olurdu.
RUNTIME_REFS = {
    "setup.roomFloorDb": {
        "status": "blocked",
        "blockedBy": "Kabukta mikrofon girişi YOK (O-040): oda gürültü tabanı "
                     "hiç ölçülmüyor, Kurulum Kontrolü bunu kendi ekranında "
                     "adıyla söylüyor. Tüketici hazır, besleyen yok.",
        # Kabukta bu desen GÖRÜNÜRSE üretici doğmuş demektir → kayıt bayat.
        "producerPattern": r"roomFloorDb",
        "consumer": "packages/ostinato_audio/lib/src/gate/audio_confidence_gate.dart",
    },
    "exercise.expectedNoteHz": {
        "status": "blocked",
        "blockedBy": "Ne üretici ne tüketici var — tüm ağaçta tek eşleşme "
                     "kendi beyanı (voice ruleset'i). Şan alıştırmasının hedef "
                     "frekansını verecek alıştırma-durumu katmanı inşa "
                     "edilmedi; mikrofon girişi de yok, yani tüketilecek bir "
                     "yer de olmazdı.",
        "producerPattern": r"expectedNoteHz",
        "consumer": None,
    },
}


def load(p):
    return json.loads(Path(p).read_text(encoding="utf-8"))


def check(problems, cond, msg):
    if not cond:
        problems.append(msg)


def sweep():
    problems = []
    lib = load(LIBRARY)
    golden = load(GOLDEN)
    taxonomy = load(TAXONOMY)

    for inst in INSTRUMENTS:
        rs_path = RULESET.format(inst)
        check(problems, Path(rs_path).exists(), f"{inst}: ruleset dosyası YOK")
        if not Path(rs_path).exists():
            continue
        cfg = load(rs_path)
        metrics = set(cfg["metrics"])
        phases = {p["id"] for t in cfg["techniques"] for p in t["phases"]}
        techs = {t["id"] for t in cfg["techniques"]}
        codes = {e["code"] for e in cfg.get("errors", [])}

        # ── KAPSAM: ruleset kendi modülünü beyan ediyor mu?
        check(problems, cfg.get("module") == inst,
              f"{inst}: ruleset.module={cfg.get('module')!r} — dosya adıyla uyuşmuyor")

        # ── ATIF: ölçüm artefaktı. KAPSAM KRİTİK: gitar ruleset'i piyano
        # referansını gösterirse çözünürlük kapısı "dosya var" der ve geçer.
        art = cfg.get("referenceConsumption", {}).get(
            "_measurementProvenance", {}).get("artifact")
        if art:
            check(problems, Path(art).exists(),
                  f"{inst}: referans artefaktı ÇÖZÜLMÜYOR: {art}")
            check(problems, art == REFERENCE.format(inst),
                  f"{inst}: referans artefaktı KAPSAM-YANLIŞ → {art} "
                  f"(beklenen {REFERENCE.format(inst)}) — dosya VAR ama "
                  f"BAŞKA ÇALGININ")
            if Path(art).exists():
                ref = load(art)
                # Artefaktın kendisi de hangi tekniğe ait olduğunu söylüyor.
                # Bekleyen regen uyuşmazlığı BEYAN EDİLEBİLİR — ama sessizce
                # değil. Beyanın kendisi eksiksiz olmak zorunda (alan · şimdiki
                # · beklenen · sebep · kim çözecek · tarih); eksik beyan,
                # susturucudan farksızdır ve kapıyı bir yorum satırına çevirir.
                pend = cfg["referenceConsumption"]["_measurementProvenance"].get(
                    "_pendingRegen")
                if ref.get("technique") not in techs:
                    if not pend:
                        problems.append(
                            f"{inst}: artefakt technique={ref.get('technique')!r} bu "
                            f"ruleset'in tekniklerinden biri DEĞİL ({sorted(techs)})")
                    else:
                        missing = [k for k in ("field", "current", "expected", "reason",
                                               "resolvedBy", "declaredAt")
                                   if not pend.get(k)]
                        if missing:
                            problems.append(
                                f"{inst}: _pendingRegen beyanı EKSİK ({missing}) — "
                                f"eksik beyan susturucudur")
                        elif pend.get("expected") not in techs:
                            problems.append(
                                f"{inst}: _pendingRegen.expected={pend.get('expected')!r} "
                                f"de çözülmüyor — beyan kırığı düzeltmiyor")
                        elif pend.get("current") != ref.get("technique"):
                            problems.append(
                                f"{inst}: _pendingRegen.current={pend.get('current')!r} "
                                f"artefaktın gerçek değeriyle ({ref.get('technique')!r}) "
                                f"uyuşmuyor — beyan BAYAT")
                        else:
                            print(f"  ⏳ {inst}: artefakt technique bekleyen regen'e "
                                  f"BEYANLI ({pend['current']} → {pend['expected']}, "
                                  f"{pend['resolvedBy']})")
                elif pend:
                    problems.append(
                        f"{inst}: _pendingRegen beyanı VAR ama uyuşmazlık YOK — "
                        f"çözülmüş bir beyan bayattır, kaldırılmalı")

        # ── ATIF: metrik listeleri
        rc = cfg.get("referenceConsumption", {})
        for field in ("scored", "coached_only"):
            for m in rc.get(field, []):
                check(problems, m in metrics,
                      f"{inst}: referenceConsumption.{field} tanımsız metriğe "
                      f"işaret ediyor: {m!r}")

        # ── ATIF: teknik ön-koşulları ve faz koşulları
        for t in cfg["techniques"]:
            for s in t.get("requires", {}).get("signals", []):
                check(problems, s["signal"] in metrics,
                      f"{inst}/{t['id']}: requires tanımsız sinyale işaret "
                      f"ediyor: {s['signal']!r}")
            for ph in t["phases"]:
                for key in ("enter", "exit"):
                    c = ph.get(key) or {}
                    m = c.get("metric")
                    if m:
                        check(problems, m in metrics,
                              f"{inst}/{t['id']}/{ph['id']}.{key} tanımsız "
                              f"metriğe işaret ediyor: {m!r}")
                for m in ph.get("quality", {}):
                    check(problems, m in metrics,
                          f"{inst}/{t['id']}/{ph['id']}.quality tanımsız "
                          f"metriğe işaret ediyor: {m!r}")

        # ── ATIF: metrik tabanları (çalışma-zamanı olanlar İSİMLE muaf)
        for mid, m in cfg["metrics"].items():
            base = m.get("baseline")
            if isinstance(base, dict) and "ref" in base:
                check(problems, base["ref"] in RUNTIME_REFS,
                      f"{inst}/{mid}: baseline.ref={base['ref']!r} ne bir "
                      f"metrik ne de bilinen çalışma-zamanı referansı "
                      f"({sorted(RUNTIME_REFS)})")

        # ── ATIF: hata kodları ↔ hata taksonomisi. KAPSAM: aynı çalgı!
        tax_codes = {e["code"] for e in taxonomy["instruments"][inst]["errors"]}
        all_tax = {e["code"] for i in INSTRUMENTS
                   for e in taxonomy["instruments"][i]["errors"]}
        for e in cfg.get("errors", []):
            if e["code"] not in tax_codes:
                where = "HİÇBİR çalgıda" if e["code"] not in all_tax else \
                        "BAŞKA bir çalgının taksonomisinde"
                problems.append(
                    f"{inst}: hata kodu {e['code']!r} bu çalgının "
                    f"taksonomisinde YOK ({where}) — kod bir hasat kaydına "
                    f"dayanmalı, ruleset'te doğamaz")
            c = e.get("condition") or {}
            if c.get("metric"):
                check(problems, c["metric"] in metrics,
                      f"{inst}/{e['code']}: koşul tanımsız metriğe işaret "
                      f"ediyor: {c['metric']!r}")
            if e.get("evaluateAt"):
                check(problems, e["evaluateAt"] in phases,
                      f"{inst}/{e['code']}: evaluateAt var olmayan faza "
                      f"işaret ediyor: {e['evaluateAt']!r}")

        # ── ATIF: gözlem işaretleri
        for cue in cfg.get("observationCues", []):
            check(problems, cue["template"] in golden["templates"],
                  f"{inst}/{cue['id']}: golden'da olmayan şablon: "
                  f"{cue['template']!r}")
            check(problems, cue["metric"] in metrics,
                  f"{inst}/{cue['id']}: tanımsız metriğe bağlı: {cue['metric']!r}")
            for ph in cue.get("evaluateAt", []):
                check(problems, ph in phases,
                      f"{inst}/{cue['id']}: var olmayan faza bağlı: {ph!r}")

    # ── ATIF: kütüphane → ruleset. Her atıf KENDİ disiplininin dünyasına.
    all_techs, all_codes, all_cues = {}, {}, {}
    for inst in INSTRUMENTS:
        cfg = load(RULESET.format(inst))
        for t in cfg["techniques"]:
            all_techs[t["id"]] = inst
        for e in cfg.get("errors", []):
            all_codes[e["code"]] = inst
        for c in cfg.get("observationCues", []):
            all_cues.setdefault(c["id"], []).append(inst)

    for d in lib["disciplines"]:
        did = d["id"]
        rs_path = RULESET.format(d["rulesetId"])
        check(problems, Path(rs_path).exists(),
              f"{did}: rulesetId={d['rulesetId']!r} ÇÖZÜLMÜYOR")
        check(problems, d["rulesetId"] == did,
              f"{did}: rulesetId={d['rulesetId']!r} KAPSAM-YANLIŞ — disiplin "
              f"kendi ruleset'ini tüketmeli")
        for c in d.get("courses", []):
            for l in c.get("lessons", []):
                lid = l["id"]
                check(problems, lid.startswith(f"{did}."),
                      f"{lid}: ders id'si disiplin öneki taşımıyor ({did}.)")
                check(problems, lid.startswith(f"{c['id']}."),
                      f"{lid}: ders id'si kurs öneki taşımıyor ({c['id']}.)")
                for t in l.get("techniques", []):
                    owner = all_techs.get(t)
                    if owner is None:
                        problems.append(f"{lid}: teknik ÇÖZÜLMÜYOR: {t!r}")
                    elif owner != did:
                        problems.append(
                            f"{lid}: teknik KAPSAM-YANLIŞ → {t!r} {owner} "
                            f"çalgısına ait (çözülüyor ama YANLIŞ dünyaya)")
                for code in l.get("errorFocus", []):
                    owner = all_codes.get(code)
                    if owner is None:
                        problems.append(f"{lid}: hata kodu ÇÖZÜLMÜYOR: {code!r}")
                    elif owner != did:
                        problems.append(
                            f"{lid}: hata kodu KAPSAM-YANLIŞ → {code!r} "
                            f"{owner} çalgısına ait")
                for cue in l.get("observationCues", []):
                    owners = all_cues.get(cue)
                    if owners is None:
                        problems.append(f"{lid}: gözlem işareti ÇÖZÜLMÜYOR: {cue!r}")
                    elif did not in owners:
                        problems.append(
                            f"{lid}: gözlem işareti KAPSAM-YANLIŞ → {cue!r} "
                            f"yalnız {owners} çalgılarında tanımlı")

    # ── ATIF: fixture indeksi → dosyalar
    idx = load(FIXTURE_INDEX)
    for f in idx["fixtures"]:
        p = Path("fixtures/audio") / f"{f['fixtureId']}.json"
        check(problems, p.exists(),
              f"fixture indeksi ÇÖZÜLMÜYOR: {f['fixtureId']} ({p})")
    on_disk = {p.stem for p in Path("fixtures/audio").glob("AF-*.json")}
    listed = {f["fixtureId"] for f in idx["fixtures"]}
    check(problems, not (on_disk - listed),
          f"diskte olup indekste OLMAYAN fixture: {sorted(on_disk - listed)} "
          f"— kayıtsız fixture, sessizce kullanılan kanıttır")

    # ── ATIF: fixture↔çalgı eşlemesi geçerli çalgı adı taşıyor mu?
    fmap = load("config/fixture-instrument-map.json")
    bad = {v for v in fmap.values() if v not in INSTRUMENTS}
    check(problems, not bad,
          f"fixture-instrument-map bilinmeyen çalgıya işaret ediyor: {sorted(bad)}")

    # ── MUAFİYET DENETİMİ: muafiyetin VARSAYDIĞI şey gerçekten öyle mi?
    #
    # (JabLab aktarımı — bkz. RUNTIME_REFS başlığı.) İsimli olmak yetmez:
    # muafiyet bir İDDİA taşır ("bunu çalışma zamanı üretir" / "bu bugün
    # engelli"), ve denetlenmeyen bir iddia tam da bu kapının kovaladığı şey.
    # İki yön de kapalı, yoksa bu yalnız daha uzun bir muafiyet listesi olur.
    shell = strip_dart_comments("\n".join(
        p.read_text(encoding="utf-8") for p in Path("lib").rglob("*.dart")))
    for ref, spec in RUNTIME_REFS.items():
        produced = bool(re.search(spec["producerPattern"], shell))
        if spec["status"] == "live":
            check(problems, produced,
                  f"muafiyet {ref!r} 'live' diyor ama kabukta ÜRETİCİSİ YOK "
                  f"(desen {spec['producerPattern']!r} lib/ içinde 0 eşleşme) "
                  f"— muafiyetin arkasında ölü bir atıf saklanıyor")
        else:
            check(problems, spec.get("blockedBy"),
                  f"muafiyet {ref!r} 'blocked' ama gerekçesi YOK — engelin "
                  f"adı yazılmadan muafiyet, sessiz atlamanın uzun hâlidir")
            # TERS YÖN: üretici doğduysa kayıt bayat, muafiyet emekli olmalı.
            check(problems, not produced,
                  f"muafiyet {ref!r} 'blocked' diyor ama kabukta ÜRETİCİSİ "
                  f"GÖRÜNDÜ (desen {spec['producerPattern']!r}) — kayıt "
                  f"bayatladı, status 'live' olmalı")
        consumer = spec.get("consumer")
        if consumer:
            check(problems, Path(consumer).exists(),
                  f"muafiyet {ref!r} tüketici olarak {consumer!r} gösteriyor "
                  f"ama o dosya YOK")

    return problems


# ── Sabotaj: her atıf SINIFI için bir kırık ────────────────────────────────
SABOTAGE = [
    ("kütüphane dersi BAŞKA çalgının tekniğini gösteriyor",
     LIBRARY, lambda d: d["disciplines"][0]["courses"][0]["lessons"][-1]
     .__setitem__("techniques", ["five_finger_drill"])),
    ("kütüphane dersi olmayan tekniği gösteriyor",
     LIBRARY, lambda d: d["disciplines"][0]["courses"][0]["lessons"][-1]
     .__setitem__("techniques", ["hayali_drill"])),
    ("disiplin BAŞKA çalgının ruleset'ini tüketiyor",
     LIBRARY, lambda d: d["disciplines"][0].__setitem__("rulesetId", "piano")),
    ("ruleset BAŞKA çalgının referans artefaktını gösteriyor",
     RULESET.format("guitar"),
     lambda d: d["referenceConsumption"]["_measurementProvenance"]
     .__setitem__("artifact", REFERENCE.format("piano"))),
    ("hata kodu bu çalgının taksonomisinde yok",
     RULESET.format("guitar"),
     lambda d: d["errors"][0].__setitem__("code", "P-WRIST-COLLAPSE")),
    ("gözlem işareti var olmayan faza bağlı",
     RULESET.format("voice"),
     lambda d: d["observationCues"][0].__setitem__("evaluateAt", ["HAYALI_FAZ"])),
    ("faz koşulu tanımsız metriğe işaret ediyor",
     RULESET.format("piano"),
     lambda d: d["techniques"][0]["phases"][0]["enter"]
     .__setitem__("metric", "hayali_metrik")),
    ("scored listesi tanımsız metrik taşıyor",
     RULESET.format("piano"),
     lambda d: d["referenceConsumption"]["scored"].append("hayali_metrik")),
]


def run_sabotage():
    import shutil, tempfile
    files = [LIBRARY] + [RULESET.format(i) for i in INSTRUMENTS]
    backup = Path(tempfile.mkdtemp(prefix="refsab-"))
    for f in files:
        shutil.copy(f, backup / Path(f).name)
    ok = True
    try:
        base = sweep()
        if base:
            print(f"⛔ TABAN KIRMIZI ({len(base)}) — sabotaj ölçümü anlamsız")
            return 1
        for label, target, mutate in SABOTAGE:
            for f in files:
                shutil.copy(backup / Path(f).name, f)
            d = load(target)
            mutate(d)
            Path(target).write_text(json.dumps(d, ensure_ascii=False, indent=1),
                                    encoding="utf-8")
            caught = sweep()
            mark = "✅ yakalandı" if caught else "⛔ KAÇTI"
            print(f"  {mark}  {label}")
            if caught:
                print(f"           → {caught[0][:110]}")
            else:
                ok = False
    finally:
        for f in files:
            shutil.copy(backup / Path(f).name, f)
        shutil.rmtree(backup, ignore_errors=True)
    print(f"\n{'✅' if ok else '⛔'} sabotaj {len(SABOTAGE)} sınıfta "
          f"{'tamamı yakalandı' if ok else 'KAÇAN VAR'}")
    return 0 if ok else 1


def main():
    if "--sabotage" in sys.argv:
        return run_sabotage()
    problems = sweep()
    if problems:
        print(f"⛔ {len(problems)} KIRIK/KAPSAM-YANLIŞ ATIF:")
        for p in problems:
            print(f"   - {p}")
        return 1
    print("✅ atıf süpürmesi TEMİZ — her atıf çözülüyor VE kendi çalgısının "
          "dünyasına çözülüyor")
    return 0


if __name__ == "__main__":
    sys.exit(main())
