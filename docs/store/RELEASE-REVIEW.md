# Ostinato yayın inceleme taslağı — 21 Ekim 2026 (satış notu 25 Ekim 2026)

Bu dosya yerel submission taslağıdır. App Store Connect'e kaydetme, build
upload, submit veya yayın kararı değildir. İmza/paket kanıtı model veya fiziksel
öğretim kabulünü kapatmaz. Tam öğretim hedefi sürer; yazılı ders ve model destek
sınırları ayrı anlatılır.

## Kaynak ve aday

Bu taslak hazırlanırken ürün kaynağı `8e98440ec8ccbb59c462e74de63b623bbd608018`, public
Core pin `d69e10786e2f1cd509b9eeadeb3ef6ea42d93b5d` idi. 14 sunum dili ve 128
yazılı ders kaynakta bulunur. `8e98440` kaynağında analyzer, readonlyformat ve
gerçek manifest kontrolü ile 38 host testi kabul edildi: 38 PASS, 0 FAIL,
0 SKIP, 0 UNRUN. Önceki kaynakların PASS sayıları bu 38'e eklenmez. Bu yerel
metadata değişikliğinin final kaynak kimliği ayrı raporda bağlanır; 38 testin
ölçülen kaynağı `8e98440` olarak kalır. Bu, native paket veya cihaz kabulü değildir.

Tarihsel App Store IPA `1.0.0(4)`, runtime `73b05164`;
SHA256 `2b3bb71bffde11833d2f30f44f4f9d6ff9158a9952e769101615824d9858b1d6`.
Mevcut dağıtım paketi korunur; yalnız EN/TR native izin çevirileri ve eski
kurs baytlarını içerir. Yeni 14 dil/tema/eğitim kaynağının paketi değildir.
Development IPA ve eski export hata makbuzu da tarihsel olarak korunur.

Bu aday için yeni native archive/package veya fiziksel cihaz kabulü yoktur.
Eski arşivin yeniden export edilmesi yeni kaynak içeriğini eklemez. Ayrı
normal ortak native kuyruğu ve yetkili paket fazı gerekir. Yeni credential,
build, imza, export veya upload bu taslakla yetkilendirilmez. Mağazada build4
çakışması güncel panelde doğrulanmamıştır.

## EN reviewer notes — inceleme öncesi son cihaz kontrolü gereken taslak

Draft notes for the new source candidate; do not submit before its host,
package and device checks are complete.

Ostinato provides original written music lessons and practice records, with
course presentation in 14 languages. The guitar path has 60 lessons in 10 modules; written
courses also cover piano (25), ukulele (24), bass (24) and voice (22), each ending in an
independent-practice stage.
Lesson completion is the user's self-report, not a measured mastery result.

Core written lessons are available as a guest. Read the onboarding, open the
library, choose Guitar, then open the guitar learning path and its first lesson.
Try the written exercise and self-check. Course progress stays in the current
guest/account scope on this device. It is not synchronized across devices.

Microphone observation is optional and appears only in the guitar note practice
flow after Start and OS permission. It displays an approximate note/Hz/cents;
it does not grade the target note, chords, rhythm, posture or mastery. Declining
permission leaves the written course available. Raw audio is processed in
bounded temporary device memory; it is not saved or uploaded by this path.

Ostinato offers optional auto-renewable subscriptions: "Ostinato" (this app only; USD 11.99 per month or 69.99 per year) and "Motion+" (all five Motion apps by YULA Lab; USD 19.99 per month or 129.99 per year). Eligible new subscribers get a 14-day free trial; the Motion+ trial is offered once per Motion account. The first 12 guitar lessons and the first 8 lessons of the piano, ukulele, bass and voice courses are free without an account. Later lessons, including the guitar independent-practice module, need a subscription. Lesson titles and progress records always stay visible. To see the paywall, open the guitar course and tap lesson 13, or open any other course and tap lesson 9.

To view the subscription options, open Settings > Account, sign in, and tap "Membership options". Prices and periods come from the App Store. The auto-renewal terms, Terms of Use (https://yulalab.com/terms) and Privacy Policy (https://yulalab.com/privacy/motion) are shown on the same screen. "Restore purchases" is available on that screen. Cancellation is done in the App Store subscription settings, which the app opens from "Manage subscription". Purchases are verified on our server before access is granted. Deleting the Motion account does not cancel a store subscription; the deletion dialog says so.

Accounts require age 13 or older. The age screen asks only month and year, with no preselected value. Where the App Store shares an age range (Declared Age Range), it can only tighten this check: an under-13 range blocks sign-up, and a declared age above the shared range must be corrected. If the user is under 13, account sign-up is blocked on that device. Users under their country's digital-consent age get a restricted account until a parent or guardian approves by email; a restricted account is not offered purchases. On-device practice remains available without an account.

Live camera posture practice and scoring are disabled in this release, also for subscribers. Written piano/ukulele/bass/voice content does not provide validated live technique or voice measurement. Piano lesson05 explicitly states that finger-key contact cannot be measured with the current production provider.

An optional shared Motion account is available under Settings > Account.
Account sign-in, profile, sign-out and common-account deletion use that service.
Account deletion affects the shared account across the five Motion apps;
store subscriptions, if any, are cancelled separately in the store account.
No reviewer password is stored in this repository. Any required existing demo
credentials must be entered privately in App Store Connect after verification.

The public-source audio research/calibration pilot is not bundled or activated.
No GuitarSet benchmark precision/recall is advertised as learner accuracy.
Original demonstration video is not included in this content version.

## Gizlilik formu taslağı ve paket kontrolü

- Support: <https://yulalab.com/support>
- Privacy: <https://yulalab.com/privacy/motion>
- Uygulama dışı hesap silme adayı:
  <https://yulalab.com/privacy/motion#motion-account-deletion>
- Apple source manifesti: EmailAddress, Name, UserID, OtherDiagnosticData,
  CoarseLocation, OtherDataTypes; altısı AppFunctionality, linked, tracking=false.
- Kamera/mikrofon ve yerel ilerleme için bu yolda cihaz dışına collection
  bildirilmez. Auth/provider günlükleri yerel RAM işlemiyle karıştırılmaz.
- Tarihsel IPA4 içinde dokuz privacy manifesti vardır; root manifest güncel
  kaynakla byte eşleşir. Bu, yeni adayın SDK arşiv raporu veya mağaza formu
  kabulü değildir; yeni yetkili pakette envanter tekrar bağlanır.
- `ITSAppUsesNonExemptEncryption` mevcut pakette belirtilmemiş. Export compliance
  sorusu App Store Connect'te gerçek kullanılan kriptografi kapsamına göre
  sahibi tarafından cevaplanmalı; otomatik varsayılan yanıt uydurulmaz.
- Provider saklama süresi/silme politikası, güncel runtime ağ davranışı ve store
  formunun kaydedilmesi henüz kapalı değildir.

## Hesap, abonelik ve restore kabul ayrımı

| Alan | Mevcut kanıt | Açık kapanış |
|---|---|---|
| Konuk ders akışı, hesap kapsamlı yerel ayrım | Önceki host/widget testleri | Signed pakette kullanıcı cihazı kontrolü |
| Gerçek mevcut hesap giriş/çıkış | Kaynak ve host kanıtı | Kullanıcı mevcut test hesabıyla güvenli giriş; parolayı sohbet/rapora verme |
| Hesap silme | Kaynak ve başarısızlık/yerel temizlik testleri | Kalıcı silme ayrı açık onay ister; mevcut gerçek hesap silinmez |
| Satış/üyelik/restore | Satış açık (kurucu kararı 2026-10-23); Core R3 `f43d71a` pini, paywall A ve ücretli ders kapısı host testleriyle | Gerçek StoreKit/Play sandbox satın alma, restore, deneme ve iptal: `SALES-OPEN-REVIEW-AND-SANDBOX.md` §5 S1–S17 (kullanıcı/yönetim yürütür) |
| Reviewer erişimi | Konuk yolu ve bu adımlar | Final cihaz yürüyüşü; gerekiyorsa mevcut demo hesabı güvenli ASC alanında |

Apple/Google sandbox satın alma, yeni hesap/credential veya üretim ödemesi bu
belgeyle yetkilendirilmez. Satış yüzeyini sahte restore başarısı ile
kapatmayın; gerçek hesabın varlığını da sentetik testten çıkarmayın.

## Ekran taslakları

`tools/evidence/store_review_capture_test.dart`, gerçek paketli ders varlıkları
ve üretim widget'larıyla TR/EN kütüphane, gitar yolu/ilk dersi ve piyano05 destek
sınırını render eder. Çıktılar host widget DRAFT'tır; native simülatör/telefon
veya mağaza kabulü değildir. Taze boş konuk kapsamı kullanır; sahte sensör,
sahte model, sahte ilerleme veya kullanıcı verisi yoktur.

```sh
OSTINATO_STORE_CAPTURE_DIR=/absolute/dedicated/evidence/folder \
  flutter test --no-pub --concurrency=1 \
  tools/evidence/store_review_capture_test.dart
```

1206×2622 PNG, Apple'ın Dynamic Island medium tablosundaki bir ölçüdür.
Güncel resmi gereksinim ve saydamlık kuralı:
<https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/>.
Final yükleme öncesi alpha kanalı, native arayüzle eşlik, locale ve güncel ASC
kabulü doğrulanmalıdır. 16 Ağustos tarihsel PNG'leri güncel kaynak diye kullanmayın.
Bu runtime iPhone-only (`UIDeviceFamily=[1]`); iPad destekleniyor gibi davranmayın.

## Yayın öncesi açık kapılar

1. Yeni exact kaynak için ayrı yetkili native archive/package ve gerçek
   imza/profile/hash/asset/locale readback; eski IPA4 güncel aday yerine geçmez.
2. ASC mevcut oturum/build4, privacy formu, reviewer kişi alanları ve doğru
   export-compliance cevabı; kaydetme/yükleme/submit ayrı yetkiyle.
3. Signed pakette gerçek hesap/izin/background/yerel kayıt yürüyüşü; önceki
   OS cihaz erişim reddi başka araçla aşılmaz. Kullanıcı cihazda tamamlayabilir.
4. Harici uzman incelemesi ilk prototipin zorunlu kapısı değildir. AI sahibi
   yalnız gerçekten incelediği video bölümlerini ve özgün yazılı dersleri
   kaydeder. Bu, uzman onayı veya fiziksel öğrenme başarısı değildir. Gerçek
   mikrofon/cihaz sınırları açık kalır; GuitarSet train overlap bağımsız
   doğruluk kanıtı sayılmaz.
5. İlk üç kabul grubu ve açık final yayın kararı kapanmadan store upload yok.

Kaynaklı kapanış yalnız gerçekten çalışan kontrollerle yapılır. Bu belge
mağaza onayını garanti etmez.
