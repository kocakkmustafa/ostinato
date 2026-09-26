# Ostinato hesap veri beyanı taslağı — 2026-09-25

Bu taslak uygulama kodundaki ortak Motion hesabına göredir. App Store Connect
gizlilik yanıtı ve Google Play Data safety formu henüz gönderilmiş değildir.

## Kaynakla uzlaştırma — 2026-09-26

Başlıktaki 2026-09-25 ilk taslak tarihidir; o günün mikrofonsuz kapsamı
tarihseldir. Kurucunun yeni kararı gitar kursunda isteğe bağlı, cihaz üstünde
tek nota gözlemidir. Bu güncelleme mevcut Dart/native kaynak kontrolüdür;
canlı sağlayıcı, mağaza formu veya fiziksel mikrofon kabulü değildir.

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

İlk sürümün Apple gizlilik manifestinde e-posta, isteğe bağlı ad ve
kullanıcı kimliği uygulama işlevi için kullanıcıyla bağlantılı, izleme dışı
beyan edilir. Play taslağında bunlar Personal info / Email address, Name ve
User IDs olarak değerlendirilir. Abonelik satışı ve satın alma geçmişi
aktarımı bu sürümde kapalıdır; ileride etkinleştirilirse Apple/Play
formları ve bu belge birlikte güncellenir.
Görünen ad kullanıcı için isteğe bağlıdır. Kamera ve cihazda kalan geçmiş
“toplanan veri” diye işaretlenmez. Şifre ve sağlayıcı günlükleri için nihai
form yanıtı canlı Supabase yapılandırmasıyla ayrıca doğrulanır.

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
satış/üyelik girişleri bu kapıya bağlıdır. Manifestin üç collected türü
e-posta, ad ve kullanıcı ID'sidir; satın alma veya ses collected türü yoktur.

Hesap ekranı ortak hesabı silme yolu sunar; başarılı uzak silmenin ardından
yalnız bu uygulamanın ilgili kullanıcıya ait yerel dizinini siler. Play'in
istediği uygulama dışı hesap silme bağlantısının canlı içeriği, mağaza
konsolundaki veri beyanı, sağlayıcı saklama süresi ve abonelik iptali açıklaması
yayın kapılarıdır. Abonelik satışı açılmadan önce hesap silme ve mağaza aboneliği ilişkisi
ayrıca açıklanır.

Kaynak: [Apple privacy manifest](https://developer.apple.com/documentation/BundleResources/describing-data-use-in-privacy-manifests),
[Google Play Data safety](https://support.google.com/googleplay/android-developer/answer/10787469),
[Google Play hesap silme](https://support.google.com/googleplay/android-developer/answer/13327111).
