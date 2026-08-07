#!/usr/bin/env python3
"""Kapsam-dışı listesini TAKSONOMİDEN üretir — "Not here — and why".

Neden var (2026-08-07, O-050 · JabLab'ın 7→12 deseninin Ostinato hâli):

  `comingSoonInThisDiscipline` bugüne dek ELLE yazılmış üçer kalemdi ve
  hepsi ÖLÇÜM engellerini anlatıyordu ("şu eşik yok", "şu alet yok"). Oysa
  `config/error-taxonomy.w1.json` ikinci ve daha güçlü bir kapsam-dışı
  sınıfı MAKİNE-OKUNUR biçimde zaten taşıyor: `inV1Scope: false` işaretli,
  gerçek öğretmenlerin ADIYLA andığı hatalar — kaçının bağımsız kanalda
  geçtiği (`independentChannels`) ve kameranın onu neden göremeyeceği
  (`observable`) dahil.

  Yani liste elle uzatılabilirdi; bunun yerine VAR OLAN veriden TÜRETİLDİ.
  Fark, aile kuralının ta kendisi: türetimli listeler elle yazılmaz. Elle
  yazılsaydı taksonomiye yeni bir kapsam-dışı hata eklendiği gün çalgı
  sayfası sessizce eksik kalırdı — ve eksikliği hiçbir kapı görmezdi.

Üretilen alan: `honesty.outOfScopeDerived`. `comingSoonInThisDiscipline`
ELLE yazılmaya devam eder ve bu betik ona DOKUNMAZ — iki liste iki AYRI
sınıf: biri "ölçemediğimiz için yok", diğeri "kapsam dışı bıraktığımız için
yok". İkisini tek listede toplamak, iki farklı gerekçeyi tek gerekçe gibi
göstermek olurdu.

`--check`: üretilen alan kaynakla aynı mı? (regen sonrası bayatlamayı kapatan
kilit taşı — `gen_posture_contract.py --check` ile aynı desen.)
"""
import json
import sys
from collections import OrderedDict
from pathlib import Path

TAXONOMY = "config/error-taxonomy.w1.json"
LIBRARY = "assets/content/library.json"

#: `observable` alanının kullanıcıya söylenecek hâli. İCAT DEĞİL çeviri:
#: taksonominin kendi etiketini cümleye çeviriyoruz, yeni bir iddia
#: eklemiyoruz. Bilinmeyen bir etiket gelirse SESSİZCE ATLANMAZ — hata verir,
#: çünkü sessiz atlama tam da bu kapının kapattığı arıza.
OBSERVABLE_PHRASE = {
    "invisible": "a camera cannot see it at all",
    "partially-visible": "a camera can only see part of it",
    "visible": "a camera can see it, but we do not cover it here",
}


#: Türkçeye özgü harfler. Taksonomi iki dilli yazılmış (`names` kimi yerde
#: [Türkçe, İngilizce], kimi yerde yalnız İngilizce) ve KONUMSAL bir kural
#: YOK — yani `names[0]` almak kullanıcıya Türkçe cümle gönderebilir, ki ilk
#: üretimde tam olarak bu oldu (gitar kalemi Türkçe çıktı). Kütüphane baştan
#: sona İngilizce; bu yüzden İngilizce aday SEÇİLİR, bulunamazsa SESSİZCE
#: ATLANMAZ — hata verilir.
TURKISH_CHARS = set("ğĞşŞıİöÖüÜçÇâÂîÎûÛ")


def english_name(err):
    names = err.get("names") or []
    for n in names:
        if not (set(n) & TURKISH_CHARS):
            return n.strip()
    raise SystemExit(
        f"⛔ {err['code']}: `names` içinde İngilizce aday YOK "
        f"({names!r}). Kütüphane İngilizce — Türkçe bir adı kullanıcıya "
        f"göndermektense kapıyı kırmızı yakıyoruz.")


def entry(err):
    name = english_name(err)
    obs = err.get("observable")
    if obs not in OBSERVABLE_PHRASE:
        raise SystemExit(
            f"⛔ {err['code']}: bilinmeyen observable={obs!r} — "
            f"cümleye çevrilemiyor. Etiket eklendiyse OBSERVABLE_PHRASE'e de "
            f"eklenmeli; sessizce atlamak kapsamı gizler.")
    ch = err.get("independentChannels")
    channels = (f"{ch} independent teaching channels name it"
                if isinstance(ch, int) and ch > 1
                else "teachers name it")
    # ⚠️ HAM HATA KODU YÜZEYE SIZMAZ (aile kuralı). İlk üretimde cümlenin
    # sonuna `(G-PRACTICE-NO-ISOLATION)` koymuştum — kullanıcıya hiçbir şey
    # söylemeyen, bize ait bir tanımlayıcı. Kod `_outOfScopeDerived_source`
    # kaydında duruyor: izlenebilirlik KAYITTA, yüzeyde değil.
    return (f"{name} — deliberately out of scope. {channels[0].upper()}"
            f"{channels[1:]}, and {OBSERVABLE_PHRASE[obs]}. "
            f"We would rather leave it out by name than pretend to watch it.")


def build():
    tax = json.loads(Path(TAXONOMY).read_text(encoding="utf-8"))
    out = {}
    for inst, blk in tax["instruments"].items():
        items = [entry(e) for e in blk["errors"]
                 if not e.get("inV1Scope", True)]
        out[inst] = sorted(items)
    return out


def main():
    check = "--check" in sys.argv
    derived = build()
    path = Path(LIBRARY)
    lib = json.loads(path.read_text(encoding="utf-8"),
                     object_pairs_hook=OrderedDict)

    stale = []
    for disc in lib["disciplines"]:
        want = derived.get(disc["id"], [])
        have = disc.get("honesty", {}).get("outOfScopeDerived", [])
        if have != want:
            stale.append(f"{disc['id']}: {len(have)} → {len(want)}")
        if not check:
            disc["honesty"]["outOfScopeDerived"] = want
            disc["honesty"]["_outOfScopeDerived_source"] = (
                f"URETILDI: tools/gen_out_of_scope.py <- {TAXONOMY} "
                f"(inV1Scope=false olan hatalar: "
                f"{', '.join(sorted(e['code'] for e in json.loads(Path(TAXONOMY).read_text(encoding='utf-8'))['instruments'][disc['id']]['errors'] if not e.get('inV1Scope', True)))}). "
                f"ELLE DUZENLEME. "
                f"comingSoonInThisDiscipline AYRI ve elle yazilir: o liste "
                f"'olcemedigimiz icin yok', bu liste 'kapsam disi biraktigimiz "
                f"icin yok' — iki ayri gerekce, tek listede toplanmaz.")

    if check:
        # VAKUM (O-059): taksonomi okunamaz ya da filtre kırılırsa türetim
        # BOŞ döner, kütüphane de boşsa "taze" görünür — sahte yeşil.
        if sum(len(v) for v in derived.values()) == 0:
            print("❌ VAKUM: taksonomiden HİÇ kapsam-dışı kalem türemedi — "
                  "`inV1Scope` filtresi ya da dosya yolu kırılmış olabilir; "
                  "'taze' hükmü GEÇERSİZ")
            return 1
        if stale:
            print("❌ kapsam-dışı listesi BAYAT (kod/taksonomi değişti, "
                  "yeniden üretilmedi):")
            for s in stale:
                print(f"   - {s}")
            print("   `python3 tools/gen_out_of_scope.py` koş.")
            return 1
        total = sum(len(v) for v in derived.values())
        print(f"✅ kapsam-dışı listesi TAZE — {total} kalem, "
              f"{TAXONOMY}'den türedi")
        return 0

    path.write_text(json.dumps(lib, ensure_ascii=False, indent=1) + "\n",
                    encoding="utf-8")
    total = sum(len(v) for v in derived.values())
    print(f"✅ kapsam-dışı listesi üretildi — {total} kalem "
          f"({', '.join(f'{k}:{len(v)}' for k, v in sorted(derived.items()))})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
