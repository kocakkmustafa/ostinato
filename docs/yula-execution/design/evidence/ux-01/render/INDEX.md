# Test render dizini (OST-UX-01)

Etiket: **test render, sahte veri**. Gerçek cihaz/simülatör görüntüsü değildir.
Üretici: `tool/ux_01_render_evidence_test.dart` (elle: `flutter test tool/ux_01_render_evidence_test.dart`; CI'a girmez).
Ortak koşullar: mantıksal 390x844, `devicePixelRatio` 3, PNG 585x1266 (ölçek 1,5; boyut sınırı için). Dil: en, açık tema. Tüm bayraklar varsayılan KAPALI (kamera, ilk üç dakika, dinle-dene-düzelt AÇILMADI). Ağ, Supabase, hesap, `--dart-define`, gerçek mikrofon/kamera yok.
Yazı tipi: pubspec'te paketli Hanken Grotesk ve IBM Plex Mono `FontLoader` ile `assets/fonts/` dosyalarından yüklendi (gerçek yazı tipi çizildi). Ama metin glifleri (gibi ⚙, ‹, ♩, ✓, ◆, ◯) bu yazı tiplerinde yok ve test ortamında yedek yazı tipi bulunmadığından kutu (tofu) olarak görünür; gerçek cihazda sistem yazı tipi bunları çizer. Kutu simgeler ürün hatası olarak okunmamalı.

| Dosya | Ekran | Sahte kurulum ve veri |
|---|---|---|
| 01-onboarding-karsilama.png | Onboarding 1/3 karşılama | `OstinatoHome(alreadyOnboarded: false)` + `InMemoryOnboardingStore`; paketli içerik |
| 02-onboarding-kapsam.png | Onboarding 2/3 kapsam | aynı, birincil düğmeye dokunuldu |
| 03-onboarding-sensorler.png | Onboarding 3/3 kamera/mikrofon/ilerleme kartları | aynı, ikinci dokunuş |
| 04-studyo-kutuphane.png | Stüdyo / kütüphane (ana liste) | `OstinatoHome(alreadyOnboarded: true)` + `InMemoryOnboardingStore`; paketli içerik |
| 05-calgi-gitar.png | Çalgı sayfası (Guitar) | kütüphaneden "Guitar" dokunuşu |
| 06-kurs-ders-listesi.png | Gitar kursu ders listesi (ilerleme/durum çipleri) | `V1PracticeListScreen` + bellek-içi ilerleme (boş) ve kontrol deposu, `MemorySetupProfileStore` (kurulum adımları atlanmış); paketli `content/v1/gtr` |
| 07-ders-okuyucu.png | V1 ders okuyucu (öz-kontrol dersi) | `V1LessonReaderScreen` + bellek-içi kontrol deposu; kurstaki ilk öz-kontrol dersi |
| 08-pratik-ekrani.png | Pratik ekranı (pratik döngüsü, durağan, mikrofon kapalı) | `PracticeLoopScreen` + bellek-içi ilerleme; ders `gtr-s1-m02-02` |
| 09-pratik-mikrofon-izni-reddi.png | Mikrofon izni reddi durumu (Start sonrası; sayfa en alta kaydırılmış) | `FakeAudioCaptureChannel` + `AudioInputController(requestMicrophonePermission: denied)`; `MicPermissionGate` durumu denied; "Start" dokunuşu |
| 10-sonuc-ekrani.png | Pratik sonuç ekranı | `PracticeResultScreen` + elle kurulmuş `PracticeRunSummary` (8 nota: 6 doğru, 1 farklı, 1 duyulmadı; veri SAHTE) |
| 11-ayarlar.png | Ayarlar | `SettingsScreen` varsayılan; paketli içerik |

## Render edilmeyenler ve nedeni
- Ayrı "ilerleme/geçmiş" ekranı: bulunamadı; ilerleme ders listesi çiplerinde (06) görünür.
- Canlı ölçüm, özet (Review), kurulum kontrolü, kamera ekranları: kamera kapısı ve gerçek kare ister (`test/reachable_screens_test.dart` ile aynı kısıt); atlandı.
- Giriş engeli ve hesap ekranları: Supabase/hesap kapsamı dışı.
