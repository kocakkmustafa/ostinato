# Ostinato hesap veri beyanı taslağı — 2026-09-25

Bu taslak uygulama kodundaki ortak Motion hesabına göredir. App Store Connect
gizlilik yanıtı ve Google Play Data safety formu henüz gönderilmiş değildir.

## Kaynakla uzlaştırma — 2026-09-26

Başlıktaki 2026-09-25 ilk taslak tarihidir; o günün mikrofonsuz kapsamı
tarihseldir. Kurucunun yeni kararı gitar kursunda isteğe bağlı, cihaz üstünde
tek nota gözlemidir. Bu güncelleme mevcut Dart/native kaynak kontrolüdür;
canlı sağlayıcı, mağaza formu veya fiziksel mikrofon kabulü değildir.

## Sağlayıcı günlükleri ve kimlik doğrulama — 2026-09-27

Üretim sağlayıcısının 2026-09-26 21:36 UTC tarihli salt okunur alan/sayı
makbuzu, cihaz dışındaki Auth ve edge günlüklerinin saklandığını doğrular.
Ölçüm anına kadar dönen örnekte edge günlüklerinin 6/6 kaydında IP, user-agent ve
ülke/bölge/şehir alanları; Auth günlüklerinin 6/6 kaydında IP ve 2/6 kaydında
hesap kimliği; ayrı Auth audit deposunun 1/1 kaydında kimlik ve user-agent
vardır. Veritabanındaki `auth.audit_log_entries` satır sayısının sıfır olması,
[ayrı Auth günlük deposunun](https://supabase.com/docs/guides/auth/audit-logs)
boş olduğu anlamına gelmez. Ham IP, kimlik, parola veya günlük içeriği bu
belgeye alınmamıştır. Makbuz ortak servise aittir; her uygulamada yeni bir
canlı ağ oturumu ölçüldüğü iddiası değildir.

| Sunucuda saklanan veri | Apple manifest türü | Amaç ve bağlantı |
|---|---|---|
| IP, user-agent, istemci platform/sürüm bilgisi ve Auth/istek güvenlik günlükleri | `NSPrivacyCollectedDataTypeOtherDiagnosticData` | İşletim, güvenlik ve teknik tanılama; App Functionality, kullanıcıya bağlı, tracking yok |
| Edge isteğine eklenen IP tabanlı ülke/bölge/şehir | `NSPrivacyCollectedDataTypeCoarseLocation` | Aynı hizmetin işletim/güvenlik kaydı; App Functionality, kullanıcıya bağlı, tracking yok; GPS veya kesin konum izni değildir |
| Parola kimlik doğrulama verisi ve saklanan parola hash'i | `NSPrivacyCollectedDataTypeOtherDataTypes` | Hesap doğrulama; App Functionality, kullanıcıya bağlı, tracking yok |

[Supabase Auth](https://supabase.com/docs/guides/auth/password-security)
parolanın bcrypt hash'ini `auth.users.encrypted_password` alanında tutar;
parola uygulamanın kurs/seans geçmişine yazılmaz. Apple parola için ayrı
bir tür adlandırmadığından **Other Data Types eşlemesi bu projede yapılan
bir sınıflandırma çıkarımıdır**. Kullanıcı kimliğinin tek yönlü özetiyle
tutulan hesap silme makbuzu da güvenlik/hesap verisidir; hash olması tek
başına anonim veri olduğu anlamına gelmez. IP ve hesap ilişkisinin toplama
öncesinde kaldırıldığı kanıtlanmadığından bu üç tür `Linked=true` beyan edilir.

Manifest artık e-posta, isteğe bağlı ad, kullanıcı ID'si ve bu üç türden
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
| Satın alma geçmişi | Hayır; ilk sürümde satış ve ücretli oturum kapalı | Bu sürümde kullanılmaz | Hayır |
| Şifre | Auth isteğinde sunucuya gider; uygulama geçmişine yazılmaz | Kayıt, giriş, şifre değiştirme | Evet |
| Kamera görüntüsü ve kare ölçümü | Hayır | Cihazdaki canlı çalışma | Yerel, sunucuda yok |
| İsteğe bağlı mikrofonun ham sesi | Hayır | Yaklaşık tek gitar notası/Hz/cents gözlemi | Yalnız sınırlı RAM; ses dosyası, upload veya hesap kaydı yok |
| Gitar kursu ilerlemesi | Hayır | Görüldü, çalışıldı ve kullanıcı beyanıyla tamamlandı durumları | Konuk/hesap kapsamına ayrılmış yerel JSON; Motion hesabına senkronize edilmez |
| Seans özeti/geçmişi | Hayır | Bu cihazdaki geçmiş | Yerel, hesap dizinine ayrılmış |

İlk sürümün Apple gizlilik manifestinde e-posta, isteğe bağlı ad,
kullanıcı kimliği ve sağlayıcı tanılama/konum/kimlik doğrulama
verileri uygulama işlevi için kullanıcıyla bağlantılı, izleme dışı beyan edilir.
Play taslağında yalnız e-posta, görünen ad ve kullanıcı ID’si sırasıyla
Personal info / Email address, Name ve User IDs olarak değerlendirilir.
Abonelik satışı ve satın alma geçmişi
aktarımı bu sürümde kapalıdır; ileride etkinleştirilirse Apple/Play
formları ve bu belge birlikte güncellenir.
Görünen ad kullanıcı için isteğe bağlıdır. Kamera ve cihazda kalan geçmiş
“toplanan veri” diye işaretlenmez. Sağlayıcı günlükleri makbuzu ve Auth
saklama belgesi temelinde tanılama, yaklaşık konum ve kimlik doğrulama
verileri de beyanlıdır; konsol formu ve saklama politikası ayrıca doğrulanır.

### Mikrofonun izin ve yaşam döngüsü

Kullanıcı gözlem ekranında **Başlat** seçer; işletim sistemi mikrofon izni
verilmeden native capture başlamaz. İzin reddedilirse kursa mikrofonsuz
devam edilir. Kullanıcı **Durdur** seçtiğinde, ekran dispose olduğunda,
hesap kapsamı değiştiğinde veya uygulama ön planı kaybettiğinde capture
kapanır. Ön plana dönüş mikrofonu otomatik yeniden başlatmaz. iOS native
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

Hesap ekranı ortak hesabı silme yolu sunar; başarılı uzak silmenin ardından
yalnız bu uygulamanın ilgili kullanıcıya ait yerel dizinini siler. Play'in
istediği uygulama dışı hesap silme bağlantısının canlı içeriği, mağaza
konsolundaki veri beyanı, sağlayıcı saklama süresi ve abonelik iptali açıklaması
yayın kapılarıdır. Abonelik satışı açılmadan önce hesap silme ve mağaza aboneliği ilişkisi
ayrıca açıklanır.

Kaynak: [Apple privacy manifest](https://developer.apple.com/documentation/BundleResources/describing-data-use-in-privacy-manifests),
[Google Play Data safety](https://support.google.com/googleplay/android-developer/answer/10787469),
[Google Play hesap silme](https://support.google.com/googleplay/android-developer/answer/13327111).
