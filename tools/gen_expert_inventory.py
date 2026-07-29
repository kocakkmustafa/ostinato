#!/usr/bin/env python3
"""Uzman-turu envanterini RULESET BAYRAKLARINDAN ÜRETİR (M-F-125 okuyucu-ii).

Neden üretilen, elle yazılan değil: kurucunun uzman/antrenör turu bugüne
kadar el-listesiydi — ve el-listesi, config değiştiğinde SESSİZCE bayatlar.
Yeni bir `expertPending` kod eklenir, listeye yazılmaz; bir kod doğrulanır,
listeden silinmez. İkisi de kimseye görünmez. Bu betik listeyi her koşumda
config'ten YENİDEN türetir — bayat olamaz, çünkü kaynağı tek.

Bu, `expertPending` bayrağının İKİNCİ zorunlu okuyucusudur (birincisi
`validate_library.py` kural 7: bayrak canlı yüzeye çıkmayı ENGELLER).
Beşinci canlılık sorusunun cevabı: bayrağı kim okuyor? — kapı + bu envanter.

Üç sınıf AYRI raporlanır, çünkü uzmandan istenen şey farklı:
  · **expertPending (koşullu)** — ölçüm ALETİ VAR, eşik/eşleme uzman onayı
    bekliyor. Uzmana sorulacak: "bu eşik doğru mu?"
  · **aspirational** — ölçüm ALETİ YOK (`blockedByTool` ile isimli). Uzmana
    sorulacak bir şey YOK; bu bir MÜHENDİSLİK borcu, uzman turu değil.
    Karıştırmak, uzmanın vaktini olmayan bir ölçüme harcatır.
  · **doğrulanmış** — ne bayrak ne blok; envanterde yalnız sayı olarak.
"""
import json
import sys
from pathlib import Path

RULESETS = Path("config/rulesets")


def main() -> int:
    pending, aspirational, settled = [], [], []
    for f in sorted(RULESETS.glob("*.json")):
        cfg = json.loads(f.read_text(encoding="utf-8"))
        module = cfg.get("module", f.stem)
        for e in cfg.get("errors", []):
            row = {"module": module, "code": e.get("code"),
                   "evaluateAt": e.get("evaluateAt"),
                   "observable": e.get("_observable"),
                   "sources": e.get("_sources")}
            if e.get("status") == "aspirational":
                row["blockedByTool"] = e.get("blockedByTool")
                row["why"] = e.get("_why")
                aspirational.append(row)
            elif e.get("expertPending"):
                cond = e.get("condition") or {}
                row["threshold"] = f"{cond.get('metric')} {cond.get('op')} {cond.get('value')}"
                row["askExpert"] = "Bu eşik doğru mu? (metrik ölçülebiliyor, eşik doğrulanmadı)"
                pending.append(row)
            else:
                settled.append(row)

    out = {
        "$why": "ÜRETİLEN envanter — elle düzenleme, `tools/gen_expert_inventory.py` koş. "
                "Kaynak: config/rulesets/*.json bayrakları (M-F-125 okuyucu-ii).",
        "expertPending": pending,
        "aspirational_engineeringDebt_notForExpert": aspirational,
        "settledCount": len(settled),
    }
    dest = Path("docs/g1/uzman-turu-envanteri.json")
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(json.dumps(out, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")

    print(f"UZMAN TURU ENVANTERİ (üretildi: {dest})\n")
    print(f"🟡 Uzmana SORULACAK — eşik doğrulaması bekleyen {len(pending)} kod:")
    for r in pending:
        print(f"   [{r['module']}] {r['code']:28} {r['threshold']}  ({r['sources']})")
    print(f"\n🔧 Uzmana SORULMAYACAK — ölçüm aleti olmayan {len(aspirational)} kod "
          f"(mühendislik borcu):")
    for r in aspirational:
        print(f"   [{r['module']}] {r['code']:28} eksik alet: {r['blockedByTool']}")
    print(f"\n✅ Bayraksız (doğrulanmış/koşulsuz) kod sayısı: {len(settled)}")
    if not pending and not aspirational:
        print("\n(hiç bekleyen yok — uzman turu gerektiren kalem kalmadı)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
