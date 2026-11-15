# ADR-008 — 13 yaş altı için veli izni akışı (SEC-OST-02)

Tarih: 2026-11-15 · Durum: ÖNERİLDİ (kurucu kararı "b: Veli izni akışı" alındı; bu ADR yalnız tasarımdır, kod/bayrak/test yazılmadı) · Numara: ADR-001..007 `docs/yula-execution/DECISIONS.md` ve `docs/g2-prep/`'te kullanılmış, ADR-UX-001 ayrı seri; 008 boş.

> İç belge. Hukuki tavsiye değildir; mevzuat ve mağaza kuralları için hukuk/mağaza doğrulaması gerekir. Tıbbi iddia içermez. Kullanıcıya dönük metin yazılmadı.

## 1. Bağlam (bugün)

Bugünkü kural: 13 yaş altı hiçbir yerde Motion hesabı açamaz.

- Yaş kararı Core'dadır. `motion_account` paketi `ventures/motion-core/lib/packages/motion_account/lib/src/motion_age_policy.dart` içinde `MotionAgePolicy.minimumAge = 13`, `bandFor` ve `MotionAgeBand { blocked, parentalConsentRequired, teen, adult }` taşır. `blocked` = "Under 13: no account and no account data collection". Ostinato bu paketi git revizyonuna sabitlenmiş olarak tüketir (`pubspec.yaml`, `motion_account` git bağımlılığı); Core kodunu Ostinato'dan değiştiremeyiz.
- 13 ile ülkenin dijital rıza yaşı arasındaki hesap için Core'da veli onayı VAR: `MotionParentalConsent { none, pending, approved, denied, expired }` (`motion_account_client.dart`), `motion-parental-consent` edge fonksiyonu ve `motion_parental_consents` tablosu (Core `docs/compliance/YAS-VELI-VE-SAKLAMA.md` okundu; SQL/edge kaynağı okunmadı). Gerçek akış: genç OTURUM AÇIKKEN veli e-postasını girer; 10 dk yeniden gönderim, günde 5 sınır; bağlantı 7 gün geçerli; veli adresi açık metin saklanmaz, yalnız SHA-256 özeti (belge satır 35); RET hesabı SİLER (satır 39); onaylanmayan hesap 30 gün sonra `motion_purge_unconsented_accounts()` ile silinir (satır 41). 13 altı için sunucu tetikleyicisi kaydı reddeder (`P0013`). İstemci reddedilme nedenleri `MotionConsentRequestError` (`invalidParentEmail`, `parentEmailIsTeen`, `tooSoon`, `dailyLimit`, `mailUnavailable` vb.). `docs/store/SALES-OPEN-REVIEW-AND-SANDBOX.md` onaylanmayan genç hesabının Core'da 30 gün sonra silindiğini söyler (Core R4 notuna atıfla; Core kaynağından yeniden doğrulanmadı).
- Ostinato tarafı yalnız bir gerçeği saklar. `lib/app/age_gate_store.dart` `AgeGateStore`: `ostinato.age_gate.v1.json` dosyasında sabit `{"schemaVersion":1,"blocked":true}`; doğum ay/yılı, ülke, e-posta, hesap kimliği tutulmaz. `read()`: dosya yoksa engel yok; dosya var ama okunamaz/değişmişse engel sürer. `markBlocked()`: atomik yazım (`.tmp` + rename).
- Bağlama: `lib/app/motion_account_bootstrap.dart` satır 38-39 `ageGate.read()` ile `ageBlocked` hesaplar; satır 57-58 `ageBlocked`/`onAgeBlocked: ageGate.markBlocked` verir; satır 81-85 `blockUnderAge` sonucu bir kez kalıcılaştırır; satır 106-107 her hesap sayfasına `ageBlocked` olarak geri verir. Sonuç: başka bir yaş girmek aynı cihazda kaydı yeniden açmaz.
- Testler: `test/age_gate_store_test.dart` (3 test: işaretçi yok = engel yok; yeni örnekte kalıcılık ve yalnız sabit içerik; bozuk/değişmiş işaretçi engelli) ve `test/age_gate_binding_test.dart`.
- Mağaza yaş sinyali yalnız sıkılaştırır ve Core'dadır: `motion_account_page.dart` satır 235 `MotionAgePolicy.storeCheck` mağaza `<13` ise aynı kalıcı engeli uygular; Ostinato tarafında yalnız `ios/Runner/Runner.entitlements` (`com.apple.developer.declared-age-range`) vardır. `lib/app/ostinato_release_policy.dart` yaş sinyali taşımaz (yalnız teen satın alma politikası, satır 85); bayrak yeri olarak önerilmesi §7'de ayrıdır.
- 13 altı kullanıcı bugün uygulamayı hesapsız (misafir) kullanır: cihaz üstü pratik açık, hesap/satın alma yok (`docs/store/RELEASE-REVIEW.md` satır 59, `SALES-OPEN-REVIEW-AND-SANDBOX.md` S11).
- Teen satın alma politikası (OST-K1): `ostinatoTeenPurchasePolicy = storeFamilyControls` (`ostinato_release_policy.dart` satır 85); 13 altı satın alamaz.

## 2. Karar

Kurucu kararı (2026-11-15, Motion orchestration üzerinden; kayıt: vault `20 Şirketler/Motion/⚖️ Karar — Ostinato ve Core kurucu kararları (2026-11-15).md`): SEC-OST-02 → **"b: Veli izni akışı"**. 13 yaş altı veli onayıyla girer. Önce ADR (bu belge), sonra bayrak arkasında KAPALI uygulama ve test. Mağaza/yaş derecesi değişikliği kurucuya BİLGİ olarak iletilir.

Bu ADR'nin önerdiği çerçeve:

1. Veli onayı olmadan 13 altı için hiçbir kişisel veri toplanmaz ve çevrimiçi hiçbir özellik açılmaz (bugünkü misafir davranışı aynen).
2. İzin yöntemi, saklama ve mağaza yönü §6'daki kurucu kararlarına bağlıdır; seçilene kadar akış KAPALI kalır.
3. Yaş bandı mantığı Core'a aittir; yeni "13 altı + veli izni" bandı bir Core işi gerektirir (§5, §7). Ostinato Core'u yeniden uygulamaz.

## 3. Akış (öneri)

1. Yaş sinyali: bugünkü tarafsız yaş ekranı (yalnız ay/yıl, ön seçim yok) + mağaza yaş sinyali (yalnız sıkılaştırır). Değişmez.
2. 13 altı sonucu: bugün kalıcı engel. Bayrak AÇIKKEN engel yerine "veli izni gerekli" durumu: çocuğun hesabı oluşturulmaz; yalnız veli iletişim adımı gösterilir.
3. Veli izni yolu (yöntem §6-1'de seçilecek). Seçenekler:
   - (a) E-posta artı doğrulama bağlantısı: veli adresine bağlantı gider; veli bağlantıda beyan ve onay verir. Bugün 13+ yolunda Core'da var; en az sürtünme. ABD COPPA'da çocuğun verisi yalnız dahili amaçlarda kullanılıyorsa kabul edilen "e-posta artı" yöntemi sayılır; veli beyanının sahte olma riski yüksek, hukuk doğrulaması gerekir.
   - (b) Mağaza aile mekanizması: iOS "Ask to Buy"/Aile Paylaşımı ve Play ebeveyn onayı. Hesap izni için değil satın alma onayıdır; tek başına veri izni yerine geçmez (kesin değil, doğrulama gerekir).
   - (c) Daha güçlü doğrulama (küçük bir kart doğrulama işlemi, kimlik kontrolü, görüntülü doğrulama): hukuken en güvenli, ama maliyet, sürtünme ve ek kişisel veri getirir; bugün hiçbir altyapısı yok.
4. İzin bekleme durumu (çocuğun yapabilecekleri): yalnız bugünkü misafir kapsamı. Hiçbir kişisel veri, hesap, çevrimiçi özellik ya da satın alma yok. Ham ses ve video cihazdan çıkmaz (mevcut politika; mikrofon cihaz üstünde işlenir). Veli e-postası dışında hiçbir şey çocuğa bağlı olarak sunucuya gitmez.
5. İzin reddi: çocuk hesabı hiç açılmaz; mevcut `AgeGateStore` engeli ile aynı sonuç (kalıcı), veli e-postası silinir (§4).
6. Süre aşımı: bekleme penceresi dolunca (Core'un mevcut kuralı 30 gün; 13+ yolunda `MotionParentalConsent.expired` var) bekleyen kayıt ve veli e-postası silinir; çocuk yeniden başlatabilir mi sorusu §6-5'te.
7. İzin geri çekme: veli onayı istediği an geri çekebilir. Geri çekme: hesap kısıtlanır, bir süre içinde silinir (süre §6'da); çocuğun cihaz üstü yerel pratik kaydı cihazda kalır.
8. Veli panosu ve silme hakkı: veli, çocuğun hesabına bağlı veriyi görebilmeli ve silebilmeli. Asgari: silme isteği bağlantısı (hesap silme akışı bugün uygulama içinde var). Tam veli panosu bu ADR'de önerilmez; ilk sürümde e-posta bağlantıları (onayı geri çek, sil) yeterli sayılır.

## 4. Saklanan veri (en az)

Sunucu (Core/Supabase; şema Core işidir):
- yaş bandı (`under_13_consented` gibi bir bant; doğum günü asla yok, bugünkü ay/yıl kuralı sürer),
- izin durumu (`pending/approved/denied/expired/withdrawn`), tarihler (istek, karar), doğrulama yöntemi etiketi,
- veli e-postası: Core bugün ham adresi saklamaz, yalnız SHA-256 özetini (`YAS-VELI-VE-SAKLAMA.md` satır 35); adres yalnız gönderim anında işlenir. Bu ADR bunu korur. Saklanan özetin amacı ve süresi §6-4'tedir.

Cihaz: bugünkü `ostinato.age_gate.v1.json` korunur; izin durumu için yeni dosya EKLENMEZ (durum Core'dan okunur), böylece cihazda ek kişisel veri oluşmaz.

Saklanmaz: doğum günü, çocuğun adı/e-postası (hesap açılana kadar), ham ses/video, kimlik belgesi görüntüsü, kart numarası, konum, reklam kimliği.

Silinme iki taraflıdır. Sunucu: `motion-delete-account` Auth kullanıcısını siler; `motion_profiles`, `motion_entitlements`, `motion_age_declarations`, `motion_parental_consents` FK cascade ile gider, anonim makbuz yazılır (`YAS-VELI-VE-SAKLAMA.md` satır 64); bu Core işidir. Ostinato: `deleteAccountData` / `AccountDeletionCoordinator` YALNIZ yerel dosyaları siler (`lib/app/account_data_directory.dart` satır 40-43: doğrulanmış hesap silmesi sonrası); izin/veli kaydına dokunmaz ve genişletilmesi önerilmez. İki taraf birlikte çalışır: sunucu silmesi makbuz üretir, Ostinato makbuzla yerel veriyi siler. Hesap açılmadan önceki bekleyen kayıt (§6-6) için silme Core tasarımına bağlıdır.

## 5. Mağaza yaş derecesi etkisi

Bu bölüm doğrulanmış resmi metne ve belirtilen yerlere dayanır; "kesin değil" işaretli yerler hukuk/mağaza doğrulaması ister. Bugünkü iç tahmin: App Store 4+ / Google Play Everyone (`docs/store/listing.json` `$ageRating.expectedTier`, "TAHMIN, nihai sonuç mağaza süreci").

Apple:
- Yaş derecesi anketi içerik ve yeteneklere (reklam, kullanıcı içeriği, sohbet, web erişimi) bakar; veli izni akışı derece değerini tek başına artırmaz, ama "In-App Controls: Parental Controls / Age Assurance" yanıtları geçerlidir. Anket alanları ve değer tabloları OS sürümüne göre değişir (iOS 26+ yeni aralıklar). Kaynak: https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions (okundu).
- Kids kategorisine girmek zorunlu değil. Girilirse (Kılavuz 1.3, 5.1.4; https://developer.apple.com/app-store/review/guidelines/ okundu): uygulama dışı bağlantı, satın alma fırsatı ve dikkat dağıtıcılar yalnız ebeveyn kapısı arkasında olabilir; kişisel veya cihaz bilgisi üçüncü taraflara gitmemeli; üçüncü taraf analitik ve reklam olmamalı (sınırlı istisnalar). 5.1.4: doğum tarihi ve veli iletişimi yalnız yasal uyum amacıyla istenebilir; ebeveyn kapısı veri rızası yerine geçmez. "For Kids" gibi terimler yalnız Kids kategorisi için ayrılmıştır (2.3.8). Ostinato'nun ücretli abonelikleri Kids kategorisiyle çakışır (§6-3).

Google Play:
- Hedef kitle çocukları içeriyorsa Families politikası geçerli (kaynak: https://support.google.com/googleplay/android-developer/answer/9893335, okundu): Play Console "Target audience and content" doğru beyan edilmeli; hassas veri (mikrofon, kamera dahil) açıklanmalı; yalnız çocuklara hedefli uygulamalar AAID aktarmaz, AD_ID izni istemez; reklam SDK'ları onaylı olmalı; karma kitlede tarafsız yaş ekranı ve çocuk için kişiselleştirilmiş reklam yok. Data safety formu çocuklardan toplanan veriyi yansıtmalı. Bugün 13 altı misafir olarak kullanabiliyor; Play'e hangi hedef kitle beyan edildiği bu ADR için doğrulanmadı (Play Console okunmadı).
- Değişim: hedef kitlede "13 altı" yaş grubu işaretlenirse Families politikası, Data safety ve IARC yeniden gözden geçirilmeli; uygulama güncellemesi gerekir.

Hukuki dayanaklar (hukuki tavsiye değil; doğrulanmadı, hukuk gerekir):
- COPPA: 13 altı çocuğa yönelik çevrimiçi hizmetlerde doğrulanabilir veli onayı; 16 CFR Part 312 (§312.5 yöntemler). 2025 değişikliklerinin ayrıntısı bu belgede doğrulanmadı. Kaynak: https://www.ecfr.gov/current/title-16/chapter-I/subchapter-C/part-312 (erişilemedi/okunmadı).
- GDPR Art. 8: bilgi toplumu hizmetinde çocuğun rızası 16 (üye devlet 13'e kadar indirebilir); altında veli onayı, çaba ile doğrulama. Core `rules` tablosu ülke bazlı değerleri taşır (`motion_age_policy.dart`); Core kendi notunda "counsel review" ister.
- KVKK: Türkiye'de 18 yaş altı için yasal temsilci; Core tablosu TR=18 (`motion_age_policy.dart`). KVKK'da çocuk verisine özel açık bir yaş eşiği kuralı olmayabilir; hukuk gerekir.

Özet etki (kurucuya BİLGİ): (1) Apple yaş derecesi anketi ve Play hedef kitle/Data safety yeniden gözden geçirilir; derece değişmesi beklenmez ama kanıtlanmadı. (2) Kids/Families kategorisi hedeflenmezse kısıtlar (analitik, reklam, satın alma kapısı) zorunlu olmaz; ama 13 altı gerçek kullanıcı olduğu için gizlilik politikası ve mağaza beyanları güncellenmeli. (3) Mağaza metinleri ("Accounts require age 13 or older", `docs/store/RELEASE-REVIEW.md` satır 59) bayrak açılırken değişir; şimdi değiştirilmedi.

## 6. Açık kurucu kararları (6 madde; 6. madde Core tasarım boşluğudur)

1. İzin yöntemi. Seçenekler: (a) e-posta artı doğrulama bağlantısı, (b) mağaza aile mekanizmasını ek kapı olarak kullanmak, (c) daha güçlü doğrulama. Öneri: (a), çocuğa bağlı veri hesap açılana kadar toplanmaz ve hukuk ek doğrulama istiyorsa (c) sonradan eklenir.
2. Kids/Families kategorisi hedef mi? Seçenekler: (a) hayır, karma kitle, kategoriye girilmez; (b) evet. Öneri: (a); (b) abonelik satın alma ve üçüncü taraf kısıtları nedeniyle ayrı kararla.
3. 13 altı için ücretli abonelik. Seçenekler: (a) satın alma kapalı (bugünkü kural), (b) mağaza aile onayıyla açık. Öneri: (a).
4. Veli adresi özeti saklama (Core ham adresi saklamıyor, yalnız SHA-256 özet). Seçenekler: (a) karar anında özeti de sil, yalnız izin durumu, tarih ve yöntem kalsın; (b) izin ispatı ve tekrar-istek sınırı için özeti sınırlı süre tut (süreyi hukuk belirler). Öneri: (a); ispat zorunluysa (b). Not: tek yönlü özet kişisel veri sayılmayabilir ya da sayılabilir; kesin değil, hukuk gerekir.
5. Süre aşımı ve yeniden deneme. Core'da bugün: bekleyen kayıt 30 gün sonra silinir; bağlantı 7 gün geçerli; 10 dk yeniden gönderim, günde 5 istek (kaynak: `YAS-VELI-VE-SAKLAMA.md` satır 33-41, 13+ yolu için). "Yeniden başlatma" için ayrı bir kural belgelenmemiştir; 13 altı için tanımsızdır. Seçenekler: (a) 30 gün sonra sil, yeni istek mümkün ve aynı gönderim sınırları geçerli; (b) bir kez, sonra kalıcı engel. Öneri: (a), gönderim sınırları Core'dakiyle aynı kalsın; yeniden başlatma kuralı Core'da yazılmalı.
6. Hesapsız bekleyen izin kaydının kimliği. Core'da veli isteği açık oturumlu bir genç hesabı ister, ret hesabı siler ve 13 altı kayıt `P0013` ile reddedilir; §3'teki "çocuk hesabı oluşturulmaz" bununla çelişir. Çocuğun hesabı yokken bekleyen izin hangi kimliğe/cihaza bağlanır? Seçenekler: (a) çocuk için kısıtlı hesap açılır (çocuğun e-postası izinden önce toplanır; "izinsiz veri yok" ilkesine aykırı); (b) cihaz başına rastgele, çocuğa ait olmayan bir bekleme jetonu: kayıt yalnız jeton özeti + veli adres özeti + tarih; çocuk e-postası/hesabı izinden SONRA; (c) veli kendi Motion hesabıyla başlatır ve çocuk profili ona bağlanır (aile modeli; en büyük Core işi). Öneri: (b); kesin değil, Core tasarımı ve hukuk onayı gerekir.

Ek bağımlılık (karar değil): akış Core'da yeni bir yaş bandı ve sunucu değişikliği ister; Ostinato bunu Core'dan bir sürümle tüketir. Core işi Motion orchestration üzerinden ayrı biletle istenir.

## 7. Uygulama planı (sonraki bilet; bu görevde YAPILMADI)

- Bayrak: `ostinatoParentalConsentEnabled`, `lib/app/ostinato_release_policy.dart` içinde, varsayılan `false`, dokümantasyon yorumlu (diğer bayraklarla aynı kalıp). KAPALIyken davranış bugünküyle birebir (kalıcı 13 altı engeli).
- Önkoşul: Core'da 13 altı + veli izni bandı ve sunucu fonksiyonu; Core revizyonunun `pubspec.yaml`'a sabitlenmesi. Core hazır değilse uygulama bileti başlamaz.
- Dosyalar (öneri): `lib/app/age_gate_store.dart` (yalnız "kalıcı engel" anlamını korur; izin verilmiş çocuk için engel işaretçisi yazılmaz, mevcut işaretçi izinle SİLİNMEZ: bkz. aşağıda), `lib/app/motion_account_bootstrap.dart` (bayrak açıkken `ageBlocked` yerine izin akışı), `lib/app/ostinato_release_policy.dart` (bayrak), `docs/store/*` (yalnız bayrak açılırken, kurucu bilgisi ile).
- AgeGateStore etkisi: bugünkü "geri alınamaz engel" kuralı korunur. Bayrak AÇIKKEN 13 altı sonuç iki yola ayrılır: izin akışı başlatılır (işaretçi yazılmaz) ya da veli reddederse işaretçi yazılır. Bayrak sonradan açılırsa eski cihazlardaki mevcut işaretçi de kalıcı engel olarak kalır; kaldırmak için kullanıcı eylemi (veli akışı) gerekir. Bu kurucu onayı gerektirir (tek taraflı otomatik açma yok).
- Test listesi (öneri): bayrak kapalıyken mevcut 3 + binding testleri aynen geçer; bayrak açıkken 13 altı sonucu izin akışına gider ve hesap oluşturmaz; izin bekleme: hiçbir ağ çağrısı/hesap yok; ret: kalıcı engel yazılır; süre aşımı: engel yazılmaz, yeniden başlatma sınırlı; geri çekme: hesap kısıtlanır; bozuk işaretçi engelli kalır; işaretçide doğum/ülke/e-posta yok; hesap silme izin kaydını da siler; ham ses/video çıkışı yok (mevcut egress testi bozulmaz: `test/ost_p0_02_egress_test.dart`).
- Geri alma: bayrağı `false` bırakmak ya da PR'ı geri almak; cihazdaki işaretçi dosyası değişmez, sunucu kayıtları Core'un silme akışına bağlı.

## 8. Riskler

- Core'a bağımlılık: yeni bant Core'dadır; gecikirse akış açılamaz.
- Veli beyanı sahte olabilir; seçilen yöntem hukuken yeterli olmayabilir (hukuk doğrulaması şart).
- 13 altı kitle mağaza beyanlarını (Play hedef kitle, Data safety, Apple anket) ve gizlilik politikasını (`https://yulalab.com/privacy/motion`) etkiler; hatalı beyan mağaza riski taşır.
- Mikrofon verisi çocuk için "hassas" sayılır (Play Families); ham ses cihazdan çıkmama taahhüdü testle korunmalı.

## 9. Kapsam dışı

Kod, bayrak, test, `pubspec.yaml`, `tools/` değişikliği; Core kodu; mağaza/yaş derecesi gönderimi; gizlilik politikası ve mağaza metinleri; fiyat/abonelik; Supabase prod; Kids kategorisi başvurusu; veli panosu arayüzü (tam sürüm).
