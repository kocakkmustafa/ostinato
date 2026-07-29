#!/usr/bin/env python3
"""Faz-config v2 şema değişmezlerini ruleset dosyalarında denetle.

Çekirdek yorumlayıcısı henüz yazılmadı; bu betik o gelene kadar aynı
değişmezleri app tarafında zorlar. Amaç "yeşil görünsün" değil: her kontrolün
negatif testi vardır (bkz. --self-test), yoksa denetim kendini doğrulayan boş
bir iddiadır.
"""
import json, sys, pathlib

EFFECTS = {"collectNoVerdict","discardWindow"}
COND_KINDS = {"metric","delta","timeInPhase","confidence","all","any",
              "localMax","localMin","flag","category","intervalOverlap"}
SPACE_OK = {"world","pixel_scaled"}

def check(doc, name):
    p = []
    metrics = doc.get("metrics", {})

    # §2: metrik sözlüğü zorunlu alanları (D5 + M-F-34)
    for mid, m in metrics.items():
        for field in ("unit","range","noiseBand","baseline"):
            if field not in m:
                p.append(f"{name}/{mid}: '{field}' eksik (§2 zorunlu)")
        r = m.get("range")
        if isinstance(r, list) and len(r) == 2 and r[0] >= r[1]:
            p.append(f"{name}/{mid}: range ters/boş {r}")
        # J-028: kamera metriği uzay beyan etmeli
        if "measurementSpace" in m and m["measurementSpace"] not in SPACE_OK:
            p.append(f"{name}/{mid}: geçersiz measurementSpace {m['measurementSpace']!r} (J-028)")

    # kural #4: filtre+eşik birlikte
    if "signalConditioning" not in doc:
        p.append(f"{name}: signalConditioning bloğu yok (kural #4 — filtre+eşik ayrılmaz)")
    else:
        # M-O-23 / 60-DSP-SOZLESMESI §1: analiz parametreleri SÜRE ve FREKANS
        # cinsinden olmalı. Örnek cinsinden bir pencere, örtük bir sampleRate
        # varsayımıdır: 44.1 kHz fixture'da doğru, 48 kHz cihazda (çoğu Android)
        # sessizce BAŞKA bir dedektör. Motoru düzeltip config'i unutmak gerçek
        # bir kaçaktı — koordinatörün denetimi yakaladı, bu kapı tekrarını önler.
        sc = doc["signalConditioning"]
        for k in sc:
            if k.startswith("_"):
                continue
            if k == "sampleRate" or k.endswith(("Samples", "FrameSize", "HopSize")):
                p.append(f"{name}: signalConditioning.{k} ÖRNEK cinsinden — "
                         f"süre (ms) ya da frekans (Hz) cinsine çevir (M-O-23)")

    # Alan-tutarlılık: bir çalgı config'i BAŞKA çalgının içeriğini taşımamalı.
    # Bu kontrol, gitar/piyano config'lerini şan dosyasından kopyalarken
    # yaptığım gerçek hatadan doğdu: yapı doğruydu, ALAN yanlıştı ve
    # doğrulayıcı geçirdi. Yapısal denetim semantik kaymayı görmez.
    mod = doc.get("module")
    PREFIX = {"voice": "V-", "piano": "P-", "guitar": "G-"}
    if mod in PREFIX:
        for e in doc.get("errors", []):
            code = e.get("code", "")
            if code[:2] in set(PREFIX.values()) and not code.startswith(PREFIX[mod]):
                p.append(f"{name}: '{mod}' config'inde yabancı hata kodu {code!r} "
                         f"(beklenen önek {PREFIX[mod]}) — alan kayması")
        for foreign, marker in (("voice", "vibrato"), ("guitar", "strum"), ("piano", "pedal")):
            if foreign != mod and any(marker in k for k in doc.get("metrics", {})):
                p.append(f"{name}: '{mod}' config'inde '{foreign}' metriği ({marker}) — alan kayması")

    for t in doc.get("techniques", []):
        tid = t.get("id","?")
        # D4: taraf çözümü zorunlu + LEFT_/RIGHT_ yasağı (M-F-06)
        if "sideResolution" not in t:
            p.append(f"{name}/{tid}: sideResolution eksik (D4 zorunlu)")
        # Yalnız ANLAMLI alanlarda ara. İlk sürüm ham json.dumps(t) üzerinde
        # arıyordu ve kendi açıklama metnimizi ("LEFT_*/RIGHT_* yasak") ihlal
        # sandı — yanlış pozitif, ve yanlış pozitif denetime olan güveni
        # gerçek bir kaçaktan daha hızlı öldürür. `_` ile başlayan anahtarlar
        # bizim yorum sözleşmemiz; taranmazlar.
        def _payload(o):
            if isinstance(o, dict):
                return {k: _payload(v) for k, v in o.items() if not k.startswith("_")}
            if isinstance(o, list):
                return [_payload(v) for v in o]
            return o
        blob = json.dumps(_payload(t))
        if "LEFT_" in blob or "RIGHT_" in blob:
            p.append(f"{name}/{tid}: config'te LEFT_/RIGHT_ YASAK (M-F-06)")

        # v3: hüküm-penceresi etkisi enum'da olmalı; kirli/geçerli ayrımı
        # sessizce kaybolursa arşive kirli veri sızar (M-O-07).
        for g in t.get("verdictGates", []):
            if g.get("effect") not in EFFECTS:
                p.append(f"{name}/{tid}: geçersiz verdictGates.effect {g.get('effect')!r}")
            if "onEvent" not in g or "holdMs" not in g:
                p.append(f"{name}/{tid}: verdictGates onEvent/holdMs eksik")

        phases = t.get("phases", [])
        ids = [f.get("id") for f in phases]
        if len(ids) != len(set(ids)):
            p.append(f"{name}/{tid}: mükerrer faz id")
        for f in phases:
            fid = f.get("id","?")
            # değişmez #1: terminal olmayan fazda timeout ZORUNLU
            if not f.get("terminal") and "timeoutMs" not in f:
                p.append(f"{name}/{tid}/{fid}: timeoutMs yok (değişmez #1)")
            for slot in ("enter","exit","abort"):
                c = f.get(slot)
                if c and c.get("kind") not in COND_KINDS:
                    p.append(f"{name}/{tid}/{fid}: bilinmeyen koşul türü {c.get('kind')!r} (kural #8)")
            # kural #8: bilinmeyen metriğe atıf = sert hata
            for slot in ("enter","exit","abort"):
                c = f.get(slot) or {}
                mid = c.get("metric")
                # flag/category muafiyeti KALDIRILDI: çekirdek linter'ı
                # `setup_complete`i yakaladı, benimki kaçırdı. Bayrak da bir
                # metriktir ve sözlükte tanımlı olmalı (M-O-10).
                if mid and mid not in metrics:
                    p.append(f"{name}/{tid}/{fid}: tanımsız metrik {mid!r} (kural #8)")
            for mid in (f.get("quality") or {}):
                if mid not in metrics:
                    p.append(f"{name}/{tid}/{fid}: quality'de tanımsız metrik {mid!r}")

    # M-F-46 kural 1/3: skorlanan her metrik ölçülmüş dispersiyon çıtasının
    # altında olmalı; üstündekiler coached_only listesinde YER ALMALI.
    rc = doc.get("referenceConsumption")
    if rc:
        bar = rc.get("scoringBarDeg")
        scored = set(rc.get("scored", []))
        coached = set(rc.get("coached_only", []))
        if bar is None:
            p.append(f"{name}: referenceConsumption.scoringBarDeg eksik (M-F-46 k.1)")
        # scored/coached_only'daki her ad metrik sözlüğünde TANIMLI olmalı.
        # Bu kural, fixture_check'in yakaladığı gerçek bir kusurdan doğdu:
        # şan config'i 'left_shoulder' skorluyordu ama sözlüğünde öyle bir
        # metrik yoktu (adı 'shoulder_rise_norm'du). Sarkan atıf, ürün
        # tarafında sessizce "o eklem hiç skorlanmaz"a dönüşür.
        for mid in sorted(scored | coached):
            if mid not in metrics:
                p.append(f"{name}: referenceConsumption'da tanımsız metrik {mid!r} "
                         f"(sözlükte yok — sarkan atıf)")
        if scored & coached:
            p.append(f"{name}: bir metrik hem scored hem coached_only: {scored & coached}")
        if coached and not rc.get("userExplanation"):
            p.append(f"{name}: coached_only var ama userExplanation yok (M-F-46 k.3 — "
                     f"açıklamasız puan-yokluğu 'sistem bozuk' okunur)")
        if rc.get("provisional") and not rc.get("provisionalConstraints"):
            p.append(f"{name}: provisional işaretli ama kısıtları yazılmamış (M-F-46 k.6)")
        # quality eşiği yalnız SKORLANAN metriğe yazılabilir
        for t in doc.get("techniques", []):
            for f in t.get("phases", []):
                for mid in (f.get("quality") or {}):
                    if mid in coached:
                        p.append(f"{name}/{t['id']}/{f['id']}: coached_only metriğe quality "
                                 f"eşiği yazılamaz: {mid} (M-F-46 k.3)")

    for e in doc.get("errors", []):
        mid = (e.get("condition") or {}).get("metric")
        if mid and mid not in metrics:
            p.append(f"{name}/{e.get('code')}: tanımsız metrik {mid!r}")
        # M-F-125/M-O-53: `aspirational` = ölçüm ALETİ yok. Böyle bir kodun
        # KOŞULU OLAMAZ — koşul yazmak, olmayan bir ölçümü varmış gibi
        # gösterir ve (ölçtüğümüz gibi) yanlış metriğe bağlanıp yanlış
        # ateşler. Eksik aletin ADI zorunlu: "yakında" demek yetmez, NEYİN
        # eksik olduğu isimle yazılır (uzman-turu envanteri bundan üretilir).
        # M-F-140: ÜÇÜNCÜ sınıf — ALET var, İSTATİSTİK yok. `aspirational`dan
        # ayrı tutulur çünkü uzmana sorulacak şey FARKLI: orada "alet yok"
        # (mühendislik borcu), burada "eşiği nereden alacağız" (ölçüm borcu).
        # İkisini aynı kovaya atmak, üretilen envanteri yanıltır.
        if e.get("status") == "thresholdPending":
            if e.get("condition"):
                p.append(f"{name}/{e.get('code')}: status=thresholdPending ama koşul "
                         f"TAŞIYOR — eşiği olmayan kod koşula bağlanamaz (M-F-140)")
            if not e.get("blockedByStatistic"):
                p.append(f"{name}/{e.get('code')}: status=thresholdPending ama "
                         f"blockedByStatistic yok — eşiğin HANGİ istatistikten "
                         f"geleceği isimle yazılır (M-F-140)")
        if e.get("status") == "aspirational":
            if e.get("condition"):
                p.append(f"{name}/{e.get('code')}: status=aspirational ama koşul TAŞIYOR — "
                         f"aleti olmayan ölçüm koşula bağlanamaz (M-O-53)")
            if not e.get("blockedByTool"):
                p.append(f"{name}/{e.get('code')}: status=aspirational ama blockedByTool yok — "
                         f"eksik ALETİN adı zorunlu (envanter bundan üretilir)")
        # NOT: `expertPending ⇒ canlı yüzeye bağlanamaz` (M-F-125 okuyucu-i)
        # kasten BURADA DEĞİL, `validate_library.py` kural 7'de. Sebep
        # ölçüldü: burada "skorlanan metriğe bağlanamaz" diye uygularsam
        # kural 7 ("açık ders YALNIZ skorlanan metriğe bağlı kodu anabilir")
        # ile ÇAKIŞIR ve hiçbir kod hiçbir açık derste anılamaz hâle gelir.
        # Ayrım: METRİK bağı ölçülebilirlik sorusu (buranın işi), YÜZEY bağı
        # "kullanıcıya hüküm olarak ulaşıyor mu" sorusu (kütüphanenin işi).
    return p

def self_test():
    """Her kontrolün gerçekten yakaladığını kanıtla."""
    base = {"signalConditioning":{}, "metrics":{"m":{"unit":"x","range":[0,1],"noiseBand":0.1,"baseline":0}},
            "techniques":[{"id":"t","sideResolution":"visible",
                           "phases":[{"id":"A","timeoutMs":1,"enter":{"kind":"metric","metric":"m"}},
                                     {"id":"Z","terminal":True}]}]}
    import copy
    cases = {
challenge: mut for challenge, mut in [
        ("timeout eksik", lambda d: d["techniques"][0]["phases"][0].pop("timeoutMs")),
        ("signalConditioning eksik", lambda d: d.pop("signalConditioning")),
        ("örnek-cinsinden pencere", lambda d: d["signalConditioning"].update({"windowSamples": 4096})),
        ("örnek-cinsinden onset çerçevesi", lambda d: d["signalConditioning"].update({"onsetFrameSize": 1024})),
        ("config'te sampleRate mühürlü", lambda d: d["signalConditioning"].update({"sampleRate": 44100})),
        ("noiseBand eksik", lambda d: d["metrics"]["m"].pop("noiseBand")),
        ("sideResolution eksik", lambda d: d["techniques"][0].pop("sideResolution")),
        ("tanımsız metrik", lambda d: d["techniques"][0]["phases"][0]["enter"].update(metric="yok")),
        ("tanımsız FLAG metriği", lambda d: d["techniques"][0]["phases"][0].update(
            enter={"kind":"flag","metric":"tanimsiz_bayrak","is":True})),
        ("bilinmeyen koşul", lambda d: d["techniques"][0]["phases"][0]["enter"].update(kind="uydurma")),
        ("yasak uzay", lambda d: d["metrics"]["m"].update(measurementSpace="normalized_raw")),
        ("LEFT_ kullanımı", lambda d: d["techniques"][0].update(limb="LEFT_SHOULDER")),
        ("geçersiz verdictGates.effect", lambda d: d["techniques"][0].update(
            verdictGates=[{"onEvent":"onset","holdMs":100,"effect":"uydurma"}])),
        ("verdictGates alanı eksik", lambda d: d["techniques"][0].update(
            verdictGates=[{"effect":"discardWindow"}])),
        ("coached_only metriğe quality eşiği", lambda d: (
            d.update(referenceConsumption={"scoringBarDeg":14,"scored":[],
                     "coached_only":["m"],"userExplanation":"x"}),
            d["techniques"][0]["phases"][0].update(quality={"m":1}))),
        ("coached_only açıklamasız", lambda d: d.update(
            referenceConsumption={"scoringBarDeg":14,"scored":[],"coached_only":["m"]})),
        ("yabancı hata kodu (alan kayması)", lambda d: (
            d.update(module="guitar"), d.update(errors=[{"code":"V-PITCH-DRIFT","evaluateAt":"A",
            "condition":{"kind":"metric","metric":"m"}}]))),
        ("sarkan referenceConsumption atfı", lambda d: d.update(
            referenceConsumption={"scoringBarDeg":14,"scored":["yok_boyle_metrik"],
                                  "coached_only":[],"userExplanation":"x"})),
        ("thresholdPending ama koşul taşıyor (M-F-140)", lambda d: d.update(
            errors=[{"code": "X-3", "evaluateAt": "A", "status": "thresholdPending",
                     "blockedByStatistic": "ref", "condition": {"kind": "metric", "metric": "m"}}])),
        ("thresholdPending ama istatistik isimsiz (M-F-140)", lambda d: d.update(
            errors=[{"code": "X-4", "evaluateAt": "A", "status": "thresholdPending"}])),
        ("aspirational ama koşul taşıyor (M-O-53)", lambda d: d.update(
            errors=[{"code": "X-1", "evaluateAt": "A", "status": "aspirational",
                     "blockedByTool": "hand-landmarks",
                     "condition": {"kind": "metric", "metric": "m"}}])),
        ("aspirational ama eksik alet isimsiz (M-O-53)", lambda d: d.update(
            errors=[{"code": "X-2", "evaluateAt": "A", "status": "aspirational"}])),
        ("yabancı metrik (alan kayması)", lambda d: (
            d.update(module="guitar"), d["metrics"].update(vibrato_rate_hz={"unit":"Hz",
            "range":[0,12],"noiseBand":0.5,"baseline":0}))),
    ]}
    ok = True
    # yanlış-pozitif testi: yorum alanında geçen yasak desen ihlal SAYILMAMALI
    commented = copy.deepcopy(base)
    commented["techniques"][0]["_why"] = "M-F-06: config'te LEFT_*/RIGHT_* yasaktır"
    if check(commented, "yorum"):
        print("❌ SELF-TEST: yorum metnindeki 'LEFT_' yanlış pozitif üretti"); ok = False
    if check(copy.deepcopy(base), "temiz"):
        print("❌ SELF-TEST: temiz doküman hata verdi"); ok = False
    for label, mut in cases.items():
        d = copy.deepcopy(base); mut(d)
        if not check(d, "neg"):
            print(f"❌ SELF-TEST: '{label}' YAKALANMADI"); ok = False
    # Sayı ELLE yazılmamalı: sabit "16/16" metni, vaka listesinden bir test
    # düşse bile aynı kalırdı — kendini doğrulayan boş rapor tam olarak bu
    # denetimin engellemek için var olduğu şey.
    print(f"✅ self-test: {len(cases)}/{len(cases)} ihlal yakalandı + temiz doküman geçti "
          f"+ yorum yanlış-pozitif üretmedi" if ok else "SELF-TEST BAŞARISIZ")
    return 0 if ok else 1

if __name__ == "__main__":
    if "--self-test" in sys.argv:
        sys.exit(self_test())
    problems = []
    for f in sorted(pathlib.Path("config/rulesets").glob("*.json")):
        problems += check(json.loads(f.read_text(encoding="utf-8")), f.name)
    print("✅ ruleset denetimi TEMİZ" if not problems else "SORUN:")
    for x in problems: print("  -", x)
    sys.exit(1 if problems else 0)
