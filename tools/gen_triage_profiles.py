#!/usr/bin/env python3
"""`config/triage/*.json` profillerini TEK KAYNAKTAN üretir.

Neden bu betik sonradan yazıldı: üretilen dosyalar başlarında
"_generated_from: … ELLE DÜZENLEME — orayı düzenle, bunu yeniden üret"
taşıyordu ama **üretici yoktu**. Üretildiğini iddia eden, üreticisi olmayan
dosya = uygulanmayan bir tek-kaynak iddiası; kaynak ile türev sessizce
ayrışır ve ayrıştığını kimse fark etmez. Nitekim `movementRomPolicy`
kaynağa eklendiğinde profillere kendiliğinden geçmedi.

`--check` kaynakla türevin ayrışıp ayrışmadığını sınar (kapı olarak koşulur),
argümansız çağrı yeniden üretir.
"""
import json
import sys
from pathlib import Path

SOURCE = Path("config/triage-thresholds.w1.json")
OUT_DIR = Path("config/triage")


def build(doc):
    """Kaynaktan profil-başına rig-uyumlu belge üret."""
    out = {}
    for name, prof in doc["profiles"].items():
        body = {
            "_generated_from": f"{SOURCE} (tek kaynak) — bu dosyayı ELLE DÜZENLEME; "
                               f"kaynağı düzenle ve `tools/gen_triage_profiles.py` koş",
            "_profile": name,
        }
        # Kaynakta eşikler profilin KENDİSİNDE düz duruyor; `note` alanı
        # gerekçedir, eşik değildir — rig'e eşik diye geçmemeli.
        if prof.get("note"):
            body["_rationale"] = prof["note"]
        body["thresholds"] = {k: v for k, v in prof.items() if k != "note"}
        # M-F-45 politikası profile TAŞINIR: rig `load_rom_policy`yi triyaj
        # profilinden okur. Kaynakta durup profile geçmezse, hasat sessizce
        # muhafazakâr varsayılana (passiveExecutionPossible=True) düşer ve
        # hangi hareket için neyin beyan edildiği görünmez olur.
        if "movementRomPolicy" in doc:
            body["movementRomPolicy"] = {
                k: v for k, v in doc["movementRomPolicy"].items() if not k.startswith("_")
            }
            body["_movementRomPolicyWhy"] = doc["movementRomPolicy"].get("_why", "")
        return_key = OUT_DIR / f"{name}.json"
        out[return_key] = body
    return out


def main():
    doc = json.loads(SOURCE.read_text(encoding="utf-8"))
    built = build(doc)
    check = "--check" in sys.argv
    drifted = []

    for path, body in built.items():
        text = json.dumps(body, ensure_ascii=False, indent=1) + "\n"
        if check:
            current = path.read_text(encoding="utf-8") if path.exists() else ""
            if current != text:
                drifted.append(path.name)
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text, encoding="utf-8")

    if check:
        if drifted:
            print(f"❌ türev kaynaktan AYRIŞMIŞ: {', '.join(drifted)}")
            print(f"   düzeltmek için: python3 {Path(__file__).name}")
            return 1
        print(f"✅ {len(built)} profil kaynakla eşleşiyor")
        return 0

    print(f"✅ {len(built)} profil üretildi: {', '.join(p.name for p in built)}")
    pol = doc.get("movementRomPolicy", {})
    for k, v in pol.items():
        if not k.startswith("_"):
            print(f"   movementRomPolicy.{k} = passiveExecutionPossible:{v}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
