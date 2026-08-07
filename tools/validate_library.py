#!/usr/bin/env python3
"""İçerik kütüphanesi (`assets/content/library.json`) dürüstlük denetimi —
JabLab `library_test.dart`in AYNI beş kuralını (kopyası değil, aynı
gerekçeyle) Python'da uygular (M-F-103/108, kilitli-ders paketi).

İhlal = kullanıcıya verilmiş somut bir sözün çiğnenmesi — uyarı değil hata.
"""
import json
import re
import sys
from pathlib import Path


def load(path):
    return json.loads(Path(path).read_text(encoding="utf-8"))


def technique_ids(ruleset_path):
    if not Path(ruleset_path).exists():
        return set()
    cfg = load(ruleset_path)
    return {t["id"] for t in cfg.get("techniques", [])}


def error_metric_map(ruleset_path):
    """Hata kodu -> koşulunun bağlandığı metrik. Kural 7'nin dayanağı."""
    if not Path(ruleset_path).exists():
        return {}
    cfg = load(ruleset_path)
    return {e["code"]: e.get("condition", {}).get("metric")
            for e in cfg.get("errors", [])}


def error_flags(ruleset_path):
    """Hata kodu -> (expertPending, status). M-F-125 okuyucu-(i)nin dayanağı."""
    if not Path(ruleset_path).exists():
        return {}
    cfg = load(ruleset_path)
    return {e["code"]: (bool(e.get("expertPending")), e.get("status"))
            for e in cfg.get("errors", [])}


def observation_cues(ruleset_path):
    """Gözlem işareti kodu -> bağlı olduğu metrik (M-F-232 kural 8'in dayanağı)."""
    if not Path(ruleset_path).exists():
        return {}
    cfg = load(ruleset_path)
    return {c["id"]: c.get("metric") for c in cfg.get("observationCues", [])}


def scored_metrics(ruleset_path):
    if not Path(ruleset_path).exists():
        return set()
    return set(load(ruleset_path).get("referenceConsumption", {}).get("scored", []))


def main():
    lib_path = "assets/content/library.json"
    lib = load(lib_path)
    violations = []

    for d in lib["disciplines"]:
        did = d["id"]

        # Kural 1: coming_soon disiplinde kurs OLAMAZ.
        if d.get("status") == "coming_soon" and d.get("courses"):
            violations.append(f"{did}: coming_soon ama {len(d['courses'])} kurs listeliyor")

        # Kural 4: her disiplinde honesty.notMeasured DOLU olmalı.
        not_measured = d.get("honesty", {}).get("notMeasured")
        if not not_measured:
            violations.append(f"{did}: honesty.notMeasured boş/yok")

        if d.get("status") != "live":
            continue

        rs_path = f"config/rulesets/{d['rulesetId']}@0.2.0-draft.json"
        techs = technique_ids(rs_path)
        err_metric = error_metric_map(rs_path)
        err_flags = error_flags(rs_path)
        scored = scored_metrics(rs_path)
        obs_cues = observation_cues(rs_path)

        for c in d.get("courses", []):
            # Kural 2: her kursun en az 1 dersi olmalı.
            if not c.get("lessons"):
                violations.append(f"{did}/{c['id']}: boş kurs (0 ders)")
                continue

            for l in c["lessons"]:
                lid = l["id"]
                # Kural 3: ders, ruleset'te BULUNMAYAN teknige atif yapamaz.
                for t in l.get("techniques", []):
                    if t not in techs:
                        violations.append(
                            f"{lid}: var olmayan tekniğe atıf: '{t}' "
                            f"(ruleset {d['rulesetId']}'de yok)")
                # Kural 5: locked ders lockedReason taşımalı.
                if l.get("status") == "locked" and not l.get("lockedReason"):
                    violations.append(f"{lid}: status=locked ama lockedReason yok")
                if l.get("status") != "locked" and l.get("lockedReason"):
                    violations.append(f"{lid}: lockedReason var ama status=locked değil "
                                       f"(tutarsız beyan)")
                # Kural 7 (M-O-53): AÇIK bir ders yalnız GERÇEKTEN skorlanan bir
                # metriğe bağlı hata kodunu öne çıkarabilir. Gerekçe ölçüldü:
                # gitar ruleset'indeki 5 hata kodunun 4'ü taslak olarak
                # `level_above_room_floor_db > 15`e bağlı — yani "başparmak
                # sapta" uyarısı SES YÜKSEKLİĞİNDE ateşlerdi. `expertPending`
                # bayrağı bunu engellemiyor: hiçbir kod/araç o bayrağı OKUMUYOR
                # (beşinci canlılık sorusu — bayrak var, tüketicisi yok).
                # Bu kural, o tuzağın kullanıcıya AÇIK ders olarak ulaşmasını
                # mekanik olarak keser; ruleset'in kendi düzeltmesi ayrı iş
                # (koordinatör hükmü bekliyor — eşik/eşleme TASARIM kararı).
                if l.get("status") != "locked":
                    for code in l.get("errorFocus", []):
                        if code not in err_metric:
                            violations.append(
                                f"{lid}: var olmayan hata koduna atıf: '{code}'")
                        # M-F-125 okuyucu-(i): `expertPending` artık KAPI.
                        # Uzman onayı beklenen bir kod AÇIK derste anılamaz —
                        # metrik ölçülebilir olsa bile EŞİĞİ uzman-doğrulamalı
                        # değildir; "sırtın eğik" demek, hak etmediğimiz bir
                        # hükümdür. Ders KAPANMAZ (postür ölçümü ATTESTED,
                        # referansa göre skorlanır) — yalnız doğrulanmamış
                        # hata kodunu REKLAM ETMEZ.
                        elif err_flags.get(code, (False, None))[0]:
                            violations.append(
                                f"{lid}: AÇIK ders '{code}' kodunu anıyor ama o kod "
                                f"expertPending — uzman-doğrulanmamış eşik canlı "
                                f"yüzeye çıkamaz (M-F-125)")
                        elif err_flags.get(code, (False, None))[1] == "aspirational":
                            violations.append(
                                f"{lid}: AÇIK ders '{code}' kodunu anıyor ama o kod "
                                f"aspirational (ölçüm aleti yok)")
                        elif err_metric[code] not in scored:
                            violations.append(
                                f"{lid}: AÇIK ders '{code}' hata kodunu öne "
                                f"çıkarıyor ama o kod skorlanmayan bir metriğe "
                                f"bağlı ({err_metric[code]!r}; skorlananlar: "
                                f"{sorted(scored)}) — kullanıcıya ölçülmeyen "
                                f"bir hüküm vaat edilirdi")

                # Kural 12 (O-046, ekran kanıtı bulgusu): KİLİTLİ ders
                # `promotionPath.unblockedBy` taşımak ZORUNDA.
                #
                # Ölçüldü: 10 kilitli dersin 10'unda da bu alan YOKTU ve
                # `lesson_locked_screen.dart` "WHAT WOULD OPEN IT" başlıklı
                # kartı BOŞ gövdeyle çiziyordu. Hiçbir kapı görmedi: kural 5
                # `lockedReason`ı (NEDEN kapalı) kolluyordu, NE AÇAR sorusunu
                # kimse kollamıyordu. İkisi ayrı bilgi ve ikincisi olmadan
                # kilit bir çıkmaz sokak gibi okunur — oysa bu ailenin en
                # güçlü içeriği tam da "bunu ne açar" cümlesidir.
                if l.get("status") == "locked":
                    ub = (l.get("promotionPath") or {}).get("unblockedBy", "")
                    if len(str(ub).strip()) < 60:
                        violations.append(
                            f"{lid}: KİLİTLİ ama promotionPath.unblockedBy yok "
                            f"ya da yer-tutucu ({len(str(ub).strip())} karakter) "
                            f"— 'neden kapalı' yazılıp 'ne açar' yazılmazsa "
                            f"ekranda BOŞ bir kart çizilir (kural 12)")

                # Kural 11 (M-F-245): demoOnlyClass SÖZLEŞMESİ — varsayılan YOK.
                #
                # Sessiz varsayılan bir İDDİADIR: sınıfı yazılmamış bir
                # demoOnly ders, okuyana "geçici olsa gerek" dedirtir. Sözlük
                # KAPALI ve iki dallı, ikisi de ZORUNLU beyanla:
                #   structural-circular (ölçülür ama skorlanamaz)
                #        ⇒ promotionPath ZORUNLU (üç alanıyla)
                #   permanent (kamera o kalite boyutunu GÖREMEZ)
                #        ⇒ whyPermanent ZORUNLU ∧ promotionPath YASAK
                #
                # TERS YÖN asıl kapı: `permanent`a yol yazmak eksiklik değil
                # ÇELİŞKİDİR — ya sınıf yanlış ya yol sahte. Sessiz geçmek,
                # var olmayan bir gelecek vaat eder.
                #
                # "Yazılmamış adım" ASLA demoOnly değildir → locked.
                if l.get("status") == "demoOnly":
                    klass = l.get("demoOnlyClass")
                    if klass not in ("structural-circular", "permanent"):
                        violations.append(
                            f"{lid}: status=demoOnly ama demoOnlyClass "
                            f"{klass!r} — kapalı sözlük: structural-circular | "
                            f"permanent (varsayılan YOK, M-F-245)")
                    if not l.get("demoOnlyReason"):
                        violations.append(
                            f"{lid}: demoOnlyReason yok — 'ne alırsın' beyanı zorunlu")
                    path = l.get("promotionPath")
                    if klass == "structural-circular":
                        if not path:
                            violations.append(
                                f"{lid}: structural-circular ama promotionPath YOK — "
                                f"isimsiz çıkış çıkış değildir")
                        else:
                            for k in ("blockedBy", "unblockedBy", "ifItStaysBlocked"):
                                if not str(path.get(k, "")).strip():
                                    violations.append(
                                        f"{lid}: promotionPath.{k} eksik/boş")
                    elif klass == "permanent":
                        if path:
                            violations.append(
                                f"{lid}: permanent AMA promotionPath VAR — bu bir "
                                f"eksiklik değil ÇELİŞKİ: ya sınıf yanlış ya yol "
                                f"sahte (M-F-248 ters-yön kapısı)")
                        if not str(l.get("whyPermanent", "")).strip():
                            violations.append(
                                f"{lid}: permanent ama whyPermanent yok — "
                                f"'ve bu DEĞİŞMEYECEK çünkü' beyanı zorunlu")
                if l.get("demoOnlyClass") and l.get("status") != "demoOnly":
                    violations.append(
                        f"{lid}: demoOnlyClass var ama status={l.get('status')!r} — "
                        f"sınıf, taşımadığı bir durumu nitelendiriyor")

                # Kural 8 (M-F-232): GÖZLEM ŞERİDİ — açık ders bir
                # `observationCue` gösterebilir, ama ŞERİTLER KARIŞAMAZ.
                # Kural 7/M-F-125 aynen duruyor: öğüt (hata kodu) kapalı.
                # Buradaki tehlike, gözlem şeridinin öğüt için ARKA KAPI
                # olması — bir hata kodunu `observationCues` listesine yazıp
                # expertPending kapısını atlamak. Üç kontrol bunu keser.
                for code in l.get("observationCues", []):
                    if code not in obs_cues:
                        violations.append(
                            f"{lid}: var olmayan gözlem işaretine atıf: '{code}'")
                    elif code in err_metric:
                        violations.append(
                            f"{lid}: '{code}' HEM hata kodu HEM gözlem işareti — "
                            f"şeritler ayrı olmalı (M-F-232 şart 1)")
                    elif obs_cues[code] not in scored:
                        violations.append(
                            f"{lid}: gözlem işareti '{code}' skorlanmayan bir "
                            f"metriğe bağlı ({obs_cues[code]!r})")
                if set(l.get("observationCues", [])) & set(l.get("errorFocus", [])):
                    violations.append(
                        f"{lid}: aynı kod hem errorFocus hem observationCues'ta")
                if l.get("status") == "locked" and l.get("observationCues"):
                    violations.append(
                        f"{lid}: KİLİTLİ ders gözlem işareti gösteremez — "
                        f"kilitli ders hiçbir hüküm yüzeyi taşımaz")

        # Kural 9 (MUT-A bulgusu, 2026-08-04): KULLANICIYA GÖRÜNEN SAYI
        # ARTEFAKTA BAĞLI OLMAK ZORUNDA.
        #
        # Mutasyon süpürmesi şunu ölçtü: piyanonun dürüstlük kutusundaki
        # "3 independent piano teachers" ifadesini "30 independent ... agree
        # to within 0.01 degrees" diye değiştirdiğimde HİÇBİR kapı kırmızı
        # yanmadı. Yani ürünün en görünür dürüstlük yüzeyi, ölçümle bağı
        # OLMAYAN serbest metindi — config'teki her sayıyı üç kapıyla
        # koruyup vitrindeki cümleyi korumasız bırakmışız.
        #
        # Kural: honesty.measured içindeki "N independent ..." kalıbı
        # artefaktın `contributingTakes` değerine EŞİT olmalı. Kalıp hiç
        # yoksa da ihlal — sayı taşımayan bir iddia denetlenemez, ve
        # denetlenemeyen iddia tam da bu kuralın kapattığı boşluktur.
        ref_path = f"config/references/{did}-posture-setup.v1.json"
        if Path(ref_path).exists():
            expected_n = load(ref_path)["result"]["contributingTakes"]
            claims = [s for s in d.get("honesty", {}).get("measured", [])
                      if re.search(r"\b\d+\s+independent\b", s)]
            if not claims:
                violations.append(
                    f"{did}: honesty.measured hiçbir '<N> independent ...' "
                    f"iddiası taşımıyor — kaynak sayısı kullanıcıya söylenmeli "
                    f"ve denetlenebilir olmalı (kural 9)")
            for s in claims:
                n = int(re.search(r"\b(\d+)\s+independent\b", s).group(1))
                if n != expected_n:
                    violations.append(
                        f"{did}: dürüstlük kutusu '{n} independent' diyor ama "
                        f"artefakt {expected_n} take ile kurulmuş — kullanıcıya "
                        f"gösterilen sayı ÖLÇÜMLE ÇELİŞİYOR (kural 9)")

        # Kural 10 (MUT-A bulgusu): VARLIK kapısı → ÖZ kapısı.
        #
        # Mutasyon: her `lockedReason`ı "x"e, her `notMeasured` maddesini
        # "-"e indirdim; kapılar yeşil kaldı. Kural 4 ve 5 yalnız ALANIN
        # DOLU olduğuna bakıyordu — yani "boş bırakma" diyordu, "bir şey
        # söyle" demiyordu. Bir gerekçe alanının varlığı, gerekçenin
        # kendisi değildir.
        #
        # Eşik bir VEKİL, ve öyle olduğu yazılı: uzun bir cümle iyi bir
        # gerekçe garantisi vermez, ama "x" kesinlikle gerekçe değildir.
        # Bugünkü meşru metinlerin en kısası ~90 karakter; 40 tabanı
        # meşruları rahat geçirip yer-tutucuyu keser.
        for c in d.get("courses", []):
            for l in c.get("lessons", []):
                lr = l.get("lockedReason")
                if lr is not None and len(lr.strip()) < 40:
                    violations.append(
                        f"{l['id']}: lockedReason yer-tutucu görünüyor "
                        f"({len(lr.strip())} karakter) — kural 5 EKSİK ÖLÇÜMÜN "
                        f"ADINI ister, dolu bir alan değil (kural 10)")
        for item in d.get("honesty", {}).get("notMeasured", []):
            if len(str(item).strip()) < 40:
                violations.append(
                    f"{did}: honesty.notMeasured maddesi yer-tutucu görünüyor: "
                    f"'{item}' (kural 10)")

        # Kural 6: comingSoonInThisDiscipline maddeleri gerekçesiz olamaz
        # (canlı disiplinin İÇİNDEKİ kapsam-dışı maddeler — ayrı listedeki
        # string'ler, ' — ' ile gerekçe taşımalı, boş bırakılmamalı).
        for item in d.get("comingSoonInThisDiscipline", []):
            if len(item.strip()) < 20:
                violations.append(f"{did}: comingSoonInThisDiscipline maddesi "
                                   f"gerekçesiz görünüyor: '{item}'")

    if violations:
        print(f"⛔ {len(violations)} DÜRÜSTLÜK İHLALİ:")
        for v in violations:
            print(f"   - {v}")
        return 1

    live = [d["id"] for d in lib["disciplines"] if d.get("status") == "live"]
    soon = [d["id"] for d in lib["disciplines"] if d.get("status") == "coming_soon"]
    print(f"✅ kütüphane denetimi TEMİZ — {len(lib['disciplines'])} disiplin "
          f"({len(live)} canlı: {live} · {len(soon)} yakında: {soon})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
