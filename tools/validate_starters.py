#!/usr/bin/env python3
"""START HERE şeridi — kimlik VERİDE mi, ekranda mı? (DESIGN-AHEAD §1.2)

Neden var (2026-08-13, O-117):

  Tasarım şeridin üç dersini ADIYLA veriyordu. En kolay inşa, o üç kimliği
  `library_screen.dart`a yazmaktı — ve o an şerit, içeriğin geri kalanından
  KOPARDI: ders yeniden adlandırılsa, kilitlense ya da kaldırılsa ekran
  eskimiş bir kapıyı göstermeye devam ederdi ve hiçbir şey ötmezdi.

  Bu, bu depoda zaten adı konmuş bir sınıf: `honesty.instrumentSpecificGap`
  aynı gerekçeyle veriye taşınmıştı — *"hangi boşluğun bu çalgının kendi
  boşluğu sayıldığı bir SEÇİMDİR, ve seçim ekran kodunda gömülü olsaydı
  gözden geçirilemezdi."*

Kapı DÖRT şeyi ölçer:
  ① her CANLI disiplin tam bir `starterLessonId` bildirir
  ② bildirilen kimlik o disiplinin derslerinde GERÇEKTEN vardır
  ③ giriş kapısı `locked` ya da `demoOnly` OLAMAZ — şeridin etiketi
    "Start here" ve bir çıkmaza ya da puanlanmayan bir derse işaret etmek
    etiketin kendisini yalanlar
  ④ ekran kodu HİÇBİR ders kimliği taşımaz (türetim gerçekten türetim mi)

⑤ `_why_starter` gerekçesi: bu depoda seçim gerekçesiz kalmaz (kural 6/10'un
   aynısı) — boş ya da yer-tutucu bir gerekçe ihlaldir.
"""
import json
import re
import sys
from pathlib import Path

LIB = Path("assets/content/library.json")
SCREEN = Path("lib/app/screens/library_screen.dart")

# Ders kimliği deseni: `<disiplin>.<kurs>.<ders>` — ekran kodunda BU
# görünmemeli. Nokta-ayrık üç parça, tırnak içinde.
LESSON_ID_IN_SOURCE = re.compile(r"""['"]([a-z_]+\.[a-z_]+\.[a-z_]+)['"]""")

# Gerekçe en az bu kadar uzun olmalı — "TODO"/"design" gibi tek kelimelik
# yer tutucuları eler. Sayı, `validate_library.py` kural 6'nın 20'siyle aynı
# aileden ama daha yüksek: gerekçe KAYNAK adlandırmalı, niyet beyan etmemeli.
MIN_WHY_LEN = 40


def load_lib(path=LIB):
    return json.loads(path.read_text(encoding="utf-8"))


def check(lib, screen_src):
    """Tüm ihlalleri döndürür. Saf fonksiyon — öz-test bunu mutasyonla çağırır."""
    violations = []

    for d in lib["disciplines"]:
        did = d["id"]
        if d.get("status") != "live":
            # coming_soon disiplin şerit kalemi bildirmemeli: gösterilecek
            # dersi yok. Bildiriyorsa bu sessiz bir tutarsızlık.
            if d.get("starterLessonId"):
                violations.append(
                    f"{did}: status={d.get('status')} ama starterLessonId "
                    f"bildiriyor (şeritte gösterilemez)")
            continue

        # ① bildirim var mı
        sid = d.get("starterLessonId")
        if not sid:
            violations.append(
                f"{did}: canlı disiplin ama starterLessonId YOK — şerit bu "
                f"çalgı için sessizce boş kalır (DESIGN-AHEAD §1.2)")
            continue

        # ② kimlik gerçekten var mı
        lessons = {l["id"]: l for c in d.get("courses", []) for l in c["lessons"]}
        if sid not in lessons:
            violations.append(
                f"{did}: starterLessonId '{sid}' bu disiplinin derslerinde YOK "
                f"({len(lessons)} ders tarandı) — ölü kapı")
            continue

        # ③ giriş kapısı çıkmaz olamaz
        status = lessons[sid].get("status", "open")
        if status in ("locked", "demoOnly"):
            violations.append(
                f"{did}: starter '{sid}' status={status} — 'Start here' "
                f"etiketi bir çıkmaza/puanlanmayan derse işaret edemez")

        # ⑤ gerekçe
        why = (d.get("_why_starter") or "").strip()
        if len(why) < MIN_WHY_LEN:
            violations.append(
                f"{did}: _why_starter yok/yer-tutucu ({len(why)} karakter, "
                f"en az {MIN_WHY_LEN}) — seçim gerekçesiz kalamaz")

    # ④ ekran kimlik taşımıyor
    for m in LESSON_ID_IN_SOURCE.finditer(screen_src):
        violations.append(
            f"{SCREEN}: ders kimliği KODA GÖMÜLÜ: '{m.group(1)}' — şerit "
            f"türetilmiş olmalı (kimlik `library.json`'ın starterLessonId'sinde)")

    return violations


def selftest():
    """Kapı ISIRIYOR mu — dört kuralın her biri kendi mutasyonuyla.

    Öz-testin kendi kuralı (O-116): kontroller CANLI DURUMA değil ÖZELLİĞE
    bağlanır. Aşağıdaki hiçbir vaka bugünkü içeriğin sayılarını okumuyor;
    hepsi kendi sentetik disiplinini kuruyor, yani içerik büyüdüğünde
    öz-test sessizce ölmez.
    """
    good_why = "x" * (MIN_WHY_LEN + 1)

    def disc(**over):
        base = {
            "id": "synth",
            "status": "live",
            "starterLessonId": "synth.c.a",
            "_why_starter": good_why,
            "courses": [{"id": "synth.c", "lessons": [
                {"id": "synth.c.a"},
                {"id": "synth.c.b", "status": "locked"},
            ]}],
        }
        base.update(over)
        return {"disciplines": [base]}

    cases = [
        ("① bildirim yok", disc(starterLessonId=None), "", "starterLessonId YOK"),
        ("② ölü kimlik", disc(starterLessonId="synth.c.zzz"), "", "derslerinde YOK"),
        ("③ kilitli starter", disc(starterLessonId="synth.c.b"), "", "status=locked"),
        ("⑤ gerekçe yok", disc(_why_starter="kisa"), "", "_why_starter"),
        ("⑥ coming_soon bildiriyor",
         disc(status="coming_soon"), "", "gösterilemez"),
        ("④ ekrana gömülü kimlik", disc(),
         "const id = 'guitar.foundations.camera_space';", "KODA GÖMÜLÜ"),
    ]

    failures = []
    for name, lib, src, needle in cases:
        vs = check(lib, src)
        if not any(needle in v for v in vs):
            failures.append(f"{name}: mutasyon İNMEDİ (beklenen '{needle}', "
                            f"bulunan {vs or 'HİÇBİR ihlal'})")

    # POZİTİF İKİZ: temiz girdi SIFIR ihlal vermeli. Yoksa kapı her şeye
    # kırmızı veriyordur ve yukarıdaki altı vaka hiçbir şey kanıtlamaz.
    clean = check(disc(), "// hiçbir kimlik yok")
    if clean:
        failures.append(f"pozitif ikiz: temiz girdi {len(clean)} ihlal verdi: {clean}")

    if failures:
        print(f"⛔ öz-test {len(failures)} KUSUR:")
        for f in failures:
            print(f"   - {f}")
        return 1
    print(f"✅ starter kapısı öz-testi — {len(cases)} mutasyonun {len(cases)}'i "
          f"indi + pozitif ikiz temiz")
    return 0


def main():
    if "--selftest" in sys.argv:
        return selftest()

    lib = load_lib()
    violations = check(lib, SCREEN.read_text(encoding="utf-8"))
    if violations:
        print(f"⛔ {len(violations)} START HERE İHLALİ:")
        for v in violations:
            print(f"   - {v}")
        return 1

    live = [d for d in lib["disciplines"] if d.get("status") == "live"]
    named = [f"{d['id']}→{d['starterLessonId'].split('.')[-1]}" for d in live]
    print(f"✅ START HERE şeridi TÜRETİLMİŞ — {len(live)} canlı disiplin, "
          f"{len(live)} kalem: {', '.join(named)} · ekranda gömülü kimlik 0")
    return 0


if __name__ == "__main__":
    sys.exit(main())
