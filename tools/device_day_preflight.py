#!/usr/bin/env python3
"""F5 — cihaz günü ön-uçuş kontrolü (O-160, 2026-08-16).

Kurucu telefonu bağladığında BEŞ DAKİKADA çalıştırılacak tek komut: bağlı
cihazı bulur, GERÇEK UDID'sini çözer (`devicectl`in kendi pairing
identifier'ı DEĞİL — H-9/O-129 dersi, ikisi FARKLI değerler), Ostinato'nun
imza profiline karşı sınar, imza kimliğinin var olduğunu doğrular.

⚠️ Bu betik KURULUMU yapmaz (D9, ayrı adım) — yalnız kurulumdan ÖNCE
"bu neden patlayabilir"i söyler. `codesign geçti` ≠ `kurulur` ayrımı
(H-9): profil olması yetmez, O CİHAZIN UDID'si `ProvisionedDevices`te
olmalı; yoksa çözüm kod değil TAZELEME (`xcodebuild -allowProvisioningUpdates`).
"""
from __future__ import annotations

import json
import plistlib
import subprocess
import sys
from pathlib import Path

APP_ID = "com.yulalab.ostinato"
TEAM_ID = "T5HZGYBWK8"
PROFILE_DIRS = [
    Path.home() / "Library/Developer/Xcode/UserData/Provisioning Profiles",
    Path.home() / "Library/MobileDevice/Provisioning Profiles",
]


def run(cmd: list[str]) -> str:
    return subprocess.run(cmd, capture_output=True, text=True).stdout


def find_ostinato_profile() -> dict | None:
    """`ProvisionedDevices`/`ExpirationDate` gibi alanları taşıyan, BUGÜN
    Ostinato'ya ait profili bulur — dosya adına (UUID, KOŞUM-BAĞIMLI,
    profil yenilendikçe değişir) değil, İÇERİĞE göre arar."""
    best = None
    for d in PROFILE_DIRS:
        if not d.exists():
            continue
        for f in d.glob("*.mobileprovision"):
            der = subprocess.run(
                ["security", "cms", "-D", "-i", str(f)],
                capture_output=True,
            ).stdout
            try:
                doc = plistlib.loads(der)
            except Exception:
                continue
            appid = doc.get("Entitlements", {}).get("application-identifier", "")
            if appid != f"{TEAM_ID}.{APP_ID}":
                continue
            if best is None or doc.get("CreationDate", "") > best.get("CreationDate", ""):
                best = doc
                best["_file"] = str(f)
    return best


def connected_devices() -> list[dict]:
    """`devicectl list devices --json-output` yerine metin çıktısını
    ayrıştırır (JSON bayrağı bazı devicectl sürümlerinde ayrı bir dosyaya
    yazar, burada gereksiz karmaşıklık) — yalnız satır-tabanlı, kırılgan
    olmaması için `available (paired)` durumunu arar."""
    out = run(["xcrun", "devicectl", "list", "devices"])
    devices = []
    for line in out.splitlines()[2:]:
        parts = line.split()
        if len(parts) < 3 or "paired" not in line:
            continue
        identifier = next((p for p in parts if len(p) == 36 and p.count("-") == 4), None)
        if identifier:
            devices.append({"pairing_identifier": identifier, "raw_line": line})
    return devices


def resolve_real_udid(pairing_identifier: str) -> str | None:
    """`devicectl`in KENDİ pairing identifier'ı (ör. `882CC2EC-...`)
    `ProvisioningProfile`in beklediği UDID (ör. `00008120-...`) DEĞİLDİR
    — ikisi ayrı alan, H-9'un ölçtüğü tuzağın aynısı. Gerçek `udid`
    alanı `device info details` çıktısında ayrı satırdadır."""
    out = run(["xcrun", "devicectl", "device", "info", "details",
               "--device", pairing_identifier])
    for line in out.splitlines():
        # ⚠️ Satır başındaki işaret ASCII `?` DEĞİL, Unicode BULLET (U+2022)
        # — terminalde `?` görünüyordu (font fallback), gerçek bayt farklıydı
        # (`repr()`le ölçüldü). Öneke değil ALT DİZEYE bağlan, hangi bullet
        # karakteri kullanılırsa kullanılsın kırılmasın.
        stripped = line.strip()
        if "udid:" in stripped:
            return stripped.split("udid:", 1)[1].strip()
    return None


def signing_identities() -> list[str]:
    out = run(["security", "find-identity", "-v", "-p", "codesigning"])
    return [l.strip() for l in out.splitlines() if "valid identities" not in l and l.strip()]


def main() -> int:
    problems, ok = [], []

    idents = signing_identities()
    if not idents:
        problems.append("[imza] `security find-identity -v -p codesigning` SIFIR "
                         "geçerli kimlik döndü — hiçbir şey imzalanamaz.")
    else:
        ok.append(f"[imza] {len(idents)} geçerli codesign kimliği bulundu.")

    profile = find_ostinato_profile()
    if profile is None:
        problems.append(f"[profil] `{APP_ID}` için HİÇBİR provisioning profili "
                         f"bulunamadı — `xcodebuild -allowProvisioningUpdates` "
                         f"koşulmalı (Automatic signing profili kendi üretir).")
    else:
        exp = profile.get("ExpirationDate")
        ok.append(f"[profil] bulundu: {profile.get('Name')} "
                   f"(`{profile['_file']}`, bitiş {exp})")
        provisioned = set(profile.get("ProvisionedDevices", []))

        devices = connected_devices()
        if not devices:
            problems.append("[cihaz] `devicectl list devices` bağlı/eşleşmiş "
                             "hiçbir cihaz göstermiyor. ⚠️ H-9 uyarısı: bir "
                             "aracın 'yok' demesi yokluğun KANITI değil — "
                             "USB/Wi-Fi bağlantısını ve Ayarlar > Genel > "
                             "AirPlay ve Handoff'u kontrol et, gerekirse "
                             "`xctrace list devices` ile ikinci kaynaktan doğrula.")
        for dev in devices:
            real_udid = resolve_real_udid(dev["pairing_identifier"])
            if not real_udid:
                problems.append(f"[cihaz] {dev['pairing_identifier']}: gerçek "
                                 f"UDID çözülemedi (`devicectl device info "
                                 f"details` beklenen alanı vermedi).")
                continue
            if real_udid in provisioned:
                ok.append(f"[cihaz] {real_udid} PROFİLDE KAYITLI — kurulum "
                           f"tazeleme GEREKTİRMEMELİ.")
            else:
                problems.append(
                    f"[cihaz] {real_udid} profildeki {len(provisioned)} cihaz "
                    f"arasında YOK. Çözüm KOD DEĞİL TAZELEME: "
                    f"`xcodebuild -workspace ios/Runner.xcworkspace -scheme "
                    f"Runner -configuration Release -destination "
                    f"\"id={real_udid}\" -allowProvisioningUpdates build` "
                    f"(yeni profil o anki TÜM kayıtlı cihazları içerir).")

    print("═══ CİHAZ GÜNÜ ÖN-UÇUŞ ═══")
    for line in ok:
        print(f"✅ {line}")
    for line in problems:
        print(f"⛔ {line}")
    print()
    if problems:
        print(f"⛔ {len(problems)} SORUN — kurulumdan ÖNCE çözülmeli.")
        return 1
    print("✅ ÖN-UÇUŞ TEMİZ — kuruluma geçilebilir (D9, bu betiğin kapsamı DEĞİL).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
