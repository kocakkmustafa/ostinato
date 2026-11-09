# Güncel simülatör görüntüleri (OST-UX-01)

Etiket: güncel simülatör (iOS 27.0, main `1fa8b93` derlemesi), giriş engeli: `MOTION_SUPABASE_*` tanımları verilmedi.

| Dosya | Ekran |
|---|---|
| 01-acilis-splash.png | Açılış (lacivert zemin, çubuk figür logosu), ~6 sn sonra |
| 02-giris-engeli.png | Hesap önyükleme engeli: "Bu sürümde giriş kullanılamıyor. Lütfen güncel bir sürüm deneyin." |

Cihaz: Ostinato Review 18 Pro Max (iOS 27.0 simülatör), `flutter build ios --simulator --debug`, temiz kurulum. Neden engel: `lib/app/motion_account_bootstrap.dart` `MOTION_SUPABASE_URL` ve publishable key `--dart-define` ile bekler; verilmedi (kurucu kararı bekleniyor, define dosyası kullanılmadı).
