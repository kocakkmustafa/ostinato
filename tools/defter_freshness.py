#!/usr/bin/env python3
"""DEFTER tazeliği: commit'lerde anılan her kayıt defterde DURUYOR mu? (O-108)

**Neden var — ölçüldü, 2026-08-12:** bu deponun defteri 08-07'den beri
dokunulmamıştı ve **15 kayıt** taşıyordu; commit'lerde **96 numara**
anılıyordu → **87 kayıtlık gedik**, beş günlük iş yalnız commit
mesajlarında yaşıyordu. Hiçbir kapı defterin tazeliğini ölçmüyordu.

> ***Bir işin YAPILMIŞ olması, KAYDEDİLMİŞ olması değildir*** (JabLab) — ve
> bu kez kaçan şey **kaydın kendisiydi.**

**ADAPTE EDİLDİ, İCAT EDİLMEDİ:** referans Gravita `tools/defter_freshness.py`
(`1d110be`) — `git log` ∖ `DEFTER` fark kümesi. Ama **desen ve öz-test kopya
DEĞİL**, çünkü ikisi de bu ağaçta ÖLÇÜLDÜ ve farklı çıktı:

## ① Desen: Gravita'nın çapası bende 85 commit'in 28'ini görürdü

Gravita `^(G-\\d+)` — başlık **başına** çapalı. Ostinato'nun biçimi ölçüldü:
**altı ayrı şekil** var (`O-NNN:` 21 · `O-NNN/NNN:` 3 · `O-NNN` 3 ·
`O-NNN/NNN/NNN:` 1 · `M-F-NNN/M-O-NN:` …) ve **O- anan 85 commit'in yalnız
28'i başlıkta O- ile BAŞLIYOR.** Çapalı desen → **57 sahte gedik.**
*(Gravita'da 2 biçim vardı ve ilk yazımı 47 sahte gedik verdi; Lissom'da 3
biçim vardı. Uyarıyı ölçtüm, devralmadım.)*
→ Bu kapı **başlık + gövdeyi** tarar ve çapa kullanmaz.

## ② Kirlenme riski: Gravita'nın SENTİNEL'i bende YOK — kendiminkini sınıyorum

Gravita'nın öz-testi depodaki kasıtlı `G-999` sahte kaydının girdiye
karışmadığını kanıtlar. **Ölçüldü: `O-999` bu ağaçta SIFIR** — yani o riski
devralmadım ve o testi **yazmıyorum.**

> ***Bir öz-testi KOPYALAMAK, koruduğu riski de devraldığını VARSAYMAKTIR***
> (Lissom).

**Benim ölçülmüş riskim BAŞKA: BİRLEŞİK numaralı başlıklar** —
`O-089/090` · `O-081/082` · `O-083/084` · `O-077/078/079`. Naif bir
`\\bO-0*(\\d+)\\b` deseni bunlarda yalnız İLK numarayı görür. Etkisi de
ölçüldü, abartılmadı: bugün **tam 1 numara** (O-090). Öz-test **bunu** sınar.
"""
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFTER = ROOT.parent / "workspace" / "DEFTER.md"

#: Defter satırı: `| O-098 | …` (bu defterin TEK biçimi — 2026-08-12'de
#: yeniden yazıldı, ölçüldü: başka biçim yok).
_ENTRY = re.compile(r"^\|\s*O-0*(\d+)\s*\|", re.M)
#: Commit metni: `O-098` VE birleşik `O-089/090`, `O-077/078/079`.
_MENTION = re.compile(r"\bO-(\d+(?:/\d+)*)")

#: BİLEREK BOŞ — kaynağı olmadığı ÖLÇÜLEN numaralar. Bunlar defterde
#: "KAYNAK BULUNAMADI/BELİRSİZ" diye ADIYLA duruyor; kapı onları her koşumda
#: sahte gedik diye bildirmesin. ⚠️ Bu bir muafiyet listesi DEĞİL: her biri
#: defterde bir SATIR olarak var, yalnız kaynağı yok.
KNOWN_EMPTY = {15, 16, 90}

#: PLANLAMA DÖNEMİ — commit'lerin numara anma alışkanlığından ÖNCE yazılmış
#: kayıtlar (risk/karar-izdüşümü sınıfı: çello yükü · yay-takibi fizibilitesi ·
#: çocuk-verisi uyumu · içerik maliyeti · kurucusuz veri fabrikası). Bunların
#: commit karşılığı YOK çünkü **kod değil KARAR** kayıtları.
#: ⚠️ `KNOWN_EMPTY` ile AYNI TORBAYA konmadı ve bu kasıtlı: biri *"kaynağı
#: aradım, bulamadım"*, öteki *"kaynağı zaten commit değil"*. İkisini tek
#: listede toplamak, aynı sayının iki farklı şeyi saymasıydı — bu ağacın
#: bugün dört kez düştüğü sınıf.
PRE_COMMIT_ERA = {1, 2, 4, 5, 6, 14}


def expand(text: str) -> set:
    """`O-089/090` → {89, 90}. Kısa parçalar baştaki numaradan tamamlanır."""
    out = set()
    for m in _MENTION.finditer(text):
        parts = m.group(1).split("/")
        base = parts[0]
        for p in parts:
            out.add(int(p if len(p) >= len(base)
                        else base[:len(base) - len(p)] + p))
    return out


def commit_ids():
    log = subprocess.run(["git", "-C", str(ROOT), "log", "--format=%s%n%b"],
                         capture_output=True, text=True).stdout
    n = len([l for l in log.split("\n") if l.strip()])
    return expand(log), n


def defter_ids():
    if not DEFTER.exists():
        return set()
    return {int(m) for m in _ENTRY.findall(DEFTER.read_text(encoding="utf-8"))}


def run() -> int:
    commits, lines = commit_ids()
    defter = defter_ids()
    missing = sorted(commits - defter - KNOWN_EMPTY)
    # ⚠️ UÇUŞTAKİ KAYIT: bu kapı pre-commit hook'unda koşar ve o anda
    # yazılmakta olan commit'in mesajı `git log`da HENÜZ YOKTUR. Kaydını
    # commit'ten ÖNCE yazmak DOĞRU alışkanlıktır (O-107 tam bunu yapmadığım
    # için kaçmıştı) — ceza almamalı. Sınır TÜRETİLİR, muafiyet listesi
    # değil: commit'lenmiş en yüksek numaranın ÜSTÜ uçuştadır; ALTINDA
    # kaynaksız bir kayıt varsa o GERÇEK öksüzdür.
    ceiling = max(commits) if commits else 0
    inflight = sorted(n for n in defter - commits - KNOWN_EMPTY
                      - PRE_COMMIT_ERA if n > ceiling)
    orphan = sorted(n for n in defter - commits - KNOWN_EMPTY
                    - PRE_COMMIT_ERA if n <= ceiling)
    if not commits:
        print("⛔ VAKUM: commit'lerde hiç O- numarası bulunamadı — tarama "
              "kırık, 'taze' hükmü GEÇERSİZ")
        return 1
    if not defter:
        print(f"⛔ VAKUM: {DEFTER} okunamadı ya da hiç kayıt yok")
        return 1
    bad = False
    if missing:
        print(f"⛔ DEFTER BAYAT — {len(missing)} kayıt commit'te VAR, defterde "
              f"YOK:")
        print(f"   {', '.join('O-%03d' % n for n in missing)}")
        print("   (Bir işin YAPILMIŞ olması, KAYDEDİLMİŞ olması değildir.)")
        bad = True
    # TERS YÖN: defterde olup hiçbir commit'in anmadığı kayıt da bir olgudur —
    # ya numara uydurulmuş ya commit mesajı numarayı hiç yazmamış.
    if orphan:
        print(f"⚠️ TERS YÖN — {len(orphan)} kayıt defterde VAR, commit'lerde "
              f"anılmıyor: {', '.join('O-%03d' % n for n in orphan)}")
        print("   (Kaynağı olmayan bir kayıt, geri dönüş adresi olmayan bir "
              "iddiadır — `KNOWN_EMPTY`e ADIYLA girmeli.)")
        bad = True
    if bad:
        return 1
    print(f"✅ DEFTER TAZE — commit'lerde anılan {len(commits)} numaranın "
          f"tamamı defterde ({len(defter)} kayıt)")
    if inflight:
        print(f"   ✍️ uçuştaki kayıt {len(inflight)}: "
              f"{', '.join('O-%03d' % n for n in inflight)} — commit'lenmiş "
              f"tavanın (O-{ceiling:03d}) ÜSTÜNDE, yani şu an yazılıyor "
              f"(kaydı commit'ten ÖNCE yazmak doğru alışkanlık)")
    print(f"   payda: {lines} log satırı tarandı · bilerek-boş "
          f"{len(KNOWN_EMPTY)} ({', '.join('O-%03d' % n for n in sorted(KNOWN_EMPTY))}) "
          f"· planlama-dönemi {len(PRE_COMMIT_ERA)} "
          f"· iki yönde ölçüldü (eksik 0 · öksüz 0)")
    return 0


def selftest() -> int:
    dead = []
    commits, lines = commit_ids()
    defter = defter_ids()
    # ① VAKUM: iki yol da dolu mu?
    if len(commits) < 20:
        dead.append(f"commit taraması yalnız {len(commits)} numara buldu "
                    f"(beklenen ≥20) — desen ölmüş")
    if len(defter) < 20:
        dead.append(f"defter taraması yalnız {len(defter)} kayıt buldu "
                    f"(beklenen ≥20) — biçim kaymış olabilir")
    # ② BENİM ölçülmüş riskim: BİRLEŞİK numara. (Gravita'nın sentinel testi
    #    DEĞİL — `O-999` bu ağaçta 0, o riski devralmadım.)
    if expand("O-089/090") != {89, 90}:
        dead.append("BİRLEŞİK numara açılmıyor — `O-089/090` yalnız ilk "
                    "numarayı veriyor; bu ağacın ÖLÇÜLEN kirlenme sınıfı bu "
                    "(4 birleşik başlık var)")
    if expand("O-077/078/079") != {77, 78, 79}:
        dead.append("ÜÇLÜ birleşik numara açılmıyor")
    # ③ Çapalı desen bu ağaçta YETERSİZ — kanıtı kayda geçsin.
    log = subprocess.run(["git", "-C", str(ROOT), "log", "--format=%s"],
                         capture_output=True, text=True).stdout
    anchored = len([l for l in log.split("\n") if re.match(r"^O-\d+", l)])
    mentions = len([l for l in log.split("\n") if re.search(r"\bO-\d+", l)])
    if anchored >= mentions:
        dead.append(f"çapalı desen ({anchored}) mention'la ({mentions}) eşit "
                    f"— bu ağacın çok-biçimli olduğu varsayımı ARTIK YANLIŞ, "
                    f"desen gerekçesi tazelenmeli")
    # ④ OLUMSUZ İKİZ: bugünkü ağaç gedik VERMEMELİ.
    if (commits - defter - KNOWN_EMPTY):
        dead.append("BUGÜNKÜ ağaçta gedik var — olumsuz ikiz başarısız")
    if dead:
        print(f"⛔ {len(dead)} ÖLÜ DESEN (öz-test başarısız):")
        for d in dead:
            print(f"   - {d}")
        return 1
    print(f"✅ tazelik kapısı öz-testi GEÇTİ — birleşik numara açılıyor "
          f"(O-089/090 · O-077/078/079) · çapalı desen bu ağaçta {anchored}/"
          f"{mentions} görürdü (yetersiz, gerekçe geçerli) · bugünkü ağaç "
          f"gediksiz")
    return 0


if __name__ == "__main__":
    sys.exit(selftest() if "--selftest" in sys.argv else run())
