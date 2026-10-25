# Ostinato hesap veri beyanı taslağı — 2026-09-25

Bu taslak uygulama kodundaki ortak Motion hesabına göredir. App Store Connect
gizlilik yanıtı ve Google Play Data safety formu henüz gönderilmiş değildir.

## Kaynakla uzlaştırma — 2026-10-02

Başlıktaki 2026-09-25 ilk taslak tarihidir; o günün mikrofonsuz kapsamı
tarihseldir. Kurucunun yeni kararı gitar kursunda isteğe bağlı, cihaz üstünde
tek nota gözlemidir. Bu güncelleme mevcut Dart/native kaynak kontrolüdür;
canlı sağlayıcı, mağaza formu veya fiziksel mikrofon kabulü değildir.

## Sağlayıcı günlükleri ve kimlik doğrulama — tarihsel 2026-09-26 makbuzu

Üretim sağlayıcısının 2026-09-26 21:36 UTC tarihli salt okunur alan/sayı
makbuzu, o tarihsel örnekte cihaz dışındaki Auth ve edge günlüklerinin
saklandığını göstermiştir. O ölçümde dönen örnekte edge günlüklerinin 6/6 kaydında IP, user-agent ve
ülke/bölge/şehir alanları; Auth günlüklerinin 6/6 kaydında IP ve 2/6 kaydında
hesap kimliği; ayrı Auth audit deposunun 1/1 kaydında kimlik ve user-agent
vardır. Veritabanındaki `auth.audit_log_entries` satır sayısının sıfır olması,
[ayrı Auth günlük deposunun](https://supabase.com/docs/guides/auth/audit-logs)
boş olduğu anlamına gelmez. Ham IP, kimlik, parola veya günlük içeriği bu
belgeye alınmamıştır. Makbuz ortak servise aittir; her uygulamada yeni bir
canlı ağ oturumu ölçüldüğü iddiası değildir. 2026-10-02 kaynak uzlaştırması
sağlayıcıya yeniden bağlanmamıştır; güncel saklama, alanlar, silme davranışı
ve Ostinato çalışma zamanı trafiği bu tarihsel makbuzla kabul edilmiş sayılmaz.

| Beyan kapsamındaki hesap/sağlayıcı verisi | Apple manifest türü | Amaç ve bağlantı |
|---|---|---|
| E-posta adresi | `NSPrivacyCollectedDataTypeEmailAddress` | Hesap işlevleri; App Functionality, kullanıcıya bağlı, tracking yok |
| Kullanıcının isteğe bağlı görünen adı | `NSPrivacyCollectedDataTypeName` | Profil; App Functionality, kullanıcıya bağlı, tracking yok |
| Kullanıcı/hesap kimliği | `NSPrivacyCollectedDataTypeUserID` | Oturum ve hesap ayrımı; App Functionality, kullanıcıya bağlı, tracking yok |
| IP, user-agent, istemci platform/sürüm bilgisi ve Auth/istek güvenlik günlükleri | `NSPrivacyCollectedDataTypeOtherDiagnosticData` | İşletim, güvenlik ve teknik tanılama; App Functionality, kullanıcıya bağlı, tracking yok |
| Edge isteğine eklenen IP tabanlı ülke/bölge/şehir | `NSPrivacyCollectedDataTypeCoarseLocation` | Aynı hizmetin işletim/güvenlik kaydı; App Functionality, kullanıcıya bağlı, tracking yok; GPS veya kesin konum izni değildir |
| Parola kimlik doğrulama verisi ve saklanan parola hash'i | `NSPrivacyCollectedDataTypeOtherDataTypes` | Hesap doğrulama; App Functionality, kullanıcıya bağlı, tracking yok |
| Abonelik satın alma kanıtı ve sunucuda doğrulanan hak kaydı (`motion_entitlements`, Motion+ deneme defteri `motion_trial_ledger`) — 2026-10-26 | `NSPrivacyCollectedDataTypePurchaseHistory` | Satın almanın sunucuda doğrulanması ve erişim; App Functionality, kullanıcıya bağlı, tracking yok |

[Supabase Auth](https://supabase.com/docs/guides/auth/password-security)
parolanın bcrypt hash'ini `auth.users.encrypted_password` alanında tutar;
parola uygulamanın kurs/seans geçmişine yazılmaz. Apple parola için ayrı
bir tür adlandırmadığından **Other Data Types eşlemesi bu projede yapılan
bir sınıflandırma çıkarımıdır**. Kullanıcı kimliğinin tek yönlü özetiyle
tutulan hesap silme makbuzu da güvenlik/hesap verisidir; hash olması tek
başına anonim veri olduğu anlamına gelmez. IP ve hesap ilişkisinin toplama
öncesinde kaldırıldığı kanıtlanmadığından bu üç tür `Linked=true` beyan edilir.

2026-10-02 kaynak okumasında manifest e-posta, isteğe bağlı ad, kullanıcı ID'si ve bu üç türden
oluşan **altı** collected-data kaydı taşır. Hepsinde
`NSPrivacyCollectedDataTypePurposeAppFunctionality`, `Linked=true` ve
`Tracking=false` vardır. Bu, davranış analitiği veya reklam amacı eklendiği
anlamına gelmez. Kamera/kareler, cihazda kalan kurs ilerlemesi ve seans
geçmişi için collection beyanı eklenmez; Ostinato'nun isteğe bağlı ham sesi
de yalnız cihazdaki sınırlı RAM'de kalır. Diğer dört uygulama mikrofon
kullanmaz. Sunucu günlükleri, cihaz içi geçici işleme ile aynı şey değildir.

[Apple collection ve kullanım tanımları](https://developer.apple.com/app-store/app-privacy-details/)
ve [manifest tür/anahtarları](https://developer.apple.com/documentation/bundleresources/describing-data-use-in-privacy-manifests)
bu ayrımın temelidir. Apple manifestinin güncellenmesi App Store Connect
veya Play Data safety formunun girildiği/onaylandığı anlamına gelmez.
Play kategorileri kendi form tanımlarıyla ayrıca eşleştirilir. Sağlayıcı
saklama süreleri, günlüklerin silme/erişim politikası, gerçek hesap silme
akışı ve son paket/SDK gizlilik raporu ayrı kabul kapılarıdır.

| Veri | Cihaz dışına çıkar mı? | Kullanım | Hesapla bağlı mı? |
|---|---|---|---|
| E-posta adresi | Evet, Motion Auth | Kayıt, giriş, doğrulama, şifre sıfırlama | Evet |
| Görünen ad | Kullanıcı girerse evet, Motion profili | Profil | Evet |
| Kullanıcı kimliği | Evet, Motion Auth/profil/uygulama üyeliği | Oturum ve hesap veri ayrımı | Evet |
| Satın alma geçmişi (2026-10-26) | Evet; mağaza satın alma kanıtı Motion sunucusuna (`motion-verify-purchase`) gider, mağaza bildirimleri hak kaydını günceller | Aboneliği doğrulamak, erişim vermek, Motion+ denemesini hesap başına bir kez sunmak | Evet |
| Şifre | Auth isteğinde sunucuya gider; uygulama geçmişine yazılmaz | Kayıt, giriş, şifre değiştirme | Evet |
| Kamera görüntüsü ve kare ölçümü | Hayır | Cihazdaki canlı çalışma | Yerel, sunucuda yok |
| İsteğe bağlı mikrofonun ham sesi | Hayır | Yaklaşık tek gitar notası/Hz/cents gözlemi | Yalnız sınırlı RAM; ses dosyası, upload veya hesap kaydı yok |
| Gitar kursu ilerlemesi | Hayır | Görüldü, çalışıldı ve kullanıcı beyanıyla tamamlandı durumları | Konuk/hesap kapsamına ayrılmış yerel JSON; Motion hesabına senkronize edilmez |
| Seans özeti/geçmişi | Hayır | Bu cihazdaki geçmiş | Yerel, hesap dizinine ayrılmış |

İlk sürümün Apple gizlilik manifestinde e-posta, isteğe bağlı ad,
kullanıcı kimliği ve sağlayıcı tanılama/konum/kimlik doğrulama
verileri uygulama işlevi için kullanıcıyla bağlantılı, izleme dışı beyan edilir.
Apple'ın bu altı manifest türü Play'e altı aynı kategori olarak kopyalanmaz.
Play taslağı hesap alanlarının yanında sağlayıcı verilerini de kapsar;
aşağıdaki eşleme [Google'ın kendi tür/amaç tanımları](https://support.google.com/googleplay/android-developer/answer/10787469?hl=en)
üzerinden hazırlanmıştır ve konsol yanıtı değildir.

| Veri | Google Play taslak kategorisi | Eşleme sınırı |
|---|---|---|
| E-posta | Personal info / Email address | Kaynakta hesap alanı |
| İsteğe bağlı görünen ad | Personal info / Name | Kaynakta profil alanı |
| Kullanıcı/hesap ID'si | Personal info / User IDs | Kaynakta hesap alanı |
| IP'den türetilen ülke/bölge/şehir | Location / Approximate location | Tarihsel sağlayıcı örneği; güncel kapsam manuel doğrulanacak |
| IP, user-agent, platform ve Auth/istek güvenlik günlükleri | App info and performance / Diagnostics; Device or other IDs için alan bazlı eşleme açık | Teknik tanılama ile cihaz/tarayıcı tanımlayıcısı ayrımı manuel doğrulanacak; Apple türü tek başına Play seçimi belirlemez |
| Parola kimlik doğrulama verisi/hash | Personal info / Other info adayı | Proje çıkarımı; Google parola için ayrı tür adlandırmaz, nihai form eşlemesi manuel doğrulanacak |
| Abonelik satın alma geçmişi (2026-10-26) | Financial info / Purchase history | Ödeme kartı bilgisi uygulamaya/sunucuya gelmez (mağaza işler); yalnız satın alma kanıtı ve hak durumu |

Hesap alanları için App functionality / Account management; güvenlik günlükleri
için Fraud prevention, security, and compliance amaçları taslak adaylarıdır.
Her alanın gerçek kullanımı ve SDK davranışı doğrulanmadan amaç, paylaşım,
isteğe bağlılık, şifreleme veya silme yanıtı kesinleştirilmez. Apple manifesti
ve bu tablo, güncel sunucu davranışı ya da gönderilmiş mağaza formu kanıtı değildir.

**2026-10-26 güncellemesi:** abonelik satışı ilk sürümde açıktır (kurucu
kararı 2026-10-23). Satın alma geçmişi Apple manifestine
`NSPrivacyCollectedDataTypePurchaseHistory` (bağlı, tracking yok, App
Functionality) olarak eklendi; manifest artık **yedi** collected tür taşır.
App Store Connect App Privacy formuna "Purchases" ve Play Data safety'ye
"Financial info / Purchase history" girişi Yönetim işidir. Yaş beyanı (ay/yıl)
ve veli onayı kayıtları hesapla bağlı sunucu verisidir; Apple form eşlemesi
(Other Data Types) Yönetim/hukuk teyidine açıktır. Aşağıdaki tarihsel
bölümlerdeki "altı tür / satış kapalı" ifadeleri o tarihin okumasıdır.
Görünen ad kullanıcı için isteğe bağlıdır. Kamera ve cihazda kalan geçmiş
“toplanan veri” diye işaretlenmez. Tarihsel sağlayıcı günlükleri makbuzu ve
Auth saklama belgesi temelinde tanılama, yaklaşık konum ve kimlik doğrulama
verileri Apple kaynak manifestinde beyanlıdır; Play eşlemesi, konsol formu,
güncel sağlayıcı saklama politikası ve son paket/SDK raporu ayrıca doğrulanır.

### Mikrofonun izin ve yaşam döngüsü

Kullanıcı gözlem ekranında **Başlat** seçer; işletim sistemi mikrofon izni
verilmeden native capture başlamaz. İzin reddedilirse kursa mikrofonsuz
devam edilir. Kullanıcı **Durdur** seçtiğinde, ekran dispose olduğunda,
hesap kapsamı değiştiğinde veya uygulama ön planı kaybettiğinde kaynak
capture kapanmasını ister. Bu kaynak davranışı fiziksel cihazda başarılı
kapanma/route kabulü değildir. Ön plana dönüş mikrofonu otomatik yeniden başlatmaz. iOS native
kaynağı izin/foreground denetler; Android native kaynağı da izin ve
foreground denetler. Ham PCM yalnız sınırlı bellek tamponlarında işlenir;
bu yolda ses dosyası yazma, ses upload'u veya ağ sink'i yoktur.

Yaklaşık nota/Hz/cents yalnız geçici ekranda gözlenir; doğru nota, akort
başarısı, akor, ritim, mutlak dB veya ustalık puanı değildir ve kurs
ilerlemesini yazmaz. Kurs mikrofon olmadan tamamlanabilir. Kaynakta iOS
`NSMicrophoneUsageDescription` ve Android `RECORD_AUDIO` vardır; izin
bulunması tek başına sesin sunucuya toplandığı anlamına gelmez. Gerçek
telefon mikrofon/route ve çalışma zamanı ağ kabulü ayrı kapıdır.

### Yerel işleme ile mağaza “collection” ayrımı

[Apple](https://developer.apple.com/app-store/app-privacy-details/) ve
[Google Play](https://support.google.com/googleplay/android-developer/answer/10787469?hl=en)
yalnız cihazda işlenip cihaz dışına gönderilmeyen veriyi bu beyanlarda
toplanan veri saymaz. Bu yüzden ham ses ve yerel kurs kaydı için sunucu
verisi beyanı eklenmez. Cihaz dışına gönderilen türetilmiş veri ve SDK
davranışı ayrıca değerlendirilir; Google'ın cihaz dışındaki geçici işleme
kuralı, cihaz içi RAM kullanımından farklıdır.

Kaynak kontrolü: `lib/app/audio/audio_input_controller.dart`,
`lib/app/audio/guitar_note_observation_controller.dart`,
`lib/app/screens/guitar_note_observation_screen.dart`,
`ios/Runner/AudioCaptureStreamer.swift`, Android `AudioCaptureStreamer.kt`,
`lib/app/guitar_journey_progress.dart`, iOS/Android izin dosyaları ve
`ios/Runner/PrivacyInfo.xcprivacy`. Çözümlenen `motion_account` paketindeki
`motion_release_policy.dart` değeri `motionPaidFeaturesAvailable=false`;
satış/üyelik girişleri bu kapıya bağlıdır. Manifestin altı collected türü
e-posta, ad, kullanıcı ID'si, diğer tanılama,
yaklaşık konum ve diğer verilerdir; satın alma veya ses collected türü yoktur.

### 2026-10-15 herkese açık silme yönergesi okuması

Mevcut [Motion gizlilik sayfasının hesap silme bölümü](https://yulalab.com/privacy/motion#motion-account-deletion)
HTTP 200 HTML içinde `motion-account-deletion` hedefini ve
`mailto:support@yulalab.com?subject=Motion%20account%20deletion` bağlantısını taşıyor.
Metin, uygulama kullanılamadığında hesap e-postası ve uygulama adıyla talep
gönderilmesini, parola gönderilmemesini ve aboneliğin mağazada ayrıca iptalini
açıklıyor. Bu mevcut adres, Play'in uygulama dışı silme URL alanı için doğrulanacak
metadata adayıdır; ayrı bir `/delete-account/motion` adresi varsayılmamalıdır.
Bu okuma mağaza formunun kaydedildiği/kabul edildiği, mail gönderildiği, silme
talebinin işlendiği veya gerçek hesabın silindiği anlamına gelmez. Nihai form
uygunluğu, sağlayıcı saklama kapsamı ve gerçek silme kabulü açık kalır.

Hesap ekranı ortak hesabı silme yolu sunar; başarılı uzak silmenin ardından
yalnız bu uygulamanın ilgili kullanıcıya ait yerel dizinini siler. Play'in
istediği uygulama dışı hesap silme bağlantısının canlı içeriği, mağaza
konsolundaki veri beyanı, sağlayıcı saklama süresi ve abonelik iptali açıklaması
yayın kapılarıdır. Abonelik satışı açılmadan önce hesap silme ve mağaza aboneliği ilişkisi
ayrıca açıklanır.

Kaynak: [Apple privacy manifest](https://developer.apple.com/documentation/BundleResources/describing-data-use-in-privacy-manifests),
[Google Play Data safety](https://support.google.com/googleplay/android-developer/answer/10787469),
[Google Play hesap silme](https://support.google.com/googleplay/android-developer/answer/13327111).

## 2026-10-18 mevcut paket ve herkese açık bağlantı uzlaştırması

`73b05164` kaynağının `1.0.0(4)` Development IPA'sında dokuz privacy manifesti
bulundu. Uygulamanın altı collected-data türü kaynakla aynıdır; hiçbir manifestte
tracking veya tracking domain bildirimi yoktur. Required-reason API bildirimleri
UserDefaults (1C8F.1), FileTimestamp (0A2A.1/C617.1) ve SystemBootTime
(35F9.1) için ilgili SDK manifestlerinde bulunur. Bu paket okuması çalışma zamanı
trafik denetimi, Xcode aggregate privacy report veya mağaza formu kabulü değildir.

Aynı gün mevcut privacy ve support URL'leri HTTP200 döndü; privacy sayfasındaki
`motion-account-deletion` hedefi ve mevcut destek e-posta yolu tekrar görüldü.
Mesaj gönderilmedi, hesap silinmedi, site veya backend değiştirilmedi. Güncel
sağlayıcı saklama süreleri ve silme makbuzu/oturum davranışı gerçek hesapta ayrı
kabul gerektirir; eski günlük örnekleri bu kabul yerine geçmez.

App-local Basic Pitch/GuitarSet araştırma pilotu bu IPA'nın içinde değildir;
yeni veri toplama/aktarımı, privacy kategorisi veya doğruluk iddiası eklemez.
Abonelik ve ücretli kamera kapısı kapalı kalır. Restore ve satın alma geçmişi
kapısı, satış açılan sonraki sürümün sandbox kabulüdür; bu sürüm için başarılı
IAP işlemi yapılmış gibi işaretlenmez. Reviewer ve store taslak girişi:
[RELEASE-REVIEW.md](RELEASE-REVIEW.md).
