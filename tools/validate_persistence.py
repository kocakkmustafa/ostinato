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
from surface_context import preference_payload_role  # noqa: E402

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
    roles = {name: preference_payload_role(strip_dart_comments(text))
             for name, text in prod_sources.items() if name in write_files}
    return {
        "preferenceRoles": {k: v for k, v in roles.items() if v},
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
    "writeCallSites": 14,
    "writeFiles": ["age_gate_store.dart", "app_locale_preferences.dart",
                   "app_theme_preferences.dart",
                   "guitar_journey_progress.dart", "onboarding_store.dart",
                   "own_recording.dart", "own_recording_preference.dart",
                   "pose_model.dart", "practice_display_preferences.dart",
                   "practice_progress_store.dart",
                   "session_store.dart", "setup_profile_store.dart",
                   "tuner_check_memory.dart", "weekly_goal_store.dart"],
    "userArtifactMayBePersisted": True,
    "userArtifactFiles": ["live_screen.dart", "review_screen.dart",
                          "session_store.dart"],
    "$why": (
        "GÜNCEL ENVANTER 2026-11-02 (FK4 / plan F2.7): "
        "`practice/display/practice_display_preferences.dart` uygulama "
        "düzeyinde `ostinato.practice_display.v1.json` yazar: şema sürümü + "
        "`leftHanded` + `colorBlindSafe` (ikisi de varsayılan false). Sunum "
        "tercihidir; ses, ölçüm, ilerleme veya hesap verisi taşımaz. "
        "GÜNCEL ENVANTER 2026-11-02 (v1 tam gitar kursu): aynı "
        "`practice/loop/practice_progress_store.dart`, aynı hesap dizinine "
        "ikinci bir kardeş dosya yazar: `v1_lesson_checks.v1.json` — "
        "ölçülü döngüde çalışmayan v1 dersleri için ders kimliği, kanıt "
        "türü (`self_report` = öğrencinin öz-kontrol beyanı, ölçülmedi; "
        "`tuner_check` = akort aleti altı teli akortlu ölçtü) ve zaman. "
        "İşaretlenen maddeler, ses, ölçüm değeri yazılmaz; ağa ve Motion "
        "Core'a çıkmaz. Yazma çağrısı ortak atomik yardımcıdan geçer (çağrı "
        "sayısı değişmedi). "
        "GÜNCEL ENVANTER 2026-11-01 (FK2, kurucu onayı: \"Olsun, varsayılan "
        "kapalı\"): `practice/own_recording/own_recording.dart` ayar açıksa "
        "bir pratik turunun sesini RAM'de tutar, tur bitince geçici dizine "
        "(`getTemporaryDirectory()/own_recording/take-N.wav`) yazar; sonuç "
        "ekranında dinlenir. Sonraki tur, başarısız/terk edilen tur ve ders "
        "ekranının kapanması dosyayı siler; çökme artığı ders açılışında "
        "süpürülür. Yüklenmez, analize ve eğitime verilmez "
        "(`test/own_recording_test.dart`). `own_recording_preference.dart` "
        "yalnız aç/kapa anahtarını `ostinato.own_recording.v1.json`a yazar "
        "(varsayılan kapalı). `tuner/tuner_check_memory.dart` (PR #16) "
        "bugünkü akort sonucunu cihazda `tuner_check.v1.json`a yazar: akort "
        "kimliği, akortlu/toplam tel ve zaman; ses yok. "
        "GÜNCEL ENVANTER 2026-11-01 (F2.5 + F4.2): "
        "`practice/loop/practice_progress_store.dart` hesap dizinine "
        "`v1_practice_progress.v1.json` yazar: ders başına ölçülen pratik "
        "sayıları (tur sayısı, en iyi doğruluk/duyulma oranı, tempo, ilk "
        "geçiş ve tamamlanma zamanı; `evidence: measured_practice`). "
        "`practice/setup/setup_profile_store.dart` cihaz düzeyinde "
        "`setup_profile.v1.json` yazar: kurulum adımlarının yapıldı/atlandı "
        "durumu, oda seviyesi (dBFS) ve rota başına gecikme (µs). İkisinde "
        "de ses, nota listesi veya ağ yok; Motion Core'a yazılmaz. "
        "GÜNCEL ENVANTER 2026-11-01 (F5.2): `retention/weekly_goal_store.dart` "
        "hesap dizinine `weekly_goal.v1.json` yazar: haftalık hedef "
        "değişiklikleri (hafta + oturum sayısı) ve gün başına giriş (yerel "
        "gün, giriş türü: ölçülen/ders/uygulama dışı/ses dinlenme günü, kurs "
        "kimliği). Ders metni, ses, ölçüm değeri saklanmaz; Motion Core'a "
        "ve ağa çıkmaz; hesap dizini silinince gider. "
        "GÜNCEL ENVANTER 2026-10-21: `app_locale_preferences.dart` ve "
        "`app_theme_preferences.dart` uygulama düzeyinde birer sunum tercihi "
        "dosyası yazar (`ostinato.locale.v1.json`: şema sürümü + desteklenen "
        "dil etiketi veya null; `ostinato.theme.v1.json`: şema sürümü + "
        "system/light/dark). Kullanıcı üretimi, ölçüm veya hesap verisi "
        "değildir; payload rolü `preference_payload_role` ile yapısal "
        "olarak kanıtlanır. "
        "GÜNCEL ENVANTER 2026-10-16: mevcut `guitar_journey_progress.dart` "
        "ders kimliği/sürümü, görülme ve pratik zamanları, pratik sayısı ve "
        "öz beyan tamamlama zamanını `guitar_journey_progress.v1.json`a "
        "yazar. Bu kayıt `self_report_only`dir; ölçülen nota/teknik/ustalık "
        "değildir. Misafir yerel kökü ve hesap-UUID dizinleri ayrıdır. "
        "Bu envanter düzeltmesi yeni saklama davranışı eklemez. "
        "GÜNCELLENDİ 2026-08-16 (D14, O-153 — kurucu kararı geldi). "
        "`session_store.dart` yeni yazma yolu: her pratik oturumunun "
        "ÖZETİ (ders/çalgı kimliği + süre + örnek/dışarı-sayımı + "
        "zaman damgası — HAM açı-örnekleri/`history` DEĞİL, o kapsam "
        "dışında bırakıldı, kayıtlar KÜÇÜK kalsın diye) `sessions.jsonl`e "
        "JSONL satırı olarak eklenir. `SharedPreferences`/`Hive`/`sqflite`: "
        "hâlâ hiçbiri yok, düz dosya G/Ç (aile deseni, `M-F-650`)."),
    "$whatIsDiscarded": (
        "FK2: kendi kayıt dosyası oturum sonunda ATILIR (sonraki tur / ders "
        "çıkışı / çökme sonrası süpürme); ayar kapalıyken hiç oluşmaz. "
        "ATILAN, adıyla — D14 SONRASI: ham açı-örnekleri (`history`) hâlâ "
        "atılıyor, yalnız ÖZET saklanıyor. Video hiçbir zaman saklanmadı, "
        "hâlâ saklanmıyor. SAKLANAN: hangi ders, ne zaman, kaç saniye, "
        "bant-içi oranı ve ayrı gitar yolunda ders sürümüne bağlı öz beyan "
        "ilerlemesi. Kullanıcı 'son oturum'unu Review'da, gitar ders "
        "ilerlemesini yazılı kurs yüzeyinde görür. Ham ses, kare-kare açı "
        "geçmişi ve ölçülen müzik ustalığı bu kayıtlarda tutulmaz."),
    "ephemeralityClaimFiles": [],
    "$coupling": (
        "H-10 (2026-08-14): *bir yokluk cümlesi, yokluk bittiği gün "
        "bayatlar.* D14 TAM BUNU YAPTI — saklama eklendiğinde üç yüzeyin "
        "(Info.plist, onboarding, settings) 'nothing is stored' cümleleri "
        "ÖNCE düzeltildi (bu commit'te, kod değişikliğiyle AYNI turda), "
        "SONRA bu beyan tazelendi — H-10'un istediği sıra tam buydu: "
        "'metni ÖNCE düzelt.' Üç yüzey artık ne sakladığını GERÇEKTEN "
        "söylüyor (video/ham ölçüm hâlâ hayır, oturum özeti artık evet)."),
    "$founderDecision": (
        "VERİLDİ (D14, 2026-08-16): oturum sonucu YEREL saklanır. "
        "M-F-650 (Lissom emsali): Apple'ın anlamında 'collect' = cihazdan "
        "DIŞARI aktarmak; bu veri hiç ağa çıkmıyor (D1'in repo-geneli "
        "sıfır-ağ kapısı, `test/flutter_test_config.dart`, bunu da "
        "kapsıyor — TRIPWIRE koda bağlı, belgeye değil). İlerleme "
        "yüzeyinin NEREDE/NASIL görüneceği (tam geçmiş, grafik, streak) "
        "ayrıca TASARIM YÖNÜDÜR ve o tarihsel kararda post-V1'dir. "
        "2026-10-16 mevcut kaynak gözlemi: ayrı yazılı gitar kursu öz beyan "
        "ilerlemesini zaten saklar; envanter, mevcut davranışı kaydeder ve "
        "yeni veri toplama veya kapsam genişletme yetkisi oluşturmaz."),
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
    "age_gate_store.dart": (
        "CİHAZ KORUMA İŞARETİ (2026-10-23) — Core'un 13 yaş altı kayıt "
        "engeli bu cihazda bir kez gerçekleşti mi; yalnız şema sürümü ve "
        "sabit `blocked: true`. Doğum ayı/yılı, ülke, e-posta veya hesap "
        "kimliği yazılmaz. Silinirse engel bu cihazda yeniden sorulur."),
    "app_locale_preferences.dart": (
        "SUNUM TERCİHİ — yalnız şema sürümü ve desteklenen 14 dilden birinin "
        "etiketi (veya sistem dili için null). Hesap, ilerleme veya ölçüm "
        "taşımaz. Silinirse uygulama cihaz diline döner; kullanıcı emeği "
        "kaybolmaz."),
    "app_theme_preferences.dart": (
        "SUNUM TERCİHİ — yalnız şema sürümü ve system/light/dark modu. "
        "Silinirse görünüm sisteme döner; kullanıcı emeği kaybolmaz."),
    "guitar_journey_progress.dart": (
        "KULLANICI ÜRETİMİ — yazılı gitar yolunda sürümlü ders kimliği, "
        "görülme/pratik zamanları, pratik sayısı ve öz beyan tamamlama "
        "zamanı. `self_report_only`; sensör sonucu, ham ses veya ölçülen "
        "ustalık değildir. Misafir kökü hesap-UUID dizinlerinden ayrıdır. "
        "Silinirse kullanıcının yerel gitar çalışma kaydı kaybolur."),
    "practice_progress_store.dart": (
        "KULLANICI ÜRETİMİ (F2.5, 2026-11-01) — v1 dersleri için ölçülen "
        "pratik: tur sayısı, en iyi doğruluk/duyulma, tempo, ilk geçiş "
        "(sıradaki dersi açar) ve hedef tempoda tamamlanma zamanı. Yalnız "
        "sayılar; ses ve nota dizisi yazılmaz; hesap dizininde kalır, ağa "
        "ve Motion Core'a çıkmaz. Silinirse ölçülen ders kilitleri baştan "
        "başlar. 2026-11-02: kardeş dosya `v1_lesson_checks.v1.json` — "
        "ölçülemeyen v1 derslerinde öz-kontrol beyanı (`self_report`, "
        "ölçülmüş sayılmaz) ve akort dersinde akort aleti sonucu "
        "(`tuner_check`); yalnız ders kimliği, kanıt türü, zaman. Silinirse "
        "öz-kontrol tamamlamaları ve 'ölçülmedi' etiketli modül açılışları "
        "kaybolur."),
    "setup_profile_store.dart": (
        "CİHAZ AYARI (F4.2, 2026-11-01) — kurulum sihirbazının sonucu: "
        "adımların yapıldı/atlandı durumu, oda seviyesi ve rota başına "
        "(hoparlör/kablolu/Bluetooth) ölçülen gecikme. Kişiyi değil "
        "telefonun ses yolunu anlatır; ses kaydı yok. Silinirse zamanlama "
        "rozeti geri gelir ve kurulum yeniden önerilir; kullanıcı emeği "
        "kaybolmaz."),
    "weekly_goal_store.dart": (
        "KULLANICI ÜRETİMİ (F5.2, 2026-11-01) — haftalık hedef ve seri: "
        "hedef değişiklikleri ve gün başına giriş (yerel gün, giriş türü, "
        "kurs kimliği). Ders metni, ses veya ölçüm değeri yazılmaz; Motion "
        "Core'a ve ağa çıkmaz. Silinirse haftalık seri ve dondurma hakları "
        "sıfırdan başlar; ders ilerlemesi etkilenmez."),
    "own_recording.dart": (
        "GEÇİCİ KULLANICI SESİ (FK2, 2026-11-01, kurucu onaylı) — ayar "
        "açıkken bir pratik turunun 16-bit mono WAV'ı, yalnız uygulamanın "
        "geçici dizininde ve yalnız oturum boyunca. Sonraki tur, terk ve "
        "ders ekranının kapanması siler; çökme artığı ders açılışında "
        "süpürülür. Ağ API'si yok; nota hakemi bu kaydı okumaz. Silinmesi "
        "amaçtır; kullanıcı emeği kaybolmaz."),
    "practice_display_preferences.dart": (
        "SUNUM TERCİHİ (FK4, 2026-11-02) — yalnız şema sürümü, `leftHanded` "
        "(TAB şeridi aynalanır) ve `colorBlindSafe` (Okabe–Ito paleti); "
        "ikisi de varsayılan false. Ses, ölçüm, ilerleme veya hesap verisi "
        "taşımaz. Silinirse iki ayar kapalıya döner; kullanıcı emeği "
        "kaybolmaz."),
    "own_recording_preference.dart": (
        "CİHAZ AYARI (FK2, 2026-11-01) — yalnız şema sürümü ve "
        "`enabled` (varsayılan false). Ses veya hesap verisi taşımaz. "
        "Silinirse ayar kapalıya döner."),
    "tuner_check_memory.dart": (
        "CİHAZ DURUMU (PR #16, 2026-11-01) — bugünkü akort sonucu: akort "
        "kimliği, akortlu ve toplam tel sayısı, zaman. Çalgının durumunu "
        "anlatır, kişiyi değil; ses yok; ertesi gün geçersiz sayılır. "
        "Silinirse oturum kapısı akortu yeniden önerir."),
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
    "session_store.dart": (
        "KULLANICI ÜRETİMİ (D14, 2026-08-16) — her pratik oturumunun "
        "ÖZETİ (ders/çalgı kimliği, süre, bant-içi sayaçları, zaman "
        "damgası; HAM açı-örnekleri DEĞİL). Silinirse kullanıcı geçmiş "
        "oturumlarının izini kaybeder — bu SESSION_STORE'un TEK amacı, "
        "kaybı önlemek değil GÖRÜNÜR ilerleme sağlamaktır."),
}


PREFERENCE_CLASSES = {"age_gate_store.dart": "age_gate",
                      "app_locale_preferences.dart": "locale",
                      "app_theme_preferences.dart": "theme"}


def check(declared, actual):
    bad = []
    for f in actual["writeFiles"]:
        if not str(WRITE_CLASSES.get(f, "")).strip():
            bad.append(f"«{f}» YENİ BİR YAZMA YOLU ve SINIFLANDIRILMAMIŞ — "
                       f"`WRITE_CLASSES`a gerekçesiyle eklenmeli. Bir ürünün "
                       f"neyi sakladığı, saklamaya BAŞLADIĞI anda yazılır; "
                       f"sonradan hatırlanmaz")
    # Tercih sınıfı bir beyan değil kanıt ister: dosyanın her yazması
    # yapısal olarak locale/theme payload'ı olmalı (fail-closed).
    for f, role in PREFERENCE_CLASSES.items():
        if f in actual["writeFiles"] and actual.get("preferenceRoles", {}).get(f) != role:
            bad.append(f"«{f}» SUNUM TERCİHİ sınıfında ama yazma payload'ı "
                       f"«{role}» rolü olarak kanıtlanamadı — sınıf yeniden ölçülmeli")
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
    # ②b TERCİH SINIFI KANIT İSTER: tercih dosyası ölçüm yazmaya başlarsa
    #     sınıfı düşmeli (beyan kendi kanıtı değildir).
    pref = ("Future<void> write(String? languageTag) async {\n"
            "  if (languageTag != null && !supportedLanguageTags.contains(languageTag)) {\n"
            "    throw ArgumentError.value(languageTag);\n  }\n"
            "  await f.writeAsString(\n"
            "    jsonEncode({'schemaVersion': 1, 'languageTag': languageTag}),\n"
            "    flush: true,\n  );\n}")
    good = detect({"app_locale_preferences.dart": pref})
    bad = detect({"app_locale_preferences.dart": pref.replace(
        "'languageTag': languageTag", "'history': languageTag")})
    if good["preferenceRoles"] != {"app_locale_preferences.dart": "locale"}:
        dead.append("TERCİH ROLÜ kör — kanıtlı locale payload'ı tanınmadı")
    if not any("SUNUM TERCİHİ sınıfında" in b for b in check(DECLARED, bad)):
        dead.append("TERCİH SINIFI KANITSIZ GEÇİYOR — ölçüm benzeri payload "
                    "sunum tercihi sayıldı")
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
          f"beyan-yorum bağışıklığı: ON İKİ kontrolün on ikisi de canlı")
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
    if actual["userArtifactMayBePersisted"]:
        print("   ✅ ATILAN (adıyla): ham açı-örnekleri (`history`) — özet "
              "saklanıyor, kare-kare hareket saklanmıyor")
    else:
        print("   ⚠️ ATILAN (adıyla): her pratik oturumunun SONUCU — geçmiş "
              "yok, ilerleme yok, streak yok")
    print(f"   ✅ VE ÜRÜN BUNU SÖYLÜYOR — geçicilik beyanı "
          f"{actual['ephemeralityClaimFiles']} ({len(actual['ephemeralityClaimFiles'])} yüzey). "
          f"Bu bir dürüstlük kusuru DEĞİL, kapsam bulgusu")
    if actual["ephemeralityClaimFiles"]:
        print(f"   🔗 BAĞ CANLI (H-10): saklama eklendiği gün bu "
              f"{len(actual['ephemeralityClaimFiles'])} metin BAYAT yokluk "
              f"cümlesine döner ve kapı öter — metin ÖNCE düzeltilir")
    else:
        print("   ✅ BAĞ TEMİZ (H-10): geçicilik iddiası taşıyan yüzey yok — "
              "saklıyorsan söylemen, söylüyorsan saklamaman gerekmiyor")
    if actual["userArtifactMayBePersisted"]:
        print("   ✅ KURUCU KARARI VERİLDİ (D14, 2026-08-16): yerel saklama "
              "— kapı artık kararı DEĞİL, kararın kalıcılığını görünür "
              "tutuyor")
    else:
        print("   ⏳ KURUCU KARARI AÇIK: yerel saklama mı, bilerek iz "
              "bırakmamak mı (kapı bu kararı VERMEZ, görünür tutar)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
