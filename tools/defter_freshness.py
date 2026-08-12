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

#: 🔴 SENTİNEL/ÖRNEK NUMARA ARALIĞI — `O-900`+ hiçbir zaman gerçek kayıt
#: DEĞİLDİR; belgede/commit mesajında ÖRNEK olarak anılır.
#:
#: ⚠️ BU KURALIN DOĞUŞU, bugünün en keskin öz-yakalaması: Gravita'nın
#: `G-999` sentinel testini "bende karşılığı YOK, `O-999` → 0" diye ölçüp
#: YAZMADIM (Lissom'un kuralı: *bir öz-testi kopyalamak, koruduğu riski
#: devraldığını varsaymaktır*). Sonra O-108'in commit MESAJINA tam o cümleyi
#: yazdım — ve bir sonraki koşumda kapı `O-999`u EKSİK KAYIT diye bildirdi.
#:
#: > ***Riski devralmadığımı ölçtüğüm cümlenin KENDİSİ riski yarattı:
#: > bir numaradan SÖZ ETMEK ile bir numarayı KAYDETMEK aynı metinde
#: > ayırt edilemez.***
#:
#: Yani Gravita'nın sentinel tasarımı bende de GEREKLİ — ama devraldığım
#: için değil, ÖLÇÜMÜN KENDİSİ onu ürettiği için. Ayrılan aralık `9xx`.
SENTINEL_RANGE = range(900, 1000)


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


def commit_census():
    """PAYDA DENETİMİ (koordinatör şartı): atıflı + atıfsız = TARANAN.

    ⚠️ Neden sayı değil DENKLEM: bir kapı *"N commit taradım"* diyebilir ve
    N yanlış olabilir — bölme kaçırırsa, `--format` bozulursa, ya da bir
    ayrıştırma hatası commit'leri birleştirirse. Denklem tutmuyorsa
    **kapı KENDİNE öter**; sayının doğruluğu kendi kanıtı değildir.
    (JabLab'ınki bugün tutmuyor: 121+91=212, depoda 226 — 14 commit
    kayboluyor. Ölçüm koordinatörden geldi, kendi paydamı denetledim.)
    """
    out = subprocess.run(
        ["git", "-C", str(ROOT), "log", "--format=%H%x01%s%x01%b%x02"],
        capture_output=True, text=True).stdout
    commits = [c.strip() for c in out.split("\x02") if c.strip()]
    with_ref = [c for c in commits if _MENTION.search(c)]
    total = subprocess.run(["git", "-C", str(ROOT), "rev-list", "--count",
                            "HEAD"], capture_output=True, text=True).stdout
    return commits, with_ref, int(total.strip() or 0)


def commit_ids():
    commits, with_ref, total = commit_census()
    ids = {n for n in expand("\n".join(commits)) if n not in SENTINEL_RANGE}
    return ids, (len(with_ref), len(commits) - len(with_ref), total)


def defter_ids():
    if not DEFTER.exists():
        return set()
    return {int(m) for m in _ENTRY.findall(DEFTER.read_text(encoding="utf-8"))}


def subject_ids():
    """YALNIZ commit BAŞLIKLARINDA anılan numaralar — "bu commit o kaydı
    YAZIYOR" iddiasının dar okuması."""
    log = subprocess.run(
        ["git", "-C", str(ROOT), "log", "--format=%s"],
        capture_output=True, text=True).stdout
    return {n for n in expand(log) if n not in SENTINEL_RANGE}


def body_only_unrecorded():
    """⚖️ İKİNCİ DESENİN GEREKLİLİĞİNİ ÖLÇEN ÇAPA (O-110, koordinatör hükmü).

    **Sorun:** bu kapı İKİ YÖNLÜ ama deseni TEK, ve desen genişliğinin iki
    yöndeki etkisi ZITTIR:
      · *öksüz* yönünde geniş desen DOĞRU — dar desen 57 sahte öksüz üretirdi
      · *eksik* yönünde geniş desen RİSKLİ — *"bkz. O-104"* diyen bir commit
        O-104'ü İDDİA ETMİŞ sayılır (*sözünü etmek ≠ kayıt*)

    **Ölçüldü (2026-08-12):** yalnız-gövde numarası **17** (geniş 101 − dar
    84); bunun **9'u** erken dönem kendi KAYIT commit'i (başlıkta `O-` hiç
    yok), **8'i** gerçek çapraz-atıf. Ama **zararlı alt-sınıf 0**: bu 17'nin
    defterde OLMAYANI yok — ve sebebi yapısal, tesadüf değil (yabancı
    numaralandırma ayrı önek kullanır: `M-O-`/`M-F-`; örnekler `9xx`te).

    **Hüküm:** ikinci deseni SPEKÜLATİF olarak yazma; GEREKLİLİĞİNİ ölç.
    > ***Bir kapıyı spekülatif olarak genişletmek yerine, genişlemenin
    > gerekliliğini ölç — o zaman ikinci deseni sen değil, KUSUR ister.***

    Bu fonksiyon o eşiği döndürür: yalnız gövdede anılan VE defterde kaydı
    OLMAYAN numaralar. **0 ise** tek desen güvenli ve gerekçesi CANLI;
    **>0 ise** iki yön iki ayrı desen ister (iddia için çapalı, bağ için
    geniş) ve öz-test bunu ADIYLA söyler.
    """
    commits, _ = commit_ids()
    body_only = commits - subject_ids()
    return sorted(body_only - defter_ids() - KNOWN_EMPTY - PRE_COMMIT_ERA)


def run() -> int:
    commits, census = commit_ids()
    with_ref, without_ref, total = census
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
    # PAYDA DENETİMİ — denklem tutmuyorsa kapı KENDİNE öter.
    if with_ref + without_ref != total:
        print(f"⛔ PAYDA TUTMUYOR: atıflı {with_ref} + atıfsız "
              f"{without_ref} = {with_ref + without_ref}, ama depoda {total} "
              f"commit var → tarama commit KAYBEDİYOR; bu kapının HER "
              f"sonucu şüpheli (sayının doğruluğu kendi kanıtı değildir)")
        bad = True
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
    risky = body_only_unrecorded()
    print(f"   ⚖️ tek-desen çapası: yalnız-gövde anılan VE defterde olmayan "
          f"= {len(risky)}{'' if not risky else ' → ' + ', '.join('O-%03d' % n for n in risky)}"
          f"  (0 iken tek desen güvenli; >0 ikinci deseni KUSUR ister)")
    print(f"   payda DENETLENDİ: atıflı {with_ref} + atıfsız {without_ref} "
          f"= {total} (rev-list ile birebir) · bilerek-boş "
          f"{len(KNOWN_EMPTY)} ({', '.join('O-%03d' % n for n in sorted(KNOWN_EMPTY))}) "
          f"· planlama-dönemi {len(PRE_COMMIT_ERA)} "
          f"· iki yönde ölçüldü (eksik 0 · öksüz 0)")
    return 0


def selftest() -> int:
    dead = []
    commits, census = commit_ids()
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
    # ③ SENTİNEL: `O-999` commit MESAJINDA geçiyor (bu kapının kendi
    #    docstring'i ve O-108'in mesajı) ama kayıt olarak SAYILMAMALI.
    #    Gravita'nın testinin bendeki hâli — ve buraya "devraldığım için"
    #    değil, ÖLÇÜMÜN KENDİSİ riski ürettiği için girdi.
    log_all = subprocess.run(["git", "-C", str(ROOT), "log", "--format=%s%n%b"],
                             capture_output=True, text=True).stdout
    if "O-999" not in log_all:
        dead.append("`O-999` commit geçmişinde artık YOK — sentinel testi "
                    "boşa koşuyor; ya gerekçe bayatladı ya geçmiş yazıldı")
    if 999 in commits:
        dead.append("SENTİNEL SIZDI: `O-999` kayıt sayılıyor — `9xx` aralığı "
                    "ayrılmış olmasına rağmen girdiye karışıyor")
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
    if (commits - defter - KNOWN_EMPTY - PRE_COMMIT_ERA
            - {n for n in defter if n > max(commits or {0})}):
        dead.append("BUGÜNKÜ ağaçta gedik var — olumsuz ikiz başarısız")
    # ⑤ İKİNCİ DESENİN GEREKLİLİĞİ — spekülatif genişletme yerine EŞİK.
    risky = body_only_unrecorded()
    if risky:
        dead.append(
            f"TEK DESEN ARTIK YETMİYOR: {len(risky)} numara yalnız GÖVDEDE "
            f"anılıyor ve defterde kaydı YOK ({', '.join('O-%03d' % n for n in risky)}) "
            f"— geniş desen bunları İDDİA sayıyor ama 'sözünü etmek ≠ kayıt'. "
            f"İki yön artık İKİ AYRI desen ister: iddia için ÇAPALI "
            f"(başlık), bağ için GENİŞ (başlık+gövde)")
    # ⑥ PAYDA denklemi öz-testte de sınanır: bozulursa kapı sessiz kalmasın.
    w, wo, tot = census
    if w + wo != tot:
        dead.append(f"PAYDA denklemi tutmuyor ({w}+{wo}≠{tot}) — kapının "
                    f"kendi sayımı commit kaybediyor")
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
