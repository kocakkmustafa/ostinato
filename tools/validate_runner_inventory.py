#!/usr/bin/env python3
"""Koşum envanteri — kapsamı KİŞİYE değil KAPIYA bağlar.

Neden var (2026-08-07, O-065 · JabLab J-145/d33012f aktarımı):

  JabLab kırk kez *"kapılar N/N yeşil"* yazdı; o **app süitiydi**, motor
  süiti J-104'ten beri kırmızıydı. Teşhisi keskin:

  > *"Asıl mesele CÜMLENİN BİÇİMİ, dikkat değil: 'N/N yeşil' kapsamı
  > taşımayan bir cümle olduğu sürece HEM YAZAN HEM OKUYAN aynı boşluğa
  > düşer."*

  *"Sormalıydım"* KİŞİYE yüklenen bir çözümdür ve tekrarlanabilir değildir.
  Bu kapı kapsamı **yapıya** bağlar.

Ostinato ailede **en parçalı** olan: dört ayrı koşum (kabuk · iki paket · 27
python betiği). JabLab'ın vakası İKİ koşumdu ve kırk yanlış rapora yetti.

Kapının üç özelliği (JabLab'ın deseni):
  ① yeni bir koşum ÇIKARSA öter **ve ne yapılacağını söyler**
  ② SAYIYI değil KİMLİĞİ ölçer — paket sayısı doğru kalıp YERİ değişirse
     `dart test` sessizce yanlış dizine bakar: sayı yeşil, kapsam boş
  ③ analyzer kapsamı **DENEYLE** ölçüldü, varsayımla değil (aşağıda)
"""
import re
import sys
from pathlib import Path

#: Bilinen koşumlar — KİMLİKLE (yol), sayıyla değil.
KNOWN_RUNNERS = {
    "kabuk": {"path": ".", "cmd": "flutter test", "kind": "dart"},
    "ostinato_posture": {"path": "packages/ostinato_posture",
                         "cmd": "dart test", "kind": "dart"},
    "ostinato_audio": {"path": "packages/ostinato_audio",
                       "cmd": "dart test", "kind": "dart"},
    "python kapıları": {"path": "tools", "cmd": "run_gates.sh", "kind": "py"},
}

#: ③ ANALYZER KAPSAMI — DENEYLE ölçüldü (2026-08-07), varsayılmadı.
#: İki pakete de KASITLI kullanılmayan import konup üç komut karşılaştırıldı:
#:   `flutter analyze lib test` (run_gates'in koştuğu) → 0 bulgu
#:   `flutter analyze`          (kapsamsız)            → 2 bulgu
#:   paket-içi `dart analyze`                          → 1 + 1 bulgu
#: SONUÇ: bizim analyzer koşumumuz KAPSAMLI olduğu için paketleri KAPSAMIYOR.
#: JabLab'da ikinci analyzer koşumu gereksizdi; BİZDE YÜK TAŞIYOR — o satır
#: silinirse paketler sessizce denetimsiz kalır ve `flutter analyze` yine
#: yeşil der. Bu yüzden kapı o satırın VARLIĞINI de kolluyor.
ANALYZER_EXPERIMENT = {
    "date": "2026-08-07",
    "scopedFindsPackages": False,
    "requiresSeparatePackageAnalyze": True,
}

GATES = "tools/run_gates.sh"


def main() -> int:
    problems = []
    gates = Path(GATES).read_text(encoding="utf-8")

    # ── ① Ağaçtaki GERÇEK koşumlar ↔ bilinenler
    found = {"kabuk", "python kapıları"}
    for pubspec in sorted(Path("packages").glob("*/pubspec.yaml")):
        found.add(pubspec.parent.name)
    known = set(KNOWN_RUNNERS)
    for extra in sorted(found - known):
        problems.append(
            f"YENİ KOŞUM: '{extra}' ağaçta var ama envanterde YOK. YAPILACAK: "
            f"(a) `run_gates.sh`a ekle (b) buraya KİMLİĞİYLE yaz "
            f"(c) her raporda sayısını AYRI bildir — 'N/N yeşil' kapsamı "
            f"taşımayan bir cümledir")
    for gone in sorted(known - found - {"kabuk", "python kapıları"}):
        problems.append(
            f"KAYIP KOŞUM: '{gone}' envanterde var ama ağaçta YOK — kayıt "
            f"bayat, ya paket taşındı ya silindi")

    # ── ② KİMLİK: her koşumun YOLU gerçekten orada mı?
    #    Sayı doğru kalıp yer değişirse `dart test` yanlış dizine bakar.
    for name, spec in KNOWN_RUNNERS.items():
        p = Path(spec["path"])
        if not p.exists():
            problems.append(
                f"KİMLİK: '{name}' yolu YOK ({spec['path']}) — sayı doğru "
                f"kalıp yer değiştiğinde koşum sessizce boş çalışır")
        elif spec["kind"] == "dart" and name != "kabuk":
            if not (p / "pubspec.yaml").exists():
                problems.append(f"KİMLİK: {spec['path']} pubspec taşımıyor")
            if not (p / "test").is_dir():
                problems.append(
                    f"KİMLİK: {spec['path']}/test YOK — `dart test` orada "
                    f"HİÇBİR ŞEY koşmaz ve YEŞİL döner (sahte yeşil)")

    # ── ① run_gates HER koşumu gerçekten çağırıyor mu?
    for name, spec in KNOWN_RUNNERS.items():
        if spec["kind"] != "dart" or name == "kabuk":
            continue
        if spec["path"] not in gates:
            problems.append(
                f"KAPSAM: '{name}' `run_gates.sh`ta ÇAĞRILMIYOR — tek komut "
                f"kapsamı taşımıyorsa kapsam kişiye kalır")
    if "flutter test" not in gates:
        problems.append("KAPSAM: kabuk süiti `run_gates.sh`ta çağrılmıyor")

    # ── ③ Analyzer deneyinin sonucu hâlâ geçerli mi?
    if ANALYZER_EXPERIMENT["requiresSeparatePackageAnalyze"]:
        if not re.search(r"dart analyze", gates):
            problems.append(
                "ANALYZER: deney (2026-08-07) `flutter analyze lib test`in "
                "paketleri KAPSAMADIĞINI ölçtü — ayrı `dart analyze` satırı "
                "ZORUNLU, ama `run_gates.sh`ta YOK. Silinirse paketler "
                "sessizce denetimsiz kalır ve analyze yine yeşil der")

    # ── VAKUM
    if len(found) < 3:
        problems.append(
            f"VAKUM: yalnız {len(found)} koşum bulundu (beklenen ≥3) — "
            f"`packages/*/pubspec.yaml` taraması kırılmış olabilir")

    if problems:
        print(f"⛔ {len(problems)} KOŞUM ENVANTERİ İHLALİ:")
        for p in problems:
            print(f"   - {p}")
        return 1
    print(f"✅ koşum envanteri TEMİZ — {len(found)} koşum, hepsi KİMLİĞİYLE "
          f"doğrulandı ve `run_gates.sh`ta çağrılıyor; analyzer deneyi "
          f"({ANALYZER_EXPERIMENT['date']}) hâlâ geçerli")
    return 0


if __name__ == "__main__":
    sys.exit(main())
