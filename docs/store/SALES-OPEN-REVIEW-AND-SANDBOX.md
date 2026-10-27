# Ostinato satış açık ilk sürüm — App Review metni ve sandbox kabul planı (2026-10-23; Core R3 güncellemesi 2026-10-25; Core R4 + OST-K1 2026-10-27)

Kaynak karar: kullanıcı kararı 23 Ekim, madde 4. Satış beş Motion app'te ilk sürümde açık; app'e özgü abonelik ve Motion+ satılır.
Bu belge yerel taslaktır. Şunları yetkilendirmez: App Store Connect/Play Console kaydı, ürün oluşturma, fiyat, upload, submit, sandbox satın alma, secret girişi. Sandbox hesabı kullanıcıdan gelir; parola sohbete, repoya veya rapora yazılmaz.

## 1. Uygulamada bağlananlar (main; satış birleşmesi `wip/ostinato-2026-10-23` → main)

| Parça | Durum |
|---|---|
| `lib/app/ostinato_release_policy.dart` | `ostinatoPaidFeaturesAvailable = true`; kamera pratiği kapalı kalır (`ostinatoCameraPracticeAvailable = false`) |
| Hesap sayfası (Core `MotionAccountPage`) | `membershipAvailable: true` → üyelik durumu (`motion-check-membership`), "Abonelik seçenekleri", "Hesabı ve üyeliği yenile" |
| Ücretli kapı (Core `requireMotionPaidAccess(salesAvailable:)`) | Aynı bayrak; yalnız kilitli derste çağrılır; oturum yoksa hesap sayfası, üyelik yoksa Core `MotionMembershipPage` |
| Kamera kapısı (Core `requireMotionCameraAccess`) | Duruş dersindeki kurulum denetimi bu kapıdan geçer; `ostinatoCameraPracticeAvailable = false` olduğu için aboneye de kapalıdır, hesap/satın alma adımı açılmaz. Kütüphane metni Core `motionCameraCoachingAvailable`'ı okur |
| 13+ yaş/veli akışı | Core yaş beyanı ve veli onayı hesap sayfasında. 13 altı sonuç `AgeGateStore` ile cihazda tek bir sabit gerçek olarak saklanır (`{"schemaVersion":1,"blocked":true}`; doğum tarihi, ülke ve hesap tutulmaz) ve her sayfaya `ageBlocked` olarak geri verilir |
| Native | `in_app_purchase_storekit` ve `url_launcher_ios` Podfile.lock'ta. Android BILLING izni eklenti manifestinden birleşir. iOS IAP için ek entitlement gerekmez. Core R3 mağaza yaş sinyali için `ios/Runner/Runner.entitlements` → `com.apple.developer.declared-age-range = true` (App ID capability yönetimde; yoksa sinyal `null`, akış değişmez). Android'de ek satır yok (`age-signals 0.0.4` Gradle ile gelir) |

**Paywall A (kurucu kararı 23 Ekim, beş app ortak).**
- Gitarda ilk 12 ders, piyano, ukulele, bas ve şanda ilk 8 ders ücretsizdir.
- Kalan dersler abonelik ister; gitarın bağımsız pratik modülü (49–60) de buna dahildir.
- Ders listesi, başlıklar ve ilerleme kayıtları her zaman görünür kalır.
- Tek kaynak `lib/app/course_access.dart`:
  - `ostinatoFreeLessonCounts` (OST-K2 kurucu kararı 2026-10-25: sayılar aynen) ve `ostinatoCourseShapes` (toplam/ilk modül; test paketli kurs dosyalarıyla karşılaştırır)
  - `isFreeLesson`: Core `isLessonUnlocked(..., freeLessonLimit:)`; Core'un varsayılan formülü (gitar 20, piyano 9) yerine app sayıları override olarak verilir. Bilinmeyen kursta veya kurs dışı indekste ücretsiz ders yoktur; satış kapalıysa hiçbir ders kilitli değildir.
  - `admitLesson`: Core `requireMotionPaidAccess`'i çağırır. Hesap hizmeti yoksa kilitli kalır ve nedenini söyler.
- Beş kurs ekranında listeden açma, "Sonraki ders" ve "Önceki ders" geçişleri kapıdan geçer.
- Testler `test/course_access_test.dart` dosyasında:
  - sınırlar
  - ücretsiz ders kontrol çağırmaz
  - üye olmayan kullanıcı listede kalır
  - üye sınırı geçer
  - süresi dolan üye ilerleyemez
  - hesap hizmeti yokken kapı kapalı kalır
  - gitar 13. ders ilerleme satırı görünür halde kilitli
- Onboarding cümlesi ve mağaza açıklamaları güncellendi.

**Fiyat (kurucu kararı 23 Ekim, USD baz):**
- Ostinato aylık $11,99 / yıllık $69,99
- Motion+ aylık $19,99 / yıllık $129,99
- 14 gün ücretsiz deneme: uygun yeni abonelere, mağaza tanıtım teklifi olarak

Uygulama yalnız mağazanın döndürdüğü yerelleştirilmiş fiyatı gösterir; fiyat koda gömülmez. Fiyat ve deneme teklifi ASC ve Play Console'da **kullanıcı tarafından** kurulur. Ayrıntılar `docs/store/listing*.json` içindeki `$pricing20261023` alanında.

## 2. SKU eşlemesi (Core `MotionMembershipPage`, `MotionApp.ostinato`)

| Mağaza | Ürün kimliği | Kapsam / dönem |
|---|---|---|
| App Store | `com.yulalab.ostinato.individual.monthly` | Ostinato, aylık |
| App Store | `com.yulalab.ostinato.individual.yearly` | Ostinato, yıllık |
| App Store | `com.yulalab.ostinato.motionplus.monthly` | Motion+ (beş app), aylık |
| App Store | `com.yulalab.ostinato.motionplus.yearly` | Motion+ (beş app), yıllık |
| Google Play | `ostinato_individual` (monthly/yearly base plan) | Ostinato |
| Google Play | `ostinato_motion_plus` (monthly/yearly base plan) | Motion+ |

Kimlikler Core kodundan türetildi. Mağaza panelindeki varlıkları, durumları ("Ready to Submit"/aktif), abonelik grubu ve fiyatları bu oturumda **doğrulanmadı**; kullanıcı panelde doğrulamalı. Dört iOS ürünü aynı abonelik grubunda olmalı ki yükseltme/düşürme mağaza tarafından yönetilsin. İlk abonelik ürünleri ilk app sürümüyle birlikte incelemeye gönderilmeli.

## 3. Akış ve uyum öğeleri (Core membership sayfası)

- **Satın alma:**
  - Mağazanın döndürdüğü yerelleştirilmiş fiyat ve dönem gösterilir; sabit fiyat yazılmaz.
  - Satın alma, sunucuda `motion-verify-purchase` ile doğrulanmadan erişim açmaz.
- **Otomatik yenileme metni** satın alma düğmesinin yanında yer alır. Kullanım koşulları `https://yulalab.com/terms`, gizlilik `https://yulalab.com/privacy/motion`.
- **Geri yükleme:** Restore düğmesi mağaza işlemlerini yeniden gönderir; doğrulama yine sunucudadır. Erişim hesaba bağlıdır.
- **İptal:** Uygulama içinde iptal yoktur. "Aboneliği yönet" düğmesi Apple'da `https://apps.apple.com/account/subscriptions`, Play'de `https://play.google.com/store/account/subscriptions` adresini açar.
- **Hesap silme mağaza aboneliğini iptal etmez.** Silme iletişim kutusu ve review notu bunu söyler.
- **Bilinmeyen sonuç erişim vermez:** zaman aşımı, ağ hatası veya doğrulanamayan yanıtta erişim kapalı kalır ve "üyelik doğrulanamadı" gösterilir.

## 4. EN App Review notes (draft; replaces the "sales disabled" paragraph in RELEASE-REVIEW.md)

> Ostinato offers optional auto-renewable subscriptions: "Ostinato" (this app only; USD 11.99 per month or 69.99 per year) and "Motion+" (all five Motion apps by YULA Lab; USD 19.99 per month or 129.99 per year). Eligible new subscribers get a 14-day free trial; the Motion+ trial is offered once per Motion account. The first 12 guitar lessons and the first 8 lessons of the piano, ukulele, bass and voice courses are free without an account. Later lessons, including the guitar independent-practice module, need a subscription. Lesson titles and progress records always stay visible. To see the paywall, open the guitar course and tap lesson 13, or open any other course and tap lesson 9.
>
> To view the subscription options, open Settings > Account, sign in, and tap "Membership options". Prices and periods come from the App Store. The auto-renewal terms, Terms of Use (https://yulalab.com/terms) and Privacy Policy (https://yulalab.com/privacy/motion) are shown on the same screen. "Restore purchases" is available on that screen. Cancellation is done in the App Store subscription settings, which the app opens from "Manage subscription". Purchases are verified on our server before access is granted. Deleting the Motion account does not cancel a store subscription; the deletion dialog says so.
>
> Accounts require age 13 or older. The age screen asks only month and year, with no preselected value. Where the App Store shares an age range (Declared Age Range), it can only tighten this check: an under-13 range blocks sign-up, and a declared age above the shared range must be corrected. If the user is under 13, account sign-up is blocked on that device. Users under their country's digital-consent age get a restricted account until a parent or guardian approves by email; a restricted account can still see the subscription offers, and purchases by users under 18 are subject to the App Store's family controls (Ask to Buy); account features stay limited until approval, and users under 13 cannot purchase. On-device practice remains available without an account.
>
> Live camera posture practice and scoring are disabled in this release, also for subscribers.
>
> Demo account: [entered privately in App Store Connect; not stored in the repository].

## 5. Sandbox kabul planı

### 5.1 Ön koşullar (kullanıcı/servis girdisi; bu oturum yapmaz)

1. **Supabase (Core R4 `0d29d1b019033f00828be741aa3e23e3923841be`'ten deploy — R3→R4 `supabase/` değişmedi; paket: Core `scratch/2026-10-25-motion-core-packages/CORE-07-CANLI-DEPLOY.tr.md`):**
   - Migration'lar: `20261021190000_motion_age_consent_retention`, `20261023120000_motion_age_metadata_strip`, `20261025120000_motion_trial_ledger`.
   - Fonksiyonlar: `motion-check-membership`, `motion-verify-purchase`, `motion-parental-consent` (`verify_jwt=false`), `motion-offer-eligibility`, `motion-store-notifications` (`verify_jwt=false`).
   - Function secret **adları** (değerler girilmez, okunmaz):
     - Apple: `MOTION_APPLE_IAP_ISSUER_ID`, `MOTION_APPLE_IAP_KEY_ID`, `MOTION_APPLE_IAP_PRIVATE_KEY`, `MOTION_APPLE_ROOT_CAS_BASE64`
     - Google: `MOTION_GOOGLE_PLAY_SERVICE_ACCOUNT`, `MOTION_RTDN_AUDIENCE`, `MOTION_RTDN_PUSH_SERVICE_ACCOUNT`
     - Veli e-postası (Google Workspace SMTP, Core R2): `MOTION_SMTP_HOST` (`smtp.gmail.com`), `MOTION_SMTP_PORT` (465), `MOTION_SMTP_TLS` (`implicit`), `MOTION_SMTP_USER`, `MOTION_SMTP_PASSWORD` (uygulama şifresi), `MOTION_MAIL_FROM`, `MOTION_CONSENT_PAGE_URL`; isteğe bağlı `MOTION_CONSENT_ALLOWED_ORIGINS`. Eski `MOTION_MAIL_API_URL` / `MOTION_MAIL_API_KEY` Core R2'de kaldırıldı.
   - ASC: App Store Server Notifications v2 URL'si (prod + sandbox) `…/functions/v1/motion-store-notifications/apple`. Play: RTDN Pub/Sub topic + push abonelik (OIDC) `…/google`; Motion+ deneme teklifi "Developer determined" + etiket `motion-plus-trial`.
   - Apple Developer: `com.yulalab.ostinato` App ID'de **Declared Age Range** capability (imzalı IPA profili bunu içermeli).
2. **App Store Connect:** dört ürün aynı grupta ve "Ready to Submit" durumunda. Paid Apps sözleşmesi, vergi ve banka bilgileri aktif. **Sandbox tester hesabı kullanıcıdan** gelir: ayrı bir Apple Account; cihazda Ayarlar > Geliştirici > Sandbox Hesabı'na kullanıcı girer.
3. **Play Console:** iki abonelik ve her birinde monthly/yearly base plan aktif. Lisans test kullanıcıları tanımlı. Imzalı AAB internal testing kanalında olmalı, çünkü Play Billing yalnız Play'den kurulan uygulamada çalışır. **Upload ayrı onay ister.**
4. **Test hesapları:** iki Motion test hesabı (A, B) ve bir 13–17 yaş senaryosu için sentetik beyan. Gerçek kişisel veri kullanılmaz.

### 5.2 Senaryolar (her platformda; kanıt = ekran görüntüsü + sunucu `motion_entitlements` satırı, kimlik özetli)

| # | Senaryo | Beklenen |
|---|---|---|
| S1 | Oturumsuz kullanıcı ücretli içeriğe dokunur | Hesap sayfası açılır; satın alma oturumsuz başlamaz |
| S2 | A hesabı Ostinato aylık satın alır | Sunucu doğrular → `active=true`; ücretli içerik açılır; hesap sayfası "bu app'te üyelik aktif" |
| S3 | A hesabı Ostinato yıllık'a yükseltir | Mağaza grubu yükseltmeyi yönetir; tek aktif hak kaydı |
| S4 | B hesabı Motion+ aylık satın alır | Ostinato açılır; diğer bir Motion app'te `anyActive`/Motion+ görünür (aile çapraz kontrolü) |
| S5 | Uygulamayı sil/yeniden kur → A ile giriş → Restore | Hak geri gelir; başka hesaba devredilmez |
| S6 | Aynı cihazda A çıkış, B giriş | A'nın hakkı B'ye görünmez (sahiplik kontrolü); B satın almadıysa kapalı |
| S7 | Mağaza ayarlarından iptal | Dönem sonuna kadar aktif; sandbox hızlandırılmış süre sonunda `active=false`; içerik kapanır, yerel ilerleme korunur |
| S8 | Sandbox yenileme ve süre dolması | Hızlandırılmış dönemlerde yenileme/bitiş sunucuya doğru yansır |
| S9 | Ödeme reddi / Ask to Buy bekleyen | Erişim açılmaz; bekleyen durum dürüst gösterilir |
| S10 | Ağ kesik / function 5xx | "Üyelik doğrulanamadı"; erişim verilmez, sahte başarı yok |
| S11 | 13 altı beyan | Kayıt engellenir; uygulama yeniden açılınca da engel sürer (`AgeGateStore`); satın alma yüzeyi oturumsuz kalır |
| S12 | 13 ≤ yaş < rıza yaşı, veli onayı **bekleniyor** | Kısıtlı hesap, veli e-postası gönderilir; hesap özellikleri (profil, veli formu dışı) onaya kadar kapalı. **OST-K1 (kurucu kararı 2026-10-25), Core R4 `teenPurchasePolicy: storeFamilyControls`:** üyelik sayfası bireysel + Motion+ tekliflerini ve 14 dilde "18 yaş altı satın almalar mağazanın aile/ebeveyn denetimlerine tabidir" notunu gösterir; ödeme kararı mağazada (iOS Ask to Buy / Play ebeveyn onayı), bekleyen satın alma aktif sayılmaz; sunucu doğrulaması aynı. Ayrıntılı adımlar: Core `scratch/2026-10-25-motion-core-packages/CORE-R3-KABUL-KONTROLLERI.tr.md` "R4 eki" S-R4-1/2/3/5 (S-R4-4 varsayılan politikalı başka app) |
| S13 | Hesap silme (aktif abonelikle) | Silme uyarısı aboneliğin mağazadan iptal edilmesi gerektiğini söyler; abonelik mağazada sürer |
| S14 | 14 dilde membership sayfası, 320 pt genişlik, %200 metin | Fiyat, yenileme metni, restore ve bağlantılar görünür, taşma yok |
| S15 | Yeni sandbox abonesi deneme ile başlar | 14 günlük tanıtım teklifi mağaza ekranında görünür (sandbox'ta hızlandırılmış); deneme süresince `active=true`; deneme sonunda ücret veya iptal sunucuya yansır |
| S16 | Sınır dersleri: gitar 12→13, diğer kurslarda 8→9 ("Sonraki ders" ve listeden) | 12. ve 8. ders üyelik sorulmadan açılır; 13. ve 9. ders oturum ve üyelik ister; üye olmayan kullanıcı listede kalır, ilerleme satırları görünür |
| S17 | Yerelleştirilmiş fiyat (TR, US, JP storefront) | Paywall mağazanın döndürdüğü yerel fiyatı ve dönemi gösterir; uygulamada sabit USD metni yoktur |
| S18 | Motion+ denemesi hesap başına bir kez (Core R3 K3): A hesabı başka bir Motion app'te Motion+ denemesi kullandı, sonra Ostinato'da Motion+ | Deneme iddiası gösterilmez; iOS 16+'da satın almaya `introductoryOfferEligibility=false` eklenir, Play'de deneme teklifi seçilmez (base plan); bireysel plan denemesi etkilenmez. iOS 15'te ikinci deneme engellenemez (bilinen sınır) |
| S19 | Mağaza yaş sinyali (Core R3 K1; iOS 26+ Declared Age Range / Play Age Signals destekli bölge) | Mağaza <13 → kayıt kalıcı engellenir, misafir kullanım açık; beyan mağaza üst sınırından büyükse düzeltme mesajı; sinyal yoksa ülke/veli akışı aynen |
| S20 | Mağaza sunucu bildirimi (Core R3 K2): sandbox'ta iptal/iade/yenileme | `motion-store-notifications` imzalı bildirimi alır, mağazadan yeniden doğrular; `motion_entitlements` satırı uygulama açılmadan güncellenir |

### 5.3 Açık kararlar ve girdiler

- **ASC/Play'de SKU, fiyat ve 14 günlük deneme teklifinin gerçekten var olduğu** konsol erişimi gerektirir; kullanıcı girdisidir. `consoleExistenceVerified: false`.
- **Reşit olmayanların satın alması (OST-K1, kurucu kararı 2026-10-25):** 13–17 yaş hesapların satın alması mağaza aile kontrollerine (Ask to Buy, Play ebeveyn onayı) bırakılır. Core R4 (`0d29d1b`, CORE-12) bunu app başına parametreyle verir; Ostinato `lib/app/ostinato_release_policy.dart` `ostinatoTeenPurchasePolicy = storeFamilyControls` seçer ve hesap sayfası, ücretli ders kapısı ve kamera kapısı bu değeri Core'a geçirir (`test/teen_purchase_policy_test.dart`). Hesap özellikleri veli onayına kadar kapalı kalır, 13 yaş altı satın alamaz; Ostinato Core davranışını aşan yol açmaz. Onaylanmayan genç hesabı Core'da 30 gün sonra silinir; mağaza aboneliği bununla iptal olmaz ve yeni/onaylı hesapta geri yüklenir (Core R4 kırıcı/dikkat 4).
- **Paywall A sayıları (OST-K2, kurucu kararı 2026-10-25):** gitar 12/60, piyano 8/25, vokal 8/22, ukulele 8/24, bas 8/24 — Core `isLessonUnlocked(..., freeLessonLimit:)` override ile birebir; Core formülüne (gitar 20, piyano 9) geçilmez.
- **Storefront ülkesi:** kapandı. Core `30a2cb2`'den (R1 ve sonrası) beri hesap sayfası `countryCode` verilmeyince kayıt/yaş onayında mağaza ülkesini okur (3 sn sınır; hata → cihaz bölgesi; bölge yoksa 16 eşiği). Ostinato ek kablolama yapmaz.
- Sandbox tester (Apple), lisans test kullanıcıları (Play), function secret'ları ve internal testing upload onayı kullanıcıdan gelir.
