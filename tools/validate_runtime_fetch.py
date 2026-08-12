#!/usr/bin/env python3
"""Çalışma-anı kaynak çekmesi GÖRÜNÜR olsun (O-104).

**Sevk (koordinatör, 2026-08-12):** `google_fonts` üretimde çalışma anında
Google'ın sunucularından font indiriyor — **beş hatta da**. Kusurun şekli
Kural E2'nin aynı ailesinden ama AĞ tarafında:

> Çekme, testler ağsız geçsin diye **TESTLERDE** kapatılmış → ***hiçbir test
> bu davranışı GÖREMEZ, çünkü testler onu görmeyecek şekilde
> yapılandırılmış.*** Kapı yok değil, **kapı KÖR EDİLMİŞ** — ve körlük **iyi
> niyetle** konmuş.

**⛔ BU KAPI DAVRANIŞI DEĞİŞTİRMEZ.** Font paketlemek ya da üretimde
`allowRuntimeFetching`i kapatmak bir **ürün duruşu** kararıdır ve
**kurucudadır**. Kapının işi tek şey: durumu **ölçmek** ve **BEYAN EDİLMİŞ**
hâlle karşılaştırmak. Beyan ile ölçüm ayrışırsa öter.

**Desen ADAPTE (icat değil):** Kural E2'nin biçimi — *özne + ölçüm ADRESİ* —
ve JabLab'ın `networkCapable` bölmesindeki gerekçe derinliği. JabLab'ın
cümlesi burada da geçerli, kendi ağacımda yeniden ölçüldü:

> ***Kendi kodunda ağ olmaması, ürününde ağ olmaması demek değildir.***

## Neden BEYAN + ÖLÇÜM, neden salt ölçüm değil

Salt ölçüm "bugün şu durumda" der ve sessizce değişir. Beyan, o durumu bir
KARAR NOKTASINA çevirir: durum değişirse (ör. biri üretimde çekmeyi kapatır,
ya da font paketlenir) kapı öter ve **kayıt tazelenmek zorunda kalır.**
Ayrıca ASİMETRİ beyan edilir: kaç test dosyası çekmeyi kapatıyor, üretim
kapatıyor mu. *Bir test-ikizinin gerçeğin kuralını uygulamaması, sessiz
kalamaz.*
"""
import re
import sys
from pathlib import Path

LIB = Path("lib")
TEST = Path("test")
PUBSPEC = Path("pubspec.yaml")

#: Üretimde font sağlayıcısını KULLANAN çağrılar.
FONT_API = re.compile(r"GoogleFonts\.")
#: Çekmeyi kapatan satır (hangi ağaçta olursa).
FETCH_DISABLED = re.compile(r"allowRuntimeFetching\s*=\s*false")

# ── BEYAN — her alan bir ÖLÇÜM ADRESİ taşır (E2 ilkesi) ──────────────────
#
# ⚠️ Bu bir MUAFİYET değil, KARAR NOKTASI. Sayılar ölçümle ayrışırsa kapı
# öter ve kaydın tazelenmesi gerekir; kayıt kendi kanıtı değildir.
DECLARED = {
    "productionFetchesAtRuntime": True,
    "productionFontApiCalls": 3,
    "productionFetchDisabled": False,
    "bundledFontAssets": 0,
    "testFilesDisablingFetch": 8,
    "$why": (
        "ÖLÇÜLDÜ 2026-08-12. Üretim `ostinato_theme.dart` içinde "
        "`GoogleFonts.hankenGrotesk` · `GoogleFonts.ibmPlexMono` · "
        "`GoogleFonts.hankenGroteskTextTheme` kullanıyor; `lib/` içinde "
        "`allowRuntimeFetching = false` YOK; `pubspec.yaml`ın `fonts:` bölümü "
        "şablon yorumu hâlinde ve depoda .ttf/.otf SIFIR → font yüzleri ilk "
        "açılışta Google'dan iniyor. Kullanıcı verisi gönderilmiyor."),
    "$asymmetry": (
        "8 test dosyası çekmeyi KAPATIYOR, üretim kapatmıyor → hiçbir test bu "
        "davranışı göremez. Körlük iyi niyetle (ağsız test) konmuş ve "
        "TESTLERİ DOĞRU, ürünü YANLIŞ temsil ediyor. Bu asimetri bir kusur "
        "olarak DEĞİL, adıyla bir GERÇEK olarak kayıtlı; kapatma kararı "
        "kurucuda (ürün duruşu: font paketlemek mi, çevrimdışı ilk açılışı "
        "kabul etmek mi)."),
    "$founderDecision": (
        "AÇIK: fontları uygulamaya gömmek (boyut artar, ağsız ilk açılış "
        "düzelir) mi, yoksa çevrimdışı ilk açılışta sistem fontuna düşmeyi "
        "kabul etmek mi. Kapı bu kararı VERMEZ, görünür tutar."),
}


def detect(prod_sources, test_sources, bundled_names):
    """SAF DEDEKTÖR — dosya sistemine DOKUNMAZ, verilen kaynakları ölçer.

    ⚠️ Neden ayrıldı (O-116): öz-test *"üretimde HİÇ font API çağrısı
    bulunamadı"* diye ötüyordu, yani kontrol **bugünkü DURUMA** dayanıyordu.
    Ölçüldü (sabotaj): font gömülüp `GoogleFonts.*` kaldırılınca öz-test
    **EXIT=1** verdi — oysa font gömmek **kurucunun açık kararı ve İSTENEN
    sonuç.**

    > ***BİR KAPI, KENDİ ÜRÜNÜNÜN İLERLEMESİNİ CEZALANDIRIYORSA, O KAPI
    > ÜRÜNÜN DÜŞMANIDIR*** — ve yanlış alarm veren kapılar, GERÇEK kapıları
    > öldüren basıncı üretir.

    Kontrolün NİYETİ *"çalışma-anı-çekme DEDEKTÖRÜ çalışıyor"*dur, *"ürün
    bugün çekiyor"* değil. Bu fonksiyon o niyeti **sonuçtan bağımsız**
    sınanabilir kılar: kapı gerçek kaynağı okumaya DEVAM EDER, yalnız
    öz-testin fixture'ı sentetikleşir.
    """
    prod_calls = sum(len(FONT_API.findall(re.sub(r"//.*", "", s)))
                     for s in prod_sources)
    prod_disabled = any(FETCH_DISABLED.search(re.sub(r"//.*", "", s))
                        for s in prod_sources)
    test_disabling = [i for i, s in enumerate(test_sources)
                      if FETCH_DISABLED.search(s)]
    return prod_calls, prod_disabled, test_disabling


def measure():
    """Bugünkü gerçek — dosyalardan, beyandan DEĞİL."""
    prod = [f.read_text(encoding="utf-8") for f in sorted(LIB.rglob("*.dart"))]
    tests = [f.read_text(encoding="utf-8") for f in sorted(TEST.rglob("*.dart"))]
    prod_calls, prod_disabled, test_disabling = detect(prod, tests, [])
    test_disabling = sorted(
        str(f) for f in TEST.rglob("*.dart")
        if FETCH_DISABLED.search(f.read_text(encoding="utf-8")))
    bundled = [str(p) for p in Path(".").rglob("*.ttf")] + \
              [str(p) for p in Path(".").rglob("*.otf")]
    bundled = [b for b in bundled
               if not re.search(r"(^|/)(build|ios/Pods|\.dart_tool)(/|$)", b)]
    return {
        "productionFetchesAtRuntime": prod_calls > 0 and not prod_disabled
                                      and not bundled,
        "productionFontApiCalls": prod_calls,
        "productionFetchDisabled": prod_disabled,
        "bundledFontAssets": len(bundled),
        "testFilesDisablingFetch": len(test_disabling),
        "_testFiles": test_disabling,
    }


def check(declared, actual):
    bad = []
    for key in ("productionFetchesAtRuntime", "productionFontApiCalls",
                "productionFetchDisabled", "bundledFontAssets",
                "testFilesDisablingFetch"):
        if declared[key] != actual[key]:
            bad.append(f"«{key}»: BEYAN {declared[key]!r} · ÖLÇÜM "
                       f"{actual[key]!r} — beyan ölçümle ayrıştı, kayıt "
                       f"tazelenmeli (beyan kendi kanıtı değildir)")
    # ASİMETRİ beyanı ZORUNLU: testler görmüyorsa bu adıyla yazılı olmalı.
    if actual["testFilesDisablingFetch"] > 0 and not actual[
            "productionFetchDisabled"]:
        if not str(declared.get("$asymmetry", "")).strip():
            bad.append("TEST↔ÜRETİM ASİMETRİSİ beyan edilmemiş: testler "
                       "çekmeyi kapatıyor, üretim kapatmıyor → hiçbir test bu "
                       "davranışı göremez ve bu SESSİZ kalamaz")
    for field in ("$why", "$founderDecision"):
        if not str(declared.get(field, "")).strip():
            bad.append(f"«{field}» boş — beyan ölçüm ADRESİNİ ve açık kararı "
                       f"taşımak zorunda")
    return bad


def selftest() -> int:
    """Kapı, ölçümü GERÇEKTEN yapıyor mu — yoksa beyanı mı okuyor?"""
    dead = []
    actual = measure()
    # ✅ SENTETİK DEDEKTÖR SINAMASI (O-116) — sonuçtan BAĞIMSIZ.
    # Eskiden burada `actual["productionFontApiCalls"] < 1` vardı ve font
    # gömüldüğü gün öterdi; artık dedektörün KENDİSİ sınanıyor.
    calls, disabled, tests_off = detect(
        ["final t = GoogleFonts.hankenGrotesk();  // gerçek çağrı",
         "// GoogleFonts.ibmPlexMono(); yalnız YORUM — sayılmamalı"],
        ["void main(){ GoogleFonts.config.allowRuntimeFetching = false; }",
         "void main(){ /* kapatmıyor */ }"], [])
    if calls != 1:
        dead.append(f"DEDEKTÖR: sentetik kaynakta 1 gerçek çağrı beklenirken "
                    f"{calls} bulundu (yorumdaki çağrı sayılmamalı) — "
                    f"çalışma-anı-çekme dedektörü bozuk")
    if len(tests_off) != 1:
        dead.append(f"DEDEKTÖR: sentetik testlerden 1'i çekmeyi kapatıyor, "
                    f"{len(tests_off)} saptandı — `allowRuntimeFetching` "
                    f"deseni bozuk")
    if detect(["GoogleFonts.config.allowRuntimeFetching = false;"], [], [])[1] \
            is not True:
        dead.append("DEDEKTÖR: üretimde çekme kapatılmışken saptanmıyor")
    if detect(["final x = 1;"], [], [])[0] != 0:
        dead.append("DEDEKTÖR: font çağrısı OLMAYAN kaynakta çağrı buluyor "
                    "(yanlış-pozitif)")
    # Beyan/ölçüm karşılaştırması gerçekten ısırıyor mu?
    if not check({**DECLARED, "bundledFontAssets": 999}, actual):
        dead.append("beyan-ölçüm karşılaştırması ISIRMIYOR — uydurma bir sayı "
                    "(999) fark edilmedi")
    if not check({**DECLARED, "$asymmetry": ""}, actual):
        dead.append("ASİMETRİ beyanı boşken kapı susuyor — sessiz kalması "
                    "yasak olan tam bu")
    if check(DECLARED, actual):
        dead.append("BUGÜNKÜ beyan ölçümle ayrışıyor — olumsuz ikiz başarısız")
    if dead:
        print(f"⛔ {len(dead)} ÖLÜ DESEN (öz-test başarısız):")
        for d in dead:
            print(f"   - {d}")
        return 1
    print("✅ çekme kapısı öz-testi GEÇTİ — ölçüm canlı (3 çağrı · 8 test "
          "dosyası), uydurma sayı ve boş asimetri beyanı yakalanıyor")
    return 0


def main() -> int:
    if "--selftest" in sys.argv:
        return selftest()
    actual = measure()
    bad = check(DECLARED, actual)
    if bad:
        print(f"⛔ {len(bad)} ÇEKME BEYANI İHLALİ:")
        for b in bad:
            print(f"   - {b}")
        return 1
    state = ("ÜRETİMDE ÇALIŞMA ANINDA ÇEKİYOR"
             if actual["productionFetchesAtRuntime"] else "çekmiyor")
    print(f"✅ çalışma-anı çekmesi BEYANLA UYUŞUYOR — durum: {state}")
    print(f"   ölçüm: üretimde {actual['productionFontApiCalls']} font API "
          f"çağrısı · üretimde çekme kapatılmamış "
          f"({not actual['productionFetchDisabled']}) · paketlenmiş font "
          f"{actual['bundledFontAssets']}")
    print(f"   ⚠️ ASİMETRİ (adıyla): {actual['testFilesDisablingFetch']} test "
          f"dosyası çekmeyi kapatıyor, ÜRETİM kapatmıyor → hiçbir test bu "
          f"davranışı GÖREMEZ")
    print(f"   ⏳ KURUCU KARARI AÇIK: font gömme mi, çevrimdışı ilk açılışı "
          f"kabul mü (kapı bu kararı VERMEZ, görünür tutar)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
