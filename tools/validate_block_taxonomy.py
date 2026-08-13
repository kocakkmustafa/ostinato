#!/usr/bin/env python3
"""A4 — AÇILMAYAN DERSLERİN ENGEL TAKSONOMİSİ, türetilir (O-124).

**Ölçüt (`YAYIN-HAZIRLIK-OLCUTU.md` A4):** *"Çıkmaz sokak sayısı ölçülmüş ve
ADIYLA yazılmış"*, kanıt: **taksonomi + payda ve İŞLEM.**

## Kovalar — ölçüt dosyasında TANIMLI, burada UYGULANIR

| kova | tanım | kimde |
|---|---|---|
| `A`  | içerik hiç yazılmamış | içerik kapasitesi |
| `A'` | içerik başlamış, **referans yok** | hasat turu |
| `B`  | içerik var, **bağlı değil** | hat |
| `C`  | kart hiç olmamalıydı | hat |
| `D`  | **TAM + BAĞLI, bilerek KAPALI** | çoğunlukla kurucu |
| `E`  | **awaiting-capability** — ölçüm ALETİ yok | yetenek işi |

## 🔴 NEDEN BU KAPI BÖYLE KURULDU — kırılganlığı GÜRÜLTÜLÜ yapmak

Sınıf, dersin kendi düzyazısından okunur. Düzyazı-regex'i kırılgandır ve bu
depo haklı olarak ona güvenmez: *bir eşleşme bir sebep değildir.* Panzehir
metni daha akıllı desenler yazmak DEĞİL, **eksikliği sessiz olmaktan
çıkarmaktır**:

> ### ***HER AÇILMAYAN DERS, TAM OLARAK BİR KURALA UYMALI.***
> Sıfır eşleşme → *desen kör kaldı ya da yeni bir engel biçimi doğdu.*
> İki eşleşme → *kovalar örtüşüyor, sınıflandırma karar vermiyor.*
> **İkisi de KIRMIZI.** Böylece desen bir gün metne yetişemezse, kapı yanlış
> bir sınıf uydurmaz — **bağırır.**

⚠️ Bu kapı bir SAYIYI dondurmaz. Dağılım değişebilir ve değişmesi
İYİDİR (bir engel kalkarsa kalem kova değiştirir, ölçüt bunu zaten söylüyor:
*bir sınıflandırma kalemlerin BUGÜNKÜ engelini gösterir*). Kapının koruduğu
şey dağılım değil, **her kalemin bir sınıfının OLDUĞU ve o sınıfın
kaynaktan TÜREDİĞİ**.
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LIBRARY = ROOT / "assets" / "content" / "library.json"

#: `E` — ALET eksikliği. Üçü de ürünün KENDİ cümlesinden alındı, uydurulmadı:
#: · mikrofon girişi yok (6 derste birebir bu cümle)
#: · "a missing measurement TOOL, not a missing threshold" (el/bilek landmark'ı)
#: · "we only measure angles today" (omuz YÜKSEKLİĞİ metriği yok)
E_MARKERS = re.compile(
    r"no microphone input|missing measurement TOOL|only measure angles")

#: `A'` — REFERANS eksikliği: yeni bir HASAT gerekiyor (eşik değil).
#: Ürünün cümlesi: *"this is a new harvest — not a threshold"*.
APRIME_MARKERS = re.compile(r"harvest")


def lessons():
    d = json.loads(LIBRARY.read_text(encoding="utf-8"))
    for di in d["disciplines"]:
        for c in di.get("courses", []):
            for l in c.get("lessons", []):
                yield di["id"], c["id"], l


def blob(l):
    """Dersin ENGEL METNİ — kullanıcıya görünen gerekçe + açılma koşulu."""
    return " ".join([
        l.get("lockedReason", ""),
        l.get("demoOnlyReason", ""),
        json.dumps(l.get("promotionPath", {}), ensure_ascii=False),
    ])


def classify(l):
    """(sınıf, sebep) — ya da eşleşme tekil değilse (None, açıklama)."""
    # `D` YAPIDAN gelir, düzyazıdan değil: `demoOnly` demek *ölçüm gösteriliyor,
    # not verilmiyor* demektir — içerik TAM ve BAĞLI, kapalılık KASITLI.
    if l.get("status") == "demoOnly":
        return "D", "status=demoOnly → ölçüm gösteriliyor, not KASITLI olarak yok"
    t = blob(l)
    hits = []
    if E_MARKERS.search(t):
        hits.append(("E", "ALET eksikliği: " +
                     ", ".join(sorted(set(E_MARKERS.findall(t))))))
    if APRIME_MARKERS.search(t):
        hits.append(("A'", "REFERANS eksikliği: yeni HASAT gerekiyor"))
    if len(hits) == 1:
        return hits[0]
    if not hits:
        return None, ("HİÇBİR kurala uymuyor — desen kör kaldı ya da YENİ bir "
                      "engel biçimi doğdu; sınıfı UYDURMAK yerine kapı ötüyor")
    return None, ("BİRDEN ÇOK kurala uyuyor (%s) — kovalar örtüşüyor ve "
                  "sınıflandırma karar VERMİYOR" % ", ".join(h[0] for h in hits))


def measure():
    total, blocked, rows, bad = 0, [], [], []
    for _di, _c, l in lessons():
        total += 1
        if "status" not in l:
            continue
        blocked.append(l)
        cls, why = classify(l)
        if cls is None:
            bad.append((l["id"], why))
        else:
            rows.append((l["id"], l["status"], cls, why))
    return total, blocked, rows, bad


def selftest() -> int:
    """SENTETİK ikizler — gerçek içeriğin bugünkü hâline bağlı DEĞİL."""
    dead = []
    cases = [
        ({"status": "locked", "lockedReason": "there is no microphone input"},
         "E", "tek E işareti"),
        ({"status": "locked",
          "promotionPath": {"unblockedBy": "a new harvest of footage"}},
         "A'", "tek A' işareti"),
        ({"status": "demoOnly", "demoOnlyReason": "a new harvest would help"},
         "D", "demoOnly YAPIDAN gelir — düzyazıdaki `harvest` onu EZEMEZ"),
        ({"status": "locked", "lockedReason": "no microphone input",
          "promotionPath": {"unblockedBy": "a new harvest"}},
         None, "İKİ işaret → karar verilmemeli, ötmeli"),
        ({"status": "locked", "lockedReason": "bilinmeyen yeni bir engel"},
         None, "HİÇ işaret → sınıf uydurulmamalı, ötmeli"),
    ]
    for i, (lesson, want, note) in enumerate(cases, 1):
        got, _why = classify(lesson)
        if got != want:
            dead.append(f"ikiz-{i} ({note}): {got!r} verdi, {want!r} "
                        f"bekleniyordu")
    # VAKUM: içerik dosyası okunabiliyor ve açılmayan ders GERÇEKTEN var mı?
    # (Bir 'ihlal 0' bulgusundan önce: ölçülecek bir şey var mı?)
    _t, blocked, _r, _b = measure()
    if not blocked:
        dead.append("VAKUM: hiç açılmayan ders bulunamadı — ya `status` alanı "
                    "yeniden adlandırıldı ya içerik boşaldı; 'taksonomi temiz' "
                    "iddiası GEÇERSİZ")
    if dead:
        print(f"⛔ {len(dead)} ÖLÜ DESEN (öz-test başarısız):")
        for d in dead:
            print(f"   - {d}")
        return 1
    print(f"✅ taksonomi öz-testi GEÇTİ — beş sentetik ikiz (tek-E · tek-A' · "
          f"demoOnly YAPIDAN · çift-eşleşme ÖTÜYOR · sıfır-eşleşme ÖTÜYOR), "
          f"bu ağaçta {len(blocked)} açılmayan ders")
    return 0


def main() -> int:
    if "--selftest" in sys.argv:
        return selftest()
    total, blocked, rows, bad = measure()
    if bad:
        print(f"⛔ {len(bad)} DERSİN ENGEL SINIFI TÜRETİLEMEDİ:")
        for lid, why in bad:
            print(f"   - {lid}: {why}")
        return 1
    dist = {}
    for _id, _st, cls, _why in rows:
        dist[cls] = dist.get(cls, 0) + 1
    offering = total - len(blocked)
    print(f"✅ A4 TAKSONOMİSİ TÜRETİLDİ — her açılmayan ders TAM BİR sınıfa "
          f"düşüyor")
    print(f"   İŞLEM: {total} ders = {offering} iş sunan ⊎ {len(blocked)} "
          f"açılmayan   [payda = {len(blocked)}]")
    print(f"   dağılım: " + " · ".join(
        f"{k} {dist.get(k, 0)}" for k in ("A", "A'", "B", "C", "D", "E")))
    for lid, st, cls, why in sorted(rows, key=lambda r: (r[2], r[0])):
        print(f"     [{cls:<2}] {lid:<42} ({st}) — {why}")
    # 🔴 KARAR-DEĞERİ: E'nin kaçı TEK BİR yetenekte birleşiyor?
    mic = [r[0] for r in rows
           if r[2] == "E" and "no microphone input" in r[3]]
    if mic:
        print(f"   🔴 E'nin {len(mic)}'i TEK bir eksik yetenekte birleşiyor: "
              f"MİKROFON GİRİŞİ YOK")
        for m in mic:
            print(f"       · {m}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
