#!/usr/bin/env python3
"""MUT-A: kapılarımın kendisi sınanır — ÇELİŞKİ kapısı mı, yoksa yalnız VARLIK
kapısı mı? (M-F-229, Gravita emsali)

Neden gerekli
-------------
Bir kapının yeşil olması, sınadığını sandığın şeyi sınadığı anlamına gelmez.
İki ayrı zayıflık sınıfı var ve ikisi de "kapı var" cümlesinin arkasında
saklanır:

  VARLIK kapısı  — "alan dolu mu" diye bakar. İçeriği bozarsan yeşil kalır.
  ÇELİŞKİ kapısı — iki kaynağı karşılaştırır. TEK kaynağı bozarsan kırmızı
                   yanar; ama **İKİ KAYNAĞI BİRDEN tutarlı şekilde bozarsan
                   yine yeşil kalır** — bu onun kusuru değil, TANIMI. Kusur,
                   o durumu yakalayacak ÜÇÜNCÜ çapanın hiç olmamasıdır.

MUT-A tam bu üçüncü boşluğu ölçer: her çelişki kapısı için "iki kaynağı
birden" mutasyonu uygulanır ve TÜM kapı takımı koşulur. Hiçbiri kırmızı
yanmıyorsa, o iddia bugün hiçbir çapaya bağlı değildir — isimle raporlanır.

NEGATİF İKİZ (M-F-194): her mutasyonun beklenen sonucu YAZILIDIR. "Kırmızı
yanmalı" kadar "yeşil KALMALI" da sınanır — hep-kırmızı yanan bir kapı da
her mutasyon testini geçerdi.
"""
import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

RULESET = "config/rulesets/{}@0.2.0-draft.json"
REFERENCE = "config/references/{}-posture-setup.v1.json"
LIBRARY = "assets/content/library.json"

GATES = {
    "türetme": [sys.executable, "tools/derive_posture_thresholds.py", "--check"],
    "kütüphane": [sys.executable, "tools/validate_library.py"],
    "gözlem": [sys.executable, "tools/validate_observation_cues.py", "--fast"],
    "ruleset": [sys.executable, "tools/validate_ruleset.py"],
}


def jload(p):
    return json.loads(Path(p).read_text(encoding="utf-8"))


def jdump(p, d):
    Path(p).write_text(json.dumps(d, ensure_ascii=False, indent=1), encoding="utf-8")


def run_gates():
    """Hangi kapılar kırmızı? (adlarıyla)"""
    red = []
    for name, cmd in GATES.items():
        if subprocess.run(cmd, capture_output=True).returncode != 0:
            red.append(name)
    return red


# ── Mutasyonlar ──────────────────────────────────────────────────────────────
# kind: "single" = tek kaynak bozulur (çelişki kapısı YAKALAMALI)
#       "both"   = iki kaynak TUTARLI bozulur (üçüncü çapa var mı?)
#       "content"= alan DURUYOR ama içeriği anlamsızlaşıyor (varlık kapısı mı?)

def m_noise_band_only(_):
    p = RULESET.format("voice"); d = jload(p)
    d["metrics"]["trunk_tilt"]["noiseBand"] = 3
    jdump(p, d)


def m_takes_both(_):
    """İki kaynağı BİRDEN: config `_derivedFrom` VE artefaktın `result` bloğu."""
    p = RULESET.format("piano"); d = jload(p)
    d["metrics"]["trunk_tilt"]["_derivedFrom"]["contributingTakes"] = 99
    jdump(p, d)
    r = REFERENCE.format("piano"); a = jload(r)
    a["result"]["contributingTakes"] = 99
    jdump(r, a)


def m_threshold_both_loosen(_):
    """İki kaynağı BİRDEN + GEVŞETME yönünde: artefaktın barı ve ona bağlı
    her config değeri 14 → 30. Gözlem işareti daha AZ ateşler, yani şart 6b
    (hold penceresinde 0 ateşleme) hâlâ sağlanır — sıkılaştırmayı yakalayan
    test gevşetmeyi yakalamaz."""
    r = REFERENCE.format("guitar"); a = jload(r)
    a["gates"]["clusterToleranceDeg"] = 30.0
    jdump(r, a)
    p = RULESET.format("guitar"); d = jload(p)
    for e in d["errors"]:
        if e.get("condition", {}).get("metric") == "trunk_tilt":
            e["condition"]["value"] = 30.0
    for c in d["observationCues"]:
        c["condition"]["value"] = 30.0
        c["silentWhen"]["value"] = 30.0
        c["templateData"]["thresholdDeg"] = 30.0
    jdump(p, d)


def m_sources_both(_):
    """Artefaktın `distinctSources` sayısı ve cue'nun `n`i BİRDEN şişer —
    `takes` dizisi ve `sources` listesi dokunulmadan kalır (üçüncü çapa)."""
    r = REFERENCE.format("voice"); a = jload(r)
    a["result"]["contributingTakes"] = 40
    a["result"]["distinctSources"] = 40
    jdump(r, a)
    p = RULESET.format("voice"); d = jload(p)
    d["metrics"]["trunk_tilt"]["_derivedFrom"]["contributingTakes"] = 40
    d["observationCues"][0]["templateData"]["n"] = 40
    jdump(p, d)


def m_locked_reason_junk(_):
    """VARLIK kapısı sınavı: alan DURUYOR ama içerik anlamsız."""
    d = jload(LIBRARY)
    for disc in d["disciplines"]:
        for c in disc.get("courses", []):
            for l in c["lessons"]:
                if l.get("status") == "locked":
                    l["lockedReason"] = "x"
    jdump(LIBRARY, d)


def m_not_measured_junk(_):
    d = jload(LIBRARY)
    for disc in d["disciplines"]:
        disc["honesty"]["notMeasured"] = ["-"]
    jdump(LIBRARY, d)


def m_honesty_claim_lie(_):
    """Kütüphane dürüstlük kutusu ölçümle ÇELİŞİYOR: piyano 3 eğitmenle
    kuruldu, kutu 30 diyor. Bugün bunu okuyan bir kapı var mı?"""
    d = jload(LIBRARY)
    for disc in d["disciplines"]:
        if disc["id"] == "piano":
            disc["honesty"]["measured"][0] = (
                "Trunk alignment while you sit — checked against 30 independent "
                "piano teachers who agree to within 0.01 degrees of each other")
    jdump(LIBRARY, d)


def m_cue_namespace(_):
    p = RULESET.format("guitar"); d = jload(p)
    d["observationCues"][0]["id"] = "G-SNEAKY"
    jdump(p, d)


def m_quality_below_band(_):
    p = RULESET.format("piano"); d = jload(p)
    for t in d["techniques"]:
        for ph in t["phases"]:
            if "trunk_tilt" in ph.get("quality", {}):
                ph["quality"]["trunk_tilt"]["value"] = 2
    jdump(p, d)


def m_expert_flag_dropped(_):
    p = RULESET.format("guitar"); d = jload(p)
    for e in d["errors"]:
        if e["code"] == "G-POST-SLOUCH":
            e["expertPending"] = False
    jdump(p, d)


def m_cue_in_locked_lesson(_):
    d = jload(LIBRARY)
    for disc in d["disciplines"]:
        for c in disc.get("courses", []):
            for l in c["lessons"]:
                if l.get("status") == "locked":
                    l["observationCues"] = ["OBS-TRUNK-RANGE"]
                    break
    jdump(LIBRARY, d)


def m_error_code_as_cue(_):
    d = jload(LIBRARY)
    for disc in d["disciplines"]:
        if disc["id"] != "guitar":
            continue
        for c in disc.get("courses", []):
            for l in c["lessons"]:
                if l["id"].endswith(".posture"):
                    l["observationCues"] = ["G-POST-SLOUCH"]
    jdump(LIBRARY, d)


def m_nothing(_):
    """Kontrol satırı: hiçbir şey bozulmadı. Kapılar YEŞİL kalmalı —
    hep-kırmızı bir takım da diğer tüm mutasyon testlerini geçerdi."""
    return


MUTATIONS = [
    ("KONTROL — hiçbir şey bozulmadı", "control", m_nothing, []),
    ("tek kaynak: şan noiseBand 8→3", "single", m_noise_band_only, ["türetme"]),
    ("tek kaynak: piyano quality barı 8→2", "single", m_quality_below_band, ["türetme"]),
    ("tek kaynak: cue G- ad-alanına kaçıyor", "single", m_cue_namespace, ["gözlem"]),
    ("tek kaynak: G-POST-SLOUCH expertPending düşürüldü", "single", m_expert_flag_dropped, ["gözlem"]),
    ("tek kaynak: kilitli ders gözlem işareti gösteriyor", "single", m_cue_in_locked_lesson, ["kütüphane"]),
    ("tek kaynak: hata kodu observationCues'a yazıldı", "single", m_error_code_as_cue, ["kütüphane"]),
    ("İKİ KAYNAK: take sayısı config+artefakt birlikte 3→99", "both", m_takes_both, []),
    ("İKİ KAYNAK: eşik GEVŞETİLDİ 14→30 (artefakt+config+cue)", "both", m_threshold_both_loosen, []),
    ("İKİ KAYNAK: kaynak sayısı 6→40 (artefakt+cue)", "both", m_sources_both, []),
    ("içerik: lockedReason 'x'e indirildi (alan duruyor)", "content", m_locked_reason_junk, []),
    ("içerik: notMeasured '-' (alan duruyor)", "content", m_not_measured_junk, []),
    ("içerik: dürüstlük kutusu 3 eğitmeni 30 diye yazıyor", "content", m_honesty_claim_lie, []),
]

TOUCHED = [RULESET.format(i) for i in ("guitar", "voice", "piano")] + \
          [REFERENCE.format(i) for i in ("guitar", "voice", "piano")] + [LIBRARY]


#: ÇÖKMEYE-DAYANIKLI GERİ ALMA (O-072). Bu harness GERÇEK config dosyalarını
#: mutasyona uğratır ve `finally` ile geri alır — ama SÜREÇ ÖLDÜRÜLÜRSE
#: `finally` KOŞMAZ ve repo BOZUK kalır.
#:
#: O-064'te bu harness `run_gates.sh`a bağlandı; yarıçapı "hatırlayan koşar"dan
#: "HER taramada"ya çıktı. Ve tam da öyle oldu: bir koşum zaman aşımıyla
#: öldürüldü, `guitar@0.2.0-draft.json` `G-SNEAKY` mutasyonuyla kaldı, ve
#: SONRAKİ kapı turu kırmızı yandı — kusur üründe değil, KAPININ KENDİSİNDEydi.
#:
#: Çözüm: sabit yedek dizini + NÖBETÇİ dosya. Nöbetçi varsa önceki koşum
#: mutasyonun ORTASINDA ölmüş demektir → sessizce değil, GÜRÜLTÜYLE onarılır.
#: (Kendi dersim, O-065: *geri-alma da mutasyonun parçasıdır.*)
BACKUP_DIR = Path(".mutA-backup")
SENTINEL = BACKUP_DIR / "IN-FLIGHT"


def _heal_if_needed():
    if not SENTINEL.exists():
        return
    print("⚠️  ÖNCEKİ MUT-A KOŞUMU MUTASYONUN ORTASINDA ÖLMÜŞ — onarılıyor:")
    for f in TOUCHED:
        src = BACKUP_DIR / Path(f).name
        if src.exists():
            shutil.copy(src, f)
            print(f"     geri alındı: {f}")
    SENTINEL.unlink(missing_ok=True)
    print("   (repo onarıldı; bu uyarı görüldüyse bir önceki tur kesilmiştir)")


def main():
    _heal_if_needed()
    BACKUP_DIR.mkdir(exist_ok=True)
    backup = BACKUP_DIR
    for f in TOUCHED:
        shutil.copy(f, backup / Path(f).name)
    SENTINEL.write_text("mutations in flight\n", encoding="utf-8")

    baseline = run_gates()
    if baseline:
        print(f"⛔ TABAN KIRMIZI ({baseline}) — mutasyon ölçümü anlamsız")
        return 1

    rows, unguarded = [], []
    try:
        for label, kind, mutate, expect in MUTATIONS:
            for f in TOUCHED:
                shutil.copy(backup / Path(f).name, f)
            mutate(None)
            red = run_gates()
            if kind == "control":
                ok = not red
                verdict = "✅ yeşil kaldı" if ok else f"⛔ KONTROL KIRMIZI ({red})"
            elif expect:
                ok = bool(set(expect) & set(red))
                verdict = f"✅ yakalandı → {red}" if ok else "⛔ KAÇTI"
            else:
                ok = bool(red)
                verdict = f"✅ üçüncü çapa var → {red}" if ok else "🔴 ÜÇÜNCÜ ÇAPA YOK"
                if not ok:
                    unguarded.append(label)
            rows.append((kind, label, verdict, ok))
    finally:
        for f in TOUCHED:
            shutil.copy(backup / Path(f).name, f)
        SENTINEL.unlink(missing_ok=True)
        shutil.rmtree(backup, ignore_errors=True)

    width = max(len(r[1]) for r in rows)
    for kind, label, verdict, _ in rows:
        print(f"  [{kind:7}] {label:<{width}}  {verdict}")

    caught = sum(1 for _, _, _, ok in rows if ok)
    print(f"\n{caught}/{len(rows)} mutasyon beklendiği gibi davrandı.")
    if unguarded:
        print(f"\n🔴 ÜÇÜNCÜ ÇAPASI OLMAYAN {len(unguarded)} İDDİA "
              f"(iki kaynağı birden bozan düzenleme sessizce geçiyor):")
        for u in unguarded:
            print(f"   - {u}")
        print("   → Bunlar bugün hiçbir kapıya bağlı DEĞİL. Kapatılana kadar "
              "'kapımız var' cümlesi bu iddialar için kurulamaz.")
    # Kaçan `single`/`control` = gerçek arıza; çapasız `both`/`content` = RAPOR.
    hard = [r for r in rows if not r[3] and r[0] in ("single", "control")]
    return 1 if hard else 0


if __name__ == "__main__":
    sys.exit(main())
