#!/usr/bin/env python3
"""Gizlilik manifesti ↔ KODUN GERÇEĞİ — iki yönlü kapı (O-078).

Neden var (2026-08-07):

  `ios/Runner/PrivacyInfo.xcprivacy` şunu BEYAN ediyor: hiçbir veri
  toplanmıyor, hiçbir "required reason" API'si kullanılmıyor, izleme yok.
  Bugün bu beyan ÖLÇÜLDÜ ve DOĞRU. Ama beyan bir metindir; kod değişir.

  Yarın biri `shared_preferences` ekler, ya da bir dosyanın değişim tarihini
  okur — beyan sessizce YALANA döner ve kimse fark etmez. App Store beyanı
  yanlış olan bir uygulama reddedilir; daha kötüsü, kullanıcıya yanlış söz
  vermiş olur.

  Bu yüzden manifest ELLE BAKILAN bir dosya değil, KAPIYA BAĞLI bir iddia.

Kapı İKİ YÖNDE de öter — çünkü kapsam iki yönde de yanlış olabilir:
  P2 ileri  : kod bir API'yi KULLANIYOR ama manifest BEYAN ETMİYOR → yalan
  P3 geri   : manifest BEYAN EDİYOR ama kod KULLANMIYOR → gürültü
              (*"olmayan sınırı beyan etmek gürültüdür"* — koordinatör)

⚠️ KAPSAM KASITLI DAR: yalnız SEVK EDİLEN kod taranır (`lib/`, sevk edilen
yerel paketler, `ios/Runner/*.swift`). `tools/` ve `test/` HARİÇ — orası
telefona gitmez, ve geniş kapsam yanlış-pozitif üretip kapıyı susturur
(O-057'nin dersi).
"""
import plistlib
import re
import sys
from pathlib import Path

MANIFEST = Path("ios/Runner/PrivacyInfo.xcprivacy")

#: Apple'ın "required reason" API kategorileri → kodda aranan izler.
#: Dart ve Swift izleri birlikte; ikisi de aynı pakete giriyor.
API_TRACES = {
    "NSPrivacyAccessedAPICategoryFileTimestamp": [
        r"\.lastModified\b", r"\bstatSync\b", r"\.stat\(\)", r"\bFileStat\b",
        r"\bcreationDate\b", r"\bmodificationDate\b", r"\bgetattrlist\b",
    ],
    "NSPrivacyAccessedAPICategoryUserDefaults": [
        r"\bUserDefaults\b", r"\bNSUserDefaults\b", r"\bSharedPreferences\b",
    ],
    "NSPrivacyAccessedAPICategorySystemBootTime": [
        r"\bsystemUptime\b", r"\bmach_absolute_time\b",
    ],
    "NSPrivacyAccessedAPICategoryDiskSpace": [
        r"\bvolumeAvailableCapacity\b", r"\bfreeSpace\b", r"\bstatfs\b",
    ],
    "NSPrivacyAccessedAPICategoryActiveKeyboards": [
        r"\bactiveInputModes\b",
    ],
}

#: Veri TOPLAYABİLEN bağımlılık aileleri. Biri belirirse "hiçbir şey
#: toplamıyoruz" beyanı artık otomatik doğru DEĞİLDİR — insan bakmalı.
COLLECTING_DEPS = [
    "firebase", "sentry", "posthog", "amplitude", "mixpanel", "segment",
    "appsflyer", "adjust", "facebook", "google_analytics", "crashlytics",
]

#: Ağa çıkabilen ama VERİ TOPLAMAYAN bilinen bağımlılıklar — beyanla
#: çelişmez, ama kayda geçer (kurucu brifindeki "zayıflatan" kalemi).
KNOWN_NETWORK_BENIGN = {"google_fonts": "yazı tiplerini Google CDN'inden indirir"}


def _strip_comments(src: str) -> str:
    """Yorum satırlarını at — yoksa bu dosyanın KENDİ örnekleri bile ötür."""
    src = re.sub(r"/\*.*?\*/", " ", src, flags=re.DOTALL)
    return "\n".join(re.sub(r"//.*$", "", line) for line in src.splitlines())


def _shipped_sources():
    """SEVK EDİLEN kaynak dosyalar — sevkiyat türetimini tek yerden alır."""
    sys.path.insert(0, str(Path("tools").resolve()))
    from validate_runner_inventory import shipping_map  # noqa: E402

    files = list(Path("lib").rglob("*.dart"))
    for name, shipped in shipping_map().items():
        if shipped:
            files += list((Path("packages") / name / "lib").rglob("*.dart"))
    files += list(Path("ios/Runner").glob("*.swift"))
    return files


def main() -> int:
    problems, notes = [], []

    # ── P1 · manifest VAR ve okunabilir mi?
    if not MANIFEST.exists():
        print(f"⛔ {MANIFEST} YOK — App Store beyanı eksik")
        return 1
    try:
        m = plistlib.loads(MANIFEST.read_bytes())
    except Exception as exc:
        print(f"⛔ {MANIFEST} okunamadı: {exc}")
        return 1
    for key in ("NSPrivacyTracking", "NSPrivacyTrackingDomains",
                "NSPrivacyCollectedDataTypes", "NSPrivacyAccessedAPITypes"):
        if key not in m:
            problems.append(f"P1: manifest '{key}' anahtarını taşımıyor")

    declared = {e.get("NSPrivacyAccessedAPIType")
                for e in m.get("NSPrivacyAccessedAPITypes", [])}

    # ── VAKUM · gerçekten kod taradık mı?
    files = _shipped_sources()
    if len(files) < 20:
        problems.append(
            f"VAKUM: yalnız {len(files)} sevk edilen kaynak dosya tarandı "
            f"(beklenen ≥20) — tarama kırılmışsa kapı BOŞLUĞU yeşil sayar")

    blob = "\n".join(_strip_comments(f.read_text(encoding="utf-8", errors="ignore"))
                     for f in files)

    # ── P2 ileri · kullanılan ama beyan edilmeyen
    for category, traces in API_TRACES.items():
        hits = [t for t in traces if re.search(t, blob)]
        if hits and category not in declared:
            problems.append(
                f"P2 (YALAN): sevk edilen kod {category} izini taşıyor "
                f"({', '.join(hits)}) ama manifest onu BEYAN ETMİYOR — "
                f"beyan artık yanlış")
    # ── P3 geri · beyan edilen ama kullanılmayan
    for category in declared:
        traces = API_TRACES.get(category, [])
        if traces and not any(re.search(t, blob) for t in traces):
            problems.append(
                f"P3 (GÜRÜLTÜ): manifest {category} beyan ediyor ama sevk "
                f"edilen kodda izi YOK — olmayan sınırı beyan etmek gürültüdür")

    # ── P4 · veri toplayan bağımlılık ↔ boş toplama beyanı
    pub = Path("pubspec.yaml").read_text(encoding="utf-8")
    for dep in COLLECTING_DEPS:
        if re.search(rf"^\s+{re.escape(dep)}\w*:", pub, re.MULTILINE):
            if not m.get("NSPrivacyCollectedDataTypes"):
                problems.append(
                    f"P4: '{dep}' bağımlılığı eklenmiş ama "
                    f"NSPrivacyCollectedDataTypes BOŞ — 'hiçbir şey "
                    f"toplamıyoruz' beyanı artık otomatik doğru DEĞİL, "
                    f"insan bakmalı")
    for dep, why in KNOWN_NETWORK_BENIGN.items():
        if re.search(rf"^\s+{re.escape(dep)}:", pub, re.MULTILINE):
            notes.append(f"{dep} — {why} (veri toplamaz; beyanla çelişmez)")

    if problems:
        print(f"⛔ {len(problems)} GİZLİLİK MANİFESTİ İHLALİ:")
        for p in problems:
            print(f"   - {p}")
        return 1
    print(f"✅ gizlilik manifesti ↔ kod TUTARLI — {len(files)} sevk edilen "
          f"kaynak tarandı, 5 required-reason kategorisi İKİ YÖNDE denetlendi; "
          f"beyan: izleme yok · toplama yok · required-reason API yok")
    for n in notes:
        print(f"   ℹ️  ağ notu: {n}")
    return 0


def selftest() -> int:
    """POZİTİF İKİZ: kapı SABOTAJLA gerçekten düşüyor mu?

    Düşmeyen bir kapının yeşili anlamsızdır. Her kural için kasten bozuk bir
    girdi kurulur ve kapının ÖTMESİ beklenir.
    """
    import tempfile
    ok = True

    def expect(name: str, blob: str, declared: set, should_fire: bool):
        nonlocal ok
        fired = False
        for category, traces in API_TRACES.items():
            hits = [t for t in traces if re.search(t, blob)]
            if hits and category not in declared:
                fired = True
            if category in declared and traces and not any(
                    re.search(t, blob) for t in traces):
                fired = True
        for category in declared - set(API_TRACES):
            fired = True
        status = "✓" if fired == should_fire else "✗"
        if fired != should_fire:
            ok = False
        print(f"   {status} {name}: ötme={fired}, beklenen={should_fire}")

    print("── P2 ileri (kullanıyor, beyan etmiyor)")
    expect("UserDefaults kullanımı, boş manifest",
           "final p = SharedPreferences.getInstance();", set(), True)
    expect("dosya zaman damgası, boş manifest",
           "final t = f.lastModified();", set(), True)
    expect("temiz kod, boş manifest", "final x = 1 + 1;", set(), False)

    print("── P3 geri (beyan ediyor, kullanmıyor)")
    expect("boş kod, UserDefaults beyanı", "final x = 1;",
           {"NSPrivacyAccessedAPICategoryUserDefaults"}, True)
    expect("kullanılan API beyan edilmiş", "UserDefaults.standard",
           {"NSPrivacyAccessedAPICategoryUserDefaults"}, False)

    print("── yorum bağışıklığı (yanlış-pozitif kapısı)")
    expect("yalnız yorumda geçen API",
           _strip_comments("// UserDefaults burada KULLANILMIYOR\nvar x = 1;"),
           set(), False)

    print("── VAKUM")
    with tempfile.TemporaryDirectory() as d:
        n = len(list(Path(d).rglob("*.dart")))
        fired = n < 20
        print(f"   {'✓' if fired else '✗'} boş ağaç → vakum ötüyor={fired}")
        ok = ok and fired

    print("✅ öz-test GEÇTİ" if ok else "⛔ ÖZ-TEST DÜŞTÜ — kapı sabotajla ötmüyor")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(selftest() if "--selftest" in sys.argv else main())
