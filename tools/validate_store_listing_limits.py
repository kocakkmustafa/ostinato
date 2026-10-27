#!/usr/bin/env python3
"""Mağaza metninin MEKANİK kısıtını ölçer — uzunluk, varlık, $ sözleşmesi (H-78/H-82).

## Neden var

`H-78` (2026-08-17, orkestratör): üç listing yan yana okunduğunda `playStore/shortDescription`
92 karakter çıktı, Play limiti 80 — ve iki kardeş kapı (Gravita: sayı-katalog uyuşması,
JabLab: vaat/ölçüm dili) hiçbiri KARAKTER LİMİTİ ölçmüyordu. İhlal tam da kapısı olmayan
hatta çıktı. `H-82`: Ostinato'ya bu kapıyı KUR görevi verildi.

Limitler `ventures/motion-core/workspace/MAGAZA-ALAN-LIMITLERI.md`nin (aile katmanı, TEK
otorite) `## 📐 LİMİTLER` tablosundan ÇALIŞMA-ANINDA okunur — burada bir KOPYA tutulmaz
(`H-58`: kopya = güncelleme borcu). O dosya değişirse bu kapı otomatik izler; parse hiçbir
satır bulamazsa (desen kayboldu/dosya taşındı) kapı KÖR olduğunu söyler, sessizce geçmez.

    python3 tools/validate_store_listing_limits.py            # 14 dil gerçek dosyalarla
    python3 tools/validate_store_listing_limits.py --selftest # sınırlar + sabotaj + vakum
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LISTING = ROOT / "docs" / "store" / "listing.json"
# K-6 (2026-10-27): EN kaynak + her `listing.<dil>.json` (14 mağaza dili).
LISTINGS = (LISTING, *sorted(LISTING.parent.glob("listing.*.json")))
LIMITS_MD = ROOT.parent.parent / "motion-core" / "workspace" / "MAGAZA-ALAN-LIMITLERI.md"

# Ostinato'da SEVK EDİLEN alanlar → MAGAZA-ALAN-LIMITLERI.md'deki karşılığı.
# playStore/title BİLİNÇLİ YOK (H-78 §4b kararı: appStore/name'den türer, O-157 emsali) —
# bu yüzden burada listelenmiyor, yokluğu bir hata DEĞİL.
SHIPPED_FIELDS = {
    ("appStore", "name"): "appStore/name",
    ("appStore", "subtitle"): "appStore/subtitle",
    ("appStore", "promotionalText"): "appStore/promotionalText",
    ("appStore", "keywords"): "appStore/keywords",
    ("playStore", "shortDescription"): "playStore/shortDescription",
    (None, "description"): "description",
}

# $ sözleşmesi (MAGAZA-ALAN-LIMITLERI.md §🚪): her blokta hangi anahtarlar SEVK edilir
# (bu yüzden $ TAŞIMAZ). Bu kümede olmayan her anahtar $ İLE BAŞLAMALI — yoksa yeni bir
# alan sessizce sızmış ya da bir gerekçe alanı yanlışlıkla $ almadan kalmış demektir.
SHIPPED_KEYS_BY_BLOCK = {
    # supportUrl / privacyPolicyUrl: Apple'ın ZORUNLU tuttuğu iki alan (H-83).
    # Beş app ortak sayfa kullanır; değer kurucu kararıdır (H-85), hat seçmez.
    # Bu kapı orkestratör alanları eklerken gerçekten öttü ve doğru öttü —
    # beyaz listeye alınmadan geçselerdi "sessizce sızan sevk alanı" olurlardı.
    "$root": {"appStore", "playStore", "description", "cameraPermissionRationale",
              "supportUrl", "privacyPolicyUrl"},
    "appStore": {"name", "subtitle", "promotionalText", "keywords"},
    "playStore": {"shortDescription"},
    "cameraPermissionRationale": {"ios", "android"},
}


def parse_limits(md_text: str) -> dict[str, int]:
    """`| \\`key\\` | **N** |` satırlarını çıkarır. Desen bulunamazsa BOŞ döner —
    çağıran bunu 'limit yok' değil 'kapı KÖR' olarak okumalı."""
    limits = {}
    for m in re.finditer(r"\|\s*`([^`]+?)`(?:\s*\(full\))?\s*\|\s*\*\*(\d+)\*\*\s*\|", md_text):
        limits[m.group(1)] = int(m.group(2))
    return limits


def check_lengths(listing: dict, limits: dict[str, int]) -> list[str]:
    """Saf fonksiyon — dosya okumaz. Öz-test bunu sahte listing+limits ile çağırır."""
    errors = []
    if not limits:
        errors.append(
            "⛔ KÖR: MAGAZA-ALAN-LIMITLERI.md'den TEK bir limit okunamadı — dosya "
            "taşınmış ya da tablo formatı değişmiş olabilir. Bu 'limit yok' demek "
            "DEĞİL, bu kapı hiçbir şey ÖLÇEMEDİ demek.")
        return errors

    for (block, field), limit_key in SHIPPED_FIELDS.items():
        value = listing.get(block, {}).get(field) if block else listing.get(field)
        limit = limits.get(limit_key)
        if limit is None:
            errors.append(
                f"⛔ KÖR: '{limit_key}' için MAGAZA-ALAN-LIMITLERI.md'de bir satır "
                f"bulunamadı — tablo değişmiş olabilir.")
            continue
        if value is None:
            errors.append(f"⛔ VARLIK: '{limit_key}' listing.json'da YOK (zorunlu alan).")
            continue
        # ASC keywords sınırı virgüller dahil UTF-8 byte; diğer alanlar karakter.
        is_keywords = limit_key == "appStore/keywords"
        length = len(value.encode("utf-8")) if is_keywords else len(value)
        unit = "UTF-8 byte" if is_keywords else "karakter"
        if length > limit:
            errors.append(
                f"⛔ UZUNLUK: '{limit_key}' {length} {unit}, belgelenmiş limit "
                f"{limit} (+{length - limit}) — yükleme reddedebilir.")
    return errors


def check_dollar_contract(listing: dict) -> list[str]:
    errors = []

    def scan(block: dict, name: str, whitelist: set[str]):
        for key in block:
            is_dollar = key.startswith("$")
            in_whitelist = key in whitelist
            if in_whitelist and is_dollar:
                errors.append(
                    f"⛔ $ sözleşmesi: {name}.{key} sevk edilen bir alan ama $ taşıyor.")
            elif not in_whitelist and not is_dollar:
                errors.append(
                    f"⛔ $ sözleşmesi: {name}.{key} ne beyaz listede ne $ öneki taşıyor "
                    f"— yeni bir sevk-alanı mı sessizce sızdı, yoksa bir gerekçe alanı "
                    f"$ almadan mı kaldı?")

    scan(listing, "$root", SHIPPED_KEYS_BY_BLOCK["$root"])
    if isinstance(listing.get("appStore"), dict):
        scan(listing["appStore"], "appStore", SHIPPED_KEYS_BY_BLOCK["appStore"])
    if isinstance(listing.get("playStore"), dict):
        scan(listing["playStore"], "playStore", SHIPPED_KEYS_BY_BLOCK["playStore"])
    if isinstance(listing.get("cameraPermissionRationale"), dict):
        scan(listing["cameraPermissionRationale"], "cameraPermissionRationale",
             SHIPPED_KEYS_BY_BLOCK["cameraPermissionRationale"])
    return errors


def check(listing: dict, limits: dict[str, int]) -> list[str]:
    return check_lengths(listing, limits) + check_dollar_contract(listing)


BASE_LIMITS = {
    "appStore/name": 30, "appStore/subtitle": 30, "appStore/promotionalText": 170,
    "appStore/keywords": 100, "playStore/title": 30, "playStore/shortDescription": 80,
    "description": 4000,
}


def _ok_listing() -> dict:
    return {
        "appStore": {"name": "A" * 8, "subtitle": "B" * 27, "promotionalText": "C" * 140,
                     "keywords": "D" * 100},
        "playStore": {"shortDescription": "E" * 76, "$shortDescriptionWhy": "gerekçe"},
        "description": "F" * 1411,
        "cameraPermissionRationale": {"ios": "G" * 10, "$source": "kaynak"},
        "$ageRating": {"$why": "..."},
        "$doc": "...",
    }


def self_test() -> int:
    ok = _ok_listing()

    # POZİTİF İKİZ: bugünkü doğru veriler sessizce geçmeli.
    errs = check(ok, BASE_LIMITS)
    if errs:
        print("⛔ TERS İKİZ BAŞARISIZ: doğru metin yanlışlıkla kırmızı yaktı:")
        for e in errs:
            print(f"   {e}")
        return 1
    print("✅ pozitif ikiz: bugünkü doğru veriler sessizce geçti")

    # Çok byte'lı keyword sınırı: 50 × ü = 100 byte geçer, 51 × ü = 102 byte kalır.
    for count, accepted in ((50, True), (51, False)):
        boundary = json.loads(json.dumps(ok))
        boundary["appStore"]["keywords"] = "ü" * count
        errs = check(boundary, BASE_LIMITS)
        if bool(errs) == accepted:
            print(f"⛔ UTF-8 keyword sınırı yanlış: {count * 2} byte, {errs}")
            return 1
    print("✅ UTF-8 keyword sınırı: 100 byte kabul, 102 byte ret")

    # SABOTAJ ①: bir alan limiti 1 karakter aşıyor.
    sab1 = json.loads(json.dumps(ok))
    sab1["playStore"]["shortDescription"] = "E" * 81
    errs = check(sab1, BASE_LIMITS)
    if not any("UZUNLUK" in e and "playStore/shortDescription" in e for e in errs):
        print("⛔ SABOTAJ YAKALANMADI: limit+1 karakter kırmızı yakmadı.")
        return 1
    print("✅ sabotaj (uzunluk +1): yakalandı")

    # SABOTAJ ②: $ önekisiz, beyaz-listede olmayan bir alan sessizce sızıyor.
    sab2 = json.loads(json.dumps(ok))
    sab2["appStore"]["surpriseField"] = "sızan alan"
    errs = check(sab2, BASE_LIMITS)
    if not any("$ sözleşmesi" in e and "surpriseField" in e for e in errs):
        print("⛔ SABOTAJ YAKALANMADI: $ önekisiz sızan alan yakalanmadı.")
        return 1
    print("✅ sabotaj ($ sözleşmesi ihlali): yakalandı")

    # VAKUM: limit tablosu tamamen kaybolursa (desen değişti/dosya taşındı) kapı
    # sessizce geçmemeli, kör olduğunu SÖYLEMELİ.
    errs = check(ok, {})
    if not any("KÖR" in e for e in errs):
        print("⛔ VAKUM YAKALANMADI: boş limit tablosu sessizce geçti (kapı kör "
              "olduğunu fark etmedi).")
        return 1
    print("✅ vakum (limit tablosu kayboldu): kapı kör olduğunu söyledi")

    print("\n✅ 6/6 kapı ateşlendi (pozitif ikiz + 2 UTF-8 sınırı + 2 sabotaj + vakum)")
    return 0


def main() -> int:
    if "--selftest" in sys.argv:
        return self_test()

    if not LIMITS_MD.exists():
        print(f"⛔ KÖR: aile limit dosyası yok: {LIMITS_MD}")
        return 1

    limits = parse_limits(LIMITS_MD.read_text(encoding="utf-8"))
    failed = False
    for path in LISTINGS:
        if not path.exists():
            print(f"⛔ beklenen dosya yok: {path}")
            failed = True
            continue
        listing = json.loads(path.read_text(encoding="utf-8"))
        errors = check(listing, limits)
        if errors:
            for e in errors:
                print(f"{path.name}: {e}")
            failed = True
            continue
        print(f"✅ {path.name} MEKANİK kısıtları geçti — {len(SHIPPED_FIELDS)} alan "
              f"uzunluk/varlık, keywords UTF-8 byte, $ sözleşmesi temiz")
    return int(failed)


if __name__ == "__main__":
    sys.exit(main())
