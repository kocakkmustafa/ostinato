# Ostinato satış açık ilk sürüm — App Review metni ve sandbox kabul planı (2026-10-23)

Kaynak karar: kullanıcı kararı 23 Ekim, madde 4. Satış beş Motion app'te ilk sürümde açık; app'e özgü abonelik ve Motion+ satılır.
Bu belge yerel taslaktır. Şunları yetkilendirmez: App Store Connect/Play Console kaydı, ürün oluşturma, fiyat, upload, submit, sandbox satın alma, secret girişi. Sandbox hesabı kullanıcıdan gelir; parola sohbete, repoya veya rapora yazılmaz.

## 1. Uygulamada bağlananlar (main; satış birleşmesi `wip/ostinato-2026-10-23` → main)

| Parça | Durum |
|---|---|
| `lib/app/ostinato_release_policy.dart` | `ostinatoPaidFeaturesAvailable = true`; kamera pratiği kapalı kalır (`ostinatoCameraPracticeAvailable = false`) |
| Hesap sayfası (Core `MotionAccountPage`) | `paidFeaturesAvailable: true` → üyelik durumu (`motion-check-membership`), "Abonelik seçenekleri", "Hesabı ve üyeliği yenile" |
| Ücretli kapı (Core `requireMotionPaidAccess`) | Aynı bayrak; oturum yoksa hesap sayfası, üyelik yoksa Core `MotionMembershipPage` |
| 13+ yaş/veli akışı | Core yaş beyanı ve veli onayı hesap sayfasında. 13 altı sonuç `AgeGateStore` ile cihazda tek bir sabit gerçek olarak saklanır (`{"schemaVersion":1,"blocked":true}`; doğum tarihi, ülke ve hesap tutulmaz) ve her sayfaya `ageBlocked` olarak geri verilir |
| Native | `in_app_purchase_storekit` ve `url_launcher_ios` Podfile.lock'ta. Android BILLING izni eklenti manifestinden birleşir. iOS IAP için ek entitlement gerekmez |

**Paywall A (kurucu kararı 23 Ekim, beş app ortak).**
- Gitarda ilk 12 ders, piyano, ukulele, bas ve şanda ilk 8 ders ücretsizdir.
- Kalan dersler abonelik ister; gitarın bağımsız pratik modülü (49–60) de buna dahildir.
- Ders listesi, başlıklar ve ilerleme kayıtları her zaman görünür kalır.
- Tek kaynak `lib/app/course_access.dart`:
  - `ostinatoFreeLessonCounts`
  - `isFreeLesson`: bilinmeyen kursta ücretsiz ders yoktur; satış kapalıysa hiçbir ders kilitli değildir.
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

> Ostinato offers optional auto-renewable subscriptions: "Ostinato" (this app only; USD 11.99 per month or 69.99 per year) and "Motion+" (all five Motion apps by YULA Lab; USD 19.99 per month or 129.99 per year). Eligible new subscribers get a 14-day free trial. The first 12 guitar lessons and the first 8 lessons of the piano, ukulele, bass and voice courses are free without an account. Later lessons, including the guitar independent-practice module, need a subscription. Lesson titles and progress records always stay visible. To see the paywall, open the guitar course and tap lesson 13, or open any course and tap lesson 9.
>
> To view the subscription options, open Settings > Account, sign in, and tap "Membership options". Prices and periods come from the App Store. The auto-renewal terms, Terms of Use (https://yulalab.com/terms) and Privacy Policy (https://yulalab.com/privacy/motion) are shown on the same screen. "Restore purchases" is available on that screen. Cancellation is done in the App Store subscription settings, which the app opens from "Manage subscription". Purchases are verified on our server before access is granted. Deleting the Motion account does not cancel a store subscription; the deletion dialog says so.
>
> Accounts require age 13 or older. The age screen asks only month and year, with no preselected value. If the user is under 13, account sign-up is blocked on that device. Users under their country's digital-consent age get a restricted account until a parent or guardian approves by email. On-device practice remains available without an account.
>
> Demo account: [entered privately in App Store Connect; not stored in the repository].

## 5. Sandbox kabul planı

### 5.1 Ön koşullar (kullanıcı/servis girdisi; bu oturum yapmaz)

1. **Supabase:** `motion-check-membership` ve `motion-verify-purchase` Edge Function'ları Core pin `5832031` sürümüyle dağıtılmış olmalı. Function secret **adları** (değerler girilmez, okunmaz):
   - Apple: `MOTION_APPLE_IAP_ISSUER_ID`, `MOTION_APPLE_IAP_KEY_ID`, `MOTION_APPLE_IAP_PRIVATE_KEY` (App Store Server API anahtarı)
   - Google: `MOTION_GOOGLE_PLAY_SERVICE_ACCOUNT` (Play Developer API yetkili servis hesabı)
   - Veli e-postası için: `MOTION_MAIL_API_URL`, `MOTION_MAIL_API_KEY`, `MOTION_MAIL_FROM`, `MOTION_CONSENT_PAGE_URL`
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
| S12 | 13 ≤ yaş < rıza yaşı | Kısıtlı hesap, veli e-postası gönderilir. Kısıtlı hesabın satın alma davranışı **hukuk/ürün kararı** (aşağıda) |
| S13 | Hesap silme (aktif abonelikle) | Silme uyarısı aboneliğin mağazadan iptal edilmesi gerektiğini söyler; abonelik mağazada sürer |
| S14 | 14 dilde membership sayfası, 320 pt genişlik, %200 metin | Fiyat, yenileme metni, restore ve bağlantılar görünür, taşma yok |
| S15 | Yeni sandbox abonesi deneme ile başlar | 14 günlük tanıtım teklifi mağaza ekranında görünür (sandbox'ta hızlandırılmış); deneme süresince `active=true`; deneme sonunda ücret veya iptal sunucuya yansır |
| S16 | Sınır dersleri: gitar 12→13, diğer kurslarda 8→9 ("Sonraki ders" ve listeden) | 12. ve 8. ders üyelik sorulmadan açılır; 13. ve 9. ders oturum ve üyelik ister; üye olmayan kullanıcı listede kalır, ilerleme satırları görünür |
| S17 | Yerelleştirilmiş fiyat (TR, US, JP storefront) | Paywall mağazanın döndürdüğü yerel fiyatı ve dönemi gösterir; uygulamada sabit USD metni yoktur |

### 5.3 Açık kararlar ve girdiler

- **ASC/Play'de SKU, fiyat ve 14 günlük deneme teklifinin gerçekten var olduğu** konsol erişimi gerektirir; kullanıcı girdisidir. `consoleExistenceVerified: false`.
- **Reşit olmayanların satın alması:** 13–17 kısıtlı veya genç hesabın satın alması mağazanın aile kontrollerine (Ask to Buy, Play ebeveyn onayı) mı bırakılacak, yoksa uygulama veli onayına kadar satışı kapatacak mı? Hukuk incelemesi gerekir. Core belgesi bunun hukuki görüş olmadığını söyler.
- **Storefront ülkesi:** Hesap sayfasına `storefrontCountry` henüz verilmiyor. Core cihaz bölgesini kullanır; bölge bilinmiyorsa 16 yaş eşiğini uygular. StoreKit storefront ülkesinin bağlanması ayrı küçük bir iştir.
- Sandbox tester (Apple), lisans test kullanıcıları (Play), function secret'ları ve internal testing upload onayı kullanıcıdan gelir.
