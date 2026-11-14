# OST-P0-08B devir notu (2026-11-14)

## Kapanan
- `lib/app/practice/own_recording/encrypted_take_store.dart` (AES-256-GCM, KeyStore soyutlaması, put/read/delete/deleteAll/exportTo/ids) ve `secure_key_store.dart` (flutter_secure_storage). ADR-007.
- Hiçbir yere bağlı değil; `persistentArchive` hâlâ `denied`; yeni bayrak yok; yeni kullanıcı metni yok.

## Ölçülen
- `test/ost_p0_08b_encrypted_store_test.dart`: şifreleme, kurcalama, anahtar, silme, export, politika regresyonu (testler bellek içi sahte anahtarla koşar).

## Açık (ölçülmedi)
- `SecureKeyStore` gerçek cihazda (Keychain/Keystore) denenmedi; yalnız birim testte sahte var.
- Saf Dart AES-GCM'in 180 sn WAV (~5,8 MB @16 kHz) için süresi ve bellek tepe değeri cihazda ölçülmedi (gerekirse isolate ya da `cryptography_flutter`).
- iOS Keychain verisi uygulama silinince kalabilir (yeniden kurulumda anahtar var, dosya yok: zararsız; tersi yok). Android'de yedekten çıkarma yapıldı, cihaz-aktarımı denenmedi.
- Dizin adı `encrypted_takes` (getApplicationSupportDirectory altında) çağıranın seçimi; yedek kuralı bu adı varsayar.

## Bayrak AÇILMADAN önce gerekenler
1. Çocuk sınırı: yaş sinyali yok; child/unknown için saklama ve export kapalı kalmalı (ADR-005).
2. UI: kullanıcı açıkça saklama/export seçer; paylaşım yüzeyi, silme ve "tümünü sil" erişimi; ayarlar ekranındaki işlevsiz anahtar sorunu (ADR-005 sınır c).
3. Onay metni: ne saklanır, nerede, ne kadar, nasıl silinir; 12 dilde anadil kontrolü. Export'un şifresiz olduğu açıkça yazılmalı.
4. Anahtar kaybı senaryosu: anahtar silinir/yedekten gelmezse eski takeler kalıcı olarak okunamaz (`keyMissing`/`corrupt`); kullanıcıya "kayıt kurtarılamaz" akışı ve bozuk dosya temizliği tasarlanmalı. Cihaz değişiminde kayıtlar taşınmaz.
5. Politika kararı (`persistentArchive`) ve bayrak: ayrı kurucu/Motion kararı; politika testleri güncellenir.
6. Mağaza gizlilik/veri güvenliği beyanları ve egress bekçisinin yeniden gözden geçirilmesi.
