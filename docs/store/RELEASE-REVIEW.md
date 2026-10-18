# Ostinato yayın inceleme paketi — 18 Ekim 2026

Bu dosya yerel submission taslağıdır. App Store Connect'e kaydetme, build
upload, submit veya yayın kararı değildir. İmza/paket kanıtı model veya fiziksel
öğretim kabulünü kapatmaz. Tam öğretim hedefi sürer; yazılı ders ve model destek
sınırları ayrı anlatılır.

## Kaynak ve aday

Mevcut doğrulanmış Development IPA: runtime kaynak `73b05164`, `1.0.0 (4)`,
`com.yulalab.ostinato`, SHA256
`910be9df017745a4623bb193d6c52e181b1910d34a38d92353052e02a4049f04`.
Distribution henüz üretilmiş değildir. Mevcut App Store profil/Distribution
identity metadata'sı bulundu; yeni credential gereksinimi saptanmadı. Aynı
arşivden ayrı, açık onaylı tek `app-store-connect` export en kısa alternatiftir.
Development IPA yeniden üretilmez. Kaynakta runtime değişirse bu arşiv güncel
runtime yerine kullanılamaz. Mağazada build4 çakışması güncel panelde doğrulanır.

## EN reviewer notes — inceleme öncesi son cihaz kontrolü gereken taslak

Ostinato provides original English and Turkish music lessons and practice
records. The guitar path has 60 lessons in 10 modules; introductory written
courses also cover piano (16), ukulele (18), bass (18) and voice (16).
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

Live camera posture practice, paid sessions and subscription sales are disabled
in this release. No purchase or trial is required for the written courses.
There is no active restore-purchase flow to exercise in this release. Written
piano/ukulele/bass/voice content does not provide validated live technique or
voice measurement. Piano lesson05 explicitly states that finger-key contact
cannot be measured with the current production provider.

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
- Mevcut pakette dokuz manifest var; SDK reason kodlarının kaynak manifestleri
  pakette taşınıyor. Bu, son distribution paketinin veya mağaza formunun kabulü
  değildir; export sonrası aynı envanter tekrar bağlanır.
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
| Satış/üyelik/restore | Shared pin `ef60e346` içinde `motionPaidFeaturesAvailable=false` | Bu sürümde satış kapsam dışı; satış açılırsa gerçek store sandbox satın alma/restore ayrı kapı |
| Reviewer erişimi | Konuk yolu ve bu adımlar | Final cihaz yürüyüşü; gerekiyorsa mevcut demo hesabı güvenli ASC alanında |

Apple/Google sandbox satın alma, yeni hesap/credential veya üretim ödemesi bu
belgeyle yetkilendirilmez. Kapalı satış yüzeyini sahte restore başarısı ile
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

1. Distribution export için yeni sınırlı koşu onayı ve actual imza/profile/hash.
2. ASC mevcut oturum/build4, privacy formu, reviewer kişi alanları ve doğru
   export-compliance cevabı; kaydetme/yükleme/submit ayrı yetkiyle.
3. Signed pakette gerçek hesap/izin/background/yerel kayıt yürüyüşü; önceki
   OS cihaz erişim reddi başka araçla aşılmaz. Kullanıcı cihazda tamamlayabilir.
4. Kullanıcı gösterimleri/öğretmen ve model doğruluğu kabulü ayrı; mevcut ses
   pilotunun train overlap'ı bu kapıları kapatmaz.
5. İlk üç kabul grubu ve açık final yayın kararı kapanmadan store upload yok.

Kaynaklı kapanış yalnız gerçekten çalışan kontrollerle yapılır. Bu belge
mağaza onayını garanti etmez.
