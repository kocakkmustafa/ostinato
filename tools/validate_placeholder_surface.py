#!/usr/bin/env python3
"""Beyan KAYNAKTA değil, KULLANICIDA da duruyor mu? (O-107)

**Lissom'un bulgusu, kendi ağacımda SABOTAJLA doğrulandı (2026-08-12):**
`setup-room-gap-body` kullanıcı cümlesi silindi, `// PLACEHOLDER(flow)`
kaynak işaretçisi bırakıldı →

    gen_placeholder_register.py --check  → EXIT 0  (YEŞİL)
    validate_surface_honesty.py          → EXIT 0  (YEŞİL)

Yani kullanıcıya verilen dürüst beyan **yok olurken iki kapı da sustu.**

> ***Kaynakta beyanlı olmak, KULLANICIYA beyanlı olmak değildir — iki ayrı
> yüzey, iki ayrı kapı.***

`gen_placeholder_register.py` **tasarımı gereği** kaynak katmanını korur
(`// PLACEHOLDER(...)` yorumlarını tarar). Bu kapı **eksik olan ikinci
katmanı** kapatır: bir yer tutucu KULLANICIYA görünen bir cümleyle
eşleşiyorsa, o cümle **kaybolamaz**.

## Şekil: BÖLME (⑤'in ve Lissom'un deseni), liste değil

Her işaretçi iki hâlden **birine** girmek ZORUNDA:
* `user-surface: <WidgetKey>` → o anahtar **sevk edilen kodda** bulunmalı;
  bulunamazsa kapı öter (Lissom'un vakası tam bu)
* `source-only: <gerekçe>` → kullanıcı yüzeyi **yok** ve bu **beyan edilmiş**

Üçüncü hâl (ikisi de yok) KIRMIZI. *Bir yer tutucunun kullanıcı yüzeyi olup
olmadığı bir KARARDIR; kararsız bırakmak, kaybı sessizleştirir.*

⛔ Bu kapı **davranış istemez**: `source-only` tamamen meşru bir cevaptır
(kameranın arkasındaki bir veri boşluğunun kullanıcı cümlesi olmayabilir).
Yasakladığı tek şey **kararsızlık** ve **sessiz kayıp**.
"""
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gen_placeholder_register import scan_dart_markers  # noqa: E402
# ⚠️ Yorum ayıklayıcı YENİDEN YAZILMADI, var olandan içe aktarıldı: iki
# bağımsız çıkarımın zamanla ayrışması bugün üç kez yaşandı. Üstelik bu
# ayıklayıcı STRING-FARKINDALI (bir dizge içindeki `//` yorum sanılmaz) —
# naif bir satır kontrolü onu kaçırırdı.
from validate_surface_honesty import strip_dart_comments  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
LIB = ROOT / "lib"

#: `user-surface:` değeri TEK BİR WIDGET ANAHTARIDIR (serbest metin değil) —
#: ilk yazımda `(.+?)` kullanmıştım ve işaretçinin geri kalanını da yutuyordu,
#: yani "anahtar sevk edilen kodda var mı" sorusu HİÇ SORULMUYORDU. Kapının
#: kendi ilk hâli, ölçtüğü kusurun aynısını taşıyordu.
BINDING_RE = re.compile(
    r"user-surface:\s*([A-Za-z0-9_\-]+)|source-only:\s*(\S.{9,}?)(?:\s*·|$)",
    re.IGNORECASE)
#: `key: const Key('x')` — sevk edilen koddaki kullanıcı-yüzeyi çapası.
KEY_RE = re.compile(r"Key\(\s*'([^']+)'\s*\)")


def shipped_keys():
    """SEVK EDİLEN koddaki widget anahtarları — YORUMLAR DÜŞÜRÜLÜR (O-111).

    🔴 **Neden (Lissom işaret etti, bende SABOTAJLA doğrulandı):** ilk yazım
    dosyayı HAM okuyordu, yani bir YORUM içindeki `Key('x')` de kanıt
    sayılıyordu. Sabotaj: gerçek `key: const Key('demo-live-gap-note')`
    satırı yoruma çevrildi → **kullanıcı yüzeyi sevk edilen koddan GİTTİ**
    ama kapı **EXIT=0** kaldı ve hâlâ *"2 kullanıcı yüzeyine bağlı"* dedi.

    > ***Bir kapının ÇIKTISI doğru olabilir ve İDDİASI yine de yanlış
    > olabilir:*** sayı doğruydu (2 anahtar gerçekten vardı), ama kapı onu
    > **yanlış tanığa sorarak** buldu — sayı doğru, GEREKÇE yok.

    ⚠️ Ve *"bugün 0 yorum-anahtarı var"* gerekçeyi ZAYIFLATMAZ, güçlendirir:
    42 gerçek / 0 yorum sayımı bir **alışkanlığın** sonucuydu, bir kuralın
    değil — ve o koşul hiçbir yerde yazılı değildi.
    """
    keys = set()
    for f in LIB.rglob("*.dart"):
        src = strip_dart_comments(f.read_text(encoding="utf-8"))
        keys |= set(KEY_RE.findall(src))
    return keys


def check(markers, keys):
    bad = []
    bound = source_only = 0
    for m in markers:
        text = m["text"] if isinstance(m, dict) else getattr(m, "text", "")
        where = m["file"] if isinstance(m, dict) else getattr(m, "source", "?")
        line = m.get("line", "") if isinstance(m, dict) else ""
        hit = BINDING_RE.search(text)
        if not hit:
            bad.append(
                f"{where}{line} — yer tutucu ne `user-surface:` ne "
                f"`source-only:` beyanı taşıyor (ÜÇÜNCÜ HÂL). Kullanıcıya "
                f"görünen bir cümlesi var mı YOK mu, bu bir KARARDIR; "
                f"kararsız bırakmak kaybı sessizleştirir")
            continue
        if hit.group(1):
            kind, value = "user-surface", hit.group(1).strip()
        else:
            kind, value = "source-only", (hit.group(2) or "").strip()
        if kind == "source-only":
            source_only += 1
            if len(value) < 10:
                bad.append(f"{where}{line} — `source-only:` gerekçesi çok "
                           f"kısa ({value!r}); beyan kendi kanıtı değildir")
            continue
        bound += 1
        if value not in keys:
            bad.append(
                f"{where}{line} — `user-surface: {value}` beyan edilmiş ama "
                f"o anahtar SEVK EDİLEN KODDA YOK. Kullanıcıya verilen "
                f"dürüst beyan kaybolmuş olabilir ve kaynak işaretçisi bunu "
                f"GİZLİYOR (Lissom'un vakası, bende sabotajla doğrulandı)")
    return bad, bound, source_only


def selftest() -> int:
    dead = []
    markers = scan_dart_markers()
    if not markers:
        dead.append("scan_dart_markers() BOŞ — kaydın ayrıştırıcısı ölmüş; "
                    "bu kapı hiçbir şey ölçmez (vakum)")
    keys = shipped_keys()
    if len(keys) < 10:
        dead.append(f"sevk edilen kodda yalnız {len(keys)} widget anahtarı "
                    f"bulundu (beklenen ≥10) — anahtar taraması kırık")
    # ① Bağsız (üçüncü hâl) yakalanıyor mu?
    if not check([{"file": "x", "line": "", "text": "hiçbir beyan yok"}],
                 keys)[0]:
        dead.append("ÜÇÜNCÜ HÂL yakalanmıyor — beyansız yer tutucu geçerdi")
    # ② Var olmayan anahtara bağlanmış beyan yakalanıyor mu? (Lissom'un vakası)
    if not check([{"file": "x", "line": 1,
                   "text": "user-surface: ZZQQ-yok-boyle-bir-anahtar"}],
                 keys)[0]:
        dead.append("KAYIP KULLANICI CÜMLESİ yakalanmıyor — Lissom'un vakası "
                    "bu kapıdan da geçerdi")
    # ③ OLUMSUZ İKİZ: gerçek bir anahtara bağlı beyan ÖTMEMELİ.
    # ⚠️ İnterpolasyonlu anahtarlar (`Key('band-scale-${d.id}')`) temsil
    # ETMEZ: değerleri çalışma anında oluşur ve `user-surface:` beyanında
    # sabit bir ad olarak yazılamaz. Olumsuz ikiz DÜZ bir anahtar seçer —
    # ilk yazımda `sorted(keys)[0]` interpolasyonlu olanı seçti ve öz-test
    # kendi kapısını yanlış-pozitifle suçladı.
    # ⭐ KALICI NEGATİF İKİZ (O-111) — bugün ürettiğim sabotajın kendisi.
    # Silinirse kapı aynı körlüğe yeniden açılır, ve o gün kimse bakmaz.
    probe = ("class X {\n"
             "  // key: const Key('ZZQQ-yorumda-kalan-anahtar'),\n"
             "  Widget b() => Text('x', key: const Key('ZZQQ-gercek'));\n"
             "}\n")
    from_comment = set(KEY_RE.findall(strip_dart_comments(probe)))
    if "ZZQQ-yorumda-kalan-anahtar" in from_comment:
        dead.append("YORUMDAKİ `Key()` hâlâ KANIT sayılıyor — kapı yanlış "
                    "tanığa soruyor (Lissom'un işaret ettiği tuzak, bende "
                    "sabotajla doğrulanmıştı)")
    if "ZZQQ-gercek" not in from_comment:
        dead.append("GERÇEK koddaki `Key()` ayıklayıcıdan sonra KAYBOLDU — "
                    "yorum düşürme fazla geniş, kanıtı da siliyor")
    plain = sorted(k for k in keys if "$" not in k)
    assert plain, "düz anahtar yok"
    real = plain[0]
    if check([{"file": "x", "line": "", "text": f"user-surface: {real}"}],
             keys)[0]:
        dead.append(f"GERÇEK anahtara bağlı beyan ötüyor ({real}) — "
                    f"yanlış-pozitif")
    if dead:
        print(f"⛔ {len(dead)} ÖLÜ DESEN (öz-test başarısız):")
        for d in dead:
            print(f"   - {d}")
        return 1
    print(f"✅ yer tutucu↔yüzey öz-testi GEÇTİ — üçüncü hâl · kayıp anahtar "
          f"yakalanıyor, gerçek anahtar yakalanMIYOR ({len(keys)} anahtar "
          f"taranıyor)")
    return 0


def main() -> int:
    if "--selftest" in sys.argv:
        return selftest()
    markers = scan_dart_markers()
    keys = shipped_keys()
    bad, bound, source_only = check(markers, keys)
    if bad:
        print(f"⛔ {len(bad)} YER TUTUCU↔YÜZEY İHLALİ:")
        for b in bad:
            print(f"   - {b}")
        return 1
    print(f"✅ yer tutucu↔yüzey TEMİZ — {len(markers)} işaretçi = "
          f"{bound} KULLANICI YÜZEYİNE bağlı ⊎ {source_only} `source-only` "
          f"(beyanlı); üçüncü hâl 0")
    print(f"   ⚠️ iki AYRI katman: kaynak işaretçisini "
          f"`gen_placeholder_register.py` korur, KULLANICI cümlesini BU kapı "
          f"korur (Lissom'un bulgusu, bende sabotajla doğrulandı)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
