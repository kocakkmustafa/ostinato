#!/usr/bin/env python3
"""Ürün, kullanıcının ÜRETTİĞİ değeri saklıyor mu — GÖRÜNÜR olsun (O-133).

## Neden bu kapı doğdu

`A` tablosunun tamamı yeşilken ölçüldü ki **Ostinato kullanıcının yaptığı
hiçbir şeyi hatırlamıyor**: tüm `lib/` ağacında tek yazma çağrısı var
(`onboarding_store.dart`, yalnız *"onboarding bitti"* bayrağı). Bir kullanıcı
dersi çalışır, ölçüm yapılır, sonuç ekranı çizilir — **ekran kapanınca hepsi
yok olur.**

> ***BİR KONTROL LİSTESİNİN YEŞİL OLMASI, SORDUĞU SORULAR KADAR BİR ŞEY
> KANITLAR.*** Ölçüt yüzeylerin DÜRÜSTLÜĞÜNÜ ve GEZİLEBİLİRLİĞİNİ ölçüyor;
> hiçbir kalemi *"ürün, kullanıcının ürettiği değeri SAKLIYOR MU"* diye
> sormuyor. `A1` *"oturum→sonuç"* der ve o akış çalışır — ama **sonuçtan
> sonrası** ölçütün kör noktasıdır.

## ⛔ BU KAPI DAVRANIŞI DEĞİŞTİRMEZ

Kalıcılık eklemek ya da eklememek bir **ürün duruşu** kararıdır ve
**kurucudadır** (blueprint'te *"pratik günlüğü + streak"* geçiyor, ama MIDI
algılama · akort aleti · metronom ile aynı İLERİ-DÖNEM listesinde ⇒ bu
kararlaştırılmış bir şeyin eksik uygulaması değil, bir KAPSAM kararı).
Kapının işi tek şey: durumu **ölçmek** ve **BEYAN EDİLMİŞ** hâlle
karşılaştırmak. Ayrışırsa öter.

**Desen ADAPTE (icat değil):** `validate_runtime_fetch.py`nin beyan+ölçüm
biçimi. Oradaki cümle burada da geçerli: *kapı bu kararı VERMEZ, görünür
tutar.*

## Neden BEYAN + ÖLÇÜM, neden salt ölçüm değil

Salt ölçüm *"bugün şu durumda"* der ve **sessizce değişir**. Beyan onu bir
KARAR NOKTASINA çevirir: biri kalıcılık eklerse ya da var olanı silerse kapı
öter ve kayıt tazelenmek zorunda kalır. Ve tersi de önemli — *bu boşluk bir
daha SESSİZ kalamaz.*

⚠️ Kapı **kalıcılığı ŞART KOŞMAZ.** Sıfır yazma çağrısı meşru bir üründür
(cihaz-üstü, iz bırakmayan). Yasak olan şey **beyansızlık**: ürünün ne
sakladığı ve neyi ATTIĞI yazılı olmadan geçilemez.

## 🔴 ÖRTÜŞME — ADIYLA (O-138, 2026-08-14, öz-yakalama)

**Bu kapıyı yazarken deponun onu ZATEN kurup kurmadığını ölçmedim, ve kısmen
kurmuştu.** `validate_surface_honesty.py` **Kural E2** (`O-102`) saklama
iddiasını ölçümle **iki yönde** ve **ÖZNE BAŞINA** bağlıyor; hatta bu ağacın
iki yazma yolunu (`onboarding_store.dart` · `pose_model.dart`) kendi yorumunda
adıyla sayıyor — yani `O-133`'te *"keşfettiğim"* olgu depoda **zaten
ölçülmüştü.** Üstelik E2'nin yorumu bu dosyanın kusurunu önceden yazmış:
*"`writer_found` GLOBAL bir bool ve Gravita'nın vakasını ayırt EDEMEZ"* —
buradaki `userArtifactMayBePersisted` tam olarak o global bool.

> ***BİR KAPIYI KURMADAN ÖNCE, DEPONUN ONU ZATEN KURUP KURMADIĞINI ÖLÇ.***
> Ürünü aradım, ama deponun KENDİ BİLGİSİNİ aramadım.

**Ölçülmüş iş bölümü — üstünlük iddiası GERİ ÇEKİLDİ:**
  · **Yön ⑴** (saklıyor ama hâlâ *"saklanmıyor"* diyor) → **YETKİLİ SÜRÜM E2'dir**
    (özne başına). Buradaki kontrol yalnız **KABA BİR ÇAPRAZ KONTROL**; E2 ile
    çelişirse **E2 doğrudur.**
  · **Yön ⑵** (hiçbir şey saklamıyor ve bunu **hiçbir yerde söylemiyor**) →
    **E2 KAPSAMIYOR** ve bu kapının gerçek katkısı burasıdır: E2 saklama hükmü
    veren *cümleleri* denetler; **hiç cümle yoksa denetleyecek şeyi de yoktur.**
  · **`WRITE_CLASSES`** (her yazma yolunun gerekçeli sınıfı + sayı sapması) →
    E2'de yok; ikinci gerçek katkı.
"""
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
# ⚠️ Yorum-körlüğü panzehiri BAŞTAN takılı — yeniden yazılmadı, içe aktarıldı.
# Bu depoda üç kapı ham metin tarayıp "sessiz yeşil" verdi (2026-08-13 taraması);
# aynı sınıfa dördüncü kez düşmemek için ayıklayıcı ilk satırdan itibaren burada.
from validate_surface_honesty import strip_dart_comments  # noqa: E402

LIB = Path("lib")

#: Kalıcı yazma yolları — hangi mekanizma olursa.
PERSIST_WRITE = re.compile(
    r"SharedPreferences|Hive\.|openBox|sqflite|openDatabase|"
    r"writeAsString|writeAsBytes|\.setString\(|\.setInt\(|\.setBool\(|"
    r"\.setDouble\(|\.setStringList\(")

#: Kullanıcının ÜRETTİĞİ değerin taşıyıcısı. Bu ad değişirse kapı ötmelidir —
#: çünkü o zaman "oturum sonucu saklanıyor mu" sorusu YANLIŞ ŞEYE bakıyordur.
USER_ARTIFACT = re.compile(r"SessionSummary")

#: 🔴 **GEÇİCİLİK BEYANI — ürünün kullanıcıya SÖYLEDİĞİ şey** (H-10, 2026-08-14).
#:
#: Koordinatör hükmü: ***BİR YOKLUK CÜMLESİ, YOKLUK BİTTİĞİ GÜN BAYATLAR.***
#: Choreia'da onboarding *"Nothing you do is saved"* diyordu ve saklama
#: eklenince **yanlış** oldu; kimse fark etmedi çünkü kapı **sembol** arıyordu,
#: cümle ise **düz metindi**.
#:
#: Ostinato bugün o cümlenin DOĞRU tarafında: hiçbir şey saklanmıyor ve
#: onboarding bunu **açıkça söylüyor**. ⚠️ Ama tam bu yüzden ikisi BİRBİRİNE
#: BAĞLI: kalıcılık eklendiği gün bu cümle **bayat bir yokluk cümlesi** olur.
#:
#: ⇒ Kapı artık iki cümleyi **birbirine karşı** okur — H-10'un *"hiçbir kapı
#: bir ekrandaki iki cümleyi birbirine karşı okumaz"* dediği eksik tam bu:
#:     saklanıyor mu  ⟷  saklanmadığını SÖYLÜYOR mu
#: İkisi ayrışırsa öter, **hangi yönde ayrışırsa ayrışsın.**
#:
#: 📌 **TEK DOSYA YETMEZ** (H-10): aynı iddia hem uygulama metninde hem iOS
#: izin dizesinde geçiyor — ikisi de taranır, çünkü izin dizesi kullanıcının
#: gördüğü ilk cümledir ve kimse onu "ekran" saymaz.
EPHEMERALITY_CLAIM = re.compile(
    r"[Nn]othing is stored|gone when it ends|is gone when the lesson ends|"
    r"no history here to browse")

#: Beyanın geçtiği, taranması ZORUNLU kabuk dosyaları (kod DIŞI yüzeyler).
SHELL_SURFACES = (Path("ios/Runner/Info.plist"),)


def detect(prod_sources):
    """SAF DEDEKTÖR — dosya sistemine DOKUNMAZ, verilen kaynakları ölçer.

    ⚠️ Neden saf (O-116 dersi): öz-test *bugünkü duruma* değil DEDEKTÖRÜN
    ÖZELLİĞİNE bağlanmalı. Kurucu yarın kalıcılık eklerse bu kapının öz-testi
    kırılmamalı — yalnız BEYAN tazelenmelidir.

    `prod_sources`: {dosya-adı: dart kaynağı}
    """
    write_files, artifact_files, claim_files = set(), set(), set()
    sites = 0
    for name, text in prod_sources.items():
        # Kabuk yüzeyleri (plist/xml) dart yorumu taşımaz; ayıklayıcı zararsız.
        s = strip_dart_comments(text)
        hits = PERSIST_WRITE.findall(s)
        if hits:
            write_files.add(name)
            sites += len(hits)
        if USER_ARTIFACT.search(s):
            artifact_files.add(name)
        if EPHEMERALITY_CLAIM.search(s):
            claim_files.add(name)
    return {
        "writeCallSites": sites,
        "writeFiles": sorted(write_files),
        # Kullanıcı artefaktını ANAN dosyalardan herhangi biri yazıyor mu.
        # ⚠️ Bu bir ÜST SINIR ölçümüdür: aynı dosyada olmaları saklandığını
        # KANITLAMAZ, yalnız saklanma İHTİMALİNİ açar. `False` ise kesindir —
        # hiçbir yerde yan yana gelmiyorlarsa saklanmıyordur.
        "userArtifactMayBePersisted": bool(artifact_files & write_files),
        "userArtifactFiles": sorted(artifact_files),
        # ⚠️ Geçicilik beyanı YORUMDAN OKUNMAZ: `strip_dart_comments`ten
        # geçmiş metinde aranır. Bir yorumda anlatılan vaat, kullanıcıya
        # verilmiş vaat değildir — ve bu depoda o tuzak ölçüldü (`O-054`
        # düzeltmesini ANLATAN yorum, ham taramada vaat gibi görünüyordu).
        "ephemeralityClaimFiles": sorted(claim_files),
    }


# ── BEYAN — her alan bir ÖLÇÜM ADRESİ taşır (E2 ilkesi) ──────────────────
#
# ⚠️ Bu bir MUAFİYET değil, KARAR NOKTASI.
DECLARED = {
    "writeCallSites": 2,
    "writeFiles": ["onboarding_store.dart", "pose_model.dart"],
    "userArtifactMayBePersisted": False,
    "userArtifactFiles": ["live_screen.dart", "review_screen.dart"],
    "$why": (
        "ÖLÇÜLDÜ 2026-08-14 (O-133). `lib/` ağacında İKİ kalıcı yazma var ve "
        "İKİSİ DE kullanıcı üretimi DEĞİL (sınıfları `WRITE_CLASSES`ta). "
        "`SharedPreferences` · `Hive` · `sqflite`: hiçbiri yok. "
        "`SessionSummary` yalnız `live_screen.dart`ta üretilip "
        "`review_screen.dart`a GEÇİRİLİR; hiçbir yere yazılmaz. "
        "⚠️ İlk beyanım `1` yazıyordu ve KAPI ÖTEREK düzeltti: elle `grep`im "
        "`writeAsBytes`i kapsamıyordu. *Bir envanteri elle saymak, deseninin "
        "genişliği kadar doğrudur.*"),
    "$whatIsDiscarded": (
        "ATILAN, adıyla: her pratik oturumunun SONUCU. Kullanıcı dersi "
        "çalışır, postür ölçülür, sonuç yüzeyi ÖLÇÜLEN kareden türetilir — "
        "ve ekran kapanınca hepsi yok olur. Geçmiş YOK · ilerleme YOK · "
        "streak YOK. Ertesi gün uygulama kullanıcıyı hiç görmemiş gibidir. "
        "✅ DÜZELTME (aynı gün, ölçümle): ilk yazdığım *'bu duruş SEÇİLMİŞ "
        "değil, yalnız YAZILMAMIŞTIR'* cümlesi YANLIŞTI. Duruş kullanıcıya "
        "AÇIKÇA beyan edilmiş — onboarding *'Your video'* kartı: «Nothing is "
        "stored either: what we measure exists while the lesson runs and is "
        "gone when it ends», ve aynı iddia iOS kamera-izin dizesinde de "
        "geçiyor. ⇒ Bu bir DÜRÜSTLÜK kusuru DEĞİL, bir KAPSAM bulgusudur: "
        "ürün saklamıyor ve saklamadığını SÖYLÜYOR."),
    "ephemeralityClaimFiles": ["Info.plist", "onboarding_screen.dart",
                               "settings_screen.dart"],
    "$coupling": (
        "H-10 (2026-08-14): *bir yokluk cümlesi, yokluk bittiği gün bayatlar.* "
        "Bugün Ostinato o cümlenin DOĞRU tarafında — ama tam bu yüzden "
        "kalıcılık ile geçicilik-beyanı BİRBİRİNE BAĞLI: saklama eklendiği "
        "gün «Nothing is stored» YANLIŞ olur. Kapı ikisini birbirine karşı "
        "okur ve HANGİ YÖNDE ayrışırsa ötterir — Choreia'nın vakasında kusur "
        "tam da kimsenin bu bağı kurmamış olmasıydı."),
    "$founderDecision": (
        "AÇIK: ⑴ oturum sonucunu yerel olarak saklamak (ilerleme mümkün olur, "
        "cihaz-üstü kalır) mı, ⑵ hiçbir şey saklamamayı BİLEREK seçip bunu "
        "kullanıcıya söylemek mi. Blueprint 'pratik günlüğü + streak' diyor "
        "ama ileri-dönem listesinde ⇒ kapsam kararı. İlerlemenin NEREDE "
        "görüneceği ayrıca TASARIM YÖNÜDÜR. Kapı bu kararı VERMEZ, görünür "
        "tutar."),
}

#: Beyanın boş bırakılamayacak gerekçe alanları.
PROSE_FIELDS = ("$why", "$whatIsDiscarded", "$founderDecision", "$coupling")


def coupling_violation(actual):
    """Saklıyor mu ⟷ saklamadığını SÖYLÜYOR mu — İKİ YÖNDE de öter (H-10)."""
    persists = actual["userArtifactMayBePersisted"]
    claims = bool(actual["ephemeralityClaimFiles"])
    if persists and claims:
        return (f"🔴 BAYAT YOKLUK CÜMLESİ (H-10) — ⚠️ KABA ÇAPRAZ KONTROL, "
                f"yetkili sürüm `validate_surface_honesty` Kural E2'dir (özne "
                f"başına; burası GLOBAL bool ve E2 ile çelişirse E2 doğrudur): "
                f"ürün artık kullanıcı üretimini SAKLIYOR olabilir, ama "
                f"{actual['ephemeralityClaimFiles']} hâlâ «hiçbir şey "
                f"saklanmıyor» diyor. *Bir yokluk cümlesi, yokluk bittiği gün "
                f"bayatlar* — metni ÖNCE düzelt")
    if not persists and not claims:
        return ("🔴 SESSİZ GEÇİCİLİK: ürün hiçbir kullanıcı üretimini "
                "saklamıyor ve bunu kullanıcıya HİÇBİR YERDE söylemiyor. "
                "*Saklamamak meşrudur; sessizce saklamamak değildir* — "
                "kullanıcı emeğinin kaybolacağını önceden bilmelidir")
    return ""

#: 🔴 **HER YAZMA YOLU SINIFLANDIRILIR — gerekçesiz yazma geçemez.**
#:
#: Bu alan kapının İLK KOŞUSUNDA doğdu ve doğuran şey kapının kendi kusuruydu:
#: düz bir *"yazma sayısı"* ölçümü `pose_model.dart`ın **sevk edilen varlık**
#: yazmasını, `onboarding_store.dart`ın **kullanıcı durumu** yazmasıyla aynı
#: kovaya atıyordu. O-128'in dersi burada aynen geçerli:
#: > ***BİR SINIFLANDIRMA, HİÇBİR KOVAYA UYMAYAN BİR KALEMİ YİNE DE BİRİNE
#: > ATIYORSA, ÖLÇTÜĞÜ ŞEY KALEM DEĞİL KENDİ DARLIĞIDIR.***
#:
#: ⚠️ Ve asıl değeri ileriye dönük: kalıcılık eklenirse yeni yazma yolu
#: **sınıflandırılmadan geçemez** — yani *"ne sakladığını söyle"* zorunluluğu
#: koda gömülür, kayıtlara değil.
WRITE_CLASSES = {
    "onboarding_store.dart": (
        "KULLANICI DURUMU (tek bit) — `onboarding-v1.done` işaretçisi. "
        "Kullanıcının ÜRETTİĞİ bir değer değil, uygulamanın onu bir kez "
        "gördüğünün kaydı. Silinirse kullanıcı yalnız onboarding'i yeniden "
        "görür; hiçbir emeği kaybolmaz."),
    "pose_model.dart": (
        "SEVK EDİLEN VARLIK ÖNBELLEĞİ — pakete gömülü ML modelini "
        "`getApplicationSupportDirectory()` altına açar, çünkü plugin "
        "bundle değil YOL istiyor (`resolveFilePath`, dosya varsa yeniden "
        "yazmaz). Kullanıcı üretimi DEĞİL: silinse uygulama onu paketten "
        "yeniden açar, hiçbir bilgi kaybolmaz."),
}


def check(declared, actual):
    bad = []
    for f in actual["writeFiles"]:
        if not str(WRITE_CLASSES.get(f, "")).strip():
            bad.append(f"«{f}» YENİ BİR YAZMA YOLU ve SINIFLANDIRILMAMIŞ — "
                       f"`WRITE_CLASSES`a gerekçesiyle eklenmeli. Bir ürünün "
                       f"neyi sakladığı, saklamaya BAŞLADIĞI anda yazılır; "
                       f"sonradan hatırlanmaz")
    cv = coupling_violation(actual)
    if cv:
        bad.append(cv)
    for key in ("writeCallSites", "writeFiles", "userArtifactMayBePersisted",
                "userArtifactFiles", "ephemeralityClaimFiles"):
        if declared.get(key) != actual[key]:
            bad.append(f"«{key}»: BEYAN {declared.get(key)!r} · ÖLÇÜM "
                       f"{actual[key]!r} — kalıcılık duruşu DEĞİŞMİŞ ve kayıt "
                       f"tazelenmemiş; kayıt kendi kanıtı değildir")
    for field in PROSE_FIELDS:
        if not str(declared.get(field, "")).strip():
            bad.append(f"«{field}» BOŞ — bir kalıcılık duruşu, NEYİ ATTIĞINI "
                       f"yazmadan beyan edilemez (sessizlik yasak)")
    return bad


def _read_lib():
    """`lib/` + KABUK yüzeyleri. H-10: *tek dosya yetmez.*"""
    out = {f.name: f.read_text(encoding="utf-8")
           for f in sorted(LIB.rglob("*.dart"))}
    for p in SHELL_SURFACES:
        if p.exists():
            out[p.name] = p.read_text(encoding="utf-8")
    return out


def selftest() -> int:
    """Dedektörün ÖZELLİĞİ sınanır — bugünkü ağacın DURUMU değil."""
    dead = []
    # ① yazma görülmeli
    a = detect({"s.dart": "prefs.setString('k', v);"})
    if a["writeCallSites"] != 1:
        dead.append(f"YAZMA DESENİ kör — `setString` sayılmadı ({a})")
    # ② YORUM BAĞIŞIKLIĞI (bu deponun üç kez ısırdığı sınıf)
    a = detect({"s.dart": "// prefs.setString('k', v);"})
    if a["writeCallSites"] != 0:
        dead.append("YORUM BAĞIŞIKLIĞI ÖLDÜ — yorumdaki yazma sayılıyor; "
                    "kapı 'saklıyor' der, ürün saklamaz")
    # ③ artefakt + yazma AYNI dosyada → saklanma İHTİMALİ açılır
    a = detect({"live.dart": "SessionSummary s; f.writeAsString(j);"})
    if not a["userArtifactMayBePersisted"]:
        dead.append("ARTEFAKT/YAZMA KESİŞİMİ ölü — aynı dosyadaki ikili "
                    "görülmüyor, kalıcılık EKLENSE bile kapı susardı")
    # ④ artefakt var, yazma yok → kesin HAYIR
    a = detect({"live.dart": "SessionSummary s;", "o.dart": "prefs.setBool(x);"})
    if a["userArtifactMayBePersisted"]:
        dead.append("KESİŞİM FAZLA GENİŞ — ayrı dosyalardaki artefakt ve "
                    "yazmayı birleştiriyor (yanlış-pozitif)")
    # ⑤ VAKUM — boş kaynak kümesi 'sorun yok' diye okunamaz
    if detect({})["writeCallSites"] != 0:
        dead.append("VAKUM davranışı tanımsız")
    real = _read_lib()
    if not real:
        dead.append("VAKUM: `lib/` içinde hiç dart kaynağı bulunamadı — "
                    "yanlış dizinden koşuluyor ya da ağaç boş; 'kalıcılık "
                    "yok' ölçümü GEÇERSİZ")
    # ⑥ BEYAN MEKANİZMASI ısırıyor mu — sayı ve gerekçe iki AYRI yolla
    actual = detect(real)
    if not check({**DECLARED, "writeCallSites": 999}, actual):
        dead.append("BEYAN KONTROLÜ ölü — uydurma sayı yakalanmıyor")
    if not check({**DECLARED, "$whatIsDiscarded": ""}, actual):
        dead.append("GEREKÇE KONTROLÜ ölü — boş `$whatIsDiscarded` geçiyor; "
                    "sessizlik yasağı uygulanmıyor")
    # ⑧ BAĞ — İKİ YÖNDE de ötmeli (H-10). Sentetik, bugünkü ağaçtan bağımsız.
    if not coupling_violation({"userArtifactMayBePersisted": True,
                               "ephemeralityClaimFiles": ["o.dart"]}):
        dead.append("BAĞ TEK YÖNLÜ — saklama eklendiği hâlde «hiçbir şey "
                    "saklanmıyor» cümlesi duruyorsa kapı SUSUYOR; Choreia'nın "
                    "bayat-yokluk vakası burada TEKRARLANIR (H-10)")
    if not coupling_violation({"userArtifactMayBePersisted": False,
                               "ephemeralityClaimFiles": []}):
        dead.append("BAĞ ÖTEKİ YÖNDE ÖLÜ — hiçbir şey saklamayıp bunu "
                    "SÖYLEMEYEN ürün geçiyor; sessiz geçicilik yakalanmıyor")
    if coupling_violation({"userArtifactMayBePersisted": False,
                           "ephemeralityClaimFiles": ["o.dart"]}):
        dead.append("BAĞ YANLIŞ-POZİTİF — bugünkü DOĞRU hâl (saklamıyor VE "
                    "söylüyor) ötüyor")
    # ⑨ Geçicilik beyanı YORUMDAN okunmamalı (O-054'ün ham-tarama tuzağı)
    if detect({"o.dart": "// body: 'Nothing is stored either'"}
              )["ephemeralityClaimFiles"]:
        dead.append("GEÇİCİLİK BEYANI YORUMDAN OKUNUYOR — bir yorumda "
                    "anlatılan vaat, kullanıcıya verilmiş vaat değildir")
    # ⑦ SINIFLANDIRMA ZORUNLULUĞU — sentetik, bugünkü ağaçtan BAĞIMSIZ.
    #    Yarın kalıcılık eklenirse bu kontrol *"ne sakladığını söyle"* der.
    fake = {"writeCallSites": 1, "writeFiles": ["yeni_depo.dart"],
            "userArtifactMayBePersisted": True,
            "userArtifactFiles": ["yeni_depo.dart"],
            # Bağ ihlali ötmesin diye: saklıyor VE geçicilik iddiası YOK.
            "ephemeralityClaimFiles": []}
    if not check({**DECLARED, **{k: fake[k] for k in fake}}, fake):
        dead.append("SINIFLANDIRMA ZORUNLULUĞU ölü — sınıfsız bir yazma yolu "
                    "geçiyor; kalıcılık eklendiğinde SESSİZ girer")
    if dead:
        print(f"⛔ {len(dead)} ÖLÜ DESEN (kalıcılık kapısı öz-testi):")
        for d in dead:
            print(f"   - {d}")
        return 1
    print(f"✅ kalıcılık kapısı öz-testi GEÇTİ — yazma deseni · yorum "
          f"bağışıklığı · artefakt kesişimi (İKİ yönde) · vakum · beyan "
          f"mekanizması (sayı + gerekçe) · sınıflandırma zorunluluğu · BAĞ (üç yön) · "
          f"beyan-yorum bağışıklığı: ON BİR kontrolün on biri de canlı")
    return 0


def main() -> int:
    if "--selftest" in sys.argv:
        return selftest()
    sources = _read_lib()
    if not sources:
        print("⛔ VAKUM: `lib/` içinde hiç dart kaynağı yok — ölçüm GEÇERSİZ")
        return 1
    actual = detect(sources)
    bad = check(DECLARED, actual)
    if bad:
        print(f"⛔ {len(bad)} KALICILIK BEYANI İHLALİ:")
        for b in bad:
            print(f"   - {b}")
        return 1
    stance = ("HİÇBİR KULLANICI ÜRETİMİ SAKLANMIYOR"
              if not actual["userArtifactMayBePersisted"]
              else "kullanıcı üretimi SAKLANIYOR olabilir")
    print(f"✅ kalıcılık BEYANLA UYUŞUYOR — duruş: {stance}")
    print(f"   ölçüm: {actual['writeCallSites']} yazma çağrısı · "
          f"yazan dosya {actual['writeFiles']} · "
          f"oturum sonucunu ANAN dosya {actual['userArtifactFiles']}")
    print(f"   ⚠️ ATILAN (adıyla): her pratik oturumunun SONUCU — geçmiş yok, "
          f"ilerleme yok, streak yok")
    print(f"   ✅ VE ÜRÜN BUNU SÖYLÜYOR — geçicilik beyanı "
          f"{actual['ephemeralityClaimFiles']} ({len(actual['ephemeralityClaimFiles'])} yüzey). "
          f"Bu bir dürüstlük kusuru DEĞİL, kapsam bulgusu")
    print(f"   🔗 BAĞ CANLI (H-10): saklama eklendiği gün bu "
          f"{len(actual['ephemeralityClaimFiles'])} metin BAYAT yokluk cümlesine "
          f"döner ve kapı öter — metin ÖNCE düzeltilir")
    print(f"   ⏳ KURUCU KARARI AÇIK: yerel saklama mı, bilerek iz "
          f"bırakmamak mı (kapı bu kararı VERMEZ, görünür tutar)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
