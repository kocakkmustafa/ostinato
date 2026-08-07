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

Kapının DÖRT özelliği (JabLab'ın deseni + O-077):
  ① yeni bir koşum ÇIKARSA öter **ve ne yapılacağını söyler**
  ② SAYIYI değil KİMLİĞİ ölçer — paket sayısı doğru kalıp YERİ değişirse
     `dart test` sessizce yanlış dizine bakar: sayı yeşil, kapsam boş
  ③ analyzer kapsamı **DENEYLE** ölçüldü, varsayımla değil (aşağıda)
  ④ **SEVKİYAT** — bir koşumun VARLIĞI onun ALÂKASI değildir (O-077)

── ④ neden eklendi (2026-08-07, O-077) ────────────────────────────────────
Bu kapı J-145'e CEVABEN yazılmıştı ve "her koşum çağrılıyor mu?"yu doğru
ölçtü. Ama `run_gates.sh` düz *"3 Dart süiti"* diyordu ve ÖLÇÜLDÜ ki
`ostinato_audio` (81 test) uygulamanın `pubspec.yaml`ında YOK, `lib/`den hiç
import edilmiyor — yalnız `tools/dart_pilot` fixture üreticileri kullanıyor.

  **81 test, SEVK EDİLMEYEN kodu koruyor.**

Kusur pakette değil: paket kasten bağlanmamış (ses çıkışı kurucu kararı).
Kusur CÜMLEDE — "3 süit yeşil" kapsamı taşımayan bir cümle, tıpkı J-145'in
"N/N yeşil"i gibi. Yani kapının kendisi J-145'in kusurunu KENDİ kapsam
satırında tekrarlıyordu: **varlığı ölçtüm, alâkayı ölçmedim.**

Panzehir: kapsam cümlesi artık ELLE YAZILMIYOR — `--kapsam` ile ağaçtan
TÜRETİLİYOR ve sevk edilmeyen her koşum adıyla işaretleniyor.
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

#: ④ Elle yazılmış kapsam sayısı DESENİ — bu satır `run_gates.sh`ta bir daha
#: belirirse kapı öter. "3 Dart süiti" tam olarak O-077'nin cümlesiydi.
HANDWRITTEN_SCOPE = re.compile(r"\d+\s+Dart\s+süit", re.IGNORECASE)


def _pubspec_path_deps(pubspec: Path) -> set:
    """Bir pubspec'in `path:` ile bağladığı YEREL paket adları.

    Kaba ama KASITLI dar bir okuma: yalnız `path:` satırındaki son dizin adı.
    YAML ayrıştırıcısı bir bağımlılık daha getirirdi ve bu kapının kendisi
    bağımlılık eklememeli (kapı, ölçtüğü şeyin parçası olmamalı).
    """
    if not pubspec.exists():
        return set()
    out = set()
    for m in re.finditer(r"^\s+path:\s*(\S+)\s*$", pubspec.read_text(encoding="utf-8"),
                         re.MULTILINE):
        out.add(Path(m.group(1)).name)
    return out


def shipping_map() -> dict:
    """packages/* → SEVK EDİLİYOR mu? (ağaçtan TÜRETİLİR, elle yazılmaz)

    Sevk = uygulamanın `pubspec.yaml`ından `path:` ile bağlı, ya da bağlı bir
    paketin kendi `path:` bağımlılığı (geçişli kapanış).
    """
    local = {p.parent.name for p in Path("packages").glob("*/pubspec.yaml")}
    shipped = _pubspec_path_deps(Path("pubspec.yaml")) & local
    # geçişli kapanış
    while True:
        grew = set()
        for name in shipped:
            grew |= _pubspec_path_deps(Path("packages") / name / "pubspec.yaml") & local
        if grew <= shipped:
            break
        shipped |= grew
    return {name: (name in shipped) for name in sorted(local)}


def _imported_from_lib(name: str) -> bool:
    """İKİNCİ, BAĞIMSIZ sinyal: `lib/` gerçekten import ediyor mu?

    pubspec "bağlı" derken lib hiç import etmiyorsa bu da bir olgudur (ölü
    bağımlılık). Tek sinyale güvenmiyoruz — kapsam İKİ YÖNDE de yanlış olabilir.
    """
    pat = f"package:{name}/"
    return any(pat in f.read_text(encoding="utf-8", errors="ignore")
               for f in Path("lib").rglob("*.dart"))


def kapsam_line() -> str:
    """`run_gates.sh`ın KAPSAM cümlesi — ELLE DEĞİL, buradan TÜRETİLİR."""
    ship = shipping_map()
    sevk = [n for n, s in ship.items() if s]
    disi = [n for n, s in ship.items() if not s]
    lines = [
        "   Dart suitleri: kabuk (flutter test) + " + ", ".join(sorted(ship)),
        "     ├ SEVK EDILEN kodu kapsayan: kabuk, " + (", ".join(sevk) or "(yok)"),
    ]
    if disi:
        lines.append(
            "     └ SEVK EDILMEYEN kodu kapsayan: " + ", ".join(disi) +
            "  ⚠️ yesilleri urun hakkinda BIR SEY SOYLEMEZ")
    return "\n".join(lines)


def main() -> int:
    if "--kapsam" in sys.argv:
        print(kapsam_line())
        return 0
    problems = []
    gates = Path(GATES).read_text(encoding="utf-8")

    # ── ④ SEVKİYAT: kapsam cümlesi elle yazılmış mı?
    if HANDWRITTEN_SCOPE.search(gates):
        problems.append(
            "SEVKİYAT: `run_gates.sh` kapsam sayısını ELLE yazıyor (O-077). "
            "Türetilmiş liste elle yazılmaz — `--kapsam` çıktısını kullan; "
            "yoksa sevk EDİLMEYEN bir süit 'kapsandı' sanılır")
    if "--kapsam" not in gates:
        problems.append(
            "SEVKİYAT: `run_gates.sh` kapsam satırını TÜRETMİYOR — "
            "`python3 tools/validate_runner_inventory.py --kapsam` çağırmalı")

    ship = shipping_map()
    if not ship:
        problems.append("VAKUM: packages/ altında hiç paket bulunamadı — "
                        "sevkiyat türetimi kırılmış olabilir")
    for name, shipped in ship.items():
        if shipped and not _imported_from_lib(name):
            problems.append(
                f"SEVKİYAT ÇELİŞKİSİ: '{name}' pubspec'te bağlı ama `lib/` onu "
                f"hiç import etmiyor — ya ölü bağımlılık ya da kapsam yanılgısı")

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
